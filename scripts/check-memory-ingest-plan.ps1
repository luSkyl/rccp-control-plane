[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "memory-ingest-plan",
    [string[]]$TargetPaths = @(),
    [string]$OutDir = "docs/治理/最新态",
    [switch]$Strict,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Utf8NoBom {
    Param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $normalized = $Content -replace "`r`n", "`n" -replace "`r", "`n"
    [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false)))
}

function Normalize-PathText {
    Param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    return ([string]$Path).Replace("\", "/").Trim()
}

function Split-PackedList {
    Param([string[]]$Values)
    $packed = New-Object System.Collections.Generic.List[string]
    foreach ($value in @($Values)) {
        if ([string]::IsNullOrWhiteSpace([string]$value)) { continue }
        foreach ($item in @([string]$value -split "[;,]")) {
            $trimmed = ([string]$item).Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) { $packed.Add($trimmed) | Out-Null }
        }
    }
    return @($packed.ToArray())
}

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Read-Text {
    Param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
}

function Read-JsonOrNull {
    Param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Add-Check {
    Param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [bool]$Ok,
        [string]$Detail
    )
    $Checks.Add([ordered]@{
        name = $Name
        ok = [bool]$Ok
        detail = [string]$Detail
    }) | Out-Null
}

function Get-DefaultRoots {
    Param([string]$RepoRoot)
    return @(
        (Join-Path $RepoRoot "docs/adapters"),
        (Join-Path $RepoRoot "docs/AI上下文"),
        (Join-Path $RepoRoot "examples/obsidian-second-brain-repo")
    )
}

function Get-MarkdownFiles {
    Param([string[]]$Paths)
    $files = New-Object System.Collections.Generic.List[string]
    foreach ($raw in @($Paths)) {
        if ([string]::IsNullOrWhiteSpace([string]$raw)) { continue }
        $resolved = $raw
        if (-not [System.IO.Path]::IsPathRooted($resolved)) {
            $resolved = Join-Path (Get-Location).Path $resolved
        }
        if (-not (Test-Path -LiteralPath $resolved)) { continue }
        $item = Get-Item -LiteralPath $resolved
        if ($item.PSIsContainer) {
            foreach ($child in @(Get-ChildItem -LiteralPath $resolved -Recurse -File -Filter *.md)) {
                $files.Add($child.FullName) | Out-Null
            }
        }
        elseif ($item.Extension -ieq ".md") {
            $files.Add($item.FullName) | Out-Null
        }
    }
    return @($files.ToArray() | Sort-Object -Unique)
}

function Get-Frontmatter {
    Param([string]$Text)
    $lines = @($Text -replace "`r`n", "`n" -replace "`r", "`n" -split "`n")
    if ($lines.Count -lt 3) { return [ordered]@{ hasFrontmatter = $false; meta = @{}; body = $Text } }
    if (-not [string]::Equals(([string]$lines[0]).Trim(), "---", [System.StringComparison]::Ordinal)) {
        return [ordered]@{ hasFrontmatter = $false; meta = @{}; body = $Text }
    }
    $endIndex = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ([string]::Equals(([string]$lines[$i]).Trim(), "---", [System.StringComparison]::Ordinal)) {
            $endIndex = $i
            break
        }
    }
    if ($endIndex -lt 0) { return [ordered]@{ hasFrontmatter = $false; meta = @{}; body = $Text } }
    $meta = [ordered]@{}
    for ($i = 1; $i -lt $endIndex; $i++) {
        $line = [string]$lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch '^\s*([A-Za-z0-9_-]+)\s*:\s*(.*)$') { continue }
        $key = $Matches[1]
        $value = [string]$Matches[2]
        $meta[$key] = $value.Trim().Trim("'").Trim('"')
    }
    $body = [string]::Join("`n", @($lines[($endIndex + 1)..($lines.Count - 1)]))
    return [ordered]@{ hasFrontmatter = $true; meta = $meta; body = $body }
}

