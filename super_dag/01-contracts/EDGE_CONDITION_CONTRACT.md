# Edge Condition Contract
**Version:** 1.0  
**Date:** 2025-11-14  
**Status:** LOCKED (Runtime Determinism)

---

## Executive Summary

Edge conditions are evaluated using `ConditionEvaluator::evaluate()` at **5 call sites** across normal routing, QC pass, and QC fail flows. Priority rules are **deterministic** with specific tie-breakers. `guard_json` field is **NOT USED** in runtime (legacy field, only in Graph Designer save).

**Key Finding:** All condition evaluation uses unified `ConditionEvaluator` class. No fallback to legacy string matching.

---

## Call Sites Map

### 1. Normal Routing (selectNextNode)

**File:** `source/BGERP/Service/DAGRoutingService.php`  
**Function:** `selectNextNode()`  
**Lines:** 939-1036  
**Caller Chain:**
```
routeToken() [61]
  └─ selectNextNode() [92, 145]
      └─ ConditionEvaluator::evaluate() [1006]
```

**Evidence:**
- **Entry:** `DAGRoutingService::routeToken()` line 61
- **Called from:** `routeToken()` when `count($edges) > 1` (line 143-147)
- **Condition input:** `context = ['token' => $token, 'job' => null, 'node' => null]` (line 950-954)
- **Priority:** Specific → Default → Normal (line 994-1021)
- **Ambiguous:** Multiple specific matches → Exception thrown (line 1031-1033)
- **Edge order:** Uses `getOutgoingEdges()` with `ORDER BY priority DESC, id_edge ASC` (line 2714)

**Context:**
- Used when node has 2+ outgoing edges
- Evaluates all conditional edges before falling back to normal edges
- **Determinism:** Edges ordered by SQL `ORDER BY priority DESC, id_edge ASC` (line 2714) - NOT array order

### 2. QC Pass Routing (handleQCResult)

**File:** `source/BGERP/Service/DAGRoutingService.php`  
**Function:** `handleQCResult()` → QC pass branch  
**Lines:** 423-502  
**Caller Chain:**
```
dag_token_api.php:3119
  └─ DAGRoutingService::handleQCResult() [351]
      └─ ConditionEvaluator::evaluate() [462] (QC pass branch)
```

**Evidence:**
- **Entry:** `dag_token_api.php:3119` → `handleQCResult()`
- **Condition input:** `context = ['token' => $token, 'job' => $job, 'node' => $node]` (line 412-416)
- **QC result in context:** `token.metadata.qc_result` added to context (line 419-421)
- **Priority:** Specific conditional → Default conditional → Normal (sorted by `is_default DESC`) (line 432-480)
- **Ambiguous:** Multiple specific matches → Exception thrown (line 487-489)
- **Edge order:** Uses `getOutgoingEdges()` with `ORDER BY priority DESC, id_edge ASC` (line 2714)

**Context:**
- Evaluates pass conditions after QC result is written to token metadata
- Uses `qc_result.*` properties in condition evaluation
- Normal edges sorted by `is_default DESC` before selection (line 476-478)

### 3. QC Fail Routing (handleQCFailWithPolicy)

**File:** `source/BGERP/Service/DAGRoutingService.php`  
**Function:** `handleQCFailWithPolicy()`  
**Lines:** 522-701  
**Caller Chain:**
```
handleQCResult() [505]
  └─ handleQCFailWithPolicy() [522]
      └─ ConditionEvaluator::evaluate() [578] (specific fail edges only)
```

**Evidence:**
- **Entry:** `handleQCResult()` line 505 when `$qcPass === false`
- **Condition input:** `context = ['token' => $token, 'job' => $job, 'node' => $node]` (line 412-416, passed to function)
- **Priority:** Specific fail edges (evaluated) → Legacy rework edges (no evaluation) → Default edges (line 589-602)
- **Normal edges:** SKIPPED for fail paths (line 555-560), except `is_default=1` (line 557-559)
- **Ambiguous:** Multiple specific fail edges → Exception thrown (line 683-685)
- **Edge order:** Uses `getOutgoingEdges()` with `ORDER BY priority DESC, id_edge ASC` (line 2714)

