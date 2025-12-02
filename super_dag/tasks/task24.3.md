
## Task 24.3 — Job Ticket Progress: Accuracy, Consistency & UI Fallback

**Phase:** 24 — Job Ticket  
**Task:** 24.3  
**Status:** Pending Implementation  
**Owner:** Backend + Frontend Integration  
**Last Updated:** _(auto after implementation)_

---

## 1. Objective

ยกระดับระบบ Progress ของ Job Ticket ให้มีความ:

- **ถูกต้อง (Accuracy)** — คิดเปอร์เซ็นต์ความคืบหน้าตามข้อมูลจริง ทั้งในโหมด DAG และ Linear
- **สม่ำเสมอ (Consistency)** — โครงสร้างข้อมูลเดียวกัน ใช้ได้กับทั้งสองโหมด, ตอบโต้กับ UI และระบบอื่น ๆ ได้ง่าย
- **ทนทานต่อข้อผิดพลาด (Resilient)** — หากข้อมูลไม่ครบ / ผิดปกติ ต้องไม่ทำให้ UI หรือ API พัง แต่ต้องส่งสัญญาณแจ้งเตือนที่ชัดเจน

Task 24.2 ได้สร้าง **JobTicketProgressService v1** และ **job_ticket_progress_api.php** พร้อมการแสดงผลเบื้องต้นในหน้า Job Ticket แล้ว  
Task 24.3 จะทำหน้าที่เป็น “ชั้นเสถียรภาพ (stability layer)” เพื่อ:

1. ทำให้ progress calculation มี **error model ที่ชัดเจน** (error_code / error_message / meta)  
2. ทำให้ API behavior มี **กติกา HTTP / JSON ชัดเจน** (อะไร 200, อะไร 404)  
3. ทำให้ UI มี **fallback behavior** ที่ชัดเจนเมื่อ progress คำนวณไม่ได้

---

## 2. Current Situation (จาก 24.2)

### 2.1 มีอะไรแล้ว

- `JobTicketProgressService`:
  - รองรับ 2 โหมด:
    - **DAG mode** → ใช้ข้อมูลจาก `flow_token` (token-based)
    - **Linear mode** → ใช้ข้อมูลจาก `job_task` และ/หรือ `task_operator_session`
  - คืนค่า structure พื้นฐาน: `ok`, `mode`, `progress_pct`, `completed_qty`, `target_qty`, `breakdown`, `meta`
  - ทำงานแบบ read-only (ไม่มี side-effects)

- `job_ticket_progress_api.php`:
  - action: `progress&job_ticket_id=...`
  - เรียก `JobTicketProgressService` แล้วคืน JSON ให้ frontend

- `views/job_ticket.php` + `assets/javascripts/hatthasilpa/job_ticket.js`:
  - Offcanvas detail มี Progress section
  - JS เรียก API เพื่อโหลด progress แล้ว render ลง UI

### 2.2 ปัญหาที่พบ/คาดการณ์

1. **Error Model ยังไม่ชัดเจนพอ**
   - `ok=false` อาจเกิดจากหลายสาเหตุ แต่ยังไม่มี `error_code` ที่แน่นอน
   - UI ไม่รู้ว่า progress คำนวณไม่ได้เพราะ:
     - Ticket ไม่เจอ
     - ไม่มี DAG tokens
     - ไม่มี tasks (legacy ticket)
     - หรือ graph หาย

2. **API Mapping HTTP Status ยังหยาบ**
   - ตอนนี้ `ok=false` อาจถูก map เป็น 404 ทั้งหมด ซึ่งไม่ถูกต้องในทุกกรณี
   - กรณีข้อมูลขาดบางส่วน → ควรตอบ 200 พร้อม error_code ให้ UI handle เอง

3. **UI Fallback ยังไม่ชัด**
   - ถ้า progress คำนวณไม่ได้ UI อาจแสดง 0% (ทำให้เข้าใจผิดว่าเป็น 0 ไม่ใช่ N/A)
   - ยังไม่มีข้อความสื่อสารกับ user หรือ badge ชัด ๆ ว่า “ข้อมูลไม่เพียงพอ / กราฟหาย / ไม่มี tokens”

