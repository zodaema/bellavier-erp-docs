
✅ Task 24.6.3 — Job Owner Finalization & Legacy Operator Cleanup (MEGA TASK)

Goal: แก้ความสับสนทั้งหมดเกี่ยวกับ operator, owner, assignment ก่อนจะเข้าสู่ Phase 25 (Node Assignment)
ระบบต้องถูก set ให้ถูกตั้งแต่รากฐาน ไม่เช่นนั้นจะกลายเป็น spaghetti

⸻

🎯 Objectives (ทำครบทุกข้อใน Task เดียว)

A) Database Renaming

เปลี่ยนชื่อ field ที่ผิดหลักให้ถูกต้อง:

1) job_ticket.assigned_operator_id → job_owner_id
	•	เปลี่ยนชื่อตารางจริงด้วย migration
	•	รองรับ fallback legacy fields (อ่านได้ แต่จะไม่เขียน)

2) ไม่แตะต้อง assigned_user_id และ assigned_to (legacy read-only)

แต่ annotate ว่า deprecated

⸻

B) Backend Refactor (ทุกที่ที่ใช้ operator → owner)

1) source/job_ticket.php
	•	เปลี่ยนทุก reference จาก assigned_operator_id → job_owner_id
	•	เปลี่ยน validation → ERR_OWNER_REQUIRED
	•	เปลี่ยน error message และ label wording ทั้งหมด
	•	เปลี่ยน list/get/create/update ให้ใช้ job_owner_id + fallback legacy

2) JobTicketProgressService
	•	ถ้ามี usage ของ assigned_operator_id ให้เปลี่ยนเป็น owner

3) MO → Job Ticket creation hooks
	•	MOCreateAssistService (if any)
	•	classic_api.php
	•	JobCreationService
	•	ทุกจุดที่สร้าง ticket ใหม่ ต้องส่ง job_owner_id

⸻

C) Frontend Refactor

1) JS

ไฟล์: assets/javascripts/hatthasilpa/job_ticket.js

เปลี่ยน:
	•	assigned_operator_id → job_owner_id
	•	ทุก UI label “Assigned Operator” → “Job Owner” / “เจ้าของบัตรงาน”
	•	Validation: ถ้าไม่มี job_owner_id → disable start

ลบ:
	•	ค่า legacy ที่ไม่ต้องใช้แล้ว (แต่รองรับอ่าน fallback ผ่าน backend)

2) Views

ไฟล์: views/job_ticket.php

เปลี่ยน UI ทั้งหมด:
	•	“ช่างผู้รับผิดชอบ (Assigned Operator)” → “เจ้าของบัตรงาน (Job Owner)”
	•	Table column → “Job Owner”
	•	Offcanvas → “Job Owner”
	•	Create/Edit modal → ลบ legacy fields และเปลี่ยน label

⸻

D) API Harmonization

1) job_ticket_progress_api.php

เปลี่ยน response key:
	•	assigned_operator_id → job_owner_id

2) job_ticket.php API responses

แก้ JSON ทั้งหมด:
	•	ใช้ key job_owner_id
	•	ส่ง assigned_operator_id ไปด้วยเพื่อ backwards-compatibility 1 version (optional)

⸻

E) Backward Compatibility Layer (สำคัญมาก)
	•	ถ้า request payload ยังส่ง assigned_operator_id ให้ map → job_owner_id แบบ silent
	•	ถ้า request payload ยังส่ง assigned_user_id → ใช้เป็น fallback (อ่านเท่านั้น)
	•	ถ้า database ยังไม่มี column ใหม่ ให้ skip (เหมือน pattern ที่ทำใน 24.6.1/24.6.2)

⸻

F) Code Cleanup From Audit

รวม patch จาก audit 24.6.2:
	•	remove legacy operator select from JS
	•	ensure no part of code references assigned_operator_id anymore
	•	unify operator display → job_owner_name
	•	fix list query SELECT fields duplication
	•	fix inconsistent queries between list/get
	•	fix payload inconsistencies (บางจุดส่ง null, บางจุดส่ง empty string)

⸻

G) Unit & Manual Testing Requirements

1) Create Job Ticket
	•	job_owner_id ถูกเขียนใน DB
	•	name แสดงถูกต้อง

2) Start / Pause / Resume / Complete
	•	ถ้าไม่มี job_owner_id → block start
	•	error messages ถูกต้อง

3) Existing Legacy Tickets
	•	ถ้ามี assigned_user_id แต่ไม่มี job_owner_id
→ UI ต้องแสดง owner name ถูกต้อง
→ Save ใหม่ต้องเขียนเป็น job_owner_id เท่านั้น

4) List / Detail UI
	•	ต้องแสดง owner ถูกต้อง
	•	ต้องไม่แสดง operator wording อีก

⸻

🧨 สิ่งที่ต้องห้ามใน Task นี้ (เพื่อไม่ให้ Agent ทำผิด)
	•	ห้ามแตะ Node Assignment (ยังไม่เริ่ม Phase 25)
	•	ห้ามสร้าง column ใหม่นอกจาก rename assigned_operator_id
	•	ห้ามลบ legacy fields จาก DB (อ่าน-only)

⸻

🏁 สุดท้าย: Prompt ให้ Agent ทำงานได้ทันที (พร้อมใช้)

# Task 24.6.3 — Job Owner Finalization & Operator Cleanup

You must refactor the entire Job Ticket module so that:
- "assigned_operator_id" is renamed to "job_owner_id" (database + backend + frontend)
- The system no longer uses the term “operator” for job ownership
- The UI must show “Job Owner” (Thai: "เจ้าของบัตรงาน") everywhere
- Classic Line job ownership is now separate from “operator assignment per node” in the future phase

## BACKEND (PHP)
1. Rename column in job_ticket table:
   assigned_operator_id → job_owner_id  
   (with backward-compatibility: if column does not exist, skip)

2. Update job_ticket.php:
   - List/Get must return job_owner_id, job_owner_name
   - Create/Update must accept job_owner_id only
   - Fallback logic: if job_owner_id is null but assigned_user_id exists → treat as job_owner_id
   - Update validation: Start only allowed if job_owner_id exists
   - Replace all references of assigned_operator_id with job_owner_id

3. Update all services:
   - JobTicketProgressService
   - JobCreationService
   - classic_api.php
   - Any place creating job tickets must pass job_owner_id

4. API updates:
   - job_ticket_progress_api.php → return job_owner_id
   - Maintain backwards-compatible aliases for 1 version only

## FRONTEND (JS)
1. Replace all “assigned_operator_id” with “job_owner_id”
2. Replace UI text “Assigned Operator” with “Job Owner”
3. Remove any remaining legacy fields (assigned_to, assigned_user_id)
4. Ensure validation requires job_owner_id before Start
5. Ensure rendering uses job_owner_name

## VIEWS (PHP)
1. Update table column headers → “Job Owner”
2. Update offcanvas detail fields → “Job Owner”
3. Update Create/Edit UI → show only job_owner_id selector

## CLEANUP
- Delete any dead code referencing assigned_operator_id
- Ensure no part of system uses operator wording for job ownership
- Ensure compatibility with legacy tickets (fallback logic)

After finishing, run syntax checks and ensure no references to assigned_operator_id remain.

