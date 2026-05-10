[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "rccp-leaf-contract-check",
    [string]$ActionName = "",
    [string]$DispatchPath = "docs/治理/策略/rccp-entry-dispatch.json",
    [string]$OutDir = "docs/治理/最新态",
    [switch]$RequireAllLeafScripts,
    [switch]$Strict,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Utf8NoBom {
    Param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $normalized = $Content -replace "`r`n", "`n" -replace "`r", "`n"
    [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Convert-ActionNameToSlug {
    Param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return "all" }
    $slug = ([string]$Name).Trim().ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug -replace "^-+", "" -replace "-+$", ""
    if ([string]::IsNullOrWhiteSpace($slug)) { return "unknown" }
    return $slug
}

function Resolve-RepoPath {
    Param([string]$RepoRoot, [string]$PathText)
    if ([string]::IsNullOrWhiteSpace($PathText)) { return "" }
    if ([System.IO.Path]::IsPathRooted($PathText)) { return $PathText }
    return (Join-Path $RepoRoot $PathText)
}

function Get-ScriptParameterNames {
    Param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw ("leaf script missing: {0}" -f $Path)
    }
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        throw ("leaf script parse failed: {0}: {1}" -f $Path, [string]::Join("; ", @($errors | ForEach-Object { $_.Message })))
    }
    $paramNames = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    if ($null -ne $ast.ParamBlock) {
        foreach ($param in @($ast.ParamBlock.Parameters)) {
            [void]$paramNames.Add([string]$param.Name.VariablePath.UserPath)
            foreach ($attr in @($param.Attributes)) {
                if ($attr.TypeName.FullName -notin @("Alias", "System.Management.Automation.Alias")) { continue }
                foreach ($arg in @($attr.PositionalArguments)) {
                    $aliasValue = ""
                    if ($arg -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                        $aliasValue = [string]$arg.Value
                    }
                    if (-not [string]::IsNullOrWhiteSpace($aliasValue)) {
                        [void]$paramNames.Add($aliasValue)
                    }
                }
            }
        }
    }
    return $paramNames
}

