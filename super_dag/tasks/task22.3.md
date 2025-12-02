# Task 22.3 – Timeline Reconstruction v1  
**Status:** SPEC  
**Date:** 2025-XX-XX  
**Owner:** Bellavier ERP Core / SuperDAG Team  
**Depends on:**  
- Phase 22 Blueprint  
- Task 22.1 (Local Repair Engine v1)  
- Task 22.2 (Repair Event Model & Log)  
- Validator + TimeEventReader  

---

# 1. Objective

สร้างระบบ **Timeline Reconstruction v1** เพื่อซ่อม canonical timeline ที่เสียรูป (L2/L3 problems) โดยอาศัย canonical events + metadata จาก Local Repair Engine เพื่อสร้าง "canonical timeline ที่สมบูรณ์ที่สุดเท่าที่ข้อมูลอนุญาต" โดยมีหลักการว่า:

- ใช้ canonical events ที่มีอยู่เป็นหลัก  
- ใช้ logic reconstruction เติมจุดที่หาย  
- ยังเป็น append-only (ไม่แก้ event เดิม)  
- บันทึก reconstruct events ลง token_event พร้อม repair-log  
- ไม่ผูกกับ feature flag (ในช่วง build)  
- สามารถ reconstruct timeline ให้ validator ผ่านได้ในระดับสูง

> Timeline Reconstruction v1 = Local Repair Engine v2  
> แต่ทำงานระดับ L2/L3 เช่น sequence ผิด → เติม event / ปิด session / rebuild durations

---

# 2. Problems to Solve

จาก Phase 21–22 ตอนนี้ระบบยังซ่อมได้เฉพาะ L1:

- Missing start  
- Missing complete  
- Unpaired pause  
- No canonical events  

แต่ยังมี L2/L3 problems ที่ยังไม่ได้ซ่อม เช่น:

1. **INVALID_SEQUENCE_SIMPLE**  
   - START → START  
   - RESUME → PAUSE → START  
   - COMPLETE ซ้อนผิดลำดับ

2. **SESSION_OVERLAP_SIMPLE**  
   - session A (start–pause)  
   - session B (start–pause) ที่ทับกัน

3. **ZERO_DURATION**  
   - start_time == complete_time  
   - มักเกิดจาก operator กดเร็วหรือ event sync หาย

4. **NEGATIVE_DURATION / OUT_OF_ORDER**  
   - event_time ย้อนหลัง / out-of-order

เป้าหมายของ 22.3 คือ “สร้าง Timeline Reconstruction Engine v1” ที่ซ่อม problems ข้างบนแบบ minimal / deterministic / append-only

---

# 3. Scope (High-Level)

22.3 แบ่งเป็น 4 ส่วน:

### 3.1 Core Timeline Reconstruct Engine  
สร้าง class ใหม่:  
`source/BGERP/Dag/TimelineReconstructionEngine.php`

ความสามารถขั้นต้น:

- อ่าน canonical events แบบ raw  
- อ่าน timeline baseline จาก TimeEventReader  
- วิเคราะห์ L2/L3 problems  
- สร้าง “proposed timeline” ที่ถูกต้องที่สุด  
- คืนรายการ event ที่ควรเพิ่ม

### 3.2 Integration กับ LocalRepairEngine  
LocalRepairEngine จะเรียก TimelineReconstructionEngine อัตโนมัติถ้า:

- token eligible (completed/scrapped)  
- ไม่มี L1 problems  
- แต่ validator ยัง report L2/L3 problems

### 3.3 Append Reconstruction Events  
สร้าง canonical events ใหม่ เช่น:

- NODE_START (rebuild)  
- NODE_RESUME (re-align)  
- NODE_COMPLETE (re-align)  
- OVERRIDE_TIME_FIX (optional)

และเพิ่ม metadata repair เช่น:

```
'repair' => {
   'type' : 'TIMELINE_RECONSTRUCT',
   'version' : 'v1',
   'by' : 'TimelineReconstructionEngine',
   'original_problems': [...]
}
```

### 3.4 Repair Log Integration  
ทุก reconstruction ต้องเข้า:

`flow_token_repair_log`

snapshot (before/after) ใช้ TimeEventReader  
metadata แบบ RepairEventModel

---

# 4. Patches Included in 22.3 (สำคัญ)

### 4.1 รวม Patch จากการตรวจไฟล์

**(A) เติม metadata ให้ handler MISSING_START**  
LocalRepairEngine ต้องใส่ RepairEventModel metadata เหมือนตัวอื่น

