# check_remote_changes.ps1
#
# Watches origin/main for commits that were NOT made on this PC (for example by
# the other developer), explains what changed, flags risky edits, appends a
# report to Documentation/IMPLEMENTATION_LOG.md and lists proposed actions.
#
# It NEVER edits game code. It only reads git, appends to the implementation log
# and stores its own checkpoint in logs/remote_check_state.json (gitignored).
#
# Usage, from the project root:
#   powershell -ExecutionPolicy Bypass -File .\scripts\dev\check_remote_changes.ps1
#   powershell -ExecutionPolicy Bypass -File .\scripts\dev\check_remote_changes.ps1 -ParseCheck
#
# Exit codes: 0 = no external change, 2 = external or risky change found,
#             1 = git/setup error. The report is written before exiting.

param(
    [switch]$ParseCheck,
    [string]$Remote = "origin",
    [string]$Branch = "main",
    [string]$AuthorEmailOverride = ""
)

$ErrorActionPreference = "Stop"
$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { Write-Error "Not inside a git repository."; exit 1 }
Set-Location $root

$logPath = Join-Path $root "Documentation\IMPLEMENTATION_LOG.md"
$statePath = Join-Path $root "logs\remote_check_state.json"
New-Item -ItemType Directory -Force -Path (Split-Path $statePath) | Out-Null

function Write-Utf8([string]$path, [string]$text, [switch]$Append) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    if ($Append) {
        [System.IO.File]::AppendAllText($path, $text, $encoding)
    } else {
        [System.IO.File]::WriteAllText($path, $text, $encoding)
    }
}

function Short([string]$sha) { if ($sha.Length -ge 8) { $sha.Substring(0, 8) } else { $sha } }

function Test-Ancestor([string]$sha, [string]$ref) {
    git merge-base --is-ancestor $sha $ref 2>$null
    return ($LASTEXITCODE -eq 0)
}

# ---------------------------------------------------------------------------
# Identity and remote state
# ---------------------------------------------------------------------------
$localEmail = (git config user.email 2>$null)
if (-not $localEmail) { $localEmail = "" }
if ($AuthorEmailOverride) { $localEmail = $AuthorEmailOverride }
$localEmail = $localEmail.Trim().ToLowerInvariant()

$state = $null
if (Test-Path $statePath) {
    try { $state = Get-Content $statePath -Raw | ConvertFrom-Json } catch { $state = $null }
}

Write-Host "Fetching $Remote/$Branch ..."
git fetch $Remote $Branch --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: git fetch failed. Check network access and credentials." -ForegroundColor Yellow
    exit 1
}

$remoteRef = "$Remote/$Branch"
$remoteHead = (git rev-parse $remoteRef).Trim()
$localHead = (git rev-parse HEAD).Trim()

# First run: only look at commits that are new relative to local work, so the
# report does not replay the entire history.
$base = $null
if ($state -and $state.last_checked_sha) {
    $base = [string]$state.last_checked_sha
    git cat-file -e "$base^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { $base = $null }
}
if (-not $base) {
    $base = (git merge-base HEAD $remoteRef 2>$null)
    if (-not $base) { $base = $remoteHead }
    $base = $base.Trim()
}

Write-Host "Local HEAD  : $(Short $localHead)"
Write-Host "Remote HEAD : $(Short $remoteHead)"
Write-Host "Since       : $(Short $base)"

if ($base -eq $remoteHead) {
    Write-Host "No new commits on $remoteRef since the last check." -ForegroundColor Green
    $state = [ordered]@{
        last_checked_sha = $remoteHead
        last_checked_at  = (Get-Date).ToString("s")
        local_author     = $localEmail
        remote           = $remoteRef
    }
    Write-Utf8 $statePath ($state | ConvertTo-Json)
    exit 0
}

# ---------------------------------------------------------------------------
# Collect commits
# ---------------------------------------------------------------------------
$format = "%H%x1f%an%x1f%ae%x1f%ad%x1f%s"
$raw = git log "$base..$remoteRef" --date=iso-strict --format=$format
$commits = @()
foreach ($line in ($raw -split "`n")) {
    if (-not $line.Trim()) { continue }
    $parts = $line -split [char]0x1f
    if ($parts.Count -lt 5) { continue }
    $sha = $parts[0].Trim()
    $authorEmail = $parts[2].Trim().ToLowerInvariant()
    $stat = git show --numstat --format="" $sha
    $files = @()
    $added = 0
    $removed = 0
    foreach ($row in ($stat -split "`n")) {
        if (-not $row.Trim()) { continue }
        $cells = $row -split "`t"
        if ($cells.Count -lt 3) { continue }
        $files += $cells[2]
        if ($cells[0] -match '^\d+$') { $added += [int]$cells[0] }
        if ($cells[1] -match '^\d+$') { $removed += [int]$cells[1] }
    }
    $commits += [pscustomobject]@{
        Sha        = $sha
        Author     = $parts[1].Trim()
        Email      = $authorEmail
        Date       = $parts[3].Trim()
        Subject    = $parts[4].Trim()
        Files      = $files
        Added      = $added
        Removed    = $removed
        InLocal    = (Test-Ancestor $sha "HEAD")
        External   = ($authorEmail -ne $localEmail) -or (-not (Test-Ancestor $sha "HEAD"))
    }
}

