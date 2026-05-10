[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "project-governance-check",
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

function Read-JsonFile {
    Param([string]$Path)
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$dispatchPath = Join-Path $repoRoot "docs/治理/策略/rccp-entry-dispatch.json"
$policyPath = Join-Path $repoRoot "policies/rccp-entry-dispatch.json"
$dispatch = Read-JsonFile -Path $dispatchPath
$policy = Read-JsonFile -Path $policyPath
$required = @($dispatch.distributionProfile.requiredLeafActions | ForEach-Object { [string]$_ })
$missingRequired = @($required | Where-Object {
    $target = [string]$dispatch.entryDispatch.$_
    [string]::IsNullOrWhiteSpace($target) -or -not (Test-Path -LiteralPath (Join-Path $repoRoot $target) -PathType Leaf)
})
$mirrorText = (($dispatch | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
$policyText = (($policy | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
$pass = ($missingRequired.Count -eq 0) -and [string]::Equals($mirrorText, $policyText, [System.StringComparison]::Ordinal)

$latestJsonPath = Join-Path $OutDir "project-governance-check-latest.json"
$payload = [ordered]@{
    machineTag = "RCCP_PROJECT_GOVERNANCE_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    pass = [bool]$pass
    distributionProfile = [string]$dispatch.distributionProfile.name
    requiredLeafActionCount = [int]$required.Count
    missingRequiredActions = @($missingRequired)
    dispatchMirror = [bool][string]::Equals($mirrorText, $policyText, [System.StringComparison]::Ordinal)
    evidencePath = "docs/治理/最新态/project-governance-check-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("project-governance-check completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
