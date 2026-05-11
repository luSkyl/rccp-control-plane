# Memory Layer Contract

RCCP memory support is a read-only context loading aid. It helps an operator or
agent decide which durable documents and latest evidence should be loaded first,
without creating a second runtime authority.

The default load order is:

1. identity
2. project
3. task
4. review
5. evolution

## Layer Rules

`identity` covers stable repository behavior, safety boundaries, and durable
collaboration expectations. It should be small and read-only.

`project` covers adopter configuration, policy bundles, compatibility contracts,
and adapter-specific scope. It explains where RCCP ends and the project begins.

`task` covers the current objective, target paths, evidence paths, admission
state, and ownership scope. It should be the narrowest active layer.

`review` covers latest review intelligence, route hints, and replayable evidence.
It can influence routing, but it must not replace admission, ownership, or
closeout evidence.

`evolution` covers accepted rule changes, release boundaries, evidence model
updates, and retired entrypoints. It keeps the reusable control plane from
absorbing source-project private history.

## Boundary

Memory briefing never mutates runtime state, checkpoint state, ownership leases,
policy bundles, or closeout evidence. It emits latest evidence only under the
repository evidence directory and remains safe to run before deeper gates.

## Adapter Bridge

The public memory layer can point to optional downstream adapter contracts, but
it does not make them a second runtime authority. For the ordered path that
joins source-backed notes, context assembly, and bounded delegation, use
`docs/adapters/context-and-coordination.md` together with
`docs/adapters/obsidian-second-brain.md`, `docs/adapters/ai-context-gateway.md`,
and the contracts under `docs/AI上下文/`.

## Runtime Checks

The public second-brain chain is intentionally offline and rebuildable:

1. `obsidian-second-brain-contract-check` validates the adapter docs, source
   schema, and example vault shape.
2. `memory-source-contract-check` validates source-backed note metadata and
   `source_path` coverage.
3. `memory-ingest-plan` emits chunk candidates, `sourceFingerprint`,
   `indexVersion`, and delta evidence without calling a vector service.
4. `memory-recall-check` evaluates recall against generated candidates.
5. `abstain-shape-check` verifies the fail-closed answer shape when recall
   cannot support a claim.
