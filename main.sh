#!/bin/bash
# Main BASH configuration file that will be sourced by the .bashrc file.
# This file acts as the central point for sourcing all custom configurations from $BASH_DIR directory.
# The .bashrc file will be very simple, it will only source this file.
# Example of sourcing main configuration from .bash directory. Only the following lines below will be added to .bashrc file located in the home directory.
# if [ -f "$BASH_DIR/main.sh" ]; then
# 	source "$BASH_DIR/main.sh"
# fi

# Enable debug logs (set to false to silence sourcing output)
# If DEBUG is unset or null, default to 'true'. Otherwise, keep its existing value.
# Value of $DEBUG is set with "reload_shell()" when we
: "${DEBUG:=true}"
if [[ $DEBUG == true ]]; then
    # echo "🐞🐞🐞 Debug mode enabled. Sourcing ~/.bashrc... 🐞🐞🐞"
    echo "🐞🐞🐞 Debug mode enabled. Sourcing main bash file: $BASH_DIR/main.sh 🐞🐞🐞"
fi

# Check if shell is running interactively
# $- is a string containing current shell options (i = interactive shell)
# != means "not equal to"
# *i* checks if 'i' appears anywhere in the string
# && means "and" - only execute the next command if the previous one is true
# return exits the script if shell is non-interactive
[[ $- != *i* ]] && return

# =====================================================================================
# Helper: safely source all '.sh' files under a directory and its sub-directories
# Arguments:
#   $1 = label (used for debug messages: env/functions/aliases/completions/tools)
#   $2 = base directory to search within
# =====================================================================================
source_sh_files() {
    local label="$1" # Label used to indicate source type (e.g., "env")
    local dir="$2"   # Directory path to search for .sh files

    # Define exclusion lists (filenames and directory names to skip)
    local EXCLUDE_FILES=("") # filenames to exclude. This will exclude irrespective of the directory, unlike EXCLUDE_FILES_BY_DIR
    # local EXCLUDE_FILES=("aws.sh" "docker.sh")              # filenames to exclude

    local EXCLUDE_DIRS=("text-processing" "system" "cloud") # DIRECTORY/FOLDER names to exclude (anywhere in path)

    # === ASSOCIATIVE ARRAY: key = folder name, value = filenames to exclude within that folder only ===
    # This only excludes files (values) in specific directories (keys)
    # e.g., EXCLUDE_FILES_BY_DIR["dev"]="local.sh secrets.sh"
    declare -A EXCLUDE_FILES_BY_DIR
    # EXCLUDE_FILES_BY_DIR["containers"]="docker.sh kubernetes.sh"
    # EXCLUDE_FILES_BY_DIR["file-management"]="ripgrep.sh"

    # `while IFS= read -r -d '' file; do ... done < <(...)` is process substitution:
    # - IFS=         → disables word splitting, reads the whole line
    # - -r           → disables backslash escaping
    # - -d ''        → sets the delimiter to null (for use with `-print0`)
    # - < <(...)     → process substitution feeds output of `find` into the loop, safely
    #
    # This ensures robust and safe reading of file paths, even those with special characters
    while IFS= read -r -d '' file; do

        # Pure Bash way to get the filename
        # ${file##*/} → Remove everything up to and including the last `/`
        # Example:
        #   file="/home/user/.bash/functions/aws.sh"
        #   filename="${file##*/}" → "aws.sh"
        # Equivalent to: basename "$file" — but faster!
        local filename="${file##*/}"

        # Extract just the immediate parent directory
        # ${file%/*} → Remove the shortest match of '/*' from the end (the filename part)
        # Example:
        #   file="/home/user/.bash/functions/aws.sh"
        #   parent_dir="${file%/*}" → "/home/user/.bash/functions"
        local parent_dir="${file%/*}" # Strip filename → gives directory path
        # ${parent_dir##*/} → Remove everything up to and including the last `/`
        # Example:
        #   parent_dir="/home/user/.bash/functions"
        #   folder="${parent_dir##*/}" → "functions"
        # This gives you just the last folder in the path
        # Equivalent to: basename "$(dirname "$file")" — but much faster!
        local folder="${parent_dir##*/}" # Strip everything up to last slash → parent dir

        # Check if the file should be excluded by filename
        for excluded_file in "${EXCLUDE_FILES[@]}"; do
            [[ "$filename" == "$excluded_file" ]] && continue 2
        done

        # Check if any part of the file path matches excluded directories
        for exclude_dir in "${EXCLUDE_DIRS[@]}"; do
            [[ "$file" == *"/$exclude_dir/"* ]] && continue 2
        done

        # === Skip specific files from certain directories ===
        # This allows you to specify, for example:
        #   EXCLUDE_FILES_BY_DIR["development"]="local.sh secrets.sh"
        # So that only those files are excluded in the 'development' folder, but NOT in other folders.

        # Check if the current folder has any file-specific exclusions
        # - `-n` tests whether the value is non-empty (i.e., there are exclusions defined for this folder)
        # - `${EXCLUDE_FILES_BY_DIR[$folder]}` retrieves the space-separated list of filenames to exclude for that folder
        if [[ -n "${EXCLUDE_FILES_BY_DIR[$folder]}" ]]; then

            # Loop over each filename specified for exclusion in that specific folder
            # - `excluded_file` takes each file name in the list (e.g., "local.sh", "secrets.sh")
            # - `${EXCLUDE_FILES_BY_DIR[$folder]}` is split into individual filenames automatically
            for excluded_file in ${EXCLUDE_FILES_BY_DIR[$folder]}; do

                # If the current file’s name matches any excluded_file filename, skip the outer loop iteration
                # - `continue 2` tells Bash to skip this file and jump back to the next iteration of the *outer* loop (not just this inner loop)
                [[ "$filename" == "$excluded_file" ]] && continue 2

            done
        fi

        # If debugging is enabled, print the file being sourced
        # [[ $DEBUG == true ]] && echo "Sourcing [${label} (${folder}/${filename})]: $file"
        [[ $DEBUG == true ]] && printf "Sourcing [%s (%s/%s)]: %s\n" "$label" "$folder" "$filename" "$file"

        # Source the file into the current shell (not a subshell)
        source "$file"

        # Use `find` to locate all `.sh` files under the directory tree
        #   -type f      → only files (not directories)
        #   -name "*.sh" → only files ending with .sh
        #   -print0      → output null-separated paths (safe for filenames with spaces/newlines)
    done < <(find "$dir" -type f -name "*.sh" -print0)
}

