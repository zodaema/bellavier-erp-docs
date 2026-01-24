# 27.16 Graph Linter Rules - Implementation Plan

> **Feature:** Validation Engine to Prevent Bad Graphs  
> **Priority:** 🟡 MEDIUM (Quality Assurance)  
> **Estimated Duration:** 5-6 Days (~44 hours)  
> **Dependencies:** 27.13 Component Node, 27.15 QC Rework V2  
> **Spec:** `01-concepts/GRAPH_LINTER_RULES.md`  
> **Policy Reference:** `docs/developer/01-policy/DEVELOPER_POLICY.md`
> **Last Updated:** December 6, 2025 (CTO Audit Applied)

---

## 🛡️ Enterprise Safety Guards

```
┌─────────────────────────────────────────────────────────────────┐
│              SAFETY GUARDS (Validation Protection)              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. RATE LIMITING                                               │
│     ─────────────                                               │
│     • RateLimiter::check($member, 30, 60, 'validate_graph')     │
│     • Max 30 validations per minute per user                    │
│     • Prevents abuse and DoS                                    │
│                                                                 │
│  2. MAX GRAPH SIZE                                              │
│     ─────────────                                               │
│     • MAX_NODES_PER_GRAPH = 500                                 │
│     • MAX_EDGES_PER_GRAPH = 1000                                │
│     • Larger graphs = async validation                          │
│                                                                 │
│  3. VALIDATION TIMEOUT                                          │
│     ──────────────────                                          │
│     • Max 30 seconds per validation                             │
│     • Circuit breaker for complex graphs                        │
│                                                                 │
│  4. FEATURE FLAG                                                │
│     ────────────                                                │
│     • GRAPH_LINTER_ENABLED = true                               │
│     • Can disable if causing issues                             │
│                                                                 │
│  5. CACHING                                                     │
│     ───────                                                     │
│     • Cache key: graph_validation_{graph_id}_{content_hash}     │
│     • TTL: 5 minutes or until graph modified                    │
│     • Prevents redundant validations                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Config Constants:**
```php
// In config/features.php
define('GRAPH_LINTER_ENABLED', true);
define('MAX_NODES_PER_GRAPH', 500);
define('MAX_EDGES_PER_GRAPH', 1000);
define('GRAPH_VALIDATION_TIMEOUT_SECONDS', 30);
```

---

## ⚡ Performance Requirements

| Graph Size | Max Validation Time | Notes |
|------------|---------------------|-------|
| < 50 nodes | < 100ms | Real-time feedback |
| 50-200 nodes | < 500ms | Acceptable delay |
| 200-500 nodes | < 2s | Show progress indicator |
| > 500 nodes | Async | Background job + notification |

---

## 📐 Enterprise Compliance Notes

**Per DEVELOPER_POLICY.md:**
- ✅ `RateLimiter::check()` for validate_graph action
- ✅ `json_success()` / `json_error()` only
- ✅ i18n: All error messages must use `translate('key', 'English default')`

**i18n Requirement for Error Messages:**
```php
// ❌ FORBIDDEN:
'message' => "Node '{$code}' is not reachable from START"

// ✅ REQUIRED:
'message' => translate('linter.s3_unreachable', "Node '%s' is not reachable from START", $code)
```

---

## 📊 Purpose

```
┌─────────────────────────────────────────────────────────────────┐
│              GRAPH LINTER: PREVENT BAD GRAPHS                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ WITHOUT LINTER:                                             │
│     • Missing Component Node under split                        │
│     • Component Node in wrong position (after merge)            │
│     • QC Node with edge_condition (violates V2 philosophy)      │
│     • Orphan nodes                                              │
│     → Runtime failures, debugging nightmare                     │
│                                                                 │
│  ✅ WITH LINTER:                                                │
│     • Validate on save / publish                                │
│     • Block graphs that break concepts                          │
│     • Show warnings with fix suggestions                        │
│     → Clean graphs, predictable behavior                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Rule Categories

| Category | Severity | Count | Description |
|----------|----------|-------|-------------|
| **STRUCTURAL (S)** | 🔴 ERROR | 4 | Basic graph structure (S1-S4) |
| **COMPONENT (C)** | 🔴 ERROR | 3 | Component anchor rules (C1-C3) |
| **QC (Q)** | 🔴 ERROR | 2 | QC node rules (Q1-Q2) |
| **BEST_PRACTICE (B)** | 🟢 INFO | 4 | Suggestions (B1-B4) |

### Rule Severity Matrix

| Rule | Default Severity | Blocks Save? | Blocks Publish? | Auto-Fix? |
|------|------------------|--------------|-----------------|-----------|
| S1 | ERROR | ✅ | ✅ | ❌ |
| S2 | ERROR | ✅ | ✅ | ✅ (delete orphan) |
| S3 | ERROR | ✅ | ✅ | ❌ |
| S4 | ERROR | ✅ | ✅ | ❌ |
| C1 | ERROR | ✅ | ✅ | ✅ (format fix) |
| C2 | ERROR | ✅ | ✅ | ❌ |
| C3 | ERROR | ❌ | ✅ | ❌ |
| Q1 | ERROR | ✅ | ✅ | ✅ (remove condition) |
| Q2 | WARNING | ❌ | ⚠️ | ❌ |
| B1-4 | INFO | ❌ | ❌ | ❌ |

