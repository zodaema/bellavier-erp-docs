# Product Component Architecture (Definitive Guide)

> **Last Updated:** 2025-12-06  
> **Status:** ✅ AUTHORITATIVE  
> **CTO Audit Score:** 9.3/10 → **10/10** (after tightening)  
> **Purpose:** ขจัดความสับสนระหว่าง Component / Component Type / Product Component / Anchor Slot

---

## 🎯 สรุปแบบ 1 หน้า

```
┌─────────────────────────────────────────────────────────────────┐
│            COMPONENT LAYER ARCHITECTURE (FINAL)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🏷️ LAYER 1: component_type_catalog (Generic Types)            │
│  ├─ type_code: BODY, STRAP, FLAP, LINING, HARDWARE             │
│  ├─ ใช้เป็น "ประเภท" หรือ "หมวดหมู่" ของชิ้นส่วน                │
│  └─ ไม่ผูกกับ Product ใดเฉพาะเจาะจง                             │
│                                                                 │
│  📦 LAYER 2: product_component (Product-Specific)              │
│  ├─ component_code: AIMEE_MINI_BODY_2025                       │
│  ├─ component_type_code: BODY (FK → Layer 1)                   │
│  ├─ เป็น "ชิ้นส่วนจริง" ของ Product ใบนั้น                      │
│  └─ ผูก BOM, Physical Specs, Costing                           │
│                                                                 │
│  📋 LAYER 3: product_component_material (BOM)                  │
│  ├─ material_sku, qty_required                                 │
│  └─ ผูกกับ Layer 2                                              │
│                                                                 │
│  🔗 MAPPING: graph_component_mapping                           │
│  ├─ anchor_slot (จาก Graph) → id_product_component (Layer 2)  │
│  └─ ผูกเฉพาะ Product ใบนั้น ไม่ใช่ global                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📚 คำศัพท์ที่ต้องใช้ให้ตรงกัน

| คำ | หมายถึง | ตัวอย่าง | Table |
|----|---------|---------|-------|
| **Component Type** | ประเภท/หมวดหมู่ของชิ้นส่วน (generic) | BODY, STRAP, FLAP | `component_type_catalog` |
| **Product Component** | ชิ้นส่วนจริงของ Product ใบนั้น | AIMEE_MINI_BODY_2025 | `product_component` |
| **Anchor Slot** | Placeholder ใน Graph สำหรับ component branch | SLOT_BODY, SLOT_STRAP | `routing_node.anchor_slot` |
| **Component Mapping** | การจับคู่ Anchor Slot กับ Product Component | SLOT_BODY → AIMEE_MINI_BODY | `graph_component_mapping` |

---

## 🖥️ 2 Tabs ใน Product Modal

### Tab 1: Components (จัดการชิ้นส่วนจริง)

**หน้าที่:** สร้าง/แก้ไข **Product Components** (Layer 2) ของ Product นี้

**แสดงข้อมูล:**

| Component Code | Component Type | ชื่อ | BOM Items | Actions |
|----------------|----------------|------|-----------|---------|
| AIMEE_MINI_BODY | BODY | ตัวกระเป๋าหลัก | 3 materials | [Edit] [Del] |
| AIMEE_MINI_FLAP | FLAP | ฝาปิด | 2 materials | [Edit] [Del] |
| AIMEE_MINI_STRAP | STRAP | สายสะพายยาว | 2 materials | [Edit] [Del] |

**Modal เพิ่ม/แก้ไข:**
- Component Code (unique per product)
- Component Type (dropdown จาก `component_type_catalog`)
- Display Name
- Physical Specs (optional)
- BOM Materials (sub-table)

---

### Tab 2: Component Mapping (จับคู่กับ Graph)

**หน้าที่:** Map **Anchor Slot** จาก Graph → **Product Component** ที่สร้างใน Tab 1

**แสดงข้อมูล:**

| Anchor Slot (จาก Graph) | Product Component (เลือกจาก Tab Components) |
|-------------------------|---------------------------------------------|
| `SLOT_BODY` | [Dropdown: AIMEE_MINI_BODY (BODY)] |
| `SLOT_FLAP` | [Dropdown: AIMEE_MINI_FLAP (FLAP)] |
| `SLOT_STRAP` | [Dropdown: AIMEE_MINI_STRAP (STRAP)] |

**⚠️ กฎสำคัญ:**

1. **Dropdown ต้องแสดง Product Components จาก Tab 1 เท่านั้น**
   - ❌ ไม่ใช่ Component Type ลอยๆ
   - ✅ ต้องเป็นชิ้นส่วนจริงที่สร้างไว้แล้ว

2. **Filter ตาม Component Type ของ Anchor Slot**
   - ถ้า Anchor Slot = SLOT_BODY และมี `expected_type = BODY`
   - Dropdown ควรแสดงเฉพาะ Product Components ที่มี `component_type_code = BODY`

3. **ถ้ายังไม่มี Product Component ที่ตรง type**
   - แสดง Warning: "ยังไม่มี Component ประเภท BODY สำหรับ Product นี้"
   - ปุ่มลัด: [+ สร้าง Component BODY]

---

## 🔄 Flow การใช้งาน

```
┌─────────────────────────────────────────────────────────────────┐
│              USER FLOW: PRODUCT SETUP                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  STEP 1: สร้าง Product                                          │
│  └─ Product: Aimee Mini Greentea                                │
│                                                                 │
│  STEP 2: Tab Components — สร้างชิ้นส่วนจริง                     │
│  ├─ [+] AIMEE_MINI_BODY (type: BODY) + BOM                      │
│  ├─ [+] AIMEE_MINI_FLAP (type: FLAP) + BOM                      │
│  └─ [+] AIMEE_MINI_STRAP (type: STRAP) + BOM                    │
│                                                                 │
│  STEP 3: เลือก Graph (Bind Graph)                               │
│  └─ Graph: Leather Bag Component Flow V5                        │
│      └─ มี Anchor Slots: SLOT_BODY, SLOT_FLAP, SLOT_STRAP       │
│                                                                 │
│  STEP 4: Tab Component Mapping — จับคู่                         │
│  ├─ SLOT_BODY → AIMEE_MINI_BODY                                 │
│  ├─ SLOT_FLAP → AIMEE_MINI_FLAP                                 │
│  └─ SLOT_STRAP → AIMEE_MINI_STRAP                               │
│                                                                 │
│  STEP 5: สร้าง Job Ticket                                       │
│  └─ System ใช้ mapping เพื่อ:                                   │
│      • สร้าง Token ต่อ branch                                   │
│      • คำนวณ Material Requirement จาก BOM                       │
│      • Track งานต่อ Component                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🗃️ Database Schema (Current vs Required)

