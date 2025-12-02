Task 7 – Time Engine Integration (STITCH First)

เป้าหมายหลัก

ให้ behavior STITCH:
	•	stitch_start
	•	stitch_pause
	•	stitch_resume

เชื่อมกับ Time Engine จริง (work session) โดยยัง:
	•	❌ ไม่ยุ่ง DAG routing (ไม่ย้าย node)
	•	❌ ไม่ยุ่ง component binding
	•	❌ ไม่แตก / merge token
	•	✅ โฟกัสแค่ “เวลาทำงานของช่าง” ต่อ token/node

⸻

ขอบเขต (Scope)

IN Scope
	1.	เชื่อม BehaviorExecutionService → Time Engine service เดิม (เช่น TokenWorkSessionService / WorkSessionTimeEngine ถ้ามีแล้ว)
	2.	รองรับ use-case:
	•	เริ่มงานเย็บ (start)
	•	หยุดชั่วคราว (pause)
	•	กลับมาทำงานต่อ (resume)
	3.	ป้องกัน case เสีย:
	•	1 คนห้ามมี 2 งาน active พร้อมกัน
	•	กด start ซ้ำบน token เดิมแบบผิดจังหวะ → handle gracefully
	4.	Log เวลาทำงานลงตาราง session เดิม (ไม่สร้างตารางใหม่ถ้าไม่จำเป็น)
	5.	Error handling แบบสวย ๆ ผ่าน TenantApiOutput::error()

OUT of Scope (ห้ามแตะใน Task 7)
	•	Routing ระหว่าง nodes ทั้งหมด
	•	Behavior อื่น (CUT / EDGE / QC) ยังเป็น log-only
	•	UI behavior panel (ไม่เปลี่ยน layout / payload)
	•	Token status enum (ยังคง active/completed/scrapped)

⸻

แนวคิดสถาปัตยกรรม

ตอนนี้ข้อมูลเรามี:
	•	Token = flow_token
	•	Node = routing_node
	•	Behavior action = STITCH (start/pause/resume)
	•	BehaviorExec → BehaviorExecutionService

สิ่งที่จะเพิ่มใน Task 7:
	1.	Work Session Service (ถ้ามีแล้วให้ใช้, ถ้ายังไม่มีให้สร้าง)
	•	ตัวอย่างชื่อ: BGERP\Dag\TokenWorkSessionService
	•	ทำหน้าที่:
	•	เปิด session ใหม่ (start)
	•	ปิดหรือ pause session ปัจจุบัน
	•	Resume session เดิม
	2.	BehaviorExecutionService จะเรียก service นี้ใน handleStitch()
แล้ว:
	•	start/resume → เปิด session หรือ mark active
	•	pause → ปิด session / mark paused
	•	เก็บเวลาจริงด้วย time engine (timestamp now)
	3.	เก็บข้อมูลในตาราง (ที่น่าจะมีอยู่แล้ว หรือสร้างใหม่):
	•	แนะนำ schema session (ถ้ายังไม่มี):

token_work_session
--------------------------------
id_session       (PK, AI)
id_token         (FK -> flow_token)
id_node          (FK -> routing_node)
id_worker        (nullable, หรือ map จาก session user_id)
status           ENUM('active','paused','completed')
started_at       DATETIME
paused_at        DATETIME NULL
resumed_at       DATETIME NULL
completed_at     DATETIME NULL
total_seconds    INT (optional, อัปเดตตอน pause/complete)
created_at       DATETIME
updated_at       DATETIME



⸻

พฤติกรรมที่ต้องได้ (STITCH Behavior)

1) stitch_start

เงื่อนไข:
	•	context ต้องมี token_id, node_id
	•	ตรวจว่าช่างคนนี้ (จาก session) มี session active อื่นอยู่หรือไม่
	•	ถ้ามี → คืน error (หรือบังคับ pause auto ในอนาคต แต่ตอนนี้ให้ error ก่อนจะปลอดภัยกว่า)

Flow:
	1.	Validate context
	2.	ปิด session อื่นที่ “ผิดปกติ” ถ้าเรายอม auto-fix (optional)
	3.	สร้าง record ใหม่ใน token_work_session:
	•	status = active
	•	started_at = NOW()
	•	id_token / id_node ตาม context
	•	id_worker จาก session
	4.	Log ลง dag_behavior_log เช่นเดิม
	5.	คืนค่า:

{
  "ok": true,
  "effect": "session_started",
  "session_id": 123,
  "log_id": 456
}



⸻

2) stitch_pause

เงื่อนไข:
	•	ต้องมี session active สำหรับ token/node นี้อยู่
	•	ถ้าไม่มี → คืน error no_active_session_for_token

Flow:
	1.	หา token_work_session ที่:
	•	id_token = context.token_id
	•	status = ‘active’
	•	(optional) id_worker = current user
	2.	อัปเดต:
	•	status = ‘paused’
	•	paused_at = NOW()
	•	total_seconds += NOW() - started_at (หรือถ้าเก็บ incremental)
	3.	Log ลง dag_behavior_log เช่นเดิม
	4.	คืนค่า:

{
  "ok": true,
  "effect": "session_paused",
  "session_id": 123,
  "log_id": 457
}



⸻

3) stitch_resume

เงื่อนไข:
	•	ต้องมี session ที่ paused สำหรับ token/node นี้
	•	ถ้ามี active อยู่แล้ว → อาจให้ effect: 'already_active'

Flow:
	1.	หา session ที่:
	•	id_token = context.token_id
	•	status = ‘paused’
	2.	อัปเดต:
	•	status = ‘active’
	•	resumed_at = NOW()
	•	(อาจ reset started_at ใหม่สำหรับรอบนี้ ถ้าเก็บแบบช่วง)
	3.	Log ลง dag_behavior_log
	4.	คืนค่า:

{
  "ok": true,
  "effect": "session_resumed",
  "session_id": 123,
  "log_id": 458
}



⸻

Safety Rails สำหรับ Task 7
	•	❗ ห้ามเปลี่ยนโครงสร้าง payload จาก frontend (behavior_execution.js)
	•	❗ ห้ามเปลี่ยน flow_token.status เป็น state แปลก ๆ (ใช้เฉพาะ ‘active’ ตามเดิม)
	•	❗ ห้ามโยน exception หลุดออกจาก dag_behavior_exec.php โดยไม่จับ
	•	❗ ถ้าตาราง token_work_session ไม่มีในบาง tenant ให้ fail แบบนิ่ม ๆ:
	•	log error
	•	คืน error JSON ที่เข้าใจได้
	•	✅ ใช้ TenantApiOutput::error() / TenantApiOutput::success() เท่านั้น
	•	✅ ควรมี unit-ish หรือ manual test case document เหมือน Task 6

⸻