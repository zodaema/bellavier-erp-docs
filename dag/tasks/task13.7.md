🧩 Task 13.7 — Component Override Supervisor UI

Phase 3.3 — UI Integration for Component Completeness Override

สถานะ: Ready for Implementation
ความสำคัญ: สูง
งานนี้เป็น extension โดยตรงจาก Task 13.6

⸻

🎯 Objective

สร้าง UI ให้ Supervisor/Admin สามารถ:
	1.	ตรวจสอบว่า token ไหน “ขาด component” (incomplete)
	2.	ดูรายการ component ที่ยังขาด
	3.	ใช้ “Supervisor Override” ผ่าน UI
	•	ส่ง reason
	•	ระบบจะ route token ไป node ถัดไปทันที (skip completeness validation)
	•	Log ทุกอย่างเพื่อ audit trail

⸻

🧱 Deliverables

1. 🔧 New Page Definition

File: page/component_supervisor_override.php
	•	Register route /component_supervisor_override
	•	Load:
	•	DataTable
	•	supervisor UI JS
	•	permissions check

⸻

2. 🖥️ New View Template

File: views/component_supervisor_override.php

ต้องมีองค์ประกอบดังนี้:
	•	DataTable:
	•	token_id
	•	product
	•	current node
	•	required components
	•	bound components
	•	missing components
	•	created_at / updated_at
	•	action button: “Override”
	•	Modal “Override Requirements”
	•	Fields:
	•	token_id (read-only)
	•	target_node_id (auto-filled)
	•	missing components list (read-only)
	•	reason (required textarea)
	•	Buttons:
	•	Confirm Override
	•	Cancel
	•	Toast system (success/error)

⸻

3. 📦 New JavaScript Logic

File: assets/javascripts/component/component_supervisor_override.js

Responsibilities:
	•	Load DataTable from API
(component_binding.php?action=list_incomplete_tokens)
	•	Click “Override” → เปิด modal
	•	Submit override:
	•	Call API:
component_binding.php?action=override_requirements
	•	Payload:
	•	token_id
	•	target_node_id
	•	reason
	•	Update UI after success:
	•	Refresh table
	•	Toast success
	•	Error handling:
	•	Show missing list
	•	Show audit history (optional future)

⸻

4. 🔌 API Endpoint Enhancements

File: source/component_binding.php

Add new action:

list_incomplete_tokens
Query:
	•	join tokens + routing_node + component_required config
	•	calculate missing components
	•	return only incomplete tokens

Return format:

{
  "ok": true,
  "data": [
    {
      "token_id": 312,
      "current_node_id": 45,
      "node_name": "EDGE PAINT 1",
      "components_required": [...],
      "bound": [...],
      "missing": [...],
      "suggested_action": "Please bind missing components before progressing"
    }
  ]
}

Permission:
	•	component.binding.view
	•	plus only: platform admin OR tenant admin
(ใช้ RbacHelper::isOwnerRole())

⸻

5. 🔐 Permission System

New permission:

Code	Name	Default
component.binding.override_ui	Access component override UI	Admin only

Migration:
File:
database/tenant_migrations/2025_12_component_override_ui_permission.php

⸻

6. 📝 Documentation

File: docs/dag/tasks/task13.7_results.md

ต้องรวม:
	•	What was added
	•	API specs
	•	UI structure
	•	error codes
	•	user stories
	•	audit specification

⸻

⚠️ Constraints & Safety
	•	ต้องไม่แตะ DAG Execution Logic
	•	ต้องไม่แก้ Behavior Execution Logic
	•	ต้องไม่ route token ถ้าไม่ใช่ admin
	•	การ override ต้อง log ใน component_serial_usage_log:
	•	token_id
	•	target_node_id
	•	supervisor_id
	•	reason
	•	timestamp

⸻

🚦 Definition of Done (DoD)
	•	✓ Page + View + JS ครบ
	•	✓ DataTable แสดง tokens ที่ incomplete
	•	✓ Modal override ใช้งานได้จริง
	•	✓ API override สำเร็จ
	•	✓ Log ลงฐานข้อมูล
	•	✓ Permission การเข้าถึงถูกต้อง
	•	✓ UI ใช้งานง่ายสำหรับ Supervisor
	•	✓ ไม่กระทบ task13.6 และ super_dag flow

⸻