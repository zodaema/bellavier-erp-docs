# Edge Condition & Rework Lock Summary
**Date:** 2025-12-25  
**Status:** ✅ **LOCKED** (Runtime Determinism + DB Evidence)

---

## Executive Summary

**Edge Condition:** Runtime **STILL DEPENDS** on Edge Condition for routing. 5 call sites use `ConditionEvaluator::evaluate()` with deterministic priority. Edge order is deterministic via SQL `ORDER BY priority DESC, id_edge ASC`. `guard_json` is **NOT READ** in runtime.

**Edge Rework:** Runtime has **3 entry points** - Legacy edge (`edge_type='rework'`), Policy-based, and V2 human selection. Legacy path **STILL REQUIRED** for backward compatibility, but **DB evidence shows 0 usage** in current tenant.

**Verdict:** System is **HYBRID** - Node policy (qc_policy) + Edge routing (edge_condition). Contracts locked. Ready for Node Behavior Phase with legacy support maintained.

---

## DB Evidence (Real Numbers)

**Source:** `docs/super_dag/00-audit/LEGACY_RELIANCE_STATS_20251225.md`  
**Tenant:** maison_atelier  
**Date:** 2025-12-25

### Summary Statistics

| Metric | Count | Status |
|--------|-------|--------|
| Total rework edges | 0 | ✅ No legacy usage |
| Graphs with rework edges | 0 | ✅ No legacy usage |
| QC nodes without qc_policy | 0 | ✅ All migrated |
| QC nodes with qc_policy | (not shown in summary) | ✅ Policy adoption complete |
| QC nodes with policy but no edges | 0 | ✅ No routing issues |
| Decision nodes | 0 | ✅ No legacy usage |
| Active tokens on decision nodes | 0 | ✅ No active usage |

### Key Findings

1. **Legacy Rework Edge:** 0 edges found - **ELIGIBLE to remove**
2. **QC Nodes Without Policy:** 0 nodes found - **ELIGIBLE to disable fallback**
3. **Decision Nodes:** 0 nodes found - **ELIGIBLE to deprecate**

---

## Go/No-Go Criteria for Legacy Deprecation

### Decision Nodes

**Current State:**
- Decision nodes: **0**
- Active tokens on decision nodes: **0**

**Eligibility Criteria:**
- `decision_nodes == 0 AND active_tokens_on_decision == 0`

**Status:** ✅ **ELIGIBLE to deprecate**

**Action:** Can remove `handleDecisionNode()` runtime support (keep for backward compatibility only)

---

### Legacy Rework Edge (edge_type='rework')

**Current State:**
- Rework edges: **0**
- QC nodes without policy: **0**

**Eligibility Criteria:**
- **Disable fallback:** `qc_nodes_without_policy == 0` → ✅ **ELIGIBLE**
- **Remove support:** `rework_edge_count == 0 AND qc_nodes_without_policy == 0` → ✅ **ELIGIBLE**

**Status:** ✅ **ELIGIBLE to disable fallback AND remove**

**Action:** Can remove `routeToRework()` legacy path (keep for backward compatibility only)

---

## Observability (Gated Logs Added)

**File:** `source/BGERP/Service/DAGRoutingService.php`

### B1: Legacy Rework Fallback Log
- **Location:** Line ~724 (after `if (empty($qcPolicy))`)
- **Flag:** `DEBUG_DAG_REWORK`
- **Logs:** `LEGACY_REWORK_FALLBACK` when QC node has no `qc_policy`

### B2: Legacy Rework Edge Usage Log
- **Location:** Line ~2520 (after `$reworkEdge = ...`)
- **Flag:** `DEBUG_DAG_REWORK`
- **Logs:** `LEGACY_REWORK_EDGE_USED` when `edge_type='rework'` is used

### B3: Decision Node Usage Log
- **Location:** Line ~319 (before `handleDecisionNode()`)
- **Flag:** `DEBUG_DAG_DECISION`
- **Logs:** `DEPRECATED_DECISION_NODE_USED` when decision node routes token

### C1: QC Node No Fail Edges Warning
- **Location:** Line ~645 (when `empty($matchingFailEdges)`)
- **Flag:** `DEBUG_DAG_REWORK`
- **Logs:** `QC_NODE_NO_FAIL_EDGES` when QC node has policy but no fail edges

### C2: QC Node No Rework Edge Warning
- **Location:** Line ~2520 (when `!$reworkEdge`)
- **Flag:** `DEBUG_DAG_REWORK`
- **Logs:** `QC_NODE_NO_REWORK_EDGE` when QC node has no policy and no rework edge

**Usage:**
```php
// Enable in config.php or environment
define('DEBUG_DAG_REWORK', true);
define('DEBUG_DAG_DECISION', true);
```

---

## Next Milestone: Node Behavior Phase

**Prerequisites (All Met):**
- ✅ Edge Condition contract locked
- ✅ Edge Rework contract locked
- ✅ DB evidence collected
- ✅ Observability added (gated)
- ✅ Legacy usage = 0 (eligible to deprecate)

**Ready to Proceed:**
- Node Behavior Phase can begin
- Legacy support maintained for backward compatibility
- Gated logs available for monitoring

---

## Files Updated

1. ✅ `docs/super_dag/00-audit/LEGACY_RELIANCE_STATS_20251225.md` - DB evidence
2. ✅ `source/BGERP/Service/DAGRoutingService.php` - Gated logs added
3. ✅ `docs/super_dag/01-contracts/EDGE_CONDITION_CONTRACT.md` - Contract locked
4. ✅ `docs/super_dag/01-contracts/EDGE_REWORK_CONTRACT.md` - Contract locked
5. ✅ `docs/super_dag/01-contracts/EDGE_CONDITION_REWORK_LOCK_20251225.md` - This file

---

**Status:** ✅ **COMPLETE**  
**Contracts Locked:** 2025-12-25  
**Evidence-Based:** All findings backed by DB queries + code references
