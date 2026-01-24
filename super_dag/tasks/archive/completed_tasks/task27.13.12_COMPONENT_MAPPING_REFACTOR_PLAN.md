# Task 27.13.12: Component Mapping Refactor

> **Created:** 2025-12-06  
> **Status:** ✅ CTO APPROVED (95% ready)  
> **CTO Review:** 2025-12-06  
> **Estimated Time:** 2-3 hours

---

## 🎯 CTO Final Decisions (2025-12-06)

| # | Decision | Detail |
|---|----------|--------|
| 1 | `expected_component_type` | **Manual input** — ไม่ auto-fill จาก anchor_slot |
| 2 | Data เดิมใน `graph_component_mapping` | **Truncate** ก่อน migrate V2 |
| 3 | `product_component.component_code` | **Unique per product** — ต้อง generate ใหม่ไม่ใช่ semi-physical |
| 4 | Duplicate: component_code | **Regenerate** ไม่ใช่ copy ของเก่า |
| 5 | UI ถ้าไม่มี product_component | **Block mapping** + redirect to Tab Components |

---

## ✅ AUDIT: สิ่งที่ทำเสร็จแล้ว (Task 27.13.11b)

| รายการ | สถานะ | หมายเหตุ |
|--------|--------|----------|
| Schema: `product_component` | ✅ | ครบทุก column |
| Schema: `product_component_material` | ✅ | ครบทุก column |
| Schema: `component_type_catalog` | ✅ | ครบทุก column |
| Seed: 24 Component Types | ✅ | มีครบ 5 categories |
| Service: `ProductComponentService` | ✅ | CRUD + BOM |
| Service: `ComponentMappingService` | ✅ | Basic version |
| API: `get_component_types` | ✅ | Load Layer 1 types |
| API: `get_product_components` | ✅ | Load Layer 2 components |
| API: `save_component` | ✅ | CRUD |
| UI: Tab Components | ✅ | Complete (CRUD + BOM + Select2) |
| UI: Tab Component Mapping | ⚠️ | มี แต่เลือก Type ไม่ใช่ Component |

---

## 📋 สรุปปัญหาปัจจุบัน

### ปัญหาที่เหลือ 3 ข้อ

| # | ปัญหา | ผลกระทบ |
|---|-------|---------|
| 1 | `graph_component_mapping` ไม่มี `id_product`, `id_product_component` | ทุก Product share mapping + ไม่ link กับ BOM |
| 2 | Dropdown ใน Tab Component Mapping เลือก "Component Type" | ต้องเปลี่ยนเป็น "Product Component" |
| 3 | `handleDuplicate()` ไม่ได้ dup Components, BOM, Mapping | Product ใหม่ไม่มี component data |

---

## 🎯 เป้าหมาย

1. **Mapping scope per Product** — แต่ละ Product มี mapping ของตัวเอง
2. **Link to Product Component** — map ไปหา `product_component` ไม่ใช่ `component_type`
3. **Duplicate ครบถ้วน** — dup ทั้ง Components, BOM, Mapping
4. **Modal เลือก** — user เลือกได้ว่าจะ dup อะไรบ้าง

---

## 🗂️ PART 1: Schema Changes

### 1.1 เพิ่ม `expected_component_type` ใน `routing_node`

**เหตุผล:** เพื่อ validate ว่า anchor_slot ต้อง map กับ component ประเภทใด

```sql
ALTER TABLE routing_node 
ADD COLUMN expected_component_type VARCHAR(30) NULL 
COMMENT 'Expected component type (Layer 1) - Designer selects manually';
```

**✅ CTO Decision:**
- **ไม่ต้อง backfill อัตโนมัติ** — NULL allowed
- **Designer กำหนดเอง** ตอนสร้าง graph → เลือก node_type = component แล้วเลือก expected_component_type
- **แยกกันชัดเจน:**
  - `anchor_slot` = ตำแหน่งใน flow (SLOT_A, BODY1, PANEL_A...)
  - `expected_component_type` = ประเภทของชิ้นส่วนที่ควรต่อเข้า slot นี้ (BODY, FLAP, STRAP...)

