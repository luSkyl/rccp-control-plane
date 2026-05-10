[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "rccp-kit-rollout-check",
    [string[]]$ProjectConfigPath = @("rccp.project.json"),
    [string]$ContractPath = "docs/治理/策略/rccp-project-contract.json",
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

$requiredEvidence = @(
    "docs/治理/最新态/action-registry-check-latest.json",
    "docs/治理/最新态/memory-layer-contract-latest.json",
    "docs/治理/最新态/rccp-thin-entry-check-latest.json"
)
$presentEvidence = @($requiredEvidence | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
$pass = ($presentEvidence.Count -eq $requiredEvidence.Count)

$latestJsonPath = Join-Path $OutDir "rccp-kit-rollout-check-latest.json"
$payload = [ordered]@{
    machineTag = "RCCP_KIT_ROLLOUT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    pass = [bool]$pass
    requiredEvidence = @($requiredEvidence)
    presentEvidence = @($presentEvidence)
    evidencePath = "docs/治理/最新态/rccp-kit-rollout-check-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("rccp-kit-rollout-check completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
