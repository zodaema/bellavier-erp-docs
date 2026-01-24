# DC-07 — BOM Version Source for PoolKey (CUT → Pool)

## Chosen source of truth (1 line)
**SSOT for `PoolKey.bom_version_id`: `job_ticket.bom_version_id` (requires DC-07 schema addition; pinned at job creation and immutable).**

## Evidence (schema + code paths)

### A) PoolKey requires a BOM *ID* (`bom.id_bom`)
- `database/tenant_migrations/2026_01_hatthasilpa_pool_foundation.php`
  - `pool_balance.bom_version_id` is declared as `FK → bom.id_bom`.
  - `pool_event.bom_version_id` is declared as `FK → bom.id_bom`.

### B) `job_ticket` is the job/run identity, but does **not** store any BOM version
- `database/tenant_migrations/0001_init_tenant_schema_v2.php`
  - `job_ticket` table definition (see the `// 33. job_ticket` block) includes:
    - `id_product`
    - `id_routing_graph`
    - `graph_version` (string)
  - It does **not** include `bom_version_id`, `id_bom`, or `id_bom_template`.

### C) Job creation pins `product_revision_id` + `graph_version`, but still pins **no BOM id**
- `database/tenant_migrations/2026_01_product_revision_system.php`
  - Adds `job_ticket.product_revision_id` (runtime binding).
  - `product_revision` table contains:
    - `graph_version_id` (routing graph version binding)
    - `snapshot_json`, `components_json`
  - There is **no** `bom_version_id` column on `product_revision`.

- `source/BGERP/Service/JobCreationService.php`
  - `createJobTicketForDAGJob()` inserts into `job_ticket`:
    - `(ticket_code, job_name, id_product, product_revision_id, target_qty, due_date, id_mo, status, routing_mode, production_type, id_routing_graph, graph_version)`
    - No BOM column is written.

### D) The binding layer can reference a BOM (`id_bom_template`), but jobs do **not** persist it
- `database/tenant_migrations/0001_init_tenant_schema_v2.php`
  - `product_graph_binding.id_bom_template` exists and is declared as `FK to bom(id_bom)`.

- `source/BGERP/Service/JobCreationService.php`
  - `loadBinding()` selects `pgb.id_bom_template`.
  - The `job_ticket` INSERT statements do not store it (because there is no `job_ticket` column for it).

### E) `product_revision.snapshot_json` contains a derived BOM *summary*, not a `bom.id_bom`
- `source/BGERP/Product/ProductRevisionService.php`
  - `buildRuntimeSnapshot()` returns a `bom` section:
    - `bom.items` sourced from `structure['bom_items']`.
    - `generated_from` is `structure_v2`.
  - This is a material requirements summary (SKU/UoM quantities), not a stable reference to `bom.id_bom`.

## Rejection of non-deterministic alternatives (why forbidden)

Aligned to:
- `docs/super_dag/01-canonical/HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md`

Rejected sources:
1. **“Use current active BOM for product”** (e.g., `bom.is_active=1` for `id_product`).
   - Forbidden because it is time-dependent and can change after the job starts.
   - Pool events must be replay-safe and deterministic; PoolKey must not drift.

2. **“Look up `product_graph_binding` at CUT yield time and read `id_bom_template`”**.
   - Forbidden because bindings can change (`effective_from`, `priority`, `is_active`).
   - Without storing the chosen binding (or BOM id) on the job/run, this is not deterministic.

3. **“Derive a synthetic BOM version from `product_revision.snapshot_json` content”**.
   - Forbidden because canonical PoolKey explicitly requires an integer `bom_version_id` referencing `bom.id_bom`.
   - A hash/version derived from snapshot content would not satisfy the canonical contract.

4. **“Infer `bom.id_bom` from partial artifacts like `bom_line_id`”**.
   - Not generally available in the CUT session end path (CUT session stores component/material identity, not `bom_line_id`).
   - Even if available for some cases (e.g., leather logs), it is not guaranteed for all CUT yields; PoolKey must be defined for all.

## INSUFFICIENT EVIDENCE (current state)
No deterministic, job-pinned source of `bom.id_bom` exists for Hatthasilpa CUT yields.

## Required DC-07 schema addition (conceptual; no implementation here)

### Migration name
`database/tenant_migrations/2026_01_dc07_job_ticket_bom_version_id.php`

### Schema change
Add a column:
- `job_ticket.bom_version_id INT NULL COMMENT 'FK → bom.id_bom (pinned at job creation for PoolKey determinism)'`

Add supporting index (and FK if feasible for existing data):
- `INDEX idx_job_ticket_bom_version (bom_version_id)`
- Optional: `FOREIGN KEY (bom_version_id) REFERENCES bom(id_bom)`

### How job creation should set it (conceptual)
- When creating a Hatthasilpa job from a binding (where `product_graph_binding.id_bom_template` is known):
  - Set `job_ticket.bom_version_id = product_graph_binding.id_bom_template` at INSERT time.
- When creating a DAG job without an explicit binding id:
  - Resolve the binding deterministically at job creation time (same decision the job UI uses) and pin the resolved `id_bom_template` into `job_ticket.bom_version_id`.

### Immutability rule
- Once `job_ticket.bom_version_id` is set for a job, it must never be updated.
  - This keeps PoolKey stable for replay, audit, and cross-time correctness.
