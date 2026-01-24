# Graph Designer Rules - Definitive Guide

**Purpose:** Canonical reference for creating routing graphs in Bellavier ERP  
**Audience:** AI Agents, Developers, Graph Designers  
**Version:** 1.0  
**Date:** 2025-12-02  
**Status:** 🔴 CRITICAL - READ BEFORE CREATING ANY GRAPH

**Based on:**
- Production code analysis (2025-12-02)
- COMPONENT_PARALLEL_FLOW_SPEC.md
- SPEC_QC_SYSTEM.md
- Real graph data (routing_graph, routing_node, routing_edge)

---

## 🚨 **CRITICAL PRINCIPLES**

### **1. START/FINISH Nodes Have NO Behavior**

```sql
✅ CORRECT:
routing_node:
  - node_code: 'START'
  - node_type: 'start'
  - behavior_code: NULL  ← ✅ No behavior!
  
routing_node:
  - node_code: 'FINISH'
  - node_type: 'end'
  - behavior_code: NULL  ← ✅ No behavior!

❌ WRONG:
routing_node:
  - node_code: 'START'
  - node_type: 'start'
  - behavior_code: 'CUT'  ← ❌ Start nodes don't execute behaviors!
```

**Rule:**
- START/FINISH = Control flow nodes (routing only)
- Behavior execution = Operation/QC nodes ONLY

---

### **2. Split/Merge Nodes = Topology Nodes (NO Behavior!)** ⚠️ **CRITICAL**

**❌ WRONG (Common Mistake):**
```sql
routing_node:
  - node_code: 'STITCH_MAIN'
  - node_type: 'operation'
  - behavior_code: 'STITCH'  ← ❌ Split nodes CANNOT have behavior!
  - is_parallel_split: 1
```

**✅ CORRECT (Production Pattern):**

**Parallel Split:**
```sql
routing_node:
  - node_code: 'SPLIT_PARALLEL'
  - node_type: 'split'  ← ✅ Topology node type
  - behavior_code: NULL  ← ✅ NO behavior!
  - is_parallel_split: 1
  
routing_edge (from SPLIT_PARALLEL):
  - 3+ outgoing edges  ← ✅ Multiple branches
```

**Merge:**
```sql
routing_node:
  - node_code: 'MERGE_PARALLEL'
  - node_type: 'join'  ← ✅ Topology node type
  - behavior_code: NULL  ← ✅ NO behavior!
  - is_merge_node: 1
  
routing_edge (to MERGE_PARALLEL):
  - 3+ incoming edges  ← ✅ Multiple branches converge
```

**Rule 2 from COMPONENT_PARALLEL_FLOW_SPEC:**
```sql
-- A node cannot have split/merge flag AND behavior_code
WHERE (is_parallel_split = 1 OR is_merge_node = 1) AND behavior_code IS NOT NULL  -- ❌ INVALID
```

**Key Insight:**
- Split/Merge = Pure topology nodes (routing control only)
- Behaviors execute BEFORE split and AFTER merge
- Example: `STITCH_PIECE → SPLIT → [branches] → MERGE → ASSEMBLY`

---

### **3. Component Mapping (Node Config JSON)**

**⚠️ Schema Limitation:**
```sql
routing_node:
  - produces_component: NULL  ← ❌ Column doesn't exist yet
  - consumes_components: NULL  ← ❌ Column doesn't exist yet
```

**✅ Current Workaround:**
```sql
routing_node:
  - node_config: JSON  ← ✅ Use this for component attributes

Example:
  node_config: '{"produces_component": "BODY"}'
  node_config: '{"consumes_components": ["BODY", "FLAP", "STRAP"]}'
```

**Usage in Code:**
```php
$nodeConfig = json_decode($node['node_config'], true);
$producesComponent = $nodeConfig['produces_component'] ?? null;
$consumesComponents = $nodeConfig['consumes_components'] ?? [];
```

---

### **4. Edge Types - Routing Semantics**

**Available Types:**
```sql
routing_edge.edge_type ENUM('normal', 'rework', 'conditional')
```

**Usage:**

**a) Normal Edge:**
```sql
edge_type: 'normal'  ← Standard flow (happy path, no conditions)
edge_condition: NULL
```

**b) Conditional Edge (⭐ Production Pattern):**
```sql
edge_type: 'conditional'  ← Decision-based routing with conditions
edge_condition: JSON  ← REQUIRED for conditional edges

Example (QC Pass):
  from_node: QC_BODY
  to_node: MERGE_PARALLEL
  edge_type: 'conditional'
  edge_condition: '{"field": "qc_result.status", "operator": "eq", "value": "pass"}'
  edge_label: 'QC ผ่าน'

Example (QC Fail - Rework):
  from_node: QC_BODY
  to_node: STITCH_BODY
  edge_type: 'conditional'
  edge_condition: '{"field": "qc_result.status", "operator": "in", "value": ["fail_minor", "fail_major"]}'
  edge_label: 'Rework (QC ไม่ผ่าน)'
```

