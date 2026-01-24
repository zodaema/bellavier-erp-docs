# 27.13.11b Material Linking - Implementation Plan (V2.2)

> **Feature:** Product Component + BOM Architecture  
> **Priority:** 🔴 CRITICAL (Required for Job Material Calculation)  
> **Estimated Duration:** 7.5 Hours  
> **Dependencies:** 27.12 Component Catalog (to be refactored)  
> **Parent Task:** 27.13 Component Node Type  
> **Spec Reference:** `docs/super_dag/specs/MATERIAL_ARCHITECTURE_V2.md`  
> **Last Audit:** 2025-12-05 (Verified against production DB)  
> **Status:** ✅ **COMPLETE** (Dec 5, 2025)

---

## 🔍 System Audit (2025-12-05 - FINAL)

| Item | Expected | Actual | Status |
|------|----------|--------|--------|
| Product table | `product` | `product` | ✅ Verified |
| Material table | `material` | `material` | ✅ Verified |
| UOM table | `unit_of_measure` | `unit_of_measure` | ✅ Verified |
| anchor_slot format | `BODY` | `BODY, FLAP, STRAP...` | ✅ **MIGRATED** |
| component_catalog | Legacy | 35 records, marked LEGACY | ✅ **DONE** |
| component_type_catalog | NEW Layer 1 | **24 types** (Bellavier Master List) | ✅ **COMPLETE** |
| product_component | NEW Layer 2 | Table ready | ✅ **COMPLETE** |
| product_component_material | NEW Layer 3 | Table ready | ✅ **COMPLETE** |
| ComponentTypeService | Service | Fully functional | ✅ **COMPLETE** |
| ProductComponentService | Service | Fully functional | ✅ **COMPLETE** |
| API endpoints | 11 endpoints | All working | ✅ **COMPLETE** |
| Components Tab UI | Product Modal | Fully functional | ✅ **COMPLETE** |
| Migration Consolidation | 0001 + 0002 | 100% schema match | ✅ **COMPLETE** |

**Status:** ✅ **ALL COMPLETE** - Database, Services, API, UI fully implemented and tested.

---

## 📐 Architecture Overview

### Bellavier Material System - 3 Layers

```
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 1: ROUTING COMPONENT (Graph Designer)                         │
│  ══════════════════════════════════════════                          │
│  Table: component_type_catalog                                       │
│  Data: BODY, FLAP, STRAP, POCKET, HANDLE                            │
│  Purpose: Generic anchor_slot for routing flow                       │
│  Owner: Graph Designer                                               │
│                                                                      │
│  ❌ ไม่มี material, size, color                                       │
│  ❌ ไม่ใช่ BOM                                                        │
├─────────────────────────────────────────────────────────────────────┤
│  Layer 2: PRODUCT COMPONENT (Product Config)                         │
│  ══════════════════════════════════════════                          │
│  Table: product_component                                            │
│  Data: BODY_AIMEE_MINI_2025_GREENTEA                                │
│  Purpose: Physical spec per product (pattern, edge, time)            │
│  Owner: Product Modal → Tab "Components"                             │
│                                                                      │
│  ✅ เก็บ spec จริงของชิ้นงาน                                          │
│  ✅ ผูกกับ Product เฉพาะ                                              │
├─────────────────────────────────────────────────────────────────────┤
│  Layer 3: BOM (Per Product Component)                                │
│  ══════════════════════════════════════════                          │
│  Table: product_component_material                                   │
│  Data: Goat #19 Greentea - 1.24 sq.ft                               │
│  Purpose: Material list per component                                │
│  Owner: Product Component                                            │
│                                                                      │
│  ✅ วัสดุที่ต้องใช้สำหรับ component นั้น                               │
│  ✅ ใช้สำหรับ Reservation, Deduction, Costing                         │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Key Principles (Bellavier Protocol)

### ✅ DO

1. **Product = Unique** - สี/วัสดุเปลี่ยน = Product ใหม่
2. **BOM ผูกกับ Product Component** - ไม่ใช่ Generic Component
3. **Graph ใช้ Generic anchor_slot** - BODY, FLAP, STRAP (ไม่รู้ material)
4. **Product Config map anchor → Physical Component**
5. **anchor_slot ต้องใช้ type_code จาก component_type_catalog เท่านั้น**
   - ✅ ใช้: `BODY`, `FLAP`, `STRAP`, `HANDLE`, `POCKET`...
   - ❌ ห้าม: `SLOT_BODY`, `BODY_SLOT_1`, custom strings

### ❌ DON'T

1. **ห้าม** Material Variant ที่ระดับ Product BOM
2. **ห้าม** Track consumables (thread, glue, edge paint)
3. **ห้าม** ให้ Graph Designer รู้จัก BOM
4. **ห้าม** Per-product material override

---

## 🗄️ Database Schema

### Table 1: `component_type_catalog` (Layer 1 - NEW, replaces component_catalog for new features)

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
COMMENT='Layer 1: Generic component types for Graph routing';
```

