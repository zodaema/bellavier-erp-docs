# Task 5 – Batch B Tenant API Migration (Medium-Risk APIs)

**Type:** Refactor / Migration  
**Goal:** ย้าย Tenant APIs กลุ่ม Batch B ไปใช้ `TenantApiBootstrap::init()` + DatabaseHelper ให้ครบ และล้าง legacy setup/query ให้จบ โดยไม่แตะ business logic

---

## 1. Scope

### 1.1 Target Files (Batch B Candidates)

จาก `tenant_api_bootstrap.discovery.md` ให้ถือว่า Batch B = APIs ต่อไปนี้ (อย่างน้อย):

1. `source/team_api.php`        – medium risk (duplicate org resolution + correlation id)
2. `source/token_management_api.php`
3. `source/trace_api.php`
4. `source/pwa_scan_api.php`
5. `source/dag_approval_api.php`
6. `source/hatthasilpa_jobs_api.php`
7. `source/hatthasilpa_job_ticket.php`
8. `source/exceptions_api.php`
9. `source/dashboard_api.php`
10. `source/tenant_users_api.php`
11. `source/mo.php`
12. `source/products.php`
13. `source/classic_api.php`
14. `source/people_api.php`

> หมายเหตุ: ถ้าใน discovery มีไฟล์อื่นที่ pattern เดียวกัน (resolve_current_org + tenant_db + DatabaseHelper + json_error/json_success) และไม่ใหญ่เกินไป ให้ Agent จัดเข้ากลุ่ม Batch B ได้เช่นกัน

### 1.2 Out of Scope (Batch C / Special)

ห้ามยุ่งใน Task นี้:

- `source/dag_token_api.php`            – CRITICAL / 3,000+ lines
- ไฟล์อื่นที่ถูก mark ว่า Batch C ใน discovery
- CLI scripts, non-tenant admin, view templates

---

## 2. Objectives

สำหรับทุกไฟล์ใน Batch B:

1. ใช้ `TenantApiBootstrap::init()` เพื่อ:
   - resolve org
   - open tenant DB
   - set timezone
   - ได้ `$org, $db (DatabaseHelper)`

2. ล้าง legacy setup:
   - `resolve_current_org()`
   - `tenant_db()`
   - `new DatabaseHelper(...)`
   - `new mysqli(...)` (ตรง ๆ)

3. ปรับ query ทั้งหมดให้ผ่าน:
   - `$db->fetchAll() / fetchOne() / execute()`  
   **หรือ**
   - `$db->getTenantDb()` แล้วใช้ mysqli (กรณีพิเศษ เช่น DDL, multi-query)

4. คง business logic, response format, error handling **เหมือนเดิมทุกอย่าง**

---

## 3. Migration Rules (ต่อไฟล์)

### 3.1 Insert Bootstrap

ด้านบนไฟล์ (หลัง `<?php` และ `use` block) ให้ใส่:

