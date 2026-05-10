# Findings

## Baseline

- Current HEAD before this task: `67eca34 Sync memory layer and registry checks`.
- Prior `action-registry-check-latest.json` reported `registeredActionCount=91` and `missingScriptCount=84`.
- `existing-capability-probe` was registered but unavailable because the leaf script was absent from this staging extraction.

## Root Cause

The dispatch registry describes a broader control-plane surface than the current staging repository physically ships. Without an explicit distribution profile, checks cannot distinguish expected staging omissions from release defects.

## Implemented Resolution

- Added `distributionProfile.name=staging-extraction` with `15` required leaf actions.
- Upgraded `action-registry-check` so default strict mode enforces required leaf coverage and `-RequireAllLeafScripts` enforces full-kit coverage.
- Upgraded `leaf-contract-check` to use the same distribution profile boundary.
- Restored P0 governance leaves: existing capability probe/shape check, project onboarding/governance, kit compatibility, and rollout checks.
- Updated README and help text to document staging versus full-kit validation.

## Verification

- `action-registry-check -Strict`: PASS with `missingRequiredScriptCount=0`.
- `leaf-contract-check -Strict`: PASS across required leaf actions.
- `memory-layer-contract-check -Strict`: PASS.
- `thin-entry-check -Strict`: PASS.
- `project-governance-check -Strict`: PASS.
- `rccp-kit-compat-check -Strict`: PASS.
- `rccp-kit-rollout-check -Strict`: PASS.
- `tools/sanitize-check.ps1 -Strict`: PASS.
