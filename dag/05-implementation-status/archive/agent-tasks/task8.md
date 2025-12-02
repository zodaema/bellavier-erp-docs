🎯 Task ถัดไป: Task 8 – Serial Enforcement Stage 2 Gate

ตอนนี้สภาพระบบคือ:
	•	Serial ถูก hardened แล้ว (format + checksum)
	•	มี SerialHealthService ตรวจ anomaly ได้ (Stage 1: detection only)
	•	มี CLI + unit test ครอบ

สิ่งที่ยัง “ขาด” คือ ชั้น Gate ที่เอา health result ไปตัดสินใจจริง:

“ถ้า serial ecosystem ของ job นี้เริ่มเพี้ยน → จะยอมให้ spawn / เริ่มงานต่อไหม
แล้วกฎนี้ต้องสวิตช์ on/off ได้ด้วย feature flag”

Scope หลักของ Task 8
	1.	เพิ่ม Severity ให้ SerialHealthService
	•	map issue type → WARNING / BLOCKER
เช่น:
	•	BLOCKER: duplicate serial, serial ผูกกับหลาย token, format violation ฯลฯ
	•	WARNING: serial ใน registry แต่ไม่ผูก job, serial job ที่ยังไม่ spawn ครบ เป็นต้น
	2.	เพิ่ม Helper แบบ Gate ใน SerialHealthService
	•	input: job_ticket_id + phase (pre_start / in_production)
	•	output: has_blocker, has_warning, issues[] (แนบ severity ไปด้วย)
	3.	Hook จุดตัดสินใจ
	•	ใน JobCreationService::createFromBinding()
หลังสร้าง serial + token เสร็จ เรียก SerialHealthService:
	•	ถ้า FF_SERIAL_ENFORCE_STAGE2 = 0 → log อย่างเดียว (เหมือนเดิม)
	•	ถ้า FF_SERIAL_ENFORCE_STAGE2 >= 1 และพบ BLOCKER → block + ส่ง error กลับแบบ JSON ที่อ่านง่าย
	•	ใน dag_token_api.php (เช่น handleTokenSpawn / cancel+restart ที่ spawn token):
	•	หลัง / ก่อน spawn token เรียก health check
	•	ถ้า flag เปิด + มี BLOCKER → return ok=false, error='ERR_SERIAL_HEALTH_BLOCKED', issues=[…]
	4.	ใช้ Feature Flag คุม
	•	FF_SERIAL_ENFORCE_STAGE2
	•	0 = detection only (default สำหรับทุก tenant ตอนนี้)
	•	1 = block เฉพาะ BLOCKER
	•	Fail-open เสมอถ้า:
	•	flag อ่านไม่ได้
	•	SerialHealthService ขว้าง exception เอง
	•	สำหรับ test ค่อยเปิด flag เฉพาะ scenario ที่เราทดสอบ enforcement
	5.	Test ที่ควรเพิ่ม
	•	Case A (flag=0):
	•	health พบ BLOCKER แต่ FF_SERIAL_ENFORCE_STAGE2 = 0 → API/Job ยัง ok=true
	•	Case B (flag=1):
	•	health พบ BLOCKER + flag=1 → API/Job ok=false + error code + อย่างน้อยหนึ่ง issue severity=BLOCKER

⸻

สิ่งที่คุณทำต่อได้เลย
	1.	สร้างไฟล์ task spec:
	•	docs/dag/agent-tasks/task8_SERIAL_ENFORCEMENT_STAGE2.md
	•	เอา logic จากที่ผมสรุปข้างบนไปใส่ (คุณมีเวอร์ชันยาวจากข้อความก่อนหน้าแล้ว)
	2.	สั่ง Agent ตาม pattern เดิมว่า:
	•	อย่า regenerate ไฟล์ทั้งก้อน
	•	โค้ดตัวอย่างใน spec เป็นแค่ pseudo / example
	•	ให้รายงาน:
	•	ไฟล์ที่แก้
	•	phpunit commands ที่รัน
	•	log ตัวอย่าง (flag=0 กับ flag=1)
	3.	พอ Agent ทำเสร็จแล้ว ค่อยรัน:

vendor/bin/phpunit tests/Unit/SerialHealthServiceTest.php
vendor/bin/phpunit tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php
vendor/bin/phpunit tests/Integration/HatthasilpaAssignmentIntegrationTest.php --filter Serial

(หรือชื่อ test ที่ Agent เพิ่มเกี่ยวกับ serial enforcement)

---

## 🔍 Definitions & Guardrails (สำคัญมาก)

