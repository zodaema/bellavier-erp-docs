# Task 15.1 — System Seed Decoupling (Phase 1: Discovery & Impact Map) — Results

**Status:** ✅ **COMPLETED**  
**Date:** December 2025  
**Task:** [task15.1.md](./task15.1.md)

---

## Summary

Task 15.1 successfully completed the discovery and impact mapping phase for System Seed Decoupling. This phase identified all database tables, API endpoints, and JavaScript modules that depend on `work_center` and `unit_of_measure` tables, which must become fully seed-driven instead of ID-driven.

**Key Findings:**
- 14 database tables reference `work_center` or `unit_of_measure`
- 16+ PHP files use these tables
- 17 JavaScript files pass IDs to APIs or use IDs in UI
- All require migration to `*_code` columns

---

## Deliverables

### 1. Database Impact Map ✅

**File:** `task15.1_db_impact_map.md`

**Summary:**
- **Work Center References:** 6 tables
  - `job_task`, `job_ticket`, `routing_node`, `routing_step` (legacy), `work_center_team_map`, `work_center_behavior_map`
- **Unit of Measure References:** 8 tables
  - `bom_line`, `product`, `mo`, `material`, `material_lot`, `stock_item`, `stock_ledger`, `purchase_rfq_item`
- **All System-Critical:** ✅ YES (except 2 legacy tables)
- **All Require Migration:** ✅ YES

**High-Risk Hotspots:**
1. `job_task` - Core production workflow
2. `routing_node` - DAG routing system
3. `product` - Product master data
4. `mo` - Manufacturing orders
5. `material` / `stock_item` - Inventory system

---

### 2. API Impact Map ✅

**File:** `task15.1_api_impact_map.md`

**Summary:**
- **Work Center References:** 8 PHP files
  - CRUD: `work_centers.php`
  - Production: `hatthasilpa_job_ticket.php`, `pwa_scan_api.php`, `dag_token_api.php`
  - Routing: `routing.php` (legacy), `dag_routing_api.php`
  - Services: `LegacyRoutingAdapter.php`, `WorkCenterBehaviorRepository.php`
- **Unit of Measure References:** 8+ PHP files
  - CRUD: `uom.php`
  - Master Data: `products.php`, `materials.php`, `mo.php`
  - BOM: `bom.php`, `BOMService.php`
  - Inventory: `leather_grn.php`, `stock_card.php`, etc.
- **All Require Migration:** ✅ YES

**High-Risk Hotspots:**
1. `hatthasilpa_job_ticket.php` - Core production workflow
2. `products.php` - Product master data
3. `mo.php` - Manufacturing orders
4. `bom.php` / `BOMService.php` - BOM system
5. `materials.php` - Material master data

---

### 3. JavaScript Impact Map ✅

**File:** `task15.1_js_impact_map.md`

**Summary:**
- **Work Center References:** 10 JS files
  - Core: `work_centers.js`, `work_centers_behavior.js`
  - Production: `job_ticket.js`, `pwa_scan/work_queue.js`, `pwa_scan/pwa_scan.js`
  - DAG: `graph_designer.js`, `GraphSaver.js`, `behavior_execution.js`
  - Legacy: `routing.js` (V1)
  - UI: `product_graph_binding.js`
- **Unit of Measure References:** 7 JS files
  - Core: `uom.js`
  - Master Data: `products.js`, `materials.js`, `mo.js`
  - BOM: `bom.js`
  - Inventory: `purchase/rfq.js`, `issue/issue.js`
- **All Require Migration:** ✅ YES

**High-Risk Hotspots:**
1. `work_centers.js` - Core work center management
2. `uom.js` - Core UOM management
3. `job_ticket.js` - Job ticket workflow
4. `products.js` - Product master data
5. `graph_designer.js` - DAG graph designer

---

## Scope Summary

### Total Impact

| Category | Count | All Require Migration |
|----------|-------|----------------------|
| Database Tables | 14 | ✅ YES |
| PHP Files | 16+ | ✅ YES |
| JavaScript Files | 17 | ✅ YES |
| **Total Files Affected** | **47+** | **✅ YES** |

---

## High-Risk Hotspots

### 1. Core Production Workflow
- **Tables:** `job_task`, `job_ticket`
- **APIs:** `hatthasilpa_job_ticket.php`
- **JS:** `job_ticket.js`
- **Risk Level:** 🔴 **CRITICAL** - Production workflow depends on work center IDs

### 2. Product Master Data
- **Tables:** `product`, `bom_line`
- **APIs:** `products.php`, `bom.php`, `BOMService.php`
- **JS:** `products.js`, `bom.js`
- **Risk Level:** 🔴 **CRITICAL** - Product system depends on UOM IDs

### 3. DAG Routing System
- **Tables:** `routing_node`
- **APIs:** `dag_routing_api.php`, `dag_token_api.php`
- **JS:** `graph_designer.js`, `GraphSaver.js`
- **Risk Level:** 🔴 **CRITICAL** - DAG system depends on work center IDs

