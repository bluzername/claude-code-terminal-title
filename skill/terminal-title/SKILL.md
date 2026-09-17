---
name: terminal-title
description: Automatically updates the terminal window title to reflect the current high-level task. Use at the start of every Claude Code session when the user provides their first prompt, and whenever the user switches to a distinctly new high-level task. Helps developers manage multiple Claude Code terminals by providing clear, at-a-glance identification of what each terminal is working on.
metadata:
  version: "1.3.0"
---

# Terminal Title

## Overview

Sets a descriptive terminal window title based on the task Claude is working on. Essential for developers running multiple Claude Code instances who need to identify which terminal handles which task.

## When to Use

**Always trigger this skill:**
- At the start of every new Claude Code session (after receiving the first user prompt)
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
3. **Set title**: run `set_title.sh` with the generated title
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

## Script Details

`scripts/set_title.sh` writes the OSC 0 escape sequence to the controlling terminal (`/dev/tty`), falling back to stdout when no terminal is attached. It also stores the title in `~/.claude/terminal_title` so shell hooks can re-apply it after each prompt. It is compatible with macOS Terminal.app, iTerm2, Alacritty, Kitty, and most xterm-compatible emulators (including tmux and screen).

The script takes one argument (the title) and exits silently when none is given.

## Automatic Directory Prefix

Every title is prefixed with the current directory name (usually the repo name):

```
my-project | Build: Dashboard UI
another-repo | Debug: Auth API
```

## Optional Custom Prefix

Users can add a custom prefix through the `CLAUDE_TITLE_PREFIX` environment variable:

```bash
export CLAUDE_TITLE_PREFIX="Claude"
```

This produces titles like `Claude | my-project | Build: Dashboard UI`.

**Note:** You do not need to check these variables or change your behaviour. The script handles them.

## Deterministic Alternative

`hooks/set-title-hook.sh` in this skill directory can be wired as a Claude Code `UserPromptSubmit` hook. It sets the title from the first line of every prompt without relying on this skill being invoked. See the project README for the settings snippet.
