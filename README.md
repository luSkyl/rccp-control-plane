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
  adapter, memory, project, kit, install-smoke, and sanitization gates listed
  below.

## Capability Map

| Area | Capabilities |
| --- | --- |
| Command entry | Single PowerShell entry through `rccp.ps1`; direct leaf scripts stay behind the entry facade. |
| Task runtime | `task-start`, `task-bootstrap`, `checkpoint`, `resume-check`, `self-interrupt`, `status`, `trace`, `task-end`. |
| Ownership | File-scoped ownership checks through `ownership-claim` and `ownership-check`. |
| Closeout | `closeout-check`, `closeout-atomic`, recap validation, and final-reply contract validation with explicit `-AnswerPath` or `-AnswerText`. |
| Evidence | Compact JSON/Markdown evidence for status, registry, leaf contracts, project checks, kit rollout, closeout, and memory-layer checks. |
| Adapter pack factory | `adapter-pack-factory-check`, `java-vue-contract-check`, `docs-only-contract-check`, and `ai-context-gateway-contract-check` standardize reusable pack shapes for Java+Vue, docs-only, Obsidian, AI context, and multi-agent packs. |
| Multi-agent coordination | `multi-agent-contract-check`, `execution-card`, `lease-acquire`, and `ownership-claim` define bounded main-agent/sub-agent work orders and evidence handoff. |
| Context orchestration | `docs/adapters/context-and-coordination.md`, `obsidian-second-brain-contract-check`, `memory-layer-contract-check`, `memory-source-contract-check`, `memory-ingest-plan`, `memory-recall-check`, and `abstain-shape-check` show the ordered path from source-backed notes to bounded context and fail-closed answers. |
| Project adoption | `project-onboard`, `project-governance-check`, `rccp-kit-compat-check`, and `rccp-kit-rollout-check`. |
| Registry hygiene | `action-registry-check`, `rccp-leaf-contract-check`, `thin-entry-check`, and `action-reference-surface-check`. |
| Command safety | `command-template-lint` validates command snippets before they are copied into docs, CI, or handoff notes. |
| Existing capability answers | `existing-capability-probe` and `existing-capability-answer-shape-check` help avoid redesigning a capability that already exists, while preserving a layered v1/v2/v3 response path for authorized GitHub or greenfield exploration. |
| Memory layer | `memory-layer-contract-check`, `memory-briefing`, `memory-source-contract-check`, `memory-ingest-plan`, `memory-recall-check`, and `abstain-shape-check` keep context loading, ingest evidence, recall evaluation, and abstain behavior auditable. |
| Obsidian/LLM adapter | `obsidian-second-brain-contract-check`, public adapter docs, source metadata rules, vector-ingestion rules, and abstain guidance describe how downstream projects can add an auditable second-brain layer without changing RCCP core. |
| Release hygiene | `tools/sanitize-check.ps1 -Strict`, parser checks, empty-repo install smoke, and release checklist gates. |

## Quickstart

### Requirements

- PowerShell 7+
- Git
- A repository where you want RCCP command entry and local evidence

### Try RCCP in this repository

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action help
pwsh -NoProfile -File .\rccp.ps1 -Action rccp-kit-rollout-check -Task "quickstart" -Strict
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

### 3) Validate context and adapter surfaces

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action obsidian-second-brain-contract-check -Task "adapter-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action ai-context-gateway-contract-check -Task "adapter-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action adapter-pack-factory-check -Task "adapter-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action java-vue-contract-check -Task "adapter-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action docs-only-contract-check -Task "adapter-readiness" -Strict
```

### 4) Validate a multi-agent handoff

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action multi-agent-contract-check -Task "multi-agent-readiness" -Strict
```

### 5) Check the public kit before release

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action command-template-lint -Task "release-readiness" -CommandText "pwsh -NoProfile -File .\rccp.ps1 -Action rccp-leaf-contract-check -Task `"release-readiness`" -RequireAllLeafScripts -Strict" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action action-reference-surface-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action action-registry-check -Task "release-readiness" -RequireAllLeafScripts -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action thin-entry-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action rccp-leaf-contract-check -Task "release-readiness" -RequireAllLeafScripts -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action obsidian-second-brain-contract-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action memory-layer-contract-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action memory-source-contract-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action memory-ingest-plan -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action memory-recall-check -Task "release-readiness" -EvalPath "examples/obsidian-second-brain-repo/eval-cases/memory-recall-cases.json" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action abstain-shape-check -Task "release-readiness" -AnswerPath "examples/obsidian-second-brain-repo/eval-cases/abstain-answer.md" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action ai-context-gateway-contract-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action adapter-pack-factory-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action java-vue-contract-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action docs-only-contract-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action multi-agent-contract-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action project-onboard -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action project-governance-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action rccp-kit-rollout-check -Task "release-readiness" -Strict
pwsh -NoProfile -File .\tools\sanitize-check.ps1 -Strict
```

