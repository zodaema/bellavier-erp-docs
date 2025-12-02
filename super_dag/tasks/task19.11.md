

# Task 19.11 — Validator v3 (Semantic Validation Engine)

**Status:** IMPLEMENTATION TASK  
**Depends on:**
- Task 19.7 (GraphValidationEngine v2)
- Task 19.8–19.9 (AutoFix v1–v2)
- Task 19.10 (AutoFix v3 Spec)
- Task 19.10.1 (SemanticIntentEngine implementation)
- Task 19.10.2 (AutoFix v3 intent-aware integration)

---

## 1. Objective

ยกระดับระบบ validation จากระดับ **rule-based เชิงโครงสร้าง** (v2) ไปสู่ระดับ **semantic-aware validation** (v3) ที่เข้าใจเจตนาการออกแบบกราฟ โดยอาศัยผลจาก `SemanticIntentEngine` และใช้ร่วมกับ AutoFixEngine v3

เป้าหมายของ Validator v3 คือ:

1. ตรวจจับข้อผิดพลาดที่ "โครงสร้างถูก แต่เจตนาผิด" (semantic errors)
2. ลด false positive ของ validation เดิม (เช่น เตือนเรื่อง QC cover ทั้ง 3 status ทั้งที่ตั้งใจใช้แค่สองทาง)
3. แบ่งระดับความรุนแรงของปัญหาแบบมีเหตุผล: error / warning / suggestion
4. ทำงานสอดคล้องกับ AutoFixEngine v3 โดยไม่ซ้ำซ้อนกัน

หลังจบ Task 19.11:
- กราฟที่ผ่าน validation v3 จะถือว่า "พร้อมใช้งานจริง" ระดับ Production (ยกเว้น edge cases ที่ต้องรอ 19.12)

---

## 2. Scope

### In-Scope
- Patch/Refactor `GraphValidationEngine.php`
- เชื่อม `GraphValidationEngine` กับ `SemanticIntentEngine`
- เพิ่ม semantic validation rules (QC, Parallel, Endpoint, Reachability, Time model basic)
- ปรับโครงสร้าง error/warning ให้รองรับ semantic metadata
- ปรับ `dag_routing_api.php` action: `graph_validate` ให้ส่ง semantic context กลับไปยัง frontend

### Out-of-Scope
- AutoFix logic (ใช้ข้อมูลจาก Validator แต่ไม่เปลี่ยน AutoFixEngine ใน task นี้)
- UI overhaul (ใช้กลไกแสดง errors/warnings เดิม แต่เพิ่มข้อมูล semantic)
- Simulation / Time prediction (เป็นเรื่องของ Task 20.x)

---

## 3. High-Level Design

### 3.1 Current Situation (v2)

- GraphValidationEngine v2 ตรวจ:
  - Node without work_center
  - Orphan nodes, cycles (if any)
  - QC routing coverage (ค่อนข้าง strict → ต้องมี pass/fail_minor/fail_major)
  - Basic parallel/merge constraints
- ยังไม่เข้าใจเจตนาจาก graph pattern ระดับสูง
- ใช้ rule แบบ "กรณีเดียวใช้ได้กับทุกสถานการณ์" ทำให้เตือนเกินจำเป็นในเคสที่ผู้ใช้ตั้งใจออกแบบแบบง่าย ๆ

### 3.2 Target (v3)

Validator v3 จะเรียก pipeline ดังนี้:

```php
$intentResult = $semanticIntentEngine->analyzeIntent($nodes, $edges);
$intents      = $intentResult['intents'];

$validation = [
  'structural_errors' => [...],
  'semantic_errors'   => [...],
  'warnings'          => [...],
  'suggestions'       => [...],
  'intents'           => $intents,
];
```

โครงสร้างผลลัพธ์ต้องรองรับ:
- error/warning แบบผูกกับ node/edge
- message ที่อ้างถึง intent ที่เกี่ยวข้อง (เช่น `qc.two_way` หรือ `operation.multi_exit`)

---

## 4. Validation Rules (v3)

### 4.1 QC Routing Rules

ใช้ intents:
- `qc.two_way`
- `qc.three_way`
- `qc.pass_only`

#### Rule 4.1.1 — QC Two-Way

- ถ้า node มี intent = `qc.two_way`:
  - **ต้อง**มี:
    - อย่างน้อย 1 pass edge
    - อย่างน้อย 1 เส้นทาง rework (conditional หรือ default)
  - ไม่บังคับให้มี fail_minor/fail_major แยกกัน

**Error:**
- ถ้าไม่มี path สำหรับ failure เลย (ไม่มี rework / ไม่มี default non-pass route)

**Warning:**
- ถ้ามี conditional edge สำหรับ fail_minor/fail_major แต่ปลายทางไม่ใช่ rework/subflow ที่มีความหมาย → แจ้งเตือนระดับ warning

#### Rule 4.1.2 — QC Three-Way

