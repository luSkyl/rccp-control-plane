[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "final-reply-contract-regression",
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

function Invoke-Case {
    Param(
        [string]$Name,
        [string]$RecapPath,
        [string]$AnswerPath = "",
        [bool]$ExpectPass
    )
    $scriptPath = Join-Path $PSScriptRoot "check-final-reply-contract-check.ps1"
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath, "-Task", $Name, "-RecapPath", $RecapPath, "-OutDir", $caseOutDir)
    if (-not [string]::IsNullOrWhiteSpace($AnswerPath)) {
        $args += @("-AnswerPath", $AnswerPath)
    }
    & pwsh @args | Out-Null
    $passed = ($LASTEXITCODE -eq 0)
    return [ordered]@{
        name = $Name
        expectedPass = [bool]$ExpectPass
        actualPass = [bool]$passed
        pass = ([bool]$passed -eq [bool]$ExpectPass)
        exitCode = [int]$LASTEXITCODE
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$caseOutDir = Join-Path $OutDir "final-reply-contract-regression"
if (-not (Test-Path -LiteralPath $caseOutDir)) { New-Item -ItemType Directory -Path $caseOutDir -Force | Out-Null }

$requiredFields = @("遇到的问题", "P级", "处置动作", "根因是否闭环", "已有机制为什么没挡住", "防复发机制", "是否临时绕过", "未决风险", "证据路径")
$passRecapPath = Join-Path $caseOutDir "pass-recap.json"
$blockedRecapPath = Join-Path $caseOutDir "blocked-recap.json"
$goodAnswerPath = Join-Path $caseOutDir "good-answer.md"
$missingFieldsAnswerPath = Join-Path $caseOutDir "missing-fields-answer.md"
$missingRootAnswerPath = Join-Path $caseOutDir "missing-root-answer.md"
$missingMechanismAnswerPath = Join-Path $caseOutDir "missing-mechanism-answer.md"
$falseDoneAnswerPath = Join-Path $caseOutDir "false-done-answer.md"

$passRecap = [ordered]@{
    machineTag = "FINAL_RECAP_CHECK_V1"
    task = "final-reply-contract-regression-pass"
    pass = $true
    finalStatus = "DONE_ALLOWED"
    externalReplyRequired = $true
    requiredFields = $requiredFields
    issues = @([ordered]@{
        problem = "本轮未遇到阻塞或失败"
        level = "N/A"
        actionTaken = "无需处置"
        rootCauseClosed = "不适用，本轮未遇到阻塞或失败"
        mechanismGap = "不适用，本轮未遇到阻塞或失败"
        recurrencePrevention = "最终复盘和最终回复契约门禁继续执行"
        temporaryBypass = "否"
        openRisk = "无"
        evidencePaths = @("docs/治理/最新态/action-registry-check-latest.json")
    })
    blockingIssues = @()
    evidencePaths = @("docs/治理/最新态/action-registry-check-latest.json")
}
$blockedIssue = [ordered]@{
    problem = "final reply omitted root cause"
    level = "P1"
    actionTaken = "must block final answer"
    rootCauseClosed = "否，仅缓解"
    mechanismGap = "最终回复只看完成声明，没有强制携带根因闭环状态"
    recurrencePrevention = "最终回复契约门禁阻断缺少根因字段或 false done 的回答"
    temporaryBypass = "否"
    openRisk = "阻断 DONE 结论"
    evidencePaths = @("docs/治理/最新态/final-recap-check-latest.json")
}
$blockedRecap = [ordered]@{
    machineTag = "FINAL_RECAP_CHECK_V1"
    task = "final-reply-contract-regression-blocked"
    pass = $false
    finalStatus = "BLOCKED"
    externalReplyRequired = $true
    requiredFields = $requiredFields
    issues = @($blockedIssue)
    blockingIssues = @($blockedIssue)
    evidencePaths = @("docs/治理/最新态/final-recap-check-latest.json")
}

Write-Utf8NoBom -Path $passRecapPath -Content ($passRecap | ConvertTo-Json -Depth 12)
Write-Utf8NoBom -Path $blockedRecapPath -Content ($blockedRecap | ConvertTo-Json -Depth 12)
Write-Utf8NoBom -Path $goodAnswerPath -Content @"
遇到的问题：本轮未遇到阻塞或失败
P级：N/A
处置动作：无需处置
根因是否闭环：不适用，本轮未遇到阻塞或失败
已有机制为什么没挡住：不适用，本轮未遇到阻塞或失败
防复发机制：最终复盘和最终回复契约门禁继续执行
是否临时绕过：否
未决风险：无
证据路径：docs/治理/最新态/action-registry-check-latest.json
"@
Write-Utf8NoBom -Path $missingFieldsAnswerPath -Content "完成了"
Write-Utf8NoBom -Path $missingRootAnswerPath -Content @"
遇到的问题：本轮未遇到阻塞或失败
P级：N/A
处置动作：无需处置
是否临时绕过：否
未决风险：无
证据路径：docs/治理/最新态/action-registry-check-latest.json
"@
Write-Utf8NoBom -Path $missingMechanismAnswerPath -Content @"
遇到的问题：本轮未遇到阻塞或失败
P级：N/A
处置动作：无需处置
根因是否闭环：不适用，本轮未遇到阻塞或失败
防复发机制：最终复盘和最终回复契约门禁继续执行
是否临时绕过：否
未决风险：无
证据路径：docs/治理/最新态/action-registry-check-latest.json
"@
Write-Utf8NoBom -Path $falseDoneAnswerPath -Content @"
遇到的问题：final reply omitted root cause
P级：P1
处置动作：must block final answer
根因是否闭环：否，仅缓解
已有机制为什么没挡住：最终回复只看完成声明，没有强制携带根因闭环状态
防复发机制：最终回复契约门禁阻断缺少根因字段或 false done 的回答
是否临时绕过：否
未决风险：阻断 DONE 结论
证据路径：docs/治理/最新态/final-recap-check-latest.json
已完成，全部解决。
"@

$results = @(
    Invoke-Case -Name "positive-complete-reply" -RecapPath $passRecapPath -AnswerPath $goodAnswerPath -ExpectPass $true
    Invoke-Case -Name "negative-missing-answer-source" -RecapPath $passRecapPath -ExpectPass $false
    Invoke-Case -Name "negative-only-completed" -RecapPath $passRecapPath -AnswerPath $missingFieldsAnswerPath -ExpectPass $false
    Invoke-Case -Name "negative-missing-root-status" -RecapPath $passRecapPath -AnswerPath $missingRootAnswerPath -ExpectPass $false
    Invoke-Case -Name "negative-missing-mechanism-gap" -RecapPath $passRecapPath -AnswerPath $missingMechanismAnswerPath -ExpectPass $false
    Invoke-Case -Name "negative-false-done-with-blocker" -RecapPath $blockedRecapPath -AnswerPath $falseDoneAnswerPath -ExpectPass $false
)

$failed = @($results | Where-Object { -not [bool]$_.pass })
$pass = ($failed.Count -eq 0)
$latestJsonPath = Join-Path $OutDir "final-reply-contract-regression-latest.json"
$latestMdPath = Join-Path $OutDir "final-reply-contract-regression-latest.md"
$payload = [ordered]@{
    machineTag = "FINAL_REPLY_CONTRACT_REGRESSION_V1"
    generatedAt = (Get-Date).ToString("s")
    task = [string]$Task
    pass = [bool]$pass
    caseCount = @($results).Count
    failedCount = $failed.Count
    results = @($results)
    evidencePath = "docs/治理/最新态/final-reply-contract-regression-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

$mdLines = New-Object System.Collections.Generic.List[string]
$mdLines.Add("# Final Reply Contract Regression") | Out-Null
$mdLines.Add("") | Out-Null
$mdLines.Add(("- pass: {0}" -f [bool]$pass)) | Out-Null
foreach ($result in @($results)) {
    $mdLines.Add(("- {0}: expected={1}; actual={2}; pass={3}" -f $result.name, $result.expectedPass, $result.actualPass, $result.pass)) | Out-Null
}
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($mdLines.ToArray())) + "`n")

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("final-reply-contract-regression completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if (-not $pass) {
    exit 1
}
