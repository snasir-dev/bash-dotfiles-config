#!/bin/bash
# Aggregator for the Yazi selector's "Command History" view
# (BASH_SCRIPTS/x-script-selector-YAZI.sh). Reads the TSV log written by
# tools/shell-utility-and-system/bash-history-log.sh, collapses it to one row
# per unique command, and materializes three folders inside the selector's
# cache tree:
#
#   $HOME/.cache/bash-selector/tree/Command History/
#   ├── Recent/     0001 · <command>.sh   -- most-recently-run first
#   ├── Frequent/   0001 · <command>.sh   -- highest zoxide-style frecency first
#   └── By Tool/                          -- same top-maxn pool as Frequent,
#       ├── git/    0001 · <command>.sh      filed under EVERY recognized tool
#       ├── rg/     0001 · <command>.sh      a command uses (pipeline-aware --
#       └── ...                              "cut … | awk …" lands in both).
#                                            Aliases (lg, ccfast, ...) resolve
#                                            to their real tool first, via the
#                                            map build-index.sh dumps from
#                                            `alias -p` -- see command_tools().
#
# plus $HOME/.cache/bash-selector/history.lua, dofile'd by both
# plugin/main.lua (to resolve a hovered entry back to its real command) and
# ~/.config/yazi/init.lua (to render the right-column linemode + hover line --
# merged straight into the same BASH_SELECTOR_DESCS table functions/scripts
# already populate, so no new display code path is needed there).
#
# Invoked LAZILY -- only the first time "Command History" is entered in Yazi
# (see plugin/main.lua) -- so opening `xy` itself never gets slower as your
# history grows.
#
# PERFORMANCE: parsing, aggregating, frecency scoring, both rankings, filename
# sanitizing, per-entry file writing, AND emitting history.lua all happen in
# ONE gawk process (PROCINFO["sorted_in"] does the ranking -- no external
# `sort`). build-index.sh's approach of shelling out to `jq` once per entry is
# fine at ~50 functions (~50ms each) but would cost ~100s at 2000 entries; a
# single awk pass over the same data is far cheaper -- but NOT free: creating
# (and, on a rebuild, first deleting) up to 2*maxn real files is genuinely
# felt time on this filesystem, not a rounding error, mostly independent of
# per-file content size once it's this small. Measured on this machine at the
# default maxn=500 (1000 files total): ~0.8s clean, scaling up roughly
# linearly with maxn (raise BASH_HISTORY_MAX_ENTRIES for more history at the
# cost of a slower rebuild). That's why: (a) the default cap is 500, not more,
# and (b) the staleness gate below debounces -- see the comment there --
# instead of repaying that cost every time you re-enter "Command History"
# after typing anything anywhere, which the capture hook makes the common
# case, not a rare one.
#
# Usage: build-history.sh [--rebuild]

