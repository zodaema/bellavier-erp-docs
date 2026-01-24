# Task 27.9 — Parallel Flow Failure Recovery & Error Handling

**Phase:** 4 - Failure Recovery  
**Priority:** 🟡 HIGH  
**Estimated Effort:** 6-8 hours  
**Status:** 📋 Pending
**Approach:** 🎨 **Design-First** (Runtime validation deferred)

**Parent Task:** Phase 4 - Failure Mode Recovery  
**Dependencies:** Task 27.8 (Parallel flow integration complete) ✅  
**Blocks:** Task 27.10 (Component metadata aggregation)

---

## 🚨 **CRITICAL: Design-First Approach**

**⚠️ Context & Constraints:**

**Graph Validation Limitation (Known Issue):**
- Graph validation engine (CI-04) ยังไม่รองรับ parallel pattern ใหม่
- Graph ที่มี `is_parallel_split=1` / `is_merge_node=1` ยัง publish ไม่ได้
- End-to-end testing ผ่าน UI/Work Queue ยังทำไม่ได้จนกว่า validation จะ refactor

**Impact on Task 27.9:**
- ❌ Cannot do full end-to-end integration tests
- ✅ Can do unit tests (mock-based error injection)
- ✅ Can design error handling policies
- ✅ Can implement error recovery logic
- ⏸️ Full integration tests deferred (see "Future Work" section)

**Documented In:**
- `docs/super_dag/00-audit/GRAPH_DESIGNER_RULES.md` (validation limitations)
- `docs/super_dag/tasks/results/task27.6_results.md` (validation issues encountered)

**Approach Adjustment:**
- **Originally:** Full implementation + end-to-end tests
- **Adjusted:** Design + code + unit tests (integration tests deferred)
- **Rationale:** Don't block progress on validation engine refactor (separate large project)

---

## 📝 Quick Summary (TL;DR)

**What This Task Does:**
1. Analyzes 4 failure modes (split error, merge error, component scrap, QC fail)
2. Implements error handling in ParallelMachineCoordinator (idempotency, scrap detection)
3. Creates FailureRecoveryService (QC fail recovery only - component scrap deferred)
4. Writes unit tests with mock-based error injection
5. Documents future work (integration tests + component scrap policy)

**What This Task Does NOT Do:**
- ❌ End-to-end integration tests (blocked by graph validation)
- ❌ Graph validation engine refactor (separate project)
- ❌ UI changes or schema changes

**Key Deliverables:**
- Enhanced error handling (~45 lines in coordinator)
- New recovery service (~240 lines)
- 12 unit tests (~280 lines)
- Future work documentation

---

## 🎯 Goal

Design and implement error handling and recovery mechanisms for parallel flow (split/merge operations) and QC fail scenarios.

**Key Principles:**
- ✅ Design state machine behavior for error scenarios
- ✅ Implement error propagation and logging
- ✅ Define recovery policies (idempotency, rollback, retry)
- ⏸️ Runtime validation deferred to future task (when validation engine ready)
- ❌ TokenLifecycleService = Normal flow only (no recovery logic mixing)

---

## 📋 Failure Modes Analysis

### Failure Mode 1: DB/System Error During Split

**Scenario:**
- `ParallelMachineCoordinator::handleSplit()` starts transaction
- INSERT creates some components successfully
- Transaction fails mid-way (DB connection lost, constraint violation, etc.)

**Current Behavior (Task 27.7):**
- ✅ Transaction wrapper exists → rollback should occur
- ✅ No components created if transaction fails
- ⚠️ If components created but `updateToken(parent, 'waiting')` fails → inconsistent state

**Desired Behavior:**
- **Guarantee 1:** If transaction fails → NO components exist
- **Guarantee 2:** Parent token remains in safe state (not stuck in 'waiting' with no components)
- **Guarantee 3:** Error logged with correlation ID for debugging
- **Recovery:** Retry split operation (idempotent)

**Implementation Strategy:**
- Wrap entire split flow in transaction (already done in 27.7)
- Add error state detection: if components exist but parent != 'waiting' → alert
- Optional: Add `error_split` status for explicit error tracking

---

### Failure Mode 2: DB/System Error During Merge

**Scenario:**
- All components complete at merge node
- `ParallelMachineCoordinator::handleMerge()` checks readiness
- Parent re-activation fails (updateToken fails, DB error, etc.)

**Current Behavior (Task 27.7/27.8):**
- ✅ Components marked complete
- ⚠️ Parent might remain in 'waiting' state (merge appears incomplete)
- ⚠️ Retry might trigger double-activation (if not idempotent)

