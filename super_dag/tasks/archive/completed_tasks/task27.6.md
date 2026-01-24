# Task 27.6 — Add Component Hooks in Behavior (No Parallel Yet)

**Phase:** 2 - Component Flow Integration  
**Priority:** 🔴 BLOCKER  
**Estimated Effort:** 4-6 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 2 - Component Flow Integration  
**Dependencies:** Task 27.5 (ComponentFlowService exists) ✅ **COMPLETE**  
**Blocks:** Task 27.7 (Parallel split/merge)

---

## 🚨 **CRITICAL: Namespace Reference**

**⚠️ ComponentFlowService Location:**
```
✅ CORRECT: source/BGERP/Service/ComponentFlowService.php
✅ Namespace: BGERP\Service

❌ WRONG: source/BGERP/Dag/ComponentFlowService.php (old spec)
```

**Import Statement:**
```php
use BGERP\Service\ComponentFlowService;  // ⚠️ BGERP\Service NOT BGERP\Dag
```

---

## ⚠️ **Context from Phase 1 + Task 27.5**

**Phase 1 Complete (Task 27.2-27.4):**
- ✅ TokenLifecycleService (BGERP\Service) - 5 methods
- ✅ BehaviorExecutionService refactored - 13 lifecycle calls
- ✅ Validation matrix - 13 behaviors × 3 token types

**Task 27.5 Complete:**
- ✅ ComponentFlowService created (BGERP\Service)
- ✅ 4 stub methods: onComponentCompleted, isReadyForAssembly, getSiblingStatus, aggregateComponentTimes
- ✅ 7/7 tests passed
- ✅ Graceful failures, NULL-safe metadata

**BehaviorExecutionService Current Structure (from Task 27.3):**
- ✅ Has lifecycle dependency (lazy init via getLifecycleService())
- ✅ Has session dependency (lazy init via getSessionService())
- ✅ 9 handlers already refactored with lifecycle calls
- ✅ Pattern: lifecycle → session → log

**Integration Strategy:**
- Add ComponentFlowService dependency (lazy init - same pattern)
- Add component hooks in complete handlers (if token_type = component)
- Add assembly validation hook (isReadyForAssembly stub)

---

## 🎯 Goal

ให้ `BehaviorExecutionService` aware ว่า token เป็น component แล้วเรียก hook ที่ถูกต้อง

**Key Principle:**
- ✅ Behavior ตรวจว่า `token_type = 'component'`
- ✅ Behavior เรียก `ComponentFlowService` hooks
- ❌ Behavior ไม่ทำ component logic เอง
- ✅ Use BGERP\Service\ComponentFlowService (from Task 27.5)

**⚠️ PHASE 2 SCOPE:** Hook structure only (hooks เรียกได้ แต่ยัง return stub)

---

## 📋 Requirements

### 1. Add ComponentFlowService Dependency

**Import Statement (add to top of file):**
```php
use BGERP\Service\TokenLifecycleService;
use BGERP\Service\ComponentFlowService;  // ⚠️ NEW - BGERP\Service namespace
```

**Property Declaration:**
```php
class BehaviorExecutionService {
    private ?TokenLifecycleService $lifecycleService;
    private ?DagTokenWorkSessionService $sessionService;
    private ?DagExecutionService $dagExecutionService;
    private ?ComponentFlowService $componentService;  // ⚠️ NEW
```

**Constructor (use lazy init pattern like Task 27.3):**
```php
    public function __construct(mysqli $db, array $org, ?int $workerId = null) {
        $this->db = $db;
        $this->org = $org;
        $this->workerId = $workerId;
        
    $this->lifecycleService = null;  // Lazy init
    $this->sessionService = null;    // Lazy init
    $this->dagExecutionService = null;  // Lazy init
    $this->componentService = null;  // ⚠️ NEW - Lazy init
}
```

