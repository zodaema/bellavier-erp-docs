# Products & Components V3 — BOM-Driven Production Constraints (Role-Based)

**Version:** 3.0  
**Date:** 2025-12-25  
**Status:** Concept Spec (Implementation Ready)

---

## Executive Summary

**V3 Philosophy:** BOM Line เป็น Source of Truth ของ Material Constraints — ไม่ใช่ Slot-Level Config

**Core Change:** Production Constraints ย้ายจาก "config กลางระดับ slot" ไปเป็น "configuration ของแต่ละ BOM line item" ที่ขับด้วย Material Role/Category

**Why V3:**
- V2 + Phase 1: `product_config_component_slot` เป็น "Config กลาง" ทำให้ UX และข้อมูล "ไม่ฉลาด" และใช้จริงไม่ได้
- โลกจริง: Constraints ส่วนใหญ่เป็น "คุณสมบัติ/เงื่อนไขของวัสดุแต่ละรายการใน BOM" ไม่ใช่ของ slot แบบรวมๆ
- V3: Constraints ผูกกับ BOM line item + Material Role → ฉลาดขึ้นจริง

---

## 1. Principles (กฎเหล็ก)

### P1 — BOM Line เป็น Source of Truth ของ Constraints

**ทุก constraints ที่เกี่ยวกับวัสดุ** (ความหนา, lining, reinforcement, hardware finish, thread size, glue type ฯลฯ) **ต้องผูกกับ "BOM line item" ใน `product_component_material`**

❌ **ห้าม:** ผูก constraints กับ `anchor_slot` โดยตรง  
❌ **ห้าม:** เก็บ constraints เป็น config กลางระดับ slot  
✅ **ต้อง:** Constraints อยู่ที่ BOM line item เท่านั้น

---

### P2 — Constraints ถูกขับด้วย "Material Role/Category"

**BOM line ต้องมี "Role" ชัดเจน** เพื่อให้ระบบรู้ว่าต้องถาม fields อะไรบ้าง:

| Role Code | Name | Description | Example Fields |
|-----------|------|-------------|----------------|
| `MAIN_MATERIAL` | Main Material | วัสดุหลักของ component | `thickness_mm`, `grain_direction`, `finish_type` |
| `LINING` | Lining | วัสดุบุใน | `bonding_method`, `thickness_mm`, `color` |
| `REINFORCEMENT` | Reinforcement | วัสดุเสริมความแข็งแรง | `thickness_mm`, `placement`, `adhesive_type` |
| `HARDWARE` | Hardware | อุปกรณ์ (ซิป, หัวเข็ม, ฯลฯ) | `finish`, `color`, `size`, `brand` |
| `THREAD` | Thread | ด้าย | `color`, `weight`, `material_type` |
| `EDGE_FINISH` | Edge Finish | การตกแต่งขอบ | `method`, `width_mm`, `color` |
| `ADHESIVE` | Adhesive | กาว/สารยึดติด | `type`, `application_method`, `cure_time` |
| `PACKAGING` | Packaging | บรรจุภัณฑ์ | `type`, `size`, `quantity` |

**เมื่อเลือก role → UI/validation จะรู้ว่าต้องถาม fields อะไรบ้าง**

---

### P3 — Graph ยังเป็น SSOT ของ Slot (Anchor Slot)

- `routing_node.anchor_slot` คือ SSOT ของ slot และยังเหมือนเดิม
- `graph_component_mapping` มีหน้าที่ "บอกว่า slot นี้คือ component ไหน"
- **Graph ไม่ควรเป็นที่เก็บ constraints วัสดุ**

---

### P4 — Slot-level Spec เหลือแค่สิ่งที่เป็น "slot จริงๆ"

**สิ่งที่เป็น property ของ slot จริงๆ:**
- `quantity_per_product` (จำนวนชิ้นต่อสินค้า)
- `is_required` (จำเป็น/optional)
- `dimensions` (optional - ถ้าต้องการ intent ระดับชิ้นงาน)

**สิ่งเหล่านี้ไม่ใช่ material constraints และไม่ควรปนกับ BOM constraints**

---

## 2. New Mental Model (โมเดลใหม่)

### Entity ที่ผู้ใช้คิดตามจริง

```
Product
  └── Components
        └── BOM (materials)
              └── Constraints ตามวัสดุแต่ละตัว
```

**ไม่ใช่:**
```
Product
  └── Slot Specs (config กลาง)
        └── แล้วค่อยเดาว่าต้องไปถามอะไร
```

### "Production Constraints" จะไม่เป็น section แยกอีกต่อไป

- มันจะเป็น **"configuration ของแต่ละ BOM line"**
- ผู้ใช้แก้ constraints โดย **คลิกที่วัสดุใน BOM**

---

## 3. UX Flow (สิ่งที่ UI ต้องเป็น)

### Component Modal = BOM-First (คงไว้) แต่ "Constraints แทรกใน BOM"

#### ใน modal ของ component:

**1. Materials (BOM) Table**

แต่ละแถว (material line) ต้องมี:
- **Material** (sku/name) — Select2 dropdown
- **Qty + UOM** — Number input + UOM dropdown
- **Role** — Dropdown (MAIN_MATERIAL, LINING, HARDWARE, etc.)
- **Configure** button — เปิด role-based fields modal
- **Status badge:** ✅ครบ / ⚠️ไม่ครบ — แสดงว่า constraints ครบหรือไม่

**2. Production Constraints Section (แบบรวมๆ) → Remove/Deprecate**

- ❌ ไม่มีฟอร์มกลางที่อิง `anchor_slot`
- ✅ ถ้าต้องโชว์รวม ให้โชว์เป็น **summary ของ BOM roles** เท่านั้น (read-only)

**3. Notes** (เหมือนเดิม)

---

### การทำงานแบบจริง

**ตัวอย่าง: ถ้าต้องมี lining**

