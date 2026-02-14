#!/bin/bash
# GIT CONFIGURATION
# Check Git Config:
# git config --edit (--local/--global/--system)
# Most changes in git config --edit --global
# Located in ~\.gitconfig

# --- ENVIRONMENT VARIABLES ---
# Git Vars
# export GIT_AUTHOR_NAME="Your Name"
# export GIT_AUTHOR_EMAIL="your_email@example.com"

# --- ALIASES ---

alias gs="git status"
# alias ga="git add"
# alias gc="git commit -m"
# alias gp="git push"

# Can specify number of records to show by adding "-n 10" - Will show '10' amount of rows
alias gl="git log --oneline --graph --decorate --all" # can add additional commands after it like number of lines "-n 20"
alias gfsck="git_fsck"

# Go to the root of the current git repo
alias {groot,gtop}='cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"'

# Alias for LazyGit - A TERMINAL USER INTERFACE for GIT
# alias lg="lazygit" LG="lazygit" Lg="lazygit"

# shellcheck disable=SC2139
# Brace expansion {lg,LG,Lg} generates three separate aliases (lg, LG, Lg) in a single command. Bash processes this during startup with no runtime performance difference
alias {lg,LG,Lg,lG}="lazygit"

# All
# alias lg="lazygit"
# alias LG="lazygit"
# alias Lg="lazygit"

#*******************************

# --- COMPLETIONS ---

#===============================================
# GitHub CLI (gh) Auto-Completion SCRIPTS      #
#===============================================
# Official GitHub CLI Completion Docs: https://cli.github.com/manual/gh_completion
# Enable GitHub CLI auto-completion for bash.
# `gh completion -s bash` generates completion script for gh CLI.
# Using `source <(...)` loads completions into the current shell session.
# This enables tab completion for `gh` commands, subcommands, and flags like `--state`, `--label`, etc.
# Pre-requisite - Ensure GitHub CLI is installed and available in PATH.
# Can install on Windows with command: winget install --id GitHub.cli
if command -v gh &> /dev/null; then
    source <(gh completion -s bash)
    # eval "$(gh completion -s bash)"
fi

# --- FUNCTIONS ---

# git fsck --full --unreachable → Lists unreachable objects.
# grep "commit" → Filters only commit objects.
# awk '{print $3}' → Extracts only the commit hashes.
# xargs git log --format="%h %cd %s" --date=format:'%Y-%m-%d %H:%M:%S' → Displays:
# %h → Short commit hash.
# %cd → Commit date.
# %s → Commit message.
# --date=format:'%Y-%m-%d %H:%M:%S' → Formats the date like YYYY-MM-DD HH:MM:SS.

# Example OUTPUT:
# abc1234 2024-03-10 14:30:45 Fix login issue
# def5678 2024-03-11 09:15:22 Refactored API

# To use command do: git_fsck
# Can specify num of rows. This will try to get 10 rows: git_fsck 10

git_fsck() {
    local num_rows="${1:-1}" # If num_rows is empty or 0, set it to 1
    # Check if num_rows is less than 1
    if [ "$num_rows" -lt 1 ]; then
        num_rows=1
    fi

    git fsck --full --unreachable | grep "commit" | awk '{print $3}' | xargs git log --format="%h %cd %s" --date=format:'%Y-%m-%d %H:%M:%S' | head -n "$num_rows"
}

# g2() {
#     git fsck --full --unreachable | while read line; do
#         if echo "$line" | grep -q "dangling"; then
#             # Color dangling objects red
#             echo -e "\033[31m$line\033[0m"
#         elif echo "$line" | grep -q "unreachable"; then
#             # Color unreachable objects yellow
#             echo -e "\033[33m$line\033[0m"
#         else
#             echo "$line"
#         fi
#     done | grep "commit" | awk '{print $3}' | xargs git log --format="%h %cd %s" --date=format:'%Y-%m-%d %H:%M:%S' | head -n "$num_rows"

# }

#*************************************
# COMMIT MESSAGE FORMAT REMINDER
#*************************************

# MAIN COMMIT MESSAGE FORMAT REMINDER W/ EXAMPLES

# Set the color code for orange and a code to reset to default
ORANGE='\033[38;2;249;179;0m'
# Add "1;" to the start of the color code to make it bold
BOLD_ORANGE='\033[1;38;2;249;179;0m'
RESET='\033[0m'

