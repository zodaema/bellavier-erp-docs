# Operational Safety & Change Governance - Implementation Plan

**Version:** 2.0 (Reframed for Revision-First Architecture)  
**Date:** January 2026  
**Status:** 📋 **PLANNING**  
**Based on:** `docs/super_dag/06-specs/OPERATIONAL_SAFETY_CHANGE_GOVERNANCE.md`  
**Priority:** 🔴 **HIGH** (Production safety critical)

---

## 📋 Overview

This plan implements the Operational Safety & Change Governance spec using a **Revision-First Architecture** (inspired by Graph Versioning).

**Core Principle:**
> No operational entity (inventory, job, token, WIP) may change its behavior or meaning after it has started.

**Architectural Philosophy:**
> **Graph is not an exception, but a template.**  
> Product, Constraints, BOM should be treated the same as Graph:  
> "Editable always, but never edit what's already in use."

**Key Insight:**
- **Lock-First** (original plan) = Safety Layer (Phase 0-1)
- **Revision-First** (this plan) = Scalable / UX-friendly / SAP-like (Phase 2-3)

---

## 🎯 Current State Analysis

### ✅ What Exists

1. **Product State Validation (Partial)**
   - `validateProductState()` - Checks `is_draft` and `is_active`
   - `checkProductUsage()` - Soft-check (warnings only, not blocking)
   - Used in: `hatthasilpa_jobs_api.php`, `product_api.php`

2. **ETag Support (Partial)**
   - ETag headers in `product_api.php` (metadata endpoint)
   - ETag/If-Match in `products.php` (update endpoint)
   - ETag/If-Match in `dag_routing_api.php` (node update)

3. **Role Change Policy (Done)**
   - ✅ Confirmation dialog before clearing constraints
   - ✅ Hard reset constraints on role change
   - Implemented: January 2026

4. **Graph Versioning (Reference Implementation)**
   - ✅ `GraphVersionService` - Version creation and management
   - ✅ `routing_graph_version` table - Immutable snapshots
   - ✅ Draft/Published/Retired lifecycle
   - ✅ Token binding to specific graph version
   - **This is our template for Product Revision**

### ❌ What's Missing

1. **Product Revision System**
   - No `product_revision` table (like `routing_graph_version`)
   - No revision lifecycle (Draft/Published/Retired)
   - No revision binding in jobs/tokens

2. **Product Usage State Model**
   - No DRAFT/ACTIVE/IN_PRODUCTION/RETIRED states
   - No state derivation from system data
   - Current: Only `is_draft` and `is_active` flags

3. **Change Classification & Redirect Logic**
   - No distinction between breaking vs non-breaking changes
   - No "redirect to new revision" logic
   - All edits allowed regardless of usage

4. **Runtime Snapshot (Revision-Bound)**
   - Need to verify snapshot creation in job/token creation
   - Need to ensure runtime binds to `product_revision_id` (not `product_id`)
   - Need to ensure runtime doesn't read live product tables

5. **Concurrency Control**
   - ETag exists but not consistently applied
   - No 409 CONFLICT handling in all endpoints
   - Need revision-level concurrency control

---

## 📊 Implementation Phases

### Phase 0: Product Revision Foundation (NEW - Core Architecture)

**Goal:** Establish Product Revision as first-class citizen (like Graph Versioning)

**Philosophy:**
> "Revision Strategy is not a feature, but a safety mechanism that replaces destructive edits."

**Tasks:**

#### 0.1 Create `product_revision` table (similar to `routing_graph_version`)

