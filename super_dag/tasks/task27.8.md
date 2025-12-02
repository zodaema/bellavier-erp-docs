# Task 27.8 — Implement completeNode() for All Node Types (Split/Merge Integration)

**Phase:** 3 - Parallel / Split-Merge Integration  
**Priority:** 🔴 BLOCKER  
**Estimated Effort:** 6-8 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 3 - Parallel Execution Integration  
**Dependencies:** Task 27.7 (ParallelMachineCoordinator API ready)  
**Blocks:** Task 27.9 (Failure recovery)

---

## 🎯 Goal

ทำ `TokenLifecycleService::completeNode()` ให้รองรับ node type ทั้งหมด: normal, split, merge, end

**Key Principle:**
- ✅ TokenLifecycleService = Single entry point สำหรับ complete node
- ✅ Internally delegates to ParallelMachineCoordinator for split/merge
- ❌ Behavior ไม่ต้องรู้ node type (เรียก completeNode เสมอ)

---

## 📋 Requirements

### 1. Update completeNode() Method

**File:** `source/BGERP/Dag/TokenLifecycleService.php`

**Current (Phase 1):**
- Handles normal/end nodes only
- Returns error for split/merge

**Target (Phase 3):**
- Handles ALL node types: normal, split, merge, end

**Updated Implementation:**

```php
/**
 * Complete node work
 * Handles routing based on node type
 * 
 * Phase 3: All node types (normal, split, merge, end)
 * 
 * @param int $tokenId
 * @param int $nodeId
 * @return array Result with routing info
 */
public function completeNode(int $tokenId, int $nodeId): array
{
    // 1. Fetch node
    $node = $this->fetchNode($nodeId);
    if (!$node) {
        return ['ok' => false, 'error' => 'Node not found'];
    }
    
    // 2. Fetch token
    $token = $this->fetchToken($tokenId);
    if (!$token) {
        return ['ok' => false, 'error' => 'Token not found'];
    }
    
    // 3. Validate token status
    if ($token['status'] !== 'active') {
        return ['ok' => false, 'error' => "Cannot complete: token status is {$token['status']}"];
    }
    
    // 4. Route based on node type
    if ($node['is_parallel_split'] === 1) {
        return $this->completeSplitNode($tokenId, $nodeId, $node);
    } elseif ($node['is_merge_node'] === 1) {
        return $this->completeMergeNode($tokenId, $nodeId, $node);
    } elseif ($this->isEndNode($nodeId)) {
        return $this->completeEndNode($tokenId);
    } else {
        return $this->completeNormalNode($tokenId, $nodeId);
    }
}
```

### 2. Implement completeSplitNode()

```php
/**
 * Complete split node
 * Delegates to ParallelMachineCoordinator for component spawn
 * 
 * @param int $tokenId Parent token
 * @param int $nodeId Split node
 * @param array $node Node data
 * @return array
 */
private function completeSplitNode(int $tokenId, int $nodeId, array $node): array
{
    // 1. Call coordinator to spawn components
    require_once __DIR__ . '/ParallelMachineCoordinator.php';
    $coordinator = new \BGERP\Dag\ParallelMachineCoordinator($this->db, $this->org);
    
    $splitResult = $coordinator->handleSplit($tokenId, $nodeId);
    
    if (!$splitResult['ok']) {
        return $splitResult; // Return error from coordinator
    }
    
    // 2. Update parent token status: active → waiting
    $this->updateTokenStatus($tokenId, 'waiting');
    
    // 3. Emit canonical event
    $this->emitEvent('TOKEN_SPLIT', [
        'token_id' => $tokenId,
        'node_id' => $nodeId,
        'parallel_group_id' => $splitResult['parallel_group_id'],
        'spawned_count' => count($splitResult['spawned_tokens'])
    ]);
    
    return [
        'ok' => true,
        'effect' => 'token_split',
        'status' => 'waiting',
        'parallel_group_id' => $splitResult['parallel_group_id'],
        'spawned_tokens' => $splitResult['spawned_tokens']
    ];
}
```

### 3. Implement completeMergeNode()

