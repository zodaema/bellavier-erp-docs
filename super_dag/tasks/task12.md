

# Super DAG – Task 12
**Title:** Advanced Session & Time Safeguards (STITCH v2)  
**Area:** super_dag / Time Engine / Behavior Execution  
**Depends on:** Task 5–11 (behavior spine, Time Engine integration, session lifecycle)  
**Target scope:** STITCH behavior only (Hatthasilpa line) – no CUT/EDGE logic yet

---

## 1. Background & Problem Statement

หลังจาก Task 7–11:
- STITCH behavior สามารถ **start / pause / resume / complete** session ได้ครบ
- Session lifecycle ถูกบังคับให้ต้อง **ปิด session ก่อน route** (Task 11)
- มี `session_summary` สำหรับใช้ใน analytics/report

แต่ยังขาด “เกราะป้องกัน” ปัญหาในโลกจริง เช่น:
- ช่างลืมกด pause แล้วกลับบ้าน → session ค้างข้ามวัน, เวลาเพี้ยน
- เบราเซอร์ค้าง/ปิด → กลับมาเปิดใหม่ เวลาไม่ตรงกับของจริง
- Worker คนเดียวเผลอมี **2 งาน active พร้อมกัน** (ผิด logic และทำให้เวลาบวม)
- ต้องมีวิธีให้หัวหน้าหรือระบบ **recover / override** ได้อย่างปลอดภัยเมื่อมีกรณีผิดปกติ

Task 12 จะยกระดับ Time Engine ของ STITCH จาก “ทำงานได้” → “ปลอดภัยในโลกจริง” โดยไม่ทำให้การใช้งานของช่างยุ่งยากเกินไป

---

## 2. Goal & Non-Goal

### 2.1 Goals (สิ่งที่ต้องได้ใน Task 12)

1. **Stale Session Detection (ตรวจจับ Session ที่เพี้ยน/ค้าง)**
   - ตรวจจับ session ที่อยู่ในสถานะ active นานผิดปกติ (เช่น > 8 ชม., หรือข้ามวัน)
   - ไม่ให้เวลาถูกนับต่อแบบไร้ขีดจำกัด
   - ส่งสัญญาณให้ UI และบันทึกลง log อย่างชัดเจน

2. **Single-Active-Work Rule per Worker (ห้าม 1 คน ทำ 2 งานพร้อมกัน)**
   - ป้องกันไม่ให้ worker คนเดียวมี session STITCH active มากกว่า 1 session พร้อมกัน
   - ถ้า user พยายาม start/resume งานใหม่ทั้งที่มี session active อยู่แล้ว → ต้องมี guard และ flow ที่ชัดเจน

3. **Recovery & Override Flows (กรณีผิดปกติ)**
   - รองรับเคส เช่น เครื่องค้าง, ปิด browser, tab หลุด, worker เปลี่ยนโต๊ะเย็บกลางคัน ฯลฯ
   - ออกแบบวิธีการ “ปิด session เก่าอย่างปลอดภัย” และเริ่ม session ใหม่
   - รองรับ “supervisor override” ในอนาคต (ด้วย flag/field) โดยยังไม่ต้องทำ UI เต็ม ๆ ใน Task นี้

4. **Clear Error Contract & JSON Schema**
   - ทุกกรณีที่ block action (start/pause/resume/complete) ต้องมี error code + message ที่สื่อความหมายชัดเจน
   - JSON response format ต้อง **backward compatible** กับ Task 10–11

### 2.2 Non-Goals (สิ่งที่ไม่ทำใน Task 12)

- ยัง **ไม่** รองรับ CUT/EDGE/HARDWARE/QC behaviors – โฟกัสเฉพาะ STITCH ก่อน
- ยัง **ไม่** ทำ UI สำหรับ supervisor override แบบเต็มตัว (เพียงแต่เตรียมข้อมูล/field + error code ให้พร้อม)
- ยัง **ไม่** เปลี่ยนแปลงรายงานหรือ dashboard – แค่เตรียมข้อมูลให้ Time/Session reports ใช้ในอนาคต
- ยัง **ไม่** แก้ logic DAG split/merge หรือ token distribution (จะทำใน tasks ถัดไป)

---

## 3. Desired Behavior – STITCH Session Safety

### 3.1 คำนิยามสำคัญ

