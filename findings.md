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

## Continuous Kit Polish Findings

- Existing-capability probe for the polish loop returned `EXISTING_CAPABILITY_CONFIRMED`, so the next improvement should refine the current RCCP runtime instead of adding a new control plane.
- `rccp status -Task "continuous-kit-polish"` selected the intended task, but plain `rccp status` initially selected older task `root-cause-closure-protocol-hardening`.
- The projection already contained `continuous-kit-polish` with the latest `updatedAt`, so the residual was not missing events; it was default selection by hashtable value order in `Publish-RccpEvidenceCard` and `Publish-RccpExecutionCard`.
- The minimal repair is a shared projection task selector that honors an explicit `-Task` and otherwise selects the task with the newest `updatedAt`.
- After the repair, plain `rccp status` and task-scoped `rccp status -Task "continuous-kit-polish"` both report `continuous-kit-polish`.

## Evidence Path Cleanup Findings

- `rccp-closeout-sidecar-latest.json` already stores closeout `evidencePaths` without embedded quotes.
- `final-recap-check-latest.json` stored the same style of paths as `"docs/治理/最新态/..."` with literal quote characters, so the drift was in final recap path expansion rather than the core sidecar path model.
- Direct `check-final-recap-check.ps1 -EvidencePaths "a","b"` and routed `rccp.ps1 -Action final-recap-check -EvidencePaths "a","b"` both reproduced quoted JSON evidence paths before the fix.
- `Expand-PathList` now strips repeated wrapper single/double quotes after splitting on comma or semicolon.
- Focused after-fix checks show direct, routed, and deliberately nested-quoted invocations all emit clean evidence path values.

## Recap OutDir Metadata Findings

- `final-recap-check -OutDir evidence/latest/tmp-recap-outdir-before` wrote output files to the custom directory but the summary fields `latestJson`, `latestMarkdown`, `taskJson`, and `taskMarkdown` still pointed at `docs/治理/最新态/...`.
- Default `OutDir` should continue to self-report `docs/治理/最新态/...`, while custom `OutDir` should self-report the actual custom output paths.
- `final-recap-check` now derives those four summary fields from the actual output path variables and normalizes path separators to `/`.
- Focused after-fix checks confirm custom `OutDir` reports `evidence/latest/tmp-recap-outdir-after/...` and default `OutDir` still reports `docs/治理/最新态/...`.

## Multi-Agent Closure Findings

- The repository already had sub-agent primitives before this round: `execution-card`, `lease-acquire`, `ownership-claim`, `Test-RccpWorkOrderContract`, and the `rccp-agent-task-graph-schema` invariant `sub_agent_must_not_closeout`.
- The missing layer was public packaging, not runtime capability: no dedicated multi-agent workflow doc, work-order schema, example repo, or dedicated contract check existed on the public surface.
- The new public boundary should stay evidence-first and fail closed on unauthorized paths or sub-agent closeout.
- Installing the new workflow docs into `.rccp/docs` is useful for adopter visibility, but the example repo remains a source-surface artifact rather than a shipped runtime dependency.

## Adapter Pack Factory Closure Findings

- The pack factory now has a public guide, schema, template manifest, example repo, contract check, release checklist entry, CI gate, and rollout evidence path.
- Empty-target install smoke initially failed because the installed bundle did not include the source repo's root `README`, release checklist, or CI workflow; the fix was to keep those as source-surface checks and skip them when the pack check runs inside an installed kit.
- `install.ps1` now copies `adapters/` and `examples/` so the installed kit can validate the adapter-pack template shape instead of only the docs shell.
- The parser sweep surfaced a broken `scripts/check-existing-capability-probe.ps1`; it was rewritten into a clean probe so the repo-wide syntax check is green again.
- `closeout-atomic` now passes with the updated final answer draft and the task is fully closed out.

## Adapter Pack Productization Findings

- `java-vue`, `docs-only`, and `ai-context-gateway` were the remaining useful families that had design or placeholder surfaces but not full pack productization.
- The new pack guides and manifests turn those families into the same guide/manifest/example/check shape as the existing factory and Obsidian/multi-agent surfaces.
- The adapter index, README, release checklist, help text, CI workflow, kit manifest, and rollout checks now name the new pack checks explicitly so they are not just documented but enforceable.
- `rccp-kit-rollout-check` now includes the new pack evidence paths and runs the new pack checks in the install smoke.
- `closeout-atomic` now passes with the English recap-field draft for the current productization task.

## Context Productization Findings

- The repository now has a unified `docs/adapters/context-and-coordination.md` path that ties together Obsidian, memory, AI context gateway, and multi-agent adoption.
- `docs/adapters/README.md`, `README.md`, `docs/release-checklist.md`, `docs/memory-layer.md`, `docs/AI上下文/README.md`, and `docs/multi-agent-workflow.md` now point at the same ordered context/coordination path instead of presenting those surfaces as separate islands.
- The example repos now state both the expected pass behavior and the fail-closed boundary, which makes the adapter surfaces easier to adopt without guessing the hidden rules.
- The adapter-pack factory doc and template README now include `release checklist` in the productization loop, and the check script accepts the updated lifecycle wording.
- The release checklist now uses the public action name `thin-entry-check`, and `rccp-kit-rollout-check` now runs that check inside the installed-kit smoke instead of relying only on source checkout evidence.
- A parallel rollout run briefly saw stale adapter-pack-factory evidence, but rerunning the factory check sequentially refreshed the latest evidence and restored rollout PASS.

## perfect-solution-layered-protocol
- Existing probe only had binary delta/greenfield behavior; added response-mode signals for v1 delta, v2 external/GitHub authorization, and v3 greenfield authorization.
- Answer shape check now treats layered answers as stricter: v1/v2/v3, authorization, rollback/risk, and acceptance gate must be present when layered protocol appears.

## perfect-solution-v0-v3-template Findings

- Root cause: the previous answer-shape governance allowed a generic nine-section diagnosis layout, so "perfect solution" answers were not forced into the user's expected V0/V1/V2/V2.5/V3 visual structure.
- Minimal repair: reuse the tracked existing capability answer-shape checker instead of adding another untracked leaf script, and add a dedicated perfect-solution-answer-template-check action with PerfectSolutionV0V3 mode.
- Compatibility fix: template validation now accepts the user's Chinese section labels and keeps external/GitHub benchmarking authorization-aware instead of assuming every perfect方案 is greenfield.
- Guardrail: V3-B evidence requirements now trigger only when the final current status actually claims V3-B, so a V3-A/V3-B status legend does not falsely fail the template.
