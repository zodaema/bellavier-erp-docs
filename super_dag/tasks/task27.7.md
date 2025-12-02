# Task 27.7 — Design ParallelMachineCoordinator API for Split/Merge

**Phase:** 3 - Parallel / Split-Merge Integration  
**Priority:** 🔴 BLOCKER  
**Estimated Effort:** 6-8 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 3 - Parallel Execution Integration  
**Dependencies:** Task 27.6 (Component hooks in Behavior)  
**Blocks:** Task 27.8 (completeNode for all node types)

---

## 🎯 Goal

ออกแบบ / ปรับ `ParallelMachineCoordinator` ให้เป็น API ตาม spec สำหรับ split/merge operations

**Key Principle:**
- ✅ ParallelMachineCoordinator = Owner of split/merge logic
- ❌ TokenLifecycleService ไม่ implement split/merge เอง (delegates to coordinator)
- ❌ BehaviorExecutionService ไม่รู้เรื่อง split/merge (calls lifecycle only)

---

## 📋 Requirements

### 1. Review Existing ParallelMachineCoordinator

**File:** `source/BGERP/Dag/ParallelMachineCoordinator.php`

**Current Status:** Check what exists
- ตรวจว่ามี methods อะไรอยู่แล้ว
- ตรวจว่า handle parallel execution ยังไง
- ตรวจว่าใช้ `parallel_group_id`, `parallel_branch_key` หรือยัง

### 2. Add/Update Method: handleSplit($parentTokenId, $nodeId)

```php
/**
 * Handle parallel split node
 * Spawns component tokens from parent token
 * 
 * @param int $parentTokenId Parent token ID (piece token)
 * @param int $nodeId Split node ID
 * @return array ['ok' => bool, 'spawned_tokens' => array, 'parallel_group_id' => int]
 */
public function handleSplit(int $parentTokenId, int $nodeId): array
{
    // 1. Validate node is split node
    $node = $this->fetchNode($nodeId);
    if ($node['is_parallel_split'] !== 1) {
        return ['ok' => false, 'error' => 'Node is not a parallel split node'];
    }
    
    // 2. Get outgoing edges
    $edges = $this->getOutgoingEdges($nodeId);
    if (count($edges) < 2) {
        return ['ok' => false, 'error' => 'Split node must have at least 2 outgoing edges'];
    }
    
    // 3. Generate parallel group ID
    $parallelGroupId = $this->generateParallelGroupId();
    
    // 4. Spawn component token for each edge
    $spawnedTokens = [];
    
    foreach ($edges as $i => $edge) {
        $targetNode = $this->fetchNode($edge['to_node_id']);
        
        // Component code from target node (or stub)
        $componentCode = $targetNode['produces_component'] ?? "COMP_" . ($i + 1);
        
        $newTokenId = $this->spawnComponentToken([
            'parent_token_id' => $parentTokenId,
            'parallel_group_id' => $parallelGroupId,
            'parallel_branch_key' => ($i + 1),
            'component_code' => $componentCode,
            'current_node_id' => $edge['to_node_id'],
            'status' => 'ready'
        ]);
        
        $spawnedTokens[] = [
            'token_id' => $newTokenId,
            'component_code' => $componentCode,
            'target_node_id' => $edge['to_node_id']
        ];
    }
    
    // 5. Log
    error_log(sprintf(
        "[ParallelCoordinator] Split: parent=%d, group=%d, spawned=%d tokens",
        $parentTokenId, $parallelGroupId, count($spawnedTokens)
    ));
    
    return [
        'ok' => true,
        'effect' => 'parallel_split',
        'parallel_group_id' => $parallelGroupId,
        'spawned_tokens' => $spawnedTokens
    ];
}
```

### 3. Add Method: spawnComponentToken(array $data)

```php
/**
 * Spawn component token
 * 
 * @param array $data Token data
 * @return int New token ID
 */
private function spawnComponentToken(array $data): int
{
    $stmt = $this->db->prepare("
        INSERT INTO flow_token (
            id_instance,
            token_type,
            parent_token_id,
            parallel_group_id,
            parallel_branch_key,
            current_node_id,
            status,
            metadata,
            spawned_at
        ) VALUES (?, 'component', ?, ?, ?, ?, ?, ?, NOW())
    ");
    
    // Get id_instance from parent token
    $parent = $this->fetchToken($data['parent_token_id']);
    $idInstance = $parent['id_instance'];
    
    $metadata = json_encode(['component_code' => $data['component_code']]);
    
    $stmt->bind_param(
        'iiiiss',
        $idInstance,
        $data['parent_token_id'],
        $data['parallel_group_id'],
        $data['parallel_branch_key'],
        $data['current_node_id'],
        $data['status'],
        $metadata
    );
    
    $stmt->execute();
    
    return $this->db->insert_id;
}
```

### 4. Add/Update Method: handleMerge($componentTokenId, $nodeId)

