# Validation Rule Ordering Specification

**Task 19.21: Stability Regression & Post-Helper Normalization Pass**

This document defines the deterministic execution order of validation modules in `GraphValidationEngine`.

## Purpose

- Ensure consistent error/warning ordering across runs
- Fix test randomness issues (same graph, different error order)
- Establish clear precedence for conflict resolution
- Guide AutoFix engine execution order

## Execution Order

Validation modules execute in the following order:

### Phase 1: Structural Fatal (Must Pass)

**Module 1: Node Existence Validator**
- Checks: Graph has at least one node
- Errors: `GRAPH_EMPTY`
- **Rationale**: Cannot validate anything if graph is empty

**Module 2: Start/End Validator**
- Checks: Exactly 1 START, at least 1 END
- Errors: `GRAPH_MISSING_START`, `GRAPH_MULTIPLE_START`, `GRAPH_MISSING_FINISH`
- Warnings: `GRAPH_MULTIPLE_FINISH`
- **Rationale**: Graph must have entry and exit points

**Module 3: Edge Integrity Validator**
- Checks: All edges have valid from/to nodes, no self-loops
- Errors: `EDGE_DANGLING_FROM`, `EDGE_DANGLING_TO`, `EDGE_SELF_LOOP`
- **Rationale**: Invalid edges break graph topology analysis

### Phase 2: Structural Topology

**Module 4: Parallel Structure Validator**
- Checks: Split nodes have ≥2 outgoing edges
- Errors: `SPLIT_INSUFFICIENT_EDGES`
- **Rationale**: Parallel structure must be valid before semantic analysis

**Module 5: Merge Structure Validator**
- Checks: Merge nodes have ≥2 incoming edges
- Errors: `MERGE_INSUFFICIENT_EDGES`
- **Rationale**: Merge structure must be valid before semantic analysis

**Module 6: QC Routing Validator (Structural)**
- Checks: QC nodes have at least one outgoing edge
- Warnings: `QC_NO_OUTGOING_EDGES`
- **Rationale**: Light structural check, semantic validation comes later

**Module 7: Conditional Routing Validator**
- Checks: Conditional edges have valid conditions
- Errors: `CONDITIONAL_EDGE_MISSING_CONDITION`
- **Rationale**: Conditional edges must be valid before semantic analysis

### Phase 3: Node Configuration

**Module 8: Behavior-WorkCenter Compatibility Validator**
- Checks: (Placeholder - not implemented)
- **Rationale**: Node configuration checks before semantic analysis

**Module 9: Machine Binding Validator**
- Checks: (Placeholder - not implemented)
- **Rationale**: Node configuration checks before semantic analysis

**Module 10: Node Configuration Validator**
- Checks: Operation nodes have work center/team, QC nodes have policy, Join nodes have requirement
- Errors: `QC_MISSING_POLICY`, `JOIN_MISSING_REQUIREMENT`
- Warnings: `OPERATION_MISSING_WORKFORCE`
- **Rationale**: Node configuration must be valid before semantic analysis

### Phase 4: Semantic Analysis

**Module 11: Semantic Validation Layer**

Within Module 11, sub-modules execute in this order:

#### 11.1: Intent Analysis (First)
- `SemanticIntentEngine::analyzeIntent()` runs first
- Detects: `qc.*`, `parallel.*`, `endpoint.*`, `linear.*`, `sink.*`, `unreachable.*`
- **Rationale**: All semantic rules depend on intent analysis

#### 11.2: Reachability Rules
- Uses: `ReachabilityAnalyzer::analyze()`
- Errors: `UNREACHABLE_NODE`, `DEAD_END_NODE`
- Warnings: `DEAD_END_NODE_WARNING`, `CYCLE_DETECTED_WARNING`
- **Rationale**: Reachability must be checked before endpoint/parallel rules

#### 11.3: QC Routing Semantic Rules
- Errors: `QC_MISSING_FAILURE_PATH`
- Warnings: `QC_THREE_WAY_MISSING_STATUSES`, `QC_THREE_WAY_DEFAULT_ROUTE`, `QC_PASS_ONLY_WARNING`
- **Rationale**: QC routing is critical for workflow correctness

#### 11.4: Parallel/Multi-exit Semantic Rules
- Errors: `LINEAR_NODE_PARALLEL_FLAGS`, `PARALLEL_SPLIT_NO_MERGE`
- Warnings: `MULTI_EXIT_PARALLEL_FLAG`, `SEMANTIC_SPLIT_WARNING`
- **Rationale**: Parallel structure conflicts must be detected

#### 11.5: Endpoint Semantic Rules
- Errors: `ENDPOINT_MISSING`, `UNINTENTIONAL_MULTI_END`, `INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING`
- Warnings: `MULTI_END_WARNING`
- **Rationale**: Endpoint rules depend on reachability and parallel analysis

#### 11.6: Time/SLA Basic Rules
- Warnings: `SLA_ON_END_NODE`, `SLA_ON_START_NODE`
- **Rationale**: Time/SLA rules are soft checks, run last

## Error/Warning Ordering Within Module

Within each module, errors and warnings are ordered by:

1. **Error Code** (alphabetically)
2. **Node Code** (alphabetically, if applicable)
3. **Edge Code** (alphabetically, if applicable)

This ensures deterministic ordering even when multiple errors of the same type exist.

## Conflict Precedence

When multiple rules conflict:

1. **Structural errors** take precedence over semantic errors
2. **Errors** take precedence over warnings
3. **Fatal errors** (Module 1-3) take precedence over all others
4. **Semantic errors** are ordered by sub-module execution order

## Example

For a graph with:
- Missing START node
- Unreachable node
- QC missing policy
- Multiple END nodes

Error order will be:
1. `GRAPH_MISSING_START` (Module 2 - fatal)
2. `QC_MISSING_POLICY` (Module 10 - configuration)
3. `UNREACHABLE_NODE` (Module 11.2 - reachability)
4. `GRAPH_MULTIPLE_FINISH` (Module 2 - warning, but shown after errors)
5. `MULTI_END_WARNING` (Module 11.5 - semantic warning)

## Implementation Notes

- Current implementation in `GraphValidationEngine::validate()` follows this order
- Error/warning arrays are merged in module execution order
- No sorting is applied after merge (preserves order)
- Intent analysis runs once at start of Module 11, results cached in `$this->intents`

## Test Implications

- `ValidateGraphTest` should expect errors in this order
- Snapshot tests should capture this deterministic order
- AutoFix engine should fix errors in this order (fatal first, then semantic)