- **Active session:** session ใน `token_work_session` ที่มี `status = 'active'` (นิยามตาม service ปัจจุบัน)
- **Paused session:** มี status ตามที่ Time Engine ใช้อยู่ (ไม่เปลี่ยน enum เดิม)
- **Stale session (เบื้องต้น):**
  - session ที่มีสถานะ active และ
  - `now - last_update_at` เกิน `STALE_THRESHOLD_MINUTES` (เช่น 480 นาที / 8 ชม. – ให้ใช้ config/constant)

> หมายเหตุ: ให้เขียน code เผื่อไว้สำหรับการปรับ threshold ในอนาคต (อย่า hard-code ตัวเลขลึกใน logic หลายจุด)

---

### 3.2 Single Active Session per Worker (STITCH)

**Rule หลัก:**
> สำหรับ behavior = STITCH, worker 1 คน ต้องมีได้ไม่เกิน 1 active session พร้อมกัน

#### Case A: Worker พยายาม `stitch_start`
- ถ้า **ไม่มี** active session อื่นของ worker นี้ → อนุญาตให้ start
- ถ้า **มี** active session อื่น (token คนละใบ) → block action พร้อม response:
  - HTTP 409 (Conflict)
  - `error`: `BEHAVIOR_STITCH_CONFLICTING_SESSION`
  - `conflict` object:
    - `token_id`
    - `work_center_id`
    - `started_at`
    - `elapsed_seconds_estimate`
    - `is_stale` (true/false)

#### Case B: Worker พยายาม `stitch_resume`
- ถ้ามี active session ของ token ปัจจุบันอยู่แล้ว → error `BEHAVIOR_SESSION_ALREADY_ACTIVE`
- ถ้ามี active session อื่น (token อื่น) → error `BEHAVIOR_STITCH_CONFLICTING_SESSION` เช่นกัน (พร้อม `conflict` object)

> **UI ภายหลัง** จะสามารถใช้ `conflict` object นี้เพื่อแสดง dialog ให้หัวหน้าตัดสินใจ (แต่ Task 12 ยังไม่ต้องทำ dialog ซับซ้อนมาก แค่แสดงข้อความแจ้งเตือนและ block action ก็พอ)

---

### 3.3 Stale Session Detection & Auto-Soft-Stop

เมื่อ worker เรียก action ใด ๆ ของ STITCH (start/pause/resume/complete):

1. Service ควรตรวจสอบ **ทุก active session ของ worker** ใน background:
   - การเรียกซ้ำ ๆ นี้ไม่ควร throw fatal – แค่ log warning + ปรับ field ตามจำเป็น

2. ถ้าพบ session ที่เข้าเงื่อนไข stale (active นานเกิน threshold):
   - ให้ mark session นั้นเป็นสถานะใหม่ เช่น `status = 'stale'` หรือใช้ `is_stale` flag (ต้องใช้วิธีที่ไม่พัง logic เดิม)
   - หยุดการนับเวลาต่อ (Time Engine ไม่ควรทบเวลาต่อจนล้น)
   - บันทึกลง `dag_behavior_log` หรือ log อื่น ๆ ว่าเกิด stale state

3. Behavior ต่อไป:
   - ถ้า worker จะ resume งานเดิมที่ stale → ต้องแจ้ง error หรือ warning ชัดเจน เช่น:
     - `BEHAVIOR_STITCH_SESSION_STALE` (409)
     - response อาจเสนอ `suggested_action` เช่น "please contact supervisor" หรือ "close and start new"
   - ถ้าจะ start งานใหม่ทั้งที่มี session stale → ให้ treat เหมือน conflicting session แต่ flag `is_stale = true`

> ใน Task 12 เน้นที่การ **detect + block + log** ให้ชัดเจนก่อน ส่วน flow แก้ไขใน UI แบบ advance (เช่น supervisor close) จะอยู่ใน Task ถัดไป

---

### 3.4 Minimal Recovery Flow (Worker Self-Recovery)

แม้จะยังไม่มี supervisor UI เต็ม ๆ แต่ในโลกจริง worker ต้องทำงานต่อได้ ไม่เช่นนั้นระบบจะกลายเป็นตัวถ่วงงาน:

1. เพิ่ม method ใน Time Engine wrapper (ถ้ายังไม่มี):
   - `forceCloseSessionForWorkerAndToken($workerId, $tokenId, $reason)`
   - ต้องระวัง **มาก** – ห้ามเรียกแบบอัตโนมัติพร่ำเพรื่อ ให้ใช้เฉพาะใน flow ที่กำหนดชัดเจน

