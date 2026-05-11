[CmdletBinding(PositionalBinding = $false)]
Param()

$ErrorActionPreference = "Stop"

function Get-RccpRepoRoot {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    return (Resolve-Path (Join-Path $moduleRoot "..")).Path
}

function Get-RccpPaths {
    $repoRoot = Get-RccpRepoRoot
    $runtimeDir = Join-Path $repoRoot ".claude/rccp"
    $docsLatestDir = Join-Path $repoRoot "docs/治理/最新态"
    return [pscustomobject]@{
        repoRoot = $repoRoot
        runtimeDir = $runtimeDir
        binDir = Join-Path $runtimeDir "bin"
        tmpDir = Join-Path $runtimeDir "tmp"
        projectionDir = Join-Path $runtimeDir "projections"
        eventStorePath = Join-Path $runtimeDir "event-store.sqlite"
        docsLatestDir = $docsLatestDir
        evidenceCardMd = Join-Path $docsLatestDir "rccp-evidence-card-latest.md"
        evidenceCardJson = Join-Path $docsLatestDir "rccp-evidence-card-latest.json"
        executionCardMd = Join-Path $docsLatestDir "rccp-agent-execution-card-latest.md"
        executionCardJson = Join-Path $docsLatestDir "rccp-agent-execution-card-latest.json"
        closeoutFastJson = Join-Path $docsLatestDir "rccp-closeout-fast-latest.json"
        closeoutFastMd = Join-Path $docsLatestDir "rccp-closeout-fast-latest.md"
        closeoutSidecarJson = Join-Path $docsLatestDir "rccp-closeout-sidecar-latest.json"
        closeoutSidecarMd = Join-Path $docsLatestDir "rccp-closeout-sidecar-latest.md"
        blueprintStateJson = Join-Path $docsLatestDir "blueprint-state-ledger-latest.json"
        blueprintStateMd = Join-Path $docsLatestDir "blueprint-state-ledger-latest.md"
        blueprintProjectionCheckJson = Join-Path $docsLatestDir "blueprint-projection-check-latest.json"
        blueprintProjectionCheckMd = Join-Path $docsLatestDir "blueprint-projection-check-latest.md"
        blueprintStageGateJson = Join-Path $docsLatestDir "blueprint-stage-gate-latest.json"
        blueprintStageGateMd = Join-Path $docsLatestDir "blueprint-stage-gate-latest.md"
        cutoverCheckJson = Join-Path $docsLatestDir "rccp-cutover-check-latest.json"
        cutoverCheckMd = Join-Path $docsLatestDir "rccp-cutover-check-latest.md"
        projectionReport = Join-Path $docsLatestDir "rccp-state-projection-check-latest.json"
        chaosReport = Join-Path $docsLatestDir "rccp-chaos-regression-latest.json"
    }
}

function New-RccpDirectory {
    Param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-RccpTextAtomic {
    Param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-RccpDirectory -Path $directory
    }
    $leaf = Split-Path -Leaf $Path
    $tmpPath = Join-Path $directory (".{0}.{1}.tmp" -f $leaf, [guid]::NewGuid().ToString("N"))
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tmpPath, $Content, $utf8NoBom)
    [System.IO.File]::Move($tmpPath, $Path, $true)
}

function Get-RccpNowIso {
    return (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK")
}

function ConvertTo-RccpJson {
    Param([Parameter(Mandatory = $true)]$Value, [int]$Depth = 16)
    return ($Value | ConvertTo-Json -Depth $Depth -Compress)
}

function Get-RccpStringHash {
    Param([AllowNull()][string]$Text = "")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
        $hash = $sha.ComputeHash($bytes)
        return "sha256:" + ([System.BitConverter]::ToString($hash).Replace("-", "").ToLowerInvariant())
    }
    finally {
        $sha.Dispose()
    }
}

function ConvertTo-RccpSqlLiteral {
    Param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return "NULL" }
    return "'" + ([string]$Value).Replace("'", "''") + "'"
}

function ConvertTo-RccpSlug {
    Param([string]$Text)
    $slug = ([string]$Text).ToLowerInvariant() -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "task" }
    if ($slug.Length -gt 64) { $slug = $slug.Substring(0, 64).Trim("-") }
    return $slug
}

function ConvertTo-RccpStableText {
    Param([AllowNull()]$Value)
    if ($null -eq $Value) { return "" }
    if ($Value -is [datetime]) { return ([datetime]$Value).ToString("yyyy-MM-ddTHH:mm:ss.fffK") }
    return [string]$Value
}

function ConvertTo-RccpList {
    Param([AllowNull()][string]$Text = "")
    $items = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    foreach ($raw in ([string]$Text -split "\r?\n|;")) {
        $value = [string]$raw
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $trimmed = $value.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        $items.Add($trimmed) | Out-Null
    }
    return @($items.ToArray())
}

function ConvertTo-RccpPathList {
    Param([string[]]$Paths = @())
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($rawItem in @($Paths)) {
        if ([string]::IsNullOrWhiteSpace($rawItem)) { continue }
        foreach ($raw in ([string]$rawItem -split ",|;")) {
            $value = [string]$raw
            if ([string]::IsNullOrWhiteSpace($value)) { continue }
            $trimmed = $value.Trim().Trim('"').Trim("'").Trim()
            while ($trimmed.EndsWith("/") -and -not $trimmed.Contains("/")) {
                $trimmed = $trimmed.Substring(0, $trimmed.Length - 1)
            }
            if ($trimmed.EndsWith("/") -and $trimmed -match '\.(ps1|psm1|md|json|toml|txt)/$') {
                $trimmed = $trimmed.Substring(0, $trimmed.Length - 1)
            }
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
            $items.Add($trimmed) | Out-Null
        }
    }
    return @($items.ToArray())
}

function New-RccpId {
    Param(
        [Parameter(Mandatory = $true)][string]$Prefix,
        [string]$Seed = ""
    )
    $stamp = Get-Date -Format "yyyyMMddHHmmssfff"
    $hash = (Get-RccpStringHash -Text ($Seed + "|" + [guid]::NewGuid().ToString("N"))).Substring(7, 12).ToUpperInvariant()
    return ("{0}-{1}-{2}" -f $Prefix.ToUpperInvariant(), $stamp, $hash)
}

function Get-RccpSqlitePath {
    $paths = Get-RccpPaths
    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace([string]$env:RCCP_SQLITE3)) {
        $candidates.Add([string]$env:RCCP_SQLITE3) | Out-Null
    }
    $candidates.Add((Join-Path $paths.binDir "sqlite3.exe")) | Out-Null
    $cmd = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace([string]$cmd.Source)) {
        $candidates.Add([string]$cmd.Source) | Out-Null
    }
    foreach ($candidate in @($candidates)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if (Test-Path -LiteralPath $candidate) { return (Resolve-Path $candidate).Path }
    }
    return ""
}

function Get-RccpPythonPath {
    $candidates = @("python", "py")
    foreach ($candidate in @($candidates)) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace([string]$cmd.Source)) {
            return [string]$cmd.Source
        }
    }
    return ""
}

function Get-RccpStoreBackend {
    $sqlite = Get-RccpSqlitePath
    if (-not [string]::IsNullOrWhiteSpace($sqlite)) {
        return [pscustomobject]@{
            kind = "sqlite3-cli"
            path = $sqlite
        }
    }
    $python = Get-RccpPythonPath
    if (-not [string]::IsNullOrWhiteSpace($python)) {
        return [pscustomobject]@{
            kind = "python-sqlite3"
            path = $python
        }
    }
    return [pscustomobject]@{
        kind = "missing"
        path = ""
    }
}

function Assert-RccpSqliteAvailable {
    $backend = Get-RccpStoreBackend
    if ([string]::Equals([string]$backend.kind, "missing", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "RCCP BLOCKED_DEPENDENCY: neither sqlite3 nor Python sqlite3 backend was found. Install sqlite3, set RCCP_SQLITE3, or install Python."
    }
    return $backend
}

function Invoke-RccpSqlite {
    Param(
        [Parameter(Mandatory = $true)][string]$Sql,
        [switch]$Json
    )
    $paths = Get-RccpPaths
    $backend = Assert-RccpSqliteAvailable
    New-RccpDirectory -Path $paths.runtimeDir
    if ([string]::Equals([string]$backend.kind, "sqlite3-cli", [System.StringComparison]::OrdinalIgnoreCase)) {
        $args = @()
        if ($Json) { $args += "-json" }
        $args += @($paths.eventStorePath, $Sql)
        $output = & ([string]$backend.path) @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw ("RCCP sqlite failed exit={0}: {1}" -f $LASTEXITCODE, ([string]::Join("`n", @($output))))
        }
        if ($Json) {
            $text = [string]::Join("`n", @($output))
            if ([string]::IsNullOrWhiteSpace($text)) { return @() }
            return @($text | ConvertFrom-Json)
        }
        return @($output)
    }

    $pathsForPy = Get-RccpPaths
    $scriptPath = Join-Path $pathsForPy.tmpDir ("sqlite-runner-" + [guid]::NewGuid().ToString("N") + ".py")
    $sqlPath = Join-Path $pathsForPy.tmpDir ("sqlite-query-" + [guid]::NewGuid().ToString("N") + ".sql")
    $jsonOutPath = Join-Path $pathsForPy.tmpDir ("sqlite-output-" + [guid]::NewGuid().ToString("N") + ".json")
    New-RccpDirectory -Path $pathsForPy.tmpDir
    $pythonCode = @'
import json
import sqlite3
import sys

db_path = sys.argv[1]
sql_path = sys.argv[2]
emit_json = sys.argv[3] == "1"
json_out_path = sys.argv[4]

with open(sql_path, "r", encoding="utf-8") as handle:
    sql = handle.read()

connection = sqlite3.connect(db_path)
try:
    connection.row_factory = sqlite3.Row
    cursor = connection.cursor()
    rows = []
    if emit_json and sql.lstrip().lower().startswith("select"):
        cursor.execute(sql)
        rows = [dict(row) for row in cursor.fetchall()]
    else:
        cursor.executescript(sql)
        connection.commit()
    if emit_json:
        with open(json_out_path, "w", encoding="utf-8") as output:
            output.write(json.dumps(rows, ensure_ascii=False, separators=(",", ":")))
finally:
    connection.close()
'@
    Set-Content -LiteralPath $scriptPath -Value $pythonCode -Encoding UTF8
    Set-Content -LiteralPath $sqlPath -Value $Sql -Encoding UTF8
    $jsonFlag = $(if ($Json) { "1" } else { "0" })
    $output = & ([string]$backend.path) $scriptPath $paths.eventStorePath $sqlPath $jsonFlag $jsonOutPath 2>&1
    $exitCode = $LASTEXITCODE
    Remove-Item -LiteralPath $scriptPath, $sqlPath -Force -ErrorAction SilentlyContinue
    if ($exitCode -ne 0) {
        Remove-Item -LiteralPath $jsonOutPath -Force -ErrorAction SilentlyContinue
        throw ("RCCP python sqlite failed exit={0}: {1}" -f $exitCode, ([string]::Join("`n", @($output))))
    }
    if ($Json) {
        $text = ""
        if (Test-Path -LiteralPath $jsonOutPath) {
            $text = Get-Content -LiteralPath $jsonOutPath -Encoding UTF8 -Raw
        }
        Remove-Item -LiteralPath $jsonOutPath -Force -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($text)) { return @() }
        return @($text | ConvertFrom-Json)
    }
    Remove-Item -LiteralPath $jsonOutPath -Force -ErrorAction SilentlyContinue
    return @($output)
}

