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
# all defined functions in a clean, formatted table with Name | Description | Parameters | Example.
# Color-coded with bold orange headers matching git.sh styling.

list_functions_table() {
    # Color definitions matching git.sh styling
    local BOLD_ORANGE='\033[1;38;2;249;179;0m'
    local RESET='\033[0m'

    # Try multiple locations for functions directory
    local functions_dir=""

    # Priority 1: BASH_DIR environment variable
    if [ -d "$BASH_DIR/functions" ]; then
        functions_dir="$BASH_DIR/functions"
    # Priority 2: Current worktree (script location detection)
    elif [ -d "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions" ]; then
        functions_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions"
    # Priority 3: Hardcoded worktree path for testing
    elif [ -d "/c/Users/Syed/Documents/@MAIN_WORKSPACE/@REPOS/SCRIPTS_SHELLS_CLI_TOOLS/Bash/BASH_REPO.worktrees/agents-frantic-eel/functions" ]; then
        functions_dir="/c/Users/Syed/Documents/@MAIN_WORKSPACE/@REPOS/SCRIPTS_SHELLS_CLI_TOOLS/Bash/BASH_REPO.worktrees/agents-frantic-eel/functions"
    fi

    # Check if functions directory exists
    if [ ! -d "$functions_dir" ]; then
        echo -e "${BOLD_ORANGE}Error:${RESET} Functions directory not found."
        echo "  Searched in:"
        echo "    1. \$BASH_DIR/functions: $BASH_DIR/functions"
        echo "    2. Script location: $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions"
        echo "    3. Worktree path"
        return 1
    fi

    # Temporary file for collecting function data
    local temp_file=$(mktemp)
    trap "rm -f '$temp_file'" RETURN

    # Header row
    echo "FUNCTION NAME|DESCRIPTION|PARAMETERS|EXAMPLE" > "$temp_file"

    # Get all function definitions from all .sh files
    local found_functions=0
    while IFS=: read -r script_file line_num rest; do
        if [[ $rest =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)\ *\{ ]]; then
            local func_name="${BASH_REMATCH[1]}"
            ((found_functions++))

            # Extract documentation from comments above the function (up to 30 lines back)
            local start_line=$((line_num - 30))
            [ $start_line -lt 1 ] && start_line=1

            # Get comments and filter out shebang, separators, and SOURCE lines
            local doc_text=$(sed -n "${start_line},$((line_num-1))p" "$script_file" | \
                grep "^#" | \
                grep -v "^#!" | \
                grep -v "^#=" | \
                grep -v "^#-" | \
                grep -v "^# SOURCE" | \
                sed 's/^#[[:space:]]*//g' | \
                sed 's/^#$//g' | \
                tail -15)

            local description=""
            local parameters=""
            local example=""

            # Parse documentation - prioritize lines with keywords
            if [ ! -z "$doc_text" ]; then
                # Try to find a line that describes what the function does
                description=$(echo "$doc_text" | \
                    grep -iE "function|list|get|create|delete|set|print|convert|check|validate|extract" | \
                    head -1)

                # Fallback: use first non-empty line
                if [ -z "$description" ]; then
                    description=$(echo "$doc_text" | sed '/^[[:space:]]*$/d' | head -1)
                fi

                # Look for parameters/usage info
                parameters=$(echo "$doc_text" | grep -iE "parameter|usage|argument" | head -1)

                # Look for example
                example=$(echo "$doc_text" | grep -iE "example" | head -1)
            fi

            # Clean up and prepare for table display
            description="${description:0:50}"
            [ -z "$description" ] && description="(No description)"

            parameters="${parameters:0:38}"
            [ -z "$parameters" ] && parameters="See function"

            example="${example:0:50}"
            [ -z "$example" ] && example="$func_name"

            # Append to temp file
            echo "${func_name}|${description}|${parameters}|${example}" >> "$temp_file"
        fi
    done < <(grep -rn "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$functions_dir")

    # Display formatted table with bold orange header
    if [ $(wc -l < "$temp_file") -gt 1 ]; then
        echo ""
        echo -e "${BOLD_ORANGE}=== ALL FUNCTIONS IN $functions_dir ===${RESET}"
        echo ""

        # Use column to format the table with bold header
        cat "$temp_file" | column -t -s "|" -o "    " | sed '1s/.*/'$'\033[1;38;2;249;179;0m&\033[0m''/'

        echo ""
        echo -e "${BOLD_ORANGE}Total Functions Found:${RESET} $(( $(wc -l < "$temp_file") - 1 ))"
        echo ""
    else
        echo -e "${BOLD_ORANGE}Warning:${RESET} No functions found in directory."
        return 1
    fi
}

# Export specific functions so child bash processes inherit them
# Note this only works for scripts with "/bin/bash" shebang. Other shells like "/bin/sh" will not have access to these functions.
export -f largest oldfiles dirsummary print_command_output list_functions_table

