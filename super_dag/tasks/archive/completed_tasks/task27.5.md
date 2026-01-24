# Task 27.5 — Create ComponentFlowService (Stub for Component Metadata)

**Phase:** 2 - Component Flow Integration  
**Priority:** 🔴 BLOCKER  
**Estimated Effort:** 4-5 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 2 - Component Flow Integration  
**Dependencies:** Task 27.4 (Validation matrix implemented) ✅ **COMPLETE**  
**Blocks:** Task 27.6 (Component hooks in Behavior)

---

## 🚨 **CRITICAL: Namespace Change from Original Spec**

**⚠️ IMPORTANT CHANGE:**
```diff
- Location: source/BGERP/Dag/ComponentFlowService.php  ❌ OLD (ผิด)
+ Location: source/BGERP/Service/ComponentFlowService.php  ✅ NEW (ถูก)

- Namespace: BGERP\Dag  ❌ OLD
+ Namespace: BGERP\Service  ✅ NEW
```

**Rationale:**
- Lesson from Task 27.2: Services live in BGERP\Service (not BGERP\Dag)
- ComponentFlowService = domain service (owner of component metadata)
- BehaviorExecutionService = orchestrator (lives in BGERP\Dag, calls services)
- Consistency: TokenLifecycleService also in BGERP\Service

**This is NOT a mistake - it's an architectural correction!**

---

## 📋 **Quick Summary (TL;DR)**

**What:** Create ComponentFlowService (stub) in `BGERP\Service` namespace  
**Why:** Owner of component metadata (component_code, times, worker info)  
**Scope:** Phase 2 = Stub only (4 methods return safe defaults)  
**Phase 3:** Full implementation (split/merge, parallel group validation)  
**Namespace:** ⚠️ `BGERP\Service` (NOT BGERP\Dag - learned from Task 27.2)  
**Integration:** Task 27.6 will add calls from BehaviorExecutionService

---

## ⚠️ **Context from Phase 1 (COMPLETE)**

**Phase 1 Achievements (Task 27.2-27.4):**
- ✅ TokenLifecycleService exists (`BGERP\Service\TokenLifecycleService`)
- ✅ BehaviorExecutionService refactored (`BGERP\Dag\BehaviorExecutionService`)
- ✅ Validation matrix implemented (13 behaviors × 3 token types)
- ✅ Tests: 53 tests passing (10 lifecycle + 43 validation)

**Why ComponentFlowService Now:**
- Phase 2 focus = Component flow awareness
- Need **owner** for component metadata (component_code, times, worker info)
- Behavior shouldn't implement component logic directly

**Service Ownership Established:**
```
Token Status       → TokenLifecycleService (BGERP\Service) ✅ Phase 1
Component Metadata → ComponentFlowService (BGERP\Service) 📋 Phase 2 (this task)
Behavior Orchestration → BehaviorExecutionService (BGERP\Dag) ✅ Phase 1
```

**Integration Strategy:**
- Task 27.5 (this): Create ComponentFlowService (stub)
- Task 27.6 (next): BehaviorExecutionService calls ComponentFlowService
- Phase 3: Implement split/merge logic

---

## 🎯 Goal

สร้าง `ComponentFlowService` เป็น **owner ของ component metadata logic**

**Key Principle:**
- ✅ ComponentFlowService = Owner of component_code, component_times, component metadata
- ❌ Behavior ไม่ทำ component logic เอง (เรียก service)
- ✅ **Use BGERP\Service namespace** (consistency with TokenLifecycleService)

**⚠️ PHASE 2 SCOPE:** Stub methods only (ยังไม่ทำ split/merge จริง)

---

## 📋 Requirements

### 0. Prerequisites - Database Schema Check ⚠️

**BEFORE starting, verify database schema:**

```sql
-- Check if metadata column exists
SHOW COLUMNS FROM flow_token LIKE 'metadata';
-- Expected: metadata (JSON or TEXT type)

-- If metadata doesn't exist, check alternatives:
SHOW COLUMNS FROM flow_token LIKE '%data%';
SHOW COLUMNS FROM flow_token LIKE '%note%';
```