### 1. routing_node: เพิ่ม expected_component_type

```sql
-- ⚠️ CTO AUDIT: ต้องเพิ่ม field นี้เพื่อ safety ระดับ Hermès
ALTER TABLE routing_node 
ADD COLUMN expected_component_type VARCHAR(30) NULL 
COMMENT 'Expected component type for this anchor slot (e.g., BODY, STRAP)';

-- ตัวอย่าง:
-- anchor_slot = 'SLOT_BODY' → expected_component_type = 'BODY'
-- anchor_slot = 'SLOT_STRAP' → expected_component_type = 'STRAP'
```

### 2. graph_component_mapping: เปลี่ยน FK

**Current (❌ Wrong):**
```sql
CREATE TABLE graph_component_mapping (
    id_mapping INT AUTO_INCREMENT PRIMARY KEY,
    id_graph INT NOT NULL,
    anchor_slot VARCHAR(50) NOT NULL,
    component_code VARCHAR(50) NOT NULL,  -- ❌ เก็บ type_code (Layer 1)
    ...
);
```

**Required (✅ Correct):**
```sql
-- Migration: เพิ่ม column + FK
ALTER TABLE graph_component_mapping 
ADD COLUMN id_product_component INT NULL 
COMMENT 'FK to product_component.id_product_component (Layer 2)';

ALTER TABLE graph_component_mapping
ADD CONSTRAINT fk_mapping_product_component 
FOREIGN KEY (id_product_component) 
REFERENCES product_component(id_product_component)
ON DELETE SET NULL;

-- ⚠️ เพิ่ม product_id เพื่อ scope mapping ต่อ product
ALTER TABLE graph_component_mapping 
ADD COLUMN id_product INT NULL 
COMMENT 'FK to product (scope mapping per product)';

-- Unique: 1 anchor slot per product-graph combination
ALTER TABLE graph_component_mapping
ADD UNIQUE KEY uk_product_graph_slot (id_product, id_graph, anchor_slot);
```