function Initialize-RccpEventStore {
    $paths = Get-RccpPaths
    New-RccpDirectory -Path $paths.runtimeDir
    New-RccpDirectory -Path $paths.tmpDir
    New-RccpDirectory -Path $paths.projectionDir
    New-RccpDirectory -Path $paths.docsLatestDir
    $backend = Assert-RccpSqliteAvailable

    $schema = @"
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
CREATE TABLE IF NOT EXISTS events (
  event_sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id TEXT NOT NULL UNIQUE,
  event_type TEXT NOT NULL,
  task_id TEXT NOT NULL,
  task_slug TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  session_id TEXT NOT NULL,
  action TEXT NOT NULL,
  tx_id TEXT NOT NULL,
  parent_tx_id TEXT,
  pre_state_hash TEXT NOT NULL,
  post_state_hash TEXT NOT NULL,
  target_paths_json TEXT NOT NULL,
  root_cause_bucket TEXT,
  risk_class TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rccp_events_task ON events(task_id, event_sequence);
CREATE INDEX IF NOT EXISTS idx_rccp_events_tx ON events(tx_id);
CREATE TABLE IF NOT EXISTS projection_store (
  projection_key TEXT PRIMARY KEY,
  projection_json TEXT NOT NULL,
  projection_hash TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS retry_budget (
  task_id TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  blocker_fingerprint TEXT NOT NULL,
  attempts INTEGER NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY(task_id, epoch, blocker_fingerprint)
);
"@
    [void](Invoke-RccpSqlite -Sql $schema)
    return [pscustomobject]@{
        ok = $true
        backend = [string]$backend.kind
        backendPath = [string]$backend.path
        eventStorePath = $paths.eventStorePath
    }
}

function Get-RccpStateHash {
    try {
        $rows = Invoke-RccpSqlite -Json -Sql "SELECT COUNT(*) AS count, COALESCE(MAX(event_sequence),0) AS maxSeq, COALESCE(MAX(event_id),'') AS maxEventId FROM events;"
        $row = @($rows)[0]
        return Get-RccpStringHash -Text (ConvertTo-RccpJson -Value $row)
    }
    catch {
        return Get-RccpStringHash -Text "empty"
    }
}

function Resolve-RccpTaskIdentity {
    Param([Parameter(Mandatory = $true)][string]$Task)
    $slug = ConvertTo-RccpSlug -Text $Task
    $hash = (Get-RccpStringHash -Text $Task).Substring(7, 16).ToUpperInvariant()
    return [pscustomobject]@{
        taskId = "TASK-" + $hash
        taskSlug = $slug
    }
}

function Add-RccpEvent {
    Param(
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][string]$Task,
        [string]$Action = "",
        [string]$TxId = "",
        [string]$ParentTxId = "",
        [string[]]$TargetPaths = @(),
        [string]$RootCauseBucket = "",
        [ValidateSet("DISCUSS_ONLY", "QUICK", "MICRO_SAFE", "NORMAL", "RISKY", "RELEASE")]
        [string]$RiskClass = "NORMAL",
        [hashtable]$Payload = @{}
    )
    [void](Initialize-RccpEventStore)
    if ([string]::IsNullOrWhiteSpace($Action)) { $Action = $EventType }
    if ([string]::IsNullOrWhiteSpace($TxId)) { $TxId = New-RccpId -Prefix "TX" -Seed ($Task + "|" + $EventType) }
    $identity = Resolve-RccpTaskIdentity -Task $Task
    $preHash = Get-RccpStateHash
    $eventId = New-RccpId -Prefix "EVT" -Seed ($Task + "|" + $EventType + "|" + $TxId)
    $sessionId = [string]$env:OPS_SESSION_ID
    if ([string]::IsNullOrWhiteSpace($sessionId)) { $sessionId = "local:" + [System.Environment]::MachineName }
    $createdAt = Get-RccpNowIso
    $payloadObject = [ordered]@{
        task = $Task
        data = $Payload
    }
    $payloadJson = ConvertTo-RccpJson -Value $payloadObject
    $targetJson = ConvertTo-RccpJson -Value @($TargetPaths)
    $postHash = Get-RccpStringHash -Text ([string]::Join("|", @($preHash, $eventId, $EventType, $payloadJson)))
    $sql = @"
INSERT INTO events(event_id,event_type,task_id,task_slug,epoch,session_id,action,tx_id,parent_tx_id,pre_state_hash,post_state_hash,target_paths_json,root_cause_bucket,risk_class,payload_json,created_at)
VALUES($(ConvertTo-RccpSqlLiteral $eventId),$(ConvertTo-RccpSqlLiteral $EventType),$(ConvertTo-RccpSqlLiteral $identity.taskId),$(ConvertTo-RccpSqlLiteral $identity.taskSlug),1,$(ConvertTo-RccpSqlLiteral $sessionId),$(ConvertTo-RccpSqlLiteral $Action),$(ConvertTo-RccpSqlLiteral $TxId),$(ConvertTo-RccpSqlLiteral $ParentTxId),$(ConvertTo-RccpSqlLiteral $preHash),$(ConvertTo-RccpSqlLiteral $postHash),$(ConvertTo-RccpSqlLiteral $targetJson),$(ConvertTo-RccpSqlLiteral $RootCauseBucket),$(ConvertTo-RccpSqlLiteral $RiskClass),$(ConvertTo-RccpSqlLiteral $payloadJson),$(ConvertTo-RccpSqlLiteral $createdAt));
"@
    [void](Invoke-RccpSqlite -Sql $sql)
    return [pscustomobject]@{
        eventId = $eventId
        eventType = $EventType
        taskId = $identity.taskId
        taskSlug = $identity.taskSlug
        txId = $TxId
        preStateHash = $preHash
        postStateHash = $postHash
        createdAt = $createdAt
    }
}

function Get-RccpEvents {
    Param([string]$Task = "")
    [void](Initialize-RccpEventStore)
    if ([string]::IsNullOrWhiteSpace($Task)) {
        return @(Invoke-RccpSqlite -Json -Sql "SELECT * FROM events ORDER BY event_sequence ASC;")
    }
    $identity = Resolve-RccpTaskIdentity -Task $Task
    return @(Invoke-RccpSqlite -Json -Sql ("SELECT * FROM events WHERE task_id = {0} ORDER BY event_sequence ASC;" -f (ConvertTo-RccpSqlLiteral $identity.taskId)))
}

function Get-RccpPolicyRoute {
    Param(
        [ValidateSet("DISCUSS_ONLY", "QUICK", "MICRO_SAFE", "NORMAL", "RISKY", "RELEASE")]
        [string]$RiskClass = "NORMAL"
    )
    switch ($RiskClass) {
        "DISCUSS_ONLY" { return "READONLY" }
        "QUICK" { return "FAST" }
        "MICRO_SAFE" { return "MICRO_FAST" }
        "NORMAL" { return "STAGED" }
        "RISKY" { return "RISK" }
        "RELEASE" { return "RELEASE" }
        default { return "STAGED" }
    }
}

function Invoke-RccpTaskDeclare {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [string[]]$TargetPaths = @(),
        [ValidateSet("DISCUSS_ONLY", "QUICK", "MICRO_SAFE", "NORMAL", "RISKY", "RELEASE")]
        [string]$RiskClass = "NORMAL"
    )
    $txId = New-RccpId -Prefix "TX" -Seed ("declare|" + $Task)
    $route = Get-RccpPolicyRoute -RiskClass $RiskClass
    $events = @()
    $events += Add-RccpEvent -EventType "TaskDeclared" -Task $Task -Action "task-declare" -TxId $txId -TargetPaths $TargetPaths -RiskClass $RiskClass -Payload @{ targetPaths = @($TargetPaths) }
    $events += Add-RccpEvent -EventType "IntentClassified" -Task $Task -Action "intent-classify" -TxId $txId -ParentTxId $txId -TargetPaths $TargetPaths -RiskClass $RiskClass -Payload @{ riskClass = $RiskClass; policyRoute = $route }
    $events += Add-RccpEvent -EventType "PolicyRouteSelected" -Task $Task -Action "policy-route" -TxId $txId -ParentTxId $txId -TargetPaths $TargetPaths -RiskClass $RiskClass -Payload @{ policyRoute = $route }
    [void](Invoke-RccpProjectionRebuild)
    [void](Publish-RccpEvidenceCard -Task $Task)
    return [pscustomobject]@{
        ok = $true
        txId = $txId
        policyRoute = $route
        events = @($events)
    }
}

function Invoke-RccpCheckpoint {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [Parameter(Mandatory = $true)][string]$CurrentState,
        [Parameter(Mandatory = $true)][string]$NextStep,
        [string[]]$EvidencePaths = @()
    )
    $checkpointId = New-RccpId -Prefix "CHK" -Seed $Task
    $event = Add-RccpEvent -EventType "CheckpointRecorded" -Task $Task -Action "checkpoint" -TargetPaths $EvidencePaths -RiskClass "NORMAL" -Payload @{
        checkpointId = $checkpointId
        currentState = $CurrentState
        nextStep = $NextStep
        evidencePaths = @($EvidencePaths)
    }
    [void](Invoke-RccpProjectionRebuild)
    [void](Publish-RccpEvidenceCard -Task $Task)
    return [pscustomobject]@{
        ok = $true
        checkpointId = $checkpointId
        event = $event
    }
}

function Invoke-RccpSelfInterrupt {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [string]$CurrentState = "",
        [string]$NextStep = "",
        [string[]]$EvidencePaths = @()
    )
    $txId = New-RccpId -Prefix "INT" -Seed ("self-interrupt|" + $Task)
    $normalizedEvidencePaths = @(ConvertTo-RccpPathList -Paths $EvidencePaths)
    $stateText = if ([string]::IsNullOrWhiteSpace($CurrentState)) { "stuck-detected or manual interrupt recorded" } else { $CurrentState }
    $nextText = if ([string]::IsNullOrWhiteSpace($NextStep)) { "switch to root-cause isolation before downstream closeout" } else { $NextStep }
    $event = Add-RccpEvent -EventType "SelfInterruptRecorded" -Task $Task -Action "self-interrupt" -TxId $txId -TargetPaths $normalizedEvidencePaths -RootCauseBucket "USER_FEEDBACK_TIMEOUT" -RiskClass "RISKY" -Payload ([ordered]@{
            task = $Task
            currentState = $stateText
            nextStep = $nextText
            evidencePaths = @($normalizedEvidencePaths)
            recoveryModel = "root-cause-first"
            downstreamBlockedUntil = "root-cause-isolated-or-explicitly-parked"
        })
    [void](Invoke-RccpProjectionRebuild)
    [void](Publish-RccpEvidenceCard -Task $Task)
    return [pscustomobject]@{
        ok = $true
        txId = $txId
        event = $event
        currentState = $stateText
        nextStep = $nextText
    }
}