**Fallback Strategy:**
- ✅ If metadata exists → use it
- ⚠️ If metadata doesn't exist → use alternative field (component_data, notes, custom_json)
- 📝 If no suitable field → log only (skip UPDATE, just error_log for Phase 2)

### 1. Create ComponentFlowService Class

**Location:** `source/BGERP/Service/ComponentFlowService.php` ⚠️ **IMPORTANT: BGERP\Service NOT BGERP\Dag**

**Namespace:** `BGERP\Service` (consistency with TokenLifecycleService)

**Rationale (from Task 27.2):**
- ✅ Services = domain logic owners → live in BGERP\Service
- ✅ Orchestrators = workflow managers → live in BGERP\Dag
- ✅ ComponentFlowService = owner of component metadata → BGERP\Service
- ✅ BehaviorExecutionService = orchestrator → BGERP\Dag (calls ComponentFlowService)

**Dependencies:**
- `mysqli` - Database connection
- `BGERP\Helper\TimeHelper` - Time utilities (if needed)

### 2. Constructor & Basic Structure

```php
<?php
namespace BGERP\Service;

use mysqli;

class ComponentFlowService
{
    private mysqli $db;
    
    /**
     * Constructor
     * 
     * @param mysqli $db Database connection
     */
    public function __construct(mysqli $db)
    {
        $this->db = $db;
    }
    
    // Methods below...
}
```

### 3. Implement Stub Methods

#### 3.1 onComponentCompleted($tokenId, array $context)

```php
/**
 * Record component completion
 * Updates component metadata after work completed
 * 
 * Phase 2: Basic metadata update only
 * 
 * @param int $tokenId Component token ID
 * @param array $context ['component_code', 'duration_ms', 'worker_id', 'worker_name', 'node_id']
 */
public function onComponentCompleted(int $tokenId, array $context): void
{
    // Validate token type
    $token = $this->fetchToken($tokenId);
    if ($token['token_type'] !== 'component') {
        error_log("[ComponentFlowService] onComponentCompleted called on non-component token");
        return; // Fail gracefully
    }
    
    // Update component metadata
    $metadata = [
        'component_completed_at' => TimeHelper::toMysql(TimeHelper::now()),
        'component_time_ms' => $context['duration_ms'] ?? 0,
        'worker_id' => $context['worker_id'] ?? null,
        'worker_name' => $context['worker_name'] ?? null,
        'completed_node_id' => $context['node_id'] ?? null
    ];
    
    $stmt = $this->db->prepare("
        UPDATE flow_token 
        SET metadata = JSON_MERGE_PATCH(metadata, ?)
        WHERE id_token = ?
    ");
    $stmt->bind_param('si', json_encode($metadata), $tokenId);
    $stmt->execute();
    
    error_log("[ComponentFlowService] Component {$tokenId} completed: " . ($context['component_code'] ?? 'unknown'));
}
```

**⚠️ Implementation Note:**
- Check if `flow_token.metadata` column exists
- If exists: Use JSON_MERGE_PATCH
- If not: Use alternative field or skip UPDATE (log only)

#### 3.2 isReadyForAssembly($finalTokenId)

```php
/**
 * Check if final token ready for assembly
 * Validates all required components complete
 * 
 * Phase 2: Stub implementation (returns dummy data)
 * Phase 3: Real validation with parallel_group_id
 * 
 * @param int $finalTokenId Final token ID
 * @return array ['ready' => bool, 'missing' => array]
 */
public function isReadyForAssembly(int $finalTokenId): array
{
    // Phase 2: Stub - always return ready
    // Phase 3: Check actual component tokens
    
    error_log("[ComponentFlowService] isReadyForAssembly stub called for token {$finalTokenId}");
    
    return [
        'ready' => true,
        'missing' => [],
        'note' => 'Phase 2 stub - not validating components yet'
    ];
}
```

#### 3.3 getSiblingStatus($parallelGroupId)

