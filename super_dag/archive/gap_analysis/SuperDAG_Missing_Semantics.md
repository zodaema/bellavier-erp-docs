# SuperDAG Missing Semantics

**Status:** Active Documentation (Updated for Task 19.7, 19.8, 19.9, 19.10, 20, 20.2)  
**Date:** 2025-01-XX (Last Updated)  
**Purpose:** Document semantics and features that are NOT implemented or are incomplete in the current codebase

> **⚠️ IMPORTANT:** This document describes **what is missing or incomplete**, based on:
> 1. Code analysis (stubs, TODOs, not implemented messages)
> 2. Spec/documentation references that don't match code
> 3. Common DAG/workflow patterns that are not present

---

## Table of Contents

1. [OR-Join / XOR-Join](#or-join--xor-join)
2. [Multi-Source Inbound / Error Convergence](#multi-source-inbound--error-convergence)
3. [Resource Consolidation Joins](#resource-consolidation-joins)
4. [Re-entry / Loopback](#re-entry--loopback)
5. [Stub Implementations](#stub-implementations)
6. [Spec vs Code Gaps](#spec-vs-code-gaps)
7. [Conditional Edge × QC Integration](#conditional-edge--qc-integration)
8. [Advanced Expression Evaluation](#advanced-expression-evaluation)
9. [Subgraph Fork Mode](#subgraph-fork-mode)
10. [Token Reopen Previous Node](#token-reopen-previous-node)

---

## OR-Join / XOR-Join

### Status: **NOT IMPLEMENTED**

**Evidence:**
- No code found for OR-Join or XOR-Join semantics
- Merge policies only support: ALL, ANY, AT_LEAST, TIMEOUT_FAIL
- No distinction between "OR" (any branch) and "XOR" (exactly one branch)

**Current Behavior:**
- `ANY` merge policy is closest to OR-Join, but:
  - It waits for "any branch completed" (not "any branch arrives")
  - It doesn't prevent multiple branches from completing
  - It doesn't cancel other branches when one completes

**Missing:**
- XOR-Join: Exactly one branch should complete, others should be cancelled
- OR-Join with cancellation: When one branch completes, cancel others
- Branch cancellation logic when merge condition met

**Location in Code:**
- `ParallelMachineCoordinator::canMerge()` - Only checks completion, doesn't cancel branches

---

## Multi-Source Inbound / Error Convergence

### Status: **PARTIALLY IMPLEMENTED**

**Current Behavior:**
- Merge nodes can have multiple incoming edges (2+)
- All branches must complete (or meet merge policy) before merge proceeds

**Missing:**
- **Error Convergence:** If one branch fails/scraps, what happens to other branches?
  - Current: Other branches continue, merge may never complete
  - Missing: Option to cancel other branches on error
- **Multi-Source with Different Paths:** Branches from different source nodes
  - Current: Supported (merge node accepts any incoming edges)
  - Missing: Validation that all branches are from same parallel group

**Location in Code:**
- `DAGRoutingService::handleMergeNode()` - Doesn't handle branch failures
- No error convergence logic

---

## Resource Consolidation Joins

### Status: **NOT IMPLEMENTED**

**Definition:** Multiple resources (tokens) merge back to use a single machine/resource

**Current Behavior:**
- Merge nodes merge tokens, but:
  - They don't consolidate resources
  - They don't queue tokens for shared resources
  - Machine allocation is per-token, not per-resource

**Missing:**
- Resource pool management
- Token queuing for shared resources
- Resource consolidation after merge

**Location in Code:**
- No code found for resource consolidation

---

## Re-entry / Loopback

### Status: **PARTIALLY IMPLEMENTED**

**Current Behavior:**
- Rework edges can route tokens back to previous nodes
- Tokens can loop through graph (no cycle detection in routing)

**Missing:**
- **Cycle Detection:** No validation that graph doesn't have cycles
- **Re-entry Limit:** No limit on how many times a token can re-enter a node
- **Loopback Tracking:** No tracking of how many times token has looped

**Location in Code:**
- `DAGRoutingService::routeToken()` - No cycle detection
- `validateGraphStructure()` - No cycle validation

**Note:** Rework is implemented via separate token spawn (`spawnReworkToken()`), not true loopback.

---

## Stub Implementations

### 1. reopenPreviousNode()

**Location:** `DagExecutionService::reopenPreviousNode()`

**File:** `source/BGERP/Dag/DagExecutionService.php:317`

**Status:** **STUB - NOT IMPLEMENTED**

**Code:**
```php
public function reopenPreviousNode(int $tokenId, int $nodeId): array
{
    // Phase 1: Stub - not implemented yet
    return [
        'ok' => false,
        'from_node_id' => null,
        'to_node_id' => null,
        'error' => 'not_implemented',
        'message' => 'reopenPreviousNode is not implemented in Phase 1'
    ];
}
```

**Purpose (from comment):** Reopen previous node for rework functionality

**Missing:** Full implementation of token moving backward in graph

---

### 2. Subgraph Fork Mode

**Location:** `DAGRoutingService::handleSubgraphNode()`

**File:** `source/BGERP/Service/DAGRoutingService.php:2005`

**Status:** **NOT IMPLEMENTED**

**Code:**
```php
// Fork mode: not implemented yet
throw new \Exception("Fork mode not implemented yet for subgraph nodes");
```

**Also:** `source/BGERP/Service/DAGRoutingService.php:2102`
```php
// Fork mode: not implemented yet
throw new \Exception("Fork mode exit not implemented yet");
```

**Missing:** Fork mode for subgraph nodes (parallel execution within subgraph)

---

## Spec vs Code Gaps

### 1. Conditional Edge × QC Integration

**Status:** ✅ **IMPLEMENTED (Task 18, 19.1, 19.2)**

**Implementation:**
- Task 18: Unified `ConditionEvaluator` class with `qc_result.status` support
- Task 19.1: Dropdown-only conditional edge editor with QC-aware presets
- Task 19.2: Multi-group condition support with QC templates and coverage validation
- Conditional edges automatically evaluated using `ConditionEvaluator`
- QC result properties (`qc_result.status`, `qc_result.defect_type`, `qc_result.severity`) available in condition evaluation

**Location in Code:**
- `source/BGERP/Service/ConditionEvaluator.php` - Unified condition evaluation (Task 18)
- `assets/javascripts/dag/modules/conditional_edge_editor.js` - UI editor (Task 19.1, 19.2)
- `DAGRoutingService::selectNextNode()` - Uses `ConditionEvaluator` for edge selection

---

### 2. Advanced Expression Evaluation

**Current Implementation:**
- Simple expression parser in `evaluateExpression()`
- Supports: `token.qty > 10 AND token.priority = 'high'`
- Basic pattern matching

**Missing:**
- Complex expressions (nested parentheses, functions)
- QC result field access in expressions
- Component binding status in expressions
- Time-based conditions (e.g., "token.age > 3600")

**Location in Code:**
- `DAGRoutingService::evaluateExpression()` - Simple parser only

---

### 3. Join Quorum (N_OF_M)

**Spec Reference:** `dag_routing_api.php` validates `join_quorum` field

**Current Implementation:**
- `join_quorum` field exists in schema
- Validation exists in `validateGraphStructure()`
- But merge logic doesn't use `join_quorum`

**Missing:**
- Merge logic that uses `join_quorum` instead of `parallel_merge_at_least_count`
- Support for legacy join nodes with quorum

**Location in Code:**
- `ParallelMachineCoordinator::canMerge()` - Uses `parallel_merge_at_least_count`, not `join_quorum`
- Legacy join nodes are deprecated (Task 17.2)

---

## Conditional Edge × QC Integration

### Status: **✅ IMPLEMENTED (Task 18, 19.1, 19.2)**

**Task 18:** Unified condition model with `ConditionEvaluator` class  
**Task 19.1:** Dropdown-only conditional edge editor with QC-aware presets  
**Task 19.2:** Multi-group condition support with QC templates and coverage validation

### Current Implementation

**QC Pass Routing (Task 18, 19.1, 19.2):**
- **Location:** `DAGRoutingService::selectNextNode()` → `ConditionEvaluator::evaluate()`
- **Method:** Unified condition evaluation using `ConditionEvaluator`
- **Condition Format:**
  ```json
  {
    "type": "token_property",
    "property": "qc_result.status",
    "operator": "==",
    "value": "pass"
  }
  ```
- **Multi-Group Support (Task 19.2):**
  ```json
  {
    "type": "or",
    "groups": [
      {
        "type": "and",
        "conditions": [
          { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass" }
        ]
      }
    ]
  }
  ```

**QC Fail Routing:**
- **Location:** `DAGRoutingService::handleQCFailWithPolicy()`
- **Method 1:** Explicit edge type (`edge_type = 'rework'`) - Legacy support
- **Method 2:** Conditional edge with `qc_result.status == 'fail_minor'` or `'fail_major'` (Task 19.1, 19.2)

**UI Support (Task 19.1, 19.2):**
- QC-aware presets for edges from QC nodes
- QC templates (Template A: Basic QC Split, Template B: Severity + Quantity)
- QC coverage validation (ensures all statuses covered)
- Dropdown-only editor (no free text)

**Backend Support (Task 18):**
- `ConditionEvaluator` class evaluates conditions at runtime
- Supports `qc_result.status`, `qc_result.defect_type`, `qc_result.severity`
- QC result available in condition evaluation context
- Multi-group format evaluation (OR between groups, AND within groups)

### What Was Missing (Now Implemented)

✅ **QC result property access:** `qc_result.status` now supported  
✅ **Conditional edge evaluation:** Automatic evaluation using `ConditionEvaluator`  
✅ **QC coverage validation:** Frontend validates all QC statuses are covered  
✅ **QC templates:** Preset templates for common QC routing scenarios  
✅ **Multi-group support:** Complex routing rules with AND/OR logic

---

## Advanced Expression Evaluation

### Current Implementation

**Location:** `DAGRoutingService::evaluateExpression()`

**File:** `source/BGERP/Service/DAGRoutingService.php:1001`

**Supported:**
- Simple expressions: `token.qty > 10 AND token.priority = 'high'`
- AND/OR operators
- Basic variable access: `token.*`, `job.*`, `node.*`

### Missing Features

1. **Nested Parentheses:** `(token.qty > 10 AND token.priority = 'high') OR job.target_qty > 100`
2. **Functions:** `SUM(token.qty)`, `COUNT(branches)`, `AVG(cycle_time)`
3. **QC Result Access:** `token.qc_result.pass`, `token.qc_result.defect_code`
4. **Component Binding:** `token.component_bindings.complete`, `token.missing_components`
5. **Time-Based:** `token.age > 3600`, `NOW() - token.spawned_at > 3600`
6. **String Functions:** `CONTAINS(token.serial_number, 'BATCH')`, `STARTS_WITH(token.serial_number, 'TOTE')`

---

## Subgraph Fork Mode

### Current Implementation

**Location:** `DAGRoutingService::handleSubgraphNode()`

**File:** `source/BGERP/Service/DAGRoutingService.php:2005`

**Status:** **NOT IMPLEMENTED**

**Code:**
```php
// Fork mode: not implemented yet
throw new \Exception("Fork mode not implemented yet for subgraph nodes");
```

**Also:** Exit logic (`source/BGERP/Service/DAGRoutingService.php:2102`):
```php
// Fork mode: not implemented yet
throw new \Exception("Fork mode exit not implemented yet");
```

### What's Missing

**Fork Mode:** Parallel execution within subgraph (multiple tokens spawned in subgraph)

**Current:** Subgraph execution is sequential (one token at a time)

**Missing:**
- Fork mode configuration in subgraph node
- Token spawning logic for subgraph fork
- Merge logic for subgraph fork exit

---

## Token Reopen Previous Node

### Current Implementation

**Location:** `DagExecutionService::reopenPreviousNode()`

**File:** `source/BGERP/Dag/DagExecutionService.php:317`

**Status:** **STUB - NOT IMPLEMENTED**

**Code:**
```php
public function reopenPreviousNode(int $tokenId, int $nodeId): array
{
    // Phase 1: Stub - not implemented yet
    return [
        'ok' => false,
        'error' => 'not_implemented',
        'message' => 'reopenPreviousNode is not implemented in Phase 1'
    ];
}
```

### What's Missing

**Purpose:** Move token backward in graph (for rework without spawning new token)

**Current Rework:** Uses `spawnReworkToken()` which creates new token

**Missing:**
- Logic to move existing token backward
- Validation that target node is reachable from current position
- History tracking of node re-entry

---

## Decision Node Condition Rule

### Current Implementation

**Location:** `DAGRoutingService::handleDecisionNode()`

**File:** `source/BGERP/Service/DAGRoutingService.php:1800`

**Status:** **IMPLEMENTED BUT SEPARATE FROM selectNextNode()**

**Behavior:**
- Decision nodes use `condition_rule` JSON field (not `edge_condition`)
- Evaluation order based on `priority` field
- First matching condition wins

**Gap:**
- `selectNextNode()` uses `edge_condition` (for conditional edges)
- `handleDecisionNode()` uses `condition_rule` (for decision nodes)
- **Two separate systems** for condition evaluation

**Missing:**
- Unified condition evaluation system
- `selectNextNode()` doesn't check decision node logic

---

## Component Completeness Validation

### Current Implementation

**Location:** `DagExecutionService::validateComponentCompleteness()`

**File:** `source/BGERP/Dag/DagExecutionService.php:427`

**Status:** **IMPLEMENTED (Task 13.6)**

**Behavior:**
- Validates component bindings before routing
- Blocks routing if components incomplete
- Returns missing components list

**Note:** This is implemented, but included here for completeness.

---

## Waiting Queue Management

### Current Implementation

**Location:** `DAGRoutingService::routeToNode()`

**Status:** **PARTIALLY IMPLEMENTED**

**Behavior:**
- Tokens set to 'waiting' when limits reached
- Queue position calculated (`getQueuePosition()`)
- But: No automatic activation when limit clears

**Missing:**
- Background process to activate waiting tokens
- Queue position tracking over time
- Priority-based queue ordering

**Location in Code:**
- `DAGRoutingService::routeToNode()` - Sets status to 'waiting'
- No code found for automatic activation

---

## ETA Calculation

### Current Implementation

**Location:** `ParallelMachineCoordinator::getETA()`

**File:** `source/BGERP/Dag/ParallelMachineCoordinator.php:373`

**Status:** **PARTIALLY IMPLEMENTED**

**Behavior:**
- Estimates time for parallel block completion
- Uses machine cycle time and elapsed time
- Returns longest branch ETA

**Missing:**
- Queue position consideration (if branch waiting for machine)
- Machine availability prediction
- Historical cycle time data
- Branch dependency analysis

**Limitations:**
- Returns `null` if branches waiting (cannot estimate)
- Doesn't consider queue position
- Doesn't use historical data

---

## Summary

This document identifies **missing or incomplete semantics** in SuperDAG execution engine. Key findings:

1. **OR-Join / XOR-Join:** Not implemented (ANY policy is closest but doesn't cancel branches)
2. **Error Convergence:** Not implemented (branch failures don't affect other branches)
3. **Resource Consolidation:** Not implemented
4. **Re-entry / Loopback:** Partially implemented (rework spawns new token, no true loopback)
5. **Stub Implementations:** 2 stubs found (`reopenPreviousNode()`, subgraph fork mode)
6. **Conditional Edge × QC:** ✅ **IMPLEMENTED (Task 18, 19.1, 19.2)** - Unified condition model with QC support
7. **Advanced Expressions:** Limited (simple parser only, no functions, but QC access now supported via `qc_result.*` properties)
8. **Join Quorum:** Field exists but not used in merge logic
9. **Waiting Queue:** Partially implemented (no automatic activation)
10. **ETA Calculation:** Partially implemented (limited to machine cycles, no queue consideration)

**Next Steps:**
- Use this document to prioritize missing features for future tasks
- Reference actual code locations when implementing missing semantics
- Maintain this document as features are added

---

## Graph Validation & AutoFix

### Status: **✅ IMPLEMENTED** (Task 19.7, 19.8, 19.9, 19.10)

**Evidence:**
- `GraphValidationEngine` class provides unified validation (Task 19.7)
- `GraphAutoFixEngine` class provides fix suggestions (Task 19.8, 19.9, 19.10)
- `SemanticIntentEngine` class analyzes graph patterns (Task 19.10, 19.10.1)

**Current Behavior:**
- 11 validation modules covering all graph rules
- AutoFix v1: Metadata fixes (mark flags, set defaults)
- AutoFix v2: Structural fixes (create edges/nodes)
- AutoFix v3: Semantic fixes with risk scoring

**Completed:**
- ✅ Unified validation engine (replaces scattered validation)
- ✅ Safe AutoFix suggestions (read-only, user confirms)
- ✅ Risk scoring for fixes (0-100 scale)
- ✅ Semantic intent analysis (13 intent types)
- ✅ QC routing validation and fixes
- ✅ Parallel structure validation
- ✅ Conditional edge validation
- ✅ Reachability analysis

**Location in Code:**
- `source/BGERP/Dag/GraphValidationEngine.php`
- `source/BGERP/Dag/GraphAutoFixEngine.php`
- `source/BGERP/Dag/SemanticIntentEngine.php`
- `source/dag_routing_api.php` (graph_validate, graph_autofix actions)

---

**Last Updated:** January 2025 (Added Graph Validation & AutoFix section, ETA/SLA Engine, Timezone Normalization)

