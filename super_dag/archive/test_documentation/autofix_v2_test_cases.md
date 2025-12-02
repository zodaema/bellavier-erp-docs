# AutoFix v2 Test Cases (Structural Fixes)

**Task 19.9: Graph AutoFix Engine v2 - Structural Repairs**

## Overview

This document contains test cases for AutoFix Engine v2, which extends v1 (metadata-only fixes) to include structural graph repairs (creating edges and nodes).

---

## Test Case 1: QC Missing fail_major → Creates Edge

**Setup:**
- Graph has QC node "QC1"
- QC1 has 1 conditional edge: `qc_result.status == 'pass'` → Finish
- QC1 has 1 rework edge (no condition) → ReworkSink
- Missing conditional edge for `fail_major`

**Validation Error/Warning:**
- `QC_MISSING_ROUTES` for fail_major

**Expected Fix:**
- Type: `QC_FULL_COVERAGE`
- Operation: `create_edge` with condition `qc_result.status == 'fail_major'` → ReworkSink
- Severity: `safe`

**Expected Result:**
- New conditional edge created: QC1 → ReworkSink (fail_major)
- Validation error disappears
- Graph can be saved

---

## Test Case 2: QC Missing fail_minor → Creates Edge

**Setup:**
- Graph has QC node "QC1"
- QC1 has 1 conditional edge: `qc_result.status == 'pass'` → Finish
- QC1 has 1 rework edge (no condition) → ReworkSink
- Missing conditional edge for `fail_minor`

**Validation Error/Warning:**
- `QC_MISSING_ROUTES` for fail_minor

**Expected Fix:**
- Type: `QC_FULL_COVERAGE`
- Operation: `create_edge` with condition `qc_result.status == 'fail_minor'` → ReworkSink
- Severity: `safe`

**Expected Result:**
- New conditional edge created: QC1 → ReworkSink (fail_minor)
- Validation error disappears

---

## Test Case 3: No END Node → Create END

**Setup:**
- Graph has START node
- Graph has operation nodes "OP1", "OP2"
- OP1 and OP2 have 0 outgoing edges
- Graph has no END/FINISH node

**Validation Error/Warning:**
- `GRAPH_MISSING_FINISH`

**Expected Fix:**
- Type: `CREATE_END_NODE`
- Operations:
  1. `create_node`: END node (auto-generated code)
  2. `create_edge`: OP1 → END
  3. `create_edge`: OP2 → END
- Severity: `safe`

**Expected Result:**
- New END node created
- Terminal operations connected to END
- Validation error disappears

---

## Test Case 4: Parallel Branches → Auto Mark Merge

**Setup:**
- Graph has node "SPLIT1" with 2 outgoing edges → OP1, OP2
- OP1 and OP2 both have outgoing edges → MERGE1
- MERGE1 has 2 incoming edges but not marked as merge

**Validation Error/Warning:**
- Warning about merge node not marked

**Expected Fix:**
- Type: `MARK_MERGE_NODE`
- Operation: `set_node_merge_flag` on MERGE1
- Severity: `safe`

**Expected Result:**
- MERGE1 marked as `is_merge_node = true`
- Warning disappears

---

## Test Case 5: Non-QC Conditional Without Default → Create Default Edge

**Setup:**
- Graph has decision node "DEC1"
- DEC1 has 1 conditional edge: `job.priority == 'high'` → FastPath
- DEC1 has no unconditional/default edge

**Validation Error/Warning:**
- Warning about incomplete coverage

**Expected Fix:**
- Type: `CREATE_ELSE_EDGE`
- Operation: `create_edge` (normal, is_default=true) from DEC1 to nearest valid node (END or next operation)
- Severity: `safe`

**Expected Result:**
- New default edge created: DEC1 → END (or next operation)
- Warning disappears

---

## Test Case 6: Dangling Node → Auto-connect

**Setup:**
- Graph has START node
- Graph has operation node "OP1" (unreachable, no incoming edges)
- OP1 is not START

**Validation Error/Warning:**
- Warning about unreachable node

**Expected Fix:**
- Type: `CONNECT_UNREACHABLE`
- Operation: `create_edge` from START → OP1
- Severity: `safe`

**Expected Result:**
- New edge created: START → OP1
- Node becomes reachable
- Warning disappears

---

## Test Case 7: Orphan Node → Auto-connect

**Setup:**
- Graph has START → OP1 → OP2
- Graph has operation node "OP3" (orphan, no incoming edges, not connected to main flow)
- OP3 is not START

**Validation Error/Warning:**
- Warning about unreachable node

**Expected Fix:**
- Type: `CONNECT_UNREACHABLE`
- Operation: `create_edge` from START → OP3 (or nearest upstream node)
- Severity: `safe`

**Expected Result:**
- New edge created connecting OP3 to main flow
- Node becomes reachable

---

## Test Case 8: QC + No Rework Path → Create Rework

**Setup:**
- Graph has QC node "QC1"
- QC1 has QC policy: `require_rework_edge = true`
- QC1 has no rework edge
- Graph has REWORK_SINK node "RS1"

**Validation Error/Warning:**
- Error about missing rework path

**Expected Fix:**
- Type: `CREATE_REWORK_PATH`
- Operation: `create_edge` (rework type) from QC1 → RS1 with condition for fail_minor & fail_major
- Severity: `safe`

**Expected Result:**
- New rework edge created: QC1 → RS1
- Error disappears