---

### 1.2 เพิ่ม columns ใน `graph_component_mapping`

**เหตุผล:** scope mapping per product และ link กับ Product Component

```sql
-- เพิ่ม id_product (scope per product)
ALTER TABLE graph_component_mapping 
ADD COLUMN id_product INT NULL 
COMMENT 'FK to product (scope mapping per product)';

-- เพิ่ม id_product_component (link to real component)
ALTER TABLE graph_component_mapping 
ADD COLUMN id_product_component INT NULL 
COMMENT 'FK to product_component.id_product_component (Layer 2)';

-- FK constraints
ALTER TABLE graph_component_mapping
ADD CONSTRAINT fk_mapping_product 
FOREIGN KEY (id_product) 
REFERENCES product(id_product)
ON DELETE CASCADE;

ALTER TABLE graph_component_mapping
ADD CONSTRAINT fk_mapping_product_component 
FOREIGN KEY (id_product_component) 
REFERENCES product_component(id_product_component)
ON DELETE SET NULL;

-- Unique constraint: 1 slot per product-graph
ALTER TABLE graph_component_mapping
ADD UNIQUE KEY uk_product_graph_slot (id_product, id_graph, anchor_slot);

-- Index for performance
CREATE INDEX idx_mapping_product ON graph_component_mapping(id_product);
```

**✅ CTO Decision:**
- **Truncate `graph_component_mapping` ก่อน migrate V2**
- เพื่อหลีกเลี่ยง ghost data จากระบบ dev
- ไม่มี production data ที่ต้อง migrate

---

### 1.3 ~~Seed 24 Component Types~~ ✅ มีครบแล้ว!

**สถานะ:** ไม่ต้องทำ — มี 24 types ครบแล้วในฐานข้อมูล

```
✅ BODY, FLAP, POCKET, GUSSET, BASE, DIVIDER, FRAME, PANEL
✅ STRAP, HANDLE, ZIPPER_PANEL, ZIP_POCKET, LOOP, TONGUE, CLOSURE_TAB  
✅ LINING, INTERIOR_PANEL, CARD_SLOT_PANEL
✅ REINFORCEMENT, PADDING, BACKING
✅ LOGO_PATCH, DECOR_PANEL, BADGE
```

**Seeded by:** `0002_seed_data.php` (Line 861-942)

---

## 🔧 PART 2: Service Changes

### 2.1 แก้ `ComponentMappingService`

**ไฟล์:** `source/BGERP/Service/ComponentMappingService.php`

**การเปลี่ยนแปลง:**

| Method | เดิม | ใหม่ |
|--------|------|------|
| `getMappingsForGraph()` | `WHERE id_graph = ?` | `WHERE id_graph = ? AND id_product = ?` |
| `setMapping()` | ไม่มี product | เพิ่ม `id_product`, `id_product_component` |
| `resolveComponentCode()` | Return `component_code` | Return `id_product_component` หรือทั้งคู่ |

**New/Renamed Methods:**

```php
/**
 * Get all mappings for a product + graph combination
 */
public function getMappingsForProductGraph(int $productId, int $graphId): array

/**
 * ✅ RENAMED: resolveComponentCode → resolveProductComponent
 * Returns full component data, not just code
 */
public function resolveProductComponent(int $productId, int $graphId, string $anchorSlot): ?array
// Returns: id_product_component, component_type, display_name, BOM

/**
 * Set mapping with product component (V2)
 */
public function setMappingV2(
    int $productId,
    int $graphId, 
    string $anchorSlot, 
    int $productComponentId,
    ?int $userId = null,
    ?string $notes = null
): int

/**
 * Duplicate all mappings from one product to another
 */
public function duplicateMappingsToProduct(
    int $sourceProductId,
    int $targetProductId,
    array $componentIdMap // Old → New component ID mapping
): int
```