**Context:**
- Evaluates fail conditions for specific conditional edges
- Legacy rework edges (`edge_type='rework'`) are matched WITHOUT evaluation (line 563-567)
- Normal edges are skipped unless `is_default=1` (line 555-560)

### 4. Decision Node (handleDecisionNode) - DEPRECATED BUT STILL CALLED

**File:** `source/BGERP/Service/DAGRoutingService.php`  
**Function:** `handleDecisionNode()`  
**Lines:** 2050-2142  
**Caller Chain:**
```
routeToNode() [160]
  └─ (if toNode['node_type'] === 'decision') [319-322]
      └─ handleDecisionNode() [2050]
          └─ evaluateCondition() [2112] (private method, NOT ConditionEvaluator)
```

**Evidence:**
- **Entry:** `routeToNode()` line 319-322 checks `node_type === 'decision'`
- **Status:** ⚠️ **DEPRECATED** but **STILL CALLED** in runtime (line 319-322)
- **Uses:** Private `evaluateCondition()` method (line 2112), NOT `ConditionEvaluator::evaluate()`
- **Condition source:** `edge.condition_rule` JSON field (line 2096), NOT `edge.edge_condition`
- **Evaluation order:** Uses `node_config.evaluation_order` (line 2072) or array order
- **Risk:** ⚠️ **ACTIVE LEGACY PATH** - Decision nodes still route tokens in production

**Status:** ⚠️ **DEPRECATED** - Decision node type is deprecated. Use conditional edges instead. **BUT STILL ACTIVE IN RUNTIME.**

### 5. Private evaluateCondition (Legacy)

**File:** `source/BGERP/Service/DAGRoutingService.php`  
**Function:** `evaluateCondition()` (private)  
**Lines:** 1070-1203  
**Status:** ⚠️ **LEGACY** - Only used by deprecated `handleDecisionNode()`. All new code uses `ConditionEvaluator::evaluate()`.

---

## Priority Rules (Runtime Determinism)

### Normal Routing (selectNextNode)

**File:** `source/BGERP/Service/DAGRoutingService.php:939-1036`

**Priority Order:**
1. **Specific conditional edges** (`edge_type='conditional'` + `condition.type != 'default'`)
   - Evaluate in order (first match wins)
   - If multiple match → **ERROR: ambiguous routing**
2. **Default conditional edges** (`edge_type='conditional'` + `condition.type = 'default'`)
   - Fallback if no specific match
   - First default edge wins (should only be one)
3. **Normal edges** (`edge_type='normal'` OR no `edge_condition`)
   - Catch-all, lowest priority
   - First normal edge wins

**Tie-Breaker:**
- Multiple specific conditions match → **Exception thrown** (line 1032)
- Multiple default/normal edges → First in array wins

**Edge Classification Logic:**
```php
// Line 969-989
foreach ($edges as $edge) {
    $edgeType = $edge['edge_type'] ?? 'normal';
    
    if ($edgeType === 'normal' || empty($edge['edge_condition'])) {
        $normalEdges[] = $edge;
    } elseif ($edgeType === 'conditional' || $edgeType === 'rework') {
        $condition = normalizeJsonField($edge, 'edge_condition', null);
        if ($condition && is_array($condition)) {
            $conditionType = $condition['type'] ?? '';
            if ($conditionType === 'default') {
                $defaultConditionalEdges[] = $edge;
            } else {
                $specificConditionalEdges[] = $edge;
            }
        } else {
            $normalEdges[] = $edge; // Invalid condition → treat as normal
        }
    }
}
```

### QC Pass Routing

**File:** `source/BGERP/Service/DAGRoutingService.php:423-502`

**Priority Order:**
1. **Specific conditional edges** (evaluate first)
2. **Default conditional edges** (fallback)
3. **Normal edges** (sorted by `is_default DESC`, then first wins)

**Tie-Breaker:**
- Multiple specific conditions match → **Exception thrown** (line 488)
- Normal edges sorted by `is_default` field (DESC) before selection

### QC Fail Routing

