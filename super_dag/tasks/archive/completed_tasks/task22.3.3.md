

# Task 22.3.3 – LocalRepairEngine Activation & Eligibility Alignment

**Status:** SPEC  
**Date:** 2025-XX-XX  
**Owner:** Bellavier ERP Core / SuperDAG Team  
**Depends on:**  
- Task 22.1 (Local Repair Engine v1)  
- Task 22.2 (Repair Event Model & Log)  
- Task 22.3 (Timeline Reconstruction v1)  
- Task 22.3.1 (Reconstruction Hardening)  
- Task 22.3.2 (Canonical Timeline Repair Test Suite v1)  

---

## 1. Objective

ตอนนี้ Test Suite (`dag_repair_test_suite.php`) ทำงานแล้ว, Validator มองเห็นปัญหาได้ถูกต้อง แต่ `LocalRepairEngine::generateRepairPlan()` ยัง **ไม่สร้าง repair plan เลยแม้แต่เคสเดียว** (ทุกเคสขึ้น `⚠️  No repair plan generated`)

เป้าหมายของ Task 22.3.3:

1. เปิดให้ LocalRepairEngine “กล้าทำงาน” ใน dev mode  
2. Align eligibility + error mapping ให้รองรับ error codes รุ่นใหม่ของ Validator  
3. เพิ่ม debug signal ให้ Test Suite แสดงสาเหตุที่ไม่ได้สร้าง repair plan  
4. ทำให้ Test Suite v1 (TC01–TC10) มีอย่างน้อยบางเคสที่ได้ repair plan จริง ๆ และปัญหาลดลงหลังซ่อม

---

## 2. ปัญหาที่สังเกตจาก Test Suite ปัจจุบัน

### 2.1 Engine ไม่สร้าง plan แม้มี L1 errors ชัดเจน

จาก output ล่าสุด:

- TC01: Problems = `BAD_FIRST_EVENT, MISSING_START, TIMELINE_MISSING_START`  
- TC03: Problems = `UNPAIRED_PAUSE`  
- TC04: Problems = `NO_CANONICAL_EVENTS`  
- TC07: Problems = `UNPAIRED_PAUSE`  
- TC09: Problems = `BAD_FIRST_EVENT, PAUSE_BEFORE_START, UNPAIRED_PAUSE`

แต่ทุกเคสขึ้น:

```text
⚠️  No repair plan generated
```

แปลว่า:

- แม้จะมี problems ที่ LocalRepairEngine v1 “รู้จัก” เช่น `MISSING_START`, `UNPAIRED_PAUSE`, `NO_CANONICAL_EVENTS`  
- Engine เลือกที่จะไม่ทำงานเลย (repair plan ว่าง)

### 2.2 สาเหตุที่เป็นไปได้ (Hypothesis)

1. **Feature Flag / Eligibility Gate**  
   - มี check ว่า feature flag หรือ config ไม่ผ่าน → return ซะก่อนสร้าง plan  
   - หรือ token status ไม่ใช่ `completed` / `scrapped` → ไม่ repair

2. **Unknown Error Codes → Fail Safe**  
   - Validator รุ่นใหม่ปล่อย error codes เพิ่ม เช่น:
     - `BAD_FIRST_EVENT`  
     - `TIMELINE_MISSING_START`  
     - `PAUSE_BEFORE_START`  
   - Engine อาจมองว่า “ถ้ามี error ที่ไม่รู้จัก → อย่าแตะ” แล้ว return plan ว่าง

---

## 3. Scope ของ Task 22.3.3

### 3.1 ปรับ Eligibility Logic ใน LocalRepairEngine

**ไฟล์:**  
- `source/BGERP/Dag/LocalRepairEngine.php`

**เป้าหมาย:**  
- ให้ L1 problems ที่ Engine v1 รู้จัก (เช่น `MISSING_START`, `MISSING_COMPLETE`, `UNPAIRED_PAUSE`, `NO_CANONICAL_EVENTS`) ถูกพิจารณา repair แม้จะมี error อื่นปนอยู่  
- ลดเงื่อนไขที่บล็อกการทำงานโดยไม่จำเป็นใน dev

