#!/bin/bash

# Used to display System Information quickly. Faster and better maintained than Neofetch
# Github: https://github.com/fastfetch-cli/fastfetch

# --- ENVIRONMENT VARIABLES ---

# --- FUNCTIONS ---

# --- ALIASES ---
# shellcheck disable=SC2046
alias ff="fastfetch"               # Default
alias flf="flashfetch"             # Little less options show then default 'fastfetch'
alias ffa="fastfetch -c all.jsonc" # (COMMAND NOT STABLE when running in VS Code Bash - CAUSES FREQUENT CRASHES OF TERMINAL | Seems to work fine in Warp -> Powershell) Shows list of all options to get an idea of what values you might want to display.

# --- COMPLETIONS ---
