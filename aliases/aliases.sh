#!/bin/bash
# ALIASES - Command Aliases and Shortcuts
#**************************************************************

#==================
# PATH ALIASES    #
#==================

# ALIAS TO PRINT THE CURRENT WORKING DIRECTORY AS A WINDOWS PATH
# pwd - Prints the current working directory in Unix format
# cygpath -w --file: This runs the converter. The --file - (or -f -) part is important; it tells cygpath to read the path from the standard input (which is coming from the pipe) instead of from a command-line argument.
# shellcheck disable=SC2139
# alias {wpwd,pwdw}='pwd | cygpath -w --file -'

#====================
# SCRIPT ALIASES    #
#====================
# Specify the path to your scripts directory
SCRIPTS_DIR="$BASH_DIR/BASH_SCRIPTS"
alias {scripts,x,X}='$SCRIPTS_DIR/x-script-selector.sh'

# YAZI-based selector (functions AND scripts, browsed with your normal Yazi keys).
# Must be a FUNCTION, not a plain alias: x-script-selector-YAZI.sh writes the chosen
# command to $BASH_SELECTOR_CMD, and we `source` it HERE so any `cd`/env changes made
# by the selected function/script persist in THIS shell instead of a subshell.
x-script-selector-yazi() {
    export BASH_SELECTOR_CMD="${TMPDIR:-/tmp}/bash-selector-cmd.$$"
    : > "$BASH_SELECTOR_CMD"
    "$SCRIPTS_DIR/x-script-selector-YAZI.sh" "$@"
    [[ -s "$BASH_SELECTOR_CMD" ]] && source "$BASH_SELECTOR_CMD"
    rm -f "$BASH_SELECTOR_CMD"
    unset BASH_SELECTOR_CMD
}
alias {yscripts,xy,XY}='x-script-selector-yazi'

#====================================================================
# FILE INFORMATION & LISTING & DIRECTORY NAVIGATION ALIASES         #
#====================================================================
# NOTE: using eza now instead of ls. ls command now points to eza. See plugins/file-management/eza.sh for more details.

# ls commands
alias ll="ls -la"                                                    # Alias to list files in long format, including hidden files
alias la="ls -A"                                                     # Alias to list all files, including hidden ones
alias l="ls -CF"                                                     # Alias to list files in a multi-column format with file type indicators
alias lr='ls -R --color=auto -F -I "node_modules" -I "bin" -I "obj"' # Recursively list all files with colors and file type indicators, ignoring common build/dependency folders (node_modules, bin, obj)

# List files with detailed info, sorted by size
alias ls-size='du -sh * | sort -rh'
# Count files in current directory and subdirectories
alias filecount='find . -type f | wc -l'

# Show file type for a given file or directory. Uses 'file' command.
alias typeof='file'

#====================================================================
# DIRECTORY NAVIGATION ALIASES
# Aliases to make moving around the filesystem faster and easier.
#====================================================================

# ------- IMPORTANT - 'zoxide.sh' OVERRIDES 'cd' alias -------
# See plugins/file-management/zoxide.sh for more details.
# ------------------------------------------------------------

# Go back to the previous directory. Very fast for going back and forth.
alias back='cd -' # Use 'back' to return to the last directory you were in.

# Stack-based directory navigation. Useful for jumping around and returning to previous locations.
# `pushd`, `popd`, `dirs` (Aliases 'push', 'pop', 'listd'): Stack-based navigation.
#    - 'push [directory]':  Changes to [directory] and remembers the previous directory. Adds [directory] to the stack.
#    - 'pop':  Returns to the last directory you 'pushd' from.  Removes the top location from the stack.
#    - 'dirs' (or 'listd'): Shows the stack of directories you've 'pushd' into.  Numbering helps visualize the stack.
#    Example:
#    push /tmp  # Go to /tmp, remember current location
#    push /var  # Go to /var, remember /tmp
#    dirs       # Shows stack, e.g., 0 /var 1 /tmp ...
#    pop        # Go back to /tmp
#    pop        # Go back to original location before 'push /tmp'
#alias push='pushd' # Use the push function specified in functions/directory-traversal-functions.sh.
alias pop='popd_at_index' # Return to the directory at the top of the stack (undoes 'pushd'). Calls popd_at_index function in directory-traversal-functions.sh.
alias dirs='dirs -v'      # View the directory stack with index numbers. Useful to see where you've been with 'pushd'.
alias listd='dirs -v'     # Alternative name for 'dirs -v' - list directory stack

