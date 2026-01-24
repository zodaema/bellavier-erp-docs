# Graph Linter Rules Specification

> **Last Updated:** 2025-12-04  
> **Status:** 📋 DRAFT  
> **Priority:** 🔴 HIGH  
> **Depends On:** QC_REWORK_PHILOSOPHY_V2.md, COMPONENT_CATALOG_SPEC.md  
> **Version:** v2.0 (Anchor Model Aligned)

---

## 🎯 Purpose

**"กันกราฟที่โง่แต่ไม่รู้ตัวเข้าสู่ระบบ"**

```
┌─────────────────────────────────────────────────────────────────┐
│              GRAPH LINTER: WHY IT MATTERS                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ WITHOUT LINTER:                                             │
│     • ลืมใส่ Component Node ใต้ split                           │
│     • ใส่ Component Node ผิดที่ (หลัง merge)                    │
│     • QC Node วางใน branch ที่ไม่มี operation                   │
│     → กราฟพังตอน runtime, debug ยาก                            │
│                                                                 │
│  ✅ WITH LINTER:                                                │
│     • ตรวจทุกครั้งก่อน save/publish                             │
│     • Block กราฟที่ break concept                              │
│     • แจ้ง warning พร้อมวิธีแก้                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Rule Categories

| Category | Severity | Description |
|----------|----------|-------------|
| **STRUCTURAL** | 🔴 ERROR | โครงสร้างกราฟผิดพื้นฐาน (block save) |
| **COMPONENT** | 🔴 ERROR | Component Node ใช้ผิดที่/ผิดวิธี |
| **QC** | 🟡 WARNING | QC Node configuration issues |
| **BEST_PRACTICE** | 🟢 INFO | คำแนะนำ (ไม่ block) |

---

## 🔴 STRUCTURAL RULES

### RULE S1: Parallel split ต้องมี Component Nodes ทุกแขน

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: S1_PARALLEL_NEEDS_COMPONENT_ANCHORS                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ INVALID:                                                    │
│     SPLIT → CUT_STRAP → ...                                     │
│           → CUT_BODY → ...                                      │
│     (ไม่มี Component Node)                                      │
│                                                                 │
│  ✅ VALID:                                                      │
│     SPLIT → [COMPONENT: STRAP] → CUT_STRAP → ...               │
│           → [COMPONENT: BODY] → CUT_BODY → ...                 │
│                                                                 │
│  Message: "Parallel split node '{node_code}' requires           │
│           Component Node anchors for each branch"               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation:**

```php
private function validateParallelHasComponentAnchors(array $node, array $nodes, array $edges): array
{
    $errors = [];
    
    if ($node['is_parallel_split'] ?? false) {
        // Get immediate children
        $children = $this->getDirectChildren($node['id_node'], $edges, $nodes);
        
        foreach ($children as $child) {
            if ($child['node_type'] !== 'component') {
                $errors[] = [
                    'code' => 'S1_PARALLEL_NEEDS_COMPONENT_ANCHORS',
                    'severity' => 'error',
                    'node_id' => $node['id_node'],
                    'message' => "Parallel split '{$node['node_code']}' branch to '{$child['node_code']}' must start with Component Node"
                ];
            }
        }
        
        // Must have at least 2 component children
        $componentChildren = array_filter($children, fn($c) => $c['node_type'] === 'component');
        if (count($componentChildren) < 2) {
            $errors[] = [
                'code' => 'S1_PARALLEL_INSUFFICIENT_COMPONENTS',
                'severity' => 'error',
                'node_id' => $node['id_node'],
                'message' => "Parallel split '{$node['node_code']}' must have at least 2 component branches"
            ];
        }
    }
    
    return $errors;
}
```

---

### RULE S2: Component Node ห้ามอยู่หลัง Assembly/Merge

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: S2_COMPONENT_BEFORE_ASSEMBLY                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ INVALID:                                                    │
│     MERGE → ASSEMBLY → [COMPONENT: STRAP]                       │
│     (Component หลัง assembly ไม่มีความหมาย)                     │
│                                                                 │
│  ✅ VALID:                                                      │
│     [COMPONENT: STRAP] → ... → MERGE → ASSEMBLY                 │
│     (Component ก่อน assembly)                                   │
│                                                                 │
│  Message: "Component node '{node_code}' cannot appear           │
│           after assembly/merge node"                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation:**

```php
private function validateComponentBeforeAssembly(array $node, array $nodes, array $edges): array
{
    $errors = [];
    
    if ($node['node_type'] === 'component') {
        // Check if any upstream node is merge/assembly
        $upstreamNodes = $this->getUpstreamNodes($node['id_node'], $edges, $nodes);
        
        foreach ($upstreamNodes as $upstream) {
            if ($upstream['is_merge_node'] || $upstream['node_type'] === 'assembly') {
                $errors[] = [
                    'code' => 'S2_COMPONENT_AFTER_ASSEMBLY',
                    'severity' => 'error',
                    'node_id' => $node['id_node'],
                    'message' => "Component node '{$node['node_code']}' cannot appear after merge/assembly node '{$upstream['node_code']}'"
                ];
            }
        }
    }
    
    return $errors;
}
```

---

### RULE S3: QC Node ต้องมี Operation Upstream

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: S3_QC_NEEDS_UPSTREAM_OPERATION                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ INVALID:                                                    │
│     [COMPONENT: STRAP] → QC_STRAP                               │
│     (ไม่มี operation ก่อน QC)                                   │
│                                                                 │
│  ✅ VALID:                                                      │
│     [COMPONENT: STRAP] → CUT_STRAP → EDGE_STRAP → QC_STRAP     │
│     (มี operation ก่อน QC)                                      │
│                                                                 │
│  Message: "QC node '{node_code}' has no upstream operation      │
│           nodes in the same component branch"                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation:**

```php
private function validateQCHasUpstreamOperation(array $node, array $nodes, array $edges): array
{
    $errors = [];
    
    if ($node['node_type'] === 'qc') {
        // Find component anchor for this QC
        $anchor = $this->findComponentAnchor($node['id_node'], $nodes, $edges);
        
        if ($anchor) {
            // Get nodes between anchor and QC
            $nodesInBranch = $this->getNodesBetween($anchor['id_node'], $node['id_node'], $nodes, $edges);
            
            // Check if any are operation nodes
            $hasOperation = false;
            foreach ($nodesInBranch as $branchNode) {
                if ($branchNode['node_type'] === 'operation') {
                    $hasOperation = true;
                    break;
                }
            }
            
            if (!$hasOperation) {
                $errors[] = [
                    'code' => 'S3_QC_NO_UPSTREAM_OPERATION',
                    'severity' => 'error',
                    'node_id' => $node['id_node'],
                    'message' => "QC node '{$node['node_code']}' has no upstream operation nodes in component anchor '{$anchor['anchor_slot']}'"
                ];
            }
        }
    }
    
    return $errors;
}
```

---

### RULE S4: Merge Node component count mismatch

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: S4_MERGE_COMPONENT_COUNT                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ INVALID:                                                    │
│     Merge expects: [BODY, STRAP, FLAP]                          │
│     Graph defines: [BODY, STRAP] (ขาด FLAP)                     │
│                                                                 │
│  ✅ VALID:                                                      │
│     Merge expects: [BODY, STRAP, FLAP]                          │
│     Graph defines: [BODY, STRAP, FLAP] (ครบ)                    │
│                                                                 │
│  Message: "Merge node '{node_code}' expects 3 components        │
│           but graph only defines 2 component branches"          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation:**

```php
private function validateMergeComponentCount(array $node, array $nodes, array $edges): array
{
    $errors = [];
    
    if ($node['is_merge_node'] ?? false) {
        $expectedComponents = json_decode($node['expected_components'] ?? '[]', true);
        
        if (!empty($expectedComponents)) {
            // Find corresponding split
            $split = $this->findCorrespondingSplit($node['id_node'], $nodes, $edges);
            
            if ($split) {
                // Get component nodes after split
                $componentNodes = $this->getComponentNodesAfterSplit($split['id_node'], $nodes, $edges);
                $actualSlots = array_column($componentNodes, 'anchor_slot');
                
                $missing = array_diff($expectedSlots, $actualSlots);
                $extra = array_diff($actualSlots, $expectedSlots);
                
                if (!empty($missing)) {
                    $errors[] = [
                        'code' => 'S4_MERGE_MISSING_COMPONENTS',
                        'severity' => 'error',
                        'node_id' => $node['id_node'],
                        'message' => "Merge node '{$node['node_code']}' missing components: " . implode(', ', $missing)
                    ];
                }
                
                if (!empty($extra)) {
                    $errors[] = [
                        'code' => 'S4_MERGE_EXTRA_COMPONENTS',
                        'severity' => 'warning',
                        'node_id' => $node['id_node'],
                        'message' => "Merge node '{$node['node_code']}' has unexpected components: " . implode(', ', $extra)
                    ];
                }
            }
        }
    }
    
    return $errors;
}
```

---

## 🔴 COMPONENT RULES

### RULE C1: Component Node ต้องมี anchor_slot (Anchor Model v2)

> **Note:** ตาม Anchor Model, Graph Designer ใช้ `anchor_slot` ไม่ใช่ `component_code`  
> การ validate catalog code ทำที่ mapping layer แทน

```php
private function validateComponentAnchorSlot(array $node): array
{
    $errors = [];
    
    if ($node['node_type'] === 'component') {
        $slot = $node['anchor_slot'] ?? null;
        
        if (empty($slot)) {
            $errors[] = [
                'code' => 'C1_ANCHOR_SLOT_REQUIRED',
                'severity' => 'error',
                'message' => "Component node '{$node['node_code']}' must have anchor_slot"
            ];
        }
        
        // anchor_slot format validation (optional: enforce naming convention)
        if ($slot && !preg_match('/^[A-Z][A-Z0-9_]*$/', $slot)) {
            $errors[] = [
                'code' => 'C1_ANCHOR_SLOT_FORMAT',
                'severity' => 'warning',
                'message' => "Anchor slot '{$slot}' should use UPPER_SNAKE_CASE format"
            ];
        }
    }
    
    return $errors;
}
```

### RULE C2: No duplicate anchor_slot in graph

> **Note:** Same graph cannot have two component nodes with the same anchor_slot

```php
private function validateUniqueAnchorSlots(array $nodes): array
{
    $errors = [];
    $seen = [];
    
    foreach ($nodes as $node) {
        if ($node['node_type'] === 'component') {
            $slot = $node['anchor_slot'] ?? null;
            if ($slot && isset($seen[$slot])) {
                $errors[] = [
                    'code' => 'C2_DUPLICATE_ANCHOR_SLOT',
                    'severity' => 'error',
                    'message' => "Anchor slot '{$slot}' used by both '{$seen[$slot]}' and '{$node['node_code']}'"
                ];
            }
            if ($slot) {
                $seen[$slot] = $node['node_code'];
            }
        }
    }
    
    return $errors;
}
```

### RULE C3: Mapping Validation (at Publish/Configure)

> **Note:** This rule runs when graph is configured for a product, not at design time

```php
private function validateComponentMappings(int $graphId): array
{
    $errors = [];
    
    // Get all anchor_slots in graph
    $slots = $this->getAnchorSlotsInGraph($graphId);
    
    // Get all mappings
    $mappings = $this->getComponentMappings($graphId);
    $mappedSlots = array_column($mappings, 'anchor_slot');
    
    // Check all slots are mapped
    foreach ($slots as $slot) {
        if (!in_array($slot, $mappedSlots)) {
            $errors[] = [
                'code' => 'C3_UNMAPPED_ANCHOR_SLOT',
                'severity' => 'error',
                'message' => "Anchor slot '{$slot}' has no component_code mapping"
            ];
        }
    }
    
    // Check all mapped codes exist in catalog
    foreach ($mappings as $mapping) {
        if (!$this->isValidCatalogCode($mapping['component_code'])) {
            $errors[] = [
                'code' => 'C3_INVALID_COMPONENT_CODE',
                'severity' => 'error',
                'message' => "Component code '{$mapping['component_code']}' for slot '{$mapping['anchor_slot']}' not found in catalog"
            ];
        }
    }
    
    return $errors;
}
```

---

## 🔴 QC RULES

> **Note:** ตาม QC V2 Philosophy, QC เป็น Human-judgment node  
> ไม่ใช่ automated routing node — ดังนั้น edge_condition บน QC = ERROR

### RULE Q1: QC Node ห้ามใช้ edge_condition (ERROR)

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: Q1_QC_NO_EDGE_CONDITION                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ INVALID:                                                    │
│     QC_BODY → edge_condition: {status == 'fail'}                │
│     (QC ใช้ edge_condition = ขัด QC V2 Philosophy)              │
│                                                                 │
│  ✅ VALID:                                                      │
│     QC_BODY → plain edges (pass/rework)                         │
│     Rework target เลือกผ่าน Behavior UI                         │
│                                                                 │
│  Message: "QC node MUST NOT use edge_condition.                 │
│           Use QC Behavior UI to select rework target."          │
│                                                                 │
│  See: EDGE_CONDITION_USAGE_POLICY.md                            │
│       "edge_condition = ของ Router/Option เท่านั้น ไม่ใช่ QC"   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```php
private function validateQCNoEdgeCondition(array $node, array $edges): array
{
    $errors = [];
    
    if ($node['node_type'] === 'qc') {
        $outgoingEdges = $this->getOutgoingEdges($node['id_node'], $edges);
        
        foreach ($outgoingEdges as $edge) {
            // QC ห้ามใช้ edge_condition ทุกกรณี (ตาม QC V2 Philosophy)
            if (!empty($edge['edge_condition'])) {
                $condition = json_decode($edge['edge_condition'], true);
                // ยกเว้น type: 'default' ซึ่งเป็น else case
                if (isset($condition['type']) && $condition['type'] === 'default') {
                    continue;
                }
                
                $errors[] = [
                    'code' => 'Q1_QC_HAS_EDGE_CONDITION',
                    'severity' => 'error',  // 🔴 ERROR ไม่ใช่ warning
                    'node_id' => $node['id_node'],
                    'message' => "QC node '{$node['node_code']}' MUST NOT use edge_condition. Use QC Behavior UI to select rework target (QC V2 philosophy)."
                ];
            }
        }
    }
    
    return $errors;
}
```

### RULE Q2: QC Node ควรมี pass edge

```php
private function validateQCHasPassEdge(array $node, array $edges): array
{
    $warnings = [];
    
    if ($node['node_type'] === 'qc') {
        $outgoingEdges = $this->getOutgoingEdges($node['id_node'], $edges);
        
        $hasPass = false;
        foreach ($outgoingEdges as $edge) {
            if ($edge['edge_type'] === 'normal' || 
                (isset($edge['edge_label']) && stripos($edge['edge_label'], 'pass') !== false)) {
                $hasPass = true;
                break;
            }
        }
        
        if (!$hasPass) {
            $warnings[] = [
                'code' => 'Q2_QC_NO_PASS_EDGE',
                'severity' => 'warning',
                'message' => "QC node '{$node['node_code']}' has no pass edge"
            ];
        }
    }
    
    return $warnings;
}
```

---

## 🟢 BEST PRACTICE RULES

### RULE B1: Component branch ควรมี QC ก่อน merge

```php
private function suggestQCBeforeMerge(array $nodes, array $edges): array
{
    $suggestions = [];
    
    // Find component nodes
    foreach ($nodes as $node) {
        if ($node['node_type'] === 'component') {
            // Check if there's a QC before merge
            $nodesInBranch = $this->getNodesInComponentBranch($node['id_node'], $nodes, $edges);
            
            $hasQC = false;
            foreach ($nodesInBranch as $branchNode) {
                if ($branchNode['node_type'] === 'qc') {
                    $hasQC = true;
                    break;
                }
            }
            
            if (!$hasQC) {
                $suggestions[] = [
                    'code' => 'B1_COMPONENT_NO_QC',
                    'severity' => 'info',
                    'message' => "Component anchor '{$node['anchor_slot']}' has no QC node before merge. Consider adding quality check."
                ];
            }
        }
    }
    
    return $suggestions;
}
```

---

## 🏭 ADVANCED MANUFACTURING RULES (Hermès-grade)

> **Status:** Extended rules for enterprise manufacturing control  
> **Target:** BMW / Tesla / Hermès workshop level

### RULE S1B: Every Component Branch Must Merge

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: S1B_COMPONENT_MUST_MERGE                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ INVALID (Dangling Path):                                    │
│     SPLIT                                                       │
│       ├→ COMPONENT:BODY → CUT → EDGE → (ลืม merge!)            │
│       └→ COMPONENT:FLAP → CUT → EDGE → MERGE                   │
│                                                                 │
│  ❌ INVALID (Dead End):                                         │
│     SPLIT                                                       │
│       ├→ COMPONENT:BODY → CUT → [END NODE]  ← ผิด!             │
│       └→ COMPONENT:FLAP → CUT → MERGE                          │
│                                                                 │
│  ✅ VALID:                                                      │
│     SPLIT                                                       │
│       ├→ COMPONENT:BODY → CUT → EDGE → MERGE                   │
│       └→ COMPONENT:FLAP → CUT → EDGE → MERGE                   │
│                                                                 │
│  Reality: "ไม่มี component ใดในโลกที่ไม่ merge กลับสินค้า"       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation:**

```php
private function validateComponentMustMerge(array $nodes, array $edges): array
{
    $errors = [];
    
    // Find all component nodes
    $componentNodes = array_filter($nodes, fn($n) => $n['node_type'] === 'component');
    
    foreach ($componentNodes as $component) {
        // Trace path from component to find if it reaches a merge node
        $reachesMerge = $this->pathReachesMerge(
            $component['id_node'], 
            $nodes, 
            $edges
        );
        
        if (!$reachesMerge) {
            $errors[] = [
                'code' => 'S1B_COMPONENT_NO_MERGE',
                'severity' => 'error',
                'node_id' => $component['id_node'],
                'message' => "Component anchor '{$component['anchor_slot']}' branch does not merge back. All component branches must connect to a merge node."
            ];
        }
    }
    
    return $errors;
}

