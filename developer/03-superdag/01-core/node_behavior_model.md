# Node Behavior Model (Aligned with Node_Behavier.md)

**Status:** Active Documentation  
**Date:** 2025-01-XX  
**Version:** 2.0 (Task 21.1-21.8 - Completed)  
**Category:** SuperDAG / Node Behavior Engine

**⚠️ CRITICAL:** This document is aligned with `Node_Behavier.md` canonical spec.  
**Key Principle:** Node Mode is defined at Work Center level, NOT at Node level.

**Status:** ✅ **IMPLEMENTED** (Task 21.1-21.8 completed)
- Task 21.1: NodeBehaviorEngine skeleton ✅
- Task 21.2: Canonical events generation ✅
- Task 21.3: TokenEventService integration ✅
- Task 21.5: TimeEventReader for timeline ✅
- Task 21.7: CanonicalEventIntegrityValidator ✅
- Task 21.8: BulkIntegrityValidator ✅

---

## 1. Overview

The **Node Behavior Model** defines how SuperDAG nodes execute based on **Node Mode** from Work Centers, integrated with Time Engine, Component Binding, and execution semantics.

**Core Concept (from Node_Behavier.md):**
- **Node Mode** (BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE) is defined at **Work Center** level
- Node "receives" `node_mode` from the Work Center it is bound to
- Runtime uses `(workCenter.node_mode, job.line_type)` to determine execution mode
- Designer does NOT choose node_mode directly - only binds Node to Work Center

This document establishes the conceptual foundation for the Node Behavior Engine, which will be implemented incrementally across Tasks 21.1–21.x.

---

## 2. Core Concepts (Aligned with Node_Behavier.md)

### 2.1 Node Mode (from Work Center)

**Node Mode (`node_mode`):**
- **Purpose:** Execution behavior classification (Framework-level enum)
- **Location:** Stored in `work_center.node_mode` (NOT in `routing_node`)
- **Examples:** `BATCH_QUANTITY`, `HAT_SINGLE`, `CLASSIC_SCAN`, `QC_SINGLE`
- **Scope:** Execution semantics, UI rendering, Time Engine behavior, Token/Batch Session creation
- **Immutable at Node Level:** Node receives node_mode from Work Center, cannot override

**Key Axioms (from Node_Behavier.md):**

**AXIOM A2 – Work Center คือคนกำหนด Node Mode (Behavior Code)**
- ตาราง `work_centers` ต้องมีฟิลด์ `node_mode` (enum) เสมอ
- Node ในกราฟ **ต้องไม่ได้กำหนด node_mode เอง** แต่ "รับ" จาก Work Center ที่ผูกอยู่
- Work Center CRUD คือที่เดียวที่ให้ตั้งค่า `node_mode` ได้ (ผ่านการเลือกจาก enum)

**AXIOM A3 – Runtime ตีความจาก (node_mode + line_type)**
- Execution จริง (UI, Time Engine, Scan Flow ฯลฯ) = ฟังก์ชันของคู่:
  - `workCenter.node_mode`
  - `job.line_type` (`classic` หรือ `hatthasilpa`)

**AXIOM A4 – Designer เป็นกลางในแง่ Behavior**
- ในหน้าจอ DAG Designer:
  - Designer เลือก Node + Work Center เท่านั้น
  - ไม่ให้เลือก/แก้ `node_mode` ที่ระดับ Node

### 2.2 Node Type vs Node Mode

**Node Type (`node_type`):**
- **Purpose:** Structural classification of the node in the graph topology
- **Examples:** `operation`, `qc`, `wait`, `decision`, `start`, `end`, `split`, `join`, `subgraph`
- **Scope:** Graph structure, routing logic, parallel/merge semantics
- **Location:** `routing_node.node_type`

