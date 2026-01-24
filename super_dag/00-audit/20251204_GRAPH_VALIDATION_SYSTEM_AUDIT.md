# Graph Designer & Validation System - Comprehensive Audit Report

**Date:** December 4, 2025  
**Auditor:** Claude Opus 4.5  
**Status:** 🟡 NEEDS ATTENTION - Multiple redundancies and inconsistencies found

---

## 📊 Executive Summary

The Graph Designer and Validation system has evolved organically over several phases, resulting in:

| Issue | Severity | Impact |
|-------|----------|--------|
| **Multiple validation engines** | 🔴 High | Code duplication, inconsistent results |
| **Scattered validation logic** | 🟡 Medium | Hard to maintain, bugs slip through |
| **Missing SELECT fields** | 🟢 Fixed | `is_default` was missing from edge query |
| **UI display bugs** | 🟢 Fixed | `[object Object]` in warnings |
| **1-hop merge detection** | 🟢 Fixed | BFS now finds downstream merge nodes |

---

## 🏗️ System Architecture

### File Overview

| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| `source/dag_routing_api.php` | 7,645 | Main API endpoint | 🟡 Bloated, contains inline validation |
| `source/BGERP/Dag/GraphValidationEngine.php` | 1,616 | Unified validation engine | ✅ Primary validator |
| `source/BGERP/Dag/SemanticIntentEngine.php` | 1,103 | Semantic intent analysis | ✅ Works correctly |
| `source/BGERP/Service/DAGValidationService.php` | 2,809 | Legacy validation service | ⚠️ Partially deprecated |
| `assets/javascripts/dag/graph_designer.js` | 8,775 | Frontend UI | ✅ Recently fixed |
| **Total** | **~22K** | - | - |

---

## 🔍 Detailed Findings

### 1. Multiple Validation Engines (🔴 Critical)

**Problem:** Three different validation systems exist with overlapping responsibilities:

#### A. `GraphValidationEngine` (Recommended - SINGLE SOURCE OF TRUTH)
```
Location: source/BGERP/Dag/GraphValidationEngine.php
Created: Task 19.7
Used by: dag_routing_api.php (validate_graph action)

Methods:
- validate() - Main entry point
- validateSemanticLayer() - Uses SemanticIntentEngine
- validateNodeExistence(), validateStartEnd(), validateEdgeIntegrity()
- validateQCRouting(), validateParallelSemantic(), validateReachabilityRules()
- hasMergeNodeDownstream() - BFS fix (Dec 4, 2025)

Features:
✅ Semantic intent analysis
✅ Structured error codes
✅ BFS for parallel split validation
✅ Profiling support
```

#### B. `DAGValidationService.validateGraphRuleSet()` (Redundant)
```
Location: source/BGERP/Service/DAGValidationService.php
Created: November 2, 2025

Methods:
- validateGraphRuleSet() - In-memory validation
- validateGraph() - DB-based validation

Issues:
❌ Duplicates START/END validation
❌ Duplicates cycle detection
❌ Separate error code format
❌ No semantic intent analysis
```

#### C. Inline validation in `dag_routing_api.php` (Legacy)
```
Location: source/dag_routing_api.php (lines 4144-4190)
Purpose: "Semantic validation" for decision/QC nodes

Issues:
❌ Duplicates QC default edge check
❌ Different logic from GraphValidationEngine
❌ Uses different data source (edges from loadGraphWithVersion)
```

### 2. Validation Flow Conflicts

**Current Flow (Confusing):**

```
User clicks "Validate" in Graph Designer
         ↓
dag_routing_api.php (case 'graph_validate')
         ↓
    ┌────────────────────────────────────────┐
    │  loadGraphWithVersion()                │
    │  - Fetches nodes/edges from DB         │
    │  - Was missing is_default! (FIXED)     │
    └────────────────────────────────────────┘
         ↓
    ┌────────────────────────────────────────┐
    │  GraphValidationEngine->validate()     │
    │  - Full semantic validation            │
    │  - Returns structured errors/warnings  │
    └────────────────────────────────────────┘
         ↓
    ┌────────────────────────────────────────┐
    │  INLINE validation (dag_routing_api)   │  ← REDUNDANT!
    │  - QC default edge check               │
    │  - Decision node check                 │
    │  - Different logic, may conflict       │
    └────────────────────────────────────────┘
         ↓
    Return combined errors/warnings
```

**Recommended Flow (Clean):**

```
User clicks "Validate"
         ↓
dag_routing_api.php (case 'graph_validate')
         ↓
    loadGraphWithVersion() ← Fixed: includes is_default
         ↓
    GraphValidationEngine->validate() ← SINGLE SOURCE OF TRUTH
         ↓
    Return results (no additional inline validation)
```

