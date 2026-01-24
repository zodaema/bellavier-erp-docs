# Task 30.3 Results: Component Parallel Flow Runtime (Split + Merge)

**Task:** Component Parallel Flow Runtime (Split + Merge)  
**Status:** ✅ **COMPLETE**  
**Date:** 2026-01-11  
**Duration:** 1 session

---

## 🎯 Objectives Achieved

- [x] Split: spawn component tokens แบบ idempotent
- [x] Component identity SSOT: ใช้ `flow_token.component_code` (ยังคง `metadata.component_code` เพื่อ backward compat)
- [x] Merge readiness ใช้ SSOT: `routing_node.parallel_merge_policy` รองรับ `ALL|ANY|AT_LEAST|TIMEOUT_FAIL`
- [x] เมื่อ merge ready: activate parent(final) token ที่ merge node และ mark component tokens เป็น merged

---

## 📋 Files Modified / Added

- `source/BGERP/Service/DAGRoutingService.php`
  - split: ใช้ `ParallelMachineCoordinator::handleSplit()` และ set parent token เป็น `waiting`
  - merge: เมื่อ component token arrive แล้ว evaluate merge และ activate parent token ที่ merge node
  - เพิ่ม hook ใน `routeToNode()` เพื่อ trigger merge evaluation อัตโนมัติเมื่อ component token เดินถึง merge node
- `source/BGERP/Dag/ParallelMachineCoordinator.php`
  - split idempotency: detect component tokens ที่ spawn แล้วสำหรับ parent เดิม
  - spawn component tokens: ใส่ `component_code` ลง column (SSOT) + metadata compat
  - merge policy: ประเมิน readiness ตาม arrival-at-merge-node semantics
  - marking: `ALL` → mark ทั้งหมด, `ANY/AT_LEAST` → mark เฉพาะ arrived tokens
- `tests/Integration/ComponentParallelSplitMergeRuntimeTest.php` (NEW)
  - ครอบ `ALL`, `ANY`, `AT_LEAST(1)` และการ activate parent ที่ merge node

---

## 🧪 Tests

✅ Passing:
- `vendor/bin/phpunit --testdox tests/Integration/ComponentParallelSplitMergeRuntimeTest.php`

---

## ✅ Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| Split ไม่สร้าง component tokens ซ้ำเมื่อ retry | ✅ |
| `flow_token.component_code` ถูก set เป็น SSOT | ✅ |
| merge readiness ตาม `parallel_merge_policy` | ✅ |
| parent(final) token ถูก activate ที่ merge node เมื่อ ready | ✅ |

---

**Next Task:** (Optional) 30.4 — Schema Hardening (ถ้าต้องการ mapping ถาวรใน routing_node)

