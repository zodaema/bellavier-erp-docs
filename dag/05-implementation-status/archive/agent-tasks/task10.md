Task 10 – Operator Availability Console & Enforcement Flag

1. เป้าหมายหลัก
	1.	ให้ระบบรู้จริง ๆ ว่า ช่างคนไหน “พร้อมรับงาน” อยู่บ้าง โดยใช้ตาราง operator_availability (schema is_available + unavailable_until)
	2.	เพิ่มหน้า/จอ “ตั้งค่า Availability ของช่าง” ให้ Admin/Manager ใช้งานง่าย ๆ
	3.	ผูกเข้ากับ AssignmentEngine::filterAvailable() ผ่าน Feature Flag
	•	Flag ปิด → behavior เหมือนเดิม (fail-open ใช้เป็น transition)
	•	Flag เปิด → filter คนที่ “ไม่ว่าง” ออกจาก candidate จริง ๆ

⸻

2. ขอบเขตงาน (Scope)

2.1 Backend – Feature Flag ใหม่
	•	เพิ่ม Feature Flag ใหม่ใน FeatureFlagService / core DB:

ชื่อ flag: FF_HAT_ENFORCE_AVAILABILITY

พฤติกรรม:
	•	ถ้า flag = 0 (default):
	•	filterAvailable() ทำงานเหมือนปัจจุบัน (logic fail-open ที่เราเพิ่งเขียน)
	•	ถ้า flag = 1:
	•	เมื่อมี schema: is_available + unavailable_until + id_member
และมี row ใน operator_availability สำหรับ member บางคน
→ ให้ถือว่า “ไม่มี row = ยังไม่ config” (fail-open)
→ ถ้ามี row แล้ว:
	•	is_available = 1 และ (unavailable_until เป็น NULL หรือผ่านเวลาไปแล้ว) → ถือว่า “ว่าง”
	•	is_available = 0 หรือ unavailable_until > NOW() → ถือว่า “ไม่ว่าง” (ต้องถูก filter ทิ้ง)

จุด Hook:
ใน AssignmentEngine::filterAvailable() ตอน branch:

} elseif ($hasAvailableFlag && $hasUnavailableUntil) {
    // ...
}

ให้:
	1.	อ่านค่า FF_HAT_ENFORCE_AVAILABILITY ตาม tenant (ใช้ tenant code เดิมที่ AssignmentEngine ใช้ใน node_plan auto-assign – เช่น resolve_current_org() หรือ org code จาก DB name)
	2.	ถ้า flag = 0 → ใช้ behavior ปัจจุบัน (มี fail-open 2 ชั้น +ถือว่าไม่มี config = ทุกคนว่าง)
	3.	ถ้า flag = 1 → ปรับให้ “fail-open เฉพาะกรณี table ว่าง / ไม่มี row สำหรับ candidates เลย”
แต่ถ้ามี row สำหรับ member ใด member หนึ่งแล้ว →
	•	คนที่มี row และ is_available = 0 หรือ unavailable_until > now ต้องถูก filter ทิ้ง
	•	คนที่มี row และ is_available = 1 และ unavailable_until <= now or NULL อยู่ต่อ
	•	คนที่ ไม่มี rowเลย → ยังถือว่า “ไม่ถูก config” → fail-open (ผ่านได้)

เป้าหมายคือ: พอเริ่มใช้จอ Availability จริง ๆ แล้ว ระบบจะ “เคารพ” availability ของช่าง แต่ยังไม่ทำร้ายคนที่ยังไม่ถูกตั้งค่าเลย

⸻

2.2 Backend – API สำหรับจัดการ Operator Availability
สร้าง/ต่อยอด API ฝั่ง Hatthasilpa:
	•	ถ้าในโปรเจกต์มีไฟล์รวม API ฝั่ง Hatthasilpa อยู่แล้ว เช่น source/hatthasilpa_jobs_api.php หรือ endpoint อื่นที่เกี่ยวกับ operator:
	•	ให้เพิ่ม action ใหม่ในไฟล์นั้น
	•	ถ้าไม่มีชัดเจน ให้สร้างไฟล์ใหม่ (ยึด naming ตาม convention เดิมของ DAG/Hatthasilpa) เช่น:
	•	source/hatthasilpa_operator_api.php