**File:** `source/BGERP/Service/DAGRoutingService.php:522-701`

**Priority Order:**
1. **Specific fail condition edges** (`edge_type='conditional'` + condition evaluates to true)
2. **Legacy rework edges** (`edge_type='rework'` - no evaluation needed)
3. **Default conditional edges** (`condition.type = 'default'` OR `is_default=1` on normal edge)

**Tie-Breaker:**
- Multiple specific fail edges match → **Exception thrown** (line 684)
- Legacy rework edges matched by `edge_type` only (no condition evaluation)

**Special Behavior:**
- Normal edges are **SKIPPED** for fail paths (line 555-560)
- Only normal edges with `is_default=1` are considered as fallback

---

## Condition Schema Inventory

### Supported Types

**File:** `source/BGERP/Dag/ConditionEvaluator.php:34-79`

#### 1. `qty_threshold`

**Required Fields:**
- `type`: `"qty_threshold"`
- `threshold`: `number`
- `operator`: `">" | ">=" | "<" | "<=" | "==" | "!="`

**Optional Fields:** None

**Example:**
```json
{
  "type": "qty_threshold",
  "threshold": 10,
  "operator": ">"
}
```

**Failure Modes:**
- Missing `threshold` → defaults to 0
- Missing `operator` → defaults to ">"
- Invalid operator → returns false

#### 2. `token_property`

**Required Fields:**
- `type`: `"token_property"`
- `property`: `string` (see supported properties below)
- `operator`: `">" | ">=" | "<" | "<=" | "==" | "!=" | "IN" | "NOT_IN" | "CONTAINS" | "STARTS_WITH"`
- `value`: `any`

**Supported Properties:**
- Direct fields: `qty`, `priority`, `serial_number`, `status`, `rework_count`
- Metadata fields: `metadata.*` (any key in metadata JSON)
- QC result fields: `qc_result.status`, `qc_result.defect_type`, `qc_result.severity`

**Example:**
```json
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "pass"
}
```

**Failure Modes:**
- Missing `property` → returns false
- Invalid property path → returns false
- Missing `operator` → defaults to "=="
- Missing `value` → returns false

#### 3. `job_property`

**Required Fields:**
- `type`: `"job_property"`
- `property`: `string` (see supported properties below)
- `operator`: `">" | ">=" | "<" | "<=" | "==" | "!=" | "IN" | "NOT_IN" | "CONTAINS" | "STARTS_WITH"`
- `value`: `any`

**Supported Properties:**
- `priority`, `type`, `target_qty`, `process_mode`, `order_channel`, `customer_tier`, `work_center_id`, `production_type`
- Supports `job.*` prefix (auto-stripped)

**Example:**
```json
{
  "type": "job_property",
  "property": "process_mode",
  "operator": "==",
  "value": "piece"
}
```

**Failure Modes:**
- Missing `job` in context → returns false
- Invalid property → returns false
- Missing `operator` → defaults to "=="

#### 4. `node_property`

**Required Fields:**
- `type`: `"node_property"`
- `property`: `string` (see supported properties below)
- `operator`: `">" | ">=" | "<" | "<=" | "==" | "!=" | "IN" | "NOT_IN" | "CONTAINS" | "STARTS_WITH"`
- `value`: `any`

**Supported Properties:**
- `node_type`, `node_code`, `behavior_code`, `category`, `work_center_code`
- Supports `node.*` prefix (auto-stripped)
- ⚠️ **NOT SUPPORTED:** `current_load` (requires WIP calculation, not implemented)

**Example:**
```json
{
  "type": "node_property",
  "property": "node_type",
  "operator": "==",
  "value": "operation"
}
```

**Failure Modes:**
- Missing `node` in context → returns false
- Invalid property → returns false
- Missing `operator` → defaults to "=="

#### 5. `expression`

**Required Fields:**
- `type`: `"expression"`
- `expression`: `string` (e.g., `"token.qty > 10 AND token.priority = 'high'"`)

**Optional Fields:** None

**Example:**
```json
{
  "type": "expression",
  "expression": "token.qty > 10 AND token.priority == 'high'"
}
```

