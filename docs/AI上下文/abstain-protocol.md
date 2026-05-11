---
title: Abstain Protocol
status: active
owner: governance-owner
updated_at: 2026-05-11
source_path: docs/AI上下文/abstain-protocol.md
confidence: high
---

# Abstain Protocol

Abstain prevents an LLM from filling evidence gaps with memory or inference.

## Trigger Conditions

The answer path must abstain when:

- no relevant `source_path` exists;
- evidence is stale, low confidence, or conflicting;
- retrieval cannot prove `indexVersion` or `sourceFingerprint`;
- sensitive content, credentials, or irreversible operations are involved;
- the user asks whether something is enabled or available without fresh
  verification;
- current runtime evidence contradicts long-lived notes.

## Response Shape

```text
Evidence is insufficient to confirm.
Minimal next step: <one command, file, or user action>
```

The response may add the blocked reason and the missing evidence path, but it
must not invent a conclusion.

## Evidence Rules

An evidence-backed answer must cite `source_path` or a generated evidence file.
If a retrieved fact lacks metadata, it can be listed as blocked context but must
not support the conclusion.
