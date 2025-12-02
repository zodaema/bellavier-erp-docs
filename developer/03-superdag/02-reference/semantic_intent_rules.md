# Semantic Intent Rules

**Task 19.10: Semantic Repair Engine**

## Overview

Semantic Intent Engine analyzes graph patterns to infer user intent, enabling AutoFix v3 to generate contextual fixes that respect design intent rather than blindly applying structural repairs.

---

## Intent Tags

### QC Routing Intents

#### `qc.two_way`
**Pattern:** QC node with Pass edge + Rework edge, no minor/major split  
**Confidence:** 0.9 (High)  
**Evidence:**
- `has_pass_edge`: true
- `has_rework_edge`: true
- `has_minor_split`: false
- `has_major_split`: false

**Fix Strategy:** Mark rework edge as default route for all fail statuses  
**Risk Score:** 10 (Low)

#### `qc.three_way`
**Pattern:** QC node with Pass edge + at least one fail split (minor or major)  
**Confidence:** 0.8 (High)  
**Evidence:**
- `has_pass_edge`: true
- `has_minor_split`: true/false
- `has_major_split`: true/false
- `missing_statuses`: Array of missing QC statuses

**Fix Strategy:** Create conditional edges for missing QC statuses  
**Risk Score:** 40 (Medium)

---

### Parallel vs Multi-exit Intents

#### `operation.multi_exit`
**Pattern:** Node with multiple outgoing edges, including rework or conditional edges  
**Confidence:** 0.85 (High)  
**Evidence:**
- `has_rework_edges`: true/false
- `has_conditional_edges`: true/false
- `total_outgoing`: Number of outgoing edges

**Fix Strategy:** None (just semantics - not parallel)  
**Risk Score:** 5 (Very Low)

#### `parallel.true_split`
**Pattern:** Node with 2+ normal edges to operation nodes  
**Confidence:** 0.75 (Medium-High)  
**Evidence:**
- `normal_edges_count`: Number of normal edges
- `operation_targets`: Number of operation target nodes

**Fix Strategy:** Mark node as `is_parallel_split = true`  
**Risk Score:** 30 (Medium)

#### `parallel.semantic_split`
**Pattern:** Node with 2+ normal edges to mixed node types  
**Confidence:** 0.6 (Medium)  
**Evidence:**
- `normal_edges_count`: Number of normal edges
- `target_types`: Array of target node types

**Fix Strategy:** Mark node as `is_parallel_split = true` (with lower confidence)  
**Risk Score:** 45 (Medium-High)

---

### Endpoint Intents

#### `endpoint.true_end`
**Pattern:** Single END node in graph  
**Confidence:** 1.0 (Perfect)  
**Evidence:**
- `end_node_count`: 1

**Fix Strategy:** None (already correct)  
**Risk Score:** 0

#### `endpoint.multi_end`
**Pattern:** Multiple END nodes with parallel structure  
**Confidence:** 0.8 (High)  
**Evidence:**
- `end_node_count`: Number of END nodes
- `end_node_codes`: Array of END node codes
- `has_parallel_branches`: true

**Fix Strategy:** None (intentional parallel termination)  
**Risk Score:** 5 (Very Low)

#### `endpoint.unintentional_multi`
**Pattern:** Multiple END nodes without parallel structure  
**Confidence:** 0.7 (Medium-High)  
**Evidence:**
- `end_node_count`: Number of END nodes
- `end_node_codes`: Array of END node codes
- `has_parallel_branches`: false

**Fix Strategy:** Suggest consolidation (high risk)  
**Risk Score:** 60 (High)

#### `endpoint.missing`
**Pattern:** No END node in graph  
**Confidence:** 1.0 (Perfect)  
**Evidence:**
- `end_node_count`: 0

**Fix Strategy:** Create END node and connect terminal operations  
**Risk Score:** 10 (Low)

---

### Reachability Intents

#### `unreachable.intentional_subflow`
**Pattern:** Unreachable node that is part of a connected subgraph  
**Confidence:** 0.7 (Medium-High)  
**Evidence:**
- `subgraph_size`: Number of nodes in subgraph
- `subgraph_nodes`: Array of node codes in subgraph

**Fix Strategy:** None (intentional multi-flow process)  
**Risk Score:** 0

#### `unreachable.unintentional`
**Pattern:** Isolated unreachable node  
**Confidence:** 0.9 (High)  
**Evidence:**
- `is_isolated`: true
- `node_type`: Type of unreachable node

