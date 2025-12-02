# Task 14.1 — Live Database Schema Snapshot

**Date:** December 2025  
**Phase:** 14.1 — Deep System Scan  
**Status:** ✅ COMPLETED  
**Tenant:** `maison_atelier` (bgerp_t_maison_atelier)

---

## Summary

This document contains a snapshot of the live database schema, identifying all tables, their relationships, and legacy tables that should not exist in new tenants.

---

## Database Overview

**Tenant:** `maison_atelier`  
**Total Tables:** 121 tables  
**Database:** `bgerp_t_maison_atelier`

---

## Legacy Tables Found

### V1 Legacy Tables (Should NOT be in Master Schema V2)

1. ✅ **`uom`** — Legacy UOM table
   - **Status:** EXISTS in DB
   - **Replacement:** `unit_of_measure`
   - **Code Usage:** None (safe to deprecate)

2. ✅ **`stock_item`** — Legacy stock item table
   - **Status:** EXISTS in DB
   - **Replacement:** `material`, `material_lot`, `stock_ledger`
   - **Code Usage:** 5 files, 11 references (HIGH RISK)

3. ✅ **`stock_item_asset`** — Legacy stock asset table
   - **Status:** EXISTS in DB
   - **Replacement:** `material_asset`
   - **Code Usage:** Unknown (needs verification)

4. ✅ **`stock_item_lot`** — Legacy stock lot table
   - **Status:** EXISTS in DB
   - **Replacement:** `material_lot`
   - **Code Usage:** Unknown (needs verification)

5. ✅ **`bom_line`** — Legacy BOM line table
   - **Status:** EXISTS in DB
   - **Replacement:** `bom` + `bom_item`
   - **Code Usage:** 5 files, 8 references (HIGH RISK)

6. ✅ **`routing`** — Legacy routing table (V1)
   - **Status:** EXISTS in DB
   - **Replacement:** `routing_graph`, `routing_node`, `routing_edge` (V2)
   - **Code Usage:** 3 files, 7 references (HIGH RISK)

---

## V2 Current Tables (Must be in Master Schema V2)

### Master Data (V2)
- ✅ `unit_of_measure` — Current UOM system
- ✅ `work_center` — Current work center system
- ✅ `warehouse` — Warehouse master
- ✅ `warehouse_location` — Warehouse location master
- ✅ `product_category` — Product category
- ✅ `material` — Material master (V2)
- ✅ `material_lot` — Material lot tracking
- ✅ `material_asset` — Material asset tracking

### Production System (V2)
- ✅ `job_ticket` — Job ticket (canonical)
- ✅ `job_task` — Job task (canonical)
- ✅ `job_ticket_serial` — Serial tracking
- ✅ `job_ticket_status_history` — Status history
- ✅ `wip_log` — WIP log (canonical)
- ✅ `task_operator_session` — Operator session
- ✅ `mo` — Manufacturing order

### DAG Token System (V2)
- ✅ `flow_token` — Flow token
- ✅ `token_assignment` — Token assignment
- ✅ `token_event` — Token event log
- ✅ `token_work_session` — Token work session
- ✅ `token_join_buffer` — Token join buffer
- ✅ `token_spawn_log` — Token spawn log
- ✅ `node_assignment` — Node assignment
- ✅ `node_instance` — Node instance
- ✅ `job_graph_instance` — Job graph instance

### Routing V2 (DAG Routing) — Per `routing_classification.md`

**Status:** ✅ **ALL ROUTING V2 TABLES EXIST**

1. ✅ `routing_graph` — DAG graph (V2)
2. ✅ `routing_graph_version` — Graph versioning
3. ✅ `routing_graph_var` — Graph variables
4. ✅ `routing_graph_favorite` — User favorites
5. ✅ `routing_graph_feature_flag` — Feature flags
6. ✅ `routing_node` — Graph node (V2)
7. ✅ `routing_edge` — Graph edge (V2)
8. ✅ `routing_set` — Routing set
9. ✅ `routing_step` — Routing step
10. ✅ `routing_audit_log` — Audit log

**Note:** `routing_graph_draft` may exist but was not explicitly checked.

### Inventory & Stock (V2)
- ✅ `stock_ledger` — Central stock ledger (V2) — **ACTIVE USE**
- ✅ `warehouse_inventory` — Warehouse inventory
- ✅ `inventory_transaction` — Inventory transaction
- ✅ `inventory_transaction_item` — Transaction items