**Schema:**
```sql
CREATE TABLE product_revision (
    id_revision INT AUTO_INCREMENT PRIMARY KEY,
    id_product INT NOT NULL,
    version VARCHAR(20) NOT NULL,           -- e.g., "1.0", "2.0"
    status ENUM('draft','published','retired') NOT NULL DEFAULT 'draft',
    
    -- Immutable Snapshots
    snapshot_json JSON NOT NULL,            -- Product metadata snapshot
    components_json JSON NOT NULL,          -- Components with constraints
    graph_version_id INT,                   -- Explicit graph version (not "active")
    
    -- Revision Lineage & Intent (Section 11 of SPEC)
    revision_reason ENUM('FIX_ERROR','OPTIMIZATION','COST_REDUCTION','MATERIAL_CHANGE','CUSTOMER_SPECIFIC','ENGINEERING_CHANGE') NOT NULL,
    derived_from_revision_id INT,           -- Parent revision (lineage)
    revision_notes TEXT,                    -- Human-readable explanation
    
    -- Lifecycle
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INT NOT NULL,
    published_at DATETIME,
    published_by INT,
    retired_at DATETIME,
    retired_by INT,
    allow_new_jobs BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Concurrency
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    row_version INT NOT NULL DEFAULT 1,
    
    -- Indexes
    INDEX idx_product_version (id_product, version),
    INDEX idx_product_status (id_product, status),
    FOREIGN KEY (id_product) REFERENCES product(id_product),
    FOREIGN KEY (graph_version_id) REFERENCES routing_graph_version(id_version),
    FOREIGN KEY (derived_from_revision_id) REFERENCES product_revision(id_revision)
);
```

#### 0.2 Implement Revision Invariants Validation (Section 10 of SPEC)

**Invariants that CANNOT differ between revisions:**
- `product_id` (identity)
- `sku` (external reference)
- `uom_base` (inventory consistency)
- `material_category` (accounting logic)
- `inventory_accounting_method` (costing consistency)
- `traceability_level` (lot/serial tracking)

**Validation Logic:**
```php
public function validateRevisionInvariants(int $productId, array $newSnapshot): array {
    $product = $this->loadProduct($productId);
    
    $invariants = ['uom_base', 'material_category', 'inventory_accounting_method', 'traceability_level'];
    $violations = [];
    
    foreach ($invariants as $field) {
        if (($newSnapshot[$field] ?? null) !== ($product[$field] ?? null)) {
            $violations[] = "Cannot change {$field} between revisions. Create a new product instead.";
        }
    }
    
    return ['valid' => empty($violations), 'violations' => $violations];
}
```

#### 0.3 Create `ProductRevisionService` (similar to `GraphVersionService`)

**Methods:**
- `createRevision($productId, $userId, $reasonCode, $notes, $derivedFromId)` - Atomic revision creation
- `publishRevision($revisionId, $userId)` - Publish draft revision
- `retireRevision($revisionId, $userId)` - Retire (soft-delete)
- `getActiveRevision($productId)` - Get current active revision
- `listRevisions($productId)` - List all revisions
- `isReferenced($revisionId)` - Check if revision is bound to any runtime entity
- `validateInvariants($productId, $snapshot)` - Validate invariants

#### 0.4 Atomic Revision Creation (Execution-Level Requirement)

**"Create new revision" MUST be atomic operation:**

```php
public function createRevision(
    int $productId,
    int $userId,
    string $reasonCode,
    ?string $notes = null,
    ?int $derivedFromId = null
): array {
    // ATOMIC - All or nothing
    $this->db->begin_transaction();
    
    try {
        // 1. Load current product state
        $product = $this->loadProduct($productId);
        
        // 2. Validate invariants (if derived from existing)
        if ($derivedFromId) {
            $parentSnapshot = $this->loadRevisionSnapshot($derivedFromId);
            $invariantsCheck = $this->validateInvariants($productId, $parentSnapshot);
            if (!$invariantsCheck['valid']) {
                throw new InvariantViolationException($invariantsCheck['violations']);
            }
        }
        
        // 3. Load and freeze components + constraints
        $components = $this->loadComponents($productId);
        
        // 4. Get explicit graph version (not "active")
        $graphVersionId = $this->getActiveGraphVersionId($productId);
        
        // 5. Create snapshot JSON
        $snapshot = [
            'product' => $product,
            'snapshot_at' => now()
        ];
        
        // 6. Generate next version string
        $version = $this->generateNextVersion($productId);
        
        // 7. Insert into product_revision (status='draft')
        $revisionId = $this->insertRevision([
            'id_product' => $productId,
            'version' => $version,
            'status' => 'draft',
            'snapshot_json' => json_encode($snapshot),
            'components_json' => json_encode($components),
            'graph_version_id' => $graphVersionId,
            'revision_reason' => $reasonCode,
            'derived_from_revision_id' => $derivedFromId,
            'revision_notes' => $notes,
            'created_by' => $userId
        ]);
        
        // 8. Log lineage
        $this->logRevisionCreation($revisionId, $userId, $reasonCode);
        
        $this->db->commit();
        
        return $this->loadRevision($revisionId);
        
    } catch (\Throwable $e) {
        $this->db->rollback();
        throw $e;
    }
}
```

