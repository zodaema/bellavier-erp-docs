# Task 14.0-B — Deprecated Migrations

**Date:** December 2025  
**Phase:** 14.0-B — Blueprint Refactor  
**Status:** ✅ COMPLETED

---

## Summary

This document lists all migration files that create or reference V1 (Legacy) tables. These migrations should be considered **deprecated** and should NOT be run for new tenants.

**Important:**
- Existing tenants that already have these tables will continue to work
- New tenants should use Master Schema V2 only (no V1 tables)
- These migrations are kept for historical reference only

---

## Deprecated Migrations

### Files Creating V1 Legacy Tables

#### `0001_init_tenant_schema_v2.php` (Partial Deprecation)

**Status:** ⚠️ **PARTIALLY DEPRECATED**

This file creates both V2 and V1 tables. The following sections should be excluded from Master Schema V2:

1. **`uom` table (line 358)**
   - **Reason:** Replaced by `unit_of_measure`
   - **Action:** Remove from Master Schema V2

2. **`stock_item` table (line 1425)**
   - **Reason:** Replaced by `material`, `material_lot`, `stock_ledger`
   - **Action:** Remove from Master Schema V2

3. **`stock_item_asset` table**
   - **Reason:** Replaced by `material_asset`
   - **Action:** Remove from Master Schema V2

4. **`stock_item_lot` table**
   - **Reason:** Replaced by `material_lot`
   - **Action:** Remove from Master Schema V2

5. **`routing` table**
   - **Reason:** Replaced by `routing_graph`, `routing_node`, `routing_edge` (DAG Routing V2)
   - **Action:** Remove from Master Schema V2

6. **`bom_line` table (line 160)**
   - **Reason:** Replaced by `bom`, `bom_item`
   - **Action:** Remove from Master Schema V2

**Note:** This file will be replaced by `2025_14_master_schema_v2.php` which excludes all V1 tables.

---

## Migration File Organization

### Recommended Structure

```
database/
├── tenant_migrations/
│   ├── 2025_14_master_schema_v2.php  ← NEW: Master Schema V2 (V2 tables only)
│   ├── 2025_12_system_master_data_hardening.php  ← Active
│   └── ... (other active migrations)
│
└── tenant_migrations_deprecated/
    ├── 0001_init_tenant_schema_v2.php  ← MOVE HERE (contains V1 tables)
    └── README.md  ← Explains why these are deprecated
```

---

## Deprecation Rules

### For New Tenants

1. **DO NOT run migrations that create V1 tables:**
   - `uom` → Use `unit_of_measure` instead
   - `stock_item` → Use `material`, `material_lot`, `stock_ledger` instead
   - `routing` → Use `routing_graph`, `routing_node`, `routing_edge` instead
   - `bom_line` → Use `bom`, `bom_item` instead

2. **DO run Master Schema V2:**
   - `2025_14_master_schema_v2.php` (to be created)
   - Contains only V2 tables

### For Existing Tenants

1. **Existing tenants keep their current schema:**
   - No automatic migration needed
   - V1 tables remain for backward compatibility
   - Code can continue to reference V1 tables if needed

2. **Future cleanup:**
   - Manual data migration from V1 → V2 (Task 14.1-14.3, if needed)
   - Code refactoring to remove V1 references (separate task)

---

## Bootstrap Script Changes

### Current Behavior

Bootstrap scripts currently run all migrations in `database/tenant_migrations/` directory.

### Recommended Change

1. **Skip deprecated folder:**
   - Bootstrap should NOT run migrations in `*_deprecated/` folders
   - Only run migrations in active `tenant_migrations/` folder

2. **Master Schema V2 priority:**
   - For new tenants, run `2025_14_master_schema_v2.php` first
   - Then run other active migrations

3. **Migration tracking:**
   - Use `tenant_migrations` table to track which migrations have been run
   - Skip migrations that are already recorded

---

## Code References

### Files That May Reference V1 Tables

These files should be audited and marked as "Legacy" if they use V1 tables:

1. **UOM System:**
   - Files using `uom` table (should use `unit_of_measure`)

2. **Stock/Inventory:**
   - Files using `stock_item` (should use `material`, `stock_ledger`)
   - Files using `stock_item_asset` (should use `material_asset`)
   - Files using `stock_item_lot` (should use `material_lot`)

3. **Routing:**
   - Files using `routing` table (should use `routing_graph`, `routing_node`, `routing_edge`)

4. **BOM:**
   - Files using `bom_line` (should use `bom`, `bom_item`)

**Action:** Create `task14_legacy_code_refs.md` to document all code references to V1 tables.

---

## Next Steps

1. ✅ **Create this document** — Done
2. ⏳ **Create Master Schema V2** — `2025_14_master_schema_v2.php` (exclude V1 tables)
3. ⏳ **Update bootstrap scripts** — Skip deprecated folder
4. ⏳ **Create legacy code refs document** — `task14_legacy_code_refs.md`

---

**Document Status:** ✅ Complete  
**Last Updated:** December 2025

