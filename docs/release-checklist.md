# Release Checklist

This staging repository can be made public only after these checks pass.

## Required

- `pwsh -NoProfile -File .\rccp.ps1 -Action help`
- `pwsh -NoProfile -File .\rccp.ps1 -Action task-start -Task "staging smoke" -TargetPaths "README.md"`
- `pwsh -NoProfile -File .\rccp.ps1 -Action ownership-check -Task "staging smoke"`
- `pwsh -NoProfile -File .\rccp.ps1 -Action command-template-lint -Task "staging smoke" -CommandText "pwsh -NoProfile -File .\rccp.ps1 -Action rccp-leaf-contract-check -Task \`"staging smoke\`" -RequireAllLeafScripts -Strict" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action action-reference-surface-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action action-registry-check -Task "staging smoke" -RequireAllLeafScripts -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action thin-entry-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action rccp-leaf-contract-check -Task "staging smoke" -RequireAllLeafScripts -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action obsidian-second-brain-contract-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action memory-layer-contract-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action memory-source-contract-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action memory-ingest-plan -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action memory-recall-check -Task "staging smoke" -EvalPath "examples/obsidian-second-brain-repo/eval-cases/memory-recall-cases.json" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action abstain-shape-check -Task "staging smoke" -AnswerPath "examples/obsidian-second-brain-repo/eval-cases/abstain-answer.md" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action ai-context-gateway-contract-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action adapter-pack-factory-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action java-vue-contract-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action docs-only-contract-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action multi-agent-contract-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action project-onboard -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action project-governance-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\rccp.ps1 -Action rccp-kit-rollout-check -Task "staging smoke" -Strict`
- `pwsh -NoProfile -File .\tools\sanitize-check.ps1 -Strict`
- PowerShell parser check for every `*.ps1` and `*.psm1`
- Empty-repo install smoke through `install.ps1`, including installed
  `action-registry-check -RequireAllLeafScripts -Strict`,
  `thin-entry-check -Strict`, and
  `adapter-pack-factory-check -Strict`, `java-vue-contract-check -Strict`,
  `docs-only-contract-check -Strict`, and
  `ai-context-gateway-contract-check -Strict`

## Public Boundary

Commit source, policies, schemas, adapters, examples, and docs.

Do not commit generated runtime state:

- `.claude/`
- `.rccp/`
- `docs/治理/最新态/`
- `evidence/latest/`

Public adapter docs under `docs/adapters/` and `docs/AI上下文/` are part of the
source surface and should be committed.
Public adapter pack factory docs under `docs/adapters/adapter-pack-factory.md`
are part of the source surface and should be committed.
Public Java + Vue adapter docs under `docs/adapters/java-vue.md` are part of
the source surface and should be committed.
Public docs-only adapter docs under `docs/adapters/docs-only.md` are part of
the source surface and should be committed.
Public AI context gateway docs under `docs/adapters/ai-context-gateway.md` are
part of the source surface and should be committed.
Public multi-agent workflow docs under `docs/multi-agent-workflow.md` are part
of the source surface and should be committed.
Public context-and-coordination docs under
`docs/adapters/context-and-coordination.md` are part of the source surface and
should be committed.

## Follow-Up Before Public GitHub Release

- Decide whether compatibility paths under `docs/治理/策略` should remain or be replaced by `policies/` in a later breaking release.
- Add an English-only policy profile after the first adopter repository validates the extracted core.
