# Task 27.10.1: Fix Rework Edge Pattern Recognition

## Overview

**Status:** Pending  
**Priority:** CRITICAL  
**Estimated Time:** 1-2 hours  
**Dependencies:** None  
**Blocks:** Task 27.10.2, Task 27.11

---

## Problem Statement

### Current Situation

**Modern Pattern (Used in Seed files and Graph Designer):**
- Rework uses `edge_type='conditional'` + `edge_condition` with fail logic
- Example: `['type' => 'conditional', 'condition' => '{"status":"fail"}']`

**Legacy Pattern (Used in Validators):**
- Rework uses `edge_type='rework'`

### Evidence

```sql
-- Seed graph (ID 1951) has NO 'rework' edges
SELECT edge_type, COUNT(*) FROM routing_edge WHERE id_graph=1951 GROUP BY edge_type;
-- Result: normal=9, conditional=8 (zero 'rework')
```

### Affected Code

| File | Function | Issue |
|------|----------|-------|
| `DAGValidationService.php` | `hasCycle()` | Skip only `edge_type='rework'` |
| `GraphValidationEngine.php` | Cycle detection | Check only `edge_type='rework'` |
| `GraphValidationEngine.php` | QC routing | Detect failure path via `edge_type='rework'` |

---

## Objective

Update all validators to understand BOTH patterns:
1. Legacy: `edge_type='rework'`
2. Modern: `edge_type='conditional'` + fail condition in `edge_condition`

---

## Requirements

### R1: Create isReworkEdge() Helper

Add to both DAGValidationService and GraphValidationEngine:

```php
private function isReworkEdge(array $edge): bool
{
    // Legacy pattern
    if (($edge['edge_type'] ?? '') === 'rework') {
        return true;
    }
    
    // Modern pattern: conditional with fail condition
    if (($edge['edge_type'] ?? '') === 'conditional') {
        $condition = $edge['edge_condition'] ?? '';
        if (empty($condition)) {
            return false;
        }
        
        $conditionData = is_string($condition) ? json_decode($condition, true) : $condition;
        if (!is_array($conditionData)) {
            return false;
        }
        
        $status = $conditionData['status'] ?? $conditionData['qc_status'] ?? null;
        if (in_array(strtolower($status ?? ''), ['fail', 'failed', 'reject', 'rejected', 'rework'], true)) {
            return true;
        }
        
        if (($conditionData['qc_fail'] ?? false) === true) {
            return true;
        }
    }
    
    return false;
}
```

### R2: Update DAGValidationService.hasCycle()

**File:** `source/BGERP/Service/DAGValidationService.php`  
**Line:** ~946-978

**Change:**
```php
// Before:
if ($edge['edge_type'] === 'rework') {
    continue;
}

// After:
if ($this->isReworkEdge($edge)) {
    continue;
}
```

### R3: Update GraphValidationEngine Cycle Check

**File:** `source/BGERP/Dag/GraphValidationEngine.php`  
**Line:** ~1371-1385

**Change:**
```php
// Before:
if ($edgeType === 'rework') {
    $hasReworkEdge = true;
}

// After:
if ($this->isReworkEdge($edge)) {
    $hasReworkEdge = true;
}
```

### R4: Update GraphValidationEngine QC Routing Check

**File:** `source/BGERP/Dag/GraphValidationEngine.php`  
**Line:** ~961-963

**Change:**
```php
// Before:
if ($edge['edge_type'] === 'rework') {
    $hasFailurePath = true;
}

// After:
if ($this->isReworkEdge($edge)) {
    $hasFailurePath = true;
}
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `source/BGERP/Service/DAGValidationService.php` | Add `isReworkEdge()`, update `hasCycle()` |
| `source/BGERP/Dag/GraphValidationEngine.php` | Add `isReworkEdge()`, update cycle and QC checks |

---

## Acceptance Criteria

1. `isReworkEdge()` helper exists in both files
2. `hasCycle()` skips conditional edges with fail condition
3. GraphValidationEngine cycle check recognizes modern pattern
4. GraphValidationEngine QC routing check recognizes modern pattern
5. Seed graph (BAG_COMPONENT_FLOW_V3) passes validation with no false cycle errors
6. Existing graphs with legacy `edge_type='rework'` still work

---

## Testing

### Manual Test 1: Seed Graph Validation
1. Navigate to Graph Designer
2. Open BAG_COMPONENT_FLOW_V3
3. Click Validate
4. Expected: 0 errors, 3 warnings (expected rework cycle warnings)

### Manual Test 2: Legacy Graph
1. Find or create graph with `edge_type='rework'`
2. Validate
3. Expected: Still works correctly

---

## Results Template

```markdown
## Task 27.10.1 Results

**Completed:** [DATE]
**Time Spent:** [X hours]

### Changes Made
1. ...

### Tests Passed
- [ ] Seed graph validation
- [ ] Legacy graph validation

### Notes
...
```

