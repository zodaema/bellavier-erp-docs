# Task 15.9 — System Work Center Behavior Seed & Auto-Binding

**Status:** NEW  
**Area:** Production Master Data (Work Center + Behavior)  
**Depends on:**  
- Task 15.7 (Canonical seed alignment)  
- Task 15.8 (UOM & Work Center Hardening — is_system/locked/is_active + UI Lock)  
- Template tenant: `bgerp_t_maison_atelier` as **source of truth**

---

## 0. CONTEXT

- ตาราง `work_center` ถูก seed canonical จาก `bgerp_t_maison_atelier` แล้วใน `0002_seed_data.php`  
  - มีคอลัมน์อย่างน้อย: `code`, `name`, `description`, `headcount`, `work_hours_per_day`, `is_active`, `sort_order`, `is_system`, `locked`
  - ตัวอย่าง canonical rows:

    | Code        | Name      |
    |-------------|-----------|
    | CUT         | Cutting   |
    | SKIV        | Skiving   |
    | EDG         | Edging    |
    | GLUE        | Gluing    |
    | ASSEMBLY    | Assembly  |
    | SEW         | Sewing    |
    | HW          | Hardware  |
    | PACK        | Packing   |
    | QC_INITIAL  | QC Initial|
    | QC_FINAL    | QC Final  |

- บน UI work_center มี column “Behavior” ให้กด `+ Set` เพื่อเลือก behavior จาก dropdown เช่น:
  - Cutting (CUT)  
  - Edge Paint (EDGE)  
  - Hardware Assembly (HARDWARE_ASSEMBLY)  
  - Final Quality Control (QC_FINAL)  
  - QC Repair (QC_REPAIR)  
  - Stitching (STITCH)  
  - ฯลฯ  

- ปัจจุบัน:
  - Behavior binding ต้องตั้งค่า **มือ** ต่อ-tenant (กด `+ Set` ทีละตัว)  
  - แม้ system work centers จะมี `is_system = 1, locked = 1` แล้ว ก็ยัง **ไม่ถูกผูก behavior default อัตโนมัติ**  
  - Behavior definitions และ mapping ยัง **ไม่ได้ถูก seed ใน `0002_seed_data.php`** (มีแค่ work_center)  
  - ทำให้ tenant ใหม่ต้องมา setting เองก่อนใช้ DAG/Hatthasilpa line → เสี่ยงพลาด, ใช้งานไม่ต่อเนื่อง

**Important System Rule:**  
For all system work centers (`is_system = 1`):  
- Behavior **cannot** be changed by users.  
- All action buttons (`+ Set`, `Change`, `Remove`, etc.) must be **hidden entirely**.  
- Instead of disabled buttons, show a clear i18n message such as:  
  - `Editing is not allowed for system-defined work centers.`  
- This rule is mandatory for both UI and backend enforcement.

---

## 1. GOAL

1. **นิยาม “Canonical Work Center Behavior Set”** จาก template DB + โค้ดปัจจุบัน  
2. สร้าง/อัปเดต **Behavior definition seed** (เช่นใน table พวก `work_center_behavior`, `work_center_behavior_type`, ฯลฯ)  
3. สร้าง **default mapping** ระหว่าง canonical work centers ↔ behaviors (CUT → Cutting, SEW → Stitching, ฯลฯ)  
4. ทำให้:
   - **Tenant ใหม่**: ได้ทั้ง work_center + behavior + mapping ครบ จาก `0002_seed_data.php` ทันที  
   - **Tenant เดิม**: ใช้ migration ใหม่เติม behavior + mapping ให้โดยอัตโนมัติ  
5. หลัง Migration Wizard ทำงานกับ tenants ปัจจุบันเสร็จ สามารถลบ tenant migration ไฟล์ที่สร้างใน Task นี้ได้  
   โดย **ไม่เสียผล** เพราะ logic หลักถูกฝังไว้ใน `0002_seed_data.php` แล้ว  
