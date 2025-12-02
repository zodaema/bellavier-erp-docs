# Task 27.2 — Extend TokenLifecycleService for Node-Level Lifecycle (Phase 1)

**Phase:** 1 - Core Token Lifecycle + Behavior Wiring  
**Priority:** 🔴 BLOCKER  
**Estimated Effort:** 6-8 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 1 - Token Lifecycle Integration  
**Dependencies:** None (first task in phase)  
**Blocks:** Task 27.3 (Refactor BehaviorExecutionService)

---

## 📌 Quick Summary (TL;DR)

**What:** Extend existing `BGERP\Service\TokenLifecycleService` with 5 node-level methods

**Why:** Class already exists but missing node-level lifecycle methods (start/pause/resume/completeNode)

**How:** Add new methods WITHOUT touching existing spawn/move/complete/split logic

**Key Decision:** 
- ❌ NOT creating new class in `BGERP\Dag\` (avoid namespace confusion)
- ✅ Extending existing class in `BGERP\Service\` (one canonical lifecycle service)

**Methods to Add:**
1. `startWork($tokenId)` - ready → active (first time start)
2. `pauseWork($tokenId)` - active → paused
3. `resumeWork($tokenId)` - paused → active (resume after pause)
4. `completeNode($tokenId, $nodeId)` - complete node + routing
5. `scrapToken($tokenId, $reason)` - any → scrapped (refactor existing if needed)

---

## 🔍 Existing Class Mapping & Current State

**⚠️ CRITICAL FINDING:** TokenLifecycleService already exists!

**Current Location:** `source/BGERP/Service/TokenLifecycleService.php` (✅ 1560 lines)

**Current Namespace:** `BGERP\Service`

**Current Methods (Existing):**
- ✅ `spawnTokens()` - Job creation spawn (batch/piece mode)
- ✅ `moveToken()` - Move token to next node
- ✅ `completeToken()` - Complete token (reached end node)
- ✅ `cancelToken()` - Cancel token (3 types: qc_fail, redesign, permanent)
- ✅ `scrapToken()` - DEPRECATED wrapper for cancelToken()
- ✅ `splitToken()` - Parallel spawn (component tokens)
- ✅ `spawnReplacementToken()` - Replacement spawn
- ✅ `spawnReworkToken()` - Rework spawn
- ✅ Join buffer management (addToJoinBuffer, checkJoinReadiness, activateJoin)

**Current Dependencies:**
- `AssignmentResolverService` - Auto-assignment on spawn
- `TimeEventReader` - Time sync from canonical events
- `NodeBehaviorEngine` - Behavior execution (behind feature flag)
- `MOEtaHealthService` - ETA health hook (non-blocking)
- `TokenEventService` - Canonical events

**Current Issues:**
- ❌ **Too many responsibilities** (God Object pattern)
- ❌ **Missing node-level methods** (startWork, pauseWork, resumeWork, completeNode)
- ❌ **Tight coupling** with assignment/ETA/time sync (should be separate concerns)

**Used By:**
- `BGERP\Dag\DagExecutionService` (line 28-29, 44) - Already using this service!
- `source/hatthasilpa_jobs_api.php` - Job creation
- `source/dag_token_api.php` - Token operations

---

## 🎯 Goal (REVISED)

**Extend** existing `TokenLifecycleService` (BGERP\Service) to support **node-level lifecycle transitions**

**Key Principle:**
- ✅ All token status changes MUST go through this service
- ❌ NO direct `UPDATE flow_token.status` anywhere else
- ✅ **Use existing class** (BGERP\Service\TokenLifecycleService)
- ❌ **DO NOT create new class** with same name in different namespace

**Why extend instead of create new:**
1. **Prevent namespace confusion** - One canonical TokenLifecycleService for entire system
2. **Backwards compatible** - Existing code (DagExecutionService) already uses BGERP\Service version
3. **Single responsibility** - Add node-level methods without touching existing spawn/move/split logic
4. **Future-proof** - Can refactor assignment/ETA/time sync in separate phase

---

## 📋 Requirements

### 1. Extend TokenLifecycleService Class

**Location:** `source/BGERP/Service/TokenLifecycleService.php` (✅ EXISTING)

**Namespace:** `BGERP\Service` (✅ KEEP EXISTING)

**New Dependencies:**
- ✅ `BGERP\Dag\TokenEventService` - Already used for canonical events
- ✅ `BGERP\Service\DAGRoutingService` - Already available
- ⚠️ **AVOID circular dependency** with BehaviorExecutionService

### 2. Rationale: Why Extend Instead of Create New

**Decision:** Extend `BGERP\Service\TokenLifecycleService` instead of creating `BGERP\Dag\TokenLifecycleService`

**Reasons:**

1. **Prevent Namespace Confusion** 🚫
   - Having two classes named `TokenLifecycleService` in different namespaces causes:
     - Developer confusion: "Which one is the real one?"
     - AI agent confusion: "Which one should I use?"
     - Maintenance nightmare: "Which one should be updated?"
   - **Solution:** One canonical class per responsibility

2. **Existing Usage** ✅
   - `DagExecutionService` already uses `BGERP\Service\TokenLifecycleService`
   - Multiple APIs use this service
   - Changing namespace would require widespread refactoring
   - **Better:** Extend what's already integrated

3. **Backwards Compatibility** 🔒
   - Existing methods (spawn/move/complete/split) must continue working
   - No production data yet, but code stability matters
   - Adding methods = safe, replacing class = risky

4. **Single Source of Truth** 🎯
   - Token lifecycle should have ONE owner: `BGERP\Service\TokenLifecycleService`
   - Not two owners in different namespaces
   - Clear ownership = better maintainability

5. **Future Refactor Path** 🔮
   - Phase 1 (now): Add node-level methods
   - Phase 2 (later): Extract assignment logic → AssignmentEngine
   - Phase 3 (later): Extract ETA logic → MOEtaHealthService
   - Phase 4 (later): Extract time sync → TimeEventReader
   - Result: Clean, focused TokenLifecycleService with clear responsibilities

**Alternative Considered (Rejected):**
- ❌ Create `BGERP\Dag\TokenLifecycleService` - Would cause namespace confusion
- ❌ Create `BGERP\Dag\NodeLifecycleService` - Would duplicate token status logic
- ❌ Create adapter/wrapper - Unnecessary abstraction layer

---

### 3. Implementation Strategy

**Approach:** **ADDITIVE ONLY** - Add new methods without touching existing logic

**File Structure After Task 27.2:**
```php
<?php
namespace BGERP\Service;

