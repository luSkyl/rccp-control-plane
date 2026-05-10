# RCCP Control Plane

RCCP is an evidence-first control plane for repositories where humans, scripts,
and AI coding agents work in the same workspace.

It gives a project one command entry, task admission checks, file-level
ownership, policy routing, closeout evidence, and machine-readable audit
artifacts. The goal is simple: make automation safe to run repeatedly without
losing track of who changed what, which gate ran, and what evidence proves the
repository is ready for the next step.

> Status: early staging extraction. The public surface is being hardened. Run
> the sanitization check before publishing or embedding this repository in
> another project.

This repository currently declares the `staging-extraction` distribution
profile. Required leaf actions are enforced by `action-registry-check`; broader
registered actions are advisory here and become mandatory only for a full-kit
release check.

## Why RCCP?

Modern software repositories are no longer edited by one person in one terminal.
They often have:

- multiple AI agent sessions touching the same files;
- local scripts that mutate runtime state, evidence, and docs;
- human reviewers who need a short answer backed by exact artifacts;
- release or governance rules that must be repeatable instead of remembered.

RCCP turns those moving parts into a small control-plane loop:

```text
admit task -> claim files -> run scoped action -> write evidence -> close out
```

If something is blocked, RCCP reports a compact evidence card with the reason,
the next command, and the evidence path instead of leaving the operator to infer
state from scattered logs.

## Capability Map

### 1) Runtime and task control

- One command entry through `rccp.ps1`.
- Task lifecycle control with `task-start`, `task-bootstrap`, `checkpoint`,
  `resume-check`, `self-interrupt`, `closeout-check`, `task-end`, and
  `closeout-atomic`.
- File-level ownership with `ownership-claim` and `ownership-check`.
- Runtime recovery and attribution with `admission-reconcile`,
  `single-writer-reconcile`, `task-reentry-probe`, and
  `runtime-writer-trace-report`.

### 2) Project adoption and compatibility

- Project onboarding with `project-onboard`.
- Policy and action dispatch validation with `project-governance-check`.
- Kit compatibility and rollback-profile checks with `rccp-kit-compat-check`.
- Rollout acceptance with `rccp-kit-rollout-check`.
- Command-template linting with `command-template-lint`.

### 3) Governance, routing, and documentation ops

- Policy-backed routing through `policies/` and `adapters/`.
- Scoped route planning with `ops-route-plan`.
- Token-minimal governance reporting with `governance-token-report`.
- Suggestion and workspace upkeep with `suggestion-triple-sync` and
  `workspace-govern`.
- Registry and load-order checks with `action-registry-check`,
  `thin-entry-check`, `memory-layer-contract-check`, and `memory-briefing`.
- Checkpoint and planning consistency helpers such as
  `checkpoint-integrity-check`, `checkpoint-reconcile`, and
  `planning-context-probe`.

### 4) Evidence and audit surface

- Compact evidence cards for status, admission, and closeout paths.
- Machine-readable latest evidence under `evidence/latest/` and
  project-local `docs/治理/最新态/` style paths.
- Read-only runtime inspection with `status`, `trace`, `evidence-card`, and
  `execution-card`.
- Journal and projection reports such as
  `runtime-admission-journal-check` and `runtime-admission-journal-replay`.

### 5) Release and hygiene

- Staging sanitization with `tools/sanitize-check.ps1 -Strict`.
- Empty-repo installation with `install.ps1`.
- Release readiness checks from `docs/release-checklist.md`.
- Public boundary guidance for what should and should not be committed.

## When To Use It

RCCP is a good fit when a repository needs auditable local automation:

- AI-assisted coding with concurrent sessions;
- governance or release gates that must leave evidence;
- task handoff between humans, scripts, and agents;
- repositories that need local state isolation while sharing a common control
  plane.

It is not meant to replace CI, Git, or code review. RCCP sits closer to the
developer workspace and helps decide whether a local task may start, continue,
or close.

## Quickstart

### Requirements

- PowerShell 7+
- Git
- A repository where you want local RCCP command entry and evidence

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

