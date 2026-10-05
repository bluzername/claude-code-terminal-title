# Terminal Title for Claude Code

Sets your terminal window title to the task Claude Code is working on, prefixed with the project folder, so a wall of identical terminal tabs turns into:

```
my-api | Debug: Auth Flow
react-app | Build: Dashboard UI
payment-service | Test: Refund Path
```

Two ways to run it, from one install:

| Mode | How the title is chosen | When it fires |
|------|-------------------------|---------------|
| **Skill** (`SKILL.md`) | Claude reads your prompt and writes a short `Category: Focus` title | When Claude decides you started a new high-level task |
| **Hook** (`hooks/set-title-hook.sh`) | First line of your prompt, capped at 40 chars | Every prompt, deterministically, via a `UserPromptSubmit` hook |

Both call the same `scripts/set_title.sh`, which also stores the title in `~/.claude/terminal_title` so the optional zsh setup can keep it in place across prompts.

## Claude Code already sets a title. Do you need this?

Recent Claude Code releases set the terminal title themselves: a short model-generated summary of the conversation plus a busy indicator. If that is enough for you, you do not need this project.

Use this project when you want:

- the **project folder name** in front of every title (the built-in title does not include it),
- titles that **persist** after Claude Code exits or while a shell prompt is active (via the zsh hook),
- a **deterministic** title from your prompt instead of a model-generated one,
- a custom prefix per machine or role via `CLAUDE_TITLE_PREFIX`.

The two features write to the same terminal title and will overwrite each other. To let this project own the title, disable the built-in one:

```bash
# ~/.zshrc or ~/.bashrc
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1
```

Without that variable the built-in title wins on the next model turn, and you will see the title flip back and forth.

## Install

Requirements: bash, and a terminal that understands OSC title sequences (macOS Terminal.app, iTerm2, Alacritty, Kitty, GNOME Terminal, Konsole, Windows Terminal via WSL, tmux, screen).

### Option 1: install script (macOS and Linux)

```bash
git clone https://github.com/bluzername/claude-code-terminal-title.git
cd claude-code-terminal-title
./install-and-test.sh
```

The script copies `skill/terminal-title` to `~/.claude/skills/terminal-title`, makes the scripts executable, and runs a smoke test that sets a title in the current terminal.

### Option 2: manual

```bash
mkdir -p ~/.claude/skills
cp -R skill/terminal-title ~/.claude/skills/terminal-title
chmod +x ~/.claude/skills/terminal-title/scripts/*.sh ~/.claude/skills/terminal-title/hooks/*.sh
```

For a single project instead of your whole machine, copy it to `.claude/skills/terminal-title` inside the repo.

`terminal-title.skill` at the repo root is the same directory packaged as a zip (`unzip terminal-title.skill -d ~/.claude/skills/`). It is rebuilt from `skill/` by `scripts/build-skill.sh`, and CI fails if the two drift.

### Enable the hook (optional, recommended)

