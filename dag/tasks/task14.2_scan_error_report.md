# Task 14.2 — Pre-Cleanup Scan Error Report (Updated After Task 14.1.5-14.1.6)

## ⚠️ LIMITED SCOPE: Legacy References Still Present

**Status:** ⚠️ **LIMITED SCOPE - Task 14.2 executed with documentation only**

This report documents all legacy table references found in the codebase.  
**Most cleanup operations are COMMENTED OUT due to remaining dependencies per task14.1.6_results.md.**

**Last Updated:** After Task 14.1.5 and 14.1.6 completion

---

## 🔴 Critical Legacy References Found

### 1. Legacy Routing Tables (`routing`, `routing_step`)

#### Files Still Using Legacy Routing:

**A. `source/routing.php` (Legacy API - READ-ONLY)**
- **Status:** ⚠️ Still exists, marked as deprecated
- **Usage:** READ operations only (CREATE/UPDATE/DELETE disabled in Task 14.1.3)
- **Action Required:** Delete file after confirming no UI/API calls it

**B. `source/BGERP/Helper/LegacyRoutingAdapter.php` (Adapter)**
- **Status:** ⚠️ Still in use
- **Used By:**
  - `source/hatthasilpa_job_ticket.php` (Line 1177-1216)
  - `source/pwa_scan_api.php` (Line 1120-1170)
- **Action Required:** Remove adapter after migrating all callers to V2

**C. Direct SQL Queries:**
- `source/routing.php` - Multiple queries to `routing` and `routing_step` tables
- `source/BGERP/Helper/LegacyRoutingAdapter.php` - Queries to `routing` and `routing_step` tables

---

### 2. Legacy Stock Tables (`stock_item`, `stock_item_lot`)

#### Files Still Using Legacy Stock:

**A. `source/leather_grn.php`**
- **References:** 6 matches
- **Usage:** 
  - Dual-write to `id_stock_item` (Task 14.1.2)
  - Fallback queries using `stock_item` table
- **Action Required:** Remove dual-write and fallback logic

**B. `source/materials.php`**
- **References:** 10 matches
- **Usage:**
  - `lot_list` action: Fallback to `id_stock_item` (Line 564-587)
  - `lot_create` action: Still requires `id_stock_item` (Line 596)
- **Action Required:** Migrate to `id_material` only

**C. `source/bom.php`**
- **References:** 12 matches
- **Usage:**
  - `lines` action: JOIN with `stock_item` (Line 475)
  - `get_line` action: JOIN with `stock_item` (Line 721)
- **Action Required:** Migrate to `material` table

**D. `source/BGERP/Service/BOMService.php`**
- **References:** 2 matches
- **Usage:**
  - `getBOMLines()`: JOIN with `stock_item` (Line 214)
- **Action Required:** Migrate to `material` table

**E. `source/BGERP/Helper/MaterialResolver.php`**
- **References:** 2 matches
- **Usage:** Legacy material resolution
- **Action Required:** Remove legacy resolution methods

**F. Other Files:**
- `source/trace_api.php` - 3 matches
- `source/leather_cut_bom_api.php` - 3 matches
- `source/refs.php` - 2 matches
- `source/purchase_rfq.php` - 1 match
- `source/utils/InventoryHelper.php` - 4 matches

---

### 3. Legacy BOM Tables (`bom_line`)

#### Files Still Using Legacy BOM:

**A. `source/bom.php`**
- **References:** 16 matches
- **Usage:**
  - `lines` action: SELECT from `bom_line` (Line 473)
  - `get_line` action: SELECT from `bom_line` (Line 719)
  - `add_line`, `update_line`, `delete_line`: CRUD operations on `bom_line`
- **Action Required:** ⚠️ **CRITICAL** - `bom_line` is still the active BOM table, not legacy!
- **Note:** Need to verify if `bom_line` should be kept or migrated to new BOM structure

**B. `source/BGERP/Service/BOMService.php`**
- **References:** 6 matches
- **Usage:**
  - `getBOMLines()`: SELECT from `bom_line` (Line 212)
  - `deleteBOMLine()`: DELETE from `bom_line` (Line 230)
- **Action Required:** Same as above - verify if `bom_line` is legacy or active

**C. Other Files:**
- `source/leather_cut_bom_api.php` - 3 matches
- `source/BGERP/Helper/MaterialResolver.php` - 1 match
- `source/BGERP/Component/ComponentAllocationService.php` - 2 matches
- `source/component.php` - 1 match

---

### 4. Legacy Column References (`id_stock_item`, `id_routing`)

#### Files Still Using Legacy Columns:

**A. `id_stock_item` References:**
- `source/routing.php` - 19 matches (mostly in comments/deprecated code)
- `source/leather_grn.php` - 14 matches (dual-write)
- `source/materials.php` - 28 matches (fallback logic)
- `source/trace_api.php` - 4 matches
- `source/purchase_rfq.php` - 8 matches
- `source/BGERP/Service/ScheduleService.php` - 4 matches
- `source/service/ScheduleService.php` - 4 matches
- `source/BGERP/Service/WorkCenterCapacityCalculator.php` - 3 matches
- `source/service/CapacityCalculator.php` - 4 matches

