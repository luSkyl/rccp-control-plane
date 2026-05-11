---
title: RCCP Adapter Pack Factory
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/adapters/adapter-pack-factory.md
confidence: high
---

# RCCP Adapter Pack Factory

This document defines the shared shape for reusable RCCP adapter packs. A pack
is a productized boundary around one adopter scenario, not a change to RCCP
core.

## What A Pack Must Contain

Every adapter pack must include:

1. A public guide under `docs/adapters/`.
2. A machine-readable pack manifest under `adapters/`.
3. A source-surface example repo under `examples/`.
4. A dedicated contract check under `scripts/`.
5. Release and rollout references in README, checklist, CI, and kit gates.

## Shared Product Model

The factory standardizes the same five steps for every pack:

1. Define the problem boundary and what the pack does not own.
2. Define the pack contract and required gates.
3. Provide a minimal example repository.
4. Provide a public verification command.
5. Register the pack in release readiness and rollout checks.

## Pack Families

The repository should grow these packs first:

- `java-vue`
- `docs-only`
- `obsidian-second-brain`
- `ai-context-gateway`
- `multi-agent-workflow`

Each pack can have its own gates, but all of them must use the same factory
shape so adopters can discover, copy, and verify them the same way.

## Required Boundaries

Adapter packs may define language checks, build checks, docs checks, migration
checks, context checks, or collaboration checks. They must not:

- change RCCP core ownership or closeout rules;
- depend on private history as source of truth;
- require a model provider or vector service unless the pack explicitly says
  it is optional and fail-closed without it;
- hide their verification steps behind prose only.

## Example Pack Flow

```text
guide -> manifest -> example repo -> check script -> dispatch -> CI -> release checklist -> rollout
```

## Acceptance Gate

Run the factory check before release:

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action adapter-pack-factory-check -Task "release-readiness" -Strict
```

If the factory check fails, the pack is not ready for adoption even if its
individual leaf checks pass.

For this staging kit, the pack is only considered productized when the source
checkout and an empty-target install smoke both pass the same check.
