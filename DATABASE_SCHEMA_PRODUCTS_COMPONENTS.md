# Database Schema: Products & Components System

**Last Updated:** 2025-12-25  
**Version:** 2.0 (Component Architecture V2)

---

## Overview

ระบบ Products & Components ใช้ **3-Layer Architecture**:

1. **Layer 1 (Abstract):** `component_type_catalog` - ประเภท component แบบ generic (BODY, FLAP, STRAP, etc.)
2. **Layer 2 (Physical):** `product_component` - Component specs เฉพาะ product + BOM (`product_component_material`)
3. **Layer 3 (Graph Binding):** `graph_component_mapping` - Map component ไปยัง Graph anchor slots

---

## Core Tables

### 1. `product` - Product Master

```sql
CREATE TABLE `product` (
  `id_product` int(11) NOT NULL AUTO_INCREMENT,
  `sku` varchar(100) NOT NULL COMMENT 'Product SKU (unique)',
  `name` varchar(200) NOT NULL COMMENT 'Product name',
  `description` text DEFAULT NULL COMMENT 'Product description',
  `id_category` int(11) DEFAULT NULL COMMENT 'FK to product_category',
  `production_line` varchar(32) NOT NULL DEFAULT 'classic' COMMENT 'Single production line: classic or hatthasilpa',
  `default_uom` int(11) DEFAULT NULL COMMENT 'FK to unit_of_measure',
  `default_uom_code` varchar(30) DEFAULT NULL COMMENT 'Default UOM code (seed-driven)',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `is_draft` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Draft flag',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_product`),
  UNIQUE KEY `uniq_sku` (`sku`),
  KEY `fk_prod_cat` (`id_category`),
  KEY `fk_prod_uom` (`default_uom`),
  KEY `idx_production_line` (`production_line`),
  KEY `idx_product_uom_code` (`default_uom_code`),
  CONSTRAINT `fk_prod_cat` FOREIGN KEY (`id_category`) REFERENCES `product_category` (`id_category`) ON DELETE SET NULL,
  CONSTRAINT `fk_prod_uom` FOREIGN KEY (`default_uom`) REFERENCES `unit_of_measure` (`id_unit`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Key Fields:**
- `production_line`: `'classic'` หรือ `'hatthasilpa'` (single value, not array)
- `is_draft`: Draft flag สำหรับ products ที่ยังไม่พร้อมใช้งาน

---

### 2. `component_type_catalog` - Layer 1 (Abstract Component Types)

```sql
CREATE TABLE `component_type_catalog` (
  `id_component_type` INT AUTO_INCREMENT PRIMARY KEY,
  
  -- Identity
  `type_code` VARCHAR(30) NOT NULL COMMENT 'Generic code: BODY, FLAP, STRAP (UPPERCASE only)',
  `type_name_en` VARCHAR(100) NOT NULL COMMENT 'English name',
  `type_name_th` VARCHAR(100) NOT NULL COMMENT 'Thai name',
  
  -- Classification
  `category` ENUM('MAIN', 'ACCESSORY', 'INTERIOR', 'REINFORCEMENT', 'DECORATIVE') NOT NULL DEFAULT 'MAIN',
  `display_order` INT NOT NULL DEFAULT 0,
  `description` VARCHAR(255) NULL COMMENT 'Description of this component type',
  
  -- Status
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Constraints
  UNIQUE KEY `uk_type_code` (`type_code`),
  INDEX `idx_category` (`category`),
  INDEX `idx_display_order` (`display_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Layer 1: Abstract component types (24 types: BODY, FLAP, STRAP, etc.)';
```

**Seed Data:** 24 types ใน 5 categories:
- **MAIN:** BODY, FLAP, POCKET, GUSSET, BASE, DIVIDER, FRAME, PANEL
- **ACCESSORY:** STRAP, HANDLE, ZIPPER_PANEL, ZIP_POCKET, LOOP, TONGUE, CLOSURE_TAB
- **INTERIOR:** LINING, INTERIOR_PANEL, CARD_SLOT_PANEL
- **REINFORCEMENT:** REINFORCEMENT, PADDING, BACKING
- **DECORATIVE:** LOGO_PATCH, DECOR_PANEL, BADGE

---

### 3. `product_component` - Layer 2 (Physical Component Specs)

```sql
CREATE TABLE `product_component` (
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
  INDEX `idx_product_type` (`id_product`, `component_type_code`),
  
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

**Key Points:**
- `component_code`: Unique ภายใน product (format: `{TYPE_CODE}_{PRODUCT_ID}_{TIMESTAMP}`)
- `component_type_code`: Reference ไปยัง `component_type_catalog.type_code`
- Owns BOM ผ่าน `product_component_material`

---

### 4. `product_component_material` - Layer 3 (BOM per Component)

```sql
CREATE TABLE `product_component_material` (
  `id_pcm` INT AUTO_INCREMENT PRIMARY KEY,
  
  -- Ownership
  `id_product_component` INT NOT NULL COMMENT 'FK to product_component',
  
  -- Material Reference
  `material_sku` VARCHAR(100) NOT NULL COMMENT 'FK to material.sku',
  
  -- Quantity
  `qty_required` DECIMAL(10,4) NOT NULL DEFAULT 1.0000 COMMENT 'Quantity required per component',
  `uom_code` VARCHAR(20) NULL COMMENT 'Unit of measure (null = inherit from material.default_uom_code)',
  
  -- BOM Priority
  `is_primary` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Primary material for this component',
  `priority` INT NOT NULL DEFAULT 1 COMMENT 'Priority order if multiple materials',
  
  -- Notes
  `notes` TEXT NULL,
  
  -- Metadata
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Constraints
  UNIQUE KEY `uk_component_material` (`id_product_component`, `material_sku`),
  INDEX `idx_component` (`id_product_component`),
  INDEX `idx_material` (`material_sku`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Layer 3: BOM per component (material requirements)';
```

**Key Points:**
- `material_sku`: Reference ไปยัง `material.sku` (not FK constraint - material อาจอยู่ใน core DB)
- `is_primary`: Primary material สำหรับ component นี้
- `uom_code`: ถ้า NULL จะ inherit จาก `material.default_uom_code`

---

## Graph Binding Tables

### 5. `product_graph_binding` - Product → Graph Binding

```sql
CREATE TABLE `product_graph_binding` (
  `id_binding` INT AUTO_INCREMENT PRIMARY KEY,
  `id_product` INT NOT NULL COMMENT 'FK to product.id_product',
  `id_graph` INT NOT NULL COMMENT 'FK to routing_graph.id_graph',
  
  -- Pattern & BOM References (Optional)
  `id_pattern` INT NULL COMMENT 'FK to pattern.id_pattern',
  `id_pattern_version` INT NULL COMMENT 'FK to pattern_version.id_version',
  `id_bom_template` INT NULL COMMENT 'FK to bom.id_bom',
  
  -- Binding Metadata
  `binding_label` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'Human-readable label (e.g., "Tote A / Pattern V2 / DAG: Diagonal_V2")',
  
  -- Version Pinning (Phase 1: graph_version_id is PRIMARY)
  `graph_version_id` INT NULL COMMENT 'FK to routing_graph_version.id_version (NULL = use published_current pointer)',
  `graph_version_pin` VARCHAR(50) NULL COMMENT 'Legacy: version string pin (deprecated, use graph_version_id)',
  
  -- Production Mode
  `default_mode` ENUM('hatthasilpa','classic','hybrid') DEFAULT 'hatthasilpa' COMMENT 'Default production mode for this binding',
  
  -- Status & Lifecycle
  `is_active` TINYINT(1) DEFAULT 1 COMMENT 'Is this binding currently active',
  `effective_from` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'When this binding became effective',
  `effective_until` DATETIME NULL COMMENT 'When this binding expires (NULL = indefinite)',
  `priority` INT DEFAULT 0 COMMENT 'Priority if multiple active bindings (higher = preferred)',
  
  -- Metadata
  `notes` TEXT NULL COMMENT 'Admin notes about this binding',
  `source` ENUM('manual','migration','api','system') DEFAULT 'manual' COMMENT 'Source of binding creation',
  `created_by` INT NULL COMMENT 'User who created this binding',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_by` INT NULL COMMENT 'User who last updated',
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Constraints
  PRIMARY KEY (`id_binding`),
  UNIQUE KEY `uniq_product_graph_active` (`id_product`, `id_graph`, `is_active`, `effective_from`),
  KEY `idx_product` (`id_product`),
  KEY `idx_graph` (`id_graph`),
  KEY `idx_version_id` (`graph_version_id`),
  KEY `idx_active` (`is_active`, `effective_from`, `effective_until`),
  KEY `idx_mode` (`default_mode`),
  KEY `idx_priority` (`priority`),
  KEY `idx_product_mode_active` (`id_product`, `default_mode`, `is_active`),
  
  -- Foreign Keys
  CONSTRAINT `fk_binding_product` FOREIGN KEY (`id_product`) REFERENCES `product` (`id_product`) ON DELETE CASCADE,
  CONSTRAINT `fk_binding_graph` FOREIGN KEY (`id_graph`) REFERENCES `routing_graph` (`id_graph`) ON DELETE CASCADE,
  CONSTRAINT `fk_binding_version` FOREIGN KEY (`graph_version_id`) REFERENCES `routing_graph_version` (`id_version`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Product → Graph binding with version pinning';
```

**Key Points:**
- `graph_version_id`: **PRIMARY** สำหรับ version pinning (Phase 1)
- `graph_version_pin`: Legacy field (deprecated, ใช้ `graph_version_id` แทน)
- `is_active`: Active binding flag

---

### 6. `graph_component_mapping` - Graph Anchor Slot → Component Mapping (V2)

```sql
CREATE TABLE `graph_component_mapping` (
  `id_mapping` INT(11) NOT NULL AUTO_INCREMENT,
  
  -- Graph & Slot
  `id_graph` INT(11) NOT NULL COMMENT 'FK to routing_graph.id_graph',
  `anchor_slot` VARCHAR(50) NOT NULL COMMENT 'Anchor slot from routing_node (where node_type=component)',
  
  -- Product Scope (V2 - Added Dec 2025)
  `id_product` INT NULL COMMENT 'FK to product (scope mapping per product)',
  
  -- Component Reference (V2 - Product-scoped)
  `component_code` VARCHAR(50) NOT NULL COMMENT 'Legacy: component_type_catalog.type_code or component_catalog.component_code',
  `id_product_component` INT NULL COMMENT 'FK to product_component (Layer 2)',
  
  -- Metadata
  `notes` TEXT NULL COMMENT 'Optional notes about this mapping',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_by` INT(11) NULL COMMENT 'FK to account.id_member',
  
  -- Constraints
  PRIMARY KEY (`id_mapping`),
  UNIQUE KEY `uk_product_graph_slot` (`id_product`, `id_graph`, `anchor_slot`),
  KEY `idx_graph` (`id_graph`),
  KEY `idx_component` (`component_code`),
  KEY `idx_anchor` (`anchor_slot`),
  KEY `idx_mapping_product` (`id_product`),
  KEY `idx_mapping_product_component` (`id_product_component`),
  
  -- Foreign Keys
  CONSTRAINT `fk_mapping_graph` 
      FOREIGN KEY (`id_graph`) REFERENCES `routing_graph` (`id_graph`)
      ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Maps graph anchor slots to components (V2: Product-scoped)';
```

**Key Points:**
- **V2 Changes (Dec 2025):**
  - เพิ่ม `id_product`: Scope mapping per product
  - เพิ่ม `id_product_component`: Reference ไปยัง `product_component` (Layer 2)
  - Unique constraint: `(id_product, id_graph, anchor_slot)`
- `anchor_slot`: มาจาก `routing_node.anchor_slot` (where `node_type='component'`)

---

## Product Config Tables (Phase 1)

### 7. `product_config_component_slot` - Product Config Slot Specs (Phase 1)

```sql
CREATE TABLE `product_config_component_slot` (
  `id_spec` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Primary key',
  `id_product` int(11) NOT NULL COMMENT 'FK to product.id_product',
  `anchor_slot` varchar(50) NOT NULL COMMENT 'Component slot identifier from Graph (routing_node.anchor_slot where node_type=component)',
  
  -- Phase 1 Fields Only (Intent/Constraints)
  `quantity_per_product` int(11) NOT NULL DEFAULT 1 COMMENT 'Quantity of this component per product',
  `is_required` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'Is this component slot required (1=required, 0=optional)',
  `dimensions` json DEFAULT NULL COMMENT 'Component dimensions: {"width": decimal, "length": decimal, "height": decimal, "unit": "cm"|"mm"|"inch"}',
  `target_thickness` decimal(5,2) DEFAULT NULL COMMENT 'Target thickness in millimeters (mm) - unit is always mm, independent of dimensions.unit',
  `material_specification` varchar(100) DEFAULT NULL COMMENT 'Material specification intent (material code or specification text)',
  `lining_required` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Is lining required for this component (1=yes, 0=no)',
  `material_sheet_size_constraint` varchar(100) DEFAULT NULL COMMENT 'Material sheet size constraint (e.g., "max_width:120cm")',
  `special_attributes` json DEFAULT NULL COMMENT 'Special attributes/notes as JSON object',
  
  -- Metadata
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_by` int(11) DEFAULT NULL COMMENT 'User who created this spec (account.id_member)',
  
  -- Constraints
  PRIMARY KEY (`id_spec`),
  UNIQUE KEY `uk_product_anchor_slot` (`id_product`, `anchor_slot`) COMMENT 'Prevent duplicate specs for same product+slot',
  KEY `idx_product` (`id_product`) COMMENT 'Fast product lookups',
  KEY `idx_anchor_slot` (`anchor_slot`) COMMENT 'Fast slot lookups',
  CONSTRAINT `fk_product_config_product` FOREIGN KEY (`id_product`) REFERENCES `product` (`id_product`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Phase 1: Product Config Component Slot Specifications (Intent/Constraints only)';
```

**Key Points:**
- **Graph SSOT:** `anchor_slot` มาจาก Graph (`routing_node.anchor_slot`) เท่านั้น
- **Intent Only:** เก็บ constraints/intent เท่านั้น ไม่เก็บ workflow/process
- `target_thickness`: Unit = mm เสมอ (ไม่ผูกกับ `dimensions.unit`)
- `material_specification`: Intent only (ไม่ duplicate BOM)

---

## Audit & Logging Tables

### 8. `product_config_log` - Product Config Audit Trail

```sql
CREATE TABLE `product_config_log` (
  `id_log` INT AUTO_INCREMENT PRIMARY KEY,
  `id_product` INT NOT NULL COMMENT 'FK to product',
  
  -- What changed
  `config_type` ENUM(
    'graph_binding',
    'component_mapping',
    'product_component',
    'component_material',
    'production_line'
  ) NOT NULL COMMENT 'Type of configuration changed',
  
  `action` ENUM('create', 'update', 'delete') NOT NULL COMMENT 'Action performed',
  
  -- Details
  `old_value` JSON NULL COMMENT 'Previous value (for update/delete)',
  `new_value` JSON NULL COMMENT 'New value (for create/update)',
  
  -- Who & When
  `changed_by` INT NOT NULL COMMENT 'FK to account.id_member',
  `changed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  -- Context
  `ip_address` VARCHAR(45) NULL COMMENT 'Client IP address',
  `user_agent` VARCHAR(255) NULL COMMENT 'Browser user agent',
  
  INDEX `idx_product` (`id_product`),
  INDEX `idx_changed_at` (`changed_at`),
  INDEX `idx_config_type` (`config_type`),
  INDEX `idx_changed_by` (`changed_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Audit log for product configuration changes (Task 27.19)';
```

---

## Related Graph Tables

### 9. `routing_node` - Graph Nodes (Component Slots)

```sql
-- Relevant columns for Component System:
`id_node` INT PRIMARY KEY,
`id_graph` INT NOT NULL,
`node_type` ENUM('...', 'component', 'router', ...) NOT NULL,
`anchor_slot` VARCHAR(50) NULL COMMENT 'Component slot identifier (when node_type=component)',
`expected_component_type` VARCHAR(30) NULL COMMENT 'Expected component type (Layer 1) - Designer selects manually',
...
```

**Key Points:**
- `node_type='component'`: Component nodes ที่มี `anchor_slot`
- `anchor_slot`: Component slot identifier (UPPER_SNAKE_CASE)
- `expected_component_type`: Expected `component_type_catalog.type_code`

---

## Relationships Diagram

```
product
  ├── product_component (1:N)
  │     └── product_component_material (1:N) → material.sku
  │
  ├── product_graph_binding (1:1) → routing_graph
  │     └── graph_version_id → routing_graph_version
  │
  ├── graph_component_mapping (1:N) → routing_graph + anchor_slot
  │     └── id_product_component → product_component
  │
  └── product_config_component_slot (1:N) → anchor_slot (from Graph)

component_type_catalog (Layer 1)
  └── product_component.component_type_code (1:N)

routing_graph
  ├── routing_node (1:N)
  │     └── anchor_slot (when node_type='component')
  │
  └── graph_component_mapping (1:N)
        └── anchor_slot → product_component
```

---

## Migration History

| Migration File | Date | Changes |
|----------------|------|---------|
| `0001_init_tenant_schema_v2.php` | 2025-12 | Initial schema: product, component_type_catalog, product_component, product_component_material, graph_component_mapping |
| `2025_12_component_mapping_refactor.php` | 2025-12-06 | V2: Add id_product, id_product_component to graph_component_mapping |
| `2025_12_product_binding_version_id.php` | 2025-12-14 | Add graph_version_id to product_graph_binding (Phase 1) |
| `2025_12_product_config_component_slot.php` | 2025-12-25 | Create product_config_component_slot table (Phase 1) |
| `2025_12_product_readiness.php` | 2025-12-06 | Create product_config_log table (Task 27.19) |

---

## Key Design Decisions

### 1. 3-Layer Architecture
- **Layer 1 (Abstract):** Generic component types (reusable across products)
- **Layer 2 (Physical):** Product-specific component specs + BOM
- **Layer 3 (Graph Binding):** Map components to Graph anchor slots

### 2. Graph SSOT (Single Source of Truth)
- Component slots (`anchor_slot`) มาจาก Graph (`routing_node`) เท่านั้น
- Product Config ไม่สามารถ invent slots เองได้

### 3. Version Pinning (Phase 1)
- `graph_version_id` (INT) = PRIMARY สำหรับ version pinning
- `graph_version_pin` (VARCHAR) = Legacy (deprecated)

### 4. Product-Scoped Mapping (V2)
- `graph_component_mapping` เพิ่ม `id_product` เพื่อ scope mapping per product
- Support multiple products ใช้ graph เดียวกัน แต่ map components ต่างกัน

---

## Common Queries

### Get all components for a product
```sql
SELECT 
  pc.*,
  ctc.type_name_en,
  ctc.category
FROM product_component pc
JOIN component_type_catalog ctc ON ctc.type_code = pc.component_type_code
WHERE pc.id_product = ?
ORDER BY ctc.display_order, pc.component_code;
```

### Get BOM for a component
```sql
SELECT 
  pcm.*,
  m.name_en AS material_name
FROM product_component_material pcm
LEFT JOIN material m ON m.sku = pcm.material_sku
WHERE pcm.id_product_component = ?
ORDER BY pcm.is_primary DESC, pcm.priority;
```

### Get component mapping for a product+graph
```sql
SELECT 
  gcm.*,
  pc.component_name,
  pc.component_type_code
FROM graph_component_mapping gcm
LEFT JOIN product_component pc ON pc.id_product_component = gcm.id_product_component
WHERE gcm.id_product = ? AND gcm.id_graph = ?
ORDER BY gcm.anchor_slot;
```

### Get Product Config slots for a product
```sql
SELECT 
  pccs.*,
  rn.node_name AS slot_name
FROM product_config_component_slot pccs
JOIN product_graph_binding pgb ON pgb.id_product = pccs.id_product AND pgb.is_active = 1
JOIN routing_node rn ON rn.id_graph = pgb.id_graph 
  AND rn.anchor_slot = pccs.anchor_slot 
  AND rn.node_type = 'component'
WHERE pccs.id_product = ?;
```

---

## Notes

- **Material Reference:** `product_component_material.material_sku` reference ไปยัง `material.sku` (อาจอยู่ใน core DB หรือ tenant DB)
- **Soft Delete:** ไม่มี soft delete สำหรับ product/component tables (ใช้ `is_active` flag สำหรับ product)
- **Audit Trail:** ใช้ `product_config_log` สำหรับ audit product configuration changes

---

**Related Documentation:**
- `docs/super_dag/specs/MATERIAL_ARCHITECTURE_V2.md` - Component Architecture V2
- `docs/super_dag/06-specs/PHASE_1_IMPLEMENTATION_PLAN.md` - Phase 1 Implementation
- `docs/super_dag/06-specs/PHASE_1_PREIMPLEMENTATION_AUDIT.md` - Pre-Implementation Audit

