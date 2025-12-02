📘 Task8.md – Core / Platform API Audit & Protection (Non‑Tenant Layer)

Date: 2025-11-18
Status: ✅ COMPLETED (2025-11-18)
Owner: Bootstrap Project – Phase Finalization
Purpose: สำรวจ (audit) และป้องกันไม่ให้ AI Agent ไป migrate/refactor ไฟล์ Core / Platform สำคัญที่ยังใช้ legacy pattern อยู่ โดยไม่ได้ตั้งใจ พร้อมทั้งบันทึกสถานะให้ชัดเจนว่าไฟล์เหล่านี้ “เป็นส่วนหนึ่งของ ERP / Platform” แต่ **อยู่นอก scope ของ TenantApiBootstrap** รอบนี้

⸻

🎯 เป้าหมายของ Task 8

หลังจาก Bootstrap Migration เสร็จ 100% สำหรับ Tenant APIs (40/40) พบว่ายังมีไฟล์ชุดหนึ่งที่:
- เป็นของ ERP / Platform จริง ๆ (ไม่ใช่ไฟล์ CRM ที่ติดมาด้วย)
- ยังใช้ core setup แบบ legacy (resolve_current_org, tenant_db, new mysqli ฯลฯ)
- ทำหน้าที่ระดับ **Core / Platform / Admin / Migration** ไม่ได้เป็น Hatthasilpa Tenant API โดยตรง

ตัวอย่างไฟล์ที่ตรวจพบ (จากผล scan ล่าสุด):
- source/admin_org.php
- source/admin_rbac.php
- source/bootstrap_migrations.php
- source/member_login.php
- source/permission.php
- source/platform_dashboard_api.php
- source/platform_health_api.php
- source/platform_migration_api.php
- source/platform_serial_metrics_api.php
- source/run_tenant_migrations.php

(จำนวนไฟล์จริงอาจมากกว่าหรือน้อยกว่านี้เล็กน้อย ให้ Agent ยืนยันอีกครั้งใน Step 1)

ปัญหาถ้าไม่จัดการให้ชัดเจน:
- AI Agent รุ่นถัดไปอาจพยายามยัด TenantApiBootstrap เข้าไฟล์เหล่านี้ ซึ่งผิดชั้นของสถาปัตยกรรม
- ทำให้ smoke test / static analysis สแกนไฟล์เกิน scope หรือพยายาม enforce standard ที่ยังไม่ได้ออกแบบ
- เสี่ยงทำให้ login / migration / platform health พัง โดยไม่ตั้งใจ

ดังนั้น Task 8 =
- “บอกให้ชัดว่า ไฟล์ไหนคือ Core/Platform (Non‑Tenant Layer)”
- “ใส่ Guardrails ป้องกัน Agent ไป refactor แบบผิด scope”
- “บันทึกลง discovery/document ว่าจะมี Phase ถัดไปมาดูไฟล์กลุ่มนี้โดยเฉพาะ”

⸻

📦 Scope ของ Task 8

1. ครอบคลุมไฟล์ Core / Platform / Admin / Migration ที่ยังใช้ legacy pattern และ **ไม่มี** TenantApiBootstrap::init()
2. ไม่แตะ business logic / SQL / auth / session / migration logic ใด ๆ
3. ไม่ย้ายไฟล์ไปโฟลเดอร์อื่น (ไฟล์พวกนี้ “ใช้งานจริง” ในระบบ ERP / Platform)
4. สิ่งที่ทำได้ใน Task 8 คือ:
   - Audit + Classify
   - ใส่ header comment อธิบายบทบาทไฟล์
   - อัปเดต discovery/document
   - เสนอแผนสำหรับ Phase ถัดไป (เช่น Task 9 – CoreBootstrap)

⸻

🛠 สิ่งที่ต้องทำใน Task 8

### Step 1 — ให้ Agent Scan และยืนยันรายชื่อ Core / Platform Files

เกณฑ์สำหรับไฟล์ในกลุ่มนี้:
1. ไม่มี TenantApiBootstrap::init()
2. มีการเรียก legacy core setup เช่น:
   - resolve_current_org()
   - tenant_db()
   - new mysqli()
3. หน้าที่ของไฟล์เข้าข่ายอย่างใดอย่างหนึ่ง:
   - Admin / Org / RBAC / Permission
   - Member / Login / Session
   - Platform‑level Dashboard / Health / Metrics
   - Tenant migration / bootstrap / installer
4. ไม่ได้ถูกเรียกใช้โดย UI/flow ของ Hatthasilpa work_queue / token / job ticket โดยตรง (คือไม่ได้เป็น production DAG API)

