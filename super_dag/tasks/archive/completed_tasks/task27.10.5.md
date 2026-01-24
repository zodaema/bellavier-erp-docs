# Task 27.10.5: Fix Routing Priority for Default/Else Edges

## Status: 🔴 PENDING

## Problem

### 1. Normal Edge Always Matches
```php
// DAGRoutingService.php line 886-890
if ($edge['edge_type'] === 'normal' || empty($edge['edge_condition'])) {
    $matchingEdges[] = $edge;  // ❌ Always added to matches!
    continue;
}
```

**Impact:** If a node has both Normal and Conditional edges, Normal edge will always match, causing "Multiple edges match" error.

### 2. Default/Else Edge Always Matches
```php
// ConditionEvaluator.php line 49
if ($type === 'default') {
    return true;  // ❌ Always returns true!
}
```

**Impact:** If a node has a specific conditional edge (e.g., `qc_result.status == 'pass'`) AND a default edge, both will match when condition is true.

### 3. No Priority Order
Current logic evaluates ALL edges and expects exactly 1 match. No priority handling.

---

## Test Cases

### Case 1: QC Node with Pass + Else
```
QC Node:
├── Edge A: conditional { qc_result.status == 'pass' } → NEXT
└── Edge B: conditional { type: 'default' } → REWORK
```

| QC Result | Expected | Current |
|-----------|----------|---------|
| Pass | Edge A | ❌ A + B match → ERROR |
| Fail | Edge B | ✅ B only (works by accident) |

### Case 2: QC Node with Pass + Else + Normal
```
QC Node:
├── Edge A: conditional { qc_result.status == 'pass' } → NEXT
├── Edge B: conditional { type: 'default' } → REWORK
└── Edge C: normal → OTHER
```

| QC Result | Expected | Current |
|-----------|----------|---------|
| Pass | Edge A | ❌ A + B + C match → ERROR |
| Fail | Edge B | ❌ B + C match → ERROR |

### Case 3: Decision Node with Multiple Conditions
```
Decision Node:
├── Edge A: conditional { qty > 100 } → BULK
├── Edge B: conditional { qty > 50 } → MEDIUM
└── Edge C: conditional { type: 'default' } → SMALL
```

| Qty | Expected | Current |
|-----|----------|---------|
| 150 | Edge A | ❌ A + B + C match → ERROR |
| 75 | Edge B | ❌ B + C match → ERROR |
| 25 | Edge C | ✅ Works |

---

## Solution

### Phase 1: Implement Priority-Based Routing

```php
private function selectNextNode(array $edges, array $token, ?int $operatorId = null): array
{
    if (empty($edges)) {
        throw new \Exception('No outgoing edges available for routing');
    }
    
    // Build context for ConditionEvaluator
    $context = [
        'token' => $token,
        'job' => null,
        'node' => null
    ];
    
    // Phase 1: Separate edges by priority category
    $specificConditionalEdges = [];  // Specific conditions (evaluate first)
    $defaultConditionalEdges = [];   // type: 'default' (fallback)
    $normalEdges = [];               // edge_type: 'normal' (lowest priority)
    
    foreach ($edges as $edge) {
        if ($edge['edge_type'] === 'normal' || empty($edge['edge_condition'])) {
            $normalEdges[] = $edge;
        } elseif ($edge['edge_type'] === 'conditional') {
            $condition = JsonNormalizer::normalizeJsonField($edge, 'edge_condition', null);
            if ($condition && is_array($condition)) {
                if (($condition['type'] ?? '') === 'default') {
                    $defaultConditionalEdges[] = $edge;
                } else {
                    $specificConditionalEdges[] = $edge;
                }
            }
        }
    }
    
    // Phase 2: Evaluate in priority order
    $matchingEdges = [];
    
    // Priority 1: Specific conditional edges
    foreach ($specificConditionalEdges as $edge) {
        $condition = JsonNormalizer::normalizeJsonField($edge, 'edge_condition', null);
        
        // Lazy load context if needed
        $this->loadContextIfNeeded($condition, $context, $token);
        
        if (ConditionEvaluator::evaluate($condition, $context)) {
            $matchingEdges[] = $edge;
        }
    }
    
    // Priority 2: If no specific match, use default conditional edge
    if (empty($matchingEdges) && !empty($defaultConditionalEdges)) {
        $matchingEdges[] = $defaultConditionalEdges[0];  // First default edge
    }
    
    // Priority 3: If still no match, use normal edge (catch-all)
    if (empty($matchingEdges) && !empty($normalEdges)) {
        $matchingEdges[] = $normalEdges[0];  // First normal edge
    }
    
    // Validation
    if (empty($matchingEdges)) {
        throw new \Exception('No matching edge found for routing - token is unroutable');
    }
    
    // Multiple specific conditions match = ambiguous (error)
    if (count($matchingEdges) > 1) {
        throw new \Exception('Multiple specific conditions match - ambiguous routing');
    }
    
    return $matchingEdges[0];
}

private function loadContextIfNeeded(array $condition, array &$context, array $token): void
{
    $conditionType = $condition['type'] ?? '';
    $instanceId = $token['id_instance'] ?? null;
    $currentNodeId = $token['current_node_id'] ?? null;
    
    if ($conditionType === 'job_property' && $context['job'] === null && $instanceId) {
        $context['job'] = $this->fetchJobTicket($instanceId);
    }
    if ($conditionType === 'node_property' && $context['node'] === null && $currentNodeId) {
        $context['node'] = $this->fetchNode($currentNodeId);
    }
}
```

### Phase 2: Update QC Routing (`handleQCResult`, `handleQCFailWithPolicy`)

Apply same priority logic to QC-specific routing methods.

### Phase 3: Validator Enhancement

Add validation warning when:
- QC/Decision node has both Normal and Conditional edges
- Node has multiple `type: 'default'` edges

---

## Files to Modify

1. **`source/BGERP/Service/DAGRoutingService.php`**
   - `selectNextNode()` - Implement priority-based routing
   - `handleQCResult()` - Apply same priority logic
   - `handleQCFailWithPolicy()` - Apply same priority logic

2. **`source/BGERP/Dag/GraphValidationEngine.php`**
   - Add warning: "Node has both Normal and Conditional edges (ambiguous routing)"
   - Add warning: "Node has multiple default edges"

3. **`tests/Unit/RoutingPriorityTest.php`** (NEW)
   - Test priority order
   - Test edge case combinations

---

## Priority Order Summary

| Priority | Edge Type | Condition | Behavior |
|----------|-----------|-----------|----------|
| 1 (Highest) | conditional | Specific condition | Evaluate first, first match wins |
| 2 | conditional | `type: 'default'` | Fallback if no specific match |
| 3 (Lowest) | normal | None | Catch-all if no conditional match |

---

## Acceptance Criteria

- [ ] QC Pass with pass+else edges → routes to pass edge only
- [ ] QC Fail with pass+else edges → routes to else edge
- [ ] Decision node with multiple conditions → first match wins
- [ ] Normal edge is lowest priority (catch-all)
- [ ] Multiple default edges → warning in validator
- [ ] Mixed normal+conditional → warning in validator
- [ ] Unit tests for all priority scenarios

---

## Related Tasks

- Task 27.10.1: Fix Rework Edge Pattern (COMPLETE)
- Task 27.10.2: Unify Validation Engine (PENDING)
- Task 27.10.4: Validate Edge Condition Structure (PENDING)

---

## Estimated Effort

- Development: 2-3 hours
- Testing: 1-2 hours
- Total: 3-5 hours

