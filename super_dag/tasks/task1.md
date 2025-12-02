# Task 1 – Bootstrap Work Center Behavior (Super DAG)

**Folder:** `docs/super_dag/tasks/task1.md`  
**Status:** PLANNED  
**Depends on:**  
- `docs/super_dag/SPEC_WORK_CENTER_BEHAVIOR.md`  
- `docs/super_dag/DAG_IMPLEMENTATION_GUIDE.md`  
- `docs/super_dag/REALITY_EVENT_IN_HOUSE.md`  

---

## 1. เป้าหมาย (Goal)

วาง “ฐานราก” ให้ Super DAG โดย:

1. สร้าง **ตาราง behavior กลาง** สำหรับ Work Center (CUT, EDGE, STITCH, QC_FINAL, …) ตามสเปคใน `SPEC_WORK_CENTER_BEHAVIOR.md`
2. สร้าง **ตาราง mapping** ระหว่าง `work_center` เดิม ↔ behavior presets  
3. สร้าง **PHP helper (PSR-4)** สำหรับโหลด behavior ของ work_center แบบปลอดภัย และมี fallback
4. ยัง **ไม่แตะ** Work Queue, Token Engine, Time Engine, UI — แค่เตรียม “โครงกระดูก” ให้ทุกอย่างมาพิงทีหลังได้

จบ Task นี้ → ระบบยังทำงานเหมือนเดิม 100% แต่มี foundation พร้อมสำหรับ Task ต่อ ๆ ไป (CUT/EDGE/STITCH behavior, token split, time engine ฯลฯ)

---

## 2. ขอบเขตงาน (In Scope)

### 2.1 Database – tenant_migrations

สร้าง **2 migration ใหม่** ในโฟลเดอร์ tenant (ตาม convention ของคุณ ปรับชื่อไฟล์/namespace ให้ตรงจริง):

1. `work_center_behavior`  
2. `work_center_behavior_map`

อ้างอิง schema จาก `SPEC_WORK_CENTER_BEHAVIOR.md`:

#### 2.1.1 Table: `work_center_behavior`

Fields ตามสเปค:

- `id_behavior` int PK AUTO_INCREMENT  
- `code` varchar(50) UNIQUE (ตัวอย่าง: CUT, EDGE, STITCH, QC_FINAL, HARDWARE_ASSEMBLY, QC_REPAIR)  
- `name` varchar(100)  
- `description` text  
- `is_hatthasilpa_supported` tinyint(1) default 1  
- `is_classic_supported` tinyint(1) default 0  
- `execution_mode` enum('BATCH','SINGLE','MIXED')  
- `time_tracking_mode` enum('PER_BATCH','PER_PIECE','NO_TIME')  
- `requires_quantity_input` tinyint(1) default 0  
- `allows_component_binding` tinyint(1) default 0  
- `allows_defect_capture` tinyint(1) default 0  
- `supports_multiple_passes` tinyint(1) default 0  
- `ui_template_code` varchar(50) NULL  
- `default_expected_duration` int NULL (seconds)  
- `created_at` datetime NOT NULL  
- `updated_at` datetime NOT NULL  

Indexes:

- PRIMARY KEY (`id_behavior`)  
- UNIQUE KEY `uq_behavior_code` (`code`)

Migration logic:

- `up()` → create table + unique index  
- `down()` → drop table `work_center_behavior`

#### 2.1.2 Table: `work_center_behavior_map`

Fields:

- `id_work_center` int FK → `work_center.id_work_center`  
- `id_behavior` int FK → `work_center_behavior.id_behavior`  
- `override_settings` json NULL (MySQL JSON; ถ้า version ไม่รองรับ ให้ใช้ `text` + comment ระบุไว้)  
- `created_at` datetime NOT NULL  
- `updated_at` datetime NOT NULL  

Indexes:

- PRIMARY KEY (`id_work_center`, `id_behavior`)  
- FOREIGN KEY (`id_work_center`) REFERENCES `work_center(id_work_center)` ON DELETE CASCADE  
- FOREIGN KEY (`id_behavior`) REFERENCES `work_center_behavior(id_behavior)` ON DELETE CASCADE  

Migration logic:

- `up()` → create table, primary key, FKs  
- `down()` → drop table `work_center_behavior_map`

> 🔒 **ข้อห้ามสำคัญ:** ห้ามแก้ structure ของ `work_center` เดิมใน Task นี้

---

### 2.2 Seed Preset Behaviors (CUT / EDGE / STITCH / QC)

ใน migration (หรือตัว seed helper แยกไฟล์ก็ได้ แต่ต้องคุมไม่ให้เรียกซ้ำ) ให้:

1. เพิ่ม preset ขั้นต่ำตามตัวอย่างใน `SPEC_WORK_CENTER_BEHAVIOR.md`:

   - `CUT` (Cutting – batch)
   - `EDGE` (Edge Paint – mixed)
   - `STITCH` (Hatthasilpa single)
   - `QC_FINAL` (Final QC)
   - แถมเพิ่มอีก 2 ตัว (แบบเบา ๆ) เพื่อรองรับอนาคต:
     - `HARDWARE_ASSEMBLY`
     - `QC_REPAIR`

2. ใช้ pattern เดียวกับตัวอย่างใน spec (ค่าของ execution_mode, time_tracking_mode ฯลฯ):

   ตัวอย่าง (ไม่ต้อง copy ตรง ๆ แต่อ้าง logic):

   - CUT  
     - `execution_mode = 'BATCH'`  
     - `time_tracking_mode = 'PER_BATCH'`  
     - `requires_quantity_input = 1`  
     - `allows_defect_capture = 1`  
     - `allows_component_binding = 0`  
   - STITCH  
     - `execution_mode = 'SINGLE'`  
     - `time_tracking_mode = 'PER_PIECE'`  
     - `requires_quantity_input = 0`  
     - `allows_defect_capture = 1`  

> ⚠️ ต้องระวัง migration idempotent:
> - ใช้ `INSERT ... ON DUPLICATE KEY UPDATE` หรือเช็คก่อน insert
> - ห้ามทำให้ migration รันรอบสองแล้ว error

---

### 2.3 PHP Helper – Work Center Behavior Repository

สร้าง class ใหม่แบบ PSR-4:

- Namespace: `BGERP\Dag` (หรือ `BGERP\SuperDag` ถ้าอยากแยกชัด ๆ)  
- File: `source/BGERP/Dag/WorkCenterBehaviorRepository.php` (หรือชื่อใกล้เคียง แต่งให้ตรง PSR-4 mapping เดิม)

Minimal responsibilities:

1. โหลด behavior ตาม **behavior code**:

   ```php
   WorkCenterBehaviorRepository::getByCode(string $code): ?array;

	•	คืน array แบบ associative (ดึงทุก field หลักจาก table)
	•	ถ้าไม่เจอ → return null (ห้าม throw exception ในเวอร์ชันแรก)

	2.	โหลด behavior ตาม work_center id (ผ่าน mapping table):

WorkCenterBehaviorRepository::getByWorkCenterId(int $id_work_center): ?array;

Logic:
	•	Join work_center_behavior_map + work_center_behavior
	•	ถ้าไม่มี mapping → return null (แปลว่ายังใช้ generic behavior เดิม)
	•	ไม่ต้องทำ fallback อื่นใน Task1 → แค่เตรียม interface ให้ task ต่อไปใช้

	3.	Simple static cache ภายใน request:
	•	ลด query ซ้ำ: cache ตาม code และ id_work_center
	•	ไม่ต้อง optimize เกินไป แค่ array cache ก็พอ
	4.	Logging:
	•	ถ้า query fail → log ด้วย DatabaseHelper หรือ helper เดิม (ตาม pattern ระบบเดิม)
	•	ห้ามโยน error ดิบ ๆ ออกไป (กัน production พัง)

❗ ข้อสำคัญ: ใน Task1 ห้ามผูก repository เข้ากับ Work Queue / Token Engine / UI
แค่ให้ class อยู่ใน codebase พร้อมใช้งาน

⸻

2.4 Minimal Integration (Non-breaking)

เพื่อให้ dev/AI agent future ใช้ง่ายขึ้น ทำ integration เล็ก ๆ:
	1.	ใน work_centers.php (API list)
	•	เพิ่ม field ใหม่ใน JSON ถ้าทำได้แบบไม่เสี่ยง เช่น:

{
  "id_work_center": 1,
  "name": "CUTTING TABLE 1",
  "behavior_code": "CUT",        // ถ้ามี mapping
  "behavior_name": "Cutting",    // optional
  "has_behavior": true           // หรือ false ถ้าไม่มี mapping
}

แนวทาง:
	•	ถ้าตอนนี้ยังไม่มี mapping ใด ๆ → ให้ has_behavior = false และ behavior_code = null
	•	อย่าเปลี่ยน structure หลักที่ DataTables ใช้อยู่ (เพิ่ม field เสริมได้)

	2.	ยังไม่ต้อง render behavior ใน UI template
	•	แค่ส่ง JSON เพิ่ม ไว้ให้ task UI ในอนาคตเรียกใช้

⸻

3. นอกขอบเขต (Out of Scope)

ใน Task 1 ห้ามทำสิ่งเหล่านี้:
	1.	ห้ามแตะ / refactor:
	•	work_queue.php
	•	Token engine
	•	Time engine
	•	QC flows
	•	Component binding UI/APIs
	2.	ห้ามเปลี่ยน business logic เดิมของงาน Classic / Hatthasilpa
	3.	ห้ามบังคับให้ทุก work_center ต้องมี behavior → behavior mapping เป็น optional
	4.	ห้ามเพิ่ม Node Mode / Node Character logic ใน Task นี้ (ไว้ task ถัด ๆ ไป)

⸻

4. Acceptance Criteria (นิยาม “เสร็จ”)

ถือว่า Task 1 “ผ่าน” ก็ต่อเมื่อ:

4.1 Database
	•	Migration work_center_behavior รันผ่านใน tenant DB
	•	Migration work_center_behavior_map รันผ่านใน tenant DB
	•	รันรวมกับ migrations เดิมแล้วไม่ล้ม
	•	SELECT * FROM work_center_behavior มีอย่างน้อย 4 preset:
	•	CUT, EDGE, STITCH, QC_FINAL (และหากเพิ่ม HARDWARE_ASSEMBLY, QC_REPAIR ให้ตรวจด้วย)

4.2 PHP Helper
	•	source/BGERP/Dag/WorkCenterBehaviorRepository.php syntax ผ่าน (php -l)
	•	สามารถเรียก getByCode('CUT') แล้วได้ array ที่มี key อย่างน้อย:
	•	code, execution_mode, time_tracking_mode, ui_template_code
	•	เรียก getByWorkCenterId() แล้วถ้าไม่มี mapping → return null (ไม่ error)

4.3 Integration & Safety
	•	หน้า Work Centers ยังเปิดได้ปกติ ไม่มี fatal error
	•	ถ้าเพิ่ม behavior metadata ใน API:
	•	JSON structure เดิมของ DataTables ยังเหมือนเดิม
	•	field เสริมที่เพิ่มเข้ามา ไม่ทำให้ frontend พัง
	•	composer dump-autoload ผ่าน (ไม่มี PSR-4 warning ใหม่จากไฟล์ที่เพิ่ม)
	•	vendor/bin/phpunit tests/Integration/SystemWide/* ยังไม่แย่ลงจากเดิมเพราะ Task นี้ (ไม่มี error ใหม่จาก behavior tables)

4.4 Documentation
	•	อัปเดต docs/super_dag/task_index.md:
	•	เพิ่มแถวสำหรับ Task 1 (status: COMPLETED/IN_PROGRESS ตามจริง)
	•	ถ้าต้องมี note เพิ่มใน SPEC_WORK_CENTER_BEHAVIOR.md (เช่น field ใหม่) ให้ update พร้อมกัน

⸻

5. Safety Rails สำหรับ AI Agent

เวลาใช้ GPT-5.1 Codex / Cursor ให้ถือกฎนี้:
	1.	ห้ามแก้ work_center table structure
	2.	ห้ามแตะไฟล์ Work Queue, Token Engine, Time Engine ใน Taskนี้
	3.	ห้ามเปลี่ยน behavior การทำงานจริงบน production/uat:
	•	ทุกหน้าที่เคยใช้ได้ ต้องยังใช้ได้เหมือนเดิม
	4.	เพิ่มไฟล์ใหม่ให้:
	•	ใช้ namespace ที่สอดคล้องกับ PSR-4 mapping ปัจจุบัน
	•	ไม่สร้าง class ชื่อชนกับของเดิม
	5.	ถ้าต้องใช้ JSON field (override_settings) แล้ว MySQL version ของ dev ต่ำเกิน:
	•	ให้ fallback ใช้ text และ comment ไว้ใน migration ว่า “intended as JSON”

⸻

6. Suggested Command Checklist (สำหรับมนุษย์ตอนรันจริง)

หลังจากให้ AI Agent แก้โค้ดเสร็จ:

cd /Applications/MAMP/htdocs/bellavier-group-erp

# 1) Syntax check
php -l source/BGERP/Dag/WorkCenterBehaviorRepository.php
php -l database/tenant_migrations/XXXX_work_center_behavior.php
php -l database/tenant_migrations/XXXX_work_center_behavior_map.php

# 2) Migrate tenant DB (ตามวิธีที่คุณใช้ประจำ)
# php path/to/migration_runner.php --tenant=<tenant_code>

# 3) Quick sanity check in tinker/script
php -r "require 'config.php'; /* include bootstrap */ /* ลองเรียก WorkCenterBehaviorRepository::getByCode('CUT'); */"

# 4) Run tests (อย่างน้อยระดับ smoke)
vendor/bin/phpunit tests/Integration/SystemWide/ --testdox | head -80


⸻

Definition of Done:
เมื่อ migration ผ่าน, helper ใช้งานได้, system ไม่มี regression, และ doc อัปเดต → Task 1 ของ super_dag ถือว่าเสร็จสมบูรณ์ และพร้อมให้ Task ต่อไปมาพิง behavior layer นี้ได้เต็มที่