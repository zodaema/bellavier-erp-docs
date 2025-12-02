# Task 15.4 — Work Center & UOM Dual-Mode API Layer — Results

**Status:** ✅ **PHASE 1 COMPLETED** (Service Helpers Created)  
**Date:** December 2025  
**Task:** [task15.4.md](./task15.4.md)

---

## Summary

Task 15.4 implements a transitional dual-mode API layer for Work Center and UOM code-based resolution. **Phase 1** (Service Helpers) has been completed. The system now has infrastructure to support both ID and CODE-based lookups.

**Key Achievements:**
- ✅ WorkCenterService created with code resolution
- ✅ UOMService created with code resolution
- ✅ Dual-mode support (code → id resolution)
- ✅ Error logging for resolution mismatches
- ✅ Ready for API endpoint updates

---

## Deliverables

### 1. Service Helpers ✅

#### WorkCenterService
**File:** `source/BGERP/Service/WorkCenterService.php`

**Methods:**
- `resolveByCode(string $code): ?array` - Resolve work center by code
- `getById(int $id): ?array` - Get work center by ID
- `ensureCodeExists(string $code): bool` - Check if code exists
- `resolveId(?string $code, ?int $id): ?int` - Dual-mode resolution (code or id)

**Usage Pattern:**
```php
require_once __DIR__ . '/BGERP/Service/WorkCenterService.php';

$wcService = new \BGERP\Service\WorkCenterService($tenantDb);

// Resolve by code
$id = $wcService->resolveId(code: $_POST['work_center_code']);

// Or resolve by id (backward compatible)
$id = $wcService->resolveId(id: (int)($_POST['id_work_center'] ?? 0));
```

#### UOMService
**File:** `source/BGERP/Service/UOMService.php`

**Methods:**
- `resolveByCode(string $code): ?array` - Resolve UOM by code
- `getById(int $id): ?array` - Get UOM by ID
- `ensureCodeExists(string $code): bool` - Check if code exists
- `resolveId(?string $code, ?int $id): ?int` - Dual-mode resolution (code or id)

**Usage Pattern:**
```php
require_once __DIR__ . '/BGERP/Service/UOMService.php';

$uomService = new \BGERP\Service\UOMService($tenantDb);

// Resolve by code
$id = $uomService->resolveId(code: $_POST['uom_code']);

// Or resolve by id (backward compatible)
$id = $uomService->resolveId(id: (int)($_POST['id_uom'] ?? 0));
```

---

## API Update Pattern

### Input Handling (Dual-Mode)

**Before:**
```php
$id_work_center = (int)($_POST['id_work_center'] ?? 0);
if ($id_work_center <= 0) {
    json_error('Invalid work center ID', 400);
}
```

**After:**
```php
require_once __DIR__ . '/BGERP/Service/WorkCenterService.php';
$wcService = new \BGERP\Service\WorkCenterService($tenantDb);

// Accept both code and id
$id_work_center = $wcService->resolveId(
    code: $_POST['work_center_code'] ?? null,
    id: (int)($_POST['id_work_center'] ?? 0)
);

if ($id_work_center === null) {
    json_error('Work center not found (code or id required)', 400);
}
```

### Output Enhancement (Return Both)

**Before:**
```php
json_success([
    'id_work_center' => $row['id_work_center'],
    'code' => $row['code'],
    'name' => $row['name']
]);
```

**After:**
```php
json_success([
    'id_work_center' => $row['id_work_center'],
    'work_center_code' => $row['code'], // Always include code
    'name' => $row['name']
]);
```

### Database Writes (Still ID-Based)

**Important:** Database writes should still use IDs:
```php
// ✅ CORRECT: Write using ID
$stmt = $db->prepare("INSERT INTO job_task (id_work_center, ...) VALUES (?, ...)");
$stmt->bind_param('i', $id_work_center);

// ❌ WRONG: Don't write codes directly to ID columns
// $stmt->bind_param('s', $_POST['work_center_code']); // NO!
```

---

## API Files Requiring Updates

### Work Center Related APIs

1. **`source/work_centers.php`** ⚠️ PENDING
   - Update `handleCreate()` - Accept `work_center_code` in addition to `id_work_center`
   - Update `handleUpdate()` - Accept `work_center_code` in addition to `id_work_center`
   - Update `handleList()` - Return both `id_work_center` and `work_center_code`
   - Update `handleGet()` - Return both `id_work_center` and `work_center_code`

2. **`source/hatthasilpa_job_ticket.php`** ⚠️ PENDING
   - Update `handleTaskSave()` - Accept `work_center_code` in addition to `id_work_center`
   - Update `handleTaskList()` - Return both `id_work_center` and `work_center_code`
   - Update `handleTaskCreateFromRouting()` - Use code resolution

