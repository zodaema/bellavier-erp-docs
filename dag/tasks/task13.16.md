Task 13.16 — Leather GRN → Material Master Auto-Create → Leather Sheet Insert Fix

Status: Ready
Owner: BGERP Engineering
Module: Leather GRN / Material Master / Leather Sheet Pipeline
Depends On: Task 13.15 (Material Pipeline Schema Blueprint)
Priority: High
Type: API Stability / Data Model Sync
Sprint: DAG S13

⸻

1. Background / Problem Statement

ขณะรันระบบ GRN (Leather Goods Receiving Note) ระบบจะ:
	•	ดึง SKU จาก `stock_item` ตามที่ผู้ใช้เลือกในหน้า leather_grn
	•	สร้างข้อมูลลงใน `material_stock_in`
	•	และพยายามสร้าง `leather_sheet` ที่อ้างอิง FK ไปที่ `material.sku`

แต่เกิด error ดังนี้:

Cannot add or update a child row:
a foreign key constraint fails (`leather_sheet`,
CONSTRAINT `fk_leather_sheet_material`
FOREIGN KEY (`sku_material`) REFERENCES `material`(`sku`)

สาเหตุหลัก:
GRN ใช้ SKU ที่มีอยู่ใน `stock_item` แล้ว แต่ยังไม่มี row เดียวกันใน `material.sku` ทำให้การ INSERT `leather_sheet.sku_material` ซึ่งผูก FK ไปที่ `material.sku` ล้มเหลวทันที

นี่เป็นปัญหาสำคัญเพราะ:
	•	ทำให้ GRN flow ไม่สมบูรณ์
	•	leather_sheet ไม่ถูกสร้าง → CUT pipeline (Task 13.x) ทำงานไม่ได้
	•	ข้อมูล master ไม่สอดคล้อง (inconsistent state)
	•	เกิด 500 error ทุกครั้ง

⸻

2. Objective

สร้างระบบ Material Master Auto-Create ที่เป็นส่วนหนึ่งของ GRN pipeline:

เมื่อเกิด GRN:
	1.	ตรวจสอบว่า sku_material อยู่ใน material หรือไม่
	2.	ถ้า ไม่มี → ระบบต้อง สร้าง material master อัตโนมัติ พร้อมค่าเริ่มต้น
	2.1	การสร้าง material master จะดึงข้อมูลเบื้องต้นจาก `stock_item` (เช่น sku, description, material_type) มาเป็นค่าเริ่มต้น
	3.	จากนั้นจึง INSERT ลง leather_sheet ได้โดยไม่ล้ม
	4.	ทำให้ GRN → Leather Sheet → CUT pipeline ทำงานครบทุกขั้น

⸻

3. Why Auto-Create is Required

เพราะ:
	•	Raw material SKU ถูกสร้างขึ้นครั้งแรกตอน GRN (ตาม business reality)
	•	ไม่ใช่ทุกโรงงาน/ฝ่ายเอกสารจะกรอก master ก่อนสร้าง GRN
	•	Flow ของ BGERP ออกแบบให้ GRN เป็นจุดแรกของ material intake
	•	ERP ระดับ enterprise เช่น SAP MM, Oracle SCM ก็ใช้วิธีเดียวกันใน early-stage businesses

ดังนั้น auto-create เป็น design ที่ถูกต้อง สำหรับ phase นี้ และไม่มีผลเสียด้านข้อมูล

⸻

4. Functional Specification

4.1 Flow Diagram

[GRN Input]
     ↓
Check sku_material exists in material?
     ↓
[YES] → Continue GRN normally → Create leather_sheet
     ↓
[NO] → Auto-Create material master → Continue GRN


⸻

5. Technical Specification

5.1 Required Changes

A. leather_grn.php  
ปัจจุบันหน้า leather_grn เลือก SKU จาก `stock_item.sku` และใช้ค่านั้นไปสร้าง GRN และ leather_sheet ต่อไป  
ก่อนจะเริ่ม transaction และสร้าง leather_sheet ต้องเพิ่มขั้นตอน **ensure material exists for this SKU** ดังนี้:
	•	ตรวจสอบ existence ในตาราง `material` จาก SKU ที่ได้มาจาก `stock_item`:

```php
$check = $tenantDb->prepare("
    SELECT sku
    FROM material
    WHERE sku = ?
    LIMIT 1
");
$check->bind_param('s', $materialSku);
$check->execute();
$materialRow = $check->get_result()->fetch_assoc();
$check->close();
```

	•	Auto-create ถ้าไม่พบ:

```php
if (!$materialRow) {
    $stmt = $tenantDb->prepare("
        INSERT INTO material (
            sku,
            name,
            material_type,
            is_active,
            created_at
        ) VALUES (?, ?, ?, 1, NOW())
    ");

    // ชื่อและ material_type อาจดึงจาก stock_item ถ้ามี ไม่เช่นนั้น fallback เป็นค่าเริ่มต้น
    $materialName = $stockItemRow['description'] ?? $materialSku;
    $materialType = $stockItemRow['material_type'] ?? 'leather';

    $stmt->bind_param('sss', $materialSku, $materialName, $materialType);
    $stmt->execute();
    $stmt->close();
}
```

B. leather_sheet insert logic
ไม่ต้องแก้ schema
เพียงแค่มั่นใจว่า insert ถูกต้องหลัง material ถูกสร้าง

⸻

6. Data Model Impact Analysis

Table	Impact
material	New records auto-generated
leather_sheet	Insert no longer fails
material_stock_in	No impact
bom / CUT pipeline	Now fully compatible


⸻

7. Validation Rules
	1.	SKU ห้ามเป็นค่าว่าง ('')
	2.	SKU ต้องเป็น string แต่ไม่จำเป็นต้องมีใน master มาก่อน
	3.	Auto-create จะถูกทำเฉพาะเมื่อใช้ SKU จาก `stock_item` แล้วไม่พบ row เดียวกันใน `material.sku` (ก่อนเริ่มสร้าง leather_sheet)
	4.	ทุกการสร้าง material master ต้องอยู่ใน GRN transaction (atomic)

⸻

8. API Response Impact

Before fix →

500 error with foreign key failure

After fix →

ในกรณีข้อมูลถูกต้องและไม่มีปัญหาอื่น ระบบจะตอบกลับตัวอย่างเช่น:

```json
{
  "ok": true,
  "message": "GRN saved and leather sheets created"
}
```

โดยเฉพาะอย่างยิ่ง จะไม่เกิด 500 error จาก FK `leather_sheet.sku_material → material.sku` อีกต่อไป

⸻

9. Unit Test Cases

TC-13.16-01

Given: GRN สร้างใหม่ด้วย SKU ที่ไม่เคยมี
Expect: material master ถูก auto-create

TC-13.16-02

Given: SKU มีอยู่แล้ว
Expect: ไม่สร้างซ้ำ

TC-13.16-03

Given: GRN 1 อันมีหลาย leather_sheet
Expect: material create 1 ครั้งเท่านั้น

TC-13.16-04

Given: MySQL strict mode
Expect: ไม่มี 500 error

⸻

10. Acceptance Criteria
	•	GRN flow ทำงานครบ ไม่มี error
	•	leather_sheet ถูกสร้างทุกครั้ง
	•	ไม่มี FK failure อีกต่อไป
	•	CUT pipeline สามารถดึงข้อมูลได้
	•	material master ถูกเติมเต็มโดยอัตโนมัติ
	•	รันซ้ำกี่ครั้งก็ไม่สร้าง material ซ้ำ (idempotent)

⸻

11. Developer Checklist

Required:
	•	เพิ่ม material auto-create block ใน leather_grn.php
	•	ยืนยัน INSERT leather_sheet ใช้ค่า SKU ที่ตรงกับ material master
	•	เพิ่ม logging เล็กน้อย (SKU, material_create or exists)
	•	Test ด้วย SKU ใหม่
	•	Test ด้วย SKU ที่มีใน master

Optional:
	•	เพิ่ม MaterialResolver::ensureMaterial() helper (future)

⸻

12. Completion Note

การแก้ Task 13.16 จะปิดปัญหาที่ค้างคาของ GRN และทำให้ระบบพร้อมเข้าสู่ขั้นตอน:
	•	Task 13.17 — Leather Sheet Consumption
	•	Task 13.18 — CUT Actual Panel Tracking
	•	Task 13.19 — Wastage Dashboard

⸻