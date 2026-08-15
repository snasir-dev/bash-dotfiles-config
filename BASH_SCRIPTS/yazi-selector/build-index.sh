#!/bin/bash
# Cache builder for the Yazi-based bash function/script selector
# (BASH_SCRIPTS/x-script-selector-YAZI.sh). This file is `source`d, not run
# standalone -- a cache hit just `return 0`s straight back to the caller.
#
# Rebuilds $HOME/.cache/bash-selector/ (a small filesystem Yazi can browse)
# whenever functions/*.sh, BASH_SCRIPTS/**/*.sh, or descriptions.json changed
# since the last build. On a cache hit this costs one `find -newer`; nothing
# else runs. Pass --rebuild to force it regardless of mtimes.
#
# Layout produced:
#   $HOME/.cache/bash-selector/
#   ├── stamp        staleness marker
#   ├── index.tsv    kind⇥name⇥realpath⇥line⇥cachepath  (debugging aid only)
#   ├── index.lua    same data + descriptions.json, dofile'd by the Lua side
#   └── tree/
#       ├── Command History/   EMPTY here -- populated lazily, on first entry,
#       │                      by build-history.sh (see plugin/main.lua). Kept
#       │                      empty at this stage so `xy` startup cost never
#       │                      grows with how much history you've accumulated.
#       ├── Functions/   one generated file per bash function (real source)
#       └── Scripts/     verbatim copies of BASH_SCRIPTS/**/*.sh

