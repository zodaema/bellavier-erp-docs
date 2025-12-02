# Task 15.1 — JavaScript Impact Map

**Date:** December 2025  
**Phase:** 15.1 — Discovery & Impact Map  
**Status:** ✅ COMPLETED

---

## Summary

This document identifies all JavaScript files that pass IDs to API endpoints, use IDs in DOM/UI, or use IDs in binding/selection for `work_center` or `unit_of_measure` tables.

---

## JavaScript Files Using `work_center` IDs

### 1. `assets/javascripts/work_centers/work_centers.js`
- **File Path:** `assets/javascripts/work_centers/work_centers.js`
- **Functions:**
  - `buildTable()` - Displays `id_work_center` in DataTable
  - `handleEdit()` - Gets work center by `id_work_center`
  - `handleSave()` - Sends `id_work_center` in update payload
  - `handleDelete()` - Sends `id_work_center` in delete payload
- **API Endpoint:** `source/work_centers.php`
- **Payload Structure:**
  ```javascript
  // GET detail
  { action: 'detail', id_work_center: id }
  
  // UPDATE
  { action: 'update', id_work_center: payload.id, code, name, ... }
  
  // DELETE
  { action: 'delete', id_work_center: id }
  ```
- **DOM Usage:**
  - DataTable column: `{ data: 'id_work_center', title: 'ID' }`
  - Button data attributes: `data-id="${row.id_work_center}"`
  - Form field: `$('#wc_id').val(data.id_work_center)`
- **Migration Need:** ✅ YES - Core work center management

---

### 2. `assets/javascripts/work_centers/work_centers_behavior.js`
- **File Path:** `assets/javascripts/work_centers/work_centers_behavior.js`
- **Functions:**
  - `bindBehavior()` - Binds behavior to work center by ID
  - `unbindBehavior()` - Unbinds behavior from work center by ID
- **API Endpoint:** `source/work_centers.php`
- **Payload Structure:**
  ```javascript
  // BIND
  { action: 'bind_behavior', id_work_center: idWorkCenter, id_behavior: idBehavior }
  
  // UNBIND
  { action: 'unbind_behavior', id_work_center: idWorkCenter, id_behavior: idBehavior }
  ```
- **DOM Usage:**
  - Row lookup: `r.id_work_center == idWorkCenter`
- **Migration Need:** ✅ YES - Behavior mapping UI

---

### 3. `assets/javascripts/hatthasilpa/job_ticket.js`
- **File Path:** `assets/javascripts/hatthasilpa/job_ticket.js`
- **Functions:**
  - `loadWorkCenters()` - Loads work centers for dropdown
  - `handleTaskSave()` - Saves task with `id_work_center`
  - `handleTaskEdit()` - Loads task with work center
- **API Endpoint:** `source/hatthasilpa_job_ticket.php`
- **Payload Structure:**
  ```javascript
  // SAVE TASK
  { action: 'task_save', id_work_center: $(selectors.taskWorkCenter).val(), ... }
  
  // GET TASK
  { action: 'task_get', id_job_task: id }
  // Response includes: { id_work_center: ... }
  ```
- **DOM Usage:**
  - Dropdown options: `<option value="${wc.id_work_center}">${wc.code} - ${wc.name}</option>`
  - Form field: `$('#task_work_center').val(resp.data.id_work_center)`
  - DataTable column: `{ data: 'id_work_center', ... }`
- **Migration Need:** ✅ YES - Job ticket workflow

---

### 4. `assets/javascripts/dag/graph_designer.js`
- **File Path:** `assets/javascripts/dag/graph_designer.js`
- **Functions:**
  - `saveNode()` - Saves node with `workCenterId`
  - `loadWorkCenters()` - Loads work centers for dropdown
  - `renderNodeForm()` - Renders node form with work center selection
- **API Endpoint:** `source/dag_routing_api.php`
- **Payload Structure:**
  ```javascript
  // SAVE NODE
  { id_work_center: node.data('workCenterId') || null, ... }
  
  // LOAD WORK CENTERS
  // Response: [{ id_work_center, code, name }, ...]
  ```
- **DOM Usage:**
  - Dropdown options: `<option value="${wc.id_work_center}" ${selected}>${wc.code} - ${wc.name}</option>`
  - Node data attribute: `node.data('workCenterId', wc.id_work_center)`
