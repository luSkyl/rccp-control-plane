# Task Plan

Goal: eliminate the root cause behind registered-but-unavailable RCCP actions by adding an explicit distribution contract, upgrading registry validation, restoring P0 governance leaf actions, and closing with repeatable evidence.

## Phases

- [complete] Baseline current repository state and evidence.
- [complete] Add distribution profile metadata to mirrored dispatch contracts.
- [complete] Upgrade `action-registry-check` with default required-action validation and `-RequireAllLeafScripts`.
- [complete] Add P0 governance leaf scripts for existing capability and kit compatibility checks.
- [complete] Sync README/help documentation and rerun compatibility gates.
- [complete] Commit, push, and summarize closure evidence.

## Decisions

- Keep current repository as `staging-extraction`, not full kit.
- Required actions must exist and pass contract checks.
- Full registry coverage is enforced only with `-RequireAllLeafScripts`.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---|---|
| `existing-capability-probe` did not receive `-Why` through the entry wrapper | 1 | Added `BoundArgs.Why` translation before falling back to `Objective`. |
| `leaf-contract-check` failed on optional/full-kit leaf contracts in staging | 1 | Added distribution-profile default scope and full-kit opt-in with `-RequireAllLeafScripts`. |
| Required aliases lacked leaf contracts | 1 | Added contracts for `rccp-leaf-contract-check` and `leaf-contract-check`. |
