# Work Queue & Token Lifecycle Integration Audit

**Audit Date:** December 2, 2025  
**Audit Type:** Integration Analysis & Gap Identification  
**Scope:** Work Queue APIs, BehaviorExecutionService, TokenLifecycleService  
**Purpose:** Pre-Task 27.2 audit to identify integration points and potential issues  
**Auditor:** AI Agent + Owner Review

---

## Executive Summary

**Audit Goal:** Understand current Work Queue implementation and identify integration gaps before implementing Task 27.2 (Extend TokenLifecycleService)

**Key Finding:** 🚨 **Session-Token Status Drift Risk**

Current implementation updates **work sessions** but **NOT token status** during start/pause/resume operations, causing potential state inconsistency.

**Impact:**
- ⚠️ **Medium Risk** - Token status may not reflect actual work state
- ⚠️ System still functional but status queries may be inaccurate
- ✅ **Easy Fix** - Task 27.2 provides the missing lifecycle methods

**Status:** ✅ No blockers found, safe to proceed with Task 27.2

---

## 1. System Architecture Overview

### 1.1 Current Service Layer

```
┌─────────────────────────────────────────────────────────────┐
│                   Work Queue System                         │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
┌───────────────▼────────────┐  ┌───────────▼──────────────────┐
│  worker_token_api.php      │  │  dag_behavior_exec.php       │
│  (Task 20.3)               │  │  (Task 5-6)                  │
└───────────────┬────────────┘  └───────────┬──────────────────┘
                │                           │
                │                           │
┌───────────────▼────────────┐  ┌───────────▼──────────────────┐
│ TokenWorkSessionService    │  │  BehaviorExecutionService    │
│ (BGERP\Service)            │  │  (BGERP\Dag)                 │
│ - Session management       │  │  - Behavior logic            │
└────────────────────────────┘  └───────────┬──────────────────┘
                                            │
                                ┌───────────▼──────────────────┐
                                │ TokenWorkSessionService      │
                                │ (BGERP\Dag - wrapper)        │
                                └──────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│  TokenLifecycleService (BGERP\Service)                     │
│  - Token spawn, move, complete, cancel, split              │
│  ❌ MISSING: startWork, pauseWork, resumeWork methods       │
└────────────────────────────────────────────────────────────┘
```

### 1.2 Critical Files

| File | Purpose | Status | Lines |
|------|---------|--------|-------|
| `source/worker_token_api.php` | Work Queue API (Task 20.3) | ✅ Active | 1184 |
| `source/dag_behavior_exec.php` | Behavior execution API | ✅ Active | 302 |
| `source/BGERP/Dag/BehaviorExecutionService.php` | Behavior handlers | ✅ Active | 2250 |
| `source/BGERP/Service/TokenLifecycleService.php` | Token lifecycle | ⚠️ Incomplete | 1560 |
| `source/BGERP/Service/TokenWorkSessionService.php` | Session management | ✅ Active | ~500 |
| `source/BGERP/Dag/TokenWorkSessionService.php` | Session wrapper | ✅ Active | 506 |

---

## 2. Work Queue API Audit (worker_token_api.php)

### 2.1 API Actions

| Action | Handler | Status | Integration Quality |
|--------|---------|--------|---------------------|
| `start_token` | handleStartToken() | ✅ Works | ⚠️ Partial (session only) |
| `pause_token` | handlePauseToken() | ✅ Works | ⚠️ Partial (session only) |
| `resume_token` | handleResumeToken() | ✅ Works | ⚠️ Partial (session only) |
| `complete_token` | handleCompleteToken() | ✅ Works | ✅ Full (session + lifecycle + routing) |
| `get_current_work` | handleGetCurrentWork() | ✅ Works | ✅ Read-only |
| `get_next_work` | handleGetNextWork() | ✅ Works | ✅ Read-only |

### 2.2 Integration Analysis

#### ✅ **What Works Well:**

1. **Service Layer Usage:**
   ```php
   // Line 39-41
   use BGERP\Service\TokenLifecycleService;
   use BGERP\Service\TokenWorkSessionService;
   use BGERP\Service\DAGRoutingService;
   ```
   ✅ Uses proper service layer (no direct SQL)

