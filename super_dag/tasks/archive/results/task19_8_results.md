# Task 19.8 Results – Graph AutoFix Engine (Safe Quick-Fix for DAG & QC)

## Overview

Task 19.8 successfully implemented a safe, deterministic AutoFix layer that can repair the most common, low-risk graph problems automatically (or semi-automatically via UI confirmation), without changing business semantics and without touching runtime tokens.

**Completion Date:** 2025-12-19  
**Status:** ✅ Completed

---

## Problem Analysis

### Issues Resolved

1. **QC Routing False Warnings**
   - **Before:** Users manually had to mark rework edges as default routes
   - **After:** AutoFix detects QC Pass→Next + Else→Rework pattern and suggests marking rework edge as default

2. **Dead-End SINK Node Warnings**
   - **Before:** ReworkSink/ScrapSink nodes with 0 outgoing edges triggered dead-end warnings
   - **After:** AutoFix marks explicit sink nodes to suppress warnings

3. **Incomplete Conditional Coverage**
   - **Before:** Decision nodes with conditional + normal edges required manual default route marking
   - **After:** AutoFix suggests marking normal edge as default ELSE route

4. **START/END Metadata Inconsistency**
   - **Before:** START/END nodes sometimes had inconsistent metadata flags
   - **After:** AutoFix normalizes metadata to match visual node types

---

## Implementation

### GraphAutoFixEngine.php

**Location:** `source/BGERP/Dag/GraphAutoFixEngine.php`

**Key Methods:**
- `suggestFixes()` - Main entry point, analyzes validation results and suggests fixes
- `suggestQCDefaultRework()` - Pattern 1: QC Pass→Next + Else→Rework
- `suggestMarkSinkNodes()` - Pattern 2: Mark explicit SINK nodes
- `suggestDefaultElseRoute()` - Pattern 3: Default ELSE route clarification
- `suggestStartEndNormalization()` - Pattern 4: START/END metadata normalization

**Fix Patterns Implemented:**

1. **QC Default Rework Pattern**
   - Detects: QC node with 1 pass edge + 1 rework edge
   - Suggests: Mark rework edge as `is_default = true`
   - Severity: `safe`

2. **Mark SINK Nodes Pattern**
   - Detects: Node with 0 outgoing edges + sink behavior/category
   - Suggests: Set `node_params.is_sink = true`
   - Severity: `safe`

3. **Default ELSE Route Pattern**
   - Detects: Node with ≥1 conditional edges + exactly 1 normal edge
   - Suggests: Mark normal edge as `is_default = true`
   - Severity: `safe`

4. **START/END Normalization Pattern**
   - Detects: START/END nodes with inconsistent metadata
   - Suggests: Set `node_params.is_start = true` or `node_params.is_end = true`
   - Severity: `safe`

### API Integration

**New Action:** `graph_autofix`

**Location:** `source/dag_routing_api.php`

**Input:**
```json
{
  "action": "graph_autofix",
  "id": 123,
  "mode": "draft"
}
```

**Output:**
```json
{
  "ok": true,
  "fix_count": 2,
  "fixes": [
    {
      "id": "FIX-QC-DEFAULT-REWORK-QC1",
      "type": "QC_DEFAULT_REWORK",
      "severity": "safe",
      "target": {
        "node_id": 123,
        "node_code": "QC1",
        "edge_id": 456,
        "edge_code": "QC1-REWORK"
      },
      "title": "Treat rework edge as default QC fail route",
      "description": "QC node \"QC1\" has a pass edge and a rework edge without conditions...",
      "operations": [
        {
          "op": "set_edge_default_route",
          "edge_id": 456,
          "edge_code": "QC1-REWORK",
          "value": true
        }
      ]
    }
  ],
  "patched_nodes": [],
  "patched_edges": []
}
```

**Note:** v1 does NOT apply fixes to DB - only suggests. Application is done via frontend UI.

### Frontend Integration

**Location:** `assets/javascripts/dag/graph_designer.js`

**New Functions:**
- `showAutoFixDialog()` - Calls API and shows fixes dialog
- `showFixesSelectionDialog()` - Displays fixes list with checkboxes
- `applyFixes()` - Applies selected fixes to graph state
- `applyFixOperation()` - Applies individual fix operation

