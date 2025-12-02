# Task 22.3.1 – Timeline Reconstruction Hardening

**Status:** SPEC  
**Date:** 2025-XX-XX  
**Owner:** Bellavier ERP Core / SuperDAG Team  
**Depends on:**  
- Task 22.3 – Timeline Reconstruction v1  
- Task 22.2 – Repair Event Model & Log  
- Task 22.1 – Local Repair Engine v1  

---

## 1. Objective

เสริมความแข็งแรง (hardening) ให้ `TimelineReconstructionEngine` และส่วนที่เกี่ยวข้อง โดยแก้ปัญหาที่ตรวจพบจาก code review:

1. ให้การแก้ `ZERO_DURATION` ทำงานได้จริง (ตอนนี้ logic ชนกันเองจนไม่เกิด repair event)
2. ให้การแก้ `SESSION_OVERLAP_SIMPLE` ใช้ canonical event ที่สอดคล้องกับ semantics ของระบบ (ตอนนี้ใช้ `NODE_RESUME` ซึ่งไม่เหมาะ)
3. ให้ `RECONSTRUCTABLE_PROBLEMS` สอดคล้องกับ implementation จริง (ไม่ claim เกินกว่าที่ซ่อมได้)
4. ลด path ที่เป็น dead code / logic ซ้อนทับที่ไม่ถูกใช้

เป้าหมายคือให้ Timeline Reconstruction v1:

- แก้ L2/L3 problems ที่รองรับอยู่จริง  
- ทำงานแบบ deterministic, append-only  
- มี semantics ตรงกับพฤติกรรมจริงของระบบและช่าง  
- ไม่สร้าง “ภาพลวงตา” ว่าซ่อมได้แต่จริง ๆ ไม่ได้ซ่อม

---

## 2. Problems จากการตรวจ TimelineReconstructionEngine ปัจจุบัน

### 2.1 ZERO_DURATION ไม่ได้ถูกซ่อมจริง

อาการ:

- ใน `reconstructNodeTimeline()` มี logic:

  ```php
  // Handle zero duration: if start == complete, push complete +1s
  if ($startTime && $completeTime && $startTime === $completeTime) {
      $completeTime = TimeHelper::parse($completeTime)->modify('+1 second')->toMysql();
  }
  ```

  → ทำให้ `start_time !== complete_time` ใน timeline ที่ return ออกมา

- ใน `diffTimeline()` มี branch:

  ```php
  if (in_array('ZERO_DURATION', $problemCodes, true)) {
      if ($nodeTimeline['start_time'] && $nodeTimeline['complete_time'] &&
          $nodeTimeline['start_time'] === $nodeTimeline['complete_time']) {
          // generate NODE_COMPLETE +1s
      }
  }
  ```

  → แต่เงื่อนไข `start_time === complete_time` จะ **ไม่เกิดอีกแล้ว** เพราะถูกเปลี่ยนไปแล้วใน reconstructNodeTimeline

ผลลัพธ์:

- ไม่เกิด reconstruction event สำหรับ ZERO_DURATION  
- canonical events ใน DB ยังเป็น zero-duration เหมือนเดิม  
- validator รอบถัดไปมีโอกาสฟ้อง ZERO_DURATION ซ้ำ

---

### 2.2 SESSION_OVERLAP_SIMPLE ใช้ NODE_RESUME ซึ่ง semantics ไม่เหมาะ

ใน `diffTimeline()`:

```php
if (in_array('SESSION_OVERLAP_SIMPLE', $problemCodes, true)) {
    // ...
    if ($endA && $startB < $endA) {
        $resumeTime = TimeHelper::parse($sessionB['from'])->modify('-1 second')->toMysql();
        $reconstructionEvents[] = [
            'canonical_type' => 'NODE_RESUME',
            'event_time' => $resumeTime,
            'node_id' => $nodeId,
            'payload' => [
                'repair_reason' => 'SESSION_OVERLAP_FIX',
                'overlapping_sessions' => [$i, $i + 1],
                ...
            ],
        ];
    }
}
```

ปัญหา:

- Overlap จริง ๆ คือ session A ยังไม่ปิด แต่ session B เริ่มแล้ว  
- สิ่งที่ควรทำเชิง semantics คือ “ปิด session A ให้จบก่อน” (มักจะคิดถึง `NODE_PAUSE` หรือปรับเวลา COMPLETE ของ A)  
- การใส่ `NODE_RESUME` ก่อน B.start ดูไม่สอดคล้องกับพฤติกรรมจริง (RESUME หมายถึงกลับมาทำต่อหลัง pause ไม่ได้ปิด session)

---

### 2.3 RECONSTRUCTABLE_PROBLEMS claim เยอะกว่า implementation จริง

ปัจจุบัน:

```php
private const RECONSTRUCTABLE_PROBLEMS = [
    'INVALID_SEQUENCE_SIMPLE',
    'SESSION_OVERLAP_SIMPLE',
    'ZERO_DURATION',
    'EVENT_TIME_DISORDER',
    'NEGATIVE_DURATION',
];
```

