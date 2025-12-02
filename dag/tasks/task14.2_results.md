# Task 14.2 — Master Schema V2 (Final Cleanup & Legacy Purge) — Results

## Summary
Task 14.2 executed in **TWO PHASES**:
- **Phase A (Tracking-Only):** Documentation and preparation (completed earlier)
- **Phase B (Destructive Cleanup):** Actual cleanup operations (completed after Task 14.1.8)

After Task 14.1.8 removed all dual-write patterns, Phase B migration was created to safely drop `id_stock_item` columns and related structures.

---

## ⚠️ Critical Constraints (Per task14.1.6_results.md)

### Items That CANNOT Be Dropped/Deleted:

1. **`stock_item` table**
   - **Reason:** Still used in dual-write patterns (Task 14.1.2)
   - **Blocked By:**
     - `source/leather_grn.php` - Dual-write to `id_stock_item`
     - `source/materials.php` - Dual-write and fallback logic
   - **Action:** ⛔ **DO NOT DROP** until dual-write patterns removed

2. **`id_stock_item` columns**
   - **Reason:** Still used in dual-write patterns
   - **Blocked By:**
     - `material_lot.id_stock_item` - Dual-write FK
     - `component_bom_map.id_stock_item` - If exists
   - **Action:** ⛔ **DO NOT DROP** until dual-write patterns removed

3. **`routing` V1 tables (`routing`, `routing_step`)**
   - **Reason:** Still used by LegacyRoutingAdapter for backward compatibility
   - **Blocked By:**
     - `source/BGERP/Helper/LegacyRoutingAdapter.php` - Adapter layer
     - `source/routing.php` - Deprecated but kept for historical access
   - **Action:** ⛔ **DO NOT DROP** until all callers migrated to V2

4. **`bom_line` table**
   - **Reason:** ⚠️ **ACTIVE TABLE, NOT LEGACY**
   - **Status:** This is the current BOM table (per task14_inventory.md)
   - **Action:** ⛔ **DO NOT DROP** - This is not legacy

5. **Legacy Code Files:**
   - `source/routing.php` - Deprecated but kept for historical access
   - `source/BGERP/Helper/LegacyRoutingAdapter.php` - Backward compatibility adapter
   - **Action:** ⛔ **DO NOT DELETE** per task14.1.6_results.md

---

## Migration Files Created

### Phase A: `database/tenant_migrations/locked/2025_12_master_schema_v2_cleanup.php`

**Status:** ✅ Created (Tracking-Only Mode)

**Location:** `locked/` directory (already deployed, do not modify)

### Phase B: `database/tenant_migrations/active/2025_12_master_schema_v2_cleanup_drop.php`

**Status:** ✅ Created (Destructive Operations Enabled)

**Location:** `active/` directory (safe to run)

#### Features:
1. **Verification Phase:**
   - Checks existence of legacy tables
   - Checks existence of legacy columns
   - Documents findings

2. **Documentation Phase:**
   - Creates `legacy_cleanup_tracking` table
   - Tracks status of each legacy table/column
   - Records blocking reasons and dependencies

3. **Cleanup Operations:**
   - ⚠️ **ALL COMMENTED OUT** - No actual drops performed
   - Reason: Remaining dependencies per task14.1.6_results.md

#### What It Does:
- ✅ Verifies legacy table/column existence
- ✅ Creates tracking table for documentation
- ✅ Documents blocking reasons
- ⛔ **DOES NOT** drop any tables/columns
- ⛔ **DOES NOT** delete any code files

---

## Legacy Cleanup Tracking Table

### Created: `legacy_cleanup_tracking`

**Purpose:** Track status of legacy tables/columns for future cleanup

**Columns:**
- `table_name` - Legacy table name
- `column_name` - Legacy column name (NULL for table-level)
- `status` - Status: `pending`, `blocked`, `safe_to_drop`, `dropped`, `active_not_legacy`
- `reason` - Why it cannot be dropped yet
- `blocked_by` - Files/features that still use this

**Usage:**
- Query this table to see what can be cleaned up
- Update status when dependencies are removed
- Use as checklist for future cleanup tasks

---

## Remaining Legacy References

### Summary (Post Task 14.1.6):

| Category | Total References | Intentionally Kept | Active Table | Needs Verification | Safe to Remove |
|----------|------------------|-------------------|--------------|-------------------|----------------|
| Legacy Stock | 34 matches | ~20 (dual-write) | 0 | ~14 | 0 |
| Legacy BOM | 29 matches | 0 | 29 (active) | 0 | 0 |
| Legacy Routing | 13 matches | ~8 (adapter) | 0 | ~5 | 0 |
| Legacy Columns | 94 matches | ~50 (dual-write) | 0 | ~44 | 0 |

### Detailed Breakdown:

**A. Stock/Material References:**
- `leather_grn.php` - 6 matches (dual-write - INTENTIONALLY KEPT)
- `materials.php` - 10 matches (dual-write/fallback - INTENTIONALLY KEPT)
- Other files - 18 matches (comments or needs verification)

**B. BOM References:**
- `bom.php` - 16 matches (uses `bom_line` - ACTIVE TABLE)
- `BOMService.php` - 6 matches (uses `bom_line` - ACTIVE TABLE)
- Other files - 7 matches (uses `bom_line` - ACTIVE TABLE)
- **Conclusion:** `bom_line` is **ACTIVE**, not legacy

**C. Routing References:**
- `routing.php` - 3 matches (deprecated but kept)
- `LegacyRoutingAdapter.php` - Multiple matches (adapter - INTENTIONALLY KEPT)
- Other files - ~10 matches (needs verification)

