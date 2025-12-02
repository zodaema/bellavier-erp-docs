# Task 13.10 — Unified Leather GRN Flow (One-Entry Point)

**Status:** PLANNING  
**Area:** Components / Materials / Leather Traceability  
**Depends on:**  
- Task 13.3–13.9 (Component + Allocation Layer ready)  
- Existing Materials + Material Lots module

---

## 1. Context

ปัจจุบัน Flow รับหนังเข้าโกดังซับซ้อนเกินไปสำหรับคนคลัง:

1. รับหนังมาจริง 10 ผืน
2. ต้องไปสร้าง **Materials** (ถ้าเป็นหนังตัวใหม่)
3. ต้องกรอก **Material Lot** แยก (GRN-like)
4. ถ้าต้องใช้ `leather_sheet` และ physical traceability (Task 13.8)  
   → ต้องกรอก Sheet แยกเพิ่มอีก

➡ ส่งผลให้เกิด “การกรอกข้อมูลซ้ำ” หลายหน้า / หลายระบบ และทำให้คนคลังไม่อยากใช้ระบบ

**เป้าหมายของ Task 13.9**  
ทำให้ “การรับหนังเข้า” เหลือ **การกรอกครั้งเดียว** บนหน้า GRN เดียว แล้วระบบสร้าง:

- Material Lot
- Leather Sheets (N ผืน)
- Link ไปยัง Material SKU + Batch
- (เตรียม hook สำหรับ stock movement ในอนาคต)

---

## 2. Goal / Scope

### 2.1 Goals

1. สร้าง **Leather GRN Page** ใหม่ (single entry point)
2. เมื่อบันทึก GRN:
   - สร้าง 1 แถวใน `material_lot` (ใช้เป็น GRN header)
   - สร้าง N แถวใน `leather_sheet` สำหรับแต่ละผืน
   - ผูก `leather_sheet` ทั้งหมดกับ GRN/lot และ material SKU
3. ลดการกรอกซ้ำ:  
   - คนคลังไม่ต้องไปสร้าง Leather Sheet manual อีก
4. ต่อยอดจาก Physical Traceability Layer (Task 13.8):  
   - CUT behavior จะสามารถเลือก `sheet_id` จากชุดที่ระบบสร้างให้จาก GRN

### 2.2 In Scope

- New page + view + JS สำหรับ Leather GRN เฉพาะ “หนัง” เท่านั้น
- ใช้ **`material` + `material_lot` table เดิม** เป็นฐาน ไม่สร้าง table GRN ใหม่ถ้าไม่จำเป็น
- ผูก `leather_sheet.sku_material` + `leather_sheet.batch_code` กับ `material` / `material_lot`
- API ใหม่สำหรับสร้าง GRN + ดึงข้อมูลที่จำเป็น
- Permission แยกต่างหากสำหรับ “รับหนังเข้า”
- มี transaction ครอบ header + sheets ให้เป็น atomic operation

### 2.3 Out of Scope (ทำทีหลัง)

- Stock movement / GL posting (Kardex) จริงจัง → จะทำใน task ถัดไป
- การรับวัตถุดิบประเภทอื่นนอกจากหนัง (ด้าย, อะไหล่, กาว ฯลฯ)  
  → ยังใช้ Material Lots modal เดิมไปก่อน
- UI แก้ไข leather_sheet ทีละผืนเชิงลึก (ตำหนิ, defect map, รูปถ่ายผืน)  
  → ทำเป็นหน้า “Leather Sheet Inspector” ภายหลัง

---

## 3. UX & Flow

### 3.1 Leather GRN Page (ใหม่)

**Route & Files (เสนอ):**

- Page: `page/leather_grn.php`
- View: `views/leather_grn.php`
- JS: `assets/javascripts/materials/leather_grn.js`
- API: `source/leather_grn.php`

**Permission:**

- Code: `leather_grn.manage`
- ต้องกำหนดใน tenant migrations + assign ให้ role `Warehouse` / `Operations` / `Owner` / `Admin`

---

### 3.2 UI Layout (ระดับ wireframe)

**Section A — GRN Header**

Fields (บนสุดของหน้า หรือบน modal):

