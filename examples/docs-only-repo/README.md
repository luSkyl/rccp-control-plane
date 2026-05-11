---
title: Docs-Only RCCP Adopter
status: active
owner: example-owner
updated_at: 2026-05-11
source_path: examples/docs-only-repo/README.md
confidence: high
---

# Docs-Only RCCP Adopter

This example shows the smallest public-safe shape for a repository that mainly
contains Markdown, policy files, and operational documentation.

## Try The Shape

1. Keep the pack focused on docs governance and review flow.
2. Keep application build gates out of the pack boundary.
3. Use release readiness checks for documentation integrity and policy drift.

## Verify The Pack

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action docs-only-contract-check -Task "docs-only"
```

This example does not add backend or frontend build assumptions.
