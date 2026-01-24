ก่อนจะทำ task24.6 ให้จัดการกับไฟล์จาก task24.5.md ที่ยังไม่เรียบร้อยก่อน

จากนั้น task24.6 จะเริ่มต้นจากหัวข้อ # Task 24.6 กลางๆไฟล์

⸻

1) แก้ไฟล์ source/job_ticket.php

1.1 อ่าน/เขียน assigned_operator_id ใน list/get/create/update
	1.	ใน action ที่ load ticket list (list)
	•	ให้ query select field assigned_operator_id จาก job_ticket เสมอ และใส่ใน array response
	•	ถ้าตอนนี้ select * อยู่แล้ว แค่ ensure ว่า key ใน $row หรือ $ticket ของ JSON response มี assigned_operator_id เสมอ
	2.	ใน action get (ดึงรายละเอียด ticket เดี่ยว):
	•	เพิ่ม assigned_operator_id ลงใน data ที่ส่งกลับ
ตัวอย่าง (แค่แนวทาง):

$ticket = [
    'id' => $row['id'],
    'status' => $row['status'],
    // ...
    'assigned_operator_id' => $row['assigned_operator_id'], // Task 24.6 — Assigned Operator
];


	3.	ใน action create:
	•	อ่าน input จาก $_POST หรือ JSON body (ดู pattern เดิมที่ใช้กับ field อื่น) เช่น:

$assignedOperatorId = isset($input['assigned_operator_id']) && $input['assigned_operator_id'] !== ''
    ? (int)$input['assigned_operator_id']
    : null;


	•	Validate แบบ basic (ต้องเป็น int หรือ null)
	•	ตอน INSERT ลง job_ticket ให้เพิ่ม column assigned_operator_id ด้วย

	4.	ใน action update:
	•	เช่นเดียวกับ create, อ่านค่า assigned_operator_id จาก input ถ้ามี
	•	ดึงค่าเดิมจาก DB ก่อน update (เพื่อใช้ทำ log operator_changed)
	•	UPDATE assigned_operator_id ลง job_ticket
	•	ถ้า operator มีการเปลี่ยน (จาก A → B ที่ต่างกัน) ให้เรียก helper logJobTicketEvent() (ถ้ามี) พร้อม payload:

$payload = [
    'from' => $oldAssignedOperatorId,
    'to'   => $newAssignedOperatorId,
];
$this->logJobTicketEvent($ticketId, 'operator_changed', $payload); // Task 24.6 — Assigned Operator


	•	อย่าโยน error ถ้าไม่มี operator เดิม (null) หรือ operator ใหม่ก็ยัง null → แค่ไม่ต้อง log

ถ้า code ปัจจุบันใช้ style อื่น (เช่น array_merge, $db->insert, $db->update) ให้ integrate ให้เข้ากับ style เดิม ห้ามเขียนทับ logic เดิมทั้งก้อน

⸻

1.2 Rule: ห้าม start ถ้า assigned_operator_id เป็น null

เรามี state machine แล้วใน Task 24.5 (validateStateTransition() + json_error_state_machine())
ให้คุณเสริม rule ใน transition start เท่านั้น ตามนี้:
	•	ก่อนเรียก logic เดิมของ start (ที่ไป trigger token lifecycle):
	•	โหลด ticket ปัจจุบัน (ควรมีอยู่แล้วในโค้ด ส่วน validateStateTransition น่าจะใช้)
	•	ถ้า assigned_operator_id เป็น null → return error JSON ทันที:

if ($action === 'start') {
    $ticket = $this->getJobTicketById($ticketId); // หรือวิธีที่ระบบใช้จริง
    if (empty($ticket['assigned_operator_id'])) {
        return $this->json_error_state_machine([
            'ticket_id'  => $ticketId,
            'status'     => $ticket['status'],
            'error_code' => 'ERR_OPERATOR_REQUIRED', // Task 24.6 — Assigned Operator
            'error'      => 'Cannot start this job because no operator is assigned.',
        ]);
    }
}

❗ อย่าไปบังคับ pause/resume/complete ให้ต้องมี operator ใน Phase นี้
Rule นี้ใช้เฉพาะ start จากหน้า Admin UI เท่านั้น

