#!/bin/bash
# Terminal Title for Claude Code - install and smoke test.
#
# Copies skill/terminal-title to ~/.claude/skills/terminal-title (or extracts
# terminal-title.skill when only the zip is present), makes the scripts
# executable, and sets a test title in the current terminal.

set -euo pipefail

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

error() { echo "${RED}error: $1${NC}" >&2; exit 1; }
success() { echo "${GREEN}ok${NC}  $1"; }
step() { echo "${BLUE}[$1]${NC} $2"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/skill/terminal-title"
SKILL_ZIP="${SCRIPT_DIR}/terminal-title.skill"
INSTALL_ROOT="${HOME}/.claude/skills"
INSTALL_DIR="${INSTALL_ROOT}/terminal-title"

echo "${CYAN}Terminal Title for Claude Code - install${NC}"
echo ""

step "1/5" "Locating skill source"
if [ -f "${SOURCE_DIR}/SKILL.md" ]; then
    success "using directory ${SOURCE_DIR}"
    SOURCE_KIND="dir"
elif [ -f "$SKILL_ZIP" ]; then
    command -v unzip >/dev/null 2>&1 || error "unzip is required to install from ${SKILL_ZIP}"
    success "using zip ${SKILL_ZIP}"
    SOURCE_KIND="zip"
else
    error "neither ${SOURCE_DIR} nor ${SKILL_ZIP} found"
fi

step "2/5" "Installing to ${INSTALL_DIR}"
mkdir -p "$INSTALL_ROOT"
rm -rf "$INSTALL_DIR"
if [ "$SOURCE_KIND" = "dir" ]; then
    cp -R "$SOURCE_DIR" "$INSTALL_DIR"
else
    unzip -o -q "$SKILL_ZIP" -d "$INSTALL_ROOT"
fi
chmod +x "${INSTALL_DIR}/scripts/set_title.sh" "${INSTALL_DIR}/hooks/set-title-hook.sh"
success "installed"

step "3/5" "Verifying files"
for f in SKILL.md VERSION LICENSE CHANGELOG.md scripts/set_title.sh hooks/set-title-hook.sh; do
    [ -f "${INSTALL_DIR}/${f}" ] || error "missing ${INSTALL_DIR}/${f}"
done
success "version $(cat "${INSTALL_DIR}/VERSION")"

step "4/5" "Setting a test title"
FOLDER=$(basename "$PWD")
bash "${INSTALL_DIR}/scripts/set_title.sh" "Test: Installation Successful"
success "look for the title: ${YELLOW}${FOLDER} | Test: Installation Successful${NC}"

step "5/5" "Testing CLAUDE_TITLE_PREFIX"
CLAUDE_TITLE_PREFIX="Claude" bash "${INSTALL_DIR}/scripts/set_title.sh" "With Prefix"
success "look for the title: ${YELLOW}Claude | ${FOLDER} | With Prefix${NC}"

echo ""
echo "${GREEN}Install complete.${NC}"
echo ""
echo "${CYAN}Next steps${NC}"
echo ""
echo "1. Let this project own the title (Claude Code sets its own otherwise):"
echo "   ${BLUE}export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1${NC}   # add to ~/.zshrc or ~/.bashrc"
echo ""
echo "2. Optional, deterministic titles on every prompt - add to ~/.claude/settings.json:"
echo '   {"hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command",'
echo '     "command": "bash ~/.claude/skills/terminal-title/hooks/set-title-hook.sh"}]}]}}'
echo ""
echo "3. macOS Terminal.app + zsh users: ${BLUE}./setup-zsh.sh${NC} keeps titles across prompts."
echo ""
echo "4. Open a new terminal, run ${BLUE}claude${NC}, and give it a task."
echo ""
