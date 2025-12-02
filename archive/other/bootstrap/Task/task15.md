Platform Serial Salt API Hardening & CoreApiBootstrap Migration

**Status:** ✅ COMPLETED (2025-11-18)
Executor: AI Agent (Cursor / ChatGPT Code Editor)
Author: Bellavier Group Engineering Standards
Last Updated: 2025-11-18

⸻

🎯 Objective

ทำการ migrate และ harden ไฟล์:
	•	platform_serial_salt_api.php

จาก legacy bootstrap → CoreApiBootstrap
พร้อมทั้ง ทบทวน security model แบบละเอียด โดย:
	•	✅ ไม่เปลี่ยนพฤติกรรมด้านผลลัพธ์ (backward compatible)
	•	✅ ไม่เปลี่ยน algorithm ของ salt/hashing
	•	✅ ไม่ log ข้อมูลอ่อนไหว (salt, key, hash)
	•	✅ เพิ่มมาตรฐาน modern bootstrapping (CoreApiBootstrap, AI Trace, error handling, RateLimiter)
	•	✅ เพิ่ม guardrails ด้าน security ที่ชัดเจน

นี่คือไฟล์ CRITICAL: มีผลกับความปลอดภัยของทั้งระบบ Platform & Tenant ทั้งชุด

⸻

🧱 Scope

ต้องทำ
	1.	ใช้ CoreApiBootstrap::init()
	•	ใช้สำหรับ auth, member, core DB, tenant (ถ้าจำเป็น)
	•	ต้องใช้ pattern เดียวกับ platform_*_api.php อื่น ๆ
	2.	เพิ่ม AI Trace + error handling
	•	เพิ่ม try/catch/finally block ตามมาตรฐาน platform
	•	เพิ่ม X-AI-Trace header แต่ห้ามใส่ข้อมูลอ่อนไหวใน trace
	3.	ปรับการใช้ DB ให้สอดคล้องมาตรฐาน
	•	ใช้ $coreDb (DatabaseHelper) แทน manual core_db() / new DatabaseHelper
	•	ใช้ $coreDb->getCoreDb() เฉพาะส่วนที่ต้องใช้ mysqli ตรง (ถ้ามี)
	•	ถ้าไฟล์นี้แตะ tenant DB ต้องใช้ $tenantDb จาก bootstrap เท่านั้น
	4.	เพิ่ม RateLimiter สำหรับ API นี้โดยเฉพาะ
	•	ใช้ RateLimiter::check()
	•	Limit เข้มกว่าปกติ เช่น 60 req / 60 sec / user (หรือเท่ากับค่าปัจจุบันถ้ามีแล้ว)
	•	Scope แยก: 'platform_salt_api' (ไม่ใช้ 'platform_api' ร่วมกับ API ทั่วไป)
	5.	ยกเลิก legacy bootstrap ทั้งหมด
	•	ลบ:
	•	session_start()
	•	require_once 'config.php' (ใช้ autoload จาก vendor + bootstrap)
	•	new memberDetail() + thisLogin()
	•	manual JSON header
	•	manual correlation ID
	•	manual core_db/tenant_db
	•	manual DatabaseHelper creation
	6.	เขียน/อัพเดทเอกสาร discovery สำหรับ API นี้
	•	ระบุ:
	•	มี action อะไรบ้าง ($_REQUEST['action'])
	•	ใช้ข้อมูล input อะไรบ้าง
	•	คืนค่าข้อมูลแบบไหน (fields, structure)
	•	มีการใช้ salt/secret/hash แบบไหน
	•	ถูกเรียกจากส่วนใดของระบบ (ระบุไฟล์ caller ถ้ามี)

⸻

ห้ามทำ (Security Guardrails)
	•	❌ ห้ามเปลี่ยน algorithm เกี่ยวกับ salt/hash
	•	ห้ามเปลี่ยนจาก random_bytes → algorithm อื่น
	•	ห้ามเปลี่ยน salt length หรือ format ที่ส่งคืนให้ caller
	•	❌ ห้าม log ข้อมูลอ่อนไหว:
	•	ห้าม log ค่าใด ๆ ที่เป็น:
	•	salt จริง
	•	secret key
	•	hash ที่ใช้ verify โดยตรง
	•	raw payload ที่เอาไว้ผูกกับ salt
	•	❌ ห้ามเปลี่ยนโครงสร้าง JSON response
	•	ห้ามเพิ่ม field ใหม่ที่เปิดเผยข้อมูลเพิ่มโดยไม่จำเป็น
	•	ห้ามลบ field เดิม (อาจทำให้ client พัง)
	•	❌ ห้ามแก้ไข permission semantics
	•	ถ้าปัจจุบันมีการเช็ค is_platform_administrator($member) / เงื่อนไขอื่น
	•	ต้องคง logic ทั้งหมดไว้เหมือนเดิม (แค่ย้ายเข้า context ใหม่)
	•	❌ ห้าม reorder หรือ refactor business logic
	•	ห้าม “จัดโค้ดให้สวยขึ้น” ในส่วน generate/verify salt
	•	เน้น “wrap” ด้วย bootstrap + guardrails เท่านั้น
	•	❌ ห้ามเปลี่ยนพฤติกรรมสำหรับ CLI/cron call ถ้ามี
	•	ถ้ามี php_sapi_name() === 'cli' หรือ path สำหรับ background job
	•	ห้ามแก้ตรรกะส่วนนั้น ให้ wrap ใน bootstrap แยกอย่างระวัง หรือทิ้ง CLI path ไว้เหมือนเดิมแล้ว comment ไว้อย่างชัดเจน