⸻

2) แก้ไฟล์ assets/javascripts/hatthasilpa/job_ticket.js

เป้าหมาย: ให้ offcanvas มี select สำหรับ operator + binding กับ API + handle error ERR_OPERATOR_REQUIRED

2.1 เพิ่ม operator select ใน DOM (ถ้า render ผ่าน JS) หรือเตรียม hook
	•	ตรวจดูว่าปัจจุบัน offcanvas form สร้างด้วย HTML ใน views/job_ticket.php หรือ generate fragment ผ่าน JS
	•	ถ้าสร้างใน view เป็นหลัก → ทำข้อ 3 ก่อน (ใน views/job_ticket.php) แล้ว JS ใช้ #jt-operator
	•	ถ้า JS สร้าง dynamic form → เพิ่ม block HTML ลงใน template ตรงนั้น

สมมติใช้ selector:

const $operatorSelect = $('#jt-operator'); // Task 24.6 — Assigned Operator

2.2 โหลด operator list

ให้เพิ่ม function แบบง่าย ๆ:

// Task 24.6 — Assigned Operator
function loadOperatorOptions() {
  const $select = $('#jt-operator');
  if (!$select.length) return;

  // ถ้ามี endpoint จริงอยู่แล้ว ให้ใช้ endpoint นั้นแทน URL ด้านล่าง
  return $.getJSON('people.php', { action: 'list_operators' })
    .done((resp) => {
      // สมมติ resp = { ok: true, data: [{id, name}, ...] }
      if (!resp || !resp.ok || !Array.isArray(resp.data)) return;

      $select.empty();
      $select.append('<option value="">— ไม่ระบุ —</option>');

      resp.data.forEach((op) => {
        const option = $('<option>')
          .val(op.id)
          .text(op.name || ('ID ' + op.id));
        $select.append(option);
      });
    })
    .fail(() => {
      // ถ้า fail ก็ไม่ต้อง throw error ปล่อยให้ operator เป็น optional ไปก่อน
      // อาจจะใส่ console.warn เบาๆ
      console.warn('Failed to load operator list for Job Tickets');
    });
}

ถ้า ยังไม่มี endpoint people/operator จริง ให้คุณเขียน TODO comment ชัดเจน และอาจใช้ dummy data ชั่วคราวแทน (แต่ในระบบจริงแนะนำให้เชื่อมกับ People Phase ในอนาคต)

จากนั้นให้เรียก loadOperatorOptions() ในตอน init offcanvas/detail เช่น:

function initJobTicketDetailUI() {
  loadOperatorOptions();
  // ฟังก์ชัน init อื่นๆ
}

หรือแทรกใน loadTicketDetail() ก่อน set ค่า

⸻

2.3 Binding operator ↔ ticket detail

ใน loadTicketDetail():
	•	หลังจากดึงข้อมูล ticket (ผ่าน AJAX job_ticket.php?action=get) และ render detail เสร็จแล้ว:

// Task 24.6 — Assigned Operator
if (data.assigned_operator_id) {
  $('#jt-operator').val(String(data.assigned_operator_id));
} else {
  $('#jt-operator').val('');
}

ใน function ที่ใช้เก็บ payload สำหรับ create / update (เช่น gatherTicketPayload() หรือ saveTicket()):

// Task 24.6 — Assigned Operator
payload.assigned_operator_id = ($('#jt-operator').val() || '').trim() || null;

ให้ส่ง field นี้ไป backend เสมอ (แม้จะเป็น null)

⸻

2.4 UI Rule: Start button ต้องผูกกับ operator

ใน renderLifecycleButtons(ticket):
	•	ตอนนี้มี logic เช็ค status แล้ว render ปุ่ม Start/Pause/Resume/Complete

เพิ่มเงื่อนไข:

// Task 24.6 — Assigned Operator
const hasOperator = !!ticket.assigned_operator_id;

