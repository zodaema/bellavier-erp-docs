🎯 เป้าหมาย Task 2.1 – Time Engine v2 UI Rollout

ชื่อ: Task 2.1 – Time Engine v2 Multi-Surface Rollout (UI Only)
เป้าหมายหลัก:
	1.	ทุกหน้า UI ที่แสดง “เวลาทำงานของ token / worker”
→ ต้องใช้ BGTimeEngine (drift-corrected) แทน setInterval เดิม
	2.	หน้าที่อยู่ใน scope รอบแรก:
	•	✅ Work Queue (ทำแล้ว – แค่ verify)
	•	🧑‍🏭 People / Manager Assignment (สำคัญสุด)
	•	👁 People Monitor / Operator Overview (ถ้ามี)
	•	🔍 Token Detail / Trace / Serial Detail (ถ้ามี timer)
	•	อื่นๆ ที่ใช้ class/selector เดิม เช่น .work-timer, .timer-display, data-work-seconds-*
	3.	ไม่แตะ backend logic / database / API ให้ “UI timer layer” เป็นแค่ consumer ของ Timer DTO หรือ seconds เดิม

⸻

🧩 Design หลัก ที่ทุกหน้าต้องตามให้เหมือน Work Queue

ใช้ pattern จาก work_queue_timer.js เป็น มาตรฐานกลาง:

1. DOM Contract (มาตรฐานสำหรับ Timer Element)

ทุก element ที่เป็น timer ควรใช้ pattern ใกล้เคียง:

<span
  class="work-timer work-timer-active"
  data-token-id="1234"
  data-status="active"           <!-- active|paused|completed -->
  data-work-seconds-sync="360"   <!-- seconds จาก server ณ last_server_sync -->
  data-last-server-sync="1731932400" <!-- optional: unix timestamp -->
>
    <span class="timer-display">00:06:00</span>
</span>

หลักการ:
	•	ใช้ class work-timer (หรือชื่อที่ใช้แล้วในระบบ) ให้ BGTimeEngine หาเจอง่าย
	•	ใช้ data-token-id เสมอ (แม้หน้า People จะไม่มี token row แบบเดียวกับ Work Queue ก็ให้ map id งาน / session → token-id)
	•	ใช้ data-status → active, paused, completed
	•	ใช้ data-work-seconds-sync แทน “นับเวลาบน client เองแบบ +1”

ถ้าหน้าไหนเคยใช้แค่ data-work-seconds-base หรือฝั่ง JS นับเอง ให้เปลี่ยนมาใช้ data-work-seconds-sync ตาม Time Engine v2

⸻

2. JS Contract – ใช้ BGTimeEngine เหมือน Work Queue

ทุกหน้าที่มี timer ต้อง ทำ 3 อย่างเหมือนกัน:
	1.	โหลด work_queue_timer.js ก่อน JS ของหน้านั้น
	•	เช่นใน page definition:

$page_detail['jquery'][] = domain::getDomain().'/assets/javascripts/pwa_scan/work_queue_timer.js?v='.time();
$page_detail['jquery'][] = domain::getDomain().'/assets/javascripts/people_assignment.js?v='.time();

(สำหรับ People Assignment ก็ใช้ pattern เดียวกัน เปลี่ยนชื่อไฟล์ JS ให้ตรง)

	2.	มี helper registerTimerElements($container) ฝั่ง JS หน้านั้น

function registerTimerElements($container) {
    if (!window.BGTimeEngine || !BGTimeEngine.registerTimerElement) {
        return; // safety
    }

    $container.find('.work-timer').each(function () {
        const el = this;
        BGTimeEngine.registerTimerElement(el);
    });
}


	3.	เรียก registerTimerElements() หลัง render / reload data
ตัวอย่างใน People Assignment:

function renderPeopleAssignmentList(data) {
    const $container = $('#people-assignment-list');
    $container.html(renderPeopleHtml(data));

    // หลังจาก inject HTML แล้ว
    registerTimerElements($container);
}



⸻

3. หน้า People / Manager Assignment – แนวทางเฉพาะ

เป้าหมาย: เวลาที่แสดงใต้แต่ละ “ช่าง / worker” ต้อง sync กับ Time Engine v2 เช่นเดียวกับ Work Queue

3.1 ตรวจสอบ Data จาก API
ใน JS หรือ PHP ที่ใช้ดึงข้อมูลหน้า People / Manager Assignment:
	•	หา payload ที่เกี่ยวกับ “งานที่ช่างกำลังทำ” หรือ “session time”:
	•	เช่น current_session.work_seconds
	•	หรือ token.work_seconds
	•	หรือ worker.current_work_seconds