class TokenLifecycleService {
    // ========================================
    // EXISTING METHODS (DO NOT MODIFY)
    // ========================================
    public function spawnTokens(...)      // ✅ Keep unchanged
    public function moveToken(...)        // ✅ Keep unchanged
    public function completeToken(...)    // ✅ Keep unchanged
    public function cancelToken(...)      // ✅ Keep unchanged
    public function splitToken(...)       // ✅ Keep unchanged
    // ... other existing methods ...
    
    // ========================================
    // NEW METHODS (Task 27.2)
    // ========================================
    public function startWork(int $tokenId): void           // ⭐ NEW
    public function pauseWork(int $tokenId): void           // ⭐ NEW
    public function resumeWork(int $tokenId): void          // ⭐ NEW
    public function completeNode(int $tokenId, int $nodeId): array  // ⭐ NEW
    // scrapToken() - refactor existing deprecated method if needed
}
```

**Why This Approach:**
1. ✅ **No breaking changes** - Existing code continues to work
2. ✅ **No namespace confusion** - One TokenLifecycleService for entire system
3. ✅ **Clean separation** - New methods = node-level, existing methods = job-level
4. ✅ **Future refactor-ready** - Can extract assignment/ETA later without breaking public API

**Integration:**
- `DagExecutionService` already uses `BGERP\Service\TokenLifecycleService` (line 28-29)
- `BehaviorExecutionService` will start using new node-level methods (Task 27.3)
- No changes to imports/namespaces needed (same class)

---

---

### 4. Implement NEW Methods (Phase 1 Scope)

**⚠️ PHASE 1 SCOPE:** Normal/End nodes only (NO split/merge yet)

**⚠️ CRITICAL RULE:** Add new methods ONLY. DO NOT modify existing methods.

#### 4.1 startWork($tokenId)

```php
/**
 * Start work on token (first time)
 * Transition: ready → active
 * 
 * @param int $tokenId
 * @throws Exception if token status invalid
 */
