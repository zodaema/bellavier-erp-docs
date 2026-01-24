# Task 29.1 Results: Revision Foundation

**Status:** ✅ **COMPLETE** (Reviewed & Fixed)  
**Date:** January 6, 2026  
**Estimate:** 2-3 days → **Actual:** 1 session + review fixes

---

## Post-Review Fixes (Critical)

### 1. ✅ Fixed `bind_param()` Type Mismatch
**Problem:** Original bind_param had incorrect type string that could cause data corruption  
**Fix:** Changed from `isisssissi` to `iiississsi`
- Changed `version` (string) → `revision_no` (int)
- Fixed `graphVersionId` type: was `s`, now `i`
- Fixed `now` type: was `i`, now `s`

### 2. ✅ Locked Vocabulary: Revision Status vs Product Usage State

| Concept | Values | Storage |
|---------|--------|---------|
| **Revision Status** | `draft`, `published`, `retired` | Stored in `product_revision.status` |
| **Product Usage State** | `DRAFT`, `ACTIVE`, `IN_PRODUCTION`, `RETIRED` | **Computed** from runtime (Task 29.2) |

**Rationale:** These are two separate concepts:
- Revision Status = lifecycle of individual revision
- Product Usage State = derived from runtime usage (jobs, tokens, inventory)

Aligns with Graph Versioning pattern (`routing_graph_version.status`).

### 3. ✅ Added `revision_no` as Source of Truth

**Before:** Used `version` (VARCHAR) with parsed increment logic  
**After:** Added `revision_no` (INT) as source of truth

```sql
revision_no INT NOT NULL,
version VARCHAR(20) GENERATED ALWAYS AS (CONCAT(revision_no, '.0')) VIRTUAL
UNIQUE INDEX idx_product_revision_no (id_product, revision_no)
```

**Benefits:**
- No string parsing required
- Database guarantees uniqueness
- Version string is derived/display only
- Simpler increment logic: `MAX(revision_no) + 1`

---

## Summary

Implemented the foundation for Product Revision System including:
- Database migration for `product_revision` and `product_revision_reference` tables
- `ProductRevisionService` with full CRUD operations
- Exception classes for invariant violations
- Unit tests (18 tests, 81 assertions)

---

## Files Created

### Migration
| File | Purpose |
|------|---------|
| `database/tenant_migrations/2026_01_product_revision_system.php` | Creates product_revision table, adds FK columns to product/job_ticket/flow_token |

### Service
| File | Purpose |
|------|---------|
| `source/BGERP/Product/ProductRevisionService.php` | Core revision service (create, publish, retire, delete, validate) |

### Exceptions
| File | Purpose |
|------|---------|
| `source/BGERP/Exception/InvariantViolationException.php` | Thrown when invariant fields change |
| `source/BGERP/Exception/RevisionCreationException.php` | Thrown when revision cannot be created |

### Tests
| File | Tests | Assertions |
|------|-------|------------|
| `tests/Unit/ProductRevisionServiceTest.php` | 20 | 89 |

---

## Database Changes

### New Tables

#### `product_revision`
```sql
- id_revision (PK)
- id_product (FK → product)
- revision_no (INT, source of truth for version number)
- version (GENERATED: revision_no + '.0', e.g., "1.0", "2.0")
- derived_from_revision_id (FK → self)
- revision_reason (ENUM)
- revision_notes (TEXT)
- status (draft/published/retired)
- allow_new_jobs (BOOLEAN)
- graph_version_id (FK → routing_graph_version)
- snapshot_json (JSON)
- components_json (JSON)
- created_at, created_by
- published_at, published_by
- retired_at, retired_by
- updated_at, row_version
```

**Key Index:** `UNIQUE INDEX idx_product_revision_no (id_product, revision_no)`

#### `product_revision_reference`
```sql
- id_reference (PK)
- id_revision (FK → product_revision)
- reference_type (job_ticket/flow_token/inventory_ledger/mo)
- reference_id
- referenced_at
```

### Column Additions

