#!/bin/bash
# Set terminal window title
# Usage: ./set_title.sh "Your Title Here"
#
# Optional: Set CLAUDE_TITLE_PREFIX environment variable for custom prefix
# Example: export CLAUDE_TITLE_PREFIX="🤖 Claude"
#          Results in: "🤖 Claude | Your Title"

# Exit silently if no title provided (fail-safe behavior)
if [ -z "$1" ]; then
    exit 0
fi

# Validate and sanitize input
# Remove control characters (0x00-0x1F) and limit length to 80 characters
TITLE=$(echo "$1" | tr -d '\000-\037' | head -c 80)

# Ensure title is not empty after sanitization
if [ -z "$TITLE" ]; then
    exit 0
fi

# Build the final title with optional prefix
if [ -n "$CLAUDE_TITLE_PREFIX" ]; then
    # Sanitize prefix as well
    PREFIX=$(echo "$CLAUDE_TITLE_PREFIX" | tr -d '\000-\037' | head -c 40)
    if [ -n "$PREFIX" ]; then
        FINAL_TITLE="${PREFIX} | ${TITLE}"
    else
        FINAL_TITLE="${TITLE}"
    fi
else
    FINAL_TITLE="${TITLE}"
fi

# Store the title in a file that shell hooks can read
# This allows precmd hooks (like update_terminal_cwd) to preserve the title
# Use atomic write to prevent race conditions
TITLE_FILE="${HOME}/.claude/terminal_title"
mkdir -p "${HOME}/.claude"

# Atomic write using temp file + rename
TEMP_FILE="${TITLE_FILE}.tmp.$$"
echo "$FINAL_TITLE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$TITLE_FILE" 2>/dev/null || rm -f "$TEMP_FILE"

# Set the terminal title using ANSI escape sequences
# Detect terminal type and set title accordingly
case "$TERM" in
    xterm*|rxvt*|screen*|tmux*)
        # Standard xterm-compatible terminals
        printf '\033]0;%s\007' "$FINAL_TITLE"
        ;;
    *)
        # Fallback: try anyway, suppress errors
        # This works for iTerm2, Alacritty, and most modern terminals
        printf '\033]0;%s\007' "$FINAL_TITLE" 2>/dev/null
        ;;
esac
