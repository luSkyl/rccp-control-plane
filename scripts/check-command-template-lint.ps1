[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "command-template-lint",
    [string]$CommandText = "",
    [string]$CommandPath = "",
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

function Add-Violation {
    Param(
        [System.Collections.Generic.List[object]]$Violations,
        [string]$Code,
        [string]$Detail,
        [string]$Command
    )
    $Violations.Add([ordered]@{
        code = $Code
        detail = $Detail
        command = $Command
    }) | Out-Null
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$commands = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($CommandText)) {
    foreach ($line in ($CommandText -split "`n")) {
        $trimmed = ([string]$line).Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed) -and -not $trimmed.StartsWith("#")) {
            $commands.Add($trimmed) | Out-Null
        }
    }
}
if (-not [string]::IsNullOrWhiteSpace($CommandPath)) {
    $resolvedCommandPath = if ([System.IO.Path]::IsPathRooted($CommandPath)) { $CommandPath } else { Join-Path $repoRoot $CommandPath }
    if (Test-Path -LiteralPath $resolvedCommandPath -PathType Leaf) {
        foreach ($line in (Get-Content -LiteralPath $resolvedCommandPath -Encoding UTF8)) {
            $trimmed = ([string]$line).Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed) -and -not $trimmed.StartsWith("#")) {
                $commands.Add($trimmed) | Out-Null
            }
        }
    }
}

$violations = New-Object System.Collections.Generic.List[object]
if (-not [string]::IsNullOrWhiteSpace($CommandPath)) {
    $resolvedCommandPath = if ([System.IO.Path]::IsPathRooted($CommandPath)) { $CommandPath } else { Join-Path $repoRoot $CommandPath }
    if (-not (Test-Path -LiteralPath $resolvedCommandPath -PathType Leaf)) {
        Add-Violation -Violations $violations -Code "COMMAND_PATH_MISSING" -Detail $CommandPath -Command ""
    }
}

foreach ($command in @($commands.ToArray())) {
    if ($command -match '(?i)\s-Risk\s+') {
        Add-Violation -Violations $violations -Code "AMBIGUOUS_RISK_PARAMETER" -Detail "Use -RiskClass or -RiskScore; -Risk is ambiguous in the RCCP entry." -Command $command
    }
    if ($command -match '(?i)\bmvn(\.cmd)?\b.*\s-D[^\s`"''=]+=' -and $command -notmatch '["'']-D[^"'']+=') {
        Add-Violation -Violations $violations -Code "UNQUOTED_MAVEN_PROPERTY" -Detail "Quote Maven -D properties in PowerShell, e.g. `\"-DfailIfNoTests=false`\"." -Command $command
    }
    if ($command -match '(?i)Get-ChildItem\b.*\s-Filter\s+[''"][^''"]+[,;][^''"]+[''"]') {
        Add-Violation -Violations $violations -Code "MULTI_VALUE_FILTER" -Detail "Get-ChildItem -Filter accepts one pattern; use -Include or Where-Object for multiple patterns." -Command $command
    }
    if ($command -match '(?i)-Action(Name)?\s+["'']?all["'']?' -and $command -match '(?i)leaf-contract-check') {
        Add-Violation -Violations $violations -Code "LEAF_CONTRACT_ALL_AS_ACTION" -Detail "Use -RequireAllLeafScripts for full leaf contract coverage; all is not an action name." -Command $command
    }
}

$checkedInvariants = @(
    "no ambiguous RCCP -Risk template",
    "PowerShell Maven -D properties are quoted",
    "Get-ChildItem -Filter is not used with multiple patterns",
    "leaf contract full coverage uses -RequireAllLeafScripts"
)
$pass = ($violations.Count -eq 0)
$latestJsonPath = Join-Path $OutDir "command-template-lint-latest.json"
$payload = [ordered]@{
    machineTag = "RCCP_COMMAND_TEMPLATE_LINT_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    pass = [bool]$pass
    semanticPass = [bool]$pass
    commandPath = [string]$CommandPath
    checkedCommandCount = [int]$commands.Count
    checkedInvariants = @($checkedInvariants)
    blockingFailures = @($violations.ToArray())
    evidencePath = "docs/治理/最新态/command-template-lint-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("command-template-lint completed: pass={0}, violations={1}, latest='{2}'" -f [bool]$pass, [int]$violations.Count, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