2. **Enterprise Standards:**
   ```php
   // Line 68: Rate limiting
   RateLimiter::check($member, 120, 60, 'worker_token');
   
   // Line 182-192: Request validation
   $validation = RequestValidator::make($_POST, [...]);
   ```
   ✅ Follows enterprise patterns

3. **Complete Token Flow (Line 509-633):**
   ```php
   // ✅ Full integration
   $sessionResult = $sessionService->completeToken($tokenId, $employeeId);
   $lifecycleService->completeToken($tokenId, $employeeId);
   $routingResult = $routingService->routeToken($tokenId, $employeeId);
   ```
   ✅ Session + Lifecycle + Routing all integrated

#### ❌ **Integration Gaps:**

**Gap 1: handleStartToken() - Missing Lifecycle Call**

**Location:** Line 242-248

**Current Code:**
```php
// ✅ Updates session
$result = $sessionService->startToken(
    $tokenId,
    $employeeId,
    $operatorName,
    'own',
    ''
);

// ❌ MISSING: Update token status
// Should call: $lifecycleService->startWork($tokenId);
```

**Impact:**
- Session status = `'active'`
- Token status = `'ready'` (unchanged!)
- **Drift:** Session says "working" but token says "ready"

**Root Cause:**
- `TokenLifecycleService::startWork()` method doesn't exist yet
- Will be added in Task 27.2

---

**Gap 2: handlePauseToken() - Missing Lifecycle Call**

**Location:** Line 345

**Current Code:**
```php
// ✅ Updates session
$result = $sessionService->pauseToken($tokenId, $reason);

// ❌ MISSING: Update token status
// Should call: $lifecycleService->pauseWork($tokenId);
```

**Impact:**
- Session status = `'paused'`
- Token status = `'active'` (unchanged!)
- **Drift:** Session says "paused" but token says "active"

**Root Cause:**
- `TokenLifecycleService::pauseWork()` method doesn't exist yet
- Will be added in Task 27.2

---

**Gap 3: handleResumeToken() - Missing Lifecycle Call**

**Location:** Line 469

**Current Code:**
```php
// ✅ Updates session
$result = $sessionService->resumeToken($tokenId);

// ❌ MISSING: Update token status
// Should call: $lifecycleService->resumeWork($tokenId);
```

**Impact:**
- Session status = `'active'`
- Token status = `'paused'` (unchanged!)
- **Drift:** Session says "active" but token says "paused"

**Root Cause:**
- `TokenLifecycleService::resumeWork()` method doesn't exist yet
- Will be added in Task 27.2

---

### 2.3 Validation & Safety Rules

**✅ Implemented Safety Rules (Phase 2):**

1. **Invariant 1: One Active Token per Employee** (Line 201-210)
   ```php
   $activeSession = $sessionService->getOperatorActiveSession($employeeId);
   if ($activeSession) {
       json_error('EMPLOYEE_HAS_ACTIVE_TOKEN', 409, [...]);
   }
   ```
   ✅ Prevents multi-tasking

2. **Invariant 2: Single Owner per Active Token** (Line 331-342, 443-453, 564-579)
   ```php
   if ($activeSession && (int)$activeSession['operator_user_id'] !== $employeeId) {
       json_error('TOKEN_OWNED_BY_ANOTHER_EMPLOYEE', 403, [...]);
   }
   ```
   ✅ Prevents worker conflicts

3. **Invariant 3: No Start on Completed Tokens** (Line 213-239, 303-329, 414-440, 536-562)
   ```php
   if (in_array($status, ['completed', 'scrapped', 'cancelled', 'merged'])) {
       json_error('TOKEN_NOT_ACTIVE', 400, [...]);
   }
   ```
   ✅ Prevents invalid operations

4. **Soft Rule 4: Long-Idle Session Warning** (Line 455-466)
   ```php
   if ($idleHours >= 8) {
       $warning = 'RESUME_AFTER_LONG_IDLE';
   }
   ```
   ✅ User experience improvement

**Status:** Safety rules are comprehensive and well-implemented.

