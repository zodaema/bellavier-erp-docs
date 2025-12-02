# Task 13 – Supervisor Override & Session Recovery UI (STITCH v1)

**Status:** PLANNING  
**Depends on:**  
- super_dag Task 7 – Time Engine Integration  
- super_dag Task 10 – Behavior-level Validation  
- super_dag Task 11 – Session Lifecycle Enforcement  
- super_dag Task 12 – Advanced Session & Time Safeguards  

---

## 1. Objective

ให้หัวหน้าช่าง / Supervisor สามารถ:

1. เห็นว่าแต่ละช่างมี **active / stale / ค้างคา** session อะไรบ้าง (เฉพาะ STITCH ก่อน)
2. ปิด / เคลียร์ / แก้ไขสถานะ session ที่ค้างผิดปกติได้อย่างปลอดภัย  
3. ทำทุกอย่างผ่าน UI โดยไม่ต้องเข้า database โดยตรง
4. ทุก action ถูก log (who/when/what/why) เพื่อใช้เป็น audit trail

**แกนคิด:**  
ระบบจะช่วยกัน “unblock” งานที่ค้าง แต่ไม่บังคับคนจนแก้ปัญหาเฉพาะหน้าไม่ได้

---

## 2. Scope

### In Scope (สำหรับ Task 13)

1. **Supervisor UI (Read-only + Action)**
   - Supervisor dashboard (แบบ lightweight) สำหรับ:
     - ดู active sessions ราย worker
     - ดู stale sessions (> threshold)
     - Filter ตาม worker / work center / status (active / paused / stale candidate)

2. **Supervisor Actions (STITCH only, Phase 1)**
   - Action บน session ระดับ token:
     - **Force Close Session** (เช่น ช่างลืมปิด / ค้างข้ามวัน)
     - **Mark As Reviewed** (กรณี stale แต่ไม่ต้องปิด)
   - กำหนดให้ทุก action ต้องกรอก **reason / note** สั้น ๆ

3. **API Layer**
   - สร้าง API ใหม่ (หรือต่อขยาย endpoint ที่มีอยู่) สำหรับ:
     - list sessions (filterable)
     - perform override actions (force close / mark reviewed)

4. **Audit & Logging**
   - ทุก action ของ supervisor ต้องถูก log:
     - supervisor_id
     - worker_id
     - token_id
     - session_id
     - action (`force_close`, `mark_reviewed`)
     - reason
     - created_at

5. **Permissions**
   - จำกัดสิทธิ์เฉพาะ:
     - Platform admin  
     - หรือ role ระดับ “Supervisor” ที่คุณ define ไว้ในระบบ permission เดิม
   - คนที่เป็นช่างปกติ **ห้าม** เข้าหน้านี้

---

## 3. Out of Scope (ยังไม่ทำใน Task 13)

- ไม่ยุ่งกับ **Component binding**  
- ไม่ยุ่งกับ **QC behaviors**  
- ไม่เปลี่ยน **Time Engine core logic** (เฟสนี้ใช้แต่ `TokenWorkSessionService` ที่มีอยู่)  
- ไม่เปลี่ยน **DAG routing** (ไม่ auto-route จากหน้าหัวหน้า)  
- ไม่ทำ **multi-behavior override** (CUT / EDGE / QC ไว้ task ถัดไป)  
- ไม่เพิ่ม error code ใหม่ใน Behavior layer (ใช้ของเดิมจาก Task 10–12)

---

## 4. Design Overview

### 4.1 UI Concept

**หน้าใหม่ (แนะนำ):**  
`page/dag_supervisor_sessions.php` (หรือชื่อใกล้เคียง) — สำหรับหัวหน้า

ฟีเจอร์หน้า:

- DataTable / Grid:
  - `worker_name`
  - `token_id`
  - `work_center_name`
  - `behavior_code` (ตอนนี้เน้น `STITCH`)
  - `status` (active / paused / stale flag)
  - `started_at`, `resumed_at`, `elapsed_estimate`
- Filter:
  - worker
  - behavior
  - status
- Action buttons ต่อแถว:
  - “Force Close”
  - “Mark Reviewed”

**จากหน้า Work Queue / Job Ticket (Optional, ถ้าทำไหว):**
- Link “ดู session ของช่างนี้” → เปิด popup / new tab ไปหน้า supervisor sessions พร้อม filter ไปที่ worker นั้น

---

### 4.2 API Endpoints (เสนอรูปแบบ)

ให้ทำในโฟลเดอร์ `source/` โดยยึด pattern tenant API เดิม:

1. `source/dag_supervisor_sessions.php`

   **Actions:**

   - `action=list`
     - Input: filter (worker_id?, behavior_code?, status?, paging)
     - Output (JSON):
       ```json
       {
         "ok": true,
         "data": {
           "recordsTotal": ...,
           "recordsFiltered": ...,
           "data": [
             {
               "session_id": 123,
               "token_id": 456,
               "worker_id": 789,
               "worker_name": "...",
               "work_center_id": 10,
               "work_center_name": "...",
               "behavior_code": "STITCH",
               "status": "active",
               "started_at": "...",
               "resumed_at": "...",
               "elapsed_seconds_estimate": 1234,
               "is_stale": false
             }
           ]
         }
       }
       ```

   - `action=force_close`
     - Input:
       - `session_id`
       - `reason` (string, required, min length > 3)
     - Behavior:
       - ใช้ `TokenWorkSessionService` wrapper ที่มีเพื่อปิด session
       - Log ลง audit table
     - Output:
       ```json
       {
         "ok": true,
         "session_id": 123,
         "effect": "session_closed",
         "summary": { ... } // optional
       }
       ```

   - `action=mark_reviewed`
     - Input:
       - `session_id`
       - `reason` (optional, แต่ถ้ามีจะ log)
     - Behavior:
       - ไม่เปลี่ยนสถานะ session
       - แค่ log ว่าหัวหน้า review แล้ว
     - Output:
       ```json
       {
         "ok": true,
         "session_id": 123,
         "effect": "marked_reviewed"
       }
       ```