**Desired Behavior:**
- **Guarantee 1:** handleMerge() is idempotent (can retry safely)
- **Guarantee 2:** If merge detected as complete but parent activation failed → log error, allow retry
- **Guarantee 3:** No double-activation of parent token
- **Recovery:** Retry merge operation (should detect already complete and only activate parent)

**Implementation Strategy:**
- Add idempotency check: if parent already 'active' at merge node → return success (no-op)
- Add merge completion detection: query component statuses before re-activating
- Log all merge attempts with component IDs

---

### Failure Mode 3: Business Error (Component Scrap)

**Scenario:**
- 1 or more component tokens get scrapped (QC fail, damage, etc.)
- Merge can never complete naturally (missing components)
- Parent token stuck in 'waiting' indefinitely

**Current Behavior (Task 27.7/27.8):**
- ❌ No policy for component scrap
- ❌ Parent remains 'waiting' forever
- ❌ No alert or recovery path

**Desired Behavior:**
- **Policy Option A:** Scrapped component → scrap entire parallel group (parent + siblings)
- **Policy Option B:** Allow replacement component spawn (maintain group integrity)
- **Policy Option C:** Optional components → merge continues without them
- **Guarantee:** Parent token never stuck indefinitely

**Implementation Strategy (Design Only - Implementation in Task 27.X):**
- **Policy A (Recommended):** Component scrap → cascade to parent
  - When any component scrapped → mark parent as 'scrapped'
  - Mark all sibling components as 'scrapped' (optional)
  - Log cascade with parallel_group_id for traceability
  
- **Policy B (Alternative):** Allow replacement component spawn
  - Spawn new component to replace scrapped one
  - Maintain parallel_group_id integrity
  
- **Policy C (Advanced):** Optional components
  - Some components marked as optional
  - Merge continues without them

**Task 27.9 Scope:** Design policies + add detection helper (`checkComponentScrapStatus`)  
**Task 27.X Scope:** Implement full `handleComponentScrapped()` cascade logic

---

### Failure Mode 4: QC Fail on Regular Token

**Scenario:**
- Token fails QC inspection
- Need to scrap and spawn replacement

**Current Behavior:**
- ⚠️ No centralized QC fail handling
- ⚠️ Behavior might handle inconsistently

**Desired Behavior:**
- Scrap failed token
- Spawn replacement token (same attributes, status='ready')
- Link tokens (replacement_token_id, parent_scrapped_token_id)
- Log operation

**Implementation Strategy:**
- Create `handleQcFail(tokenId, reason)` method
- Delegate to TokenLifecycleService for scrap
- Spawn replacement with cloned attributes
- Maintain token chain for traceability

---

## 📋 Requirements

### 0. Enhance ParallelMachineCoordinator (Error Handling)

**File:** `source/BGERP/Dag/ParallelMachineCoordinator.php`

**Changes:**

**1. Add Idempotency Check to handleMerge():**
```php
// At start of handleMerge():
$parent = $this->fetchToken($parentTokenId);
if ($parent['status'] === 'active' && $parent['current_node_id'] === $nodeId) {
    // Already merged and activated
    error_log("[ParallelMachineCoordinator] Merge idempotency: parent {$parentTokenId} already active at merge node");
    return [
        'ok' => true,
        'merge_complete' => true,
        'parent_token_id' => $parentTokenId,
        'idempotent' => true,
        'component_times' => $this->aggregateComponentTimes($parentTokenId)
    ];
}
```

**2. Add Component Scrap Detection:**
```php
/**
 * Check if any components in parallel group are scrapped
 * 
 * @param int $parentTokenId Parent token ID
 * @return array ['has_scrapped' => bool, 'scrapped_ids' => array]
 */
public function checkComponentScrapStatus(int $parentTokenId): array
{
    $stmt = $this->db->prepare("
        SELECT id_token, status 
        FROM flow_token 
        WHERE parent_token_id = ?
    ");
    $stmt->bind_param('i', $parentTokenId);
    $stmt->execute();
    $components = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    
    $scrappedIds = [];
    foreach ($components as $comp) {
        if ($comp['status'] === 'scrapped') {
            $scrappedIds[] = $comp['id_token'];
        }
    }
    
    return [
        'has_scrapped' => !empty($scrappedIds),
        'scrapped_ids' => $scrappedIds,
        'total_components' => count($components)
    ];
}
```