#### 0.5 Migration: Create `product_revision` table

**File:** `database/tenant_migrations/YYYY_MM_product_revision_system.php`

#### 0.6 Add revision to product metadata API response

**Response structure:**
```json
{
    "product": { ... },
    "revision": {
        "id_revision": 5,
        "version": "2.0",
        "status": "published",
        "revision_reason": "OPTIMIZATION",
        "published_at": "2026-01-15T10:30:00Z"
    },
    "revisions_count": 3
}
```

**Files to Create/Modify:**
- `database/tenant_migrations/YYYY_MM_product_revision_system.php` (new)
- `source/BGERP/Service/ProductRevisionService.php` (new)
- `source/product_api.php` (add revision endpoints)
- `source/BGERP/Product/ProductMetadataResolver.php` (add revision info)

**Reference:**
- `source/dag/Graph/Service/GraphVersionService.php` (template)
- `docs/super_dag/01-concepts/GRAPH_VERSIONING_AND_PRODUCT_BINDING.md`

---

### Phase 1: Product Usage State Model (Foundation)

**Goal:** Implement state derivation and classification

**Reframe from Original Plan:**
- **Original:** Use state to lock/unlock editing
- **Reframed:** Use state to determine edit mode (in-place vs new revision)

**State-to-Action Mapping:**

| State | Original Plan | Reframed Plan |
|-------|---------------|---------------|
| **DRAFT** | ✅ All edits allowed | ✅ Edit in-place (no revision needed) |
| **ACTIVE** | ❌ Block breaking, ✅ Allow non-breaking | ❌ Breaking → Create revision<br>✅ Non-breaking → Edit in-place |
| **IN_PRODUCTION** | ❌ Block all core edits | ❌ All edits → Create revision only |
| **RETIRED** | Read-only | Read-only |

**Tasks:**
1. Create `ProductUsageStateService` to compute state from system data
2. Add state derivation logic:
   - DRAFT: No job/token/inventory records
   - ACTIVE: Has completed jobs, no active WIP
   - IN_PRODUCTION: Has active jobs/tokens
   - RETIRED: Explicitly retired
3. Add state to product metadata API response
4. Add state badge to UI

**Files to Create/Modify:**
- `source/BGERP/Service/ProductUsageStateService.php` (new)
- `source/product_api.php` (add state to metadata)
- `views/products.php` (add state badge)
- `assets/javascripts/products/products.js` (display state)

**Dependencies:**
- Need to query: `mo`, `hatthasilpa_job`, `atelier_job_ticket`, `flow_token`, inventory tables

---

### Phase 2: Change Classification & Revision Redirect (Reframed)

**Goal:** Redirect breaking changes to new revision (instead of blocking)

**Semantics Change:**
- ❌ **Old:** "You cannot change this"
- ✅ **New:** "This change requires a new revision"

**Tasks:**
1. Classify all product change operations:
   - **Breaking:** Constraints, Components, Graph binding, BOM, Role change
   - **Non-breaking:** Labels, descriptions, notes, display order

2. Implement revision redirect logic:
   - DRAFT: All edits in-place
   - ACTIVE: Breaking → Create revision, Non-breaking → In-place
   - IN_PRODUCTION: All edits → Create revision only
   - RETIRED: Read-only

3. Add API-level redirect in `product_api.php`:
   ```php
   // Instead of blocking:
   if (!$stateService->canEditBreaking($productId)) {
       json_error('Breaking changes forbidden', 403);
   }
   
   // Redirect to revision:
   if ($isBreaking && !$stateService->canEditBreaking($productId)) {
       json_error('This change requires a new revision', 400, [
           'app_code' => 'PRD_400_REVISION_REQUIRED',
           'requires_revision' => true,
           'current_state' => $state
       ]);
   }
   ```

