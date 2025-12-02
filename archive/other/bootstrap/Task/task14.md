Platform API Batch B Migration – CoreApiBootstrap (3 Files)

**Status:** ✅ COMPLETED (2025-11-18)
Executor: AI Agent (Cursor / ChatGPT Code Editor)
Author: Bellavier Group Engineering Standards
Last Updated: 2025-11-18

⸻

🎯 Objective

ทำการ migrate Platform API ทั้ง 3 ไฟล์จาก legacy bootstrap → CoreApiBootstrap
โดย ไม่แตะ business logic, ไม่แตะ permission, ไม่แตะ response structure
และเพิ่มมาตรฐาน modern bootstrapping ทั้งหมด เช่น AI Trace, RateLimiter, error handling

Batch B (3 ไฟล์):
	1.	admin_feature_flags_api.php
	2.	platform_roles_api.php
	3.	platform_tenant_owners_api.php

⸻

🧱 Goal

หลังทำ Task 14 เสร็จ:
	•	Platform APIs ทั้งหมด (ยกเว้น salt API) จะใช้ มาตรฐานเดียวกัน 100%
	•	โค้ด bootstrap จะเหลือรูปแบบเดียว (สวย, สะอาด, audit ได้ง่าย)
	•	ลดความเสี่ยงจาก legacy bootstrap + manual headers + manual login
	•	เตรียมพื้นฐานสำหรับ Task 15 (ไฟล์ CRITICAL: salt API)

⸻

✅ Scope of Task 14

ต้องทำ
	•	ใช้ CoreApiBootstrap::init()
	•	ใส่ block AI Trace (เหมือน Task 12)
	•	ใส่ block try/catch + standardized error response
	•	ใส่ RateLimiter แบบมาตรฐาน platform (120 req/min per member)
	•	ใช้ $coreDb (DatabaseHelper) ที่ได้จาก bootstrap
	•	ใช้ $tenantDb (ถ้าไฟล์นั้นจำเป็น)
	•	ใช้ $coreDb->getCoreDb() หากไฟล์นั้นต้องการ mysqli ตรง
	•	แทนที่ pattern เดิมทั้งหมด:
	•	session_start()
	•	require_once config.php
	•	new memberDetail()
	•	thisLogin()
	•	manual JSON header
	•	manual correlation ID
	•	manual DatabaseHelper creation
	•	manual $coreDb = core_db()
	•	manual $tenantDb = tenant_db()

ห้ามทำ
	•	❌ ห้ามแก้ business logic
	•	❌ ห้ามแก้โครงสร้าง JSON output
	•	❌ ห้ามแก้ permission check logic เช่น
	•	is_platform_administrator($member)
	•	permission_allow_code()
	•	platform_has_any()
	•	❌ ห้ามแก้ action names
	•	❌ ห้ามลบหรือย้าย SQL logic ที่เป็นของเดิม
	•	❌ ห้ามแก้ file structure เช่น function order
	•	❌ ห้าม rewrite function ใหม่

⸻

🧬 Migration Rules (Standard Template)

ใช้ template นี้เป็น base:

require_once __DIR__ . '/../vendor/autoload.php';

use BGERP\Bootstrap\CoreApiBootstrap;
use BGERP\Helper\RateLimiter;
use BGERP\Helper\JsonResponse;

// INIT BOOTSTRAP
[$member, $coreDb, $tenantDb, $org, $cid] = CoreApiBootstrap::init([
    'requireAuth' => true,
    'requirePlatformAdmin' => true,   // หรือ false ตามไฟล์นั้น
    'jsonResponse' => true,
]);

// RATE LIMIT
$userId = (int)$member['id_member'];
RateLimiter::check($member, 120, 60, 'platform_api');

// AI TRACE START
$__t0 = microtime(true);
$aiTrace = [
    'module'      => basename(__FILE__, '.php'),
    'action'      => $_REQUEST['action'] ?? '',
    'tenant'      => $org['id_org'] ?? 0,
    'user_id'     => $userId,
    'timestamp'   => gmdate('c'),
    'request_id'  => $cid,
];

try {
    // ORIGINAL BUSINESS LOGIC HERE (UNCHANGED)
}
catch (\Throwable $e) {
    error_log("[CID:$cid][" . basename(__FILE__) . "][User:$userId] " . $e->getMessage());
    json_error('internal_error', 500, ['app_code' => 'API_500_INTERNAL']);
}
finally {
    $aiTrace['execution_ms'] = round((microtime(true) - $__t0) * 1000, 2);
    if (!headers_sent()) {
        header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));
    }
}


⸻

🔍 Migration File-by-File Instructions

1) platform_roles_api.php

Bootstrap Instructions
	•	Use:

'requirePlatformAdmin' => true

Notes
	•	ใช้ Core DB เท่านั้น → ไม่มี tenant DB
	•	Permission logic: is_platform_administrator($member) → อย่าเปลี่ยน
	•	มี manual correlation ID → ต้องลบ
	•	DatabaseHelper ถูกสร้าง manual → เปลี่ยนเป็น $coreDb
	•	โครงสร้างไฟล์เหมือน admin_org/admin_rbac → migrate ง่ายสุด

⸻

2) platform_tenant_owners_api.php

Bootstrap Instructions
	•	Use:

'requirePlatformAdmin' => true

Notes
	•	ใช้ Core DB เท่านั้น
	•	CRUD owner ของ tenant → ห้ามแก้ logic
	•	ใช้ account_org, account, account_group → ใช้ Core DB
	•	DatabaseHelper manual → แทนด้วย $coreDb