---

## 📋 Implementation Overview

```
┌─────────────────────────────────────────────────────────────────┐
│              GRAPH LINTER IMPLEMENTATION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 1: Core Engine + S Rules                                   │
│  ├─ 27.16.1 Integrate with GraphValidationEngine               │
│  ├─ 27.16.2 Rule S1: Start/End validation                      │
│  ├─ 27.16.3 Rule S2: Orphan node detection                     │
│  └─ 27.16.4 Rule S3: Reachability check (forward + reverse)    │
│                                                                 │
│  Day 2: S Rules (continued) + C Rules                          │
│  ├─ 27.16.5 Rule S4: Merge node edges                          │
│  ├─ 27.16.6 Rule C1: anchor_slot required + format             │
│  └─ 27.16.7 Rule C2: Unique anchor slots                       │
│                                                                 │
│  Day 3: Q Rules + C3                                            │
│  ├─ 27.16.8 Rule Q1: QC no edge_condition (STRICT!)            │
│  ├─ 27.16.9 Rule Q2: QC has operation upstream                 │
│  └─ 27.16.10 Rule C3: Mapping validation (publish only)        │
│                                                                 │
│  Day 4: B Rules + UI                                            │
│  ├─ 27.16.11 Rule B1-B4: Best practices                        │
│  └─ 27.16.12 Graph Designer: Linter panel                      │
│                                                                 │
│  Day 5: Auto-fix + Tests + API                                  │
│  ├─ 27.16.13 API: validate_graph, auto_fix_graph               │
│  └─ 27.16.14 Tests: 25+ tests                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🌐 API Specification

### Action: `validate_graph`

**File:** `source/dag_routing_api.php`

**Request:**
```json
{
  "action": "validate_graph",
  "graph_id": 123,
  "mode": "save",
  "nodes": null,
  "edges": null
}
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| graph_id | int | ✅ | Graph to validate |
| mode | string | ❌ | `"save"` (default) or `"publish"` |
| nodes | array | ❌ | Custom nodes (if null, fetch from DB) |
| edges | array | ❌ | Custom edges (if null, fetch from DB) |

**Response (Success):**
```json
{
  "ok": true,
  "valid": true,
  "errors": [],
  "warnings": [
    {
      "code": "B2_NO_WORK_CENTER",
      "severity": "info",
      "node_id": 456,
      "message": "Operation node 'STITCH_BODY' has no work center"
    }
  ],
  "rules_validated": 13,
  "validation_time_ms": 45
}
```

**Response (Validation Errors):**
```json
{
  "ok": true,
  "valid": false,
  "errors": [
    {
      "code": "Q1_QC_HAS_EDGE_CONDITION",
      "severity": "error",
      "node_id": 789,
      "edge_id": 101,
      "message": "QC node 'QC_BODY' must NOT use edge_condition",
      "auto_fix": {
        "action": "remove_edge_condition",
        "edge_id": 101
      }
    }
  ],
  "warnings": [],
  "rules_validated": 13
}
```

**Response (Error):**
```json
{
  "ok": false,
  "error": "Graph not found",
  "app_code": "LINTER_404_GRAPH"
}
```

### Action: `auto_fix_graph`

**Request:**
```json
{
  "action": "auto_fix_graph",
  "graph_id": 123,
  "fixes": [
    { "code": "S2_ORPHAN_NODE", "node_id": 456 },
    { "code": "Q1_QC_HAS_EDGE_CONDITION", "edge_id": 101 }
  ]
}
```

**Response:**
```json
{
  "ok": true,
  "fixes_applied": 2,
  "fixes_failed": 0,
  "details": [
    { "code": "S2_ORPHAN_NODE", "success": true, "action": "deleted_node" },
    { "code": "Q1_QC_HAS_EDGE_CONDITION", "success": true, "action": "removed_edge_condition" }
  ]
}
```

---

## 📋 Task Details

---

### 27.16.1 Integrate with GraphValidationEngine

**Duration:** 4 hours

**File:** `source/BGERP/Dag/GraphValidationEngine.php` (extend)