---

## 3. Behavior Execution Service Audit

### 3.1 BehaviorExecutionService.php Analysis

**Location:** `source/BGERP/Dag/BehaviorExecutionService.php` (2250 lines)

**Behaviors Supported:**
- STITCH (dedicated handler)
- CUT (batch handler)
- EDGE (multi-round handler)
- QC_SINGLE, QC_FINAL, QC_REPAIR, QC_INITIAL (QC handler)
- HARDWARE_ASSEMBLY, SKIVE, GLUE, ASSEMBLY, PACK, EMBOSS (single-piece handler)

### 3.2 Integration Gaps

**Gap 4: STITCH Behavior - Missing Lifecycle Calls**

**Location:** Line 394-430 (handleStitch)

**Current Code:**
```php
if ($action === 'stitch_start') {
    $sessionResult = $sessionService->startSession($tokenId, $nodeId, $this->workerId);
    // ❌ MISSING: $lifecycleService->startWork($tokenId);
}
elseif ($action === 'stitch_pause') {
    $sessionResult = $sessionService->pauseSession($tokenId, $nodeId, $this->workerId);
    // ❌ MISSING: $lifecycleService->pauseWork($tokenId);
}
elseif ($action === 'stitch_resume') {
    $sessionResult = $sessionService->resumeSession($tokenId, $nodeId, $this->workerId);
    // ❌ MISSING: $lifecycleService->resumeWork($tokenId);
}
elseif ($action === 'stitch_complete') {
    $coreSessionService->completeToken($tokenId, $this->workerId);
    // ❌ MISSING: $lifecycleService->completeNode($tokenId, $nodeId);
}
```

**Impact:**
- Same as worker_token_api.php gaps
- Session-token status drift

---

**Gap 5: Single-Piece Behaviors - Missing Lifecycle Calls**

**Location:** Line 1887-1893 (handleSinglePiece dispatcher)

**Current Code:**
```php
if (substr($normalizedActionLower, -6) === '_start') {
    return $this->handleSinglePieceStart(...);  // ❌ No lifecycle call
}
elseif (substr($normalizedActionLower, -6) === '_pause') {
    return $this->handleSinglePiecePause(...);  // ❌ No lifecycle call
}
elseif (substr($normalizedActionLower, -7) === '_resume') {
    return $this->handleSinglePieceResume(...); // ❌ No lifecycle call
}
elseif (substr($normalizedActionLower, -8) === '_complete') {
    return $this->handleSinglePieceComplete(...); // ❌ No lifecycle call
}
```

**Affected Behaviors:**
- HARDWARE_ASSEMBLY, SKIVE, GLUE, ASSEMBLY, PACK, EMBOSS

**Impact:**
- All single-piece behaviors have same gap as STITCH
- Consistent pattern makes fix straightforward (Task 27.3)

---

### 3.3 Dependencies Analysis

**Current Dependencies:**
```php
// Line 31-32
use BGERP\Dag\TokenWorkSessionService as DagTokenWorkSessionService;
use BGERP\Dag\DagExecutionService;
```

**Missing Dependencies:**
```php
// ❌ NOT IMPORTED (will be needed in Task 27.3):
use BGERP\Service\TokenLifecycleService;
```

**Note:** BehaviorExecutionService currently does NOT use TokenLifecycleService at all. This is the integration gap that Task 27.2 + 27.3 will fix.

---

## 4. Token Status Update Audit

### 4.1 Direct UPDATE flow_token.status Locations

**Found in 3 files:**

1. **TokenLifecycleService.php** (BGERP\Service)
   - ✅ **Legitimate** - This is the owner of token lifecycle
   - Updates: spawn (ready), complete (completed), cancel (scrapped), merge, etc.
   - **Verdict:** ✅ Correct - This is the canonical owner

2. **DAGRoutingService.php** (BGERP\Service)
   - ⚠️ **Should delegate** to TokenLifecycleService
   - Updates: Token movement, routing
   - **Verdict:** ⚠️ Future refactor candidate (not urgent)

