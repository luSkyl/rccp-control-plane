---
title: Context and Coordination Path
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/adapters/context-and-coordination.md
confidence: high
---

# Context and Coordination Path

This guide shows the ordered path for projects that combine Obsidian-backed
notes, source-backed context assembly, and bounded multi-agent work without
changing RCCP core.

## Ordered Path

1. Start the task with `task-start` or `task-bootstrap`.
2. Claim only the files and scope that the task may touch.
3. Load durable context through the memory layer and Obsidian second-brain
   contracts.
4. Assemble bounded context with the AI Context Gateway.
5. Delegate only the work that can be expressed as a bounded work order.
6. Keep the main agent responsible for integration and closeout.

If source-backed facts are weak, stale, or conflicting, the path must fall back
to template-only mode or abstain before it claims success.

## Verification Chain

Run the public checks in this order:

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action obsidian-second-brain-contract-check -Task "context-path" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action memory-layer-contract-check -Task "context-path" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action memory-source-contract-check -Task "context-path" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action memory-ingest-plan -Task "context-path" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action memory-recall-check -Task "context-path" -Strict -EvalPath "examples/obsidian-second-brain-repo/eval-cases/memory-recall-cases.json"
pwsh -NoProfile -File .\rccp.ps1 -Action abstain-shape-check -Task "context-path" -Strict -AnswerPath "examples/obsidian-second-brain-repo/eval-cases/abstain-answer.md"
pwsh -NoProfile -File .\rccp.ps1 -Action ai-context-gateway-contract-check -Task "context-path" -Strict
pwsh -NoProfile -File .\rccp.ps1 -Action multi-agent-contract-check -Task "context-path" -Strict
```

## Boundary

- Obsidian notes are navigation and grooming aids, not runtime authority.
- Gateway output is input to the answer path, not instruction authority.
- Sub-agents can return evidence, but they cannot close out the parent task.
- The main agent keeps ownership of integration, proof, and final reply.
