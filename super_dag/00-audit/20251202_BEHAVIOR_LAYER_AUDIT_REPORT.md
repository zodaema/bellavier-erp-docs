# Behavior Layer Audit Report

**Date:** 2025-12-02  
**Version:** 1.0  
**Purpose:** Audit Behavior Layer เทียบกับ Token Lifecycle Model และ Component Flow Spec  
**Status:** ⚠️ CRITICAL - Behavior Layer ยังไม่ align กับ SuperDAG Universe

---

## Executive Summary

**⚠️ CRITICAL FINDING:**

Behavior Layer ปัจจุบันทำงานได้ในระดับ **Basic Functional** แต่ยังไม่ได้ integrate กับ:
1. ❌ Token Lifecycle Model (state transitions)
2. ❌ Component Flow (token_type awareness)
3. ❌ Parallel Execution (split/merge awareness)
4. ❌ Component Metadata (produces_component, component_times)

**Current State:** Legacy Simple Engine  
**Target State:** SuperDAG Behavior Engine

---

## 1. Token Status: Actual Values in Database

### 1.1 flow_token.status ENUM

**Source:** `database/tenant_migrations/0001_init_tenant_schema_v2.php` line 699

```sql
status ENUM(
    'ready',      -- Token พร้อมเริ่มงาน (ยังไม่ start)
    'active',     -- กำลังทำงาน (work session active) ✅ ใช้ 'active' ไม่ใช่ 'in_progress'
    'waiting',    -- รอ merge / รอ dependencies
    'paused',     -- หยุดชั่วคราว (worker pause)
    'completed',  -- เสร็จสิ้น
    'scrapped'    -- ยกเลิก / ทิ้ง
) NOT NULL DEFAULT 'ready'
```

**⚠️ IMPORTANT:** ระบบใช้ `'active'` **ไม่ใช่** `'in_progress'` หรือ `'inprogress'`

### 1.2 token_work_session.status ENUM

**Session status (separate from token status):**
```sql
status ENUM('active', 'paused', 'completed') DEFAULT 'active'
```

**Note:** Session status ≠ Token status  
- Session = worker's work period
- Token = work unit in graph

---

## 2. Current Behavior Handlers

### 2.1 Implemented Handlers

| Behavior Code | Handler Method | Token Status Handling | Session Handling |
|---------------|----------------|----------------------|------------------|
| **STITCH** | `handleStitch()` | ❌ None (delegates to session) | ✅ Yes (start/pause/resume/complete) |
| **CUT** | `handleCut()` | ❌ None | ✅ Yes (batch mode) |
| **EDGE** | `handleEdge()` | ❌ None | ✅ Yes |
| **QC_SINGLE** | `handleQc()` | ❌ None | ✅ Yes |
| **QC_FINAL** | `handleQc()` | ❌ None | ✅ Yes |
| **QC_REPAIR** | `handleQc()` | ❌ None | ✅ Yes |
| **QC_INITIAL** | `handleQc()` | ❌ None | ✅ Yes |
| **HARDWARE_ASSEMBLY** | `handleSinglePiece()` | ❌ None | ✅ Yes |
| **SKIVE** | `handleSinglePiece()` | ❌ None | ✅ Yes |
| **GLUE** | `handleSinglePiece()` | ❌ None | ✅ Yes |
| **ASSEMBLY** | `handleSinglePiece()` | ❌ None | ✅ Yes |
| **PACK** | `handleSinglePiece()` | ❌ None | ✅ Yes |
| **EMBOSS** | `handleSinglePiece()` | ❌ None | ✅ Yes |

**Key Finding:** 
- ✅ Session management works (via `TokenWorkSessionService`)
- ❌ Token status transitions **NOT handled by Behavior** (delegated to `TokenWorkSessionService`)
- ❌ Behavior ไม่รู้จัก node type (split/merge/normal)

### 2.2 Behavior Execution Flow

