---
title: External Capability Intake Policy
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/治理/策略/external-capability-intake.md
confidence: high
---

# External Capability Intake Policy

RCCP can learn from external projects only through a delta-first intake. The
current control plane remains authoritative unless an explicit greenfield
redesign is approved.

## Intake Matrix

| Source | Absorb Level | RCCP Mapping | Boundary |
| --- | --- | --- | --- |
| GitNexus | concept and interface shape | Code Context Adapter, repo graph snapshot, MCP provider option | no source copy; no hard dependency |
| Multica | product model and optional bridge shape | agent runtime bridge, status stream, blocker reporting | no hosted platform import; no closeout authority |

## License Gate

Every external capability must pass `external-capability-license-check` before
implementation copies, generated derivatives, vendored packages, or runtime
coupling are allowed. Current policy is concept-level absorption only for
GitNexus because its public repository declares a noncommercial license, and
interface-level compatibility only for Multica unless a separate license review
approves broader use.

## Runtime Boundary

RCCP is a governance control plane. It may emit work orders, evidence cards,
context packs, and bridge payloads. External systems may display or execute
tasks, but they cannot bypass `ownership-claim`, `ownership-check`, verifier
evidence, or `closeout-atomic`.

## Acceptance Rule

An external capability is accepted only when:

- Existing RCCP capability is confirmed first.
- The absorbed capability is mapped to an explicit RCCP contract.
- The implementation has a fallback when the external tool is unavailable.
- License risk is recorded in evidence.
- CI gates remain runnable without network access or external daemons.

