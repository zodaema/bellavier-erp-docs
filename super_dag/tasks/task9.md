Task 9: Behavior–DAG Integration (Phase 2) ตามที่คุณเขียนปิดท้ายไว้เลย

⸻

แนวคิด Task 9 — Behavior ↔ DAG Execution

เป้าหมายสั้นๆ
ทำให้ “การกดปุ่ม behavior” บน UI (เช่น STITCH complete, QC pass/fail)
→ ไม่ได้แค่ log / time session แล้วจบ
แต่จะ สั่ง DAG เดินต่อ ผ่าน DagExecutionService โดยตรง (อย่างปลอดภัย)

ยังคงหลักการเดิม:
	•	ไม่เปลี่ยน UI / payload รูปแบบใหญ่ๆ
	•	ไม่เปลี่ยน response structure ที่ client ใช้อยู่
	•	เพิ่มความสามารถ “ต่อท้าย” จาก behavior → route token

⸻

ขอบเขต Task 9

IN Scope
	1.	เชื่อม BehaviorExecutionService → DagExecutionService
ใน source/BGERP/Dag/BehaviorExecutionService.php:
	•	เพิ่ม dependency:

use BGERP\Dag\DagExecutionService;


	•	ใน constructor หรือ factory ใด ๆ ที่ใช้:
	•	รับ / สร้าง DagExecutionService ด้วย (ใช้ tenantDb + org + userId เหมือน Task 8)

	2.	กำหนด behavior ที่จะ trigger DAG move (ระยะแรก)
อย่างน้อย 3 กลุ่ม:
	•	STITCH:
	•	action: stitch_complete
	•	หลังจาก session ถูก complete แล้ว → เรียก DagExecutionService::moveToNextNode($tokenId)
	•	QC:
	•	action: qc_pass
	•	ให้ใช้เส้นทาง pass ใน routing (อาจให้ DAGRoutingService จัดการ แต่ผ่าน DagExecutionService)
	•	action: qc_fail / qc_rework
	•	ตอนนี้ ยังไม่ต้องทำ rework จริง แต่เตรียม hook ไว้ (อาจยังไม่ route จริงแค่ log-only หรือให้ DAGRoutingService handle เหมือนเดิม)
	•	CUT / EDGE / HARDWARE:
	•	ระยะนี้ยังคง log-only แต่เตรียม comment / placeholder ไว้ใน BehaviorExecutionService สำหรับ task ถัดไป
	3.	ออกแบบผลลัพธ์มาตรฐานจาก behavior_exec
ตอนนี้ dag_behavior_exec.php ส่ง payload กลับไปแนวนี้ (สมมติ):

{
  "ok": true,
  "effect": "token_status_updated",
  "session_id": 123,
  "log_id": 456
}

Task 9 ให้เพิ่ม field เสริม (ไม่ breaking) เช่น:

{
  "ok": true,
  "effect": "stitch_completed_and_routed",
  "session_id": 123,
  "log_id": 456,
  "routing": {
    "moved": true,
    "from_node_id": 10,
    "to_node_id": 11,
    "completed": false
  }
}

	•	routing เป็น optional field
	•	ถ้า behavior นั้นไม่ทำให้ DAG เดินต่อ → routing = null หรือไม่ส่งเลย

	4.	เชื่อม behavior_execution.js ให้รู้ว่าเมื่อไหร่ต้อง refresh UI
ใน assets/javascripts/dag/behavior_execution.js:
	•	หลัง BGBehaviorExec.send() ได้ response ที่มี routing.moved = true:
	•	ให้ call callback / trigger event (เช่น BG.DagEvents.onTokenMoved(...))
	•	ตอนนี้ทำแค่ “refresh view” ของ work_queue / pwa_scan / job_ticket ก็ได้ (เช่น reload token card)
	•	แต่ ไม่ต้อง implement animation / UI advance ลึกมากใน Task 9
	5.	เอกสาร
	•	docs/super_dag/tasks/task9.md – spec ของ Task 9
	•	docs/super_dag/tasks/task9_results.md – สรุปหลังทำเสร็จ
	•	อัปเดต docs/super_dag/task_index.md → เพิ่ม Task 9, mark COMPLETED เมื่อเสร็จ

⸻

OUT of Scope (ห้ามทำใน Task 9)
	•	❌ ยังไม่ทำ rework จริง (reopenPreviousNode, complex QC re-route)
	•	❌ ยังไม่แตะ component binding
	•	❌ ยังไม่ auto-close work session ของทุก behavior (ตอนนี้ทำเฉพาะ STITCH ตาม Task 7)
	•	❌ ยังไม่แตะ PWA scan classic line
	•	❌ ไม่เปลี่ยนโครง payload form_data / context จาก behavior panel

⸻

Prompt

คุณคือ Senior PHP Architect ของ Bellavier Group ERP (super_dag timeline)

โฟกัสเฉพาะ Task 9 – Behavior–DAG Integration (Phase 2)

