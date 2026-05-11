---
title: Obsidian Second-Brain Adapter
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/adapters/obsidian-second-brain.md
confidence: high
---

# Obsidian Second-Brain Adapter

This adapter describes how an adopter can use an Obsidian-readable Markdown
vault as a human knowledge workbench while keeping RCCP evidence and Git-backed
Markdown as the source of truth.

## Role Split

| Layer | Responsibility | Source of truth |
| --- | --- | --- |
| RCCP core | task events, ownership, gates, closeout, evidence | runtime and evidence files |
| Git Markdown | durable project facts, decisions, SOPs, examples | repository history |
| Obsidian | human navigation, linking, review, note grooming | none by itself |
| Vector index | rebuildable retrieval and ranking | derived from Git Markdown |
| LLM | reasoning, summarization, task assistance | cited evidence only |

Obsidian is not a runtime database. `.obsidian/` workspace state, local plugins,
and UI settings are not accepted as gate input, recall evidence, or final-answer
support.

## Vault Shape

Adopters may use any vault root, but the recommended source root is:

```text
docs/Rccp/
  inbox/
  knowledge/
  decisions/
  projects/
```

`inbox/` is for low-confidence or unsorted material. `knowledge/`,
`decisions/`, and `projects/` are eligible for retrieval only when their notes
carry the required source metadata.

## Required Metadata

Long-lived notes that can influence LLM answers or retrieval must include:

```yaml
---
title: Example knowledge note
status: active
owner: platform-owner
updated_at: 2026-05-11
source_path: docs/policy-authoring.md#adapter-rules
confidence: high
---
```

`source_path` is the shared key across the Markdown note, Git history, evidence
files, and any vector point derived from the note. Wikilinks are allowed for
human navigation, but automated recall must use `source_path` and metadata.

## Retrieval Boundary

Only notes with `source_path`, `owner`, `updated_at`, `confidence`, and an
eligible `status` may enter the primary retrieval set. Low-confidence notes stay
in `inbox/` or a blocked list. If the retrieval layer cannot prove coverage or
freshness, the answer path must fall back to template-only mode or abstain.

## Runtime Chain

The public offline chain is:

1. `memory-source-contract-check`
2. `memory-ingest-plan`
3. `memory-recall-check`
4. `abstain-shape-check`

The matching example vault and evaluation cases live under
`examples/obsidian-second-brain-repo/`.

## Public Kit Boundary

This repository ships the adapter contract and example shape, not a project
vault, embedding provider, Qdrant service, or private historical memory. A
downstream project owns its vault contents, index lifecycle, and model provider.
