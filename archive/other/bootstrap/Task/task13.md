# Task 13 – Core Platform Bootstrap Discovery (Admin / Login / RBAC / Platform Core)

**Status:** ✅ COMPLETED (2025-11-18)

## 0. Context / Why

ตอนนี้:

- Tenant APIs ทั้งหมดถูก migrate ไปใช้ `TenantApiBootstrap::init()` ครบแล้ว (Task 1–6.1)
- มี `CoreApiBootstrap` ถูกใช้งานจริงแล้วในไฟล์:
  - `source/platform_serial_metrics_api.php` (Task 12)
- ยังมี **Core / Platform files สำคัญ** ที่ยังใช้ bootstrap แบบ legacy อยู่ เช่น:
  - `admin_org.php`
  - `admin_rbac.php`
  - `bootstrap_migrations.php`
  - `member_login.php`
  - `permission.php`
  - `platform_dashboard_api.php`
  - `platform_health_api.php`
  - `platform_migration_api.php`
  - `run_tenant_migrations.php`
  - (และอาจมีไฟล์ core อื่น ๆ ที่ยังไม่ได้สำรวจ)

**Task 13 = ยังไม่แตะโค้ด**  
แต่จะทำหน้าที่เป็น **“Discovery + Mapping + Planning”** สำหรับ Core / Platform bootstrap ทั้งก้อน เพื่อเตรียมแตกเป็น Task 14, 15… สำหรับงานลงมือ refactor จริง ๆ โดยไม่พัง login / RBAC / migration เดิม

> เป้าหมาย: ได้ภาพรวมชัดเจนว่า “Core / Platform ชั้นล่างสุดของ ERP มีไฟล์อะไรบ้าง, ทำหน้าที่อะไร, เสี่ยงแค่ไหน, และควร migrate ด้วย CoreApiBootstrap แบบไหน / ลำดับใด”

---

## 1. Goal / Output

### เป้าหมายหลัก

1. **ทำ inventory ไฟล์ Core / Platform ทั้งหมด** ที่เกี่ยวข้องกับ:
   - Admin / Org
   - RBAC / Permission
   - Authentication / Login
   - Platform Health / Dashboard / Metrics
   - Migrations (bootstrap + run)