หลักการ mapping:
	•	ให้ฝั่ง backend (ถ้าพร้อม) ส่ง Timer DTO แบบเดียวกับ Work Queue
(หรืออย่างน้อย work_seconds + timestamp server)
	•	ฝั่ง frontend แค่เอาค่านี้มาใส่ data-work-seconds-sync

3.2 ปรับ HTML Render ของแต่ละ Row
ตัวอย่างโครง (สมมุติ):

function renderPersonRow(person) {
    const timer = person.current_timer || {}; // { status, work_seconds, last_server_sync }

    return `
        <tr>
            <td>${person.name}</td>
            <td>${person.current_task_name || '-'}</td>
            <td>
                <span
                    class="work-timer ${timer.status === 'active' ? 'work-timer-active' : ''}"
                    data-token-id="${timer.token_id || ''}"
                    data-status="${timer.status || 'paused'}"
                    data-work-seconds-sync="${timer.work_seconds || 0}"
                    data-last-server-sync="${timer.last_server_sync || ''}"
                >
                    <span class="timer-display">
                        ${formatWorkSeconds(timer.work_seconds || 0)}
                    </span>
                </span>
            </td>
        </tr>
    `;
}

แล้วค่อย registerTimerElements($table) ทุกครั้งที่ render.

3.3 การ Refresh / Polling
ถ้าหน้า People ใช้การ:
	•	auto-refresh ทุก X วินาที หรือ
	•	ดึงข้อมูลใหม่ผ่าน AJAX บ่อยๆ

ให้ยึดหลัก:
	•	ทุกครั้งที่ refresh ทั้ง block →
	1.	clear HTML → 2) inject HTML ใหม่ → 3) registerTimerElements()
	•	ไม่ต้อง setInterval มานับเวลาเพิ่มเอง ให้ BGTimeEngine เป็นคน tick ให้

⸻

4. หน้าอื่นที่ควรเข้าข่าย (ให้ Agent หาเอง)