**Getter Method (add after getLifecycleService()):**
```php
/**
 * Get or create component flow service instance
 * 
 * Task 27.6: Added for component flow integration
 * 
 * @return ComponentFlowService
 */
private function getComponentService(): ComponentFlowService
{
    if ($this->componentService === null) {
        $this->componentService = new ComponentFlowService($this->db);
    }
    return $this->componentService;
}
```

### 2. Add Hook 1: onComponentCompleted (After Complete)

**Pattern (applies to all component-compatible behaviors):**

**Order: session → component hook → lifecycle → log**

```php
function handleStitchComplete($tokenId, $nodeId) {
    $token = $this->fetchToken($tokenId);
    
    // 1. Complete session FIRST
    $coreSessionService = new \BGERP\Service\TokenWorkSessionService($this->db);
    $completeResult = $coreSessionService->completeToken($tokenId, $this->workerId);
    
    $sessionService = $this->getSessionService();
    $sessionSummary = $sessionService->getSessionSummary($activeSession['id_session']);
    
    // 2. Component hook (if component token) - AFTER session, BEFORE lifecycle
    if ($token['token_type'] === 'component') {
        try {
            $componentService = $this->getComponentService();
            
            // Parse metadata JSON (NULL-safe)
            $metadata = null;
            if (!empty($token['metadata'])) {
                $metadata = json_decode($token['metadata'], true);
            }
            
            $componentService->onComponentCompleted($tokenId, [
                'component_code' => $metadata['component_code'] ?? $token['component_code'] ?? null,
                'duration_ms' => $sessionSummary['total_work_ms'] ?? 0,
            'worker_id' => $this->workerId,
            'worker_name' => $this->getWorkerName(),
            'node_id' => $nodeId
        ]);
        } catch (\Exception $e) {
            // Graceful: Log error but don't break behavior flow
            error_log('[BehaviorExecutionService] Component hook failed: ' . $e->getMessage());
        }
    }
    
    // 3. Call lifecycle (handles routing)
    $lifecycleService = $this->getLifecycleService();
    $result = $lifecycleService->completeNode($tokenId, $nodeId);
    
    // 4. Log behavior
    $this->logBehaviorAction($tokenId, $nodeId, 'STITCH', 'stitch_complete', ...);
    
    return ['ok' => true, 'effect' => 'stitch_completed', 'routing' => $result];
}
```

**⚠️ IMPORTANT: metadata JSON parsing**
```php
// ❌ WRONG: $token['metadata']->component_code (metadata is JSON string!)
// ✅ CORRECT: json_decode($token['metadata'], true)['component_code']

$metadata = !empty($token['metadata']) ? json_decode($token['metadata'], true) : [];
$componentCode = $metadata['component_code'] ?? null;  // Only from metadata!

// Note: flow_token does NOT have component_code column
// component_code stored in metadata JSON only
```

**Apply to:**
- handleStitchComplete()
- handleEdgeComplete()
- handleQcPass() (in handleQc)
- handleSinglePieceComplete() (GLUE, SKIVE, EMBOSS, etc.)

**⚠️ NOT for:**
- CUT (batch only)
- ASSEMBLY (piece only)
- PACK (piece only)

### 3. Add Hook 2: isReadyForAssembly (Before Assembly Start)

**In handleAssemblyStart() or handleSinglePieceStart() for ASSEMBLY:**

```php
function handleAssemblyStart($tokenId, $nodeId) {
    $token = $this->fetchToken($tokenId);
    
    // 1. Validate token type
    if ($token['token_type'] !== 'piece') {
        return ['ok' => false, 'error' => 'ASSEMBLY requires piece token'];
    }
    
    // 2. Component hook (validate components ready)
    $validation = $this->componentService->isReadyForAssembly($tokenId);
    if (!$validation['ready']) {
        return [
            'ok' => false,
            'error' => 'COMPONENTS_NOT_READY',
            'app_code' => 'BEHAVIOR_409_COMPONENTS_NOT_READY',
            'message' => 'ยังไม่ครบทุก component',
            'missing' => $validation['missing']
        ];
    }
    
    // 3. Call lifecycle
    $this->lifecycleService->startWork($tokenId);
    
    // 4. Create session
    $sessionResult = $this->sessionService->startToken($tokenId, $this->workerId, ...);
    
    return ['ok' => true, 'effect' => 'assembly_started'];
}
```