API ที่ต้องมี (JSON):
	1.	GET /?action=get_operator_availability
	•	Input:
	•	optional: operator_id (id_member) → ถ้าไม่ส่งให้ list ทั้งหมด
	•	Output (ตัวอย่าง):

{
  "ok": true,
  "operators": [
    {
      "id_member": 1,
      "name": "Operator A",
      "is_available": 1,
      "unavailable_until": null,
      "last_updated": "2025-11-17 15:00:00"
    },
    ...
  ]
}


	•	Join กับ bgerp.account เพื่อดึงชื่อ (ถ้าจำเป็นใช้แค่ id_member ก็ได้)

	2.	POST /?action=update_operator_availability
	•	Input (JSON หรือ form-data):
	•	id_member (required, int)
	•	is_available (0/1)
	•	unavailable_until (nullable; DATETIME string หรือ empty หมายถึง NULL)
	•	Behavior:
	•	ถ้ายังไม่มี row → INSERT
	•	ถ้ามีอยู่แล้ว → UPDATE
	•	Output:

{
  "ok": true,
  "operator": {
    "id_member": 1,
    "is_available": 0,
    "unavailable_until": "2025-11-20 00:00:00"
  }
}


	•	ต้องหุ้มด้วย transaction + try/catch แบบเดียวกับ API อื่นในระบบ
	•	Log error ผ่าน error_log() แต่ ห้ามโยน exception ที่ PHPUnit จับแล้ว fail (logic ใช้ soft-mode เหมือนเดิม)

Note: ให้ใช้ helper เดิมที่มีอยู่ในโปรเจกต์ เช่น json_response(), getTenantDb(), core_db() ถ้ามี

⸻

2.3 Frontend – Operator Availability Console (หน้าเล็ก ๆ ก็พอ)
สร้างหน้าใหม่ใน Hatthasilpa UI (ยึด layout เดิมของระบบ):

ชื่อไฟล์แนะนำ (ตัวอย่าง):
	•	hatthasilpa_operator_availability.php
หรือถ้ามีโฟลเดอร์ view เฉพาะ Hatthasilpa ให้ใส่ตาม convention เช่น views/hatthasilpa/operator_availability.php

UI Minimal ที่ต้องการ:
	•	ตาราง list operator:
	•	Columns:
	•	ชื่อช่าง / รหัส (จาก bgerp.account)
	•	สถานะ:
	•	แสดงเป็น badge เช่น “Available”, “Unavailable”
	•	unavailable_until (ถ้ามี)
	•	ปุ่ม “แก้ไข” หรือ toggle
	•	Modal / inline form เวลาแก้ไข:
	•	เลือก:
	•	is_available (radio / switch: Available / Unavailable)
	•	unavailable_until (datetime-local หรือ date + time แยกก็ได้)
	•	ปุ่ม Save → call API update_operator_availability
	•	Behavior:
	•	เวลาเปิดหน้า:
	•	Call get_operator_availability แล้ว render table
	•	เวลา Save:
	•	ยิง update_operator_availability
	•	ถ้า ok: true → refresh row หรือ reload table

ไม่ต้องทำ UI สวยมาก แค่ใช้งานง่ายและสอดคล้องกับ style ปัจจุบัน (Bootstrap/Template ที่มีอยู่)

⸻

3. Integration กับ AssignmentEngine::filterAvailable()

ใน AssignmentEngine::filterAvailable():

ปัจจุบันใน branch:

} elseif ($hasAvailableFlag && $hasUnavailableUntil) {
    // ...
    // count table
    // check rows exist for candidates
    // SELECT ... WHERE (availColName = 1 OR availColName IS NULL) ...
}

