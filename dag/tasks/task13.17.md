

# Task 13.17 — Leather GRN → Stock Movement (Stock Card Integration)
Status: Draft
Owner: BGERP Engineering
Module: Materials / Inventory / Stock Card
Depends On: Task 13.16 (Leather GRN → Material Auto-Create)
Priority: High
Type: Inventory Integration
Sprint: DAG S13

## 1. Background / Problem

ปัจจุบันหน้า **Leather GRN** (`source/leather_grn.php`) ทำงานดังนี้:
- เลือก `stock_item.sku` จาก master
- Auto-create `material` record ถ้ายังไม่มี (Task 13.16)
- สร้าง `material_lot`
- สร้าง `leather_sheet`

แต่หน้า **Stock Card** (stock ledger) ยัง **ไม่แสดงผลการรับเข้า** ที่ทำผ่าน Leather GRN เนื่องจาก:
- GRN leather ยังไม่สร้าง "stock movement" ในตารางที่ stock_card ใช้เป็นแหล่งข้อมูลหลัก
- ทำให้ภาพรวมสต็อก (ยอดคงเหลือ, ประวัติการเคลื่อนไหว) ไม่สะท้อนการรับหนังที่เกิดจาก Leather GRN

ดังนั้นต้องเพิ่มขั้นตอน: เมื่อบันทึก Leather GRN สำเร็จ → ต้องมีการสร้าง movement (IN) ให้กับ SKU/lot/qty นั้น ๆ เพื่อให้ stock_card มองเห็นยอดอย่างถูกต้อง

## 2. Objective

ทำให้ Leather GRN เชื่อมเข้ากับระบบสต็อกกลางอย่างสมบูรณ์:

> เมื่อบันทึก Leather GRN สำเร็จ ระบบต้องสร้าง "Stock Movement (IN)" สำหรับ SKU / Lot / ปริมาณที่รับเข้า และหน้า Stock Card ต้องสะท้อนยอดเพิ่มอย่างถูกต้อง

เป้าหมายย่อย:
- ทุก GRN leather ที่บันทึกสำเร็จต้องมี movement record ในตารางสมุดสต็อก
- หน้า stock_card แสดงยอดเพิ่มตามจำนวนรับจริง
- Movement และ GRN ทำงานใน transaction เดียวกัน (rollback ร่วมกัน)
- ไม่กระทบ flow อื่นที่ใช้ stock_card อยู่เดิม

## 3. Scope

**รวมใน Task นี้:**
- วิเคราะห์หน้า stock_card เพื่อระบุตาราง/วิวที่ใช้เป็น stock ledger
- วิเคราะห์ schema จาก `schema_raw_dump.md` เพื่อหาตาราง movement ที่เหมาะสม (เช่น `stock_movement`, `inventory_movement` หรือชื่อเทียบเคียง)
- เพิ่ม logic ใน `source/leather_grn.php` ให้สร้าง movement (IN) หลังจาก GRN + material_lot + leather_sheet บันทึกสำเร็จ
- ทำให้การสร้าง movement อยู่ใน transaction เดียวกับ GRN

**ไม่รวม (จะทำใน Task อื่น):**
- UI แสดง GRN history / Lot / Sheet อย่างละเอียด
- Stock movement สำหรับงานอื่น (CUT consumption / ISSUE / RETURN / ADJUSTMENT)
- การ migrate movement ย้อนหลังสำหรับ GRN เดิม (ย้อนหลัง)

## 4. High-Level Design

### 4.1 Identify Stock Movement Source

1. เปิดโค้ดหน้า Stock Card (PHP/JS) เพื่อดู query หลักว่าดึงจาก:
   - ตารางอะไร (เช่น `stock_movement`, `inventory_tx`, `warehouse_stock_card` หรือ view อื่น)
   - ฟิลด์สำคัญที่ stock_card ใช้ (เช่น `sku`, `qty`, `direction`, `movement_type`, `movement_date`, `warehouse_id` ฯลฯ)

2. Cross-check กับ `docs/architecture/schema_raw_dump.md` เพื่อตรวจสอบ schema ของตารางนั้น:
   - Primary key
   - คอลัมน์ที่จำเป็น
   - Foreign keys (ถ้ามี)

3. สรุปว่า stock ledger หลักของระบบ คือ table/view ใด และต้องใช้คอลัมน์อะไรบ้างตอน insert movement สำหรับ GRN

### 4.2 GRN → Movement Mapping

กำหนด mapping มาตรฐานระหว่าง Leather GRN กับ stock movement เช่น:

