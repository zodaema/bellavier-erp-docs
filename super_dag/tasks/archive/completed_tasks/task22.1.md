# Task 22.1 – Local Repair Engine v1 (Phase 22)

**Status:** SPEC  
**Date:** 2025-XX-XX  
**Owner:** Bellavier ERP Core / SuperDAG Team  
**Depends on:** Phase 22 Blueprint, Tasks 21.1–21.8  
**Scope:** Local, token-level repair under controlled rules  
**Environment:** Dev, Staging (Production only with flag)

---

# 1. Objective

สร้าง **Local Repair Engine v1** เพื่อซ่อม canonical events / timeline ของ **หนึ่ง token ต่อครั้ง** (local scope) ตามกติกาที่ควบคุมอย่างเข้มงวด

Local Repair Engine จะเป็นพื้นฐานให้:

- ระบบซ่อม event ที่หายไป
- ซ่อม session pair (pause/resume)
- ซ่อม timeline ที่ผิดปกติ
- เติม canonical events ตามกติกา
- ทำงานแบบ reversible + audit trail

> นี่คือ “ซ่อมทีละ token อย่างแม่นยำ” ก่อนจะไป batch repair (Task 22.4)

---

# 2. Constraints / Safety / Invariants

Local Repair Engine ต้องปฏิบัติตามกติกาต่อไปนี้:

### 2.1 Closed Context Only (สำคัญที่สุด)
Local Repair Engine ทำงานเฉพาะเมื่อ token:

- อยู่สถานะ `complete` หรือ `cancelled`
- ไม่มี event ใหม่กำลังเข้ามา (behavior engine idle)
- ไม่กำลังถูก process โดยคน

### 2.2 Non-Destructive / Append-Only
- ห้ามลบ canonical event เดิม  
- ห้ามแก้ canonical event เดิม  
- “ซ่อม” = เพิ่ม *Repair Event* (22.2 จะสร้าง audit model)
- ถ้าต้อง override timeline ให้สร้าง canonical event ใหม่ ไม่แก้ของเดิม

### 2.3 Validate → Propose → Apply
Local Repair Engine ต้องมี 3 เฟส:

1. อ่าน canonical events
2. วิเคราะห์ปัญหา → สร้าง `repair_plan`
3. ถ้า admin/engine อนุมัติ → apply repair_plan

### 2.4 No Hidden Mutation
- ทุกการซ่อมต้องบันทึกลง repair log (Task 22.2)
- “ไม่มีการแอบแก้ข้อมูลเงียบ ๆ”

### 2.5 Single Responsibility
Local Repair Engine:
- ไม่ซ่อม batch  
- ไม่ซ่อม tokens ที่ยัง active  
- ไม่ reconstruct timeline (ไปทำใน Task 22.3)

---

# 3. Scope ของ Local Repair Engine v1

Local Repair Engine v1 จะรองรับการซ่อมระดับ L1 ตาม blueprint:

### 3.1 Missing Event Fix (ระดับง่าย)
กรณี:

- COMPLETE มี แต่ START ไม่มี → เติม NODE_START (เวลา = event COMPLETE - min_duration)
- มี PAUSE แต่ไม่มี RESUME → เติม RESUME เวลาเดียวกับ COMPLETE
- มี RESUME แต่ไม่มี PAUSE → เติม PAUSE ก่อน RESUME
- มี canonical START แต่ไม่มี COMPLETE (แต่ token complete ใน legacy) → เติม COMPLETE จาก `flow_token.completed_at`

### 3.2 Invalid Ordering Fix
กรณี:

- START มาอยู่หลัง PAUSE  
- RESUME มาอยู่ก่อน START  
- COMPLETE มาอยู่ก่อน START  

→ เสนอ reorder canonical events (ด้วย “synthetic order_time” เพื่อไม่แตะ event_time เดิม)

### 3.3 Duration Repair (แบบเบื้องต้น)
กรณี:

- timeline duration = 0 ms แต่ token duration มีใน legacy  
→ เสนอเติม session เดียว as fallback

### 3.4 Session Normalization
กรณี:

- เกิด session overlap แบบง่าย (rule 10)  
→ ปิด session แรกเร็วขึ้นหรือเปิด session ใหม่ให้ไม่ทับกัน

