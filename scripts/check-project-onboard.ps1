[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "project-onboard",
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

$projectRootResolved = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $repoRoot } elseif ([System.IO.Path]::IsPathRooted($ProjectRoot)) { $ProjectRoot } else { Join-Path $repoRoot $ProjectRoot }
$contractExists = Test-Path -LiteralPath (Join-Path $repoRoot $ContractPath) -PathType Leaf
$configPaths = @($ProjectConfigPath | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$existingConfigs = @($configPaths | Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot $_) -PathType Leaf })
$pass = (Test-Path -LiteralPath $projectRootResolved -PathType Container) -and $contractExists

$latestJsonPath = Join-Path $OutDir "project-onboard-latest.json"
$payload = [ordered]@{
    machineTag = "RCCP_PROJECT_ONBOARD_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    pass = [bool]$pass
    projectRoot = $projectRootResolved.Replace("\", "/")
    projectConfigPaths = @($configPaths)
    existingProjectConfigPaths = @($existingConfigs)
    contractPath = $ContractPath
    contractExists = [bool]$contractExists
    distribution = "staging-extraction"
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action project-governance-check -Task `"$Task`" -Strict"
    evidencePath = "docs/治理/最新态/project-onboard-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("project-onboard completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
