

# Task 14.1.1 – Stock Pipeline Code Migration (Phase 1)

> **Scope type:** DAG / Inventory / Legacy Cleanup  
> **Parent task:** 14.1 – Legacy Stock/BOM/Routing Risk Reduction  
> **Status:** PLANNED

---

## 1. Objective

ย้ายการอ้างอิงจาก **legacy stock tables** (โดยเฉพาะ `stock_item` และญาติๆ) ไปใช้ **inventory model ปัจจุบัน** (เช่น `material`, `material_lot`, `warehouse_inventory`, ฯลฯ) อย่างปลอดภัย โดย **ไม่ทำให้ระบบพัง** และ **ไม่เปลี่ยนพฤติกรรมทางธุรกิจ** ที่ user เห็นในตอนนี้

Phase นี้เป็น **Code Migration เท่านั้น**:
- ยัง *ไม่* ลบตาราง legacy ออกจากฐานข้อมูล
- ยัง *ไม่* ปรับปรุง business rule เรื่อง stock จริง / scrap / safety stock
- เป้าหมายคือ: ลดความเสี่ยงจากการที่ legacy stock pipeline ยังถูกเรียกใช้อยู่ในโค้ด

---

## 2. In-scope / Out-of-scope

### In-scope

- ทุกจุดที่ **อ่าน/เขียน** stock ผ่านตาราง:
  - `stock_item`
  - `stock_item_asset`
  - `stock_item_lot`
- ทุกฟังก์ชัน / endpoint ที่ใช้ตารางเหล่านี้เพื่อ:
  - แสดงยอด stock
  - ตัด stock
  - จอง stock
  - แสดง movement history (ถ้ามี)
- เฉพาะ **tenant-side** code (ไม่แตะ platform core)

### Out-of-scope (Phase 1)

- การลบตาราง `stock_item*` ออกจาก DB จริง (จะทำใน phase ถัดไป)
- การเปลี่ยนยอด stock ทางธุรกิจ (เช่น วิธีคิด usable stock, scrap stock)
- การผูก stock เข้ากับ **Component Serial** / **Leather Sheet** (จะทำใน task 13.8+)
- การเปลี่ยน UI ใหญ่ ๆ (เป้าหมายคือให้ "หน้าตาเหมือนเดิม" แต่ใช้ data source ใหม่)

---

## 3. Files & Endpoints in Scope

> หมายเหตุ: รายการไฟล์ด้านล่างต้อง sync ให้ตรงกับ `task14.1_scan_results.md` และ `task14.1_stock_pipeline.md` ถ้ามี mismatch ให้ update เอกสารก่อน แล้วค่อยเริ่มลงมือแก้โค้ด

อย่างน้อยต้องพิจารณาไฟล์กลุ่มนี้ (ชื่อไฟล์อาจต่างเล็กน้อย ให้อิงจากผลสแกนจริง):

### 3.1 API / Endpoint ชั้น Stock

- `source/stock.php` (ถ้ามี)
- `source/inventory.php` หรือ endpoint ที่รับผิดชอบ movement
- `source/materials.php` (เฉพาะส่วนที่แสดง stock summary ถ้ายังผูกกับ `stock_item`)

### 3.2 Helper / Service

- `source/model/stock_helper.php` หรือไฟล์ที่ทำหน้าที่คล้ายกัน (ถ้ามี)
- โค้ดภายใต้ `BGERP/Inventory/*` ที่ยังเรียก `stock_item`

### 3.3 UI / DataTable Layer

- JS ที่เรียก endpoints เหล่านี้ (เช่น `materials.js`, `stock.js`)
- View ที่แสดงคอลัมน์ stock (เช่น `views/materials.php`)

> ☑️ ก่อนเริ่ม AI migration ต้องติ๊ก check list ใน `task14.1_stock_pipeline.md` ให้ครบว่า
> - ทุก reference ของ `stock_item*` ถูกระบุชัดเจนแล้ว
> - แยกประเภทการใช้งานได้: read-only vs write / adjust

---

## 4. Target Model (ปลายทางที่ควรใช้แทน)