```php
/**
 * Handle merge node
 * Validates all components complete, re-activates parent
 * 
 * @param int $componentTokenId Component token ID (last to complete)
 * @param int $nodeId Merge node ID
 * @return array ['ok' => bool, 'effect' => string, 'parent_token_id' => int]
 */
public function handleMerge(int $componentTokenId, int $nodeId): array
{
    // 1. Validate node is merge node
    $node = $this->fetchNode($nodeId);
    if ($node['is_merge_node'] !== 1) {
        return ['ok' => false, 'error' => 'Node is not a merge node'];
    }
    
    // 2. Get component token
    $componentToken = $this->fetchToken($componentTokenId);
    if ($componentToken['token_type'] !== 'component') {
        return ['ok' => false, 'error' => 'Merge expects component token'];
    }
    
    $parentTokenId = $componentToken['parent_token_id'];
    $parallelGroupId = $componentToken['parallel_group_id'];
    
    // 3. Check if all siblings complete
    $allComplete = $this->checkAllComponentsComplete($parallelGroupId, $nodeId);
    
    if (!$allComplete) {
        // Not all components ready yet
        return [
            'ok' => true,
            'effect' => 'merge_waiting',
            'message' => 'Waiting for other components',
            'parent_token_id' => $parentTokenId
        ];
    }
    
    // 4. All complete → merge
    // 4a. Aggregate component data (call ComponentFlowService)
    require_once __DIR__ . '/ComponentFlowService.php';
    $componentService = new \BGERP\Dag\ComponentFlowService($this->db);
    $componentTimes = $componentService->aggregateComponentTimes($parentTokenId);
    
    // 4b. Update parent token metadata
    $stmt = $this->db->prepare("
        UPDATE flow_token 
        SET metadata = JSON_MERGE_PATCH(metadata, ?)
        WHERE id_token = ?
    ");
    $stmt->bind_param('si', json_encode($componentTimes), $parentTokenId);
    $stmt->execute();
    
    // 4c. Mark component tokens as merged
    $this->markComponentsAsMerged($parentTokenId);
    
    // 5. Log
    error_log(sprintf(
        "[ParallelCoordinator] Merge: parent=%d, group=%d, all components complete",
        $parentTokenId, $parallelGroupId
    ));
    
    return [
        'ok' => true,
        'effect' => 'merge_complete',
        'parent_token_id' => $parentTokenId,
        'component_times' => $componentTimes
    ];
}
```

### 5. Add Helper Methods

```php
private function generateParallelGroupId(): int
{
    // Simple: use timestamp + random
    return (int)(microtime(true) * 1000) + rand(1000, 9999);
}

private function getOutgoingEdges(int $nodeId): array
{
    $stmt = $this->db->prepare("
        SELECT * FROM routing_edge 
        WHERE from_node_id = ? 
        ORDER BY id_edge ASC
    ");
    $stmt->bind_param('i', $nodeId);
    $stmt->execute();
    return $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
}

private function fetchNode(int $nodeId): ?array
{
    $stmt = $this->db->prepare("SELECT * FROM routing_node WHERE id_node = ?");
    $stmt->bind_param('i', $nodeId);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc();
}

private function checkAllComponentsComplete(int $parallelGroupId, int $nodeId): bool
{
    // Check if all components in group reached this node with status completed/active
    $stmt = $this->db->prepare("
        SELECT COUNT(*) as total,
               SUM(CASE WHEN current_node_id = ? OR status = 'completed' THEN 1 ELSE 0 END) as at_node
        FROM flow_token
        WHERE parallel_group_id = ?
          AND token_type = 'component'
          AND status NOT IN ('scrapped')
    ");
    $stmt->bind_param('ii', $nodeId, $parallelGroupId);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    
    return $result['total'] > 0 && $result['total'] === $result['at_node'];
}

private function markComponentsAsMerged(int $parentTokenId): void
{
    $stmt = $this->db->prepare("
        UPDATE flow_token 
        SET status = 'completed',
            metadata = JSON_SET(metadata, '$.merged_at', NOW(), '$.merged_into_token_id', ?)
        WHERE parent_token_id = ?
          AND token_type = 'component'
          AND status != 'scrapped'
    ");
    $stmt->bind_param('ii', $parentTokenId, $parentTokenId);
    $stmt->execute();
}
```

---

## 🚧 Guardrails (MUST FOLLOW)

### Guardrail 1: Coordinator Responsibility Only
- ✅ This service handles split/merge coordination ONLY
- ❌ NO updating token status (ให้ TokenLifecycleService ทำ)
- ❌ NO calling BehaviorExecutionService (circular dependency)
- ✅ CAN call ComponentFlowService (for aggregation)

### Guardrail 2: Database Safety
- ✅ Use prepared statements
- ✅ Use transactions for multi-step operations (spawn multiple tokens)
- ❌ NO schema changes
- ❌ NO touching other tables (sessions, events, etc.)

### Guardrail 3: Fail Gracefully
- ✅ Validate node type before processing
- ✅ Validate edge count (split ≥ 2, merge ≥ 2)
- ✅ Return error if validation fails (ไม่ throw exception)
- ✅ Log all operations