ต้องปรับ:
	1.	ดึงค่า FF_HAT_ENFORCE_AVAILABILITY (tenant-based)
	•	ใช้ core DB: core_db()
	•	ใช้ FeatureFlagService ที่มีอยู่ (เหมือนที่ใช้กับ FF_HAT_NODE_PLAN_AUTO_ASSIGN)
	•	tenant scope ให้ใช้ logic เดียวกับ node_plan auto-assign:
	•	org_code จาก resolve_current_org() หรือ pattern DB name ที่มีอยู่
	•	ถ้าหาไม่ได้ ใช้ 'GLOBAL'
	2.	กรณี flag = 0:
	•	ใช้ behaviorเดิม 100%
	•	คือ:
	•	ถ้า table ว่าง → return $ids (fail-open)
	•	ถ้าไม่มี row สำหรับ candidates → return $ids (fail-open)
	•	query ปัจจุบันที่ allow availColName IS NULL → ถือว่า null = ว่าง (ยังไม่ config)
	3.	กรณี flag = 1:
	•	ยังใช้ สองชั้น fail-open แบบเดิม:
	•	ถ้า table ว่าง → return $ids
	•	ถ้าไม่มี row สำหรับ candidates เลย → return $ids
	•	แต่ตอน SELECT หลัก:
	•	แก้ query ให้ “ไม่ถือว่า IS NULL = ว่าง” อีกต่อไปสำหรับคนที่มี row
	•	เงื่อนไขควรจะเป็นประมาณ:

SELECT {$idColumn} AS member_id
FROM operator_availability
WHERE {$idColumn} IN ($in)
  AND (
    ({$availColName} = 1 AND (unavailable_until IS NULL OR unavailable_until <= UTC_TIMESTAMP()))
  )

(คือไม่ใช้ OR {$availColName} IS NULL แล้ว)

	•	หลังจากได้ $out แล้ว:
	•	intersect กับ $ids เหมือนเดิม
	•	return $out หรือ $ids ตาม logic ที่มีอยู่

⸻

4. Tests ที่ต้องเพิ่ม

4.1 Unit Test – AssignmentEngine::filterAvailable()
ถ้ามี Unit Test สำหรับ AssignmentEngine อยู่แล้ว:
	•	เพิ่ม test ใหม่ เช่น:

	1.	testFilterAvailable_FlagOff_FailOpenBehaviorPreserved()
	•	Arrange:
	•	Mock DB schema ให้มี table operator_availability + columns id_member, is_available, unavailable_until
	•	table ว่าง หรือไม่มี row ตรงกับ candidate
	•	Simulate: FF_HAT_ENFORCE_AVAILABILITY = 0
	•	Assert: return candidate IDs ทั้งหมด (fail-open)
	2.	testFilterAvailable_FlagOn_RespectsAvailability()
	•	Arrange:
	•	candidates = [1, 2, 3]
	•	operator_availability:
	•	(id_member=1, is_available=1, unavailable_until=NULL)
	•	(id_member=2, is_available=0, unavailable_until=NULL)
	•	(id_member=3, is_available=1, unavailable_until=อนาคต)
	•	FF_HAT_ENFORCE_AVAILABILITY = 1
	•	Assert:
	•	result = [1] เท่านั้น
	3.	testFilterAvailable_FlagOn_NoRowsForCandidates_FailOpen()
	•	operator_availability ไม่มี row สำหรับ candidates เลย แต่ table ไม่ว่าง (เช่นมี row ของคนอื่น)
	•	Assert:
	•	result = candidate IDs เดิมทั้งหมด

ถ้า Unit Test ระดับนี้เขียนยากเพราะ helper db function เป็น global,
อนุโลมให้ทำ Integration Test แทนโดยใช้ tenant DB ทดสอบ

4.2 Integration Test – Operator Availability + Assignment
สร้างไฟล์ใหม่ เช่น:
	•	tests/Integration/HatthasilpaOperatorAvailabilityTest.php

