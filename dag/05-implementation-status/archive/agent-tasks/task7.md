✅ TASK 7 – Node Plan Auto-Assignment Integration

Goal

ให้ระบบสามารถ “สร้าง token_assignment โดยอัตโนมัติ” จาก node_plan หรือ manager_assignment อย่างถูกต้อง ปลอดภัย ไม่ override สิ่งที่มีอยู่แล้ว และผ่านทุกรูปแบบ flow ของระบบ Hatthasilpa.

⸻

🎯 Task 7 Objectives

1. Node Plan → Token Assignment (AUTO MODE)

เมื่อระบบ spawn token หรือ assignOne() ทำงาน:
	•	ถ้า manager assignment ไม่มี
	•	และ job_plan ไม่มี
	•	แต่ node_plan มี candidate คนเดียว
	•	→ สร้าง token_assignment ให้โดยอัตโนมัติ

Rules
	•	ต้องเป็น assignee เดียว เท่านั้น (หลากหลายคนห้าม assign อัตโนมัติ)
	•	ใช้ assignment_method = 'node_plan' (ถ้ามี column นี้)
	•	status = 'assigned'
	•	assigned_by_user_id = NULL หรือ system (ตาม policy)
	•	ต้อง idempotent: เรียกซ้ำแล้วไม่สร้างซ้ำ

⸻

2. Existing assignment → DO NOT OVERRIDE

ตาม Test7.2:
	•	ถ้ามีแถวใน token_assignment อยู่แล้ว:
	•	status = assigned / accepted / started / paused
	•	→ ห้ามแตะต้อง assignment เดิม
	•	→ ห้าม override assigned_to_user_id ตาม node_plan

⸻

3. Manager assignment still highest priority

Priority order ใหม่ต้องเป็น:

manager_assignment → job_plan → node_plan → auto_assign_policy

System ต้อง log แบบนี้:

[AssignmentEngine] Node plan candidate accepted: user 13
[AssignmentEngine] Assignment created via node_plan


⸻

4. Must Pass Task 7 Tests

คุณต้องเตรียม test ใหม่ 3 อัน (จะให้โค้ดให้ด้านล่าง):
	1.	testNodePlanAssignmentCreated()
	2.	testNodePlanAssignmentNotOverrideExisting()
	3.	testNodePlanAssignmentIdempotent()

ทั้งหมดต้องผ่านใน tenant maison_atelier.

⸻

5. Feature Flag (mandatory)

เพื่อความปลอดภัย ต้องควบคุมด้วย FF:

FF_HAT_NODE_PLAN_AUTO_ASSIGN

	•	default = 0
	•	เปิดสำหรับ maison_atelier เท่านั้น

ถ้า FF ปิด → ยังไม่สร้าง assignment จริง

การเช็คค่า FF_HAT_NODE_PLAN_AUTO_ASSIGN:
	• ต้องเรียกผ่าน `FeatureFlagService` เดิมที่ใช้อยู่ในระบบ (เช่น แบบเดียวกับ FF_SERIAL_STD_HAT)
	• ห้ามเพิ่มกลไก feature flag แบบใหม่ หรืออ่านค่าจาก config/constant ตรง ๆ
	• ห้ามแก้ไข schema ของตาราง feature_flag_catalog หรือ feature_flag_tenant

⸻

6. Add 3 new tests (in the existing integration test file ONLY):
   - `testNodePlanAssignmentCreated`
   - `testNodePlanAssignmentNotOverrideExisting`
   - `testNodePlanAssignmentIdempotent`
   
   All 3 tests must be implemented inside:
   - `tests/Integration/HatthasilpaAssignmentIntegrationTest.php`
   
   Do NOT:
   - create new test files,
   - rename the existing file,
   - or move existing tests.

⸻

7. Implement ใน AssignmentEngine.php

Agent ต้องแก้ไฟล์:

source/BGERP/Service/AssignmentEngine.php

โดยเพิ่ม helper ต่อไปนี้:

private static function applyNodePlanAssignment($tenantDb, $tokenId, $nodeId, $assigneeUserId)

Behavior:
	•	ถ้าไม่มี row → INSERT
	•	ถ้ามี row → return (ไม่แตะ)
	•	ถ้ามี >1 row → choose first active (fail-open)

ใช้ transaction guard เพื่อ safety

⸻

🧪 Acceptance Criteria

ผ่านเมื่อ:

✔ Node plan ที่มี candidate เดียว สร้าง token_assignment สำเร็จ
✔ Manager assignment ไม่ถูก override
✔ เรียกซ้ำไม่สร้าง duplicate assignment
✔ รองรับ fail-open schema
✔ ไม่แตะตารางอื่น
✔ ไม่แก้ signature ของฟังก์ชันเดิม
✔ ผ่าน test suite ทั้งหมดก่อนหน้า
✔ ผ่าน Task7 test suite

⸻

IMPORTANT (STRICT CONSTRAINTS – DO NOT VIOLATE):

- Follow existing code style / naming.
- **Do NOT rewrite or refactor the entire class.**
- **Do NOT change the structure of `assignOne()`**:
  - ❌ ห้ามย้าย code block เดิม
  - ❌ ห้ามรวม logic manager/job/node plan เข้าด้วยกัน
  - ❌ ห้ามเปลี่ยน signature ของฟังก์ชันเดิม
  - ✔ ให้เพิ่ม code เฉพาะ “ใต้จุดที่ node_plan คืน candidates หลัง filter แล้ว” เท่านั้น
- ทุก code block ใหม่ที่เกี่ยวกับงานนี้ต้องขึ้นต้นด้วยคอมเมนต์:
  - `// TASK7 - Node Plan Auto-Assignment (DO NOT MOVE THIS BLOCK)`
- **Tests:**
  - ต้องเพิ่ม tests ใหม่ทั้งหมดในไฟล์ที่มีอยู่แล้ว:
    - `tests/Integration/HatthasilpaAssignmentIntegrationTest.php`
  - ห้ามสร้างไฟล์ test ใหม่, ห้ามเปลี่ยนชื่อไฟล์เดิม, ห้ามย้าย test ที่มีอยู่แล้ว
  - เพิ่ม test ใหม่ไว้ท้ายไฟล์เท่านั้น
- **Feature Flag:**
  - ต้องใช้ `FeatureFlagService` ที่มีอยู่แล้วในระบบเท่านั้น เมื่อเช็ค `FF_HAT_NODE_PLAN_AUTO_ASSIGN`
  - ห้ามสร้างกลไกเช็ค flag แบบใหม่, ห้ามอ่านค่าจาก config หรือ constant โดยตรง
- **Database & Transactions:**
  - ห้ามเพิ่มหรือแก้ไข schema ฐานข้อมูลใด ๆ (ห้าม ALTER TABLE)
  - ถ้า column `assignment_method` ไม่มี ให้ข้ามการเขียนค่า column นี้ (ไม่ต้องสร้าง schema ใหม่)
  - ห้ามเพิ่ม `BEGIN`, `COMMIT`, หรือ transaction block ใหม่ใน `applyNodePlanAssignment()` หรือส่วนอื่น
- ทุก snippet ที่อยู่ในเอกสารนี้เป็น **EXAMPLE เท่านั้น**
  - ห้าม copy/paste ตรง ๆ โดยไม่ตรวจสอบโครงสร้างไฟล์จริง
  - ต้องอ่านไฟล์จริง วิเคราะห์ context จริง และปรับโค้ดให้เข้ากับโครงสร้างที่มีอยู่ก่อนเสมอ
