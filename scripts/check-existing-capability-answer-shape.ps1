[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "existing-capability-answer-shape-check",
    [string]$Why = "",
    [string]$AnswerText = "",
    [string]$AnswerPath = "",
    [string]$TemplateMode = "",
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
    [switch]$Json
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
function Write-Utf8NoBom { Param([Parameter(Mandatory = $true)][string]$Path,[Parameter(Mandatory = $true)][string]$Content) $normalized = $Content -replace "`r`n", "`n" -replace "`r", "`n"; [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false))) }
function ConvertFrom-CodePoints { Param([Parameter(Mandatory = $true)][int[]]$CodePoints) return [string]::Concat(($CodePoints | ForEach-Object { [char]$_ })) }
function Add-Missing { Param([System.Collections.Generic.List[string]]$Missing,[string]$Name) if (-not $Missing.Contains($Name)) { $Missing.Add($Name) | Out-Null } }
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
$governanceDir = ConvertFrom-CodePoints @(0x6cbb, 0x7406)
$latestDir = ConvertFrom-CodePoints @(0x6700, 0x65b0, 0x6001)
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path (Join-Path "docs" $governanceDir) $latestDir }
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$answer = [string]$AnswerText
if (-not [string]::IsNullOrWhiteSpace($AnswerPath)) { $resolvedAnswerPath = if ([System.IO.Path]::IsPathRooted($AnswerPath)) { $AnswerPath } else { Join-Path $repoRoot $AnswerPath }; if (Test-Path -LiteralPath $resolvedAnswerPath -PathType Leaf) { $answer = Get-Content -LiteralPath $resolvedAnswerPath -Encoding UTF8 -Raw } }
$missing = New-Object System.Collections.Generic.List[string]
$templateRequested = [string]::Equals($TemplateMode, "PerfectSolutionV0V3", [System.StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($Task, "perfect-solution-answer-template-check", [System.StringComparison]::OrdinalIgnoreCase)
if ($templateRequested) {
    $templateSections = [ordered]@{
        v0 = "(?m)^#{1,4}\s*V0\b"
        v0Goal = "Main goal|target|goal|\u4E3B\u76EE\u6807|\u76EE\u6807"
        v0Acceptance = "Acceptance metrics|acceptance metric|\u9A8C\u6536\u6307\u6807|\u9A8C\u6536"
        v0NonRegression = "Non-regression|non-regression|\u4E0D\u53EF\u9000\u5316\u7EA6\u675F|\u4E0D\u53EF\u9000\u5316"
        v0Timebox = "Timebox|timebox|\u65F6\u95F4\u76D2"
        v0OutOfScope = "Out of scope|out of scope|\u672C\u8F6E\u4E0D\u505A|\u975E\u8303\u56F4|\u4E0D\u505A"
        v1 = "(?m)^#{1,4}\s*V1\b"
        v1Problem = "Problem definition|problem definition|\u95EE\u9898\u5B9A\u4E49|####\s*1\."
        v1RootHypothesis = "Root-cause hypotheses|root-cause hypotheses|\u6839\u56E0\u5047\u8BBE|####\s*2\."
        v1SelfBuiltPlan = "Self-built plan|self-built plan|\u81EA\u7814\u65B9\u6848|####\s*3\."
        v1ExecutionSteps = "Execution steps|execution steps|\u6267\u884C\u6B65\u9AA4|Step 1|\u6B65\u9AA4"
        v1RiskRollback = "Risk and rollback|risk and rollback|\u98CE\u9669\u4E0E\u56DE\u6EDA|rollback|\u56DE\u6EDA"
        v2 = "(?m)^#{1,4}\s*V2\b"
        v2Metadata = "Metadata|metadata|\u5143\u4FE1\u606F|####\s*0\."
        v2Scope = "Goals and scope|goals and scope|\u76EE\u6807\u4E0E\u8303\u56F4|scope|\u8303\u56F4"
        v2Tradeoff = "Fusion conclusion|tradeoffs|tradeoff|\u878D\u5408\u7ED3\u8BBA|\u53D6\u820D"
        v2Wbs = "WBS|Phase 1|Phased|\u5206\u9636\u6BB5\u6267\u884C\u6B65\u9AA4|\u9636\u6BB5|Phase"
        v2Milestones = "Milestones|timebox|M1|\u91CC\u7A0B\u7891|\u65F6\u95F4\u76D2"
        v2Raci = "RACI|Responsible|Accountable|Consulted|Informed|\u8D23\u4EFB\u5206\u5DE5"
        v2Prerequisites = "Prerequisites|dependency|dependencies|\u524D\u7F6E\u4F9D\u8D56|\u4F9D\u8D56"
        v2Gates = "acceptance gates|Acceptance gates|gate|\u9A8C\u6536\u95E8\u7981|\u95E8\u7981"
        v2Evidence = "Evidence output paths|evidence output|evidence paths|\u8BC1\u636E\u8F93\u51FA\u8DEF\u5F84|\u8BC1\u636E\u8DEF\u5F84"
        v2OpenItems = "Open items|next steps|Owner|\u672A\u51B3\u9879|\u4E0B\u4E00\u6B65"
        v25 = "(?m)^#{1,4}\s*V2\.5\b"
        v25Matrix = "Perf matrix|matrix|Scenario|scenario|\u538B\u6D4B\u77E9\u9635|\u573A\u666F"
        v25Metrics = "Observation metrics|metrics|\u89C2\u6D4B\u6307\u6807|\u6307\u6807"
        v25Thresholds = "Performance thresholds|thresholds|P95|P99|\u6027\u80FD\u9608\u503C|\u9608\u503C"
        v25Evidence = "Evidence paths|Logs|Snapshot|Report|\u8BC1\u636E\u8DEF\u5F84|\u65E5\u5FD7|\u5FEB\u7167|\u62A5\u544A"
        v25StopRules = "Stop-loss rules|stop rule|Failure budget|\u6B62\u635F\u89C4\u5219|\u5931\u8D25\u9884\u7B97"
        v3 = "(?m)^#{1,4}\s*V3\b"
        v3Status = "V3-A|V3-B"
        v3Confirmed = "Confirmed hypotheses|confirmed hypothesis|\u88AB\u8BC1\u5B9E\u7684\u5047\u8BBE|\u8BC1\u5B9E"
        v3Rejected = "Rejected hypotheses|rejected hypothesis|\u88AB\u63A8\u7FFB\u7684\u5047\u8BBE|\u63A8\u7FFB"
        v3Findings = "New findings|findings|\u65B0\u53D1\u73B0"
        v3FinalPlan = "Final adopted plan|adopted plan|\u6700\u7EC8\u91C7\u7528\u65B9\u6848|\u91C7\u7528\u65B9\u6848"
        v3NonGoals = "Explicit non-goals|non-goals|\u660E\u786E\u4E0D\u505A|\u4E0D\u505A\u9879"
        v3Backfill = "Perf confirmation backfill|backfill|V3-B|\u538B\u6D4B\u786E\u8BA4\u56DE\u586B|\u56DE\u586B"
    }
    foreach ($item in $templateSections.GetEnumerator()) { if ($answer -notmatch $item.Value) { Add-Missing -Missing $missing -Name ([string]$item.Key) } }
    if ($answer -match "GitHub|github|external|benchmark|open source|\u5916\u90E8|\u5BF9\u6807") { if ($answer -notmatch "authorized|authorization|explicit|allowed|requires authorization|\u6388\u6743|\u660E\u786E|\u5141\u8BB8") { Add-Missing -Missing $missing -Name "externalBenchmarkAuthorization" } }
    $claimsV3B = ($answer -match 'Current status:\s*`?V3-B|\u5F53\u524D\u72B6\u6001[:\uFF1A]\s*`?V3-B')
    if ($claimsV3B) { foreach ($pattern in @('execution scope|\u538B\u6D4B\u6267\u884C\u8303\u56F4','evidence|\u56DE\u6536\u8BC1\u636E|\u8BC1\u636E','revision|\u4FEE\u8BA2\u70B9','final conclusion|final confirmation|\u6700\u7EC8\u786E\u8BA4\u7ED3\u8BBA','backfill|\u56DE\u586B')) { if ($answer -notmatch $pattern) { Add-Missing -Missing $missing -Name ("v3bBackfill_{0}" -f $pattern.Replace(' ','_')) } } }
    $verdict = if ($missing.Count -eq 0) { "PASS" } else { "PERFECT_SOLUTION_TEMPLATE_REGRESSION" }
    $latestJsonPath = Join-Path $OutDir "perfect-solution-answer-template-check-latest.json"
    $latestMdPath = Join-Path $OutDir "perfect-solution-answer-template-check-latest.md"
    $payload = [ordered]@{ machineTag = "PERFECT_SOLUTION_ANSWER_TEMPLATE_CHECK_V2"; generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz"); task = [string]$Task; why = [string]$Why; verdict = $verdict; pass = [bool]($missing.Count -eq 0); templateMode = "PerfectSolutionV0V3"; missingSections = @($missing.ToArray()); requiredSections = @($templateSections.Keys); evidencePath = $latestJsonPath }
    Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)
    Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @("# Perfect Solution Answer Template Check", "", "- verdict: $verdict", "- missingSections: $($missing.Count)", "- templateMode: PerfectSolutionV0V3")))
    if ($Json) { $payload | ConvertTo-Json -Depth 12 } else { Write-Host ("perfect-solution-answer-template-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($missing.Count -eq 0) { "Green" } else { "Red" }) }
    if ($Strict -and $missing.Count -gt 0) { exit 1 }
    exit 0
}
$requirements = [ordered]@{ existingImplementation = "current|existing|\u73B0\u6709|\u5F53\u524D|\u57FA\u7EBF"; residualSymptom = "symptom|gap|problem|residual|current|\u75C7\u72B6|\u7F3A\u53E3|\u95EE\u9898|\u6B8B\u7559|\u5F53\u524D"; rootCause = "root cause|cause|reason|\u6839\u56E0|\u539F\u56E0|\u5047\u8BBE"; minimalRepair = "repair|action|implement|land|minimal|Self-built plan|Execution steps|Step 1|\u4FEE\u590D|\u52A8\u4F5C|\u843D\u5730|\u81EA\u7814\u65B9\u6848|\u6267\u884C\u6B65\u9AA4"; verification = "verification|gate|evidence|acceptance|PASS|\u9A8C\u8BC1|\u95E8\u7981|\u8BC1\u636E|\u9A8C\u6536|\u901A\u8FC7" }
foreach ($item in $requirements.GetEnumerator()) { if ($answer -notmatch $item.Value) { Add-Missing -Missing $missing -Name ([string]$item.Key) } }
$usesLayeredProtocol = ($answer -match "v1|V1|v2|V2|v3|V3|GitHub|github|greenfield|redesign")
if ($usesLayeredProtocol) { $layerRequirements = [ordered]@{ v1Delta = "v1|V1|minimal|delta|existing|current|\u6700\u5C0F|\u5DEE\u91CF|\u73B0\u6709|\u5F53\u524D|\u81EA\u7814"; v2Authorization = "v2|V2|authorized|authorization|GitHub|github|external|\u6388\u6743|\u5BF9\u6807|\u5916\u90E8|\u878D\u5408"; v3Authorization = "v3|V3|greenfield|redesign|from scratch|explicit|\u91CD\u6784|\u4ECE\u96F6|\u660E\u786E|\u6536\u655B"; rollbackOrRisk = "rollback|risk|migration|cost|\u56DE\u6EDA|\u98CE\u9669|\u8FC1\u79FB|\u6210\u672C"; acceptanceGate = "gate|acceptance|verification|PASS|evidence|\u95E8\u7981|\u9A8C\u6536|\u9A8C\u8BC1|\u901A\u8FC7|\u8BC1\u636E" }; foreach ($item in $layerRequirements.GetEnumerator()) { if ($answer -notmatch $item.Value) { Add-Missing -Missing $missing -Name ([string]$item.Key) } } }
$verdict = if ($missing.Count -eq 0) { "PASS" } else { "GREENFIELD_ANSWER_REGRESSION" }
$latestJsonPath = Join-Path $OutDir "existing-capability-answer-shape-latest.json"
$latestMdPath = Join-Path $OutDir "existing-capability-answer-shape-latest.md"
$payload = [ordered]@{ machineTag = "EXISTING_CAPABILITY_ANSWER_SHAPE_CHECK_V1"; generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz"); task = [string]$Task; why = [string]$Why; verdict = $verdict; missingSections = @($missing.ToArray()); usesLayeredProtocol = [bool]$usesLayeredProtocol; evidencePath = $latestJsonPath }
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @("# Existing Capability Answer Shape Check", "", "- verdict: $verdict", "- missingSections: $($missing.Count)", "- usesLayeredProtocol: $usesLayeredProtocol")))
if ($Json) { $payload | ConvertTo-Json -Depth 12 } else { Write-Host ("existing-capability-answer-shape-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($missing.Count -eq 0) { "Green" } else { "Red" }) }
if ($Strict -and $missing.Count -gt 0) { exit 1 }
