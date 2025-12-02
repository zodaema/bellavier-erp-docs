# Task 14.2 — Master Schema V2 (Final Cleanup & Legacy Purge)
**Status: PARTIALLY IMPLEMENTED (Phase A: Tracking-Only) — see “Current Implementation Status” below**

This document defines the *final and complete* cleanup required to finish the migration from Legacy Schema (V1) → Master Schema V2.  
The goal is to **fully remove legacy tables, legacy routing, legacy stock, legacy BOM, and all dual-write fallback logic**.

---
## Current Implementation Status (as of 14.1.8)

- The migration file `database/tenant_migrations/2025_12_master_schema_v2_cleanup.php` **already exists** and has been executed at least twice.
- **Phase A (Tracking-Only Mode)** is currently implemented:
  - Creates `legacy_cleanup_tracking` (or equivalent) bookkeeping structures.
  - Does **not** execute any `DROP TABLE` / `DROP COLUMN` statements.
  - All destructive SQL is either commented out or omitted.
- This means running the existing migration again is **safe** but also **non-destructive**.
- **Phase B (Destructive Cleanup)** — the actual dropping of legacy tables/columns — **must not** be added to the existing file anymore.  
  Instead, it will be implemented in a **new migration file** (e.g. `2025_12_master_schema_v2_cleanup_drop.php`) and a follow-up task (e.g. Task 14.3) once all legacy references are truly gone (14.1.7–14.1.12 complete).

The rest of this document still describes the **full target state** for Master Schema V2.  
Treat any “DROP …” instructions below as the **Phase B goal**, not as a description of what the current migration file already does.

---
## Preconditions สำหรับ Task 14.2 (Master Schema V2 Cleanup)

ก่อนเริ่ม Task 14.2 **ต้องผ่านทั้งหมดนี้แล้วเท่านั้น**:

1. ✅ Legacy READ queries ที่อ้าง `stock_item` ใน:
   - `leather_grn.php`
   - `MaterialResolver.php`
   - `bom.php`
   - `trace_api.php`
   - `leather_cut_bom_api.php`
   ถูก migrate มาใช้ `material` แล้ว (ดู Task 14.1.1–14.1.6)

2. ✅ BOM pipeline ใช้:
   - `bom_line` เป็น table หลัก (ยัง active)
   - ไม่มี JOIN กับ `stock_item` เหลืออยู่ (ยืนยันแล้วใน 14.1.6)

3. ✅ Component pipeline:
   - ไม่มีการ JOIN `stock_item` (ยืนยันแล้วใน 14.1.6)

4. ⚠️ สิ่งต่อไปนี้ **ยังไม่อนุญาตให้ลบ** ใน Task 14.2:
   - ตาราง `stock_item`
   - คอลัมน์ `id_stock_item` ใน tables อื่น
   - Routing V1 tables และ `LegacyRoutingAdapter`

> ถ้า static scan (grep / ripgrep) ยังพบ `stock_item` หรือ `id_stock_item` ใน query ที่เป็น WRITE / dual-write logic ให้เลื่อนการทำ Task 14.2 ออกไป และสร้าง Task 14.1.x เพิ่มเติมสำหรับ cleanup รอบใหม่ก่อน

> อัปเดตเพิ่มเติม: หลังจาก Task 14.1.7–14.1.8  
> เราเริ่มทะยอยลบ dual-write patterns และย้าย migration บางส่วนไปอยู่ในโฟลเดอร์ใหม่ (`active/`, `locked/`).  
> อย่างไรก็ตาม การ “DROP จริง” จะถูกเลื่อนไปไว้ใน Phase B (Task 14.3+) เพื่อไม่ให้ migration ที่รันใน Production ไปแล้วถูกเปลี่ยนพฤติกรรมภายหลัง

---

### หมายเหตุเรื่อง unit_cost

- ตอนนี้ทุกจุดที่เคยอ่าน `stock_item.unit_cost` ถูกเปลี่ยนเป็น `0` ชั่วคราว
- ห้ามให้ AI / Dev พยายาม "เดา" ต้นทุนจาก field อื่น (เช่น `material` หรือ `warehouse_inventory`) ใน Task 14.2
- จะมี Task แยก (Stock/Costing Phase) สำหรับออกแบบ **Material Pricing / Costing Engine** ที่ถูกต้อง

---

# 🚨 Section 1 — Objectives  
### PRIMARY GOAL  
Remove all legacy structures safely **without breaking production tenants**.

This includes:
1. Legacy Routing Tables  
2. Legacy BOM Tables  
3. Legacy Stock Tables  
4. Legacy Mapping Columns (e.g., id_stock_item)  
5. All V1 Code Paths  
6. All temporary adapters / compatibility layers

