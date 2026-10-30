# Install the terminal-title skill on native Windows (PowerShell).
#
# Defaults to Codex's custom-skill root: ~\.agents\skills when it exists,
# otherwise ~\.codex\skills. For Claude Code, pass the Claude skills root:
#
#   .\install-codex-powershell.ps1 -InstallDir "$env:USERPROFILE\.claude\skills"
#
# Installs from skill\terminal-title in this repository, falling back to the
# packaged terminal-title.skill zip, then runs a smoke test that sets the
# current console title.

[CmdletBinding()]
param(
    [string]$InstallDir
)

$ErrorActionPreference = 'Stop'

function Write-Step($Message) {
    Write-Host "[terminal-title] $Message"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = Join-Path $scriptDir 'skill\terminal-title'
$skillFile = Join-Path $scriptDir 'terminal-title.skill'

if (-not $InstallDir) {
    $agentsSkills = Join-Path $env:USERPROFILE '.agents\skills'
    $codexSkills = Join-Path $env:USERPROFILE '.codex\skills'
    $InstallDir = if (Test-Path -LiteralPath $agentsSkills) { $agentsSkills } else { $codexSkills }
}

$target = Join-Path $InstallDir 'terminal-title'
Write-Step "Installing to $target"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
}

if (Test-Path -LiteralPath (Join-Path $sourceDir 'SKILL.md')) {
    Copy-Item -LiteralPath $sourceDir -Destination $InstallDir -Recurse -Force
} elseif (Test-Path -LiteralPath $skillFile) {
    # Expand-Archive only accepts .zip, so copy the .skill package first.
    $tempZip = Join-Path ([IO.Path]::GetTempPath()) ("terminal-title-{0}.zip" -f [guid]::NewGuid())
    try {
        Copy-Item -LiteralPath $skillFile -Destination $tempZip -Force
        Expand-Archive -LiteralPath $tempZip -DestinationPath $InstallDir -Force
    } finally {
        Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
    }
} else {
    throw "Neither $sourceDir nor $skillFile was found. Run this from a checkout of the repository."
}

$titleScript = Join-Path $target 'scripts\set_title.ps1'
if (-not (Test-Path -LiteralPath $titleScript)) {
    throw "Installed skill is missing scripts\set_title.ps1"
}

Write-Step "Running smoke test (your tab title should change)"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $titleScript 'Test: Install OK'

Write-Step "Installed terminal-title. Restart Codex or Claude Code so the skill list reloads."
