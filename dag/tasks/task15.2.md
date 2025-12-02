# Task 15.2 — System Seed Decoupling (Phase 2.1: Add *_code Columns Only)

**Goal:**  
เพิ่มคอลัมน์ `*_code` ในทุกตารางที่อิง `work_center` และ `unit_of_measure` ตาม Impact Map ของ Task 15.1  
โดย **ยังไม่แตะ API / JS / ลบคอลัมน์เดิมใด ๆ ทั้งสิ้น** เพื่อให้เป็น phase ที่ปลอดภัย 100%

---

## Scope

### 1. ตารางฝั่ง Work Center

เพิ่มคอลัมน์ (nullable, indexed) ตามนี้:

- `routing_node`
  - เพิ่ม `work_center_code` VARCHAR(50) NULL
- `job_task`
  - เพิ่ม `work_center_code` VARCHAR(50) NULL
- `job_ticket`
  - เพิ่ม `work_center_code` VARCHAR(50) NULL (future use)
- `work_center_team_map`
  - เพิ่ม `work_center_code` VARCHAR(50) NULL
- `work_center_behavior_map`
  - เพิ่ม `work_center_code` VARCHAR(50) NULL
- (ถ้ามี `routing_step` ยังใช้งานอยู่) เพิ่ม `work_center_code` เช่นกัน แต่ mark เป็น legacy

### 2. ตารางฝั่ง Unit of Measure (UOM)

เพิ่มคอลัมน์ (nullable, indexed) ตามนี้:

- `product`
  - เพิ่ม `default_uom_code` VARCHAR(30) NULL
- `bom_line`
  - เพิ่ม `uom_code` VARCHAR(30) NULL
- `material`
  - เพิ่ม `default_uom_code` VARCHAR(30) NULL
- `material_lot`
  - เพิ่ม `uom_code` VARCHAR(30) NULL
- `stock_item`
  - เพิ่ม `uom_code` VARCHAR(30) NULL
- `stock_ledger`
  - เพิ่ม `uom_code` VARCHAR(30) NULL
- `purchase_rfq_item`
  - เพิ่ม `uom_code` VARCHAR(30) NULL
- `mo`
  - เพิ่ม `uom_code` VARCHAR(30) NULL

> หมายเหตุ: ทุกคอลัมน์ใหม่ให้เป็น **NULL ได้**, ยังไม่ต้องใส่ค่า และต้องมี INDEX แยกให้เรียบร้อย

---

## Out of Scope (ห้ามทำใน Task 15.2)

- ❌ ห้ามลบ / แก้ไข / rename คอลัมน์ `id_work_center`, `id_uom`, หรือ FK ที่อิงอยู่
- ❌ ห้ามแก้ไฟล์ PHP / API ใด ๆ (read/write)
- ❌ ห้ามแก้ไฟล์ JavaScript
- ❌ ห้ามเพิ่ม logic mapping หรือ backfill ใด ๆ (ทำใน Task 15.3)
- ❌ ห้ามเปลี่ยน behavior ของ production flow, routing, MO, BOM, GRN

---

## Implementation Detail

1. สร้าง tenant migration ใหม่:
   - ไฟล์: `database/tenant_migrations/2025_12_wc_uom_add_code_columns.php`
2. ใช้ pattern:
   ```php
   // ตัวอย่างสำหรับเพิ่มคอลัมน์ถ้ายังไม่มี
   $db->query("
     ALTER TABLE routing_node
     ADD COLUMN IF NOT EXISTS work_center_code VARCHAR(50) NULL AFTER id_work_center
   ");

หรือถ้า IF NOT EXISTS ใช้ไม่ได้ใน MySQL version นี้:
	•	เช็คใน PHP ก่อนด้วย SHOW COLUMNS LIKE 'work_center_code' แล้วค่อย ALTER

	3.	เพิ่ม INDEX ให้ทุก *_code column:

CREATE INDEX idx_routing_node_wc_code ON routing_node(work_center_code);



⸻

Acceptance Criteria
	•	✅ Migration รันผ่านบนทุก tenant (dev/staging/prod) โดยไม่ error
	•	✅ ทุกตารางใน Impact Map มีคอลัมน์ *_code ตาม spec
	•	✅ ไม่มีการแก้ไขหรือทำลายข้อมูลเดิมในคอลัมน์ ID
	•	✅ ไม่มี PHP / JS ไฟล์ใดถูกแก้ใน Task 15.2
	•	✅ ระบบทำงานได้เหมือนเดิม 100% หลังรัน migration

⸻

Next Tasks (หลัง 15.2)
	•	Task 15.3 — Backfill & Sync Codes
	•	เติมค่า *_code จากตาราง work_center และ unit_of_measure
	•	Task 15.4 — API/JS Dual-Mode
	•	ให้ API/JS รองรับ code เป็นหลัก, id เป็น fallback
	•	Task 15.5 — Remove ID Dependencies (Destructive)
	•	พิจารณาการถอด ID ออกจาก FK / payload เมื่อทุกอย่างนิ่งแล้ว
