🧠 Prompt สำหรับ AI Agent — Task 5: Serial Number Hardening Layer (Stage 1 – Detection & Observability)

⚠️ สำคัญมาก
	•	ห้าม copy โค้ดตัวอย่างจาก prompt นี้ไปวางตรง ๆ โดยไม่เปิดไฟล์จริง
	•	โค้ดทุกบล็อคด้านล่างคือ ตัวอย่าง / pseudo-code เท่านั้น
	•	คุณต้อง open ไฟล์จริง ตรวจ context จริง แล้วค่อย modify ให้เข้ากับโครงสร้างปัจจุบันของโปรเจกต์

⸻

🎯 เป้าหมาย Task 5

ทำ Serial Number Hardening Layer – Stage 1 (Detection & Observability เท่านั้น)
	1.	เพิ่ม “ชั้นตรวจสอบความปลอดภัย” ให้กับระบบ serial:
	•	ตรวจจับ serial ซ้ำ / ผิด format / ผูกกับ token ผิด
	•	ไม่เปลี่ยนพฤติกรรมหลักของระบบ (ยังไม่ถึงขั้น block ระบบ)
	2.	เพิ่ม tools + logs สำหรับตรวจสุขภาพของ serial:
	•	ตรวจฐานข้อมูล serial_registry, job_ticket_serial, ความสัมพันธ์กับ flow_token
	•	สามารถรันแบบ diagnostic (CLI) ดูผลรวม / รายการที่ผิดปกติได้
	3.	เพิ่ม tests สำหรับ layer นี้:
	•	Unit / Integration ที่ยืนยันว่าการตรวจจับทำงานถูกต้อง
	•	ไม่มี regression กับของเดิม เช่น UnifiedSerialServiceTest, E2E Hatthasilpa

Stage นี้เน้น “ตรวจจับ + log + tools” ยังไม่เปิดใช้ “Danger Mode” (บล็อกระบบ)
Enforcement (เช่น โยน exception, ปิดการ assign token) ให้เก็บไว้เป็น Task ถัดไป

⸻

🔎 Context ที่ต้องอ่านก่อนแก้