แต่ใน `diffTimeline()`:

- มี logic สำหรับ:
  - missing START  
  - missing COMPLETE  
  - ZERO_DURATION (แต่ชนกับข้อ 2.1)  
  - SESSION_OVERLAP_SIMPLE  
- ยังไม่มี logicเฉพาะสำหรับ:
  - EVENT_TIME_DISORDER  
  - NEGATIVE_DURATION  

จึงเกิด gap ระหว่าง:

- สิ่งที่ class บอกว่าซ่อมได้ (ผ่าน constant)  
- สิ่งที่จริง ๆ แล้วมี implementation อยู่

---

### 2.4 idealTimeline['sessions'] ถูกสร้างแต่ยังไม่ถูกใช้จริง

ใน `determineIdealTimeline()`:

- มีการรวม `nodeTimeline['sessions']` ของทุก node เข้า `idealTimeline['sessions']`  
- มีการเรียก `removeSessionOverlaps()` บน ideal sessions  

แต่ใน `diffTimeline()`:

- ใช้ `nodeTimeline['sessions']` ของแต่ละ node ในการตรวจ overlap  
- ไม่เคยใช้ `idealTimeline['sessions']` ที่ประมวลผลแล้ว

ผล: path นี้กลายเป็น semi-dead code ในเวอร์ชันปัจจุบัน

---

## 3. Scope ของ Task 22.3.1

### 3.1 Hardening ZERO_DURATION

เป้าหมาย:

- ทำให้ ZERO_DURATION ถูกซ่อมจริงด้วย canonical events ใหม่  
- หลีกเลี่ยงการ “แค่แก้ค่าในตัวแปร timeline” แต่ไม่สร้าง event

แนวทาง:

1. **ย้าย handling ZERO_DURATION ไปอยู่ใน diffTimeline อย่างเดียว**

   - ลบ/คอมเมนต์ logic ใน `reconstructNodeTimeline()` ที่เปลี่ยน `$completeTime` +1s  
   - ปล่อยให้ timeline ที่ได้จาก `reconstructNodeTimeline()`สะท้อนปัญหา zero-duration ตามจริง

2. **ใน `diffTimeline()`**:

   - ตรวจเคส: `ZERO_DURATION` + `start_time === complete_time`  
   - สร้าง canonical event ใหม่:

     ```php
     [
        'canonical_type' => 'NODE_COMPLETE',
        'event_time'     => complete_time + 1 second,
        'node_id'        => $nodeId,
        'payload'        => [
            'repair_reason' => 'ZERO_DURATION_FIX',
            ...RepairEventModel::buildRepairMetadata(TYPE_TIMELINE_RECONSTRUCT, ...),
        ],
     ]
     ```

   - แนวคิด: COMPLETE ใหม่ที่เวลา +1s กลายเป็น “จุดจบจริง” ของงาน, COMPLETE เดิมถือว่าเป็น data point glitch ที่ไม่ใช้คำนวณ duration

3. หลัง repair → validator + TimeEventReader ควรเห็น duration > 0 ms

---

### 3.2 Hardening SESSION_OVERLAP_SIMPLE

เป้าหมาย:

- ปิดช่อง overlap ระหว่าง sessions โดยใช้อีเวนต์ที่สมเหตุสมผล  
- รักษา semantics: “Session A ต้องจบก่อน B จะเริ่ม”

แนวทาง:

1. ใช้ `NODE_PAUSE` แทน `NODE_RESUME` สำหรับ SESSION_OVERLAP_FIX:

   - เมื่อพบ session A (fromA–toA) กับ B (fromB–toB) แล้ว `fromB < toA`:
     - สร้าง `NODE_PAUSE` ที่เวลา = `fromB - 1 second` สำหรับ session A
   - ผลเชิงความหมาย:  
     - A ถูก pause ก่อนเริ่ม B → ไม่มีช่วงเวลาที่สองงาน “active” พร้อมกันใน timeline

2. แก้ branch SESSION_OVERLAP_SIMPLE ใน `diffTimeline()`:

   - เปลี่ยน canonical_type จาก `NODE_RESUME` → `NODE_PAUSE`
   - ปรับชื่อ `repair_reason` เป็น `SESSION_OVERLAP_FIX` (ใช้ต่อได้)  
   - ตรวจ guard พิเศษ:
     - ไม่สร้าง PAUSE ซ้อนบนจุดที่มี PAUSE จริงอยู่แล้ว (optional)

3. หลัง repair:

   - TimeEventReader ไม่ควรเห็น session overlaps อีกสำหรับ node นั้น  
   - Validator rule SESSION_OVERLAP_SIMPLE ควรหายไปจาก problems หลัง reconstruction

---

### 3.3 Align RECONSTRUCTABLE_PROBLEMS กับ Implementation

เป้าหมาย:

- ลดความสับสน: “engine นี้ซ่อมอะไรได้จริงบ้าง”

แนวทาง:

