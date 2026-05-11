---
title: Docs-Only Adapter Pack
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/adapters/docs-only.md
confidence: high
---

# Docs-Only Adapter Pack

This adapter pack productizes repositories whose main surface is Markdown,
policy files, change logs, and operational guidance.

## Pack Boundary

The pack owns:

- documentation structure and review flow;
- policy and checklist alignment;
- doc release readiness and archival rules.

The pack does not own application build pipelines, backend services, or RCCP
core behavior.

## Required Shape

- guide: this document
- manifest: `adapters/docs-only.json`
- example repo: `examples/docs-only-repo`
- check script: `scripts/check-docs-only-contract.ps1`

## Runtime Order

```text
guide -> manifest -> example repo -> contract check -> dispatch -> CI -> rollout
```

## Public Verification

Run the pack check before release:

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action docs-only-contract-check -Task "release-readiness" -Strict
```

The pack is only considered productized when the source checkout and installed
kit both pass the same contract check.
