ภาพรวมแผน Time Engine v2

ผมขอแบ่งเป็นเฟสแบบนี้ (ทั้งหมดจะค่อย ๆ ทำผ่าน Agent task แยกกัน):
	1.	Phase 1 – Core Engine (Back-end)
	•	สร้าง Service กลางสำหรับคำนวณเวลาทำงานของ session/token
	•	เลิกเขียน TIMESTAMPDIFF ดิบ ๆ ใน SQL แล้วใช้ Service เดียวทุกที่
	•	Work Queue ใช้ Engine ใหม่นี้เป็นที่แรก
	2.	Phase 2 – Front-end Timer (Drift-corrected)
	•	work_queue.js เปลี่ยนจาก “+1 ทุกวินาที” เป็น “คำนวณจาก base + delta เวลาเครื่อง”
	•	เพิ่มกลไก re-sync กับ server ทุก X วินาที
	3.	Phase 3 – Auto Guard / Abandoned Session
	•	cron / worker ที่ปิด session แปลก ๆ (ลืมกด pause, ปิดแท็บไปแล้ว ฯลฯ)
	•	rule ชัดเจน เช่น inactive > 2 ชม. → auto-pause
	4.	Phase 4 – Multi-surface Integration
	•	ให้ People Monitor, Trace overview, Analytics ใช้ Time Engine เดียวกัน
	•	รวมถึงรายงาน productivity, OEE, ฯลฯ

วันนี้ผมจะเขียน Task สำหรับ Phase 1 ให้เลย (เป็นฐานของทุกอย่าง)
ไฟล์แนะนำ:
docs/dag/agent-tasks/task12_TIME_ENGINE_V2_CORE_ENGINE_AND_WORK_QUEUE.md

⸻


# Task 1 – Time Engine v2 (Core Engine + Work Queue Integration)

**Type:** Backend foundation + minimal frontend wire-in  
**Scope (Phase 1):**
- สร้าง “Time Engine” กลางสำหรับคำนวณเวลาทำงานของ token_work_session
- ใช้งานใน `handleGetWorkQueue()` แทน CASE SQL เดิม
- ส่ง Timer DTO ที่เป็นมาตรฐานให้ frontend
- Frontend ยังใช้ setInterval แบบเดิมได้ก่อน (Phase 2 ค่อย refactor timer JS)

---

## 1. Goals

1. เลิกกระจาย logic คำนวณเวลาไว้ใน SQL / endpoint หลายจุด  
2. มี Service กลางที่ตอบคำถามง่าย ๆ ว่า  
   > “ตอนนี้ token/ session นี้ใช้เวลาไปแล้วกี่วินาที และ state คืออะไร?”
3. ให้ Work Queue เป็น consumer แรกของ Time Engine v2  
4. เตรียมพื้นสำหรับ Phase 2 (JS timer แบบ drift-corrected) และ Phase 3 (auto-guard)

---

## 2. Non-goals (Phase 1)

- ยัง **ไม่** ทำ cron auto-pause / auto-close
- ยัง **ไม่** เปลี่ยน People Monitor หรือหน้าจออื่น
- ยัง **ไม่** refactor JS timer แบบเต็มระบบ (แค่รองรับ DTO ใหม่)

---

## 3. Architecture Design

### 3.1 New Service: `BGERP\Service\TimeEngine\WorkSessionTimeEngine`

**File:** `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`

**Responsibilities:**

- เป็น “แหล่งความจริงเดียว” ของ logic เวลา session/token
- รับ row ของ `token_work_session` + `now()` แล้วคืน Timer DTO

**API design (เบื้องต้น):**