### Guardrail 4: Phase 3 Scope
- ✅ Implement: handleSplit, handleMerge, helper methods
- ❌ NO machine allocation logic (existing coordinator may have - keep it)
- ❌ NO UI changes
- ❌ NO touching BehaviorExecutionService (Task 27.8 will integrate)

### Guardrail 5: Component Code Handling
- ✅ Read from `routing_node.produces_component` (if exists)
- ✅ Fallback to stub: "COMP_1", "COMP_2" (if field missing)
- ❌ NO requiring produces_component field to exist (ยังไม่มี schema)
- ✅ Use metadata JSON for component_code (temporary)

---

## 🧪 Testing Requirements

### Unit Tests

**File:** `tests/Unit/ParallelMachineCoordinatorTest.php` (new or update existing)

**Test Cases:**
1. `testHandleSplitCreatesComponentTokens()` - Verify spawn
2. `testHandleSplitSetsParallelGroupId()` - Verify group ID
3. `testHandleSplitRequiresTwoEdges()` - Validation
4. `testHandleMergeWaitsForAllComponents()` - Merge waiting
5. `testHandleMergeReActivatesParentWhenComplete()` - Merge complete
6. `testHandleMergeAggregatesComponentTimes()` - Aggregation
7. `testMarkComponentsAsMerged()` - Component status update

**Run Command:**
```bash
vendor/bin/phpunit tests/Unit/ParallelMachineCoordinatorTest.php --testdox
```

**Expected:** All tests pass (7/7)

### Manual Testing

**Test Scenario 1: Split Node**
1. Create final token at split node
2. Call `handleSplit($tokenId, $splitNodeId)`
3. Check: 2-3 component tokens created
4. Check: `parallel_group_id` same for all
5. Check: `parallel_branch_key` = 1, 2, 3
6. Check: `parent_token_id` = final token ✅

**Test Scenario 2: Merge Node (Not Ready)**
1. Component token A completes at merge node
2. Call `handleMerge($tokenA, $mergeNodeId)`
3. Should return `merge_waiting` (other components not ready) ✅

**Test Scenario 3: Merge Node (Ready)**
1. All component tokens complete at merge node
2. Call `handleMerge($tokenLast, $mergeNodeId)`
3. Check: Returns `merge_complete`
4. Check: Parent token metadata has `component_times`
5. Check: Component tokens marked as merged ✅

---

## 📦 Deliverables

### 1. Modified/Created Files

- ✅ `source/BGERP/Dag/ParallelMachineCoordinator.php`
  - Add/update `handleSplit()` method (~80-100 lines)
  - Add/update `handleMerge()` method (~80-100 lines)
  - Add helper methods (~100-120 lines)
  - Total: ~260-320 lines added/modified

### 2. Test Files

- ✅ `tests/Unit/ParallelMachineCoordinatorTest.php` (new or update)
  - 7 test cases minimum
  - ~200-300 lines

### 3. Results Document

- ✅ `docs/super_dag/tasks/results/task27.7_results.md`

---

## ✅ Definition of Done

- [ ] handleSplit() implemented and tested
- [ ] handleMerge() implemented and tested
- [ ] Component token spawning works
- [ ] parallel_group_id, parallel_branch_key set correctly
- [ ] Merge validation works (wait for all components)
- [ ] Component times aggregation works
- [ ] Unit tests pass (7/7)
- [ ] Manual testing pass (3 scenarios)
- [ ] No database schema changes required
- [ ] Results document created

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO integrating with TokenLifecycleService yet (Task 27.8)
- ❌ NO integrating with BehaviorExecutionService
- ❌ NO database schema changes (produces_component field)
- ❌ NO UI changes
- ❌ NO creating new tables
- ❌ NO touching existing behavior handlers
- ❌ NO implementing full component model (Task 5 - future)
- ❌ NO creating new .md documentation

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Section 4, 5 (Split/Merge)
- `docs/super_dag/02-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - Section 3, 4 (Spawn/Merge patterns)

**Existing Code:**
- `source/BGERP/Dag/ParallelMachineCoordinator.php` - File to modify
- `source/BGERP/Dag/ComponentFlowService.php` - For aggregation (from Task 27.5)

---

## 📝 Results Template

```markdown
# Task 27.7 Results — ParallelMachineCoordinator API

**Completed:** YYYY-MM-DD  
**Duration:** X hours  
**Status:** ✅ Complete

## Files Modified
- `source/BGERP/Dag/ParallelMachineCoordinator.php` (+XXX lines)

## Files Created
- `tests/Unit/ParallelMachineCoordinatorTest.php` (XXX lines, X tests)

## Test Results
```
vendor/bin/phpunit tests/Unit/ParallelMachineCoordinatorTest.php --testdox
✅ 7/7 tests passed
```

## Manual Testing
- ✅ Split creates component tokens correctly
- ✅ Merge waits for all components
- ✅ Merge completes when all ready
- ✅ Component times aggregated

## Issues Encountered
- (List any issues)

## Next Steps
- Proceed to Task 27.8 (Integrate split/merge with TokenLifecycleService)
```

---

**END OF TASK**

