# Evidence

RCCP evidence should be compact, current, and joinable across actions.

Recommended evidence card shape:

```json
{
  "verdict": "PASS",
  "category": "admission",
  "reason": "no active writer lanes",
  "nextCommand": "",
  "evidencePath": "evidence/latest/admission-latest.json"
}
```

Latest evidence is for fast operator feedback. Historical evidence should live
in timestamped files or an event store when a project needs audit replay.
