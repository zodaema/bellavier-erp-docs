# Task 14.1 — Migration Deep Scan Results

**Date:** December 2025  
**Phase:** 14.1 — Deep System Scan  
**Status:** ✅ COMPLETED

---

## Summary

This document contains the results of scanning all migration files for legacy (V1) table creation.

---

## Active Migrations Creating Legacy Tables

### `database/tenant_migrations/0001_init_tenant_schema_v2.php`

**Status:** ⚠️ **CREATES LEGACY TABLES**

**Legacy Tables Created:**

1. **`uom`** (line 358)
   - **Replacement:** `unit_of_measure`
   - **Status:** Can be safely excluded (no code references found)

2. **`bom_line`** (line 160)
   - **Replacement:** `bom` + `bom_item`
   - **Status:** ⚠️ **ACTIVE USE** — 5 files, 8 references
   - **Risk:** HIGH — Must migrate code before deprecating

3. **`routing`** (line 851)
   - **Replacement:** `routing_graph`, `routing_node`, `routing_edge` (V2)
   - **Status:** ⚠️ **ACTIVE USE** — 3 files, 7 references
   - **Risk:** HIGH — Must migrate code before deprecating

4. **`stock_item`** (line 1425)
   - **Replacement:** `material`, `material_lot`, `stock_ledger`
   - **Status:** ⚠️ **ACTIVE USE** — 5 files, 11 references
   - **Risk:** CRITICAL — Must migrate code before deprecating

5. **`stock_item_asset`** (line 1438)
   - **Replacement:** `material_asset`
   - **Status:** Unknown usage (needs verification)
   - **Risk:** MEDIUM — Verify before deprecating

6. **`stock_item_lot`** (line 1456)
   - **Replacement:** `material_lot`
   - **Status:** Unknown usage (needs verification)
   - **Risk:** MEDIUM — Verify before deprecating

**Total Legacy Tables:** 6 tables

---

## Archived Migrations

### `database/tenant_migrations/archive/consolidated_2025_11/0001_init_tenant_schema.php`

**Status:** ✅ **ARCHIVED** (Not active)

**Legacy Tables Created:**
- `uom` (line 476)
- `bom_line` (line 92)
- `routing` (line 300)
- `stock_item` (line 356)
- `stock_item_asset` (line 364)
- `stock_item_lot` (line 372)

**Note:** This file is archived and not used for new tenants.

---

## Duplicate Table Analysis

### V1 vs V2 Tables

| V1 (Legacy) | V2 (Current) | Status |
|-------------|--------------|--------|
| `uom` | `unit_of_measure` | ✅ No code conflict |
| `stock_item` | `material` | ⚠️ Code uses both |
| `stock_item_asset` | `material_asset` | ⚠️ Need verification |
| `stock_item_lot` | `material_lot` | ⚠️ Need verification |
| `bom_line` | `bom` + `bom_item` | ⚠️ Code uses both |
| `routing` | `routing_graph` + `routing_node` + `routing_edge` | ⚠️ Code uses both |

**Conclusion:**
- **No pure duplicates** — V1 and V2 tables serve different purposes
- **Code migration needed** — Some code still uses V1, some uses V2
- **Risk:** HIGH — Both V1 and V2 tables exist, causing confusion

---

## Routing V1 vs V2 Analysis

### Routing V1 (Legacy)
- **Table:** `routing` (single table)
- **Created in:** `0001_init_tenant_schema_v2.php` (line 851)
- **Usage:** 3 files, 7 references
- **Status:** ⚠️ **ACTIVE USE**

### Routing V2 (DAG)
- **Tables:** `routing_graph`, `routing_graph_version`, `routing_graph_var`, `routing_graph_favorite`, `routing_graph_feature_flag`, `routing_node`, `routing_edge`, `routing_set`, `routing_step`, `routing_audit_log`
- **Created in:** `0001_init_tenant_schema_v2.php` (multiple locations)
- **Usage:** Active in DAG Designer, Behavior Engine, Job Ticket
- **Status:** ✅ **ACTIVE USE**

**Conclusion:**
- **Both V1 and V2 exist** — This is the expected state during transition
- **V1 must be deprecated** — After code migration to V2
- **V2 must be protected** — Per `routing_classification.md`

---

## Stock Pipeline Analysis

### Legacy Stock Tables
- `stock_item` — Created in migration
- `stock_item_asset` — Created in migration
- `stock_item_lot` — Created in migration

### V2 Stock Tables
- `material` — Created in migration
- `material_lot` — Created in migration
- `material_asset` — Created in migration
- `stock_ledger` — Created in migration

**Conclusion:**
- **Both V1 and V2 exist** — Transition period
- **Code uses V1** — Must migrate to V2 before deprecating
- **Risk:** CRITICAL — Core material pipeline depends on V1

---

## BOM Pipeline Analysis

### Legacy BOM
- `bom_line` — Created in migration (line 160)

### V2 BOM
- `bom` — Created in migration
- `bom_item` — Created in migration

**Conclusion:**
- **Both V1 and V2 exist** — Transition period
- **Code uses V1** — Must migrate to V2 before deprecating
- **Risk:** HIGH — BOM system depends on V1

---

## Recommendations

### For Master Schema V2

1. **Exclude All Legacy Tables:**
   - `uom` ✅ (safe to exclude)
   - `stock_item` ⚠️ (must migrate code first)
   - `stock_item_asset` ⚠️ (verify usage first)
   - `stock_item_lot` ⚠️ (verify usage first)
   - `bom_line` ⚠️ (must migrate code first)
   - `routing` ⚠️ (must migrate code first)

2. **Include All V2 Tables:**
   - `unit_of_measure` ✅
   - `material`, `material_lot`, `material_asset` ✅
   - `stock_ledger` ✅
   - `bom`, `bom_item` ✅
   - All Routing V2 tables ✅

### Migration Strategy

1. **Phase 1:** Create Master Schema V2 (exclude legacy tables)
2. **Phase 2:** Migrate code from V1 → V2
3. **Phase 3:** Deprecate V1 tables (after code migration)

---

**Document Status:** ✅ Complete  
**Last Updated:** December 2025

