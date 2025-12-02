✅ Task2.md — Create PSR-4 Helper Classes + TenantApiBootstrap::init() (Implementation Task)

**Status:** ✅ **COMPLETED** (2025-11-18)

Version: Perfect for AI Agent execution
Goal: สร้างฐานราก PSR-4 ทั้งชุด เพื่อให้ API ทั้งระบบสามารถย้ายไปใช้ Bootstrap กลางได้ใน Task 3

⚠️ หมายเหตุ: Task1.md = Discovery (อ่านโค้ดเท่านั้น) สามารถรันได้ทันที
Task2.md = Implementation (สร้างไฟล์ใหม่ ไม่แตะ API เดิม)

⸻


# Task 2 – Implement PSR-4 Helper Classes & TenantApiBootstrap::init()

**Type:** Implementation (สร้างโค้ดใหม่ + class ใหม่)  
**Project:** `/docs/bootstrap/tenant_api_bootstrap.md`  
**Goal:** วางโครงสร้าง PSR-4 bootstrap ที่สมบูรณ์ เพื่อรองรับการ refactor APIs ทั้งหมดใน Task3–Task5

---

# 1. Objective

สร้าง PSR-4 helper classes ชุดใหม่ใน namespace:

BGERP\Helper
BGERP\Bootstrap\

เพื่อแทนโค้ด legacy ที่มีลักษณะดังนี้:

- ฟังก์ชันแบบ procedural เช่น `resolve_current_org()`, `tenant_db()`, `json_error()`
- การ connect tenant DB แบบ `new mysqli(...)`
- require_once helpers กระจัดกระจาย
- ตั้ง header หรือ timezone ใน API รายไฟล์

และสร้าง **TenantApiBootstrap::init()** ซึ่งจะถูกใช้แทน require/base logic ทั้งหมดของ API แบบ tenant-scoped

---

# 2. Deliverables

### ต้องสร้างไฟล์ใหม่ทั้งหมดใน PSR-4 structure:

source/BGERP/Helper/OrgResolver.php
source/BGERP/Helper/TenantConnection.php
source/BGERP/Helper/JsonResponse.php
source/BGERP/Bootstrap/TenantApiBootstrap.php

*DatabaseHelper มีอยู่แล้ว → ใช้ของเดิม*

---

# 3. Requirements (Per Class)

## 3.1 `OrgResolver`
**Purpose:** คืนค่าองค์กรปัจจุบัน โดยอิง behavior เดิมของ resolve_current_org()

### Required:
- Static method:
  ```php
  public static function resolveCurrentOrg(): ?array
  ```
- ให้เรียกฟังก์ชัน legacy: `resolve_current_org()` (มาจาก config.php)
- คืน `?array` ตามรูปแบบเดิม (เช่น `$org['code']`, `$org['timezone']`)
- ห้ามส่ง JSON response ใน class นี้
- ห้ามสร้าง OrgDTO ใน Task นี้ (จะทำใน task อนาคตหลัง migrate APIs แล้ว)

⸻

3.2 TenantConnection

Purpose: เปิด tenant database ตาม org code

Required:

public static function forOrgCode(string $orgCode): \mysqli

Rules:
- ต้อง delegate ไปหา tenant_db($orgCode) (ไม่ต้อง new mysqli เอง)
- ถ้า tenant_db() ไม่คืน mysqli → โยน RuntimeException
- ห้าม echo/print ใด ๆ

⸻

3.3 JsonResponse

Purpose: แทน json_error() และ json_success()

Required:

public static function success(array $data = [], array $meta = []): void
public static function error(string $message, int $status = 400, array $meta = []): void

Rules:
- ต้อง wrap การทำงานของ json_success() และ json_error() เดิมในช่วง transition นี้
- ยังไม่ต้องออกแบบ JSON format ใหม่ (ต้อง match behavior เดิม 100%)
- ต้อง exit() หลังส่ง response เหมือน behavior เดิม
- ห้าม echo ข้อความอื่นก่อน JSON

Format:

{
  "ok": true,
  "data": {},
  "meta": {}
}

{
  "ok": false,
  "error": "message",
  "app_code": "SOME_CODE",
  "meta": {}
}


⸻

3.4 TenantApiBootstrap

Purpose: จุดกลาง bootstrap สำหรับ API ทั้งระบบ

Required Method:

public static function init(): array

Must do:
	1.	require_once config.php
	2. โหลด config.php (bootstrap global + autoload)
	3. resolve org ผ่าน OrgResolver
	4. เปิด tenant DB ผ่าน TenantConnection
	5. wrap ด้วย DatabaseHelper
	6. set timezone ($org['timezone'] ?? DEFAULT_TIMEZONE)

