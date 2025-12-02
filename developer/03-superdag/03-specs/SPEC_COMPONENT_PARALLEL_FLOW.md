# Component Parallel Flow Spec

**Status:** Active Specification  
**Date:** 2025-01-XX  
**Version:** 1.0  
**Category:** SuperDAG / Component Token / Parallel Work

**⚠️ CRITICAL VISION:** Component Token = **CORE MECHANIC** ของ Hatthasilpa Workflow  
**ไม่ใช่ optional enhancement แต่เป็น mandatory architecture**

**⚠️ MECHANISM:** Component Token uses **Native Parallel Split** (`is_parallel_split` flag), **NOT Subgraph `fork` mode**

**See Also:** `docs/dag/SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md` - Detailed comparison of Subgraph vs Component Token mechanisms

---

## 1. Core Principle: Component Tokens = First-Class Tokens

### 1.1 Component Token = Core Mechanic

**Component Token = First-Class Token** (ไม่ใช่ sub-token หรือ optional feature)

**Architecture Principle:**
- Component Token มี work session ของตัวเอง
- Component Token มี time tracking ของตัวเอง
- Component Token มี behavior execution ของตัวเอง
- Component Token = **Core Mechanic** ของ Hatthasilpa workflow

### 1.2 Job Tray (ถาดงาน) - Physical Container

**⚠️ CRITICAL:** Job Tray = Physical container in factory

**Relationship:**
- 1 Final Token = 1 Job Tray
- All components of a Final Token → Must be in the same tray
- Tray has QR/Tag with `final_serial` / `id_final_token`

**Database:**
```sql
job_tray:
  - id_tray (PK)
  - id_final_token (FK to flow_token.id_token)
  - final_serial (VARCHAR) -- For QR/Tag
  - tray_code (VARCHAR) -- Physical tray identifier
```

**Physical Reality:**
- Workers pick up "Tray F001" → Work with all components of F001
- No mixing: Components of F001 must stay in Tray F001
- Digital relationship (`parent_token_id`) = Physical relationship (tray)

**❌ Anti-pattern:**
- ❌ **DO NOT allow components of one piece to mix with another piece's tray**

**Why Component Tokens Are Mandatory:**

1. **Parallel Craftsmanship Model:**
   - Bag มีหลายชิ้นส่วน (BODY, FLAP, STRAP, LINING, etc.)
   - แต่ละชิ้นส่วนทำโดยช่างคนละคน **พร้อมกัน (parallel)**
   - แต่ละช่างจับเวลาแยกกัน
   - Assembly = รวมชิ้นส่วนที่เสร็จแล้ว

2. **Component-Level Time Tracking:**
   - แต่ละช่างจับเวลาแยกกัน
   - Component token = work session แยกกัน
   - Time tracking per component = จำเป็นสำหรับ craftsmanship analytics

3. **ETA Model:**
   - ETA ของทั้งใบ = `max(component_times) + assembly_time`
   - Bottleneck = component ที่ใช้เวลานานที่สุด
   - ต้อง track component time แยกกันเพื่อคำนวณ ETA

4. **Assembly Merge:**
   - Assembly node = join component tokens
   - Final serial = output ของ component merge
   - ต้องรอให้ทุก component เสร็จก่อน assembly

5. **Craftsmanship Traceability:**
   - Storytelling ของกระเป๋า = เวลาของแต่ละช่างในแต่ละชิ้น
   - ต้องรู้ว่าใครทำชิ้นไหน ใช้เวลาเท่าไหร่
   - Component token = signature ของแต่ละช่าง

6. **Multi-Craftsman Signature:**
   - แต่ละ component = signature ของช่างคนนั้น
   - QC ของแต่ละ component = คนละ node, คนละ behavior
   - ต้อง track component-level QC แยกกัน

7. **Bottleneck Analytics:**
   - ชิ้นไหนเสร็จช้า = bottleneck ของใบ
   - ต้องวิเคราะห์ component time เพื่อหา bottleneck
   - Component token = data source สำหรับ analytics

---

## 2. Component Tokens Have Their Own Work Sessions

### 2.1 Work Session Per Component Token

**Rule:** Component Token = First-Class Token → มี work session ของตัวเอง

**Implementation:**
- Component tokens use `TokenWorkSessionService` (same as regular tokens)
- No restrictions on `token_type` in `TokenWorkSessionService`
- Each component token can have its own work session independently

**Workflow:**
1. Component token created via `splitToken()` (parallel split)
2. Worker starts work on component token → `TokenWorkSessionService::startToken()`
3. Worker pauses/resumes work → `TokenWorkSessionService::pauseToken()` / `resumeToken()`
4. Worker completes work → `TokenWorkSessionService::completeToken()`
5. Time tracked per component token independently

**Example:**
```
Component Token #1 (BODY):
  - Worker A starts work → Session #1 created
  - Worker A pauses → Session #1 paused
  - Worker A resumes → Session #1 resumed
  - Worker A completes → Session #1 completed
  - Time: 2 hours (tracked independently)

Component Token #2 (FLAP):
  - Worker B starts work → Session #2 created
  - Worker B completes → Session #2 completed
  - Time: 1.5 hours (tracked independently)

Component Token #3 (STRAP):
  - Worker C starts work → Session #3 created
  - Worker C completes → Session #3 completed
  - Time: 1 hour (tracked independently)
```

### 2.2 Time Tracking Per Component

**Rule:** Component time = tracked independently per component token

**Data Model:**
- `token_work_session.id_token` = component token ID
- `token_work_session.work_seconds` = component work time
- Each component token has its own work session record