**Node Mode (`node_mode`):**
- **Purpose:** Execution behavior classification (Framework-level enum)
- **Examples:** `BATCH_QUANTITY`, `HAT_SINGLE`, `CLASSIC_SCAN`, `QC_SINGLE`
- **Scope:** Execution semantics, UI rendering, Time Engine behavior
- **Location:** `work_center.node_mode` (Node receives from Work Center)

**Key Distinction:**
- A node with `node_type='operation'` can have `node_mode='BATCH_QUANTITY'` or `node_mode='HAT_SINGLE'`
- Both are operations, but they execute differently based on node_mode
- Node Mode determines: batch vs single, work_queue vs PWA scan, time tracking method

---

## 3. Node Mode Catalog (from Node_Behavier.md)

### 3.1 BATCH_QUANTITY (Cutting / Prep)

**Use Case:**
- ขั้นตอนที่ทำงานแบบ Batch เช่น CUTTING, SKIVING, PREP COMPONENTS
- ช่างตัดชิ้นส่วนสำหรับกระเป๋า 10 ใบในครั้งเดียว

**Behavior:**
- เมื่อเริ่มงาน: System ถามจำนวน (qty), สร้าง `batch_session`
- Time Engine: จับเวลาทั้ง batch (start → pause/resume → complete)
- Token: การ "แตกตัวเป็นหลาย Token" ที่ Node ถัดไป (เช่น จาก batch ไปที่ `HAT_SINGLE`)

**Config Examples (ใน Work Center `config_json`):**
```json
{
  "require_quantity": true,
  "default_quantity": 10,
  "max_quantity": 50,
  "time_distribution": "even"
}
```

#### 3.1.1 Canonical Principle: Batch Mode Must Not Encode Line
Node Mode ต้องไม่ encode line_type เข้าไปใน enum เช่น `HAT_BATCH` หรือ `CLASSIC_BATCH`.

**เหตุผล:**
- Node Mode = “พฤติกรรมกลาง” (Behavior Type)
- Line Type = “เงื่อนไขการรัน” (Execution Context)
- ถ้า encode รวมกัน enum จะระเบิดและทำให้ Behavior Engine แตกเป็น spaghetti

**กติกา:**
```
(node_mode, line_type) → execution_mode
```
ไม่ใช่:
```
node_mode = LINE_SPECIFIC_BEHAVIOR
```

### 3.2 HAT_SINGLE (Hatthasilpa – Single Piece Work)

**Use Case:**
- งานเย็บหัตถศิลป์ (Hand Stitching) ที่ทำทีละใบ
- ใช้ใน Work Queue (Hatthasilpa line)

**Behavior:**
- 1 Token = 1 ใบงาน
- Time Engine: จับเวลาต่อ Token (start / pause / resume / complete)
- UI (Work Queue): แสดงใบงานทีละใบ, กด start/pause/resume/complete ได้ตามปกติ

### 3.3 CLASSIC_SCAN (Classic Line – PWA Scan)

**Use Case:**
- สายการผลิต Classic / OEM ที่ไม่ได้ใช้งาน work_queue
- ทุกอย่างขับเคลื่อนผ่าน PWA + QR Scan

**Behavior:**
- Worker ใช้ PWA Scan: Scan Token / Serial → งานขยับ Node ตาม DAG
- Time Engine: อาจบันทึก time per scan (enter/exit), แต่ *ไม่ได้* ใช้ start/pause/resume แบบ Hatthasilpa

#### 3.3.1 Mapping Rule Reminder
CLASSIC_SCAN = behavior ที่ Work Center นิยามไว้ล่วงหน้า  
แต่ execution ที่แท้จริงจะถูก cast จาก `(node_mode, line_type)`:

- หาก `line_type='classic'` → ใช้ PWA Scan
- หาก `line_type='hatthasilpa'` → ไม่อนุญาต (Designer ควรผูก WC ให้ถูกต้อง)

### 3.4 QC_SINGLE (Quality Control per Piece)

**Use Case:**
- QC ใบต่อใบ ทั้ง Hatthasilpa และ Classic ได้
- ใช้เมื่อต้องการผล PASS / FAIL + Reason