ให้ AI Agent เดินตามแนวคิดนี้:

### 4.1 Stock ปัจจุบัน ให้คิดเป็น 3 ชั้น

1. **Master** – วัสดุพื้นฐาน
   - `material`

2. **Lot / GRN / Sheet** – แหล่งที่มาของ stock
   - `material_lot`
   - `leather_sheet` (สำหรับหนังเท่านั้น)

3. **On-hand / Warehouse-level** – ปริมาณที่มีในแต่ละคลัง
   - `warehouse_inventory`

### 4.2 การ map จาก legacy → target

- เดิม: `stock_item` = ภาพรวม stock ต่อ material/product แบบเป็นก้อน
- ใหม่: ควรคำนวณยอดจาก `warehouse_inventory` (รวมตาม dimension ที่ใช้จริงใน UI)

ตัวอย่าง pattern:

```sql
SELECT
    wi.id_material,
    SUM(wi.qty_on_hand) AS qty_on_hand
FROM warehouse_inventory wi
JOIN material m ON m.id_material = wi.id_material
WHERE ... (filters ตามเดิมใน code)
GROUP BY wi.id_material;
```

> ❗ ห้ามเปลี่ยน logic ฟิลเตอร์ (เช่น filter by warehouse, by production line) ถ้าไม่ได้เขียนไว้ชัดเจนใน task อื่น

---

## 5. Safety Rails สำหรับ AI Agent

ให้เขียนใน prompt (และยึดในโค้ดจริง) ว่า:

1. **ห้ามลบ field / column เดิมใน JSON output**
   - ถ้าเดิมมี field `stock_qty` ให้ยังคงมีเหมือนเดิม
   - เปลี่ยนเฉพาะ *วิธีการคำนวณ* เบื้องหลังเท่านั้น

2. **ห้ามเขียน logic ตัด stock ใหม่**
   - ถ้า endpoint ทำหน้าที่ read-only ให้คงเป็น read-only
   - ถ้า endpoint มีการ update stock จริง ๆ ให้ mark เป็น *OUT OF SCOPE* และไม่แตะ (จะย้ายใน phase 2)

3. **ห้ามแก้ business rule ที่ไม่รู้ที่มา**
   - ถ้าเจอ comment แปลก ๆ หรือ magic number (`* 1.05`, safety factor ฯลฯ) ให้ log ไว้ใน `task14.1_stock_pipeline.md` แทนการ refactor

4. **ห้าม introduce stock model ใหม่เอง**
   - ใช้เฉพาะ: `material`, `material_lot`, `warehouse_inventory`, `leather_sheet`
   - ห้ามสร้าง table หรือ enum ใหม่ใน task นี้

5. **Backward Compatible หรือไม่ทำเลย**
   - ถ้าไม่ได้มั่นใจ 100% ว่าคำนวณได้เท่ากับของเดิม → ให้ใส่ TODO และ rollback การเปลี่ยนแปลง

---

## 6. แผนการทำงาน (สำหรับ AI Agent)

ให้เขียน prompt นำทาง AI agent ตาม step นี้:

### Step 1 – Static Scan & Bookmark

1. เปิด `task14.1_stock_pipeline.md`
2. Cross-check รายการไฟล์ + ฟังก์ชันที่มี `stock_item*`
3. ในแต่ละไฟล์ ให้ comment ไว้บนสุดของไฟล์ว่า:
   - `// [Task14.1.1] in-scope: stock_item read-only migration`

### Step 2 – Identify Read-only vs Write

สำหรับ *แต่ละฟังก์ชัน* ที่เรียก `stock_item`:

1. ถ้ามีแต่ `SELECT` → mark เป็น **READ**
2. ถ้ามี `INSERT/UPDATE/DELETE` → mark เป็น **WRITE** และ **อย่าแก้โค้ด** ใน task นี้ (ใส่ comment ว่า `// WRITE – out of scope for 14.1.1`)

### Step 3 – Migrate READ Queries