commit_msg() {
    echo "--- COMMIT MESSAGE STRUCTURE ---"
    echo "  type(scope): subject    Example: feature(auth): add social login"
    echo "  │     │      └─> Concise description (50 chars max), lowercase, no period"
    echo "  │     └─> Optional area of change: users, auth, api, etc."

    # Make "Required" Bold via printf
    #     %s is a placeholder in the format string that will be replaced by the next argument.
    # \e[1m and \e[0m are still the ANSI escape codes for bold start and reset.
    # \n at the end adds a newline character, just like echo implicitly does.
    # "Required" is the second argument to printf. This string will be inserted in place of %s in the format string
    printf "  └─> \e[1m%s\e[0m: feature|fix|docs|refactor|test|chore|performance|build|ci|revert|multi" "Required" # Passing required as a variable in %s  "e[1m%s\e[0m"
    echo ""
    echo "--- FORMATTING OPTIONS ---"
    echo "  • SINGLE TYPE:         feature(auth): Add social login support"
    echo "                         - [docs] Added function documentation"
    echo "                         - [style] Fixed indentation"
    echo ""
    echo "  • MULTIPLE TYPES:      multi(fix,style,docs): Comprehensive update"
    echo "                         OR: refactor(docs,style): Reorganize config and improve comments"
    echo ""
    echo "  • ALTERNATIVE FORMAT:  refactor/docs/style: Update function documentation and formatting"
    echo ""
    echo "--- SPECIAL CASES ---"
    echo "  • Comments:            Use 'docs' for adding/removing/modifying comments"
    echo "  • Renaming/Moving:     Use 'refactor' for renaming variables, functions, files, or aliases"
    echo "  • Mixed Changes:       Use primary type for most significant change + detail others in body"
    echo ""
    # With separators "|" and Bold Header Row
    {
        echo "TYPE|DESCRIPTION|EXAMPLE 1|EXAMPLE 2"
        echo -e "${BOLD_ORANGE}feature${RESET}|(Adds new functionality or capability)|feature(payment): Add PayPal integration|feature(users): User registration"
        echo -e "${BOLD_ORANGE}fix${RESET}|(Corrects a bug or issue)|fix(cart): Prevent total calculation error|fix(auth): Password reset bug"
        echo -e "${BOLD_ORANGE}docs${RESET}|(Documentation changes - comments, README, etc.)|docs(config): Add setup instructions|docs(api): Update endpoint docs"
        echo -e "${BOLD_ORANGE}style${RESET}|(Formatting, indentation, whitespace)|style(css): Apply consistent indentation|style(code): Consistent formatting"
        echo -e "${BOLD_ORANGE}refactor${RESET}|(Code changes that don't add features or fix bugs)|refactor(utils): Simplify error handling|refactor(payment): Improve logic"
        echo -e "${BOLD_ORANGE}chore${RESET}|(Reorganize File Structure, dependency updates, config changes)|chore(deps): Update Node packages|chore(gitignore): Update ignore files"
        echo "enhance|(Makes improvements to existing code or features)|enhance(search): Improve search result relevance|enhance(api): Reduce response time by 40%"
        # echo "enhance|(Improves code structure, UX, maintainability)|enhance(ui): Improve dark mode contrast|enhance(logs): Add context to log output"
        # echo "enhance|(Optimizes performance, UX, or code quality)|enhance(api): Reduce response time by 40%|enhance(forms): Add better input validation feedback"
        echo "test|(Adding or modifying tests)|test(api): Add unit tests for endpoints|test(auth): Unit tests for login"
        echo "performance|(Improves speed or resource usage)|performance(queries): Optimize database lookups|performance(db): Optimize query latency"
        echo "build|(Build system, compilation, packaging)|build(webpack): Update configuration|build(deps): Update dependencies"
        echo "ci|(Continuous integration pipeline changes)|ci(actions): Set up automated testing|ci(github): Setup CI workflow"
        echo "revert|(Undoes a previous commit)|revert: Revert 'feature(auth): Add OAuth'|revert: Revert 'feature(users): ...'"
        echo "multi|(For commits with multiple distinct changes)|multi(fix,style,docs): Comprehensive update|multi(refactor,docs): Code cleanup w/ comments"
    } | column -t -s "|" -o "     " | sed '1s/.*/'$'\e[1m&\e[0m''/'
    # | column -t -s "|" -o "  " -> Format output as aligned table:
    # -t: table format (auto-align columns)
    # -s "|": input field separator is "|"
    # -o " | ": output field separator is " | "

    # | sed '1s/.*/'$'\e[1m&\e[0m''/' -> Make the first line (header) bold:
    # sed: stream editor
    # '1s/.../.../': substitute command, line 1 only
    # /.*/: match whole line (any character, any times)
    # '$'\e[1m&\e[0m'': replacement - bold ANSI escape codes around matched text (& - whole line)
}