```php
<?php
declare(strict_types=1);

namespace BGERP\Dag;

class GraphValidationEngine
{
    private \mysqli $db;
    private array $rules = [];
    private array $errors = [];
    private array $warnings = [];
    private int $rulesValidated = 0;
    
    public function __construct(\mysqli $db)
    {
        $this->db = $db;
        $this->registerDefaultRules();
    }
    
    /**
     * Validate a graph
     * 
     * @param array $nodes
     * @param array $edges
     * @param array $options ['mode' => 'save'|'publish', 'strict' => bool]
     * @return array ['valid' => bool, 'errors' => [], 'warnings' => [], 'rules_validated' => int]
     */
    public function validate(array $nodes, array $edges, array $options = []): array
    {
        $this->errors = [];
        $this->warnings = [];
        $this->rulesValidated = 0;
        
        $mode = $options['mode'] ?? 'save';
        $strict = $options['strict'] ?? ($mode === 'publish');
        
        // Build helper maps
        $nodeMap = $this->buildNodeMap($nodes);
        $edgeMap = $this->buildEdgeMap($edges);
        
        // Run all registered rules
        foreach ($this->rules as $rule) {
            // Check if rule applies to current mode
            if (!$this->ruleApplies($rule, $mode)) {
                continue;
            }
            
            $result = $this->executeRule($rule, $nodes, $edges, $nodeMap, $edgeMap);
            $this->rulesValidated++;
            
            foreach ($result['errors'] ?? [] as $error) {
                $this->errors[] = $error;
            }
            foreach ($result['warnings'] ?? [] as $warning) {
                $this->warnings[] = $warning;
            }
        }
        
        // Publish-specific checks
        if ($mode === 'publish') {
            $publishResult = $this->validateForPublish($nodes, $edges, $nodeMap, $edgeMap);
            $this->errors = array_merge($this->errors, $publishResult['errors']);
            $this->warnings = array_merge($this->warnings, $publishResult['warnings']);
            $this->rulesValidated += $publishResult['rules_validated'];
        }
        
        return [
            'valid' => empty($this->errors),
            'errors' => $this->errors,
            'warnings' => $this->warnings,
            'rules_validated' => $this->rulesValidated
        ];
    }
    
    /**
     * Register default linter rules
     * 
     * Rule Categories:
     * - S: Structural (4 rules) - Basic graph structure
     * - C: Component (3 rules) - Anchor/component validation
     * - Q: QC (2 rules) - QC node philosophy
     * - B: Best Practice (4 rules) - Suggestions only
     * 
     * Total: 13 rules
     */
    private function registerDefaultRules(): void
    {
        // Structural rules (S1-S4)
        $this->registerRule('S1_START_END', [$this, 'validateStartEnd'], 'always');
        $this->registerRule('S2_ORPHAN_NODES', [$this, 'validateNoOrphans'], 'always');
        $this->registerRule('S3_REACHABILITY', [$this, 'validateReachability'], 'always');
        $this->registerRule('S4_MERGE_EDGES', [$this, 'validateMergeEdges'], 'always');
        
        // Component rules (C1-C3)
        $this->registerRule('C1_ANCHOR_SLOT', [$this, 'validateAnchorSlot'], 'always');
        $this->registerRule('C2_UNIQUE_SLOTS', [$this, 'validateUniqueSlots'], 'always');
        $this->registerRule('C3_MAPPING', [$this, 'validateMappings'], 'publish');
        
        // QC rules (Q1-Q2) - CRITICAL for V2 philosophy
        $this->registerRule('Q1_NO_EDGE_CONDITION', [$this, 'validateQCNoEdgeCondition'], 'always');
        $this->registerRule('Q2_HAS_OPERATION', [$this, 'validateQCHasOperation'], 'always');
        
        // Best practices (B1-B4) - INFO only, never blocks
        $this->registerRule('B1_QC_BEFORE_MERGE', [$this, 'suggestQCBeforeMerge'], 'always');
        $this->registerRule('B2_WORK_CENTER', [$this, 'suggestWorkCenter'], 'always');
        $this->registerRule('B3_EDGE_LABELS', [$this, 'suggestEdgeLabels'], 'always');
        $this->registerRule('B4_NODE_NAMES', [$this, 'suggestNodeNames'], 'always');
    }
    
    private function registerRule(string $code, callable $handler, string $mode): void
    {
        $this->rules[$code] = [
            'code' => $code,
            'handler' => $handler,
            'mode' => $mode
        ];
    }
}
```

**Deliverables:**
- [ ] Rule registration system
- [ ] Mode-based filtering (save/publish)
- [ ] Error/warning aggregation
- [ ] Result structure standardized

---

### 27.16.2-5 Structural Rules (S1-S4)

**Duration:** 10 hours

**Rule S1: Start/End Validation**

```php
private function validateStartEnd(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $errors = [];
    
    $startNodes = array_filter($nodes, fn($n) => $n['node_type'] === 'start');
    $endNodes = array_filter($nodes, fn($n) => $n['node_type'] === 'end');
    
    if (count($startNodes) !== 1) {
        $errors[] = [
            'code' => 'S1_START_COUNT',
            'severity' => 'error',
            'message' => sprintf('Graph must have exactly 1 START node (found %d)', count($startNodes))
        ];
    }
    
    if (count($endNodes) < 1) {
        $errors[] = [
            'code' => 'S1_END_MISSING',
            'severity' => 'error',
            'message' => 'Graph must have at least 1 END node'
        ];
    }
    
    return ['errors' => $errors, 'warnings' => []];
}
```

**Rule S2: Orphan Detection**

