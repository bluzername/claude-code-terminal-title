---
name: terminal-title
description: Automatically updates the terminal window title to reflect the current high-level task. Use at the start of every Claude Code or Codex session when the user provides their first prompt, and whenever the user switches to a distinctly new high-level task. Helps developers manage multiple Claude Code or Codex terminals by providing clear, at-a-glance identification of what each terminal is working on.
metadata:
  version: "1.4.0"
---

# Terminal Title

## Overview

Sets a descriptive terminal window title based on the task Claude is working on. Essential for developers running multiple Claude Code instances who need to identify which terminal handles which task.

## When to Use

**Always trigger this skill:**
- At the start of every new Claude Code or Codex session (after receiving the first user prompt)
- When switching to a substantially different task (for example from "API Integration" to "Database Migration")

**Trigger on task switches like these:**
- Switching from frontend work to backend work
- Moving from debugging to new feature development
- Changing from one module or component to a completely different one
- Starting work on a different part of the system (for example from auth to payments)

**Do NOT trigger for:**
- Follow-up questions about the same task ("Can you add a comment to that function?")
- Small refinements to current work ("Make it blue instead of red")
- Debugging the same feature you just built
- Clarifications ("What did you mean by X?")
- Iterating on the same component or module
- Mid-task status updates or progress checks

## How It Works

1. **Extract task summary**: identify the high-level task from the user's prompt
2. **Generate title**: create a concise, descriptive title (max 40 characters)
3. **Set title**: run `set_title.sh` (macOS / Linux) or `set_title.ps1` (native Windows) with the generated title
4. **No confirmation needed**: this happens silently in the background

## Title Format Guidelines

**Good titles:**
- "API Integration: Auth Flow"
- "Fix: Login Bug"
- "DB Migration: Users Table"
- "Build: Dashboard UI"
- "Refactor: Payment Module"

**Displayed as (the script adds the folder prefix):**
- `my-project | API Integration: Auth Flow`
- `my-project | Fix: Login Bug`

**Bad titles:**
- Too long: "Implementing the new authentication system with OAuth2.0 support"
- Too generic: "Working" or "Coding"
- Too verbose: "The user wants me to help them with..."
- Includes system information: "/Users/john/project: Build feature"
- A full sentence: "I am working on the dashboard component"

**Format pattern:**
```
[Action/Category]: [Specific Focus]
```

Keep titles concise, actionable, and immediately recognizable.

## Implementation

Pick the script for the host OS. If unsure, the working directory's path style is a reliable hint: `/home/...` or `/Users/...` means macOS / Linux (including WSL), while `C:\...` or `D:\...` means native Windows.

### macOS / Linux / WSL

Run the script from the installed skill directory. The personal install path is shown; for a project install use `.claude/skills/terminal-title/scripts/set_title.sh` relative to the project root.

```bash
bash ~/.claude/skills/terminal-title/scripts/set_title.sh "Your Title Here"
```

**Example workflow:**
```bash
# User asks: "Help me debug the authentication flow in the API"
bash ~/.claude/skills/terminal-title/scripts/set_title.sh "Debug: Auth API Flow"

# User asks: "Create a React component for the user profile page"
bash ~/.claude/skills/terminal-title/scripts/set_title.sh "Build: User Profile UI"

# User asks: "Write tests for the payment processing module"
bash ~/.claude/skills/terminal-title/scripts/set_title.sh "Test: Payment Module"
```

### Native Windows

Do **not** use `set_title.sh` on native Windows: the Bash tool strips the escape sequence before it reaches the terminal, so nothing changes. Run the PowerShell script instead. From the Bash tool (Git Bash), use this command; `-ExecutionPolicy Bypass` applies to this one call only, so it works under the default `Restricted` policy:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/.claude/skills/terminal-title/scripts/set_title.ps1" "Your Title Here"
```

From a PowerShell tool, the equivalent is (if the execution policy blocks it, use the `powershell.exe -ExecutionPolicy Bypass -File` form with `$env:USERPROFILE`):

```powershell
& "$env:USERPROFILE\.claude\skills\terminal-title\scripts\set_title.ps1" "Your Title Here"
```

For a project install, use `.claude/skills/terminal-title/scripts/set_title.ps1` relative to the project root. Codex installs the skill under `~/.agents/skills` or `~/.codex/skills`; substitute that root for `~/.claude/skills`.

## Script Details

`scripts/set_title.sh` writes the OSC 0 escape sequence to the controlling terminal (`/dev/tty`), falling back to stdout when no terminal is attached. It also stores the title in `~/.claude/terminal_title` so shell hooks can re-apply it after each prompt. It is compatible with macOS Terminal.app, iTerm2, Alacritty, Kitty, and most xterm-compatible emulators (including tmux and screen).

`scripts/set_title.ps1` is the Windows counterpart. It sets the title through `[Console]::Title` (the Win32 `SetConsoleTitle` API) on the inherited console, so no escape sequence has to pass through stdout. It works in Windows Terminal and the classic console host, with Windows PowerShell 5.1 or PowerShell 7, and writes the same `~/.claude/terminal_title` file.

Both scripts take one argument (the title) and exit silently when none is given.

## Automatic Directory Prefix

Every title is prefixed with the current directory name (usually the repo name):

```
my-project | Build: Dashboard UI
another-repo | Debug: Auth API
```

## Optional Custom Prefix

Users can add a custom prefix through the `CLAUDE_TITLE_PREFIX` environment variable (or `CODEX_TITLE_PREFIX`, which wins when both are set):

```bash
export CLAUDE_TITLE_PREFIX="Claude"
```

```powershell
$env:CLAUDE_TITLE_PREFIX = "Claude"
```

This produces titles like `Claude | my-project | Build: Dashboard UI`.

**Note:** You do not need to check these variables or change your behaviour. The script handles them.

## Deterministic Alternative

`hooks/set-title-hook.sh` in this skill directory (or `scripts/set_title.ps1` on native Windows, which reads the hook JSON from stdin when called without an argument) can be wired as a Claude Code `UserPromptSubmit` hook. It sets the title from the first line of every prompt without relying on this skill being invoked. See the project README for the settings snippet.
