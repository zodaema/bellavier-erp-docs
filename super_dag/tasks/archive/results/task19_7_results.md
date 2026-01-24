# Task 19.7 Results – GraphValidator Hardening & Unified Validation Framework

## Overview

Task 19.7 successfully implemented a unified validation engine (`GraphValidationEngine.php`) that consolidates all scattered validation logic into a single source of truth. This resolves critical validation issues including QC routing false warnings, incorrect "missing work center" errors, and missing/duplicated START/END checks.

**Completion Date:** 2025-12-19  
**Status:** ✅ Completed

---

## Problem Analysis

### Issues Resolved

1. **QC Routing False Warnings**
   - **Before:** QC nodes required exactly 3 edges (pass, fail_minor, fail_major) or validation failed
   - **After:** QC nodes do NOT require 3 edges. Missing statuses are warnings (not errors) unless no ELSE/default edge exists

2. **Incorrect "Missing Work Center" Errors**
   - **Before:** Operation nodes without work center were treated as errors
   - **After:** Operation nodes without work center are warnings (advisory only)

3. **Missing/Duplicated START/END Checks**
   - **Before:** Validation scattered across multiple functions
   - **After:** Centralized in Module 2 (Start/End Validator) with clear error messages

4. **Parallel Split/Merge Structural Validation Gaps**
   - **Before:** Inconsistent validation logic
   - **After:** Centralized in Modules 4 & 5 with clear requirements

5. **Invalid Conditional Routing Rules**
   - **Before:** Conditional edges validated inconsistently
   - **After:** Centralized in Module 7 with proper condition structure validation

---

## New Validation Architecture

### GraphValidationEngine.php

**Location:** `source/BGERP/Dag/GraphValidationEngine.php`

A unified validator with 10 modules:

1. **Node Existence Validator** - Ensures graph has at least one node
2. **Start/End Validator** - Exactly 1 START, exactly 1 END
3. **Edge Integrity Validator** - No dangling edges, no self-loops
4. **Parallel Structure Validator** - Split nodes have ≥2 outgoing edges
5. **Merge Structure Validator** - Merge nodes have ≥2 incoming edges
6. **QC Routing Validator** (Task 19.7: Fixed) - QC coverage with warnings
7. **Conditional Routing Validator** - Validates conditional edge conditions
8. **Behavior-WorkCenter Compatibility Validator** - (Placeholder for future)
9. **Machine Binding Validator** - (Placeholder for future)
10. **Node Configuration Validator** - QC policy, join requirement, etc.

### Validation Flow

```
Frontend (graph_designer.js)
    ↓
validateGraphBeforeSave() → API call
    ↓
Backend (dag_routing_api.php)
    ↓
graph_validate action
    ↓
GraphValidationEngine::validate()
    ↓
10 Modules execute in sequence
    ↓
Return: { valid, errors[], warnings[], summary }
    ↓
Frontend displays errors/warnings
```

---

## Validator Rule List

### Module 1: Node Existence
- **Rule:** Graph must have at least one node
- **Error Code:** `GRAPH_EMPTY`
- **Severity:** Error

### Module 2: Start/End
- **Rule:** Exactly 1 START node required
- **Error Codes:** `GRAPH_MISSING_START`, `GRAPH_MULTIPLE_START`
- **Severity:** Error
- **Suggestion:** "Add a Start node to begin the workflow" / "Remove extra Start nodes. Keep only one."

- **Rule:** Exactly 1 END node required
- **Error Codes:** `GRAPH_MISSING_FINISH`, `GRAPH_MULTIPLE_FINISH`
- **Severity:** Error
- **Suggestion:** "Add a Finish node to end the workflow" / "Remove extra Finish nodes. Keep only one."

### Module 3: Edge Integrity
- **Rule:** No dangling edges (from_node or to_node not found)
- **Error Codes:** `EDGE_DANGLING_FROM`, `EDGE_DANGLING_TO`
- **Severity:** Error

- **Rule:** No self-loop edges
- **Error Code:** `EDGE_SELF_LOOP`
- **Severity:** Error

### Module 4: Parallel Structure
- **Rule:** Split nodes must have ≥2 outgoing edges
- **Error Code:** `SPLIT_INSUFFICIENT_EDGES`
- **Severity:** Error

### Module 5: Merge Structure
- **Rule:** Merge nodes must have ≥2 incoming edges
- **Error Code:** `MERGE_INSUFFICIENT_EDGES`
- **Severity:** Error

### Module 6: QC Routing (Task 19.7: Fixed)
- **Rule:** QC nodes should have routes for all statuses (pass, fail_minor, fail_major)
- **Error Code:** `QC_MISSING_ROUTES` (only if no ELSE/default edge exists)
- **Warning Code:** `QC_MISSING_SPECIFIC_ROUTES` (if ELSE exists but specific routes missing)
- **Severity:** Error (if no ELSE) or Warning (if ELSE exists)
- **Suggestion:** "Add conditional edge or declare ELSE route."

### Module 7: Conditional Routing
- **Rule:** Conditional edges must have valid conditions (unless default)
- **Error Code:** `CONDITIONAL_EDGE_MISSING_CONDITION`
- **Severity:** Error

### Module 8: Behavior-WorkCenter Compatibility
- **Status:** Placeholder (TODO: Implement)

### Module 9: Machine Binding
- **Status:** Placeholder (TODO: Implement)

### Module 10: Node Configuration
- **Rule:** Operation nodes should have work center or team (warning only)
- **Warning Code:** `OPERATION_MISSING_WORKFORCE`
- **Severity:** Warning

- **Rule:** QC nodes must have QC policy
- **Error Code:** `QC_MISSING_POLICY`
- **Severity:** Error

