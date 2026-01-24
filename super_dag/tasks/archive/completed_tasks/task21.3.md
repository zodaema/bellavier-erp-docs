# Task 21.3 – Persist Canonical Events to token_event + Deepen Behavior Logic

**Status:** PLANNING  
**Date:** 2025-01-XX  
**Category:** SuperDAG / Node Behavior Engine / Canonical Events  

**Depends on:**  
- Task 21.1 – Node Behavior Engine (Skeleton)  
- Task 21.2 – Node Behavior Execution (Canonical Events Only)  
- `Node_Behavier.md` (Axioms + Canonical Events Section 3.9)  
- `node_behavior_model.md` (Execution Context + Canonical Integration)  
- `SuperDAG_Execution_Model.md`  
- `time_model.md` (Canonical Time Model & Events)  
- `core_principles_of_flexible_factory_erp.md` (ข้อ 13–15: Closed Logic, Canonical Events, Golden Rule)

---

## 1. Objective

ทำให้ Canonical Events **เปลี่ยนจาก “คิดได้” → “บันทึกจริง”**:

1. Persist canonical events จาก `NodeBehaviorEngine::executeBehavior()` ลง table `token_event`
2. เริ่มเติม behavior logic ที่ลึกขึ้นสำหรับ execution mode หลัก:
   - `hat_single`
   - `hat_batch_quantity`
   - `classic_scan`
   - `qc_single`
3. ยังคง **อยู่หลัง feature flag** (`NODE_BEHAVIOR_EXPERIMENTAL`)  
   แต่คราวนี้จะมีผลกับฐานข้อมูลจริง (เขียน event ลง DB)

> เป้าหมาย Task 21.3 = Event Pipeline ทำงานครบ “คิดได้ + เขียนได้”  
> แต่ยังไม่บังคับ consumer ฝั่งอื่นต้องอ่าน canonical events แทนของเดิมทั้งหมด

---

## 2. Scope

### 2.1 In-Scope