**✅ CTO Decision:**
- **Deprecate** methods เดิมที่ใช้ `component_code`
- ใช้ V2 methods ที่ใช้ `id_product_component` เท่านั้น

---

### 2.2 เพิ่ม API Endpoints ใน `product_api.php`

**New Actions:**

```php
case 'get_product_components_for_mapping':
    // Get product components for dropdown in Component Mapping tab
    // Filter by: id_product, expected_component_type (optional)
    // Return: id_product_component, component_code, component_type_code, display_name
    break;

case 'save_component_mapping_v2':
    // Save mapping: anchor_slot → id_product_component
    // Validate: component type must match expected_component_type
    break;

case 'get_component_mappings_for_product':
    // Get all mappings for a product (with graph info)
    break;
```

---

## 📦 PART 3: Duplicate Function

### 3.1 Current State (ใน `handleDuplicate()`)

| สิ่งที่ Dup | Line | Status |
|-------------|------|--------|
| Product basic info | 807-856 | ✅ |
| Product assets | 865-967 | ✅ |
| Product graph binding | 973-1001 | ✅ |
| Product components | - | ❌ ต้องเพิ่ม |
| Product component materials | - | ❌ ต้องเพิ่ม |
| Graph component mapping | - | ❌ ต้องเพิ่ม |

---

### 3.2 New Duplicate Logic

**✅ CTO Decision:** `component_code` ต้อง **regenerate** ไม่ใช่ copy ของเก่า

```php
// After creating new product...

// Get new product SKU for generating component codes
$newProductSku = $result['sku']; // e.g., "AM25-DRAFT-20251206"
$skuPrefix = substr(preg_replace('/[^A-Z0-9]/', '', strtoupper($newProductSku)), 0, 10);

// 1. Duplicate product_component with NEW component_code
$componentIdMap = []; // old_id => new_id
$componentsStmt = $db->prepare("
    SELECT * FROM product_component WHERE id_product = ?
");
$componentsStmt->bind_param('i', $sourceProductId);
$componentsStmt->execute();
$components = $componentsStmt->get_result();

while ($comp = $components->fetch_assoc()) {
    // ✅ Generate NEW component_code (unique per product)
    $newComponentCode = $skuPrefix . '_' . $comp['component_type_code'];
    // e.g., "AM25DRAFT20_BODY", "AM25DRAFT20_FLAP"
    
    $insertCompStmt = $db->prepare("
        INSERT INTO product_component 
        (id_product, component_code, component_name, component_type_code, 
         pattern_size, pattern_code, edge_width_mm, stitch_count,
         estimated_time_minutes, notes, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $insertCompStmt->bind_param(
        'isssssdiiis',
        $newProductId,
        $newComponentCode,  // ✅ NEW code, not copied!
        $comp['component_name'],
        $comp['component_type_code'],
        $comp['pattern_size'],
        $comp['pattern_code'],
        $comp['edge_width_mm'],
        $comp['stitch_count'],
        $comp['estimated_time_minutes'],
        $comp['notes'],
        $memberId
    );
    $insertCompStmt->execute();
    $newCompId = $db->insert_id;
    $componentIdMap[$comp['id_product_component']] = $newCompId;
    $insertCompStmt->close();
    
    // 2. Duplicate product_component_material for this component
    $materialsStmt = $db->prepare("
        SELECT * FROM product_component_material 
        WHERE id_product_component = ?
    ");
    $materialsStmt->bind_param('i', $comp['id_product_component']);
    $materialsStmt->execute();
    $materials = $materialsStmt->get_result();
    
    while ($mat = $materials->fetch_assoc()) {
        $insertMatStmt = $db->prepare("
            INSERT INTO product_component_material 
            (id_product_component, material_sku, qty_required, uom_code, 
             is_primary, priority, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        $insertMatStmt->bind_param(
            'isdsiis',
            $newCompId,  // New component ID
            $mat['material_sku'],
            $mat['qty_required'],
            $mat['uom_code'],
            $mat['is_primary'],
            $mat['priority'],
            $mat['notes']
        );
        $insertMatStmt->execute();
        $insertMatStmt->close();
    }
    $materialsStmt->close();
}

// 3. Duplicate graph_component_mapping (using new component IDs)
$mappingService = new ComponentMappingService($db);
$mappingService->duplicateMappingsToProduct(
    $sourceProductId,
    $newProductId,
    $componentIdMap  // Maps old → new component IDs
);
```

