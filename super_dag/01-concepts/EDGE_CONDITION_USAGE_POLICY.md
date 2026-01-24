# Edge Condition Usage Policy

> **Last Updated:** 2024-12-04  
> **Status:** ✅ Finalized  
> **Authors:** Human + AI Collaboration

---

## 🎯 Core Principle

**"edge_condition เป็นของเล่นของ Router/Option Node ไม่ใช่ของ QC"**

```
┌──────────────────────────────────────────────────────────────┐
│                    DECISION OWNERSHIP                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐          ┌──────────────────┐           │
│  │  SYSTEM DECIDES │          │  HUMAN DECIDES   │           │
│  │ (edge_condition)│          │  (Behavior UI)   │           │
│  ├─────────────────┤          ├──────────────────┤           │
│  │                 │          │                  │           │
│  │  • Router Node  │          │  • QC Node       │           │
│  │  • Option Node  │          │  • Decision Node │           │
│  │  • Auto-skip    │          │  • Manual Gate   │           │
│  │                 │          │                  │           │
│  └─────────────────┘          └──────────────────┘           │
│                                                              │
│  ✅ Logic in Graph            ✅ Logic in Behavior           │
│  ✅ Auto-route by data        ✅ Human picks target          │
│  ✅ No human interaction      ✅ Graph = Permission only     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 1️⃣ When to Use `edge_condition`

### ✅ USE FOR: Router/Option Nodes (System Decision)

**Purpose:** Auto-route tokens based on product/material/option data

**Examples:**

```
┌─────────────────────────────────────────────────────────────┐
│              EXAMPLE 1: Material-Based Routing              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    ┌──────────┐                             │
│                    │  ROUTER  │                             │
│                    │  NODE    │                             │
│                    └────┬─────┘                             │
│                         │                                   │
│         ┌───────────────┼───────────────┐                   │
│         │               │               │                   │
│         ▼               ▼               ▼                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐             │
│  │ EDGE PAINT │  │ HEAT SEAL  │  │ SKIP EDGE  │             │
│  │ (3 coats)  │  │            │  │            │             │
│  └────────────┘  └────────────┘  └────────────┘             │
│                                                             │
│  Edge Conditions:                                           │
│  • → EDGE PAINT: material IN ['goat', 'cow']                │
│  • → HEAT SEAL:  material IN ['canvas', 'nylon']            │
│  • → SKIP EDGE:  material = 'synthetic' (default)           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────┐
│  EXAMPLE 2: Product Option Routing                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    ┌──────────┐                             │
│                    │  OPTION  │                             │
│                    │  ROUTER  │                             │
│                    └────┬─────┘                             │
│                         │                                   │
│              ┌──────────┴──────────┐                        │
│              │                     │                        │
│              ▼                     ▼                        │
│       ┌────────────┐        ┌────────────┐                  │
│       │ ATTACH     │        │ SKIP TO    │                  │
│       │ CHARM      │        │ ASSEMBLY   │                  │
│       └────────────┘        └────────────┘                  │
│                                                             │
│  Edge Conditions:                                           │
│  • → ATTACH CHARM: has_custom_charm = true                  │
│  • → SKIP:         has_custom_charm = false (default)       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**edge_condition Format:**
```json
{
  "type": "token_property",
  "property": "metadata.material",
  "operator": "in",
  "value": ["goat", "cow"]
}
```

---

## 2️⃣ When NOT to Use `edge_condition`

### ❌ DO NOT USE FOR: QC Rework (Human Decision)

**Purpose:** QC rework decisions are made by humans, not by data

**Reasoning:**
- QC failures require human judgment (severity, root cause, fix approach)
- Same defect type may require different rework paths
- Operator expertise determines best recovery route

**Correct Approach:**

```
┌─────────────────────────────────────────────────────────────┐
│  QC REWORK: Graph as Permission Layer                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    ┌──────────┐                             │
│                    │    QC    │                             │
│                    │   NODE   │                             │
│                    └────┬─────┘                             │
│                         │                                   │
│    ┌────────────────────┼────────────────────┐              │
│    │        │           │           │        │              │
│    ▼        ▼           ▼           ▼        ▼              │
│  ┌────┐  ┌───────┐  ┌────────┐  ┌───────┐  ┌──────┐         │
│  │PASS│  │ CUT   │  │  GLUE  │  │STITCH │  │ EDGE │         │
│  │    │  │(recut)│  │(rework)│  │(redo) │  │(redo)│         │
│  └────┘  └───────┘  └────────┘  └───────┘  └──────┘         │
│                                                             │
│  Edge Types:                                                │
│  • → PASS:   edge_type = 'normal', is_default = true        │
│  • → CUT:    edge_type = 'rework', NO edge_condition        │
│  • → GLUE:   edge_type = 'rework', NO edge_condition        │
│  • → STITCH: edge_type = 'rework', NO edge_condition        │
│  • → EDGE:   edge_type = 'rework', NO edge_condition        │
│                                                             │
│  ⚠️ NO edge_condition on rework edges!                      │
│  Decision made by QC Behavior UI, not by graph data         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**QC UI Flow:**
```
1. Operator marks QC as FAIL
2. UI shows: "ส่งกลับไปแก้ที่ไหน?"
   • [ ] กลับไปตัดใหม่ (CUT)
   • [ ] กลับไปทากาว (GLUE)
   • [ ] กลับไปเย็บ (STITCH)
   • [ ] กลับไปแก้ขอบ (EDGE)