_bash_selector_build_index() {
    local fn_dir="$BASH_DIR/functions"
    local sc_dir="$BASH_DIR/BASH_SCRIPTS"
    local sel_dir="$sc_dir/yazi-selector"
    local json="$sel_dir/descriptions.json"
    local cache="$HOME/.cache/bash-selector"
    local stamp="$cache/stamp"

    # ---- staleness gate ----------------------------------------------------
    local stale=0
    [[ "$1" == "--rebuild" ]] && stale=1
    [[ -f "$stamp" ]] || stale=1
    [[ "$json" -nt "$stamp" ]] && stale=1
    if [[ $stale -eq 0 ]]; then
        [[ -n $(find "$fn_dir" "$sc_dir" -maxdepth 5 -name '*.sh' -newer "$stamp" -print -quit 2> /dev/null) ]] && stale=1
    fi
    [[ $stale -eq 0 ]] && return 0

    echo "🔄  Rebuilding bash-selector cache..." >&2

    rm -rf "$cache"
    # "Command History" is created empty -- build-history.sh populates it
    # lazily the first time it's entered in Yazi (see plugin/main.lua), and
    # its own staleness stamp (history-stamp) lives right here, so wiping the
    # whole cache on a functions/scripts change just means the very next
    # "Command History" visit rebuilds it once more -- cheap, and correct.
    mkdir -p "$cache/tree/Command History" "$cache/tree/Functions" "$cache/tree/Scripts"
    local idx="$cache/index.tsv"
    : > "$idx"

    # ---- 1. extract every top-level function's source into its own file ----
    # Start regex mirrors function_list_all_table() in _general-functions.sh.
    # A function's end is the first column-0 "}" after it -- reliable here
    # because .editorconfig enforces shfmt's binary_next_line brace style.
    # Cache files get a ".sh" suffix (name != the actual bash function name,
    # which has no extension) purely so Yazi's mime-sniffing recognizes them
    # as shell scripts and syntax-highlights them -- same "code"/syntect
    # previewer already configured for every other text file, at no extra
    # cost. index.lua's `invoke` field carries the real, callable name.
    awk -v outdir="$cache/tree/Functions" -v idxfile="$idx" '
        FNR == 1 { capturing = 0 }
        /^[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{/ {
            match($0, /^[a-zA-Z_][a-zA-Z0-9_]*/)
            name = substr($0, RSTART, RLENGTH)
            outfile = outdir "/" name ".sh"
            print "#!/bin/bash" > outfile
            print $0 >> outfile
            printf "functions\t%s\t%s\t%d\t%s\n", name, FILENAME, FNR, outfile >> idxfile
            capturing = 1
            next
        }
        capturing && /^\}[[:space:]]*$/ { print $0 >> outfile; capturing = 0; next }
        capturing { print $0 >> outfile }
    ' "$fn_dir"/*.sh

    # Drop names listed under "hidden" in descriptions.json (internal helpers
    # like render_tree_level, or the _j_* completion internals).
    # NOTE: jq is a native Windows binary here, so piped output is CRLF --
    # `tr -d '\r'` strips it, otherwise "name\r" never matches "name" below.
    local h
    while IFS= read -r h; do
        [[ -z "$h" ]] && continue
        rm -f "$cache/tree/Functions/$h.sh"
        grep -v -F $'\t'"$h"$'\t' "$idx" > "$idx.tmp" 2> /dev/null && mv "$idx.tmp" "$idx"
    done <<< "$(jq -r '.hidden[]? // empty' "$json" 2> /dev/null | tr -d '\r')"

    # ---- 2. copy every script verbatim, mirroring subfolders ----------------
    local f rel dest
    while IFS= read -r f; do
        rel="${f#"$sc_dir"/}"
        case "$rel" in
            yazi-selector/* | x-script-selector-YAZI.sh) continue ;;
        esac
        dest="$cache/tree/Scripts/$rel"
        mkdir -p "$(dirname "$dest")"
        cp "$f" "$dest"
        printf 'scripts\t%s\t%s\t1\t%s\n' "$(basename "$f")" "$f" "$dest" >> "$idx"
    done < <(find "$sc_dir" -maxdepth 5 -type f -name '*.sh')

    # ---- 3. load descriptions.json into bash associative arrays -------------
    # NOTE: deliberately NOT using @tsv/tab here. Tab is one of bash's "IFS
    # whitespace" characters, so `IFS=$'\t' read` COLLAPSES adjacent tabs
    # instead of preserving the empty field between them -- and `params` is
    # often legitimately empty, which silently shifted every field after it.
    # \x1F (unit separator) is NOT IFS whitespace, so empty fields survive.
    # `tr -d '\r'` strips the CRLF jq (a native Windows binary) writes here.
    local usep
    usep=$(printf '\x1f')
    local -A M_LINEMODE_COL=() M_DESC=() M_PARAMS=() M_EXAMPLE=()
    local mkind mname mlinemodecol mdesc mparams mexample
    while IFS="$usep" read -r mkind mname mlinemodecol mdesc mparams mexample; do
        M_LINEMODE_COL["$mkind|$mname"]="$mlinemodecol"
        M_DESC["$mkind|$mname"]="$mdesc"
        M_PARAMS["$mkind|$mname"]="$mparams"
        M_EXAMPLE["$mkind|$mname"]="$mexample"
    done < <(jq -r --arg sep "$usep" '
        def rows(k): (.[k] // {}) | to_entries[] |
            [k, .key, (.value.description_linemode_col // ""), (.value.desc // ""), (.value.params // ""), (.value.example // .key)] | join($sep);
        rows("functions"), rows("scripts")
    ' "$json" | tr -d '\r')

    local default_desc="(no description yet -- add one to yazi-selector/descriptions.json)"

    # ---- 4. write $cache/index.lua -------------------------------------------
    # Merges realpath/line (discovered from disk) with description_linemode_col/
    # desc/params/example (from descriptions.json), keyed by name. Both init.lua
    # (hover descriptions) and the plugin (action resolution) dofile this one
    # file -- no path string ever needs to cross the bash/Lua boundary.
    #
    # Functions are keyed by their CACHE FILENAME ("largest.sh", matching what
    # Yazi's h.name reports), which differs from the real callable bash
    # function name ("largest") -- that real name travels separately as the
    # `invoke` field so execution still calls the right thing. Scripts need no
    # such split: their cache filename already IS a real, runnable path.
    local kind name realpath line cachepath
    {
        printf 'return {\n  functions = {\n'
        while IFS=$'\t' read -r kind name realpath line cachepath; do
            [[ "$kind" == "functions" ]] || continue
            jq -nr \
                --arg cachekey "$name.sh" --arg invoke "$name" \
                --arg realpath "$realpath" --argjson line "$line" \
                --arg linemode_col "${M_LINEMODE_COL["functions|$name"]}" \
                --arg desc "${M_DESC["functions|$name"]:-$default_desc}" \
                --arg params "${M_PARAMS["functions|$name"]}" \
                --arg example "${M_EXAMPLE["functions|$name"]:-$name}" \
                '"    [" + ($cachekey|tojson) + "] = { invoke = " + ($invoke|tojson)
                 + ", realpath = " + ($realpath|tojson) + ", line = " + ($line|tostring)
                 + ", description_linemode_col = " + ($linemode_col|tojson)
                 + ", desc = " + ($desc|tojson) + ", params = " + ($params|tojson)
                 + ", example = " + ($example|tojson) + " },"'
        done < "$idx"
        printf '  },\n  scripts = {\n'
        while IFS=$'\t' read -r kind name realpath line cachepath; do
            [[ "$kind" == "scripts" ]] || continue
            jq -nr \
                --arg name "$name" --arg realpath "$realpath" --argjson line "$line" \
                --arg linemode_col "${M_LINEMODE_COL["scripts|$name"]}" \
                --arg desc "${M_DESC["scripts|$name"]:-$default_desc}" \
                --arg params "${M_PARAMS["scripts|$name"]}" \
                --arg example "${M_EXAMPLE["scripts|$name"]:-$name}" \
                '"    [" + ($name|tojson) + "] = { realpath = " + ($realpath|tojson)
                 + ", line = " + ($line|tostring)
                 + ", description_linemode_col = " + ($linemode_col|tojson)
                 + ", desc = " + ($desc|tojson) + ", params = " + ($params|tojson)
                 + ", example = " + ($example|tojson) + " },"'
        done < "$idx"
        printf '  },\n}\n'
    } | tr -d '\r' > "$cache/index.lua"

    # ---- 5. prepend a human-readable header to every generated file ---------
    local sep tmp
    sep=$(printf '=%.0s' {1..60})
    while IFS=$'\t' read -r kind name realpath line cachepath; do
        [[ -f "$cachepath" ]] || continue
        tmp="$cachepath.hdr"
        {
            printf '# %s\n#%s\n' "$name" "$sep"
            printf '# %s\n' "${M_DESC["$kind|$name"]:-$default_desc}"
            [[ -n "${M_PARAMS["$kind|$name"]}" ]] && printf '# Params:  %s\n' "${M_PARAMS["$kind|$name"]}"
            printf '# Example: %s\n' "${M_EXAMPLE["$kind|$name"]:-$name}"
            printf '# Source:  %s\n#%s\n\n' "$realpath" "$sep"
            cat "$cachepath"
        } > "$tmp"
        mv "$tmp" "$cachepath"
    done < "$idx"

    touch "$stamp"
}

_bash_selector_build_index "$@"