---

### 3.3 Duplicate Options Modal

**UI Concept:**

```
┌────────────────────────────────────────────────────┐
│  📋 Duplicate Product                              │
│  สำเนาสินค้า: Aimee Mini Greentea                   │
├────────────────────────────────────────────────────┤
│                                                    │
│  เลือกข้อมูลที่ต้องการสำเนา:                        │
│                                                    │
│  ☑ ข้อมูลพื้นฐาน                                   │
│     (ชื่อ, รหัส, รายละเอียด, หมวดหมู่)               │
│                                                    │
│  ☑ รูปภาพสินค้า                                    │
│     (รูปทั้งหมด จะถูกคัดลอกไปยังสินค้าใหม่)          │
│                                                    │
│  ☑ Graph Binding                                  │
│     (การเชื่อมต่อกับ Routing Graph)                 │
│                                                    │
│  ☑ Components & BOM                               │
│     (ชิ้นส่วนทั้งหมดและรายการวัสดุ)                  │
│                                                    │
│  ☑ Component Mapping                              │
│     (การจับคู่ Anchor Slot กับ Components)          │
│     ⚠️ ต้องติ๊ก "Components & BOM" ด้วย            │
│                                                    │
├────────────────────────────────────────────────────┤
│                                                    │
│  SKU สินค้าใหม่: AIMEE-MINI-GT-DRAFT-20251206...   │
│                                                    │
│  [ยกเลิก]                        [Duplicate]       │
│                                                    │
└────────────────────────────────────────────────────┘
```

**Checkbox Dependencies (✅ CTO Approved):**

| Option | Depends On | Default | Notes |
|--------|------------|---------|-------|
| ข้อมูลพื้นฐาน | - | ☑️ checked | Always required (disabled) |
| รูปภาพสินค้า | - | ☑️ checked | Optional |
| Graph Binding | - | ☑️ checked | Required for Mapping |
| Components & BOM | - | ☑️ checked | Required for Mapping |
| Component Mapping | Graph + Components | ☑️ checked | Auto-disable if either unchecked |

**✅ CTO Decisions:**
- **Default:** ติ๊กหมด
- **Graph unchecked + Mapping checked:** Block (ต้อง bind graph ก่อน)
- **Components unchecked + Mapping checked:** Block (ต้องมี components ก่อน)

---

## 🖥️ PART 4: UI Changes

### 4.1 แก้ `product_graph_binding.js`

**ปัจจุบัน:**
- Dropdown โหลดจาก `get_component_types` (Layer 1)
- แสดง: BODY, STRAP, FLAP...

**ต้องแก้เป็น:**
- Dropdown โหลดจาก `get_product_components_for_mapping` (Layer 2)
- แสดง: AIMEE_MINI_BODY (BODY), AIMEE_MINI_STRAP (STRAP)...

```javascript
// OLD
function loadComponentCatalog() {
    $.post('source/product_api.php', { action: 'get_component_types' }, ...);
}

// NEW
function loadProductComponentsForSlot(productId, anchorSlot, expectedType) {
    return $.post('source/product_api.php', { 
        action: 'get_product_components_for_mapping',
        product_id: productId,
        expected_type: expectedType // Filter by type
    });
}
```

---

### 4.2 Empty State Handling (✅ CTO Approved)

**✅ CTO Decision:** ถ้าไม่มี `product_component` → **Block mapping** และ redirect to Tab Components

**ถ้ายังไม่มี Product Components:**

