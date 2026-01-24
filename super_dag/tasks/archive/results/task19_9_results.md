# Task 19.9 Results – Graph AutoFix Engine v2 (Structural Repairs)

## Overview

Task 19.9 successfully expanded AutoFix Engine from metadata-only fixes (v1) to structural graph repairs (v2), including creating edges and nodes to complete graph structures.

**Completion Date:** 2025-12-19  
**Status:** ✅ Completed

---

## Problem Analysis

### Issues Resolved

1. **QC Full Coverage**
   - **Before:** Users manually had to create conditional edges for each QC status
   - **After:** AutoFix detects missing QC statuses and creates dedicated edges automatically

2. **Missing Default Routes**
   - **Before:** Decision nodes with conditional edges required manual default edge creation
   - **After:** AutoFix creates default ELSE edges to nearest valid node

3. **Missing END Node**
   - **Before:** Terminal operations without END node caused validation errors
   - **After:** AutoFix creates END node and connects terminal operations

4. **Unreachable Nodes**
   - **Before:** Orphan nodes required manual connection
   - **After:** AutoFix connects unreachable nodes to main flow

5. **Missing Rework Paths**
   - **Before:** QC nodes requiring rework had to manually create rework edges
   - **After:** AutoFix creates rework paths when QC policy requires it

6. **Parallel Structure Detection**
   - **Before:** Merge/split nodes required manual flag setting
   - **After:** AutoFix infers and marks merge/split nodes from graph structure

---

## Implementation

### GraphAutoFixEngine.php (Extended)

**New Method:** `generateStructuralFixes()`

**Key Methods Added:**
- `suggestQCFullCoverage()` - Pattern 1: Create QC edges for full coverage
- `suggestCreateElseEdge()` - Pattern 2: Create default ELSE edges
- `suggestCreateEndNode()` - Pattern 3: Create END node
- `suggestConnectUnreachable()` - Pattern 4: Connect unreachable nodes
- `suggestCreateReworkPath()` - Pattern 5: Create rework paths
- `suggestMarkMergeNode()` - Pattern 6: Mark merge nodes
- `suggestMarkSplitNode()` - Pattern 7: Mark split nodes

**Structural Fix Patterns Implemented:**

1. **QC Full Coverage Pattern**
   - Detects: QC node with pass edge + rework edge, missing fail_minor/fail_major
   - Creates: Conditional edges for each missing status → ReworkSink
   - Severity: `safe`

2. **Default ELSE Edge Pattern**
   - Detects: Node with ≥1 conditional edges, 0 normal edges
   - Creates: Normal edge (is_default=true) to nearest valid node
   - Severity: `safe`

3. **END Node Creation Pattern**
   - Detects: No END node, terminal operations with 0 outgoing edges
   - Creates: END node + edges from terminal operations
   - Severity: `safe`

4. **Unreachable Node Connection Pattern**
   - Detects: Node with 0 incoming edges, not START
   - Creates: Edge from START (or nearest upstream) to unreachable node
   - Severity: `safe`

5. **Rework Path Creation Pattern**
   - Detects: QC node with `require_rework_edge=true`, no rework edge
   - Creates: Rework edge to REWORK_SINK with fail_minor & fail_major conditions
   - Severity: `safe`

6. **Merge Node Marking Pattern**
   - Detects: Node with 2+ incoming edges from parallel branches
   - Marks: `is_merge_node = true`
   - Severity: `safe`

7. **Split Node Marking Pattern**
   - Detects: Node with 2+ outgoing normal edges (not conditional)
   - Marks: `is_parallel_split = true`
   - Severity: `safe`

### API Integration

**Updated Action:** `graph_autofix`

**New Mode Parameter:**
- `mode=metadata` - v1 fixes only (default, backward compatible)
- `mode=structural` - v1 + v2 fixes (includes structural repairs)

**Input:**
```json
{
  "action": "graph_autofix",
  "id": 123,
  "mode": "structural"
}
```

**Output (Extended):**
```json
{
  "ok": true,
  "fix_count": 3,
  "fixes": [
    {
      "id": "FIX-QC-FULL-COVERAGE-QC1",
      "type": "QC_FULL_COVERAGE",
      "severity": "safe",
      "operations": [
        {
          "op": "create_edge",
          "from_node_id": 12,
          "from_node_code": "QC1",
          "to_node_id": 98,
          "to_node_code": "REWORK_SINK1",
          "edge_type": "conditional",
          "edge_condition": {
            "type": "token_property",
            "property": "qc_result.status",
            "operator": "==",
            "value": "fail_major"
          }
        }
      ]
    }
  ],
  "patched_nodes": [],
  "patched_edges": []
}
```

### Frontend Integration

**Location:** `assets/javascripts/dag/graph_designer.js`