3. **ParallelMachineCoordinator.php** (BGERP\Dag)
   - ⚠️ **Should delegate** to TokenLifecycleService
   - Updates: Parallel split/merge operations
   - **Verdict:** ⚠️ Future refactor candidate (Phase 3)

### 4.2 Token Status Update Pattern

**Current Pattern (Multiple Owners):**
```
Token Status Updates:
├─ TokenLifecycleService    ✅ spawn, complete, cancel, split
├─ DAGRoutingService        ⚠️ move, route (should delegate)
└─ ParallelMachineCoordinator ⚠️ split, merge (should delegate)
```

**Target Pattern (Single Owner - After refactor):**
```
Token Status Updates:
└─ TokenLifecycleService ONLY ✅
   ├─ spawn, startWork, pauseWork, resumeWork
   ├─ completeNode, completeToken
   ├─ scrapToken, cancelToken
   └─ splitToken, mergeTokens
   
Other Services Call Lifecycle:
├─ DAGRoutingService → calls TokenLifecycleService
└─ ParallelMachineCoordinator → calls TokenLifecycleService
```

---

## 5. Integration Points Summary

### 5.1 Worker Token API (worker_token_api.php)

**Integration Matrix:**

| Action | Session Update | Token Status Update | Routing | Status |
|--------|---------------|---------------------|---------|--------|
| start_token | ✅ Yes (line 242) | ❌ **Missing** | N/A | ⚠️ Partial |
| pause_token | ✅ Yes (line 345) | ❌ **Missing** | N/A | ⚠️ Partial |
| resume_token | ✅ Yes (line 469) | ❌ **Missing** | N/A | ⚠️ Partial |
| complete_token | ✅ Yes (line 582) | ✅ Yes (line 585) | ✅ Yes (line 588) | ✅ Full |

**Fix Plan (Post Task 27.2):**
```php
// After Task 27.2 adds methods, update worker_token_api.php:

function handleStartToken(...) {
    $sessionService->startToken(...);
    $lifecycleService->startWork($tokenId);  // ⭐ ADD
}

function handlePauseToken(...) {
    $sessionService->pauseToken(...);
    $lifecycleService->pauseWork($tokenId);  // ⭐ ADD
}

function handleResumeToken(...) {
    $sessionService->resumeToken(...);
    $lifecycleService->resumeWork($tokenId); // ⭐ ADD
}
```

### 5.2 Behavior Execution Service

**Integration Matrix:**

| Behavior | Start | Pause | Resume | Complete | Status |
|----------|-------|-------|--------|----------|--------|
| STITCH | ❌ Session only | ❌ Session only | ❌ Session only | ❌ Session only | ⚠️ Gaps |
| HARDWARE_ASSEMBLY | ❌ Session only | ❌ Session only | ❌ Session only | ❌ Session only | ⚠️ Gaps |
| SKIVE | ❌ Session only | ❌ Session only | ❌ Session only | ❌ Session only | ⚠️ Gaps |
| GLUE | ❌ Session only | ❌ Session only | ❌ Session only | ❌ Session only | ⚠️ Gaps |
| ASSEMBLY | ❌ Session only | ❌ Session only | ❌ Session only | ❌ Session only | ⚠️ Gaps |
| PACK | ❌ Session only | ❌ Session only | ❌ Session only | ❌ Session only | ⚠️ Gaps |
| EMBOSS | ❌ Session only | ❌ Session only | ❌ Session only | ❌ Session only | ⚠️ Gaps |
| CUT | ⚠️ Batch | N/A | N/A | ⚠️ Batch | ⚠️ Different pattern |
| EDGE | ⚠️ Mixed | N/A | N/A | ⚠️ Mixed | ⚠️ Different pattern |
| QC_* | ⚠️ QC flow | N/A | N/A | ⚠️ QC flow | ⚠️ Different pattern |

