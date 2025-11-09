#!/bin/zsh
# Setup script for zsh users to fix terminal title persistence
# This overrides macOS Terminal.app's update_terminal_cwd function

set -e

ZSHRC="${HOME}/.zshrc"
BACKUP="${HOME}/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Terminal Title Skill - Zsh Setup                           ║"
echo "╔══════════════════════════════════════════════════════════════╗"
echo ""

# Check if already configured
if grep -q "CLAUDE_TERMINAL_TITLE_SETUP" "$ZSHRC" 2>/dev/null; then
    echo "✓ Your ~/.zshrc is already configured for terminal-title skill"
    echo ""
    exit 0
fi

echo "This script will add configuration to your ~/.zshrc to make"
echo "terminal titles work correctly with macOS Terminal.app"
echo ""
echo "A backup will be created at: $BACKUP"
echo ""
read -q "REPLY?Continue? (y/n) "
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Backup existing .zshrc
if [ -f "$ZSHRC" ]; then
    cp "$ZSHRC" "$BACKUP"
    echo "✓ Backup created: $BACKUP"
fi

# Add configuration to .zshrc
cat >> "$ZSHRC" << 'EOF'

# ============================================================================
# CLAUDE_TERMINAL_TITLE_SETUP - Terminal Title Skill Configuration
# Added by terminal-title skill setup script
# ============================================================================

# Override macOS Terminal.app's update_terminal_cwd to preserve Claude titles
update_terminal_cwd() {
    local title_file="${HOME}/.claude/terminal_title"

    if [ -f "$title_file" ]; then
        local claude_title=$(cat "$title_file" 2>/dev/null)

        if [ -n "$claude_title" ]; then
            # Check if this shell session has already claimed a title
            if [ -n "$CLAUDE_TITLE_CLAIMED" ]; then
                # This session has claimed a title - use it indefinitely
                printf '\033]0;%s\007' "$claude_title"
                return
            else
                # New shell session - check if title is fresh (< 5 minutes)
                local current_time=$(date +%s)
                local file_time
                
                # Detect OS and use appropriate stat command
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    file_time=$(stat -f %m "$title_file" 2>/dev/null)
                elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
                    file_time=$(stat -c %Y "$title_file" 2>/dev/null)
                else
                    # Fallback: use find for modification time
                    file_time=$(find "$title_file" -printf '%T@' 2>/dev/null | cut -d. -f1)
                    if [[ -z "$file_time" ]]; then
                        # Last resort: try ls -T (BSD) or ls --time-style (GNU)
                        file_time=$(ls -T "$title_file" 2>/dev/null | awk '{print $6" "$7" "$8}' | xargs -I {} date -j -f "%b %d %H:%M:%S" "{}" +%s 2>/dev/null || \
                                   ls -l --time-style=+%s "$title_file" 2>/dev/null | awk '{print $6}' 2>/dev/null)
                    fi
                fi
                
                # If we can't get file time, assume it's stale and skip
                if [[ -z "$file_time" ]] || ! [[ "$file_time" =~ ^[0-9]+$ ]]; then
                    # Fallback: show current directory
                    printf '\033]0;%s\007' "${PWD/#$HOME/~}"
                    return
                fi
                
                local age=$((current_time - file_time))

                if [ $age -lt 300 ]; then
                    # Title is fresh - claim it for this shell session
                    export CLAUDE_TITLE_CLAIMED=1
                    printf '\033]0;%s\007' "$claude_title"
                    return
                fi
            fi
        fi
    fi

    # Fallback: show current directory
    printf '\033]0;%s\007' "${PWD/#$HOME/~}"
}

# Make sure our override is called
if [[ ! "${precmd_functions[(r)update_terminal_cwd]}" == "update_terminal_cwd" ]]; then
    precmd_functions+=(update_terminal_cwd)
fi

# ============================================================================
EOF

echo "✓ Configuration added to ~/.zshrc"
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

    echo "✓ Terminal.app title settings configured"
    echo ""
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Setup Complete!                                             ║"
echo "╔══════════════════════════════════════════════════════════════╗"
echo ""
echo "Next steps:"
echo ""
echo "1. Reload your shell configuration:"
echo "   source ~/.zshrc"
echo ""
echo "2. Test the title:"
echo "   bash ~/.claude/skills/terminal-title/scripts/set_title.sh 'Test: Clean Title'"
echo ""
echo "3. Your terminal title should now be JUST: 'Test: Clean Title'"
echo "   (no prefixes or suffixes!)"
echo ""
echo "4. Try with Claude Code in a NEW terminal"
echo ""