**3. Enhanced Error Logging:**
```php
// Add correlation ID to all error logs
// Format: [ParallelMachineCoordinator][handleSplit|handleMerge] CID:{correlation_id} ...
```

---

### 1. Create FailureRecoveryService Class

**Location:** `source/BGERP/Dag/FailureRecoveryService.php`

**Namespace:** `BGERP\Dag`

**Dependencies:**
- `mysqli` - Database
- `BGERP\Service\TokenLifecycleService` - For scrapTokenSimple ⚠️ (Service namespace!)
- `BGERP\Helper\TimeHelper` - Time utilities

### 2. Implement Method: handleQcFail($tokenId, $reason)

```php
/**
 * Handle QC fail scenario
 * Scraps token and spawns replacement
 * 
 * @param int $tokenId Failed token
 * @param string $reason Failure reason
 * @return array ['ok', 'scrapped_token_id', 'replacement_token_id']
 */
public function handleQcFail(int $tokenId, string $reason): array
{
    // 1. Fetch token
    $token = $this->fetchToken($tokenId);
    if (!$token) {
        return ['ok' => false, 'error' => 'Token not found'];
    }
    
    // 2. Scrap token (call lifecycle service)
    // Note: Use scrapTokenSimple() from TokenLifecycleService (Task 27.2)
    try {
        $this->lifecycleService->scrapTokenSimple($tokenId, $reason);
    } catch (Exception $e) {
        error_log("[FailureRecovery] Scrap failed: " . $e->getMessage());
        return ['ok' => false, 'error' => 'Failed to scrap token'];
    }
    
    // 3. Spawn replacement token
    $replacementTokenId = $this->spawnReplacementToken($token);
    
    // 4. Link tokens
    $stmt = $this->db->prepare("
        UPDATE flow_token 
        SET replacement_token_id = ?
        WHERE id_token = ?
    ");
    $stmt->bind_param('ii', $replacementTokenId, $tokenId);
    $stmt->execute();
    
    $stmt = $this->db->prepare("
        UPDATE flow_token 
        SET parent_scrapped_token_id = ?
        WHERE id_token = ?
    ");
    $stmt->bind_param('ii', $tokenId, $replacementTokenId);
    $stmt->execute();
    
    // 5. Log
    error_log(sprintf(
        "[FailureRecovery] QC Fail: scrapped=%d, replacement=%d, reason=%s",
        $tokenId, $replacementTokenId, $reason
    ));
    
    return [
        'ok' => true,
        'effect' => 'qc_fail_recovered',
        'scrapped_token_id' => $tokenId,
        'replacement_token_id' => $replacementTokenId,
        'message' => 'สร้าง token ใหม่แทนที่แล้ว'
    ];
}
```

### 3. Add Method: spawnReplacementToken($scrappedToken)

```php
/**
 * Spawn replacement token from scrapped token
 * Clones token attributes but status = ready
 * 
 * @param array $scrappedToken Scrapped token data
 * @return int New token ID
 */
private function spawnReplacementToken(array $scrappedToken): int
{
    // Determine replacement start node
    // For now: same node as scrapped token (or configurable)
    $replacementNodeId = $this->getReplacementStartNode($scrappedToken);
    
    $stmt = $this->db->prepare("
        INSERT INTO flow_token (
            id_instance,
            token_type,
            parent_token_id,
            parallel_group_id,
            parallel_branch_key,
            current_node_id,
            status,
            qty,
            metadata,
            spawned_at
        ) VALUES (?, ?, ?, ?, ?, ?, 'ready', ?, ?, NOW())
    ");
    
    // Copy metadata but add replacement flag
    $metadata = json_decode($scrappedToken['metadata'] ?? '{}', true);
    $metadata['is_replacement'] = true;
    $metadata['replaces_token_id'] = $scrappedToken['id_token'];
    $metadataJson = json_encode($metadata);
    
    $stmt->bind_param(
        'isiisiss',  // 8 params: int, string, int, int, string, int, string, string
        $scrappedToken['id_instance'],
        $scrappedToken['token_type'],
        $scrappedToken['parent_token_id'],
        $scrappedToken['parallel_group_id'],
        $scrappedToken['parallel_branch_key'],
        $replacementNodeId,
        $scrappedToken['qty'],
        $metadataJson
    );
    
    $stmt->execute();
    
    return $this->db->insert_id;
}

private function getReplacementStartNode(array $scrappedToken): int
{
    // Phase 4: Simple - use same node
    // Future: configurable (e.g., go back to previous node)
    return $scrappedToken['current_node_id'];
}
```