public function startWork(int $tokenId): void
```

**Logic:**
1. Fetch token, validate exists
2. Validate current status: MUST be `'ready'` ONLY (NOT paused - use resumeWork instead)
3. Transition to `'active'`
4. Emit canonical event: `NODE_START`

**⚠️ Design Decision:**
- `startWork()` = เริ่มงานครั้งแรก (ready → active)
- `resumeWork()` = กลับมาทำต่อ (paused → active)
- **Clear separation** prevents confusion

#### 4.2 pauseWork($tokenId)

```php
/**
 * Pause work on token
 * Transition: active → paused
 * 
 * @param int $tokenId
 * @throws Exception if token not active
 */
public function pauseWork(int $tokenId): void
```

**Logic:**
1. Validate current status: MUST be `'active'`
2. Transition to `'paused'`
3. Emit canonical event: `NODE_PAUSE`

#### 4.3 resumeWork($tokenId)

```php
/**
 * Resume work on token
 * Transition: paused → active
 * 
 * @param int $tokenId
 * @throws Exception if token not paused
 */
public function resumeWork(int $tokenId): void
```

**Logic:**
1. Validate current status: MUST be `'paused'`
2. Transition to `'active'`
3. Emit canonical event: `NODE_RESUME`

#### 4.4 completeNode($tokenId, $nodeId)

```php
/**
 * Complete node work
 * Handles routing based on node type
 * 
 * Phase 1: Normal/End nodes only (NO split/merge)
 * 
 * @param int $tokenId
 * @param int $nodeId
 * @return array Result with routing info
 */
public function completeNode(int $tokenId, int $nodeId): array
```

**Phase 1 Logic:**
1. Fetch node, validate exists
2. Check node type:
   - **End node** (no outgoing edges):
     - Transition to `'completed'`
     - Set `completed_at = NOW()`
     - Emit `NODE_COMPLETE`
     - Return `['ok' => true, 'effect' => 'token_completed']`
   - **Normal node** (has outgoing edges):
     - Call `DagExecutionService::moveToNextNode($tokenId)`
     - Keep status `'active'`
     - Emit `NODE_COMPLETE`
     - Return routing result
   - **Split/Merge node** (Phase 1):
     - ⚠️ NOT IMPLEMENTED YET
     - Return `['ok' => false, 'error' => 'Split/merge not implemented in Phase 1']`

#### 4.5 scrapToken($tokenId, $reason)

```php
/**
 * Scrap token (for QC fail, damage, etc.)
 * Transition: any → scrapped
 * 
 * @param int $tokenId
 * @param string $reason
 */
