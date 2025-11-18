#!/bin/bash
# Terminal Title Skill - Uninstall Script
# This script removes the terminal-title skill and optionally reverts shell configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

SKILL_DIR="${HOME}/.claude/skills/terminal-title"
ZSHRC="${HOME}/.zshrc"
TITLE_FILE="${HOME}/.claude/terminal_title"

echo "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo "${CYAN}║  Terminal Title Skill - Uninstall Script                   ║${NC}"
echo "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Check if skill is installed
if [[ ! -d "$SKILL_DIR" ]]; then
    warning "Skill not found at: ${SKILL_DIR}"
    echo "${YELLOW}  Nothing to uninstall.${NC}"
    echo ""
    exit 0
fi

echo "${BLUE}This will remove:${NC}"
echo "  • ${SKILL_DIR}"
if [[ -f "$TITLE_FILE" ]]; then
    echo "  • ${TITLE_FILE}"
fi
echo ""

# Ask about zsh configuration removal
REMOVE_ZSH_CONFIG=false
if [[ -f "$ZSHRC" ]] && grep -q "CLAUDE_TERMINAL_TITLE_SETUP" "$ZSHRC" 2>/dev/null; then
    echo "${YELLOW}Found terminal-title configuration in ~/.zshrc${NC}"
    read -p "Remove zsh configuration? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        REMOVE_ZSH_CONFIG=true
    fi
fi

# Ask about Terminal.app settings (macOS only)
RESTORE_TERMINAL_SETTINGS=false
if [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
    echo "${YELLOW}Terminal.app title settings were modified${NC}"
    read -p "Restore Terminal.app settings? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        RESTORE_TERMINAL_SETTINGS=true
    fi
fi

echo ""
read -p "${RED}Continue with uninstall? (y/n) ${NC}" -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""

# Remove skill directory
if [[ -d "$SKILL_DIR" ]]; then
    rm -rf "$SKILL_DIR" || error "Failed to remove skill directory"
    success "Removed: ${SKILL_DIR}"
fi

# Remove title file
if [[ -f "$TITLE_FILE" ]]; then
    rm -f "$TITLE_FILE" || warning "Failed to remove title file"
    success "Removed: ${TITLE_FILE}"
fi

# Remove zsh configuration
if [[ "$REMOVE_ZSH_CONFIG" == true ]]; then
    if [[ -f "$ZSHRC" ]]; then
        # Create backup
        BACKUP="${ZSHRC}.backup.before-uninstall.$(date +%Y%m%d_%H%M%S)"
        cp "$ZSHRC" "$BACKUP" || error "Failed to create backup"
        success "Backup created: ${BACKUP}"
        
        # Remove the configuration block
        # Use sed to remove lines between markers
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS sed
            sed -i '' '/# ============================================================================/,/# ============================================================================/d' "$ZSHRC" 2>/dev/null || true
        else
            # GNU sed
            sed -i '/# ============================================================================/,/# ============================================================================/d' "$ZSHRC" 2>/dev/null || true
        fi
        
        # Also remove any standalone update_terminal_cwd function if it exists
        # This is a simpler approach - remove the entire block
        perl -i -pe 'BEGIN{undef $/;} s/# ============================================================================\n# CLAUDE_TERMINAL_TITLE_SETUP.*?# ============================================================================\n//smg' "$ZSHRC" 2>/dev/null || true
        
        success "Removed configuration from ~/.zshrc"
        echo "${YELLOW}  Note: You may need to reload your shell (source ~/.zshrc)${NC}"
    fi
fi

# Restore Terminal.app settings
if [[ "$RESTORE_TERMINAL_SETTINGS" == true ]]; then
    PLIST="$HOME/Library/Preferences/com.apple.Terminal.plist"
    PROFILE=$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || echo "Basic")
    PROFILE="${TERMINAL_PROFILE:-${PROFILE}}"
    
    # Restore default values (true)
    /usr/libexec/PlistBuddy -c "Set ':Window Settings:$PROFILE:ShowActiveProcessInTitle' true" "$PLIST" 2>/dev/null || warning "Failed to restore ShowActiveProcessInTitle"
    /usr/libexec/PlistBuddy -c "Set ':Window Settings:$PROFILE:ShowDimensionsInTitle' true" "$PLIST" 2>/dev/null || warning "Failed to restore ShowDimensionsInTitle"
    /usr/libexec/PlistBuddy -c "Set ':Window Settings:$PROFILE:ShowRepresentedURLInTitle' true" "$PLIST" 2>/dev/null || warning "Failed to restore ShowRepresentedURLInTitle"
    
    success "Restored Terminal.app title settings"
    echo "${YELLOW}  Note: Changes take effect in new Terminal windows${NC}"
fi

echo ""
echo "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo "${GREEN}║  ✓ Uninstall Complete!                                      ║${NC}"
echo "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo ""
echo "${CYAN}Next steps:${NC}"
echo ""
if [[ "$REMOVE_ZSH_CONFIG" == true ]]; then
    echo "1. Reload your shell configuration:"
    echo "   ${BLUE}source ~/.zshrc${NC}"
    echo ""
fi
echo "2. The terminal-title skill has been completely removed."
echo ""
echo "${GREEN}Thank you for using terminal-title skill!${NC}"
echo ""

