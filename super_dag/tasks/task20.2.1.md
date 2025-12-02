

# Task 20.2.1 — Timezone Normalization Audit Plan

## 🎯 Objective
Establish a canonical timezone handling model across the entire Bellavier ERP platform by auditing all PHP APIs, JS layers, database columns, and DAG routing components that rely on timestamps.

---

## 1) Canonical Timezone Standard

### Backend Standard
- All timestamps **stored in DB as UTC+0**.
- All backend (PHP) computations in **UTC only**.
- Conversion to tenant timezone occurs **only at the UI layer**.

### Frontend Standard
- JS receives UTC timestamps.
- UI displays time according to `tenant.timezone`.
- Any time sent to API must be normalized → UTC.

### Tenant-Level Settings
Each tenant must define:
- `timezone_name` (IANA format, e.g., `Asia/Bangkok`)
- `timezone_offset_minutes` (e.g., `420`)

---

## 2) Audit Scope

### Scope A — Core DAG / Routing
Audit components that use timestamps:
- `dag_routing_api.php`
- `DAGRoutingService`
- `EtaEngine`
- Token lifecycle fields:
  - `start_at`, `pause_at`, `resume_at`, `complete_at`

### Scope B — Workflow Logging
Review DB tables and related services:
- `workflow_token`
- `workflow_token_log`
- `job_route_log`
- `job_time_tracking`
- `operation_time_tracking`

### Scope C — API Endpoints (Full Scan)
Audit 42–55 endpoints including:
- `token_start`, `token_pause`, `token_resume`, `token_complete`
- `token_eta`, `node_eta`
- `routing_save`, `routing_publish`
- `job_create`, `job_update`, `job_assign`

### Scope D — Frontend (JavaScript)
Audit files:
- `graph_designer.js`
- `GraphHistoryManager.js`
- PWA time displays
- All UI timestamp filters & formatting

---

## 3) Audit Method

### Method 1 — Static Grep Scan
Search for risky patterns:
```
date(
new Date(
Asia/Bangkok
NOW(
current_timestamp(
```

### Method 2 — Static Code Review
Flag all timezone-unsafe code:
- Hardcoded timezone strings
- PHP `date_default_timezone_set()`
- JS `toLocaleString()` without TZ
- SQL functions returning server time

### Method 3 — DB Schema Review
Check if columns use:
- `datetime` (requires TZ normalization)
- `timestamp` (auto-converts → avoid)
- `datetime(6)` (preferred)

### Method 4 — DAG Engine Simulation
Trace timestamp flow through:
- token transitions
- SLA/ETA evaluations
- overdue computations

---

## 4) Deliverables

### Output Files Generated in 20.2.1
- `timezone_audit_report.md`
  - List of all files & endpoints using timestamps
  - Flagged status: `OK`, `NEED_FIX`, `CRITICAL`
- `timezone_reference_map.json`
  - Canonical mapping of TZ rules and tenant settings
- `timezone_migration_plan.md`
  - Defines required fixes for 20.2.2–20.2.3

---

## 5) Acceptance Criteria

- ✓ All API + JS + DB + DAG files audited
- ✓ Zero missing timestamp-related files
- ✓ Clear flagging for each file needing fix
- ✓ No functional changes yet (audit only)
- ✓ Output files created and stored in `/docs/super_dag/timezone/`

---

## ✔ Status
This file defines the plan for **Task 20.2.1** and is ready for execution.

ด้านล่างนี้คือ Task 20.2.1 – Unified Timezone Normalization Audit Plan
พร้อมรูปแบบ ไฟล์ markdown ที่พร้อมให้ Patch ลงใน docs/super_dag/tasks/task20.2.1.md ได้ทันทีผ่าน Oboe หากต้องการ

⸻

✅ Task 20.2.1 — Timezone Normalization Audit Plan (Full Specification)

🎯 Objective

กำหนดมาตรฐานกลาง (canonical standard) สำหรับการจัดการเวลาในระบบ ERP ทั้งหมด
ครอบคลุม API, PHP Backend, JS Frontend, Database storage และ DAG Engine