1. ผู้ใช้เพิ่ม BOM line วัสดุ lining (material_sku = "LINING_001")
2. ตั้ง Role = `LINING`
3. ระบบถาม fields ของ LINING:
   - `bonding_method` (stitch / glue / heat-seal)
   - `thickness_mm` (0.5, 0.8, 1.0, etc.)
   - `color` (optional)
4. บันทึก → constraints_json เก็บคำตอบ

**ตัวอย่าง: Hardware**

1. เพิ่ม material line → material_sku = "ZIPPER_YKK_20CM"
2. role = `HARDWARE`
3. ระบบถาม:
   - `finish` (matte / shiny / antique)
   - `color` (gold / silver / black)
   - `size` (20cm / 25cm / 30cm)
   - `brand` (YKK / RIRI / etc.)

---

## 4. Data Model V3 (ภาพใหญ่)

### 4.1 Extend: `product_component_material` (BOM line)

**เพิ่ม columns:**

```sql
ALTER TABLE product_component_material
  ADD COLUMN `role_code` VARCHAR(50) NOT NULL DEFAULT 'MAIN_MATERIAL' COMMENT 'Material role: MAIN_MATERIAL, LINING, HARDWARE, etc.',
  ADD COLUMN `constraints_json` JSON NULL COMMENT 'Role-based constraints fields (data-driven)';
```

**DB Constraint Decision:**
- `role_code` = `NOT NULL DEFAULT 'MAIN_MATERIAL'` เพื่อ enforce SSOT และลด edge-case
- UI save ต้องมี `role_code` เสมอ (DoD requirement)
- Legacy data migration: ใช้ DEFAULT 'MAIN_MATERIAL' สำหรับ existing rows

**เหตุผล:**
- 1 BOM line = 1 วัสดุ + 1 role + 1 ชุด constraints ที่เกี่ยวข้อง
- ยืดหยุ่นสูง (เพิ่ม fields โดยไม่เปลี่ยน schema บ่อย)

**Example `constraints_json`:**
```json
{
  "thickness_mm": 0.8,
  "grain_direction": "parallel",
  "finish_type": "smooth"
}
```

---

### 4.2 Role Catalog (เพื่อให้ UI generate ได้ + validation มาตรฐาน)

#### Table 1: `material_role_catalog`

