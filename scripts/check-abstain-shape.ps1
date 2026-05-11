[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "abstain-shape-check",
    [string]$Why = "",
    [string]$AnswerText = "",
    [string]$AnswerPath = "",
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

function Read-AnswerText {
    Param(
        [string]$Text,
        [string]$Path,
        [string]$RepoRoot
    )
    $answer = [string]$Text
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $resolved = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $RepoRoot $Path }
        if (Test-Path -LiteralPath $resolved -PathType Leaf) {
            $answer = Get-Content -LiteralPath $resolved -Encoding UTF8 -Raw
        }
    }
    return $answer
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$answer = Read-AnswerText -Text $AnswerText -Path $AnswerPath -RepoRoot $repoRoot
$rules = [ordered]@{
    evidenceInsufficient = "证据不足|Evidence is insufficient to confirm"
    minimalNextStep = "最小下一步|Minimal next step"
    blockedReason = "blocked|原因|reason|unsupported|missing|stale|conflicting"
    noOverclaim = "confirmed|certain|definitely|definitive|I can confirm|可以确认|已确认|肯定"
    sourcePathSupport = "source_path|evidencePath"
}

$checks = New-Object System.Collections.Generic.List[object]
foreach ($item in $rules.GetEnumerator()) {
    $ok = $false
    switch ($item.Key) {
        "evidenceInsufficient" { $ok = ($answer -match $item.Value) }
        "minimalNextStep" { $ok = ($answer -match $item.Value) }
        "blockedReason" { $ok = ($answer -match $item.Value) }
        "noOverclaim" { $ok = ($answer -notmatch $item.Value) }
        "sourcePathSupport" { $ok = ($answer -match $item.Value) }
    }
    $checks.Add([ordered]@{
        name = $item.Key
        ok = [bool]$ok
        detail = $item.Value
    }) | Out-Null
}

$failureCount = @($checks | Where-Object { -not [bool]$_.ok }).Count
$verdict = if ($failureCount -eq 0) { "PASS" } else { "FAIL" }
$latestJsonPath = Join-Path $OutDir "abstain-shape-check-latest.json"
$latestMdPath = Join-Path $OutDir "abstain-shape-check-latest.md"
$payload = [ordered]@{
    machineTag = "ABSTAIN_SHAPE_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    why = [string]$Why
    verdict = [string]$verdict
    pass = ($verdict -eq "PASS")
    failureCount = [int]$failureCount
    checks = @($checks.ToArray())
    evidencePath = "docs/治理/最新态/abstain-shape-check-latest.json"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Abstain Shape Check") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- verdict: {0}" -f $verdict)) | Out-Null
$md.Add(("- failureCount: {0}" -f $failureCount)) | Out-Null
$md.Add("") | Out-Null
$md.Add("## Checks") | Out-Null
foreach ($item in @($checks.ToArray())) {
    $md.Add(("- {0}: {1} ({2})" -f $item.name, $(if ([bool]$item.ok) { "PASS" } else { "FAIL" }), $item.detail)) | Out-Null
}
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())))

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("abstain-shape-check completed: verdict={0}, latest='{1}'" -f $verdict, $latestJsonPath) -ForegroundColor $(if ($verdict -eq "PASS") { "Green" } else { "Red" }) }

if ($Strict -and $verdict -ne "PASS") { exit 1 }
