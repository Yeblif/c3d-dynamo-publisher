<#
  publish-dynamo.ps1
  ------------------------------------------------------------------
  Publishes the latest RELEASED version of each Civil 3D Dynamo graph
  into the _Published folder that Civil 3D reads from.

  - Looks in every repo in the source folder (folders starting "_" are skipped)
  - A release = a git tag like v1, v2 ... (made in Git Bash or GitHub > Releases)
  - Takes the .dyn files from the repo root AT THAT TAG, so unfinished work on
    main, branches or in test folders is never published
  - Compares file contents (not dates) to report New / Updated / Unchanged
  - Writes _versions.txt in _Published so you can see which version is live

  Paths come from publish-config.json next to this script (not stored in git).
  On first run it is created from publish-config.example.json for you to edit.
  ------------------------------------------------------------------
#>
param(
    [string]$SourceRoot,
    [string]$DestRoot,
    [int]$MaxLogs,
    [switch]$NoFetch    # skip fetching tags from GitHub (e.g. offline)
)

$ErrorActionPreference = 'Continue'

# ---- Load settings: command-line > publish-config.json > defaults ----
$configPath  = Join-Path $PSScriptRoot 'publish-config.json'
$examplePath = Join-Path $PSScriptRoot 'publish-config.example.json'

if (-not (Test-Path $configPath)) {
    Copy-Item $examplePath $configPath
    Write-Host "Created publish-config.json - set your paths in it, save, then run again." -ForegroundColor Yellow
    Start-Process notepad.exe $configPath
    exit 1
}

try   { $config = Get-Content $configPath -Raw | ConvertFrom-Json }
catch { Write-Host "publish-config.json is not valid JSON: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }

function Resolve-Setting($cliValue, $configValue, $default) {
    $v = if ($cliValue) { $cliValue } elseif ($configValue) { $configValue } else { $default }
    if ($v -is [string]) { $v = [Environment]::ExpandEnvironmentVariables($v) }
    return $v
}

# Default source = the folder this repo sits in (e.g. dev\c3d-dynamo when cloned to dev\c3d-dynamo\_publisher)
$SourceRoot = Resolve-Setting $SourceRoot $config.SourceRoot (Split-Path $PSScriptRoot -Parent)
$DestRoot   = Resolve-Setting $DestRoot   $config.DestRoot   $null
$MaxLogs    = [int](Resolve-Setting $MaxLogs $config.MaxLogs 50)

if (-not $DestRoot -or $DestRoot -like '*CHANGE-ME*') {
    Write-Host "Set DestRoot in publish-config.json to your _Published folder." -ForegroundColor Red; exit 1
}
if (-not (Test-Path $SourceRoot)) {
    Write-Host "Source folder not found: $SourceRoot" -ForegroundColor Red; exit 1
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git not found on PATH." -ForegroundColor Red; exit 1
}

$stamp   = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$logDir  = Join-Path $DestRoot 'Logs'
$tmpRoot = Join-Path $env:TEMP "dyn-publish-$stamp"
New-Item -ItemType Directory -Force -Path $DestRoot, $logDir, $tmpRoot | Out-Null

$results = New-Object System.Collections.Generic.List[object]
$seen    = @{}   # dyn file name -> repo, to catch name clashes between repos

function Add-Result($status, $graph, $repo, $version) {
    $results.Add([pscustomobject]@{ Status = $status; Graph = $graph; Version = $version; Repo = $repo })
}

$repos = Get-ChildItem -Path $SourceRoot -Directory |
         Where-Object { $_.Name -notlike '_*' -and (Test-Path (Join-Path $_.FullName '.git')) } |
         Sort-Object Name

foreach ($repo in $repos) {
    $r = $repo.FullName
    Write-Host "Checking $($repo.Name)..." -ForegroundColor DarkGray

    if (-not $NoFetch) {
        git -C $r fetch --tags --quiet origin
        if ($LASTEXITCODE -ne 0) { Write-Host "  fetch failed - using local tags only" -ForegroundColor Yellow }
    }

    $tag = git -C $r tag --list 'v*' --sort=-v:refname | Select-Object -First 1
    if (-not $tag) { Add-Result 'Not released' '-' $repo.Name '-'; continue }

    # Extract the repo exactly as it was at the release tag
    $zip = Join-Path $tmpRoot "$($repo.Name).zip"
    $out = Join-Path $tmpRoot $repo.Name
    git -C $r archive --format=zip -o $zip $tag
    if ($LASTEXITCODE -ne 0) { Add-Result 'ERROR (archive)' '-' $repo.Name $tag; continue }
    try   { Expand-Archive -Path $zip -DestinationPath $out -Force -ErrorAction Stop }
    catch { Add-Result 'ERROR (extract)' '-' $repo.Name $tag; continue }

    $dyns = Get-ChildItem -Path $out -Filter '*.dyn' -File   # repo root only
    if (-not $dyns) { Add-Result 'No .dyn at tag' '-' $repo.Name $tag; continue }

    foreach ($f in $dyns) {
        if ($seen.ContainsKey($f.Name)) {
            Add-Result "CLASH with $($seen[$f.Name])" $f.Name $repo.Name $tag; continue
        }
        $seen[$f.Name] = $repo.Name
        $dest = Join-Path $DestRoot $f.Name

        # Only report success if the copy actually worked (e.g. file open/locked in Dynamo)
        try {
            if (-not (Test-Path $dest)) {
                Copy-Item $f.FullName $dest -Force -ErrorAction Stop
                Add-Result 'New' $f.Name $repo.Name $tag
            }
            elseif ((Get-FileHash $f.FullName).Hash -ne (Get-FileHash $dest -ErrorAction Stop).Hash) {
                Copy-Item $f.FullName $dest -Force -ErrorAction Stop
                Add-Result 'Updated' $f.Name $repo.Name $tag
            }
            else {
                Add-Result 'Unchanged' $f.Name $repo.Name $tag
            }
        }
        catch {
            Add-Result 'ERROR (copy - file open?)' $f.Name $repo.Name $tag
            Write-Host "  Could not publish $($f.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Remove-Item $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue

# ---- Summary (screen + log) ----
$order   = @{ 'New' = 0; 'Updated' = 1; 'Unchanged' = 2; 'Not released' = 3 }
$sorted  = $results | Sort-Object @{ e = { if ($order.ContainsKey($_.Status)) { $order[$_.Status] } else { 9 } } }, Graph
$table   = $sorted | Format-Table -AutoSize | Out-String
$counts  = ($results | Group-Object Status | ForEach-Object { "$($_.Name): $($_.Count)" }) -join '   '
$summary = @"
==================================================
Publish run: $stamp
Source:      $SourceRoot
Destination: $DestRoot
$counts
$table
"@
Write-Host $summary
$summary | Out-File -FilePath (Join-Path $logDir "publish_$stamp.txt") -Encoding utf8

# ---- What's live: _versions.txt ----
$results | Where-Object { $_.Status -in 'New', 'Updated', 'Unchanged' } |
    Sort-Object Graph | Select-Object Graph, Version, Repo |
    Format-Table -AutoSize | Out-String |
    ForEach-Object { "Published graphs - last run $stamp`r`n$_" } |
    Out-File -FilePath (Join-Path $DestRoot '_versions.txt') -Encoding utf8

# ---- Keep only the most recent $MaxLogs logs ----
Get-ChildItem -Path $logDir -Filter 'publish_*.txt' | Sort-Object Name -Descending |
    Select-Object -Skip $MaxLogs | Remove-Item -Force
