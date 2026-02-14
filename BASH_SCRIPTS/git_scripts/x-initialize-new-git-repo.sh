#!/bin/bash

# This script Initializes a NEW PRIVATE GIT REPOSITORY. It uses the GitHub CLI (gh) to create the remote repository and set the remote origin link. It checks if git/gh exists and if we are logged in, if we are NOT logged in, it will ask us to login. It will automatically add a README.md (if it does not exists) and bring over .gitignore and .gitattributes files from @SHARED_RESOURCE_REPO.

# ================================

# Set the trap at the very beginning of the script
# The trap command in Bash automatically runs a piece of code whenever the script exits, for any reason. We want to know the exit code status (what code fzf returns if say we press ESC or CTRL+C)
# $?: This special shell variable always holds the exit code of the LAST EXECUTED COMMAND ONLY.
# trap 'echo "DEBUG: Script exited with EXIT-CODE $?"' EXIT

# ==========================================
# 1. SETUP & TRAPS
# ==========================================

# Trap function to run on exit
trap_message_func() {
    # Capture the exit code of the last command run in the script
    EXIT_CODE=$?
    echo ""
    echo "DEBUG: Script exited with EXIT-CODE $EXIT_CODE"

    if [ $EXIT_CODE -eq 0 ]; then
        echo "✅ DONE: Repository created and pushed successfully."
    else
        echo "❌ FAILED: The script encountered an error."
    fi
}

# Register the trap for the EXIT signal
trap trap_message_func EXIT

# Exit the script immediately if any command returns a non-zero status
set -e

# ==========================================
# 2. PREREQUISITES CHECK
# ==========================================

echo "🔍 Checking prerequisites..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed."
    exit 1
fi

# Check if GitHub CLI (gh) is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    exit 1
fi

# Check if user is logged into gh
# if ! gh auth status &> /dev/null; then
#     echo "Error: You are not logged into GitHub CLI. Run 'gh auth login' first."
#     exit 1
# fi
# Check if user is logged into gh.
if ! gh auth status &> /dev/null; then
    echo "⚠️  You are not logged into GitHub CLI."
    echo "🔐 Initiating login process now..."

    # Run the interactive login
    # Note if not logged in will launch interactive prompt. It will ask following questions. Here are the recommended answers:
    # ? What account do you want to log into? -> GitHub.com
    # ? What is your preferred protocol for Git operations on this host? -> HTTPS
    # ? Authenticate Git with your GitHub credentials? -> Yes
    # ? How would you like to authenticate GitHub CLI? -> Login with a web browser
    # Goes to website, asks a 6-digit code, paste the code then authenticate with mobile.
    gh auth login

    # Verify login was successful
    if ! gh auth status &> /dev/null; then
        echo "❌ Error: Login failed or was cancelled. Exiting."
        exit 1
    fi
    echo "✅ Login successful!"
fi

# ==========================================
# 3. EXISTING REPO CHECK
# ==========================================

if [ -d ".git" ]; then
    echo "⚠️  Error: A git repository already exists in this directory."
    exit 1
fi

# ==========================================
# 4. Set the REPO NAME. If Left blank, defaults to current folder
# ==========================================

# Get current folder name
CURRENT_DIR_NAME=$(basename "$PWD")

echo ""
echo "📂 Current directory: $PWD"
read -p "❓ Use '$CURRENT_DIR_NAME' as the repo name? [Y/n] " -r RESPONSE

# Default to current directory name
REPO_NAME="$CURRENT_DIR_NAME"

# Check if user said 'n' or 'N'
if [[ "$RESPONSE" =~ ^[Nn]$ ]]; then
    read -p "📝 Enter your desired repository name (if empty defaults to current directory name): " USER_INPUT

    # If user hits enter (empty), fallback to current dir name
    if [ -n "$USER_INPUT" ]; then
        REPO_NAME="$USER_INPUT"
    else
        echo "⚠️  No name entered. Defaulting to '$CURRENT_DIR_NAME'."
    fi
