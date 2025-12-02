# Task 14.2 — Re-Scan After Task 14.1.5-14.1.6

## Summary
This document provides an updated scan of legacy references after completing Task 14.1.5 and 14.1.6, to determine if Task 14.2 can proceed safely.

---

## Scan Results (Post Task 14.1.6)

### 1. Legacy Stock Tables (`stock_item`, `stock_item_lot`)

#### Files Still Using Legacy Stock:

**A. `source/leather_grn.php`**
- **References:** 6 matches
- **Usage:** 
  - Dual-write to `id_stock_item` (Task 14.1.2 pattern - INTENTIONALLY KEPT)
  - Fallback queries using `stock_item` table (Line 211-212, 568)
- **Status:** ⚠️ **INTENTIONALLY KEPT** - Dual-write logic, not safe to remove
- **Action:** ⛔ **DO NOT REMOVE** - Part of dual-write pattern from Task 14.1.2

**B. `source/materials.php`**
- **References:** 10 matches
- **Usage:**
  - `lot_list` action: Fallback to `id_stock_item` (Task 14.1.2 pattern)
  - `lot_create` action: Still requires `id_stock_item` (dual-write)
  - Direct queries to `stock_item` table (Lines 176, 308, 369, 420, 640, 662)
- **Status:** ⚠️ **INTENTIONALLY KEPT** - Dual-write and fallback logic
- **Action:** ⛔ **DO NOT REMOVE** - Part of dual-write pattern

**C. Other Files:**
- `source/BGERP/Helper/MaterialResolver.php` - 2 matches (comments only)
- `source/trace_api.php` - 3 matches (comments only)
- `source/refs.php` - 2 matches (needs verification)
- `source/purchase_rfq.php` - 1 match (needs verification)
- `source/utils/InventoryHelper.php` - 4 matches (needs verification)

---

### 2. Legacy BOM Tables (`bom_line`)

#### Files Still Using `bom_line`:

**A. `source/bom.php`**
- **References:** 16 matches
- **Usage:** Active BOM operations (CRUD)
- **Status:** ✅ **ACTIVE TABLE** - `bom_line` is NOT legacy, it's the active BOM table
- **Action:** ⛔ **DO NOT DROP** - This is the current BOM table

**B. `source/BGERP/Service/BOMService.php`**
- **References:** 6 matches
- **Usage:** Active BOM service methods
- **Status:** ✅ **ACTIVE TABLE** - `bom_line` is NOT legacy
- **Action:** ⛔ **DO NOT DROP** - This is the current BOM table

**C. Other Files:**
- `source/leather_cut_bom_api.php` - 3 matches (active usage)
- `source/BGERP/Helper/MaterialResolver.php` - 1 match (active usage)
- `source/BGERP/Component/ComponentAllocationService.php` - 2 matches (active usage)
- `source/component.php` - 1 match (active usage)

**Conclusion:** `bom_line` is **ACTIVE**, not legacy. Do NOT drop in Task 14.2.

---

### 3. Legacy Routing Tables (`routing`, `routing_step`)

#### Files Still Using Legacy Routing:

**A. `source/routing.php` (Legacy API - READ-ONLY)**
- **Status:** ⚠️ **INTENTIONALLY KEPT** - DEPRECATED, READ-ONLY
- **Usage:** Historical data access only
- **Action:** ⛔ **DO NOT DELETE** - Per task14.1.6_results.md

**B. `source/BGERP/Helper/LegacyRoutingAdapter.php` (Adapter)**
- **Status:** ⚠️ **INTENTIONALLY KEPT** - Backward compatibility adapter
- **Used By:**
  - `source/hatthasilpa_job_ticket.php`
  - `source/pwa_scan_api.php`
- **Action:** ⛔ **DO NOT DELETE** - Per task14.1.6_results.md

**C. Other Files:**
- `source/classic_api.php` - 2 matches (needs verification)
- `source/BGERP/Service/GraphInstanceService.php` - 1 match (needs verification)
- `source/BGERP/Service/ScheduleService.php` - 3 matches (needs verification)
- `source/service/ScheduleService.php` - 2 matches (needs verification)
- `source/BGERP/Service/WorkCenterCapacityCalculator.php` - 1 match (needs verification)
- `source/service/CapacityCalculator.php` - 1 match (needs verification)

---

### 4. Legacy Column References (`id_stock_item`, `id_routing`)

#### Files Still Using Legacy Columns:

**A. `id_stock_item` References:**
- `source/routing.php` - 19 matches (comments/deprecated code)
- `source/leather_grn.php` - 14 matches (dual-write - INTENTIONALLY KEPT)
- `source/materials.php` - 28 matches (dual-write/fallback - INTENTIONALLY KEPT)
- `source/trace_api.php` - 4 matches (comments only)
- `source/purchase_rfq.php` - 8 matches (needs verification)
- `source/BGERP/Service/ScheduleService.php` - 4 matches (needs verification)
- `source/service/ScheduleService.php` - 4 matches (needs verification)
- `source/BGERP/Service/WorkCenterCapacityCalculator.php` - 3 matches (needs verification)
- `source/service/CapacityCalculator.php` - 4 matches (needs verification)

**B. `id_routing` References:**
- `source/routing.php` - Multiple references (deprecated API)
- `source/hatthasilpa_job_ticket.php` - 1 match (uses LegacyRoutingAdapter)
- `source/BGERP/Helper/LegacyRoutingAdapter.php` - 5 matches (adapter)
- Other files - Various references (needs verification)

---

## Summary Statistics

| Category | Total References | Intentionally Kept | Active Table | Needs Verification | Safe to Remove |
|----------|------------------|-------------------|--------------|-------------------|----------------|
| Legacy Stock | 34 matches | ~20 (dual-write) | 0 | ~14 | 0 |
| Legacy BOM | 29 matches | 0 | 29 (active) | 0 | 0 |
| Legacy Routing | 13 matches | ~8 (adapter) | 0 | ~5 | 0 |
| Legacy Columns | 94 matches | ~50 (dual-write) | 0 | ~44 | 0 |

---

## Critical Findings

### ⚠️ Cannot Proceed with Full Task 14.2

**Reasons:**

1. **`bom_line` is ACTIVE, not legacy**
   - Task 14.2.md incorrectly lists `bom_line` as legacy
   - `bom_line` is the current BOM table (per task14_inventory.md)
   - **Action:** ⛔ **DO NOT DROP** `bom_line` table

2. **Dual-write logic still active**
   - `leather_grn.php` and `materials.php` still use `id_stock_item` for dual-write
   - Per task14.1.6_results.md: "ห้ามลบ FK / columns หรือ refactor ส่วนนี้ใน Task 14.2"
   - **Action:** ⛔ **DO NOT DROP** `id_stock_item` columns

3. **Legacy routing intentionally kept**
   - `routing.php` and `LegacyRoutingAdapter.php` kept for backward compatibility
   - Per task14.1.6_results.md: "ห้ามลบใน Task 14.2 จนกว่าจะมี Task แยก"
   - **Action:** ⛔ **DO NOT DELETE** routing V1 files

4. **`stock_item` table still referenced**
   - Still used in dual-write patterns
   - Still used in fallback queries
   - **Action:** ⛔ **DO NOT DROP** `stock_item` table yet

---

## Safe Actions for Task 14.2

### ✅ Can Do (Limited Scope)

1. **Documentation Only:**
   - Update migration comments
   - Add deprecation warnings
   - Document remaining legacy references

2. **Verify Table Status:**
   - Confirm which tables are truly legacy vs active
   - Document findings

3. **Prepare Migration File (Read-Only):**
   - Create migration file structure
   - Add comments about what CANNOT be dropped yet
   - Prepare for future cleanup

### ⛔ Cannot Do (Per task14.1.6_results.md)

1. ❌ Drop `stock_item` table
2. ❌ Drop `id_stock_item` columns
3. ❌ Drop `routing` V1 tables
4. ❌ Delete `routing.php` file
5. ❌ Delete `LegacyRoutingAdapter.php`
6. ❌ Drop `bom_line` table (it's active, not legacy)

---

## Recommendation

**Status:** ⚠️ **LIMITED SCOPE ONLY**

Task 14.2 should be executed with **LIMITED SCOPE**:
- ✅ Documentation and preparation only
- ✅ Verify table status
- ⛔ **DO NOT** drop tables/columns that are still in use
- ⛔ **DO NOT** delete code files that are intentionally kept

**Next Steps:**
1. Create migration file with comments about what cannot be dropped
2. Document remaining legacy references
3. Create task plan for future cleanup phases
4. Wait for explicit approval before dropping any tables/columns

---

**Scan Date:** 2025-12-XX  
**Status:** ⚠️ **LIMITED SCOPE** - Cannot proceed with full cleanup