public function scrapToken(int $tokenId, string $reason): void
```

**Logic:**
1. Fetch token
2. Transition to `'scrapped'`
3. Set `scrapped_at = NOW()`
4. Store reason in `metadata->scrap_reason`
5. Emit canonical event: `NODE_CANCEL`

**Note on Existing scrapToken():**
- Current implementation is deprecated wrapper for `cancelToken()`
- **Implementation options:**
  - **Option A:** Refactor existing `scrapToken()` to align with spec (simple implementation)
  - **Option B:** Keep existing as-is, create `scrapTokenSimple()` for Phase 1
  - **Option C:** Make new `scrapToken()` call `cancelToken('permanent', $reason)` internally
- **Decision:** Choose during implementation based on backwards compatibility needs

**⚠️ Event Naming Note:**
- Current spec uses `NODE_CANCEL` event for scrap action
- Future consideration: May want dedicated `NODE_SCRAP` event type for analytics
- For Phase 1: `NODE_CANCEL` is acceptable
- Can add TODO comment in code for future enhancement

---

## 🚧 Guardrails (MUST FOLLOW)

### Guardrail 0: Extend, Not Replace
- ✅ **EXTEND** existing BGERP\Service\TokenLifecycleService class
- ❌ **DO NOT create** new class in BGERP\Dag namespace
- ✅ **ADD** new methods only
- ❌ **DO NOT modify** existing methods (spawn/move/complete/split/cancel/join)
- ✅ **Keep backwards compatible** - DagExecutionService must continue to work

### Guardrail 1: Single Responsibility (New Methods Only)
- ✅ New methods ONLY manage `flow_token.status` transitions
- ❌ NO session management (ให้ TokenWorkSessionService ทำ)
- ❌ NO behavior logic (ให้ BehaviorExecutionService ทำ)
- ❌ NO component metadata (ให้ ComponentFlowService ทำ)
- ⚠️ **Existing methods may have assignment/ETA/time sync** - leave unchanged for now

### Guardrail 2: Phase 1 Scope
- ✅ Implement: startWork, pauseWork, resumeWork, completeNode (normal/end only), scrapToken
- ❌ NO split/merge logic (Phase 3 only)
- ❌ NO component-specific logic (Phase 2 only)
- ✅ If encounter split/merge node → return error (ยังไม่รองรับ)

### Guardrail 3: State Machine Validation
- ✅ MUST validate current status before transition
- ✅ MUST throw exception if invalid transition
- ❌ NO silent failures
- ✅ Log all state changes

**Valid Transitions (Phase 1):**
```
ready → active (startWork)
active → paused (pauseWork)
paused → active (resumeWork)
active → active (completeNode normal)
active → completed (completeNode end)
any → scrapped (scrapToken)
```

**Invalid Transitions (MUST throw exception):**
```
completed → active (terminal state)
scrapped → active (terminal state)
ready → paused (must be active first)
```

### Guardrail 4: Database Constraints
- ✅ Use prepared statements (MANDATORY)
- ✅ Update ONLY `flow_token.status`, `completed_at`, `scrapped_at`, `metadata`
- ❌ NO changes to other tables (sessions, nodes, edges, etc.)
- ✅ Use transactions for multi-step operations

### Guardrail 5: Integration Points (New Methods)
- ✅ Call `TokenEventService::persistEvents()` for canonical events
- ✅ Call `DagExecutionService::moveToNextNode()` for routing (normal node)
- ❌ NO calling BehaviorExecutionService (ป้องกัน circular dependency)
- ❌ NO calling ComponentFlowService yet (Phase 2)
- ✅ Use existing `createEvent()` helper if available in class

### Guardrail 6: Avoid Circular Dependencies
**⚠️ CRITICAL:** Prevent circular dependency loop

**Current dependency chain:**
```
BehaviorExecutionService 
  └─→ DagExecutionService
       └─→ TokenLifecycleService (BGERP\Service)
```

**After Task 27.2:**
```
BehaviorExecutionService
  ├─→ DagExecutionService
  │    └─→ TokenLifecycleService (BGERP\Service) - existing methods
  └─→ TokenLifecycleService (BGERP\Service) - NEW node-level methods
```

**Rule:** TokenLifecycleService **MUST NOT** call BehaviorExecutionService
- ✅ Can call DagExecutionService (already does via moveToken)
- ✅ Can call TokenEventService (already does)
- ❌ Cannot call BehaviorExecutionService (would create cycle)

---

## 🔮 Future Refactor Plan (Out of Scope for Task 27.2)

**Current State After Task 27.2:**
```
BGERP\Service\TokenLifecycleService {
    // Job-level methods (existing, untouched):
    + spawnTokens()
    + moveToken()
    + completeToken()
    + cancelToken()
    + splitToken()
    
    // Node-level methods (NEW in Task 27.2):
    + startWork()
    + pauseWork()
    + resumeWork()
    + completeNode()
    + scrapToken()
    
    // Legacy concerns (existing, to refactor later):
    - resolveAndAssignToken() → Should be in AssignmentEngine
    - ETA health hook → Should be in MOEtaHealthService
    - Time sync logic → Should be in TimeEventReader
}
```

**Future Phase (Separate Tasks - NOT Task 27.2):**

**Phase A: Extract Assignment Logic**
- Move `resolveAndAssignToken()` → `AssignmentEngine`
- Remove assignment dependencies from TokenLifecycleService
- Keep public API same (internal refactor only)

**Phase B: Extract ETA Logic**
- Move ETA health hook → `MOEtaHealthService::subscribeToTokenEvents()`
- Use event listener pattern instead of direct call
- Decouple ETA from lifecycle

**Phase C: Extract Time Sync Logic**
- Move time sync → `TimeEventReader::autoSync()`
- Use event listener pattern
- TokenLifecycleService focuses on status only

**Phase D: Final State (Target Architecture)**
```
BGERP\Service\TokenLifecycleService {
    // Pure lifecycle only:
    + spawnTokens()        - Create tokens
    + startWork()          - ready → active
    + pauseWork()          - active → paused
    + resumeWork()         - paused → active
    + completeNode()       - Complete + route
    + completeToken()      - Final completion
    + scrapToken()         - any → scrapped
    + cancelToken()        - Cancel with types
    + splitToken()         - Parallel spawn
    + mergeTokens()        - Merge tokens
    
    // Event emission only (no external service calls)
    - Emit canonical events
    - Update flow_token.status
    - Call routing service (DagExecutionService)
}

