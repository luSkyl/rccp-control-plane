# Findings

## Baseline

- `existing-capability-probe` for this request returned `DELTA_ANSWER_REQUIRED`.
- `closeout-atomic` already invokes `final-recap-check` before `task-close`.
- `final-recap-check` already emits `externalReplyRequired=true`, `requiredFields`, `issues`, `blockingIssues`, and task-specific recap files.

## Root Cause

The current closeout chain validates that recap evidence exists, but it does not validate the final external reply against that recap evidence. This leaves a gap where a task can produce evidence but the user-facing answer can still omit root-cause closure, existing mechanism gap, recurrence prevention, open risk, or evidence path details.

The first hard-gate draft still defaulted to `docs/治理/最新态/final-answer-draft-latest.md`. That default preserved a second root cause: the gate could read an untracked, stale latest draft instead of a current reply artifact.

## Target Resolution

- Add `final-reply-contract-check` to compare final answer text with `final-recap-check-latest.json`.
- Require callers to pass the current final reply through explicit `-AnswerPath` or `-AnswerText`; do not infer latest draft files.
- Fail when required recap fields are absent from the answer.
- Fail when unresolved blocking issues exist and the answer claims completion.
- Register the action and cover it with positive and negative regression cases.

## Verification So Far

- PowerShell parser check passed for the new scripts and modified RCCP entry files.
- Dispatch JSON parse passed for `policies/rccp-entry-dispatch.json` and `docs/治理/策略/rccp-entry-dispatch.json`.
- `final-reply-contract-regression`: PASS.
- `leaf-contract-check -ActionName final-reply-contract-check -Strict`: PASS.
- `action-registry-check -Strict`: PASS with missingScripts=0.
- `leaf-contract-check -Strict`: PASS across 16 checked leaf actions.
- `thin-entry-check -Strict`: initially failed on entry line count, then PASS after thinning blank lines.
- `final-reply-contract-check -AnswerPath docs/治理/最新态/final-answer-draft-latest.md -Strict`: PASS.
- `final-reply-contract-regression -Strict`: PASS with `negative-missing-answer-source` expected failure covered.
- `action-registry-check -RequireAllLeafScripts -Strict`: PASS with `missingScripts=0`.
- `leaf-contract-check -Strict`: PASS across 16 checked leaf actions.
- `closeout-atomic -AnswerPath docs/治理/最新态/final-answer-draft-latest.md`: PASS; `final-reply-contract-check` ran before `task-close`.
- `sanitize-check -Strict`: PASS with `hits=0`.
- `doc-check` is unavailable in this staging extraction; README/help dual sync was still applied manually.
