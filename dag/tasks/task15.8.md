# Task 15.8 — UOM & Work Center Hardening (Legacy Screen Lockdown)

**Status:** NEW  
**Area:** Master Data (Unit of Measure, Work Center)  
**Depends on:**  
- task15.6–15.7 (UOM/Work Center schema & seed alignment, code-based keys)  
- bgerp_t_maison_atelier template being the canonical reference  
- `erp_api_map.md` (for understanding current API usage surface)

**Goal:**  
Prevent accidental corruption of **core UOM** and **core Work Center** masters that are used by Leather GRN, CUT Node, stock, and production.  
This is a **safety + UX hardening task**: lock “system rows” both at DB-level and UI-level on the legacy master screens.

---

## 0. CONTEXT (WHY THIS TASK EXISTS)

- Node **CUT** และ Leather **GRN** จะไปต่อไม่ได้ ถ้า UOM และ Work Center ไม่เสถียร  
- ปัจจุบัน:
  - UOM เป็น legacy master ที่ **สามารถแก้/ลบหน่วยสำคัญได้** ผ่านหน้าจอเก่า  
  - มีการ refactor ไปใช้ `uom_code` เป็น business key (แทน id) แล้วในหลายจุด (Task 15.x)  
  - แต่:
    - ยังไม่มี `is_system` (หรือ equivalent) ที่ lock หน่วยสำคัญในตารางจริง
    - Legacy UI ยัง allow delete/modify UOM/Work Center เสี่ยงพัง chain ต่อเนื่อง
  - ปัญหาสำคัญ: **id ต่าง tenant ไม่ตรงกัน** ทำให้อ้างอิงด้วย id เป็นระเบิดเวลา หาก migrate/seed ใหม่

**สิ่งที่ต้องทำใน Task นี้**:  
- ระบุ “system UOM” + “system Work Center” จาก template tenant  
- เพิ่ม flag (`is_system`) และ enforce ว่า:
  - ห้ามลบ
  - ห้ามแก้ code / type / base_ratio / critical fields  
- Lock legacy master screens ให้สอดคล้องกับกฎนี้ (UI + service)  
- ทำให้ Leather GRN / CUT / stock / job flow ใช้งานได้บนฐานที่ “safe”

---

## 1. SCOPE

### In-Scope

1. **Table: `unit_of_measure`**
   - เพิ่ม/ใช้ `is_system` flag
   - lock system UOM ทั้งใน DB + UI + service layer
   - align ใช้ `uom_code` เป็น business key สำหรับ cross-tenant logic

2. **Table: `work_center`**
   - เพิ่ม/ใช้ `is_system` flag
   - lock system Work Center ทั้งใน DB + UI + service layer
   - ensure link ไป UOM ใช้ mapping ที่ปลอดภัย (id vs code) ตาม spec ปัจจุบัน

3. **Legacy Master Screens**
   - UOM management screen (เช่น `uom.php`, `unit_of_measure.php`, หรือไฟล์อื่นที่ทำ CRUD UOM)
   - Work Center management screen (ไฟล์ที่ทำ CRUD work_center)
   - ปรับ UI + controller ให้เคารพ `is_system`

4. **Guardrails for Leather / CUT / GRN usage**
   - ตรวจจุดที่ Leather GRN, CUT BOM, Leather Sheet ฯลฯ ใช้ UOM/Work Center
   - Confirm ว่าใช้ `uom_code` / `wc_code` เป็น key สำหรับ logic ที่ต้องข้าม tenant/template

### Out-of-Scope (for this task)

- การเปลี่ยนแปลง schema เพิ่มเติมนอกเหนือจาก `is_system`/unique constraints  
- การ redesign UX หน้าจอทั้งหมด (ให้แก้เฉพาะ behavior lock)  
- การลบตาราง legacy (routing V1, etc.) — อยู่ใน Phase 17

---

## 2. PHASE A — SCHEMA HARDENING

### 2.1 `unit_of_measure`

1. **Confirm existing columns**  
   ตาราง `unit_of_measure` มีคอลัมน์ `is_system`, `locked`, `is_active` อยู่แล้ว  
   (ไม่ต้องเพิ่มคอลัมน์ใหม่)

2. **Define roles clearly**
   - `is_system = 1` → เป็นหน่วยหลักของระบบ ห้ามลบ/ห้ามแก้ core fields  
   - `locked = 1` → tenant-level lock ไม่ให้ user ทั่วไปแก้  
   - `is_active = 0` → ปิดการใช้งาน (deactivate) แต่ไม่ลบออก

