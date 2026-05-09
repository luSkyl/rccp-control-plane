[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "",
    [string]$TaskClass = "IMPLEMENT",
    [Alias("Problem")]
    [string]$ProblemText = "",
    [Alias("PLevel", "Severity")]
    [string]$Level = "",
    [Alias("Resolution")]
    [string]$ActionTaken = "",
    [Alias("RootCauseClosed")]
    [string]$RootCauseStatus = "",
    [string]$TemporaryBypass = "",
    [string]$OpenRisk = "",
    [string[]]$TargetPaths = @(),
    [string[]]$EvidencePaths = @(),
    [string]$SuggestionId = "",
    [string]$IssueId = "",
    [string]$ProgressId = "",
    [string]$RecentSection = "",
    [string]$Mode = "Staged",
    [string]$GateProfile = "Fast",
    [string]$BlueprintRoot = "docs/治理/方案蓝图",
    [string]$BlueprintPath = "",
    [string]$OutDir = "docs/治理/最新态",
    [switch]$Strict,
    [switch]$AllowPartial,
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

function Read-TextSafe {
    Param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return "" }
    try { return [string](Get-Content -LiteralPath $Path -Encoding UTF8 -Raw) }
    catch { return "" }
}

function Convert-ToSafeFilePart {
    Param([string]$Text)
    $value = if ([string]::IsNullOrWhiteSpace($Text)) { "unknown-task" } else { $Text }
    $value = $value -replace '[\\/:*?"<>|]', '-'
    $value = $value -replace '\s+', '-'
    if ($value.Length -gt 80) { $value = $value.Substring(0, 80) }
    return $value
}

