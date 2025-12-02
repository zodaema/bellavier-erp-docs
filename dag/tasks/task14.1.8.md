✅ Task 14.1.8 — Dual-Write Removal (Phase A – Material Lot Stabilization)

🎯 เป้าหมายของ Task

ยกเลิก dual-write patterns ในระบบ Material & Leather GRN เพื่อให้ฐานข้อมูลและโค้ดเหลือเพียง source of truth เดียว (id_material) และปูทางไปสู่การลบ legacy columns เช่น id_stock_item ใน Task 14.2

⸻

📌 เหตุผลที่ต้องทำ Task 14.1.8 ก่อน

จาก Task 14.1.7 (Migration Framework) และ 14.1.1–14.1.6 (Stock/BOM cleanup):
	•	material_lot ยังเขียน ทั้ง id_material และ id_stock_item
	•	leather_grn.php ยังทำ dual-insert
	•	materials.php ยังคง READ fallback logic (V1 → V2)
	•	stock_item table ยังต้องอยู่เพราะ dual-write ยังใช้งาน
	•	Locked migration material_lot_id_material.php ถูก block ไว้เพราะ dual-write ยังไม่ถูกถอด

ถ้าไม่ลบ dual-write → Task 14.2 (Master Schema V2 cleanup) จะทำไม่ได้

ดังนั้น Task 14.1.8 = ขั้นตอนที่ “จำเป็นที่สุด” ก่อนจะไปทำ Phase B

⸻

✅ ขอบเขตงานใน Task 14.1.8

A. File Focus (เฉพาะ 2 ไฟล์นี้เท่านั้นใน Phase A)

1. source/leather_grn.php

ต้องแก้:
	•	ลบการ insert ลง id_stock_item
	•	บังคับใช้ id_material เท่านั้น
	•	เอา fallback logic ออกทั้งหมด
	•	Update JOIN/SELECT ให้ใช้ material

2. source/materials.php

ต้องแก้:
	•	READ: เอา fallback id_stock_item ออก
	•	LIST: ใช้ material table เป็นหลัก
	•	CREATE/UPDATE: เขียนเฉพาะ id_material

⸻

B. Database Behavior ที่ต้องปรับ
	•	material_lot.id_stock_item จะยังคงอยู่ แต่ไม่ใช้งานแล้ว
	•	หลัง Task 14.1.8 → สามารถย้าย locked migration:
	•	legacy_stock/2025_12_material_lot_id_material.php
→ ไปไว้ใน active/ ได้ทันที

⸻

C. Safeguards / Rules
	•	❌ ห้ามลบ id_stock_item column ใน Task นี้
	•	❌ ห้ามลบ stock_item table
	•	❌ ห้ามแก้ behavior pipeline หรือ super_dag
	•	❌ ห้ามแก้ transaction structure ของ GRN
	•	✔️ ต้องแก้เฉพาะจุด dual-write เท่านั้น
	•	✔️ ต้องรักษา backward compatibility ของ API response
	•	✔️ ต้องไม่กระทบ stock pipeline ที่ยังใช้ material_lot

⸻

🧩 รายละเอียดงานที่ต้องให้ AI Agent ทำ

### 1. leather_grn.php — Remove dual-write
	•	ค้นหาโค้ดที่เขียนลง id_stock_item
	•	ลบ INSERT/UPDATE fields ที่เกี่ยวกับมัน
	•	Remove fallback GETs

Example pattern to remove:

'id_stock_item' => $materialId

Replace with strict:

'id_material' => $materialId


⸻

2. materials.php — Remove fallback & dual-write
	•	ลบทุก logic ประเภท:

IFNULL(material.id_material, stock_item.id_stock_item) ...

	•	ลบ JOIN กับ stock_item
	•	ลบการเขียนลง id_stock_item

⸻

3. Update SELECT logic ให้ใช้ V2 table อย่างเดียว

From:

LEFT JOIN stock_item si ON si.id_stock_item = ml.id_stock_item

To:

JOIN material m ON m.id_material = ml.id_material


⸻

4. แก้ logic ของ MaterialResolver (ถ้ามี fallback อยู่)
	•	Remove fallback resolution
	•	MaterialResolver ต้อง return material เท่านั้น

⸻

5. Document และสร้างไฟล์
	•	docs/dag/tasks/task14.1.8_results.md
	•	อัปเดต task_index.md

⸻

📝 Expected Outputs
	1.	โค้ดใน leather_grn.php ถูกทำให้เป็น single-source-of-truth (id_material)
	2.	materials.php ไม่มี dual-write/fallback อีกต่อไป
	3.	ไม่มี INSERT/UPDATE ไปยัง id_stock_item
	4.	ไม่มี SELECT fallback ไปยัง stock_item
	5.	Migration 2025_12_material_lot_id_material.php สามารถย้ายจาก /locked/ → /active/ ได้
	6.	ระบบยังคง backward compatible
	7.	super_dag และ component pipeline ไม่ได้รับผลกระทบ

⸻

🔥 หลังจบ Task 14.1.8

คุณจะมีสิทธิ์ทำ Task 14.2 (Final Cleanup) โดย:

✔️ Allowed
	•	drop id_stock_item columns
	•	drop stock_item table
	•	drop id_stock_item reference ใน material_lot

❌ Not Allowed ก่อน 14.1.8

ทำไม่ได้จนกว่า dual-write จะถูกลบออก