- **Migration Need:** ✅ YES - DAG graph designer

---

### 5. `assets/javascripts/dag/modules/GraphSaver.js`
- **File Path:** `assets/javascripts/dag/modules/GraphSaver.js`
- **Functions:**
  - `saveGraph()` - Saves graph with node `id_work_center`
- **API Endpoint:** `source/dag_routing_api.php`
- **Payload Structure:**
  ```javascript
  { nodes: [{ id_work_center: node.data('workCenterId') || null, ... }] }
  ```
- **Migration Need:** ✅ YES - Graph saving module

---

### 6. `assets/javascripts/routing/routing.js`
- **File Path:** `assets/javascripts/routing/routing.js`
- **Functions:**
  - `loadWorkCenters()` - Loads work centers for dropdown
  - `handleStepSave()` - Saves routing step with `id_work_center`
  - `handleStepEdit()` - Loads step with work center
- **API Endpoint:** `source/routing.php` (Legacy V1)
- **Payload Structure:**
  ```javascript
  // SAVE STEP
  { action, id_step, id_work_center: $('#rs_wc').val(), ... }
  
  // UPDATE STEP
  { action: 'update_step', id_step, id_work_center: $('#ers_wc').val(), ... }
  ```
- **DOM Usage:**
  - Dropdown options: `<option value="${w.id_work_center}">${w.code} - ${w.name}</option>`
  - Form field: `$('#rs_wc').val(String(r.data.id_work_center))`
- **Migration Need:** ⚠️ PARTIAL - Legacy V1 routing (may be deprecated)

---

### 7. `assets/javascripts/pwa_scan/work_queue.js`
- **File Path:** `assets/javascripts/pwa_scan/work_queue.js`
- **Functions:**
  - `loadWorkQueue()` - Loads work queue with `work_center_id`
  - `handleTokenAction()` - Sends token actions with `work_center_id`
- **API Endpoint:** `source/pwa_scan_api.php`
- **Payload Structure:**
  ```javascript
  // TOKEN ACTION
  { work_center_id: token.work_center_id || null, ... }
  ```
- **DOM Usage:**
  - Token data: `token.work_center_id`
- **Migration Need:** ✅ YES - PWA work queue

---

### 8. `assets/javascripts/pwa_scan/pwa_scan.js`
- **File Path:** `assets/javascripts/pwa_scan/pwa_scan.js`
- **Functions:**
  - `handleTokenAction()` - Sends actions with `work_center_id`
- **API Endpoint:** `source/pwa_scan_api.php`
- **Payload Structure:**
  ```javascript
  { work_center_id: currentNode.id_work_center || null, ... }
  ```
- **Migration Need:** ✅ YES - PWA scan workflow

---

### 9. `assets/javascripts/dag/behavior_execution.js`
- **File Path:** `assets/javascripts/dag/behavior_execution.js`
- **Functions:**
  - `executeBehavior()` - Sends behavior execution with `work_center_id`
- **API Endpoint:** `source/dag_behavior_exec.php`
- **Payload Structure:**
  ```javascript
  { work_center_id: baseContext.work_center_id || null, ... }
  ```
- **Migration Need:** ✅ YES - Behavior execution

---

### 10. `assets/javascripts/products/product_graph_binding.js`
- **File Path:** `assets/javascripts/products/product_graph_binding.js`
- **Functions:**
  - `renderNodeDetails()` - Displays node with `id_work_center`
- **DOM Usage:**
  - Display: `WC: ${node.id_work_center}`
- **Migration Need:** ✅ YES - Product graph binding UI

---

## JavaScript Files Using `unit_of_measure` IDs

### 1. `assets/javascripts/uom/uom.js`
- **File Path:** `assets/javascripts/uom/uom.js`
- **Functions:**
  - `handleSave()` - Saves UOM with `id_unit`
  - `handleEdit()` - Loads UOM by `id_unit`
  - `handleDelete()` - Deletes UOM by `id_unit`
- **API Endpoint:** `source/uom.php`
- **Payload Structure:**
  ```javascript
  // UPDATE
  { action: 'update', id_unit: id, code, name, description }
  
  // DELETE
  { action: 'delete', id_unit: id }
  ```
