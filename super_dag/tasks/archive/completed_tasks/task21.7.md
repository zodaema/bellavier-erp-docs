

# Task 21.7 – Canonical Event Integrity Validator (Consistency Checker)

**Status:** PLANNING  
**Date:** 2025-01-XX  
**Category:** SuperDAG / Canonical Events / Integrity Checking  
**Depends on:**  
- Task 21.1–21.6 (Node Behavior Engine, Canonical Events, TimeEventReader, Debug Timeline Viewer)  
- `Node_Behavier.md` (Canonical Event Axioms)  
- `time_model.md` (Time Model State Machine)  
- `SuperDAG_Execution_Model.md`  

---

## 1. Objective

สร้างระบบ **Canonical Event Integrity Validator** เพื่อตรวจสอบความถูกต้องของ event pipeline ตามกติกาที่กำหนดใน Axioms:

1. ตรวจลำดับ event (sequence correctness)  
2. ตรวจ event completeness (missing NODE_START, missing NODE_COMPLETE)  
3. ตรวจ session correctness (pause/resume pairing)  
4. ตรวจความสมเหตุสมผลของเวลา (duration validity)  
5. ตรวจความสอดคล้องกับ flow_token (legacy sync check)  

> เป้าหมาย Task 21.7 = เพื่อค้นหาความผิดปกติใน canonical event pipeline อัตโนมัติ ไม่ต้องรอผู้ใช้เจอเอง

---

## 2. Scope

### 2.1 In-Scope

1. **สร้าง Event Integrity Ruleset**
   - Rule 1: NODE_START ต้องมาก่อน NODE_COMPLETE  
   - Rule 2: หากมี NODE_PAUSE ต้องมี NODE_RESUME  
   - Rule 3: หากมีหลาย sessions ต้องไม่ overlap  
   - Rule 4: เวลา event_time ต้องเรียงลำดับถูกต้อง  
   - Rule 5: duration_ms ต้อง >= 0  
   - Rule 6: หากมี NODE_COMPLETE → ต้องมี start_time  
   - Rule 7: canonical duration ต้องไม่ต่างจาก legacy > threshold (เช่น 5%)  
   - Rule 8: canonical event canonical_type ต้องอยู่ใน whitelist  
   - Rule 9: ไม่ควรมี event_type mismatch (เช่น canonical = NODE_COMPLETE แต่ event_type = “spawn”)

2. **เพิ่ม Class ใหม่: CanonicalEventIntegrityValidator**
   - รับ token_id  
   - Fetch canonical events  
   - ตรวจตาม ruleset ทั้งหมด  
   - ส่งกลับผลลัพธ์เป็น array เช่น:
     ```php
     [
       'valid'   => false,
       'problems' => [
         ['code' => 'MISSING_START', 'message' => 'NODE_COMPLETE found but no NODE_START'],
         ['code' => 'BAD_SEQUENCE', 'message' => 'PAUSE before START'],
       ],
       'summary' => [...],
       'events'  => [...]
     ]
     ```

3. **Integration กับ Dev Timeline Debugger**
   - เพิ่ม panel “Integrity Report” ในหน้า dev tool  
   - หากพบปัญหา ให้ขึ้นข้อความสีแดง/เหลืองตาม severity

4. **CLI / Dev Command (optional)**
   - เพิ่มคำสั่ง dev-only:
     ```
     php artisan dag:validate:token {token_id}
     ```
     หรือ  
     ```
     php cli.php dag:validate-token --token=123
     ```

5. **Logging**
   - หาก token มีปัญหา ให้ log เช่น:
     ```
     [IntegrityCheck] Token 123: BAD_SEQUENCE (pause before start)
     ```
   - dev/staging เท่านั้น

### 2.2 Out-of-Scope

- ไม่แก้ไข canonical events โดยอัตโนมัติ  
- ไม่แก้ไข flow_token อัตโนมัติ  
- ไม่ integrate กับ production reporting  
- ไม่ทำ automated repair (ไว้ Task 22.x)

---

## 3. Design

### 3.1 Class Structure

ไฟล์ที่คาดหวัง:  
`source/BGERP/Dag/CanonicalEventIntegrityValidator.php`

โครงสร้าง:

```php
class CanonicalEventIntegrityValidator
{
    protected PDO $db;

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    public function validateToken(int $tokenId): array
    {
        $events = $this->fetchCanonicalEvents($tokenId);
        $timeline = (new TimeEventReader($this->db))->getTimelineForToken($tokenId);

        $problems = [];
        $problems = array_merge($problems, $this->checkSequence($events));
        $problems = array_merge($problems, $this->checkCompleteness($events, $timeline));
        $problems = array_merge($problems, $this->checkDuration($timeline));
        $problems = array_merge($problems, $this->checkLegacySync($tokenId, $timeline));

        return [
            'valid'    => empty($problems),
            'problems' => $problems,
            'events'   => $events,
            'timeline' => $timeline,
        ];
    }
}
```

### 3.2 Rule Evaluation

ตัวอย่าง rule:

```php
protected function checkSequence(array $events): array
{
    $problems = [];

    // START must be first
    $first = $events[0]['canonical_type'] ?? null;
    if ($first !== 'NODE_START') {
        $problems[] = ['code' => 'BAD_FIRST_EVENT', 'message' => 'First event is not NODE_START'];
    }

    // pause before start
    foreach ($events as $e) {
        if ($e['canonical_type'] === 'NODE_PAUSE' && !$this->hasStartBefore($events, $e)) {
            $problems[] = ['code' => 'PAUSE_BEFORE_START', 'message' => 'NODE_PAUSE appears before NODE_START'];
        }
    }

    return $problems;
}
```

---

## 4. Testing

### 4.1 Unit Tests
- feed synthetic event sequences เพื่อทดสอบ rules:
  - no start
  - no complete
  - pause without resume
  - resume without pause
  - complete without start
  - duration < 0
  - event_time disorder

### 4.2 Integration Tests (dev)
- ใช้ tokens ที่ได้จาก dev flow  
- เช็คว่ารายงานความผิดปกติถูกต้อง  
- ตรวจ log

---

## 5. Done Criteria

- Class `CanonicalEventIntegrityValidator` ทำงานได้ครบทุก ruleset  
- Dev Timeline Debugger แสดง Integrity Panel  
- สามารถวิเคราะห์ event pipeline ได้ง่ายขึ้น  
- ระบบไม่แตะข้อมูลจริง ไม่กระทบ production  
- เอกสาร `task21_7_results.md` ถูกสร้างและสรุปผลการทำงาน  