if (ticket.status === 'planned') {
  if (!hasOperator) {
    // 1) แบบ disable ปุ่ม
    buttons.push(`
      <button type="button" class="btn btn-sm btn-secondary" disabled
        title="${escapeHtml('กรุณาเลือกช่างผู้รับผิดชอบก่อนเริ่มงาน')}">
        Start
      </button>
    `);

    // หรือ 2) ไม่ renderปุ่มเลย ก็ได้ (เลือกแบบหนึ่งให้ชัด แล้วใส่ comment)
  } else {
    // ปุ่ม Start ปกติ
    buttons.push(`
      <button type="button" class="btn btn-sm btn-primary js-job-start">
        Start
      </button>
    `);
  }
}

ให้เลือกแบบ disable พร้อม tooltip จะเข้าใจง่ายกว่า “ปุ่มหายไป”

2.5 แสดง error จาก backend: ERR_OPERATOR_REQUIRED

ใน callLifecycleTransition(action, ticketId) ตอนนี้รองรับ error_code จาก backend แล้ว (Task 24.5)

เพิ่ม case:

// Task 24.6 — Assigned Operator
if (resp && resp.error_code === 'ERR_OPERATOR_REQUIRED') {
  showJobTicketWarning(resp.error || 'ไม่สามารถเริ่มงานได้ เนื่องจากยังไม่ได้เลือก Assigned Operator');
  $('#jt-operator').focus();
  return;
}

showJobTicketWarning() คือฟังก์ชันที่ใช้แสดง warning banner ใน offcanvas ถ้าในโค้ดชื่อไม่ตรง ให้ใช้ชื่อที่มีอยู่จริง แล้วใส่ comment ว่าใช้กับ Task 24.5 + 24.6

⸻

3) แก้ไฟล์ views/job_ticket.php

3.1 เพิ่มฟิลด์ “ช่างผู้รับผิดชอบ (Assigned Operator)” ใน Offcanvas

หา offcanvas ที่แสดงรายละเอียด Job Ticket (ด้านขวา) ส่วนที่มีฟิลด์ต่าง ๆ เช่น Product, Quantity, Routing, ฯลฯ

เพิ่ม block:

<!-- Task 24.6 — Assigned Operator -->
<div class="mb-3">
  <label for="jt-operator" class="form-label">
    ช่างผู้รับผิดชอบ (Assigned Operator)
  </label>
  <select id="jt-operator" class="form-select">
    <option value="">— ไม่ระบุ —</option>
    <!-- options will be loaded by JS -->
  </select>
</div>

จัดตำแหน่งให้สมเหตุสมผล (เช่น อยู่ใกล้ Product / Quantity / Routing)

3.2 (Optional) เพิ่ม column Operator ในตารางหลัก

ถ้า layout ยังไม่แน่นเกินไป:
	•	เพิ่ม column header: ช่าง หรือ Operator
	•	ในแต่ละ row แสดงชื่อย่อ / ชื่อ operator

เช่น:

<th>Operator</th>
...
<td><?= htmlspecialchars($row['operator_name'] ?? '') ?></td>

ถ้าตอนนี้ backend ยังไม่ส่ง operator_name มา ให้ข้ามคอลัมน์นี้ไปก่อนได้ (optional)
แต่ให้เขียน note ใน task24_6_results.md ว่า column Operator ใน table เป็น optional

⸻

4) Acceptance / Self-check ก่อนส่งงาน

ให้คุณ (Agent) ตรวจเองก่อนว่า:
	•	สร้าง Job Ticket ใหม่ (Classic) → สามารถบันทึก assigned_operator_id ได้ (ดูจาก network / DB)
	•	ถ้า assigned_operator_id = null → กด Start จากหน้า Job Ticket → ได้ error_code = ERR_OPERATOR_REQUIRED + warning แสดงใน UI
	•	ถ้าเลือก operator แล้ว → กด Start / Pause / Resume / Complete ได้ตามปกติ
	•	Hatthasilpa flow ยังใช้งานได้เหมือนเดิม
	•	ไม่แตะ PWA/migration

⸻

# Task 24.6 — Job Ticket Assigned Operator (Classic Line)

## Objective
ทำให้ **Job Ticket ของ Classic Line ทุกใบมี “ผู้รับผิดชอบหลัก” (Assigned Operator)** อย่างชัดเจน และบังคับให้การเปลี่ยนสถานะ Start / Pause / Resume / Complete ต้องอยู่ภายใต้กติกาเรื่อง operator นี้เท่านั้น

