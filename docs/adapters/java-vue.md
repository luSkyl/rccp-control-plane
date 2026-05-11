---
title: Java + Vue Adapter Pack
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/adapters/java-vue.md
confidence: high
---

# Java + Vue Adapter Pack

This adapter pack productizes the common shape for repositories that pair a
Java backend with a Vue frontend and want RCCP to govern build, migration, and
release gates without changing RCCP core.

## Pack Boundary

The pack owns:

- backend build and test commands;
- frontend build and test commands;
- migration and database checks;
- release readiness gates for the adopter repository.

The pack does not own RCCP task state, ownership rules, or closeout rules.

## Required Shape

- guide: this document
- manifest: `adapters/java-vue.json`
- example repo: `examples/java-vue-repo`
- check script: `scripts/check-java-vue-contract.ps1`

## Runtime Order

```text
guide -> manifest -> example repo -> contract check -> dispatch -> CI -> rollout
```

## Public Verification

Run the pack check before release:

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action java-vue-contract-check -Task "release-readiness" -Strict
```

The pack is only considered productized when the source checkout and installed
kit both pass the same contract check.
