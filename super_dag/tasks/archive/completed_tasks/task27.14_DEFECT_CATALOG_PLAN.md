# 27.14 Defect Catalog - Implementation Plan

> **Feature:** Standardized Defect Dictionary for QC  
> **Status:** ✅ **COMPLETE** (2025-12-05)  
> **Priority:** 🟠 HIGH (Required for QC Rework V2)  
> **Estimated Duration:** 4-5 Days (~35 hours)  
> **Actual Duration:** 1 Day  
> **Dependencies:** `component_type_catalog` (from 27.13.11b Material Architecture V2 ✅)  
> **Spec:** `01-concepts/DEFECT_CATALOG_SPEC.md`  
> **Policy Reference:** `docs/developer/01-policy/DEVELOPER_POLICY.md`  
> **API Reference:** `docs/API_DEFECT_CATALOG.md`  
> **Last Updated:** 2025-12-05 (Implementation Complete)

---

## 📐 Component Type Reference (from 27.13.11b)

**Available `type_code` values for `allowed_component_types`:**

| Category | Type Codes |
|----------|------------|
| **MAIN** | `BODY`, `FLAP`, `POCKET`, `GUSSET`, `BASE`, `DIVIDER`, `FRAME`, `PANEL` |
| **ACCESSORY** | `STRAP`, `HANDLE`, `ZIPPER_PANEL`, `ZIP_POCKET`, `LOOP`, `TONGUE`, `CLOSURE_TAB` |
| **INTERIOR** | `LINING`, `INTERIOR_PANEL`, `CARD_SLOT_PANEL` |
| **REINFORCEMENT** | `REINFORCEMENT`, `PADDING`, `BACKING` |
| **DECORATIVE** | `LOGO_PATCH`, `DECOR_PANEL`, `BADGE` |

**Example `allowed_component_types` values:**
```json
// Defect applies to all stitching-related components
["STRAP", "HANDLE", "BODY", "FLAP", "GUSSET"]

// Defect applies only to edge-finished components
["BODY", "FLAP", "STRAP"]

// Defect applies to ALL component types
null
```

---

## 📐 Enterprise Compliance Notes

**Per DEVELOPER_POLICY.md, all APIs MUST include:**
- ✅ `TenantApiBootstrap::init()` 
- ✅ `RateLimiter::check()` for all actions
- ✅ `RequestValidator::make()` for input validation
- ✅ Idempotency for create operations (`Idempotency::guard/store`)
- ✅ ETag/If-Match for update operations
- ✅ Maintenance mode check (`storage/maintenance.flag`)
- ✅ Execution time tracking (`$__t0 = microtime(true)`)
- ✅ `json_success()` / `json_error()` only
- ✅ i18n: `translate('key', 'English default')`

---

## 📊 Implementation Overview