The installer copies the thin command entry and the policy/runtime assets needed
for the target repository to keep its own local evidence and runtime state.

## First Commands

Use these commands after installing RCCP into a project:

```powershell
# Show supported actions
pwsh -NoProfile -File .\rccp.ps1 -Action help

# Inspect current RCCP runtime status
pwsh -NoProfile -File .\rccp.ps1 -Action status

# Start a scoped task and claim the files it intends to change
pwsh -NoProfile -File .\rccp.ps1 -Action task-start -Task "update-readme" -TargetPaths "README.md"

# Install or verify project governance configuration
pwsh -NoProfile -File .\rccp.ps1 -Action project-onboard -Task "project-onboarding" -ProjectConfigPath .\rccp.project.json

# Validate the project configuration and policy compatibility
pwsh -NoProfile -File .\rccp.ps1 -Action project-governance-check -Task "project-onboarding" -ProjectConfigPath .\rccp.project.json

# Validate the staging action registry and required leaf scripts
pwsh -NoProfile -File .\rccp.ps1 -Action action-registry-check -Task "project-onboarding" -Strict

# Run the full-kit registry gate before publishing a complete kit
pwsh -NoProfile -File .\rccp.ps1 -Action action-registry-check -Task "release-readiness" -RequireAllLeafScripts -Strict

# Emit read-only context loading guidance
pwsh -NoProfile -File .\rccp.ps1 -Action memory-briefing -Task "project-onboarding"

# Run a single closeout chain when a task is ready to finish
pwsh -NoProfile -File .\rccp.ps1 -Action closeout-atomic -Task "update-readme" -TargetPaths "README.md" -Mode Staged -GateProfile Fast
```

Action availability depends on the installed policy bundle and adapter. Use
`-Action help` as the source of truth for the current repository.

## Core Concepts

### Admission

Admission checks decide whether the repository is ready for a task. They inspect
runtime state, checkpoint lineage, pending issue markers, writer lanes, and
planning-file context before any write path begins.

### Ownership

Ownership is file-level. A task should claim only the paths it intends to
change, refresh those claims only while the same task is active, and release or
let claims expire quickly.

### Policy Routing

RCCP routes actions through policy bundles, dispatch maps, and project adapters.
This keeps reusable control-plane behavior separate from project-specific
checks such as backend builds, frontend gates, migrations, or docs validation.

### Evidence

Evidence is machine-readable first. A typical evidence card includes:

```json
{
  "verdict": "PASS",
  "category": "admission",
  "reason": "no active writer lanes",
  "nextCommand": "",
  "evidencePath": "evidence/latest/admission-latest.json"
}
```

Human summaries should cite evidence files instead of replacing them.

Latest evidence is kept in `evidence/latest/` for the repository itself, while
adopter projects are expected to keep their own project-local evidence roots.

### Closeout

Closeout is a single auditable chain. The preferred path is one deterministic
`closeout-atomic` run that records task-scoped evidence and avoids manual
stitching of partial checks.

## Repository Layout

```text
rccp.ps1                 Thin repository command entry
install.ps1              Installer for adopting repositories
scripts/rccp/            PowerShell modules and RCCP command core
scripts/help/            Canonical long-form command help
policies/                Policy bundle, dispatch map, and rollout manifest
schemas/                 Public machine-readable contracts
adapters/                Optional project profiles
examples/                Minimal adopter repositories
docs/                    Concepts, evidence model, policy authoring, release notes
tools/                   Staging and release hygiene utilities
evidence/latest/         Local staging evidence, ignored by git
```

## Examples

- `examples/minimal-repo`: a small repository that only wants admission,
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

Before making this repository public or using it as an external kit, verify:

1. `tools/sanitize-check.ps1 -Strict` has zero findings.
2. Installation works in an empty repository.
3. `admission`, `ownership`, `closeout`, `evidence`, and `policy` concepts are
   documented.
4. Business project names, local machine paths, secrets, and historical incident
   details are absent from public files.

## License

This project is licensed under the terms in [LICENSE](LICENSE).