เพื่อป้องกันการตีความผิดพลาดของ AI Agent และเพื่อให้ Task 8 ไม่สร้าง regression เพิ่มเติม จึงต้องกำหนด Definitions ให้ชัดเจนดังนี้:

### 1) Severity Mapping (Canonical)
- **BLOCKER**
  - SERIAL_DUPLICATE_TOKEN — serial เดียวถูกใช้หลาย token
  - SERIAL_DUPLICATE_REGISTRY — serial เดียวใน registry ซ้ำหลาย row
  - SERIAL_FORMAT_INVALID — ไม่ผ่าน hardened rule
  - SERIAL_NOT_IN_REGISTRY — spawn token แต่ serial ไม่มีใน registry
  - SERIAL_CONFLICT_JOB — serial ของ job อื่นถูกอ้างใน job นี้
- **WARNING**
  - SERIAL_UNUSED — อยู่ใน registry แต่ไม่ถูกใช้
  - SERIAL_NOT_FULLY_SPAWNED — serial job นี้ยังไม่ spawn ครบจำนวน
  - SERIAL_ORPHAN — registry มี serial ที่ไม่ผูก job_ticket_id

### 2) Enforcement Phase Definition
- **phase = pre_start**
  - ใช้ใน JobCreationService::createFromBinding()
  - ใช้หลัง generate serial + before start production
- **phase = in_production**
  - ใช้ใน dag_token_api::handleTokenSpawn(), cancel+restart
  - ใช้หลังเริ่มผลิตแล้ว และ token ใหม่กำลังจะเกิด

### 3) Feature Flag Rules
- FF_SERIAL_ENFORCE_STAGE2 = 0  
  → ระบบจะ “log-only” เสมอ ไม่ block production  
- FF_SERIAL_ENFORCE_STAGE2 = 1  
  → block เฉพาะ BLOCKER เท่านั้น  
- Fail-open เสมอถ้า:
  - flag ไม่พบ
  - flag ไม่ใช่ int
  - SerialHealthService ทำงานแล้ว throw

### 4) Error Response Contract (ต้องคงรูปแบบนี้เท่านั้น)
ถ้า block:
```
{
  "ok": false,
  "error": "ERR_SERIAL_HEALTH_BLOCKED",
  "issues": [
    {
      "code": "SERIAL_DUPLICATE_TOKEN",
      "severity": "BLOCKER",
      "message": "Serial is used by multiple tokens"
    }
  ]
}
```

### 5) Agent Guardrails
- ห้าม regenerate class ทั้งก้อน
- ห้ามเปลี่ยน signature ของ public methods
- Code ตัวอย่างในไฟล์นี้เป็น “pseudo-code” เท่านั้น ห้ามนำไปใช้ตรงๆ
- ต้อง patch เฉพาะจุดที่ระบุ เช่น add block, add mapper, add hook
- Unit test ต้องอ่านง่าย และไม่ควร mock มากเกินจำเป็น

---

## 6) Integration Points (ต้องแก้เฉพาะจุดนี้เท่านั้น)

การ Implement Task 8 ต้องจำกัด scope ไว้ที่จุดต่อไปนี้เท่านั้น:

1. **SerialHealthService**
   - เพิ่ม:
     - severity mapping (function หรือ static map ก็ได้ แต่ให้เป็น private และใช้เฉพาะภายใน service นี้)
     - helper method สำหรับ gate ตาม phase เช่น:
       - `evaluateGateForJob(int $jobTicketId, string $phase): array`
     - ห้าม:
       - เปลี่ยน signature ของ public methods เดิม
       - เปลี่ยน behavior เดิมของ Stage 1 (detection-only)

2. **JobCreationService::createFromBinding()**
   - จุด Hook:
     - หลัง generate serial + spawn token เสร็จ (เหมือน Stage 1 hook ตอนใช้ SerialHealthService ตรวจ log)
   - เพิ่ม:
     - เรียก SerialHealthService gate ด้วย `phase = 'pre_start'`
     - อ่าน feature flag `FF_SERIAL_ENFORCE_STAGE2` จาก **Core DB / tenant scope** ตาม pattern เดิมที่ใช้กับ serial flags อื่น
     - ถ้า flag เปิด + มี BLOCKER → return JSON error ตาม contract ข้อ 4
   - ห้าม:
     - เปลี่ยน payload success ปัจจุบัน (ok=true, data=..., message=...) นอกจากกรณีถูก block จริง ๆ
     - เปลี่ยน flow การสร้าง job_ticket / graph_instance / token เดิม

