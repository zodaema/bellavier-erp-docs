# Task 15.5 — Hard Transition Results

## Overview
Task 15.5 implements hard transition from ID-based references to CODE-based references for Work Centers and Units of Measure (UOM).

## Files Updated

### API Layer (8 files) ✅

1. **`source/products.php`**
   - Reject `default_uom` (id), require `default_uom_code`
   - create, update actions

2. **`source/materials.php`**
   - Reject `id_uom`, require `uom_code`
   - create, update, lot_create actions

3. **`source/mo.php`**
   - Reject `id_uom`, require `uom_code`
   - create action (fallback to product default)

4. **`source/bom.php`**
   - Reject `id_uom`, require `uom_code`
   - add_line, add_assembly, update_line actions

5. **`source/dag_routing_api.php`**
   - Reject `id_work_center`, require `work_center_code`
   - node_create, graph_save (UPDATE และ INSERT nodes)

6. **`source/dag_behavior_exec.php`**
   - Reject `work_center_id` ใน context, require `work_center_code`

7. **`source/hatthasilpa_job_ticket.php`**
   - Reject `id_work_center`, require `work_center_code`
   - task_create, task_update, task_create_from_routing actions

8. **`source/work_centers.php`**
   - Reject `id_work_center`, require `work_center_code`
   - update action

### JavaScript Layer (8 files) ✅

1. **`assets/javascripts/products/products.js`**
   - Send `default_uom_code` instead of `default_uom`
   - UOM dropdown uses code as value only
   - Removed all id fallbacks

2. **`assets/javascripts/materials/materials.js`**
   - Send `uom_code` instead of `id_uom`
   - UOM dropdowns use code as value only
   - Removed all id fallbacks

3. **`assets/javascripts/mo/mo.js`**
   - Send `uom_code` instead of `id_uom`
   - Removed id fallback

4. **`assets/javascripts/bom/bom.js`**
   - Send `uom_code` instead of `id_uom`
   - UOM dropdowns use code as value only
   - Removed all id fallbacks

5. **`assets/javascripts/dag/graph_designer.js`**
   - Send `work_center_code` instead of `id_work_center`
   - Work center dropdown uses code as value only
   - Removed workCenterId data attribute

6. **`assets/javascripts/dag/modules/GraphSaver.js`**
   - Send `work_center_code` instead of `id_work_center`

7. **`assets/javascripts/hatthasilpa/job_ticket.js`**
   - Send `work_center_code` instead of `id_work_center`
   - Removed `work_center_id` from context
   - Work center dropdown uses code as value only

8. **`assets/javascripts/work_centers/work_centers_behavior.js`**
   - Send `work_center_code` only (removed `id_work_center`)

9. **`assets/javascripts/work_centers/work_centers.js`**
   - Removed `id_work_center` from update payload

10. **`assets/javascripts/products/product_graph_binding.js`**
    - Display `work_center_code` instead of `id_work_center`

## Error Handling

All APIs now return HTTP 400 with error codes:
- `WORK_CENTER_ID_DEPRECATED` - When `id_work_center` is submitted
- `UOM_ID_DEPRECATED` - When `id_uom` or `default_uom` is submitted

Error response format:
```json
{
  "ok": false,
  "error": {
    "code": "WORK_CENTER_ID_DEPRECATED",
    "message": "id_work_center is deprecated. Use work_center_code instead.",
    "hint": "ส่ง work_center_code ตามที่ได้จาก /work_centers.php?action=list"
  }
}
```

## Static Scan Results

### PHP Files
- **API Input Handling:** ✅ All APIs reject `id_*` in POST/GET requests
- **Database Queries:** ⚠️ Some SELECT queries still reference `id_work_center` and `id_uom` (read-only, acceptable)
- **Legacy Files:** ⚠️ `grn.php`, `leather_grn.php` still use `id_uom` (outside Task 15.5 scope per guardrails)

### JavaScript Files
- **Form Submissions:** ✅ All forms send `*_code` only
- **Dropdown Values:** ✅ All dropdowns use code as value
- **Legacy Files:** ⚠️ Some legacy files still use `id_*`:
  - `adjust.js`, `transfer.js`, `issue.js` - Stock operations (outside scope)
  - `routing.js` - Legacy routing (deprecated)
  - `grn.js`, `rfq.js` - Purchase/GRN operations (outside scope)

### Acceptable Exceptions
- Database SELECT queries (read-only)
- Legacy modules outside Task 15.5 scope (per guardrails)
- Migration files
- Documentation/comments

## Database Writes

All INSERT/UPDATE operations now use `*_code` columns:
- `routing_node.work_center_code`
- `job_task.work_center_code`
- `product.default_uom_code`
- `material.uom_code`
- `material_lot.uom_code`
- `mo.uom_code`
- `bom_line.uom_code`
- `stock_item.uom_code`

**Note:** `id_*` columns are still populated for backward compatibility (will be removed in Task 15.6).

## Testing Checklist

### ✅ Completed
- [x] All API files reject `id_*` in requests
- [x] All API files require `*_code` in requests
- [x] All JS files send `*_code` only
- [x] All JS dropdowns use code as value
- [x] Syntax validation passed for all files
- [x] Error handling implemented with proper error codes

### ⚠️ Manual Testing Required
- [ ] Test product create/update with `default_uom_code`
- [ ] Test material create/update with `uom_code`
- [ ] Test MO create with `uom_code`
- [ ] Test BOM line add with `uom_code`
- [ ] Test DAG node create with `work_center_code`
- [ ] Test job task create with `work_center_code`
- [ ] Verify error messages when sending `id_*`

## Migration Safety

### ✅ Allowed Changes
- Reject `id_*` in API requests
- Require `*_code` in API requests
- Send `*_code` from JavaScript
- Use `*_code` in database writes

### ❌ No Breaking Changes
- Database schema unchanged (columns still exist)
- Read-only queries still work
- Legacy modules untouched (per guardrails)

## Notes

1. **Legacy Files:**
   - `grn.php`, `leather_grn.php` - Still use `id_uom` (outside scope per guardrails)
   - `adjust.js`, `transfer.js`, `issue.js` - Stock operations (outside scope)
   - `routing.js` - Legacy routing system (deprecated)

2. **Read-Only Operations:**
   - SELECT queries may still reference `id_*` (acceptable)
   - Display/rendering may show `id_*` (acceptable for read-only)

3. **Database Columns:**
   - `id_work_center` and `id_uom` columns still exist (will be removed in Task 15.6)
   - Both `id_*` and `*_code` are populated for backward compatibility

## Files Status

| Category | Files Updated | Status |
|----------|---------------|--------|
| API (PHP) | 8 files | ✅ Complete |
| JS (Frontend) | 10 files | ✅ Complete |
| Static Scan | PHP + JS | ✅ Complete |

## Next Steps

1. Manual testing of updated endpoints
2. Verify error messages are clear and helpful
3. Proceed to Task 15.6 (DROP ID columns) when ready

---

**Task 15.5 Complete** ✅  
**API Files Updated: 8**  
**JS Files Updated: 10**  
**Error Handling: Implemented**  
**Static Scan: Passed (with acceptable exceptions)**

**Last Updated:** December 2025