```php
/**
 * Complete merge node
 * Delegates to ParallelMachineCoordinator for merge validation
 * Re-activates parent token if all components complete
 * 
 * @param int $tokenId Component token (last to complete)
 * @param int $nodeId Merge node
 * @param array $node Node data
 * @return array
 */
private function completeMergeNode(int $tokenId, int $nodeId, array $node): array
{
    // 1. Call coordinator to check merge readiness
    require_once __DIR__ . '/ParallelMachineCoordinator.php';
    $coordinator = new \BGERP\Dag\ParallelMachineCoordinator($this->db, $this->org);
    
    $mergeResult = $coordinator->handleMerge($tokenId, $nodeId);
    
    if (!$mergeResult['ok']) {
        return $mergeResult; // Return error
    }
    
    // 2. Check if merge complete or still waiting
    if ($mergeResult['effect'] === 'merge_waiting') {
        // Other components not ready yet
        return $mergeResult;
    }
    
    // 3. Merge complete → re-activate parent token
    $parentTokenId = $mergeResult['parent_token_id'];
    
    // Update parent: waiting → active, move to merge node
    $this->updateToken($parentTokenId, [
        'status' => 'active',
        'current_node_id' => $nodeId
    ]);
    
    // 4. Emit canonical event
    $this->emitEvent('TOKEN_MERGE', [
        'parent_token_id' => $parentTokenId,
        'merge_node_id' => $nodeId,
        'component_times' => $mergeResult['component_times']
    ]);
    
    return [
        'ok' => true,
        'effect' => 'merge_complete',
        'parent_token_id' => $parentTokenId,
        'status' => 'active'
    ];
}
```

### 4. Add Helper: updateToken()

```php
/**
 * Update token fields
 * 
 * @param int $tokenId
 * @param array $updates ['status' => '...', 'current_node_id' => X, ...]
 */
private function updateToken(int $tokenId, array $updates): void
{
    $fields = [];
    $values = [];
    $types = '';
    
    foreach ($updates as $field => $value) {
        $fields[] = "`{$field}` = ?";
        $values[] = $value;
        $types .= is_int($value) ? 'i' : 's';
    }
    
    $values[] = $tokenId;
    $types .= 'i';
    
    $sql = "UPDATE flow_token SET " . implode(', ', $fields) . " WHERE id_token = ?";
    $stmt = $this->db->prepare($sql);
    $stmt->bind_param($types, ...$values);
    $stmt->execute();
}
```

---

## 🚧 Guardrails (MUST FOLLOW)

### Guardrail 1: Single Entry Point
- ✅ Behavior ALWAYS calls `completeNode($tokenId, $nodeId)`
- ✅ completeNode internally routes by node type
- ❌ Behavior ไม่เช็ค node type เอง
- ❌ Behavior ไม่เรียก completeSplitNode/completeMergeNode ตรงๆ

### Guardrail 2: Delegation Pattern
- ✅ Split/merge logic → ParallelMachineCoordinator (owner)
- ✅ TokenLifecycleService = router + status updater
- ❌ NO implementing split/merge business logic in lifecycle service
- ✅ Keep lifecycle service focused on status transitions

### Guardrail 3: Status Transitions
- ✅ Split: `active` → `waiting` (parent token)
- ✅ Merge: `waiting` → `active` (parent token)
- ✅ Normal: `active` → `active` (move to next)
- ✅ End: `active` → `completed`
- ❌ NO other transitions

### Guardrail 4: Error Handling
- ✅ Wrap coordinator calls in try-catch
- ✅ Return errors gracefully
- ❌ NO silent failures
- ✅ Log all operations

### Guardrail 5: Scope Limitation
- ✅ Modify ONLY `TokenLifecycleService.php`
- ❌ NO touching BehaviorExecutionService (already done)
- ❌ NO touching ParallelMachineCoordinator logic (Task 27.7 did it)
- ❌ NO UI changes
- ❌ NO database schema changes

---

## 🧪 Testing Requirements

### Integration Test

**File:** `tests/Integration/ParallelFlowIntegrationTest.php` (new)

**Test: End-to-End Split-Merge Flow**

