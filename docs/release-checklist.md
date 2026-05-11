# Release Checklist

This staging repository can be made public only after these checks pass.

## Required

- `pwsh -NoProfile -File .\rccp.ps1 -Action help`
- `pwsh -NoProfile -File .\rccp.ps1 -Action task-start -Task "staging smoke" -TargetPaths "README.md"`
- `pwsh -NoProfile -File .\rccp.ps1 -Action ownership-check -Task "staging smoke"`
- `pwsh -NoProfile -File .\rccp.ps1 -Action command-template-lint -Task "staging smoke" -CommandText "pwsh -NoProfile -File .\rccp.ps1 -Action rccp-leaf-contract-check -Task \`"staging smoke\`" -RequireAllLeafScripts -Strict" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action action-reference-surface-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action action-registry-check -Task "staging smoke" -RequireAllLeafScripts -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action rccp-leaf-contract-check -Task "staging smoke" -RequireAllLeafScripts -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action project-onboard -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action project-governance-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action rccp-kit-rollout-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\tools\sanitize-check.ps1 -Strict`
- PowerShell parser check for every `*.ps1` and `*.psm1`
- Empty-repo install smoke through `install.ps1`, including installed
  `action-registry-check -RequireAllLeafScripts -Strict`

## Public Boundary

Commit source, policies, schemas, adapters, examples, and docs.

Do not commit generated runtime state:

- `.claude/`
- `.rccp/`
- `docs/治理/最新态/`
- `evidence/latest/`

## Follow-Up Before Public GitHub Release

- Decide whether compatibility paths under `docs/治理/策略` should remain or be replaced by `policies/` in a later breaking release.
- Add an English-only policy profile after the first adopter repository validates the extracted core.