**(B) ผ่อน/ตัด feature flag ใน applyRepairPlan()**  
เพราะช่วง build ยังไม่ deploy จริง ให้เปลี่ยนเป็น:

- ถ้า flag ไม่มี → treat ว่า enabled  
- หรือ bypass flag check ทั้งหมดใน dev environment

**(C) ลบ migration เก่า (0008, 0009)**  
เพราะตอนนี้ยังไม่ต้องการ schema feature_flag และ repair_log บน production  
จะให้ Agent:**ลบไฟล์เหล่านี้ออกทันทีใน task22.3**

**(D) ปรับ TokenEventService mapping ถ้า Reconstruction ใช้ canonical เพิ่ม**  
เช่นต้องเพิ่ม mapping สำหรับ OVERRIDE_TIME_FIX

---

# 5. Reconstruction Algorithm (Design v1)

### Step 1 – Load Raw Canonical Events
ใช้ TokenEventService → SELECT events  
ใช้ canonical_type (‘NODE_*’ เท่านั้น)

### Step 2 – Normalize
จัดกลุ่ม events ตาม node (หรือ token-level)  
สort by time  
กรอง repair events (payload.repair) ออกถ้าต้องการ baseline

### Step 3 – Determine Ideal Timeline
สร้าง timeline ใหม่ตาม rule:

- มีได้หลาย session แต่ต้องไม่ทับกัน  
- START ต้องมาก่อน RESUME/PAUSE/COMPLETE  
- COMPLETE ต้องปิด session สุดท้าย  
- ห้าม negative-duration  
- ห้าม zero-duration (ถ้ามี → push COMPLETE +1s)

### Step 4 – Diff Timeline vs Canonical Events
เปรียบเทียบ “ideal timeline” กับ events ที่มีจริง  
หา missing START / missing PAUSE / missing RESUME / missing COMPLETE / zero-duration fix

### Step 5 – Generate Reconstruction Event Plan
สร้าง list ของ canonical events ที่ต้องเพิ่ม:

- canonical_type  
- event_time  
- node_id  
- payload = repair metadata (type = TIMELINE_RECONSTRUCT)

### Step 6 – Apply (ผ่าน LocalRepairEngine)
LocalRepairEngine จะ persistEvents() + addRepairLog() + snapshot ให้ครบ

---

# 6. Deliverables

1. Engine ใหม่:  
   - `TimelineReconstructionEngine.php` (~400–700 lines)

2. Patch LocalRepairEngine:  
   - ติด metadata ให้ MISSING_START  
   - bypass flag (หรือ fallback default = enabled)  
   - integration เรียก reconstruct ถ้า validator ยังเจอ L2/L3 problems

3. Patch TokenEventService (optional)  
   - เพิ่ม mapping สำหรับ canonical ใหม่ (OVERRIDE_TIME_FIX)

4. ลบ migration:  
   - `0008_canonical_self_healing_local_flag.php`  
   - `0009_token_repair_log.php`

5. เอกสาร:  
   - `task22_3_results.md`

---

# 7. Acceptance Criteria

1. สามารถ reconstruct timeline ที่:
   - sequence ผิด  
   - session overlap  
   - zero-duration  
   - missing resume/close session  
   ได้สำเร็จแบบ deterministic

2. LocalRepairEngine เรียก reconstruction ต่อจาก L1 repairs อัตโนมัติ

3. canonical events หลังซ่อม → TimeEventReader ให้ผลลัพธ์:
   - มี start_time  
   - มี complete_time  
   - duration_ms > 0  
   - ไม่มี session overlap  
   - order ถูกต้อง

4. validator(valid_after_reconstruct) = **valid**

5. repair log ถูกบันทึกด้วย metadata:
   - type = TIMELINE_RECONSTRUCT  
   - version = v1  
   - engine = TimelineReconstructionEngine  
   - original_problems = ["INVALID_SEQUENCE_SIMPLE", ...]

6. ไม่กระทบ behavior engine เดิม และยังเป็น append-only ทั้งหมด

---

# 8. Notes

- Timeline Reconstruction v1 = focus node-level / token-level basic correction  
- version v2/v3 อาจซ่อม multi-node transitions / duration smoothing  
- ระบุชัดว่า 22.3 ไม่แตะ event เก่า → เพียงเติม event ใหม่ที่จำเป็นเท่านั้น  
- รองรับรวม patch ที่ตรวจเจอในไฟล์ก่อนหน้าเพื่อความเรียบร้อยและลดงานซ้ำในอนาคต