```php
public function testSplitMergeFlow()
{
    // 1. Create final token at split node
    $finalTokenId = createTestToken(['token_type' => 'piece', 'status' => 'active']);
    
    // 2. Complete at split node
    $lifecycleService = new TokenLifecycleService($this->db);
    $splitResult = $lifecycleService->completeNode($finalTokenId, $splitNodeId);
    
    // Assert: Split happened
    $this->assertTrue($splitResult['ok']);
    $this->assertEquals('token_split', $splitResult['effect']);
    
    // Assert: Parent token waiting
    $parent = fetchToken($finalTokenId);
    $this->assertEquals('waiting', $parent['status']);
    
    // Assert: Component tokens created
    $components = fetchComponentTokens($finalTokenId);
    $this->assertCount(3, $components); // 3 components
    
    // 3. Complete component tokens at merge node
    foreach ($components as $i => $comp) {
        // Simulate work: set status active
        updateToken($comp['id_token'], ['status' => 'active', 'current_node_id' => $mergeNodeId]);
        
        // Complete at merge
        $mergeResult = $lifecycleService->completeNode($comp['id_token'], $mergeNodeId);
        
        if ($i < count($components) - 1) {
            // Not last → should wait
            $this->assertEquals('merge_waiting', $mergeResult['effect']);
        } else {
            // Last component → should merge
            $this->assertEquals('merge_complete', $mergeResult['effect']);
        }
    }
    
    // Assert: Parent token re-activated
    $parent = fetchToken($finalTokenId);
    $this->assertEquals('active', $parent['status']);
    $this->assertEquals($mergeNodeId, $parent['current_node_id']);
}
```

### Manual Testing

**Full Flow Test:**
1. Create test graph with split → [3 branches] → merge
2. Create final token
3. Complete at split → verify 3 component tokens spawned
4. Complete components one by one → verify merge waiting
5. Complete last component → verify parent re-activated
6. Check metadata has component_times ✅

---

## 📦 Deliverables

### 1. Modified Files

- ✅ `source/BGERP/Dag/TokenLifecycleService.php`
  - Update `completeNode()` (~40 lines)
  - Add `completeSplitNode()` (~50 lines)
  - Add `completeMergeNode()` (~60 lines)
  - Add `updateToken()` helper (~20 lines)
  - Total: ~170 lines added/modified

### 2. Test Files

- ✅ `tests/Integration/ParallelFlowIntegrationTest.php` (new)
  - 1 comprehensive integration test
  - ~100-150 lines

### 3. Results Document

- ✅ `docs/super_dag/tasks/results/task27.8_results.md`

---

## ✅ Definition of Done

- [ ] completeNode() handles all node types
- [ ] completeSplitNode() delegates to coordinator, updates parent status
- [ ] completeMergeNode() delegates to coordinator, re-activates parent
- [ ] Integration test passes (split → merge flow)
- [ ] Manual testing pass (full flow)
- [ ] Canonical events emitted
- [ ] No regressions (normal/end nodes still work)
- [ ] Behavior Layer now supports parallel flow (via lifecycle)
- [ ] Results document created

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO implementing coordinator logic (Task 27.7 did it)
- ❌ NO touching BehaviorExecutionService
- ❌ NO UI changes
- ❌ NO database schema changes (produces_component field)
- ❌ NO creating component tables
- ❌ NO implementing full component model
- ❌ NO touching Work Queue
- ❌ NO creating new .md documentation

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 4.1 (Single entry point)
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Section 4, 5 (Split/Merge)
- `docs/super_dag/02-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - Section 3, 4 (Patterns)

**Code:**
- `source/BGERP/Dag/TokenLifecycleService.php` - File to modify
- `source/BGERP/Dag/ParallelMachineCoordinator.php` - Service to call (from Task 27.7)

---

## 📝 Results Template

```markdown
# Task 27.8 Results — completeNode() for All Node Types

**Completed:** YYYY-MM-DD  
**Duration:** X hours  
**Status:** ✅ Complete

## Files Modified
- `source/BGERP/Dag/TokenLifecycleService.php` (+XXX lines)

## Files Created
- `tests/Integration/ParallelFlowIntegrationTest.php` (XXX lines)

## Test Results
```
vendor/bin/phpunit tests/Integration/ParallelFlowIntegrationTest.php --testdox
✅ Integration test passed
```

## Manual Testing
- ✅ Split node spawns components
- ✅ Parent token set to waiting
- ✅ Merge node waits for all components
- ✅ Parent re-activated when merge complete
- ✅ Component times aggregated

## Issues Encountered
- (List any issues)

## Breakthrough
🎉 Component Parallel Flow now works end-to-end!

## Next Steps
- Proceed to Task 27.9 (Failure Recovery)
```

---

**END OF TASK**

