#!/bin/bash

# Have added this script to PATH. Can directly call the script by just stating "x-claude-sessions".
# Also have aliases for it (ccfzf / ccs / claude-sessions) in tools/ai/claude-code.sh.
# Root-level (not in a subfolder) so it ranks above deeper scripts in the "x" picker,
# which sorts fd results by folder depth (see x-script-selector.sh).

# This script lists every Claude Code session that can be jumped back into -- both
# sessions the daemon is currently tracking (`claude agents --json`: live/background
# jobs, with rich state like "blocked"/"working") AND every session that ever ran,
# read straight from the on-disk transcripts under ~/.claude/projects/ -- lets you
# fuzzy-pick one with fzf, and attaches/resumes it in place.
#
# WHY BOTH SOURCES: `claude agents --json` ALONE is not a complete session index --
# confirmed by comparing it against the native `/resume` picker's full list, which
# it fell well short of. `claude agents --json` only tracks sessions dispatched as
# background jobs, plus a CURRENTLY-LIVE interactive process (if any). The moment
# you exit an interactive session normally (/exit, closing the terminal), it drops
# out of that list entirely, even though its transcript is still fully resumable --
# that's why recently-used interactive sessions would otherwise be invisible here.

# --- ENVIRONMENT VARIABLES ---

# --- FUNCTIONS ---

