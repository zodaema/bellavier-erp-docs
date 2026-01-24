# Task 19.10.1 Results – Implement SemanticIntentEngine.php (v1.0)

## Overview

Task 19.10.1 successfully enhanced `SemanticIntentEngine.php` to match the specifications in `semantic_intent_rules.md` and `autofix_risk_scoring.md`, providing complete semantic intent analysis for AutoFix v3.

**Completion Date:** 2025-12-19  
**Status:** ✅ Completed

---

## Implementation Summary

### Enhanced `analyzeIntent()` Method

**Signature Updated:**
```php
public function analyzeIntent(array $nodes, array $edges, array $options = []): array
```

**Changes:**
- Added `$options` parameter for future extensibility
- Changed internal methods to use pass-by-reference for `$intents` and `$patterns` arrays
- All intent detection methods now populate shared arrays instead of returning separate arrays

**Return Format:**
```php
[
    'intents' => IntentDefinition[],
    'patterns' => PatternDescription[]
]
```

---

## Intent Types Implemented

### QC Routing Intents (3 types)

#### 1. `qc.pass_only` ✅ NEW
- **Pattern:** QC node has only PASS edge, no failure/rework paths
- **Confidence:** 0.85 (High)
- **Risk Base:** 20 (Low-Medium)
- **Evidence Fields:**
  - `total_outgoing`: Number of outgoing edges
  - `has_pass_edge`: true
  - `has_fail_edges`: false
  - `has_rework_edges`: false
- **Notes:** "QC node with only PASS edge and no failure or rework paths"

#### 2. `qc.two_way` ✅ ENHANCED
- **Pattern:** Pass + Rework (no minor/major split)
- **Confidence:** 0.9 (High)
- **Risk Base:** 10 (Low)
- **Evidence Fields:**
  - `total_outgoing`: Number of outgoing edges
  - `has_pass_edge`: true
  - `has_rework_edge`: true
  - `has_rework_edges`: true
  - `has_fail_edges`: false
  - `has_minor_split`: false
  - `has_major_split`: false
- **Notes:** "QC node with pass + rework only (2-way routing)"

#### 3. `qc.three_way` ✅ ENHANCED
- **Pattern:** Pass + Minor + Major
- **Confidence:** 0.8 (High)
- **Risk Base:** 40 (Medium)
- **Evidence Fields:**
  - `total_outgoing`: Number of outgoing edges
  - `has_pass_edge`: true
  - `has_minor_split`: true/false
  - `has_major_split`: true/false
  - `has_fail_edges`: true/false
  - `has_rework_edges`: true/false
  - `missing_statuses`: Array of missing QC statuses
- **Notes:** "QC node with pass + minor/major split (3-way routing)"

---

### Parallel / Multi-Exit Intents (4 types)

#### 1. `operation.linear_only` ✅ NEW
- **Pattern:** Operation node with exactly 1 outgoing edge, no conditional/parallel semantics
- **Confidence:** 0.95 (High)
- **Risk Base:** 0 (No fix required)
- **Evidence Fields:**
  - `total_outgoing`: 1
  - `has_conditional_edges`: false
  - `has_rework_edges`: false
  - `has_parallel_flag`: false
- **Notes:** "Operation node with exactly one outgoing edge and no conditional/parallel semantics"
- **Purpose:** Reduces semantic noise and prevents false-positive parallel detection

#### 2. `operation.multi_exit` ✅ ENHANCED
- **Pattern:** Multiple edges with rework/conditional (not parallel)
- **Confidence:** 0.85 (High)
- **Risk Base:** 5 (Very Low)
- **Evidence Fields:**
  - `total_outgoing`: Number of outgoing edges
  - `has_rework_edges`: true/false
  - `has_conditional_edges`: true/false
  - `has_parallel_flag`: true/false
- **Notes:** "Node with multiple outgoing edges including rework or conditional (multi-exit, not parallel)"

#### 3. `parallel.true_split` ✅ ENHANCED
- **Pattern:** 2+ normal edges to operation nodes
- **Confidence:** 0.75 (Medium-High)
- **Risk Base:** 30 (Medium)
- **Evidence Fields:**
  - `total_outgoing`: Number of outgoing edges
  - `normal_edges_count`: Number of normal edges
  - `operation_targets`: Number of operation target nodes
  - `has_parallel_flag`: true/false
  - `execution_mode`: Execution mode string