```php
private function validateNoOrphans(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $errors = [];
    $connectedNodes = [];
    
    // Mark all nodes connected by edges
    foreach ($edges as $edge) {
        $connectedNodes[$edge['source_node_id']] = true;
        $connectedNodes[$edge['target_node_id']] = true;
    }
    
    // Check for orphans (except single-node graphs)
    if (count($nodes) > 1) {
        foreach ($nodes as $node) {
            if (!isset($connectedNodes[$node['id_node']])) {
                $errors[] = [
                    'code' => 'S2_ORPHAN_NODE',
                    'severity' => 'error',
                    'node_id' => $node['id_node'],
                    'message' => "Node '{$node['node_code']}' is not connected to any other node"
                ];
            }
        }
    }
    
    return ['errors' => $errors, 'warnings' => []];
}
```

**Rule S3: Reachability (Forward + Reverse)**

```php
/**
 * Check all nodes are reachable FROM start AND can reach TO end
 */
private function validateReachability(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $errors = [];
    
    // Find start and end nodes
    $startNode = null;
    $endNodes = [];
    foreach ($nodes as $node) {
        if ($node['node_type'] === 'start') {
            $startNode = $node;
        }
        if ($node['node_type'] === 'end') {
            $endNodes[] = $node;
        }
    }
    
    if (!$startNode) {
        return ['errors' => [], 'warnings' => []]; // S1 will catch this
    }
    
    // Forward BFS: Can reach from START?
    $forwardReachable = $this->bfsForward($startNode['id_node'], $edgeMap);
    
    // Check all nodes reachable from START
    foreach ($nodes as $node) {
        if (!isset($forwardReachable[$node['id_node']])) {
            $errors[] = [
                'code' => 'S3_UNREACHABLE_FROM_START',
                'severity' => 'error',
                'node_id' => $node['id_node'],
                'message' => translate('linter.s3_unreachable_from_start',
                    "Node '%s' is not reachable from START", $node['node_code'])
            ];
        }
    }
    
    // Reverse BFS: Can reach END?
    if (!empty($endNodes)) {
        $reverseReachable = [];
        foreach ($endNodes as $endNode) {
            $reverseReachable += $this->bfsReverse($endNode['id_node'], $edgeMap);
        }
        
        // Check all nodes can reach END (except END itself)
        foreach ($nodes as $node) {
            if ($node['node_type'] === 'end') continue;
            if (!isset($reverseReachable[$node['id_node']])) {
                $errors[] = [
                    'code' => 'S3_CANNOT_REACH_END',
                    'severity' => 'error',
                    'node_id' => $node['id_node'],
                    'message' => translate('linter.s3_cannot_reach_end',
                        "Node '%s' cannot reach any END node", $node['node_code'])
                ];
            }
        }
    }
    
    return ['errors' => $errors, 'warnings' => []];
}

private function bfsForward(int $startId, array $edgeMap): array
{
    $reachable = [];
    $queue = [$startId];
    
    while (!empty($queue)) {
        $currentId = array_shift($queue);
        if (isset($reachable[$currentId])) continue;
        $reachable[$currentId] = true;
        
        foreach ($edgeMap['outgoing'][$currentId] ?? [] as $edge) {
            $queue[] = $edge['target_node_id'];
        }
    }
    
    return $reachable;
}

private function bfsReverse(int $endId, array $edgeMap): array
{
    $reachable = [];
    $queue = [$endId];
    
    while (!empty($queue)) {
        $currentId = array_shift($queue);
        if (isset($reachable[$currentId])) continue;
        $reachable[$currentId] = true;
        
        foreach ($edgeMap['incoming'][$currentId] ?? [] as $edge) {
            $queue[] = $edge['source_node_id'];
        }
    }
    
    return $reachable;
}
```

**Rule S4: Merge Edges**

```php
private function validateMergeEdges(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $errors = [];
    
    foreach ($nodes as $node) {
        if (!($node['is_merge_node'] ?? false)) continue;
        
        $incoming = $edgeMap['incoming'][$node['id_node']] ?? [];
        
        if (count($incoming) < 2) {
            $errors[] = [
                'code' => 'S4_MERGE_INSUFFICIENT_EDGES',
                'severity' => 'error',
                'node_id' => $node['id_node'],
                'message' => "Merge node '{$node['node_code']}' must have at least 2 incoming edges (has " . count($incoming) . ")"
            ];
        }
    }
    
    return ['errors' => $errors, 'warnings' => []];
}
```

**Deliverables:**
- [ ] S1: Start/End validation
- [ ] S2: Orphan detection
- [ ] S3: Reachability from START
- [ ] S4: Merge node edges

---

### 27.16.6-7 Component Rules (C1-C2)

**Duration:** 7 hours

**Rule C1: Anchor Slot Required**

```php
private function validateAnchorSlot(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $errors = [];
    $warnings = [];
    
    foreach ($nodes as $node) {
        if ($node['node_type'] !== 'component') continue;
        
        $slot = $node['anchor_slot'] ?? null;
        
        if (empty($slot)) {
            $errors[] = [
                'code' => 'C1_ANCHOR_SLOT_REQUIRED',
                'severity' => 'error',
                'node_id' => $node['id_node'],
                'message' => "Component node '{$node['node_code']}' must have anchor_slot"
            ];
        } elseif (!preg_match('/^[A-Z][A-Z0-9_]*$/', $slot)) {
            $warnings[] = [
                'code' => 'C1_ANCHOR_SLOT_FORMAT',
                'severity' => 'warning',
                'node_id' => $node['id_node'],
                'message' => "Anchor slot '{$slot}' should use UPPER_SNAKE_CASE format"
            ];
        }
    }
    
    return ['errors' => $errors, 'warnings' => $warnings];
}
```