function Invoke-RccpLeaseAcquire {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [string]$ActionName = "lease-acquire",
        [string[]]$TargetPaths = @(),
        [ValidateSet("DISCUSS_ONLY", "QUICK", "MICRO_SAFE", "NORMAL", "RISKY", "RELEASE")]
        [string]$RiskClass = "NORMAL"
    )
    $txId = New-RccpId -Prefix "LEASE" -Seed ($Task + "|" + $ActionName)
    $normalizedTargetPaths = @(ConvertTo-RccpPathList -Paths $TargetPaths)
    $event = Add-RccpEvent -EventType "LeaseAcquired" -Task $Task -Action $ActionName -TxId $txId -TargetPaths $normalizedTargetPaths -RiskClass $RiskClass -Payload ([ordered]@{
            task = $Task
            action = $ActionName
            targetPaths = @($normalizedTargetPaths)
            writerModel = "rccp-event-store"
            deprecatedState = "retired task pointer"
            fallback = "disabled"
        })
    [void](Invoke-RccpProjectionRebuild)
    [void](Publish-RccpEvidenceCard -Task $Task)
    return [pscustomobject]@{
        ok = $true
        txId = $txId
        event = $event
        route = "RCCP_ONE_WAY_CUTOVER"
    }
}

function Invoke-RccpPolicyGate {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [string]$ActionName = "gate",
        [string[]]$TargetPaths = @(),
        [string[]]$EvidencePaths = @(),
        [string]$Mode = "Staged",
        [string]$GateProfile = "Fast",
        [switch]$Strict
    )
    $txId = New-RccpId -Prefix "GATE" -Seed ($Task + "|" + $ActionName + "|" + $Mode + "|" + $GateProfile)
    $normalizedTargetPaths = @(ConvertTo-RccpPathList -Paths $TargetPaths)
    $normalizedEvidencePaths = @(ConvertTo-RccpPathList -Paths $EvidencePaths)
    $event = Add-RccpEvent -EventType "PolicyGateEvaluated" -Task $Task -Action $ActionName -TxId $txId -TargetPaths $normalizedTargetPaths -RiskClass "RISKY" -Payload ([ordered]@{
            task = $Task
            action = $ActionName
            targetPaths = @($normalizedTargetPaths)
            evidencePaths = @($normalizedEvidencePaths)
            mode = $Mode
            gateProfile = $GateProfile
            strict = [bool]$Strict
            verdict = "PASS"
            acceptance = "RCCP projection/event-store gate; retired task-pointer arbitration is not available from the default command facade"
        })
    [void](Invoke-RccpProjectionRebuild)
    [void](Publish-RccpEvidenceCard -Task $Task)
    return [pscustomobject]@{
        ok = $true
        txId = $txId
        verdict = "PASS"
        event = $event
    }
}

function Invoke-RccpTaskClose {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [ValidateSet("SUCCESS", "FAILURE")]
        [string]$Result = "SUCCESS",
        [string[]]$TargetPaths = @(),
        [string[]]$EvidencePaths = @(),
        [string]$SuggestionId = "",
        [string]$IssueId = "",
        [string]$ProgressId = "",
        [string]$RecentSection = ""
    )
    $txId = New-RccpId -Prefix "CLOSE" -Seed ($Task + "|" + $Result)
    $normalizedTargetPaths = @(ConvertTo-RccpPathList -Paths $TargetPaths)
    $normalizedEvidencePaths = @(ConvertTo-RccpPathList -Paths $EvidencePaths)
    $event = Add-RccpEvent -EventType "TaskClosed" -Task $Task -Action "task-close" -TxId $txId -TargetPaths $normalizedTargetPaths -RiskClass "NORMAL" -Payload ([ordered]@{
            task = $Task
            result = $Result
            targetPaths = @($normalizedTargetPaths)
            evidencePaths = @($normalizedEvidencePaths)
            suggestionId = $SuggestionId
            issueId = $IssueId
            progressId = $ProgressId
            recentSection = $RecentSection
            closeoutModel = "rccp-snapshot-and-sidecar"
        })
    [void](Invoke-RccpProjectionRebuild)
    [void](Publish-RccpEvidenceCard -Task $Task)
    return [pscustomobject]@{
        ok = $true
        txId = $txId
        result = $Result
        event = $event
    }
}

function Test-RccpOneWayCutover {
    Param(
        [string]$Task = "rccp-cutover-check",
        [switch]$PersistReport
    )
    $paths = Get-RccpPaths
    $opsPath = Join-Path $paths.repoRoot (Join-Path "scripts" ("ops" + ".ps1"))
    $opsRemoved = -not (Test-Path -LiteralPath $opsPath)
    $opsText = ""
    if (Test-Path -LiteralPath $opsPath) {
        $opsText = [string](Get-Content -LiteralPath $opsPath -Encoding UTF8 -Raw)
    }
    $requiredMarkers = @(
        "Test-RccpOneWayCutoverEnabled",
        "Invoke-RccpOpsCutover",
        "RCCP_PHYSICAL_REMOVAL",
        "RCCP_ONE_WAY_CUTOVER"
    )
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($marker in @($requiredMarkers)) {
        if ((-not $opsRemoved) -and $opsText.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            $missing.Add($marker) | Out-Null
        }
    }
    $report = [ordered]@{
        machineTag = "RCCP_ONE_WAY_CUTOVER_V1"
        generatedAt = Get-RccpNowIso
        task = $Task
        ok = ($opsRemoved -or $missing.Count -eq 0)
        pass = ($opsRemoved -or $missing.Count -eq 0)
        route = $(if ($opsRemoved) { "RCCP_PHYSICAL_REMOVAL" } else { "RCCP_ONE_WAY_CUTOVER" })
        physicalRemoval = [bool]$opsRemoved
        missingMarkers = @($missing.ToArray())
        evidenceCard = "docs/治理/最新态/rccp-evidence-card-latest.json"
        invariant = "retired ops entry is absent or strictly one-way; retired task-pointer writer is not reachable from the default command path"
    }
    if ($PersistReport) {
        New-RccpDirectory -Path $paths.docsLatestDir
        $lf = [Environment]::NewLine
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($paths.cutoverCheckJson, ((ConvertTo-RccpJson -Value $report -Depth 12) + $lf), $utf8NoBom)
        $md = @(
            "# RCCP One-Way Cutover Check",
            "",
            ("- generatedAt: {0}" -f $report.generatedAt),
            ("- task: {0}" -f $report.task),
            ("- pass: {0}" -f [bool]$report.pass),
            ("- route: {0}" -f $report.route),
            ("- physicalRemoval: {0}" -f [bool]$report.physicalRemoval),
            ("- missingMarkers: {0}" -f ($(if (@($report.missingMarkers).Count -eq 0) { "none" } else { [string]::Join(", ", @($report.missingMarkers)) }))),
            "",
            "## Invariant",
            ("- {0}" -f $report.invariant)
        )
        [System.IO.File]::WriteAllText($paths.cutoverCheckMd, ([string]::Join($lf, $md) + $lf), $utf8NoBom)
    }
    if (-not [bool]$report.pass) {
        return [pscustomobject]$report
    }
    [void](Add-RccpEvent -EventType "OneWayCutoverVerified" -Task $Task -Action "cutover-check" -RiskClass "RISKY" -Payload $report)
    [void](Invoke-RccpProjectionRebuild)
    [void](Publish-RccpEvidenceCard -Task $Task)
    return [pscustomobject]$report
}

function New-RccpControlTransaction {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [string]$ActionName = "control-transaction",
        [string[]]$TargetPaths = @(),
        [string[]]$EvidencePaths = @(),
        [string]$SuggestionId = "",
        [string]$IssueId = "",
        [string]$Mode = "Staged",
        [string]$GateProfile = "Fast",
        [string]$RootCauseBucket = ""
    )
    $normalizedTargetPaths = @(ConvertTo-RccpPathList -Paths $TargetPaths)
    $normalizedEvidencePaths = @(ConvertTo-RccpPathList -Paths $EvidencePaths)
    $controlTxId = New-RccpId -Prefix "CTX" -Seed ("control|" + $Task + "|" + $ActionName)
    $transactionKeyPayload = [ordered]@{
        task = $Task
        action = $ActionName
        targetPaths = @($normalizedTargetPaths)
        evidencePaths = @($normalizedEvidencePaths)
        suggestionId = $SuggestionId
        issueId = $IssueId
        mode = $Mode
        gateProfile = $GateProfile
    }
    $transactionKey = Get-RccpStringHash -Text (ConvertTo-RccpJson -Value $transactionKeyPayload -Depth 12)
    $payload = [ordered]@{
        controlTxId = $controlTxId
        transactionKey = $transactionKey
        action = $ActionName
        targetPaths = @($normalizedTargetPaths)
        evidencePaths = @($normalizedEvidencePaths)
        suggestionId = $SuggestionId
        issueId = $IssueId
        mode = $Mode
        gateProfile = $GateProfile
        rootCauseBucket = $RootCauseBucket
        invariants = @(
            "single legal write transaction per task epoch",
            "closeout main chain consumes immutable snapshot only",
            "same blocker fingerprint has one automatic retry budget"
        )
    }
    $event = Add-RccpEvent -EventType "ControlTransactionOpened" -Task $Task -Action $ActionName -TxId $controlTxId -TargetPaths $normalizedTargetPaths -RootCauseBucket $RootCauseBucket -RiskClass "RISKY" -Payload $payload
    [void](Invoke-RccpProjectionRebuild)
    [void](Publish-RccpEvidenceCard -Task $Task)
    return [pscustomobject]@{
        ok = $true
        controlTxId = $controlTxId
        transactionKey = $transactionKey
        event = $event
    }
}

function New-RccpCloseoutSnapshot {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [string[]]$TargetPaths = @(),
        [string[]]$EvidencePaths = @(),
        [string]$SuggestionId = "",
        [string]$IssueId = "",
        [string]$ProgressId = "",
        [string]$RecentSection = "",
        [string]$PolicyRoute = "STAGED",
        [string]$ControlTxId = ""
    )
    $normalizedTargetPaths = @(ConvertTo-RccpPathList -Paths $TargetPaths)
    $normalizedEvidencePaths = @(ConvertTo-RccpPathList -Paths $EvidencePaths)
    $snapshotId = New-RccpId -Prefix "SNAP" -Seed $Task
    $fingerprint = Get-RccpStringHash -Text (ConvertTo-RccpJson -Value ([ordered]@{ task = $Task; controlTxId = $ControlTxId; targetPaths = @($normalizedTargetPaths); evidencePaths = @($normalizedEvidencePaths) }))
    $event = Add-RccpEvent -EventType "CloseoutSnapshotCreated" -Task $Task -Action "closeout-snapshot" -TargetPaths $normalizedTargetPaths -RiskClass "NORMAL" -Payload @{
        snapshotId = $snapshotId
        controlTxId = $ControlTxId
        targetPaths = @($normalizedTargetPaths)
        evidencePaths = @($normalizedEvidencePaths)
        suggestionId = $SuggestionId
        issueId = $IssueId
        progressId = $ProgressId
        recentSection = $RecentSection
        policyRoute = $PolicyRoute
        stagedFingerprint = $fingerprint
    }
    [void](Invoke-RccpProjectionRebuild)
    [void](Publish-RccpEvidenceCard -Task $Task)
    return [pscustomobject]@{
        ok = $true
        snapshotId = $snapshotId
        stagedFingerprint = $fingerprint
        event = $event
    }
}

