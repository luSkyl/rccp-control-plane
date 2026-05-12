[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "code-context-contract-check",
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

function Add-Check {
    Param([System.Collections.Generic.List[object]]$Checks, [string]$Name, [bool]$Ok, [string]$Detail)
    $Checks.Add([ordered]@{ name = $Name; ok = [bool]$Ok; detail = [string]$Detail }) | Out-Null
}

function Test-ContainsAll {
    Param([string]$Text, [string[]]$Terms)
    foreach ($term in @($Terms)) {
        if ($Text.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    }
    return $true
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$checks = New-Object System.Collections.Generic.List[object]
$requiredFiles = @(
    "docs/adapters/code-context-adapter.md",
    "docs/adapters/runtime-bridge.md",
    "docs/治理/策略/external-capability-intake.md",
    "schemas/rccp-code-context.schema.json",
    "schemas/rccp-runtime-bridge.schema.json",
    "scripts/check-code-context-snapshot.ps1",
    "scripts/check-code-context-contract.ps1",
    "scripts/check-runtime-bridge-contract.ps1",
    "scripts/check-external-capability-license.ps1"
)
foreach ($path in @($requiredFiles)) {
    Add-Check -Checks $checks -Name ("file-present:{0}" -f $path) -Ok (Test-Path -LiteralPath $path -PathType Leaf) -Detail $path
}

$adapterDoc = Read-Text -Path "docs/adapters/code-context-adapter.md"
$runtimeDoc = Read-Text -Path "docs/adapters/runtime-bridge.md"
$intakeDoc = Read-Text -Path "docs/治理/策略/external-capability-intake.md"
$contextSchema = Get-Content -LiteralPath "schemas/rccp-code-context.schema.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$runtimeSchema = Get-Content -LiteralPath "schemas/rccp-runtime-bridge.schema.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$dispatch = Get-Content -LiteralPath "docs/治理/策略/rccp-entry-dispatch.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$policyDispatch = Get-Content -LiteralPath "policies/rccp-entry-dispatch.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$workflow = Read-Text -Path "docs/multi-agent-workflow.md"

Add-Check -Checks $checks -Name "adapter-doc-contract" -Ok (Test-ContainsAll -Text $adapterDoc -Terms @("Code Context Adapter", "builtin-lite", "gitnexus-mcp", "contextPackPath", "closeout")) -Detail "adapter doc describes providers, context packs, and authority boundary"
Add-Check -Checks $checks -Name "runtime-doc-contract" -Ok (Test-ContainsAll -Text $runtimeDoc -Terms @("Runtime Bridge", "createTask", "completeTask", "closeout")) -Detail "runtime bridge remains optional and non-authoritative"
Add-Check -Checks $checks -Name "intake-policy-contract" -Ok (Test-ContainsAll -Text $intakeDoc -Terms @("GitNexus", "Multica", "License Gate", "no hard dependency")) -Detail "external intake policy records boundary and license gate"
Add-Check -Checks $checks -Name "context-schema-contract" -Ok (
    [string]::Equals([string]$contextSchema.machineTag, "RCCP_CODE_CONTEXT_SCHEMA_V1", [System.StringComparison]::OrdinalIgnoreCase) -and
    (@($contextSchema.providers) -contains "builtin-lite") -and
    (@($contextSchema.providers) -contains "gitnexus-mcp") -and
    (-not [bool]$contextSchema.externalDependencyRequired)
) -Detail "context schema is optional and provider-aware"
Add-Check -Checks $checks -Name "runtime-schema-contract" -Ok (
    [string]::Equals([string]$runtimeSchema.machineTag, "RCCP_RUNTIME_BRIDGE_SCHEMA_V1", [System.StringComparison]::OrdinalIgnoreCase) -and
    (@($runtimeSchema.operations) -contains "completeTask") -and
    (-not [bool]$runtimeSchema.closeoutAllowedForExternalRuntime)
) -Detail "runtime schema forbids external closeout authority"

$requiredActions = @("code-context-snapshot", "code-context-contract-check", "runtime-bridge-contract-check", "external-capability-license-check")
$entryNames = @($dispatch.entryDispatch.PSObject.Properties.Name)
$policyEntryNames = @($policyDispatch.entryDispatch.PSObject.Properties.Name)
$surfaceNames = @($dispatch.actionSurface.readonly)
$actionsOk = $true
foreach ($name in @($requiredActions)) {
    $actionsOk = $actionsOk -and ($entryNames -contains $name) -and ($policyEntryNames -contains $name) -and ($surfaceNames -contains $name)
}
Add-Check -Checks $checks -Name "dispatch-actions" -Ok $actionsOk -Detail ($requiredActions -join ",")
Add-Check -Checks $checks -Name "workflow-link" -Ok (Test-ContainsAll -Text $workflow -Terms @("contextPackPath", "Code Context Adapter", "Runtime Bridge")) -Detail "multi-agent workflow references context adapter and bridge"

if ($Strict) {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File "scripts/check-code-context-snapshot.ps1" -Task $Task -TargetPaths "docs/adapters" | Out-Null
    Add-Check -Checks $checks -Name "snapshot-strict-run" -Ok ($LASTEXITCODE -eq 0) -Detail "docs/治理/最新态/code-context-snapshot-latest.json"
}

$failureCount = @($checks.ToArray() | Where-Object { -not [bool]$_.ok }).Count
$verdict = if ($failureCount -gt 0) { "FAIL" } else { "PASS" }
$latestJsonPath = Join-Path $OutDir "code-context-contract-check-latest.json"
$latestMdPath = Join-Path $OutDir "code-context-contract-check-latest.md"
$payload = [ordered]@{
    machineTag = "RCCP_CODE_CONTEXT_CONTRACT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    verdict = [string]$verdict
    pass = ($failureCount -eq 0)
    failureCount = [int]$failureCount
    requiredFiles = @($requiredFiles)
    requiredActions = @($requiredActions)
    checks = @($checks.ToArray())
    evidencePath = ($latestJsonPath -replace "\\", "/")
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action runtime-bridge-contract-check -Task `"$Task`" -Strict"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 20)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Code Context Contract Check") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- task: {0}" -f $payload.task)) | Out-Null
$md.Add(("- verdict: {0}" -f $payload.verdict)) | Out-Null
$md.Add(("- failureCount: {0}" -f $payload.failureCount)) | Out-Null
$md.Add("") | Out-Null
$md.Add("## Checks") | Out-Null
foreach ($item in @($checks.ToArray())) { $md.Add(("- {0}: {1} ({2})" -f $item.name, $(if ([bool]$item.ok) { "PASS" } else { "FAIL" }), $item.detail)) | Out-Null }
$md.Add("") | Out-Null
$md.Add("## Next") | Out-Null
$md.Add(("- {0}" -f $payload.nextCommand)) | Out-Null
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())) + "`n")

if ($Json) { $payload | ConvertTo-Json -Depth 20 }
else { Write-Host ("code-context-contract-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Red" }) }
if ($Strict -and $failureCount -gt 0) { exit 1 }