4. Add UI-level redirect:
   - Show "Create Revision" button when breaking change detected
   - Auto-create revision on save if required
   - Show revision creation dialog

**Files to Modify:**
- `source/product_api.php` (add revision redirect logic)
- `source/BGERP/Service/ProductUsageStateService.php` (add `requiresRevision()` methods)
- `assets/javascripts/products/product_components.js` (revision redirect UI)
- `assets/javascripts/products/product_graph_binding.js` (revision redirect UI)

**Breaking Change Operations to Redirect:**
- `update_component_material` (constraints)
- `component_save` (components)
- `save_binding` (graph binding)
- Role change (already has confirmation, now redirect to revision)

**Key Difference from Original:**
- **Original:** Block with 403 Forbidden
- **Reframed:** Redirect with 400 + `requires_revision: true` → UI creates revision

---

### Phase 3: Runtime Snapshot (Revision-Bound) - LOCKED DESIGN

**Goal:** Verify and enforce revision-bound snapshot creation

**Critical Change:**
- **Original:** Snapshot binds to `product_id`
- **Reframed:** Snapshot binds to `product_revision_id`

#### 3.1 Immutability Contract Enforcement (Section 13 of SPEC)

**The Contract:**
```
ONCE a product_revision is referenced by:
  - job
  - token
  - inventory ledger
  - any runtime entity

THEN:
  - It is FOREVER IMMUTABLE
  - No admin override
  - No hidden backdoor
  - No "fix data" permission
```

**Implementation:**
```php
// Before any update to product_revision
public function updateRevision(int $revisionId, array $data): void {
    if ($this->isReferenced($revisionId)) {
        throw new ImmutabilityViolationException(
            "Cannot modify revision {$revisionId} - it is referenced by active/historical runtime entities"
        );
    }
    // Proceed with update
}

public function isReferenced(int $revisionId): bool {
    // Check all runtime entities
    $hasJobs = $this->checkJobs($revisionId);
    $hasTokens = $this->checkTokens($revisionId);
    $hasInventory = $this->checkInventory($revisionId);
    
    return $hasJobs || $hasTokens || $hasInventory;
}
```

#### 3.2 Cross-Module Version Consistency (Section 14 of SPEC)

**Rule:** Product revision MUST reference specific graph version explicitly.

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| `graph_binding_id` → "active graph" | `graph_version_id` → "v2.0" (explicit) |
| Revision A uses "latest graph" | Revision A uses "graph v2.0" (frozen) |

**Why:** Prevents graph drift from silently affecting product behavior.

#### 3.3 Effective Scope (Section 12 of SPEC)

| Entity | Affected by New Revision? |
|--------|---------------------------|
| **New Jobs** | ✅ Yes (uses active revision) |
| **Existing Active Jobs** | ❌ No (stays on bound revision) |
| **Completed Jobs** | ❌ No (historical, immutable) |
| **Inventory Transactions** | ❌ No (bound at time of transaction) |

**Critical:** No auto-migration of existing jobs to new revision.

#### 3.4 Tasks

1. Audit job/token creation to ensure revision binding:
   - `hatthasilpa_job` → `product_revision_id` (not `product_id`)
   - `atelier_job_ticket` → `product_revision_id`
   - `flow_token` → `product_revision_id` (via job)
   - Inventory transactions → `product_revision_id`

2. Verify runtime entities don't read live product tables:
   - Runtime must read from `product_revision.snapshot_json`
   - Runtime must NOT read from `product` table
   - Runtime must NOT read from `product_component_material` table

3. Document snapshot structure:
   - Product metadata snapshot
   - Components snapshot (with constraints)
   - Graph version ID (explicit)

4. Add tests for snapshot integrity:
   - Test revision binding in job creation
   - Test runtime reads from revision (not live)
   - Test revision immutability after reference

**Files to Audit/Modify:**
- `source/hatthasilpa_jobs_api.php` (job creation - bind to revision)
- `source/atelier_job_ticket.php` (ticket creation - bind to revision)
- `source/dag_routing_api.php` (token creation - bind to revision)
- Runtime execution code (read from revision)

