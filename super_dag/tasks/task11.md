

# Task 11 — Enhanced Session Management (Phase 3)

## Objective
ยกระดับระบบ Session Lifecycle ให้สอดคล้องกับ DAG Execution และ Behavior Execution 100% โดยเฉพาะในงาน STITCH ที่เป็นงานหัตถศิลป์แบบใบต่อใบ เพื่อให้โปรแกรมเก็บเวลาทำงานจริงได้อย่างแม่นยำ และป้องกัน session ค้าง/ซ้อน/ข้ามวัน

Task นี้เป็น Non-breaking change:  
- ห้ามแก้ schema database  
- ห้ามเปลี่ยน response structure เดิม (เพิ่ม field optional ได้)  
- ห้ามแตะ Component Binding  
- ห้ามแตะ DAG Designer  

---

## Scope

### 1) STITCH — Force Session Lifecycle Consistency
ก่อนทำ `stitch_complete`:
- ต้องตรวจว่ามี active session ของ token+worker
- ถ้ามี → ปิด session ให้เรียบร้อยด้วย Time Engine
- ถ้าไม่มี → error: `BEHAVIOR_NO_ACTIVE_SESSION_FOR_COMPLETE`

หลังปิด session:
- ดึง session summary
- แนบใน response ใน key: `session_summary` (optional)

### 2) Session Summary Structure
Response ของ stitch_complete ต้องเพิ่ม field:

```
"session_summary": {
  "total_work_seconds": 0,
  "total_pause_seconds": 0,
  "started_at": "",
  "ended_at": ""
}
```

ถ้าไม่มี session → ไม่ต้องใส่ field นี้

### 3) DagExecutionService Integration
ก่อน `moveToNextNode()`:
- ตรวจอีกครั้งว่า session ยัง active อยู่หรือไม่
- ถ้า active → ห้าม move token  
  error: `DAG_409_SESSION_STILL_ACTIVE`

### 4) Conflict Handling Rules
- Worker A มี session แต่ Worker B มากด start/resume → block
- Session ค้างข้ามวัน (stale) → ไม่ auto-close ใน Task11 แต่ mark TODO และ return warning flag ถ้าพบ duration เกิน X ชั่วโมง

### 5) Logging
- ทุก behavior action ต้องเขียนลง `dag_behavior_log`
- ปิด session ต้องเขียนลง session log (ตารางที่มีอยู่แล้ว)

---

## Required File Changes

### 1. BehaviorExecutionService.php
- เพิ่ม logic ปิด sessionใน STITCH complete
- เพิ่ม error ใหม่
- เพิ่ม session_summary ใน response

### 2. TokenWorkSessionService (DAG Wrapper)
- เพิ่ม method helper สำหรับดึง session summary
- เพิ่ม check session stale (TODO)

### 3. DagExecutionService.php
- เพิ่ม guard ก่อน moveToNextNode()

### 4. dag_behavior_exec.php
- ส่ง session_summary ออกไปใน JSON ถ้ามีข้อมูล

### 5. task11_results.md
- สร้างเพื่อลงผลลัพธ์หลังการ implement

### 6. task_index.md
- mark Task 11 เป็น COMPLETED หลังทำเสร็จ

---

## Deliverables สำหรับ AI Agent
ให้ AI Agent ทำสิ่งต่อไปนี้:

1. แก้ BehaviorExecutionService:
   - Implement session close ใน stitch_complete
   - เพิ่ม error: `BEHAVIOR_NO_ACTIVE_SESSION_FOR_COMPLETE`
   - แทรก session_summary ใน response

2. แก้ TokenWorkSessionService (DAG wrapper):
   - เพิ่ม method: `getSessionSummary($sessionId)`
   - เพิ่ม method: `isSessionStale($session)` (ยังไม่ใช้ แต่เตรียมไว้)

3. อัปเดต DagExecutionService:
   - เพิ่ม guard: ถ้า session ยัง active → error `DAG_409_SESSION_STILL_ACTIVE`

4. อัปเดต dag_behavior_exec.php:
   - ส่ง session_summary ออกใน response

5. ตรวจ PHP syntax
6. สร้าง task11_results.md
7. อัปเดต task_index.md

---

## Definition of Done
- STITCH complete ต้องปิด session ทุกครั้ง
- Routing หลัง STITCH complete must NOT happen หาก session ยังไม่ปิด
- session_summary ปรากฏใน response แบบ optional
- ไม่มี breaking changes
- ไม่มี schema change
- Task 11 ถูก mark COMPLETE
