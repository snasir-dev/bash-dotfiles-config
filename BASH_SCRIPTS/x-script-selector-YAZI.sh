#!/bin/bash

# Have added this script to PATH. Can directly call it by stating "x-script-selector-YAZI".
# Aliased/wrapped in aliases/aliases.sh as x-script-selector-yazi / yscripts / xy / XY.

# YAZI-based alternative to x-script-selector.sh: browses bash functions
# (functions/*.sh), standalone scripts (BASH_SCRIPTS/**/*.sh), AND your
# command history ("Command History" -- see BASH_SCRIPTS/yazi-selector/
# build-history.sh) in one Yazi session, using your normal ~/.config/yazi
# keybinds -- no separate Yazi config. Selecting an item (your normal
# "enter" key) opens an action menu instead of blindly running it: execute /
# execute with arguments / open in VS Code for functions & scripts; execute /
# edit & insert into prompt / cd to recorded directory & run / open the raw
# history log in VS Code for a history entry. (Print name / print path /
# copy path were dropped -- Yazi's own default "c" copy submenu already
# covers those.)
#
# Two ways to invoke it, via aliases/aliases.sh:
#   - typed "xy" (x-script-selector-yazi):        runs the selection immediately.
#   - Alt+G (x-script-selector-yazi-insert):       INSERTS it at your cursor
#     instead -- see BASH_SELECTOR_INSERT below and config/bash_keybinds.sh.
#
# See BASH_SCRIPTS/yazi-selector/ for the cache builder (build-index.sh), the
# plugin source (plugin/main.lua, synced into ~/.config/yazi/plugins), and
# descriptions.json -- the file to edit when adding or describing entries.
#
# Usage: x-script-selector-YAZI.sh [--rebuild]
#   --rebuild   force the cache to regenerate even if nothing looks stale.