**This Phase is LOCKED DESIGN:**
- Matches Graph Versioning pattern exactly
- No deviation from revision-bound model
- Runtime must be revision-agnostic (reads snapshot only)

---

### Phase 4: Concurrency Control & Retire Semantics

**Goal:** Ensure all product/revision updates use optimistic locking + Retire semantics

#### 4.1 Concurrency Control

**Reframe:**
- **Original:** Product-level concurrency control
- **Reframed:** Revision-level concurrency control

**Tasks:**
1. Add `updated_at` tracking to all product/revision-related tables
2. Implement ETag/If-Match in all update endpoints:
   - `component_save` (product or revision)
   - `update_component_material` (product or revision)
   - `save_binding` (product or revision)
   - `publish_revision` (revision)
3. Return 409 CONFLICT on version mismatch
4. Add UI handling for conflicts (reload message)

**Key Insight:**
- Concurrency control = Prevent editing same revision simultaneously
- Not preventing editing product (revision allows multiple drafts)

#### 4.2 Soft-Delete / Retire Semantics (Section 15 of SPEC)

**Terminology:**
| Term | Meaning | Recoverable? |
|------|---------|--------------|
| **Draft** | Work in progress | N/A |
| **Published** | Active, can create jobs | N/A |
| **Retired** | Soft-deleted, visible for history | ❌ Cannot un-retire |
| **Deleted** | Hard-deleted, removed from DB | ❌ Gone forever |

**Retire Rules:**
- ❌ Un-retire revision = Never (create new instead)
- ✅ Retired revision visible = Yes (for history/audit)
- ❌ Create job with retired revision = No

**Delete Rules:**
- ✅ Delete draft revision = Yes (if never published)
- ❌ Delete published revision = No
- ❌ Delete referenced revision = No

**Implementation:**
```php
public function retireRevision(int $revisionId, int $userId): void {
    $revision = $this->loadRevision($revisionId);
    
    if ($revision['status'] !== 'published') {
        throw new InvalidOperationException("Only published revisions can be retired");
    }
    
    // Retire (soft-delete) - NOT un-retirable
    $this->db->query("UPDATE product_revision SET status='retired', retired_at=NOW(), retired_by=?, allow_new_jobs=0 WHERE id_revision=?", [$userId, $revisionId]);
}

public function deleteRevision(int $revisionId): void {
    $revision = $this->loadRevision($revisionId);
    
    if ($revision['status'] !== 'draft') {
        throw new InvalidOperationException("Only draft revisions can be deleted");
    }
    
    if ($this->isReferenced($revisionId)) {
        throw new InvalidOperationException("Cannot delete referenced revision");
    }
    
    // Hard delete (draft only)
    $this->db->query("DELETE FROM product_revision WHERE id_revision=?", [$revisionId]);
}
```

**Files to Modify:**
- `source/product_api.php` (add ETag to all updates)
- `source/BGERP/Service/ProductRevisionService.php` (revision-level ETag, retire/delete)
- `assets/javascripts/products/product_components.js` (handle 409)
- `assets/javascripts/products/product_graph_binding.js` (handle 409)

---

### Phase 5: UI/UX Enhancements (Revision-Aware)

**Goal:** Visual indicators and revision-aware user feedback

**Reframe:**
- **Original:** Show state and disable controls
- **Reframed:** Show state and redirect to revision creation

**Tasks:**
1. Add state badge to product modal/UI:
   - DRAFT / ACTIVE / IN_PRODUCTION / RETIRED
   - Show active revision version (e.g., "v2.0")

2. Show revision creation prompts:
   - "This change requires a new revision. Create revision v3.0?"
   - Auto-create revision option
   - Show revision history

3. Hide complexity:
   - Most users see "Product" (not revisions)
   - Advanced users can see revision history
   - Active revision is implicit (like Graph)

4. Add "Where Used" report integration:
   - Show which jobs use which revision
   - Show revision dependencies

**Files to Modify:**
- `views/products.php` (add state badge, revision info)
- `assets/javascripts/products/products.js` (state display, revision UI)
- `assets/javascripts/products/product_components.js` (revision redirect)
- `assets/javascripts/products/product_graph_binding.js` (revision redirect)