🧾 Output ที่ต้องส่ง:
- รายชื่อไฟล์ทั้งหมดที่เข้าเกณฑ์ (เช่น 10–13 ไฟล์)
- บทบาทของไฟล์ (เช่น "platform health", "admin org management")
- ประเภท legacy pattern ที่พบในแต่ละไฟล์
- ยืนยันว่าไฟล์เหล่านี้ **ไม่ใช่ Tenant API** แต่เป็น **Core / Platform Layer**

⸻

### Step 2 — เพิ่ม Header Comment บนไฟล์ Core / Platform

ทุกไฟล์ในกลุ่มนี้ ต้องมีคอมเมนต์ block บนหัวไฟล์ เพื่อเป็น guardrail ให้ Agent เข้าใจตรงกันว่า **ห้ามยัด TenantApiBootstrap รอบนี้**:

<?php
/**
 * CORE / PLATFORM FILE (NON-TENANT API)
 * -------------------------------------
 * This file is part of the Bellavier / Hatthasilpa ERP core platform
 * (admin / login / RBAC / migrations / platform metrics).
 *
 * It is NOT a tenant-scoped Hatthasilpa API and MUST NOT be migrated
 * to TenantApiBootstrap in this phase.
 *
 * DO NOT apply TenantApiBootstrap here.
 * DO NOT refactor DB bootstrap or auth/session logic in this task.
 *
 * A dedicated Core/Platform bootstrap will be designed in a future task.
 */

ข้อควรระวัง:
- ห้ามเปลี่ยนโครงสร้าง include/require เดิม
- ห้ามเปลี่ยนวิธี login / session / migration ที่ไฟล์เหล่านี้ใช้
- เป้าหมายคือ **ใส่คำอธิบาย** และ **สร้างรั้วป้องกัน** เท่านั้น

⸻

### Step 3 — อัปเดต Smoke Test / Discovery ให้เข้าใจ Layer ให้ถูกต้อง

#### 3.1 ปรับ Discovery: `docs/bootstrap/tenant_api_bootstrap.discovery.md`

เพิ่ม Section ใหม่ เช่น:

> **Core / Platform Layer (Non‑Tenant, Out of Scope for Task 1–6.1)**
>
> - รายชื่อไฟล์: admin_org.php, admin_rbac.php, bootstrap_migrations.php, member_login.php, permission.php, platform_dashboard_api.php, platform_health_api.php, platform_migration_api.php, platform_serial_metrics_api.php, run_tenant_migrations.php, ฯลฯ
> - บทบาท: admin / login / RBAC / platform / migrations
> - Status: ใช้งานจริง, รอออกแบบ CoreBootstrap แยกใน Task ถัดไป
> - Reason: ไม่ใช่ tenant-scoped API, ห้าม migrate ด้วย TenantApiBootstrap

อัปเดตสถิติให้ชัดเจน:
- Tenant APIs: 40/40 (100%) – migrated & standardized
- Core / Platform Files: ~10–13 (excluded from TenantApiBootstrap scope)

#### 3.2 ปรับเอกสารหลัก: `docs/bootstrap/tenant_api_bootstrap.md`

เพิ่มหัวข้อใหม่ เช่น:

> ### 9. Non‑Tenant Core / Platform Layer
>
> - กลุ่มไฟล์ core / platform (admin, login, migration, platform metrics) จะไม่ถูก migrate มาที่ TenantApiBootstrap ใน Phase นี้
> - จะมีการออกแบบ CoreBootstrap / PlatformBootstrap แยกต่างหากใน Task 9+

⸻

🧱 Guardrails (สำคัญมาก)

**ห้ามทำใน Task 8:**
- ห้าม migrate ไฟล์ Core/Platform ใด ๆ ไปใช้ TenantApiBootstrap
- ห้ามแก้ auth/session/permission/migration logic ในไฟล์เหล่านี้
- ห้ามเปลี่ยนวิธีเชื่อมต่อฐานข้อมูลในไฟล์นี้ให้เหมือน tenant layer โดยพลการ
- ห้ามลบไฟล์เหล่านี้

**อนุญาตเฉพาะ:**
- เพิ่ม header comment
- อัปเดต discovery/docs
- เพิ่มคำอธิบาย role ของไฟล์

⸻

🔎 Step 4 — Verification (ให้ Agent ทำหลังจบ)

Agent ต้องรัน:

```bash
php -l source/admin_org.php
php -l source/admin_rbac.php
php -l source/bootstrap_migrations.php
php -l source/member_login.php
php -l source/permission.php
php -l source/platform_dashboard_api.php
php -l source/platform_health_api.php
php -l source/platform_migration_api.php
php -l source/platform_serial_metrics_api.php
php -l source/run_tenant_migrations.php

php tests/bootstrap/ApiBootstrapSmokeTest.php
vendor/bin/phpunit tests/Unit
vendor/bin/phpunit tests/Integration
```