2. ใน Task 12 ให้ทำ **minimal recovery flow** ก่อน:
   - ถ้าพบว่า session สำหรับ token เดียวกันของ worker ค้างเป็น stale และ workerพยายาม `stitch_start` ใหม่บน token เดิม:
     - อนุญาตให้ **force close session เดิม** (ด้วย reason `"stale_self_recover"`)
     - จากนั้นค่อย `startSession()` ใหม่
   - ต้องบันทึกลง log ชัดเจนว่าเกิด self-recovery

3. สำหรับกรณี token อื่น (ไม่ใช่ token เดิม):
   - ยังไม่อนุญาตใน Task 12 → ให้ error `BEHAVIOR_STITCH_CONFLICTING_SESSION` เพื่อบังคับให้แก้ไขผ่าน supervisor ใน Task ต่อไป

---

## 4. Changes Required

### 4.1 PHP – Token Session Service (DAG Wrapper)

**File:** `source/BGERP/Dag/TokenWorkSessionService.php`

1. เพิ่ม helper methods:
   - `findActiveSessionsByWorker(int $workerId): array`
   - `markSessionAsStale(int $sessionId): void` (หรือ changeStatus)
   - `isSessionStale(array $session): bool` (ใช้ threshold เดียวกับที่ Task 11 เตรียมไว้)
   - `forceCloseSessionForWorkerAndToken(int $workerId, int $tokenId, string $reason): array`  
     - return summary ของ session ที่ถูกปิด

2. ห้าม:
   - เปลี่ยน enum/status เดิมแบบ breaking
   - เปลี่ยน signature methods ที่มีอยู่แล้ว

### 4.2 PHP – BehaviorExecutionService

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

1. ใน handler ของ STITCH (`handleStitch()`):
   - ก่อน `startSession()` หรือ `resumeSession()` ให้เรียก logic:
     - ตรวจ active sessions ของ worker ทั้งหมด
     - แยก**กรณี conflict** กับ **กรณี stale self-recover** (token เดียวกัน)
   - แปลงเป็น error codes ตามที่กำหนดใน section 3.2–3.4

2. ในทุก action ของ STITCH ให้เรียกฟังก์ชันตรวจ stale session **แบบ background**:
   - ถ้ามี stale session แล้ว มีผลต่อ action ปัจจุบัน → ส่ง error ตาม spec
   - ถ้าไม่มีผล (เช่น action ปกติของ token อื่น) → log warning อย่างเดียว

### 4.3 PHP – DagExecutionService

**File:** `source/BGERP/Dag/DagExecutionService.php`

- ยืนยันว่าก่อน routing เรียก guard เดิมจาก Task 11 (`DAG_SESSION_STILL_ACTIVE`) ได้ทำงานร่วมกับ stale logic ได้อย่างถูกต้อง
- ถ้ามีการ force close session ก่อน complete → guard นี้ไม่ควร block routing โดยไม่จำเป็น

### 4.4 API Endpoint

**File:** `source/dag_behavior_exec.php`

- อัปเดตรายการ error codes ที่ mapping เป็น HTTP status:
  - `BEHAVIOR_STITCH_CONFLICTING_SESSION` → 409
  - `BEHAVIOR_STITCH_SESSION_STALE` → 409
  - อื่น ๆ คงเดิม
- ทำให้แน่ใจว่า field ใหม่ เช่น `conflict`, `session_summary`, `suggested_action` เป็น **optional** เพื่อไม่ทำลาย client เดิม

### 4.5 JavaScript (Minimal UI Feedback)

**Files:**
- `assets/javascripts/dag/behavior_execution.js`
- `assets/javascripts/pwa_scan/work_queue.js`
- `assets/javascripts/pwa_scan/pwa_scan.js`
- (ถ้าจำเป็น) `assets/javascripts/hatthasilpa/job_ticket.js`

1. ใน `BGBehaviorExec.send()` หรือ handler ที่เกี่ยวข้อง:
   - หากพบ error code:
     - `BEHAVIOR_STITCH_CONFLICTING_SESSION`
     - `BEHAVIOR_STITCH_SESSION_STALE`
   - ให้แสดง toast/alert แบบ **อ่านง่าย** (ไม่ต้อง dialog ซับซ้อน):
     - อธิบายสั้น ๆ ว่า "มีงานอีกใบที่ยังค้างอยู่" หรือ "เวลางานใบนี้ค้างข้ามวันแล้ว"

