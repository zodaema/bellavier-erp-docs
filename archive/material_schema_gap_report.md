# Material Schema Gap & Conflict Report

**Generated:** December 2025  
**Purpose:** Identify gaps, conflicts, and risks in Material Pipeline schema  
**Task:** Task 13.15 — Schema Mapping & Material Pipeline Blueprint

---

## Executive Summary

This report identifies **critical gaps and conflicts** in the Material Pipeline schema that may cause data inconsistency, FK mismatches, and integration issues. These gaps must be addressed before proceeding with Task 13.16–13.20.

---

## Critical Gaps

### Gap 1: Dual Material Master (High Priority)

**Issue:** Both `material` and `stock_item` exist with overlapping purposes.

**Current State:**
- `stock_item`: Newer table, used by GRN flow (`material_lot.id_stock_item` → `stock_item.id_stock_item`)
- `material`: Legacy table, used by legacy flows (`leather_sheet.sku_material` → `material.sku`)

**Impact:**
- **Data Inconsistency:** SKU values may differ between tables
- **Sync Issues:** No automatic synchronization mechanism
- **Confusion:** Developers unsure which table to use
- **Maintenance Burden:** Must maintain both tables

**Root Cause:**
- Legacy system used `material` table
- New system introduced `stock_item` table
- Both tables coexist without clear migration path

**Recommendation:**
1. **Short-term:** Use `stock_item` as source of truth, sync `material` manually
2. **Medium-term:** Migrate all references from `material` to `stock_item`
3. **Long-term:** Deprecate `material` table (keep for read-only legacy support)

**Risk Level:** 🔴 **HIGH** (Data inconsistency, maintenance burden)

---

### Gap 2: FK Mismatch in Leather Sheet (High Priority)

**Issue:** `leather_sheet.sku_material` references `material.sku` but should reference `stock_item.sku`.

**Current State:**
- `leather_sheet.sku_material` → `material.sku` (legacy FK, enforced)
- `leather_sheet.id_lot` → `material_lot.id_material_lot` (new FK, enforced)
- `material_lot.id_stock_item` → `stock_item.id_stock_item` (indirect path)

**Impact:**
- **Inconsistency:** Leather sheet references legacy `material` instead of `stock_item`
- **Indirect Path:** Must traverse `material_lot` to reach `stock_item`
- **Data Integrity:** If `material` record missing, leather sheet creation fails

**Root Cause:**
- Legacy FK maintained for backward compatibility
- New FK added for GRN flow (Task 13.10)
- No migration of legacy FK to new structure

**Recommendation:**
1. **Short-term:** Ensure `material` record exists for all `stock_item` records (sync)
2. **Medium-term:** Add `stock_item_sku` column to `leather_sheet` (nullable, for migration)
3. **Long-term:** Remove `sku_material` FK, use only `id_lot` → `material_lot` → `stock_item` path

**Risk Level:** 🔴 **HIGH** (FK mismatch, data integrity issues)

---

### Gap 3: String FK in BOM Line (Medium Priority)

**Issue:** `bom_line.material_sku` is a string without FK constraint.

**Current State:**
- `bom_line.material_sku`: VARCHAR(100), no FK constraint
- Should reference `stock_item.sku` or `material.sku`
- No referential integrity enforcement

