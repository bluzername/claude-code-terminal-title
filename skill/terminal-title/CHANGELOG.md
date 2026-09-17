# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-09-17

### Added
- `hooks/set-title-hook.sh`: a deterministic `UserPromptSubmit` hook that sets the title from the prompt text without relying on the model invoking the skill
- `CLAUDE_TITLE_OUTPUT=tty` mode in `set_title.sh` for hook use (never writes to stdout)
- Shell test suite (`tests/run.sh`), shellcheck, and a zip consistency check in CI
- `scripts/build-skill.sh` to rebuild `terminal-title.skill` from the `skill/` directory

### Changed
- Single source of truth: the skill now lives in `skill/terminal-title/`; the zip is built from it
- `set_title.sh` writes the escape sequence to `/dev/tty` when available so it reaches the terminal even when stdout is captured
- `SKILL.md` frontmatter uses the documented `metadata` field for the version
- README documents the interplay with Claude Code's built-in title feature and `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`

### Removed
- `temp_extract/` (stale 1.1.0 copy that had diverged from the zip)
- `GITHUB-README.md`, `PROJECT-SUMMARY.md`, `QUICK-START.md` (duplicated or stale documentation)
- The nonexistent `claude-code install` command from the install instructions

## [1.2.0] - 2025-11-15

### Added
- Automatic folder name prefix in window titles for better context
- Format: `[Folder Name] | Task Description` or `[Prefix] | [Folder Name] | Task Description` with CLAUDE_TITLE_PREFIX

### Changed
- Updated set_title.sh to prepend the folder name using `basename "$PWD"`

## [1.1.0] - 2025-01-07

### Added
- Optional customization via `CLAUDE_TITLE_PREFIX` environment variable
- LICENSE, VERSION, and CHANGELOG.md
- Explicit task switching examples and "Common Mistakes to Avoid" in SKILL.md
- Terminal type detection in set_title.sh

### Changed
- Fail-safe behaviour: the script exits silently instead of printing an error

### Fixed
- Error suppression for unsupported terminal types

## [1.0.0] - 2025-01-07

### Added
- Initial release
- Automatic terminal title updates based on Claude Code tasks
- SKILL.md with usage instructions and set_title.sh
- Support for macOS Terminal, iTerm2, Alacritty, and other ANSI-compatible terminals
