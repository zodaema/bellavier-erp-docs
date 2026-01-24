# Phase 3 — ASSEMBLY emits POOL_ALLOCATE (bookkeeping-only)

## Canonical laws → implementation mapping

### LAW-01 (Token SSOT)
- Token remains authoritative for lifecycle/routing/execution.
- Allocation is implemented as a bookkeeping side effect only and does not alter token routing decisions.

### LAW-02 (Pool = ledger only)
- Pool is treated as an availability ledger.
- Allocation failures do not block execution.

### LAW-03 (Single pool state)
- Allocation uses only `state='cut_ready'`.

### LAW-04 (No stage pool states)
- No `skived_ready`, `edged_ready`, or other stage states are emitted.

### LAW-05 (Explicit allocation only)
- Pool decrement happens only via `POOL_ALLOCATE`.
- Allocation is emitted at `assembly_start` only.

### LAW-06 (No reconciliation)
- No implicit pool ↔ token reconciliation is introduced.
- No pool decrement on token spawn.

## Implementation location (mandatory)

- Server-side hook: `BGERP\Dag\BehaviorExecutionService::handleSinglePieceStart(...)`
- Trigger: `behavior_code='ASSEMBLY'` and action routed to `handleSinglePieceStart()`.

## Allocation rules

### Input source of truth
Pinned snapshot only:

`job_ticket.product_revision.snapshot_json → structure.component_requirements[]`

For each component requirement item:
- `is_required === true`
- `component_code`
- `default_qty`

### Emission: one POOL_ALLOCATE per component
For each required component, emit one pool event with:

- `event_type='POOL_ALLOCATE'`
- `pool_mode='allocate'`
- `product_model_id = job_ticket.id_product`
- `bom_version_id = job_ticket.bom_version_id`
- `component_code = component_code`
- `state='cut_ready'`
- `delta_qty = -default_qty` formatted with 6 decimals
- `token_id = token_id`
- `reason_code='ASSEMBLY_ALLOCATE'`
- `actor_id = worker_id`
- `occurred_at = now()`
- `idempotency_key = "pa:asm:{tokenId}:{componentCode}"`

## Failure semantics

### Pool insufficient
If `PoolEventService` returns `POOL_409_NEGATIVE`:
- Continue execution.
- Return response fields:
  - `allocation_ok=false`
  - `warnings=["POOL_INSUFFICIENT"]`

### bom_version_id missing
If `job_ticket.bom_version_id` is missing/NULL:
- Skip allocation.
- Continue execution.
- Return response fields:
  - `allocation_skipped=true`
  - `reason="BOM_VERSION_MISSING"`

## Why allocation is non-blocking
- Pool is an availability ledger and not SSOT for execution correctness.
- Blocking assembly on pool would make pool an execution gate, violating LAW-01/02.

## Why pool is not SSOT
- Pool represents aggregated availability for planning/reporting and bookkeeping.
- Token lifecycle and routing remain authoritative.

## Why only cut_ready exists
- Pre-assembly process states (SKIVE/EDGE/etc.) are managed by token routing and work sessions.
- Pool state does not model stages.
