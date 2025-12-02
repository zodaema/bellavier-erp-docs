# Task 14.0 Results — Master Blueprint Cleanup & Legacy Schema Purge

**Status:** 🟡 **IN PROGRESS** (Phase 14.0-A & 14.0-B Partial Complete)  
**Date:** December 2025  
**Task:** [14.0.md](task14.md)

---

## Summary

Task 14.0 aims to clean up the database "Blueprint" (migration + schema) to ensure Bellavier ERP has a single, clear database structure without legacy tables, and can deploy to production / create new tenants without creating legacy tables again.

**Current Status:**
- ✅ Phase 14.0-A: Inventory & Classification (COMPLETED)
- ✅ Phase 14.0-B: Deprecated Migrations Documentation (COMPLETED)
- ⏳ Phase 14.0-B: Master Schema V2 Creation (PENDING)
- ⏳ Phase 14.0-C: Tenant Bootstrap Strategy (PENDING)

---

## Phase 14.0-A: Inventory & Classification (COMPLETED)

### Deliverables

1. ✅ **`task14_inventory.md`** — Complete table inventory and classification
   - Lists all 87+ tables from `0001_init_tenant_schema_v2.php`
   - Classifies into V2 (Current Core) and V1 (Legacy)
   - Includes Routing V2/V1 classification per `routing_classification.md`
   - Provides V1 → V2 mapping table

### Key Findings

**V2 Tables (Current Core):** ~75 tables
- Master Data: `unit_of_measure`, `work_center`, `warehouse`, `warehouse_location`, `material`, `material_lot`, etc.
- Production: `job_ticket`, `job_task`, `wip_log`, `task_operator_session`
- DAG Token: `flow_token`, `token_assignment`, `token_event`, etc.
- Routing V2: `routing_graph`, `routing_node`, `routing_edge`, etc.
- Inventory: `stock_ledger`, `warehouse_inventory`, `inventory_transaction`
- BOM: `bom`, `bom_item`
- QC: `qc_inspection`, `qc_fail_event`
- And more...

**V1 Legacy Tables:** ~6 tables
- ❌ `uom` (replaced by `unit_of_measure`)
- ❌ `stock_item` (replaced by `material`, `stock_ledger`)
- ❌ `stock_item_asset` (replaced by `material_asset`)
- ❌ `stock_item_lot` (replaced by `material_lot`)
- ❌ `routing` (replaced by `routing_graph`, `routing_node`, `routing_edge`)
- ❌ `bom_line` (replaced by `bom`, `bom_item`)

### V1 → V2 Mapping

| V1 (Legacy) | V2 (Current) |
|-------------|--------------|
| `uom` | `unit_of_measure` |
| `work_centers` | `work_center` |
| `stock_item` | `material`, `material_lot`, `stock_ledger` |
| `stock_item_asset` | `material_asset` |
| `stock_item_lot` | `material_lot` |
| `routing` | `routing_graph`, `routing_node`, `routing_edge` |
| `bom_line` | `bom`, `bom_item` |

---

## Phase 14.0-B: Blueprint Refactor (PARTIAL)

### Deliverables

1. ✅ **`task14_deprecated_migrations.md`** — Deprecated migrations documentation
   - Lists all migrations that create V1 tables
   - Provides deprecation rules for new vs existing tenants
   - Recommends file organization structure
   - Documents bootstrap script changes needed

### Key Actions Identified

1. **Create Master Schema V2:**
   - File: `database/tenant_migrations/2025_14_master_schema_v2.php`
   - Contains ONLY V2 tables (excludes all V1 legacy tables)
   - Idempotent (uses `migration_create_table_if_missing()`)

2. **Deprecate Legacy Migrations:**
   - Mark `0001_init_tenant_schema_v2.php` as partially deprecated
   - Move to `tenant_migrations_deprecated/` folder (or mark in documentation)
   - Update bootstrap scripts to skip deprecated folder