### 3. Data Loading Issues

**Fixed Issue:** `loadGraphWithVersion()` was missing `is_default` column:

```php
// BEFORE (Bug):
SELECT e.id_edge, e.from_node_id, e.to_node_id, e.edge_type, e.edge_condition, e.edge_label, e.priority, ...
// Missing: e.is_default!

// AFTER (Fixed Dec 4, 2025):
SELECT e.id_edge, e.from_node_id, e.to_node_id, e.edge_type, e.edge_condition, e.edge_label, e.priority, e.is_default, ...
```

### 4. Error Code Inconsistencies

**GraphValidationEngine codes:**
```
PARALLEL_SPLIT_NO_MERGE
QC_MISSING_POLICY
MULTI_END_WARNING
LINEAR_NODE_PARALLEL_FLAGS
CYCLE_DETECTED
```

**DAGValidationService codes:**
```
CYCLE_DETECTED
START_END_INVALID
JOIN_INVALID
SPLIT_INVALID
ORPHANED_NODE
```

**dag_routing_api inline codes:**
```
DAG_WARN_DECISION_NO_DEFAULT
DAG_WARN_QC_NO_REWORK
```

**Problem:** Same issue may have different codes depending on which validator catches it first.

### 5. Semantic Intent vs Rule-Based Validation

**Current State:**
- `SemanticIntentEngine` analyzes graph patterns to detect "intent"
- `GraphValidationEngine` uses intents for smart validation
- `DAGValidationService` uses pure rule-based validation (no intent)

**Example:**
```
Parallel Split Detection:
- SemanticIntentEngine: Detects "parallel.true_split" intent from pattern
- GraphValidationEngine: Uses BFS to verify merge node exists downstream
- DAGValidationService: Simple edge count check (less accurate)
```

---

## 🐛 Bugs Fixed Today (Dec 4, 2025)

### Bug 1: PARALLEL_SPLIT_NO_MERGE False Positive

**Root Cause:** `GraphValidationEngine.validateParallelSemantic()` used 1-hop check
```php
// OLD (Bug): Only checked immediate neighbors
foreach ($outgoingEdges as $edge) {
    $toId = ...;
    if ($nodeMap[$toId]['is_merge_node']) { ... }  // 1-hop only!
}

// NEW (Fixed): BFS traversal
$hasMergeNode = $this->hasMergeNodeDownstream($nodeId, $nodes, $edges, $nodeMap);
```

**Files Changed:**
- `source/BGERP/Dag/GraphValidationEngine.php` (+60 lines)

### Bug 2: Missing `is_default` in Edge Query

**Root Cause:** `loadGraphWithVersion()` didn't SELECT `is_default`
```php
// Fixed in dag_routing_api.php line ~606
SELECT ..., e.is_default, ...
```

### Bug 3: `[object Object]` in Save Warnings

**Root Cause:** Frontend displayed object instead of message
```javascript
// OLD (Bug):
${warn}  // Shows [object Object]

// NEW (Fixed):
${typeof warn === 'object' ? (warn.message || JSON.stringify(warn)) : warn}
```

**Files Changed:**
- `assets/javascripts/dag/graph_designer.js` (2 locations)

---

## 📋 Recommendations

### Short-term (Before Phase 5 continues)

1. **Remove inline validation from dag_routing_api.php**
   ```php
   // DELETE lines 4144-4190 (decision/QC semantic validation)
   // GraphValidationEngine already handles this
   ```

2. **Deprecate DAGValidationService.validateGraphRuleSet()**
   ```php
   /**
    * @deprecated Use GraphValidationEngine::validate() instead
    */
   public function validateGraphRuleSet(...) { ... }
   ```

3. **Standardize error codes**
   - Create `ValidationErrorCode.php` constant class
   - All validators use same codes

### Medium-term (Q1 2026)

1. **Merge DAGValidationService into GraphValidationEngine**
   - Move DB-based validations (serial requirements, etc.)
   - Keep one service only

2. **Refactor dag_routing_api.php**
   - Extract validation endpoints to separate file
   - Currently 7,645 lines - too big

3. **Add validation result caching**
   - Cache results for unchanged graphs
   - Invalidate on save

### Long-term (Q2 2026)

1. **Create validation plugin system**
   - Allow custom validators per tenant
   - Support different industry requirements

---

## 🧪 Test Coverage

### Existing Tests

| Test File | Coverage | Status |
|-----------|----------|--------|
| `tests/super_dag/ValidateGraphTest.php` | Basic validation | ✅ |
| `tests/super_dag/SemanticSnapshotTest.php` | Intent detection | ✅ |
| `tests/Unit/DAGValidationExtendedTest.php` | Edge cases | ✅ |
| `tests/manual/test_bfs_merge_fix.php` | BFS fix | ✅ Created today |

