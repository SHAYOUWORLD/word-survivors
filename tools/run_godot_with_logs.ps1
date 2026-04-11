<#
.SYNOPSIS
    One-shot Godot runner with log capture for Word Survivors.

.DESCRIPTION
    Runs the project without opening the editor. Captures stdout + stderr
    into tools/logs/<timestamp>-<mode>.log and copies it to
    tools/logs/latest.log so you can inspect parse errors, prints, and
    script crashes after the run.

    Modes:
      Run    (default) — launches the main scene (scenes/main.tscn). Play
                         the game; close the window to stop.
      Check            — headless --check-only + quit. Fast script parse
                         pass; exits non-zero if any script fails to parse.
      Editor           — opens the Godot editor on the project.

.PARAMETER Mode
    Run | Check | Editor. Default: Run.

.PARAMETER Scene
    Optional scene path (relative to project root) to run instead of the
    default main scene. Ignored in Check/Editor modes.

.EXAMPLE
    tools\run_godot_with_logs.ps1 -Mode Run
    tools\run_godot_with_logs.ps1 -Mode Check
    tools\run_godot_with_logs.ps1 -Mode Run -Scene scenes/main.tscn

.NOTES
    Godot binary path is hard-coded to C:\dev\Godot. Override via the
    WORD_SURVIVORS_GODOT env var if you move it.
#>

[CmdletBinding()]
param(
    [ValidateSet('Run', 'Check', 'Editor')]
    [string]$Mode = 'Run',

    [string]$Scene = ''
)

$ErrorActionPreference = 'Stop'

# Force UTF-8 for console I/O so Godot's Japanese log output (WordDatabase
# stage name, プレイ時間, etc.) round-trips correctly through PowerShell
# instead of getting mangled into CP932.
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
} catch {
    # Best-effort: if the host doesn't allow it, logs may show mojibake
    # but the run still works.
}

# --- Paths -----------------------------------------------------------------

# Project root = parent of the tools folder this script lives in.
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir      = Join-Path $PSScriptRoot 'logs'

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# Godot executable. Prefer the _console build so stdout flows back to us;
# fall back to the regular GUI build if the console one is missing.
$GodotDir = $env:WORD_SURVIVORS_GODOT
if (-not $GodotDir) {
    $GodotDir = 'C:\dev\Godot'
}

$GodotConsole = Join-Path $GodotDir 'Godot_v4.6.1-stable_win64_console.exe'
$GodotGui     = Join-Path $GodotDir 'Godot_v4.6.1-stable_win64.exe'

if (Test-Path $GodotConsole) {
    $GodotExe = $GodotConsole
}
elseif (Test-Path $GodotGui) {
    $GodotExe = $GodotGui
}
else {
    Write-Error "Godot not found in $GodotDir. Set WORD_SURVIVORS_GODOT or install Godot 4.6.1."
    exit 2
}

# --- Log file --------------------------------------------------------------

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile   = Join-Path $LogDir ("{0}-{1}.log" -f $Timestamp, $Mode.ToLower())
$LatestLog = Join-Path $LogDir 'latest.log'

# --- Build Godot CLI args --------------------------------------------------

$GodotArgs = @('--path', $ProjectRoot)

switch ($Mode) {
    'Run' {
        # NOT headless — we want the window. If you passed an explicit
        # scene, use it; otherwise Godot falls back to [application]/run/main_scene.
        if ($Scene) {
            $GodotArgs += $Scene
        }
    }
    'Check' {
        # --check-only parses every script in the project and exits.
        # --quit-after 1 ensures we bail out after the first frame even if
        # something reaches main loop.
        $GodotArgs += @('--headless', '--check-only', '--quit-after', '1')
    }
    'Editor' {
        $GodotArgs += @('--editor')
    }
}

# --- Run -------------------------------------------------------------------

Write-Host "=== Godot ($Mode) ===" -ForegroundColor Cyan
Write-Host "Binary : $GodotExe"
Write-Host "Project: $ProjectRoot"
Write-Host "Log    : $LogFile"
Write-Host "Args   : $($GodotArgs -join ' ')"
Write-Host ''

# Header to the log file so you can tell runs apart. Write as UTF-8 with
# no BOM so downstream readers (and the user's terminal) see clean text.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$headerLines = @(
    "# Godot $Mode run $Timestamp"
    "# Binary : $GodotExe"
    "# Project: $ProjectRoot"
    "# Args   : $($GodotArgs -join ' ')"
    ''
)
[System.IO.File]::WriteAllLines($LogFile, $headerLines, $utf8NoBom)

# Invoke Godot via the call operator so $LASTEXITCODE is populated. We
# merge stderr into stdout (2>&1) and stream line-by-line to both the
# console and the log file.
#
# Godot writes harmless cleanup warnings to stderr at exit ("ObjectDB
# instances leaked", etc.). With $ErrorActionPreference='Stop' those would
# bubble up as terminating NativeCommandErrors even though the process
# exited cleanly. Flip to 'Continue' just for the invocation.
#
# Why not Tee-Object? PS 5.1's Tee-Object has no -Encoding switch and
# writes UTF-16, which leaves the log unreadable as a text file. Manually
# appending via StreamWriter gives us UTF-8 output on every PS version.
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$logStream = [System.IO.StreamWriter]::new($LogFile, $true, $utf8NoBom)
$logStream.AutoFlush = $true
try {
    & $GodotExe @GodotArgs 2>&1 | ForEach-Object {
        $line = "$_"
        Write-Host $line
        $logStream.WriteLine($line)
    }
    $exit = $LASTEXITCODE
}
finally {
    $logStream.Dispose()
    $ErrorActionPreference = $prevEAP
}

# Refresh the "latest" pointer.
Copy-Item $LogFile $LatestLog -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($exit -eq 0) {
    Write-Host "Exit 0 (ok)" -ForegroundColor Green
}
else {
    Write-Host "Exit $exit" -ForegroundColor Red
}
Write-Host "Log: $LogFile"
exit $exit