### 4. Add Stub Method: validateTray($tokenId, $scannedTrayCode)

```php
/**
 * Validate token is in correct tray
 * 
 * Phase 4: Stub (always pass)
 * Task 27.10: Real validation
 * 
 * @param int $tokenId
 * @param string $scannedTrayCode
 * @return array ['valid' => bool, 'message' => string, 'correct_tray' => string]
 */
public function validateTray(int $tokenId, string $scannedTrayCode): array
{
    // Phase 4: Stub - always pass
    error_log("[FailureRecovery] validateTray stub: token={$tokenId}, tray={$scannedTrayCode}");
    
    return [
        'valid' => true,
        'message' => 'Tray validation not implemented yet',
        'correct_tray' => $scannedTrayCode
    ];
}
```

---

## 🚧 Guardrails (MUST FOLLOW)

### Guardrail 1: Service Ownership
- ✅ FailureRecoveryService = Owner of recovery logic
- ✅ Delegates to TokenLifecycleService for scrapToken
- ❌ NO implementing scrap logic in recovery service
- ✅ Focus on: spawn replacement, link tokens, recovery orchestration

### Guardrail 2: Replacement Token Rules
- ✅ Copy from scrapped token: id_instance, token_type, parent_token_id, parallel_group_id
- ✅ New values: status = 'ready', spawned_at = NOW()
- ✅ Link: replacement_token_id, parent_scrapped_token_id
- ❌ NO copying: status, completed_at, scrapped_at

### Guardrail 3: Error Handling
- ✅ Wrap lifecycle calls in try-catch
- ✅ Return errors gracefully
- ❌ NO silent failures
- ✅ Log all recovery operations

### Guardrail 4: Phase 4 Scope (Task 27.9)
- ✅ Implement: handleQcFail, spawnReplacementToken (QC fail recovery)
- ✅ Implement: Error detection in ParallelMachineCoordinator (idempotency, scrap status check)
- ✅ Stub: validateTray (Task 27.10 will implement)
- ❌ NO implementing: handleComponentScrapped full cascade (deferred to Task 27.X)
- ❌ NO implementing: cascadeCancelFinal (future)
- ❌ NO tray validation logic yet

### Guardrail 5: Database Safety
- ✅ Use prepared statements
- ✅ Use transactions for multi-step operations (scrap + spawn + link in handleQcFail)
- ⚠️ **Transaction Scope:** Wrap scrap → spawn → link in single transaction to prevent partial state
- ❌ NO schema changes
- ❌ NO creating new tables

**Transaction Pattern:**
```php
// Recommended pattern for handleQcFail():
$this->db->begin_transaction();
try {
    // 1. Scrap token
    $this->lifecycleService->scrapTokenSimple($tokenId, $reason);
    
    // 2. Spawn replacement
    $replacementId = $this->spawnReplacementToken($scrappedToken);
    
    // 3. Link tokens (2 updates)
    // ... UPDATE queries ...
    
    $this->db->commit();
    return ['ok' => true, ...];
} catch (\Throwable $e) {
    $this->db->rollback();
    error_log("[FailureRecovery] Transaction failed: " . $e->getMessage());
    return ['ok' => false, 'error' => 'Recovery failed'];
}
```

---

## 🧪 Testing Requirements

### Unit Tests (Mock-Based)

**Approach:** Since end-to-end tests are blocked, use mock-based unit tests with error injection.

**File 1:** `tests/Unit/ParallelMachineCoordinatorErrorTest.php` (new)

**Test Cases:**
1. `testHandleMergeIdempotency()` - Call merge twice, verify no double-activation
2. `testCheckComponentScrapStatus()` - Verify scrapped component detection
3. `testHandleMergeWithScrappedComponent()` - Should return error if component scrapped
4. `testHandleSplitTransactionRollback()` - Mock DB error, verify rollback
5. `testCorrelationIdLogging()` - Verify all errors logged with CID

**File 2:** `tests/Unit/FailureRecoveryServiceTest.php` (new)

**Test Cases:**
1. `testHandleQcFailScrapsToken()` - Verify scrap delegation
2. `testHandleQcFailSpawnsReplacement()` - Verify replacement creation
3. `testHandleQcFailLinksTokens()` - Verify bidirectional links
4. `testReplacementTokenHasCorrectAttributes()` - Verify cloning
5. `testReplacementTokenStatusReady()` - Verify initial status