commit_msg_other() {
    other_commit_msg1
    other_commit_msg2
    other_commit_msg3

    # Option 1: Basic column formatting with headers
    {
        echo "TYPE|DESCRIPTION|EXAMPLE"
        echo "feat|(New feature)|feat(users): Add registration"
        echo "fix|(Bug fix)|fix(auth): Fix password reset"
        echo "docs|(Documentation)|docs(api): Update endpoint docs"
        echo "refactor|(Code refactor)|refactor(payment): Simplify logic"
        echo "chore|(Maintenance)|chore(deps): Update dependencies"
        echo "test|(Testing)|test(auth): Add login tests"
    } | column -t -s "|" -o "  |  "

    echo -e "\n------------------------"

    # Option 2: With separator ":" and Bold Header Row
    # {
    #     echo "TYPE:DESCRIPTION:EXAMPLE"
    #     echo "feat:(New feature):feat(users) - Add registration"
    #     echo "fix:(Bug fix):fix(auth) - Fix password reset"
    #     echo "docs:(Documentation):docs(api) - Update endpoint docs"
    # } | column -t -s ":" -o " | " | sed '1s/.*/'$'\e[1m&\e[0m''/'

    # With separators "|" and Bold Header Row
    {
        echo "TYPE|DESCRIPTION|EXAMPLE"
        echo "feat|(New feature)|feat(users):- Add registration"
        echo "fix|(Bug fix)|fix(auth):- Fix password reset"
        echo "docs|(Documentation)|docs(api):- Update endpoint docs"
    } | column -t -s "|" -o " | " | sed '1s/.*/'$'\e[1m&\e[0m''/'

    # {
    #     echo "TYPE:DESCRIPTION:EXAMPLE"
    #     echo "feature:(New feature - Adds new functionality):feature(users) - User registration"
    #     echo "fix:(Bug fix - Corrects an issue):fix(auth) - Password reset bug"
    #     echo "docs:(Documentation - Documentation changes only):docs(api) - Update endpoint docs"
    #     echo "style:(Formatting - No code change, just style):style(code) - Consistent formatting"
    #     echo "refactor:(Code refactor - Code change, no new feature/bug fix) - refactor(payment): Improve logic"
    #     echo "chore:(Maintenance - General maintenance tasks):chore(gitignore) - Update ignore files"
    #     echo "test:(Testing - Tests related changes):test(auth): - Unit tests for login"
    #     echo "performance:(Performance - Improves performance):performance(db): Optimize query latency"
    #     echo "build:(Build system - Build process or dependencies):build(deps): Update dependencies"
    #     echo "ci/cd:(CI/CD - CI configuration changes):ci(github): Setup CI workflow"
    #     echo "revert:(Revert commit - Undoes a previous commit):revert: Revert 'feature(users): ...'"
    # } | column -t -s ":" -o " | " | sed '1s/.*/'$'\e[1m&\e[0m''/'

    # {
    #     echo "TYPE:DESCRIPTION:EXAMPLE"
    #     echo "feature:(New feature - Adds new functionality):Example: feature(users): User registration"
    #     echo "fix:(Bug fix - Corrects an issue):Example: fix(auth): Password reset bug"
    #     echo "docs:(Documentation - Documentation changes only):Example: docs(api): Update endpoint docs"
    #     echo "style:(Formatting - No code change, just style):Example: style(code): Consistent formatting"
    #     echo "refactor:(Code refactor - Code change, no new feature/bug fix):Example: refactor(payment): Improve logic"
    #     echo "chore:(Maintenance - General maintenance tasks):Example: chore(gitignore): Update ignore files"
    #     echo "test:(Testing - Tests related changes):Example: test(auth): Unit tests for login"
    #     echo "performance:(Performance - Improves performance):Example: performance(db): Optimize query latency"
    #     echo "build:(Build system - Build process or dependencies):Example: build(deps): Update dependencies"
    #     echo "ci/cd:(CI/CD - CI configuration changes):Example: ci(github): Setup CI workflow"
    #     echo "revert:(Revert commit - Undoes a previous commit):Example: revert: Revert 'feature(users): ...'"
    # } | column -t -s ":" -o " | " | sed '1s/[^|]*/"  &  "/g' | sed '1s/.*/'$'\e[1m&\e[0m''/'

    # Option 3: Multi-table approach with different column counts
    # echo -e "\n--- Common Types ---"
    # {
    #     echo "PRIMARY|DESCRIPTION"
    #     echo "feat|(New feature)"
    #     echo "fix|(Bug fix)"
    #     echo "docs|(Documentation)"
    # } | column -t -s "|"

    # echo -e "\n--- Additional Types ---"
    # {
    #     echo "SECONDARY|DESCRIPTION"
    #     echo "style|(Formatting)"
    #     echo "perf|(Performance)"
    #     echo "build|(Build system)"
    # } | column -t -s "|"
}