โฟลเดอร์สำคัญ:
- source/dag_behavior_exec.php
- source/BGERP/Dag/BehaviorExecutionService.php
- source/BGERP/Dag/DagExecutionService.php
- assets/javascripts/dag/behavior_execution.js
- docs/super_dag/tasks/*
- docs/super_dag/task_index.md

เป้าหมาย:
- เมื่อ user กด behavior action (เช่น stitch_complete) ผ่าน behavior panel:
  → ให้ BehaviorExecutionService เรียก DagExecutionService เพื่อ move token ตาม DAG
  → ให้ API response ของ dag_behavior_exec.php มีข้อมูล routing เพิ่มเติม (แบบ optional)
- ห้ามเปลี่ยน behavior ภายนอก (UX เดิมยังเหมือนเดิม) นอกจาก “งานเดินต่ออัตโนมัติ” ที่สมเหตุสมผล

สิ่งที่ต้องทำ:

1) BehaviorExecutionService ↔ DagExecutionService

- อัปเดต source/BGERP/Dag/BehaviorExecutionService.php:
  - เพิ่ม dependency ต่อ DagExecutionService (ใช้ tenantDb + org + userId)
  - ใน handler ของ STITCH:
    - เมื่อ action = 'stitch_complete' และ Time Engine ทำงานสำเร็จ:
      - เรียก $dagExecutionService->moveToNextNode($tokenId)
      - เก็บผลลัพธ์ (from_node_id, to_node_id, completed) ลงใน result array
  - ใน handler ของ QC (ถ้ามี action เช่น 'qc_pass', 'qc_fail', 'qc_rework'):
    - ให้เรียก DagExecutionService หรือ DAGRoutingService ตาม logic ปัจจุบัน
    - Phase นี้ถ้า logic QC ซับซ้อน ให้พยายาม wrap การเรียกเดิมลงใน BehaviorExecutionService
    - ถ้าซับซ้อนเกินไป ให้คงใช้ DAGRoutingService เหมือนเดิม แต่ส่ง routing summary กลับภายใต้คีย์เดียวกัน

- ห้าม duplicate logic จาก DagExecutionService หรือ DAGRoutingService
- ให้ BehaviorExecutionService ทำหน้าที่ orchestration เท่านั้น

2) อัปเดต dag_behavior_exec.php

- หลังจาก BehaviorExecutionService::execute(...) คืนค่า:
  - ถ้า result มีข้อมูล routing (เช่น 'routing' หรือ 'dag_move'):
    - ให้ผนวกข้อมูลนี้เข้า JSON response หลัก
  - รูปแบบแนะนำ:
    - เพิ่ม field 'routing' ใน response:
      - ['moved' => bool, 'from_node_id' => int|null, 'to_node_id' => int|null, 'completed' => bool|null]
- ห้ามลบ key เดิมออกจาก response
- สามารถเพิ่ม field ใหม่ได้ แต่ต้องไม่ breaking

3) behavior_execution.js

- เปิดไฟล์ assets/javascripts/dag/behavior_execution.js
- ใน BGBehaviorExec.send():
  - หลังรับ response สำเร็จ:
    - ถ้า response.routing.moved === true:
      - ให้เรียกฟังก์ชัน callback (ถ้ามีอยู่ เช่น options.onRoutingApplied)
      - ถ้าตอนนี้ยังไม่มี callback ให้ implement event เล็ก ๆ:
        - เช่น window.dispatchEvent(new CustomEvent('BG:TokenRouted', { detail: { token_id, from_node_id, to_node_id }}))
      - ในไฟล์ pwa_scan.js และ work_queue.js:
        - ถ้ามีจุดเหมาะสม ให้ subscribe event นี้ แล้ว reload token card หรือ refresh table เฉพาะบรรทัด (ถ้าทำได้ง่าย)
      - ถ้าซับซ้อนเกินไป ให้เริ่มจากการ log ใน console แต่ให้เขียน TODO ไว้ในโค้ดชัดเจน

- ห้ามเปลี่ยน payload structure ตอนส่ง (behavior_code, source_page, context, form_data)

4) เอกสาร

- สร้าง docs/super_dag/tasks/task9.md:
  - อธิบายเป้าหมาย, scope, non-goals, ภาพรวม integration (Behavior → Time Engine → DagExecutionService)
- สร้าง docs/super_dag/tasks/task9_results.md:
  - สรุปไฟล์ที่แก้ไข/สร้าง
  - อธิบาย behavior ที่ตอนนี้ “เดิน DAG ต่อ” แล้ว
  - ระบุข้อจำกัด (เช่น QC ยังไม่สมบูรณ์, rework ยังไม่ implement)
- อัปเดต docs/super_dag/task_index.md:
  - เพิ่ม Task 9 ในรายการ
  - Mark COMPLETED เมื่อทำเสร็จ

5) Safety Rails

- ห้ามเปลี่ยน database schema
- ห้ามเปลี่ยน structure หลักของ JSON response ที่ client มีการใช้แล้ว (เพิ่ม field ได้, ห้ามลบ/rename field)
- ห้ามเปลี่ยน business logic ของ QC routing, component binding, หรือ time engine ในแบบที่แตกต่างจาก behavior ปัจจุบัน
- ถ้ามี error จาก DagExecutionService:
  - ต้องถูกจับและส่งกลับในรูปแบบ JSON error มาตรฐาน (ผ่าน TenantApiOutput หรือรูปแบบที่ dag_behavior_exec ใช้อยู่)
- หากไม่มั่นใจเรื่อง side-effect ให้ใส่ TODO + comment ไว้ชัดเจน แทนการเดาร้ายแรง

6) ทดสอบ

- php -l สำหรับทุกไฟล์ที่แก้ไข
- manual test ผ่าน UI:
  - STITCH:
    - start → pause → resume → complete (ต้อง route ต่อได้ และไม่พัง)
  - ถ้ามี behavior QC บน UI ให้ลองอย่างน้อย 1 case (pass)
- ระบุผลการทดสอบใน task9_results.md
