✅ Task 20.3 — Worker App: Token Execution Engine (Phase 1–3 Plan)

(Prompt พร้อมรันใน Cursor)
Phase 1 พร้อมรันทันที, Phase 2–3 คือแผนต่อเนื่องในไฟล์เดียวกัน (ให้ Cursor ทำทีละ Phase ตามลำดับ)

⸻


### 🟧 TASK 20.3 — Worker App: Token Execution Engine (Phase 1: Core API)

## 🎯 OBJECTIVE
Implement the backend API layer that will allow the Worker App to:
- Start a token
- Pause a token
- Resume a token
- Complete a token
- Update active operation data
- Fetch the next task in queue

All new logic MUST rely on:
- TokenLifecycleService (already timezone-migrated)
- TokenWorkSessionService (already timezone-migrated)
- TimeHelper (canonical source of time)
- DAGRoutingService (to compute next node)

This task is ONLY for **backend APIs**.  
No UI. No PWA work.  
Strictly follow the Architecture Map.

---

## 📌 REQUIREMENTS (MANDATORY)

### 1) Create new API file
`source/worker_token_api.php`

It must include ONLY actions below:

| Action | Description |
|--------|------------|
| start_token | Worker scans QR → token enters active work session |
| pause_token | Worker pauses work |
| resume_token | Worker resumes work |
| complete_token | Worker finishes the operation |
| get_current_work | For dashboard (worker current task) |
| get_next_work | Pull next task in queue |

Each action must:
- validate `id_token` (must exist)
- validate `id_employee` (must exist)
- use `TimeHelper::now()` for timestamps
- use `TokenLifecycleService` and `TokenWorkSessionService`
- return JSON structure (`ok`, `result`, `error`)

---

## 📌 BUSINESS RULES

### START
- A token can be started only if:
  - It is in WAIT, READY, or ASSIGNED state
- Create a work session
- Update token state → WORKING

### PAUSE
- Allowed only when token is WORKING
- Close current session (Pause)
- Set token state → PAUSED

### RESUME
- Allowed only when token is PAUSED
- Create NEW session
- Set token state → WORKING

### COMPLETE
- Allowed only if:
  - Token is WORKING or PAUSED
- Close final session
- Trigger DAGRoutingService to move token to next node
- Return `next_node_id`, `is_finish`

---

## 📌 TECHNICAL RULES

- No direct SQL queries — use service layer
- No direct `time()`, `date()` — use TimeHelper only
- No HTML output — pure JSON API
- Follow existing pattern of `dag_token_api.php`

---

## 📌 OUTPUT FORMAT EXAMPLES

