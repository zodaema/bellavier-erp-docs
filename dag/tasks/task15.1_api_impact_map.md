# Task 15.1 — API Impact Map

**Date:** December 2025  
**Phase:** 15.1 — Discovery & Impact Map  
**Status:** ✅ COMPLETED

---

## Summary

This document identifies all PHP files that reference `work_center` or `unit_of_measure` tables. These files must be migrated from ID-based lookups to code-based lookups.

---

## PHP Files Referencing `work_center`

### 1. `source/work_centers.php`
- **File Type:** CRUD API Endpoint
- **Functions:**
  - `handleList()` - Lists work centers
  - `handleGet()` - Gets single work center by ID
  - `handleCreate()` - Creates work center
  - `handleUpdate()` - Updates work center
  - `handleDelete()` - Deletes work center
- **ID Usage:**
  - READ: `SELECT * FROM work_center WHERE id_work_center=?`
  - WRITE: `INSERT INTO work_center (code, name, ...) VALUES (...)`
  - JOIN: Used in queries joining with other tables
- **Classification:** READ / WRITE
- **Migration Required:** ✅ YES - Core work center management API

---

### 2. `source/hatthasilpa_job_ticket.php`
- **File Type:** Job Ticket API
- **Functions:**
  - `handleTaskList()` - Lists tasks with work center info
  - `handleTaskSave()` - Creates/updates task with `id_work_center`
  - `handleTaskCreateFromRouting()` - Creates tasks from routing with work center
  - `handleGetRoutingSteps()` - Gets routing steps with work center lookup
- **ID Usage:**
  - READ: `SELECT id_work_center, code, name FROM work_center`
  - WRITE: `INSERT INTO job_task (..., id_work_center, ...) VALUES (...)`
  - UPDATE: `UPDATE job_task SET id_work_center=? WHERE ...`
  - JOIN: `LEFT JOIN work_center wc ON wc.id_work_center = ...`
- **Classification:** READ / WRITE / JOIN
- **Migration Required:** ✅ YES - Core production workflow

---

### 3. `source/pwa_scan_api.php`
- **File Type:** PWA Scan API
- **Functions:**
  - `handleGetTokenDetails()` - Gets token with work center info
  - `handleGetWorkQueue()` - Lists work queue with work center
  - `handleGetTaskDetails()` - Gets task with work center
- **ID Usage:**
  - READ: `SELECT rn.id_work_center, ... FROM routing_node rn`
  - JOIN: `LEFT JOIN work_center wc ON wc.id_work_center = ajt_task.id_work_center`
  - Behavior lookup: `getByWorkCenterId((int)$row['id_work_center'])`
- **Classification:** READ / JOIN
- **Migration Required:** ✅ YES - PWA scan workflow

---

### 4. `source/dag_token_api.php`
- **File Type:** DAG Token API
- **Functions:**
  - `handleGetTokenDetails()` - Gets token with work center
  - `handleGetWorkQueue()` - Lists work queue with work center
  - `handleGetNodeDetails()` - Gets node with work center
- **ID Usage:**
  - READ: `SELECT rn.id_work_center, ... FROM routing_node rn`
  - Behavior lookup: `getByWorkCenterId((int)$token['id_work_center'])`
- **Classification:** READ
- **Migration Required:** ✅ YES - DAG token system

---

### 5. `source/routing.php`
- **File Type:** Legacy Routing V1 API
- **Functions:**
  - `handleGetWorkCenters()` - Lists work centers
  - `handleStepSave()` - Creates/updates routing step with `id_work_center`
- **ID Usage:**
  - READ: `SELECT id_work_center, code, name FROM work_center`
  - WRITE: `INSERT INTO routing_step (..., id_work_center, ...) VALUES (...)`
  - JOIN: `JOIN work_center wc ON wc.id_work_center = s.id_work_center`
- **Classification:** READ / WRITE / JOIN
- **Migration Required:** ⚠️ PARTIAL - Legacy V1 routing (may be deprecated)

---

### 6. `source/BGERP/Helper/LegacyRoutingAdapter.php`
- **File Type:** Helper Class
- **Functions:**
  - `getRoutingStepsForProduct()` - Gets routing steps with work center
- **ID Usage:**
  - READ: `SELECT rs.id_work_center, ... FROM routing_step rs`
  - JOIN: `LEFT JOIN work_center wc ON wc.id_work_center = rs.id_work_center`
