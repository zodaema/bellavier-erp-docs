

# Task 15.4 — Work Center & UOM Dual-Mode API Layer (ID → CODE Transition)

## Objective
Implement a transitional dual-mode API layer so that all ERP modules can operate using both:
- Legacy: `id_work_center`, `id_uom`
- New Standard: `work_center_code`, `uom_code`

This allows the system to continue running while we progressively migrate UI, JS, and backend logic away from ID-based references.

---

## Scope

### APIs to Update
**Work Center Related**
- `dag_routing_api.php`
- `work_center.php`
- `work_center_team.php`
- `work_center_behavior.php`
- `job_ticket_api.php`
- `job_task_api.php`

**UOM Related**
- `products.php`
- `materials.php`
- `bom.php`
- `mo.php`
- `purchase.php`
- `stock_ledger_api.php`

### JavaScript Files to Update
- `graph_designer.js`
- `job_ticket.js`
- `mo.js`
- `products.js`
- `materials.js`
- `bom_editor.js`
- `purchase.js`

---

## Dual-Mode Strategy

### 1. API Input (Accept Both)
For every endpoint that currently requires:
- `id_work_center`
- `id_uom`

Update input handling:

```
if (isset($_POST['work_center_code'])) {
    $wc = WorkCenterService::resolveByCode($_POST['work_center_code']);
    $id_work_center = $wc['id_work_center'];
} else {
    $id_work_center = intval($_POST['id_work_center']);
}
```

Same pattern for UOM:
```
if (isset($_POST['uom_code'])) {
    $uom = UOMService::resolveByCode($_POST['uom_code']);
    $id_uom = $uom['id_unit'];
} else {
    $id_uom = intval($_POST['id_uom']);
}
```

### 2. API Output (Always Return Both)
Example output:
```
{
   "id_work_center": 3,
   "work_center_code": "CUT",
   "id_uom": 2,
   "uom_code": "SQFT"
}
```

### 3. Database Writes (Still ID-Based)
For now:
- Write using IDs  
- Use codes only as resolution layer

---

## Migration Safety Rules

### Allowed
- Add code → id resolution
- Return both id + code in API responses
- Add new service helpers

### Forbidden
- Removing ID fields
- Rewriting schema
- Changing existing output field names

### Required Safeguards
- Must log resolution mismatches
- Must verify code uniqueness before resolution
- Must prevent null ID writes

---

## Required New Helpers

### WorkCenterService
```
resolveByCode($code)
getById($id)
ensureCodeExists($code)
```

### UOMService
```
resolveByCode($code)
getById($id)
ensureCodeExists($code)
```

---

## Deliverables

### 1. Code Changes
- Update all APIs listed above
- Update all JS modules to send `*_code` instead of `id_*`
- Add resolution helpers

### 2. Documentation
- `task15.4_results.md`
- Updated impact maps for API & JS layers
- Example POST payloads for each updated endpoint

### 3. Verification Plan
- Unit test: API accepts code
- Unit test: API resolves correct ID
- UI test: JS sends only codes
- DB test: Writes occur only through IDs

---

## Acceptance Criteria
- Full system still works using legacy IDs
- Full system can operate using codes
- Zero breaking changes in existing UIs
- Codes fully backfilled (from Task 15.3)
- No direct DB updates using codes
- All resolution mapping logged

---

## Next Step After Task 15.4
Task 15.5 — **Hard transition**
- Switch API to code-only mode
- Deprecate all ID-based input
- Migrate routing_node to code-only
