# Validation Regression Suite

**Task 19.18: Validation Regression Suite & Hardening Pass**

## Overview

The Validation Regression Suite provides a comprehensive test harness for SuperDAG validation, ensuring that validation logic remains stable and correct throughout refactoring and feature additions.

**Purpose:**
- Prevent regressions in validation logic
- Ensure semantic intent inference remains consistent
- Validate autofix pipeline correctness
- Support Lean-Up Phase refactoring with confidence

---

## Test Structure

### Test Harnesses

1. **ValidateGraphTest.php** - Main validation test harness
   - Tests graph validation against expected results
   - Supports filtering by test ID or category
   - Validates error/warning counts and codes
   - Checks semantic intent inference

2. **SemanticSnapshotTest.php** - Semantic intent snapshot testing
   - Compares semantic intents against saved snapshots
   - Detects unintended changes in intent inference
   - Supports snapshot update mode

3. **AutoFixPipelineTest.php** - Autofix pipeline testing
   - Tests complete autofix flow: Validate → AutoFix → ApplyFix → Validate
   - Ensures errors decrease or stay same (never increase)
   - Validates no new error codes introduced

### Test Fixtures

**Location:** `tests/super_dag/fixtures/`

**Format:** JSON files with structure:
```json
{
  "id": "TC-XXX",
  "label": "Test Case Label",
  "meta": {
    "category": "QC|PL|RC|END|SM",
    "description": "Test description",
    "source": "semantic_routing_test_cases.md#TC-X"
  },
  "nodes": [...],
  "edges": [...],
  "expected": {
    "error_count": 0,
    "min_warning_count": 0,
    "must_not_have_error_codes": [...],
    "must_have_error_codes": [...],
    "must_have_warning_codes": [...],
    "semantic_intents": [...]
  }
}
```

---

## Running Tests

### ValidateGraphTest

```bash
# Run all tests
php tests/super_dag/ValidateGraphTest.php

# Run specific test
php tests/super_dag/ValidateGraphTest.php --test TC-QC-01

# Run by category
php tests/super_dag/ValidateGraphTest.php --category QC

# Verbose output
php tests/super_dag/ValidateGraphTest.php --verbose
```

**Exit Codes:**
- `0` = All tests passed
- `1` = One or more tests failed

### SemanticSnapshotTest

```bash
# Compare against snapshots
php tests/super_dag/SemanticSnapshotTest.php

# Update snapshots
php tests/super_dag/SemanticSnapshotTest.php --update
```

**Snapshot Location:** `tests/super_dag/snapshots/`

**Snapshot Format:**
```json
{
  "test_id": "TC-QC-01",
  "timestamp": "2025-11-24 10:30:00",
  "intents": [
    {
      "type": "qc.two_way",
      "node_id": "temp_3",
      "confidence": 0.9
    }
  ]
}
```

### AutoFixPipelineTest

```bash
# Run all autofix pipeline tests
php tests/super_dag/AutoFixPipelineTest.php

# Run specific test
php tests/super_dag/AutoFixPipelineTest.php --test TC-QC-04

# Verbose output
php tests/super_dag/AutoFixPipelineTest.php --verbose
```

---

## Test Cases

### QC Routing (QC)

| Test ID | Label | Expected Errors | Expected Warnings |
|---------|-------|----------------|-------------------|
| TC-QC-01 | Pass + Default Rework | 0 | 0 |
| TC-QC-02 | 3-Way QC | 0 | 0 |
| TC-QC-03 | Non-QC Condition | 0 | >= 1 |
| TC-QC-04 | No Outgoing Edges | 0 | >= 1 |

### Parallel / Multi-Exit (PL)

| Test ID | Label | Expected Errors | Expected Warnings |
|---------|-------|----------------|-------------------|
| TC-PL-01 | Parallel True Split | 0 | 0 |
| TC-PL-02 | Parallel Merge | 0 | 0 |
| TC-PL-03 | Parallel + Conditional Conflict | >= 1 | 0 |
| TC-PL-04 | Multi-Exit Conditional | 0 | 0 |

### Reachability (RC)

| Test ID | Label | Expected Errors | Expected Warnings |
|---------|-------|----------------|-------------------|
| TC-RC-01 | Unreachable Node | >= 1 | 0 |
| TC-RC-02 | Dead-End Non-Sink | >= 1 | 0 |
| TC-RC-03 | Dead-End Sink | 0 | 0 |

### Endpoint (END)

| Test ID | Label | Expected Errors | Expected Warnings |
|---------|-------|----------------|-------------------|
| TC-END-01 | END with Outgoing | >= 1 | 0 |
| TC-END-02 | Multi-End Intentional | 0 | 0 |

### Semantic (SM)

| Test ID | Label | Expected Errors | Expected Warnings |
|---------|-------|----------------|-------------------|
| TC-SM-01 | Conflicting Intents | >= 1 | 0 |
| TC-SM-02 | Simple Linear Flow | 0 | 0 |

---

## Adding New Test Cases

### Step 1: Create Fixture File

Create a new JSON file in `tests/super_dag/fixtures/`:

```json
{
  "id": "TC-XXX-YY",
  "label": "Test Case Label",
  "meta": {
    "category": "QC",
    "description": "Test description",
    "source": "semantic_routing_test_cases.md#TC-X"
  },
  "nodes": [
    {
      "id_node": 1,
      "node_code": "START",
      "node_type": "start"
    }
  ],
  "edges": [],
  "expected": {
    "error_count": 0,
    "min_warning_count": 0
  }
}
```

### Step 2: Define Expected Results