- **DOM Usage:**
  - Form field: `$('#uom_id').val($(this).data('id'))`
  - Button data attributes: `data-id="${r.id_unit}"`
  - DataTable column: `{ data: 'id_unit', name: 'id_unit' }`
- **Migration Need:** ✅ YES - Core UOM management

---

### 2. `assets/javascripts/products/products.js`
- **File Path:** `assets/javascripts/products/products.js`
- **Functions:**
  - `loadOptions()` - Loads UOM options for dropdown
  - `handleSave()` - Saves product with `default_uom`
  - `handleEdit()` - Loads product with UOM
- **API Endpoint:** `source/products.php`
- **Payload Structure:**
  ```javascript
  // SAVE PRODUCT
  { default_uom: $('#modal_default_uom').val(), ... }
  ```
- **DOM Usage:**
  - Dropdown options: `<option value="${u.id_unit}">${u.code} - ${u.name}</option>`
  - Form field: `$('#modal_default_uom').val(uomId)`
  - UOM lookup: `data.default_uom || data.id_uom || data.uom_id`
- **Migration Need:** ✅ YES - Product master data

---

### 3. `assets/javascripts/mo/mo.js`
- **File Path:** `assets/javascripts/mo/mo.js`
- **Functions:**
  - `loadProductUom()` - Loads product UOM
  - `handleSave()` - Saves MO with `id_uom`
  - `handleEdit()` - Loads MO with UOM
- **API Endpoint:** `source/mo.php`
- **Payload Structure:**
  ```javascript
  // SAVE MO
  { id_uom: $('#mo_uom').val(), ... }
  ```
- **DOM Usage:**
  - Form field: `$('#mo_uom').val(resp.id_uom || '')`
- **Migration Need:** ✅ YES - Manufacturing orders

---

### 4. `assets/javascripts/bom/bom.js`
- **File Path:** `assets/javascripts/bom/bom.js`
- **Functions:**
  - `handleLineSave()` - Saves BOM line with `id_uom`
  - `handleAssemblySave()` - Saves assembly line with `id_uom`
- **API Endpoint:** `source/bom.php`
- **Payload Structure:**
  ```javascript
  // ADD LINE
  { action: 'add_line', id_bom, material_sku, qty, id_uom, waste_pct }
  
  // ADD ASSEMBLY
  { action: 'add_assembly', id_bom, id_child_product, qty, id_uom }
  
  // UPDATE LINE
  { action: 'update_line', id_bom_line, material_sku, qty, id_uom: '', waste_pct }
  ```
- **DOM Usage:**
  - Form field: `$('#bl_uom').val()`
  - Form field: `$('#bl_assembly_uom').val()`
- **Migration Need:** ✅ YES - BOM system

---

### 5. `assets/javascripts/materials/materials.js`
- **File Path:** `assets/javascripts/materials/materials.js`
- **Functions:**
  - `handleMaterialSave()` - Saves material with `id_uom`
  - `handleLotSave()` - Saves material lot with `id_uom`
  - `handleMaterialEdit()` - Loads material with UOM
- **API Endpoint:** `source/materials.php`
- **Payload Structure:**
  ```javascript
  // SAVE MATERIAL
  { id_uom, ... }
  
  // SAVE LOT
  { id_uom: $('#lot_uom').val(), ... }
  ```
- **DOM Usage:**
  - Form field: `$('#mat_uom').val(String(r.data.id_uom || ''))`
  - Form field: `$('#lot_uom').val()`
- **Migration Need:** ✅ YES - Material master data

---

### 6. `assets/javascripts/purchase/rfq.js`
- **File Path:** `assets/javascripts/purchase/rfq.js`
- **Functions:**
  - `handleItemAdd()` - Adds RFQ item with `id_uom`
  - `handleItemSave()` - Saves RFQ item with `id_uom`
- **API Endpoint:** `source/purchase_rfq.php`
- **Payload Structure:**
  ```javascript
  // ADD ITEM
  { id_stock_item: stockId, requested_qty: qty, id_uom: uom, spec_notes: spec, sku }
  ```
- **DOM Usage:**
  - Form field: `$('.rfq-item-uom').val(ui.item.data.id_uom || '')`
- **Migration Need:** ✅ YES - Purchase RFQ

---