1. **สร้าง / ปรับ schema ตาราง `token_event`**
   - ถ้ามีอยู่แล้ว → ตรวจสอบให้ align กับ Canonical Event Framework  
   - ถ้ายังไม่มี → เพิ่ม migration ใหม่สำหรับ core DB

   **โครงขั้นต่ำ (อ้างอิง spec เดิม):**
   ```sql
   CREATE TABLE token_event (
       id_event        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
       id_token        BIGINT UNSIGNED NULL,
       id_node         BIGINT UNSIGNED NULL,
       id_job_ticket   BIGINT UNSIGNED NULL,
       event_type      VARCHAR(64) NOT NULL,
       event_time      DATETIME NOT NULL,
       duration_ms     BIGINT NULL,
       payload_json    JSON NULL,
       created_at      DATETIME NOT NULL,
       created_by      VARCHAR(64) NULL,
       INDEX idx_token_time (id_token, event_time),
       INDEX idx_node_time (id_node, event_time),
       INDEX idx_event_type_time (event_type, event_time)
   ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

หมายเหตุ: ถ้ามี field บางตัวอยู่แล้ว (เช่น cid, tenant_code) ให้ reuse ตามมาตรฐาน BGERP

	2.	สร้าง Service/Repository สำหรับเขียน event
	•	ตัวอย่าง: BGERP\Dag\TokenEventService
	•	หน้าที่:
	•	รับ array ของ canonical_events จาก Behavior Engine
	•	Validate event_type ให้อยู่ใน whitelist
	•	Insert ลง token_event ภายใต้ transaction ที่เหมาะสม
	3.	ปรับ TokenLifecycleService::completeToken()
	•	หลังจาก NodeBehaviorEngine::executeBehavior() แล้ว:
	•	เรียก TokenEventService::persistEvents($canonicalEvents)
	•	ยังอยู่หลัง feature flag:

if ($ffs->getFlag('NODE_BEHAVIOR_EXPERIMENTAL', false, $tenantScope)) {
    // executeBehavior()
    // persist canonical_events
}


	4.	เติม Behavior Logic เพิ่มใน execution handlers
	•	executeHatSingle():
	•	นอกจาก NODE_COMPLETE ให้รองรับ NODE_START ในกรณีเริ่มทำงานจาก context ที่เหมาะสม
	•	executeHatBatchQuantity():
	•	พิจารณากรณี batch complete ที่มีจำนวน shortfall (เตรียม TOKEN_SHORTFALL หรือ payload ระบุจำนวน)
	•	executeClassicScan():
	•	รองรับการ emit NODE_COMPLETE ที่สอดคล้องกับ Scan Flow (classic line)
	•	executeQcSingle():
	•	รองรับ NODE_COMPLETE พร้อม payload ผล QC (pass/fail, reason)
ยังไม่ต้องทำทุก branch ให้ครบแค่ case หลักที่ใช้จริง ใน flow ปัจจุบัน
ที่เหลือเก็บไว้ใน Task 21.x ถัดไป
	5.	Logging & Diagnostics
	•	ถ้า persist events สำเร็จ → log summary (จำนวน events, token, node)
	•	ถ้า persist ล้มเหลว → log error และ behavior ควร “ไม่บล็อก” token completion (เหมือน 21.2)

⸻

2.2 Out-of-Scope
	•	ยังไม่บังคับให้ Time Engine / UI / Reporting อ่านจาก token_event เป็นหลัก
	•	ยังไม่ลบ / deprecate legacy effects หรือ field เวลาใน flow_token
	•	ยังไม่รองรับทุก combination ของ node_mode + line_type (ให้โฟกัส use case ปัจจุบันก่อน)

⸻

3. Design

3.1 TokenEventService

ไฟล์ที่คาดหวัง:
source/BGERP/Dag/TokenEventService.php (หรือใน namespace ที่เหมาะสม)

หน้าที่หลัก:

namespace BGERP\Dag;

use BGERP\Library\TimeHelper;

class TokenEventService
{
    protected \PDO $db;

    /** @var string[] */
    protected array $allowedTypes = [
        'TOKEN_CREATE',
        'TOKEN_SHORTFALL',
        'TOKEN_ADJUST',
        'TOKEN_SPLIT',
        'TOKEN_MERGE',
        'NODE_START',
        'NODE_PAUSE',
        'NODE_RESUME',
        'NODE_COMPLETE',
        'NODE_CANCEL',
        'OVERRIDE_ROUTE',
        'OVERRIDE_TIME_FIX',
        'OVERRIDE_TOKEN_ADJUST',
        'COMP_BIND',
        'COMP_UNBIND',
        'INVENTORY_MOVE',
    ];

    public function __construct(\PDO $db)
    {
        $this->db = $db;
    }

    /**
     * @param array<int,array<string,mixed>> $events
     */
    public function persistEvents(array $events, ?string $createdBy = null): void
    {
        if (empty($events)) {
            return;
        }

        $nowMysql = TimeHelper::toMysql(TimeHelper::now());

        $sql = "INSERT INTO token_event
            (id_token, id_node, id_job_ticket, event_type, event_time, duration_ms, payload_json, created_at, created_by)
            VALUES (:id_token, :id_node, :id_job_ticket, :event_type, :event_time, :duration_ms, :payload_json, :created_at, :created_by)";

        $stmt = $this->db->prepare($sql);

        foreach ($events as $event) {
            if (!$this->isAllowedType($event['event_type'] ?? null)) {
                // skip or log warning
                continue;
            }

            $payload = $event['payload'] ?? [];
            $eventTime = $event['event_time'] ?? $nowMysql;

            $stmt->execute([
                ':id_token'      => $event['token_id'] ?? null,
                ':id_node'       => $event['node_id'] ?? null,
                ':id_job_ticket' => $event['job_ticket_id'] ?? null,
                ':event_type'    => $event['event_type'],
                ':event_time'    => $eventTime,
                ':duration_ms'   => $event['duration_ms'] ?? null,
                ':payload_json'  => json_encode($payload, JSON_UNESCAPED_UNICODE),
                ':created_at'    => $nowMysql,
                ':created_by'    => $createdBy,
            ]);
        }
    }

    protected function isAllowedType(?string $type): bool
    {
        if (!$type) {
            return false;
        }
        return in_array($type, $this->allowedTypes, true);
    }
}

Task 21.3 = persist only
Task 21.4 หรือหลังจากนั้นค่อยสร้าง Query / Reporting Service สำหรับอ่าน events

⸻

3.2 Integration Flow (completeToken)

ก่อน Task 21.3:
	•	completeToken → logic เดิม (update flow_token, ฯลฯ)
	•	ถ้า feature flag เปิด → เรียก NodeBehaviorEngine → canonical_events → log-only

หลัง Task 21.3:

if ($ffs->getFlag('NODE_BEHAVIOR_EXPERIMENTAL', false, $tenantScope)) {
    try {
        $node = $this->fetchNode($token['current_node_id']);
        if ($node) {
            $behaviorEngine = new NodeBehaviorEngine($this->db);
            $context        = $behaviorEngine->buildExecutionContext($token, $node);
            $behaviorResult = $behaviorEngine->executeBehavior($context);

            $canonicalEvents = $behaviorResult['canonical_events'] ?? [];
            if (!empty($canonicalEvents)) {
                $eventService = new TokenEventService($this->db);
                $eventService->persistEvents($canonicalEvents, $this->currentUserCode() ?? null);

                error_log(sprintf(
                    '[CID:%s][NodeBehaviorEngine] Token %d completed at node %d: %d canonical events persisted',
                    $GLOBALS['cid'] ?? 'UNKNOWN',
                    $tokenId,
                    $token['current_node_id'],
                    count($canonicalEvents)
                ));
            }
        }
    } catch (\Exception $e) {
        error_log(...); // log แล้วปล่อยให้ token completion ทำงานต่อ
    }
}

Important:
	•	Token completion ยังต้องสำเร็จ แม้ persist events จะ fail
	•	ในอนาคต (หลัง PoC ผ่าน) เราอาจเพิ่มโหมด strict ที่ถ้า event เขียนไม่ได้ให้ถือว่าผิด flow

⸻

3.3 Behavior Logic Deepening

เน้นไปที่ กรณี “complete” + ข้อมูลสำคัญที่จำเป็นต่อ Time / QC / Component:
	•	HAT_SINGLE
	•	กรณี complete ปกติ: NODE_COMPLETE + payload:
	•	reason = 'normal'
	•	optional: ถ้า context มีข้อมูลเวลาทำงาน session → เตรียม duration_ms (ยังไม่บังคับ)
	•	HAT_BATCH_QUANTITY
	•	NODE_COMPLETE
	•	ถ้ามี shortfall (จำนวนทำจริง < จำนวน target):
	•	อาจเตรียม payload: { "produced": X, "planned": Y, "shortfall": Y - X }
	•	ยังไม่ต้องสร้าง TOKEN_SHORTFALL event แยกใน Task นี้ (แค่เตรียมโครง)
	•	CLASSIC_SCAN
	•	เมื่อ Scan complete node → NODE_COMPLETE
	•	payload อาจระบุว่า scan ผ่านช่องทางไหน (PWA / desktop) ไว้ใน field ย่อย
	•	QC_SINGLE
	•	NODE_COMPLETE + payload:
	•	qc_result = 'pass' | 'fail'
	•	qc_reason (กรณี fail)
	•	ยังไม่ต้อง route rework ใน Task นี้ (เป็นของ SuperDAG Routing / QC task แยก)

⸻

4. Safety & Feature Flag
	•	ทุก call ของ Behavior Engine + TokenEventService:
	•	ต้องอยู่ภายใต้ NODE_BEHAVIOR_EXPERIMENTAL
	•	ถ้า flag ปิด → ระบบทำงานแบบเดิม (ไม่มี event ใหม่, ไม่มีผลกับ DB)
	•	ถ้า flag เปิด:
	•	Behavior Engine generate canonical events
	•	TokenEventService persist ลง token_event
	•	ถ้าเกิด error → log แล้วอนุญาตให้ token completion สำเร็จต่อ

⸻

5. Testing

5.1 DB Migration / Schema
	•	ตรวจว่า token_event มีอยู่จริง + column ครบ
	•	ถ้าเป็น migration ใหม่ ต้อง include ใน installer/upgrade script ของ core DB

5.2 Integration Test (Manual)

ใน dev/staging (เปิด feature flag):
	1.	Case: HAT_SINGLE, hatthasilpa
	•	complete token
	•	ตรวจ token_event ว่ามี NODE_COMPLETE event, event_time, payload ถูก
	2.	Case: BATCH_QUANTITY, hatthasilpa
	•	complete batch node
	•	ตรวจ event, payload จำนวน/shortfall (ถ้ามี)
	3.	Case: CLASSIC_SCAN, classic
	•	ใช้ flow ที่ scan จริง (หรือ simulate)
	•	ตรวจ token_event ว่ามี event ตามคาด
	4.	Case: QC_SINGLE
	•	complete QC node (pass / fail)
	•	ตรวจ payload ว่าเก็บผล QC ถูกต้อง
	5.	Error path:
	•	จำลองให้ DB error (เช่น ปิด permission INSERT token_event)
	•	ยืนยันว่า:
	•	token completion ยัง success
	•	error ถูก log

⸻

6. Done Criteria
	•	✅ token_event table พร้อมใช้งานตาม Canonical Event Framework
	•	✅ TokenEventService สามารถ persist canonical events ได้จริง
	•	✅ completeToken() persist canonical events เมื่อ flag เปิด
	•	✅ Behavior Engine ใน execution modes ที่อยู่ใน scope:
	•	สร้าง canonical events ถูกต้องสำหรับเคสหลัก
	•	✅ ไม่มี breaking change กับ flow เดิมเมื่อ feature flag ปิด
	•	✅ มี log ที่เพียงพอสำหรับ debug ใน dev/staging

⸻

7. Alignment
	•	✅ ตรงกับ Node_Behavier.md (Axioms + Canonical Events Section 3.9)
	•	✅ ตรงกับ time_model.md (เวลาอิงจาก canonical events)
	•	✅ ตรงกับ Core Principles 13–15:
	•	Closed Logic, Flexible Operations
	•	Canonical Event Framework
	•	Golden Rule: Reality อิสระได้ แต่ Logic ห้ามงอ
	•	✅ สอดคล้องกับผลของ Task 21.2 (executeBehavior() คืน canonical_events แล้ว)

---