**Fix Plan (Task 27.3):**
```php
// After Task 27.2, add to BehaviorExecutionService:

use BGERP\Service\TokenLifecycleService;  // ⭐ ADD IMPORT

private function handleSinglePieceStart(...) {
    $sessionService->startSession(...);
    $this->lifecycleService->startWork($tokenId);  // ⭐ ADD
}

private function handleSinglePiecePause(...) {
    $sessionService->pauseSession(...);
    $this->lifecycleService->pauseWork($tokenId);  // ⭐ ADD
}

private function handleSinglePieceResume(...) {
    $sessionService->resumeSession(...);
    $this->lifecycleService->resumeWork($tokenId); // ⭐ ADD
}

private function handleSinglePieceComplete(...) {
    $sessionService->completeToken(...);
    $this->lifecycleService->completeNode($tokenId, $nodeId); // ⭐ ADD
}
```

---

## 6. Risk Assessment

### 6.1 Current State Risks

| Risk | Severity | Likelihood | Impact | Mitigation Status |
|------|----------|------------|--------|-------------------|
| **Session-Token Status Drift** | 🟡 Medium | High | Token status queries inaccurate | ✅ Task 27.2 will fix |
| **No Single Source of Truth** | 🟡 Medium | High | Hard to track status changes | ✅ Task 27.2 will fix |
| **Multiple Direct UPDATE** | 🟡 Medium | Medium | Hard to enforce business rules | ⚠️ Future refactor |
| **Circular Dependency** | 🟠 Low | Low | Could block if not careful | ✅ Guardrail in Task 27.2 |
| **Breaking Existing Code** | 🟢 Low | Low | Backwards compatibility | ✅ Additive approach in Task 27.2 |

### 6.2 Drift Scenarios

**Scenario 1: Worker starts token, then system queries token status**
```
Timeline:
1. Worker calls worker_token_api.php?action=start_token
2. API updates session: token_work_session.status = 'active' ✅
3. API does NOT update token: flow_token.status = 'ready' ❌
4. Dashboard queries: SELECT status FROM flow_token WHERE id_token = ?
5. Dashboard shows: "ready" (incorrect! Should be "active")
```

**Scenario 2: Worker pauses token, analytics query token status**
```
Timeline:
1. Worker calls worker_token_api.php?action=pause_token
2. API updates session: token_work_session.status = 'paused' ✅
3. API does NOT update token: flow_token.status = 'active' ❌
4. Analytics: SELECT COUNT(*) FROM flow_token WHERE status = 'active'
5. Count includes paused tokens (incorrect!)
```

**Why This Hasn't Caused Production Issues Yet:**
- ✅ No production data yet (dev/test only)
- ✅ Most queries use `token_work_session.status` (accurate)
- ✅ Critical operations (complete/route) DO update token status
- ⚠️ Only status **display** queries affected

### 6.3 Mitigation Strategy

**Immediate (Task 27.2):**
1. ✅ Add lifecycle methods to TokenLifecycleService
2. ✅ Document integration pattern
3. ✅ Write tests for state transitions

**Short-term (Task 27.3):**
1. ⚠️ Update BehaviorExecutionService to call lifecycle methods
2. ⚠️ Update worker_token_api.php to call lifecycle methods

**Long-term (Future Tasks):**
1. 🔮 Refactor DAGRoutingService to delegate status updates
2. 🔮 Refactor ParallelMachineCoordinator to delegate status updates
3. 🔮 Add database trigger to sync session ↔ token status (optional)

---

## 7. Circular Dependency Analysis

### 7.1 Current Dependency Graph

```
BehaviorExecutionService (BGERP\Dag)
    ├─→ TokenWorkSessionService (BGERP\Dag wrapper)
    │    └─→ TokenWorkSessionService (BGERP\Service core)
    └─→ DagExecutionService (BGERP\Dag)
         ├─→ TokenLifecycleService (BGERP\Service) ← EXISTS
         └─→ DAGRoutingService (BGERP\Service)
```

### 7.2 After Task 27.2

```
BehaviorExecutionService (BGERP\Dag)
    ├─→ TokenWorkSessionService (BGERP\Dag wrapper)
    │    └─→ TokenWorkSessionService (BGERP\Service core)
    ├─→ DagExecutionService (BGERP\Dag)
    │    ├─→ TokenLifecycleService (BGERP\Service) ← existing methods
    │    └─→ DAGRoutingService (BGERP\Service)
    └─→ TokenLifecycleService (BGERP\Service) ← NEW methods (Task 27.3)
```

