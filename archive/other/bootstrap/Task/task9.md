# Task 9 – Core / Platform Bootstrap Design (CoreApiBootstrap)

**Status:** ✅ COMPLETED (2025-11-18)  
**Owner:** AI Agent (Bellavier ERP Bootstrap Track)  
**Created:** 2025-11-18  
**Depends On:**  
- ✅ Task 1–6.1 – TenantApiBootstrap + Tenant API Migration (40/40 APIs done)  
- ✅ Task 8 – Core / Platform API Audit & Protection (mark files as NON-TENANT)

---

## 1. เป้าหมาย (Goal)

ออกแบบ **Core / Platform Bootstrap** สำหรับไฟล์ระดับแพลตฟอร์ม (non-tenant APIs) ให้เป็นมาตรฐานเดียวกัน เหมือนที่ `TenantApiBootstrap` ทำให้ชั้น Hatthasilpa Tenant API แล้ว แต่ **ยังไม่ลงมือ refactor โค้ดจริง** ใน Task นี้

สรุปคือ Task 9 = **“Design & Spec”**  
Task ถัดไป (เช่น Task 10+) ค่อยเป็น **Implementation + Migration**

---

## 2. ขอบเขต (Scope)

ไฟล์กลุ่ม **Core / Platform Layer** ที่ถูก mark แล้วใน discovery:

1. `source/admin_org.php` – Admin Organizations Management (Platform-level)
2. `source/admin_rbac.php` – Admin RBAC Management (Platform + Tenant)
3. `source/bootstrap_migrations.php` – Migration Bootstrap (Core)
4. `source/member_login.php` – Member Login API (Core Authentication)
5. `source/permission.php` – Permission Helper (Core)
6. `source/platform_dashboard_api.php` – Platform Dashboard (Platform-level)
7. `source/platform_health_api.php` – Platform Health Check (Platform-level)
8. `source/platform_migration_api.php` – Platform Migration API (Platform-level)
9. `source/platform_serial_metrics_api.php` – Platform Serial Metrics (Platform-level)
10. `source/run_tenant_migrations.php` – Tenant Migrations Runner (Tool)

**ทั้งหมดนี้:**
- คือไฟล์ของ ERP จริง ๆ (ไม่ใช่ CRM legacy)
- แต่เป็น **Core / Platform**, ไม่ใช่ **Hatthasilpa Tenant API**
- ใน Task 9: แค่ *สำรวจ + ออกแบบ Bootstrap Concept* สำหรับ layer นี้

---

## 3. สิ่งที่ห้ามทำใน Task 9 (Non-Goals / Guardrails)

ใน Task 9 **ห้าม** ทำสิ่งเหล่านี้:

1. ❌ ห้ามแก้ไข behavior ของ:
   - `member_login.php` (flow login)
   - `permission.php` (RBAC / permission logic)
   - script migration ต่าง ๆ (`bootstrap_migrations.php`, `run_tenant_migrations.php`, `platform_migration_api.php`)

2. ❌ ห้าม migrate ไฟล์เหล่านี้ไปใช้ `TenantApiBootstrap::init()`  
   (มันเป็นคนละ layer กัน)

3. ❌ ห้ามเขียนโค้ดเปลี่ยนแปลงในไฟล์ source/ เหล่านี้ใน Task 9  
   - ทำได้แค่ “อ่าน → วิเคราะห์ → เขียน spec/design เป็นเอกสาร”
   - ถ้าจะสร้าง class ใหม่ เช่น `CoreApiBootstrap` ให้เป็นแค่ skeleton / sample ในเอกสารเท่านั้น หรือวางแผนไว้ใน Task 10

4. ❌ ห้ามแตะ session/auth/permission logic ในเชิง implementation  
   - Task นี้ออกแบบระดับ **concept + interface** เท่านั้น

---

## 4. เป้าหมายเชิงเทคนิค

1. นิยาม concept ของ **Core / Platform Bootstrap** ให้ชัดว่า:
   - รับผิดชอบอะไรบ้าง  
   - ต่างจาก `TenantApiBootstrap` อย่างไร  
   - ขอบเขตของมัน (session, auth, org, core_db, logging, correlation id ฯลฯ)

2. สรุป “pattern ปัจจุบัน” ที่ไฟล์ Core ใช้อยู่ เช่น:
   - `session_start()`, `require_once`, `core_db()`, `memberDetail()`, `permission_check()`, etc.
   - header / JSON response / error handling pattern
   - log + correlation id (ถ้ามี)

3. ออกแบบ interface เบื้องต้นของ class ใหม่ เช่น:
   - `BGERP\Bootstrap\CoreApiBootstrap`
   - และ/หรือ helper เพิ่มเติม เช่น `CoreConnectionHelper`, `CoreJsonResponse` (ถ้าจำเป็น)