2. อย่าทำ auto-recover ใน frontend ใน Task 12:
   - อย่าเรียก API ซ้ำเพื่อแก้เอง
   - ให้เพียงแจ้ง worker ให้หยุดและแจ้งหัวหน้า หรือใช้ flow self-recover ที่ backend นิยามไว้เท่านั้น

---

## 5. Error Codes (เพิ่มจาก Task 10–11)

เพิ่มใน family `BEHAVIOR_*` สำหรับ STITCH:

- `BEHAVIOR_STITCH_CONFLICTING_SESSION` (409)
  - มี active session อื่นของ worker นี้อยู่แล้ว (token คนละตัว)
- `BEHAVIOR_STITCH_SESSION_STALE` (409)
  - session ของ token นี้ stale แล้ว ไม่อนุญาตให้ resume/start ต่อ
- (ใช้ต่อ) `BEHAVIOR_SESSION_ALREADY_ACTIVE`, `BEHAVIOR_NO_ACTIVE_SESSION_FOR_COMPLETE`

Backend ควรอัปเดตเอกสาร error mapping ที่เกี่ยวข้อง (เช่นใน `task10_results.md` ถ้ามีการอ้างอิง) ให้สอดคล้องกัน

---

## 6. Testing & Verification

### 6.1 Manual Test Matrix (อย่างต่ำ)

1. **Conflict – start ใบใหม่ขณะมี active session ใบอื่น**
   - Expect: 409 + `BEHAVIOR_STITCH_CONFLICTING_SESSION` + conflict object

2. **Conflict – resume ใบใหม่ขณะมี active session ใบอื่น**
   - Expect: เช่นเดียวกับข้อ 1

3. **Stale – ปล่อย session active ข้าม threshold แล้วลอง resume**
   - (ทดสอบโดยแก้เวลาใน DB / ใช้ script ช่วย)
   - Expect: 409 + `BEHAVIOR_STITCH_SESSION_STALE`

4. **Self-recover – token เดิม stale แล้ว worker start ใหม่บน token เดิม**
   - Expect: session เดิมถูกปิด (ด้วย reason), session ใหม่เริ่ม, log ถูกบันทึก

5. **Complete ขณะมี session active**
   - Expect: ต้องปิด session ก่อน routing (behavior ตาม Task 11) ยังคงทำงานร่วมกับ stale logic ได้

### 6.2 Automation (ถ้าทำได้ใน Task 12)

- เพิ่ม integration tests เบื้องต้นใน `tests/Integration/SuperDag/` (หรือโฟลเดอร์ที่ใช้จริง)
- เน้น scenario conflict + stale + normal flow

---

## 7. Acceptance Criteria

Task 12 จะถือว่า **เสร็จสมบูรณ์** เมื่อ:

1. Worker 1 คนไม่สามารถมี STITCH active session มากกว่า 1 ใบพร้อมกันได้
2. ระบบตรวจจับ stale sessions ได้ และ block การ resume/start แบบไม่รู้เรื่อง
3. มี minimal self-recovery flow สำหรับกรณี token เดิม (ไม่ทำลาย UX ของช่าง)
4. Error codes และ JSON schema สำหรับกรณี conflict/stale ถูกกำหนดและใช้งานจริง
5. ไม่มี breaking changes กับ client เดิม (field ใหม่ทั้งหมดเป็น optional)
6. มี test (manual + ถ้าเป็นไปได้ automated) ครอบคลุม scenario หลัก
7. เอกสารใน `task12_results.md` ถูกสร้างเมื่อ implement เสร็จ พร้อม list ของ scenarios ที่ผ่านแล้ว

---

## 8. Notes for AI Agent

เมื่อ implement ตามเอกสารนี้:

- ห้ามเปลี่ยน behavior ปกติที่ไม่มี conflict/stale (happy path ต้องทำงานเหมือน Task 11 ทุกประการ)
- ระวังไม่ให้ logic ใหม่ทำให้ performance ตกมาก (เช่น query หา active sessions ควรใช้ index และวิธีที่มีอยู่ใน service เดิม)
- ทุกจุดที่ "เดา" สิ่งที่ worker ต้องการ → ให้เลือกทางที่ **ปลอดภัยที่สุด** เสมอ (block + แจ้ง error) แล้วค่อยเพิ่ม UX ภายหลังใน tasks ถัดไป