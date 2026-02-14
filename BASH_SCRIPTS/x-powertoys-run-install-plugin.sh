#!/usr/bin/env bash

#========================================================
# Automatically install latest PowerToys Run plugin
#========================================================

# Define plugin destination path using LOCALAPPDATA
PLUGIN_DIR="$LOCALAPPDATA/Microsoft/PowerToys/PowerToys Run/Plugins"

#-------------------------------------------------------------
# Step 0: (Optional) Download plugin from GitHub release
# NOTE: THIS REQUIRES gh CLI (from github)
# It also requires you to be logged in to GitHub CLI using `gh auth login`
#-------------------------------------------------------------
# If a GitHub URL is provided as first arg, try to pull latest x64.zip release

#--------------------------------------------------------
# Step 0: (Optional) Download plugin from GitHub release
#--------------------------------------------------------

echo
echo "🌐 Optional (CAN LEAVE BLANK): Enter GitHub repository URL to auto-download the latest x64 plugin release."
echo "   Format: https://github.com/<owner>/<repo>"
echo "   Example 1: https://github.com/TBM13/BrowserSearch"
echo "   Example 2: https://github.com/CCcat8059/FastWeb"

echo "   ⚠️  IF LEFT BLANK, you'll be prompted to manually select a .zip file from your DOWNLOADS folder.⚠️"
echo
echo "⚠️  Requires GitHub CLI (gh) to be installed and authenticated (One time only, if login required will prompt you):"
echo "   Run: gh auth login"
echo

read -rp "🔗 GitHub Repo URL (optional): " GITHUB_URL

if [[ -n "$GITHUB_URL" && "$GITHUB_URL" =~ github\.com/([^/]+)/([^/]+) ]]; then
    REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    echo "🔍 Checking GitHub repo: $REPO"

    if ! command -v gh &> /dev/null; then
        echo "❌ GitHub CLI ('gh') is not installed. Please install it from https://cli.github.com/"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        echo "❌ GitHub CLI is not authenticated. Run: gh auth login"
        exit 1
    fi

    if ! gh repo view "$REPO" &> /dev/null; then
        echo "❌ Invalid GitHub repository: $REPO"
        exit 1
    fi

    echo "📦 Checking latest release for $REPO..."

    if ! gh release view -R "$REPO" &> /dev/null; then
        echo "❌ No releases found for $REPO"
        exit 1
    fi

    echo "⬇️  Downloading latest *x64.zip to Downloads folder..."
    # shellcheck disable=SC2164
    cd "$USERPROFILE/Downloads"

    if ! gh release download -R "$REPO" --pattern "*x64.zip" --clobber; then
        echo "❌ Failed to download x64.zip from the latest release."
        exit 1
    fi

    echo "✅ Download complete. Continuing with plugin installation..."

    echo -e "===============================\n" # Adds a separator and 2 new lines for better readability
fi

#--------------------------------------------------------
# Step 1: Find latest zip file in Downloads using fd + fzf
#--------------------------------------------------------

# Define Downloads folder
DOWNLOADS="$USERPROFILE/Downloads"

echo "🔍 Select plugin .zip file (sorted by most recent):"

# 1. Find all .zip files in Downloads folder -> fd --extension zip . "$DOWNLOADS" --type f
# 2. Get modified time and filename for sorting -> --exec stat -c '%Y %n' {} \;
# 3. Sort by timestamp, newest first -> sort -nr
# 4. Remove timestamp, keep file path only -> cut -d' ' -f2-
# 5. Use fzf to select a zip file interactively -> fzf --reverse --height=20 --prompt="ZIP File > "
ZIP_FILE=$(
    fd --extension zip . "$DOWNLOADS" --type f \
        --exec stat -c '%Y %n' {} \; 2> /dev/null \
        | sort -nr \
        | cut -d' ' -f2- \
        | fzf --reverse --height=20 --prompt="ZIP File > "
)

if [[ -z "$ZIP_FILE" ]]; then
    echo "❌ No zip file selected. Exiting."
    exit 1
fi

echo "📦 Selected zip file: $ZIP_FILE"

#--------------------------------------------------------
# Step 2: Unzip selected file
#--------------------------------------------------------
# Create a temp folder for extraction
TEMP_DIR="$(mktemp -d)"
echo "📂 Extracting to temp folder: $TEMP_DIR"

if command -v 7z &> /dev/null; then
    7z x "$ZIP_FILE" -o"$TEMP_DIR" -y
elif command -v unzip &> /dev/null; then
    unzip -q "$ZIP_FILE" -d "$TEMP_DIR"
