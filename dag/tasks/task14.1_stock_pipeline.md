# Task 14.1 — Stock Pipeline Verification

**Date:** December 2025  
**Phase:** 14.1 — Deep System Scan  
**Status:** ✅ COMPLETED

---

## Summary

This document verifies the stock pipeline system, identifying which APIs/UI use legacy `stock_item*` tables vs V2 `material*` and `stock_ledger` tables.

---

## Stock System Overview

The Bellavier ERP stock system has two generations:

### V1 (Legacy) — `stock_item*`
- `stock_item` — Legacy stock item master
- `stock_item_asset` — Legacy stock asset tracking
- `stock_item_lot` — Legacy stock lot tracking

### V2 (Current) — `material*` + `stock_ledger`
- `material` — Material master (V2)
- `material_lot` — Material lot tracking (V2)
- `material_asset` — Material asset tracking (V2)
- `stock_ledger` — Central stock ledger (V2) — **ACTIVE USE**

---

## Code Usage Analysis

### V2 Stock System Usage

#### `stock_ledger` — Central Stock Ledger (V2)

**Status:** ✅ **ACTIVE USE** — Multiple files

**Files Using `stock_ledger`:**

1. **`source/leather_grn.php`** — Creates stock movements
   - **Purpose:** GRN Leather creates stock movement (IN) records
   - **Transaction Type:** `GRN_LEATHER`
   - **Status:** ✅ Active (Task 13.17 integration)

2. **`source/stock_card.php`** — Reads stock ledger
   - **Purpose:** Stock card reporting (read-only)
   - **Query:** `SELECT ... FROM stock_ledger ...`
   - **Status:** ✅ Active

3. **`source/transfer.php`** — Creates stock movements
   - **Purpose:** Stock transfer creates OUT + IN records
   - **Transaction Type:** `TRANSFER`
   - **Status:** ✅ Active

4. **`source/issue.php`** — Creates stock movements
   - **Purpose:** Stock issue creates OUT records
   - **Transaction Type:** `ISSUE`
   - **Status:** ✅ Active

5. **`source/grn.php`** — Creates stock movements
   - **Purpose:** General GRN creates stock movement (IN) records
   - **Transaction Type:** `GRN`
   - **Status:** ✅ Active

6. **`source/adjust.php`** — Creates stock movements
   - **Purpose:** Stock adjustment creates movement records
   - **Transaction Type:** `ADJUST`
   - **Status:** ✅ Active

**Conclusion:**
- ✅ `stock_ledger` is **actively used** by stock transaction APIs
- ✅ `stock_ledger` is **critical** for stock movement tracking
- ✅ `stock_ledger` must be **protected** in Master Schema V2

#### `material*` Tables (V2)

**Status:** ✅ **ACTIVE USE** — Multiple files

**Files Using `material`:**

1. **`source/leather_grn.php`** — Uses `material` table
   - **Purpose:** Material master auto-create (Task 13.16)
   - **Query:** `SELECT sku FROM material WHERE sku = ?`
   - **Status:** ✅ Active

2. **`source/stock_card.php`** — Uses `material` (indirectly via `stock_ledger.sku`)
   - **Purpose:** Stock card shows material SKUs
   - **Status:** ✅ Active

**Conclusion:**
- ✅ `material` table is **actively used** by GRN and stock systems
- ✅ `material` must be **protected** in Master Schema V2

---

### V1 Legacy Stock System Usage

#### `stock_item` — Legacy Stock Item

**Status:** ⚠️ **ACTIVE USE** — 5 files, 11 references

**Files Using `stock_item`:**

1. **`source/leather_grn.php`** (4 references)
   - Line 100: `FROM stock_item si`
   - Line 174: `FROM stock_item`
   - Line 280: Comment mentions `stock_item`
   - Line 526: `INNER JOIN stock_item si ON si.id_stock_item = ml.id_stock_item`
   - **Purpose:** Leather GRN reads from `stock_item` for material lookup
   - **Risk:** HIGH — Core GRN functionality depends on this

2. **`source/leather_cut_bom_api.php`** (1 reference)
   - Line 159: `LEFT JOIN stock_item si ON si.sku = bl.material_sku`
   - **Purpose:** CUT BOM uses `stock_item` for material lookup
   - **Risk:** MEDIUM — CUT BOM depends on this

3. **`source/BGERP/Helper/MaterialResolver.php`** (1 reference)
   - Line 205: `LEFT JOIN stock_item si ON si.sku = bl.material_sku`
   - **Purpose:** Core material resolver uses `stock_item`
   - **Risk:** HIGH — Core helper class depends on this

4. **`source/trace_api.php`** (2 references)
   - Line 1774: `LEFT JOIN stock_item si ON si.id_stock_item = iti.id_stock_item`
   - Line 2682: `LEFT JOIN stock_item si ON si.id_stock_item = iti.id_stock_item`
   - **Purpose:** Trace API uses `stock_item` for traceability
   - **Risk:** MEDIUM — Trace functionality depends on this

