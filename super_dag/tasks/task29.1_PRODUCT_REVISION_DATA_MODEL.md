# Task 29.1: Define Product Revision Data Model

**Status:** 📋 **TODO**  
**Priority:** 🔴 **CRITICAL**  
**Phase:** 0 (Foundation)  
**Estimate:** 0.5 day  
**Depends On:** None (First task)

---

## Goal

สร้างโครงสร้าง `product_revision` ที่รองรับ snapshot, lineage, invariants

---

## Scope

### 1. Define Conceptual Schema for `product_revision`

**Fields ต้องครอบคลุม:**

| Category | Field | Type | Description |
|----------|-------|------|-------------|
| **Identity** | `id_revision` | INT PK | Primary key |
| | `id_product` | INT FK | Link to product |
| **Revision Identity** | `version` | VARCHAR(20) | e.g., "1.0", "2.0" |
| | `revision_code` | VARCHAR(50) | Optional: human-readable code |
| **Lineage** | `derived_from_revision_id` | INT FK NULL | Parent revision |
| **Intent** | `revision_reason` | ENUM | Why this revision exists |
| | `revision_notes` | TEXT | Human-readable explanation |
| **Status** | `status` | ENUM | draft/published/retired |
| | `allow_new_jobs` | BOOLEAN | Can create jobs with this revision |
| **Binding** | `graph_version_id` | INT FK NULL | Explicit graph version |
| **Snapshot** | `snapshot_json` | JSON | Frozen product metadata |
| | `components_json` | JSON | Frozen components + constraints |
| **Lifecycle** | `created_at` | DATETIME | Creation timestamp |
| | `created_by` | INT FK | Creator user |
| | `published_at` | DATETIME NULL | Publication timestamp |
| | `published_by` | INT FK NULL | Publisher user |
| | `retired_at` | DATETIME NULL | Retirement timestamp |
| | `retired_by` | INT FK NULL | Retirer user |
| **Concurrency** | `updated_at` | DATETIME | Last update |
| | `row_version` | INT | Optimistic locking |

### 2. Revision Reason Codes

```sql
ENUM('FIX_ERROR', 'OPTIMIZATION', 'COST_REDUCTION', 'MATERIAL_CHANGE', 'CUSTOMER_SPECIFIC', 'ENGINEERING_CHANGE', 'INITIAL')
```

| Code | Description | Example |
|------|-------------|---------|
| `INITIAL` | First version (v1) | Bootstrap |
| `FIX_ERROR` | Fix production error | "Wrong constraint caused waste" |
| `OPTIMIZATION` | Improve efficiency | "Reduce material usage" |
| `COST_REDUCTION` | Lower cost | "Cheaper supplier" |
| `MATERIAL_CHANGE` | Substitute material | "Original discontinued" |
| `CUSTOMER_SPECIFIC` | Customer requirement | "Custom spec" |
| `ENGINEERING_CHANGE` | Design update | "Drawing revision" |

### 3. Status Lifecycle

```
DRAFT → PUBLISHED → RETIRED
        ↑
        └── (only via explicit retire action)
```

| Status | Editable? | Can Create Jobs? | Visible in History? |
|--------|-----------|------------------|---------------------|
| `draft` | ✅ Yes | ❌ No | ✅ Yes |
| `published` | ❌ No | ✅ Yes (if `allow_new_jobs`) | ✅ Yes |
| `retired` | ❌ No | ❌ No | ✅ Yes |

---

## Agent Must Think About

### 1. What belongs in Revision vs Product?

| Field | Location | Reason |
|-------|----------|--------|
| `sku` | Product | Identity (invariant) |
| `uom_base` | Product | Identity (invariant) |
| `material_category` | Product | Identity (invariant) |
| `name` | Product | Display only |
| `constraints` | Revision | Can change between revisions |
| `components` | Revision | Can change between revisions |
| `graph_binding` | Revision | Can change between revisions |

### 2. What must be immutable after reference?

Once a revision is referenced by runtime entity (job, token, inventory):
- ❌ `snapshot_json` cannot change
- ❌ `components_json` cannot change
- ❌ `graph_version_id` cannot change
- ❌ `status` cannot change back to `draft`

### 3. How this mirrors Graph Version schema?

