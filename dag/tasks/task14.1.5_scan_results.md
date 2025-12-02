# Task 14.1.5 — Targeted Legacy Reference Cleanup (Wave A) — Scan Results

## Summary
This document provides the current state of legacy references in the codebase after Task 14.1.1-14.1.4, focusing on READ-only files that can be safely migrated in Wave A.

---

## Phase 0: Re-Scan Results

### Files Scanned (Group A/B/C)

#### A. Stock / Material (Read-Only)

**1. `source/trace_api.php`**
- **Status:** ✅ Already migrated (Task 14.1.1)
- **Legacy References:** None
- **Current Usage:** Uses `material` table exclusively
- **Action:** No changes needed

**2. `source/leather_cut_bom_api.php`**
- **Status:** ⚠️ Partially migrated
- **Legacy References:**
  - Line 164: `LEFT JOIN stock_item si ON si.sku = bl.material_sku` (fallback pattern)
  - Line 157-158: `COALESCE(m.name, si.description)` and `COALESCE(m.category, si.material_type)` (fallback)
- **Action Required:** Remove `stock_item` fallback JOIN, use `material` only
- **Risk Level:** LOW (read-only query, fallback can be removed)

**3. `source/BGERP/Helper/MaterialResolver.php`**
- **Status:** ✅ Already migrated (Task 14.1.1)
- **Legacy References:** None
- **Current Usage:** Uses `material` table exclusively
- **Action:** No changes needed

---

#### B. BOM / Component (Read-Only)

**1. `source/component.php`**
- **Status:** ⚠️ Uses `bom_line` (active table, not legacy)
- **Legacy References:**
  - Line 355: `LEFT JOIN bom_line bl ON bl.id_bom_line = cbm.id_bom_line`
- **Action Required:** ⚠️ **VERIFY** - Is `bom_line` legacy or active?
  - Current understanding: `bom_line` is still the active BOM table
  - If active: No action needed
  - If legacy: Need to migrate to new BOM structure
- **Risk Level:** MEDIUM (need to verify table status)

**2. `source/BGERP/Component/ComponentAllocationService.php`**
- **Status:** ⚠️ Needs verification
- **Action Required:** Scan for legacy references (not yet scanned in detail)
- **Risk Level:** MEDIUM (component allocation logic)

---

#### C. Routing (Read-Only / Debug / Helper)

**1. `source/routing.php`**
- **Status:** ⚠️ Deprecated but still exists (Task 14.1.3)
- **Legacy References:**
  - Multiple queries to `routing` and `routing_step` tables
  - All write operations disabled (410 Gone)
  - Only READ operations allowed
- **Action Required:** 
  - ⚠️ **DO NOT DELETE** - Still used for historical data access
  - Add deprecation comments if not already present
  - Document that this file is read-only
- **Risk Level:** LOW (read-only, already deprecated)

**2. `source/BGERP/Helper/LegacyRoutingAdapter.php`**
- **Status:** ⚠️ Still in use (Task 14.1.3)
- **Legacy References:**
  - Queries to `routing` and `routing_step` tables (V1 fallback)
  - Used by: `hatthasilpa_job_ticket.php`, `pwa_scan_api.php`
- **Action Required:**
  - ⚠️ **DO NOT DELETE** - Still needed for backward compatibility
  - Can add comments/documentation about deprecation
  - Tidy up code if needed (but keep functionality)
- **Risk Level:** LOW (adapter layer, safe to keep)

---

## Summary Statistics

| Category | Files | Status | Action Required |
|----------|-------|--------|-----------------|
| Stock/Material (Read-Only) | 3 | 2 migrated, 1 partial | Remove fallback in `leather_cut_bom_api.php` |
| BOM/Component (Read-Only) | 2 | Needs verification | Verify `bom_line` status |
| Routing (Read-Only) | 2 | Deprecated/Adapter | Document, no deletion |

---

## Safe Migration Targets (Wave A)

### ✅ Ready to Migrate

1. **`source/leather_cut_bom_api.php`** (Line 164)
   - Remove `LEFT JOIN stock_item si` fallback
   - Use `material` table only
   - Risk: LOW (read-only query)

### ⚠️ Needs Verification

1. **`source/component.php`**
   - Verify if `bom_line` is legacy or active
   - If active: No action
   - If legacy: Migrate to new BOM structure

2. **`source/BGERP/Component/ComponentAllocationService.php`**
   - Scan for legacy references
   - Assess migration feasibility

### ⛔ Do Not Touch

1. **`source/routing.php`**
   - Keep for historical data access
   - Already deprecated (read-only)

2. **`source/BGERP/Helper/LegacyRoutingAdapter.php`**
   - Keep for backward compatibility
   - Still used by 2 files

---

## Migration Plan (Wave A)

### Phase 1: Low-Risk READ Queries

1. **Migrate `leather_cut_bom_api.php`**
   - Remove `stock_item` fallback JOIN
   - Use `material` table only
   - Test: Verify BOM lines still load correctly

### Phase 2: Verification & Documentation

1. **Verify `bom_line` status**
   - Check if `bom_line` is legacy or active
   - Document findings

2. **Update documentation**
   - Mark files as migrated
   - Document remaining legacy references

---

## Notes

- **`bom_line` table:** Need to verify if this is legacy or active before any migration
- **`routing.php`:** Keep for historical access, already deprecated
- **`LegacyRoutingAdapter.php`:** Keep for backward compatibility, still in use

---

**Scan Date:** 2025-12-XX  
**Status:** Ready for Wave A migration (1 file ready, 2 need verification)

