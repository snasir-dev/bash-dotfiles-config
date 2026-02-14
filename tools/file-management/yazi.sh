#!/bin/bash

# ============================================
# yazi - terminal file manager written in Rust, based on non-blocking async I/O. It aims to provide an efficient, user-friendly, and customizable file management experience.
# Github: https://github.com/sxyazi/yazi
# Docs: https://yazi-rs.github.io/docs/quick-start
# ============================================

# --- ENVIRONMENT VARIABLES / PATH ---
# By default Yazi uses '%AppData%\yazi\config\yazi.toml' on Windows
# To set ~/.config/yazi, must set that value in XDG_CONFIG_HOME env variable.
# Docs: https://yazi-rs.github.io/docs/configuration/overview#custom-directory
export YAZI_CONFIG_HOME="$HOME/.config/yazi"

# Adds logging to YAZI. See: https://yazi-rs.github.io/docs/plugins/overview/#logging
# You can view the log with this command: cat ~/AppData/Roaming/yazi/state/yazi.log
# export YAZI_LOG=debug

# --- CONFIGURATION ---
# Docs: https://yazi-rs.github.io/docs/configuration/overview
# Yazi has default files (yazi-default, keymap-default, theme-dark.toml | theme-light.toml)
# To override, place a (yazi.toml, keymap.toml, theme.toml) file in the config directory. (For us will be $HOME/.config)

# --- FUNCTIONS ---
# 'y' shell wrapper that provides the ability to change the current working directory when exiting Yazi.
# Link to Official Docs (where I got this from): https://yazi-rs.github.io/docs/quick-start#shell-wrapper
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}

# Function to bootstrap Yazi config directory and empty files
yazi_create_config() {
    local config_dir="$HOME/.config/yazi"

    # Create root directory as well as "flavors" directory which is for themes.
    mkdir -p "$config_dir" "$config_dir/flavors"

    # Create empty config files if missing
    touch "$config_dir/yazi.toml" "$config_dir/keymap.toml" "$config_dir/theme.toml"

    # ya (DO NOT NEED TO SEPARATELY INSTALL )- built-in package manager comes bundled with YAZI dedicated to handling Yazi's themes and plugins
    # Install Theme - Ayu Dark (Themes gets installed in the flavors directory.)
    # List of all themes - REPO: https://github.com/yazi-rs/flavors/blob/main/README.md
    ya pkg add kmlupreti/ayu-dark
    # ya pkg add gosxrgxx/flexoki-dark
    ya pkg add 956MB/vscode-dark-modern
    # ya pkg add 956MB/vscode-dark-plus
    # ya pkg add bennyyip/gruvbox-dark

    echo -e "📃Listing pkg packages:\n"
    ya pkg list

    echo -e "\n✅ Yazi config initialized: $config_dir/yazi.toml, $config_dir/keymap.toml, $config_dir/theme.toml"
}

yazi_install_plugins() {
    echo -e "\n🔌 Installing Yazi plugins:\n"

    # Create init.lua if it doesn't exist. This is a single file yazi uses to allow all of the plugins to be able to configure any ADDITIONAL Settings. Not every plugin has it, if it does it will be in README. They will specify all options you can do and what to put.
    local init_file="$YAZI_CONFIG_HOME/init.lua"
    touch "$init_file"

    #─────────────────────────── cd-git-root ────────────────────────────
    # cd-git-root - Changes directory to the root of the git repository you are currently in
    # Repo: https://github.com/ciarandg/cd-git-root.yazi
    ya pkg add ciarandg/cd-git-root

    #─────────────────────────── bunny ────────────────────────────
    ya pkg add stelcodes/bunny

    #─────────────────────────── yamb ────────────────────────────
    # yamb: bookmarks plugins. It supports persistence, jumping by a key, jumping by fzf.
    # Repo: https://github.com/h-hg/yamb.yazi
    ya pkg add h-hg/yamb

    #─────────────────────────── projects (Save Yazi Layouts)  ────────────────────────────
    # projects.yazi: A Yazi plugin that adds the functionality to save, load and merge projects. A project means all tabs and their status, including cwd and so on.
    # Repo: https://github.com/MasouShizuka/projects.yazi
    ya pkg add MasouShizuka/projects

    #─────────────────────────── bookmarks.yazi ────────────────────────────
    # bookmarks.yazi: A Yazi plugin that adds the basic functionality of vi-like marks.
    # Repo: https://github.com/dedukun/bookmarks.yazi
    ya pkg add dedukun/bookmarks

    #─────────────────────────── simple-tag (Tag Management) ────────────────────────────
    # simple-tag is a Yazi plugin that allows you to add tags to files and folders. Each tag is associated with a unique key.
    # Repo: https://github.com/boydaihungst/simple-tag.yazi
    ya pkg add boydaihungst/simple-tag

    echo -e "\n📃Listing installed plugins:\n"
    ya pkg list
}

# FOLLOWING FUNCTION IS FOR 'PROJECTS' YAZI PLUGIN
# See: https://github.com/MasouShizuka/projects.yazi?tab=readme-ov-file#optional-configuration
# "You can also load a specific project by using the below Bash/Zsh function (uses the "official" shell wrapper, but you can also replace y with yazi)"
# Usage: With the above function you can open a specific project by running -> yap SomeProject
# MY EXAMPLE: Trigger with "yap default" which will open my "default" project saved.
# ============================================================================
function yap() {
    local yaziProject="$1"
    shift
    if [ -z "$yaziProject" ]; then
        >&2 echo "ERROR: The first argument must be a project"
        return 64
    fi

    # Generate random Yazi client ID (DDS / `ya emit` uses `YAZI_ID`)
    local yaziId=$RANDOM

    # Use Yazi's DDS to run a plugin command after Yazi has started
    # (the nested subshell is only to suppress "Done" output for the job)
    ( (
        # sleep 0.1  # DEFAULT VALUE, BUT TOO SMALL ALWAYS GOT ERROR: "Cannot emit command: No connection could be made because the target machine actively refused it. (os error 10061)"
        sleep 0.75 # Slight delay after starting yazi, will then immediately load project specified.
        YAZI_ID=$yaziId ya emit plugin projects "load $yaziProject"
    ) &)

    # Run Yazi with the generated client ID
    y --client-id $yaziId "$@" || return $?
}
# # ============================================================================

# --- ALIASES ---
# This will trigger y() function above instead of the yazi.exe executable. (If for any reason you need to trigger yazi.exe, run command 'command yazi')
# Remember if you want to exit out of yazi without it changing directory, press Q instead of q
alias yazi='y'
alias yp='yap default' # Loads the 'default' project. (Requires projects.yazi plugin and the 'default' project to already be created)

# --- COMPLETIONS ---
