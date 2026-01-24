# Task 30.1 Results: Deterministic Work Queue API + Visibility Policy

**Task:** Deterministic Work Queue API + Visibility Policy  
**Status:** ✅ **COMPLETE**  
**Date:** 2026-01-11  
**Duration:** 1 session

---

## 🎯 Objectives Achieved

- [x] Work Queue / Token Detail ใช้ node metadata จาก **pinned snapshot** เมื่อ job/token pinned
- [x] เพิ่ม policy: **ซ่อน component tokens โดย default** และเปิดได้เฉพาะเมื่อ request ระบุชัด
- [x] เพิ่ม tests ครอบ policy + กัน regression

---

## 📋 Files Modified / Added

- `source/dag_token_api.php`
  - เพิ่ม request validation สำหรับ `get_work_queue` (รวม `include_component_tokens`)
  - Default filter: ไม่คืน `token_type='component'` (override ได้ด้วย `include_component_tokens=1`)
  - เพิ่ม field ใน payload: `token_type`, `component_code`, `parent_token_id`
- `tests/Integration/WorkQueueVisibilityComponentTokenTest.php` (NEW)
  - test default hide + explicit include

---

## 🧪 Tests

✅ Passing:
- `vendor/bin/phpunit --testdox tests/Integration/WorkQueueVisibilityComponentTokenTest.php`
- `vendor/bin/phpunit --testdox tests/Integration/WorkQueueSnapshotNodeDeterminismSmokeTest.php`

---

## ✅ Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| Work queue/token detail ของ job pinned ไม่ drift ตาม live routing_node | ✅ |
| Default work queue ไม่โชว์ component tokens | ✅ |
| include component tokens ได้เมื่อระบุ param แบบ explicit | ✅ |

---

**Next Task:** 30.2 (Deterministic Behavior Execution Context)