⸻

🧬 Phase 1 – Deep Discovery & Threat Model

1.1 Static Discovery

Agent ต้อง:
	•	อ่าน platform_serial_salt_api.php ทั้งไฟล์
	•	list:
	•	action ทั้งหมดที่ support เช่น:
	•	get_salt, rotate_salt, sync_salt, ฯลฯ (ตัวอย่าง – ให้ agent ดึงจริง)
	•	input parameters ที่ใช้: serial, job_ticket_id, org_code, ฯลฯ
	•	output fields: อะไรบ้างที่มี salt / hash / token
	•	ตรวจว่าปัจจุบันใช้อะไร generate:
	•	random_bytes(), openssl_random_pseudo_bytes(), uniqid(), ฯลฯ
	•	ใช้ hash function อะไร: sha256, bcrypt, password_hash, ฯลฯ
	•	ตรวจการใช้ DB:
	•	ตาราง / fields ที่เกี่ยวกับ serial salt
	•	ใช้ core หรือ tenant DB
	•	มี transaction หรือไม่

1.2 Usage / Caller Discovery

Agent ต้อง:
	•	grep หา platform_serial_salt_api.php ทั่วทั้งโปรเจค
	•	list callers เช่น:
	•	JS front-end
	•	PHP backend อื่น
	•	CLI script หรือ cron job

เพื่อให้เรามั่นใจว่า การเปลี่ยน bootstrap ไม่กระทบ consumer แปลก ๆ

1.3 Threat Model (สั้น ๆ แต่ชัด)

Agent ต้องเขียนสรุป (ภายใน core_platform_bootstrap.discovery.md):
	•	ข้อควรกังวลหลัก:
	•	API นี้สามารถทำให้ attacker:
	•	ขอ salt ใหม่ไม่จำกัด?
	•	เดาโครงสร้าง serial + salt ได้ง่ายขึ้น?
	•	อ่านค่า salt ที่ใช้ใน production ได้หรือไม่?
	•	ขอบเขต protection ปัจจุบัน:
	•	auth / permission ที่มีอยู่
	•	logging ที่ทำ/ไม่ทำ
	•	rate limiting (ถ้ามี หรือไม่มีเลย)

⸻

🧬 Phase 2 – Bootstrap Design (เฉพาะไฟล์นี้)

2.1 CoreApiBootstrap Options

ในไฟล์นี้ให้ใช้:

[$member, $coreDb, $tenantDb, $org, $cid] = CoreApiBootstrap::init([
    'requireAuth'         => true,
    'requirePlatformAdmin'=> true,      // ถ้าปัจจุบันเป็นเฉพาะ platform admin
    'requireTenant'       => false,     // ถ้า API นี้ใช้ core-level only
    'jsonResponse'        => true,
]);

ถ้าพบว่าปัจจุบัน ไม่ได้บังคับ admin (เปิดให้ member ทั่วไปบางกลุ่ม)
ให้ Agent ระบุอย่างชัดเจนใน discovery แล้วใช้ flag ที่สอดคล้องที่สุด
(เช่น requirePlatformAdmin => false + custom permission check เดิมที่มีอยู่)

2.2 RateLimiter Design
	•	ใช้:

use BGERP\Helper\RateLimiter;
$userId = (int)$member['id_member'];
RateLimiter::check($member, 60, 60, 'platform_salt_api');


	•	ถ้าไฟล์เดิมมี Rate limit logic อยู่แล้ว:
	•	ห้ามลบ ให้คงไว้ และเพิ่ม RateLimiter เป็นชั้นเสริมได้
(แต่ต้อง note ไว้ใน discovery)

2.3 AI Trace (No Sensitive Data)
	•	Format:

$__t0 = microtime(true);
$aiTrace = [
    'module'     => basename(__FILE__, '.php'),
    'action'     => $_REQUEST['action'] ?? '',
    'tenant'     => $org['id_org'] ?? 0,
    'user_id'    => $userId,
    'timestamp'  => gmdate('c'),
    'request_id' => $cid,
];

	•	❌ ห้ามเพิ่ม:
	•	serial number ที่ใช้จริง
	•	salt หรือ hash
	•	secret values

เพียง log metadata พอ เช่น action, tenant, user, timing

⸻

🛠 Phase 3 – Implementation Steps (Agent Playbook)
	1.	Backup & Snapshot
	•	copy ไฟล์ platform_serial_salt_api.php เก็บไว้เป็น reference (ใน Git อยู่แล้ว)
	•	ห้ามแก้ชื่อไฟล์ / path
	2.	Add Modern Bootstrap
	•	require_once __DIR__ . '/../vendor/autoload.php';
	•	use BGERP\Bootstrap\CoreApiBootstrap;
	•	use BGERP\Helper\RateLimiter;
	•	เรียก CoreApiBootstrap::init([...]) ด้านบนสุดของไฟล์
	3.	Remove Legacy Bootstrap
	•	ลบ session_start()
	•	ลบ require_once 'config.php'; (หรือ path อื่น)
	•	ลบ new memberDetail() + thisLogin()
	•	ลบ manual $coreDb = core_db(); / $tenantDb = tenant_db();
	•	ลบ manual correlation id
	4.	Wire DB Access ผ่าน $coreDb / $tenantDb
	•	แทนที่ core_db() ด้วย $coreDb->getCoreDb() หรือ $coreDb->fetchAll()/fetchOne()/execute()
	•	ถ้าไฟล์นี้ใช้ tenant table จริง ๆ → ใช้ $tenantDb จาก bootstrap
	5.	Wrap Business Logic ด้วย try/catch/finally
	•	ใส่ try { ... } catch (\Throwable $e) { ... } finally { ... }
	•	preserve business logic เดิม ทั้งก้อน
(แค่ย้ายเข้าใน try block ตามที่จำเป็น)
	6.	Ensure Responses ใช้ json_ เดิม*
	•	ใช้ json_success(), json_error() ตามเดิม
	•	ห้ามเพิ่ม field ใหม่ใน response
	7.	Logging / Error
	•	ใช้ error_log() เฉพาะ message / metadata
	•	ห้าม log ค่า salt/hash/secret

⸻

🧪 Phase 4 – Verification

Agent ต้องรัน:
	1.	Syntax
	•	php -l source/platform_serial_salt_api.php
	2.	Bootstrap Smoke Test
	•	อัพเดท (ถ้าจำเป็น) tests/bootstrap/CorePlatformBootstrapSmokeTest.php
ให้รวมไฟล์ platform_serial_salt_api.php ในรายการตรวจ:
	•	ตรวจว่ามี CoreApiBootstrap::init()
	•	ตรวจว่าไม่มี session_start(), core_db(), tenant_db()
	3.	Behavior Check (Manual / Semi-Manual)
	•	ก่อนแก้: เรียก API อย่างน้อย 1 action (ผ่าน browser/Postman) → บันทึกตัวอย่าง response (mask ค่าอ่อนไหว)
	•	หลังแก้: เรียก API เดิม → ตรวจว่า:
	•	HTTP status เหมือนเดิม
	•	โครงสร้าง JSON เหมือนเดิม
	•	status flags / code / message เหมือนเดิม
	4.	Security Sanity Check
	•	ตรวจว่า:
	•	ไม่มี var_dump() / print_r() debug
	•	ไม่มี log ของค่า input ที่อ่อนไหว
	•	ไม่มีที่ไหนที่ echo/sprintf salt หรือ hash ออก log

⸻

📦 Agent Deliverables

เมื่อเสร็จ Task 15 ให้ Agent ส่ง:
	1.	Diff ของ platform_serial_salt_api.php
	•	แสดงเฉพาะส่วน bootstrap + try/catch + DB wiring
	2.	ผลการทดสอบ
	•	Output ของ php -l source/platform_serial_salt_api.php
	•	Output ของ smoke test (ถ้ามี script)
	•	Screenshot หรือ text ของ response ก่อน/หลัง (mask salt/secret ออก)
	3.	Discovery Notes
	•	Action list
	•	Summary threat model (สั้น ๆ)
	•	Permission model ปัจจุบันของ API นี้
	4.	Docs Update
	•	อัพเดท:
	•	core_platform_bootstrap.discovery.md
	•	เพิ่ม Task 15 ใน status + stats
	•	ถ้าจำเป็น เพิ่ม note ใน core_platform_bootstrap.md ว่า:
	•	Salt API ได้ผ่านการ harden + bootstrap แล้ว