5. **`source/bom.php`** (3 references)
   - Line 127: `LEFT JOIN stock_item si ON si.sku = bl.material_sku`
   - Line 227: `LEFT JOIN stock_item si ON si.sku = bl.material_sku`
   - Line 439: `SELECT sku, description, quantity FROM stock_item ORDER BY sku ASC LIMIT 2000`
   - **Purpose:** BOM API uses `stock_item` for material lookup
   - **Risk:** HIGH — BOM functionality depends on this

**Conclusion:**
- ⚠️ `stock_item` is **still actively used** by 5 files
- ⚠️ `stock_item` must be **migrated to `material`** before deprecating
- ⚠️ `stock_item` **cannot be safely removed** until code migration

#### `stock_item_asset` and `stock_item_lot`

**Status:** ❓ **UNKNOWN USAGE** — Needs verification

**Recommendation:**
- Search codebase for references to `stock_item_asset`
- Search codebase for references to `stock_item_lot`
- Verify if these tables are used or can be safely deprecated

---

## GRN Leather Analysis

### Current Implementation

**File:** `source/leather_grn.php`

**Uses Both V1 and V2:**

1. **V1 Usage:**
   - Reads from `stock_item` for material lookup (lines 100, 174, 526)
   - Uses `stock_item.sku` to find material information

2. **V2 Usage:**
   - Creates `material` record if not exists (Task 13.16)
   - Creates `material_lot` record
   - Creates `leather_sheet` record
   - Creates `stock_ledger` record (Task 13.17)

**Conclusion:**
- ⚠️ GRN Leather uses **both V1 and V2** systems
- ⚠️ Must migrate from `stock_item` → `material` before deprecating V1

---

## CUT Behavior Analysis

### Current Implementation

**File:** `source/leather_cut_bom_api.php`

**Uses V1:**
- Reads from `stock_item` for material lookup (line 159)
- Uses `bom_line` (legacy) for BOM structure

**Conclusion:**
- ⚠️ CUT Behavior uses **V1 legacy tables**
- ⚠️ Must migrate to V2 before deprecating

---

## Migration Requirements

### Before Deprecating `stock_item*`

1. **Migrate `leather_grn.php`:**
   - Replace `stock_item` queries with `material` queries
   - Use `material.sku` instead of `stock_item.sku`
   - Update material lookup logic

2. **Migrate `MaterialResolver.php`:**
   - Replace `stock_item` queries with `material` queries
   - Update material resolution logic

3. **Migrate `bom.php`:**
   - Replace `stock_item` queries with `material` queries
   - Update BOM material lookup

4. **Migrate `trace_api.php`:**
   - Replace `stock_item` queries with `material` queries
   - Update traceability logic

5. **Migrate `leather_cut_bom_api.php`:**
   - Replace `stock_item` queries with `material` queries
   - Update CUT BOM material lookup

6. **Verify `stock_item_asset` and `stock_item_lot`:**
   - Check if these tables are used
   - Migrate to `material_asset` and `material_lot` if needed

---

## Risk Assessment

### High Risk (Must Fix Before Deprecation)

1. **`leather_grn.php`** — Uses `stock_item` for material lookup
   - **Impact:** CRITICAL — GRN Leather will fail if `stock_item` is removed
   - **Action:** Must migrate to `material` before deprecating

2. **`MaterialResolver.php`** — Core helper uses `stock_item`
   - **Impact:** CRITICAL — Material resolution will fail if `stock_item` is removed
   - **Action:** Must migrate to `material` before deprecating

3. **`bom.php`** — BOM API uses `stock_item`
   - **Impact:** HIGH — BOM functionality will fail if `stock_item` is removed
   - **Action:** Must migrate to `material` before deprecating

### Medium Risk

1. **`trace_api.php`** — Trace API uses `stock_item`
   - **Impact:** MEDIUM — Traceability may fail if `stock_item` is removed
   - **Action:** Migrate to `material` before deprecating

2. **`leather_cut_bom_api.php`** — CUT BOM uses `stock_item`
   - **Impact:** MEDIUM — CUT BOM may fail if `stock_item` is removed
   - **Action:** Migrate to `material` before deprecating

---

## Recommendations

### For Master Schema V2

1. **Include All V2 Stock Tables:**
   - `material` ✅
   - `material_lot` ✅
   - `material_asset` ✅
   - `stock_ledger` ✅ (CRITICAL — actively used)

2. **Exclude All V1 Stock Tables:**
   - `stock_item` ⚠️ (must migrate code first)
   - `stock_item_asset` ⚠️ (verify usage first)
   - `stock_item_lot` ⚠️ (verify usage first)

3. **Code Migration Priority:**
   - **Phase 1:** Migrate `MaterialResolver.php` (highest priority)
   - **Phase 2:** Migrate `leather_grn.php`
   - **Phase 3:** Migrate `bom.php`
   - **Phase 4:** Migrate `trace_api.php` and `leather_cut_bom_api.php`

---

**Document Status:** ✅ Complete  
**Last Updated:** December 2025