function Get-RccpLatestCloseoutSnapshot {
    Param([Parameter(Mandatory = $true)][string]$Task)
    $projection = Get-RccpCurrentProjection
    $matches = @($projection.closeoutSnapshots | Where-Object {
            [string]::Equals([string]$_.task, $Task, [System.StringComparison]::OrdinalIgnoreCase)
        } | Sort-Object -Property createdAt)
    if ($matches.Count -lt 1) {
        throw ("RCCP_CLOSEOUT_FAST_BLOCKED: no closeout snapshot found for task '{0}'. Run rccp-closeout-snapshot first." -f $Task)
    }
    return $matches[$matches.Count - 1]
}

function Test-RccpCloseoutFast {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [string[]]$TargetPaths = @(),
        [string[]]$EvidencePaths = @(),
        [switch]$PersistReport
    )
    $paths = Get-RccpPaths
    $normalizedTargetPaths = @(ConvertTo-RccpPathList -Paths $TargetPaths)
    $normalizedEvidencePaths = @(ConvertTo-RccpPathList -Paths $EvidencePaths)
    $snapshot = Get-RccpLatestCloseoutSnapshot -Task $Task
    $expectedFingerprint = [string]$snapshot.stagedFingerprint
    $actualFingerprint = Get-RccpStringHash -Text (ConvertTo-RccpJson -Value ([ordered]@{
            task = $Task
            controlTxId = (ConvertTo-RccpStableText $snapshot.controlTxId)
            targetPaths = @($normalizedTargetPaths)
            evidencePaths = @($normalizedEvidencePaths)
        }))
    $blockers = New-Object System.Collections.Generic.List[string]
    if (-not [string]::Equals($expectedFingerprint, $actualFingerprint, [System.StringComparison]::OrdinalIgnoreCase)) {
        $blockers.Add("SNAPSHOT_FINGERPRINT_DRIFT") | Out-Null
    }
    $report = [ordered]@{
        machineTag = "RCCP_CLOSEOUT_FAST_V1"
        generatedAt = Get-RccpNowIso
        task = $Task
        ok = ($blockers.Count -eq 0)
        verdict = $(if ($blockers.Count -eq 0) { "PASS" } else { "BLOCKED" })
        snapshotId = [string]$snapshot.snapshotId
        policyRoute = [string]$snapshot.policyRoute
        expectedFingerprint = $expectedFingerprint
        actualFingerprint = $actualFingerprint
        blockers = @($blockers.ToArray())
        targetPaths = @($normalizedTargetPaths)
        evidencePaths = @($normalizedEvidencePaths)
        mainChainContract = "snapshot-only; no latest refresh; no context compact; no suggestion receipt audit"
    }
    if ($PersistReport) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $lf = "`n"
        New-RccpDirectory -Path $paths.docsLatestDir
        [System.IO.File]::WriteAllText($paths.closeoutFastJson, ((ConvertTo-RccpJson -Value $report -Depth 12) + $lf), $utf8NoBom)
        $lines = @(
            "# RCCP Closeout Fast",
            "",
            ("- ok: {0}" -f [bool]$report.ok),
            ("- verdict: {0}" -f [string]$report.verdict),
            ("- task: {0}" -f [string]$report.task),
            ("- snapshotId: {0}" -f [string]$report.snapshotId),
            ("- mainChainContract: {0}" -f [string]$report.mainChainContract)
        )
        [System.IO.File]::WriteAllText($paths.closeoutFastMd, ([string]::Join($lf, $lines) + $lf), $utf8NoBom)
    }
    return [pscustomobject]$report
}

function Test-RccpControlTransactionV4 {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [string[]]$TargetPaths = @(),
        [string[]]$EvidencePaths = @(),
        [string]$BlockerFingerprint = ""
    )
    $projection = Get-RccpCurrentProjection
    $transactions = @($projection.controlTransactions | Where-Object {
            [string]::Equals([string]$_.task, $Task, [System.StringComparison]::OrdinalIgnoreCase)
        } | Sort-Object -Property createdAt)
    $snapshots = @($projection.closeoutSnapshots | Where-Object {
            [string]::Equals([string]$_.task, $Task, [System.StringComparison]::OrdinalIgnoreCase)
        } | Sort-Object -Property createdAt)
    $blockers = New-Object System.Collections.Generic.List[string]
    if ($transactions.Count -lt 1) { $blockers.Add("CONTROL_TX_MISSING") | Out-Null }
    if ($snapshots.Count -lt 1) { $blockers.Add("CLOSEOUT_SNAPSHOT_MISSING") | Out-Null }
    $latestTx = if ($transactions.Count -gt 0) { $transactions[$transactions.Count - 1] } else { $null }
    $latestSnapshot = if ($snapshots.Count -gt 0) { $snapshots[$snapshots.Count - 1] } else { $null }
    if ($null -ne $latestSnapshot -and $null -ne $latestTx) {
        if (-not [string]::Equals([string]$latestSnapshot.controlTxId, [string]$latestTx.controlTxId, [System.StringComparison]::OrdinalIgnoreCase)) {
            $blockers.Add("SNAPSHOT_TX_MISMATCH") | Out-Null
        }
    }
    $retry = $null
    if (-not [string]::IsNullOrWhiteSpace($BlockerFingerprint)) {
        $retry = Test-RccpRetryBudget -Task $Task -BlockerFingerprint $BlockerFingerprint
        if (-not [bool]$retry.allowed) { $blockers.Add("RETRY_BUDGET_EXHAUSTED") | Out-Null }
    }
    return [pscustomobject]@{
        ok = ($blockers.Count -eq 0)
        task = $Task
        controlTxId = $(if ($null -ne $latestTx) { [string]$latestTx.controlTxId } else { "" })
        snapshotId = $(if ($null -ne $latestSnapshot) { [string]$latestSnapshot.snapshotId } else { "" })
        transactionKey = $(if ($null -ne $latestTx) { [string]$latestTx.transactionKey } else { "" })
        blockers = @($blockers.ToArray())
        retry = $retry
        targetPaths = @(ConvertTo-RccpPathList -Paths $TargetPaths)
        evidencePaths = @(ConvertTo-RccpPathList -Paths $EvidencePaths)
    }
}

function Publish-RccpCloseoutSidecar {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [string[]]$TargetPaths = @(),
        [string[]]$EvidencePaths = @(),
        [string]$SuggestionId = "",
        [string]$ProgressId = ""
    )
    $paths = Get-RccpPaths
    $normalizedTargetPaths = @(ConvertTo-RccpPathList -Paths $TargetPaths)
    $normalizedEvidencePaths = @(ConvertTo-RccpPathList -Paths $EvidencePaths)
    $snapshot = Get-RccpLatestCloseoutSnapshot -Task $Task
    $payload = [ordered]@{
        snapshotId = [string]$snapshot.snapshotId
        targetPaths = @($normalizedTargetPaths)
        evidencePaths = @($normalizedEvidencePaths)
        suggestionId = $SuggestionId
        progressId = $ProgressId
        sidecarMode = "ASYNC_NON_BLOCKING"
    }
    $event = Add-RccpEvent -EventType "CloseoutSidecarEvidencePublished" -Task $Task -Action "closeout-sidecar" -TargetPaths $normalizedEvidencePaths -RiskClass "NORMAL" -Payload $payload
    [void](Invoke-RccpProjectionRebuild)
    $report = [ordered]@{
        machineTag = "RCCP_CLOSEOUT_SIDECAR_V1"
        generatedAt = Get-RccpNowIso
        task = $Task
        ok = $true
        verdict = "PASS"
        snapshotId = [string]$snapshot.snapshotId
        eventId = [string]$event.eventId
        sidecarMode = "ASYNC_NON_BLOCKING"
        targetPaths = @($normalizedTargetPaths)
        evidencePaths = @($normalizedEvidencePaths)
        suggestionId = $SuggestionId
        progressId = $ProgressId
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $lf = "`n"
    New-RccpDirectory -Path $paths.docsLatestDir
    [System.IO.File]::WriteAllText($paths.closeoutSidecarJson, ((ConvertTo-RccpJson -Value $report -Depth 12) + $lf), $utf8NoBom)
    $lines = @(
        "# RCCP Closeout Sidecar",
        "",
        ("- ok: {0}" -f [bool]$report.ok),
        ("- verdict: {0}" -f [string]$report.verdict),
        ("- task: {0}" -f [string]$report.task),
        ("- snapshotId: {0}" -f [string]$report.snapshotId),
        ("- sidecarMode: {0}" -f [string]$report.sidecarMode)
    )
    [System.IO.File]::WriteAllText($paths.closeoutSidecarMd, ([string]::Join($lf, $lines) + $lf), $utf8NoBom)
    return [pscustomobject]$report
}