### SECONDARY GOAL  
Rebuild a *clean*, *stable*, and *explicit* Master Schema V2 that is:
- Fully normalized  
- Tenant-safe  
- ERP-consistent  
- Ready for bootstrap automation  
- Ready for super_dag + component pipeline + warehouse pipeline  
- 10-year safe guarantee  

---

# 🔥 Section 2 — Risk Kill Checklist (MANDATORY)

Before starting Task 14.2, the AI Agent must verify the following:

### ✔ No code reads from legacy routing (routing, routing_line)
- All `routing.php` actions except READ must be disabled
- V1 routing *must not be referenced anywhere*

### ✔ No code reads from legacy BOM (bom_line)
- All queries must be pointing to `component_bom_map` + `component_master`

### ✔ No code reads from legacy stock tables (stock_item, stock_item_lot)
- `material`, `material_lot`, `warehouse_inventory` must be the only sources

### ✔ No code depends on id_stock_item
- Dual-write must be removed
- `material_lot.id_stock_item` must be deleted safely

### ✔ No UI depends on V1 routing/BOM/stock
- job_ticket  
- pwa_scan  
- dag designer  
- leather_grn  
- leather_cut_bom_api  
ALL must point to V2.

### ✔ No API action touches legacy tables  
If any found → Abort and return a STOP error.

---

# 🛠 Section 3 — Final Removal Plan

> ⚠ Phase B Notice:  
> ขั้นตอนใน Section 3 นี้คือ **แผนลบจริง (Phase B)** ที่จะต้องไปอยู่ใน migration ใหม่ (เช่น `2025_12_master_schema_v2_cleanup_drop.php`)  
> ห้ามแก้ไขไฟล์ `2025_12_master_schema_v2_cleanup.php` เดิมให้มีคำสั่ง DROP เพิ่มเติม เพราะไฟล์นั้นถูก deploy และรันใน Production ไปแล้วในโหมด Tracking-Only

### 3.1 Remove Legacy Columns (14.2 Scope)

For Task 14.2, the ONLY confirmed-safe legacy column to drop is:

| Table        | Column        | Action                  |
|--------------|---------------|-------------------------|
| material_lot | id_stock_item | DROP (ALREADY DONE IN DEV/STAGING VIA 14.2 PHASE B)

All other `id_stock_item` columns in other tables (if any) MUST be treated as FUTURE work (Task 14.3+ or later) after a fresh scan confirms they are unused.
Do **NOT** generate DROP COLUMN statements for any other tables in 14.2.

### 3.2 Remove Legacy Tables (FUTURE CLEANUP, NOT 14.2 SCOPE)

> IMPORTANT:
> * As of Task 14.1.6, `bom_line` is STILL ACTIVE and MUST NOT be dropped.
> * Routing V1 tables (`routing`, `routing_line`) and stock tables (`stock_item*`) are still referenced indirectly (e.g. via LegacyRoutingAdapter or for historical data).
>
> Therefore, **Task 14.2 must not generate any DROP TABLE statements for these.**
> They are **candidates** for a FUTURE cleanup task (e.g. 14.3+), once all callers are migrated and feature flags are OFF.

Future candidates (DO NOT DROP in 14.2):

- `stock_item`
- `stock_item_asset`
- `stock_item_lot`
- `routing`
- `routing_line`
- `bom_line`
- `job_component_serial` (already manually dropped in some DEV envs; keep as a production cleanup candidate only)

### 3.3 Remove Legacy Code Paths
> NOTE: These file deletions are **FUTURE CLEANUP (14.3+)** and must only be executed after a fresh scan confirms zero references. Task 14.2 should only DOCUMENT these targets, not delete them yet.

Delete the following files (ONLY if the scan confirms no references):

- `source/routing.php`
- `source/stock_item.php`
- `source/legacy_bom.php` (if exists)
- ANY file containing V1 routing UI or logic

### 3.4 Remove Adapters & Dual-Write Guards
> NOTE: As with 3.3, this section describes **future deletion targets (14.3+)**. In Task 14.2, keep these adapters in place and only ensure the new systems (material, routing V2, etc.) are the primary path.

Remove the following:

- `LegacyRoutingAdapter.php`
- `MaterialResolver::resolveLegacyStockItem()`
- All COALESCE fallback patterns
- All INSERT dual-writes for id_stock_item
- All mapping arrays from stock → material

### 3.5 Create Migration File
**File (Phase B – DROP logic):** `database/tenant_migrations/2025_12_master_schema_v2_cleanup_drop.php`

> Reminder: the existing `database/tenant_migrations/2025_12_master_schema_v2_cleanup.php` is a **tracking-only** migration that has already been deployed. It MUST remain non‑destructive. All future DROP / CLEANUP SQL must go into the new `..._cleanup_drop.php` file instead.

The migration must:

1. Drop legacy tables SAFELY (IF EXISTS)
2. Drop legacy columns SAFELY (IF EXISTS)
3. Rebuild foreign keys
4. Rebuild indexes
5. Optimize schema via ANALYZE/OPTIMIZE
6. Be fully **idempotent** – running the migration multiple times must never fail or change results.
7. Be **tenant-safe** – all destructive operations must run in the tenant DB only, never in the core/platform DB.
8. Be **atomic per tenant** – where possible, wrap destructive operations in a transaction so a failure does not leave partial state.

---

# 🧪 Section 4 — Post-Cleanup Verification (MANDATORY)

After cleanup, the AI Agent must run a full scan:

### ✔ API Layer:  
- no “stock_item”
- no “routing”
- no “bom_line”
- no id_stock_item

### ✔ UI Layer:
- no V1 routing UI  
- no V1 BOM UI  
- no V1 Stock UI  

### ✔ DB Layer:
- no leftover FKs to legacy tables  
- no leftover columns  

### ✔ DAG:
- only DAG Designer + dag_routing_api.php

### ✔ Components:
- only component_master + component_serial + component_binding

### ✔ Warehouse:
- only material + material_lot + warehouse_inventory

---

# 🧱 Section 5 — FAIL-SAFE MECHANISMS

To protect production, the prompt must enforce:

### 1. Perform a SCAN before performing DROP  
If any reference is detected → ABORT immediately.

### 2. Use SAFE DROP syntax  
```
ALTER TABLE table_name DROP COLUMN column_name IF EXISTS;
DROP TABLE IF EXISTS table_name;
```

### 3. Code deletion ONLY after reference scan passes  
Never delete files before scanning.

### 4. No schema changes allowed outside migration file.

### 5. No API response shape changes allowed.

### 5.1 Multi-tenant & Environment Safeguards
- Run this migration **first on DEV / STAGING tenants** only; never start from production.
- Always execute via the existing `bootstrap_migrations` / tenant migration runner; **do not** run the SQL manually on the DB shell.
- Confirm that the current tenant is correct before running (avoid cross-tenant drops).
- Never delete or rewrite **business data** in non-legacy tables as part of this task – only drop legacy tables/columns that have been fully migrated.
- Log which tenants have successfully applied `2025_12_master_schema_v2_cleanup.php` for audit.

---

# 🧠 Section 6 — Precise Prompt for AI Agent
*(This is the exact prompt for Cursor / Auto Dev Agent)*

```
You are updating Bellavier Group ERP to Master Schema V2.
Your mission is to execute Task 14.2 with MAXIMUM safety and reliability.
Follow these rules STRICTLY:

1. Perform a full‑project SCAN.
2. If ANY reference to legacy routing/BOM/stock tables exists:
      → STOP and print ERROR REPORT only.
3. If SCAN PASSES:
      → Proceed to generate the migration file and code cleanup.
4. Do NOT delete anything before scan passes.
5. All destructive actions go ONLY into a **new** migration file (e.g.:
      database/tenant_migrations/2025_12_master_schema_v2_cleanup_drop.php
   ) — ห้ามแก้ไข `2025_12_master_schema_v2_cleanup.php` เดิมให้มีคำสั่ง DROP เพิ่มเติม
6. Do NOT modify API response shapes.
7. Do NOT modify DAG/Token/Session engines.
8. Do NOT modify Component pipeline.
9. Do NOT modify warehouse pipeline.
10. After cleanup, run a second SCAN and generate a verification report.
11. Operate **only** on tenant migrations and tenant databases – never touch the Core / Platform schema.
12. Do NOT delete or modify data rows in active business tables; this task is **schema cleanup only** for legacy structures.
13. If you detect that `2025_12_master_schema_v2_cleanup.php` already exists and has non-destructive behavior (tracking-only), you MUST keep it as-is and create a separate migration file for any future DROP/CLEANUP logic.
```

---

# ✅ Section 7 — Completion Criteria

Task 14.2 is COMPLETE when:

- ❌ No legacy tables remain **enabled in active code paths** (any remaining tables are archived and flagged for 14.3+ cleanup)
- ❌ No legacy columns remain **in active use** (any remaining columns are documented and unused, or already dropped via 14.2 Phase B)
- ❌ No V1 routing/BOM/stock code is used in normal execution flow (leftovers, if any, are guarded behind feature flags and marked for removal in 14.3+)
- ✔ Master Schema V2 is the only schema used in production code paths  
- ✔ All APIs still return 200 OK  
- ✔ PWA Scan and Job Ticket work normally  
- ✔ DAG Designer unaffected  
- ✔ Component pipeline unaffected  
- ✔ Warehouse pipeline unaffected  
- ✔ Session/Token engine unaffected  

---

# 🟢 Ready for Implementation
This file is the final authoritative specification.  
A Cursor Agent can now safely execute Task 14.2 using this prompt.