| Graph Version | Product Revision |
|---------------|------------------|
| `id_version` | `id_revision` |
| `id_graph` | `id_product` |
| `version` | `version` |
| `snapshot_json` | `snapshot_json` + `components_json` |
| `status` | `status` |
| `allow_new_jobs` | `allow_new_jobs` |
| `published_at/by` | `published_at/by` |

---

## Deliverables

### 1. SQL Schema Definition

```sql
CREATE TABLE product_revision (
    -- Identity
    id_revision INT AUTO_INCREMENT PRIMARY KEY,
    id_product INT NOT NULL,
    
    -- Revision Identity
    version VARCHAR(20) NOT NULL,
    revision_code VARCHAR(50) NULL,
    
    -- Lineage
    derived_from_revision_id INT NULL,
    
    -- Intent
    revision_reason ENUM(
        'INITIAL',
        'FIX_ERROR',
        'OPTIMIZATION',
        'COST_REDUCTION',
        'MATERIAL_CHANGE',
        'CUSTOMER_SPECIFIC',
        'ENGINEERING_CHANGE'
    ) NOT NULL,
    revision_notes TEXT,
    
    -- Status
    status ENUM('draft', 'published', 'retired') NOT NULL DEFAULT 'draft',
    allow_new_jobs BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Binding
    graph_version_id INT NULL,
    
    -- Snapshot
    snapshot_json JSON NOT NULL COMMENT 'Frozen product metadata',
    components_json JSON NOT NULL COMMENT 'Frozen components + constraints',
    
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
    
    -- Indexes
    INDEX idx_product_version (id_product, version),
    INDEX idx_product_status (id_product, status),
    INDEX idx_product_active (id_product, status, allow_new_jobs),
    
    -- Foreign Keys
    FOREIGN KEY (id_product) REFERENCES product(id_product),
    FOREIGN KEY (graph_version_id) REFERENCES routing_graph_version(id_version),
    FOREIGN KEY (derived_from_revision_id) REFERENCES product_revision(id_revision),
    FOREIGN KEY (created_by) REFERENCES account(id_member),
    FOREIGN KEY (published_by) REFERENCES account(id_member),
    FOREIGN KEY (retired_by) REFERENCES account(id_member)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2. Snapshot JSON Structure

```json
{
    "product": {
        "id_product": 123,
        "sku": "PROD-001",
        "name": "Sample Product",
        "uom_base": "PCS",
        "material_category": "FINISHED_GOODS"
    },
    "snapshot_at": "2026-01-15T10:30:00Z"
}
```

### 3. Components JSON Structure

```json
{
    "components": [
        {
            "id_component": 1,
            "material_id": 456,
            "role_code": "MAIN_MATERIAL",
            "constraints": {
                "width": 100,
                "length": 200,
                "unit": "mm"
            },
            "computed_qty": 2.5
        }
    ],
    "snapshot_at": "2026-01-15T10:30:00Z"
}
```

---

## Acceptance Criteria

- [ ] Schema definition complete
- [ ] Clear separation Product vs Revision documented
- [ ] All fields have clear purpose and type
- [ ] Lineage structure supports full revision history
- [ ] Status lifecycle matches Graph Version pattern
- [ ] Can represent multiple revisions per product safely
- [ ] Snapshot structures defined

---

## Test Cases (Conceptual)

1. **Multiple Revisions per Product**
   - Product P1 can have v1.0, v2.0, v3.0 revisions
   - Each revision has own snapshot

2. **Lineage Tracking**
   - v2.0 has `derived_from_revision_id` pointing to v1.0
   - v3.0 has `derived_from_revision_id` pointing to v2.0

3. **Status Isolation**
   - Only one `published` + `allow_new_jobs=true` per product
   - Multiple `retired` allowed
   - Multiple `draft` NOT allowed (enforce in service)

---

## Reference Files

- `source/dag/Graph/Service/GraphVersionService.php` - Template
- `database/tenant_migrations/routing_graph_version_additive.php` - Schema reference
- `docs/super_dag/06-specs/OPERATIONAL_SAFETY_CHANGE_GOVERNANCE.md` - SPEC

---

**Next Task:** 29.2 (Define Revision Invariants Validation)
