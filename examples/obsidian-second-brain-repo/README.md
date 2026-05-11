---
title: Obsidian Second-Brain Example
status: active
owner: example-owner
updated_at: 2026-05-11
source_path: examples/obsidian-second-brain-repo/README.md
confidence: high
---

# Obsidian Second-Brain Example

This example shows the smallest public-safe shape for a project that wants to
use RCCP with an Obsidian-readable knowledge root.

The project opens `docs/Rccp` as an Obsidian vault, but RCCP and any retrieval
adapter treat Git Markdown plus `source_path` metadata as the durable source of
truth.

## Try The Shape

1. Open `docs/Rccp` in Obsidian.
2. Review the sample note under `knowledge/`.
3. Keep unsorted notes in `inbox/`.
4. Promote notes only after they have `source_path`, `owner`, `updated_at`, and
   `confidence`.

## Verify The Chain

Run the offline checks in this order:

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action memory-source-contract-check -Task "obsidian-second-brain"
pwsh -NoProfile -File .\rccp.ps1 -Action memory-ingest-plan -Task "obsidian-second-brain"
pwsh -NoProfile -File .\rccp.ps1 -Action memory-recall-check -Task "obsidian-second-brain" -EvalPath "examples/obsidian-second-brain-repo/eval-cases/memory-recall-cases.json"
pwsh -NoProfile -File .\rccp.ps1 -Action abstain-shape-check -Task "obsidian-second-brain" -AnswerPath "examples/obsidian-second-brain-repo/eval-cases/abstain-answer.md"
```

These checks prove the example vault can be indexed, recalled, and safely
abstained from without shipping a model provider.

This example does not ship Qdrant, embeddings, or a model provider.

## What Good Looks Like

- Notes with `source_path`, `owner`, `updated_at`, and `confidence` can enter
  the retrieval set.
- `memory-recall-check` emits source-backed candidates instead of guessed facts.
- `abstain-shape-check` returns a compact fallback when coverage or freshness
  is not strong enough.

## What Stays Closed

- Unsorted notes stay in `inbox/`.
- Local `.obsidian/` state does not become evidence.
- Missing source metadata does not become a final answer.
