# Material Pipeline Schema Raw Dump

**Generated:** December 2025  
**Purpose:** Complete schema extraction for Material Pipeline (GRN → Material → Leather Sheet → CUT → BOM → DAG)  
**Task:** Task 13.15 — Schema Mapping & Material Pipeline Blueprint

---

## Overview

This document contains the raw schema dump for all tables related to the Material Pipeline:
- Material Master Data (`material`, `stock_item`)
- GRN & Lot Management (`material_lot`)
- Leather Sheet Inventory (`leather_sheet`)
- BOM Structure (`bom`, `bom_line`)
- CUT Operations (`leather_cut_bom_log`, `leather_sheet_usage_log`, `cut_batch`)
- Component Allocation (`component_serial_allocation`)
- DAG Integration (`flow_token`, `job_graph_instance`, `job_ticket`)

---

## 1. Material Master Data Tables

### 1.1 `material`

**Purpose:** Master material catalog (legacy table)

```sql
CREATE TABLE `material` (
  `id_material` int(11) NOT NULL AUTO_INCREMENT,
  `sku` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `default_uom` int(11) DEFAULT NULL,
  `category` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_material`),
  UNIQUE KEY `uniq_material_sku` (`sku`),
  KEY `fk_material_uom` (`default_uom`),
  CONSTRAINT `fk_material_uom` FOREIGN KEY (`default_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Key Fields:**
- `sku`: Material SKU (unique identifier)
- `name`: Material name
- `category`: Material category (e.g., 'Leather', 'Textile', 'Hardware')
- `is_active`: Active flag

**Foreign Keys:**
- `default_uom` → `unit_of_measure(id_unit)`

---

### 1.2 `stock_item`

**Purpose:** Stock item master (newer table, used for inventory)

```sql
CREATE TABLE `stock_item` (
  `id_stock_item` bigint(20) NOT NULL AUTO_INCREMENT,
  `sku` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `material_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'e.g., leather, textile, hardware',
  `id_uom` int(11) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_stock_item`),
  UNIQUE KEY `uniq_stock_item_sku` (`sku`),
  KEY `idx_stock_item_uom` (`id_uom`),
  CONSTRAINT `fk_stock_item_uom` FOREIGN KEY (`id_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4_unicode_ci;
```

**Key Fields:**
- `sku`: Stock item SKU (unique identifier)
- `name`: Stock item name
- `material_type`: Material type (e.g., 'leather', 'textile', 'hardware')
- `is_active`: Active flag

**Foreign Keys:**
- `id_uom` → `unit_of_measure(id_unit)`

**Note:** This table is the **preferred source** for material SKU in newer flows (GRN, Leather Sheet).

---

## 2. GRN & Lot Management Tables

### 2.1 `material_lot`

**Purpose:** Material lot/batch tracking (GRN header)

```sql
CREATE TABLE `material_lot` (
  `id_material_lot` int(11) NOT NULL AUTO_INCREMENT,
  `id_stock_item` bigint(20) NOT NULL,
  `lot_code` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `supplier_name` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `supplier_reference` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `received_at` datetime DEFAULT NULL,
  `quantity` decimal(18,6) NOT NULL DEFAULT '0.000000',
  `id_uom` int(11) NOT NULL,
  `area_sqft` decimal(18,6) DEFAULT NULL,
  `weight_kg` decimal(18,6) DEFAULT NULL,
  `thickness_avg` decimal(10,3) DEFAULT NULL,
  `grade` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'available',
  `location_code` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `is_leather_grn` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Flag indicating this lot was created via Leather GRN flow',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_material_lot`),
  UNIQUE KEY `uniq_lot_per_material` (`id_stock_item`,`lot_code`),
  KEY `idx_material_lot_sku` (`id_stock_item`),
  KEY `fk_material_lot_uom` (`id_uom`),
  KEY `idx_material_lot_sku_leather_grn` (`id_stock_item`, `is_leather_grn`),
  CONSTRAINT `fk_material_lot_item` FOREIGN KEY (`id_stock_item`) 
    REFERENCES `stock_item` (`id_stock_item`) ON DELETE CASCADE,
  CONSTRAINT `fk_material_lot_uom` FOREIGN KEY (`id_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Key Fields:**
- `id_stock_item`: FK to `stock_item` (material reference)
- `lot_code`: Lot/batch code (unique per stock_item)
- `is_leather_grn`: Flag for Leather GRN flow (Task 13.10)
- `area_sqft`: Area in square feet (for leather)
- `grade`: Quality grade (e.g., 'A', 'B', 'C', 'D')

**Foreign Keys:**
- `id_stock_item` → `stock_item(id_stock_item)`
- `id_uom` → `unit_of_measure(id_unit)`

**Indexes:**
- `uniq_lot_per_material`: Unique lot per material
- `idx_material_lot_sku_leather_grn`: Composite index for Leather GRN queries

---

## 3. Leather Sheet Inventory Tables

### 3.1 `leather_sheet`

**Purpose:** Physical leather sheet inventory (Task 13.8)

```sql
CREATE TABLE `leather_sheet` (
  `id_sheet` INT PRIMARY KEY AUTO_INCREMENT,
  `sku_material` VARCHAR(64) NOT NULL COMMENT 'Material SKU reference',
  `batch_code` VARCHAR(64) NULL COMMENT 'Lot/batch number',
  `sheet_code` VARCHAR(64) NOT NULL UNIQUE COMMENT 'Unique sheet label/code',
  `area_sqft` DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Total area in square feet',
  `area_remaining_sqft` DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Remaining area available',
  `status` ENUM('active', 'depleted', 'archived') NOT NULL DEFAULT 'active' COMMENT 'Sheet status',
  `id_lot` INT NULL COMMENT 'FK to material_lot.id_material_lot (GRN lot this sheet belongs to)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX idx_sku_material (sku_material),
  INDEX idx_batch_code (batch_code),
  INDEX idx_sheet_code (sheet_code),
  INDEX idx_status (status),
  INDEX idx_area_remaining (area_remaining_sqft),
  INDEX idx_leather_sheet_lot_sku_status (sku_material, id_lot, status),
  
  CONSTRAINT fk_leather_sheet_material FOREIGN KEY (sku_material) 
    REFERENCES material(sku) ON DELETE RESTRICT,
  CONSTRAINT fk_leather_sheet_lot FOREIGN KEY (id_lot) 
    REFERENCES material_lot(id_material_lot) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Leather sheet inventory for physical traceability';
```

**Key Fields:**
- `sku_material`: FK to `material(sku)` (legacy FK)
- `id_lot`: FK to `material_lot` (GRN lot, Task 13.10)
- `sheet_code`: Unique sheet identifier
- `area_sqft`: Total area
- `area_remaining_sqft`: Remaining area
- `status`: Sheet status

**Foreign Keys:**
- `sku_material` → `material(sku)` (legacy FK)
- `id_lot` → `material_lot(id_material_lot)` (GRN lot)

**Note:** 
- **GAP:** `sku_material` references `material(sku)` but should reference `stock_item(sku)` for consistency
- **GAP:** Dual FK structure (legacy `material` + new `material_lot`) creates confusion

---

### 3.2 `leather_sheet_usage_log`

**Purpose:** Track leather sheet usage per DAG token (Task 13.12)

```sql
CREATE TABLE `leather_sheet_usage_log` (
  `id_usage` INT PRIMARY KEY AUTO_INCREMENT,
  `id_sheet` INT NOT NULL COMMENT 'FK to leather_sheet.id_sheet',
  `token_id` INT NOT NULL COMMENT 'FK to flow_token.id_token (DAG token that used this sheet)',
  `used_area` DECIMAL(8,2) NOT NULL COMMENT 'Area used in sq.ft',
  `used_by` INT NOT NULL COMMENT 'FK to account.id_member (worker who used the sheet)',
  `note` TEXT NULL COMMENT 'Optional note about usage',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX idx_sheet_token (id_sheet, token_id),
  INDEX idx_token (token_id),
  INDEX idx_sheet (id_sheet),
  INDEX idx_used_by (used_by),
  INDEX idx_created_at (created_at),
  
  CONSTRAINT fk_usage_sheet FOREIGN KEY (id_sheet)
    REFERENCES leather_sheet(id_sheet) ON DELETE RESTRICT,
  CONSTRAINT fk_usage_token FOREIGN KEY (token_id)
    REFERENCES flow_token(id_token) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tracks leather sheet usage per DAG token for traceability';
```

**Key Fields:**
- `id_sheet`: FK to `leather_sheet`
- `token_id`: FK to `flow_token` (DAG token)
- `used_area`: Area used in square feet
- `used_by`: Worker who used the sheet

**Foreign Keys:**
- `id_sheet` → `leather_sheet(id_sheet)`
- `token_id` → `flow_token(id_token)`

---

## 4. BOM Structure Tables

### 4.1 `bom`

**Purpose:** Bill of Materials header

```sql
CREATE TABLE `bom` (
  `id_bom` int(11) NOT NULL AUTO_INCREMENT,
  `id_product` int(11) NOT NULL,
  `version` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `remarks` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_bom`),
  UNIQUE KEY `uniq_product_version` (`id_product`,`version`),
  KEY `idx_bom_product` (`id_product`),
  CONSTRAINT `fk_bom_product` FOREIGN KEY (`id_product`) 
    REFERENCES `product` (`id_product`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4_unicode_ci;
```

**Key Fields:**
- `id_product`: FK to `product`
- `version`: BOM version
- `is_active`: Active flag

**Foreign Keys:**
- `id_product` → `product(id_product)`

---

### 4.2 `bom_line`

**Purpose:** BOM line items (materials/components)

```sql
CREATE TABLE `bom_line` (
  `id_bom_line` int(11) NOT NULL AUTO_INCREMENT,
  `id_bom` int(11) NOT NULL,
  `material_sku` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `id_child_product` int(11) DEFAULT NULL COMMENT 'If set, this line is a sub-assembly',
  `qty` decimal(18,6) NOT NULL,
  `id_uom` int(11) DEFAULT NULL,
  `waste_pct` decimal(10,4) NOT NULL DEFAULT '0.0000',
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_bom_line`),
  KEY `idx_bom_line_bom` (`id_bom`),
  KEY `idx_bom_line_uom` (`id_uom`),
  CONSTRAINT `fk_bom_line_bom` FOREIGN KEY (`id_bom`) 
    REFERENCES `bom` (`id_bom`) ON DELETE CASCADE,
  CONSTRAINT `fk_bom_line_uom` FOREIGN KEY (`id_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4_unicode_ci;
```

**Key Fields:**
- `id_bom`: FK to `bom`
- `material_sku`: Material SKU (string, no FK constraint)
- `id_child_product`: FK to `product` (if sub-assembly)
- `qty`: Quantity per unit
- `waste_pct`: Waste percentage

**Foreign Keys:**
- `id_bom` → `bom(id_bom)`
- `id_uom` → `unit_of_measure(id_unit)`
- `id_child_product` → `product(id_product)` (if set)

**Note:**
- **GAP:** `material_sku` is a string without FK constraint (should reference `stock_item(sku)` or `material(sku)`)
- **GAP:** No direct link to `stock_item` or `material` table

---

## 5. CUT Operations Tables

### 5.1 `leather_cut_bom_log`

**Purpose:** Track CUT results per BOM line (Task 13.14)

```sql
CREATE TABLE `leather_cut_bom_log` (
  `id_log` INT PRIMARY KEY AUTO_INCREMENT,
  `token_id` INT NOT NULL COMMENT 'FK to flow_token.id_token',
  `bom_line_id` INT NOT NULL COMMENT 'FK to bom_line.id_bom_line',
  `qty_plan` DECIMAL(18,6) NOT NULL COMMENT 'Planned quantity from BOM',
  `qty_actual` DECIMAL(18,6) NOT NULL COMMENT 'Actual quantity cut (user input)',
  `qty_scrap` DECIMAL(18,6) NOT NULL DEFAULT 0.000000 COMMENT 'Quantity scrapped (from overcut classification)',
  `qty_extra_good` DECIMAL(18,6) NOT NULL DEFAULT 0.000000 COMMENT 'Extra good pieces (from overcut classification)',
  `area_per_piece` DECIMAL(10,4) NOT NULL DEFAULT 0.0000 COMMENT 'Area per piece in cm² (from BOM or calculated)',
  `area_planned` DECIMAL(12,4) NOT NULL DEFAULT 0.0000 COMMENT 'Planned area = qty_plan * area_per_piece',
  `area_used` DECIMAL(12,4) NOT NULL DEFAULT 0.0000 COMMENT 'Used area = qty_actual * area_per_piece',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
  `created_by` INT NULL COMMENT 'FK to account.id_member',
  
  INDEX idx_token (token_id),
  INDEX idx_bom_line (bom_line_id),
  INDEX idx_token_bom_line (token_id, bom_line_id),
  INDEX idx_created_at (created_at),
  
  CONSTRAINT fk_cut_bom_log_token FOREIGN KEY (token_id)
    REFERENCES flow_token(id_token) ON DELETE CASCADE,
  CONSTRAINT fk_cut_bom_log_bom_line FOREIGN KEY (bom_line_id)
    REFERENCES bom_line(id_bom_line) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tracks CUT results per BOM line for leather materials';
```

**Key Fields:**
- `token_id`: FK to `flow_token` (DAG token)
- `bom_line_id`: FK to `bom_line`
- `qty_plan`: Planned quantity from BOM
- `qty_actual`: Actual quantity cut
- `qty_scrap`: Scrapped quantity
- `qty_extra_good`: Extra good pieces
- `area_per_piece`: Area per piece in cm²
- `area_planned`: Planned area
- `area_used`: Used area

**Foreign Keys:**
- `token_id` → `flow_token(id_token)`
- `bom_line_id` → `bom_line(id_bom_line)`

---

### 5.2 `cut_batch`

**Purpose:** CUT batch records linking tokens to leather sheets (Task 13.8)

```sql
CREATE TABLE `cut_batch` (
  `id_cut_batch` INT PRIMARY KEY AUTO_INCREMENT,
  `token_id` INT NOT NULL COMMENT 'FK to flow_token.id_token (token that triggered CUT)',
  `sheet_id` INT NOT NULL COMMENT 'FK to leather_sheet.id_sheet',
  `total_components` INT NOT NULL DEFAULT 0 COMMENT 'Number of components cut in this batch',
  `cut_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When cut was performed',
  `created_by` INT NOT NULL COMMENT 'FK to member.id_member (user who performed cut)',
  
  INDEX idx_token_id (token_id),
  INDEX idx_sheet_id (sheet_id),
  INDEX idx_cut_at (cut_at),
  INDEX idx_created_by (created_by),
  
  CONSTRAINT fk_cut_batch_token FOREIGN KEY (token_id) 
    REFERENCES flow_token(id_token) ON DELETE RESTRICT,
  CONSTRAINT fk_cut_batch_sheet FOREIGN KEY (sheet_id) 
    REFERENCES leather_sheet(id_sheet) ON DELETE RESTRICT,
  CONSTRAINT fk_cut_batch_created_by FOREIGN KEY (created_by) 
    REFERENCES member(id_member) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='CUT batch records linking tokens to leather sheets';
```

**Key Fields:**
- `token_id`: FK to `flow_token`
- `sheet_id`: FK to `leather_sheet`
- `total_components`: Number of components cut
- `cut_at`: Cut timestamp
- `created_by`: Worker who performed cut

**Foreign Keys:**
- `token_id` → `flow_token(id_token)`
- `sheet_id` → `leather_sheet(id_sheet)`
- `created_by` → `member(id_member)`

---

## 6. Component Allocation Tables

### 6.1 `component_serial_allocation`

**Purpose:** Component serial allocation to leather sheets and cut batches (Task 13.8)

```sql
CREATE TABLE `component_serial_allocation` (
  `id_alloc` INT PRIMARY KEY AUTO_INCREMENT,
  `serial_id` INT NOT NULL COMMENT 'FK to component_serial.id_component_serial',
  `sheet_id` INT NOT NULL COMMENT 'FK to leather_sheet.id_sheet',
  `cut_batch_id` INT NULL COMMENT 'FK to cut_batch.id_cut_batch (optional, set when batch is created)',
  `area_used_sqft` DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Area consumed by this component',
  `allocated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When allocation was created',
  
  UNIQUE KEY uniq_serial_allocation (serial_id) COMMENT 'One allocation per serial',
  INDEX idx_serial_id (serial_id),
  INDEX idx_sheet_id (sheet_id),
  INDEX idx_cut_batch_id (cut_batch_id),
  INDEX idx_allocated_at (allocated_at),
  
  CONSTRAINT fk_alloc_serial FOREIGN KEY (serial_id) 
    REFERENCES component_serial(id_component_serial) ON DELETE RESTRICT,
  CONSTRAINT fk_alloc_sheet FOREIGN KEY (sheet_id) 
    REFERENCES leather_sheet(id_sheet) ON DELETE RESTRICT,
  CONSTRAINT fk_alloc_cut_batch FOREIGN KEY (cut_batch_id) 
    REFERENCES cut_batch(id_cut_batch) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Component serial allocation to leather sheets and cut batches';
```

**Key Fields:**
- `serial_id`: FK to `component_serial`
- `sheet_id`: FK to `leather_sheet`
- `cut_batch_id`: FK to `cut_batch` (optional)
- `area_used_sqft`: Area consumed

**Foreign Keys:**
- `serial_id` → `component_serial(id_component_serial)`
- `sheet_id` → `leather_sheet(id_sheet)`
- `cut_batch_id` → `cut_batch(id_cut_batch)`

---

## 7. DAG Integration Tables (Summary)

### 7.1 `flow_token`

**Purpose:** DAG token (work unit)

**Key Fields:**
- `id_token`: Primary key
- `id_instance`: FK to `job_graph_instance`
- `status`: Token status

**Relationship:**
- Links to `leather_sheet_usage_log(token_id)`
- Links to `leather_cut_bom_log(token_id)`
- Links to `cut_batch(token_id)`

---

### 7.2 `job_graph_instance`

**Purpose:** Graph instance (job execution)

**Key Fields:**
- `id_instance`: Primary key
- `id_job_ticket`: FK to `job_ticket`
- `id_graph`: FK to `routing_graph`

---

### 7.3 `job_ticket`

**Purpose:** Job ticket (work order)

**Key Fields:**
- `id_job_ticket`: Primary key
- `id_product`: FK to `product`
- `id_mo`: FK to `mo` (Manufacturing Order)

**Relationship:**
- Links to `bom` via `product`
- Links to `job_graph_instance` via `id_job_ticket`

---

## 8. Summary of Foreign Key Relationships

### Material Master Data
- `material.sku` ← `leather_sheet.sku_material` (legacy FK)
- `stock_item.sku` ← `material_lot.id_stock_item` → `stock_item.id_stock_item`
- `stock_item.sku` ← `bom_line.material_sku` (string, no FK constraint)

### GRN & Lot
- `material_lot.id_stock_item` → `stock_item.id_stock_item`
- `material_lot.id_material_lot` ← `leather_sheet.id_lot`

### Leather Sheet
- `leather_sheet.sku_material` → `material.sku` (legacy)
- `leather_sheet.id_lot` → `material_lot.id_material_lot` (GRN lot)
- `leather_sheet.id_sheet` ← `leather_sheet_usage_log.id_sheet`
- `leather_sheet.id_sheet` ← `cut_batch.sheet_id`
- `leather_sheet.id_sheet` ← `component_serial_allocation.sheet_id`

### BOM
- `bom.id_product` → `product.id_product`
- `bom_line.id_bom` → `bom.id_bom`
- `bom_line.material_sku` → `stock_item.sku` (string, no FK)
- `bom_line.id_bom_line` ← `leather_cut_bom_log.bom_line_id`

### CUT Operations
- `leather_cut_bom_log.token_id` → `flow_token.id_token`
- `leather_cut_bom_log.bom_line_id` → `bom_line.id_bom_line`
- `cut_batch.token_id` → `flow_token.id_token`
- `cut_batch.sheet_id` → `leather_sheet.id_sheet`
- `leather_sheet_usage_log.token_id` → `flow_token.id_token`

### DAG Integration
- `flow_token.id_instance` → `job_graph_instance.id_instance`
- `job_graph_instance.id_job_ticket` → `job_ticket.id_job_ticket`
- `job_ticket.id_product` → `product.id_product`
- `bom.id_product` → `product.id_product`

---

## 9. Index Summary

### Material Master
- `material.uniq_material_sku`: Unique SKU
- `stock_item.uniq_stock_item_sku`: Unique SKU

### GRN & Lot
- `material_lot.uniq_lot_per_material`: Unique lot per material
- `material_lot.idx_material_lot_sku_leather_grn`: Composite index for Leather GRN

### Leather Sheet
- `leather_sheet.idx_sku_material`: Material SKU lookup
- `leather_sheet.idx_sheet_code`: Unique sheet code
- `leather_sheet.idx_leather_sheet_lot_sku_status`: Composite index for queries

### BOM
- `bom.uniq_product_version`: Unique BOM per product version
- `bom_line.idx_bom_line_bom`: BOM lookup

### CUT Operations
- `leather_cut_bom_log.idx_token_bom_line`: Composite index for token+BOM line
- `cut_batch.idx_token_id`: Token lookup
- `leather_sheet_usage_log.idx_sheet_token`: Composite index for sheet+token

---

## 10. Notes & Observations

1. **Dual Material Master:** Both `material` and `stock_item` exist with overlapping purposes
2. **FK Mismatch:** `leather_sheet.sku_material` references `material(sku)` but should reference `stock_item(sku)`
3. **String FK:** `bom_line.material_sku` is a string without FK constraint
4. **Legacy + New:** `leather_sheet` has both legacy FK (`sku_material` → `material`) and new FK (`id_lot` → `material_lot`)
5. **No Direct Link:** `bom_line` has no direct FK to `stock_item` or `material` (only string `material_sku`)

---

**End of Schema Dump**