function Invoke-RccpProjectionRebuild {
    [void](Initialize-RccpEventStore)
    $paths = Get-RccpPaths
    $events = @(Get-RccpEvents)
    $tasks = @{}
    $checkpoints = New-Object System.Collections.Generic.List[object]
    $snapshots = New-Object System.Collections.Generic.List[object]
    $controlTransactions = New-Object System.Collections.Generic.List[object]
    $executionCards = New-Object System.Collections.Generic.List[object]
    $blueprints = @{}
    $lastEvent = $null
    foreach ($event in @($events)) {
        $lastEvent = $event
        $payload = $null
        try { $payload = ([string]$event.payload_json | ConvertFrom-Json) } catch { $payload = $null }
        if (-not $tasks.ContainsKey([string]$event.task_id)) {
            $tasks[[string]$event.task_id] = [ordered]@{
                taskId = (ConvertTo-RccpStableText $event.task_id)
                taskSlug = (ConvertTo-RccpStableText $event.task_slug)
                task = $(if ($null -ne $payload) { ConvertTo-RccpStableText $payload.task } else { ConvertTo-RccpStableText $event.task_slug })
                epoch = [int]$event.epoch
                riskClass = (ConvertTo-RccpStableText $event.risk_class)
                policyRoute = ""
                lastEventType = ""
                lastTxId = ""
                updatedAt = ""
            }
        }
        $taskState = $tasks[[string]$event.task_id]
        $taskState.lastEventType = (ConvertTo-RccpStableText $event.event_type)
        $taskState.lastTxId = (ConvertTo-RccpStableText $event.tx_id)
        $taskState.updatedAt = (ConvertTo-RccpStableText $event.created_at)
        if ([string]$event.event_type -eq "PolicyRouteSelected" -and $null -ne $payload) {
            $taskState.policyRoute = (ConvertTo-RccpStableText $payload.data.policyRoute)
        }
        if ([string]$event.event_type -eq "CheckpointRecorded" -and $null -ne $payload) {
            $checkpoints.Add([ordered]@{
                taskId = (ConvertTo-RccpStableText $event.task_id)
                task = (ConvertTo-RccpStableText $payload.task)
                checkpointId = (ConvertTo-RccpStableText $payload.data.checkpointId)
                currentState = (ConvertTo-RccpStableText $payload.data.currentState)
                nextStep = (ConvertTo-RccpStableText $payload.data.nextStep)
                eventId = (ConvertTo-RccpStableText $event.event_id)
                createdAt = (ConvertTo-RccpStableText $event.created_at)
            }) | Out-Null
        }
        if ([string]$event.event_type -eq "CloseoutSnapshotCreated" -and $null -ne $payload) {
            $snapshots.Add([ordered]@{
                taskId = (ConvertTo-RccpStableText $event.task_id)
                task = (ConvertTo-RccpStableText $payload.task)
                snapshotId = (ConvertTo-RccpStableText $payload.data.snapshotId)
                controlTxId = (ConvertTo-RccpStableText $payload.data.controlTxId)
                stagedFingerprint = (ConvertTo-RccpStableText $payload.data.stagedFingerprint)
                policyRoute = (ConvertTo-RccpStableText $payload.data.policyRoute)
                eventId = (ConvertTo-RccpStableText $event.event_id)
                createdAt = (ConvertTo-RccpStableText $event.created_at)
            }) | Out-Null
        }
        if ([string]$event.event_type -eq "ControlTransactionOpened" -and $null -ne $payload) {
            $controlTransactions.Add([ordered]@{
                taskId = (ConvertTo-RccpStableText $event.task_id)
                task = (ConvertTo-RccpStableText $payload.task)
                controlTxId = (ConvertTo-RccpStableText $payload.data.controlTxId)
                transactionKey = (ConvertTo-RccpStableText $payload.data.transactionKey)
                action = (ConvertTo-RccpStableText $payload.data.action)
                mode = (ConvertTo-RccpStableText $payload.data.mode)
                gateProfile = (ConvertTo-RccpStableText $payload.data.gateProfile)
                rootCauseBucket = (ConvertTo-RccpStableText $payload.data.rootCauseBucket)
                eventId = (ConvertTo-RccpStableText $event.event_id)
                createdAt = (ConvertTo-RccpStableText $event.created_at)
            }) | Out-Null
        }
        if ([string]$event.event_type -eq "ExecutionCardUpdated" -and $null -ne $payload) {
            $executionCards.Add([ordered]@{
                taskId = (ConvertTo-RccpStableText $event.task_id)
                task = (ConvertTo-RccpStableText $payload.task)
                objective = (ConvertTo-RccpStableText $payload.data.objective)
                acceptanceCriteria = @($payload.data.acceptanceCriteria)
                mainBlockingPath = @($payload.data.mainBlockingPath)
                parallelizableSlices = @($payload.data.parallelizableSlices)
                noDelegateReasons = @($payload.data.noDelegateReasons)
                subAgentEvidence = @($payload.data.subAgentEvidence)
                mainIntegrationResult = (ConvertTo-RccpStableText $payload.data.mainIntegrationResult)
                closeoutEvidence = @($payload.data.closeoutEvidence)
                suggestionId = (ConvertTo-RccpStableText $payload.data.suggestionId)
                progressId = (ConvertTo-RccpStableText $payload.data.progressId)
                issueId = (ConvertTo-RccpStableText $payload.data.issueId)
                targetPaths = @($payload.data.targetPaths)
                eventId = (ConvertTo-RccpStableText $event.event_id)
                txId = (ConvertTo-RccpStableText $event.tx_id)
                createdAt = (ConvertTo-RccpStableText $event.created_at)
            }) | Out-Null
        }
        if ([string]$event.event_type -like "Blueprint*" -and $null -ne $payload) {
            $data = $payload.data
            $blueprintId = ConvertTo-RccpStableText $data.blueprintId
            if ([string]::IsNullOrWhiteSpace($blueprintId)) {
                $blueprintId = ConvertTo-RccpStableText $payload.task
            }
            if (-not $blueprints.ContainsKey($blueprintId)) {
                $blueprints[$blueprintId] = [ordered]@{
                    blueprintId = $blueprintId
                    path = ""
                    title = ""
                    stage = "UNKNOWN"
                    v25EvidenceStatus = "UNKNOWN"
                    v3bClaimAllowed = $false
                    roundStatus = "UNKNOWN"
                    statusLine = ""
                    suggestionIds = @()
                    progressIds = @()
                    evidencePaths = @()
                    unresolvedReasons = @()
                    textHash = ""
                    lastEventType = ""
                    lastEventId = ""
                    lastTxId = ""
                    updatedAt = ""
                }
            }
            $bp = $blueprints[$blueprintId]
            foreach ($name in @("path", "title", "stage", "v25EvidenceStatus", "roundStatus", "statusLine", "textHash")) {
                if ($null -ne $data.$name -and -not [string]::IsNullOrWhiteSpace((ConvertTo-RccpStableText $data.$name))) {
                    $bp[$name] = ConvertTo-RccpStableText $data.$name
                }
            }
            if ($null -ne $data.v3bClaimAllowed) { $bp.v3bClaimAllowed = [bool]$data.v3bClaimAllowed }
            if ($null -ne $data.suggestionIds) { $bp.suggestionIds = @($data.suggestionIds) }
            if ($null -ne $data.progressIds) { $bp.progressIds = @($data.progressIds) }
            if ($null -ne $data.evidencePaths) { $bp.evidencePaths = @($data.evidencePaths) }
            if ($null -ne $data.unresolvedReasons) { $bp.unresolvedReasons = @($data.unresolvedReasons) }
            $bp.lastEventType = ConvertTo-RccpStableText $event.event_type
            $bp.lastEventId = ConvertTo-RccpStableText $event.event_id
            $bp.lastTxId = ConvertTo-RccpStableText $event.tx_id
            $bp.updatedAt = ConvertTo-RccpStableText $event.created_at
        }
    }
    $projection = [ordered]@{
        rebuiltAt = Get-RccpNowIso
        eventCount = @($events).Count
        latestEventId = $(if ($null -ne $lastEvent) { [string]$lastEvent.event_id } else { "" })
        latestTxId = $(if ($null -ne $lastEvent) { [string]$lastEvent.tx_id } else { "" })
        tasks = @($tasks.Values)
        checkpoints = @($checkpoints.ToArray())
        closeoutSnapshots = @($snapshots.ToArray())
        controlTransactions = @($controlTransactions.ToArray())
        executionCards = @($executionCards.ToArray())
        blueprints = @($blueprints.Values | Sort-Object -Property path)
    }
    $projectionJson = ConvertTo-RccpJson -Value $projection -Depth 20
    $projectionHash = Get-RccpStringHash -Text $projectionJson
    $projectionPath = Join-Path $paths.projectionDir "current.json"
    Write-RccpTextAtomic -Path $projectionPath -Content ($projectionJson + [Environment]::NewLine)
    $sql = @"
INSERT INTO projection_store(projection_key,projection_json,projection_hash,updated_at)
VALUES('current',$(ConvertTo-RccpSqlLiteral $projectionJson),$(ConvertTo-RccpSqlLiteral $projectionHash),$(ConvertTo-RccpSqlLiteral (Get-RccpNowIso)))
ON CONFLICT(projection_key) DO UPDATE SET projection_json=excluded.projection_json, projection_hash=excluded.projection_hash, updated_at=excluded.updated_at;
"@
    [void](Invoke-RccpSqlite -Sql $sql)
    $report = [ordered]@{
        checkedAt = Get-RccpNowIso
        ok = $true
        projectionHash = $projectionHash
        eventCount = @($events).Count
        projectionPath = $projectionPath
        eventStorePath = $paths.eventStorePath
        latestEventId = $projection.latestEventId
        latestTxId = $projection.latestTxId
    }
    Write-RccpTextAtomic -Path $paths.projectionReport -Content ((ConvertTo-RccpJson -Value $report -Depth 12) + [Environment]::NewLine)
    return [pscustomobject]$report
}

function Get-RccpCurrentProjection {
    $paths = Get-RccpPaths
    $projectionPath = Join-Path $paths.projectionDir "current.json"
    if (-not (Test-Path -LiteralPath $projectionPath)) {
        [void](Invoke-RccpProjectionRebuild)
    }
    return (Get-Content -LiteralPath $projectionPath -Encoding UTF8 -Raw | ConvertFrom-Json)
}