4. จัดทำ **spec design document** แยกต่างหาก:
   - `docs/bootstrap/core_platform_bootstrap.design.md`
   - บอกโครงสร้าง target แบบละเอียด + ตัวอย่าง usage

---

## 5. แผนการทำงาน (Steps)

### Step 1 – Static Scan & Classification (Read-only)

**เป้าหมาย:** map ให้ชัดว่า Core/Platform แต่ละไฟล์ใช้ pattern แบบไหน

ให้ Agent ทำ:

1. เปิดไฟล์ทีละตัว (10 ไฟล์ใน scope)
2. จด pattern สำคัญต่อไปนี้ (ไม่ต้องแก้โค้ด):
   - การ setup autoload + config (`vendor/autoload.php`, `config.php`, `global_function.php`)
   - auth & session:
     - ใช้ `session_start()` เอง หรือ autoload?
     - ใช้ `memberDetail` / `$objMemberDetail->thisLogin()` ตรง ๆ หรือผ่าน helper อื่น?
   - DB:
     - มีใช้ `core_db()` หรือ `tenant_db()` หรือ `DatabaseHelper` ตรง ๆ ไหม
     - ถ้ามี multi-tenant context ในไฟล์ platform_xxx ให้จดไว้
   - JSON / header:
     - ใช้ `json_error/json_success` ไหม หรือ set header เอง
   - permission:
     - ใช้ `permission.php` / ฟังก์ชันอะไรในการตรวจสิทธิ์
3. แยกเป็นกลุ่ม:
   - **Group A – Auth / RBAC / Org Admin**
     - `admin_org.php`, `admin_rbac.php`, `member_login.php`, `permission.php`
   - **Group B – Platform APIs**
     - `platform_dashboard_api.php`, `platform_health_api.php`, `platform_migration_api.php`, `platform_serial_metrics_api.php`
   - **Group C – Migration Tools**
     - `bootstrap_migrations.php`, `run_tenant_migrations.php`

ผลลัพธ์ Step 1 = ตาราง summary ในเอกสาร design (ชื่อและ pattern ของแต่ละไฟล์)

---

### Step 2 – Define Core / Platform Bootstrap Responsibilities

จาก pattern ที่เก็บใน Step 1 ให้ Agent นิยามว่า **CoreApiBootstrap** ควรรับผิดชอบอะไรบ้าง เช่น:

- โหลด autoload + config + global_function (เหมือน TenantApiBootstrap)
- เตรียม **core-level DB connection** (แทน `core_db()` ตรง ๆ หรือ wrap)
- เตรียม **$member / session context** (ถ้า route นั้นต้อง login)
- เตรียม **org context** (ถ้ามี multi-tenant บางส่วนใน platform layer)
- ติดตั้ง header พื้นฐาน เช่น:
  - `Content-Type: application/json; charset=utf-8`
  - `X-Correlation-Id`
- เตรียม **error handling baseline** (อาจ reuse `JsonResponse` หรือ define rule การใช้)

และต้อง define ว่าแต่ละ **Group** (A/B/C) ควรใช้ bootstrap แบบไหน เช่น:

- Group A (auth/RBAC/admin) → ต้อง require login + permission
- Group B (platform APIs) → require platform-level permission, อาจต้อง allow integration keys
- Group C (migration tools) → อาจมี mode CLI vs Web, ไม่ใช้ login ปกติ

ผลลัพธ์ Step 2 = Section “CoreApiBootstrap Responsibilities & Modes” ใน design doc

---

### Step 3 – Draft Target Interface (CoreApiBootstrap)

ออกแบบ interface (ยังไม่ต้อง implementใน source):

เช่น:

```php
namespace BGERP\Bootstrap;

use BGERP\Helper\DatabaseHelper;

final class CoreApiBootstrap
{
    /**
     * Initialize core/platform API context.
     *
     * @param array $options {
     *   @var bool   $requireAuth        Require logged-in member (default: true)
     *   @var bool   $requireTenant      Require tenant/org context (default: false)
     *   @var array  $requiredPermissions List of permission keys (default: [])
     *   @var bool   $jsonResponse       Setup JSON headers (default: true)
     * }
     *
     * @return array [$member, $coreDb, $org]
     */
    public static function init(array $options = []): array
    {
        // design only in Task 9 (pseudo-code in docs)
    }
}

สิ่งที่ต้องระบุใน spec:
	•	parameter / options ที่รองรับ
	•	return values (ตัวแปรหลักที่ใช้บ่อย เช่น $member, $coreDb, $org)
	•	behavior เมื่อ:
	•	ไม่ได้ login แต่ $requireAuth = true
	•	ไม่มี org แต่ $requireTenant = true
	•	ไม่มี permission ตาม $requiredPermissions
	•	ความสัมพันธ์กับ:
	•	TenantApiBootstrap::init() (ห้าม recursive / ห้าม conflict)
	•	global functions เดิม (core_db(), resolve_current_org())

สำคัญ: Task นี้อยู่ในระดับ design
Agent ควรเขียนตัวอย่าง usage ด้วย เช่น:

// Example usage in platform_dashboard_api.php (future Task 10):
[$member, $coreDb, $org] = CoreApiBootstrap::init([
    'requireAuth'        => true,
    'requireTenant'      => false,
    'requiredPermissions'=> ['platform.dashboard.view'],
]);


⸻

Step 4 – Define Migration Strategy (High-level Only)

ยังไม่ลงมือ migrate แต่ต้องตอบคำถาม:
	1.	ไฟล์ไหนน่าจะ migrate ก่อนหลัง ใน phase CoreBootstrap:
	•	เช่น Group B (platform_*_api.php) ก่อน Group A (admin/login/rbac)
	2.	ระดับความเสี่ยงของแต่ละ group:
	•	Login & permission = high risk → ต้องมี phase แยก
	•	Migration tools = medium risk แต่ใช้ไม่บ่อยใน runtime
	3.	ความสัมพันธ์กับ TenantApiBootstrap:
	•	ต้องไม่ไปยุ่งกับ tenant API layer ที่ทำเสร็จแล้ว
	•	แยก namespace, responsibility ชัดเจน

ผลลัพธ์ Step 4 = Section “Migration Strategy (Core Layer)” ใน design doc
ใช้ format คล้าย Task 3–6 แต่เป็นระดับ high-level

⸻

Step 5 – Documentation Updates

ให้ Agent อัปเดตเอกสารต่อไปนี้ (ใน Task 9):
	1.	docs/bootstrap/core_platform_bootstrap.design.md
	•	สร้างไฟล์ใหม่นี้
	•	ใส่เนื้อหาจาก Step 1–4
	•	ทำเป็น “design spec” แบบอ่านแล้ว implement Task 10 ต่อได้เลย
	2.	docs/bootstrap/tenant_api_bootstrap.discovery.md
	•	เพิ่ม Section ใหม่ใน Chapter 11:
	•	11.x – Core / Platform Bootstrap Design (Task 9)
	•	ปรับ “Next Steps” ให้ระบุ Task 10 = CoreBootstrap Implementation
	3.	docs/bootstrap/tenant_api_bootstrap.md
	•	เพิ่ม short note เชื่อมโยง:
	•	TenantApiBootstrap = สำหรับ Tenant APIs
	•	CoreApiBootstrap (design-only) = สำหรับ Core/Platform layer (แผนใน Task 9)

ข้อสำคัญ: Task 9 ไม่ควรแตะไฟล์ source/*.php
ทุกอย่างอยู่ในระดับ “เอกสาร + design”

⸻

6. Deliverables

เมื่อ Task 9 เสร็จสมบูรณ์ ควรมี:
	1.	✅ docs/bootstrap/Task/task9.md (ไฟล์นี้) – อัพเดทเป็น Status: COMPLETED
	2.	✅ docs/bootstrap/core_platform_bootstrap.design.md
	•	Inventory + pattern ของไฟล์ Core/Platform ทั้งหมด
	•	Spec ของ CoreApiBootstrap (interface + behavior)
	•	Strategy การ migrate (แผนคร่าว ๆ สำหรับ Task 10+)
	3.	✅ อัพเดท:
	•	docs/bootstrap/tenant_api_bootstrap.discovery.md – เพิ่ม section Task 9
	•	docs/bootstrap/tenant_api_bootstrap.md – mention CoreApiBootstrap ในภาพรวม

⸻

7. Checklist สำหรับ Agent
	•	อ่านไฟล์ Core/Platform ทั้ง 10 ไฟล์ (read-only)
	•	สร้างตาราง summary patterns ลงใน core_platform_bootstrap.design.md
	•	นิยาม responsibilities ของ CoreApiBootstrap ให้ชัด
	•	Draft interface (signature, options, return values) ใน design doc
	•	เขียนตัวอย่าง usage 2–3 ไฟล์ (platform_xxx, admin_xxx, migration_xxx)
	•	นิยาม migration strategy เบื้องต้น (phase, risk)
	•	อัปเดต discovery + main bootstrap docs ให้ reflect Task 9
	•	เปลี่ยนสถานะ Task 9 เป็น COMPLETED เมื่อทุกอย่างเรียบร้อย

⸻

หมายเหตุสำคัญ:
Task 9 = "คิดให้จบก่อนลงมือ"
เพื่อไม่ให้ไปแตะ auth/login/permission/migration core logic แบบสุ่มสี่สุ่มห้า แล้วค่อยมี Task 10 สำหรับลงมือ implement จริงอย่างเป็นระบบ

---

## ✅ Completion Summary (2025-11-18)

### Step 1: Static Scan & Classification ✅

**10 Core/Platform Files Analyzed:**
- Group A (Auth/RBAC/Admin): 4 files
- Group B (Platform APIs): 4 files
- Group C (Migration Tools): 2 files

**Patterns Documented:**
- Session management patterns
- Authentication patterns
- Database connection patterns (Core DB, Tenant DB)
- Permission check patterns
- Response format patterns (JSON, plain text)
- Header patterns (Correlation ID, Content-Type)

**See:** `docs/bootstrap/core_platform_bootstrap.design.md` Section 2 for complete inventory

### Step 2: CoreApiBootstrap Responsibilities ✅

**Responsibilities Defined:**
- Autoload & Configuration
- Session Management
- Database Connections (Core DB, optional Tenant DB)
- Authentication (with public endpoint support)
- Permission Checks (multiple patterns)
- Headers & Response (JSON, plain text)
- Error Handling (standardized)
- Maintenance Mode

**Modes Defined:**
- Mode 1: Auth Required (default)
- Mode 2: Public (no auth)
- Mode 3: Platform Admin Only
- Mode 4: CLI Mode
- Mode 5: Tenant Context Optional

**See:** `docs/bootstrap/core_platform_bootstrap.design.md` Section 3 for details

### Step 3: Target Interface Design ✅

**CoreApiBootstrap Interface:**
```php
CoreApiBootstrap::init(array $options = []): array
```

**Options:**
- `requireAuth` (bool, default: true)
- `requirePlatformAdmin` (bool, default: false)
- `requiredPermissions` (array, default: [])
- `requireTenant` (bool, default: false)
- `jsonResponse` (bool, default: true)
- `cliMode` (bool, default: false)
- `correlationId` (string, optional)

**Return Values:**
- `$member` (array|null)
- `$coreDb` (DatabaseHelper)
- `$tenantDb` (DatabaseHelper|null)
- `$org` (array|null)
- `$cid` (string)

**Usage Examples:**
- Platform Dashboard API
- Admin Org API
- Member Login API (public)
- Platform Serial Metrics API (with tenant context)
- Bootstrap Migrations (CLI mode)

**See:** `docs/bootstrap/core_platform_bootstrap.design.md` Section 4 for complete interface specification

### Step 4: Migration Strategy ✅

**5-Phase Migration Plan:**
1. **Phase 1 (Low Risk):** Platform APIs (Group B) - 3 files
2. **Phase 2 (Medium Risk):** Platform Serial Metrics - 1 file
3. **Phase 3 (High Risk):** Admin APIs (Group A) - 2 files
4. **Phase 4 (Very High Risk):** Auth & Permission - 2 files (may keep as-is)
5. **Phase 5 (High Risk):** Migration Tools (Group C) - 2 files

**Risk Assessment:**
- Group B: Low risk (read-only, standardized)
- Group A: High risk (critical operations)
- Group C: High risk (infrastructure)
- Auth/Permission: Very high risk (core security)

**See:** `docs/bootstrap/core_platform_bootstrap.design.md` Section 5 for complete strategy

### Step 5: Documentation Updates ✅

**Files Created/Updated:**
1. ✅ `docs/bootstrap/core_platform_bootstrap.design.md` (NEW)
   - Complete design specification
   - File inventory and patterns
   - Interface design
   - Migration strategy
   - Usage examples

2. ✅ `docs/bootstrap/tenant_api_bootstrap.discovery.md`
   - Added Section 11.4: Core / Platform Bootstrap Design (Task 9)
   - Updated Next Steps

3. ✅ `docs/bootstrap/tenant_api_bootstrap.md`
   - Added note about CoreApiBootstrap design
   - Linked to design document

4. ✅ `docs/bootstrap/Task/task9.md` (this file)
   - Updated status to ✅ COMPLETED
   - Added completion summary

### Deliverables ✅

1. ✅ `docs/bootstrap/core_platform_bootstrap.design.md` - Complete design specification
2. ✅ `docs/bootstrap/tenant_api_bootstrap.discovery.md` - Updated with Task 9 section
3. ✅ `docs/bootstrap/tenant_api_bootstrap.md` - Updated with CoreApiBootstrap note
4. ✅ `docs/bootstrap/Task/task9.md` - Updated status and completion summary

### Final Status

✅ **Task 9 Complete:**
- Design specification complete
- Interface defined with all modes and options
- Migration strategy defined (5 phases, risk-based)
- Documentation updated
- Ready for Task 10 (Implementation)

**Next Steps:**
- Task 10: Implement `CoreApiBootstrap` class
- Task 11+: Migrate Core/Platform APIs following the defined strategy
