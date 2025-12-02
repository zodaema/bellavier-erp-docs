

# Task 13.12 — Leather Sheet Binding UX + API for CUT Behavior

**Status:** NEW  
**Phase:** Component System Phase 4  
**Goal:** เชื่อม Leather GRN → CUT Behavior อย่างสมบูรณ์  
**Focus:** ให้ช่างเลือก "Leather Sheet" ที่ใช้จริงในการ CUT แบบง่าย เร็ว ไม่ผิดพลาด และเก็บ Audit ครบถ้วน

---

## 1. Objective

สร้างระบบให้ช่าง CUT สามารถ:

1. **เลือก Leather Sheets** ที่ต้องนำมาตัด  
2. ระบุ **ปริมาณการใช้** (Usage Area หรือ “จำนวนที่ตัดไปแล้ว”)  
3. ให้ระบบรู้ว่า sheet ไหนถูกใช้ไปแล้วกี่ sq.ft → คำนวณเหลือเท่าไร  
4. บันทึกการใช้ลง log ที่ผูกกับ token อย่างชัดเจน  
5. ใช้ง่ายที่สุดสำหรับ user หน้างาน (warehouse/ช่างตัด) และไม่ไปยุ่ง flow เดิมของ GRN

Task นี้เป็น **Phase 4: Leather Sheet Usage Binding** ที่เชื่อม 3 โลกเข้าด้วยกัน:

- Leather GRN (sheet-level)  
- CUT Behavior ใน super_dag  
- Component / Traceability layer

---

## 2. Scope

### In Scope

- ฐานข้อมูลสำหรับเก็บ usage ของ leather sheet ต่อ token
- API สำหรับ:
  - list เลือก leather sheets ที่ใช้ได้
  - บันทึก usage ต่อ token
  - list usage per token
- Integration กับ CUT behavior panel:
  - เลือก sheet
  - ใส่ used_area
  - แสดง usage list บน panel
- Supervisor view (อ่าน usage) ผ่าน endpoint เดิม (ไม่ต้องทำ UI ใหม่)
- UX ที่เน้นใช้ได้จริงในโรงงาน:
  - search sheet ง่าย
  - ใส่จำนวนได้เร็ว
  - แก้ไข/ลบ usage ได้ก่อน complete

### Out of Scope (ไม่ทำใน Task นี้)

- Auto-enforce ว่าต้องมี usage ครบก่อน CUT complete (ยังเป็น soft warning)
- Allocation logic กับ cost หรือ stock ledger
- Cross-MO aggregation ของ usage
- Report ระดับ BI หรือ cost accounting

---

## 3. Database Design

### 3.1 New Table: `leather_sheet_usage_log`

**Migration file:**  
`database/tenant_migrations/2025_12_leather_sheet_usage.php`

สร้างตารางใหม่:

- `leather_sheet_usage_log`
  - `id_usage` (PK, AUTO_INCREMENT)
  - `id_sheet` (FK → `leather_sheet.id_sheet`)
  - `token_id` (FK → dag token / job token ที่มีอยู่แล้วในระบบ)
  - `used_area` (DECIMAL(8,2)) — หน่วย sq.ft หรือหน่วยหลักที่กำหนด
  - `used_by` (INT, FK → worker / member id ที่กำลังทำงาน)
  - `created_at` (DATETIME)
  - `updated_at` (DATETIME, nullable)
  - index:
    - `idx_sheet_token` (`id_sheet`, `token_id`)
    - `idx_token` (`token_id`)
    - `idx_sheet` (`id_sheet`)

**Notes:**

- ไม่แก้ไข structure ของ `leather_sheet`
- ไม่แก้ไข structure ของ GRN เดิม
- Idempotent migration (เช็คก่อนสร้าง)

---

## 4. API Endpoint: `leather_sheet_api.php`

**File:** `source/leather_sheet_api.php` (ใหม่)  
ใช้ pattern เดิม: `TenantApiBootstrap` + `TenantApiOutput`

### 4.1 Common

- ตรวจสอบ session + tenant context
- ใช้ permission:
  - `leather.sheet.use` — สำหรับ actions ที่แก้ข้อมูล
  - `leather.sheet.view` — สำหรับ read-only list