- **Classification:** READ / JOIN
- **Migration Required:** ⚠️ PARTIAL - Legacy adapter (may be deprecated)

---

### 7. `source/BGERP/Dag/WorkCenterBehaviorRepository.php`
- **File Type:** Service Class
- **Functions:**
  - `getByWorkCenterId()` - Gets behavior by work center ID
- **ID Usage:**
  - READ: Uses `id_work_center` to lookup behavior mappings
- **Classification:** READ
- **Migration Required:** ✅ YES - Behavior mapping system

---

### 8. `source/dag_routing_api.php`
- **File Type:** DAG Routing API
- **Functions:**
  - Various functions that reference `routing_node.id_work_center`
- **ID Usage:**
  - READ: Queries routing nodes with work center
- **Classification:** READ
- **Migration Required:** ✅ YES - DAG routing system

---

## PHP Files Referencing `unit_of_measure`

### 1. `source/uom.php`
- **File Type:** CRUD API Endpoint
- **Functions:**
  - `handleList()` - Lists UOMs
  - `handleGet()` - Gets single UOM by ID
  - `handleCreate()` - Creates UOM
  - `handleUpdate()` - Updates UOM
  - `handleDelete()` - Deletes UOM
- **ID Usage:**
  - READ: `SELECT * FROM unit_of_measure WHERE id_unit=?`
  - WRITE: `INSERT INTO unit_of_measure (code, name, ...) VALUES (...)`
- **Classification:** READ / WRITE
- **Migration Required:** ✅ YES - Core UOM management API

---

### 2. `source/products.php`
- **File Type:** Product API
- **Functions:**
  - `handleCreate()` - Creates product with `default_uom`
  - `handleUpdate()` - Updates product with `default_uom`
  - `handleGetUomList()` - Lists UOMs for dropdown
- **ID Usage:**
  - READ: `SELECT id_unit, code, name FROM unit_of_measure`
  - WRITE: `INSERT INTO product (..., default_uom, ...) VALUES (...)`
  - UPDATE: `UPDATE product SET default_uom=? WHERE ...`
  - JOIN: `LEFT JOIN unit_of_measure u ON u.id_unit = p.default_uom`
- **Classification:** READ / WRITE / JOIN
- **Migration Required:** ✅ YES - Product master data

---

### 3. `source/mo.php`
- **File Type:** Manufacturing Order API
- **Functions:**
  - `handleCreate()` - Creates MO with `id_uom`
  - `handleGet()` - Gets MO with UOM info
  - `handleProductUom()` - Gets product UOM
- **ID Usage:**
  - READ: `SELECT m.id_uom, ... FROM mo m`
  - WRITE: `INSERT INTO mo (..., id_uom, ...) VALUES (...)`
  - JOIN: `LEFT JOIN unit_of_measure u ON u.id_unit = m.id_uom`
- **Classification:** READ / WRITE / JOIN
- **Migration Required:** ✅ YES - Manufacturing orders

---

### 4. `source/bom.php`
- **File Type:** BOM API
- **Functions:**
  - `handleGetUomList()` - Lists UOMs for dropdown
  - `handleLineSave()` - Creates/updates BOM line with `id_uom`
  - `handleLineList()` - Lists BOM lines with UOM info
- **ID Usage:**
  - READ: `SELECT id_unit, code, name FROM unit_of_measure`
  - WRITE: `INSERT INTO bom_line (..., id_uom, ...) VALUES (...)`
  - JOIN: `LEFT JOIN unit_of_measure u1 ON u1.id_unit = bl.id_uom`
- **Classification:** READ / WRITE / JOIN
- **Migration Required:** ✅ YES - BOM system

---

### 5. `source/BGERP/Service/BOMService.php`
- **File Type:** Service Class
- **Functions:**
  - `addMaterialLine()` - Adds BOM line with `id_uom`
  - `addAssemblyLine()` - Adds assembly line with `id_uom`
  - `getBOMTree()` - Gets BOM tree with UOM info
- **ID Usage:**
  - READ: `LEFT JOIN unit_of_measure u1 ON u1.id_unit = bl.id_uom`
  - WRITE: `INSERT INTO bom_line (..., id_uom, ...) VALUES (...)`
- **Classification:** READ / WRITE / JOIN
- **Migration Required:** ✅ YES - BOM service layer

---

### 6. `source/materials.php`
- **File Type:** Materials API
- **Functions:**
  - `handleList()` - Lists materials with UOM
  - `handleCreate()` - Creates material with `default_uom`
  - `handleUpdate()` - Updates material with `default_uom`
  - `handleLotList()` - Lists material lots with UOM
  - `handleLotSave()` - Creates material lot with `id_uom`