**Enhanced Functions:**
- `showAutoFixDialog()` - Now calls API with `mode=structural`
- `showFixesSelectionDialog()` - Enhanced with structural preview
- `applyFixes()` - Handles structural operations
- `applyFixOperation()` - Extended with `create_edge`, `create_node`, `set_node_merge_flag`, `set_node_split_flag`

**New UI Features:**
- **Structural Preview:** Shows which edges/nodes will be created
- **Visual Indicators:** Highlights source/target nodes for new edges
- **Warning Banner:** Alerts user about structural changes
- **Badge Labels:** "Structural" badge for fixes that create edges/nodes

**New Operations Supported:**
- `create_edge` - Creates new edge in graph
- `create_node` - Creates new node in graph
- `set_node_merge_flag` - Marks node as merge
- `set_node_split_flag` - Marks node as split

---

## Test Cases

**File:** `docs/super_dag/tests/autofix_v2_test_cases.md`

**Total:** 15 test cases covering:
- ✅ QC full coverage (fail_minor, fail_major)
- ✅ END node creation
- ✅ Default ELSE edge creation
- ✅ Unreachable node connection
- ✅ Rework path creation
- ✅ Merge/split node marking
- ✅ Legacy graph compatibility
- ✅ Excessive branches (no fix)
- ✅ Combined structural + metadata fixes

---

## Safety & Constraints

### v2 Limitations (Explicitly Out of Scope)

✅ **Implemented:**
- Create edges (QC coverage, ELSE routes, rework paths, connections)
- Create END node (only visible node creation allowed)
- Mark merge/split nodes (metadata flags)

❌ **NOT Implemented (v2):**
- Creating visible nodes other than END
- Creating whole subgraphs
- Auto-creating JOIN/SPLIT nodes explicitly (uses inferred metadata)
- Changing `work_center_code`, `behavior_code`, or `execution_mode`
- Auto-creating parallel branches without explicit user intent

### Safety Guarantees

1. **No DB Writes in API**
   - `graph_autofix` is read-only
   - Fixes are applied via frontend UI only
   - Changes go through normal `graph_save` flow

2. **User Confirmation Required**
   - All structural fixes require user selection
   - Preview shows exactly what will be created
   - Warning banner for structural changes

3. **Deterministic Patterns**
   - Only repairs structures that are strongly implied
   - Does not alter intended behavior
   - Idempotent: Same input = same output

4. **Backward Compatible**
   - Default mode is `metadata` (v1 only)
   - Legacy graphs work without issues
   - Structural mode is opt-in

---

## Acceptance Criteria Status

| Requirement | Status |
|------------|--------|
| GraphAutoFixEngine supports v2 structural fixes | ✅ Complete |
| dag_routing_api.php exposes structural mode | ✅ Complete |
| GraphDesigner UI supports preview & confirmation | ✅ Complete |
| QC full-coverage creation works | ✅ Complete |
| Default edges created correctly | ✅ Complete |
| END node creation safe | ✅ Complete |
| Parallel merge marking correct | ✅ Complete |
| No unsafe fixes (semantics preserved) | ✅ Complete |
| All fixes idempotent | ✅ Complete |
| Tests written (15+) | ✅ Complete |

---

## Example Usage

### Scenario: QC Node Missing fail_minor Edge

**Before:**
- QC node "QC1" has:
  - Conditional edge: `qc_result.status == 'pass'` → Finish
  - Rework edge (no condition) → ReworkSink
- Validation error: "QC node QC1 → Missing QC route for: fail_minor"

**User Action:**
1. Clicks "Save graph"
2. Sees validation error dialog
3. Clicks "Try Auto-Fix" button
4. Sees fix: "Create QC edges for missing statuses: fail_minor"
5. Preview shows: "Will create: Edge: QC1 → REWORK_SINK1"
6. Selects fix → Clicks "Apply Selected"

**After:**
- New conditional edge created: QC1 → ReworkSink (fail_minor)
- Edge appears in graph with highlight
- Validation error disappears
- Graph can be saved successfully

---

## Future Work (Task 19.10+)

Potential enhancements for future tasks:
- Auto-position new nodes (END node placement)
- Smart edge routing (avoid overlaps)
- Batch structural fixes (apply all safe fixes at once)
- Undo/redo for structural fixes
- More sophisticated merge/split detection

---

## Summary

Task 19.9 successfully expanded AutoFix Engine to v2, adding structural graph repair capabilities:
- ✅ Creates edges for QC full coverage
- ✅ Creates default ELSE edges
- ✅ Creates END node when missing
- ✅ Connects unreachable nodes
- ✅ Creates rework paths for QC
- ✅ Marks merge/split nodes automatically
- ✅ Maintains safety and user confirmation
- ✅ 100% backward compatible with v1

The AutoFix Engine v2 completes graph structures that are strongly implied by the design, reducing manual work while preserving user control and graph semantics.