⸻

🎉 Expected Outcome

หลัง Task 15 เสร็จ:
	•	Platform API ทุกตัวจะใช้ CoreApiBootstrap 100%
	•	Salt API (จุดเสี่ยงที่สุด) จะถูก:
	•	ห่อด้วย auth/permission ที่ชัดเจน
	•	ป้องกันด้วย RateLimiter
	•	ไม่ log ข้อมูลอ่อนไหว
	•	Monitor ได้ผ่าน AI Trace (แค่ metadata)
	•	ระบบพร้อมสำหรับขั้นต่อไปของ Bellavier Security Framework

---

## Completion Summary (2025-11-18)

**Status:** ✅ COMPLETED

### Migration Results

**File Migrated:** 1 file (CRITICAL, security-sensitive)
- ✅ `platform_serial_salt_api.php`

### Changes Made

**Bootstrap Migration:**
- ✅ Replaced legacy bootstrap with `CoreApiBootstrap::init(['requirePlatformAdmin' => true])`
- ✅ Removed `session_start()`, `require_once config.php`, manual auth checks
- ✅ Removed manual correlation ID generation
- ✅ Removed manual JSON header setup
- ✅ Added AI Trace metadata (NO sensitive data - salt values excluded)
- ✅ Added `try-catch-finally` with `X-AI-Trace` header
- ✅ Preserved all business logic, security features, and response formats

**Security Features Preserved:**
- ✅ CSRF protection (preserved)
- ✅ Rate limiting (10 req/60sec - very strict, preserved)
- ✅ File-based storage (preserved - no DB usage)
- ✅ Atomic file writes (preserved)
- ✅ File permissions 0600 (preserved)
- ✅ Audit log (preserved - NO salt values, only metadata)

**Security Guardrails Applied:**
- ✅ No salt values in error logs
- ✅ No salt values in AI Trace
- ✅ No debug output (var_dump, print_r)
- ✅ Algorithm unchanged (random_bytes(32))
- ✅ Response structure unchanged (backward compatible)

### Verification

- ✅ All syntax checks passed (`php -l`)
- ✅ File uses `CoreApiBootstrap::init()`
- ✅ No legacy patterns remaining (no `session_start()`, `config.php`, etc.)
- ✅ AI Trace headers added (without sensitive data)
- ✅ Standardized error handling
- ✅ Security check: No salt values in logs ✅

### Discovery Notes

**Actions Supported:**
- `status`: Get current status (no salt values)
- `csrf_token`: Get CSRF token for form
- `generate`: Generate initial salts (HAT + Classic, version 1)
- `rotate`: Rotate salts (increment version)

**Threat Model:**
- **Primary Concerns:**
  - API requires Platform Super Admin (Owner/SysAdmin) only
  - Very strict rate limiting (10 req/60sec)
  - CSRF protection for state-changing operations
  - File-based storage (not in database)
  - Salt values displayed only once (show-once display)
  
- **Current Protections:**
  - Auth: Platform Super Admin only (`is_platform_administrator`)
  - Rate Limiting: 10 requests per 60 seconds per user
  - CSRF: Token validation for POST requests
  - Logging: Only action metadata, NEVER salt values
  - Storage: File-based with restrictive permissions (0600)

**Permission Model:**
- `is_platform_administrator($member)` - Platform Super Admin only
- Requires Owner/SysAdmin role (highest privilege)

**Callers:**
- JS Front-end: `assets/javascripts/platform/serial_salt.js`

### Current Status

**Platform API Migration Progress:**
- ✅ **Migrated:** 12 files (100% of API endpoints)
  - platform_dashboard_api.php, platform_health_api.php, platform_migration_api.php
  - platform_serial_metrics_api.php, admin_org.php, admin_rbac.php
  - member_login.php, run_tenant_migrations.php
  - admin_feature_flags_api.php, platform_roles_api.php, platform_tenant_owners_api.php
  - platform_serial_salt_api.php (CRITICAL, security-sensitive) ✅
- ✅ **Helper/Library Files:** 2 files (N/A)
  - permission.php (function library)
  - bootstrap_migrations.php (CLI tool)

### Next Steps

- ✅ **Core Platform Bootstrap Migration:** 100% Complete!
- 🔄 **Future Tasks:**
  - Consider CoreCliBootstrap for CLI tools (optional)
  - Platform API full modernization (if additional improvements needed)
  - Performance optimization review
  - Integration tests for critical paths
