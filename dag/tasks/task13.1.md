🧩 Task 13.1 – Hatthasilpa Component API Manual Validation

Goal:
พิสูจน์ให้แน่ชัดว่า hatthasilpa_component_api.php ใช้งานได้จริงครบทุกกรณีพื้นฐาน ก่อนเอาไปผูกกับ UI / Job Ticket / Workcenter

Scope:
เฉพาะ 2 actions นี้ (ยังไม่แตะ UI)
	•	action=bind_component_serial
	•	action=get_component_serials

⸻

1. Files & Areas ที่เกี่ยวข้อง

ให้ Agent โฟกัสไฟล์/ส่วนนี้เท่านั้น (ห้ามออกนอกกรอบ):
	•	API หลัก
	•	source/hatthasilpa_component_api.php
	•	ตารางที่เกี่ยวข้องใน tenant DB
	•	job_ticket
	•	job_component_serial
	•	Feature Flag (อ่านจาก core DB):
	•	FF_HAT_COMPONENT_SERIAL_BINDING (ผ่าน FeatureFlagService)
	•	Permission / Auth
	•	must_allow_code($member, 'hatthasilpa.job.ticket')
	•	memberDetail->thisLogin()

⸻

2. Output ที่ต้องมีหลังจบ Task 13.1
	1.	เอกสาร test case แบบ human-readable
	•	สร้างไฟล์:
	•	docs/dag/task13_1_component_binding_manual_tests.md
	•	ในไฟล์นี้ต้องมี:
	•	Context / เป้าหมายของ Task 13.1
	•	สรุป API (input / output ของแต่ละ action)
	•	Test Matrix (ตาราง test case แบบละเอียด)
	•	สรุปผลที่ทดสอบจริง (pass / fail และ note ถ้ามี bug)
	2.	Sample Requests
	•	สร้างไฟล์ HTTP examples:
	•	docs/api/examples/hatthasilpa_component_api.http
	•	ใส่ตัวอย่าง:
	•	POST /source/hatthasilpa_component_api.php?action=bind_component_serial
	•	GET  /source/hatthasilpa_component_api.php?action=get_component_serials&job_ticket_id=...
	•	ครอบคลุม:
	•	Happy path
	•	Feature flag off
	•	Validation fail
	•	Not found
	•	Unauthorized

💡 จุดนี้สำคัญ: Task 13.1 = ยังไม่เขียน PHPUnit / Integration Test
Automated tests จะไปอยู่ Task 13.6 ตาม roadmap

⸻

3. Test Matrix (ให้ Agent แปลงเป็นตารางใน md)

ให้ Agent จัดรูปแบบเป็น table แบบนี้ใน task13_1_component_binding_manual_tests.md:

3.1 bind_component_serial – Happy Paths
	1.	TC1 – Basic bind with minimal fields
	•	Input:
	•	job_ticket_id = job ที่มีอยู่จริง
	•	component_serial = string 1 ชิ้น
	•	ไม่ส่ง: final_piece_serial, id_component_token, id_final_token, bom_line_id
	•	Expect:
	•	ok: true
	•	data.id_binding เป็น int > 0
	•	row ถูก insert ลง job_component_serial
	•	log ใน PHP error log มี [HatthasilpaComponentAPI] Component serial bound: ...
	2.	TC2 – Bind with all optional fields
	•	Input:
	•	job_ticket_id valid
	•	component_code = "BODY"
	•	component_serial = string
	•	final_piece_serial = serial ของชิ้นงานหลัก
	•	id_component_token, id_final_token, bom_line_id = int valid
	•	Expect:
	•	ok: true
	•	field ทั้งหมดถูกบันทึกครบ
	•	type ถูกต้อง (int/null)
	3.	TC3 – Multi-bind on same job_ticket
	•	Bind ซ้ำหลาย component (BODY, LINING, HARDWARE) บน job_ticket_id เดียวกัน
	•	Expect:
	•	ทุกครั้ง ok: true
	•	job_component_serial มีหลาย row ผูกกับ job เดิม

ห้าม enforce uniqueness / rules ใดๆ ใน Task13.1
ตอนนี้ Stage 1 = “Capture & Expose” ยังไม่ใช่ “Enforcement”

⸻

