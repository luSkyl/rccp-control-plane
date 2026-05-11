[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "existing-capability-probe",
    [string]$Why = "",
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

function Join-TermPattern {
    Param([Parameter(Mandatory = $true)][string[]]$Terms)
    return [string]::Join("|", $Terms)
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
$governanceDir = ConvertFrom-CodePoints @(0x6cbb, 0x7406)
$latestDir = ConvertFrom-CodePoints @(0x6700, 0x65b0, 0x6001)
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path (Join-Path "docs" $governanceDir) $latestDir }
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$whyText = [string]$Why
$deltaPattern = Join-TermPattern @(
    "existing", "capability", "delta", "root cause", "why", "optimize", "perfect",
    (ConvertFrom-CodePoints @(0x65b9, 0x6848)),
    (ConvertFrom-CodePoints @(0x5b8c, 0x5584)),
    (ConvertFrom-CodePoints @(0x6839, 0x56e0)),
    (ConvertFrom-CodePoints @(0x4f18, 0x5316)),
    (ConvertFrom-CodePoints @(0x5df2, 0x6709)),
    (ConvertFrom-CodePoints @(0x4e3a, 0x4ec0, 0x4e48)),
    (ConvertFrom-CodePoints @(0x5b8c, 0x7f8e)),
    (ConvertFrom-CodePoints @(0x6700, 0x4f18)),
    (ConvertFrom-CodePoints @(0x6700, 0x4f73))
)
$externalPattern = Join-TermPattern @(
    "GitHub", "github", "open source", "external", "industry", "best practice", "v2", "V2", "v3", "V3",
    (ConvertFrom-CodePoints @(0x5916, 0x90e8)),
    (ConvertFrom-CodePoints @(0x884c, 0x4e1a)),
    (ConvertFrom-CodePoints @(0x6700, 0x4f73, 0x5b9e, 0x8df5))
)
$greenfieldPattern = Join-TermPattern @(
    "greenfield", "redesign", "from scratch", "v3", "V3",
    (ConvertFrom-CodePoints @(0x4ece, 0x96f6)),
    (ConvertFrom-CodePoints @(0x91cd, 0x6784)),
    (ConvertFrom-CodePoints @(0x91cd, 0x65b0, 0x8bbe, 0x8ba1)),
    (ConvertFrom-CodePoints @(0x7a81, 0x7834, 0x73b0, 0x6709))
)
$layeredPattern = Join-TermPattern @(
    "perfect", "optimal", "best", "v1", "V1", "v2", "V2", "v3", "V3", "GitHub", "github", "greenfield", "redesign",
    (ConvertFrom-CodePoints @(0x5b8c, 0x7f8e)),
    (ConvertFrom-CodePoints @(0x6700, 0x4f18)),
    (ConvertFrom-CodePoints @(0x6700, 0x4f73))
)
$negativeAuthorizationPattern = Join-TermPattern @(
    "without authorization", "not authorized", "unauthorized", "not allowed", "disallow",
    (ConvertFrom-CodePoints @(0x672a, 0x6388, 0x6743)),
    (ConvertFrom-CodePoints @(0x4e0d, 0x6388, 0x6743)),
    (ConvertFrom-CodePoints @(0x6ca1, 0x6709, 0x6388, 0x6743)),
    (ConvertFrom-CodePoints @(0x672a, 0x5141, 0x8bb8)),
    (ConvertFrom-CodePoints @(0x4e0d, 0x5141, 0x8bb8))
)

$negativeAuthorizationRequested = ($whyText -match $negativeAuthorizationPattern)
$deltaRequested = ($whyText -match $deltaPattern)
$externalReferenceRequested = ($whyText -match $externalPattern)
$greenfieldExplicitlyRequested = ($whyText -match $greenfieldPattern)
$layeredProtocolRequested = ($whyText -match $layeredPattern)
if ($negativeAuthorizationRequested) {
    $externalReferenceRequested = $false
    $greenfieldExplicitlyRequested = $false
}

$evidenceCandidates = @(
    (Join-Path $OutDir "action-registry-check-latest.json"),
    (Join-Path $OutDir "memory-layer-contract-latest.json"),
    (Join-Path $OutDir "rccp-thin-entry-check-latest.json")
)
$existingEvidence = @($evidenceCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
$verdict = if ($greenfieldExplicitlyRequested) { "GREENFIELD_ALLOWED" } elseif ($deltaRequested -and $existingEvidence.Count -gt 0) { "DELTA_ANSWER_REQUIRED" } elseif ($existingEvidence.Count -gt 0) { "EXISTING_CAPABILITY_CONFIRMED" } else { "GREENFIELD_ALLOWED" }
$recommendedResponseMode = if ($greenfieldExplicitlyRequested) { "V1_V2_V3_GREENFIELD_AUTHORIZED" } elseif ($externalReferenceRequested) { "V1_DELTA_PLUS_V2_EXTERNAL_AUTHORIZED" } elseif ($layeredProtocolRequested) { "V1_DELTA_WITH_V2_V3_PLACEHOLDERS" } else { "STANDARD_DELTA" }
$reason = if ($greenfieldExplicitlyRequested) {
    "Explicit greenfield/redesign authorization was detected; answer may include v3 redesign, while preserving current repository evidence and migration gates."
} elseif ($externalReferenceRequested) {
    "External reference authorization was detected; answer should keep v1 repository delta first, then add v2 external/GitHub comparison without skipping evidence."
} elseif ($existingEvidence.Count -gt 0) {
    "Repository evidence exists; answer should describe delta from current control-plane capability rather than propose a greenfield design."
} else {
    "No repository evidence was found; greenfield design is allowed."
}

$latestJsonPath = Join-Path $OutDir "existing-capability-probe-latest.json"
$latestMdPath = Join-Path $OutDir "existing-capability-probe-latest.md"
$payload = [ordered]@{
    machineTag = "EXISTING_CAPABILITY_PROBE_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    why = $whyText
    verdict = $verdict
    evidencePaths = @($existingEvidence)
    reason = $reason
    requestSignals = [ordered]@{
        deltaRequested = [bool]$deltaRequested
        negativeAuthorizationRequested = [bool]$negativeAuthorizationRequested
        externalReferenceRequested = [bool]$externalReferenceRequested
        greenfieldExplicitlyRequested = [bool]$greenfieldExplicitlyRequested
        layeredProtocolRequested = [bool]$layeredProtocolRequested
    }
    recommendedResponseMode = $recommendedResponseMode
    recommendedResponseLayers = @(
        "v1 repository delta / minimal repair",
        "v2 external or GitHub enhancement only when authorized",
        "v3 greenfield or broad redesign only when explicitly authorized"
    )
    requiredAnswerShape = @(
        "existing implementation confirmation",
        "current residual symptom",
        "why existing mechanism did not stop it",
        "root-cause evidence path",
        "minimal repair action",
        "verification evidence and acceptance gate"
    )
    evidencePath = $latestJsonPath
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

$lines = @(
    "# Existing Capability Probe",
    "",
    ("- task: {0}" -f $payload.task),
    ("- verdict: {0}" -f $payload.verdict),
    ("- recommendedResponseMode: {0}" -f $payload.recommendedResponseMode),
    ("- evidenceCount: {0}" -f $existingEvidence.Count),
    "",
    "## Evidence",
    $(if ($existingEvidence.Count -eq 0) { "- none" } else { ($existingEvidence | ForEach-Object { "- $_" }) })
)
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($lines)))

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("existing-capability-probe completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor Green }

if ($Strict -and [string]::Equals($verdict, "BLOCKED_EVIDENCE", [System.StringComparison]::OrdinalIgnoreCase)) { exit 1 }