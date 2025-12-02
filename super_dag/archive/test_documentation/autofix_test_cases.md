# AutoFix Test Cases

**Task 19.8: Graph AutoFix Engine Test Cases**

## Overview

This document contains test cases for the AutoFix Engine. Each test case describes:
- **Setup**: Initial graph state
- **Validation Error/Warning**: What validation issue triggers the fix
- **Expected Fix**: What fix should be suggested
- **Expected Result**: What the graph state should be after applying the fix

---

## Test Case 1: QC Pass→Finish + Else Rework → Add Default/Conditions Automatically

**Setup:**
- Graph has QC node "QC1"
- QC1 has 1 conditional edge: `qc_result.status == 'pass'` → Finish node
- QC1 has 1 normal edge (no condition) → ReworkSink node
- No `is_default` flag on rework edge

**Validation Error/Warning:**
- `QC_MISSING_ROUTES` or `QC_MISSING_SPECIFIC_ROUTES` for fail_minor, fail_major

**Expected Fix:**
- Type: `QC_DEFAULT_REWORK`
- Operation: `set_edge_default_route` on rework edge
- Severity: `safe`

**Expected Result:**
- Rework edge has `is_default = true`
- Validation error/warning disappears
- Graph can be saved

---

## Test Case 2: QC Has 3 Statuses Complete → AutoFix Does Not Propose Fix

**Setup:**
- Graph has QC node "QC1"
- QC1 has 3 conditional edges:
  - `qc_result.status == 'pass'` → Finish
  - `qc_result.status == 'fail_minor'` → ReworkSink
  - `qc_result.status == 'fail_major'` → ReworkSink
- All edges properly configured

**Validation Error/Warning:**
- None (graph is valid)

**Expected Fix:**
- No fixes proposed

**Expected Result:**
- `graph_autofix` returns `fix_count: 0`
- No fixes array

---

## Test Case 3: QC Has Only Pass, No Rework → AutoFix Does Not Propose Fix

**Setup:**
- Graph has QC node "QC1"
- QC1 has 1 conditional edge: `qc_result.status == 'pass'` → Finish
- No rework edge exists

**Validation Error/Warning:**
- `QC_MISSING_ROUTES` for fail_minor, fail_major

**Expected Fix:**
- No fixes proposed (cannot auto-create edges in v1)

**Expected Result:**
- `graph_autofix` returns `fix_count: 0`
- Error remains (user must manually add rework edge)

---

## Test Case 4: REWORK_SINK Has No Outgoing Edges → Mark as Sink

**Setup:**
- Graph has node "ReworkSink1"
- Node type: `rework_sink` (or `node_params.is_rework_sink = true`)
- Node has 0 outgoing edges
- Node does not have `node_params.is_sink = true`

**Validation Error/Warning:**
- Dead-end warning (if validation checks for unreachable nodes)

**Expected Fix:**
- Type: `MARK_SINK_NODE`
- Operation: `set_node_sink_flag` with `sink_type: 'REWORK_SINK'`
- Severity: `safe`

**Expected Result:**
- Node has `node_params.is_sink = true`
- Dead-end warning disappears (or downgraded)

---

## Test Case 5: Normal Node Has No Outgoing Edges → AutoFix Does Not Mark as Sink

**Setup:**
- Graph has operation node "OP1"
- Node type: `operation`
- Node has 0 outgoing edges
- Node is not a sink type

**Validation Error/Warning:**
- Dead-end warning (if validation checks)

**Expected Fix:**
- No fixes proposed (only mark explicit sink nodes)

**Expected Result:**
- `graph_autofix` returns `fix_count: 0`
- Warning remains (user must manually fix)

---

## Test Case 6: Non-QC Node: 1 Conditional + 1 Normal Edge → Propose Set Default Route

**Setup:**
- Graph has decision node "DEC1"
- DEC1 has 1 conditional edge: `job.priority == 'high'` → FastPath
- DEC1 has 1 normal edge (no condition) → NormalPath
- Normal edge does not have `is_default = true`

**Validation Error/Warning:**
- Warning about incomplete coverage (if validation checks)

**Expected Fix:**
- Type: `DEFAULT_ELSE_ROUTE`
- Operation: `set_edge_default_route` on normal edge
- Severity: `safe`

**Expected Result:**
- Normal edge has `is_default = true`
- Warning disappears (or downgraded)

---

## Test Case 7: Non-QC Node: 2 Conditional Edges + 0 Normal Edge → Do Not Propose Default Route Fix

**Setup:**
- Graph has decision node "DEC1"
- DEC1 has 2 conditional edges:
  - `job.priority == 'high'` → FastPath
  - `job.priority == 'low'` → SlowPath
- No normal edge exists