3.2 bind_component_serial – Error / Guard Cases
	4.	TC4 – Feature flag disabled
	•	ปิด FF_HAT_COMPONENT_SERIAL_BINDING สำหรับ tenant นี้
	•	Call bind_component_serial
	•	Expect:
	•	ok: false
	•	app_code: HAT_COMPONENT_403_FEATURE_DISABLED
	•	HTTP status = 403 (ถ้า test ผ่าน browser / curl ดู header ด้วย)
	5.	TC5 – Validation fail – missing required fields
	•	ไม่ส่ง job_ticket_id
	•	หรือส่ง component_serial = ""
	•	Expect:
	•	ok: false
	•	app_code: HAT_COMPONENT_400_VALIDATION
	•	errors มี key ที่ fail
	6.	TC6 – job_ticket not found
	•	ส่ง job_ticket_id ที่ไม่มีอยู่จริง
	•	Expect:
	•	ok: false
	•	app_code: HAT_COMPONENT_404_JOB_NOT_FOUND
	7.	TC7 – Unauthorized (not logged in)
	•	ล้าง session / เปิด incognito แล้วยิง API ตรง
	•	Expect:
	•	ok: false
	•	app_code: AUTH_401_UNAUTHORIZED
	•	กรณีนี้อาจถูก intercept ก่อนถึง switch-case (ดู behavior actual แล้วบันทึกใน doc)
	8.	TC8 – Permission denied
	•	ใช้ user ที่ login ได้ แต่ ไม่มี code hatthasilpa.job.ticket
	•	Expect:
	•	ok: false
	•	error จาก must_allow_code (เก็บ error message จริงๆ ใน doc)

⸻

3.3 get_component_serials – Cases
	9.	TC9 – No bindings yet
	•	job_ticket_id valid แต่ยังไม่เคย bind
	•	Expect:
	•	ok: true
	•	data.component_serials = [] (array ว่าง)
	10.	TC10 – With bindings
	•	ใช้ job ที่ผ่าน TC1–3
	•	Expect:
	•	ok: true
	•	component_serials มี list ตรงกับใน DB
	•	sort ตาม component_code, component_serial
	11.	TC11 – Validation error
	•	job_ticket_id missing / 0 / negative
	•	Expect:
	•	ok: false
	•	app_code: HAT_COMPONENT_400_VALIDATION
	12.	TC12 – Unauthorized / Permission denied
	•	เหมือน TC7 / TC8 แต่กับ action นี้
	•	Expect behavior consistent กับ bind action

⸻

4. Implementation Notes สำหรับ Agent

ให้ Agent ทำตามนี้แบบ step-by-step:
	1.	สร้างไฟล์เอกสาร:
	•	docs/dag/task13_1_component_binding_manual_tests.md
	•	ใช้โครงสร้าง:
	•	Title + Context
	•	API Summary (actions, inputs, outputs)
	•	Test Environment (tenant, base URL, sample job_ticket_id)
	•	Test Matrix (แยก happy / error / edge cases)
	•	Execution Log (ช่องให้มนุษย์กรอกจริงตอนเทส)
	2.	สร้าง HTTP example file:
	•	docs/api/examples/hatthasilpa_component_api.http
	•	ใส่ตัวอย่าง:
	•	Happy path (bind)
	•	Feature flag disabled
	•	Validation error
	•	Get component_serials (empty / non-empty)
	3.	ไม่แก้ business logic ใน hatthasilpa_component_api.php
	•	ยกเว้น:
	•	เจอ bug จริงจากการเทส ให้จดใน doc ก่อน
แล้วค่อยเปิดเป็น Task 13.1.x / 13.2 refactor อีกที
	•	ห้าม:
	•	เปลี่ยนชื่อ field
	•	เปลี่ยน app_code
	•	เปลี่ยนโครง JSON
	4.	เช็คว่ามี Feature Flag จริง
	•	ถ้าไม่มี record FF_HAT_COMPONENT_SERIAL_BINDING
ให้บันทึกใน doc ว่า “ต้องมี manual setup ใน core DB”
แต่ห้ามเขียน SQL ลงเอกสารแบบ hard-coded (เพื่อความยืดหยุ่น)

⸻

5. Definition of Done สำหรับ Task 13.1

Task 13.1 ถือว่า “จบ” ก็ต่อเมื่อ:
	•	✅ docs/dag/task13_1_component_binding_manual_tests.md มี test case ครบตาม matrix และมีช่องให้กรอกผลจริง
	•	✅ docs/api/examples/hatthasilpa_component_api.http สร้างเสร็จ ใช้ยิงเทสได้จริง
	•	✅ คุณลองยิงอย่างน้อย 3–5 เคส (happy + error) แล้ว JSON ตรงตาม expectation (ถ้าไม่ตรง ให้บันทึกในเอกสาร)
	•	✅ ไม่มีการเปลี่ยน business logic / app_code โดยไม่จำเป็น
	•	✅ ถ้ามี bug → ถูกจดใน section “Known Issues / Next Tasks” ในไฟล์เดียวกัน