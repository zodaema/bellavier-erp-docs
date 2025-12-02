# Semantic Routing Test Cases

**Task 19.17: Semantic Routing Consistency & Intent Conflict Detection**

## Overview

Test cases for validating semantic routing consistency and intent conflict detection. These tests ensure that:
- Graph structure matches inferred semantic intents
- Intent conflicts are detected and reported correctly
- Semantic errors/warnings are displayed clearly in UI

---

## Test Cases

### TC-1: Multi-Exit Conditional (Valid)

**Graph Structure:**
```
START → OP1 → (condition A) → OP2
                (condition B) → OP3
                (default) → OP4 → END
```

**Expected:**
- ✅ No semantic errors
- ✅ Intent: `operation.multi_exit` on OP1
- ✅ No conflicts

**Validation:**
- `error_count = 0`
- `warning_count >= 0` (may have other warnings)
- No `INTENT_CONFLICT_*` errors

---

### TC-2: Parallel Split (Valid)

**Graph Structure:**
```
START → OP1 → OP2 (parallel)
              → OP3 (parallel)
              → OP4 (parallel)
        OP2 → MERGE
        OP3 → MERGE
        OP4 → MERGE
        MERGE → END
```

**Node Configuration:**
- OP1: `is_parallel_split = true`
- OP2, OP3, OP4: Normal edges (no conditions)
- MERGE: `is_merge_node = true`

**Expected:**
- ✅ No semantic errors
- ✅ Intent: `parallel.true_split` on OP1
- ✅ No conflicts

**Validation:**
- `error_count = 0`
- No `INTENT_CONFLICT_PARALLEL_CONDITIONAL` error

---

### TC-3: Parallel + Conditional Mix (Invalid)

**Graph Structure:**
```
START → OP1 → (condition A) → OP2
                (condition B) → OP3
                → END
```

**Node Configuration:**
- OP1: `is_parallel_split = true` (WRONG - has conditional edges)

**Expected:**
- ❌ Error: `INTENT_CONFLICT_PARALLEL_CONDITIONAL`
- ❌ Message: "Node 'OP1' is marked as parallel split but has conditional edges"
- ❌ Suggestion: "Remove parallel flag OR convert conditional edges to normal edges"
- 🛈 May include evidence metadata (e.g. has_conditional_edges: true)

**Validation:**
- `error_count >= 1`
- Error code: `INTENT_CONFLICT_PARALLEL_CONDITIONAL`
- Category: `semantic`
- Rule: `INTENT_CONFLICT`

---

### TC-4: END Node with Outgoing Edges (Invalid)

**Graph Structure:**
```
START → OP1 → END → OP2 → END2
```

**Expected:**
- ❌ Error: `INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING`
- ❌ Message: "END node 'END' has 1 outgoing edge(s). END nodes are terminal and cannot have outgoing edges."
- ❌ Suggestion: "Remove outgoing edges from this END node or change node type if routing is needed."

**Validation:**
- `error_count >= 1`
- Error code: `INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING`
- Category: `semantic`
- Rule: `INTENT_CONFLICT`

---

### TC-5: QC 2-Way + Non-QC Condition (Warning)

**Graph Structure:**
```
START → OP1 → QC1 → (pass) → OP2
                    → (token.priority == 'high') → OP3
                    → END
```

**Expected:**
- ⚠️ Warning: `INTENT_CONFLICT_QC_NON_QC_CONDITION`
- ⚠️ Message: "QC node 'QC1' has edge with non-QC condition field 'token.priority'. QC nodes should route based on QC results."
- ⚠️ Suggestion: "Consider using qc_result.status or qc_result.defect_type for QC routing instead."

**Validation:**
- `error_count = 0`
- `warning_count >= 1`
- Warning code: `INTENT_CONFLICT_QC_NON_QC_CONDITION`
- Category: `semantic`, Rule: `INTENT_CONFLICT`

---

### TC-6: Subflow Sink (Valid)

**Graph Structure:**
```
START → OP1 → QC1 → (pass) → OP2 → END
                    → (fail) → REWORK_SINK
```

