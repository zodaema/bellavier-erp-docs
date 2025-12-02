# Task 6 – Batch C Tenant API Migration (dag_token_api.php – CRITICAL)

**Type:** High-risk Refactor / Migration  
**File Focus:** `source/dag_token_api.php`  
**Goal:** ย้าย `dag_token_api.php` ไปใช้ `TenantApiBootstrap::init()` + `DatabaseHelper` เต็มรูปแบบ โดย **ไม่เปลี่ยน business logic / JSON shape / app_code** และไม่ทำให้ invariants ของ DAG token พัง

---

## 1. Context & Constraints

- ไฟล์: `source/dag_token_api.php`
- ขนาด: ~3,300+ บรรทัด
- ความเสี่ยง: 🔴 **CRITICAL**
- ความสำคัญ: เป็นหัวใจของระบบ Hatthasilpa DAG Token Engine

**สถานะปัจจุบัน (จาก discovery report):**

- ยังใช้ pattern เก่า:
  - `resolve_current_org()`
  - `tenant_db($org['code'])`
  - `new DatabaseHelper($tenantDb)`
  - custom header + `json_error()`
- ใช้ `use BGERP\` แล้ว → PSR-4 ready
- มี business logic ซับซ้อนเกี่ยวกับ:
  - token status transitions (`ready`, `active`, `paused`, `completed`, `cancelled`, etc.)
  - assignment / operator / team
  - rework / QC / routing / WIP invariants

**ข้อสำคัญ:**  
Task 6 = “ย้าย core setup + DB access” เท่านั้น  
**ห้าม** ปรับแก้ business rule, SQL condition, หรือ structure ของ response JSON เว้นแต่จำเป็นจริง ๆ เพื่อความถูกต้อง

---

## 2. Scope

### 2.1 In Scope

1. การเปลี่ยน “core setup” ให้ใช้:

   ```php
   use BGERP\Bootstrap\TenantApiBootstrap;

   [$org, $db] = TenantApiBootstrap::init(); // $db = DatabaseHelper

	2.	การลบ / ย้าย / เปลี่ยน usages ของ:
	•	resolve_current_org()
	•	tenant_db()
	•	new DatabaseHelper(...)
	•	new mysqli(...)
	•	$tenantDb / $conn / $mysqli ที่ยังเหลือในไฟล์
	3.	การจัดการ DB ให้เหลือแค่:
	•	$db = DatabaseHelper
	•	$db->getTenantDb() = mysqli (ถ้าจำเป็นจริง ๆ)
	4.	อัพเดต tests/bootstrap/ApiBootstrapSmokeTest.php เพื่อให้:
	•	ตรวจจับ dag_token_api.php ในรายการ migrated files
	•	ตรวจ legacy patterns ในไฟล์นี้

2.2 Out of Scope (ห้ามยุ่ง)
	•	ห้ามเปลี่ยน business logic เช่น:
	•	เงื่อนไขเปลี่ยนสถานะ token
	•	validation / guard rails
	•	pumping logic / multi-step state transitions
	•	ห้ามเปลี่ยน JSON structure / keys / app_code
	•	ห้ามเปลี่ยน semantics ของ error mapping
	•	ห้าม restructure file ทั้งก้อน (เช่น แยก class / move function ออกไปไฟล์อื่น) ใน Task นี้

⸻

3. Migration Strategy (ทีละชั้น)

Step 1 – วิเคราะห์โครงสร้างไฟล์
	1.	หา “core setup block” ด้านบนไฟล์:
	•	session_start()
	•	require_once ...
	•	resolve_current_org()
	•	tenant_db()
	•	new DatabaseHelper(...)
	•	header ที่เกี่ยวกับ JSON / CORS
	2.	แยกส่วนหลัก ๆ ของไฟล์:
	•	Request routing (อ่าน $_REQUEST['action'] / $_POST['action'] ฯลฯ)
	•	Handler functions สำหรับแต่ละ action (start_token, pause_token, complete_token, ฯลฯ)
	•	Helper functions (เช่น validation, serialization, logging)
	•	Low-level DB utilities

อย่า refactor โครงสร้างไฟล์ แค่ทำความเข้าใจ layout ให้ชัดก่อน

⸻

Step 2 – ผูกกับ TenantApiBootstrap
	1.	ด้านบนไฟล์ ให้ import:

use BGERP\Bootstrap\TenantApiBootstrap;
use BGERP\Helper\DatabaseHelper; // ถ้ายังไม่ได้ import


	2.	แทนที่ core setup เดิม ด้วย:

[$org, $db] = TenantApiBootstrap::init(); // $db = DatabaseHelper


	3.	ถ้าไฟล์นี้ต้องใช้ mysqli โดยตรง (เช่นเคยใช้ $tenantDb):

$tenantDb = $db->getTenantDb(); // mysqli


	4.	ลบ/ปิดการใช้:
	•	resolve_current_org() ภายในไฟล์นี้
	•	tenant_db($org['code'])
	•	new DatabaseHelper(...)
	•	new mysqli(...)

เงื่อนไข:
ถ้า core_db() ยังใช้ในบางส่วน (เช่น logs, core tables) ให้เก็บ core_db() ไว้ได้ ไม่เกี่ยวกับ TenantApiBootstrap

⸻

Step 3 – Normalize ตัวแปร DB ใน Handler

เป้าหมาย: หลัง migration เสร็จ:
	•	Handler ระดับบนใช้ $db (DatabaseHelper)
	•	ถ้า helper ยังใช้ mysqli → ให้เรียกผ่าน $db->getTenantDb()

รูปแบบเป้าหมายที่แนะนำ
	1.	สำหรับ handler ใหม่ หรือที่แก้ไข:

function handleStartToken(DatabaseHelper $db, array $member, array $org): void {
    $mysqli = $db->getTenantDb(); // ถ้ายังต้องใช้ mysqli เดิมภายใน
    // ... business logic เดิม ...
}

ใน router:

case 'start':
    handleStartToken($db, $member, $org);
    break;


	2.	สำหรับ helper ที่เคยรับ mysqli:

// เดิม:
function loadTokenDetails(mysqli $db, int $tokenId): array { ... }

// เปลี่ยนได้ 2 แบบ (เลือกแบบใดแบบหนึ่ง):

// แบบ A (ระยะเปลี่ยนผ่าน – ใช้ mysqli ต่อ)
function loadTokenDetails(mysqli $db, int $tokenId): array {
    // ... ใช้ $db->prepare() เหมือนเดิม ...
}

// แล้วให้ caller ส่ง $db->getTenantDb() เข้าไป:
$token = loadTokenDetails($db->getTenantDb(), $tokenId);

// แบบ B (ระยะยาว)
function loadTokenDetails(DatabaseHelper $db, int $tokenId): array {
    $mysqli = $db->getTenantDb();
    // ... logic เดิม ...
}



ใน Task6 นี้ให้เน้น แบบ A ก่อน (คง signature เดิม ใช้ mysqli ต่อ) เพื่อลดความเสี่ยง
แต่ให้ binding กับ $dbHelper ผ่าน $db->getTenantDb() ในจุดเรียก

⸻

Step 4 – ล้าง legacy patterns ภายในไฟล์