other_commit_msg1() {
    echo "📝 Commit Message Reminder 📝"
    echo "--- Commit Structure Template: ---"
    echo "  type(scope): subject    Example: feature(auth): add social login"
    echo "  │     │      └─> Concise description (50 chars max), lowercase, no period"
    echo "  │     └─> Optional area of change: users, auth, api, etc."
    echo "  └─> Required: feature|fix|docs|refactor|test|chore"
    echo "--- Types: ---"
    echo "feature         : (New feature)          - Adds new functionality                   | Example: feature(users): User registration"
    echo "fix             : (Bug fix)              - Corrects an issue                        | Example: fix(auth): Password reset bug"
    echo "docs            : (Documentation)        - Documentation changes only               | Example: docs(api): Update endpoint docs"
    echo "style           : (Formatting)           - No code change, just style               | Example: style(code): Consistent formatting"
    echo "refactor        : (Code refactor)        - Code change, no new feature/bug fix      | Example: refactor(payment): Improve logic"
    echo "chore           : (Maintenance)          - General maintenance tasks                | Example: chore(gitignore): Update ignore files"
    echo "test            : (Testing)              - Tests related changes                    | Example: test(auth): Unit tests for login"
    echo "performance     : (Performance)          - Improves performance                     | Example: performance(db): Optimize query latency"
    echo "build           : (Build system)         - Build process or dependencies            | Example: build(deps): Update dependencies"
    echo "ci/cd           : (CI/CD)                - CI configuration changes                 | Example: ci(github): Setup CI workflow"
    echo "revert          : (Revert commit)        - Undoes a previous commit                 | Example: revert: Revert 'feature(users): ...'"

    echo -e "\n------------------------"
}

other_commit_msg2() {
    echo "📝 Commit Message Reminder 📝"
    {
        echo "TYPE:DESCRIPTION:EXAMPLE"
        echo "feat:(New feature):feat(users): Add registration"
        echo "fix:(Bug fix):fix(auth): Fix password reset"
        echo "docs:(Documentation):docs(api): Update endpoint docs"
        echo "refactor:(Code refactor):refactor(payment): Simplify logic"
        echo "chore:(Maintenance):chore(deps): Update dependencies"
        echo "test:(Testing):test(auth): Add login tests"
        echo "style:(Formatting):style(code): Format according to standards"
        echo "perf:(Performance):perf(db): Optimize query"
        echo "build:(Build system):build(deps): Update webpack"
        echo "ci:(CI config):ci(github): Setup workflow"
        echo "revert:(Revert commit):revert: Revert 'feat(users): ...'"
    } | column -t -s ":"

    echo -e "\n--- Format: type(scope): subject ---"
    echo "  • Scope is optional and indicates area of change"
    echo "  • Subject should be under 50 chars, lowercase, no period"

    echo -e "\n------------------------"
}

other_commit_msg3() {
    echo "📝 Commit Message Reminder 📝"
    printf "%-10s %-20s %-30s\n" "TYPE" "DESCRIPTION" "EXAMPLE"
    printf "%-10s %-20s %-30s\n" "feat" "(New feature)" "feat(users): Add registration"
    printf "%-10s %-20s %-30s\n" "fix" "(Bug fix)" "fix(auth): Fix password reset"
    # And so on for other types...

    echo -e "\n--- Format: type(scope): subject ---"

    echo -e "\n------------------------"
}

#*************************************
#
#*************************************