1. **ระยะสั้น (ใน Task นี้)**:

   - ปรับ `RECONSTRUCTABLE_PROBLEMS` ให้เหลือเฉพาะ codes ที่มี logic จริงใน `diffTimeline()` หลัง patch:

     ```php
     private const RECONSTRUCTABLE_PROBLEMS = [
         'INVALID_SEQUENCE_SIMPLE',   // ถ้ามี logic แล้ว
         'SESSION_OVERLAP_SIMPLE',
         'ZERO_DURATION',
     ];
     ```

   - ถ้า `INVALID_SEQUENCE_SIMPLE` ยังไม่มี logic เฉพาะ → ตัดออกชั่วคราว หรือเพิ่ม logic ง่าย ๆ เช่น reorder ตามเวลาคงที่

2. **ระยะกลาง (ภายหลัง)**:

   - ถ้าในอนาคตมี implementation สำหรับ:
     - EVENT_TIME_DISORDER  
     - NEGATIVE_DURATION  
   - ค่อยเพิ่มกลับเข้ามาใน constant นี้พร้อม test + docs

---

### 3.4 (Optional) Clean Up IdealTimeline Sessions

Scope optional (เฉพาะถ้าไม่ใช้จริงใน 22.x):

- ถ้าปัจจุบัน `idealTimeline['sessions']` ยังไม่ถูกใช้ใน logic อื่น:
  - คอมเมนต์/ลบการรวม sessions เข้าสู่ idealTimeline  
  - หรืออย่างน้อยระบุ comment ไว้ชัดเจน:

    > “Reserved for future multi-node timeline analysis; not used by Reconstruction v1”

เพื่อให้ dev อื่นไม่สับสนว่าทำไมสร้าง idealTimeline แต่ไม่ได้เอาไปใช้

---

## 4. Integration กับ LocalRepairEngine / RepairEventModel

### 4.1 METADATA สำหรับ ZERO_DURATION & SESSION_OVERLAP_FIX

- ทุก event ที่สร้างจาก TimelineReconstructionEngine ต้องใช้:

  ```php
  RepairEventModel::buildRepairMetadata(
      RepairEventModel::TYPE_TIMELINE_RECONSTRUCT,
      $batchId,
      $problemCodes
  )
  ```

- ให้รวม `repair_reason` ระดับ field แยก (เช่น `'ZERO_DURATION_FIX'`, `'SESSION_OVERLAP_FIX'`) ไว้ใน payload ด้วย  
  เพื่อให้ debug ง่าย

### 4.2 LocalRepairEngine Flow

- การเรียก reconstruction:
  - ยังทำเหมือนเดิม: หลัง L1 repairs → ถ้าพบ L2/L3 problems → เรียก TimelineReconstructionEngine  
- หลัง patch → L2/L3 problems ที่รองรับจะถูกลด/หายไป  
- นอกเหนือจากนั้นไม่ต้องแก้ flow ของ LocalRepairEngine

---

## 5. Deliverables

1. Patch `TimelineReconstructionEngine.php`:
   - ZERO_DURATION logic ย้ายไป diffTimeline และสร้าง COMPLETE ใหม่ + metadata
   - SESSION_OVERLAP_SIMPLE logic เปลี่ยนไปใช้ NODE_PAUSE + semantics ที่เหมาะสม
   - ปรับ `RECONSTRUCTABLE_PROBLEMS` ให้ตรงกับ logic

2. (Optional) Clean-up idealTimeline sessions:
   - Comment / adjust code ให้ชัดเจนว่าไม่ใช้ใน v1

3. Docs:
   - สร้าง `task22_3_1_results.md`  
   - อธิบาย behavior ก่อน/หลัง patch พร้อมตัวอย่าง timeline

---

## 6. Acceptance Criteria

1. ZERO_DURATION:
   - ก่อน patch: ZERO_DURATION problems ไม่หายแม้ reconstruction ทำงาน  
   - หลัง patch: มี repair event เพิ่ม → TimeEventReader ให้ duration > 0 → validator ไม่ฟ้อง ZERO_DURATION สำหรับ token ที่ซ่อมแล้ว

2. SESSION_OVERLAP_SIMPLE:
   - ก่อน patch: ใช้ NODE_RESUME และ semantics ไม่ชัด  
   - หลัง patch: ใช้ NODE_PAUSE ก่อน B.start → ไม่มี session overlap ตาม TimeEventReader → validator ผ่าน rule นี้

3. RECONSTRUCTABLE_PROBLEMS:
   - ไม่มี code ใดอยู่ใน constant โดยไม่มี implementation จริง  
   - Dev อ่านแล้วเข้าใจได้ทันทีว่า engine นี้รองรับ problems ชุดใด

4. Backward Compatibility:
   - ไม่เปลี่ยน behavior engine เดิม  
   - ไม่แก้ canonical event เดิม (ยัง append-only)  
   - dev tools (dev_token_timeline, dev_timeline_report) ยังใช้ได้ปกติ