// Concerns extracted to:
AssignmentEngine - Auto-assignment on spawn
MOEtaHealthService - ETA health monitoring (event listener)
TimeEventReader - Time sync from events (event listener)
```

**⚠️ For Task 27.2:** Focus ONLY on adding 5 node-level methods. Future refactor = separate tasks.

---

## 🧪 Testing Requirements

### Unit Tests (Minimum)

**File:** `tests/Unit/Dag/TokenLifecycleServiceNodeLevelTest.php` (NEW)

**⚠️ Note:** Use different filename to avoid conflict with potential existing tests for spawn/move methods

**Test Cases (Node-Level Methods ONLY):**
1. `testStartWorkFromReady()` - ready → active ✅
2. `testStartWorkFromPaused()` - should throw exception ❌ (use resumeWork instead)
3. `testStartWorkFromCompleted()` - should throw exception ❌
4. `testPauseWorkFromActive()` - active → paused ✅
5. `testPauseWorkFromReady()` - should throw exception ❌
6. `testResumeWorkFromPaused()` - paused → active ✅
7. `testCompleteNormalNode()` - active → active (move to next) ✅
8. `testCompleteEndNode()` - active → completed ✅
9. `testScrapToken()` - any → scrapped ✅
10. `testCanonicalEventsEmitted()` - verify events persisted ✅

**Run Command:**
```bash
# Test new node-level methods only
vendor/bin/phpunit tests/Unit/Dag/TokenLifecycleServiceNodeLevelTest.php --testdox

# Verify all existing tests still pass
vendor/bin/phpunit tests/ --testdox
```

**Expected:** 
- All new tests pass (10/10)
- All existing tests still pass (no regressions)

---

## 📦 Deliverables

### 1. Source Files (Modified)

- ✅ `source/BGERP/Service/TokenLifecycleService.php` (**EXTEND EXISTING**)
  - **ADD** 5 new methods:
    - `startWork(int $tokenId): void`
    - `pauseWork(int $tokenId): void`
    - `resumeWork(int $tokenId): void`
    - `completeNode(int $tokenId, int $nodeId): array`
    - Refactor existing `scrapToken()` if needed (currently deprecated)
  - **DO NOT MODIFY** existing methods:
    - spawnTokens(), moveToken(), completeToken(), cancelToken(), splitToken() → Keep unchanged
  - Add ~200-300 lines (new methods only)
  - Full docblocks for new methods
  - PSR-4 compliant (already is)

### 2. Test Files (New)

- ✅ `tests/Unit/Dag/TokenLifecycleServiceNodeLevelTest.php` (new file)
  - **Note:** Use different filename to avoid conflict with existing tests
  - 10 test cases minimum (for new node-level methods only)
  - All passing
  - ~150-200 lines

### 3. Documentation Updates

- ✅ Update `docs/super_dag/DOCUMENTATION_COMPLETE.md`
  - Add: "Task 27.2 Complete - TokenLifecycleService extended with node-level methods"
- ❌ NO new .md files (update existing only)

---

## ✅ Definition of Done

- [ ] TokenLifecycleService (BGERP\Service) extended with 5 new methods
- [ ] All 5 new methods implemented and tested:
  - [ ] startWork($tokenId) - ready/paused → active
  - [ ] pauseWork($tokenId) - active → paused
  - [ ] resumeWork($tokenId) - paused → active
  - [ ] completeNode($tokenId, $nodeId) - routing by node type
  - [ ] scrapToken($tokenId, $reason) - any → scrapped (refactor if needed)
- [ ] State machine validation works (throws on invalid transitions)
- [ ] Canonical events emitted correctly (via TokenEventService)
- [ ] Unit tests pass (10/10)
- [ ] Existing methods (spawn/move/complete/split) unchanged and still working
- [ ] DagExecutionService still works (uses same service)
- [ ] No `UPDATE flow_token.status` in new methods (use proper transitions)
- [ ] Code compiles without errors
- [ ] PSR-4 autoload works (no changes needed - class exists)

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO creating new TokenLifecycleService in BGERP\Dag namespace (use existing BGERP\Service)
- ❌ NO modifying existing methods (spawn/move/complete/split/join) - keep unchanged
- ❌ NO refactoring assignment/ETA/time sync logic out (separate task later)
- ❌ NO split/merge implementation (Phase 3)
- ❌ NO component-specific logic (Phase 2)
- ❌ NO refactoring BehaviorExecutionService yet (Task 27.3)
- ❌ NO UI changes
- ❌ NO database schema changes
- ❌ NO new migration files
- ❌ NO touching Classic line code
- ❌ NO creating new documentation files (update existing only)

---

## 💡 Implementation Notes

### Note 1: Use Existing Helper Methods

**The class already has these helpers:**
- ✅ `fetchToken($tokenId)` - Fetch token data
- ✅ `fetchNode($nodeId)` - Fetch node data
- ✅ `createEvent($tokenId, $eventType, ...)` - Create token events
- ✅ `generateUUID()` - Generate idempotency keys

**Use these instead of duplicating!**

### Note 2: Existing Event Creation Pattern

**Current pattern in class:**
```php
$this->createEvent($tokenId, 'event_type', $nodeId, $operatorId, [
    'metadata' => 'value'
]);
```

**For canonical events (new methods):**
- Use `TokenEventService::persistEvents()` for canonical types (TOKEN_*, NODE_*, etc.)
- Or extend `createEvent()` to support canonical types

### Note 3: State Machine Validation Template

**Reusable validation pattern:**
```php
private function validateTransition(array $token, string $expectedStatus, string $action): void
{
    if ($token['status'] !== $expectedStatus) {
        throw new \Exception(sprintf(
            'Cannot %s: Token status is %s, expected %s',
            $action,
            $token['status'],
            $expectedStatus
        ));
    }
}