```php
namespace BGERP\Service\TimeEngine;

class WorkSessionTimeEngine
{
    public function __construct(\mysqli $tenantDb);

    /**
     * Calculate live work seconds for a given session row.
     *
     * @param array $sessionRow  // row จาก token_work_session
     * @param \DateTimeImmutable|null $now // ใช้สำหรับ test override, default=now()
     * @return array {
     *   work_seconds      int   // วินาทีรวม ณ ตอนนี้
     *   base_work_seconds int   // work_seconds ที่บันทึกไว้ใน DB (snapshot)
     *   live_tail_seconds int   // ส่วนเพิ่มตั้งแต่ resumed_at/start จนถึง $now
     *   status            string// active|paused|completed|unknown
     *   started_at        string|null // ISO8601
     *   resumed_at        string|null // ISO8601
     *   last_server_sync  string      // ISO8601 (เวลา now ใช้คำนวณ)
     * }
     */
    public function calculateTimer(array $sessionRow, \DateTimeImmutable $now = null): array;
}

Logic ภายใน (สอดคล้องกับของเดิม แต่เป็นมาตรฐาน):
	•	ถ้า status = 'active':
	•	base = (int)($session['work_seconds'] ?? 0)
	•	anchor = $session['resumed_at'] ?? $session['started_at']
	•	live_tail = max(0, now - anchor)
	•	work_seconds = base + live_tail
	•	ถ้า status IN ('paused', 'completed'):
	•	base = (int)($session['work_seconds'] ?? 0)
	•	live_tail = 0
	•	work_seconds = base
	•	ถ้าไม่เข้าเงื่อนไข → status = 'unknown', work_seconds = base

ห้ามเรียก SQL ภายในคลาสนี้ (รับ row จาก API caller อย่างเดียว)

⸻

3.2 Timer DTO for API responses

สร้าง DTO เบา ๆ (ไม่จำเป็นต้องเป็น class แยกก็ได้ แต่ควรใช้รูปแบบเดียวทุกที่):

$timerDto = [
    'work_seconds'      => (int),
    'base_work_seconds' => (int),
    'live_tail_seconds' => (int),
    'status'            => 'active|paused|completed|unknown',
    'started_at'        => '2025-11-18T10:27:00+07:00',
    'resumed_at'        => '2025-11-18T10:35:00+07:00',
    'last_server_sync'  => '2025-11-18T10:37:12+07:00',
];

ใน Phase 2 Frontend จะใช้ last_server_sync เพื่อแก้ drift
ตอนนี้ให้ใส่ไว้ก่อนเลยเพื่ออนาคต (ใช้ gmdate('c') หรือแปลง timezone ตาม config)

⸻

4. Backend Changes – Work Queue Integration

4.1 Remove inline SQL CASE for work_seconds_display

ใน handleGetWorkQueue() (ไฟล์ source/dag_token_api.php) ปัจจุบันมีใน SELECT:

CASE 
    WHEN s.status = 'active' THEN 
        COALESCE(s.work_seconds, 0) + TIMESTAMPDIFF(SECOND, COALESCE(s.resumed_at, s.started_at), NOW())
    WHEN s.status IN ('paused', 'completed') THEN 
        COALESCE(s.work_seconds, 0)
    ELSE 0
END as work_seconds_display,

ให้ลบ CASE นี้ออก แล้วแทนที่ด้วย:
	•	เลือก column ดิบเหล่านี้แทน:

s.work_seconds,
s.status as session_status,
s.started_at,
s.resumed_at,

(จริง ๆ มีอยู่แล้วใน SELECT, ตรวจให้แน่ใจว่ายังอยู่ครบ)

4.2 ใช้ WorkSessionTimeEngine หลังจาก fetch rows

ใน handleGetWorkQueue() หลังจาก:

$result = $stmt->get_result();
$tokens = $result->fetch_all(MYSQLI_ASSOC);

เพิ่ม:

use BGERP\Service\TimeEngine\WorkSessionTimeEngine;

$timeEngine = new WorkSessionTimeEngine($db->getTenantDb());
$now = new \DateTimeImmutable('now');

foreach ($tokens as &$token) {
    // มี session เฉพาะกรณี active/paused เท่านั้น
    if (!empty($token['id_session'])) {
        $sessionRow = [
            'status'       => $token['session_status'] ?? null,
            'work_seconds' => $token['work_seconds'] ?? null,
            'started_at'   => $token['started_at'] ?? null,
            'resumed_at'   => $token['resumed_at'] ?? null,
        ];
        $timer = $timeEngine->calculateTimer($sessionRow, $now);
    } else {
        $timer = [
            'work_seconds'      => 0,
            'base_work_seconds' => 0,
            'live_tail_seconds' => 0,
            'status'            => 'none',
            'started_at'        => null,
            'resumed_at'        => null,
            'last_server_sync'  => $now->format(DATE_ATOM),
        ];
    }

    // แนบเข้า tokenData (ตอน build $tokenData ด้านล่าง)
    $token['timer'] = $timer;
}
unset($token);

4.3 ส่ง timer DTO ไปใน JSON

ตอน build $tokenData ในส่วน grouped tokens (ท้าย ๆ ของ handleGetWorkQueue):

$tokenData = [
    // ... field เดิม ...
    'timer' => $token['timer'] ?? null,
];

อย่าลืม: เอา work_seconds_display เดิมออกจาก response เพื่อเลี่ยง duplicate source of truth

⸻

5. Frontend Considerations (Phase 1)

ไฟล์: assets/javascripts/pwa_scan/work_queue.js
	•	ตอน render card (list/kanban/mobile) เดิมใช้ token.work_seconds_display หรือ logicคล้าย ๆ นั้น
	•	ให้เปลี่ยนไปใช้:

const timer = token.timer || null;
const workSeconds = timer ? timer.work_seconds : 0;

	•	แปลงเป็น mm:ss / hh:mm:ss เหมือนเดิม
	•	data-attribute สำหรับ timer ควรใช้:

<span
  class="token-work-timer"
  data-work-seconds-base="{timer.base_work_seconds}"
  data-last-server-sync="{timer.last_server_sync}"
  data-status="{timer.status}"
>
  {formattedTime}
</span>

Phase 2 จะมาเปลี่ยน updateAllTimers() ให้ใช้ base + drift จาก last_server_sync
ตอนนี้ยังใช้ +1 ธรรมดาได้ แค่ให้เริ่มอ่านจากโครงสร้าง DTO ใหม่แทน field เดิม

⸻

6. Tests

6.1 Unit Tests for WorkSessionTimeEngine

File: tests/Unit/WorkSessionTimeEngineTest.php

เคสหลักที่ต้องมี:
	1.	active + ไม่มี resume → work_seconds = base + (now - started_at)
	2.	active + มี resume → work_seconds = base + (now - resumed_at)
	3.	paused → work_seconds = base (ไม่บวกเพิ่ม)
	4.	completed → work_seconds = base
	5.	datetime เพี้ยนเล็กน้อย → ไม่ throw error, live_tail >= 0 เสมอ

6.2 Integration Smoke Test – Work Queue

File: เพิ่มใน tests/Integration/HatthasilpaE2E_WorkQueueTimeEngineTest.php (หรือเพิ่มในไฟล์ที่มีอยู่แล้วถ้าเหมาะ)
	•	สร้าง token + session active เทียมใน DB
	•	เรียก get_work_queue
	•	ตรวจโครงสร้าง response:

$this->assertArrayHasKey('timer', $token);
$this->assertArrayHasKey('work_seconds', $token['timer']);
$this->assertEquals('active', $token['timer']['status']);


⸻

7. Guardrails
	•	ห้ามแก้ token_work_session schema ใน Task นี้ (Phase 1 ใช้ field เดิมทั้งหมด)
	•	ห้ามเปลี่ยน UI layout / HTML structure ของ work_queue
	•	ห้ามเพิ่ม column SQL หนัก ๆ เพิ่มเติมใน handleGetWorkQueue() นอกจากการลบ CASE เดิม
	•	ถ้า logic เวลาเปลี่ยน ต้องอัปเดต Unit test ให้ครบ

⸻

8. Future Tasks (Out of Scope but MUST be considered)

ให้ comment ไว้ในไฟล์ Service ว่าทางข้างหน้าจะมี:
	•	Phase 2: Drift-corrected JS timers (ใช้ last_server_sync)
	•	Phase 3: Auto-guard (auto-pause/close abandoned sessions)
	•	Phase 4: Multi-surface integration (People Monitor, trace_overview, analytics)

เพื่อตอกย้ำว่า Service นี้คือ “หัวใจ” Time Engine ของ Bellavier Group

---

ถัดจาก Task นี้ ผมแนะนำลำดับประมาณนี้:

- **Task 1** (อันนี้ที่เขียนไป) – Core Engine + Work Queue  
- **Task 2** – JS Timer Refactor (drift-corrected)  
- **Task 3** – Session Auto-Guard + Cron  
- **Task 4** – People Monitor integration (ใช้ Time Engine + realtime timer ต่อคน)