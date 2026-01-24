# Task 29: Product Revision System Implementation

**Status:** 📋 **PLANNING**  
**Priority:** 🔴 **CRITICAL**  
**Category:** Product Lifecycle / Data Integrity / ERP Safety  
**Date:** January 2026

---

## Executive Summary

**Goal:** Implement Product Revision system to ensure product changes never corrupt runtime entities (jobs, tokens, inventory).

**Architectural Philosophy:**
> **Graph is not an exception, but a template.**  
> Product, Constraints, BOM should be treated the same as Graph:  
> "Editable always, but never edit what's already in use."

**Reference Documents:**
- `docs/super_dag/06-specs/OPERATIONAL_SAFETY_CHANGE_GOVERNANCE.md` (SPEC v2.0)
- `docs/super_dag/plans/OPERATIONAL_SAFETY_IMPLEMENTATION_PLAN.md` (Implementation Plan v2.0)
- `source/dag/Graph/Service/GraphVersionService.php` (Code Template)

---

## Task Breakdown (Consolidated)

| Task | Title | Scope | Estimate |
|------|-------|-------|----------|
| **29.1** | Revision Foundation | Schema + Service + Migration + Invariants + Lineage + Active Selection | 2-3 days |
| **29.2** | Usage State & Change Classification | State Derivation + State-to-Action + Breaking vs Non-breaking + Redirect | 2 days |
| **29.3** | Runtime Snapshot & Immutability | Snapshot Builder + Revision Binding + Immutability + Cross-Module Consistency | 2 days |
| **29.4** | Lifecycle & Concurrency | Retire/Delete + Optimistic Locking + UI Indicators | 1.5 days |

**Total Estimate:** ~7.5-8.5 days

---

## Task 29.1: Revision Foundation

**Status:** ✅ **COMPLETE**  
**Estimate:** 2-3 days → **Actual:** 1 session  
**Results:** `docs/super_dag/tasks/results/task29.1.results.md`

### Scope

รวม Phase 0 ทั้งหมด:
- Data Model (Schema)
- Invariants Validation
- Atomic Revision Creation
- Lineage & Intent
- Active Revision Selection
- Database Migration

### Data Model

```sql
CREATE TABLE product_revision (
    -- Identity
    id_revision INT AUTO_INCREMENT PRIMARY KEY,
    id_product INT NOT NULL,
    
    -- Revision Identity
    version VARCHAR(20) NOT NULL,
    
    -- Lineage & Intent
    derived_from_revision_id INT NULL,
    revision_reason ENUM(
        'INITIAL', 'FIX_ERROR', 'OPTIMIZATION', 
        'COST_REDUCTION', 'MATERIAL_CHANGE', 
        'CUSTOMER_SPECIFIC', 'ENGINEERING_CHANGE'
    ) NOT NULL,
    revision_notes TEXT,
    
    -- Status
    status ENUM('draft', 'published', 'retired') NOT NULL DEFAULT 'draft',
    allow_new_jobs BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Binding
    graph_version_id INT NULL,
    
    -- Snapshot
    snapshot_json JSON NOT NULL,
    components_json JSON NOT NULL,
    
    -- Lifecycle
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INT NOT NULL,
    published_at DATETIME NULL,
    published_by INT NULL,
    retired_at DATETIME NULL,
    retired_by INT NULL,
    
    -- Concurrency
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    row_version INT NOT NULL DEFAULT 1,
    
    -- Indexes & FKs
    INDEX idx_product_version (id_product, version),
    INDEX idx_product_status (id_product, status),
    FOREIGN KEY (id_product) REFERENCES product(id_product),
    FOREIGN KEY (graph_version_id) REFERENCES routing_graph_version(id_version),
    FOREIGN KEY (derived_from_revision_id) REFERENCES product_revision(id_revision)
);
```

### Invariants (Fields that CANNOT differ between revisions)

| Field | Reason |
|-------|--------|
| `sku` | External reference |
| `uom_base` | Inventory consistency |
| `material_category` | Accounting logic |
| `inventory_accounting_method` | Costing consistency |
| `traceability_level` | Lot/Serial tracking |

### Service Methods

```php
class ProductRevisionService {
    // Core Operations
    public function createRevision(int $productId, int $userId, string $reason, ?string $notes, ?int $derivedFrom): array;
    public function publishRevision(int $revisionId, int $userId): array;
    public function retireRevision(int $revisionId, int $userId): void;
    public function deleteRevision(int $revisionId): void;
    
    // Queries
    public function getActiveRevision(int $productId): ?array;
    public function listRevisions(int $productId): array;
    public function loadRevision(int $revisionId): ?array;
    
    // Validation
    public function validateInvariants(int $productId, array $snapshotData): array;
    public function isReferenced(int $revisionId): bool;
    
    // Lock Reason (Human-readable)
    public function getLockedReason(int $revisionId): ?string;
}
```