- **SKU:** ใช้จาก `stock_item.sku` ที่เลือกบนหน้า GRN
- **Qty:** ปริมาณที่รับจริงจากแบบฟอร์ม GRN (เช่น `qty_received` หรือ `total_area` แล้วแต่การออกแบบ stock unit)
- **Direction / Movement Type:**
  - ค่า direction: `IN` หรือ `+1`
  - movement_type: `GRN_LEATHER` หรือ code ที่ใช้ร่วมกับระบบปัจจุบัน
- **Reference:**
  - ref_table: `'leather_grn'` (หรือค่าคงที่ตามมาตรฐานระบบ)
  - ref_id: primary key ของ GRN record
  - ref_no: หมายเลขเอกสาร GRN (ถ้ามี เช่น `grn_no`)
- **Date:**
  - ใช้วันที่เอกสาร GRN หรือ `NOW()` ถ้าไม่ได้แยก
- **Warehouse:**
  - ถ้าระบบรองรับหลายคลัง ให้ใช้ค่า warehouse จาก GRN
  - ถ้าไม่รองรับ ให้ใช้ค่า default warehouse

การ insert movement อาจทำได้แบบ:
- 1 แถวต่อ GRN header (รวมปริมาณทั้งหมดของ SKU เดียว)
- หรือ 1 แถวต่อ GRN line (ถ้ามีหลาย SKU/หลายแถวในอนาคต)

สำหรับเฟสนี้ ให้เลือกแบบที่ตรงกับโครงสร้างปัจจุบันของ Leather GRN (ส่วนใหญ่คือ 1 SKU ต่อ GRN)

### 4.3 Transaction Integration

ใน `leather_grn.php` (action `save` หรือเทียบเท่า):

1. ภายใน transaction ที่บันทึก GRN header + lot + sheet:
   - เมื่อข้อมูล GRN และ lot/sheet ถูก insert สำเร็จแล้ว
   - เรียกฟังก์ชันช่วย (helper) เพื่อ insert movement (IN)

2. ถ้า insert movement ล้มเหลว:
   - ต้อง throw error และ rollback transaction ทั้งหมด (GRN + lot + sheet + movement)

3. ถ้ามีการ rollback ด้วยเหตุผลอื่นก่อนหน้า:
   - ห้ามมี movement ถูกสร้างหลุดออกมา

### 4.4 Helper Abstraction (ถ้าเหมาะสม)

เพื่อใช้ซ้ำในอนาคต แนะนำให้สร้าง helper class เช่น:

- `source/BGERP/Helper/StockMovementHelper.php`

ฟังก์ชันตัวอย่าง:

- `public static function recordGrnIn(mysqli $db, array $params): void`
  - รับพารามิเตอร์จำเป็นเช่น `sku`, `qty`, `movement_type`, `ref_table`, `ref_id`, `warehouse_id` ฯลฯ
  - จัดการ insert ลงตาราง movement และโยน exception ถ้าล้มเหลว

Task นี้ไม่บังคับ แต่ถ้าโครงสร้างเข้าที่แล้ว แนะนำให้ใช้ helper เพื่อลด duplication และรองรับ use case อื่น (CUT, ISSUE, RETURN) ในอนาคต

## 5. Implementation Steps (สำหรับ Agent)

1. อ่านโค้ดหน้า stock_card และสรุปตาราง/วิวที่ใช้เป็น stock ledger
2. เปิด `schema_raw_dump.md` เพื่ออ่าน schema ของตาราง movement ที่เกี่ยวข้อง
3. สร้าง/อัปเดต helper (ถ้าตัดสินใจใช้) สำหรับ insert stock movement
4. เพิ่ม logic ใน `leather_grn.php` ภายใน transaction:
   - เตรียมพารามิเตอร์ movement ตาม mapping ข้อ 4.2
   - เรียก insert stock movement
5. เพิ่ม error handling ให้ rollback transaction หาก insert movement ล้มเหลว
6. ทดสอบด้วย test cases ในข้อ 6

## 6. Test Cases

### TC-13.17-01 — GRN Leather → Stock Card Shows IN

**Given:**
- มี `stock_item` และ SKU ที่ใช้ได้จริง

**Steps:**
1. เปิดหน้า Leather GRN และสร้าง GRN ใหม่สำหรับ SKU นั้น ปริมาณ 10 หน่วย
2. บันทึก GRN ให้สำเร็จ
3. เปิดหน้า stock_card ของ SKU เดียวกัน

**Expected:**
- มองเห็น movement ชนิด IN จาก GRN ที่สร้าง
- ยอดคงเหลือของ SKU เพิ่มขึ้น 10 หน่วย (ตามหน่วยที่ระบบกำหนด)

