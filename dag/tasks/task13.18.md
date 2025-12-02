
# Task 13.18 — Material Sheet Registry (Hybrid-C) & CUT Integration

## Objective

ยกระดับระบบ “Leather Sheet Registry” ให้กลายเป็น **Material Sheet Registry แบบมาตรฐานกลาง** ที่ใช้ได้กับทุกชนิดวัสดุที่คิดเป็น “พื้นที่” โดยใช้แนวคิด **Hybrid-C** คือ:

- ภายในระบบ (canonical) ใช้หน่วย **cm²** สำหรับการคำนวณทุกอย่าง
- แต่ยังเคารพ UOM เดิมของโลกจริง (เช่น sqft, m², sheet) เพื่อให้ GRN / รายงาน / UX สำหรับมนุษย์อ่านง่าย
- เชื่อมโยงเข้ากับ CUT pipeline แบบ 100% เพื่อให้การตัดงาน, การคำนวณคงเหลือ, และการตามรอยการใช้วัสดุเป็นมาตรฐานเดียวกันทั้งระบบ

---

## แนวคิด Hybrid-C (สรุป)

1. **Canonical Unit = cm²**
   - ทุก material ที่ใช้ “พื้นที่” (หนัง, ผ้า, canvas, lining, foam ฯลฯ) จะถูกแปลงเป็น cm² เวลาเก็บใน Material Sheet Registry
   - Engine ทุกตัว (CUT reserve / commit / wastage / dashboard) ใช้ cm² เป็นฐาน

2. **Display UOM = ตามโลกจริง**
   - GRN สามารถคีย์วัสดุในหน่วยที่มาจากซัพพลายเออร์ เช่น:
     - หนัง: sqft
     - ผ้า/lining: m²
   - ระบบแปลงค่าจาก display UOM → cm² อัตโนมัติ แล้วเก็บทั้งสองอย่างไว้:
     - canonical_area_cm2
     - display_qty + id_uom_display

3. **Sheet Count**
   - สำหรับวัสดุที่มาเป็น “แผ่น/ใบ” (เช่น leather sheet, foam board, lining sheet) ให้เก็บจำนวนใบเป็นตัวเลข (sheet_count) เพิ่มเติม
   - ใช้เพื่อ UX และการตามรอย (เช่น “ใช้จากใบที่ 1/3”)

---

## Goals

### 1. Unify Material Sheet Registry

- ปรับโครงสร้างจาก “leather_sheet” → “material_sheet” (หรือใช้ชื่อ table ใหม่ แต่ต้องมี migration ที่ชัดเจน)
- รองรับทุก material type ที่มีลักษณะเป็นแผ่น/พื้นที่ เช่น Leather, PU, Fabric, Lining, Foam, Canvas, Sticker ฯลฯ
- ใช้ FK ไปที่ `material.sku` เป็นมาตรฐาน (ซึ่ง map ต่อไปยัง `stock_item` ผ่าน schema ที่นิยามใน Task 13.15–13.16)

### 2. Normalize Sheet Attributes (Hybrid-C)

ออกแบบ schema สำหรับ `material_sheet` (แนวคิดหลัก):

- `id_sheet` (PK)
- `sheet_code` (unique, human-friendly code)
- `sku_material` (FK → material.sku)
- `lot_code` (เชื่อมกับ material_lot)
- **Canonical fields (ใช้ใน engine):**
  - `area_total_cm2` — พื้นที่เต็มในหน่วย cm²
  - `area_usable_cm2` — พื้นที่ที่ใช้ได้จริงใน cm² (หลังหัก defect / margin)
  - `area_used_cm2` — พื้นที่ที่ถูกใช้ไปแล้วใน cm²
- **Display / UX fields:**
  - `display_qty` — จำนวนตาม UOM ที่คีย์มาจาก GRN (เช่น 22.0)
  - `id_uom_display` — FK → UOM (เช่น sqft, square_meter, sheet)
  - `sheet_count` — จำนวนใบใน GRN (ถ้ามี, เช่น 1 ใบ, 2 ใบ)
