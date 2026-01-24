# Edge Rework Contract
**Version:** 1.0  
**Date:** 2025-11-14  
**Status:** LOCKED (Runtime Determinism)

---

## Executive Summary

Rework routing has **3 entry points** with different priority chains. Legacy `edge_type='rework'` is **STILL USED** as fallback when `qc_policy` is missing. V2 human-selected rework **bypasses edge traversal** entirely. System is in **transition state** - cannot remove legacy support yet.

**Key Finding:** Dual-path architecture (legacy edge + V2 human selection) must be maintained until all graphs migrate to `qc_policy`.

---

## Entry Points Map

### 1. Legacy Path (handleQCFail → routeToRework)

**File:** `source/BGERP/Service/DAGRoutingService.php`  
**Function:** `handleQCFail()` → `routeToRework()`  
**Lines:** 713-758 → 2485-2581  
**Caller Chain:**
```
dag_token_api.php:3119 (QC fail)
  └─ DAGRoutingService::handleQCResult() [351]
      └─ handleQCFail() [713] (if qc_policy empty, line 723)
          └─ routeToRework() [2485] (line 753)
```

**Evidence:**
- **Entry:** `handleQCResult()` line 505 when `$qcPass === false`
- **Trigger:** `qc_policy` is empty/null (line 723: `if (empty($qcPolicy))`)
- **SQL Query:** `SELECT ... WHERE edge_type = 'rework'` (line 2497-2507)
- **Edge traversal:** ✅ **YES** - Routes token through edge (line 2565: `moveToken($tokenId, $reworkEdge['to_node_id'])`)
- **Fallback:** If no rework edge → scraps token (line 2509-2519)

**Behavior:**
- Finds edge with `edge_type='rework'` (line 2502)
- Routes token through edge (line 2565)
- OR spawns new token if `rework_policy.on_fail = 'spawn_new_token'` (line 2522)

### 2. Policy Path (handleQCFailWithPolicy)

**File:** `source/BGERP/Service/DAGRoutingService.php`  
**Function:** `handleQCFailWithPolicy()`  
**Lines:** 522-701  
**Caller Chain:**
```
handleQCResult() [505] (when $qcPass === false)
  └─ handleQCFailWithPolicy() [522]
```

**Evidence:**
- **Entry:** `handleQCResult()` line 505 when `$qcPass === false`
- **Trigger:** QC node has `qc_policy` (line 398-401: `if (empty($qcPolicy))` throws exception)
- **Edge traversal:** ✅ **YES** - Routes via matching edge (line 688-689: `routeToNode($tokenId, $failEdge)`)
- **Priority:** Specific fail → Legacy rework → Default (line 589-602)
- **Legacy fallback:** Uses `edge_type='rework'` as Priority 2 (line 595-597)

**Trigger Condition:**
- QC node has `qc_policy` (line 398-401)
- QC result is fail

**Behavior:**
- Uses `qc_policy` fields: `require_rework_edge`, `allow_scrap`, `rework_limit`
- Evaluates edges with priority: specific fail → legacy rework → default
- Routes via matching edge OR scraps token

### 3. V2 Path (handleQCFailV2 - Human Selection)

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`  
**Function:** `handleQCFailV2()`  
**Lines:** 1688-1786  
**Caller Chain:**
```
BehaviorExecutionService::handleQc() [1586]
  └─ (if target_node_id !== null) [1600]
      └─ handleQCFailV2() [1688]