### Missing Tests

- [ ] Integration test: Full validation flow
- [ ] Regression test: Parallel split with deep merge
- [ ] Performance test: Large graphs (100+ nodes)

---

## 📐 Database Schema Notes

### Key Tables

```sql
routing_graph (id_graph, code, name, status, graph_type, ...)
routing_node (id_node, id_graph, node_code, node_type, is_parallel_split, is_merge_node, ...)
routing_edge (id_edge, id_graph, from_node_id, to_node_id, edge_type, is_default, edge_condition, ...)
```

### Important Columns

| Column | Table | Usage | Notes |
|--------|-------|-------|-------|
| `is_parallel_split` | routing_node | Marks parallel split nodes | Boolean (0/1) |
| `is_merge_node` | routing_node | Marks merge points | Boolean (0/1) |
| `is_default` | routing_edge | Default edge for conditional routing | Boolean (0/1), was missing from SELECT! |
| `edge_condition` | routing_edge | JSON condition for conditional edges | Required when edge_type='conditional' |
| `qc_policy` | routing_node | JSON QC configuration | Required for node_type='qc' |

---

## 🔄 Current Validation Rules

### From GraphValidationEngine

| Rule | Code | Severity | Description |
|------|------|----------|-------------|
| Start node count | GRAPH_MISSING_START | Error | Must have exactly 1 |
| End node count | GRAPH_MISSING_END | Error | Must have at least 1 |
| Edge integrity | EDGE_MISSING_FROM/TO | Error | Edges must reference valid nodes |
| Parallel split | PARALLEL_SPLIT_NO_MERGE | Error | Must have merge downstream (BFS) |
| QC routing | QC_MISSING_POLICY | Error | QC nodes need qc_policy |
| Reachability | UNREACHABLE_NODE_ERROR | Error | All nodes reachable from START |
| Cycles | CYCLE_DETECTED | Warning | Rework cycles allowed |

### From Inline dag_routing_api

| Rule | Code | Severity | Description |
|------|------|----------|-------------|
| QC default edge | DAG_WARN_DECISION_NO_DEFAULT | Warning | QC/decision need is_default edge |
| QC rework edge | DAG_WARN_QC_NO_REWORK | Warning | QC should have fail path |

---

## 📚 Related Documentation

- `docs/super_dag/00-audit/GRAPH_DESIGNER_RULES.md` - Graph design rules
- `docs/dag/GRAPH_DESIGNER_FINAL_REFACTOR_PLAN.md` - Refactor plan
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Parallel flow spec

---

## ✅ Action Items

### Immediate (Today)

- [x] Fix BFS merge detection
- [x] Fix missing is_default in SELECT
- [x] Fix [object Object] UI display
- [x] Create this audit report

### Next Sprint

- [ ] Remove inline validation from dag_routing_api.php
- [ ] Add deprecation notice to DAGValidationService
- [ ] Standardize error codes across all validators
- [ ] Create integration tests for full validation flow

### Future

- [ ] Refactor dag_routing_api.php (split into smaller files)
- [ ] Merge DAGValidationService into GraphValidationEngine
- [ ] Add validation result caching

---

## 🔴 **CRITICAL: Rework Edge Inconsistency (Dec 4, 2025 - Round 2)**

### **ปัญหา:**

**Modern Pattern (ใน Seed file):**
```php
// Rework ใช้ edge_type='conditional' + edge_condition
['from' => 'QC_BODY', 'to' => 'STITCH_BODY', 'type' => 'conditional', 'condition' => $qcFailCondition]
```

**Legacy Pattern (ในเอกสารและ code เก่า):**
```php
// Rework ใช้ edge_type='rework'
['from' => 'QC_BODY', 'to' => 'STITCH_BODY', 'type' => 'rework']
```

### **Code ที่ใช้ Legacy Pattern (ต้องแก้):**

| File | Function | Issue |
|------|----------|-------|
| `DAGValidationService.php` | `hasCycle()` | Skip เฉพาะ `edge_type='rework'` |
| `GraphValidationEngine.php` | Cycle check | ตรวจหา `edge_type='rework'` |
| `GraphValidationEngine.php` | QC routing | ตรวจ failure path ด้วย `edge_type='rework'` |

### **Database Reality:**
```sql
-- Seed graph (ID 1951) ไม่มี edge_type='rework' เลย!
SELECT edge_type, COUNT(*) FROM routing_edge WHERE id_graph=1951 GROUP BY edge_type;
-- normal: 9, conditional: 8
```

### **ผลกระทบ:**

