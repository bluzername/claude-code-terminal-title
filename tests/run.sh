#!/bin/bash
# Shell test suite for set_title.sh and set-title-hook.sh.
# Runs with a throwaway HOME so it never touches the real ~/.claude.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SET_TITLE="${REPO_DIR}/skill/terminal-title/scripts/set_title.sh"
HOOK="${REPO_DIR}/skill/terminal-title/hooks/set-title-hook.sh"

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="${SANDBOX}/home"
mkdir -p "$HOME" "${SANDBOX}/my-project"
cd "${SANDBOX}/my-project"

# Neutralize ambient Herdr env so each test controls it explicitly; otherwise
# running inside a Herdr pane (HERDR_ENV=1 exported) would leak into every case.
unset HERDR_ENV HERDR_PANE_ID HERDR_BIN_PATH

TITLE_FILE="${HOME}/.claude/terminal_title"
PASS=0
FAIL=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
        echo "ok   - $name"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL - $name"
        echo "       expected: $(printf '%q' "$expected")"
        echo "       actual:   $(printf '%q' "$actual")"
    fi
}

stored_title() {
    cat "$TITLE_FILE" 2>/dev/null || true
}

# 1. No argument: exit 0, no file written, no stdout.
out=$(bash "$SET_TITLE"); rc=$?
check "no-arg exits 0" "0" "$rc"
check "no-arg prints nothing" "" "$out"
check "no-arg writes no file" "missing" "$([ -f "$TITLE_FILE" ] && echo present || echo missing)"

# 2. Basic title gets the folder prefix.
CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" "Build: Dashboard UI"
check "folder prefix" "my-project | Build: Dashboard UI" "$(stored_title)"

# 3. Custom prefix format.
CLAUDE_TITLE_PREFIX="Claude" CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" "Fix: Login Bug"
check "custom prefix" "Claude | my-project | Fix: Login Bug" "$(stored_title)"

# 4. Control characters are stripped.
CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" "$(printf 'Debug:\tAuth\033[31m Flow')"
check "control chars stripped" "my-project | Debug:Auth[31m Flow" "$(stored_title)"

# 5. 80-character cap on the task title.
long=$(printf 'a%.0s' $(seq 1 120))
CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" "$long"
folder=$(basename "$PWD")
check "80-char cap" "$((${#folder} + 3 + 80))" "$(stored_title | tr -d '\n' | wc -c | tr -d ' ')"

# 6. Whitespace-only title is ignored after sanitisation is not required, but
#    an empty string must be a no-op.
CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" "Test: Keep Me"
CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" ""
check "empty title is a no-op" "my-project | Test: Keep Me" "$(stored_title)"

# 7. Without a tty and in auto mode, the OSC sequence goes to stdout.
out=$(bash "$SET_TITLE" "Stdout Fallback" 2>/dev/null </dev/null || true)
if [ -c /dev/tty ] && { : > /dev/tty; } 2>/dev/null; then
    check "auto mode with a tty prints nothing to stdout" "" "$out"
else
    check "auto mode without a tty prints OSC to stdout" "$(printf '\033]0;my-project | Stdout Fallback\007')" "$out"
fi

# 8. Hook: JSON payload sets the title and prints nothing to stdout.
payload='{"session_id":"abc","cwd":"/tmp","hook_event_name":"UserPromptSubmit","prompt":"Refactor the payment module\nand add tests"}'
out=$(printf '%s' "$payload" | bash "$HOOK"); rc=$?
check "hook exits 0" "0" "$rc"
check "hook prints nothing" "" "$out"
check "hook sets title from first line" "my-project | Refactor the payment module" "$(stored_title)"

# 9. Hook: long prompt is capped at 40 chars and whitespace collapsed.
payload='{"prompt":"   Investigate    why the   nightly    build fails on the arm64 runners after upgrade   "}'
printf '%s' "$payload" | bash "$HOOK"
check "hook caps at 40 chars" "my-project | Investigate why the nightly build fails" "$(stored_title)"

# 10. Hook: slash commands are ignored.
CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" "Before Slash"
printf '%s' '{"prompt":"/compact"}' | bash "$HOOK"
check "hook ignores slash commands" "my-project | Before Slash" "$(stored_title)"

# 11. Hook: invalid JSON exits 0 and changes nothing.
out=$(printf 'not json at all' | bash "$HOOK"); rc=$?
check "hook invalid JSON exits 0" "0" "$rc"
check "hook invalid JSON prints nothing" "" "$out"
check "hook invalid JSON leaves title" "my-project | Before Slash" "$(stored_title)"

# 12. Hook: empty stdin exits 0.
out=$(bash "$HOOK" </dev/null); rc=$?
check "hook empty stdin exits 0" "0" "$rc"

# 13. Herdr: under HERDR_ENV=1 with a stub `herdr` on PATH (via HERDR_BIN_PATH),
#     the pane rename and report-metadata calls fire with the task title.
HERDR_LOG="${SANDBOX}/herdr.log"
HERDR_STUB="${SANDBOX}/herdr"
cat > "$HERDR_STUB" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$HERDR_LOG"
exit 0
EOF
chmod +x "$HERDR_STUB"

rm -f "$HERDR_LOG"
HERDR_ENV=1 HERDR_PANE_ID="pane-7" HERDR_BIN_PATH="$HERDR_STUB" \
    CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" "Ship: Herdr Pane"
check "herdr title still stored" "my-project | Ship: Herdr Pane" "$(stored_title)"
check "herdr pane rename invoked" \
    "pane rename pane-7 Ship: Herdr Pane" \
    "$(grep '^pane rename ' "$HERDR_LOG" 2>/dev/null || true)"
check "herdr report-metadata invoked" "1" \
    "$(grep -c '^pane report-metadata pane-7 .*--token task=Ship: Herdr Pane' "$HERDR_LOG" 2>/dev/null | tr -d ' ')"

# 14. Herdr: without HERDR_ENV=1 the stub is never called (no-op path).
rm -f "$HERDR_LOG"
HERDR_PANE_ID="pane-7" HERDR_BIN_PATH="$HERDR_STUB" \
    CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" "No Herdr Here"
check "no herdr call without HERDR_ENV" "missing" \
    "$([ -f "$HERDR_LOG" ] && echo present || echo missing)"

# 15. Herdr: a missing `herdr` binary never breaks the main title path.
HERDR_ENV=1 HERDR_PANE_ID="pane-7" HERDR_BIN_PATH="${SANDBOX}/does-not-exist" \
    CLAUDE_TITLE_OUTPUT="tty" bash "$SET_TITLE" "Herdr Absent: Still Fine"; rc=$?
check "missing herdr exits 0" "0" "$rc"
check "missing herdr still sets title" "my-project | Herdr Absent: Still Fine" "$(stored_title)"

echo ""
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
