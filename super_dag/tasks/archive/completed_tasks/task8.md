Task 8: DAG Execution Logic (Phase 1) อย่างที่คุณเขียนท้ายสรุปไว้เลย

⸻

แนวคิด Task 8 – DAG Execution Logic (Phase 1, No New Feature)

เป้าหมายหลักของ Task 8:
	•	เอา “ตรรกะการขยับ Token ไปตาม DAG” ที่ตอนนี้กระจายอยู่ในหลายไฟล์
(เช่น dag_token_api.php, pwa_scan_api.php, hatthasilpa_job_ticket.php)
→ มารวมให้อยู่ใน Service เดียว ภายใต้ BGERP\Dag
	•	ในเฟสนี้: ไม่เพิ่ม behavior ใหม่, ไม่เปลี่ยนวิธีใช้งานของผู้ใช้
แค่ “ย้ายและจัดระบบ” logic ให้เป็น DAG Execution Service กลาง

พูดง่าย ๆ:
Task 7 = เวลาเดินจริงแล้ว (STITCH)
Task 8 = ทำให้ “การเดินไป node ถัดไป” มีสมองกลาง ไม่กระจัดกระจาย

⸻

ขอบเขต Task 8

IN Scope
	1.	สร้าง DAG Execution Service กลาง
	•	ไฟล์ใหม่ (ตัวอย่างชื่อ):
	•	source/BGERP/Dag/DagExecutionService.php
	•	Responsibility:
	•	โหลด routing graph ของ token (nodes, edges)
	•	รู้ว่า “node ปัจจุบันคืออะไร” และ “node ถัดไปคืออะไร”
	•	ทำ operation:
	•	moveToNextNode(...)
	•	moveToNodeId(...) (สำหรับกรณี override/manual, ยังไม่ต้องใช้เต็มที่แต่เตรียม interface)
	•	reopenPreviousNode(...) (วาง stub ไว้ใช้ใน rework ภายหลัง)
	2.	Refactor logic การขยับ token ที่มีอยู่แล้ว
ให้ Agent ไปค้นโค้ดที่ตอนนี้ทำหน้าที่:
	•	ปิด node ปัจจุบัน / set status completed
	•	เปลี่ยน flow_token.current_node_id
	•	log timeline, dag log ฯลฯ
โดย:
	•	ย้าย into DagExecutionService
	•	ให้ endpoint เก่า (dag_token_api.php, pwa_scan_api.php, etc.)
เรียกผ่าน service นี้แทน
	3.	ผูกเข้ากับ Time/Token Engine แบบ “รู้จักกันแต่ยังไม่ deep coupling”
	•	ใน DagExecutionService::moveToNextNode():
	•	เช็คว่ามี work session active ที่ node ปัจจุบันไหม
	•	(Phase 1) แค่ validate + warning ถ้าจำเป็น ยังไม่ต้อง auto-close session
	•	เก็บโครงไว้สำหรับ Task ถัดไปที่จะทำ auto-complete session → then move node
	4.	เอกสาร
	•	docs/super_dag/tasks/task8.md – spec ของ Task 8
	•	docs/super_dag/tasks/task8_results.md – สรุปหลังทำเสร็จ
	•	อัปเดต docs/super_dag/task_index.md → Task 8 = COMPLETED

OUT of Scope (ห้ามทำใน Task 8)
	•	❌ ยังไม่ต้องเพิ่ม behavior action ใหม่ใน UI เช่น stitch_complete
	•	❌ ยังไม่ต้องเปลี่ยน behavior panel, templates, payload
	•	❌ ยังไม่ต้อง implement rework, multi-QC, batch split จริง
	•	❌ ยังไม่ต้อง tie-in component binding

ตอนนี้คนใช้ระบบจะ “รู้สึกเหมือนเดิมเป๊ะ”
แต่ข้างใน code base จะเป็นระเบียบขึ้นมาก

⸻

สเปค DAG Execution Service (Phase 1)

ตัวอย่าง interface ที่อยากได้ (ให้ Agent design รายละเอียดเองได้ แต่ควรใกล้เคียง):

namespace BGERP\Dag;

class DagExecutionService
{
    public function __construct(\PDO $tenantDb, array $org, int $userId) { ... }

    /**
     * Move token forward along its DAG (happy path)
     */
    public function moveToNextNode(int $tokenId): array
    {
        // return ['ok' => bool, 'from_node_id' => ?, 'to_node_id' => ?, 'error' => ?];
    }

    /**
     * Move token to a specific node (for override / future features)
     */
    public function moveToNodeId(int $tokenId, int $targetNodeId): array
    {
        // Phase 1: basic validation + possibly not used yet
    }

    /**
     * Stub for rework / reopening previous nodes
     */
    public function reopenPreviousNode(int $tokenId, int $nodeId): array
    {
        // Phase 1: might just return ['ok' => false, 'error' => 'not_implemented']
    }
}

ภายใน service:
	•	โหลด routing graph (จาก data structure ที่คุณใช้ปัจจุบัน)
	•	หา current_node ของ token
	•	หา edge ต่อ (default path) → node ถัดไป
	•	update:
	•	flow_token.current_node_id
	•	log movement (ถ้า logic นี้มีอยู่แล้ว ให้ย้ายมาที่นี่)

