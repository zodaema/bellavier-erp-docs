# DAG Task 7: Node Plan Auto-Assignment Integration

**Task ID:** DAG-7  
**Status:** ✅ **COMPLETED** (December 2025)  
**Scope:** Assignment / Node Plan  
**Type:** Implementation Task

---

## 1. Context

### Problem

When `node_plan` has exactly 1 candidate after filtering:
- System would fall through to normal auto-assignment flow
- No automatic `token_assignment` creation from `node_plan`
- Work Queue would show "Unassigned" despite having a clear candidate

### Impact

- Operators had to manually assign tokens even when node plan clearly specified assignee
- Work Queue didn't show planned assignments from node plans
- Assignment workflow was incomplete

---

## 2. Objective

Implement Node Plan Auto-Assignment Integration that:
- Auto-creates `token_assignment` when `node_plan` has exactly 1 candidate
- Respects existing assignments (idempotency)
- Controlled by feature flag for safety
- Priority order: manager_assignment > job_plan > node_plan > auto

---

## 3. Scope

### Files Changed

**PHP Service Files:**
- `source/BGERP/Service/AssignmentEngine.php`
  - Modified: `assignOne()` method - Added node plan auto-assignment logic
  - Added: `applyNodePlanAssignment()` helper method

**Test Files:**
- `tests/Integration/HatthasilpaAssignmentIntegrationTest.php`
  - Added: 3 new test cases
  - Added: `seedNodePlan()` helper method

### Database Tables Used

- `assignment_plan_node` - Node-level assignment plans (existing)
- `token_assignment` - Actual assignments (existing)
- `assignment_log` - Assignment history (existing)

---

## 4. Implementation Summary

### Priority Order (Updated)

**New Priority Order:**
```
1. PIN (highest)
2. MANAGER ASSIGNMENT (from manager_assignment table)
3. JOB PLAN (from assignment_plan_job)
4. NODE PLAN (from assignment_plan_node) ← NEW AUTO-ASSIGN
5. AUTO (skill matching + load balancing)
```

### Node Plan Auto-Assignment Logic

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

### Helper Method: `applyNodePlanAssignment()`

**Location:** `source/BGERP/Service/AssignmentEngine.php`  
**Method:** `private static function applyNodePlanAssignment()`

**Behavior:**
- Idempotent: Won't create duplicate if assignment exists
- Handles edge case: Multiple assignments → use first active
- Creates assignment with `assignment_method='node_plan'`
- Populates `assignment_log` for Work Queue display
- Returns `true` if created, `false` otherwise

### Feature Flag Integration

**Feature Flag:** `FF_HAT_NODE_PLAN_AUTO_ASSIGN`

**Default:** `0` (disabled)  
**Enabled for:** `maison_atelier` tenant (in tests)

**Safety:**
- Feature flag must be enabled for auto-assignment to work
- If flag check fails → soft mode (don't enable, log error)
- If flag disabled → log and continue with normal flow

---

## 5. Guardrails

### Must Not Regress

- ✅ **Idempotency** - Existing assignments are never overridden
- ✅ **Priority order** - manager_assignment > job_plan > node_plan > auto (must maintain)
- ✅ **Feature flag protection** - Auto-assignment only when flag enabled
- ✅ **No schema changes** - Uses existing tables

### Test Coverage

**Integration Tests:**
- `testNodePlanAssignmentCreated()` - Verifies assignment creation
- `testNodePlanAssignmentNotOverrideExisting()` - Verifies idempotency
- `testNodePlanAssignmentIdempotent()` - Verifies no duplicates

**Test File:** `tests/Integration/HatthasilpaAssignmentIntegrationTest.php`

---

## 6. Status

**Status:** ✅ **COMPLETED** (December 2025)

**Implementation:**
- ✅ Node plan auto-assignment logic implemented
- ✅ Feature flag `FF_HAT_NODE_PLAN_AUTO_ASSIGN` integrated
- ✅ Idempotency guard (won't override existing assignments)
- ✅ Helper method `applyNodePlanAssignment()` created
- ✅ Priority order maintained (manager > job > node > auto)
- ✅ Assignment created with `assignment_method='node_plan'`
- ✅ Assignment log populated for Work Queue
- ✅ All 3 integration tests passing
- ✅ No regression in existing tests

**Related Tasks:**
- ✅ Task 1: Manager Assignment Propagation (December 2025) - Manager plans propagate on spawn
  - See [TASK_DAG_2_MANAGER_ASSIGNMENT.md](TASK_DAG_2_MANAGER_ASSIGNMENT.md)

**Documentation:**
- ✅ Implementation summary: `docs/dag/agent-tasks/task7_NODE_PLAN_AUTO_ASSIGNMENT.md`

---

## 7. Related Documentation

- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Assignment section
- [TASK_DAG_2_MANAGER_ASSIGNMENT.md](TASK_DAG_2_MANAGER_ASSIGNMENT.md) - Manager assignment propagation
- [task7_NODE_PLAN_AUTO_ASSIGNMENT.md](../agent-tasks/task7_NODE_PLAN_AUTO_ASSIGNMENT.md) - Detailed implementation summary
- [INVESTIGATION_REPORT_NODE_PLAN_ASSIGNMENT.md](../agent-tasks/INVESTIGATION_REPORT_NODE_PLAN_ASSIGNMENT.md) - Investigation report

---

**Task Completed:** December 2025  
**Implemented By:** AI Agent (Composer)  
**Task Reference:** docs/dag/agent-tasks/task7.md