```

**Evidence:**
- **Entry:** `BehaviorExecutionService::handleQc()` line 1600 checks `$targetNodeId !== null`
- **Edge traversal:** ❌ **NO** - Direct `moveTokenToNode()` (line 1777)
- **Validation:** Same-component branch check (line 1715: `validateReworkTargetSelection()`)
- **Max rework:** Checks `MAX_REWORK_COUNT_PER_TOKEN` (line 1703)
- **Audit log:** Logs to `qc_rework_override_log` (line 1787)

**Trigger Condition:**
- Human selects rework target (`target_node_id` in form data)
- V2 flow requested (line 1600)

**Behavior:**
- **NO EDGE TRAVERSAL** - Direct `moveTokenToNode()` (line 1777)
- Validates same-component branch (line 1715)
- Checks max rework count (line 1703)
- Logs to `qc_rework_override_log` (line 1787)

---

## Priority Chain (Authoritative Rules)

### Policy Path Priority (handleQCFailWithPolicy)

**File:** `source/BGERP/Service/DAGRoutingService.php:536-602`

**Priority Order:**
1. **Specific fail condition edges** (`edge_type='conditional'` + condition evaluates to true)
   - Evaluated using `ConditionEvaluator::evaluate()` (line 578)
   - First match wins
   - Multiple matches → **Exception thrown** (line 684)

2. **Legacy rework edges** (`edge_type='rework'`)
   - Matched by `edge_type` only (no condition evaluation)
   - Fallback if no specific match (line 595-597)

3. **Default conditional edges** (`condition.type = 'default'` OR `is_default=1` on normal edge)
   - Fallback if no specific or legacy match (line 600-602)

**Decision Logic (After Edge Selection):**
- Check rework limit (line 605-642)
  - If exceeded → scrap token (if `allow_scrap=true`)
  - If scrap not allowed → **Exception thrown**
- If no matching edges (line 645-680)
  - If `require_rework_edge=true` → **Exception thrown**
  - If `allow_scrap=true` → scrap token
  - If scrap not allowed → **Exception thrown**

### Legacy Path Priority (routeToRework)

**File:** `source/BGERP/Service/DAGRoutingService.php:2485-2581`

**Priority Order:**
1. **Find `edge_type='rework'` edge** (line 2497-2507)
   - SQL query: `WHERE edge_type = 'rework'`
   - First match wins (LIMIT 1)

2. **If no rework edge found:**
   - Scrap token (line 2511)

**Rework Policy (node_config.rework_policy):**
- If `on_fail = 'spawn_new_token'` → spawn new token at target (line 2522-2562)
- Else → route token through edge (line 2564-2580)

### V2 Path Priority (handleQCFailV2)

**File:** `source/BGERP/Dag/BehaviorExecutionService.php:1688-1786`

**Priority Order:**
1. **Human selection wins** (if `target_node_id` provided)
   - Validates same-component branch (line 1715)
   - Checks max rework count (line 1703)
   - **NO EDGE TRAVERSAL** - Direct move (line 1777)

2. **Rework mode:**
   - `recut` → scrap current token + spawn replacement (line 1727-1760)
   - `same_piece` → move token to target (line 1761-1786)

---

## Inconsistencies & Gaps

### 1. Dual Path Behavior Difference

**Issue:**
- Legacy path: Routes through edge (topology-based)
- V2 path: Direct move (no edge traversal)

**Impact:**
- Same QC fail can route differently depending on entry point
- Legacy graphs may break if V2 path is used

**Mitigation:**
- V2 path requires explicit `target_node_id` - won't auto-trigger
- Legacy path still works for graphs without `qc_policy`

### 2. Legacy Rework Edge Still Required

**Issue:**
- `routeToRework()` requires `edge_type='rework'` edge
- If missing → token is scrapped (no fallback)

**Impact:**
- Graphs without rework edge cannot use legacy path
- Must migrate to `qc_policy` or add rework edge

**Evidence:**
- Line 2509-2519: No rework edge → scrap token

### 3. No Guard for Legacy Fallback

**Issue:**
- `handleQCFail()` falls back to `routeToRework()` silently
- No warning when legacy path is used

**Impact:**
- Hard to track which graphs still use legacy
- Migration progress unclear

**Recommendation:**
- Add warning log when legacy path is used (gated by debug flag)

---

## Observed Legacy Reliance (DB Evidence)

**Source:** `docs/super_dag/00-audit/LEGACY_RELIANCE_STATS_20251225.md`  
**Date:** 2025-12-25  
**Tenant:** maison_atelier

### Summary Statistics

| Metric | Count | Status |
|--------|-------|--------|
| Total rework edges | 0 | ✅ No legacy usage |
| Graphs with rework edges | 0 | ✅ No legacy usage |
| QC nodes without qc_policy | 0 | ✅ All migrated |
| QC nodes with policy but no edges | 0 | ✅ No routing issues |

### Go/No-Go Criteria for Legacy Deprecation

**Legacy Rework Edge (edge_type='rework'):**
- **Current:** 0 rework edges, 0 QC nodes without policy
- **Eligible to disable fallback:** `qc_nodes_without_policy == 0` → ✅ **ELIGIBLE**
- **Eligible to remove:** `rework_edge_count == 0 AND qc_nodes_without_policy == 0` → ✅ **ELIGIBLE**

**Status:** ✅ **ELIGIBLE to disable fallback AND remove**

**Action:** Can remove `routeToRework()` legacy path (keep for backward compatibility only)

### Risk Assessment

**If legacy path is removed:**
- Graphs without `qc_policy` → **Will fail** (no rework routing)
- Graphs with `edge_type='rework'` but no `qc_policy` → **Will fail**
- Graphs with both → **Will work** (use policy path)

**Current State:** ✅ **SAFE** - No graphs rely on legacy path (0 usage)

**Migration Required:**
- ✅ **COMPLETE** - All QC nodes have `qc_policy` (0 nodes without policy)

**Evidence:**
- Legacy path entry: `handleQCFail()` line 723 checks `if (empty($qcPolicy))`
- Legacy path SQL: `routeToRework()` line 2502 queries `WHERE edge_type = 'rework'`
- Policy path fallback: `handleQCFailWithPolicy()` line 595-597 uses legacy as Priority 2
- **DB Query Results:** 0 rework edges, 0 QC nodes without policy

---

## Loopback Edge / Back-Edge Usage

### Topology Analysis

**Finding:**
- Rework edges create **intentional cycles** in graph topology
- Validation engine allows intentional cycles (rework/fail edges)

**File:** `source/BGERP/Dag/GraphValidationEngine.php:1573-1585`

**Behavior:**
- Detects cycles in graph
- Checks if cycle is intentional (rework/fail edge)
- Intentional cycles → **No error**
- Unintentional cycles → **Warning**

**Evidence:**
```php
// Line 1578-1579
if ($edge['edge_type'] === 'rework' || $this->isReworkSinkEdge($edge, $nodes, $nodeMap)) {
    $isIntentionalCycle = true;
}
```

### Back-Edge Usage

**Status:** ✅ **USED** - Rework edges are back-edges that create cycles

**Purpose:**
- Allow token to return to previous node for rework
- Create intentional loops in graph topology

**Risk if Removed:**
- Cannot route tokens back for rework
- Must use V2 human selection or spawn new tokens

---

## Telemetry & Monitoring

### Current Logging

**Legacy Path:**
- No specific log for legacy rework usage
- Only general QC fail event (line 2568)

**Policy Path:**
- QC fail event with `qc_policy_applied: true` (line 692-698)
- Includes `action: 'rework'` or `action: 'scrapped'`

**V2 Path:**
- Logs to `qc_rework_override_log` table (line 1787)
- Includes `defect_code`, `rework_mode`, `target_node_id`

### Recommended Telemetry (Gated)

**Add debug logs (gated by `DEBUG_DAG.rework` flag):**
1. Legacy path usage: Log when `routeToRework()` is called
2. Policy path usage: Log when `handleQCFailWithPolicy()` is called
3. V2 path usage: Already logged to audit table

**Metrics to Track:**
- Count of legacy rework routes per day
- Count of policy rework routes per day
- Count of V2 human-selected rework per day
- Graphs still using legacy path

---

## Deprecation Plan

### Phase 0: Lock Behavior + Warn (Current)

**Status:** ✅ **COMPLETE**
- Behavior is locked (no changes)
- Contracts documented

**Actions:**
- Add warning logs when legacy path is used (gated by debug flag)
- Document migration requirements

### Phase 1: Enforce qc_policy Presence (Future)

**Target:** All QC nodes must have `qc_policy`

**Actions:**
- Graph validation: Warn if QC node has no `qc_policy`
- Graph Designer: Require `qc_policy` when creating QC node
- Migration tool: Auto-generate `qc_policy` from `edge_type='rework'` edges

**Timeline:** TBD

### Phase 2: Deprecate edge_type='rework' (Future)

**Target:** Remove legacy path support

**Prerequisites:**
- All graphs have `qc_policy`
- All graphs use conditional fail edges (not `edge_type='rework'`)
- Migration complete

**Actions:**
- Mark `edge_type='rework'` as deprecated in Graph Designer
- Add validation warning for new graphs using `edge_type='rework'`
- **DO NOT REMOVE** - Keep for backward compatibility

**Timeline:** TBD (after Phase 1 complete)

---

## Migration Plan

### From Legacy to Policy

**Step 1: Add qc_policy to QC Node**
```json
{
  "mode": "basic_pass_fail",
  "require_rework_edge": true,
  "allow_scrap": true,
  "allow_replacement": false
}
```

**Step 2: Convert rework edge to conditional fail edge**
- Change `edge_type='rework'` → `edge_type='conditional'`
- Add `edge_condition` with appropriate condition (or `type: "default"`)

**Step 3: Test routing**
- Verify QC fail routes correctly
- Verify rework limit is enforced
- Verify scrap behavior works

### From Legacy to V2

**Step 1: Enable V2 flow in UI**
- Add rework target selection UI
- Pass `target_node_id` in form data

**Step 2: Validate same-component branch**
- Ensure QC node and target are in same component branch
- Use `validateReworkTargetSelection()` (line 3865)

**Step 3: Test V2 routing**
- Verify direct move works (no edge traversal)
- Verify audit log is created
- Verify rework count is incremented

---

## Validation Lint Rules (Optional)

### Rule 1: QC Node Without qc_policy

**Check:**
```php
if ($node['node_type'] === 'qc' && empty($node['qc_policy'])) {
    // Warning: QC node without qc_policy relies on legacy rework edge
}
```

**Severity:** Warning (not error - legacy support still works)

### Rule 2: QC Node With qc_policy But No Outgoing Edges

**Check:**
```php
if ($node['node_type'] === 'qc' && !empty($node['qc_policy'])) {
    $edges = getOutgoingEdges($nodeId);
    if (empty($edges)) {
        // Error: QC node with qc_policy but no routing edges
    }
}
```

**Severity:** Error (token will be unroutable)

### Rule 3: Edge Condition Schema Invalid

**Check:**
```php
$condition = normalizeJsonField($edge, 'edge_condition', null);
if ($condition && !ConditionEvaluator::validateSchema($condition)) {
    // Warning: Invalid condition schema
}
```

**Severity:** Warning (will be treated as normal edge)

---

## References

- **Legacy Path:** `source/BGERP/Service/DAGRoutingService.php:713-758, 2485-2581`
- **Policy Path:** `source/BGERP/Service/DAGRoutingService.php:522-701`
- **V2 Path:** `source/BGERP/Dag/BehaviorExecutionService.php:1688-1786`
- **Validation:** `source/BGERP/Dag/GraphValidationEngine.php:1573-1585`

---

**Contract Status:** ✅ LOCKED  
**Last Updated:** 2025-11-14