**Rule C2: Unique Anchor Slots**

```php
private function validateUniqueSlots(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $errors = [];
    $seen = [];
    
    foreach ($nodes as $node) {
        if ($node['node_type'] !== 'component') continue;
        
        $slot = $node['anchor_slot'] ?? null;
        if (!$slot) continue;
        
        if (isset($seen[$slot])) {
            $errors[] = [
                'code' => 'C2_DUPLICATE_ANCHOR_SLOT',
                'severity' => 'error',
                'node_id' => $node['id_node'],
                'message' => "Anchor slot '{$slot}' used by both '{$seen[$slot]}' and '{$node['node_code']}'"
            ];
        }
        $seen[$slot] = $node['node_code'];
    }
    
    return ['errors' => $errors, 'warnings' => []];
}
```

**Deliverables:**
- [ ] C1: anchor_slot required for component nodes
- [ ] C1: Format suggestion (UPPER_SNAKE_CASE)
- [ ] C2: No duplicate slots in same graph

---

### 27.16.8-9 QC Rules (Q1-Q2)

**Duration:** 5 hours

**Rule Q1: QC No edge_condition (ERROR!)**

```php
/**
 * QC nodes must NOT use edge_condition - STRICT CHECK
 * 
 * This is a CORE PRINCIPLE of QC Rework V2 philosophy:
 * - QC is human-judgment layer
 * - Graph defines permission (which nodes can be reworked)
 * - Behavior handles decision (operator selects target)
 * 
 * ⚠️ CTO AUDIT: Strict check - ANY non-empty edge_condition is ERROR
 */
private function validateQCNoEdgeCondition(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $errors = [];
    
    // Find QC nodes
    $qcNodeIds = [];
    foreach ($nodes as $node) {
        $behaviorCode = strtoupper($node['behavior_code'] ?? '');
        $nodeType = $node['node_type'] ?? '';
        
        if (str_starts_with($behaviorCode, 'QC_') || $nodeType === 'qc') {
            $qcNodeIds[$node['id_node']] = $node['node_code'];
        }
    }
    
    // Check edges from QC nodes - STRICT: no edge_condition allowed
    foreach ($edges as $edge) {
        if (!isset($qcNodeIds[$edge['source_node_id']])) continue;
        
        $condition = $edge['edge_condition'] ?? null;
        
        // Strict check: ANY non-empty, non-null condition is forbidden
        $hasCondition = !empty($condition) && 
                        $condition !== 'null' && 
                        $condition !== '{}' && 
                        $condition !== '[]' &&
                        $condition !== 'default';
        
        if ($hasCondition) {
                $errors[] = [
                    'code' => 'Q1_QC_HAS_EDGE_CONDITION',
                    'severity' => 'error',
                'node_id' => $edge['source_node_id'],
                    'edge_id' => $edge['id_edge'] ?? null,
                'message' => translate('linter.q1_qc_edge_condition',
                    "QC node '%s' must NOT use edge_condition. Use QC Behavior V2 for human-judgment routing.",
                    $qcNodeIds[$edge['source_node_id']]),
                'auto_fix' => [
                    'action' => 'remove_edge_condition',
                    'edge_id' => $edge['id_edge'] ?? null
                ]
            ];
        }
    }
    
    return ['errors' => $errors, 'warnings' => []];
}
```

**Rule Q2: QC Has Upstream Operation**

```php
private function validateQCHasOperation(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $warnings = [];
    
    foreach ($nodes as $node) {
        $behaviorCode = strtoupper($node['behavior_code'] ?? '');
        if (!str_starts_with($behaviorCode, 'QC_') && $node['node_type'] !== 'qc') {
            continue;
        }
        
        // Check if there's at least one operation upstream
        $hasOperation = $this->hasUpstreamOperation($node['id_node'], $nodeMap, $edgeMap);
        
        if (!$hasOperation) {
            $warnings[] = [
                'code' => 'Q2_QC_NO_UPSTREAM_OPERATION',
                'severity' => 'warning',
                'node_id' => $node['id_node'],
                'message' => "QC node '{$node['node_code']}' has no upstream operation nodes. What is being inspected?"
            ];
        }
    }
    
    return ['errors' => [], 'warnings' => $warnings];
}

private function hasUpstreamOperation(int $nodeId, array $nodeMap, array $edgeMap): bool
{
    $visited = [];
    $queue = [$nodeId];
    
    while (!empty($queue)) {
        $currentId = array_shift($queue);
        if (isset($visited[$currentId])) continue;
        $visited[$currentId] = true;
        
        $node = $nodeMap[$currentId] ?? null;
        if (!$node) continue;
        
        if ($node['node_type'] === 'operation') {
            return true;
        }
        
        // Add upstream nodes
        foreach ($edgeMap['incoming'][$currentId] ?? [] as $edge) {
            $queue[] = $edge['source_node_id'];
        }
    }
    
    return false;
}
```