- **ID Usage:**
  - READ: `LEFT JOIN unit_of_measure u ON u.id_unit = si.id_uom`
  - WRITE: `INSERT INTO stock_item (..., id_uom, ...) VALUES (...)`
  - WRITE: `INSERT INTO material_lot (..., id_uom, ...) VALUES (...)`
  - UPDATE: `UPDATE stock_item SET id_uom=? WHERE ...`
- **Classification:** READ / WRITE / JOIN
- **Migration Required:** ✅ YES - Material master data

---

### 7. `source/leather_grn.php`
- **File Type:** Leather GRN API
- **Functions:**
  - `handleCreate()` - Creates GRN with UOM from material
  - `handleLotSave()` - Creates material lot with `id_uom`
- **ID Usage:**
  - READ: `SELECT m.default_uom AS id_uom FROM material m`
  - WRITE: `INSERT INTO material_lot (..., id_uom, ...) VALUES (...)`
  - WRITE: `INSERT INTO stock_ledger (..., id_uom, ...) VALUES (...)`
- **Classification:** READ / WRITE
- **Migration Required:** ✅ YES - GRN workflow

---

### 8. `source/stock_card.php`, `stock_on_hand.php`, `adjust.php`, `issue.php`, `transfer.php`, `grn.php`
- **File Type:** Inventory Transaction APIs
- **Functions:**
  - Various inventory operations that reference UOM
- **ID Usage:**
  - READ: Queries stock items with UOM
  - WRITE: Creates ledger entries with `id_uom`
- **Classification:** READ / WRITE
- **Migration Required:** ✅ YES - Inventory system

---

## Summary Statistics

### Work Center References
- **Total PHP Files:** 8
- **CRUD Endpoints:** 1 (`work_centers.php`)
- **Production APIs:** 3 (`hatthasilpa_job_ticket.php`, `pwa_scan_api.php`, `dag_token_api.php`)
- **Routing APIs:** 2 (`routing.php`, `dag_routing_api.php`)
- **Helper/Service Classes:** 2 (`LegacyRoutingAdapter.php`, `WorkCenterBehaviorRepository.php`)
- **All Require Migration:** ✅ YES

### Unit of Measure References
- **Total PHP Files:** 8+
- **CRUD Endpoints:** 1 (`uom.php`)
- **Master Data APIs:** 3 (`products.php`, `materials.php`, `mo.php`)
- **BOM APIs:** 2 (`bom.php`, `BOMService.php`)
- **Inventory APIs:** 6+ (`leather_grn.php`, `stock_card.php`, etc.)
- **All Require Migration:** ✅ YES

### Combined Total
- **Total PHP Files Affected:** 16+
- **All Require Migration:** ✅ YES
- **High-Risk Hotspots:**
  1. `hatthasilpa_job_ticket.php` - Core production workflow
  2. `products.php` - Product master data
  3. `mo.php` - Manufacturing orders
  4. `bom.php` / `BOMService.php` - BOM system
  5. `materials.php` - Material master data

---

## Migration Priority Recommendations

### Phase 2 Priority Order (Add `*_code` columns):

1. **High Priority (Core APIs):**
   - `work_centers.php` - Work center CRUD
   - `uom.php` - UOM CRUD
   - `hatthasilpa_job_ticket.php` - Job ticket workflow
   - `products.php` - Product master data
   - `mo.php` - Manufacturing orders

2. **Medium Priority (Supporting APIs):**
   - `bom.php` / `BOMService.php` - BOM system
   - `materials.php` - Material master data
   - `pwa_scan_api.php` - PWA scan workflow
   - `dag_token_api.php` - DAG token system

3. **Low Priority (Legacy/Supporting):**
   - `routing.php` - Legacy V1 routing
   - `LegacyRoutingAdapter.php` - Legacy adapter
   - `dag_routing_api.php` - DAG routing
   - `WorkCenterBehaviorRepository.php` - Behavior mapping
   - Inventory transaction APIs

---

## Notes

- All APIs use prepared statements (safe for migration)
- Most APIs already have `code` columns in responses (good foundation)
- Legacy V1 routing (`routing.php`) may be deprecated in future
- Service classes (`BOMService.php`, `WorkCenterBehaviorRepository.php`) need migration for consistency

---

**Last Updated:** December 2025

