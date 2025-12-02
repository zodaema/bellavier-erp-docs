Prompt สำหรับ Agent — Task 24.6.2 Operator Harmonization (Phase 1)

เอาไปวางในไฟล์ docs/super_dag/tasks/task24_6_2_operator_harmonization.md หรือส่งตรงให้ Agent ก็ได้เลย:

# Task 24.6.2 — Operator Field Harmonization (Phase 1: Read/Write + UI)

## Objective
ทำให้ระบบ Job Ticket ใช้ `assigned_operator_id` เป็น source of truth สำหรับ "ผู้รับผิดชอบหลักของบัตรงาน" แต่ยังรองรับ legacy data (`assigned_user_id`, `assigned_to`) ในเชิงอ่านอย่างเดียว (fallback) โดย:

1. Backend อ่าน operator จาก `assigned_operator_id` เป็นหลัก ถ้าไม่มี → fallback ไป `assigned_user_id`
2. Backend เขียน operator เฉพาะใน `assigned_operator_id`
3. UI/JS ใช้ field เดียว (`assigned_operator_id`) และตัด legacy select (`#ticket_assigned`) ทิ้ง
4. Query รายการ และ detail แสดงชื่อ operator ตาม `assigned_operator_id` (พร้อม fallback) ให้ตรงกับที่ใช้ใน validation (start job)

---

## Scope Files

1. `source/job_ticket.php`
2. `assets/javascripts/hatthasilpa/job_ticket.js`
3. `views/job_ticket.php`
4. (อ่านอย่างเดียว เพื่อไม่หลุด scope) `source/BGERP/Service/JobCreationService.php`, `source/classic_api.php`, `source/mo.php`

อย่าลบ column หรือแก้ schema ใน task นี้  
โฟกัสเฉพาะ logic อ่าน/เขียน + UI

---

## Part A — Backend Harmonization (`source/job_ticket.php`)

### A.1 list action (GET `job_ticket.php?action=list`)

**เป้าหมาย:** ให้ list ใช้ operator เดียวกับที่ใช้ใน detail + validation

