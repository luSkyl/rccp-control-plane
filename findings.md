# Findings

## Baseline

- Current worktree was clean at initial check: `git status --short` returned no changed files.
- Existing-capability probe for this request returned `DELTA_ANSWER_REQUIRED`; the final report must be a delta/evidence answer, not a greenfield redesign.
- The repository contains current planning files, governance docs, scripts, policies, schemas, evidence, examples, adapters, and tools.

## Findings Log

- Tracked public surface is small: root entry, `scripts/`, `policies/`, `schemas/`, `docs/`, `examples/`, `adapters/`, and `tools/`.
- `.gitignore` intentionally ignores `.rccp/`, `.claude/`, `docs/治理/最新态/`, `evidence/latest/`, logs, backups, local files, and build output.
- README states this is an early `staging-extraction` public surface; registered public leaf actions are only the ones shipped in this repo.
- Dispatch registry has `readonly`, `runtimeWrite`, and `closeoutWrite` surfaces; public leaf scripts are registered under `entryDispatch`, while runtime/closeout core actions live in the module path.
- The initial tracked worktree became dirty only because this audit updated `task_plan.md`, `findings.md`, and `progress.md`.
- PASS gates: `action-registry-check -RequireAllLeafScripts -Strict`, `leaf-contract-check -Strict`, `thin-entry-check -Strict`, `memory-layer-contract-check -Strict`, `rccp-kit-compat-check -Strict`, `rccp-kit-rollout-check -Strict`, `final-reply-contract-regression -Strict`, and `tools/sanitize-check.ps1 -Strict`.
- Unavailable public/documented actions confirmed by execution: `doc-check`, `governance-stale-candidates-check`, and `gate-debt` all fail with "action is not available".
- `task-start` smoke succeeds but emits missing maintenance warnings for `progress-doc-auto-compact` and `governance-doc-auto-compact`.
- `task-end` smoke fails before close because `progress-doc-auto-compact` is missing and is invoked with `-HardFail`.
- `closeout-atomic` does not invoke the same maintenance branch; it runs recap/reply checks and `task-close` directly.
- Empty-repo install smoke: `install.ps1` installs and `help` runs, but installed `action-registry-check -RequireAllLeafScripts -Strict` fails because `.rccp/docs/治理/策略/rccp-entry-dispatch.json` is not copied.
- JSON parse across repository JSON files passed.
- PowerShell parser check across `*.ps1` and `*.psm1` passed after correcting the local check command.
- Kit manifest declares `command-template-lint` as a required action, but it is absent from dispatch/core/runtime/closeout action surfaces; existing kit checks did not catch that mismatch.

## Root-Cause Hardening Findings

- `command-template-lint` and `action-reference-surface-check` are now shipped leaf actions and dispatch required actions; full leaf contract now checks 18 actions.
- `action-reference-surface-check` catches stale action references in README, release checklist, help text, manifest, and dispatch, while excluding reserved `help` from ordinary action matching.
- `project-onboard` now records `semanticPass`, `profile`, `checkedInvariants`, `waivedInvariants`, and `blockingFailures`.
- `project-onboard -Profile adopter-onboard -Strict` with no `rccp.project.json` correctly fails in a temporary evidence directory.
- `command-template-lint -Strict` correctly fails an ambiguous `-Risk` command template in a temporary evidence directory.
- `project-governance-check` now checks contract/manifest required actions against dispatchable/core actions and validates real project configs when the selected profile requires one.
- `rccp-kit-rollout-check` now checks evidence content, dispatch/contract/manifest mirrors, CI workflow presence, required-action dispatchability, and empty-repo install smoke.
- `install.ps1` now copies `docs/memory-layer.md` and `docs/治理/策略` into `.rccp`, which makes installed `action-registry-check -RequireAllLeafScripts -Strict` pass during rollout smoke.
- `help` is a special entry branch in `scripts/rccp/Rccp.Entry.psm1`; until it was added to the public surface mirror, `action-reference-surface-check` treated doc references to `-Action help` as unavailable.
- After adding `help` to the surface mirror, `action-reference-surface-check`, `action-registry-check`, `command-template-lint`, `rccp-leaf-contract-check`, `thin-entry-check`, `memory-layer-contract-check`, `project-onboard`, `project-governance-check`, `rccp-kit-compat-check`, and `rccp-kit-rollout-check` all passed, and a temp install smoke confirmed `task-start` and `task-end` work end-to-end.
- Residual maintenance warning-skips are now removed by executable leaves: `progress-doc-auto-compact`, `governance-doc-auto-compact`, and `auto-commit-govern`.
- `rccp-kit-rollout-check` now captures install-smoke task-start/task-end output and fails if maintenance unavailable/skipped warnings return.
- Empty-target install smoke now shows `progress-doc-auto-compact`, `governance-doc-auto-compact`, and `auto-commit-govern` all executing with `pass=True`.
- `rccp-kit-rollout-check` now fails on maintenance unavailable/skipped warnings if they reappear, so install smoke is warning-free, not just exit-code clean.
