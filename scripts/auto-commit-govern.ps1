[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "auto-commit-govern",
    [switch]$Apply,
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

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$changed = New-Object System.Collections.Generic.List[string]
$gitAvailable = $true
try {
    $status = & git status --porcelain=v1 -- README.md docs install.ps1 policies schemas scripts .github task_plan.md findings.md progress.md 2>$null
    foreach ($line in @($status)) {
        $text = [string]$line
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $changed.Add($text.Trim()) | Out-Null
    }
}
catch {
    $gitAvailable = $false
}

$pass = $gitAvailable
$latestJsonPath = Join-Path $OutDir "auto-commit-govern-latest.json"
$latestMdPath = Join-Path $OutDir "auto-commit-govern-latest.md"
$payload = [ordered]@{
    machineTag = "RCCP_AUTO_COMMIT_GOVERN_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    apply = [bool]$Apply
    pass = [bool]$pass
    semanticPass = [bool]$pass
    gitAvailable = [bool]$gitAvailable
    changedCount = [int]$changed.Count
    changed = @($changed.ToArray())
    note = "staging extraction records governance status; it does not create a git commit"
    evidencePath = "docs/治理/最新态/auto-commit-govern-latest.json"
}

Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)
$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Auto Commit Govern") | Out-Null
$md.Add("") | Out-Null
$md.Add(("- task: {0}" -f $Task)) | Out-Null
$md.Add(("- apply: {0}" -f [bool]$Apply)) | Out-Null
$md.Add(("- pass: {0}" -f [bool]$pass)) | Out-Null
$md.Add(("- changedCount: {0}" -f $changed.Count)) | Out-Null
Write-Utf8NoBom -Path $latestMdPath -Content ([string]::Join("`n", @($md.ToArray())))

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("auto-commit-govern completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
