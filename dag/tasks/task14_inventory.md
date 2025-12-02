# Task 14.0-A — Inventory & Classification

**Date:** December 2025  
**Phase:** 14.0-A — Inventory & Classification  
**Status:** ✅ COMPLETED

---

## Summary

This document provides a comprehensive inventory of all tables in the tenant migration blueprint (`0001_init_tenant_schema_v2.php`) and classifies them into:

- **V2 (Current Core)** — Active tables used by current system
- **V1 (Legacy)** — Deprecated tables from old system
- **Routing V2** — DAG Routing tables (per `routing_classification.md`)
- **Routing V1** — Legacy routing tables (if any)

---

## Table Classification

### V2 (Current Core) — Active Tables

These tables are actively used by the current system and must be included in Master Schema V2.

#### Master Data (V2)
- ✅ `unit_of_measure` — Current UOM system (replaces `uom`)
- ✅ `work_center` — Current work center system (replaces `work_centers`)
- ✅ `warehouse` — Warehouse master data
- ✅ `warehouse_location` — Warehouse location master data
- ✅ `product_category` — Product category (V2, used by current system)
- ✅ `material` — Material master (V2)
- ✅ `material_lot` — Material lot tracking
- ✅ `material_asset` — Material asset tracking
- ✅ `pattern` — Pattern master
- ✅ `pattern_version` — Pattern versioning

#### Production System (V2)
- ✅ `job_ticket` — Job ticket (canonical naming, Phase 8)
- ✅ `job_task` — Job task (canonical naming, Phase 8)
- ✅ `job_ticket_serial` — Serial number tracking
- ✅ `job_ticket_status_history` — Status history
- ✅ `wip_log` — WIP log (canonical naming, Phase 8)
- ✅ `task_operator_session` — Operator session tracking
- ✅ `mo` — Manufacturing order

#### DAG Token System (V2)
- ✅ `flow_token` — Flow token (DAG token system)
- ✅ `token_assignment` — Token assignment
- ✅ `token_event` — Token event log
- ✅ `token_work_session` — Token work session
- ✅ `token_join_buffer` — Token join buffer
- ✅ `token_spawn_log` — Token spawn log
- ✅ `node_assignment` — Node assignment
- ✅ `node_instance` — Node instance
- ✅ `job_graph_instance` — Job graph instance

#### Routing V2 (DAG Routing) — Per `routing_classification.md`
- ✅ `routing_graph` — DAG graph (V2)
- ✅ `routing_graph_draft` — Graph draft (not in list, but referenced)
- ✅ `routing_graph_version` — Graph versioning
- ✅ `routing_graph_var` — Graph variables
- ✅ `routing_graph_favorite` — User favorites
- ✅ `routing_graph_feature_flag` — Feature flags
- ✅ `routing_node` — Graph node (V2)
- ✅ `routing_edge` — Graph edge (V2)
- ✅ `routing_set` — Routing set
- ✅ `routing_step` — Routing step
- ✅ `routing_audit_log` — Audit log

#### Inventory & Stock (V2)
- ✅ `stock_ledger` — Central stock ledger (V2)
- ✅ `warehouse_inventory` — Warehouse inventory
- ✅ `inventory_transaction` — Inventory transaction
- ✅ `inventory_transaction_item` — Transaction items

#### BOM System (V2)
- ✅ `bom` — Bill of Materials (V2)
- ✅ `bom_item` — BOM items (V2)

#### Quality Control (V2)
- ✅ `qc_inspection` — QC inspection
- ✅ `qc_inspection_item` — QC inspection items
- ✅ `qc_fail_event` — QC fail event

#### Serial System (V2)
- ✅ `serial_generation_log` — Serial generation log
- ✅ `serial_link_outbox` — Serial link outbox
- ✅ `serial_quarantine` — Serial quarantine

#### Assignment System (V2)
- ✅ `assignment_log` — Assignment log
- ✅ `assignment_decision_log` — Decision log
- ✅ `assignment_notification` — Notifications
- ✅ `assignment_plan_job` — Job planning
- ✅ `assignment_plan_node` — Node planning

#### Team System (V2)
- ✅ `team` — Team master
- ✅ `team_member` — Team members
- ✅ `team_availability` — Team availability
- ✅ `operator_availability` — Operator availability
- ✅ `work_center_team_map` — Work center ↔ Team mapping
- ✅ `member_leave` — Leave tracking

#### Purchase System (V2)
- ✅ `purchase_rfq` — Purchase RFQ
- ✅ `purchase_rfq_item` — RFQ items
- ✅ `supplier_score` — Supplier scoring

#### Product System (V2)
- ✅ `product` — Product master (V2, used by current system)
- ✅ `product_asset` — Product asset

#### System Tables (V2)
- ✅ `organization` — Organization/tenant
- ✅ `permission` — Permissions
- ✅ `tenant_role` — Tenant roles
- ✅ `tenant_role_permission` — Role permissions
- ✅ `tenant_user_role` — User roles
- ✅ `tenant_feature_flags` — Feature flags
- ✅ `tenant_migrations` — Migration tracking
- ✅ `tenant_schema_migrations` — Legacy migration tracking
- ✅ `production_schedule_config` — Schedule config
- ✅ `schedule_change_log` — Schedule change log