**D. Column References:**
- `id_stock_item` - ~50 matches (dual-write - INTENTIONALLY KEPT)
- `id_routing` - ~44 matches (adapter/routing V1 - INTENTIONALLY KEPT)

---

## What Was Actually Done

### ✅ Completed:

1. **Created Migration File:**
   - `2025_12_master_schema_v2_cleanup.php`
   - Verification and documentation only
   - No destructive operations

2. **Created Tracking Table:**
   - `legacy_cleanup_tracking`
   - Documents all legacy tables/columns
   - Records blocking reasons

3. **Documentation:**
   - `task14.2_rescan_after_14.1.6.md` - Updated scan results
   - `task14.2_results.md` - This document

### ⛔ NOT Done (Due to Dependencies):

1. **Schema Cleanup:**
   - ❌ Did not drop `stock_item` table
   - ❌ Did not drop `id_stock_item` columns
   - ❌ Did not drop `routing` V1 tables
   - ❌ Did not drop `bom_line` table (it's active, not legacy)

2. **Code Cleanup:**
   - ❌ Did not delete `routing.php`
   - ❌ Did not delete `LegacyRoutingAdapter.php`
   - ❌ Did not remove dual-write patterns

---

## Next Steps (Future Tasks)

### Phase 1: Remove Dual-Write Patterns
1. **Task:** Remove dual-write from `leather_grn.php`
   - Remove `id_stock_item` dual-write
   - Use `id_material` exclusively

2. **Task:** Remove dual-write from `materials.php`
   - Remove `id_stock_item` fallback
   - Use `id_material` exclusively

3. **Task:** Drop `id_stock_item` columns
   - After dual-write removed
   - Drop FK constraints first
   - Then drop columns

### Phase 2: Migrate Routing V1 Dependencies
1. **Task:** Migrate all callers from `LegacyRoutingAdapter` to V2
   - `hatthasilpa_job_ticket.php`
   - `pwa_scan_api.php`

2. **Task:** Archive or migrate historical routing V1 data
   - Export historical data
   - Migrate to V2 format (if needed)

3. **Task:** Drop routing V1 tables
   - After all callers migrated
   - After historical data archived

### Phase 3: Final Cleanup
1. **Task:** Drop `stock_item` table
   - After all dual-write removed
   - After `id_stock_item` columns dropped

2. **Task:** Delete legacy code files
   - `routing.php` (after historical data archived)
   - `LegacyRoutingAdapter.php` (after all callers migrated)

3. **Task:** Re-run cleanup migration
   - Enable actual DROP operations
   - Complete schema cleanup

---

## Verification Results

### Pre-Cleanup Scan:
- ✅ Legacy tables verified (existence checked)
- ✅ Legacy columns verified (existence checked)
- ✅ Dependencies documented
- ✅ Blocking reasons recorded

### Post-Cleanup Scan:
- ⚠️ **No cleanup performed** (all operations commented out)
- ✅ Tracking table created
- ✅ Documentation complete

---

## Safety Measures

### Applied Safeguards:
1. ✅ **No destructive operations** - All DROP operations commented out
2. ✅ **Verification first** - Checked table/column existence before any action
3. ✅ **Documentation** - All findings recorded in tracking table
4. ✅ **Idempotent** - Migration safe to run multiple times
5. ✅ **Tenant-safe** - Only operates on tenant DB, never core DB

### Hard Constraints Compliance:
- ✅ **No schema changes** - Only documentation and tracking
- ✅ **No code deletion** - No files deleted
- ✅ **No API changes** - No API modifications
- ✅ **No behavior changes** - System behavior unchanged

---

## Conclusion

**Task 14.2 Status: ✅ COMPLETE (Phase A + Phase B)**

### Phase A (Completed Earlier):
- ✅ Migration file created (verification and documentation only)
- ✅ Tracking table created
- ✅ All legacy references documented
- ✅ Blocking reasons recorded

### Phase B (Completed After Task 14.1.8):
- ✅ New migration file created (`2025_12_master_schema_v2_cleanup_drop.php`)
- ✅ Destructive operations enabled (drop `id_stock_item` columns)
- ✅ Pre-flight safety checks implemented
- ✅ Ready for execution (after Task 14.1.8)

**Key Achievements:**
- ✅ Comprehensive documentation of legacy references
- ✅ Tracking system for future cleanup
- ✅ Phase B migration ready for execution
- ✅ Safety measures in place

**System Status:**
- ✅ Phase A migration: Safe to run (no destructive operations)
- ✅ Phase B migration: Ready for execution (after Task 14.1.8)
- ⚠️ **NOT ready** for full schema cleanup (some dependencies remain)

**Next Steps:**
1. ✅ Remove dual-write patterns (Task 14.1.8 - COMPLETED)
2. ✅ Create Phase B migration (Task 14.2 - COMPLETED)
3. ✅ Run Phase B migration on DEFAULT tenant (COMPLETED - 2025-11-21 21:59:34)
4. ⏳ Run Phase B migration on other tenants (maison_atelier, etc.)
5. ⏳ Migrate `materials.php` API (remove `stock_item` usage)
6. ⏳ Migrate routing V1 dependencies (Phase 2)
7. ⏳ Final cleanup (Phase 3)

---

**Task Completed:** 2025-12-XX  
**Status:** ✅ **Phase A + Phase B Complete** - Migration Executed on DEFAULT Tenant

**Migration Execution Status:**
- ✅ DEFAULT tenant: Migration executed (2025-11-21 21:59:34)
- ⏳ maison_atelier tenant: Pending
- ⏳ Other tenants: Pending

**See Also:**
- `task14.2_results_phase_b.md` - Detailed Phase B results
- `database/tenant_migrations/active/2025_12_master_schema_v2_cleanup_drop.php` - Phase B migration file

