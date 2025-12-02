# Task 14.1 — UI Scan Results

**Date:** December 2025  
**Phase:** 14.1 — Deep System Scan  
**Status:** ✅ COMPLETED

---

## Summary

This document identifies UI pages that link to legacy APIs or use legacy schema references.

---

## UI Files Scanned

**Total UI Files:** 63 files in `views/` directory

---

## Legacy UI Pages Found

### 1. `views/routing.php` — Legacy Routing UI

**Status:** ⚠️ **LEGACY UI**

**Details:**
- Line 47: `window.RoutingConfig = { endpoint: 'source/routing.php' }`
- **API Used:** `source/routing.php` (legacy routing API)
- **Legacy Table:** Uses `routing` (V1) table
- **Risk:** HIGH — Legacy routing UI depends on V1 routing

**Action Required:**
- Option A: Migrate to use `routing_graph` (V2) API
- Option B: Mark as Legacy UI and deprecate
- Document that this is legacy routing UI

---

### 2. `views/bom.php` — BOM UI (Partial Legacy)

**Status:** ⚠️ **PARTIAL LEGACY REFERENCES**

**Details:**
- Line 84: `id="bom_lines_id_bom"` — References `bom_line` structure
- Line 85: `id="bom_line_id"` — References `bom_line` ID
- Line 187: `id="ebl_id_bom_line"` — References `bom_line` ID
- **Legacy Table:** References `bom_line` (V1) in UI
- **Risk:** MEDIUM — UI references legacy BOM structure

**Note:**
- The BOM API (`source/bom.php`) uses BOMService which uses V2 (`bom` + `bom_item`)
- But UI still has references to `bom_line` structure
- May be legacy UI code that needs cleanup

**Action Required:**
- Update UI to use V2 BOM structure (`bom` + `bom_item`)
- Remove `bom_line` references from UI

---

### 3. `views/uom.php` — UOM UI

**Status:** ✅ **USES V2 API**

**Details:**
- Line 45: `window.UomConfig = { endpoint: 'source/uom.php' }`
- **API Used:** `source/uom.php`
- **Table Used:** `unit_of_measure` (V2) ✅
- **Risk:** NONE — Uses V2 API correctly

**Conclusion:**
- ✅ UOM UI is **safe** — Uses V2 API (`unit_of_measure`)
- ✅ No action required

---

## V2 UI Pages (Current)

### Routing V2 UI
- ✅ `views/routing_graph_designer.php` — DAG Graph Designer (V2)
- ✅ `views/routing_graph_designer_toolbar_v2.php` — Graph Designer Toolbar (V2)
- ✅ `views/routing_graph_help.php` — Graph Designer Help (V2)

**Status:** ✅ **USES V2** — All routing V2 UI uses `routing_graph` (V2)

---

### Stock/Material V2 UI
- ✅ `views/stock_card.php` — Stock Card (uses `stock_ledger` V2)
- ✅ `views/stock_on_hand.php` — Stock On Hand (uses V2)
- ✅ `views/materials.php` — Materials (uses `material` V2)
- ✅ `views/leather_grn.php` — Leather GRN (uses V2, but also reads V1)

**Status:** ✅ **USES V2** — Stock/Material UI uses V2 tables

---

### BOM V2 UI
- ✅ `views/bom.php` — BOM UI (uses V2 API, but has legacy references)
- ✅ `views/bom_tree.php` — BOM Tree (uses V2)

**Status:** ⚠️ **PARTIAL** — BOM UI uses V2 API but has legacy references

---

## UI Pages Using Legacy APIs

| UI Page | Legacy API | Legacy Table | Risk | Action |
|---------|------------|--------------|------|--------|
| `views/routing.php` | `source/routing.php` | `routing` (V1) | HIGH | Migrate or deprecate |
| `views/bom.php` | (uses V2 API) | `bom_line` (UI refs) | MEDIUM | Clean up UI references |

---

## Recommendations

### For UI Cleanup

1. **Migrate `views/routing.php`:**
   - Option A: Update to use `routing_graph` (V2) API
   - Option B: Mark as Legacy UI and deprecate
   - Document migration path

2. **Clean up `views/bom.php`:**
   - Remove `bom_line` references from UI
   - Update to use V2 BOM structure (`bom` + `bom_item`)
   - Ensure UI matches V2 API structure

3. **Verify Other UI Pages:**
   - Check if any other UI pages reference legacy tables
   - Update documentation if found

---

**Document Status:** ✅ Complete  
**Last Updated:** December 2025

