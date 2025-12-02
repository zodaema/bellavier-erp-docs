# Node Plan Auto-Assignment Integration - Implementation Summary

**Date:** December 2025  
**Status:** ✅ **COMPLETE**  
**Task:** docs/dag/agent-tasks/task7.md

---

## 📋 Executive Summary

Implemented Node Plan Auto-Assignment Integration for Hatthasilpa DAG system. When a `node_plan` has exactly 1 candidate after filtering, the system now automatically creates a `token_assignment` row with `assignment_method='node_plan'`, controlled by feature flag `FF_HAT_NODE_PLAN_AUTO_ASSIGN`.

**Key Achievement:**
- ✅ Node plan auto-assignment when exactly 1 candidate exists
- ✅ Feature flag protection (`FF_HAT_NODE_PLAN_AUTO_ASSIGN`)
- ✅ Idempotency: Won't override existing assignments
- ✅ Priority order: manager_assignment → job_plan → node_plan → auto_assign_policy
- ✅ All 3 integration tests passing

---

## 1. Problem Statement

### Before Implementation

**Issue:**
When `node_plan` has exactly 1 candidate after filtering:
- System would fall through to normal auto-assignment flow
- No automatic `token_assignment` creation from `node_plan`
- Work Queue would show "Unassigned" despite having a clear candidate

**Business Requirement:**
- If `node_plan` has exactly 1 candidate → auto-create `token_assignment`
- Must respect existing assignments (idempotency)
- Must be controlled by feature flag for safety
- Priority: manager_assignment > job_plan > node_plan > auto

---

## 2. Solution

### 2.1 Priority Order

**New Priority Order:**
```
1. PIN (highest)
2. MANAGER ASSIGNMENT (from manager_assignment table)
3. JOB PLAN (from assignment_plan_job)
4. NODE PLAN (from assignment_plan_node) ← NEW AUTO-ASSIGN
5. AUTO (skill matching + load balancing)
```

### 2.2 Node Plan Auto-Assignment Logic

**Location:** `source/BGERP/Service/AssignmentEngine.php` - `assignOne()` method  
**Branch:** After `filterAvailable()`, before `pickByLowestLoad()`

**Implementation:**
```php
// TASK7 - Node Plan Auto-Assignment (DO NOT MOVE THIS BLOCK)
// If node_plan has exactly 1 candidate after filtering, auto-assign (if feature flag enabled)
if ($source === 'node_plan' && count($candidates) === 1) {
    $singleCandidate = $candidates[0];
    
    // Check feature flag FF_HAT_NODE_PLAN_AUTO_ASSIGN
    $featureFlagEnabled = false;
    // ... (feature flag check logic)
    
    if ($featureFlagEnabled) {
        // Check if assignment already exists (idempotency)
        $existingAssignment = db_fetch_one($db, "
            SELECT id_assignment, assigned_to_user_id, status
            FROM token_assignment
            WHERE id_token = ?
              AND status IN ('assigned', 'accepted', 'started', 'paused')
            LIMIT 1
        ", [$tokenId]);
        
        if ($existingAssignment) {
            // Existing assignment found - do not override
            // Log and skip
        } else {
            // No existing assignment - create via node_plan
            $success = self::applyNodePlanAssignment($db, $tokenId, $nodeId, $singleCandidate);
            
            if ($success) {
                // Assignment created - commit and return
                $db->commit();
                return;
            }
        }
    }
}
// END TASK7 - Node Plan Auto-Assignment
```

**Behavior:**
- Only triggers when `source === 'node_plan'` AND `count($candidates) === 1`
- Checks feature flag `FF_HAT_NODE_PLAN_AUTO_ASSIGN` (must be enabled)
- Checks for existing assignment (idempotency guard)
- Creates assignment via `applyNodePlanAssignment()` helper
- Logs decision for audit trail

### 2.3 Helper Method: `applyNodePlanAssignment()`

**Location:** `source/BGERP/Service/AssignmentEngine.php`  
**Method:** `private static function applyNodePlanAssignment()`