2. **จัดหมวด + ระดับความเสี่ยง** ของแต่ละไฟล์:
   - ชนิดไฟล์: `AUTH`, `RBAC`, `ADMIN_UI`, `PLATFORM_API`, `MIGRATION`, `UTILITY`
   - Risk: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`
3. **วิเคราะห์ bootstrap pattern ปัจจุบัน**:
   - ใช้ `CoreApiBootstrap` แล้วหรือยัง?
   - ใช้ `config.php` + `resolve_current_org()` + `tenant_db()` แบบเก่า?
   - ใช้ `json_error/json_success` ตรง ๆ?
4. **ออกแบบ Roadmap การ migrate ในอนาคต**:
   - แบ่งเป็น Phase / Task ย่อย (เช่น Task 14, 15, …)
   - Define ว่าไฟล์ไหนอยู่ Phase ไหน และต้องใช้ guardrails แบบไหน
5. เขียนผลทั้งหมดลงใน:
   - `docs/bootstrap/core_platform_bootstrap.discovery.md` (ใหม่)

---

## 2. Scope

### In Scope

- เฉพาะ **Discovery + Documentation**:
  - สแกนไฟล์ PHP ที่เป็น core/platform layer (ไม่ใช่ tenant APIs)
  - อ่านโค้ด, วิเคราะห์ pattern, จดโน้ต, สรุปเป็นตาราง + bullet
- ใช้ `php -l` / `grep` / `ls` / `wc` ได้ตามปกติ
- ใช้ `CoreApiBootstrap` implementation ปัจจุบันของ `platform_serial_metrics_api.php` เป็น **reference** ในการอธิบาย pattern

### Out of Scope (ห้ามทำใน Task 13)

- ❌ ห้ามแก้ไขไฟล์ PHP ใด ๆ (ไม่มี code change)
- ❌ ห้ามแก้ login / session / auth / RBAC / migration logic
- ❌ ห้ามเพิ่ม `CoreApiBootstrap` เข้าไฟล์อื่นใน task นี้
- ❌ ห้ามเปลี่ยน behavior จริงของระบบใน runtime

---

## 3. Guardrails / ห้ามแตะอะไร

1. **Auth / Login / Session**
   - `member_login.php`
   - `permission.php`
   - อะไรก็ตามที่มีคำว่า `login`, `session`, `must_login`, `auth` → อ่านได้, แต่อย่าแก้
2. **RBAC / Admin**
   - `admin_rbac.php`
   - `admin_org.php`
   - ฟังก์ชันอย่าง `must_allow()`, `must_admin()` → แค่บันทึกว่ามี, ห้าม refactor
3. **Migration Scripts**
   - `bootstrap_migrations.php`
   - `run_tenant_migrations.php`
   - อื่น ๆ ที่เกี่ยวข้องกับ migration / schema → อ่านได้อย่างเดียว
4. **CoreApiBootstrap เอง**
   - ห้ามแก้ class `CoreApiBootstrap` ใน task นี้
   - ใช้เพื่ออ้างอิง pattern อย่างเดียว

---

## 4. Files of Interest (เริ่มต้นจากชุดที่รู้อยู่แล้ว)

ให้ Agent ใช้ list นี้เป็น “seed” แล้วค้นต่อถ้ามีไฟล์อื่นที่เกี่ยวข้อง:

- `source/admin_org.php`
- `source/admin_rbac.php`
- `source/bootstrap_migrations.php`
- `source/member_login.php`
- `source/permission.php`
- `source/platform_dashboard_api.php`
- `source/platform_health_api.php`
- `source/platform_migration_api.php`
- `source/platform_serial_metrics_api.php` (อันนี้เป็น reference ที่ migrate แล้ว)
- `source/run_tenant_migrations.php`

ถ้าพบไฟล์อื่นที่เข้าข่าย “core / platform” (เช่น มีคำว่า `platform_`, `admin_`, `bootstrap_` ในชื่อไฟล์) ให้บันทึกเพิ่มด้วย

---

## 5. Step-by-Step Plan สำหรับ AI Agent

### Step 1 – เตรียมไฟล์ Discovery

1. ถ้ายังไม่มีไฟล์:
   - สร้าง `docs/bootstrap/core_platform_bootstrap.discovery.md`
2. ใส่โครงสร้างเบื้องต้น:

   ```markdown
   # Core Platform Bootstrap – Discovery

   ## 1. Overview
   (สรุปว่าไฟล์นี้สำหรับรวบรวมข้อมูล Core / Platform bootstrap)

   ## 2. File Inventory (High-level)
   (ตารางรายชื่อไฟล์ + ประเภทคร่าว ๆ)

   ## 3. Detailed File Notes
   (subsection แยกตามไฟล์)

   ## 4. Bootstrap Patterns
   (list รูปแบบ bootstrap ที่พบ)

   ## 5. Migration Roadmap Proposal
   (Phase / Task สำหรับอนาคต)

   ## 6. Status & Next Steps