### New FK Relationship

```
graph_component_mapping (PER PRODUCT!)
├── id_graph → routing_graph.id_graph
├── id_product → product.id_product  ← NEW!
├── anchor_slot (from routing_node)
└── id_product_component → product_component.id_product_component
        └── has component_type_code → component_type_catalog.type_code
        └── owns product_component_material (BOM)
```

---

## 🏷️ Component Code Naming Convention (Hermès Standard)

### ✅ Good Pattern: `{PRODUCT}_{TYPE}_{VARIANT}`

```
AIMEE_MINI_BODY          ← Clear: Aimee Mini's body
AIMEE_MINI_FLAP          ← Clear: Aimee Mini's flap
AIMEE_MINI_STRAP_LONG    ← Clear: Aimee Mini's long strap
TOTE_CLASSIC_BODY        ← Clear: Tote Classic's body
```

### ❌ Bad Pattern: Generic names

```
BODY_MAIN      ← Which product?
FLAP_FRONT     ← Which product?
STRAP_LONG     ← Ambiguous!
```

### Rule: Component Code ต้อง unique ภายใน Product

```sql
-- Enforced by unique constraint
UNIQUE KEY uk_product_component_code (id_product, component_code)
```

---

## 🔧 Code Changes Required

### 1. API: product_api.php

```php
// NEW: Get product components for mapping dropdown
case 'get_product_components_for_mapping':
    $productId = (int)($_GET['product_id'] ?? 0);
    $anchorSlot = $_GET['anchor_slot'] ?? null;
    
    // Get anchor slot's expected type from graph
    $expectedType = null;
    if ($anchorSlot) {
        // Lookup expected component type for this slot
        // (may need to store this in routing_node or infer from slot name)
    }
    
    // Get product components, optionally filtered by type
    $sql = "SELECT pc.*, ctc.type_name_th, ctc.type_name_en
            FROM product_component pc
            JOIN component_type_catalog ctc ON ctc.type_code = pc.component_type_code
            WHERE pc.id_product = ?";
    
    if ($expectedType) {
        $sql .= " AND pc.component_type_code = ?";
    }
    
    // Return list for dropdown
    break;

// MODIFY: Save component mapping
case 'save_component_mapping':
    // ❌ OLD: Save component_code (type_code)
    // ✅ NEW: Save id_product_component
    break;
```

### 2. JS: product_graph_binding.js

```javascript
// ❌ OLD: Load component types (Layer 1)
function loadComponentCatalog() {
    $.post('source/product_api.php', { action: 'get_component_types' }, ...);
}

// ✅ NEW: Load product components (Layer 2)
function loadProductComponentsForMapping(productId, anchorSlot) {
    return $.post('source/product_api.php', { 
        action: 'get_product_components_for_mapping',
        product_id: productId,
        anchor_slot: anchorSlot
    }, ...);
}
```

### 3. Dropdown Rendering

```javascript
// ✅ NEW: Show product components, not types
function renderMappingDropdown(slot, productComponents) {
    let html = '<option value="">-- เลือก Component --</option>';
    
    if (productComponents.length === 0) {
        return `<div class="alert alert-warning">
            ยังไม่มี Component ประเภท ${slot.expected_type} สำหรับ Product นี้
            <button class="btn btn-sm btn-primary ms-2" onclick="createQuickComponent('${slot.expected_type}')">
                + สร้าง Component
            </button>
        </div>`;
    }
    
    productComponents.forEach(pc => {
        const label = `${pc.component_code} (${pc.component_type_code})`;
        const selected = pc.id_product_component === currentMapping ? 'selected' : '';
        html += `<option value="${pc.id_product_component}" ${selected}>${label}</option>`;
    });
    
    return `<select class="form-select">${html}</select>`;
}
```