3. Operator selects target
4. Router validates target is in allowed edges
5. Token routes to selected node
```

---

## 3️⃣ Node Type Summary

| Node Type | edge_condition | Decision By | Logic Location |
|-----------|----------------|-------------|----------------|
| **Router Node** | ✅ Required | System | Graph (edge_condition) |
| **Option Node** | ✅ Required | System | Graph (edge_condition) |
| **QC Node** | ❌ Forbidden | Human | Behavior UI |
| **Decision Node** | ❌ Forbidden | Human | Behavior UI |
| **Manual Gate** | ❌ Forbidden | Human | Behavior UI |

---

## 4️⃣ Implementation Rules

### For Graph Designer (UI)

```javascript
// When creating edges from QC node
if (sourceNode.node_type === 'qc') {
    // Disable condition editor for rework edges
    if (edge.edge_type === 'rework') {
        edge.edge_condition = null; // Force null
        showMessage('QC rework edges use plain routing (no conditions)');
    }
}

// When creating edges from Router node
if (sourceNode.node_type === 'router') {
    // Require condition
    if (!edge.edge_condition && !edge.is_default) {
        showWarning('Router edges should have conditions');
    }
}
```

### For Validation Engine

```php
// GraphValidationEngine.php
private function validateEdgeConditionPolicy(array $node, array $edge): array
{
    $warnings = [];
    $nodeType = $node['node_type'] ?? 'operation';
    $edgeType = $edge['edge_type'] ?? 'normal';
    $hasCondition = !empty($edge['edge_condition']);
    
    // QC nodes: rework edges should NOT have conditions
    if ($nodeType === 'qc' && $edgeType === 'rework' && $hasCondition) {
        $warnings[] = [
            'code' => 'POLICY_QC_REWORK_NO_CONDITION',
            'message' => "QC rework edge '{$edge['edge_code']}' should not have edge_condition (use Behavior UI instead)"
        ];
    }
    
    // Router nodes: edges SHOULD have conditions (except default)
    if ($nodeType === 'router' && $edgeType === 'conditional' && !$hasCondition && !$edge['is_default']) {
        $warnings[] = [
            'code' => 'POLICY_ROUTER_NEEDS_CONDITION',
            'message' => "Router edge '{$edge['edge_code']}' should have edge_condition"
        ];
    }
    
    return $warnings;
}
```

### For DAGRoutingService

```php
// QC fail routing: use target_node_id from Behavior, not edge_condition
if ($nodeType === 'qc' && isset($qcResult['target_node_id'])) {
    $targetNodeId = $qcResult['target_node_id'];
    
    // Validate target is in allowed rework edges
    if (!$this->isValidReworkTarget($nodeId, $targetNodeId)) {
        throw new \Exception("Invalid rework target: not in allowed edges");
    }
    
    // Route directly (no condition evaluation needed)
    $edge = $this->findReworkEdgeTo($nodeId, $targetNodeId);
    return $this->routeToNode($tokenId, $edge, $operatorId);
}

// Router routing: use edge_condition (system decision)
if ($nodeType === 'router') {
    // Evaluate conditions to find matching edge
    $matchingEdge = $this->evaluateRouterConditions($nodeId, $context);
    return $this->routeToNode($tokenId, $matchingEdge, $operatorId);
}
```

---

## 5️⃣ Benefits of This Policy

| Benefit | Description |
|---------|-------------|
| **Clarity** | Clear separation: System vs Human decisions |
| **Simplicity** | QC graphs don't need complex conditions |
| **Flexibility** | Operators can choose appropriate rework path |
| **Maintainability** | Router conditions are reusable across products |
| **Auditability** | QC decisions logged with operator ID |

---

## 6️⃣ Migration Path

### Existing Graphs with QC edge_condition

If you have existing graphs with `edge_condition` on QC rework edges:

1. **Keep them working** (backward compatible)
2. **Show warning** in Graph Designer
3. **Recommend migration** to plain rework edges + Behavior UI

```php
// Warning message
"⚠️ This QC node uses edge_condition for rework routing.
Consider migrating to plain rework edges + QC Behavior UI
for more flexibility."
```

---

## 7️⃣ Quick Reference

### QC Nodes (Hatthasilpa Workshop)

- ✅ Use plain edges (pass / rework)
- ✅ edge_type = 'rework' for fail paths
- ❌ DO NOT use edge_condition
- ✅ Decision made in Behavior UI

### Router / Option Nodes

- ✅ Use edge_condition for auto-routing
- ✅ Support material/option-based paths
- ✅ Include default edge for fallback
- ✅ Logic visible in graph

---

## 8️⃣ Related Documentation

- [QC_DYNAMIC_REWORK_TARGET.md](./QC_DYNAMIC_REWORK_TARGET.md) - QC Behavior UI design
- [ROUTER_NODE_DESIGN.md](./ROUTER_NODE_DESIGN.md) - Router node patterns
- [CONDITION_EVALUATOR_SPEC.md](../02-specs/CONDITION_EVALUATOR_SPEC.md) - Condition format

---

> **"edge_condition = ของเล่นของ Router/Option Node"**  
> **"QC = โลกของมนุษย์ตัดสินใจ + ระบบคอยกันพลาด"**

