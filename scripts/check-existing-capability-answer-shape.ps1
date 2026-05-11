[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "existing-capability-answer-shape-check",
    [string]$Why = "",
    [string]$AnswerText = "",
    [string]$AnswerPath = "",
    [string]$OutDir = "",
    [switch]$Strict,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Utf8NoBom {
    Param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Content)
    $normalized = $Content -replace "`r`n", "`n" -replace "`r", "`n"
    [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false)))
}

function ConvertFrom-CodePoints {
    Param([Parameter(Mandatory = $true)][int[]]$CodePoints)
    return [string]::Concat(($CodePoints | ForEach-Object { [char]$_ }))
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
$governanceDir = ConvertFrom-CodePoints @(0x6cbb, 0x7406)
$latestDir = ConvertFrom-CodePoints @(0x6700, 0x65b0, 0x6001)
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path (Join-Path "docs" $governanceDir) $latestDir }
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$answer = [string]$AnswerText
if (-not [string]::IsNullOrWhiteSpace($AnswerPath)) {
    $resolvedAnswerPath = if ([System.IO.Path]::IsPathRooted($AnswerPath)) { $AnswerPath } else { Join-Path $repoRoot $AnswerPath }
    if (Test-Path -LiteralPath $resolvedAnswerPath -PathType Leaf) {
        $answer = Get-Content -LiteralPath $resolvedAnswerPath -Encoding UTF8 -Raw
    }
}

$requirements = [ordered]@{
    existingImplementation = "current|existing"
    residualSymptom = "symptom|gap|problem|residual|current"
    rootCause = "root cause|cause|reason"
    minimalRepair = "repair|action|implement|land|minimal"
    verification = "verification|gate|evidence|acceptance|PASS"
}

$missing = New-Object System.Collections.Generic.List[string]
foreach ($item in $requirements.GetEnumerator()) {
    if ($answer -notmatch $item.Value) { $missing.Add([string]$item.Key) | Out-Null }
}

$usesLayeredProtocol = ($answer -match "v1|V1|v2|V2|v3|V3|GitHub|github|greenfield|redesign")
if ($usesLayeredProtocol) {
    $layerRequirements = [ordered]@{
        v1Delta = "v1|V1|minimal|delta|existing|current"
        v2Authorization = "v2|V2|authorized|authorization|GitHub|github|external"
        v3Authorization = "v3|V3|greenfield|redesign|from scratch|explicit"
        rollbackOrRisk = "rollback|risk|migration|cost"
        acceptanceGate = "gate|acceptance|verification|PASS|evidence"
    }
    foreach ($item in $layerRequirements.GetEnumerator()) {
        if ($answer -notmatch $item.Value) { $missing.Add([string]$item.Key) | Out-Null }
    }
}

$verdict = if ($missing.Count -eq 0) { "PASS" } else { "GREENFIELD_ANSWER_REGRESSION" }
$latestJsonPath = Join-Path $OutDir "existing-capability-answer-shape-latest.json"
$latestMdPath = Join-Path $OutDir "existing-capability-answer-shape-latest.md"
$payload = [ordered]@{
    machineTag = "EXISTING_CAPABILITY_ANSWER_SHAPE_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    why = [string]$Why
    verdict = $verdict
    missingSections = @($missing.ToArray())
    usesLayeredProtocol = [bool]$usesLayeredProtocol
    evidencePath = $latestJsonPath
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @("# Existing Capability Answer Shape Check", "", "- verdict: $verdict", "- missingSections: $($missing.Count)", "- usesLayeredProtocol: $usesLayeredProtocol")))

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("existing-capability-answer-shape-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($missing.Count -eq 0) { "Green" } else { "Red" }) }

if ($Strict -and $missing.Count -gt 0) { exit 1 }