_bash_history_build() {
    local log="$HOME/.local/share/bash-history/history.tsv"
    local cache="$HOME/.cache/bash-selector"
    local tree="$cache/tree/Command History"
    local bytool_dir="$tree/By Tool"
    local aliasfile="$cache/aliases.txt"
    local luafile="$cache/history.lua"
    local stamp="$cache/history-stamp"
    local maxn="${BASH_HISTORY_MAX_ENTRIES:-500}"
    local max_per_tool="${BASH_HISTORY_MAX_PER_TOOL:-100}"
    local debounce="${BASH_HISTORY_REBUILD_DEBOUNCE:-30}"

    # Written by build-index.sh (source'd from the interactive shell, so it
    # can see aliases this non-interactive process can't) -- see that file's
    # step 0. Guard its existence rather than its content: a brand-new
    # machine where `xy` has never run yet shouldn't hard-fail here, it
    # should just resolve zero aliases.
    [[ -f "$aliasfile" ]] || : > "$aliasfile"

    # No log yet (hook never fired, or this is a brand new machine) -- just
    # make sure the tree/lua exist in a valid, empty state and bail.
    if [[ ! -s "$log" ]]; then
        mkdir -p "$tree/Recent" "$tree/Frequent" "$bytool_dir"
        printf 'return {}\n' > "$luafile"
        touch "$stamp"
        return 0
    fi

    # ---- staleness gate -----------------------------------------------------
    # Measured on this machine: a full rebuild costs real, felt time (~0.8s at
    # the default 500-per-view cap; scales up from there) -- it's a `rm -rf` +
    # up to 2*maxn file writes, not a cheap check. Plain "$log -nt $stamp"
    # alone would repay that EVERY time you re-enter Command History after
    # typing even one command anywhere (the capture hook advances $log's mtime
    # on every command) -- a common pattern, not an edge case. So: a genuine
    # staleness (log changed) only forces a rebuild if the LAST rebuild was
    # more than $debounce seconds ago; a quick re-visit reuses the still-
    # recent build instead. --rebuild always forces, ignoring all of this.
    local stale=0
    if [[ "$1" == "--rebuild" ]]; then
        stale=1
    elif [[ ! -f "$stamp" ]]; then
        stale=1
    elif [[ "$log" -nt "$stamp" ]]; then
        local stamp_epoch
        stamp_epoch=$(date -r "$stamp" +%s 2> /dev/null || echo 0)
        (( EPOCHSECONDS - stamp_epoch >= debounce )) && stale=1
    fi
    [[ $stale -eq 0 ]] && return 0

    rm -rf "$tree"
    mkdir -p "$tree/Recent" "$tree/Frequent" "$bytool_dir"

    awk -v recent_dir="$tree/Recent" -v frequent_dir="$tree/Frequent" -v bytool_dir="$bytool_dir" \
        -v maxn="$maxn" -v max_per_tool="$max_per_tool" -v now="$EPOCHSECONDS" -v luafile="$luafile" \
        -F'\t' '
    # ---- alias map (crosses the bash/awk process boundary) --------------
    # build-history.sh runs as a separate, non-interactive bash process
    # (shelled out to by plugin/main.lua), so it cannot see the caller'"'"'s
    # aliases directly -- aliasfile is how build-index.sh'"'"'s `alias -p` dump
    # gets here. FNR==NR is only true while reading the FIRST file below
    # (aliasfile); once the log file starts, FNR resets to 1 while NR keeps
    # climbing, so this rule stops matching on its own -- standard awk
    # multi-file idiom, no explicit file-boundary bookkeeping needed. Every
    # line here unconditionally `next`s, whether or not it matched the alias
    # regex, so nothing from aliasfile ever reaches the log-parsing rule
    # below. Format is raw `alias -p` output, always single-quoted by bash.
    FNR == NR {
        # Name class is deliberately permissive ([^ \t=]+, not an identifier
        # pattern) -- real alias names in this config include hyphens
        # (claude-fast), leading dots (.DIR_apps), and even a colon (c:).
        # Whatever the shell itself accepted as a name, accept it back.
        if (match($0, /^alias [^ \t=]+=/)) {
            aname = substr($0, RSTART + 6, RLENGTH - 7)
            atgt = substr($0, RSTART + RLENGTH)
            if (substr(atgt, 1, 1) == "\047" && substr(atgt, length(atgt), 1) == "\047") {
                atgt = substr(atgt, 2, length(atgt) - 2)
            }
            amap[aname] = atgt
        }
        next
    }

    # ---- helpers --------------------------------------------------------

    # Windows-illegal filename chars -> visually-similar Unicode lookalikes.
    # Same trick as build-index.sh uses to keep generated filenames real,
    # runnable-looking, ".sh"-suffixed entries Yazi will syntax-highlight.
    function sanitize(s,    out) {
        out = s
        gsub(/\\/, "⧵", out)
        gsub(/\//, "∕", out)
        gsub(/:/, "∶", out)
        gsub(/\*/, "∗", out)
        gsub(/\?/, "？", out)
        gsub(/"/, "″", out)
        gsub(/</, "‹", out)
        gsub(/>/, "›", out)
        gsub(/\|/, "¦", out)
        gsub(/[\001-\037]/, " ", out)   # stray control bytes, just in case
        gsub(/[ .]+$/, "", out)         # Windows: no trailing space/dot
        if (length(out) > 140) out = substr(out, 1, 140)
        gsub(/[ .]+$/, "", out)         # re-trim in case truncation left one
        if (out == "") out = "(blank)"
        return out
    }

    # ---- tool extraction for "By Tool" -----------------------------------
    # A command is filed under EVERY recognized tool it uses, not just its
    # leading word -- grouping by first-word alone would miss ripgrep/awk/
    # bat/etc., which almost never lead a real command (they sit mid-
    # pipeline: `cut ... | awk ...`). Builtins/no-ops are dropped so "cd",
    # "echo", etc. never get their own folder.

    # Repeatedly strips a leading env assignment (FOO=bar) or wrapper command
    # (sudo, command, env, time, nohup, builtin, exec) so the real tool
    # underneath is what gets matched, e.g. `sudo bat file` -> `bat`,
    # `FOO=1 awk ...` -> `awk`. Bounded by toolof()'"'"'s own depth cap, not
    # here, since this can also be re-entered after an alias substitution.
    function strip_prefix(s,    changed) {
        changed = 1
        while (changed) {
            changed = 0
            if (match(s, /^[A-Za-z_][A-Za-z0-9_]*=[^ \t]*[ \t]+/)) {
                s = substr(s, RSTART + RLENGTH)
                changed = 1
            } else if (match(s, /^(sudo|command|env|time|nohup|builtin|exec)[ \t]+/)) {
                s = substr(s, RSTART + RLENGTH)
                changed = 1
            }
        }
        return s
    }

    # First word of a (possibly prefix-stripped) segment, with surrounding
    # quotes, any leading path, and a .exe suffix removed -- so
    # `"/usr/bin/git"` and `git.exe` both normalize to `git`.
    function clean_token(t,    q) {
        q = "\047"
        while (substr(t, 1, 1) == q || substr(t, 1, 1) == "\"") t = substr(t, 2)
        while (length(t) > 0 && (substr(t, length(t), 1) == q || substr(t, length(t), 1) == "\"")) {
            t = substr(t, 1, length(t) - 1)
        }
        sub(/.*\//, "", t)
        sub(/\.exe$/, "", t)
        return t
    }

    # Resolves one pipeline segment down to the tool that actually runs.
    # Loops (bounded to 5 hops) because an alias'"'"'s OWN target can carry
    # further env assignments/wrappers -- e.g. ccfast is defined as
    # `MAX_THINKING_TOKENS=0 command claude --model sonnet ...`, which only
    # resolves to "claude" if stripping re-runs AFTER the alias substitution,
    # not just before it.
    function toolof(seg,    s, t, w, depth) {
        s = seg
        for (depth = 0; depth < 5; depth++) {
            s = strip_prefix(s)
            sub(/^[ \t]+/, "", s)
            split(s, w, /[ \t]+/)
            t = clean_token(w[1])
            if (t == "") return ""
            if (t in amap) { s = amap[t]; continue }
            return t
        }
        return t
    }

    function is_noise(t) {
        return (t ~ /^(cd|echo|export|source|\.|set|unset|alias|pwd|printf|read|exit|clear|true|false|:|local|declare|eval|test|\[|shift|return|history|type|which)$/)
    }

    # Populates arr[1..N] (1-indexed, caller-owned) with the distinct
    # recognized tools used by command c and returns N. Pipeline/list-aware:
    # splits on |, ||, &&, ; first. Pure/deterministic -- safe to call twice
    # for the same c, which the END block below deliberately does (once to
    # decide which tool folders need creating, once to actually write files).
    function command_tools(c, arr,    cmd, segs, n, i, t, seen, nt) {
        cmd = c
        gsub(/\|\||&&/, "|", cmd)
        gsub(/;/, "|", cmd)
        n = split(cmd, segs, "|")
        nt = 0
        delete seen
        for (i = 1; i <= n; i++) {
            t = toolof(segs[i])
            if (t == "" || is_noise(t) || t ~ /^[^A-Za-z_]/) continue
            if (!(t in seen)) {
                seen[t] = 1
                arr[++nt] = t
            }
        }
        return nt
    }

    # Lua `"..."` literal escaping. The text being embedded is already in
    # bash-history-log.sh'"'"'s app-level escaped form (backslash -> \\, real
    # newline -> literal \n, real tab -> literal \t) -- this is a SEPARATE,
    # outer layer: Lua does not know or care what those bytes "mean" at the
    # app level, it just needs valid Lua source representing the exact same
    # bytes back. Composing the two layers this way is correct; see
    # x-script-selector-YAZI.sh for where the app-level layer gets decoded.
    function luastr(s,    out) {
        out = s
        gsub(/\\/, "\\\\", out)
        gsub(/"/, "\\\"", out)
        gsub(/\n/, "\\n", out)
        gsub(/\t/, "\\t", out)
        return out
    }

    # ---- pass 1: aggregate by (already-escaped) command text ------------
    {
        if (NF < 6) next
        epoch = $1 + 0
        ex = $2 + 0
        cwd = $5
        cmd = $6
        for (i = 7; i <= NF; i++) cmd = cmd "\t" $i   # defensive rejoin
        if (cmd == "") next

        if (!(cmd in count)) order[++total] = cmd
        count[cmd]++
        last_ts[cmd] = epoch      # file is append-only -> last occurrence wins
        last_exit[cmd] = ex

        # Only a COUNT of unique directories + the most recent one is kept --
        # not the full list -- since that'"'"'s all the (deliberately slim, see
        # emit_entry) per-file preview actually displays. No cap needed: this
        # is now a cheap membership check, not string storage per directory.
        if (cwd != "") {
            dkey = cmd SUBSEP cwd
            if (!(dkey in dir_seen)) {
                dir_seen[dkey] = 1
                dir_n[cmd]++
            }
            last_cwd[cmd] = cwd
        }
    }

    # ---- pass 2: frecency + both rankings + file/lua output -------------
    END {
        for (i = 1; i <= total; i++) {
            c = order[i]
            age = now - last_ts[c]
            if (age < 0) age = 0
            if (age <= 3600) mult = 4
            else if (age <= 86400) mult = 2
            else if (age <= 604800) mult = 0.5
            else mult = 0.25
            score[c] = count[c] * mult
        }

        # NOTE: history.lua is NESTED (`recent = {...}, frequent = {...}`),
        # NOT one flat map. A single command commonly lands on the identical
        # rank in BOTH views (your newest command is often also a frequent
        # one) -- a flat map keyed only by filename would then have to pick
        # ONE view'"'"'s display data to win, silently showing the wrong right-
        # column format (e.g. a frecency score under Recent). Nesting means
        # each view keeps its own correct description_linemode_col, and the
        # Lua side disambiguates which sub-table to read using
        # cx.active.current.cwd (an already-proven API -- see bunny.yazi and
        # simple-tag.yazi, both already installed) rather than guessing from
        # the bare filename alone.
        lua = "return {\n  recent = {\n"

        PROCINFO["sorted_in"] = "@val_num_desc"

        rank = 0
        for (c in last_ts) {
            rank++
            if (rank > maxn) break
            lua = lua emit_entry(c, recent_dir, rank, "recent")
        }

        lua = lua "  },\n  frequent = {\n"

        rank = 0
        for (c in score) {
            rank++
            if (rank > maxn) break
            lua = lua emit_entry(c, frequent_dir, rank, "frequent")
        }

        lua = lua "  },\n"

        # ---- By Tool: same top-maxn pool as Frequent, filed per tool --------
        # Two passes over that identical pool (score-sorted -- PROCINFO
        # ["sorted_in"] set above still applies, so `for (c in score)` visits
        # commands in the same order both times):
        #   pass A only COLLECTS the distinct tool names, so every subfolder
        #   can be created in ONE batched `mkdir -p` call below. Measured on
        #   this machine: one system() call creating ~25 dirs costs ~65ms;
        #   25 SEPARATE system() calls (one per tool, the naive way to do
        #   this) cost ~700ms -- more than the rest of a rebuild combined,
        #   dominated by per-call process-spawn overhead on Windows, not the
        #   mkdir itself.
        #   pass B re-walks the identical pool and actually writes the files
        #   -- command_tools() is pure, so recomputing it a second time is
        #   cheap (string ops over <=maxn short commands) and safe.
        delete all_tools
        rank = 0
        for (c in score) {
            rank++
            if (rank > maxn) break
            nt = command_tools(c, ctools)
            for (ti = 1; ti <= nt; ti++) all_tools[ctools[ti]] = 1
        }
        if (length(all_tools) > 0) {
            mkcmd = "mkdir -p"
            for (t in all_tools) mkcmd = mkcmd " \"" bytool_dir "/" sanitize(t) "\""
            system(mkcmd)
        }

        lua = lua "  bytool = {\n"

        rank = 0
        for (c in score) {
            rank++
            if (rank > maxn) break
            nt = command_tools(c, ctools)
            for (ti = 1; ti <= nt; ti++) {
                t = ctools[ti]
                st = sanitize(t)
                tool_total_cmds[st]++
                tool_total_runs[st] += count[c]
                if (last_ts[c] > tool_last_ts[st]) tool_last_ts[st] = last_ts[c]
                # Unconditional above (folder header stays accurate even past
                # the cap); gated here -- max_per_tool only bounds how many
                # FILES one dominant tool (e.g. git) gets to write.
                if (tool_rank[st] < max_per_tool) {
                    tool_rank[st]++
                    # `view` doubles as emit_entry'"'"'s used_cmd[] collision
                    # scope AND its recent-vs-frecency column-style switch --
                    # passing the tool name here is exactly right for both:
                    # it scopes collisions per tool FOLDER (mirroring how
                    # "recent"/"frequent" already scope per view), and no
                    # real tool is literally named "recent", so every tool
                    # folder correctly gets the "×count · score" column style.
                    lua = lua emit_entry(c, bytool_dir "/" st, tool_rank[st], st)
                }
            }
        }

        lua = lua "  },\n  bytool_dirs = {\n"

        # One entry per TOOL FOLDER itself (not per command) -- keyed by the
        # plain sanitized tool name, no rank prefix, matching the "By Tool"
        # rows Yazi lists (its directories). This is what gives the folders
        # themselves a right-hand column.
        for (st in tool_total_cmds) {
            lua = lua sprintf("    [%s] = { description_linemode_col = %s, desc = %s },\n",
                luaquote(st),
                luaquote(sprintf("%d cmds · %d runs", tool_total_cmds[st], tool_total_runs[st])),
                luaquote(sprintf("%d distinct commands, %d total runs · last used %s",
                    tool_total_cmds[st], tool_total_runs[st], strftime("%Y-%m-%d %H:%M", tool_last_ts[st]))))
        }

        lua = lua "  },\n}\n"
        print lua > luafile
        close(luafile)
    }

    # Writes one entry'"'"'s cache file + returns its history.lua table fragment.
    # `used_cmd[]` disambiguates a filename collision WITHIN one view only
    # (keyed by view SUBSEP name) -- matching the fact that Recent/ and
    # Frequent/ are separate directories on disk, a name only needs to be
    # unique within its own folder. A collision here means two DIFFERENT
    # commands sanitized+truncated to the identical text at the identical
    # rank (only possible past the 140-char truncation point) -- rare, but
    # handled so neither entry is silently dropped.
    function emit_entry(c, dir, rank, view,    base, orig_name, name, n, ukey, disp, hdr, body, outfile, colcol, descmsg, dirsmsg) {
        base = sanitize(c)
        orig_name = sprintf("%04d · %s", rank, base)
        name = orig_name
        ukey = view SUBSEP name
        if ((ukey in used_cmd) && used_cmd[ukey] != c) {
            n = 1
            while ((ukey in used_cmd) && used_cmd[ukey] != c) {
                name = orig_name " ⁝" sprintf("%04x", n)
                ukey = view SUBSEP name
                n++
            }
        }
        used_cmd[ukey] = c
        disp = name ".sh"
        outfile = dir "/" disp

        if (dir_n[c] + 0 <= 1) {
            dirsmsg = (dir_n[c] + 0 == 1) ? last_cwd[c] : "(unknown directory)"
        } else {
            dirsmsg = sprintf("%s  (+%d more)", last_cwd[c], dir_n[c] - 1)
        }

        # Kept deliberately short: PER-FILE CONTENT SIZE, not just file count,
        # is what actually costs time to write at this scale (measured: 4000
        # files with a ~500-byte header ≈3.3s vs ~1.5s with a one-line body --
        # content size dominates over file count once the count itself is
        # bounded by maxn). The fuller picture (every directory, every recent
        # run) still lives in history.lua'"'"'s `desc`/`example` fields either way
        # -- nothing is lost, it just isn'"'"'t duplicated into every single file.
        hdr = sprintf("# %s\n# ×%d runs  ·  rank #%d (%s)  ·  frecency %.1f  ·  exit %d\n# Last run:  %s\n# From:      %s\n\n",
            disp, count[c], rank, view, score[c], last_exit[c], strftime("%Y-%m-%d %H:%M:%S", last_ts[c]), dirsmsg)

        body = hdr c "\n"
        print body > outfile
        close(outfile)

        if (view == "recent") {
            colcol = strftime("%Y-%m-%d %H:%M", last_ts[c])
        } else {
            colcol = sprintf("×%d · %.1f", count[c], score[c])
        }
        descmsg = sprintf("Run %dx  ·  last %s  ·  exit %d  ·  %s", count[c], strftime("%Y-%m-%d %H:%M", last_ts[c]), last_exit[c], dirsmsg)

        return sprintf("  [%s] = { cmd = \"%s\", cwd = \"%s\", count = %d, score = %.1f, rank = %d, view = %s, last_ts = %d, last_exit = %d, description_linemode_col = \"%s\", desc = \"%s\", example = \"%s\" },\n",
            luaquote(disp), luastr(c), luastr(last_cwd[c]), count[c], score[c], rank, luaquote(view),
            last_ts[c], last_exit[c], luastr(colcol), luastr(descmsg), luastr(c))
    }

    function luaquote(s) { return "\"" luastr(s) "\"" }
    ' "$aliasfile" "$log"

    touch "$stamp"
}

_bash_history_build "$@"