### Lock Reason (UX + Audit)

Every immutable revision exposes `locked_reason`:
- "Used by Job #A24019"
- "Inventory ledger posted (2026-01-15)"
- "Active tokens in production"

### Deliverables

- [ ] `database/tenant_migrations/YYYY_MM_product_revision_system.php`
- [ ] `source/BGERP/Service/ProductRevisionService.php`
- [ ] `source/BGERP/Exception/InvariantViolationException.php`
- [ ] `source/BGERP/Exception/RevisionCreationException.php`
- [ ] Unit tests for invariants validation
- [ ] Unit tests for revision creation

### Acceptance Criteria

- [ ] Schema created and migrated
- [ ] Revision creation is atomic (all-or-nothing)
- [ ] Invariants validated on create/update
- [ ] Lineage tracked via `derived_from_revision_id`
- [ ] Only one active (published + allow_new_jobs) revision per product
- [ ] Version numbering works correctly (1.0, 2.0, 3.0)

---

## Task 29.2: Usage State & Change Classification

**Status:** 📋 **TODO**  
**Depends On:** Task 29.1  
**Estimate:** 2 days

### Scope

รวม Phase 1 + Phase 2:
- Product Usage State Derivation
- State-to-Action Mapping
- Breaking vs Non-Breaking Classification
- Redirect Instead of Block

### Usage States

| State | Condition | Actions Allowed |
|-------|-----------|-----------------|
| **DRAFT** | No runtime references | All edits in-place |
| **ACTIVE** | Historical jobs only | Non-breaking in-place, Breaking → revision |
| **IN_PRODUCTION** | Active jobs/tokens | All edits → revision only |
| **RETIRED** | Explicitly retired | Read-only |

### Change Classification

| Type | Examples | DRAFT | ACTIVE | IN_PRODUCTION |
|------|----------|-------|--------|---------------|
| **Breaking** | Constraints, Components, Graph, Role | ✅ In-place | ⚠️ Revision | ⚠️ Revision |
| **Non-Breaking** | Labels, Notes, Display order | ✅ In-place | ✅ In-place | ⚠️ Revision |

### Service Methods

```php
class ProductUsageStateService {
    public function computeState(int $productId): string;
    public function requiresRevision(int $productId, bool $isBreaking): bool;
    public function getStateDetails(int $productId): array;
}
```

### API Response for Revision Required

```json
{
    "ok": false,
    "error": "This change requires a new revision",
    "app_code": "PRD_400_REVISION_REQUIRED",
    "requires_revision": true,
    "current_state": "ACTIVE",
    "suggested_action": "create_revision"
}
```

### Deliverables

- [ ] `source/BGERP/Service/ProductUsageStateService.php`
- [ ] Integration in `product_api.php` for state-aware enforcement
- [ ] API response format for revision redirect
- [ ] Unit tests for state derivation
- [ ] Unit tests for change classification

### Acceptance Criteria

- [ ] State computed from runtime data (not manual flag)
- [ ] State-to-action mapping enforced
- [ ] Breaking changes redirect to revision (not blocked)
- [ ] API returns `requires_revision: true` when needed
- [ ] UI can consume decision and show appropriate prompt

---

## Task 29.3: Runtime Snapshot & Immutability

**Status:** 📋 **TODO**  
**Depends On:** Task 29.1, 29.2  
**Estimate:** 2 days

### Scope

รวม Phase 3:
- Revision Snapshot Builder
- Runtime Binding to `product_revision_id`
- Immutability Contract Enforcement
- Cross-Module Version Consistency

### Snapshot Structure

```json
{
    "product": {
        "id_product": 123,
        "sku": "PROD-001",
        "name": "Sample Product",
        "uom_base": "PCS"
    },
    "snapshot_at": "2026-01-15T10:30:00Z"
}
```

```json
{
    "components": [
        {
            "id_component": 1,
            "material_id": 456,
            "role_code": "MAIN_MATERIAL",
            "constraints": { ... },
            "computed_qty": 2.5
        }
    ],
    "snapshot_at": "2026-01-15T10:30:00Z"
}
```

### Immutability Contract

```
ONCE a product_revision is referenced by:
  - job / token / inventory ledger
THEN:
  - It is FOREVER IMMUTABLE
  - No admin override
  - No hidden backdoor
```

