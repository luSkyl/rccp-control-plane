# RCCP Control Plane

Evidence-first repository control plane for AI agents, multi-session coding,
and auditable automation.

RCCP is designed for repositories where humans, scripts, and AI agents all
touch the same workspace. It provides one command entry, policy-backed task
routing, file-level ownership, admission checks, closeout evidence, and
machine-readable JSON artifacts.

## Status

This repository is a private staging extraction. It is not ready to publish
until `tools/sanitize-check.ps1 -Strict` passes and the quickstart works in an
empty repository.

## Core Ideas

- `rccp.ps1` is the only command entry.
- Runtime authority comes from control-plane phase, writer lanes, checkpoint
  ledger, pending issue state, ownership, and staged scope.
- `activeTask` is treated as a legacy drift signal, not authority.
- Every meaningful action should leave compact evidence under `evidence/` or a
  project-local equivalent.
- Project-specific behavior belongs in adapters and policy overrides, not in
  RCCP core.

## Quickstart

From this repository:

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action help
pwsh -NoProfile -File .\tools\sanitize-check.ps1 -Strict
```

Install into another repository:

```powershell
pwsh -NoProfile -File .\install.ps1 -TargetRoot C:\path\to\repo
cd C:\path\to\repo
pwsh -NoProfile -File .\rccp.ps1 -Action help
```

## Repository Layout

```text
scripts/rccp/      RCCP thin entry and PowerShell modules
scripts/help/      Canonical long-form command help
policies/          Policy bundle, dispatch map, rollout manifest
docs/治理/策略/    Compatibility policy path used by the current PowerShell core
schemas/           Public machine-readable contracts
adapters/          Optional project profiles
examples/          Minimal adopter repositories
tools/             Staging and release hygiene utilities
evidence/latest/   Local staging evidence, ignored by git
```

## Release Rule

Do not make this repository public until all of these are true:

1. Sanitization has zero hits.
2. Empty-repo installation works.
3. `admission`, `ownership`, `closeout`, `evidence`, and `policy` concepts are
   documented.
4. Business project names, local machine paths, secrets, and historical incident
   details are absent from public files.
