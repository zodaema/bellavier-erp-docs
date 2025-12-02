# Task 14.1 — Source Code Deep Scan Results

**Date:** December 2025  
**Phase:** 14.1 — Deep System Scan  
**Status:** ✅ COMPLETED

---

## Summary

This document contains the results of deep scanning source code for references to legacy (V1) tables: `uom`, `stock_item*`, `bom_line`, and legacy `routing`.

---

## 1. Legacy Table: `uom`

### Files Using `uom` Table

**Status:** ✅ **NO DIRECT REFERENCES FOUND**

**Analysis:**
- The file `source/uom.php` uses `unit_of_measure` (V2), NOT `uom` (V1)
- All queries in `uom.php` reference `unit_of_measure` table
- No code found that directly queries the legacy `uom` table

**Files Checked:**
- ✅ `source/uom.php` — Uses `unit_of_measure` (V2) ✅
- ✅ `source/bom.php` — Uses `unit_of_measure` (V2) ✅

**Conclusion:**
- ✅ **SAFE TO DEPRECATE** — No code references legacy `uom` table
- The `uom` table can be safely excluded from Master Schema V2

---

## 2. Legacy Tables: `stock_item*`

### Files Using `stock_item` Table

**Status:** ⚠️ **ACTIVE REFERENCES FOUND**

**Files with References:**

1. **`source/leather_grn.php`** (4 references)
   - Line 100: `FROM stock_item si`
   - Line 174: `FROM stock_item`
   - Line 280: Comment mentions `stock_item`
   - Line 526: `INNER JOIN stock_item si ON si.id_stock_item = ml.id_stock_item`
   - **Risk:** HIGH — Leather GRN actively uses `stock_item`
   - **Action Required:** Migrate to `material` table

2. **`source/leather_cut_bom_api.php`** (1 reference)
   - Line 159: `LEFT JOIN stock_item si ON si.sku = bl.material_sku`
   - **Risk:** MEDIUM — CUT BOM uses `stock_item` for material lookup
   - **Action Required:** Migrate to `material` table

3. **`source/BGERP/Helper/MaterialResolver.php`** (1 reference)
   - Line 205: `LEFT JOIN stock_item si ON si.sku = bl.material_sku`
   - **Risk:** HIGH — Core helper class uses `stock_item`
   - **Action Required:** Migrate to `material` table

4. **`source/trace_api.php`** (2 references)
   - Line 1774: `LEFT JOIN stock_item si ON si.id_stock_item = iti.id_stock_item`
   - Line 2682: `LEFT JOIN stock_item si ON si.id_stock_item = iti.id_stock_item`
   - **Risk:** MEDIUM — Trace API uses `stock_item`
   - **Action Required:** Migrate to `material` table

5. **`source/bom.php`** (3 references)
   - Line 127: `LEFT JOIN stock_item si ON si.sku = bl.material_sku`
   - Line 227: `LEFT JOIN stock_item si ON si.sku = bl.material_sku`
   - Line 439: `SELECT sku, description, quantity FROM stock_item ORDER BY sku ASC LIMIT 2000`
   - **Risk:** HIGH — BOM API uses `stock_item` for material lookup
   - **Action Required:** Migrate to `material` table

**Summary:**
- **Total Files:** 5 files
- **Total References:** 11 references
- **Risk Level:** HIGH — Multiple critical systems use `stock_item`
- **Action:** Must migrate to `material` table before deprecating `stock_item`

---

## 3. Legacy Table: `bom_line`

### Files Using `bom_line` Table

**Status:** ⚠️ **ACTIVE REFERENCES FOUND**

**Files with References:**

1. **`source/leather_cut_bom_api.php`** (4 references)
   - Line 158: `FROM bom_line bl`
   - Line 178: Comment mentions `bom_line`
   - Line 264: `FROM bom_line bl`
   - Line 428: `FROM bom_line bl`
   - **Risk:** HIGH — CUT BOM API actively uses `bom_line`
   - **Action Required:** Migrate to `bom` + `bom_item` structure

2. **`source/BGERP/Helper/MaterialResolver.php`** (1 reference)
   - Line 204: `FROM bom_line bl`
   - **Risk:** HIGH — Core helper class uses `bom_line`
   - **Action Required:** Migrate to `bom` + `bom_item`

3. **`source/BGERP/Component/ComponentAllocationService.php`** (1 reference)
   - Line 582: `LEFT JOIN bom_line bl ON bl.id_bom_line = cbm.id_bom_line`
   - **Risk:** MEDIUM — Component allocation uses `bom_line`
   - **Action Required:** Migrate to `bom` + `bom_item`

4. **`source/component.php`** (1 reference)
   - Line 355: `LEFT JOIN bom_line bl ON bl.id_bom_line = cbm.id_bom_line`
   - **Risk:** MEDIUM — Component API uses `bom_line`
   - **Action Required:** Migrate to `bom` + `bom_item`