private function pathReachesMerge(int $startNodeId, array $nodes, array $edges): bool
{
    $visited = [];
    $queue = [$startNodeId];
    
    while (!empty($queue)) {
        $currentId = array_shift($queue);
        
        if (isset($visited[$currentId])) continue;
        $visited[$currentId] = true;
        
        $node = $this->findNodeById($currentId, $nodes);
        
        // Found merge node!
        if ($node && ($node['is_merge_node'] ?? false)) {
            return true;
        }
        
        // Get downstream nodes
        $children = $this->getDirectChildren($currentId, $edges, $nodes);
        foreach ($children as $child) {
            $queue[] = $child['id_node'];
        }
    }
    
    return false;
}
```

---

### RULE S3B: QC Must Stay Within Correct Component Branch

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: S3B_QC_CORRECT_COMPONENT_BRANCH                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ INVALID (QC in wrong branch):                               │
│     SPLIT                                                       │
│       ├→ COMPONENT:BODY → CUT → QC_FLAP  ← ผิด branch!         │
│       └→ COMPONENT:FLAP → CUT → EDGE                           │
│                                                                 │
│  ❌ INVALID (Cross-branch QC):                                  │
│     SPLIT                                                       │
│       ├→ COMPONENT:BODY → CUT                                   │
│       │                    ↓                                    │
│       │              QC_MIXED  ← อยู่กลางระหว่าง branch!        │
│       │                    ↓                                    │
│       └→ COMPONENT:FLAP → CUT                                   │
│                                                                 │
│  ✅ VALID:                                                      │
│     SPLIT                                                       │
│       ├→ COMPONENT:BODY → CUT → EDGE → QC_BODY → MERGE         │
│       └→ COMPONENT:FLAP → CUT → EDGE → QC_FLAP → MERGE         │
│                                                                 │
│  Reality: "QC BODY ต้อง QC BODY เท่านั้น"                       │
│           "ไม่สามารถไป QC รถอีกคันได้"                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation:**

```php
private function validateQCInCorrectBranch(array $node, array $nodes, array $edges): array
{
    $errors = [];
    
    if ($node['node_type'] === 'qc') {
        // Find component anchor for this QC
        $anchor = $this->findComponentAnchor($node['id_node'], $nodes, $edges);
        
        if ($anchor) {
            $expectedSlot = $anchor['anchor_slot'];
            
            // Check if QC node_code / behavior suggests different component
            $qcCode = strtoupper($node['node_code'] ?? '');
            $qcBehavior = strtoupper($node['behavior_code'] ?? '');
            
            // Extract component hint from QC name (e.g., QC_FLAP, QC_BODY)
            $componentHints = ['BODY', 'STRAP', 'FLAP', 'POCKET', 'LINING'];
            
            foreach ($componentHints as $hint) {
                // If QC name contains a component hint different from anchor
                if ((strpos($qcCode, $hint) !== false || strpos($qcBehavior, $hint) !== false)
                    && strpos($expectedComponent, $hint) === false) {
                    $errors[] = [
                        'code' => 'S3B_QC_WRONG_COMPONENT_BRANCH',
                        'severity' => 'error',
                        'node_id' => $node['id_node'],
                        'message' => "QC node '{$node['node_code']}' appears to be for '{$hint}' but is placed in component branch '{$expectedComponent}'"
                    ];
                    break;
                }
            }
        }
    }
    
    return $errors;
}
```

---

### RULE S4B: Merge Node Must Have Exact Incoming Edges

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: S4B_MERGE_EXACT_INCOMING_EDGES                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ INVALID (Missing incoming edge):                            │
│     SPLIT (expects 3 branches)                                  │
│       ├→ COMPONENT:BODY → ... → MERGE                          │
│       ├→ COMPONENT:FLAP → ... → MERGE                          │
│       └→ COMPONENT:STRAP → ... → (ไม่เข้า merge!)              │
│                                                                 │
│  ❌ INVALID (Duplicate merge path):                             │
│     SPLIT                                                       │
│       ├→ COMPONENT:BODY → CUT → MERGE                          │
│       │                   └───→ MERGE  ← เข้า 2 ครั้ง!          │
│       └→ COMPONENT:FLAP → ... → MERGE                          │
│                                                                 │
│  ❌ INVALID (Non-component edge to merge):                      │
│     SPLIT                                                       │
│       ├→ COMPONENT:BODY → MERGE                                │
│       └→ RANDOM_NODE ────→ MERGE  ← ไม่ใช่ component path!      │
│                                                                 │
│  ✅ VALID:                                                      │
│     SPLIT                                                       │
│       ├→ COMPONENT:BODY → ... → MERGE (1 edge)                 │
│       ├→ COMPONENT:FLAP → ... → MERGE (1 edge)                 │
│       └→ COMPONENT:STRAP → ... → MERGE (1 edge)                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation:**

```php
private function validateMergeIncomingEdges(array $node, array $nodes, array $edges): array
{
    $errors = [];
    
    if ($node['is_merge_node'] ?? false) {
        // Get all incoming edges to merge
        $incomingEdges = array_filter($edges, fn($e) => $e['target_node_id'] == $node['id_node']);
        
        // Find corresponding split
        $split = $this->findCorrespondingSplit($node['id_node'], $nodes, $edges);
        
        if ($split) {
            // Get expected component count from split
            $componentNodes = $this->getComponentNodesAfterSplit($split['id_node'], $nodes, $edges);
            $expectedCount = count($componentNodes);
            $actualCount = count($incomingEdges);
            
            // Validate count matches
            if ($actualCount !== $expectedCount) {
                $errors[] = [
                    'code' => 'S4B_MERGE_EDGE_COUNT_MISMATCH',
                    'severity' => 'error',
                    'node_id' => $node['id_node'],
                    'message' => "Merge node '{$node['node_code']}' has {$actualCount} incoming edges but expects {$expectedCount} (one per component branch)"
                ];
            }
            
            // Validate each incoming edge comes from component branch
            foreach ($incomingEdges as $edge) {
                $sourceNode = $this->findNodeById($edge['source_node_id'], $nodes);
                $componentAnchor = $this->findComponentAnchor($edge['source_node_id'], $nodes, $edges);
                
                if (!$componentAnchor) {
                    $errors[] = [
                        'code' => 'S4B_MERGE_NON_COMPONENT_EDGE',
                        'severity' => 'error',
                        'node_id' => $node['id_node'],
                        'message' => "Merge node '{$node['node_code']}' has incoming edge from '{$sourceNode['node_code']}' which is not in a component branch"
                    ];
                }
            }
            
            // Check for duplicate paths from same component anchor
            $anchorPaths = [];
            foreach ($incomingEdges as $edge) {
                $anchor = $this->findComponentAnchor($edge['source_node_id'], $nodes, $edges);
                if ($anchor) {
                    $slot = $anchor['anchor_slot'];
                    if (isset($anchorPaths[$slot])) {
                        $errors[] = [
                            'code' => 'S4B_MERGE_DUPLICATE_COMPONENT_PATH',
                            'severity' => 'error',
                            'node_id' => $node['id_node'],
                            'message' => "Merge node '{$node['node_code']}' has multiple paths from anchor '{$slot}'"
                        ];
                    }
                    $anchorPaths[$slot] = true;
                }
            }
        }
    }
    
    return $errors;
}
```

---

### RULE B2: Work Center Compatibility

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: B2_WORK_CENTER_COMPATIBILITY                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ⚠️ WARNING Case:                                               │
│     Component: STRAP                                            │
│       → Edge Painting (work_center: PAINT)                      │
│       → Hot Press (work_center: HEAT)                           │
│       → Edge Painting (work_center: PAINT)  ← กลับมาอีก         │
│                                                                 │
│  Potential Issues:                                              │
│     • PAINT มี 1 เครื่อง แต่ต้องใช้ 2 ครั้ง → bottleneck       │
│     • Work center sequence อาจไม่ realistic                     │
│     • Travel time ระหว่าง work center ไม่ถูกคำนวณ              │
│                                                                 │
│  Suggestion: "Review work center sequence for optimization"     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Implementation:**

```php
private function suggestWorkCenterOptimization(array $nodes, array $edges): array
{
    $suggestions = [];
    
    // Group operations by work center
    $workCenterUsage = [];
    foreach ($nodes as $node) {
        if ($node['node_type'] === 'operation' && !empty($node['work_center_code'])) {
            $wc = $node['work_center_code'];
            if (!isset($workCenterUsage[$wc])) {
                $workCenterUsage[$wc] = [];
            }
            $workCenterUsage[$wc][] = $node;
        }
    }
    
    // Check for potential bottlenecks
    foreach ($workCenterUsage as $wc => $usages) {
        if (count($usages) > 3) {
            $suggestions[] = [
                'code' => 'B2_WORK_CENTER_BOTTLENECK',
                'severity' => 'info',
                'message' => "Work center '{$wc}' is used {count($usages)} times in this graph. Consider load balancing or adding capacity."
            ];
        }
    }
    
    // Check for back-and-forth work center usage
    $path = $this->getLinearPath($nodes, $edges);
    $prevWc = null;
    $wcJumps = 0;
    
    foreach ($path as $node) {
        if ($node['node_type'] === 'operation' && !empty($node['work_center_code'])) {
            if ($prevWc !== null && $prevWc !== $node['work_center_code']) {
                $wcJumps++;
            }
            $prevWc = $node['work_center_code'];
        }
    }
    
    if ($wcJumps > 5) {
        $suggestions[] = [
            'code' => 'B2_WORK_CENTER_TRAVEL',
            'severity' => 'info',
            'message' => "Graph has {$wcJumps} work center transitions. Consider grouping operations by work center to reduce travel time."
        ];
    }
    
    return $suggestions;
}
```

---

### RULE B3: Material Compatibility

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: B3_MATERIAL_COMPATIBILITY                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ⚠️ WARNING Case:                                               │
│     Component: BODY (material: goat_nappa)                      │
│       → Hot Press 180°C   ← goat_nappa ทนได้แค่ 150°C!          │
│                                                                 │
│  Potential Issues:                                              │
│     • Material ไม่ compatible กับ process                       │
│     • Operation parameters ไม่เหมาะกับ material                 │
│     • อาจเกิด damage ระหว่างผลิต                                │
│                                                                 │
│  Note: ต้องเชื่อมกับ SKILL_MATERIAL_TOLERANCE_SPEC              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### RULE B4: Skill Requirements Not Assigned

```
┌─────────────────────────────────────────────────────────────────┐
│  RULE: B4_SKILL_NOT_ASSIGNED                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ⚠️ WARNING Case:                                               │
│     Operation: STITCH_BODY                                      │
│       → behavior: STITCH                                        │
│       → required_skill: STITCHING level 4                       │
│       → work_center: STITCH_01                                  │
│       → assigned_worker: (none)                                 │
│                                                                 │
│  Suggestion:                                                    │
│     "Operation STITCH_BODY requires STITCHING skill level 4     │
│      but no worker assignment. Consider pre-assigning           │
│      qualified workers or enabling skill-based auto-routing."   │
│                                                                 │
│  Note: ต้องเชื่อมกับ SKILL_MATERIAL_TOLERANCE_SPEC              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎨 UI Integration

