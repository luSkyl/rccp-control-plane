---
title: Java + Vue RCCP Adopter
status: active
owner: example-owner
updated_at: 2026-05-11
source_path: examples/java-vue-repo/README.md
confidence: high
---

# Java + Vue RCCP Adopter

This example shows the smallest public-safe shape for a repository that wants
to govern a Java backend and Vue frontend under one adapter pack.

## Try The Shape

1. Add backend build and test gates.
2. Add frontend build and test gates.
3. Add migration checks.
4. Keep release readiness as the pack boundary, not RCCP core changes.

## Verify The Pack

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action java-vue-contract-check -Task "java-vue"
```

This example does not change RCCP ownership, closeout, or task state rules.
