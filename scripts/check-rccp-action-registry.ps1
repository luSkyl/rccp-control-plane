[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "action-registry-check",
    [string]$OutDir = "docs/治理/最新态",
    [switch]$RequireAllLeafScripts,
    [switch]$Strict,
    [switch]$Json,
    [object[]]$RemainingArgs = @()
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

function Normalize-JsonText {
    Param([Parameter(Mandatory = $true)][object]$Value)
    return (($Value | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
}

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Read-JsonFile {
    Param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw ("missing registry artifact: {0}" -f $Path)
    }
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Get-ObjectPropertyValue {
    Param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
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
        ok = $Ok
        detail = $Detail
    }) | Out-Null
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$docsDispatchPath = Join-Path $repoRoot "docs/治理/策略/rccp-entry-dispatch.json"
$policyDispatchPath = Join-Path $repoRoot "policies/rccp-entry-dispatch.json"
$entryPath = Join-Path $repoRoot "scripts/rccp/rccp.ps1"
$latestJsonPath = Join-Path $OutDir "action-registry-check-latest.json"
$latestMdPath = Join-Path $OutDir "action-registry-check-latest.md"

$docsDispatch = Read-JsonFile -Path $docsDispatchPath
$policyDispatch = Read-JsonFile -Path $policyDispatchPath
$entryPathExists = Test-Path -LiteralPath $entryPath -PathType Leaf

$checks = New-Object System.Collections.Generic.List[object]

Add-Check -Checks $checks -Name "docs-dispatch" -Ok ([bool]$docsDispatch) -Detail $docsDispatchPath
Add-Check -Checks $checks -Name "policy-dispatch" -Ok ([bool]$policyDispatch) -Detail $policyDispatchPath
Add-Check -Checks $checks -Name "canonical-entry" -Ok ([string]::Equals([string]$docsDispatch.canonicalEntry, "scripts/rccp/rccp.ps1", [System.StringComparison]::OrdinalIgnoreCase) -and [string]::Equals([string]$policyDispatch.canonicalEntry, "scripts/rccp/rccp.ps1", [System.StringComparison]::OrdinalIgnoreCase)) -Detail "scripts/rccp/rccp.ps1"
Add-Check -Checks $checks -Name "entry-script" -Ok $entryPathExists -Detail "scripts/rccp/rccp.ps1"

$docsComparable = [ordered]@{
    machineTag = [string]$docsDispatch.machineTag
    canonicalEntry = [string]$docsDispatch.canonicalEntry
    distributionProfile = $docsDispatch.distributionProfile
    leafParameterEnvelope = $docsDispatch.leafParameterEnvelope
    actionSurface = $docsDispatch.actionSurface
    leafContracts = $docsDispatch.leafContracts
    entryDispatch = $docsDispatch.entryDispatch
    coreActions = $docsDispatch.coreActions
    retiredArtifacts = $docsDispatch.retiredArtifacts
}
$policyComparable = [ordered]@{
    machineTag = [string]$policyDispatch.machineTag
    canonicalEntry = [string]$policyDispatch.canonicalEntry
    distributionProfile = $policyDispatch.distributionProfile
    leafParameterEnvelope = $policyDispatch.leafParameterEnvelope
    actionSurface = $policyDispatch.actionSurface
    leafContracts = $policyDispatch.leafContracts
    entryDispatch = $policyDispatch.entryDispatch
    coreActions = $policyDispatch.coreActions
    retiredArtifacts = $policyDispatch.retiredArtifacts
}

$docsComparableText = Normalize-JsonText -Value $docsComparable
$policyComparableText = Normalize-JsonText -Value $policyComparable
$mirrorOk = [string]::Equals($docsComparableText, $policyComparableText, [System.StringComparison]::Ordinal)
Add-Check -Checks $checks -Name "dispatch-mirror" -Ok $mirrorOk -Detail "docs/policies registry content must stay aligned"

$entryDispatch = $docsDispatch.entryDispatch
$registeredActions = @()
if ($null -ne $entryDispatch) {
    $registeredActions = @($entryDispatch.PSObject.Properties.Name)
}

$distributionProfileName = [string](Get-ObjectPropertyValue -Object $docsDispatch.distributionProfile -Name "name")
if ([string]::IsNullOrWhiteSpace($distributionProfileName)) { $distributionProfileName = "unspecified" }
$requiredLeafActions = @()
if ($null -ne $docsDispatch.distributionProfile) {
    $requiredLeafActions = @((Get-ObjectPropertyValue -Object $docsDispatch.distributionProfile -Name "requiredLeafActions") | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
if ($requiredLeafActions.Count -eq 0) {
    $requiredLeafActions = @(
        "final-recap-check",
        "thin-entry-check",
        "rccp-leaf-contract-check",
        "leaf-contract-check",
        "memory-layer-contract-check",
        "memory-briefing",
        "action-registry-check"
    )
}
Add-Check -Checks $checks -Name "distribution-profile" -Ok (-not [string]::IsNullOrWhiteSpace($distributionProfileName)) -Detail ("profile={0}; requiredLeafActions={1}" -f $distributionProfileName, $requiredLeafActions.Count)

$missingScripts = New-Object System.Collections.Generic.List[string]
foreach ($action in @($registeredActions)) {
    $target = [string](Get-ObjectPropertyValue -Object $entryDispatch -Name $action)
    $fullTarget = if ([System.IO.Path]::IsPathRooted($target)) { $target } else { Join-Path $repoRoot $target }
    if (-not (Test-Path -LiteralPath $fullTarget -PathType Leaf)) {
        $missingScripts.Add(("{0} -> {1}" -f $action, $target)) | Out-Null
    }
}
$missingRequiredScripts = New-Object System.Collections.Generic.List[string]
foreach ($action in @($requiredLeafActions)) {
    $target = [string](Get-ObjectPropertyValue -Object $entryDispatch -Name $action)
    if ([string]::IsNullOrWhiteSpace($target)) {
        $missingRequiredScripts.Add(("{0} -> MISSING_DISPATCH_TARGET" -f $action)) | Out-Null
        continue
    }
    $fullTarget = if ([System.IO.Path]::IsPathRooted($target)) { $target } else { Join-Path $repoRoot $target }
    if (-not (Test-Path -LiteralPath $fullTarget -PathType Leaf)) {
        $missingRequiredScripts.Add(("{0} -> {1}" -f $action, $target)) | Out-Null
    }
}
$dispatchTargetsDetail = if ($missingScripts.Count -eq 0) {
    "all registered actions resolve to leaf scripts"
} elseif ($RequireAllLeafScripts) {
    ("{0} registered actions are missing leaf scripts under full-kit enforcement" -f $missingScripts.Count)
} else {
    ("{0} optional registered actions are missing leaf scripts under {1}; required actions are checked separately" -f $missingScripts.Count, $distributionProfileName)
}
$requiredTargetsDetail = if ($missingRequiredScripts.Count -eq 0) {
    "all required leaf actions resolve to scripts"
} else {
    [string]::Join("; ", @($missingRequiredScripts.ToArray()))
}
Add-Check -Checks $checks -Name "required-dispatch-targets" -Ok ($missingRequiredScripts.Count -eq 0) -Detail $requiredTargetsDetail
Add-Check -Checks $checks -Name "dispatch-targets" -Ok (-not $RequireAllLeafScripts -or $missingScripts.Count -eq 0) -Detail $dispatchTargetsDetail

$actionRegistryOk = (
    $mirrorOk -and
    $entryPathExists -and
    ($missingRequiredScripts.Count -eq 0) -and
    (-not $RequireAllLeafScripts -or $missingScripts.Count -eq 0) -and
    ([string]::Equals([string]$docsDispatch.machineTag, "RCCP_ENTRY_DISPATCH_V1", [System.StringComparison]::OrdinalIgnoreCase))
)
Add-Check -Checks $checks -Name "registry-health" -Ok $actionRegistryOk -Detail "registered actions, mirror state, and script coverage"

$failedChecks = @($checks.ToArray() | Where-Object { -not [bool]$_.ok })

$report = [ordered]@{
    machineTag = "RCCP_ACTION_REGISTRY_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    pass = ($actionRegistryOk -and $failedChecks.Count -eq 0)
    docsDispatchPath = "docs/治理/策略/rccp-entry-dispatch.json"
    policyDispatchPath = "policies/rccp-entry-dispatch.json"
    entryPath = "scripts/rccp/rccp.ps1"
    distributionProfile = [string]$distributionProfileName
    requireAllLeafScripts = [bool]$RequireAllLeafScripts
    registeredActionCount = [int]@($registeredActions).Count
    requiredLeafActionCount = [int]$requiredLeafActions.Count
    missingScriptCount = [int]$missingScripts.Count
    missingRequiredScriptCount = [int]$missingRequiredScripts.Count
    missingScripts = @($missingScripts.ToArray())
    missingRequiredScripts = @($missingRequiredScripts.ToArray())
    checks = @($checks.ToArray())
    evidencePath = "docs/治理/最新态/action-registry-check-latest.json"
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action thin-entry-check -Task `"$Task`" -Strict"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($report | ConvertTo-Json -Depth 20)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Action Registry Check") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- task: {0}" -f $report.task)) | Out-Null
$verdictText = if ([bool]$report.pass) { "PASS" } else { "FAIL" }
$md.Add(("- verdict: {0}" -f $verdictText)) | Out-Null
$md.Add(("- registeredActionCount: {0}" -f $report.registeredActionCount)) | Out-Null
$md.Add(("- requiredLeafActionCount: {0}" -f $report.requiredLeafActionCount)) | Out-Null
$md.Add(("- missingScriptCount: {0}" -f $report.missingScriptCount)) | Out-Null
$md.Add(("- missingRequiredScriptCount: {0}" -f $report.missingRequiredScriptCount)) | Out-Null
$md.Add("") | Out-Null
$md.Add("## Checks") | Out-Null
foreach ($item in @($checks.ToArray())) {
    $md.Add(("- {0}: {1} ({2})" -f $item.name, $(if ([bool]$item.ok) { "PASS" } else { "FAIL" }), $item.detail)) | Out-Null
}
$md.Add("") | Out-Null
$md.Add("## Missing Scripts") | Out-Null
$md.Add("") | Out-Null
$md.Add("### Required") | Out-Null
if ($missingRequiredScripts.Count -eq 0) {
    $md.Add("- none") | Out-Null
}
else {
    foreach ($item in @($missingRequiredScripts.ToArray())) {
        $md.Add(("- {0}" -f $item)) | Out-Null
    }
}
$md.Add("") | Out-Null
$md.Add("### Registered") | Out-Null
if ($missingScripts.Count -eq 0) {
    $md.Add("- none") | Out-Null
}
else {
    foreach ($item in @($missingScripts.ToArray())) {
        $md.Add(("- {0}" -f $item)) | Out-Null
    }
}
$md.Add("") | Out-Null
$md.Add("## Next") | Out-Null
$md.Add(("- {0}" -f $report.nextCommand)) | Out-Null
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md)))

if ($Json) {
    $report | ConvertTo-Json -Depth 20
}
else {
    Write-Host ("action-registry-check completed: pass={0}, missingScripts={1}, latest='{2}'" -f [bool]$report.pass, [int]$report.missingScriptCount, $latestJsonPath) -ForegroundColor $(if ([bool]$report.pass) { "Green" } else { "Red" })
}

if ($Strict -and -not [bool]$report.pass) {
    exit 1
}
