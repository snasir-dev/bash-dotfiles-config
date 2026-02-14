#!/bin/bash

# Official Github: https://github.com/sharkdp/bat

# BAT is a better version of 'cat' command with syntax highlighting, line numbers, git integration, and themes customization.

# --- ENVIRONMENT VARIABLES ---


# --- FUNCTIONS ---

# bat on Windows does not natively support Cygwin's unix-style paths (/cygdrive/*).
# When passed an absolute cygwin path as an argument, 
# bat will encounter the following error: 
# The system cannot find the path specified. (os error 3)
# Source (function taken directly from official bat repo):
# https://github.com/sharkdp/bat?tab=readme-ov-file#cygwin

# This can be solved by creating a wrapper or adding the following function to your .bash_profile file:

# bat() {
#     local index
#     local args=("$@")
#     for index in $(seq 0 ${#args[@]}) ; do
#         case "${args[index]}" in
#         -*) continue;;
#         *)  [ -e "${args[index]}" ] && args[index]="$(cygpath --windows "${args[index]}")";;
#         esac
#     done
#     command bat "${args[@]}"
# }



# --- ALIASES ---


# --- COMPLETIONS ---

#=================================================
# bat Auto-Completion SCRIPTS                    #
#=================================================
# Official bat Documentation: https://github.com/sharkdp/bat?tab=readme-ov-file#from-cratesio
# The bat --generate-completion-script bash command generates the completion script.
# Sourcing this output enables tab completion for bat flags, languages, and themes.
# Pre-requisite - Ensure bat is installed and available in PATH.
# Can install on Windows with command: choco install bat -y
if command -v bat &>/dev/null; then    
    source <(bat --completion bash)
fi