function Select-RccpProjectionTask {
    Param(
        [Parameter(Mandatory = $true)]$Projection,
        [string]$Task = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($Task)) {
        foreach ($item in @($Projection.tasks)) {
            if ([string]::Equals([string]$item.task, $Task, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $item
            }
        }
    }

    $tasks = @($Projection.tasks)
    if ($tasks.Count -eq 0) {
        return $null
    }

    return ($tasks |
        Sort-Object -Property @{ Expression = { [string]$_.updatedAt } }, @{ Expression = { [string]$_.task } } |
        Select-Object -Last 1)
}

function Publish-RccpEvidenceCard {
    Param([string]$Task = "")
    [void](Initialize-RccpEventStore)
    $paths = Get-RccpPaths
    $projection = Get-RccpCurrentProjection
    $backend = Get-RccpStoreBackend
    $selectedTask = Select-RccpProjectionTask -Projection $projection -Task $Task
    $blockers = @()
    if ([string]::Equals([string]$backend.kind, "missing", [System.StringComparison]::OrdinalIgnoreCase)) {
        $blockers += "BLOCKED_DEPENDENCY: sqlite3/python sqlite backend missing"
    }
    $card = [ordered]@{
        generatedAt = Get-RccpNowIso
        ok = ($blockers.Count -eq 0)
        task = $(if ($null -ne $selectedTask) { [string]$selectedTask.task } else { "" })
        taskId = $(if ($null -ne $selectedTask) { [string]$selectedTask.taskId } else { "" })
        policyRoute = $(if ($null -ne $selectedTask) { [string]$selectedTask.policyRoute } else { "" })
        latestTxId = [string]$projection.latestTxId
        latestEventId = [string]$projection.latestEventId
        eventCount = [int]$projection.eventCount
        backend = [string]$backend.kind
        blockers = @($blockers)
        nextStep = $(if ($blockers.Count -gt 0) { "Install sqlite3 or set RCCP_SQLITE3, then rerun rccp status." } else { "Use RCCP CLI for declare/checkpoint/status and keep rccp.ps1 as facade during migration." })
        evidencePaths = @(
            ".claude/rccp/event-store.sqlite",
            ".claude/rccp/projections/current.json",
            "docs/治理/最新态/rccp-state-projection-check-latest.json",
            "docs/治理/最新态/rccp-evidence-card-latest.md"
        )
    }
    $lf = "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($paths.evidenceCardJson, ((ConvertTo-RccpJson -Value $card -Depth 12) + $lf), $utf8NoBom)
    $blockerText = "none"
    if ($card.blockers.Count -gt 0) {
        $blockerText = [string]::Join("; ", @($card.blockers))
    }
    $lines = @(
        "# RCCP Evidence Card",
        "",
        ("- generatedAt: {0}" -f [string]$card.generatedAt),
        ("- ok: {0}" -f [bool]$card.ok),
        ("- task: {0}" -f [string]$card.task),
        ("- taskId: {0}" -f [string]$card.taskId),
        ("- policyRoute: {0}" -f [string]$card.policyRoute),
        ("- latestTxId: {0}" -f [string]$card.latestTxId),
        ("- latestEventId: {0}" -f [string]$card.latestEventId),
        ("- eventCount: {0}" -f [int]$card.eventCount),
        ("- backend: {0}" -f [string]$card.backend),
        ("- blockers: {0}" -f $blockerText),
        ("- nextStep: {0}" -f [string]$card.nextStep),
        "",
        "## Evidence",
        ""
    )
    foreach ($path in @($card.evidencePaths)) {
        $lines += ("- {0}" -f [string]$path)
    }
    [System.IO.File]::WriteAllText($paths.evidenceCardMd, ([string]::Join($lf, $lines) + $lf), $utf8NoBom)
    return [pscustomobject]$card
}

function Publish-RccpExecutionCard {
    Param(
        [string]$Task = "",
        [string]$Objective = "",
        [string]$AcceptanceCriteria = "",
        [string]$MainBlockingPath = "",
        [string]$ParallelizableSlices = "",
        [string]$NoDelegateReasons = "",
        [string]$SubAgentEvidence = "",
        [string]$MainIntegrationResult = "",
        [string]$CloseoutEvidence = "",
        [string[]]$TargetPaths = @(),
        [string]$SuggestionId = "",
        [string]$ProgressId = "",
        [string]$IssueId = ""
    )
    [void](Initialize-RccpEventStore)
    $paths = Get-RccpPaths

    $shouldRecord = -not (
        [string]::IsNullOrWhiteSpace($Objective) -and
        [string]::IsNullOrWhiteSpace($AcceptanceCriteria) -and
        [string]::IsNullOrWhiteSpace($MainBlockingPath) -and
        [string]::IsNullOrWhiteSpace($ParallelizableSlices) -and
        [string]::IsNullOrWhiteSpace($NoDelegateReasons) -and
        [string]::IsNullOrWhiteSpace($SubAgentEvidence) -and
        [string]::IsNullOrWhiteSpace($MainIntegrationResult) -and
        [string]::IsNullOrWhiteSpace($CloseoutEvidence) -and
        @($TargetPaths).Count -eq 0 -and
        [string]::IsNullOrWhiteSpace($SuggestionId) -and
        [string]::IsNullOrWhiteSpace($ProgressId) -and
        [string]::IsNullOrWhiteSpace($IssueId)
    )
    if ($shouldRecord -and [string]::IsNullOrWhiteSpace($Task)) {
        throw "rccp execution-card update requires -Task"
    }

    if ($shouldRecord) {
        $payload = [ordered]@{
            objective = [string]$Objective
            acceptanceCriteria = @(ConvertTo-RccpList -Text $AcceptanceCriteria)
            mainBlockingPath = @(ConvertTo-RccpList -Text $MainBlockingPath)
            parallelizableSlices = @(ConvertTo-RccpList -Text $ParallelizableSlices)
            noDelegateReasons = @(ConvertTo-RccpList -Text $NoDelegateReasons)
            subAgentEvidence = @(ConvertTo-RccpList -Text $SubAgentEvidence)
            mainIntegrationResult = [string]$MainIntegrationResult
            closeoutEvidence = @(ConvertTo-RccpList -Text $CloseoutEvidence)
            suggestionId = [string]$SuggestionId
            progressId = [string]$ProgressId
            issueId = [string]$IssueId
            targetPaths = @(ConvertTo-RccpPathList -Paths $TargetPaths)
        }
        $normalizedTargetPaths = @(ConvertTo-RccpPathList -Paths $TargetPaths)
        [void](Add-RccpEvent -EventType "ExecutionCardUpdated" -Task $Task -Action "execution-card" -TargetPaths $normalizedTargetPaths -RiskClass "RISKY" -Payload $payload)
        [void](Invoke-RccpProjectionRebuild)
    }

    $projection = Get-RccpCurrentProjection
    $selectedTask = Select-RccpProjectionTask -Projection $projection -Task $Task

    $selectedExecutionCard = $null
    foreach ($item in @($projection.executionCards)) {
        if ($null -eq $selectedTask) {
            $selectedExecutionCard = $item
            continue
        }
        if ([string]::Equals([string]$item.taskId, [string]$selectedTask.taskId, [System.StringComparison]::OrdinalIgnoreCase)) {
            $selectedExecutionCard = $item
        }
    }

    $card = [ordered]@{
        generatedAt = Get-RccpNowIso
        ok = ($null -ne $selectedExecutionCard)
        task = $(if ($null -ne $selectedTask) { [string]$selectedTask.task } elseif ($null -ne $selectedExecutionCard) { [string]$selectedExecutionCard.task } else { "" })
        taskId = $(if ($null -ne $selectedTask) { [string]$selectedTask.taskId } elseif ($null -ne $selectedExecutionCard) { [string]$selectedExecutionCard.taskId } else { "" })
        policyRoute = $(if ($null -ne $selectedTask) { [string]$selectedTask.policyRoute } else { "" })
        objective = $(if ($null -ne $selectedExecutionCard) { [string]$selectedExecutionCard.objective } else { "" })
        acceptanceCriteria = $(if ($null -ne $selectedExecutionCard) { @($selectedExecutionCard.acceptanceCriteria) } else { @() })
        mainBlockingPath = $(if ($null -ne $selectedExecutionCard) { @($selectedExecutionCard.mainBlockingPath) } else { @() })
        parallelizableSlices = $(if ($null -ne $selectedExecutionCard) { @($selectedExecutionCard.parallelizableSlices) } else { @() })
        noDelegateReasons = $(if ($null -ne $selectedExecutionCard) { @($selectedExecutionCard.noDelegateReasons) } else { @() })
        subAgentEvidence = $(if ($null -ne $selectedExecutionCard) { @($selectedExecutionCard.subAgentEvidence) } else { @() })
        mainIntegrationResult = $(if ($null -ne $selectedExecutionCard) { [string]$selectedExecutionCard.mainIntegrationResult } else { "" })
        closeoutEvidence = $(if ($null -ne $selectedExecutionCard) { @($selectedExecutionCard.closeoutEvidence) } else { @() })
        suggestionId = $(if ($null -ne $selectedExecutionCard) { [string]$selectedExecutionCard.suggestionId } else { "" })
        progressId = $(if ($null -ne $selectedExecutionCard) { [string]$selectedExecutionCard.progressId } else { "" })
        issueId = $(if ($null -ne $selectedExecutionCard) { [string]$selectedExecutionCard.issueId } else { "" })
        targetPaths = $(if ($null -ne $selectedExecutionCard) { @($selectedExecutionCard.targetPaths) } else { @() })
        latestEventId = [string]$projection.latestEventId
        latestTxId = [string]$projection.latestTxId
        eventCount = [int]$projection.eventCount
        evidencePaths = @(
            ".claude/rccp/event-store.sqlite",
            ".claude/rccp/projections/current.json",
            "docs/治理/最新态/rccp-agent-execution-card-latest.json",
            "docs/治理/最新态/rccp-agent-execution-card-latest.md"
        )
    }

    $lf = "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($paths.executionCardJson, ((ConvertTo-RccpJson -Value $card -Depth 16) + $lf), $utf8NoBom)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# RCCP Agent Execution Card") | Out-Null
    $lines.Add("") | Out-Null
    foreach ($pair in @(
            ("generatedAt: {0}" -f [string]$card.generatedAt),
            ("ok: {0}" -f [bool]$card.ok),
            ("task: {0}" -f [string]$card.task),
            ("taskId: {0}" -f [string]$card.taskId),
            ("policyRoute: {0}" -f [string]$card.policyRoute),
            ("objective: {0}" -f [string]$card.objective),
            ("suggestionId: {0}" -f [string]$card.suggestionId),
            ("progressId: {0}" -f [string]$card.progressId),
            ("issueId: {0}" -f [string]$card.issueId),
            ("latestTxId: {0}" -f [string]$card.latestTxId),
            ("latestEventId: {0}" -f [string]$card.latestEventId),
            ("eventCount: {0}" -f [int]$card.eventCount),
            ("mainIntegrationResult: {0}" -f [string]$card.mainIntegrationResult)
        )) {
        $lines.Add("- $pair") | Out-Null
    }
    foreach ($section in @(
            @{ title = "Acceptance Criteria"; items = @($card.acceptanceCriteria) },
            @{ title = "Main Blocking Path"; items = @($card.mainBlockingPath) },
            @{ title = "Parallelizable Slices"; items = @($card.parallelizableSlices) },
            @{ title = "No-Delegate Reasons"; items = @($card.noDelegateReasons) },
            @{ title = "Sub-agent Evidence"; items = @($card.subAgentEvidence) },
            @{ title = "Closeout Evidence"; items = @($card.closeoutEvidence) },
            @{ title = "Target Paths"; items = @($card.targetPaths) },
            @{ title = "Evidence Paths"; items = @($card.evidencePaths) }
        )) {
        $lines.Add("") | Out-Null
        $lines.Add(("## {0}" -f [string]$section.title)) | Out-Null
        if (@($section.items).Count -eq 0) {
            $lines.Add("- none") | Out-Null
            continue
        }
        foreach ($item in @($section.items)) {
            $lines.Add(("- {0}" -f [string]$item)) | Out-Null
        }
    }
    [System.IO.File]::WriteAllText($paths.executionCardMd, ([string]::Join($lf, @($lines.ToArray())) + $lf), $utf8NoBom)
    return [pscustomobject]$card
}

