

# Task 22.2 – Repair Event Model & Audit Trail (Phase 22)

**Status:** SPEC  
**Date:** 2025-XX-XX  
**Owner:** Bellavier ERP Core / SuperDAG Team  
**Depends on:**  
- Phase 22 Blueprint  
- Task 22.1 (Local Repair Engine v1)  
- Task 21.8 (Integrity Validator / Bulk Tools)  

---

# 1. Objective

สร้างระบบ **Repair Event Model + Audit Trail** ให้ Local Repair Engine สามารถ:

- บันทึกทุกการซ่อม (repair action) ได้แบบ append-only  
- แยกความจริงว่า event ไหน “เกิดจากการทำงานจริงของคน/behavior engine”  
- event ไหน “เกิดจาก Local Repair Engine แก้ไขปัญหา”  
- ทำให้ทุกการซ่อมมีหลักฐานย้อนตรวจสอบได้  
- ทำให้ระบบสามารถ reconstruct full history → ไม่เกิด “กล่องดำ”  

> ถ้า Phase 21 = ตา (เห็นทุกอย่าง), Phase 22.1 = มือแพทย์,  
> Task 22.2 = สมุดบันทึกการผ่าตัด + X-Ray + รายงานแพทย์  
> คือจุดที่ Self-Healing เริ่มมี accountability ที่สมบูรณ์

---

# 2. Problems to Solve

หลัง Task 22.1, Engine ซ่อมได้แล้ว แต่ยังมีปัญหา:

1. **ไม่มี Repair Log / Audit Trail**  
   → ไม่รู้ว่า event ไหนถูกสร้างเพราะอะไร / โดยใคร / เมื่อไร

2. **Repair Event ยังไม่มี Metadata**  
   → canonical event ใหม่ไม่มี tag ระบุว่า “นี่คือ repair event”

3. **TokenEventService ยังไม่รองรับ repair context**  
   → ตอน persist ยังไม่มี field สำหรับ repair_type, repair_batch_id ฯลฯ

4. **LocalRepairEngine ยังไม่ได้ส่งครบ context**  
   - ไม่ส่ง `token_id`  
   - ไม่ส่ง `node_id`  
   - ไม่มี repair metadata  
   - ไม่มี repair event grouping  
   (ต้อง patch ใน 22.2 รวมชุดเดียวกัน)

> Task 22.2 จะเป็นการ “ปิดช่องว่างทั้งหมด” ระหว่าง Self-Healing และ Canonical Pipeline

---

# 3. Scope (High-Level)

Task 22.2 ประกอบด้วย 4 ส่วน:

### 3.1 สร้างตารางใหม่: `flow_token_repair_log`
เพื่อเก็บข้อมูลการซ่อม:

- repair_id (PK)  
- token_id  
- node_id  
- repair_type (enum)  
- canonical_event_ids (json list)  
- before_snapshot (json)  
- after_snapshot (json)  
- created_at  
- created_by (system/user)  
- batch_id (nullable)  
- notes

### 3.2 สร้าง RepairEventModel
เป็น class สำหรับสร้าง metadata ตัว repair:

- repair_type  
- repair_payload  
- timestamp  
- actor (“LocalRepairEngine”)  
- version (“v1”)  
- original_problems  
- derived_events  

### 3.3 Patch LocalRepairEngine (สำคัญ)
- ส่ง `token_id` และ `node_id` เข้า persistEvents  
- เติม metadata ลง payload:
  - `repair_type`
  - `repair_version`
  - `repair_by`
  - `repair_batch_id` (ถ้ามี)
- ตัด code ที่ยังไม่มี handler จริงออกจาก repairable list (INVALID_SEQUENCE_SIMPLE / SESSION_OVERLAP_SIMPLE / ZERO_DURATION)  
  หรือ mark เป็น `not_supported` แบบ explicit

### 3.4 Patch TokenEventService ให้รองรับ repair context
- เมื่อ persist events มี key: `repair_context`  
  → บันทึกลง canonical event  
  → บันทึกลง repair_log  
  → return canonical_event_ids ให้ LocalRepairEngine

---

# 4. Repair Log Schema (สำคัญที่สุด)

ไฟล์ migration:  
`database/migrations/0009_token_repair_log.php`

ตาราง:

```
flow_token_repair_log
---------------------------------------------
id_repair_log          BIGINT PK
token_id               BIGINT (indexed)
node_id                BIGINT (nullable)
repair_type            VARCHAR(64)
canonical_event_ids    JSON
before_snapshot        JSON
after_snapshot         JSON
batch_id               VARCHAR(64) NULL
notes                  TEXT NULL
created_at             DATETIME
created_by             VARCHAR(64) DEFAULT 'system'
```

