# Task 27.3 — Refactor BehaviorExecutionService to Call Lifecycle Only

**Phase:** 1 - Core Token Lifecycle + Behavior Wiring  
**Priority:** 🔴 BLOCKER  
**Estimated Effort:** 8-10 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 1 - Token Lifecycle Integration  
**Dependencies:** Task 27.2 (TokenLifecycleService extended with node-level methods) ✅ **COMPLETE**  
**Blocks:** Task 27.4 (Behavior-Token Type Validation)

---

## ⚠️ **Context from Task 27.2 (COMPLETED)**

**TokenLifecycleService Location:** `source/BGERP/Service/TokenLifecycleService.php`  
**Namespace:** `BGERP\Service` (NOT BGERP\Dag - see Task 27.2 rationale)

**New Methods Available:**
- ✅ `startWork(int $tokenId): void` - ready → active
- ✅ `pauseWork(int $tokenId): void` - active → paused
- ✅ `resumeWork(int $tokenId): void` - paused → active
- ✅ `completeNode(int $tokenId, int $nodeId): array` - complete + routing
- ✅ `scrapTokenSimple(int $tokenId, string $reason): void` - any → scrapped

**Integration Audit:** `docs/super_dag/00-audit/20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md`
- Identified 5 integration gaps in BehaviorExecutionService
- All gaps will be fixed in this task

---

## 🎯 Goal

Refactor `BehaviorExecutionService` ให้เรียก `TokenLifecycleService` แทนการแตะ `flow_token.status` ตรง ๆ

**Key Principle:**
- ✅ Behavior = Orchestrator (call services)
- ❌ Behavior ห้ามเป็น owner ของ token status
- ✅ Use `BGERP\Service\TokenLifecycleService` (from Task 27.2)

---

## 📋 Requirements

### 1. Refactor All Behavior Handlers

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

**Handlers to Update:**
1. `handleStitch()` - STITCH behavior
2. `handleCut()` - CUT behavior  
3. `handleEdge()` - EDGE behavior
4. `handleQc()` - QC_SINGLE, QC_FINAL, QC_REPAIR, QC_INITIAL
5. `handleSinglePiece()` - HARDWARE_ASSEMBLY, SKIVE, GLUE, ASSEMBLY, PACK, EMBOSS

### 2. Update Pattern for All *_start Actions

**Before (Current):**
```php
function handleStitchStart($tokenId, $nodeId) {
    // ❌ No lifecycle call
    $sessionResult = $this->sessionService->startToken($tokenId, ...);
    return ['ok' => true, 'session_id' => $sessionResult['session_id']];
}
```

**After (Target):**
```php
function handleStitchStart($tokenId, $nodeId) {
    // 1. Call lifecycle FIRST
    $this->lifecycleService->startWork($tokenId);
    
    // 2. Then create session
    $sessionResult = $this->sessionService->startToken($tokenId, ...);
    
    // 3. Log behavior
    $this->logBehaviorAction($tokenId, $nodeId, 'STITCH', 'stitch_start', ...);
    
    return ['ok' => true, 'effect' => 'stitch_started', 'session_id' => $sessionResult['session_id']];
}
```

### 3. Update Pattern for All *_pause Actions

**After (Target):**
```php
function handleStitchPause($tokenId, $nodeId) {
    // 1. Call lifecycle FIRST
    $this->lifecycleService->pauseWork($tokenId);
    
    // 2. Then pause session
    $sessionResult = $this->sessionService->pauseToken($tokenId, ...);
    
    return ['ok' => true, 'effect' => 'stitch_paused'];
}
```

### 4. Update Pattern for All *_resume Actions

**After (Target):**
```php
function handleStitchResume($tokenId, $nodeId) {
    // 1. Call lifecycle FIRST
    $this->lifecycleService->resumeWork($tokenId);
    
    // 2. Then resume session
    $sessionResult = $this->sessionService->resumeToken($tokenId, ...);
    
    return ['ok' => true, 'effect' => 'stitch_resumed'];
}
```

### 5. Update Pattern for All *_complete Actions

**Before (Current):**
```php
function handleStitchComplete($tokenId, $nodeId) {
    // Complete session
    $this->sessionService->completeToken($tokenId, ...);
    
    // Route to next node (DagExecutionService)
    $routingResult = $this->dagExecutionService->moveToNextNode($tokenId);
    
    return ['ok' => true, 'routing' => $routingResult];
}
```

**After (Target):**
```php
function handleStitchComplete($tokenId, $nodeId) {
    // 1. Complete session FIRST
    $this->sessionService->completeToken($tokenId, $this->workerId);
    
    // 2. Call lifecycle (handles routing internally)
    $result = $this->lifecycleService->completeNode($tokenId, $nodeId);
    
    // 3. Log behavior
    $this->logBehaviorAction($tokenId, $nodeId, 'STITCH', 'stitch_complete', ...);
    
    return ['ok' => true, 'effect' => 'stitch_completed', 'routing' => $result];
}
```

### 6. Add TokenLifecycleService Dependency

**Import Statement:**
```php
use BGERP\Service\TokenLifecycleService;  // ⚠️ IMPORTANT: BGERP\Service NOT BGERP\Dag
```

**In BehaviorExecutionService constructor:**

```php
class BehaviorExecutionService {
    private TokenLifecycleService $lifecycleService;
    private TokenWorkSessionService $sessionService;
    private DagExecutionService $dagExecutionService;
    
    public function __construct(mysqli $db, array $org, ?int $workerId = null) {
        $this->db = $db;
        $this->org = $org;
        $this->workerId = $workerId;
        
        // Add lifecycle service (Task 27.2)
        $this->lifecycleService = new TokenLifecycleService($db);  // BGERP\Service namespace
        $this->sessionService = null; // Lazy init
        $this->dagExecutionService = null; // Lazy init
    }
}
```

