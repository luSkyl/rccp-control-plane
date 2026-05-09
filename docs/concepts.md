# Concepts

RCCP separates repository governance into a small set of auditable concepts.

## Admission

Admission checks decide whether the repository is ready for a task. They look
for runtime drift, pending incidents, writer-lane conflicts, and checkpoint
lineage issues before any write path begins.

## Ownership

Ownership is file-level. Agents should claim only the paths they intend to
change, refresh claims only while working on the same task, and release or let
claims expire quickly.

## Closeout

Closeout is a single auditable chain. The preferred closure path is one
deterministic `closeout-atomic` run that records fast evidence and sidecar
evidence.

## Evidence

Evidence is machine-readable first. Human summaries should cite JSON evidence
instead of replacing it.

## Project Adapters

Project-specific rules live outside RCCP core. A project adapter can define
language checks, docs checks, migration checks, or release gates without
changing the control plane.
