#!/bin/bash
# Set terminal window title
# Usage: ./set_title.sh "Your Title Here"
#
# The script automatically prefixes the title with the current directory name
# (usually the repo/project name) for easy identification across multiple terminals.
#
# Optional: Set CLAUDE_TITLE_PREFIX environment variable for additional custom prefix
# Example: export CLAUDE_TITLE_PREFIX="🤖"
#          Results in: "🤖 my-project | Your Title"

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

# Get the current directory name (usually the repo/project name)
DIR_NAME=$(basename "$PWD")

# Build the final title with directory prefix and optional custom prefix
if [ -n "$CLAUDE_TITLE_PREFIX" ]; then
    # Sanitize prefix as well
    PREFIX=$(echo "$CLAUDE_TITLE_PREFIX" | tr -d '\000-\037' | head -c 20)
    if [ -n "$PREFIX" ]; then
        FINAL_TITLE="${PREFIX} ${DIR_NAME} | ${TITLE}"
    else
        FINAL_TITLE="${DIR_NAME} | ${TITLE}"
    fi
else
    FINAL_TITLE="${DIR_NAME} | ${TITLE}"
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

# When running inside Herdr, also rename the pane and publish title metadata.
# Official integrations only report lifecycle state; without this, the Herdr
# sidebar stays as bare "claude" while only the outer terminal title updates.
# Fail open: never break title setting if herdr is missing or errors.
if [ "${HERDR_ENV:-}" = "1" ] && [ -n "${HERDR_PANE_ID:-}" ]; then
    HERDR_BIN="${HERDR_BIN_PATH:-herdr}"
    # Prefer the clean task title for pane labels; fall back to final title.
    PANE_TITLE="$TITLE"
    if [ -z "$PANE_TITLE" ]; then
        PANE_TITLE="$FINAL_TITLE"
    fi
    PANE_TITLE=$(printf '%s' "$PANE_TITLE" | head -c 60)
    if [ -n "$PANE_TITLE" ] && command -v "$HERDR_BIN" >/dev/null 2>&1; then
        "$HERDR_BIN" pane rename "$HERDR_PANE_ID" "$PANE_TITLE" >/dev/null 2>&1 || true
        "$HERDR_BIN" pane report-metadata "$HERDR_PANE_ID" \
            --source "plugin:claude-code-terminal-title" \
            --title "$PANE_TITLE" \
            --display-agent "$PANE_TITLE" \
            --token "task=$PANE_TITLE" \
            --ttl-ms 86400000 >/dev/null 2>&1 || true
    fi
fi
