# Material Architecture V2 - Bellavier Protocol

> **Version:** 2.3 (Final)  
> **Status:** ✅ APPROVED - Ready for Implementation  
> **Date:** 2025-12-05  
> **Author:** Bellavier Architecture Team  
> **Reviewed By:** Owner

---

## 🔍 System Audit Notes (2025-12-05)

| Spec | Actual DB | Status |
|------|-----------|--------|
| `products` | `product` | ✅ Spec updated to `product` |
| `material` | `material` | ✅ Match |
| `unit_of_measure` | `unit_of_measure` | ✅ Match |
| anchor_slot format | `SLOT_BODY` → `BODY` | ⚠️ Needs migration |
| `component_catalog` | 35 semi-physical records | ⚠️ Mark as legacy |

**Decision:** Follow Spec V2 100%, migrate existing data.

---

## 📐 Executive Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│                    BELLAVIER MATERIAL ARCHITECTURE                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Layer 1: ROUTING COMPONENT (Graph Designer)                        │
│   ════════════════════════════════════════════                       │
│   • Generic names: BODY, FLAP, STRAP, POCKET                        │
│   • Table: component_type_catalog                                    │
│   • Purpose: Flow abstraction, QC rework boundary                    │
│   • Owner: Graph Designer                                            │
│                                                                      │
│                           │ anchor_slot mapping                      │
│                           ▼                                          │
│                                                                      │
│   Layer 2: PRODUCT COMPONENT (Product Config)                        │
│   ════════════════════════════════════════════                       │
│   • Physical spec: BODY_AIMEE_MINI_2025_GREENTEA                    │
│   • Table: product_component                                         │
│   • Purpose: BOM, Costing, Material Spec, QC Defect                 │
│   • Owner: Product Modal                                             │
│                                                                      │
│                           │ owns BOM                                 │
│                           ▼                                          │
│                                                                      │
│   Layer 3: MATERIAL BOM (Per Product Component)                      │
│   ════════════════════════════════════════════                       │
│   • Table: product_component_material                                │
│   • Purpose: Material list per component                             │
│   • Drives: Reservation, Deduction, Costing                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Database Schema

### Table 1: `component_type_catalog` (Layer 1 - NEW, replaces component_catalog)

```sql
CREATE TABLE IF NOT EXISTS `component_type_catalog` (
    `id_component_type` INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Identity
    `type_code` VARCHAR(30) NOT NULL COMMENT 'Generic code: BODY, FLAP, STRAP',
    `type_name_en` VARCHAR(100) NOT NULL COMMENT 'English name',
    `type_name_th` VARCHAR(100) NOT NULL COMMENT 'Thai name',
    
    -- Classification
    `category` ENUM('MAIN', 'ACCESSORY', 'HARDWARE', 'LINING') NOT NULL DEFAULT 'MAIN',
    `display_order` INT NOT NULL DEFAULT 0,
    
    -- Status
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE KEY `uk_type_code` (`type_code`)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Layer 1: Generic component types for Graph routing (BODY, FLAP, STRAP)';
```

**Seed Data:**
```sql
INSERT INTO component_type_catalog (type_code, type_name_en, type_name_th, category, display_order) VALUES
('BODY', 'Body', 'ตัวกระเป๋า', 'MAIN', 1),
('FLAP', 'Flap', 'ฝาปิด', 'MAIN', 2),
('STRAP', 'Strap', 'สายสะพาย', 'ACCESSORY', 3),
('HANDLE', 'Handle', 'หูหิ้ว', 'ACCESSORY', 4),
('POCKET', 'Pocket', 'ช่องกระเป๋า', 'MAIN', 5),
('GUSSET', 'Gusset', 'ข้างกระเป๋า', 'MAIN', 6),
('LINING', 'Lining', 'ซับใน', 'LINING', 7),
('ZIPPER_PANEL', 'Zipper Panel', 'แผงซิป', 'ACCESSORY', 8);
```