function Get-Sha256 {
    Param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Text -replace "`r`n", "`n" -replace "`r", "`n"))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (([BitConverter]::ToString($sha.ComputeHash($bytes))) -replace "-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Split-BodyIntoChunks {
    Param(
        [string]$Body,
        [int]$MaxChunkChars = 800
    )
    $chunks = New-Object System.Collections.Generic.List[string]
    $normalized = ($Body -replace "`r`n", "`n" -replace "`r", "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($normalized)) { return @() }
    foreach ($block in @($normalized -split "(\n\s*\n)+")) {
        $trimmed = ([string]$block).Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.Length -le $MaxChunkChars) {
            $chunks.Add($trimmed) | Out-Null
            continue
        }
        $cursor = 0
        while ($cursor -lt $trimmed.Length) {
            $length = [Math]::Min($MaxChunkChars, $trimmed.Length - $cursor)
            $chunks.Add($trimmed.Substring($cursor, $length).Trim()) | Out-Null
            $cursor += $length
        }
    }
    return @($chunks.ToArray())
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$targetList = @(Split-PackedList -Values $TargetPaths)
if ($targetList.Count -eq 0) { $targetList = @(Get-DefaultRoots -RepoRoot $repoRoot) }

$latestJsonPath = Join-Path $OutDir "memory-ingest-plan-latest.json"
$latestMdPath = Join-Path $OutDir "memory-ingest-plan-latest.md"
$latestJsonlPath = Join-Path $OutDir "memory-index-candidates-latest.jsonl"

$previous = Read-JsonOrNull -Path $latestJsonPath
$previousState = @{}
if ($null -ne $previous -and $null -ne $previous.fileState) {
    foreach ($row in @($previous.fileState)) {
        $previousState[[string]$row.source_path] = [string]$row.contentHash
    }
}

$markdownFiles = @(Get-MarkdownFiles -Paths $targetList)
$requiredFields = @("title", "status", "owner", "updated_at", "source_path", "confidence")
$checks = New-Object System.Collections.Generic.List[object]
$files = New-Object System.Collections.Generic.List[object]
$chunks = New-Object System.Collections.Generic.List[object]
$blocked = New-Object System.Collections.Generic.List[object]
$currentState = @{}

foreach ($path in @($markdownFiles)) {
    $text = Read-Text -Path $path
    $front = Get-Frontmatter -Text $text
    $meta = $front.meta
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($field in @($requiredFields)) {
        if ($null -eq $meta[$field] -or [string]::IsNullOrWhiteSpace([string]$meta[$field])) {
            $missing.Add($field) | Out-Null
        }
    }
    $status = [string]$meta["status"]
    $confidence = [string]$meta["confidence"]
    $sourcePath = Normalize-PathText ([string]$meta["source_path"])
    $eligible = ($front.hasFrontmatter -and $missing.Count -eq 0 -and $status -in @("active", "draft", "deprecated", "inbox") -and $confidence -in @("high", "medium", "low"))
    $fileHash = Get-Sha256 -Text $text
    $currentState[$sourcePath] = $fileHash
    $changed = if ($previousState.ContainsKey($sourcePath)) { $previousState[$sourcePath] -ne $fileHash } else { $true }
    $bodyChunks = @(Split-BodyIntoChunks -Body $front.body)
    $files.Add([ordered]@{
        path = Normalize-PathText $path
        title = [string]$meta["title"]
        status = $status
        owner = [string]$meta["owner"]
        updated_at = [string]$meta["updated_at"]
        source_path = $sourcePath
        confidence = $confidence
        hasFrontmatter = [bool]$front.hasFrontmatter
        contentHash = $fileHash
        chunkCount = [int]$bodyChunks.Count
        eligible = [bool]$eligible
        changed = [bool]$changed
    }) | Out-Null
    if (-not $eligible) {
        $blocked.Add([ordered]@{
            path = Normalize-PathText $path
            source_path = $sourcePath
            missingFields = @($missing.ToArray())
            reason = $(if (-not $front.hasFrontmatter) { "missing frontmatter" } else { "missing required metadata" })
        }) | Out-Null
        continue
    }
    for ($i = 0; $i -lt $bodyChunks.Count; $i++) {
        $chunkText = [string]$bodyChunks[$i]
        $chunkHash = Get-Sha256 -Text ($sourcePath + "|" + $i + "|" + $chunkText)
        $chunks.Add([ordered]@{
            chunkId = ("{0}::chunk-{1}" -f $sourcePath, $i)
            source_path = $sourcePath
            path = Normalize-PathText $path
            title = [string]$meta["title"]
            status = $status
            owner = [string]$meta["owner"]
            updated_at = [string]$meta["updated_at"]
            confidence = $confidence
            chunkIndex = [int]$i
            chunkHash = $chunkHash
            text = $chunkText
            chars = [int]$chunkText.Length
        }) | Out-Null
    }
}

$deletedPoints = New-Object System.Collections.Generic.List[string]
foreach ($previousSource in @($previousState.Keys)) {
    if (-not $currentState.ContainsKey($previousSource)) {
        $deletedPoints.Add([string]$previousSource) | Out-Null
    }
}

$changedFiles = @($files | Where-Object { [bool]$_.changed } | ForEach-Object { [string]$_.path })
$unchangedFiles = @($files | Where-Object { -not [bool]$_.changed } | ForEach-Object { [string]$_.path })
$sourceFingerprint = Get-Sha256 -Text ([string]::Join("`n", @($files | Sort-Object source_path | ForEach-Object { "{0}|{1}|{2}" -f $_.source_path, $_.contentHash, $_.updated_at })))
$indexVersion = ("idx-{0}-{1}" -f (Get-Date).ToString("yyyyMMddHHmmss"), $sourceFingerprint.Substring(0, 8))
$sourcePathCoverage = if ($files.Count -eq 0) { 0 } else { [math]::Round(((@($files | Where-Object { [bool]$_.eligible }).Count / [double]$files.Count) * 100), 2) }
$verdict = if ($blocked.Count -eq 0 -and $chunks.Count -gt 0 -and $sourcePathCoverage -eq 100) { "PASS" } else { "FAIL" }

$jsonlLines = New-Object System.Collections.Generic.List[string]
foreach ($chunk in @($chunks.ToArray())) {
    $jsonlLines.Add(($chunk | ConvertTo-Json -Depth 20 -Compress)) | Out-Null
}
Write-Utf8NoBom -Path $latestJsonlPath -Content ([string]::Join("`n", @($jsonlLines.ToArray())))

$report = [ordered]@{
    machineTag = "MEMORY_INGEST_PLAN_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    toolVersion = "check-memory-ingest-plan.ps1/v1"
    verdict = [string]$verdict
    pass = ($verdict -eq "PASS")
    targetPaths = @($targetList)
    fileCount = [int]$files.Count
    eligibleFileCount = [int](@($files | Where-Object { [bool]$_.eligible }).Count)
    chunkCount = [int]$chunks.Count
    blockedCount = [int]$blocked.Count
    sourcePathCoverage = $sourcePathCoverage
    sourceFingerprint = $sourceFingerprint
    indexVersion = $indexVersion
    changedFiles = @($changedFiles)
    unchangedFiles = @($unchangedFiles)
    deletedPoints = @($deletedPoints.ToArray())
    files = @($files.ToArray())
    chunks = @($chunks.ToArray())
    blocked = @($blocked.ToArray())
    fileState = @($files | ForEach-Object { [ordered]@{ source_path = $_.source_path; contentHash = $_.contentHash; path = $_.path } })
    evidencePath = "docs/治理/最新态/memory-ingest-plan-latest.json"
    candidateIndexPath = Normalize-PathText $latestJsonlPath
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action memory-recall-check -Task `"$Task`" -Query `"source path contract`" -Strict"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($report | ConvertTo-Json -Depth 20)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Memory Ingest Plan") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- verdict: {0}" -f $report.verdict)) | Out-Null
$md.Add(("- sourceFingerprint: {0}" -f $report.sourceFingerprint)) | Out-Null
$md.Add(("- indexVersion: {0}" -f $report.indexVersion)) | Out-Null
$md.Add(("- toolVersion: {0}" -f $report.toolVersion)) | Out-Null
$md.Add(("- fileCount: {0}" -f $report.fileCount)) | Out-Null
$md.Add(("- eligibleFileCount: {0}" -f $report.eligibleFileCount)) | Out-Null
$md.Add(("- chunkCount: {0}" -f $report.chunkCount)) | Out-Null
$md.Add(("- sourcePathCoverage: {0}%" -f $report.sourcePathCoverage)) | Out-Null
$md.Add("") | Out-Null
$md.Add("## Delta") | Out-Null
$md.Add(("- changedFiles: {0}" -f $(if ($changedFiles.Count -eq 0) { "none" } else { [string]::Join(", ", $changedFiles) }))) | Out-Null
$md.Add(("- unchangedFiles: {0}" -f $(if ($unchangedFiles.Count -eq 0) { "none" } else { [string]::Join(", ", $unchangedFiles) }))) | Out-Null
$md.Add(("- deletedPoints: {0}" -f $(if ($deletedPoints.Count -eq 0) { "none" } else { [string]::Join(", ", @($deletedPoints.ToArray())) }))) | Out-Null
$md.Add("") | Out-Null
$md.Add("## Blocked") | Out-Null
if ($blocked.Count -eq 0) { $md.Add("- none") | Out-Null }
else {
    foreach ($item in @($blocked.ToArray())) {
        $md.Add(("- {0}: {1}" -f $item.path, $item.reason)) | Out-Null
    }
}
$md.Add("") | Out-Null
$md.Add("## Next") | Out-Null
$md.Add(("- {0}" -f $report.nextCommand)) | Out-Null
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())))

if ($Json) { $report | ConvertTo-Json -Depth 20 }
else { Write-Host ("memory-ingest-plan completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($verdict -eq "PASS") { "Green" } else { "Red" }) }

if ($Strict -and $verdict -ne "PASS") { exit 1 }