- `grn_number` (optional, auto-generate ถ้าเว้นว่าง)
- `sku_material` (select2 จากตาราง `material` แต่ filter เฉพาะที่เป็น “Leather”)
- `supplier_name` (text / dropdown ถ้ามี master)
- `invoice_number`
- `received_date`
- `grade` (A/B/C, etc.)
- `thickness_mm` (ค่า default ของ lot)
- `location` (rack/section)
- `note` (long text)
- `total_sheets` (จำนวนผืนที่รับเข้ามา)

**Section B — Leather Sheets (dynamic rows)**

ตารางด้านล่าง:

คอลัมน์ต่อ 1 ผืน:

- running no.
- `sheet_code` (อาจ auto = `{sku}-{grn_number}-{index}` แต่แก้ได้)
- `area_sqft`
- (optional) `weight_kg`
- `status` (default = `available`)
- small “copy value down” buttons เช่น copy area ทั้ง column

Shortcut:

- ถ้าผู้ใช้ใส่ `total_sheets = 10` → JS สร้าง 10 แถวโดยอัตโนมัติ
- ปุ่ม “Fill all with area X” เอาไว้กรณีทุกผืนขนาดใกล้กัน

**Section C — Actions**

- ปุ่ม “บันทึก GRN”
- ปุ่ม “ยกเลิก / เคลียร์ฟอร์ม”

หลัง submit:

- แสดง Toast: “บันทึกรับหนังสำเร็จ — สร้าง Sheet 10 ผืนแล้ว”
- แสดง summary ด้านล่าง (หรือ redirectไปหน้า view GRN)

---

## 4. Backend & Data Model

### 4.1 Reuse Tables เดิม

ไม่สร้าง table GRN ใหม่ถ้าไม่จำเป็น — ให้ใช้:

- `material` (เดิม)  
- `material_lot` (เดิม) → **ใช้เป็น GRN header**
- `leather_sheet` (จาก Task 13.8) → รายการผืนหนัง

Relation เสนอ:

- `material_lot.id_lot` (PK)  
- `leather_sheet` เพิ่ม field (ถ้ายังไม่มี):
  - `id_lot` (FK → material_lot.id_lot) **หรือ** เก็บ `batch_code = material_lot.lot_code`
- `leather_sheet.sku_material` = `material.sku`

> ถ้าข้อมูล lot เดิมมี structure ต่างออกไป ให้จัด mapping ใน migration (ดูข้อ 5)

---

### 4.2 API: source/leather_grn.php

ใช้ pattern เดียวกับ tenant APIs อื่น:

- Bootstrap: `TenantApiBootstrap`
- Output: `TenantApiOutput`
- Permission: ตรวจ `leather_grn.manage`
- Rate limit: medium (เช่น 60/60sec)

**Actions**

1. `init` (GET)
   - ใช้ตอนโหลดหน้า
   - ส่ง:
     - รายการ leather materials ที่เลือกได้
     - ค่า default เช่น location list, grades, thickness options
   - Response:
     ```json
     {
       "ok": true,
       "data": {
         "materials": [...],
         "grades": [...],
         "locations": [...],
         "thickness_defaults": [...]
       }
     }
     ```

2. `save` (POST)
   - รับ payload:
     ```json
     {
       "header": {
         "grn_number": "...(optional)...",
         "sku_material": "...",
         "supplier_name": "...",
         "invoice_number": "...",
         "received_date": "YYYY-MM-DD",
         "grade": "A",
         "thickness_mm": 1.4,
         "location": "Rack A1",
         "note": "...",
         "total_sheets": 10
       },
       "sheets": [
         {
           "sheet_code": "...",
           "area_sqft": 12.3,
           "weight_kg": 3.4
         },
         ...
       ]
     }
     ```
   - Validation:
     - `sku_material` ต้องเป็น material ที่ flag เป็น “Leather”
     - `total_sheets` = `count(sheets)`
     - ทุก `sheet.area_sqft > 0`
   - Processing (1 transaction):
     1. สร้าง `material_lot` 1 แถว
     2. สำหรับแต่ละ sheet:
        - สร้างแถวใน `leather_sheet`:
          - `sku_material`, `batch_code` (map จาก material_lot), `sheet_code`,
            `area_sqft`, `area_remaining_sqft`, `status = 'available'`, `id_lot` (ถ้าใช้)
   - Response:
     ```json
     {
       "ok": true,
       "data": {
         "lot": {...},
         "sheets": [...],
         "summary": {
           "total_sheets": 10,
           "total_area_sqft": 120.0
         }
       }
     }
     ```