**📏 type_code Naming Rules:**
```
✅ MUST be UPPERCASE only: BODY, FLAP, STRAP, HANDLE
❌ NOT allowed: body, Body, strap_long, Strap-Main

Pattern: [A-Z][A-Z0-9_]{1,29}
• Start with uppercase letter
• Only uppercase letters, numbers, underscore
• Max 30 characters

Reason: Ensures exact match with routing_node.anchor_slot
        Simplifies validation and case-sensitive comparisons
```

---

### Table 2: `product_component` (Layer 2 - Physical Spec)

```sql
CREATE TABLE IF NOT EXISTS `product_component` (
    `id_product_component` INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Ownership
    `id_product` INT NOT NULL COMMENT 'FK to product.id_product',
    
    -- Component Identity
    `component_code` VARCHAR(100) NOT NULL COMMENT 'Unique code: BODY_AIMEE_MINI_2025_GREENTEA',
    `component_name` VARCHAR(200) NOT NULL COMMENT 'Display name',
    
    -- Link to Routing Layer
    `component_type_code` VARCHAR(30) NOT NULL COMMENT 'FK to component_type_catalog.type_code (BODY, FLAP, etc.)',
    
    -- Physical Specifications
    `pattern_size` VARCHAR(50) NULL COMMENT 'e.g., 22cm x 14cm',
    `pattern_code` VARCHAR(50) NULL COMMENT 'Pattern reference code',
    `edge_width_mm` DECIMAL(5,2) NULL COMMENT 'Edge width in mm',
    `stitch_count` INT NULL COMMENT 'Estimated stitch count',
    `estimated_time_minutes` INT NULL COMMENT 'Estimated work time',
    
    -- Notes
    `notes` TEXT NULL,
    
    -- Metadata
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_by` INT NULL,
    
    -- Constraints
    UNIQUE KEY `uk_product_component_code` (`id_product`, `component_code`),
    INDEX `idx_product` (`id_product`),
    INDEX `idx_component_type` (`component_type_code`),
    INDEX `idx_product_type` (`id_product`, `component_type_code`),  -- For querying by product + type
    
    -- Foreign Keys
    CONSTRAINT `fk_pc_product` 
        FOREIGN KEY (`id_product`) REFERENCES `product` (`id_product`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_pc_component_type` 
        FOREIGN KEY (`component_type_code`) REFERENCES `component_type_catalog` (`type_code`)
        ON DELETE RESTRICT ON UPDATE CASCADE
        
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Layer 2: Physical component specs per product (owns BOM)';
```

**📏 component_code Naming Guidelines:**
```
Suggested pattern:
  {TYPE_CODE}_{PRODUCT_CODE}_{YEAR}_{VARIANT}

Examples:
  BODY_AIMEE_MINI_2025_GREENTEA
  STRAP_AIMEE_MINI_2025_GREENTEA_LONG
  FLAP_TOTE_2025_CARAMEL

Rules:
  ✅ Readable: ดูแล้วรู้ว่าเป็นชิ้นส่วนของ product ไหน
  ✅ Unique within product: UNIQUE(id_product, component_code)
  ✅ UPPERCASE preferred (consistent with type_code)
  
  ❌ ห้ามซ้ำกันใน product เดียว
  ❌ ห้ามใช้ special characters ที่อาจมีปัญหา (/, \, ?, #)

Note: Pattern ไม่บังคับตายตัว ทีมสามารถเลือกเองได้
      แต่ควรตั้งชื่อไปทิศทางเดียวกันทั้งองค์กร
```

---

### Table 3: `product_component_material` (BOM per Component)

```sql
CREATE TABLE IF NOT EXISTS `product_component_material` (
    `id_pcm` INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Component Reference
    `id_product_component` INT NOT NULL COMMENT 'FK to product_component',
    
    -- Material Reference
    `material_sku` VARCHAR(100) NOT NULL COMMENT 'FK to material.sku',
    
    -- BOM Specification
    `qty_required` DECIMAL(18,6) NOT NULL DEFAULT 1.000000 COMMENT 'Quantity needed',
    `uom_code` VARCHAR(30) NULL COMMENT 'Unit of measure (null = inherit from material)',
    
    -- Classification
    `is_primary` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1=Primary, 0=Alternative',
    `priority` INT NOT NULL DEFAULT 1 COMMENT 'Display/selection order',
    
    -- Notes
    `notes` TEXT NULL,
    
    -- Metadata
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE KEY `uk_component_material` (`id_product_component`, `material_sku`),
    INDEX `idx_component` (`id_product_component`),  -- For BOM queries by component
    INDEX `idx_material_sku` (`material_sku`),
    
    -- Foreign Keys
    CONSTRAINT `fk_pcm_component` 
        FOREIGN KEY (`id_product_component`) REFERENCES `product_component` (`id_product_component`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    -- NOTE: Verify actual table name before migration (material vs materials)
    CONSTRAINT `fk_pcm_material` 
        FOREIGN KEY (`material_sku`) REFERENCES `material` (`sku`)
        ON DELETE RESTRICT ON UPDATE CASCADE
        
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='BOM: Materials required per product component';
```

---

### Table 4: `graph_component_mapping` (LEGACY STATUS)

```
┌─────────────────────────────────────────────────────────────────────┐
│  ⚠️ graph_component_mapping = LEGACY for Material Architecture V2   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  This table was created in Task 27.13 for POC/demo purposes.         │
│                                                                      │
│  Current Use:                                                        │
│  • Provides anchor_slot list for a graph                            │
│  • Used by UI "Component Mapping" tab in Product Modal               │
│                                                                      │
│  For Material Architecture V2:                                       │
│  ❌ NOT used for BOM calculation                                    │
│  ❌ NOT used for Costing                                            │
│  ❌ NOT used for Material Reservation                                │
│  ❌ component_code column → obsolete (was FK to old component_catalog)│
│                                                                      │
│  Migration: anchor_slot format only                                  │
│  • Change SLOT_BODY → BODY (to match component_type_catalog)         │
│  • Add FK: anchor_slot → component_type_catalog.type_code           │
│                                                                      │
│  Future Decision (TBD):                                              │
│  • Option A: Keep as legacy reference, ignore component_code         │
│  • Option B: Deprecate entirely, use product_component as source     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Migration SQL:**
```sql
-- Update anchor_slot format
UPDATE graph_component_mapping
SET anchor_slot = REPLACE(anchor_slot, 'SLOT_', '')
WHERE anchor_slot LIKE 'SLOT_%';

-- Add FK to component_type_catalog (after migration)
ALTER TABLE graph_component_mapping 
    MODIFY COLUMN anchor_slot VARCHAR(30) NOT NULL,
    ADD CONSTRAINT `fk_gcm_component_type` 
    FOREIGN KEY (`anchor_slot`) REFERENCES `component_type_catalog` (`type_code`)
    ON DELETE RESTRICT ON UPDATE CASCADE;
```

---

## 🔗 Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DATA FLOW                                    │
└─────────────────────────────────────────────────────────────────────┘

                    GRAPH DESIGNER
                         │
                         │ uses
                         ▼
              ┌─────────────────────┐
              │ component_type_     │
              │ catalog             │
              │ ─────────────────── │
              │ BODY                │
              │ FLAP                │
              │ STRAP               │
              └─────────────────────┘
                         │
                         │ anchor_slot
                         ▼
              ┌─────────────────────┐
              │ routing_node        │
              │ ─────────────────── │
              │ anchor_slot: BODY   │◄──── Graph Template
              │ anchor_slot: FLAP   │
              │ anchor_slot: STRAP  │
              └─────────────────────┘


                    PRODUCT CONFIG
                         │
                         │ owns
                         ▼
┌──────────────┐    ┌─────────────────────┐
│ product      │───►│ product_component   │
│ ──────────── │    │ ─────────────────── │
│ Aimee Mini   │    │ BODY_AIMEE_2025_GRN │
│ Greentea     │    │ FLAP_AIMEE_2025_GRN │
└──────────────┘    │ STRAP_AIMEE_2025_GRN│
                    └─────────────────────┘
                              │
                              │ owns BOM
                              ▼
                    ┌─────────────────────┐
                    │ product_component_  │
                    │ material            │
                    │ ─────────────────── │
                    │ Goat #19 - 1.2 sqft │
                    │ Microfiber - 0.8    │
                    │ Gold Buckle - 2 pcs │
                    └─────────────────────┘
                              │
                              │ used by
                              ▼
                    ┌─────────────────────┐
                    │ JOB EXECUTION       │
                    │ ─────────────────── │
                    │ Material Reservation│
                    │ Material Deduction  │
                    │ Cost Calculation    │
                    │ QC Defect Tracking  │
                    │ Serial Traceability │
                    └─────────────────────┘
```

---

## 🖥️ UI Design

### Product Modal - Components Tab

```
┌─────────────────────────────────────────────────────────────────────┐
│  Product: Aimee Mini Greentea                              [Save]   │
├─────────────────────────────────────────────────────────────────────┤
│ [General] [Pricing] [Components] [Gallery] [Production Flow]        │
│                         ▲▲▲▲▲▲▲▲▲                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Product Components                                [+ Add Component] │
│  ══════════════════════════════════════════════════════════════════ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ BODY_AIMEE_MINI_2025_GREENTEA                      [Edit] [🗑️] │ │
│  │ Type: BODY (ตัวกระเป๋า)                                         │ │
│  │ Pattern: 22cm x 14cm | Edge: 0.8mm | Est. Time: 45 min         │ │
│  │                                                                 │ │
│  │ 📦 Materials (2)                                                │ │
│  │ ├── Goat #19 Greentea ────────── 1.24 sq.ft  ⭐               │ │
│  │ └── Microfiber Mint ──────────── 0.80 sq.ft  ⭐               │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ STRAP_AIMEE_MINI_LONG_2025_GREENTEA                [Edit] [🗑️] │ │
│  │ Type: STRAP (สายสะพาย)                                          │ │
│  │ Pattern: 103cm x 2cm | Stitches: 380 | Est. Time: 25 min       │ │
│  │                                                                 │ │
│  │ 📦 Materials (2)                                                │ │
│  │ ├── Goat #19 Greentea ────────── 0.40 sq.ft  ⭐               │ │
│  │ └── Gold Buckle #202 ─────────── 2 pcs       ⭐               │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ FLAP_AIMEE_MINI_2025_GREENTEA                      [Edit] [🗑️] │ │
│  │ Type: FLAP (ฝาปิด)                                              │ │
│  │ Pattern: 18cm x 12cm | Edge: 0.8mm | Est. Time: 30 min         │ │
│  │                                                                 │ │
│  │ 📦 Materials (1)                                                │ │
│  │ └── Goat #19 Greentea ────────── 0.60 sq.ft  ⭐               │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ══════════════════════════════════════════════════════════════════ │
│  📊 Total Materials Summary                                          │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Goat #19 Greentea ─────────────────────────────── 2.24 sq.ft   │ │
│  │ Microfiber Mint ──────────────────────────────── 0.80 sq.ft   │ │
│  │ Gold Buckle #202 ─────────────────────────────── 2 pcs        │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Add/Edit Component Modal

```
┌─────────────────────────────────────────────────────────────────────┐
│  Add Component to: Aimee Mini Greentea                       [✕]   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Component Type *                                                    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ [BODY - ตัวกระเป๋า                                      ▼] │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Component Code * (auto-generated, editable)                         │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ BODY_AIMEE_MINI_2025_GREENTEA                               │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Component Name *                                                    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ Body - Aimee Mini Greentea 2025                             │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ─────────────────── Physical Specifications ───────────────────    │
│                                                                      │
│  Pattern Size          Pattern Code          Edge Width (mm)         │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐         │
│  │ 22cm x 14cm  │     │ PAT-AM-BODY  │     │ 0.8          │         │
│  └──────────────┘     └──────────────┘     └──────────────┘         │
│                                                                      │
│  Est. Stitch Count    Est. Time (min)                                │
│  ┌──────────────┐     ┌──────────────┐                               │
│  │ 420          │     │ 45           │                               │
│  └──────────────┘     └──────────────┘                               │
│                                                                      │
│  ─────────────────── Materials (BOM) ───────────────────────────    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Material             │ Qty      │ Unit    │ Primary │ ✕     │   │
│  ├──────────────────────────────────────────────────────────────┤   │
│  │ Goat #19 Greentea    │ 1.24     │ sq.ft   │   ☑    │ [🗑️] │   │
│  │ Microfiber Mint      │ 0.80     │ sq.ft   │   ☑    │ [🗑️] │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                  [+ Add Material]    │
│                                                                      │
│  Notes                                                               │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                                                              │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│                                    [Cancel]  [Save Component]        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Flow Diagrams

### Flow 1: Product Setup

```
1. Admin สร้าง Product ใหม่
   │
   ▼
2. เปิด Product Modal → Tab "Components"
   │
   ▼
3. คลิก [+ Add Component]
   │
   ▼
4. เลือก Component Type (BODY, FLAP, STRAP...)
   │
   ▼
5. ระบบ auto-generate Component Code
   │
   ▼
6. กรอก Physical Specs (pattern, edge, time)
   │
   ▼
7. เพิ่ม Materials (BOM)
   │
   ▼
8. บันทึก → product_component + product_component_material
```

### Flow 2: Job Creation (Future - Task 27.18)

```
1. User สร้าง Job สำหรับ Product X
   │
   ▼
2. ระบบดึง product_component ของ Product X
   │
   ▼
3. ระบบดึง product_component_material ของแต่ละ component
   │
   ▼
4. ระบบ SUM total materials needed
   │
   ▼
5. ระบบทำ Material Reservation
   │
   ▼
6. Job Token สร้างพร้อม component_code reference
```

### Flow 3: CUT Node Execution (Future - Task 27.18)

```
1. Token ถึง CUT node
   │
   ▼
2. ระบบอ่าน token.component_code
   │
   ▼
3. ระบบดึง BOM จาก product_component_material
   │
   ▼
4. ระบบ Deduct materials จาก Inventory
   │
   ▼
5. บันทึก material_issue record (traceability)
```

---

## ⚠️ Implementation Notes (READ BEFORE CODING!)

### 1. Table Names (VERIFIED 2025-12-05)

```
✅ Confirmed actual table names in database:
   - `product` (NOT products)
   - `material` (NOT materials)
   - `unit_of_measure` (code column for UOM validation)

All FKs in this spec use correct table names.
```

### 2. anchor_slot Migration (REQUIRED)

```sql
-- Current data in production:
-- routing_node.anchor_slot = 'SLOT_BODY', 'SLOT_FLAP', 'SLOT_STRAP'
-- graph_component_mapping.anchor_slot = 'SLOT_BODY', 'SLOT_FLAP', 'SLOT_STRAP'

-- MIGRATION REQUIRED: Remove SLOT_ prefix to match Spec V2

-- Step 1: Update routing_node
UPDATE routing_node 
SET anchor_slot = REPLACE(anchor_slot, 'SLOT_', '')
WHERE anchor_slot LIKE 'SLOT_%';

-- Step 2: Update graph_component_mapping
UPDATE graph_component_mapping
SET anchor_slot = REPLACE(anchor_slot, 'SLOT_', '')
WHERE anchor_slot LIKE 'SLOT_%';

-- Step 3: After component_type_catalog is created, add FK:
ALTER TABLE graph_component_mapping 
  ADD CONSTRAINT fk_gcm_component_type 
  FOREIGN KEY (anchor_slot) REFERENCES component_type_catalog(type_code)
  ON DELETE RESTRICT ON UPDATE CASCADE;
```

### 3. Legacy component_catalog Handling

```
⚠️ IMPORTANT: Existing component_catalog table (35 records) is now LEGACY

Current data includes:
- BODY_MAIN, BODY_FRONT, BODY_BACK... (6 records)
- STRAP_MAIN, STRAP_SHORT, STRAP_LONG... (6 records)
- etc.

These are "semi-physical" components - NOT pure generic types.

DECISION:
1. DO NOT delete component_catalog
2. DO NOT use it in NEW features
3. Mark as legacy in documentation
4. New features use ONLY:
   - component_type_catalog (Layer 1)
   - product_component (Layer 2)
   - product_component_material (Layer 3)

Future: May repurpose as "Default Component Template" library.
```

### 4. uom_code Validation

```php
// uom_code in product_component_material is nullable
// If NOT null, should validate against UOM master table
//
// Implementation note:
// - If uom_code is null → inherit from material.default_uom_code
// - If uom_code is set → validate exists in unit_of_measure table

// Example:
// - material.sku = 'LTH-GOAT-19', default_uom_code = 'sqft'
// - product_component_material.uom_code = NULL
// → System uses 'sqft' as unit for reservation/deduction
//
// - If uom_code = 'pcs' (explicit)
// → System uses 'pcs' instead of material default
```

### 5. Multiple Components of Same Type

```
// Current UNIQUE KEY allows multiple components of same type per product:
// UNIQUE KEY (`id_product`, `component_code`)
//
// This is CORRECT for real-world scenarios:
// - Product may have 2 STRAPs (STRAP_LEFT, STRAP_RIGHT)
// - Both have component_type_code = 'STRAP'
//
// If business rule needs "only 1 BODY per product" → enforce at Service/UI level
```

---

## 📋 Pre-Migration Checklist

```
Before running ANY migration, verify:

□ 1. routing_node has anchor_slot column
     SELECT COUNT(*) FROM routing_node WHERE anchor_slot IS NOT NULL;
     Expected: ~3 rows (SLOT_BODY, SLOT_FLAP, SLOT_STRAP)

□ 2. graph_component_mapping exists
     SELECT COUNT(*) FROM graph_component_mapping;
     Expected: ~3 rows

□ 3. component_catalog exists (legacy)
     SELECT COUNT(*) FROM component_catalog WHERE is_active = 1;
     Expected: 35 rows (will be marked legacy, NOT deleted)

□ 4. product table exists (NOT products)
     DESCRIBE product;
     Expected: id_product, sku, name, etc.

□ 5. material table exists (NOT materials)
     DESCRIBE material;
     Expected: id_material, sku, name, etc.

□ 6. Backup taken before migration
     mysqldump -u root -p bgerp_t_maison_atelier > backup_before_v2.sql
```

---

## 📋 Implementation Tasks

### Phase 1: Database Migration (1.5 hr)

**Migration Order (CRITICAL):**

| Order | Task | Dependency |
|-------|------|------------|
| 1 | Create `component_type_catalog` table | None |
| 2 | Seed generic types (BODY, FLAP, STRAP...) | #1 |
| 3 | Migrate anchor_slot: `SLOT_X` → `X` | #2 |
| 4 | Add FK: `graph_component_mapping.anchor_slot` → `component_type_catalog.type_code` | #3 |
| 5 | Create `product_component` table | #1 |
| 6 | Create `product_component_material` table | #5 |
| 7 | Mark `component_catalog` as legacy (add comment, NOT delete) | None |

### Phase 2: Service Layer (2 hr)

| # | Task | File |
|---|------|------|
| 1 | `ComponentTypeService` (Layer 1) | New service |
| 2 | `ProductComponentService` (Layer 2) | New service |
| 3 | BOM calculation methods | Extend service |

### Phase 3: API (1.5 hr)

| # | Task | File |
|---|------|------|
| 1 | API for component types | `component_type_api.php` |
| 2 | API for product components | `product_api.php` (extend) |
| 3 | API for component materials | `product_api.php` (extend) |

### Phase 4: UI (3 hr)

| # | Task | File |
|---|------|------|
| 1 | Components Tab in Product Modal | `products.js` |
| 2 | Add/Edit Component Modal | `products.js` |
| 3 | Materials sub-form | `products.js` |
| 4 | Total Materials Summary | `products.js` |

---

## ✅ Definition of Done

- [ ] `component_type_catalog` table with seed data
- [ ] `product_component` table with FK to product
- [ ] `product_component_material` table (BOM)
- [ ] Services for CRUD operations
- [ ] API endpoints with proper permissions
- [ ] Product Modal - Components Tab working
- [ ] Add/Edit Component Modal working
- [ ] Materials sub-form working
- [ ] Total Materials Summary calculated
- [ ] All collations matched (utf8mb4_unicode_ci)
- [ ] i18n applied to all UI text

---

## 🚫 Out of Scope

1. ❌ Material Variant at Product level → **Never** (สี/วัสดุเปลี่ยน = Product ใหม่)
2. ❌ Consumables tracking (thread, glue) → **Never** (ไม่ track ในระบบ)
3. ❌ Material Reservation logic → Task 27.18
4. ❌ Material Deduction logic → Task 27.18
5. ❌ Per-product material override → **Never** (see explanation below)
6. ❌ Dynamic material input at job execution

### Explanation: "Per-product material override = Never"

```
Some ERP systems have:
  • "Global Component BOM" = default material formula for BODY
  • "Per-product Override" = some products override the default

But in Bellavier Material Architecture V2:
  ❌ NO "Global Component BOM"
  ❌ NO "Default + Override" layer
  
  ✅ BOM stored directly at product_component
  ✅ Every Product has its own 100% independent component + BOM
  
Therefore "Per-product override" is meaningless in this system
because "ALL BOM = per-product from the beginning"
```

---

## 🛡️ Golden Rules (NEVER BREAK!)

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ARCHITECTURE DISCIPLINE                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ✅ DO:                                                              │
│  ────                                                                │
│  1. Core behavior (token, split/merge, costing, QC)                 │
│     ONLY use these 3 tables:                                         │
│     - component_type_catalog                                         │
│     - product_component                                              │
│     - product_component_material                                     │
│                                                                      │
│  2. Graph Designer uses generic types only (BODY, FLAP, STRAP)      │
│                                                                      │
│  3. Product Modal owns all physical component specs                  │
│                                                                      │
│  4. BOM calculation uses product_component_material only             │
│                                                                      │
│  5. anchor_slot MUST use type_code from component_type_catalog      │
│     ✅ Use: BODY, FLAP, STRAP, HANDLE, POCKET                       │
│     ❌ Never: SLOT_BODY, BODY_SLOT_1, custom strings                │
│                                                                      │
│  ❌ NEVER:                                                           │
│  ──────                                                              │
│  1. Use legacy component_catalog in NEW features                     │
│                                                                      │
│  2. Let Graph Designer define material/cost                          │
│                                                                      │
│  3. Hard-code assumption "1 product = 1 BODY only"                  │
│     (Product may have multiple STRAP or POCKET)                      │
│                                                                      │
│  4. Assume single-tenant/single-factory behavior                     │
│     (Design for multi-factory future)                                │
│                                                                      │
│  5. Use graph_component_mapping for BOM/Costing/Reservation          │
│     (This table is LEGACY for Material Architecture V2)              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📚 Related Documents

- `docs/super_dag/tasks/task27.13_COMPONENT_NODE_PLAN.md`
- `docs/super_dag/tasks/MASTER_IMPLEMENTATION_ROADMAP.md`
- `docs/super_dag/specs/MATERIAL_REQUIREMENT_RESERVATION_SPEC.md`