⸻

1) Timezone Canonical Standard (Target Goal)

Backend Canonical
	•	ทุกเวลาในระบบเก็บเป็น UTC+0 ในฐานข้อมูล
	•	คำนวณใน backend (PHP) เป็น UTC+0
	•	แสดงผล/แปลงเวลาเป็น timezone ของ tenant → ที่ UI เท่านั้น

Frontend Canonical
	•	JS รับข้อมูลเป็น UTC
	•	แสดงผลตาม tenant.timezone
	•	ส่งเวลาขึ้น API ต้องถูก normalize → UTC

Tenant-level TZ Definition

ในตาราง tenants ต้องมี field:

timezone_name (IANA) เช่น "Asia/Bangkok"
timezone_offset_minutes เช่น +420


⸻

2) Audit Scope

ตรวจสอบว่า API / Engine ใดบ้างใช้เวลาแบบไม่ normalize
(ปัจจุบันอาจใช้ Asia/Bangkok แบบ hardcode)

Scope A — Core DAG / Routing
	•	dag_routing_api.php
	•	DAGRoutingService
	•	Node ETA / SLA fields
	•	Action timestamps:
	•	token start_at
	•	pause_at
	•	complete_at
	•	resume_at

Scope B — Job Logs / Token Logs

ตารางที่ต้อง normalize:
	•	workflow_token
	•	workflow_token_log
	•	job_route_log
	•	job_time_tracking
	•	operation_time_tracking

Scope C — API Endpoints (Full Scan)

ประมาณ 42–55 endpoints ที่ต้อง audit:
	•	token_start
	•	token_pause
	•	token_resume
	•	token_complete
	•	node_eta
	•	token_eta
	•	routing_save
	•	routing_publish
	•	job_create
	•	job_update
	•	job_assign

(หมายเหตุ: audit ไม่ได้แก้ไขทันที จะรวมใน 20.2.2)

Scope D — Frontend JS

ไฟล์ที่ต้องตรวจ:
	•	graph_designer.js
	•	GraphHistoryManager.js
	•	POS/PWA time display
	•	Time-based filters
	•	UI columns ที่โชว์เวลา

⸻

3) Audit Method

(1) Automated Grep Search

ค้นหา patterns ที่อันตราย:

date()
new Date()
Asia/Bangkok
current_timestamp()
NOW()

(2) Static Code Scan

แท็กไฟล์ที่มี hard-coded TZ หรือไม่มีการ normalize

(3) Database Schema Check

ตรวจสอบ column types:
	•	datetime (ไม่ดี)
	•	timestamp (auto convert)
	•	datetime(6) default NULL ← ideal

(4) DAG Engine Flow Simulation

ตรวจเวลาที่มีผลต่อ ETA:
	•	token start/pause/resume/complete
	•	SLA computation
	•	overdue computation

⸻

4) Deliverables

20.2.1 Output Files
	1.	timezone_audit_report.md
	•	รายการไฟล์ทั้งหมดที่พบการใช้เวลา
	•	Flag: OK, NEED_FIX, CRITICAL
	2.	timezone_reference_map.json
	•	แผนที่ canonical timezone
	3.	timezone_migration_plan.md
	•	สรุปว่าใน Task 20.2.2–20.2.3 ต้องแก้ไฟล์ไหนบ้าง

⸻

5) Acceptance Criteria
	•	✓ Audit ครบทุกไฟล์ (PHP + JS + API + DB)
	•	✓ ไม่มีไฟล์ที่พลาดหรือตกหล่น
	•	✓ ระบุชัดว่าไฟล์ไหนใช้เวลาไม่ถูกต้อง
	•	✓ ระบุว่าต้องแก้อะไรใน Phase 20.2.2
	•	✓ สร้างรายงาน audit เรียบร้อย
	•	✓ ไม่มี code changes ใน Phase นี้ (audit-only)

⸻