**Note:** Tests for `handleComponentScrapped()` deferred to Task 27.X

**Run Command:**
```bash
vendor/bin/phpunit tests/Unit/ParallelMachineCoordinatorErrorTest.php --testdox
vendor/bin/phpunit tests/Unit/FailureRecoveryServiceTest.php --testdox
```

**Expected:** All tests pass (10/10)

---

### Low-Level Manual Testing (Optional)

**⚠️ Note:** Without published graph, can only test with manually created test data.

**Test Scenario 1: Merge Idempotency (Direct Call)**
```php
// Setup: Create parent + 3 completed components manually in DB
$coordinator = new ParallelMachineCoordinator($db);

// First call
$result1 = $coordinator->handleMerge($comp3Id, $mergeNodeId);
// Expected: merge_complete=true, parent activated

// Second call (retry)
$result2 = $coordinator->handleMerge($comp3Id, $mergeNodeId);
// Expected: merge_complete=true, idempotent=true, no double-activation
```

**Test Scenario 2: Component Scrap Detection**
```php
// Setup: Parent token ID=100, 3 components, 1 scrapped
$status = $coordinator->checkComponentScrapStatus(100);
// Expected: has_scrapped=true, scrapped_ids=[102], total_components=3
```

**Test Scenario 3: QC Fail Recovery**
```php
$recovery = new FailureRecoveryService($db, $org);
$result = $recovery->handleQcFail($tokenId, 'เย็บไม่ตรง');
// Expected: ok=true, scrapped_token_id, replacement_token_id
```

---

### Integration Tests (Future - Deferred)

**⏸️ Blocked By:** Graph Validation Engine refactor

**When Ready:**
1. Publish parallel flow test graph
2. Create Hatthasilpa job with graph
3. Test full split → component work → merge flow
4. Inject errors at each stage (F1-F4)
5. Verify recovery behaviors

**Timeline:** After Graph Validation Phase complete (estimated Q1 2026)

---

## 📦 Deliverables

### 1. Enhanced ParallelMachineCoordinator

**File:** `source/BGERP/Dag/ParallelMachineCoordinator.php` (modify)

**Changes:**
- Add idempotency check to `handleMerge()` (~15 lines)
- Add `checkComponentScrapStatus()` method (~25 lines)
- Enhanced error logging with correlation IDs (~5 lines)
- Total: ~45 lines added

### 2. New FailureRecoveryService

**File:** `source/BGERP/Dag/FailureRecoveryService.php` (new)

**Methods:**
- `handleQcFail()` - QC fail recovery (~60 lines)
- `spawnReplacementToken()` - Replacement spawn (~50 lines)
- `validateTray()` - Stub for Task 27.10 (~15 lines)
- `checkComponentScrapStatus()` - Detection only (~25 lines)
- Helper methods (~30 lines)
- Total: ~180-200 lines

**Note:** `handleComponentScrapped()` (full cascade logic) deferred to Task 27.X

### 3. Test Files

**File 1:** `tests/Unit/ParallelMachineCoordinatorErrorTest.php` (new)
- 5 test cases for error handling
- ~100-120 lines

**File 2:** `tests/Unit/FailureRecoveryServiceTest.php` (new)
- 5 test cases for QC fail recovery
- ~100-120 lines

**Total Tests:** 10 test cases, ~200-240 lines  
**Deferred:** 2 test cases for handleComponentScrapped (Task 27.X)

### 4. Documentation

**File 1:** `docs/super_dag/tasks/results/task27.9_results.md` (new)
- Implementation summary
- Error scenarios covered
- Test results
- Future work notes

**File 2:** `docs/super_dag/tasks/TASK_INDEX_BEHAVIOR_LAYER_EVOLUTION.md` (update)
- Mark Task 27.9 complete
- Add TODO for Task 27.X (integration tests)

### 5. Optional: Behavior Integration

**File:** `source/BGERP/Dag/BehaviorExecutionService.php` (optional modify)

**Change (if QC behaviors exist):**
- Update `handleQc()` to call `FailureRecoveryService::handleQcFail()` on fail
- ~10-15 lines modified

---

## ✅ Definition of Done

### Core Implementation
- [ ] ParallelMachineCoordinator enhanced (idempotency + scrap detection)
- [ ] FailureRecoveryService class created
- [ ] handleQcFail() implemented (scrap + spawn replacement with transaction)
- [ ] spawnReplacementToken() works correctly (clones attributes)
- [ ] Token links correct (replacement_token_id, parent_scrapped_token_id)
- [ ] validateTray() stub exists (Task 27.10 placeholder)
- [ ] checkComponentScrapStatus() detection only (full cascade deferred)
- [ ] Error logging with correlation IDs
- [x] handleComponentScrapped() cascade: Deferred to Task 27.X