**B. `id_routing` References:**
- `source/routing.php` - Multiple references (deprecated API)
- `source/hatthasilpa_job_ticket.php` - 1 match
- `source/BGERP/Helper/LegacyRoutingAdapter.php` - 5 matches
- `source/classic_api.php` - 2 matches
- `source/BGERP/Service/GraphInstanceService.php` - 1 match
- `source/BGERP/Service/ScheduleService.php` - 3 matches
- `source/service/ScheduleService.php` - 2 matches
- `source/BGERP/Service/WorkCenterCapacityCalculator.php` - 1 match
- `source/service/CapacityCalculator.php` - 1 match

---

## 📊 Summary Statistics

| Category | Files Affected | Total References |
|----------|---------------|------------------|
| Legacy Routing | 7 files | 13+ queries |
| Legacy Stock | 10 files | 45+ queries |
| Legacy BOM | 6 files | 29+ queries |
| Legacy Columns | 11 files | 94+ references |

---

## 🚨 Required Actions Before Task 14.2

### Phase 1: Complete Code Migration (MUST DO FIRST)

1. **Remove Legacy Routing Adapter:**
   - Migrate `hatthasilpa_job_ticket.php` to use V2 routing directly
   - Migrate `pwa_scan_api.php` to use V2 routing directly
   - Delete `LegacyRoutingAdapter.php`
   - Delete `source/routing.php` (after confirming no UI calls it)

2. **Remove Legacy Stock References:**
   - Remove dual-write logic in `leather_grn.php`
   - Remove fallback logic in `materials.php`
   - Migrate all `stock_item` JOINs to `material` table
   - Remove `id_stock_item` column from `material_lot` table

3. **Verify BOM Structure:**
   - ⚠️ **CRITICAL:** Verify if `bom_line` is legacy or active
   - If legacy: Migrate to new BOM structure
   - If active: Keep `bom_line` table (do not drop)

4. **Remove Legacy Column References:**
   - Remove all `id_stock_item` references
   - Remove all `id_routing` references (except in deprecated code)

### Phase 2: Schema Cleanup (ONLY AFTER Phase 1)

1. Drop legacy tables:
   - `routing`
   - `routing_step`
   - `stock_item`
   - `stock_item_asset`
   - `stock_item_lot`
   - (Verify `bom_line` status before dropping)

2. Drop legacy columns:
   - `material_lot.id_stock_item`
   - Any other `id_stock_item` columns
   - Any `id_routing` columns (if not needed)

---

## ⚠️ Critical Notes

### 1. BOM Line Table Status
- **Question:** Is `bom_line` legacy or active?
- **Current Usage:** Still actively used in `bom.php` and `BOMService.php`
- **Action:** Must verify with task documentation before dropping

### 2. Legacy Routing Adapter
- **Status:** Still in use by 2 files
- **Action:** Must migrate callers before deleting adapter

### 3. Dual-Write Logic
- **Status:** Still active in `leather_grn.php` and `materials.php`
- **Action:** Must remove dual-write before dropping `id_stock_item` column

---

## ⚠️ LIMITED SCOPE Condition (Updated After Task 14.1.5-14.1.6)

**Task 14.2 executed with LIMITED SCOPE because:**
- ⚠️ Dual-write patterns still active (`leather_grn.php`, `materials.php`)
- ⚠️ Legacy routing adapter still in use (`LegacyRoutingAdapter.php`)
- ⚠️ Historical routing data access needed (`routing.php`)
- ✅ READ queries migrated (Task 14.1.1-14.1.6)
- ✅ BOM pipeline uses `material` table (Task 14.1.6)
- ⚠️ `bom_line` is ACTIVE, not legacy (do not drop)

**Current Status:** ⚠️ **LIMITED SCOPE** - Documentation and preparation only

**Per task14.1.6_results.md:**
- ⛔ **DO NOT DROP** `stock_item` table (dual-write)
- ⛔ **DO NOT DROP** `id_stock_item` columns (dual-write)
- ⛔ **DO NOT DROP** routing V1 tables (adapter)
- ⛔ **DO NOT DELETE** `routing.php` (historical access)
- ⛔ **DO NOT DELETE** `LegacyRoutingAdapter.php` (backward compat)

---

## 📝 Next Steps

1. **Review this report** with team
2. **Prioritize migration tasks** (routing → stock → BOM)
3. **Create migration plan** for remaining references
4. **Execute migrations** one by one
5. **Re-scan** after each migration
6. **Proceed with Task 14.2** only after scan passes

---

**Report Generated:** 2025-12-XX (Initial)  
**Last Updated:** 2025-12-XX (After Task 14.1.5-14.1.6)  
**Scan Status:** ⚠️ LIMITED SCOPE - Legacy references intentionally kept  
**Recommendation:** 
- ✅ Task 14.2 executed with documentation only
- ⚠️ Remove dual-write patterns in future task
- ⚠️ Migrate routing V1 dependencies in future task
- ⚠️ Re-run cleanup migration after dependencies removed

**See:** `task14.2_results.md` for detailed findings and next steps

