# Task 30.2: Deterministic Behavior Execution Context

**Status:** ✅ **COMPLETE**  
**Priority:** 🔴 **CRITICAL**  
**Phase:** 2 (Deterministic Runtime)  
**Estimate:** 1 day  
**Depends On:** Task 30.1 (API determinism baseline), Graph Snapshot Runtime availability
**Results:** `docs/super_dag/tasks/results/task30.2.results.md`

---

## Goal

ทำให้การ execute behavior ของ token/job ที่ pinned (`graph_version`) ใช้ node/work-center context จาก **graph snapshot** แบบ deterministic 100% และ enforce invariant สำคัญที่เกี่ยวกับ execution mode

---

## Problem Statement

ถ้า `BehaviorExecutionService` หรือ `NodeBehaviorEngine` อ่าน `routing_node`/`work_center` live:
- behavior ที่เลือก (หรือ UI template) อาจเปลี่ยนจากการแก้ live data
- execution mode อาจ drift (เช่น node_mode/work_center เปลี่ยน) → ส่งผลต่อ validation และการบันทึก event

---

## Scope

### Included
- Deterministic node fetch (prefer snapshot) ใน layer execute
- Consistent context builder:
  - `node_mode` (from work_center)
  - `line_type` (from job_ticket)
  - `execution_mode` resolved from `(node_mode, line_type)`
- Integration test ที่ยืนยัน “live drift ไม่กระทบ execution”

### Excluded
- เพิ่ม behavior handlers ใหม่ (ทำเฉพาะ determinism + guardrails)

---

## Determinism Rules (Binding)

เมื่อมี instanceId/graph_version:
- Node metadata MUST come from snapshot:
  - `node_code`, `node_name`, `node_type`, `work_center_id`, behavior binding fields ที่ runtime ใช้
- ห้ามอ่าน `routing_node` live เพื่อเอาข้อมูลเดียวกันนี้

---

## Deliverables

- [ ] Patch `source/BGERP/Dag/BehaviorExecutionService.php`
  - [ ] `fetchNode(...)` หรือ method ที่ใช้ resolve node ให้ prefer snapshot เมื่อมี instanceId
  - [ ] Lazy init `GraphSnapshotRuntimeService` (ถ้าต้องใช้)
- [ ] Verify/patch `source/BGERP/Dag/NodeBehaviorEngine.php`
  - [ ] Build execution context แบบ canonical (ไม่อ่าน live node meta เมื่อ pinned)
  - [ ] Resolve execution_mode deterministic จาก `(node_mode, line_type)`
- [ ] Tests
  - [ ] `tests/Integration/BehaviorExecutionSnapshotNodeGuardTest.php` (หรือ test ใหม่ถ้าจำเป็น)

---

## Acceptance Criteria

- [ ] แก้ live `routing_node` (name/code/type/work_center) แล้ว execute บน pinned job **ยังใช้ค่าจาก snapshot**
- [ ] execution_mode ที่ resolve ได้ “repeatable” เมื่อ run ซ้ำ (ไม่ขึ้นกับ live drift)
- [ ] ทุก error ส่ง `app_code` ชัดเจน (ไม่ silent)

---

## Implementation Notes

- ในกรณีไม่มี graph_version (un-pinned / legacy): อนุญาต fallback ไป live ได้ แต่ต้องชัดว่าเป็น “non-deterministic mode”
- หลีกเลี่ยง cross-DB join ใน prepared statements (ถ้าต้องอ่าน core + tenant ให้ใช้ 2-step merge)

---

**Next Task:** 30.3 (Component Parallel Flow Runtime)

