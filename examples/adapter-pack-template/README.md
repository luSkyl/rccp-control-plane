# Adapter Pack Template

This example shows the minimum shape every RCCP adapter pack should copy.

## Files

- `docs/adapters/<pack>.md`
- `adapters/<pack>.json`
- `examples/<pack>-repo/`
- `scripts/check-<pack>.ps1`

## Template Loop

```text
guide -> manifest -> example -> check -> dispatch -> CI -> release checklist -> rollout
```

The pack should describe its own scope, required actions, and evidence shape
without changing RCCP core rules.

## Copy Checklist

1. Replace the placeholder pack name.
2. Replace the placeholder stack tags.
3. Replace the required actions with real pack actions.
4. Replace the example root with the adopter-facing repository path.
5. Replace the check script path with the concrete contract check.
6. Register the pack in dispatch, CI, release checklist, and rollout gates.
7. Remove all placeholder language before shipping the pack.