3. **dag_token_api.php**
   - จุด Hook:
     - ใน `handleTokenSpawn()` และ flow cancel+restart ที่มีการ spawn token ใหม่
   - เพิ่ม:
     - เรียก SerialHealthService gate ด้วย `phase = 'in_production'`
     - อ่าน feature flag `FF_SERIAL_ENFORCE_STAGE2` เช่นเดียวกับใน JobCreationService
     - ถ้า flag เปิด + มี BLOCKER → return JSON error ตาม contract ข้อ 4
   - Fail-open:
     - ถ้า flag อ่านไม่ได้ / service throw → log แล้วปล่อยให้ flow เดิมทำงานต่อ (ไม่ block)

> NOTE: ห้ามสร้าง service ใหม่ที่ซ้ำหน้าที่กับ SerialHealthService หรือ FeatureFlagService

---

## 7) Testing Plan (แนะนำแนวทางเขียน test)

แนวทางการเขียน test สำหรับ Task 8:

1. **Unit Test (SerialHealthService)**  
   - เพิ่ม test สำหรับ:
     - mapping issue type → severity
     - evaluateGateForJob(…, 'pre_start') เมื่อมีเฉพาะ WARNING → `has_blocker = false`, `has_warning = true`
     - evaluateGateForJob(…, 'pre_start') เมื่อมี BLOCKER → `has_blocker = true`
   - ไม่จำเป็นต้อง mock database หนัก ๆ ถ้าสามารถใช้ fixture เดิมที่มีอยู่

2. **Integration Test (JobCreationService / dag_token_api)**  
   - Case A: flag = 0 (detection only)
     - Setup: ใส่ข้อมูลให้มีอย่างน้อยหนึ่ง BLOCKER ใน job นั้น
     - Expect: job/create หรือ token spawn ยัง `ok = true` แต่ error_log มี issue ถูก log
   - Case B: flag = 1 (enforce BLOCKER)
     - Setup: เหมือน Case A แต่เปิด FF_SERIAL_ENFORCE_STAGE2
     - Expect:
       - response `ok = false`
       - `error = 'ERR_SERIAL_HEALTH_BLOCKED'`
       - `issues[0]['severity'] = 'BLOCKER'`

3. **Naming Suggestion**
   - Unit test: `tests/Unit/SerialHealthServiceTest.php` (ขยายไฟล์เดิม)
   - Integration test:  
     - อาจเพิ่มใน `HatthasilpaE2E_WorkQueueFilterTest` หรือสร้างไฟล์ใหม่เช่น `HatthasilpaE2E_SerialEnforcementStage2Test.php`

---

## 8) Non-Goals & Safety Constraints (ห้ามทำ)

เพื่อกัน regression เพิ่มเติม ให้ถือว่า Task 8 **ห้ามทำสิ่งต่อไปนี้**:

1. ห้ามแก้ schema database
   - ห้ามเพิ่ม / ลบ / แก้ column ใน `serial_registry`, `job_ticket_serial`, `flow_token` ฯลฯ
   - งานนี้เป็น logic layer เท่านั้น

2. ห้ามเปลี่ยน behavior ของ TEMP-* serial
   - TEMP-* serial ยังต้องไม่ถูก insert เข้า `serial_registry`
   - Task 8 ไม่ไปแตะ logic TEMP-* ใน dag_token_api

3. ห้ามเปลี่ยน behavior ของ Stage 1
   - SerialHealthService ในโหมด detection-only ต้องทำงานเหมือนเดิมเมื่อ flag ปิด
   - Task 8 แค่เพิ่ม “ชั้น Gate” เมื่อ flag เปิด

4. ห้ามเพิ่ม public API ใหม่แบบไม่จำเป็น
   - ถ้าต้องเพิ่ม method ใหม่ใน SerialHealthService ให้เป็น `public` เฉพาะกรณีจำเป็นจริง ๆ และต้องใช้เฉพาะภายใน ERP (ไม่ expose ออก REST อื่น)

5. ห้ามใช้ `die()` / `exit` ใน flow enforcement
   - ต้องคืนค่า JSON ผ่าน contract เดิมเท่านั้น
   - error / exception ใช้ผ่านกลไกเดิม (throw + try/catch หรือ json_error helper ตามที่ระบบใช้)

6. ห้ามแก้ test เดิมให้ “เงียบ error โดยไม่ตั้งใจ”
   - ถ้าต้องแก้ test ให้รองรับ enforcement ให้:
     - ระบุ scenario ชัดเจน (flag=0 หรือ flag=1)
     - Assert ว่า behavior ถูกต้องตาม phase + flag