### 6) Close out with explicit final-answer evidence

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
docs/adapters/           Public optional adapter guides
docs/AI上下文/           Public LLM context, source-path, ingestion, and abstain contracts
docs/                    Concepts, evidence model, policy authoring, release notes
tools/                   Staging and release hygiene utilities
evidence/latest/         Local staging evidence, ignored by git
```

Compatibility mirrors under `docs/治理/策略/` are kept for current PowerShell
core compatibility and should stay synchronized with `policies/`.

## Examples

- `examples/minimal-repo`: a small repository that only wants RCCP entry,
  ownership, and closeout evidence.
- `examples/obsidian-second-brain-repo`: a minimal Obsidian-readable knowledge
  root that demonstrates `source_path` metadata without shipping a vector
  service or model provider.
- `examples/ai-context-gateway-repo`: a minimal fail-closed context assembly
  example that keeps source-backed retrieval and abstain behavior auditable.
- `examples/adapter-pack-template`: the pack-factory template that future
  adapter families can copy into a concrete guide, manifest, example repo, and
  check script.
- `examples/multi-agent-repo`: a minimal multi-agent handoff example that keeps
  closeout on the main agent and returns bounded sub-agent evidence.
- `examples/java-vue-repo`: a Java and Vue pack example that keeps backend,
  frontend, migration, and release gates together.
- `examples/docs-only-repo`: a docs-first pack example for policy, Markdown,
  and release governance without application build gates.

## Documentation

- [Concepts](docs/concepts.md)
- [Evidence](docs/evidence.md)
- [Policy Authoring](docs/policy-authoring.md)
- [Obsidian Second-Brain Adapter](docs/adapters/obsidian-second-brain.md)
- [AI Context Gateway Adapter](docs/adapters/ai-context-gateway.md)
- [Context and Coordination Path](docs/adapters/context-and-coordination.md)
- [Java + Vue Adapter](docs/adapters/java-vue.md)
- [Docs-Only Adapter](docs/adapters/docs-only.md)
- [Adapter Pack Factory](docs/adapters/adapter-pack-factory.md)
- [AI Context Contracts](docs/AI上下文/README.md)
- [Multi-Agent Workflow](docs/multi-agent-workflow.md)
- [Release Checklist](docs/release-checklist.md)
- [Minimal Example](examples/minimal-repo/README.md)
- [Obsidian Second-Brain Example](examples/obsidian-second-brain-repo/README.md)

## Release Readiness

Before making this repository public or embedding it as an external kit, verify:

1. `pwsh -NoProfile -File .\rccp.ps1 -Action help` works.
2. `pwsh -NoProfile -File .\tools\sanitize-check.ps1 -Strict` has zero findings.
3. PowerShell parser checks pass for every `*.ps1` and `*.psm1`.
4. `command-template-lint -Strict` passes for the published command examples.
5. `action-reference-surface-check -Strict` passes.
6. `action-registry-check -RequireAllLeafScripts -Strict` passes.
7. `thin-entry-check -Strict` passes.
8. `rccp-leaf-contract-check -RequireAllLeafScripts -Strict` passes.
9. `obsidian-second-brain-contract-check -Strict` passes for the public
   adapter surface.
10. `memory-layer-contract-check`, `memory-source-contract-check`,
   `memory-ingest-plan`, `memory-recall-check`, and `abstain-shape-check`
   pass for the public memory chain.
11. `ai-context-gateway-contract-check -Strict` passes for the AI context gateway pack surface.
12. `adapter-pack-factory-check -Strict` passes for the shared adapter-pack template surface.
13. `java-vue-contract-check -Strict` passes for the Java + Vue pack surface.
14. `docs-only-contract-check -Strict` passes for the docs-only pack surface.
15. `multi-agent-contract-check -Strict` passes for the public coordination surface.
16. `project-onboard`, `project-governance-check`, and
   `rccp-kit-rollout-check` report semantic PASS for the intended profile.
17. Empty-repo installation through `install.ps1` works, including installed
    `action-registry-check -RequireAllLeafScripts -Strict`,
    `thin-entry-check -Strict`,
    `adapter-pack-factory-check -Strict`, `java-vue-contract-check -Strict`,
    `docs-only-contract-check -Strict`, and
    `ai-context-gateway-contract-check -Strict`.
18. Business project names, local machine paths, secrets, and historical incident
   details are absent from public files.

## License

This project is licensed under the terms in [LICENSE](LICENSE).