**Current Pattern (ALL behaviors):**
```php
// Start
1. Check active session (prevent duplicate)
2. Start session → TokenWorkSessionService::startToken()
   - Creates token_work_session record
   - Does NOT update flow_token.status ❌
3. Log behavior action
4. Return session_id

// Pause/Resume
1. Pause/Resume session → TokenWorkSessionService
   - Updates token_work_session.status
   - Does NOT update flow_token.status ❌

// Complete
1. Complete session → TokenWorkSessionService::completeToken()
   - Marks token_work_session.status = 'completed'
   - Does NOT update flow_token.status ❌
2. Route token → DagExecutionService::moveToNextNode()
   - DagExecutionService handles routing
   - May update flow_token.current_node_id
3. Return routing result
```

**⚠️ CRITICAL GAP:**
- Behavior เรียก `TokenWorkSessionService` แต่ไม่ได้จัดการ `flow_token.status` เลย
- `TokenWorkSessionService` จัดการเฉพาะ session status (ไม่ใช่ token status)
- **Token status transitions = MISSING**

---

## 3. Token Status Transition Gaps

### 3.1 What's Missing

**⚠️ IMPORTANT - Ownership Clarification:**

Behavior Layer ต้อง **trigger** การเปลี่ยนสถานะ token ตาม Token Lifecycle Model  
แต่ตัวที่ **เขียน status ลง DB** จริง ๆ ควรเป็น **TokenLifecycleService** (ไม่ใช่ Behavior ทำเอง)

**Architecture Principle:**
- ❌ Behavior ห้าม: `UPDATE flow_token SET status = 'active'` (direct DB update)
- ✅ Behavior ต้อง: `TokenLifecycle::startWork($tokenId)` (call lifecycle API)

**Based on Token Lifecycle Model, Behavior SHOULD trigger:**

| Event | Expected Lifecycle Transition | Current Behavior | Gap |
|-------|------------------------------|------------------|-----|
| **Start Work** | Call `TokenLifecycle::startWork()` → `ready` → `active` | ❌ ไม่มี call | CRITICAL |
| **Pause Work** | Call `TokenLifecycle::pauseWork()` → `active` → `paused` | ❌ ไม่มี call (only session) | CRITICAL |
| **Resume Work** | Call `TokenLifecycle::resumeWork()` → `paused` → `active` | ❌ ไม่มี call (only session) | CRITICAL |
| **Complete Node** | Call `TokenLifecycle::completeNode()` → varies by node type | ❌ ไม่มี call | CRITICAL |
| - Normal node | → `active` (move to next) | ✅ Partial (DagExecutionService routing) | Exists but should go through lifecycle |
| - Parallel split | → `waiting` + trigger component spawn | ❌ Not handled | BLOCKER |
| - Merge node | → re-activate parent + aggregate | ❌ Not handled | BLOCKER |
| - End node | → `completed` | ✅ Partial (DagExecutionService) | Exists but should go through lifecycle |
| **QC Fail** | Call `TokenLifecycle::scrapToken()` + spawn replacement | ❌ Not handled | HIGH |

**⚠️ Note on Current "Partial" Status:**
- DagExecutionService ปัจจุบันจัดการ routing และ mark completed (legacy)
- ในเป้า SuperDAG: ควรย้าย responsibility นี้ไปอยู่ที่ TokenLifecycleService
- เพื่อให้ token status transitions อยู่ที่เดียว (Single Responsibility)

### 3.2 Current vs Expected Flow

**Current Flow:**
```
Worker Start
    ↓
Create Session (token_work_session.status = 'active')
    ↓
[Token status unchanged] ❌
    ↓
Worker Complete
    ↓
Complete Session (token_work_session.status = 'completed')
    ↓
Route to Next Node (update current_node_id)
    ↓
[Token status unchanged unless end node] ❌
```

**Expected Flow (per Token Lifecycle Model):**
```
Worker Start
    ↓
Token status: ready → active ✅
    ↓
Create Session (token_work_session.status = 'active')
    ↓
Worker Complete
    ↓
Complete Session (token_work_session.status = 'completed')
    ↓
Check Node Type:
  - Normal node → Route to next (status = 'active')
  - Parallel split → Spawn components (status = 'waiting')
  - Merge node → Re-activate parent (status = 'active')
  - End node → Mark complete (status = 'completed')
```

