[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "existing-capability-probe",
    [string]$Why = "",
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

$whyText = [string]$Why
$deltaRequested = ($whyText -match "方案|完善|根因|优化|已有|为什么|完美|existing|capability|delta")
$evidenceCandidates = @(
    "docs/治理/最新态/action-registry-check-latest.json",
    "docs/治理/最新态/memory-layer-contract-latest.json",
    "docs/治理/最新态/rccp-thin-entry-check-latest.json"
)
$existingEvidence = @($evidenceCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
$verdict = if ($deltaRequested -and $existingEvidence.Count -gt 0) { "DELTA_ANSWER_REQUIRED" } elseif ($existingEvidence.Count -gt 0) { "EXISTING_CAPABILITY_CONFIRMED" } else { "GREENFIELD_ALLOWED" }

$latestJsonPath = Join-Path $OutDir "existing-capability-probe-latest.json"
$latestMdPath = Join-Path $OutDir "existing-capability-probe-latest.md"
$payload = [ordered]@{
    machineTag = "EXISTING_CAPABILITY_PROBE_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    why = $whyText
    verdict = $verdict
    evidencePaths = @($existingEvidence)
    reason = "Repository evidence exists; answer should describe delta from current control-plane capability rather than propose a greenfield design."
    requiredAnswerShape = @(
        "existing implementation confirmation",
        "current residual symptom",
        "why existing mechanism did not stop it",
        "root-cause evidence path",
        "minimal repair action",
        "verification evidence and acceptance gate"
    )
    evidencePath = "docs/治理/最新态/existing-capability-probe-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

$lines = @(
    "# Existing Capability Probe",
    "",
    ("- task: {0}" -f $payload.task),
    ("- verdict: {0}" -f $payload.verdict),
    ("- evidenceCount: {0}" -f $existingEvidence.Count),
    "",
    "## Evidence",
    $(if ($existingEvidence.Count -eq 0) { "- none" } else { ($existingEvidence | ForEach-Object { "- $_" }) })
)
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($lines)))

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("existing-capability-probe completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor Green }

if ($Strict -and [string]::Equals($verdict, "BLOCKED_EVIDENCE", [System.StringComparison]::OrdinalIgnoreCase)) { exit 1 }