### Testing
- [ ] Unit tests pass: ParallelMachineCoordinatorErrorTest (5/5)
- [ ] Unit tests pass: FailureRecoveryServiceTest (5/5)
- [ ] Low-level manual tests (optional): 3 scenarios verified
- [ ] Total: 10 unit tests (component scrap tests deferred)

### Documentation
- [ ] Failure modes analysis complete
- [ ] Error handling policies documented
- [ ] Future work section (integration tests deferred)
- [ ] Results document created
- [ ] TASK_INDEX updated (27.9 complete + 27.X TODO)

### Quality Gates
- [ ] No syntax errors
- [ ] Code reasoning sound (peer review)
- [ ] Backwards compatibility maintained
- [ ] No breaking changes to existing flow

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO end-to-end integration tests (blocked by graph validation)
- ❌ NO graph validation engine refactor (separate project)
- ❌ NO implementing validateTray logic (Task 27.10)
- ❌ NO implementing full cascadeCancelFinal (stub only)
- ❌ NO supervisor override mechanisms (future)
- ❌ NO UI changes
- ❌ NO database schema changes (work with existing columns)
- ❌ NO creating new tables
- ❌ NO modifying TokenLifecycleService normal flow logic

---

## 🔮 Future Work (Deferred)

### Integration Tests for Parallel Flow Error Scenarios

**Blocked By:** Graph Validation Engine enhancement (CI-04 refactor)

**Required Before Integration Tests:**
1. Update `GraphValidationEngine` to recognize:
   - `is_parallel_split` flag on operation nodes
   - `is_merge_node` flag on operation nodes
   - `produces_component` / `consumes_components` in node_config
   - Parallel edge routing patterns

2. Publish test graph:
   - Use `database/tenant_migrations/2025_12_seed_component_flow_graph.php`
   - Or create simplified version for error testing

3. Create test scenarios:
   - Happy path: split → complete components → merge ✅
   - Error F1: split transaction failure (simulate DB error)
   - Error F2: merge with parent activation failure
   - Error F3: component scrap during merge waiting
   - Error F4: QC fail on component token

**Estimated Effort:** 8-10 hours (separate task batch)

**TODO Item Created:**
```markdown
## Task 27.X: Parallel Flow Integration Tests (Future)

**Dependencies:**
- Graph Validation Engine refactor complete
- Test graph published and usable
- Task 27.7, 27.8, 27.9 complete

**Scope:**
- End-to-end happy path test
- Error injection tests (F1-F4)
- Recovery verification tests
- Performance/stress tests (100+ tokens)

**References:**
- docs/super_dag/tasks/results/task27.6_results.md (validation issues)
- docs/super_dag/00-audit/GRAPH_DESIGNER_RULES.md (validation rules)
- database/tenant_migrations/2025_12_seed_component_flow_graph.php (test fixture)
```

---

## 📊 Acceptance Criteria Adjustment

**Original Goal:** Full integration + runtime tests  
**Adjusted Goal:** Design + unit tests (integration deferred)

**Modified Definition of Done:**
- [x] Failure modes analyzed and documented (F1-F4)
- [ ] Error handling logic implemented (idempotency, logging)
- [x] Component scrap policy designed (3 policies documented, implementation deferred to 27.X)
- [ ] Component scrap detection implemented (checkComponentScrapStatus helper)
- [ ] QC fail recovery implemented (scrap + spawn replacement with transaction)
- [ ] Unit tests pass (mock-based error injection: 10/10)
- [ ] Code review complete (logic reasoning sound)
- [ ] Results document created
- [x] Future work documented (integration tests + component cascade deferred)
- ⏸️ End-to-end tests: Deferred to Task 27.X (when validation ready)
- ⏸️ Component scrap cascade: Design complete, implementation deferred to Task 27.X

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 7 (Failure modes)
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Section 13 (Failure scenarios)

**Code:**
- `source/BGERP/Service/TokenLifecycleService.php` - Service to call ⚠️ (Service namespace!)
- `source/BGERP/Dag/BehaviorExecutionService.php` - Integration point
- `source/BGERP/Dag/ParallelMachineCoordinator.php` - Error handling enhancement

---

**END OF TASK**

