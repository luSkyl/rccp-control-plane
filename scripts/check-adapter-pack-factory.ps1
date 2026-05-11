[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "adapter-pack-factory-check",
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
    "docs/adapters/adapter-pack-factory.md",
    "schemas/rccp-adapter-pack.schema.json",
    "docs/治理/策略/rccp-adapter-pack.schema.json",
    "adapters/adapter-pack-template.json",
    "examples/adapter-pack-template/README.md",
    "scripts/check-adapter-pack-factory.ps1"
)

$checks = New-Object System.Collections.Generic.List[object]
foreach ($path in @($requiredFiles)) {
    Add-Check -Checks $checks -Name ("file-present:{0}" -f $path) -Ok (Test-Path -LiteralPath $path -PathType Leaf) -Detail $path
}

$factoryDoc = Read-Text -Path "docs/adapters/adapter-pack-factory.md"
$rootReadmeExists = Test-Path -LiteralPath "README.md" -PathType Leaf
$releaseChecklistExists = Test-Path -LiteralPath "docs/release-checklist.md" -PathType Leaf
$ciWorkflowExists = Test-Path -LiteralPath ".github/workflows/rccp-ci.yml" -PathType Leaf
$rolloutScriptExists = Test-Path -LiteralPath "scripts/check-rccp-kit-rollout.ps1" -PathType Leaf
$rootReadme = Read-Text -Path "README.md"
$releaseChecklist = Read-Text -Path "docs/release-checklist.md"
$ciWorkflow = Read-Text -Path ".github/workflows/rccp-ci.yml"
$rolloutScript = Read-Text -Path "scripts/check-rccp-kit-rollout.ps1"
$kitManifest = Read-JsonOrNull -Path "policies/rccp-kit-manifest.json"
$kitManifestMirror = Read-JsonOrNull -Path "docs/治理/策略/rccp-kit-manifest.json"
$templateManifest = Read-JsonOrNull -Path "adapters/adapter-pack-template.json"
$schema = Read-JsonOrNull -Path "schemas/rccp-adapter-pack.schema.json"
$schemaMirror = Read-JsonOrNull -Path "docs/治理/策略/rccp-adapter-pack.schema.json"
$exampleDoc = Read-Text -Path "examples/adapter-pack-template/README.md"
$adaptersReadme = Read-Text -Path "docs/adapters/README.md"

Add-Check -Checks $checks -Name "factory-doc-contract" -Ok (Test-ContainsAll -Text $factoryDoc -Terms @("guide", "manifest", "example repo", "check script", "release and rollout", "java-vue", "docs-only", "obsidian-second-brain", "ai-context-gateway", "multi-agent-workflow")) -Detail "factory doc names the five-piece pattern and pack families"
Add-Check -Checks $checks -Name "adapters-readme-link" -Ok (Test-ContainsAll -Text $adaptersReadme -Terms @("Java + Vue Adapter", "Docs-Only Adapter", "Obsidian Second-Brain Adapter", "AI Context Gateway Adapter", "Multi-Agent Workflow", "Adapter Pack Factory")) -Detail "adapter index points to the public pack families and factory"
Add-Check -Checks $checks -Name "example-template-contract" -Ok (Test-ContainsAll -Text $exampleDoc -Terms @("guide -> manifest -> example -> check -> dispatch -> CI -> release checklist -> rollout", "Replace the placeholder pack name", "Replace the placeholder stack tags")) -Detail "template example shows copy checklist and lifecycle"
$releaseSurfaceAvailable = ($rootReadmeExists -and $releaseChecklistExists -and $ciWorkflowExists -and $rolloutScriptExists)
$releaseSurfaceOk = $true
$releaseSurfaceDetail = "source surface files are absent in installed bundle; release-surface link check skipped"
if ($releaseSurfaceAvailable) {
    $releaseSurfaceOk = (
        (Test-ContainsAll -Text $rootReadme -Terms @("adapter-pack-factory-check", "Adapter Pack Factory")) -and
        (Test-ContainsAll -Text $releaseChecklist -Terms @("adapter-pack-factory-check")) -and
        (Test-ContainsAll -Text $ciWorkflow -Terms @("adapter-pack-factory-check")) -and
        (Test-ContainsAll -Text $rolloutScript -Terms @("adapter-pack-factory-check-latest.json", "adapter-pack-factory-check"))
    )
    $releaseSurfaceDetail = "README, release checklist, CI, and rollout surface the pack factory check"
}
Add-Check -Checks $checks -Name "release-surface-links" -Ok $releaseSurfaceOk -Detail $releaseSurfaceDetail
Add-Check -Checks $checks -Name "kit-manifest-required-action" -Ok (
    (Get-StringArray -Value $kitManifest.compatibility.requiredActions) -contains "adapter-pack-factory-check" -and
    (Get-StringArray -Value $kitManifestMirror.compatibility.requiredActions) -contains "adapter-pack-factory-check"
) -Detail "kit manifest requires the adapter pack factory check"

