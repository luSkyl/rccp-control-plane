[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "rccp-kit-compat-check",
    [string[]]$ProjectConfigPath = @("rccp.project.json"),
    [string]$ContractPath = "docs/治理/策略/rccp-project-contract.json",
    [string]$ProjectRoot = "",
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

$dispatch = Get-Content -LiteralPath "docs/治理/策略/rccp-entry-dispatch.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$bundle = Get-Content -LiteralPath "docs/治理/策略/rccp-policy-bundle.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$contractExists = Test-Path -LiteralPath $ContractPath -PathType Leaf
$canonicalOk = [string]::Equals([string]$dispatch.canonicalEntry, "scripts/rccp/rccp.ps1", [System.StringComparison]::OrdinalIgnoreCase)
$profileOk = -not [string]::IsNullOrWhiteSpace([string]$dispatch.distributionProfile.name)
$bundleOk = [string]::Equals([string]$bundle.canonicalEntry, "scripts/rccp/rccp.ps1", [System.StringComparison]::OrdinalIgnoreCase)
$pass = $canonicalOk -and $profileOk -and $bundleOk -and $contractExists

$latestJsonPath = Join-Path $OutDir "rccp-kit-compat-check-latest.json"
$payload = [ordered]@{
    machineTag = "RCCP_KIT_COMPAT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    pass = [bool]$pass
    distributionProfile = [string]$dispatch.distributionProfile.name
    canonicalEntryOk = [bool]$canonicalOk
    policyBundleOk = [bool]$bundleOk
    projectContractExists = [bool]$contractExists
    evidencePath = "docs/治理/最新态/rccp-kit-compat-check-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("rccp-kit-compat-check completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
