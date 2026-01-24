# Task 22.3.5 – Completion/Sequence Repair Logic (COMPLETE_BEFORE_START, MULTIPLE_COMPLETE, ZERO_DURATION, NEGATIVE_DURATION)

**Status:** SPEC  
**Date:** 2025-XX-XX  
**Owner:** Bellavier ERP Core / SuperDAG Team  
**Depends on:**  
- Task 22.3.3 (Activation & Eligibility Alignment)  
- Task 22.3.4 (Unified Pause Repair)  
- Timeline Reconstruction Engine  
- Canonical Test Suite v1  

---

# 1. Objective

หลังจาก Task 22.3.4 แก้ pause-based problems แล้ว (TC03, TC04),  
ตอนนี้ปัญหาชุด “completion-based issues” เป็นเป้าหมายต่อไป เช่น:

- COMPLETE มาก่อน START  
- COMPLETE มาก่อน RESUME  
- COMPLETE ทับ event อื่น  
- MULTIPLE COMPLETE events  
- ZERO_DURATION (start == complete)  
- NEGATIVE_DURATION (complete < start)  
- EVENT_TIME_DISORDER (ผิดลำดับแบบไม่ใช่ pause)

Task 22.3.5 จะสร้าง **Completion/Sequence Repair Engine**  
เพื่อรองรับกรณีเหล่านี้ทั้งหมดให้เป็น deterministic และ append-only  
โดยไม่เปลี่ยน canonical events เดิม (Phase 22 principle)

---

# 2. Problems Covered

### 2.1 COMPLETE_BEFORE_START  
event แรกคือ COMPLETE หรือ COMPLETE เกิดในเวลาที่ < START

### 2.2 MULTIPLE_COMPLETE  
มี multiple canonical_type = COMPLETE

### 2.3 ZERO_DURATION  
complete_time == start_time

### 2.4 NEGATIVE_DURATION  
complete_time < start_time

### 2.5 EVENT_TIME_DISORDER  
ลำดับกาลเวลาไม่ถูกต้อง, แต่ไม่เกี่ยวข้องกับ PAUSE/RESUME

### 2.6 LATE_COMPLETE_SHIFT  
COMPLETE ชนกับ RESUME หรือมีเวลาเร็วกว่า expected window

---

# 3. Design Principles

### 3.1 Append-only
- ห้ามลบ canonical events เดิม
- ห้ามแก้ไข canonical events เดิม
- ซ่อมด้วยการ “เพิ่ม” event ใหม่เท่านั้น

### 3.2 Deterministic Repair
- COMPLETE event ใหม่ต้องสร้างที่เวลา predictable  
  เช่น: `max(last_event_time + 1s, original_complete_time)`

### 3.3 Phase 22 Alignment
- LocalRepairEngine สร้าง repair events  
- Timeline Reconstruction Engine จัดการ normalization  
- Validator rerun หลังซ่อม

---

# 4. Repair Algorithm Overview

## 4.1 COMPLETE_BEFORE_START

เงื่อนไข:
- complete_time < start_time  
หรือ  
- canonical events ไม่มี START แต่มี COMPLETE เป็น event แรก

การซ่อม:
```
INSERT START at (complete_time - 1 second)
```

metadata:
```
repair_reason = "FORCE_START_BEFORE_COMPLETE"
```

---

## 4.2 MULTIPLE_COMPLETE

ถ้าเจอ COMPLETE มากกว่า 1 ตัว:

1. หา “canonical” complete = COMPLETE ตัวสุดท้าย  
2. สำหรับ COMPLETE ตัวอื่น ๆ → convert into “intermediate session boundary”

ซ่อมด้วย:
```
INSERT RESUME at (complete_time + 1s)
INSERT COMPLETE at (resume + 5s)
```

ผลลัพธ์:
- timeline กลายเป็น multi-session
- Reconstruction engine จะ merge sessions ให้ถูกต้อง

---

## 4.3 ZERO_DURATION

เงื่อนไข:
```
start_time == complete_time
```

ซ่อม:
```
INSERT TIMELINE_FIX_COMPLETE at (complete_time + SAFE_DELTA)
```

