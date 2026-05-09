[CmdletBinding(PositionalBinding = $false)]
Param()

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Rccp.Core.psm1") -Force

function Get-RccpResultStatus {
    Param([object]$Result)
    if ($null -eq $Result) {
        return [ordered]@{ ok = $false; label = "UNKNOWN" }
    }

    $props = $Result.PSObject.Properties
    if ($null -ne $props["ok"]) {
        $okValue = [bool]$Result.ok
        return [ordered]@{ ok = $okValue; label = $(if ($okValue) { "PASS" } else { "FAIL" }) }
    }
    if ($null -ne $props["pass"]) {
        $passValue = [bool]$Result.pass
        return [ordered]@{ ok = $passValue; label = $(if ($passValue) { "PASS" } else { "FAIL" }) }
    }
    foreach ($name in @("verdict", "status")) {
        if ($null -eq $props[$name] -or $null -eq $Result.$name) { continue }
        $label = ([string]$Result.$name).Trim()
        $okValue = $label -in @("PASS", "OK", "SUCCESS", "CLEAN", "PASS_WITH_WARNINGS")
        return [ordered]@{ ok = $okValue; label = $label }
    }

    return [ordered]@{ ok = $true; label = "EMITTED" }
}

function Invoke-RccpCli {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("init", "declare", "checkpoint", "self-interrupt", "status", "trace", "projection-check", "evidence-card", "execution-card", "control-transaction", "lease-acquire", "gate", "task-close", "cutover-check", "closeout-snapshot", "closeout-fast", "closeout-sidecar", "blueprint-import", "blueprint-projection-check", "blueprint-stage-gate")]
        [string]$Action,
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
        [switch]$RequireV3B,
        [switch]$Strict,
        [switch]$Json
    )

    $result = $null
    switch ($Action) {
        "init" {
            $result = Initialize-RccpEventStore
            [void](Invoke-RccpProjectionRebuild)
            [void](Publish-RccpEvidenceCard -Task $Task)
        }
        "declare" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp declare requires -Task" }
            $result = Invoke-RccpTaskDeclare -Task $Task -TargetPaths $TargetPaths -RiskClass $RiskClass
        }
        "checkpoint" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp checkpoint requires -Task" }
            if ([string]::IsNullOrWhiteSpace($CurrentState) -or [string]::IsNullOrWhiteSpace($NextStep)) {
                throw "rccp checkpoint requires -CurrentState and -NextStep"
            }
            $result = Invoke-RccpCheckpoint -Task $Task -CurrentState $CurrentState -NextStep $NextStep -EvidencePaths $EvidencePaths
        }
        "self-interrupt" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp self-interrupt requires -Task" }
            $result = Invoke-RccpSelfInterrupt -Task $Task -CurrentState $CurrentState -NextStep $NextStep -EvidencePaths $EvidencePaths
        }
        "status" {
            [void](Invoke-RccpProjectionRebuild)
            $result = Publish-RccpEvidenceCard -Task $Task
        }
        "trace" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp trace requires -Task" }
            $result = [pscustomobject]@{
                ok = $true
                task = $Task
                events = @(Get-RccpEvents -Task $Task)
            }
        }
        "projection-check" {
            $result = Invoke-RccpProjectionRebuild
        }
        "evidence-card" {
            $result = Publish-RccpEvidenceCard -Task $Task
        }
        "execution-card" {
            $result = Publish-RccpExecutionCard -Task $Task -Objective $Objective -AcceptanceCriteria $AcceptanceCriteria -MainBlockingPath $MainBlockingPath -ParallelizableSlices $ParallelizableSlices -NoDelegateReasons $NoDelegateReasons -SubAgentEvidence $SubAgentEvidence -MainIntegrationResult $MainIntegrationResult -CloseoutEvidence $CloseoutEvidence -TargetPaths $TargetPaths -SuggestionId $SuggestionId -ProgressId $ProgressId -IssueId $IssueId
        }
        "control-transaction" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp control-transaction requires -Task" }
            $result = New-RccpControlTransaction -Task $Task -ActionName "control-transaction" -TargetPaths $TargetPaths -EvidencePaths $EvidencePaths -SuggestionId $SuggestionId -IssueId $IssueId
        }
        "lease-acquire" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp lease-acquire requires -Task" }
            $result = Invoke-RccpLeaseAcquire -Task $Task -ActionName "lease-acquire" -TargetPaths $TargetPaths -RiskClass $RiskClass
        }
        "gate" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp gate requires -Task" }
            $result = Invoke-RccpPolicyGate -Task $Task -ActionName "gate" -TargetPaths $TargetPaths -EvidencePaths $EvidencePaths -Mode $Mode -GateProfile $GateProfile -Strict:$Strict
        }
        "task-close" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp task-close requires -Task" }
            $result = Invoke-RccpTaskClose -Task $Task -Result $CloseResult -TargetPaths $TargetPaths -EvidencePaths $EvidencePaths -SuggestionId $SuggestionId -IssueId $IssueId -ProgressId $ProgressId -RecentSection $RecentSection
        }
        "cutover-check" {
            $checkTask = $(if ([string]::IsNullOrWhiteSpace($Task)) { "rccp-cutover-check" } else { $Task })
            $result = Test-RccpOneWayCutover -Task $checkTask -PersistReport
            if (-not [bool]$result.pass) {
                throw ("rccp cutover-check failed: missingMarkers={0}" -f [string]::Join(",", @($result.missingMarkers)))
            }
        }
        "closeout-snapshot" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp closeout-snapshot requires -Task" }
            $result = New-RccpCloseoutSnapshot -Task $Task -TargetPaths $TargetPaths -EvidencePaths $EvidencePaths -SuggestionId $SuggestionId -IssueId $IssueId -ProgressId $ProgressId -RecentSection $RecentSection
        }
        "closeout-fast" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp closeout-fast requires -Task" }
            $result = Test-RccpCloseoutFast -Task $Task -TargetPaths $TargetPaths -EvidencePaths $EvidencePaths -PersistReport
        }
        "closeout-sidecar" {
            if ([string]::IsNullOrWhiteSpace($Task)) { throw "rccp closeout-sidecar requires -Task" }
            $result = Publish-RccpCloseoutSidecar -Task $Task -TargetPaths $TargetPaths -EvidencePaths $EvidencePaths -SuggestionId $SuggestionId -ProgressId $ProgressId
        }
        "blueprint-import" {
            $result = Import-RccpBlueprintStateLedger -Task $Task -BlueprintRoot $BlueprintRoot -SuggestionId $SuggestionId -ProgressId $ProgressId -PersistReports
        }
        "blueprint-projection-check" {
            $result = Test-RccpBlueprintProjection -PersistReports
        }
        "blueprint-stage-gate" {
            $result = Test-RccpBlueprintStageGate -BlueprintPath $BlueprintPath -RequireV3B:$RequireV3B -PersistReports
        }
    }

    if ($Json) {
        Write-Output ($result | ConvertTo-Json -Depth 20)
    }
    else {
        switch ($Action) {
            "status" { Write-Host ("rccp status: ok={0}, task='{1}', route='{2}', card='docs/治理/最新态/rccp-evidence-card-latest.md'" -f [bool]$result.ok, [string]$result.task, [string]$result.policyRoute) -ForegroundColor Green }
            "trace" { Write-Host ("rccp trace: task='{0}', events={1}" -f $Task, @($result.events).Count) -ForegroundColor Green }
            default {
                $status = Get-RccpResultStatus -Result $result
                Write-Host ("rccp {0}: ok={1}, status={2}" -f $Action, [bool]$status.ok, [string]$status.label) -ForegroundColor Green
            }
        }
        return $result
    }
}

Export-ModuleMember -Function Invoke-RccpCli