3. **Classify system UOMs**
   - Query template tenant: `bgerp_t_maison_atelier.unit_of_measure`
   - Identify UOM ที่ถูกใช้ใน stock/material/Leather GRN/CUT BOM
   - Mark system rows:

```
UPDATE unit_of_measure
SET is_system = 1, locked = 1, is_active = 1
WHERE uom_code IN (<LIST จาก template>);
```

4. **DB-level protection (optional)**
   - หากจะเพิ่ม trigger ให้ใช้ `is_system` เป็นตัวกำหนด primary guard  
   - ห้ามแก้ core fields (`uom_code`, `uom_type`, `base_ratio`) เมื่อ `is_system = 1`

⸻

2.2 work_center
1. **Confirm existing columns**  
   ตาราง `work_center` มีคอลัมน์ `is_system`, `locked`, `is_active` อยู่แล้ว  
   (ไม่ต้องเพิ่มคอลัมน์ใหม่)

2. **Define roles clearly**
   - `is_system = 1` → core work center ของระบบ ห้ามลบ/ห้ามแก้ code  
   - `locked = 1` → tenant-level lock สำหรับป้องกันการแก้ไข  
   - `is_active = 0` → deactivate work center

3. **Identify system Work Centers**
   - Query from template tenant: `bgerp_t_maison_atelier.work_center`
   - Identify work centers used in DAG / Leather / CUT / PWA  
   - Mark them:

```
UPDATE work_center
SET is_system = 1, locked = 1, is_active = 1
WHERE code IN (<LIST จาก template>);
```

4. **DB-level protection (optional)**
   - ใช้ `is_system` เป็น guard ห้ามแก้ไข `code` และ field ที่ DAG ใช้อ้างอิง

⸻

3. PHASE B — LEGACY MASTER SCREEN LOCKDOWN (UOM + WORK CENTER)

3.1 Find legacy UOM management UI
	•	Search in /source (or related folders) for:
	•	FROM unit_of_measure
	•	UOM listing / CRUD
	•	Identify PHP file(s) ที่ทำหน้าที่เป็น “หน้าจอ master UOM” (ตัวอย่างชื่อน่าจะเป็น uom.php, master_uom.php, ฯลฯ)

Change required:

**Important:**  
- `is_system = 1` → ล็อกโดยระบบ (ห้ามแก้/ลบ)  
- `locked = 1` → ล็อกโดย tenant/UI  
- `is_active` ใช้สำหรับ deactivate ไม่ใช่การล็อก

	1.	List View:
	•	แสดง column ใหม่/label: 🔒 System หรือ badge “System UOM” เมื่อตรวจเจอ is_system = 1
	•	สำหรับแถว system:
	•	ปุ่ม Delete: ซ่อน หรือ disabled
	•	ปุ่ม Edit: อนุญาตเฉพาะการแก้ non-critical fields เช่น display name, description, remark
	2.	Edit Form:
	•	เมื่อ load UOM ที่ is_system = 1:
	•	Lock fields:
	•	uom_code → readonly
	•	uom_type → readonly
	•	base_ratio → readonly
	•	Optional: allow แก้แค่ name_en, name_th, หรือ display label ได้
	3.	Create Form:
	•	UOM ใหม่ที่สร้างจากหน้าจอนี้:
	•	บังคับ is_system = 0
	•	ห้าม user ปกติตั้ง is_system เอง
	4.	Controller / save handler:
	•	ก่อน UPDATE:
	•	ถ้า row เป็น is_system = 1 → ignore การเปลี่ยนแปลง field critical:
	•	code/type/base_ratio
	•	หรือ throw error บอก user
	•	ก่อน DELETE:
	•	บังคับ WHERE is_system = 0
	•	หรือ check ใน PHP + reject

เป้าหมาย: legacy screen ยังใช้ “ดู / แก้ label” ได้ แต่แก้ core semantics ไม่ได้

⸻

3.2 Find legacy Work Center management UI
	•	Search for:
	•	FROM work_center
	•	Work center list / CRUD
	•	Identifyไฟล์หน้าจอ และ controller ที่เกี่ยวข้อง

Change required:

**Important:**  
- `is_system = 1` → ล็อกโดยระบบ (ห้ามแก้/ลบ)  
- `locked = 1` → ล็อกโดย tenant/UI  
- `is_active` ใช้สำหรับ deactivate ไม่ใช่การล็อก

	1.	List View:
	•	แสดง badge “System Work Center” เมื่อ is_system = 1
	•	ห้ามลบ system work center (disable delete)
	2.	Edit Form:
	•	ถ้า is_system = 1:
	•	lock code (readonly)
	•	lock fields ที่ผูกกับ DAG logic เช่น type/category ถ้ามี
	•	อนุญาตแก้แค่ label/description ตามสมควร
	3.	Create Form:
	•	work center ใหม่ → is_system = 0 เสมอ
	4.	Controller:
	•	ก่อน UPDATE:
	•	ถ้า is_system = 1 → reject การเปลี่ยน code และ field ที่ DAG ใช้ reference
	•	ก่อน DELETE:
	•	block delete ถ้า is_system = 1

⸻

4. PHASE C — GUARDRAILS FOR CUT / GRN / LEATHER USAGE

4.1 Confirm UOM reference strategy
	•	Inspect Leather-related APIs (จาก erp_api_map.md):
	•	leather_cut_bom_api.php
	•	leather_sheet_api.php
	•	Any GRN-related API or UI (ค้นคำว่า GRN, goods_receipt, ฯลฯ)

Check:
	•	ใช้อ้าง UOM โดย:
	•	id_unit_of_measure (ภายใน tenant เดียว → ok)
	•	แต่ seed / mapping / cross-tenant logic ต้องใช้ uom_code + is_system
	•	ถ้าพบ logic ที่ assume ว่า id ของ UOM “แน่นอนเหมือน template” → ต้อง refactor ให้ใช้ code-based lookup แทนในจุดนั้น

4.2 Confirm Work Center reference strategy
	•	Inspect:
	•	DAG routing API (dag_routing_api.php)
	•	Hatthasilpa job API (hatthasilpa_jobs_api.php)
	•	Classic API (classic_api.php ถ้ามีใช้ work center)
	•	Node CUT / Leather node-specific logic

Check:
	•	Internal FK ใน tenant: ใช้ id_work_center ได้
	•	แต่ seed/graph/template binding ที่ดึงจาก template หรือ sync ข้าม tenant ต้อง refer ด้วย code (ไม่ใช่ id)

Add note in docs (ถ้ามี doc routing/hatthasilpa):

“System work centers identified by code + is_system = 1. Do not rely on id_work_center across tenants.”

⸻

5. DELIVERABLES
	1.	New Migration file (e.g. 2025_12_15_08_harden_uom_and_work_center.php):
	•	ALTER TABLE for:
	•	unit_of_measure (add is_system + unique uom_code)
	•	work_center (add is_system + unique code)
	•	UPDATE statements mark system UOM & Work Center from template-derived list
	•	(Optional) DB-level triggers to block system row mutation/deletion
	2.	Updated Legacy UOM Screen(s):
	•	UI changes (badge, disabled buttons, readonly fields)
	•	Controller changes guarding system rows
	•	Short inline comments explaining is_system behavior
	3.	Updated Legacy Work Center Screen(s):
	•	UI changes (badge, disabled delete, readonly fields)
	•	Controller changes guarding system rows
	4.	Short Dev Note (e.g. docs/architecture/uom_work_center_hardening.md):
	•	Which UOM codes are considered system
	•	Which Work Center codes are considered system
	•	Brief explanation:
	•	“System rows cannot be deleted or have core fields changed”
	•	“Cross-tenant logic must reference UOM/Work Center by code, not id”

⸻

6. NON-NEGOTIABLE RULES
	•	DO NOT:
	•	invent new UOM codes
	•	invent new Work Center codes
	•	silently change existing codes
	•	Any classification as is_system = 1 MUST be based on:
	•	template tenant (bgerp_t_maison_atelier)
	•	existing seed/migration (Task 15.7)
	•	actual usage in Leather/Stock/CUT/GRN logic
	•	If there is ambiguity (e.g. a UOM appears unused but was seeded as core):
	•	default to safer choice → mark as system rather than dropping it
	•	Legacy screens must not allow deletion or core-field modification for is_system = 1 rows.

- ต้องใช้บทบาทของคอลัมน์ทั้งสามนี้ดังนี้:
  - `is_system` = system-level guard  
  - `locked` = tenant/UI-level lock  
  - `is_active` = activation status (ไม่ใช่การล็อก)

DO NOT IMAGINE NEW SCHEMA OR BUSINESS RULES.
USE EXISTING TEMPLATE + CURRENT CODEBASE AS THE SOURCE OF TRUTH.
