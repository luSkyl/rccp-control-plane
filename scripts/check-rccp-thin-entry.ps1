[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "rccp-thin-entry-check",
    [string]$OutDir = "docs/治理/最新态",
    [switch]$Strict,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

function Write-Utf8NoBom {
    Param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Content)
    $normalized = $Content -replace "`r`n", "`n" -replace "`r", "`n"
    [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false)))
}

$entryPath = Join-Path $repoRoot "scripts/rccp/rccp.ps1"
$dispatchPath = Join-Path $repoRoot "docs/治理/策略/rccp-entry-dispatch.json"
$bundlePath = Join-Path $repoRoot "docs/治理/策略/rccp-policy-bundle.json"
$schemaPath = Join-Path $repoRoot "docs/治理/策略/rccp-evidence-schema.json"
$taskGraphPath = Join-Path $repoRoot "docs/治理/策略/rccp-agent-task-graph-schema.json"
$retiredPath = Join-Path $repoRoot "docs/治理/策略/retired-entrypoints.json"

$entryText = if (Test-Path -LiteralPath $entryPath) { Get-Content -LiteralPath $entryPath -Encoding UTF8 -Raw } else { "" }
$dispatch = if (Test-Path -LiteralPath $dispatchPath) { Get-Content -LiteralPath $dispatchPath -Encoding UTF8 -Raw | ConvertFrom-Json } else { $null }

$violations = New-Object System.Collections.Generic.List[object]
foreach ($path in @($dispatchPath, $bundlePath, $schemaPath, $taskGraphPath, $retiredPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        $violations.Add([ordered]@{ path = $path; reason = "MISSING_POLICY_ARTIFACT"; detail = $path }) | Out-Null
    }
}

$entryLineCount = ($entryText -split "`r?`n").Count
if ($entryLineCount -gt 80) {
    $violations.Add([ordered]@{ path = "scripts/rccp/rccp.ps1"; reason = "ENTRY_TOO_THICK"; detail = ("lineCountApprox={0}" -f $entryLineCount) }) | Out-Null
}
foreach ($pattern in @("Invoke-RccpEntry", "Rccp.Entry.psm1", "RemainingArgs")) {
    if (-not [regex]::IsMatch($entryText, [regex]::Escape($pattern), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $violations.Add([ordered]@{ path = "scripts/rccp/rccp.ps1"; reason = "ENTRY_MISSING_THIN_MARKER"; detail = $pattern }) | Out-Null
    }
}
if ($entryText -match 'Set-Content|Add-Content|Out-File|WriteAllText|AppendAllText') {
    $violations.Add([ordered]@{ path = "scripts/rccp/rccp.ps1"; reason = "ENTRY_DIRECT_WRITE"; detail = "entry script must not write state directly" }) | Out-Null
}
if ($null -ne $dispatch) {
    if ([string]::IsNullOrWhiteSpace([string]$dispatch.canonicalEntry) -or -not [string]::Equals([string]$dispatch.canonicalEntry, "scripts/rccp/rccp.ps1", [System.StringComparison]::OrdinalIgnoreCase)) {
        $violations.Add([ordered]@{ path = $dispatchPath; reason = "DISPATCH_CANONICAL_ENTRY_MISMATCH"; detail = [string]$dispatch.canonicalEntry }) | Out-Null
    }
    if (@($dispatch.retiredArtifacts).Count -lt 2) {
        $violations.Add([ordered]@{ path = $dispatchPath; reason = "RETIRED_ARTIFACTS_INCOMPLETE"; detail = "retired artifacts should include ops.ps1 and legacy report docs" }) | Out-Null
    }
}

$report = [ordered]@{
    machineTag = "RCCP_THIN_ENTRY_CHECK_V1"
    generatedAt = (Get-Date).ToString("s")
    task = $Task
    pass = ($violations.Count -eq 0)
    entryPath = "scripts/rccp/rccp.ps1"
    dispatchPath = "docs/治理/策略/rccp-entry-dispatch.json"
    policyBundlePath = "docs/治理/策略/rccp-policy-bundle.json"
    evidenceSchemaPath = "docs/治理/策略/rccp-evidence-schema.json"
    taskGraphSchemaPath = "docs/治理/策略/rccp-agent-task-graph-schema.json"
    retiredEntrypointsPath = "docs/治理/策略/retired-entrypoints.json"
    violationCount = [int]$violations.Count
    violations = @($violations.ToArray())
}

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$jsonPath = Join-Path $OutDir ("rccp-thin-entry-check-{0}.json" -f $stamp)
$latestJsonPath = Join-Path $OutDir "rccp-thin-entry-check-latest.json"
Write-Utf8NoBom -Path $jsonPath -Content ($report | ConvertTo-Json -Depth 16)
Write-Utf8NoBom -Path $latestJsonPath -Content ($report | ConvertTo-Json -Depth 16)

if ($Json) {
    $report | ConvertTo-Json -Depth 16
}
else {
    Write-Host ("rccp-thin-entry-check completed: pass={0}, violations={1}, latest='{2}'" -f [bool]$report.pass, [int]$violations.Count, $latestJsonPath) -ForegroundColor Green
}

if ($Strict -and -not [bool]$report.pass) {
    throw ("rccp-thin-entry-check failed: violations={0}; latest={1}" -f [int]$violations.Count, $latestJsonPath)
}
