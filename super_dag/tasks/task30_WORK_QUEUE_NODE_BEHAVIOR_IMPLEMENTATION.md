# Task 30: Work Queue (Node Behavior) + Component Parallel Flow Runtime Implementation

**Status:** ✅ **COMPLETE**  
**Priority:** 🔴 **CRITICAL**  
**Category:** Execution Layer / Deterministic Runtime / Operator UX / Data Integrity  
**Date:** January 2026

**Results:**
- `docs/super_dag/tasks/results/task30.1.results.md`
- `docs/super_dag/tasks/results/task30.2.results.md`
- `docs/super_dag/tasks/results/task30.3.results.md`

---

## Executive Summary

**Goal:** ทำให้ Work Queue + Node Behavior “deterministic” 100% (อ่าน context จาก pinned graph snapshot) และเริ่ม implement runtime สำหรับ **Component Parallel Flow** (split/merge) บนโครงสร้าง token ปัจจุบัน

**Why Important:**
- ป้องกัน “live graph drift” ทำให้ job ที่กำลังรันอยู่เปลี่ยน behavior/work-center แบบไม่ตั้งใจ
- ทำให้การทำงานในหน้างานสอดคล้องกับ `graph_version` ที่ pin แล้ว (repeatable, audit-friendly)
- รองรับ “natural flow” ของ Hatthasilpa: ทำ component บางชิ้นก่อนได้ ไม่ต้องรอครบทุกชิ้นก่อนเริ่มงานบางสถานี

**Reference Documents:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` (Behavior execution rules + contracts)
- `docs/developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md` (Frontend/back contract)
- `docs/developer/03-superdag/03-specs/SPEC_WORK_CENTER_BEHAVIOR.md` (node_mode/work_center → execution_mode)
- `docs/super_dag/01-concepts/COMPONENT_PARALLEL_FLOW.md` (Concept)
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` (Spec + SSOT)

**Primary Code Areas (Expected):**
- `source/dag_token_api.php` (work queue/detail endpoints)
- `source/BGERP/Dag/BehaviorExecutionService.php` (behavior execution + node fetch)
- `source/BGERP/Dag/NodeBehaviorEngine.php` (resolve node_mode / execution_mode)
- `source/BGERP/Service/DAGRoutingService.php` (snapshot routing + split/merge)
- `source/BGERP/Service/TokenLifecycleService.php` (token creation/binding helpers)
- Tests: `tests/Integration/*`

---

## Core Invariants (Non-Negotiable)

### Determinism / Pinned Snapshot
- เมื่อ job/token มี `graph_version` (pinned) แล้ว:
  - **Node context MUST come from graph snapshot** ผ่าน `GraphSnapshotRuntimeService`
  - ห้ามอ่าน `routing_node` / `routing_edge` live tables เพื่อ resolve `node_name/node_code/node_type/work_center_id`

### SSOT (Single Source of Truth)
- **Component identity SSOT:** `flow_token.component_code` (เมื่อ `token_type='component'`)
- **Merge policy SSOT:** `routing_node.parallel_merge_policy` (+ `parallel_merge_timeout_seconds`, `parallel_merge_at_least_count`)
- **Work Queue visibility SSOT (ชั่วคราว):** rule ใน API (ไม่โชว์ component tokens โดย default ต่อ assembly/general queue)

### Data Integrity / Enterprise API Rules
- Tenant isolation: ใช้ `tenant_db()` เท่านั้น
- SQL: prepared statements เท่านั้น (zero-tolerance)
- API structure: `switch($action)` + top-level try/catch + `json_success/json_error`
- Mandatory helpers: maintenance mode check, request validation, rate limiting, execution time tracking, headers (`X-Correlation-Id`, `X-AI-Trace`)
- State changes: ใช้ idempotency เมื่อเป็น create/submit แบบเสี่ยงซ้ำ

---

## Scope

### Included
- ทำให้ Work Queue + Token Detail + Behavior Execution อ่าน node/work-center context จาก **pinned snapshot** เมื่อมี `graph_version`
- กำหนด policy การ “ซ่อน component tokens” ใน Work Queue แบบ default-safe
- เริ่ม implement runtime สำหรับ “Component Parallel Flow”:
  - split: สร้าง component tokens จาก final token ที่เข้า parallel split node
  - merge readiness: ประเมิน readiness ตาม `parallel_merge_policy`
  - merge action: ส่ง final token ต่อเมื่อพร้อม (พร้อม marker ใน metadata ตามแนวคิดที่ตกลง)

### Excluded (Not in this task)
- UI redesign ใหญ่/ปรับ UX เชิงลึก (ยกเว้นสิ่งจำเป็นเพื่อให้ Work Queue ทำงาน)
- การย้าย “metadata target” ไปเป็น “columns จริง” ทั้งหมด (จะทำเมื่อสรุป schema แล้ว)

---

## Task Breakdown (Sub-task Files)

งาน Task 30 ถูกแยกเป็นไฟล์ย่อยเพื่อให้ implement ทีละส่วนได้ชัดเจน:

| Task | Title | File |
|------|-------|------|
| **30.1** | Deterministic Work Queue API + Visibility Policy | `docs/super_dag/tasks/task30.1_DETERMINISTIC_WORK_QUEUE_API_VISIBILITY_POLICY.md` |
| **30.2** | Deterministic Behavior Execution Context | `docs/super_dag/tasks/task30.2_DETERMINISTIC_BEHAVIOR_EXECUTION_CONTEXT.md` |
| **30.3** | Component Parallel Flow Runtime (Split + Merge) | `docs/super_dag/tasks/task30.3_COMPONENT_PARALLEL_FLOW_RUNTIME_SPLIT_MERGE.md` |
| **30.4** | Schema Hardening (Node-to-Component Mapping) — Optional | `docs/super_dag/tasks/task30.4_SCHEMA_HARDENING_NODE_TO_COMPONENT_MAPPING.md` |

---

## Agent Instructions (Execution Rules)

1. ต้องยึด “pinned snapshot determinism” เป็นหลักทุกจุดที่อ่าน node/work-center context
2. ห้ามทำให้ Work Queue แสดง component tokens โดย default
3. ห้ามสร้าง SSOT ใหม่ (เช่น `metadata.component_code` เป็นหลัก) — ให้ใช้คอลัมน์ปัจจุบัน
4. ทุกจุดที่ “create/spawn” ให้มี idempotency guard
5. เพิ่ม/แก้ tests ให้ครอบก่อนปิดงาน

---

**Next Task:** 30.1 (`task30.1_DETERMINISTIC_WORK_QUEUE_API_VISIBILITY_POLICY.md`)

