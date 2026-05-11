[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "ai-context-gateway-contract-check",
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

function Read-Text {
    Param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
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

function Test-ContainsAll {
    Param([string]$Text, [string[]]$Terms)
    foreach ($term in @($Terms)) {
        if ([string]::IsNullOrWhiteSpace($term)) { continue }
        if ($Text.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    }
    return $true
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$checks = New-Object System.Collections.Generic.List[object]
$requiredFiles = @(
    "docs/adapters/ai-context-gateway.md",
    "adapters/ai-context-gateway.json",
    "examples/ai-context-gateway-repo/README.md",
    "examples/ai-context-gateway-repo/eval-cases/abstain-answer.md",
    "examples/ai-context-gateway-repo/eval-cases/context-cases.json",
    "scripts/check-ai-context-gateway-contract.ps1"
)
foreach ($path in @($requiredFiles)) {
    Add-Check -Checks $checks -Name ("file-present:{0}" -f $path) -Ok (Test-Path -LiteralPath $path -PathType Leaf) -Detail $path
}

$guide = Read-Text -Path "docs/adapters/ai-context-gateway.md"
$manifest = Get-Content -LiteralPath "adapters/ai-context-gateway.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$example = Read-Text -Path "examples/ai-context-gateway-repo/README.md"
$abstain = Read-Text -Path "examples/ai-context-gateway-repo/eval-cases/abstain-answer.md"
$cases = Get-Content -LiteralPath "examples/ai-context-gateway-repo/eval-cases/context-cases.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$readme = Read-Text -Path "README.md"
$releaseChecklist = Read-Text -Path "docs/release-checklist.md"
$ciWorkflow = Read-Text -Path ".github/workflows/rccp-ci.yml"

Add-Check -Checks $checks -Name "guide-contract" -Ok (Test-ContainsAll -Text $guide -Terms @("AI Context Gateway", "intent normalization", "template slot fill", "project fact retrieval", "abstain")) -Detail "guide names gateway pipeline and fail-closed behavior"
Add-Check -Checks $checks -Name "manifest-contract" -Ok (
    [string]::Equals([string]$manifest.packId, "ai-context-gateway", [System.StringComparison]::OrdinalIgnoreCase) -and
    [string]::Equals([string]$manifest.manifestPath, "adapters/ai-context-gateway.json", [System.StringComparison]::OrdinalIgnoreCase) -and
    [string]::Equals([string]$manifest.checkScriptPath, "scripts/check-ai-context-gateway-contract.ps1", [System.StringComparison]::OrdinalIgnoreCase)
) -Detail "pack manifest points to the AI context gateway pack surface"
Add-Check -Checks $checks -Name "example-contract" -Ok (
    Test-ContainsAll -Text $example -Terms @("AI Context Gateway RCCP Adopter", "source-backed context", "abstain")
) -Detail "example repo shows fail-closed context assembly"
Add-Check -Checks $checks -Name "abstain-example" -Ok (Test-ContainsAll -Text $abstain -Terms @("Evidence is insufficient to confirm", "Minimal next step")) -Detail "example abstain answer is fail-closed"
Add-Check -Checks $checks -Name "cases-contract" -Ok (@($cases.cases).Count -ge 2) -Detail "example context cases cover grounded and abstain paths"
$releaseSurfaceOk = $true
$releaseSurfaceDetail = "source surface files absent in installed bundle; release-surface link check skipped"
if ((Test-Path -LiteralPath "README.md" -PathType Leaf) -and (Test-Path -LiteralPath "docs/release-checklist.md" -PathType Leaf) -and (Test-Path -LiteralPath ".github/workflows/rccp-ci.yml" -PathType Leaf)) {
    $releaseSurfaceOk = (
        (Test-ContainsAll -Text $readme -Terms @("ai-context-gateway-contract-check", "AI Context Gateway")) -and
        (Test-ContainsAll -Text $releaseChecklist -Terms @("ai-context-gateway-contract-check")) -and
        (Test-ContainsAll -Text $ciWorkflow -Terms @("ai-context-gateway-contract-check"))
    )
    $releaseSurfaceDetail = "README, release checklist, and CI surface the AI context gateway pack check"
}
Add-Check -Checks $checks -Name "release-surface-links" -Ok $releaseSurfaceOk -Detail $releaseSurfaceDetail

$failureCount = @($checks.ToArray() | Where-Object { -not [bool]$_.ok }).Count
$verdict = if ($failureCount -gt 0) { "FAIL" } else { "PASS" }
$latestJsonPath = Join-Path $OutDir "ai-context-gateway-contract-check-latest.json"
$payload = [ordered]@{
    machineTag = "RCCP_AI_CONTEXT_GATEWAY_CONTRACT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    verdict = [string]$verdict
    pass = ($failureCount -eq 0)
    failureCount = [int]$failureCount
    requiredFiles = @($requiredFiles)
    checks = @($checks.ToArray())
    evidencePath = "docs/治理/最新态/ai-context-gateway-contract-check-latest.json"
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action ai-context-gateway-contract-check -Task `"$Task`" -Strict"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 20)
if ($Json) { $payload | ConvertTo-Json -Depth 20 } else { Write-Host ("ai-context-gateway-contract-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Red" }) }
if ($Strict -and $failureCount -gt 0) { exit 1 }