- **Physical attributes (optional แต่ควรเผื่อ future):**
  - `width_mm`
  - `height_mm`
  - `grain_direction` (เช่น along_length / across_width / unknown)
- **Meta:**
  - `source` (GRN / MANUAL / ADJUST)
  - `remarks`
  - `created_by`, `created_at`

### 3. FULL Integration กับ CUT Behavior

CUT Behavior ต้อง:

- ดึงรายการ sheet ที่ยังไม่หมด (area_usable_cm2 - area_used_cm2 > 0)
- Reserve usage เป็น cm² (canonical) ตาม BOM Panel / Pattern ที่ต้องตัด
- Commit usage หลังยืนยันการตัด (complete behavior)
- ปรับ `area_used_cm2` และตรวจว่า:
  - ถ้า `area_used_cm2 >= area_usable_cm2` → mark sheet ว่า “หมด”
  - ถ้าใช้ไปเกิน threshold (เช่น 80%) → flag ว่า “ใกล้หมด” เพื่อ UX

ผูกข้อมูลกลับไปยัง:

- Token (production token id)
- Job Ticket / MO
- BOM panel/chunk ที่ถูกตัดจาก sheet นั้น

### 4. Improve Traceability

เพิ่มส่วนเชื่อมโยงต่อไปนี้ (อาจอยู่ใน `material_sheet_usage`):

- ใครเป็นคนเพิ่ม GRN (user id)
- ใครเป็นคนใช้ sheet (cutter / operator)
- ใช้ sheet กับ Token ไหน
- ใช้ไปกี่ cm² ในแต่ละครั้งที่ตัด
- ใช้ตัดชิ้นส่วน BOM / Panel อะไรบ้าง
- เวลาใช้งาน (timestamps)

---

---

## Required Clarifications for Implementation (Must Follow)

เพื่อป้องกันไม่ให้ Agent เดาเองและทำให้ behavior เพี้ยน ข้อกำหนดด้านล่างนี้ต้องถือเป็นกติกากลางในการ implement Task 13.18

### 1) Migration Rules (leather_sheet → material_sheet)

สำหรับข้อมูลเก่าที่อยู่ใน `leather_sheet` ให้ migrate ตามกติกา:

- `area_total_cm2`  = ค่า area เดิม (หน่วย sqft) × **929.0304**
- `area_usable_cm2` = `area_total_cm2` (initial state, ยังไม่หัก defect)
- `area_used_cm2`   = 0 (เริ่มต้น)
- `display_qty`     = ค่า area เดิม (หน่วย sqft)
- `id_uom_display`  = UOM ที่แทนค่า `sqft`
- `sheet_count`     = 1 (default สำหรับ leather ที่รับเข้าเป็นใบเดียวต่อ GRN line)
- `lot_code`        = lot เดิมจาก `leather_sheet`

หากพบ record ใน `leather_sheet` ที่ไม่สามารถระบุหน่วยเดิมได้อย่างชัดเจน ให้ log แยกในผลลัพธ์ของ `task13.18_results.md` เพื่อพิจารณา manual fix ภายหลัง

### 2) Sheet Code Format

เพื่อให้ sheet_code มีมาตรฐานและอ่านง่าย ให้ใช้รูปแบบ:

```text
SH-{MATERIAL_TYPE_CODE}-{6DIGITS}
ตัวอย่าง: SH-LTH-000123, SH-CVS-000045
```

โดยที่ `MATERIAL_TYPE_CODE` มาจาก material type mapping ที่มีอยู่แล้ว (เช่น LTH = Leather, CVS = Canvas, LIN = Lining เป็นต้น)

### 3) Unsupported Materials Behavior

Task นี้รองรับเฉพาะวัสดุที่เป็น "พื้นที่" (area-based) เท่านั้น:

- ถ้า `material` หรือ `stock_item` มีประเภท UOM ที่ไม่ใช่ area-based (เช่น purely length-based roll, หรือ count-only โดยไม่มีพื้นที่) → **ห้ามสร้าง `material_sheet`**
- ระบบต้องตอบ error ที่ชัดเจน เช่น:

```json
{
  "ok": false,
  "error": "unsupported_material_for_sheet_registry",
  "message": "This material is not area-based and cannot be registered as a sheet."
}
```