**Validation Error/Warning:**
- Warning about incomplete coverage (if validation checks)

**Expected Fix:**
- No fixes proposed (cannot mark conditional edge as default without normal edge)

**Expected Result:**
- `graph_autofix` returns `fix_count: 0`
- Warning remains (user must manually add default edge)

---

## Test Case 8: START/END Flags Inconsistent with Visual Node → Propose Normalize

**Setup:**
- Graph has node "START1" with `node_type = 'start'`
- Node does not have `node_params.is_start = true`
- Graph has node "END1" with `node_type = 'end'`
- Node does not have `node_params.is_end = true`

**Validation Error/Warning:**
- None (graph structure is valid, but metadata inconsistent)

**Expected Fix:**
- Type: `START_END_NORMALIZATION`
- Operations:
  - `set_node_start_flag` for START1
  - `set_node_end_flag` for END1
- Severity: `safe`

**Expected Result:**
- START1 has `node_params.is_start = true`
- END1 has `node_params.is_end = true`
- Metadata synchronized with visual node type

---

## Test Case 9: Legacy Graph That Passes Validation → No Fixes Proposed

**Setup:**
- Graph created before 2025-11-15 (legacy graph)
- Graph passes all validation rules
- No errors or warnings

**Validation Error/Warning:**
- None

**Expected Fix:**
- No fixes proposed

**Expected Result:**
- `graph_autofix` returns `fix_count: 0`
- No fixes array

---

## Test Case 10: AutoFix Applied Then Re-validate → Original Error Does Not Return

**Setup:**
- Graph has QC node "QC1" with Pass→Finish + Rework edge (no default flag)
- Validation reports: `QC_MISSING_ROUTES` for fail_minor, fail_major

**Steps:**
1. Call `graph_autofix` → Returns fix: `QC_DEFAULT_REWORK`
2. Apply fix: Set rework edge `is_default = true`
3. Call `graph_validate` again

**Expected Fix:**
- Type: `QC_DEFAULT_REWORK`
- Operation: `set_edge_default_route` on rework edge

**Expected Result After Fix:**
- Re-validation shows no `QC_MISSING_ROUTES` error
- Graph can be saved successfully
- Original error does not return

---

## Test Case 11: Multiple Fixes Available → All Proposed

**Setup:**
- Graph has:
  - QC node "QC1" with Pass→Finish + Rework (needs default flag)
  - ReworkSink node "RS1" with 0 outgoing edges (needs sink flag)
  - Decision node "DEC1" with 1 conditional + 1 normal (needs default flag)

**Validation Error/Warning:**
- Multiple warnings/errors

**Expected Fix:**
- 3 fixes proposed:
  1. `QC_DEFAULT_REWORK` for QC1
  2. `MARK_SINK_NODE` for RS1
  3. `DEFAULT_ELSE_ROUTE` for DEC1

**Expected Result:**
- `graph_autofix` returns `fix_count: 3`
- User can select which fixes to apply
- All selected fixes are applied correctly

---

## Test Case 12: Fix Already Applied → Idempotent (No Duplicate Fix)

**Setup:**
- Graph has QC node "QC1" with Pass→Finish + Rework edge
- Rework edge already has `is_default = true`

**Validation Error/Warning:**
- None (graph is valid)

**Expected Fix:**
- No fixes proposed (fix already applied)

**Expected Result:**
- `graph_autofix` returns `fix_count: 0`
- No duplicate fix operations

---

## Summary

| Test Case | Pattern | Expected Fix | Status |
|-----------|--------|--------------|--------|
| 1 | QC Pass + Rework | QC_DEFAULT_REWORK | ✅ |
| 2 | QC Complete | No fix | ✅ |
| 3 | QC Pass Only | No fix | ✅ |
| 4 | ReworkSink Dead-end | MARK_SINK_NODE | ✅ |
| 5 | Normal Dead-end | No fix | ✅ |
| 6 | Decision + Normal | DEFAULT_ELSE_ROUTE | ✅ |
| 7 | Decision Only | No fix | ✅ |
| 8 | START/END Metadata | START_END_NORMALIZATION | ✅ |
| 9 | Legacy Valid Graph | No fix | ✅ |
| 10 | Fix Applied + Re-validate | Error Gone | ✅ |
| 11 | Multiple Fixes | All Proposed | ✅ |
| 12 | Fix Already Applied | Idempotent | ✅ |

---

## Notes

- **v1 Limitations**: AutoFix Engine v1 does NOT:
  - Create or delete nodes
  - Create or delete edges
  - Change `work_center_code`, `behavior_code`, or `execution_mode`
  - Auto-connect isolated nodes

- **Safety**: All fixes in v1 are marked as `severity: 'safe'` and only modify metadata/flags, not graph structure.