- ถ้า intent = `qc.three_way` (หรือ detect จาก node ว่ามี pass/fail_minor/fail_major แยกชัดเจน):
  - ควรมี edges ครบทั้ง 3 สถานะ (pass, fail_minor, fail_major)

**Error:**
- ขาด status ใด status หนึ่ง โดยไม่มี default route ที่ปลอดภัย

**Warning:**
- If มี default/else route ที่กลืน fail_minor/major ทั้งหมด แต่ตั้งใจใช้ → แสดง warning ไม่ใช่ error

#### Rule 4.1.3 — QC Pass-Only

- ถ้า intent = `qc.pass_only`:
  - ไม่ error โดยอัตโนมัติ
  - ขึ้นอยู่กับ QC policy (config ภายนอก ในอนาคต)

**Warning (default behavior):**
- เตือนว่า "QC node นี้ไม่มี failure path เลย อาจเป็น informational QC เท่านั้น" โดยไม่ block save

---

### 4.2 Parallel / Multi-Exit Rules

ใช้ intents:
- `operation.linear_only`
- `operation.multi_exit`
- `parallel.true_split`
- `parallel.semantic_split`

#### Rule 4.2.1 — Linear Only

- ถ้า node มี intent = `operation.linear_only`:
  - ห้ามตั้งค่า parallel flags / merge flags แปลก ๆ

**Error:**
- linear node แต่ถูก mark ว่าเป็น parallel_split หรือ is_merge_node โดยไม่มีเหตุผล

#### Rule 4.2.2 — Multi-Exit (Non-Parallel)

- ถ้า intent = `operation.multi_exit`:
  - Validation v3 ไม่ควรบังคับให้เป็น parallel node
  - ถือว่าเป็น multi-exit ปกติ เช่น OP → QC, OP → Scrap, OP → Rework

**Warning:**
- ถ้ามี execution_mode หรือ parallel flags แปลก ๆ ผสมกับ multi-exit → เตือนผู้ใช้ให้ตรวจสอบอีกครั้ง

#### Rule 4.2.3 — True Parallel Split

- ถ้า intent = `parallel.true_split`:
  - ควรมี merge node downstream ที่เหมาะสม (intent: parallel branches converge)

**Error:**
- มี parallel split แล้วไม่มี node ใดเลยที่เป็นจุด converge (join) หรือ merge node

#### Rule 4.2.4 — Semantic Split

- ถ้า intent = `parallel.semantic_split` (สันนิษฐานว่าเป็น parallel แต่ไม่ชัดเจน):
  - ไม่ขึ้น error โดยตรง
  - แสดง warning เพื่อให้ผู้ใช้ตรวจสอบด้วยตนเอง

---

### 4.3 Endpoint Rules

ใช้ intents:
- `endpoint.missing`
- `endpoint.true_end`
- `endpoint.multi_end`
- `endpoint.unintentional_multi`

#### Rule 4.3.1 — Missing END

- ถ้า intent = `endpoint.missing`:
  - Error ระดับสูง: กราฟไม่มีจุดจบที่ชัดเจน

#### Rule 4.3.2 — True End

- ถ้า intent = `endpoint.true_end`:
  - ไม่ต้องเตือนอะไร

#### Rule 4.3.3 — Multi-End

- ถ้า intent = `endpoint.multi_end`:
  - Warning: "กราฟนี้มีหลายจุดจบที่ดูตั้งใจ" → ให้ผู้ใช้ยืนยันเอง

#### Rule 4.3.4 — Unintentional Multi-End

- intent = `endpoint.unintentional_multi`:
  - Error: ต้องให้ผู้ใช้แก้ หรือใช้ AutoFix (merge หรือ normalize) ในภายหลัง

---

### 4.4 Reachability Rules

ใช้ intents:
- `unreachable.intentional_subflow`
- `unreachable.unintentional`

#### Rule 4.4.1 — Intentional Subflow

- ไม่ error
- แค่บันทึกเป็น suggestion หรือ info

#### Rule 4.4.2 — Unintentional Unreachable

- Error: node/กลุ่ม node ที่ขาดการเชื่อมต่อจาก START
- ให้ suggestion: "อาจใช้ AutoFix เพื่อเชื่อมต่อหรือซ่อน subflow นี้"

---

### 4.5 Time Model / SLA Basic Rules

(ใช้ข้อมูลจาก Task 19.5 แต่เฉพาะ rule ง่าย ๆ)

#### Rule 4.5.1 — SLA on END

- END node ไม่ควรมี SLA

**Warning:**
- ถ้า END node มี `sla_minutes` > 0 → เตือน

#### Rule 4.5.2 — SLA on START

- START node ไม่ควรมี SLA

**Warning:**
- ถ้ามี SLA บน START → เตือน

#### Rule 4.5.3 — Isolated SLA

- ถ้า node มี SLA แต่ downstream ไม่มีไหนเลยมี SLA → Suggestion ว่า SLA นี้อาจไม่มีผลต่อภาพรวม

---

## 5. GraphValidationEngine Changes

