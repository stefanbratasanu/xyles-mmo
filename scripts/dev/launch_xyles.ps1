param(
    [switch]$ImportOnly,
    [switch]$ForceImport,
    [switch]$TestLaunch
)

# Run from the repository regardless of where the shortcut was started.
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $projectRoot
$consoleGodot = Join-Path $projectRoot 'Godot_v4.7.2-stable_win64_console.exe'
$gameGodot = Join-Path $projectRoot 'Godot_v4.7.2-stable_win64.exe'
$logDir = Join-Path $projectRoot 'logs'
$stampPath = Join-Path $logDir 'launcher_import_stamp.txt'
$importLog = Join-Path $logDir 'launcher_import.log'
$worldCheckLog = Join-Path $logDir 'launcher_world_check.log'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $consoleGodot) -or -not (Test-Path -LiteralPath $gameGodot)) {
    Write-Host 'Godot was not found in the game folder. Both Godot 4.7.2 executables are required.'
    exit 1
}

function Get-SourceFingerprint {
    # Git can change imported files, scenes, scripts or the world snapshot. The
    # cheap metadata scan also notices local edits and new assets between pulls.
    $roots = @('assets', 'scenes', 'scripts', 'shaders') | ForEach-Object { Join-Path $projectRoot $_ }
    $items = foreach ($rootPath in $roots) {
        if (Test-Path -LiteralPath $rootPath) {
            Get-ChildItem -LiteralPath $rootPath -File -Recurse -ErrorAction Stop | Where-Object {
                $_.FullName -notlike '*\assets\animations\Ultimate Animation Collection\*'
            }
        }
    }
    $items += Get-Item -LiteralPath (Join-Path $projectRoot 'project.godot')
    $rows = $items | Sort-Object FullName | ForEach-Object {
        '{0}|{1}|{2}' -f $_.FullName.Substring($projectRoot.Length), $_.Length, $_.LastWriteTimeUtc.Ticks
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($rows -join "`n"))
        return [Convert]::ToBase64String($sha.ComputeHash($bytes))
    } finally { $sha.Dispose() }
}

function Find-MissingImportedResource {
    $importFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'assets') -Filter '*.import' -File -Recurse -ErrorAction Stop
    foreach ($file in $importFiles) {
        $line = Get-Content -LiteralPath $file.FullName | Where-Object { $_ -match '^path="res://\.godot/imported/' } | Select-Object -First 1
        if ($line -match '^path="res://([^\"]+)"') {
            $target = Join-Path $projectRoot ($Matches[1] -replace '/', '\')
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { return $file.FullName }
        }
    }
    return $null
}

try {
    $fingerprint = Get-SourceFingerprint
    $lastFingerprint = if (Test-Path -LiteralPath $stampPath) { (Get-Content -LiteralPath $stampPath -Raw).Trim() } else { '' }
    $missing = Find-MissingImportedResource
    if ($ForceImport -or $fingerprint -ne $lastFingerprint -or $null -ne $missing) {
        Write-Host 'Preparing game assets. This can take a while after an update...'
        & $consoleGodot --headless --path $projectRoot --import *> $importLog
        $importExit = $LASTEXITCODE
        # The editor has a previously documented empty-name diagnostic. Other
        # engine/script errors mean we should show the log rather than silently
        # launching with missing scenery, even if Godot returned exit code zero.
        $problems = @(Get-Content -LiteralPath $importLog | Where-Object {
            ($_ -match '^ERROR:|^SCRIPT ERROR:|Parse Error|^FATAL:') -and
            ($_ -notmatch '^ERROR: Condition "p_name\.is_empty\(\)" is true\.')
        })
        $missing = Find-MissingImportedResource
        if ($importExit -ne 0 -or $problems.Count -gt 0 -or $null -ne $missing) {
            Write-Host 'Asset preparation did not finish cleanly. The game was not started.'
            Write-Host "See: $importLog"
            if ($null -ne $missing) { Write-Host "Missing imported resource for: $missing" }
            $problems | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
            exit 1
        }
        Write-Host 'Checking world assets...'
        & $consoleGodot --headless --path $projectRoot --script 'res://scripts/dev/verify_world_assets.gd' *> $worldCheckLog
        $checkExit = $LASTEXITCODE
        # The project currently emits known renderer cleanup diagnostics at
        # process exit. Missing dependencies and script errors are still fatal.
        $worldProblems = @(Get-Content -LiteralPath $worldCheckLog | Where-Object {
            ($_ -match '^ERROR:|^SCRIPT ERROR:|Parse Error|^FATAL:') -and
            ($_ -notmatch '^ERROR: \d+ RID allocations of type ') -and
            ($_ -notmatch '^ERROR: Pages in use exist at exit in PagedAllocator:') -and
            ($_ -notmatch '^ERROR: \d+ resources still in use at exit')
        })
        if ($checkExit -ne 0 -or $worldProblems.Count -gt 0) {
            Write-Host 'The world asset check failed. The game was not started.'
            Write-Host "See: $worldCheckLog"
            $worldProblems | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
            exit 1
        }
        (Get-SourceFingerprint) | Set-Content -LiteralPath $stampPath -Encoding ASCII
        Write-Host 'Assets are ready.'
    } else {
        Write-Host 'Assets are up to date.'
    }
    if (-not $ImportOnly) {
        $launchArgs = @('--path', ('"{0}"' -f $projectRoot))
        if ($TestLaunch) { $launchArgs += @('--quit-after', '120', '--', '--test-mode') }
        if ($TestLaunch) {
            $process = Start-Process -FilePath $gameGodot -ArgumentList $launchArgs -WorkingDirectory $projectRoot -PassThru -WindowStyle Hidden
        } else {
            $process = Start-Process -FilePath $gameGodot -ArgumentList $launchArgs -WorkingDirectory $projectRoot -PassThru
        }
        Write-Host 'Starting Xyles.'
        if ($TestLaunch) {
            $process.WaitForExit()
            if ($process.ExitCode -ne 0) { exit $process.ExitCode }
        }
    }
} catch {
    Write-Host "Could not prepare the game: $($_.Exception.Message)"
    exit 1
}
