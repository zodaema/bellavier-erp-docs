Task 26.4 — Product List Cleanup & Draft/Publish UX Redesign

Phase: Product Module Phase 2
Objective: Reduce UI clutter, remove redundant statuses, enforce one-way Publish flow, and modernize product list table.

⸻

✅ 1. Problems to Fix

จากการตรวจสอบระบบ Product ปัจจุบัน พบปัญหาดังนี้:

1.1 Status ซ้ำซ้อน
	•	มี badge “Draft/Published” ใกล้ SKU แล้ว
	•	แต่ยังมี column “Status” ซ้ำอีก 1 ช่อง → ทำให้ UI รก

1.2 ปุ่ม Action เยอะเกิน
	•	ปุ่ม Publish / Unpublish / Draft / Delete / Bind Graph / Duplicate
	•	ทำให้ผู้ใช้สับสน และวางตำแหน่งยาก

1.3 Publish Flow ไม่มีความหมาย
	•	ตอนนี้ revert Draft ทำได้ใน list view → ทำให้ product ที่ถูกใช้งาน production ไปแล้วอาจ revert ผิดได้

1.4 Product Table ไม่มี Active / Inactive toggle
	•	ไม่มีวิธีปิดการใช้งาน product โดยไม่ลบ
	•	เป็นฟีเจอร์จำเป็นของธุรกิจ (สินค้าเลิกผลิต, เลิกขาย, inactive version)

⸻

🎯 2. Task Goals

2.1 ลด Status ให้เหลือ badge เดียว
	•	ลบ column “Status” จาก Datatable
	•	ใช้ badge ตรง SKU เท่านั้น

2.2 ปรับ Publish เป็น One-Way
	•	Draft → Publish ได้
	•	Published → Draft ไม่ได้ (ยกเลิกการ revert)
	•	หากต้องสร้างเวอร์ชันใหม่ ให้ใช้ Duplicate → สร้าง draft copy

2.3 ย้ายปุ่ม Publish ไปไว้ใน Edit Modal
	•	ไม่แสดงปุ่ม Publish ใน row action แล้ว
	•	ลดปุ่มรกใน list view
	•	ใน modal แสดงปุ่ม:
	•	Publish Product (เฉพาะ is_draft=1)

2.4 Remove: Unpublish / Mark as Draft
	•	ทั้ง backend endpoint + frontend button

2.5 เตรียมพื้นที่สำหรับ Active / Inactive toggle
	•	ยังไม่สร้าง column หรือ API
	•	แต่ให้ปรับ UI structure รองรับในอนาคต (ถัดไป Task 26.5)

⸻

🧩 3. Expected UI After Task 26.4

Product List Table
	•	Column ที่เหลือ:
	•	Thumbnail
	•	Code
	•	SKU + Badge Draft/Published
	•	Name
	•	Category
	•	Production Line
	•	Production Flow
	•	Actions (Thumbnail, Graph, Duplicate, Edit, Delete)

Badges
	•	Draft = yellow
	•	Published = green
	•	No Status column anymore

Actions
	•	Publish button หายจาก list (ไปโผล่เฉพาะใน modal)
	•	Duplicate remains
	•	Delete remains
	•	Preview, Edit, Graph binding remain

Edit Modal

เพิ่ม section:

Status
-------
[Publish Product]   (show only when is_draft = 1)

Note:
Published product can no longer revert to Draft.
Use Duplicate to create a new editable version.


⸻

📌 4. Technical Changes Required

4.1 Remove Status column in products.php
	•	Remove <th>Status</th>
	•	Remove <td>${row.status}</td> from JS datatable renderer
	•	Ensure product_stats/dashboard using status still works (they don’t use this)

⸻

4.2 Update JS — product_list.js
	•	Remove column definition for Status
	•	Remove logic for renderStatusBadge() IF duplicated
	•	Remove buttons:
	•	“Mark as Draft”
	•	“Unpublish”

⸻

4.3 Edit Modal Update
	•	Add Publish section
	•	Hide publish button if is_draft == 0

⸻

4.4 Backend cleanups

In product_api.php:
	•	Remove endpoint: unpublish_product
	•	Remove logic that sets is_draft back to 1
	•	Keep only:
	•	publish_product
	•	duplicate_product

Enforce rule:

If product.is_draft == 0:
  deny reverting to draft


⸻

✔️ 5. Acceptance Criteria

User Experience
	•	Product List ไม่มี column “Status”
	•	Draft/Published badge อยู่ที่ SKU เท่านั้น
	•	ปุ่ม Publish มีเฉพาะใน Edit Modal
	•	ไม่มีปุ่ม revert-to-draft ใน UI
	•	Duplicate workflow ใช้งานได้

Data Integrity
	•	Product published → ไม่สามารถ revert
	•	Duplicate product จะสร้าง is_draft=1 เสมอ

Code Quality
	•	UI ไม่เหลือ placeholder status
	•	API ไม่รับ revert-to-draft request อีก
	•	Translation, tooltip, safe-rendering ครบถ้วน

⸻

🚀 6. Cursor Prompt — RUN THIS IN CURSOR

ให้วางไปตรง ๆ ไม่ต้องแก้อะไร

You are Cursor AI Agent.
Execute the following task with strict adherence to Bellavier Group ERP’s developer policies:

## Task 26.4 — Product List Cleanup & Draft/Publish UX Redesign

### Requirements
1. Remove “Status” column from product list:
   - Delete column header
   - Delete datatable column renderer
   - Ensure badge near SKU remains the only status indicator

2. Remove all "Unpublish" or "Mark as Draft" actions:
   - Delete backend endpoint in product_api.php
   - Delete frontend buttons & JS handlers
   - Delete revert logic from products.php

3. Move Publish action into Edit Modal:
   - Add “Publish Product” button only when is_draft=1
   - Add Safety Notice: “Published products cannot revert to Draft. Use Duplicate to create a new version.”
   - Trigger existing publish_product API

4. Ensure duplicate workflow creates is_draft=1 products.

5. Clean up UI:
   - Reduce badge clutter
   - Harmonize button layout
   - Ensure i18n wrapper is used for all new labels

### Files to modify
- views/products.php
- assets/javascripts/products/product_list.js (or equivalent)
- assets/javascripts/products/product_graph_binding.js (ensure no collision)
- source/product_api.php
- source/products.php

### Additional requirements
- Follow developer policy in docs/developer/01-policy/*
- No inline Thai text; use translate() for all labels
- Follow safe HTML escaping conventions
- Comment code clearly in English

After modifications:
- Run full syntax check
- Show diff summary of all files