### 4. Add Helper Method: getWorkerName()

**Phase 2: Use session data (simple approach)**

```php
/**
 * Get worker name from session or worker ID
 * 
 * Task 27.6: Helper for component metadata
 * Phase 2: Use session data (simple)
 * Phase 3+: Could query database if needed
 * 
 * @return string Worker name
 */
private function getWorkerName(): string
{
    // Try session first (already loaded)
    if (isset($_SESSION['member']['name'])) {
        return $_SESSION['member']['name'];
    }
    
    // Fallback to worker ID
    if ($this->workerId) {
        return "Worker #{$this->workerId}";
    }
    
    return 'Unknown';
}
```

**Rationale:**
- ✅ Phase 2 = simple approach (session data)
- ✅ No extra database queries
- ✅ Session already has member data
- 📝 Phase 3+: Can enhance if needed

---

## 🚧 Guardrails (MUST FOLLOW)

### Guardrail 1: Hook Placement
- ✅ onComponentCompleted: AFTER session complete, BEFORE lifecycle complete
- ✅ isReadyForAssembly: BEFORE lifecycle start, AFTER token type validation
- ❌ NO calling hooks if token_type wrong
- ✅ Check `token_type === 'component'` before calling hooks

### Guardrail 2: Fail Gracefully
- ✅ If component_code missing → log warning, continue
- ✅ If ComponentFlowService fails → log error, continue behavior execution
- ❌ NO breaking behavior flow due to component hook failures
- ✅ Wrap component service calls in try-catch

```php
try {
    $this->componentService->onComponentCompleted($tokenId, $context);
} catch (Exception $e) {
    error_log("[BehaviorExecution] Component hook failed: " . $e->getMessage());
    // Continue execution (don't break behavior)
}
```

### Guardrail 3: Phase 2 Limitations
- ✅ Hooks เรียกได้ แต่ยังไม่ทำงานเต็มรูป (stub)
- ❌ NO expecting component validation to actually work
- ❌ NO expecting sibling status to return real data
- ✅ Focus: โครงสร้างถูก, เรียกใช้ได้ไม่ error

### Guardrail 4: Scope Limitation
- ✅ Modify ONLY `BehaviorExecutionService.php`
- ❌ NO touching ComponentFlowService (Task 27.5 created it)
- ❌ NO touching TokenLifecycleService
- ❌ NO UI changes
- ❌ NO database changes

### Guardrail 5: Backward Compatibility
- ✅ Existing flows (piece tokens) ต้องทำงานได้เหมือนเดิม
- ✅ Component hooks เพิ่มเข้ามา ไม่กระทบ piece tokens
- ❌ NO breaking existing behavior calls

---

## 🧪 Testing Requirements

### Manual Testing

**Test Scenario 1: Piece Token (No Component)**
1. Execute STITCH on piece token
2. Complete work
3. Should work normally (hook not called)
4. Check: No errors, flow completes ✅

**Test Scenario 2: Component Token (With Component Code)**
1. Create component token (set metadata: `{"component_code": "BODY"}`)
2. Execute STITCH on component token
3. Complete work
4. Check: `onComponentCompleted()` called (see error_log)
5. Check: metadata updated with `component_completed_at`, `component_time_ms` ✅

**Test Scenario 3: Assembly Start (Stub Validation)**
1. Execute ASSEMBLY start on piece token
2. Check: `isReadyForAssembly()` called (see error_log)
3. Should allow start (stub returns ready=true) ✅

