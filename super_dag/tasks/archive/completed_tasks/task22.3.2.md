# Task 22.3.2 – Canonical Timeline Repair Test Suite v1  
**Status:** SPEC  
**Date:** 2025-XX-XX  
**Owner:** Bellavier ERP Core / SuperDAG Team  
**Depends on:**  
- Task 22.3.1 (Reconstruction Hardening)  
- Task 22.3 (Timeline Reconstruction v1)  
- Validator + TimeEventReader + LocalRepairEngine  

---

# 1. Objective

สร้าง **Test Suite มาตรฐาน** สำหรับตรวจสอบความถูกต้องของระบบ Canonical Events + Local Repair + Timeline Reconstruction โดยทดสอบ L1–L3 problems ทั้งหมดที่ระบบปัจจุบันรองรับ

Test Suite นี้ใช้สำหรับ:

- Dev manual testing  
- Regression test หลังแก้ Behavior / Engine  
- Debug tokens จริงจากโรงงาน  
- ยืนยันว่าระบบ self-healing + reconstruction ทำงาน *end-to-end*  

ไฟล์นี้เป็น SPEC สำหรับใช้ร่วมกับ dev tools:  
- `tools/dag_validate_cli.php`  
- `tools/dev_token_timeline.php`  
- `tools/dev_timeline_report.php`

---

# 2. Test Case Summary

| Code | Type | Description |
|------|------|-------------|
| TC01 | L1 | Missing Start |
| TC02 | L1 | Missing Complete |
| TC03 | L1 | Unpaired Pause |
| TC04 | L1 | No Canonical Events |
| TC05 | L2 | Zero Duration |
| TC06 | L2 | Session Overlap |
| TC07 | L2 | Invalid Sequence |
| TC08 | L2 | Event Time Disorder |
| TC09 | L3 | Negative Duration |
| TC10 | L2 Combo | Zero Duration + Overlap |

---

# 3. Detailed Test Cases

---

## **TC01 — Missing Start**

### Input Canonical Events
```
COMPLETE @ 10:00
```

### Expected Problems  
- `MISSING_START`

### Expected Repair  
```
START @ 09:59 (LocalRepairEngine)
```

### Expected Final Timeline  
- start = 09:59  
- complete = 10:00  
- duration > 0  

### Pass Criteria  
Validator: **pass**

---

## **TC02 — Missing Complete**

### Input  
```
START @ 10:00
```

### Expected Problems  
- `MISSING_COMPLETE`

### Expected Repair  
```
COMPLETE @ 10:01 (or flow_token.completed_at)
```

### Expected Final  
duration > 0  

### Pass Criteria  
Validator: **pass**

---

## **TC03 — Unpaired Pause**

### Input  
```
START @ 10:00  
PAUSE @ 10:05  
```

### Expected Repair  
```
RESUME @ 10:05:01  
COMPLETE @ flow_token.completed_at
```

### Pass Criteria  
Validator: **pass**

---

## **TC04 — No Canonical Events**

### Input  
(no canonical)

### Expected Repair  
```
START   @ flow_token.start_at  
COMPLETE @ flow_token.completed_at
```

### Pass Criteria  
Validator: **pass**

---

## **TC05 — Zero Duration**

### Input  
```
START @ 10:00  
COMPLETE @ 10:00
```

### Expected Repair  
```
COMPLETE @ 10:01 (ZERO_DURATION_FIX)
```

### Expected Final Timeline  
- start = 10:00  
- complete = 10:01  
- duration > 0  

### Pass Criteria  
No ZERO_DURATION after repair  
Validator: **pass**

---

## **TC06 — Session Overlap**

### Input  
```
START    @ 10:00  
PAUSE    @ 10:10  
RESUME   @ 10:20  
START    @ 10:15  ← overlap  
```

### Expected Problems  
- `SESSION_OVERLAP_SIMPLE`

### Expected Repair  
```
NODE_PAUSE @ 10:14:59 (pause A before B starts)
```

### Expected Final  
No overlaps  
Validator: **pass**

---

## **TC07 — Invalid Sequence**

### Input  
```
START @ 10:00  
START @ 10:05  (invalid)  
PAUSE @ 10:10
```

### Expected Problems  
- `INVALID_SEQUENCE_SIMPLE`

### Expected Repair  
Minimal deterministic fix (v1):
- ignore second START  
- continue timeline from first START  

### Pass Criteria  
Validator: **pass**

---

## **TC08 — Event Time Disorder**

### Input  
```
START @ 10:10  
COMPLETE @ 10:00  (disorder)
```

### Expected Problems  
- `EVENT_TIME_DISORDER`

### Expected Repair  
- COMPLETE adjusted to 10:11 (minimal fix)  
- or treated as ZERO_DURATION_FIX +1s

### Pass Criteria  
Validator: **pass**

---

## **TC09 — Negative Duration**

### Input  
```
START @ 10:10  
PAUSE @ 10:05  (invalid negative)
```

### Expected Repair  
- Shift PAUSE to START+1s  
OR  
- Drop invalid PAUSE and rebuild based on START/COMPLETE

### Pass Criteria  
Validator: **pass**

---

## **TC10 — Combined Case: Zero Duration + Overlap**

### Input  
```
START @ 10:00  
COMPLETE @ 10:00  
START @ 10:00  (overlap)
```

### Expected Repair  
1. ZERO_DURATION_FIX → COMPLETE @ 10:01  
2. SESSION_OVERLAP_FIX → PAUSE @ 09:59:59  

### Pass Criteria  
Validator: **pass**  
Timeline valid  
duration > 0  

---

# 4. Test Execution Instructions

### CLI Execution
```
php tools/dag_validate_cli.php validate-token --token=123 --json
```

### Dev Timeline View
```
/tools/dev_token_timeline.php?token=123
```

### Dev Aggregate Report
```
/tools/dev_timeline_report.php
```

---

# 5. Acceptance Criteria

- ทุก test case หลัง repair + reconstruction ต้องผ่าน validator  
- ZERO_DURATION, SESSION_OVERLAP_SIMPLE, INVALID_SEQUENCE_SIMPLE ต้องไม่ปรากฏหลังซ่อม  
- TimelineReader ต้องรายงาน duration > 0 สำหรับทุก case ที่มี START/COMPLETE  
- Reconstruction events ต้องมี repair metadata ครบ  
- dev token timeline view ต้องแสดง "after repair" timeline ที่อ่านรู้เรื่อง  

---

# 6. Notes

- Test Suite v2 จะเพิ่ม: multi-node, merge flows, split flows, high-concurrency behavior  
- Test Suite v1 เพียงพอสำหรับยืนยันความพร้อมของ Phase 22 Core