**Behavior:**
- 1 Token = 1 ใบงาน
- Node UI: ต้องให้กรอกผล QC (PASS / FAIL, reason, defect_code)
- Time Engine: จับเวลา QC ต่อใบได้ (ถ้าต้องการ)

---

## 4. Execution Context Structure

### 4.0 Canonical Events Integration
เพื่อ align กับ Core Principles ของระบบ Bellavier ERP (ข้อ 13–15):

- Behavior Execution MUST output only canonical event structures
- ห้ามสร้าง custom keys ใน `effects`
- Manual override ใด ๆ ต้องแปลเป็น canonical events ก่อนเข้าสู่ Behavior Engine

**Allowed Canonical Events:**
- TOKEN_* (create, split, merge, adjust)
- NODE_* (start, pause, resume, complete, cancel)
- OVERRIDE_* (route, time_fix, token_adjust)
- COMP_* (bind, unbind)
- INVENTORY movements

Behavior ห้ามส่งผลลัพธ์ที่อยู่นอกเหนือรายการนี้

### 4.1 Input Context

When a behavior is executed, it receives a **normalized context** containing:

```php
[
    'token' => [
        'id_token' => int,
        'status' => string, // 'active', 'paused', 'completed'
        'serial_number' => string,
        'current_node_id' => int,
        'start_at' => string, // ISO8601
        'actual_duration_ms' => int|null,
    ],
    'node' => [
        'id_node'       => int,
        'node_code'     => string,
        'node_type'     => string, // 'operation', 'qc', etc.
        'id_work_center' => int,
        'work_center_code' => string|null,
        'sla_minutes'   => int|null,
        'estimated_minutes' => int|null,
    ],
    'work_center' => [
        'id_work_center' => int,
        'node_mode'      => string, // BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE
    ],
    'job_ticket' => [
        'id_job_ticket' => int,
        'ticket_code'   => string,
        'job_name'      => string,
        'id_mo'         => int|null,
        'sku'           => string|null,
        'id_product'    => int|null,
        'customer_name' => string|null,
        'process_mode'  => string, // 'batch' or 'piece'
        'routing_mode'  => string, // 'linear' or 'dag'
        'line_type'     => string, // 'classic' or 'hatthasilpa'
    ] | null,
    'execution' => [
        'node_mode' => string, // From Work Center
        'line_type' => string, // From job context
        // Runtime will resolve: execution_mode = resolveExecutionMode(node_mode, line_type)
    ],
    'time' => [
        'now'      => DateTimeImmutable, // Canonical timezone
        'timezone' => string, // 'Asia/Bangkok'
    ],
    'meta' => [
        'version' => string, // '21.1'
    ],
]
```

### 4.2 Output Effects (Canonical Events Only)

When a behavior executes, it returns **normalized effects with canonical events only**:

```php
[
    'ok' => bool,
    'node_mode' => string, // BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE
    'line_type' => string, // classic or hatthasilpa
    'canonical_events' => [
        // Allowed Canonical Events (from Core Principles 14):
        // TOKEN_* (create, split, merge, adjust)
        // NODE_* (start, pause, resume, complete, cancel)
        // OVERRIDE_* (route, time_fix, token_adjust)
        // COMP_* (bind, unbind)
        // INVENTORY movements
        
        // Example structure (Task 21.2+):
        // 'TOKEN_CREATE' => [
        //     'token_id' => int,
        //     'serial_number' => string,
        //     'node_id' => int,
        // ],
        // 'NODE_COMPLETE' => [
        //     'node_id' => int,
        //     'token_id' => int,
        //     'duration_ms' => int,
        // ],
        // 'COMP_BIND' => [
        //     'token_id' => int,
        //     'component_code' => string,
        //     'component_serial' => string,
        // ],
        // 'INVENTORY_MOVEMENT' => [
        //     'item_code' => string,
        //     'qty' => float,
        //     'uom' => string,
        //     'direction' => 'consume' | 'produce',
        // ],
    ],
    'effects' => [
        // Task 21.1: Legacy structure for compatibility
        // Will be deprecated in Task 21.2+ in favor of canonical_events
        'wip'        => null,
        'inventory'  => null,
        'qc'         => null,
        'routing'    => [
            'next_node_id' => int|null, // Optional override: Only set if behavior wants to force route
            'condition'    => string|null,
        ] | null,
    ],
    'meta' => [
        'version' => string,
        'executed' => bool, // true when real logic is added
        'timestamp' => string, // MySQL DATETIME
    ],
]
```