---

## 🔧 Implementation Details

### Product Revision Service (Template from Graph)

```php
class ProductRevisionService {
    /**
     * Create new revision from current product state
     * Similar to GraphVersionService::publish()
     */
    public function createRevision(
        int $productId,
        int $userId,
        ?string $versionNote = null
    ): array {
        // 1. Load current product state
        // 2. Load components
        // 3. Load constraints
        // 4. Load graph binding
        // 5. Create snapshot JSON
        // 6. Insert into product_revision (status='draft')
        // 7. Return revision data
    }
    
    /**
     * Publish draft revision
     */
    public function publishRevision(int $revisionId, int $userId): array {
        // 1. Validate revision
        // 2. Update status to 'published'
        // 3. Set published_at, published_by
        // 4. Set allow_new_jobs=1
        // 5. Return published revision
    }
    
    /**
     * Get active revision for product (latest published)
     */
    public function getActiveRevision(int $productId): ?array {
        // SELECT * FROM product_revision 
        // WHERE id_product=? AND status='published' 
        // ORDER BY version DESC LIMIT 1
    }
}
```

### Product Usage State Service (Reframed)

```php
class ProductUsageStateService {
    /**
     * Compute product usage state from system data
     */
    public function computeState(\mysqli $db, int $productId): string {
        // 1. Check if explicitly retired
        // 2. Check for active jobs/tokens (bound to any revision)
        // 3. Check for completed jobs
        // 4. Default to DRAFT
    }
    
    /**
     * Check if breaking change requires new revision
     * (Reframed from "canEditBreaking")
     */
    public function requiresRevision(\mysqli $db, int $productId, bool $isBreaking): bool {
        $state = $this->computeState($db, $productId);
        
        if ($state === 'DRAFT') {
            return false; // Can edit in-place
        }
        
        if ($state === 'ACTIVE' && !$isBreaking) {
            return false; // Non-breaking can edit in-place
        }
        
        // ACTIVE + breaking, or IN_PRODUCTION + any change
        return true; // Requires revision
    }
}
```

### Enforcement in API (Reframed)

```php
// In update_component_material endpoint
$stateService = new ProductUsageStateService($tenantDb);
$isBreaking = true; // Constraints change is breaking

if ($stateService->requiresRevision($tenantDb, $productId, $isBreaking)) {
    // Instead of blocking:
    // json_error('Breaking changes forbidden', 403);
    
    // Redirect to revision:
    json_error('This change requires a new revision', 400, [
        'app_code' => 'PRD_400_REVISION_REQUIRED',
        'requires_revision' => true,
        'current_state' => $stateService->computeState($tenantDb, $productId),
        'suggested_action' => 'create_revision'
    ]);
}

// If allowed, proceed with in-place edit
```

---

## 📝 Testing Requirements

### 1. Revision Creation Tests
- Test creating revision from product
- Test publishing revision
- Test revision immutability after reference

### 2. Invariants Tests
- Test `uom_base` cannot differ between revisions
- Test `material_category` cannot differ between revisions
- Test invariant violation returns clear error

### 3. Lineage Tests
- Test `revision_reason` is mandatory
- Test `derived_from_revision_id` is set correctly
- Test revision history is traceable

### 4. State Derivation Tests
- Test DRAFT state (no usage)
- Test ACTIVE state (completed jobs, no active)
- Test IN_PRODUCTION state (active jobs/tokens)
- Test RETIRED state

### 5. Revision Redirect Tests
- Test breaking changes redirect in ACTIVE
- Test breaking changes redirect in IN_PRODUCTION
- Test non-breaking changes allowed in-place in ACTIVE
- Test all changes redirect in IN_PRODUCTION

### 6. Runtime Snapshot Tests
- Test job creation binds to revision
- Test runtime reads from revision (not live)
- Test revision immutability after runtime reference
- Test explicit `graph_version_id` binding (not "active")

### 7. Concurrency Tests
- Test ETag/If-Match validation
- Test 409 CONFLICT response
- Test UI conflict handling

### 8. Retire/Delete Tests
- Test retire published revision (allowed)
- Test retire draft revision (not allowed)
- Test delete draft revision (allowed)
- Test delete published revision (not allowed)
- Test un-retire (never allowed)