### 7.3 Circular Dependency Risk

**Rule to Prevent Cycle:**
```
TokenLifecycleService MUST NOT call BehaviorExecutionService
```

**Verified:**
- ✅ TokenLifecycleService does NOT import BehaviorExecutionService
- ✅ No circular dependency detected
- ✅ Safe to add lifecycle methods

**Dependency Flow (After Task 27.2):**
```
Behavior → Lifecycle → DagExecution → Routing
   ↓          ↓            ↓              ↓
Session   Token Status   Movement     Next Node

No cycles: ✅ Safe
```

---

## 8. TokenLifecycleService Current State

### 8.1 Existing Methods Audit

**Location:** `source/BGERP/Service/TokenLifecycleService.php` (1560 lines)

**Job-Level Methods (Existing):**
- ✅ `spawnTokens($instanceId, $targetQty, $processMode, $serials)` - Line 45
- ✅ `moveToken($tokenId, $toNodeId, $operatorId)` - Line 338
- ✅ `completeToken($tokenId, $operatorId)` - Line 380
- ✅ `scrapToken($tokenId, $reason, $operatorId)` - Line 571 (DEPRECATED)
- ✅ `cancelToken($tokenId, $cancellationType, $reason, $operatorId)` - Line 587
- ✅ `splitToken($parentTokenId, $splitConfig, $parallelGroupId)` - Line 814
- ✅ Join buffer management - Lines 1390-1471

**Node-Level Methods (Missing - Task 27.2 will add):**
- ❌ `startWork($tokenId)` - NOT FOUND
- ❌ `pauseWork($tokenId)` - NOT FOUND
- ❌ `resumeWork($tokenId)` - NOT FOUND
- ❌ `completeNode($tokenId, $nodeId)` - NOT FOUND

**Helper Methods (Available for reuse):**
- ✅ `fetchToken($tokenId)` - Line 1094
- ✅ `fetchNode($nodeId)` - Line 1102
- ✅ `createEvent($tokenId, $eventType, ...)` - Line 988
- ✅ `generateUUID()` - Line 1365

### 8.2 Tight Coupling Analysis

**Current Tight Coupling (God Object Pattern):**

```php
class TokenLifecycleService {
    // Pure lifecycle: ✅
    + spawnTokens()
    + moveToken()
    + completeToken()
    + cancelToken()
    + splitToken()
    
    // Should be separate: ⚠️
    - resolveAndAssignToken()        → AssignmentEngine
    - MOEtaHealthService hook        → Event listener
    - TimeEventReader sync           → Event listener
    - NodeBehaviorEngine execution   → Separate concern
}
```

**Dependencies Count:**
- `AssignmentResolverService` (Line 14, 1253)
- `TimeEventReader` (Line 18, 460)
- `NodeBehaviorEngine` (Line 16, 438)
- `MOEtaHealthService` (Line 530)
- `TokenEventService` (Line 17, 445)

**Total:** 5 external dependencies (too many for lifecycle service)

**Task 27.2 Approach:** 
- ✅ Add methods WITHOUT adding more dependencies
- ✅ Use existing helpers only
- ⚠️ Future: Extract assignment/ETA/time sync (separate phase)

---

## 9. Backwards Compatibility Assessment

### 9.1 Existing Code That Uses TokenLifecycleService

**Found in:**
1. `BGERP/Dag/DagExecutionService.php` - Line 28-29, 44
2. `source/hatthasilpa_jobs_api.php` - Job creation
3. `source/dag_token_api.php` - Token operations
4. `source/worker_token_api.php` - Line 75

**Usage Pattern:**
```php
use BGERP\Service\TokenLifecycleService;

$lifecycleService = new TokenLifecycleService($tenantDb);
$lifecycleService->spawnTokens(...);
$lifecycleService->completeToken(...);
```

**Impact of Adding Methods:**
- ✅ **Zero impact** - Adding methods doesn't break existing calls
- ✅ Existing tests should still pass
- ✅ No namespace changes needed

### 9.2 Risk Level: 🟢 LOW