3. **`source/dag_routing_api.php`** ⚠️ PENDING
   - Update `handleNodeSave()` - Accept `work_center_code` in addition to `id_work_center`
   - Update `handleNodeList()` - Return both `id_work_center` and `work_center_code`
   - Update `handleGetWorkCenters()` - Return both `id_work_center` and `work_center_code`

4. **`source/pwa_scan_api.php`** ⚠️ PENDING
   - Update `handleGetTokenDetails()` - Return both `id_work_center` and `work_center_code`
   - Update `handleGetWorkQueue()` - Return both `id_work_center` and `work_center_code`

5. **`source/work_center_team.php`** ⚠️ PENDING
   - Update `handleBind()` - Accept `work_center_code` in addition to `id_work_center`
   - Update `handleList()` - Return both `id_work_center` and `work_center_code`

6. **`source/work_center_behavior.php`** ⚠️ PENDING
   - Update `handleBind()` - Accept `work_center_code` in addition to `id_work_center`
   - Update `handleList()` - Return both `id_work_center` and `work_center_code`

### UOM Related APIs

1. **`source/products.php`** ⚠️ PENDING
   - Update `handleSave()` - Accept `default_uom_code` in addition to `default_uom`
   - Update `handleList()` - Return both `id_uom`/`default_uom` and `uom_code`/`default_uom_code`
   - Update `handleGet()` - Return both `id_uom`/`default_uom` and `uom_code`/`default_uom_code`

2. **`source/materials.php`** ⚠️ PENDING
   - Update `handleSave()` - Accept `default_uom_code` in addition to `default_uom`
   - Update `handleList()` - Return both `id_uom`/`default_uom` and `uom_code`/`default_uom_code`

3. **`source/bom.php`** ⚠️ PENDING
   - Update `handleLineSave()` - Accept `uom_code` in addition to `id_uom`
   - Update `handleLineList()` - Return both `id_uom` and `uom_code`

4. **`source/mo.php`** ⚠️ PENDING
   - Update `handleSave()` - Accept `uom_code` in addition to `id_uom`
   - Update `handleList()` - Return both `id_uom` and `uom_code`
   - Update `handleGet()` - Return both `id_uom` and `uom_code`

5. **`source/purchase.php`** ⚠️ PENDING
   - Update `handleRfqItemSave()` - Accept `uom_code` in addition to `id_uom`
   - Update `handleRfqItemList()` - Return both `id_uom` and `uom_code`

6. **`source/stock_ledger_api.php`** ⚠️ PENDING
   - Update `handleList()` - Return both `id_uom` and `uom_code`
   - Update `handleGet()` - Return both `id_uom` and `uom_code`

---

## JavaScript Files Requiring Updates

### Work Center Related JS

1. **`assets/javascripts/work_centers/work_centers.js`** ⚠️ PENDING
   - Update `handleSave()` - Send `work_center_code` instead of `id_work_center`
   - Update `buildTable()` - Display `work_center_code` instead of `id_work_center`
   - Update `handleEdit()` - Use `work_center_code` for lookups

2. **`assets/javascripts/work_centers/work_centers_behavior.js`** ⚠️ PENDING
   - Update `bindBehavior()` - Send `work_center_code` instead of `id_work_center`
   - Update `unbindBehavior()` - Send `work_center_code` instead of `id_work_center`

3. **`assets/javascripts/hatthasilpa/job_ticket.js`** ⚠️ PENDING
   - Update `handleTaskSave()` - Send `work_center_code` instead of `id_work_center`
   - Update `loadWorkCenters()` - Use `work_center_code` for dropdown values
   - Update `handleTaskEdit()` - Use `work_center_code` for form population

4. **`assets/javascripts/dag/graph_designer.js`** ⚠️ PENDING
   - Update `saveNode()` - Send `work_center_code` instead of `id_work_center`
   - Update `loadWorkCenters()` - Use `work_center_code` for dropdown values
   - Update `renderNodeForm()` - Use `work_center_code` for form population

### UOM Related JS

1. **`assets/javascripts/products/products.js`** ⚠️ PENDING
   - Update `handleSave()` - Send `default_uom_code` instead of `default_uom`
   - Update `loadUOMs()` - Use `uom_code` for dropdown values
   - Update `handleEdit()` - Use `default_uom_code` for form population

2. **`assets/javascripts/materials/materials.js`** ⚠️ PENDING
   - Update `handleSave()` - Send `default_uom_code` instead of `default_uom`
   - Update `loadUOMs()` - Use `uom_code` for dropdown values

3. **`assets/javascripts/bom/bom_editor.js`** ⚠️ PENDING
   - Update `handleLineSave()` - Send `uom_code` instead of `id_uom`
   - Update `loadUOMs()` - Use `uom_code` for dropdown values

4. **`assets/javascripts/mo/mo.js`** ⚠️ PENDING
   - Update `handleSave()` - Send `uom_code` instead of `id_uom`
   - Update `loadUOMs()` - Use `uom_code` for dropdown values