---

## 🚧 Guardrails (MUST FOLLOW)

### Guardrail 1: No Direct Status Updates
- ✅ Remove ALL `UPDATE flow_token SET status = ...` from BehaviorExecutionService
- ✅ Replace with `$this->lifecycleService->startWork/pauseWork/resumeWork/completeNode()`
- ❌ NO exceptions (ทุก status change ต้องผ่าน lifecycle)

### Guardrail 2: Order of Operations
- ✅ Lifecycle BEFORE session (for start/pause/resume)
- ✅ Session BEFORE lifecycle (for complete)
- ✅ Log AFTER both (logging is last step)

**Example:**
```php
// Start: lifecycle → session → log
$this->lifecycleService->startWork($tokenId);
$this->sessionService->startToken($tokenId, ...);
$this->logBehaviorAction(...);

// Complete: session → lifecycle → log
$this->sessionService->completeToken($tokenId, ...);
$this->lifecycleService->completeNode($tokenId, $nodeId);
$this->logBehaviorAction(...);
```

### Guardrail 3: Error Handling
- ✅ Wrap lifecycle calls in try-catch
- ✅ Return proper error response if lifecycle fails
- ❌ NO silent failures
- ✅ Log errors before returning

```php
try {
    $this->lifecycleService->startWork($tokenId);
} catch (Exception $e) {
    error_log("[BehaviorExecution] Lifecycle error: " . $e->getMessage());
    return [
        'ok' => false,
        'error' => 'LIFECYCLE_TRANSITION_FAILED',
        'message' => $e->getMessage()
    ];
}
```

### Guardrail 4: Backward Compatibility
- ✅ API responses ต้องเหมือนเดิม (same structure)
- ✅ Frontend ไม่ต้องแก้ (behavior API contract unchanged)
- ❌ NO breaking changes to response format

### Guardrail 5: Scope Limitation
- ✅ Update: handleStitch, handleCut, handleEdge, handleQc, handleSinglePiece
- ❌ NO touching other files (DagExecutionService, TokenWorkSessionService, etc.)
- ❌ NO UI changes
- ❌ NO database changes
- ❌ NO new migrations

---

## 🧪 Testing Requirements

### Manual Testing Checklist

**Test Scenario 1: STITCH Linear Flow**
1. Start STITCH → check `flow_token.status = 'active'`
2. Pause → check `status = 'paused'`
3. Resume → check `status = 'active'`
4. Complete → check routing works, status updated correctly

**Test Scenario 2: CUT Batch Flow**
1. Start CUT batch → status = 'active'
2. Complete with quantity → status updated, moved to next node

**Test Scenario 3: QC Flow**
1. Start QC → status = 'active'
2. QC Pass → complete node, route to next

**Test Scenario 4: End Node**
1. Complete at end node → status = 'completed', `completed_at` set

**Test Scenario 5: Error Cases**
1. Try start token already active → should error
2. Try pause token not active → should error
3. Try resume token not paused → should error

### Integration Test

**File:** `tests/Integration/BehaviorLifecycleIntegrationTest.php` (optional)

**Test:** End-to-end flow with lifecycle + session + routing

---

## 📦 Deliverables

### 1. Modified Files

- ✅ `source/BGERP/Dag/BehaviorExecutionService.php`
  - All handlers updated (5 handlers × 4 actions = ~20 updates)
  - Add `TokenLifecycleService` dependency
  - Remove direct status updates
  - ~50-80 lines changed

### 2. Test Evidence

- ✅ Manual test checklist completed (5 scenarios)
- ✅ No regressions (existing behaviors still work)
- ✅ No errors in browser console (F12)
- ✅ No PHP errors in error log

### 3. Results Document

- ✅ `docs/super_dag/tasks/results/task27.3_results.md`
  - Files modified list
  - Test results
  - Issues encountered (if any)
  - Screenshots (optional)

---

## ✅ Definition of Done

- [ ] All behavior handlers call `lifecycleService` for status changes
- [ ] No direct `UPDATE flow_token.status` in BehaviorExecutionService
- [ ] Order of operations correct (lifecycle → session or session → lifecycle)
- [ ] Error handling in place (try-catch around lifecycle calls)
- [ ] Manual testing pass (5 scenarios)
- [ ] API responses unchanged (backward compatible)
- [ ] No regressions (existing flows work)
- [ ] Results document created

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO implementing split/merge (Phase 3 - Task 27.8)
- ❌ NO implementing component hooks (Phase 2 - Task 27.6)
- ❌ NO implementing validation matrix (Task 27.4)
- ❌ NO implementing failure recovery (Phase 4 - Task 27.9-27.10)
- ❌ NO UI changes
- ❌ NO database schema changes
- ❌ NO new services (only use TokenLifecycleService from Task 27.2)
- ❌ NO touching Work Queue UI files
- ❌ NO creating new .md documentation files

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 4, 5 (Implementation patterns)
- `docs/super_dag/02-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - Section 1 (State transitions)

**Current Code:**
- `source/BGERP/Dag/BehaviorExecutionService.php` - File to modify
- `source/BGERP/Service/TokenLifecycleService.php` - **Service to call** (extended in Task 27.2)

**⚠️ CRITICAL:**
- Import from `BGERP\Service\TokenLifecycleService` (NOT BGERP\Dag)
- Use methods: startWork, pauseWork, resumeWork, completeNode, scrapTokenSimple

**Task 27.2 Results:**
- `docs/super_dag/tasks/results/task27.2_results.md` - Implementation details
- All 5 methods tested and working (10/10 tests passed)

---

**END OF TASK**