In the `expected` section, specify:
- `error_count`: Exact number of errors expected
- `min_warning_count`: Minimum number of warnings expected
- `must_not_have_error_codes`: Error codes that must NOT appear
- `must_have_error_codes`: Error codes that MUST appear
- `must_have_warning_codes`: Warning codes that MUST appear
- `semantic_intents`: Expected semantic intent types

### Step 3: Run Test

```bash
php tests/super_dag/ValidateGraphTest.php --test TC-XXX-YY
```

### Step 4: Update Snapshot (if needed)

If test includes semantic intent validation:

```bash
php tests/super_dag/SemanticSnapshotTest.php --update
```

---

## Fixture JSON Format

### Nodes

```json
{
  "id_node": 1,
  "node_code": "OP1",
  "node_type": "operation",
  "behavior_code": "CUT",
  "is_parallel_split": false,
  "is_merge_node": false
}
```

**Required Fields:**
- `id_node`: Unique node ID (integer)
- `node_code`: Node code (string)
- `node_type`: Node type (start, end, operation, qc, rework_sink, etc.)

**Optional Fields:**
- `behavior_code`: Behavior code (CUT, QC, etc.)
- `is_parallel_split`: Boolean flag for parallel split
- `is_merge_node`: Boolean flag for merge node
- `work_center_code`: Work center code
- `team_category`: Team category

### Edges

```json
{
  "from": 1,
  "to": 2,
  "edge_type": "conditional",
  "condition": {
    "type": "token_property",
    "property": "qc_result.status",
    "operator": "==",
    "value": "pass"
  },
  "is_default": false
}
```

**Required Fields:**
- `from`: Source node ID (integer)
- `to`: Target node ID (integer)

**Optional Fields:**
- `edge_type`: Edge type (normal, conditional, rework)
- `condition`: Condition object (for conditional edges)
- `is_default`: Boolean flag for default/else route

**Condition Types:**
- `token_property`: Token property condition
- `job_property`: Job property condition
- `node_property`: Node property condition
- `default`: Default/else route

### Expected Results

```json
{
  "expected": {
    "error_count": 0,
    "min_warning_count": 0,
    "must_not_have_error_codes": ["QC_MISSING_ROUTES"],
    "must_have_error_codes": ["INTENT_CONFLICT_PARALLEL_CONDITIONAL"],
    "must_have_warning_codes": ["INTENT_CONFLICT_QC_NON_QC_CONDITION"],
    "semantic_intents": ["qc.two_way", "operation.linear_only"]
  }
}
```

---

## Example Output

### ValidateGraphTest

```
SuperDAG Validation Regression Test Suite
==========================================

Found 14 test case(s)

Testing: TC-QC-01 - QC Pass + Default Rework
  ✅ PASSED

Testing: TC-QC-02 - QC 3-Way Routing
  ✅ PASSED

Testing: TC-QC-03 - QC with Non-QC Condition (Warning)
  ✅ PASSED

...

==========================================
Summary:
  Total:   14
  Passed:  14
  Failed:  0
  Skipped: 0
==========================================
```

### SemanticSnapshotTest

```
Semantic Intent Snapshot Test Suite
====================================

Mode: COMPARE (comparing against snapshots)

Testing: TC-QC-01 - QC Pass + Default Rework
  ✅ PASSED (intents match snapshot)

Testing: TC-QC-02 - QC 3-Way Routing
  ✅ PASSED (intents match snapshot)

...

====================================
Summary:
  Total:   14
  Passed:  14
  Failed:  0
====================================
```

### AutoFixPipelineTest

```
AutoFix Pipeline Test Suite
===========================

Testing: TC-QC-04 - QC with No Outgoing Edges (Error)
  Before: 0 errors, 1 warnings
  Generated 1 fix(es)
  After: 0 errors, 0 warnings
  ✅ PASSED (errors reduced or maintained, no new errors)

...

===========================
Summary:
  Total:   14
  Passed:  12
  Failed:  0
  Skipped: 2
===========================
```

---

## Best Practices

1. **Test Coverage:**
   - Cover all validation rule categories (QC, Parallel, Reachability, Endpoint, Semantic)
   - Include both valid and invalid patterns
   - Test edge cases and boundary conditions

2. **Fixture Organization:**
   - Use descriptive test IDs (TC-CATEGORY-NUMBER)
   - Link to documentation via `meta.source`
   - Keep fixtures simple and focused

3. **Expected Results:**
   - Be specific about error/warning counts
   - Specify exact error codes when important
   - Include semantic intents for intent validation

4. **Snapshot Management:**
   - Update snapshots when intent inference logic changes intentionally
   - Review snapshot changes carefully before committing
   - Document intentional snapshot updates

---

## Troubleshooting

### Test Fails Unexpectedly

1. Check if validation logic changed
2. Verify fixture JSON is valid
3. Run with `--verbose` to see detailed errors
4. Compare against expected results in documentation

### Snapshot Mismatch

1. Determine if change is intentional or regression
2. If intentional: Update snapshot with `--update`
3. If regression: Investigate intent inference logic

### Autofix Pipeline Fails

1. Check if autofix generated correct fixes
2. Verify ApplyFix executed without errors
3. Compare before/after error counts
4. Check for new error codes introduced

---

## Related Documentation

- `semantic_routing_test_cases.md` - Detailed test case descriptions
- `qc_routing_test_cases.md` - QC routing specific test cases
- `semantic_intent_rules.md` - Semantic intent rules and patterns
- `autofix_risk_scoring.md` - Autofix risk scoring guidelines

---

**Last Updated:** November 24, 2025  
**Task:** 19.18 - Validation Regression Suite & Hardening Pass

