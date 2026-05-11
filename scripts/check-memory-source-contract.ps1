[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "memory-source-contract-check",
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
    if ($lines.Count -lt 3) {
        return [ordered]@{ hasFrontmatter = $false; meta = @{}; body = $Text }
    }
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
    if ($endIndex -lt 0) {
        return [ordered]@{ hasFrontmatter = $false; meta = @{}; body = $Text }
    }
    $meta = [ordered]@{}
    for ($i = 1; $i -lt $endIndex; $i++) {
        $line = [string]$lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch '^\s*([A-Za-z0-9_-]+)\s*:\s*(.*)$') { continue }
        $key = $Matches[1]
        $value = [string]$Matches[2]
        if ($value -match '^\[(.*)\]\s*$') {
            $items = @()
            foreach ($part in @($Matches[1] -split ',')) {
                $trimmed = ([string]$part).Trim().Trim("'").Trim('"')
                if (-not [string]::IsNullOrWhiteSpace($trimmed)) { $items += $trimmed }
            }
            $meta[$key] = @($items)
        }
        else {
            $meta[$key] = $value.Trim().Trim("'").Trim('"')
        }
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

$repoRoot = Get-RepoRoot
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$targetList = @(Split-PackedList -Values $TargetPaths)
if ($targetList.Count -eq 0) {
    $targetList = @(Get-DefaultRoots -RepoRoot $repoRoot)
}

$checks = New-Object System.Collections.Generic.List[object]
$notes = New-Object System.Collections.Generic.List[object]
$violations = New-Object System.Collections.Generic.List[object]
$markdownFiles = @(Get-MarkdownFiles -Paths $targetList)

foreach ($path in @($markdownFiles)) {
    $text = Read-Text -Path $path
    $front = Get-Frontmatter -Text $text
    $meta = $front.meta
    $requiredFields = @("title", "status", "owner", "updated_at", "source_path", "confidence")
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($field in @($requiredFields)) {
        if ($null -eq $meta[$field] -or [string]::IsNullOrWhiteSpace([string]$meta[$field])) {
            $missing.Add($field) | Out-Null
        }
    }
    $status = [string]$meta["status"]
    $confidence = [string]$meta["confidence"]
    $sourcePath = Normalize-PathText ([string]$meta["source_path"])
    $title = [string]$meta["title"]
    $owner = [string]$meta["owner"]
    $updatedAt = [string]$meta["updated_at"]
    $fileHash = Get-Sha256 -Text $text
    $isObsidianState = $path -match '(^|[\\/])\.obsidian([\\/]|$)'
    $allowedStatuses = @("active", "draft", "deprecated", "inbox")
    $allowedConfidence = @("high", "medium", "low")
    $statusOk = $allowedStatuses -contains $status
    $confidenceOk = $allowedConfidence -contains $confidence
    $metadataOk = ($front.hasFrontmatter -and $missing.Count -eq 0 -and $statusOk -and $confidenceOk -and -not $isObsidianState)
    if (-not $metadataOk) {
        $violations.Add([ordered]@{
            path = Normalize-PathText $path
            missingFields = @($missing.ToArray())
            hasFrontmatter = [bool]$front.hasFrontmatter
            status = $status
            confidence = $confidence
            source_path = $sourcePath
            reason = $(if ($isObsidianState) { ".obsidian state is not allowed in primary source surface" } elseif (-not $front.hasFrontmatter) { "missing frontmatter" } elseif ($missing.Count -gt 0) { "missing required metadata" } elseif (-not $statusOk) { "invalid status" } elseif (-not $confidenceOk) { "invalid confidence" } else { "unknown" })
        }) | Out-Null
    }
    $notes.Add([ordered]@{
        path = Normalize-PathText $path
        title = $title
        status = $status
        owner = $owner
        updated_at = $updatedAt
        source_path = $sourcePath
        confidence = $confidence
        hasFrontmatter = [bool]$front.hasFrontmatter
        contentHash = $fileHash
        eligible = [bool]$metadataOk
    }) | Out-Null
}

$eligibleCount = @($notes | Where-Object { [bool]$_.eligible }).Count
$missingFrontmatterCount = @($notes | Where-Object { -not [bool]$_.hasFrontmatter }).Count
$blockedCount = $violations.Count
$sourceCoverage = if ($notes.Count -eq 0) { 0 } else { [math]::Round((($eligibleCount / [double]$notes.Count) * 100), 2) }

Add-Check -Checks $checks -Name "scan-roots" -Ok ($markdownFiles.Count -gt 0) -Detail ("roots={0}; files={1}" -f $targetList.Count, $markdownFiles.Count)
Add-Check -Checks $checks -Name "frontmatter-coverage" -Ok ($blockedCount -eq 0) -Detail ("missingFrontmatter={0}; blocked={1}" -f $missingFrontmatterCount, $blockedCount)
Add-Check -Checks $checks -Name "source-path-coverage" -Ok ($sourceCoverage -eq 100) -Detail ("coverage={0}%" -f $sourceCoverage)
Add-Check -Checks $checks -Name "eligible-notes" -Ok ($eligibleCount -gt 0) -Detail ("eligible={0}" -f $eligibleCount)

$verdict = if (@($checks | Where-Object { -not [bool]$_.ok }).Count -eq 0) { "PASS" } else { "FAIL" }
$latestJsonPath = Join-Path $OutDir "memory-source-contract-check-latest.json"
$latestMdPath = Join-Path $OutDir "memory-source-contract-check-latest.md"
$report = [ordered]@{
    machineTag = "MEMORY_SOURCE_CONTRACT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    verdict = $verdict
    pass = ($verdict -eq "PASS")
    targetPaths = @($targetList)
    noteCount = [int]$notes.Count
    eligibleCount = [int]$eligibleCount
    blockedCount = [int]$blockedCount
    sourcePathCoverage = $sourceCoverage
    notes = @($notes.ToArray())
    violations = @($violations.ToArray())
    checks = @($checks.ToArray())
    evidencePath = "docs/治理/最新态/memory-source-contract-check-latest.json"
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action memory-ingest-plan -Task `"$Task`" -Strict"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($report | ConvertTo-Json -Depth 20)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Memory Source Contract Check") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- verdict: {0}" -f $report.verdict)) | Out-Null
$md.Add(("- noteCount: {0}" -f $report.noteCount)) | Out-Null
$md.Add(("- eligibleCount: {0}" -f $report.eligibleCount)) | Out-Null
$md.Add(("- sourcePathCoverage: {0}%" -f $report.sourcePathCoverage)) | Out-Null
$md.Add("") | Out-Null
$md.Add("## Checks") | Out-Null
foreach ($item in @($checks.ToArray())) {
    $md.Add(("- {0}: {1} ({2})" -f $item.name, $(if ([bool]$item.ok) { "PASS" } else { "FAIL" }), $item.detail)) | Out-Null
}
$md.Add("") | Out-Null
$md.Add("## Violations") | Out-Null
if ($violations.Count -eq 0) {
    $md.Add("- none") | Out-Null
}
else {
    foreach ($item in @($violations.ToArray())) {
        $md.Add(("- {0}: {1}" -f $item.path, $item.reason)) | Out-Null
    }
}
$md.Add("") | Out-Null
$md.Add("## Next") | Out-Null
$md.Add(("- {0}" -f $report.nextCommand)) | Out-Null
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())))

if ($Json) { $report | ConvertTo-Json -Depth 20 }
else { Write-Host ("memory-source-contract-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($verdict -eq "PASS") { "Green" } else { "Red" }) }

if ($Strict -and $verdict -ne "PASS") { exit 1 }
