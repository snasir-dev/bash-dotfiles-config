#!/bin/bash

# Have added this script to PATH. Can directly call the script by just stating "x-script-selector".
# Also have added an alias for it in aliases/aliases.sh file.
# can use "scripts" alias command to run this script.

# This script allows us to select and run scripts interactively using fzf.

# Best practice to use kebab-case for script names, e.g., "x-script-selector.sh". It is easier to type.
x-script-selector() {
    echo "📝  Starting script selection using fzf..."

    # 1. Define the directory where this script is located
    local scripts_dir="$BASH_DIR/BASH_SCRIPTS"

    # 2. Check if the script directory actually exists
    if [[ ! -d "$scripts_dir" ]]; then
        echo "Error: Scripts directory not found at '$scripts_dir'"
        return 1
    fi

    # 3. Find executable scripts and pipe them to fzf for selection
    local selected_script

    # Old Logic: $(find "$scripts_dir" -maxdepth 1 -type f -executable | fzf)
    # Old fd logic: $(fd --max-depth 1 --extension sh . "$scripts_dir" | fzf)
    # Adding '--base-directory' instead of "." (fd --base-directory "$scripts_dir") Will show relative path based on the path specified instead of full path. But will cause issues with preview.
    selected_script=$(
        # awk - Prepend number of slashes to each line. This adds a numeric value like depth 5 before each line. We sort it based off that value then remove these numbers with 'cut'. This makes it so we SORT THE FD RESULTS BY FOLDER DEPTH, SO THAT SCRIPTS IN FEWER NESTED DIRECTORIES (CLOSER TO THE ROOT) APPEAR AT THE TOP
        fd . "$scripts_dir" \
            --max-depth 5 \
            --extension sh \
            --exclude '*x-script-selector*' \
            | awk -F'/' '{ print NF-1, $0 }' \
            | sort -n \
            | cut -d' ' -f2- \
            | fzf \
                --height 50% \
                --border=rounded \
                --prompt="Select a script to run from (SCRIPTS_DIR:$scripts_dir) > "
    )
    # selected_script=$(fd . "$scripts_dir" \
    #     --max-depth 5 \
    #     --extension sh \
    #     --exclude '*x-script-selector*' | fzf \
    #     --height 50% \
    #     --border=rounded \
    #     --prompt="Select a script to run from (SCRIPTS_DIR:$scripts_dir) > ")

    # 4. If a script was selected, execute it
    if [[ -n "$selected_script" ]]; then
        echo "▶️  Executing: $(basename "$selected_script")"
        # Execute the script, passing along any arguments that are provided to the `scripts` command
        "$selected_script" "$@"
    else
        echo "🚫 No script selected."
    fi
}

# CALL FUNCTION

# "$@" is a special variable that represents all the command-line arguments passed to our script. The double quotes are crucial because they ensure each argument is treated as a separate entity, even if it contains spaces.
x-script-selector "$@"
