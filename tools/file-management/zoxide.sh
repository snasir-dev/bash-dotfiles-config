#!/bin/bash

# zoxide: Better (cd) replacement. Smarter cd. It remembers which directories you use most frequently, so you can "jump" to them in just a few keystrokes.
# Github: https://github.com/ajeetdsouza/zoxide

# USAGE (Source: https://github.com/ajeetdsouza/zoxide?tab=readme-ov-file#getting-started)
# z foo              # cd into highest ranked directory matching foo
# z foo bar          # cd into highest ranked directory matching foo and bar
# z foo /            # cd into a subdirectory starting with foo

# z ~/foo            # z also works like a regular cd command
# z foo/             # cd into relative path
# z ..               # cd one level up
# z -                # cd into previous directory

# zi foo             # cd with interactive selection (using fzf)

# z foo<SPACE><TAB>  # show interactive completions (zoxide v0.8.0+, bash 4.4+/fish/zsh only)

# --- ENVIRONMENT VARIABLES ---

# --- ALIASES ---
# Note that within the completion script command $(zoxide init bash), zoxide automatically creates an alias for z command to the zoxide executable.

# --- FUNCTIONS ---

# --- COMPLETIONS ---
# Per Official Docs instruction in Installation -> Step 2: Setup zoxide on your shell
# 'Add this to the end of your config file (usually ~/.bashrc)':

# Important look at additional options and flags when running the init command:
# https://github.com/ajeetdsouza/zoxide?tab=readme-ov-file#flags
# Adding --cmd cd to replace and override the cd command with zoxide.
# IMPORTANT - using '--cmd cd' will no longer allow us to use 'z' command. Instead we will use 'cd' and for launching zoxide interactive mode do 'cdi' instead of 'zi'.
eval "$(zoxide init bash)"
# eval "$(zoxide init bash --cmd cd)"  # uncomment this line and comment the above line to override 'cd' command with zoxide.
# OVERRIDE 'cd' ALIASES Following allows us to use both 'z' and 'cd' commands easily.
alias cd='z'   # optional: let 'cd' be a wrapper to z. This will allow us to use both 'z', 'zi'
alias cdi='zi' # alias for interactive mode of zoxide