**⚠️ CRITICAL:** Behavior ห้ามส่งผลลัพธ์ที่อยู่นอกเหนือรายการ canonical events ที่กำหนดไว้

---

## 5. Behavior Execution Flow

### 5.1 Token Completion Flow

When a token completes work at a node:

1. **Token Work Session Completes**
   - `TokenWorkSessionService::completeToken(int $tokenId, int $operatorId)` called
   - Session closed, `actual_duration_ms` calculated

2. **Token Lifecycle Completes**
   - `TokenLifecycleService::completeToken(int $tokenId, ?int $operatorId)` called
   - Token status → `completed`
   - Sets `completed_at` and `actual_duration_ms` using TimeHelper (Task 20.2.2)

3. **Behavior Execution** (Task 21.2+)
   - `NodeBehaviorEngine::executeBehavior()` called
   - Engine resolves `node_mode` from Work Center (not from Node)
   - Engine resolves `line_type` from job context
   - Behavior processes context → produces effects

4. **Effects Applied** (Task 21.3+)
   - WIP updated (if needed) - via `TokenLifecycleService` or equivalent
   - Inventory moved (if needed) - via `InventoryMovementService` or equivalent
   - QC result recorded (if needed) - via QC service layer

5. **Token Routing**
   - `DAGRoutingService::routeToken()` called
   - Token moves to next node (or completes)
   - **Note:** Behavior's `routing.next_node_id` is **optional override only**
   - If behavior does not specify `next_node_id`, `DAGRoutingService` decides routing based on graph structure

**Note:** Task 21.2+ implementation completed:
- `NodeBehaviorEngine::executeBehavior()` generates canonical events
- `TokenEventService::persistEvent()` persists events to `token_event` table
- `TimeEventReader::getTimelineForToken()` syncs timeline to `flow_token`

### 5.2 Node Mode Resolution

**Step 1: Resolve Node Mode from Work Center**
```php
$nodeMode = $nodeBehaviorEngine->resolveNodeMode($node);
// Returns: 'BATCH_QUANTITY', 'HAT_SINGLE', 'CLASSIC_SCAN', 'QC_SINGLE' or null
// Reads from work_center.node_mode (NOT from routing_node)
```

**Step 2: Build Execution Context**
```php
$context = $nodeBehaviorEngine->buildExecutionContext($token, $node, $jobTicket);
// Returns: Normalized context array
// Note: $jobTicket is from job_ticket table
// Note: node_mode comes from Work Center, line_type comes from job context
```

**Step 3: Execute Behavior**
```php
$result = $nodeBehaviorEngine->executeBehavior($context);
// Returns: Effects array (stubbed in Task 21.1)
// Uses node_mode + line_type to determine execution semantics
```

---

## 6. Abstraction Principles

**1. Behavior Does Not Know About UI**
- Behaviors are pure business logic
- No HTML, no JavaScript, no user interaction
- UI layer calls behavior engine, not the other way around

Behavior ห้ามส่งสัญญาณหรือ trigger ไปยัง UI โดยตรง ทุกอย่างต้องผ่าน canonical effects เท่านั้น

