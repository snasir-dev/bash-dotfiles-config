#!/bin/bash

# eza OFFICIAL GITHUB: https://github.com/eza-community/eza
# eza (better 'ls'): It lists files and directories with more features and better defaults than the traditional 'ls' command. It uses colors to distinguish file types and metadata. It knows about symlinks, extended attributes, and Git. And it’s small, fast, and just one single binary.

# By deliberately making some decisions differently, eza attempts to be a more featureful, more user-friendly version of ls.

# --- ENVIRONMENT VARIABLES ---

# --- FUNCTIONS ---

# --- ALIASES ---

# ---- Eza (better ls) -----
# Use eza as a drop-in replacement for ls.

# --color=always       → force color output even when piped
# --long               → use long listing format (like 'ls -l')
# --git                → show Git status for each file
# --no-filesize        → hide file size column
# --icons=always       → always show icons (requires Nerd Font)
# --no-time            → hide modification time column
# --no-user            → hide user/owner column
# --no-permissions     → hide permission bits column
alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"

# --- COMPLETIONS ---

#=================================================
# eza Auto-Completion SCRIPTS                    #
#=================================================
# Official eza Documentation: https://eza.rocks/completion
# NO OFFICIAL eza --completions bash command available.
# Instead eza provides a script that can be sourced to enable completions.
# Run command:
# curl -Lo "$BASH_DIR/completions/packages/eza.bash" https://raw.githubusercontent.com/eza-community/eza/main/completions/bash/eza
# This downloads the eza completion script from (ROOT_EZA_REPO/completions/bash/eza) to the $BASH_DIR/completions/packages/eza.bash
# Sourcing this output enables tab completion for eza flags and options.
# Pre-requisite - Ensure eza is installed and available in PATH.
# Can install on Windows with command: choco install eza -y

# -f $BASH_DIR/completions/eza.bash checks if the file exists before sourcing it.
if command -v eza &> /dev/null && [[ -f "$BASH_DIR/completions/packages/eza.bash" ]]; then
    source "$BASH_DIR/completions/packages/eza.bash"
fi