---

## 🎨 Component Type Master List (Seed Data)

> **Hermès-level craft structure + Apple-level simplicity**

### 1. MAIN STRUCTURE (โครงสร้างหลัก) - 8 types

| type_code | type_name_th | type_name_en | Description |
|-----------|--------------|--------------|-------------|
| BODY | ตัวกระเป๋า | Main Body | โครงหลักของสินค้า |
| FLAP | ฝาปิด | Flap Cover | ใช้กับ flap bags / กระเป๋าสตางค์ |
| POCKET | ช่อง | Pocket | ช่องภายนอก/ภายในที่เป็นชิ้นแยก |
| GUSSET | ข้างกระเป๋า | Gusset | ขยายความลึกของกระเป๋า |
| BASE | ก้นกระเป๋า | Base | ส่วนล่างที่รับน้ำหนัก |
| DIVIDER | ฉากกั้น | Divider | ช่องคั่นภายในใบ |
| FRAME | โครงเสริม | Frame | ใช้ใน structured bags |
| PANEL | แผง | Panel | ใช้ใน Wallet/SLG |

### 2. ACCESSORY & SUPPORT (ชิ้นส่วนเสริม) - 7 types

| type_code | type_name_th | type_name_en | Description |
|-----------|--------------|--------------|-------------|
| STRAP | สายสะพาย | Strap | long strap / short strap |
| HANDLE | หูหิ้ว | Handle | กระเป๋าถือ |
| ZIPPER_PANEL | แผงซิป | Zipper Panel | ชิ้นซิปหลักหรือภายใน |
| ZIP_POCKET | ช่องซิป | Zip Pocket | ช่องซิปที่แยกจาก panel |
| LOOP | ห่วงร้อย | Loop | strap loop / belt loop |
| TONGUE | ลิ้น | Tongue | ใช้ใน buckle closures |
| CLOSURE_TAB | แถบปิด | Closure Tab | สำหรับ magnetic หรือ snap |

### 3. INTERIOR (ชิ้นภายใน) - 3 types

| type_code | type_name_th | type_name_en | Description |
|-----------|--------------|--------------|-------------|
| LINING | ซับใน | Lining | lining หลักของตัวกระเป๋า |
| INTERIOR_PANEL | แผงภายใน | Interior Panel | ใช้ในกระเป๋าที่ต้องเย็บ panel ติดซับใน |
| CARD_SLOT_PANEL | ช่องบัตร | Card Slot Panel | เป็น panel แยกจริง มี flow เย็บพับ 2-3 ชั้น |

### 4. REINFORCEMENT (เสริมโครง) - 3 types

| type_code | type_name_th | type_name_en | Description |
|-----------|--------------|--------------|-------------|
| REINFORCEMENT | แผ่นเสริม | Reinforcement | เสริมโครงด้านใน เช่น bottom stiffener |
| PADDING | แผ่นรอง | Padding | ใช้กับ soft bags / phone cases |
| BACKING | แผ่นรองหลัง | Backing | ใช้ในโลโก้หรือฮาร์ดแวร์ |

### 5. DECORATIVE (งานตกแต่ง) - 3 types

| type_code | type_name_th | type_name_en | Description |
|-----------|--------------|--------------|-------------|
| LOGO_PATCH | ป้ายโลโก้ | Logo Patch | เช่น leather logo patch |
| DECOR_PANEL | แผงตกแต่ง | Decor Panel | ใช้กับดีไซน์พิเศษ เช่น quilting panel |
| BADGE | Badge | Badge | ชิ้นหนังหรือโลโก้ที่เย็บติด |

> **Total: 24 Core Component Types**

---

## ✅ Validation Rules (Hermès-Grade Strict)

### Tab Components

| Rule | Description | Enforcement |
|------|-------------|-------------|
| 1 | Component Code ต้อง unique ภายใน Product | `UNIQUE KEY (id_product, component_code)` |
| 2 | Component Type ต้องเลือกจาก `component_type_catalog` | FK constraint |
| 3 | Component Code ควรขึ้นต้นด้วย Product prefix | Frontend suggestion |
| 4 | ต้องมี BOM อย่างน้อย 1 material | Warning (not blocking) |

