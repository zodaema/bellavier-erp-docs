# Task 14.1.2 – Scan Notes: material_lot + stock_item Touchpoints

**Date:** December 2025  
**Task:** [14.1.2.md](task14.1.2.md)  
**Status:** ✅ COMPLETED

---

## Summary

This document identifies all code paths that still use `material_lot.id_stock_item` and need to be migrated to use `id_material` in Phase 2.

---

## Files Using material_lot + stock_item

### 1. `source/leather_grn.php` ⚠️ **HIGH PRIORITY**

**Usage Type:** CREATE (WRITE)

**Location:** Line ~369-399

**Current Code:**
```php
INSERT INTO material_lot (
    id_stock_item, lot_code, supplier_name, supplier_reference,
    received_at, quantity, id_uom, area_sqft, weight_kg, thickness_avg,
    grade, status, location_code, notes, is_leather_grn
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'available', ?, ?, 1)
```

**Context:**
- Creates `material_lot` record during Leather GRN flow
- Uses `$idStockItem` variable (resolved from `stock_item` table)
- Already has `$materialRow` with `id_material` from Task 14.1.1

**Migration Plan:**
- Add `id_material` to INSERT statement
- Use dual-write: write both `id_material` and `id_stock_item`
- Resolve `id_material` from `material` table (already available)

**Risk:** HIGH - Core GRN functionality

---

### 2. `source/materials.php` ⚠️ **HIGH PRIORITY**

**Usage Type:** CREATE, READ

#### 2.1 READ: `lot_list` endpoint (Line ~570-575)

**Current Code:**
```php
SELECT ... FROM material_lot WHERE id_stock_item=? ORDER BY ...
```

**Context:**
- Lists lots for a given `id_stock_item`
- Called from UI to show lots for a material

**Migration Plan:**
- Change to: `WHERE id_material=?` (prefer new field)
- Fallback: `WHERE id_stock_item=?` if `id_material` is NULL (for legacy data)

#### 2.2 CREATE: `lot_create` endpoint (Line ~638-643)

**Current Code:**
```php
INSERT INTO material_lot (id_stock_item, lot_code, ...) VALUES (?,?,...)
```

**Context:**
- Creates new lot from Materials UI
- Receives `id_stock_item` from frontend
- Needs to resolve `id_material` from `stock_item.sku` → `material.sku`

**Migration Plan:**
- Resolve `id_material` from `stock_item.sku` → `material.sku`
- Dual-write: write both `id_material` and `id_stock_item`
- Update validation to accept either `id_stock_item` or `sku_material`

**Risk:** HIGH - Materials management functionality

---

### 3. `source/leather_sheet_api.php` ✅ **LOW PRIORITY**

**Usage Type:** READ (JOIN only)

**Location:** Line ~139

**Current Code:**
```php
LEFT JOIN material_lot ml ON ml.id_material_lot = ls.id_lot
```

**Context:**
- Only JOINs `material_lot` to get lot information
- Does NOT directly use `id_stock_item`
- No changes needed (already uses `id_material_lot` PK)

**Migration Plan:**
- No changes needed (already safe)

**Risk:** LOW - Only reads, doesn't use id_stock_item

---

## Categorization by Usage Type

### CREATE / UPDATE Flows (WRITE)

1. **`leather_grn.php`** - `save` action
   - Creates `material_lot` during GRN
   - **Priority:** HIGH
   - **Status:** Needs dual-write

2. **`materials.php`** - `lot_create` action
   - Creates `material_lot` from Materials UI
   - **Priority:** HIGH
   - **Status:** Needs dual-write + SKU resolution

### READ Flows

1. **`materials.php`** - `lot_list` action
   - Lists lots for a material
   - **Priority:** HIGH
   - **Status:** Needs to prefer `id_material`, fallback to `id_stock_item`

2. **`leather_grn.php`** - `list` action
   - Lists GRN records (already migrated in Task 14.1.1)
   - **Priority:** LOW
   - **Status:** Already uses COALESCE pattern

3. **`leather_sheet_api.php`** - Various actions
   - JOINs `material_lot` (doesn't use `id_stock_item`)
   - **Priority:** LOW
   - **Status:** No changes needed

---

## Stock Computation Patterns

### Current Pattern (Legacy)
```php
// Get stock from stock_item.quantity
SELECT quantity FROM stock_item WHERE id_stock_item = ?
```

### Target Pattern (V2)
```php
// Get stock from warehouse_inventory aggregation
SELECT SUM(qty) FROM warehouse_inventory WHERE id_material = ?
```

**Files to Update:**
- None identified yet (may be in future tasks)

---

## Migration Strategy

### Phase 1: Database Migration
1. Add `id_material` column to `material_lot` (nullable, FK to `material`)
2. Backfill `id_material` from existing `id_stock_item` mapping
3. Add index on `id_material`

### Phase 2: Code Migration
1. **Dual-write for CREATE:**
   - Resolve `id_material` from `material.sku` (via `stock_item.sku`)
   - Write both `id_material` and `id_stock_item` in INSERT statements

2. **Prefer new field for READ:**
   - Change WHERE clauses to prefer `id_material`
   - Fallback to `id_stock_item` if `id_material` is NULL

3. **Update JOINs:**
   - Prefer `JOIN material m ON m.id_material = ml.id_material`
   - Fallback to `JOIN stock_item si ON si.id_stock_item = ml.id_stock_item`

---

## Risk Assessment

### High Risk ⚠️
- `leather_grn.php` - Core GRN functionality
- `materials.php` - Materials management UI

### Medium Risk
- None identified

### Low Risk ✅
- `leather_sheet_api.php` - Only reads, doesn't use id_stock_item

---

## Next Steps

1. ✅ Create migration to add `id_material` column
2. ✅ Backfill `id_material` from existing data
3. ✅ Update CREATE flows to dual-write
4. ✅ Update READ flows to prefer `id_material`
5. ⏳ Test all affected endpoints

---

**Last Updated:** December 2025

