[CmdletBinding(PositionalBinding = $false)]
Param(
    [string]$Task = "rccp-kit-rollout-check",
    [string[]]$ProjectConfigPath = @("rccp.project.json"),
    [string]$ContractPath = "docs/治理/策略/rccp-project-contract.json",
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

function Read-JsonFile {
    Param([string]$Path)
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Get-ObjectValue {
    Param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Get-StringArray {
    Param([object]$Value)
    if ($null -eq $Value) { return @() }
    return @($Value | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
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

function Test-EvidencePass {
    Param([object]$Evidence)
    if ($null -eq $Evidence) { return $false }
    $passValue = Get-ObjectValue -Object $Evidence -Name "pass"
    if ($null -ne $passValue) { return [bool]$passValue }
    $okValue = Get-ObjectValue -Object $Evidence -Name "ok"
    if ($null -ne $okValue) { return [bool]$okValue }
    $verdictValue = [string](Get-ObjectValue -Object $Evidence -Name "verdict")
    if (-not [string]::IsNullOrWhiteSpace($verdictValue)) {
        return [string]::Equals($verdictValue, "PASS", [System.StringComparison]::OrdinalIgnoreCase)
    }
    return $false
}

function Invoke-InstallSmoke {
    Param([string]$RepoRoot)
    $tempParent = [System.IO.Path]::GetTempPath()
    $tempRoot = Join-Path $tempParent ("rccp-install-smoke-" + [System.Guid]::NewGuid().ToString("N"))
    $result = [ordered]@{
        ok = $false
        targetRoot = $tempRoot
        helpExit = -1
        registryExit = -1
        taskStartExit = -1
        taskEndExit = -1
        helpOutput = ""
        registryOutput = ""
        taskStartOutput = ""
        taskEndOutput = ""
        detail = ""
    }
    function Invoke-CapturedStep {
        Param(
            [string]$CommandPath,
            [string[]]$Arguments = @()
        )
        $captured = & pwsh -NoProfile -ExecutionPolicy Bypass -File $CommandPath @Arguments 2>&1
        return [ordered]@{
            exit = [int]$LASTEXITCODE
            output = ([string]::Join("`n", @($captured | ForEach-Object { [string]$_ })))
        }
    }
    try {
        New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
        & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "install.ps1") -TargetRoot $tempRoot | Out-Null
        $help = Invoke-CapturedStep -CommandPath (Join-Path $tempRoot "rccp.ps1") -Arguments @("-Action", "help")
        $result.helpExit = $help.exit
        $result.helpOutput = $help.output
        $registry = Invoke-CapturedStep -CommandPath (Join-Path $tempRoot "rccp.ps1") -Arguments @("-Action", "action-registry-check", "-Task", "install-smoke", "-RequireAllLeafScripts", "-Strict")
        $result.registryExit = $registry.exit
        $result.registryOutput = $registry.output
        $taskStart = Invoke-CapturedStep -CommandPath (Join-Path $tempRoot "rccp.ps1") -Arguments @("-Action", "task-start", "-Task", "install-smoke", "-TargetPaths", "README.md")
        $result.taskStartExit = $taskStart.exit
        $result.taskStartOutput = $taskStart.output
        $taskEnd = Invoke-CapturedStep -CommandPath (Join-Path $tempRoot "rccp.ps1") -Arguments @("-Action", "task-end", "-Task", "install-smoke", "-CloseResult", "SUCCESS")
        $result.taskEndExit = $taskEnd.exit
        $result.taskEndOutput = $taskEnd.output

        $warningPatterns = @(
            "RCCP maintenance action 'progress-doc-auto-compact' is unavailable",
            "RCCP maintenance action 'governance-doc-auto-compact' is unavailable",
            "RCCP maintenance action 'progress-doc-auto-compact' is unavailable; skipped for staging extraction",
            "RCCP maintenance action 'governance-doc-auto-compact' is unavailable; skipped for staging extraction"
        )
        $warningHits = New-Object System.Collections.Generic.List[string]
        foreach ($text in @($result.taskStartOutput, $result.taskEndOutput)) {
            foreach ($pattern in @($warningPatterns)) {
                if ($text -like ("*" + $pattern + "*")) {
                    $warningHits.Add($pattern) | Out-Null
                }
            }
        }
        $result.detail = if ($warningHits.Count -gt 0) { [string]::Join("; ", @($warningHits.ToArray())) } else { "" }
        $result.ok = (
            $result.helpExit -eq 0 -and
            $result.registryExit -eq 0 -and
            $result.taskStartExit -eq 0 -and
            $result.taskEndExit -eq 0 -and
            $warningHits.Count -eq 0
        )
    }
    catch {
        $result.detail = $_.Exception.Message
    }
    finally {
        $fullTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        $fullTempParent = [System.IO.Path]::GetFullPath($tempParent)
        if ($fullTempRoot.StartsWith($fullTempParent, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $fullTempRoot)) {
            Remove-Item -LiteralPath $fullTempRoot -Recurse -Force
        }
    }
    return $result
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$requiredEvidence = @(
    "docs/治理/最新态/action-registry-check-latest.json",
    "docs/治理/最新态/rccp-leaf-contract-check-all-latest.json",
    "docs/治理/最新态/memory-layer-contract-latest.json",
    "docs/治理/最新态/rccp-thin-entry-check-latest.json",
    "docs/治理/最新态/command-template-lint-latest.json",
    "docs/治理/最新态/action-reference-surface-check-latest.json",
    "docs/治理/最新态/project-onboard-latest.json",
    "docs/治理/最新态/project-governance-check-latest.json"
)
$presentEvidence = @($requiredEvidence | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
$checks = New-Object System.Collections.Generic.List[object]

foreach ($path in @($requiredEvidence)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Check -Checks $checks -Name ("evidence-present:{0}" -f $path) -Ok $false -Detail "missing"
        continue
    }
    $evidence = Read-JsonFile -Path $path
    Add-Check -Checks $checks -Name ("evidence-pass:{0}" -f $path) -Ok (Test-EvidencePass -Evidence $evidence) -Detail "latest evidence must be semantically PASS"
}

$docsDispatch = Read-JsonFile -Path "docs/治理/策略/rccp-entry-dispatch.json"
$policyDispatch = Read-JsonFile -Path "policies/rccp-entry-dispatch.json"
$docsContract = Read-JsonFile -Path "docs/治理/策略/rccp-project-contract.json"
$policyContract = Read-JsonFile -Path "policies/rccp-project-contract.json"
$schemaContract = Read-JsonFile -Path "schemas/rccp-project-contract.json"
$manifest = Read-JsonFile -Path "docs/治理/策略/rccp-kit-manifest.json"
$policyManifest = Read-JsonFile -Path "policies/rccp-kit-manifest.json"

$docsDispatchComparable = (($docsDispatch | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
$policyDispatchComparable = (($policyDispatch | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
Add-Check -Checks $checks -Name "dispatch-docs-policy-mirror" -Ok ([string]::Equals($docsDispatchComparable, $policyDispatchComparable, [System.StringComparison]::Ordinal)) -Detail "docs and policies dispatch must match"

$contractComparable = (($docsContract | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
$policyContractComparable = (($policyContract | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
$schemaContractComparable = (($schemaContract | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
Add-Check -Checks $checks -Name "project-contract-mirrors" -Ok ([string]::Equals($contractComparable, $policyContractComparable, [System.StringComparison]::Ordinal) -and [string]::Equals($contractComparable, $schemaContractComparable, [System.StringComparison]::Ordinal)) -Detail "docs, policies, and schemas project contracts must match"

$manifestComparable = (($manifest | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
$policyManifestComparable = (($policyManifest | ConvertTo-Json -Depth 30) -replace "`r`n", "`n" -replace "`r", "`n")
Add-Check -Checks $checks -Name "kit-manifest-mirror" -Ok ([string]::Equals($manifestComparable, $policyManifestComparable, [System.StringComparison]::Ordinal)) -Detail "docs and policies kit manifests must match"

$availableActions = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in @($docsDispatch.entryDispatch.PSObject.Properties.Name)) { [void]$availableActions.Add([string]$name) }
foreach ($name in @($docsDispatch.coreActions)) { [void]$availableActions.Add([string]$name) }
foreach ($surface in @("readonly", "write", "runtimeWrite", "closeoutWrite")) {
    foreach ($name in @(Get-StringArray -Value (Get-ObjectValue -Object $docsDispatch.actionSurface -Name $surface))) {
        [void]$availableActions.Add([string]$name)
    }
}
$missingRequiredActions = New-Object System.Collections.Generic.List[string]
foreach ($action in @(Get-StringArray -Value $docsContract.requiredActions)) {
    if (-not $availableActions.Contains($action)) { $missingRequiredActions.Add($action) | Out-Null }
}
foreach ($action in @(Get-StringArray -Value $manifest.compatibility.requiredActions)) {
    if (-not $availableActions.Contains($action) -and -not $missingRequiredActions.Contains($action)) { $missingRequiredActions.Add($action) | Out-Null }
}
Add-Check -Checks $checks -Name "required-actions-dispatchable" -Ok ($missingRequiredActions.Count -eq 0) -Detail ($(if ($missingRequiredActions.Count -eq 0) { "all contract/manifest required actions resolve" } else { [string]::Join(",", @($missingRequiredActions.ToArray())) }))

$ciWorkflow = ".github/workflows/rccp-ci.yml"
Add-Check -Checks $checks -Name "ci-workflow-present" -Ok (Test-Path -LiteralPath $ciWorkflow -PathType Leaf) -Detail $ciWorkflow

$installSmoke = Invoke-InstallSmoke -RepoRoot $repoRoot
Add-Check -Checks $checks -Name "empty-repo-install-smoke" -Ok ([bool]$installSmoke.ok) -Detail ("helpExit={0}; registryExit={1}; {2}" -f $installSmoke.helpExit, $installSmoke.registryExit, $installSmoke.detail)

$failedChecks = @($checks.ToArray() | Where-Object { -not [bool]$_.ok })
$pass = ($failedChecks.Count -eq 0)

$latestJsonPath = Join-Path $OutDir "rccp-kit-rollout-check-latest.json"
$payload = [ordered]@{
    machineTag = "RCCP_KIT_ROLLOUT_CHECK_V1"
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
    task = [string]$Task
    pass = [bool]$pass
    semanticPass = [bool]$pass
    requiredEvidence = @($requiredEvidence)
    presentEvidence = @($presentEvidence)
    checks = @($checks.ToArray())
    missingRequiredActions = @($missingRequiredActions.ToArray())
    installSmoke = $installSmoke
    blockingFailures = @($failedChecks | ForEach-Object { ("{0}: {1}" -f $_.name, $_.detail) })
    evidencePath = "docs/治理/最新态/rccp-kit-rollout-check-latest.json"
}
Write-Utf8NoBom -Path $latestJsonPath -Content ($payload | ConvertTo-Json -Depth 12)

if ($Json) { $payload | ConvertTo-Json -Depth 12 }
else { Write-Host ("rccp-kit-rollout-check completed: pass={0}, latest='{1}'" -f [bool]$pass, $latestJsonPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" }) }

if ($Strict -and -not $pass) { exit 1 }