**2. Behavior Does Not Execute SQL Directly**
- Behaviors use **service layer** for all database operations
- **Existing services to use:**
  - `TokenLifecycleService` - Token lifecycle management
  - `TokenWorkSessionService` - Work session management
  - `DAGRoutingService` - Token routing logic
  - `InventoryMovementService` (or equivalent) - Inventory operations (Task 21.3+)
  - `WorkCenterService` (or equivalent) - Work center operations (Task 21.3+)
- Service layer handles all SQL queries
- Behaviors compose service calls to achieve business goals

**3. Behavior Is Stateless**
- Behavior execution is a pure function: `context → effects`
- No internal state between executions
- All state is in the database (via service layer)

Statelessness เป็นส่วนหนึ่งของ Close System:  
ห้าม behavior เก็บ state เพิ่มเอง หรือสร้าง behavior variant โดยใช้ dynamic flags

**4. Behavior Is Testable**
- Given a context, behavior should produce deterministic effects
- Can be tested in isolation (unit tests)
- Can be tested with mock services (integration tests)

---

## 7. Task 21.1 Scope

**What Task 21.1 Does:**
- ✅ Defines Behavior Model (this document - aligned with Node_Behavier.md)
- ✅ Creates `NodeBehaviorEngine` skeleton (reads node_mode from Work Center)
- ✅ Establishes context/effects structure
- ✅ No database side effects (as required)

**What Task 21.1 Does NOT Do:**
- ❌ Implement actual behavior logic
- ❌ Wire into Token Completion Flow
- ❌ Execute SQL or modify database
- ❌ Integrate with Worker App

**⚠️ CRITICAL GUARD:**
- `NodeBehaviorEngine` **MUST NOT** be invoked from production flows before Task 21.2 is complete
- Any call to `executeBehavior()` must be guarded by a feature flag:
  ```php
  if (!getFeatureFlag('NODE_BEHAVIOR_EXPERIMENTAL', false)) {
      // Skip behavior execution
      return;
  }
  ```
- Task 21.1 is **specification-only** - no runtime integration allowed

**Next Steps (Task 21.2+):**
- Task 21.2: Wire `NodeBehaviorEngine` into Token Completion Flow (read-only/dry-run)
- Task 21.3: Implement first behavior set based on node_mode (BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE)
- Task 21.4: Internal Behavior Registry (NOT plugin-extensible)
  - Behavior registry ใช้เพื่อ mapping node_mode → internal behavior class เท่านั้น
  - Close System: ไม่อนุญาต plugin, extension, หรือ behavior type ใหม่จากภายนอก
  - Node Mode ถูกควบคุมโดย Bellavier Framework เท่านั้น

---

## 8. References

- **Node_Behavier.md (Canonical Spec):** `docs/super_dag/Node_Behavier.md`
- **SuperDAG Architecture:** `docs/super_dag/SuperDAG_Architecture.md`
- **Time Model:** `docs/super_dag/time_model.md`
- **Execution Model:** `docs/super_dag/SuperDAG_Execution_Model.md`
- **Task 20 (ETA Engine):** `docs/super_dag/tasks/task20_results.md`
- **Task 21.1:** `docs/super_dag/tasks/task21.1.md`

---

**Document Status:** ✅ Complete (Task 21.1 - Corrected)  
**Last Updated:** 2025-01-XX  
**Alignment:** Aligned with Node_Behavier.md canonical spec

---

## 9. Alignment With Node_Behavier A1 & A5

**A1 – Graph Neutrality**  
เอกสารนี้ยืนยันว่า Graph Designer ไม่กำหนด line_type  
แต่ Node Behavior Engine จะ resolve execution จาก `(node_mode, job.line_type)` เท่านั้น  
Graph ใด ๆ ต้อง reusable ระหว่าง Classic / Hatthasilpa

**A5 – BOM Separation**  
Behavior Engine ไม่ยุ่งเกี่ยวกับ BOM  
Component Binding (COMP_BIND/UNBIND) เป็นเพียง canonical event ที่ behavior อาจ emit  
แต่อยู่คนละเลเยอร์กับ BOM logic โดยสิ้นเชิง  
