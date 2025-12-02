# SuperDAG Flow Map

**Status:** Active Documentation (Updated for Task 19.7, 19.8, 19.9, 19.10, 20, 20.2)  
**Date:** 2025-01-XX (Last Updated)  
**Purpose:** Complete flow map of token movement, parallel execution, and conditional routing

> **⚠️ IMPORTANT:** This document describes **what the code actually does**, not what it should do. All flow descriptions are based on actual code execution paths.

---

## Table of Contents

1. [Token Flow Overview](#token-flow-overview)
2. [Linear Flow](#linear-flow)
3. [Parallel Flow](#parallel-flow)
4. [Conditional Routing Logic](#conditional-routing-logic)
5. [Join Semantics (Merge Behavior)](#join-semantics-merge-behavior)
6. [Parallel Semantics](#parallel-semantics)
7. [Rework Flow](#rework-flow)

---

## Token Flow Overview

### Token States

**From `flow_token.status` ENUM (actual values in code):**
- `ready` - Token spawned, ready to start work
- `active` - Token in active work
- `waiting` - Token waiting (queue, machine, merge)
- `paused` - Token paused (work session paused)
- `completed` - Token reached end node
- `scrapped` - Token scrapped (QC fail, permanent cancellation)
- `cancelled` - Token cancelled (deprecated, use scrapped)
- `merged` - Token merged into another token
- `consumed` - Token consumed (rework spawn)
- `stuck` - Token stuck (deadlock detected)

### Token Lifecycle States

```
SPAWNED (ready)
  ↓
ACTIVE (active) ←→ PAUSED (paused)
  ↓
COMPLETED (completed)
  OR
SCRAPPED (scrapped)
  OR
WAITING (waiting) → ACTIVE (active)
  OR
MERGED (merged)
  OR
CONSUMED (consumed) → [spawns rework token]
```

---

## Linear Flow

### Example: Start → Operation → QC → Finish

**Flow Diagram:**
```
[START] → [CUT] → [QC] → [FINISH]
```

**Step-by-Step Execution:**

1. **Token Spawn**
   - **Location:** `TokenLifecycleService::spawnTokens()`
   - **Action:** Create token at START node with status 'ready'
   - **Event:** 'spawn' + 'enter' events created
   - **Task 21.2+:** Also creates canonical events via `TokenEventService` (TOKEN_CREATE, NODE_ENTER)
   - **Task 20.2.2:** All timestamps use `TimeHelper` (canonical timezone)

2. **Start Work (CUT)**
   - **Location:** `BehaviorExecutionService::handleCut()`
   - **Action:** `cut_start` → Start work session
   - **Token Status:** Remains 'ready' (or 'active' if session started)

3. **Complete Work (CUT)**
   - **Location:** `BehaviorExecutionService::handleCutComplete()`
   - **Action:** `cut_complete` → Complete session
   - **Routing:** `DagExecutionService::moveToNextNode()` → `DAGRoutingService::routeToken()`
   - **Token Status:** Set to 'ready' when entering QC node

4. **QC Pass**
   - **Location:** `BehaviorExecutionService::handleQc()`
   - **Action:** `qc_pass` → Route to next node
   - **Routing:** `DagExecutionService::moveToNextNode()` → `DAGRoutingService::routeToken()`
   - **Edge Selection:** Find pass edge (edge_condition with qc='pass' or normal edge)

5. **Finish**
   - **Location:** `DAGRoutingService::routeToken()`
   - **Action:** No outgoing edges → `TokenLifecycleService::completeToken()`
   - **Token Status:** Set to 'completed'
   - **Event:** 'complete' event created
   - **Task 21.2+:** Also creates canonical event `NODE_COMPLETE` via `TokenEventService`
   - **Task 21.5:** `TimeEventReader` syncs timeline to `flow_token` (start_at, completed_at, actual_duration_ms)
   - **Task 23.5:** `MOEtaHealthService::onTokenCompleted()` hook (non-blocking)

---

## Parallel Flow

### Example: Operation → [Branch A, Branch B] → Merge → Finish

**Flow Diagram:**
```
[START] → [CUT] → [PARALLEL SPLIT]
                    ├─→ [STITCH_BODY] ─┐
                    └─→ [STITCH_HANDLE] ─┤
                                         ↓
                                    [MERGE] → [QC] → [FINISH]
```

**Step-by-Step Execution:**

1. **Token Reaches Parallel Split Node**
   - **Location:** `DAGRoutingService::routeToken()`
   - **Detection:** `is_parallel_split = true` on node
   - **Validation:** Must have 2+ outgoing edges

2. **Parallel Split Execution**
   - **Location:** `DAGRoutingService::handleParallelSplit()`
   - **Flow:**
     ```
     a. Get outgoing edges (must be 2+)
     b. Generate parallel_group_id (uses parent token ID)
     c. Create split config for each branch:
        - serial: parent_serial-BRANCH_CODE
        - node_id: target node ID
        - branch_key: "1", "2", "3", ...
     d. TokenLifecycleService::splitToken()
        - Create child tokens with:
          * parallel_group_id = parent_token_id
          * parallel_branch_key = "1", "2", ...
          * status = 'active'
        - Mark parent as 'completed'
     e. ParallelMachineCoordinator::onSplit()
        - For each child token:
          * Check machine binding
          * Allocate machine if needed
          * Set branch state (READY, IN_MACHINE, WAITING_MACHINE)
     f. Log 'parallel_split' event
     ```

3. **Branch Execution**
   - **Location:** Each branch executes independently
   - **Token Status:** 'active' (or 'waiting' if machine not available)
   - **Machine Allocation:** If node is machine-bound, token waits until machine available

4. **Token Reaches Merge Node**
   - **Location:** `DAGRoutingService::routeToken()`
   - **Detection:** `is_merge_node = true` on node
   - **Validation:** Token must have `parallel_group_id`

5. **Merge Execution**
   - **Location:** `DAGRoutingService::handleMergeNode()`
   - **Flow:**
     ```
     a. Get parallel_group_id from token
     b. Get merge policy from node:
        - parallel_merge_policy (ALL, ANY, AT_LEAST, TIMEOUT_FAIL)
        - parallel_merge_at_least_count (for AT_LEAST)
        - parallel_merge_timeout_seconds (for TIMEOUT_FAIL)
     c. ParallelMachineCoordinator::canMerge()
        - Check deadlock (isBlockStuck())
        - Check timeout (if TIMEOUT_FAIL)
        - Count completed branches
        - Evaluate merge policy:
          * ALL: completed_count >= total_branches
          * ANY: completed_count >= 1
          * AT_LEAST: completed_count >= at_least_count
          * TIMEOUT_FAIL: (timeout check) + ALL semantics
     d. If deadlock:
        - Mark all tokens in group as 'stuck'
        - Log 'parallel_block_deadlocked' event
        - Return error
     e. If not ready:
        - Set token status to 'waiting'
        - Log 'merge_waiting' event
        - Return waiting status
     f. If ready:
        - Move token through merge node
        - Log 'merge_complete' event
        - Continue routing (get outgoing edges)
     ```

6. **Continue After Merge**
   - **Location:** `DAGRoutingService::handleMergeNode()`
   - **Flow:**
     - Get outgoing edges from merge node
     - If 0 edges → Complete token (end node)
     - If 1 edge → Auto-route
     - If 2+ edges → `selectNextNode()` (evaluate conditions)

---

## Conditional Routing Logic

### Where Conditions Are Evaluated

**Location:** `DAGRoutingService::selectNextNode()` → `evaluateCondition()`

**File:** `source/BGERP/Service/DAGRoutingService.php:766-807`

**Task 18, 19.1, 19.2:** Uses unified `ConditionEvaluator` class for condition evaluation

### Evaluation Priority

**From code (`selectNextNode()`):**
1. **Priority 1:** Conditional edges (`edge_type = 'conditional'`)
   - Evaluate `edge_condition` JSON using `ConditionEvaluator`
   - First matching condition wins
   - Task 19.2: Supports multi-group format (`{ type: "or", groups: [...] }`)
2. **Priority 2:** Normal edges (`edge_type = 'normal'`)
3. **Priority 3:** Default edge (`is_default = true` or `{ type: "expression", expression: "true" }`)
4. **Priority 4:** First edge (fallback)

### Edge Condition Model

**Database Field:** `routing_edge.edge_condition` (JSON)

**Alternative Field:** `routing_edge.condition_rule` (JSON) - Used in decision nodes (legacy)

**Normalization:** Uses `JsonNormalizer::normalizeJsonField()` to handle both JSON string and array formats

**Task 18, 19.1, 19.2:** Unified condition model with standardized structure

### Condition Types (Actual Implementation)

**From `ConditionEvaluator` class (Task 18) and `evaluateCondition()` method:**

#### 1. `token_property` (Task 18, 19.1, 19.2)
```json
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "pass"
}
```
- **Properties:** 
  - `qc_result.status` (pass, fail_minor, fail_major)
  - `qc_result.defect_type`, `qc_result.severity`
  - `token.qty`, `token.priority`, `token.rework_count`
  - Any key in `token.metadata`
- **Operators:** `==`, `!=`, `>`, `>=`, `<`, `<=`, `IN`, `NOT_IN`, `CONTAINS`, `STARTS_WITH`

#### 2. `job_property` (Task 18, 19.1, 19.2)
```json
{
  "type": "job_property",
  "property": "priority",
  "operator": "==",
  "value": "high"
}
```
- **Properties:** `job.priority`, `job.target_qty`, `job.process_mode`
- **Operators:** `==`, `!=`, `>`, `>=`, `<`, `<=`, `IN`, `NOT_IN`

#### 3. `node_property` (Task 18, 19.1, 19.2)
```json
{
  "type": "node_property",
  "property": "node_type",
  "operator": "==",
  "value": "qc"
}
```
- **Properties:** `node.node_type`, `node.work_center_code`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`

#### 4. `expression` (Task 18, 19.1, 19.2 - Default Route)
```json
{
  "type": "expression",
  "expression": "true"
}
```
- **Purpose:** Always-true condition for default/else routes
- **Evaluation:** Always evaluates to true
- **Note:** Task 19.1, 19.2 use this for default route edges

#### 5. Multi-Group Format (Task 19.2)
```json
{
  "type": "or",
  "groups": [
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass" }
      ]
    },
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "IN", "value": ["fail_minor", "fail_major"] }
      ]
    }
  ]
}
```
- **Logic:** OR between groups, AND within groups
- **Evaluation:** First group with all conditions matching wins
- **Fallback:** If no groups match, use default route

### Legacy Condition Types (Deprecated)

#### 1. `qty_threshold` (Legacy)
```json
{
  "type": "qty_threshold",
  "threshold": 10,
  "operator": ">"
}
```
- **Status:** Deprecated, use `token_property` with `property: "qty"` instead
- **Operators:** `>`, `>=`, `<`, `<=`, `==`, `!=`
- **Source:** `token.qty`

### Default Routing

**From `selectNextNode()` code:**
- Task 18, 19.1, 19.2: Default edge with `{ type: "expression", expression: "true" }` is evaluated last
- If no conditional edge matches → Use default edge (`is_default = true` or expression type)
- If no default edge → Use normal edge
- If no normal edge → Use first edge (fallback)

**Task 19.1, 19.2:** Default route checkbox in UI creates `{ type: "expression", expression: "true" }` condition

**Note:** Decision nodes use `condition_rule` with evaluation order (`priority` field), but this is separate from `selectNextNode()` logic.

### Conditional Routing with QC

**QC Pass Edge Selection (Task 18, 19.1, 19.2):**
- **Location:** `DAGRoutingService::selectNextNode()` → `ConditionEvaluator::evaluate()`
- **Flow:**
  1. Get outgoing edges from QC node
  2. Evaluate conditional edges using `ConditionEvaluator`:
     - Single condition: `{ type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }`
     - Multi-group: `{ type: "or", groups: [{ type: "and", conditions: [...] }] }`
  3. First matching condition wins
  4. If no conditional edge matches → Use default edge or normal edge
  5. Route token to matching edge

**QC Fail Edge Selection:**
- **Location:** `DAGRoutingService::handleQCFailWithPolicy()`
- **Flow:**
  1. Get rework edges (`edge_type = 'rework'`)
  2. Check rework limit
  3. If limit exceeded → Scrap token (or spawn replacement)
  4. If limit not exceeded → Route to rework edge
  5. **Alternative:** Conditional edge with `qc_result.status == 'fail_minor'` or `'fail_major'` (Task 19.1, 19.2)

**Task 19.1, 19.2:** Conditional edges are automatically evaluated using unified `ConditionEvaluator`. QC routing can use conditional edges with `qc_result.status` property instead of explicit `rework` edge type.

---

## Join Semantics (Merge Behavior)

### Merge Policies (Actual Implementation)

**From `ParallelMachineCoordinator::canMerge()` (`source/BGERP/Dag/ParallelMachineCoordinator.php:148`):**

#### 1. ALL (Default)
- **Requirement:** All branches must be completed
- **Logic:** `completed_count >= total_branches`
- **Use Case:** Standard parallel merge (wait for all branches)

#### 2. ANY
- **Requirement:** Any branch completed is enough
- **Logic:** `completed_count >= 1`
- **Use Case:** Race condition (first branch wins)

#### 3. AT_LEAST
- **Requirement:** At least N branches must be completed
- **Logic:** `completed_count >= at_least_count`
- **Use Case:** Partial completion (e.g., 3 out of 5 branches)

#### 4. TIMEOUT_FAIL
- **Requirement:** Wait for all branches, but fail if timeout exceeded
- **Logic:**
  1. Check timeout first (if exceeded → deadlock)
  2. If not exceeded → Use ALL semantics
- **Use Case:** Time-bounded parallel execution

### Merge Readiness Calculation

**From `ParallelMachineCoordinator::canMerge()`:**

```php
// Count branch states
$completedCount = 0;
$waitingMachineCount = 0;
$inMachineCount = 0;
$activeCount = 0;

foreach ($tokens as $token) {
    $status = $token['status'];
    $machineCode = $token['machine_code'];
    
    if ($status === 'completed') {
        $completedCount++;
    } elseif ($status === 'waiting' && !empty($machineCode)) {
        $waitingMachineCount++;
    } elseif ($status === 'active' && !empty($machineCode) && !empty($token['machine_cycle_started_at'])) {
        $inMachineCount++;
    } elseif ($status === 'active') {
        $activeCount++;
    }
}
```

**Note:** Only `completed` branches count toward merge readiness. Branches that are `waiting` or `active` (even if in machine) do not count.

### Deadlock Detection

**From `ParallelMachineCoordinator::isBlockStuck()` (`source/BGERP/Dag/ParallelMachineCoordinator.php:317`):**

**Checks:**
1. Branches waiting on inactive machines
2. Branches waiting but node has no machine binding (invalid state)

**Action:** If deadlock detected → Mark all tokens in group as 'stuck', return deadlock reason

### Timeout Handling

**From `ParallelMachineCoordinator::checkTimeout()` (`source/BGERP/Dag/ParallelMachineCoordinator.php:483`):**

**Logic:**
1. Get earliest token creation time in parallel group
2. Calculate elapsed seconds
3. Compare with `parallel_merge_timeout_seconds`
4. If exceeded → Return `timed_out = true`

**Note:** Timeout check is only performed for `TIMEOUT_FAIL` policy.

---

## Parallel Semantics

### Parallel Group ID Generation

**Location:** `TokenLifecycleService::splitToken()` (`source/BGERP/Service/TokenLifecycleService.php:665`)

**Logic:**
- If `parallel_group_id` provided → Use it
- If not provided → Use parent token ID as group ID
- **Rationale:** Parent token ID ensures uniqueness

### Parallel Branch Key Generation

**Location:** `TokenLifecycleService::splitToken()` (`source/BGERP/Service/TokenLifecycleService.php:676`)

**Logic:**
- If `branch_key` provided in split config → Use it
- If not provided → Auto-generate: "1", "2", "3", ... (based on branch index)

**Storage:** `flow_token.parallel_branch_key` (VARCHAR(50))

### Parallel Block Completion Detection

**Location:** `ParallelMachineCoordinator::canMerge()`

**Query:**
```sql
SELECT 
    id_token,
    status,
    machine_code,
    machine_cycle_started_at,
    parallel_branch_key
FROM flow_token
WHERE parallel_group_id = ?
ORDER BY parallel_branch_key ASC
```

**Completion Criteria:**
- Count tokens with `status = 'completed'`
- Compare with merge policy requirements

### Parallel + Machine Combined Execution

**Location:** `ParallelMachineCoordinator::onSplit()` (`source/BGERP/Dag/ParallelMachineCoordinator.php:47`)

**Flow:**
1. After split, for each child token:
   - Check if node needs machine (`machine_binding_mode != NONE`)
   - If yes → `MachineAllocationService::allocateMachine()`
   - If allocated → Set branch state to 'IN_MACHINE'
   - If waiting → Set branch state to 'WAITING_MACHINE', token status to 'waiting'
   - If no machine → Set branch state to 'READY'

2. Branch states tracked:
   - `READY` - No machine binding, can proceed
   - `IN_MACHINE` - Machine allocated, cycle started
   - `WAITING_MACHINE` - Waiting for machine availability
   - `ERROR` - Error state

**Note:** Machine allocation happens **per branch** independently. Different branches can use different machines.

---

## Rework Flow

### QC Fail → Rework

**Location:** `DAGRoutingService::handleQCFailWithPolicy()` (`source/BGERP/Service/DAGRoutingService.php:426`)

**Flow:**
1. Check rework limit (`rework_count >= rework_limit`)
2. If limit exceeded:
   - If `allow_scrap = true` → Scrap token
   - If `allow_replacement = true` → Spawn replacement token
   - Return scrapped status
3. If limit not exceeded:
   - Get rework edges (`edge_type = 'rework'`)
   - If no rework edge:
     - If `require_rework_edge = true` → Throw exception
     - If `allow_scrap = true` → Scrap token
   - If rework edge exists:
     - Route token to rework edge target node
     - Increment `rework_count`
     - Log rework event

### Rework Token Spawn

**Location:** `TokenLifecycleService::spawnReworkToken()` (`source/BGERP/Service/TokenLifecycleService.php:1322`)

**Flow:**
1. Create new token at target node
2. Set `token_type = 'rework'`
3. Set `serial_number = original_serial-REWORK`
4. Set `parent_token_id = original_token_id`
5. Set `status = 'ready'`
6. Mark original token as 'consumed' (`status = 'consumed'`, `consumed_at = NOW()`)
7. Create 'spawn_rework' + 'enter' events

**Note:** Rework tokens are separate tokens, not the same token moving backward.

---

## Flow Examples

### Example 1: Simple Linear Flow

```
[START] → [CUT] → [STITCH] → [QC] → [FINISH]
```

**Token States:**
1. Spawn: `ready` at START
2. After CUT complete: `ready` at STITCH
3. After STITCH complete: `ready` at QC
4. After QC pass: `ready` at FINISH
5. At FINISH: `completed`

---

### Example 2: Parallel with Machine

```
[START] → [CUT] → [PARALLEL SPLIT]
                    ├─→ [STITCH_BODY] (machine: SEW_MACHINE_001) ─┐
                    └─→ [STITCH_HANDLE] (machine: SEW_MACHINE_002) ─┤
                                                                   ↓
                                                              [MERGE] → [QC] → [FINISH]
```

**Token States:**
1. Parent token: `active` at CUT → `completed` after split
2. Child token 1: `active` at STITCH_BODY, `machine_code = SEW_MACHINE_001`
3. Child token 2: `active` at STITCH_HANDLE, `machine_code = SEW_MACHINE_002`
4. Both complete → Reach MERGE
5. Merge policy: ALL → Wait for both
6. After merge: `ready` at QC
7. After QC pass: `ready` at FINISH
8. At FINISH: `completed`

---

### Example 3: Conditional Routing

```
[START] → [CUT] → [DECISION]
                    ├─→ (qty > 10) → [BATCH_QC] → [FINISH]
                    └─→ (qty <= 10) → [SINGLE_QC] → [FINISH]
```

**Edge Conditions:**
- Edge 1: `{"type": "token_property", "property": "qty", "operator": ">", "value": 10}`
- Edge 2: `{"type": "token_property", "property": "qty", "operator": "<=", "value": 10}`

**Evaluation:**
1. Token reaches DECISION node
2. `selectNextNode()` evaluates edges in order
3. First matching condition wins
4. Route token to matching edge's target node

---

### Example 4: QC with Rework

```
[START] → [CUT] → [STITCH] → [QC]
                              ├─→ (pass) → [FINISH]
                              └─→ (fail) → [REWORK] → [STITCH] → [QC] → [FINISH]
```

**Flow:**
1. QC Pass → Route to FINISH
2. QC Fail → Route to REWORK edge target (back to STITCH)
3. Rework token spawned → `rework_count` incremented
4. If `rework_count >= rework_limit` → Scrap token (no more rework)

---

## Summary

This flow map documents the **actual execution paths** of tokens through SuperDAG graphs. Key findings:

1. **Token States:** 10 possible states (ready, active, waiting, paused, completed, scrapped, cancelled, merged, consumed, stuck)
2. **Parallel Execution:** Uses `parallel_group_id` and `parallel_branch_key` to track branches
3. **Merge Policies:** 4 policies supported (ALL, ANY, AT_LEAST, TIMEOUT_FAIL)
4. **Conditional Routing:** 5 condition types supported (qty_threshold, token_property, job_property, node_property, expression)
5. **Machine Allocation:** Per-branch, respects `concurrency_limit`
6. **Rework:** Separate token spawned, original token marked as 'consumed'

**Task 20-26 Enhancements:**
7. **Timezone Normalization:** All time operations use `TimeHelper` (canonical timezone: Asia/Bangkok)
8. **Canonical Events:** All behavior actions generate canonical events via `TokenEventService` (Task 21.2+)
9. **Timeline Engine:** `TimeEventReader` provides canonical timeline, syncs to `flow_token` (Task 21.5)
10. **Self-Healing:** `LocalRepairEngine` and `TimelineReconstructionEngine` for timeline repair (Task 22.1-22.3)
11. **MO Integration:** ETA calculation, load simulation, health monitoring integrated with MO lifecycle (Task 23.1-23.6)

**Next Steps:**
- Use this map to design Conditional Edge × QC Integration (Task 18.5+)
- Reference actual code locations when implementing new routing logic
- Maintain this document as execution paths evolve
- **All new flows must use TimeHelper for time operations**
- **All behavior actions must generate canonical events**

