[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "code-context-snapshot",
    [string[]]$TargetPaths = @(),
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

function Normalize-PathText {
    Param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    return ($Path -replace "\\", "/")
}

function Resolve-TargetPath {
    Param([string]$RepoRoot, [string]$PathText)
    if ([string]::IsNullOrWhiteSpace($PathText)) { return "" }
    if ([System.IO.Path]::IsPathRooted($PathText)) { return $PathText }
    return Join-Path $RepoRoot $PathText
}

function Get-FileCategory {
    Param([string]$Path)
    $normalized = Normalize-PathText $Path
    if ($normalized -match "(^|/)src/main/java/.*Controller\.java$") { return "controller" }
    if ($normalized -match "(^|/)src/main/java/.*Service.*\.java$") { return "service" }
    if ($normalized -match "(^|/)src/main/java/.*Mapper\.java$") { return "mapper" }
    if ($normalized -match "(^|/)src/main/resources/.*\.xml$") { return "sql-mapping" }
    if ($normalized -match "(^|/)src/test/") { return "test" }
    if ($normalized -match "(^|/)src/.*\.(vue|ts|js)$") { return "frontend" }
    if ($normalized -match "(^|/)docs/") { return "docs" }
    if ($normalized -match "(^|/)schemas/.*\.json$") { return "schema" }
    if ($normalized -match "(^|/)scripts/.*\.(ps1|psm1)$") { return "script" }
    return "source"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$targetPathList = @($TargetPaths | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($targetPathList.Count -eq 0) {
    $targetPathList = @(".")
}

$related = New-Object System.Collections.Generic.List[object]
$symbolHints = New-Object System.Collections.Generic.List[string]
$dependencyHints = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
$ownershipSlices = New-Object System.Collections.Generic.List[object]
$existingTargetCount = 0

foreach ($target in @($targetPathList)) {
    $full = Resolve-TargetPath -RepoRoot $repoRoot -PathText $target
    $files = @()
    if (Test-Path -LiteralPath $full -PathType Leaf) {
        $files = @(Get-Item -LiteralPath $full)
    } elseif (Test-Path -LiteralPath $full -PathType Container) {
        $files = @(Get-ChildItem -LiteralPath $full -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "\\(\.git|node_modules|target|dist|build|\.gradle|\.m2)\\" } | Select-Object -First 200)
    }
    if ($files.Count -gt 0) { $existingTargetCount++ }
    foreach ($file in @($files)) {
        $rel = Normalize-PathText (($file.FullName).Substring($repoRoot.Length).TrimStart('\', '/'))
        $category = Get-FileCategory -Path $rel
        $related.Add([ordered]@{
            path = $rel
            category = $category
            length = [int64]$file.Length
        }) | Out-Null
        $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        if (-not [string]::IsNullOrWhiteSpace($base)) { $symbolHints.Add($base) | Out-Null }
        switch ($category) {
            "controller" { [void]$dependencyHints.Add("spring-web") }
            "service" { [void]$dependencyHints.Add("service-layer") }
            "mapper" { [void]$dependencyHints.Add("mybatis-mapper") }
            "sql-mapping" { [void]$dependencyHints.Add("sql-mapping") }
            "frontend" { [void]$dependencyHints.Add("vue-or-js-frontend") }
            "script" { [void]$dependencyHints.Add("powershell-governance") }
            "schema" { [void]$dependencyHints.Add("json-schema-contract") }
        }
    }
}

$grouped = @($related.ToArray() | Group-Object -Property category)
foreach ($group in @($grouped)) {
    $paths = @($group.Group | ForEach-Object { [string]$_["path"] })
    $ownershipSlices.Add([ordered]@{
        sliceId = ("slice-{0}" -f $group.Name)
        objective = ("Handle {0} files under scoped ownership" -f $group.Name)
        allowedPaths = @($paths)
        closeoutAllowed = $false
    }) | Out-Null
}

$uniqueSymbols = @($symbolHints.ToArray() | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique | Select-Object -First 80)
$relatedFiles = @($related.ToArray())
$graphConfidence = if ($relatedFiles.Count -eq 0) { "low" } elseif ($targetPathList.Count -eq $existingTargetCount) { "high" } else { "medium" }
$impactSummary = if ($relatedFiles.Count -eq 0) {
    "No source-backed files found for the requested targets; use existing RCCP evidence gates before editing."
} else {
    "builtin-lite scanned $($relatedFiles.Count) files across $(@($grouped).Count) categories for scoped work-order context."
}
$recommendedVerifierChecks = @(
    "pwsh -NoProfile -File ./rccp.ps1 -Action ownership-check -Task `"$Task`"",
    "pwsh -NoProfile -File ./rccp.ps1 -Action multi-agent-contract-check -Task `"$Task`" -Strict"
)
$dependencyHintList = @($dependencyHints | ForEach-Object { [string]$_ })
if ($dependencyHintList -contains "powershell-governance") {
    $recommendedVerifierChecks += "pwsh -NoProfile -File ./rccp.ps1 -Action rccp-leaf-contract-check -Task `"$Task`" -RequireAllLeafScripts -Strict"
}

$latestJsonPath = Join-Path $OutDir "code-context-snapshot-latest.json"
$latestMdPath = Join-Path $OutDir "code-context-snapshot-latest.md"
$payload = [ordered]@{
    machineTag = "RCCP_CODE_CONTEXT_SNAPSHOT_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    provider = "builtin-lite"
    targetPaths = @($targetPathList | ForEach-Object { Normalize-PathText $_ })
    relatedFiles = @($relatedFiles)
    symbolHints = @($uniqueSymbols)
    dependencyHints = @($dependencyHintList)
    impactSummary = $impactSummary
    ownershipSlices = @($ownershipSlices.ToArray())
    recommendedVerifierChecks = @($recommendedVerifierChecks)
    graphConfidence = $graphConfidence
    contextPackPath = Normalize-PathText $latestJsonPath
    externalDependencyRequired = $false
    closeoutAuthority = $false
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 20)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Code Context Snapshot") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- task: {0}" -f $payload.task)) | Out-Null
$md.Add(("- provider: {0}" -f $payload.provider)) | Out-Null
$md.Add(("- graphConfidence: {0}" -f $payload.graphConfidence)) | Out-Null
$md.Add(("- relatedFileCount: {0}" -f @($payload.relatedFiles).Count)) | Out-Null
$md.Add("") | Out-Null
$md.Add("## Impact") | Out-Null
$md.Add(("- {0}" -f $payload.impactSummary)) | Out-Null
$md.Add("") | Out-Null
$md.Add("## Ownership Slices") | Out-Null
foreach ($slice in @($payload.ownershipSlices)) { $md.Add(("- {0}: {1} paths" -f $slice.sliceId, @($slice.allowedPaths).Count)) | Out-Null }
$md.Add("") | Out-Null
$md.Add("## Verifier Checks") | Out-Null
foreach ($check in @($payload.recommendedVerifierChecks)) { $md.Add(("- {0}" -f $check)) | Out-Null }
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())) + "`n")

if ($Json) { $payload | ConvertTo-Json -Depth 20 }
else { Write-Host ("code-context-snapshot completed: provider={0}, confidence={1}, latest='{2}'" -f $payload.provider, $payload.graphConfidence, $latestJsonPath) -ForegroundColor Green }

if ($Strict -and $relatedFiles.Count -eq 0) { exit 1 }
