# Task Plan

Goal: produce an evidence-based pain point, optimization, and recommendation report for the current repository state without inventing a new control plane.

## Current Execution: root-cause-surface-closure

Goal: land the root-cause fix for false PASS risk by making command templates, action references, project onboarding, project governance, rollout, installer smoke, CI, and final closeout evidence semantically checkable.

- [complete] Start governed task and claim target files.
- [complete] Inspect dispatch, installer, and gate scripts.
- [complete] Add `command-template-lint` and `action-reference-surface-check` and register them in the public leaf surface.
- [complete] Add profile-aware project onboarding/governance semantics.
- [complete] Strengthen kit rollout with evidence-content checks, mirror checks, CI presence, and empty-repo install smoke.
- [complete] Run final verification and closeout.

## Current Execution: root-cause-hardening-finalization

Goal: finish the remaining hardening by replacing maintenance warning-skips with real leaves and making rollout fail on maintenance warning regressions.

- [complete] Start governed task and claim residual hardening files.
- [complete] Add executable maintenance leaves for progress docs, governance docs, and auto-commit governance status.
- [complete] Strengthen install smoke to fail on maintenance unavailable/skipped warnings.
- [complete] Rerun full gates and close out.

## Phases

- [complete] Establish current repo state, skill constraints, and existing-capability verdict.
- [complete] Inventory changed/current files, command registry, docs, evidence, and runtime governance outputs.
- [complete] Run available read-only or non-mutating checks to expose objective failures.
- [complete] Classify findings by severity, evidence path, root cause, and minimal repair route.
- [complete] Validate the final answer shape against existing-capability requirements where possible.
- [complete] Implement root-cause fixes for install layout, closeout maintenance, action references, rollout coverage, and CI/docs alignment.
- [complete] Verify all root-cause acceptance gates and close out.
- [complete] Entity residual maintenance leaves and warning-free rollout enforcement.

## Decisions

- User approved execution after the discussion-only audit; this phase now applies bounded root-cause fixes.
- Do not propose a new architecture unless local evidence shows the current mechanism lacks the needed capability.
- Prefer repository gates and latest evidence files over memory or broad guesses.
- Include residual symptoms, why existing mechanisms missed them, and minimal repair actions for each material issue.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---|---|
| First parser-check one-liner used an uninitialized `[ref]$parseErrors` variable and reported empty paths | 1 | Re-run parser check with initialized token/error variables before using the result. |
| `checkpoint -Risk` was ambiguous against current RCCP params | 1 | Re-ran with `-RiskClass RISKY`; added command-template-lint coverage for ambiguous `-Risk`. |
| `action-reference-surface-check` initially treated `help` as an unavailable ordinary action | 1 | Kept `help` as an entry special command and excluded it from ordinary action-reference matching. |