**Reasons:**
1. ✅ Additive only (no modifications to existing methods)
2. ✅ Same namespace (no import changes needed)
3. ✅ No breaking changes to method signatures
4. ✅ Existing code doesn't call missing methods (obviously)

---

## 10. Recommendations

### 10.1 Immediate Actions (Task 27.2)

**Priority 1: Add Node-Level Methods** ✅ PROCEED

1. ✅ Add `startWork($tokenId)` - ready → active + emit NODE_START
2. ✅ Add `pauseWork($tokenId)` - active → paused + emit NODE_PAUSE
3. ✅ Add `resumeWork($tokenId)` - paused → active + emit NODE_RESUME
4. ✅ Add `completeNode($tokenId, $nodeId)` - routing by node type + emit NODE_COMPLETE
5. ⚠️ Refactor `scrapToken($tokenId, $reason)` - simple wrapper or delegate to cancelToken

**Guardrails:**
- ✅ DO NOT modify existing methods
- ✅ DO NOT add new dependencies
- ✅ Use existing helpers (fetchToken, createEvent, etc.)
- ✅ Emit canonical events via TokenEventService
- ❌ DO NOT call BehaviorExecutionService (prevent cycle)

**Test Coverage:**
- ✅ Write 10 unit tests for new methods
- ✅ Verify all existing tests still pass
- ✅ Test state machine validation (invalid transitions throw exceptions)

### 10.2 Follow-Up Actions (Task 27.3)

**Priority 2: Integrate Lifecycle Calls** ⚠️ FOLLOW-UP

**Update BehaviorExecutionService:**
```php
// Import lifecycle service
use BGERP\Service\TokenLifecycleService;

// Add to constructor
private TokenLifecycleService $lifecycleService;

// Update handlers
private function handleSinglePieceStart(...) {
    $this->sessionService->startSession(...);
    $this->lifecycleService->startWork($tokenId);  // ⭐ ADD
}
```

**Update worker_token_api.php:**
```php
function handleStartToken(...) {
    $sessionService->startToken(...);
    $lifecycleService->startWork($tokenId);  // ⭐ ADD
}
```

### 10.3 Long-Term Actions (Future)

**Priority 3: Extract Concerns** 🔮 FUTURE

1. Extract `resolveAndAssignToken()` → AssignmentEngine
2. Extract ETA hook → Event listener pattern
3. Extract time sync → Event listener pattern
4. Refactor DAGRoutingService to delegate status updates
5. Refactor ParallelMachineCoordinator to delegate status updates

---

## 11. Conclusion

### 11.1 Audit Verdict

**Status:** ✅ **SAFE TO PROCEED** with Task 27.2

**Findings:**
- ✅ No blockers found
- ⚠️ Integration gaps identified (session-token drift)
- ✅ Clear fix path documented
- ✅ No circular dependency risks
- ✅ Backwards compatibility guaranteed

### 11.2 Critical Success Factors

