---
title: AI Context Adapter Contracts
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/AI上下文/README.md
confidence: high
---

# AI Context Adapter Contracts

This directory contains public-safe contracts for using LLM context, Obsidian
notes, and optional vector retrieval with RCCP.

## Contracts

- [Source Path Contract](source-path-contract.md)
- [Second-Brain Vault Template](second-brain-vault-template.md)
- [Vector Ingestion Rules](ingestion-rules/vector-ingestion-rules.md)
- [Abstain Protocol](abstain-protocol.md)

## Runtime Checks

- `obsidian-second-brain-contract-check` validates the public adapter surface.
- `memory-layer-contract-check` validates briefing and dispatch alignment.
- `memory-source-contract-check` validates note metadata and `source_path`.
- `memory-ingest-plan` emits rebuildable chunk and delta evidence.
- `memory-recall-check` evaluates offline recall cases.
- `abstain-shape-check` validates fail-closed answer wording.

## Boundary

The contracts define how a downstream project can make long-lived knowledge
auditable. They do not ship a model provider, a vector database, project facts,
or a production memory service.

## Related Paths

- [Context and Coordination Path](../adapters/context-and-coordination.md)
- [Multi-Agent Workflow](../multi-agent-workflow.md)
