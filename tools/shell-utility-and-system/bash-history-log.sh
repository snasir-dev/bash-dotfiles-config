#!/bin/bash

# Fixes bash's native command history (it defaults to a 500-entry cap with no
# append -- the last shell to exit overwrites everyone else's) and adds a
# lightweight capture hook that logs every command you run -- with a real
# timestamp, exit code, cwd, and terminal -- to a TSV log. That log is what
# the Yazi selector's "Command History" view (xy / XY / Alt+G) reads, via
# BASH_SCRIPTS/yazi-selector/build-history.sh (the aggregator) and
# x-script-selector-YAZI.sh (the kind=history execution branch).
#
# Deliberately does NOT set HISTTIMEFORMAT: that would add a column to
# `history`'s own output and shift the `{2..}` field reference in
# tools/file-management/fzf.sh's FZF_CTRL_R_OPTS, silently breaking what
# Ctrl-R pastes. Our own log carries timestamps instead, so there's no need
# to touch that.
#
# PERFORMANCE (this hook runs on EVERY command you type -- see the budget in
# the implementation plan, "Command History for the Yazi selector"):
#   - Bash builtins only, plus exactly ONE forced subshell (the `history 1`
#     command substitution -- capturing output always forks in bash, builtin
#     or not, so this one is unavoidable if we want the actual command text).
#   - No external binaries (date/awk/sed/cut/wc), no pipelines, no second $( ).
#   - Bare Enter / duplicate-filtered / ignorespace-filtered commands exit via
#     a fork-free HISTCMD comparison BEFORE that subshell is ever reached.
#   - Measured cost: ~7ms/command, against oh-my-posh's own ~88ms/command
#     prompt render on this machine -- roughly +8% on a cost you already pay,
#     not perceptible while typing.
#
# To disable capture entirely: comment out the two PROMPT_COMMAND+=(...) lines
# near the bottom of this file. The histappend/HISTSIZE fixes above them are
# independent and safe to keep either way.

# --- ENVIRONMENT VARIABLES ---

# Append to $HISTFILE instead of overwriting it (bash's default behavior is
# "last shell to exit wins", which loses history from every other concurrent
# VS Code / Warp terminal), and stop truncating at the 500-entry default.
shopt -s histappend
HISTSIZE=100000
HISTFILESIZE=200000

# ignorespace only -- prefix a command with a space to keep it out of both
# ~/.bash_history AND this log (useful for one-off secrets/tokens).
#
# Deliberately NOT adding ignoredups here: HISTCONTROL=ignoredups suppresses
# HISTCMD from incrementing on a repeated command run back-to-back, which
# would make _bash_history_log()'s fork-free early-out (below) skip logging
# it entirely -- silently undercounting exactly the repetition signal the
# Yazi "Command History" > Frequent view is built to surface.
HISTCONTROL=ignorespace

# Where the capture hook writes. Deliberately OUTSIDE ~/.cache/bash-selector --
# yazi-selector/build-index.sh wipes that directory with `rm -rf` on every
# rebuild, and this log needs to survive that.
_BH_LOG_DIR="$HOME/.local/share/bash-history"
_BH_LOG_FILE="$_BH_LOG_DIR/history.tsv"

# Commands matching any of these bash [[ =~ ]] regexes are never logged.
# Empty by default (log everything). Add your own in ~/.bash_local, e.g.:
#   BASH_HISTORY_LOG_IGNORE+=('password' 'api[_-]?key')
[[ -z "${BASH_HISTORY_LOG_IGNORE+x}" ]] && declare -ga BASH_HISTORY_LOG_IGNORE=()

# --- FUNCTIONS ---