**แนวทาง:**

1. เพิ่ม/ปรับ method (หรือ logic) เช่น `isTokenEligibleForLocalRepair($validationResult)`:

   - ตรวจ:
     - token status (ต้องเป็น completed/scrapped หรือค่าอื่นที่เรายอมรับ)  
     - ไม่ต้องขึ้นอยู่กับ feature flag (หรือ treat flag หาย = enabled ใน dev)

   - อย่าบล็อกทุกอย่างเพียงเพราะมี error code แปลกใด ๆ

2. ใน `generateRepairPlan()`:

   - เขียนลำดับ:

     ```php
     // 1) ถ้า token ไม่เข้าเงื่อนไข (เช่น ยังไม่ complete) → return reason = "TOKEN_NOT_ELIGIBLE"
     // 2) ถ้าไม่มี L1 problems ที่รู้จัก → return reason = "NO_KNOWN_PROBLEMS"
     // 3) ถ้ามีอย่างน้อย 1 L1 problem ที่รองรับ → เดิน logic ซ่อมตามปกติ
     ```

   - **ไม่ควร** return ทันทีเพราะเจอ `BAD_FIRST_EVENT` / `TIMELINE_MISSING_START` / `PAUSE_BEFORE_START` หากยังมี `MISSING_START`, `UNPAIRED_PAUSE` ฯลฯ

3. ใน dev mode:

   - สามารถใช้ heuristic แบบ:
     - ถ้า `org` อยู่ใน whitelist dev (เช่น `maison_atelier`) → bypass flag check  
     - เพื่อให้ Test Suite วิ่งได้เต็มที่ก่อนจริงจังเรื่อง config ใน production

### 3.2 Mapping Error Codes รุ่นใหม่ให้เข้ากับ Repair Logic

**เป้าหมาย:**  
- ทำให้ error codes ที่ validator เพิ่มเข้ามา **ไม่บล็อก** repair ที่เราทำได้  
- และในบางเคสอาจถูก map เข้าสู่ repair handler เดิม

**ตัวอย่าง mapping:**

- `TIMELINE_MISSING_START` → ซ้อนกับ `MISSING_START` → ใช้ handler `MISSING_START` ได้  
- `PAUSE_BEFORE_START` → variation ของ `UNPAIRED_PAUSE` หรือ `INVALID_SEQUENCE_SIMPLE` → ใช้ handler `UNPAIRED_PAUSE` หรือ ignore เพิ่มเติม  
- `BAD_FIRST_EVENT` → ไม่ต้องซ่อมโดยตรง แต่ไม่ควรทำให้ engine ยอมแพ้ทั้ง plan

**วิธี implement (แนะนำ):**

- เพิ่ม helper:

  ```php
  private function extractSupportedProblems(array $problems): array
  ```

  - filter เฉพาะ codes ที่ LocalRepairEngine v1 รองรับจริง เช่น:
    - `MISSING_START`
    - `MISSING_COMPLETE`
    - `UNPAIRED_PAUSE`
    - `NO_CANONICAL_EVENTS`
    - (และอื่น ๆ ที่ handler มีอยู่จริง)

- ใน `generateRepairPlan()`:

  - ใช้ supportedProblems ในการตัดสินใจว่าจะสร้าง repair plan หรือไม่  
  - ถ้า supportedProblems ว่าง → return reason = "NO_SUPPORTED_PROBLEMS"

### 3.3 Debug Signal สำหรับ Test Suite

**ไฟล์:**  
- `tools/dag_repair_test_suite.php`

**เป้าหมาย:**  
- เมื่อ `repairs` ว่าง → ให้ข้อมูลเพิ่มว่าทำไมถึงไม่ซ่อม

**แนวทาง:**

