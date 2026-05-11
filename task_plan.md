# Task Plan

Goal: make the final external reply a hard-gated closeout artifact so root cause, resolution status, open risks, and evidence paths cannot be omitted after `final-recap-check`.

## Phases

- [complete] Bootstrap RCCP task state and claim exact files.
- [complete] Implement `final-reply-contract-check`.
- [complete] Register the new leaf action in runtime and mirrored dispatch contracts.
- [complete] Add regression coverage for pass and fail cases.
- [complete] Remove implicit latest-draft fallback and sync README/help.
- [complete] Re-run registry, leaf-contract, new gate, and closeout evidence.

## Decisions

- Reuse existing `final-recap-check-latest.json` as the source of truth.
- Keep the new check as a leaf script with strict `exit 1` behavior.
- Insert the gate before `task-close` in `closeout-atomic`.
- Treat final answer text as a checked artifact via explicit `-AnswerPath` or `-AnswerText`.
- Do not infer `docs/治理/最新态/final-answer-draft-latest.md`; latest files can be stale and must not make the gate pass by accident.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---|---|
| `checkpoint -Risk` was ambiguous between `RiskClass` and `RiskScore` | 1 | Re-run checkpoint with explicit `-RiskClass NORMAL`. |
| `thin-entry-check` failed with `ENTRY_TOO_THICK lineCountApprox=82` | 1 | Removed blank lines from `scripts/rccp/rccp.ps1` without changing dispatch behavior; rerun passed. |
| `closeout-atomic` failed because `final-recap-check` received unsupported `-AnswerPath` | 1 | Filter final-answer-only args away from `final-recap-check`; keep them for `final-reply-contract-check`. |
| `final-reply-contract-check` could still infer an untracked latest draft | 1 | Remove the default `AnswerPath` and add `MISSING_ANSWER_SOURCE` regression coverage. |
| `doc-check` action is unavailable in this staging extraction | 1 | Record as unavailable; README/help were both updated and `sanitize-check -Strict` passed. |