---

## Test Case 9: Multi-branch Join → Infer Merge

**Setup:**
- Graph has parallel split: SPLIT1 → OP1, OP2, OP3
- OP1, OP2, OP3 all converge to JOIN1
- JOIN1 has 3 incoming edges but not marked as merge

**Validation Error/Warning:**
- Warning about merge node not marked

**Expected Fix:**
- Type: `MARK_MERGE_NODE`
- Operation: `set_node_merge_flag` on JOIN1
- Severity: `safe`

**Expected Result:**
- JOIN1 marked as merge node
- Warning disappears

---

## Test Case 10: Multi-branch Split → Infer Split

**Setup:**
- Graph has operation node "OP1"
- OP1 has 3 outgoing edges (normal edges, not conditional)
- OP1 is not marked as parallel split

**Validation Error/Warning:**
- None (but structure implies split)

**Expected Fix:**
- Type: `MARK_SPLIT_NODE`
- Operation: `set_node_split_flag` on OP1
- Severity: `safe`

**Expected Result:**
- OP1 marked as `is_parallel_split = true`
- Graph structure correctly reflects parallel split

---

## Test Case 11: Legacy Graph → No Unwanted Fixes

**Setup:**
- Graph created before 2025-11-15 (legacy)
- Graph passes all validation rules
- Graph structure is valid but uses old patterns

**Validation Error/Warning:**
- None

**Expected Fix:**
- No fixes proposed (graph is valid)

**Expected Result:**
- `graph_autofix` returns `fix_count: 0`
- No unwanted structural changes

---

## Test Case 12: Excessive Branches → No Fix

**Setup:**
- Graph has node "OP1" with 10 outgoing edges (excessive, likely error)
- OP1 is not marked as split

**Validation Error/Warning:**
- Warning about excessive branches (if validation checks)

**Expected Fix:**
- No automatic fix (excessive branches require manual review)

**Expected Result:**
- `graph_autofix` does not propose split fix for excessive branches
- User must manually fix

---

## Test Case 13: Structural + Metadata Combined

**Setup:**
- Graph has QC node "QC1" with Pass→Finish + Rework (needs default flag) + missing fail_minor edge
- Graph has decision node "DEC1" with conditional but no default edge

**Validation Error/Warning:**
- Multiple errors/warnings

**Expected Fix:**
- Multiple fixes:
  1. `QC_DEFAULT_REWORK` (metadata) - mark rework as default
  2. `QC_FULL_COVERAGE` (structural) - create fail_minor edge
  3. `CREATE_ELSE_EDGE` (structural) - create default edge for DEC1

**Expected Result:**
- All fixes applied correctly
- Both metadata and structural changes work together

---

## Test Case 14: Incomplete Group of Conditional Edges

**Setup:**
- Graph has decision node "DEC1"
- DEC1 has 2 conditional edges:
  - `job.priority == 'high'` → FastPath
  - `job.priority == 'medium'` → NormalPath
- Missing default edge for 'low' priority

**Validation Error/Warning:**
- Warning about incomplete coverage

**Expected Fix:**
- Type: `CREATE_ELSE_EDGE`
- Operation: `create_edge` (normal, is_default=true) from DEC1 to nearest valid node
- Severity: `safe`

**Expected Result:**
- Default edge created
- All priorities covered

---

## Test Case 15: END Normalization Only (No Structural Change)

**Setup:**
- Graph has node "END1" with `node_type = 'end'`
- END1 has `node_params.is_end = false` (inconsistent metadata)
- Graph structure is valid

**Validation Error/Warning:**
- None (metadata inconsistency only)

**Expected Fix:**
- Type: `START_END_NORMALIZATION` (v1 metadata fix)
- Operation: `set_node_end_flag` on END1
- Severity: `safe`

**Expected Result:**
- Metadata synchronized
- No structural changes (v1 fix only)

---

## Summary

| Test Case | Pattern | Expected Fix | Status |
|-----------|--------|--------------|--------|
| 1 | QC missing fail_major | Create edge | ✅ |
| 2 | QC missing fail_minor | Create edge | ✅ |
| 3 | No END node | Create END + edges | ✅ |
| 4 | Parallel → merge | Mark merge | ✅ |
| 5 | Conditional no default | Create default edge | ✅ |
| 6 | Dangling node | Auto-connect | ✅ |
| 7 | Orphan node | Auto-connect | ✅ |
| 8 | QC no rework | Create rework path | ✅ |
| 9 | Multi-branch join | Infer merge | ✅ |
| 10 | Multi-branch split | Infer split | ✅ |
| 11 | Legacy graph | No fix | ✅ |
| 12 | Excessive branches | No fix | ✅ |
| 13 | Structural + metadata | Combined fixes | ✅ |
| 14 | Incomplete conditionals | Create default | ✅ |
| 15 | END normalization | Metadata only | ✅ |

---

## Notes

- **v2 Limitations**: AutoFix Engine v2 does NOT:
  - Create visible nodes other than END
  - Create whole subgraphs
  - Auto-create JOIN/SPLIT nodes explicitly (uses inferred metadata)
  - Change `work_center_code`, `behavior_code`, or `execution_mode`
  - Auto-create parallel branches without explicit user intent

- **Safety**: All structural fixes in v2 are marked as `severity: 'safe'` and only complete or repair structures that are already strongly implied by the graph design.

- **User Confirmation**: All structural fixes require user selection and confirmation before application.