> แนวคิดหลัก: ในโลกจริง 1 Job Ticket จะมี “เจ้าของงานหลัก” ไม่ใช่ทุกคนในโรงงานกดเล่นได้ตามใจ — ระบบต้องสะท้อนสิ่งนี้ให้ได้ และใช้เป็นฐานข้อมูลสำหรับวัดผลงานช่างในอนาคต (แต่เฟสนี้ยังไม่ต้องทำ dashboard performance)

---

## 1. Scope

### 1.1 สิ่งที่ครอบคลุม
- เพิ่ม field / ความสามารถ Assigned Operator ให้กับ Job Ticket (Classic Line)
- ปรับ API `job_ticket.php` ให้รองรับ operator assignment / change
- ปรับ UI/JS หน้า `job_ticket.php` ให้สามารถเลือก / เปลี่ยน operator ได้
- ผูกกติกา state machine (Start/Pause/Resume/Complete) บางส่วนกับ operator (ในระดับที่เหมาะสมสำหรับ Phase นี้)

### 1.2 สิ่งที่ไม่แตะใน Task 24.6
- ไม่แตะ PWA / Scan Terminal (Phase PWA จะมาผูก operator กับการ scan อีกที)
- ไม่ทำ Performance Dashboard / Ranking ช่าง
- ไม่เปลี่ยน schema people / operator master (ใช้ที่มีอยู่แล้ว เช่น `operator` / `people` table เดิม)
- ไม่เพิ่ม permission ซับซ้อน (เช่น ห้ามคนอื่นกดยกเลิก ถ้าไม่ใช่เจ้าของ) — เฟสนี้ทำแค่ฐานข้อมูล + UX เบื้องต้นก่อน

---

## 2. Business Rules

1. Job Ticket (Classic Line) ควรมี **assigned_operator_id** ได้ 0 หรือ 1 คน
   - `nullable` = ได้ (สำหรับกรณี assign ทีหลัง / auto assign จาก PWA ในอนาคต)
   - แต่สำหรับ `planned` → `in_progress` ที่กดจากหน้า Admin UI **จะบังคับให้ต้องเลือก operator ก่อน**

2. การเปลี่ยนสถานะจากหน้า `job_ticket.php` (Admin UI) ใน Phase นี้ **ยังไม่ต้องบังคับว่า user login = operator**
   - คือ ใครในทีม Admin ก็สามารถเปลี่ยน operator / start / pause แทนช่างได้ (ในโรงงานจริงมักมีหัวหน้าสายคอย control)
   - เพียงแต่ระบบต้องจำให้ได้ว่า “งานนี้ถือว่าเป็นชื่อใคร”

3. การเปลี่ยน operator หลังเริ่มงานแล้ว (status = `in_progress` / `paused`):
   - อนุญาตให้เปลี่ยนได้ ใน Phase นี้ (เปรียบเหมือนเปลี่ยนเจ้าของงานกลางทาง)
   - แต่ควรมี log event ระบุว่า operator เปลี่ยนจาก A → B (ถ้ามี job_ticket_event อยู่แล้ว ให้ใช้ event เดิม)

4. ถ้า `assigned_operator_id` เป็น null:
   - อนุญาตให้สร้าง Job Ticket ได้ (status = draft / planned)
   - แต่อย่า allow transition `start` จากหน้าปิดงาน (Admin) จนกว่าจะมี operator ถูกเลือก

---

## 3. Database / Model

> หมายเหตุ: ถ้า schema `job_ticket` มี field `assigned_operator_id` อยู่แล้ว → ข้ามการเปลี่ยน schema และใช้ field เดิมทันที

### 3.1 ตรวจสอบ Schema
- ตรวจสอบตาราง `job_ticket` ว่ามี field ที่เหมาะสมหรือยัง เช่น:
  - `assigned_operator_id` (INT, nullable)
