✅ Prompt สำหรับ AI Agent — Task 24.6.1 PRE-SCAN (Operator Field Audit)

🔥 คัดลอกข้อความด้านล่างส่งให้ Agent ได้เลย ใช้ได้ทั้ง Cursor / Factory Droid

⸻

🟦 TASK 24.6.1 — OPERATOR FIELD AUDIT

Objective

รวบรวมข้อมูลทั้งหมดที่เกี่ยวข้องกับ operator assignment ในระบบ Job Ticket (Classic Line)
เพื่อตรวจสอบว่า:
	•	มี field อะไรบ้างที่เกี่ยวกับ operator
	•	มี API / Helper / Service / SQL / JS อะไรที่อ่าน/เขียน field เหล่านี้
	•	ช่องทางไหน ยังใช้ assigned_to / assigned_user_id อยู่
	•	ช่องทางไหนใช้ assigned_operator_id (ตัวใหม่)
	•	มีจุดไหน “ซ่อนอยู่” ใน legacy code หรือไม่ได้เชื่อมกับ UI ใหม่
	•	มีจุดไหนที่ทำให้เกิด ความเสี่ยงข้อมูลไม่ตรง / เขียนทับผิด field

⸻

🔍 Scope ที่ต้องสแกน

1. Database Fields

ค้นในตาราง job_ticket:
	•	assigned_to
	•	assigned_user_id
	•	assigned_operator_id

ตรวจว่า column ถูกใช้ที่ไฟล์ไหนบ้าง (query insert/update/select)

⸻

2. Backend Files (PHP)

ค้นในโฟลเดอร์:
	•	/source/job_ticket.php
	•	/source/BGERP/JobTicket/
	•	/source/BGERP/Service/
	•	/source/BGERP/Dag/
	•	/source/helpers/
	•	/source/api/

หา function/API ที่เกี่ยวข้องกับ:
	•	การสร้าง ticket
	•	การอัปเดต ticket
	•	การโหลด ticket
	•	การ render list
	•	การเปลี่ยน operator
	•	การสร้าง/โหลดโมดาล
	•	การโยนต่อไปยัง work session / token / lifecycle

⸻

3. Frontend (JS)

ค้นใน:
	•	assets/javascripts/hatthasilpa/job_ticket.js
	•	assets/javascripts/hatthasilpa/…
	•	views/job_ticket.php

สแกนจุดที่:
	•	render operator name
	•	ใช้ operator ใน offcanvas
	•	update operator
	•	disable START ปุ่มถ้าไม่มี operator
	•	fallback logic

⸻

4. MO / Job Ticket Integration

ค้นหาใน:
	•	source/mo.php
	•	source/MO*Service.php
	•	mo_assist_api.php
	•	mo_eta_api.php

ว่ามีจุดไหนโยน operator id เข้ามาใน job_ticket หรือไม่

⸻

5. Worker / Member / People Relationship

ค้นใน:
	•	member_class.php
	•	operator list APIs
	•	helper ที่เกี่ยวกับ member info

ว่ามีการ map:
	•	assigned_to → member
	•	assigned_user_id → member
	•	assigned_operator_id → member

ยังอยู่หรือไม่

⸻

📦 Output Format (สำคัญมาก)

ให้ Agent แสดงผลลัพธ์แบบนี้:

⸻

1. Operator Fields Summary

job_ticket.assigned_to                 → used in: [...]
job_ticket.assigned_user_id            → used in: [...]
job_ticket.assigned_operator_id        → used in: [...]


⸻

2. API Usage

รายการ API + method + ไฟล์ที่อ่าน/เขียน operator fields
พร้อมบอกว่าปัจจุบันใช้ field อันไหนเป็นหลัก

ตัวอย่าง:

GET job_ticket/get        → assigned_operator_id (main)
POST job_ticket/update    → assigned_operator_id (write)
Legacy: job_ticket/create → assigned_to (old)  ← FLAG_FOR_REMOVAL


⸻

3. JS Usage

job_ticket.js:
 - loadTicketDetail()     → use assigned_operator_id
 - saveOperatorAssignment → write assigned_operator_id
Legacy fallback: assigned_to still printed in header  ← FLAG_FOR_REMOVAL


⸻

4. Conflicts / Redundant Fields

แสดงจุดที่มีความเสี่ยง เช่น:

⚠ Conflict: assigned_to used to load operator name in list view
⚠ Conflict: assigned_user_id updated in backend for no reason
⚠ Dead code: assigned_user_id never referenced in UI


⸻

5. Clean Migration Paths

เสนอ path เช่น:

→ KEEP: assigned_operator_id
→ DEPRECATE: assigned_to, assigned_user_id
→ MIGRATION REQUIRED: unify operator display in ticket header
→ PATCH REQUIRED: job_ticket list query must use assigned_operator_id only


⸻

🎯 Goal

ให้ Agent ส่ง Audit Report ครบทุกจุด → หลังจากนั้นเราจะเข้าสู่

➡ Task 24.6.1 — Operator Field Harmonization Patch

เพื่อให้ทั้งระบบใช้ field เดียวเท่านั้น:
assigned_operator_id