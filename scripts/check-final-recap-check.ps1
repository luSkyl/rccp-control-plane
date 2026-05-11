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
    [Alias("ExistingMechanismGap")]
    [string]$MechanismGap = "",
    [Alias("RecurrencePrevention", "Prevent")]
    [string]$Prevention = "",
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
    [string]$BlueprintRoot = "",
    [string]$BlueprintPath = "",
    [string]$OutDir = "",
    [switch]$Strict,
    [switch]$AllowPartial,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Utf8NoBom {
    Param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Content)
    $normalized = $Content -replace "`r`n", "`n" -replace "`r", "`n"
    [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false)))
}

function ConvertFrom-CodePoints {
    Param([Parameter(Mandatory = $true)][int[]]$CodePoints)
    return [string]::Concat(($CodePoints | ForEach-Object { [char]$_ }))
}

function Convert-ToSafeFilePart {
    Param([string]$Text)
    $value = if ([string]::IsNullOrWhiteSpace($Text)) { "unknown-task" } else { $Text }
    $value = $value -replace '[\\/:*?"<>|]', '-'
    $value = $value -replace '\s+', '-'
    if ($value.Length -gt 80) { $value = $value.Substring(0, 80) }
    return $value
}

function Convert-ToEvidencePathText {
    Param([string]$Path)
    return ([string]$Path).Replace("\", "/")
}

function Expand-PathList {
    Param([string[]]$Paths = @())
    $expanded = New-Object System.Collections.Generic.List[string]
    foreach ($path in @($Paths)) {
        if ([string]::IsNullOrWhiteSpace([string]$path)) { continue }
        foreach ($part in ([string]$path -split '[;,]')) {
            $value = ([string]$part).Trim().Trim('"', "'")
            if (-not [string]::IsNullOrWhiteSpace($value)) { $expanded.Add((Convert-ToEvidencePathText -Path $value)) | Out-Null }
        }
    }
    return @($expanded.ToArray() | Select-Object -Unique)
}

function New-RecapIssue {
    Param(
        [string]$Problem,
        [string]$PLevel,
        [string]$Resolution,
        [string]$RootClosed,
        [string]$MechanismGap,
        [string]$Prevention,
        [string]$Bypass,
        [string]$Risk,
        [string[]]$Evidence = @()
    )
    return [ordered]@{
        problem = [string]$Problem
        level = [string]$PLevel
        actionTaken = [string]$Resolution
        rootCauseClosed = [string]$RootClosed
        mechanismGap = [string]$MechanismGap
        recurrencePrevention = [string]$Prevention
        temporaryBypass = [string]$Bypass
        openRisk = [string]$Risk
        evidencePaths = @($Evidence | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
}

function Convert-IssueToMarkdownRow {
    Param([object]$Issue)
    $evidence = [string]::Join("<br>", @($Issue.evidencePaths))
    $cells = @($Issue.problem, $Issue.level, $Issue.actionTaken, $Issue.rootCauseClosed, $Issue.mechanismGap, $Issue.recurrencePrevention, $Issue.temporaryBypass, $Issue.openRisk, $evidence)
    return "| " + [string]::Join(" | ", @($cells | ForEach-Object { ([string]$_).Replace("|", "\|") })) + " |"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
$governanceDir = ConvertFrom-CodePoints @(0x6cbb, 0x7406)
$latestDir = ConvertFrom-CodePoints @(0x6700, 0x65b0, 0x6001)
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path (Join-Path "docs" $governanceDir) $latestDir }
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$effectiveTask = if ([string]::IsNullOrWhiteSpace($Task)) { "final-recap-check" } else { [string]$Task }
$effectiveEvidencePaths = @(Expand-PathList -Paths $EvidencePaths)
if ($effectiveEvidencePaths.Count -eq 0) { $effectiveEvidencePaths = @(Expand-PathList -Paths $TargetPaths) }

$issues = New-Object System.Collections.Generic.List[object]
if (-not [string]::IsNullOrWhiteSpace($ProblemText)) {
    $issues.Add((New-RecapIssue `
        -Problem $ProblemText `
        -PLevel $(if ([string]::IsNullOrWhiteSpace($Level)) { "P2" } else { [string]$Level }) `
        -Resolution $(if ([string]::IsNullOrWhiteSpace($ActionTaken)) { "Recorded in final recap." } else { [string]$ActionTaken }) `
        -RootClosed $(if ([string]::IsNullOrWhiteSpace($RootCauseStatus)) { "No, mitigation only." } else { [string]$RootCauseStatus }) `
        -MechanismGap $(if ([string]::IsNullOrWhiteSpace($MechanismGap)) { "Existing mechanism gap not specified." } else { [string]$MechanismGap }) `
        -Prevention $(if ([string]::IsNullOrWhiteSpace($Prevention)) { "Prevention not specified." } else { [string]$Prevention }) `
        -Bypass $(if ([string]::IsNullOrWhiteSpace($TemporaryBypass)) { "No" } else { [string]$TemporaryBypass }) `
        -Risk $(if ([string]::IsNullOrWhiteSpace($OpenRisk)) { "Unspecified" } else { [string]$OpenRisk }) `
        -Evidence $effectiveEvidencePaths)) | Out-Null
}
if ($issues.Count -eq 0) {
    $issues.Add((New-RecapIssue `
        -Problem "No blocking issue or unrecovered failure in this recap." `
        -PLevel "N/A" `
        -Resolution "No incident action required." `
        -RootClosed "Not applicable; no blocker or unrecovered failure occurred." `
        -MechanismGap "Not applicable; no blocker or unrecovered failure occurred." `
        -Prevention "Final recap and final reply contract gates remain enforced." `
        -Bypass "No" `
        -Risk "None" `
        -Evidence $effectiveEvidencePaths)) | Out-Null
}

$blockingIssues = @($issues.ToArray() | Where-Object { ([string]$_.level -in @("P0", "P1")) -and -not ([string]$_.rootCauseClosed -match "(?i)yes|closed|resolved|not applicable") })
$pass = ($blockingIssues.Count -eq 0) -or [bool]$AllowPartial
$finalStatus = if ($blockingIssues.Count -eq 0) { "DONE_ALLOWED" } elseif ($AllowPartial) { "PARTIAL_ALLOWED" } else { "BLOCKED" }
$safeTask = Convert-ToSafeFilePart -Text $effectiveTask
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$jsonPath = Join-Path $OutDir "final-recap-check-latest.json"
$mdPath = Join-Path $OutDir "final-recap-check-latest.md"
$taskJsonPath = Join-Path $OutDir ("task-recap-{0}-latest.json" -f $safeTask)
$taskMdPath = Join-Path $OutDir ("task-recap-{0}-latest.md" -f $safeTask)
$historyJsonPath = Join-Path $OutDir ("final-recap-check-{0}.json" -f $stamp)
$requiredFields = @("Problem", "Priority", "ActionTaken", "RootCauseClosed", "MechanismGap", "RecurrencePrevention", "TemporaryBypass", "OpenRisk", "EvidencePaths")
$summary = [ordered]@{
    machineTag = "FINAL_RECAP_CHECK_V1"
    generatedAt = (Get-Date).ToString("s")
    task = $effectiveTask
    taskClass = [string]$TaskClass
    pass = [bool]$pass
    finalStatus = $finalStatus
    externalReplyRequired = $true
    requiredFields = @($requiredFields)
    issues = @($issues.ToArray())
    blockingIssues = @($blockingIssues)
    evidencePaths = @($effectiveEvidencePaths)
    latestJson = Convert-ToEvidencePathText -Path $jsonPath
    latestMarkdown = Convert-ToEvidencePathText -Path $mdPath
    taskJson = Convert-ToEvidencePathText -Path $taskJsonPath
    taskMarkdown = Convert-ToEvidencePathText -Path $taskMdPath
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
$mdLines.Add("- externalReplyRequired: true") | Out-Null
$mdLines.Add("") | Out-Null
$mdLines.Add("| Problem | Priority | ActionTaken | RootCauseClosed | MechanismGap | RecurrencePrevention | TemporaryBypass | OpenRisk | EvidencePaths |") | Out-Null
$mdLines.Add("|---|---|---|---|---|---|---|---|---|") | Out-Null
foreach ($issue in @($issues.ToArray())) { $mdLines.Add((Convert-IssueToMarkdownRow -Issue $issue)) | Out-Null }
$md = [string]::Join("`n", @($mdLines.ToArray())) + "`n"
Write-Utf8NoBom -Path $mdPath -Content $md
Write-Utf8NoBom -Path $taskMdPath -Content $md
if ($Json) { $jsonText } else { Write-Host ("final-recap-check completed: pass={0}, status={1}, latest='{2}'" -f [bool]$pass, $finalStatus, $jsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }
if (-not $pass) { exit 1 }