**Time Calculation:**
- Component time = `work_seconds` from `token_work_session` for component token
- Total component time = sum of all component times
- ETA = `max(component_times) + assembly_time`

---

## 3. Behavior Execution Must Accept Component Tokens

### 3.1 Component Token in Behavior Execution

**Rule:** Behavior Execution Service must accept `id_component_token`

**Current Implementation:**
- `BehaviorExecutionService::execute()` accepts `context['token_id']`
- Component tokens can use behavior execution (no restrictions)
- But no explicit workflow/documentation for component token behavior execution

**Required:**
- Behavior Execution Service must explicitly support component tokens
- Component tokens must have their own behavior execution
- Component-level QC = separate behavior execution

**Example:**
```
Component Token #1 (BODY) at STITCH node:
  - Behavior: STITCH
  - Action: stitch_start
  - Worker: Worker A
  - Time: Tracked per component token

Component Token #2 (FLAP) at STITCH node:
  - Behavior: STITCH
  - Action: stitch_start
  - Worker: Worker B
  - Time: Tracked per component token (separate from Token #1)
```

### 3.2 Behavior Support Matrix (CRITICAL FOR IMPLEMENTATION)

**Rule:** Not all behaviors support component tokens

**Behavior Support Table:**

| Behavior Code | Piece Token | Component Token | Notes |
|--------------|-------------|-----------------|-------|
| STITCH | ✅ | ✅ | Works on both piece and component |
| EDGE | ✅ | ✅ | Works on both piece and component |
| CUT | ✅ | ❌ | Piece-only (batch mode, no component) |
| QC_SINGLE | ✅ | ✅ | QC can happen at component level |
| QC_FINAL | ✅ | ✅ | Final QC can include component QC |
| QC_REPAIR | ✅ | ✅ | Component can be repaired |
| QC_INITIAL | ✅ | ✅ | Initial QC can be component-level |
| HARDWARE_ASSEMBLY | ✅ | ✅ | Component assembly behavior |
| SKIVE | ✅ | ✅ | Works on both piece and component |
| GLUE | ✅ | ✅ | Works on both piece and component |
| ASSEMBLY | ✅ | ❌ | Assembly = merge component tokens (not component token itself) |
| PACK | ✅ | ❌ | Pack = final product only |
| EMBOSS | ✅ | ✅ | Works on both piece and component |

**Implementation Rules:**

1. **Behavior Execution Service:**
   ```php
   // In BehaviorExecutionService::execute()
   $token = $this->fetchToken($context['token_id']);
   $tokenType = $token['token_type'];
   
   // Check if behavior supports token type
   if ($tokenType === 'component' && !$this->behaviorSupportsComponent($behaviorCode)) {
       return [
           'ok' => false,
           'error' => 'BEHAVIOR_COMPONENT_NOT_SUPPORTED',
           'behavior_code' => $behaviorCode,
           'token_type' => $tokenType
       ];
   }
   ```

2. **Behavior Support Check:**
   ```php
   private function behaviorSupportsComponent(string $behaviorCode): bool
   {
       $componentSupported = [
           'STITCH', 'EDGE', 'QC_SINGLE', 'QC_FINAL', 
           'QC_REPAIR', 'QC_INITIAL', 'HARDWARE_ASSEMBLY',
           'SKIVE', 'GLUE', 'EMBOSS'
       ];
       return in_array($behaviorCode, $componentSupported, true);
   }
   ```

3. **Work Queue Rendering:**
   - Component tokens appear in work queue with `token_type = 'component'`
   - UI must show component code (BODY, FLAP, STRAP) in work queue
   - Behavior panel must accept component tokens
   - Behavior template must handle component tokens (same as piece tokens for supported behaviors)

**Status:** ✅ **CURRENT** - BehaviorExecutionService works with any token type, but explicit support check not yet implemented

### 3.3 Component-Level Behaviors

**Rule:** Component tokens can have their own behaviors

**Behaviors per Component:**
- STITCH component → STITCH behavior (supports component)
- QC component → QC behavior (supports component)
- Each component = separate behavior execution

**Work Queue Integration:**
- Workers see component tokens in work queue
- Workers can start/pause/resume/complete work on component tokens
- Component tokens = separate work items
- UI must distinguish component tokens from piece tokens

---

## 4. Parallel Routing = Official Hatthasilpa Model

### 4.1 Node-to-Component Mapping (CRITICAL FOR IMPLEMENTATION)

**Rule:** Nodes must declare which component they produce or consume

**Database Schema (Required):**
```sql
ALTER TABLE routing_node
    ADD COLUMN produces_component VARCHAR(64) NULL 
        COMMENT 'Component code this node produces (e.g., BODY, FLAP, STRAP)',
    ADD COLUMN consumes_components JSON NULL 
        COMMENT 'Array of component codes this node consumes (e.g., ["BODY", "STRAP", "FLAP"])',
    ADD KEY idx_produces_component (produces_component);
```

**Mapping Rules:**

1. **Split/Start Nodes (Component Creation):**
   - `produces_component` = 'BODY' or 'STRAP' or 'FLAP' etc.
   - Used to set `component_code` on spawned tokens
   - Each outgoing edge from split node = one component branch
   - Example:
     ```sql
     -- Split node creates BODY component
     UPDATE routing_node 
     SET produces_component = 'BODY' 
     WHERE node_code = 'SPLIT_BODY';
     ```

