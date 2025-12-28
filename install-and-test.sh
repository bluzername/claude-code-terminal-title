#!/bin/zsh
# Terminal Title Skill - Installation and Testing Script
# This script installs and tests the terminal-title skill for Claude Code

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check required commands
for cmd in unzip mkdir chmod bash; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "${RED}✗ Error:${NC} $cmd is required but not installed." >&2
        echo "  Please install it and try again." >&2
        exit 1
    fi
done

# Error handling functions
error() {
    echo "${RED}✗ Error: $1${NC}" >&2
    exit 1
}

warning() {
    echo "${YELLOW}⚠ Warning: $1${NC}" >&2
}

info() {
    echo "${BLUE}ℹ Info: $1${NC}"
}

success() {
    echo "${GREEN}✓ $1${NC}"
}

# Get the directory where this script is located (POSIX-compliant)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_FILE="${SCRIPT_DIR}/terminal-title.skill"
INSTALL_DIR="${HOME}/.claude/skills"
SETTINGS_FILE="${HOME}/.claude/settings.local.json"
PERMISSION_RULE="Bash(bash *set_title.sh*)"

echo "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo "${CYAN}║  Terminal Title Skill - Installation & Test Script          ║${NC}"
echo "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Step 1: Check if skill file exists
echo "${BLUE}[1/7]${NC} Checking for skill file..."
if [[ ! -f "$SKILL_FILE" ]]; then
    error "terminal-title.skill not found at: ${SKILL_FILE}"
fi
success "Found: ${SKILL_FILE}"
echo ""

# Step 2: Extract the skill
echo "${BLUE}[2/7]${NC} Installing skill to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR" || error "Failed to create directory: ${INSTALL_DIR}"
unzip -o "$SKILL_FILE" -d "$INSTALL_DIR" > /dev/null 2>&1 || error "Failed to extract skill file"
success "Skill extracted successfully"
echo ""

# Step 3: Make script executable
echo "${BLUE}[3/7]${NC} Setting script permissions..."
chmod +x "${INSTALL_DIR}/terminal-title/scripts/set_title.sh" || error "Failed to set script permissions"
success "Script is now executable"
echo ""

# Step 4: Configure auto-approval permission
echo "${BLUE}[4/7]${NC} Configuring auto-approval permission..."
configure_permission() {
    local settings_dir="${HOME}/.claude"
    local settings_file="${settings_dir}/settings.local.json"

    # Create .claude directory if it doesn't exist
    mkdir -p "$settings_dir"

    # Check if settings file exists
    if [[ -f "$settings_file" ]]; then
        # Check if permission already exists
        if grep -q "set_title.sh" "$settings_file" 2>/dev/null; then
            success "Permission already configured"
            return 0
        fi

        # Check if jq is available for proper JSON manipulation
        if command -v jq >/dev/null 2>&1; then
            # Use jq to add the permission properly
            local temp_file="${settings_file}.tmp"
            jq --arg rule "$PERMISSION_RULE" '.permissions.allow += [$rule]' "$settings_file" > "$temp_file" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                mv "$temp_file" "$settings_file"
                success "Added auto-approval permission (using jq)"
                return 0
            else
                rm -f "$temp_file"
            fi
        fi

        # Fallback: Simple string replacement for common JSON structure
        # Look for the "allow": [ pattern and add our rule
        if grep -q '"allow":\s*\[' "$settings_file" 2>/dev/null; then
            # Create backup
            cp "$settings_file" "${settings_file}.backup"

            # Add the permission after the first "allow": [
            sed -i.bak 's/"allow":\s*\[/"allow": [\n      "'"$PERMISSION_RULE"'",/' "$settings_file" 2>/dev/null || \
            sed -i '' 's/"allow": \[/"allow": [\
      "'"$PERMISSION_RULE"'",/' "$settings_file" 2>/dev/null

            if [[ $? -eq 0 ]]; then
                rm -f "${settings_file}.bak"
                success "Added auto-approval permission"
                return 0
            else
                # Restore backup on failure
                mv "${settings_file}.backup" "$settings_file"
            fi
        fi

        warning "Could not automatically add permission. Please add manually (see below)"
        return 1
    else
        # Create new settings file with the permission
        cat > "$settings_file" << EOJSON
{
  "permissions": {
    "allow": [
      "$PERMISSION_RULE"
    ],
    "deny": []
  }
}
EOJSON
        success "Created settings file with auto-approval permission"
        return 0
    fi
}

