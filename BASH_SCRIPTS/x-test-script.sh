#!/bin/bash

# This script is a test script to demonstrate functionality.

x-test-script() {
    echo "Running x-test.sh script..."

    # Example command to run
    echo "This is a test command."

    # You can add more commands here as needed
    echo "x-test.sh completed successfully."

    # POWERTOYS_PLUGIN_DEST_PATH="$LOCALAPPDATA/Microsoft/PowerToys/PowerToys Run/Plugins"
    # WINDOWS_PLUGIN_DEST_PATH=$(cygpath -w "$POWERTOYS_PLUGIN_DEST_PATH")
    WINDOWS_PLUGIN_DEST_PATH="$(cygpath -w "$LOCALAPPDATA/Microsoft/PowerToys/PowerToys Run/Plugins")"

    echo "📂 Opening PowerToys plugin directory in File Explorer..."
    echo "🔍 PowerToys Plugin Directory (Windows Path): $WINDOWS_PLUGIN_DEST_PATH"
    # explorer "$WINDOWS_PLUGIN_DEST_PATH"

}

test_what_is_available_in_script() {
    # echo -e "\n" # Newline
    echo # new blank line

    echo -e "\e[1;33mRUNNING: test_what_is_available_in_script()\e[0m]"

    echo -e "\e[1;33mTesting what is available by default in any script that is run. Research states only exported variables, and not functions\e[0m]"

    echo ".BASHRC IS NEVER SOURCED WHEN RUNNING SCRIPTS. (Only exported Variables INHERITED from PARENT SHELL)"

    echo "Are Exported VARIABLES Available? (Yes should see value): BASH_DIR=$BASH_DIR "
    echo "Are Exported FUNCTIONS Available? (No should not see function):"

    echo # new line

    # Check for a function named 'largest'
    echo -e "-- Functions: checking for \e[1;33m'largest' (NOTE I HAVE EXPORTED THIS FUNCTION SHOULD WORK - SEE 'GENERAL-FUNCTIONS')\e[0m] --"
    # declare -f prints function body; declare -F prints only the name if it exists
    if declare -F largest > /dev/null; then
        echo "Function 'largest' is defined in this shell. (You can call it with: largest 5 )"
        echo "Declaring function body:"
        declare -f largest
    else
        echo "Function 'largest' is NOT defined in this shell."
    fi
    echo

    # Check for alias 'filecount'
    echo -e "-- Aliases: checking for \e[1;33m'filecount'\e[0m] --"
    # Aliases are not expanded in non-interactive shells unless expand_aliases is enabled.
    # `alias -p` lists current aliases known to this shell.
    if alias filecount > /dev/null 2>&1; then
        echo "Alias 'filecount' exists: $(alias filecount)"
    else
        echo "Alias 'filecount' does NOT exist in this shell (aliases usually aren't present in non-interactive scripts)."
    fi
    echo
}

x-test-script "$@"

# DO NOT NEED TO USE FUNCTIONS CAN JUST PUT INFORMATION DIRECTLY. See 'x-powertoys-run-install-plugin.sh' for example.

test_what_is_available_in_script "$@"