6. System work centers must have behavior assigned automatically and users must not be allowed to edit behavior.

---

## 2. SCOPE

### In-Scope

- ตาราง work center behavior ทั้งหมดที่เกี่ยวข้องกับ dropdown “Behavior”  
  - เช่น `work_center_behavior`, `work_center_behavior_profile`, `work_center_behavior_type`, `work_center_behavior_map`, ฯลฯ  
  - ใช้ **การค้นหาโค้ดจริง** ใน repo เป็นตัวตัดสินว่า table ไหนคือแหล่งข้อมูลจริง
- Template tenant `bgerp_t_maison_atelier`:
  - ใช้ confirm รายการ behavior ปัจจุบัน  
  - ใช้ confirm mapping ปัจจุบัน (ถ้ามี)  
- สร้าง tenant migration ใหม่ **หนึ่งไฟล์** สำหรับ backfill tenant ปัจจุบัน  
- อัปเดต `database/tenant_migrations/0002_seed_data.php` ให้:
  - seed behavior definitions  
  - seed work center ↔ behavior mapping default

### Out-of-Scope

- การออกแบบ behavior ใหม่ที่ไม่สะท้อนงานจริงในโรงงาน (ห้ามแต่งเพิ่มเอง)  
- การเปลี่ยนชื่อ `code` เดิมของ work center หรือ behavior ที่มีอยู่ใน DB  
- การเปลี่ยนแปลง logic ของ Token/DAG/QC — Task นี้โฟกัสที่ “master & seed + mapping” เท่านั้น

---

## 3. PHASE A — DISCOVERY (ต้องใช้โค้ด/DB จริง)