# Shorter aliases for common directory locations.
alias {cdrive,"c:",".DRIVE_C"}='cd /c/' # Alias to go to the C: root directory

alias temp='cd /c/temp'                                          # Alias to go to C:/temp
alias home='cd ~'                                                # Go directly to your home directory.
alias downloads='cd ~/Downloads'                                 # Go directly to your Downloads directory.
alias desktop='cd ~/Desktop'                                     # Go directly to your Desktop directory.
alias documents='cd ~/Documents'                                 # Go directly to your Documents directory.
alias pictures='cd $USERPROFILE/Pictures'                        # Go directly to your Pictures directory.
alias videos='cd $USERPROFILE/Videos'                            # Go directly to your Videos directory.
alias obsidian='cd $USERPROFILE/Documents/@OBSIDIAN/@MAIN_VAULT' # Go directly to main Obsidian vault.

# WORKSPACE_DIR=~/Documents/@MAIN_WORKSPACE # Cannot use quotes, will treat "~" as literal string. No Quotes or using $HOME env variable works.
# Prefix going to specific directories with "." Use ".." to open directories with git repositories initialized.
# Easy navigation to directories that are not git repositories. Prefix with '.'
WORKSPACE_DIR="$HOME/Documents/@MAIN_WORKSPACE"
alias ".DIR_main_workspace"='cd $WORKSPACE_DIR' # Go to my Main Workspace. Just type '.workspace' to go there.
alias ".DIR_repos"='cd $WORKSPACE_DIR/@REPOS'
alias ".DIR_apps"='cd $WORKSPACE_DIR/@REPOS/@APPS'

# Note CURRENTLY NOT A REPO. For just normal VS Code testing and files. Later might convert to a repo.
alias ".REPO_general_repo"='cd $WORKSPACE_DIR/@REPOS/GENERAL_REPO'

# Prefix aliases opening repositories with ".."
alias ".REPO_fullstack-react-net-app"='cd $WORKSPACE_DIR/@REPOS/@APPS/fullstack/Fullstack.React.NET.App'
alias ".REPO_shared-resources-repo"='cd $WORKSPACE_DIR/@REPOS/@SHARED_RESOURCES_REPO'
alias ".REPO_bash"='cd $BASH_DIR'
alias ".REPO_orbz-cli"='cd $WORKSPACE_DIR/@REPOS/\SCRIPTS_SHELLS_CLI_TOOLS/CLI_TOOLS/orbz-cli'
alias ".REPO_obsidian_main_vault"='cd $HOME/Documents/@OBSIDIAN/@MAIN_VAULT'

# Visual File Directory - Tree like structure
# Official "tree" command with git-bash.
alias tree='tree.com'
# Tree-like view including hidden files
# Below mimics tree functionality.
# Basic tree-like directory structure (excluding hidden files)
alias tree2='find . -maxdepth 2 -type d | sed -e "s/[^-][^\/]*\//  |/g" -e "s/|\([^ ]\)/|-\1/"'
alias treeall='find . -type d | sed -e "s/[^-][^\/]*\//  |/g" -e "s/|\([^ ]\)/|-\1/"'

# (IMPORTANT) Filetree - Custom function to display a tree-like structure of files and directories.
# Will run filetree shell method below. Remember after ft can specify parameters:
# Example: ft 3 false ~/Documents/@MAIN_WORKSPACE
alias ft="filetree"

#==============================================================================
# COMMAND SHORTCUTS & UTILITIES ALIASES
# Aliases for frequently used commands or to add extra functionality.
#==============================================================================

alias mkdir='mkdir -p' # Create directories recursively (including parent directories if they don't exist). Very convenient for nested directories.
# alias mkd='mkdir -p'  # Shorter version for 'mkdir -p'.

