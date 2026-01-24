
✅ docs/super_dag/tasks/task14.md — Super DAG Task 14

(Minimum Viable Execution for CUT / EDGE / QC Behaviors)

ด้านล่างคือเวอร์ชันที่พร้อมนำไปใส่ไฟล์ task14.md ได้ทันที

⸻

Task 14 — Super DAG Behavior Execution (CUT / EDGE / QC) — Minimal Viable Production Line

🎯 Goal / เป้าหมาย

ทำให้กระบวนการ Hatthasilpa สามารถ “วิ่งครบเส้น” ได้จริง
แม้จะยังไม่มี Component Serial Binding และยังไม่ซับซ้อนแบบโรงงานจริง 100%

เป้าหมายของ Task 14:
ให้ CUT → STITCH → EDGE → QC → PACK
ทำงานจริงแบบ MVP (Minimum Viable Production Line)
โดยใช้ Behavior Pipeline ที่สร้างไว้ตั้งแต่ Tasks 1–12

⸻

🔧 Scope

พัฒนา Behavior Execution Logic ขั้นแรกสำหรับ 3 behavior ใหม่:
	•	CUT (Batch Work)
	•	EDGE (Multi-Coats Edge Paint)
	•	QC_SINGLE / QC_FINAL (Simple Pass/Fail)

โดย ไม่แตะ:
	•	Component Binding (จะทำหลัง Task 14)
	•	Advanced Metrics
	•	Multi-round Edge Paint
	•	Defect Codes
	•	PWA Classic Line

⸻

🧩 Behavior Requirements (MVP)

1) CUT Behavior — Batch Production

✓ Worker กด “Start Cutting” → เปิด session แบบ batch
✓ Worker กด “Complete Cutting” → ปิด session และ route token ไป STITCH

Session Rules
	•	ไม่ต้อง track per-piece
	•	ใช้ time session แบบ batch เดียวพอ

DAG Routing After Complete
	•	ทุกใบใน batch จะถูก route ต่อไป node STITCH
	•	(ไม่มี split per-piece ใน Phase นี้)

⸻

2) EDGE Behavior — Simple Coating

✓ Worker กด “Start Edge Coat” → เปิด session
✓ Worker กด “Complete Coat” → ปิด session และ route token ต่อไป
✓ ยังไม่ต้องทำ multi-round
✓ ยังไม่ต้องทำ drying timer

MVP = 1 รอบ ต่อใบ

⸻

3) QC Behavior — Simple PASS / FAIL

✓ Worker กด PASS → route ไป node ถัดไป
✓ Worker กด FAIL → route ย้อนกลับไป rework node (ตาม DAG)

ไม่มี multi-level QC ใน Phase นี้ (จะมาใน Task 18)

⸻

📌 API Changes (MVP Only)

เพิ่ม handler ใหม่ใน BehaviorExecutionService:
	•	handleCutStart()
	•	handleCutComplete()
	•	handleEdgeStart()
	•	handleEdgeComplete()
	•	handleQcPass()
	•	handleQcFail()

สิ่งสำคัญคือ:
ใช้งาน Session Engine แบบเดียวกับ STITCH แล้วจึง route ผ่าน DagExecutionService

⸻

📁 Files to Modify

1. source/BGERP/Dag/BehaviorExecutionService.php

เพิ่ม method สำหรับ CUT / EDGE / QC (ตาม handler ที่กล่าวด้านบน)

2. source/dag_behavior_exec.php

เพิ่ม action mapping:
	•	cut_start, cut_complete
	•	edge_start, edge_complete
	•	qc_pass, qc_fail

3. assets/javascripts/dag/behavior_execution.js

เพิ่ม UI-side handlers:
	•	onCutStart()
	•	onCutComplete()
	•	onEdgeStart()
	•	onEdgeComplete()
	•	onQcPass()
	•	onQcFail()

4. Behavior UI templates

ไม่ต้องแก้เยอะ → เพิ่มปุ่มใน panel เดิมที่สร้างใน Task 4

⸻

📑 Acceptance Criteria
	1.	CUT behavior:
	•	Start/Complete ทำงานได้
	•	Token ถูก route ไป STITCH อัตโนมัติ
	•	Session summary ส่งกลับมาถูกต้อง
	2.	EDGE behavior:
	•	Start/Complete ทำงานได้
	•	Token route ต่อได้
	3.	QC behavior:
	•	Pass → route ไป node ถัดไป
	•	Fail → route ไป Rework node
	4.	Work Queue / PWA Scan
	•	Refresh อัตโนมัติเมื่อ token ถูก route
	•	Behavior panel เห็นปุ่ม correctly
	5.	Error-handling
	•	ใช้มาตรฐาน error code จาก Task 10

⸻

🚀 Output of This Task

หลังจบ Task 14 คุณจะทำได้:
	•	ใช้งาน LINE ผลิต Hatthasilpa แบบ MVP ทั้งเส้น
	•	สาธิตการทำงานให้ช่าง/ผู้บริหารดูได้จริง
	•	ใช้ session/log/route อย่างถูกต้อง
	•	เห็นภาพ workflow จริงของโรงงาน

และพร้อมสำหรับ Task 15 ต่อทันที

⸻

❗ ถ้าต้อง “กระโดดไปทำ Components ก่อน” — จะต้องเป็นกรณีนี้

ผมจะบอกทันทีเมื่อพบเงื่อนไขต่อไปนี้:

🇩🇴 ควรหยุด Super DAG และไปทำ Component ก่อน ทันที ถ้า …
	•	Work Center “HARDWARE_ASSEMBLY” ต้องการ binding ของ component เพื่อ route ต่อ
เช่น: ประกอบ hardware จะต้องรู้ว่า hardware serial ไหนถูกใช้งาน
	•	QC_FINAL ต้องตรวจสอบว่า component ครบหรือไม่ก่อน pass
	•	หรือคุณต้องการ trace 100% เพื่อใช้ขายลูกค้าช่วงเปิดตัว

🇩🇴 ตอนนี้ยัง “ไม่ต้องกระโดด” ไป Components

เพราะ:
	•	CUT / EDGE / QC MVP ยังไม่ได้แตะ component เลย
	•	คุณยังไม่เริ่ม FLOW ที่จะรวม component จริง
	•	เดี๋ยวระบบยังไม่เห็นภาพหลักของการผลิต Hatthasilpa

🎯 สรุป: ทำ Task 14 ก่อน → ถึง Task 16 ค่อยกระโดดไป Components

⸻

พร้อมส่งให้ AI Agent ใช้หรือยัง?

ถ้าพร้อม → ผมจะแก้ไฟล์ task14.md ให้ในรอบถัดไปตามโครงนี้ 100% พร้อม CI/AI integration.

ต้องการให้ patch ลงไฟล์เลยไหมครับ?