### SUCCESS
```json
{ "ok": true, "result": { "token_id": 123, "next": "NODE_02" } }

ERROR

{ "ok": false, "error": "TOKEN_NOT_FOUND" }


⸻

📌 FILES TO CREATE / EDIT

Create:
	•	source/worker_token_api.php

No modification:
	•	No frontend files
	•	No PWA files
	•	No designer files

⸻

📌 SAFETY GUARD (IMPORTANT)
	•	Do NOT modify dag_token_api.php
	•	Do NOT modify existing routing logic
	•	Do NOT refactor TokenLifecycleService (already stable)
	•	Do NOT change DB schema
	•	Do NOT touch JS

⸻

📌 ACCEPTANCE CRITERIA
	•	Server runs with 0 syntax errors
	•	API returns correct JSON structure
	•	Timezone-safe timestamps everywhere
	•	Token lifecycle fully functional end-to-end
	•	No regressions in DAG routing
	•	No interference with existing ERP modules

⸻

☑️ DELIVERABLE

After completion, generate:
	•	docs/super_dag/tasks/task20_3_results.md
containing:
	•	Summary
	•	Modified files
	•	Example API requests/responses
	•	Known limitations

---

### 🟦 PHASE 2 — Safety & Concurrency Rules (Backend Only)

**เป้าหมาย:** เสริม core API จาก Phase 1 ให้ “ปลอดภัยต่อการใช้งานจริงในโรงงาน” โดยป้องกันเคส:
- คนหนึ่งถือหลายงานพร้อมกันโดยไม่ตั้งใจ
- งานชิ้นเดียวกันถูกเริ่มพร้อมกันสองคน
- Pause / Resume / Complete ข้ามคน (คนที่ไม่ได้เป็นเจ้าของ session)

> หมายเหตุ: Phase 2 ยังคงเป็น **backend only** ไม่มี UI, ไม่มี PWA

#### ✅ REQUIREMENTS (PHASE 2)

**1) Hard Invariants (ต้องบังคับใช้):**

1. **One Active Token per Employee**
   - พนักงานหนึ่งคน (`id_employee`) ห้ามมีมากกว่า 1 token อยู่ในสถานะ WORKING พร้อมกัน
   - ถ้า worker เรียก `start_token` หรือ `resume_token` แล้วมี active token อยู่แล้ว:
     - ให้ return:
       ```json
       { "ok": false, "error": "EMPLOYEE_HAS_ACTIVE_TOKEN" }
       ```
     - พร้อม `active_token_id` ใน `meta` ถ้าสามารถดึงได้

2. **Single Owner per Active Token**
   - token หนึ่งตัวในสถานะ WORKING หรือ PAUSED ต้องมี “owner” ชัดเจน (id_employee ล่าสุดที่ start/resume)
   - ถ้า worker A พยายาม `pause_token`, `resume_token`, `complete_token` ของ token ที่ owned โดย worker B:
     - ให้ return:
       ```json
       { "ok": false, "error": "TOKEN_OWNED_BY_ANOTHER_EMPLOYEE" }
       ```

3. **No Start on Completed / Cancelled Tokens**
   - ถ้า token อยู่ในสถานะ FINISHED, CANCELLED, SCRAPPED:
     - `start_token`, `resume_token`, `pause_token`, `complete_token` ต้อง return:
       ```json
       { "ok": false, "error": "TOKEN_NOT_ACTIVE" }
       ```

**2) Soft Rules (เตือน แต่ไม่บังคับ):**

4. **Long-Idle Session Warning**
   - ถ้า `resume_token` แล้วพบว่า token เคยถูก pause ไว้นานเกิน N ชั่วโมง (เช่น 8 ชม.):
     - อนุญาตให้ resume ได้
     - แต่ให้เพิ่ม `warning`:
       ```json
       {
         "ok": true,
         "result": { ... },
         "warning": "RESUME_AFTER_LONG_IDLE"
       }
       ```

**3) Integration Requirements**

- ห้ามเขียน SQL เองเพื่อเช็ค session
- ให้ใช้ `TokenWorkSessionService` / `TokenLifecycleService` สำหรับ:
  - ตรวจ active session ของ employee
  - ตรวจ owner ล่าสุดของ token
- ใช้ `TimeHelper::now()` สำหรับทุกการเปรียบเทียบเวลา

**4) Output Format**

ทุก action จาก Phase 1 ที่เกี่ยวข้อง (start, pause, resume, complete) ต้องเพิ่ม `meta` เมื่อมีข้อมูลให้:

```json
{
  "ok": true,
  "result": {
    "token_id": 123,
    "state": "WORKING"
  },
  "meta": {
    "owner_employee_id": 45,
    "active_session_id": 789
  }
}
```

หรือในกรณี error:

```json
{
  "ok": false,
  "error": "EMPLOYEE_HAS_ACTIVE_TOKEN",
  "meta": {
    "active_token_id": 999
  }
}
```

**SAFETY GUARD (PHASE 2)**  
- ห้ามเปลี่ยน signature ของ Phase 1 actions (ให้เพิ่ม field, ห้าม breaking change)
- ห้ามเปลี่ยน routing logic เดิม
- ห้ามแก้ TokenLifecycleService ลึกๆ (เพิ่ม method ได้ แต่ห้าม breaking change)

**ACCEPTANCE CRITERIA (PHASE 2)**  
- มี invariant checks ครบทั้ง 3 ข้อ
- มี warning RESUME_AFTER_LONG_IDLE ทำงานจริง
- Test manual: สร้างเคส worker A/B ทดสอบ cross-ownership
- ไม่มี regression กับ behavior จาก Phase 1


---

### 🟩 PHASE 3 — Token Timeline & Diagnostics API (Backend Only)

**เป้าหมาย:** เพิ่ม API อ่านอย่างเดียว (read-only) เพื่อให้ Worker App / Dashboard ในอนาคตสามารถ:
- แสดง timeline ของงานต่อ token
- แสดงประวัติการทำงานของคน (per employee)
- แสดงสรุปประจำวัน (work summary)

> หมายเหตุ: Phase 3 ก็ยังเป็น **backend only** เช่นกัน UI/PWA จะไปทำ task อื่น

#### ✅ NEW ACTIONS (PHASE 3) — ใน `worker_token_api.php`

เพิ่ม actions ต่อไปนี้ (read-only):

| Action | Description |
|--------|------------|
| get_token_timeline | ดึง timeline ของ token: start/pause/resume/complete sessions |
| get_worker_timeline | ดึงงานที่ employee คนนั้นเคยทำในช่วงเวลาที่กำหนด |
| get_worker_daily_summary | ดึงสรุปเวลาทำงาน / จำนวน token ต่อวัน |

**1) get_token_timeline**

- Input:
  - `id_token` (required)
- Behavior:
  - อ่านข้อมูลจาก TokenWorkSessionService / TokenLifecycleService
  - คืนลิสต์ของ sessions ตามลำดับเวลา
- Output:

```json
{
  "ok": true,
  "result": {
    "token_id": 123,
    "timeline": [
      {
        "session_id": 1,
        "employee_id": 45,
        "state": "WORKING",
        "started_at": "2025-01-01T09:00:00+07:00",
        "ended_at": "2025-01-01T09:30:00+07:00",
        "duration_ms": 1800000,
        "source": "start_token"
      },
      {
        "session_id": 2,
        "employee_id": 45,
        "state": "PAUSED",
        "started_at": "2025-01-01T09:30:00+07:00",
        "ended_at": "2025-01-01T10:00:00+07:00",
        "duration_ms": 1800000,
        "source": "pause_token"
      }
    ]
  }
}
```

**2) get_worker_timeline**

- Input:
  - `id_employee` (required)
  - `date_from`, `date_to` (optional, default = วันนี้)
- Behavior:
  - ดึงทุก session ที่ employee คนนี้มีส่วนเกี่ยวข้อง
- Output (ตัวอย่าง):

```json
{
  "ok": true,
  "result": {
    "employee_id": 45,
    "sessions": [
      {
        "token_id": 123,
        "node_code": "CUT",
        "started_at": "2025-01-01T09:00:00+07:00",
        "ended_at": "2025-01-01T09:30:00+07:00",
        "duration_ms": 1800000
      },
      {
        "token_id": 124,
        "node_code": "SEW",
        "started_at": "2025-01-01T10:00:00+07:00",
        "ended_at": "2025-01-01T11:15:00+07:00",
        "duration_ms": 4500000
      }
    ]
  }
}
```

**3) get_worker_daily_summary**

- Input:
  - `id_employee` (required)
  - `date` (optional, default = วันนี้)
- Behavior:
  - สรุปเวลาและจำนวน token สำหรับวันนั้น:
    - `total_active_ms`
    - `token_count`
    - `by_node` (group ตาม node_code)
- Output (ตัวอย่าง):

```json
{
  "ok": true,
  "result": {
    "employee_id": 45,
    "date": "2025-01-01",
    "total_active_ms": 6300000,
    "token_count": 3,
    "by_node": [
      { "node_code": "CUT", "token_count": 1, "active_ms": 1800000 },
      { "node_code": "SEW", "token_count": 2, "active_ms": 4500000 }
    ]
  }
}
```

**TECHNICAL RULES (PHASE 3)**

- ใช้ TimeHelper สำหรับทุก field timestamp / date
- ห้าม join ตารางหนักๆ แบบไม่มี index (ถ้าจำเป็นให้ใส่ TODO ชัดเจน)
- ห้ามรวม business logic ของ routing มาปนใน timeline (อ่านอย่างเดียว)

**SAFETY GUARD (PHASE 3)**  
- ห้ามแก้ Phase 1 / Phase 2 behavior
- ห้ามเปลี่ยน structure ของ start/pause/resume/complete
- Phase 3 เป็น read-only เท่านั้น

**ACCEPTANCE CRITERIA (PHASE 3)**  
- มี 3 actions ใหม่ (get_token_timeline, get_worker_timeline, get_worker_daily_summary)
- ทุก action คืนค่า JSON สมบูรณ์
- ไม่มี side-effect (ไม่เขียน DB)
- ใช้ TimeHelper ถูกต้อง
- สามารถใช้ในอนาคตสำหรับ Worker App และ Dashboard ได้ทันที

---

จบ Task 20.3 Prompt (Phase 1–3) ให้ Cursor รันทีละ Phase ตามลำดับได้เลย