**Supported Syntax:**
- Variables: `token.*`, `job.*`, `node.*`
- Operators: `>`, `>=`, `<`, `<=`, `==`, `!=`
- Logic: `AND`, `OR` (case-insensitive)

**Failure Modes:**
- Invalid expression syntax → returns false
- Missing variable → returns false
- Parse error → returns false

#### 6. `default`

**Required Fields:**
- `type`: `"default"`

**Behavior:**
- Always returns `true` (catch-all route)
- Evaluated last in priority order

**Example:**
```json
{
  "type": "default"
}
```

---

## Error Handling & Failure Modes

### Condition Evaluation Errors

**File:** `source/BGERP/Dag/ConditionEvaluator.php:34-79`

**Behavior:**
- Empty condition → returns `false`
- Invalid type → returns `false`
- Missing required fields → returns `false` (with defaults where applicable)
- **No exceptions thrown** - always returns boolean

### Context Missing

**Behavior:**
- Missing `token` → property access returns `null` → comparison fails
- Missing `job` → `job_property` conditions return `false`
- Missing `node` → `node_property` conditions return `false`

**Lazy Loading:**
- `selectNextNode()` loads job/node only if condition type requires it (line 1047-1057)

### Invalid Schema

**Behavior:**
- Invalid JSON in `edge_condition` → normalized to `null` → treated as normal edge
- Missing `type` field → defaults to `"simple"` → returns `false` (not a valid type)

### Ambiguous Routing

**Behavior:**
- Multiple specific conditions match → **Exception thrown** (no fallback)
- File: `DAGRoutingService.php:1032` (normal routing), `488` (QC pass), `684` (QC fail)

---

## guard_json Status

**Finding:** `guard_json` field is **NOT USED** in runtime evaluation.

**Evidence:**
- **Runtime reads:** `grep guard_json` in `source/BGERP/Service/DAGRoutingService.php` → **0 matches**
- **Runtime reads:** `grep guard_json` in `source/BGERP/Dag/ConditionEvaluator.php` → **0 matches**
- **Runtime reads:** All condition evaluation uses `edge_condition` JSON field (line 443, 571, 975, etc.)
- **Graph Designer only:** `source/dag/Graph/Service/GraphSaveEngine.php:513-517` - Reads `guard_json` only when **saving** graph (designer operation)
- **API responses:** `source/dag_routing_api.php` - Sets `guard_json => null` in responses (line 455, 605, 2855)
- **Helpers:** `source/dag/_helpers.php` - Sets to `null` when creating edges (line 311, 456, 594)

**Verdict:** Legacy field, kept for DB schema compatibility. **NOT READ in runtime routing logic. Not part of runtime contract.**

**Code Evidence:**
- `DAGRoutingService::selectNextNode()` reads `edge['edge_condition']` (line 975)
- `DAGRoutingService::handleQCResult()` reads `edge['edge_condition']` (line 443)
- `DAGRoutingService::handleQCFailWithPolicy()` reads `edge['edge_condition']` (line 571)
- **No code reads `edge['guard_json']` for evaluation**

---

## Runtime Determinism Checklist

### ✅ Deterministic Behaviors

1. **Priority order is fixed** - No runtime variation
2. **First match wins** - No random selection
3. **Tie-breakers are explicit** - Multiple matches → exception
4. **Fallback chain is deterministic** - Specific → Default → Normal
5. **Error handling is consistent** - Always returns boolean or throws exception

### ⚠️ Non-Deterministic Behaviors (Edge Cases)

1. **Edge order from SQL** - ✅ **DETERMINISTIC** - `getOutgoingEdges()` uses `ORDER BY priority DESC, id_edge ASC` (line 2714)
   - **Evidence:** `source/BGERP/Service/DAGRoutingService.php:2707-2719`
   - **Result:** Edges are ordered by priority (DESC) then id_edge (ASC) - deterministic
   - **Risk:** If multiple edges have same priority, order is deterministic (id_edge ASC)

