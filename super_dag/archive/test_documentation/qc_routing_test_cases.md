# QC & Conditional Routing Test Case Catalog

**Date:** 2025-12-18  
**Purpose:** Comprehensive test case catalog for QC routing and conditional edge evaluation  
**Coverage:** Task 19.0, 19.1, 19.2

> **⚠️ IMPORTANT:** This catalog contains **20+ test cases** covering all dimensions of QC routing and conditional edges. Use this for manual testing, automated testing, or regression validation.

---

## Table of Contents

1. [Test Case Categories](#test-case-categories)
2. [Test Cases](#test-cases)
3. [Test Execution Guide](#test-execution-guide)
4. [Coverage Matrix](#coverage-matrix)

---

## Test Case Categories

### Category 1: Simple QC Pass/Fail (5 cases)
- Basic QC routing with single conditions
- Pass, fail_minor, fail_major scenarios

### Category 2: Multi-Condition & Multi-Group (5 cases)
- AND logic within groups
- OR logic between groups
- Complex multi-group scenarios

### Category 3: Default Route & Coverage (3 cases)
- Default route handling
- QC coverage validation
- Partial coverage with default

### Category 4: Error Scenarios (3 cases)
- Unroutable tokens
- Ambiguous routing
- Missing conditions

### Category 5: Legacy Compatibility (2 cases)
- Legacy condition format conversion
- Legacy graph compatibility

### Category 6: Advanced Scenarios (2 cases)
- Non-QC conditional routing
- Job property conditions
- Parallel + QC integration

**Total: 20 test cases**

---

## Test Cases

### TC-001: QC_PASS_SIMPLE

**Category:** Simple QC Pass/Fail  
**Priority:** High  
**Scenario ID:** `QC_PASS_SIMPLE`

**Description:**  
Simple QC pass routing with single condition edge.

**Graph:**
```
[START] → [QC] → [FINISH]
            ↓
         (pass edge)
```

**Preconditions:**
- Graph: QC node with one outgoing conditional edge
- Edge condition: `{ type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }`
- Token: At QC node, `qc_result.status = 'pass'`

**Steps:**
1. Token completes QC with result: `pass`
2. Evaluate outgoing edges
3. Conditional edge matches
4. Route token to FINISH

**Expected Result:**
- ✅ Token routed to FINISH node
- ✅ Token status: `ready`
- ✅ Event: `routed` logged
- ✅ No errors

**Test Data:**
```json
{
  "token": {
    "id": 1,
    "current_node_id": 2,
    "qty": 1,
    "metadata": {
      "qc_result": {
        "status": "pass"
      }
    }
  },
  "edge_condition": {
    "type": "token_property",
    "property": "qc_result.status",
    "operator": "==",
    "value": "pass"
  }
}
```

---

### TC-002: QC_FAIL_MINOR_REWORK

**Category:** Simple QC Pass/Fail  
**Priority:** High  
**Scenario ID:** `QC_FAIL_MINOR_REWORK`

**Description:**  
QC fail_minor routes to rework node.

**Graph:**
```
[START] → [QC] → [REWORK]
            ↓
         (fail edge)
```

**Preconditions:**
- Graph: QC node with one outgoing conditional edge
- Edge condition: `{ type: "token_property", property: "qc_result.status", operator: "IN", value: ["fail_minor", "fail_major"] }`
- Token: At QC node, `qc_result.status = 'fail_minor'`

**Steps:**
1. Token completes QC with result: `fail_minor`
2. Evaluate outgoing edges
3. Conditional edge matches (fail_minor in [fail_minor, fail_major])
4. Route token to REWORK

**Expected Result:**
- ✅ Token routed to REWORK node
- ✅ Token status: `ready`
- ✅ Event: `routed` logged
- ✅ No errors

**Test Data:**
```json
{
  "token": {
    "id": 2,
    "current_node_id": 2,
    "qty": 1,
    "metadata": {
      "qc_result": {
        "status": "fail_minor"
      }
    }
  },
  "edge_condition": {
    "type": "token_property",
    "property": "qc_result.status",
    "operator": "IN",
    "value": ["fail_minor", "fail_major"]
  }
}
```

---

### TC-003: QC_FAIL_MAJOR_SCRAP

**Category:** Simple QC Pass/Fail  
**Priority:** High  
**Scenario ID:** `QC_FAIL_MAJOR_SCRAP`

**Description:**  
QC fail_major routes to scrap/exception node.

**Graph:**
```
[START] → [QC] → [SCRAP]
            ↓
         (fail_major edge)
```

**Preconditions:**
- Graph: QC node with one outgoing conditional edge
- Edge condition: `{ type: "token_property", property: "qc_result.status", operator: "==", value: "fail_major" }`
- Token: At QC node, `qc_result.status = 'fail_major'`

**Steps:**
1. Token completes QC with result: `fail_major`
2. Evaluate outgoing edges
3. Conditional edge matches
4. Route token to SCRAP

**Expected Result:**
- ✅ Token routed to SCRAP node
- ✅ Token status: `ready` or `scrapped`
- ✅ Event: `routed` or `scrapped` logged
- ✅ No errors

**Test Data:**
```json
{
  "token": {
    "id": 3,
    "current_node_id": 2,
    "qty": 1,
    "metadata": {
      "qc_result": {
        "status": "fail_major"
      }
    }
  },
  "edge_condition": {
    "type": "token_property",
    "property": "qc_result.status",
    "operator": "==",
    "value": "fail_major"
  }
}
```

---

### TC-004: QC_ALL_STATUSES_COVERED

**Category:** Simple QC Pass/Fail  
**Priority:** High  
**Scenario ID:** `QC_ALL_STATUSES_COVERED`

**Description:**  
All QC statuses (pass, fail_minor, fail_major) covered with separate edges.

**Graph:**
```
[START] → [QC] → [FINISH] (pass)
            ↓
         [REWORK] (fail_minor)
            ↓
         [SCRAP] (fail_major)
```

**Preconditions:**
- Graph: QC node with three outgoing conditional edges
- Edge 1: `qc_result.status == 'pass'` → FINISH
- Edge 2: `qc_result.status == 'fail_minor'` → REWORK
- Edge 3: `qc_result.status == 'fail_major'` → SCRAP
- Token: At QC node

**Test Cases:**
- **TC-004a:** `qc_result.status = 'pass'` → Routes to FINISH
- **TC-004b:** `qc_result.status = 'fail_minor'` → Routes to REWORK
- **TC-004c:** `qc_result.status = 'fail_major'` → Routes to SCRAP

**Expected Result:**
- ✅ All QC statuses covered
- ✅ Each status routes to correct node
- ✅ No errors

---

### TC-005: QC_PASS_FAIL_BINARY

**Category:** Simple QC Pass/Fail  
**Priority:** Medium  
**Scenario ID:** `QC_PASS_FAIL_BINARY`

**Description:**  
Binary QC split: pass vs fail (all fail types).

**Graph:**
```
[START] → [QC] → [FINISH] (pass)
            ↓
         [REWORK] (fail: fail_minor OR fail_major)
```

**Preconditions:**
- Graph: QC node with two outgoing conditional edges
- Edge 1: `qc_result.status == 'pass'` → FINISH
- Edge 2: `qc_result.status IN ['fail_minor', 'fail_major']` → REWORK
- Token: At QC node

**Test Cases:**
- **TC-005a:** `qc_result.status = 'pass'` → Routes to FINISH
- **TC-005b:** `qc_result.status = 'fail_minor'` → Routes to REWORK
- **TC-005c:** `qc_result.status = 'fail_major'` → Routes to REWORK

**Expected Result:**
- ✅ Pass → FINISH
- ✅ Fail (any) → REWORK
- ✅ No errors

---

### TC-006: MULTI_GROUP_OR_LOGIC

**Category:** Multi-Condition & Multi-Group  
**Priority:** High  
**Scenario ID:** `MULTI_GROUP_OR_LOGIC`

**Description:**  
Multi-group OR logic (Task 19.2).

**Graph:**
```
[START] → [QC] → [PATH_A] (Group 1: pass)
            ↓
         [PATH_B] (Group 2: fail_minor OR fail_major)
```

**Preconditions:**
- Graph: QC node with one outgoing conditional edge (multi-group)
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
- Token: At QC node

**Test Cases:**
- **TC-006a:** `qc_result.status = 'pass'` → Group 1 matches → Routes to PATH_A
- **TC-006b:** `qc_result.status = 'fail_minor'` → Group 2 matches → Routes to PATH_B
- **TC-006c:** `qc_result.status = 'fail_major'` → Group 2 matches → Routes to PATH_B

**Expected Result:**
- ✅ OR logic between groups works
- ✅ First matching group wins
- ✅ No errors

---

### TC-007: MULTI_GROUP_AND_WITHIN_GROUP

**Category:** Multi-Condition & Multi-Group  
**Priority:** High  
**Scenario ID:** `MULTI_GROUP_AND_WITHIN_GROUP`

**Description:**  
AND logic within group (Task 19.2).

**Graph:**
```
[START] → [QC] → [SPECIAL_PATH] (status == fail_minor AND qty >= 5)
            ↓
         [NORMAL_PATH] (default)
```

**Preconditions:**
- Graph: QC node with two outgoing edges
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
- Token: At QC node

**Test Cases:**
- **TC-007a:** `qc_result.status = 'fail_minor'`, `token.qty = 10` → Both conditions match → Routes to SPECIAL_PATH
- **TC-007b:** `qc_result.status = 'fail_minor'`, `token.qty = 3` → qty condition fails → Routes to NORMAL_PATH (default)
- **TC-007c:** `qc_result.status = 'pass'` → Status condition fails → Routes to NORMAL_PATH (default)

**Expected Result:**
- ✅ AND logic within group: All conditions must match
- ✅ If group doesn't match → Use default route
- ✅ No errors

---

### TC-008: QC_TEMPLATE_A_BASIC_SPLIT

**Category:** Multi-Condition & Multi-Group  
**Priority:** High  
**Scenario ID:** `QC_TEMPLATE_A_BASIC_SPLIT`

**Description:**  
Template A from Task 19.2 (Basic QC Split).

**Graph:**
```
[START] → [QC] → [FINISH] (pass edge)
            ↓
         [REWORK] (fail edge)
```

**Preconditions:**
- Graph: QC node with two outgoing conditional edges
- Edge 1 (Pass): `{ type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }` → FINISH
- Edge 2 (Fail): `{ type: "token_property", property: "qc_result.status", operator: "IN", value: ["fail_minor", "fail_major"] }` → REWORK
- Token: At QC node

**Test Cases:**
- **TC-008a:** `qc_result.status = 'pass'` → Routes to FINISH
- **TC-008b:** `qc_result.status = 'fail_minor'` → Routes to REWORK
- **TC-008c:** `qc_result.status = 'fail_major'` → Routes to REWORK

**Expected Result:**
- ✅ All QC statuses covered
- ✅ Pass → FINISH, Fail → REWORK
- ✅ No errors

---

### TC-009: QC_TEMPLATE_B_SEVERITY_QTY

**Category:** Multi-Condition & Multi-Group  
**Priority:** High  
**Scenario ID:** `QC_TEMPLATE_B_SEVERITY_QTY`

**Description:**  
Template B from Task 19.2 (Severity + Quantity).

**Graph:**
```
[START] → [QC] → [REWORK_MINOR] (fail_minor + qty >= 1)
            ↓
         [REWORK_MAJOR] (fail_major)
```

**Preconditions:**
- Graph: QC node with two outgoing conditional edges (multi-group format)
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
- Token: At QC node

**Test Cases:**
- **TC-009a:** `qc_result.status = 'fail_minor'`, `token.qty = 2` → Both conditions match → Routes to REWORK_MINOR
- **TC-009b:** `qc_result.status = 'fail_minor'`, `token.qty = 0` → qty condition fails → May be unroutable (depends on default)
- **TC-009c:** `qc_result.status = 'fail_major'` → Routes to REWORK_MAJOR

**Expected Result:**
- ✅ fail_minor + qty >= 1 → REWORK_MINOR
- ✅ fail_major → REWORK_MAJOR
- ⚠️ fail_minor + qty < 1 → May be unroutable (depends on default edge)

---

### TC-010: MULTI_GROUP_COMPLEX

**Category:** Multi-Condition & Multi-Group  
**Priority:** Medium  
**Scenario ID:** `MULTI_GROUP_COMPLEX`

**Description:**  
Complex multi-group with multiple conditions per group.

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
- Graph: QC node with multi-group conditional edge (see Scenario 19 in Regression Map)
- Default edge exists
- Token: At QC node

**Test Cases:**
- **TC-010a:** `qc_result.status = 'pass'` → Group 1 matches → Routes to PATH_A
- **TC-010b:** `qc_result.status = 'fail_minor'`, `token.qty = 10` → Group 2 matches → Routes to PATH_B
- **TC-010c:** `qc_result.status = 'fail_minor'`, `token.qty = 3` → Group 2 fails, Group 3 fails → Routes to DEFAULT
- **TC-010d:** `qc_result.status = 'fail_major'` → Group 3 matches → Routes to PATH_C

**Expected Result:**
- ✅ OR logic between groups works
- ✅ AND logic within groups works
- ✅ Complex conditions evaluated correctly
- ✅ Default route used when no groups match

---

### TC-011: QC_DEFAULT_ELSE_ROUTE

**Category:** Default Route & Coverage  
**Priority:** High  
**Scenario ID:** `QC_DEFAULT_ELSE_ROUTE`

**Description:**  
Default route used when no conditional edge matches.

**Graph:**
```
[START] → [QC] → [FINISH] (pass edge)
            ↓
         [DEFAULT] (default edge)
```

**Preconditions:**
- Graph: QC node with two outgoing edges
- Edge 1: `qc_result.status == 'pass'` → FINISH
- Edge 2: Default edge `{ type: "expression", expression: "true" }` → DEFAULT
- Token: At QC node, `qc_result.status = 'fail_minor'` (doesn't match pass condition)

**Steps:**
1. Token completes QC with result: `fail_minor`
2. Evaluate outgoing edges
3. Conditional edge (pass) doesn't match
4. Default edge matches (always true)
5. Route token to DEFAULT

**Expected Result:**
- ✅ Token routed to DEFAULT node (not FINISH)
- ✅ Token status: `ready`
- ✅ Event: `routed` logged
- ✅ No errors

---

### TC-012: QC_FULL_COVERAGE_VALIDATION

**Category:** Default Route & Coverage  
**Priority:** High  
**Scenario ID:** `QC_FULL_COVERAGE_VALIDATION`

**Description:**  
Frontend validation ensures all QC statuses are covered.

**Graph:**
```
[START] → [QC] → [FINISH] (pass edge)
            ↓
         [REWORK] (fail_minor edge)
         (Missing: fail_major edge)
```

**Preconditions:**
- Graph: QC node with two outgoing edges
- Edge 1: `qc_result.status == 'pass'` → FINISH
- Edge 2: `qc_result.status == 'fail_minor'` → REWORK
- Missing: Edge for `fail_major`
- No default edge

**Validation (Frontend - Task 19.1, 19.2):**
- `validateQCCoverage()` checks all outgoing edges
- Detects missing `fail_major` coverage
- Blocks save with error

**Expected Result:**
- ❌ Graph save blocked (frontend validation)
- ❌ Error message: "QC statuses not covered: fail_major"
- ✅ User must add edge for `fail_major` or default edge

---

### TC-013: QC_PARTIAL_COVERAGE_WITH_DEFAULT

**Category:** Default Route & Coverage  
**Priority:** High  
**Scenario ID:** `QC_PARTIAL_COVERAGE_WITH_DEFAULT`

**Description:**  
Partial QC coverage with default route (valid).

**Graph:**
```
[START] → [QC] → [FINISH] (pass edge)
            ↓
         [DEFAULT] (default edge)
```

**Preconditions:**
- Graph: QC node with two outgoing edges
- Edge 1: `qc_result.status == 'pass'` → FINISH
- Edge 2: Default edge `{ type: "expression", expression: "true" }` → DEFAULT
- Token: At QC node

**Test Cases:**
- **TC-013a:** `qc_result.status = 'pass'` → Routes to FINISH (conditional edge matches)
- **TC-013b:** `qc_result.status = 'fail_minor'` → Routes to DEFAULT (default edge)
- **TC-013c:** `qc_result.status = 'fail_major'` → Routes to DEFAULT (default edge)

**Expected Result:**
- ✅ Pass → FINISH (conditional edge)
- ✅ Fail → DEFAULT (default edge)
- ✅ All QC statuses covered (pass explicitly, fail via default)
- ✅ No validation errors

---

### TC-014: NO_MATCH_UNROUTABLE

**Category:** Error Scenarios  
**Priority:** High  
**Scenario ID:** `NO_MATCH_UNROUTABLE`

**Description:**  
Error when no edge matches and no default route exists.

**Graph:**
```
[START] → [QC] → [FINISH] (pass edge only)
```

**Preconditions:**
- Graph: QC node with one outgoing conditional edge
- Edge condition: `qc_result.status == 'pass'` → FINISH
- No default edge exists
- Token: At QC node, `qc_result.status = 'fail_minor'` (doesn't match pass condition)

**Steps:**
1. Token completes QC with result: `fail_minor`
2. Evaluate outgoing edges
3. Conditional edge (pass) doesn't match
4. No default edge exists
5. No normal edge exists
6. Routing fails

**Expected Result:**
- ❌ Token NOT routed (stays at QC node or error)
- ❌ Error: `error_unroutable` or token status: `waiting` / `stuck`
- ❌ Event: `routing_failed` or similar logged
- ⚠️ Token may require manual intervention

---

### TC-015: AMBIGUOUS_MATCH_ERROR

**Category:** Error Scenarios  
**Priority:** Medium  
**Scenario ID:** `AMBIGUOUS_MATCH_ERROR`

**Description:**  
Multiple edges match simultaneously (ambiguous routing).

**Graph:**
```
[START] → [QC] → [PATH_A] (condition: qty >= 1)
            ↓
         [PATH_B] (condition: qty >= 0)
```

**Preconditions:**
- Graph: QC node with two outgoing conditional edges
- Edge 1: `{ type: "token_property", property: "token.qty", operator: ">=", value: 1 }` → PATH_A
- Edge 2: `{ type: "token_property", property: "token.qty", operator: ">=", value: 0 }` → PATH_B
- Token: At QC node, `token.qty = 5` (matches both conditions)

**Steps:**
1. Token at QC node with `token.qty = 5`
2. Evaluate outgoing edges
3. Both conditional edges match (5 >= 1 and 5 >= 0)
4. Ambiguous routing detected

**Expected Result:**
- ⚠️ Implementation-dependent:
  - Option A: First match wins (PATH_A selected)
  - Option B: Error `error_ambiguous`
  - Option C: Priority-based selection (if priority field used)
- ⚠️ Document actual behavior in results

---

### TC-016: MISSING_CONDITION_FIELD

**Category:** Error Scenarios  
**Priority:** Medium  
**Scenario ID:** `MISSING_CONDITION_FIELD`

**Description:**  
Condition missing required field (validation error).

**Graph:**
```
[START] → [QC] → [FINISH] (invalid edge condition)
```

**Preconditions:**
- Graph: QC node with one outgoing conditional edge
- Edge condition: `{ type: "token_property", operator: "==", value: "pass" }` (missing `property` field)
- Token: At QC node

**Validation (Frontend - Task 19.1, 19.2):**
- `validateConditionGroups()` checks for missing fields
- Blocks save with error

**Expected Result:**
- ❌ Graph save blocked (frontend validation)
- ❌ Error message: "Group {N}: Field is required"
- ✅ User must fix condition

---

### TC-017: LEGACY_CONDITION_MIGRATION

**Category:** Legacy Compatibility  
**Priority:** High  
**Scenario ID:** `LEGACY_CONDITION_MIGRATION`

**Description:**  
Legacy condition format converted to new format.

**Graph:**
```
[START] → [QC] → [FINISH] (legacy condition format)
```

**Preconditions:**
- Graph: QC node with legacy condition format (pre-Task 19.0)
- Legacy format: `{ qc: 'pass' }` or `{ condition_field: 'qc_result.status', condition_operator: '==', condition_value: 'pass' }`
- Token: At QC node, `qc_result.status = 'pass'`

**Steps:**
1. Legacy condition loaded and converted to unified format
2. `ConditionEvaluator` evaluates converted condition
3. Token routed based on converted condition

**Expected Result:**
- ✅ Legacy format converted correctly
- ✅ Routing behavior matches new format
- ✅ No errors
- ⚠️ Document conversion mapping in results

---

### TC-018: LEGACY_OR_FORMAT_CONVERSION

**Category:** Legacy Compatibility  
**Priority:** Medium  
**Scenario ID:** `LEGACY_OR_FORMAT_CONVERSION`

**Description:**  
Legacy OR format converted to multi-group (Task 19.2).

**Graph:**
```
[START] → [QC] → [PATH_A] (legacy OR format)
            ↓
         [PATH_B]
```

**Preconditions:**
- Graph: QC node with legacy OR format condition:
  ```json
  {
    "type": "or",
    "conditions": [
      { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass" },
      { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_minor" }
    ]
  }
  ```
- Token: At QC node

**Conversion (Task 19.2):**
- Legacy OR → Multi-group format (see Scenario 16 in Regression Map)

**Test Cases:**
- **TC-018a:** `qc_result.status = 'pass'` → Routes to PATH_A
- **TC-018b:** `qc_result.status = 'fail_minor'` → Routes to PATH_B

**Expected Result:**
- ✅ Legacy OR format converted to multi-group
- ✅ Each condition becomes separate group
- ✅ Routing behavior unchanged
- ✅ No errors

---

### TC-019: NON_QC_CONDITIONAL_ROUTING

**Category:** Advanced Scenarios  
**Priority:** Medium  
**Scenario ID:** `NON_QC_CONDITIONAL_ROUTING`

**Description:**  
Conditional routing from non-QC operation node.

**Graph:**
```
[START] → [OPERATION] → [PATH_A] (qty >= 10)
            ↓
         [PATH_B] (qty < 10)
```

**Preconditions:**
- Graph: OPERATION node (not QC) with two outgoing conditional edges
- Edge 1: `{ type: "token_property", property: "token.qty", operator: ">=", value: 10 }` → PATH_A
- Edge 2: `{ type: "token_property", property: "token.qty", operator: "<", value: 10 }` → PATH_B
- Token: At OPERATION node, `token.qty = 15`

**Steps:**
1. Token completes OPERATION
2. Evaluate outgoing edges
3. Edge 1 matches (15 >= 10)
4. Route token to PATH_A

**Expected Result:**
- ✅ Conditional routing works from non-QC nodes
- ✅ Token property conditions evaluated correctly
- ✅ Token routed to PATH_A
- ✅ No errors

---

### TC-020: JOB_PROPERTY_CONDITION

**Category:** Advanced Scenarios  
**Priority:** Medium  
**Scenario ID:** `JOB_PROPERTY_CONDITION`

**Description:**  
Conditional routing based on job properties.

**Graph:**
```
[START] → [OPERATION] → [HIGH_PRIORITY] (job.priority == 'high')
            ↓
         [NORMAL_PRIORITY] (default)
```

**Preconditions:**
- Graph: OPERATION node with two outgoing edges
- Edge 1: `{ type: "job_property", property: "job.priority", operator: "==", value: "high" }` → HIGH_PRIORITY
- Edge 2: Default edge → NORMAL_PRIORITY
- Token: At OPERATION node
- Job: `priority = 'high'`

**Steps:**
1. Token at OPERATION node
2. Evaluate outgoing edges
3. Edge 1 matches (job.priority == 'high')
4. Route token to HIGH_PRIORITY

**Expected Result:**
- ✅ Job property conditions evaluated correctly
- ✅ Token routed to HIGH_PRIORITY
- ✅ No errors

---

### TC-021: QC_PARALLEL_BRANCH_SAFE

**Category:** Advanced Scenarios  
**Priority:** Low  
**Scenario ID:** `QC_PARALLEL_BRANCH_SAFE`

**Description:**  
QC routing before parallel split (minimal case).

**Graph:**
```
[START] → [QC] → [SPLIT] → [BRANCH_A]
            ↓              → [BRANCH_B]
         (pass edge)
```

**Preconditions:**
- Graph: QC node with conditional edge → SPLIT node
- SPLIT node is parallel split (spawns multiple tokens)
- Edge condition: `qc_result.status == 'pass'` → SPLIT
- Token: At QC node, `qc_result.status = 'pass'`

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

---

### TC-022: EXPRESSION_DEFAULT_ONLY

**Category:** Default Route & Coverage  
**Priority:** Low  
**Scenario ID:** `EXPRESSION_DEFAULT_ONLY`

**Description:**  
Default route only (no conditional edges).

**Graph:**
```
[START] → [OPERATION] → [DEFAULT] (default edge only)
```

**Preconditions:**
- Graph: OPERATION node with one outgoing default edge
- Edge condition: `{ type: "expression", expression: "true" }` → DEFAULT
- Token: At OPERATION node

**Steps:**
1. Token completes OPERATION
2. Evaluate outgoing edges
3. Default edge matches (always true)
4. Route token to DEFAULT

**Expected Result:**
- ✅ Default route works as only edge
- ✅ Token routed to DEFAULT
- ✅ No errors

---

## Test Execution Guide

### Manual Testing

1. **Setup:**
   - Create graph matching test case scenario
   - Set up token with required state
   - Set QC result in token metadata (for QC tests)

2. **Execution:**
   - Trigger routing (complete node, QC action, etc.)
   - Observe token location and status
   - Check token events

3. **Validation:**
   - Compare actual result with expected result
   - Document any discrepancies
   - Update test case if behavior changed

### Automated Testing (If CLI Harness Implemented)

```bash
# Run all tests
php tests/super_dag/QCRoutingSmokeTest.php

# Run specific test
php tests/super_dag/QCRoutingSmokeTest.php --test TC-001

# Run category
php tests/super_dag/QCRoutingSmokeTest.php --category "Simple QC Pass/Fail"
```

### Test Data Format

Each test case includes:
- **Graph definition:** ASCII diagram
- **Preconditions:** Required graph state, token state, edge conditions
- **Steps:** Execution sequence
- **Expected Result:** Success criteria
- **Test Data:** JSON format for token, edge conditions

---

## Coverage Matrix

| Dimension | Coverage |
|-----------|----------|
| **QC Status** | ✅ pass, ✅ fail_minor, ✅ fail_major |
| **Condition Complexity** | ✅ Single, ✅ Multi-condition (AND), ✅ Multi-group (OR of AND) |
| **Default Logic** | ✅ With default, ✅ Without default (full coverage) |
| **Graph Topology** | ✅ Linear, ✅ Parallel (minimal) |
| **Origin Node** | ✅ QC node, ✅ Non-QC operation node |
| **Data Origin** | ✅ New graphs (19.x format), ✅ Legacy graphs (converted) |
| **Error Scenarios** | ✅ Unroutable, ✅ Ambiguous, ✅ Missing fields |
| **Templates** | ✅ Template A, ✅ Template B |
| **Non-QC Routing** | ✅ Priority, ✅ Customer Tier, ✅ Order Channel, ✅ Product Type, ✅ Node Behavior |

**Total Test Cases:** 27 (22 QC + 5 Non-QC)  
**Coverage:** 100% of required scenarios

---

### TC-023: PRIORITY_BASED_ROUTING

**Category:** Advanced Scenarios (Non-QC)  
**Priority:** High  
**Scenario ID:** `PRIORITY_BASED_ROUTING`

**Description:**  
Route tokens based on job priority (high/urgent → fast path, normal/low → standard path).

**Graph:**
```
[START] → [OPERATION] → [FAST_PATH] (job.priority IN ['high', 'urgent'])
            ↓
         [STANDARD_PATH] (default)
```

**Preconditions:**
- Graph: OPERATION node with two outgoing edges
- Edge 1: `{ type: "job_property", property: "job.priority", operator: "IN", value: ["high", "urgent"] }` → FAST_PATH
- Edge 2: Default edge `{ type: "expression", expression: "true" }` → STANDARD_PATH
- Token: At OPERATION node
- Job: `priority = 'high'`

**Steps:**
1. Token at OPERATION node
2. Evaluate outgoing edges
3. Edge 1 matches (job.priority = 'high' in ['high', 'urgent'])
4. Route token to FAST_PATH

**Expected Result:**
- ✅ Token routed to FAST_PATH
- ✅ Token status: `ready`
- ✅ Event: `routed` logged
- ✅ No errors

**Test Data:**
```json
{
  "token": {
    "id": 23,
    "current_node_id": 2,
    "qty": 1
  },
  "job": {
    "priority": "high"
  },
  "edge_condition": {
    "type": "job_property",
    "property": "job.priority",
    "operator": "IN",
    "value": ["high", "urgent"]
  }
}
```

---

### TC-024: CUSTOMER_TIER_ROUTING

**Category:** Advanced Scenarios (Non-QC)  
**Priority:** High  
**Scenario ID:** `CUSTOMER_TIER_ROUTING`

**Description:**  
Route tokens based on customer tier (VIP → priority path).

**Graph:**
```
[START] → [OPERATION] → [VIP_PATH] (job.customer_tier == 'vip')
            ↓
         [NORMAL_PATH] (default)
```

**Preconditions:**
- Graph: OPERATION node with two outgoing edges
- Edge 1: `{ type: "job_property", property: "job.customer_tier", operator: "==", value: "vip" }` → VIP_PATH
- Edge 2: Default edge → NORMAL_PATH
- Token: At OPERATION node
- Job: `customer_tier = 'vip'`

**Steps:**
1. Token at OPERATION node
2. Evaluate outgoing edges
3. Edge 1 matches (job.customer_tier == 'vip')
4. Route token to VIP_PATH

**Expected Result:**
- ✅ Token routed to VIP_PATH
- ✅ Token status: `ready`
- ✅ Event: `routed` logged
- ✅ No errors

**Test Data:**
```json
{
  "token": {
    "id": 24,
    "current_node_id": 2,
    "qty": 1
  },
  "job": {
    "customer_tier": "vip"
  },
  "edge_condition": {
    "type": "job_property",
    "property": "job.customer_tier",
    "operator": "==",
    "value": "vip"
  }
}
```

---

### TC-025: ORDER_CHANNEL_ROUTING

**Category:** Advanced Scenarios (Non-QC)  
**Priority:** Medium  
**Scenario ID:** `ORDER_CHANNEL_ROUTING`

**Description:**  
Route tokens based on order channel (online → e-commerce path, retail → store path).

**Graph:**
```
[START] → [OPERATION] → [ECOMMERCE_PATH] (job.order_channel == 'online')
            ↓
         [RETAIL_PATH] (job.order_channel == 'retail')
            ↓
         [DEFAULT_PATH] (default)
```

**Preconditions:**
- Graph: OPERATION node with three outgoing edges
- Edge 1: `job.order_channel == 'online'` → ECOMMERCE_PATH
- Edge 2: `job.order_channel == 'retail'` → RETAIL_PATH
- Edge 3: Default edge → DEFAULT_PATH
- Token: At OPERATION node
- Job: `order_channel = 'online'`

**Steps:**
1. Token at OPERATION node
2. Evaluate outgoing edges
3. Edge 1 matches (job.order_channel == 'online')
4. Route token to ECOMMERCE_PATH

**Expected Result:**
- ✅ Token routed to ECOMMERCE_PATH
- ✅ Token status: `ready`
- ✅ Event: `routed` logged
- ✅ No errors

**Test Cases:**
- **TC-025a:** `order_channel = 'online'` → Routes to ECOMMERCE_PATH
- **TC-025b:** `order_channel = 'retail'` → Routes to RETAIL_PATH
- **TC-025c:** `order_channel = 'oem'` → Routes to DEFAULT_PATH

---

### TC-026: PRODUCT_TYPE_ROUTING

**Category:** Advanced Scenarios (Non-QC)  
**Priority:** Medium  
**Scenario ID:** `PRODUCT_TYPE_ROUTING`

**Description:**  
Route tokens based on job type (custom → custom path, standard → standard path).

**Graph:**
```
[START] → [OPERATION] → [CUSTOM_PATH] (job.type == 'custom')
            ↓
         [STANDARD_PATH] (default)
```

**Preconditions:**
- Graph: OPERATION node with two outgoing edges
- Edge 1: `{ type: "job_property", property: "job.type", operator: "==", value: "custom" }` → CUSTOM_PATH
- Edge 2: Default edge → STANDARD_PATH
- Token: At OPERATION node
- Job: `type = 'custom'`

**Steps:**
1. Token at OPERATION node
2. Evaluate outgoing edges
3. Edge 1 matches (job.type == 'custom')
4. Route token to CUSTOM_PATH

**Expected Result:**
- ✅ Token routed to CUSTOM_PATH
- ✅ Token status: `ready`
- ✅ Event: `routed` logged
- ✅ No errors

---

### TC-027: NODE_BEHAVIOR_ROUTING

**Category:** Advanced Scenarios (Non-QC)  
**Priority:** Medium  
**Scenario ID:** `NODE_BEHAVIOR_ROUTING`

**Description:**  
Route tokens based on target node behavior code (CUT → CUT nodes only).

**Graph:**
```
[START] → [OPERATION] → [CUT_NODE] (node.behavior_code == 'CUT')
            ↓
         [STITCH_NODE] (node.behavior_code == 'STITCH')
            ↓
         [DEFAULT_NODE] (default)
```

**Preconditions:**
- Graph: OPERATION node with three outgoing edges
- Edge 1: `{ type: "node_property", property: "node.behavior_code", operator: "==", value: "CUT" }` → CUT_NODE
- Edge 2: `{ type: "node_property", property: "node.behavior_code", operator: "==", value: "STITCH" }` → STITCH_NODE
- Edge 3: Default edge → DEFAULT_NODE
- Token: At OPERATION node
- Target node: CUT_NODE has `behavior_code = 'CUT'`

**Steps:**
1. Token at OPERATION node
2. Evaluate outgoing edges
3. Edge 1 matches (target node behavior_code == 'CUT')
4. Route token to CUT_NODE

**Expected Result:**
- ✅ Token routed to CUT_NODE
- ✅ Token status: `ready`
- ✅ Event: `routed` logged
- ✅ No errors

**Note:** Node property conditions evaluate the target node, not the source node.

---

**End of Test Case Catalog**

