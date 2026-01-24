# Task 19.10.1 — Implement SemanticIntentEngine.php (v1.0)

**Status:** IMPLEMENTATION TASK  
**Depends on:**
- `docs/super_dag/semantic_intent_rules.md`
- `docs/super_dag/autofix_risk_scoring.md`
- `source/BGERP/Dag/SemanticIntentEngine.php` (skeleton already exists)
- Task 19.8, 19.9, 19.10

---

## 1. Objective

เติมความสามารถให้ `SemanticIntentEngine.php` ให้สอดคล้องกับเอกสาร:
- `semantic_intent_rules.md`
- `autofix_risk_scoring.md`

โดยไม่สร้างไฟล์ใหม่ แต่ **patch/implement** ภายในไฟล์เดิม ให้สามารถวิเคราะห์ "เจตนา" (intent) ของกราฟได้จริง และใช้เป็น input ให้ AutoFix v3 + GraphValidationEngine v3.

> เป้าหมายหลัก: ให้ `SemanticIntentEngine->analyzeIntent()` คืนผลลัพธ์ที่เพียงพอสำหรับการ:
> - แยก QC แบบ 2-way / 3-way / pass-only
> - แยก multi-exit vs parallel
> - แยก endpoint ที่ตั้งใจ vs ผิดพลาด
> - แยก unreachable ที่ตั้งใจ (subflow) vs ผิดพลาด
> - ลด noise ของ validation (เช่น operation.linear_only)

---

## 2. Scope

### In-Scope
- Implement logic ภายใน `SemanticIntentEngine.php` ทั้ง 4 กลุ่มหลัก:
  1. QC Intents
  2. Parallel / Multi-exit Intents
  3. Endpoint Intents
  4. Reachability Intents
- เพิ่ม intent ใหม่ให้ครบตาม spec:
  - `qc.two_way`
  - `qc.three_way`
  - `qc.pass_only`
  - `operation.multi_exit`
  - `operation.linear_only`
  - `parallel.true_split`
  - `parallel.semantic_split`
  - `endpoint.missing`
  - `endpoint.true_end`
  - `endpoint.multi_end`
  - `endpoint.unintentional_multi`
  - `unreachable.intentional_subflow`
  - `unreachable.unintentional`
- เติม `evidence` fields ตามที่ระบุใน `semantic_intent_rules.md` (เช่น `total_outgoing`, `has_pass_edge`, `has_rework_edges`, ฯลฯ)
- ผูกแต่ละ intent กับ base risk จาก `autofix_risk_scoring.md` (แต่ **ยังไม่ต้องคำนวณ total risk** ในไฟล์นี้)

### Out-of-Scope
- ไม่ยุ่งกับ AutoFixEngine (v3) ใน task นี้ — แค่เตรียมข้อมูลให้พร้อม
- ไม่เปลี่ยนแปลง GraphValidationEngine
- ไม่ใช้ DB / ไม่ query database — ทำงานจาก `nodes` / `edges` array เท่านั้น

---

## 3. Expected API

### 3.1 Class Signature

ไฟล์: `source/BGERP/Dag/SemanticIntentEngine.php`

```php
class SemanticIntentEngine
{
    /**
     * @param array $nodes Normalized nodes from graph loader
     * @param array $edges Normalized edges from graph loader
     * @param array $options Optional flags (e.g., ['graphId' => ..., 'mode' => 'draft'|'publish'])
     * @return array {
     *   'intents' => IntentDefinition[],
     *   'patterns' => string[],
     * }
     */
    public function analyzeIntent(array $nodes, array $edges, array $options = []): array
    {
        // Implement in this task
    }
}
```

### 3.2 IntentDefinition structure

```php
[
    'type'       => 'qc.two_way',
    'scope'      => 'node',          // 'node' | 'edge' | 'graph'
    'node_id'    => 123,             // optional if scope != node
    'edge_id'    => null,            // optional
    'confidence' => 0.90,            // 0.0 - 1.0
    'risk_base'  => 10,              // base risk from autofix_risk_scoring
    'evidence'   => [                // arbitrary structured info
        'total_outgoing'     => 2,
        'has_pass_edge'      => true,
        'has_rework_edges'   => true,
        'has_fail_edges'     => false,
    ],
    'notes'      => 'QC node with pass + rework only (2-way)',
]
```

