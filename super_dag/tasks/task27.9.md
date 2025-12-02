# Task 27.9 — Create FailureRecoveryService + QC Fail Flow

**Phase:** 4 - Failure Recovery  
**Priority:** 🟡 HIGH  
**Estimated Effort:** 5-7 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 4 - Failure Mode Recovery  
**Dependencies:** Task 27.8 (Parallel flow working)  
**Blocks:** Task 27.10 (Wrong tray validation)

---

## 🎯 Goal

สร้าง `FailureRecoveryService` เพื่อจัดการ QC fail และ exceptional cases

**Key Principle:**
- ✅ FailureRecoveryService = Owner of recovery logic
- ❌ Behavior ไม่ implement recovery logic เอง (calls service)
- ❌ TokenLifecycleService ไม่ implement recovery logic (focuses on normal transitions)

---

## 📋 Requirements

### 1. Create FailureRecoveryService Class

**Location:** `source/BGERP/Dag/FailureRecoveryService.php`

**Namespace:** `BGERP\Dag`

**Dependencies:**
- `mysqli` - Database
- `BGERP\Dag\TokenLifecycleService` - For scrapToken
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
    try {
        $this->lifecycleService->scrapToken($tokenId, $reason);
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
        'iiiiiis',
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

### Guardrail 4: Phase 4 Scope
- ✅ Implement: handleQcFail, spawnReplacementToken
- ✅ Stub: validateTray (Task 27.10 will implement)
- ❌ NO implementing: cascadeCancelFinal, handleComponentScrapped (future)
- ❌ NO tray validation logic yet

### Guardrail 5: Database Safety
- ✅ Use prepared statements
- ✅ Use transactions for multi-step operations
- ❌ NO schema changes
- ❌ NO creating new tables

---

## 🧪 Testing Requirements

### Unit Tests

**File:** `tests/Unit/FailureRecoveryServiceTest.php` (new)

**Test Cases:**
1. `testHandleQcFailScrapsToken()` - Verify scrap
2. `testHandleQcFailSpawnsReplacement()` - Verify spawn
3. `testHandleQcFailLinksTokens()` - Verify links
4. `testReplacementTokenHasCorrectAttributes()` - Verify clone
5. `testReplacementTokenStatusReady()` - Verify status
6. `testValidateTrayStubAlwaysPass()` - Stub test

**Run Command:**
```bash
vendor/bin/phpunit tests/Unit/FailureRecoveryServiceTest.php --testdox
```

**Expected:** All tests pass (6/6)

### Manual Testing

**Test Scenario 1: QC Fail on Piece Token**
1. Create piece token, start work
2. Execute QC fail with reason
3. Check: Original token scrapped
4. Check: Replacement token created
5. Check: Links correct (replacement_token_id, parent_scrapped_token_id) ✅

**Test Scenario 2: QC Fail on Component Token**
1. Create component token (with parent_token_id, parallel_group_id)
2. Execute QC fail
3. Check: Replacement preserves parent/parallel info ✅

**Test Scenario 3: Multiple Failures**
1. QC fail token A → replacement A1
2. QC fail token A1 → replacement A2
3. Check: Chain preserved ✅

---

## 📦 Deliverables

### 1. Source Files

- ✅ `source/BGERP/Dag/FailureRecoveryService.php` (new)
  - handleQcFail (~60 lines)
  - spawnReplacementToken (~50 lines)
  - validateTray stub (~15 lines)
  - helpers (~30 lines)
  - Total: ~155-180 lines

### 2. Test Files

- ✅ `tests/Unit/FailureRecoveryServiceTest.php` (new)
  - 6 test cases
  - ~120-150 lines

### 3. Behavior Integration

- ✅ Update `BehaviorExecutionService::handleQcFail()`
  - Call `FailureRecoveryService::handleQcFail()`
  - ~10 lines modified

### 4. Results Document

- ✅ `docs/super_dag/tasks/results/task27.9_results.md`

---

## ✅ Definition of Done

- [ ] FailureRecoveryService class created
- [ ] handleQcFail() implemented and tested
- [ ] spawnReplacementToken() works correctly
- [ ] Token links correct (replacement_token_id, parent_scrapped_token_id)
- [ ] validateTray() stub exists
- [ ] BehaviorExecutionService integrated (calls recovery service)
- [ ] Unit tests pass (6/6)
- [ ] Manual testing pass (3 scenarios)
- [ ] Results document created

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO implementing validateTray logic (Task 27.10)
- ❌ NO implementing cascadeCancelFinal (future)
- ❌ NO implementing handleComponentScrapped full logic (future)
- ❌ NO supervisor override mechanisms (future)
- ❌ NO UI changes
- ❌ NO database schema changes
- ❌ NO creating tray tables
- ❌ NO touching TokenLifecycleService (calls it only)

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 7 (Failure modes)
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Section 13 (Failure scenarios)

**Code:**
- `source/BGERP/Dag/TokenLifecycleService.php` - Service to call
- `source/BGERP/Dag/BehaviorExecutionService.php` - Integration point

---

**END OF TASK**