```php
/**
 * Get status of sibling components in parallel group
 * For UI display
 * 
 * Phase 2: Stub implementation (returns empty array)
 * Phase 3: Real query with parallel_group_id
 * 
 * @param int $parallelGroupId
 * @return array List of component status
 */
public function getSiblingStatus(int $parallelGroupId): array
{
    // Phase 2: Stub - return empty
    // Phase 3: Query flow_token WHERE parallel_group_id = ?
    
    error_log("[ComponentFlowService] getSiblingStatus stub called for group {$parallelGroupId}");
    
    return [
        // Empty for now
        // Phase 3 will return:
        // [
        //     ['component_code' => 'BODY', 'status' => 'active', 'worker_name' => 'Alice'],
        //     ['component_code' => 'FLAP', 'status' => 'completed', 'worker_name' => 'Bob'],
        // ]
    ];
}
```

#### 3.4 aggregateComponentTimes($finalTokenId)

```php
/**
 * Aggregate component times for merge
 * 
 * Phase 2: Stub implementation
 * Phase 3: Real aggregation
 * 
 * @param int $finalTokenId
 * @return array Component times summary
 */
public function aggregateComponentTimes(int $finalTokenId): array
{
    // Phase 2: Stub
    error_log("[ComponentFlowService] aggregateComponentTimes stub called for token {$finalTokenId}");
    
    return [
        'component_times' => [],
        'max_component_time' => 0,
        'total_component_time' => 0,
        'note' => 'Phase 2 stub'
    ];
}
```

#### 3.5 Helper: fetchToken($tokenId)

**Note:** Duplicate from TokenLifecycleService (intentional - no dependency)

```php
private function fetchToken(int $tokenId): ?array
{
    $stmt = $this->db->prepare("SELECT * FROM flow_token WHERE id_token = ?");
    $stmt->bind_param('i', $tokenId);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc();
}
```

---

## 🚧 Guardrails (MUST FOLLOW)

### Guardrail 1: Stub Implementation Only
- ✅ Phase 2 = stub methods (basic structure, logging, dummy returns)
- ❌ NO full implementation (Phase 3)
- ❌ NO parallel_group_id queries yet
- ❌ NO split/merge logic
- ✅ Methods callable but return safe defaults

### Guardrail 2: Fail Gracefully
- ✅ If called on wrong token type → log error + return gracefully
- ❌ NO throwing exceptions that break behavior execution
- ✅ Use error_log for debugging

### Guardrail 3: Database Safety
- ✅ Use prepared statements
- ✅ Update only `flow_token.metadata` (JSON field)
- ❌ NO schema changes
- ❌ NO creating component tables (Task 5 - future)

### Guardrail 4: Single Responsibility
- ✅ This service manages component metadata ONLY
- ❌ NO token status updates (TokenLifecycleService owns that)
- ❌ NO session management (TokenWorkSessionService owns that)
- ❌ NO split/merge coordination (ParallelMachineCoordinator - Phase 3)
- ❌ NO lifecycle transitions (TokenLifecycleService owns that)

### Guardrail 5: No External Dependencies
- ✅ Can call: database, TimeHelper, error_log
- ❌ NO calling BehaviorExecutionService (circular dependency)
- ❌ NO calling TokenLifecycleService (separate concerns)
- ❌ NO calling ParallelMachineCoordinator yet (Phase 3)

### Guardrail 6: Helper Method Strategy
- ✅ Duplicate fetchToken() in this service (no dependency on TokenLifecycleService)
- ✅ Keep services independent (easier to test, no coupling)
- 📝 Future Phase 5: Extract to shared TokenHelper (optional cleanup)

---

## 🏗️ Service Architecture (After Task 27.5)

```
BGERP\Service\
├─ TokenLifecycleService (Phase 1 ✅)
│  └─ Owns: Token status transitions
└─ ComponentFlowService (Phase 2 📋 this task)
   └─ Owns: Component metadata

BGERP\Dag\
└─ BehaviorExecutionService (Phase 1 ✅, Task 27.6 will update)
   ├─ Calls: TokenLifecycleService
   └─ Calls: ComponentFlowService (Task 27.6)

NO circular dependencies ✅
```

---

## 🧪 Testing Requirements

### Unit Tests

**File:** `tests/Unit/ComponentFlowServiceTest.php` (new)