```
┌─────────────────────────────────────────────────────────────────┐
│              DEFECT CATALOG: QUALITY LAYER                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 1: Database Layer                                          │
│  ├─ 27.14.1 Migration: defect_catalog table                    │
│  └─ 27.14.2 Migration: defect_category lookup                  │
│                                                                 │
│  Day 2: Service Layer                                           │
│  ├─ 27.14.3 DefectCatalogService (CRUD + query)                │
│  └─ 27.14.4 API: CRUD endpoints                                │
│                                                                 │
│  Day 3: Integration                                             │
│  ├─ 27.14.5 API: get_defects_for_component_type                │
│  └─ 27.14.6 API: suggest_rework_targets                        │
│                                                                 │
│  Day 4: Data + UI                                               │
│  ├─ 27.14.7 Seed: Common defects (30+)                         │
│  └─ 27.14.8 Admin UI: Defect catalog management                │
│                                                                 │
│  Day 5: QC UI + Tests                                           │
│  ├─ 27.14.9 QC UI: Defect selector in QC Fail form             │
│  └─ 27.14.10 Tests: Unit + Integration                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Task Details

---

### 27.14.1 Migration: defect_catalog table

**Duration:** 3 hours

**File:** `database/tenant_migrations/2025_12_defect_catalog.php`

```sql
CREATE TABLE defect_catalog (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Identity
    defect_code VARCHAR(50) NOT NULL UNIQUE 
        COMMENT 'Unique code e.g. STITCH_UNEVEN, GLUE_VISIBLE',
    
    -- Display (i18n)
    display_name_th VARCHAR(100) NOT NULL,
    display_name_en VARCHAR(100) NOT NULL,
    description_th TEXT NULL,
    description_en TEXT NULL,
    
    -- Classification
    category_code VARCHAR(30) NOT NULL 
        COMMENT 'FK to defect_category',
    severity ENUM('minor', 'major', 'critical') NOT NULL DEFAULT 'minor'
        COMMENT 'minor=cosmetic, major=functional, critical=safety',
    
    -- Component Type Association (JSON array of type_codes from component_type_catalog)
    allowed_component_types JSON NULL 
        COMMENT '["STRAP", "BODY", "HANDLE"] or null for all types',
    
    -- Rework Hints (JSON)
    rework_hints JSON NULL 
        COMMENT '{"suggested_operation": "STITCH", "rework_level": "same_piece"}',
    
    -- Metadata
    visual_guide_url VARCHAR(255) NULL 
        COMMENT 'URL to defect identification image',
    display_order INT DEFAULT 0,
    
    -- Status
    is_active TINYINT(1) DEFAULT 1,
    
    -- Audit
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NULL,
    
    -- Indexes
    INDEX idx_category (category_code),
    INDEX idx_severity (severity),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
  COMMENT='Standardized defect dictionary';
```

**Deliverables:**
- [ ] Table created
- [ ] JSON columns work
- [ ] Indexes created

---

### 27.14.2 Migration: defect_category lookup

**Duration:** 1 hour

```sql
CREATE TABLE defect_category (
    category_code VARCHAR(30) PRIMARY KEY,
    display_name_th VARCHAR(100) NOT NULL,
    display_name_en VARCHAR(100) NOT NULL,
    display_order INT DEFAULT 0,
    is_active TINYINT(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed categories
INSERT INTO defect_category VALUES
('STITCHING', 'ข้อบกพร่องการเย็บ', 'Stitching Defects', 10, 1),
('GLUING', 'ข้อบกพร่องการทากาว', 'Gluing Defects', 20, 1),
('CUTTING', 'ข้อบกพร่องการตัด', 'Cutting Defects', 30, 1),
('EDGE', 'ข้อบกพร่องขอบ', 'Edge Defects', 40, 1),
('SURFACE', 'ข้อบกพร่องผิว', 'Surface Defects', 50, 1),
('ASSEMBLY', 'ข้อบกพร่องการประกอบ', 'Assembly Defects', 60, 1),
('HARDWARE', 'ข้อบกพร่องอุปกรณ์', 'Hardware Defects', 70, 1),
('MATERIAL', 'ข้อบกพร่องวัสดุ', 'Material Defects', 80, 1);
```

**Deliverables:**
- [ ] Category table created
- [ ] 8 categories seeded

---

### 27.14.3 Service: DefectCatalogService

**Duration:** 4 hours

**File:** `source/BGERP/Service/DefectCatalogService.php`

```php
<?php
declare(strict_types=1);

namespace BGERP\Service;

class DefectCatalogService
{
    private \mysqli $db;
    
    public function __construct(\mysqli $db)
    {
        $this->db = $db;
    }
    
    // ==================== CATALOG CRUD ====================
    
    /**
     * Get all defects grouped by category
     */
    public function getAllGroupedByCategory(): array;
    
    /**
     * Get single defect by code
     */
    public function getByCode(string $code): ?array;
    
    /**
     * Create new defect
     */
    public function create(array $data): int;
    
    /**
     * Update existing defect
     */
    public function update(string $code, array $data): bool;
    
    /**
     * Deactivate defect
     */
    public function deactivate(string $code): bool;
    
    // ==================== COMPONENT TYPE FILTERING ====================
    
    /**
     * Get defects applicable to a component type
     * @param string $typeCode Type code from component_type_catalog (e.g., BODY, STRAP, FLAP)
     * @return array Defects where allowed_component_types is null or includes this type
     */
    public function getDefectsForComponentType(string $typeCode): array
    {
        $stmt = $this->db->prepare("
            SELECT d.*, c.display_name_th as category_name_th, c.display_name_en as category_name_en
            FROM defect_catalog d
            LEFT JOIN defect_category c ON c.category_code = d.category_code
            WHERE d.is_active = 1
            AND (
                d.allowed_component_types IS NULL 
                OR JSON_CONTAINS(d.allowed_component_types, ?, '$')
            )
            ORDER BY c.display_order, d.display_order
        ");
        
        $typeCodeJson = json_encode($typeCode);
        $stmt->bind_param('s', $typeCodeJson);
        $stmt->execute();
        
        return $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    }
    
    // ==================== REWORK SUGGESTIONS ====================
    
    /**
     * Suggest rework targets based on defect
     * @param string $defectCode
     * @param int $qcNodeId
     * @return array Suggested nodes with priority
     */
    public function suggestReworkTargets(string $defectCode, int $qcNodeId): array
    {
        $defect = $this->getByCode($defectCode);
        if (!$defect) {
            return [];
        }
        
        $hints = json_decode($defect['rework_hints'] ?? '{}', true);
        $suggestedOperation = $hints['suggested_operation'] ?? null;
        
        // Get rework targets from DAGRoutingService
        $dagService = new DAGRoutingService($this->db);
        $anchor = $dagService->findComponentAnchor($qcNodeId);
        
        if (!$anchor) {
            return [];
        }
        
        $candidates = $dagService->getNodesInComponent($anchor);
        
        // Prioritize by defect hint
        $prioritized = [];
        foreach ($candidates as $node) {
            $priority = 0;
            
            // Match by suggested operation
            if ($suggestedOperation && stripos($node['node_code'], $suggestedOperation) !== false) {
                $priority = 10;
            }
            
            // Match by behavior type
            $behaviorType = strtoupper($node['behavior_code'] ?? '');
            if ($suggestedOperation && $behaviorType === $suggestedOperation) {
                $priority = 20;
            }
            
            $prioritized[] = array_merge($node, ['suggestion_priority' => $priority]);
        }
        
        // Sort by priority descending
        usort($prioritized, fn($a, $b) => $b['suggestion_priority'] - $a['suggestion_priority']);
        
        return $prioritized;
    }
    
    // ==================== VALIDATION ====================
    
    /**
     * Validate defect data
     */
    public function validate(array $data, bool $isUpdate = false): array;
    
    // ==================== CATEGORIES ====================
    
    /**
     * Get all categories
     */
    public function getCategories(): array;
}
```

**Deliverables:**
- [ ] Service file created
- [ ] Component filtering works with JSON_CONTAINS
- [ ] Rework suggestions algorithm
- [ ] All methods tested

---

### 27.14.4-6 API Endpoints

**Duration:** 10 hours

**File:** `source/defect_catalog_api.php`

**Endpoints:**

| Action | Method | Description |
|--------|--------|-------------|
| `list` | GET | Get all defects (grouped by category) |
| `get` | GET | Get single defect by code |
| `create` | POST | Create new defect |
| `update` | POST | Update existing defect |
| `delete` | POST | Deactivate defect |
| `categories` | GET | Get all categories |
| `for_component_type` | GET | Get defects for a component type (from component_type_catalog) |
| `suggest_rework` | GET | Suggest rework targets for defect |
| `component_types` | GET | Get available component types for dropdown |

**Deliverables:**
- [ ] All endpoints implemented
- [ ] Rate limiting applied
- [ ] Permission checks
- [ ] Validation

---

### 27.14.7 Seed: Common Defects

**Duration:** 3 hours

**File:** `database/tenant_migrations/2025_12_seed_defect_catalog.php`

```php
// Format: [defect_code, name_th, name_en, category, severity, allowed_component_types, rework_hints]
$defects = [
    // STITCHING Category - applies to most components
    ['STITCH_UNEVEN', 'ตะเข็บไม่เท่ากัน', 'Uneven Stitching', 'STITCHING', 'minor', 
     '["BODY","FLAP","STRAP","HANDLE","GUSSET","POCKET"]', 
     '{"suggested_operation": "STITCH", "rework_level": "same_piece"}'],
    ['STITCH_LOOSE', 'ตะเข็บหลวม', 'Loose Stitching', 'STITCHING', 'major',
     '["BODY","FLAP","STRAP","HANDLE","GUSSET","POCKET"]', 
     '{"suggested_operation": "STITCH", "rework_level": "same_piece"}'],
    ['STITCH_BROKEN', 'ตะเข็บขาด', 'Broken Stitching', 'STITCHING', 'critical',
     null, // All component types
     '{"suggested_operation": "STITCH", "rework_level": "same_piece"}'],
    ['STITCH_SKIPPED', 'ตะเข็บข้ามไป', 'Skipped Stitches', 'STITCHING', 'major',
     null, 
     '{"suggested_operation": "STITCH", "rework_level": "same_piece"}'],
    
    // GLUING Category
    ['GLUE_VISIBLE', 'เห็นกาว', 'Visible Glue', 'GLUING', 'minor',
     null, 
     '{"suggested_operation": "GLUE", "rework_level": "same_piece"}'],
    ['GLUE_WEAK', 'กาวไม่ติด', 'Weak Bond', 'GLUING', 'major',
     '["BODY","FLAP","GUSSET","LINING","REINFORCEMENT"]', 
     '{"suggested_operation": "GLUE", "rework_level": "same_piece"}'],
    ['GLUE_EXCESS', 'กาวเกิน', 'Excess Glue', 'GLUING', 'minor',
     null, 
     '{"suggested_operation": "GLUE", "rework_level": "same_piece"}'],
    
    // CUTTING Category - applies to main structure components
    ['CUT_UNEVEN', 'ตัดไม่เท่า', 'Uneven Cut', 'CUTTING', 'major',
     '["BODY","FLAP","STRAP","GUSSET","BASE","PANEL"]', 
     '{"suggested_operation": "CUT", "rework_level": "recut"}'],
    ['CUT_WRONG_SIZE', 'ขนาดผิด', 'Wrong Size', 'CUTTING', 'critical',
     '["BODY","FLAP","STRAP","GUSSET","BASE","PANEL"]', 
     '{"suggested_operation": "CUT", "rework_level": "recut"}'],
    ['CUT_DAMAGED', 'ตัดเสียหาย', 'Cutting Damage', 'CUTTING', 'major',
     null, 
     '{"suggested_operation": "CUT", "rework_level": "recut"}'],
    
    // EDGE Category - applies to visible edges
    ['EDGE_ROUGH', 'ขอบไม่เรียบ', 'Rough Edge', 'EDGE', 'minor',
     '["BODY","FLAP","STRAP","HANDLE","POCKET"]', 
     '{"suggested_operation": "EDGE", "rework_level": "same_piece"}'],
    ['EDGE_UNFINISHED', 'ขอบไม่เสร็จ', 'Unfinished Edge', 'EDGE', 'major',
     '["BODY","FLAP","STRAP","HANDLE"]', 
     '{"suggested_operation": "EDGE", "rework_level": "same_piece"}'],
    ['EDGE_PAINT_UNEVEN', 'สีขอบไม่เท่า', 'Uneven Edge Paint', 'EDGE', 'minor',
     '["BODY","FLAP","STRAP","HANDLE","POCKET","GUSSET"]', 
     '{"suggested_operation": "EDGE", "rework_level": "same_piece"}'],
    
    // SURFACE Category - applies to visible surfaces
    ['SURFACE_SCRATCH', 'รอยขีดข่วน', 'Surface Scratch', 'SURFACE', 'minor',
     '["BODY","FLAP","STRAP","HANDLE"]', 
     '{"suggested_operation": "POLISH", "rework_level": "same_piece"}'],
    ['SURFACE_STAIN', 'รอยเปื้อน', 'Surface Stain', 'SURFACE', 'major',
     null, 
     '{"suggested_operation": "CLEAN", "rework_level": "same_piece"}'],
    
    // ASSEMBLY Category
    ['ASSEMBLY_MISALIGNED', 'ประกอบไม่ตรง', 'Misaligned Assembly', 'ASSEMBLY', 'major',
     '["BODY","FLAP","STRAP","HANDLE","CLOSURE_TAB"]', 
     '{"suggested_operation": "ASSEMBLE", "rework_level": "disassemble"}'],
    
    // HARDWARE Category
    ['HARDWARE_LOOSE', 'อุปกรณ์หลวม', 'Loose Hardware', 'HARDWARE', 'major',
     '["STRAP","HANDLE","CLOSURE_TAB","ZIPPER_PANEL"]', 
     '{"suggested_operation": "HARDWARE", "rework_level": "same_piece"}'],
    
    // ... more defects (30+ total)
];
```

**Deliverables:**
- [ ] 30+ defects seeded
- [ ] All categories represented
- [ ] rework_hints populated
- [ ] allowed_component_types set where applicable (using type_codes: BODY, STRAP, FLAP, etc.)

---

### 27.14.8-9 UI: Admin + QC Selector

**Duration:** 10 hours

**Admin UI Features:**
- DataTable with server-side processing
- Filter by category/severity
- Create/Edit modal with JSON editors
- Visual guide upload

**QC Fail Form Integration:**

```javascript
// In QC Behavior when FAIL is selected
// typeCode comes from the current node's anchor_slot → component_type_catalog.type_code
async function loadDefectSelector(typeCode) {
    const response = await fetch(`/source/defect_catalog_api.php?action=for_component_type&type_code=${typeCode}`);
    const data = await response.json();
    
    if (data.ok) {
        renderDefectDropdown(data.defects);
    }
}

function renderDefectDropdown(defects) {
    const grouped = groupByCategory(defects);
    
    // Render grouped dropdown
    // [STITCHING]
    //   - Uneven Stitching (minor)
    //   - Loose Stitching (major)
    // [GLUING]
    //   - Visible Glue (minor)
    // ...
}
```

**Component Type Resolution:**
```
Token → Node → anchor_slot → component_type_catalog.type_code
e.g., Token at "CUT_BODY" → anchor_slot="BODY" → type_code="BODY"
```

**Deliverables:**
- [ ] Admin UI functional
- [ ] QC Fail form has defect dropdown
- [ ] Defects filtered by component type (from component_type_catalog)
- [ ] Severity badges shown

---

### 27.14.10 Tests

**Duration:** 4 hours

```php
class DefectCatalogServiceTest extends TestCase
{
    public function testGetDefectsForComponentTypeReturnsFiltered(): void;
    public function testGetDefectsForComponentTypeReturnsAllIfNullTypes(): void;
    public function testSuggestReworkTargetsPrioritizesByHint(): void;
    public function testCreateDefectValidatesCategory(): void;
    public function testAllowedComponentTypesJsonValidation(): void;
    public function testValidTypeCodeFromComponentTypeCatalog(): void;
}

class DefectCatalogApiTest extends TestCase
{
    public function testListReturnsGroupedDefects(): void;
    public function testForComponentTypeFiltersCorrectly(): void;
    public function testSuggestReworkReturnsOrderedList(): void;
    public function testComponentTypesEndpointReturnsAllTypes(): void;
}
```

**Deliverables:**
- [ ] 10+ unit tests
- [ ] 5+ integration tests
- [ ] All tests passing

---

## ✅ Definition of Done

- [ ] `defect_catalog` table with JSON columns (`allowed_component_types`)
- [ ] `defect_category` lookup table
- [ ] `DefectCatalogService` with component type filtering
- [ ] Rework suggestion algorithm
- [ ] 30+ defects seeded
- [ ] Admin UI for management
- [ ] QC Fail form uses defect selector (filtered by component type)
- [ ] 15+ tests passing

---

## 🔗 Dependencies

**Requires:**
- ✅ `component_type_catalog` (from 27.13.11b - **COMPLETE**)
  - 24 component types (BODY, STRAP, FLAP, HANDLE, POCKET, etc.)
  - Used for `allowed_component_types` validation

**Blocks:**
- 27.15 QC Rework V2 (uses defect-based suggestions)

---

## 📚 Related Documents

- [DEFECT_CATALOG_SPEC.md](../01-concepts/DEFECT_CATALOG_SPEC.md)
- [QC_REWORK_PHILOSOPHY_V2.md](../01-concepts/QC_REWORK_PHILOSOPHY_V2.md)
- [MASTER_IMPLEMENTATION_ROADMAP.md](./MASTER_IMPLEMENTATION_ROADMAP.md)

