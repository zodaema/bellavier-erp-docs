# SuperDAG Execution Model

**Status:** Active Documentation  
**Date:** 2025-01-XX (Last Updated)  
**Purpose:** Complete execution model documentation - token state machine, execution steps, machine semantics


> **Design Context (Bellavier Close System)**  
> - เอกสารนี้เน้นอธิบาย “สภาพปัจจุบันของโค้ด” (as-is execution)  
> - แต่ Framework หลักของระบบ DAG / Node Mode / Canonical Events / Close System ถูกนิยามไว้ใน:  
>   - `Node_Behavier.md`  
>   - `node_behavior_model.md`  
>   - `core_principles_of_flexible_factory_erp.md`  
> - ถ้าพบว่าพฤติกรรมในเอกสารนี้ไม่ตรงกับ Axioms / Principles ให้ถือว่าเป็น “หนี้เทคนิค” ที่ต้องแก้ในโค้ด ไม่ใช่การเปลี่ยนกฎหลัก


## Table of Contents

1. [Token Creation (Spawn)](#token-creation-spawn)
2. [Token Execution Entry Points](#token-execution-entry-points)
3. [Token State Machine](#token-state-machine)
4. [Node Completion Decision](#node-completion-decision)
5. [Token Movement Flow](#token-movement-flow)
6. [Token Pause/Resume/Cancel](#token-pauseresumecancel)
7. [Machine Semantics](#machine-semantics)
8. [Execution Examples](#execution-examples)

---

## Token Creation (Spawn)

### Where Tokens Are Created

**Primary Location:** `TokenLifecycleService::spawnTokens()`

**File:** `source/BGERP/Service/TokenLifecycleService.php:41`

**Called From:**
- `dag_token_api.php::spawn()` action
- `job_ticket_dag.php::start()` action (indirectly)

> 🔎 **Canonical Events Note:**  
> การสร้าง Token (`spawnTokens()`) ควรถูกมองเป็นการปล่อย canonical events ชุดแรกใน lifecycle คือ `TOKEN_CREATE` + `NODE_ENTER` (แม้ในโค้ดปัจจุบันจะใช้ชื่อ event `'spawn'` / `'enter'` ก็ตาม) เพื่อ align กับ Canonical Event Framework (ข้อ 14 ใน core principles)

### Spawn Process

**Step-by-Step (from code):**

1. **Idempotency Check**
   ```php
   // Location: TokenLifecycleService::spawnTokens():47
   $stateCounts = $this->getInstanceTokenStateCounts($instanceId);
   $liveCount = ready + active + waiting + paused;
   $scrappedCount = scrapped;
   
   if ($liveCount > 0 && $scrappedCount > 0) {
       throw new RuntimeException('Mixed token states detected');
   }
   if ($liveCount > 0) {
       return []; // Idempotent skip
   }
   ```

2. **Process Mode Normalization**
   ```php
   // Location: TokenLifecycleService::spawnTokens():68
   // Prefer explicit parameter → fallback to job_ticket.process_mode → default 'batch'
   $normalized = ($processMode === 'piece') ? 'piece' : 'batch';
   ```

3. **Feature Flag Check (Piece Mode)**
   ```php
   // Location: TokenLifecycleService::spawnTokens():92
   if ($processMode === 'piece') {
       $ffEnabled = FeatureFlagService::getFlagValue('FF_SERIAL_STD_HAT', $tenantScope);
       if ($ffEnabled !== 1) {
           throw new RuntimeException('DAG_400_SERIAL_FLAG_REQUIRED');
       }
   }
   ```

4. **Get Start Node**
   ```php
   // Location: TokenLifecycleService::spawnTokens():110
   $startNode = $this->getStartNode($instanceId);
   // Finds node with node_type = 'start' OR first node with no incoming edges
   ```

5. **Create Token(s)**
   - **Batch Mode:**
     ```php
     // Location: TokenLifecycleService::spawnTokens():120
     createToken([
         'instance_id' => $instanceId,
         'token_type' => 'batch',
         'serial_number' => null,
         'current_node_id' => $startNode['id_node'],
         'qty' => $targetQty,
         'status' => 'ready'
     ]);
     ```
   - **Piece Mode:**
     ```php
     // Location: TokenLifecycleService::spawnTokens():156
     for ($i = 0; $i < $targetQty; $i++) {
         $serial = $serials[$i] ?? null;
         createToken([
             'instance_id' => $instanceId,
             'token_type' => 'piece',
             'serial_number' => $serial,
             'current_node_id' => $startNode['id_node'],
             'qty' => 1,
             'status' => 'ready'
         ]);
         // Link serial: markSerialAsSpawned($jobId, $serial, $tokenId);
     }
     ```

6. **Create Events**
   ```php
   // Location: TokenLifecycleService::spawnTokens():135
   createEvent($tokenId, 'spawn', $startNode['id_node'], null, [
       'spawn_mode' => 'batch' or 'piece',
       'qty' => $targetQty
   ]);
   createEvent($tokenId, 'enter', $startNode['id_node'], null, [
       'node_name' => $startNode['node_name']
   ]);
   ```

   **Task 21.2+ (Canonical Events):**
   - Events are also persisted via `TokenEventService::persistEvent()`
   - Canonical event types: `TOKEN_CREATE`, `NODE_ENTER`
   - Legacy event types (`spawn`, `enter`) are still created for backward compatibility
   - All events use canonical timezone via `TimeHelper` (Task 20.2.2)

7. **Auto-Assign**
   ```php
   // Location: TokenLifecycleService::spawnTokens():147
   resolveAndAssignToken($tokenId, $startNode['id_node'], $jobId, $graphId, $tenantCode);
   // Uses AssignmentResolverService to assign token to operator/team
   ```

---

## Token Execution Entry Points

### Entry Point 1: Behavior Execution

**Location:** `BehaviorExecutionService::execute()`

**File:** `source/BGERP/Dag/BehaviorExecutionService.php:94`

**Called From:**
- Work Queue UI (STITCH, CUT, EDGE behaviors)
- PWA Scan Station (QC behaviors)
- Job Ticket UI (all behaviors)

**Flow:**
```
API Request (work_queue, pwa_scan, job_ticket)
  ↓
BehaviorExecutionService::execute(behaviorCode, sourcePage, action, context, formData)
  ├─→ Validate behavior_code matches node.behavior_code (Task 15)
  ├─→ Validate execution_mode matches node.execution_mode (Task 16)
  ├─→ Route to behavior handler:
  │     ├─→ STITCH → handleStitch()
  │     ├─→ CUT → handleCut()
  │     ├─→ EDGE → handleEdge()
  │     └─→ QC_SINGLE/QC_FINAL → handleQc()
  └─→ (if complete action) DagExecutionService::moveToNextNode()
```

**Task 21.2+ (Canonical Events):**
```
BehaviorExecutionService::execute()
  ↓
NodeBehaviorEngine::executeBehavior() (Task 21.2+)
  ├─→ Resolve node_mode from Work Center (Task 21.1)
  ├─→ Build execution context
  ├─→ Generate canonical events
  └─→ TokenEventService::persistEvent() → token_event table
```

> 🧩 **Mapping กับ Node Mode / Line Type**  
> - `behaviorCode` ที่ส่งเข้า `BehaviorExecutionService::execute()` ต้องสอดคล้องกับ `node_mode` จาก Work Center ของ Node ปัจจุบัน (ตามสเปกใน `Node_Behavier.md`)  
> - `execution_mode` ที่ใช้ validate/route ภายใน service ควรถูก derive มาจากคู่ `(node_mode, job.line_type)` ตามฟังก์ชัน `resolveExecutionMode()` ในเอกสาร Node Behavior Model  
> - **Task 21.1+:** `NodeBehaviorEngine` resolves node_mode from Work Center automatically
> - ถ้าพบว่าตัวโค้ดใช้ hard-coded behavior ที่ไม่ผ่าน mapping นี้ ให้ถือเป็นจุดที่ต้อง refactor ในเฟสถัดไป

### Entry Point 2: Direct Token Routing

**Location:** `DagExecutionService::moveToNextNode()`

**File:** `source/BGERP/Dag/DagExecutionService.php:58`

**Called From:**
- `BehaviorExecutionService` (after behavior complete)
- `DAGRoutingService::routeToken()` (internal)

**Flow:**
```
DagExecutionService::moveToNextNode($tokenId)
  ├─→ Validate token state (not closed, active/ready, no active session)
  ├─→ Validate component completeness (Task 13.6)
  └─→ DAGRoutingService::routeToken($tokenId, $userId)
```

### Entry Point 3: Manual Token Movement

**Location:** `DagExecutionService::moveToNodeId()`

**File:** `source/BGERP/Dag/DagExecutionService.php:220`

**Purpose:** Override/manual routing to specific node

**Flow:**
```
DagExecutionService::moveToNodeId($tokenId, $targetNodeId)
  ├─→ Validate token and target node
  ├─→ Validate component completeness for target node
  └─→ TokenLifecycleService::moveToken($tokenId, $targetNodeId)
```

---

## Token State Machine

### State Transitions (From Code)

**States (from `flow_token.status` ENUM):**
- `ready` - Token spawned, ready to start work
- `active` - Token in active work
- `waiting` - Token waiting (queue, machine, merge)
- `paused` - Token paused (work session paused)
- `completed` - Token reached end node
- `scrapped` - Token scrapped
- `cancelled` - Token cancelled (deprecated)
- `merged` - Token merged into another
- `consumed` - Token consumed (rework spawn)
- `stuck` - Token stuck (deadlock)

### State Transition Diagram

```
[SPAWNED]
  status = 'ready'
  ↓
[START WORK]
  BehaviorExecutionService::execute('STITCH', 'work_queue', 'stitch_start')
  ↓
[ACTIVE]
  status = 'active' (if session started)
  OR
  status = 'ready' (if session not started yet)
  ↓
[PAUSE] ←→ [RESUME]
  status = 'paused' ←→ status = 'active'
  ↓
[COMPLETE WORK]
  BehaviorExecutionService::execute('STITCH', 'work_queue', 'stitch_complete')
  ↓
[ROUTING]
  DagExecutionService::moveToNextNode()
  ↓
[WAITING] (if limits reached or machine not available)
  status = 'waiting'
  ↓
[ACTIVE] (when limit cleared or machine available)
  status = 'active' or 'ready'
  ↓
[COMPLETED]
  status = 'completed' (reached end node)
```

#### Axiom Alignment

- State Machine นี้คือ “Logic ชั้นใน” ตาม Golden Rule (Reality Flexible, Logic Strict)  
- การเปลี่ยนสถานะ token (ready/active/waiting/paused/...) ทั้งหมดต้องเกิดจาก canonical events เท่านั้น (เช่น NODE_START, NODE_COMPLETE, OVERRIDE_ROUTE) ไม่ใช่จาก UI logic โดยตรง  
- ถ้าพบ state transition ที่เขียนตรงจาก UI → DB โดยไม่ผ่าน service/event ที่รองรับ ให้ถือว่าเป็นจุดละเมิด Canonical Event Framework

### State Transition Rules (From Code)

**ready → active:**
- **Trigger:** Work session started (`TokenWorkSessionService::startSession()`)
- **Location:** `BehaviorExecutionService::handleStitch()` (stitch_start action)
- **Note:** Token status may remain 'ready' if session not explicitly started

**active → paused:**
- **Trigger:** Work session paused (`TokenWorkSessionService::pauseSession()`)
- **Location:** `BehaviorExecutionService::handleStitch()` (stitch_pause action)
- **Note:** Token status may not change, session status changes

**paused → active:**
- **Trigger:** Work session resumed (`TokenWorkSessionService::resumeSession()`)
- **Location:** `BehaviorExecutionService::handleStitch()` (stitch_resume action)

**ready/active → waiting:**
- **Trigger:** 
  - Concurrency limit reached (`DAGRoutingService::routeToNode()`)
  - WIP limit reached (`DAGRoutingService::routeToNode()`)
  - Machine not available (`DAGRoutingService::routeToNode()`)
  - Merge not ready (`DAGRoutingService::handleMergeNode()`)
- **Location:** `DAGRoutingService::routeToNode()` or `handleMergeNode()`

**waiting → ready/active:**
- **Trigger:** Limit cleared or machine available
- **Location:** Manual trigger or background process (not implemented in current code)

**ready/active → completed:**
- **Trigger:** Token reached end node (no outgoing edges)
- **Location:** `DAGRoutingService::routeToken()` → `TokenLifecycleService::completeToken()`

**ready/active → scrapped:**
- **Trigger:** 
  - QC fail with scrap policy (`DAGRoutingService::handleQCFailWithPolicy()`)
  - Token cancellation (`TokenLifecycleService::cancelToken()`)
- **Location:** `DAGRoutingService::handleQCFailWithPolicy()` or `TokenLifecycleService::cancelToken()`

**ready/active → consumed:**
- **Trigger:** Rework token spawned
- **Location:** `TokenLifecycleService::spawnReworkToken()`

**ready/active → stuck:**
- **Trigger:** Deadlock detected in parallel block
- **Location:** `DAGRoutingService::handleMergeNode()` → `markParallelGroupAsStuck()`

---

## Node Completion Decision

### What Determines Next Node

**Location:** `DAGRoutingService::routeToken()`

**File:** `source/BGERP/Service/DAGRoutingService.php:54`

**Decision Tree (from code):**

```
routeToken($tokenId)
  ↓
1. Check subgraph exit (Phase 1.7)
  ↓
2. Release machine if leaving machine-bound node (Task 18)
  ↓
3. Check if parallel split node?
   YES → handleParallelSplit() → END
   NO  → Continue
  ↓
4. Check if merge node?
   YES → handleMergeNode() → Continue after merge
   NO  → Continue
  ↓
5. Get outgoing edges
  ↓
6. Edge count?
   0 → Complete token (end node)
   1 → Auto-route to next node
   2+ → selectNextNode() (evaluate conditions)
```

### Edge Selection Logic

**Location:** `DAGRoutingService::selectNextNode()`

**File:** `source/BGERP/Service/DAGRoutingService.php:766`

**Priority Order:**
1. **Conditional edges** (`edge_type = 'conditional'`)
   - Evaluate `edge_condition` JSON
   - First matching condition wins
2. **Normal edges** (`edge_type = 'normal'`)
3. **First edge** (fallback)

**Note:** Decision nodes use separate logic with `condition_rule` and evaluation order (`priority` field), but this is not used in `selectNextNode()`.

---

## Token Movement Flow

### Movement Process

**Location:** `TokenLifecycleService::moveToken()`

**File:** `source/BGERP/Service/TokenLifecycleService.php:334`

**Steps:**
1. Fetch token
2. Get `from_node_id = token.current_node_id`
3. Update `flow_token.current_node_id = $toNodeId`
4. Create 'move' event (uses TimeHelper for timestamp - Task 20.2.2)
5. Create 'enter' event at new node (uses TimeHelper for timestamp - Task 20.2.2)

**Task 21.2+ (Canonical Events):**
- `moveToken()` also creates canonical events via `TokenEventService`:
  - `NODE_LEAVE` from old node
  - `NODE_ENTER` to new node
- Legacy events (`'move'`, `'enter'`) are still created for backward compatibility
- All timestamps use canonical timezone via `TimeHelper` (Task 20.2.2)

### Routing to Node

**Location:** `DAGRoutingService::routeToNode()`

**File:** `source/BGERP/Service/DAGRoutingService.php:153`

**Steps:**
1. **Check Limits:**
   - Concurrency limit (priority) → If reached, set status to 'waiting', return
   - WIP limit → If reached, set status to 'waiting', return

2. **Production Mode Transition:**
   - Atelier → OEM: Generate QR code

3. **Move Token:**
   - `TokenLifecycleService::moveToken()`

4. **Machine Allocation (Task 18):**
   - If `machine_binding_mode != NONE`:
     - `MachineAllocationService::allocateMachine()`
     - If allocated → `assignMachine()`, set `machine_cycle_started_at`
     - If waiting → Set status to 'waiting', log 'machine_waiting' event

5. **Set Status:**
   - If target node is operation/QC → Set status to 'ready'
   - If OEM → Atelier transition → Set status to 'ready'

6. **Resolve Assignment:**
   - `AssignmentResolverService::resolveAssignment()`
   - Auto-assign token to node

7. **Handle Special Node Types:**
   - `join` → `handleJoinNode()`
   - `split` → `handleSplitNode()`
   - `wait` → `handleWaitNode()`
   - `decision` → `handleDecisionNode()`
   - `subgraph` → `handleSubgraphNode()`

---

## Token Pause/Resume/Cancel

### Pause

**Location:** `BehaviorExecutionService::handleStitch()` (stitch_pause action)

**File:** `source/BGERP/Dag/BehaviorExecutionService.php:326`

**Flow:**
1. Check for active session
2. Validate worker ownership
3. `TokenWorkSessionService::pauseSession()`
4. Log behavior action

**Note:** Token status may not change, session status changes to 'paused'.

### Resume

**Location:** `BehaviorExecutionService::handleStitch()` (stitch_resume action)

**File:** `source/BGERP/Dag/BehaviorExecutionService.php:288`

**Flow:**
1. Check for stale session (Task 12)
2. Check for conflicting sessions
3. Check for paused session
4. `TokenWorkSessionService::resumeSession()`
5. Log behavior action

**Note:** Token status may not change, session status changes to 'active'.

### Cancel

**Location:** `TokenLifecycleService::cancelToken()`

**File:** `source/BGERP/Service/TokenLifecycleService.php:430`

**Cancellation Types:**
- `qc_fail` → Auto-spawn replacement token at same node
- `redesign` → Mark for redesign (requires manager review)
- `permanent` → Just scrap, no replacement

**Flow:**
1. Store original node ID
2. Validate cancellation type
3. Update token:
   - `status = 'scrapped'`
   - `cancellation_type = $cancellationType`
   - `cancellation_reason = $reason`
   - `current_node_id = NULL`
4. Create 'cancel' event
5. Handle based on type:
   - `qc_fail` → `spawnReplacementToken()`
   - `redesign` → `markForRedesign()`
   - `permanent` → No action

> 🛡️ **Close System Rule:**  
> - การยกเลิก / scrap / spawn replacement token ถือเป็น “Logic กลาง” ของระบบ ไม่ควรให้ UI หรือ endpoint อื่น bypass `TokenLifecycleService::cancelToken()` หรือ `spawnReplacementToken()`  
> - สคริปต์หรือ API ใหม่ใด ๆ ที่ต้องการยกเลิก token ต้องเรียกผ่าน service เดียวกัน เพื่อรักษา Traceability และเงื่อนไขของ Canonical Events

---

## Machine Semantics

### Machine Binding Modes

**From `routing_node.machine_binding_mode` (actual values in code):**

1. **NONE** (Default)
   - No machine binding
   - Token proceeds normally
   - **Location:** `MachineAllocationService::allocateMachine()` returns immediately

2. **BY_WORK_CENTER**
   - Auto-select from work center machines
   - **Location:** `MachineAllocationService::getCandidateMachines()` → `MachineRegistry::getMachinesByWorkCenter()`
   - **Selection:** First available machine (respecting `concurrency_limit`)

3. **EXPLICIT**
   - Use explicit machine list from `machine_codes`
   - **Location:** `MachineAllocationService::getCandidateMachines()` → `MachineRegistry::getMachinesByCodes()`
   - **Format:** JSON array or comma-separated string

### Machine Allocation Process

**Location:** `MachineAllocationService::allocateMachine()`

**File:** `source/BGERP/Dag/MachineAllocationService.php:40`

**Flow:**
1. If `machine_binding_mode = NONE` → Return immediately
2. Get candidate machines based on binding mode
3. `findAvailableMachine()`:
   - For each candidate machine:
     - Count active tokens at node using this machine
     - If count < `concurrency_limit` → Machine available
   - Return first available machine
4. If available → Return `['allocated' => true, 'machine_code' => ...]`
5. If not available → Return `['allocated' => false, 'waiting' => true, 'reason' => 'all_machines_busy']`

### Machine Assignment

**Location:** `MachineAllocationService::assignMachine()`

**File:** `source/BGERP/Dag/MachineAllocationService.php:225`

**Actions:**
```sql
UPDATE flow_token
SET machine_code = ?,
    machine_cycle_started_at = NOW(),
    machine_cycle_completed_at = NULL
WHERE id_token = ?
```

### Machine Release

**Location:** `MachineAllocationService::releaseMachine()`

**File:** `source/BGERP/Dag/MachineAllocationService.php:203`

**Trigger:** Token leaving machine-bound node

**Location:** `DAGRoutingService::routeToken()` (`source/BGERP/Service/DAGRoutingService.php:93`)

**Actions:**
```sql
UPDATE flow_token
SET machine_cycle_completed_at = NOW()
WHERE id_token = ?
  AND machine_code IS NOT NULL
  AND machine_cycle_completed_at IS NULL
```

**Note:** `machine_code` is NOT cleared (kept for audit trail).

### Machine Queue

**Location:** `MachineAllocationService::getActiveTokenCount()`

**File:** `source/BGERP/Dag/MachineAllocationService.php:174`

**Query:**
```sql
SELECT COUNT(*) as active_count
FROM flow_token
WHERE machine_code = ?
  AND current_node_id = ?
  AND status IN ('active', 'waiting')
  AND machine_cycle_started_at IS NOT NULL
  AND machine_cycle_completed_at IS NULL
```

**Logic:** Count tokens that have started machine cycle but not completed.

### Concurrency Limit

**From `machine.concurrency_limit` (actual field in schema):**

- **Default:** 1 (one token per machine)
- **Usage:** Maximum number of tokens that can use machine simultaneously
- **Enforcement:** `MachineAllocationService::findAvailableMachine()` checks active token count

### Cycle Time

**From `machine.cycle_time_seconds` (actual field in schema):**

- **Purpose:** Average cycle time per unit or batch
- **Usage:** 
  - ETA calculation (`ParallelMachineCoordinator::getETA()`)
  - Throughput prediction (future)
- **Note:** Not currently enforced (no automatic cycle completion)

### Machine States

**From code analysis:**
- **Active:** `machine.is_active = 1`
- **Inactive:** `machine.is_active = 0` (deadlock detection checks for branches waiting on inactive machines)

---

## Execution Examples

### Example 1: Simple STITCH Execution

**Scenario:** Token at STITCH node, worker starts work

**Steps:**
1. **API Call:** `dag_token_api.php::start()` with `action = 'stitch_start'`
2. **Behavior Execution:** `BehaviorExecutionService::execute('STITCH', 'work_queue', 'stitch_start', context)`
3. **Validation:**
   - Check behavior_code matches node.behavior_code
   - Check execution_mode matches node.execution_mode
   - Check for conflicting sessions
4. **Session Start:** `TokenWorkSessionService::startSession($tokenId, $nodeId, $workerId)`
   - Uses `TimeHelper::now()` for timestamp (Task 20.2.2)
5. **Canonical Events (Task 21.2+):**
   - `NodeBehaviorEngine::executeBehavior()` generates canonical events
   - `TokenEventService::persistEvent('NODE_START', ...)` → token_event table
6. **Log:** Behavior action logged to `dag_behavior_log`
7. **Result:** Session started, token remains 'ready' or becomes 'active'

**Complete:**
1. **API Call:** `dag_token_api.php::complete()` with `action = 'stitch_complete'`
2. **Behavior Execution:** `BehaviorExecutionService::execute('STITCH', 'work_queue', 'stitch_complete', context)`
3. **Session Complete:** `TokenWorkSessionService::completeToken($tokenId, $workerId)`
   - Uses `TimeHelper` for timestamp calculation (Task 20.2.2)
4. **Canonical Events (Task 21.2+):**
   - `NodeBehaviorEngine::executeBehavior()` generates `NODE_COMPLETE` event
   - `TokenEventService::persistEvent()` → token_event table
   - `TimeEventReader::getTimelineForToken()` syncs to `flow_token` (start_at, completed_at, actual_duration_ms)
5. **Routing:** `DagExecutionService::moveToNextNode($tokenId)`
6. **Route Token:** `DAGRoutingService::routeToken($tokenId, $userId)`
7. **Move:** `TokenLifecycleService::moveToken($tokenId, $nextNodeId)`
8. **MO Lifecycle Hook (Task 23.5):**
   - `TokenLifecycleService::completeToken()` → `MOEtaHealthService::onTokenCompleted()` (non-blocking)
9. **Result:** Token moved to next node, status = 'ready'

---

### Example 2: Parallel Execution with Machine

**Scenario:** Token at parallel split node, branches need machines

**Steps:**
1. **Token Reaches Split:** `DAGRoutingService::routeToken()` detects `is_parallel_split = true`
2. **Split Execution:** `handleParallelSplit()`
   - Generate `parallel_group_id = parent_token_id`
   - Create child tokens with `parallel_group_id` and `parallel_branch_key`
3. **Machine Allocation:** `ParallelMachineCoordinator::onSplit()`
   - For each child token:
     - Check `machine_binding_mode`
     - If `BY_WORK_CENTER` → Get machines from work center
     - If `EXPLICIT` → Get machines from `machine_codes`
     - `MachineAllocationService::allocateMachine()`
     - If available → `assignMachine()`, set branch state to 'IN_MACHINE'
     - If not available → Set token to 'waiting', set branch state to 'WAITING_MACHINE'
4. **Branch Execution:** Each branch executes independently
5. **Merge:** When token reaches merge node:
   - `handleMergeNode()` → `ParallelMachineCoordinator::canMerge()`
   - Check merge policy (ALL, ANY, AT_LEAST, TIMEOUT_FAIL)
   - If ready → Move token through merge
   - If not ready → Set token to 'waiting'

---

### Example 3: Conditional Routing

**Scenario:** Token at decision node with conditional edges

**Steps:**
1. **Token Reaches Decision:** `DAGRoutingService::routeToken()` gets 2+ outgoing edges
2. **Edge Selection:** `selectNextNode()`
   - Priority 1: Evaluate conditional edges
   - For each conditional edge:
     - Load `edge_condition` JSON
     - `evaluateCondition()`:
       - Check condition type (qty_threshold, token_property, job_property, node_property, expression)
       - Load job/node data if needed
       - Evaluate condition
     - If match → Return edge
   - Priority 2: Normal edge
   - Priority 3: First edge (fallback)
3. **Route:** `routeToNode($tokenId, $selectedEdge)`
4. **Result:** Token moved to selected edge's target node

---

## Alignment With Node_Behavier & Core Principles

เอกสารนี้อธิบาย “สิ่งที่โค้ดทำอยู่จริง” ใน SuperDAG Execution Layer แต่เพื่อไม่ให้สถาปัตย์แตกจากกรอบหลัก จำเป็นต้องยืนยันความสอดคล้องกับไฟล์แนวคิดดังนี้:

- **A1 – Graph Neutrality (Node_Behavier.md)**  
  - การ route token ทั้งหมดในเอกสารนี้ต้องไม่อาศัยชื่อกราฟหรือ line type แบบ hard-coded  
  - การแยก Classic vs Hatthasilpa ต้องมาจาก `job.line_type` เท่านั้น ไม่ใช่จากโครงสร้างกราฟ

- **A2 – Work Center Node Mode (Node_Behavier.md)**  
  - Behavior / execution path ทั้งหมดที่นี่ควรถูก derive มาจาก `node_mode` ของ Work Center + `line_type` ของ job  
  - ถ้ามี behaviorCode ที่ไม่ผูกกับ Work Center / node_mode ให้ mark เป็นหนี้เทคนิค

- **Canonical Event Framework (Core Principles 14)**  
  - ทุกการเปลี่ยนแปลงสถานะ token หรือการเคลื่อน node ต้อง map ไปยัง canonical event types (TOKEN_*, NODE_*, OVERRIDE_*, COMP_*)  
  - ถ้า event_type ปัจจุบันไม่ใช่ชื่อ canonical ให้กำหนด mapping ที่ Event Layer และวางแผน rename ในอนาคต

- **Closed Logic, Flexible Operations (Core Principles 13 & 15)**  
  - Execution Model นี้คือ “Logic ปิด” ที่ไม่ควรเปิดเป็น plug-in หรือให้ external code เปลี่ยน behavior ตามใจ  
  - ความยืดหยุ่นทั้งหมดควรถูกจำกัดอยู่ที่ระดับ:  
    - การเลือกกราฟ / routing  
    - การเลือก Work Center  
    - การใช้ manual override ที่ map → canonical events

การ maintain เอกสารนี้ในอนาคต ต้องระบุให้ชัดเจนทุกครั้งว่า behavior ใหม่ ๆ ที่เพิ่มเข้ามา align กับ Axioms ดังกล่าวหรือไม่ และถ้าไม่ ให้ระบุว่าเป็นหนี้เทคนิค/temporary deviation ที่ต้องปิดในเฟสถัดไป

## Summary

This execution model documents the **actual execution steps** of tokens through SuperDAG graphs. Key findings:

1. **Token Spawn:** Idempotent, supports batch/piece modes, auto-assigns on spawn
2. **Entry Points:** 3 main entry points (Behavior Execution, Direct Routing, Manual Movement)
3. **State Machine:** 10 possible states with specific transition rules
4. **Node Completion:** Decision tree based on node type and edge count
5. **Machine Allocation:** Per-branch, respects concurrency limits, supports 3 binding modes
6. **Pause/Resume/Cancel:** Session-based pause/resume, 3 cancellation types

**Task 20-26 Enhancements:**
7. **Timezone Normalization:** All time operations use `TimeHelper` (canonical timezone: Asia/Bangkok)
8. **Canonical Events:** All behavior actions generate canonical events via `TokenEventService`
9. **Timeline Engine:** `TimeEventReader` provides canonical timeline, syncs to `flow_token`
10. **Self-Healing:** `LocalRepairEngine` and `TimelineReconstructionEngine` for timeline repair
11. **MO Integration:** ETA calculation, load simulation, health monitoring integrated with MO lifecycle

**Next Steps:**
- Use this model to design new execution features
- Reference actual code locations when debugging execution issues
- Maintain this document as execution logic evolves
- **All new features must use TimeHelper for time operations**
- **All behavior actions must generate canonical events**

