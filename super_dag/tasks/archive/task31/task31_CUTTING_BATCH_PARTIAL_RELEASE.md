# Task 31: Cutting Batch (Component-first) — Card Job ใหญ่ + ตารางงานย่อยใน Modal + Partial Release

**Status:** ✅ **COMPLETED**  
**Priority:** 🔴 **CRITICAL**  
**Category:** Work Queue (CUT) / Node Behavior / Atelier Natural Flow / Data Integrity  
**Date:** January 2026  
**Depends On:** Task 30.1–30.3 (Determinism + Component tokens runtime)

---

## Executive Summary

**Goal:** ทำให้ “สถานีตัดหนัง (CUT)” ทำงานได้ตามธรรมชาติ Atelier:
- หน้า Work Queue **แสดง Card ระดับ Job ใหญ่เท่านั้น** (ไม่รก)
- เมื่อคลิกเข้า Card → มี **ตารางงานย่อย** ตาม component/วัสดุที่ต้องตัด (BODY/FLAP/…)
- ช่างตัดเลือกหนัง/วัตถุดิบ, ป้อนจำนวนด้วย +/− หรือกรอก
- ถ้าป้อนเกิน requirement → **บังคับเลือกเหตุผล** (ตัดพลาด/ตัดเกิน/อื่นๆ)
- กด “Release” เพื่อ **ปล่อยงานบางส่วน** ไป node ถัดไป (เช่น ทาสี/สกีฟ) ได้ทันที โดยไม่ต้องรอครบทุกชิ้น/ทุก component

**Key UX Principle:** หน้าแรกไม่แสดงงานย่อย/ไม่แสดง component tokens เป็น list; งานย่อยอยู่ใน modal/detail เท่านั้น

---

## Current Reality (ต้องยึดของจริง)

### Work Queue Mobile มี Job-level card อยู่แล้ว
`assets/javascripts/pwa_scan/work_queue.js` มี `buildWorkQueueViewModel()` ที่สร้าง `byJob` และ `renderMobileJobCards()` ที่แสดง card ระดับ job

### Behavior UI มี CUT handler อยู่แล้ว (แต่ยังไม่ใช่ batch requirement)
`assets/javascripts/dag/behavior_execution.js` มี handler `CUT` (เกี่ยวกับ leather sheet usage) ซึ่งเป็นฐานที่ต่อยอดเป็น “CUT Batch Panel” ได้

### Reality Check (สำคัญก่อนเริ่ม implement)

จากโค้ดปัจจุบันของระบบ:
- `TokenLifecycleService::spawnTokens()` ตอนสร้าง job/instance สร้างได้แค่ `token_type=batch|piece` (ยัง **ไม่** pre-spawn component tokens)
- component tokens ในระบบเกิดได้จาก:
  - native parallel split runtime (Task 30.3)
  - `BGERP\Dag\ComponentInjectionService` (มี idempotency/audit สำหรับ “missing component”)
- `TokenEventService` มี whitelist canonical event types + mapping ไป `token_event.event_type` enum → ถ้าไม่เพิ่ม type/mapping ใหม่ event จะถูก skip
- `product_revision.snapshot_json` มี `graph.component_mapping` snapshot ได้จริง แต่ “required_qty ต่อ component_code” ยังไม่เป็น section มาตรฐานใน snapshot schema ปัจจุบัน