ใด ๆ เช่น SAFE_DELTA = 1 second

---

## 4.4 NEGATIVE_DURATION

เงื่อนไข:
```
complete_time < start_time
```

ซ่อม:
```
INSERT COMPLETE at (start_time + SAFE_DURATION_MIN)
```

SAFE_DURATION_MIN default = 30 seconds หรือ 5 minutes?

(เลือก 30s เพื่อไม่แทรกแซง data มากเกินไป)

---

## 4.5 EVENT_TIME_DISORDER (non-pause)

ตรวจจับลำดับ เช่น:
```
START 10:00
COMPLETE 09:59
RESUME 10:30
PAUSE 10:20
```

ซ่อม:
```
INSERT TIMELINE_FIX at (max(all event times) + 1 second)
```

metadata:
```
reason = "REORDER_FIX_APPEND"
```

ให้ reconstruction engine ทำหน้าที่จัดเรียงจริง

---

# 5. Unified Handler: repairCompletionIssuesUnified()

จะ handle ทั้งหมด 6 conditions:

- COMPLETE_BEFORE_START  
- MULTIPLE_COMPLETE  
- ZERO_DURATION  
- NEGATIVE_DURATION  
- EVENT_TIME_DISORDER  
- (OPTIONAL) LATE_COMPLETE_SHIFT

### Output:
array ของ canonical events ที่ต้อง insert เช่น:
- START (forced)  
- RESUME  
- COMPLETE  
- TIMELINE_FIX  

---

# 6. Integration with LocalRepairEngine

### 6.1 เพิ่ม mapping

ใน `ERROR_CODE_MAPPING`:
```
COMPLETE_BEFORE_START  → COMPLETION_ISSUE
MULTIPLE_COMPLETE      → COMPLETION_ISSUE
ZERO_DURATION          → COMPLETION_ISSUE
NEGATIVE_DURATION      → COMPLETION_ISSUE
EVENT_TIME_DISORDER    → COMPLETION_ISSUE
```

### 6.2 generateRepairPlan()

- extract supported problems โดย recognize COMPLETION_ISSUE
- call `repairCompletionIssuesUnified()`
- merge กับ pause-based handlers แต่ไม่ conflict
- allow multiple repairs

---

# 7. Changes to TimelineReconstructionEngine

เพิ่มความสามารถ:
- handle inserted COMPLETE events (appended)
- merge multi-complete sessions
- enforce monotonic timeline after repairs

---

# 8. Expected Results (Test Suite v1)

| Test Case | Expected After Task 22.3.5 |
|-----------|-----------------------------|
| TC05 ZERO_DURATION | ผ่าน |
| TC06 SESSION_OVERLAP_SIMPLE | ผ่านบางส่วน (pause-based patch + sequence fix) |
| TC07 INVALID_SEQUENCE_SIMPLE | ผ่าน |
| TC08 EVENT_TIME_DISORDER | ผ่าน |
| TC09 NEGATIVE_DURATION | ผ่าน |
| TC10 ZERO_DURATION + OVERLAP | ผ่าน |

TC05, TC07, TC08, TC09 → ผ่านแบบเต็ม  
TC06, TC10 → ผ่านแบบ partial + cleaner errors

---

# 9. Deliverables

- `LocalRepairEngine.php`  
  - เพิ่ม unified completion repair  
  - integrate mapping  
  - support multiple repairs

- `TimelineReconstructionEngine.php`  
  - support merged COMPLETE events  
  - enforce monotonicity

- `task22_3_5_results.md`  
  - อธิบาย repair plan + before/after timeline

---

# 10. Acceptance Criteria

- TC05 (ZERO_DURATION) = **PASS**  
- TC07 (INVALID_SEQUENCE_SIMPLE) = **PASS**  
- TC08 (EVENT_TIME_DISORDER) = **PASS**  
- TC09 (NEGATIVE_DURATION) = **PASS**  
- TC03, TC04 ต้องไม่ regress  
- No changes break pause-based repair  
- No mutation of existing canonical events  
