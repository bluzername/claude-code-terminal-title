#!/bin/bash
# Claude Code UserPromptSubmit hook: set the terminal title from the prompt.
#
# Deterministic alternative to the model-invoked skill. Claude Code pipes the
# hook payload as JSON on stdin; the relevant field is "prompt".
#
# Install (in ~/.claude/settings.json):
#   {"hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command",
#     "command": "bash ~/.claude/skills/terminal-title/hooks/set-title-hook.sh"}]}]}}
#
# Rules this script follows:
#   - always exits 0, so a title failure can never block a prompt
#   - never writes to stdout (stdout of this hook becomes model context)
#   - skips slash commands and empty prompts
#   - keeps the first line of the prompt, collapses whitespace, caps at 40 chars

MAX_TITLE_LENGTH=40
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SET_TITLE="${SCRIPT_DIR}/../scripts/set_title.sh"

extract_prompt() {
    local payload="$1"
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
prompt = data.get("prompt", "") if isinstance(data, dict) else ""
if isinstance(prompt, str):
    sys.stdout.write(prompt)
' 2>/dev/null
        return
    fi
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$payload" | jq -r 'if type == "object" then (.prompt // "") else "" end' 2>/dev/null
        return
    fi
    # Conservative fallback: grab the string value of the "prompt" key.
    printf '%s' "$payload" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

make_title() {
    local prompt="$1"
    printf '%s' "$prompt" \
        | head -n 1 \
        | tr -d '\000-\037' \
        | tr -s '[:space:]' ' ' \
        | sed -e 's/^ //' \
        | head -c "$MAX_TITLE_LENGTH" \
        | sed -e 's/ *$//'
}

main() {
    local payload prompt title
    payload=$(cat 2>/dev/null || true)
    [ -n "$payload" ] || return 0

    prompt=$(extract_prompt "$payload")
    [ -n "$prompt" ] || return 0

    case "$prompt" in
        /*) return 0 ;;
    esac

    title=$(make_title "$prompt")
    [ -n "$title" ] || return 0

    if [ -f "$SET_TITLE" ]; then
        CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" "$title" >/dev/null 2>&1 || true
    fi
    return 0
}

main
exit 0
