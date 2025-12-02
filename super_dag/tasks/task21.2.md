# Task 21.2 – Node Behavior Execution (Canonical Events Only)

**Status:** Planning  
**Owner:** Nuttaphon / Bellavier ERP Core  
**Depends on:**  
- `Node_Behavier.md` (Axioms A1–A5 + Canonical Events Section 3.9)  
- `node_behavior_model.md` (Execution Context + Behavior Principles)  
- `SuperDAG_Execution_Model.md` (Token Execution Flow)  
- `time_model.md` (เวลาและ canonical events)  
- `Task 21.1 – Node Behavior Engine (Skeleton)`  

---

## 1. Objective

สร้าง “สมองขั้นต่ำ” ให้ `NodeBehaviorEngine::executeBehavior()`:

- รับ `context` จาก `buildExecutionContext()`  
- ตัดสินใจ behavior ตาม `node_mode` + `line_type`  
- คืนค่า **canonical events เท่านั้น** (ไม่ยิง DB, ไม่ยุ่ง UI)  
- ยัง **ปิดด้วย feature flag** (`NODE_BEHAVIOR_EXPERIMENTAL`) ห้ามวิ่ง production ตรง ๆ

> เป้าหมายของ 21.2 = ให้ Behavior Engine “คิดเป็น” แล้ว  
> แต่ยังให้ Service ชั้นนอก/Token Engine เป็นคน persist ลง DB ใน Task ถัดไป (21.3+)

---

## 2. Scope

### 2.1 In-Scope

1. เติม logic ภายใน `NodeBehaviorEngine::executeBehavior()` ให้รองรับ:

   - `HAT_SINGLE` – โฟกัส Hatthasilpa work_queue node ที่ทำงานกับ token เดี่ยว  
   - `BATCH_QUANTITY` – โฟกัส Batch Node ที่ใช้จำนวน (จำนวนใน token/job context)  
   - `CLASSIC_SCAN` – เบื้องต้น: รองรับ structure canonical events แบบเบา ๆ (stub ที่ถูกต้องตามรูป)  
   - `QC_SINGLE` – เตรียมโครงสำหรับ QC Node (ไม่ต้องลงลึกทุก case ใน task นี้)

2. สร้าง helper ภายใน class:

   - `protected function resolveExecutionMode(string $nodeMode, ?string $lineType): string`
     - คืนค่า execution_mode ภายใน (เช่น `hat_single`, `hat_batch_quantity`, `classic_scan`, `qc_single`)  
     - mapping ตาม Axioms: `(node_mode, line_type) -> execution_mode`
   - `protected function buildCanonicalEvent(string $type, array $data = []): array`
     - สร้าง event record ใน format มาตรฐาน (ยังไม่ยิง DB แค่สร้าง array)

