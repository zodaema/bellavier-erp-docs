# DAG Execution Runtime Audit Report
**Date:** 2025-11-14  
**Auditor:** AI Agent (Code Path Analysis)  
**Scope:** QC Decision, Rework Flow, Routing Source of Truth, Architecture Pattern

---

## Executive Summary

### QC Decision: **HYBRID (Node Policy + Edge Condition)**
- ✅ **อ่าน `qc_policy` จาก node** (node-centric)
- ✅ **แต่ยังต้องหา matching edge** (edge-centric routing)
- ❌ **ไม่ใช้ edge_condition/guard_json โดยตรง** → ใช้ ConditionEvaluator::evaluate() แทน

### Rework Flow: **DUAL PATH (Legacy Edge + V2 Human Selection)**
- ✅ **Legacy path ยังใช้งาน:** `routeToRework()` → หา `edge_type='rework'` → route token ผ่าน edge
- ✅ **V2 path (ใหม่):** `handleQCFailV2()` → Human เลือก target → **ไม่ใช้ edge traversal** → ใช้ `moveTokenToNode()` โดยตรง

### Routing Source of Truth: **HYBRID**
- QC Pass: ใช้ `edge_condition` + ConditionEvaluator (edge-centric)
- QC Fail: ใช้ `qc_policy` + หา matching edge (hybrid)
- Normal Routing: ใช้ `selectNextNode()` → evaluate `edge_condition` (edge-centric)

### Final Architecture Verdict: **HYBRID (Transitioning to Node-Centric)**
- ✅ Node-centric: QC policy, rework limit, scrap policy อ่านจาก node
- ✅ Edge-centric: Routing logic ยังพึ่ง edge_condition และ edge traversal
- ⚠️ **V2 path บ่งชี้ทิศทาง:** human-selected rework ไม่ใช้ edge → สนับสนุน node-centric

---

## Evidence Table

| Topic | File | Function | Lines | Finding |
|-------|------|----------|-------|---------|
| **QC Decision Logic** | `DAGRoutingService.php` | `handleQCResult()` | 351-507 | ใช้ `qc_policy` จาก node แต่ต้องหา matching edge |
| **QC Fail Routing** | `DAGRoutingService.php` | `handleQCFailWithPolicy()` | 522-701 | ใช้ `qc_policy` + หา edges (specific fail edges → legacy rework → default) |
| **Edge Condition Evaluation** | `DAGRoutingService.php` | `evaluateCondition()` | 1070-1203 | ใช้ ConditionEvaluator::evaluate() ไม่ใช้ guard_json โดยตรง |
| **Legacy Rework (Edge-based)** | `DAGRoutingService.php` | `routeToRework()` | 2485-2581 | หา `edge_type='rework'` → route token ผ่าน edge (LEGACY PATH) |
| **V2 Rework (Node-based)** | `BehaviorExecutionService.php` | `handleQCFailV2()` | 1688-1786 | Human เลือก target → `moveTokenToNode()` โดยตรง (ไม่ใช้ edge) |
| **QC Policy Read** | `DAGRoutingService.php` | `handleQCFail()` | 713-758 | อ่าน `qc_policy` จาก `node.qc_policy` JSON field |
| **Normal Routing** | `DAGRoutingService.php` | `routeToken()` | 61-148 | ใช้ `getOutgoingEdges()` → `selectNextNode()` → evaluate conditions |
| **Condition Evaluator** | `DAGRoutingService.php` | ConditionEvaluator::evaluate() | 462, 578 | ใช้ ConditionEvaluator แทน string matching (modern) |
| **executeQcSingle** | `NodeBehaviorEngine.php` | `executeQcSingle()` | 515-550 | **ไม่ทำ routing** → แค่สร้าง NODE_COMPLETE event → routing อยู่ที่ routing service |

---

## Call Flow Diagrams

### Flow 1: QC Pass → Routing

```
QC Node Complete
  └─ dag_token_api.php:3119
      └─ DAGRoutingService::handleQCResult()
          ├─ Read qc_policy from node.qc_policy JSON
          ├─ Get outgoing edges (getOutgoingEdges)
          ├─ Evaluate edge conditions:
          │   ├─ Specific conditional edges (type != 'default')
          │   │   └─ ConditionEvaluator::evaluate(edge_condition, context)
          │   ├─ Default conditional edges (type = 'default')
          │   └─ Normal edges (is_default=1 preferred)
          └─ Route via matching edge (routeToNode)
```

**Key Finding:** ใช้ `qc_policy` แต่ routing ยังพึ่ง edge conditions

### Flow 2: QC Fail → Legacy Rework (Edge-based)

```
QC Fail (Legacy Path)
  └─ DAGRoutingService::handleQCFail()
      ├─ Read qc_policy from node (if exists)
      │   └─ If empty → fallback to routeToRework()
      └─ handleQCFailWithPolicy()
          ├─ Read qc_policy fields: require_rework_edge, allow_scrap, rework_limit
          ├─ Get outgoing edges
          ├─ Priority order:
          │   1. Specific fail condition edges (ConditionEvaluator)
          │   2. Legacy rework edges (edge_type='rework')
          │   3. Default conditional edges
          └─ Route via matching edge (routeToNode)
```

