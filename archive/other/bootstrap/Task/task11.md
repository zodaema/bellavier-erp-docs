Task 11 – Migrate Platform APIs to CoreApiBootstrap

Status: ✅ COMPLETED (2025-11-18)
Owner: AI Agent (Bellavier ERP Bootstrap Track)
Created: 2025-11-19
Depends On:
	•	✅ Task 10 – CoreApiBootstrap implemented & fully tested
	•	✅ Task 8 – Platform API audit
	•	✅ Task 9 – Bootstrap design

⸻

1. เป้าหมาย (Goal)

ทำการ migrate ไฟล์ Platform API (Core-level) ดังต่อไปนี้ให้ใช้:

list($member, $coreDb, $tenantDb, $org, $cid) = CoreApiBootstrap::init([...]);

โดย ไม่เปลี่ยน business logic ใด ๆ ในไฟล์เหล่านี้:
	•	admin_org.php
	•	admin_rbac.php
	•	member_login.php
	•	permission.php
	•	platform_dashboard_api.php
	•	platform_health_api.php
	•	platform_migration_api.php
	•	platform_serial_metrics_api.php
	•	bootstrap_migrations.php
	•	run_tenant_migrations.php

รวมทั้งหมด 10 ไฟล์

เป้าหมายคือ ทำให้ไฟล์ทุกตัวกลายเป็นมาตรฐานใหม่แบบเดียวกับ tenant APIs
แต่ ไม่กระทบ auth / session / permission behavior เดิม

⸻

2. Guardrails (สำคัญมาก)

❌ ห้ามเปลี่ยน logic ต่อไปนี้:
	1.	member login
	2.	permission_allow_code
	3.	must_allow_admin
	4.	is_platform_administrator
	5.	core_db
	6.	resolve_current_org
	7.	tenant_db

❌ ห้ามเปลี่ยนรูปแบบ response เดิม เช่น:
	•	บางไฟล์ใช้ echo json_encode(...)
	•	บางไฟล์ใช้ json_error()
	•	บางไฟล์ใช้ plain text
→ ต้องคงไว้เหมือนเดิม

❌ ห้ามเปลี่ยน field หรือชื่อ key ในผลลัพธ์

❌ ห้ามรวมไฟล์ / restructure code

⸻

3. Strategy (แผนภาพใหญ่วิธี migrate)

แบ่งออกเป็น 3 กลุ่ม:

⸻

Group A – ง่ายที่สุด (No Tenant)

ไม่มี tenant context, logic สั้น
	1.	platform_health_api.php
	2.	platform_dashboard_api.php

Bootstrap options:

CoreApiBootstrap::init([
    'requireAuth' => true,
    'jsonResponse' => true,
]);

Migration effort: ⭐ (ง่ายมาก)

⸻

Group B – ต้องการ Platform Admin

ต้องเช็ค platform admin
	3.	admin_org.php
	4.	admin_rbac.php
	5.	permission.php

Bootstrap options:

CoreApiBootstrap::init([
    'requireAuth' => true,
    'requirePlatformAdmin' => true,
]);

Migration effort: ⭐⭐⭐ (ระดับกลาง)

⸻

Group C – ใช้ Tenant + ใช้ CLI

ไฟล์ critical ที่ซับซ้อนที่สุด
	6.	platform_migration_api.php
	7.	platform_serial_metrics_api.php
	8.	bootstrap_migrations.php
	9.	run_tenant_migrations.php
	10.	member_login.php (special case เป็น auth engine)

Bootstrap options (dynamic):

CLI mode:

CoreApiBootstrap::init([
    'cliMode' => true,
]);

Web mode:

CoreApiBootstrap::init([
    'requireAuth' => true,
    'requirePlatformAdmin' => true,
    'requireTenant' => false,
]);

Migration effort: ⭐⭐⭐⭐⭐ (ไฟล์ที่หนักที่สุด)

⸻

4. Workflow แบบเดียวกับ Task 5/6/6.1

Step 1 – โคลน template from task6.1

สร้าง template สำหรับ patch file API

Step 2 – ทำทีละ batch
	•	Batch A → Health + Dashboard
	•	Batch B → Admin Org, RBAC, Permission
	•	Batch C → Migration / Serial Metrics / Bootstrap Migrations / run_tenant_migrations
	•	Special Case → member_login.php

Step 3 – Static Check
	•	php -l
	•	Smoke Test
	•	Unit test

Step 4 – Verification
	•	Response shape ไม่เปลี่ยน
	•	Behavior ไม่เปลี่ยน
	•	all exit paths preserved
	•	platform admin guard ไม่ถูกแตะ
	•	migration engine ไม่ถูกเปลี่ยน

Step 5 – Documentation Update
	•	tenant_api_bootstrap.discovery.md → เพิ่ม Task 11 section
	•	task11.md → เพิ่ม progress
	•	core_platform_bootstrap.design.md → update integration roadmap

⸻

5. Mapping ไฟล์ → Bootstrap Options

File	Require Auth	Require Platform Admin	Require Tenant	CLI Mode	Json Response	Note
platform_health_api.php	Yes	No	No	No	Yes	Simple
platform_dashboard_api.php	Yes	No	No	No	Yes	Simple
admin_org.php	Yes	Yes	No	No	Yes	Admin
admin_rbac.php	Yes	Yes	No	No	Yes	Admin
permission.php	Yes	Yes	No	No	Yes	Permission
platform_migration_api.php	Yes	Yes	Yes?	Yes sometimes	Yes	Complex
platform_serial_metrics_api.php	Yes	Yes	No	No	Yes	Heavy SQL
bootstrap_migrations.php	Yes?	Yes?	No	Yes	Plain	CLI/Plain mixed
run_tenant_migrations.php	Yes?	Yes?	Yes	Yes	Plain	Mixed
member_login.php	No	No	No	No	Plain	Do NOT break login


⸻

6. Deliverables

Task 11 ต้องประกอบด้วย:

1) Migration PR

ไฟล์ patch สำหรับทั้ง 10 ไฟล์

2) Unit test เสริม
	•	CoreApiBootstrap integration test
	•	Basic behavior test สำหรับ platform endpoints

3) Documentation
	•	task11.md
	•	tenant_api_bootstrap.discovery.md → update progress
	•	core_platform_bootstrap.design.md → add “phase: integration started”

4) Smoke Test
	•	อัปเดต ApiBootstrapSmokeTest ให้ตรวจทุกไฟล์ platform API

⸻

7. Checklist สำหรับ Agent
	•	Batch A (2 files)
	•	Batch B (3 files)
	•	Batch C (4 files)
	•	Special Case (member_login.php)
	•	Static Check
	•	Smoke Test update
	•	Unit Test update
	•	Documentation update
	•	Task11.md → COMPLETED

⸻

สรุป Task 11 (พร้อมเริ่มทำได้ทันที)

Task 11 จะทำให้ CoreApiBootstrap ถูก integrate ใช้งานจริง ซึ่งเป็น milestone ใหญ่ที่สุดก่อนเข้าสู่:
	•	Task 12: Platform API full modernization
	•	Task 13: Tenant + Platform consistency
	•	Task 14: Time Engine integration
	•	Task 15: DAG Execution Bootstrap
	•	Task 16+: ERP 2.0 Core Runtime