**Seed Data:**
| type_code | type_name_en | type_name_th | category |
|-----------|--------------|--------------|----------|
| BODY | Body | ตัวกระเป๋า | MAIN |
| FLAP | Flap | ฝาปิด | MAIN |
| STRAP | Strap | สายสะพาย | ACCESSORY |
| HANDLE | Handle | หูหิ้ว | ACCESSORY |
| POCKET | Pocket | ช่องกระเป๋า | MAIN |
| GUSSET | Gusset | ข้างกระเป๋า | MAIN |
| LINING | Lining | ซับใน | LINING |
| ZIPPER_PANEL | Zipper Panel | แผงซิป | ACCESSORY |

---

### Table 2: `product_component` (Layer 2 - NEW)

```sql
CREATE TABLE IF NOT EXISTS `product_component` (
    `id_product_component` INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Ownership
    `id_product` INT NOT NULL COMMENT 'FK to product.id_product',
    
    -- Component Identity
    `component_code` VARCHAR(100) NOT NULL COMMENT 'Unique: BODY_AIMEE_MINI_2025_GREENTEA',
    `component_name` VARCHAR(200) NOT NULL COMMENT 'Display name',
    
    -- Link to Routing Layer
    `component_type_code` VARCHAR(30) NOT NULL COMMENT 'FK to component_type_catalog.type_code',
    
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
    UNIQUE KEY `uk_product_component` (`id_product`, `component_code`),
    INDEX `idx_product` (`id_product`),
    INDEX `idx_component_type` (`component_type_code`),
    INDEX `idx_product_type` (`id_product`, `component_type_code`),
    
    -- Foreign Keys
    CONSTRAINT `fk_pc_product` 
        FOREIGN KEY (`id_product`) REFERENCES `product` (`id_product`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_pc_component_type` 
        FOREIGN KEY (`component_type_code`) REFERENCES `component_type_catalog` (`type_code`)
        ON DELETE RESTRICT ON UPDATE CASCADE
        
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Layer 2: Physical component specs per product';
```

---

### Table 3: `product_component_material` (Layer 3 - BOM)

```sql
CREATE TABLE IF NOT EXISTS `product_component_material` (
    `id_pcm` INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Component Reference
    `id_product_component` INT NOT NULL COMMENT 'FK to product_component',
    
    -- Material Reference
    `material_sku` VARCHAR(100) NOT NULL COMMENT 'FK to material.sku',
    
    -- BOM Specification
    `qty_required` DECIMAL(18,6) NOT NULL DEFAULT 1.000000,
    `uom_code` VARCHAR(30) NULL COMMENT 'null = inherit from material',
    
    -- Classification
    `is_primary` TINYINT(1) NOT NULL DEFAULT 1,
    `priority` INT NOT NULL DEFAULT 1,
    
    -- Notes
    `notes` TEXT NULL,
    
    -- Metadata
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE KEY `uk_component_material` (`id_product_component`, `material_sku`),
    INDEX `idx_component` (`id_product_component`),
    INDEX `idx_material_sku` (`material_sku`),
    
    -- Foreign Keys
    CONSTRAINT `fk_pcm_component` 
        FOREIGN KEY (`id_product_component`) REFERENCES `product_component` (`id_product_component`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_pcm_material` 
        FOREIGN KEY (`material_sku`) REFERENCES `material` (`sku`)
        ON DELETE RESTRICT ON UPDATE CASCADE
        
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Layer 3: BOM - Materials per product component';
```

---

## 🖥️ UI Design

### Location: Product Modal → Tab "Components"

```
┌─────────────────────────────────────────────────────────────────────┐
│  Product: Aimee Mini Greentea                              [Save]   │
├─────────────────────────────────────────────────────────────────────┤
│ [General] [Pricing] [Components] [Gallery] [Production Flow]        │
│                         ▲▲▲▲▲▲▲▲▲                                   │
│                         NEW TAB!                                     │
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
│  │ ...                                                             │ │
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

---

## 📋 Implementation Tasks

### Task 1: Database Migration (1.5 hr)

**File:** `database/tenant_migrations/2025_12_material_architecture_v2.php`

---

**⚠️ Pre-Migration Checklist (VERIFIED 2025-12-05):**

| Check | Command | Expected | Actual |
|-------|---------|----------|--------|
| Product table | `DESCRIBE product` | exists | ✅ |
| Material table | `DESCRIBE material` | exists | ✅ |
| anchor_slot values | `SELECT anchor_slot FROM routing_node WHERE anchor_slot IS NOT NULL` | `SLOT_*` | `SLOT_BODY, SLOT_FLAP, SLOT_STRAP` |
| component_catalog | `SELECT COUNT(*) FROM component_catalog` | >0 | 35 records |

---

**Migration Order (CRITICAL):**

```
Step 1: Create component_type_catalog (NEW table)
   │
   ▼
Step 2: Seed generic types (BODY, FLAP, STRAP...)
   │
   ▼
Step 3: Migrate anchor_slot values
   │     UPDATE routing_node SET anchor_slot = REPLACE(anchor_slot, 'SLOT_', '')
   │     UPDATE graph_component_mapping SET anchor_slot = REPLACE(anchor_slot, 'SLOT_', '')
   │
   ▼
Step 4: Verify collation = utf8mb4_unicode_ci
   │
   ▼
Step 5: Add FK: graph_component_mapping.anchor_slot → component_type_catalog.type_code
   │
   ▼
Step 6: Create product_component table
   │
   ▼
Step 7: Create product_component_material table
   │
   ▼
Step 8: Mark component_catalog as LEGACY (add table comment, NOT delete)
```

---

**Migration SQL Preview:**

```sql
-- Step 1: Create component_type_catalog
CREATE TABLE IF NOT EXISTS `component_type_catalog` (
    `id_component_type` INT AUTO_INCREMENT PRIMARY KEY,
    `type_code` VARCHAR(30) NOT NULL,
    `type_name_en` VARCHAR(100) NOT NULL,
    `type_name_th` VARCHAR(100) NOT NULL,
    `category` ENUM('MAIN', 'ACCESSORY', 'HARDWARE', 'LINING') NOT NULL DEFAULT 'MAIN',
    `display_order` INT NOT NULL DEFAULT 0,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_type_code` (`type_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Step 2: Seed generic types
INSERT INTO component_type_catalog (type_code, type_name_en, type_name_th, category, display_order) VALUES
('BODY', 'Body', 'ตัวกระเป๋า', 'MAIN', 1),
('FLAP', 'Flap', 'ฝาปิด', 'MAIN', 2),
('STRAP', 'Strap', 'สายสะพาย', 'ACCESSORY', 3),
('HANDLE', 'Handle', 'หูหิ้ว', 'ACCESSORY', 4),
('POCKET', 'Pocket', 'ช่องกระเป๋า', 'MAIN', 5),
('GUSSET', 'Gusset', 'ข้างกระเป๋า', 'MAIN', 6),
('LINING', 'Lining', 'ซับใน', 'LINING', 7),
('ZIPPER_PANEL', 'Zipper Panel', 'แผงซิป', 'ACCESSORY', 8);

-- Step 3: Migrate anchor_slot values (remove SLOT_ prefix)
UPDATE routing_node 
SET anchor_slot = REPLACE(anchor_slot, 'SLOT_', '')
WHERE anchor_slot LIKE 'SLOT_%';

UPDATE graph_component_mapping
SET anchor_slot = REPLACE(anchor_slot, 'SLOT_', '')
WHERE anchor_slot LIKE 'SLOT_%';

-- Step 5: Add FK after data cleanup
ALTER TABLE graph_component_mapping 
  MODIFY COLUMN anchor_slot VARCHAR(30) NOT NULL,
  ADD CONSTRAINT fk_gcm_component_type 
  FOREIGN KEY (anchor_slot) REFERENCES component_type_catalog(type_code)
  ON DELETE RESTRICT ON UPDATE CASCADE;

-- Step 8: Mark legacy table
ALTER TABLE component_catalog COMMENT = 'LEGACY: Do not use for new features. Use component_type_catalog + product_component instead.';
```

---

### Task 2: Service Layer (2 hr)

**Files:**
- `source/BGERP/Service/ComponentTypeService.php` (NEW - Layer 1)
- `source/BGERP/Service/ProductComponentService.php` (NEW - Layer 2)

**ComponentTypeService Methods:**
```php
// Layer 1 - Generic types for Graph
public function getAllTypes(): array
public function getTypeByCode(string $code): ?array
public function getActiveTypes(): array
```

**ProductComponentService Methods:**
```php
// Layer 2 - Physical components per product
public function getComponentsForProduct(int $productId): array
public function createComponent(int $productId, array $data): int
public function updateComponent(int $componentId, array $data): bool
public function deleteComponent(int $componentId): bool

// BOM
public function getMaterialsForComponent(int $componentId): array
public function addMaterial(int $componentId, string $materialSku, float $qty, ?string $uom = null): bool
public function updateMaterial(int $componentId, string $materialSku, float $qty): bool
public function removeMaterial(int $componentId, string $materialSku): bool

// Calculations
public function calculateTotalMaterials(int $productId): array
```

---

### Task 3: API Endpoints (1.5 hr)

**File:** `source/product_api.php` (extend existing)

| Action | Method | Permission | Description |
|--------|--------|------------|-------------|
| `get_components` | GET | `products.view` | Get product components |
| `add_component` | POST | `products.manage` | Add component to product |
| `update_component` | POST | `products.manage` | Update component |
| `delete_component` | POST | `products.manage` | Delete component |
| `get_component_materials` | GET | `products.view` | Get BOM for component |
| `add_component_material` | POST | `products.manage` | Add material to BOM |
| `update_component_material` | POST | `products.manage` | Update material qty |
| `remove_component_material` | POST | `products.manage` | Remove from BOM |
| `get_total_materials` | GET | `products.view` | Calculate total BOM |

**File:** `source/component_type_api.php` (rename from component_catalog_api.php)

| Action | Method | Permission | Description |
|--------|--------|------------|-------------|
| `list` | GET | `component.type.view` | List all types |
| `get` | GET | `component.type.view` | Get single type |

---

### Task 4: UI - Components Tab (3 hr)

**Files:**
- `views/products.php` (add Components tab)
- `assets/javascripts/products/products.js` (extend)
- `assets/javascripts/products/product_components.js` (NEW)

**Features:**
- [ ] Components Tab in Product Modal
- [ ] Component List with expand/collapse
- [ ] Add Component Modal
- [ ] Edit Component Modal
- [ ] Materials sub-form (inline)
- [ ] Add Material dropdown
- [ ] Total Materials Summary
- [ ] Validation before save

---

## 🔄 Migration from Current State

### Current State (Audited 2025-12-05)

| Table | Records | Status |
|-------|---------|--------|
| `component_catalog` | 35 | ⚠️ Mark as LEGACY |
| `graph_component_mapping` | 3 | ✏️ Migrate anchor_slot format |
| `product_component_mapping` | 0 | 🗑️ Can be dropped |
| `routing_node.anchor_slot` | 3 values | ✏️ Migrate format |

### What to Keep (as Legacy)
- `component_catalog` table → DO NOT DELETE, mark as legacy
  - **⚠️ NOT used by Material Architecture V2 anymore**
  - New features MUST use `component_type_catalog` + `product_component`
  - Future use: "Default Component Template" library (optional)

### What to Migrate
- `graph_component_mapping.anchor_slot`: `SLOT_BODY` → `BODY`
- `routing_node.anchor_slot`: `SLOT_BODY` → `BODY`
- `graph_component_mapping.component_code` → will break FK (OK, we're replacing this)

### What to Create (NEW)
- `component_type_catalog` table (Layer 1 - generic types)
- `product_component` table (Layer 2 - physical specs)
- `product_component_material` table (Layer 3 - BOM)
- Components Tab in Product Modal

### What to Drop (Safe)
- `product_component_mapping` (0 records, not used)
- FK from `graph_component_mapping` → `component_catalog` (will be replaced)

---

### `graph_component_mapping` Status (IMPORTANT!)

```
┌─────────────────────────────────────────────────────────────────────┐
│  graph_component_mapping = LEGACY for Material Architecture V2      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Current Use: Yes, but only for old POCs / demo graphs               │
│                                                                      │
│  For Material Architecture V2:                                       │
│  ❌ NOT used in new features (BOM, Costing, Reservation)            │
│  ❌ component_code column → obsolete (was FK to old component_catalog)│
│                                                                      │
│  What this table still does:                                         │
│  ✅ Provides anchor_slot list for a graph                           │
│  ✅ Used by UI "Component Mapping" tab in Product Modal              │
│     (for display/reference only, NOT for BOM calculation)            │
│                                                                      │
│  Future Decision (Task TBD):                                         │
│  • Option A: Keep as legacy reference, ignore component_code        │
│  • Option B: Migrate to product_component–based mapping              │
│  • Option C: Deprecate entirely, use product_component as source     │
│                                                                      │
│  For NOW: Safe to keep, but DO NOT use in new Material features!     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🌐 i18n Keys

```javascript
// Tab
t('product.components', 'Components')
t('product.components.add', 'Add Component')
t('product.components.edit', 'Edit Component')
t('product.components.delete.confirm', 'Delete this component?')

// Component Form
t('product.component.type', 'Component Type')
t('product.component.code', 'Component Code')
t('product.component.name', 'Component Name')
t('product.component.pattern_size', 'Pattern Size')
t('product.component.pattern_code', 'Pattern Code')
t('product.component.edge_width', 'Edge Width (mm)')
t('product.component.stitch_count', 'Stitch Count')
t('product.component.estimated_time', 'Estimated Time (min)')

// Materials
t('product.component.materials', 'Materials')
t('product.component.materials.add', 'Add Material')
t('product.component.materials.qty', 'Quantity')
t('product.component.materials.uom', 'Unit')
t('product.component.materials.primary', 'Primary')
t('product.component.materials.remove.confirm', 'Remove this material?')

// Summary
t('product.materials.total', 'Total Materials Summary')
t('product.materials.empty', 'No materials defined')

// Messages
t('product.component.save.success', 'Component saved successfully')
t('product.component.delete.success', 'Component deleted')
t('product.component.material.add.success', 'Material added')
t('product.component.material.remove.success', 'Material removed')
```

---

## ✅ Definition of Done

### Phase 1: Database (COMPLETE ✅)
- [x] `component_type_catalog` table created with seed data
- [x] `product_component` table created
- [x] `product_component_material` table created
- [x] Migration runs without error
- [x] anchor_slot migrated: SLOT_BODY → BODY
- [x] component_catalog marked as LEGACY
- [x] Collation matched (utf8mb4_unicode_ci)

### Phase 2: Service Layer (COMPLETE ✅)
- [x] ComponentTypeService working (`source/BGERP/Service/ComponentTypeService.php`)
- [x] ProductComponentService working (`source/BGERP/Service/ProductComponentService.php`)

### Phase 3: API (COMPLETE ✅)
- [x] API endpoints in `source/product_api.php`
- [x] Actions: component_types_list, product_components_list, product_component_get, product_component_create, product_component_update, product_component_delete

### Phase 4: UI (PENDING)
- [ ] Components Tab in Product Modal
- [ ] Add/Edit Component Modal
- [ ] Materials BOM form
- [ ] Total Materials calculation
- [ ] i18n applied
- [ ] No console errors

---

## 🚫 Out of Scope (This Task)

1. ❌ Material Reservation logic → Task 27.18
2. ❌ Material Deduction at CUT node → Task 27.18
3. ❌ Consumables (thread, glue) → **Never** (ไม่ track ในระบบ)
4. ❌ Material Variant at Product level → **Never** (สี/วัสดุเปลี่ยน = Product ใหม่)
5. ❌ Per-product material override → **Never** (ดูคำอธิบายด้านล่าง)
6. ❌ Component Mapping Tab changes → Separate task

---

### คำอธิบาย "Per-product material override = Never"

```
ในระบบ ERP บางตัว มี concept:
  • "Global Component BOM" = default สูตรวัสดุของ BODY ทั่วไป
  • "Per-product Override" = บาง product แก้สูตรจาก default

แต่ใน Bellavier Material Architecture V2:
  ❌ ไม่มี "Global Component BOM"
  ❌ ไม่มี "Default + Override" layer
  
  ✅ BOM เก็บที่ product_component โดยตรง
  ✅ ทุก Product มี component + BOM ของตัวเอง 100%
  
ดังนั้น "Per-product override" เป็นคำที่ไม่มีความหมายในระบบนี้
เพราะ "ทุก BOM = per-product อยู่แล้ว ตั้งแต่แรก"
```

---

## 📚 Related Documents

- `docs/super_dag/specs/MATERIAL_ARCHITECTURE_V2.md` - Full spec
- `docs/super_dag/tasks/task27.13_COMPONENT_NODE_PLAN.md` - Parent task
- `docs/super_dag/tasks/MASTER_IMPLEMENTATION_ROADMAP.md` - Roadmap
