[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "existing-capability-answer-shape-check",
    [string]$Why = "",
    [string]$AnswerText = "",
    [string]$AnswerPath = "",
    [string]$OutDir = "docs/治理/最新态",
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

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$answer = [string]$AnswerText
if (-not [string]::IsNullOrWhiteSpace($AnswerPath)) {
    $resolvedAnswerPath = if ([System.IO.Path]::IsPathRooted($AnswerPath)) { $AnswerPath } else { Join-Path $repoRoot $AnswerPath }
    if (Test-Path -LiteralPath $resolvedAnswerPath -PathType Leaf) {
        $answer = Get-Content -LiteralPath $resolvedAnswerPath -Encoding UTF8 -Raw
    }
}

$requirements = [ordered]@{
    existingImplementation = "现有|已实现|current|existing"
    residualSymptom = "残余|当前|symptom|缺口|问题"
    rootCause = "根因|root cause|原因"
    minimalRepair = "修复|repair|action|落地"
    verification = "验证|门禁|evidence|acceptance|PASS"
}

$missing = New-Object System.Collections.Generic.List[string]
foreach ($item in $requirements.GetEnumerator()) {
    if ($answer -notmatch $item.Value) { $missing.Add([string]$item.Key) | Out-Null }
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
    evidencePath = "docs/治理/最新态/existing-capability-answer-shape-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @("# Existing Capability Answer Shape Check", "", "- verdict: $verdict", "- missingSections: $($missing.Count)")))

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("existing-capability-answer-shape-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($missing.Count -eq 0) { "Green" } else { "Red" }) }

if ($Strict -and $missing.Count -gt 0) { exit 1 }