```sql
CREATE TABLE `material_role_catalog` (
  `id_role` INT AUTO_INCREMENT PRIMARY KEY,
  `role_code` VARCHAR(50) NOT NULL COMMENT 'Unique code: MAIN_MATERIAL, LINING, etc.',
  `name_en` VARCHAR(100) NOT NULL,
  `name_th` VARCHAR(100) NOT NULL,
  `applies_to_line` ENUM('classic', 'hatthasilpa', 'both') NOT NULL DEFAULT 'both' COMMENT 'Production line scope: classic, hatthasilpa, or both',
  `display_order` INT NOT NULL DEFAULT 0,
  `description` TEXT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_role_code` (`role_code`),
  INDEX `idx_display_order` (`display_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Material role catalog (data-driven UI)';
```

#### Table 2: `material_role_field`

```sql
CREATE TABLE `material_role_field` (
  `id_field` INT AUTO_INCREMENT PRIMARY KEY,
  `role_code` VARCHAR(50) NOT NULL COMMENT 'FK to material_role_catalog.role_code',
  CONSTRAINT `fk_role_field_role` FOREIGN KEY (`role_code`) REFERENCES `material_role_catalog` (`role_code`) ON UPDATE CASCADE ON DELETE RESTRICT,
  `field_key` VARCHAR(50) NOT NULL COMMENT 'Field identifier in constraints_json',
  `field_type` ENUM('text', 'number', 'select', 'boolean', 'json') NOT NULL,
  `field_label_en` VARCHAR(100) NOT NULL,
  `field_label_th` VARCHAR(100) NOT NULL,
  `required` TINYINT(1) NOT NULL DEFAULT 0,
  `options_json` JSON NULL COMMENT 'Options for select type: [{"value": "...", "label": "..."}]',
  `unit` VARCHAR(20) NULL COMMENT 'Unit for number fields (mm, cm, g, etc.)',
  `help_text_en` TEXT NULL,
  `help_text_th` TEXT NULL,
  `display_order` INT NOT NULL DEFAULT 0,
  `validation_rules_json` JSON NULL COMMENT 'Additional validation rules',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_role_field` (`role_code`, `field_key`),
  INDEX `idx_role` (`role_code`),
  INDEX `idx_display_order` (`role_code`, `display_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Field definitions per material role (data-driven form generation)';
```

**หลักการ:**
- UI ไม่ hardcode ฟอร์ม constraints
- UI render ตาม `material_role_field`
- Validation ใช้ `material_role_field.required` เป็นฐาน

**Field Type Contract (Critical for Data-Driven UI):**

| `field_type` | JSON Payload Shape | Validation Rules |
|--------------|-------------------|-------------------|
| `number` | JSON number (integer or float) | Must be numeric, optional min/max from `validation_rules_json` |
| `text` | JSON string | Must be string, optional max length from `validation_rules_json` |
| `boolean` | JSON `true` or `false` | Must be boolean literal |
| `select` | JSON string | Must match one of `options_json[].value` |
| `json` | JSON object or array | Must be valid JSON, validate structure from `validation_rules_json` |

**Critical Rules:**
- `constraints_json` ต้องเป็น **object เสมอ** (ไม่ใช่ array)
- Field keys ต้องตรงกับ `field_key` ใน `material_role_field`
- Select values ต้องอยู่ใน `options_json[].value` (case-sensitive)
- Number fields ใช้ `unit` จาก `material_role_field.unit` สำหรับ display เท่านั้น (storage เป็น number)

**Example Payload:**
```json
{
  "thickness_mm": 0.8,
  "grain_direction": "parallel",
  "finish_type": "smooth",
  "has_coating": true,
  "special_notes": {"note": "Custom finish"}
}
```

**Example Seed Data:**

```sql
-- MAIN_MATERIAL role fields
INSERT INTO material_role_field (role_code, field_key, field_type, field_label_en, field_label_th, required, unit, display_order) VALUES
('MAIN_MATERIAL', 'thickness_mm', 'number', 'Thickness (mm)', 'ความหนา (มม.)', 1, 'mm', 10),
('MAIN_MATERIAL', 'grain_direction', 'select', 'Grain Direction', 'ทิศทางลาย', 0, NULL, 20),
('MAIN_MATERIAL', 'finish_type', 'select', 'Finish Type', 'ประเภทผิว', 0, NULL, 30);

-- LINING role fields
INSERT INTO material_role_field (role_code, field_key, field_type, field_label_en, field_label_th, required, unit, display_order) VALUES
('LINING', 'bonding_method', 'select', 'Bonding Method', 'วิธีการยึดติด', 1, NULL, 10),
('LINING', 'thickness_mm', 'number', 'Thickness (mm)', 'ความหนา (มม.)', 1, 'mm', 20),
('LINING', 'color', 'text', 'Color', 'สี', 0, NULL, 30);
```

---

### 4.3 Slot-level Spec Table (clean replacement)

**สร้าง table ใหม่** เพื่อเก็บ "slot property ที่แท้จริง":

```sql
CREATE TABLE `product_component_slot_spec` (
  `id_spec` INT AUTO_INCREMENT PRIMARY KEY,
  `id_product` INT NOT NULL COMMENT 'FK to product.id_product',
  `anchor_slot` VARCHAR(50) NOT NULL COMMENT 'Component slot from Graph (routing_node.anchor_slot)',
  
  -- Slot Properties Only (NOT material constraints)
  `quantity_per_product` INT NOT NULL DEFAULT 1 COMMENT 'Quantity of this component per product',
  `is_required` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Is this component slot required',
  `dimensions_json` JSON NULL COMMENT 'Component dimensions intent: {"width": decimal, "length": decimal, "height": decimal, "unit": "cm"|"mm"|"inch"}',
  
  -- Metadata
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_by` INT NULL,
  
  -- Constraints
  UNIQUE KEY `uk_product_anchor_slot` (`id_product`, `anchor_slot`),
  INDEX `idx_product` (`id_product`),
  INDEX `idx_anchor_slot` (`anchor_slot`),
  CONSTRAINT `fk_slot_spec_product` FOREIGN KEY (`id_product`) REFERENCES `product` (`id_product`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='V3: Slot-level properties only (quantity, required, dimensions) - NOT material constraints';
```

**ตารางนี้ "ไม่ยุ่งกับ BOM constraints" และไม่เก็บ material intent**

---

### 4.4 Graph Requirements (optional แต่ recommended)

**ถ้าจะให้ validate แบบ graph-aware:**

```sql
CREATE TABLE `graph_slot_role_requirement` (
  `id_requirement` INT AUTO_INCREMENT PRIMARY KEY,
  `graph_version_id` INT NULL COMMENT 'FK to routing_graph_version.id_version (NULL = applies to all versions)',
  `id_graph` INT NOT NULL COMMENT 'FK to routing_graph.id_graph',
  `anchor_slot` VARCHAR(50) NOT NULL COMMENT 'Component slot from routing_node',
  `role_code` VARCHAR(50) NOT NULL COMMENT 'Required material role',
  `min_lines` INT NOT NULL DEFAULT 1 COMMENT 'Minimum BOM lines with this role',
  `required_fields_json` JSON NULL COMMENT 'Required field_keys for this role in this slot',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_graph_slot_role` (`id_graph`, `anchor_slot`, `role_code`),
  INDEX `idx_graph` (`id_graph`),
  INDEX `idx_anchor_slot` (`anchor_slot`),
  INDEX `idx_role` (`role_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Graph-defined role requirements per slot (optional validation)';
```

**หน้าที่:**
- Graph บอก requirement ระดับ role
- ระบบไปเช็ค BOM ของ component ที่ map กับ slot

**Example:**
```sql
-- Graph "Tote_V2" requires BODY slot to have:
-- - At least 1 MAIN_MATERIAL with thickness_mm
-- - At least 1 LINING with bonding_method
INSERT INTO graph_slot_role_requirement (id_graph, anchor_slot, role_code, min_lines, required_fields_json) VALUES
(1, 'BODY', 'MAIN_MATERIAL', 1, '["thickness_mm"]'),
(1, 'BODY', 'LINING', 1, '["bonding_method", "thickness_mm"]');
```

---

## 5. Validation Rules (นิยามชัดๆ)

### V-Base (Role-based validation)

**เมื่อบันทึก BOM line:**

1. ถ้า `role_code = X`
2. `constraints_json` ต้องมี `field_key` ที่ `required = 1` ใน `material_role_field` สำหรับ role นั้น
3. Field types ต้อง validate ตาม `field_type` (number, select, etc.)

**Example:**
```php
// BOM line with role_code = 'LINING'
// material_role_field for LINING:
//   - bonding_method (required=1, type=select)
//   - thickness_mm (required=1, type=number)
//   - color (required=0, type=text)

// constraints_json must have:
{
  "bonding_method": "stitch",  // ✅ required
  "thickness_mm": 0.8          // ✅ required
  // color is optional ✅
}
```

---

### V-Hatthasilpa (Graph-aware validation)

**เมื่อ product เป็น `hatthasilpa` และมี binding graph:**

1. สำหรับทุก `routing_node` ที่ `node_type='component'`:
2. หา mapping → `id_product_component` (จาก `graph_component_mapping`)
3. ดึง BOM lines ของ component นั้น
4. เช็ค requirement:
   - มี roles ครบตาม `graph_slot_role_requirement`
   - BOM line ที่เป็น role นั้นมี constraints required ครบ

**Example:**
```php
// Graph "Tote_V2" slot "BODY" requires:
//   - MAIN_MATERIAL (min_lines=1, required_fields=["thickness_mm"])
//   - LINING (min_lines=1, required_fields=["bonding_method", "thickness_mm"])

// Component mapped to BODY must have:
//   - At least 1 BOM line with role_code='MAIN_MATERIAL' AND constraints_json has "thickness_mm"
//   - At least 1 BOM line with role_code='LINING' AND constraints_json has "bonding_method" AND "thickness_mm"
```

---

### V-Classic

- ไม่ enforce graph requirements
- Role-based validation ยังใช้ได้ (เพื่อข้อมูลดีขึ้น) แต่ไม่ต้อง block หนัก

---

## 6. Migration Strategy (ไม่พังของเดิม)

### M1 — Additive first (เพิ่มก่อน ไม่ลบทันที)

**Phase 1: Add columns**
- เพิ่ม `role_code`, `constraints_json` ให้ `product_component_material`
- สร้าง `material_role_catalog` table
- สร้าง `material_role_field` table
- สร้าง `product_component_slot_spec` table (slot properties only)

**Phase 2: Seed role catalog**
- Seed 8 roles: MAIN_MATERIAL, LINING, REINFORCEMENT, HARDWARE, THREAD, EDGE_FINISH, ADHESIVE, PACKAGING
- Seed fields สำหรับแต่ละ role

---

### M2 — UI switch (ย้าย UX ไป BOM line)

**Phase 1: Update Component Modal**
- BOM Table: เพิ่ม Role column + Configure button
- Remove/Deprecate Production Constraints section แบบ slot-level
- สร้าง Role-based Constraints Modal (data-driven จาก `material_role_field`)

**Phase 2: Migration UI**
- (Optional) Tool สำหรับ migrate ข้อมูลจาก `product_config_component_slot` → BOM lines

---

### M3 — Data mapping (optional)

**ถ้ามีข้อมูลอยู่ใน `product_config_component_slot`:**

| Source Field | Target | Mapping Logic |
|--------------|--------|---------------|
| `target_thickness` | BOM line role=MAIN_MATERIAL | `constraints_json.thickness_mm` |
| `material_sheet_size_constraint` | BOM line role=MAIN_MATERIAL | `constraints_json.sheet_size_constraint` |
| `lining_required` + `material_specification` | BOM line role=LINING | Create new BOM line if `lining_required=1` |
| `special_attributes` | BOM line role=MAIN_MATERIAL | `constraints_json.special_attributes` |
| `quantity_per_product` | `product_component_slot_spec` | `quantity_per_product` |
| `is_required` | `product_component_slot_spec` | `is_required` |
| `dimensions` | `product_component_slot_spec` | `dimensions_json` |

---

### M4 — Deprecate

- `product_config_component_slot` กลายเป็น **legacy read-only** / migration source
- (ยังไม่ delete จนกว่าจะมั่นใจ)

---

## 7. What NOT To Do (กัน Agent พลาด)

### ❌ ห้ามสร้าง constraints เป็น "Config กลาง" ใหม่อีก

- ห้ามทำ table แบบ `product_config_component_slot_v2` ที่ยังยึด `anchor_slot` เป็นหลักสำหรับวัสดุ

### ❌ ห้ามผูก material constraints กับ component แบบรวมๆ

- ต้องอยู่ที่ BOM line item เท่านั้น

### ❌ ห้าม hardcode ฟอร์ม constraints ใน JS แบบตายตัว

- ต้องให้ `material_role_field` เป็นตัวขับ (data-driven UI)

### ❌ ห้ามกลับไปใช้ `material_specification`

- เพราะมัน duplicate/intent เก๊ ไม่เชื่อมกับ BOM จริง

---

## 8. Expected Outcome (ผลลัพธ์ที่เราต้องได้)

✅ **BOM แยก category/role ชัด:** main, lining, hardware, etc.

✅ **เมื่อเพิ่มวัสดุแต่ละประเภท ระบบถาม "คำถามที่ถูกต้อง" ตาม role**

✅ **Production constraints เกิดจาก BOM จริง ไม่ใช่ config กลาง**

✅ **Validate ได้ทั้งแบบ role-based และ graph-aware**

✅ **Architecture ยังอยู่ในกรอบ V2 (3-layer) แต่ฉลาดขึ้นจริงใน V3**

---

## 9. Implementation Scope (เพื่อให้ Agent แตกงานถูก)

### Core Workstreams

#### 1. DB Migrations
- [ ] Add `role_code`, `constraints_json` to `product_component_material`
- [ ] Create `material_role_catalog` table
- [ ] Create `material_role_field` table
- [ ] Create `product_component_slot_spec` table
- [ ] (Optional) Create `graph_slot_role_requirement` table
- [ ] Seed role catalog (8 roles)
- [ ] Seed role fields (per role)

#### 2. API Updates
- [ ] Extend `product_component_material` CRUD to handle `role_code`, `constraints_json`
- [ ] Create `material_role_catalog` API (list roles, get role fields)
- [ ] Create `product_component_slot_spec` API (CRUD slot properties)
- [ ] Validation service: Role-based validation
- [ ] (Optional) Validation service: Graph-aware validation

#### 3. UI Updates
- [ ] Component Modal: BOM Table — Add Role column + Configure button
- [ ] Role-based Constraints Modal (data-driven form generation)
- [ ] Remove/Deprecate Production Constraints section (slot-level)
- [ ] (Optional) Slot Spec UI (quantity, is_required, dimensions)

#### 4. Validation Logic
- [ ] Role-based validation (required fields check)
- [ ] Field type validation (number, select, etc.)
- [ ] (Optional) Graph-aware validation (role requirements check)

#### 5. Migration Mapping Script (Optional)
- [ ] Map `product_config_component_slot` → BOM lines + slot spec
- [ ] Data migration tool/UI

---

## 10. Architecture Compliance

### V3 ยังอยู่ในกรอบ V2 (3-Layer Architecture)

**Layer 1 (Abstract):** `component_type_catalog` — ไม่เปลี่ยน

**Layer 2 (Physical):** 
- `product_component` — ไม่เปลี่ยน
- `product_component_material` — **Extend:** เพิ่ม `role_code`, `constraints_json`

**Layer 3 (Graph Binding):**
- `graph_component_mapping` — ไม่เปลี่ยน
- `product_component_slot_spec` — **New:** Slot properties only (ไม่ใช่ material constraints)

**New Layer (Role Catalog):**
- `material_role_catalog` — **New:** Role definitions
- `material_role_field` — **New:** Field definitions per role

---

## 11. Comparison: V2 vs V3

| Aspect | V2 + Phase 1 | V3 |
|--------|---------------|-----|
| **Constraints Location** | `product_config_component_slot` (slot-level) | `product_component_material.constraints_json` (BOM line-level) |
| **Material Intent** | `material_specification` (text field) | BOM line + role + constraints |
| **UI Form** | Hardcoded fields in Production Constraints section | Data-driven from `material_role_field` |
| **Validation** | Manual/slot-level | Role-based + Graph-aware |
| **Flexibility** | Limited (fixed fields) | High (add fields via role catalog) |
| **UX** | Config กลาง → เดาว่าต้องถามอะไร | BOM line → role → fields ที่ถูกต้อง |

---

## 12. Next Steps

1. **Review & Approve Concept** — Stakeholder sign-off
2. **Create Implementation Plan** — Break down into patches
3. **Start with DB Migrations** — Additive first (M1)
4. **Build Role Catalog** — Seed data + API
5. **Update UI** — BOM-first with role-based constraints
6. **Migration Script** — (Optional) Map old data
7. **Deprecate Legacy** — Mark `product_config_component_slot` as read-only

---

**Related Documents:**
- `docs/DATABASE_SCHEMA_PRODUCTS_COMPONENTS.md` — Current V2 schema
- `docs/super_dag/06-specs/PHASE_1_IMPLEMENTATION_PLAN.md` — Phase 1 (slot-level config)
- `docs/super_dag/01-concepts/PRODUCT_CONFIG_V3_CONCEPT.md` — Product Config V3 concept

---

## 13. Glossary (คำศัพท์ที่ต้องใช้ให้ตรงกัน)

**เพื่อลดการตีความผิด — ใช้คำเหล่านี้ให้ตรงกันเสมอ:**

| Term | Definition | Example |
|------|------------|---------|
| **Slot (anchor_slot)** | ช่อง component ใน Graph (`routing_node.anchor_slot`) เป็น SSOT ของ "slot name" | `"BODY"`, `"FLAP"`, `"STRAP"` |
| **Component** | ชิ้นงานจริงของ product (`product_component`) | Component "BODY_AIMEE_MINI_2025_GREENTEA" |
| **BOM Line** | รายการวัสดุใน component (`product_component_material`) = 1 material ต่อ 1 แถว | BOM line: material_sku="GOAT_001", qty=1.0 |
| **Material Role** | หมวด/บทบาทของ BOM line เช่น MAIN_MATERIAL, LINING, HARDWARE ฯลฯ | `role_code="LINING"` |
| **Material Constraints** | คำตอบ/สเปกที่ "ผูกกับ BOM line" (`constraints_json`) | `{"thickness_mm": 0.8, "bonding_method": "stitch"}` |
| **Slot Spec** | Property ของ slot จริงๆ เท่านั้น (quantity_per_product, is_required, dimensions_json) ไม่ใช่ material constraints | `quantity_per_product=1`, `is_required=1` |

**Critical Distinction:**
- **Material Constraints** = เกี่ยวกับวัสดุ (thickness, finish, color, etc.) → อยู่ที่ BOM line
- **Slot Spec** = เกี่ยวกับ slot (quantity, required, dimensions) → อยู่ที่ slot spec table

**Slot Spec vs Component Quantity (Locked Meaning):**

| Field | Meaning | Example |
|-------|---------|---------|
| `product_component_slot_spec.quantity_per_product` | จำนวน "component ชิ้นนั้น" ต่อ product (ไม่ใช่จำนวนวัสดุ/จำนวน BOM lines) | หูจับ (HANDLE) = 2 ชิ้นต่อ product |
| `product_component_material.quantity` | จำนวนวัสดุใน BOM line (ต่อ component) | GOAT_001 = 1.0 m² ต่อ component |

**Important:**
- `quantity_per_product` = จำนวน component instances ต่อ product (เช่น HANDLE 2 ชิ้น)
- ไม่ใช่จำนวนวัสดุ (วัสดุอยู่ใน BOM lines)
- ไม่ใช่จำนวน BOM lines (BOM lines = รายการวัสดุ)

**Graph Binding Context:**
- ถ้าไม่มี graph binding: `product_component_slot_spec` อาจไม่มี/ไม่ enforce (ตาม I4)
- Slot spec ใช้ได้เฉพาะเมื่อ product มี graph binding และ component mapped กับ slot

---

## 14. SSOT Rules (Invariants) — ห้ามละเมิด

**กฎเหล็กที่ Agent ต้องยึดถือเสมอ — ห้ามละเมิด:**

### I1 — Material constraints อยู่ที่ BOM line เท่านั้น

❌ **ห้าม:** มีฟอร์ม/ตารางใดที่เก็บ "ความหนา/lining/hardware finish/thread size" แบบ slot-level อีก

✅ **ต้อง:** Material constraints เก็บใน `product_component_material.constraints_json` เท่านั้น

**Evidence Check:**
- ถ้า Agent พบ table/field ที่เก็บ material constraints แบบ slot-level → ต้อง report และไม่ใช้เป็น SSOT

---

### I2 — Slot spec เก็บได้แค่ slot properties

❌ **ห้าม:** ยัด "material" หรือ "spec วัสดุ" ลงใน `product_component_slot_spec`

✅ **ต้อง:** `product_component_slot_spec` เก็บได้เฉพาะ:
- `quantity_per_product`
- `is_required`
- `dimensions_json` (optional)

**Evidence Check:**
- Migration/table definition ต้องไม่มี fields เกี่ยวกับวัสดุ (thickness, material_spec, lining, etc.)

---

### I3 — Role-driven UI/Validation ต้อง data-driven

❌ **ห้าม:** Hardcode fields ใน JS แบบตายตัว (ยกเว้นโครงสร้าง renderer)

✅ **ต้อง:** UI ฟอร์ม constraints ต้อง generate จาก `material_role_field`

**Evidence Check:**
- JS code ต้อง query `material_role_field` API
- Form fields render จาก API response
- Validation rules มาจาก `material_role_field.required`

---

### I4 — Graph เป็น SSOT ของ slot list

❌ **ห้าม:** Invent slot จาก product config

✅ **ต้อง:** Slot list มาจาก Graph (`routing_node.anchor_slot` where `node_type='component'`) เท่านั้น

**Evidence Check:**
- Slot dropdown/list ต้อง query จาก Graph
- ถ้าไม่มี graph binding: slot-spec UI จะไม่ enforce แต่ BOM/role ยังใช้ได้

---

## 15. Concept of Operations (ConOps) — User Journey

**User Journey ที่ระบบต้องทำให้ได้:**

### Scenario A: Hatthasilpa + bound graph + mapped component

**Flow:**
1. User เปิด component modal
2. เห็น BOM table → เพิ่ม/แก้ BOM line
3. ตั้ง Role ให้แต่ละ line → กด Configure → กรอก fields (data-driven)
4. Save → ระบบ validate required fields ตาม role
5. Validate Graph-aware (optional) → slot requirement ผ่าน/ไม่ผ่านพร้อม reason

**Expected Behavior:**
- BOM table แสดง role + status badge (✅ครบ / ⚠️ไม่ครบ)
- Configure modal แสดง fields ตาม role (จาก `material_role_field`)
- Validation แสดง errors ชัดเจน (missing required fields)

---

### Scenario B: Hatthasilpa แต่ component ยังไม่ mapped

**Flow:**
- ทำ BOM + role + constraints ได้เหมือนเดิม
- Graph-aware validation ไม่ enforce (หรือขึ้น warning ว่า "ยังไม่ mapped")

**Expected Behavior:**
- BOM/role/constraints ทำงานปกติ
- Graph validation skip หรือ warning only

---

### Scenario C: Classic product

**Flow:**
- ไม่มี Graph/slot concerns
- ใช้ BOM+role+constraints เป็น "data quality improvement" ได้ แต่ไม่ block หนัก

**Expected Behavior:**
- BOM/role/constraints ทำงานปกติ
- Role-based validation ใช้ได้ (เพื่อข้อมูลดีขึ้น) แต่ไม่ block หนัก
- Graph validation ไม่ enforce

---

## 16. Validation Model (คมๆ ว่า block อะไร)

### V-Base (ต้องมีแน่)

**เมื่อ save BOM line:**

1. **Role Required:**
   - ต้องมี `role_code` (หรือ default `MAIN_MATERIAL`)

2. **Required Fields Check:**
   - ถ้า role มี required fields → `constraints_json` ต้องมีครบ
   - เช็คจาก `material_role_field` where `role_code=X` AND `required=1`

3. **Type Validation:**
   - `field_type='number'` → ต้องเป็น number
   - `field_type='select'` → ต้องอยู่ใน `options_json`
   - `field_type='boolean'` → ต้องเป็น true/false

**Error Taxonomy (Standardized Error Types):**

| Error Type | Code | Description | Example |
|------------|------|-------------|---------|
| `missing_required_field` | `V3_MISSING_FIELD` | Required field missing in `constraints_json` | `thickness_mm` required but not provided |
| `invalid_type` | `V3_INVALID_TYPE` | Field value type mismatch | `thickness_mm` must be number, got string |
| `invalid_option` | `V3_INVALID_OPTION` | Select value not in `options_json` | `grain_direction="invalid"` not in options |
| `missing_role_lines` | `V3_MISSING_ROLE` | Graph requires role but BOM has no lines | Slot "BODY" requires 1 LINING line but found 0 |
| `not_mapped` | `V3_NOT_MAPPED` | Component not mapped to slot | Component 123 not mapped to any anchor_slot |
| `legacy_only_warning` | `V3_LEGACY_WARNING` | Using legacy table/field (read-only) | Reading from `product_config_component_slot` (legacy) |

**Error Format:**
```json
{
  "ok": false,
  "error": "Validation failed",
  "error_code": "V3_MISSING_FIELD",
  "errors": [
    {
      "type": "missing_required_field",
      "field": "thickness_mm",
      "role": "MAIN_MATERIAL",
      "message": "Required field 'thickness_mm' is missing for role MAIN_MATERIAL"
    }
  ]
}
```

**UI Rendering:**
- UI ต้อง render errors ตาม `type` (ไม่ต้อง parse `message`)
- `type` เป็น enum ที่ UI รู้จัก (missing_required_field, invalid_type, etc.)

---

### V-Hatthasilpa (แนะนำเป็น Phase 2)

**เมื่อกด "Validate" หรือก่อน publish product config:**

1. **Graph Requirements Check:**
   - ตรวจ `graph_slot_role_requirement` (ถ้ามี) เทียบกับ BOM ของ component ที่ mapped
   - สำหรับทุก slot ที่ component mapped:
     - เช็ค `min_lines` (มี BOM lines ครบตาม role หรือไม่)
     - เช็ค `required_fields_json` (มี required fields ครบหรือไม่)

2. **Output Format:**
   - รายการ issues แบบ actionable:
     - `missing_role_lines`: Slot "BODY" requires 1 LINING line but found 0
     - `missing_required_fields`: LINING line missing "bonding_method"
     - `invalid_value_type`: thickness_mm must be number

**Example Response:**
```json
{
  "ok": true,
  "status": "VALID" | "INVALID" | "WARNING",
  "issues": [
    {
      "slot": "BODY",
      "component_id": 123,
      "type": "missing_role_lines",
      "role": "LINING",
      "required": 1,
      "found": 0,
      "message": "Slot BODY requires 1 LINING line but found 0"
    }
  ]
}
```

---

### V-Classic

- ไม่ enforce graph requirements
- Role-based validation ยังใช้ได้ (เพื่อข้อมูลดีขึ้น) แต่ไม่ต้อง block หนัก

---

## 17. Acceptance Criteria (Definition of Done)

**Agent ต้องส่งมอบอะไรถึงเรียกว่าเสร็จ:**

### DB Layer ✅

- [ ] `product_component_material` มี `role_code`, `constraints_json` columns
- [ ] มี `material_role_catalog` table
- [ ] มี `material_role_field` table
- [ ] มี `product_component_slot_spec` table (slot properties only)
- [ ] Seed roles 8 อัน (MAIN_MATERIAL, LINING, REINFORCEMENT, HARDWARE, THREAD, EDGE_FINISH, ADHESIVE, PACKAGING)
- [ ] Seed fields ขั้นต่ำ "พอใช้งานจริง" (ไม่ต้องสมบูรณ์ทุก role แต่ต้องจบ flow)

**Evidence:**
- Migration files ผ่าน syntax check
- Seed data มี roles + fields สำหรับ MAIN_MATERIAL และ LINING อย่างน้อย

---

### API Layer ✅

- [ ] BOM CRUD รองรับ `role_code` + `constraints_json`
- [ ] Endpoint `list_roles` (get material_role_catalog)
- [ ] Endpoint `list_role_fields` (get material_role_field for role)
- [ ] Slot spec CRUD (quantity/is_required/dimensions) แยกชัด
- [ ] Validation endpoint (อย่างน้อย role-based)

**Evidence:**
- API responses มี `role_code`, `constraints_json`
- Validation endpoint return errors ตาม required fields

---

### UI Layer ✅

- [ ] BOM table มี Role dropdown + Configure button ต่อแถว
- [ ] Configure modal เป็น data-driven (render จาก `material_role_field`)
- [ ] "Production Constraints section แบบ slot-level" ถูก remove/deprecate (หรือ read-only summary เท่านั้น)
- [ ] แสดง badge/สถานะ "ครบ/ไม่ครบ" ต่อ BOM line

**Evidence:**
- BOM table แสดง role column
- Configure modal ไม่ hardcode fields
- Slot-level constraints section ไม่มีหรือเป็น read-only

---

### Legacy/Compatibility ✅

- [ ] `product_config_component_slot` ไม่ถูกใช้งานเป็น SSOT อีก
- [ ] ถ้ายังต้องอ่าน legacy: ต้องเป็น read-only และมี label "legacy" ชัด

**Evidence:**
- Code ไม่ write ไป `product_config_component_slot` (ยกเว้น migration script)
- UI แสดง "Legacy" label ถ้ายังอ่านจาก legacy table

**Deprecate Legacy - Evidence Check (Machine-Checkable):**

**Rule:** โค้ด production ห้ามเรียก `UPDATE`/`INSERT` ไปที่ `product_config_component_slot` (ยกเว้น migration tool/endpoint ที่ต้องติด label `__legacy_migration_only`)

**Evidence Check Script (DEV-only):**
```bash
# Grep for writes to legacy table (must be empty or only __legacy_migration_only)
grep -r "UPDATE.*product_config_component_slot\|INSERT.*product_config_component_slot" source/ --exclude-dir=vendor
# Expected: Only migration scripts with __legacy_migration_only label

# Grep for __legacy_migration_only label (must exist if any writes found)
grep -r "__legacy_migration_only" source/
```

**Acceptance:**
- Production code (source/**/*.php) ไม่มี `UPDATE`/`INSERT` ไป `product_config_component_slot` (ยกเว้น migration scripts)
- Migration scripts ต้องมี comment `// __legacy_migration_only` และ guard ด้วย `if (!defined('LEGACY_MIGRATION_MODE')) { die(); }`

---

### Audit Trail / Logging ✅

**Requirement:** ทุกการแก้ `constraints_json` / `role_code` ต้องเขียน log เข้า `product_config_log` (หรือ log table ใหม่ถ้าจำเป็น)

**Log Payload Structure:**
```json
{
  "action": "update_bom_constraints",
  "id_product": 123,
  "id_component": 456,
  "id_material": 789,
  "field": "constraints_json",
  "before": {"thickness_mm": 0.8},
  "after": {"thickness_mm": 1.0},
  "changed_by": 1,
  "changed_at": "2025-12-25 10:30:00"
}
```

**Alternative (Hash + Diff):**
```json
{
  "action": "update_bom_constraints",
  "id_product": 123,
  "id_component": 456,
  "id_material": 789,
  "field": "constraints_json",
  "before_hash": "abc123",
  "after_hash": "def456",
  "diff": {"thickness_mm": {"old": 0.8, "new": 1.0}},
  "changed_by": 1,
  "changed_at": "2025-12-25 10:30:00"
}
```

**DoD Requirement (Phase 1/2):**
- [ ] BOM CRUD API writes log entry เมื่อแก้ `role_code` หรือ `constraints_json`
- [ ] Log table: `product_config_log` (หรือ extend existing log table)
- [ ] Log payload ต้องมี `before`/`after` หรือ `before_hash`/`after_hash` + `diff`
- [ ] Log ต้องมี `changed_by` (user ID) และ `changed_at` (timestamp)

**Evidence:**
- API code มี log write หลัง UPDATE/INSERT `product_component_material`
- Log table schema มี fields: `action`, `id_product`, `id_component`, `id_material`, `field`, `before`, `after`, `changed_by`, `changed_at`
- Test: Save BOM line → verify log entry created

---

## 18. What NOT To Build (Anti-Patterns)

**Anti-Patterns ที่ Agent ชอบพลาด — ห้ามทำ:**

### ❌ "Slot-level constraints v2"

**ห้าม:** เปลี่ยนชื่อ table แต่ยังทำแบบเดิม (เช่น `product_config_component_slot_v2` ที่ยังยึด `anchor_slot` เป็นหลักสำหรับวัสดุ)

**Why:** ละเมิด I1 (Material constraints ต้องอยู่ที่ BOM line)

---

### ❌ "Constraints per component" แบบรวมๆ

**ห้าม:** ผูก material constraints กับ component แบบรวมๆ (ไม่ผูกกับ BOM line)

**Why:** ละเมิด I1 (Material constraints ต้องอยู่ที่ BOM line)

---

### ❌ "Hardcode constraints fields" ใน JS

**ห้าม:** Hardcode fields ใน JS แบบตายตัว (เช่น `if (role === 'LINING') { showField('bonding_method') }`)

**Why:** ละเมิด I3 (UI ต้อง data-driven จาก `material_role_field`)

**Exception:** โครงสร้าง renderer (เช่น `renderField(fieldDef)`) hardcode ได้

---

### ❌ "material_specification comeback"

**ห้าม:** กลับมาเป็น text intent (เช่น `material_specification` field ใหม่)

**Why:** Duplicate/intent เก๊ ไม่เชื่อมกับ BOM จริง

---

## 19. Implementation Phasing

**เพื่อให้ Agent แตก patch ถูก:**

### Phase 1 (M1 + UI minimal)

**Deliverables:**
- [ ] DB: Add `role_code`, `constraints_json` to `product_component_material`
- [ ] DB: Create `material_role_catalog`, `material_role_field` tables
- [ ] DB: Create `product_component_slot_spec` table
- [ ] Seed: 8 roles + minimal fields (MAIN_MATERIAL, LINING อย่างน้อย)
- [ ] API: List roles + list fields for role
- [ ] API: BOM CRUD รองรับ `role_code` + `constraints_json`
- [ ] UI: BOM table — Role dropdown + Configure button
- [ ] UI: Configure modal (data-driven)
- [ ] Validation: Role-based (required fields check)
- [ ] UI: Status badge (ครบ/ไม่ครบ)
- [ ] Deprecate: Slot-level constraints section (remove or read-only)

**Acceptance:** BOM line สามารถตั้ง role + configure constraints ได้

---

### Phase 2 (Slot spec cleanup)

**Deliverables:**
- [ ] API: Slot spec CRUD (quantity/is_required/dimensions)
- [ ] UI: Slot spec editor (ถ้าจำเป็น)
- [ ] Migration: Map quantity/is_required ออกจาก legacy (ถ้ามี)

**Acceptance:** Slot properties แยกชัดจาก material constraints

---

### Phase 3 (Graph-aware validation)

**Deliverables:**
- [ ] DB: Create `graph_slot_role_requirement` table (optional)
- [ ] API: Graph-aware validation endpoint
- [ ] UI: Validate button + issues display

**Acceptance:** Validate against graph binding + mapping

---

## 20. Agent Prompt (Ready-to-Use)

**คัดลอกไปใช้ได้ทันทีเมื่อสั่ง Agent ให้ทำงาน:**

```
Implement PRODUCTS & COMPONENTS V3 ตามเอกสาร 
docs/super_dag/01-concepts/PRODUCTS_COMPONENTS_V3_CONCEPT.md 

โดยยึด invariants:
(1) Material constraints ต้องอยู่ที่ product_component_material.constraints_json เท่านั้น
(2) Slot spec แยกไป product_component_slot_spec เก็บได้แค่ quantity/is_required/dimensions
(3) UI constraints ต้อง data-driven จาก material_role_field ห้าม hardcode fields
(4) Graph เป็น SSOT ของ slots ห้าม invent slots เอง

Phase 1 deliverables:
- DB migrations (add role_code, constraints_json + create role catalog tables + seed 8 roles + minimal fields)
- API to list roles/fields + BOM CRUD รองรับ constraints_json
- UI BOM table add role dropdown + configure modal (data-driven) + role-based validation + status badge
- Deprecate slot-level constraints section (remove or make summary read-only)

Do not create any new slot-level constraints table.
```

---

## 21. Quick Reference Checklist

**Agent ใช้ checklist นี้ก่อนส่งมอบ:**

### Pre-Implementation
- [ ] อ่าน `PRODUCTS_COMPONENTS_V3_CONCEPT.md` ครบ
- [ ] อ่าน `DATABASE_SCHEMA_PRODUCTS_COMPONENTS.md` (V2 current state)
- [ ] ตรวจสอบ invariants (I1-I4) ว่าเข้าใจแล้ว

### Implementation
- [ ] DB migrations: Additive only (ไม่ลบของเดิม)
- [ ] API: BOM CRUD รองรับ `role_code` + `constraints_json`
- [ ] UI: Data-driven form generation (ไม่ hardcode)
- [ ] Validation: Role-based (required fields check)

### Post-Implementation
- [ ] Legacy table (`product_config_component_slot`) ไม่ถูกใช้เป็น SSOT
- [ ] Slot-level constraints section ถูก remove/deprecate
- [ ] Tests: Role-based validation ผ่าน
- [ ] Documentation: Update schema docs

---

**End of Document**