- Rate limiting (ใช้ helper เดิมถ้ามี)
- Error format: ใช้ standard `TenantApiOutput::error()` พร้อม `app_code`

### 4.2 Actions

#### a) `action=list_available_sheets`

**Input:**

- `material_id` (required) — หนังชนิดไหน
- optional:
  - `search` (string) — ค้นจาก sheet code / GRN / note
  - pagination params (start, length) ถ้าจำเป็น

**Logic:**

1. join:
   - `leather_sheet`
   - `material_lot`
   - (ถ้าจำเป็น) material master
2. คำนวณ `remaining_area` = `area_original` - SUM(usage_log.used_area)
3. filter ให้เหลือเฉพาะ:
   - remaining_area > 0
   - material_id ตรงกับ input
4. คืน JSON:

```jsonc
{
  "ok": true,
  "data": [
    {
      "id_sheet": 123,
      "sheet_code": "MAT-SAFF-20251120-001",
      "grn_number": "GRN-2025-00123",
      "area_original": 15.50,
      "area_used": 3.25,
      "area_remaining": 12.25
    }
  ]
}
```

#### b) `action=bind_sheet_usage`

**Input:**

- `token_id` (required)
- `sheet_id` (required)
- `used_area` (required, > 0)
- optional: `note`

**Logic:**

1. ตรวจสอบ:
   - token exists + active
   - sheet exists
   - used_area <= remaining_area (soft check)
2. เปิด transaction
   - insert `leather_sheet_usage_log`
   - commit
3. ส่ง response:

```jsonc
{
  "ok": true,
  "usage": {
    "id_usage": 10,
    "token_id": 555,
    "sheet_id": 123,
    "used_area": 1.50,
    "area_remaining_after": 10.75
  }
}
```

**Error Cases:**

- `LEATHER_SHEET_NOT_FOUND`
- `LEATHER_SHEET_NO_REMAINING_AREA`
- `LEATHER_SHEET_USAGE_INVALID_AREA`

#### c) `action=list_sheet_usage_by_token`

**Input:**

- `token_id` (required)

**Output:**

- list ของ usage ทั้งหมดของ token นั้น:

```jsonc
{
  "ok": true,
  "data": [
    {
      "id_usage": 10,
      "sheet_code": "MAT-SAFF-20251120-001",
      "used_area": 1.50,
      "used_by_name": "Somchai",
      "created_at": "2025-11-20 14:32:00"
    }
  ]
}
```

**Permission:** `leather.sheet.view`

---

## 5. CUT Behavior Integration

### 5.1 Backend: BehaviorExecutionService

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

ใน handler ของ CUT (เช่น `handleCutStart()` / `handleCutComplete()`):

- ไม่ต้องบังคับว่าต้องมี usage ก่อน complete
- แต่ควร:
  - ดึง `leather_sheet_usage_log` ของ token มาแสดงใน response (field `sheet_usage`)
  - ให้ data พร้อมสำหรับ UI render

### 5.2 Frontend: behavior_ui_templates.js

**File:** `assets/javascripts/dag/behavior_ui_templates.js`

ใน CUT behavior panel:

- เพิ่ม section ใหม่ **"Leather Sheets Used"**
  - ตารางเล็กๆ:
    - Sheet code
    - Used area
    - เวลา
  - ปุ่ม “+ เลือก Leather Sheet”

### 5.3 Frontend: behavior_execution.js

**File:** `assets/javascripts/dag/behavior_execution.js`

- เพิ่ม handler สำหรับ:
  - ปุ่ม “+ เลือก Leather Sheet” → เปิด modal
  - submit usage → call `leather_sheet_api.php?action=bind_sheet_usage`
  - refresh panel หลังใช้งานสำเร็จ (update usage list)

**Behavior:**

- เมื่อกด `cut_start` → ยังไม่ต้องบังคับให้เลือก sheet
- ระหว่าง CUT worker สามารถ:
  - เปิด modal เลือก sheet + ใส่ used_area ได้หลายครั้ง
- เมื่อกด `cut_complete`:
  - ถ้าไม่มี usage:
    - แสดง warning (toast / alert):
      - “ยังไม่ได้ระบุหนังที่ใช้ตัดในงานนี้ คุณสามารถบันทึกย้อนหลังได้ในภายหลัง”
    - อนุญาตให้ complete ได้ (ไม่ block)