### 3.3 Return Format

```php
return [
    'intents'  => $intents,  // list of IntentDefinition
    'patterns' => $patterns, // list of human-readable strings (optional)
];
```

`patterns` ใช้สำหรับ debug / UI optional เช่น:
- "QC node QC1 appears to be 2-way (pass/rework)"
- "Node CUT1 appears to be a multi-exit operation (non-parallel)"

---

## 4. Implementation Details

### 4.1 QC Intent Analysis

ฟังก์ชันภายใน (ตัวอย่างชื่อ):

```php
private function analyzeQCRoutingIntent(array $nodes, array $edges, array &$intents, array &$patterns): void
```

#### Logic หลัก (ต่อ node type = 'qc')

สำหรับแต่ละ QC node:
- รวบรวม outgoing edges
- แยกโดยประเภท edge:
  - `pass_edges` → เงื่อนไข `qc_result.status == pass`
  - `fail_minor_edges`
  - `fail_major_edges`
  - `rework_edges` → edge type = 'rework' หรือปลายทาง behavior = REWORK_SINK

จากนั้นจัด intent ตาม pattern:

1. **`qc.pass_only`**
   - has_pass_edge = true
   - has_rework_edges = false
   - has_fail_edges = false
   → สร้าง IntentDefinition ที่ type = `qc.pass_only`

2. **`qc.two_way`**
   - has_pass_edge = true
   - has_rework_edges = true
   - ไม่มีการแยก minor/major ชัดเจน (ไม่มี fail_minor/fail_major เฉพาะ)
   → สร้าง `qc.two_way`

3. **`qc.three_way`**
   - มีอย่างน้อย 3 เส้นทางแยก: pass, fail_minor, fail_major
   → สร้าง `qc.three_way`

> หมายเหตุ: ถ้า pattern ซ้อนกัน (เช่น detect pass_only + two_way) ให้เลือก **intent ที่มี confidence สูงสุด** หรือสร้างหลาย intent ได้ แต่ต้องใส่หลักฐานให้ชัดเจน

ทุก intent จาก QC ต้องเติม `evidence` ตามเอกสาร semantic_intent_rules เช่น:

```php
'evidence' => [
    'total_outgoing'   => $totalOutgoing,
    'has_pass_edge'    => $hasPass,
    'has_rework_edges' => $hasRework,
    'has_fail_edges'   => $hasFailEdges,
],
```

และ map `risk_base` จาก `autofix_risk_scoring.md` (เช่น qc.two_way = 10, qc.three_way = 40).

---

### 4.2 Parallel / Multi-Exit Intent Analysis

ฟังก์ชันภายใน:

```php
private function analyzeParallelIntent(array $nodes, array $edges, array &$intents, array &$patterns): void
```

#### สำหรับแต่ละ operation node:

- นับจำนวน outgoing edges
- ตรวจว่า:
  - มี rework edge หรือไม่ (`edge_type = 'rework'` หรือปลายทาง behavior = REWORK_SINK)
  - มี conditional edges หรือไม่

จากนั้น:

1. **`operation.linear_only`**
   - `total_outgoing = 1`
   - ไม่มี conditional / rework / parallel flags
   → สร้าง intent `operation.linear_only` (risk_base=0, ใช้แค่ลด noise)

2. **`operation.multi_exit`**
   - `total_outgoing > 1`
   - มี rework หรือ scrap หรือ conditional ออกหลายทาง
   - แต่ไม่มีการตั้งค่า parallel flags ชัดเจน
   → สร้าง intent `operation.multi_exit`

3. **`parallel.true_split`**
   - `total_outgoing >= 2`
   - ปลายทางทั้งหมดเป็น operation node ปกติ (ไม่ใช่ QC/Rework/Sink)
   - มี parallel flags หรือ execution_mode บ่งบอก
   → สร้าง intent `parallel.true_split`

4. **`parallel.semantic_split`**
   - ไม่เข้าเคสด้านบนแบบชัดเจน แต่มีโอกาสเป็น parallel (เช่น time-critical branches)
   → สร้าง intent `parallel.semantic_split` พร้อม risk สูงกว่า

