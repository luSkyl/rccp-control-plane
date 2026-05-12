[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "runtime-bridge-contract-check",
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
function Read-Text { Param([string]$Path) if (Test-Path -LiteralPath $Path -PathType Leaf) { Get-Content -LiteralPath $Path -Encoding UTF8 -Raw } else { "" } }
function Add-Check { Param([System.Collections.Generic.List[object]]$Checks,[string]$Name,[bool]$Ok,[string]$Detail) $Checks.Add([ordered]@{name=$Name;ok=[bool]$Ok;detail=[string]$Detail}) | Out-Null }
function Test-ContainsAll { Param([string]$Text,[string[]]$Terms) foreach($term in @($Terms)){ if($Text.IndexOf($term,[System.StringComparison]::OrdinalIgnoreCase) -lt 0){ return $false }} return $true }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$checks = New-Object System.Collections.Generic.List[object]
$doc = Read-Text -Path "docs/adapters/runtime-bridge.md"
$schema = Get-Content -LiteralPath "schemas/rccp-runtime-bridge.schema.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$workflow = Read-Text -Path "docs/multi-agent-workflow.md"

Add-Check -Checks $checks -Name "file-present:runtime-doc" -Ok (Test-Path -LiteralPath "docs/adapters/runtime-bridge.md" -PathType Leaf) -Detail "docs/adapters/runtime-bridge.md"
Add-Check -Checks $checks -Name "file-present:runtime-schema" -Ok (Test-Path -LiteralPath "schemas/rccp-runtime-bridge.schema.json" -PathType Leaf) -Detail "schemas/rccp-runtime-bridge.schema.json"
Add-Check -Checks $checks -Name "runtime-doc-boundary" -Ok (Test-ContainsAll -Text $doc -Terms @("optional", "External runtimes are never closeout authorities", "handoff evidence")) -Detail "bridge is optional and non-authoritative"
Add-Check -Checks $checks -Name "runtime-operations" -Ok (@($schema.operations).Count -eq 5 -and (@($schema.operations) -contains "reportBlocker") -and (@($schema.operations) -contains "completeTask")) -Detail "bridge operations cover task lifecycle and handoff"
Add-Check -Checks $checks -Name "runtime-closeout-forbidden" -Ok (-not [bool]$schema.closeoutAllowedForExternalRuntime) -Detail "external runtime closeout is forbidden"
Add-Check -Checks $checks -Name "workflow-runtime-boundary" -Ok (Test-ContainsAll -Text $workflow -Terms @("Runtime Bridge", "external runtime", "closeout")) -Detail "workflow documents runtime bridge authority boundary"

$failureCount = @($checks.ToArray() | Where-Object { -not [bool]$_.ok }).Count
$verdict = if ($failureCount -gt 0) { "FAIL" } else { "PASS" }
$latestJsonPath = Join-Path $OutDir "runtime-bridge-contract-check-latest.json"
$latestMdPath = Join-Path $OutDir "runtime-bridge-contract-check-latest.md"
$payload = [ordered]@{
    machineTag = "RCCP_RUNTIME_BRIDGE_CONTRACT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    verdict = [string]$verdict
    pass = ($failureCount -eq 0)
    failureCount = [int]$failureCount
    checks = @($checks.ToArray())
    evidencePath = ($latestJsonPath -replace "\\", "/")
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action external-capability-license-check -Task `"$Task`" -Strict"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 20)
$md = @("# Runtime Bridge Contract Check", "", "- task: $($payload.task)", "- verdict: $($payload.verdict)", "- failureCount: $($payload.failureCount)", "", "## Checks")
foreach ($item in @($checks.ToArray())) { $md += ("- {0}: {1} ({2})" -f $item.name, $(if ([bool]$item.ok) { "PASS" } else { "FAIL" }), $item.detail) }
$md += @("", "## Next", "- $($payload.nextCommand)")
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md)) + "`n")
if ($Json) { $payload | ConvertTo-Json -Depth 20 } else { Write-Host ("runtime-bridge-contract-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Red" }) }
if ($Strict -and $failureCount -gt 0) { exit 1 }