**Stock Ledger Usage:**
- `leather_grn.php` — Creates stock movements (GRN_LEATHER)
- `stock_card.php` — Reads stock ledger for reporting
- `transfer.php` — Creates stock movements (TRANSFER)
- `issue.php` — Creates stock movements (ISSUE)
- `grn.php` — Creates stock movements (GRN)
- `adjust.php` — Creates stock movements (ADJUST)

### BOM System (V2)
- ✅ `bom` — Bill of Materials (V2)
- ✅ `bom_item` — BOM items (V2)

### Quality Control (V2)
- ✅ `qc_inspection` — QC inspection
- ✅ `qc_inspection_item` — QC inspection items
- ✅ `qc_fail_event` — QC fail event

### Serial System (V2)
- ✅ `serial_generation_log` — Serial generation log
- ✅ `serial_link_outbox` — Serial link outbox
- ✅ `serial_quarantine` — Serial quarantine

### Assignment System (V2)
- ✅ `assignment_log` — Assignment log
- ✅ `assignment_decision_log` — Decision log
- ✅ `assignment_notification` — Notifications
- ✅ `assignment_plan_job` — Job planning
- ✅ `assignment_plan_node` — Node planning

### Team System (V2)
- ✅ `team` — Team master
- ✅ `team_member` — Team members
- ✅ `team_availability` — Team availability
- ✅ `operator_availability` — Operator availability
- ✅ `work_center_team_map` — Work center ↔ Team mapping
- ✅ `member_leave` — Leave tracking

### Purchase System (V2)
- ✅ `purchase_rfq` — Purchase RFQ
- ✅ `purchase_rfq_item` — RFQ items
- ✅ `supplier_score` — Supplier scoring

### Product System (V2)
- ✅ `product` — Product master (V2)
- ✅ `product_asset` — Product asset

### System Tables (V2)
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

## Table Count Summary

| Category | V2 Tables | V1 Legacy Tables | Total |
|----------|-----------|------------------|-------|
| Master Data | 8 | 1 (`uom`) | 9 |
| Production | 7 | 0 | 7 |
| DAG Token | 9 | 0 | 9 |
| Routing | 10 (V2) | 1 (`routing` V1) | 11 |
| Inventory | 4 | 3 (`stock_item*`) | 7 |
| BOM | 2 | 1 (`bom_line`) | 3 |
| QC | 3 | 0 | 3 |
| Serial | 3 | 0 | 3 |
| Assignment | 5 | 0 | 5 |
| Team | 6 | 0 | 6 |
| Purchase | 3 | 0 | 3 |
| Product | 2 | 0 | 2 |
| System | 10 | 0 | 10 |
| **TOTAL** | **~75** | **6** | **121** |

---

## Foreign Key Relationships

### Legacy Tables with Foreign Keys

1. **`stock_item`** — May have FKs to:
   - `uom` (legacy)
   - Other legacy tables

2. **`bom_line`** — May have FKs to:
   - `product` (V2)
   - `stock_item` (legacy)
   - `bom` (V2) — Check if exists

3. **`routing`** — May have FKs to:
   - `product` (V2)
   - `work_center` (V2)

**Note:** Full FK analysis requires detailed schema inspection.

---

## AUTO_INCREMENT Status

**Note:** AUTO_INCREMENT values were not captured in this snapshot.  
**Recommendation:** Check AUTO_INCREMENT values before creating Master Schema V2 to ensure no conflicts.

---

## Recommendations

### For Master Schema V2

1. **Include All V2 Tables:**
   - All tables listed in "V2 Current Tables" section
   - All Routing V2 tables (10 tables)
   - All system tables

2. **Exclude All V1 Legacy Tables:**
   - `uom` ✅ (safe to exclude)
   - `stock_item`, `stock_item_asset`, `stock_item_lot` ⚠️ (must migrate code first)
   - `bom_line` ⚠️ (must migrate code first)
   - `routing` ⚠️ (must migrate code first)

3. **Verify Before Deprecation:**
   - Check `stock_item_asset` usage
   - Check `stock_item_lot` usage
   - Verify all code migrated from V1 → V2

---

**Document Status:** ✅ Complete  
**Last Updated:** December 2025

