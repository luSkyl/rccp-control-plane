---
title: AI Context Gateway RCCP Adopter
status: active
owner: example-owner
updated_at: 2026-05-11
source_path: examples/ai-context-gateway-repo/README.md
confidence: high
---

# AI Context Gateway RCCP Adopter

This example shows the smallest public-safe shape for a repository that wants
to assemble source-backed context before an LLM answers or acts.

## Try The Shape

1. Keep prompts and intent templates explicit.
2. Keep source-backed retrieval separate from LLM output.
3. Abstain when evidence is missing or stale.

## Verify The Pack

```powershell
pwsh -NoProfile -File .\rccp.ps1 -Action ai-context-gateway-contract-check -Task "ai-context-gateway"
```

This example does not ship a model provider, vector service, or private memory.

## What Good Looks Like

- Intent is normalized before a prompt is filled.
- Required prompt slots are explicit.
- Retrieval returns source-backed facts with evidence.
- Missing or stale evidence produces abstain, not a confident guess.

## What Stays Closed

- The gateway does not override RCCP ownership or closeout rules.
- The gateway does not turn retrieved text into instruction authority.