1. **Cycle Detection False Positive:**
   - `hasCycle()` ไม่ skip conditional edges
   - ทำให้ detect cycles แม้ว่าจะเป็น intentional rework loops

2. **QC Routing Check:**
   - ตรวจหา `edge_type='rework'` เพื่อยืนยัน failure path
   - ไม่เจอ conditional edges ที่มี qc_fail condition
   - อาจ error "QC_MISSING_FAILURE_PATH"

3. **Publish Validation:**
   - `canPublishGraph()` ใช้ `DAGValidationService.validateGraph()`
   - ใช้ `hasCycle()` ที่ไม่ skip conditional → **Block publish!**

### **Fix Required:**

**Option A: Update Validators to understand both patterns**
```php
// In hasCycle() and other places:
if ($edge['edge_type'] === 'rework') {
    continue; // Skip legacy rework
}
// Also skip conditional edges with fail condition
if ($edge['edge_type'] === 'conditional') {
    $condition = $edge['edge_condition'] ?? null;
    if ($condition && isFailCondition($condition)) {
        continue; // Skip modern rework
    }
}
```

**Option B: Standardize to one pattern (Recommended)**
- Use `edge_type='conditional'` everywhere (modern)
- Deprecate `edge_type='rework'`
- Update all validators to check condition instead of edge_type

### **Immediate Action:**
แก้ `DAGValidationService.hasCycle()` ให้ skip conditional edges ที่มี fail condition

---

## 🔴 **CRITICAL: Dual Validation Engine (Dec 4, 2025)**

### **ปัญหา:**

| Action | Engine Used |
|--------|-------------|
| `graph_validate` (UI) | `GraphValidationEngine` |
| `graph_publish` (API) | `DAGValidationService.canPublishGraph()` |

**ผลกระทบ:** 
- Validate ผ่าน แต่ Publish ไม่ผ่าน (หรือกลับกัน)
- User confused

### **Fix Required:**
```php
// In graph_publish:
// BEFORE:
$canPublish = $validationService->canPublishGraph($graphId);

// AFTER (use same engine):
$validationEngine = new GraphValidationEngine($tenantDb);
$validationResult = $validationEngine->validate($nodes, $edges, ['mode' => 'publish']);
if (!$validationResult['valid']) {
    json_error('Validation failed', 400, ['errors' => $validationResult['errors']]);
}
```

---

## 🔴 **CRITICAL: Routing Priority for Default/Else Edges (Dec 4, 2025 - Round 3)**

### Problem Found

**UI states:** "If disabled [Use Conditional Routing toggle], this edge becomes the ELSE route."

**But Runtime (`DAGRoutingService`) has no priority logic:**

```php
// Line 886-890: Normal edges ALWAYS match
if ($edge['edge_type'] === 'normal' || empty($edge['edge_condition'])) {
    $matchingEdges[] = $edge;  // ❌ Always added!
    continue;
}

// Line 913-915: Conditional edges evaluated
if (ConditionEvaluator::evaluate($condition, $context)) {
    $matchingEdges[] = $edge;  // ❌ Default edge also matches!
}

// Line 925: Multiple matches = ERROR
if (count($matchingEdges) > 1) {
    throw new \Exception('Multiple edges match');  // ❌ Always happens!
}
```

### Impact

| Scenario | Expected | Actual |
|----------|----------|--------|
| QC Pass with pass+else edges | Pass edge only | ERROR (both match) |
| QC Fail with pass+else edges | Else edge only | ✅ Works |
| Any with normal+conditional | Conditional first | ERROR (both match) |

### Root Cause

1. **No priority order:** All edges evaluated equally
2. **Normal edges always match:** No conditional evaluation
3. **Default edges always match:** `type: 'default'` returns `true`

### Solution (Task 27.10.5)

Implement priority-based routing:
1. **Priority 1:** Specific conditional edges (evaluate first)
2. **Priority 2:** Default conditional edges (fallback)
3. **Priority 3:** Normal edges (catch-all)

---

## 📋 Tasks Created from Audit

| Task | Description | Status |
|------|-------------|--------|
| 27.10.1 | Fix Rework Edge Pattern Recognition | ✅ COMPLETE |
| 27.10.2 | Unify Validation Engine for Publish | 📋 PENDING |
| 27.10.3 | Validation Consolidation & Cleanup | 📋 PENDING |
| 27.10.4 | Validate Edge Condition Structure | 📋 PENDING |
| 27.10.5 | Fix Routing Priority for Default/Else | 📋 PENDING |

---

**Report Generated:** December 4, 2025  
**Last Updated:** December 4, 2025 (Round 3 Audit - Routing Priority)  
**Version:** 1.2