2. **Array iteration order** - ✅ **DETERMINISTIC** - PHP preserves array order from SQL query
   - **Evidence:** `selectNextNode()` iterates `$specificConditionalEdges` array (line 995-1009)
   - **Order source:** SQL `ORDER BY priority DESC, id_edge ASC` (line 2714)
   - **Result:** First match wins, order is deterministic

3. **Lazy context loading** - ✅ **DETERMINISTIC** - Context loaded once per evaluation cycle
   - **Evidence:** `loadConditionContext()` called before evaluation (line 1003)
   - **Result:** Context is consistent for all evaluations in same cycle

### 🔒 Locked Contracts

1. **ConditionEvaluator is the single source of truth** - No fallback to string matching
2. **Priority rules are immutable** - Cannot change without breaking existing graphs
3. **Schema is versioned** - New condition types require code changes

---

## Legacy String Matching Verdict

**Finding:** No fallback to legacy string matching in condition evaluation.

**Evidence:**
- **ConditionEvaluator:** Uses structured condition types (line 34-79) - No string matching
- **Private evaluateCondition:** Uses switch/case on condition type (line 1076-1203) - No string matching
- **Comment in code:** Line 411 states "no string matching, no fallback"
- **String functions used:** Only `strpos()` for property path parsing (e.g., `qc_result.*`, `job.*`) - NOT for condition matching
- **Expression parser:** Uses `preg_match()` for expression parsing (line 315, 1302) - Structured parsing, not string matching

**Verdict:** ✅ **NO LEGACY STRING MATCHING** - All evaluation uses structured condition types.

## Observed Legacy Reliance (DB Evidence)

**Source:** `docs/super_dag/00-audit/LEGACY_RELIANCE_STATS_20251225.md`  
**Date:** 2025-12-25  
**Tenant:** maison_atelier

### Decision Nodes Usage

| Metric | Count | Status |
|--------|-------|--------|
| Decision nodes | 0 | ✅ No legacy usage |
| Active tokens on decision nodes | 0 | ✅ No active usage |

**Go/No-Go Criteria:**
- **Eligible to deprecate:** `decision_nodes == 0 AND active_tokens_on_decision == 0`
- **Status:** ✅ **ELIGIBLE** - Can remove runtime support (keep for backward compatibility)

**Note:** Decision nodes are deprecated but still called in runtime (line 319-322). With 0 usage, can safely remove support in future phase.

---

## Forbidden Patterns

### ❌ DO NOT:

1. **Use guard_json for runtime evaluation** - Use `edge_condition` only
2. **Create multiple specific conditions that can match simultaneously** - Will cause ambiguous routing error
3. **Rely on array order for tie-breaking** - ✅ **NOT AN ISSUE** - Edges ordered by SQL `ORDER BY priority DESC, id_edge ASC` (line 2714)
4. **Use `current_load` in node_property** - Not implemented, always returns false
5. **Mix legacy `evaluateCondition()` with `ConditionEvaluator`** - Use `ConditionEvaluator` only (except deprecated decision nodes)

### ✅ DO:

1. **Use `ConditionEvaluator::evaluate()` for all condition evaluation**
2. **Use `type: "default"` for catch-all routes**
3. **Validate condition schema before saving graph**
4. **Use `qc_result.*` properties for QC routing conditions**
5. **Test ambiguous routing scenarios** - Should throw exception, not silently fail

---

## Migration Notes

### From Legacy Decision Nodes

**Deprecated:** `handleDecisionNode()` uses private `evaluateCondition()` method  
**Migration:** Use conditional edges with `edge_condition` JSON field

### From guard_json

**Deprecated:** `guard_json` field (not evaluated in runtime)  
**Migration:** Use `edge_condition` JSON field with ConditionEvaluator schema

---

## References

- **ConditionEvaluator:** `source/BGERP/Dag/ConditionEvaluator.php`
- **Normal Routing:** `source/BGERP/Service/DAGRoutingService.php:939-1036`
- **QC Routing:** `source/BGERP/Service/DAGRoutingService.php:351-507`
- **QC Fail Routing:** `source/BGERP/Service/DAGRoutingService.php:522-701`

---

**Contract Status:** ✅ LOCKED  
**Last Updated:** 2025-11-14

