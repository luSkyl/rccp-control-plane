[CmdletBinding(PositionalBinding = $false)]
Param(
    [Parameter(Mandatory = $true)]
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
    [string]$CommandText = "",
    [string]$CommandPath = "",
    [string]$AnswerText = "",
    [string]$AnswerPath = "",
    [string]$RecapPath = "",
    [string[]]$ProjectConfigPath = @(),
    [string]$ContractPath = "",
    [string]$ProjectRoot = "",
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
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$RemainingArgs = @()
)
$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSScriptRoot "Rccp.Entry.psm1") -Force
$forwardArgs = @{}
foreach ($key in @($PSBoundParameters.Keys)) {
    if ([string]::Equals([string]$key, "RemainingArgs", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
    $forwardArgs[$key] = $PSBoundParameters[$key]
}
Invoke-RccpEntry @forwardArgs -RemainingArgs $RemainingArgs