**Node Configuration:**
- REWORK_SINK: `node_type = 'rework_sink'` (no outgoing edges)

**Expected:**
- ✅ No semantic errors
- ✅ Intent: `sink.expected` on REWORK_SINK
- ✅ No conflicts (intentional dead-end)

**Validation:**
- `error_count = 0`
- No `DEAD_END_NODE` error (intentional sink)

---

### TC-7: Endpoint Multi-End (Intentional vs Unintentional)

**Graph Structure (Intentional):**
```
START → OP1 → (parallel) → OP2 → END1
                    → OP3 → END2
```

**Node Configuration:**
- OP1: `is_parallel_split = true`
- END1, END2: `node_type = 'end'`

**Expected:**
- ✅ No semantic errors
- ✅ Intent: `endpoint.multi_end` (intentional parallel termination)
- ✅ No conflicts

**Validation:**
- `error_count = 0`
- Intent: `endpoint.multi_end` with `has_parallel_branches: true`

---

**Graph Structure (Unintentional):**
```
START → OP1 → OP2 → END1
        OP1 → OP3 → END2
```

**Node Configuration:**
- OP1: Normal node (not parallel)
- END1, END2: `node_type = 'end'`

**Expected:**
- ⚠️ Warning: `endpoint.unintentional_multi` (semantic warning for multi-END without parallel split)
- ⚠️ Message: "Node 'OP1' leads to multiple END nodes without being a parallel split. This may indicate ambiguous termination paths."
- ⚠️ Suggestion: "Either mark this as parallel split or consolidate termination into a single END node."

**Validation:**
- `error_count = 0`
- `warning_count >= 1`
- Warning code: `endpoint.unintentional_multi`
- Category: `semantic`, Rule: `INTENT_CONFLICT`

---

### TC-8: Graph Small (No Conflicts)

**Graph Structure:**
```
START → OP1 → OP2 → END
```

**Expected:**
- ✅ No semantic errors
- ✅ No conflicts
- ✅ Intent: `operation.linear_only` on OP1, OP2

**Validation:**
- `error_count = 0`
- `warning_count >= 0` (may have other warnings)
- No `INTENT_CONFLICT_*` errors/warnings

---

### TC-9: Linear Node with Multiple Outgoing Edges (Invalid)

**Graph Structure:**
```
START → OP1 → OP2
              → OP3
              → END
```

**Node Configuration:**
- OP1: Has `operation.linear_only` intent (from structure: 1 incoming, but 2 outgoing)

**Expected:**
- ❌ Error: `INTENT_CONFLICT_LINEAR_MULTIPLE_EXITS`
- ❌ Message: "Node 'OP1' is marked as linear-only but has 2 outgoing edge(s). Linear nodes must have exactly 1 outgoing edge."
- ❌ Suggestion: "Remove extra edges OR change intent to operation.multi_exit if conditional routing is needed."

**Validation:**
- `error_count >= 1`
- Error code: `INTENT_CONFLICT_LINEAR_MULTIPLE_EXITS`
- Category: `semantic`
- Rule: `INTENT_CONFLICT`

---

### TC-10: Multiple Conflicting Routing Styles (Invalid)

**Graph Structure:**
```
START → OP1 → (condition A) → OP2
              → OP3 (normal)
              → END
```

**Node Configuration:**
- OP1: Has both `parallel.true_split` and `operation.multi_exit` intents

**Expected:**
- ❌ Error: `INTENT_CONFLICT_MULTIPLE_ROUTING_STYLES`
- ❌ Message: "Node 'OP1' has conflicting routing styles: parallel split and multi-exit conditional. Choose one pattern."
- ❌ Suggestion: "Clarify design intent: use either parallel split (normal edges) OR conditional multi-exit (conditional edges), not both."

**Validation:**
- `error_count >= 1`
- Error code: `INTENT_CONFLICT_MULTIPLE_ROUTING_STYLES`
- Category: `semantic`
- Rule: `INTENT_CONFLICT`

---

### TC-11: QC 2-Way with Default Rework (Valid)

**Graph Structure:**
```
START → OP1 → QC1 → (qc_result.status == 'pass') → FINISH
                    → (default / else) → REWORK_SINK
```