function New-RecapIssue {
    Param(
        [string]$Problem,
        [string]$PLevel,
        [string]$Resolution,
        [string]$RootClosed,
        [string]$Bypass,
        [string]$Risk,
        [string[]]$Evidence = @()
    )
    return [ordered]@{
        problem = [string]$Problem
        level = [string]$PLevel
        actionTaken = [string]$Resolution
        rootCauseClosed = [string]$RootClosed
        temporaryBypass = [string]$Bypass
        openRisk = [string]$Risk
        evidencePaths = @($Evidence | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
}

function Expand-PathList {
    Param([string[]]$Paths = @())
    $expanded = New-Object System.Collections.Generic.List[string]
    foreach ($path in @($Paths)) {
        if ([string]::IsNullOrWhiteSpace([string]$path)) { continue }
        foreach ($part in ([string]$path -split '[;,]')) {
            $value = ([string]$part).Trim()
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $expanded.Add($value) | Out-Null
            }
        }
    }
    return @($expanded.ToArray())
}

function Get-OperationRows {
    Param(
        [string]$LedgerPath,
        [string]$TaskName
    )
    $rows = New-Object System.Collections.Generic.List[object]
    $text = Read-TextSafe -Path $LedgerPath
    if ([string]::IsNullOrWhiteSpace($text) -or [string]::IsNullOrWhiteSpace($TaskName)) { return @() }
    $seq = 0
    foreach ($line in ($text -split "`n")) {
        $seq++
        if ($line -notmatch '^\|') { continue }
        if ($line -match '^\|\s*-+') { continue }
        $parts = @($line -split '\|' | ForEach-Object { $_.Trim() })
        if ($parts.Count -lt 8) { continue }
        $taskCell = [string]$parts[3]
        if (-not [string]::Equals($taskCell, $TaskName, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $rows.Add([ordered]@{
            seq = $seq
            at = [string]$parts[1]
            action = [string]$parts[2]
            task = $taskCell
            result = [string]$parts[4]
            detail = [string]$parts[6]
            evidence = [string]$parts[7]
        }) | Out-Null
    }
    return @($rows.ToArray())
}

function Test-HasLaterSuccess {
    Param(
        [object[]]$Rows,
        [object]$FailureRow
    )
    foreach ($row in @($Rows)) {
        if ([int]$row.seq -le [int]$FailureRow.seq) { continue }
        if (-not [string]::Equals([string]$row.action, [string]$FailureRow.action, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        if ([string]::Equals([string]$row.result, "SUCCESS", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Convert-IssueToMarkdownRow {
    Param([object]$Issue)
    $evidence = if (@($Issue.evidencePaths).Count -gt 0) { [string]::Join("<br>", @($Issue.evidencePaths)) } else { "N/A" }
    return "| $($Issue.problem) | $($Issue.level) | $($Issue.actionTaken) | $($Issue.rootCauseClosed) | $($Issue.temporaryBypass) | $($Issue.openRisk) | $evidence |"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$effectiveTask = if ([string]::IsNullOrWhiteSpace($Task)) { "UNKNOWN" } else { [string]$Task }
$issues = New-Object System.Collections.Generic.List[object]

if (-not [string]::IsNullOrWhiteSpace($ProblemText)) {
    $issueLevel = if ([string]::IsNullOrWhiteSpace($Level)) { "P2" } else { [string]$Level }
    $rootStatus = if ([string]::IsNullOrWhiteSpace($RootCauseStatus)) { "否，仅缓解" } else { [string]$RootCauseStatus }
    $resolution = if ([string]::IsNullOrWhiteSpace($ActionTaken)) { "已记录到最终复盘卡，等待处置说明补齐" } else { [string]$ActionTaken }
    $bypass = if ([string]::IsNullOrWhiteSpace($TemporaryBypass)) { "否" } else { [string]$TemporaryBypass }
    $risk = if ([string]::IsNullOrWhiteSpace($OpenRisk)) { "未说明" } else { [string]$OpenRisk }
    $issues.Add((New-RecapIssue -Problem $ProblemText -PLevel $issueLevel -Resolution $resolution -RootClosed $rootStatus -Bypass $bypass -Risk $risk -Evidence $EvidencePaths)) | Out-Null
}

$rows = @(Get-OperationRows -LedgerPath "docs/治理/操作执行台账.md" -TaskName $effectiveTask)
foreach ($row in @($rows | Where-Object { [string]::Equals([string]$_.result, "FAILURE", [System.StringComparison]::OrdinalIgnoreCase) })) {
    $laterSuccess = Test-HasLaterSuccess -Rows $rows -FailureRow $row
    $rootClosed = if ($laterSuccess) { "是，已根因解决" } else { "否，仅缓解" }
    $resolution = if ($laterSuccess) {
        "同一动作后续已成功，最终收口前作为已恢复问题复核"
    }
    else {
        "失败仍未看到同动作成功记录，最终状态不得宣称全部完成"
    }
    $evidence = @()
    if (-not [string]::IsNullOrWhiteSpace([string]$row.evidence)) { $evidence += [string]$row.evidence }
    $issues.Add((New-RecapIssue `
        -Problem ("{0} failed at {1}: {2}" -f [string]$row.action, [string]$row.at, [string]$row.detail) `
        -PLevel "P1" `
        -Resolution $resolution `
        -RootClosed $rootClosed `
        -Bypass "否" `
        -Risk $(if ($laterSuccess) { "不影响本轮验收" } else { "阻断 DONE 结论" }) `
        -Evidence $evidence)) | Out-Null
}

$effectiveEvidencePaths = @(Expand-PathList -Paths $EvidencePaths)
if ($effectiveEvidencePaths.Count -eq 0) {
    $effectiveEvidencePaths = @(Expand-PathList -Paths $TargetPaths)
}

if ($issues.Count -eq 0) {
    $issues.Add((New-RecapIssue `
        -Problem "本轮未遇到阻塞或失败" `
        -PLevel "N/A" `
        -Resolution "无需处置" `
        -RootClosed "不适用，本轮未遇到阻塞或失败" `
        -Bypass "否" `
        -Risk "无" `
        -Evidence $effectiveEvidencePaths)) | Out-Null
}

$blockingIssues = @($issues | Where-Object {
    ([string]$_.level -in @("P0", "P1")) -and
    -not [string]::Equals([string]$_.rootCauseClosed, "是，已根因解决", [System.StringComparison]::OrdinalIgnoreCase)
})

$pass = ($blockingIssues.Count -eq 0) -or [bool]$AllowPartial
$finalStatus = if ($blockingIssues.Count -eq 0) { "DONE_ALLOWED" } elseif ($AllowPartial) { "PARTIAL_ALLOWED" } else { "BLOCKED" }
$safeTask = Convert-ToSafeFilePart -Text $effectiveTask
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$jsonPath = Join-Path $OutDir "final-recap-check-latest.json"
$mdPath = Join-Path $OutDir "final-recap-check-latest.md"
$taskJsonPath = Join-Path $OutDir ("task-recap-{0}-latest.json" -f $safeTask)
$taskMdPath = Join-Path $OutDir ("task-recap-{0}-latest.md" -f $safeTask)
$historyJsonPath = Join-Path $OutDir ("final-recap-check-{0}.json" -f $stamp)

$summary = [ordered]@{
    machineTag = "FINAL_RECAP_CHECK_V1"
    generatedAt = (Get-Date).ToString("s")
    task = $effectiveTask
    taskClass = [string]$TaskClass
    pass = [bool]$pass
    finalStatus = $finalStatus
    externalReplyRequired = $true
    requiredFields = @("遇到的问题", "P级", "处置动作", "根因是否闭环", "是否临时绕过", "未决风险", "证据路径")
    issues = @($issues.ToArray())
    blockingIssues = @($blockingIssues)
    evidencePaths = @($effectiveEvidencePaths)
    latestJson = "docs/治理/最新态/final-recap-check-latest.json"
    latestMarkdown = "docs/治理/最新态/final-recap-check-latest.md"
    taskJson = ("docs/治理/最新态/task-recap-{0}-latest.json" -f $safeTask)
    taskMarkdown = ("docs/治理/最新态/task-recap-{0}-latest.md" -f $safeTask)
}

$jsonText = $summary | ConvertTo-Json -Depth 8
Write-Utf8NoBom -Path $jsonPath -Content $jsonText
Write-Utf8NoBom -Path $taskJsonPath -Content $jsonText
Write-Utf8NoBom -Path $historyJsonPath -Content $jsonText

$mdLines = New-Object System.Collections.Generic.List[string]
$mdLines.Add("# Final Recap Check") | Out-Null
$mdLines.Add("") | Out-Null
$mdLines.Add(("- task: {0}" -f $effectiveTask)) | Out-Null
$mdLines.Add(("- pass: {0}" -f [bool]$pass)) | Out-Null
$mdLines.Add(("- finalStatus: {0}" -f $finalStatus)) | Out-Null
$mdLines.Add(("- externalReplyRequired: true")) | Out-Null
$mdLines.Add("") | Out-Null
$mdLines.Add("| 遇到的问题 | P级 | 处置动作 | 根因是否闭环 | 是否临时绕过 | 未决风险 | 证据路径 |") | Out-Null
$mdLines.Add("|---|---|---|---|---|---|---|") | Out-Null
foreach ($issue in @($issues.ToArray())) {
    $mdLines.Add((Convert-IssueToMarkdownRow -Issue $issue)) | Out-Null
}
$md = [string]::Join("`n", @($mdLines.ToArray())) + "`n"
Write-Utf8NoBom -Path $mdPath -Content $md
Write-Utf8NoBom -Path $taskMdPath -Content $md

if ($Json) {
    $jsonText
}
else {
    Write-Host ("final-recap-check completed: pass={0}, status={1}, latest='{2}'" -f [bool]$pass, $finalStatus, $jsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" })
}

if (-not $pass) {
    exit 1
}