$external = @($commits | Where-Object { $_.External })
$mine = @($commits | Where-Object { -not $_.External })
if ($external.Count -eq 0) {
    Write-Host "New commits exist, but all were authored on this PC ($localEmail)." -ForegroundColor Green
    $state = [ordered]@{
        last_checked_sha = $remoteHead
        last_checked_at  = (Get-Date).ToString("s")
        local_author     = $localEmail
        remote           = $remoteRef
    }
    Write-Utf8 $statePath ($state | ConvertTo-Json)
    exit 0
}

# ---------------------------------------------------------------------------
# Risk heuristics
# ---------------------------------------------------------------------------
$watchFiles = @(
    "project.godot", "scenes/main.tscn", "scripts/main.gd",
    "scripts/game_state.gd", "scripts/world_builder.gd", "scripts/game_hud.gd",
    "scripts/enemy.gd", "scripts/player.gd", "scripts/game_log.gd"
)
$binaryExtensions = @(".png", ".jpg", ".glb", ".gltf", ".blend", ".dll", ".exe", ".zip", ".efkefc", ".res", ".tres")
$dangerExtensions = @(".exe", ".dll", ".zip", ".bat", ".cmd", ".ps1", ".vbs")

$flags = New-Object System.Collections.Generic.List[string]
$allFiles = @($external | ForEach-Object { $_.Files } | Sort-Object -Unique)
$generatedMeta = @($allFiles | Where-Object { $_ -like "*.uid" -or $_ -like "*.import" })
$sourceFiles = @($allFiles | Where-Object { $_ -notlike "*.uid" -and $_ -notlike "*.import" })

foreach ($file in $sourceFiles) {
    if ($file -like "addons/*" -and $file -notlike "addons/effekseer/*") {
        $flags.Add("New or changed addon outside addons/effekseer: ``$file``. Review before running.")
    }
    if ($watchFiles -contains $file) {
        $flags.Add("Core file changed: ``$file``. Re-run the game and the tests before trusting it.")
    }
    $ext = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
    # The bundled Effekseer DLLs are a known, tracked dependency; anything else
    # executable is worth a look before it runs.
    if ($dangerExtensions -contains $ext -and $file -notlike "addons/effekseer/*") {
        $flags.Add("Executable/script added or changed: ``$file``. Do not run it until reviewed.")
    }
}

$deleted = @(git diff --diff-filter=D --name-only "$base..$remoteRef" 2>$null | Where-Object { $_.Trim() })
if ($deleted.Count -gt 0) {
    $flags.Add("$($deleted.Count) file(s) deleted by the remote commits. Confirm the deletion was intended.")
}

# Content-level checks on added lines only.
$addedLines = git log "$base..$remoteRef" -p --unified=0 --format="" 2>$null
$patterns = @{
    "Merge conflict markers" = '^\+.*(<<<<<<<|>>>>>>>|=======)'
    "Debug leftovers"        = '^\+.*(breakpoint|print_debug|TODO|FIXME|HACK)'
    "Hard failure calls"     = '^\+.*(push_error|assert\()'
}
foreach ($key in $patterns.Keys) {
    $hits = @($addedLines -split "`n" | Where-Object { $_ -match $patterns[$key] })
    if ($hits.Count -gt 0) {
        $flags.Add("$key on $($hits.Count) added line(s).")
    }
}