---

## 🚨 Risk Assessment

**High Risk:**
- Breaking existing workflows if enforcement too strict
- Performance impact of state computation
- User confusion if UI suddenly requires revisions

**Mitigation:**
- Feature flag for gradual rollout
- Clear error messages explaining why revision needed
- Auto-create revision option (hide complexity)
- Performance optimization (cache state)
- User training/communication

**Key Difference:**
- **Original Plan:** Risk of "system feels locked"
- **Reframed Plan:** Risk of "too many revisions" (mitigated by auto-create)

---

## 📅 Timeline Estimate

- **Phase 0:** 3-4 days (Revision Foundation - NEW)
- **Phase 1:** 2-3 days (State Model)
- **Phase 2:** 3-4 days (Revision Redirect)
- **Phase 3:** 2-3 days (Runtime Snapshot - Revision-Bound)
- **Phase 4:** 1-2 days (Concurrency)
- **Phase 5:** 1-2 days (UI/UX)

**Total:** ~12-18 days

---

## ✅ Definition of Done

System is considered production-safe when:
- ✅ Product revision system operational (like Graph)
- ✅ Product usage state computed correctly
- ✅ Breaking changes redirect to revision (not blocked)
- ✅ All updates use optimistic locking
- ✅ Runtime snapshots bound to revision (not product)
- ✅ UI shows state and redirects appropriately
- ✅ All tests passing

**Key Success Metric:**
- Users can always make changes (no dead-end)
- Changes never affect active/historical jobs
- System feels like Graph (consistent mental model)

---

## 🎯 Summary: What Changed from Original Plan

| Aspect | Original (Lock-First) | Reframed (Revision-First) |
|--------|----------------------|---------------------------|
| **Philosophy** | Block destructive edits | Redirect to new revision |
| **Semantics** | "You cannot change" | "This requires a new revision" |
| **Revision Strategy** | Phase 2 (Optional) | Phase 0 (Core Architecture) |
| **Enforcement** | 403 Forbidden | 400 + `requires_revision: true` |
| **Runtime Binding** | `product_id` | `product_revision_id` |
| **User Experience** | "System is locked" | "Create revision to continue" |
| **Mental Model** | Exception (special case) | Template (like Graph) |

**Core Principle:**
> **Graph is not an exception, but a template.**  
> Product, Constraints, BOM should be treated the same as Graph:  
> "Editable always, but never edit what's already in use."

---

## 📋 Future Capabilities (Document Now, Implement Later)

### Diff Capability (Structure Must Support)

Even if UI not ready, **revision system MUST be diffable**:

```php
// Future: Diff two revisions
$diff = $revisionService->diffRevisions($revisionId1, $revisionId2);

// Returns:
// [
//     'constraints' => [
//         ['field' => 'width', 'from' => 100, 'to' => 120],
//         ['field' => 'length', 'from' => 200, 'to' => 200, 'changed' => false]
//     ],
//     'components' => [...],
//     'graph_version' => ['from' => 'v1.0', 'to' => 'v2.0']
// ]
```

**Why Now:** Data structure must support diffing. If not designed now, future refactor required.

### Correction vs Adjustment Doctrine (Section 16 of SPEC)

**The Doctrine:**
> Historical errors are corrected via adjustment transactions, not revision edits.

| Scenario | Wrong Approach | Correct Approach |
|----------|----------------|------------------|
| Wrong qty produced | Edit job record | Create adjustment entry |
| Wrong material used | Edit constraint | Create correction transaction |
| Inventory mismatch | "Fix" ledger | Adjustment journal entry |

**Why Document Now:** Prevents "can we just fix it?" requests later.

---

**Status:** 📋 **PLANNING**  
**Next Action:** Review and approve plan, then begin Phase 0 (Revision Foundation)  
**Priority:** 🔴 **HIGH**  
**Reference:** `docs/super_dag/01-concepts/GRAPH_VERSIONING_AND_PRODUCT_BINDING.md`  
**SPEC:** `docs/super_dag/06-specs/OPERATIONAL_SAFETY_CHANGE_GOVERNANCE.md`
