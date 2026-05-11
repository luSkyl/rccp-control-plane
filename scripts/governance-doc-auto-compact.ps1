[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "governance-doc-auto-compact",
    [string]$RunMode = "task-start",
    [string]$OutDir = "docs/治理/最新态",
    [switch]$ForceWhenTriggered,
    [switch]$HardFailOnUnresolved,
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

function Read-JsonFile {
    Param([Parameter(Mandatory = $true)][string]$Path)
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Normalize-JsonText {
    Param([Parameter(Mandatory = $true)][object]$Value)
    return (($Value | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$mirrorPairs = @(
    @{ label = "entry-dispatch"; policy = "policies/rccp-entry-dispatch.json"; docs = "docs/治理/策略/rccp-entry-dispatch.json" },
    @{ label = "kit-manifest"; policy = "policies/rccp-kit-manifest.json"; docs = "docs/治理/策略/rccp-kit-manifest.json" },
    @{ label = "project-contract"; policy = "policies/rccp-project-contract.json"; docs = "docs/治理/策略/rccp-project-contract.json" }
)

$blockingFailures = New-Object System.Collections.Generic.List[string]
$mirrorChecks = New-Object System.Collections.Generic.List[object]

foreach ($pair in @($mirrorPairs)) {
    $policyPath = [string]$pair.policy
    $docsPath = [string]$pair.docs
    if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
        $blockingFailures.Add(("MISSING_POLICY: {0}" -f $policyPath)) | Out-Null
        $mirrorChecks.Add([ordered]@{ label = [string]$pair.label; ok = $false; detail = "missing policy" }) | Out-Null
        continue
    }
    if (-not (Test-Path -LiteralPath $docsPath -PathType Leaf)) {
        $blockingFailures.Add(("MISSING_DOC_MIRROR: {0}" -f $docsPath)) | Out-Null
        $mirrorChecks.Add([ordered]@{ label = [string]$pair.label; ok = $false; detail = "missing docs mirror" }) | Out-Null
        continue
    }
    $policy = Read-JsonFile -Path $policyPath
    $docs = Read-JsonFile -Path $docsPath
    $policyText = Normalize-JsonText -Value $policy
    $docsText = Normalize-JsonText -Value $docs
    $ok = [string]::Equals($policyText, $docsText, [System.StringComparison]::Ordinal)
    $detail = if ($ok) { "mirrors aligned" } else { "policy/docs mirror drift" }
    $mirrorChecks.Add([ordered]@{ label = [string]$pair.label; ok = [bool]$ok; detail = $detail }) | Out-Null
    if (-not $ok -and $HardFailOnUnresolved) {
        $blockingFailures.Add(("MIRROR_DRIFT:{0}" -f [string]$pair.label)) | Out-Null
    }
}

$pass = ($blockingFailures.Count -eq 0)
$latestJsonPath = Join-Path $OutDir "governance-doc-auto-compact-latest.json"
$latestMdPath = Join-Path $OutDir "governance-doc-auto-compact-latest.md"
$payload = [ordered]@{
    machineTag = "RCCP_GOVERNANCE_DOC_AUTO_COMPACT_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    runMode = [string]$RunMode
    pass = [bool]$pass
    semanticPass = [bool]$pass
    forceWhenTriggered = [bool]$ForceWhenTriggered
    hardFailOnUnresolved = [bool]$HardFailOnUnresolved
    mirrorChecks = @($mirrorChecks.ToArray())
    blockingFailures = @($blockingFailures.ToArray())
    evidencePath = "docs/治理/最新态/governance-doc-auto-compact-latest.json"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)
$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Governance Doc Auto Compact") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- task: {0}" -f $Task)) | Out-Null
$md.Add(("- runMode: {0}" -f $RunMode)) | Out-Null
$md.Add(("- pass: {0}" -f [bool]$pass)) | Out-Null
if ($blockingFailures.Count -gt 0) {
    $md.Add("") | Out-Null
    $md.Add("## Blocking Failures") | Out-Null
    foreach ($item in @($blockingFailures.ToArray())) {
        $md.Add(("- {0}" -f $item)) | Out-Null
    }
}
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())))

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("governance-doc-auto-compact completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