เติม `evidence` เช่น:

```php
'evidence' => [
    'total_outgoing'        => $totalOutgoing,
    'has_rework_edges'      => $hasRework,
    'has_conditional_edges' => $hasConditional,
    'has_parallel_flag'     => $hasParallelFlag,
],
```

---

### 4.3 Endpoint Intent Analysis

ฟังก์ชันภายใน:

```php
private function analyzeEndpointIntent(array $nodes, array $edges, array &$intents, array &$patterns): void
```

- หา nodes ที่ไม่มี outgoing edges → candidate END
- หา nodes ที่มี flag `is_end` หรือ behavior/category เป็น END

Cases:

- ไม่มี END เลย → สร้าง intent `endpoint.missing` (scope='graph')
- มี END เดียว → `endpoint.true_end`
- มี END หลายตัว → วิเคราะห์ว่า intentional หรือไม่:
  - ถ้าอยู่คนละสาขาชัดเจน → `endpoint.multi_end`
  - ถ้าดูเหมือนแบ่ง END แบบมั่ว → `endpoint.unintentional_multi`

หลักฐาน เช่น:

```php
'evidence' => [
    'end_node_ids' => $endNodeIds,
    'count_end'    => count($endNodeIds),
],
```

---

### 4.4 Reachability Intent Analysis

ฟังก์ชันภายใน:

```php
private function analyzeReachabilityIntent(array $nodes, array $edges, array &$intents, array &$patterns): void
```

- สร้าง graph traversal จาก START → node อื่น ๆ
- หา nodes ที่ไม่ถูกเข้าถึง

จัดกลุ่ม unreachable:

1. **`unreachable.intentional_subflow`**
   - กลุ่ม node หลายตัวต่อกันเองเป็นสาระ (subgraph)
   - มี pattern เช่น เริ่มด้วย node ประเภท TEMPLATE, หรือ behavior category เฉพาะที่ใช้เป็น reference

2. **`unreachable.unintentional`**
   - Node เดี่ยว ๆ หรือกลุ่มเล็ก ๆ ที่ดูเหมือนถูกลืม
   - ใช้ risk_base จาก `CONNECT_UNREACHABLE` (65, High + Suggest-only)

หลักฐานเช่น:

```php
'evidence' => [
    'unreachable_node_ids' => $nodeIds,
    'component_size'       => $componentSize,
],
```

---

## 5. Integration Notes

- Task 19.10.1 ยัง **ไม่ต้องผูก SemanticIntentEngine เข้ากับ AutoFixEngine** — แค่ให้ `analyzeIntent()` คืนข้อมูลได้ครบถ้วน
- AutoFixEngine v3 (ใน Task 19.10 main) จะเรียก `analyzeIntent()` และใช้ `intents` + `evidence` + risk_base จากไฟล์นี้ไปคำนวณ risk รวมเอง
- GraphValidationEngine v3 (19.11) สามารถใช้ `intents` เพื่อปรับระดับ error/warning

---

## 6. Acceptance Criteria

- [ ] `SemanticIntentEngine::analyzeIntent()` คืน `intents` ครบทุก type ตาม spec
- [ ] มี QC intents: `qc.two_way`, `qc.three_way`, `qc.pass_only`
- [ ] มี parallel/multi-exit intents: `operation.linear_only`, `operation.multi_exit`, `parallel.true_split`, `parallel.semantic_split`
- [ ] มี endpoint intents: `endpoint.missing`, `endpoint.true_end`, `endpoint.multi_end`, `endpoint.unintentional_multi`
- [ ] มี reachability intents: `unreachable.intentional_subflow`, `unreachable.unintentional`
- [ ] ทุก intent มี `confidence`, `risk_base`, `evidence` ครบถ้วน
- [ ] ไม่ query DB ภายใน SemanticIntentEngine
- [ ] ไม่แก้ไข nodes/edges (pure analysis only)
- [ ] มี `task19_10_1_results.md` สรุปสิ่งที่ทำจริง + ข้อจำกัด (ถ้ามี)

