# Task 14.1 — BOM Pipeline Verification

**Date:** December 2025  
**Phase:** 14.1 — Deep System Scan  
**Status:** ✅ COMPLETED

---

## Summary

This document verifies the BOM (Bill of Materials) system, confirming that `bom` + `bom_item` (V2) are used for DAG V2, and identifying where `bom_line` (V1 legacy) is still referenced.

---

## BOM System Overview

The Bellavier ERP BOM system has two generations:

### V1 (Legacy) — `bom_line`
- Single table structure
- Used by legacy BOM system
- **Status:** ⚠️ Still actively used

### V2 (Current) — `bom` + `bom_item`
- Two-table structure (BOM header + items)
- Used by DAG V2 system
- **Status:** ✅ Active use

---

## Code Usage Analysis

### V2 BOM System Usage

#### `bom` + `bom_item` Tables (V2)

**Status:** ✅ **ACTIVE USE** — Multiple files

**Files Using V2 BOM:**

1. **`source/BGERP/Service/BOMService.php`**
   - **Purpose:** BOM Service (PSR-4) creates/manages BOMs
   - **Tables:** Uses `bom` and `bom_item`
   - **Status:** ✅ Active

2. **`source/bom.php`**
   - **Purpose:** BOM API uses BOM Service
   - **Tables:** Uses `bom` and `bom_item` via BOMService
   - **Status:** ✅ Active

**Conclusion:**
- ✅ V2 BOM (`bom` + `bom_item`) is **actively used** by BOM Service
- ✅ V2 BOM must be **protected** in Master Schema V2

---

### V1 Legacy BOM System Usage

#### `bom_line` — Legacy BOM Line

**Status:** ⚠️ **ACTIVE USE** — 5 files, 8 references

**Files Using `bom_line`:**

1. **`source/leather_cut_bom_api.php`** (4 references)
   - Line 158: `FROM bom_line bl`
   - Line 178: Comment mentions `bom_line`
   - Line 264: `FROM bom_line bl`
   - Line 428: `FROM bom_line bl`
   - **Purpose:** CUT BOM API reads from `bom_line` for BOM structure
   - **Risk:** HIGH — CUT BOM functionality depends on this

2. **`source/BGERP/Helper/MaterialResolver.php`** (1 reference)
   - Line 204: `FROM bom_line bl`
   - **Purpose:** Core material resolver uses `bom_line`
   - **Risk:** HIGH — Core helper class depends on this

3. **`source/BGERP/Component/ComponentAllocationService.php`** (1 reference)
   - Line 582: `LEFT JOIN bom_line bl ON bl.id_bom_line = cbm.id_bom_line`
   - **Purpose:** Component allocation uses `bom_line`
   - **Risk:** MEDIUM — Component allocation depends on this

4. **`source/component.php`** (1 reference)
   - Line 355: `LEFT JOIN bom_line bl ON bl.id_bom_line = cbm.id_bom_line`
   - **Purpose:** Component API uses `bom_line`
   - **Risk:** MEDIUM — Component functionality depends on this

5. **`source/bom.php`** (1 reference)
   - Line 126: `FROM bom_line bl`
   - **Purpose:** BOM API uses `bom_line` for legacy BOM lookup
   - **Risk:** HIGH — BOM functionality depends on this

**Conclusion:**
- ⚠️ `bom_line` is **still actively used** by 5 files
- ⚠️ `bom_line` must be **migrated to `bom` + `bom_item`** before deprecating
- ⚠️ `bom_line` **cannot be safely removed** until code migration

---

## CUT Behavior Analysis

### Current Implementation

**File:** `source/leather_cut_bom_api.php`

**Uses V1:**
- Reads from `bom_line` for BOM structure (4 references)
- Uses `bom_line.material_sku` for material lookup
- Creates `leather_cut_bom_log` records linked to `bom_line`

**Conclusion:**
- ⚠️ CUT Behavior uses **V1 legacy `bom_line`**
- ⚠️ Must migrate to V2 (`bom` + `bom_item`) before deprecating

---

## BOM Structure Comparison

### V1 (Legacy) — `bom_line`
```sql
bom_line
  - id_bom_line
  - material_sku
  - quantity
  - (other fields)
```

**Characteristics:**
- Single table structure
- Direct material SKU reference
- Used by legacy BOM system

### V2 (Current) — `bom` + `bom_item`
```sql
bom
  - id_bom
  - id_product
  - version
  - (other fields)

bom_item
  - id_bom_item
  - id_bom
  - material_sku (or id_material)
  - quantity
  - (other fields)
```

**Characteristics:**
- Two-table structure (header + items)
- Supports versioning
- Used by DAG V2 system

---

## Migration Requirements

### Before Deprecating `bom_line`

1. **Migrate `leather_cut_bom_api.php`:**
   - Replace `bom_line` queries with `bom_item` queries
   - Use `bom_item.material_sku` instead of `bom_line.material_sku`
   - Update BOM structure lookup logic
   - Update `leather_cut_bom_log` to reference `bom_item` instead of `bom_line`

2. **Migrate `MaterialResolver.php`:**
   - Replace `bom_line` queries with `bom_item` queries
   - Update material resolution logic

3. **Migrate `ComponentAllocationService.php`:**
   - Replace `bom_line` queries with `bom_item` queries
   - Update component allocation logic

4. **Migrate `component.php`:**
   - Replace `bom_line` queries with `bom_item` queries
   - Update component API logic

5. **Migrate `bom.php`:**
   - Replace `bom_line` queries with `bom_item` queries
   - Update BOM API logic

---

## Risk Assessment

### High Risk (Must Fix Before Deprecation)

1. **`leather_cut_bom_api.php`** — Uses `bom_line` for CUT BOM
   - **Impact:** CRITICAL — CUT BOM will fail if `bom_line` is removed
   - **Action:** Must migrate to `bom_item` before deprecating

2. **`MaterialResolver.php`** — Core helper uses `bom_line`
   - **Impact:** CRITICAL — Material resolution will fail if `bom_line` is removed
   - **Action:** Must migrate to `bom_item` before deprecating

3. **`bom.php`** — BOM API uses `bom_line`
   - **Impact:** HIGH — BOM functionality will fail if `bom_line` is removed
   - **Action:** Must migrate to `bom_item` before deprecating

### Medium Risk

1. **`ComponentAllocationService.php`** — Component allocation uses `bom_line`
   - **Impact:** MEDIUM — Component allocation may fail if `bom_line` is removed
   - **Action:** Migrate to `bom_item` before deprecating

2. **`component.php`** — Component API uses `bom_line`
   - **Impact:** MEDIUM — Component functionality may fail if `bom_line` is removed
   - **Action:** Migrate to `bom_item` before deprecating

---

## Recommendations

### For Master Schema V2

1. **Include All V2 BOM Tables:**
   - `bom` ✅ (BOM header)
   - `bom_item` ✅ (BOM items)

2. **Exclude V1 BOM Table:**
   - `bom_line` ⚠️ (must migrate code first)

3. **Code Migration Priority:**
   - **Phase 1:** Migrate `MaterialResolver.php` (highest priority)
   - **Phase 2:** Migrate `leather_cut_bom_api.php`
   - **Phase 3:** Migrate `bom.php`
   - **Phase 4:** Migrate `ComponentAllocationService.php` and `component.php`

---

**Document Status:** ✅ Complete  
**Last Updated:** December 2025