5. **`assets/javascripts/purchase/purchase.js`** ⚠️ PENDING
   - Update `handleRfqItemSave()` - Send `uom_code` instead of `id_uom`
   - Update `loadUOMs()` - Use `uom_code` for dropdown values

---

## Implementation Checklist

### Phase 1: Service Helpers ✅
- [x] Create WorkCenterService
- [x] Create UOMService
- [x] Implement code resolution
- [x] Implement ID resolution
- [x] Add error logging

### Phase 2: API Updates ⚠️ PENDING
- [ ] Update work_centers.php
- [ ] Update hatthasilpa_job_ticket.php
- [ ] Update dag_routing_api.php
- [ ] Update pwa_scan_api.php
- [ ] Update work_center_team.php
- [ ] Update work_center_behavior.php
- [ ] Update products.php
- [ ] Update materials.php
- [ ] Update bom.php
- [ ] Update mo.php
- [ ] Update purchase.php
- [ ] Update stock_ledger_api.php

### Phase 3: JavaScript Updates ⚠️ PENDING
- [ ] Update work_centers.js
- [ ] Update work_centers_behavior.js
- [ ] Update job_ticket.js
- [ ] Update graph_designer.js
- [ ] Update products.js
- [ ] Update materials.js
- [ ] Update bom_editor.js
- [ ] Update mo.js
- [ ] Update purchase.js

### Phase 4: Testing ⚠️ PENDING
- [ ] Unit test: API accepts code
- [ ] Unit test: API resolves correct ID
- [ ] Unit test: API returns both id and code
- [ ] UI test: JS sends only codes
- [ ] DB test: Writes occur only through IDs
- [ ] Integration test: Full workflow with codes

---

## Migration Safety Rules

### ✅ Allowed
- Add code → id resolution
- Return both id + code in API responses
- Add new service helpers
- Accept code in addition to id in API inputs

### ❌ Forbidden
- Removing ID fields from API responses
- Rewriting database schema
- Changing existing output field names
- Writing codes directly to ID columns

### ✅ Required Safeguards
- Must log resolution mismatches
- Must verify code uniqueness before resolution
- Must prevent null ID writes
- Must maintain backward compatibility (ID still works)

---

## Example API Update

### Before (ID-only)
```php
case 'task_save':
    $id_work_center = (int)($_POST['id_work_center'] ?? 0);
    if ($id_work_center <= 0) {
        json_error('Invalid work center ID', 400);
    }
    
    $stmt = $db->prepare("INSERT INTO job_task (id_work_center, ...) VALUES (?, ...)");
    $stmt->bind_param('i', $id_work_center);
    // ...
    break;
```

### After (Dual-Mode)
```php
case 'task_save':
    require_once __DIR__ . '/BGERP/Service/WorkCenterService.php';
    $wcService = new \BGERP\Service\WorkCenterService($tenantDb);
    
    // Accept both code and id
    $id_work_center = $wcService->resolveId(
        code: $_POST['work_center_code'] ?? null,
        id: (int)($_POST['id_work_center'] ?? 0)
    );
    
    if ($id_work_center === null) {
        json_error('Work center not found (code or id required)', 400);
    }
    
    $stmt = $db->prepare("INSERT INTO job_task (id_work_center, work_center_code, ...) VALUES (?, ?, ...)");
    $stmt->bind_param('is', $id_work_center, $_POST['work_center_code'] ?? null);
    // ...
    break;
```

---

## Next Steps

### Immediate (Phase 2)
1. Update API endpoints one by one
2. Test each API update thoroughly
3. Verify backward compatibility (ID still works)

### Short-term (Phase 3)
1. Update JavaScript files
2. Test UI workflows
3. Verify code-based operations

### Long-term (Task 15.5)
1. Switch API to code-only mode
2. Deprecate all ID-based input
3. Migrate routing_node to code-only

---

## Files Created

1. ✅ `source/BGERP/Service/WorkCenterService.php` - Work center resolution service
2. ✅ `source/BGERP/Service/UOMService.php` - UOM resolution service
3. ✅ `docs/dag/tasks/task15.4_results.md` - This results file

---

## Notes

- **Service Pattern:**
  - Services use prepared statements (SQL injection safe)
  - Services log errors for debugging
  - Services return null on not found (graceful handling)

- **Resolution Priority:**
  - Code first (if provided)
  - ID second (if code not provided)
  - Null if neither found

- **Error Handling:**
  - Resolution mismatches logged to error_log
  - API returns 400 if resolution fails
  - Database writes still use IDs (safe)

- **Backward Compatibility:**
  - Existing ID-based code continues to work
  - New code-based code works alongside
  - Gradual migration possible

---

**Task 15.4 Phase 1 Complete** ✅  
**Service Helpers Ready for API Integration**  
**Next: Update API Endpoints (Phase 2)**

---

**Last Updated:** December 2025

