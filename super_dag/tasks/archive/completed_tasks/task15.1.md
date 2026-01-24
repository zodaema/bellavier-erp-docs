task15.1.md — Add PRESS Work Center & PRESS Behaviors

Status: NEW
Category: Core Work Center & Behavior Expansion
Depends on:
	•	Task 14.x (UOM → Work Center refactor)
	•	Task 15.x (Work Center system defaults & lock rules)
	•	Task 16 (Behavior → Execution Mode Binding)
	•	Task 17 (Parallel Engine, unaffected but must not break)

⸻

🎯 Objective

เพิ่ม Work Center ใหม่ PRESS และ Behavior ประเภท PRESS ให้เป็น system default
เพื่อรองรับขั้นตอน:
	•	Hot Stamp
	•	Foil Press
	•	Emboss
	•	Logo Press

สิ่งเหล่านี้เป็น Core Capabilities ของ Luxury Leather Workflow และต้องถูกล็อกในระบบ (is_system = 1, locked = 1)

Task นี้มีหน้าที่:
	1.	เพิ่ม PRESS ลงใน work_center (ผ่าน migration + seed)
	2.	เพิ่ม behavior ประเภท PRESS (ผ่าน seed)
	3.	เพิ่ม mapping ระหว่าง Work Center → Behavior
	4.	รองรับ Execution Mode (ตาม Task 16)

⸻

📦 Deliverables

1. Migration File

สร้างไฟล์ migration:

database/tenant_migrations/2025_12_15_01_add_press_work_center.php

สิ่งที่ migration ต้องทำ:

1.1 เพิ่ม Work Center ถ้ายังไม่มี

ตารางจริงคือ work_center (ยืนยันแล้วจากระบบคุณ)

เพิ่ม row:

column	value
work_center_code	PRESS
name	Logo Press / Hot Stamp
description	Press Logo / Foil / Emboss operations
is_system	1
is_active	1
locked	1

ใช้ฟังก์ชันจำพวก:

migration_insert_if_not_exists(...)

ห้าม insert ตรง ๆ ต้อง idempotent

⸻

2. Seed Update — 0002_seed_data.php

ให้แก้ไขไฟล์ seed:

database/tenant_migrations/0002_seed_data.php

เพิ่ม Behavior ใหม่ทั้งหมด:

behavior_code	description	is_system	default_execution_mode
EMBOSS	Logo / Foil / Emboss hot stamping	1	HAT_SINGLE

หมายเหตุ:
ถ้าระบบของคุณมี behavior PRESS อยู่ก่อนแล้ว ให้ Agent discover ก่อน แล้วค่อย update ไม่ใช่ create ใหม่ซ้ำซ้อน

Mapping: Work Center → Behavior

ในตาราง mapping จริงคือ work_center_behavior_map (หรือชื่อเทียบเท่า ต้อง discover ให้ชัดก่อนเขียน)

ให้เพิ่ม mapping:

work_center_code	behavior_code
PRESS	EMBOSS

กฎสำคัญ:
	•	row เหล่านี้เป็น system rows → ใส่ is_system = 1 ถ้ามี column ดังกล่าว
	•	ห้ามลบห้ามแก้ไขใน UI (ตามกติกา Task 15.x)
	•	ใช้ migration_insert_if_not_exists
	•	ต้อง idempotent 100% ทุก tenant

⸻

3. Execution Mode Binding (Task 16 Compatibility)

ทุก Behavior TYPE PRESS ต้องผูก mode:
	•	HAT_SINGLE
(งานปั๊มโลโก้ใน luxury leather ต้อง single precision สูง)

ใน seed ต้องเพิ่ม:

behavior_code: EMBOSS → execution_mode: HAT_SINGLE

ห้ามให้ Agent เดา mode
ห้าม set เป็น BATCH เว้นแต่คุณสั่งเอง

⸻

4. Update Documentation

สร้าง:

docs/super_dag/tasks/task15_1_results.md

ให้สรุปสิ่งที่ทำ:
	•	Work Center PRESS was added
	•	EMBOSS behavior seeded and system-locked (unified behavior for Logo / Foil / Emboss)
	•	Default execution mode is HAT_SINGLE
	•	Work Center → Behavior mapping added
	•	All seeds processed into 0002_seed_data.php
	•	Ready for Task 18 machine binding

⸻

✅ Summary

Task 15.1 ทำให้ระบบ ERP ของคุณมี “PRESS Work Center” แบบ system-level:
	•	ถูกล็อก ไม่ถูกแก้ไขหรือลบจาก tenant
	•	มี behavior PRESS ครบทุกประเภทที่โรงงานต้องการ
	•	ผูกกับ execution mode (Task 16)
	•	พร้อมรองรับ Machine Binding (Task 18)

หลังทำ Task 15.1 แล้ว Work Center ทั้งหมดของระบบจะเป็นดังนี้:

code	is_system	purpose
CUT	1	Cutting
SKIVE	1	Skiving
EDGE	1	Edge paint
PRESS	1	Logo press / emboss
STITCH	1	Stitching
QC_INITIAL	1	QC
QC_FINAL	1	QC
PACK	1	Packaging


⸻