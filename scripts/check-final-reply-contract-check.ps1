[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "final-reply-contract-check",
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
    [string]$AnswerText = "",
    [string]$AnswerPath = "",
    [string]$RecapPath = "docs/治理/最新态/final-recap-check-latest.json",
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

function Resolve-RepoPath {
    Param([string]$RepoRoot, [string]$PathText)
    if ([string]::IsNullOrWhiteSpace($PathText)) { return "" }
    if ([System.IO.Path]::IsPathRooted($PathText)) { return $PathText }
    return (Join-Path $RepoRoot $PathText)
}

function Get-PropertyValue {
    Param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Convert-ToList {
    Param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @([string]$Value)
    }
    return @($Value | ForEach-Object { $_ })
}

function Add-Failure {
    Param(
        [System.Collections.Generic.List[object]]$Failures,
        [string]$Code,
        [string]$Detail
    )
    $Failures.Add([ordered]@{
        code = $Code
        detail = $Detail
    }) | Out-Null
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$failures = New-Object System.Collections.Generic.List[object]
$resolvedRecapPath = Resolve-RepoPath -RepoRoot $repoRoot -PathText $RecapPath
$resolvedAnswerPath = Resolve-RepoPath -RepoRoot $repoRoot -PathText $AnswerPath

$recap = $null
if (-not (Test-Path -LiteralPath $resolvedRecapPath -PathType Leaf)) {
    Add-Failure -Failures $failures -Code "MISSING_RECAP" -Detail $RecapPath
}
else {
    $recap = Get-Content -LiteralPath $resolvedRecapPath -Encoding UTF8 -Raw | ConvertFrom-Json
}

$answer = [string]$AnswerText
$hasAnswerText = -not [string]::IsNullOrWhiteSpace($AnswerText)
$hasAnswerPath = -not [string]::IsNullOrWhiteSpace($AnswerPath)
if (-not $hasAnswerText -and -not $hasAnswerPath) {
    Add-Failure -Failures $failures -Code "MISSING_ANSWER_SOURCE" -Detail "pass -AnswerText or -AnswerPath for the current final external reply draft"
}
elseif (-not $hasAnswerText -and $hasAnswerPath) {
    if (Test-Path -LiteralPath $resolvedAnswerPath -PathType Leaf) {
        $answer = Get-Content -LiteralPath $resolvedAnswerPath -Encoding UTF8 -Raw
    }
    else {
        Add-Failure -Failures $failures -Code "MISSING_ANSWER" -Detail $AnswerPath
    }
}
if ([string]::IsNullOrWhiteSpace($answer) -and ($hasAnswerText -or $hasAnswerPath)) {
    Add-Failure -Failures $failures -Code "EMPTY_ANSWER" -Detail "final external reply draft is empty"
}

$requiredFields = @("遇到的问题", "P级", "处置动作", "根因是否闭环", "是否临时绕过", "未决风险", "证据路径")
$externalReplyRequired = $true
$finalStatus = "UNKNOWN"
$blockingIssueCount = 0
$evidenceCandidates = New-Object System.Collections.Generic.List[string]
$rootStatusCandidates = New-Object System.Collections.Generic.List[string]
$mechanismGapCandidates = New-Object System.Collections.Generic.List[string]
$preventionCandidates = New-Object System.Collections.Generic.List[string]

if ($null -ne $recap) {
    $externalValue = Get-PropertyValue -Object $recap -Name "externalReplyRequired"
    if ($null -ne $externalValue) { $externalReplyRequired = [bool]$externalValue }
    $configuredFields = @(Convert-ToList -Value (Get-PropertyValue -Object $recap -Name "requiredFields") | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($configuredFields.Count -gt 0) { $requiredFields = @($configuredFields) }
    $finalStatusValue = Get-PropertyValue -Object $recap -Name "finalStatus"
    if ($null -ne $finalStatusValue) { $finalStatus = [string]$finalStatusValue }
    $blockingIssueCount = @(Convert-ToList -Value (Get-PropertyValue -Object $recap -Name "blockingIssues")).Count

    foreach ($path in @(Convert-ToList -Value (Get-PropertyValue -Object $recap -Name "evidencePaths"))) {
        $value = [string]$path
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $evidenceCandidates.Add($value) | Out-Null
            $trimmedValue = $value.Trim('"', "'")
            if (-not [string]::Equals($value, $trimmedValue, [System.StringComparison]::Ordinal)) {
                $evidenceCandidates.Add($trimmedValue) | Out-Null
            }
        }
    }
    foreach ($issue in @(Convert-ToList -Value (Get-PropertyValue -Object $recap -Name "issues"))) {
        $rootStatus = [string](Get-PropertyValue -Object $issue -Name "rootCauseClosed")
        if (-not [string]::IsNullOrWhiteSpace($rootStatus)) { $rootStatusCandidates.Add($rootStatus) | Out-Null }
        $mechanismGap = [string](Get-PropertyValue -Object $issue -Name "mechanismGap")
        if (-not [string]::IsNullOrWhiteSpace($mechanismGap)) { $mechanismGapCandidates.Add($mechanismGap) | Out-Null }
        $prevention = [string](Get-PropertyValue -Object $issue -Name "recurrencePrevention")
        if (-not [string]::IsNullOrWhiteSpace($prevention)) { $preventionCandidates.Add($prevention) | Out-Null }
        foreach ($path in @(Convert-ToList -Value (Get-PropertyValue -Object $issue -Name "evidencePaths"))) {
            $value = [string]$path
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $evidenceCandidates.Add($value) | Out-Null
                $trimmedValue = $value.Trim('"', "'")
                if (-not [string]::Equals($value, $trimmedValue, [System.StringComparison]::Ordinal)) {
                    $evidenceCandidates.Add($trimmedValue) | Out-Null
                }
            }
        }
    }
}

if ($externalReplyRequired) {
    foreach ($field in @($requiredFields)) {
        if ($answer -notlike ("*" + $field + "*")) {
            Add-Failure -Failures $failures -Code "MISSING_REQUIRED_FIELD" -Detail $field
        }
    }

    $hasEvidencePath = $false
    foreach ($path in @($evidenceCandidates.ToArray() | Select-Object -Unique)) {
        if ($answer -like ("*" + $path + "*")) {
            $hasEvidencePath = $true
            break
        }
    }
    if (@($evidenceCandidates.ToArray()).Count -gt 0 -and -not $hasEvidencePath) {
        Add-Failure -Failures $failures -Code "MISSING_EVIDENCE_PATH_VALUE" -Detail "answer must include at least one recap evidence path"
    }

    foreach ($status in @($rootStatusCandidates.ToArray() | Select-Object -Unique)) {
        if ($answer -notlike ("*" + $status + "*")) {
            Add-Failure -Failures $failures -Code "MISSING_ROOT_CAUSE_STATUS_VALUE" -Detail $status
        }
    }

    foreach ($mechanismGap in @($mechanismGapCandidates.ToArray() | Select-Object -Unique)) {
        if ($answer -notlike ("*" + $mechanismGap + "*")) {
            Add-Failure -Failures $failures -Code "MISSING_MECHANISM_GAP_VALUE" -Detail $mechanismGap
        }
    }

    foreach ($prevention in @($preventionCandidates.ToArray() | Select-Object -Unique)) {
        if ($answer -notlike ("*" + $prevention + "*")) {
            Add-Failure -Failures $failures -Code "MISSING_PREVENTION_VALUE" -Detail $prevention
        }
    }
}

$completionClaimPattern = "(?i)(DONE_ALLOWED|DONE|completed|complete|closed|fixed)|已完成|完成了|已闭环|全部解决|全部完成|根因解决"
if (($blockingIssueCount -gt 0 -or -not [string]::Equals($finalStatus, "DONE_ALLOWED", [System.StringComparison]::OrdinalIgnoreCase)) -and $answer -match $completionClaimPattern) {
    Add-Failure -Failures $failures -Code "FALSE_DONE_CLAIM" -Detail ("finalStatus={0}; blockingIssues={1}" -f $finalStatus, $blockingIssueCount)
}

$pass = ($failures.Count -eq 0)
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$latestJsonPath = Join-Path $OutDir "final-reply-contract-check-latest.json"
$latestMdPath = Join-Path $OutDir "final-reply-contract-check-latest.md"
$historyJsonPath = Join-Path $OutDir ("final-reply-contract-check-{0}.json" -f $stamp)

$payload = [ordered]@{
    machineTag = "FINAL_REPLY_CONTRACT_CHECK_V1"
    generatedAt = (Get-Date).ToString("s")
    task = [string]$Task
    pass = [bool]$pass
    finalStatus = [string]$finalStatus
    externalReplyRequired = [bool]$externalReplyRequired
    answerSource = $(if ($hasAnswerText) { "AnswerText" } elseif ($hasAnswerPath) { "AnswerPath" } else { "none" })
    answerPath = [string]$AnswerPath
    recapPath = [string]$RecapPath
    requiredFields = @($requiredFields)
    blockingIssueCount = [int]$blockingIssueCount
    checkedEvidencePathCount = [int]@($evidenceCandidates.ToArray()).Count
    checkedRootStatusCount = [int]@($rootStatusCandidates.ToArray()).Count
    checkedMechanismGapCount = [int]@($mechanismGapCandidates.ToArray()).Count
    checkedPreventionCount = [int]@($preventionCandidates.ToArray()).Count
    failures = @($failures.ToArray())
    evidencePath = "docs/治理/最新态/final-reply-contract-check-latest.json"
}

$jsonText = $payload | ConvertTo-Json -Depth 12
Write-Utf8NoBom -Path $latestJsonPath -Content $jsonText
Write-Utf8NoBom -Path $historyJsonPath -Content $jsonText

$mdLines = New-Object System.Collections.Generic.List[string]
$mdLines.Add("# Final Reply Contract Check") | Out-Null
$mdLines.Add("") | Out-Null
$mdLines.Add(("- task: {0}" -f $Task)) | Out-Null
$mdLines.Add(("- pass: {0}" -f [bool]$pass)) | Out-Null
$mdLines.Add(("- finalStatus: {0}" -f $finalStatus)) | Out-Null
$mdLines.Add(("- answerPath: {0}" -f $AnswerPath)) | Out-Null
$mdLines.Add(("- recapPath: {0}" -f $RecapPath)) | Out-Null
$mdLines.Add("") | Out-Null
$mdLines.Add("## Failures") | Out-Null
if ($failures.Count -eq 0) {
    $mdLines.Add("- none") | Out-Null
}
else {
    foreach ($failure in @($failures.ToArray())) {
        $mdLines.Add(("- {0}: {1}" -f $failure.code, $failure.detail)) | Out-Null
    }
}
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($mdLines.ToArray())) + "`n")

if ($Json) {
    $jsonText
}
else {
    Write-Host ("final-reply-contract-check completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" })
}

if (-not $pass) {
    exit 1
}