- **Notes:** "Node with 2+ normal edges to operation nodes (true parallel split)"

#### 4. `parallel.semantic_split` ✅ ENHANCED
- **Pattern:** 2+ normal edges to mixed node types
- **Confidence:** 0.6 (Medium)
- **Risk Base:** 45 (Medium-High)
- **Evidence Fields:**
  - `total_outgoing`: Number of outgoing edges
  - `normal_edges_count`: Number of normal edges
  - `target_types`: Array of unique target node types
  - `has_parallel_flag`: true/false
- **Notes:** "Node with 2+ normal edges to mixed node types (semantic split)"

---

### Endpoint Intents (4 types)

#### 1. `endpoint.missing` ✅ ENHANCED
- **Pattern:** No END node in graph
- **Confidence:** 1.0 (Perfect)
- **Risk Base:** 10 (Low)
- **Scope:** `graph`
- **Evidence Fields:**
  - `end_node_count`: 0
  - `terminal_node_count`: Number of terminal nodes (0 outgoing edges)
  - `terminal_node_codes`: Array of terminal node codes
- **Notes:** "Graph has no END node"

#### 2. `endpoint.true_end` ✅ ENHANCED
- **Pattern:** Single END node
- **Confidence:** 1.0 (Perfect)
- **Risk Base:** 0 (No fix required)
- **Scope:** `node`
- **Evidence Fields:**
  - `end_node_count`: 1
  - `end_node_ids`: Array with single END node ID
  - `end_node_codes`: Array with single END node code
- **Notes:** "Graph has single END node (correct)"

#### 3. `endpoint.multi_end` ✅ ENHANCED
- **Pattern:** Multiple END nodes with parallel structure
- **Confidence:** 0.8 (High)
- **Risk Base:** 5 (Very Low)
- **Scope:** `graph`
- **Evidence Fields:**
  - `end_node_count`: Number of END nodes
  - `end_node_ids`: Array of END node IDs
  - `end_node_codes`: Array of END node codes
  - `has_parallel_branches`: true
- **Notes:** "Graph has multiple END nodes with parallel structure (intentional)"

#### 4. `endpoint.unintentional_multi` ✅ ENHANCED
- **Pattern:** Multiple END nodes without parallel structure
- **Confidence:** 0.7 (Medium-High)
- **Risk Base:** 60 (High)
- **Scope:** `graph`
- **Evidence Fields:**
  - `end_node_count`: Number of END nodes
  - `end_node_ids`: Array of END node IDs
  - `end_node_codes`: Array of END node codes
  - `has_parallel_branches`: false
- **Notes:** "Graph has multiple END nodes without parallel structure (unintentional)"

---

### Reachability Intents (2 types)

#### 1. `unreachable.intentional_subflow` ✅ ENHANCED
- **Pattern:** Unreachable node that is part of a connected subgraph
- **Confidence:** 0.7 (Medium-High)
- **Risk Base:** 0 (No fix required)
- **Scope:** `node`
- **Evidence Fields:**
  - `unreachable_node_ids`: Array of unreachable node IDs in subgraph
  - `component_size`: Size of connected component
  - `subgraph_size`: Number of nodes in subgraph
  - `subgraph_nodes`: Array of node codes in subgraph
- **Notes:** "Unreachable node that is part of a connected subgraph (intentional multi-flow)"
- **Heuristic:** Checks for TEMPLATE nodes, reference types, or large subgraphs (> 3 nodes)

#### 2. `unreachable.unintentional` ✅ ENHANCED
- **Pattern:** Isolated unreachable node
- **Confidence:** 0.9 (High)
- **Risk Base:** 65 (High)
- **Scope:** `node`
- **Evidence Fields:**
  - `unreachable_node_ids`: Array with single node ID
  - `component_size`: Size of connected component (usually 1)
  - `is_isolated`: true
  - `node_type`: Type of unreachable node
  - `subgraph_size`: Number of nodes in subgraph
- **Notes:** "Isolated unreachable node (unintentional)"

---

## IntentDefinition Structure

Every intent now includes all required fields:

```php
[
    'type'       => 'qc.two_way',
    'scope'      => 'node',          // 'node' | 'edge' | 'graph'
    'node_id'    => 123,             // optional if scope != node
    'node_code'  => 'QC1',           // optional
    'edge_id'    => null,            // optional
    'confidence' => 0.90,            // 0.0 - 1.0
    'risk_base'  => 10,              // base risk from autofix_risk_scoring.md
    'evidence'   => [                // structured info per semantic_intent_rules.md
        'total_outgoing'     => 2,
        'has_pass_edge'      => true,
        'has_rework_edges'   => true,
        // ... etc
    ],
    'notes'      => 'QC node with pass + rework only (2-way routing)',
]
```

---

## Enhanced Helper Methods

### `isIntentionalSubflow()` ✅ NEW
- **Purpose:** Check if unreachable subgraph looks intentional
- **Heuristics:**
  - Subgraph contains TEMPLATE nodes
  - Subgraph has reference behavior codes
  - Subgraph is large (> 3 nodes) and well-connected
- **Returns:** `bool`

### `checkParallelBranchesToEnds()` ✅ ENHANCED
- **Purpose:** Check if multiple END nodes are reached from parallel branches
- **Enhanced Logic:**
  - Checks if any END node has incoming edges from nodes marked as `is_parallel_split`
  - Checks `execution_mode === 'parallel'`
  - More accurate than simple count check
- **Returns:** `bool`

---

## Pattern Descriptions

The `patterns` array now contains human-readable descriptions for debugging/UI:

Examples:
- `"QC node \"QC1\" appears to be 2-way (pass/rework)"`
- `"Node \"CUT1\" appears to be a multi-exit operation (non-parallel)"`
- `"Graph has 3 END nodes without parallel structure (unintentional)"`
- `"Node \"OP5\" is unreachable and appears unintentional"`

**Note:** `operation.linear_only` and `endpoint.true_end` do not generate patterns (reduces noise).

---

## Acceptance Criteria Status

| Requirement | Status |
|------------|--------|
| `analyzeIntent()` returns intents with all required types | ✅ Complete |
| QC intents: `qc.two_way`, `qc.three_way`, `qc.pass_only` | ✅ Complete |
| Parallel/multi-exit intents: `operation.linear_only`, `operation.multi_exit`, `parallel.true_split`, `parallel.semantic_split` | ✅ Complete |
| Endpoint intents: `endpoint.missing`, `endpoint.true_end`, `endpoint.multi_end`, `endpoint.unintentional_multi` | ✅ Complete |
| Reachability intents: `unreachable.intentional_subflow`, `unreachable.unintentional` | ✅ Complete |
| Every intent has `confidence`, `risk_base`, `evidence` fields | ✅ Complete |
| No DB queries within SemanticIntentEngine | ✅ Complete |
| Pure analysis only (no graph modification) | ✅ Complete |
| Documentation created | ✅ Complete |

---

## Implementation Details

### QC Intent Detection Logic

1. **Find all QC nodes**
2. **For each QC node:**
   - Count outgoing edges
   - Categorize edges (pass, rework, conditional)
   - Extract QC statuses from conditional edges
   - Determine pattern:
     - Pass only, no fail/rework → `qc.pass_only`
     - Pass + Rework, no minor/major → `qc.two_way`
     - Pass + Minor/Major split → `qc.three_way`

### Parallel Intent Detection Logic

1. **For each operation node:**
   - Count outgoing edges
   - If count = 1 and no conditional/rework/parallel flags → `operation.linear_only`
   - If count >= 2:
     - Has rework/conditional → `operation.multi_exit`
     - All normal, 2+ operation targets → `parallel.true_split`
     - All normal, mixed targets → `parallel.semantic_split`

### Endpoint Intent Detection Logic

1. **Find END nodes** (by `node_type` or `is_end` flag)
2. **Find terminal nodes** (0 outgoing edges, not START/REWORK_SINK)
3. **Count END nodes:**
   - 0 → `endpoint.missing`
   - 1 → `endpoint.true_end`
   - > 1:
     - Check parallel branches → `endpoint.multi_end` or `endpoint.unintentional_multi`

### Reachability Intent Detection Logic