วัสดุประเภท roll-length หรือกรณีอื่น ๆ จะถูกออกแบบ pipeline แยกใน Task ถัดไป (อย่าเดาใน Task 13.18)

### 4) width_mm / height_mm Rules

- สำหรับ **Leather** (หนังแบบ irregular shape):
  - `width_mm` และ `height_mm` เป็น **optional** — ใช้เพื่อ reference เท่านั้น ไม่ใช้คำนวณ area canonical
- สำหรับวัสดุที่เป็นแผ่นสี่เหลี่ยมชัดเจน เช่น **foam board, lining sheet, แผ่น PU ที่ตัดเป็น panel**:
  - ถ้าจะใช้ `sheet` เป็น display UOM หรือจะ derive cm² จากขนาด → ต้องกรอก `width_mm` และ `height_mm`
  - canonical area สามารถคำนวณได้จาก: `width_mm × height_mm / 100` (แปลงเป็น cm²) หรือใช้ค่าที่คีย์มาใน GRN ตามรูปแบบที่ออกแบบไว้

### 5) UOM Conversion Table (ต้องใช้ค่าชุดนี้เท่านั้น)

ค่ามาตรฐานสำหรับการแปลงเป็น cm²:

- 1 **sqft**  = **929.0304 cm²**
- 1 **m²**    = **10000 cm²**
- 1 **sheet** = ต้องคำนวณจาก `width_mm` × `height_mm` → cm² (ถ้าไม่มีข้อมูลขนาด ห้าม derive เอง ให้ block หรือ log error)

Agent ห้ามใช้ค่าปัดเศษอื่น เช่น 929 หรือ 929.1 โดยพลการ

### 6) Reserve / Commit Model ใน CUT

แนวคิดสำหรับ CUT behavior:

- `reserve_area_cm2` = ผลรวมพื้นที่ของ panel ทั้งหมดที่ต้องตัดจาก sheet นั้น (Σ panel_area_cm2)
- `commit_area_cm2`  = `reserve_area_cm2 × usage_factor`
  - โดยที่ `usage_factor` default = **1.00** สำหรับเฟสแรก
  - ในอนาคตอาจเพิ่มให้ config ได้ต่อ behavior/graph

ใน Task 13.18 ให้ implement modelแบบตรงไปตรงมา:
- ใช้ `reserve_area_cm2` = `commit_area_cm2` (usage_factor = 1.00)
- เขียนโค้ด/โครงสร้างให้รองรับการเพิ่ม usage_factor ใน Task ถัดไปได้ง่าย (เช่น เก็บเป็น field ใน qc/cut_policy หรือ node_params)

---

## Final Deliverables

### 1. Database Migration

1. สร้าง table `material_sheet` (ตาม Hybrid-C schema ด้านบน)
2. สร้าง table `material_sheet_usage`:
   - `id_usage` (PK)
   - `id_sheet` (FK → material_sheet)
   - `token_id` (หรือ id_token)
   - `panel_code` / `bom_component_code` (optional)
   - `area_used_cm2`
   - `used_by` (user id)
   - `used_at`
   - `note`
3. (Optional but recommended) `material_sheet_audit` หรือใช้ audit mechanism เดิมของระบบ
4. Migration script สำหรับย้ายจาก `leather_sheet` → `material_sheet`:
   - map ฟิลด์เดิม (area, lot, sku) → canonical cm²
   - กำหนด `id_uom_display` เริ่มต้น (เช่น sqft สำหรับหนังที่รับมาเป็น sqft)
   - ตั้งค่า `display_qty` ให้สอดคล้องกับข้อมูลเก่าเท่าที่ทำได้

### 2. API Updates

อัปเดต/สร้างไฟล์:

- `source/leather_grn.php`:
  - เปลี่ยนจากการสร้าง `leather_sheet` → สร้าง `material_sheet` แทน
  - รองรับการคีย์ข้อมูล GRN ใน UOM display (เช่น sqft, m²) แล้ว convert → cm² อัตโนมัติ
- `source/leather_sheet_api.php`:
  - ปรับให้เป็น wrapper ที่เรียก `material_sheet_api.php` หรือ mark ว่า deprecated
