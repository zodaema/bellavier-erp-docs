# Phase 2 — CUT Yield Emits POOL_TRANSFORM (Pool SSOT)

## Scope

This change implements **Phase 2 only**:

- CUT behavior only
- Transform only (no allocation, no binding)
- Emits `POOL_TRANSFORM` into Pool SSOT via `PoolEventService->applyEvent(...)`
- `token_id` for `POOL_TRANSFORM` is **always NULL**
- No changes to classic/oem paths, Graph Designer, Work Queue, or any allocation logic

## Canonical Mapping

When `cut_session_end` completes successfully, emit:

- `event_type`: `POOL_TRANSFORM`
- `pool_mode`: `transform`
- `product_model_id`: `job_ticket.id_product`
- `bom_version_id`: `job_ticket.bom_version_id` (DC-07 pinned)
- `component_code`: resolved from CUT session (`cut_session.component_code`, uppercased)
- `state`: `cut_ready`
- `delta_qty`: yield quantity (`qty_cut`) formatted as string with **6 decimals**
- `reason_code`: `CUT_YIELD`
- `actor_id`: operator id
- `token_id`: `NULL`
- `occurred_at`: server time (uses session end time when available)
- `event_group_id` (optional): session UUID when present

## Hard-fail (Hatthasilpa/Hybrid Only)

In `handleCutSessionEnd(...)`:

- If `job_ticket.production_type` is `hatthasilpa` or `hybrid`
- And `job_ticket.bom_version_id` is `NULL` / `0`

Then the handler **fails before side effects** (before ending the session / emitting pool events) with:

- `error`: `CUT_POOL_BOM_VERSION_REQUIRED`
- `app_code`: `CUT_500_POOL_BOM_VERSION_REQUIRED`

## Idempotency Strategy

Deterministic, stable keys (no `time()` / random):

- CUT session end (CutSessionService):
  - `cut_session_end:{cut_session_id}`
- Yield event (token_event):
  - `cut_end:{cut_session_id}`
- Pool transform event (pool_event):
  - `pool_transform:cut_end:{cut_session_id}:{component_code}:cut_ready`

This ensures retry of the same request does not double-apply `pool_balance`.

## Files Changed

- `source/BGERP/Dag/BehaviorExecutionService.php`
  - Surgical patch **inside** `handleCutSessionEnd(...)` only
- `tests/Integration/CutSessionEndEmitsPoolTransformTest.php`
  - New/updated integration coverage for Phase 2
- `docs/super_dag/04-implementation/PHASE2_CUT_YIELD_EMITS_POOL_TRANSFORM.md`

## PHPUnit

```bash
vendor/bin/phpunit --configuration phpunit.xml --testsuite Integration --filter CutSessionEndEmitsPoolTransformTest
```