> ใช้ `TenantApiBootstrap` + `TenantApiOutput` ตามมาตรฐาน bootstrap ใหม่  
> ตรวจสอบ permission ผ่าน `PermissionHelper` (role: supervisor / admin)

---

### 4.3 Database & Logging

#### 4.3.1 ใช้ตารางที่มีอยู่แล้ว

- `token_work_session` — สำหรับข้อมูล session จริง
- `dag_behavior_log` — ใช้ log เพิ่ม action override (ไม่ต้องสร้างตารางใหม่)

#### 4.3.2 Logging Pattern เสนอ

เมื่อ:

- `force_close`:
  - Insert log ใน `dag_behavior_log`:
    - `behavior_code`: `"STITCH_SUPERVISOR_OVERRIDE"`
    - `action`: `"force_close"`
    - `actor_role`: `"supervisor"` (อยู่ใน payload JSON)
    - `reason`

- `mark_reviewed`:
  - `behavior_code`: `"STITCH_SUPERVISOR_OVERRIDE"`
  - `action`: `"mark_reviewed"`

> ไม่ต้องเปลี่ยน schema — pack field เพิ่มใน JSON payload เดิม

---

## 5. Files to Touch (Candidate List)

> ให้ AI Agent ตรวจไฟล์จริงก่อนแก้เสมอ และทำ patch แบบ minimal

### New

- `page/dag_supervisor_sessions.php`
- `views/dag_supervisor_sessions.php` (ถ้าใช้ pattern เดิม)
- `assets/javascripts/dag/dag_supervisor_sessions.js`
- `source/dag_supervisor_sessions.php`
- `docs/super_dag/tasks/task13_results.md` (ผลลัพธ์หลังทำเสร็จ)

### Existing (ต้องแก้ด้วยความระวัง)

- `docs/super_dag/task_index.md`
  - เพิ่ม Task 13 ในรายการ และอัปเดตสถานะเป็น COMPLETED หลังทำเสร็จ

- `source/BGERP/Dag/TokenWorkSessionService.php`
  - ถ้าต้องการ helper เพิ่ม เช่น `getSessionsForSupervisorView()` (อ่านอย่างเดียว)
  - **ห้าม** เปลี่ยน behavior ของ `start/pause/resume` ใน Task 13

- `assets/javascripts/pwa_scan/work_queue.js` / `.../job_ticket.js` (Optional)
  - ถ้าอยากเพิ่ม link เปิดหน้า supervisor (แต่ไม่บังคับใน Task 13)

---

## 6. Acceptance Criteria

1. **Supervisor UI**
   - มีหน้า 1 หน้า (หรือ popup) ที่ list sessions ตาม filter
   - สามารถ filter ตาม worker / status ได้จริง (อย่างน้อย 1 filter)

2. **Supervisor Actions**
   - `force_close` ทำให้ session ปิด และเวลาหยุดเดิน
   - `mark_reviewed` ไม่เปลี่ยน status session แต่ log การ review

3. **Permissions**
   - คนที่ไม่ใช่ admin/supervisor เข้า endpoint / หน้า UI นี้แล้วโดนปฏิเสธ (403 / error JSON)

4. **Logging**
   - ทุก action ของ supervisor มี log ใน `dag_behavior_log` พร้อม reason

5. **Safety**
   - ไม่แตะ logic ใน Task 10–12 ที่เกี่ยวกับ STITCH safeguards
   - ไม่เกิด breaking change กับ Time Engine / DAG Engine
   - PHP `php -l` ผ่านทุกไฟล์
   - JS ไม่มี error ใน console

---

## 7. Notes for AI Agent

> สำหรับ AI Agent ที่จะ implement Task 13 — กรุณาปฏิบัติตาม:

1. อ่านไฟล์ต่อไปนี้ก่อนเขียนโค้ด:
   - `docs/super_dag/task_index.md`
   - `docs/super_dag/tasks/task10_results.md`
   - `docs/super_dag/tasks/task11_results.md`
   - `docs/super_dag/tasks/task12_results.md`
   - `source/dag_behavior_exec.php`
   - `source/BGERP/Dag/TokenWorkSessionService.php`
   - `source/BGERP/Dag/BehaviorExecutionService.php`

2. ห้าม:
   - เปลี่ยน signature หรือ behavior ของ method เดิมใน `TokenWorkSessionService` (start/pause/resume)
   - เปลี่ยน error code ที่ Task 10–12 ใช้อยู่
   - เปลี่ยนโครงสร้าง JSON responses ของ `dag_behavior_exec.php`

3. ถ้าต้องเพิ่ม helper ใหม่:
   - ให้ทำในรูปแบบ method ใหม่ที่เป็น read-only / safe
   - ห้ามโยน exception ดิบ ๆ ออกไปถึง endpoint

4. โค้ดทั้งหมดต้อง:
   - ใช้ `TenantApiBootstrap` + `TenantApiOutput` สำหรับ endpoint ใหม่
   - ใช้ pattern logging เดียวกับ `dag_behavior_log` เดิม
   - ผ่าน `php -l` ทุกไฟล์

---

**End of Task 13 Spec**