The skill only fires when Claude decides to invoke it. For a title on every prompt, add the hook to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/skills/terminal-title/hooks/set-title-hook.sh"
          }
        ]
      }
    ]
  }
}
```

The hook never blocks a prompt (it always exits 0), never writes to stdout, and ignores slash commands. You can run both the skill and the hook; the skill's `Category: Focus` titles simply replace the hook's raw-prompt titles when Claude invokes it.

### zsh + macOS Terminal.app (optional)

Terminal.app rewrites the title on every prompt (`user - zsh - 80x24`). `setup-zsh.sh` adds a `precmd` function to `~/.zshrc` that re-applies the stored Claude title and turns off Terminal.app's own suffixes. It backs up `~/.zshrc` first and only runs with your confirmation.

```bash
./setup-zsh.sh
```

If you use oh-my-zsh or another framework that manages titles, also add this to `~/.zshrc`, otherwise the framework overwrites the title on each prompt:

```bash
DISABLE_AUTO_TITLE="true"
```

Open a new terminal window afterwards.

### Uninstall

```bash
./uninstall.sh
```

Removes `~/.claude/skills/terminal-title` and `~/.claude/terminal_title`, and offers to remove the zsh block and restore Terminal.app settings. Remove the `UserPromptSubmit` entry from `settings.json` yourself if you added it.

## Usage

Nothing to do. Start `claude` in a project and give it a task.

```
You:    Help me debug the authentication API
Title:  my-api-project | Debug: Auth API Flow
```

### Custom prefix

```bash
export CLAUDE_TITLE_PREFIX="Claude"
# my-project | Build: Dashboard UI  becomes  Claude | my-project | Build: Dashboard UI
```

### Set a title by hand

```bash
bash ~/.claude/skills/terminal-title/scripts/set_title.sh "Review: PR 42"
```

## How it works

- `scripts/set_title.sh <title>` sanitises the input (control characters removed, 80-char cap), prefixes the current folder name and optional `CLAUDE_TITLE_PREFIX`, writes the result atomically to `~/.claude/terminal_title`, then sends the `ESC ] 0 ; title BEL` sequence to `/dev/tty`. If no terminal is attached it falls back to stdout. With `CLAUDE_TITLE_OUTPUT=tty` it never touches stdout, which is what the hook uses.
- `hooks/set-title-hook.sh` reads the hook JSON from stdin (python3, jq, or a sed fallback), takes the first line of `prompt`, collapses whitespace, caps it at 40 chars, and calls `set_title.sh`.
- `setup-zsh.sh` installs an `update_terminal_cwd` override that re-emits the stored title on every prompt. A new shell adopts a stored title only if it is less than 5 minutes old, so stale titles do not leak into unrelated terminals.

## Herdr

[Herdr](https://herdr.dev) multiplexes Claude Code sessions into panes with a
sidebar. Its official integrations report agent lifecycle state only, so the
sidebar stays as a bare `claude` label while the outer terminal title updates.

When `set_title.sh` runs with `HERDR_ENV=1` and `HERDR_PANE_ID` set (both are
exported inside a Herdr pane), it also mirrors the task title into Herdr after
setting the OSC terminal title:

- `herdr pane rename <pane_id> <title>` — renames the pane to the task title.
- `herdr pane report-metadata <pane_id> --source plugin:claude-code-terminal-title --title <title> --display-agent <title> --token task=<title> --ttl-ms 86400000`
  — publishes the title metadata so the sidebar matches.

Point the integration at a specific binary with `HERDR_BIN_PATH` (defaults to
`herdr` on `PATH`). This path is **fail-open**: if `HERDR_ENV` is unset, the
binary is missing, or a `herdr` call fails, the terminal title is still set and
the exit code stays `0`. Non-Herdr sessions are completely unaffected.

**Minimum Herdr version: 0.7.4.** The `--token`/`--clear-token` flags on
`herdr pane report-metadata` were added in 0.7.4 (0.7.3 and earlier exposed
`--custom-status` instead); `herdr pane rename` and the `--source` / `--title`
/ `--display-agent` / `--ttl-ms` flags are present from that release onward.
Verified against the [Herdr CLI reference](https://github.com/herdrdev/herdr/blob/master/docs/versions/0.7.4/website/src/content/docs/cli-reference.mdx)
(latest at time of writing: 0.9.3). Older Herdr builds fail the `--token`
call, which is swallowed by the fail-open guard.

## Compatibility

| Terminal | Status |
|----------|--------|
| macOS Terminal.app + zsh (with `setup-zsh.sh`) | Tested |
| iTerm2 | Tested |
| Alacritty, Kitty, GNOME Terminal, Konsole, Windows Terminal + WSL | Should work, reports welcome |
| Windows native PowerShell or cmd | Not supported by the bash script; see [PR #3](https://github.com/bluzername/claude-code-terminal-title/pull/3) for a PowerShell port |
| Plain bash without a `PROMPT_COMMAND` hook | Titles set, but are not re-applied after each prompt |

Pending community work: [PR #3](https://github.com/bluzername/claude-code-terminal-title/pull/3) adds a Windows `set_title.ps1`; [PR #6](https://github.com/bluzername/claude-code-terminal-title/pull/6) renames [Herdr](https://herdr.dev) panes alongside the terminal title.

## Troubleshooting

**The title flips back to Claude Code's own title.** Set `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` in your shell config and restart Claude Code.

**Nothing changes.** Check the install and run the script directly:

```bash
ls ~/.claude/skills/terminal-title/scripts/set_title.sh
bash ~/.claude/skills/terminal-title/scripts/set_title.sh "Test: It Works"
```

**Title changes, then reverts on the next prompt (Terminal.app).** Run `./setup-zsh.sh` and open a new window.

**Title reverts on the next prompt (oh-my-zsh, prezto, powerlevel10k).** Add `DISABLE_AUTO_TITLE="true"` to `~/.zshrc` before the framework loads.

**Escape codes show up as text.** Your terminal does not support OSC titles. Use one of the terminals in the table above.

**The skill does not fire.** The skill is model-invoked and Claude may skip it for follow-up prompts by design. Enable the hook for deterministic behaviour.

## Development

```bash
bash tests/run.sh          # shell test suite (uses a throwaway HOME)
shellcheck skill/terminal-title/scripts/*.sh skill/terminal-title/hooks/*.sh scripts/*.sh tests/*.sh
scripts/build-skill.sh     # rebuild terminal-title.skill from skill/
```

CI runs shellcheck, the test suite, and a check that the committed zip matches `skill/`.

## Contributing

Most useful right now: reports from Linux terminals and Windows Terminal, a bash `PROMPT_COMMAND` equivalent of `setup-zsh.sh`, and a fish shell variant. Please open an issue with your terminal, shell, and OS.

## License

MIT. See `skill/terminal-title/LICENSE`.
