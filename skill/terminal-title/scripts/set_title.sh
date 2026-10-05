#!/bin/bash
# Set the terminal window title with a folder name prefix.
#
# Usage: set_title.sh "Your Title Here"
#
# Resulting title formats:
#   "<folder> | Your Title"
#   "<prefix> | <folder> | Your Title"   when CLAUDE_TITLE_PREFIX is set
#
# Behaviour:
#   - exits 0 silently when no title is given (fail-safe)
#   - strips control characters, caps the title at 80 chars and the prefix at 40
#   - writes the final title to ~/.claude/terminal_title atomically so shell
#     precmd hooks (see setup-zsh.sh) can re-apply it on every prompt
#   - emits the OSC 0 escape sequence to /dev/tty when possible, otherwise to
#     stdout. Set CLAUDE_TITLE_OUTPUT=tty to never write to stdout (used by the
#     UserPromptSubmit hook, whose stdout is captured by Claude Code).

if [ -z "${1:-}" ]; then
    exit 0
fi

sanitize() {
    printf '%s' "$1" | tr -d '\000-\037' | head -c "$2"
}

TITLE=$(sanitize "$1" 80)
if [ -z "$TITLE" ]; then
    exit 0
fi

FOLDER_NAME=$(basename "$PWD")
PREFIX=""
if [ -n "${CLAUDE_TITLE_PREFIX:-}" ]; then
    PREFIX=$(sanitize "$CLAUDE_TITLE_PREFIX" 40)
fi

if [ -n "$PREFIX" ]; then
    FINAL_TITLE="${PREFIX} | ${FOLDER_NAME} | ${TITLE}"
else
    FINAL_TITLE="${FOLDER_NAME} | ${TITLE}"
fi

# Persist the title for shell hooks (atomic write: temp file + rename).
TITLE_FILE="${HOME}/.claude/terminal_title"
mkdir -p "${HOME}/.claude"
TEMP_FILE="${TITLE_FILE}.tmp.$$"
if printf '%s\n' "$FINAL_TITLE" > "$TEMP_FILE" 2>/dev/null; then
    mv "$TEMP_FILE" "$TITLE_FILE" 2>/dev/null || rm -f "$TEMP_FILE"
fi

emit_title() {
    local sequence
    sequence=$(printf '\033]0;%s\007' "$FINAL_TITLE")

    if [ "${CLAUDE_TITLE_OUTPUT:-auto}" = "tty" ]; then
        # Hook mode: only the controlling terminal, never stdout.
        { printf '%s' "$sequence" > /dev/tty; } 2>/dev/null || true
        return 0
    fi

    if { printf '%s' "$sequence" > /dev/tty; } 2>/dev/null; then
        return 0
    fi

    # No controlling terminal (CI, some tool sandboxes): fall back to stdout.
    printf '%s' "$sequence"
}

emit_title

# When running inside Herdr, also rename the pane and publish title metadata.
# Official integrations only report lifecycle state; without this, the Herdr
# sidebar stays as bare "claude" while only the outer terminal title updates.
# Fail open: never break title setting if herdr is missing or errors.
# Requires Herdr >= 0.7.4 for `pane report-metadata --token`; older builds
# fail that call harmlessly (swallowed below). See README "Herdr" section.
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

exit 0
