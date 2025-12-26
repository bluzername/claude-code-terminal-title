#!/bin/bash
# Setup script for bash users to fix terminal title persistence
# Supports macOS Terminal.app, Warp terminal, and other terminals
# Uses PROMPT_COMMAND to preserve Claude titles across /clear

set -e

BASHRC="${HOME}/.bashrc"
BASH_PROFILE="${HOME}/.bash_profile"

echo "========================================================================"
echo "  Terminal Title Skill - Bash Setup                                    "
echo "========================================================================"
echo ""

# Determine which file to use
TARGET_FILE="$BASHRC"
if [[ ! -f "$BASHRC" ]] && [[ -f "$BASH_PROFILE" ]]; then
    TARGET_FILE="$BASH_PROFILE"
fi

BACKUP="${TARGET_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if already configured
if grep -q "CLAUDE_TERMINAL_TITLE_SETUP" "$TARGET_FILE" 2>/dev/null; then
    echo "Your $TARGET_FILE is already configured for terminal-title skill"
    echo ""
    exit 0
fi

echo "This script will add configuration to your $TARGET_FILE to make"
echo "terminal titles persist correctly across /clear commands."
echo "Supports: macOS Terminal.app, Warp terminal, and others"
echo ""
echo "A backup will be created at: $BACKUP"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Backup existing file
if [ -f "$TARGET_FILE" ]; then
    cp "$TARGET_FILE" "$BACKUP"
    echo "Backup created: $BACKUP"
fi

# Add configuration
cat >> "$TARGET_FILE" << 'EOF'

# ============================================================================
# CLAUDE_TERMINAL_TITLE_SETUP - Terminal Title Skill Configuration
# Added by terminal-title skill setup script
# Supports: macOS Terminal.app, Warp terminal, and other terminals
# ============================================================================

__claude_title_precmd() {
    local title_file="${HOME}/.claude/terminal_title"

    # WARP TERMINAL: Always re-send title on every prompt
    # Warp's block model resets title after /clear, so force it every time
    if [[ "$TERM_PROGRAM" == "WarpTerminal" && -n "$CLAUDE_TITLE_CLAIMED" ]]; then
        if [[ -f "$title_file" ]]; then
            local claude_title
            claude_title=$(cat "$title_file" 2>/dev/null)
            if [[ -n "$claude_title" ]]; then
                printf '\033]0;%s\007' "$claude_title"
                return
            fi
        fi
    fi

    if [[ -f "$title_file" ]]; then
        local claude_title
        claude_title=$(cat "$title_file" 2>/dev/null)

        if [[ -n "$claude_title" ]]; then
            # Check if this shell session has already claimed a title
            if [[ -n "$CLAUDE_TITLE_CLAIMED" ]]; then
                # This session has claimed a title - use it indefinitely
                printf '\033]0;%s\007' "$claude_title"
                return
            else
                # New shell session - check if title is fresh (< 5 minutes)
                local current_time file_time age
                current_time=$(date +%s)

                # Detect OS and use appropriate stat command
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    file_time=$(stat -f %m "$title_file" 2>/dev/null)
                else
                    file_time=$(stat -c %Y "$title_file" 2>/dev/null)
                fi

                # If we can't get file time, assume it's stale and skip
                if [[ -z "$file_time" ]] || ! [[ "$file_time" =~ ^[0-9]+$ ]]; then
                    # Fallback: show current directory
                    printf '\033]0;%s\007' "${PWD/#$HOME/\~}"
                    return
                fi

                age=$((current_time - file_time))

                if [[ $age -lt 300 ]]; then
                    # Title is fresh - claim it for this shell session
                    export CLAUDE_TITLE_CLAIMED=1
                    printf '\033]0;%s\007' "$claude_title"
                    return
                fi
            fi
        fi
    fi

    # Fallback: show current directory
    printf '\033]0;%s\007' "${PWD/#$HOME/\~}"
}

# Add to PROMPT_COMMAND if not already present
if [[ "$PROMPT_COMMAND" != *"__claude_title_precmd"* ]]; then
    PROMPT_COMMAND="__claude_title_precmd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# ============================================================================
EOF

echo "Configuration added to $TARGET_FILE"
echo ""

# Configure Terminal.app to disable title suffixes (macOS only)
if [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
    echo "Configuring Terminal.app title settings..."
    PLIST="$HOME/Library/Preferences/com.apple.Terminal.plist"

    # Try to detect active profile from Terminal preferences
    PROFILE=$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || echo "Basic")

    # Allow override via environment variable
    PROFILE="${TERMINAL_PROFILE:-${PROFILE}}"

    /usr/libexec/PlistBuddy -c "Set ':Window Settings:$PROFILE:ShowActiveProcessInTitle' false" "$PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add ':Window Settings:$PROFILE:ShowActiveProcessInTitle' bool false" "$PLIST" 2>/dev/null

    /usr/libexec/PlistBuddy -c "Set ':Window Settings:$PROFILE:ShowDimensionsInTitle' false" "$PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add ':Window Settings:$PROFILE:ShowDimensionsInTitle' bool false" "$PLIST" 2>/dev/null

    /usr/libexec/PlistBuddy -c "Set ':Window Settings:$PROFILE:ShowRepresentedURLInTitle' false" "$PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add ':Window Settings:$PROFILE:ShowRepresentedURLInTitle' bool false" "$PLIST" 2>/dev/null

    echo "Terminal.app title settings configured"
    echo ""
fi

echo "========================================================================"
echo "  Setup Complete!                                                       "
echo "========================================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Reload your shell configuration:"
echo "   source $TARGET_FILE"
echo ""
echo "2. Test the title:"
echo "   bash ~/.claude/skills/terminal-title/scripts/set_title.sh 'Test: Clean Title'"
echo ""
echo "3. Your terminal title should now be JUST: 'Test: Clean Title'"
echo "   (no prefixes or suffixes!)"
echo ""
echo "4. Try with Claude Code in a NEW terminal"
echo ""