### 7. `assets/javascripts/issue/issue.js`
- **File Path:** `assets/javascripts/issue/issue.js`
- **Functions:**
  - `handleIssueSave()` - Saves issue with `id_uom`
  - `handleIssueEdit()` - Loads issue with UOM
- **API Endpoint:** `source/issue.php`
- **Payload Structure:**
  ```javascript
  { id_uom: parseInt(idUom), ... }
  ```
- **DOM Usage:**
  - Form field: `$('#iss_uom').val(d.id_uom)`
- **Migration Need:** ✅ YES - Issue workflow

---

## Summary Statistics

### Work Center References
- **Total JS Files:** 10
- **Core Management:** 2 (`work_centers.js`, `work_centers_behavior.js`)
- **Production Workflows:** 3 (`job_ticket.js`, `pwa_scan/work_queue.js`, `pwa_scan/pwa_scan.js`)
- **DAG System:** 3 (`graph_designer.js`, `GraphSaver.js`, `behavior_execution.js`)
- **Legacy:** 1 (`routing.js` - V1)
- **UI Display:** 1 (`product_graph_binding.js`)
- **All Require Migration:** ✅ YES

### Unit of Measure References
- **Total JS Files:** 7
- **Core Management:** 1 (`uom.js`)
- **Master Data:** 3 (`products.js`, `materials.js`, `mo.js`)
- **BOM System:** 1 (`bom.js`)
- **Inventory:** 2 (`purchase/rfq.js`, `issue/issue.js`)
- **All Require Migration:** ✅ YES

### Combined Total
- **Total JS Files Affected:** 17
- **All Require Migration:** ✅ YES
- **High-Risk Hotspots:**
  1. `work_centers.js` - Core work center management
  2. `uom.js` - Core UOM management
  3. `job_ticket.js` - Job ticket workflow
  4. `products.js` - Product master data
  5. `graph_designer.js` - DAG graph designer

---

## Migration Priority Recommendations

### Phase 2 Priority Order (Add `*_code` columns):

1. **High Priority (Core Management):**
   - `work_centers.js` - Work center CRUD UI
   - `uom.js` - UOM CRUD UI
   - `job_ticket.js` - Job ticket workflow
   - `products.js` - Product master data

2. **Medium Priority (Production Workflows):**
   - `graph_designer.js` - DAG graph designer
   - `bom.js` - BOM system
   - `materials.js` - Material master data
   - `mo.js` - Manufacturing orders
   - `pwa_scan/work_queue.js` - PWA work queue

3. **Low Priority (Supporting Systems):**
   - `work_centers_behavior.js` - Behavior mapping
   - `GraphSaver.js` - Graph saving
   - `behavior_execution.js` - Behavior execution
   - `product_graph_binding.js` - Graph binding UI
   - `pwa_scan/pwa_scan.js` - PWA scan
   - `purchase/rfq.js` - Purchase RFQ
   - `issue/issue.js` - Issue workflow
   - `routing.js` - Legacy V1 routing

---

## Common Patterns Found

### Pattern 1: Dropdown Options
```javascript
// Current (ID-based)
r.data.forEach(w => {
  sel.append(`<option value="${w.id_work_center}">${w.code} - ${w.name}</option>`);
});

// Future (Code-based)
r.data.forEach(w => {
  sel.append(`<option value="${w.code}">${w.code} - ${w.name}</option>`);
});
```

### Pattern 2: Form Field Values
```javascript
// Current (ID-based)
$('#field_id').val(data.id_work_center);

// Future (Code-based)
$('#field_code').val(data.work_center_code);
```

### Pattern 3: API Payloads
```javascript
// Current (ID-based)
{ action: 'save', id_work_center: id, ... }

// Future (Code-based)
{ action: 'save', work_center_code: code, ... }
```

### Pattern 4: DataTable Columns
```javascript
// Current (ID-based)
{ data: 'id_work_center', title: 'ID' }

// Future (Code-based)
{ data: 'work_center_code', title: 'Code' }
```

---

## Notes

- Most JS files already display `code` in dropdowns (good foundation)
- All files use jQuery for DOM manipulation
- DataTables used extensively for list views
- Form validation typically checks for empty values (will need to check for code instead of ID)
- Legacy V1 routing (`routing.js`) may be deprecated in future

---

**Last Updated:** December 2025