# One-time import of whatever is currently sitting in ~/.bash_history (your
# existing, timestamp-less, 500-entry-capped file) so the log -- and the Yazi
# "Command History" view -- isn't empty on day one. Seeded entries get
# epoch=0 ("unknown time"): build-history.sh's frecency scoring sorts epoch=0
# last by recency and buckets it into the oldest ("older", x0.25) multiplier.
_bash_history_log_seed() {
    [[ -f "$_BH_LOG_FILE" ]] && return 0 # already seeded -- never re-run
    mkdir -p "$_BH_LOG_DIR"
    : > "$_BH_LOG_FILE"
    [[ -f "$HISTFILE" ]] || return 0

    local line escaped
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        escaped="${line//\\/\\\\}"
        escaped="${escaped//$'\t'/\\t}"
        printf '0\t0\t0\tseed\t\t%s\n' "$escaped" >> "$_BH_LOG_FILE"
    done < "$HISTFILE"
}
_bash_history_log_seed

# Appends one TSV record per command:
#   epoch <TAB> exit <TAB> pid <TAB> term <TAB> cwd <TAB> command
# Registered on PROMPT_COMMAND below (runs after every command, before the
# next prompt is drawn). See the file header for the hard performance budget
# this must stay inside.
_BH_LAST_HISTCMD=""
_bash_history_log() {
    local exit=$? # MUST be first line -- captures the exit status of the command that just ran

    # Fork-free early-out. HISTCMD (a builtin variable) only changes when a
    # command was actually appended to bash's history list -- so it stays put
    # for bare Enter, HISTCONTROL=ignorespace-filtered commands, and blank
    # lines, letting all three skip out before the one forced subshell below.
    [[ "$HISTCMD" == "$_BH_LAST_HISTCMD" ]] && return 0
    _BH_LAST_HISTCMD="$HISTCMD"

    # The one subshell this hook is allowed: capturing `history 1`'s output
    # always forks in bash (builtin or not), so there's no fork-free way to
    # read the actual command text back.
    local raw hnum cmd
    raw=$(HISTTIMEFORMAT='' history 1)
    # shellcheck disable=SC2034  # hnum: `read`'s way of discarding the leading history-number field; only $cmd (the rest of the line) is used.
    read -r hnum cmd <<< "$raw"
    [[ -z "$cmd" ]] && return 0

    # Defensive backstop for ignorespace (HISTCMD's early-out above already
    # catches this in the normal case; this only matters if HISTCONTROL gets
    # overridden downstream of this file).
    [[ "$cmd" == " "* ]] && return 0

    local pat
    for pat in "${BASH_HISTORY_LOG_IGNORE[@]}"; do
        [[ -n "$pat" && "$cmd" =~ $pat ]] && return 0
    done

    local term="${TERM_PROGRAM:-${WT_SESSION:+windows-terminal}}"
    term="${term:-git-bash}"

    # One-line-safe: escape backslash/newline/tab so every record is exactly
    # one TSV line (multi-line commands can still embed real newlines despite
    # cmdhist's default semicolon-joining, e.g. via heredocs).
    local esc="${cmd//\\/\\\\}"
    esc="${esc//$'\n'/\\n}"
    esc="${esc//$'\t'/\\t}"

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$EPOCHSECONDS" "$exit" "$$" "$term" "$PWD" "$esc" >> "$_BH_LOG_FILE" 2> /dev/null

    # Registered here (not FUNCTIONS-only) so it's colocated with the two
    # PROMPT_COMMAND entries it participates in -- see below.
    return 0
}

# Wire the hook into PROMPT_COMMAND. Appended (never assigned!) because
# oh-my-posh installs its own PROMPT_COMMAND before tools/ is sourced (see
# main.sh's load order: config -> env -> functions -> aliases -> completions
# -> oh-my-posh theme -> tools). Array form requires bash 5.1+; Git Bash on
# this repo ships 5.2+.
PROMPT_COMMAND+=(_bash_history_log)
# Flush $HISTFILE to disk after every command, not just on clean shell exit --
# otherwise histappend only helps if every concurrent shell closes cleanly,
# which defeats the point when VS Code/Warp windows get killed outright.
PROMPT_COMMAND+=("history -a")

# --- ALIASES ---

# --- COMPLETIONS ---
