# Task 24.4 — Job Ticket Lifecycle v2 (Start / Pause / Resume / Complete / Cancel / Restore)

**Objective:**  
ยกระดับระบบ Job Ticket Lifecycle ให้สมบูรณ์แบบและพร้อมใช้งานจริงใน Bellavier Group ERP โดยเชื่อมโยง State Machine → Job Ticket API → UI → Token Engine อย่างราบรื่น, ถูกต้องตามหลักการผลิต, และรองรับ Classic Line เต็มรูปแบบ (ไม่แตะ Hatthasilpa)

---

## 1. Scope

### ✔ สิ่งที่ครอบคลุม
- State Machine: start, pause, resume, complete, cancel, restore  
- Backend API (job_ticket.php): ปรับ logic และเพิ่ม safety rules  
- UI/JS: ปรับปุ่มให้ถูกต้องตาม state  
- TokenLifecycleService: integrate แบบปลอดภัย  
- Audit Log: เขียน log ทุก transition  
- ETA/Health: แจ้ง hooks แบบ non‑blocking

### ❌ สิ่งที่ไม่แตะใน Task 24.4
- ไม่แตะผลิตภัณฑ์ Hatthasilpa  
- ไม่แตะ Node Behavior Engine  
- ไม่แตะ Canonical Events, Repair Engine  
- ไม่แก้ routing, graph designer  
- ไม่แตะ People / Skill System

### 1.3 หมายเหตุเรื่อง PWA (Scan Terminal เท่านั้น)
- PWA ใน Phase นี้ **ไม่ทำหน้าที่เป็น Work Queue**
- PWA ทำหน้าที่เป็น **Scan Terminal ประจำแต่ละ Station** เท่านั้น (สแกน Barcode/QR ของ Job Ticket)
- การเปลี่ยนสถานะ Start/Pause/Resume/Complete ของ Classic Job Ticket มาจาก:
  - ฝั่ง Web Admin (job_ticket.php) หรือ
  - ฝั่ง PWA ที่ยิง API เฉพาะ (เช่น job_ticket_scan_api.php) ตาม state machine นี้
- Task 24.4 โฟกัสที่ **State Machine + job_ticket.php + JS บนหน้า Admin** ก่อน
- การเชื่อม PWA Scan Terminal กับ lifecycle ตาม spec นี้จะทำใน Task ถัดไป (Phase PWA)

---

## 2. New State Machine (Classic Line Only)

```
DRAFT → PLANNED → IN_PROGRESS → PAUSED → IN_PROGRESS → COMPLETED
                                    ↘︎ CANCELLED ↗︎    ↘︎ RESTORED ↗︎
```

### Rules:
- start_allowed เมื่อ `PLANNED → IN_PROGRESS`  
- pause_allowed เมื่อ `IN_PROGRESS → PAUSED`  
- resume_allowed เมื่อ `PAUSED → IN_PROGRESS`  
- complete_allowed เมื่อ `IN_PROGRESS → COMPLETED` (ไม่อนุญาตให้ complete ขณะ PAUSED)  
- cancel_allowed เมื่อ `PLANNED || IN_PROGRESS || PAUSED`  
- restore_allowed เมื่อ `CANCELLED → PAUSED` (กลับมาเฉพาะ paused state)

---

## 3. Backend Changes (job_ticket.php)

### 3.1 Add New Methods
- `transitionStart()`
- `transitionPause()`
- `transitionResume()`
- `transitionComplete()`
- `transitionCancel()`
- `transitionRestore()`

### 3.2 Validation Layer
ตรวจสอบ:
- state ปัจจุบัน  
- graph_mode (ต้องเป็น classic)  
- ไม่มี token dangling  
- ไม่มี task locking (future)

### 3.3 TokenLifecycle Integration
- start → spawn tokens  
- pause → call `pauseTokenGroup()`  
- resume → call `resumeTokenGroup()`  
- complete → call `completeTokenGroup()`  
- cancel → soft‑cancel token group  
- restore → reactivate token group

### 3.4 ETA / Health Hooks
Non‑blocking:
- onStart  
- onPause  
- onResume  
- onComplete  
- onCancel  
- onRestore  

---

## 4. UI/JS Changes

### 4.1 ปุ่มที่ต้องแสดงตาม state
| State         | Buttons |
|---------------|---------|
| DRAFT         | none |
| PLANNED       | Start, Cancel |
| IN_PROGRESS   | Pause, Complete, Cancel |
| PAUSED        | Resume, Cancel |
| CANCELLED     | Restore |
| COMPLETED     | none |

### 4.2 JS updates
ใน `job_ticket.js`:
- เพิ่ม `callStart`, `callPause`, `callResume`, `callComplete`, `callCancel`, `callRestore`
- เพิ่ม guard เพื่อไม่รีเฟรชทั้งหน้า
- ให้ reload offcanvas เฉพาะส่วน

---

## 5. Data Model Rules (No Schema Change)
แม้ไม่เพิ่ม columns ใหม่ แต่ enforce:
- `job_ticket.status` ต้องสะท้อน state machine  
- `job_ticket.progress_pct` = read-only  
- `job_ticket.cancelled_at`, `completed_at` optional  

---

## 6. Logging

### table: `job_ticket_event`
เพิ่ม events:
- TICKET_STARTED  
- TICKET_PAUSED  
- TICKET_RESUMED  
- TICKET_COMPLETED  
- TICKET_CANCELLED  
- TICKET_RESTORED  

---

## 7. Acceptance Criteria

### Functional
- Start/Pause/Resume/Complete/Cancel/Restore ทำงานได้ครบ  
- UI แสดงปุ่มตาม state ถูกต้อง  
- TokenLifecycle ทำงานสอดคล้อง  
- ETA/Health ไม่พังแม้ state transition รวดเร็ว  

### Non‑Functional
- No schema migration  
- No breaking change  
- No side effects กับ Hatthasilpa  

---

## 8. Deliverables

- Updated `source/job_ticket.php`  
- Updated `assets/javascripts/hatthasilpa/job_ticket.js`  
- Updated `views/job_ticket.php` หากจำเป็น  
- Updated `TokenLifecycleService` (เฉพาะ integration methods)  
- `task24_4_results.md`

---

## 9. Notes for Agent
- ห้ามแก้ชื่อไฟล์ hatthasilpa/job_ticket.js  
- ห้ามแตะ Hatthasilpa Jobs  
- เปลี่ยนเฉพาะ Classic Job Ticket  
- ทำ patch ให้ atomic → ไม่กระทบ tasks อื่น  
- ใส่ comments ว่า “Classic Lifecycle v2” ในจุดที่แก้ไข  
- อย่าแก้ไขโค้ด PWA (เช่นไฟล์ในโฟลเดอร์ `pwa/` หรือ `mobile/`) ใน Task นี้
- ถ้าจำเป็นต้องเตรียม hook/API สำหรับ PWA ให้ทำแบบ generic ในฝั่ง backend เท่านั้น (เช่น เพิ่ม action ใหม่ใน job_ticket.php) โดยไม่ออกแบบ UI PWA ใน Task นี้

Task 24.4 พร้อมให้ AI Agent ทำงานต่อ