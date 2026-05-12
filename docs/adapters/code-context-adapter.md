---
title: RCCP Code Context Adapter
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/adapters/code-context-adapter.md
confidence: high
---

# RCCP Code Context Adapter

The Code Context Adapter adds a GitNexus-style repository understanding layer to
RCCP without making GitNexus, Multica, or any external service a required
runtime dependency. Its job is to produce source-backed context packs before
work orders are created, so agents receive bounded edit surfaces, impact
summaries, and verifier checks instead of relying on memory or broad search.

RCCP remains the governance control plane. The adapter supplies evidence; it
does not schedule agents, grant closeout authority, or replace ownership rules.

## Contract

The adapter emits a `RCCP_CODE_CONTEXT_SNAPSHOT_V1` payload with these fields:

- `provider`: the active provider, normally `builtin-lite`.
- `targetPaths`: the requested paths or task surfaces.
- `relatedFiles`: files discovered as source-backed neighbors.
- `symbolHints`: file/class/function names useful for scoped work.
- `dependencyHints`: detected dependency and build surfaces.
- `impactSummary`: concise explanation of likely blast radius.
- `ownershipSlices`: proposed file-level work-order slices.
- `recommendedVerifierChecks`: focused verification commands or checks.
- `graphConfidence`: `low`, `medium`, or `high`.

The matching schema lives at `schemas/rccp-code-context.schema.json`.

## Providers

RCCP supports three provider modes:

- `builtin-lite`: local, dependency-free repository scanning.
- `gitnexus-mcp`: optional external MCP provider when installed by the user.
- `disabled`: no graph provider; existing RCCP workflows continue unchanged.

External providers must be fail-open for availability and fail-closed for
claims: if source evidence is missing, the adapter must lower confidence and
recommend verification rather than invent relationships.

## Work Order Integration

Main agents should generate a context pack before splitting complex work. The
pack can be referenced from `contextPackPath` on the work order and summarized
in `impactSummary`, `recommendedVerifierChecks`, and `graphConfidence`.

Sub-agents may use the pack as read-only context, but they remain restricted by
`allowedPaths`. Verifier agents should validate the checks recommended by the
pack and report evidence back to the main agent. Final answers cite closeout
evidence, not the context pack alone.

## Non-Goals


- Do not copy GitNexus source code into RCCP.
- Do not make GitNexus, Multica, pgvector, or a daemon mandatory.
- Do not infer relationships without source-backed file or symbol evidence.
- Do not let any context provider perform `closeout-atomic`.