### Validation Results Display

```
┌─────────────────────────────────────────────────────────────────┐
│              GRAPH VALIDATION RESULTS                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🔴 ERRORS (2) - Must fix before save                          │
│  ├─ S1: Parallel split 'MAIN_SPLIT' branch to 'CUT_STRAP'      │
│  │      must start with Component Node                         │
│  │      [Go to node] [Auto-fix]                                 │
│  │                                                              │
│  └─ C1: Component code 'STRAP_LONGG' not found in catalog      │
│         [Go to node] [Select from catalog]                      │
│                                                                 │
│  🟡 WARNINGS (1)                                                │
│  └─ Q1: QC node 'QC_BODY' has edge_condition on rework edge    │
│         Consider using QC Behavior UI instead                   │
│         [Go to node] [Learn more]                               │
│                                                                 │
│  🟢 SUGGESTIONS (1)                                             │
│  └─ B1: Component 'STRAP_LONG' has no QC node before merge     │
│         Consider adding quality check                           │
│         [Dismiss] [Add QC node]                                 │
│                                                                 │
│  ──────────────────────────────────────────────────────────     │
│  [Cancel]                    [Fix Errors & Save]                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Rule Summary

### Core Rules (v1.0)

| Code | Rule | Severity |
|------|------|----------|
| **S1** | Parallel split needs component anchors | 🔴 ERROR |
| **S2** | Component before assembly only | 🔴 ERROR |
| **S3** | QC needs upstream operation | 🔴 ERROR |
| **S4** | Merge component count match | 🔴 ERROR |
| **C1** | Component code in catalog | 🔴 ERROR |
| **C2** | Unique component codes | 🔴 ERROR |
| **Q1** | QC MUST NOT use edge_condition | 🔴 ERROR |
| **Q2** | QC has pass edge | 🟡 WARNING |
| **B1** | Component has QC | 🟢 INFO |

### Advanced Manufacturing Rules (v1.1 Hermès-grade)

| Code | Rule | Severity |
|------|------|----------|
| **S1B** | Every component branch must merge | 🔴 ERROR |
| **S3B** | QC must stay in correct component branch | 🔴 ERROR |
| **S4B** | Merge exact incoming edge validation | 🔴 ERROR |
| **B2** | Work center compatibility/bottleneck | 🟢 INFO |
| **B3** | Material compatibility check | 🟢 INFO |
| **B4** | Skill requirements validation | 🟢 INFO |

---

## 🚀 Implementation Phases

### Phase 1: Core Rules (Week 1)
- [ ] S1, S2, S3 (Structural)
- [ ] C1, C2 (Component)
- [ ] Integration with GraphValidationEngine

### Phase 2: QC Rules (Week 2)
- [ ] Q1, Q2 (QC)
- [ ] S4 (Merge count)
- [ ] Auto-fix suggestions

### Phase 3: Best Practices (Week 3)
- [ ] B1 and other suggestions
- [ ] UI integration
- [ ] Help documentation

### Phase 4: Advanced Manufacturing (Week 4-5) 🏭
- [ ] S1B (Component merge validation)
- [ ] S3B (QC branch validation)
- [ ] S4B (Merge edge validation)
- [ ] B2/B3/B4 (Work center, Material, Skill)
- [ ] Integration with SKILL_MATERIAL_TOLERANCE_SPEC

---

## Related Documents

- [QC_REWORK_PHILOSOPHY_V2.md](./QC_REWORK_PHILOSOPHY_V2.md) - QC V2 concept
- [COMPONENT_CATALOG_SPEC.md](./COMPONENT_CATALOG_SPEC.md) - Component standards
- [DEFECT_CATALOG_SPEC.md](./DEFECT_CATALOG_SPEC.md) - Defect standards
- [MISSING_COMPONENT_INJECTION_SPEC.md](./MISSING_COMPONENT_INJECTION_SPEC.md) - **Escape Hatch** สำหรับ production

---

## 🚨 Linter Limitations & Escape Hatch

```
┌─────────────────────────────────────────────────────────────────┐
│              WHAT LINTER CAN'T CATCH                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ✅ Linter CAN catch:                                           │
│     • กราฟโครงสร้างผิด (ไม่มี start/end)                        │
│     • Component node วางผิดที่                                  │
│     • QC ใช้ edge_condition (ขัด QC V2)                         │
│     • Merge node incoming edges ผิด                             │
│                                                                 │
│  ❌ Linter CANNOT catch:                                        │
│     • Designer ลืมวาด component บางตัว                          │
│     • Design ถูกต้องตาม spec แต่ไม่ตรงกับ product จริง          │
│     • การตัดสินใจทางธุรกิจที่เปลี่ยนระหว่าง production          │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ SOLUTION: Missing Component Injection (MCI)              │   │
│  │                                                          │   │
│  │ • Linter = Prevention (กันตั้งแต่ design time)           │   │
│  │ • MCI = Recovery (แก้ตอน production time)                │   │
│  │                                                          │   │
│  │ ทั้งสองทำงานร่วมกัน ครอบคลุมทั้ง design-time + runtime   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  See: MISSING_COMPONENT_INJECTION_SPEC.md                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

> **"Linter = ด่านกัน concept พัง"**