- **Rule:** Join nodes must have join_requirement
- **Error Code:** `JOIN_MISSING_REQUIREMENT`
- **Severity:** Error

---

## Before/After Examples

### Example 1: QC Node with Missing Routes

**Before (Task 19.7):**
```
[ERROR] QC node "QC1" is missing edges for QC statuses: fail_minor, fail_major.
All QC nodes must have edges covering pass, fail_minor, and fail_major.
```
❌ Blocks save

**After (Task 19.7):**
```
[WARNING] QC node "QC1" → Missing specific routes for: fail_minor, fail_major (using ELSE route)
Suggestion: Consider adding specific routes for better routing control.
```
✅ Allows save (warning only)

**If no ELSE route:**
```
[ERROR] QC node "QC1" → Missing QC route for: fail_minor, fail_major
Suggestion: Add conditional edge or declare ELSE route.
```
❌ Blocks save

### Example 2: Multiple START Nodes

**Before:**
```
[ERROR] Graph must have exactly 1 Start node.
```

**After:**
```
[ERROR] Graph has 2 Start nodes. Only 1 is allowed. (Found: START1, START2)
Suggestion: Remove extra Start nodes. Keep only one.
```

### Example 3: Operation Node Without Work Center

**Before:**
```
[ERROR] Operation node "OP1" must have work center assigned
```
❌ Blocks save

**After:**
```
[WARNING] Operation node "OP1" should have work center or team assigned.
Suggestion: Assign a work center or team category.
```
✅ Allows save (warning only)

---

## Expected UX Behavior

### Frontend (graph_designer.js)

1. **Before Save:**
   - Calls `validateGraphBeforeSave()` (async)
   - Calls backend `graph_validate` API
   - Displays errors in SweetAlert2 dialog
   - Blocks save if errors exist
   - Shows warnings dialog (user can proceed or cancel)

2. **Error Display:**
   - Error message
   - Suggestion (if available)
   - Node/Edge context (if available)

3. **Warning Display:**
   - Warning message
   - Suggestion (if available)
   - "Proceed Anyway" button

### Backend (dag_routing_api.php)

1. **API Endpoint:** `graph_validate`
2. **Input:** `{ action: 'graph_validate', id: graphId }`
3. **Output:**
   ```json
   {
     "ok": true,
     "validation": {
       "valid": false,
       "errors": [
         {
           "code": "GRAPH_MISSING_START",
           "message": "Graph must have exactly 1 Start node.",
           "suggestion": "Add a Start node to begin the workflow.",
           "category": "structure"
         }
       ],
       "warnings": [
         {
           "code": "QC_MISSING_SPECIFIC_ROUTES",
           "message": "QC node \"QC1\" → Missing specific routes for: fail_minor, fail_major (using ELSE route)",
           "suggestion": "Consider adding specific routes for better routing control.",
           "category": "routing",
           "node": "QC1"
         }
       ],
       "summary": {
         "total_nodes": 5,
         "total_edges": 4,
         "validated_rules": 8,
         "skipped_rules": 0
       }
     }
   }
   ```

---

## Implementation Details

### Files Created

1. **`source/BGERP/Dag/GraphValidationEngine.php`**
   - Unified validation engine
   - 10 validation modules
   - Structured error/warning format with suggestions

### Files Modified

1. **`source/dag_routing_api.php`**
   - Updated `graph_validate` action to use `GraphValidationEngine`
   - Added error code mapping for new validation codes
   - Added suggestion and node/edge context to error/warning responses

2. **`assets/javascripts/dag/graph_designer.js`**
   - Updated `validateGraphBeforeSave()` to call backend API (async)
   - Removed legacy QC routing validation
   - Added warning dialog with "Proceed Anyway" option
   - Wrapped save logic in `performActualSave()` function

### Backward Compatibility

✅ **100% backward compatible**
- Legacy error codes still supported (`DAG.E001`, `DAG.E002`, etc.)
- Old graphs validated correctly
- No breaking changes to API response format

---

## Testing

### Test Cases

1. ✅ QC node with only pass route + ELSE → Warning (not error)
2. ✅ QC node with no routes → Error
3. ✅ Multiple START nodes → Error with suggestion
4. ✅ Missing START node → Error with suggestion
5. ✅ Operation node without work center → Warning (not error)
6. ✅ Split node with 1 outgoing edge → Error
7. ✅ Merge node with 1 incoming edge → Error
8. ✅ Conditional edge without condition → Error
9. ✅ Self-loop edge → Error
10. ✅ Dangling edge → Error

---

## Future Work (Task 19.8)

**AutoFix Engine** - Automatically repair simple validation issues:
- Missing END node → Auto-add
- Dangling edges → Auto-remove
- Missing default edge → Auto-add ELSE route
- etc.

---

## Acceptance Criteria Status

| Requirement | Status |
|------------|--------|
| Unified validation engine | ✅ Complete |
| QC routing warnings fixed | ✅ Complete |
| START/END uniqueness | ✅ Complete |
| Parallel/merge consistency | ✅ Complete |
| UX-friendly error messages | ✅ Complete |
| Frontend only shows actionable errors | ✅ Complete |
| No breaking of legacy graphs | ✅ Complete |
| 100% backward compatible | ✅ Complete |
| No routing logic changed | ✅ Complete |
| No DAG execution logic changed | ✅ Complete |

---

## Summary

Task 19.7 successfully consolidated all validation logic into a unified `GraphValidationEngine` that provides:
- ✅ Clear, actionable error messages with suggestions
- ✅ Proper error vs warning distinction
- ✅ Fixed QC routing validation (warnings instead of errors)
- ✅ Centralized validation rules
- ✅ 100% backward compatibility

The validation system is now deterministic, predictable, and user-friendly.