**Key Finding:** Legacy path ยังใช้ `edge_type='rework'` สำหรับ backward compatibility

### Flow 3: QC Fail → V2 Rework (Human Selection - Node-based)

```
QC Fail (V2 Path - BehaviorExecutionService)
  └─ BehaviorExecutionService::handleQc()
      └─ handleQCFailV2()
          ├─ Validate target selection (same-component check)
          ├─ Check max rework count (node policy)
          ├─ if rework_mode === 'recut':
          │   └─ scrapToken() + spawn replacement
          └─ else (same_piece):
              └─ moveTokenToNode() directly (NO EDGE TRAVERSAL)
                  └─ Log to qc_rework_override_log
```

**Key Finding:** V2 path ไม่ใช้ edge → บ่งชี้ทิศทาง node-centric

### Flow 4: Normal Node Complete → Routing

```
Token Complete Node
  └─ TokenLifecycleService::completeNode()
      └─ DAGRoutingService::routeToken()
          ├─ Check parallel split/merge
          ├─ Get outgoing edges
          ├─ if 0 edges → completeToken()
          ├─ if 1 edge → routeToNode()
          └─ if 2+ edges → selectNextNode()
              └─ Evaluate edge conditions (evaluateCondition)
                  └─ Route via matching edge
```

**Key Finding:** Normal routing ยังเป็น edge-centric 100%

---

## Detailed Findings

### 1. QC Decision Source of Truth

#### Code Evidence:
- **File:** `source/BGERP/Service/DAGRoutingService.php:398-506`
- **Function:** `handleQCResult()`

```php
// Line 398: Read QC policy from node
$qcPolicy = \BGERP\Helper\JsonNormalizer::normalizeJsonField($node, 'qc_policy', null);

// Line 409: Get outgoing edges (still need edges!)
$edges = $this->getOutgoingEdges($nodeId);

// Line 412-416: Build context for condition evaluation
$context = [
    'token' => $token,
    'job' => $this->fetchJobTicket($token['id_instance'] ?? null),
    'node' => $node
];

// Line 462: Evaluate edge conditions using ConditionEvaluator
if (ConditionEvaluator::evaluate($condition, $context)) {
    $matchingEdges[] = $edge;
}
```

#### Verdict:
- ✅ **Node-centric:** อ่าน `qc_policy` จาก node
- ✅ **Edge-dependent:** ยังต้องหา matching edge เพื่อ route
- ❌ **ไม่ใช่ pure node-centric:** ยังไม่สามารถ route โดยไม่ใช้ edge ได้

### 2. Rework Flow Analysis

#### Legacy Path (Edge-based):
- **File:** `source/BGERP/Service/DAGRoutingService.php:2485-2581`
- **Function:** `routeToRework()`

```php
// Line 2497-2507: Find rework edge by edge_type
$stmt = $this->db->prepare("
    SELECT re.*, rn.node_name, rn.node_type
    FROM routing_edge re
    JOIN routing_node rn ON rn.id_node = re.to_node_id
    WHERE re.from_node_id = ?
    AND re.edge_type = 'rework'
    LIMIT 1
");

// Line 2565: Route token through edge
$this->tokenService->moveToken($tokenId, $reworkEdge['to_node_id'], $operatorId);
```

**Status:** ✅ **USED** - ยังถูกเรียกจาก `handleQCFail()` เมื่อไม่มี `qc_policy`

#### V2 Path (Node-based):
- **File:** `source/BGERP/Dag/BehaviorExecutionService.php:1688-1786`
- **Function:** `handleQCFailV2()`

```php
// Line 1777: Move token directly (NO EDGE TRAVERSAL)
$moveResult = $lifecycleService->moveTokenToNode($tokenId, $targetNodeId, 'QC_REWORK', $eventPayload);
```

**Status:** ✅ **USED** - ถูกเรียกเมื่อ human เลือก target (V2 flow)

#### Verdict:
- ✅ **Legacy edge path ยังใช้งาน** - ต้อง support ต่อ
- ✅ **V2 path ไม่ใช้ edge** - บ่งชี้ทิศทาง node-centric

### 3. Routing Source of Truth

#### QC Pass Routing:
- **File:** `source/BGERP/Service/DAGRoutingService.php:423-502`
- **Logic:** 
  1. อ่าน `qc_policy` จาก node
  2. Get outgoing edges
  3. Evaluate conditions → หา matching edge
  4. Route via edge

#### QC Fail Routing:
- **File:** `source/BGERP/Service/DAGRoutingService.php:522-701`
- **Logic:**
  1. อ่าน `qc_policy` จาก node (require_rework_edge, allow_scrap, rework_limit)
  2. Get outgoing edges
  3. Priority: specific fail edges → legacy rework edges → default edges
  4. Route via matching edge