3. กำหนดโครงสร้าง `canonical_events` ให้ชัดเจน:

   ```php
   [
     [
       'event_type' => 'NODE_START',
       'token_id'   => ...,
       'node_id'    => ...,
       'job_ticket_id' => ...,
       'payload'    => [...],
       'event_time' => TimeHelper::toMysql(TimeHelper::now()),
     ],
     ...
   ]

หมายเหตุ: 21.2 แค่คืน array นี้ให้ service ชั้นบนไปตัดสินใจ persist → token_event เอง

	4.	รักษา effects เดิมไว้ชั่วคราว:
	•	map จาก canonical events หลักเป็น effects เพื่อไม่ทำให้โค้ดเก่าพัง (compat layer)
	•	ระบุใน comment ว่า 21.3–21.4 จะทยอยย้าย consumer ไปใช้ canonical_events แทน effects
	5.	เพิ่มการตั้งค่า feature flag ให้ชัดเจน:
	•	ใน service ที่จะเรียก executeBehavior() ต้องเช็ค:

if (!getFeatureFlag('NODE_BEHAVIOR_EXPERIMENTAL', false)) {
    // ข้าม logic ใหม่, ใช้ของเดิมไปก่อน
}



2.2 Out of Scope
	•	ไม่ยิง DB (ไม่ insert token_event, ไม่ update flow_token)
	•	ไม่เปลี่ยน UI / PWA / work_queue (ไว้ Task ถัดไป)
	•	ไม่ bind component จริง (แค่เตรียม COMP_BIND เพื่อใช้ในภายหลัง)

⸻

3. Design

3.1 Execution Mode Mapping

เพิ่ม method ภายใน NodeBehaviorEngine:

protected function resolveExecutionMode(?string $nodeMode, ?string $lineType): ?string
{
    if (!$nodeMode) {
        return null;
    }

    switch ($nodeMode) {
        case 'HAT_SINGLE':
            // Hatthasilpa line เท่านั้น
            if ($lineType === 'hatthasilpa') {
                return 'hat_single';
            }
            // ถ้ามา Classic → ยังไม่รองรับ, ให้ return null หรือโยน error ในอนาคต
            return null;

        case 'BATCH_QUANTITY':
            if ($lineType === 'hatthasilpa') {
                return 'hat_batch_quantity';
            }
            // Classic line ยังไม่โฟกัสใน 21.2
            return null;

        case 'CLASSIC_SCAN':
            if ($lineType === 'classic') {
                return 'classic_scan';
            }
            return null;

        case 'QC_SINGLE':
            // ใช้ได้ทั้งสอง line, แล้วแต่ context
            return 'qc_single';

        default:
            return null;
    }
}

NOTE: 21.2 ยังไม่โยน exception แรง ๆ แต่ให้ return null + log warning.
Task 21.x หลังจาก PoC ผ่านแล้ว อาจปรับเป็น exception ที่ควบคุมได้

3.2 Canonical Event Builder

ภายใน NodeBehaviorEngine:

protected function buildCanonicalEvent(string $type, array $context, array $payload = []): array
{
    $token    = $context['token']      ?? [];
    $node     = $context['node']       ?? [];
    $job      = $context['job_ticket'] ?? [];
    $now      = $context['time']['now'] ?? TimeHelper::now();

    return [
        'event_type'    => $type, // e.g. NODE_START, NODE_COMPLETE, COMP_BIND
        'token_id'      => $token['id_token'] ?? null,
        'node_id'       => $node['id_node']   ?? null,
        'job_ticket_id' => $job['id_job_ticket'] ?? null,
        'payload'       => $payload,
        'event_time'    => TimeHelper::toMysql($now),
    ];
}

21.2: ยังไม่ insert DB
21.3: จะให้ service ภายนอก convert array นี้ → insert token_event

3.3 Behavior Skeleton per Execution Mode

ใน executeBehavior():

public function executeBehavior(array $context): array
{
    $nodeMode  = $context['execution']['node_mode'] ?? null;
    $lineType  = $context['execution']['line_type'] ?? null;

    $executionMode = $this->resolveExecutionMode($nodeMode, $lineType);

    $canonicalEvents = [];

    switch ($executionMode) {
        case 'hat_single':
            $canonicalEvents = $this->executeHatSingle($context);
            break;

        case 'hat_batch_quantity':
            $canonicalEvents = $this->executeHatBatchQuantity($context);
            break;

        case 'classic_scan':
            $canonicalEvents = $this->executeClassicScan($context);
            break;

        case 'qc_single':
            $canonicalEvents = $this->executeQcSingle($context);
            break;

        default:
            // Unknown / unsupported combination
            $canonicalEvents = [];
            break;
    }

    // TODO 21.2: แปลง canonicalEvents → legacy effects (ถ้าจำเป็น)
    $effects = $this->mapCanonicalEventsToLegacyEffects($canonicalEvents, $context);

    return [
        'ok'               => true,
        'node_mode'        => $nodeMode,
        'line_type'        => $lineType,
        'execution_mode'   => $executionMode,
        'canonical_events' => $canonicalEvents,
        'effects'          => $effects,
        'meta'             => [
            'version'   => '21.2',
            'executed'  => true,
            'timestamp' => TimeHelper::toMysql(TimeHelper::now()),
        ],
    ];
}

แล้วเพิ่ม method ย่อย:

protected function executeHatSingle(array $context): array
{
    $events = [];

    // 21.2: focus case "complete node" ขั้นต่ำ
    $events[] = $this->buildCanonicalEvent('NODE_COMPLETE', $context, [
        'reason' => 'normal',
    ]);

    // placeholder: ในอนาคตอาจมี NODE_START, NODE_PAUSE, NODE_RESUME
    return $events;
}

อื่น ๆ:
	•	executeHatBatchQuantity(array $context): array
	•	executeClassicScan(array $context): array
	•	executeQcSingle(array $context): array

21.2: กล้า minimal ได้ เพราะยังอยู่หลัง feature flag
Task 21.3–21.4 ค่อยไล่เติมเคสย่อยแต่ละ mode ให้ครบ

⸻

4. Testing

4.1 Unit Test
	•	สำหรับ resolveNodeMode() (ของเดิม)
	•	สำหรับ resolveExecutionMode()
	•	สำหรับ executeBehavior() ในโหมด:
	•	HAT_SINGLE + hatthasilpa
	•	BATCH_QUANTITY + hatthasilpa
	•	CLASSIC_SCAN + classic
	•	QC_SINGLE (ทั้งสอง line)
	•	ทดสอบว่า:
	•	canonical_events มี shape ถูกต้อง
	•	event_type อยู่ใน whitelist (TOKEN_, NODE_, OVERRIDE_, COMP_, INVENTORY_*)
	•	ไม่มี field แปลก ๆ นอก schema

4.2 Feature Flag
	•	ทดสอบ service ที่เรียก executeBehavior():
	•	เมื่อ flag = false → ไม่โดน logic ใหม่
	•	เมื่อ flag = true  → ได้ canonical_events กลับมา

⸻

5. Migration / DB Impact
	•	Task 21.2: ไม่มี migration ใหม่
	•	ใช้แค่ TimeHelper + current schema (flow_token, routing_node, work_center, job_ticket)
	•	Canonical events ยังไม่ insert DB ใน task นี้

⸻

6. Rollout Plan
	1.	พัฒนา + test logic ใน Engine
	2.	เปิดใช้ใน dev/staging ด้วย NODE_BEHAVIOR_EXPERIMENTAL = true
	3.	ให้ Execution Model / Token Service เรียกใช้เพื่อ inspect canonical_events (ไม่ persist)
	4.	ปรับจูนจน shape ของ events stable
	5.	Task 21.3: wiring canonical events → token_event table จริง + เริ่มใช้แทน effects

⸻

7. Done Criteria
	•	NodeBehaviorEngine::executeBehavior():
	•	คืน canonical_events ที่ถูกต้องตามสเปก
	•	ไม่มี DB write ใด ๆ เกิดจาก method นี้
	•	ทุก execution mode ที่อยู่ใน scope มี unit test ครอบ
	•	Feature flag ป้องกันไม่ให้ logic นี้วิ่งโดยไม่ตั้งใจใน production
	•	เอกสาร node_behavior_model.md และ Node_Behavier.md ยังสอดคล้อง ไม่ต้องแก้อะไรเพิ่มจาก logic 21.2

---