1. สำหรับ query ที่เป็น READ:
   - เขียน query ใหม่ที่ใช้ `warehouse_inventory` (และ table ที่เกี่ยวข้อง)
   - พยายามให้ผลลัพธ์ได้ฟิลด์เหมือนเดิม (alias ให้ตรงชื่อเก่า)
2. รักษา behavior:
   - sorting เดิม
   - pagination เดิม
   - filter เดิม

### Step 4 – Adapter Layer (ถ้าจำเป็น)

ถ้า UI หรือ JS code อิง field จาก `stock_item` แบบแน่น (เช่น `row.stock_item_id`):

1. เพิ่ม adapter mapping ใน PHP ก่อน return JSON
2. หรือสร้าง helper function เช่น `mapWarehouseInventoryRowToLegacyStockItemShape()`

> จุดประสงค์คือ "ให้หน้าบ้านไม่รู้ว่าหลังบ้านเปลี่ยน data source แล้ว"

### Step 5 – Logging & TODOs

- ถ้าเจอ logic ที่ไม่แน่ใจ → อย่าเดา ให้:
  - ใส่ `// TODO[Task14.1.1]:` พร้อมคำอธิบายสั้น ๆ
  - เพิ่ม entry ใน `task14.1_stock_pipeline.md` section `Open Questions`

### Step 6 – Self-check

หลังแก้โค้ด ให้ AI agent รัน:

```bash
php -l source/<file>.php
vendor/bin/phpunit tests/Integration/SystemWide/EndpointSmokeSystemWideTest.php --filter=stock
```

หรือถ้าไม่มี test เฉพาะ ให้รันอย่างน้อย:

```bash
vendor/bin/phpunit tests/Integration/SystemWide/EndpointSmokeSystemWideTest.php
```

แล้วอัปเดตผลใน `task14.1.1_results.md` (ให้ agent สร้างไฟล์นี้เพิ่ม)

---

## 7. Definition of Done (DoD)

Task 14.1.1 จะถือว่า **สำเร็จ** เมื่อ:

1. ✅ ทุกฟังก์ชันที่ **READ** จาก `stock_item*` ถูกย้ายไปอ่านจาก `warehouse_inventory` (หรือ target modelที่ถูกต้อง) แล้ว
2. ✅ ไม่มีการแก้ไขฟังก์ชันที่ **WRITE** stock (ถูก mark เป็น out-of-scope ชัดเจน)
3. ✅ JSON output ของ endpoints ที่เกี่ยวข้อง **ไม่เปลี่ยน shape** (field เดิมยังอยู่ครบ)
4. ✅ ไม่มีการสร้าง table/enum ใหม่
5. ✅ Syntax check ผ่านสำหรับทุกไฟล์ที่แตะ
6. ✅ รัน SystemWide Endpoint Smoke Tests แล้ว **ไม่เพิ่ม error ใหม่** (ถ้ามี error เดิมอยู่แล้ว ให้บันทึกไว้ใน results)
7. ✅ อัปเดต `task14.1_stock_pipeline.md` และสร้าง `task14.1.1_results.md` พร้อมสรุป:
   - ไฟล์ที่แก้ไข
   - ฟังก์ชันที่ migrate สำเร็จ
   - ฟังก์ชันที่ mark out-of-scope
   - Known risks / open questions

---

## 8. Note ถึงตัวคุณในอนาคต / Dev คนอื่น

- Task 14.1.1 เป็น **base layer** ของงาน stock ทั้งหมดในอนาคต (รวมถึง Leather Sheet และ Component Serial Allocation)
- ถ้าทำส่วนนี้เรียบร้อย คุณจะสามารถ:
  - ลบ `stock_item*` ออกจาก code base ได้อย่างมั่นใจใน Phase 2
  - ขยาย logic stock ให้ฉลาดขึ้น (เช่น แยก usable / blocked / scrap) ใน task ถัด ๆ ไป
- ถ้าอ่านไฟล์นี้แล้วรู้สึกว่ามันเยอะเกินไป → ให้ทำทีละ endpoint และจด progress ใน `task14.1_stock_pipeline.md` แทนการพยายามจบทุกอย่างในรอบเดียว