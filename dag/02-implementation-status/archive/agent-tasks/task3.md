### GOAL

ตอนนี้ Integration Test ยังไม่ผ่าน:

1) vendor/bin/phpunit tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php --testdox --verbose

ผลลัพธ์:

- Hatthasilpa E2E_Work Queue Filter
  ✘ Work queue filters strictly
    ┐
    ├ get_work_queue should succeed
    ├ Failed asserting that false is true.
    ╵ tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php:270

2) vendor/bin/phpunit tests/Integration/HatthasilpaE2E_CancelRestartSpawnTest.php --testdox --verbose

- Hatthasilpa E2E_Cancel Restart Spawn
  ↩ Cancel restart creates new instance and no reuse
    ┐
    ├ start_job did not create any instance in this environment
    ┴ (Skipped 1)

**เป้าหมายตอนนี้มี 2 ข้อ:**

1. แก้ `HatthasilpaE2E_WorkQueueFilterTest` ให้ **ผ่านจริง** (ok=true) ไม่ใช่ผ่านแบบ skip  
2. ยอมรับได้ว่า `HatthasilpaE2E_CancelRestartSpawnTest` ยัง Skip ได้ ตาม guard เดิม (ยังไม่ต้องไปยุ่ง)

ให้โฟกัสข้อ (1) ก่อน จนกว่าจะรันแล้วเขียวจริง

---

### SCOPE

ห้ามไปยุ่งสิ่งเหล่านี้:

- Features serial number / FF_SERIAL_STD_HAT (ถือว่าผ่านแล้ว)
- UnifiedSerialService, SerialManagementService, FeatureFlagService

จำกัด scope แก้เฉพาะ:

- API: `source/hatthasilpa_jobs_api.php` → action `get_work_queue`
- Service ที่ใช้โดย action นี้ (ถ้ามี): เช่น `HatthasilpaWorkQueueService` หรือ logic query ภายใน
- Test: `tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php` (เฉพาะในส่วนที่จำเป็น ถ้าตัวเทสเขียนผิดจาก spec)

---

### STEP 1: ทำความเข้าใจ TEST ก่อน (Canonical Spec)

1. เปิดไฟล์ `tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php`
   - อ่านทุก test method ในไฟล์นี้ โดยเฉพาะ method ที่บรรทัด ~270 (ที่ error ชี้)
   - สรุปให้ได้ว่า:

     - มัน seed อะไรบ้าง (job, instance, node, tokens, status, node type ฯลฯ)
     - เรียก API `get_work_queue` ด้วย parameters อะไร (tenant/org, filters, pagination)
     - test EXPECT ว่าอะไร คือ definition ของ “Work queue filters strictly”

2. จบ STEP 1 ให้สรุปสั้น ๆ เป็น comment ในไฟล์ test หรือใน docs:
   - “Spec ของ get_work_queue ตามไฟล์นี้คืออะไร”
   - เช่น: Work queue ต้องแสดงเฉพาะ tokens ที่:
     - status = ready
     - อยู่บน node ที่ operable
     - instance active, ไม่ archived
     - …ฯลฯ

**ห้ามเปลี่ยน spec ของ test ก่อนที่จะสรุปความเข้าใจให้ครบ**

---

### STEP 2: ตรวจฝั่ง API `get_work_queue` ว่าทำอะไรจริง ๆ

