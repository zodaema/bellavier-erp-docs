📌 TASK_DAG_2 — Manager Assignment Rebaseline & Unified Specification

(PROMPT พร้อมรันโดย Cursor / AI Agent)

⸻

🎯 GOAL

Rebaseline ระบบ Manager Assignment ทั้งหมด ของ DAG ใหม่ให้เป็นหนึ่งเดียว
ครอบคลุมทุกระบบที่เกี่ยวข้อง และย้ายความรู้จากไฟล์เก่าใน docs/dag/agent-tasks/
ไปสู่เอกสารโครงสร้างใหม่ที่อยู่ใน:

docs/dag/03-tasks/TASK_DAG_2_MANAGER_ASSIGNMENT.md

Task นี้เป็น task สร้าง “Specification ระดับแม่” ของระบบ Manager Assignment
ซึ่งจะถูกใช้เป็น foundation สำหรับ Task 3, 4, 5 ต่อไป

⸻

📁 Scope ครอบคลุมทั้งหมด (สำคัญมาก)

1) Frontend
	•	work_queue UI
	•	job_ticket detail UI
	•	manager assignment panel
	•	operator dropdown behavior
	•	assignment state rendering
	•	error UI flow

2) Backend
	•	dag_token_api.php → assignment actions
	•	dag_operator_api.php → available operators
	•	work_queue filters + groupings
	•	People assignment logic (People DB)
	•	wait_node / availability / scheduling rules (จาก tasks 3–6 เก่า)
	•	Manager assignment permissions

3) Time Engine Integration
	•	start/pause/resume with assigned manager context
	•	assignment lock window
	•	auto-reassign rules

4) Migration of old documents

นำข้อมูลจากไฟล์เก่าเข้ามา เช่น:

task2.md
task2_IMPLEMENTATION_SUMMARY.md
task4_OPERATOR_AVAILABILITY_SCHEDULER.md
task6_OPERATOR_AVAILABILITY_FAILURE.md
task10_OPERATOR_AVAILABILITY_CONSOLIDATED.md
task10.1_OPERATOR_AVAILABILITY_POLICY.md
task10.2_OPERATOR_AVAILABILITY_PHRASES.md
INVESTIGATION_REPORT_NODE_PLAN.md

ต้อง merge เป็นเนื้อหาเดียวอย่างเรียบร้อย
และทำ “Mapping Table” ว่าข้อมูลเก่ามาจากไฟล์ใด

⸻

🧠 OUTPUT REQUIRED

ให้ Agent สร้างไฟล์ใหม่:

docs/dag/03-tasks/TASK_DAG_2_MANAGER_ASSIGNMENT.md

เนื้อหาต้องประกอบด้วย:

⸻

📘 SECTION 1 — Executive Summary (5–10 บรรทัด)
	•	ปัญหาในระบบเดิม
	•	ด้านใดบ้างที่ต้อง unify
	•	เป้าหมายของ Task 2

⸻

📘 SECTION 2 — Architecture Overview

แสดงระบบ Manager Assignment ทั้งหมดในภาพรวม:

[Frontend] → work_queue, job_ticket 
       ↓
[API] → dag_token_api.php?action=assign_manager
       → dag_operator_api.php?action=available
       → people_api.php (People DB)
       ↓
[Engine] → Time Engine
       ↓
[DB] → dag_token, dag_token_assignment, people, org tables


⸻

📘 SECTION 3 — Functional Specification (ละเอียดมาก)

3.1 Manager Selection Rules
	•	who can assign
	•	who can unassign
	•	when assignment is frozen
	•	when assignment is auto-updated

3.2 Operator Availability Rules

รวมความรู้จาก:
	•	task4 (availability schedule)
	•	task6 (failure modes)
	•	task10 (consolidated)
	•	task10.1 (policy)
	•	task10.2 (phrases & rules)

ให้กลายเป็นหนึ่งเอกสาร unified

3.3 Time Engine Binding

Manager Assignment ต้องสัมพันธ์กับ:
	•	start time
	•	pause
	•	resume
	•	duration tracking
	•	locked manager state

3.4 Multi-Tenant Rules
	•	manager from same org only
	•	cross-tenant enforcement (จาก task9)

3.5 Error Model

ทุก error ต้องระบุ:
	•	error_code
	•	description
	•	recommended action

⸻

📘 SECTION 4 — UI Specification

4.1 Work Queue UI
	•	dropdown list behavior
	•	tag color
	•	assignment chip behavior
	•	live update (polling or socket-ready spec)

4.2 Job Ticket UI
	•	manager card
	•	selection modal
	•	error flows
	•	skeleton loading for operator list

⸻

📘 SECTION 5 — API Contract Specification

dag_operator_api.php
	•	action=available
	•	returned fields
	•	filtering logic
	•	availability rule

dag_token_api.php
	•	action=assign_manager
	•	action=unassign_manager
	•	action=override_manager
	•	action=get_current_assignment

ระบุแบบละเอียด

⸻

📘 SECTION 6 — Database Model Specification

Tables:
	•	dag_token
	•	dag_token_assignment
	•	people
	•	people_org

ระบุ:
	•	field descriptions
	•	constraints
	•	indexes needed
	•	recommended migrations

⸻

📘 SECTION 7 — Migration From Old Tasks

อันนี้ “บังคับต้องมี”

สร้าง ตาราง mapping เช่น:

Old File	Merged Into	Notes
task2.md	Section 3	Main logic
task4.md	Section 3.2	Availability Rules
task10.1.md	Section 3.2	Policy integration
INVESTIGATION_REPORT_NODE_PLAN.md	Section 3.3	Decision rationale
task11.md	Referenced	UI part

ไม่ให้ข้อมูลหายแม้แต่ 1 บรรทัด

⸻

📘 SECTION 8 — Acceptance Criteria

ตัวอย่างเช่น:
	1.	ทุกไฟล์เก่าถูก merged → ไม่มีข้อมูลตกหล่น
	2.	UI + Backend + Time Engine integration ถูกอธิบายครบ
	3.	ทุก operator availability rule ถูกรวม
	4.	API contract ใหม่ชัดเจนและพร้อม implement
	5.	ไม่มี logic เก่าที่ขัดกันหรือตัดทิ้งโดยไม่อธิบาย

⸻

📘 SECTION 9 — Next Tasks

ปิดท้ายด้วยสิ่งที่ต้องทำต่อ:
	•	Task 3 — Wait Node v2 Specification
	•	Task 4 — Node Plan Next Actions
	•	Task 5 — Component Token Serialization
	•	Task 11 → Component Model v2
	•	ฯลฯ

⸻