---

## 4. Component Flow Integration Gaps

### 4.1 Token Type Awareness

**Current:**
```php
// Behavior does NOT check token_type
function handleStitch($sourcePage, $action, $context, $formData) {
    // Treats all tokens the same way
    // Does not differentiate between:
    // - token_type = 'piece' (final)
    // - token_type = 'component' (BODY/FLAP/STRAP)
}
```

**Target (per Component Flow Spec):**
```php
function handleStitch($sourcePage, $action, $context, $formData) {
    $token = fetchToken($tokenId);
    
    // Check token type
    if ($token['token_type'] === 'component') {
        // Component-specific rules:
        // - Validate component_code exists
        // - Check parallel group status
        // - Update component_times on complete
    } elseif ($token['token_type'] === 'piece') {
        // Final token rules:
        // - Check if all components complete (if waiting)
        // - Different routing logic
    }
}
```

### 4.2 Component Metadata Handling

**Current:**
- ❌ Behavior ไม่เขียน `component_code` ลง `metadata`
- ❌ Behavior ไม่เขียน `component_times` ลง `metadata`
- ❌ Behavior ไม่ validate `produces_component` ของ node

**Target (per Component Flow Spec Section 12):**
```php
// On component token complete
$metadata = [
    'component_code' => 'BODY',  // From node.produces_component
    'component_time_ms' => 7200000,  // Duration
    'worker_id' => 101,
    'worker_name' => 'Alice',
    'completed_at' => '2025-12-02 10:30:00'
];

// Update token
UPDATE flow_token 
SET metadata = JSON_MERGE_PATCH(metadata, ?)
WHERE id_token = ?
```

### 4.3 Behavior Support Matrix Validation

**Current:**
- ❌ Behavior ไม่ validate ว่ารองรับ token_type หรือไม่

**Target (per Component Flow Spec Section 3.2):**
```php
function validateBehaviorTokenType($behaviorCode, $tokenType) {
    $matrix = [
        'STITCH' => ['piece' => true, 'component' => true],
        'CUT' => ['batch' => true, 'piece' => false, 'component' => false],
        'ASSEMBLY' => ['piece' => true, 'component' => false],
        'PACK' => ['piece' => true, 'component' => false],
        'QC_FINAL' => ['piece' => true, 'component' => false],
    ];
    
    return $matrix[$behaviorCode][$tokenType] ?? false;
}
```

---

## 5. Parallel Execution Awareness Gaps

### 5.1 Split Node Handling

**Current:**
- ❌ Behavior ไม่รู้ว่า node เป็น `is_parallel_split = 1`
- ❌ เมื่อ complete ที่ split node → ไม่ spawn component tokens

**Target Behavior:**

**⚠️ NOTE:** Pseudo-code ด้านล่างอธิบาย **TARGET SYSTEM BEHAVIOR**  
**Owner:** Logic นี้ควรอยู่ใน **TokenLifecycleService** / **ParallelMachineCoordinator**  
**NOT** in BehaviorExecutionService ตรง ๆ

**Behavior Layer responsibility:**
- ตรวจว่า node เป็น split node หรือไม่
- เรียก `TokenLifecycle::completeSplitNode($tokenId, $nodeId)`
- Lifecycle service จัดการ spawn + status update

```php
// TARGET: Behavior Layer
function handleBehaviorComplete($tokenId, $nodeId) {
    $node = fetchNode($nodeId);
    
    if ($node['is_parallel_split'] === 1) {
        // Call lifecycle service (NOT implement split logic here)
        $lifecycleService = new TokenLifecycleService($this->db);
        $lifecycleService->completeSplitNode($tokenId, $nodeId);
        return;
    }
}

// TARGET: TokenLifecycleService (owner of split logic)
class TokenLifecycleService {
    function completeSplitNode($tokenId, $nodeId) {
        $edges = getOutgoingEdges($nodeId);
        $parallelGroupId = generateParallelGroupId();
        
        foreach ($edges as $i => $edge) {
            $targetNode = getNode($edge['to_node_id']);
            $this->spawnComponentToken([
                'parent_token_id' => $tokenId,
                'parallel_group_id' => $parallelGroupId,
                'parallel_branch_key' => ($i + 1),
                'component_code' => $targetNode['produces_component'],
                'current_node_id' => $edge['to_node_id']
            ]);
        }
        
        // Set parent to waiting
        $this->updateTokenStatus($tokenId, 'waiting');
    }
}
```