---

### V1 (Legacy) — Deprecated Tables

These tables are from the old system and should NOT be created in new tenants.

#### Master Data (V1 Legacy)
- ❌ `uom` — **DEPRECATED** (replaced by `unit_of_measure`)
  - **Migration:** `0001_init_tenant_schema_v2.php` (line 358)
  - **Status:** Still in blueprint, must be removed from Master Schema V2
  - **Replacement:** `unit_of_measure`

#### Product/Stock (V1 Legacy)
- ❌ `stock_item` — **DEPRECATED** (replaced by `material`, `stock_ledger`)
  - **Migration:** `0001_init_tenant_schema_v2.php` (line 1425)
  - **Status:** Still in blueprint, must be removed from Master Schema V2
  - **Replacement:** `material`, `material_lot`, `stock_ledger`
- ❌ `stock_item_asset` — **DEPRECATED** (replaced by `material_asset`)
  - **Status:** Legacy, must be removed
  - **Replacement:** `material_asset`
- ❌ `stock_item_lot` — **DEPRECATED** (replaced by `material_lot`)
  - **Status:** Legacy, must be removed
  - **Replacement:** `material_lot`

#### Routing V1 (Legacy)
- ❌ `routing` — **DEPRECATED** (replaced by `routing_graph`, `routing_node`, `routing_edge`)
  - **Migration:** `0001_init_tenant_schema_v2.php`
  - **Status:** Legacy routing table, must be removed from Master Schema V2
  - **Replacement:** `routing_graph`, `routing_node`, `routing_edge` (DAG Routing V2)

#### BOM (V1 Legacy)
- ❌ `bom_line` — **DEPRECATED** (replaced by `bom`, `bom_item`)
  - **Migration:** `0001_init_tenant_schema_v2.php` (line 160)
  - **Status:** Legacy BOM structure, must be removed from Master Schema V2
  - **Replacement:** `bom`, `bom_item`

---

## Migration File Analysis

### `0001_init_tenant_schema_v2.php`

**Total Tables:** 87+ tables

**V2 Tables:** ~75 tables (Current Core)
**V1 Legacy Tables:** ~5 tables (must be removed from Master Schema V2)

**Legacy Tables Found:**
1. `uom` (line 358) — Replaced by `unit_of_measure`
2. `stock_item` (line 1425) — Replaced by `material`, `stock_ledger`
3. `stock_item_asset` — Replaced by `material_asset`
4. `stock_item_lot` — Replaced by `material_lot`
5. `routing` — Replaced by `routing_graph`, `routing_node`, `routing_edge`
6. `bom_line` (line 160) — Replaced by `bom`, `bom_item`

---

## V1 → V2 Mapping

| V1 (Legacy) | V2 (Current) | Notes |
|-------------|--------------|-------|
| `uom` | `unit_of_measure` | UOM system upgrade |
| `work_centers` | `work_center` | Naming standardization |
| `stock_item` | `material`, `material_lot`, `stock_ledger` | Material pipeline refactor |
| `stock_item_asset` | `material_asset` | Asset tracking refactor |
| `stock_item_lot` | `material_lot` | Lot tracking refactor |
| `routing` | `routing_graph`, `routing_node`, `routing_edge` | DAG routing system |
| `bom_line` | `bom`, `bom_item` | BOM structure refactor |
| `product_categories` | `product_category` | Naming standardization |
| `material_categories` | (none) | Removed, use `material.category` |

---

## Routing Classification (Per `routing_classification.md`)

### Routing V2 (DAG Routing) — KEEP
- ✅ `routing_graph`
- ✅ `routing_graph_version`
- ✅ `routing_graph_var`
- ✅ `routing_graph_favorite`
- ✅ `routing_graph_feature_flag`
- ✅ `routing_node`
- ✅ `routing_edge`
- ✅ `routing_set`
- ✅ `routing_step`
- ✅ `routing_audit_log`

### Routing V1 (Legacy) — DEPRECATE
- ❌ `routing` — **DEPRECATED** (replaced by DAG routing V2)

---

## Recommendations

### For Master Schema V2

1. **Include All V2 Tables:**
   - All tables listed in "V2 (Current Core)" section
   - All Routing V2 tables
   - All system tables

2. **Exclude All V1 Legacy Tables:**
   - `uom` (use `unit_of_measure` instead)
   - `stock_item`, `stock_item_asset`, `stock_item_lot` (use `material`, `material_lot`, `material_asset`, `stock_ledger` instead)
   - `routing` (use `routing_graph`, `routing_node`, `routing_edge` instead)
   - `bom_line` (use `bom`, `bom_item` instead)

3. **Ensure Idempotency:**
   - Use `migration_create_table_if_missing()` for all tables
   - Check table existence before creation

---

## Next Steps

1. ✅ **Phase 14.0-A Complete** — Inventory & Classification done
2. ⏳ **Phase 14.0-B** — Create Master Schema V2 migration (exclude V1 tables)
3. ⏳ **Phase 14.0-C** — Tenant bootstrap strategy

---

**Document Status:** ✅ Complete  
**Last Updated:** December 2025

