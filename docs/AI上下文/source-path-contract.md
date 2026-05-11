---
title: Source Path Contract
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/AI上下文/source-path-contract.md
confidence: high
---

# Source Path Contract

`source_path` is the durable key that connects human notes, Git files, evidence,
and optional vector index points.

## Required Fields

Every long-lived note that can influence retrieval or answers must expose:

| Field | Meaning |
| --- | --- |
| `title` | Human readable note title. |
| `status` | `active`, `draft`, `deprecated`, or `inbox`. |
| `owner` | Role or team responsible for maintaining the note. |
| `updated_at` | Date when the note was last reviewed. |
| `source_path` | Repository path, evidence path, or anchored section proving the fact. |
| `confidence` | `high`, `medium`, or `low`. |

## Rules

- `source_path` must be repository-relative unless it intentionally points to a
  public external reference.
- Retrieval points must carry the same `source_path` as the source note.
- Moving a source file requires deleting old index points and writing new ones.
- Low-confidence or missing-source notes must not enter primary recall.
- Human wikilinks may assist navigation, but they do not replace `source_path`.

## Example

```yaml
---
title: Adapter routing rules
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/policy-authoring.md#project-adapters
confidence: high
---
```
