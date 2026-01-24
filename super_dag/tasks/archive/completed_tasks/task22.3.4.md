# Task 22.3.4 – Unified Pause/Resume Repair Logic (UNPAIRED_PAUSE, PAUSE_BEFORE_START, BAD_FIRST_EVENT)

**Status:** SPEC  
**Date:** 2025-XX-XX  
**Owner:** Bellavier ERP Core / SuperDAG Team  
**Depends on:**  
- Task 22.1 (Local Repair Engine v1)  
- Task 22.2 (Repair Event Model & Log)  
- Task 22.3 (Timeline Reconstruction v1)  
- Task 22.3.1 (Reconstruction Hardening)  
- Task 22.3.2 (Canonical Test Suite v1)  
- Task 22.3.3 (Activation & Eligibility Alignment)

---

# 1. Objective

หลังจาก Task 22.3.3:

- **MISSING_START** ผ่านแล้ว (TC01) → Engine เริ่มทำงาน
- แต่ **UNPAIRED_PAUSE** (TC03) และ **NO_CANONICAL_EVENTS** (TC04) ยังไม่ซ่อม
- Validator รุ่นใหม่มี error codes:  
  - `UNPAIRED_PAUSE`  
  - `PAUSE_BEFORE_START`  
  - `BAD_FIRST_EVENT` (pause-based invalid first event)

ปัญหาคือ logic ปัจจุบันของ LocalRepairEngine สำหรับ pause/resume ยัง **ไม่ unified** และยังไม่รองรับ interaction กับ Timeline Reconstruction engine

ดังนั้น Task 22.3.4 มีเป้าหมาย:

- สร้าง **Unified Pause Repair Engine** ที่จัดการเคส pause-based problems ทั้งหมด
- ทำให้ Test Suite:  
  - **TC03** ผ่าน  
  - วางรากฐานให้ TC09 ผ่านในงานถัดไป
- Align pause/ resume events กับ timeline reconstruction semantics

---

# 2. Problems (Based on Test Suite Logs)

จากการรัน Test Suite:

```
TC03: UNPAIRED_PAUSE
→ No repair plan generated (reason: NO_REPAIRS_GENERATED)

TC07: UNPAIRED_PAUSE
TC09: PAUSE_BEFORE_START, UNPAIRED_PAUSE
```

แปลว่า:

1. Engine “เห็น” UNPAIRED_PAUSE แต่ไม่ซ่อม  
2. Handler `repairUnpairedPause()` อาจไม่ถูกเรียก หรือถูกเรียกแต่ return empty  
3. เคส pause ฟอร์มต่าง ๆ ยังไม่ map รวมกัน  
4. ไม่ได้ integrate กับ reconstruction (session creation)

---

# 3. Scope

## 3.1 ปรับ Error Mapping (ใน LocalRepairEngine)

เพิ่มใน `ERROR_CODE_MAPPING`:

```
UNPAIRED_PAUSE          → UNPAIRED_PAUSE
PAUSE_BEFORE_START      → UNPAIRED_PAUSE
BAD_FIRST_EVENT         → UNPAIRED_PAUSE   (ถ้า event แรกเป็น pause/complete)
INVALID_SEQUENCE_SIMPLE → UNPAIRED_PAUSE   (pause-based)
```

เหตุผล:

- ปัญหา pause-based ทั้งหมด root cause เดียวกัน → missing resume, invalid first event, pause without start

---

## 3.2 สร้าง Unified Handler: `repairUnpairedPauseUnified(tokenId, nodeId, events)`

### เป้าหมาย:

- ให้ handler นี้ handle เคส pause-based ทั้งหมด:
  - UNPAIRED_PAUSE
  - PAUSE_BEFORE_START
  - BAD_FIRST_EVENT (ถ้า pause/complete มาเป็น event แรก)
- ให้ได้ผลลัพธ์ deterministic
- ทำงานแบบ append-only (ตาม Phase 22 principles)

---

# 4. Unified Pause Repair Algorithm

### Input:
- canonical events array (sorted)
- validation problems (mapped)
- token timeline (from TimeEventReader)

---

## Step 1 — ตรวจ event แรกว่าผิดหรือไม่

If first event canonical_type ∈ { PAUSE, RESUME, COMPLETE } → invalid start

Expected fix:

```
INSERT NODE_START at (first_event_time - 1 second)
```

payload:

```
repair_reason = "FORCE_START_BEFORE_PAUSE"
```

---

## Step 2 — กรณี PAUSE ก่อน START

Validator error: `PAUSE_BEFORE_START`

Fix:

```
INSERT NODE_START at (pause_time - 1 second)
```

---

## Step 3 — กรณี UNPAIRED_PAUSE (pause มีแต่ไม่มี resume)

Fix:

```
INSERT NODE_RESUME at (pause_time + 1 second)
```

If resume_time >= complete_time:

→ shift complete_time +1s

---

## Step 4 — สร้าง session แบบปลอดภัย

หลังซ่อม:

- session ที่ pause/resume จะกลายเป็น:

```
START —> PAUSE —> RESUME —> COMPLETE
```

- duration จะถูกคำนวณใหม่โดย Timeline Reconstruction engine
- ไม่สร้าง sessions ซ้ำซ้อนเอง (ให้ reconstruction ทำ)

---

# 5. Expected Output Format (RepairEventModel)

ทุก event ใช้:

```
RepairEventModel::buildRepairMetadata(
   TYPE_TIMELINE_RECONSTRUCT,
   null,
   [...original problems...],
   ENGINE_TIMELINE_RECONSTRUCTION
)
```

canonical events created:

- NODE_START (optional + deterministic)
- NODE_RESUME
- NODE_COMPLETE (shift case)

---

# 6. Integration with Reconstruction Engine

หลังสร้าง repair plan:

- LocalRepairEngine → applyRepairPlan  
- THEN call TimelineReconstructionEngine → rebuild timeline cleanly  
- Re-run validator  
- TC03 ต้อง “Valid: YES”

---

# 7. Example Expected Behavior (TC03)

### Before:

```
START 10:00
PAUSE 10:05
(no resumes)
```

### Repair Plan:

```
ADD_RESUME:
  RESUME @ 10:05:01
```

### After:

Validator sees:

- session: [10:00 → 10:05:01]
- no L1 problems  
→ Valid = YES

---

# 8. Expected Behavior (TC07 / TC09)

- ไม่หวังให้ TC07/TC09 ผ่านในงานนี้  
- แต่ pause-based part ควร “ถูกซ่อมบางส่วน”  
- Work for next tasks (22.3.5 / 22.3.6)

---

# 9. Deliverables

1. `LocalRepairEngine.php`
   - เพิ่ม unified repair handler
   - ปรับ error mapping
   - ปรับ generateRepairPlan ให้ recognize pause-based problems

2. Future extension:
   - integrate forced START + forced COMPLETE in reconstruction

3. `task22_3_4_results.md`

---

# 10. Acceptance Criteria

- TC03 ผ่านแบบเต็มรูปแบบ  
  - มี repair plan  
  - timeline หลังซ่อม valid  
- TC07/09 ไม่ต้องผ่านทั้งหมด แต่ต้อง:
  - ลดจำนวน errors  
  - แสดง repair plan ที่เกี่ยวข้องกับ pause

- ไม่มีการ break behavior ของ:
  - MISSING_START
  - NO_CANONICAL_EVENTS
  - ZERO_DURATION
  - SESSION_OVERLAP_SIMPLE

- No side effects with reconstruction engine