1. **Build reachability map** from START node
2. **For each unreachable node:**
   - Find connected subgraph
   - Check if intentional (TEMPLATE, reference, large subgraph)
   - If intentional → `unreachable.intentional_subflow`
   - If isolated → `unreachable.unintentional`

---

## Risk Base Mapping

All intents now include `risk_base` from `autofix_risk_scoring.md`:

| Intent Type | Risk Base | Level |
|------------|-----------|-------|
| `qc.pass_only` | 20 | Low-Medium |
| `qc.two_way` | 10 | Low |
| `qc.three_way` | 40 | Medium |
| `operation.linear_only` | 0 | None |
| `operation.multi_exit` | 5 | Very Low |
| `parallel.true_split` | 30 | Medium |
| `parallel.semantic_split` | 45 | Medium-High |
| `endpoint.missing` | 10 | Low |
| `endpoint.true_end` | 0 | None |
| `endpoint.multi_end` | 5 | Very Low |
| `endpoint.unintentional_multi` | 60 | High |
| `unreachable.intentional_subflow` | 0 | None |
| `unreachable.unintentional` | 65 | High |

---

## Limitations & Notes

### Known Limitations

1. **Intent Detection is Heuristic-Based**
   - Not 100% accurate
   - Low confidence intents should generate warnings, not errors
   - User can always override intent-based fixes

2. **Parallel Branch Detection**
   - `checkParallelBranchesToEnds()` uses simple heuristics
   - Could be enhanced with full graph traversal analysis
   - Current implementation checks for `is_parallel_split` flags and `execution_mode`

3. **Intentional Subflow Detection**
   - `isIntentionalSubflow()` uses pattern matching (TEMPLATE, reference)
   - Large subgraphs (> 3 nodes) are assumed intentional
   - May need refinement based on real-world usage

4. **No Database Queries**
   - Pure analysis from `nodes` and `edges` arrays
   - Does not query behavior definitions or work center data
   - Relies on data already present in graph structure

### Design Decisions

1. **Pass-by-Reference for Arrays**
   - Changed internal methods to use `&$intents` and `&$patterns`
   - Reduces array merging overhead
   - Cleaner code structure

2. **Pattern Descriptions**
   - Added human-readable patterns for debugging/UI
   - Some intents (linear_only, true_end) don't generate patterns to reduce noise

3. **Scope Field**
   - Added `scope` field to distinguish node-level vs graph-level intents
   - Helps AutoFix engine target fixes correctly

4. **Evidence Fields**
   - All evidence fields match `semantic_intent_rules.md` exactly
   - Provides complete context for fix generation

---

## Integration Notes

### For AutoFix Engine v3

`SemanticIntentEngine` is now ready to be used by `GraphAutoFixEngine`:

```php
$intentEngine = new SemanticIntentEngine($db);
$intentAnalysis = $intentEngine->analyzeIntent($nodes, $edges);
$intents = $intentAnalysis['intents'];

// AutoFix can now use:
// - $intent['type'] to determine fix pattern
// - $intent['risk_base'] as starting point for risk calculation
// - $intent['evidence'] for contextual fix generation
// - $intent['confidence'] to adjust risk scores
```

### For GraphValidationEngine v3

`SemanticIntentEngine` can be used to add semantic validation layer:

```php
$intentEngine = new SemanticIntentEngine($db);
$intentAnalysis = $intentEngine->analyzeIntent($nodes, $edges);
$intents = $intentAnalysis['intents'];

// Validation can check:
// - Low confidence intents → Semantic warning
// - Intent mismatches → Semantic error
// - Missing required intents → Validation error
```

---

## Summary

Task 19.10.1 successfully implemented all required intent types and enhanced `SemanticIntentEngine.php` to match the specifications:

- ✅ 13 intent types implemented (3 QC, 4 parallel/multi-exit, 4 endpoint, 2 reachability)
- ✅ All intents include `scope`, `confidence`, `risk_base`, `evidence`, `notes` fields
- ✅ Evidence fields match `semantic_intent_rules.md` exactly
- ✅ Risk base values match `autofix_risk_scoring.md` exactly
- ✅ Pattern descriptions for debugging/UI
- ✅ No database queries (pure analysis)
- ✅ No graph modification (read-only)

The `SemanticIntentEngine` is now ready for integration with AutoFix v3 and GraphValidationEngine v3.

