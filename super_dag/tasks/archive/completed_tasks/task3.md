📄 Task 3 Specification — Behavior Awareness Integration (Read-Only Phase)

ไฟล์ที่ผมจะส่งออก:
docs/super_dag/tasks/task3.md

⸻

✅ ทุกส่วนที่จะอยู่ใน task3.md

ด้านล่างคือเนื้อหาเต็มที่จะถูกใส่ลงในไฟล์ทันทีเมื่อคุณอนุมัติ:

⸻

Task 3 — Behavior Awareness Integration (Read-Only Phase)

Status: Pending
Owner: AI Agent
Depends on: Task 1 (Behavior DB), Task 2 (Mapping UI/API)
Goal: ให้โมดูลหลักทุกตัว มองเห็น behavior metadata แต่ ยังไม่เปิดใช้ logic ใด ๆ

⸻

🎯 Objective

หลังจาก Task 1–2 พื้นฐาน Behavior Layer เสร็จสมบูรณ์แล้ว
Task 3 ตั้งใจให้ “ทั้งระบบรับรู้ behavior” เพื่อเตรียมพร้อมสู่ DAG Execution จริงใน Task 4+

⚠️ ห้ามใช้ logic ใด ๆ ตาม behavior ใน Task 3 — เป็น read-only เท่านั้น
(สำหรับความปลอดภัยและป้องกัน side-effects)

⸻

📦 Deliverables

🔹 1. API Enhancements (Read-only metadata)

เพิ่ม behavior metadata ลงใน API เหล่านี้:

API	สิ่งที่ต้องเพิ่ม
dag_routing_api.php	ส่ง behavior ของแต่ละ node
dag_token_api.php	ส่ง behavior ของ current node ใน token detail
mo_api.php	ส่ง behavior ของแต่ละ work center ใน MO routing
hatthasilpa_job_ticket.php	ส่ง behavior per step
work_queue.php	ส่ง behavior สำหรับแต่ละ queue row
pwa_scan_api.php	ส่ง behavior ของ node ที่ต้อง scan


⸻

🔹 2. UI Enhancements (Display-only)

เพิ่ม behavior badge (สีประจำ behavior) ใน UI ต่อไปนี้:
	•	Work Queue table
	•	MO Detail page
	•	Hatthasilpa Job Ticket Detail page
	•	PWA Scan screen
	•	DAG Routing Debug Tool
	•	Token Detail popup

ตัวอย่าง Badge:
	•	CUT → 🟦 CUT
	•	EDGE → 🟪 EDGE
	•	STITCH → 🟩 STITCH
	•	HARDWARE → 🟧 HW
	•	QC → 🟥 QC

UI Only — ไม่มี logic

⸻

🔹 3. Behavior Metadata Format (Standard Output)

ทุก API จะเพิ่ม field แบบนี้ลงในแต่ละ node/work center:

{
  "behavior": {
    "code": "CUT",
    "name": "Cutting",
    "description": "Cutting raw materials",
    "execution_mode": "BATCH",
    "time_tracking_mode": "PER_BATCH"
  }
}


⸻

📁 Files to Update

PHP (6 files)
	•	source/dag_routing_api.php
	•	source/dag_token_api.php
	•	source/mo_api.php
	•	source/hatthasilpa_job_ticket.php
	•	source/work_queue.php
	•	source/pwa_scan_api.php

JS / UI (5 files)
	•	Work Queue JS
	•	Job Ticket UI
	•	MO Detail UI
	•	PWA Scan UI
	•	DAG Designer Debug UI

⸻

🔐 Safety Rails

เพื่อให้ Task 3 ไม่ส่งผลต่อระบบหลัก:
	1.	❌ ห้ามแตะ Time Engine
	2.	❌ ห้ามแตะ Token Engine
	3.	❌ ห้ามแตะ DAG Execution Logic
	4.	❌ ห้ามเพิ่มฟังก์ชันใหม่ที่เปลี่ยน behavior ของระบบ
	5.	❌ ห้ามเพิ่ม validation logic ใหม่ที่บังคับ behavior
	6.	❌ แค่ enrich response เท่านั้น

⸻

🧪 Test Plan (AI Agent & Human)

Unit Tests
	•	Behavior metadata appears in every relevant API
	•	APIs ยังตอบ JSON เดิม + metadata (backward compatible)

Integration Tests
	1.	Work Queue → behavior column should appear
	2.	Token Detail → must show behavior name
	3.	PWA Scan → resolves correct behavior
	4.	MO Detail → shows behavior per routing step
	5.	DAG Debug → shows behavior metadata

Manual Tests
	•	เปิดหน้า Work Queue / MO / Job Ticket / PWA แล้วเช็ค badge
	•	Behavior badge ต้องสอดคล้องกับ mapping ใน Work Centers

⸻

💬 Example Commit Message

Task 3: Add behavior metadata to DAG/MO/Queue/PWA APIs (read-only)
- Add WorkCenterBehaviorRepository to all routing/token APIs
- Enrich API outputs with behavior descriptors
- Add UI badges in queue, ticket, MO detail, PWA
- No execution logic added (read-only phase)


⸻

✔️ Definition of Done
	•	API ทุกตัวมี behavior metadata
	•	UI แสดง behavior badge
	•	ไม่มี behavioral logic ถูกใช้
	•	เอกสาร task3_results.md อัปเดต
	•	ทุกหน้าใช้งานได้ตามเดิม
	•	Backward compatible 100%

⸻