#### Normal Routing:
- **File:** `source/BGERP/Service/DAGRoutingService.php:61-148`
- **Logic:**
  1. Get outgoing edges
  2. Evaluate conditions
  3. Route via edge

#### Verdict:
- ⚠️ **HYBRID:** Node policy + Edge routing
- ✅ **Condition evaluation:** ใช้ ConditionEvaluator (modern) ไม่ใช่ string matching

### 4. Edge Condition Usage

#### Code Evidence:
- **File:** `source/BGERP/Service/DAGRoutingService.php:1070-1203`
- **Function:** `evaluateCondition()`

**Supported condition types:**
- `qty_threshold`
- `token_property`
- `job_property`
- `node_property`
- `expression`

**Usage:**
- ✅ **USED:** ใน `selectNextNode()`, `handleQCResult()`, `handleQCFailWithPolicy()`
- ❌ **NOT USED:** `guard_json` (legacy field) - ไม่พบการใช้งานใน runtime

#### Verdict:
- ✅ **Edge conditions ยังใช้งาน** - แต่ใช้ ConditionEvaluator แทน guard_json

---

## Architecture Pattern Analysis

### Current State: **HYBRID (Transitioning)**

#### Node-Centric Components:
1. ✅ **QC Policy:** อ่านจาก `node.qc_policy`
2. ✅ **Rework Limit:** อ่านจาก `token.rework_limit` (มาจาก node policy)
3. ✅ **Scrap Policy:** อ่านจาก `qc_policy.allow_scrap`
4. ✅ **V2 Rework:** ไม่ใช้ edge → `moveTokenToNode()` โดยตรง

#### Edge-Centric Components:
1. ✅ **Routing Logic:** ยังพึ่ง `getOutgoingEdges()` → evaluate conditions → route via edge
2. ✅ **Legacy Rework:** ใช้ `edge_type='rework'`
3. ✅ **Condition Evaluation:** ใช้ `edge_condition` JSON field

#### Transition Indicators:
- ✅ V2 rework path ไม่ใช้ edge (node-centric)
- ⚠️ QC routing ยังพึ่ง edge แต่ใช้ node policy (hybrid)
- ⚠️ Normal routing ยังเป็น edge-centric 100%

---

## Risk Notes

### 1. Legacy Edge Path ยังใช้งาน
- **Risk:** ไม่สามารถตัด `edge_type='rework'` ได้เลย → ยังมี code path ที่พึ่งมัน
- **Evidence:** `routeToRework()` ยังถูกเรียกจาก `handleQCFail()` fallback
- **Mitigation:** ต้อง migrate graphs ทั้งหมดไปใช้ V2 หรือ qc_policy ก่อนตัด legacy

### 2. Dual Path Inconsistency
- **Risk:** Legacy path ใช้ edge, V2 path ไม่ใช้ edge → behavior ต่างกัน
- **Evidence:** 
  - Legacy: `routeToRework()` → edge traversal
  - V2: `handleQCFailV2()` → direct move
- **Mitigation:** ต้อง standardize เป็น V2 หรือ maintain backward compatibility

### 3. executeQcSingle ไม่ทำ Routing
- **Finding:** `executeQcSingle()` ใน `NodeBehaviorEngine` แค่สร้าง event → routing อยู่ที่ routing service
- **Implication:** Node behavior engine เป็น event generator → routing service ยังเป็น edge-centric

---

## Final Verdicts

### Edge Condition for QC: **USED (via ConditionEvaluator)**
- ✅ ใช้ `edge_condition` แต่ผ่าน ConditionEvaluator (ไม่ใช่ guard_json)
- ✅ QC routing ยังพึ่ง edge evaluation

### Edge Rework (edge_type='rework'): **USED (Legacy Path)**
- ✅ `routeToRework()` ยังใช้ `edge_type='rework'`
- ✅ ถูกเรียกเมื่อไม่มี `qc_policy` (fallback)

### Node-centric Execution: **PARTIAL**
- ✅ Node policy อ่านจาก node (qc_policy, rework_limit)
- ⚠️ Routing logic ยังพึ่ง edge traversal
- ✅ V2 path บ่งชี้ทิศทาง node-centric

---

## Recommendations

### 1. Short-term (Maintain Status Quo)
- ✅ **Keep edge_type='rework'** - ยังถูกใช้งาน
- ✅ **Support both paths** - Legacy edge + V2 human selection

### 2. Medium-term (Migration)
- ⚠️ **Migrate graphs** จาก legacy edge_type='rework' → qc_policy + conditional edges
- ⚠️ **Standardize rework flow** - เลือก V2 หรือ maintain dual path

### 3. Long-term (Architecture)
- 🔮 **Node Behavior Phase** - Move routing logic ไป node behavior handlers
- 🔮 **Remove edge dependency** - ให้ node handlers กำหนด routing โดยตรง

---

**Audit Completed:** 2025-11-14  
**Codebase Version:** Based on runtime code paths as of audit date
