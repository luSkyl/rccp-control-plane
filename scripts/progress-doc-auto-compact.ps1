[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "progress-doc-auto-compact",
    [string]$RunMode = "task-start",
    [string]$OutDir = "docs/治理/最新态",
    [switch]$ForceWhenTriggered,
    [switch]$HardFailOnUnresolved,
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

function Get-TextLines {
    Param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $text = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
    return @($text -split "`r?`n")
}

function Resolve-WorkspaceRoot {
    Param(
        [Parameter(Mandatory = $true)][string]$StartDir,
        [string[]]$SentinelFiles = @("task_plan.md", "progress.md", "findings.md")
    )
    $current = (Resolve-Path -LiteralPath $StartDir).Path
    while ($true) {
        foreach ($file in @($SentinelFiles)) {
            if (Test-Path -LiteralPath (Join-Path $current $file) -PathType Leaf) {
                return $current
            }
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or [string]::Equals($parent, $current, [System.StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $current = $parent
    }
    return ""
}

function Get-NonEmptyTail {
    Param(
        [string[]]$Lines,
        [int]$Count = 12
    )
    $tail = New-Object System.Collections.Generic.List[string]
    foreach ($line in @($Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $tail.Add([string]$line) | Out-Null
    }
    $items = @($tail.ToArray())
    if ($items.Count -le $Count) { return $items }
    return @($items[($items.Count - $Count)..($items.Count - 1)])
}

$repoRoot = Resolve-WorkspaceRoot -StartDir $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$taskPlanPath = "task_plan.md"
$findingsPath = "findings.md"
$progressPath = "progress.md"

$taskPlanLines = @(Get-TextLines -Path $taskPlanPath)
$findingsLines = @(Get-TextLines -Path $findingsPath)
$progressLines = @(Get-TextLines -Path $progressPath)

$blockingFailures = New-Object System.Collections.Generic.List[string]
$waivedArtifacts = New-Object System.Collections.Generic.List[string]
if ($taskPlanLines.Count -eq 0) { $waivedArtifacts.Add(("MISSING_TASK_PLAN: {0}" -f $taskPlanPath)) | Out-Null }
if ($findingsLines.Count -eq 0) { $waivedArtifacts.Add(("MISSING_FINDINGS: {0}" -f $findingsPath)) | Out-Null }
if ($progressLines.Count -eq 0) { $waivedArtifacts.Add(("MISSING_PROGRESS: {0}" -f $progressPath)) | Out-Null }

$openMarkers = New-Object System.Collections.Generic.List[string]
foreach ($line in @($taskPlanLines)) {
    if ($line -match '^\s*-\s+\[(pending|in_progress)\]') {
        $openMarkers.Add($line.Trim()) | Out-Null
    }
}

if ($HardFailOnUnresolved -and $openMarkers.Count -gt 0) {
    $blockingFailures.Add(("UNRESOLVED_PLAN_ITEMS: {0}" -f [string]::Join(" || ", @($openMarkers.ToArray())))) | Out-Null
}

$pass = ($blockingFailures.Count -eq 0)
$latestJsonPath = Join-Path $OutDir "progress-doc-auto-compact-latest.json"
$latestMdPath = Join-Path $OutDir "progress-doc-auto-compact-latest.md"

$payload = [ordered]@{
    machineTag = "RCCP_PROGRESS_DOC_AUTO_COMPACT_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    runMode = [string]$RunMode
    pass = [bool]$pass
    semanticPass = [bool]$pass
    forceWhenTriggered = [bool]$ForceWhenTriggered
    hardFailOnUnresolved = [bool]$HardFailOnUnresolved
    taskPlanPath = $taskPlanPath
    findingsPath = $findingsPath
    progressPath = $progressPath
    taskPlanLineCount = [int]$taskPlanLines.Count
    findingsLineCount = [int]$findingsLines.Count
    progressLineCount = [int]$progressLines.Count
    waivedArtifacts = @($waivedArtifacts.ToArray())
    openMarkers = @($openMarkers.ToArray())
    taskPlanTail = @(Get-NonEmptyTail -Lines $taskPlanLines -Count 12)
    findingsTail = @(Get-NonEmptyTail -Lines $findingsLines -Count 12)
    progressTail = @(Get-NonEmptyTail -Lines $progressLines -Count 12)
    blockingFailures = @($blockingFailures.ToArray())
    evidencePath = "docs/治理/最新态/progress-doc-auto-compact-latest.json"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)
$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Progress Doc Auto Compact") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- task: {0}" -f $Task)) | Out-Null
$md.Add(("- runMode: {0}" -f $RunMode)) | Out-Null
$md.Add(("- pass: {0}" -f [bool]$pass)) | Out-Null
$md.Add(("- openMarkers: {0}" -f $openMarkers.Count)) | Out-Null
if ($waivedArtifacts.Count -gt 0) {
    $md.Add(("- waivedArtifacts: {0}" -f $waivedArtifacts.Count)) | Out-Null
}
if ($blockingFailures.Count -gt 0) {
    $md.Add("") | Out-Null
    $md.Add("## Blocking Failures") | Out-Null
    foreach ($item in @($blockingFailures.ToArray())) {
        $md.Add(("- {0}" -f $item)) | Out-Null
    }
}
if ($waivedArtifacts.Count -gt 0) {
    $md.Add("") | Out-Null
    $md.Add("## Waived Artifacts") | Out-Null
    foreach ($item in @($waivedArtifacts.ToArray())) {
        $md.Add(("- {0}" -f $item)) | Out-Null
    }
}
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())))

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("progress-doc-auto-compact completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