**Node Configuration:**
- QC1: `behavior = 'QC'`
- REWORK_SINK: `node_type = 'rework_sink'` (no outgoing edges)
- Conditional edge 1: field = `qc_result.status`, operator = `==`, value = `pass`
- Conditional edge 2: `type: 'default'` (Else route)

**Expected:**
- ✅ No semantic errors
- ✅ QC routing intent: `qc.two_way` (Pass + Else/Rework)
- ✅ No `QC_MISSING_ROUTES` error
- ✅ REWORK_SINK treated as `sink.expected`

**Validation:**
- `error_count = 0`
- `warning_count >= 0`
- No error code: `QC_MISSING_ROUTES`
- No dead-end error on REWORK_SINK

---

### TC-12: Default Route Only (Valid)

**Graph Structure:**
```
START → OP1 → (default / else) → OP2 → END
```

**Node Configuration:**
- OP1: Normal operation node
- Single outgoing edge from OP1 with condition `type: 'default'`

**Expected:**
- ✅ No semantic errors
- ✅ Intent: `operation.linear_only` (logical single-path flow)
- ✅ Default route recognized as unconditional path

**Validation:**
- `error_count = 0`
- `warning_count >= 0`
- No semantic conflict errors

---

## Test Execution

### Manual Testing

1. Create graph in Graph Designer
2. Configure nodes/edges according to test case
3. Click "Validate" button
4. Check validation results:
   - Error count
   - Warning count
   - Error codes
   - Error messages
   - Suggestions

### Automated Testing (Future)

```php
// Example test structure
public function testMultiExitConditional(): void
{
    $nodes = [
        ['node_code' => 'OP1', 'node_type' => 'operation', ...],
        ['node_code' => 'OP2', 'node_type' => 'operation', ...],
        // ...
    ];
    
    $edges = [
        ['from_node_code' => 'OP1', 'to_node_code' => 'OP2', 'edge_type' => 'conditional', ...],
        // ...
    ];
    
    $engine = new GraphValidationEngine($db);
    $result = $engine->validate($nodes, $edges);
    
    $this->assertEquals(0, $result['error_count']);
    $this->assertEmpty(array_filter($result['errors'], fn($e) => strpos($e['code'] ?? '', 'INTENT_CONFLICT') === 0));
}
```

---

## Expected Results Summary

| Test Case | Error Count | Warning Count | Conflict Type |
|-----------|-------------|---------------|---------------|
| TC-1: Multi-Exit Conditional | 0 | >= 0 | None |
| TC-2: Parallel Split | 0 | >= 0 | None |
| TC-3: Parallel + Conditional | >= 1 | >= 0 | `INTENT_CONFLICT_PARALLEL_CONDITIONAL` |
| TC-4: END with Outgoing | >= 1 | >= 0 | `INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING` |
| TC-5: QC Non-QC Condition | 0 | >= 1 | `INTENT_CONFLICT_QC_NON_QC_CONDITION` |
| TC-6: Subflow Sink | 0 | >= 0 | None |
| TC-7: Multi-End (Intentional) | 0 | >= 0 | None |
| TC-7: Multi-End (Unintentional) | 0 | >= 1 | `endpoint.unintentional_multi` (warning) |
| TC-8: Graph Small | 0 | >= 0 | None |
| TC-9: Linear Multiple Exits | >= 1 | >= 0 | `INTENT_CONFLICT_LINEAR_MULTIPLE_EXITS` |
| TC-10: Multiple Routing Styles | >= 1 | >= 0 | `INTENT_CONFLICT_MULTIPLE_ROUTING_STYLES` |
| TC-11: QC 2-Way with Default Rework | 0 | >= 0 | None |
| TC-12: Default Route Only | 0 | >= 0 | None |

---

## Notes

- All test cases should pass validation (no false positives)
- Semantic conflicts should be clearly displayed in UI with `[Semantic Conflicts]` prefix
- Suggestions should be actionable and helpful
- Test cases cover both valid patterns (no conflicts) and invalid patterns (conflicts detected)