ให้ค้นหา pattern ต่อไปนี้ใน dag_token_api.php และจัดการ:
	1.	resolve_current_org(
	•	ต้องไม่มีเหลือใน file
	2.	tenant_db(
	•	ต้องไม่มีเหลือ
	3.	new DatabaseHelper(
	•	ห้ามสร้าง DatabaseHelper ใหม่เองในไฟล์นี้
ต้องใช้ $db จาก TenantApiBootstrap::init() อย่างเดียว
	4.	new mysqli(
	•	ห้ามมี (ยกเว้นใน library/utility แยกต่างหากจริง ๆ ซึ่งไม่ควรอยู่ในไฟล์นี้)
	5.	$mysqli->query(, $conn->query( ฯลฯ
	•	ถ้ายังจำเป็นต้องใช้:
	•	ให้แน่ใจว่ามาจาก $db->getTenantDb()
	•	ห้ามใช้ connection ตัวอื่นนอกจากจาก $db->getTenantDb()

⸻

Step 5 – Headers, JSON, Error Handling
	1.	ถ้าไฟล์กำหนด Content-Type: application/json ซ้ำกับ json_success/json_error:
	•	ให้ใช้ pattern เดิมที่ระบบใช้ (อ้างอิงจากไฟล์ที่ migrate แล้ว เช่น assignment_api.php)
	•	ถ้า json_success/json_error จัดการ header ให้แล้ว → ไม่จำเป็นต้องตั้งซ้ำ แต่ ห้ามเปลี่ยน behavior เดิม ถ้าไม่แน่ใจ
	2.	อย่าลบหรือเปลี่ยน:
	•	app_code
	•	HTTP status
	•	รูปแบบ response JSON
	•	การ map error code → message → app_code

⸻

4. Guardrails (สิ่งที่ห้ามทำเด็ดขาด)
	1.	❌ ห้ามเปลี่ยน business logic:
	•	ห้ามเปลี่ยน SQL WHERE, JOIN, ORDER BY
	•	ห้ามเพิ่ม/ลดเงื่อนไข state machine ของ token
	•	ห้ามเปลี่ยนค่า status, flag, หรือ serialized output
	2.	❌ ห้าม restructure file ระดับใหญ่:
	•	ห้ามย้าย handler ออกไฟล์ใหม่
	•	ห้าม split class/namespace ใหม่ใน Task นี้
	3.	❌ ห้ามเปลี่ยน signature ของฟังก์ชันที่ถูกใช้หลายที่ ถ้าไม่จำเป็น
	•	ถ้าจำเป็นต้องเปลี่ยน signature:
	•	ต้องแก้ call sites ทุกที่
	•	ต้องแน่ใจว่า type/behavior เหมือนเดิม
	4.	❌ ห้ามเปลี่ยน app_code หรือ key JSON ที่ frontend/ระบบอื่น rely อยู่

⸻

5. Testing Plan

5.1 Syntax & Static Checks
	1.	ตรวจ syntax ของไฟล์:

php -l source/dag_token_api.php


	2.	รัน ApiBootstrapSmokeTest (ต้องเพิ่ม dag_token_api.php เข้า $migratedFiles ใน test นี้ด้วย):

php tests/bootstrap/ApiBootstrapSmokeTest.php

ตรวจว่า:
	•	เจอว่า dag_token_api.php ใช้ TenantApiBootstrap::init()
	•	ไม่มี resolve_current_org, tenant_db, new DatabaseHelper, new mysqli
	•	ถ้ามี warning เรื่อง $mysqli->query() ให้ตรวจว่า $mysqli มาจาก $db->getTenantDb() เท่านั้น

5.2 PHPUnit Tests (ที่มีอยู่แล้ว)

อย่างน้อยต้องรัน:

vendor/bin/phpunit tests/Unit/SerialHealthServiceTest.php --testdox
vendor/bin/phpunit tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php --testdox

เพื่อแน่ใจว่า:
	•	SerialHealthService ยังทำงานได้
	•	Enforcement Stage 2 (ที่อิงกับ dag_token_api flow) ยังผ่านเหมือนเดิม

5.3 Manual Test (ถ้ามี UI)
	•	ใช้หน้า UI ที่เรียก dag_token_api.php เช่น work_queue / manager_assignment / claim flow ที่เกี่ยวข้อง
	•	ทดสอบ action สำคัญ:
	•	start token
	•	pause token
	•	resume / complete
	•	rework-related actions
	•	ตรวจว่า behavior จากมุมมองผู้ใช้ “ไม่เปลี่ยนไป” จากก่อน migrate

⸻

6. Success Criteria

Task 6 ถือว่าสำเร็จเมื่อ:
	1.	source/dag_token_api.php:
	•	ใช้ TenantApiBootstrap::init() และรับ $org, $db (DatabaseHelper)
	•	ไม่มี resolve_current_org(), tenant_db(), new DatabaseHelper(), new mysqli() ในไฟล์
	•	ถ้ามี $mysqli ต้องมาจาก $db->getTenantDb() เท่านั้น
	2.	tests/bootstrap/ApiBootstrapSmokeTest.php:
	•	รวม dag_token_api.php ใน $migratedFiles
	•	ผ่านทุก test (ไม่มี legacy pattern รุนแรงหลุดรอด)
	3.	PHPUnit:
	•	SerialHealthServiceTest และ HatthasilpaE2E_SerialEnforcementStage2Test ผ่านเหมือนเดิม
	4.	Manual smoke:
	•	Action หลักของ dag token (start/pause/resume/complete/rework) ทำงานตามปกติจาก UI

⸻

7. Notes for Future Tasks
	•	Task 7: ทำ “API Standardization” รอบสุดท้าย:
	•	เปลี่ยน handler ทั้งหมดให้รับ DatabaseHelper (ไม่รับ mysqli)
	•	ลด/ลบการใช้ $db->getTenantDb() ใน business layer ให้มากที่สุด
	•	Standardize pagination, filtering, response format
	•	Task 8: เพิ่ม integration tests เพิ่มเติมสำหรับ dag_token_api actions แต่ละตัว
	•	test path: happy, error, edge cases

---