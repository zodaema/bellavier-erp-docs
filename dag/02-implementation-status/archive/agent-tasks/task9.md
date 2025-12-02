Task 9 – Serial Enforcement Stage 2: Tenant Resolution & Integration Test Hardening

เป้าหมายหลัก:
	1.	ทำให้ SerialHealthService ใช้งานได้เสถียรในทุก context (prod, CLI, PHPUnit) โดยไม่พึ่งการหา tenant_id แบบงง ๆ
	2.	ทำให้ HatthasilpaE2E_SerialEnforcementStage2Test รันผ่านครบทั้ง 2 เคส (flag=0 และ flag=1) โดย ไม่ต้อง mark skipped
	3.	ล้าง log พวก “Could not determine tenant_id for job_ticket_id=…” ออกจาก path ปกติ (ให้เหลือเฉพาะกรณี error จริง ๆ)

⸻

1. Problem

1.1 อาการตอนนี้
	•	Unit tests ของ SerialHealthService = ผ่านหมด ✅
	•	Integration test HatthasilpaE2E_SerialEnforcementStage2Test:
	•	testEnforcementFlagOneBlocksOnBlocker() → ผ่าน ✅
	•	testEnforcementFlagZeroDoesNotBlock() → ต้อง mark เป็น skipped เพราะ:
	•	checkJobSerialHealth() พยายาม resolve tenant_id จาก job_ticket / mapping table ใน core DB
	•	แต่ fixture ใน integration test ไม่ได้เซ็ต mapping เหมือน prod → ทำให้ได้ log:
Could not determine tenant_id for job_ticket_id=...
	•	ผลคือ health ไม่ detect anomaly ตามที่ test คาด → assertion fail → ต้อง skip

1.2 ความเสี่ยงถ้าปล่อยไว้
	•	Serial Enforcement Stage 2 ทำงานจริงแล้ว แต่ integration test ฝั่ง flag=0 “ไม่เคย green จริง ๆ” → หนี้ทางเทคนิค / ความไม่สบายใจ
	•	Log “Could not determine tenant_id…” จะโผล่แม้ในกรณีที่เรารู้อยู่แล้วว่าใช้งานใน tenant DB ที่ถูกต้อง (เช่น CLI, PHPUnit, manual tools)
	•	Developer คนอื่นที่จะมาดูทีหลังจะงงว่า SerialHealth ต้องการ multi-tenant mapping เสมอ ทั้งที่ในหลาย context เรารู้ tenant แล้ว

⸻

2. Objectives
	1.	Refactor Tenant Resolution Logic ใน SerialHealthService ให้:
	•	ถ้า constructor ได้ $tenantDb เข้ามาแล้ว → สามารถทำงานได้เต็มรูปแบบ โดยไม่จำเป็นต้อง resolve tenant จาก job_ticket_id
	•	ลด log noisy "Could not determine tenant_id..." ใน path ปกติ
	2.	ทำ Integration Test ให้ Deterministic:
	•	testEnforcementFlagZeroDoesNotBlock() ต้อง:
	•	สร้าง anomaly แบบ BLOCKER ได้จริง (duplicate serial / multiple tokens)
	•	health check เห็น anomaly แน่นอน
	•	Assert ว่า flag=0 → ไม่ block
	3.	ไม่แตะ logic enforcement ที่ทำไว้ใน Task 8
ไม่เปลี่ยน behavior production ที่ confirm แล้วว่าถูก

⸻

3. Scope

3.1 Files ใน Scope
	•	source/BGERP/Service/SerialHealthService.php
	•	tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php
	•	(optionally) docs/dag/agent-tasks/task8_SERIAL_ENFORCEMENT_STAGE2.md และ/หรือ DAG_IMPLEMENTATION_ROADMAP.md สำหรับอัปเดตสถานะ

3.2 ข้อจำกัด
	•	❌ ห้าม เปลี่ยน signature ของ public methods (checkJobSerialHealth, evaluateGateForJob)
	•	❌ ห้าม เปลี่ยน logic ที่ใช้ใน Task 8 enforcement (เฉพาะเพิ่ม / refine ภายใน SerialHealthService)
	•	❌ ห้าม ALTER TABLE / schema จริง
	•	✅ ทำได้: เพิ่ม private helpers, ปรับ internal flow, เพิ่ม test helpers/fixtures

