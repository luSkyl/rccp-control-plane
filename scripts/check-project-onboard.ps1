[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "project-onboard",
    [string[]]$ProjectConfigPath = @("rccp.project.json"),
    [string]$ContractPath = "docs/治理/策略/rccp-project-contract.json",
    [string]$ProjectRoot = "",
    [string]$Profile = "",
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

function Add-Item {
    Param(
        [System.Collections.Generic.List[string]]$Items,
        [string]$Value
    )
    if (-not [string]::IsNullOrWhiteSpace($Value)) { $Items.Add($Value) | Out-Null }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$projectRootResolved = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $repoRoot } elseif ([System.IO.Path]::IsPathRooted($ProjectRoot)) { $ProjectRoot } else { Join-Path $repoRoot $ProjectRoot }
$contractExists = Test-Path -LiteralPath (Join-Path $repoRoot $ContractPath) -PathType Leaf
$configPaths = @($ProjectConfigPath | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$existingConfigs = @($configPaths | Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot $_) -PathType Leaf })
$effectiveProfile = if ([string]::IsNullOrWhiteSpace($Profile)) { "staging-extraction" } else { [string]$Profile }
$configRequiredProfiles = @("adopter-onboard", "public-release", "release-strict")
$requiresProjectConfig = ($configRequiredProfiles -contains $effectiveProfile)

$checkedInvariants = New-Object System.Collections.Generic.List[string]
$waivedInvariants = New-Object System.Collections.Generic.List[string]
$blockingFailures = New-Object System.Collections.Generic.List[string]

Add-Item -Items $checkedInvariants -Value "project root exists"
if (-not (Test-Path -LiteralPath $projectRootResolved -PathType Container)) {
    Add-Item -Items $blockingFailures -Value ("PROJECT_ROOT_MISSING: {0}" -f $projectRootResolved)
}
Add-Item -Items $checkedInvariants -Value "project contract exists"
if (-not $contractExists) {
    Add-Item -Items $blockingFailures -Value ("CONTRACT_MISSING: {0}" -f $ContractPath)
}
if ($requiresProjectConfig) {
    Add-Item -Items $checkedInvariants -Value "profile requires a real project config"
    if ($existingConfigs.Count -eq 0) {
        Add-Item -Items $blockingFailures -Value ("PROJECT_CONFIG_MISSING: profile={0}; expected={1}" -f $effectiveProfile, [string]::Join(",", @($configPaths)))
    }
}
else {
    Add-Item -Items $waivedInvariants -Value ("project config existence is waived for profile={0}" -f $effectiveProfile)
}

$pass = ($blockingFailures.Count -eq 0)

$latestJsonPath = Join-Path $OutDir "project-onboard-latest.json"
$payload = [ordered]@{
    machineTag = "RCCP_PROJECT_ONBOARD_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    pass = [bool]$pass
    semanticPass = [bool]$pass
    profile = [string]$effectiveProfile
    projectRoot = $projectRootResolved.Replace("\", "/")
    projectConfigPaths = @($configPaths)
    existingProjectConfigPaths = @($existingConfigs)
    contractPath = $ContractPath
    contractExists = [bool]$contractExists
    checkedInvariants = @($checkedInvariants.ToArray())
    waivedInvariants = @($waivedInvariants.ToArray())
    blockingFailures = @($blockingFailures.ToArray())
    distribution = "staging-extraction"
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action project-governance-check -Task `"$Task`" -Profile `"$effectiveProfile`" -Strict"
    evidencePath = "docs/治理/最新态/project-onboard-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("project-onboard completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