// Usage in new methods:
public function startWork(int $tokenId): void {
    $token = $this->fetchToken($tokenId);
    $this->validateTransition($token, 'ready', 'start work');  // STRICT: ready only
    // ... proceed with start logic
}

public function pauseWork(int $tokenId): void {
    $token = $this->fetchToken($tokenId);
    $this->validateTransition($token, 'active', 'pause work');
    // ... proceed with pause logic
}

public function resumeWork(int $tokenId): void {
    $token = $this->fetchToken($tokenId);
    $this->validateTransition($token, 'paused', 'resume work');
    // ... proceed with resume logic
}
```

**⚠️ Design Decision - Strict State Validation:**
- `startWork()` accepts `ready` ONLY (not `paused`)
- `resumeWork()` accepts `paused` ONLY (not `ready`)
- Clear separation prevents confusion and makes state machine predictable

### Note 4: Avoid Breaking Existing Code

**Before implementing:**
1. ✅ Read existing methods to understand patterns
2. ✅ Check where existing methods are called (grep for usage)
3. ✅ Test that existing tests still pass after adding new methods

**After implementing:**
1. ✅ Run `vendor/bin/phpunit tests/` to verify no regressions
2. ✅ Check that DagExecutionService still works
3. ✅ Verify existing APIs still function

### Note 5: completeNode() vs completeToken()

**⚠️ Important distinction:**

**Existing `completeToken()`:**
- Marks token as completed (terminal state)
- Sets completed_at timestamp
- Called when token reaches END node
- Does NOT route to next node

**New `completeNode()`:**
- Completes work at CURRENT node
- Routes to next node (if normal node)
- OR marks completed (if end node)
- Internally may call existing `completeToken()` for end nodes

**Implementation approach:**
```php
public function completeNode(int $tokenId, int $nodeId): array
{
    $node = $this->fetchNode($nodeId);
    
    // Check if end node (no outgoing edges)
    if ($this->isEndNode($nodeId)) {
        // Delegate to existing completeToken()
        $this->completeToken($tokenId, null);
        return ['ok' => true, 'effect' => 'token_completed', 'completed' => true];
    }
    
    // Normal node - route to next
    // Use DagExecutionService (if available) or DAGRoutingService
    // ...
}
```

---

## ✅ Verification Checklist

**Before marking task complete, verify:**

### Backwards Compatibility
- [ ] Run existing tests: `vendor/bin/phpunit tests/`
- [ ] All existing tests pass (no regressions)
- [ ] DagExecutionService still uses TokenLifecycleService correctly
- [ ] Existing APIs that use spawn/move/complete still work

### New Functionality
- [ ] New methods follow state machine spec exactly
- [ ] Invalid transitions throw exceptions (not silent failures)
- [ ] Canonical events emitted correctly
- [ ] New tests cover all edge cases

### Code Quality
- [ ] No direct `UPDATE flow_token.status` in new methods
- [ ] Proper error messages in exceptions
- [ ] Comprehensive docblocks
- [ ] PSR-4 compliant (already is)

### Integration
- [ ] No circular dependencies introduced
- [ ] Service can be instantiated without errors
- [ ] Methods can be called from BehaviorExecutionService (Task 27.3 prep)

---

## ⚠️ Implementation Awareness

**This spec is a "North Star" reference, not a blood contract.**

**Known Minor Inconsistencies (FYI - Not Blockers):**

1. **scrapToken() Method:**
   - Existing implementation is deprecated wrapper for `cancelToken()`
   - Spec wants simple `scrapToken($tokenId, $reason)`
   - **Decision during implementation:** Choose refactor approach that maintains backwards compatibility

2. **Event Naming:**
   - Current spec uses `NODE_CANCEL` for scrap action
   - Future: May want dedicated `NODE_SCRAP` event for analytics separation
   - **Phase 1:** `NODE_CANCEL` is acceptable
   - Can add `// TODO: Consider NODE_SCRAP event type` in code

