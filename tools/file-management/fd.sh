#!/bin/bash

# fd is used for Finding files and directories. What is fd? A modern alternative to 'find' command, it is faster, has more user-friendly syntax and sensible defaults (IMPORTANT: it respects .gitignore by default).

# --- ENVIRONMENT VARIABLES ---

# --- FUNCTIONS ---

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Show fd command examples
fdhelp() {
    cat << 'EOF'
FD - MOST USEFUL COMMANDS AND EXAMPLES:

BASIC USAGE:
  fd <pattern>                    # Find files/dirs matching pattern
  fd -i <pattern>                 # Case-insensitive search
  fd -g <pattern>                 # Glob pattern (exact match)

FILE TYPE FILTERS:
  fd -t f <pattern>               # Files only
  fd -t d <pattern>               # Directories only
  fd -t x <pattern>               # Executable files only
  fd -t l <pattern>               # Symlinks only

DEPTH CONTROL:
  fd -d 1 <pattern>               # Search current directory only
  fd -d 3 <pattern>               # Search up to 3 levels deep
  fd --min-depth 2 <pattern>      # Skip first 2 levels

EXTENSION FILTERS:
  fd -e js -e ts                  # Find JS/TS files
  fd . -e txt                     # Find all .txt files

SIZE FILTERS:
  fd -S +100M                     # Files larger than 100MB
  fd -S -1k                       # Files smaller than 1KB
  fd -S +1M -S -10M               # Files between 1MB and 10MB

DATE FILTERS:
  fd --change-newer-than 1day     # Modified in last day
  fd --change-older-than 1week    # Modified more than week ago

EXCLUSIONS:
  fd -E node_modules              # Exclude node_modules
  fd -E '*.tmp'                   # Exclude .tmp files
  fd --hidden                     # Include hidden files

EXECUTION:
  fd -x ls -la                    # Execute 'ls -la' on each result
  fd '*.txt' -x head -5           # Show first 5 lines of each .txt

POPULAR REAL-WORLD EXAMPLES:
  fd 'README'                     # Find README files
  fd -i 'todo'                    # Find files with 'todo' (case-insensitive)
  fd -e cs -x wc -l               # Count lines in all C# files
  fd -t d node_modules            # Find all node_modules directories
  fd -e log --change-newer-than 1day  # Find recent log files
  fd '' -t f -S +10M              # Find files larger than 10MB
  fd -H -t f '^\.'                # Find hidden files (dotfiles)

ADVANCED COMMANDS:
fd -t d --hidden --glob '.git' ~/Documents/\@MAIN_WORKSPACE/\@REPOS/ -E 'Git' -E '**/android/**' -x dirname {} | sort | sed 's#.*/Documents/@MAIN_WORKSPACE/##'  				# Find all Git Repositories ('.git') dirs in @REPOS folder, exclude 'Git' folder in @REPOS and ANY 'android' folder in any subdirectories, outputs the directory names, sort alphabetically, shortens the url path to start from @REPOS folder.

EOF
}

# Quick reference for common patterns
fdpatterns() {
    cat << 'EOF'
COMMON FD PATTERNS:

DEVELOPMENT:
  fd -e cs | head -10             # First 10 C# files
  fd -e js -e ts -E node_modules  # JS/TS files, skip node_modules
  fd 'test' -t d                  # Find test directories
  fd '.*\.config\.' -i            # Find config files
  fd 'Program' -e cs              # Find Program.cs files

CLEANUP:
  fd -e tmp -e log -x rm          # Remove temp and log files
  fd 'node_modules' -t d -x rm -rf # Remove node_modules dirs
  fd -e bak -e old                # Find backup files

ANALYSIS:
  fd -e cs -x wc -l | awk '{sum+=$1} END {print sum}'  # Total lines in C# files
  fd -t f -S +100M                # Find large files for cleanup
  fd -t f --change-older-than 1year  # Find old files

WINDOWS SPECIFIC:
  fd -e exe -e dll                # Find executables and DLLs
  fd -i 'desktop.ini'             # Find Windows desktop config files
  fd -e bat -e cmd                # Find batch files
EOF
}

# --- ALIASES ---

# ============================================================================
# BASIC SEARCH ALIASES
# ============================================================================

# Find files by name (case-insensitive)
alias fdi='fd -i'

# Find files by exact name
alias fde='fd -g'

# Find only files (no directories)
alias fdf='fd -t f'

# Find only directories
alias fdd='fd -t d'

# Find only executable files
alias fdx='fd -t x'

# Find only symlinks
alias fdl='fd -t l'

# ============================================================================
# DEPTH AND SIZE ALIASES
# ============================================================================

# Search only in current directory (depth 1)
alias fd1='fd -d 1'

# Search up to 2 levels deep
alias fd2='fd -d 2'

# Search up to 3 levels deep
alias fd3='fd -d 3'

# Find large files (over 100MB)
alias fdlarge='fd -t f -S +100M'

# Find small files (under 1KB)
alias fdsmall='fd -t f -S -1k'

# Find empty files
alias fdempty='fd -t f -S 0'

# ============================================================================
# DATE-BASED ALIASES
# ============================================================================

# Find files modified today
alias fdtoday='fd -t f --change-newer-than 1day'

# Find files modified this week
alias fdweek='fd -t f --change-newer-than 1week'

# Find files modified this month
alias fdmonth='fd -t f --change-newer-than 1month'

# Find recently modified files (last hour)
alias fdrecent='fd -t f --change-newer-than 1hour'

# ============================================================================
# EXTENSION-SPECIFIC ALIASES
# ============================================================================

# Find JavaScript/TypeScript files
alias fdjs='fd -e js -e ts -e jsx -e tsx'

# Find C# files
alias fdcs='fd -e cs -e csx'

# Find text files
alias fdtxt='fd -e txt -e md -e log'

# Find image files
alias fdimg='fd -e jpg -e jpeg -e png -e gif -e bmp -e svg'

# Find config files
alias fdconfig='fd -e json -e xml -e yaml -e yml -e toml -e ini'

# Find source code files
alias fdsrc='fd -e c -e cpp -e h -e hpp -e cs -e js -e ts -e py -e java'

# --- COMPLETIONS ---
#===============================================
# fd (Rust-based Find) Auto-Completion SCRIPT   #
#===============================================
# Official repo: https://github.com/sharkdp/fd
# Bash completion is supported via: `fd --completion bash`
# This loads `fd` auto-completion in Bash if it's installed and in PATH.

if command -v fd &> /dev/null; then
    source <(fd --gen-completions bash)
fi

# If you want better performance (recommended), store the generated script once:
# fd --gen-completions bash > ~/.bash_completions/fd
# Then source it in your .bashrc or .bash_profile:
# if [ -f ~/.bash_completions/fd ]; then
#     source ~/.bash_completions/fd
# fi