**Test Cases:**
1. `testOnComponentCompletedUpdatesMetadata()` - Verify metadata updated
2. `testOnComponentCompletedGracefulOnPieceToken()` - Should not crash
3. `testIsReadyForAssemblyReturnsStub()` - Returns ready=true
4. `testGetSiblingStatusReturnsEmpty()` - Returns empty array
5. `testAggregateComponentTimesReturnsStub()` - Returns stub data

**Run Command:**
```bash
vendor/bin/phpunit tests/Unit/ComponentFlowServiceTest.php --testdox
```

**Expected:** All tests pass (5/5)

---

## 📦 Deliverables

### 1. Source Files

- ✅ `source/BGERP/Service/ComponentFlowService.php` (new) ⚠️ **BGERP\Service namespace**
  - 4 stub methods + 1 helper
  - ~150-200 lines
  - PSR-4 compliant
  - Full docblocks
  - Constructor with mysqli dependency

### 2. Test Files

- ✅ `tests/Unit/ComponentFlowServiceTest.php` (new)
  - 5 test cases minimum
  - ~80-100 lines

### 3. Results Document

- ✅ `docs/super_dag/tasks/results/task27.5_results.md`

---

## ✅ Definition of Done

- [ ] ComponentFlowService class exists
- [ ] 4 stub methods implemented (onComponentCompleted, isReadyForAssembly, getSiblingStatus, aggregateComponentTimes)
- [ ] Methods callable without errors
- [ ] onComponentCompleted updates metadata successfully
- [ ] Other methods return safe stub data
- [ ] Unit tests pass (5/5)
- [ ] No exceptions thrown
- [ ] Code compiles, PSR-4 autoload works
- [ ] Results document created

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO full component flow implementation (Phase 3)
- ❌ NO parallel_group_id validation
- ❌ NO split/merge logic
- ❌ NO creating component tables
- ❌ NO database schema changes
- ❌ NO UI changes
- ❌ NO touching BehaviorExecutionService (Task 27.6)
- ❌ NO implementing actual component time aggregation
- ❌ NO creating new .md documentation

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 6 (Component hooks)
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Section 4 (Component metadata)

**Related Tasks:**
- Task 27.2: TokenLifecycleService (BGERP\Service) - Pattern reference
- Task 27.3: BehaviorExecutionService refactored - Will call ComponentFlowService in Task 27.6
- Task 27.4: Validation matrix - Behavior-token type compatibility

**Database Schema:**
- Check: `flow_token.metadata` column (JSON field for component metadata)
- Alternative: `flow_token.component_data` or other JSON field

---

## 📝 Implementation Checklist

**Before Coding:**
- [ ] Verify database schema (metadata column exists)
- [ ] Read TokenLifecycleService for pattern reference (BGERP\Service namespace)
- [ ] Understand BehaviorExecutionService structure (from Task 27.3)

**During Coding:**
- [ ] Use BGERP\Service namespace (NOT BGERP\Dag)
- [ ] Constructor with mysqli dependency
- [ ] Stub methods return safe defaults
- [ ] Fail gracefully (no exceptions)
- [ ] Comprehensive error logging

**After Coding:**
- [ ] Run composer dump-autoload
- [ ] Check PSR-4 autoload works
- [ ] Run unit tests (5/5)
- [ ] Verify no circular dependencies

---

## 📝 Results Template

```markdown
# Task 27.5 Results — ComponentFlowService Created

**Completed:** YYYY-MM-DD  
**Duration:** X hours  
**Status:** ✅ Complete

## Files Created
- `source/BGERP/Service/ComponentFlowService.php` (XXX lines) ⚠️ BGERP\Service
- `tests/Unit/ComponentFlowServiceTest.php` (XXX lines, X tests)

## Test Results
```
vendor/bin/phpunit tests/Unit/ComponentFlowServiceTest.php --testdox
✅ 5/5 tests passed
```

## Notes
- Stub implementation only (Phase 2)
- Full implementation in Phase 3

## Next Steps
- Proceed to Task 27.6 (Component hooks in Behavior)
```

---

**END OF TASK**

