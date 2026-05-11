[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "docs-only-contract-check",
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
    "docs/adapters/docs-only.md",
    "adapters/docs-only.json",
    "examples/docs-only-repo/README.md",
    "scripts/check-docs-only-contract.ps1"
)
foreach ($path in @($requiredFiles)) {
    Add-Check -Checks $checks -Name ("file-present:{0}" -f $path) -Ok (Test-Path -LiteralPath $path -PathType Leaf) -Detail $path
}

$guide = Read-Text -Path "docs/adapters/docs-only.md"
$manifest = Get-Content -LiteralPath "adapters/docs-only.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$example = Read-Text -Path "examples/docs-only-repo/README.md"
$readme = Read-Text -Path "README.md"
$releaseChecklist = Read-Text -Path "docs/release-checklist.md"
$ciWorkflow = Read-Text -Path ".github/workflows/rccp-ci.yml"

Add-Check -Checks $checks -Name "guide-contract" -Ok (Test-ContainsAll -Text $guide -Terms @("Docs-Only Adapter Pack", "Markdown", "policy", "documentation")) -Detail "guide names docs-only boundary"
Add-Check -Checks $checks -Name "manifest-contract" -Ok (
    [string]::Equals([string]$manifest.packId, "docs-only", [System.StringComparison]::OrdinalIgnoreCase) -and
    [string]::Equals([string]$manifest.manifestPath, "adapters/docs-only.json", [System.StringComparison]::OrdinalIgnoreCase) -and
    [string]::Equals([string]$manifest.checkScriptPath, "scripts/check-docs-only-contract.ps1", [System.StringComparison]::OrdinalIgnoreCase)
) -Detail "pack manifest points to the docs-only pack surface"
Add-Check -Checks $checks -Name "example-contract" -Ok (Test-ContainsAll -Text $example -Terms @("Docs-Only RCCP Adopter", "docs governance", "release readiness")) -Detail "example repo shows docs-only pack shape"
$releaseSurfaceOk = $true
$releaseSurfaceDetail = "source surface files absent in installed bundle; release-surface link check skipped"
if ((Test-Path -LiteralPath "README.md" -PathType Leaf) -and (Test-Path -LiteralPath "docs/release-checklist.md" -PathType Leaf) -and (Test-Path -LiteralPath ".github/workflows/rccp-ci.yml" -PathType Leaf)) {
    $releaseSurfaceOk = (
        (Test-ContainsAll -Text $readme -Terms @("docs-only-contract-check", "Docs-Only")) -and
        (Test-ContainsAll -Text $releaseChecklist -Terms @("docs-only-contract-check")) -and
        (Test-ContainsAll -Text $ciWorkflow -Terms @("docs-only-contract-check"))
    )
    $releaseSurfaceDetail = "README, release checklist, and CI surface the docs-only pack check"
}
Add-Check -Checks $checks -Name "release-surface-links" -Ok $releaseSurfaceOk -Detail $releaseSurfaceDetail

$failureCount = @($checks.ToArray() | Where-Object { -not [bool]$_.ok }).Count
$verdict = if ($failureCount -gt 0) { "FAIL" } else { "PASS" }
$latestJsonPath = Join-Path $OutDir "docs-only-contract-check-latest.json"
$payload = [ordered]@{
    machineTag = "RCCP_DOCS_ONLY_CONTRACT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    verdict = [string]$verdict
    pass = ($failureCount -eq 0)
    failureCount = [int]$failureCount
    requiredFiles = @($requiredFiles)
    checks = @($checks.ToArray())
    evidencePath = "docs/治理/最新态/docs-only-contract-check-latest.json"
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action docs-only-contract-check -Task `"$Task`" -Strict"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 20)
if ($Json) { $payload | ConvertTo-Json -Depth 20 } else { Write-Host ("docs-only-contract-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Red" }) }
if ($Strict -and $failureCount -gt 0) { exit 1 }
