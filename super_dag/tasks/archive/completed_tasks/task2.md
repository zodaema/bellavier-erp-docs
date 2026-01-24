📄 super_dag/tasks/task2.md – Work Center Behavior Mapping UI + API

Version: 1.0
Depends on:
	•	Task1 (Behavior DB + Repository)
	•	Existing work_centers.php API
	•	Existing Work Center CRUD UI

Goal:
ให้ระบบ Work Center สามารถ “เลือก Behavior” ได้แต่ไม่เปลี่ยน logic backend ใด ๆ

แบบปลอดภัย ไม่แตะ DAG, Token, Time Engine ทั้งหมด

⸻

✔️ SCOPE (ทำอะไรบ้าง)

1. API: เพิ่ม action ใหม่ใน source/work_centers.php
	•	เพิ่มให้ครบ 3 actions:
	•	get_behavior_list → ดึงรายการ behavior ทั้งหมด
	•	bind_behavior → Save mapping (insert/update)
	•	unbind_behavior → ลบ mapping

2. UI: เพิ่ม Panel Behavior Mapping ในหน้า Work Centers
	•	เพิ่ม <select> ให้เลือก Behavior (CUT, EDGE, STITCH, QC_FINAL…)
	•	ถ้ามี override_settings ใน map → แสดง badge “Override”
	•	ถ้าไม่มี mapping → แสดง —
	•	เพิ่มปุ่ม “Remove Behavior” ถ้ามี mapping

3. ไม่กระทบระบบเก่า
	•	ไม่แตะ Token Engine
	•	ไม่แตะ Time Engine
	•	ไม่แตะ Routing Logic (DAG)
	•	ไม่แตะ Work Queue / PWA / QC

ใช้งานได้ทันที โดยไม่ต้อง refactor อะไรเดิมเลย

⸻

✨ DELIVERABLES (ไฟล์ที่ต้องถูกสร้าง/แก้)

A. Files to CREATE
	1.	docs/super_dag/task2_results.md
	•	ผลการทดสอบ + screenshots
	•	API response samples
	2.	assets/js/work_centers_behavior.js
	•	1 file แยกสำหรับ UI dropdown + AJAX mapping

⸻

B. Files to UPDATE
	1.	source/work_centers.php
	•	เพิ่ม 3 actions:

action=get_behavior_list
action=bind_behavior
action=unbind_behavior


	•	ใช้ WorkCenterBehaviorRepository อ่าน behavior

	2.	views/work_centers.php
	•	เพิ่ม column “Behavior”
	•	เพิ่ม modal เลือก behavior
	•	Load script work_centers_behavior.js
	3.	docs/super_dag/task_index.md
	•	Mark Task 2 as COMPLETED หลังทำเสร็จ

⸻

🔧 TECH SPECS (สำหรับ AI Agent)

1. API: get_behavior_list

URL

source/work_centers.php?action=get_behavior_list

Output

{
  "ok": true,
  "behaviors": [
    { "code": "CUT", "name": "Cutting" },
    { "code": "EDGE", "name": "Edge Paint" },
    ...
  ]
}


⸻

2. API: bind_behavior

URL

POST source/work_centers.php?action=bind_behavior

Input JSON

{
  "id_work_center": 3,
  "behavior_code": "CUT"
}

Success

{ "ok": true }


⸻

3. API: unbind_behavior

URL

POST source/work_centers.php?action=unbind_behavior

Input JSON

{
  "id_work_center": 3
}

Success

{ "ok": true }


⸻

🎨 UI REQUIREMENTS

Column Behavior

ใน DataTables เพิ่มคอลัมน์ใหม่:

Work Center	Behavior	Tools
CUT 01	CUT	Change
EDGE 01	EDGE	Change
STITCH 03	—	Set

Modal

Select behavior:
[ CUT | EDGE | STITCH | ... ]
[ Save ] [ Cancel ]

JS Behavior (work_centers_behavior.js)
	•	โหลดรายชื่อ behavior → populate dropdown
	•	ส่ง AJAX bind / unbind
	•	Reload datatable เมื่อสำเร็จ

⸻

🧪 TEST PLAN (AI Agent ต้องสร้างใน task2_results.md)

Test Case 1 — Load behavior list
	•	Call action=get_behavior_list
	•	Expect 6 preset behaviors

Test Case 2 — Bind behavior
	•	Bind CUT ให้ work_center ID = 1
	•	ตรวจ DB table work_center_behavior_map ว่ามี row ใหม่

Test Case 3 — Unbind behavior
	•	Unbind → DB ต้องลบ mapping

Test Case 4 — UI smoke test
	•	Dropdown แสดงรายการถูกต้อง
	•	Binding แล้ว reload UI เห็น behavior code

⸻

🚫 NON-GOALS (ห้ามทำใน Task นี้)

❌ ห้ามแก้ Work Queue
❌ ห้ามแก้ Time Engine
❌ ห้ามแก้ Token Engine
❌ ห้ามบังคับ UI ใหม่ใน execution
❌ ห้ามเพิ่ม logic ให้ behavior impact ระบบอื่น
❌ ห้ามแก้ DAG Designer

⸻

⚙️ STEP-BY-STEP (สำหรับ AI Agent)
	1.	สร้างไฟล์ assets/js/work_centers_behavior.js
	2.	แก้ work_centers.php เพิ่ม 3 actions
	3.	แก้หน้า views/work_centers.php ให้มี modal + column behavior
	4.	เพิ่ม scripts ในหน้าให้ load js ใหม่
	5.	สร้าง file docs/super_dag/task2_results.md
	6.	Update docs/super_dag/task_index.md

⸻

🏁 DEFINITION OF DONE
	•	UI Work Center เลือก behavior ได้
	•	Mapping ถูก save ใน DB
	•	Mapping ถูกแสดงใน DataTables
	•	Unbind ทำงานได้
	•	API ใช้งานได้
	•	Documents & Screenshots พร้อมใน task2_results.md
	•	ระบบอื่นทั้งหมดยังทำงานได้ตามเดิม