**Deliverables:**
- [ ] Q1: QC with edge_condition = ERROR
- [ ] Q2: QC without upstream operation = WARNING

---

### 27.16.10 Rule C3: Mapping Validation (Publish)

**Duration:** 3 hours

```php
/**
 * Validate all anchor slots are mapped to component_codes
 * Only runs on publish
 */
private function validateMappings(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $errors = [];
    
    // Get graph ID (from first node)
    $graphId = $nodes[0]['id_graph'] ?? null;
    if (!$graphId) {
        return ['errors' => [], 'warnings' => []];
    }
    
    // Get all anchor slots in graph
    $slots = [];
    foreach ($nodes as $node) {
        if ($node['node_type'] === 'component' && !empty($node['anchor_slot'])) {
            $slots[] = $node['anchor_slot'];
        }
    }
    
    if (empty($slots)) {
        return ['errors' => [], 'warnings' => []];
    }
    
    // Get mappings from database
    $mappingService = new \BGERP\Service\ComponentMappingService($this->db);
    $mappings = $mappingService->getMappingsForGraph($graphId);
    $mappedSlots = array_column($mappings, 'anchor_slot');
    
    // Check all slots are mapped
    foreach ($slots as $slot) {
        if (!in_array($slot, $mappedSlots)) {
            $errors[] = [
                'code' => 'C3_UNMAPPED_SLOT',
                'severity' => 'error',
                'message' => translate('linter.c3_unmapped_slot',
                    "Anchor slot '%s' has no component_code mapping. Configure in Product Settings before publishing.", $slot)
            ];
        }
    }
    
    // Check mapped codes exist in catalog
    // ⚠️ CTO AUDIT FIX: Use ComponentTypeService (Layer 1), not ComponentCatalogService
    $typeService = new \BGERP\Service\ComponentTypeService($this->db);
    foreach ($mappings as $mapping) {
        $componentCode = $mapping['component_code'] ?? '';
        if (!$typeService->isValidCode($componentCode)) {
            $errors[] = [
                'code' => 'C3_INVALID_COMPONENT_CODE',
                'severity' => 'error',
                'message' => translate('linter.c3_invalid_code',
                    "Component code '%s' for slot '%s' not found in component_type_catalog",
                    $componentCode, $mapping['anchor_slot'])
            ];
        }
    }
    
    return ['errors' => $errors, 'warnings' => []];
}
```

**Deliverables:**
- [ ] C3: Unmapped slots = ERROR (publish only)
- [ ] C3: Invalid component codes = ERROR

---

### 27.16.11 Best Practice Rules (B1-B4)

**Duration:** 4 hours

```php
// B1: Suggest QC before merge
private function suggestQCBeforeMerge(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $warnings = [];
    
    foreach ($nodes as $node) {
        if (!($node['is_merge_node'] ?? false)) continue;
        
        // Check each incoming path for QC
        foreach ($edgeMap['incoming'][$node['id_node']] ?? [] as $edge) {
            $sourceNode = $nodeMap[$edge['source_node_id']] ?? null;
            if (!$sourceNode) continue;
            
            $hasQC = $this->hasQCInPath($edge['source_node_id'], $nodeMap, $edgeMap, 3);
            
            if (!$hasQC) {
                $warnings[] = [
                    'code' => 'B1_NO_QC_BEFORE_MERGE',
                    'severity' => 'info',
                    'node_id' => $node['id_node'],
                    'message' => "Consider adding QC node before merge in path from '{$sourceNode['node_code']}'"
                ];
            }
        }
    }
    
    return ['errors' => [], 'warnings' => $warnings];
}

// B2: Operation should have work center
private function suggestWorkCenter(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $warnings = [];
    
    foreach ($nodes as $node) {
        if ($node['node_type'] !== 'operation') continue;
        if (!empty($node['id_work_center'])) continue;
        
        $warnings[] = [
            'code' => 'B2_NO_WORK_CENTER',
            'severity' => 'info',
            'node_id' => $node['id_node'],
            'message' => "Operation node '{$node['node_code']}' has no work center assigned"
        ];
    }
    
    return ['errors' => [], 'warnings' => $warnings];
}

// B3: Conditional edges should have labels
private function suggestEdgeLabels(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    $warnings = [];
    
    foreach ($edges as $edge) {
        if (($edge['edge_type'] ?? '') !== 'conditional') continue;
        if (!empty($edge['label'])) continue;
        
        $warnings[] = [
            'code' => 'B3_NO_EDGE_LABEL',
            'severity' => 'info',
            'edge_id' => $edge['id_edge'] ?? null,
            'message' => "Conditional edge should have a label for clarity"
        ];
    }
    
    return ['errors' => [], 'warnings' => $warnings];
}
```

**Deliverables:**
- [ ] B1: QC before merge suggestion
- [ ] B2: Work center suggestion
- [ ] B3: Edge label suggestion
- [ ] B4: Node name suggestion

---

### 27.16.12-13 Graph Designer UI + Auto-fix

**Duration:** 10 hours

