---
title: RCCP Multi-Agent Workflow
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/multi-agent-workflow.md
confidence: high
---

# RCCP Multi-Agent Workflow

RCCP supports evidence-governed multi-agent collaboration by turning parallel
work into bounded work orders, file-level ownership claims, and auditable
handoffs. It does not ship a model scheduler, remote worker service, or agent
orchestrator. The public contract is the coordination surface around humans,
scripts, and coding agents that already run in the repository.

For source-backed context assembly around delegated work, see
`docs/adapters/context-and-coordination.md`.

## Roles

| Role | Responsibility | Closeout authority |
| --- | --- | --- |
| Main agent | Declare the task, split work orders, integrate results, and run closeout | yes |
| Worker agent | Execute one authorized work order within its allowed paths | no |
| Verifier agent | Check evidence, tests, contracts, and handoff claims | no |

Sub-agents must not close the parent task. They report evidence back to the
main agent, and the main agent decides whether to integrate, retry, park, or
abstain.

## Required Loop

```text
main task -> work order -> ownership-claim -> scoped edit/check -> sub-agent evidence -> main integration -> closeout-atomic
```

The main agent starts the parent task with `task-start` or `task-bootstrap`,
then records a checkpoint before delegating. Each sub-agent receives a work
order with an objective, allowed paths, acceptance criteria, and required
evidence. Before editing, the sub-agent must run `ownership-claim` for only
those paths.

## Work Order Contract

A work order should include:

- `workOrderId`
- `parentTask`
- `actorRole`
- `objective`
- `allowedPaths`
- `forbiddenActions`
- `acceptanceCriteria`
- `evidenceRequired`
- `handoffFormat`
- `closeoutAllowed`
- `expiresAt`

`closeoutAllowed` must be `false` for `sub-agent` and `verifier-agent`. The
matching schema lives at `schemas/rccp-work-order.schema.json`.

## Execution Card

The `execution-card` action publishes the current collaboration summary at
`docs/治理/最新态/rccp-agent-execution-card-latest.json` and Markdown beside it.
For multi-agent work, the important fields are:

- `mainBlockingPath`: work that must stay on the main path.
- `parallelizableSlices`: work that can be delegated.
- `noDelegateReasons`: reasons a slice stayed local.
- `subAgentEvidence`: worker or verifier evidence returned to the main agent.
- `mainIntegrationResult`: what the main agent accepted or rejected.
- `closeoutEvidence`: final evidence used by closeout.

Final answers should cite the closeout evidence, not a sub-agent claim by
itself.

## Conflict Rules

File ownership is the first conflict boundary. If two agents need the same
path, the main agent must serialize the work or split the path surface more
precisely. A sub-agent request outside `allowedPaths` is unauthorized even when
the task name matches.

The existing runtime invariant is `sub_agent_must_not_closeout`; the matching
PowerShell guard is `Test-RccpWorkOrderContract` in
`scripts/rccp/Rccp.Core.psm1`.


## Context and Runtime Bridges

Before splitting complex work, the main agent should run `code-context-snapshot`
to create a source-backed context pack. Work orders may reference the pack with
`contextPackPath`, summarize the `impactSummary`, and copy focused
`recommendedVerifierChecks` into acceptance criteria. The Code Context Adapter is
optional and must fall back to existing RCCP evidence gates when graph evidence
is unavailable.

The optional Runtime Bridge reserves a Multica-style external status or worker
surface. External runtimes may mirror work orders and return handoff evidence,
but they are never closeout authorities and cannot bypass ownership or verifier
checks.

## Public Verification

Run the contract check before release:

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action multi-agent-contract-check -Task "release-readiness" -Strict
```

Release readiness should then run the normal registry, leaf-contract,
reference-surface, thin-entry, kit-rollout, and sanitization gates.