**Impact:**
- **Data Integrity:** Orphaned BOM lines (SKU doesn't exist)
- **Validation:** No automatic validation of SKU existence
- **Queries:** Must manually validate SKU exists before use
- **Errors:** Runtime errors if SKU missing

**Root Cause:**
- BOM system designed before FK constraints were standardized
- String FK allows flexibility but sacrifices integrity

**Recommendation:**
1. **Short-term:** Add validation in application code (check SKU exists before BOM creation)
2. **Medium-term:** Validate existing data (ensure all `material_sku` values exist in `stock_item`)
3. **Long-term:** Add FK constraint: `bom_line.material_sku` → `stock_item.sku`

**Risk Level:** 🟡 **MEDIUM** (Data integrity, validation issues)

---

### Gap 4: Leather Sheet Creation Failure (High Priority)

**Issue:** Leather sheet creation fails if `material` record doesn't exist.

**Current State:**
- `leather_sheet.sku_material` → `material.sku` (FK enforced, RESTRICT)
- If `material` record missing, `leather_sheet` creation fails
- GRN flow may fail if `material` not synced with `stock_item`

**Impact:**
- **GRN Failure:** Leather GRN flow fails if `material` record missing
- **User Experience:** Confusing error messages
- **Workaround:** Must manually create `material` record before GRN

**Root Cause:**
- Legacy FK dependency
- No auto-creation of `material` record during GRN

**Recommendation:**
1. **Short-term:** Auto-create `material` record if missing during GRN (sync with `stock_item`)
2. **Medium-term:** Remove `sku_material` FK dependency
3. **Long-term:** Use only `id_lot` → `material_lot` → `stock_item` path

**Risk Level:** 🔴 **HIGH** (GRN flow failure, user experience)

---

### Gap 5: CUT Pipeline Material Master Access (Medium Priority)

**Issue:** CUT pipeline doesn't have direct access to material master data (color, type, etc.).

**Current State:**
- CUT behavior resolves material SKU from token → product → BOM → `bom_line.material_sku`
- `bom_line.material_sku` is string, no direct link to `stock_item` or `material`
- Must query `stock_item` or `material` separately to get material attributes

**Impact:**
- **Performance:** Extra queries to get material attributes
- **Data Access:** No direct FK path to material master
- **Consistency:** Material attributes may be stale or missing

**Root Cause:**
- `bom_line.material_sku` is string without FK
- No direct link to material master tables

**Recommendation:**
1. **Short-term:** Query `stock_item` by SKU string match (current approach)
2. **Medium-term:** Add FK constraint to `bom_line.material_sku`
3. **Long-term:** Denormalize material attributes in `bom_line` (if needed for performance)

**Risk Level:** 🟡 **MEDIUM** (Performance, data access)

---

### Gap 6: DAG Behavior Material SKU Mapping (Low Priority)

**Issue:** DAG behavior needs `material_sku` but no direct mapping exists.

**Current State:**
- DAG behavior (CUT) needs material SKU for sheet selection
- MaterialResolver (Task 13.13) traverses: token → job_ticket → product → BOM → `bom_line.material_sku`
- No direct FK path, relies on string matching

**Impact:**
- **Performance:** Multiple joins to resolve material SKU
- **Reliability:** String matching may fail if SKU format differs
- **Maintenance:** Complex resolution logic

**Root Cause:**
- No direct FK from token to material
- Must traverse multiple tables to resolve SKU

**Recommendation:**
1. **Short-term:** Use MaterialResolver (current approach, Task 13.13)
2. **Medium-term:** Cache material SKU in token metadata (if needed)
3. **Long-term:** Consider denormalizing material SKU in token (if performance critical)

**Risk Level:** 🟢 **LOW** (Performance, complexity)

---

### Gap 7: QC Policy JSON Artifact (Resolved)

**Issue:** `routing_node.qc_policy` stored as `'0'` (string) instead of valid JSON.

**Current State:**
- **RESOLVED** (Task 13.15 fix)
- Normalization block added to ensure valid JSON
- Default policy auto-fill for QC nodes
- SQL cleanup script provided

**Impact:**
- **RESOLVED:** No longer an issue

**Root Cause:**
- Legacy data stored as `'0'` (string)
- MySQL JSON column requires valid JSON

**Recommendation:**
- ✅ **COMPLETED:** Normalization and cleanup implemented

**Risk Level:** ✅ **RESOLVED**

---

## Conflicts

### Conflict 1: Material SKU Ownership

**Issue:** Both `material` and `stock_item` claim ownership of material SKU.

**Current State:**
- `material.sku`: Legacy SKU (unique constraint)
- `stock_item.sku`: New SKU (unique constraint)
- Both may have same SKU values (no enforced relationship)

**Impact:**
- **Confusion:** Which table is the source of truth?
- **Sync Issues:** SKU values may diverge
- **Maintenance:** Must keep both tables in sync

**Resolution:**
- **Declare:** `stock_item.sku` is the source of truth
- **Action:** Sync `material.sku` with `stock_item.sku` (manual or automated)
- **Future:** Deprecate `material` table

---

### Conflict 2: Leather Sheet FK Path

**Issue:** `leather_sheet` has dual FK paths (legacy and new).

**Current State:**
- Legacy: `leather_sheet.sku_material` → `material.sku`
- New: `leather_sheet.id_lot` → `material_lot.id_material_lot` → `stock_item.id_stock_item`

**Impact:**
- **Complexity:** Two FK paths to material
- **Inconsistency:** Legacy FK may point to different material than new FK
- **Maintenance:** Must maintain both paths

**Resolution:**
- **Short-term:** Ensure both paths point to same material (sync)
- **Medium-term:** Remove legacy FK, use only new FK path
- **Long-term:** Single FK path via `id_lot`

---

## Risk Points

### Risk 1: Data Inconsistency

**Description:** Material SKU values may differ between `material` and `stock_item`.

**Probability:** 🟡 **MEDIUM**  
**Impact:** 🔴 **HIGH**

**Mitigation:**
- Implement sync mechanism (manual or automated)
- Validate SKU consistency during GRN
- Add data validation checks

---

### Risk 2: GRN Flow Failure

**Description:** Leather GRN flow fails if `material` record doesn't exist.

**Probability:** 🟡 **MEDIUM**  
**Impact:** 🔴 **HIGH**

**Mitigation:**
- Auto-create `material` record if missing during GRN
- Add validation before GRN creation
- Provide clear error messages

---

### Risk 3: Orphaned BOM Lines

**Description:** BOM lines may reference non-existent material SKUs.

**Probability:** 🟢 **LOW**  
**Impact:** 🟡 **MEDIUM**

**Mitigation:**
- Add validation in application code
- Validate existing data
- Add FK constraint (long-term)

---

### Risk 4: Performance Issues

**Description:** Multiple joins required to resolve material SKU in CUT pipeline.

**Probability:** 🟢 **LOW**  
**Impact:** 🟡 **MEDIUM**

**Mitigation:**
- Use MaterialResolver (current approach)
- Cache material SKU if needed
- Consider denormalization (if performance critical)

---

## Recommendations Summary

### Immediate Actions (Before Task 13.16)

1. ✅ **SQL Cleanup:** Run cleanup script for `qc_policy` JSON artifacts
2. 🔴 **Sync Material Tables:** Ensure `material.sku` matches `stock_item.sku` for all records
3. 🔴 **Auto-Create Material:** Add auto-creation of `material` record during GRN (if missing)
4. 🟡 **Validate BOM Lines:** Validate all `bom_line.material_sku` values exist in `stock_item`

### Short-Term Actions (Task 13.16–13.17)

1. 🟡 **Add FK Constraint:** Add FK constraint to `bom_line.material_sku` → `stock_item.sku`
2. 🟡 **Update Leather Sheet:** Add `stock_item_sku` column to `leather_sheet` (nullable, for migration)
3. 🟡 **Sync Mechanism:** Implement automatic sync between `material` and `stock_item`

### Long-Term Actions (Task 13.18–13.20)

1. 🔴 **Migrate References:** Migrate all references from `material` to `stock_item`
2. 🔴 **Remove Legacy FK:** Remove `leather_sheet.sku_material` FK to `material`
3. 🔴 **Deprecate Material:** Deprecate `material` table (keep for read-only legacy support)

---

## Priority Matrix

| Gap | Priority | Risk Level | Action Required |
|-----|----------|------------|-----------------|
| Gap 1: Dual Material Master | 🔴 HIGH | 🔴 HIGH | Sync mechanism, migration plan |
| Gap 2: FK Mismatch in Leather Sheet | 🔴 HIGH | 🔴 HIGH | Remove legacy FK, use new FK path |
| Gap 3: String FK in BOM Line | 🟡 MEDIUM | 🟡 MEDIUM | Add FK constraint, validate data |
| Gap 4: Leather Sheet Creation Failure | 🔴 HIGH | 🔴 HIGH | Auto-create material record |
| Gap 5: CUT Pipeline Material Access | 🟡 MEDIUM | 🟡 MEDIUM | Add FK constraint, optimize queries |
| Gap 6: DAG Behavior Material Mapping | 🟢 LOW | 🟢 LOW | Use MaterialResolver (current) |
| Gap 7: QC Policy JSON Artifact | ✅ RESOLVED | ✅ RESOLVED | ✅ Completed |

---

## Conclusion

The Material Pipeline schema has **several critical gaps** that must be addressed before proceeding with Task 13.16–13.20. The most critical issues are:

1. **Dual Material Master** (Gap 1)
2. **FK Mismatch in Leather Sheet** (Gap 2)
3. **Leather Sheet Creation Failure** (Gap 4)

These gaps should be addressed **immediately** to ensure data consistency and prevent GRN flow failures.

---

**End of Gap & Conflict Report**

