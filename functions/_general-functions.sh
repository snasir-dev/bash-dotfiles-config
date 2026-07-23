#!/bin/bash
# Contains all bash general/common function definitions

# List largest files (top 10 by default, customizable). Example:  largest 5: Show top 5 largest files
largest() {
    count=${1:-10}
    find . -type f -print0 | xargs -0 du -h | sort -rh | head -n "$count"
}

# List files older than X days. Example usage: oldfiles 60: List files older than 60 days
oldfiles() {
    days=${1:-30}
    find . -type f -mtime +"$days" -print
}

# Combine file count with size information
dirsummary() {
    echo "Total Files: $(find . -type f | wc -l)"
    echo "Total Size: $(du -sh .)"
}

#==================================================================

# This defines a Bash function named print_command_output that takes one argument ($1).
# The function prints the command to be executed in bold blue color, then executes the command, and finally prints a divider.

# echo -e "\033[1;34m> $1\033[0m"

# echo -e enables interpretation of escape sequences. Allows for adding color to text or newlines ("\n").
# \033[1;34m sets text color to bold blue.
# > $1 prints the command being executed (e.g., kubectl config current-context).
# \033[0m resets the text color to default.
print_command_output() {
    echo -e "\033[1;34mCommand: $1\033[0m"               # Bold blue command
    eval "$1"                                            # eval executes the command passed as an argument ($1). Example: If we call print_command_output "kubectl config get-contexts", it runs kubectl config get-contexts.
    echo -e "\n----------------------------------------" # Divider. Using echo -e allows us to interpret escape sequences like \n for a new line.
}

# LIST ALL FUNCTIONS IN A FORMATTED TABLE
# This function scans all .sh files in the functions directory and displays
# all defined functions in a clean, formatted table with File | Name | Description | Parameters | Example.
# Color-coded with bold orange headers matching git.sh styling.

list_functions_table() {
    # Color definitions matching git.sh styling
    local BOLD_ORANGE='\033[1;38;2;249;179;0m'
    local RESET='\033[0m'

    # Try multiple locations for functions directory
    local functions_dir="$BASH_DIR/functions"
    if [ ! -d "$functions_dir" ]; then
        functions_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions"
    fi

    # Check if functions directory exists
    if [ ! -d "$functions_dir" ]; then
        echo -e "${BOLD_ORANGE}Error:${RESET} Functions directory not found."
        echo "  Searched in:"
        echo "    1. \$BASH_DIR/functions: $BASH_DIR/functions"
        echo "    2. Script location: $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions"
        return 1
    fi

    # Enable case-insensitive regex matching for keyword lookups below, and
    # remember whether it needs to be turned back off when we're done.
    local nocasematch_was_on=1
    shopt -q nocasematch || nocasematch_was_on=0
    shopt -s nocasematch

    # Header row, plus one row per function found below (all in-memory —
    # no per-function subprocesses, which is what made this slow before).
    local rows=("FILE NAME|FUNCTION NAME|DESCRIPTION|PARAMETERS|EXAMPLE")
    local comment_buffer=()
    local file file_name line

    while IFS= read -r file; do
        file_name="${file##*/}"
        comment_buffer=()
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ $line =~ ^#! ]]; then
                continue # shebang
            elif [[ $line =~ ^#= ]]; then
                continue # "#===" separator
            elif [[ $line =~ ^#- ]]; then
                continue # "#---" separator
            elif [[ $line =~ ^#[[:space:]]*SOURCE ]]; then
                continue # "# SOURCE ..." header line
            elif [[ $line =~ ^[[:space:]]*#[[:space:]]*(.*)$ ]]; then
                # Comment line: strip the leading "#" and remember it.
                comment_buffer+=("${BASH_REMATCH[1]}")
                # Cap the lookback window, mirroring the original's 30-line reach.
                [ "${#comment_buffer[@]}" -gt 30 ] && comment_buffer=("${comment_buffer[@]:1}")
            elif [[ -z "${line//[[:space:]]/}" ]]; then
                : # blank line: doc blocks may have spacer lines, keep the buffer
            elif [[ $line =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ ]]; then
                local func_name="${BASH_REMATCH[1]}"

                # Only the comment lines closest to the function matter.
                local window=("${comment_buffer[@]}")
                [ "${#window[@]}" -gt 15 ] && window=("${window[@]: -15}")

                local description="" parameters="" example="" first_nonempty="" cl
                for cl in "${window[@]}"; do
                    [ -z "$cl" ] && continue
                    [ -z "$first_nonempty" ] && first_nonempty="$cl"
                    if [ -z "$description" ] && [[ $cl =~ function|list|get|create|delete|set|print|convert|check|validate|extract ]]; then
                        description="$cl"
                    fi
                    if [ -z "$parameters" ] && [[ $cl =~ parameter|usage|argument ]]; then
                        parameters="$cl"
                    fi
                    if [ -z "$example" ] && [[ $cl =~ example ]]; then
                        example="$cl"
                    fi
                done
                [ -z "$description" ] && description="$first_nonempty"

                # Clean up and prepare for table display
                description="${description:0:50}"
                [ -z "$description" ] && description="(No description)"

                parameters="${parameters:0:38}"
                [ -z "$parameters" ] && parameters="See function"

                example="${example:0:50}"
                [ -z "$example" ] && example="$func_name"

                rows+=("${file_name}|${func_name}|${description}|${parameters}|${example}")
                comment_buffer=()
            else
                comment_buffer=() # real code line: doc block above no longer applies
            fi
        done < "$file"
    done < <(find "$functions_dir" -type f -name '*.sh' | sort)

    [ "$nocasematch_was_on" -eq 0 ] && shopt -u nocasematch

    local found_functions=$(( ${#rows[@]} - 1 ))

    # Display formatted table with bold orange header
    if [ "$found_functions" -gt 0 ]; then
        echo ""
        echo -e "${BOLD_ORANGE}=== ALL FUNCTIONS IN $functions_dir ===${RESET}"
        echo ""

        # Use column to format the table with bold header
        printf '%s\n' "${rows[@]}" | column -t -s "|" -o "    " | sed '1s/.*/'$'\033[1;38;2;249;179;0m&\033[0m''/'

        echo ""
        echo -e "${BOLD_ORANGE}Total Functions Found:${RESET} $found_functions"
        echo ""
    else
        echo -e "${BOLD_ORANGE}Warning:${RESET} No functions found in directory."
        return 1
    fi
}

# Export specific functions so child bash processes inherit them
# Note this only works for scripts with "/bin/bash" shebang. Other shells like "/bin/sh" will not have access to these functions.
export -f largest oldfiles dirsummary print_command_output list_functions_table

