Task 19.21 — Stability Regression & Post-Helper Normalization Pass

สถานะปัจจุบันก่อนเริ่ม Task

หลังจาก Task 19.20:
	•	GraphHelper ถูกนำมาใช้เป็น single source of truth
	•	Duplicate logic ถูกลบออกจาก engines ทั้งหมด
	•	Tests:
	•	AutoFixPipelineTest: PASS 15/15
	•	SemanticSnapshotTest: UPDATED (ผ่านเมื่อ run –update)
	•	ValidateGraphTest: 7 ผ่าน / 8 ตก

ข้อสังเกตสำคัญ:
ValidateGraphTest ที่ fail ไม่ใช่ Fatal error แต่เป็น “semantic mismatch” ระหว่าง validation rules ใหม่และ expected results เก่าจาก Task 18.x → 19.x (ก่อน Semantic Layer + Reachability Analyzer + Intent Rules)

ดังนั้น 19.21 ไม่ใช่งานแก้บัค แต่เป็นงาน จูน engine ให้เข้าที่หลังการ Lean-Up เพื่อสร้าง “Stability Baseline” ก่อนเริ่ม Phase 20 (ETA Engine)

⸻

เป้าหมายของ Task 19.21

ยืนยันและทำ normalization รอบใหญ่เพื่อให้ระบบ validation เสถียร 100% โดยเฉพาะ:
	1.	แก้ความไม่สอดคล้องของ Test Expectations
	2.	Normalize error severity (error/warning)
	3.	Normalize intent detection consistency
	4.	Normalize dead-end and unreachable rule ordering
	5.	Review conflict precedence rules
	6.	Re-align snapshot semantics กับ engine version หลัง Lean-Up

⸻

Deliverables

1. Validation Severity Normalization Map

ไฟล์ใหม่:

docs/super_dag/validation/validation_severity_matrix.md

สรุป:
	•	สำหรับทุก rule ใน GraphValidationEngine
	•	ควรเป็น Error หรือ Warning?
	•	ควรมี suggestion หรือไม่?
	•	ควรตรวจจับในระดับ semantic หรือ structural?

Output นี้เป็น baseline ที่ ValidateGraphTest จะ sync ด้วย

⸻

2. Validation Ordering Specification

ไฟล์ใหม่:

docs/super_dag/validation/validation_rule_ordering.md

ระบุลำดับการตรวจแบบ deterministic:
	1.	Structural Fatal (duplicate IDs, missing START)
	2.	Reachability (unreachable, cycles)
	3.	Endpoint rules
	4.	Parallel rules
	5.	QC rules
	6.	Semantic conflicts
	7.	Warnings / Soft errors

สิ่งนี้แก้ปัญหา test randomness เช่น order ของ errors ต่างกันในบาง test

⸻

3. Normalize Intent Detection Output

อัปเดต:

source/BGERP/Dag/SemanticIntentEngine.php

ให้แน่ใจว่า:
	•	Intent ถูก detect ตาม priority:
	1.	endpoint.*
	2.	parallel.*
	3.	qc.*
	4.	linear.*
	•	Intent conflicts ถูก filter ตาม rules ใหม่ใน Task 19.17
	•	Output mapping สม่ำเสมอ (sort alphabetically)

⸻

4. Update ValidateGraphTest Expected Results

ไฟล์ที่ต้องอัปเดต:

tests/super_dag/fixtures/validate/*.json
tests/super_dag/ValidateGraphTest.php

เนื่องจาก:
	•	หลัง Lean-Up validation rules เปลี่ยนแปลง (ถูกต้องขึ้น)
	•	Test เก่าบางตัว expect พฤติกรรมที่ผิดจาก viewpoint ใหม่ (19.x)

⸻

5. Full Re-run & Snapshot Refresh

หลัง normalization:

php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php --update
php tests/super_dag/AutoFixPipelineTest.php

เป้าหมาย:
All Tests Passed

⸻

Acceptance Criteria

รายการ	ต้องทำให้ได้
ValidateGraphTest ผ่าน ≥ 14/15	✔
AutoFixPipelineTest ผ่าน 15/15	✔
SemanticSnapshotTest ผ่าน (หลัง update)	✔
ไม่มี fatal errors	✔
Intent detection output คงที่ทุกครั้ง	✔
Error severity เป็นไปตาม severity map	✔
Rule ordering consistent	✔


⸻

ผลลัพธ์หลังทำ Task 19.21 (Expected)

Validation Layer:
	•	ไม่ฟ้อง error ผิดลักษณะอีกต่อไป
	•	ไม่มี ValidateGraphTest fail แบบ semantic mismatch
	•	การเรียง error/warning คงที่ทุกครั้ง (deterministic)
	•	Snapshot stable หลัง update

Codebase:
	•	Lean + Stable
	•	พร้อมเข้าสู่ Task 20 (ETA Engine)
	•	พร้อม Lean-Up phase (20.x)

⸻