### 4.1 canonical_event_ids  
ลิสต์ event_id ที่ถูกสร้างจาก repair เช่น:

```
[1234, 1235]
```

### 4.2 before_snapshot / after_snapshot  
ใช้ `TimeEventReader` + `fetchCanonicalEvents` เพื่อ snapshot timeline ก่อน-หลัง repair

---

# 5. LocalRepairEngine Patches (จุดที่ต้องแก้จาก 22.1)

### 5.1 persistEvents ต้องปรับให้ “ครบ context”

ตอนนี้ LocalRepairEngine ส่ง event แบบนี้:

```
[
  'canonical_type' => ...,
  'event_time'     => ...,
  'payload'        => ...
]
```

ต้องเปลี่ยนเป็น:

```
[
  'token_id'       => $tokenId,
  'node_id'        => $nodeId,
  'canonical_type' => ...,
  'event_type'     => 'repair',
  'event_time'     => ...,
  'payload'        => [
      ...payload...
      'repair' => [
           'type'       => REPAIR_TYPE,
           'version'    => 'v1',
           'by'         => 'LocalRepairEngine',
           'batch_id'   => $batchId,
      ]
  ]
]
```

### 5.2 REPAIRABLE_PROBLEMS ต้อง align กับ handler จริง

เอาออก 3 code เหล่านี้ (หรือ mark ว่า not_supported):

- INVALID_SEQUENCE_SIMPLE  
- SESSION_OVERLAP_SIMPLE  
- ZERO_DURATION  

เหตุผล:
- ไม่มี handler ใน 22.1  
- จะไปทำใน 22.3 (timeline reconstruction)

### 5.3 addRepairLog()
สร้างเมธอด:

```
private function addRepairLog($tokenId, $nodeId, $repairType, $canonicalEventIds, $before, $after, $notes)
{
    INSERT INTO flow_token_repair_log ...
}
```

### 5.4 applyRepairPlan() ต้องบันทึก log ก่อน–หลัง
Flow ใหม่:

1. snapshot ก่อน repair  
2. persistEvents  
3. snapshot หลัง repair  
4. addRepairLog()  
5. re-validate  
6. return result

---

# 6. TokenEventService Patch (รองรับ repair event)

ไฟล์: `source/BGERP/Dag/TokenEventService.php`

### เพิ่มความสามารถ:

1. ถ้า event payload มี key `repair` → treat event as repair-event  
2. คืน canonical_event_id ให้ LocalRepairEngine  
3. บันทึก metadata ลง `event_data` json  
4. ไม่ต้องทำ mapping legacy → การซ่อมไม่ควรมีผลลึกถึง legacy layer (ตาม blueprint)

---

# 7. Test Cases

### 7.1 Missing Start Repair
- canonical event ก่อน repair = ไม่มี START  
- หลัง apply:
  - มี repair START  
  - มี repair log  
  - canonical_event_ids มี id ใหม่  
  - validator(valid_after) = true

### 7.2 Minimal Timeline Repair (NO_CANONICAL_EVENTS)
- ก่อน repair: ไม่มี canonical events  
- หลัง repair:
  - มี START + COMPLETE  
  - repair log มี 2 event  
  - timeline ถูกต้อง

### 7.3 UNPAIRED_PAUSE
- ก่อน repair: PAUSE ไม่มี RESUME  
- หลัง repair: มี RESUME ใหม่  
- repair log มี 1 event  
- validator ok

### 7.4 Safety
- token active → isTokenEligible = false  
- simulateRepair → ok  
- applyRepairPlan → blocked (flag required)

---

# 8. Deliverables

- ไฟล์ migration `0009_token_repair_log.php`
- Patch TokenEventService  
- Patch LocalRepairEngine  
- สร้าง `RepairEventModel.php`  
- Documentation:  
  - `task22_2_results.md`

---

# 9. Acceptance Criteria

- Repair events ถูกบันทึกเป็น canonical events พร้อม metadata  
- มีบันทึก repair log ใน `flow_token_repair_log`  
- LocalRepairEngine ส่ง event context ครบ (token_id/node_id/repair_meta)  
- Validator หลังซ่อม = valid หรือ warning เท่านั้น  
- Feature flag ยังควบคุมได้  
- ไม่มี destructive mutation (append-only)