4. **ความสัมพันธ์ระหว่าง DAG vs Linear ยังไม่ถูก log/อธิบายชัด**
   - บาง ticket ที่ควรเป็น DAG อาจ fallback ไป Linear แบบเงียบ ๆ (กรณี graph_instance หาย)
   - ต้องมีทั้ง meta และ log เพื่อใช้ debug ในอนาคต

---

## 3. Goals ของ Task 24.3

### 3.1 Functional Goals

1. เพิ่ม **error / reason metadata** ใน `JobTicketProgressService` ให้ละเอียดพอสำหรับ UI และระบบตรวจสอบ (Audit/Health) ในอนาคต
2. แก้ไข `job_ticket_progress_api.php` ให้ mapping ระหว่าง error_code ↔ HTTP status ชัดเจน
3. ปรับ frontend (`job_ticket.js`) ให้มี **UI fallback ที่อ่านเข้าใจง่าย** ในทุก case ที่ progress ใช้งานไม่ได้

### 3.2 Non-Functional Goals

1. **Backward Compatible**
   - ไม่เปลี่ยน signature หลักของ API ในแบบที่ client พัง
   - เพิ่ม field ใหม่แบบ additive เท่านั้น

2. **Error-proof**
   - ไม่เกิด PHP notice/warning เพราะ meta structure ไม่ครบ
   - ไม่เกิด JS error เพราะ field ไม่อยู่ตามที่คาด

3. **Extendable**
   - โครงสร้าง error_code เหมาะสำหรับต่อยอดใช้กับ ETA / Health / Audit pipeline ใน Phase ต่อ ๆ ไป

---

## 4. Design – Backend

### 4.1 ขยายผลลัพธ์ของ JobTicketProgressService

ไฟล์: `source/BGERP/JobTicket/JobTicketProgressService.php`

เพิ่ม/ปรับโครงสร้างผลลัพธ์ให้รองรับ metadata ดังนี้ (ตัวอย่าง):

```php
return [
    'ok'            => false,
    'mode'          => 'dag',        // หรือ 'linear' | 'unknown'
    'progress_pct'  => null,         // ในกรณี error ให้เป็น null
    'completed_qty' => null,
    'target_qty'    => null,
    'breakdown'     => [
        'stages' => [],
        'nodes'  => [],
    ],
    'meta'          => [
        'error_code'    => 'NO_TOKENS',
        'error_message' => 'This ticket has no DAG tokens.',
        'reason'        => 'dag_without_tokens',
        'data_source'   => 'token',   // หรือ 'task', 'session', 'none'
        'formula'       => 'completed_qty/target_qty',
        'flags'         => [
            'no_tasks'      => false,
            'has_sessions'  => false,
            'fallback_used' => false,
        ],
        'notes'        => [
            'Graph instance found but no tokens for this ticket.',
        ],
    ],
];
```

#### 4.1.1 error_code ที่ต้องรองรับ (minimal set)

- `TICKET_NOT_FOUND` — ไม่พบ job ticket ตาม id ที่ส่งมา
- `NO_DATA` — ไม่พบทั้ง tasks, tokens, หรือข้อมูลอื่นที่ใช้คำนวณ progress
- `NO_GRAPH` — ticket ถูก mark ว่าเป็น DAG แต่ไม่พบ graph instance
- `NO_TOKENS` — DAG ticket แต่ไม่มี tokens เลย
- `NO_TASKS` — Linear ticket แต่ไม่มี tasks เลย
- `INVALID_MODE` — ticket อยู่ในสถานะ/โหมดที่ logic ยังไม่รองรับ
- `MISSING_REQUIRED_FIELDS` — ขาด field สำคัญ เช่น target_qty โดยไม่สามารถหา fallback ได้

> หมายเหตุ: ใน Task นี้ให้ implement ขั้นต่ำตามรายการด้านบน แต่ควรออกแบบให้สามารถเพิ่ม error_code ใหม่ในอนาคตได้ง่าย

#### 4.1.2 การตัดสินใจโหมดและ error

Pseudo-logic (แนวคิด):