**c) Rework Edge (⚠️ Legacy - Backward Compatibility):**
```sql
edge_type: 'rework'  ← Old pattern (still supported but deprecated)
edge_condition: NULL

✅ NEW: Use edge_type='conditional' + edge_condition instead
❌ OLD: edge_type='rework' (no condition evaluation)
```

**⚠️ IMPORTANT:**
- ✅ QC routing uses `edge_type='conditional'` + `edge_condition` (production pattern)
- ⚠️ `edge_type='rework'` still works but is legacy (no condition evaluation)
- ❌ NO 'parallel' edge type (doesn't exist in enum)
- Parallel branches = multiple 'normal' edges from split node

---

## 📋 **Complete Graph Design Pattern**

### **Pattern 1: Sequential Flow (No Parallel)**

```
START (start, no behavior)
  ↓ (normal edge)
OPERATION_1 (operation, STITCH)
  ↓ (normal edge)
OPERATION_2 (operation, EDGE)
  ↓ (normal edge)
QC_CHECK (qc, QC_FINAL)
  ↓ (normal edge)
FINISH (end, no behavior)

+ Rework edge:
  QC_CHECK → OPERATION_2 (rework)
```

**Database:**
```sql
routing_graph:
  - graph_type: 'sequential'

routing_node (5 nodes):
  - START: node_type='start', behavior_code=NULL
  - OPERATION_1: node_type='operation', behavior_code='STITCH'
  - OPERATION_2: node_type='operation', behavior_code='EDGE'
  - QC_CHECK: node_type='qc', behavior_code='QC_FINAL'
  - FINISH: node_type='end', behavior_code=NULL

routing_edge (5 edges):
  - START → OPERATION_1 (normal)
  - OPERATION_1 → OPERATION_2 (normal)
  - OPERATION_2 → QC_CHECK (normal)
  - QC_CHECK → FINISH (normal)
  - QC_CHECK → OPERATION_2 (rework)
```

---

### **Pattern 2: Parallel + Assembly (Component Flow)** ⭐ **Production Pattern**

```
START (start, no behavior)
  ↓
CUT (operation, CUT)
  ↓
STITCH_PIECE (operation, STITCH) ← Execute behavior BEFORE split
  ↓
SPLIT_PARALLEL (split, NO behavior, is_parallel_split=1) ← Topology only!
  ├─→ STITCH_BODY (operation, STITCH, produces_component='BODY') → QC_BODY ─┐
  ├─→ STITCH_FLAP (operation, STITCH, produces_component='FLAP') → QC_FLAP ─┤
  └─→ STITCH_STRAP (operation, STITCH, produces_component='STRAP') → QC_STRAP ─┘
       ↓ (all merge to)
MERGE_PARALLEL (join, NO behavior, is_merge_node=1, consumes_components=['BODY','FLAP','STRAP']) ← Topology only!
  ↓
ASSEMBLY (operation, ASSEMBLY) ← Execute behavior AFTER merge
  ↓
QC_FINAL (qc, QC_FINAL, qc_policy={...})
  ↓
FINISH (end, no behavior)

+ Conditional edges (8):
  - QC_BODY → MERGE_PARALLEL (conditional, qc_result.status='pass')
  - QC_BODY → STITCH_BODY (conditional, qc_result.status IN ['fail_minor','fail_major'])
  - QC_FLAP → MERGE_PARALLEL (conditional, pass)
  - QC_FLAP → STITCH_FLAP (conditional, fail)
  - QC_STRAP → MERGE_PARALLEL (conditional, pass)
  - QC_STRAP → STITCH_STRAP (conditional, fail)
  - QC_FINAL → FINISH (conditional, pass)
  - QC_FINAL → ASSEMBLY (conditional, fail)
```

**Database:**
```sql
routing_graph:
  - graph_type: 'assembly'  ← ✅ Parallel + merge pattern

routing_node (12 nodes):
  - START: node_type='start', behavior_code=NULL
  - CUT: node_type='operation', behavior_code='CUT'
  - STITCH_MAIN: node_type='operation', behavior_code='STITCH', is_parallel_split=1  ← ✅ Split!
  - STITCH_BODY: node_type='operation', behavior_code='STITCH', node_config='{"produces_component":"BODY"}'
  - QC_BODY: node_type='qc', behavior_code='QC_INITIAL'
  - STITCH_FLAP: node_type='operation', behavior_code='STITCH', node_config='{"produces_component":"FLAP"}'
  - QC_FLAP: node_type='qc', behavior_code='QC_INITIAL'
  - STITCH_STRAP: node_type='operation', behavior_code='STITCH', node_config='{"produces_component":"STRAP"}'
  - QC_STRAP: node_type='qc', behavior_code='QC_INITIAL'
  - ASSEMBLY: node_type='operation', behavior_code='ASSEMBLY', is_merge_node=1, node_config='{"consumes_components":["BODY","FLAP","STRAP"]}'  ← ✅ Merge!
  - QC_FINAL: node_type='qc', behavior_code='QC_FINAL'
  - FINISH: node_type='end', behavior_code=NULL

routing_edge (17 edges):
  - 13 normal edges (main flow + parallel branches)
  - 4 rework edges (QC fail routing)
```

---

## 🔑 **Key Rules Summary**

### **Rule 1: Node Types → Behavior Assignment**

| Node Type | Behavior Code | Description |
|-----------|---------------|-------------|
| `start` | ❌ NULL (no behavior) | Entry point (control only) |
| `end` | ❌ NULL (no behavior) | Terminal point (control only) |
| `operation` | ✅ REQUIRED | Work node (STITCH, CUT, EDGE, ASSEMBLY, etc.) |
| `qc` | ✅ REQUIRED | QC node (QC_INITIAL, QC_FINAL, QC_SINGLE, etc.) |
| `decision` | ❌ NULL | Conditional routing (future) |
| `subgraph` | ❌ NULL | Subgraph reference (module template) |
| `wait` | ❌ NULL | Wait/pause node (future) |

**Law:**
- Behavior execution = `operation` or `qc` nodes ONLY
- START/FINISH/decision/wait = Control flow nodes (no behavior)

---

### **Rule 2: Parallel Split → Operation Node + Flag**

**Pattern:**
```sql
routing_node (Split Point):
  - node_type: 'operation'  ← Still execute behavior!
  - behavior_code: 'STITCH'
  - is_parallel_split: 1  ← Flag indicates split
  - Outgoing edges: 3+  ← Multiple target nodes
```

**NOT:**
```sql
❌ node_type: 'split'  ← Doesn't exist in current system
❌ node_type: 'split_parallel'  ← Never existed
```

**Physical Meaning:**
- Worker completes STITCH_MAIN (เย็บหลัก)
- System spawns 3 component tokens (BODY, FLAP, STRAP)
- Each component moves to respective branch

---

### **Rule 3: Merge → Operation Node + Flag**

**Pattern:**
```sql
routing_node (Merge Point):
  - node_type: 'operation'  ← Still execute behavior!
  - behavior_code: 'ASSEMBLY'
  - is_merge_node: 1  ← Flag indicates merge
  - Incoming edges: 3+  ← Multiple source nodes
  - node_config: '{"consumes_components": ["BODY","FLAP","STRAP"]}'
```

**NOT:**
```sql
❌ node_type: 'merge'  ← Doesn't exist in current system
❌ node_type: 'join'  ← Wrong (join != merge in this context)
```

**Physical Meaning:**
- System waits for all 3 components to complete (QC pass)
- Final token re-activated at ASSEMBLY node
- Worker assembles components from same tray

---

### **Rule 4: Component Attributes → node_config JSON**

**⚠️ No Dedicated Columns Yet:**
```sql
routing_node:
  - produces_component: NULL  ← Column doesn't exist
  - consumes_components: NULL  ← Column doesn't exist
```

**✅ Use node_config Workaround:**
```sql
-- For component-producing nodes:
node_config: '{"produces_component": "BODY"}'

-- For component-consuming nodes (assembly):
node_config: '{"consumes_components": ["BODY", "FLAP", "STRAP"]}'
```

**Code Access:**
```php
$config = json_decode($node['node_config'], true) ?? [];
$producesComponent = $config['produces_component'] ?? null;
$consumesComponents = $config['consumes_components'] ?? [];
```

---

### **Rule 5: Rework Routing → edge_type='rework'**

**Pattern:**
```sql
routing_edge:
  - from_node_id: <QC node>
  - to_node_id: <Work node>
  - edge_type: 'rework'  ← ✅ Indicates QC fail routing
  - edge_label: 'Rework (QC ไม่ผ่าน)'
```

**Example:**
```
QC_BODY (qc)
  ├─→ ASSEMBLY (normal edge - QC pass)
  └─→ STITCH_BODY (rework edge - QC fail)
```

**Runtime Logic:**
```php
if ($qcDecision === 'pass') {
    // Follow normal edge (QC_BODY → ASSEMBLY)
} elseif ($qcDecision === 'fail') {
    // Follow rework edge (QC_BODY → STITCH_BODY)
}
```

---

## 📐 **Graph Design Checklist**

### **Before Creating Graph:**

- [ ] Define graph_type ('sequential' or 'assembly')
- [ ] Identify START node (exactly 1, node_type='start', no behavior)
- [ ] Identify FINISH node (exactly 1, node_type='end', no behavior)
- [ ] Map all operation nodes (node_type='operation', behavior_code required)
- [ ] Map all QC nodes (node_type='qc', behavior_code required)
- [ ] Identify parallel split points (operation nodes with multiple outgoing edges)
- [ ] Identify merge points (operation nodes with multiple incoming edges)
- [ ] Define component mapping (produces_component, consumes_components in node_config)
- [ ] Define rework edges (edge_type='rework' for QC fail routes)

### **Node Creation:**

```sql
INSERT INTO routing_node (
    id_graph,
    sequence_no,
    node_code,
    node_name,
    node_type,  ← 'start'|'operation'|'qc'|'end'
    behavior_code,  ← NULL for start/end, REQUIRED for operation/qc
    is_parallel_split,  ← 1 if split point
    is_merge_node,  ← 1 if merge point
    node_config,  ← JSON for produces_component / consumes_components
    position_x,  ← Visual layout (optional)
    position_y,  ← Visual layout (optional)
    created_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
```

### **Edge Creation:**

```sql
INSERT INTO routing_edge (
    id_graph,  ← ✅ REQUIRED! (NOT NULL constraint)
    from_node_id,
    to_node_id,
    edge_type,  ← 'normal'|'rework'|'conditional'
    edge_label,  ← Human-readable label
    created_at
) VALUES (?, ?, ?, ?, ?, NOW())
```

**Validation:**
- [ ] Every edge has id_graph (required field)
- [ ] from_node_id exists in routing_node
- [ ] to_node_id exists in routing_node
- [ ] edge_type is valid enum value
- [ ] Rework edges only from QC nodes

---

## 🎯 **Node Type Reference**

### **Available Node Types:**

```sql
node_type ENUM(
    'start',       -- Entry point (1 per graph, no behavior)
    'operation',   -- Work node (behavior required)
    'split',       -- ❌ LEGACY (don't use)
    'join',        -- ❌ LEGACY (don't use)
    'decision',    -- Decision node (future, no behavior yet)
    'end',         -- Terminal point (1+ per graph, no behavior)
    'qc',          -- QC node (behavior required)
    'wait',        -- Wait node (future, no behavior yet)
    'subgraph',    -- Subgraph reference (no behavior, module template)
    'system'       -- System node (future, no behavior yet)
)
```

**Usage Frequency (Current):**
- ✅ `start` - Always 1 per graph
- ✅ `operation` - Most common (work nodes)
- ✅ `qc` - QC inspection nodes
- ✅ `end` - Always 1+ per graph
- ⚠️ `subgraph` - Module templates (advanced)
- ❌ `split`/`join` - Legacy (replaced by is_parallel_split/is_merge_node flags)
- 🔮 `decision`/`wait`/`system` - Future use

---

## 🏭 **Real-World Example: Leather Bag Assembly**

### **Graph Metadata:**
```sql
routing_graph:
  - code: 'BAG_COMPONENT_FLOW_V2'
  - name: 'Leather Bag - Component Flow (Correct Pattern)'
  - graph_type: 'assembly'
  - status: 'published'
```

### **Nodes (12):**

| Seq | Node Code | Node Type | Behavior | Split | Merge | Config |
|-----|-----------|-----------|----------|-------|-------|--------|
| 1 | START | start | NULL | 0 | 0 | NULL |
| 2 | CUT_BATCH | operation | CUT | 0 | 0 | NULL |
| 3 | STITCH_MAIN | operation | STITCH | **1** | 0 | NULL |
| 4 | STITCH_BODY | operation | STITCH | 0 | 0 | {"produces_component":"BODY"} |
| 5 | QC_BODY | qc | QC_INITIAL | 0 | 0 | NULL |
| 6 | STITCH_FLAP | operation | STITCH | 0 | 0 | {"produces_component":"FLAP"} |
| 7 | QC_FLAP | qc | QC_INITIAL | 0 | 0 | NULL |
| 8 | STITCH_STRAP | operation | STITCH | 0 | 0 | {"produces_component":"STRAP"} |
| 9 | QC_STRAP | qc | QC_INITIAL | 0 | 0 | NULL |
| 10 | ASSEMBLY | operation | ASSEMBLY | 0 | **1** | {"consumes_components":["BODY","FLAP","STRAP"]} |
| 11 | QC_FINAL | qc | QC_FINAL | 0 | 0 | NULL |
| 12 | FINISH | end | NULL | 0 | 0 | NULL |

### **Edges (17):**

**Normal Flow (13 edges):**
```
START → CUT_BATCH
CUT_BATCH → STITCH_MAIN
STITCH_MAIN → STITCH_BODY (parallel branch A)
STITCH_MAIN → STITCH_FLAP (parallel branch B)
STITCH_MAIN → STITCH_STRAP (parallel branch C)
STITCH_BODY → QC_BODY
QC_BODY → ASSEMBLY (merge)
STITCH_FLAP → QC_FLAP
QC_FLAP → ASSEMBLY (merge)
STITCH_STRAP → QC_STRAP
QC_STRAP → ASSEMBLY (merge)
ASSEMBLY → QC_FINAL
QC_FINAL → FINISH
```

**Rework Flow (4 edges):**
```
QC_BODY → STITCH_BODY (rework)
QC_FLAP → STITCH_FLAP (rework)
QC_STRAP → STITCH_STRAP (rework)
QC_FINAL → ASSEMBLY (rework)
```

---

## ⚠️ **Common Mistakes**

### **Mistake 1: Adding Behavior to START/FINISH**
```sql
❌ WRONG:
routing_node:
  - node_code: 'START'
  - node_type: 'start'
  - behavior_code: 'CUT'  ← NO! Start nodes don't execute behaviors

✅ CORRECT:
routing_node:
  - node_code: 'START'
  - node_type: 'start'
  - behavior_code: NULL
  
routing_node (next node):
  - node_code: 'CUT_BATCH'
  - node_type: 'operation'
  - behavior_code: 'CUT'  ← Behavior goes here
```

### **Mistake 2: Using Legacy Split/Merge Types**
```sql
❌ WRONG:
routing_node:
  - node_type: 'split'  ← Legacy pattern
  - behavior_code: NULL

✅ CORRECT:
routing_node:
  - node_type: 'operation'
  - behavior_code: 'STITCH'
  - is_parallel_split: 1  ← Use flag instead
```

### **Mistake 3: Missing id_graph in Edges**
```sql
❌ WRONG:
INSERT INTO routing_edge (from_node_id, to_node_id, edge_type)
VALUES (?, ?, ?)  ← Missing id_graph!

✅ CORRECT:
INSERT INTO routing_edge (id_graph, from_node_id, to_node_id, edge_type)
VALUES (?, ?, ?, ?)  ← id_graph is NOT NULL
```

### **Mistake 4: Using 'parallel' Edge Type**
```sql
❌ WRONG:
routing_edge:
  - edge_type: 'parallel'  ← Doesn't exist in enum!

✅ CORRECT:
routing_edge:
  - edge_type: 'normal'  ← Parallel indicated by split node flag
```

### **Mistake 5: Missing Component Mapping**
```sql
❌ WRONG:
routing_node (STITCH_BODY):
  - behavior_code: 'STITCH'
  - node_config: NULL  ← Missing component info!

✅ CORRECT:
routing_node (STITCH_BODY):
  - behavior_code: 'STITCH'
  - node_config: '{"produces_component": "BODY"}'  ← Component mapping
```

---

## 📊 **Validation Rules**

### **Graph-Level Validation:**
- [ ] Exactly 1 START node (node_type='start')
- [ ] At least 1 FINISH node (node_type='end')
- [ ] All operation/qc nodes have behavior_code
- [ ] All start/end nodes have behavior_code=NULL
- [ ] graph_type matches pattern ('sequential' or 'assembly')

### **Parallel Split Validation:**
- [ ] Split node: node_type='operation' + is_parallel_split=1
- [ ] Split node: 2+ outgoing edges (all edge_type='normal')
- [ ] Target nodes: have produces_component in node_config
- [ ] Component codes unique per split group

### **Merge Validation:**
- [ ] Merge node: node_type='operation' + is_merge_node=1
- [ ] Merge node: 2+ incoming edges
- [ ] Merge node: has consumes_components in node_config
- [ ] Component codes match upstream produces_component

### **Rework Edge Validation:**
- [ ] from_node: node_type='qc' (only QC nodes can rework)
- [ ] to_node: node_type='operation' (rework to work node)
- [ ] edge_type: 'rework'
- [ ] Rework creates loop (QC → Work → QC)

---

## 🛠️ **Migration Template**

**Use this template for creating seed graphs:**

```php
<?php
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    // 1. Create graph
    $graphCode = 'YOUR_GRAPH_CODE';
    $graphName = 'Your Graph Name';
    $graphType = 'sequential'; // or 'assembly'
    
    $stmt = $db->prepare("
        INSERT INTO routing_graph (code, name, graph_type, status, created_at) 
        VALUES (?, ?, ?, 'published', NOW())
    ");
    $stmt->bind_param('sss', $graphCode, $graphName, $graphType);
    $stmt->execute();
    $graphId = $db->insert_id;
    $stmt->close();
    
    // 2. Create nodes
    $nodes = [
        // START node (required)
        ['code' => 'START', 'name' => 'เริ่มต้น', 'type' => 'start', 'behavior' => null],
        
        // Operation nodes
        ['code' => 'OP1', 'name' => 'งาน 1', 'type' => 'operation', 'behavior' => 'STITCH'],
        
        // QC nodes
        ['code' => 'QC1', 'name' => 'ตรวจสอบ', 'type' => 'qc', 'behavior' => 'QC_FINAL'],
        
        // FINISH node (required)
        ['code' => 'FINISH', 'name' => 'เสร็จสิ้น', 'type' => 'end', 'behavior' => null],
    ];
    
    $nodeIdMap = [];
    foreach ($nodes as $i => $n) {
        if ($n['behavior'] === null) {
            $stmt = $db->prepare("
                INSERT INTO routing_node (id_graph, sequence_no, node_code, node_name, node_type, created_at)
                VALUES (?, ?, ?, ?, ?, NOW())
            ");
            $stmt->bind_param('iisss', $graphId, $i, $n['code'], $n['name'], $n['type']);
        } else {
            $stmt = $db->prepare("
                INSERT INTO routing_node (id_graph, sequence_no, node_code, node_name, node_type, behavior_code, created_at)
                VALUES (?, ?, ?, ?, ?, ?, NOW())
            ");
            $stmt->bind_param('iissss', $graphId, $i, $n['code'], $n['name'], $n['type'], $n['behavior']);
        }
        $stmt->execute();
        $nodeIdMap[$n['code']] = $db->insert_id;
        $stmt->close();
    }
    
    // 3. Create edges
    $edges = [
        ['from' => 'START', 'to' => 'OP1', 'type' => 'normal', 'label' => 'เริ่ม'],
        ['from' => 'OP1', 'to' => 'QC1', 'type' => 'normal', 'label' => 'ส่ง QC'],
        ['from' => 'QC1', 'to' => 'FINISH', 'type' => 'normal', 'label' => 'QC ผ่าน'],
        ['from' => 'QC1', 'to' => 'OP1', 'type' => 'rework', 'label' => 'Rework'],
    ];
    
    foreach ($edges as $e) {
        $stmt = $db->prepare("
            INSERT INTO routing_edge (id_graph, from_node_id, to_node_id, edge_type, edge_label, created_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ");
        $stmt->bind_param('iiiss', $graphId, $nodeIdMap[$e['from']], $nodeIdMap[$e['to']], $e['type'], $e['label']);
        $stmt->execute();
        $stmt->close();
    }
};
```

---

## 🔍 **Troubleshooting**

### **Error: "Unknown column 'graph_code'"**
```sql
❌ WRONG: WHERE graph_code = ?
✅ CORRECT: WHERE code = ?
```

### **Error: "Unknown column 'graph_name'"**
```sql
❌ WRONG: INSERT INTO routing_graph (graph_name, ...) VALUES (?, ...)
✅ CORRECT: INSERT INTO routing_graph (name, ...) VALUES (?, ...)
```

### **Error: "Field 'id_graph' doesn't have a default value"**
```sql
❌ WRONG:
INSERT INTO routing_edge (from_node_id, to_node_id, edge_type) VALUES (?, ?, ?)

✅ CORRECT:
INSERT INTO routing_edge (id_graph, from_node_id, to_node_id, edge_type) VALUES (?, ?, ?, ?)
```

### **Error: "Data truncated for column 'edge_type'"**
```sql
❌ WRONG: edge_type: 'parallel'  ← Not in enum!
✅ CORRECT: edge_type: 'normal'|'rework'|'conditional'
```

### **Error: "Data truncated for column 'node_type'"**
```sql
❌ WRONG: node_type: 'split'|'merge'|'split_parallel'  ← Legacy/invalid
✅ CORRECT: node_type: 'start'|'operation'|'qc'|'end'
```

---

## 📚 **References**

**Core Specs:**
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Component token architecture
- `docs/developer/03-superdag/03-specs/SPEC_QC_SYSTEM.md` - QC routing and rework edges
- `docs/super_dag/01-concepts/COMPONENT_PARALLEL_FLOW.md` - Conceptual overview

**Database Schema:**
- `database/tenant_migrations/0001_init_tenant_schema_v2.php` - routing_graph, routing_node, routing_edge definitions
- Table: `routing_graph` - Graph metadata
- Table: `routing_node` - Node definitions (includes is_parallel_split, is_merge_node flags)
- Table: `routing_edge` - Edge connections (includes edge_type enum)

**Example Graphs:**
- Graph ID 1: TOTE_PRODUCTION_V1 (assembly type)
- Graph ID 1940: BAG_COMPONENT_FLOW_V2 (correct pattern example)

---

## 🎓 **Learning Path for Graph Designers**

**Step 1: Understand Node Types (30 min)**
- Read this document: Section "Node Type Reference"
- Key: START/FINISH = no behavior, operation/qc = has behavior

**Step 2: Understand Parallel Pattern (20 min)**
- Read: "Rule 2: Parallel Split" + "Rule 3: Merge"
- Key: No split/merge node types, use flags instead

**Step 3: Understand Component Mapping (15 min)**
- Read: "Rule 4: Component Attributes"
- Key: Use node_config JSON (produces_component, consumes_components)

**Step 4: Understand QC Routing (20 min)**
- Read: "Rule 5: Rework Routing" + SPEC_QC_SYSTEM.md
- Key: edge_type='rework' for QC fail paths

**Step 5: Practice (1-2 hours)**
- Study: BAG_COMPONENT_FLOW_V2 (Graph ID 1940)
- Create: Your own test graph using migration template
- Verify: Check graph visualization in UI

**Total Time:** 2-3 hours (comprehensive understanding)

---

## ✅ **Quick Reference Card**

| Element | Rule | Example |
|---------|------|---------|
| **START node** | node_type='start', behavior=NULL | START → (no behavior) |
| **FINISH node** | node_type='end', behavior=NULL | FINISH → (no behavior) |
| **Operation node** | node_type='operation', behavior=REQUIRED | STITCH → (execute STITCH) |
| **QC node** | node_type='qc', behavior=REQUIRED | QC_FINAL → (execute QC_FINAL) |
| **Parallel split** | operation + is_parallel_split=1 | STITCH_MAIN (3 outgoing edges) |
| **Merge** | operation + is_merge_node=1 | ASSEMBLY (3 incoming edges) |
| **Component produce** | node_config='{"produces_component":"BODY"}' | STITCH_BODY → produces BODY |
| **Component consume** | node_config='{"consumes_components":["BODY","FLAP"]}' | ASSEMBLY → needs BODY+FLAP |
| **Normal edge** | edge_type='normal' | STITCH → QC (happy path) |
| **Rework edge** | edge_type='rework' | QC → STITCH (fail path) |

---

**Last Updated:** 2025-12-02  
**Author:** System Audit (based on production code + specs)  
**Status:** ✅ Production-Ready Reference

---

## ✅ **Resolved Validation Issues**

### **Issue 1: Parallel Split → Merge Detection** ✅ FIXED (Dec 4, 2025)

**Original Problem:**
```
Validator checked only DIRECT neighbors (1 hop) for merge nodes.
Pattern: SPLIT_OP → WORK → QC → MERGE_OP failed validation falsely.
```

**Error Code:** `PARALLEL_SPLIT_NO_MERGE` (false positive)

**Root Cause:**
- **File:** `source/BGERP/Dag/GraphValidationEngine.php`
- **Lines:** 1133-1171 (validateParallelSemantic → Rule 4.2.3)
- **Bug:** Only checked immediate targets, not full downstream path

**Fix Applied (Dec 4, 2025):**
```php
// New method added: hasMergeNodeDownstream()
// Uses BFS traversal to find merge nodes anywhere downstream

// File: GraphValidationEngine.php (lines 1560-1610)
private function hasMergeNodeDownstream(string $startNodeId, array $nodes, array $edges, array $nodeMap): bool
{
    // BFS traversal to find merge node
    $outgoingMap = [];
    foreach ($edges as $edge) { ... }
    
    $visited = [$startNodeId => true];
    $queue = $outgoingMap[$startNodeId] ?? [];
    
    while (!empty($queue)) {
        $currentId = array_shift($queue);
        if (isset($visited[$currentId])) continue;
        $visited[$currentId] = true;
        
        // Check if this node is a merge node
        $currentNode = $nodeMap[$currentId] ?? null;
        if (is_array($currentNode) && ($currentNode['is_merge_node'] ?? false) === true) {
            return true;
        }
        // Add downstream neighbors to queue...
    }
    return false;
}
```

**Verification Tests (All Passing):**
```
✅ Test 1: Split→Op1/Op2→Merge (2 hops) - No error
✅ Test 2: Split→Op1/Op2→End1/End2 (NO merge) - Correct error
✅ Test 3: Split→Op→QC→MERGE (3 hops) - No error
```

**Status:** ✅ FIXED  
**Fixed By:** Opus 4.5 (Dec 4, 2025)  
**Test File:** `tests/manual/test_bfs_merge_fix.php`

---

### **Issue 2: Default Edge Warning (Minor)**

**Problem:**
```
Validator warns: "Decision node QC_X should have default edge"
Even when is_default=1 is set on edges
```

**Warning Code:** `DECISION_NODE_MISSING_DEFAULT`

**Status:** 🟡 Minor (warnings only, not blocking)  
**Notes:** May be validation display issue or additional requirements

---

## ✅ **Current Status (Dec 4, 2025)**

All major validation issues have been resolved:

| Issue | Status | Notes |
|-------|--------|-------|
| Parallel Split → Merge Detection | ✅ FIXED | BFS traversal now finds merge nodes at any depth |
| Default Edge Warning | 🟡 Minor | Warnings only, not blocking |

**For Graph Creation:**
- ✅ Use patterns from this document
- ✅ Parallel split patterns now validate correctly
- ✅ Unit tests + Integration tests available
- ✅ Manual testing in Graph Designer works

---

## 🏗️ **Validation Architecture (Updated Dec 2025)**

### **Single Source of Truth: GraphValidationEngine**

As of December 2025 (Task 27.10.2-27.10.3), ALL graph validation MUST go through:

| Component | File | Method |
|-----------|------|--------|
| **Primary Validator** | `source/BGERP/Dag/GraphValidationEngine.php` | `validate($nodes, $edges, $options)` |
| **Error Codes** | `source/BGERP/Dag/ValidationErrorCodes.php` | Constants + getMessage() |

### **Deprecated Services**

The following are **DEPRECATED** and will be removed in a future version:

| Service | Method | Replacement |
|---------|--------|-------------|
| `DAGValidationService` | `validateGraph()` | `GraphValidationEngine::validate()` |
| `DAGValidationService` | `canPublishGraph()` | `GraphValidationEngine::validate(['mode'=>'publish'])` |
| `dag_routing_api.php` | Inline validation | **REMOVED** |

### **Validation Modes**

| Mode | Usage | Behavior |
|------|-------|----------|
| `draft` (default) | UI validation | Warnings allowed |
| `publish` | Publishing | Strict validation, temp IDs blocked |

```php
// Draft mode (UI)
$result = $engine->validate($nodes, $edges, ['mode' => 'draft']);

// Publish mode (strict)
$result = $engine->validate($nodes, $edges, ['mode' => 'publish', 'strict' => true]);
```

### **Edge Pattern Recognition**

GraphValidationEngine recognizes **BOTH** patterns for rework edges:

```php
// Pattern 1: Legacy
['edge_type' => 'rework']

// Pattern 2: Modern (conditional with fail condition)
[
    'edge_type' => 'conditional',
    'edge_condition' => '{"type":"token_property","property":"qc_result.status","operator":"in","value":["fail_minor","fail_major"]}'
]
```

Both patterns are excluded from cycle detection.

### **Error Code Structure**

```php
use BGERP\Dag\ValidationErrorCodes;

// Structural: GRAPH_xxx
ValidationErrorCodes::START_NODE_MISSING     // 'GRAPH_001_START_MISSING'
ValidationErrorCodes::CYCLE_DETECTED         // 'GRAPH_005_CYCLE_DETECTED'

// Semantic: SEM_xxx  
ValidationErrorCodes::PARALLEL_SPLIT_NO_MERGE // 'SEM_001_PARALLEL_NO_MERGE'
ValidationErrorCodes::QC_MISSING_FAILURE_PATH // 'SEM_003_QC_NO_FAIL_PATH'

// Publish: PUB_xxx
ValidationErrorCodes::TEMP_NODE_ID           // 'PUB_001_TEMP_ID'
ValidationErrorCodes::MISSING_WORK_CENTER    // 'PUB_003_NO_WORK_CENTER'

// Condition: COND_xxx
ValidationErrorCodes::CONDITION_MISSING_TYPE // 'COND_001_MISSING_TYPE'

// Warnings: WARN_xxx
ValidationErrorCodes::REWORK_CYCLE_WARNING   // 'WARN_001_REWORK_CYCLE'
```