Step 2 – สแกนไฟล์ Core / Platform
	1.	รันคำสั่งเช็คไฟล์ที่คาดว่าเป็น core/platform:
	•	เช่น:
	•	รายชื่อไฟล์ admin_*.php, platform_*.php, bootstrap_*.php, run_*migrations*.php
	•	หรือใช้ ls source/*platform*php / ls source/admin_* ฯลฯ
	2.	บันทึกรายชื่อไฟล์ลงใน Section 2. File Inventory ในรูปแบบตาราง เช่น:

#	File	Type (guess)	Notes
1	source/admin_org.php	ADMIN_UI	Org management screen
2	source/platform_dashboard_api.php	PLATFORM_API	JSON dashboard for platform overview
…	…	…	…


	3.	ทำให้มั่นใจว่าไฟล์ seed ทั้งหมด 10 ไฟล์อยู่ในตารางแน่นอน

Step 3 – วิเคราะห์ทีละไฟล์ (Detailed Notes)

สำหรับแต่ละไฟล์ใน list:

ให้ Agent เปิดอ่านและเติมใน Section 3. Detailed File Notes โดยใช้ template เดียวกันทุกไฟล์ เช่น:

### source/platform_dashboard_api.php

- **Role**: PLATFORM_API
- **Risk Level**: HIGH (อ่าน metrics ระดับ platform, ใช้ permission ไหน?)
- **Entry Type**: HTTP JSON API (ไม่ใช่ CLI)
- **Bootstrap Pattern**:
  - require: `config.php` / `vendor/autoload.php` (ระบุให้ชัด)
  - ใช้ `CoreApiBootstrap` หรือไม่: (yes/no)
  - ใช้ `resolve_current_org()` / `tenant_db()` หรือไม่
- **DB Access**:
  - ใช้ `DatabaseHelper` / `$mysqli` / raw PDO / อื่น ๆ
  - แตะทั้ง core DB และ tenant DB หรือไม่
- **Auth / Permission**:
  - ใช้ `must_login()`, `must_allow()`, หรือ custom check อื่น ๆ
  - permission string: เช่น `platform.view.metrics`, `platform.admin`, ฯลฯ
- **Special Coupling / Notes**:
  - ผูกกับระบบ ERP ส่วนไหนบ้าง (เช่น serial, migration, login)
  - มี guardrails หรือ comments สำคัญในไฟล์หรือไม่
- **Candidate Bootstrap Strategy (future)**:
  - เช่น "ควรใช้ CoreApiBootstrap", "ควรทำ CoreCliBootstrap แยกสำหรับ CLI", ฯลฯ

สำคัญ: ยังไม่ต้อง implement Strategy เหล่านี้ใน Task 13
แค่เขียนเป็น “ข้อเสนอ / observation” ให้ทีมใช้ตัดสินใจตอน Task 14+

Step 4 – สรุป Bootstrap Patterns ที่พบ

ใน Section 4. Bootstrap Patterns ให้ Agentสรุป:
	•	Pattern ปัจจุบันที่พบ เช่น:
	•	require_once '../config.php'; + manual $db = new DatabaseHelper(...)
	•	ใช้ CoreApiBootstrap (เฉพาะ platform_serial_metrics_api.php)
	•	ใช้ global function json_error/json_success ตรง ๆ
	•	ปัญหาที่อาจเกิดจากความไม่สม่ำเสมอ:
	•	บางไฟล์ใช้ tenant DB แบบผิดมาตรฐาน
	•	บางไฟล์ทำ auth check ก่อน / หลัง bootstrap
	•	บางไฟล์เป็น CLI แต่ใช้ pattern แบบเว็บ

Step 5 – วาง Migration Roadmap

ใน Section 5. Migration Roadmap Proposal:
	1.	แบ่งเป็น Phase / Task ย่อย:
ตัวอย่าง:
	•	Phase 1 – Read-only Platform APIs
	•	platform_dashboard_api.php
	•	platform_health_api.php
	•	platform_serial_metrics_api.php (reference, no change)
	•	Phase 2 – Migrations & Platform Tools
	•	platform_migration_api.php
	•	bootstrap_migrations.php
	•	run_tenant_migrations.php
	•	Phase 3 – Admin UI / RBAC (High Risk)
	•	admin_org.php
	•	admin_rbac.php
	•	permission.php
	•	Phase 4 – Authentication / Login (Very High Risk)
	•	member_login.php
	2.	สำหรับแต่ละ Phase ให้ระบุ:
	•	เป้าหมายของ Phase
	•	แนวคิด bootstrap ที่เหมาะสม:
	•	CoreApiBootstrap (สำหรับ HTTP JSON API)
	•	อาจต้องออกแบบ CoreCliBootstrap แยก (สำหรับ CLI / migration)
	•	Guardrails ที่จำเป็น (เช่น ห้ามเปลี่ยน behavior ของ login / RBAC)

Step 6 – Status & Next Steps

ใน Section 6. Status & Next Steps:
	•	สรุปว่า Task 13 = Discovery only, no code change
	•	ระบุว่าเอกสารนี้จะเป็น input ให้ Task 14+ เช่น:
	•	Task 14 – CoreApiBootstrap rollout for platform_*_api.php (read-only metrics)
	•	Task 15 – Core CLI Bootstrap design (bootstrap_migrations.php, run_tenant_migrations.php)
	•	Task 16 – RBAC / Admin UI Hardening
	•	Task 17 – Login / Auth Hardening and Bootstrap

⸻

6. Definition of Done (DoD)

Task 13 ถือว่า สำเร็จ เมื่อ:
	1.	มีไฟล์: docs/bootstrap/core_platform_bootstrap.discovery.md และมีเนื้อหาครบ:
	•	Overview
	•	File Inventory Table
	•	Detailed Notes สำหรับไฟล์ core/platform ทุกไฟล์ใน scope
	•	Bootstrap Patterns Summary
	•	Migration Roadmap Proposal
	•	Status & Next Steps
	2.	ไม่มีไฟล์ PHP ใด ๆ ถูกแก้ไข
	3.	php -l ผ่านทุกไฟล์ (ไม่มี syntax error ใหม่เกิดขึ้น)
	4.	บันทึก phase / task ที่เสนอสำหรับอนาคตชัดเจน (อย่างน้อย Phase 1–4)

---

## Completion Summary (2025-11-18)

**Status:** ✅ COMPLETED

### Discovery Results

**Files Analyzed:** 15 Core/Platform files

**Migration Status:**
- ✅ **Migrated to CoreApiBootstrap:** 8 files (53.3%)
  - admin_org.php, admin_rbac.php, member_login.php
  - platform_dashboard_api.php, platform_health_api.php, platform_migration_api.php
  - platform_serial_metrics_api.php, run_tenant_migrations.php
- ❌ **Legacy Pattern:** 6 files (40.0%)
  - admin_feature_flags_api.php, platform_roles_api.php, platform_serial_salt_api.php
  - platform_tenant_owners_api.php
  - permission.php (helper library, N/A)
  - bootstrap_migrations.php (CLI tool, N/A)
- 🔄 **N/A (Helper/Library):** 1 file (6.7%)
  - permission.php (function library)

### Key Findings

1. **Bootstrap Patterns Found:**
   - Pattern 1: CoreApiBootstrap (Modern) - 8 files
   - Pattern 2: Legacy Bootstrap - 6 files

2. **Migration Roadmap Created:**
   - Phase 1: ✅ COMPLETED (Task 12) - 4 Platform APIs standardized
   - Phase 2: 🔄 PENDING (Task 14) - 3 medium-risk Platform APIs
   - Phase 3: 🔄 PENDING (Task 15) - 1 critical security-sensitive API
   - Phase 4: ✅ N/A - Helper files (no migration needed)

3. **Priority Matrix:**
   - **P0 (Critical):** platform_serial_salt_api.php (security-sensitive)
   - **P1 (High):** admin_feature_flags_api.php, platform_roles_api.php, platform_tenant_owners_api.php
   - **P2 (N/A):** permission.php, bootstrap_migrations.php (helper files)

### Deliverables

1. ✅ Created `docs/bootstrap/core_platform_bootstrap.discovery.md`
   - Complete file inventory (15 files)
   - Detailed notes for each file
   - Bootstrap pattern analysis
   - Migration roadmap proposal
   - Current statistics and next steps

2. ✅ No code changes (Discovery only)

3. ✅ All syntax checks passed

4. ✅ Migration roadmap defined (Task 14-15)

### Next Steps

- **Task 14:** Platform API Batch B Migration (3 files, medium-risk)
- **Task 15:** Platform Serial Salt API Migration (1 file, critical, security-sensitive)

⸻

7. Notes for AI Agent
	•	คุณคือ AI Agent ที่ทำงานในโค้ดจริงของ Bellavier Group ERP
	•	Task นี้เป็น งานวิเคราะห์ + เอกสาร เท่านั้น
	•	ห้ามแก้โค้ด runtime เพราะไฟล์ใน scope ส่วนใหญ่เป็น core / critical
	•	ระหว่างทำงาน:
	•	ให้ log สเต็ปด้วย echo/print ใน terminal ได้ตามความเหมาะสม
	•	แต่ต้องไม่เปลี่ยน behavior ของระบบ

ถ้าพร้อมแล้ว ให้เริ่มจาก:
	1.	สร้าง/อัพเดท docs/bootstrap/core_platform_bootstrap.discovery.md
	2.	เติมหัวข้อ Overview + File Inventory
	3.	ไล่เปิดไฟล์ตามรายการ แล้วเก็บรายละเอียดทีละไฟล์ตาม template ที่กำหนด
	4.	สรุป Roadmap + Next Steps
