# Task 15.1 — Database Impact Map

**Date:** December 2025  
**Phase:** 15.1 — Discovery & Impact Map  
**Status:** ✅ COMPLETED

---

## Summary

This document identifies all database tables that reference `work_center` or `unit_of_measure` tables. These tables contain `is_system` and `locked` flags and must become **fully seed-driven** instead of ID-driven.

---

## Tables Referencing `work_center`

### 1. `job_task`
- **FK Column:** `id_work_center` (INT, NULL)
- **Schema Definition:**
  ```sql
  `id_work_center` int(11) DEFAULT NULL,
  KEY `fk_job_task_work_center` (`id_work_center`),
  CONSTRAINT `fk_job_task_work_center` FOREIGN KEY (`id_work_center`) 
    REFERENCES `work_center` (`id_work_center`) ON DELETE SET NULL
  ```
- **Is System-Critical?** ✅ YES - Core production table
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Links job tasks to work centers for routing and assignment

---

### 2. `job_ticket`
- **FK Column:** `id_work_center` (INT, NULL)
- **Schema Definition:**
  ```sql
  `id_work_center` int(11) DEFAULT NULL COMMENT 'จัดให้ work center ไหน (future use)',
  KEY `fk_job_ticket_work_center` (`id_work_center`),
  CONSTRAINT `fk_job_ticket_work_center` FOREIGN KEY (`id_work_center`) 
    REFERENCES `work_center` (`id_work_center`) ON DELETE SET NULL
  ```
- **Is System-Critical?** ✅ YES - Core production table
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Future use for work center assignment at ticket level

---

### 3. `routing_node`
- **FK Column:** `id_work_center` (INT, NULL)
- **Schema Definition:**
  ```sql
  `id_work_center` int(11) DEFAULT NULL COMMENT 'Work center if operation type',
  KEY `idx_work_center` (`id_work_center`),
  CONSTRAINT `routing_node_ibfk_2` FOREIGN KEY (`id_work_center`) 
    REFERENCES `work_center` (`id_work_center`) ON DELETE SET NULL
  ```
- **Is System-Critical?** ✅ YES - DAG routing system
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Links DAG nodes to work centers for operation execution

---

### 4. `routing_step` (Legacy V1)
- **FK Column:** `id_work_center` (INT, NOT NULL)
- **Schema Definition:**
  ```sql
  `id_work_center` int(11) NOT NULL,
  KEY `idx_routing_step_wc` (`id_work_center`),
  CONSTRAINT `fk_routing_step_wc` FOREIGN KEY (`id_work_center`) 
    REFERENCES `work_center` (`id_work_center`)
  ```
- **Is System-Critical?** ⚠️ PARTIAL - Legacy V1 routing (deprecated but still used)
- **Requires `*_code` Migration?** ✅ YES (if still in use)
- **Usage:** Legacy routing system (V1) - may be deprecated

---

### 5. `work_center_team_map`
- **FK Column:** `id_work_center` (INT, NOT NULL)
- **Schema Definition:**
  ```sql
  `id_work_center` int(11) NOT NULL COMMENT 'Work center ID',
  PRIMARY KEY (`id_work_center`,`id_team`),
  KEY `idx_work_center` (`id_work_center`),
  CONSTRAINT `work_center_team_map_ibfk_1` FOREIGN KEY (`id_work_center`) 
    REFERENCES `work_center` (`id_work_center`) ON DELETE CASCADE
  ```
- **Is System-Critical?** ✅ YES - Team assignment system
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Maps work centers to teams for assignment filtering

---

### 6. `work_center_behavior_map`
- **FK Column:** `id_work_center` (INT, NOT NULL)
- **Schema Definition:**
  ```sql
  id_work_center INT NOT NULL COMMENT 'FK to work_center.id_work_center',
  PRIMARY KEY (id_work_center, id_behavior),
  FOREIGN KEY (id_work_center) REFERENCES work_center(id_work_center) ON DELETE CASCADE
  ```
- **Is System-Critical?** ✅ YES - Behavior mapping system
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Maps work centers to behaviors (CUT, STITCH, EDGE, QC, etc.)

---

## Tables Referencing `unit_of_measure`

### 1. `bom_line`
- **FK Column:** `id_uom` (INT, NULL)
- **Schema Definition:**
  ```sql
  `id_uom` int(11) DEFAULT NULL,
  KEY `idx_bom_line_uom` (`id_uom`),
  CONSTRAINT `fk_bom_line_uom` FOREIGN KEY (`id_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`) ON DELETE SET NULL
  ```
- **Is System-Critical?** ✅ YES - BOM system
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Unit of measure for BOM line items

---

### 2. `product`
- **FK Column:** `default_uom` (INT, NULL)
- **Schema Definition:**
  ```sql
  `default_uom` int(11) DEFAULT NULL,
  KEY `fk_prod_uom` (`default_uom`),
  CONSTRAINT `fk_prod_uom` FOREIGN KEY (`default_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`) ON DELETE SET NULL
  ```