- หลังเรียก `generateRepairPlan()`:

  ```php
  if (empty($repairPlan['repairs'])) {
      $reason = $repairPlan['reason'] ?? 'no reason provided';
      echo "⚠️  No repair plan generated (reason: {$reason})\n\n";
  }
  ```

- ถ้า `generateRepairPlan()` ไม่มี field `reason` ให้เพิ่มใน LocalRepairEngine เช่น:

  ```php
  return [
      'token_id' => $tokenId,
      'repairs'  => [],
      'reason'   => 'NO_SUPPORTED_PROBLEMS',
      // optional: 'problems' => $validationResult['problems'] ?? [],
  ];
  ```

ทำแบบนี้จะช่วยให้เวลารัน:

```bash
php tools/dag_repair_test_suite.php run-all --org=maison_atelier
```

คุณจะเห็นชัดเจนว่า engine ไม่ซ่อมเพราะอะไร เช่น:

- `reason: FEATURE_FLAG_DISABLED`  
- `reason: TOKEN_NOT_ELIGIBLE`  
- `reason: NO_SUPPORTED_PROBLEMS`

---

## 4. Expected Changes in Test Suite Behavior

หลังจบ Task 22.3.3 แล้ว:

1. **TC01 (MISSING_START)**  
   - Before: BAD_FIRST_EVENT, MISSING_START, TIMELINE_MISSING_START → no plan  
   - After:
     - Engine ยังเห็น BAD_FIRST_EVENT / TIMELINE_MISSING_START  
     - แต่สามารถซ่อม `MISSING_START` ได้ → มี START ถูกเพิ่ม  
     - Problems ลดลง (MISSING_START/TIMELINE_MISSING_START หาย หรือเหลือเฉพาะ BAD_FIRST_EVENT)

2. **TC03 (UNPAIRED_PAUSE)**  
   - ควรได้ RESUME + COMPLETE ตาม handler ที่มีอยู่

3. **TC04 (NO_CANONICAL_EVENTS)**  
   - ควร generate START + COMPLETE จาก flow_token

4. **TC05, TC06, TC10**  
   - ถ้าปัจจุบัน Validator มองว่า “Valid: YES” → Test Suite ถือว่าไม่ได้ทดสอบ repair แต่ทดสอบ “no-op” (confirm ว่าไม่ซ่อมเมื่อไม่จำเป็น)  
   - Task นี้ไม่จำเป็นต้องเปลี่ยนผลผ่าน/ตกของ TC05/06/10 มากนัก แค่ให้ behavior ชัดเจน

5. อย่างน้อย 2–4 test cases ควรเริ่มมี `Repair Plan` และ `After Repair` ที่ problems ลดลงจริง

---

## 5. Deliverables

1. `LocalRepairEngine.php`:
   - ปรับ eligibility (isTokenEligibleForLocalRepair หรือเทียบเท่า)
   - เพิ่ม/ปรับ mapping supportedProblems  
   - เพิ่ม field `reason` ในผลลัพธ์ generateRepairPlan เมื่อไม่มี repairs

2. `dag_repair_test_suite.php`:
   - แสดง `reason` เมื่อไม่มี repair plan

3. `task22_3_3_results.md`:
   - สรุป implementation ที่ทำจริง + ตัวอย่าง log ก่อน–หลัง patch

---

## 6. Acceptance Criteria

- Test Suite v1 (`run-all`) แสดง:
  - TC01, TC03, TC04 อย่างน้อยบางเคสมี `Repair Plan` ไม่ว่าง  
  - มี log `After Repair` ที่ problems ลดลงจาก `Before Repair`
- ไม่มี test case ไหนที่ “ควรซ่อม” แต่ถูกบล็อกเพราะ error code แปลก (เช่น BAD_FIRST_EVENT) โดยที่ยังมี L1 problems ที่ engine รู้จัก
- Dev สามารถอ่าน `reason` จาก log แล้วเข้าใจได้ว่า “ทำไม token นี้ไม่ถูกซ่อม”
- ไม่กระทบ behavior engine เดิม และยังเป็น append-only ทั้งหมด