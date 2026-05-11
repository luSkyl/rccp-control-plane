[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "obsidian-second-brain-contract-check",
    [string]$OutDir = "docs/治理/最新态",
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
    Param(
        [string]$Text,
        [string[]]$Terms
    )
    foreach ($term in @($Terms)) {
        if ([string]::IsNullOrWhiteSpace($term)) { continue }
        if ($Text -notmatch [regex]::Escape($term)) { return $false }
    }
    return $true
}

function Get-ObjectPropertyValue {
    Param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$requiredFiles = @(
    "docs/adapters/README.md",
    "docs/adapters/obsidian-second-brain.md",
    "docs/adapters/ai-context-gateway.md",
    "docs/AI上下文/README.md",
    "docs/AI上下文/source-path-contract.md",
    "docs/AI上下文/second-brain-vault-template.md",
    "docs/AI上下文/ingestion-rules/vector-ingestion-rules.md",
    "docs/AI上下文/abstain-protocol.md",
    "docs/memory-layer.md",
    "schemas/rccp-memory-source.schema.json",
    "scripts/check-memory-source-contract.ps1",
    "scripts/check-memory-ingest-plan.ps1",
    "scripts/check-memory-recall-check.ps1",
    "scripts/check-abstain-shape.ps1",
    "examples/obsidian-second-brain-repo/README.md",
    "examples/obsidian-second-brain-repo/docs/Rccp/README.md",
    "examples/obsidian-second-brain-repo/docs/Rccp/inbox/README.md",
    "examples/obsidian-second-brain-repo/docs/Rccp/knowledge/README.md",
    "examples/obsidian-second-brain-repo/docs/Rccp/knowledge/obsidian-second-brain-contract.md",
    "examples/obsidian-second-brain-repo/docs/Rccp/decisions/README.md",
    "examples/obsidian-second-brain-repo/docs/Rccp/projects/README.md",
    "examples/obsidian-second-brain-repo/eval-cases/memory-recall-cases.json",
    "examples/obsidian-second-brain-repo/eval-cases/abstain-answer.md"
)

$checks = New-Object System.Collections.Generic.List[object]

foreach ($path in @($requiredFiles)) {
    Add-Check -Checks $checks -Name ("file-present:{0}" -f $path) -Ok (Test-Path -LiteralPath $path -PathType Leaf) -Detail $path
}

$obsidianDoc = Read-Text -Path "docs/adapters/obsidian-second-brain.md"
$gatewayDoc = Read-Text -Path "docs/adapters/ai-context-gateway.md"
$sourcePathDoc = Read-Text -Path "docs/AI上下文/source-path-contract.md"
$ingestDoc = Read-Text -Path "docs/AI上下文/ingestion-rules/vector-ingestion-rules.md"
$abstainDoc = Read-Text -Path "docs/AI上下文/abstain-protocol.md"
$vaultDoc = Read-Text -Path "docs/AI上下文/second-brain-vault-template.md"
$aiContextReadme = Read-Text -Path "docs/AI上下文/README.md"
$memoryLayerDoc = Read-Text -Path "docs/memory-layer.md"
$sampleNote = Read-Text -Path "examples/obsidian-second-brain-repo/docs/Rccp/knowledge/obsidian-second-brain-contract.md"
$recallCases = Read-JsonOrNull -Path "examples/obsidian-second-brain-repo/eval-cases/memory-recall-cases.json"
$abstainAnswer = Read-Text -Path "examples/obsidian-second-brain-repo/eval-cases/abstain-answer.md"

Add-Check -Checks $checks -Name "obsidian-boundary" -Ok (Test-ContainsAll -Text $obsidianDoc -Terms @("Obsidian", ".obsidian/", "source_path", "Git Markdown", "Vector index")) -Detail "Obsidian adapter keeps human workbench separate from source truth"
Add-Check -Checks $checks -Name "gateway-pipeline" -Ok (Test-ContainsAll -Text $gatewayDoc -Terms @("intent normalization", "template slot fill", "project fact retrieval", "evidence-shaped answer", "abstain")) -Detail "AI Context Gateway includes intent/template/retrieval/evidence/abstain stages"
Add-Check -Checks $checks -Name "source-path-metadata" -Ok (Test-ContainsAll -Text $sourcePathDoc -Terms @("source_path", "owner", "updated_at", "confidence", "status")) -Detail "source metadata contract is explicit"
Add-Check -Checks $checks -Name "ingestion-evidence" -Ok (Test-ContainsAll -Text $ingestDoc -Terms @("sourceFingerprint", "indexVersion", "deletedPoints", "fail-closed")) -Detail "vector ingestion requires rebuildable evidence"
Add-Check -Checks $checks -Name "abstain-shape" -Ok (Test-ContainsAll -Text $abstainDoc -Terms @("Evidence is insufficient to confirm.", "Minimal next step:", "source_path")) -Detail "abstain response shape blocks unsupported conclusions"
Add-Check -Checks $checks -Name "vault-template" -Ok (Test-ContainsAll -Text $vaultDoc -Terms @("docs/Rccp/", "inbox/", "knowledge/", "decisions/", "projects/")) -Detail "recommended Obsidian vault shape is documented"
Add-Check -Checks $checks -Name "memory-layer-bridge" -Ok (Test-ContainsAll -Text $memoryLayerDoc -Terms @("docs/adapters/obsidian-second-brain.md", "docs/adapters/ai-context-gateway.md")) -Detail "memory layer points to public adapter bridge"
Add-Check -Checks $checks -Name "runtime-chain-docs" -Ok (Test-ContainsAll -Text (($obsidianDoc, $gatewayDoc, $aiContextReadme, $memoryLayerDoc) -join "`n") -Terms @("memory-source-contract-check", "memory-ingest-plan", "memory-recall-check", "abstain-shape-check")) -Detail "public docs name the offline runtime chain"

$schema = Read-JsonOrNull -Path "schemas/rccp-memory-source.schema.json"
$schemaFields = @()
if ($null -ne $schema) {
    $schemaFields = @((Get-ObjectPropertyValue -Object $schema -Name "requiredFields") | ForEach-Object { [string]$_ })
}
$requiredSchemaFields = @("title", "status", "owner", "updated_at", "source_path", "confidence")
$schemaOk = $true
foreach ($field in @($requiredSchemaFields)) {
    if ($schemaFields -notcontains $field) { $schemaOk = $false }
}
Add-Check -Checks $checks -Name "schema-required-fields" -Ok $schemaOk -Detail ("required={0}" -f [string]::Join(",", $requiredSchemaFields))

$sampleFieldsOk = $true
foreach ($field in @($requiredSchemaFields)) {
    if ($sampleNote -notmatch ("(?m)^{0}\s*:" -f [regex]::Escape($field))) { $sampleFieldsOk = $false }
}
Add-Check -Checks $checks -Name "example-frontmatter" -Ok $sampleFieldsOk -Detail "sample knowledge note has required metadata"

$recallCasesOk = $false
if ($null -ne $recallCases) {
    $recallCaseIds = @($recallCases.cases | ForEach-Object { [string]$_.id })
    $recallCasesOk = ([string]::Equals([string]$recallCases.machineTag, "OBSIDIAN_SECOND_BRAIN_RECALL_CASES_V1", [System.StringComparison]::OrdinalIgnoreCase) -and $recallCaseIds.Count -ge 3 -and $recallCaseIds -contains "source-path-contract" -and $recallCaseIds -contains "obsidian-adapter" -and $recallCaseIds -contains "unrelated-query")
}
Add-Check -Checks $checks -Name "recall-cases" -Ok $recallCasesOk -Detail "offline recall evaluation cases are present"

$abstainAnswerOk = (Test-ContainsAll -Text $abstainAnswer -Terms @("Evidence is insufficient to confirm.", "Minimal next step:", "memory-ingest-plan", "memory-recall-check"))
Add-Check -Checks $checks -Name "abstain-answer" -Ok $abstainAnswerOk -Detail "abstain sample points to the offline runtime chain"

$publicDocs = @(
    $obsidianDoc,
    $gatewayDoc,
    $aiContextReadme,
    $sourcePathDoc,
    $ingestDoc,
    $abstainDoc,
    $vaultDoc
) -join "`n"
$privateLeakOk = ($publicDocs -notmatch "黑灰产|开发执行与优化进度|建议池|Hermes")
Add-Check -Checks $checks -Name "public-boundary" -Ok $privateLeakOk -Detail "adapter docs do not depend on source-project private history"

$failureCount = @($checks.ToArray() | Where-Object { -not [bool]$_.ok }).Count
$verdict = if ($failureCount -gt 0) { "FAIL" } else { "PASS" }
$latestJsonPath = Join-Path $OutDir "obsidian-second-brain-contract-check-latest.json"
$latestMdPath = Join-Path $OutDir "obsidian-second-brain-contract-check-latest.md"

$payload = [ordered]@{
    machineTag = "OBSIDIAN_SECOND_BRAIN_CONTRACT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    verdict = [string]$verdict
    pass = ($failureCount -eq 0)
    failureCount = [int]$failureCount
    requiredFiles = @($requiredFiles)
    checks = @($checks.ToArray())
    evidencePath = Normalize-PathText $latestJsonPath
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action memory-layer-contract-check -Task `"$Task`" -Strict"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 20)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Obsidian Second-Brain Contract Check") | Out-Null
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
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())))

if ($Json) { $payload | ConvertTo-Json -Depth 20 }
else { Write-Host ("obsidian-second-brain-contract-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($failureCount -eq 0) { "Green" } else { "Red" }) }

if ($Strict -and $failureCount -gt 0) { exit 1 }