**UI Features:**

```javascript
// In graph_designer.js
class LinterPanel {
    constructor(graphDesigner) {
        this.graphDesigner = graphDesigner;
        this.results = { errors: [], warnings: [] };
    }
    
    async validate() {
        const response = await fetch('/source/dag_routing_api.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'validate_graph',
                nodes: this.graphDesigner.getNodes(),
                edges: this.graphDesigner.getEdges(),
                mode: 'save'
            })
        });
        
        this.results = await response.json();
        this.render();
    }
    
    render() {
        const panel = document.getElementById('linter-panel');
        
        let html = '<div class="linter-results">';
        
        // Errors
        if (this.results.errors.length > 0) {
            html += '<div class="linter-section errors">';
            html += `<h6 class="text-danger">❌ ${t('linter.errors', 'Errors')} (${this.results.errors.length})</h6>`;
            this.results.errors.forEach(err => {
                html += this.renderItem(err, 'danger');
            });
            html += '</div>';
        }
        
        // Warnings
        if (this.results.warnings.length > 0) {
            html += '<div class="linter-section warnings">';
            html += `<h6 class="text-warning">⚠️ ${t('linter.warnings', 'Warnings')} (${this.results.warnings.length})</h6>`;
            this.results.warnings.forEach(warn => {
                html += this.renderItem(warn, 'warning');
            });
            html += '</div>';
        }
        
        // Success
        if (this.results.valid) {
            html += `<div class="alert alert-success">✅ ${t('linter.valid', 'Graph is valid')}</div>`;
        }
        
        html += '</div>';
        panel.innerHTML = html;
    }
    
    renderItem(item, type) {
        const hasAutoFix = !!item.auto_fix;
        return `
            <div class="linter-item alert alert-${type} py-2">
                <strong>${item.code}</strong>: ${item.message}
                ${hasAutoFix ? `<button class="btn btn-sm btn-outline-${type} ms-2" onclick="linter.autoFix('${item.code}', ${item.node_id || 'null'})">${t('linter.fix', 'Fix')}</button>` : ''}
            </div>
        `;
    }
    
    autoFix(code, nodeId) {
        // Auto-fix suggestions
        switch (code) {
            case 'S2_ORPHAN_NODE':
                // Offer to delete orphan
                this.graphDesigner.deleteNode(nodeId);
                break;
            case 'C1_ANCHOR_SLOT_FORMAT':
                // Convert to UPPER_SNAKE_CASE
                const node = this.graphDesigner.getNode(nodeId);
                node.anchor_slot = node.anchor_slot.toUpperCase().replace(/[^A-Z0-9]/g, '_');
                this.graphDesigner.updateNode(node);
                break;
            // ... more auto-fixes
        }
        
        this.validate();
    }
}
```

**Deliverables:**
- [ ] Linter panel in Graph Designer
- [ ] Errors shown in red
- [ ] Warnings shown in yellow
- [ ] Click to focus on node
- [ ] Auto-fix button where applicable
- [ ] Re-validate on fix

---

### 27.16.14 Tests

**Duration:** 6 hours

```php
class GraphLinterTest extends TestCase
{
    // S rules
    public function testS1RejectsMultipleStarts(): void;
    public function testS1RejectsMissingEnd(): void;
    public function testS2DetectsOrphanNodes(): void;
    public function testS3DetectsUnreachableNodes(): void;
    public function testS4RejectsMergeWithOneEdge(): void;
    
    // C rules
    public function testC1RequiresAnchorSlot(): void;
    public function testC1WarnsOnBadFormat(): void;
    public function testC2RejectsDuplicateSlots(): void;
    public function testC3RejectsUnmappedSlotsOnPublish(): void;
    public function testC3SkipsOnSaveMode(): void;
    
    // Q rules (CRITICAL)
    public function testQ1ErrorsOnQCWithEdgeCondition(): void;
    public function testQ1AllowsQCWithDefaultEdge(): void;
    public function testQ2WarnsQCWithoutOperation(): void;
    
    // B rules
    public function testB1SuggestsQCBeforeMerge(): void;
    public function testB2SuggestsWorkCenter(): void;
    
    // Integration
    public function testValidGraphPasses(): void;
    public function testPublishBlockedByErrors(): void;
    public function testSaveAllowedWithWarnings(): void;
}
```

**Deliverables:**
- [ ] 20+ unit tests
- [ ] 5+ integration tests
- [ ] All tests passing

---

## 📝 Translation Keys Required

All linter messages MUST use `translate()` for i18n compliance.

### Structural Rules (S)

| Key | EN Default | TH |
|-----|------------|-----|
| `linter.s1_start_count` | Graph must have exactly 1 START node (found %d) | กราฟต้องมี START เพียง 1 จุด (พบ %d) |
| `linter.s1_end_missing` | Graph must have at least 1 END node | กราฟต้องมี END อย่างน้อย 1 จุด |
| `linter.s2_orphan_node` | Node '%s' is not connected to any other node | โหนด '%s' ไม่ได้เชื่อมต่อกับโหนดอื่น |
| `linter.s3_unreachable_from_start` | Node '%s' is not reachable from START | โหนด '%s' ไปไม่ถึงจาก START |
| `linter.s3_cannot_reach_end` | Node '%s' cannot reach any END node | โหนด '%s' ไปไม่ถึง END |
| `linter.s4_merge_insufficient` | Merge node '%s' must have at least 2 incoming edges | โหนดรวม '%s' ต้องมีขาเข้าอย่างน้อย 2 |

