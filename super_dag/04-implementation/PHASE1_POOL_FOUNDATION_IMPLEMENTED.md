# Phase 1 — Pool Foundation (Implemented)

## Scope

This document describes the Phase 1 implementation of the Hatthasilpa Pool Foundation.

Phase 1 provides:

- A tenant-scoped Pool snapshot table (`pool_balance`).
- An append-only Pool event ledger (`pool_event`).
- A single-writer service to mutate pool state via events only (`PoolEventService`).
- A minimal read service (`PoolReadService`).
- A read-only API endpoint to fetch pool snapshots (`hatthasilpa_pool_api.php`, action `pool_snapshot`).
- Minimal integration test coverage.

## Data model (tenant DB)

### Canonical PoolKey

Canonical PoolKey is implemented exactly as:

- `product_model_id`
- `bom_version_id`
- `component_code`
- `state`

### `pool_balance` (snapshot SSOT)

Migration:

- `database/tenant_migrations/2026_01_hatthasilpa_pool_foundation.php`

Key columns:

- `product_model_id` (int)
- `bom_version_id` (int)
- `component_code` (varchar(50))
- `state` (varchar(64))
- `quantity_on_hand` (decimal(18,6) unsigned, default `0.000000`)

Keys/indexes:

- Unique: `uq_pool_key (product_model_id, bom_version_id, component_code, state)`

Invariant:

- `quantity_on_hand` must never be negative.

### `pool_event` (append-only ledger)

Migration:

- `database/tenant_migrations/2026_01_hatthasilpa_pool_foundation.php`

Key columns:

- `event_type` enum: `POOL_TRANSFORM`, `POOL_MOVE`, `POOL_ALLOCATE`, `POOL_SCRAP`, `POOL_ADJUST`
- `pool_mode` enum: `transform`, `allocate`
- PoolKey columns: `product_model_id`, `bom_version_id`, `component_code`, `state`
- `delta_qty` decimal(18,6) (signed)
- `idempotency_key` varchar(64)
- `occurred_at` datetime
- `created_at` datetime

Keys/indexes:

- Unique: `uniq_pool_event_idempotency (idempotency_key)`
- Index: `idx_pool_event_pool_key (product_model_id, bom_version_id, component_code, state)`

## Services

### `BGERP\Service\PoolEventService`

File:

- `source/BGERP/Service/PoolEventService.php`

Purpose:

- Single writer for pool mutations.
- Enforces idempotency, row-locking, and non-negativity.

Contract:

- `applyEvent(array $event): array`

Behavior:

- Validates event fields (types, enums, max lengths).
- Enforces idempotency by `idempotency_key` lookup.
- Uses tenant DB transaction + row lock on the PoolKey row (`SELECT ... FOR UPDATE`).
- Rejects any mutation that would make the quantity negative (`POOL_409_NEGATIVE`).
- Inserts exactly one `pool_event` row per successful call.
- Updates exactly one `pool_balance` row per successful call.

Ordering:

- Durable ordering is via `id_pool_event` (auto-increment primary key).
- `occurred_at` is stored for audit/semantic time, but ordering for replay/audit is explicit and auditable.

### `BGERP\Service\PoolReadService`

File:

- `source/BGERP/Service/PoolReadService.php`

Minimal Phase 1 read contract:

- `getPoolBalanceByKey(int $productModelId, int $bomVersionId, string $componentCode, string $state): ?array`
- `listPoolBalance(array $filters = [], int $limit = 200, int $offset = 0): array`

Demand-group wrapper (Phase 1 only):

- `getByGroup(int $productModelId, int $bomVersionId, ?string $state = null): array`

Notes:

- “Demand group” is treated as “grouped by product model and BOM version”, per the canonical visibility-engine inputs.
- This method is intentionally a thin wrapper around `pool_balance` reads only; it does not implement Phase 5 visibility math.

## API

File:

- `source/hatthasilpa_pool_api.php`

Action:

- `pool_snapshot` (read-only)

Request (GET):

- Optional filters:
  - `product_model_id`
  - `bom_version_id`
  - `component_code`
  - `state`
  - `limit`
  - `offset`

Response:

- If full PoolKey is provided:
  - `{ ok: true, balance: { pool_key, quantity_on_hand, updated_at } | null }`
- Otherwise:
  - `{ ok: true, balances: [...], limit, offset, count }`

## Acceptance criteria mapping (F1–F4)

### F1 — PoolKey mapping contract is defined and testable

Implemented:

- PoolKey is concretely defined in the migration and enforced via unique index:
  - `(product_model_id, bom_version_id, component_code, state)`

Testability:

- `PoolEventService::applyEvent()` accepts PoolKey fields explicitly.
- `PoolReadService::getPoolBalanceByKey()` reads by PoolKey.

### F2 — Minimal pool snapshot read contract exists

Implemented:

- By-key read:
  - `PoolReadService::getPoolBalanceByKey(...)`
- Demand-group projection support (minimal wrapper for Phase 1):
  - `PoolReadService::getByGroup(product_model_id, bom_version_id, state?)`

This supports later phases where Work Queue projections read pool snapshots grouped by product model and BOM.

### F3 — Pool event idempotency and ordering requirement is explicit

Implemented:

- Idempotency:
  - `pool_event.idempotency_key` unique index.
  - `PoolEventService` checks existing by `idempotency_key`.
  - Concurrency-safe behavior under retry due to unique constraint + transaction + post-lock re-check.

- Ordering:
  - Explicit event primary key `id_pool_event` is the durable order.
  - `occurred_at` is recorded for audit/semantic time.

### F4 — Enforcement boundary is explicit and verified

Implemented boundary:

- Pool mutation path is explicitly implemented as a single-writer service (`PoolEventService`).
- Read paths are isolated in `PoolReadService` and the read-only API.

Verification in codebase:

- Pool table access is localized to the pool services and the pool API.

## Tests

Integration test:

- `tests/Integration/HatthasilpaPoolFoundationPhase1Test.php`

Coverage:

- Apply event increases pool quantity and is readable via `PoolReadService`.
- Idempotency key replay does not double-apply.
- Negative mutation is rejected and does not change `pool_balance`.
- API smoke call verifies JSON response shape (success or clean failure depending on permissions in the environment).