---

## 6. UI/UX Details สำหรับ CUT Panel

### 6.1 Sheet Selection Modal

- Search box ด้านบน:
  - ค้นจาก sheet_code, GRN number, note
- ตาราง:
  - Sheet Code
  - GRN Number
  - Area Original
  - Area Used
  - Area Remaining
  - Input: Used Area (inline input)
  - ปุ่ม “ใช้”

UX:

- คลิก row → focus input used_area
- กด Enter → submit ใช้งาน
- ถ้า used_area > remaining → error ทันที

### 6.2 Usage List ใน Panel

- แสดงด้านล่างปุ่ม CUT action
- Columns:
  - Sheet Code
  - Used Area
  - เวลา (short form)
- ถ้า session ยังไม่ complete:
  - แสดง icon ลบ (ลบ usage ได้, เรียก API unbind ถ้าต้องรองรับ)
- ถ้า session complete:
  - icon ลบถูกปิด (readonly)

---

## 7. Supervisor / Audit Integration

### 7.1 ใช้ Endpoint เดิม

ไม่ต้องสร้างหน้าใหม่ แต่:

- เพิ่มความสามารถใน `ComponentBindingService` หรือ service ใหม่สำหรับ:
  - `getLeatherSheetUsagesByToken(token_id)`
- ให้ `dag_supervisor_sessions.php` (หรือ tooling อื่นในอนาคต) สามารถเรียกใช้ service นี้เพื่อแสดงข้อมูล (ถ้าต้องการ)

### 7.2 Logging & Safety

- ทุก usage log คือการ “ลด” remaining area แบบ logical (ไม่ต้องคำนวณ stock ledger จริงใน task นี้)
- ถ้าในอนาคตต้องมีการแก้ไข usage:
  - ให้ทำผ่าน endpoint เฉพาะ supervisor (task ถัดไป)
  - และ log การแก้ไขแยกต่างหาก

---

## 8. Permissions

### 8.1 Migration

- ไฟล์: `database/tenant_migrations/2025_12_leather_sheet_usage_permissions.php`
- สร้าง 2 permissions:
  - `leather.sheet.view`
  - `leather.sheet.use`
- Auto-assign ให้:
  - Tenant admin
  - Production manager role (ถ้ามี)

### 8.2 Enforcement

- `list_available_sheets` + `list_sheet_usage_by_token` → `leather.sheet.view`
- `bind_sheet_usage` → `leather.sheet.use`

---

## 9. Acceptance Criteria

1. ช่าง CUT สามารถ:
   - เปิด CUT behavior panel
   - เลือก Leather Sheet จาก modal
   - ใส่ used_area และบันทึกได้
2. Usage ทุกครั้งถูกบันทึกใน `leather_sheet_usage_log` พร้อม token, sheet, worker
3. Remaining area ของแต่ละ sheet ถูกคำนวณถูกต้องเมื่อเรียก `list_available_sheets`
4. CUT complete ทำได้แม้ไม่มี usage (soft warning เท่านั้น)
5. UI ของ CUT panel แสดงรายการ leather sheets ที่ถูกใช้แล้ว
6. Supervisor สามารถดึง usage ของ token ผ่าน service/endpoint ได้ (แม้ยังไม่มีหน้า UI เฉพาะ)
7. ไม่มีการเปลี่ยน structure ของ GRN / leather_sheet เดิม
8. ไม่มีผลกระทบกับ Standard GRN หรือ Material system อื่นๆ
9. Syntax check (`php -l`, JS lint) ผ่านทุกไฟล์ที่เกี่ยวข้อง

---

## 10. Notes for AI Agent

- ห้ามแก้ไข schema ของ:
  - `grn` เดิม
  - `leather_sheet` เดิม
- ห้ามแตะ logic ของ super_dag (CUT/STITCH/EDGE/QC) เกินกว่าที่ระบุใน task
- ถ้าพบ error เดิมในไฟล์ที่แก้ ให้ log ไว้ใน `docs/dag/tasks/task13.12_results.md`
- หลัง implement เสร็จ:
  - สร้าง `docs/dag/tasks/task13.12_results.md` สรุปไฟล์ที่แก้, ผล test, และ TODO ถัดไป