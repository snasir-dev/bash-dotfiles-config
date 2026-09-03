#!/bin/bash

# Setup script for bash configuration repository
# - Copies .bashrc and .bash_profile from 'config/setup' into the user's home directory (~).
# - Backs up any existing versions to a timestamped backup folder, skipping any that are
#      already a symlink to the right file (so re-running it is a no-op)
# - Creates symbolic links from the home directory to the files in the .bash repo
#      (located in "./config/setup"). If you make any changes to .bashrc in this repo, it will reflect in your home directory.
# - Creates a .bash_local override file if missing

# USAGE (run from the ROOT of this REPO): ./setup_bash.sh

# Define the base directory
BASH_REPO_DIR="$HOME/.config/bash"
BACKUP_DIR="$BASH_REPO_DIR/.bash_backup_$(date +%Y_%m_%d_%H%M%S)"
echo "BASH_REPO_DIR: $BASH_REPO_DIR"
echo "BACKUP_DIR: $BACKUP_DIR"

# Function to backup existing files.
# Skips a symlink that already resolves to the file we are about to link it to. Without this,
# re-running the script - or running it after @create-symlinks.ps1, which now makes these same
# two links on Windows pointing straight at BASH_REPO - moves a perfectly good symlink into a
# new timestamped backup folder every time, and those pile up inside ~/.config/bash.
# readlink -f canonicalises both sides, so a link made via ~/.config/bash and one made direct
# to BASH_REPO compare equal.
backup_file() {
    local file="$1"
    local intended_target="$2"

    if [ -L "$file" ] && [ -n "$intended_target" ] &&
        [ "$(readlink -f "$file")" = "$(readlink -f "$intended_target")" ]; then
        echo "Already linked correctly, leaving alone: $file"
        return
    fi

    if [ -f "$file" ] || [ -L "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$file" "$BACKUP_DIR/"
        echo "Backed up $file to $BACKUP_DIR/"
    fi
}

# Create necessary directories. They should already be created by the git clone command, this is just for redundancy.
# Should not be necessary. Cloning Repo should take care of this step.
# echo "Creating directory structure..."
# mkdir -p "$BASH_REPO_DIR"/{setup,completions/packages,functions,aliases,scripts,env,themes,plugins}

# Backup existing files
echo "Backing up existing .bashrc and .bash_profile files..."
backup_file "$HOME/.bashrc"       "$BASH_REPO_DIR/config/setup/.bashrc"
backup_file "$HOME/.bash_profile" "$BASH_REPO_DIR/config/setup/.bash_profile"

# Create symbolic links
echo "Creating symbolic links..."
ln -sf "$BASH_REPO_DIR/config/setup/.bashrc" "$HOME/.bashrc"
ln -sf "$BASH_REPO_DIR/config/setup/.bash_profile" "$HOME/.bash_profile"

# Create local override files if they don't exist
echo "Creating local override files. Source local machine-specific settings. Note '.bash_local' shouldn't be in version control..."
touch "$HOME/.bash_local"

echo "Installation complete!"
echo "Remember to source our bash config. Run Command: source ~/.bashrc"