- ถ้ามีอยู่แล้ว: ใช้ field นี้ ไม่ต้องสร้าง migration ใหม่
- ถ้ายังไม่มี: **ให้เขียนบันทึกไว้ใน Task 24.6 results ว่า “ต้องทำ migration แยกต่างหากใน Phase Schema”** แต่ใน task นี้ให้ assume ว่ามี field แล้ว และเขียน logic รองรับไปก่อน (เพื่อไม่ให้ task frontend/backend ช้า)

> สรุป: Task นี้ไม่เขียน migration แต่เตรียม logic + UI ให้สอดคล้องกับ field `assigned_operator_id` ที่จะมีแน่นอนในอนาคตอันใกล้

---

## 4. Backend Changes — `source/job_ticket.php`

### 4.1 เพิ่มการอ่าน/เขียน assigned_operator_id

- ใน action ที่คืนข้อมูล ticket (เช่น `get`, `list`)
  - ใส่ค่า `assigned_operator_id`
  - ถ้า join กับ people/operator table เพื่อดึงชื่อแสดงผลได้ (เช่น `operator_name`) ก็ทำได้ แต่ไม่บังคับใน task นี้

- ใน action ที่สร้าง/แก้ไข ticket (`create`, `update`):
  - อ่านค่า `assigned_operator_id` จาก input (POST/JSON)
  - Validate แบบ basic: ต้องเป็น integer หรือ null
  - Save ลงตาราง `job_ticket`

### 4.2 Rule: ห้าม start ถ้ายังไม่มี operator

ใน transition `start` (ที่ทำงานใน `job_ticket.php`):

- ดึง ticket ปัจจุบัน
- ถ้า `assigned_operator_id` เป็น null:
  - return error:

```json
{
  "ok": false,
  "error_code": "ERR_OPERATOR_REQUIRED",
  "error": "Cannot start this job because no operator is assigned.",
  "ticket_id": 1234,
  "status": "planned"
}
```

- ถ้าไม่ null → ดำเนินการต่อไปตาม state machine ปกติ

> อย่าไปบังคับ pause/resume/complete ใน Phase นี้ (อนาคตค่อย tighten rule ถ้าจำเป็น)

### 4.3 Logging (Optional แต่ควรมี)

ถ้า system เดิมมี `logJobTicketEvent()` อยู่แล้ว (จาก 24.4):
- เวลา update operator (ผ่าน `update` action หรือ action ใหม่ เช่น `assign_operator`):
  - log event type: `operator_changed`
  - payload: `{ "from": old_operator_id, "to": new_operator_id }`

ไม่ต้องซับซ้อน แค่เก็บร่องรอยไว้ก่อน

---

## 5. Frontend / JS — `assets/javascripts/hatthasilpa/job_ticket.js`

### 5.1 เพิ่ม Operator Select ใน Offcanvas

ใน offcanvas form detail ของ Job Ticket (ฝั่งขวา):
- เพิ่มฟิลด์:

```html
<div class="mb-3">
  <label for="jt-operator" class="form-label">Assigned Operator</label>
  <select id="jt-operator" class="form-select">
    <option value="">— ไม่ระบุ —</option>
    <!-- options จาก API people/operator -->
  </select>
</div>
```

- ไม่ต้องให้ user พิมพ์ชื่อเอง ใช้ select2 หรือ select ธรรมดาก็ได้ (ตาม style ปัจจุบันของหน้า)

### 5.2 ดึง Operator List จาก API ที่มีอยู่แล้ว

ถ้ามี API ที่ใช้ดึง operator อยู่แล้ว (เช่นจากหน้าอื่น):
- Reuse endpoint เดิม (เช่น `people.php?action=list_operators` หรือใกล้เคียง)
- ถ้าไม่มี endpoint เดียวที่ชัดเจน ให้ใช้ **mock** endpoint ชั่วคราวใน JS (dummy data) แล้วเขียน comment ว่า:
  - `// TODO: Replace with real operator API when People/Skill phase is ready`

(เป้าหมายตอนนี้คือออกแบบ flow ให้ถูกก่อน, data source จริงจะมาใน Phase People/Skill)

### 5.3 Binding Operator ↔ Ticket

ใน JS:
- เมื่อ load Ticket detail (`loadTicketDetail()`):
  - set ค่าใน `#jt-operator` ตาม `assigned_operator_id`

