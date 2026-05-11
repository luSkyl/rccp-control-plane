[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "memory-recall-check",
    [string]$Query = "",
    [string]$EvalPath = "",
    [int]$TopK = 5,
    [string]$IndexPath = "docs/治理/最新态/memory-ingest-plan-latest.json",
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

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-TokenList {
    Param([string]$Text)
    $tokens = @()
    foreach ($item in @(([string]$Text) -split "[^A-Za-z0-9\u4e00-\u9fff]+")) {
        $trimmed = ([string]$item).Trim().ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) { $tokens += $trimmed }
    }
    return @($tokens | Select-Object -Unique)
}

function Test-TextContains {
    Param(
        [string]$Haystack,
        [string]$Needle
    )
    if ([string]::IsNullOrWhiteSpace($Haystack) -or [string]::IsNullOrWhiteSpace($Needle)) { return $false }
    return (([string]$Haystack).IndexOf([string]$Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Normalize-MatchText {
    Param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $normalized = ([string]$Text).ToLowerInvariant() -replace "[^A-Za-z0-9\u4e00-\u9fff]+", " "
    return ($normalized -replace "\s+", " ").Trim()
}

function Get-Score {
    Param(
        [object]$Record,
        [string[]]$Tokens,
        [string]$QueryText
    )
    $title = [string]$Record.title
    $sourcePath = [string]$Record.source_path
    $body = [string]$Record.text
    $confidence = [string]$Record.confidence
    $status = [string]$Record.status
    $textScore = 0
    foreach ($token in @($Tokens)) {
        if ([string]::IsNullOrWhiteSpace($token)) { continue }
        if (Test-TextContains -Haystack $title -Needle $token) { $textScore += 4 }
        if (Test-TextContains -Haystack $sourcePath -Needle $token) { $textScore += 6 }
        if (Test-TextContains -Haystack $body -Needle $token) { $textScore += 1 }
    }
    $meaningfulTokens = @($Tokens | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($meaningfulTokens.Count -gt 0) {
        $allTitleTokens = $true
        $allSourcePathTokens = $true
        foreach ($token in @($meaningfulTokens)) {
            if (-not (Test-TextContains -Haystack $title -Needle ([string]$token))) { $allTitleTokens = $false }
            if (-not (Test-TextContains -Haystack $sourcePath -Needle ([string]$token))) { $allSourcePathTokens = $false }
        }
        if ($allTitleTokens) { $textScore += 120 }
        if ($allSourcePathTokens) { $textScore += 80 }
    }
    $normalizedPhrase = Normalize-MatchText -Text ([string]::Join(" ", @($Tokens)))
    if (-not [string]::IsNullOrWhiteSpace($normalizedPhrase)) {
        $normalizedTitle = Normalize-MatchText -Text $title
        $normalizedSourcePath = Normalize-MatchText -Text $sourcePath
        $normalizedBody = Normalize-MatchText -Text $body
        if (Test-TextContains -Haystack $normalizedTitle -Needle $normalizedPhrase) { $textScore += 80 }
        if (Test-TextContains -Haystack $normalizedSourcePath -Needle $normalizedPhrase) { $textScore += 60 }
        if (Test-TextContains -Haystack $normalizedBody -Needle $normalizedPhrase) { $textScore += 30 }
    }
    if ($textScore -le 0) { return 0 }
    $score = $textScore
    if ($status -eq "active") { $score += 3 }
    if ($confidence -eq "high") { $score += 3 }
    elseif ($confidence -eq "medium") { $score += 2 }
    return $score
}

function Format-Excerpt {
    Param([string]$Text)
    $normalized = ([string]$Text -replace "`r`n", " " -replace "`r", " " -replace "\s+", " ").Trim()
    if ($normalized.Length -le 160) { return $normalized }
    return $normalized.Substring(0, 157) + "..."
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$indexFullPath = if ([System.IO.Path]::IsPathRooted($IndexPath)) { $IndexPath } else { Join-Path $repoRoot $IndexPath }
$indexDoc = Read-JsonOrNull -Path $indexFullPath
if ($null -eq $indexDoc) {
    throw ("memory-recall-check requires index file: {0}" -f $IndexPath)
}

$indexRecords = @($indexDoc.chunks)
if ($indexRecords.Count -eq 0 -and (Test-Path -LiteralPath ($indexDoc.candidateIndexPath))) {
    $jsonlPath = if ([System.IO.Path]::IsPathRooted([string]$indexDoc.candidateIndexPath)) { [string]$indexDoc.candidateIndexPath } else { Join-Path $repoRoot ([string]$indexDoc.candidateIndexPath) }
    if (Test-Path -LiteralPath $jsonlPath -PathType Leaf) {
        $indexRecords = @((Get-Content -LiteralPath $jsonlPath -Encoding UTF8 | ForEach-Object { if (-not [string]::IsNullOrWhiteSpace($_)) { $_ | ConvertFrom-Json } }))
    }
}

function Invoke-RecallForQuery {
    Param(
        [string]$QueryText,
        [int]$Limit
    )
    $tokens = @(Get-TokenList -Text $QueryText)
    $eligible = @($indexRecords | Where-Object {
        [string]$_.status -eq "active" -and ([string]$_.confidence -in @("high", "medium"))
    })
    $scored = New-Object System.Collections.Generic.List[object]
    foreach ($record in @($eligible)) {
        $score = Get-Score -Record $record -Tokens $tokens -QueryText $QueryText
        if ($score -le 0) { continue }
        $scored.Add([ordered]@{
            chunkId = [string]$record.chunkId
            source_path = [string]$record.source_path
            path = Normalize-PathText ([string]$record.path)
            title = [string]$record.title
            status = [string]$record.status
            owner = [string]$record.owner
            updated_at = [string]$record.updated_at
            confidence = [string]$record.confidence
            score = [int]$score
            excerpt = Format-Excerpt -Text ([string]$record.text)
        }) | Out-Null
    }
    $results = @($scored | Sort-Object score -Descending | Select-Object -First $Limit)
    $abstainRequired = ($results.Count -eq 0)
    return [ordered]@{
        query = $QueryText
        tokens = @($tokens)
        verdict = $(if ($abstainRequired) { "ABSTAIN_REQUIRED" } else { "PASS" })
        abstainRequired = [bool]$abstainRequired
        results = @($results)
        topScore = $(if ($results.Count -gt 0) { [int]$results[0].score } else { 0 })
    }
}

$checks = New-Object System.Collections.Generic.List[object]
$caseResults = New-Object System.Collections.Generic.List[object]

if (-not [string]::IsNullOrWhiteSpace($EvalPath)) {
    $evalFullPath = if ([System.IO.Path]::IsPathRooted($EvalPath)) { $EvalPath } else { Join-Path $repoRoot $EvalPath }
    $evalDoc = Read-JsonOrNull -Path $evalFullPath
    if ($null -eq $evalDoc) { throw ("memory-recall-check requires eval file: {0}" -f $EvalPath) }
    $cases = @($evalDoc.cases)
    foreach ($case in @($cases)) {
        $queryText = [string]$case.query
        $expectedVerdict = [string]$case.expectedVerdict
        $expectedSourcePath = @($case.expectedTopSourcePaths)
        $limit = if ($case.PSObject.Properties["topK"] -ne $null) { [int]$case.topK } else { $TopK }
        $evaluationLimit = [Math]::Max($limit, [int]$indexRecords.Count)
        $result = Invoke-RecallForQuery -QueryText $queryText -Limit $evaluationLimit
        $sourcePaths = @($result.results | ForEach-Object { [string]$_.source_path })
        $verdictOk = [string]::Equals([string]$result.verdict, $expectedVerdict, [System.StringComparison]::OrdinalIgnoreCase)
        $sourceOk = $true
        foreach ($expected in @($expectedSourcePath)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$expected) -and ($sourcePaths -notcontains [string]$expected)) { $sourceOk = $false }
        }
        $casePass = ($verdictOk -and $sourceOk)
        $caseResults.Add([ordered]@{
            id = [string]$case.id
            query = $queryText
            expectedVerdict = $expectedVerdict
            actualVerdict = [string]$result.verdict
            expectedTopSourcePaths = @($expectedSourcePath)
            actualTopSourcePaths = @($sourcePaths)
            pass = [bool]$casePass
            result = $result
        }) | Out-Null
        Add-Check -Checks $checks -Name ("case:{0}" -f $case.id) -Ok $casePass -Detail ("expected={0}; actual={1}" -f $expectedVerdict, $result.verdict)
    }
    $verdict = $(if (@($caseResults | Where-Object { -not [bool]$_.pass }).Count -eq 0) { "PASS" } else { "FAIL" })
}
else {
    $result = Invoke-RecallForQuery -QueryText $Query -Limit $TopK
    $caseResults.Add([ordered]@{
        id = "single-query"
        query = $Query
        expectedVerdict = "PASS_OR_ABSTAIN"
        actualVerdict = [string]$result.verdict
        expectedTopSourcePaths = @()
        actualTopSourcePaths = @($result.results | ForEach-Object { [string]$_.source_path })
        pass = $true
        result = $result
    }) | Out-Null
    $verdict = [string]$result.verdict
    Add-Check -Checks $checks -Name "query-present" -Ok (-not [string]::IsNullOrWhiteSpace($Query)) -Detail "single-query mode"
    Add-Check -Checks $checks -Name "recall-found" -Ok (-not $result.abstainRequired) -Detail ("topScore={0}; resultCount={1}" -f $result.topScore, @($result.results).Count)
}

$failureCount = @($checks | Where-Object { -not [bool]$_.ok }).Count
if (-not [string]::IsNullOrWhiteSpace($EvalPath) -and $failureCount -gt 0) {
    $verdict = "FAIL"
}

$latestJsonPath = Join-Path $OutDir "memory-recall-check-latest.json"
$latestMdPath = Join-Path $OutDir "memory-recall-check-latest.md"
$report = [ordered]@{
    machineTag = "MEMORY_RECALL_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    query = [string]$Query
    evalPath = Normalize-PathText $EvalPath
    indexPath = Normalize-PathText $indexFullPath
    topK = [int]$TopK
    verdict = [string]$verdict
    pass = ($verdict -eq "PASS")
    failureCount = [int]$failureCount
    checks = @($checks.ToArray())
    cases = @($caseResults.ToArray())
    evidencePath = "docs/治理/最新态/memory-recall-check-latest.json"
    nextCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/rccp/rccp.ps1 -Action abstain-shape-check -Task `"$Task`" -AnswerPath `"examples/obsidian-second-brain-repo/eval-cases/abstain-answer.md`" -Strict"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($report | ConvertTo-Json -Depth 20)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Memory Recall Check") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- verdict: {0}" -f $report.verdict)) | Out-Null
$md.Add(("- failureCount: {0}" -f $report.failureCount)) | Out-Null
$md.Add(("- topK: {0}" -f $report.topK)) | Out-Null
$md.Add("") | Out-Null
$md.Add("## Checks") | Out-Null
foreach ($item in @($checks.ToArray())) {
    $md.Add(("- {0}: {1} ({2})" -f $item.name, $(if ([bool]$item.ok) { "PASS" } else { "FAIL" }), $item.detail)) | Out-Null
}
$md.Add("") | Out-Null
$md.Add("## Cases") | Out-Null
foreach ($item in @($caseResults.ToArray())) {
    $md.Add(("- {0}: {1} -> {2}" -f $item.id, $item.query, $item.actualVerdict)) | Out-Null
    foreach ($src in @($item.actualTopSourcePaths)) {
        $md.Add(("  - {0}" -f $src)) | Out-Null
    }
}
$md.Add("") | Out-Null
$md.Add("## Next") | Out-Null
$md.Add(("- {0}" -f $report.nextCommand)) | Out-Null
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())))

if ($Json) { $report | ConvertTo-Json -Depth 20 }
else { Write-Host ("memory-recall-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($verdict -eq "PASS") { "Green" } else { "Red" }) }

if ($Strict -and $verdict -ne "PASS") { exit 1 }