- **Is System-Critical?** ✅ YES - Product master data
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Default unit of measure for products

---

### 3. `mo` (Manufacturing Order)
- **FK Column:** `id_uom` (INT, NOT NULL)
- **Schema Definition:**
  ```sql
  `id_uom` int(11) NOT NULL,
  KEY `idx_mo_uom` (`id_uom`),
  CONSTRAINT `fk_mo_uom` FOREIGN KEY (`id_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`)
  ```
- **Is System-Critical?** ✅ YES - Manufacturing orders
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Unit of measure for MO quantities

---

### 4. `material`
- **FK Column:** `default_uom` (INT, NULL)
- **Schema Definition:**
  ```sql
  `default_uom` int(11) DEFAULT NULL,
  KEY `fk_material_uom` (`default_uom`),
  CONSTRAINT `fk_material_uom` FOREIGN KEY (`default_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`) ON DELETE SET NULL
  ```
- **Is System-Critical?** ✅ YES - Material master data
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Default unit of measure for materials

---

### 5. `material_lot`
- **FK Column:** `id_uom` (INT, NOT NULL)
- **Schema Definition:**
  ```sql
  `id_uom` int(11) NOT NULL,
  KEY `fk_material_lot_uom` (`id_uom`),
  CONSTRAINT `fk_material_lot_uom` FOREIGN KEY (`id_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`)
  ```
- **Is System-Critical?** ✅ YES - Material lot tracking
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Unit of measure for material lot quantities

---

### 6. `stock_item`
- **FK Column:** `id_uom` (INT, NOT NULL)
- **Schema Definition:**
  ```sql
  `id_uom` int(11) NOT NULL,
  KEY `fk_stock_uom` (`id_uom`),
  CONSTRAINT `fk_stock_uom` FOREIGN KEY (`id_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`)
  ```
- **Is System-Critical?** ✅ YES - Stock inventory system
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Unit of measure for stock items

---

### 7. `stock_ledger`
- **FK Column:** `id_uom` (INT, NOT NULL)
- **Schema Definition:**
  ```sql
  `id_uom` int(11) NOT NULL,
  KEY `fk_ledger_uom` (`id_uom`),
  CONSTRAINT `fk_ledger_uom` FOREIGN KEY (`id_uom`) 
    REFERENCES `unit_of_measure` (`id_unit`)
  ```
- **Is System-Critical?** ✅ YES - Stock ledger transactions
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Unit of measure for ledger transactions

---

### 8. `purchase_rfq_item` (Legacy)
- **FK Column:** `id_uom` (INT, NULL)
- **Schema Definition:**
  ```sql
  `id_uom` int(11) DEFAULT NULL,
  KEY `idx_rfq_item_rfq` (`id_rfq`)
  ```
- **Is System-Critical?** ⚠️ PARTIAL - Purchase RFQ system
- **Requires `*_code` Migration?** ✅ YES
- **Usage:** Unit of measure for RFQ items

---

## Summary Statistics

### Work Center References
- **Total Tables:** 6
- **System-Critical:** 5
- **Legacy/Partial:** 1 (`routing_step` - V1 legacy)
- **All Require Migration:** ✅ YES

### Unit of Measure References
- **Total Tables:** 8
- **System-Critical:** 7
- **Legacy/Partial:** 1 (`purchase_rfq_item`)
- **All Require Migration:** ✅ YES

### Combined Total
- **Total Tables Affected:** 14
- **All Require `*_code` Migration:** ✅ YES
- **High-Risk Hotspots:**
  1. `job_task` - Core production workflow
  2. `routing_node` - DAG routing system
  3. `product` - Product master data
  4. `mo` - Manufacturing orders
  5. `material` / `stock_item` - Inventory system

---

## Migration Priority Recommendations

### Phase 2 Priority Order (Add `*_code` columns):

1. **High Priority (Core Production):**
   - `job_task` (work_center_code)
   - `routing_node` (work_center_code)
   - `product` (default_uom_code)
   - `mo` (uom_code)

2. **Medium Priority (Master Data):**
   - `material` (default_uom_code)
   - `stock_item` (uom_code)
   - `bom_line` (uom_code)

3. **Low Priority (Supporting Systems):**
   - `work_center_team_map` (work_center_code)
   - `work_center_behavior_map` (work_center_code)
   - `stock_ledger` (uom_code)
   - `material_lot` (uom_code)
   - `job_ticket` (work_center_code - future use)
   - `routing_step` (work_center_code - legacy V1)
   - `purchase_rfq_item` (uom_code)

---

## Notes

- All foreign key constraints use `ON DELETE SET NULL` or `ON DELETE CASCADE` - safe for migration
- `routing_step` is legacy V1 routing - may be deprecated in future
- `job_ticket.id_work_center` is marked as "future use" - currently NULL in most cases
- All tables have unique constraints on `code` columns in master tables (`work_center.code`, `unit_of_measure.code`)

---

**Last Updated:** December 2025

