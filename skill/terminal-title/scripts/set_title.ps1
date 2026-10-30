# Set the terminal window title with a folder name prefix (Windows / PowerShell).
#
# PowerShell counterpart of set_title.sh for native Windows sessions of
# Claude Code or Codex. Works with Windows PowerShell 5.1 and PowerShell 7+.
#
# Usage:
#   set_title.ps1 "Your Title Here"                 # skill mode
#   '{"prompt":"..."}' | set_title.ps1              # hook mode (UserPromptSubmit JSON on stdin)
#
# From bash (Claude Code's Bash tool on Windows runs Git Bash) or cmd, call it as:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File <path>\set_title.ps1 "Your Title Here"
#
# Resulting title formats:
#   "<folder> | Your Title"
#   "<prefix> | <folder> | Your Title"   when CODEX_TITLE_PREFIX or CLAUDE_TITLE_PREFIX is set
#                                        (CODEX_TITLE_PREFIX wins when both are set)
#
# Behaviour (mirrors set_title.sh):
#   - exits 0 silently when no title is given, and never fails the caller
#   - strips control characters, caps the title at 80 chars and the prefix at 40
#   - hook mode keeps the first line of the prompt, collapses whitespace, caps
#     it at 40 chars, skips slash commands, and never writes to stdout
#   - writes the final title to ~/.claude/terminal_title atomically
#
# Why a second script: on native Windows, Claude Code's Bash tool strips
# control bytes from subprocess stdout, so the OSC escape that set_title.sh
# prints never reaches the terminal. [Console]::Title wraps the Win32
# SetConsoleTitle API on the inherited console, so no escape sequence has to
# travel through stdout. Windows Terminal and conhost both honour it.

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Title
)

$ErrorActionPreference = 'SilentlyContinue'

function Remove-ControlChars([string]$Text) {
    if (-not $Text) { return '' }
    return ($Text -replace '[\x00-\x1F\x7F]', '')
}

function Limit-Length([string]$Text, [int]$Max) {
    if ($Text.Length -gt $Max) { return $Text.Substring(0, $Max) }
    return $Text
}

function Get-HookTitle([string]$Payload) {
    try {
        $data = $Payload | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return ''
    }
    $prompt = $data.prompt
    if (-not ($prompt -is [string]) -or -not $prompt) { return '' }
    if ($prompt.StartsWith('/')) { return '' }

    $firstLine = ($prompt -split "`r?`n", 2)[0]
    $clean = (Remove-ControlChars ($firstLine -replace '\s+', ' ')).Trim()
    return (Limit-Length $clean 40).TrimEnd()
}

try {
    if (-not $Title) {
        if ([Console]::IsInputRedirected) {
            # Read stdin as UTF-8 bytes rather than through the console code
            # page (changing [Console]::InputEncoding would also change the
            # code page of the parent console).
            $reader = New-Object IO.StreamReader([Console]::OpenStandardInput(), (New-Object Text.UTF8Encoding $false))
            $Title = Get-HookTitle ($reader.ReadToEnd())
        }
        if (-not $Title) { exit 0 }
    }

    $clean = Limit-Length (Remove-ControlChars $Title) 80
    if (-not $clean) { exit 0 }

    $folder = Split-Path -Leaf (Get-Location).ProviderPath

    $rawPrefix = $env:CODEX_TITLE_PREFIX
    if (-not $rawPrefix) { $rawPrefix = $env:CLAUDE_TITLE_PREFIX }
    $prefix = Limit-Length (Remove-ControlChars $rawPrefix) 40

    if ($prefix) {
        $final = "$prefix | $folder | $clean"
    } else {
        $final = "$folder | $clean"
    }

    # Persist the title (atomic write: temp file + rename), like set_title.sh.
    $tempFile = $null
    try {
        # USERPROFILE on Windows (Windows PowerShell 5.1 derives $HOME from
        # HOMEDRIVE/HOMEPATH, which can differ); $HOME elsewhere.
        $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
        $claudeDir = Join-Path $homeDir '.claude'
        [void](New-Item -ItemType Directory -Force -Path $claudeDir)
        $titleFile = Join-Path $claudeDir 'terminal_title'
        $tempFile = "$titleFile.tmp.$PID"
        [IO.File]::WriteAllText($tempFile, "$final`n", (New-Object Text.UTF8Encoding $false))
        Move-Item -LiteralPath $tempFile -Destination $titleFile -Force
    } catch {
        if ($tempFile) { Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue }
    }

    try { [Console]::Title = $final } catch { }
} catch { }

exit 0
