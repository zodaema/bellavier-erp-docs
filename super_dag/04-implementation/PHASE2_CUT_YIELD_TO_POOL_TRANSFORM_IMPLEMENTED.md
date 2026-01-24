---
description: Phase 2 - CUT yield emits POOL_TRANSFORM
---

# Phase 2 — CUT yield → POOL_TRANSFORM (Implemented)

## Scope

This implementation is **Phase 2 only**:

- Emits `POOL_TRANSFORM` on `CUT` `cut_session_end`.
- Uses the Phase 1 Pool foundation (`pool_event`, `pool_balance`) as SSOT for pre-binding quantities.
- Does **not** change token routing authority, queue logic, binding/allocation, or introduce new tables.

## Canonical inputs

- **product_model_id:** `job_ticket.id_product`
- **bom_version_id (SSOT):** `job_ticket.bom_version_id`
- **component_code:** `UPPER(cut_session.component_code)` (already used in existing CUT yield payload)
- **state:** `cut_ready`
  - Canonical reference: `docs/super_dag/01-canonical/HATTHASILPA_NODE_POOL_STATE_MAPPING_CANONICAL.md` (CUT output state)

## Behavior rules

- Emits pool events only when `job_ticket.production_type` is `hatthasilpa` or `hybrid`.
- Hard-fails if `job_ticket.bom_version_id` is missing for `hatthasilpa/hybrid`.
- `token_id` is always `NULL` for `POOL_TRANSFORM` (pre-binding, no ownership links).

## Idempotency

### CUT session end

- `cut_session_end` uses deterministic idempotency key:
  - `cut_session_end:{cut_session_id}` if the caller does not provide one.

### Token event (NODE_YIELD)

- `token_event.idempotency_key`:
  - `yield_cut_session_end:{cut_session_id}`

### Pool event (POOL_TRANSFORM)

- `pool_event.idempotency_key`:
  - `cut_end_pool:{cut_session_id}`

These keys ensure retries do not double-apply.

## Files changed

- `source/BGERP/Dag/BehaviorExecutionService.php`
  - `handleCutSessionEnd` now emits `POOL_TRANSFORM` via `PoolEventService`.
  - `NODE_YIELD` idempotency key is stable.
- `source/BGERP/Dag/CutSessionService.php`
  - `endSession` idempotency is replay-safe (idempotent ENDED detection before status validation).

## Tests

- `tests/Integration/CutSessionEndEmitsPoolTransformTest.php`
  - Asserts `POOL_TRANSFORM` is written with `token_id IS NULL`.
  - Asserts `pool_balance.quantity_on_hand` increases with 6-decimal formatting.
  - Asserts idempotent replay does not double-apply.
