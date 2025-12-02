Task 2 – Time Engine v2 (Phase 2) – Drift-Corrected JS Timer for Work Queue

สถานะ: ✅ COMPLETED
Phase: Phase 2 – JS Timer Refactor (Frontend)
เป้าหมาย: ทำให้ Timer บน Work Queue UI เป็น drift-corrected, คำนวณจาก Server Snapshot + Time Engine DTO ไม่ใช่แค่ setInterval +1 แบบเดิม

⸻

🎯 Objective
	1.	เปลี่ยนกลไกนับเวลาใน work_queue.js ให้ใช้ค่าเวลาแบบ อ้างอิงจาก Server (Timer DTO จาก Time Engine v2)
	2.	ทำให้ Timer:
	•	ไม่เพี้ยนเมื่อ:
	•	แท็บอยู่เบื้องหลัง (background)
	•	สลับหน้า
	•	CPU/Browser lag
	•	ยังนับเวลาต่อถูกต้องแม่นยำ
	3.	ไม่เปลี่ยนโครง UI / HTML Structure (แค่เพิ่ม data-attributes / logic JS)

⸻

🧩 Context ปัจจุบัน (ห้ามลืม)

1. Backend Time Engine (ทำแล้วใน Task 1)
	•	Service: source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php
	•	Method: calculateTimer(array $sessionRow, ?DateTimeImmutable $now = null): array
	•	DTO:

[
    'work_seconds'      => int,
    'base_work_seconds' => int,
    'live_tail_seconds' => int,
    'status'            => string, // active|paused|completed|none|unknown
    'started_at'        => string, // ISO8601
    'resumed_at'        => string, // ISO8601
    'last_server_sync'  => string, // ISO8601
]

2. Work Queue API (ทำแล้ว)
	•	source/dag_token_api.php → handleGetWorkQueue()
– ส่ง timer DTO กลับไปทุก token:

$token['timer'] = $timer;

3. Frontend ปัจจุบัน (หลัง Task 1)

ไฟล์: assets/javascripts/pwa_scan/work_queue.js
	•	ใช้ token.timer.work_seconds แทน token.session.work_seconds
	•	มี helper:

function formatWorkSeconds(workSeconds) { ... }

	•	ตอน render HTML ของ timer (ใน views ต่าง ๆ) มีการสร้าง <span> ประมาณนี้ (จาก Task 1 spec):

<span class="work-timer-active" 
      data-started="${session.started_at}"
      data-pause-min="${totalPauseMinutes}"
      data-work-seconds-base="${timer.base_work_seconds || 0}"
      data-last-server-sync="${timer.last_server_sync || ''}"
      data-status="${timer.status || 'active'}">
  ${formatWorkSeconds(timer.work_seconds || 0)}
</span>

ตอนนี้ timer ยังนับแบบบ้าน ๆ (สะสมเอง) → หน้าที่ของ Task 2 คือ ผูก logic เวลาเข้ากับ last_server_sync + work_seconds

⸻

🗂 Files to Touch
	1.	assets/javascripts/pwa_scan/work_queue.js
	•	main work queue logic
	•	render functions (Kanban/List/Mobile)
	2.	(ถ้าจำเป็น / แนะนำ) ไฟล์ใหม่:
	•	assets/javascripts/pwa_scan/work_queue_timer.js
แยก concerns เรื่อง timer ออกจาก view logic แต่ต้อง ไม่เปลี่ยน behavior ภายนอก

❗ ห้ามแตะ PHP backend ใน Task นี้ ยกเว้นเพิ่ม field หรือ data attribute ที่สอดคล้องกับ DTO เดิม (ไม่เปลี่ยน business logic)

⸻

🔁 Desired Behaviour – Drift-Corrected Timer

แนวคิดหลัก
	1.	Server ส่ง snapshot:
	•	timer.work_seconds ณ เวลา timer.last_server_sync
	•	timer.status
	2.	Client:
	•	เก็บ snapshot นี้ไว้ที่ <span> ผ่าน data-*
	•	ทุก 1 วินาที (หรือน้อยกว่า) คำนวณใหม่จาก:
	•	work_seconds_at_sync
	•	last_server_sync
	•	status
	•	render วินาทีล่าสุดลง <span>

สูตรที่ต้องการ

ให้เพิ่ม data attribute ใหม่:

data-work-seconds-sync="${timer.work_seconds || 0}"
data-last-server-sync="${timer.last_server_sync || ''}"

โดยใน JS:

// pseudo
const syncSeconds = Number(el.dataset.workSecondsSync || 0);
const lastSyncIso = el.dataset.lastServerSync || null;
const status = el.dataset.status || 'unknown';

