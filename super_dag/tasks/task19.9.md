

# Task 19.9 — AutoFix Engine v2 (Edge Creation & Graph Structural Repair)

> Version: v1.0  
> Depends on:  
> - 19.5 (time model foundation)  
> - 19.6 (UI refactor)  
> - 19.7 (GraphValidationEngine)  
> - 19.8 (AutoFix v1 – metadata fixes only)

## 1. Objective

Expand AutoFixEngine from **metadata-only fixes** (v1) to **structural graph repairs**, including:

- Auto-create missing edges for QC full coverage (Pass / Minor / Major)
- Auto-create valid ELSE edges for non-QC conditional nodes
- Auto-create END node if missing (only if graph design implies one)
- Auto-connect dangling edges (safe patterns only)
- Auto-create required rework edges for QC nodes when QC policy demands it
- Detect & repair unreachable nodes
- Auto-generate minimal valid parallel merges/splits when graph structure implies them

**Key Rule:**  
AutoFix v2 must never alter intended behavior. It must only “complete” or “repair” structures that are already strongly implied.

---

## 2. Scope (v2)

### 2.1 In-Scope AutoFix Patterns

#### 1. Auto-create QC edges
If QC node has:
- 1 pass conditional edge
- 1 rework edge (no condition)
- Missing fail_minor / fail_major  
→ AutoFix v2 may **create a dedicated conditional edge for each missing status**, pointing to the same rework target.

**Example:**
```
QC1 --(pass)--> Next
QC1 --(no condition)---> ReworkSink
```

AutoFix creates:
```
QC1 --(status=fail_minor)--> ReworkSink
QC1 --(status=fail_major)--> ReworkSink
```

#### 2. Auto-create ELSE edge for non-QC nodes
If a node:
- Has ≥1 conditional edges
- Has **no** unconditional edge
→ AutoFix must create an unconditional “default” edge to the nearest valid node.

Nearest valid node = next sibling operation OR END.

#### 3. Auto-create END node (safe mode)
If:
- Graph has no END node  
- Last operation(s) have no outgoing edges  
→ AutoFix generates a single END node and connects all terminal operations to it.

#### 4. Auto-connect unreachable nodes
If a node exists but has:
- No incoming edges  
- And is not START  
→ AutoFix suggests connecting it to the nearest upstream node of same work_center or behavior category.

#### 5. Auto-create missing rework path for QC
If QC policy explicitly requires rework (e.g. `force_rework_on_fail=true`)  
but QC node has no path for failure  
→ AutoFix adds:
```
QC --(fail_minor & fail_major)--> REWORK_SINK
```

#### 6. Auto-create merge for parallel branches
If:
- A node is detected as parallel split (two outgoing edges)  
- Downstream nodes converge into same node  
→ AutoFix marks the converging node as merge node (`is_merge_node=1`).

#### 7. Auto-create split node (last resort, optional)
If user draws multiple edges from a node that is NOT parallel  
→ AutoFix can insert an invisible “inferred split” metadata flag.

**No new visual node created.**

---

## 3. Out-of-Scope (v2)

- Auto-creating **visible** nodes (other than END)
- Auto-creating whole subgraphs
- Auto-creating JOIN/SPLIT nodes explicitly (use inferred metadata only)
- Auto-changing behavior, WC, execution_mode
- Auto-creating parallel branches without explicit user intent
- Altering rework logic beyond QC

---

## 4. Architecture

### 4.1 File: `GraphAutoFixEngine.php`

Add new method:

```php
public function generateStructuralFixes(array $nodes, array $edges, array $validation, array $options = []): array
{
    // Returns array of FixDefinition[]
}
```

Call order:
1. Run v1 metadata fixes
2. Run v2 structural fixes
3. Merge results (preserve ordering)
4. Return FixDefinition list

### 4.2 FixDefinition (extended)

Add new fields:

```
'op' => 'create_edge', 'delete_edge', 'update_edge', 'set_node_flag', 'insert_end_node'
```

Example:

```
[
  'id' => 'FIX-QC-FULL-COVERAGE-1',
  'type' => 'QC_FULL_COVERAGE',
  'severity' => 'safe',
  'operations' => [
    [
      'op' => 'create_edge',
      'from_node_id' => 12,
      'to_node_id' => 98,
      'edge_type' => 'conditional',
      'condition' => [
        'field' => 'qc_result.status',
        'op' => 'eq',
        'value' => 'fail_major'
      ]
    ]
  ]
]
```

---

## 5. Backend Changes

### 5.1 dag_routing_api.php

Add optional enable flag:

```
graph_autofix?mode=structural
```

Selector:
- `metadata` = v1 fixes only
- `structural` = v1 + v2 fixes

### 5.2 GraphStateManager

Implement support for:

- Creating edges
- Creating END node
- Applying conditional metadata to edges
- Updating merge/split flags

---

## 6. Frontend Changes

### 6.1 graph_designer.js

Add:
- Preview UI for newly created edges/node
- Confirmation flow for structural fixes
- Warning if v2 fix may affect graph flow

### 6.2 Visual Indicators

- Created edges → glow highlight
- New END node → “auto created” badge

---

## 7. Test Cases

File: `autofix_v2_test_cases.md`  
Minimum 15 cases:

1. QC missing fail_major → creates edge  
2. QC missing fail_minor → creates edge  
3. No END → create END  
4. Parallel → auto merge marking  
5. Non-QC conditional without default → create default  
6. Dangling node → auto-connect  
7. Orphan node → auto-connect  
8. QC + no rework path → create rework  
9. Multi-branch join → infer merge  
10. Multi-branch split → infer split  
11. Legacy graph → no unwanted fixes  
12. Excessive branches → no fix  
13. Structural + metadata combined  
14. Incomplete group of conditional edges  
15. END normalization only

---

## 8. Acceptance Criteria

- [ ] GraphAutoFixEngine supports v2 structural fixes
- [ ] dag_routing_api.php exposes structural mode
- [ ] GraphDesigner UI supports preview & confirmation
- [ ] QC full-coverage creation works
- [ ] Default edges created correctly
- [ ] END node creation safe
- [ ] Parallel merge marking correct
- [ ] No unsafe fixes (semantics preserved)
- [ ] All fixes idempotent
- [ ] Tests written (15+)