# Best practice to use kebab-case for script names, e.g., "x-claude-sessions.sh".
x-claude-sessions() {
    # 1. Guard dependencies. Scripts do NOT source .bashrc, so nothing here is assumed
    #    beyond what's on PATH -- claude, jq, fzf, awk are all present on this machine
    #    (awk ships as part of Git for Windows' MSYS toolchain).
    local missing=()
    command -v claude &> /dev/null || missing+=("claude")
    command -v jq &> /dev/null || missing+=("jq")
    command -v fzf &> /dev/null || missing+=("fzf")
    command -v awk &> /dev/null || missing+=("awk")
    if ((${#missing[@]} > 0)); then
        echo "❌ Missing required tool(s): ${missing[*]}"
        return 1
    fi

    # 2. Default view is EVERY session, live or historical. -r/--running narrows it
    #    down to sessions the daemon currently shows as blocked/working/waiting --
    #    i.e. only rows that came from `claude agents --json`, not the transcript scan.
    local only_running=false
    case "$1" in
        -r | --running) only_running=true ;;
    esac

    echo "📝  Scanning Claude Code sessions..."

    # 3. PASS 1 -- everything the daemon currently tracks (rich live state, but a
    #    subset of all resumable sessions; see header comment above).
    #    Columns: sessionId, kind, shortId, cwd, state, status, waitingFor, name, startedAt.
    #    shortId (background sessions only) is what `claude attach <id>` expects;
    #    sessionId (always present) is what `claude --resume <id>` expects. name/
    #    startedAt are kept as a FALLBACK for sessions whose transcript file no
    #    longer exists on disk (confirmed this happens: old daemon registrations can
    #    outlive their own transcript) -- pass 2 below is otherwise strictly better.
    local agents_file
    agents_file=$(mktemp)

    local sessions_json
    sessions_json=$(claude agents --json --all 2> /dev/null)
    if [[ -n "$sessions_json" && "$sessions_json" != "[]" ]]; then
        echo "$sessions_json" | jq -r '
            .[]
            | [
                .sessionId,
                .kind,
                (.id // ""),
                .cwd,
                (.state // "interactive"),
                (.status // "-"),
                (.waitingFor // "-"),
                (.name // ""),
                (.startedAt // 0)
              ]
            | @tsv
        ' > "$agents_file"
    fi

    # 4. PASS 2 -- every session transcript on disk, the complete/authoritative list
    #    (matches what `claude --resume` / `/resume` shows). Each session is a
    #    top-level UUID.jsonl directly under a project folder -- NOT the nested
    #    subagents/tool-results/ subdirectories some sessions have alongside them,
    #    which hold auxiliary data, not separate sessions (maxdepth 2 excludes those).
    #
    #    Per file we need: last-modified time (a far better "how recent" signal than
    #    the agents API's startedAt, since it reflects last ACTIVITY, not creation),
    #    a display name, and the real working directory.
    #
    #    Name: Claude Code writes repeated `{"type":"agent-name","agentName":"..."}`
    #    lines as a session's name changes (rename, or dispatch-time auto-name), and
    #    `{"type":"ai-title","aiTitle":"..."}` as an auto-generated fallback summary.
    #    The LAST agent-name in the file wins if one ever appears (confirmed this
    #    matches this very session's own /rename'd name); otherwise the last
    #    ai-title; otherwise the session never got a name (rare -- ~14% of
    #    transcripts on this machine, all short/old).
    #
    #    Cwd: every "user"/"attachment" line in the transcript carries the real
    #    Windows working directory as `"cwd":"C:\\Users\\..."` (JSON-escaped, so a
    #    literal backslash appears as TWO characters) -- only the FIRST occurrence is
    #    needed, so grep -m 1 short-circuits per file instead of scanning to the end.
    #
    #    PERFORMANCE NOTE: this used to run ~5 subprocesses PER FILE (basename, 2x
    #    grep, jq, stat) -- 26+ seconds for ~130 sessions on this Windows/Git-Bash
    #    setup, where process-spawn overhead dominates (measured: ~130ms/subprocess
    #    just in sys time). Rewritten to a FIXED number of calls regardless of
    #    session count -- one `find`, two bulk `grep -H` calls covering every file at
    #    once, one `awk` doing all the parsing -- which measured under a second for
    #    the same 130+ sessions.
    local proj_root="$HOME/.claude/projects"
    local jsonl_files=()
    while IFS= read -r -d '' f; do
        jsonl_files+=("$f")
    done < <(find "$proj_root" -maxdepth 2 -name "*.jsonl" -print0 2> /dev/null)

    local mtime_file names_file cwd_file merged_file
    mtime_file=$(mktemp)
    names_file=$(mktemp)
    cwd_file=$(mktemp)
    merged_file=$(mktemp)
    trap 'rm -f "$agents_file" "$mtime_file" "$names_file" "$cwd_file" "$merged_file"' RETURN

    if ((${#jsonl_files[@]} > 0)); then
        find "$proj_root" -maxdepth 2 -name "*.jsonl" -printf '%p\t%T@\n' > "$mtime_file"
        grep -HE '"type":"agent-name"|"type":"ai-title"' "${jsonl_files[@]}" 2> /dev/null > "$names_file"
        grep -H -m 1 '"cwd":"' "${jsonl_files[@]}" 2> /dev/null > "$cwd_file"
    fi

    if [[ ! -s "$agents_file" && ! -s "$mtime_file" ]]; then
        echo "🚫 No Claude Code sessions found."
        return 0
    fi

    # 5. Merge both passes keyed by sessionId. A session tracked live (pass 1) wins
    #    on kind/state/status/waitingFor (only the daemon knows that); the transcript
    #    scan (pass 2) wins on mtime/name/cwd whenever it found a match, since it's
    #    more accurate and complete -- falling back to pass 1's startedAt/name only
    #    for the rare live entry with no matching transcript on disk (see step 3).
    #    A sessionId found ONLY in pass 2 becomes kind="resumable": not something the
    #    daemon is tracking right now, but still fully resumable via `--resume`.
    awk -F'\t' -v onlyRunning="$only_running" '
        ARGIND == 1 {
            # mtime_file: path <TAB> epoch_mtime
            n = split($1, parts, "/")
            sid = parts[n]
            sub(/\.jsonl$/, "", sid)
            sid_of_path[$1] = sid
            scan_mtime[sid] = $2
            all_sid[sid] = 1
            next
        }
        ARGIND == 2 {
            # names_file: raw `grep -H` output, "path:{json...}" per line
            colon = index($0, ":")
            path = substr($0, 1, colon - 1)
            json = substr($0, colon + 1)
            sid = sid_of_path[path]
            if (sid == "") next
            if (match(json, /"agentName":"/)) {
                rest = substr(json, RSTART + RLENGTH)
                if (match(rest, /"/)) {
                    scan_name[sid] = substr(rest, 1, RSTART - 1)
                    has_name[sid] = 1
                }
            } else if (match(json, /"aiTitle":"/)) {
                rest = substr(json, RSTART + RLENGTH)
                if (match(rest, /"/)) scan_title[sid] = substr(rest, 1, RSTART - 1)
            }
            next
        }
        ARGIND == 3 {
            # cwd_file: raw `grep -H -m1` output
            colon = index($0, ":")
            path = substr($0, 1, colon - 1)
            json = substr($0, colon + 1)
            sid = sid_of_path[path]
            if (sid == "") next
            if (match(json, /"cwd":"/)) {
                rest = substr(json, RSTART + RLENGTH)
                if (match(rest, /"/)) {
                    cw = substr(rest, 1, RSTART - 1)
                    gsub(/\\\\/, "\\", cw) # JSON-unescape \\ -> \
                    scan_cwd[sid] = cw
                }
            }
            next
        }
        ARGIND == 4 {
            # agents_file -- the jq @tsv filter doubles every literal backslash
            # (its own escaping for TSV safety), so cwd/name need the same
            # JSON-unescape step as scan_cwd above, or Windows paths render
            # doubled, e.g. C:\\Users\\...
            sid = $1
            live_kind[sid] = $2
            live_shortid[sid] = $3
            live_cwd[sid] = $4
            gsub(/\\\\/, "\\", live_cwd[sid])
            live_state[sid] = $5
            live_status[sid] = $6
            live_waiting[sid] = $7
            live_name[sid] = $8
            gsub(/\\\\/, "\\", live_name[sid])
            live_started[sid] = $9
            is_live[sid] = 1
            all_sid[sid] = 1
            next
        }
        END {
            now = systime()
            for (sid in all_sid) {
                if (sid in is_live) {
                    kind = live_kind[sid]
                    action_id = (live_shortid[sid] != "") ? live_shortid[sid] : sid
                    cwd = (live_cwd[sid] != "") ? live_cwd[sid] : scan_cwd[sid]
                    state = live_state[sid]
                    status = live_status[sid]
                    waiting = live_waiting[sid]
                } else {
                    kind = "resumable"
                    action_id = sid
                    cwd = scan_cwd[sid]
                    state = "idle"
                    status = "-"
                    waiting = "-"
                }

                if (onlyRunning == "true") {
                    active = (state == "blocked" || state == "working" || status == "waiting")
                    if (!active) continue
                }

                if (sid in scan_mtime) {
                    mtime = scan_mtime[sid]
                } else if ((sid in is_live) && (live_started[sid] + 0) > 0) {
                    mtime = live_started[sid] / 1000
                } else {
                    mtime = now
                }

                if (sid in has_name) {
                    name = scan_name[sid]
                } else if (sid in scan_title) {
                    name = scan_title[sid]
                } else if ((sid in is_live) && live_name[sid] != "") {
                    name = live_name[sid]
                } else {
                    name = "(unnamed)"
                }

                proj = (cwd != "") ? cwd : "?"
                if (cwd != "") {
                    m = split(cwd, cparts, "\\")
                    proj = cparts[m]
                }

                printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                    sid, action_id, kind, cwd, name, state, status, waiting, proj, mtime
            }
        }
    ' "$mtime_file" "$names_file" "$cwd_file" "$agents_file" \
        | sort -t $'\t' -k10,10rn -k9,9 > "$merged_file"

    if [[ ! -s "$merged_file" ]]; then
        echo "🚫 No sessions match (drop -r/--running to see all of them)."
        return 0
    fi

    # 6. State glyph + aligned display line, built with awk from the merged file.
    #    Columns: sessionId, actionId, kind, cwd, name, state, status, waitingFor, project, mtime.
    #    Age (duration since mtime) is the first VISIBLE column, per request.
    local display
    display=$(awk -F'\t' '
        function glyph(state, status) {
            if (state == "blocked" || status == "waiting") return "🔴"
            if (state == "working") return "🟡"
            if (state == "interactive") return "🟢"
            if (state == "done") return "✅"
            if (state == "failed") return "❌"
            if (state == "stopped") return "⏹️"
            return "⚪"
        }
        function age(mtime,    s) {
            s = systime() - mtime
            if (s < 60) return sprintf("%ds", s)
            if (s < 3600) return sprintf("%dm", s / 60)
            if (s < 86400) return sprintf("%dh", s / 3600)
            return sprintf("%dd", s / 86400)
        }
        {
            sid = $1; name = $5; state = $6; status = $7; project = $9; mtime = $10
            g = glyph(state, status)
            printf "%s\t%-4s %s %-10s %-28s %s\n", sid, age(mtime), g, state, project, name
        }
    ' "$merged_file")

    # 7. Pipe to fzf. IMPORTANT: fzf.sh (tools/file-management/fzf.sh) exports
    #    FZF_DEFAULT_OPTS globally -- a --preview that runs bat/eza on {}, plus
    #    ctrl-o/ctrl-a/ctrl-x binds that all assume {} is a filesystem path. Standalone
    #    scripts inherit exported vars, so every one of those would misfire on a session
    #    row here. We override --preview/--header/--prompt and all three binds explicitly
    #    -- fzf applies later flags on top of FZF_DEFAULT_OPTS, so these win.
    #    {1} always refers to the ORIGINAL first field (sessionId), regardless of --with-nth.
    local preview_cmd="awk -F'\t' -v sid={1} '\$1==sid{print \"Session: \"\$1; print \"Kind:    \"\$3; print \"Cwd:     \"\$4; print \"Name:    \"\$5; print \"State:   \"\$6; print \"Status:  \"\$7; print \"Waiting: \"\$8}' '$merged_file'"
    local open_cwd_cmd="awk -F'\t' -v sid={1} '\$1==sid{print \$4}' '$merged_file' | xargs -I{} code {}"

    local selected_sid
    selected_sid=$(
        echo "$display" | fzf \
            --height 60% \
            --border=rounded \
            --delimiter='\t' \
            --with-nth=2 \
            --prompt="(Claude Sessions) > " \
            --header=$'ENTER: attach/resume | CTRL-/: toggle preview | CTRL-O: open cwd in VSCode | CTRL-A: copy session id\n🔴 needs input  🟡 working  🟢 interactive  ⚪ idle/other  ❌ failed  ⏹️  stopped' \
            --preview="$preview_cmd" \
            --preview-window='right:50%:hidden:wrap' \
            --bind='ctrl-/:toggle-preview' \
            --bind="ctrl-o:execute($open_cwd_cmd)" \
            --bind="ctrl-a:execute-silent(echo -n {1} | clip)" \
            | cut -f1
    )

    if [[ -z "$selected_sid" ]]; then
        echo "🚫 No session selected."
        return 0
    fi

    # 8. Look up the full row for the chosen sessionId, then attach/resume.
    local row action_id kind cwd name
    row=$(awk -F'\t' -v sid="$selected_sid" '$1==sid' "$merged_file")
    action_id=$(echo "$row" | cut -f2)
    kind=$(echo "$row" | cut -f3)
    cwd=$(echo "$row" | cut -f4)
    name=$(echo "$row" | cut -f5)

    echo "✅ Session selected: $name"

    # Runs in a subshell so the calling shell's pwd is untouched afterward. cd is
    # best-effort -- some very fresh sessions have no cwd on record yet -- and the
    # actual attach/resume always runs regardless of whether cd succeeded, since
    # `claude attach`/`claude --resume` can locate a session by id on their own.
    if [[ "$kind" == "background" ]]; then
        echo "▶️  Attaching to background session: $action_id (cwd: $cwd)"
        (
            # Deliberately NOT `cd ... || exit`: a failed cd must not skip the attach below.
            # shellcheck disable=SC2164
            [[ -n "$cwd" ]] && cd "$cwd" 2> /dev/null
            claude attach "$action_id"
        )
    else
        echo "▶️  Resuming session: $action_id (cwd: $cwd)"
        (
            # See the "Deliberately NOT" comment in the background branch above.
            # shellcheck disable=SC2164
            [[ -n "$cwd" ]] && cd "$cwd" 2> /dev/null
            claude --resume "$action_id"
        )
    fi
}

# CALL FUNCTION

# "$@" is a special variable that represents all the command-line arguments passed to our script.
x-claude-sessions "$@"
