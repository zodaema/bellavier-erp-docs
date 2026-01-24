---
name: bellavier-playbook
description: Loads the canonical Bellavier ERP development playbook (architecture + safety rails + CUT time doctrine) and provides a triage guide to avoid legacy/archived docs.
---

## How to use this skill

When this skill is invoked, you must:

1. Read the supporting resources in this folder first:
   - `CANONICAL_INDEX.md`
   - `DOCTRINES_SUMMARY.md`
   - `CUT_TIME_DOCTRINE.md`
   - `LEGACY_TRIAGE.md`

2. Follow the reading order and treat the “canonical” documents as source of truth.

3. If a doc conflicts with another doc:
   - Prefer the newest, explicitly-canonical documents.
   - Treat `docs/archive/**` as legacy/historical unless explicitly confirmed by the user.

4. Before proposing any implementation that changes production behavior:
   - Confirm required safety rails are met (bootstrap/rate limit/validation/CSRF/idempotency/ETag/maintenance/execution_ms).
   - Prefer staged rollouts and feature flags.

## Canonical docs (read from repo as needed)

- `docs/developer/01-policy/DEVELOPER_POLICY.md`
- `docs/developer/02-quick-start/IMPLEMENTATION_EVERY_TIME_CHECKLIST.md`
- `docs/developer/04-api/03-api-standards.md`
- `docs/super_dag/SYSTEM_CURRENT_STATE.md`
- `docs/ROADMAP_LUXURY_WORLD_CLASS.md`
- `docs/06-specs/PUBLISHED_IMMUTABLE_CONTRACT.md`
- CUT time doctrine:
  - `docs/06-specs/TIME_LAYERS_MICRO_LEDGER_TO_MAINSTREAM_PROJECTION_SPEC_2026_01_15.md`
  - `docs/06-specs/CUT_TIME_IMPLEMENTATION_PLAYBOOK_2026_01_15.md`
  - `docs/06-specs/CUT_INTEGRATION_AUDIT_2026_01_15.md`

## Output expectations

When asked to design or implement:

- Start with a short “current state” recap and the SSOT assumptions.
- Provide a minimal-risk plan.
- Call out any conflicts/uncertainties and ask for confirmation.
- Keep changes small, testable, and reversible.