⸻

3) admin_feature_flags_api.php

Bootstrap Instructions
	•	Allowed:

'requirePlatformAdmin' => false
'requireAuth' => true
'requireTenant' => false

Notes
	•	ไฟล์นี้มี permission check ซับซ้อน → ห้ามแตะ
	•	Logic อ่าน/เขียน feature flags อยู่ใน tenant DB
→ ใช้ $tenantDb ที่ได้จาก bootstrap
	•	Org resolution ต้อง manual override เหมือน admin_rbac.php
(regardless of requireTenant flag)

⸻

🧪 Verification Checklist (Agent must self-check)

หลัง migrate ไฟล์แต่ละตัว Agent ต้องตรวจสอบ:

Syntax
	•	php -l file.php = OK

Bootstrap
	•	มี CoreApiBootstrap::init(...)
	•	ไม่มี session_start()
	•	ไม่มี require_once config.php
	•	ไม่มี manual header
	•	ไม่มี manual correlation ID
	•	ไม่มี core_db() / tenant_db()
	•	ไม่มี new memberDetail()

Permission
	•	Permission logic ยังคงเหมือนเดิม 100%

DB
	•	ใช้ $coreDb / $tenantDb
	•	ไม่มีการสร้าง DatabaseHelper ใหม่

AI TRACE
	•	มี try/catch/finally ครบ
	•	มี header X-AI-Trace

⸻

⛔ Guardrails for Agent (Strict)

Agent ต้อง:
	•	❌ ห้าม refactor logic ที่อยู่นอก bootstrap scope
	•	❌ ห้าม reorder function
	•	❌ ห้าม rename $member, $coreDb, $tenantDb, $org, $cid
	•	❌ ห้ามแก้ global variables
	•	❌ ห้ามแตะ permission มุมไหนแม้แต่น้อย
	•	❌ ห้ามเปลี่ยน response JSON
	•	❌ ห้าม optimize SQL
	•	❌ ห้ามลบ comment เดิมของไฟล์ (ยกเว้น boilerplate legacy headers)

Allowed:
	•	✔ เพิ่ม bootstrap
	•	✔ เพิ่ม AI Trace + try/catch
	•	✔ เปลี่ยน DB access ให้ใช้ DatabaseHelper
	•	✔ เพิ่ม RateLimiter
	•	✔ reorder เฉพาะ bootstrap block ที่ต้องขึ้นบนสุด

⸻

📦 Agent Deliverables

เมื่อทำเสร็จ Agent ต้องส่ง:

For each file:
	•	diff/preview ของไฟล์หลัง migrate
	•	Syntax check (php -l)
	•	Smoke test ของ bootstrap detection
	•	Summary การเปลี่ยนแปลง

For full Batch B:
	•	Updated discovery stats
	•	Updated migration roadmap
	•	Confirm readiness for Task 15

⸻

🎉 Expected Outcome

เมื่อ Task 14 จบลง:
	•	Platform API level จะ standardized 90%
	•	Remaining risky file only = platform_serial_salt_api.php
	•	ระบบ core/tenant auth + bootstrap จะเป็น ecosystem เดียว
	•	พร้อมเข้าสู่ Task 15 (Security Migration)

---

## Completion Summary (2025-11-18)

**Status:** ✅ COMPLETED

### Migration Results

**Files Migrated:** 3 files
1. ✅ `admin_feature_flags_api.php`
2. ✅ `platform_roles_api.php`
3. ✅ `platform_tenant_owners_api.php`

### Changes Made

**For each file:**
- ✅ Replaced legacy bootstrap with `CoreApiBootstrap::init()`
- ✅ Removed `session_start()`, `require_once config.php`, manual auth checks
- ✅ Removed manual correlation ID generation
- ✅ Removed manual `core_db()` and `DatabaseHelper` creation
- ✅ Added AI Trace metadata and standardized error handling
- ✅ Added `try-catch-finally` with `X-AI-Trace` header
- ✅ Used `$coreDb` from bootstrap (DatabaseHelper instance)
- ✅ Preserved all business logic, permission checks, and response formats

**Specific Bootstrap Options:**
- `admin_feature_flags_api.php`: `requirePlatformAdmin => false` (custom permission check)
- `platform_roles_api.php`: `requirePlatformAdmin => true`
- `platform_tenant_owners_api.php`: `requirePlatformAdmin => true`

### Verification

- ✅ All syntax checks passed (`php -l`)
- ✅ All files use `CoreApiBootstrap::init()`
- ✅ No legacy patterns remaining (no `session_start()`, `core_db()`, etc.)
- ✅ AI Trace headers added to all files
- ✅ Standardized error handling in all files

### Current Status

**Platform API Migration Progress:**
- ✅ **Migrated:** 11 files (73.3%)
  - platform_dashboard_api.php, platform_health_api.php, platform_migration_api.php
  - platform_serial_metrics_api.php, admin_org.php, admin_rbac.php
  - member_login.php, run_tenant_migrations.php
  - admin_feature_flags_api.php, platform_roles_api.php, platform_tenant_owners_api.php
- ❌ **Remaining:** 1 file (6.7%)
  - platform_serial_salt_api.php (CRITICAL, security-sensitive)

### Next Steps

- **Task 15:** Platform Serial Salt API Migration (1 file, critical, security-sensitive)
