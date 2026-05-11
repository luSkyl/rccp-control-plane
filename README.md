# RCCP Control Plane

RCCP is an evidence-first repository control plane for teams that let humans,
scripts, and AI coding agents work in the same workspace.

It provides a thin command entry, task lifecycle events, file-level ownership,
policy-backed routing, closeout gates, and machine-readable evidence. The
practical goal is to make local automation repeatable: every meaningful action
should say what it did, which files it touched, which gate passed or blocked,
and where the evidence lives.

> Status: early staging extraction. This repository is the public RCCP kit
> surface, not a full downstream project governance bundle. Project-specific
> gates should be supplied by adapters or by a fuller kit before they are
> registered.

## What RCCP Solves

Repositories with AI-assisted development often fail in quiet, frustrating
ways: two sessions edit the same file, a closeout check passes stale evidence,
a recovery command rewrites runtime state without attribution, or a final answer
claims more than the evidence proves.

RCCP turns that into a small loop:

```text
start task -> claim paths -> run scoped action -> write evidence -> close out
```

When the loop cannot continue, RCCP is designed to return a compact evidence
card with a verdict, reason, next command, and evidence path.

## Distribution Boundary

This repository declares the `staging-extraction` profile. That means:

- only leaf actions shipped in this repository are registered in the public
  dispatch map;
- historical or project-specific actions are intentionally not part of this
  public surface;
- adopters can add their own adapter dispatch without changing RCCP core;
- release readiness is checked with the strict registry, reference-surface,
  project, kit, and sanitization gates listed below.

## Capability Map

| Area | Capabilities |
| --- | --- |
| Command entry | Single PowerShell entry through `rccp.ps1`; direct leaf scripts stay behind the entry facade. |
| Task runtime | `task-start`, `task-bootstrap`, `checkpoint`, `resume-check`, `self-interrupt`, `status`, `trace`, `task-end`. |
| Ownership | File-scoped ownership checks through `ownership-claim` and `ownership-check`. |
| Closeout | `closeout-check`, `closeout-atomic`, recap validation, and final-reply contract validation with explicit `-AnswerPath` or `-AnswerText`. |
| Evidence | Compact JSON/Markdown evidence for status, registry, leaf contracts, project checks, kit rollout, closeout, and memory-layer checks. |
| Project adoption | `project-onboard`, `project-governance-check`, `rccp-kit-compat-check`, and `rccp-kit-rollout-check`. |
| Registry hygiene | `action-registry-check`, `rccp-leaf-contract-check`, `thin-entry-check`, and `action-reference-surface-check`. |
| Command safety | `command-template-lint` validates command snippets before they are copied into docs, CI, or handoff notes. |
| Existing capability answers | `existing-capability-probe` and `existing-capability-answer-shape-check` help avoid redesigning a capability that already exists. |
| Memory layer | `memory-layer-contract-check` and `memory-briefing` describe what context an agent should load before acting. |
| Release hygiene | `tools/sanitize-check.ps1 -Strict`, parser checks, empty-repo install smoke, and release checklist gates. |

## Quickstart

### Requirements

- PowerShell 7+
- Git
- A repository where you want RCCP command entry and local evidence

### Try RCCP in this repository

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action help
pwsh -NoProfile -File .\tools\sanitize-check.ps1 -Strict
```

### Install RCCP into another repository

```powershell
pwsh -NoProfile -File .\install.ps1 -TargetRoot C:\path\to\repo
cd C:\path\to\repo
pwsh -NoProfile -File .\rccp.ps1 -Action help
```

The installer copies the thin entry, policies, schemas, adapters, scripts, and
documentation needed for the target repository to keep its own runtime and
evidence roots.

## Common Workflows

### 1) Start and inspect a task

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action status
pwsh -NoProfile -File .\rccp.ps1 -Action task-start -Task "update-readme" -TargetPaths "README.md"
pwsh -NoProfile -File .\rccp.ps1 -Action ownership-check -Task "update-readme"
```