ไฟล์: `source/BGERP/Dag/GraphValidationEngine.php`

### 5.1 Integrate SemanticIntentEngine

- เพิ่ม property:

```php
/** @var array<int, array> */
private $intents = [];
```

- ใน entry point (เช่น `validateGraph(array $nodes, array $edges, array $options = [])`):

```php
$semanticIntentEngine = new SemanticIntentEngine();
$intentResult = $semanticIntentEngine->analyzeIntent($nodes, $edges, [
    'graphId' => $options['graph_id'] ?? null,
]);

$this->intents = $intentResult['intents'] ?? [];
```

### 5.2 Add Helpers

```php
private function findIntent(string $type, ?int $nodeId = null): ?array
{
    foreach ($this->intents as $intent) {
        if ($intent['type'] !== $type) {
            continue;
        }
        if ($nodeId !== null && ($intent['node_id'] ?? null) !== $nodeId) {
            continue;
        }
        return $intent;
    }
    return null;
}
```

และ helper อื่น ๆ ตามจำเป็นสำหรับ QC/Parallel/Endpoint/Reachability

### 5.3 Extend Validation Result Structure

โครงสร้างผลลัพธ์ให้รองรับช่อง:

```php
return [
  'valid'           => true|false,
  'error_count'     => n,
  'warning_count'   => m,
  'errors'          => [...],
  'warnings'        => [...],
  'errors_detail'   => [...],
  'warnings_detail' => [...],
  'intents'         => $this->intents,
];
```

โดย `errors_detail[]` และ `warnings_detail[]` แต่ละอันสามารถมี field เพิ่ม:

```php
[
  'code'       => 'QC_MISSING_FAILURE_PATH',
  'message'    => 'QC node "QC1" has no failure path.',
  'severity'   => 'error',
  'node_id'    => 123,
  'edge_ids'   => [45, 46],
  'intent_ref' => 'qc.two_way',
]
```

---

## 6. API Changes (dag_routing_api.php)

ใน action: `graph_validate`:
- ส่งคืน `intents` ด้วย (เพื่อใช้ debug/advanced UI)

ตัวอย่าง response:

```json
{
  "ok": false,
  "error": "Graph validation failed",
  "app_code": "DAG_ROUTING_400_VALIDATION_ERRORS",
  "meta": {
    "validation": {
      "valid": false,
      "error_count": 1,
      "warning_count": 2,
      "errors_detail": [
        {
          "code": "QC_MISSING_FAILURE_PATH",
          "message": "QC node \"QC1\" has no failure path.",
          "node_id": 12,
          "intent_ref": "qc.two_way"
        }
      ],
      "warnings_detail": [...],
      "intents": [...]
    }
  }
}
```

---

## 7. Frontend (graph_designer.js)

### 7.1 Basic Integration

- ยังไม่ต้อง redesign UI ทั้งหมด
- เพิ่มเพียง:
  - แสดง intent_ref (ถ้ามี) ใน debug/advanced panel
  - อาจเพิ่ม tooltip บางส่วน เช่น:
    - "QC node detected as two-way (pass/rework)."
    - "Node detected as multi-exit operation (non-parallel)."

### 7.2 Behavior with AutoFix

- ถ้า validator พบ error ที่ AutoFix v3 มี fix ให้:
  - แสดงปุ่ม "Try Auto-Fix" ต่อไปตามเดิม (ไม่แก้ใน Task นี้)
- ถ้าเป็น warning จาก semantic split หรือ multi-end ที่ intentional:
  - ไม่ block การ save

---

## 8. Acceptance Criteria

- [ ] GraphValidationEngine เชื่อมต่อกับ SemanticIntentEngine แล้ว
- [ ] QC validation พิจารณา intent (two_way / three_way / pass_only) อย่างถูกต้อง
- [ ] Parallel/multi-exit validation แยก parallel.true_split ออกจาก operation.multi_exit
- [ ] Endpoint validation ใช้ intent เพื่อแยก multi_end vs unintentional_multi
- [ ] Reachability validation ไม่เตือน intentional_subflow แต่ error สำหรับ unreachable.unintentional
- [ ] Time/SLA basic rules ถูก enforce ระดับ warning
- [ ] graph_validate API ส่ง intents กลับใน meta.validation.intents
- [ ] UI แสดงผล semantic context อย่างน้อยในระดับ tooltip / advanced
- [ ] `task19_11_results.md` ถูกสร้างและอธิบายการเปลี่ยนแปลงจริง + known limitations

---

## 9. Notes

- เน้น **ไม่ทำลาย behavior เดิม**: legacy graphs ต้องยัง validate ได้เหมือนเดิม หรือดีกว่าเดิม (เตือนน้อยลง ไม่มากขึ้นแบบไร้เหตุผล)
- Semantic validation v3 เน้นช่วย designer ที่ "ออกแบบถูก 80%" ให้ไปถึง 100% โดยไม่รู้สึกว่าระบบบังคับเกินไป