⸻

ไฟล์ที่คาดว่าจะโดนแตะใน Task 8

ให้ Agent สำรวจ + refactor:
	•	source/dag_token_api.php
	•	source/pwa_scan_api.php
	•	source/hatthasilpa_job_ticket.php
	•	source/trace_api.php (ถ้าแตะ node movement หรือ state)
	•	source/BGERP/Dag/BehaviorExecutionService.php
	•	(Phase 1 อาจยังไม่ต้องผูก behavior กับ DAG move, แต่เตรียม hook ไว้)


⸻

คุณคือ Senior PHP Architect ของ Bellavier Group ERP (super_dag timeline)

โฟกัสงานเฉพาะ Task 8 – DAG Execution Logic (Phase 1)

โฟลเดอร์สำคัญ:
- source/dag_token_api.php
- source/pwa_scan_api.php
- source/hatthasilpa_job_ticket.php
- source/BGERP/Dag/*
- docs/super_dag/tasks/*
- docs/super_dag/task_index.md

เป้าหมายของ Task 8:
- สร้าง “DAG Execution Service” กลางใน namespace BGERP\Dag
- ย้าย logic การขยับ token ไปตาม DAG (move node, update current_node_id, log) จาก endpoint เดิมเข้า service
- ห้ามเปลี่ยน behavior UI หรือ payload
- ห้ามเพิ่ม feature ใหม่ที่ user มองเห็น (Phase 1 = refactor + consolidate logic)

ข้อกำหนดสำคัญ:

1) สร้างไฟล์ใหม่:
   - source/BGERP/Dag/DagExecutionService.php
   - namespace BGERP\Dag;

   คลาสนี้ต้อง:
   - constructor(\PDO $tenantDb, array $org, int $userId)
   - มีเมธอดอย่างน้อย:
     - moveToNextNode(int $tokenId): array
     - moveToNodeId(int $tokenId, int $targetNodeId): array
     - reopenPreviousNode(int $tokenId, int $nodeId): array (stub สำหรับอนาคต)

   แต่ละเมธอดต้อง return array ที่มีโครง:
   - ['ok' => bool, 'from_node_id' => int|null, 'to_node_id' => int|null, 'error' => string|null]

2) ให้ค้นหา logic ปัจจุบันที่:
   - เปลี่ยน flow_token.current_node_id
   - ปิด node ปัจจุบัน / mark completed
   - สร้าง log ที่เกี่ยวกับ DAG movement
   โดยเฉพาะใน:
   - source/dag_token_api.php
   - source/pwa_scan_api.php
   - source/hatthasilpa_job_ticket.php

   จากนั้น:
   - ย้าย core logic เข้า DagExecutionService
   - Endpoint เดิมเรียก service แทน
   - พยายามไม่เปลี่ยน behavior เดิม (same input → same output)

3) ใน Phase 1 นี้:
   - ยังไม่ต้องผูก BehaviorExecutionService กับ DagExecutionService โดยตรง
   - ยังไม่ต้องเพิ่ม behavior action ใหม่ (เช่น stitch_complete)
   - แค่ทำให้มี “สมองกลาง” สำหรับ DAG move พร้อมใช้งานใน Task ถัดไป

4) Safety Rails:
   - ห้ามเปลี่ยน schema database
   - ห้ามเปลี่ยนโครงสร้าง JSON response ของ API ที่มีอยู่แล้ว (key เดิมต้องยังอยู่)
   - ถ้าต้องเพิ่ม field ใหม่ใน response ให้เป็น field เสริม (optional) เท่านั้น
   - ห้ามเปลี่ยน logic ที่เกี่ยวกับ component binding, QC state, หรือ time engine
   - ห้ามโยน exception หลุดจาก endpoint: ให้จับและแปลงเป็น JSON error ผ่าน TenantApiOutput ถ้า endpoint ใช้มันอยู่แล้ว

5) เอกสาร:
   - สร้าง docs/super_dag/tasks/task8.md:
     - สรุปเป้าหมาย, scope, non-goals, service interface, safety rails
   - สร้าง docs/super_dag/tasks/task8_results.md:
     - รายงานไฟล์ที่แก้ไข/สร้าง
     - อธิบาย logic ที่ถูกย้ายเข้า DagExecutionService
     - ยืนยันว่า behavior ภายนอกเหมือนเดิม
   - อัปเดต docs/super_dag/task_index.md:
     - เพิ่ม Task 8 ในรายการ และ mark ว่า COMPLETED (เมื่อทำเสร็จ)

6) การทดสอบ:
   - php -l สำหรับทุกไฟล์ PHP ที่สร้าง/แก้ไข
   - เรียก API ที่เคยใช้ DAG move เดิม:
     - ผ่าน UI work_queue / pwa_scan / job_ticket ตามที่เคยใช้ทดสอบ
     - ตรวจว่า current_node_id เปลี่ยนเหมือนเดิม
   - ถ้า endpoint มี SystemWide tests อยู่แล้ว ให้รันเฉพาะไฟล์เหล่านั้น และบันทึกผลใน task8_results.md

ให้แสดง diff อ่านง่าย, ระวังไม่ลบ logic เดิมที่ไม่ได้เกี่ยวข้องกับ DAG Execution