$requiredFields = @("packId", "packName", "version", "status", "owner", "stack", "scope", "nonGoals", "requiredArtifacts", "requiredActions", "verificationOrder", "exampleRoot", "guidePath", "manifestPath", "checkScriptPath")
$schemaFields = if ($null -ne $schema) { Get-StringArray -Value $schema.requiredFields } else { @() }
$schemaFieldsOk = $true
foreach ($field in @($requiredFields)) {
    if ($schemaFields -notcontains $field) { $schemaFieldsOk = $false }
}
Add-Check -Checks $checks -Name "schema-required-fields" -Ok $schemaFieldsOk -Detail ("required={0}" -f [string]::Join(",", @($requiredFields)))
Add-Check -Checks $checks -Name "schema-mirror" -Ok ([string]::Equals((Normalize-JsonText $schema), (Normalize-JsonText $schemaMirror), [System.StringComparison]::Ordinal)) -Detail "schema mirror under docs/治理/策略 matches policies/schema"

$templateOk = $false
if ($null -ne $templateManifest) {
    $templateOk = (
        [string]::Equals([string]$templateManifest.machineTag, "RCCP_ADAPTER_PACK_TEMPLATE_V1", [System.StringComparison]::OrdinalIgnoreCase) -and
        [string]::Equals([string]$templateManifest.packId, "pack-template", [System.StringComparison]::OrdinalIgnoreCase) -and
        (@(Get-StringArray -Value $templateManifest.requiredArtifacts).Count -ge 4) -and
        (@(Get-StringArray -Value $templateManifest.verificationOrder).Count -ge 7)
    )
}
Add-Check -Checks $checks -Name "template-manifest" -Ok $templateOk -Detail "adapter pack template manifest has the expected placeholder shape"

$failureCount = @($checks.ToArray() | Where-Object { -not [bool]$_.ok }).Count
$verdict = if ($failureCount -gt 0) { "FAIL" } else { "PASS" }
$latestJsonPath = Join-Path $OutDir "adapter-pack-factory-check-latest.json"
$latestMdPath = Join-Path $OutDir "adapter-pack-factory-check-latest.md"

$payload = [ordered]@{
    machineTag = "RCCP_ADAPTER_PACK_FACTORY_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    verdict = [string]$verdict
    pass = ($failureCount -eq 0)
    failureCount = [int]$failureCount
    requiredFiles = @($requiredFiles)
    checks = @($checks.ToArray())
    evidencePath = "docs/治理/最新态/adapter-pack-factory-check-latest.json"
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action adapter-pack-factory-check -Task `"$Task`" -Strict"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 20)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Adapter Pack Factory Check") | Out-Null
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
else { Write-Host ("adapter-pack-factory-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Red" }) }

if ($Strict -and $failureCount -gt 0) { exit 1 }