```html
<div class="alert alert-warning text-center py-4">
    <i class="fe fe-alert-triangle fs-3 mb-2 d-block"></i>
    <strong>ยังไม่มี Product Components</strong>
    <p class="mb-3 text-muted">กรุณาสร้าง Component ในแท็บ "Components" ก่อนทำ Mapping</p>
    <button class="btn btn-primary" onclick="switchToComponentsTab()">
        <i class="fe fe-arrow-right me-1"></i> ไปที่ Tab Components
    </button>
</div>
```

**ถ้าไม่มี Component ที่ตรง type:**

```html
<div class="alert alert-info">
    <i class="fe fe-info me-2"></i>
    ยังไม่มี Component ประเภท <strong>STRAP</strong>
    <button class="btn btn-sm btn-outline-primary ms-2" onclick="createQuickComponent('STRAP')">
        <i class="fe fe-plus me-1"></i> สร้าง STRAP
    </button>
</div>
```

**Switch Tab Function:**

```javascript
function switchToComponentsTab() {
    // Switch to Components tab
    const tab = document.querySelector('#product-components-tab');
    if (tab) {
        const bsTab = new bootstrap.Tab(tab);
        bsTab.show();
    }
}
```

---

### 4.3 Duplicate Modal Implementation

**ไฟล์:** `assets/javascripts/products/product_duplicate.js` (ใหม่)

```javascript
function showDuplicateModal(productId, productName) {
    Swal.fire({
        title: 'สำเนาสินค้า',
        html: `
            <div class="text-start">
                <p class="mb-3">สินค้า: <strong>${productName}</strong></p>
                <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" id="dup_basic" checked disabled>
                    <label class="form-check-label" for="dup_basic">
                        ข้อมูลพื้นฐาน <span class="text-muted">(จำเป็น)</span>
                    </label>
                </div>
                <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" id="dup_assets" checked>
                    <label class="form-check-label" for="dup_assets">รูปภาพสินค้า</label>
                </div>
                <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" id="dup_graph" checked>
                    <label class="form-check-label" for="dup_graph">Graph Binding</label>
                </div>
                <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" id="dup_components" checked>
                    <label class="form-check-label" for="dup_components">Components & BOM</label>
                </div>
                <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" id="dup_mapping" checked>
                    <label class="form-check-label" for="dup_mapping">Component Mapping</label>
                    <small class="d-block text-muted ms-4">ต้องติ๊ก Components & BOM ด้วย</small>
                </div>
            </div>
        `,
        showCancelButton: true,
        confirmButtonText: 'Duplicate',
        cancelButtonText: 'ยกเลิก',
        didOpen: () => {
            // Dependency logic
            document.getElementById('dup_components').addEventListener('change', (e) => {
                const mappingCheckbox = document.getElementById('dup_mapping');
                if (!e.target.checked) {
                    mappingCheckbox.checked = false;
                    mappingCheckbox.disabled = true;
                } else {
                    mappingCheckbox.disabled = false;
                }
            });
        },
        preConfirm: () => {
            return {
                assets: document.getElementById('dup_assets').checked,
                graph: document.getElementById('dup_graph').checked,
                components: document.getElementById('dup_components').checked,
                mapping: document.getElementById('dup_mapping').checked
            };
        }
    }).then((result) => {
        if (result.isConfirmed) {
            duplicateProduct(productId, result.value);
        }
    });
}
```

---

## 📋 PART 5: Migration File

**ไฟล์:** `database/tenant_migrations/2025_12_component_mapping_refactor.php`