- สร้างใหม่ `source/material_sheet_api.php`:
  - `list_available_sheets` — ดึง sheet ที่ยังเหลือพื้นที่เพียงพอ
  - `bind_sheet_usage` — commit usage (สร้าง record ใน material_sheet_usage และอัปเดต area_used_cm2)
  - `list_sheet_usage_by_token`
  - `unbind_sheet_usage` (สำหรับกรณียกเลิก/rollback ก่อน complete)

### 3. Behavior Engine Integration

ปรับ Behavior Execution Engine:

- ใน CUT behavior:
  - ใช้ Material Resolver → หา sku_material ของ token นั้น
  - เรียก API `list_available_sheets` ด้วย sku_material
  - ให้ช่างเลือก sheet (หรือ auto-pick ตาม priority rule)
  - Reserve usage (ยังไม่ commit ถ้ายังไม่ complete)
  - เมื่อ behavior complete → commit usage ไปที่ `material_sheet_usage` + อัปเดต `area_used_cm2`
- เพิ่ม validation:
  - ถ้า area ที่ต้องใช้ > area ที่เหลือใน sheet → block หรือเตือน
  - มี soft-warning ถ้า complete CUT โดยไม่ผูก sheet usage (กันลืม)

### 4. UI Enhancements

เพิ่ม/อัปเดต UI:

- **Sheet Browser Panel**:
  - แสดง list sheet ตาม sku_material, lot, location
  - แสดง:
    - พื้นที่รวม (cm²)
    - พื้นที่ที่ใช้ไป / เหลือ (cm²)
    - Display UOM + จำนวนเดิม (เช่น 22 sqft)
    - Sheet count (ถ้ามี)
- **Sheet Usage Timeline** (basic version พอ):
  - แสดง usage ของแต่ละ sheet เรียงตามเวลา
- **Sheet Remaining Heatmap** (optional, future enhancement):
  - เน้น UX ช่วยช่างเห็นว่าศักยภาพของแต่ละแผ่นเหลือประมาณไหน

---

## Acceptance Criteria

- GRN flow:
  - สร้าง `material_sheet` เสมอ (แทน `leather_sheet`)
  - รองรับการคีย์หน่วย sqft/m² แล้ว convert เป็น `area_total_cm2` อย่างถูกต้อง
- CUT Behavior:
  - ใช้ `material_sheet_usage` ในการบันทึก usage ของ sheet
  - ไม่สามารถใช้ sheet เกิน `area_usable_cm2`
  - Sheet ถูก mark หมดเมื่อ `area_used_cm2 ≥ area_usable_cm2`
- Traceability:
  - สามารถย้อนดูได้ว่า sheet ใดถูกใช้กับ token ไหน เท่าไร และโดยใคร
- Backward compatibility:
  - ข้อมูลจาก `leather_sheet` เดิมถูก migrate เข้าสู่ `material_sheet` โดยไม่ทำให้ GRN/CUT flow เดิมพัง
- UOM:
  - ระบบมี canonical unit = cm² ใช้ภายใน engine
  - UOM แสดงผล (sqft, m², sheet) สำหรับ GRN/รายงานยังทำงานได้ตามเดิมหรือดีกว่าเดิม

---

## Out of Scope (สำหรับ Task 13.18)

- ยังไม่ทำ Sheet Reservation Engine แยก (hard reserve ล่วงหน้า) — จะไปทำใน Task 13.19
- ยังไม่ทำ Dashboard เต็มรูปแบบ (Wastage Analytics, Efficiency per Pattern) — ไว้ใน Task 13.20+
- ยังไม่รองรับ material ประเภท roll-length (เช่น วัสดุที่ใช้ความยาวอย่างเดียว) แบบสมบูรณ์ — ให้ block หรือ mark ว่า “unsupported” ไว้ก่อนถ้าเจอเคสนี้

---

## Next Step (13.19)

- Implement Sheet Reservation Engine (soft/hard reserve)
- Re-check BOM integration กับ CUT Panel
- เตรียมข้อมูลสำหรับ Wastage Dashboard (Task 13.20)