```php
$ticket = $this->fetchTicket($jobTicketId);
if (!$ticket) {
    return $this->error('TICKET_NOT_FOUND', 'Job ticket not found', 'unknown');
}

$mode = $this->detectMode($ticket); // 'dag' | 'linear' | 'unknown'

if ($mode === 'dag') {
    $res = $this->computeDagProgress($ticket);
    if (!$res['ok'] && $res['meta']['error_code'] === 'NO_TOKENS') {
        // ตัวอย่าง: สามารถ fallback เป็น linear ได้ในอนาคต (ถ้า design อนุญาต)
    }
    return $res;
}

if ($mode === 'linear') {
    return $this->computeLinearProgress($ticket);
}

// else: unknown
return $this->error('INVALID_MODE', 'Unsupported ticket mode', 'unknown');
```

> ใน Task 24.3 เน้นให้ error model ชัดเจนก่อน ส่วน logic fallback ข้ามโหมด (เช่น DAG → Linear) เป็น optional, ทำได้เฉพาะถ้าแน่ใจว่าไม่ทำให้คนตีความผิด

#### 4.1.3 meta.data_source และ meta.formula

เพื่อให้ Phase ต่อไป (ETA/Health/Audit) สามารถตีความ progress ได้ถูกต้อง ให้ระบุแหล่งข้อมูลและสูตรคำนวณที่ใช้:

- `data_source`: `'token' | 'task' | 'session' | 'mixed' | 'none'`
- `formula` ตัวอย่างเช่น:
  - `completed_qty/target_qty`
  - `completed_tasks/total_tasks`
  - `session_qty/target_qty`

ข้อมูลนี้จะไม่ใช้ใน UI ปัจจุบันทันที แต่สำคัญมากสำหรับการ debug และ monitoring ภายหลัง

---

### 4.2 ปรับ job_ticket_progress_api.php

ไฟล์: `source/job_ticket_progress_api.php`

#### 4.2.1 กติกา mapping HTTP status

- ถ้า `error_code === 'TICKET_NOT_FOUND'` → ส่ง HTTP 404
- กรณีอื่น ๆ ทั้งหมด → ส่ง HTTP 200 แล้วให้ client ตัดสินใจตาม `ok` และ `meta.error_code`

ตัวอย่าง:

```php
$result = $service->computeProgress($jobTicketId);

if ($result['ok'] === false && ($result['meta']['error_code'] ?? null) === 'TICKET_NOT_FOUND') {
    http_response_code(404);
} else {
    http_response_code(200);
}

echo json_encode($result);
```

#### 4.2.2 X-AI-Trace / Execution Time

- ย้ายการ set header `X-AI-Trace` หรือ execution_ms ต่าง ๆ ไปจุดเดียวตอนท้าย (หลังคำนวณ progress เสร็จ)
- อย่าตั้ง header ซ้ำหลายครั้งแบบไม่จำเป็น

#### 4.2.3 ป้องกันการเข้าถึง meta.warnings[0] ตรง ๆ

- ใช้ `error_message` เป็น primary field สำหรับ error
- ถ้าจำเป็นจะรวม warnings ให้รวมเป็น array ใน `meta.notes` หรือ `meta.warnings`
- หลีกเลี่ยงการ assume ว่าจะมี index `[0]` เสมอ

---

## 5. Design – Frontend (job_ticket.js)

ไฟล์: `assets/javascripts/hatthasilpa/job_ticket.js`

### 5.1 UI Fallback สำหรับ Progress Section

ใน `renderTicketProgress(data)` และ/หรือ `renderTicketProgressError(err)`:

- ถ้า `data.ok === true` → แสดง progress ปกติ (bar + percentage + qty)
- ถ้า `data.ok === false` → ให้ใช้ `meta.error_code` / `meta.error_message` เพื่อแสดงสถานะ

ตัวอย่าง mapping:

| error_code           | UI Text (ตัวอย่าง)                          |
|----------------------|----------------------------------------------|
| `NO_TOKENS`          | `Progress: — (No work tokens found)`         |
| `NO_TASKS`           | `Progress: — (No tasks defined)`             |
| `NO_GRAPH`           | `Progress: — (Routing graph missing)`        |
| `NO_DATA`            | `Progress: — (No production data yet)`       |
| `INVALID_MODE`       | `Progress: — (Unsupported ticket mode)`      |
| `MISSING_REQUIRED_FIELDS` | `Progress: — (Incomplete configuration)` |

รูปแบบ UI แนะนำ:

```text
Progress: —
(reason: No work tokens found)
```

- ไม่ควรแสดง `0%` ในกรณี error เพราะจะทำให้เข้าใจผิดว่าเป็น 0% จริง ๆ
- ใช้ `—` หรือ `N/A` แทน และแสดง reason แบบสั้น ๆ ด้านล่างหรือ tooltip

### 5.2 ความทนทาน (Defensive JS)

- ถ้า response ไม่มี `meta` หรือไม่มี `error_code` ให้ fallback เป็นข้อความกลาง เช่น:
  - `Progress: — (Not available)`
- ตรวจสอบค่าที่อ่านจาก response ทุกครั้งก่อนใช้งาน

### 5.3 การเรียก API

- ยังคงเรียกเพียงครั้งเดียวเมื่อเปิด offcanvas หรือเปลี่ยน ticket
- ไม่ต้องทำ polling ใน Task นี้

---

## 6. Files in Scope

ต้องแก้ไขอย่างน้อย:

1. `source/BGERP/JobTicket/JobTicketProgressService.php`
2. `source/job_ticket_progress_api.php`
3. `assets/javascripts/hatthasilpa/job_ticket.js`
4. `views/job_ticket.php` (เล็กน้อยในส่วน progress text/tooltip ถ้าจำเป็น)

---

## 7. Testing Plan

สร้าง/อัปเดตไฟล์ผลลัพธ์:

- `docs/super_dag/tasks/results/task24_3_results.md`

ให้ระบุ:

1. **สรุป Implementation**
   - อธิบาย DAG vs Linear progress logic (โดยเฉพาะ error paths)
2. **Test Cases** (อย่างน้อย 10 เคส):
   - Ticket ไม่เจอ (TICKET_NOT_FOUND)
   - Ticket DAG ที่ไม่มี tokens (NO_TOKENS)
   - Ticket DAG ที่ graph_instance หาย (NO_GRAPH)
   - Ticket Linear ไม่มี tasks (NO_TASKS)
   - Ticket ที่ progress ปกติ (DAG, มี tokens)
   - Ticket ที่ progress ปกติ (Linear, มี tasks)
   - Ticket ที่ไม่มีข้อมูลเลย (NO_DATA)
   - Ticket ที่ field สำคัญขาด (MISSING_REQUIRED_FIELDS)
   - Ticket ที่ mode ไม่รองรับ (INVALID_MODE)
   - Legacy ticket ที่ยังแสดง progress ได้แบบ linear
3. **Error-proof Validation**
   - ไม่มี PHP notice/warning เกี่ยวกับ meta/array index
   - ไม่มี JS error ใน console เมื่อ response เป็น error

---

## 8. Acceptance Criteria

- JobTicketProgressService ส่ง `error_code` / `error_message` ที่สอดคล้องกับสถานการณ์จริง
- job_ticket_progress_api.php ใช้ HTTP 404 เฉพาะกรณี ticket ไม่เจอเท่านั้น
- UI Job Ticket แสดง fallback ที่อ่านออกและไม่หลอกให้เข้าใจผิดว่า progress=0 ในทุกกรณีที่ข้อมูลไม่พร้อม
- ไม่มี error ใน PHP log และ browser console จากการใช้งาน progress API
- โครงสร้างผลลัพธ์พร้อมสำหรับนำไปใช้ใน Phase ถัดไป (ETA/Health/Audit) โดยไม่ต้องแก้ไขใหญ่

---

> **Note for Agent:**
> - ห้ามเพิ่ม DB migration ใน Task นี้
> - ห้ามแก้ behavior ของ token lifecycle หรือ canonical events
> - ทำเฉพาะการปรับ service, API, และ UI ตาม spec นี้แบบ additive และ backward compatible เท่านั้น