Scenario แนะนำ:
	1.	testAvailabilityFlagOff_DoesNotFilterCandidates
	•	เปิด tenant maison_atelier
	•	สร้าง member 2 คนใน bgerp.account
	•	ใส่ row ใน operator_availability ให้คนหนึ่ง is_available=0
	•	Set FF_HAT_ENFORCE_AVAILABILITY = 0
	•	ปล่อย job+token ที่มี node_plan candidate = [ทั้ง 2 คน]
	•	Assert: assignment สามารถไปลงคนที่ is_available=0 ได้ (หรืออย่างน้อย filterAvailable ไม่ตัดเขาออก → ดูจาก log / decision / result)
	2.	testAvailabilityFlagOn_FiltersUnavailableOperators
	•	Set FF_HAT_ENFORCE_AVAILABILITY = 1
	•	ใช้ node_plan ให้ candidate [1,2]
	•	availability:
	•	member 1: is_available=1, unavailable_until <= now
	•	member 2: is_available=0 หรือ unavailable_until > now
	•	Spawn token ให้เข้า AssignmentEngine
	•	Assert:
	•	assignment ต้องลง member 1 เท่านั้น

⸻

5. Acceptance Criteria

Task 10 ถือว่า “ผ่าน” เมื่อ:
	1.	มีหน้า UI สำหรับจัดการ Availability ของช่าง (ดู list + แก้ is_available + unavailable_until ได้)
	2.	API:
	•	get_operator_availability ทำงานได้ และตอบกลับเป็น JSON
	•	update_operator_availability insert/update ได้จริงใน tenant DB
	3.	AssignmentEngine::filterAvailable():
	•	ไม่พัง schema เดิม
	•	ถ้า flag = 0 → behavior เหมือนเดิม
	•	ถ้า flag = 1 →
	•	คนที่ mark ไม่ว่าง/มี unavailable_until อนาคต ถูก filter ออก
	•	คนที่ mark ว่าง ถูกคงไว้
	•	คนที่ไม่มี row → fail-open (ยังถือว่าว่าง)
	4.	มี tests อย่างน้อย:
	•	1–2 integration tests สำหรับ enforce availability
	•	Tests รันผ่าน (ไม่เพิ่ม error ใหม่ใน suite ที่มีอยู่)

⸻

6. Prompt สำหรับ Agent (พร้อมโยนได้เลย)

คุณสามารถเอาบล็อกนี้ไปวางใน docs/dag/agent-tasks/task10_OPERATOR_AVAILABILITY_CONSOLE.md หรือส่งตรงให้ Agent:

# Task 10 – Operator Availability Console & Enforcement Flag

## Goal

Implement a minimal **Operator Availability Console** and wire it into `AssignmentEngine::filterAvailable()` via a new feature flag `FF_HAT_ENFORCE_AVAILABILITY`, so that:
- When the flag is OFF → behavior is exactly as today (fail-open).
- When the flag is ON → operators marked as unavailable (or with future `unavailable_until`) are excluded from assignment, while still failing open for operators that have no availability row yet.

## Context

- AssignmentEngine currently supports multiple `operator_availability` schemas and already has a branch for:
  - `hasAvailableFlag && hasUnavailableUntil` with idColumn `id_member` (production schema).
- We recently added:
  - Node plan auto-assignment (TASK7).
  - Serial Stage 2 enforcement and tenant resolution (TASK8–9).
- Now we want to make availability “real” by:
  1. Giving managers a UI to mark who is available.
  2. Letting AssignmentEngine respect that, but only when a dedicated flag is turned on.

## Requirements

### 1. New Feature Flag – FF_HAT_ENFORCE_AVAILABILITY

- Implement `FF_HAT_ENFORCE_AVAILABILITY` in the existing FeatureFlagService/core feature flag system.
- Scope: tenant-level (use the same tenant resolution logic as in FF_HAT_NODE_PLAN_AUTO_ASSIGN, e.g. `resolve_current_org()` or org_code from DB name; fallback to `GLOBAL`).
- Behavior:
  - **flag = 0 (default)**:
    - `AssignmentEngine::filterAvailable()` must behave exactly as today (full fail-open).
  - **flag = 1**:
    - When using the schema `id_member` + `is_available` (or `available`) + `unavailable_until`:
      - If the table is completely empty → fail-open (return all candidates).
      - If the table has no rows for any of the candidate IDs → fail-open (return all candidates).
      - If there are rows for some candidates:
        - `is_available = 1` and (`unavailable_until` is NULL or in the past) → treat as “available”.
        - `is_available = 0` OR `unavailable_until` in the future → treat as “unavailable” and filter out.
        - Candidates with **no row at all** are treated as “not configured yet” and should still pass (fail-open).