### Cross-Module Consistency

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| Reference "active graph" | Reference explicit `graph_version_id` |
| Read live product table | Read `snapshot_json` |

### Effective Scope

| Entity | Affected by New Revision? |
|--------|---------------------------|
| **New Jobs** | ✅ Yes |
| **Existing Active Jobs** | ❌ No (stays on bound revision) |
| **Completed Jobs** | ❌ No (historical) |

### Deliverables

- [ ] Snapshot builder methods in `ProductRevisionService`
- [ ] Audit/modify job creation to bind `product_revision_id`
- [ ] Audit/modify token creation to bind `product_revision_id`
- [ ] `isReferenced()` method for immutability check
- [ ] Enforce explicit `graph_version_id` (not "active")
- [ ] Integration tests for runtime binding

### Acceptance Criteria

- [ ] Snapshot complete and self-sufficient
- [ ] Jobs bind to `product_revision_id`
- [ ] Tokens bind to `product_revision_id`
- [ ] Referenced revisions cannot be modified
- [ ] Graph version explicitly captured
- [ ] Runtime never reads live product tables

---

## Task 29.4: Lifecycle & Concurrency

**Status:** 📋 **TODO**  
**Depends On:** Task 29.1, 29.2, 29.3  
**Estimate:** 1.5 days

### Scope

รวม Phase 4 + Phase 5:
- Retire Revision Flow
- Delete Draft Revision Rules
- Optimistic Locking
- Visual State & Revision Indicators

### Retire/Delete Rules

| Action | Draft | Published | Referenced |
|--------|-------|-----------|------------|
| **Retire** | ❌ | ✅ | ✅ |
| **Delete** | ✅ | ❌ | ❌ |
| **Un-retire** | N/A | ❌ Never | ❌ Never |

### Concurrency Control

```php
// ETag/If-Match pattern
if ($currentRowVersion !== $providedRowVersion) {
    json_error('Version conflict', 409, [
        'app_code' => 'PRD_409_VERSION_CONFLICT',
        'current_version' => $currentRowVersion
    ]);
}
```

### UI Indicators

- Product state badge: **DRAFT / ACTIVE / IN_PRODUCTION / RETIRED**
- Active revision label: **v2.0**
- Disabled actions show reason
- Revision history accessible

### Deliverables

- [ ] `retireRevision()` and `deleteRevision()` in service
- [ ] ETag/If-Match in all revision update endpoints
- [ ] 409 CONFLICT handling in UI
- [ ] State badge component
- [ ] Revision label display
- [ ] UI tests for state indicators

### Acceptance Criteria

- [ ] Retire works for published revisions
- [ ] Retired cannot be un-retired
- [ ] Delete works for draft only
- [ ] Cannot delete referenced revisions
- [ ] Optimistic locking prevents lost updates
- [ ] UI shows clear state and revision info

---

## Future-Aware (Document Only)

### Diff Capability

- Revision diff MUST use `snapshot_json` comparison (NOT live table diff)
- Canonical diff categories: `product`, `components`, `constraints`, `graph_version`
- No implementation required now

### Shadow Draft Concept

- Allow preparing next revision without publishing
- ACTIVE revision + Shadow Draft (editable, not yet active)
- Publish = atomic switch to new ACTIVE
- Not required for Phase 1

### Correction vs Adjustment

- Historical errors → adjustment transactions
- Never edit immutable revisions
- Document policy only

---

## Pre-Implementation Study (Required Reading)

### System Architecture & Standards

ก่อนเริ่ม implement ต้องอ่านเอกสารเหล่านี้:

| Document | Path | Purpose |
|----------|------|---------|
| **System Wiring Guide** | `docs/developer/SYSTEM_WIRING_GUIDE.md` | Complete system wiring, bloodlines, dependencies |
| **Global Helpers** | `docs/developer/02-quick-start/GLOBAL_HELPERS.md` | Available helpers and usage patterns |
| **Service Reuse Guide** | `docs/developer/08-guides/07-service-reuse.md` | When to reuse vs create new services |
| **Developer Policy** | `docs/developer/01-policy/DEVELOPER_POLICY.md` | Coding standards and rules |
| **API Standards** | `docs/developer/04-api/03-api-standards.md` | API development patterns |

---

### Key Services to Reuse

