[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "action-reference-surface-check",
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

function Read-JsonFile {
    Param([Parameter(Mandatory = $true)][string]$Path)
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
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

function Add-Reference {
    Param(
        [System.Collections.Generic.List[object]]$References,
        [string]$Source,
        [string]$Action,
        [string]$Kind
    )
    if ([string]::IsNullOrWhiteSpace($Action)) { return }
    $References.Add([ordered]@{
        source = $Source
        action = $Action
        kind = $Kind
    }) | Out-Null
}

function Add-Violation {
    Param(
        [System.Collections.Generic.List[object]]$Violations,
        [string]$Source,
        [string]$Action,
        [string]$Kind,
        [string]$Code
    )
    $Violations.Add([ordered]@{
        code = $Code
        source = $Source
        action = $Action
        kind = $Kind
    }) | Out-Null
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$dispatch = Read-JsonFile -Path "policies/rccp-entry-dispatch.json"
$textSources = @("README.md", "docs/release-checklist.md", "docs/multi-agent-workflow.md", "docs/adapters/README.md", "docs/AI上下文/README.md", "scripts/help/admission-runtime-actions.txt")
$textSources += @(Get-ChildItem -LiteralPath "docs/adapters" -Filter "*.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
    (Resolve-Path -Relative -LiteralPath $_.FullName) -replace '^[.][\\/]', '' -replace '\\', '/'
})
$textSources = @($textSources | Select-Object -Unique)
$manifestPaths = @("policies/rccp-kit-manifest.json", "docs/治理/策略/rccp-kit-manifest.json")

$availableActions = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in @($dispatch.entryDispatch.PSObject.Properties.Name)) { [void]$availableActions.Add([string]$name) }
foreach ($name in @(Get-StringArray -Value $dispatch.coreActions)) { [void]$availableActions.Add($name) }
foreach ($surface in @("readonly", "write", "runtimeWrite", "closeoutWrite")) {
    foreach ($name in @(Get-StringArray -Value (Get-ObjectValue -Object $dispatch.actionSurface -Name $surface))) {
        [void]$availableActions.Add([string]$name)
    }
}

$references = New-Object System.Collections.Generic.List[object]
foreach ($source in @($textSources)) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
    $text = Get-Content -LiteralPath $source -Encoding UTF8 -Raw
    foreach ($match in [regex]::Matches($text, '(?i)-Action\s+["'']?([A-Za-z0-9][A-Za-z0-9_-]*)')) {
        $action = [string]$match.Groups[1].Value
        if ([string]::Equals($action, "help", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        Add-Reference -References $references -Source $source -Action $action -Kind "text-action"
    }
}
foreach ($source in @($manifestPaths)) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
    $manifest = Read-JsonFile -Path $source
    foreach ($action in @(Get-StringArray -Value $manifest.compatibility.requiredActions)) {
        Add-Reference -References $references -Source $source -Action $action -Kind "manifest-required-action"
    }
}
foreach ($action in @(Get-StringArray -Value $dispatch.distributionProfile.requiredLeafActions)) {
    Add-Reference -References $references -Source "policies/rccp-entry-dispatch.json" -Action $action -Kind "distribution-required-leaf"
}
foreach ($action in @(Get-StringArray -Value $dispatch.distributionProfile.fullKitRequiredLeafActions)) {
    Add-Reference -References $references -Source "policies/rccp-entry-dispatch.json" -Action $action -Kind "distribution-full-kit-leaf"
}

$violations = New-Object System.Collections.Generic.List[object]
foreach ($ref in @($references.ToArray())) {
    if (-not $availableActions.Contains([string]$ref.action)) {
        Add-Violation -Violations $violations -Source ([string]$ref.source) -Action ([string]$ref.action) -Kind ([string]$ref.kind) -Code "UNAVAILABLE_ACTION_REFERENCE"
    }
}

$pass = ($violations.Count -eq 0)
$latestJsonPath = Join-Path $OutDir "action-reference-surface-check-latest.json"
$latestMdPath = Join-Path $OutDir "action-reference-surface-check-latest.md"
$payload = [ordered]@{
    machineTag = "RCCP_ACTION_REFERENCE_SURFACE_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    pass = [bool]$pass
    semanticPass = [bool]$pass
    availableActionCount = [int]$availableActions.Count
    checkedReferenceCount = [int]$references.Count
    violationCount = [int]$violations.Count
    references = @($references.ToArray())
    violations = @($violations.ToArray())
    evidencePath = "docs/治理/最新态/action-reference-surface-check-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Action Reference Surface Check") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- pass: {0}" -f [bool]$pass)) | Out-Null
$md.Add(("- checkedReferenceCount: {0}" -f [int]$references.Count)) | Out-Null
$md.Add(("- violationCount: {0}" -f [int]$violations.Count)) | Out-Null
if ($violations.Count -gt 0) {
    $md.Add("") | Out-Null
    $md.Add("## Violations") | Out-Null
    foreach ($item in @($violations.ToArray())) {
        $md.Add(("- {0}: {1} ({2})" -f $item.action, $item.source, $item.kind)) | Out-Null
    }
}
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())))

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("action-reference-surface-check completed: pass={0}, violations={1}, latest='{2}'" -f [bool]$pass, [int]$violations.Count, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