ให้ AI Agent:
	1.	ค้นหาใน repo:
	•	คำที่เกี่ยวกับ timer:
	•	work-timer
	•	timer-display
	•	work_seconds
	•	work-seconds
	•	formatWorkSeconds(
	•	data-work-seconds
	•	หรือ JS ที่ใช้ setInterval เพื่อ update timer ในหน้าอื่นที่ไม่ใช่ work queue
	2.	สำหรับทุกหน้า/ไฟล์ที่พบ:
	•	ยืนยันว่ามันแสดง “เวลาทำงาน” หรือ “เวลา session”
	•	ถ้าใช่ → แปลงไปใช้ pattern:
	•	DOM attributes มาตรฐาน
	•	ใช้ BGTimeEngine + registerTimerElements()
	•	ถ้ามี setInterval timer เดิม → deprecate แบบเดียวกับ updateAllTimers() ใน Work Queue

สำคัญ:
ห้ามไปเปลี่ยน business logic, แค่เปลี่ยนวิธี render/อัปเดต UI timer เท่านั้น

⸻


You are refactoring the Bellavier Group ERP "time engine" on the frontend.

Goal: Implement **Time Engine v2 drift-corrected timers** (BGTimeEngine from `work_queue_timer.js`) across all relevant UI surfaces, especially the People / Manager Assignment page, without changing any backend logic or database behavior.

### Constraints

- Do NOT change any business logic, DB schema, or API contracts.
- Do NOT change the Time Engine v2 core (`work_queue_timer.js`) implementation.
- Do NOT introduce new global timers with `setInterval` that re-implement timer logic.
- Only adjust:
  - DOM attributes used by timers
  - JS code that registers/updates timer elements
  - Page script includes order (to ensure BGTimeEngine is loaded first)
- All changes must be backward compatible: if BGTimeEngine fails to load, the page must still render without fatal errors.

---

## Step 1: Identify all timer surfaces

1. Search the repo for:
   - `.work-timer`
   - `.timer-display`
   - `work_seconds`
   - `data-work-seconds`
   - `formatWorkSeconds(`
   - `setInterval` blocks that update UI time in:
     - `assets/javascripts/**`
     - `views/**`
     - `page/**`

2. Build a short list in comments (no need to create extra files) of all pages/modules that show **live work/session time**, for example:
   - Work Queue (already migrated in Task 2)
   - People / Manager Assignment
   - People Monitor / Operator Overview
   - Token / Serial detail pages
   - Any other WIP / time-progress screen

We already know Work Queue is done. Focus especially on:
- People / Manager Assignment screen
- Any “People Monitor / Overview” pages

---

## Step 2: Standardize DOM attributes for timers

For each page that displays a timer:

1. Make the timer HTML follow this contract (or as close as practically possible):

```html
<span
  class="work-timer {{ timer.status === 'active' ? 'work-timer-active' : '' }}"
  data-token-id="{{ token_id or session_id }}"
  data-status="{{ 'active'|'paused'|'completed' }}"
  data-work-seconds-sync="{{ work_seconds_from_server }}"
  data-last-server-sync="{{ unix_timestamp_of_server_sync_if_available }}"
>
    <span class="timer-display">
        {{ formatted time using formatWorkSeconds() }}
    </span>
</span>

	2.	If the current implementation uses:
	•	data-work-seconds-base or just increments a JS variable → replace with data-work-seconds-sync.
	•	No data-token-id → derive a stable identifier (token id, session id, etc.) and set data-token-id.
	3.	Do NOT change the actual formatted display logic (e.g., formatWorkSeconds()); just change the attributes and registration.

⸻

Step 3: Ensure work_queue_timer.js is loaded on each relevant page

For each page that needs live timers:
	1.	Open the corresponding page/*.php file (e.g., page/work_queue.php, page/people_assignment.php, etc.).
	2.	Make sure it includes:

$page_detail['jquery'][] = domain::getDomain().'/assets/javascripts/pwa_scan/work_queue_timer.js?v='.time();

and that this line appears before the page-specific JS file, e.g.:

$page_detail['jquery'][] = domain::getDomain().'/assets/javascripts/pwa_scan/work_queue_timer.js?v='.time();
$page_detail['jquery'][] = domain::getDomain().'/assets/javascripts/people_assignment.js?v='.time();

Do NOT change the existing page JS includes, only prepend the timer engine where needed.

⸻

Step 4: Add registerTimerElements($container) to each page JS

For each JS file that renders dynamic content with timers (e.g., people_assignment.js, etc.):
	1.	Add a helper function:

function registerTimerElements($container) {
    if (!window.BGTimeEngine || typeof BGTimeEngine.registerTimerElement !== 'function') {
        return; // safety fallback
    }

    $container.find('.work-timer').each(function () {
        BGTimeEngine.registerTimerElement(this);
    });
}

	2.	After every render/refresh of content that includes timers, call:

registerTimerElements($container);

For example in the People / Manager Assignment page:

function renderPeopleAssignmentList(data) {
    const $container = $('#people-assignment-list');
    $container.html(renderPeopleHtml(data));

    registerTimerElements($container);
}

	3.	If there are any old setInterval blocks that update timers manually on that page:
	•	Remove the manual timer update.
	•	Keep any function definitions for backward compatibility, but make them no-ops with a comment like in updateAllTimers() of work_queue.js.

⸻

Step 5: Special focus – People / Manager Assignment page
	1.	Locate the JS and PHP responsible for rendering the People / Manager Assignment UI:
	•	Likely assets/javascripts/.../people_assignment.js (or similar)
	•	And a page/*.php file for that screen
	2.	Ensure each person row that shows current working time has:
	•	A work-timer element as described in Step 2
	•	Attributes:
	•	data-token-id → current work token or session
	•	data-status → active / paused / completed
	•	data-work-seconds-sync → seconds from server snapshot
	3.	Hook the timer registration:

function renderPersonRow(person) {
    const timer = person.current_timer || {};
    // ...
}

function renderPeopleAssignmentList(data) {
    const $container = $('#people-assignment-list');
    $container.html(html);
    registerTimerElements($container);
}

	4.	Do not introduce new backend fields. Reuse whatever work_seconds or time-related fields are already available in the API. If necessary, add minimal mapping in JS to convert from existing structure to the timer DOM contract.

⸻

Step 6: Verification
	1.	Run basic manual checks:
	•	Open Work Queue → timers still working (regression check).
	•	Open People / Manager Assignment:
	•	Active sessions tick up correctly.
	•	Paused/completed sessions display static time.
	•	Switch tabs, minimize browser, or sleep → on resume, timers should catch up without drift.
	2.	Run existing tests related to Time Engine / Work Queue, if any, to ensure no regressions:
	•	tests/Integration/SystemWide/EndpointSmokeSystemWideTest.php (if relevant)
	•	Any Time Engine specific tests.

If any existing tests fail because they expect old timer behavior, update the tests to align with the new drift-corrected model—but do NOT change core business or database logic.

⸻

Deliverables:
	•	Updated page scripts for all surfaces that display live work/session time, especially:
	•	People / Manager Assignment
	•	Any other pages discovered in Step 1
	•	Updated page PHP includes to load work_queue_timer.js where needed.
	•	No changes to backend Time Engine core or WorkSessionTimeEngine.
	•	Short summary of which files were touched and which pages are now using BGTimeEngine.
