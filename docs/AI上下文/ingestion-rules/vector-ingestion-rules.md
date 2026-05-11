---
title: Vector Ingestion Rules
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/AI上下文/ingestion-rules/vector-ingestion-rules.md
confidence: high
---

# Vector Ingestion Rules

Optional vector indexes are rebuildable retrieval layers. They are not source
truth.

## Eligible Sources

A document is eligible for primary retrieval only when it has:

- `source_path`
- `owner`
- `updated_at`
- `confidence`
- `status`

`status: inbox`, `status: draft`, and `confidence: low` content may be indexed
only into a blocked or review-only lane.

## Fingerprints

Each ingest run must emit:

- `sourceFingerprint`
- `indexVersion`
- `files`
- `changedFiles`
- `unchangedFiles`
- `deletedPoints`
- `chunks`
- `toolVersion`

`sourceFingerprint` proves which source state was ingested. `indexVersion`
proves which retrieval state was queried.

## Delta Handling

- New or changed files are chunked and upserted.
- Unchanged files are skipped.
- Moved paths delete old points before writing new points.
- Deleted source files delete matching points by `source_path`.
- Cache entries are invalidated for affected `source_path` values.

## Fail-Closed Rules

- Missing `source_path` blocks primary recall.
- Unknown `indexVersion` blocks evidence-backed answers.
- Sensitive content hits stop the ingest run.
- Source coverage below threshold falls back to template-only mode or abstain.

## Sensitive Defaults

Do not index credentials, tokens, private keys, production samples, build
artifacts, local environment files, or local application state.