$parseErrors = @()
if ($ParseCheck) {
    $godot = Join-Path $root "Godot_v4.7.2-stable_win64_console.exe"
    if (Test-Path $godot) {
        $worktree = Join-Path $root ".remote-check-worktree"
        Write-Host "Parse-checking $remoteRef in a temporary worktree ..."
        if (Test-Path $worktree) { git worktree remove --force $worktree 2>$null | Out-Null }
        git worktree add --detach $worktree $remoteHead --quiet
        if ($LASTEXITCODE -eq 0) {
            $output = & $godot --headless --path $worktree --import 2>&1 | Out-String
            $parseErrors = @($output -split "`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Failed to load script' })
            if ($parseErrors.Count -gt 0) {
                $flags.Add("Remote tree does not parse: $($parseErrors.Count) script error line(s).")
            } else {
                Write-Host "Parse check passed." -ForegroundColor Green
            }
            git worktree remove --force $worktree 2>$null | Out-Null
        } else {
            $flags.Add("Could not create the temporary worktree for the parse check.")
        }
    } else {
        $flags.Add("Parse check requested but the Godot console binary is missing.")
    }
}

# ---------------------------------------------------------------------------
# Proposed actions
# ---------------------------------------------------------------------------
$actions = New-Object System.Collections.Generic.List[string]
if ($parseErrors.Count -gt 0) {
    $actions.Add("**Revert or block:** the fetched tree has parse errors. Do not merge it until the broken script is named and fixed.")
}
if ($flags -match "Merge conflict markers") {
    $actions.Add("**Block:** resolve the conflict markers before running or committing.")
}
if ($flags -match "Core file changed") {
    $actions.Add("**Re-verify:** launch the game, run the tests, and re-read the changed core files against ``GAME_RULES.md``.")
}
if ($flags -match "New or changed addon|Executable") {
    $actions.Add("**Ask first:** review the addon/executable diff with the user before it is allowed to run.")
}
if ($flags -match "Debug leftovers") {
    $actions.Add("**Modify:** remove or gate debug leftovers after the user agrees.")
}
if ($actions.Count -eq 0) {
    $actions.Add("**Keep:** no structural risk detected. Still run the game and the tests once.")
}
$actions.Add("Nothing was changed automatically. Confirm each action with the user before editing or reverting.")

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## $stamp - Remote changes from another machine (automatic)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Source.** ``$remoteRef`` moved from ``$(Short $base)`` to ``$(Short $remoteHead)``. Local HEAD is ``$(Short $localHead)``.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Commits not authored on this PC** (local identity: ``$localEmail``):")
[void]$sb.AppendLine("")
foreach ($commit in $external) {
    $localNote = if ($commit.InLocal) { " [already in local HEAD]" } else { " [not in local HEAD]" }
    [void]$sb.AppendLine("- ``$(Short $commit.Sha)`` $($commit.Date) **$($commit.Author)** - $($commit.Subject) ($($commit.Files.Count) files, +$($commit.Added)/-$($commit.Removed))$localNote")
}
if ($mine.Count -gt 0) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**New commits authored on this PC:** $($mine.Count) (not reported as external).")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Files touched by the external commits:**")
[void]$sb.AppendLine("")
$shown = 0
foreach ($file in $sourceFiles) {
    [void]$sb.AppendLine("- ``$file``")
    $shown += 1
    if ($shown -ge 60) { break }
}
if ($sourceFiles.Count -gt $shown) {
    [void]$sb.AppendLine("- ... and $($sourceFiles.Count - $shown) more source file(s)")
}
if ($generatedMeta.Count -gt 0) {
    [void]$sb.AppendLine("- Generated Godot metadata: $($generatedMeta.Count) ``.uid``/``.import`` file(s) (regenerate with a headless import)")
}
if ($deleted.Count -gt 0) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**Deleted files:**")
    [void]$sb.AppendLine("")
    foreach ($file in $deleted) { [void]$sb.AppendLine("- ``$file``") }
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Flags.**")
[void]$sb.AppendLine("")
if ($flags.Count -eq 0) {
    [void]$sb.AppendLine("- None from the static heuristics.")
} else {
    foreach ($flag in $flags) { [void]$sb.AppendLine("- $flag") }
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Proposed actions (not applied).**")
[void]$sb.AppendLine("")
foreach ($action in $actions) { [void]$sb.AppendLine("- $action") }
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Status.** Awaiting the user's decision. This report did not modify any game code.")
[void]$sb.AppendLine("")

Write-Utf8 $logPath $sb.ToString() -Append
Write-Host ""
Write-Host "Report appended to Documentation/IMPLEMENTATION_LOG.md" -ForegroundColor Cyan
Write-Host "External commits: $($external.Count); flags: $($flags.Count)" -ForegroundColor Yellow
foreach ($flag in $flags) { Write-Host "  ! $flag" -ForegroundColor Yellow }

$state = [ordered]@{
    last_checked_sha = $remoteHead
    last_checked_at  = (Get-Date).ToString("s")
    local_author     = $localEmail
    remote           = $remoteRef
}
Write-Utf8 $statePath ($state | ConvertTo-Json)
exit 2