### Tab Component Mapping

| Rule | Description | Enforcement |
|------|-------------|-------------|
| 1 | **ต้องมี Product Components ก่อน** | ❌ Block mapping if empty |
| 2 | Dropdown แสดงเฉพาะ **type ตรงกับ expected_component_type** | API filter |
| 3 | ไม่อนุญาต map Product Component เดียวกันให้หลาย anchor slot | Unique constraint |
| 4 | ถ้า anchor slot ไม่มี matching component → **แสดง error** | Frontend validation |

### Before Publishing Graph

| Rule | Description | Action |
|------|-------------|--------|
| 1 | ทุก anchor slot ต้องมี `expected_component_type` | ❌ Block publish |
| 2 | ไม่มี orphan anchor slots | ❌ Block publish |
| 3 | `expected_component_type` ต้องอยู่ใน `component_type_catalog` | ❌ Block publish |

### Before Creating Job Ticket

| Rule | Description | Action |
|------|-------------|--------|
| 1 | Product ต้องมี Graph binding | ❌ Block creation |
| 2 | ทุก anchor slot ต้อง map กับ Product Component | ❌ Block creation |
| 3 | Component type ต้อง match anchor slot's expected type | ❌ Block creation |

---

## 🚫 Error Messages (Thai UX)

```javascript
const ERROR_MESSAGES = {
    NO_COMPONENTS: 'ยังไม่มี Component สำหรับสินค้านี้ กรุณาเพิ่มในแท็บ Components ก่อน',
    NO_MATCHING_TYPE: 'ยังไม่มี Component ประเภท {type} สำหรับ Product นี้',
    DUPLICATE_MAPPING: 'Component นี้ถูก map กับ slot อื่นแล้ว',
    TYPE_MISMATCH: 'ประเภท Component ไม่ตรงกับ Anchor Slot',
    INCOMPLETE_MAPPING: 'กรุณา map ทุก Anchor Slot ก่อนบันทึก',
    GRAPH_NOT_BOUND: 'กรุณาเลือก Graph ก่อนทำ Component Mapping'
};
```

---

## 📋 Summary: ต้องแก้อะไร

| # | Item | Current | Required | Priority |
|---|------|---------|----------|----------|
| 1 | Dropdown source | `component_type_catalog` | `product_component` | 🔴 HIGH |
| 2 | FK in mapping | `component_code` (type) | `id_product_component` | 🔴 HIGH |
| 3 | Add `id_product` | ❌ None | ✅ Scope per product | 🔴 HIGH |
| 4 | Add `expected_component_type` | ❌ None | ✅ In routing_node | 🔴 HIGH |
| 5 | Filter by type | ❌ None | ✅ Match anchor slot type | 🟠 MEDIUM |
| 6 | Empty state | ❌ None | ✅ Warning + quick create | 🟡 LOW |
| 7 | API endpoint | `get_component_types` | `get_product_components_for_mapping` | 🔴 HIGH |
| 8 | Seed 24 types | Partial | Full Master List | 🟠 MEDIUM |

---

## 🎯 One-Line Summary

> **Tab Components = สร้างของจริง (Layer 2)**  
> **Tab Component Mapping = จับคู่ Anchor Slot → Product Component ที่สร้างไว้**  
> **❌ ไม่ใช่ Component Type ลอยๆ อีกต่อไป!**

---

## 🛠️ Implementation Task

**Task 27.13.12: Component Mapping Refactor**

1. **Migration:** Add `expected_component_type` to `routing_node`
2. **Migration:** Add `id_product_component`, `id_product` to `graph_component_mapping`
3. **Seed:** Update `component_type_catalog` with 24 types
4. **API:** New `get_product_components_for_mapping` endpoint
5. **JS:** Update `product_graph_binding.js` dropdown logic
6. **Validation:** Strict rules before publish/create

**Estimated Time:** ~2 hours

---

*Last Updated: 2025-12-06 by CTO Audit*  
*CTO Score: 10/10 ✅*

