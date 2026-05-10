[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "memory-briefing",
    [string]$TargetPaths = "",
    [string]$EvidencePaths = "",
    [string]$SuggestionId = "",
    [string]$IssueId = "",
    [string]$ProgressId = "",
    [string]$RecentSection = "",
    [ValidateSet("Staged", "All")]
    [string]$Mode = "Staged",
    [string]$GateProfile = "Fast",
    [string]$OutDir = "docs/治理/最新态",
    [string]$ContractPath = "docs/memory-layer.md",
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
    Param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    return @($Value -split "[;,]" | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Read-JsonFileOrNull {
    Param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Get-PrimaryReviewSignal {
    Param(
        [string[]]$CandidatePaths,
        [string]$TaskName
    )
    foreach ($candidate in @($CandidatePaths)) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $doc = Read-JsonFileOrNull -Path $candidate
        if ($null -eq $doc) { continue }
        return [ordered]@{
            path = Normalize-PathText $candidate
            verdict = [string]$doc.verdict
            taskClass = [string]$doc.taskClass
            intentType = [string]$doc.intentType
            task = [string]$doc.task
            reviewRunId = [string]$doc.reviewRunId
        }
    }
    return [ordered]@{
        path = "N/A"
        verdict = "OBSERVE"
        taskClass = "N/A"
        intentType = "N/A"
        task = $TaskName
        reviewRunId = "N/A"
    }
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$targetPathList = @(Split-PackedList -Value $TargetPaths)
$evidencePathList = @(Split-PackedList -Value $EvidencePaths)
$contractFullPath = if ([System.IO.Path]::IsPathRooted($ContractPath)) { $ContractPath } else { Join-Path $repoRoot $ContractPath }
$briefingJsonPath = Join-Path $OutDir "memory-briefing-latest.json"
$briefingMdPath = Join-Path $OutDir "memory-briefing-latest.md"

if (-not (Test-Path -LiteralPath $contractFullPath -PathType Leaf)) {
    throw ("memory-briefing requires contract file: {0}" -f $ContractPath)
}

$reviewCandidatePaths = @(
    (Join-Path $OutDir "review-memory-replay-latest.json"),
    (Join-Path $OutDir "review-intent-route-latest.json"),
    (Join-Path $OutDir "review-memory-latest.json"),
    (Join-Path $OutDir "review-intelligence-report-latest.json")
)

$primaryReviewSignal = Get-PrimaryReviewSignal -CandidatePaths $reviewCandidatePaths -TaskName $Task

$layerDefinitions = @(
    [ordered]@{
        layer = "identity"
        loadOrder = 1
        purpose = "Stable operator preferences, repository safety rules, and long-lived collaboration contracts."
        sourcePaths = @(
            (Normalize-PathText (Join-Path $repoRoot "README.md")),
            (Normalize-PathText (Join-Path $repoRoot "docs/concepts.md"))
        )
        notes = @("Read-only context; never a runtime state authority.")
    },
    [ordered]@{
        layer = "project"
        loadOrder = 2
        purpose = "Adopter project boundaries, policy bundle, rollout profile, and compatibility contract."
        sourcePaths = @(
            (Normalize-PathText (Join-Path $repoRoot "policies/rccp-project-contract.json")),
            (Normalize-PathText (Join-Path $repoRoot "policies/rccp-policy-bundle.json")),
            (Normalize-PathText (Join-Path $repoRoot "docs/policy-authoring.md"))
        )
        notes = @("Project adapters extend RCCP without changing the reusable core.")
    },
    [ordered]@{
        layer = "task"
        loadOrder = 3
        purpose = "Current scoped task, target paths, evidence paths, and admission constraints."
        sourcePaths = @(
            (Normalize-PathText (Join-Path $repoRoot "docs/治理/策略/rccp-entry-dispatch.json")),
            (Normalize-PathText (Join-Path $repoRoot "policies/rccp-entry-dispatch.json"))
        )
        notes = @("Use the task-scoped target list before loading broad repository context.")
    },
    [ordered]@{
        layer = "review"
        loadOrder = 4
        purpose = "Latest review, route, and memory evidence that can inform but not replace gates."
        sourcePaths = @(
            (Normalize-PathText (Join-Path $OutDir "review-memory-replay-latest.json")),
            (Normalize-PathText (Join-Path $OutDir "review-intent-route-latest.json")),
            (Normalize-PathText (Join-Path $OutDir "review-memory-latest.json")),
            (Normalize-PathText (Join-Path $OutDir "review-intelligence-report-latest.json"))
        )
        notes = @("Review signals are advisory; closeout and ownership remain authoritative.")
    },
    [ordered]@{
        layer = "evolution"
        loadOrder = 5
        purpose = "Rule evolution, release readiness, evidence model, and retired-entrypoint boundaries."
        sourcePaths = @(
            (Normalize-PathText $contractFullPath),
            (Normalize-PathText (Join-Path $repoRoot "docs/evidence.md")),
            (Normalize-PathText (Join-Path $repoRoot "docs/release-checklist.md")),
            (Normalize-PathText (Join-Path $repoRoot "policies/retired-entrypoints.json"))
        )
        notes = @("Evolution records durable changes only; do not import source-project private history.")
    }
)

$sourcePaths = New-Object System.Collections.Generic.List[string]
foreach ($item in @($layerDefinitions)) {
    foreach ($path in @($item.sourcePaths)) {
        if ([string]::IsNullOrWhiteSpace([string]$path)) { continue }
        if (-not $sourcePaths.Contains([string]$path)) { $sourcePaths.Add([string]$path) | Out-Null }
    }
}
foreach ($path in @($targetPathList + $evidencePathList)) {
    $normalized = Normalize-PathText $path
    if (-not [string]::IsNullOrWhiteSpace($normalized) -and -not $sourcePaths.Contains($normalized)) {
        $sourcePaths.Add($normalized) | Out-Null
    }
}

$reviewRunToken = [string]$primaryReviewSignal.reviewRunId
if ([string]::IsNullOrWhiteSpace($reviewRunToken) -or $reviewRunToken -eq "N/A") {
    $reviewRunToken = (Get-Date).ToString("yyyyMMddHHmmss")
}
else {
    $reviewRunToken = $reviewRunToken.Replace("RIR-", "")
    $reviewRunToken = ($reviewRunToken -replace "[^0-9A-Za-z]", "")
    if ([string]::IsNullOrWhiteSpace($reviewRunToken)) {
        $reviewRunToken = (Get-Date).ToString("yyyyMMddHHmmss")
    }
}
if ($reviewRunToken.Length -gt 8) { $reviewRunToken = $reviewRunToken.Substring(0, 8) }

$briefingId = "MBR-" + (Get-Date).ToString("yyyyMMddHHmmss") + "-" + $reviewRunToken
$briefing = [ordered]@{
    machineTag = "MEMORY_BRIEFING_V1"
    briefingId = $briefingId
    task = $Task
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    mode = $Mode
    gateProfile = $GateProfile
    sourcePaths = @($sourcePaths.ToArray())
    targetPaths = @($targetPathList)
    evidencePaths = @($evidencePathList)
    contractPath = Normalize-PathText $contractFullPath
    layerDefinitions = @($layerDefinitions)
    primaryReviewSignal = $primaryReviewSignal
    contractExcerpt = @(
        "Memory briefing is a read-only load-order aid.",
        "The default load order is identity, project, task, review, evolution.",
        "Runtime state, ownership, and closeout evidence remain the source of truth."
    )
    verdict = "PASS"
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action rccp-leaf-contract-check -Task `"$Task`" -ActionName memory-briefing -Strict"
    evidencePath = Normalize-PathText $briefingJsonPath
}

Write-Utf8NoBom -Path $briefingJsonPath -Content ($briefing | ConvertTo-Json -Depth 20)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Memory Briefing") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(("- briefingId: {0}" -f $briefing.briefingId)) | Out-Null
$lines.Add(("- task: {0}" -f $briefing.task)) | Out-Null
$lines.Add(("- verdict: {0}" -f $briefing.verdict)) | Out-Null
$lines.Add(("- reviewSignal: {0}/{1}" -f $briefing.primaryReviewSignal.intentType, $briefing.primaryReviewSignal.verdict)) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Load Order") | Out-Null
foreach ($layer in @($layerDefinitions)) {
    $lines.Add(("- {0} | order={1} | {2}" -f $layer.layer, $layer.loadOrder, $layer.purpose)) | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Layer Sources") | Out-Null
foreach ($layer in @($layerDefinitions)) {
    $lines.Add(("- {0}" -f $layer.layer)) | Out-Null
    foreach ($path in @($layer.sourcePaths)) { $lines.Add(("  - {0}" -f $path)) | Out-Null }
}
$lines.Add("") | Out-Null
$lines.Add("## Contract Excerpt") | Out-Null
foreach ($text in @($briefing.contractExcerpt)) { $lines.Add(("- {0}" -f $text)) | Out-Null }
$lines.Add("") | Out-Null
$lines.Add("## Next") | Out-Null
$lines.Add(("- {0}" -f $briefing.nextCommand)) | Out-Null
Write-Utf8NoBom -Path $briefingMdPath -Content ([string]::Join("`n", @($lines)))

if ($Json) { $briefing | ConvertTo-Json -Depth 20 }
else { Write-Host ("memory-briefing completed: verdict={0}, latest='{1}'" -f $briefing.verdict, $briefingJsonPath) -ForegroundColor Green }
