[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "external-capability-license-check",
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
$policy = Read-Text -Path "docs/治理/策略/external-capability-intake.md"
$adapter = Read-Text -Path "docs/adapters/code-context-adapter.md"
$runtime = Read-Text -Path "docs/adapters/runtime-bridge.md"

Add-Check -Checks $checks -Name "intake-policy-present" -Ok (Test-Path -LiteralPath "docs/治理/策略/external-capability-intake.md" -PathType Leaf) -Detail "docs/治理/策略/external-capability-intake.md"
Add-Check -Checks $checks -Name "gitnexus-boundary" -Ok (Test-ContainsAll -Text $policy -Terms @("GitNexus", "concept", "no source copy")) -Detail "GitNexus intake is concept/interface only"
Add-Check -Checks $checks -Name "multica-boundary" -Ok (Test-ContainsAll -Text $policy -Terms @("Multica", "optional bridge", "no hosted platform import")) -Detail "Multica intake is bridge/model only"
Add-Check -Checks $checks -Name "external-dependency-boundary" -Ok (Test-ContainsAll -Text ($adapter + $runtime) -Terms @("optional", "external", "closeout")) -Detail "external providers remain optional and non-authoritative"
Add-Check -Checks $checks -Name "no-vendored-external-source" -Ok (-not (Test-Path -LiteralPath "vendor/GitNexus") -and -not (Test-Path -LiteralPath "vendor/multica")) -Detail "no GitNexus or Multica source is vendored"

$failureCount = @($checks.ToArray() | Where-Object { -not [bool]$_.ok }).Count
$verdict = if ($failureCount -gt 0) { "FAIL" } else { "PASS" }
$latestJsonPath = Join-Path $OutDir "external-capability-license-check-latest.json"
$latestMdPath = Join-Path $OutDir "external-capability-license-check-latest.md"
$payload = [ordered]@{
    machineTag = "RCCP_EXTERNAL_CAPABILITY_LICENSE_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    verdict = [string]$verdict
    pass = ($failureCount -eq 0)
    failureCount = [int]$failureCount
    checks = @($checks.ToArray())
    evidencePath = ($latestJsonPath -replace "\\", "/")
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action code-context-contract-check -Task `"$Task`" -Strict"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 20)
$md = @("# External Capability License Check", "", "- task: $($payload.task)", "- verdict: $($payload.verdict)", "- failureCount: $($payload.failureCount)", "", "## Checks")
foreach ($item in @($checks.ToArray())) { $md += ("- {0}: {1} ({2})" -f $item.name, $(if ([bool]$item.ok) { "PASS" } else { "FAIL" }), $item.detail) }
$md += @("", "## Next", "- $($payload.nextCommand)")
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md)) + "`n")
if ($Json) { $payload | ConvertTo-Json -Depth 20 } else { Write-Host ("external-capability-license-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Red" }) }
if ($Strict -and $failureCount -gt 0) { exit 1 }
