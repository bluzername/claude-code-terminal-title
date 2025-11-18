# Quick Start Guide

> **For complete documentation, see [README.md](README.md)**

## Quick Installation

### Option 1: Automated Install (Recommended)

```bash
chmod +x install-and-test.sh
./install-and-test.sh
```

### Option 2: Manual Install

```bash
mkdir -p ~/.claude/skills
unzip terminal-title.skill -d ~/.claude/skills/
chmod +x ~/.claude/skills/terminal-title/scripts/set_title.sh
```

## Quick Test

```bash
# Test the script directly
bash ~/.claude/skills/terminal-title/scripts/set_title.sh "Test: It Works!"

# Or use Claude Code - give it any task and watch your terminal title update!
```

## macOS Terminal.app Setup

If you're using macOS Terminal.app, run the setup script for clean titles:

```bash
chmod +x setup-zsh.sh
./setup-zsh.sh
```

## Uninstall

To remove the skill:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Need More Help?

- **Full documentation:** See [README.md](README.md)
- **Troubleshooting:** See the Troubleshooting section in README.md
- **Examples:** See the Examples section in README.md
