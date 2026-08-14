#!/bin/bash

# Have added this script to PATH. Can directly call it by stating "x-script-selector-YAZI".
# Aliased/wrapped in aliases/aliases.sh as x-script-selector-yazi / yscripts / xy / XY.

# YAZI-based alternative to x-script-selector.sh: browses BOTH bash functions
# (functions/*.sh) and standalone scripts (BASH_SCRIPTS/**/*.sh) in one Yazi
# session, using your normal ~/.config/yazi keybinds -- no separate Yazi
# config. Selecting an item (your normal "enter" key) opens an action menu
# (execute / execute with arguments / open in VS Code) instead of blindly
# running it. (Print name / print path / copy path were dropped -- Yazi's
# own default "c" copy submenu already covers those.)
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
    BASH_SELECTOR_OUT="$out" BASH_SELECTOR_CACHE="$cache" yazi "$cache/tree"

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

    if [[ -z "$realpath" ]]; then
        echo "❌ Error: selector produced no usable selection." >&2
        return 1
    fi

    case "$action" in
        code)
            code -g "$realpath:$line"
            ;;
        exec | args)
            local cmd
            if [[ "$kind" == "functions" ]]; then
                cmd="source \"$realpath\" >/dev/null 2>&1; $invoke"
            else
                cmd="\"$realpath\""
            fi
            if [[ "$action" == "args" ]]; then
                local extra
                read -r -e -p "▶  ${invoke:-$(basename "$realpath")} " extra
                [[ -n "$extra" ]] && cmd="$cmd $extra"
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