else
    echo "❌ Neither 7z nor unzip is installed. Please install one."
    exit 1
fi

#--------------------------------------------------------
# Step 3: Close PowerToys
#--------------------------------------------------------
echo "🛑 Closing PowerToys..."
taskkill //IM PowerToys.exe //F &> /dev/null

#--------------------------------------------------------
# Step 4: Move unzipped folder to Plugins directory
#--------------------------------------------------------

# Create Plugins directory if not exists
mkdir -p "$PLUGIN_DIR"

# Detect plugin root folder (assume first folder in TEMP_DIR)
PLUGIN_SRC=$(fd --type d . "$TEMP_DIR" --max-depth 1 | head -n 1)

if [[ -z "$PLUGIN_SRC" ]]; then
    echo "❌ Failed to find plugin folder inside archive."
    exit 1
fi

# Extract plugin folder name
PLUGIN_NAME=$(basename "$PLUGIN_SRC")

# Move to Plugins directory, overwrite if exists
# DEST="$PLUGIN_DIR/$PLUGIN_NAME"
DEST=$(cygpath -w "$PLUGIN_DIR\\$PLUGIN_NAME") # Convert to Windows path format with BACKWARD SLASHES (so we can easily copy paste the path from the output to FILE EXPLORER). Otherwise it was printing $PLUGIN_DIR with BACKSLASHES and then printing $PLUGIN_NAME with FORWARD SLASHES, which was causing issues.

# OUTPUT OF DEST: C:\Users\Syed\AppData\Local\Microsoft\PowerToys\PowerToys Run\Plugins\Weather

rm -rf "$DEST"
mv "$PLUGIN_SRC" "$DEST"

echo "✅ Plugin moved to: $DEST"

#--------------------------------------------------------
# Step 5: Restart PowerToys with fallback logic
#--------------------------------------------------------

# Define known shortcut and fallback executable
# Shortcut Windows Start Menu Path: C:\Users\Syed\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\PowerToys.lnk
POWERTOYS_SHORTCUT="$APPDATA/Microsoft/Windows/Start Menu/Programs/PowerToys.lnk"
# PowerToys Executable Path (Target path the Shortcut Points to): C:\Users\Syed\AppData\Local\PowerToys\WinUI3Apps\PowerToys.Settings.exe
POWERTOYS_EXECUTABLE="$LOCALAPPDATA/PowerToys/WinUI3Apps/PowerToys.Settings.exe"

SLEEP_TIME=5 # Seconds to wait before restarting PowerToys
echo "⏳ Waiting $SLEEP_TIME seconds before restarting PowerToys..."
echo "   This gives time to ensure clean shutdown and proper plugin registration..."
sleep $SLEEP_TIME

# Check if PowerToys is already running
if tasklist | grep -qi "PowerToys.Settings.exe"; then
    echo "ℹ️ PowerToys is already running. Skipping restart."
else
    echo "🚀 Attempting to restart PowerToys..."

    if [[ -f "$POWERTOYS_SHORTCUT" ]]; then
        echo "🔁 Launching via Start Menu shortcut..."
        start "" "$POWERTOYS_SHORTCUT"
    elif [[ -f "$POWERTOYS_EXECUTABLE" ]]; then
        echo "🔁 Shortcut not found. Launching directly from executable..."
        start "" "$POWERTOYS_EXECUTABLE"
    else
        echo "❌ Could not restart PowerToys."
        echo "   Neither shortcut nor executable found:"
        echo "   Shortcut: $POWERTOYS_SHORTCUT"
        echo "   Executable: $POWERTOYS_EXECUTABLE"
    fi
fi

#------------------------------------------------------------
# Step 6: Open the PowerToys plugin folder in File Explorer
#------------------------------------------------------------

POWERTOYS_PLUGIN_DEST_PATH="$LOCALAPPDATA/Microsoft/PowerToys/PowerToys Run/Plugins"
# WINDOWS_PLUGIN_DEST_PATH="$(cygpath -w "$LOCALAPPDATA/Microsoft/PowerToys/PowerToys Run/Plugins")"
WINDOWS_PLUGIN_DEST_PATH=$(cygpath -w "$POWERTOYS_PLUGIN_DEST_PATH")

echo "📂 Opening PowerToys plugin directory in File Explorer..."
echo "🔍 PowerToys Plugin Directory (Windows Path): $WINDOWS_PLUGIN_DEST_PATH"
explorer "$WINDOWS_PLUGIN_DEST_PATH"

#--------------------------------------------------------
# Done
#--------------------------------------------------------
echo "🎉 PowerToys plugin installed successfully!"
