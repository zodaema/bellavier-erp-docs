task13.8.md — Component Allocation & Leather Sheet Traceability (Phase 4.0)

Status: READY
Depends on: 13.3 – 13.7
Purpose: ทำให้ Component Serial เชื่อมโยงกับวัตถุดิบจริงที่ถูกใช้ในการผลิต เช่น หนังแต่ละแผ่น (Leather Sheets) → CUT Batch → Component Serial → Token

⸻

🎯 1. OBJECTIVE

ทำให้ Component Serial:
	•	รู้ว่ามาจากหนังแผ่นใด (leather sheet)
	•	รู้ว่าตัดในการตัดครั้งใด (cut batch)
	•	รู้ปริมาณ consumption (ใช้พื้นที่เท่าไรต่อ component)
	•	สามารถตรวจสอบได้ว่าเหลือหนังอีกเท่าไร
	•	ก่อนสร้าง MO สามารถตรวจสอบ availability ได้จริง

นี่คือหัวใจสำคัญของ
“Physical Traceability Layer” ของ Luxury ERP

⸻

🧩 2. SCOPE

✔ What we will implement
	1.	Leather Sheet Database
	2.	Leather Sheet Allocation to CUT Batch
	3.	Component Serial Allocation (serial → sheet + consumption)
	4.	Stock Deduction Rules
	5.	Component Availability Engine (pre-MO check)
	6.	APIs (read/write)
	7.	DAG CUT → Allocation Hook
	8.	Admin UI for Leather Sheet & Consumption
	9.	Supervisor override for allocation discrepancies
	10.	Integration with existing Component Completeness Engine

❌ Out of scope (for task13.9+)
	•	AUTO scrap classification
	•	AI-based leather sheet optimization
	•	CV-based “pattern placement” (Phase 7)

⸻

🗄️ 3. DATABASE CHANGES

Create new migration file:
database/tenant_migrations/2025_12_component_allocation_layer.php

3.1 leather_sheet

เก็บข้อมูลหนังจริงที่เข้าคลัง

field	type	desc
id_sheet	PK	auto
sku_material	varchar(64)	อ้างอิงวัสดุ
batch_code	varchar(64)	lot no
sheet_code	varchar(64)	label แผ่นหนัง
area_sqft	decimal(10,2)	พื้นที่รวม
area_remaining_sqft	decimal(10,2)	คงเหลือ
created_at	datetime	


⸻

3.2 cut_batch

เชื่อมกับ DAG CUT Behavior

| field | type |
| id_cut_batch | PK |
| token_id | FK (ref token) |
| sheet_id | FK (ref leather_sheet) |
| total_components | int |
| created_at | datetime |

⸻

3.3 component_serial_allocation

ลิงก์ component_serial → sheet + cut batch + consumption

field	type	desc
id_alloc	PK	
serial_id	FK -> component_serial	
sheet_id	FK -> leather_sheet	
cut_batch_id	FK -> cut_batch	
area_used_sqft	decimal(10,2)	ใช้พื้นที่ประมาณ
created_at	datetime	


⸻

🧠 4. SERVICES TO IMPLEMENT

สร้างใหม่ใน
source/BGERP/Component/ComponentAllocationService.php

Methods:

4.1 allocateSerialsToSheet($sheetId, $serialIds, $areaPerComponent)
	•	สร้าง record ใน component_serial_allocation
	•	ลด area_remaining_sqft
	•	Transaction-safe
	•	Validate:
	•	sheet exists
	•	area_remaining_sqft >= areaPerComponent * count(serials)

4.2 createCutBatch($tokenId, $sheetId, $totalComponents)
	•	สร้าง cut_batch record

4.3 linkSerialsToCutBatch($cutBatchId, $serialIds)
	•	Update allocation rows with batch reference

4.4 getAvailableSheetsForMaterial($materialSku)
	•	Return list for UI dropdown

4.5 predictMaterialAvailabilityForMO($productId, $qty)
	•	ใช้ BOM component requirements
	•	ใช้ average consumption
	•	คำนวณ sheet availability แบบ real-time
	•	Return:

{
  "ok": true,
  "material": "GOAT-BLACK",
  "needed_sqft": 78.2,
  "remaining_sqft": 96.5,
  "sufficient": true
}



⸻

🔌 5. API ENDPOINTS

สร้างใหม่
source/component_allocation.php

5.1 list_sheets
	•	สำหรับ UI เลือก sheet
	•	Filter by material

5.2 create_sheet
	•	เพิ่มแผ่นหนังใหม่เข้าคลัง

5.3 allocate_serials
	•	Allocate serials → sheet

5.4 predict_mo_material
	•	เช็ค availability ก่อนสร้าง MO

5.5 create_cut_batch
	•	ถูกเรียกจาก BehaviorExecutionService (CUT)

⸻

🔧 6. DAG BEHAVIOR INTEGRATION

ใน
source/BGERP/Dag/BehaviorExecutionService.php

ที่ handleCutComplete()

เพิ่ม:
	1.	Ask sheet_id (ผ่าน UI ใน task13.9)
	2.	Create cut_batch
	3.	Allocate component_serials
	4.	Update component_serial_allocation
	5.	Reduce leather_sheet.area_remaining

⸻

🖥️ 7. UI REQUIREMENTS

(สร้างใน Task 13.9 — ที่นี่แค่เตรียม spec)

7.1 Leather Sheet Admin

Page: /leather_sheets
	•	Create sheet
	•	Edit area_remaining
	•	Table listing sheets

7.2 Sheet Selector for CUT
	•	ใน Behavior UI (CUT)
	•	Dropdown “เลือกแผ่นหนังที่ใช้ในการตัด”
	•	Required ก่อนกด CUT Complete

7.3 Supervisor Allocation Fix

Page: /component_allocation_supervisor
	•	แสดง allocation ผิดปกติ
	•	Allow fix/update sheet linkage
	•	Audit logging

⸻

✔ 8. ACCEPTANCE CRITERIA

MUST:
	•	Component serial ต้องรู้ว่ามาจาก sheet ใด
	•	ทุกครั้งที่ allocate ต้องลด area_remaining
	•	CUT must create cut_batch และ allocate serials
	•	predict_mo_material ต้องแม่นยำ
	•	No breaking changes, backward compatible
	•	Transaction-safe ทุกจุด

NICE TO HAVE:
	•	Override UI warning เมื่อ sheet เหลือน้อยมาก
	•	Background rebalancer task (task13.10)

⸻

🧪 9. TEST CASES

A) Leather sheet create
	•	Create sheet → area_remaining = area

B) Allocate serials
	•	Sheet area_remaining ลดลงถูกต้อง
	•	Prevent over-allocation

C) CUT complete
	•	cut_batch created
	•	serial allocation created
	•	sheet area reduced

D) predict MO material
	•	Return false เมื่อ sheet ไม่พอ
	•	Return true เมื่อพอ

⸻

🚀 10. IMPLEMENTATION ORDER FOR AGENT

Phase 1 — DB layer
	1.	Create migration
	2.	Add 3 tables above
	3.	Idempotent migration

Phase 2 — Service layer
	1.	Create ComponentAllocationService
	2.	Implement 4 core methods
	3.	Write helper methods

Phase 3 — API layer
	1.	Create component_allocation.php
	2.	Add the 5 actions
	3.	Add permission checks
	4.	Add error handling

Phase 4 — DAG integration
	1.	Update BehaviorExecutionService (CUT)
	2.	Auto-create cut_batch
	3.	Auto-allocate serials

Phase 5 — Testing
	•	Manual + sample payloads

⸻

🔚 END OF TASK 13.8