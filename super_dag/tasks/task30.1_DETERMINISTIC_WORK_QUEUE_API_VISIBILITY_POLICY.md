# Task 30.1: Deterministic Work Queue API + Visibility Policy

**Status:** ✅ **COMPLETE**  
**Priority:** 🔴 **CRITICAL**  
**Phase:** 2 (Deterministic Runtime)  
**Estimate:** 1 day  
**Depends On:** Task 28 (Graph Versioning), Task 29 (Product Revision + pinned runtime), Task 30 (Overview)
**Results:** `docs/super_dag/tasks/results/task30.1.results.md`

---

## Goal

ทำให้ `Work Queue` และ `Token Detail` แสดงข้อมูล node/work-center แบบ deterministic โดย **อ่านจาก pinned graph snapshot** เมื่อ token/job ถูก pin (`graph_version`) และกำหนด policy การ “ซ่อน component tokens” ใน queue แบบ default-safe

---

## Problem Statement

ถ้า API อ่าน `routing_node` live table:
- job ที่ pin แล้วอาจ “เปลี่ยนชื่อ node / เปลี่ยน work_center / เปลี่ยน node_type” ตามการแก้ graph ในภายหลัง
- Work Queue จะไม่ deterministic → ทำให้ operator ทำงานผิดสถานี/ผิด behavior ได้

ถ้าไม่กำหนด visibility policy:
- component tokens อาจโผล่ใน queue ของ assembly/general → operator สับสนและทำงานผิด flow

---

## Scope

### Included
- `dag_token_api.php?action=get_work_queue`
- `dag_token_api.php?action=get_token_detail`
- นิยาม visibility policy สำหรับ `token_type='component'` (default hide)
- Integration smoke tests: “live node drift” แล้วยังคงคืน snapshot node fields + filtering ถูกต้อง

### Excluded
- UI redesign / UX improvements (ทำเฉพาะส่วนที่จำเป็นให้ข้อมูลถูกต้อง)

---

## Determinism Rules (Binding)

เมื่อ token/job มี `graph_version`:
- node fields ที่ต้องอ่านจาก snapshot:
  - `node_name`, `node_code`, `node_type`, `work_center_id` (และ derivative ที่ใช้เลือก behavior)
- ห้ามใช้ live:
  - `routing_node`, `routing_edge` เพื่อ resolve node context

---

## Visibility Policy (Default-Safe)

### Default Behavior
- Work Queue API ต้อง **ไม่ส่งคืน** tokens ที่ `token_type='component'` โดย default

### Optional Override (Explicit Only)
- อนุญาตให้ include component tokens เฉพาะเมื่อ request ระบุชัด (เช่น `include_component_tokens=1`)
  - หมายเหตุ: ชื่อ param เป็นข้อกำหนดของ task นี้—ต้อง implement แบบ validate ชัดเจน

---

## Deliverables

- [ ] Patch `source/dag_token_api.php`
  - [ ] `get_work_queue` prefer snapshot node fields เมื่อมี instance/graph_version
  - [ ] `get_token_detail` prefer snapshot node fields เมื่อมี instance/graph_version
  - [ ] Default filter: exclude `token_type='component'`
  - [ ] Override param (explicit) เพื่อ include component tokens
- [ ] Tests
  - [ ] `tests/Integration/WorkQueueSnapshotNodeDeterminismSmokeTest.php` (หรือ test ใหม่ถ้าจำเป็น)
  - [ ] `tests/Integration/WorkQueueVisibilityPolicyTest.php` (component hidden by default, included when explicit)

---

## Acceptance Criteria

- [ ] แก้ `routing_node` live แล้ว Work Queue / Token Detail ของ job pinned **ไม่เปลี่ยน** (ยังเท่า snapshot)
- [ ] Default work queue **ไม่โชว์** `token_type='component'`
- [ ] ถ้า request ระบุ override อย่างถูกต้อง → สามารถ include component tokens ได้
- [ ] API response ใช้มาตรฐาน `{ok: true/false}` และ error มี `app_code`

---

## Implementation Notes

- ต้องใช้ `GraphSnapshotRuntimeService` เป็นทางเดียวในการอ่าน node metadata เมื่อ pinned
- ต้อง validate input ด้วย `RequestValidator::make(...)`
- ต้องใส่ rate limiting ด้วย `RateLimiter::check(...)` หลัง auth
- ต้องมี maintenance mode check + execution time tracking ตามมาตรฐาน API

---

**Next Task:** 30.2 (Deterministic Behavior Execution Context)