**Fix Strategy:** Suggest connection to candidate upstream nodes (user must choose; never auto-apply)  
**Risk Score:** 65 (High)
**Apply Policy:** Suggest-only (no auto-apply)


---

## Confidence Levels

- **0.9-1.0:** High confidence - Fix can be auto-applied
- **0.7-0.89:** Medium-High confidence - Fix suggested with warning
- **0.5-0.69:** Medium confidence - Fix suggested, requires review
- **< 0.5:** Low confidence - Fix disabled, manual review required

---

## Intent Detection Algorithm

### QC Routing Detection

1. Find all QC nodes
2. For each QC node:
   - Count outgoing edges
   - Categorize edges (pass, rework, conditional)
   - Extract QC statuses from conditional edges
   - Determine pattern:
     - Pass + Rework only → `qc.two_way`
     - Pass + Minor/Major split → `qc.three_way`

### Parallel Detection

1. Find nodes with 2+ outgoing edges
2. For each node:
   - Categorize edges (normal, conditional, rework)
   - Check target node types
   - Determine pattern:
     - Has rework/conditional → `operation.multi_exit`
     - All normal, 2+ operation targets → `parallel.true_split`
     - All normal, mixed targets → `parallel.semantic_split`

### Endpoint Detection

1. Count END nodes
2. If count = 0 → `endpoint.missing`
3. If count = 1 → `endpoint.true_end`
4. If count > 1:
   - Check for parallel structure
   - If parallel → `endpoint.multi_end`
   - If not parallel → `endpoint.unintentional_multi`

### Reachability Detection

1. Build reachability map from START node
2. For each unreachable node:
   - Find connected subgraph
   - If subgraph size > 1 → `unreachable.intentional_subflow`
   - If isolated → `unreachable.unintentional`

---

## Usage in AutoFix v3

Semantic Intent Engine is called before generating fixes:

```php
$intentEngine = new SemanticIntentEngine($db);
$intentAnalysis = $intentEngine->analyzeIntent($nodes, $edges);
$intents = $intentAnalysis['intents'];

// Generate fixes based on intents
foreach ($intents as $intent) {
    switch ($intent['type']) {
        case 'qc.two_way':
            // Generate 2-way fix
            break;
        case 'qc.three_way':
            // Generate 3-way fix
            break;
        // ... etc
    }
}
```

---

---

## Routing Style Rules

**Task 19.17: Semantic Routing Consistency**

### Allowed Routing Patterns

#### Linear-Only
- **Pattern:** 1 incoming edge, 1 outgoing edge
- **Intent:** `operation.linear_only`
- **Use Case:** Simple sequential operations
- **Example:** START → OP1 → OP2 → END

#### Multi-Exit (Conditional)
- **Pattern:** 1 incoming edge, N outgoing edges (all conditional/default)
- **Intent:** `operation.multi_exit`
- **Use Case:** Conditional routing based on token/job properties
- **Example:** OP → (condition A) → OP1, (condition B) → OP2, (default) → OP3

#### Parallel Split
- **Pattern:** 1 incoming edge, N outgoing edges (normal edges, no conditions)
- **Intent:** `parallel.true_split` or `parallel.semantic_split`
- **Use Case:** Split work into parallel branches
- **Example:** OP → OP1 (parallel), OP → OP2 (parallel)

#### Parallel Merge
- **Pattern:** N incoming edges, 1 outgoing edge (merge node)
- **Intent:** `parallel.merge` (implicit from structure)
- **Use Case:** Combine parallel branches
- **Example:** OP1 → MERGE, OP2 → MERGE, MERGE → OP3

#### QC 2-Way
- **Pattern:** QC node → Pass edge + default/else edge
- **Intent:** `qc.two_way`
- **Use Case:** Simple pass/fail routing
- **Example:** QC → (pass) → Next, QC → (else) → Rework

#### QC 3-Way
- **Pattern:** QC node → Pass edge + FailMinor edge + FailMajor edge
- **Intent:** `qc.three_way`
- **Use Case:** Detailed QC routing with severity
- **Example:** QC → (pass) → Next, QC → (fail_minor) → Rework, QC → (fail_major) → Scrap

#### Endpoint (True End)
- **Pattern:** Single END node with no outgoing edges
- **Intent:** `endpoint.true_end`
- **Use Case:** Standard graph termination
- **Example:** ... → END

