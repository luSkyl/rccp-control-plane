[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "multi-agent-contract-check",
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

function Read-JsonOrNull {
    Param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Normalize-JsonText {
    Param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "" }
    return (($Value | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
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

$requiredFiles = @(
    "docs/multi-agent-workflow.md",
    "schemas/rccp-work-order.schema.json",
    "docs/治理/策略/rccp-work-order.schema.json",
    "policies/rccp-agent-task-graph-schema.json",
    "docs/治理/策略/rccp-agent-task-graph-schema.json",
    "examples/multi-agent-repo/README.md",
    "scripts/check-multi-agent-contract.ps1",
    "scripts/rccp/Rccp.Core.psm1",
    "policies/rccp-entry-dispatch.json",
    "docs/治理/策略/rccp-entry-dispatch.json"
)

$checks = New-Object System.Collections.Generic.List[object]
foreach ($path in @($requiredFiles)) {
    Add-Check -Checks $checks -Name ("file-present:{0}" -f $path) -Ok (Test-Path -LiteralPath $path -PathType Leaf) -Detail $path
}

$workflowDoc = Read-Text -Path "docs/multi-agent-workflow.md"
$exampleDoc = Read-Text -Path "examples/multi-agent-repo/README.md"
$coreText = Read-Text -Path "scripts/rccp/Rccp.Core.psm1"
$workOrderSchema = Read-JsonOrNull -Path "schemas/rccp-work-order.schema.json"
$workOrderSchemaMirror = Read-JsonOrNull -Path "docs/治理/策略/rccp-work-order.schema.json"
$taskGraph = Read-JsonOrNull -Path "policies/rccp-agent-task-graph-schema.json"
$taskGraphMirror = Read-JsonOrNull -Path "docs/治理/策略/rccp-agent-task-graph-schema.json"
$dispatch = Read-JsonOrNull -Path "policies/rccp-entry-dispatch.json"
$dispatchMirror = Read-JsonOrNull -Path "docs/治理/策略/rccp-entry-dispatch.json"

Add-Check -Checks $checks -Name "workflow-doc-contract" -Ok (Test-ContainsAll -Text $workflowDoc -Terms @("Main agent", "Worker agent", "Verifier agent", "work order", "ownership-claim", "execution-card", "subAgentEvidence", "closeout-atomic", "sub_agent_must_not_closeout")) -Detail "public workflow names roles, ownership, execution card, evidence, and closeout boundary"
Add-Check -Checks $checks -Name "example-work-order" -Ok (Test-ContainsAll -Text $exampleDoc -Terms @("main-agent", "worker-agent", "verifier-agent", "allowedPaths", "forbiddenActions", "closeoutAllowed", "subAgentEvidence")) -Detail "example repository shows bounded work order and role split"

$requiredSchemaFields = @("workOrderId", "parentTask", "actorRole", "objective", "allowedPaths", "forbiddenActions", "acceptanceCriteria", "evidenceRequired", "handoffFormat", "closeoutAllowed", "expiresAt")
$schemaFields = if ($null -ne $workOrderSchema) { Get-StringArray -Value $workOrderSchema.requiredFields } else { @() }
$schemaFieldsOk = $true
foreach ($field in @($requiredSchemaFields)) {
    if ($schemaFields -notcontains $field) { $schemaFieldsOk = $false }
}
Add-Check -Checks $checks -Name "work-order-required-fields" -Ok $schemaFieldsOk -Detail ("required={0}" -f [string]::Join(",", @($requiredSchemaFields)))
Add-Check -Checks $checks -Name "work-order-schema-mirror" -Ok ([string]::Equals((Normalize-JsonText $workOrderSchema), (Normalize-JsonText $workOrderSchemaMirror), [System.StringComparison]::Ordinal)) -Detail "schemas and docs strategy mirror must match"

$taskGraphNodes = if ($null -ne $taskGraph) { Get-StringArray -Value $taskGraph.nodeTypes } else { @() }
$taskGraphInvariants = if ($null -ne $taskGraph) { Get-StringArray -Value $taskGraph.invariants } else { @() }
$taskGraphOk = ($taskGraphNodes -contains "WorkOrderIssued" -and $taskGraphInvariants -contains "sub_agent_must_not_closeout")
Add-Check -Checks $checks -Name "task-graph-work-order" -Ok $taskGraphOk -Detail "task graph includes WorkOrderIssued and sub_agent_must_not_closeout"
Add-Check -Checks $checks -Name "task-graph-mirror" -Ok ([string]::Equals((Normalize-JsonText $taskGraph), (Normalize-JsonText $taskGraphMirror), [System.StringComparison]::Ordinal)) -Detail "policy and docs task graph mirrors must match"

$coreOk = (Test-ContainsAll -Text $coreText -Terms @("Test-RccpWorkOrderContract", "SUB_AGENT_CLOSEOUT_FORBIDDEN", "UNAUTHORIZED_PATH", "Export-ModuleMember"))
Add-Check -Checks $checks -Name "core-work-order-guard" -Ok $coreOk -Detail "core exports the sub-agent closeout and path guard"

$availableActions = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
if ($null -ne $dispatch) {
    foreach ($name in @($dispatch.entryDispatch.PSObject.Properties.Name)) { [void]$availableActions.Add([string]$name) }
    foreach ($name in @(Get-StringArray -Value $dispatch.coreActions)) { [void]$availableActions.Add([string]$name) }
    foreach ($surface in @("readonly", "write", "runtimeWrite", "closeoutWrite")) {
        foreach ($name in @(Get-StringArray -Value (Get-ObjectValue -Object $dispatch.actionSurface -Name $surface))) {
            [void]$availableActions.Add([string]$name)
        }
    }
}
$requiredActions = @("multi-agent-contract-check", "execution-card", "lease-acquire", "ownership-claim", "ownership-check", "closeout-atomic")
$missingActions = New-Object System.Collections.Generic.List[string]
foreach ($action in @($requiredActions)) {
    if (-not $availableActions.Contains($action)) { $missingActions.Add($action) | Out-Null }
}
Add-Check -Checks $checks -Name "dispatch-actions" -Ok ($missingActions.Count -eq 0) -Detail ($(if ($missingActions.Count -eq 0) { "required multi-agent actions are dispatchable" } else { [string]::Join(",", @($missingActions.ToArray())) }))
Add-Check -Checks $checks -Name "dispatch-mirror" -Ok ([string]::Equals((Normalize-JsonText $dispatch), (Normalize-JsonText $dispatchMirror), [System.StringComparison]::Ordinal)) -Detail "policy and docs dispatch mirrors must match"

$contractPositiveOk = $false
$contractNegativeOk = $false
try {
    Import-Module (Join-Path $repoRoot "scripts/rccp/Rccp.Core.psm1") -Force
    $positive = Test-RccpWorkOrderContract -ActorRole "sub-agent" -AllowedPaths @("docs/release-checklist.md") -RequestedPaths @("docs/release-checklist.md")
    $negative = Test-RccpWorkOrderContract -ActorRole "sub-agent" -AllowedPaths @("docs/release-checklist.md") -RequestedPaths @("README.md") -CloseoutRequested
    $contractPositiveOk = [bool]$positive.ok
    $contractNegativeOk = ((-not [bool]$negative.ok) -and (@($negative.violations) -contains "SUB_AGENT_CLOSEOUT_FORBIDDEN") -and (@($negative.violations) -contains "UNAUTHORIZED_PATH:README.md"))
}
catch {
    $contractPositiveOk = $false
    $contractNegativeOk = $false
}
Add-Check -Checks $checks -Name "work-order-positive-case" -Ok $contractPositiveOk -Detail "allowed sub-agent path without closeout passes"
Add-Check -Checks $checks -Name "work-order-negative-case" -Ok $contractNegativeOk -Detail "sub-agent closeout and unauthorized path are blocked"

$failureCount = @($checks.ToArray() | Where-Object { -not [bool]$_.ok }).Count
$verdict = if ($failureCount -gt 0) { "FAIL" } else { "PASS" }
$latestJsonPath = Join-Path $OutDir "multi-agent-contract-check-latest.json"
$latestMdPath = Join-Path $OutDir "multi-agent-contract-check-latest.md"

$payload = [ordered]@{
    machineTag = "RCCP_MULTI_AGENT_CONTRACT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    verdict = [string]$verdict
    pass = ($failureCount -eq 0)
    failureCount = [int]$failureCount
    requiredFiles = @($requiredFiles)
    requiredActions = @($requiredActions)
    checks = @($checks.ToArray())
    evidencePath = "docs/治理/最新态/multi-agent-contract-check-latest.json"
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action action-registry-check -Task `"$Task`" -RequireAllLeafScripts -Strict"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 20)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Multi-Agent Contract Check") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- task: {0}" -f $payload.task)) | Out-Null
$md.Add(("- verdict: {0}" -f $payload.verdict)) | Out-Null
$md.Add(("- failureCount: {0}" -f $payload.failureCount)) | Out-Null
$md.Add("") | Out-Null
$md.Add("## Checks") | Out-Null
foreach ($item in @($checks.ToArray())) {
    $md.Add(("- {0}: {1} ({2})" -f $item.name, $(if ([bool]$item.ok) { "PASS" } else { "FAIL" }), $item.detail)) | Out-Null
}
$md.Add("") | Out-Null
$md.Add("## Next") | Out-Null
$md.Add(("- {0}" -f $payload.nextCommand)) | Out-Null
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())) + "`n")

if ($Json) { $payload | ConvertTo-Json -Depth 20 }
else { Write-Host ("multi-agent-contract-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Red" }) }

if ($Strict -and $failureCount -gt 0) { exit 1 }