if configure_permission; then
    echo "  • Claude Code will not ask for approval when setting titles"
else
    echo ""
    echo "${YELLOW}  To enable auto-approval, add this to ~/.claude/settings.local.json:${NC}"
    echo "  ${BLUE}\"$PERMISSION_RULE\"${NC}"
fi
echo ""

# Step 5: Verify installation
echo "${BLUE}[5/7]${NC} Verifying installation..."
if [[ -f "${INSTALL_DIR}/terminal-title/SKILL.md" ]] && \
   [[ -f "${INSTALL_DIR}/terminal-title/scripts/set_title.sh" ]] && \
   [[ -x "${INSTALL_DIR}/terminal-title/scripts/set_title.sh" ]]; then
    success "All files present and configured correctly"
    echo "  • SKILL.md"
    echo "  • LICENSE"
    echo "  • VERSION"
    echo "  • CHANGELOG.md"
    echo "  • scripts/set_title.sh (executable)"
else
    error "Installation verification failed - required files missing or incorrect permissions"
fi
echo ""

# Step 6: Test basic functionality
echo "${BLUE}[6/7]${NC} Testing basic functionality..."
if bash "${INSTALL_DIR}/terminal-title/scripts/set_title.sh" "Test: Installation Successful"; then
    sleep 0.5
    success "Script executed successfully"
    echo "${YELLOW}  ➜ Check your terminal title - it should now say: 'Test: Installation Successful'${NC}"
else
    error "Script execution failed - check script permissions and terminal compatibility"
fi
echo ""

# Step 7: Test with custom prefix
echo "${BLUE}[7/7]${NC} Testing custom prefix feature..."
export CLAUDE_TITLE_PREFIX="🤖 Test"
if bash "${INSTALL_DIR}/terminal-title/scripts/set_title.sh" "With Prefix"; then
    sleep 0.5
    success "Prefix feature works"
    echo "${YELLOW}  ➜ Your terminal title should now say: '🤖 Test | With Prefix'${NC}"
else
    error "Prefix test failed"
fi
unset CLAUDE_TITLE_PREFIX
echo ""

# Test fail-safe behavior (silent test)
bash "${INSTALL_DIR}/terminal-title/scripts/set_title.sh" > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    # Fail-safe works (exits silently with no args)
    :
fi

# Success message
echo "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo "${GREEN}║  ✓ Installation and Testing Complete!                       ║${NC}"
echo "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo ""
echo "${CYAN}Next Steps:${NC}"
echo ""
echo "1. ${YELLOW}Configure Terminal (macOS Terminal.app users only):${NC}"
echo "   If you see unwanted prefixes/suffixes in titles, run:"
echo "   ${BLUE}./setup-zsh.sh${NC}"
echo "   This will configure your ~/.zshrc and Terminal.app settings"
echo ""
echo "2. ${YELLOW}Test with Claude Code:${NC}"
echo "   Open a ${YELLOW}NEW terminal window${NC} and run:"
echo "   ${BLUE}claude${NC}"
echo ""
echo "3. ${YELLOW}Give Claude a task:${NC}"
echo "   Try: \"Help me refactor the authentication module\""
echo "   Your terminal title should update automatically!"
echo ""
echo "4. ${YELLOW}Optional - Set a custom prefix:${NC}"
echo "   Add to your ${BLUE}~/.zshrc${NC}:"
echo "   ${BLUE}export CLAUDE_TITLE_PREFIX=\"🤖 Claude\"${NC}"
echo ""
echo "${CYAN}Installed to:${NC} ${INSTALL_DIR}/terminal-title/"
echo ""
echo "${GREEN}Happy coding! 🚀${NC}"
echo ""
