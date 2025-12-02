# Task 21.5 – Time Engine (Read Canonical Events) [DEV-ONLY]

**Status:** PLANNING  
**Category:** SuperDAG / Time Engine / Canonical Events  
**Depends on:**
- Task 21.1–21.4 (Node Behavior Engine + TokenEventService + Feature Flag)
- `time_model.md` (Canonical Time Model)
- `SuperDAG_Execution_Model.md`
- `Node_Behavier.md` (Canonical Events section)

---

## 1. Objective

1. ให้ Time Engine สามารถ **อ่านเวลา** จาก canonical events (`token_event`) แทนการพึ่ง field legacy ตรง ๆ  
2. ยังอยู่ในโหมด **DEV/EXPERIMENTAL เท่านั้น** (controlled by `NODE_BEHAVIOR_EXPERIMENTAL`)  
3. ไม่ทำให้ behavior เดิมพัง: `flow_token.start_at`, `completed_at`, `actual_duration_ms` ยังถูกใช้ต่อได้ แต่จะเริ่มถูก **sync จาก events** ในบางกรณี

---

## 2. Scope

### 2.1 In-Scope

1. สร้าง `TimeEventReader` service (ใหม่)
   - รับ `id_token` (และ optional `id_node`)
   - อ่านจาก `token_event` ทุก event ที่เกี่ยวข้อง:
     - `NODE_START`
     - `NODE_PAUSE`
     - `NODE_RESUME`
     - `NODE_COMPLETE`
   - คืน structure มาตรฐาน เช่น:
     ```php
     [
       'start_time'      => '2025-01-10 10:23:00',
       'complete_time'   => '2025-01-10 10:35:12',
       'duration_ms'     => 732000,
       'sessions'        => [
         ['from' => '...', 'to' => '...', 'duration_ms' => 120000],
         ...
       ],
       'events_raw'      => [ /* raw token_event rows (optional for debug) */ ],
     ]
     ```

2. เพิ่มเมธอด helper ใน Time Engine:
   - `getActualDurationFromEvents(int $tokenId): ?int`
   - `getStartAtFromEvents(int $tokenId): ?string`
   - `getCompletedAtFromEvents(int $tokenId): ?string`

3. Integration (DEV only):
   - ใน `TokenLifecycleService::completeToken()`:
     - ถ้า `NODE_BEHAVIOR_EXPERIMENTAL` เปิด และ canonical events ถูก persist สำเร็จ
     - ให้เรียก TimeEventReader:
       - คำนวณ duration จาก events
       - ถ้า value ที่ได้ “มีเหตุผล”:
         - อัปเดต `flow_token.actual_duration_ms`, `start_at`, `completed_at`
       - ทำทั้งหมดนี้แบบ non-blocking (catch exception แล้ว log)

4. Debug/Logging:
   - log summary เช่น:
     - `[TimeEngine] Token X actual_duration_ms from events = Y (old=Z)`
   - ใช้ log นี้ช่วยเทียบค่าเก่า/ใหม่ใน dev

### 2.2 Out-of-Scope

- ยังไม่ปรับหน้า Report จริงให้ไปอ่าน `token_event` โดยตรง  
- ยังไม่ลบหรือ deprecate field legacy ใน `flow_token`  
- ยังไม่คำนวณ SLA/ETA เต็มรูปแบบจาก events (เก็บไว้ Task 22.x)

---

## 3. Design

### 3.1 TimeEventReader

**ไฟล์ที่คาดหวัง:**  
`source/BGERP/Dag/TimeEventReader.php` หรือภายใต้ namespace ที่เหมาะสม

**พฤติกรรมหลัก:**

```php
class TimeEventReader
{
    public function __construct(PDO $db) { ... }

    public function getTimelineForToken(int $tokenId): ?array
    {
        // 1) ดึง token_event ที่ event_type = NODE_START/PAUSE/RESUME/COMPLETE
        // 2) sort ตาม event_time
        // 3) build timeline / sessions ตาม time_model.md
    }

    public function getActualDurationMs(int $tokenId): ?int
    {
        $timeline = $this->getTimelineForToken($tokenId);
        return $timeline['duration_ms'] ?? null;
    }
}

	•	ใช้กติกา Time Model:
	•	NODE_START → เริ่ม session
	•	NODE_PAUSE → ปิด sessionชั่วคราว
	•	NODE_RESUME → เปิด sessionใหม่
	•	NODE_COMPLETE → ปิด sessionสุดท้าย + ปิดงาน

3.2 Integration Strategy
	•	หลังจาก TokenEventService::persistEvents() ใน completeToken():
	•	เรียก TimeEventReader → ดึงเวลาใหม่
	•	ถ้า:
	•	มี start_time & complete_time
	•	duration_ms > 0 และไม่เกิน threshold ผิดปกติ
	•	แล้วค่อยเขียนทับ/เติมลงใน flow_token

ถ้าอ่าน events ไม่ได้ / ข้อมูลไม่พอ → ไม่ต้องแตะ flow_token ปล่อยใช้ค่าปัจจุบันไปก่อน

⸻

4. Safety & Feature Flag
	•	ทั้งการอ่าน events และการ sync เวลา ต้องอยู่หลัง NODE_BEHAVIOR_EXPERIMENTAL
	•	ถ้า flag ปิด:
	•	ไม่เรียก TimeEventReader
	•	ระบบทำงานเหมือนเดิม 100%
	•	Error ใด ๆ จาก TimeEventReader:
	•	ต้องถูก catch/log
	•	ห้ามทำให้ token completion fail

⸻

5. Testing

5.1 Unit Test
	•	TimeEventReader:
	•	feed ชุด events จำลอง → ตรวจ duration, start, complete ว่าคำนวณถูก
	•	เคส: pause/resume หลายรอบ
	•	เคส: event incomplete → คืนค่า null

5.2 Integration Test (dev)
	1.	เปิด NODE_BEHAVIOR_EXPERIMENTAL สำหรับ tenant dev
	2.	ทำ flow HAT_SINGLE, BATCH_QUANTITY บางเคส
	3.	เปรียบเทียบ:
	•	ค่า flow_token.actual_duration_ms เดิม vs จาก events
	•	log [TimeEngine] ว่ามีค่าตามคาด
	4.	ปิด flag แล้วทดสอบว่า behavior กลับไปเหมือนเดิม

⸻

6. Done Criteria
	•	TimeEventReader สามารถอ่าน timeline จาก token_event ได้ตาม Time Model
	•	เมื่อ flag เปิด:
	•	completeToken() จะลองอ่านเวลาใหม่จาก events และ sync ลง flow_token (เฉพาะเคสที่ข้อมูลครบ)
	•	เมื่อ flag ปิด:
	•	ไม่มี query เพิ่ม, ไม่มีการแตะ flow_token
	•	มี unit tests ครอบ logic หลักของ TimeEventReader
	•	เอกสาร task21_5_results.md สรุปสิ่งที่ทำ, ข้อจำกัด, และ data point จาก dev/staging

---