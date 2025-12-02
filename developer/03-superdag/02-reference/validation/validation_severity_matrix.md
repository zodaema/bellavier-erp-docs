# Validation Severity Matrix

**Task 19.21: Stability Regression & Post-Helper Normalization Pass**

This document defines the severity (error vs warning) for all validation rules in `GraphValidationEngine`.

## Purpose

- Standardize error/warning classification across all validation modules
- Ensure consistent user experience
- Guide AutoFix engine priority (errors first, warnings second)
- Baseline for ValidateGraphTest expectations

## Severity Guidelines

- **Error**: Blocks graph publish/save. Must be fixed before production use.
- **Warning**: Does not block publish. Best practice recommendation.

## Matrix

### Module 1: Node Existence

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `GRAPH_EMPTY` | error | structure | Graph must have at least one node | Add nodes to the graph |

### Module 2: Start/End Validator

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `GRAPH_MISSING_START` | error | structure | Graph must have exactly 1 Start node | Add a Start node to begin the workflow |
| `GRAPH_MULTIPLE_START` | error | structure | Graph has multiple Start nodes | Remove extra Start nodes. Keep only one |
| `GRAPH_MISSING_FINISH` | error | structure | Graph must have exactly 1 Finish node | Add a Finish node to end the workflow |
| `GRAPH_MULTIPLE_FINISH` | warning | structure | Graph has multiple Finish nodes | If multiple END nodes are intentional (e.g. parallel branches), you can ignore this warning |

### Module 3: Edge Integrity Validator

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `EDGE_DANGLING_FROM` | error | structure | Edge has invalid source node | Connect edge to a valid source node |
| `EDGE_DANGLING_TO` | error | structure | Edge has invalid target node | Connect edge to a valid target node |
| `EDGE_SELF_LOOP` | error | structure | Edge creates a self-loop | Remove self-loop or connect to a different node |

### Module 4: Parallel Structure Validator

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `SPLIT_INSUFFICIENT_EDGES` | error | structure | Split node must have at least 2 outgoing edges | Add more outgoing edges or remove split flag |

### Module 5: Merge Structure Validator

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `MERGE_INSUFFICIENT_EDGES` | error | structure | Merge node must have at least 2 incoming edges | Add more incoming edges or remove merge flag |

### Module 6: QC Routing Validator

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `QC_NO_OUTGOING_EDGES` | warning | routing | QC node has no outgoing edges | Add at least one edge (PASS / REWORK / ELSE) from this QC node |

### Module 7: Conditional Routing Validator

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `CONDITIONAL_EDGE_MISSING_CONDITION` | error | routing | Conditional edge has no valid condition | Add condition or mark as default route |

### Module 8: Behavior-WorkCenter Compatibility Validator

(No rules implemented yet)

### Module 9: Machine Binding Validator

(No rules implemented yet)

### Module 10: Node Configuration Validator

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `OPERATION_MISSING_WORKFORCE` | warning | assignment | Operation node should have work center or team assigned | Assign a work center or team category |
| `QC_MISSING_POLICY` | error | node_config | QC node must have QC policy defined | Configure QC policy in node properties |
| `JOIN_MISSING_REQUIREMENT` | error | node_config | Join node must have join_requirement configured | Set join_requirement in node parameters |

### Module 11: Semantic Validation Layer

#### QC Routing Semantic

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `QC_MISSING_FAILURE_PATH` | error | semantic | QC node uses 2-way routing but has no failure/rework path | Add a rework edge or default route for failure cases |
| `QC_THREE_WAY_MISSING_STATUSES` | warning | semantic | QC node uses 3-way routing but missing status coverage | Add edges for missing statuses or use default route |
| `QC_THREE_WAY_DEFAULT_ROUTE` | warning | semantic | QC node uses 3-way routing but has default route (may hide issues) | Consider explicit status routes instead of default |
| `QC_PASS_ONLY_WARNING` | warning | semantic | QC node only has pass path (no failure handling) | Consider adding failure/rework path |

#### Parallel/Multi-exit Semantic

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `LINEAR_NODE_PARALLEL_FLAGS` | error | semantic | Linear-only node has parallel/merge flags set | Remove parallel/merge flags or convert to parallel structure |
| `MULTI_EXIT_PARALLEL_FLAG` | warning | semantic | Multi-exit conditional node has parallel flag | Remove parallel flag if not using parallel split |
| `PARALLEL_SPLIT_NO_MERGE` | error | semantic | Parallel split has no merge node downstream | Add merge node or remove parallel split flag |
| `SEMANTIC_SPLIT_WARNING` | warning | semantic | Node appears to be parallel split but not flagged | Consider adding is_parallel_split flag |

#### Endpoint Semantic

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `ENDPOINT_MISSING` | error | semantic | Graph has no END node | Add an END node and connect terminal operations to it |
| `MULTI_END_WARNING` | warning | semantic | Graph has multiple END nodes which appear intentional | If multiple END nodes are intentional, no action needed |
| `UNINTENTIONAL_MULTI_END` | error | semantic | Graph has multiple END nodes without parallel structure | Consolidate to a single END node or use AutoFix to merge END nodes |
| `INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING` | error | semantic | END node has outgoing edges | END nodes are terminal and cannot have outgoing edges |

#### Reachability Semantic

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `UNREACHABLE_NODE` | error | reachability | Node is unreachable from START and appears unintentional | Connect node to main flow or use AutoFix to connect/remove unreachable nodes |
| `DEAD_END_NODE` | error | reachability | Node is a dead-end with no outgoing edges (non-sink) | Add outgoing edge or convert to sink node |
| `DEAD_END_NODE_WARNING` | warning | reachability | Node is a dead-end (sink node, intentional) | No action needed if intentional |
| `CYCLE_DETECTED_WARNING` | warning | reachability | Graph contains cycles | Review cycle structure to ensure intentional |
| `UNREACHABLE_NODE_ERROR` | error | reachability | Node is unreachable (legacy code path) | Connect node to main flow |

#### Time/SLA Semantic

| Code | Severity | Category | Description | Suggestion |
|------|----------|----------|-------------|------------|
| `SLA_ON_END_NODE` | warning | time | SLA time configured on END node (not used) | Remove SLA from END node |
| `SLA_ON_START_NODE` | warning | time | SLA time configured on START node (not used) | Remove SLA from START node |

## Summary Statistics

- **Total Rules**: 33
- **Errors**: 20
- **Warnings**: 13

## Notes

1. **Semantic vs Structural**: Semantic errors are detected after intent analysis, structural errors are detected from graph topology alone.

2. **AutoFix Priority**: Errors are always fixed before warnings.

3. **Test Baseline**: ValidateGraphTest should expect these severities. Update test fixtures if severity changes.

4. **Future Rules**: Modules 8 and 9 (Behavior-WorkCenter, Machine Binding) are placeholders for future implementation.