1. ปรับ SELECT ของ `ajt`:
   - ยืนยันว่าเลือก `ajt.assigned_operator_id` ใน select (หรือผ่าน `ajt.*`)
   - เพิ่ม field คำนวณ `effective_operator_id` แบบนี้ (ใช้ alias):

   ```sql
   COALESCE(ajt.assigned_operator_id, ajt.assigned_user_id) AS effective_operator_id

	2.	ปรับ JOIN สำหรับชื่อ operator:
	•	เดิม: JOIN ผ่าน assigned_user_id
	•	ใหม่: ใช้ effective_operator_id แทน:
ตัวอย่างแนวทาง (เขียนให้ตรงกับ style ปัจจุบันของไฟล์):

LEFT JOIN bgerp.account_org ao
  ON ao.id_member = COALESCE(ajt.assigned_operator_id, ajt.assigned_user_id)
LEFT JOIN bgerp.account a
  ON a.id_account = ao.id_account


	3.	ในผลลัพธ์ JSON:
	•	ให้ field assigned_operator_id = ajt.assigned_operator_id (จริง)
	•	ให้ field assigned_name = ชื่อจาก JOIN ข้างต้น (ตาม effective_operator_id)
	•	assigned_to / assigned_user_id ยังสามารถส่งกลับ (เพื่อ backward compat) แต่จะไม่ถูกใช้ต่อใน JS ใหม่

ข้อสำคัญ: ห้ามลด fields ที่ list ส่งกลับลงใน task นี้ ให้ยัง backward compatible ไว้ก่อน

⸻

A.2 get action (GET job_ticket.php?action=get)

เป้าหมาย: detail view ต้องแสดง operator เดียวกับ list และกับ validation
	1.	ปรับ logic ที่ปัจจุบัน fetch assigned_name จาก assigned_user_id:
	•	เปลี่ยนให้ใช้ COALESCE(assigned_operator_id, assigned_user_id) แทน
	•	ถ้า assigned_operator_id ไม่เป็น null → ใช้เป็นหลัก
	•	ถ้า null → ลองใช้ assigned_user_id
	•	ถ้า null ทั้งคู่ → ไม่ต้องฝืนสร้างชื่อ (ปล่อยเป็น null/“-”)
	2.	เพิ่ม field ใน JSON response:
	•	assigned_operator_id → int|null
	•	assigned_name → string|null จาก effective operator

อย่าเปลี่ยนชื่อ field JSON ที่ frontend ใช้อยู่แล้ว (assigned_name) แต่ให้เปลี่ยนวิธีคำนวณข้างในแทน

⸻

A.3 create / update action (POST action=create / action=update)

เป้าหมาย: เวลาเขียนข้อมูล ให้เขียน operator แค่ที่ assigned_operator_id เท่านั้น
	1.	ส่วนอ่าน request payload:
	•	ให้อ่านข้อความ operator จาก field เดียว:
	•	$assignedOperatorId = $request->get('assigned_operator_id');
	•	อย่าอ่าน/ใช้ $assigned_to และ $assigned_user_id จาก request แล้ว
	2.	ส่วน INSERT (create):
	•	ตัด assigned_to และ assigned_user_id ออกจาก column + values
	•	ให้เหลือเฉพาะ assigned_operator_id
	•	ถ้า code ปัจจุบันมี guard columnExists('assigned_operator_id') ให้คงไว้
	3.	ส่วน UPDATE (update):
	•	ตัดหรืองดการ bind/update assigned_to และ assigned_user_id
	•	ให้ update เฉพาะ assigned_operator_id
	•	Logic event logging (OPERATOR_CHANGED) ให้ใช้การเปรียบเทียบค่าเก่า/ใหม่ของ assigned_operator_id เท่านั้น

อย่าลืมตรวจว่าไม่มีจุดไหนในไฟล์ที่ยังใช้ $payload['assigned_to'] หรือ $payload['assigned_user_id'] อยู่ ถ้ามีให้ลบ/คอมเมนต์ออกไป (ยกเว้น field ใน SELECT สำหรับ backward compat)

⸻

A.4 start action (POST action=start)

เป้าหมาย: กติกาเดิมถูกแล้ว แค่ยืนยันว่าใช้ assigned_operator_id อย่างเดียว
	•	ตรวจสอบว่า validation ตอน start:
	•	เช็ค empty($ticket['assigned_operator_id']) → โอเคแล้ว
	•	ไม่ต้อง fallback ไปใช้ assigned_user_id
	•	ถ้าใน code มีการ print operator name ใน log หรือ event:
	•	ให้ใช้ชื่อจาก assigned_name ที่คำนวณจาก effective operator (ข้อ A.2)

⸻

Part B — Frontend Harmonization (assets/javascripts/hatthasilpa/job_ticket.js)

B.1 ตัด legacy select & payload
	1.	หา element #ticket_assigned ใน JS:
	•	ลบ logic ที่:
	•	อ่านค่า #ticket_assigned ใส่ payload (assigned_to, assigned_user_id)
	•	set ค่า #ticket_assigned ตอน fill form
	•	ไม่ต้องส่ง assigned_to / assigned_user_id ใน payload แล้ว
	2.	ฟังก์ชันที่ต้องเช็ค/แก้:
	•	gatherTicketPayload() / ฟังก์ชันที่ประกอบ payload สำหรับ create/update
	•	fillTicketForm() / logic ที่ set select ใน offcanvas
	3.	ให้เหลือเฉพาะ field เดียวใน payload:

payload.assigned_operator_id = $('#jt-operator').val() || null;



⸻

B.2 การแสดงชื่อ operator
	1.	ใน table row / detail view:
	•	ให้ใช้ data.assigned_name เป็นหลัก (ซึ่ง backend จะหาให้จาก effective operator id แล้ว)
	•	ถ้า assigned_name ว่าง → แสดง '-' หรือข้อความ default
	•	เอา fallback ที่อิง assigned_to ออกได้เลย

ตัวอย่าง:

const operatorName = data.assigned_name || '-';
$('#jt-operator-name-display').text(operatorName);

หรือใน DataTable render: ใช้ row.assigned_name || '—'

⸻

B.3 lifecycle buttons / validation UI
	•	ตรวจสอบว่า renderLifecycleButtons() ใช้ assigned_operator_id จาก backend (ซึ่งจะมาจาก data.assigned_operator_id)
	•	ถ้า assigned_operator_id เป็น null → disable ปุ่ม Start และแสดง tooltip ว่า “ต้องเลือกผู้รับผิดชอบก่อน”
	•	ตรงนี้ logic ปัจจุบันใกล้เคียงแล้ว ให้เช็คเพิ่มว่าไม่มี reference ไปที่ assigned_user_id / assigned_to

⸻

B.4 saveOperatorAssignment()
	•	ให้ฟังก์ชันนี้:
	•	อ่าน operator จาก #jt-operator
	•	ส่งไป update ที่ assigned_operator_id อย่างเดียว
	•	หลัง save สำเร็จ ให้ reload detail (หรือ update ชื่อใน UI) โดยใช้ assigned_name จาก response
	•	ตรวจสอบให้แน่ใจว่าไม่มีการส่ง assigned_to / assigned_user_id อีก

⸻

Part C — Views Cleanup (views/job_ticket.php)

C.1 ตัด legacy select
	1.	หา block เดิมที่เป็น select สำหรับ assignment เช่น:

<select id="ticket_assigned" ...> ... </select>

	2.	ถ้า block นี้ยังอยู่ และไม่ได้ใช้กับ requirement อื่น ให้:
	•	ลบออกจาก view
	•	ยืนยันว่า UI ตอนนี้มีแค่ select ตัวใหม่:

<select id="jt-operator" ...> ... </select>

	3.	ถ้ามี label หรือ column ใดใน table ที่เขียนว่า “Assigned To” ให้ตรวจว่า:
	•	ใช้แสดง assigned_name เดียวกันกับ operator
	•	หรือเปลี่ยน label เป็น “Operator” / “ผู้รับผิดชอบ” ให้ consistent

⸻

Part D — ไม่ต้องทำใน Task นี้ แต่ให้ตรวจให้แน่ใจ
	1.	JobCreationService / classic_api / mo.php
	•	Confirm เฉย ๆ ว่า ณ ตอนนี้:
	•	เวลาสร้าง job_ticket ผ่าน Service/API เหล่านี้ สามารถปล่อย assigned_operator_id = NULL ได้
	•	จะไม่เกิด fatal error
	•	ยังไม่ต้องเพิ่ม parameter สำหรับ operator ใน task 24.6.2
(เดี๋ยวแยกไปอีก task: “24.6.3 – MO/Classic Job Creation Operator Hook”)

⸻

Deliverables
	1.	แก้ไขไฟล์:
	•	source/job_ticket.php
	•	assets/javascripts/hatthasilpa/job_ticket.js
	•	views/job_ticket.php
	2.	สร้าง/อัปเดตเอกสาร:
	•	docs/super_dag/tasks/results/task24_6_2_results.md
	•	ใส่เนื้อหา:
	•	สรุปการเปลี่ยนแปลงแต่ละไฟล์
	•	ตัวอย่าง JSON ก่อน/หลังสำหรับ list + get
	•	ตัวอย่าง payload create/update ก่อน/หลัง
	•	ข้อจำกัด (เช่น Ticket เก่าที่มีแต่ assigned_user_id จะอ่านมาเป็น operator ผ่าน fallback)
	3.	รัน syntax check ให้ครบ:
	•	php -l source/job_ticket.php
	•	php -l source/job_ticket_progress_api.php (กัน side-effect)
	•	build frontend / lint JS ถ้ามี script เดิมใช้

---