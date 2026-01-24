# CUT Time Doctrine (Micro Ledger → Mainstream Projection)

This doctrine exists to prevent the system from drifting into “two competing sources of truth” for time.

## Non-negotiables

- Micro ledger is authoritative; projection is rebuildable.
- CUT SSOT is `cut_session`.
- Legacy `token_work_session` must not become authoritative for CUT timing.
- Projections must not be used for authorization/punishment.

## Canonical projection output (`time_summary`)

For each CUT token+node:

- `presence_seconds`
- `effort_seconds`
- `first_started_at`
- `last_activity_at`

## Rollout strategy (minimal-first)

- Phase 1: add `time_summary` to API payload for CUT only (no UI change yet).
- Phase 2: choose compute mode:
  - Mode A: on-read compute (correctness-first)
  - Mode B: summary table (fast reads, needs rebuild tooling)
- Phase 3: UI consumes projection for CUT only; avoid double timers.

## References

- `docs/06-specs/TIME_LAYERS_MICRO_LEDGER_TO_MAINSTREAM_PROJECTION_SPEC_2026_01_15.md`
- `docs/06-specs/CUT_TIME_IMPLEMENTATION_PLAYBOOK_2026_01_15.md`
- `docs/06-specs/CUT_INTEGRATION_AUDIT_2026_01_15.md`