2. **Operation Nodes (Component Work):**
   - `produces_component` = component code this node works on
   - Used to route component tokens to correct nodes
   - Example:
     ```sql
     -- STITCH node works on BODY component
     UPDATE routing_node 
     SET produces_component = 'BODY' 
     WHERE node_code = 'STITCH_BODY';
     ```

3. **Assembly/Join Nodes (Component Merge):**
   - `consumes_components` = `["BODY", "STRAP", "FLAP"]`
   - Used to validate that required components have arrived
   - Used to validate component tokens are correctly linked
   - Example:
     ```sql
     -- Assembly node consumes all components
     UPDATE routing_node 
     SET consumes_components = '["BODY", "STRAP", "FLAP"]' 
     WHERE node_code = 'ASSEMBLY_FINAL';
     ```

**Implementation Logic:**
```php
// When token arrives at node
$node = fetchNode($nodeId);

// Check if node produces component
if ($node['produces_component']) {
    $componentCode = $node['produces_component'];
    // Set component_code on token
    $token['component_code'] = $componentCode;
}

// Check if node consumes components (merge node)
if ($node['consumes_components']) {
    $requiredComponents = json_decode($node['consumes_components'], true);
    // Validate all required components have arrived
    validateComponentCompleteness($tokenId, $requiredComponents);
}
```

**Status:** 📋 **TARGET / TODO** - Schema not yet implemented (Task 5)

### 4.2 Parallel Split → Component Tokens

**Rule:** Parallel split creates component tokens

**Workflow:**
1. Parent token reaches parallel split node (`is_parallel_split = 1`)
2. System reads `produces_component` from each outgoing edge's target node
3. System creates N component tokens (one per branch)
4. Each component token has:
   - `token_type = 'component'`
   - `component_code` = from target node's `produces_component`
   - `parallel_group_id` (same for all components)
   - `parallel_branch_key` (unique per component: "1", "2", "3", ...)
   - `parent_token_id` (reference to parent token)

**Example:**
```
Parent Token (Final Product):
  - Reaches parallel split node (is_parallel_split = 1)
  - Outgoing edges:
    - Edge 1 → Node "STITCH_BODY" (produces_component = 'BODY')
    - Edge 2 → Node "STITCH_FLAP" (produces_component = 'FLAP')
    - Edge 3 → Node "STITCH_STRAP" (produces_component = 'STRAP')
  - Creates 3 component tokens:
    - Component Token #1: component_code = 'BODY', parallel_branch_key = "1"
    - Component Token #2: component_code = 'FLAP', parallel_branch_key = "2"
    - Component Token #3: component_code = 'STRAP', parallel_branch_key = "3"
  - All have same parallel_group_id
```

**Current Implementation:**
- ✅ `splitToken()` can create component tokens
- ✅ `parallel_group_id` and `parallel_branch_key` exist
- ✅ `parent_token_id` is set (MANDATORY)
- ❌ `produces_component` mapping not yet implemented
- ❌ `component_code` on token not yet set automatically