3. (Optional, ถ้าว่าง) `list` (GET)
   - ส่งประวัติ GRN ที่สร้างจากหน้าใหม่นี้
   - ใช้ field flag เช่น `material_lot.is_leather_grn = 1` (ถ้าเพิ่มใน migration)

---

## 5. Database Changes (ถ้าจำเป็น)

สร้าง tenant migration ใหม่:

- `database/tenant_migrations/2025_12_leather_grn_unified_flow.php`

Tasks ใน migration นี้:

1. ตรวจสอบ `material_lot`:
   - เพิ่ม column เสริม (ถ้าจำเป็น):
     - `is_leather_grn TINYINT(1) DEFAULT 0`
2. ตรวจสอบ `leather_sheet`:
   - ถ้ายังไม่มี `id_lot` ให้เพิ่ม:
     - `id_lot INT NULL` + FK → `material_lot(id_lot)`
3. เสริม indexes ตามเหมาะสม:
   - `leather_sheet (sku_material, id_lot, status)`
   - `material_lot (sku_material, is_leather_grn)`

> ต้องใช้ `migration_add_column_if_missing()` / helpers ตามมาตรฐาน bootstrap migrations และต้อง idempotent

---

## 6. Frontend Implementation Notes

- ใช้ DataTables / Bootstrap / Sash Components ตาม style เดิม
- อย่าเขียน JS แบบสปาเก็ตตี้:
  - แยกไฟล์: `leather_grn.js`
  - มี `BG.LeatherGRN` namespace หรือ object เดียว
- ใช้ `BG.ajaxJson()` / Utils เดิมถ้ามี
- Validation ฝั่ง JS ให้ช่วย user:
  - เตือนถ้า `total_sheets` ไม่ตรงกับจำนวน row
  - เตือนถ้า area เป็น 0
- ใช้ข้อความภาษาไทยสั้นๆ ชัดเจนสำหรับคนคลัง

---

## 7. Safety Rails & Constraints

1. **ห้าม** ลบ / เปลี่ยน structure table `material` หรือ `material_lot` เดิมที่มี data ใช้งานอยู่แล้ว
2. ห้ามปิดการทำงานของ Material Lots modal เดิม — leather GRN เป็น “ช่องทางใหม่” เท่านั้น
3. Integration กับ component allocation (Task 13.8):
   - อย่าเปลี่ยน schema ของ `leather_sheet` ที่ใช้แล้ว
   - แค่เพิ่ม FK/fields ที่ backward compatible ได้เท่านั้น
4. ทุกการ insert lot + sheets ต้องอยู่ใน transaction เดียว
5. Error จากการสร้าง sheet บางแถว **ต้อง rollback ทั้ง GRN** ไม่ให้เกิด half-created data

---

## 8. Testing

### 8.1 Manual Test Cases (ขั้นต่ำ)

1. **Happy Path**
   - เลือกหนัง 1 SKU, ใส่ total_sheets=10, ใส่ area แต่ละผืน
   - กด Save → ดูว่า:
     - มี 1 material_lot
     - มี 10 leather_sheet ผูกกับ lot + sku ถูกต้อง

2. **Validation**
   - ใส่ total_sheets=10 แต่ส่ง sheets 8 แถว → ต้อง error
   - ใส่ area=0 ในบางแถว → ต้อง error

3. **Permission**
   - User ไม่มี `leather_grn.manage` → API ตอบ 403

4. **Backward Compatibility**
   - Material Lots modal เดิมเปิดได้ ปรับ lot เดิมได้
   - หน้าที่ใช้ leather_sheet (CUT behavior, allocation) ยังทำงานได้

### 8.2 Future Integration Check

- ลองสร้าง GRN ใหม่ → ไปที่หน้าที่เลือก `sheet_id` ตอน CUT (ภายหลัง)  
  ต้องเห็น sheet ที่เพิ่งสร้างใน dropdown

---

## 9. Definition of Done

- ✅ Leather GRN page ทำงานได้จริง (create แถว lot + sheets)
- ✅ DB schema เปลี่ยนแบบ idempotent, ไม่พัง data เดิม
- ✅ Permission `leather_grn.manage` ทำงาน ถูก bind กับ role ที่เหมาะสม
- ✅ มี test cases (อย่างน้อย manual) บันทึกใน `task13.9_results.md`
- ✅ ไม่ส่งผลกระทบต่อ flow เดิม (Materials / Lots / Components / super_dag)

---