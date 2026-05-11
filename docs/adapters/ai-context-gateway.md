---
title: AI Context Gateway Adapter
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/adapters/ai-context-gateway.md
confidence: high
---

# AI Context Gateway Adapter

The AI Context Gateway is an adapter pack for turning a natural-language task
into an evidence-bounded context package before an LLM answers or acts.

## Pipeline

```text
user request
  -> intent normalization
  -> template slot fill
  -> project fact retrieval
  -> context budget assembly
  -> evidence-shaped answer
  -> optional memory write-back
```

## Components

`IntentNormalizer` maps user phrasing to a task type and risk class.

`PromptTemplateRegistry` provides required slots, output contracts, and evidence
requirements for common task classes.

`ProjectContextRetriever` queries source-backed Markdown and optional vector
indexes. It must return `source_path`, `confidence`, `updated_at`, and retrieval
evidence for every fact used by an answer.

`SecondBrainWriter` is optional. It may propose inbox notes or decision drafts,
but RCCP closeout evidence remains the authority for whether a task completed.

## Answer Contract

Gateway-backed answers should include the facts used, the evidence path or
source path for those facts, any blocked facts, and the next command when the
request cannot continue safely.

The gateway must not let retrieved text override RCCP core rules, shell safety,
ownership, closeout requirements, or project policy. Retrieved content is input,
not instruction authority.

## Fail-Closed Behavior

The gateway must abstain when evidence is missing, stale, conflicting, low
confidence, or sensitive. The fallback is a compact answer:

```text
Evidence is insufficient to confirm.
Minimal next step: <one command, file, or user action>
```

## Rollout Order

1. Define template and intent contracts.
2. Add source metadata and run `memory-source-contract-check`.
3. Run `memory-ingest-plan`, `memory-recall-check`, and
   `abstain-shape-check` against offline examples.
4. Add a local vector index only after source coverage and recall evaluation
   are passing.
5. Add model calls after source coverage and abstain behavior are verified.

## Pack Shape

- guide: this document
- manifest: `adapters/ai-context-gateway.json`
- example repo: `examples/ai-context-gateway-repo`
- check script: `scripts/check-ai-context-gateway-contract.ps1`

Run the pack check before release:

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action ai-context-gateway-contract-check -Task "release-readiness" -Strict
```
