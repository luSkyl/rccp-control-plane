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

## Current Execution: continuous-kit-polish

Goal: keep polishing the staging kit toward a public, installable, evidence-credible RCCP surface by fixing one high-signal residual drift per loop.

- [complete] Start governed task, checkpoint, resume-check, and claim planning files.
- [complete] Probe existing capability and run minimal status/reference-surface baselines.
- [complete] Diagnose default `status` selecting a stale task when no `-Task` is supplied.
- [complete] Patch projection task selection to prefer the latest `updatedAt` task.
- [complete] Run parser and RCCP release-surface verification.
- [complete] Close out with ownership and final-answer evidence.

## Current Execution: evidence-path-cleanup-polish

Goal: remove evidence-path quoting drift from final recap evidence while keeping the closeout chain and public surface unchanged.

- [complete] Start governed task, checkpoint, resume-check, and claim planning files.
- [complete] Reproduce quoted `evidencePaths` in `final-recap-check` JSON using direct and entry invocations.
- [complete] Patch final recap path expansion to strip wrapper quotes after comma/semicolon splitting.
- [complete] Run focused regression and release-surface gates.
- [complete] Close out with final-answer evidence.

## Current Execution: recap-outdir-metadata-polish

Goal: make final recap machine-readable path metadata match the actual output directory for default and custom `-OutDir` runs.

- [complete] Start governed task, checkpoint, resume-check, and claim planning files.
- [complete] Reproduce custom `-OutDir` writing files to the custom location while summary metadata still pointed at the default docs directory.
- [complete] Patch summary `latestJson`, `latestMarkdown`, `taskJson`, and `taskMarkdown` fields to use actual output paths.
- [complete] Run default/custom OutDir regressions and release-surface gates.
- [complete] Close out with final-answer evidence.

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
| `checkpoint -RiskClass MEDIUM` used a non-existent risk class in this session | 1 | Re-ran checkpoint with the current allowed value `NORMAL`. |
| Parser/JSON sweep used an invalid regex path exclusion with trailing backslashes and Chinese path text | 1 | Re-run sweeps with literal path-fragment exclusions instead of regex. |
| `rg scripts/*.ps1` was passed as a literal Windows glob and failed | 1 | Re-ran targeted file reads directly and kept the fix scoped to the already identified recap script. |

## Current Execution: multi-agent-migration-closure

Goal: turn the existing sub-agent/runtime primitives into a public, evidence-gated multi-agent workflow without changing RCCP core ownership and closeout rules.

- [complete] Start governed task, checkpoint, resume-check, and ownership-claim.
- [complete] Add public multi-agent workflow docs, work-order schema, example repo, and contract check.
- [complete] Wire the new action into dispatch/help/README/release checklist/CI/install/rollout surfaces.
- [complete] Run focused contract and release gates, then close out with final-answer evidence.

## Current Execution: adapter-pack-factory-closure

Goal: productize reusable adapter packs by wiring source-surface docs, install smoke, CI, and rollout checks so the shared pack shape works in both the repo checkout and the installed kit.

- [complete] Start governed task, checkpoint, resume-check, and ownership-claim.
- [complete] Add install support for `adapters/` and `examples/`, and wire `adapter-pack-factory-check` into CI and rollout gates.
- [complete] Make the pack factory check tolerate installed-kit runs while still enforcing source-surface release links in the repo checkout.
- [complete] Re-run parser, action-reference, action-registry, leaf-contract, project, compatibility, rollout, and sanitize checks.
- [complete] Repair the existing-capability probe script that parser sweep surfaced as broken.
- [complete] Close out with final-answer evidence and latest rollout evidence.

## Current Execution: adapter-pack-productization-closure

Goal: convert the remaining placeholder adapter families into concrete packs and wire their checks into the same release and rollout chain.

- [complete] Start governed task, checkpoint, resume-check, and ownership-claim.
- [complete] Add concrete pack guides, manifests, example repos, and contract checks for Java + Vue, Docs-Only, and AI Context Gateway.
- [complete] Wire the new pack checks into README, release checklist, help, CI, dispatch, kit manifest, and rollout evidence.
- [complete] Update the adapter index and pack-factory validation to reflect the newly productized families.
- [complete] Run parser/JSON, pack, registry, leaf-contract, project, compatibility, command-template, sanitize, and rollout checks.
- [complete] Close out with final-answer evidence and latest rollout evidence.

## Current Execution: context-productization-polish

Goal: unify the Obsidian, memory, AI context gateway, multi-agent, and adapter-pack surfaces into one ordered adoption path, then close the release surface on the new productized wording.

- [complete] Add a unified context-and-coordination path doc and link it from the adapter and memory surfaces.
- [complete] Reorder README and release-checklist verification paths into a more explicit release sequence.
- [complete] Upgrade the example repos and template to describe pass/fail-closed behavior and the release-checklist step.
- [complete] Sync the adapter-pack factory doc and check script to the new template lifecycle wording.
- [complete] Add installed-kit `thin-entry-check` smoke coverage and keep the public action name consistent.
- [complete] Run parser, adapter-pack-factory, memory, Obsidian, AI context gateway, multi-agent, release-rollout, and sanitize checks.
- [complete] Refresh the latest evidence and confirm the rollout chain is semantically PASS.

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| checkpoint parameter '-Risk' ambiguous | bootstrap attempt 1 | Use '-RiskClass NORMAL' for checkpoint commands. |
| checkpoint missing '-Task' | bootstrap attempt 2 | Include '-Task perfect-solution-layered-protocol' for checkpoint commands. |

## perfect-solution-layered-protocol Progress
- [complete] Locate existing capability probe and answer shape scripts.
- [complete] Add layered response-mode metadata to probe.
- [complete] Add layered protocol requirements to answer-shape check.
- [complete] Update README capability map.
- [in_progress] Run targeted gates and closeout.
- [complete] Closeout-atomic passed with final-reply evidence.