1. เปิด `source/hatthasilpa_jobs_api.php` แล้วหา action:

   ```php
   case 'get_work_queue':
       ...

	2.	อ่าน logic ใน block นี้ทั้งหมด:
	•	query ฝั่ง DB ดึงจาก table อะไรบ้าง
	•	flow_token
	•	job_graph_instance
	•	job_node_instance
	•	routing_node / dag_node
	•	อื่น ๆ
	•	filter เงื่อนไขอะไรบ้าง เช่น:
	•	flow_token.status = 'ready'
	•	job_graph_instance.status <> 'archived'
	•	filter ตาม node type, workcenter, ฯลฯ
	•	มี rate limiter / permission / org check หรือไม่
	•	มีเงื่อนไขใดที่ทำให้ "ok" => false เช่น:
	•	invalid parameters
	•	schema guard
	•	exception แล้ว json_error()
	3.	ใส่ debug log ชั่วคราว (ถ้ายังไม่มี) ก่อน json_success / json_error:

error_log('[hatthasilpa_jobs_api][get_work_queue] response payload: ' . json_encode($responsePayload, JSON_UNESCAPED_UNICODE));

หรืออย่างน้อย log ว่า:

error_log(sprintf(
    '[hatthasilpa_jobs_api][get_work_queue] done: ok=%s, total=%s, app_code=%s',
    isset($out['ok']) ? var_export($out['ok'], true) : 'null',
    $out['data']['total'] ?? 'null',
    $out['app_code'] ?? 'null'
));



⸻

STEP 3: รัน TEST พร้อมเก็บ LOG เพื่อตาม root cause
	1.	รัน:

vendor/bin/phpunit tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php --testdox --verbose


	2.	ดู error_log ที่เกิดขึ้นระหว่าง test:
	•	หา log จาก hatthasilpa_jobs_api และ dag_token_api
	•	ดูว่าตอน get_work_queue มัน:
	•	ตอบ ok=false เพราะอะไร
	•	app_code หรือ error message คืออะไร (ถ้ามี)
	•	query main ถูก execute จริงไหม หรือ schema guard ทำให้มัน return error
	3.	สรุป root cause ให้ชัดเจนก่อนแก้:
	•	ตัวอย่าง root cause ที่เป็นไปได้:
	•	a) test สร้าง token เป็น status 'ready' แต่ API filter 'in_queue' หรือ field คนละชื่อ
	•	b) API require column บางตัวที่ dev schema ไม่มี แล้ว guard ตอบ error
	•	c) API ตีความว่า “ถ้าไม่มี records เลย → ok=false” ขณะที่ test spec บอก “ควร ok=true แต่ list ว่างได้”
	•	d) permission / org / member ไม่ตรงกับสิ่งที่ test set

⸻

STEP 4: แก้ให้สอดคล้อง “SPEC จาก TEST”

หลังจากรู้ root cause แล้ว ให้แก้โค้ดภายใต้หลัก:
	1.	ถ้า test ถูก และ API ผิด spec → แก้ API
	•	ปรับ logic get_work_queue ให้:
	•	"ok" => true เสมอถ้ารัน query สำเร็จ (แม้จะไม่มี records)
	•	"ok" => false เฉพาะกรณี error จริง ๆ เช่น invalid input / SQL error / exception
	•	ให้แน่ใจว่า:
	•	ถ้า work queue ไม่มี token ที่ match เงื่อนไข → ควรตอบ:

{"ok":true, "data":{"items":[],"total":0}, ...}


	2.	ถ้า API เดิมเป็น canonical spec ที่เราใช้จริงใน UI แล้ว test เขียน assumption ผิด → แก้เฉพาะ test ให้ตรง spec
	•	เช่น ถ้าใน UI เราตั้งใจว่า “ถ้าไม่มีงานเลย → ok=true, data.empty” แต่ test ไป expect อย่างอื่น
	•	ในกรณีนี้ให้แก้ assertion ในบรรทัด ~270 ให้ match behavior ที่ใช้งานจริง
	3.	ห้ามทำ fast-fix แบบ force:
	•	ห้ามใส่ return json_success() โดยไม่สน query
	•	ห้าม hard-code "ok" => true เพื่อให้ test ผ่าน แต่ behavior พัง

ต้องผูกการแก้กับ root cause เท่านั้น

⸻

STEP 5: ยืนยันผลด้วย PHPUnit

หลังแก้:
	1.	รัน:

vendor/bin/phpunit tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php --testdox --verbose
vendor/bin/phpunit tests/Integration/HatthasilpaE2E_CancelRestartSpawnTest.php --testdox --verbose


	2.	เงื่อนไขสำเร็จ:
	•	HatthasilpaE2E_WorkQueueFilterTest → OK (1 test, 3 assertions, 0 failures)
	•	HatthasilpaE2E_CancelRestartSpawnTest → ยัง Skip ได้เหมือนเดิม (หรือ OK ก็ยิ่งดี แต่ไม่บังคับรอบนี้)
	3.	เขียน summary สั้น ๆ:
	•	root cause เดิมคืออะไร
	•	แก้อะไรใน hatthasilpa_jobs_api.php / test
	•	ตัวอย่าง response get_work_queue หลังแก้ (log หรือ sample JSON)

⸻

OUTPUT ที่ต้องส่งกลับมา
	1.	Diff ของไฟล์ที่แก้ (อย่างน้อย):
	•	source/hatthasilpa_jobs_api.php
	•	อาจจะมี tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php ถ้าจำเป็น
	2.	ผล PHPUnit run ของ 2 ไฟล์ (copy log ที่แท้จริง)
	3.	คำอธิบายสั้น ๆ ว่าตอนนี้ “Work queue filters strictly” หมายถึงอะไรในแง่ business logic + หมายความว่าอะไรใน UI จริง

ห้ามสรุปว่าทุกอย่างผ่านแล้ว ถ้า phpunit ยังแดงหรือยัง skip เกินจากนี้