### 2) Validate a project adoption

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action project-onboard -Task "project-onboarding" -ProjectConfigPath .\rccp.project.json
pwsh -NoProfile -File .\rccp.ps1 -Action project-governance-check -Task "project-onboarding" -ProjectConfigPath .\rccp.project.json
pwsh -NoProfile -File .\rccp.ps1 -Action rccp-kit-compat-check -Task "project-onboarding" -ProjectConfigPath .\rccp.project.json
```

### 3) Check the public kit before release

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action command-template-lint -Task "release-readiness" -CommandText "pwsh -NoProfile -File .\rccp.ps1 -Action rccp-leaf-contract-check -Task `"release-readiness`" -RequireAllLeafScripts -Strict" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action action-reference-surface-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action action-registry-check -Task "release-readiness" -RequireAllLeafScripts -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action rccp-kit-rollout-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\tools\sanitize-check.ps1 -Strict
```

### 4) Close out with explicit final-answer evidence

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action closeout-atomic -Task "update-readme" -TargetPaths "README.md" -AnswerPath "docs/治理/最新态/final-answer-draft-latest.md" -Mode Staged -GateProfile Fast
```

`closeout-atomic` intentionally requires the final reply draft through
`-AnswerPath` or `-AnswerText`; it does not infer the answer from latest
evidence files.

## Core Concepts

### Thin Entry

`rccp.ps1` is the command facade. It routes core actions and shipped leaf
actions while keeping direct script execution out of normal operator workflows.

### Admission and Runtime State

Task runtime state is represented through events, status, traces, checkpoints,
and evidence cards. In downstream kits, admission policy can be expanded through
adapters without changing the public RCCP core.

### Ownership

Ownership is file-level. A task should claim only the paths it intends to
change, and checks should stay scoped to that task and path set.

### Policy Routing

RCCP uses `policies/`, schemas, and optional `adapters/` to define the public
action surface and project-specific extension points.

### Evidence

Evidence is machine-readable first. A typical evidence card looks like this:

```json
{
  "verdict": "PASS",
  "category": "registry",
  "reason": "registered leaf actions are shipped",
  "nextCommand": "",
  "evidencePath": "evidence/latest/action-registry-check-latest.json"
}
```

Human summaries should cite evidence files instead of replacing them.

### Closeout

Closeout is a single auditable chain. The preferred path is one deterministic
`closeout-atomic` run that validates recap evidence, validates the final reply
contract, and then closes the task.

## Repository Layout

```text
rccp.ps1                 Thin repository command entry
install.ps1              Installer for adopting repositories
scripts/rccp/            PowerShell modules and RCCP command core
scripts/help/            Canonical long-form command help
scripts/*.ps1            Shipped leaf checks and utility actions
policies/                Policy bundle, dispatch map, and kit manifest
schemas/                 Public machine-readable contracts
adapters/                Optional project profiles
examples/                Minimal adopter repositories
docs/                    Concepts, evidence model, policy authoring, release notes
tools/                   Staging and release hygiene utilities
evidence/latest/         Local staging evidence, ignored by git
```

Compatibility mirrors under `docs/治理/策略/` are kept for current PowerShell
core compatibility and should stay synchronized with `policies/`.

## Examples

- `examples/minimal-repo`: a small repository that only wants RCCP entry,
  ownership, and closeout evidence.
- `examples/java-vue-repo`: a placeholder for repositories that add backend,
  frontend, migration, and release gates through adapters.
- `examples/docs-only-repo`: a placeholder for documentation-heavy repositories
  that need docs governance without application build gates.

## Documentation

- [Concepts](docs/concepts.md)
- [Evidence](docs/evidence.md)
- [Policy Authoring](docs/policy-authoring.md)
- [Release Checklist](docs/release-checklist.md)
- [Minimal Example](examples/minimal-repo/README.md)

## Release Readiness

Before making this repository public or embedding it as an external kit, verify:

1. `pwsh -NoProfile -File .\rccp.ps1 -Action help` works.
2. `tools/sanitize-check.ps1 -Strict` has zero findings.
3. Empty-repo installation through `install.ps1` works.
4. `action-registry-check -RequireAllLeafScripts -Strict` passes.
5. `action-reference-surface-check -Strict` passes.
6. `project-onboard`, `project-governance-check`, and
   `rccp-kit-rollout-check` report semantic PASS for the intended profile.
7. Business project names, local machine paths, secrets, and historical incident
   details are absent from public files.

## License

This project is licensed under the terms in [LICENSE](LICENSE).