5. **`source/bom.php`** (1 reference)
   - Line 126: `FROM bom_line bl`
   - **Risk:** HIGH — BOM API uses `bom_line`
   - **Action Required:** Migrate to `bom` + `bom_item`

**Summary:**
- **Total Files:** 5 files
- **Total References:** 8 references
- **Risk Level:** HIGH — Multiple critical systems use `bom_line`
- **Action:** Must migrate to `bom` + `bom_item` before deprecating `bom_line`

---

## 4. Legacy Table: `routing` (V1)

### Files Using Legacy `routing` Table

**Status:** ⚠️ **ACTIVE REFERENCES FOUND**

**Files with References:**

1. **`source/hatthasilpa_job_ticket.php`** (2 references)
   - Line 1091: `SELECT id_routing FROM routing WHERE id_product=? AND is_active=1`
   - Line 1188: `SELECT id_routing, version FROM routing WHERE id_product=? AND is_active=1`
   - **Risk:** HIGH — Job ticket creation uses legacy `routing`
   - **Action Required:** Migrate to `routing_graph` (V2)

2. **`source/pwa_scan_api.php`** (2 references)
   - Line 1128: `FROM routing r`
   - Line 1570: `FROM routing r`
   - **Risk:** MEDIUM — PWA scan API uses legacy `routing`
   - **Action Required:** Migrate to `routing_graph` (V2)

3. **`source/routing.php`** (3 references)
   - Line 206: `FROM routing r`
   - Line 277: `INSERT INTO routing (id_product, version)`
   - Line 330: `DELETE FROM routing WHERE id_routing = ?`
   - **Risk:** HIGH — Routing API actively uses legacy `routing` table
   - **Action Required:** Migrate to `routing_graph` (V2)

**Note:** `source/classic_api.php` and `source/BGERP/Service/GraphInstanceService.php` reference routing but use V2 (`routing_graph`), not legacy `routing`.

**Summary:**
- **Total Files:** 3 files
- **Total References:** 7 references
- **Risk Level:** HIGH — Job ticket and routing APIs use legacy `routing`
- **Action:** Must migrate to `routing_graph` (V2) before deprecating `routing`

---

## 5. Legacy Column Patterns

### Old Column Names Found

**Pattern:** `material_sku`, `qty_sqft`, `routing_id`

**Status:** ⚠️ **SOME REFERENCES FOUND**

1. **`material_sku` in `bom_line`:**
   - Used in: `leather_cut_bom_api.php`, `MaterialResolver.php`, `bom.php`
   - **Action:** Migrate to `bom_item.material_sku` or use `material.sku` directly

2. **`routing_id` references:**
   - Found in legacy `routing` table usage
   - **Action:** Migrate to `routing_graph.id_graph`

---

## Risk Assessment Summary

### High Risk (Must Fix Before Deprecation)

1. **`stock_item`** — 5 files, 11 references
   - Leather GRN, CUT BOM, Material Resolver, Trace API, BOM API
   - **Impact:** CRITICAL — Core material pipeline depends on this

2. **`bom_line`** — 5 files, 8 references
   - CUT BOM API, Material Resolver, Component Allocation, BOM API
   - **Impact:** CRITICAL — BOM system depends on this

3. **`routing` (V1)** — 3 files, 7 references
   - Job Ticket, PWA Scan, Routing API
   - **Impact:** HIGH — Job ticket creation depends on this

### Low Risk (Safe to Deprecate)

1. **`uom`** — 0 direct references
   - **Impact:** NONE — All code uses `unit_of_measure` (V2)

---

## Recommendations

### Before Deprecating V1 Tables

1. **Migrate `stock_item` → `material`:**
   - Update `leather_grn.php` to use `material` table
   - Update `MaterialResolver.php` to use `material` table
   - Update `bom.php` to use `material` table
   - Update `trace_api.php` to use `material` table
   - Update `leather_cut_bom_api.php` to use `material` table

2. **Migrate `bom_line` → `bom` + `bom_item`:**
   - Update `leather_cut_bom_api.php` to use `bom_item`
   - Update `MaterialResolver.php` to use `bom_item`
   - Update `ComponentAllocationService.php` to use `bom_item`
   - Update `component.php` to use `bom_item`
   - Update `bom.php` to use `bom_item`

3. **Migrate `routing` (V1) → `routing_graph` (V2):**
   - Update `hatthasilpa_job_ticket.php` to use `routing_graph`
   - Update `pwa_scan_api.php` to use `routing_graph`
   - Update `routing.php` to use `routing_graph` (or deprecate if legacy UI)

### Priority Order

1. **Phase 1:** Migrate `stock_item` (highest impact)
2. **Phase 2:** Migrate `bom_line` (high impact)
3. **Phase 3:** Migrate `routing` (V1) (medium impact)

---

**Document Status:** ✅ Complete  
**Last Updated:** December 2025