Error Cases:
- ถ้า org = null → JsonResponse::error('no_org', 403, ['app_code' => 'TENANT_403_NO_ORG']); exit;
- ถ้า tenant DB connect fail → JsonResponse::error('tenant_db_fail', 500);

Restrictions:
- ห้ามเขียน business logic ใด ๆ
- ห้ามทำ query ใด ๆ
- bootstrap ต้องเบา
- ไม่ต้องตั้ง Content-Type ใน bootstrap (ปล่อยให้ JsonResponse หรือ legacy json_error/json_success ตั้งเอง)

⸻

4. File Output Example (Expected by QA)

เรียกใน API แบบใหม่:

use BGERP\Bootstrap\TenantApiBootstrap;

[$org, $db] = TenantApiBootstrap::init();


⸻

5. Constraints & Guardrails
	1.	ห้ามแก้โค้ดใน API เดิม
	•	Implement classes ใหม่เท่านั้น (Task3 จะเริ่ม migrate APIs)
	2.	ต้องเป็น PSR-4 100%
	•	class name = file name
	•	namespace ตรงกับ directory
	•	ห้าม require_once helper รายไฟล์
	3.	JsonResponse ต้องเป็น source of truth
	•	API ห้ามส่ง JSON เองอีกต่อไป หลัง Task3
	4.	Bootstrap ต้องไม่มี side effects
	•	ห้ามส่ง echo/print ใด ๆ
	•	ห้ามทำ query
	•	ห้ามเริ่ม session
	•	ห้ามเขียน log
	5.	ทุก class ต้องผ่าน php -l และ autoload ได้จริง

6. APIs ที่ยังไม่เคยใช้ Setup Core (legacy API) ต้องรองรับกรณีที่ resolve_current_org() / tenant_db() มีโครงสร้างแตกต่างเล็กน้อยจากไฟล์อื่น ๆ → ห้ามทำสมมติฐานใหม่ใน Task2, ต้องใช้ behavior เดิม 100%

⸻

6. Success Criteria

Task2 ถือว่าสำเร็จเมื่อ:
	•	Helper classes ทั้งหมดถูกสร้างครบ (OrgResolver, TenantConnection, JsonResponse)
	•	TenantApiBootstrap ถูกสร้างและ autoload ใช้งานได้
	•	Code ไม่แตะ API เดิมแม้แต่บรรทัดเดียว
	•	ตัวอย่างการเรียก TenantApiBootstrap::init() ต้องผ่าน syntax check
	•	Agent สามารถเริ่ม Task3 (API migration) ต่อได้ทันที

---

## 7. Completion Summary

**✅ Task 2 Completed Successfully (2025-11-18)**

### Files Created:

1. **`source/BGERP/Helper/OrgResolver.php`** (54 lines)
   - ✅ Wraps `resolve_current_org()` function
   - ✅ Method: `resolveCurrentOrg(?string $preferredCode = null): ?array`
   - ✅ PSR-4 compliant, autoloadable

2. **`source/BGERP/Helper/TenantConnection.php`** (75 lines)
   - ✅ Wraps `tenant_db()` function
   - ✅ Method: `forOrgCode(string $orgCode): mysqli`
   - ✅ Error handling and validation included

3. **`source/BGERP/Helper/JsonResponse.php`** (140 lines)
   - ✅ Wraps `json_error()` and `json_success()` functions
   - ✅ Methods: `success(array $data, array $meta, int $code)` and `error(string $message, int $status, array $meta)`
   - ✅ 100% backward compatible with legacy functions

4. **`source/BGERP/Bootstrap/TenantApiBootstrap.php`** (115 lines)
   - ✅ Main bootstrap class
   - ✅ Method: `init(): array` - returns `[$org, $db]` tuple
   - ✅ Implements all required steps: load config, resolve org, connect DB, set timezone

### Testing:

- ✅ **Syntax Check:** All files pass `php -l` validation
- ✅ **Autoload Test:** All classes autoload successfully via PSR-4
- ✅ **Structure Test:** Method signatures and return types verified
- ✅ **Test Script:** `tests/bootstrap/TenantApiBootstrapSyntaxTest.php` created and passing

### Usage Example:

```php
use BGERP\Bootstrap\TenantApiBootstrap;

[$org, $db] = TenantApiBootstrap::init();
// Now $org and $db (DatabaseHelper) are available
```

### Next Steps:

- ✅ Ready for **Task 3**: API Migration (Batch A - Low-risk APIs)
- ✅ All Helper classes are PSR-4 compliant and autoloadable
- ✅ No changes made to existing APIs (as per spec)
- ✅ Bootstrap is lightweight and ready for production use

**Total Lines of Code:** 384 lines (Helper classes + Bootstrap)