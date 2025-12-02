# Task 1 – Tenant API Bootstrap Discovery & Mapping

**Type:** Discovery / Analysis only (ยังไม่ Refactor โค้ด)  
**Project:** `/docs/bootstrap/tenant_api_bootstrap.md` Implementation  
**Goal:** รวบรวมข้อมูล API + Helper ทั้งระบบที่ยังใช้ core setup แบบเก่าให้ครบ ก่อนวางแผนย้ายไปใช้ `tenant_api_bootstrap.php`

**Status:** ✅ **COMPLETED** (2025-11-18)  
**Deliverable:** `docs/bootstrap/tenant_api_bootstrap.discovery.md`

---

## 1. Objective

ก่อนจะเริ่ม Implement `tenant_api_bootstrap.php` และ Refactor API ทั้งระบบ  
ต้องรู้ให้ชัดก่อนว่า **ปัจจุบันมีจุดไหนบ้างที่:**

1. Resolve org/tenant เอง (เช่น `resolve_current_org()`)
2. เปิด tenant DB เอง (เช่น `tenant_db()`, `new mysqli(...)`, ฯลฯ)
3. ใช้ `$db`, `$tenantDb`, `$conn`, `$mysqli` หรือชื่อตัวแปรอื่น ๆ ที่เกี่ยวกับ DB
4. ตั้ง header / timezone / json_error แบบ custom

**Task นี้:**
- อ่านโค้ด + จัดทำ “แผนที่” (map) ว่าไฟล์ไหนใช้ pattern ไหน
- ระบุจุดเสี่ยง / ความแตกต่างของตัวแปร / พฤติกรรมพิเศษ
- ยัง **ไม่เปลี่ยนโค้ด** แค่รายงาน และเสนอแนวทางกลุ่ม (grouping) สำหรับ Refactor ขั้นถัดไป

---

## 2. Reference Documents

ก่อนเริ่มทำงาน **ต้องอ่าน**:

1. `docs/bootstrap/tenant_api_bootstrap.md`  
   - เพื่อเข้าใจมาตรฐานใหม่: PSR-4, ใช้ `DatabaseHelper`, ห้ามใช้ `mysqli_*` ตรง ๆ ฯลฯ
2. (อ่านอย่างคร่าว ๆ) `config.php`  
   - เพื่อเข้าใจว่า autoload / env / constant ปัจจุบันอยู่ตรงไหน

---

## 3. Scope

### 3.1 Include

ค้นหาจาก root:

- ทุกไฟล์ PHP ภายใต้:
  - `source/`
  - `api/` (ถ้ามี)
  - `public/` หรือ root API อื่นที่เป็น endpoint
- Helper / Service ที่เกี่ยวข้องกับ:
  - org/tenant resolution
  - DB connection
  - JSON response
  - header/timezone setup

โฟกัสพิเศษที่:

- `dag_token_api.php`
- `hatthasilpa_*_api.php`
- Manager/Operator APIs
- ไฟล์ API ที่โค้ดยาวหลายพันบรรทัด (ต้องระบุด้วย)

### 3.2 Exclude

- View-only PHP (template, HTML rendering) ที่ไม่แตะ org/tenant/DB
- CLI script ที่ไม่ได้ทำงานใน context ของ tenant org

---

## 4. What to Find (Search Targets)

### 4.1 Org/Tenant Resolution Patterns

ค้นหา pattern เช่น:

- `resolve_current_org(`
- `$org =`
- `$_SESSION['org']`
- `org_code`
- `TENANT_403_NO_ORG`
- `BGERP\Helper\OrgResolver` (ถ้ามี class นี้อยู่แล้ว)
- logic custom อื่น ๆ ที่ใช้แยก tenant

**ให้บันทึกว่าในแต่ละไฟล์:**

- ใช้ฟังก์ชัน/คลาสอะไรในการ resolve org? (function-based หรือ class-based)
- มีการ fallback หรือ default org ไหม?
- ชื่อตัวแปรที่ใช้เก็บ org คืออะไร? (`$org`, `$currentOrg`, ฯลฯ)
- **สำคัญ:** ตรวจสอบว่ามี `BGERP\Helper\OrgResolver` class อยู่แล้วหรือยัง? (สำหรับ PSR-4 migration)

---

### 4.2 Tenant DB / Connection Patterns

ค้นหา pattern เช่น:

- `tenant_db(`
- `new mysqli(`
- `$tenantDb =`
- `$db = new DatabaseHelper(`
- `BGERP\Helper\TenantConnection` (ถ้ามี class นี้อยู่แล้ว)
- `BGERP\Helper\DatabaseHelper` (ตรวจสอบว่ามีอยู่แล้วและใช้งานอย่างไร)
- ตัวแปรเกี่ยวกับ connection: `$conn`, `$mysqli`, `$dbConn`, ฯลฯ

สำหรับแต่ละไฟล์ ให้บันทึก:

- ใช้ `DatabaseHelper` อยู่แล้วหรือยังใช้ mysqli ดิบ ๆ
- มีการเปิดหลาย connection ในไฟล์เดียวหรือไม่
- ชื่อตัวแปรหลักที่ใช้สำหรับ DB คืออะไร (`$db`, `$tenantDb`, `$conn`, ฯลฯ)
- มี mixing ระหว่าง `$db` กับ `$mysqli` ในไฟล์เดียวหรือไม่ (จุดเสี่ยง)
- **สำคัญ:** ตรวจสอบว่ามี `BGERP\Helper\TenantConnection` class อยู่แล้วหรือยัง? (สำหรับ PSR-4 migration)

---

### 4.3 Header / Timezone / JSON Response Patterns

ค้นหา:

- `header('Content-Type`
- `date_default_timezone_set(`
- `json_error(`
- `json_success(`
- `BGERP\Helper\JsonResponse` (ถ้ามี class นี้อยู่แล้ว)
- `echo json_encode(`
- ที่ใดก็ตามที่ API ส่ง JSON เองแบบไม่ผ่าน helper

บันทึกว่า:

- ไฟล์ไหนตั้ง header เอง ซ้ำกับมาตรฐานที่ Bootstrap จะดูแล
- ไฟล์ไหนใช้ `json_error/json_success` อยู่แล้ว (function-based)
- ไฟล์ไหน echo หรือ `print_r` JSON เอง (ต้องระวังเวลา Refactor)
- **สำคัญ:** ตรวจสอบว่ามี `BGERP\Helper\JsonResponse` class อยู่แล้วหรือยัง? (สำหรับ PSR-4 migration)

### 4.4 PSR-4 Autoloading Patterns

**สำคัญ:** ตรวจสอบโครงสร้างปัจจุบันเพื่อเตรียม Bootstrap แบบ PSR-4

ค้นหา:

- `require_once.*bootstrap` (ถ้ามี bootstrap files อยู่แล้ว)
- `use BGERP\\` (ตรวจสอบว่า APIs ใช้ namespace classes อยู่แล้วหรือยัง)
- `composer.json` autoload configuration (ตรวจสอบ PSR-4 mapping)
- Helper classes ใน `source/BGERP/Helper/` ที่มีอยู่แล้ว

บันทึกว่า:

- APIs ไหนใช้ `require_once` แบบเก่าอยู่ (ต้องเปลี่ยนเป็น PSR-4)
- APIs ไหนใช้ `use` statements สำหรับ BGERP classes อยู่แล้ว
- มี Helper classes อะไรใน `source/BGERP/Helper/` บ้าง (DatabaseHelper, JsonResponse, OrgResolver, TenantConnection, ฯลฯ)
- **สำคัญ:** ระบุ Helper classes ที่ยังไม่มีและต้องสร้างใหม่สำหรับ Bootstrap

---

## 5. Output & Deliverables

### 5.1 Summary Report (Markdown)

สร้างไฟล์สรุป (เช่น `docs/bootstrap/tenant_api_bootstrap.discovery.md`)  
เนื้อหาต้องมีอย่างน้อย:

#### 5.1.1 ตารางรวม API ที่เกี่ยวข้อง

ตัวอย่างโครง:

| # | File Path | Type (API/Helper) | Org Resolve Pattern | DB Pattern | Header/JSON Pattern | PSR-4 Ready? | Notes |
|---|-----------|-------------------|---------------------|-----------|---------------------|--------------|-------|
| 1 | `source/dag_token_api.php` | API | `$org = resolve_current_org()` | `$tenantDb = tenant_db(...); $db = new DatabaseHelper(...)` | custom header + `json_error` | ❌ ใช้ `require_once` | ไฟล์ยาว 2,000+ บรรทัด |
| 2 | `source/hatthasilpa_operator_api.php` | API | ... | ... | ... | ... | ... |

#### 5.1.2 รายการ Helper / Service ที่ต้องรู้จัก

เช่น:

- `resolve_current_org()` อยู่ไฟล์ไหน / namespace อะไร (function-based หรือ class-based)
- ฟังก์ชัน `tenant_db()` อยู่ที่ไหน
- Helper JSON ปัจจุบันมีอะไรบ้าง (function-based หรือ class-based)
- **สำคัญ:** รายการ Helper classes ที่มีอยู่แล้วใน `source/BGERP/Helper/`:
  - `DatabaseHelper` - มีอยู่แล้วหรือยัง? ใช้งานอย่างไร?
  - `JsonResponse` - มีอยู่แล้วหรือยัง? หรือยังใช้ `json_error()` function?
  - `OrgResolver` - มีอยู่แล้วหรือยัง? หรือยังใช้ `resolve_current_org()` function?
  - `TenantConnection` - มีอยู่แล้วหรือยัง? หรือยังใช้ `tenant_db()` function?
- **สำคัญ:** รายการ Helper classes ที่ต้องสร้างใหม่สำหรับ Bootstrap แบบ PSR-4

#### 5.1.3 ความแตกต่างของตัวแปรสำคัญ

อธิบาย:

- ที่ไหนใช้ `$db` เท่ากับ `DatabaseHelper`
- ที่ไหนใช้ `$db` เท่ากับ `mysqli`
- ที่ไหนใช้ `$tenantDb` เป็น `mysqli`
- ที่ไหนใช้ `$conn` / `$mysqli` แบบดิบ

**จุดนี้สำคัญมาก** เพราะเวลาย้ายไปใช้ bootstrap แล้ว `$db` ต้องหมายถึง `DatabaseHelper` เสมอ

---

### 5.2 Risk & Attention List

เพิ่ม section ว่า:

- ไฟล์ไหน “ใหญ่ผิดปกติ” (หลายพันบรรทัด) และ:

  - มีหลาย pattern ปนกันในไฟล์เดียว (org + DB + header + business logic)
  - ควร Refactor แยก logic ก่อนย้าย bootstrap หรือไม่
  - ต้องระวังอะไรเป็นพิเศษ เช่น:
    - ใช้ `$db` คนละความหมายในฟังก์ชันต่างกัน
    - เปลี่ยน header ระหว่างกลางไฟล์
    - มี output อื่นก่อน JSON

ตัวอย่างรูปแบบ:

```md
### High-risk Files

1. `source/dag_token_api.php`
   - ~2,XXX lines
   - `$db` ถูกใช้ทั้งเป็น `mysqli` และ `DatabaseHelper` (สมมติถ้าพบ)
   - มีการตั้ง header ซ้ำหลายจุด
   - มี business logic หนาแน่น → ควร plan refactor แยกเป็น service ก่อน

2. `source/xxx_api.php`
   - ...


⸻

6. Constraints & Guardrails
	1.	ห้ามแก้ไขโค้ดใด ๆ ใน Task นี้
	•	อ่านอย่างเดียว, สรุป, จัดกลุ่ม, ทำรายงาน
	2.	ห้ามเดา
	•	ถ้าไม่แน่ใจว่าฟังก์ชันไหนใช้ทำอะไร ให้ระบุใน report ว่า “ต้องตรวจเพิ่ม” แทนการสรุปผิด ๆ
	3.	โฟกัสที่ Tenant APIs ก่อน
	•	APIs ที่ชัดเจนว่าทำงานภายใต้ org/tenant เช่น Hatthasilpa, DAG, Operator, Work Queue
	4.	ระวังไฟล์ใหญ่
	•	อย่าพยายาม “เข้าใจทุกบรรทัด” ในไฟล์ 2,000+ บรรทัด
	•	ให้ focus ที่ส่วนเริ่มต้น setup org/db/header และส่วนที่เกี่ยวข้องกับ DB/JSON เท่านั้น
	5.	อ้างอิงกับ Spec ปัจจุบันเสมอ
	•	ทุกข้อเสนอให้ Refactor ต้อง align กับ docs/bootstrap/tenant_api_bootstrap.md
	•	**สำคัญ:** Bootstrap จะใช้ PSR-4 autoloading (ไม่ใช่ `require_once`)
	•	APIs ใหม่จะเรียกใช้: `\BGERP\Bootstrap\TenantApiBootstrap::init();` แทน `require_once`
	•	ห้ามเสนอให้ใช้ `require_once` helper รายไฟล์ใน API ใหม่อีก

⸻

7. Success Criteria

Task 1 ถือว่าสำเร็จเมื่อ:
	•	มี report สรุปไฟล์ทั้งหมดที่เกี่ยวข้อง + pattern ที่ใช้อยู่ปัจจุบัน
	•	มีการระบุ "ไฟล์เสี่ยงสูง" ที่ต้องระวังตอน Refactor
	•	มีข้อเสนอเบื้องต้นว่าจะจัดกลุ่ม Refactor อย่างไร (เช่น Batch A–B–C)
	•	ไม่มีการแก้โค้ดจริงในระบบ (pure discovery)

**✅ Completion Status:**
- [x] Discovery report created: `docs/bootstrap/tenant_api_bootstrap.discovery.md`
- [x] 158 PHP files analyzed
- [x] 53 tenant-scoped APIs identified
- [x] Helper classes inventory completed
- [x] Migration batches (A, B, C) proposed
- [x] High-risk files identified (dag_token_api.php, team_api.php, etc.)

หลังจาก Task นี้ จะสามารถสร้าง Task ถัดไป เช่น:
	•	✅ **Task 2** – Create Helper Classes (OrgResolver, JsonResponse, TenantConnection) สำหรับ PSR-4 **[COMPLETED]**
	•	Task 3 – Migrate Batch A APIs ให้ใช้ Bootstrap แบบ PSR-4
	•	Task 4 – Migrate Batch B APIs (medium-risk)
	•	Task 5 – Migrate Batch C APIs (high-risk)
	•	Task 6 – Cleanup legacy patterns (mysqli, manual header, require_once, ฯลฯ)

**หมายเหตุ:** Task 2 เสร็จสมบูรณ์แล้ว - Helper classes และ TenantApiBootstrap ถูกสร้างและทดสอบแล้ว
