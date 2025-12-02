task13.md – Component Serial Binding (Phase 1: Capture & Expose – Hatthasilpa Line)

Task ID: 13
Series: DAG R2
Status: 🟡 IN PROGRESS
Scope: Hatthasilpa Line Only
Type: Data Model + API Extension (Additive, Non-Breaking)

⸻

1. Background / Context

Bellavier DAG Runtime รองรับ token lifecycle ครบ (spawn/split/join/complete) และใน Hatthasilpa line serial-engine ได้ถูกใช้งานจริงแล้ว (UnifiedSerialService + serial_registry + job_ticket_serial)

แต่ระบบ ยังไม่รองรับ Component Serial Binding
ซึ่งคือความสามารถในการบันทึกว่า:

“ชิ้นส่วน BODY, FLAP, STRAP ที่เป็นชิ้นงานย่อย — มี Serial อะไร และนำไปประกอบกับกระเป๋าหมายเลขใด”

สิ่งที่มีอยู่แล้ว
	•	flow_token รองรับ token_type = component
	•	UnifiedSerialService รองรับลงทะเบียน token-serial
	•	trace_api มี endpoint serial_components แต่ใช้ inventory เท่านั้น
	•	job_ticket_serial จับ serial ของตัวงานหลักได้

สิ่งที่ยังขาด
	•	❌ ยังไม่มี table สำหรับบันทึกความสัมพันธ์ component ↔ final piece
	•	❌ trace_api ยังไม่ดึง component จาก token
	•	❌ dag_token_api ยังไม่ expose component serial
	•	❌ job API ยังไม่มีข้อมูล component serials
	•	❌ UI ยังไม่แสดง component bindings

⸻

2. Objective

Implement Phase 1 – Capture & Expose โดยไม่ทำ enforcement
และเฉพาะ Hatthasilpa line เท่านั้น

Phase 1 Objectives
	•	บันทึกความสัมพันธ์
	•	แสดงผลใน API
	•	แสดงผลบน UI แบบ Read-Only
	•	ไม่บังคับ ไม่ block ระบบ (Fail-Open)
	•	Backward-compatible เต็มรูปแบบ
	•	Classic line ไม่ถูกแตะ

⸻

3. Deliverables

Phase 1 is composed of 4 sub-deliverables:
	1.	New data model + migration
	2.	Internal API endpoint for binding write
	3.	Extend read APIs
	4.	Minimal UI (read-only list)

⸻

4. Data Model (Stage 1)

สร้าง table ใหม่:

job_component_serial

Purpose: บันทึก component_serial → final_serial → job

Schema

CREATE TABLE job_component_serial (
    id_binding INT PRIMARY KEY AUTO_INCREMENT,

    id_job_ticket INT NOT NULL,
    id_instance INT NULL,

    component_code VARCHAR(64) NULL,
    component_serial VARCHAR(100) NOT NULL,

    final_piece_serial VARCHAR(100) NULL,

    id_component_token INT NULL,
    id_final_token INT NULL,

    bom_line_id INT NULL,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NULL,

    INDEX idx_job_ticket (id_job_ticket),
    INDEX idx_instance (id_instance),
    INDEX idx_component_serial (component_serial),
    INDEX idx_final_serial (final_piece_serial),
    INDEX idx_component_token (id_component_token),
    INDEX idx_final_token (id_final_token),

    FOREIGN KEY (id_job_ticket) REFERENCES job_ticket(id_job_ticket) ON DELETE CASCADE,
    FOREIGN KEY (id_instance) REFERENCES job_graph_instance(id_instance) ON DELETE CASCADE,
    FOREIGN KEY (id_component_token) REFERENCES flow_token(id_token) ON DELETE SET NULL,
    FOREIGN KEY (id_final_token) REFERENCES flow_token(id_token) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

Key principles:
	•	additive, queryable, normalized
	•	nullable fields to support partial/late binding
	•	optional link to component tokens (Phase 2 จะ mature ขึ้น)

⸻

5. Write Path (Stage 1)

Internal API Only (no UI yet)

สร้างไฟล์:

source/hatthasilpa_component_api.php

Action:

?action=bind_component_serial

Input:

{
  "job_ticket_id": 631,
  "component_code": "BODY",
  "component_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X-BODY",
  "final_piece_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X"
}

Feature Flag:

FF_HAT_COMPONENT_SERIAL_BINDING = 0|1

Behavior:
	•	Validate → Insert → Return success
	•	No enforcement
	•	No dependencies

⸻

6. Read Path (API Exposure)

6.1 trace_api.php

เพิ่ม component serials ใน:
	•	serial_components
	•	serial_view
	•	getComponentsForSerial()

ต้อง merge 2 sources:

Source	Description
inventory_transaction_item	Original version (keep)
job_component_serial	New table


⸻

6.2 dag_token_api.php

ใน token details response เพิ่ม:

"component_serials": [...]

Mapping ตาม token → component bindings

⸻

6.3 hatthasilpa_jobs_api.php

ใน job details (action=get):

"component_serials": [...]


⸻

7. UI Exposure (Minimal)

Where to show
	•	Work Queue → Token detail drawer
	•	Hatthasilpa Job Ticket → Job detail drawer

UI behavior
	•	Read-Only
	•	Group by component_code
	•	Show serial + link to trace viewer

Example:

Components:
- BODY  →  MA...X-BODY
- FLAP  →  MA...X-FLAP
- STRAP →  MA...X-STRAP


⸻

8. Guardrails

MUST NOT
	•	break any existing JSON contract
	•	enforce component rules (that’s Phase 2/3)
	•	touch Classic line
	•	throw hard errors (fail-open only)

MUST
	•	use TenantApiOutput
	•	use PermissionHelper
	•	follow tenant boundaries
	•	be fully backward-compatible

⸻

9. Implementation Plan

Phase 1: Data Model
	•	Create migration file
	•	Apply on tenant DB layer
	•	Document schema

Phase 2: Write Path
	•	Create hatthasilpa_component_api.php
	•	Implement action bind_component_serial
	•	Protect via feature flag
	•	Logging safe (no sensitive serials)

Phase 3: Read Path
	•	Extend trace_api.php
	•	Extend dag_token_api.php
	•	Extend hatthasilpa_jobs_api.php
	•	Ensure backward compatibility

Phase 4: UI
	•	Work Queue token details
	•	Hatthasilpa job ticket details
	•	Simple read-only section

Phase 5: Tests
	•	Test binding insert
	•	Test serial → component lookup
	•	Tenant isolation test
	•	Update task_index.md
	•	Update IMPLEMENTATION_STATUS_SUMMARY.md

⸻

10. Completion Criteria

✓ Migration created and works
✓ Internal API accepts component binding
✓ trace_api returns merged component list
✓ dag_token_api returns component_serials
✓ job ticket API returns component_serials
✓ UI read-only working
✓ Backward compatible
✓ No change to Classic line
✓ Documented in task_index.md

⸻

11. Notes for Future Phases (Task 14+)
	•	Phase 2: Link to flow_token, enforce parent-child genealogy
	•	Phase 3: Full integration with component BOM
	•	Phase 4: Enforcement (component check at JOIN)
	•	Phase 5: Classic line parity
	•	Phase 6: Genealogy export + QR

⸻

12. Status

🟡 Phase 1 (Discovery) → Completed
🟡 Phase 2 (Data Model) → Next
🟡 Phase 3 (Read Path) → Pending
⚪ Phase 4 (UI) → Pending
⚪ Phase 5 (Tests & Docs) → Pending

⸻