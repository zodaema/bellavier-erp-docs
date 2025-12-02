Task 13.6 — Component Completeness Enforcement (Phase 3.2)

Status: PENDING
Owner: super_dag / component_system
Depends on: Task 13.5 (Soft Binding)

⸻

🎯 Objective

เพิ่ม “Component Completeness Enforcement” ลงใน DAG execution flow
เพื่อให้ระบบสามารถ บังคับว่าทุกงานต้องมี Component Serial ครบ ตามที่ Node ต้องการ
ก่อนที่จะอนุญาตให้ token ถูก route ไป node ถัดไป

นี่คือ Phase 3.2 ซึ่งเป็นจุดเปลี่ยนของระบบ Component
จาก Soft Binding → Real Production Enforcement

⸻

1) Feature Scope (ต้องทำใน Task นี้)

1.1 Node-level Component Requirements

เพิ่มความสามารถให้แต่ละ node ระบุได้ว่า:
	•	Node นี้ต้องการ component อะไรบ้าง
	•	ต้องการจำนวนเท่าไร
	•	Component type หรือ component master
	•	Allow substitute หรือไม่ (MVP: ยังไม่ต้อง)

ไม่ต้องเพิ่ม column ใน DB
แต่เก็บไว้ใน:

routing_node.meta_json → components_required: [...]

ตัวอย่าง

{
  "components_required": [
    { "type_id": 1, "qty": 1 },
    { "type_id": 3, "qty": 2 }
  ]
}


⸻

1.2 Completeness Validation

เพิ่มการตรวจสอบในขั้นตอน:
	•	DagExecutionService::moveToNextNode()
	•	DagExecutionService::moveToNodeId()

โดยระบบต้องทำต่อไปนี้:
	1.	โหลด requirements จาก node
	2.	อ่าน bindings จาก ComponentBindingService::getBindingsForToken()
	3.	นับจำนวน serial ที่ bind แล้ว
	4.	ถ้าจำนวน < requirements → route ไม่ได้

จุดนี้เป็นหัวใจของ Task 13.6

⸻

1.3 Routing Block Rules

เมื่อช่างกด Complete (เช่น CUT, STITCH, EDGE, QC):
	•	ถ้า Node ต้องการ Component และ Bind ไม่ครบ → Block
	•	ส่ง error กลับไปยัง UI พร้อมรายการที่ยังขาด

⸻

1.4 API Response Format

เมื่อ block routing ต้องส่ง response ดังนี้:

{
  "ok": false,
  "error_code": "COMPONENT_INCOMPLETE",
  "message": "จำเป็นต้องผูก Serial ให้ครบก่อนทำขั้นตอนถัดไป",
  "missing": [
    { "type_id": 1, "type_name": "BODY", "required": 1, "bound": 0 },
    { "type_id": 3, "type_name": "LINING", "required": 2, "bound": 1 }
  ],
  "suggested_action": "กรุณาผูก Serial ให้ครบก่อน"
}


⸻

1.5 UI Updates (PWA + Work Queue + Job Ticket)

PWA Scan
	•	ถ้าเจอ routing blocked →
	•	Popup แสดงรายการที่ยังขาด
	•	มีปุ่ม “สแกนเพื่อ Bind Serial” เพื่อเปิด serial binding panel

Work Queue
	•	ถ้า token incomplete → แสดง badge สีแดง / icon warning

Job Ticket
	•	เพิ่ม “Component Requirements” tab
	•	Highlight ข้อที่ยังไม่ครบด้วยสีแดง

⸻

1.6 Supervisor Override (MVP)

ใน Task 13.6 ให้ทำ แค่ตรรกะ override, UI ทำใน Task 13.7

เพิ่ม endpoint:

component_binding.php?action=override_requirements

ทำงานได้เฉพาะ:
	•	Platform admin
	•	Tenant admin

และอนุญาตให้:
	•	บันทึก override event ลง log
	•	route token แม้ไม่ครบ requirement

⸻

2) What NOT to include in Task 13.6 (ไปทำ Task 13.7–13.9)

เพื่อไม่ให้ task ใหญ่เกินไป:

❌ ยังไม่ทำ UI override
❌ ยังไม่ enforce substitute components
❌ ยังไม่ enforce cross-node validation
❌ ยังไม่ enforce serial usage beyond 1 token
❌ ยังไม่ enforce stock allocation

Task 13.6 คือ Minimal Viable Enforcement เท่านั้น

⸻

3) Technical Deliverables

3.1 Update: DagExecutionService

เพิ่ม logic:

validateComponentCompleteness($tokenId, $nodeId)

และเรียกใช้ก่อน routing ทุกครั้ง

3.2 Update: ComponentBindingService

เพิ่ม method:

countBindingsByTypeForToken($tokenId)

3.3 Update: dag_behavior_exec.php

ถ้า routing ถูก block ต้อง bubble error กลับไปยัง UI

3.4 Update: pwa_scan.js

จับ error_code = COMPONENT_INCOMPLETE
แสดง popup รายการที่ขาด

3.5 Update: job_ticket.js

เพิ่ม panel components_required

3.6 Documentation
	•	docs/dag/tasks/task13.6_results.md
	•	Update task_index.md

⸻

4) Acceptance Criteria
	•	Node-level requirements ถูกอ่านจาก meta_json ได้
	•	Routing ถูก block เมื่อ component ไม่ครบ
	•	Error response ชัดเจน มีรายการที่ยังขาด
	•	PWA + Work Queue + Job Ticket แสดงผลครบ
	•	Supervisor override ทำงานผ่าน API
	•	ไม่มี breaking change ต่อ Super DAG flow
	•	Syntax check ผ่านทุกไฟล์
	•	Tenant-safe & backward compatible

⸻

5) After Task 13.6 (Roadmap Preview)
	•	Task 13.7: Supervisor UI สำหรับ override
	•	Task 13.8: Component Requirements Designer (UI ใน DAG Designer)
	•	Task 13.9: Cross-node validation + strict enforcement
	•	Task 14+: Warehouse integration + stock allocation

⸻
