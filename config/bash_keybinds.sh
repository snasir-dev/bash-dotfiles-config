#!/bin/bash

#====================================================================
# CUSTOM KEYBINDS FOR BASH SHELL SCRIPT. OVERRIDE EXISTING BEHAVIOR #
#====================================================================

# Copy Current Terminal Prompt Source Reference: https://askubuntu.com/questions/413436/copy-current-terminal-prompt-to-clipboard

copy_line_to_win_clipboard() {
    printf %s "$READLINE_LINE" | clip.exe
}

# Bind CTRL+A to copy the current line to Windows clipboard. It DOES NOT clear the line.
bind -x '"\C-a": copy_line_to_win_clipboard' # Bind to Ctrl+A
# bind -x '"\C-y": copy_line_to_win_clipboard'   # Bind to Ctrl+Y
# bind -x '"\ec": copy_line_to_win_clipboard'  # Bind to ALT+C

copy_and_clear_line() {
    # Copy current input line to clipboard
    printf %s "$READLINE_LINE" | clip.exe

    # Clear the current line
    READLINE_LINE=""
    READLINE_POINT=0
}

# Bind Alt+U to copy the current line to Windows clipboard AND clear the line
bind -x '"\eu": copy_and_clear_line' # Bind to Alt+U

# Bind Alt+G to open the Yazi bash function/script selector and INSERT the
# selection at the cursor in the current line (instead of running it) -- same
# idea as fzf's own Ctrl+T widget. Keep typing/editing, then press Enter yourself.
# See BASH_SCRIPTS/yazi-selector/ in this repo, and x-script-selector-yazi-insert()
# in aliases/aliases.sh.
# NOTE: this used to be bound to Ctrl+Alt+X, which does nothing in VS Code's
# integrated terminal -- VS Code's Electron layer treats Ctrl+Alt as AltGr, and
# xterm.js (VS Code's terminal) deliberately never sends Ctrl+Alt+<letter> to the
# shell at all (confirmed by reading VS Code's own source, not a guess). Alt+G
# (plain Alt, no Ctrl) avoids that code path entirely and was confirmed free of
# every hotkey tool on this machine (whkd, PowerToys, espanso, and others).
bind -x '"\eg": x-script-selector-yazi-insert' # Bind to Alt+G

#=====================================================================