### 5.2 Merge Node Handling

**Current:**
- ❌ Behavior ไม่รู้ว่า node เป็น `is_merge_node = 1`
- ❌ ไม่ validate ว่า components ครบหรือยัง
- ❌ ไม่ re-activate parent token

**Target Behavior:**

**⚠️ NOTE:** Pseudo-code ด้านล่างอธิบาย **TARGET SYSTEM BEHAVIOR**  
**Owner:** Logic นี้ควรอยู่ใน **ParallelMachineCoordinator** / **TokenLifecycleService**  
**NOT** in BehaviorExecutionService ตรง ๆ

**Behavior Layer responsibility:**
- ตรวจว่า node เป็น merge node หรือไม่
- เรียก `ParallelMachineCoordinator::completeMergeNode($tokenId, $nodeId)`
- Coordinator จัดการ validation + aggregation + re-activation

```php
// TARGET: Behavior Layer
function handleBehaviorComplete($tokenId, $nodeId) {
    $node = fetchNode($nodeId);
    
    if ($node['is_merge_node'] === 1) {
        // Call coordinator service (NOT implement merge logic here)
        $coordinator = new ParallelMachineCoordinator($this->db, $this->org);
        $coordinator->completeMergeNode($tokenId, $nodeId);
        return;
    }
}

// TARGET: ParallelMachineCoordinator (owner of merge logic)
class ParallelMachineCoordinator {
    function completeMergeNode($tokenId, $nodeId) {
        $token = fetchToken($tokenId);
        
        if ($token['token_type'] === 'component') {
            // Check if all siblings complete
            $allComplete = $this->checkAllComponentsComplete($token['parent_token_id'], $nodeId);
            
            if ($allComplete) {
                // Aggregate component data
                $componentTimes = $this->aggregateComponentTimes($token['parent_token_id']);
                
                // Re-activate parent token
                $lifecycleService = new TokenLifecycleService($this->db);
                $lifecycleService->reActivateToken($token['parent_token_id'], $nodeId, [
                    'component_times' => $componentTimes
                ]);
                
                // Mark components as merged
                $this->markComponentsAsMerged($token['parent_token_id']);
            }
        }
    }
}
```

---

## 6. Failure Mode Handling Gaps

**Current:**
- ❌ ไม่มี QC fail recovery (spawn replacement)
- ❌ ไม่มี component scrapped recovery
- ❌ ไม่มี wrong tray detection
- ❌ ไม่มี partial component completion handling
- ❌ ไม่มี final token cascade cancel

**Target (per Component Flow Spec Section 13):**
- Implement 7 failure scenarios:
  1. Component Token Scrapped → spawn replacement
  2. Assembly Rejects Component → reopen (spawn rework)
  3. Wrong Tray → block + supervisor override
  4. Partial Completion → block merge + supervisor override
  5. Final Token Cancel → cascade to components
  6. Wrong Component Complete → supervisor reopen
  7. Split Node Error → repair orphaned splits

---

## 7. UI Contract Gaps

### 7.1 Current UI

**What Behavior UI Shows:**
- Token ID
- Serial Number
- Node Name
- Start/Pause/Resume/Complete buttons

**What UI DOES NOT Show:**
- ❌ Token type (piece/component/batch)
- ❌ Component code (BODY/FLAP/STRAP)
- ❌ Parent token info (if component)
- ❌ Sibling component status (if parallel)
- ❌ Parallel group progress
- ❌ Component time breakdown