3. **Test Filename:**
   - Suggested: `TokenLifecycleServiceNodeLevelTest.php`
   - Final name decided during implementation
   - As long as tests cover all cases, exact filename is flexible

**Key Principle:** 
- ✅ Follow state machine strictly (ready → active → paused → active → completed)
- ✅ Emit canonical events consistently
- ✅ Don't break existing code
- ⚠️ Minor details (test names, exact error messages) = flexible during implementation

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - Section 1 (State machine)
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 4 (Lifecycle transitions)

**Audit:**
- `docs/super_dag/00-audit/20251202_BEHAVIOR_LAYER_AUDIT_REPORT.md` - Section 3 (Token status gaps)

**Existing Code:**
- `source/BGERP/Service/TokenLifecycleService.php` - **TARGET FILE** (extend this)
- `source/BGERP/Dag/TokenEventService.php` - Canonical events
- `source/BGERP/Dag/DagExecutionService.php` - Routing (uses BGERP\Service\TokenLifecycleService)

**Wiring Guide:**
- `docs/developer/SYSTEM_WIRING_GUIDE.md` - Section 2 (Token Execution Pipeline)

---

## 📝 Results Template

**After completion, create:**

`docs/super_dag/tasks/results/task27.2_results.md`

```markdown
# Task 27.2 Results — TokenLifecycleService Extended with Node-Level Methods

**Completed:** YYYY-MM-DD  
**Duration:** X hours  
**Status:** ✅ Complete

## Files Modified
- `source/BGERP/Service/TokenLifecycleService.php` (extended, +XXX lines)
  - Added methods: startWork, pauseWork, resumeWork, completeNode, scrapToken
  - Existing methods unchanged: spawnTokens, moveToken, completeToken, cancelToken, splitToken

## Files Created
- `tests/Unit/Dag/TokenLifecycleServiceNodeLevelTest.php` (XXX lines)
  - Tests for new node-level methods only

## Existing Code Impact
- ✅ DagExecutionService still works (no changes to existing usage)
- ✅ Existing methods unchanged (spawn/move/complete/split/join)
- ✅ Backwards compatible (100%)

## Test Results
```
vendor/bin/phpunit tests/Unit/Dag/TokenLifecycleServiceNodeLevelTest.php --testdox
✅ 10/10 tests passed (new methods)

vendor/bin/phpunit tests/ (all tests)
✅ All existing tests still pass
```

## Issues Encountered
- (List any issues and how they were resolved)

## Next Steps
- Proceed to Task 27.3 (Refactor BehaviorExecutionService to use new methods)
- Future: Refactor assignment/ETA/time sync out of TokenLifecycleService (separate phase)
```

---

**END OF TASK**

