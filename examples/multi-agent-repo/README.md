# Multi-Agent RCCP Example

This example shows the smallest public workflow for a repository that wants to
split one parent task across bounded agents while keeping RCCP closeout on the
main path.

## Roles

| Role | Example responsibility |
| --- | --- |
| main-agent | Starts the parent task, issues work orders, integrates evidence, and runs closeout. |
| worker-agent | Edits only the paths named in its work order and returns evidence. |
| verifier-agent | Runs checks and reports evidence without changing product files. |

## Example Work Order

```json
{
  "workOrderId": "WO-docs-001",
  "parentTask": "release-readiness",
  "actorRole": "sub-agent",
  "objective": "Update release documentation for a bounded docs slice.",
  "allowedPaths": [
    "docs/release-checklist.md"
  ],
  "forbiddenActions": [
    "closeout-check",
    "task-end",
    "closeout-atomic",
    "task-close"
  ],
  "acceptanceCriteria": [
    "Documentation names the new gate.",
    "No runtime state is edited."
  ],
  "evidenceRequired": [
    "changedPaths",
    "verificationCommands",
    "residualRisk"
  ],
  "handoffFormat": "summary plus evidence paths",
  "closeoutAllowed": false,
  "expiresAt": "2026-05-12T00:00:00+08:00"
}
```

## Command Shape

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action task-start -Task "release-readiness" -TargetPaths "docs/release-checklist.md"
pwsh -NoProfile -File .\rccp.ps1 -Action ownership-claim -Task "release-readiness" -TargetPaths "docs/release-checklist.md"
pwsh -NoProfile -File .\rccp.ps1 -Action execution-card -Task "release-readiness"
pwsh -NoProfile -File .\rccp.ps1 -Action closeout-atomic -Task "release-readiness" -TargetPaths "docs/release-checklist.md" -AnswerPath "docs/治理/最新态/final-answer-draft-latest.md"
```

Only the main agent runs the final closeout command. Worker and verifier agents
return evidence for `subAgentEvidence`; they do not close the parent task.
