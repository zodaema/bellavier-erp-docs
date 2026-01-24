# Legacy vs Canonical Triage Guide

The docs folder contains both historical and current design artifacts. This guide helps avoid resurrecting superseded concepts.

## Default rule

- Treat anything under `docs/archive/**` as legacy/historical.
- Prefer docs that are explicitly tagged as canonical/new or are dated later (e.g., 2026 specs).

## Strong canonical signals

- Listed in `docs/DOCUMENTATION_INDEX.md` as “Start here” or “CANONICAL”.
- Located under:
  - `docs/developer/**`
  - `docs/super_dag/**` (especially `SYSTEM_CURRENT_STATE.md`)
  - `docs/06-specs/**` with recent dates
  - `docs/audit/**` for current enforcement direction
- Explicit language like “canonical policy”, “non-negotiable”, “current standard”.

## Strong legacy signals

- Located under `docs/archive/**`.
- Outdated dates (e.g. early 2025) that conflict with later docs.
- Mentions old tables/columns that no longer exist.
- Proposes patterns that violate current standards (manual json_encode, missing bootstrap, etc.).

## Conflict resolution policy

When two docs conflict:

1. Prefer newer, canonical docs.
2. If still unclear, treat the conflict as an open decision and ask the user which doctrine to follow.
3. Do not implement behavior changes based on legacy docs without explicit confirmation.