function ConvertTo-RccpBlueprintId {
    Param([Parameter(Mandatory = $true)][string]$Path)
    $normalized = ([string]$Path).Replace("\", "/").ToLowerInvariant()
    $hash = (Get-RccpStringHash -Text $normalized).Substring(7, 12).ToUpperInvariant()
    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $slug = ConvertTo-RccpSlug -Text $name
    return ("BP-{0}-{1}" -f $hash, $slug)
}

function Get-RccpRelativePath {
    Param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $full = (Resolve-Path -LiteralPath $Path).Path
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path
    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($root.Length).TrimStart("\", "/").Replace("\", "/")
    }
    return $full.Replace("\", "/")
}

function Get-RccpBlueprintTitle {
    Param([Parameter(Mandatory = $true)][string]$Text, [Parameter(Mandatory = $true)][string]$Path)
    $m = [regex]::Match($Text, '(?m)^\s*#\s+(.+?)\s*$')
    if ($m.Success) { return ([string]$m.Groups[1].Value).Trim() }
    return [System.IO.Path]::GetFileNameWithoutExtension($Path)
}

function Get-RccpBlueprintStatusLine {
    Param([Parameter(Mandatory = $true)][string]$Text)
    $patterns = @(
        '(?m)^\s*-\s*当前状态[：:]\s*`?([^`\r\n]+)`?',
        '(?m)^\s*-\s*当前闭环状态[：:]\s*`?([^`\r\n]+)`?',
        '(?m)^\s*>\s*状态[：:]\s*`?([^`\r\n]+)`?',
        '(?m)^\s*-\s*版本[：:]\s*`?([^`\r\n]+)`?'
    )
    foreach ($pattern in @($patterns)) {
        $m = [regex]::Match($Text, $pattern)
        if ($m.Success) { return ([string]$m.Groups[1].Value).Trim() }
    }
    return ""
}

function Resolve-RccpBlueprintStage {
    Param([string]$StatusLine = "", [string]$Text = "")
    $source = if ([string]::IsNullOrWhiteSpace($StatusLine)) { [string]$Text } else { [string]$StatusLine }
    foreach ($stage in @("V3.5-B", "V3.5-A+", "V3.5-A", "V3-B", "V3-A", "V2.5", "V2", "V1", "V0")) {
        if ($source.IndexOf($stage, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $stage }
    }
    if ($source.IndexOf("压测确认版", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return "V3-B" }
    return "UNKNOWN"
}

function Get-RccpRegexValues {
    Param([Parameter(Mandatory = $true)][string]$Text, [Parameter(Mandatory = $true)][string]$Pattern)
    $set = New-Object System.Collections.Generic.SortedSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in [regex]::Matches($Text, $Pattern)) {
        if ($m.Groups.Count -lt 2) { continue }
        $value = ([string]$m.Groups[1].Value).Trim()
        if (-not [string]::IsNullOrWhiteSpace($value)) { [void]$set.Add($value) }
    }
    return @($set)
}

function Get-RccpRetiredArtifactSet {
    $paths = Get-RccpPaths
    $set = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($policyRel in @(
            "docs/治理/策略/retired-entrypoints.json",
            "docs/治理/策略/rccp-entry-dispatch.json"
        )) {
        $policyPath = Join-Path $paths.repoRoot $policyRel
        if (-not (Test-Path -LiteralPath $policyPath)) { continue }
        try {
            $obj = Get-Content -LiteralPath $policyPath -Encoding UTF8 -Raw | ConvertFrom-Json -Depth 20
            if ($null -ne $obj.PSObject.Properties["retired"] -and $null -ne $obj.retired) {
                foreach ($item in @($obj.retired)) {
                    $path = ([string]$item.path).Replace("\", "/").Trim()
                    if (-not [string]::IsNullOrWhiteSpace($path)) { [void]$set.Add($path) }
                }
            }
            if ($null -ne $obj.PSObject.Properties["retiredArtifacts"] -and $null -ne $obj.retiredArtifacts) {
                foreach ($item in @($obj.retiredArtifacts)) {
                    $path = ([string]$item).Replace("\", "/").Trim()
                    if (-not [string]::IsNullOrWhiteSpace($path)) { [void]$set.Add($path) }
                }
            }
        }
        catch {
            continue
        }
    }
    return $set
}

function Get-RccpBlueprintEvidencePaths {
    Param([Parameter(Mandatory = $true)][string]$Text)
    $set = New-Object System.Collections.Generic.SortedSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $retiredArtifacts = Get-RccpRetiredArtifactSet
    $patterns = @(
        '((?:docs|\.claude|scripts)[^\s`，。；;、\)\]\}]+?\.(?:json|md|sqlite))',
        '((?:docs|\.claude)[^\s`，。；;、\)\]\}]+?summary\.json)'
    )
    foreach ($pattern in @($patterns)) {
        foreach ($m in [regex]::Matches($Text, $pattern)) {
            $value = ([string]$m.Groups[1].Value).Trim().Trim("`"", "'")
            if ($value -match '^(docs|\.claude|scripts)/|^(docs|\.claude|scripts)\\') {
                $normalizedValue = $value.Replace("\", "/")
                if ($retiredArtifacts.Contains($normalizedValue)) { continue }
                [void]$set.Add($normalizedValue)
            }
        }
    }
    return @($set)
}

function Get-RccpBlueprintStateFromText {
    Param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $statusLine = Get-RccpBlueprintStatusLine -Text $Text
    $stage = Resolve-RccpBlueprintStage -StatusLine $statusLine -Text $Text
    $pendingPattern = '待执行|待回填|不得宣称\s*V3-B|不能宣称|尚未生成\s*V3-B|未执行|未完成|V3-B\s*待|V3-B\s*等待|当前不得宣称\s*V3-B|当前不宣称\s*V3-B'
    $hasPending = [regex]::IsMatch($Text, $pendingPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $hasV25Executed = [regex]::IsMatch($Text, 'V2\.5.*(执行|已完成|通过|证据回收|回填)|压测确认回填.*回收证据[：:]\s*`?(?!待回填|待执行)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $v25Status = "UNKNOWN"
    if ($hasV25Executed) { $v25Status = "EXECUTED" }
    elseif ($Text.IndexOf("V2.5", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $v25Status = "DESIGNED" }
    if ($hasPending -and -not $hasV25Executed) { $v25Status = "PENDING" }
    $claimAllowed = ($stage -like "*V3-B*" -and $hasV25Executed -and -not $hasPending)
    $reasons = New-Object System.Collections.Generic.List[string]
    if (-not $claimAllowed) {
        if ($stage -like "*V3-B*" -and $hasPending) { $reasons.Add("V3B_CLAIM_TEXT_CONTAINS_PENDING_BOUNDARY") | Out-Null }
        elseif ($stage -notlike "*V3-B*") { $reasons.Add("BLUEPRINT_NOT_AT_V3B_STAGE") | Out-Null }
        elseif (-not $hasV25Executed) { $reasons.Add("V25_EXECUTION_EVIDENCE_NOT_DETECTED") | Out-Null }
    }
    return [ordered]@{
        blueprintId = ConvertTo-RccpBlueprintId -Path $RelativePath
        path = $RelativePath
        title = Get-RccpBlueprintTitle -Text $Text -Path $Path
        statusLine = $statusLine
        stage = $stage
        v25EvidenceStatus = $v25Status
        v3bClaimAllowed = [bool]$claimAllowed
        roundStatus = "IMPORTED"
        suggestionIds = @(Get-RccpRegexValues -Text $Text -Pattern '(SUG-\d{8}-\d{3})')
        progressIds = @(Get-RccpRegexValues -Text $Text -Pattern '\b(B\.\d+)\b')
        evidencePaths = @(Get-RccpBlueprintEvidencePaths -Text $Text)
        unresolvedReasons = @($reasons.ToArray())
        textHash = Get-RccpStringHash -Text $Text
    }
}

function Import-RccpBlueprintStateLedger {
    Param(
        [string]$Task = "RCCP Blueprint State Ledger Import",
        [string]$BlueprintRoot = "docs/治理/方案蓝图",
        [string]$SuggestionId = "",
        [string]$ProgressId = "",
        [switch]$PersistReports
    )
    [void](Initialize-RccpEventStore)
    $paths = Get-RccpPaths
    $root = Join-Path $paths.repoRoot $BlueprintRoot
    if (-not (Test-Path -LiteralPath $root)) {
        throw ("RCCP_BLUEPRINT_IMPORT_BLOCKED: blueprint root missing: {0}" -f $BlueprintRoot)
    }
    $files = @(Get-ChildItem -LiteralPath $root -File -Filter "*.md" | Sort-Object -Property FullName)
    $states = New-Object System.Collections.Generic.List[object]
    $changedStates = New-Object System.Collections.Generic.List[object]
    $unchangedStates = New-Object System.Collections.Generic.List[object]
    $existingById = @{}
    try {
        $currentProjection = Get-RccpCurrentProjection
        foreach ($bp in @($currentProjection.blueprints)) {
            $id = [string]$bp.blueprintId
            if (-not [string]::IsNullOrWhiteSpace($id)) {
                $existingById[$id] = $bp
            }
        }
    }
    catch {
        $existingById = @{}
    }
    $txId = New-RccpId -Prefix "BPTX" -Seed $Task
    foreach ($file in @($files)) {
        $text = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
        $relativePath = Get-RccpRelativePath -RepoRoot $paths.repoRoot -Path $file.FullName
        $state = Get-RccpBlueprintStateFromText -Path $file.FullName -RelativePath $relativePath -Text $text
        $state.suggestionId = $SuggestionId
        $state.progressId = $ProgressId
        $states.Add([pscustomobject]$state) | Out-Null
        $existing = $null
        if ($existingById.ContainsKey([string]$state.blueprintId)) {
            $existing = $existingById[[string]$state.blueprintId]
        }
        $sameState = $false
        if ($null -ne $existing) {
            $sameState = (
                [string]::Equals([string]$existing.textHash, [string]$state.textHash, [System.StringComparison]::OrdinalIgnoreCase) -and
                [string]::Equals([string]$existing.stage, [string]$state.stage, [System.StringComparison]::OrdinalIgnoreCase) -and
                [string]::Equals([string]$existing.v25EvidenceStatus, [string]$state.v25EvidenceStatus, [System.StringComparison]::OrdinalIgnoreCase) -and
                ([bool]$existing.v3bClaimAllowed -eq [bool]$state.v3bClaimAllowed)
            )
        }
        if ($sameState) {
            $unchangedStates.Add([pscustomobject]$state) | Out-Null
            continue
        }
        $changedStates.Add([pscustomobject]$state) | Out-Null
        [void](Add-RccpEvent -EventType "BlueprintRegistered" -Task $Task -Action "blueprint-state-import" -TxId $txId -TargetPaths @($relativePath) -RiskClass "RISKY" -Payload $state)
        [void](Add-RccpEvent -EventType "BlueprintStageDeclared" -Task $Task -Action "blueprint-state-import" -TxId $txId -ParentTxId $txId -TargetPaths @($relativePath) -RiskClass "RISKY" -Payload $state)
        if ([string]$state.v25EvidenceStatus -eq "EXECUTED") {
            [void](Add-RccpEvent -EventType "BlueprintV25Executed" -Task $Task -Action "blueprint-state-import" -TxId $txId -ParentTxId $txId -TargetPaths @($relativePath) -RiskClass "RISKY" -Payload $state)
        }
        if ([bool]$state.v3bClaimAllowed) {
            [void](Add-RccpEvent -EventType "BlueprintV3BConfirmed" -Task $Task -Action "blueprint-state-import" -TxId $txId -ParentTxId $txId -TargetPaths @($relativePath) -RiskClass "RISKY" -Payload $state)
        }
        else {
            [void](Add-RccpEvent -EventType "BlueprintClaimRejected" -Task $Task -Action "blueprint-state-import" -TxId $txId -ParentTxId $txId -TargetPaths @($relativePath) -RiskClass "RISKY" -Payload $state)
        }
    }
    [void](Invoke-RccpProjectionRebuild)
    $projection = Get-RccpCurrentProjection
    $imported = @($states.ToArray())
    $confirmed = @($imported | Where-Object { [bool]$_.v3bClaimAllowed })
    $pending = @($imported | Where-Object { -not [bool]$_.v3bClaimAllowed })
    $report = [ordered]@{
        machineTag = "RCCP_BLUEPRINT_STATE_LEDGER_V1"
        generatedAt = Get-RccpNowIso
        ok = $true
        task = $Task
        txId = $txId
        blueprintRoot = $BlueprintRoot
        blueprintCount = $imported.Count
        changedBlueprintCount = $changedStates.Count
        unchangedBlueprintCount = $unchangedStates.Count
        importMode = "incremental-by-blueprint-textHash"
        v3bConfirmedCount = $confirmed.Count
        v3bPendingCount = $pending.Count
        suggestionId = $SuggestionId
        progressId = $ProgressId
        projectionHash = [string](Get-RccpStringHash -Text (ConvertTo-RccpJson -Value @($projection.blueprints) -Depth 20))
        blueprints = @($projection.blueprints)
        evidencePaths = @(
            ".claude/rccp/event-store.sqlite",
            ".claude/rccp/projections/current.json",
            "docs/治理/最新态/blueprint-state-ledger-latest.json",
            "docs/治理/最新态/blueprint-state-ledger-latest.md"
        )
    }
    if ($PersistReports) {
        Write-RccpBlueprintStateReport -Report $report
    }
    return [pscustomobject]$report
}

function Write-RccpBlueprintStateReport {
    Param([Parameter(Mandatory = $true)]$Report)
    $paths = Get-RccpPaths
    $lf = "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($paths.blueprintStateJson, ((ConvertTo-RccpJson -Value $Report -Depth 24) + $lf), $utf8NoBom)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Blueprint State Ledger") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add(("- generatedAt: {0}" -f [string]$Report.generatedAt)) | Out-Null
    $lines.Add(("- ok: {0}" -f [bool]$Report.ok)) | Out-Null
    $lines.Add(("- importMode: {0}" -f [string]$Report.importMode)) | Out-Null
    $lines.Add(("- blueprintCount: {0}" -f [int]$Report.blueprintCount)) | Out-Null
    $lines.Add(("- changedBlueprintCount: {0}" -f [int]$Report.changedBlueprintCount)) | Out-Null
    $lines.Add(("- unchangedBlueprintCount: {0}" -f [int]$Report.unchangedBlueprintCount)) | Out-Null
    $lines.Add(("- v3bConfirmedCount: {0}" -f [int]$Report.v3bConfirmedCount)) | Out-Null
    $lines.Add(("- v3bPendingCount: {0}" -f [int]$Report.v3bPendingCount)) | Out-Null
    $lines.Add(("- txId: {0}" -f [string]$Report.txId)) | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("| blueprintId | stage | v25 | v3bClaimAllowed | path |") | Out-Null
    $lines.Add("|---|---:|---:|---:|---|") | Out-Null
    foreach ($bp in @($Report.blueprints)) {
        $lines.Add(("| {0} | {1} | {2} | {3} | {4} |" -f [string]$bp.blueprintId, [string]$bp.stage, [string]$bp.v25EvidenceStatus, [bool]$bp.v3bClaimAllowed, [string]$bp.path)) | Out-Null
    }
    [System.IO.File]::WriteAllText($paths.blueprintStateMd, ([string]::Join($lf, @($lines.ToArray())) + $lf), $utf8NoBom)
}

function Test-RccpBlueprintProjection {
    Param([switch]$PersistReports)
    [void](Invoke-RccpProjectionRebuild)
    $paths = Get-RccpPaths
    $projection = Get-RccpCurrentProjection
    $blueprints = @($projection.blueprints)
    $ids = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $violations = New-Object System.Collections.Generic.List[string]
    foreach ($bp in @($blueprints)) {
        if ([string]::IsNullOrWhiteSpace([string]$bp.blueprintId)) {
            $violations.Add("BLUEPRINT_ID_MISSING") | Out-Null
            continue
        }
        if (-not $ids.Add([string]$bp.blueprintId)) {
            $violations.Add(("DUPLICATE_BLUEPRINT_ID:{0}" -f [string]$bp.blueprintId)) | Out-Null
        }
        if ([bool]$bp.v3bClaimAllowed -and [string]$bp.v25EvidenceStatus -ne "EXECUTED") {
            $violations.Add(("V3B_WITHOUT_EXECUTED_V25:{0}" -f [string]$bp.path)) | Out-Null
        }
    }
    $report = [ordered]@{
        machineTag = "RCCP_BLUEPRINT_PROJECTION_CHECK_V1"
        generatedAt = Get-RccpNowIso
        pass = ($violations.Count -eq 0)
        blueprintCount = $blueprints.Count
        violations = @($violations.ToArray())
        projectionPath = ".claude/rccp/projections/current.json"
        eventStorePath = ".claude/rccp/event-store.sqlite"
    }
    if ($PersistReports) {
        $lf = "`n"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($paths.blueprintProjectionCheckJson, ((ConvertTo-RccpJson -Value $report -Depth 12) + $lf), $utf8NoBom)
        $lines = @(
            "# Blueprint Projection Check",
            "",
            ("- generatedAt: {0}" -f [string]$report.generatedAt),
            ("- pass: {0}" -f [bool]$report.pass),
            ("- blueprintCount: {0}" -f [int]$report.blueprintCount),
            ("- violations: {0}" -f $(if ($violations.Count -eq 0) { "none" } else { [string]::Join("; ", @($violations.ToArray())) }))
        )
        [System.IO.File]::WriteAllText($paths.blueprintProjectionCheckMd, ([string]::Join($lf, $lines) + $lf), $utf8NoBom)
    }
    return [pscustomobject]$report
}

function Test-RccpBlueprintStageGate {
    Param(
        [string]$BlueprintPath = "",
        [switch]$RequireV3B,
        [switch]$PersistReports
    )
    [void](Invoke-RccpProjectionRebuild)
    $paths = Get-RccpPaths
    $projection = Get-RccpCurrentProjection
    $blueprints = @($projection.blueprints)
    if (-not [string]::IsNullOrWhiteSpace($BlueprintPath)) {
        $wanted = $BlueprintPath.Replace("\", "/")
        $blueprints = @($blueprints | Where-Object { [string]$_.path -eq $wanted -or [string]$_.path -like "*$wanted*" })
    }
    $violations = New-Object System.Collections.Generic.List[string]
    foreach ($bp in @($blueprints)) {
        if ($RequireV3B -and -not [bool]$bp.v3bClaimAllowed) {
            $violations.Add(("V3B_CLAIM_NOT_ALLOWED:{0}:{1}" -f [string]$bp.stage, [string]$bp.path)) | Out-Null
        }
        if ([bool]$bp.v3bClaimAllowed -and [string]$bp.v25EvidenceStatus -ne "EXECUTED") {
            $violations.Add(("V3B_CLAIM_WITHOUT_EXECUTED_V25:{0}" -f [string]$bp.path)) | Out-Null
        }
    }
    $report = [ordered]@{
        machineTag = "RCCP_BLUEPRINT_STAGE_GATE_V1"
        generatedAt = Get-RccpNowIso
        pass = ($violations.Count -eq 0)
        requireV3B = [bool]$RequireV3B
        blueprintPath = $BlueprintPath
        checkedCount = $blueprints.Count
        violations = @($violations.ToArray())
        checked = @($blueprints)
    }
    if ($PersistReports) {
        $lf = "`n"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($paths.blueprintStageGateJson, ((ConvertTo-RccpJson -Value $report -Depth 20) + $lf), $utf8NoBom)
        $lines = @(
            "# Blueprint Stage Gate",
            "",
            ("- generatedAt: {0}" -f [string]$report.generatedAt),
            ("- pass: {0}" -f [bool]$report.pass),
            ("- requireV3B: {0}" -f [bool]$report.requireV3B),
            ("- checkedCount: {0}" -f [int]$report.checkedCount),
            ("- violations: {0}" -f $(if ($violations.Count -eq 0) { "none" } else { [string]::Join("; ", @($violations.ToArray())) }))
        )
        [System.IO.File]::WriteAllText($paths.blueprintStageGateMd, ([string]::Join($lf, $lines) + $lf), $utf8NoBom)
    }
    return [pscustomobject]$report
}

function Test-RccpRetryBudget {
    Param(
        [Parameter(Mandatory = $true)][string]$Task,
        [Parameter(Mandatory = $true)][string]$BlockerFingerprint,
        [switch]$Consume
    )
    [void](Initialize-RccpEventStore)
    $identity = Resolve-RccpTaskIdentity -Task $Task
    $fingerprint = Get-RccpStringHash -Text $BlockerFingerprint
    $selectSql = "SELECT attempts FROM retry_budget WHERE task_id = {0} AND epoch = 1 AND blocker_fingerprint = {1};" -f (ConvertTo-RccpSqlLiteral $identity.taskId), (ConvertTo-RccpSqlLiteral $fingerprint)
    $rows = @(Invoke-RccpSqlite -Json -Sql $selectSql)
    $attempts = 0
    if ($rows.Count -gt 0) { $attempts = [int]@($rows)[0].attempts }
    $allowed = ($attempts -lt 1)
    if ($Consume -and $allowed) {
        $updatedAt = Get-RccpNowIso
        $sql = @"
INSERT INTO retry_budget(task_id,epoch,blocker_fingerprint,attempts,updated_at)
VALUES($(ConvertTo-RccpSqlLiteral $identity.taskId),1,$(ConvertTo-RccpSqlLiteral $fingerprint),1,$(ConvertTo-RccpSqlLiteral $updatedAt))
ON CONFLICT(task_id,epoch,blocker_fingerprint) DO UPDATE SET attempts=attempts+1, updated_at=excluded.updated_at;
"@
        [void](Invoke-RccpSqlite -Sql $sql)
    }
    return [pscustomobject]@{
        taskId = $identity.taskId
        blockerFingerprint = $fingerprint
        attempts = $attempts
        allowed = $allowed
    }
}

function Test-RccpWorkOrderContract {
    Param(
        [string]$ActorRole = "sub-agent",
        [string[]]$AllowedPaths = @(),
        [string[]]$RequestedPaths = @(),
        [switch]$CloseoutRequested
    )
    $violations = New-Object System.Collections.Generic.List[string]
    if ([string]::Equals($ActorRole, "sub-agent", [System.StringComparison]::OrdinalIgnoreCase) -and $CloseoutRequested) {
        $violations.Add("SUB_AGENT_CLOSEOUT_FORBIDDEN") | Out-Null
    }
    $allowed = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in @($AllowedPaths)) {
        if (-not [string]::IsNullOrWhiteSpace($path)) { [void]$allowed.Add([string]$path) }
    }
    foreach ($path in @($RequestedPaths)) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        if (-not $allowed.Contains([string]$path)) {
            $violations.Add("UNAUTHORIZED_PATH:" + [string]$path) | Out-Null
        }
    }
    return [pscustomobject]@{
        ok = ($violations.Count -eq 0)
        violations = @($violations.ToArray())
    }
}

Export-ModuleMember -Function @(
    "Get-RccpPaths",
    "Get-RccpSqlitePath",
    "Get-RccpStoreBackend",
    "Initialize-RccpEventStore",
    "Invoke-RccpTaskDeclare",
    "Invoke-RccpCheckpoint",
    "Invoke-RccpSelfInterrupt",
    "Invoke-RccpLeaseAcquire",
    "Invoke-RccpPolicyGate",
    "Invoke-RccpTaskClose",
    "Test-RccpOneWayCutover",
    "New-RccpControlTransaction",
    "New-RccpCloseoutSnapshot",
    "Test-RccpCloseoutFast",
    "Test-RccpControlTransactionV4",
    "Publish-RccpCloseoutSidecar",
    "Invoke-RccpProjectionRebuild",
    "Get-RccpCurrentProjection",
    "Publish-RccpEvidenceCard",
    "Publish-RccpExecutionCard",
    "Get-RccpEvents",
    "Get-RccpPolicyRoute",
    "Test-RccpRetryBudget",
    "Test-RccpWorkOrderContract",
    "Import-RccpBlueprintStateLedger",
    "Test-RccpBlueprintProjection",
    "Test-RccpBlueprintStageGate"
)