โปรดเปิดอ่านไฟล์เหล่านี้ก่อนทำงาน (อย่าเดาโครงสร้างเอง):
	1.	Serial Core
	•	source/BGERP/Service/UnifiedSerialService.php
	•	source/BGERP/Service/SerialManagementService.php
	•	source/BGERP/Service/JobCreationService.php
	2.	Entry Points ที่เกี่ยวกับ serial
	•	source/hatthasilpa_job_ticket.php
	•	source/dag_token_api.php
	3.	Tests ที่เกี่ยวข้อง
	•	tests/Unit/UnifiedSerialServiceTest.php
	•	tests/Integration/HatthasilpaE2E_SerialStdEnforcementTest.php
	•	E2E อื่น ๆ ที่แตะ serial ถ้ามี
	4.	Schema / DB
	•	ตาราง serial_registry
	•	ตาราง job_ticket_serial
	•	ตาราง token ที่ผูก serial (เช่น flow_token.serial_number, ฯลฯ)
	5.	เอกสาร
	•	docs/dag/master/*.md ที่พูดถึง serial
	•	docs/dag/agent-tasks/task4_OPERATOR_AVAILABILITY_SCHEMA.md (ดู pattern doc & summary)

⸻

🧩 Scope งาน (Stage 1 – Detection Layer)

1) เพิ่ม Serial Health Checker / Conflict Detector (Service ใหม่)
สร้าง class ใหม่ (ชื่อแนะนำ):
	•	BGERP\Service\SerialHealthService
	•	ใช้ core DB (เหมือน UnifiedSerialService)
	•	เน้น อ่าน / ตรวจสอบ / log เท่านั้น — ห้ามเปลี่ยน state (ยกเว้น log)

ฟังก์ชันอย่างน้อย:

// ตัวอย่างชื่อและ signature — ปรับตามโครงสร้างจริง
public function checkJobSerialHealth(int $jobTicketId): array;
public function checkTenantSerialHealth(int $tenantId, int $limit = 1000): array;

สิ่งที่ควรตรวจใน checkJobSerialHealth (ตัวอย่าง logic):
	•	นับ serial ที่อยู่ใน:
	•	job_ticket_serial สำหรับ $jobTicketId
	•	serial_registry ที่ผูกกับ job/ticket นั้น (ถ้ามี field อ้างอิง)
	•	serial ที่ถูกผูกกับ token ใน flow_token (หรือ table ที่จริงใช้)
	•	หา anomalies เช่น:
	•	serial ซ้ำกันใน serial_registry (serial_code เดียวกันหลายแถว สำหรับ tenant เดียวกัน)
	•	serial อยู่ใน serial_registry แต่ไม่มีใน job_ticket_serial ทั้งที่ควรมี
	•	token มี serial แต่ serial ไม่อยู่ใน serial_registry
	•	serial หนึ่งอันถูกผูกกับหลาย token พร้อมกัน
	•	return ผลแบบ structured เช่น:

[
  'ok' => true/false,
  'job_ticket_id' => 631,
  'counts' => [
      'registry' => 30,
      'job_ticket_serial' => 30,
      'tokens_with_serial' => 30,
  ],
  'issues' => [
      // array ของ anomaly objects
      ['type' => 'DUPLICATE_SERIAL_IN_REGISTRY', 'serial_code' => '...', 'rows' => 2 ],
      ['type' => 'TOKEN_WITHOUT_REGISTRY_ENTRY', 'token_id' => 1234, 'serial_code' => '...' ],
      // ...
  ],
]

⚠️ โค้ดข้างบนคือ ตัวอย่างโครงสร้าง response เท่านั้น
โปรดดูโครงสร้างตารางจริงและปรับให้สอดคล้อง

2) Hook จุดเรียก SerialHealthService แบบ “Soft”
เพิ่ม hook ที่จุดสำคัญ แต่ ทำแบบ soft-only:
	•	ใน JobCreationService::createFromBinding() (หลังจาก pre-generate + link serial เสร็จ)
	•	(ถ้าจำเป็น) ในจุดอื่นเช่น generateAdditionalSerialsForJob หรือ handler คล้าย ๆ กัน

ตัวอย่างแนวคิด:

try {
    $health = $serialHealthService->checkJobSerialHealth($jobTicketId);
    if (!($health['ok'] ?? true)) {
        error_log("[SerialHealth] Job {$jobTicketId} has anomalies: " . json_encode($health['issues']));
    }
} catch (\Throwable $e) {
    // ห้ามให้ health check ทำให้ flow หลักล้ม
    error_log("[SerialHealth] ERROR while checking job {$jobTicketId}: " . $e->getMessage());
}

⚠️ ตรงนี้เป็น ตัวอย่าง pattern เท่านั้น
โปรดเช็ค wiring ของ service, DI, constructor pattern ของ BGERP\Service ก่อนแก้จริง

สำคัญ:
	•	ยัง ไม่ ให้ health check โยน exception ไปหยุดงานหลัก
	•	ถ้าเจอปัญหา ให้ log เตือน, แต่ ok จาก API/Service ยังต้องเป็น true เช่นเดิม

3) Diagnostic CLI Script
สร้างไฟล์ใหม่ใน tools/ (pattern เดิมเหมือน tools/serial_registry_check.php):

เช่น:
	•	tools/serial_health_check.php

ฟังก์ชัน:
	•	รับ parameter เช่น:
	•	--job=631 → เรียก checkJobSerialHealth(631) แล้ว print summary + issues
	•	--tenant=2 → เรียก checkTenantSerialHealth(2) แล้วสรุป aggregate
	•	แสดงผลแบบอ่านง่ายใน CLI:
	•	รวม count ต่าง ๆ
	•	แสดงรายการ anomalies (limit: เช่น 100 รายการ เพื่อไม่ให้ยาวเกิน)

Pseudo:

$options = getopt('', ['job::', 'tenant::', 'limit::']);

// bootstrap core_db(), autoload, etc.

$service = new SerialHealthService($coreDb);

if (!empty($options['job'])) {
    $result = $service->checkJobSerialHealth((int)$options['job']);
    // echo summary + issues
}

⚠️ อย่าลืมใช้ bootstrap pattern เดียวกับ tools ตัวอื่นใน repo
อ่านไฟล์ tools ที่มีอยู่ก่อน แล้วค่อย copy pattern

4) Logs & Observability
เพิ่ม log แบบ ไม่รก แต่มีประโยชน์ เช่น:
	•	เมื่อเจอ anomaly ใน health check:
	•	[SerialHealth][Job:631] DUPLICATE_SERIAL_IN_REGISTRY code=... rows=2
	•	[SerialHealth][Job:631] TOKEN_WITHOUT_REGISTRY_ENTRY token=... serial=...

อย่า log ทุกเคสปกติ (จะ spam log)
Log เฉพาะตอนพบ issues หรือ error ภายใน health check เอง

⸻

🧪 Tests ที่ต้องเพิ่ม
	1.	Unit Tests สำหรับ SerialHealthService

สร้างไฟล์ใหม่ เช่น:
	•	tests/Unit/SerialHealthServiceTest.php

เคสอย่างน้อย:
	•	job ปกติ (ไม่มี anomaly) → ok=true, issues=[]
	•	job มี serial ซ้ำใน serial_registry → ok=false และมี issue type DUPLICATE_SERIAL_IN_REGISTRY
	•	job มี token ผูก serial ไม่อยู่ใน serial_registry → issue type TOKEN_WITHOUT_REGISTRY_ENTRY

⚠️ ถ้าใน environment test ไม่มี schema เต็ม ให้ใช้ pattern เดียวกับ E2E tests อื่น ๆ:
	•	เช็ค schema ก่อน (tableHasColumns)
	•	ถ้าไม่พร้อม → mark test เป็น skipped

	2.	Integration / E2E Light

อาจเพิ่ม test เบา ๆ เช่น:
	•	ใช้ flow ที่มีอยู่แล้ว (เช่น create job + spawn token)
	•	เรียก health check แล้ว assert ว่า ok=true สำหรับ case base-line

⸻

🔐 ข้อจำกัด & สิ่งที่ห้ามทำใน Task นี้ (สำคัญมาก)
	•	❌ ห้าม เปลี่ยน behavior ของ UnifiedSerialService::generateSerial() หรือ registerSerial() ในเชิง enforcement (เช่น โยน exception เพิ่ม) นอกเหนือจากที่มีอยู่แล้ว
	•	เราทำ Stage 1 = detection/observability เท่านั้น
	•	❌ ห้าม เพิ่ม UNIQUE constraint หรือ alter schema จริงใน DB (ทั้ง coredb / tenant DB) สำหรับ Task นี้
	•	ถ้าจะเสนอ ให้เขียนลงเอกสาร หรือ comment TODO แทน
	•	❌ ห้าม ทำให้ E2E ปัจจุบันพัง โดยเฉพาะ:
	•	HatthasilpaE2E_SerialStdEnforcementTest
	•	HatthasilpaE2E_WorkQueueFilterTest
	•	❌ ห้าม ปรับ config / feature_flag ที่ไม่เกี่ยวโดยตรง

⸻

📄 Documentation ที่ต้องเพิ่ม

สร้างไฟล์ใหม่:
	•	docs/dag/agent-tasks/task5_SERIAL_HARDENING.md

ให้สรุป:
	1.	Problem Statement
	2.	What SerialHealthService does
	3.	What anomalies are detected (type list)
	4.	How to run CLI tool (ตัวอย่างคำสั่ง)
	5.	Limitations (Stage 1 = detection only, no enforcement)
	6.	Plan สำหรับ Stage 2 (Danger Mode / enforcement) เป็น TODO

⸻

✅ Definition of Done (DoD) สำหรับ Task 5

Task 5 ถือว่า “เสร็จสมบูรณ์” เมื่อ:
	1.	มี SerialHealthService (หรือชื่อเทียบเท่า) พร้อม functions ตรวจ health ตาม scope
	2.	มี CLI tool tools/serial_health_check.php หรือชื่อใกล้เคียง รันได้จริง
	3.	มี Unit Tests อย่างน้อย 1 ไฟล์ + ผ่าน (หรือ skip correct ตาม schema)
	4.	E2E / Integration เดิมทั้งหมด:
	•	ยังคงผ่าน หรือ skip เฉพาะที่ถูกออกแบบให้ skip
	5.	Log แสดง anomaly ได้จริงเมื่อจำลอง case ผิดปกติ
	6.	มี doc task5_SERIAL_HARDENING.md สรุปงาน + วิธีใช้

⸻

ถ้าคุณอ่านจบและเข้าใจแล้ว
ให้เริ่มจาก:
	1.	เปิดไฟล์ serial services ที่เกี่ยวข้องทั้งหมด
	2.	Sketch design ของ SerialHealthService บนกระดาษ/ใน comment ก่อน
	3.	ค่อยลงมือ implement แบบค่อยเป็นค่อยไป + รัน PHPUnit เป็นระยะ