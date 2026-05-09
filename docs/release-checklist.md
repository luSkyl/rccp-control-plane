# Release Checklist

This staging repository can be made public only after these checks pass.

## Required

- `pwsh -NoProfile -File .\rccp.ps1 -Action help`
- `pwsh -NoProfile -File .\rccp.ps1 -Action task-start -Task "staging smoke" -TargetPaths "README.md"`
- `pwsh -NoProfile -File .\rccp.ps1 -Action ownership-check -Task "staging smoke"`
- `pwsh -NoProfile -File .\tools\sanitize-check.ps1 -Strict`
- PowerShell parser check for every `*.ps1` and `*.psm1`
- Empty-repo install smoke through `install.ps1`

## Public Boundary

Commit source, policies, schemas, adapters, examples, and docs.

Do not commit generated runtime state:

- `.claude/`
- `.rccp/`
- `docs/治理/最新态/`
- `evidence/latest/`

## Follow-Up Before Public GitHub Release

- Add CI workflow once the target GitHub repository exists.
- Decide whether compatibility paths under `docs/治理/策略` should remain or be replaced by `policies/` in a later breaking release.
- Add an English-only policy profile after the first adopter repository validates the extracted core.