function Get-PropertyValue {
    Param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Get-DispatchTarget {
    Param([object]$EntryDispatch, [string]$Name)
    $value = Get-PropertyValue -Object $EntryDispatch -Name $Name
    if ($null -eq $value) { return "" }
    return [string]$value
}

function New-CheckResult {
    Param(
        [string]$Action,
        [string]$Path,
        [string]$Category,
        [string[]]$RequiredParams,
        [string[]]$SupportedParams,
        [string[]]$MissingParams,
        [bool]$Pass
    )
    return [ordered]@{
        action = $Action
        path = $Path
        category = $Category
        requiredParams = @($RequiredParams)
        supportedParams = @($SupportedParams)
        missingParams = @($MissingParams)
        pass = [bool]$Pass
    }
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$dispatchFullPath = Resolve-RepoPath -RepoRoot $repoRoot -PathText $DispatchPath
if (-not (Test-Path -LiteralPath $dispatchFullPath)) {
    throw ("missing dispatch file: {0}" -f $DispatchPath)
}

$dispatchDoc = Get-Content -LiteralPath $dispatchFullPath -Encoding UTF8 -Raw | ConvertFrom-Json
$entryDispatch = $dispatchDoc.entryDispatch
$envelope = @(
    "Task",
    "TargetPaths",
    "EvidencePaths",
    "SuggestionId",
    "IssueId",
    "ProgressId",
    "RecentSection",
    "Mode",
    "GateProfile",
    "BlueprintRoot",
    "BlueprintPath",
    "Strict",
    "Json"
)
if ($null -ne $dispatchDoc.leafParameterEnvelope) {
    $configured = @($dispatchDoc.leafParameterEnvelope.commonParams | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($configured.Count -gt 0) { $envelope = $configured }
}

$contractMap = @{}
if ($null -ne $dispatchDoc.leafContracts) {
    foreach ($prop in @($dispatchDoc.leafContracts.PSObject.Properties)) {
        $contractMap[[string]$prop.Name] = $prop.Value
    }
}
if (-not $contractMap.ContainsKey("final-recap-check")) {
    $contractMap["final-recap-check"] = [pscustomobject]@{
        category = "closeout-critical"
        requiredParams = $envelope
        allowUnknownArgs = $false
    }
}

$distributionProfileName = "unspecified"
$requiredLeafActions = @()
if ($null -ne $dispatchDoc.distributionProfile) {
    $distributionProfileName = [string](Get-PropertyValue -Object $dispatchDoc.distributionProfile -Name "name")
    $requiredLeafActions = @((Get-PropertyValue -Object $dispatchDoc.distributionProfile -Name "requiredLeafActions") | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
if ($requiredLeafActions.Count -eq 0) {
    $requiredLeafActions = @($contractMap.Keys)
}

$actions = @()
if (-not [string]::IsNullOrWhiteSpace($ActionName)) {
    $actions = @($ActionName)
}
elseif ($RequireAllLeafScripts) {
    $actions = @($contractMap.Keys)
}
else {
    $actions = @($requiredLeafActions)
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($action in @($actions)) {
    if (-not $contractMap.ContainsKey($action)) {
        $results.Add((New-CheckResult -Action $action -Path "" -Category "UNDECLARED" -RequiredParams @() -SupportedParams @() -MissingParams @("leafContracts.$action") -Pass $false)) | Out-Null
        continue
    }
    $contract = $contractMap[$action]
    $category = [string](Get-PropertyValue -Object $contract -Name "category")
    if ([string]::IsNullOrWhiteSpace($category)) { $category = "leaf" }
    $required = @((Get-PropertyValue -Object $contract -Name "requiredParams") | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($required.Count -eq 0 -and [string]::Equals($category, "closeout-critical", [System.StringComparison]::OrdinalIgnoreCase)) {
        $required = @($envelope)
    }
    $target = Get-DispatchTarget -EntryDispatch $entryDispatch -Name $action
    $fullTarget = Resolve-RepoPath -RepoRoot $repoRoot -PathText $target
    $paramSet = Get-ScriptParameterNames -Path $fullTarget
    $supported = @($paramSet | Sort-Object)
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($name in @($required)) {
        if (-not $paramSet.Contains($name)) {
            $missing.Add($name) | Out-Null
        }
    }
    $results.Add((New-CheckResult -Action $action -Path $target -Category $category -RequiredParams $required -SupportedParams $supported -MissingParams @($missing.ToArray()) -Pass ($missing.Count -eq 0))) | Out-Null
}

$failed = @($results.ToArray() | Where-Object { -not [bool]$_.pass })
$pass = ($failed.Count -eq 0)
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$scopeSlug = Convert-ActionNameToSlug -Name $ActionName
$jsonPath = Join-Path $OutDir "rccp-leaf-contract-check-latest.json"
$mdPath = Join-Path $OutDir "rccp-leaf-contract-check-latest.md"
$historyPath = Join-Path $OutDir ("rccp-leaf-contract-check-{0}.json" -f $stamp)
$scopedJsonPath = Join-Path $OutDir ("rccp-leaf-contract-check-{0}-latest.json" -f $scopeSlug)
$scopedMdPath = Join-Path $OutDir ("rccp-leaf-contract-check-{0}-latest.md" -f $scopeSlug)
$scopedHistoryPath = Join-Path $OutDir ("rccp-leaf-contract-check-{0}-{1}.json" -f $scopeSlug, $stamp)

$summary = [ordered]@{
    machineTag = "RCCP_LEAF_CONTRACT_CHECK_V1"
    generatedAt = (Get-Date).ToString("s")
    task = [string]$Task
    pass = [bool]$pass
    actionName = [string]$ActionName
    dispatchPath = $DispatchPath
    distributionProfile = [string]$distributionProfileName
    requireAllLeafScripts = [bool]$RequireAllLeafScripts
    commonParameterEnvelope = @($envelope)
    checkedCount = @($results.ToArray()).Count
    failedCount = $failed.Count
    evidenceScope = $(if ([string]::IsNullOrWhiteSpace($ActionName)) { "all-actions" } else { "action-scoped" })
    globalLatestPath = $jsonPath
    scopedLatestPath = $scopedJsonPath
    historyPath = $historyPath
    scopedHistoryPath = $scopedHistoryPath
    results = @($results.ToArray())
}
$jsonText = $summary | ConvertTo-Json -Depth 10
Write-Utf8NoBom -Path $jsonPath -Content $jsonText
Write-Utf8NoBom -Path $historyPath -Content $jsonText
Write-Utf8NoBom -Path $scopedJsonPath -Content $jsonText
Write-Utf8NoBom -Path $scopedHistoryPath -Content $jsonText

$mdLines = New-Object System.Collections.Generic.List[string]
$mdLines.Add("# RCCP Leaf Contract Check") | Out-Null
$mdLines.Add("") | Out-Null
$mdLines.Add(("- pass: {0}" -f [bool]$pass)) | Out-Null
$mdLines.Add(("- actionName: {0}" -f $(if ([string]::IsNullOrWhiteSpace($ActionName)) { "all" } else { [string]$ActionName }))) | Out-Null
$mdLines.Add(("- checkedCount: {0}" -f @($results.ToArray()).Count)) | Out-Null
$mdLines.Add(("- failedCount: {0}" -f $failed.Count)) | Out-Null
$mdLines.Add(("- globalLatestPath: {0}" -f $jsonPath)) | Out-Null
$mdLines.Add(("- scopedLatestPath: {0}" -f $scopedJsonPath)) | Out-Null
$mdLines.Add("") | Out-Null
$mdLines.Add("| Action | Category | Pass | Missing Params | Path |") | Out-Null
$mdLines.Add("|---|---|---|---|---|") | Out-Null
foreach ($result in @($results.ToArray())) {
    $missingText = if (@($result.missingParams).Count -gt 0) { [string]::Join("<br>", @($result.missingParams)) } else { "" }
    $mdLines.Add(("| {0} | {1} | {2} | {3} | {4} |" -f $result.action, $result.category, $result.pass, $missingText, $result.path)) | Out-Null
}
$mdText = [string]::Join("`n", @($mdLines.ToArray())) + "`n"
Write-Utf8NoBom -Path $mdPath -Content $mdText
Write-Utf8NoBom -Path $scopedMdPath -Content $mdText

if ($Json) {
    $jsonText
}
else {
    Write-Host ("rccp-leaf-contract-check completed: pass={0}, checked={1}, latest='{2}', scopedLatest='{3}'" -f [bool]$pass, @($results.ToArray()).Count, $jsonPath, $scopedJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" })
}

if ($Strict -and -not $pass) {
    exit 1
}