3. **Ensure No Implicit Legacy Creation:**
   - Audit code for manual `CREATE TABLE` statements
   - Ensure no runtime creation of V1 tables

4. **Critical Routing Classification:**
   - ✅ Verified per `routing_classification.md`
   - Master Schema V2 will include ONLY Routing V2 tables
   - Exclude `routing` (V1 legacy) table

---

## Pending Tasks

### Phase 14.0-B (Remaining)

1. ⏳ **Create Master Schema V2 Migration**
   - File: `database/tenant_migrations/2025_14_master_schema_v2.php`
   - Extract V2 tables from `0001_init_tenant_schema_v2.php`
   - Exclude all V1 legacy tables:
     - `uom`
     - `stock_item`, `stock_item_asset`, `stock_item_lot`
     - `routing`
     - `bom_line`
   - Ensure idempotency
   - Test on new tenant

2. ⏳ **Update Bootstrap Scripts**
   - Skip `*_deprecated/` folders
   - Prioritize Master Schema V2 for new tenants
   - Use `tenant_migrations` table for tracking

3. ⏳ **Create Legacy Code References Document**
   - File: `task14_legacy_code_refs.md`
   - Audit codebase for V1 table references
   - Mark files as "Legacy" if they use V1 tables
   - Plan for future refactoring

### Phase 14.0-C: Tenant Bootstrap Strategy

1. ⏳ **Design Tenant Bootstrap Script**
   - File: `tools/bootstrap_tenant.php` (or similar)
   - Run Master Schema V2
   - Run System Default Seed (Task 13.21)
   - Run other necessary seeds

2. ⏳ **Define Environment Procedures**
   - Dev: Reset tenant (schema + data)
   - Staging: Reset schema + seed master
   - Prod: No reset, use blueprint for new tenants only

3. ⏳ **Create Tenant Bootstrap Documentation**
   - File: `task14_tenant_bootstrap.md`
   - Steps to create new tenant
   - Steps to reset dev tenant
   - Backup procedures

---

## Files Created

1. ✅ `docs/dag/tasks/task14_inventory.md`
   - Complete table inventory and classification
   - V1/V2 mapping
   - Routing classification

2. ✅ `docs/dag/tasks/task14_deprecated_migrations.md`
   - Deprecated migrations list
   - Deprecation rules
   - Bootstrap script recommendations

3. ✅ `docs/dag/tasks/task14_results.md`
   - This file

---

## Risk Mitigation

### Risk 1: Existing Tenants Break

**Status:** ✅ Mitigated
- Existing tenants keep current schema
- No automatic migration required
- V1 tables remain for backward compatibility

### Risk 2: Code Still References V1 Tables

**Status:** ⏳ Pending Audit
- Need to create `task14_legacy_code_refs.md`
- Mark legacy code for future refactoring
- Don't drop V1 tables until code is updated

### Risk 3: Master Schema V2 Incomplete

**Status:** ⏳ Pending Creation
- Use `task14_inventory.md` as reference
- Verify against dev DB schema
- Test on new tenant before production

---

## Next Steps

1. **Create Master Schema V2:**
   - Extract V2 tables from `0001_init_tenant_schema_v2.php`
   - Exclude V1 legacy tables
   - Test on new tenant

2. **Update Bootstrap Scripts:**
   - Skip deprecated folder
   - Prioritize Master Schema V2

3. **Create Legacy Code References:**
   - Audit codebase
   - Document V1 references

4. **Create Tenant Bootstrap Strategy:**
   - Design bootstrap script
   - Define procedures
   - Document steps

---

**Task 14.0 Status:** 🟡 **IN PROGRESS**

**Phase 14.0-A:** ✅ Complete  
**Phase 14.0-B:** 🟡 Partial (Documentation done, Master Schema V2 pending)  
**Phase 14.0-C:** ⏳ Pending

