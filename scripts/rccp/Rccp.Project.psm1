[CmdletBinding(PositionalBinding = $false)]
Param()

$ErrorActionPreference = "Stop"

function Write-RccpUtf8NoBom {
    Param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $normalized = $Content -replace "`r`n", "`n" -replace "`r", "`n"
    [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-RccpRepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
}

function Resolve-RccpPath {
    Param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [string]$PathText
    )
    if ([string]::IsNullOrWhiteSpace($PathText)) { return "" }
    if ([System.IO.Path]::IsPathRooted($PathText)) {
        return [System.IO.Path]::GetFullPath($PathText)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $PathText))
}

function ConvertTo-RccpSlashPath {
    Param([string]$PathText)
    if ([string]::IsNullOrWhiteSpace($PathText)) { return "" }
    return $PathText.Replace("\", "/")
}

function Test-RccpPathWithinRoot {
    Param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$CandidatePath
    )
    $root = [System.IO.Path]::GetFullPath($RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $candidate = [System.IO.Path]::GetFullPath($CandidatePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if ([string]::Equals($candidate, $root, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    $prefix = $root + [System.IO.Path]::DirectorySeparatorChar
    return $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Add-RccpProjectViolation {
    Param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Violations,
        [Parameter(Mandatory = $true)][string]$Code,
        [string]$Detail = "",
        [string]$Path = ""
    )
    $Violations.Add([ordered]@{
        code = $Code
        detail = [string]$Detail
        path = [string]$Path
    }) | Out-Null
}

function Get-RccpJsonDocument {
    Param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Violations,
        [Parameter(Mandatory = $true)][string]$MissingCode,
        [Parameter(Mandatory = $true)][string]$ParseCode
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        Add-RccpProjectViolation -Violations $Violations -Code $MissingCode -Path $Path -Detail "file not found"
        return $null
    }
    try {
        return (Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json -Depth 40)
    }
    catch {
        Add-RccpProjectViolation -Violations $Violations -Code $ParseCode -Path $Path -Detail $_.Exception.Message
        return $null
    }
}

function Get-RccpObjectValue {
    Param([object]$Object, [string]$Name)
    if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($Name)) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Get-RccpStringArray {
    Param([object]$Value)
    $items = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Value) { return @() }
    foreach ($item in @($Value)) {
        $text = [string]$item
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            $items.Add($text.Trim()) | Out-Null
        }
    }
    return @($items.ToArray())
}

function Get-RccpObjectArray {
    Param([object]$Value)
    if ($null -eq $Value) { return @() }
    return @($Value)
}

function Test-RccpValuePresent {
    Param([object]$Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [array]) { return (@($Value).Count -gt 0) }
    return (-not [string]::IsNullOrWhiteSpace([string]$Value))
}

function Resolve-RccpProjectOutDir {
    Param(
        [Parameter(Mandatory = $true)][object]$Snapshot,
        [string]$OutDir = ""
    )
    if (-not [string]::IsNullOrWhiteSpace($OutDir) -and
        -not [string]::Equals($OutDir, "docs/治理/最新态", [System.StringComparison]::OrdinalIgnoreCase)) {
        return (Resolve-RccpPath -BasePath ([string]$Snapshot.projectRoot) -PathText $OutDir)
    }
    $resolved = Get-RccpObjectValue -Object $Snapshot.resolvedPaths -Name "evidenceRoot"
    if (-not [string]::IsNullOrWhiteSpace([string]$resolved)) {
        return [string]$resolved
    }
    return (Resolve-RccpPath -BasePath ([string]$Snapshot.projectRoot) -PathText "docs/治理/最新态")
}

function Get-RccpProjectSnapshot {
    Param(
        [string]$Task = "project-onboard",
        [string]$ProjectConfigPath = "rccp.project.json",
        [string]$ContractPath = "docs/治理/策略/rccp-project-contract.json",
        [string]$ProjectRoot = ""
    )

    $repoRoot = Get-RccpRepoRoot
    $violations = New-Object System.Collections.Generic.List[object]
    $configFullPath = Resolve-RccpPath -BasePath $repoRoot -PathText $ProjectConfigPath
    $contractFullPath = Resolve-RccpPath -BasePath $repoRoot -PathText $ContractPath

    $config = Get-RccpJsonDocument -Path $configFullPath -Violations $violations -MissingCode "PROJECT_CONFIG_MISSING" -ParseCode "PROJECT_CONFIG_PARSE_FAILED"
    $contract = Get-RccpJsonDocument -Path $contractFullPath -Violations $violations -MissingCode "PROJECT_CONTRACT_MISSING" -ParseCode "PROJECT_CONTRACT_PARSE_FAILED"

    $requiredFields = @()
    $allowedProfiles = @()
    $requiredActions = @()
    $pathFields = @()
    $adapterContractRequiredFields = @()
    $rollbackDrillRequiredFields = @()
    if ($null -ne $contract) {
        $requiredFields = @(Get-RccpStringArray -Value (Get-RccpObjectValue -Object $contract -Name "requiredFields"))
        $allowedProfiles = @(Get-RccpStringArray -Value (Get-RccpObjectValue -Object $contract -Name "allowedProfiles"))
        $requiredActions = @(Get-RccpStringArray -Value (Get-RccpObjectValue -Object $contract -Name "requiredActions"))
        $pathFields = @((Get-RccpObjectValue -Object $contract -Name "pathFields"))
        $adapterContractRequiredFields = @(Get-RccpStringArray -Value (Get-RccpObjectValue -Object $contract -Name "adapterContractRequiredFields"))
        $rollbackDrillRequiredFields = @(Get-RccpStringArray -Value (Get-RccpObjectValue -Object $contract -Name "rollbackDrillRequiredFields"))
    }

    if ($null -ne $config) {
        foreach ($field in @($requiredFields)) {
            if (-not (Test-RccpValuePresent -Value (Get-RccpObjectValue -Object $config -Name $field))) {
                Add-RccpProjectViolation -Violations $violations -Code "PROJECT_CONFIG_REQUIRED_FIELD_MISSING" -Detail $field -Path $ProjectConfigPath
            }
        }
    }

    $projectRootFromConfig = if ($null -ne $config) { [string](Get-RccpObjectValue -Object $config -Name "projectRoot") } else { "" }
    $effectiveProjectRoot = if (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
        Resolve-RccpPath -BasePath $repoRoot -PathText $ProjectRoot
    }
    elseif (-not [string]::IsNullOrWhiteSpace($projectRootFromConfig)) {
        Resolve-RccpPath -BasePath $repoRoot -PathText $projectRootFromConfig
    }
    else {
        $repoRoot
    }

    if (-not (Test-Path -LiteralPath $effectiveProjectRoot)) {
        Add-RccpProjectViolation -Violations $violations -Code "PROJECT_ROOT_MISSING" -Detail $effectiveProjectRoot -Path $projectRootFromConfig
    }

    if (-not [string]::IsNullOrWhiteSpace($ProjectRoot) -and -not [string]::IsNullOrWhiteSpace($projectRootFromConfig)) {
        $declaredRoot = Resolve-RccpPath -BasePath $repoRoot -PathText $projectRootFromConfig
        if (-not [string]::Equals($declaredRoot, $effectiveProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-RccpProjectViolation -Violations $violations -Code "PROJECT_ROOT_OVERRIDE_MISMATCH" -Detail ("declared={0}; override={1}" -f $declaredRoot, $effectiveProjectRoot) -Path $ProjectConfigPath
        }
    }

    $profile = if ($null -ne $config) { [string](Get-RccpObjectValue -Object $config -Name "governanceProfile") } else { "" }
    if ($allowedProfiles.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($profile) -and ($allowedProfiles -notcontains $profile)) {
        Add-RccpProjectViolation -Violations $violations -Code "GOVERNANCE_PROFILE_NOT_ALLOWED" -Detail $profile -Path $ProjectConfigPath
    }

    $fallbackProfile = if ($null -ne $config) { [string](Get-RccpObjectValue -Object $config -Name "fallbackProfile") } else { "" }
    if ($allowedProfiles.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($fallbackProfile) -and ($allowedProfiles -notcontains $fallbackProfile)) {
        Add-RccpProjectViolation -Violations $violations -Code "FALLBACK_PROFILE_NOT_ALLOWED" -Detail $fallbackProfile -Path $ProjectConfigPath
    }

    $resolvedPaths = [ordered]@{}
    foreach ($pathField in @($pathFields)) {
        $fieldName = [string](Get-RccpObjectValue -Object $pathField -Name "name")
        if ([string]::IsNullOrWhiteSpace($fieldName)) { continue }
        if ([string]::Equals($fieldName, "projectRoot", [System.StringComparison]::OrdinalIgnoreCase)) {
            $resolvedPaths[$fieldName] = $effectiveProjectRoot
            continue
        }
        $value = if ($null -ne $config) { [string](Get-RccpObjectValue -Object $config -Name $fieldName) } else { "" }
        if ([string]::IsNullOrWhiteSpace($value)) {
            Add-RccpProjectViolation -Violations $violations -Code "PROJECT_PATH_FIELD_MISSING" -Detail $fieldName -Path $ProjectConfigPath
            continue
        }
        $resolved = Resolve-RccpPath -BasePath $effectiveProjectRoot -PathText $value
        $resolvedPaths[$fieldName] = $resolved

        $mustExist = [bool](Get-RccpObjectValue -Object $pathField -Name "mustExist")
        if ($mustExist -and -not (Test-Path -LiteralPath $resolved)) {
            Add-RccpProjectViolation -Violations $violations -Code "PROJECT_PATH_MISSING" -Detail $fieldName -Path $resolved
        }
        $insideRoot = [bool](Get-RccpObjectValue -Object $pathField -Name "mustBeInsideProjectRoot")
        if ($insideRoot -and (Test-Path -LiteralPath $effectiveProjectRoot) -and -not (Test-RccpPathWithinRoot -RootPath $effectiveProjectRoot -CandidatePath $resolved)) {
            Add-RccpProjectViolation -Violations $violations -Code "PROJECT_PATH_OUTSIDE_ROOT" -Detail $fieldName -Path $resolved
        }
    }

    $enabledActions = if ($null -ne $config) { @(Get-RccpStringArray -Value (Get-RccpObjectValue -Object $config -Name "enabledActions")) } else { @() }
    foreach ($action in @($requiredActions)) {
        if ($enabledActions -notcontains $action) {
            Add-RccpProjectViolation -Violations $violations -Code "PROJECT_REQUIRED_ACTION_DISABLED" -Detail $action -Path $ProjectConfigPath
        }
    }

    $adapterList = if ($null -ne $config) { @(Get-RccpStringArray -Value (Get-RccpObjectValue -Object $config -Name "adapterList")) } else { @() }
    $adapterContracts = if ($null -ne $config) { @(Get-RccpObjectArray -Value (Get-RccpObjectValue -Object $config -Name "adapterContracts")) } else { @() }
    $adapterContractNames = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($adapterContract in @($adapterContracts)) {
        $adapterName = [string](Get-RccpObjectValue -Object $adapterContract -Name "name")
        if ([string]::IsNullOrWhiteSpace($adapterName)) {
            Add-RccpProjectViolation -Violations $violations -Code "ADAPTER_CONTRACT_NAME_MISSING" -Path $ProjectConfigPath -Detail "adapterContracts.name"
            continue
        }
        [void]$adapterContractNames.Add($adapterName)
        foreach ($field in @($adapterContractRequiredFields)) {
            if (-not (Test-RccpValuePresent -Value (Get-RccpObjectValue -Object $adapterContract -Name $field))) {
                Add-RccpProjectViolation -Violations $violations -Code "ADAPTER_CONTRACT_FIELD_MISSING" -Detail ("{0}.{1}" -f $adapterName, $field) -Path $ProjectConfigPath
            }
        }
        foreach ($gate in @(Get-RccpStringArray -Value (Get-RccpObjectValue -Object $adapterContract -Name "requiredGates"))) {
            if ($enabledActions -notcontains $gate -and $requiredActions -notcontains $gate) {
                Add-RccpProjectViolation -Violations $violations -Code "ADAPTER_REQUIRED_GATE_UNAVAILABLE" -Detail ("{0}:{1}" -f $adapterName, $gate) -Path $ProjectConfigPath
            }
        }
    }
    foreach ($adapter in @($adapterList)) {
        if (-not $adapterContractNames.Contains($adapter)) {
            Add-RccpProjectViolation -Violations $violations -Code "ADAPTER_CONTRACT_MISSING" -Detail $adapter -Path $ProjectConfigPath
        }
    }

    $rollbackDrill = if ($null -ne $config) { Get-RccpObjectValue -Object $config -Name "rollbackDrill" } else { $null }
    if ($null -ne $rollbackDrill) {
        foreach ($field in @($rollbackDrillRequiredFields)) {
            if (-not (Test-RccpValuePresent -Value (Get-RccpObjectValue -Object $rollbackDrill -Name $field))) {
                Add-RccpProjectViolation -Violations $violations -Code "ROLLBACK_DRILL_FIELD_MISSING" -Detail $field -Path $ProjectConfigPath
            }
        }
        $rollbackToProfile = [string](Get-RccpObjectValue -Object $rollbackDrill -Name "toProfile")
        if (-not [string]::IsNullOrWhiteSpace($rollbackToProfile) -and -not [string]::Equals($rollbackToProfile, $fallbackProfile, [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-RccpProjectViolation -Violations $violations -Code "ROLLBACK_DRILL_FALLBACK_MISMATCH" -Detail ("toProfile={0}; fallbackProfile={1}" -f $rollbackToProfile, $fallbackProfile) -Path $ProjectConfigPath
        }
        foreach ($action in @(Get-RccpStringArray -Value (Get-RccpObjectValue -Object $rollbackDrill -Name "requiredActions"))) {
            if ($enabledActions -notcontains $action -and $requiredActions -notcontains $action) {
                Add-RccpProjectViolation -Violations $violations -Code "ROLLBACK_DRILL_ACTION_UNAVAILABLE" -Detail $action -Path $ProjectConfigPath
            }
        }
    }

    $sharedHotFiles = if ($null -ne $config) { @(Get-RccpStringArray -Value (Get-RccpObjectValue -Object $config -Name "sharedHotFiles")) } else { @() }
    foreach ($hotFile in @($sharedHotFiles)) {
        $hotPath = Resolve-RccpPath -BasePath $effectiveProjectRoot -PathText $hotFile
        if (-not (Test-Path -LiteralPath $hotPath)) {
            Add-RccpProjectViolation -Violations $violations -Code "SHARED_HOT_FILE_MISSING" -Detail $hotFile -Path $hotPath
        }
        elseif (-not (Test-RccpPathWithinRoot -RootPath $effectiveProjectRoot -CandidatePath $hotPath)) {
            Add-RccpProjectViolation -Violations $violations -Code "SHARED_HOT_FILE_OUTSIDE_ROOT" -Detail $hotFile -Path $hotPath
        }
    }

    return [pscustomobject]@{
        task = [string]$Task
        repoRoot = $repoRoot
        projectRoot = $effectiveProjectRoot
        configPath = $configFullPath
        contractPath = $contractFullPath
        config = $config
        contract = $contract
        projectId = if ($null -ne $config) { [string](Get-RccpObjectValue -Object $config -Name "projectId") } else { "" }
        projectName = if ($null -ne $config) { [string](Get-RccpObjectValue -Object $config -Name "projectName") } else { "" }
        profile = $profile
        fallbackProfile = $fallbackProfile
        requiredActions = @($requiredActions)
        enabledActions = @($enabledActions)
        allowedProfiles = @($allowedProfiles)
        adapterList = @($adapterList)
        adapterContracts = @($adapterContracts)
        rollbackDrill = $rollbackDrill
        resolvedPaths = $resolvedPaths
        sharedHotFiles = @($sharedHotFiles)
        violations = $violations
    }
}

Export-ModuleMember -Function Write-RccpUtf8NoBom, Get-RccpRepoRoot, Resolve-RccpPath, ConvertTo-RccpSlashPath, Test-RccpPathWithinRoot, Add-RccpProjectViolation, Get-RccpObjectValue, Get-RccpStringArray, Get-RccpObjectArray, Resolve-RccpProjectOutDir, Get-RccpProjectSnapshot