**⚠️ CRITICAL RULE:**
- ❌ **Component Token MUST have parent_token_id** (no orphan components)
- ✅ Final Token status = 'waiting' or 'split' after split (not deleted)
- ✅ Final Token still linked to Job Tray (tray doesn't disappear)

### 4.2 Parallel Execution

**Rule:** Component tokens execute in parallel

**Workflow:**
1. Component tokens move to their respective nodes
2. Workers start work on component tokens independently
3. Time tracked per component token independently
4. Components complete at different times

**Example:**
```
Time 0:00 - Parallel split creates 3 component tokens
Time 0:00 - Worker A starts BODY (Component Token #1)
Time 0:00 - Worker B starts FLAP (Component Token #2)
Time 0:00 - Worker C starts STRAP (Component Token #3)

Time 1:00 - Worker C completes STRAP (Component Token #3)
Time 1:30 - Worker B completes FLAP (Component Token #2)
Time 2:00 - Worker A completes BODY (Component Token #1)

Bottleneck: BODY (2 hours)
ETA: 2 hours (max component time) + 0.5 hours (assembly) = 2.5 hours
```

---

## 5. Assembly Node = Join Component Tokens

### 5.1 Merge Node Semantics (CRITICAL FOR IMPLEMENTATION)

**Rule:** Assembly node = join component tokens into final token

**Workflow:**
1. Component tokens complete their work
2. Component tokens move to assembly/merge node (`is_merge_node = 1`)
3. Merge node reads `consumes_components` to know which components to wait for
4. Merge node waits for all components (merge policy: `parallel_merge_policy = 'ALL'`)
5. When all components arrive → **re-activate parent token** (not create new token)
6. Parent token = final token (already exists, just reactivated)

**Merge Policy (from routing_node):**
- `parallel_merge_policy = 'ALL'` (default) - Wait for all components
- `parallel_merge_policy = 'AT_LEAST'` - Wait for minimum count (`parallel_merge_at_least_count`)
- `parallel_merge_policy = 'TIMEOUT_FAIL'` - Timeout if not all arrive (`parallel_merge_timeout_seconds`)

**Merge Implementation:**

1. **Component Tokens Arrive at Merge Node:**
   ```php
   // In DAGRoutingService::handleMergeNode()
   $node = fetchNode($nodeId);
   $requiredComponents = json_decode($node['consumes_components'], true);
   
   // Add component token to join buffer
   $tokenService->addToJoinBuffer($instanceId, $nodeId, $predecessorNodeId, $tokenId);
   
   // Check if all required components arrived
   $arrivedComponents = getArrivedComponents($instanceId, $nodeId);
   if (allComponentsArrived($arrivedComponents, $requiredComponents)) {
       // Re-activate parent token
       $parentTokenId = $componentTokens[0]['parent_token_id'];
       reactivateParentToken($parentTokenId, $nodeId);
   }
   ```

2. **Re-activate Parent Token:**
   ```php
   // Parent token was in 'waiting' or 'split' status
   // Re-activate = set status to 'active', move to merge node
   UPDATE flow_token 
   SET status = 'active',
       current_node_id = ?,
       updated_at = NOW()
   WHERE id_token = ?;
   ```

3. **Component Tokens Status After Merge:**
   ```php
   // Component tokens are marked as 'merged' (not deleted)
   UPDATE flow_token 
   SET status = 'merged',
       merged_into_token_id = ?,
       merged_at = NOW()
   WHERE id_token IN (?, ?, ?);
   ```

**Example:**
```
Assembly Node (Merge):
  - consumes_components = ["BODY", "FLAP", "STRAP"]
  - Waits for Component Token #1 (BODY) → Arrives at Time 2:00
  - Waits for Component Token #2 (FLAP) → Arrives at Time 1:30
  - Waits for Component Token #3 (STRAP) → Arrives at Time 1:00
  - All components arrived → Re-activate Parent Token
  - Parent Token (id_token = 100) → status = 'active', current_node_id = assembly_node
  - Component Tokens → status = 'merged', merged_into_token_id = 100
```

**Data Contract (What Gets Merged):**

1. **Component Time Summary:**
   ```php
   $componentTimes = [];
   foreach ($componentTokens as $compToken) {
       $session = getWorkSession($compToken['id_token']);
       $componentTimes[$compToken['component_code']] = $session['work_seconds'];
   }
   // Store in parent token metadata
   $parentToken['component_times'] = json_encode($componentTimes);
   ```

2. **Craftsmanship Summary:**
   ```php
   $craftsmen = [];
   foreach ($componentTokens as $compToken) {
       $assignment = getTokenAssignment($compToken['id_token']);
       $craftsmen[$compToken['component_code']] = $assignment['operator_name'];
   }
   // Store in parent token metadata
   $parentToken['component_craftsmen'] = json_encode($craftsmen);
   ```

3. **Component Token IDs:**
   ```php
   // Store component token IDs for reference
   $componentTokenIds = array_column($componentTokens, 'id_token');
   $parentToken['merged_component_tokens'] = json_encode($componentTokenIds);
   ```

4. **QC Status:**
   ```php
   $qcStatus = [];
   foreach ($componentTokens as $compToken) {
       $qcResult = getLastQcResult($compToken['id_token']);
       $qcStatus[$compToken['component_code']] = $qcResult['result'];
   }
   // Store in parent token metadata
   $parentToken['component_qc_status'] = json_encode($qcStatus);
   ```

**Component Token Discard Rules:**

- ✅ **Component tokens are NOT deleted** - They are marked as 'merged'
- ✅ **Component tokens remain in database** - For traceability and analytics
- ✅ **Component tokens can be queried** - Via `merged_into_token_id` or `parent_token_id`
- ✅ **Component tokens are archived** - Status = 'merged', not 'completed'

### 5.2 Component Time Aggregation

**Rule:** Assembly node aggregates component times

**Time Aggregation:**
- Component times: [2 hours, 1.5 hours, 1 hour]
- Max component time: 2 hours (BODY)
- Assembly time: 0.5 hours (work session on parent token at assembly node)
- Total time: 2.5 hours

**Data Model:**
- Final token tracks component times in metadata (`component_times` JSON)
- Final token tracks max component time (`max_component_time` seconds)
- Final token tracks total component time (`total_component_time` seconds)
- Final token tracks assembly time separately (`assembly_time` seconds)

**Implementation:**
```php
// After merge, aggregate component times
$componentTimes = [];
$maxTime = 0;
$totalTime = 0;

foreach ($componentTokens as $compToken) {
    $session = getWorkSession($compToken['id_token']);
    $time = $session['work_seconds'] ?? 0;
    $componentTimes[$compToken['component_code']] = $time;
    $maxTime = max($maxTime, $time);
    $totalTime += $time;
}

// Store in parent token
UPDATE flow_token 
SET component_times = ?,
    max_component_time = ?,
    total_component_time = ?
WHERE id_token = ?;
```

---

## 6. Final Serial = Created at Job Creation (NOT at Assembly)

### 6.1 Serial Generation at Job Creation

**⚠️ CRITICAL RULE:** Final serial = **created at Job Creation** (NOT at Assembly)

**Workflow:**
1. **Job Creation:** System creates Final Token with `final_serial` immediately
2. Component tokens created (reference parent token via `parent_token_id`)
3. Component tokens work in parallel
4. Component tokens complete
5. Component tokens arrive at assembly node
6. **Assembly = Re-activate Final Token** (final serial already exists)

**Serial Structure:**
- Final serial: `MA01-HAT-DIAG-20251201-00001-A7F3-X` (created at Job Creation)
- Component serials: Generated separately (if needed) - **Just labels, not relationship mechanism**

**Database:**
```sql
-- Final Token created with serial at Job Creation
flow_token:
  - id_token (Final Token)
  - serial_number = 'MA01-HAT-DIAG-20251201-00001-A7F3-X' (created immediately)
  - token_type = 'piece' or 'final'
```

**❌ Anti-pattern:**
- ❌ **DO NOT generate final serial at Assembly**
- ❌ **DO NOT wait for assembly to create final serial**

**✅ Correct Pattern:**
- ✅ Final serial exists from Job Creation
- ✅ Assembly = Re-activate Final Token (not create new)

### 6.2 Component Serial = Label Only (NOT Relationship Mechanism)

**⚠️ CRITICAL RULE:** Component serial = **label / human-readable ID only**

**Relationship Mechanism:**
- Real relationship = `parent_token_id` / `parallel_group_id` / `merged_into_token_id`
- **DO NOT use serial pattern matching for relationships**

**Binding:**
- Component serials bound via `ComponentBindingService` (if needed)
- Binding occurs at assembly node (optional)
- **Component serial = Just a label, not the relationship mechanism**

**Data Model:**
- `job_component_serial.final_piece_serial` = final serial (label)
- `job_component_serial.component_serial` = component serial (label)
- `job_component_serial.id_component_token` = component token ID (**Real relationship**)
- `job_component_serial.id_final_token` = final token ID (**Real relationship**)

**❌ Anti-pattern:**
```php
// ❌ WRONG - Using serial pattern matching
if (substr($componentSerial, 0, 4) === substr($finalSerial, 0, 4)) {
    // Match by serial pattern
}
```

**✅ Correct Pattern:**
```php
// ✅ CORRECT - Using parent_token_id
if ($componentToken['parent_token_id'] === $finalToken['id_token']) {
    // Match by parent_token_id
}
```

---

## 7. ETA = max(component-times) + assembly

### 7.1 ETA Calculation Model

**Rule:** ETA = `max(component_times) + assembly_time`

**Formula:**
```
ETA = max(
  component_1_time,
  component_2_time,
  component_3_time,
  ...
) + assembly_time
```

**Example:**
```
Component Times:
  - BODY: 2 hours
  - FLAP: 1.5 hours
  - STRAP: 1 hour

Max Component Time: 2 hours (BODY)
Assembly Time: 0.5 hours

ETA = 2 hours + 0.5 hours = 2.5 hours
```

### 7.2 Bottleneck Detection

**Rule:** Bottleneck = component with maximum time

**Detection:**
- Track component times per component token
- Identify component with maximum time
- Bottleneck = component that delays final assembly

**Analytics:**
- Component time distribution
- Bottleneck frequency by component type
- Bottleneck impact on ETA

---

## 8. Work Queue Integration

### 8.1 Component Tokens in Work Queue

**Rule:** Component tokens appear in work queue

**Work Queue Display:**
- Component tokens shown separately or grouped by `parallel_group_id`
- Workers see component tokens assigned to them
- Component tokens = separate work items

**UI Requirements:**
- Show component token type (BODY, FLAP, STRAP, etc.)
- Show component time independently
- Show parallel group status
- Show assembly readiness

### 8.2 Component Token Assignment (CRITICAL FOR IMPLEMENTATION)

**Rule:** Component tokens assignable to workers

**Assignment Rules:**

1. **Who Assigns Component Tokens:**
   - ✅ **Supervisor/Manager** - Manual assignment via Work Queue UI
   - ✅ **Auto-assignment** - Based on `routing_node.assignment_policy` (if configured)
   - ✅ **Self-claim** - Workers can claim component tokens (if `assignment_policy = 'self_claim'`)
   - ❌ **Not auto-assigned by default** - Requires explicit assignment

2. **Assignment Policy:**
   ```php
   // From routing_node.assignment_policy
   - 'manual' - Supervisor must assign (default)
   - 'self_claim' - Workers can claim component tokens
   - 'round_robin' - Auto-assign in round-robin fashion
   - 'least_loaded' - Auto-assign to worker with least tokens
   ```

3. **Component Token Assignment Table:**
   ```sql
   -- token_assignment table (already exists)
   INSERT INTO token_assignment (
       id_token, 
       id_operator, 
       assigned_by, 
       status, 
       assigned_at
   ) VALUES (?, ?, ?, 'assigned', NOW());
   ```

4. **One Worker, Multiple Components:**
   - ✅ **Allowed** - Worker can work on multiple component types
   - Example: Worker A can work on BODY and FLAP components
   - But typically: One worker = one component type (specialization)

5. **Component Token Assignment = Separate from Final Token:**
   - Component tokens have their own assignments
   - Final token (parent) has separate assignment
   - Component assignment ≠ Final token assignment

**Work Queue Display:**
- Workers see component tokens assigned to them
- Workers see component code (BODY, FLAP, STRAP) in work queue
- Workers can filter by component code
- Workers can see parallel group status

**Example:**
```
Worker A Work Queue:
  - Component Token #1 (BODY, parallel_group_id = 100) - Assigned to Worker A
  - Component Token #4 (BODY, parallel_group_id = 101) - Assigned to Worker A
  - (No FLAP or STRAP tokens - assigned to other workers)

Worker B Work Queue:
  - Component Token #2 (FLAP, parallel_group_id = 100) - Assigned to Worker B
  - Component Token #5 (FLAP, parallel_group_id = 101) - Assigned to Worker B
  - (No BODY or STRAP tokens - assigned to other workers)

Worker C Work Queue:
  - Component Token #3 (STRAP, parallel_group_id = 100) - Assigned to Worker C
  - Component Token #6 (STRAP, parallel_group_id = 101) - Assigned to Worker C
  - (No BODY or FLAP tokens - assigned to other workers)
```

**Self-Claim Workflow:**
```php
// Worker clicks "Claim" button on component token
POST /dag_token_api.php
{
  "action": "claim_component_token",
  "token_id": 123,
  "operator_id": 456
}

// System checks:
// 1. Token is component token (token_type = 'component')
// 2. Token is not yet assigned
// 3. Node allows self-claim (assignment_policy = 'self_claim')
// 4. Worker has permission to claim
```

**Status:** 📋 **TARGET / TODO** - Assignment UI and self-claim workflow not yet implemented

---

## 9. Behavior Execution for Component Tokens

### 9.1 Component Token Behavior Execution

**Rule:** Component tokens have their own behavior execution

**Workflow:**
1. Component token arrives at node
2. Node has behavior (e.g., STITCH, QC)
3. Worker starts work on component token
4. Behavior execution uses component token ID
5. Time tracked per component token

**API Contract:**
```json
{
  "behavior_code": "STITCH",
  "source_page": "work_queue",
  "action": "stitch_start",
  "context": {
    "token_id": 123,  // Component token ID
    "node_id": 456,
    "work_center_code": "WC_STITCH_01",
    "component_code": "BODY",  // Optional: component identifier
    "parallel_group_id": 789,  // Optional: parallel group
    "parallel_branch_key": "1"  // Optional: branch key
  },
  "form_data": {}
}
```

### 9.2 Component-Level QC

**Rule:** QC can happen at component level

**Workflow:**
1. Component token arrives at QC node
2. QC behavior executed on component token
3. Component-level QC result (pass/fail/rework)
4. Component token routed based on QC result

**Example:**
```
Component Token #1 (BODY) at QC_SINGLE node:
  - QC behavior executed
  - Result: PASS
  - Component token routed to next node

Component Token #2 (FLAP) at QC_SINGLE node:
  - QC behavior executed
  - Result: FAIL
  - Component token routed to rework node
```

---

## 10. Data Model Requirements

### 10.1 Flow Token Schema

**Current Fields (✅ Exists):**
- `token_type` enum('batch', 'piece', 'component') - ✅ Exists
- `parallel_group_id` int NULL - ✅ Exists
- `parallel_branch_key` varchar NULL - ✅ Exists
- `parent_token_id` int FK - ✅ Exists
- `merged_into_token_id` int FK - ✅ Exists (for merged component tokens)
- `merged_at` DATETIME NULL - ✅ Exists (for merged component tokens)

**Missing Fields (Task 5 - 📋 Planned):**
- `component_code` varchar(64) - 📋 Planned (e.g., 'BODY', 'FLAP', 'STRAP')
- `id_component` int FK - 📋 Planned (FK to product_component table)
- `root_serial` varchar(100) - 📋 Planned (root serial for genealogy)
- `root_token_id` int FK - 📋 Planned (root token for genealogy)

**Component Code Schema (Task 5 - 📋 Planned):**

```sql
-- product_component table (planned)
CREATE TABLE product_component (
    id_component INT PRIMARY KEY AUTO_INCREMENT,
    id_product INT NOT NULL,
    component_code VARCHAR(64) NOT NULL,
    component_name VARCHAR(200) NOT NULL,
    component_type ENUM('BODY', 'FLAP', 'STRAP', 'LINING', 'HARDWARE', 'OTHER') NOT NULL,
    is_required TINYINT(1) NOT NULL DEFAULT 1,
    default_qty INT NOT NULL DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_product_component (id_product, component_code),
    FOREIGN KEY (id_product) REFERENCES product(id_product) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Current Workaround:**
- Component code can be stored in `flow_token.metadata` JSON field (temporary)
- Component code can be derived from `routing_node.produces_component` (when implemented)
- Component code can be stored in `job_component_serial.component_code` (for binding)

**Status:** 📋 **TARGET / TODO** - Component code schema not yet implemented (Task 5)

### 10.2 Token Work Session Schema

**Current Schema:**
- `id_token` int FK - ✅ Works with component tokens
- `work_seconds` int - ✅ Tracks component time
- No restrictions on `token_type` - ✅ Component tokens supported

**Status:** ✅ **Complete** - No changes needed

### 10.3 Component Serial Binding Schema

**Current Schema:**
- `job_component_serial` table - ✅ Exists
- `id_component_token` int FK - ✅ Exists
- `id_final_token` int FK - ✅ Exists
- `component_serial` varchar(100) - ✅ Exists
- `final_piece_serial` varchar(100) - ✅ Exists

**Status:** ✅ **Complete** - No changes needed

---

## 11. Integration Points

### 11.1 Behavior Execution Service

**Required:**
- `BehaviorExecutionService` must accept component tokens
- Component tokens must have their own behavior execution
- Component-level behaviors = separate from final token behaviors

**Current Status:**
- ✅ Infrastructure exists (can work with component tokens)
- ✅ `BehaviorExecutionService::execute()` accepts any token type
- ❌ Explicit component token support check not yet implemented
- ❌ Behavior support matrix not yet enforced

**Alignment with Behavior App Contract:**

1. **Work Queue as Client:**
   - Work Queue calls `BGBehaviorExec.send()` with component token ID
   - Behavior App receives component token ID in `context['token_id']`
   - Behavior App executes behavior on component token (same as piece token)

2. **Behavior Template Rendering:**
   - Component tokens use same behavior templates as piece tokens
   - UI must show component code (BODY, FLAP, STRAP) in behavior panel
   - Behavior panel must distinguish component tokens from piece tokens

3. **Behavior Execution Mode:**
   - Component tokens use same execution modes as piece tokens
   - `execution_mode` from `routing_node` applies to component tokens
   - Example: STITCH behavior on component token = `HAT_SINGLE` mode

4. **Behavior Logging:**
   - Component token behavior execution logged to `dag_behavior_log`
   - Component token canonical events logged to `token_event`
   - Component token work sessions logged to `token_work_session`

### 11.2 Work Queue

**Required:**
- Work Queue must show component tokens
- Workers see component tokens assigned to them
- Component tokens = separate work items

**Current Status:**
- ❌ UI support missing
- ❌ Component token display missing

### 11.3 Time Engine

**Required:**
- Time Engine must track component time independently
- Component time aggregation at assembly
- ETA calculation using component times

**Current Status:**
- ✅ Infrastructure exists (TokenWorkSessionService works)
- ❌ Aggregation logic missing

### 11.4 Assembly Node

**Required:**
- Assembly node must wait for all components
- Assembly node must aggregate component times
- Assembly node must **re-activate Final Token** (final serial already exists)

**Current Status:**
- ✅ Merge infrastructure exists
- ❌ Time aggregation missing
- ❌ Final token re-activation missing

**⚠️ CRITICAL:**
- ❌ **DO NOT generate final serial at Assembly** (final serial exists from Job Creation)
- ✅ **DO re-activate Final Token** (status = 'active', move to assembly node)

---

## 12. Implementation Checklist

### 12.1 Priority 1: BLOCKERS (Must Fix for Production)

- [ ] **Implement Node-to-Component Mapping**
  - Add `produces_component` and `consumes_components` to `routing_node`
  - Update `DAGRoutingService::handleSplitNode()` to set `component_code` on tokens
  - Update `DAGRoutingService::handleMergeNode()` to validate component completeness
  - **Status: MANDATORY, not optional**

- [ ] **Implement Component Code Schema (Task 5)**
  - Create `product_component` table
  - Add `component_code` to `flow_token`
  - Link BOM to components
  - **Status: MANDATORY, not optional**

- [ ] **Implement Behavior Support Matrix**
  - Add `behaviorSupportsComponent()` check in `BehaviorExecutionService`
  - Enforce behavior support rules (CUT, ASSEMBLY, PACK = piece-only)
  - Update behavior handlers to handle component tokens explicitly
  - **Status: MANDATORY, not optional**

- [ ] **Implement Merge Node Data Contract**
  - Aggregate component times into parent token metadata
  - Store craftsmanship summary (who made which component)
  - Store QC status per component
  - Store component token IDs for reference
  - **Status: MANDATORY, not optional**

- [ ] **Document Component Token Time Tracking Workflow**
  - Document that component tokens can use `TokenWorkSessionService`
  - Create workflow for parallel component work
  - Add examples of component time tracking
  - **Status: MANDATORY, not optional**

- [ ] **Implement Work Queue UI for Component Tokens**
  - Add UI support for component tokens
  - Show component tokens in parallel groups
  - Display component code (BODY, FLAP, STRAP) in work queue
  - Display component time independently
  - **Status: MANDATORY, not optional**

- [ ] **Implement Component Time Aggregation**
  - Add logic to aggregate component times at assembly
  - Show component time summary
  - Track total component time vs assembly time
  - ETA = `max(component_times) + assembly_time`
  - **Status: MANDATORY, not optional**

### 12.2 Priority 2: Required for Full Functionality

- [ ] **Component Token Assignment UI**
  - Implement assignment UI in Work Queue
  - Support manual assignment by supervisor
  - Support self-claim workflow (if `assignment_policy = 'self_claim'`)
  - Show assignment status in work queue
  - **Status: Required for parallel work**

- [ ] **Component Token Filtering in Work Queue**
  - Filter by component code (BODY, FLAP, STRAP)
  - Filter by parallel group
  - Show parallel group status (waiting for other components)
  - **Status: Required for parallel work**

- [ ] **Component Token Analytics**
  - Component time distribution
  - Bottleneck detection per component type
  - Component-level QC pass/fail rates
  - **Status: Required for analytics**

### 12.3 Priority 3: Long Term

- [ ] **Implement Component Model (Task 5)**
  - Create `product_component` table
  - Add `component_code` to `flow_token`
  - Add `produces_component` / `consumes_components` to `routing_node`
  - Link BOM to components
  - **Status: Required for full component model**

---

## 13. References

- **Component Parallel Work Audit:** `docs/dag/COMPONENT_PARALLEL_WORK_AUDIT.md`
- **Component Serial Binding Spec:** `docs/developer/03-superdag/03-specs/SPEC_COMPONENT_SERIAL_BINDING.md`
- **Component Model Task:** `docs/dag/03-tasks/TASK_DAG_5_COMPONENT_MODEL.md`
- **Time Engine Spec:** `docs/developer/03-superdag/03-specs/SPEC_TIME_ENGINE.md`
- **Behavior App Contract:** `docs/developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md`
- **Parallel Work Architecture:** `docs/developer/03-superdag/01-core/SuperDAG_Architecture.md`

---

---

## 14. Implementation Gaps Summary

**Critical Gaps (Must Fix Before Production):**

1. **Node-to-Component Mapping:**
   - ❌ `routing_node.produces_component` not yet implemented
   - ❌ `routing_node.consumes_components` not yet implemented
   - ❌ `flow_token.component_code` not yet set automatically

2. **Component Code Schema:**
   - ❌ `product_component` table not yet created
   - ❌ Component master data not yet defined

3. **Behavior Support Matrix:**
   - ❌ Explicit component token support check not yet implemented
   - ❌ Behavior support rules not yet enforced

4. **Merge Node Data Contract:**
   - ❌ Component time aggregation not yet implemented
   - ❌ Craftsmanship summary not yet stored
   - ❌ Component token metadata not yet merged into parent token

5. **Work Queue UI:**
   - ❌ Component token display not yet implemented
   - ❌ Component code display not yet implemented
   - ❌ Component assignment UI not yet implemented

**Status Legend:**
- ✅ **Current** - Implemented and working
- 🚧 **Partial** - Partially implemented, needs completion
- 📋 **Target / TODO** - Planned but not yet implemented
- ❌ **Missing** - Not implemented, blocking production

---

## 15. Anti-Patterns (ข้อห้าม)

### 15.1 ❌ DO NOT Create Component Token Without parent_token_id

**Rule:**
- Component Token ทุกตัวต้องมี `parent_token_id` (ชี้ไป Final Token)
- ไม่มี Component ที่ลอยไม่มี parent_token_id

**Validation:**
```php
// When creating component token
if (empty($componentToken['parent_token_id'])) {
    throw new Exception('Component token must have parent_token_id');
}
```

### 15.2 ❌ DO NOT Generate Final Serial at Assembly

**Rule:**
- Final Serial เกิดตั้งแต่ Job Creation (ไม่ใช่ที่ Assembly)
- Assembly = ขั้นรวมข้อมูล/เวลา/ช่างจาก Component Tokens เข้าสู่ Final Token

**Validation:**
```php
// At Assembly node
if ($finalToken['serial_number'] === null) {
    throw new Exception('Final serial must exist before assembly');
}
```

### 15.3 ❌ DO NOT Mix Components Between Trays

**Rule:**
- ชิ้นส่วนของ F001 ต้องอยู่ในถาด F001 เสมอ
- Digital relationship (`parent_token_id`) = Physical relationship (tray)

**Validation:**
```php
// When moving component token
$componentToken = fetchToken($componentTokenId);
$finalToken = fetchToken($componentToken['parent_token_id']);
$tray = fetchTray($finalToken['id_job_tray']);

// Ensure component belongs to correct tray
if ($tray['id_final_token'] !== $finalToken['id_token']) {
    throw new Exception('Component must belong to correct tray');
}
```

### 15.4 ❌ DO NOT Use Serial Pattern Matching for Relationships

**Rule:**
- ใช้ `parent_token_id` + `parallel_group_id` เท่านั้น
- ห้ามใช้ pattern matching ของ serial numbers

**Anti-pattern:**
```php
// ❌ WRONG
if (substr($componentSerial, 0, 4) === substr($finalSerial, 0, 4)) {
    // Match by serial pattern
}
```

**✅ Correct Pattern:**
```php
// ✅ CORRECT
if ($componentToken['parent_token_id'] === $finalToken['id_token']) {
    // Match by parent_token_id
}
```

### 15.5 ❌ DO NOT Show Component Tokens to Assembly Worker

**Rule:**
- ช่าง Assembly ควรเห็นแค่ "Final Token F001" และหยิบถาด F001 ใบเดียว
- UI ต้องแสดง Final Token พร้อมสถานะว่า "components complete"
- ไม่ต้องแสดงรายการ component tokens ให้ช่าง Assembly

**UI Pattern:**
```
✅ CORRECT:
Work Queue (Assembly Worker):
  - Final Token F001 [Components: Complete] [Tray: F001]
  - Final Token F002 [Components: Complete] [Tray: F002]

❌ WRONG:
Work Queue (Assembly Worker):
  - Component Token: BODY (F001)
  - Component Token: FLAP (F001)
  - Component Token: STRAP (F001)
  - ... (worker has to find components manually)
```

### 15.6 ❌ DO NOT Use Subgraph `fork` Mode for Component Token

**Rule:**
- Component Token = Native Parallel Split (`is_parallel_split=1`)
- Component Token ≠ Subgraph `fork` mode (wrong mechanism)

**Reasons:**
1. Component Token = Product-specific (not reusable)
2. Component Token = Physical tray mapping (subgraph cannot handle)
3. Component Token = Native parallel split (no subgraph overhead)
4. Component Token = Component metadata (`produces_component`, `component_code`)
5. Subgraph fork = Reusable parallel module (different purpose)

**❌ WRONG: Using Subgraph fork**
```
MAIN GRAPH:
   CUT → SUBGRAPH(BAG_COMPONENTS_FORK) → ASSEMBLY

BAG_COMPONENTS_FORK (subgraph):
   ENTRY → SPLIT → [BODY, FLAP, STRAP] → JOIN → EXIT
```

**Problems:**
- ❌ Subgraph is product-specific (not reusable)
- ❌ Version-controlled subgraph for product components (too rigid)
- ❌ Different products have different components (not reusable)

**✅ CORRECT: Using Native Parallel Split**
```
MAIN GRAPH:
   CUT → PARALLEL_SPLIT (is_parallel_split=1) → [BODY, FLAP, STRAP] → MERGE (is_merge_node=1) → ASSEMBLY

BODY Branch:
   STITCH_BODY (produces_component='BODY') → QC_BODY

FLAP Branch:
   STITCH_FLAP (produces_component='FLAP') → QC_FLAP

STRAP Branch:
   STITCH_STRAP (produces_component='STRAP') → QC_STRAP
```

**Benefits:**
- ✅ Product-specific (graph = product routing)
- ✅ Flexible (changes with product design)
- ✅ Component-level QC (separate nodes per component)
- ✅ Native parallel split/merge (no subgraph overhead)

**See:** `docs/dag/SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md` for detailed comparison

---

**Last Updated:** 2025-01-XX  
**Version:** 1.3 (Clarified: Native Parallel Split, NOT Subgraph)  
**Status:** Active Specification  
**Maintained By:** Development Team