### 7.2 Target UI (per Component Flow)

**Component Worker View:**
```
┌────────────────────────────────────────┐
│ Component: BODY                        │
│ Final Serial: F001                     │
│ Tray: T-F001                          │
│ Progress: 2/3 components complete      │
│   ✅ BODY (you) - 2h 15m              │
│   ✅ FLAP - 1h 45m                    │
│   ⏳ STRAP - In progress              │
│                                        │
│ [Start] [Pause] [Complete]            │
└────────────────────────────────────────┘
```

**Assembly Worker View:**
```
┌────────────────────────────────────────┐
│ Final Serial: F001                     │
│ Components: 3/3 ✅ Ready for assembly │
│ Total Component Time: 5h 00m           │
│ Bottleneck: BODY (2h 15m)             │
│                                        │
│ [Start Assembly]                       │
└────────────────────────────────────────┘
```

---

## 8. Summary: Behavior Layer Status

| Feature | Status | Gap Description |
|---------|--------|-----------------|
| **Basic Session Management** | ✅ Working | Start/pause/resume/complete sessions work |
| **Token Status Transitions** | ❌ Missing | Behavior doesn't update flow_token.status |
| **Token Type Awareness** | ❌ Missing | Doesn't differentiate piece/component/batch |
| **Component Metadata** | ❌ Missing | Doesn't write component_code, component_times |
| **Parallel Split Handling** | ❌ Missing | Doesn't spawn component tokens |
| **Merge Handling** | ❌ Missing | Doesn't re-activate parent, aggregate data |
| **Behavior Matrix Validation** | ❌ Missing | Doesn't validate behavior-token type compatibility |
| **Failure Mode Recovery** | ❌ Missing | No QC fail, scrapped, wrong tray handling |
| **UI Component Support** | ❌ Missing | UI doesn't show component info |
| **Routing Integration** | 🚧 Partial | Works for normal nodes, missing split/merge |

**Overall Status:** 🔴 **NOT READY for Component Flow**

---

## 9. Recommended Roadmap

### Phase 1: Token Status Transitions (Critical)
**Priority:** 🔴 BLOCKER  
**Effort:** 2-3 days  
**Owner:** TokenLifecycleService + glue in BehaviorExecutionService

**Tasks:**
1. Create `TokenLifecycleService::startWork()`, `pauseWork()`, `resumeWork()`, `completeNode()`
2. Update BehaviorExecutionService to call lifecycle APIs (ไม่ UPDATE token status ตรง ๆ)
3. Bind behavior completion to node type (normal/split/merge)
4. Test status transitions with Token Lifecycle Model

**Deliverables:**
- TokenLifecycleService handles all token status transitions
- Behavior Layer triggers lifecycle transitions correctly
- All state transitions follow Token Lifecycle Model

### Phase 2: Component Flow Integration (Critical)
**Priority:** 🔴 BLOCKER  
**Effort:** 3-5 days  
**Owner:** ComponentFlowService + ParallelMachineCoordinator + Behavior glue

**Tasks:**
1. Create `ComponentFlowService` (owner of component metadata logic)
2. Add token_type awareness in all behaviors (read only, no business logic)
3. Update ParallelMachineCoordinator to handle split/merge for component tokens
4. Add behavior-token type validation matrix
5. Behavior calls ComponentFlowService for component metadata writing

**Deliverables:**
- ComponentFlowService handles component metadata
- ParallelMachineCoordinator handles split/merge
- Behavior Layer supports component tokens (via service calls)
- Component parallel flow works end-to-end

### Phase 3: Failure Mode Recovery (High)
**Priority:** 🟡 HIGH  
**Effort:** 3-4 days  
**Owner:** FailureRecoveryService (new) + Behavior glue

**Tasks:**
1. Create `FailureRecoveryService` (owner of recovery logic)
2. Implement QC fail recovery (spawn replacement)
3. Implement component scrapped recovery
4. Implement wrong tray detection (via TrayValidationService)
5. Implement supervisor override mechanisms
6. Implement cascade cancel
7. Behavior calls FailureRecoveryService for exception handling