### Component Rules (C)

| Key | EN Default | TH |
|-----|------------|-----|
| `linter.c1_anchor_required` | Component node '%s' must have anchor_slot | โหนดชิ้นส่วน '%s' ต้องระบุ anchor_slot |
| `linter.c1_anchor_format` | Anchor slot '%s' should use UPPER_SNAKE_CASE | anchor_slot '%s' ควรใช้รูปแบบ UPPER_SNAKE_CASE |
| `linter.c2_duplicate_slot` | Anchor slot '%s' used by both '%s' and '%s' | anchor_slot '%s' ถูกใช้ทั้ง '%s' และ '%s' |
| `linter.c3_unmapped_slot` | Anchor slot '%s' has no mapping. Configure before publishing | anchor_slot '%s' ยังไม่ได้ตั้งค่า ต้องตั้งค่าก่อน publish |
| `linter.c3_invalid_code` | Component code '%s' for slot '%s' not found | รหัสชิ้นส่วน '%s' สำหรับ '%s' ไม่พบ |

### QC Rules (Q)

| Key | EN Default | TH |
|-----|------------|-----|
| `linter.q1_qc_edge_condition` | QC node '%s' must NOT use edge_condition | โหนด QC '%s' ห้ามใช้ edge_condition |
| `linter.q2_no_upstream` | QC node '%s' has no upstream operation | โหนด QC '%s' ไม่มีขั้นตอนก่อนหน้า |

### Best Practices (B)

| Key | EN Default | TH |
|-----|------------|-----|
| `linter.b1_no_qc_before_merge` | Consider adding QC before merge from '%s' | ควรเพิ่ม QC ก่อนจุดรวมจาก '%s' |
| `linter.b2_no_work_center` | Operation '%s' has no work center | ขั้นตอน '%s' ยังไม่ระบุ Work Center |
| `linter.b3_no_edge_label` | Conditional edge should have a label | เส้นเงื่อนไขควรมี label |
| `linter.b4_node_unnamed` | Node '%s' has no display name | โหนด '%s' ยังไม่มีชื่อแสดง |

### UI Messages

| Key | EN Default | TH |
|-----|------------|-----|
| `linter.title` | Graph Linter | ตรวจสอบกราฟ |
| `linter.errors` | Errors | ข้อผิดพลาด |
| `linter.warnings` | Warnings | คำเตือน |
| `linter.info` | Suggestions | คำแนะนำ |
| `linter.valid` | Graph is valid | กราฟถูกต้อง |
| `linter.fix` | Fix | แก้ไข |
| `linter.fix_all` | Fix All | แก้ไขทั้งหมด |
| `linter.validating` | Validating... | กำลังตรวจสอบ... |
| `linter.rules_checked` | %d rules checked | ตรวจสอบ %d กฎ |

---

## ✅ Definition of Done

- [ ] All S rules implemented (4 rules)
- [ ] All C rules implemented (3 rules)
- [ ] All Q rules implemented (2 rules)
- [ ] All B rules implemented (4 rules)
- [ ] Total: 13 rules
- [ ] API endpoints: `validate_graph`, `auto_fix_graph`
- [ ] Graph Designer shows linter panel
- [ ] Errors block save/publish
- [ ] Warnings shown but don't block
- [ ] Auto-fix for 3+ common issues
- [ ] 25+ tests passing
- [ ] All translation keys added to `lang/th.php` and `lang/en.php`
- [ ] Performance: < 500ms for typical graphs (< 200 nodes)

---

## 🔗 Dependencies

**Requires:**
- 27.13 Component Node (for anchor_slot validation)
- 27.15 QC Rework V2 (for Q1 philosophy alignment)
- `ComponentTypeService` (for C3 validation)
- `ComponentMappingService` (for C3 validation)

**Enables:**
- Safe graph publishing
- Consistent graph quality
- Prevention of runtime errors

---

## 📊 Metrics (Expected)

| Metric | Value |
|--------|-------|
| Rules implemented | 13 |
| API endpoints | 2 |
| Service methods | 15+ |
| Translation keys | 30+ |
| Unit tests | 20+ |
| Integration tests | 5+ |
| Estimated hours | 44h |

---

## 📚 Related Documents

- [GRAPH_LINTER_RULES.md](../01-concepts/GRAPH_LINTER_RULES.md)
- [QC_REWORK_PHILOSOPHY_V2.md](../01-concepts/QC_REWORK_PHILOSOPHY_V2.md)
- [MASTER_IMPLEMENTATION_ROADMAP.md](./MASTER_IMPLEMENTATION_ROADMAP.md)
- [task27.15_QC_REWORK_V2_PLAN.md](./task27.15_QC_REWORK_V2_PLAN.md) - Q1 alignment