**For Task 27.2 to succeed:**
1. ✅ Add methods WITHOUT touching existing code
2. ✅ Follow strict state machine validation
3. ✅ Emit canonical events consistently
4. ✅ Use existing helpers (don't duplicate)
5. ✅ Write comprehensive tests
6. ✅ Verify backwards compatibility

### 11.3 Integration Roadmap

```
Phase 1 (Task 27.2) - Add Methods
├─ Extend TokenLifecycleService
├─ Add startWork/pauseWork/resumeWork/completeNode
└─ Write tests (10 cases)

Phase 2 (Task 27.3) - Integrate Behavior Layer
├─ Update BehaviorExecutionService
├─ Add lifecycle calls to all behaviors
└─ Test integration

Phase 3 (Future) - Update Worker API
├─ Update worker_token_api.php
├─ Add lifecycle calls to all actions
└─ Test end-to-end

Phase 4 (Future) - Refactor Status Ownership
├─ Extract assignment logic
├─ Extract ETA/time sync hooks
└─ Refactor DAGRoutingService/ParallelMachineCoordinator
```

---

## 12. Appendix: Code Snippets

### A. Session-Only Pattern (Current - Incomplete)

```php
// worker_token_api.php - Line 242-248
function handleStartToken(...) {
    // ✅ Session updated
    $result = $sessionService->startToken($tokenId, $employeeId, $operatorName, 'own', '');
    
    // ❌ Token status NOT updated
    // flow_token.status remains 'ready' (should be 'active')
}
```

### B. Session+Lifecycle Pattern (Target - Complete)

```php
// After Task 27.2 + 27.3
function handleStartToken(...) {
    // ✅ Session updated
    $result = $sessionService->startToken($tokenId, $employeeId, $operatorName, 'own', '');
    
    // ✅ Token status updated
    $lifecycleService->startWork($tokenId);  // ready → active + emit NODE_START
}
```

### C. Complete Pattern (Already Correct)

```php
// worker_token_api.php - Line 582-588
function handleCompleteToken(...) {
    // ✅ Session updated
    $sessionResult = $sessionService->completeToken($tokenId, $employeeId);
    
    // ✅ Token status updated
    $lifecycleService->completeToken($tokenId, $employeeId);
    
    // ✅ Routing handled
    $routingResult = $routingService->routeToken($tokenId, $employeeId);
}
```

---

## 13. Action Items

### For Task 27.2 Implementation:

- [ ] Extend `BGERP\Service\TokenLifecycleService` class
- [ ] Add `startWork($tokenId): void` method
  - [ ] Validate status = 'ready' ONLY (strict)
  - [ ] UPDATE status to 'active'
  - [ ] Emit NODE_START canonical event
- [ ] Add `pauseWork($tokenId): void` method
  - [ ] Validate status = 'active'
  - [ ] UPDATE status to 'paused'
  - [ ] Emit NODE_PAUSE canonical event
- [ ] Add `resumeWork($tokenId): void` method
  - [ ] Validate status = 'paused'
  - [ ] UPDATE status to 'active'
  - [ ] Emit NODE_RESUME canonical event
- [ ] Add `completeNode($tokenId, $nodeId): array` method
  - [ ] Check node type (end vs normal)
  - [ ] If end: delegate to existing completeToken()
  - [ ] If normal: call DagExecutionService->moveToNextNode()
  - [ ] Emit NODE_COMPLETE canonical event
- [ ] Handle `scrapToken($tokenId, $reason)` method
  - [ ] Choose implementation option (A/B/C)
  - [ ] Ensure any → scrapped transition
  - [ ] Emit NODE_CANCEL event
- [ ] Write 10 unit tests
- [ ] Verify backwards compatibility
- [ ] Document in task results

### For Task 27.3 (Follow-up):

- [ ] Import TokenLifecycleService in BehaviorExecutionService
- [ ] Add lifecycle calls to all behavior handlers
- [ ] Test all behaviors (STITCH, HARDWARE_ASSEMBLY, SKIVE, etc.)
- [ ] Verify session-token status sync

### For Future Refactor:

- [ ] Extract assignment logic from TokenLifecycleService
- [ ] Extract ETA/time sync hooks
- [ ] Refactor DAGRoutingService to delegate status updates
- [ ] Refactor ParallelMachineCoordinator to delegate status updates

---

## 14. References

**Related Tasks:**
- `docs/super_dag/tasks/task27.2.md` - Extend TokenLifecycleService (this audit supports)
- `docs/super_dag/tasks/task27.3.md` - Refactor BehaviorExecutionService (next step)
- `docs/super_dag/tasks/task20.3.md` - Worker Token API implementation

**Related Specs:**
- `docs/super_dag/02-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - Token state machine
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Behavior integration
- `docs/developer/SYSTEM_WIRING_GUIDE.md` - System bloodlines

**Related Code:**
- `source/worker_token_api.php` - Work Queue API
- `source/BGERP/Dag/BehaviorExecutionService.php` - Behavior handlers
- `source/BGERP/Service/TokenLifecycleService.php` - Target file for Task 27.2

---

**Audit Complete** ✅  
**Date:** December 2, 2025  
**Status:** Safe to proceed with Task 27.2  
**Next Step:** Implement node-level lifecycle methods