Smoke Test ต้อง:
- ไม่รายงานไฟล์กลุ่มนี้ว่าเป็น "ขาด TenantApiBootstrap" (เพราะถูกจัดเป็น Core/Platform Layer)
- ยืนยันว่า Tenant APIs 40 ไฟล์ยังผ่านเหมือนเดิม

⸻

📌 Output ที่ต้องส่งกลับเมื่อทำ Task 8 เสร็จ

Agent ต้องส่งกลับ:
1. รายชื่อไฟล์ Core / Platform ที่ยืนยันแล้ว (พร้อม role ของแต่ละไฟล์)
2. จำนวนไฟล์ที่เพิ่ม header comment สำเร็จ
3. รายการอัปเดตใน `tenant_api_bootstrap.discovery.md`
4. รายการอัปเดตใน `tenant_api_bootstrap.md`
5. Log การรัน Smoke Test + PHPUnit ที่ผ่านทั้งหมด
6. ประโยคสุดท้าย:

> ERP Tenant API Layer is 100% migrated. Core / Platform Layer is now clearly classified and protected from accidental TenantApiBootstrap migration.

---

## ✅ Completion Summary (2025-11-18)

### Step 1: Core / Platform Files Classification ✅

**10 Core / Platform Files Identified:**

1. `source/admin_org.php` - Admin Organizations Management (Platform-level)
2. `source/admin_rbac.php` - Admin RBAC Management (Platform + Tenant)
3. `source/bootstrap_migrations.php` - Migration Bootstrap (Core)
4. `source/member_login.php` - Member Login API (Core Authentication)
5. `source/permission.php` - Permission Helper (Core)
6. `source/platform_dashboard_api.php` - Platform Dashboard (Platform-level)
7. `source/platform_health_api.php` - Platform Health Check (Platform-level)
8. `source/platform_migration_api.php` - Platform Migration API (Platform-level)
9. `source/platform_serial_metrics_api.php` - Platform Serial Metrics (Platform-level)
10. `source/run_tenant_migrations.php` - Tenant Migrations Runner (Tenant-scoped but Migration tool)

**Classification:**
- All files are part of the Bellavier / Hatthasilpa ERP core platform
- NOT tenant-scoped Hatthasilpa APIs
- Handle platform-level operations (admin, login, RBAC, migrations, platform metrics)
- MUST NOT be migrated to TenantApiBootstrap in this phase

### Step 2: Header Comments Added ✅

**10 files updated with "CORE / PLATFORM FILE (NON-TENANT API)" header:**
- ✅ admin_org.php
- ✅ admin_rbac.php
- ✅ bootstrap_migrations.php
- ✅ member_login.php
- ✅ permission.php
- ✅ platform_dashboard_api.php
- ✅ platform_health_api.php
- ✅ platform_migration_api.php
- ✅ platform_serial_metrics_api.php
- ✅ run_tenant_migrations.php

### Step 3: Documentation Updated ✅

**Files Updated:**
1. ✅ `tests/bootstrap/ApiBootstrapSmokeTest.php`
   - Added Core/Platform files exclusion list
   - Added Test 4.1: Core / Platform files verification
   - Updated Test 5: Exclude Core/Platform files from legacy pattern checks

2. ✅ `docs/bootstrap/tenant_api_bootstrap.discovery.md`
   - Added Section 11.3: Core / Platform Layer (Non-Tenant, Out of Scope)
   - Listed all 10 Core/Platform files with roles
   - Updated Next Steps to include Task 8 completion

3. ✅ `docs/bootstrap/tenant_api_bootstrap.md`
   - Added Section 9: Non-Tenant Core / Platform Layer
   - Listed all 10 Core/Platform files
   - Documented protection status and future plans

4. ✅ `docs/bootstrap/Task/task8.md`
   - Updated status to ✅ COMPLETED (2025-11-18)
   - Added completion summary

### Step 4: Verification ✅

**Syntax Check:**
- All 10 Core/Platform files pass PHP syntax validation

**Smoke Test:**
- Core/Platform files correctly identified and excluded from TenantApiBootstrap checks
- Tenant APIs (40 files) still pass all smoke test validations
- Legacy pattern detection excludes Core/Platform files as expected

**PHPUnit Tests:**
- All Unit tests pass
- All Integration tests pass

### Final Status

✅ **Task 8 Complete:**
- 10 Core/Platform files classified and protected
- Header comments added to all files
- Smoke test updated to exclude Core/Platform files
- Documentation updated in discovery and main docs
- All verification tests pass

**Result:**
> ERP Tenant API Layer is 100% migrated. Core / Platform Layer is now clearly classified and protected from accidental TenantApiBootstrap migration.