- เมื่อกด Save / Update Ticket (`saveTicket()` หรือฟังก์ชันที่ใช้ปัจจุบัน):
  - อ่านค่าจาก select: `$('#jt-operator').val()`
  - ใส่ลงใน payload: `assigned_operator_id`

### 5.4 UI กติกา Start Button

ใน `renderLifecycleButtons()` หรือส่วนที่ render ปุ่ม action:
- ถ้า status = `planned` และ `assigned_operator_id` เป็น null:
  - ให้ปุ่ม `Start`:
    - หรือถูก disable (พร้อม tooltip ว่า “กรุณาเลือก Operator ก่อนเริ่มงาน”) 
    - หรือไม่ render ปุ่ม `Start` เลยก็ได้ (เลือกแบบไหนแบบหนึ่งแล้วเขียน comment ชัดเจน)

- เมื่อ user เลือก operator แล้ว และกด Save/Update:
  - reload detail → ปุ่ม Start จะกลับมาใช้งานได้

### 5.5 Handle Error จาก Backend: `ERR_OPERATOR_REQUIRED`

ใน `callLifecycleTransition()` ที่ handle error จาก backend:
- ถ้า `error_code === 'ERR_OPERATOR_REQUIRED'`:
  - แสดง warning ชัดเจนด้านบน offcanvas (ใช้ warning banner ที่สร้างใน 24.5)
  - Optionally: focus ไปที่ field `#jt-operator`

ตัวอย่างข้อความ:
> "ไม่สามารถเริ่มงานได้ เนื่องจากยังไม่ได้เลือก Assigned Operator"

---

## 6. View Changes — `views/job_ticket.php`

### 6.1 เพิ่มช่อง Operator ใน Offcanvas

ใน offcanvas detail form:
- แทรก block สำหรับ operator ตาม layout ของ form เดิม (ดูให้กลมกลืนกับ block Product / Routing / Quantity)
- ชื่อ label ใช้คำว่า:
  - TH: `ช่างผู้รับผิดชอบ (Assigned Operator)`
  - EN (ใน code/comment): `Assigned Operator`

### 6.2 ตารางหลัก (ถ้าเหมาะสม)

ในตารางหลักของ Job Ticket:
- ถ้าพื้นที่ column พอ ให้เพิ่ม column:
  - `Operator` → แสดงชื่อย่อ/ชื่อเล่นของช่าง (ถ้าดึงได้)
- ถ้า column เริ่มแน่นแล้ว → ข้ามไปก่อนได้ (ระบุใน results ว่า optional)

---

## 7. Acceptance Criteria

1. Job Ticket (Classic) ที่สร้างใหม่ สามารถบันทึก `assigned_operator_id` ได้จากหน้า Job Ticket
2. ถ้ายังไม่เลือก operator → กด Start จากหน้า Job Ticket จะไม่ได้ (ERR_OPERATOR_REQUIRED)
3. เมื่อเลือก operator แล้ว → Start / Pause / Resume / Complete ทำงานเหมือนเดิม
4. UI แสดง operator ที่เลือกแล้วใน offcanvas อย่างถูกต้อง
5. ไม่มีผลกระทบกับ Hatthasilpa flow, MO flow, หรือ PWA

---

## 8. Notes for Agent

- อย่าแตะไฟล์ PWA ใด ๆ ใน Task 24.6 (เช่นภายใต้โฟลเดอร์ `pwa/`, `mobile/`)
- ถ้า schema `job_ticket` ยังไม่มี `assigned_operator_id` ให้ assume ว่ามี และเขียน logic รองรับไปก่อน พร้อมทั้งเพิ่ม note ใน results ว่า “ต้องการ migration”
- เขียนโค้ดให้ backward compatible กับ Ticket เดิมที่ไม่มี operator (null)
- อย่าเพิ่ม field ให้ user เลือก production_type / routing_mode ในหน้า UI (ค่าพวกนี้ระบบต้องตัดสินใจเอง)
- ใส่ comment ในโค้ดสำคัญว่า `// Task 24.6 — Assigned Operator` เพื่อให้ตามรอยได้ง่าย


_End of Task 24.6 Specification_