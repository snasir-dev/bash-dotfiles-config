#!/bin/bash

# Claude Code - Anthropic's official CLI coding agent.
# Official Docs: https://docs.claude.com/en/docs/claude-code
# Setup / install docs: https://docs.claude.com/en/docs/claude-code/setup
# Pre-requisite - Ensure claude is installed and available in PATH.
# Verify with: type -a claude     (resolves to ~/.local/bin/claude on this machine)

# --- ENVIRONMENT VARIABLES ---

# --- FUNCTIONS ---

# =============================================================================
# WHY THIS WRAPPER EXISTS
# =============================================================================
# Hand-typing this on every single launch is tedious:
#     claude --permission-mode plan --allow-dangerously-skip-permissions
#
# WHAT THE TWO FLAGS ACTUALLY BUY US:
#
#   --permission-mode plan
#       Starts the session in PLAN MODE. Claude researches and proposes a plan
#       first, and is BLOCKED from editing files or running any non-read-only
#       tool until that plan is approved. Safe way to open any new task.
#
#   --allow-dangerously-skip-permissions
#       !! THIS IS NOT THE SAME FLAG AS --dangerously-skip-permissions !!
#       It does NOT turn permission-bypassing ON. Straight from `claude --help`:
#         "Enable bypassing all permission checks as an option,
#          without it being enabled by default."
#       So it merely makes BYPASS PERMISSIONS *available* as a mode that can be
#       switched into from inside the running session -- cycle modes with SHIFT+TAB.
#
#   NET EFFECT: start SAFE in PLAN mode, then SHIFT+TAB into BYPASS PERMISSIONS
#   only when it's actually wanted -- instead of launching directly into bypass
#   (which is what the plain --dangerously-skip-permissions flag would do).
#
# -----------------------------------------------------------------------------
# WHEN THE FLAGS GET INJECTED (and when they deliberately do NOT)
# -----------------------------------------------------------------------------
#   INJECTED -- when actually STARTING A SESSION. That is bare `claude`, or
#       `claude -c`, `claude "<some prompt>"`, `claude -p "..."`, etc.
#       These are the invocations where a permission mode is meaningful.
#
#   NOT INJECTED -- when calling a MANAGEMENT SUBCOMMAND, e.g. `claude mcp list`,
#       `claude update`, `claude doctor`, `claude plugin ...`. These never start
#       a session, so a permission mode means nothing to them. They are handed
#       straight to the stock binary and behave EXACTLY as if this wrapper did
#       not exist. Same for the informational flags -h/--help/-v/--version.
#
# `command claude` is used (not a bare `claude`) so the real executable on PATH
# is invoked -- a bare `claude` here would re-enter this function forever.
# =============================================================================
claude() {
    case "$1" in
        # Management subcommands + informational flags -> run stock, no injection.
        # Keep this list in sync with the "Commands:" section of `claude --help`.
        # NOTE: 'attach' does NOT appear in that Commands section (confirmed via
        # `claude attach --help`, which works despite being undocumented there) --
        # it still needs to be listed here since it never starts a NEW session, it
        # opens an already-running background one in this terminal. Without this,
        # our injected flags land on it as trailing garbage: `claude attach <id>`
        # would warn "extra arguments ignored: --permission-mode plan
        # --allow-dangerously-skip-permissions" instead of attaching cleanly.
        agents | attach | auth | auto-mode | doctor | gateway | import | install | mcp | plugin | plugins | project | setup-token | ultrareview | update | upgrade | -h | --help | -v | --version)
            command claude "$@"
            ;;
        # Everything else starts a session -> inject our preferred defaults.
        *)
            command claude --permission-mode plan --allow-dangerously-skip-permissions "$@"
            ;;
    esac
}

# --- ALIASES ---

# SHORTHAND: identical behavior to the claude() function above (plan mode
# injection + management-subcommand passthrough) -- just less typing. Aliasing
# to a shell function name works fine in bash: alias expansion is a text
# substitution that happens before the function lookup.
# shellcheck disable=SC2139
alias {cc,CC,CLAUDE}='claude'

# ESCAPE HATCH: run the stock `claude` binary with ZERO injected flags.
# `command` bypasses both shell functions and aliases, so this reaches the real
# executable even though the claude() function above shadows the name `claude`.
# (Typing `command claude ...` by hand does exactly the same thing.)
# shellcheck disable=SC2139
alias {claude-default,ccdefault}='command claude'

# FAST LANE: skips plan-mode injection entirely (bare `command claude`, like
# claude-default) and launches directly on Sonnet 5 with thinking disabled --
# built for quick throwaway questions where near-instant replies matter more
# than deep reasoning, while staying more reliable than Haiku. Not for coding
# tasks.
#   MAX_THINKING_TOKENS=0    -- disables extended thinking for this invocation
#                               only (no global env var, no --thinking flag
#                               exists in this CLI version to do this directly)
#   --model sonnet            -- near-Opus quality at Sonnet cost/speed --
#                               chosen over Haiku for reliability
#   --effort medium           -- there is no "default" value for --effort
#                               (only low/medium/high/xhigh/max exist); left
#                               unset, this silently inherits whatever effort
#                               level is pinned in your normal Claude Code
#                               settings (xhigh via settings.json) -- explicit low is the
#                               only way to force it down for this fast lane
#   --permission-mode auto    -- lets Claude Code's own risk classifier
#                               decide per-action whether to prompt, instead
#                               of falling through to the stock default
# shellcheck disable=SC2139
alias {claude-fast,ccfast}='MAX_THINKING_TOKENS=0 command claude --model sonnet --effort medium --permission-mode auto'

# SESSION SWITCHER: fuzzy-pick any live Claude Code session (interactive or
# background, across ALL projects on this machine) and attach/resume it in place --
# no need to open fullscreen agent view (`claude agents`) first. See
# BASH_SCRIPTS/x-claude-sessions.sh for the implementation.
# shellcheck disable=SC2139
alias {ccfzf,ccs,claude-sessions}='$BASH_DIR/BASH_SCRIPTS/x-claude-sessions.sh'

# --- COMPLETIONS ---

# Claude Code ships NO bash completion generator -- there is no
# `claude completion bash` subcommand as of v2.1.229. Re-check the "Commands:"
# section of `claude --help` if that ever changes. Nothing to source here.