x-script-selector-YAZI() {
    local sel_dir="$BASH_DIR/BASH_SCRIPTS/yazi-selector"
    local cache="$HOME/.cache/bash-selector"
    local yazi_home="${YAZI_CONFIG_HOME:-$HOME/.config/yazi}"
    local plug_src="$sel_dir/plugin/main.lua"
    local plug_dst="$yazi_home/plugins/bash-selector.yazi/main.lua"

    if [[ ! -f "$sel_dir/descriptions.json" ]]; then
        echo "❌ Error: selector directory not found at '$sel_dir'" >&2
        return 1
    fi

    # Keep the installed plugin copy in sync with the version-controlled one.
    if [[ ! -f "$plug_dst" ]] || [[ "$plug_src" -nt "$plug_dst" ]]; then
        mkdir -p "$(dirname "$plug_dst")"
        cp "$plug_src" "$plug_dst"
    fi

    # shellcheck source=yazi-selector/build-index.sh
    source "$sel_dir/build-index.sh" "$1" # forwards --rebuild if given

    mkdir -p "$cache"
    local out="$cache/.out"
    : > "$out"

    # Env vars are only set for this one command, so nothing leaks into the
    # calling shell -- the plugin (same process tree) reads them via getenv.
    # BASH_SELECTOR_BASH/_HISTORY_SCRIPT: Yazi is a native Windows binary, so
    # the plugin needs Windows-style paths (via `cygpath -w`) to shell out to
    # bash.exe and run build-history.sh when "Command History" is entered --
    # see plugin/main.lua's entry() and build-history.sh's own header for why
    # that's a real, felt wait, not instant.
    BASH_SELECTOR_OUT="$out" BASH_SELECTOR_CACHE="$cache" \
        BASH_SELECTOR_BASH="$(cygpath -w "$(command -v bash)")" \
        BASH_SELECTOR_HISTORY_SCRIPT="$(cygpath -w "$sel_dir/build-history.sh")" \
        yazi "$cache/tree"

    if [[ ! -s "$out" ]]; then
        echo "🚫 Nothing selected."
        return 0
    fi

    local action kind invoke realpath line
    {
        read -r action
        read -r kind
        read -r invoke
        read -r realpath
        read -r line
    } < "$out"

    # `kind` (not `realpath`) is the right emptiness check here: a history
    # entry legitimately CAN have an empty realpath (recorded cwd), when the
    # command was seeded from ~/.bash_history before any directory was ever
    # logged for it -- but `kind` is only ever empty when nothing was
    # actually resolved (ya.which cancelled, or $out never got written).
    if [[ -z "$kind" ]]; then
        echo "❌ Error: selector produced no usable selection." >&2
        return 1
    fi

    # History entries carry their command text ESCAPED (backslash/newline/
    # tab -- see bash-history-log.sh) in `invoke`, exactly as it sits in
    # history.tsv and history.lua. Decode it HERE, once, in the one place
    # every history action (exec/insert/cd) needs it -- NOT via `printf %b`
    # or sequential sed/gsub passes: unescaping \\, \n, \t as three SEPARATE
    # global substitutions is ambiguous whenever a literal backslash in the
    # original command precedes an 'n' or 't' (e.g. `printf "\n"`,
    # `sed 's/\t/ /'`) -- a later pass can't tell "backslash that came from
    # doubling an original backslash" apart from "backslash that starts a
    # still-unprocessed \n/\t marker". A single left-to-right scan (below)
    # doesn't have that ambiguity: once it consumes a `\\` pair as one
    # literal backslash, it never re-examines the second byte of that pair.
    # (Verified against printf/sed-style adversarial cases -- see
    # build-history.sh's identical decoder for the full write-up.)
    if [[ "$kind" == "history" ]]; then
        invoke=$(awk '
            function unescape(s,    out, i, c, nc, n) {
                out = ""
                n = length(s)
                i = 1
                while (i <= n) {
                    c = substr(s, i, 1)
                    if (c == "\\" && i < n) {
                        nc = substr(s, i + 1, 1)
                        if (nc == "n") { out = out "\n"; i += 2; continue }
                        if (nc == "t") { out = out "\t"; i += 2; continue }
                        if (nc == "\\") { out = out "\\"; i += 2; continue }
                        out = out c
                        i += 1
                        continue
                    }
                    out = out c
                    i += 1
                }
                return out
            }
            { printf "%s", unescape($0) }
        ' <<< "$invoke")
    fi

    case "$action" in
        code)
            code -g "$realpath:$line"
            ;;
        open-log)
            # kind=history only. Opens the RAW log every Recent/Frequent
            # entry is generated from -- not the cache tree you're currently
            # browsing (that's disposable, rebuilt from this on every
            # rebuild), and not anything in this repo either (it's per-
            # machine data, deliberately not version-controlled). See
            # tools/shell-utility-and-system/bash-history-log.sh for the
            # writer.
            local hist_log="$HOME/.local/share/bash-history/history.tsv"
            if [[ -f "$hist_log" ]]; then
                code -g "$hist_log"
            else
                code "$HOME/.local/share/bash-history"
            fi
            ;;
        cd)
            # kind=history only (see plugin/main.lua's ACTIONS_HISTORY).
            local cmd="cd \"$realpath\" 2>/dev/null; $invoke"
            if [[ -n "$BASH_SELECTOR_CMD" ]]; then
                printf '%s\n' "$cmd" > "$BASH_SELECTOR_CMD"
            else
                eval "$cmd"
            fi
            ;;
        insert)
            # kind=history only -- land it at your cursor, editable, and
            # NEVER auto-run, regardless of how `xy` was invoked (unlike
            # exec/args below, whose insert-vs-run split depends on
            # BASH_SELECTOR_INSERT / which alias launched the selector).
            if [[ -n "$BASH_SELECTOR_INSERT" ]]; then
                # Alt+G: the outer wrapper (x-script-selector-yazi-insert in
                # aliases.sh) places $BASH_SELECTOR_CMD's content at
                # READLINE_POINT for us -- nothing more to do here.
                [[ -n "$BASH_SELECTOR_CMD" ]] && printf '%s' "$invoke" > "$BASH_SELECTOR_CMD"
            else
                # Plain `xy`: this runs as a child process the wrapper only
                # `source`s the RESULT of, not an interactive bind -x context
                # -- there's no READLINE_LINE to manipulate from here. `read
                # -e -i` pre-fills an editable line instead (bash 4+), giving
                # the same "land it, keep typing, Enter when ready" feel as
                # fzf's Ctrl-R.
                local edited
                read -r -e -i "$invoke" -p "▶  " edited
                if [[ -n "$BASH_SELECTOR_CMD" ]]; then
                    printf '%s\n' "$edited" > "$BASH_SELECTOR_CMD"
                else
                    eval "$edited"
                fi
            fi
            ;;
        exec | args)
            local cmd
            if [[ -n "$BASH_SELECTOR_INSERT" ]]; then
                # Insert-widget mode (x-script-selector-yazi-insert in aliases.sh):
                # functions are already defined in any normal interactive shell, so
                # just insert the bare callable text -- no source-preamble, nothing
                # ugly ends up on the user's prompt line to edit around.
                if [[ "$kind" == "functions" || "$kind" == "history" ]]; then
                    cmd="$invoke"
                else
                    cmd="\"$realpath\""
                fi
                [[ "$action" == "args" ]] && cmd="$cmd "
            else
                if [[ "$kind" == "functions" ]]; then
                    cmd="source \"$realpath\" >/dev/null 2>&1; $invoke"
                elif [[ "$kind" == "history" ]]; then
                    cmd="$invoke"
                else
                    cmd="\"$realpath\""
                fi
                if [[ "$action" == "args" ]]; then
                    local extra
                    read -r -e -p "▶  ${invoke:-$(basename "$realpath")} " extra
                    [[ -n "$extra" ]] && cmd="$cmd $extra"
                fi
            fi
            if [[ -n "$BASH_SELECTOR_CMD" ]]; then
                # Wrapper (aliases.sh) will `source` this in the CURRENT shell,
                # so cd/env changes made by the command actually stick.
                printf '%s\n' "$cmd" > "$BASH_SELECTOR_CMD"
            else
                # Standalone fallback: no wrapper is sourcing our output, so
                # just run it here (any `cd`/env changes won't persist).
                eval "$cmd"
            fi
            ;;
        *)
            echo "❌ Error: unknown action '$action'." >&2
            return 1
            ;;
    esac
}

# CALL FUNCTION
x-script-selector-YAZI "$@"