**UX Flow:**
1. User clicks "Save graph"
2. Validation runs → Shows errors/warnings
3. If autofixable issues exist → Shows "Try Auto-Fix" button
4. User clicks "Try Auto-Fix" → Calls `graph_autofix` API
5. Shows fixes list with checkboxes
6. User selects fixes → Clicks "Apply Selected"
7. Fixes applied to graph state → Re-validates automatically
8. If all fixed → Proceeds with save

**UI Features:**
- Highlights affected nodes/edges in graph
- Shows fix severity badges (safe/risky/manual-only)
- Displays fix description and affected elements
- Allows selective application (not all-or-nothing)

---

## Test Cases

**File:** `docs/super_dag/tests/autofix_test_cases.md`

**Total:** 12 test cases covering:
- ✅ QC Pass→Finish + Else Rework pattern
- ✅ QC with complete coverage (no fix needed)
- ✅ QC with only pass (no fix - cannot create edges)
- ✅ ReworkSink dead-end (mark as sink)
- ✅ Normal node dead-end (no fix)
- ✅ Decision node with conditional + normal (mark default)
- ✅ Decision node with only conditional (no fix)
- ✅ START/END metadata normalization
- ✅ Legacy valid graph (no fix)
- ✅ Fix applied + re-validate (error gone)
- ✅ Multiple fixes available (all proposed)
- ✅ Fix already applied (idempotent)

---

## Safety & Constraints

### v1 Limitations (Explicitly Out of Scope)

✅ **Implemented:**
- Mark edges as default routes
- Mark nodes as sink nodes
- Normalize START/END metadata

❌ **NOT Implemented (v1):**
- Creating or deleting nodes
- Creating or deleting edges
- Auto-connecting isolated nodes
- Auto-splitting or merging parallel branches
- Changing `work_center_code`, `behavior_code`, or `execution_mode`
- Any change that can alter business semantics

### Safety Guarantees

1. **No DB Writes in API**
   - `graph_autofix` is read-only
   - Fixes are applied via frontend UI only
   - Changes go through normal `graph_save` flow

2. **Pure Function**
   - `GraphAutoFixEngine` has no side effects
   - Only returns fix suggestions
   - Idempotent: Same input = same output

3. **User Confirmation Required**
   - All fixes require user selection
   - No silent auto-fixing
   - User can choose which fixes to apply

4. **Metadata Only**
   - v1 only modifies flags/metadata
   - Does not change graph structure
   - Does not affect routing semantics

---

## Acceptance Criteria Status

| Requirement | Status |
|------------|--------|
| GraphAutoFixEngine.php with suggestFixes() | ✅ Complete |
| graph_autofix action (read-only, no DB writes) | ✅ Complete |
| graph_designer.js AutoFix flow | ✅ Complete |
| QC Pass→Next + Else→Rework pattern fixed | ✅ Complete |
| Dead-end SINK nodes not warned after mark | ✅ Complete |
| No node/edge creation/deletion in v1 | ✅ Complete |
| Routing semantics unchanged | ✅ Complete |
| autofix_test_cases.md (12 test cases) | ✅ Complete |
| task19_8_results.md documentation | ✅ Complete |

---

## Example Usage

### Scenario: QC Node with Pass + Rework

**Before:**
- QC node "QC1" has:
  - Conditional edge: `qc_result.status == 'pass'` → Finish
  - Normal edge (no condition) → ReworkSink
- Validation error: "QC node QC1 → Missing QC route for: fail_minor, fail_major"

**User Action:**
1. Clicks "Save graph"
2. Sees validation error dialog
3. Clicks "Try Auto-Fix" button
4. Sees fix: "Treat rework edge as default QC fail route"
5. Selects fix → Clicks "Apply Selected"

**After:**
- Rework edge has `is_default = true`
- Validation error disappears
- Graph can be saved successfully

---

## Future Work (Task 19.9+)

Potential enhancements for future tasks:
- Auto-create missing edges (with user confirmation)
- Auto-connect isolated nodes
- Auto-split/merge parallel branches
- More sophisticated fix patterns
- Fix preview/undo capability

---

## Summary

Task 19.8 successfully implemented a safe, deterministic AutoFix Engine that:
- ✅ Reduces friction for graph designers (one click to fix common issues)
- ✅ Removes noisy warnings by codifying common patterns
- ✅ Keeps all logic changes auditable and reversible
- ✅ Requires user confirmation for all fixes
- ✅ Does not modify graph structure (metadata only in v1)
- ✅ Is 100% backward compatible

The AutoFix Engine sits on top of `GraphValidationEngine` (Task 19.7) and provides actionable fix suggestions without changing business semantics.

