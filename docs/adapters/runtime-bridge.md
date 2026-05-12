---
title: RCCP Runtime Bridge
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/adapters/runtime-bridge.md
confidence: high
---

# RCCP Runtime Bridge

The Runtime Bridge reserves a Multica-style integration point without turning
RCCP into a hosted agent platform. It describes how an external board, daemon,
or managed-agent service may mirror RCCP work orders and stream status.

The bridge is optional. The local RCCP loop remains complete without it.

## Contract

The bridge payload is `RCCP_RUNTIME_BRIDGE_SCHEMA_V1` and supports these
operations:

- `createTask`: publish a bounded work order to an external runtime.
- `claimTask`: record which worker accepted a slice.
- `streamStatus`: mirror progress, blockers, and partial evidence.
- `reportBlocker`: surface runtime blockers to the main agent.
- `completeTask`: return handoff evidence for main-agent integration.

The matching schema lives at `schemas/rccp-runtime-bridge.schema.json`.

## Authority Rules

External runtimes are never closeout authorities. They may execute or visualize
work, but only the main agent can integrate results and run closeout. Sub-agent
and external-runtime output must be treated as evidence input, not final proof.

## Failure Mode

If a bridge is unavailable, RCCP falls back to local work orders and evidence
files. If a bridge returns incomplete evidence, the main agent must retry,
park, or abstain rather than close the task.