**Deliverables:**
- FailureRecoveryService handles all 7 failure scenarios
- Behavior Layer triggers recovery correctly
- Production-ready error recovery

### Phase 4: UI Enhancement (Medium)
**Priority:** 🟢 MEDIUM  
**Effort:** 2-3 days  
**Owner:** Frontend (PWA / Hatthasilpa UI)

**⚠️ Separation of Concerns:**
- **Behavior API (Backend):** ส่งข้อมูล (token + component summary + tray binding)
- **Frontend:** Render ตาม template, จัดเรียง component list, badge ฯลฯ
- **Behavior ห้าม:** กำหนด layout หรือ UI wording (ให้ frontend จัดการ)

**Tasks:**
1. Backend: Add API endpoint `get_token_ui_data` (token + components + tray + parallel status)
2. Frontend: Update behavior UI templates for component tokens
3. Frontend: Show component info, parallel progress
4. Frontend: Show final serial, tray info
5. Frontend: Assembly worker view (components completion status)

**Deliverables:**
- Behavior API ส่งข้อมูลครบถ้วน
- Component worker UI shows parallel progress
- Assembly worker UI shows components ready status
- Clear separation: Backend = data, Frontend = presentation

---

## 10. Critical Dependencies

**To complete Phase 1-2, we need:**
1. ✅ Token Lifecycle Model (DONE - `SUPERDAG_TOKEN_LIFECYCLE.md`)
2. ✅ Component Flow Spec (DONE - `COMPONENT_PARALLEL_FLOW_SPEC.md` v2.1)
3. ❌ `routing_node.produces_component` field (TARGET - not implemented)
4. ❌ `routing_node.consumes_components` field (TARGET - not implemented)
5. ❌ Split/Merge logic in `TokenLifecycleService` (TARGET - not implemented)

**Without dependencies 3-5:**
- Can implement Phase 1 (token status transitions)
- **Cannot implement** Phase 2 (component flow) fully

**Workaround:**
- Use `metadata` JSON field for `component_code` (temporary)
- Hard-code split/merge logic in behavior layer (technical debt)

---

## 11. References

**Core Architecture:**
- `docs/dag/03-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - Token lifecycle model
- `docs/dag/03-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Component flow spec (v2.1)
- `docs/developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md` - Behavior contracts

**Audit Reports:**
- `docs/dag/00-audit/20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md` - Component parallel status

**Database Schema:**
- `database/tenant_migrations/0001_init_tenant_schema_v2.php` - flow_token, token_work_session

**Source Code:**
- `source/BGERP/Dag/BehaviorExecutionService.php` - Behavior handlers
- `source/BGERP/Service/TokenWorkSessionService.php` - Session management
- `source/BGERP/Dag/DagExecutionService.php` - Routing logic

---

## 12. Conclusion

**Current State:**
- Behavior Layer = **Legacy Simple Engine**
- Works for basic linear flow
- **NOT ready** for SuperDAG Universe (Component Flow, Parallel Execution)

**Target State:**
- Behavior Layer = **SuperDAG Behavior Engine (Orchestrator)**
- Token Lifecycle aware (calls TokenLifecycleService)
- Component Flow integrated (calls ComponentFlowService)
- Parallel execution aware (calls ParallelMachineCoordinator)
- Failure recovery built-in (calls FailureRecoveryService)
- Production-ready

**Gap:** 🔴 **CRITICAL** - Requires significant refactoring (8-12 days effort)

**Next Step:** 
1. Read `../02-specs/BEHAVIOR_EXECUTION_SPEC.md` (target blueprint)
2. Start Phase 1 (Token Status Transitions) - **BLOCKER for Component Flow**

**⚠️ Important Note:**
- Audit report นี้โฟกัส: **"ตอนนี้เป็นอย่างไร"**
- Implementation spec: **"ควรเป็นอย่างไร"** → See `BEHAVIOR_EXECUTION_SPEC.md`

---

**END OF AUDIT REPORT**