---

### TC-13.17-02 — Rollback บน Error

**Given:**
- จำลองให้ insert movement ล้มเหลว (เช่น บังคับให้ throw exception ใน helper หรือทำให้ constraint ผิดชั่วคราวใน dev)

**Steps:**
1. พยายามบันทึก GRN Leather
2. ตรวจสอบฐานข้อมูล

**Expected:**
- ไม่มี GRN header/lot/sheet ที่ half-done ในฐานข้อมูล
- ไม่มี movement record ที่เกี่ยวข้องถูกสร้าง
- ระบบตอบ error อย่างเหมาะสมผ่าน TenantApiOutput

---

### TC-13.17-03 — GRN ซ้ำ / Double Submit (ถ้ามีความเสี่ยง)

**Given:**
- จำลอง user กด submit ซ้ำ (เช่น กดปุ่มสองครั้ง หรือ refresh หน้าแล้วส่งอีกครั้งภายในช่วงเวลาใกล้กัน)

**Steps:**
1. สร้าง GRN Leather สำหรับ SKU เดียวกันและ payload เดิมสองครั้ง (หรือวิธีทดสอบเทียบเคียง)

**Expected:**
- ระบบไม่สร้าง movement ซ้ำสำหรับ GRN เดียวกัน (ถ้าระบบปัจจุบันรองรับ idempotency)
- ถ้าไม่รองรับ double submit ให้บันทึก behavior ที่เกิดขึ้นจริงใน `task13.17_results.md` เพื่อใช้เป็น input ใน phase ปรับปรุงถัดไป

---

### TC-13.17-04 — Multi-sheet / Single Movement vs Multi-movement

**Given:**
- GRN Leather ที่ในอนาคตอาจรองรับหลายใบ/หลาย lot (ถ้าฟังก์ชันปัจจุบันรองรับ แต่อาจยังไม่ได้ใช้จริง)

**Steps:**
1. สร้าง GRN ที่มีหลายใบ/หลาย lot (ถ้าทำได้ใน dev)
2. ตรวจสอบตาราง movement

**Expected:**
- จำนวน movement record ตรงกับดีไซน์ที่เลือก (1 ต่อ GRN หรือ 1 ต่อใบ/ต่อ lot)
- ยอดรวมปริมาณตรงกับ GRN


## 7. Acceptance Criteria

- Leather GRN ที่บันทึกสำเร็จทุกครั้งต้องสร้าง movement record ในตารางที่ stock_card ใช้
- หน้า stock_card สามารถแสดงยอดคงเหลือเพิ่มขึ้นตาม Leather GRN ได้ถูกต้อง
- ถ้า transaction ของ GRN ถูก rollback (ไม่ว่าจะเหตุผลใด) จะต้องไม่มี movement ถูกสร้างค้าง
- ไม่กระทบ flow อื่นที่ใช้ stock_card / movement อยู่เดิม (เช่น GRN แบบอื่น, ISSUE, ADJUST ถ้ามี)
- Performance ของการบันทึก GRN ยังอยู่ในระดับที่ยอมรับได้ (ไม่หน่วงจนผิดสังเกต)

## 8. Documentation

เมื่อ Implement เสร็จ ให้สร้างไฟล์:
- `docs/dag/tasks/task13.17_results.md`

โดยสรุป:
- ตาราง movement ที่ใช้จริง + columns ที่ mapping
- โค้ดส่วนที่เพิ่มใน `leather_grn.php` (อธิบายเป็นคำอธิบาย/outline ไม่ต้อง paste โค้ดยาวทั้งไฟล์)
- Behavior จริงที่พบ (เช่น กรณี double submit)
- ปัญหา/ข้อจำกัดที่เจอ (ถ้ามี)

## 9. Completion Note

เมื่อ Task 13.17 เสร็จสมบูรณ์:
- Leather GRN จะไม่ใช่แค่การบันทึก lot/sheet ในเชิงกายภาพ แต่จะเชื่อมกับสมุดบัญชีสต็อกกลางอย่างแท้จริง
- ทำให้ฟีเจอร์ใน Phase ถัดไป (Leather Sheet Consumption, CUT Actual Panel Tracking, Wastage Dashboard) สามารถอ้างอิงยอดสต็อกที่ถูกต้องได้
- ถือเป็นการปิดปลายทางฝั่ง "รับเข้า" ของ Material Pipeline อย่างเป็นทางการ ก่อนจะเดินหน้าสู่ฝั่ง "การใช้" และ "การตามรอยการใช้" ต่อไป