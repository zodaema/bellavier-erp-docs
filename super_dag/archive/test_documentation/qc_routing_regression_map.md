# QC & Conditional Routing Regression Map

**Date:** 2025-12-18  
**Purpose:** Complete regression map for QC routing and conditional edge evaluation  
**Coverage:** Task 19.0 (Unified Condition Model), Task 19.1 (Unified UX), Task 19.2 (Multi-Group Support)

> **⚠️ IMPORTANT:** This document describes **expected behavior** for QC routing and conditional edges. Any changes to routing logic must pass all scenarios documented here.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Global Assumptions](#global-assumptions)
3. [Scenario Catalog](#scenario-catalog)
4. [Edge Cases & Known Limitations](#edge-cases--known-limitations)
5. [How to Extend](#how-to-extend)

---

## Introduction

This regression map documents all expected behaviors for:
- **QC Routing:** Token routing based on QC results (pass, fail_minor, fail_major)
- **Conditional Edges:** Single condition, multi-condition (AND), multi-group (OR of AND)
- **Default Routes:** Explicit default/else edges with `{ type: "expression", expression: "true" }`
- **Error Handling:** Unroutable tokens, ambiguous routing, validation errors

**Purpose:**
- Prevent silent regressions when routing logic changes
- Provide clear test scenarios for QA
- Document expected behavior for developers
- Enable automated testing (if CLI harness implemented)

**Scope:**
- ✅ QC routing with conditional edges
- ✅ Multi-group condition evaluation
- ✅ Default route handling
- ✅ Error scenarios (unroutable, ambiguous)
- ✅ Legacy graph compatibility
- ❌ Machine allocation / Parallel execution (separate scope)
- ❌ Merge semantics (separate scope)

---

## Global Assumptions

### 1. Condition Evaluation

**Location:** `DAGRoutingService::selectNextNode()` → `ConditionEvaluator::evaluate()`

**Available Properties:**
- `token_property`: `qc_result.status`, `qc_result.defect_type`, `qc_result.severity`, `token.qty`, `token.priority`, `token.rework_count`
- `job_property`: `job.priority`, `job.target_qty`, `job.process_mode`
- `node_property`: `node.node_type`, `node.work_center_code`

**QC Result Properties:**
- `qc_result.status`: `'pass'`, `'fail_minor'`, `'fail_major'`
- `qc_result.defect_type`: String (e.g., 'stitch', 'color', 'size')
- `qc_result.severity`: `'minor'`, `'major'`

**Operators:**
- Equality: `==`, `!=`
- Comparison: `>`, `>=`, `<`, `<=`
- Set: `IN`, `NOT_IN`
- String: `CONTAINS`, `STARTS_WITH`

### 2. Edge Evaluation Priority

**From `selectNextNode()` code:**
1. **Priority 1:** Conditional edges (`edge_type = 'conditional'`)
   - Evaluate all conditional edges
   - First matching condition wins
   - Task 19.2: Multi-group format supported (OR between groups, AND within groups)
2. **Priority 2:** Default edge (`is_default = true` or `{ type: "expression", expression: "true" }`)
3. **Priority 3:** Normal edges (`edge_type = 'normal'`)
4. **Priority 4:** First edge (fallback)

### 3. Multi-Group Condition Logic

**Task 19.2 Format:**
```json
{
  "type": "or",
  "groups": [
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass" }
      ]
    },
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "IN", "value": ["fail_minor", "fail_major"] }
      ]
    }
  ]
}
```

**Evaluation:**
- OR between groups: First group with all conditions matching wins
- AND within groups: All conditions in group must match
- If no groups match → Use default route or error

### 4. Error Scenarios

**Unroutable:**
- No conditional edge matches
- No default edge exists
- No normal edge exists
- Expected: `error_unroutable` or token stuck in `waiting` status

**Ambiguous:**
- Multiple conditional edges match simultaneously
- Expected: `error_ambiguous` or first match wins (implementation-dependent)

### 5. Token State

**Precondition for routing:**
- Token must be at node (status: `ready`, `active`, or `waiting`)
- QC result must be set in token metadata (for QC routing)
- Token must have valid `current_node_id`

**Post-routing:**
- Token status: `ready` (at new node)
- Event logged: `token_event` with `event_type = 'routed'`
- `current_node_id` updated to target node

---

## Scenario Catalog

### Scenario 1: QC_PASS_SIMPLE

**ID:** `QC_PASS_SIMPLE`  
**Description:** Simple QC pass routing with single condition

**Graph:**
```
[START] → [QC] → [FINISH]
            ↓
         (pass edge)
```

**Preconditions:**
- Graph has QC node with one outgoing conditional edge
- Edge condition: `{ type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }`
- Token at QC node with `qc_result.status = 'pass'`

**Steps:**
1. Token completes QC with result: `pass`
2. `DAGRoutingService::selectNextNode()` evaluates outgoing edges
3. Conditional edge condition matches
4. Token routed to FINISH node

**Expected Result:**
- ✅ Token routed to FINISH node
- ✅ Token status: `ready`
- ✅ Event logged: `event_type = 'routed'`, `from_node_id = QC`, `to_node_id = FINISH`
- ✅ No errors

**Edge Condition:**
```json
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "pass"
}
```

---

### Scenario 2: QC_FAIL_MINOR_REWORK

**ID:** `QC_FAIL_MINOR_REWORK`  
**Description:** QC fail_minor routes to rework node

**Graph:**
```
[START] → [QC] → [REWORK]
            ↓
         (fail edge)
```

**Preconditions:**
- Graph has QC node with one outgoing conditional edge
- Edge condition: `{ type: "token_property", property: "qc_result.status", operator: "IN", "value": ["fail_minor", "fail_major"] }`
- Token at QC node with `qc_result.status = 'fail_minor'`

**Steps:**
1. Token completes QC with result: `fail_minor`
2. `DAGRoutingService::selectNextNode()` evaluates outgoing edges
3. Conditional edge condition matches (fail_minor in [fail_minor, fail_major])
4. Token routed to REWORK node

**Expected Result:**
- ✅ Token routed to REWORK node
- ✅ Token status: `ready`
- ✅ Event logged: `event_type = 'routed'`, `from_node_id = QC`, `to_node_id = REWORK`
- ✅ No errors

**Edge Condition:**
```json
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "IN",
  "value": ["fail_minor", "fail_major"]
}
```

---

### Scenario 3: QC_FAIL_MAJOR_SCRAP

**ID:** `QC_FAIL_MAJOR_SCRAP`  
**Description:** QC fail_major routes to scrap/exception node

**Graph:**
```
[START] → [QC] → [SCRAP]
            ↓
         (fail_major edge)
```

**Preconditions:**
- Graph has QC node with one outgoing conditional edge
- Edge condition: `{ type: "token_property", property: "qc_result.status", operator: "==", value: "fail_major" }`
- Token at QC node with `qc_result.status = 'fail_major'`

**Steps:**
1. Token completes QC with result: `fail_major`
2. `DAGRoutingService::selectNextNode()` evaluates outgoing edges
3. Conditional edge condition matches
4. Token routed to SCRAP node

**Expected Result:**
- ✅ Token routed to SCRAP node
- ✅ Token status: `ready` (or `scrapped` if scrap logic implemented)
- ✅ Event logged: `event_type = 'routed'` or `'scrapped'`
- ✅ No errors

**Edge Condition:**
```json
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "fail_major"
}
```

---

### Scenario 4: QC_DEFAULT_ELSE_ROUTE

**ID:** `QC_DEFAULT_ELSE_ROUTE`  
**Description:** Default route used when no conditional edge matches

**Graph:**
```
[START] → [QC] → [FINISH] (pass edge)
            ↓
         [DEFAULT] (default edge)
```

**Preconditions:**
- Graph has QC node with two outgoing edges:
  - Conditional edge: `qc_result.status == 'pass'` → FINISH
  - Default edge: `{ type: "expression", expression: "true" }` → DEFAULT
- Token at QC node with `qc_result.status = 'fail_minor'` (doesn't match pass condition)

**Steps:**
1. Token completes QC with result: `fail_minor`
2. `DAGRoutingService::selectNextNode()` evaluates outgoing edges
3. Conditional edge (pass) doesn't match
4. Default edge matches (always true)
5. Token routed to DEFAULT node

**Expected Result:**
- ✅ Token routed to DEFAULT node (not FINISH)
- ✅ Token status: `ready`
- ✅ Event logged: `event_type = 'routed'`, `from_node_id = QC`, `to_node_id = DEFAULT`
- ✅ No errors

**Edge Conditions:**
```json
// Conditional edge
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "pass"
}

// Default edge
{
  "type": "expression",
  "expression": "true"
}
```

---

### Scenario 5: NO_MATCH_UNROUTABLE

**ID:** `NO_MATCH_UNROUTABLE`  
**Description:** Error when no edge matches and no default route exists

**Graph:**
```
[START] → [QC] → [FINISH] (pass edge only)
```

**Preconditions:**
- Graph has QC node with one outgoing conditional edge
- Edge condition: `qc_result.status == 'pass'` → FINISH
- No default edge exists
- Token at QC node with `qc_result.status = 'fail_minor'` (doesn't match pass condition)

**Steps:**
1. Token completes QC with result: `fail_minor`
2. `DAGRoutingService::selectNextNode()` evaluates outgoing edges
3. Conditional edge (pass) doesn't match
4. No default edge exists
5. No normal edge exists
6. Routing fails

**Expected Result:**
- ❌ Token NOT routed (stays at QC node or error)
- ❌ Error: `error_unroutable` or token status: `waiting` / `stuck`
- ❌ Event logged: `event_type = 'routing_failed'` or similar
- ⚠️ Token may require manual intervention

**Edge Condition:**
```json
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "pass"
}
```

---

### Scenario 6: AMBIGUOUS_MATCH_ERROR

**ID:** `AMBIGUOUS_MATCH_ERROR`  
**Description:** Multiple edges match simultaneously (ambiguous routing)

**Graph:**
```
[START] → [QC] → [PATH_A] (condition: qty >= 1)
            ↓
         [PATH_B] (condition: qty >= 0)
```

**Preconditions:**
- Graph has QC node with two outgoing conditional edges
- Edge 1: `{ type: "token_property", property: "token.qty", operator: ">=", value: 1 }` → PATH_A
- Edge 2: `{ type: "token_property", property: "token.qty", operator: ">=", value: 0 }` → PATH_B
- Token at QC node with `token.qty = 5` (matches both conditions)

**Steps:**
1. Token at QC node with `token.qty = 5`
2. `DAGRoutingService::selectNextNode()` evaluates outgoing edges
3. Both conditional edges match (5 >= 1 and 5 >= 0)
4. Ambiguous routing detected

**Expected Result:**
- ⚠️ Implementation-dependent:
  - Option A: First match wins (PATH_A selected)
  - Option B: Error `error_ambiguous`
  - Option C: Priority-based selection (if priority field used)
- ⚠️ Document actual behavior in results

**Edge Conditions:**
```json
// Edge 1
{
  "type": "token_property",
  "property": "token.qty",
  "operator": ">=",
  "value": 1
}

// Edge 2
{
  "type": "token_property",
  "property": "token.qty",
  "operator": ">=",
  "value": 0
}
```

---

### Scenario 7: QC_TEMPLATE_A_BASIC_SPLIT

**ID:** `QC_TEMPLATE_A_BASIC_SPLIT`  
**Description:** Template A from Task 19.2 (Basic QC Split)

**Graph:**
```
[START] → [QC] → [FINISH] (pass edge)
            ↓
         [REWORK] (fail edge)
```

**Preconditions:**
- Graph has QC node with two outgoing conditional edges
- Edge 1 (Pass): `{ type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }` → FINISH
- Edge 2 (Fail): `{ type: "token_property", property: "qc_result.status", operator: "IN", value: ["fail_minor", "fail_major"] }` → REWORK
- Token at QC node

**Test Cases:**
- **Case 7a:** `qc_result.status = 'pass'` → Routes to FINISH
- **Case 7b:** `qc_result.status = 'fail_minor'` → Routes to REWORK
- **Case 7c:** `qc_result.status = 'fail_major'` → Routes to REWORK

**Expected Result:**
- ✅ All QC statuses covered
- ✅ Pass → FINISH, Fail → REWORK
- ✅ No errors

**Edge Conditions:**
```json
// Edge 1 (Pass)
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "pass"
}

// Edge 2 (Fail)
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "IN",
  "value": ["fail_minor", "fail_major"]
}
```

---

### Scenario 8: QC_TEMPLATE_B_SEVERITY_QTY

**ID:** `QC_TEMPLATE_B_SEVERITY_QTY`  
**Description:** Template B from Task 19.2 (Severity + Quantity)

**Graph:**
```
[START] → [QC] → [REWORK_MINOR] (fail_minor + qty >= 1)
            ↓
         [REWORK_MAJOR] (fail_major)
```

**Preconditions:**
- Graph has QC node with two outgoing conditional edges (multi-group format)
- Edge 1: Multi-group with AND condition:
  ```json
  {
    "type": "or",
    "groups": [
      {
        "type": "and",
        "conditions": [
          { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_minor" },
          { "type": "token_property", "property": "token.qty", "operator": ">=", "value": 1 }
        ]
      }
    ]
  }
  ```
- Edge 2: `{ type: "token_property", property: "qc_result.status", operator: "==", value: "fail_major" }` → REWORK_MAJOR
- Token at QC node

**Test Cases:**
- **Case 8a:** `qc_result.status = 'fail_minor'`, `token.qty = 2` → Routes to REWORK_MINOR (both conditions match)
- **Case 8b:** `qc_result.status = 'fail_minor'`, `token.qty = 0` → No match for Edge 1, check Edge 2
- **Case 8c:** `qc_result.status = 'fail_major'` → Routes to REWORK_MAJOR (Edge 2 matches)

**Expected Result:**
- ✅ fail_minor + qty >= 1 → REWORK_MINOR
- ✅ fail_major → REWORK_MAJOR
- ⚠️ fail_minor + qty < 1 → May be unroutable (depends on default edge)

**Edge Conditions:**
```json
// Edge 1 (Multi-group with AND)
{
  "type": "or",
  "groups": [
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_minor" },
        { "type": "token_property", "property": "token.qty", "operator": ">=", "value": 1 }
      ]
    }
  ]
}

// Edge 2
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "fail_major"
}
```

---

### Scenario 9: MULTI_GROUP_OR_LOGIC

**ID:** `MULTI_GROUP_OR_LOGIC`  
**Description:** Multi-group OR logic (Task 19.2)

**Graph:**
```
[START] → [QC] → [PATH_A] (Group 1: pass)
            ↓
         [PATH_B] (Group 2: fail_minor OR fail_major)
```

**Preconditions:**
- Graph has QC node with one outgoing conditional edge (multi-group format)
- Edge condition:
  ```json
  {
    "type": "or",
    "groups": [
      {
        "type": "and",
        "conditions": [
          { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass" }
        ]
      },
      {
        "type": "and",
        "conditions": [
          { "type": "token_property", "property": "qc_result.status", "operator": "IN", "value": ["fail_minor", "fail_major"] }
        ]
      }
    ]
  }
  ```
- Token at QC node

**Test Cases:**
- **Case 9a:** `qc_result.status = 'pass'` → Group 1 matches → Routes to PATH_A
- **Case 9b:** `qc_result.status = 'fail_minor'` → Group 2 matches → Routes to PATH_B
- **Case 9c:** `qc_result.status = 'fail_major'` → Group 2 matches → Routes to PATH_B

**Expected Result:**
- ✅ First matching group wins
- ✅ OR logic between groups works correctly
- ✅ All QC statuses covered

---

### Scenario 10: MULTI_GROUP_AND_WITHIN_GROUP

**ID:** `MULTI_GROUP_AND_WITHIN_GROUP`  
**Description:** AND logic within group (Task 19.2)

**Graph:**
```
[START] → [QC] → [SPECIAL_PATH] (status == fail_minor AND qty >= 5)
            ↓
         [NORMAL_PATH] (default)
```

**Preconditions:**
- Graph has QC node with two outgoing edges
- Edge 1: Multi-group with AND condition:
  ```json
  {
    "type": "or",
    "groups": [
      {
        "type": "and",
        "conditions": [
          { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_minor" },
          { "type": "token_property", "property": "token.qty", "operator": ">=", "value": 5 }
        ]
      }
    ]
  }
  ```
- Edge 2: Default edge `{ type: "expression", expression: "true" }` → NORMAL_PATH
- Token at QC node

**Test Cases:**
- **Case 10a:** `qc_result.status = 'fail_minor'`, `token.qty = 10` → Both conditions match → Routes to SPECIAL_PATH
- **Case 10b:** `qc_result.status = 'fail_minor'`, `token.qty = 3` → qty condition fails → Routes to NORMAL_PATH (default)
- **Case 10c:** `qc_result.status = 'pass'` → Status condition fails → Routes to NORMAL_PATH (default)

**Expected Result:**
- ✅ AND logic within group: All conditions must match
- ✅ If group doesn't match → Use default route
- ✅ No errors

---

### Scenario 11: LEGACY_CONDITION_MIGRATION

**ID:** `LEGACY_CONDITION_MIGRATION`  
**Description:** Legacy condition format converted to new format

**Graph:**
```
[START] → [QC] → [FINISH] (legacy condition format)
```

**Preconditions:**
- Graph has QC node with legacy condition format (pre-Task 19.0)
- Legacy format examples:
  - `{ qc: 'pass' }` (old format)
  - `{ condition_field: 'qc_result.status', condition_operator: '==', condition_value: 'pass' }` (old format)
- Token at QC node with `qc_result.status = 'pass'`

**Steps:**
1. Legacy condition loaded and converted to unified format
2. `ConditionEvaluator` evaluates converted condition
3. Token routed based on converted condition

**Expected Result:**
- ✅ Legacy format converted correctly
- ✅ Routing behavior matches new format
- ✅ No errors
- ⚠️ Document conversion mapping in results

**Legacy → New Mapping:**
- `{ qc: 'pass' }` → `{ type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }`
- `{ condition_field: '...', condition_operator: '...', condition_value: '...' }` → Unified format

---

### Scenario 12: QC_PARALLEL_BRANCH_SAFE

**ID:** `QC_PARALLEL_BRANCH_SAFE`  
**Description:** QC routing before parallel split (minimal case)

**Graph:**
```
[START] → [QC] → [SPLIT] → [BRANCH_A]
            ↓              → [BRANCH_B]
         (pass edge)
```

**Preconditions:**
- Graph has QC node with conditional edge → SPLIT node
- SPLIT node is parallel split (spawns multiple tokens)
- Edge condition: `qc_result.status == 'pass'` → SPLIT
- Token at QC node with `qc_result.status = 'pass'`

**Steps:**
1. Token completes QC with result: `pass`
2. Conditional edge matches
3. Token routed to SPLIT node
4. SPLIT node spawns parallel branches (separate flow)

**Expected Result:**
- ✅ QC routing works correctly before parallel split
- ✅ Token routed to SPLIT node
- ✅ Parallel split behavior unchanged
- ✅ No interference between QC routing and parallel logic

**Edge Condition:**
```json
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "pass"
}
```

---

### Scenario 13: QC_FULL_COVERAGE_VALIDATION

**ID:** `QC_FULL_COVERAGE_VALIDATION`  
**Description:** All QC statuses must be covered (Task 19.1, 19.2 validation)

**Graph:**
```
[START] → [QC] → [FINISH] (pass edge)
            ↓
         [REWORK] (fail_minor edge)
         (Missing: fail_major edge)
```

**Preconditions:**
- Graph has QC node with two outgoing edges
- Edge 1: `qc_result.status == 'pass'` → FINISH
- Edge 2: `qc_result.status == 'fail_minor'` → REWORK
- Missing: Edge for `fail_major`
- No default edge

**Validation (Frontend - Task 19.1, 19.2):**
- `validateQCCoverage()` checks all outgoing edges
- Detects missing `fail_major` coverage
- Blocks save with error: "QC statuses not covered: fail_major"

**Expected Result:**
- ❌ Graph save blocked (frontend validation)
- ❌ Error message: "QC statuses not covered: fail_major"
- ✅ User must add edge for `fail_major` or default edge

---

### Scenario 14: QC_PARTIAL_COVERAGE_WITH_DEFAULT

**ID:** `QC_PARTIAL_COVERAGE_WITH_DEFAULT`  
**Description:** Partial QC coverage with default route (valid)

**Graph:**
```
[START] → [QC] → [FINISH] (pass edge)
            ↓
         [DEFAULT] (default edge)
```

**Preconditions:**
- Graph has QC node with two outgoing edges
- Edge 1: `qc_result.status == 'pass'` → FINISH
- Edge 2: Default edge `{ type: "expression", expression: "true" }` → DEFAULT
- Token at QC node

**Test Cases:**
- **Case 14a:** `qc_result.status = 'pass'` → Routes to FINISH (conditional edge matches)
- **Case 14b:** `qc_result.status = 'fail_minor'` → Routes to DEFAULT (default edge)
- **Case 14c:** `qc_result.status = 'fail_major'` → Routes to DEFAULT (default edge)

**Expected Result:**
- ✅ Pass → FINISH (conditional edge)
- ✅ Fail → DEFAULT (default edge)
- ✅ All QC statuses covered (pass explicitly, fail via default)
- ✅ No validation errors

---

### Scenario 15: SINGLE_CONDITION_LEGACY_FORMAT

**ID:** `SINGLE_CONDITION_LEGACY_FORMAT`  
**Description:** Single condition in legacy AND format (Task 19.2 conversion)

**Graph:**
```
[START] → [QC] → [FINISH] (legacy AND format)
```

**Preconditions:**
- Graph has QC node with legacy AND format condition:
  ```json
  {
    "type": "and",
    "conditions": [
      { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass" }
    ]
  }
  ```
- Token at QC node with `qc_result.status = 'pass'`

**Steps:**
1. Legacy AND format loaded
2. Converted to single-group format (Task 19.2)
3. Evaluated by `ConditionEvaluator`
4. Token routed

**Expected Result:**
- ✅ Legacy AND format converted correctly
- ✅ Single condition in AND group works
- ✅ Routing behavior unchanged
- ✅ No errors

---

### Scenario 16: LEGACY_OR_FORMAT_CONVERSION

**ID:** `LEGACY_OR_FORMAT_CONVERSION`  
**Description:** Legacy OR format converted to multi-group (Task 19.2)

**Graph:**
```
[START] → [QC] → [PATH_A] (legacy OR format)
            ↓
         [PATH_B]
```

**Preconditions:**
- Graph has QC node with legacy OR format condition:
  ```json
  {
    "type": "or",
    "conditions": [
      { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass" },
      { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_minor" }
    ]
  }
  ```
- Token at QC node

**Conversion (Task 19.2):**
- Legacy OR → Multi-group format:
  ```json
  {
    "type": "or",
    "groups": [
      { "type": "and", "conditions": [{ ...pass... }] },
      { "type": "and", "conditions": [{ ...fail_minor... }] }
    ]
  }
  ```

**Test Cases:**
- **Case 16a:** `qc_result.status = 'pass'` → Routes to PATH_A
- **Case 16b:** `qc_result.status = 'fail_minor'` → Routes to PATH_B

**Expected Result:**
- ✅ Legacy OR format converted to multi-group
- ✅ Each condition becomes separate group
- ✅ Routing behavior unchanged
- ✅ No errors

---

### Scenario 17: NON_QC_CONDITIONAL_ROUTING

**ID:** `NON_QC_CONDITIONAL_ROUTING`  
**Description:** Conditional routing from non-QC operation node

**Graph:**
```
[START] → [OPERATION] → [PATH_A] (qty >= 10)
            ↓
         [PATH_B] (qty < 10)
```

**Preconditions:**
- Graph has OPERATION node (not QC) with two outgoing conditional edges
- Edge 1: `{ type: "token_property", property: "token.qty", operator: ">=", value: 10 }` → PATH_A
- Edge 2: `{ type: "token_property", property: "token.qty", operator: "<", value: 10 }` → PATH_B
- Token at OPERATION node with `token.qty = 15`

**Steps:**
1. Token completes OPERATION
2. `DAGRoutingService::selectNextNode()` evaluates outgoing edges
3. Edge 1 matches (15 >= 10)
4. Token routed to PATH_A

**Expected Result:**
- ✅ Conditional routing works from non-QC nodes
- ✅ Token property conditions evaluated correctly
- ✅ Token routed to PATH_A
- ✅ No errors

---

### Scenario 18: JOB_PROPERTY_CONDITION

**ID:** `JOB_PROPERTY_CONDITION`  
**Description:** Conditional routing based on job properties

**Graph:**
```
[START] → [OPERATION] → [HIGH_PRIORITY] (job.priority == 'high')
            ↓
         [NORMAL_PRIORITY] (default)
```

**Preconditions:**
- Graph has OPERATION node with two outgoing edges
- Edge 1: `{ type: "job_property", property: "job.priority", operator: "==", value: "high" }` → HIGH_PRIORITY
- Edge 2: Default edge → NORMAL_PRIORITY
- Token at OPERATION node
- Job has `priority = 'high'`

**Steps:**
1. Token at OPERATION node
2. `DAGRoutingService::selectNextNode()` evaluates outgoing edges
3. Edge 1 matches (job.priority == 'high')
4. Token routed to HIGH_PRIORITY

**Expected Result:**
- ✅ Job property conditions evaluated correctly
- ✅ Token routed to HIGH_PRIORITY
- ✅ No errors

---

### Scenario 19: MULTI_GROUP_COMPLEX

**ID:** `MULTI_GROUP_COMPLEX`  
**Description:** Complex multi-group with multiple conditions per group

**Graph:**
```
[START] → [QC] → [PATH_A] (Group 1: pass)
            ↓
         [PATH_B] (Group 2: fail_minor + qty >= 5)
            ↓
         [PATH_C] (Group 3: fail_major)
            ↓
         [DEFAULT] (default)
```

**Preconditions:**
- Graph has QC node with multi-group conditional edge:
  ```json
  {
    "type": "or",
    "groups": [
      {
        "type": "and",
        "conditions": [
          { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass" }
        ]
      },
      {
        "type": "and",
        "conditions": [
          { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_minor" },
          { "type": "token_property", "property": "token.qty", "operator": ">=", "value": 5 }
        ]
      },
      {
        "type": "and",
        "conditions": [
          { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_major" }
        ]
      }
    ]
  }
  ```
- Default edge exists
- Token at QC node

**Test Cases:**
- **Case 19a:** `qc_result.status = 'pass'` → Group 1 matches → Routes to PATH_A
- **Case 19b:** `qc_result.status = 'fail_minor'`, `token.qty = 10` → Group 2 matches → Routes to PATH_B
- **Case 19c:** `qc_result.status = 'fail_minor'`, `token.qty = 3` → Group 2 fails, Group 3 fails → Routes to DEFAULT
- **Case 19d:** `qc_result.status = 'fail_major'` → Group 3 matches → Routes to PATH_C

**Expected Result:**
- ✅ OR logic between groups works
- ✅ AND logic within groups works
- ✅ Complex conditions evaluated correctly
- ✅ Default route used when no groups match

---

### Scenario 20: EXPRESSION_DEFAULT_ONLY

**ID:** `EXPRESSION_DEFAULT_ONLY`  
**Description:** Default route only (no conditional edges)

**Graph:**
```
[START] → [OPERATION] → [DEFAULT] (default edge only)
```

**Preconditions:**
- Graph has OPERATION node with one outgoing default edge
- Edge condition: `{ type: "expression", expression: "true" }` → DEFAULT
- Token at OPERATION node

**Steps:**
1. Token completes OPERATION
2. `DAGRoutingService::selectNextNode()` evaluates outgoing edges
3. Default edge matches (always true)
4. Token routed to DEFAULT

**Expected Result:**
- ✅ Default route works as only edge
- ✅ Token routed to DEFAULT
- ✅ No errors

---

## Edge Cases & Known Limitations

### 1. Ambiguous Routing Behavior

**Issue:** Multiple conditional edges match simultaneously

**Current Behavior:**
- Implementation-dependent (first match wins or error)
- Document actual behavior in test results

**Recommendation:**
- Use priority field for explicit ordering
- Or ensure conditions are mutually exclusive

### 2. Legacy Format Compatibility

**Issue:** Legacy condition formats may not convert perfectly

**Current Behavior:**
- Task 19.2 conversion handles most cases
- Some edge cases may require manual review

**Recommendation:**
- Test all legacy graphs after conversion
- Document any conversion issues

### 3. QC Result Availability

**Issue:** QC result must be set in token metadata before routing

**Current Behavior:**
- `ConditionEvaluator` reads from token metadata
- If QC result not set → Condition fails

**Recommendation:**
- Ensure QC result is set before routing
- Validate QC result exists for QC nodes

### 4. Default Route Priority

**Issue:** Default route evaluation order

**Current Behavior:**
- Default route evaluated after conditional edges
- If conditional edge matches → Default not used

**Recommendation:**
- Ensure conditional edges are mutually exclusive
- Use default route for "else" cases only

### 5. Multi-Group Performance

**Issue:** Large multi-group conditions may be slow

**Current Behavior:**
- Evaluates groups sequentially
- First matching group wins

**Recommendation:**
- Limit number of groups (e.g., < 10)
- Optimize condition evaluation if needed

---

## How to Extend

### Adding New Test Scenarios

1. **Create Scenario Entry:**
   - Use format: `### Scenario N: SCENARIO_NAME`
   - Include: ID, Description, Graph, Preconditions, Steps, Expected Result

2. **Document Edge Conditions:**
   - Include JSON format for all edge conditions
   - Specify condition types and operators

3. **Add Test Cases:**
   - Multiple test cases per scenario if applicable
   - Cover all relevant QC statuses or conditions

4. **Update Test Catalog:**
   - Add scenario to `qc_routing_test_cases.md`
   - Include in test harness if implemented

### Running Tests

**If CLI Harness Implemented:**
```bash
php tests/super_dag/QCRoutingSmokeTest.php
```

**Manual Testing:**
1. Create graph matching scenario
2. Set token state and QC result
3. Trigger routing
4. Verify token location and events
5. Compare with expected result

### Validating Changes

**Before modifying routing logic:**
1. Review all scenarios in this document
2. Identify affected scenarios
3. Run tests for affected scenarios
4. Verify no regressions

**After modifying routing logic:**
1. Run full test suite
2. Update scenarios if behavior changed
3. Document any breaking changes

---

**End of Regression Map**