# ======================================================================
# Source all scripts in config (custom keybinds, etc.)
# ======================================================================
source_sh_files "Config (Custom Keybinds)" "$BASH_DIR/config"
echo ""

# ===================================================================
# Source scripts in order (except excluded files or directories):
# Order: env → functions → aliases → completions → plugins
# ===================================================================
source_sh_files "env" "$BASH_DIR/env"
echo ""

# !! IMPORTANT: FUNCTIONS MUST BE BE SOURCED BEFORE ALIASES (SOME ALIASES WILL DEPEND ON THEM) !!
source_sh_files "functions" "$BASH_DIR/functions"
echo ""

source_sh_files "aliases" "$BASH_DIR/aliases"
echo ""

source_sh_files "completions" "$BASH_DIR/completions"
echo ""

# Add scripts directory to PATH
# export makes the variable available to child processes
# PATH is the system variable that defines where to look for executables
# $HOME expands to our home directory
# : is the path separator in PATH
# $PATH appends the existing PATH value
export PATH="$BASH_DIR/BASH_SCRIPTS:$PATH"

# Source local machine-specific settings
# These settings shouldn't be in version control
# if [ -f file ]: tests if the file exists and is a regular file
# then: begins the block of code to execute if the test is true
# fi: ends the if block
if [ -f ~/.bash_local ]; then
    source ~/.bash_local
fi

# Source Theme Configuration
# Install and Setup Oh My Posh (Custom Prompt Tool to add themes to the terminal)
# Check if 'setup_oh_my_posh.sh' file exists. If it does, source it.
SETUP_THEME_SCRIPT="$BASH_DIR/config/themes/oh-my-posh/setup_oh_my_posh.sh"
if [ -f "$SETUP_THEME_SCRIPT" ]; then
    source "$SETUP_THEME_SCRIPT"
else
    # echo -e "⚠️ Warning: '$SETUP_THEME_SCRIPT' not found! Please check your installation.\n"
    #\e[31 - sets text to red color. \e[0m resets the color to default
    echo -e "\e[31m⚠️  Warning: '$SETUP_THEME_SCRIPT' not found! Please check your installation.\e[0m ⚠️\n"
fi

# ======================================================================
# Source all scripts in tools (except excluded files or directories)
# ======================================================================
# Previous name for tools: Plugin /Tool / Module / Package
source_sh_files "Tools: CLI Tools Config Files" "$BASH_DIR/tools"
echo ""

# Run fastfetch when a new interactive shell starts
if command -v fastfetch > /dev/null 2>&1; then
    fastfetch
    echo ""
fi
