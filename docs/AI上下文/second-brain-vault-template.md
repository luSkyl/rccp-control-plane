---
title: Second-Brain Vault Template
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/AI上下文/second-brain-vault-template.md
confidence: high
---

# Second-Brain Vault Template

Use this shape when a downstream project wants its RCCP knowledge root to open
cleanly in Obsidian while remaining safe for automated retrieval.

```text
docs/Rccp/
  README.md
  inbox/
    README.md
  knowledge/
    README.md
  decisions/
    README.md
  projects/
    README.md
```

## Folder Roles

`inbox/` stores unsorted material, open questions, and low-confidence notes.

`knowledge/` stores durable facts, glossaries, SOPs, and reusable context.

`decisions/` stores why a choice was made, alternatives, risk, rollback, and
evidence.

`projects/` stores task-level context, milestones, blockers, and follow-up
evidence.

## Note Frontmatter

```yaml
---
title: Example note
tags:
  - rccp
  - context
status: active
owner: platform-owner
updated_at: 2026-05-11
source_path: docs/concepts.md#project-adapters
confidence: high
---
```

## Workflow

1. Capture uncertain content in `inbox/`.
2. Promote durable material only after it has `source_path` and an owner.
3. Store decisions in `decisions/` with alternatives and rollback.
4. Refresh retrieval indexes after source metadata or content changes.
5. Treat `.obsidian/` as local UI state, not as a runtime authority.