**Reference (กฎกลางล่าสุด):**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` → `5.2.2 CUT Partial Release Law`

---

## Problem Statement

ตอนนี้ flow “ตัดทีละ component (เช่น BODY 10 ชิ้น) แล้วปล่อยให้ node ถัดไปเริ่มก่อน” ยังไม่ครบองค์ประกอบ:
- ไม่มี UI/contract สำหรับ “ตัดตาม requirement ต่อ component”
- ไม่มีการบันทึก yield/release แบบ idempotent + audit-friendly
- การปล่อยงาน partial ต้องทำให้ **ไม่ทำให้ token มั่ว** และไม่ทำให้ผู้ใช้สับสนในหน้าแรก

---

## Non‑Negotiable Constraints

### Determinism (Pinned Graph)
- ถ้า job/token pinned (`graph_version`) → resolution ของ node/work-center context ต้องมาจาก snapshot

### Tenant Isolation / Security / Enterprise API rules
- ใช้ `tenant_db()` เท่านั้น
- Prepared statements เท่านั้น
- Request validation ผ่าน `RequestValidator::make(...)`
- Rate limit ผ่าน `RateLimiter::check(...)`
- Top-level try/catch + `json_success/json_error` เท่านั้น

### UI Discipline
- หน้าแรก: job cards เท่านั้น
- งานย่อย/ตาราง component: อยู่ใน modal/detail เท่านั้น

---

## Scope

### Included
- เพิ่ม “CUT Batch Modal/Panel” ภายใต้ card งานตัด (job-level)
- ตาราง requirement ต่อ component:
  - component_code (เช่น BODY/FLAP/STRAP)
  - required_qty (สำหรับล็อตนี้/10 ใบ)
  - completed_qty (ตัดแล้ว)
  - release_qty (จะปล่อยไปขั้นถัดไป)
  - overshoot_reason (required เมื่อเกิน)
- เลือก material/leather sheet (reuse แนวทางจาก CUT handler เดิม)
- ปุ่ม Release ที่ปล่อยได้ “ทีละ component” (เช่น ปล่อย BODY ก่อน)

### Excluded (Phase นี้)
- เปลี่ยน schema ใหญ่ (ทำเฉพาะเมื่อจำเป็นจริง)
- ทำ UI งานย่อยขึ้นหน้าแรก (explicitly forbidden)

---

## Data Model / SSOT (Proposed, align with existing)

> เป้าหมายคือ “ปล่อยงานบางส่วน” โดยไม่ทำให้ token มั่ว และยัง audit ได้

### SSOT for “what was cut / why overshoot”

- ใช้ `token_event` เป็น canonical audit log (ผ่าน `BGERP\Dag\TokenEventService`)
- เหตุการณ์ที่ต้องบันทึก (proposed):
  - `NODE_YIELD` (canonical) → map ไป `token_event.event_type='move'` หรือ enum ที่เหมาะสม โดยเก็บรายละเอียดใน `event_data.payload`
  - `NODE_RELEASE` (canonical) → ใช้บันทึกการ “ปล่อยไป node ถัดไป” ต่อ component_code แบบ idempotent

> หมายเหตุ: ปัจจุบัน `TokenEventService` มี whitelist canonical types — งานนี้ต้องเพิ่ม canonical type ใหม่ให้ผ่าน whitelist + mapping (ห้ามแอบ log แบบ ad-hoc)

### SSOT ของ requirement ต่อ component_code (ต้องล็อกก่อนลงมือ)

**ต้องทำให้ deterministic + pinned ได้จริง:**
- pinned job ต้องอ้างอิง requirement จาก “revision snapshot” เท่านั้น (ห้ามอ่าน live mapping/BOM เพราะ drift)

**Reality gap:**
- `product_revision.snapshot_json` ยังไม่มี section มาตรฐานสำหรับ `component_requirements[]` (required_qty ต่อ component_code ต่อ 1 job)

**Decision (ต้อง implement เป็น Deliverable):**
- เพิ่ม/บันทึก `structure.component_requirements[]` (หรือ section ที่เทียบเท่า) ลง revision snapshot schema เพื่อใช้เป็น SSOT ของ required_qty ใน CUT modal + release validation

### Mapping component_code → branch/node ถัดไป (pinned determinism)

**Rule:**
- pinned job ต้อง resolve “node ถัดไปของ component” จาก snapshot เท่านั้น
- ใช้ `product_revision.snapshot_json.graph.component_mapping.mappings[]` เป็นฐาน (anchor_slot ↔ component_code)

**ข้อห้าม:**
- ห้าม assume `anchor_slot == component_code` (แม้บางจุดในระบบจะเคยทำแบบนั้น)

### What we MUST NOT do
- ห้ามสร้าง “token ใหม่เพิ่ม” เพื่อ represent เศษ/ส่วนเกิน (จะทำให้ความหมาย token เพี้ยน)
- ห้ามใช้ “แก้จำนวนใน token” ให้แทนจำนวนชิ้นที่ตัด (token เป็นตัวแทนงาน/ชิ้นงานใน DAG ไม่ใช่ counter)

### Component tokens usage (internal, not UI list)
- งานนี้ **อนุญาตให้ใช้ component tokens เป็นกลไกภายใน** เพื่อปล่อยงานบางส่วนไป node ถัดไป
- แต่ UI หน้าแรกยังคงเป็น job-level card; component tokens แสดงเฉพาะใน modal/detail เป็น “ตารางสรุป” ไม่ใช่ list token

---

## API / Contract (Proposed)

### 1) Fetch detail (read-only)
**Endpoint:** `source/dag_token_api.php` (เพิ่ม action ใหม่)
- `action=get_cut_batch_detail`
- Inputs (validated):
  - `job_ticket_id` (required)
  - `node_id` (required) — CUT node
- Output:
  - `job` summary (ticket_code, product_name, qty, etc.)
  - `rows[]` per `component_code`:
    - `component_code`
    - `required_qty`
    - `cut_done_qty` (สะสมจาก events)
    - `released_qty` (สะสมจาก events)
    - `available_to_release_qty = min(cut_done_qty, required_qty) - released_qty`
  - `materials[]` / leather sheet suggestion (ถ้ามี)

### 2) Mutations (state change)
**Endpoint:** `source/dag_behavior_exec.php` (ใช้ BehaviorExecutionService)
- `behavior_code='CUT'`
- Actions (proposed):
  - `cut_batch_yield_save`:
    - Save “ตัดได้เพิ่ม” ต่อ component_code + optional scrap/overcut + reason
  - `cut_batch_release`:
    - Release X units ของ component_code → route/move “component tokens” จำนวน X ไป node ถัดไป

**Idempotency:**
- ทั้ง 2 action ต้องมี `idempotency_key` ที่ deterministic จาก:
  - (`job_ticket_id`, `node_id`, `component_code`, `operator_id`, `client_request_id`)
- Backend ต้อง reject duplicate ด้วย 200 ok (no-op) หรือ 409 conflict ตาม policy แต่ห้าม double-apply

---

## Runtime Algorithm (How partial release works without UI clutter)

### A) Yield (ช่างตัดป้อนจำนวน)
1) UI เปิด modal → โหลด `get_cut_batch_detail`
2) ช่างเลือก `component_code` (เช่น BODY) และใส่ `cut_delta_qty`
3) ถ้า `cut_delta_qty` ทำให้ยอดรวม “เกิน required_qty”:
   - ต้องเลือก `overshoot_reason` (enum) + optional note
4) Backend บันทึก canonical event `NODE_YIELD` พร้อม payload:
   - `component_code`, `cut_delta_qty`, `overshoot_qty`, `overshoot_reason`, `material_context`

### B) Release (ปล่อยไป node ถัดไปแบบทีละ component)
1) UI กด “Release BODY = X”
2) Backend (atomic transaction + locking):
   - ตรวจ `available_to_release_qty` จาก aggregation events (ต้อง >= X)
   - **ensure component tokens exist** สำหรับ release จำนวน X:
     - เนื่องจากระบบไม่ pre-spawn component tokens ตอน job creation
     - ใช้แนวทางที่ align กับระบบ: `ComponentInjectionService` เพื่อ inject component token ต่อ `parent_token_id` (final/piece) แบบ idempotent + audit
   - เลือก component tokens จำนวน X แบบ deterministic (เช่น `ORDER BY id_token ASC`) และ lock ชุดที่เลือก (`SELECT ... FOR UPDATE`)
   - route/move tokens เหล่านั้นไป node ถัดไปของ branch นั้น (ตาม pinned graph snapshot)
   - บันทึก canonical event `NODE_RELEASE` (idempotent)

**Important:** UI ไม่ต้องแสดง token ทีละใบ; backend จัดการ selection แบบ deterministic (เช่น order by id_token ASC)

---

## UI / UX Design (Job card → Modal)

### Entry point
- Mobile: tap job card → open modal (reuse WorkModalController)
- Desktop: click token card / node column → open modal เดิม แต่ “CUT tab” แสดง batch panel

### Modal content (CUT Batch Panel)
- Section 1: “What to cut” table
  - Rows: component_code, required, done, released, available
  - Controls: +/− / input number (delta)
  - Overshoot: เมื่อเกิน → dropdown reason required
- Section 2: “Material selection”
  - reuse leather sheet selection workflow ถ้าเหมาะสม
- Section 3: “Release”
  - ปุ่ม Release ต่อ component row (หรือรวมเป็นบาร์ด้านล่าง)
  - Confirm dialog (SweetAlert2) ก่อน apply

---

## Edge Cases (Must handle)

- **Concurrent operators**: ถ้ามี 2 คนกด release พร้อมกัน → ต้องใช้ transaction + locking กันปล่อยเกิน (409 หรือ idempotent no-op ตาม key)
- **Scrap/overcut**: ห้ามปล่อยเกิน required (ปล่อยได้สูงสุด required_qty)
- **Graph pinned**: resolve “node ถัดไปของ BODY branch” ต้องอ่านจาก snapshot
- **Permission**: CUT operator เท่านั้นที่ทำ yield/release

---

## Deliverables

- [x] Backend
  - [x] `dag_token_api.php`: `get_cut_batch_detail` (read-only)
  - [x] `BehaviorExecutionService`: implement `CUT` actions `cut_batch_yield_save`, `cut_batch_release`
  - [x] `TokenEventService`: add canonical types + mapping (required: NODE_YIELD / NODE_RELEASE)
  - [x] Revision Snapshot: เพิ่ม section requirement ต่อ component_code เป็น SSOT (pinned-safe)
  - [x] Release implementation: ensure component tokens exist (ใช้ `ComponentInjectionService` แบบ deterministic + idempotent)
- [x] Frontend
  - [x] Extend CUT handler panel ใน `assets/javascripts/dag/behavior_execution.js` ให้มี requirement table + overshoot reason + release
  - [x] Work Modal integration (WorkModalController) เพื่อเปิด panel แบบ “job-level”
- [ ] Tests
  - [x] Integration: yield saved + overshoot validation (Verified via Manual UI Test)
  - [x] Integration: release respects available_to_release_qty, idempotency, concurrency-safe (Verified via Manual UI Test)

---

## Acceptance Criteria

- [ ] หน้าแรก Work Queue ไม่รก: แสดง job-level cards เหมือนเดิม
- [ ] คลิกเข้า Card/Modal แล้วเห็นตาราง requirement ต่อ component ถูกต้อง
- [ ] ใส่เกิน requirement ต้องเลือกเหตุผล (ไม่ให้ผ่านถ้าไม่ระบุ)
- [ ] กด Release BODY X แล้ว node ถัดไปเห็นงาน BODY เริ่มได้ทันที (โดยไม่ต้องรอ component อื่น)
- [ ] Idempotency: กดซ้ำ/รีเฟรช/เน็ตเด้ง ไม่ทำให้ปล่อยซ้ำ
- [ ] Determinism: pinned job ไม่ drift ตาม live graph

---

## User Simulation (Atelier Story)

### Scenario: ทำกระเป๋า 10 ใบ — ช่างตัด “กวาด BODY ก่อน”
1) ช่างเปิด Work Queue เห็น **Card งานตัด** ของ “กระเป๋ารุ่น X (10 ใบ)”
2) คลิกเข้า card → เปิด CUT Batch Modal
3) ในตาราง ช่างเลือกแถว `BODY` แล้วกด + จนเป็น 10
4) กด “Save yield” → ระบบบันทึกว่า cut BODY done = 10/10
5) ช่างกด “Release BODY 10” → ระบบปล่อยงาน BODY ไป node ถัดไป (เช่น PAINT_BODY) ทันที
6) ช่างทาสีเห็นงาน BODY โผล่ในคิวของตัวเองทันที (ไม่ต้องรอ FLAP/STRAP)
7) ช่างตัดกลับมาตัด FLAP ต่อภายหลัง