**Implementation:**
```php
private static function applyNodePlanAssignment(\mysqli $db, int $tokenId, int $nodeId, int $assigneeUserId): bool {
    // Check if assignment already exists (idempotency guard)
    $existing = db_fetch_one($db, "
        SELECT id_assignment
        FROM token_assignment
        WHERE id_token = ?
          AND status IN ('assigned', 'accepted', 'started', 'paused')
        LIMIT 1
    ", [$tokenId]);
    
    if ($existing) {
        return false; // Don't create duplicate
    }
    
    // Check if multiple assignments exist (edge case - choose first active)
    // ... (fail-open logic)
    
    // No existing assignment - create new one
    try {
        // Use insertAssignmentWithMethod to support assignment_method column
        self::insertAssignmentWithMethod(
            $db,
            $tokenId,
            $assigneeUserId,
            false, // not pinned
            'node_plan',
            'Auto-assigned from node plan (single candidate)',
            null // assigned_by_user_id = NULL (system assignment)
        );
        
        // Populate assignment_log for work queue display
        self::logAssignmentToAssignmentLog(
            $db,
            $tokenId,
            $nodeId,
            $assigneeUserId,
            'node_plan',
            'Auto-assigned from node plan (single candidate)'
        );
        
        return true;
    } catch (\Throwable $e) {
        error_log('[AssignmentEngine] applyNodePlanAssignment failed: ' . $e->getMessage());
        return false;
    }
}
```

**Behavior:**
- Idempotent: Won't create duplicate if assignment exists
- Handles edge case: Multiple assignments → use first active
- Creates assignment with `assignment_method='node_plan'`
- Populates `assignment_log` for Work Queue display
- Returns `true` if created, `false` otherwise

### 2.4 Feature Flag Integration

**Feature Flag:** `FF_HAT_NODE_PLAN_AUTO_ASSIGN`

**Default:** `0` (disabled)  
**Enabled for:** `maison_atelier` tenant (in tests)

**Check Logic:**
```php
// Get tenant scope from job
$tenantScope = null;
// Try to get org_code from job_ticket (with fallback)
// Fallback to resolve_current_org() or 'GLOBAL'

// Check feature flag using FeatureFlagService
$coreDb = core_db();
$featureFlagService = new \BGERP\Service\FeatureFlagService($coreDb);
$flagValue = $featureFlagService->getFlagValue('FF_HAT_NODE_PLAN_AUTO_ASSIGN', $tenantScope);
$featureFlagEnabled = ($flagValue === 1);
```