**Test Scenario 4: Error Resilience**
1. Component token missing component_code
2. Execute STITCH complete
3. Should complete successfully (hook logs warning, doesn't break) ✅

### Check Error Log

```bash
tail -f /Applications/MAMP/logs/php_error.log | grep ComponentFlowService
```

**Should see:**
```
[ComponentFlowService] Component 123 completed: BODY
[ComponentFlowService] isReadyForAssembly stub called for token 100
```

---

## 📦 Deliverables

### 1. Modified Files

- ✅ `source/BGERP/Dag/BehaviorExecutionService.php`
  - Add `ComponentFlowService` dependency (~5 lines)
  - Add `onComponentCompleted` hook in 4 handlers (~40 lines)
  - Add `isReadyForAssembly` hook in assembly start (~20 lines)
  - Add `getWorkerName()` helper (~20 lines)
  - Total: ~85 lines added/modified

### 2. Test Evidence

- ✅ Manual test checklist completed (4 scenarios)
- ✅ Error log shows hook calls
- ✅ No exceptions/errors
- ✅ Metadata updated correctly

### 3. Results Document

- ✅ `docs/super_dag/tasks/results/task27.6_results.md`

---

## ✅ Definition of Done

- [ ] ComponentFlowService dependency added
- [ ] onComponentCompleted hook in 4 handlers
- [ ] isReadyForAssembly hook in assembly start
- [ ] getWorkerName() helper implemented
- [ ] Manual testing pass (4 scenarios)
- [ ] Error log shows hook activity
- [ ] No regressions (piece tokens work normally)
- [ ] Component token metadata updated
- [ ] Results document created

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO implementing full component validation (Phase 3)
- ❌ NO parallel_group_id queries
- ❌ NO split/merge implementation
- ❌ NO UI changes
- ❌ NO database changes
- ❌ NO creating ComponentFlowService methods (Task 27.5 did it)
- ❌ NO modifying TokenLifecycleService
- ❌ NO touching Work Queue files

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 6.2 (Hook patterns)

**Code:**
- `source/BGERP/Dag/BehaviorExecutionService.php` - File to modify
- `source/BGERP/Service/ComponentFlowService.php` - Service to call (from Task 27.5) ⚠️ **BGERP\Service**

**Related Tasks:**
- Task 27.3: BehaviorExecutionService refactored (lifecycle integration)
- Task 27.4: Validation matrix (behavior-token type)
- Task 27.5: ComponentFlowService created (stub methods)

---

## 📝 Implementation Notes

**0. Database Schema (CRITICAL):**
```
✅ flow_token.token_type: enum('batch','piece','component')
✅ flow_token.metadata: JSON
❌ flow_token.component_code: DOES NOT EXIST

⚠️ component_code stored in metadata JSON ONLY:
{
  "component_code": "BODY",
  "component_completed_at": "2025-12-02 20:00:00",
  "component_time_ms": 5000,
  ...
}
```

**1. Lazy Init Pattern (from Task 27.3):**
```php
// ✅ Use lazy init (like lifecycleService)
private ?ComponentFlowService $componentService;  // Property
private function getComponentService() { ... }    // Getter

// ❌ NOT eager init in constructor
```

**2. metadata JSON Parsing:**
```php
// ✅ CORRECT: Parse JSON first
$metadata = !empty($token['metadata']) ? json_decode($token['metadata'], true) : [];
$componentCode = $metadata['component_code'] ?? null;  // Only from metadata

// ❌ WRONG: Direct property access
$token['metadata']->component_code  // metadata is JSON string!

// ❌ WRONG: Column doesn't exist
$token['component_code']  // No such column in flow_token!
```

**3. Handlers to Update (4 handlers):**
```
✅ handleSinglePieceComplete (STITCH, EDGE, GLUE, SKIVE, EMBOSS variants)
✅ handleStitch (stitch_complete)
✅ handleEdge (edge_complete)
✅ handleQc (qc_pass)

❌ NOT handleCut (batch only - no component support)
❌ NOT handleAssembly complete (piece only final - not component)
```

**4. Assembly Start Validation:**
```php
// Only for ASSEMBLY behavior start
// Check isReadyForAssembly() BEFORE startWork()
```

---

**END OF TASK**
