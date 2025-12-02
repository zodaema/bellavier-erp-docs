# Task 14.1.2 – Stock & Lot Pipeline Migration (Phase 2)

> **Objective**  
> Move the remaining *lot-level* and *stock pipeline* references off legacy `stock_item` into the new `material`-centric schema **without breaking production**, and prepare for a clean removal path in Task 14.2.

This task continues from **Task 14.1.1** (READ query migration). We now deal with:

- `material_lot.id_stock_item` and related queries
- Any remaining WRITE paths that still assume `stock_item`
- Normalizing how quantity and availability are computed for materials

All changes **must be backward compatible** and safe to deploy on a live tenant.

---

## 1. Scope

### 1.1 In Scope

1. **Database layer (tenant DB)**
   - Add transitional columns / FKs so that `material_lot` can link directly to `material` instead of `stock_item`.
   - Ensure both old + new paths can co-exist during migration window.

2. **PHP code paths (stock / lot related)**
   - Update code that still reads/writes using `id_stock_item` in `material_lot` so that:
     - New code prefers `material`-centric fields.
     - Legacy fields are still populated for safety.

3. **Read & Write flows**
   - GRN / lot creation flows that currently write `id_stock_item`.
   - Any service/helpers that compute stock quantities per material.

4. **Documentation**
   - Snapshot of the *new* stock+lot pipeline after this phase.
   - Risk notes + rollback strategy.

### 1.2 Out of Scope

- **Dropping** `stock_item` table or columns (that’s Task 14.2+).
- UI/UX redesign of stock pages (beyond what’s strictly needed for migration).
- Changing business rules around stock valuation, costing, or reservations.

---

## 2. Constraints & Safety Rails

1. **No data loss**  
   - All migrations must be *additive*. Any destructive step (DROP/ALTER removing columns) is **forbidden** in this task.

2. **Dual-write, dual-read window**  
   - For WRITE paths touching lots/stock, use a **dual-write** approach where feasible: write to both legacy (`id_stock_item`) and new (`id_material`) fields.
   - For READ paths, prefer new `material`-centric fields but gracefully fall back if needed.

3. **Idempotent migrations**  
   - Tenant migrations must be safe to run multiple times.

4. **Production-safe**  
   - If any query fails, APIs must fail with **clear JSON errors**, not PHP errors or HTML.

5. **Do not touch**
   - `super_dag` execution logic.
   - Time engine.
   - Component serial/binding logic.

---

## 3. Database Plan (High Level)

### 3.1 material_lot → material migration

**Goal:** enable `material_lot` to reference `material` directly **without** breaking existing code still using `id_stock_item`.

Planned steps:

1. **Add new column**
   - `material_lot.id_material` (nullable, FK to `material.id_material`).

2. **Backfill mapping**
   - For existing rows, fill `id_material` using the same mapping used in Task 14.1.1 (adapter logic in PHP) but implemented in SQL.

3. **Add supporting indexes**
   - Index on `material_lot.id_material` for performance.

> **Important:** Do **not** remove `id_stock_item` in this task.

### 3.2 Quantity / availability normalization (read-side)

- Define the **canonical read pattern** for per-material stock, e.g. using `warehouse_inventory` and `material_lot` rather than legacy `stock_item` fields.
- Update helper/service classes to always use this pattern.


---

## 4. Code Migration Plan

> The goal is to move all remaining lot/stock logic off `stock_item` and onto `material`+`material_lot`, while keeping a compatibility layer.

### 4.1 Identify remaining touchpoints

Use the results from **Task 14.1.1** and extend them:

1. Search in `source/` for:
   - `material_lot.id_stock_item`
   - `stock_item` joined with `material_lot`
   - `id_stock_item` used in GRN / lot / stock flows

2. Categorize into:
   - **Create / Update** flows (GRN / lot operations)
   - **Stock computations** (quantity, availability)
   - **Misc utility** usage

Record findings in:

- `docs/dag/tasks/task14.1.2_scan_notes.md` (to be created by the agent)

### 4.2 Dual-write for lot creation / updates

For each CREATE/UPDATE flow that writes `material_lot`:

1. When creating a new lot:
   - Resolve `id_material` from the selected material.
   - **Write both**: `id_material` and `id_stock_item` (if still required), using consistent mapping.

2. When updating an existing lot:
   - If the lot’s material changes (rare), ensure both fields are updated together.

3. Error handling:
   - If `id_material` cannot be resolved, **fail fast** with JSON error.

### 4.3 Read helpers update

Update any helper/service that reads lot/stock info to:

1. Prefer `id_material` + joins to `material`.
2. Fall back to `id_stock_item` only if `id_material` is NULL.
3. Ensure no new code is added that depends on `stock_item` as a primary entity.

---

## 5. Deliverables

The AI Agent must produce **at minimum** the following deliverables:

1. **DB Migration**
   - `database/tenant_migrations/2025_12_material_lot_id_material.php`
     - Adds `id_material` column + FK
     - Backfills `id_material` from legacy mapping
     - Adds index

2. **Scan Notes**
   - `docs/dag/tasks/task14.1.2_scan_notes.md`
     - List all files that still touch `material_lot` + `stock_item`
     - Categorize by usage type (create/update/read)

3. **Code Changes**
   - Update relevant PHP files to:
     - Use `id_material` in new/updated logic
     - Maintain dual-write to legacy fields where required
     - Standardize stock read patterns

4. **Result Summary**
   - `docs/dag/tasks/task14.1.2_results.md`
     - Before/after behavior description
     - List of modified files
     - Any known limitations / TODOs

---

## 6. Acceptance Criteria

Task 14.1.2 is **DONE** when all criteria below are met:

1. **Database**
   - `material_lot` has an `id_material` column with FK to `material`.
   - Existing rows have `id_material` backfilled (where possible).

2. **Code**
   - No new code is written that depends on `stock_item` as the primary material entity.
   - Lot creation flows write `id_material` consistently.
   - READ helpers prefer `id_material` and only fall back to `id_stock_item` when necessary.

3. **Safety**
   - All migrations are idempotent.
   - No destructive ALTER/DROP is introduced.
   - Error handling is JSON-based for affected APIs.

4. **Docs**
   - `task14.1.2_scan_notes.md` and `task14.1.2_results.md` exist and accurately describe:
     - Remaining tech debt (if any)
     - Next steps for Task 14.1.3 / 14.2

---

## 7. Notes for Future Tasks

- **Task 14.1.3** is expected to deal with:
  - Cleaning up any remaining `stock_item` references in BOM / routing.
  - Preparing a clear path to **drop** `stock_item` in Task 14.2.
- Do **not** drop or rename `stock_item` in this task – just make it logically obsolete.

