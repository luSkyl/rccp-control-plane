---
title: RCCP Adapters
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/adapters/README.md
confidence: high
---

# RCCP Adapters

Adapters describe optional project capabilities that sit outside RCCP core.
They let adopters add language, release, documentation, retrieval, or memory
rules without changing the reusable control plane.

## Public Adapter Guides

- [Java + Vue Adapter](java-vue.md)
- [Docs-Only Adapter](docs-only.md)
- [Obsidian Second-Brain Adapter](obsidian-second-brain.md)
- [AI Context Gateway Adapter](ai-context-gateway.md)
- [Context and Coordination Path](context-and-coordination.md)
- [Multi-Agent Workflow](../multi-agent-workflow.md)

## Runtime Verification

Public adapters are expected to land with an offline verification chain and a
matching example vault or example repo. The pack factory defines the shared
shape, and the common surfaces follow the order below.

| Surface | Example | Minimum verification chain |
| --- | --- | --- |
| Adapter pack factory | `examples/adapter-pack-template` | `adapter-pack-factory-check` |
| Java + Vue pack | `examples/java-vue-repo` | `java-vue-contract-check` |
| Docs-only pack | `examples/docs-only-repo` | `docs-only-contract-check` |
| Obsidian second-brain | `examples/obsidian-second-brain-repo` | `obsidian-second-brain-contract-check` -> `memory-layer-contract-check` -> `memory-source-contract-check` -> `memory-ingest-plan` -> `memory-recall-check` -> `abstain-shape-check` |
| AI Context Gateway | `examples/ai-context-gateway-repo` | `ai-context-gateway-contract-check` |
| Context and coordination | `docs/adapters/context-and-coordination.md` | `multi-agent-contract-check` |
| Multi-agent workflow | `examples/multi-agent-repo` | `multi-agent-contract-check` |

## Factory

- [Adapter Pack Factory](adapter-pack-factory.md)

## Boundary

RCCP core owns command entry, task state, ownership, policy routing, gates, and
evidence. Adapter documents may define downstream conventions, but they must not
make project-specific files, private history, or local user state part of the
public kit contract.