```php
<?php
/**
 * Migration: Component Mapping Refactor
 * Task 27.13.12
 * 
 * Changes:
 * 1. Add expected_component_type to routing_node
 * 2. Add id_product, id_product_component to graph_component_mapping
 * 3. Seed 24 component types
 */

require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    
    // ✅ CTO Decision: Truncate ghost data before V2 migration
    // 0. TRUNCATE graph_component_mapping (dev data only, no production data)
    echo "Truncating graph_component_mapping (dev data cleanup)...\n";
    $db->query("TRUNCATE TABLE graph_component_mapping");
    
    // 1. routing_node: add expected_component_type
    migration_add_column_if_missing(
        $db,
        'routing_node',
        'expected_component_type',
        '`expected_component_type` VARCHAR(30) NULL COMMENT "Expected component type (Layer 1) - Designer selects manually" AFTER `anchor_slot`'
    );
    
    // 2. graph_component_mapping: add id_product
    migration_add_column_if_missing(
        $db,
        'graph_component_mapping',
        'id_product',
        '`id_product` INT NULL COMMENT "FK to product (scope per product)" AFTER `id_graph`'
    );
    
    // 3. graph_component_mapping: add id_product_component
    migration_add_column_if_missing(
        $db,
        'graph_component_mapping',
        'id_product_component',
        '`id_product_component` INT NULL COMMENT "FK to product_component (Layer 2)" AFTER `component_code`'
    );
    
    // 4. Add indexes
    migration_add_index_if_missing(
        $db,
        'graph_component_mapping',
        'idx_mapping_product',
        'INDEX `idx_mapping_product` (`id_product`)'
    );
    
    // 5. Add unique constraint (safe now after truncate)
    migration_add_index_if_missing(
        $db,
        'graph_component_mapping',
        'uk_product_graph_slot',
        'UNIQUE KEY `uk_product_graph_slot` (`id_product`, `id_graph`, `anchor_slot`)'
    );
    
    // 6. Component types already seeded (24 types) - SKIP
    // See: 0002_seed_data.php (Line 861-942)
    
    echo "Migration 2025_12_component_mapping_refactor completed.\n";
};
```

---

## ✅ PART 6: Checklist

### Before Implementation

- [ ] CTO ยืนยัน schema changes
- [ ] CTO ยืนยัน duplicate modal design
- [ ] CTO ตอบคำถามทั้งหมด

### Implementation

- [ ] Migration file
- [ ] ComponentMappingService changes
- [ ] product_api.php new endpoints
- [ ] handleDuplicate() changes
- [ ] product_graph_binding.js changes
- [ ] product_duplicate.js (new)

### Testing

- [ ] Migration runs without error
- [ ] New mapping flow works (product → component)
- [ ] Duplicate with all options checked
- [ ] Duplicate with partial options
- [ ] UI empty states

### Documentation

- [ ] Update PRODUCT_COMPONENT_ARCHITECTURE.md
- [ ] Update API_REFERENCE.md
- [ ] Create results file

---

## ✅ คำถามทั้งหมด — CTO ตอบแล้ว

| # | คำถาม | ✅ CTO Answer |
|---|-------|--------------|
| 1 | Backfill `expected_component_type` | **NULL** — Designer กำหนดเอง manual |
| 2 | Data เดิมใน `graph_component_mapping` | **Truncate** — ลบ dev data ก่อน migrate |
| 3 | Default checkboxes ใน Duplicate Modal | **ติ๊กหมด** (default) |
| 4 | Graph unchecked + Mapping checked | **Block** — ต้อง bind graph ก่อน |
| 5 | ComponentMappingService methods เดิม | **Deprecate** — ใช้ V2 เท่านั้น |
| 6 | component_code ตอน duplicate | **Regenerate** — unique per product |

---

## ⏱️ ประมาณการเวลา (หลังยืนยัน)

| Part | รายละเอียด | เวลา | หมายเหตุ |
|------|------------|------|----------|
| 1 | Migration (3 columns) | 15 min | ลดลงเพราะไม่ต้อง seed |
| 2 | Service changes | 30 min | อัพเดท ComponentMappingService |
| 3 | API (1 endpoint) | 15 min | get_product_components_for_mapping |
| 4 | UI Dropdown | 30 min | แก้ product_graph_binding.js |
| 5 | Duplicate function | 45 min | dup Components, BOM, Mapping |
| 6 | Duplicate Modal | 20 min | Checkbox options |
| 7 | Testing | 25 min | |
| **Total** | | **~3 hours** | (ลดลงจาก 3.5 hours) |

---

*Created: 2025-12-06*  
*Author: AI Agent*  
*Pending: CTO Review*