⸻

4. Implementation Plan

4.1 Refactor: Tenant Resolution Strategy

เป้าหมาย: ให้ SerialHealth มีโหมดทำงาน 2 แบบ:
	1.	Tenant-aware mode (multi-tenant core)
	•	ใช้เมื่อ tenantDb = null
	•	ต้อง resolve tenant จาก job_ticket_id → เลือก tenant DB → ค่อย query serial tables
	2.	Direct-tenant mode (single tenant already known)
	•	ใช้เมื่อ tenantDb ถูกส่งเข้ามาใน constructor
	•	ไม่ต้อง resolve tenant เพิ่ม → ทำงานกับ $this->tenantDb ตรง ๆ

ขั้นตอน:
	1.	เพิ่ม private helper เช่น:

private function resolveTenantDbForJob(int $jobTicketId): ?\mysqli
{
    // ถ้ามี $this->tenantDb แล้ว → ใช้ตัวนี้เลย
    if ($this->tenantDb instanceof \mysqli) {
        return $this->tenantDb;
    }

    // ถ้าไม่มี → ใช้ logic เดิมหา tenant_id + tenantDb จาก coreDb
    // ถ้า fail → return null (แล้วค่อย log / fail-open)
}


	2.	ใน checkJobSerialHealth():
	•	แทนที่จะ resolve tenant_id ทุกครั้ง ให้เรียก resolveTenantDbForJob($jobTicketId)
	•	ถ้าได้ $tenantDb → ดำเนินการต่อปกติ
	•	ถ้าไม่ได้:
	•	log แบบ soft:
"[SerialHealth] resolveTenantDbForJob returned null for job_ticket_id=..."
	•	แล้ว fail-open: return structureที่ issues=[], ok=true เพื่อให้ Stage 2 ตัดสินใจเองว่าจะ block หรือไม่ (ตาม Task 8)
	3.	ปรับ log เดิม:
	•	จาก Could not determine tenant_id for job_ticket_id=...
	•	เป็น log ใหม่ที่สื่อว่า “ใช้ direct-tenant mode อยู่ / fail-open by design”
ให้ชัดเจนว่าไม่ใช่ error severity สูง

4.2 Make Stage2 Integration Tests Deterministic

ไฟล์: tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php

เป้าหมาย: ให้ทั้ง 2 test รันผ่าน (หรืออย่างน้อยไม่ skip) โดยไม่ต้องพึ่ง data ปริศนา

4.2.1 Helper สำหรับสร้าง BLOCKER anomaly
เพิ่ม private helper เช่น:

private function seedDuplicateSerialAnomaly(\mysqli $tenantDb, int $jobTicketId): string
{
    // 1) สร้าง serial_code ใหม่นึง
    $serial = 'TEST-SERIAL-' . uniqid();

    // 2) insert ลง serial_registry 2 แถว (ซ้ำ serial_code, ต่าง dag_token_id)
    // 3) สร้าง 2 tokens ใน dag_token (หรือ table ที่เกี่ยว) สำหรับ job_ticket นี้
    // 4) map serial_code เดียวกันให้กับ 2 tokens นั้น (ผ่าน token_serials หรือ column ที่ใช้จริง)
    //
    // NOTE: ตรงนี้ให้ใช้โครงสร้าง table/column ตามระบบจริง
    // (ระบุใน comment ว่าตัวอย่างเป็นแค่ pseudo-SQL)
    
    return $serial;
}

Idea: ให้ helper นี้ สร้าง condition ที่ SerialHealth อ่านแล้วเห็น ISSUE_SERIAL_MULTIPLE_TOKENS แน่นอน