| Table | Column | Purpose |
|-------|--------|---------|
| `product` | `active_revision_id` | Quick lookup for active revision |
| `job_ticket` | `product_revision_id` | Runtime binding to revision |
| `flow_token` | `product_revision_id` | DAG token binding to revision |

---

## Service Methods Implemented

### Core Operations
| Method | Description |
|--------|-------------|
| `createRevision()` | Create new draft revision with snapshot |
| `publishRevision()` | Publish draft, retire previous active |
| `retireRevision()` | Mark published revision as retired |
| `deleteRevision()` | Delete draft revision only |

### Queries
| Method | Description |
|--------|-------------|
| `getActiveRevision()` | Get current active revision for product |
| `listRevisions()` | List all revisions for product |
| `loadRevision()` | Load single revision by ID |

### Validation
| Method | Description |
|--------|-------------|
| `validateInvariants()` | Check invariant fields match |
| `isReferenced()` | Check if revision is used by runtime |
| `getLockedReason()` | Human-readable lock reason |

---

## Invariant Fields (Cannot Change Between Revisions)

| Field | Reason |
|-------|--------|
| `sku` | External reference |
| `default_uom` | Inventory consistency |
| `default_uom_code` | Inventory consistency |

---

## Revision Reasons (ENUM)

| Reason | Use Case |
|--------|----------|
| `INITIAL` | First revision of product |
| `FIX_ERROR` | Correcting mistakes |
| `OPTIMIZATION` | Improving process |
| `COST_REDUCTION` | Reducing costs |
| `MATERIAL_CHANGE` | Changing materials |
| `CUSTOMER_SPECIFIC` | Customer customization |
| `ENGINEERING_CHANGE` | Engineering modification |

---

## Status Lifecycle

```
draft → published → retired
         ↓
       active (allow_new_jobs=1)
```

### Allowed Transitions
- `draft` → `published` (via publishRevision)
- `published` → `retired` (via retireRevision)

### Allowed Deletions
- `draft` only (via deleteRevision)

---

## Test Results (After Review Fixes)

```
PHPUnit 9.6.31

Product Revision Service
 ✔ Invariant violation exception creation
 ✔ Invariant violation exception for field
 ✔ Invariant violation exception for multiple fields
 ✔ Valid revision reasons
 ✔ Invalid revision reason detection
 ✔ Revision no is source of truth
 ✔ Version string format
 ✔ Revision no increment
 ✔ First revision no is one
 ✔ Version derived from revision no
 ✔ Product snapshot structure
 ✔ Components snapshot structure
 ✔ Invariant fields list
 ✔ Invariant validation
 ✔ Valid status transitions
 ✔ Invalid status transitions
 ✔ Lock reason format
 ✔ Snapshot json encoding
 ✔ Empty components snapshot
 ✔ Null values handling

OK (20 tests, 89 assertions)
```

---

## Next Steps

### Task 29.2: Usage State & Change Classification
- Implement `ProductUsageStateService`
- State derivation (DRAFT/ACTIVE/IN_PRODUCTION/RETIRED)
- Change classification (Breaking vs Non-breaking)
- API response for revision redirect

### Task 29.3: Runtime Snapshot & Immutability
- Bind jobs/tokens to `product_revision_id`
- Immutability contract enforcement
- Cross-module version consistency

### Task 29.4: Lifecycle & Concurrency
- ETag/If-Match for optimistic locking
- UI state indicators
- Retire/delete flows

---

## Template Pattern Notes

Used `GraphVersionService` as template:
- Similar constructor pattern with `DatabaseHelper`
- Similar version string generation (`X.0` format)
- Similar snapshot JSON structure
- Similar status lifecycle (draft → published → retired)

Key differences:
- Products have invariant fields (SKU, UoM)
- Products have components snapshot
- Products reference graph_version_id
- Products track lineage (derived_from_revision_id)

---

**Completed By:** AI Agent  
**Reviewed By:** Pending  
**Migration Status:** ⚠️ Not yet run (requires `php source/bootstrap_migrations.php --tenant=xxx`)