### 4. Manufacturing Orders
- **Tables:** `mo`
- **APIs:** `mo.php`
- **JS:** `mo.js`
- **Risk Level:** 🔴 **CRITICAL** - MO system depends on UOM IDs

### 5. Inventory System
- **Tables:** `material`, `stock_item`, `stock_ledger`, `material_lot`
- **APIs:** `materials.php`, `leather_grn.php`, inventory transaction APIs
- **JS:** `materials.js`
- **Risk Level:** 🟡 **HIGH** - Inventory system depends on UOM IDs

---

## Recommended Order for Phase 2

### Phase 2.1: Add `*_code` Columns (Non-Breaking)

**Priority 1 (Core Production):**
1. `job_task` → Add `work_center_code` column
2. `routing_node` → Add `work_center_code` column
3. `product` → Add `default_uom_code` column
4. `mo` → Add `uom_code` column

**Priority 2 (Master Data):**
5. `material` → Add `default_uom_code` column
6. `stock_item` → Add `uom_code` column
7. `bom_line` → Add `uom_code` column

**Priority 3 (Supporting Systems):**
8. `work_center_team_map` → Add `work_center_code` column
9. `work_center_behavior_map` → Add `work_center_code` column
10. `stock_ledger` → Add `uom_code` column
11. `material_lot` → Add `uom_code` column
12. `job_ticket` → Add `work_center_code` column (future use)
13. `routing_step` → Add `work_center_code` column (legacy V1)
14. `purchase_rfq_item` → Add `uom_code` column

---

## Risks & Mitigations

### Risk 1: Breaking Production Workflow
- **Risk:** Changing ID-based lookups to code-based may break existing workflows
- **Mitigation:** 
  - Phase 2 adds `*_code` columns alongside existing ID columns (non-breaking)
  - Phase 3 migrates code gradually with feature flags
  - Maintain backward compatibility during transition

### Risk 2: Data Migration Complexity
- **Risk:** Migrating existing data from IDs to codes requires careful mapping
- **Mitigation:**
  - Use migration scripts to populate `*_code` columns from existing IDs
  - Validate code uniqueness before migration
  - Test migration on dev/staging first

### Risk 3: API Breaking Changes
- **Risk:** Changing API payloads from IDs to codes may break frontend
- **Mitigation:**
  - Phase 2: APIs accept both ID and code (backward compatible)
  - Phase 3: APIs prefer code but fallback to ID
  - Phase 4: APIs require code only (after full migration)

### Risk 4: JavaScript Form Validation
- **Risk:** Form validation may break if checking for IDs instead of codes
- **Mitigation:**
  - Update validation to check for code instead of ID
  - Test all forms after migration
  - Provide clear error messages

### Risk 5: Legacy V1 Routing
- **Risk:** `routing_step` table is legacy V1 routing (may be deprecated)
- **Mitigation:**
  - Mark as low priority
  - Consider deprecating V1 routing before migration
  - Or migrate if still in active use

---

## Next Steps

### Phase 2: Add `*_code` Columns (Non-Breaking)
- Create migration to add `work_center_code` and `uom_code` columns
- Populate columns from existing ID relationships
- Add indexes on code columns
- Test on dev/staging

### Phase 3: Migrate API/JS Code to Use `*_code`
- Update APIs to accept code in addition to ID
- Update JavaScript to send code instead of ID
- Update queries to use code-based lookups
- Test all workflows

### Phase 4: Remove ID Dependencies
- Remove ID columns from API responses (optional)
- Remove ID columns from JavaScript payloads
- Consider removing ID foreign keys (if safe)
- Final cleanup

---

## Files Created

1. ✅ `task15.1_db_impact_map.md` - Database impact analysis
2. ✅ `task15.1_api_impact_map.md` - PHP API impact analysis
3. ✅ `task15.1_js_impact_map.md` - JavaScript impact analysis
4. ✅ `task15.1_results.md` - This summary file

---

## Acceptance Criteria Met

- ✅ No refactoring in this task (Phase 1 is discovery-only)
- ✅ No schema changes yet
- ✅ No code changes yet
- ✅ Only mapping, scanning, and documentation
- ✅ Complete enough to proceed safely to Task 15.2

---

## Notes

- All foreign key constraints use `ON DELETE SET NULL` or `ON DELETE CASCADE` - safe for migration
- Most APIs already return `code` in responses (good foundation)
- Most JavaScript dropdowns already display code (good foundation)
- Legacy V1 routing (`routing_step`, `routing.php`) may be deprecated in future
- `job_ticket.id_work_center` is marked as "future use" - currently NULL in most cases

---

**Task 15.1 Complete** ✅  
**Ready for Phase 2: Add `*_code` Columns**

---

**Last Updated:** December 2025

