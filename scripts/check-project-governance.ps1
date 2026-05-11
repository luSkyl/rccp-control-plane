[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "project-governance-check",
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

function Read-JsonFile {
    Param([string]$Path)
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Get-ObjectValue {
    Param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Get-StringArray {
    Param([object]$Value)
    if ($null -eq $Value) { return @() }
    return @($Value | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Add-Failure {
    Param([System.Collections.Generic.List[string]]$Failures, [string]$Code, [string]$Detail)
    $Failures.Add(("{0}: {1}" -f $Code, $Detail)) | Out-Null
}

function Test-PathInside {
    Param([string]$Child, [string]$Parent)
    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $childFull = [System.IO.Path]::GetFullPath($Child).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $childFull.StartsWith($parentFull, [System.StringComparison]::OrdinalIgnoreCase)
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$dispatchPath = Join-Path $repoRoot "docs/治理/策略/rccp-entry-dispatch.json"
$policyPath = Join-Path $repoRoot "policies/rccp-entry-dispatch.json"
$manifestPath = Join-Path $repoRoot "docs/治理/策略/rccp-kit-manifest.json"
$dispatch = Read-JsonFile -Path $dispatchPath
$policy = Read-JsonFile -Path $policyPath
$contract = Read-JsonFile -Path (Join-Path $repoRoot $ContractPath)
$manifest = Read-JsonFile -Path $manifestPath
$required = @($dispatch.distributionProfile.requiredLeafActions | ForEach-Object { [string]$_ })
$missingRequired = @($required | Where-Object {
    $target = [string]$dispatch.entryDispatch.$_
    [string]::IsNullOrWhiteSpace($target) -or -not (Test-Path -LiteralPath (Join-Path $repoRoot $target) -PathType Leaf)
})
$mirrorText = (($dispatch | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
$policyText = (($policy | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
$dispatchMirror = [string]::Equals($mirrorText, $policyText, [System.StringComparison]::Ordinal)

$effectiveProfile = if ([string]::IsNullOrWhiteSpace($Profile)) { "staging-extraction" } else { [string]$Profile }
$configRequiredProfiles = @("adopter-onboard", "public-release", "release-strict")
$requiresProjectConfig = ($configRequiredProfiles -contains $effectiveProfile)
$checkedInvariants = New-Object System.Collections.Generic.List[string]
$waivedInvariants = New-Object System.Collections.Generic.List[string]
$blockingFailures = New-Object System.Collections.Generic.List[string]

$checkedInvariants.Add("docs/policies dispatch mirror") | Out-Null
if (-not $dispatchMirror) { Add-Failure -Failures $blockingFailures -Code "DISPATCH_MIRROR_MISMATCH" -Detail "docs/治理/策略 and policies dispatch differ" }
$checkedInvariants.Add("required leaf actions resolve to scripts") | Out-Null
foreach ($item in @($missingRequired)) { Add-Failure -Failures $blockingFailures -Code "REQUIRED_LEAF_MISSING" -Detail $item }

$availableActions = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in @($dispatch.entryDispatch.PSObject.Properties.Name)) { [void]$availableActions.Add([string]$name) }
foreach ($name in @($dispatch.coreActions)) { [void]$availableActions.Add([string]$name) }
foreach ($surface in @("readonly", "write", "runtimeWrite", "closeoutWrite")) {
    foreach ($name in @(Get-StringArray -Value (Get-ObjectValue -Object $dispatch.actionSurface -Name $surface))) {
        [void]$availableActions.Add([string]$name)
    }
}

$contractRequiredActions = Get-StringArray -Value $contract.requiredActions
$manifestRequiredActions = Get-StringArray -Value $manifest.compatibility.requiredActions
$checkedInvariants.Add("contract required actions are dispatchable or core actions") | Out-Null
foreach ($action in @($contractRequiredActions)) {
    if (-not $availableActions.Contains($action)) { Add-Failure -Failures $blockingFailures -Code "CONTRACT_REQUIRED_ACTION_UNAVAILABLE" -Detail $action }
}
$checkedInvariants.Add("manifest required actions are dispatchable or core actions") | Out-Null
foreach ($action in @($manifestRequiredActions)) {
    if (-not $availableActions.Contains($action)) { Add-Failure -Failures $blockingFailures -Code "MANIFEST_REQUIRED_ACTION_UNAVAILABLE" -Detail $action }
}

$projectRootResolved = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $repoRoot } elseif ([System.IO.Path]::IsPathRooted($ProjectRoot)) { $ProjectRoot } else { Join-Path $repoRoot $ProjectRoot }
$configPaths = @($ProjectConfigPath | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$existingConfigs = @($configPaths | Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot $_) -PathType Leaf })
$config = $null
if ($existingConfigs.Count -gt 0) {
    $config = Read-JsonFile -Path (Join-Path $repoRoot $existingConfigs[0])
}
elseif ($requiresProjectConfig) {
    Add-Failure -Failures $blockingFailures -Code "PROJECT_CONFIG_MISSING" -Detail ("profile={0}; expected={1}" -f $effectiveProfile, [string]::Join(",", @($configPaths)))
}
else {
    $waivedInvariants.Add(("project config semantic validation is waived for profile={0}" -f $effectiveProfile)) | Out-Null
}

if ($null -ne $config) {
    $checkedInvariants.Add("project config required fields exist") | Out-Null
    foreach ($field in @(Get-StringArray -Value $contract.requiredFields)) {
        $value = Get-ObjectValue -Object $config -Name $field
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
            Add-Failure -Failures $blockingFailures -Code "PROJECT_CONFIG_FIELD_MISSING" -Detail $field
        }
    }

    $projectRootFromConfig = [string](Get-ObjectValue -Object $config -Name "projectRoot")
    $configProjectRoot = if ([string]::IsNullOrWhiteSpace($projectRootFromConfig)) { $projectRootResolved } elseif ([System.IO.Path]::IsPathRooted($projectRootFromConfig)) { $projectRootFromConfig } else { Join-Path $repoRoot $projectRootFromConfig }
    $checkedInvariants.Add("project config path fields exist and stay inside project root") | Out-Null
    foreach ($fieldSpec in @($contract.pathFields)) {
        $fieldName = [string]$fieldSpec.name
        $rawPath = [string](Get-ObjectValue -Object $config -Name $fieldName)
        if ([string]::IsNullOrWhiteSpace($rawPath)) { continue }
        $resolved = if ([System.IO.Path]::IsPathRooted($rawPath)) { $rawPath } else { Join-Path $configProjectRoot $rawPath }
        if ([bool]$fieldSpec.mustExist -and -not (Test-Path -LiteralPath $resolved)) {
            Add-Failure -Failures $blockingFailures -Code "PROJECT_CONFIG_PATH_MISSING" -Detail ("{0}={1}" -f $fieldName, $rawPath)
        }
        if ([bool]$fieldSpec.mustBeInsideProjectRoot -and -not (Test-PathInside -Child $resolved -Parent $configProjectRoot)) {
            Add-Failure -Failures $blockingFailures -Code "PROJECT_CONFIG_PATH_OUTSIDE_ROOT" -Detail ("{0}={1}" -f $fieldName, $rawPath)
        }
    }

    $enabledActions = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($action in @(Get-StringArray -Value (Get-ObjectValue -Object $config -Name "enabledActions"))) { [void]$enabledActions.Add($action) }
    $checkedInvariants.Add("project enabledActions include contract required actions") | Out-Null
    foreach ($action in @($contractRequiredActions)) {
        if (-not $enabledActions.Contains($action)) { Add-Failure -Failures $blockingFailures -Code "PROJECT_REQUIRED_ACTION_NOT_ENABLED" -Detail $action }
    }

    $checkedInvariants.Add("adapter contracts expose required fields") | Out-Null
    foreach ($adapter in @((Get-ObjectValue -Object $config -Name "adapterContracts"))) {
        foreach ($field in @(Get-StringArray -Value $contract.adapterContractRequiredFields)) {
            $value = Get-ObjectValue -Object $adapter -Name $field
            if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
                Add-Failure -Failures $blockingFailures -Code "ADAPTER_CONTRACT_FIELD_MISSING" -Detail $field
            }
        }
    }
    $checkedInvariants.Add("rollback drill exposes required fields") | Out-Null
    $rollbackDrill = Get-ObjectValue -Object $config -Name "rollbackDrill"
    foreach ($field in @(Get-StringArray -Value $contract.rollbackDrillRequiredFields)) {
        $value = Get-ObjectValue -Object $rollbackDrill -Name $field
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
            Add-Failure -Failures $blockingFailures -Code "ROLLBACK_DRILL_FIELD_MISSING" -Detail $field
        }
    }
}

$pass = ($blockingFailures.Count -eq 0)

$latestJsonPath = Join-Path $OutDir "project-governance-check-latest.json"
$payload = [ordered]@{
    machineTag = "RCCP_PROJECT_GOVERNANCE_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    pass = [bool]$pass
    semanticPass = [bool]$pass
    profile = [string]$effectiveProfile
    distributionProfile = [string]$dispatch.distributionProfile.name
    requiredLeafActionCount = [int]$required.Count
    missingRequiredActions = @($missingRequired)
    dispatchMirror = [bool]$dispatchMirror
    contractRequiredActions = @($contractRequiredActions)
    manifestRequiredActions = @($manifestRequiredActions)
    existingProjectConfigPaths = @($existingConfigs)
    checkedInvariants = @($checkedInvariants.ToArray())
    waivedInvariants = @($waivedInvariants.ToArray())
    blockingFailures = @($blockingFailures.ToArray())
    evidencePath = "docs/治理/最新态/project-governance-check-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("project-governance-check completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