**Safety:**
- Feature flag must be enabled for auto-assignment to work
- If flag check fails → soft mode (don't enable, log error)
- If flag disabled → log and continue with normal flow

---

## 3. Files Modified

### Modified Files (2 files)

1. **`source/BGERP/Service/AssignmentEngine.php`**
   - **Method:** `assignOne()` (private static)
   - **Lines:** 441-548 (added TASK7 block)
   - **Changes:**
     - Added node plan auto-assignment logic after `filterAvailable()`
     - Feature flag check with tenant scope resolution
     - Idempotency guard (existing assignment check)
     - Calls `applyNodePlanAssignment()` helper
   - **New Method:** `applyNodePlanAssignment()` (private static)
   - **Lines:** 1224-1302
   - **Changes:**
     - Helper method to create assignment from node plan
     - Idempotency checks
     - Assignment creation with `assignment_method='node_plan'`
     - Assignment log population

2. **`tests/Integration/HatthasilpaAssignmentIntegrationTest.php`**
   - **Method:** `enableFeatureFlagForTest()`
   - **Changes:**
     - Added `FF_HAT_NODE_PLAN_AUTO_ASSIGN` feature flag setup
   - **New Tests (3):**
     - `testNodePlanAssignmentCreated()` - Verifies assignment creation
     - `testNodePlanAssignmentNotOverrideExisting()` - Verifies idempotency
     - `testNodePlanAssignmentIdempotent()` - Verifies no duplicates
   - **New Helper:** `seedNodePlan()` - Seeds `assignment_plan_node` test data

---

## 4. Logging

### Log Messages

**When node plan candidate accepted:**
```
[AssignmentEngine] Node plan candidate accepted: user {userId}
```

**When assignment created:**
```
[AssignmentEngine] Assignment created via node_plan
```

**When feature flag check:**
```
[AssignmentEngine] node_plan auto-assign check: token_id={id}, tenant_scope={scope}, flag_value={value}, enabled={true/false}
```

**When existing assignment found:**
```
[AssignmentEngine] node_plan auto-assign skipped: token_id={id} already has assignment (id={id}, user={id}, status={status})
```

**When feature flag disabled:**
```
[AssignmentEngine] node_plan auto-assign disabled: token_id={id}, feature flag FF_HAT_NODE_PLAN_AUTO_ASSIGN=0
```

---

## 5. Behavior Comparison

### Before Implementation

**Scenario: Node Plan with 1 Candidate**
- Query: `SELECT assignee_id FROM assignment_plan_node WHERE id_graph=? AND id_node=?`
- Result: 1 candidate
- Filter: `filterAvailable()` → 1 candidate
- **Action:** Fall through to `pickByLowestLoad()` → normal auto-assignment
- **Problem:** No automatic assignment from node plan

### After Implementation

**Scenario: Node Plan with 1 Candidate (Feature Flag Enabled)**
- Query: Same as before
- Result: 1 candidate
- Filter: `filterAvailable()` → 1 candidate
- **Check:** `source === 'node_plan'` AND `count($candidates) === 1` → TRUE
- **Check:** Feature flag `FF_HAT_NODE_PLAN_AUTO_ASSIGN` → Enabled
- **Check:** Existing assignment → None
- **Action:** `applyNodePlanAssignment()` → Creates assignment
- **Result:** `token_assignment` row created with `assignment_method='node_plan'`

**Scenario: Node Plan with 1 Candidate (Feature Flag Disabled)**
- Same as above, but feature flag check → Disabled
- **Action:** Log and continue with normal flow
- **Result:** Falls through to normal auto-assignment

**Scenario: Node Plan with 1 Candidate (Existing Assignment)**
- Same as above, but existing assignment check → Found
- **Action:** Log and skip (don't override)
- **Result:** Original assignment remains unchanged

---

## 6. Scope & Constraints

### What Was Changed

✅ **Only Modified:**
- `AssignmentEngine::assignOne()` method (added TASK7 block)
- Added `applyNodePlanAssignment()` helper method
- Added 3 integration tests
- Added feature flag setup in test `setUp()`

### What Was NOT Changed

❌ **Not Modified:**
- Method signature of `assignOne()` (no new parameters)
- Database schema (no changes)
- Other assignment sources (manager, job_plan, auto)
- Existing test behavior (all previous tests still pass)

### Impact Analysis

**Affected:**
- Only `node_plan` assignment flow (when exactly 1 candidate)

**Not Affected:**
- Manager assignment (still highest priority)
- Job plan assignment (unchanged)
- Auto assignment (unchanged)
- All existing tests (no regression)

---

## 7. Test Results

### New Tests (3 tests)

**Status:** ✅ **All tests passing**

1. **`testNodePlanAssignmentCreated()`**
   - ✅ Creates `node_plan` with 1 candidate
   - ✅ Triggers `autoAssignOnSpawn()`
   - ✅ Verifies `token_assignment` created
   - ✅ Verifies `assigned_to_user_id` matches candidate
   - ✅ Verifies `assignment_method='node_plan'` (if column exists)
   - ✅ Verifies `status='assigned'`

2. **`testNodePlanAssignmentNotOverrideExisting()`**
   - ✅ Creates existing assignment (user A)
   - ✅ Creates `node_plan` with different candidate (user B)
   - ✅ Triggers `autoAssignOnSpawn()`
   - ✅ Verifies original assignment NOT overridden
   - ✅ Verifies `assigned_to_user_id` still = user A

3. **`testNodePlanAssignmentIdempotent()`**
   - ✅ Creates `node_plan` with 1 candidate
   - ✅ Triggers `autoAssignOnSpawn()` first time → 1 assignment
   - ✅ Triggers `autoAssignOnSpawn()` second time → still 1 assignment
   - ✅ Verifies no duplicate created
   - ✅ Verifies assignment details unchanged

### Existing Tests

**Status:** ✅ **All existing tests still pass**

- No regression in existing test suite
- All previous assignment tests still work correctly

---

## 8. Code Flow

### Execution Flow (Node Plan Auto-Assignment)

```
1. assignOne() called
   ↓
2. Check PIN → None
   ↓
3. Check MANAGER ASSIGNMENT → None
   ↓
4. Check JOB PLAN → None
   ↓
5. Check NODE PLAN → Found (1 candidate)
   ↓
6. expandAssignees() → [userId]
   ↓
7. filterAvailable() → [userId] (1 candidate)
   ↓
8. TASK7 Check: source === 'node_plan' AND count === 1 → TRUE
   ↓
9. Feature Flag Check: FF_HAT_NODE_PLAN_AUTO_ASSIGN → Enabled
   ↓
10. Existing Assignment Check → None
   ↓
11. applyNodePlanAssignment() → Creates assignment
   ↓
12. Log: "Assignment created via node_plan"
   ↓
13. Commit and return (skip normal auto-assignment)
```

---

## 9. Example Logs

### Scenario 1: Node Plan Auto-Assignment Success

```
[AssignmentEngine] assignOne start: token_id=1109, node_id_param=null, current_node_id=3967, instance_id=569
[AssignmentEngine] job context: token_id=1109, job_ticket_id=677, graph_id=1790, instance_id=569
[AssignmentEngine] manager plan not found for token_id=1109
[AssignmentEngine] job_plan query: token_id=1109, job_ticket_id=677, node_id=3967, rows=0
[AssignmentEngine] node_plan query: token_id=1109, graph_id=1790, node_id=3967, rows=1
[AssignmentEngine] node_plan candidates: token_id=1109, node_id=3967, candidates=[1]
[AssignmentEngine] filterAvailable called: candidate_count=1
[AssignmentEngine] filterAvailable: operator_availability empty, using fail-open (keep all candidates)
[AssignmentEngine] node_plan auto-assign check: token_id=1109, tenant_scope=maison_atelier, flag_value=1, enabled=true
[AssignmentEngine] Node plan candidate accepted: user 1
[AssignmentEngine] Assignment created via node_plan
```

**Result:** Assignment created with `assignment_method='node_plan'`

### Scenario 2: Existing Assignment (Idempotency)

```
[AssignmentEngine] node_plan auto-assign check: token_id=1110, tenant_scope=maison_atelier, flag_value=1, enabled=true
[AssignmentEngine] node_plan auto-assign skipped: token_id=1110 already has assignment (id=123, user=1, status=assigned)
```

**Result:** Original assignment preserved, no override

### Scenario 3: Feature Flag Disabled

```
[AssignmentEngine] node_plan auto-assign check: token_id=1111, tenant_scope=maison_atelier, flag_value=0, enabled=false
[AssignmentEngine] node_plan auto-assign disabled: token_id=1111, feature flag FF_HAT_NODE_PLAN_AUTO_ASSIGN=0
```

**Result:** Falls through to normal auto-assignment flow

---

## 10. Verification Checklist

- [x] Node plan auto-assignment logic implemented
- [x] Feature flag `FF_HAT_NODE_PLAN_AUTO_ASSIGN` integrated
- [x] Idempotency guard (won't override existing assignments)
- [x] Helper method `applyNodePlanAssignment()` created
- [x] Priority order maintained (manager > job > node > auto)
- [x] Assignment created with `assignment_method='node_plan'`
- [x] Assignment log populated for Work Queue
- [x] All 3 integration tests passing
- [x] No regression in existing tests
- [x] Proper logging for audit trail

**Status:** ✅ **ALL CHECKS PASSED**

---

## 11. Conclusion

The Node Plan Auto-Assignment Integration has been successfully implemented. The system now:

- ✅ **Auto-Assigns from Node Plan** - Creates assignment when exactly 1 candidate exists
- ✅ **Feature Flag Protected** - Controlled by `FF_HAT_NODE_PLAN_AUTO_ASSIGN`
- ✅ **Idempotent** - Won't override existing assignments
- ✅ **Priority Maintained** - Respects manager > job > node > auto order
- ✅ **Proper Logging** - Logs all decisions for audit trail
- ✅ **Test Coverage** - 3 comprehensive integration tests

**The system is ready for production use with node plan auto-assignment enabled.**

---

**Implementation Completed:** December 2025  
**Implemented By:** AI Agent (Composer)  
**Task Reference:** docs/dag/agent-tasks/task7.md

