📄 Task 13.4 — Component Serial System (Phase 2: Serial Generation)

Status: Ready for AI Agent
Category: Component System
Parent: Task Series 13.x
Depends on: Task 13.3 (Foundation Complete)

⸻

🎯 Goal

สร้างระบบ Component Serial Generation ที่สามารถ:
	•	สร้าง serial number ต่อชิ้น
	•	รองรับ batch generation (สร้างครั้งละหลายชิ้น)
	•	ลิงก์กับ component_master
	•	ให้ CUT Behavior ใช้เรียกสร้าง serial หลัง batch cutting
	•	พร้อมสำหรับ Phase 3 (Binding → Token / Node)

Task นี้เป็น backbone สำคัญ ของ component tracking ทั้งระบบ

⸻

📦 Scope

สิ่งที่ Task 13.4 จะทำ:

1. Database (3 ตารางใหม่)

1) component_serial_batch
ข้อมูล batch ที่เกิดจาก CUT หรือการรับเข้าคลัง

Fields:
	•	id_batch
	•	batch_code (e.g., CUT-20251201-0001)
	•	component_type_id
	•	component_master_id (optional)
	•	generated_by_user_id
	•	qty_generated
	•	notes
	•	timestamps

2) component_serial_pool
เก็บ running number ต่อวันต่อ component type
Equivalent to manufacturing serial pool

Fields:
	•	id_pool
	•	component_type_id
	•	date_key (YYYYMMDD)
	•	last_running

3) component_serial
Serial number จริงของแต่ละชิ้น component

Fields:
	•	id_component_serial
	•	serial_code (unique)
	•	component_type_id
	•	component_master_id (optional)
	•	batch_id
	•	status (available, used, waste, lost)
	•	timestamps

Indexes:
	•	uniq_serial_code
	•	idx_component_type
	•	idx_status

⸻

2. Serial Format Standard

{COMP_TYPE_CODE}-{YYYYMMDD}-{RUNNING_PAD_4}

Examples:

EDGE-20251201-0001
BODY-20251201-0052
STRAP-20251201-1042


⸻

3. PHP Serial Generator Service

File:

source/BGERP/Component/ComponentSerialService.php

Methods Required:

generateSerial($componentTypeId, $quantity, $componentMasterId = null)
	•	ใช้ pool → increment running
	•	สร้าง batch record
	•	สร้าง serial entries ทั้งหมด
	•	คืน:

{
  "batch_id": 123,
  "batch_code": "CUT-20251201-0001",
  "serials": [
      "BODY-20251201-0001",
      "BODY-20251201-0002",
      ...
  ]
}

getSerialByBatch($batchId)
reserveSerial() (stub — ทำ Phase 3)

⸻

4. API Endpoint (ใหม่)

File: source/component_serial.php

Actions:

generate

POST → generate component serials

Request:

{
  "component_type_id": 1,
  "quantity": 10,
  "component_master_id": 3,
  "notes": "CUT Batch for job #422"
}

Response:

{
  "ok": true,
  "batch_id": 44,
  "batch_code": "CUT-20251201-0004",
  "serials": ["BODY-20251201-0001", ...]
}

list_by_master

GET → serials for given component master

list_by_batch

GET → serials for given batch

⸻

5. Permission Required

เพิ่ม 2 permissions:
	•	component.serial.generate
	•	component.serial.view

Platform Admin + Tenant Admin auto allow
อื่นๆ ต้องเปิดสิทธิ์เองใน RBAC

⸻

6. Integration with CUT Behavior (Phase 2)

In BehaviorExecutionService

When cut_complete:
	•	ถ้า user ใส่จำนวนชิ้น → สร้าง serial batch
	•	Log action
	•	ยัง ไม่ bind serials → token (ทำใน Task 13.5)

UI ไม่ต้องเพิ่ม field ใหม่
ใช้ฟอร์ม CUT ปัจจุบัน:
	•	cut_quantity
	•	component_master_id (optional if product-level only)

⸻

7. Documentation

สร้าง 2 ไฟล์:

docs/dag/tasks/task13.4.md

Content:
	•	Preconditions
	•	Scope
	•	API Spec
	•	DB Schema
	•	Flow
	•	Error codes
	•	Response samples

docs/dag/tasks/task13.4_results.md

หลังทำเสร็จ

⸻

8. Acceptance Criteria
	•	DB migrations รันผ่าน
	•	Serial generator สร้าง serial ถูกต้องตาม format
	•	Batch record เกิดถูกต้อง
	•	API generate/list ผ่าน syntax check
	•	Permission checks ทำงานถูกต้อง
	•	CUT Behavior เรียก generator ได้ (optional field)
	•	ไม่มี breaking changes
	•	Tenant-safe

⸻

9. Out of Scope (ไป Task 13.5+)

❌ serial → token binding
❌ warehouse stock allocation
❌ component completeness enforcement
❌ QC component validation
❌ PWA integration