4.2.2 Test: testEnforcementFlagZeroDoesNotBlock()
Flow ที่ควรเป็น:
	1.	เตรียม environment:
	•	สร้าง job_ticket ปกติใน tenant DB (ใช้ helper เดิมที่มีอยู่)
	•	เรียก seedDuplicateSerialAnomaly() ให้ job นี้
	•	เปิด flag: FF_SERIAL_ENFORCE_STAGE2 = 0 (ผ่าน FeatureFlagService / seed table)
	2.	เรียก flow ที่ใกล้เคียงของจริงที่สุด เช่น:
	•	call JobCreationService::createFromBinding() หรือ
	•	call HTTP-like layer ผ่าน dag_token_api.php ตามที่ test ใช้ตอนนี้
	3.	Assert:
	•	Response ok === true (ไม่ block)
	•	แต่ log / หรือผลการเรียก evaluateGateForJob (ถ้า test ใช้ตรง ๆ) ต้องมี:
	•	has_blocker === true
	•	issues มีอย่างน้อย 1 issue ที่ severity = BLOCKER

จุดสำคัญ: เคส flag=0 ต้องยืนยัน “เกตเห็น blocker จริง” ไม่ใช่แค่ “ไม่ block เพราะไม่เห็นอะไรเลย”

4.2.3 Test: testEnforcementFlagOneBlocksOnBlocker()
	•	ใช้ seedDuplicateSerialAnomaly() ตัวเดียวกัน (reuse data)
	•	ตั้ง FF_SERIAL_ENFORCE_STAGE2 = 1
	•	รัน flow เดิม
	•	Assert:
	•	Response ok === false
	•	error === 'ERR_SERIAL_HEALTH_BLOCKED'
	•	issues มีรายการที่ severity === 'BLOCKER'

เนื่องจากเคสนี้คุณ confirm แล้วว่า logic ถูก อาจแค่ปรับให้ใช้ helper ใหม่เพื่อให้ fixture ชัดขึ้น

4.3 Docs & Roadmap
	1.	แก้ docs/dag/agent-tasks/task8_SERIAL_ENFORCEMENT_STAGE2.md:
	•	อัปเดตส่วน “Integration Tests” ให้ status เป็น “2 tests passing” (เมื่อทำ Task 9 เสร็จ)
	•	ลบคำอธิบายเรื่อง skip ออก
	2.	แก้ docs/dag/02-implementation-status/DAG_IMPLEMENTATION_ROADMAP.md:
	•	เพิ่มบรรทัดใน “Recently Completed”:
	•	✅ Task 9: Serial Enforcement Stage 2 – Tenant & Test Hardening
	•	อัปเดต section ของ Serial pipeline ให้แสดงว่า Stage 2 = fully enforced + fully tested

⸻

5. Deliverables
	1.	Code
	•	SerialHealthService::checkJobSerialHealth() ใช้ resolveTenantDbForJob()
	•	resolveTenantDbForJob() implement ตามสองโหมด direct-tenant / tenant-aware
	•	log ใหม่ที่ชัดเจนว่ากำลัง fail-open by design
	•	Helper + fixture ใหม่ใน HatthasilpaE2E_SerialEnforcementStage2Test.php เพื่อสร้าง BLOCKER anomaly
	2.	Tests
	•	tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php
	•	testEnforcementFlagZeroDoesNotBlock() ✅ ผ่าน (ไม่ skip)
	•	testEnforcementFlagOneBlocksOnBlocker() ✅ ผ่าน
	3.	Docs
	•	อัปเดต task8 summary ให้สะท้อนว่า integration tests ทั้งคู่ green
	•	อัปเดต Roadmap ว่า Stage 2 ถือว่า “fully hardened”

⸻

6. Success Criteria

Task 9 ถือว่าสำเร็จเมื่อ:
	•	รันคำสั่ง (หรือใกล้เคียง):

vendor/bin/phpunit tests/Unit/SerialHealthServiceTest.php \
                   tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php \
                   --testdox

ได้ผล:
	•	Unit: OK (8 tests, 54 assertions)
	•	Integration: OK (2 tests, X assertions) ไม่มี FAIL / SKIP

	•	log “Could not determine tenant_id for job_ticket_id=…”
ไม่โผล่ในเคสที่รันบน tenant DB ตรง ๆ (เช่น integration test ปกติ)
	•	Behavior ของ Stage 2 enforcement (flag=0 / flag=1) ยังตรงกับที่ระบุใน Task 8 ทุกประการ