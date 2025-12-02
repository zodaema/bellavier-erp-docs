✅ Task3.md – Tenant API Migration (Batch A)

Safe Migration Phase — Low-risk APIs Only

Version: Ready for Cursor AI Agent
Goal: ย้าย API ชุดแรกให้ใช้ TenantApiBootstrap::init() โดยไม่แตะ business logic

⸻

1. Overview

ระบบปัจจุบันมี API จำนวนมากซึ่ง:
	•	เขียนคนละยุค
	•	resolve org / tenant ไม่เหมือนกัน
	•	ใช้ $db คนละความหมาย (mysqli vs DatabaseHelper)
	•	มี header/echo ก่อน JSON
	•	มี logic หลายพันบรรทัดปะปนกัน

เพื่อไม่ให้ระบบล่ม Task3 จึงเป็น Batch A — Low-risk migration only

⸻

2. Target APIs in Batch A

Batch A = ไฟล์ที่ “ปลอดภัยที่สุด” ตามผล Discovery:

Criteria:
	•	ไฟล์สั้นกว่า 300 บรรทัด
	•	ใช้ resolve_current_org() + tenant_db() แบบ predictable
	•	ไม่มีการ echo/print ก่อน JSON
	•	ไม่มีการสร้าง mysqli connection เอง
	•	ไม่มี session manipulation
	•	ไม่มี side-effects HTTP headers
	•	ใช้ json_error/json_success แบบตรงไปตรงมา

Agent ต้องค้นไฟล์จาก Discovery Report และเลือกเฉพาะไฟล์ที่ถูกจัดเป็น Batch A

ห้ามรวม dag_token_api.php หรือ hatthasilpa_operator_api.php ใน Batch นี้

⸻

3. Migration Strategy (Zero-risk)

Step 1 — ใส่ bootstrap

บนบรรทัดบนสุดของ API (หลังเปิด PHP):

use BGERP\Bootstrap\TenantApiBootstrap;

[$org, $db] = TenantApiBootstrap::init();

Step 2 — ลบบรรทัดเหล่านี้ออก (ถ้ามี)
	•	require_once '../../config.php';
	•	resolve_current_org();
	•	tenant_db(...);
	•	การสร้าง $db = new mysqli(...)
	•	manual header เช่น
header("Content-Type: application/json");

Step 3 — เก็บ $org และ $db แต่ “ห้าม” เปลี่ยน logic ใด ๆ

แม้พบว่าบางโค้ดแปลก (เช่น $db->execute / $conn->query)
ห้ามแตะต้อง
Agent ต้อง:
	•	ดูว่าตัวแปรใด “เกี่ยวข้องกับ tenant DB”
	•	แทนที่ตัวแปรนั้นด้วย $db->getMysqli() ถ้าจำเป็น

แต่ห้ามเปลี่ยน function call ใน logic หลักของ API

Step 4 — ป้องกันกรณี $db ถูกใช้ผิดแบบ

ห้ามแก้ business logic เช่น:

$db->query("SELECT ...");

ให้ยังคงเดิม แต่ถ้าต้องการ mysqli ให้:

$mysqli = $db->getMysqli();

ห้ามแก้ query หรือปรับ API return format ทั้งหมด

⸻

4. Guardrails (สำคัญมาก)

Agent ต้องปฏิบัติตามทุกข้อ:

4.1 ห้ามแก้ business logic ใด ๆ

เช่น:
	•	ห้ามแตะ SELECT / UPDATE / INSERT
	•	ห้ามแก้ error handling ภายใน API
	•	ห้ามเปลี่ยน response format

4.2 ห้าม optimize โค้ดเก่า

แม้ว่าพบ code smell เช่น nested if, copy-paste, หรือ dead code — ห้ามแก้
เราจะ refactor ภายหลังใน Task 5

4.3 ต้องตรวจหา Side-effects ก่อนแก้

ถ้าไฟล์มี:
	•	echo
	•	print
	•	var_dump
	•	debug output
	•	header ที่ไม่เกี่ยวกับ JSON

→ จัดไฟล์นั้นไป Batch C ทันที ห้าม migrate ใน Task นี้

4.4 ถ้าพบ mysqli ดิบ

เช่น:

$mysqli = new mysqli(...);

Agent ต้อง:
	•	ย้าย logic DB ดิบออก
	•	แทนด้วย $db->getMysqli()
	•	แต่ไม่เปลี่ยน SQL ใด ๆ

4.5 ห้าม import TenantApiBootstrap ซ้ำหลายครั้ง

ใช้รูปแบบนี้เท่านั้น:

use BGERP\Bootstrap\TenantApiBootstrap;


⸻

5. Expected Patch Example

ตัวอย่าง (simplified) ก่อน migration:

<?php
require_once '../../config.php';

$org = resolve_current_org();
$tenantDb = tenant_db($org['code']);
$db = new DatabaseHelper($tenantDb);

header('Content-Type: application/json');

$rows = $db->query("SELECT * FROM items");
json_success(['items' => $rows]);

หลัง migration:

<?php

use BGERP\Bootstrap\TenantApiBootstrap;

[$org, $db] = TenantApiBootstrap::init();

$rows = $db->query("SELECT * FROM items");
json_success(['items' => $rows]);

ความต่างคือ สั้นลง สะอาดขึ้น มาตรฐานเดียวกัน

⸻

6. Testing Strategy (Required)

Agent ต้องสร้าง tests ต่อไปนี้:

1) Syntax tests

php -l <file>

สำหรับ API ทุกไฟล์ที่ migrate

2) Minimal smoke tests

สร้าง test file:

tests/bootstrap/ApiBootstrapSmokeTest.php

เช็คว่า:
	•	TenantApiBootstrap::init() ทำงาน
	•	API ที่ migrate เรียก init() ได้
	•	JSON response ยังถูกต้อง

3) Health check

ตรวจว่า:
	•	ไม่มี header duplicate
	•	ไม่มี echo ก่อน JSON
	•	$db type ถูกต้อง

⸻

7. Success Criteria

Task 3 สำเร็จเมื่อ:
	1.	API ทั้งหมดใน Batch A ถูก migrate อย่างปลอดภัย
	2.	ไม่มี business logic แตก
	3.	ทุกไฟล์ผ่าน syntax check
	4.	Smoke test ทำงาน
	5.	ระบบยัง running ได้ตามเดิม
	6.	พร้อมเข้าสู่ Task 4 (Batch B)

⸻

8. Notes for Human Developers (Important)
	•	Batch A เป็น migration ที่ปลอดภัยและรวดเร็ว
	•	Batch B & C จะซับซ้อนมาก (up to 4000 lines/file)
	•	เตรียมเวลาไว้สำหรับทำ Test coverage
	•	TenantApiBootstrap จะเป็นหัวใจของระบบ ERP แบบ multi-tenant
	•	นี่เป็น roadmap ในระดับ “สร้างฐานรากของ ERP เพื่อรองรับการขยายอีก 10 ปี”

⸻

9. Next Step

หลัง Task 3 ให้ทำ:
	•	Task 4 — Migrate Batch B
	•	Task 5 — Migrate Batch C (ไฟล์ใหญ่ เช่น dag_token_api.php)
	•	Task 6 — ทำ Health Metrics + Error Tracking เข้า Bootstrap
	•	Task 7 — ทำ Versioning ระบบ tenant bootstrap
