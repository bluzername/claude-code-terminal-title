# Terminal Title Skill for Claude Code

## What It Does

Automatically updates your terminal window title to reflect the current task Claude Code is working on. Perfect for developers managing multiple Claude Code instances across different terminals.

## The Problem It Solves

Running multiple Claude Code sessions? Constantly clicking between terminals trying to remember which one is handling your API integration vs database migration vs bug fix? This skill eliminates that frustration.

## How It Works

The skill automatically:
1. Analyzes your prompt when you start a new task
2. Generates a concise, descriptive title (e.g., "API Integration: Auth Flow")
3. Prepends the current folder name for context (e.g., "my-project | API Integration: Auth Flow")
4. Updates your terminal window title in the background
5. No manual configuration needed

## Installation

### Automated Install & Test (Recommended)

```bash
# Clone or download this repository, then run:
cd claude-code-terminal-title
chmod +x install-and-test.sh
./install-and-test.sh
```

This script will:
- ✅ Check for required prerequisites (unzip, mkdir, chmod, bash)
- ✅ Extract the skill to `~/.claude/skills/`
- ✅ Set proper permissions
- ✅ Run verification tests
- ✅ Show you the results in real-time

### Quick Install (Claude Code CLI)

```bash
# Download the skill file, then install it:
claude-code install terminal-title.skill
```

### Manual Install (macOS / Linux)

```bash
# Create skills directory if it doesn't exist
mkdir -p ~/.claude/skills

# Extract the skill
unzip terminal-title.skill -d ~/.claude/skills/

# Make script executable
chmod +x ~/.claude/skills/terminal-title/scripts/set_title.sh
```

### Manual Install (Windows)

```powershell
# Create skills directory if it doesn't exist
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null

# Extract the skill
Expand-Archive -Force terminal-title.skill "$env:USERPROFILE\.claude\skills\"

# Quick smoke test — your Windows Terminal tab title should change
& "$env:USERPROFILE\.claude\skills\terminal-title\scripts\set_title.ps1" "Test: Install OK"
```

The Windows version uses the .NET `[Console]::Title` API (Win32 `SetConsoleTitle`) rather than ANSI escape sequences, because Claude Code's Bash tool strips control bytes from subprocess stdout before they reach the host terminal. See the "Compatibility" section for details.

### Uninstall

To remove the skill completely:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

The uninstall script will:
- Remove the skill directory
- Optionally remove zsh configuration (with confirmation)
- Optionally restore Terminal.app settings (with confirmation)

### Additional Setup (macOS Terminal.app Users)

If you're using macOS Terminal.app with zsh, run the setup script to ensure clean titles without unwanted prefixes/suffixes:

```bash
cd claude-code-terminal-title
chmod +x setup-zsh.sh
./setup-zsh.sh
```

This script will:
- ✅ Configure your `~/.zshrc` to preserve Claude titles
- ✅ Disable Terminal.app's title suffixes (shell name, dimensions)
- ✅ Create a backup of your `.zshrc` before making changes

**Why is this needed?** macOS Terminal.app by default appends " – -zsh – 80x24" to all window titles. This setup script automatically disables those additions so you get clean titles.

**Note:** Changes take effect in NEW terminal windows. You'll need to open a new window or tab after running the setup.

## Usage

**That's it!** The skill works automatically. When you start Claude Code and give it a task, your terminal title will update.

### Examples

**User prompt:** "Help me debug the authentication API"
**Terminal title:** → "my-api-project | Debug: Auth API Flow"

**User prompt:** "Create a React dashboard component"
**Terminal title:** → "react-app | Build: Dashboard UI"

**User prompt:** "Write tests for payment processing"
**Terminal title:** → "payment-service | Test: Payment Module"

### Optional Customization

You can add a custom prefix to all terminal titles:

```bash
# Add to your ~/.bashrc, ~/.zshrc, or shell config:
export CLAUDE_TITLE_PREFIX="🤖 Claude"
```

This produces titles like: `🤖 Claude | my-project | Build: Dashboard UI`

**Title Format:**
- Default: `[Folder Name] | [Task Description]`
- With custom prefix: `[Custom Prefix] | [Folder Name] | [Task Description]`

## Compatibility

### Fully Tested & Working
- ✅ macOS Terminal.app + zsh (with setup-zsh.sh)
- ✅ iTerm2 (macOS)
- ✅ Windows Terminal + PowerShell (via the bundled `set_title.ps1`)

### Should Work (Not Extensively Tested)
- ⚠️ Alacritty
- ⚠️ Kitty
- ⚠️ GNOME Terminal (Linux)
- ⚠️ Konsole (KDE)
- ⚠️ Windows Terminal + WSL
- ⚠️ Windows Console Host (conhost.exe) — PowerShell variant should work; not benchmarked

