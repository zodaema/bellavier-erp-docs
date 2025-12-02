# Task 26.7 — Product Dual Delete Mode (Hard Delete + Archive)

## 🎯 Objective
เพิ่มระบบ “Dual Delete Mode” สำหรับ Product เพื่อให้การจัดการข้อมูลเป็นไปตามมาตรฐาน ERP ระดับ Enterprise โดยป้องกันข้อมูลสำคัญหาย และยังคงรองรับกรณีสร้างผิด/ทดสอบที่ต้องลบจริงได้

### ระบบต้องรองรับ 2 โหมด:
1. **Hard Delete (ลบจริง)** — ทำได้เฉพาะ Product ที่ *ไม่เคยถูกใช้งานเลย*
2. **Archive (Soft Delete)** — ใช้เมื่อ Product เคยถูกใช้งานแล้วแม้เพียงครั้งเดียว

---

## ✅ Functional Requirements

### ### 1. Hard Delete (FORCE DELETE)
ทำได้ก็ต่อเมื่อ Product มี dependency = 0  
ต้องตรวจสอบผ่าน `ProductDependencyScanner`:

ตรวจสอบว่าไม่มี:
- MO ที่อ้างถึง product_id
- Job Ticket ที่อ้างถึง
- Hatthasilpa Jobs ที่อ้างถึง
- Inventory movement หรือ stock card
- WIP Logs
- Routing binding
- Product stats / output logs
- ETA caches
- Serial generation logs
- Media assets ที่ linked อยู่

ถ้า **พบ dependency > 0 → BLOCK ทันที**

### Response format:
```json
{
  "ok": false,
  "error_code": "DEPENDENCY_FOUND",
  "error": "This product cannot be deleted because it has dependent records.",
  "dependencies": {
    "mo_count": 5,
    "job_ticket_count": 2,
    "inventory_count": 12
  }
}
```

### 2. Soft Delete / Archive

เมื่อ product เคยถูกใช้งานแล้ว (พบ dependency > 0) ระบบต้องไม่อนุญาต Hard Delete แต่ให้ใช้ Archive แทน

```
is_active = 0
is_archived = 1
```

UI behavior:
- ซ่อนรายการ Archived โดย default
- ปุ่ม "Restore" จะทำงานเฉพาะที่ is_archived = 1
- ปุ่ม Hard Delete ถูกซ่อนสำหรับสินค้าที่เป็น Classic และมี dependency (ไม่ควรให้ลบ Classic ที่เคยขาย/ผลิตแล้วหรือมีประวัติการผลิต)

⸻

🚨 Guardrails / Safety Requirements

1. ห้ามลบโดยไม่ผ่าน Dependency Scanner

ทุกจุดที่มีการ delete ต้องใช้:

ProductDependencyScanner::canHardDelete($productId)
ProductDependencyScanner::getDependencies($productId)

2. ห้ามลบแม้ว่าจะถูก Inactive แล้ว

Inactive และ Archived ≠ Safe to delete
Hard delete ต้องผ่าน scanner เท่านั้น

3. ต้องมี Audit Log

ทุกการลบ/Archive ต้องเขียนลง:

system_audit_log

4. UI ต้อง Confirm แบบ 2-step

Hard Delete ต้องใช้ popup ยืนยัน:

"This action cannot be undone. This product will be permanently deleted if no dependencies are found."

5. Default คือ Archive ไม่ใช่ Delete

ปุ่ม Delete ควรไปเปิด modal แบบนี้:

What do you want to do?
( ) Archive product (recommended)
( ) Attempt permanent delete (only possible if unused)

6. ต้องทำตาม AI Coding Policy กลาง
    - Message / error ทั้งหมดต้องผ่าน i18n helper ตามที่กำหนดใน `docs/policy/AI_Coding_Standards.md` และ `docs/policy/Global_Helpers.md`
    - API ต้องใช้รูปแบบ response เดียวกับ API อื่นในระบบ (มี `ok`, `error_code`, `error`, `meta`)
    - Guardrail เพิ่มเติม: อนุญาตเฉพาะ role admin หรือ product_manager เท่านั้นในการเรียก hard delete

⸻

🛠 Required Code Changes

Backend
	•	Add DELETE endpoints:
	•	product_api.php?action=delete_hard
	•	product_api.php?action=archive
	•	product_api.php?action=restore
	•	Update ProductMetadataResolver
	•	เพิ่ม state: is_archived, can_hard_delete
	•	ProductDependencyScanner
	•	เพิ่มสรุป dependency แยกตาม module

### Schema Notes
- เพิ่ม column ใหม่ `is_archived TINYINT(1) NOT NULL DEFAULT 0` ในตาราง `product` (ถ้ายังไม่มี)
- ห้ามใช้ `is_deleted` column เพิ่มเติมใน phase นี้ (ใช้ `is_active` + `is_archived` ตามที่ spec ไว้)
- ProductMetadataResolver ต้องรวม state object: `is_draft`, `is_active`, `is_archived`, `can_archive`, `can_hard_delete`, `has_dependencies`

Frontend
	•	เพิ่มปุ่ม “Archive”
	•	เพิ่มปุ่ม dropdown “More…”
	•	Hard Delete → เฉพาะ products ที่ dependency = 0 เท่านั้น
	•	แสดง badge:
	•	Archived
	•	Inactive

⸻

🧪 Testing Matrix

Case	State	Dependency	Expected
1	Active	0	Hard Delete allowed
2	Active	>0	Hard Delete blocked → Archive only
3	Archived	0	Hard Delete allowed
4	Archived	>0	Hard Delete blocked
5	Inactive	irrelevant	Hard Delete still requires scanner
6	Draft	0	Hard Delete allowed
7	Draft	>0	Hard Delete blocked


⸻

## Cross‑Module Invariants
- Product ที่ `is_archived = 1` หรือ `is_active = 0` ต้องไม่สามารถถูกเลือกใช้ใน: MO, Hatthasilpa Jobs, Job Tickets, Inventory, Serial, Routing Binding
- Product ที่ถูก hard delete ต้องไม่เหลือ reference ใด ๆ ในตารางอื่น (ให้ ProductDependencyScanner ใช้เป็น checklist กลาง)

⸻

📘 Deliverables
	1.	Backend implementation (API + Services)
	2.	Updated UI on product list & product modal
	3.	Updated ProductMetadataResolver
	4.	DependencyScanner enhancements
	5.	Full documentation in:
	•	task26.7_results.md
	•	task_index.md

---

**Last Updated:** 2025-12-01  
**Results:** See [task26_7_results.md](../results/task26_7_results.md)

⸻

🚀 After this task

ระบบ Product Master จะพร้อมเข้าสู่:
	•	Task 26.8 — Product Module Enterprise Standards Compliance ✅
	•	Task 26.9 — Product Module Additional Features
	•	Task 27 — Node Behavior Engine
	•	Task 28 — Work Queue Integration

⸻