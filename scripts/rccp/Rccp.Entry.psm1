[CmdletBinding(PositionalBinding = $false)]
Param()

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Rccp.Cli.psm1") -Force

function Get-HelpSourceVersionStamp {
    Param([string]$Path)
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
    $resolved = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $repoRoot $Path }
    if (-not (Test-Path -LiteralPath $resolved)) {
        return ("{0}=MISSING" -f $Path)
    }
    $item = Get-Item -LiteralPath $resolved
    return ("{0}=len:{1};mtime:{2:O}" -f $Path, [int64]$item.Length, $item.LastWriteTimeUtc)
}

function Add-RccpTextArg {
    Param(
        [System.Collections.Generic.List[string]]$ArgList,
        [string]$Name,
        [string]$Value
    )
    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        $ArgList.Add($Name) | Out-Null
        $ArgList.Add($Value) | Out-Null
    }
}

function Add-RccpListArg {
    Param(
        [System.Collections.Generic.List[string]]$ArgList,
        [string]$Name,
        [string[]]$Values = @()
    )
    $packed = @($Values | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($packed.Count -gt 0) {
        $ArgList.Add($Name) | Out-Null
        $ArgList.Add([string]::Join(";", $packed)) | Out-Null
    }
}

function Merge-RccpListArgsFromRemaining {
    Param([hashtable]$BoundArgs)
    $remaining = @($BoundArgs.RemainingArgs)
    if ($remaining.Count -eq 0) { return }

    $listParams = @{
        "targetpaths" = "TargetPaths"
        "evidencepaths" = "EvidencePaths"
        "projectconfigpath" = "ProjectConfigPath"
        "excludesuggestionid" = "ExcludeSuggestionId"
    }
    $passthrough = New-Object System.Collections.Generic.List[object]
    $activeListName = $null
    if ($BoundArgs.ContainsKey("TargetPaths") -and @($BoundArgs.TargetPaths).Count -gt 0) {
        $activeListName = "TargetPaths"
    }

    foreach ($raw in $remaining) {
        $arg = [string]$raw
        if ([string]::IsNullOrWhiteSpace($arg)) { continue }
        if ($arg.StartsWith("-", [System.StringComparison]::Ordinal)) {
            $name = $arg.TrimStart("-").ToLowerInvariant()
            if ($listParams.ContainsKey($name)) {
                $activeListName = [string]$listParams[$name]
                if (-not $BoundArgs.ContainsKey($activeListName)) { $BoundArgs[$activeListName] = @() }
                continue
            }
            $activeListName = $null
            $passthrough.Add($raw) | Out-Null
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($activeListName)) {
            $BoundArgs[$activeListName] = @(@($BoundArgs[$activeListName]) + $arg)
            continue
        }
        $passthrough.Add($raw) | Out-Null
    }
    $BoundArgs.RemainingArgs = @($passthrough.ToArray())
}

function Get-RccpEntryDispatchMap {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
    foreach ($dispatchPath in @(
            (Join-Path $repoRoot "policies/rccp-entry-dispatch.json"),
            (Join-Path $repoRoot "docs/治理/策略/rccp-entry-dispatch.json")
        )) {
        if (-not (Test-Path -LiteralPath $dispatchPath -PathType Leaf)) { continue }
        try {
            $doc = Get-Content -LiteralPath $dispatchPath -Encoding UTF8 -Raw | ConvertFrom-Json
            if ($null -ne $doc.entryDispatch) { return $doc.entryDispatch }
        }
        catch {
        }
    }
    return [ordered]@{
        "existing-capability-probe" = "scripts/check-existing-capability-probe.ps1"
        "existing-capability-answer-shape-check" = "scripts/check-existing-capability-answer-shape.ps1"
        "final-recap-check" = "scripts/check-final-recap-check.ps1"
        "final-reply-contract-check" = "scripts/check-final-reply-contract-check.ps1"
        "thin-entry-check" = "scripts/check-rccp-thin-entry.ps1"
        "rccp-leaf-contract-check" = "scripts/check-rccp-leaf-contract.ps1"
        "leaf-contract-check" = "scripts/check-rccp-leaf-contract.ps1"
        "memory-layer-contract-check" = "scripts/check-memory-layer-contract.ps1"
        "memory-briefing" = "scripts/invoke-memory-briefing.ps1"
        "memory-source-contract-check" = "scripts/check-memory-source-contract.ps1"
        "memory-ingest-plan" = "scripts/check-memory-ingest-plan.ps1"
        "memory-recall-check" = "scripts/check-memory-recall-check.ps1"
        "abstain-shape-check" = "scripts/check-abstain-shape.ps1"
        "obsidian-second-brain-contract-check" = "scripts/check-obsidian-second-brain-contract.ps1"
        "action-registry-check" = "scripts/check-rccp-action-registry.ps1"
        "command-template-lint" = "scripts/check-command-template-lint.ps1"
        "project-onboard" = "scripts/check-project-onboard.ps1"
        "project-governance-check" = "scripts/check-project-governance.ps1"
        "rccp-kit-compat-check" = "scripts/check-rccp-kit-compat.ps1"
        "kit-compat-check" = "scripts/check-rccp-kit-compat.ps1"
        "rccp-kit-rollout-check" = "scripts/check-rccp-kit-rollout.ps1"
        "kit-rollout-check" = "scripts/check-rccp-kit-rollout.ps1"
    }
}

function New-RccpCliArgs {
    Param(
        [Parameter(Mandatory = $true)][string]$CliAction,
        [string]$Task = "",
        [string]$CurrentState = "",
        [string]$NextStep = "",
        [string[]]$TargetPaths = @(),
        [string[]]$EvidencePaths = @(),
        [ValidateSet("DISCUSS_ONLY", "QUICK", "MICRO_SAFE", "NORMAL", "RISKY", "RELEASE")]
        [string]$RiskClass = "NORMAL",
        [string]$SuggestionId = "",
        [string]$IssueId = "",
        [string]$ProgressId = "",
        [string]$RecentSection = "",
        [Alias("Result")]
        [ValidateSet("SUCCESS", "FAILURE")]
        [string]$CloseResult = "SUCCESS",
        [string]$Mode = "Staged",
        [string]$GateProfile = "Fast",
        [string]$Objective = "",
        [string]$AcceptanceCriteria = "",
        [string]$MainBlockingPath = "",
        [string]$ParallelizableSlices = "",
        [string]$NoDelegateReasons = "",
        [string]$SubAgentEvidence = "",
        [string]$MainIntegrationResult = "",
        [string]$CloseoutEvidence = "",
        [string]$BlueprintRoot = "docs/治理/方案蓝图",
        [string]$BlueprintPath = "",
        [string]$CommandText = "",
        [string]$CommandPath = "",
        [string]$AnswerText = "",
        [string]$AnswerPath = "",
        [string]$RecapPath = "",
        [string[]]$ProjectConfigPath = @(),
        [string]$ContractPath = "",
        [string]$ProjectRoot = "",
        [string]$Profile = "",
        [string]$OutDir = "",
        [ValidateSet("Latest", "Transient")]
        [string]$EvidenceMode = "Latest",
        [switch]$NoPersist,
        [switch]$CurrentSectionOnly,
        [switch]$IsolateHistoricalDebt,
        [string]$SuggestionTitle = "",
        [string]$SuggestionContent = "",
        [string]$SuggestionSource = "",
        [string]$SuggestionPriority = "",
        [string]$SuggestionStatus = "",
        [string]$SuggestionTrigger = "",
        [string]$SuggestionNote = "",
        [string]$Title = "",
        [string]$Why = "",
        [string]$How = "",
        [string]$Prevent = "",
        [string]$Verify = "",
        [int]$ImpactScore = 0,
        [int]$RiskScore = 0,
        [int]$FrequencyScore = 0,
        [int]$TimeScore = 0,
        [int]$CostScore = 0,
        [string[]]$ExcludeSuggestionId = @(),
        [switch]$Apply,
        [switch]$RequireV3B,
        [switch]$Strict,
        [switch]$Json,
        [object[]]$RemainingArgs = @()
    )
    $argsForCli = @{
        Action = $CliAction
        Task = $Task
        CurrentState = $CurrentState
        NextStep = $NextStep
        TargetPaths = @($TargetPaths)
        EvidencePaths = @($EvidencePaths)
        RiskClass = $RiskClass
        SuggestionId = $SuggestionId
        IssueId = $IssueId
        ProgressId = $ProgressId
        RecentSection = $RecentSection
        Result = $CloseResult
        Mode = $Mode
        GateProfile = $GateProfile
        Objective = $Objective
        AcceptanceCriteria = $AcceptanceCriteria
        MainBlockingPath = $MainBlockingPath
        ParallelizableSlices = $ParallelizableSlices
        NoDelegateReasons = $NoDelegateReasons
        SubAgentEvidence = $SubAgentEvidence
        MainIntegrationResult = $MainIntegrationResult
        CloseoutEvidence = $CloseoutEvidence
        BlueprintRoot = $BlueprintRoot
        BlueprintPath = $BlueprintPath
    }
    if ($RequireV3B) { $argsForCli.RequireV3B = $true }
    if ($Strict) { $argsForCli.Strict = $true }
    if ($Json) { $argsForCli.Json = $true }
    return $argsForCli
}

function Invoke-RccpCoreAction {
    Param(
        [Parameter(Mandatory = $true)][string]$CliAction,
        [hashtable]$BoundArgs
    )
    $cliBoundArgs = @{}
    foreach ($key in @($BoundArgs.Keys)) {
        if ([string]::Equals([string]$key, "RemainingArgs", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $cliBoundArgs[$key] = $BoundArgs[$key]
    }
    $cliArgs = New-RccpCliArgs @cliBoundArgs -CliAction $CliAction
    Invoke-RccpCli @cliArgs
}

function Invoke-RccpTaskBootstrap {
    Param([hashtable]$BoundArgs)
    Invoke-RccpCoreAction -CliAction "declare" -BoundArgs $BoundArgs
    $checkpointState = if ([string]::IsNullOrWhiteSpace([string]$BoundArgs.CurrentState)) { "RCCP bootstrap initialized" } else { [string]$BoundArgs.CurrentState }
    $checkpointNext = if ([string]::IsNullOrWhiteSpace([string]$BoundArgs.NextStep)) { "continue under RCCP event store" } else { [string]$BoundArgs.NextStep }
    $checkpointBoundArgs = @{}
    foreach ($key in @($BoundArgs.Keys)) {
        if ([string]::Equals([string]$key, "RemainingArgs", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $checkpointBoundArgs[$key] = $BoundArgs[$key]
    }
    $checkpointArgs = New-RccpCliArgs @checkpointBoundArgs -CliAction "checkpoint"
    $checkpointArgs.CurrentState = $checkpointState
    $checkpointArgs.NextStep = $checkpointNext
    Invoke-RccpCli @checkpointArgs
    Invoke-RccpCoreAction -CliAction "lease-acquire" -BoundArgs $BoundArgs
}

function Invoke-RccpMaintenanceLeaf {
    Param(
        [Parameter(Mandatory = $true)][string]$ActionName,
        [string[]]$Arguments = @(),
        [switch]$HardFail
    )
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
    $leaf = Resolve-RccpLeafScript -ActionName $ActionName -BoundArgs @{}
    if ([string]::IsNullOrWhiteSpace($leaf)) {
        $message = "RCCP maintenance action '$ActionName' is unavailable."
        if ($HardFail) { throw $message }
        Write-Warning $message
        return
    }
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $leaf @Arguments
    if ($LASTEXITCODE -ne 0) {
        $message = ("RCCP maintenance action '{0}' failed with exit={1}" -f $ActionName, $LASTEXITCODE)
        if ($HardFail) { throw $message }
        Write-Warning $message
    }
}

function Invoke-RccpTaskStartMaintenance {
    Param([hashtable]$BoundArgs)
    $taskName = if ($BoundArgs.ContainsKey("Task")) { [string]$BoundArgs.Task } else { "" }
    Invoke-RccpMaintenanceLeaf -ActionName "progress-doc-auto-compact" -Arguments @("-Task", $taskName, "-RunMode", "task-start")
    Invoke-RccpMaintenanceLeaf -ActionName "governance-doc-auto-compact" -Arguments @("-Task", $taskName, "-RunMode", "task-start")
}

function Invoke-RccpTaskEndPreCloseMaintenance {
    Param([hashtable]$BoundArgs)
    $taskName = if ($BoundArgs.ContainsKey("Task")) { [string]$BoundArgs.Task } else { "" }
    foreach ($actionName in @("progress-doc-auto-compact", "governance-doc-auto-compact")) {
        $leaf = Resolve-RccpLeafScript -ActionName $actionName -BoundArgs @{}
        if ([string]::IsNullOrWhiteSpace($leaf)) {
            Write-Warning ("RCCP maintenance action '{0}' is unavailable; skipped for staging extraction." -f $actionName)
            continue
        }
        Invoke-RccpMaintenanceLeaf -ActionName $actionName -Arguments @("-Task", $taskName, "-RunMode", "closeout-gate", "-ForceWhenTriggered", "-HardFailOnUnresolved") -HardFail
    }
}

function Invoke-RccpTaskEndTailMaintenance {
    Param([hashtable]$BoundArgs)
    $taskName = if ($BoundArgs.ContainsKey("Task")) { [string]$BoundArgs.Task } else { "" }
    Invoke-RccpMaintenanceLeaf -ActionName "auto-commit-govern" -Arguments @("-Task", $taskName, "-Apply")
}

function Invoke-RccpLeafContractGate {
    Param([Parameter(Mandatory = $true)][string]$ActionName)
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
    $contractCheck = Join-Path $repoRoot "scripts/check-rccp-leaf-contract.ps1"
    if (-not (Test-Path -LiteralPath $contractCheck)) {
        throw ("RCCP leaf contract gate missing: {0}" -f $contractCheck)
    }
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $contractCheck -ActionName $ActionName -Strict
    if ($LASTEXITCODE -ne 0) {
        throw ("RCCP leaf contract gate failed for action '{0}'" -f $ActionName)
    }
}

function Test-RccpCloseoutMetadataArg {
    Param([Parameter(Mandatory = $true)][string]$Arg)
    return (
        [string]::Equals([string]$Arg, "-NoSuggestionReason", [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]::Equals([string]$Arg, "-SkillFlowTrace", [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]::Equals([string]$Arg, "-NoSkillFlowReason", [System.StringComparison]::OrdinalIgnoreCase)
    )
}

function Invoke-RccpCloseoutAtomic {
    Param([hashtable]$BoundArgs)
    Invoke-RccpLeafContractGate -ActionName "final-recap-check"
    Invoke-RccpCoreAction -CliAction "control-transaction" -BoundArgs $BoundArgs
    Invoke-RccpCoreAction -CliAction "closeout-snapshot" -BoundArgs $BoundArgs
    Invoke-RccpCoreAction -CliAction "closeout-fast" -BoundArgs $BoundArgs
    Invoke-RccpLeafAction -ActionName "final-recap-check" -BoundArgs $BoundArgs
    Invoke-RccpLeafContractGate -ActionName "final-reply-contract-check"
    Invoke-RccpLeafAction -ActionName "final-reply-contract-check" -BoundArgs $BoundArgs
    Invoke-RccpCoreAction -CliAction "task-close" -BoundArgs $BoundArgs
    Invoke-RccpCoreAction -CliAction "closeout-sidecar" -BoundArgs $BoundArgs
}

function New-LeafArgs {
    Param([hashtable]$BoundArgs)
    $argList = New-Object System.Collections.Generic.List[string]
    if ($BoundArgs.ContainsKey("Task")) { Add-RccpTextArg -ArgList $argList -Name "-Task" -Value ([string]$BoundArgs.Task) }
    if ($BoundArgs.ContainsKey("CurrentState")) { Add-RccpTextArg -ArgList $argList -Name "-CurrentState" -Value ([string]$BoundArgs.CurrentState) }
    if ($BoundArgs.ContainsKey("NextStep")) { Add-RccpTextArg -ArgList $argList -Name "-NextStep" -Value ([string]$BoundArgs.NextStep) }
    if ($BoundArgs.ContainsKey("TargetPaths")) { Add-RccpListArg -ArgList $argList -Name "-TargetPaths" -Values @($BoundArgs.TargetPaths) }
    if ($BoundArgs.ContainsKey("EvidencePaths")) { Add-RccpListArg -ArgList $argList -Name "-EvidencePaths" -Values @($BoundArgs.EvidencePaths) }
    if ($BoundArgs.ContainsKey("SuggestionId")) { Add-RccpTextArg -ArgList $argList -Name "-SuggestionId" -Value ([string]$BoundArgs.SuggestionId) }
    if ($BoundArgs.ContainsKey("IssueId")) { Add-RccpTextArg -ArgList $argList -Name "-IssueId" -Value ([string]$BoundArgs.IssueId) }
    if ($BoundArgs.ContainsKey("ProgressId")) { Add-RccpTextArg -ArgList $argList -Name "-ProgressId" -Value ([string]$BoundArgs.ProgressId) }
    if ($BoundArgs.ContainsKey("RecentSection")) { Add-RccpTextArg -ArgList $argList -Name "-RecentSection" -Value ([string]$BoundArgs.RecentSection) }
    if ($BoundArgs.ContainsKey("Mode")) { Add-RccpTextArg -ArgList $argList -Name "-Mode" -Value ([string]$BoundArgs.Mode) }
    if ($BoundArgs.ContainsKey("GateProfile")) { Add-RccpTextArg -ArgList $argList -Name "-GateProfile" -Value ([string]$BoundArgs.GateProfile) }
    if ($BoundArgs.ContainsKey("BlueprintRoot")) { Add-RccpTextArg -ArgList $argList -Name "-BlueprintRoot" -Value ([string]$BoundArgs.BlueprintRoot) }
    if ($BoundArgs.ContainsKey("BlueprintPath")) { Add-RccpTextArg -ArgList $argList -Name "-BlueprintPath" -Value ([string]$BoundArgs.BlueprintPath) }
    if ($BoundArgs.ContainsKey("CommandText")) { Add-RccpTextArg -ArgList $argList -Name "-CommandText" -Value ([string]$BoundArgs.CommandText) }
    if ($BoundArgs.ContainsKey("CommandPath")) { Add-RccpTextArg -ArgList $argList -Name "-CommandPath" -Value ([string]$BoundArgs.CommandPath) }
    if ($BoundArgs.ContainsKey("AnswerText")) { Add-RccpTextArg -ArgList $argList -Name "-AnswerText" -Value ([string]$BoundArgs.AnswerText) }
    if ($BoundArgs.ContainsKey("AnswerPath")) { Add-RccpTextArg -ArgList $argList -Name "-AnswerPath" -Value ([string]$BoundArgs.AnswerPath) }
    if ($BoundArgs.ContainsKey("RecapPath")) { Add-RccpTextArg -ArgList $argList -Name "-RecapPath" -Value ([string]$BoundArgs.RecapPath) }
    if ($BoundArgs.ContainsKey("ProjectConfigPath")) { Add-RccpListArg -ArgList $argList -Name "-ProjectConfigPath" -Values @($BoundArgs.ProjectConfigPath) }
    if ($BoundArgs.ContainsKey("ContractPath")) { Add-RccpTextArg -ArgList $argList -Name "-ContractPath" -Value ([string]$BoundArgs.ContractPath) }
    if ($BoundArgs.ContainsKey("ProjectRoot")) { Add-RccpTextArg -ArgList $argList -Name "-ProjectRoot" -Value ([string]$BoundArgs.ProjectRoot) }
    if ($BoundArgs.ContainsKey("Profile")) { Add-RccpTextArg -ArgList $argList -Name "-Profile" -Value ([string]$BoundArgs.Profile) }
    if ($BoundArgs.ContainsKey("OutDir")) { Add-RccpTextArg -ArgList $argList -Name "-OutDir" -Value ([string]$BoundArgs.OutDir) }
    if ($BoundArgs.ContainsKey("EvidenceMode")) { Add-RccpTextArg -ArgList $argList -Name "-EvidenceMode" -Value ([string]$BoundArgs.EvidenceMode) }
    if ($BoundArgs.ContainsKey("NoPersist") -and $BoundArgs.NoPersist) { $argList.Add("-NoPersist") | Out-Null }
    if ($BoundArgs.ContainsKey("CurrentSectionOnly") -and $BoundArgs.CurrentSectionOnly) { $argList.Add("-CurrentSectionOnly") | Out-Null }
    if ($BoundArgs.ContainsKey("IsolateHistoricalDebt") -and $BoundArgs.IsolateHistoricalDebt) { $argList.Add("-IsolateHistoricalDebt") | Out-Null }
    if ($BoundArgs.ContainsKey("Title")) { Add-RccpTextArg -ArgList $argList -Name "-Title" -Value ([string]$BoundArgs.Title) }
    if ($BoundArgs.ContainsKey("Why")) { Add-RccpTextArg -ArgList $argList -Name "-Why" -Value ([string]$BoundArgs.Why) }
    if ($BoundArgs.ContainsKey("How")) { Add-RccpTextArg -ArgList $argList -Name "-How" -Value ([string]$BoundArgs.How) }
    if ($BoundArgs.ContainsKey("Prevent")) { Add-RccpTextArg -ArgList $argList -Name "-Prevent" -Value ([string]$BoundArgs.Prevent) }
    if ($BoundArgs.ContainsKey("Verify")) { Add-RccpTextArg -ArgList $argList -Name "-Verify" -Value ([string]$BoundArgs.Verify) }
    if ($BoundArgs.ContainsKey("Objective")) { Add-RccpTextArg -ArgList $argList -Name "-Why" -Value ([string]$BoundArgs.Objective) }
    if ($BoundArgs.ContainsKey("RequireV3B") -and $BoundArgs.RequireV3B) { $argList.Add("-RequireV3B") | Out-Null }
    if ($BoundArgs.ContainsKey("Strict") -and $BoundArgs.Strict) { $argList.Add("-Strict") | Out-Null }
    if ($BoundArgs.ContainsKey("Json") -and $BoundArgs.Json) { $argList.Add("-Json") | Out-Null }
    $remainingArgs = @($BoundArgs.RemainingArgs)
    for ($i = 0; $i -lt $remainingArgs.Count; $i++) {
        $arg = [string]$remainingArgs[$i]
        if ([string]::IsNullOrWhiteSpace($arg)) { continue }
        if (Test-RccpCloseoutMetadataArg -Arg $arg) {
            if (($i + 1) -lt $remainingArgs.Count) { $i++ }
            continue
        }
        $argList.Add($arg) | Out-Null
    }
    return @($argList.ToArray())
}

function Resolve-RccpLeafScript {
    Param(
        [Parameter(Mandatory = $true)][string]$ActionName,
        [hashtable]$BoundArgs
    )
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
    $dispatch = Get-RccpEntryDispatchMap
    $dispatchTarget = ""
    if ($dispatch -is [hashtable] -and $dispatch.ContainsKey($ActionName)) {
        $dispatchTarget = [string]$dispatch[$ActionName]
    }
    elseif ($dispatch -is [System.Collections.IDictionary] -and $dispatch.Contains($ActionName)) {
        $dispatchTarget = [string]$dispatch[$ActionName]
    }
    else {
        $property = $dispatch.PSObject.Properties[$ActionName]
        if ($null -ne $property) {
            $dispatchTarget = [string]$property.Value
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($dispatchTarget)) {
        $path = Join-Path $repoRoot $dispatchTarget
        if (Test-Path -LiteralPath $path) { return $path }
    }
    foreach ($candidate in @(
            "scripts/check-$ActionName.ps1",
            "scripts/run-$ActionName.ps1",
            "scripts/invoke-$ActionName.ps1",
            "scripts/$ActionName.ps1"
        )) {
        $path = Join-Path $repoRoot $candidate
        if (Test-Path -LiteralPath $path) { return $path }
    }
    return ""
}

function Invoke-RccpLeafAction {
    Param(
        [Parameter(Mandatory = $true)][string]$ActionName,
        [hashtable]$BoundArgs
    )
    $leaf = Resolve-RccpLeafScript -ActionName $ActionName -BoundArgs $BoundArgs
    if ([string]::IsNullOrWhiteSpace($leaf)) {
        throw ("RCCP action '{0}' is not available. Add an RCCP event action or a direct leaf script; the retired ops entry has been physically removed." -f $ActionName)
    }
    if ($ActionName -in @("final-recap-check", "final-reply-contract-check")) {
        Invoke-RccpLeafContractGate -ActionName $ActionName
    }
    $leafArgs = @(New-LeafArgs -BoundArgs $BoundArgs)
    switch ($ActionName) {
        "final-recap-check" {
            $filtered = New-Object System.Collections.Generic.List[string]
            for ($i = 0; $i -lt $leafArgs.Count; $i++) {
                $arg = [string]$leafArgs[$i]
                if ($arg -in @("-AnswerText", "-AnswerPath", "-RecapPath")) {
                    if (($i + 1) -lt $leafArgs.Count) { $i++ }
                    continue
                }
                $filtered.Add($arg) | Out-Null
            }
            $leafArgs = @($filtered.ToArray())
        }
        "pre-commit-smoke" { $leafArgs = @("-Mode", "Staged") }
        "receipt-reconcile" { $leafArgs = @("-Mode", $(if ([string]::IsNullOrWhiteSpace([string]$BoundArgs.Mode)) { "Staged" } else { [string]$BoundArgs.Mode })) }
        "skills-sync" {
            $leafArgs = @()
            if (@($BoundArgs.RemainingArgs) -contains "-Rebuild") { $leafArgs += "-Force" }
        }
        "existing-capability-probe" {
            $translated = New-Object System.Collections.Generic.List[string]
            if (-not [string]::IsNullOrWhiteSpace([string]$BoundArgs.Task)) {
                $translated.Add("-Task") | Out-Null
                $translated.Add([string]$BoundArgs.Task) | Out-Null
            }
            $hasRequestTextArg = $false
            foreach ($arg in @($BoundArgs.RemainingArgs)) {
                if ($null -eq $arg -or [string]::IsNullOrWhiteSpace([string]$arg)) { continue }
                if ([string]::Equals([string]$arg, "-Why", [System.StringComparison]::OrdinalIgnoreCase) -or
                    [string]::Equals([string]$arg, "-RequestText", [System.StringComparison]::OrdinalIgnoreCase)) {
                    $hasRequestTextArg = $true
                }
                $translated.Add([string]$arg) | Out-Null
            }
            if ((-not $hasRequestTextArg) -and -not [string]::IsNullOrWhiteSpace([string]$BoundArgs.Why)) {
                $translated.Add("-Why") | Out-Null
                $translated.Add([string]$BoundArgs.Why) | Out-Null
                $hasRequestTextArg = $true
            }
            if ((-not $hasRequestTextArg) -and -not [string]::IsNullOrWhiteSpace([string]$BoundArgs.Objective)) {
                $translated.Add("-Why") | Out-Null
                $translated.Add([string]$BoundArgs.Objective) | Out-Null
            }
            if ($BoundArgs.ContainsKey("EvidenceMode") -and -not [string]::IsNullOrWhiteSpace([string]$BoundArgs.EvidenceMode)) {
                $translated.Add("-EvidenceMode") | Out-Null
                $translated.Add([string]$BoundArgs.EvidenceMode) | Out-Null
            }
            if ($BoundArgs.ContainsKey("NoPersist") -and $BoundArgs.NoPersist) { $translated.Add("-NoPersist") | Out-Null }
            if ($BoundArgs.Strict) { $translated.Add("-Strict") | Out-Null }
            if ($BoundArgs.Json) { $translated.Add("-Json") | Out-Null }
            $leafArgs = @($translated.ToArray())
        }
        { $_ -in @("stack-stop", "stack-reconcile-stop") } {
            $translated = New-Object System.Collections.Generic.List[string]
            for ($i = 0; $i -lt @($BoundArgs.RemainingArgs).Count; $i++) {
                $arg = [string]@($BoundArgs.RemainingArgs)[$i]
                if ([string]::IsNullOrWhiteSpace($arg)) { continue }
                if ([string]::Equals($arg, "-ServerPort", [System.StringComparison]::OrdinalIgnoreCase)) {
                    $translated.Add("-BackendPort") | Out-Null
                    continue
                }
                $translated.Add($arg) | Out-Null
            }
            $leafArgs = @($translated.ToArray())
        }
        "doc-next-id" { $leafArgs = @() }
        "suggestion-triple-sync" {
            $translated = New-Object System.Collections.Generic.List[string]
            foreach ($name in @("SuggestionTitle", "SuggestionContent", "SuggestionSource", "SuggestionPriority", "SuggestionStatus", "SuggestionTrigger", "SuggestionNote", "SuggestionId", "ProgressId", "RecentSection")) {
                if ($BoundArgs.ContainsKey($name) -and -not [string]::IsNullOrWhiteSpace([string]$BoundArgs[$name])) {
                    $translated.Add(("-{0}" -f $name)) | Out-Null
                    $translated.Add([string]$BoundArgs[$name]) | Out-Null
                }
            }
            foreach ($name in @("ImpactScore", "RiskScore", "FrequencyScore", "TimeScore", "CostScore")) {
                if ($BoundArgs.ContainsKey($name) -and [int]$BoundArgs[$name] -gt 0) {
                    $translated.Add(("-{0}" -f $name)) | Out-Null
                    $translated.Add([string]$BoundArgs[$name]) | Out-Null
                }
            }
            foreach ($arg in @($BoundArgs.RemainingArgs)) {
                if ($null -ne $arg -and -not [string]::IsNullOrWhiteSpace([string]$arg)) {
                    $translated.Add([string]$arg) | Out-Null
                }
            }
            $leafArgs = @($translated.ToArray())
        }
        "suggestion-auto-converge" {
            $translated = New-Object System.Collections.Generic.List[string]
            if ($BoundArgs.ContainsKey("Apply") -and $BoundArgs.Apply) { $translated.Add("-Apply") | Out-Null }
            if ($BoundArgs.ContainsKey("Strict") -and $BoundArgs.Strict) { $translated.Add("-Strict") | Out-Null }
            if ($BoundArgs.ContainsKey("Json") -and $BoundArgs.Json) { $translated.Add("-Json") | Out-Null }
            foreach ($id in @($BoundArgs.ExcludeSuggestionId)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$id)) {
                    $translated.Add("-ExcludeSuggestionId") | Out-Null
                    $translated.Add([string]$id) | Out-Null
                }
            }
            foreach ($arg in @($BoundArgs.RemainingArgs)) {
                if ($null -ne $arg -and -not [string]::IsNullOrWhiteSpace([string]$arg)) {
                    $translated.Add([string]$arg) | Out-Null
                }
            }
            $leafArgs = @($translated.ToArray())
        }
        "suggestion-backlog-zero-check" {
            $translated = New-Object System.Collections.Generic.List[string]
            $translated.Add("-RequireZero") | Out-Null
            if ($BoundArgs.ContainsKey("Strict") -and $BoundArgs.Strict) { $translated.Add("-Strict") | Out-Null }
            foreach ($arg in @($BoundArgs.RemainingArgs)) {
                if ($null -ne $arg -and -not [string]::IsNullOrWhiteSpace([string]$arg)) {
                    $translated.Add([string]$arg) | Out-Null
                }
            }
            $leafArgs = @($translated.ToArray())
        }
        "self-heal-preacquire-regression" {
            $translated = New-Object System.Collections.Generic.List[string]
            for ($i = 0; $i -lt @($BoundArgs.RemainingArgs).Count; $i++) {
                $arg = [string]@($BoundArgs.RemainingArgs)[$i]
                if ([string]::IsNullOrWhiteSpace($arg)) { continue }
                switch -Regex ($arg) {
                    '^-RegressionMode$' { $translated.Add("-RunMode") | Out-Null; continue }
                    '^-Iterations$' { $translated.Add("-Rounds") | Out-Null; continue }
                    default { $translated.Add($arg) | Out-Null }
                }
            }
            $leafArgs = @($translated.ToArray())
        }
        { $_ -in @("closeout-atomic-regression", "closeout-atomic-regression-lite") } {
            $filtered = New-Object System.Collections.Generic.List[string]
            foreach ($arg in @($leafArgs)) {
                if ([string]::Equals([string]$arg, "-Json", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                $filtered.Add([string]$arg) | Out-Null
            }
            $leafArgs = @($filtered.ToArray())
        }
    }
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $leaf @leafArgs
    if ($LASTEXITCODE -ne 0) {
        throw ("leaf action failed: {0} (exit={1})" -f $leaf, $LASTEXITCODE)
    }
}

function Invoke-RccpEntry {
    Param(
        [Parameter(Mandatory = $true)][string]$Action,
        [string]$Task = "",
        [string]$CurrentState = "",
        [string]$NextStep = "",
        [string[]]$TargetPaths = @(),
        [string[]]$EvidencePaths = @(),
        [ValidateSet("DISCUSS_ONLY", "QUICK", "MICRO_SAFE", "NORMAL", "RISKY", "RELEASE")]
        [string]$RiskClass = "NORMAL",
        [string]$SuggestionId = "",
        [string]$IssueId = "",
        [string]$ProgressId = "",
        [string]$RecentSection = "",
        [Alias("Result")]
        [ValidateSet("SUCCESS", "FAILURE")]
        [string]$CloseResult = "SUCCESS",
        [string]$Mode = "Staged",
        [string]$GateProfile = "Fast",
        [string]$Objective = "",
        [string]$AcceptanceCriteria = "",
        [string]$MainBlockingPath = "",
        [string]$ParallelizableSlices = "",
        [string]$NoDelegateReasons = "",
        [string]$SubAgentEvidence = "",
        [string]$MainIntegrationResult = "",
        [string]$CloseoutEvidence = "",
        [string]$BlueprintRoot = "docs/治理/方案蓝图",
        [string]$BlueprintPath = "",
        [string]$CommandText = "",
        [string]$CommandPath = "",
        [string]$AnswerText = "",
        [string]$AnswerPath = "",
        [string]$RecapPath = "",
        [string[]]$ProjectConfigPath = @(),
        [string]$ContractPath = "",
        [string]$ProjectRoot = "",
        [string]$Profile = "",
        [string]$OutDir = "",
        [ValidateSet("Latest", "Transient")]
        [string]$EvidenceMode = "Latest",
        [switch]$NoPersist,
        [switch]$CurrentSectionOnly,
        [switch]$IsolateHistoricalDebt,
        [string]$SuggestionTitle = "",
        [string]$SuggestionContent = "",
        [string]$SuggestionSource = "",
        [string]$SuggestionPriority = "",
        [string]$SuggestionStatus = "",
        [string]$SuggestionTrigger = "",
        [string]$SuggestionNote = "",
        [string]$Title = "",
        [string]$Why = "",
        [string]$How = "",
        [string]$Prevent = "",
        [string]$Verify = "",
        [int]$ImpactScore = 0,
        [int]$RiskScore = 0,
        [int]$FrequencyScore = 0,
        [int]$TimeScore = 0,
        [int]$CostScore = 0,
        [string[]]$ExcludeSuggestionId = @(),
        [switch]$Apply,
        [switch]$RequireV3B,
        [switch]$Strict,
        [switch]$Json,
        [object[]]$RemainingArgs = @()
    )

    $boundArgs = @{}
    foreach ($key in @($PSBoundParameters.Keys)) {
        if ([string]::Equals([string]$key, "Action", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $boundArgs[$key] = $PSBoundParameters[$key]
    }
    Merge-RccpListArgsFromRemaining -BoundArgs $boundArgs

    $result = $null
    $normalizedAction = ([string]$Action).Trim()
    if ($normalizedAction.StartsWith("rccp-", [System.StringComparison]::OrdinalIgnoreCase)) {
        $normalizedAction = $normalizedAction.Substring(5)
    }

    switch ($normalizedAction) {
        "help" {
            Write-Host "RCCP canonical entry: scripts/rccp/rccp.ps1" -ForegroundColor Green
            Write-Host "Core actions: task-start/task-bootstrap/checkpoint/self-interrupt/resume-check/gate/closeout-check/task-end/closeout-atomic"
            Write-Host "Leaf actions: direct check/run/invoke scripts are resolved without the retired ops entry"
            Write-Host "Help source version stamps:"
            Write-Host (Get-HelpSourceVersionStamp -Path "scripts/help/admission-runtime-actions.txt")
            Write-Host (Get-HelpSourceVersionStamp -Path "scripts/help/runtime-troubleshooting-order.txt")
        }
        "task-start" {
            Invoke-RccpCoreAction -CliAction "declare" -BoundArgs $boundArgs
            Invoke-RccpCoreAction -CliAction "lease-acquire" -BoundArgs $boundArgs
            Invoke-RccpTaskStartMaintenance -BoundArgs $boundArgs
        }
        "task-bootstrap" { Invoke-RccpTaskBootstrap -BoundArgs $boundArgs }
        "checkpoint" {
            $checkpointBoundArgs = @{}
            foreach ($key in @($boundArgs.Keys)) {
                if ([string]::Equals([string]$key, "RemainingArgs", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                $checkpointBoundArgs[$key] = $boundArgs[$key]
            }
            $checkpointArgs = New-RccpCliArgs @checkpointBoundArgs -CliAction "checkpoint"
            if ([string]::IsNullOrWhiteSpace($checkpointArgs.CurrentState)) { $checkpointArgs.CurrentState = "RCCP checkpoint recorded" }
            if ([string]::IsNullOrWhiteSpace($checkpointArgs.NextStep)) { $checkpointArgs.NextStep = "continue under RCCP event store" }
            Invoke-RccpCli @checkpointArgs
        }
        "self-interrupt" {
            if ([string]::IsNullOrWhiteSpace([string]$boundArgs.Task)) { throw "rccp self-interrupt requires -Task" }
            Invoke-RccpCoreAction -CliAction "self-interrupt" -BoundArgs $boundArgs
        }
        { $_ -in @("resume-check", "gate", "ownership-check") } { Invoke-RccpCoreAction -CliAction "gate" -BoundArgs $boundArgs }
        "ownership-claim" { Invoke-RccpCoreAction -CliAction "lease-acquire" -BoundArgs $boundArgs }
        "closeout-check" {
            Invoke-RccpLeafContractGate -ActionName "final-recap-check"
            Invoke-RccpCoreAction -CliAction "control-transaction" -BoundArgs $boundArgs
            Invoke-RccpCoreAction -CliAction "closeout-snapshot" -BoundArgs $boundArgs
            Invoke-RccpCoreAction -CliAction "closeout-fast" -BoundArgs $boundArgs
            Invoke-RccpLeafAction -ActionName "final-recap-check" -BoundArgs $boundArgs
            Invoke-RccpLeafContractGate -ActionName "final-reply-contract-check"
            Invoke-RccpLeafAction -ActionName "final-reply-contract-check" -BoundArgs $boundArgs
        }
        "task-end" {
            Invoke-RccpTaskEndPreCloseMaintenance -BoundArgs $boundArgs
            Invoke-RccpCoreAction -CliAction "task-close" -BoundArgs $boundArgs
            Invoke-RccpTaskEndTailMaintenance -BoundArgs $boundArgs
        }
        "closeout-atomic" { Invoke-RccpCloseoutAtomic -BoundArgs $boundArgs }
        { $_ -in @("init", "declare", "status", "trace", "projection-check", "evidence-card", "execution-card", "control-transaction", "lease-acquire", "task-close", "cutover-check", "closeout-snapshot", "closeout-fast", "closeout-sidecar", "blueprint-import", "blueprint-projection-check", "blueprint-stage-gate") } {
            Invoke-RccpCoreAction -CliAction ([string]$_) -BoundArgs $boundArgs
        }
        default { Invoke-RccpLeafAction -ActionName $normalizedAction -BoundArgs $boundArgs }
    }

    return $result
}

Export-ModuleMember -Function Invoke-RccpEntry