| Service | Location | Purpose | How to Use |
|---------|----------|---------|------------|
| **GraphVersionService** | `source/dag/Graph/Service/` | **Template pattern** for ProductRevisionService | Copy structure, adapt for products |
| **DatabaseTransaction** | `source/BGERP/Service/` | Atomic operations | Wrap revision creation |
| **ValidationService** | `source/BGERP/Service/` | Input validation | Validate invariants |
| **DatabaseHelper** | `source/BGERP/Helper/` | Database operations | All DB queries |
| **ErrorHandler** | `source/BGERP/Service/` | Centralized error handling | Top-level try-catch |

---

### Key Tables & Relationships

| Table | Location | Purpose | Task 29 Impact |
|-------|----------|---------|----------------|
| `product` | Tenant DB | Product master | Add `active_revision_id` FK |
| `product_graph_binding` | Tenant DB | Graph binding | Bind to revision |
| `job_ticket` | Tenant DB | Job tickets | Add `product_revision_id` |
| `flow_token` | Tenant DB | DAG tokens | Snapshot binding |
| `routing_graph_version` | Tenant DB | Graph versions | Reference pattern |

---

### Code Files to Study

ต้องอ่าน code เหล่านี้ก่อน implement:

| File | Purpose | Study For |
|------|---------|-----------|
| `source/dag/Graph/Service/GraphVersionService.php` | Graph versioning | **Template pattern** - copy structure |
| `source/product_api.php` | Product API | Where to add revision endpoints |
| `source/BGERP/Product/ProductMetadataResolver.php` | Product metadata | Extend for revision |
| `source/BGERP/Service/JobCreationService.php` | Job creation | Bind to revision |
| `source/BGERP/Service/DatabaseTransaction.php` | Transaction pattern | Atomic operations |
| `source/BGERP/Service/ValidationService.php` | Validation pattern | Invariants validation |

---

### Wiring Points (Critical Bloodlines)

```
Product (identity)
    ↓
ProductRevision (snapshot)
    ├── snapshot_json (product metadata)
    ├── components_json (frozen components + constraints)
    └── graph_version_id (explicit binding to graph)
           ↓
       Job/Token Creation
           ├── product_revision_id (REQUIRED)
           └── Read from snapshot_json (NOT live tables)
```

---

### DO NOT TOUCH Zones

| Zone | Reason | Alternative |
|------|--------|-------------|
| `flow_token` table | Use services only | `TokenLifecycleService` |
| `token_event` table | Immutable audit | `TokenEventService` |
| `GraphVersionService` | Reference only | Create `ProductRevisionService` |
| Core DB tables | Platform-level | Use Tenant DB only |

---

### Coding Patterns to Follow

#### Bootstrap Pattern
```php
[$org, $db] = TenantApiBootstrap::init();
```

#### Validation Pattern
```php
$validation = RequestValidator::make($data, $rules);
if (!$validation->passes()) { 
    json_error($validation->errors(), 400);
}
```

#### Transaction Pattern
```php
DatabaseTransaction::execute($db, function($db) use ($data) {
    // All operations atomic
    return $result;
});
```

#### Service Pattern (From GraphVersionService)
```php
namespace BGERP\Product;

class ProductRevisionService {
    private mysqli $db;
    
    public function __construct(mysqli $db) {
        $this->db = $db;
    }
}
```

#### Response Pattern
```php
json_success(['data' => $result, 'meta' => ['schema_version' => '...']]);
json_error('message', 400, ['app_code' => 'PRD_400_xxx']);
```

---

### File Locations for New Files

| Type | Path | Example |
|------|------|---------|
| **Service** | `source/BGERP/Product/` | `ProductRevisionService.php` |
| **Exception** | `source/BGERP/Exception/` | `InvariantViolationException.php` |
| **Migration** | `database/tenant_migrations/` | `2026_01_product_revision_system.php` |
| **Unit Test** | `tests/Unit/` | `ProductRevisionServiceTest.php` |
| **Integration Test** | `tests/Integration/` | `ProductRevisionApiTest.php` |
| **Results** | `docs/super_dag/tasks/results/` | `task29.1.results.md` |

---

## Agent Instructions

1. **Read Pre-Implementation Study** - Complete required reading FIRST
2. **Study GraphVersionService** - Understand the pattern before coding
3. **Start with Task 29.1** - Foundation must be solid
4. **Write tests** - Each task must have tests
5. **Use existing services** - Reuse `DatabaseTransaction`, `ValidationService`, etc.
6. **Update results** - Write `task29.X.results.md` after completion
7. **One task per session** - Complete fully before moving on
8. **Follow file locations** - Put files in correct directories

---

**Status:** 🔄 **IN PROGRESS**  
**Completed:** Task 29.1 ✅  
**Next Task:** 29.2 (Usage State & Change Classification)  
**Dependencies:** Task 28 (Graph Versioning) complete