#### Sink (Expected Dead-End)
- **Pattern:** ReworkSink, ScrapSink, or node with `sink.expected` intent
- **Intent:** `sink.expected`
- **Use Case:** Intentional termination points
- **Example:** ... → REWORK_SINK (no outgoing edges)

---

### Forbidden Patterns

#### Parallel + Conditional Mix (Invalid)
- **Pattern:** Node marked as parallel split + has conditional edges
- **Conflict:** `INTENT_CONFLICT_PARALLEL_CONDITIONAL`
- **Reason:** Parallel splits should use normal edges only; conditional routing is separate pattern
- **Fix:** Remove parallel flag OR convert conditional edges to normal edges

#### END Node with Outgoing Edges
- **Pattern:** END node has outgoing edges
- **Conflict:** `INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING`
- **Reason:** END nodes are terminal; no further routing allowed
- **Fix:** Remove outgoing edges OR change node type

#### QC Node with Non-QC Condition
- **Pattern:** Edge from QC node uses non-QC field (e.g., `token.priority`, `job.type`)
- **Conflict:** `INTENT_CONFLICT_QC_NON_QC_CONDITION` (warning)
- **Reason:** QC nodes should route based on QC results, not general properties
- **Fix:** Use `qc_result.status` or `qc_result.defect_type` instead

#### Node with Conflicting Intents
- **Pattern:** Node has both `parallel.true_split` and `operation.multi_exit` intents
- **Conflict:** `INTENT_CONFLICT_MULTIPLE_ROUTING_STYLES`
- **Reason:** Node cannot be both parallel split and conditional multi-exit
- **Fix:** Clarify design intent (choose one pattern)

#### Linear Node with Multiple Outgoing Edges
- **Pattern:** Node has `operation.linear_only` intent but 2+ outgoing edges
- **Conflict:** `INTENT_CONFLICT_LINEAR_MULTIPLE_EXITS`
- **Reason:** Linear-only nodes must have exactly 1 outgoing edge
- **Fix:** Remove extra edges OR change intent to `operation.multi_exit`

---

## Intent Conflict Detection

**Task 19.17: Detect semantic conflicts between inferred intents and graph structure**

### Conflict Types

1. **Node-Level Conflicts:**
   - Node structure contradicts inferred intent
   - Example: END node with outgoing edges

2. **Edge-Level Conflicts:**
   - Edge type/condition contradicts node intent
   - Example: QC node with non-QC condition

3. **Pattern-Level Conflicts:**
   - Multiple conflicting intents on same node
   - Example: Parallel + conditional mix

### Conflict Detection Algorithm

1. Analyze graph structure → Generate intents
2. For each node:
   - Check if structure matches inferred intent
   - Detect conflicts (structure vs intent)
3. For each edge:
   - Check if edge type/condition matches source node intent
   - Detect conflicts (edge vs node intent)
4. Aggregate conflicts → Return errors/warnings

### Conflict Resolution

- **Errors:** Must be fixed before graph can be saved/published
- **Warnings:** Can be saved but should be reviewed
- **AutoFix:** Some conflicts can be auto-fixed (low risk)

---

## Notes

- Intent detection is **heuristic-based** - not 100% accurate
- Low confidence intents generate warnings, not errors
- User can always override intent-based fixes
- Intent analysis does not modify graph - only provides tags
- **Task 19.17:** Intent conflicts are detected and reported as semantic errors/warnings



#### `qc.pass_only`
**Pattern:** QC node has only a PASS edge and no failure or rework paths  
**Confidence:** 0.85 (High)  
**Evidence:**
- `has_pass_edge`: true
- `has_fail_edges`: false
- `has_rework_edges`: false

**Fix Strategy:** Suggest adding rework/failure routing or marking QC as informational-only  
**Risk Score:** 20 (Low-Medium)  
**Apply Policy:** Suggest-only

#### `operation.linear_only`
**Pattern:** Operation node has exactly one outgoing edge and no conditional/parallel semantics  
**Confidence:** 0.95 (High)  
**Evidence:**
- `total_outgoing`: 1
- `has_conditional_edges`: false
- `has_rework_edges`: false

**Fix Strategy:** None (used to reduce semantic noise and prevent false-positive parallel detection)  
**Risk Score:** 0  
**Apply Policy:** No fix required