1. **หา table และ model ที่ใช้เก็บ “Behavior”**

   - ใช้การค้นหาในโค้ด:
     - คำว่า `"Select Behavior"`, `"Behavior"`, `"work_center_behavior"`, `"HARDWARE_ASSEMBLY"`, `"QC_FINAL"`, `"STITCH"`, `"Edge Paint"`, ฯลฯ
   - ระบุ:
     - ชื่อ table จริงที่เก็บ behavior definitions (เช่น `work_center_behavior`)  
     - ชื่อ table/map ที่เก็บการผูก work_center ↔ behavior (เช่น `work_center_behavior_map` หรือ field `id_behavior` ตรงใน `work_center`)

   **ต้องบันทึกผลค้นหาในหัวข้อ "Discovery" ด้านล่างของไฟล์นี้ด้วย (เป็น dev note) เช่น:**

   ```md
   ## Discovery (from code/db)

   - Behavior definition table: work_center_behavior
     - Columns: id_behavior, code, name, description, is_hatthasilpa_supported, is_classic_supported, execution_mode, time_tracking_mode, requires_quantity_input, allows_component_binding, allows_defect_capture, supports_multiple_passes, ui_template_code, default_expected_duration, created_at, updated_at
     - Added in Task 15.9: is_system, locked, is_active columns

   - Behavior mapping:
     - Table: work_center_behavior_map
       - Columns: id_work_center, work_center_code, id_behavior, override_settings, created_at, updated_at
       - Primary Key: (id_work_center, id_behavior)
       - Used by: source/work_centers.php (bind_behavior, unbind_behavior actions), assets/javascripts/work_centers/work_centers_behavior.js

	2.	ตรวจ behavior set ปัจจุบันใน template tenant
	•	Query: SELECT * FROM bgerp_t_maison_atelier.<behavior_table> ORDER BY code;
	•	ลดรูปเป็น list (code, name)
	•	เปรียบเทียบกับ dropdown ที่เห็นใน UI:
	•	Cutting (CUT)
	•	Edge Paint (EDGE)
	•	Hardware Assembly (HARDWARE_ASSEMBLY)
	•	Final Quality Control (QC_FINAL)
	•	QC Repair (QC_REPAIR)
	•	Stitching (STITCH)
	•	ระบุว่ามี behavior ไหนใน dropdown แต่ ไม่มี ใน DB / ไม่ถูก seed
	•	
	•	**Discovery Results (Task 15.9):**
	•	Behaviors found in codebase:
	•	- CUT, EDGE, STITCH, QC_FINAL, HARDWARE_ASSEMBLY, QC_REPAIR (from archive migration)
	•	- QC_SINGLE (from BehaviorExecutionService)
	•	- Additional behaviors needed for canonical mapping: SKIVE, GLUE, ASSEMBLY, PACK, QC_INITIAL
	•	Total: 11 behaviors seeded
	3.	ตรวจ mapping ปัจจุบัน
	•	ถ้าใน template มี mapping อยู่แล้ว (เช่น CUT ผูกกับ behavior CUT) → ให้ดึงเป็น canonical mapping
	•	ถ้ายังไม่มี mapping (หรือ mapping ว่าง) → จะใช้ logic "canonical mapping ตามตาราง work_center.default_code" ใน Phase B
	•	
	•	**Canonical Mapping (Final):**
	•	- CUT -> CUT
	•	- SKIV -> SKIVE
	•	- EDG -> EDGE
	•	- GLUE -> GLUE
	•	- ASSEMBLY -> ASSEMBLY
	•	- SEW -> STITCH
	•	- HW -> HARDWARE_ASSEMBLY
	•	- PACK -> PACK
	•	- QC_INITIAL -> QC_INITIAL
	•	- QC_FINAL -> QC_FINAL

⸻

4. PHASE B — DEFINE CANONICAL MAPPING

เมื่อได้ข้อมูลจาก Phase A ให้สร้าง canonical mapping ระดับระบบแบบนี้:
	•	ฐาน: ใช้ work_center.code เป็น key

ตัวอย่าง mapping ที่คาดหวัง (ให้ปรับตามผลจริงจาก template DB):

Work Center code	Behavior code (canonical)	หมายเหตุ
CUT	CUT	Cutting work center
SKIV	SKIVE (หรือ SKIV ถ้ามี)	Trim & Skiving Leather
EDG	EDGE	Edge finish & polishing
GLUE	GLUE	Gluing step
ASSEMBLY	ASSEMBLY / HARDWARE_ASSEMBLY	Final assembly bench
SEW	STITCH	Sewing / stitching
HW	HARDWARE_ASSEMBLY	Hardware, ZIP, screw
PACK	PACK / FINALIZE	Packing / finalization
QC_INITIAL	QC_INITIAL / QC_REPAIR	Initial QC
QC_FINAL	QC_FINAL	Final QC

สำคัญ:
	•	ห้ามเปลี่ยน work_center.code เดิม
	•	ห้าม rename behavior code ที่มีอยู่แล้วใน DB
	•	ถ้ายังไม่มี behavior ที่จำเป็น เช่น GLUE, SKIVE, PACK, QC_INITIAL, ASSEMBLY:
	•	ให้ สร้าง behavior ใหม่ โดยใช้ code/ชื่อที่สะท้อนงานจริงใกล้ที่สุด
	•	แต่ต้องไม่ชนกับ code ที่มีแล้ว

⸻

**Rule:**  
- Mapping for system work centers is immutable.  
- Once mapped, it cannot be changed or removed through UI or API.  
- Any attempt to modify must result in a clear validation error.

⸻

5. PHASE C — CREATE/UPDATE BEHAVIOR SEED

5.1 Tenant Migration ใหม่ (สำหรับ tenants ปัจจุบัน)
	1.	สร้างไฟล์ใหม่ใน database/tenant_migrations/ เช่น:
	•	2025_12_15_09_seed_work_center_behavior.php
(ให้ใช้ timestamp ตามมาตรฐานที่คุณใช้กับ Task อื่น)
	2.	Migration นี้ต้อง:
	•	Step 1: Seed behavior definitions
	•	ใช้ $behaviors = [...] in PHP แบบเดียวกับ UoM/Work Center ใน 0002_seed_data.php
	•	Format:
[code, name, description, is_active, is_system, locked] (หรือ columns จริงตาม table)
	•	ข้อมูลต้องมาจาก:
	•	template tenant bgerp_t_maison_atelier (ถ้ามี), และ/หรือ
	•	dropdown behavior ที่ใช้ใน UI ปัจจุบัน
	•	ใช้ migration_insert_if_not_exists() เพื่อให้ idempotent
	•	Step 2: Seed mapping work_center ↔ behavior
	•	สำหรับ work centers ที่ is_system = 1 และ is_active = 1:
	•	หาคู่ behavior ตาม canonical mapping ใน Phase B
	•	สร้าง row mapping ระหว่าง work_center และ behavior ผ่าน table mapping ที่ค้นเจอใน Phase A
	•	ใช้ pattern:

$wcCode = 'CUT';
$behaviorCode = 'CUT';

$idWc = migration_fetch_value($db, 'SELECT id_work_center FROM work_center WHERE code = ?', 's', [$wcCode]);
$idBehavior = migration_fetch_value($db, 'SELECT id_behavior FROM work_center_behavior WHERE code = ?', 's', [$behaviorCode]);

if ($idWc && $idBehavior) {
    migration_insert_if_not_exists(
        $db,
        'work_center_behavior_map',
        ['id_work_center' => (int)$idWc],
        ['id_work_center' => (int)$idWc, 'id_behavior' => (int)$idBehavior, 'is_active' => 1]
    );
}

ชื่อ table/column ต้องใช้ของจริงจาก Phase A
ถ้า table mapping มี key ต่างไป (เช่น composite key, field ชื่ออื่น) ให้ปรับตามจริง

	•	Step 3: Logging
	•	echo summary สั้น ๆ:
	•	จำนวน behavior ที่ seed
	•	จำนวน work centers ที่ถูก bind behavior
	•	For system work centers, ensure mapping is always enforced.  
	•	If tenant already has behavior mapping but differs from canonical mapping, the canonical mapping must overwrite it. (System rules override tenant customizations.)

	3.	ข้อควรจำเรื่องการลบไฟล์ migration:
	•	Migration นี้มีหน้าที่ เติมของให้ tenants ปัจจุบันเท่านั้น
	•	เมื่อ Migration Wizard ของคุณรันทุก tenant จนจบ และคุณตรวจแล้วว่า:
	•	behaviors & mapping ปรากฏใน tenants ทั้งหมด
	•	คุณสามารถลบไฟล์ migration นี้ได้
	•	เพราะ logic สำหรับ tenant ใหม่ จะอยู่ใน 0002_seed_data.php (Phase D) แล้ว

5.2 อัปเดต 0002_seed_data.php (สำหรับ tenant ใหม่)

สำคัญมาก:
ทุกครั้งที่สั่ง AI Agent ทำ seed ใน Task นี้
ต้องบอกให้มัน “สร้างทั้งไฟล์ migration ใหม่ + อัปเดต 0002_seed_data.php พร้อมกัน”

ใน 0002_seed_data.php ให้:
	1.	เพิ่ม Section ใหม่สำหรับ behavior หลังจาก section seeding work centers:
ตอนนี้มี:

// 5. WORK CENTER (10 canonical work centers from bgerp_t_maison_atelier)
echo "[5/5] Seeding canonical work centers...\n";
...
echo "  ✓ " . count($workCenters) . " work centers seeded (from bgerp_t_maison_atelier)\n";

ให้เพิ่มต่อจากนี้:

// 6. WORK CENTER BEHAVIOR (canonical from template)
echo "[6/6] Seeding work center behaviors...\n";

// Format: [code, name, description, is_active, is_system, locked]

**IMPORTANT:**  
`$behaviors` in `0002_seed_data.php` must include *every behavior that exists in the entire system*, including legacy behaviors and new ones introduced by canonical mapping.  
Do not rely on dropdown; extract by scanning repository + template DB.  
This ensures tenant creation relies solely on the source-of-truth seed.

$behaviors = [
    ['CUT', 'Cutting', 'Cutting operations', 1, 1, 1],
    ['EDGE', 'Edge Paint', 'Edge paint / finishing', 1, 1, 1],
    ['HARDWARE_ASSEMBLY', 'Hardware Assembly', 'Hardware & metal fittings assembly', 1, 1, 1],
    ['QC_FINAL', 'Final Quality Control', 'Final QC step', 1, 1, 1],
    ['QC_REPAIR', 'QC Repair', 'QC rework/repair actions', 1, 1, 1],
    ['STITCH', 'Stitching', 'Stitching / sewing operations', 1, 1, 1],
    // เพิ่ม behaviors ที่จำเป็นอื่น ๆ ตามผล Phase B (SKIVE, GLUE, PACK, ASSEMBLY, QC_INITIAL ฯลฯ)
];

foreach ($behaviors as [$code, $name, $description, $isActive, $isSystem, $locked]) {
    migration_insert_if_not_exists($db, 'work_center_behavior', ['code' => $code], [
        'code' => $code,
        'name' => $name,
        'description' => $description,
        'is_active' => $isActive,
        'is_system' => $isSystem,
        'locked' => $locked
    ]);
}
echo "  ✓ " . count($behaviors) . " work center behaviors seeded\n";

// Default mapping Work Center -> Behavior
echo "[6b/6] Mapping work centers to behavior...\n";

$defaultBehaviorMap = [
    ['CUT', 'CUT'],
    ['SKIV', 'SKIVE'],               // ปรับตาม behavior จริง
    ['EDG', 'EDGE'],
    ['GLUE', 'GLUE'],
    ['ASSEMBLY', 'ASSEMBLY'],
    ['SEW', 'STITCH'],
    ['HW', 'HARDWARE_ASSEMBLY'],
    ['PACK', 'PACK'],
    ['QC_INITIAL', 'QC_INITIAL'],
    ['QC_FINAL', 'QC_FINAL'],
];

foreach ($defaultBehaviorMap as [$wcCode, $behaviorCode]) {
    $idWc = migration_fetch_value($db, 'SELECT id_work_center FROM work_center WHERE code = ?', 's', [$wcCode]);
    $idBehavior = migration_fetch_value($db, 'SELECT id_behavior FROM work_center_behavior WHERE code = ?', 's', [$behaviorCode]);

    if ($idWc && $idBehavior) {
        migration_insert_if_not_exists(
            $db,
            'work_center_behavior_map',
            ['id_work_center' => (int)$idWc],
            [
                'id_work_center' => (int)$idWc,
                'id_behavior' => (int)$idBehavior,
                'is_active' => 1
            ]
        );
    }
}
echo "  ✓ Default behavior mapping for system work centers seeded\n";

**System Editing Rule:**  
For work centers with `is_system = 1`, mapping created here is final and cannot be changed later.  
UI and API must block all edits.

	2.	ปรับ counter [5/5], [6/6] หรือ summary ด้านล่างให้ถูกต้อง
	•	ถ้าจำเป็น ให้แก้ summary ตอนท้าย (หลัง sample data) ให้ไม่ hardcode จำนวนผิด เช่น ตอนนี้ยังเขียนว่า:

echo "  - Essential: " . count($permissions) . " permissions, 10 roles, " . count($uoms) . " UoM, 1 work center\n";

ทั้งที่จริง seed work centers = 10, ไม่ใช่ 1

⸻

6. PHASE D — UI & SERVICE SAFETY (OPTIONAL BUT RECOMMENDED)

หลัง seed + mapping แล้ว:
	1.	UI Work Center List:
	•	ถ้า work center มี behavior map แล้ว ให้แสดงชื่อ behavior / badge ที่สอดคล้อง
	•	ถ้าเป็น is_system = 1:
	•	อนุญาตให้เปลี่ยน behavior เฉพาะผ่านหน้าจอ Behavior (ถ้าต้องการ)
	•	แต่ค่าตั้งต้นจาก seed ต้องถูกตั้งถูกต้องก่อนแล้ว
	2.	Service Layer (ถ้ามี):
	•	ตรวจสอบ service ที่อ่าน behavior เช่น:
	•	WorkCenterBehaviorService, WorkCenterCapacityCalculator, hatthasilpa_jobs_api, ฯลฯ
	•	ให้ยืนยันว่า:
	•	ใช้ behavior จาก mapping table แทนการ hardcode code เช่น 'CUT', 'QC_FINAL' ตรง ๆ ในหลายที่
	•	ถ้า behavior หายไป → throw error ชัดเจน (ไม่ปล่อย flow เดินแบบเงียบ ๆ)

⸻

7. DELIVERABLES
	1.	Tenant Migration ใหม่
	•	ไฟล์: database/tenant_migrations/2025_XX_XX_15_09_seed_work_center_behavior.php
	•	ทำหน้าที่:
	•	Seed behavior definitions ตาม canonical list
	•	Seed mapping work_center ↔ behavior ให้ tenants ปัจจุบัน
	•	Idempotent; ใช้ helpers จาก migration_helpers.php
	2.	Updated 0002_seed_data.php
	•	เพิ่ม Section seeding behavior + mapping สำหรับ tenant ใหม่
	•	แก้ summary ตัวเลขให้ตรงกับความจริง
	•	ให้ใช้ pattern/โค้ดคล้าย migration เพื่อความสม่ำเสมอ
	3.	Dev Note ในไฟล์ Task นี้ (ส่วน Discovery)
	•	ระบุชื่อ table/column ที่ใช้จริงสำหรับ behavior + mapping
	•	ระบุ canonical mapping สุดท้ายที่ถูกใช้จริง  
	•	Must include updated system immutability rules for behavior editing.

⸻

8. NON-NEGOTIABLE RULES
	- System work centers (`is_system = 1`) must NOT allow behavior changes.  
	  - UI must hide all action buttons.  
	  - Must show i18n text: “Editing is not allowed.”  
	  - Backend must strictly reject any modification attempts.  
	- Behavior seeds must include *all behaviors* in the system (source-of-truth).  
	  - No behavior may be missing from `0002_seed_data.php`.
	•	ห้ามเปลี่ยน code ของ work centers หรือ behavior ที่มีอยู่แล้ว
	•	ห้ามลบ behavior เดิมที่ถูกใช้อยู่ใน template tenant
	•	Behavior ใหม่ที่เพิ่มต้อง:
	•	สะท้อนประเภทงานจริง (CUT, GLUE, PACK, ฯลฯ)
	•	ตั้งชื่อให้สอดคล้องกับ pattern เดิม (UPPER_SNAKE_CASE)
	•	is_system = 1, locked = 1 ถ้าเป็น behavior แกนกลางของระบบ
	•	Seed และ migration ต้อง idempotent 100%
	•	ใช้ migration_insert_if_not_exists() และ migration_fetch_value() ตามมาตรฐาน
	•	ทุกครั้งที่สั่ง AI Agent ทำงาน Task นี้
	•	ต้องระบุชัดเจนว่า:
“สร้างทั้ง tenant migration ใหม่ และ update เข้า 0002_seed_data.php ด้วย”
	•	เพราะหลังรัน Migration Wizard กับ tenants ปัจจุบันเสร็จ
	•	คุณจะลบไฟล์ migration ใหม่ทิ้ง
	•	tenant ใหม่จะใช้ 0002_seed_data.php เป็น source of truth แทนเสมอ

⸻