```php
use BGERP\Bootstrap\TenantApiBootstrap;

[$org, $db] = TenantApiBootstrap::init();

ถ้ามี code auth / permission / rate-limit ที่ต้องรัน “ก่อน” bootstrap (เช่น เช็ค login จาก core DB) ให้คงลำดับเดิม แล้วเรียก TenantApiBootstrap::init() หลังจาก auth ผ่านแล้วเท่านั้น

3.2 Remove Legacy Core Setup

ลบโค้ด pattern แบบนี้ออก (ถ้ามี):

$org = resolve_current_org();
if (!$org) {
    json_error('no_org', 403, [...]);
}

$tenantDb = tenant_db($org['code']);
$db = new DatabaseHelper($tenantDb);

// หรือ

$mysqli = new mysqli(...);

ห้ามเหลือ resolve_current_org() / tenant_db() / new DatabaseHelper() / new mysqli() ในไฟล์ที่ถือว่า “migrated แล้ว”

3.3 Normalize DB Access

สำหรับ query:

กรณี 1: ใช้ DatabaseHelper ได้ตรง ๆ
ถ้าโค้ดเดิมใช้ $db เป็น DatabaseHelper อยู่แล้ว เช่น:

$rows = $db->fetchAll("SELECT ...", $params);
json_success(['items' => $rows]);

เก็บไว้เหมือนเดิมได้เลย แค่ให้ $db มาจาก TenantApiBootstrap::init() แทน

กรณี 2: ใช้ mysqli ดิบ
เช่นเดิมมี:

$tenantDb = tenant_db($org['code']);
$result = $tenantDb->query("SELECT ...");

หรือ:

$mysqli = new mysqli(...);
$result = $mysqli->query("SELECT ...");

ให้ปรับเป็น:

[$org, $db] = TenantApiBootstrap::init();

$mysqli = $db->getTenantDb();
$result = $mysqli->query("SELECT ...");

// loop / fetch_assoc ตามเดิม

ห้ามเปลี่ยน SQL และห้ามเปลี่ยนรูปแบบของ $result / $rows

กรณี 3: DDL / complex SQL (ON DUPLICATE KEY, ALTER TABLE, SHOW INDEX)
ให้ใช้ mysqli ผ่าน $db->getTenantDb() แบบใน Task 4:

$mysqli = $db->getTenantDb();
$result = $mysqli->query("SHOW TABLES LIKE '...'");
// ...


⸻

4. ไฟล์พิเศษ: team_api.php

team_api.php มีความเสี่ยงปานกลาง เพราะ:
	•	เรียก resolve_current_org() สองครั้ง
	•	มีการตั้ง header X-Correlation-Id
	•	อาจมี logic แยก core DB / tenant DB

4.1 เป้าหมายเฉพาะของไฟล์นี้
	1.	ให้มีการ resolve org แค่ครั้งเดียวผ่าน TenantApiBootstrap::init()
	2.	ให้ header X-Correlation-Id ยังทำงานเหมือนเดิม
	3.	ให้ DB ของ tenant ใช้ $db / $db->getTenantDb() เท่านั้น
	4.	ถ้าไฟล์ใช้ core_db() สำหรับข้อมูล global, ให้คงไว้ (ไม่ไปยุ่ง)

4.2 ขั้นตอนแนะนำ
	1.	หา block ที่ทำ correlation id:

$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
header('X-Correlation-Id: ' . $cid);

ให้คง block นี้ไว้ที่เดิม หรือย้ายไปไว้หลัง Bootstrap เล็กน้อยได้ ตราบใดที่ header ยังส่งออกก่อน response JSON
	2.	ลบทุก resolve_current_org() ในไฟล์
	3.	ใส่:

[$org, $db] = TenantApiBootstrap::init();

ครั้งเดียว แล้วใช้ $org แทนในทุกจุด

⸻

5. Guardrails สำคัญ
	1.	ห้ามเปลี่ยน Business Logic ใด ๆ
	•	SQL เดิม = SQL เดิม
	•	เงื่อนไข if/else เดิม
	•	การจัดรูปแบบ array / response เดิม
	2.	ห้ามเปลี่ยนรูปแบบ JSON Response
	•	ถ้าเดิมส่ง json_success(['data' => $rows])
ต้องคงรูปนี้เป๊ะ
	3.	ห้ามเพิ่ม/ลด Header พิเศษ
	•	X-Correlation-Id, Retry-After ฯลฯ ให้คงเหมือนเดิม
	4.	Authentication / Permission
	•	อย่าไปยุ่งกับ memberDetail / permission check
	•	Bootstrap ต้องเข้ามา “หลังจาก” auth ผ่านแล้ว (ถ้าไฟล์นั้นใช้ pattern นี้)

⸻

6. Testing

6.1 Syntax

ทุกไฟล์ที่แก้:

php -l source/<file>.php

6.2 Smoke Test (ApiBootstrapSmokeTest.php)

ต้องอัปเดตรายการ $migratedFiles ให้รวม Batch B ที่เสร็จแล้ว และให้ test:
	•	ยืนยันว่ามี TenantApiBootstrap::init()
	•	ยืนยันว่าไม่มี resolve_current_org, tenant_db, new DatabaseHelper, new mysqli
	•	warning ถ้ามี $mysqli->query() ที่ไม่ได้มาจาก $db->getTenantDb()

6.3 Manual Spot Check

สำหรับไฟล์หลัก ๆ (เช่น team_api.php, token_management_api.php):
	•	ยิง API จริง (ถ้า environment พร้อม)
	•	เทียบ response structure กับก่อนแก้ (ควรจะเหมือนเดิม)

⸻

7. Success Criteria

Task 5 ถือว่าสำเร็จเมื่อ:
	•	APIs ใน Batch B ทั้งหมด:
	•	ใช้ TenantApiBootstrap::init() แล้ว
	•	ไม่ใช้ resolve_current_org(), tenant_db(), new DatabaseHelper(), new mysqli() ในไฟล์
	•	ถ้ามี $mysqli->query() จะต้องมาจาก $db->getTenantDb() เท่านั้น
	•	ApiBootstrapSmokeTest.php:
	•	เพิ่ม Batch B เข้าไปในรายการตรวจแล้ว
	•	ผ่านทุกรายการ (มีแค่ warning ที่อธิบายได้ หรือไม่มี warning เลย)
	•	ระบบยังทำงานได้ตามเดิม (response และ behavior เท่าเดิม)

⸻