### Known Limitations
- ❌ Plain bash without precmd support (titles won't persist across prompts)
- ❌ Very old terminal emulators without ANSI support

### Windows: Why a Second Script?

On Windows, the bash version's `printf '\033]0;...\007'` approach does **not** work when Claude Code invokes the script through its Bash tool, even though Windows Terminal itself fully supports OSC 0 title sequences. The reason is that Claude Code's Bash tool sanitizes control bytes from subprocess stdout before display, so the escape never reaches the host terminal.

The Windows-specific `set_title.ps1` sidesteps this by calling `[Console]::Title = ...` (which wraps the Win32 `SetConsoleTitle` API). The hook PowerShell subprocess inherits Claude Code's console, so the title-set call hits the parent terminal directly without going through stdout.

### Session Behavior
When you set a title in Terminal A and open Terminal B within 5 minutes, Terminal B will initially inherit Terminal A's title. Once Claude Code runs in Terminal B and sets a new title, each terminal will maintain its own title independently. This is by design - it prevents stale titles from appearing in new terminals while preserving titles within active sessions.

## Technical Details

- **Size:** ~2KB
- **Dependencies:** None (uses standard bash)
- **Triggers:** First prompt in a new session, or when switching to a new high-level task
- **Privacy:** All processing happens locally, no external calls

## Troubleshooting

### Title Not Updating?

1. **Verify installation:**
   ```bash
   ls -la ~/.claude/skills/terminal-title/
   # Should show: SKILL.md, scripts/, LICENSE, VERSION, CHANGELOG.md
   ```

2. **Check script permissions:**
   ```bash
   ls -la ~/.claude/skills/terminal-title/scripts/set_title.sh
   # Should show: -rwxr-xr-x (executable)
   ```

3. **If not executable, fix permissions:**
   ```bash
   chmod +x ~/.claude/skills/terminal-title/scripts/set_title.sh
   ```

4. **Test manually:**
   ```bash
   bash ~/.claude/skills/terminal-title/scripts/set_title.sh "Test: It Works!"
   # Your terminal title should change
   ```

### Title Shows Escape Codes?

Your terminal may not support ANSI escape sequences. Try:
- **macOS:** Use iTerm2 or built-in Terminal.app
- **Linux:** Use GNOME Terminal, Alacritty, or Kitty
- **Windows:** Use the bundled `set_title.ps1` (PowerShell) rather than `set_title.sh` (bash). The bash version's escape-sequence approach is filtered by Claude Code's Bash tool on Windows.

### Windows: Title Not Updating?

1. **Verify the PowerShell script exists:**
   ```powershell
   Test-Path "$env:USERPROFILE\.claude\skills\terminal-title\scripts\set_title.ps1"
   ```
2. **Test manually from Windows Terminal:**
   ```powershell
   & "$env:USERPROFILE\.claude\skills\terminal-title\scripts\set_title.ps1" "Test: Manual"
   # Your tab title should immediately show "<cwd> | Test: Manual"
   ```
3. **Confirm SKILL.md is dispatching to the .ps1, not the .sh.** Open `SKILL.md` and verify the Implementation section mentions the PowerShell path.

### Skill Not Triggering Automatically?

- Restart Claude Code after installation
- Verify SKILL.md is properly formatted (YAML front matter at top)
- Check Claude Code version supports skills

### Title Shows Unwanted Prefix or Suffix? (macOS Terminal.app)

If your title shows something like "username - Your Title - -zsh - 80x24", run:

```bash
./setup-zsh.sh
```

Then open a NEW terminal window. See the "Additional Setup" section above for details.

### Title Too Generic?

Be more specific in your prompts about what you want to accomplish

## Contributing

**We need your help!** This skill was built and tested primarily on macOS with Terminal.app and zsh.

### Areas Where We Need Contributions:

**Terminal Emulator Testing:**
- Alacritty users - does it work out of the box?
- Kitty users - any title persistence issues?
- Linux (GNOME Terminal, Konsole, Terminator) - what setup is needed?
- Windows Terminal + WSL - does the zsh config work?

**Shell Support:**
- bash users - can we add precmd equivalent for bash?
- fish shell - title persistence implementation?
- Other shells?

**Feature Improvements:**
- Better title generation logic in SKILL.md
- Configuration options (freshness window, fallback behavior)
- Support for tmux/screen session titles

### How to Contribute:

1. **Test on your setup** - Try the skill and document what works/doesn't
2. **Submit issues** - Found a bug or edge case? Open an issue with details
3. **Pull requests welcome** - Especially for:
   - Shell-specific setup scripts (setup-bash.sh, setup-fish.sh)
   - Cross-platform compatibility fixes
   - Documentation improvements

Found a bug? Have a feature request? Open an issue on GitHub!

## License

MIT - Use freely, modify as needed, share with your team.

---

Created to solve a real pain point in multi-terminal Claude Code workflows. Hope it helps your productivity too!