### 2. API for Operator Availability

Add a small JSON API for managing operator availability. Either:
- Extend an existing Hatthasilpa API file, or
- Create a new file (e.g., `hatthasilpa_operator_api.php`) following the existing API patterns.

Implement at least:

#### GET ?action=get_operator_availability

- Input:
  - optional: `id_member` (filter by specific operator).
- Output:
  - JSON with `ok: true` and a list of operators, including at least:
    - `id_member`
    - `name` (or any display name from `bgerp.account`)
    - `is_available`
    - `unavailable_until`
    - `last_updated` (if available)

#### POST ?action=update_operator_availability

- Input:
  - `id_member` (required, int)
  - `is_available` (0/1)
  - `unavailable_until` (nullable string; empty means NULL)
- Behavior:
  - INSERT a new row if none exists.
  - UPDATE existing row otherwise.
- Output:
  ```json
  {
    "ok": true,
    "operator": {
      "id_member": 1,
      "is_available": 0,
      "unavailable_until": "2025-11-20 00:00:00"
    }
  }

	•	Use the same JSON response and error handling patterns as other DAG/Hatthasilpa APIs (soft-mode: log errors via error_log() but do not throw PHPUnit exceptions).

3. Frontend: Operator Availability Console
	•	Create a minimal Hatthasilpa page (e.g., hatthasilpa_operator_availability.php) that:
	•	Lists all operators (from bgerp.account) with:
	•	Name / ID
	•	Availability badge (“Available” / “Unavailable”)
	•	unavailable_until if set
	•	Edit button or inline control.
	•	On page load:
	•	Calls get_operator_availability to populate the table.
	•	On edit:
	•	Shows a small form to set is_available and unavailable_until.
	•	Sends update_operator_availability and refreshes the row on success.
	•	Use the existing layout and components (Bootstrap/template) used in other Hatthasilpa pages.

4. Changes in AssignmentEngine::filterAvailable()
	•	In the hasAvailableFlag && hasUnavailableUntil branch:
	•	Resolve tenant scope and fetch FF_HAT_ENFORCE_AVAILABILITY via FeatureFlagService.
	•	If flag = 0:
	•	Preserve the current behavior exactly (fail-open, including the IS NULL logic).
	•	If flag = 1:
	•	Keep the two fail-open guards:
	1.	If table is empty → return all candidates.
	2.	If no rows exist for the candidate IDs → return all candidates.
	•	Adjust the main SELECT to:
	•	Only treat is_available = 1 AND (unavailable_until IS NULL OR in the past) as available.
	•	Do not treat IS NULL availability as “available” if a row exists.
	•	After fetching available IDs, intersect with the original candidate IDs and return.

5. Tests

Add tests to cover at least:
	1.	Unit or Integration (filterAvailable, flag OFF):
	•	Arrange some rows in operator_availability, but set FF_HAT_ENFORCE_AVAILABILITY = 0.
	•	Assert that all candidate IDs pass (current fail-open behavior preserved).
	2.	Unit or Integration (filterAvailable, flag ON):
	•	Candidates: [1, 2, 3].
	•	Availability rows:
	•	1: is_available=1, unavailable_until in the past or NULL → should pass.
	•	2: is_available=0 → should be filtered out.
	•	3: is_available=1, unavailable_until in the future → should be filtered out.
	•	Assert that only candidate 1 remains.
	3.	Integration Test with AssignmentEngine:
	•	Enable FF_HAT_ENFORCE_AVAILABILITY for a test tenant.
	•	Create a graph/node with node_plan including candidate members.
	•	Mark one member unavailable via operator_availability.
	•	Spawn tokens and verify that assignments do not choose the unavailable member.

6. Acceptance Criteria
	•	New page allows admins to manage operator availability and persist changes into operator_availability.
	•	API endpoints work and follow the existing API style.
	•	AssignmentEngine::filterAvailable():
	•	Keeps legacy behavior when FF_HAT_ENFORCE_AVAILABILITY = 0.
	•	Respects availability when FF_HAT_ENFORCE_AVAILABILITY = 1, while still failing open when no configuration exists.
	•	Test suite includes coverage for both flag states and passes successfully.