fi

echo ""
echo "🚀 Starting initialization for repo: '$REPO_NAME'..."

# ==========================================
# 5. INITIALIZATION & COMMIT
# ==========================================

echo "🔹 Running 'git init'..."
# Initialize with 'main' as default branch to match modern GitHub standards
git init -b main
# git branch -M main # Ensure branch is named 'main' (for older git versions that default to 'master')

# ADD .gitignore, .gitattributes and README.md file

SHARED_GIT_ASSETS="$HOME/Documents/@MAIN_WORKSPACE/@REPOS/@SHARED_RESOURCES_REPO/git"

# Check if the shared .gitignore exists at the specific location
if [ -f "$SHARED_GIT_ASSETS/.gitignore" ]; then
    echo "📥 Found shared resources. Copying from: $SHARED_GIT_ASSETS"

    # Copy .gitignore
    cp "$SHARED_GIT_ASSETS/.gitignore" .
    echo "   ✅ Copied .gitignore"

    # Check for and copy .gitattributes if it exists
    if [ -f "$SHARED_GIT_ASSETS/.gitattributes" ]; then
        cp "$SHARED_GIT_ASSETS/.gitattributes" .
        echo "   ✅ Copied .gitattributes"
    fi

else
    # Fallback if shared file is missing
    echo "⚠️  ERROR: Shared .gitignore NOT found at: $SHARED_GIT_ASSETS"
    echo "🆕 Creating a simple default .gitignore file instead..."
    echo "# Default .gitignore" > .gitignore
    # {
    #     echo "# Default .gitignore"
    #     echo ".DS_Store"
    #     echo "node_modules/"
    #     echo ".env"
    # } > .gitignore
fi

# Check for .gitignore. If it does not exist create it (Important Best Practice)
# if [ ! -f ".gitignore" ]; then
#     echo "⚠️  WARNING: No .gitignore file found."
#     echo "🆕 Creating a default .gitignore file..."
#     echo "# Default .gitignore" > .gitignore
#     # read -p "   Press ENTER to continue anyway, or CTRL+C to abort and create one."
# fi

# Create a README.md file if it doesn't exist
if [ ! -f "README.md" ]; then
    echo "# $REPO_NAME" >> README.md
fi

# STAGE ALL FILES
echo "🔹 Staging all files..."
git add .

# COMMIT CHANGES
echo "🔹 Committing files..."
# Check if there are actually files to commit to avoid empty commit error
# if git diff --cached --quiet; then
#     echo "⚠️  No files to commit. Creating an empty .gitkeep file."
#     touch .gitkeep
#     git add .gitkeep
# fi

git commit -m "Initial Commit"

# ==========================================
# 6. GITHUB CREATION & PUSH
# ==========================================

echo "🔹 Creating private repository on GitHub and adding remote..."

# gh repo create explanation:
# --private: Sets visibility
# --source=. : Uses the current directory as the source
# --remote=origin : Adds the 'git remote add origin' link automatically
# --push : Pushes the commits immediately
gh repo create "$REPO_NAME" --private --source=. --remote=origin --push

# Otherwise if we create MANUALLY REMOTE REPO we typically create REMOTE REPO from Github website Then run commands:
# git remote add origin https://github.com/<YOUR_USERNAME>/$REPO_NAME.git
# git push -u origin main

echo "✅ Remote 'origin' added and code pushed."

#=================================================================
# OLD DELETE BELOW
#=================================================================

# initialize-new-git-repo() {
#     echo "🚀 Initializing a new Git repository in the current directory: $(pwd)"
#     # git init
#     # echo "✅ Git repository initialized successfully!"
# }

# # "$@" is a special variable that represents all the command-line arguments passed to our script. The double quotes are crucial because they ensure each argument is treated as a separate entity, even if it contains spaces.
# initialize-new-git-repo "$@"