alias rm='rm -i' # Interactive remove - prompts before deleting files. Prevents accidental deletion, especially with 'rm -rf'.
alias rmi='rm -i'

alias cp='cp -i -r'  # Interactive copy - prompts before overwriting files.  Prevents accidental overwrites. -r: Recursive mode (needed for copying directories).
alias cpi='cp -i -r' # Shorter version for interactive copy.

alias mv='mv -i'  # Interactive move - prompts before overwriting files. Prevents accidental overwrites during moves.
alias mvi='mv -i' # Shorter version for interactive move.

alias grep='grep --color=auto' # Grep with color highlighting.  Makes grep output much easier to read.
# alias g='grep --color=auto'    # Shorter alias for colorized grep.

#==================================
# CLIPBOARD UTILITIES             #
#==================================

# Creates a shorter, convenient alias for the copy function
alias copy="copy"

#===========================
# KUBERNETES ALIASES       #
#===========================
alias k="kubectl"
alias kga="k get all,endpoints,ingress,pv,pvc,cm,secrets,nodes -o wide"
# Get Current Active Namespace
alias "kgns"="kubectl config view --minify | grep namespace"
#alias kga-<your-name-space>="k get all,pv,pvc,cm,secrets,nodes -n <namespace-name> -o wide"
# alias kctx="kubectl config use-context"
# alias kns="kubectl config set-context --current --namespace"

# Note - must have script x-k8s-kube-info.sh in the scripts directory to run this alias.
# I have added all scripts to PATH. Can directly call the script by just stating "x-k8s-kube-info". No need for alias
# alias x-k8s-kube-info="$BASH_DIR/BASH_SCRIPTS/x-k8s-kube-info.sh"

#===========================
# GREP + SEARCH ALIASES    #
#===========================
# alias grep="grep --color=auto"
# alias fgrep="fgrep --color=auto"
# alias egrep="egrep --color=auto"
# alias findtxt="find . -type f -name '*.txt'"

#======================
# SOURCE ALIASES      #
#======================
# alias src="source ~/.bashrc"
# alias reload="source ~/.bashrc"
# alias refresh="source ~/.bashrc"
# alias r="source ~/.bashrc"

# Function to reload the shell, with an option for setting debug output
# Optionally takes a single argument: 'true' to enable debug output. If no value is provided, defaults to 'false'.
# Usage: reload_shell [-d|--d|--debug|--verbose|true]

reload_shell() {
    local arg="$1"

    # Default to DEBUG=true, unless we specify any of these arguments (false, -s, --silent, -q, --quiet)
    case "$arg" in
        # If the argument matches any of these "off" patterns, disable debug mode.
        false | -s | --silent | -q | --quiet)
            export DEBUG=false
            ;;
        # For any other argument, OR if NO argument is provided, enable debug mode.
        *)
            # echo "🐞🐞🐞 Debug mode enabled. Sourcing ~/.bashrc... 🐞🐞🐞"
            export DEBUG=true
            ;;
    esac

    # INVERSE CONDITION ABOVE. Since we want to enable debug mode by default, we are providing silent flags instead of debug flags. Belows is reference to reverse the logic.
    # Match any of the debug-like inputs (-d, --d, -debug, --debug, -v, --verbose, true)
    # If any of these are provided, enable debug mode.
    # case "$arg" in
    #   -d|--d|-debug|--debug|-v|--verbose|true)
    #     # echo "🐞🐞🐞 Debug mode enabled. Sourcing ~/.bashrc... 🐞🐞🐞"

    #     export DEBUG=true
    #     ;;
    #   *)
    #     export DEBUG=false
    #     ;;
    # esac

    # Source the .bashrc file to apply changes
    source ~/.bashrc

    # Unset DEBUG after sourcing to clean up the environment
    unset DEBUG
}

# shellcheck disable=SC2139
# Brace expansion {src,reload,refresh,r} generates four separate aliases (src, reload, refresh, r) in a single command. Bash processes this during startup with no runtime performance difference
# alias {src,reload,refresh,r}="source ~/.bashrc"  # NORMALLY HOW WE SOURCE .bashrc
alias {src,reload,refresh,r,R}="reload_shell" # Use the reload_shell function to source .bashrc with options
