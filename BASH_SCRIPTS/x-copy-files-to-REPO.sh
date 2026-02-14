#!/bin/bash

# ==============================================================================
# DOTFILES SYNC SCRIPT
# ==============================================================================
# This script helps you copy modified config files/folders from your system
# to their corresponding git repositories without manual copy-paste work.
#
# USAGE: Run this script from the directory containing the files you want to copy
# ==============================================================================

# Set the trap at the very beginning of the script
# The trap command in Bash automatically runs a piece of code whenever the script exits, for any reason. We want to know the exit code status (what code fzf returns if say we press ESC or CTRL+C)
# $?: This special shell variable always holds the exit code of the last command that finished.
trap 'echo "DEBUG: Script exited with EXIT-CODE $?"' EXIT

# Exit immediately if a command exits with a non-zero status
set -e

# Exit if we try to use an unset variable
set -u

# Make pipes fail if any command in the pipe fails (not just the last one)
set -o pipefail

# ==============================================================================
# GLOBAL VARIABLES
# ==============================================================================

# Store the directory where this script was launched from
# This is where we'll look for files to copy
LAUNCH_DIR="$(pwd)"

echo "$LAUNCH_DIR"

REPOS_DIR="$HOME/Documents/@MAIN_WORKSPACE/@REPOS/"
# This will store the selected repository path
SELECTED_REPO=""

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        DOTFILES SYNC SCRIPT                                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ------------------------------------------------------------------------------
# STEP 1: Select the target repository
# ------------------------------------------------------------------------------
echo "📂 STEP 1: Select target repository"
echo "────────────────────────────────────────────────────────────"
echo "Searching for repositories in: $REPOS_DIR"
echo ""

# Find all git repositories and let user select one with FZF
# Note - without specifying '--height ' fzf causing issues where it will exit with error code 130 when pressing up or down.
# SELECTED_REPO=$(fd --base-directory $REPOS_DIR -t d --hidden --glob '.git' -E 'Git' -E '**/android/**' -x dirname {} | sort | fzf \
#     --prompt '(Choose REPOSITORY to COPY FILES to (Searching in Base Directory: $REPOS_DIR) > ' --height 50%)

# Check if user selected a repository (SELECTED_REPO is not empty)
if SELECTED_REPO=$(fd -t d --hidden --glob '.git' "$REPOS_DIR" \
    -E 'Git' -E '**/android/**' -x dirname {} | sort \
    | fzf --prompt '(Choose REPOSITORY to COPY FILES to) >' --height 50%); then

    # This block only runs if fzf exits with code 0 (success)
    # If it exists with non-zero (CTRL+C = 127, ESC = 130, or other reason), it will run else condition.
    echo "✓ Selected repository: $SELECTED_REPO"
else
    exit_code=$? # <-- Save the exit code immediately
    echo "❌ No repository selected. Exiting."
    exit "$exit_code"
fi

echo ""

# ------------------------------------------------------------------------------
# STEP 2: Select files/folders to copy from current directory. First Prompt user
# ------------------------------------------------------------------------------
echo "📋 STEP 2: Select files/folders to copy"
echo "────────────────────────────────────────────────────────────"
echo "Current directory: $LAUNCH_DIR"
echo "Use TAB to multi-select, ENTER to confirm"
echo ""

# -r: prevents backslashes from being interpreted. what the user types is taken literally, including any \ like \n or \t.
# -p (prompt): display a message to the user before reading input.
# $'string': allows adding \n as newline in the prompt.
# -n [amount]: ex: -n 1 reads a single character
read -rp $'Select files/folders to copy. This will open fzf. Begin selecting files? [Y]es to continue, [N] or [Q] to quit:\n' -n 10

# $REPLY is a default variable used by read when no variable is provided. The condition if [[ $REPLY =~ ^[Yy]$ ]] checks if the reply was Y or y.
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Opening FZF to Select files/folders..."

    # Use fd to find all files and directories FROM THE LOCATION/DIRECTORY WE LAUNCHED THE SCRIPT (LAUNCH_DIR), then let user multi-select with fzf
    # --multi (-m) allows multiple selections
    # Note - without specifying '--height ' fzf causing issues where it will exit with error code 130 when pressing up or down.
    SELECTED_ITEMS=$(fd --type f --type d --hidden --exclude '.git' --exclude 'node_modules' . "$LAUNCH_DIR" \
        | fzf --multi --prompt 'Select files/folders to copy (TAB=select, ENTER=confirm) >' \
            --bind 'tab:toggle+down' --height 50%)

    # Check if user cancelled or selected nothing
    if [ -z "$SELECTED_ITEMS" ]; then
        echo "❌ No files/folders selected. Exiting."
        # exit 1
    fi

    # Count how many items were selected
    ITEM_COUNT=$(echo "$SELECTED_ITEMS" | wc -l)
    echo "✓ Selected $ITEM_COUNT item(s) to copy"
    echo -e "Selected Items Values:\n$SELECTED_ITEMS"
    echo ""

elif [[ $REPLY =~ ^[NnQq]$ ]]; then
    echo "🛑 Copy cancelled. Exiting script. ('$REPLY' key pressed)"
    exit 1

else
    echo "🛑 Invalid input. Exiting script. ('$REPLY' key pressed)"
    exit 1
fi