> Local Repair Engine v1 **ยังไม่ reconstruct timeline** (ระดับ L2)  
> เฉพาะแก้กรณีง่าย ๆ ที่ไม่ขัดกติกา logic framework

---

# 4. Integration กับ Validator

Local Repair Engine ใช้ `CanonicalEventIntegrityValidator` เป็นตัวชี้ว่า “ปัญหาอะไรควรซ่อมได้”  

และในบางจุด **ต้อง patch Validator เพิ่ม** (แทรกจากรีวิว Task 21.8):

### 4.1 เพิ่ม Safety ใน checkLegacySync()
Patch ใน 22.1:
- ถ้า `$stmt = $db->prepare()` คืน false → return warning “LEGACY_SYNC_CHECK_FAILED”
- ห้ามโยน fatal error / ห้ามล้ม validator

### 4.2 Session Overlap (ongoing session)
ตามที่พบในรีวิว:
- ถ้า session A ongoing (to = null) + session B เริ่มใหม่ → ควรถือว่า “overlap”  
Patch ใน 22.1:
- เพิ่ม rule เสริม: ถ้า A.to == null และ B.start < now() → report warning “ONGOING_SESSION_OVERLAP”

### 4.3 Empty events should not return valid=true
Patch:
- ถ้า canonical events ว่าง → คืนปัญหา “NO_CANONICAL_EVENTS” severity = error

> ทั้งหมดนี้จะถูก patch ใน 22.1 พร้อมกับสร้าง LocalRepairEngine

---

# 5. Repair Plan Model

สร้างโครงสร้าง repair plan ดังนี้:

```json
{
  "token_id": 123,
  "problems_detected": [...],
  "repairs": [
    {
      "type": "ADD_MISSING_START",
      "canonical_event": {
        "canonical_type": "NODE_START",
        "event_time": "2025-01-01 10:00:00",
        "payload": { ... }
      }
    },
    {
      "type": "ADD_REVERSE_PAUSE",
      ...
    }
  ],
  "notes": "...",
  "status": "proposed"
}
```

---

# 6. Implementation Plan

### 6.1 Create class `LocalRepairEngine.php`
Location: `source/BGERP/Dag/LocalRepairEngine.php`

### 6.2 Methods

#### `generateRepairPlan($tokenId)`
- อ่าน canonical events
- เรียก validator
- วิเคราะห์ rule ที่ซ่อมได้
- สร้าง repair_plan object

#### `applyRepairPlan($repairPlan)`
- INSERT canonical events ใหม่ (ผ่าน TokenEventService)
- สร้าง repair event log (task22.2)
- กลับมารัน validator → ถ้ายังไม่ผ่าน → rollback

#### `canRepairProblem($problem)`
รองรับเฉพาะ problems ต่อไปนี้ใน v1:

- MISSING_START  
- MISSING_COMPLETE  
- UNPAIRED_PAUSE  
- INVALID_SEQUENCE_SIMPLE  
- SESSION_OVERLAP_SIMPLE  
- ZERO_DURATION  
- NO_CANONICAL_EVENTS

#### `simulateRepair($tokenId)`
- รีเทิร์น repair_plan แบบ simulation (ไม่ commit)

---

# 7. Feature Flag

สร้าง flag ใหม่:

- `CANONICAL_SELF_HEALING_LOCAL`

ค่า default = 0 ทุก tenant

เมื่อปิด flag:
- LocalRepairEngine ให้ทำงานใน simulation mode เท่านั้น

เมื่อเปิด flag:
- อนุญาต apply repair_plan

---

# 8. Deliverables

- `LocalRepairEngine.php`  
- แพตช์ Validator 3 จุดที่ระบุข้างต้น  
- Unit test / manual test  
- `task22_1_results.md`  

---

# 9. Acceptance Criteria

1. LocalRepairEngine สร้าง repair_plan ที่ถูกต้องสำหรับ token ที่มีปัญหาง่าย ๆ  
2. applyRepairPlan ทำงานแบบ append-only  
3. Validator patch ทั้ง 3 ข้อถูก implement  
4. ไม่มี token เดิมถูกแก้ event เดิม (ทุกอย่างผ่าน canonical “repair events”)  
5. dev timeline tool แสดงผลหลัง repair ถูกต้อง  
6. Feature flag บังคับการทำงานได้ตามคาด
