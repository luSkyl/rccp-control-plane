[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "memory-layer-contract-check",
    [string]$TargetPaths = "",
    [string]$EvidencePaths = "",
    [string]$SuggestionId = "",
    [string]$IssueId = "",
    [string]$ProgressId = "",
    [string]$RecentSection = "",
    [ValidateSet("Staged", "All")]
    [string]$Mode = "Staged",
    [string]$GateProfile = "Fast",
    [string]$OutDir = "docs/治理/最新态",
    [string]$ContractPath = "docs/memory-layer.md",
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

function Normalize-PathText {
    Param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    return ([string]$Path).Replace("\", "/").Trim()
}

function Split-PackedList {
    Param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    return @($Value -split "[;,]" | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Read-Text {
    Param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
}

function Read-JsonFileOrNull {
    Param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
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
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$targetPathList = @(Split-PackedList -Value $TargetPaths)
$evidencePathList = @(Split-PackedList -Value $EvidencePaths)

$contractFullPath = if ([System.IO.Path]::IsPathRooted($ContractPath)) { $ContractPath } else { Join-Path $repoRoot $ContractPath }
$briefingScriptPath = Join-Path $repoRoot "scripts/invoke-memory-briefing.ps1"
$dispatchPath = Join-Path $repoRoot "docs/治理/策略/rccp-entry-dispatch.json"
$policyDispatchPath = Join-Path $repoRoot "policies/rccp-entry-dispatch.json"
$latestJsonPath = Join-Path $OutDir "memory-layer-contract-latest.json"
$latestMdPath = Join-Path $OutDir "memory-layer-contract-latest.md"

$checks = New-Object System.Collections.Generic.List[object]
$contractText = Read-Text -Path $contractFullPath
$dispatch = Read-JsonFileOrNull -Path $dispatchPath
$policyDispatch = Read-JsonFileOrNull -Path $policyDispatchPath

$layerNames = @("identity", "project", "task", "review", "evolution")
Add-Check -Checks $checks -Name "contract-file" -Ok (-not [string]::IsNullOrWhiteSpace($contractText)) -Detail (Normalize-PathText $contractFullPath)
Add-Check -Checks $checks -Name "briefing-script" -Ok (Test-Path -LiteralPath $briefingScriptPath -PathType Leaf) -Detail (Normalize-PathText $briefingScriptPath)

$dispatchOk = $false
if ($null -ne $dispatch -and $null -ne $dispatch.entryDispatch) {
    $entryNames = @($dispatch.entryDispatch.PSObject.Properties.Name)
    $dispatchOk = $entryNames -contains "memory-briefing" -and $entryNames -contains "memory-layer-contract-check"
}
Add-Check -Checks $checks -Name "rccp-dispatch" -Ok $dispatchOk -Detail (Normalize-PathText $dispatchPath)

$policyDispatchOk = $false
if ($null -ne $policyDispatch -and $null -ne $policyDispatch.entryDispatch) {
    $policyEntryNames = @($policyDispatch.entryDispatch.PSObject.Properties.Name)
    $policyDispatchOk = $policyEntryNames -contains "memory-briefing" -and $policyEntryNames -contains "memory-layer-contract-check"
}
Add-Check -Checks $checks -Name "policy-dispatch" -Ok $policyDispatchOk -Detail (Normalize-PathText $policyDispatchPath)

$layerOk = $true
foreach ($layer in @($layerNames)) {
    $layerOk = $layerOk -and ($contractText -match [regex]::Escape($layer))
}
Add-Check -Checks $checks -Name "layer-contract" -Ok $layerOk -Detail "layers=$($layerNames -join ',')"

$publicBoundaryOk = $true
foreach ($path in @($briefingScriptPath, $contractFullPath)) {
    $text = Read-Text -Path $path
    if ($text -match "第二大脑|黑灰产|开发执行与优化进度|建议池") {
        $publicBoundaryOk = $false
    }
}
Add-Check -Checks $checks -Name "public-boundary" -Ok $publicBoundaryOk -Detail "memory layer artifacts do not depend on source repository private docs"

if ($Strict) {
    $briefingArgs = @(
        "-Task", $Task,
        "-TargetPaths", ([string]$TargetPaths),
        "-EvidencePaths", ([string]$EvidencePaths),
        "-Mode", $Mode,
        "-GateProfile", $GateProfile
    )
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $briefingScriptPath @briefingArgs | Out-Null
    $briefingOk = ($LASTEXITCODE -eq 0)
    Add-Check -Checks $checks -Name "briefing-strict-run" -Ok $briefingOk -Detail (Normalize-PathText (Join-Path $OutDir "memory-briefing-latest.json"))
}

$failureCount = @($checks | Where-Object { -not [bool]$_.ok }).Count
$verdict = if ($failureCount -gt 0) { "FAIL" } else { "PASS" }

$payload = [ordered]@{
    machineTag = "MEMORY_LAYER_CONTRACT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    mode = [string]$Mode
    gateProfile = [string]$GateProfile
    targetPaths = @($targetPathList)
    evidencePaths = @($evidencePathList)
    contractPath = Normalize-PathText $contractFullPath
    briefingScriptPath = Normalize-PathText $briefingScriptPath
    dispatchPath = Normalize-PathText $dispatchPath
    policyDispatchPath = Normalize-PathText $policyDispatchPath
    checks = @($checks.ToArray())
    failureCount = [int]$failureCount
    verdict = [string]$verdict
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action memory-briefing -Task `"$Task`" -TargetPaths `"$TargetPaths`" -Mode $Mode"
    evidencePath = Normalize-PathText $latestJsonPath
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 20)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Memory Layer Contract Check") | Out-Null
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
$md.Add("## Layers") | Out-Null
foreach ($layer in @($layerNames)) { $md.Add(("- {0}" -f $layer)) | Out-Null }
$md.Add("") | Out-Null
$md.Add("## Next") | Out-Null
$md.Add(("- {0}" -f $payload.nextCommand)) | Out-Null
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md)))

if ($Json) { $payload | ConvertTo-Json -Depth 20 }
else { Write-Host ("memory-layer-contract-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor Green }

if ($failureCount -gt 0) { exit 1 }