let displaySeconds = syncSeconds;

if (status === 'active' && lastSyncIso) {
    const lastSyncMs = Date.parse(lastSyncIso);
    const nowMs = Date.now();
    const diffSeconds = Math.max(0, Math.floor((nowMs - lastSyncMs) / 1000));
    displaySeconds = syncSeconds + diffSeconds;
}
// ถ้า paused/completed → ใช้ syncSeconds ตรง ๆ


⸻

🛠 Step-by-Step Implementation Plan

Step 1 – ปรับ HTML Data Attributes จาก Work Queue Renderer

ใน work_queue.js, ทุกที่ที่สร้าง HTML ของ timer (น่าจะมี 3 จุด):
	•	renderKanbanToken()
	•	renderListView()
	•	renderMobileJobCard() (ชื่ออาจต่างเล็กน้อย แต่คอนเซ็ปต์ประมาณนี้)

ให้ทำ 2 อย่าง:
	1.	เพิ่ม attribute:
	•	data-work-seconds-sync="${timer.work_seconds || 0}"
	2.	ตรวจสอบ/คงไว้ attribute เดิม:
	•	data-work-seconds-base="${timer.base_work_seconds || 0}" (ถ้ายังใช้)
	•	data-last-server-sync="${timer.last_server_sync || ''}"
	•	data-status="${timer.status || 'active'}"

ถ้าไม่จำเป็น ห้ามลบ attribute เดิม (เพื่อความเข้ากันได้ย้อนหลัง)

⸻

Step 2 – สร้าง JS Timer Engine ฝั่ง Frontend

แนะนำให้สร้างในไฟล์ใหม่:

▶ assets/javascripts/pwa_scan/work_queue_timer.js

และผูกใช้งานจาก work_queue.js ด้วย global object

2.1 สร้าง Registry

window.BGTimeEngine = window.BGTimeEngine || {};

(function(NS) {
    const TICK_INTERVAL_MS = 1000;
    let timerHandle = null;
    const trackedSpans = new Set();

    NS.registerTimerElement = function(spanEl) {
        if (!spanEl || !spanEl.dataset) return;
        trackedSpans.add(spanEl);
        ensureTicking();
    };

    NS.unregisterTimerElement = function(spanEl) {
        trackedSpans.delete(spanEl);
        if (trackedSpans.size === 0) {
            stopTicking();
        }
    };

    function ensureTicking() {
        if (timerHandle !== null) return;
        timerHandle = setInterval(tickAll, TICK_INTERVAL_MS);
    }

    function stopTicking() {
        if (timerHandle !== null) {
            clearInterval(timerHandle);
            timerHandle = null;
        }
    }

    function tickAll() {
        const nowMs = Date.now();
        trackedSpans.forEach(span => updateSpanTimer(span, nowMs));
    }

    function updateSpanTimer(span, nowMs) {
        const status = span.dataset.status || 'unknown';
        const syncSeconds = Number(span.dataset.workSecondsSync || 0);
        const lastSyncIso = span.dataset.lastServerSync || '';

        let displaySeconds = syncSeconds;

        if (status === 'active' && lastSyncIso) {
            const lastSyncMs = Date.parse(lastSyncIso);
            if (!Number.isNaN(lastSyncMs)) {
                const diffSeconds = Math.max(0, Math.floor((nowMs - lastSyncMs) / 1000));
                displaySeconds = syncSeconds + diffSeconds;
            }
        }

        // reuse existing formatter if accessible globally
        if (typeof window.formatWorkSeconds === 'function') {
            span.textContent = window.formatWorkSeconds(displaySeconds);
        } else {
            span.textContent = displaySeconds.toString();
        }
    }

    NS.updateTimerFromPayload = function(spanEl, timerDto) {
        if (!spanEl || !timerDto) return;
        // keep dataset in sync with latest snapshot
        spanEl.dataset.workSecondsSync = timerDto.work_seconds || 0;
        spanEl.dataset.lastServerSync = timerDto.last_server_sync || '';
        spanEl.dataset.status = timerDto.status || 'unknown';
        // update immediately
        updateSpanTimer(spanEl, Date.now());
    };

})(window.BGTimeEngine);

หมายเหตุ:
	•	ถ้าไม่อยากสร้างไฟล์ใหม่ สามารถวาง block นี้ต่อท้าย work_queue.js ได้เลย แต่ต้องทำให้ชื่อฟังก์ชันไม่ชนกับของเดิม

⸻

Step 3 – ผูก Register Timer หลัง Render Token

ใน work_queue.js เมื่อสร้าง <span class="work-timer-active"> เสร็จ และ inject เข้า DOM แล้ว:
	1.	หา element:

const timerSpan = container.querySelector('.work-timer-active[data-token-id="' + token.id_token + '"]');


	2.	เรียก:

if (window.BGTimeEngine && window.BGTimeEngine.registerTimerElement && timerSpan) {
    BGTimeEngine.registerTimerElement(timerSpan);
    BGTimeEngine.updateTimerFromPayload(timerSpan, token.timer || null);
}



ถ้าตัว render ใช้ template string + innerHTML = ... ให้จัดโครงสร้างให้หา <span> ได้ง่าย (เช่นเพิ่ม data-token-id)

⸻

Step 4 – Handle State Changes (Pause / Resume / Complete)

เมื่อมี action ที่กระทบเวลา เช่น:
	•	Operator กด Start / Resume
	•	Operator กด Pause
	•	Operator กด Complete / Close

หลังจากเรียก API แล้ว งานฝั่ง JS ที่ทำอยู่แล้วมักจะ:
	•	refetch work queue
หรือ
	•	update token บางตัวใน UI

ให้เพิ่ม logic:
	1.	อ่าน timer ตัวใหม่จาก response (ถ้ามี)
	2.	หา timer <span> ของ token นั้น
	3.	เรียก:

BGTimeEngine.updateTimerFromPayload(spanEl, token.timer);

และ ถ้า status เปลี่ยนเป็น paused / completed ก็ยังอยู่ใน registry ได้ ไม่ผิด (เพราะ logic จะไม่เพิ่มเวลาแล้ว)
ถ้าอยาก clean สุด ๆ อาจเรียก unregisterTimerElement() เมื่อ status ไม่ใช่ active ก็ได้ แต่ไม่จำเป็น

⸻

Step 5 – Backward Compatibility & Safety Rails
	1.	ห้ามเปลี่ยน:
	•	ชื่อ field JSON จาก backend (timer.*)
	•	โครงสร้าง DOM รอบ ๆ timer (class, layout, HTML structure)
	2.	อนุญาตให้เปลี่ยน / เพิ่ม:
	•	data-attributes (data-work-seconds-sync, ฯลฯ)
	•	JS helper เพิ่มใหม่
	•	internal registry
	3.	ถ้าไม่มี timer (กรณี token ไม่มี session):
	•	timerSpan สามารถแสดง 00:00 หรือ - ตามของเดิม
	•	ห้ามโยน error

⸻

✅ Acceptance Criteria (สำหรับ Dev + QA)
	1.	Exactness Test (Manual)
	•	เปิด Work Queue
	•	เริ่มงาน 1 ชิ้น (Active)
	•	จับเวลาในมือถือจริง ๆ
	•	หลังผ่านไป 2–3 นาที เวลาใน UI ต้องคลาดเคลื่อนไม่เกิน ±2 วินาที
	2.	Background Tab Test
	•	เปิด Work Queue
	•	เริ่มงาน
	•	ย้าย Tab ไปหน้าอื่น / Minimize Browser ไว้ 2–3 นาที
	•	กลับมา → เวลาใน UI ต้อง “กระโดด” ไปข้างหน้าอย่างถูกต้อง ไม่หยุดนิ่งคาไว้
	3.	Pause/Resume Test
	•	Start → ปล่อย 30s → Pause
	•	รออีก 30s (ไม่ทำอะไร)
	•	Resume → เวลาใน UI ต้องยังต่อจากเดิม (ไม่รวมเวลาตอน pause)
	4.	Multi-token Test
	•	มีอย่างน้อย 3 tokens active
	•	ตรวจ timer ทุกอันยังเดินตามสูตรแบบเดียวกัน ไม่มี token ไหนหยุดหรือเพี้ยน
	5.	No JS Errors
	•	เปิด DevTools → Console
	•	ไม่มี error จาก BGTimeEngine หรือ work_queue.js

⸻

🧠 Extra (สำหรับ AI Agent)

ก่อนแก้ไขโค้ด ให้ AI Agent:
	1.	อ่าน:
	•	docs/time-engine/time-engine-bellavier-erp-implementation.md
	•	docs/time-engine/tasks/task1_TIME_ENGINE_V2_CORE_ENGINE_COMPLETE.md
	•	docs/developer/02-quick-start/GLOBAL_HELPERS.md
	•	docs/developer/02-quick-start/AI_QUICK_START.md
	2.	เมื่อจบแล้ว ให้:
	•	รัน php -l สำหรับไฟล์ JS ที่แก้ (ข้ามได้ เพราะเป็น JS)
	•	รัน manual test ตาม Acceptance Criteria (ให้ list steps / expected results)

⸻