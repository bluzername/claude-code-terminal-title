# PowerShell test suite for set_title.ps1 (mirrors tests/run.sh).
# Runs with a throwaway HOME / USERPROFILE so it never touches the real ~/.claude.
#
# Usage:  pwsh -NoProfile -File tests/run.ps1
#         powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\run.ps1

$ErrorActionPreference = 'Stop'

$repoDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$setTitle = Join-Path $repoDir 'skill\terminal-title\scripts\set_title.ps1'
$shell = (Get-Process -Id $PID).Path

$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("terminal-title-test-{0}" -f [guid]::NewGuid())
$fakeHome = Join-Path $sandbox 'home'
$project = Join-Path $sandbox 'my-project'
New-Item -ItemType Directory -Force -Path $fakeHome, $project | Out-Null
$titleFile = Join-Path $fakeHome '.claude\terminal_title'

$script:pass = 0
$script:fail = 0

function Check([string]$Name, [string]$Expected, [string]$Actual) {
    if ($Expected -ceq $Actual) {
        $script:pass++
        Write-Output "ok   - $Name"
    } else {
        $script:fail++
        Write-Output "FAIL - $Name"
        Write-Output "       expected: '$Expected'"
        Write-Output "       actual:   '$Actual'"
    }
}

function Stored-Title {
    if (Test-Path -LiteralPath $titleFile) {
        return ([IO.File]::ReadAllText($titleFile)).TrimEnd("`n")
    }
    return ''
}

# Run set_title.ps1 in a child process with a clean environment for the prefix
# variables, the sandbox HOME, and the project folder as working directory.
# Returns @{ Code = <exit code>; Out = <stdout text> }.
function Invoke-SetTitle {
    param([string[]]$Arguments = @(), [string]$Stdin = $null, [hashtable]$Env = @{})

    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $shell
    $quoted = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', "`"$setTitle`"")
    foreach ($a in $Arguments) { $quoted += '"' + ($a -replace '"', '\"') + '"' }
    $psi.Arguments = $quoted -join ' '
    $psi.WorkingDirectory = $project
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $true
    $psi.EnvironmentVariables['HOME'] = $fakeHome
    $psi.EnvironmentVariables['USERPROFILE'] = $fakeHome
    $psi.EnvironmentVariables.Remove('CODEX_TITLE_PREFIX')
    $psi.EnvironmentVariables.Remove('CLAUDE_TITLE_PREFIX')
    foreach ($k in $Env.Keys) { $psi.EnvironmentVariables[$k] = $Env[$k] }

    $p = [Diagnostics.Process]::Start($psi)
    if ($null -ne $Stdin) { $p.StandardInput.Write($Stdin) }
    $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd()
    [void]$p.StandardError.ReadToEnd()
    $p.WaitForExit()
    # [Console]::Title on non-Windows hosts writes an OSC sequence to the
    # terminal; strip it so stdout assertions only see real output.
    $out = $out -replace "\x1b\]0;[^\x07]*\x07", ''
    return @{ Code = $p.ExitCode; Out = $out }
}

try {
    # 1. No argument, no stdin: exit 0, no output, no file.
    $r = Invoke-SetTitle
    Check 'no-arg exits 0' '0' "$($r.Code)"
    Check 'no-arg prints nothing' '' $r.Out
    Check 'no-arg writes no file' 'missing' $(if (Test-Path $titleFile) { 'present' } else { 'missing' })

    # 2. Basic title gets the folder prefix.
    $r = Invoke-SetTitle -Arguments 'Build: Dashboard UI'
    Check 'folder prefix' 'my-project | Build: Dashboard UI' (Stored-Title)
    Check 'arg mode prints nothing' '' $r.Out

    # 3. Custom prefixes.
    [void](Invoke-SetTitle -Arguments 'Fix: Login Bug' -Env @{ CLAUDE_TITLE_PREFIX = 'Claude' })
    Check 'claude prefix' 'Claude | my-project | Fix: Login Bug' (Stored-Title)
    [void](Invoke-SetTitle -Arguments 'Fix: Login Bug' -Env @{ CLAUDE_TITLE_PREFIX = 'Claude'; CODEX_TITLE_PREFIX = 'Codex' })
    Check 'codex prefix wins' 'Codex | my-project | Fix: Login Bug' (Stored-Title)

    # 4. Control characters are stripped.
    [void](Invoke-SetTitle -Arguments ("Debug:`tAuth" + [char]27 + '[31m Flow'))
    Check 'control chars stripped' 'my-project | Debug:Auth[31m Flow' (Stored-Title)

    # 5. 80-character cap on the task title, 40 on the prefix.
    [void](Invoke-SetTitle -Arguments ('a' * 120) -Env @{ CLAUDE_TITLE_PREFIX = ('p' * 60) })
    Check '80/40-char caps' (('p' * 40) + ' | my-project | ' + ('a' * 80)) (Stored-Title)

    # 6. Empty title is a no-op.
    [void](Invoke-SetTitle -Arguments 'Test: Keep Me')
    [void](Invoke-SetTitle -Arguments '')
    Check 'empty title is a no-op' 'my-project | Test: Keep Me' (Stored-Title)

    # 7. Hook mode: JSON on stdin sets the title from the first line, no stdout.
    $payload = '{"session_id":"abc","hook_event_name":"UserPromptSubmit","prompt":"Refactor the payment module\nand add tests"}'
    $r = Invoke-SetTitle -Stdin $payload
    Check 'hook exits 0' '0' "$($r.Code)"
    Check 'hook prints nothing' '' $r.Out
    Check 'hook sets title from first line' 'my-project | Refactor the payment module' (Stored-Title)

    # 8. Hook mode: whitespace collapsed, capped at 40 chars.
    [void](Invoke-SetTitle -Stdin '{"prompt":"   Investigate    why the   nightly    build fails on the arm64 runners after upgrade   "}')
    Check 'hook caps at 40 chars' 'my-project | Investigate why the nightly build fails' (Stored-Title)

    # 9. Hook mode: slash commands are ignored.
    [void](Invoke-SetTitle -Arguments 'Before Slash')
    [void](Invoke-SetTitle -Stdin '{"prompt":"/compact"}')
    Check 'hook ignores slash commands' 'my-project | Before Slash' (Stored-Title)

    # 10. Hook mode: invalid JSON exits 0 and changes nothing.
    $r = Invoke-SetTitle -Stdin 'not json at all'
    Check 'hook invalid JSON exits 0' '0' "$($r.Code)"
    Check 'hook invalid JSON prints nothing' '' $r.Out
    Check 'hook invalid JSON leaves title' 'my-project | Before Slash' (Stored-Title)

    # 11. An argument takes precedence over stdin.
    [void](Invoke-SetTitle -Arguments 'Arg Wins' -Stdin '{"prompt":"Stdin Loses"}')
    Check 'argument beats stdin' 'my-project | Arg Wins' (Stored-Title)
} finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ''
Write-Output "passed: $script:pass, failed: $script:fail"
if ($script:fail -ne 0) { exit 1 }
exit 0
