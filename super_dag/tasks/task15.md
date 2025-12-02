
# Task 15 — DAG Node Behavior Binding & Graph Standardization (Phase 4)

**Status:** NEW  
**Category:** Super DAG – Core Graph Layer  
**Depends on:** Task 1–14 (Behavior Engine, Execution Layer, Session Engine, Routing Integration)

---

# 🎯 Objective

This task establishes the **first true DAG graph standardization layer**:

1. Ensure **every DAG node** in the graph has a **canonical behavior_code**  
2. Ensure **behavior_code is derived from Work Center Behavior mapping**  
3. Ensure **graph nodes become behavior-aware at design-time**  
4. Remove all “implicit behavior inference” from runtime  
5. Build the foundation for Task 16–20 (Parallel / Merge / Machine / SLA)

This is the first task where the **graph structure** becomes part of the **execution model**.

---

# 🧩 Why Task 15 is Critical

Before Task 15:

- DAG nodes do not consistently store `behavior_code`
- Some nodes infer behavior from work_center, some from legacy fields
- Designer may add nodes without behavior context
- Execution engine relies on runtime deduction (unsafe)

After Task 15:

- Every DAG node must define its `behavior_code` explicitly  
- Valid behaviors come from `work_center_behavior` registry  
- Graph → Node → Behavior → Execution Mode → Work Center → Session Engine → Routing Engine  
- No more runtime guessing  
- This becomes the **contract** for the whole Super DAG

---

# 🛠️ Deliverables

## 1. Update DAG Node Schema  
Add to table `dag_nodes`:

| Column | Type | Description |
|--------|------|-------------|
| `behavior_code` | VARCHAR(50) NULL | Canonical behavior code (CUT, STITCH, EDGE, QC_FINAL, HARDWARE_ASSEMBLY) |
| `behavior_version` | INT DEFAULT 1 | Reserved for future upgrades |

### Requirements:
- Existing nodes: `behavior_code` = NULL initially (migration won’t break)
- New nodes must enforce non-null `behavior_code`

---

## 2. Migration File  
Create tenant migration:

`2025_12_xx_15_dag_node_behavior_binding.php`

Responsibilities:

1. Add new columns (`behavior_code`, `behavior_version`)
2. Backfill behavior_code for existing nodes using rules:
   - If node has linked work_center → lookup behavior from `work_center_behavior_map`
   - Else if node name matches known patterns (cut/edge/stitch/qc) → fallback mapping
   - Else → leave NULL (designer must fix)

3. Log summary for each tenant:
   - nodes updated
   - nodes skipped
   - nodes needing manual review

---

## 3. Update DAG Designer (UI)

### Add dropdown:

Behavior (required)

Behavior options come from:

GET /api/work_center_behavior/get_behavior_list

### Validation:
- Cannot save node without behavior_code  
- Cannot assign behavior_code not in registry  
- For system nodes (CUT, STITCH, QC_FINAL): lock behavior (no edit allowed)

### Visual:
- Add behavior badge under node name  
- Example: `[CUT]` `[STITCH]` `[QC]`

---

## 4. Update dag_node_api.php

### Add field to:
- create_node  
- update_node  
- get_node  
- get_graph  

### Validation rules:
- `behavior_code` must exist in `work_center_behavior`
- If node is system-generated → behavior cannot be changed
- Verify that behavior matches allowed execution mode in future tasks

---

## 5. Update DagExecutionService (Read only)

### Add `behavior_code` to:

- internal node representation  
- runtime routing metadata  
- event logs  
- `BG:TokenRouted` event payload  

*(No behavior logic changes in Task 15 — only structural awareness)*

---

## 6. Update BehaviorExecutionService

Before executing any behavior:

validate payload.behavior_code === node.behavior_code

If mismatch → error:

DAG_BEHAVIOR_MISMATCH
“Behavior does not match this node.”

This completely eliminates runtime ambiguity.

---

## 7. Update Seed (0002_seed_data.php)

This task **must also update the global seed file**:

`database/tenant_migrations/0002_seed_data.php`

Add a new section that seeds:

1. `behavior_code` default for system nodes  
2. Behavior registry entries (CUT, EDGE, STITCH, QC_FINAL, QC_INITIAL, HARDWARE_ASSEMBLY, SKIVE, PACK, GLUE, etc.)  
3. Ensure all canonical behaviors exist before any tenant creates a DAG.  
4. Ensure the seed is the **single source of truth** used by:
   - DAG Designer  
   - dag_node_api  
   - BehaviorExecutionService  
   - DagExecutionService  

All behaviors required by Task 15 must be inserted into the seed using:

```
migration_insert_if_not_exists(...)
```

This ensures new tenants always have a fully working Super DAG baseline from the moment they are created.

**Work Center Binding Requirement**  
This seed update MUST also bind each behavior to its corresponding system work center using the canonical Work Center → Behavior mapping established in Tasks 15.7–15.9(docs/dag).  
This ensures that all system work centers (CUT, SKIV, EDGE, GLUE, STITCH, ASSEMBLY, QC_INITIAL, QC_FINAL, PACK, etc.) always have their correct `behavior_code` assigned at tenant creation time.  
Seed must use `migration_insert_if_not_exists(...)` to write into the actual mapping table (e.g. `work_center_behavior_map` or equivalent confirmed by the repository scan).

---

# 🔒 Safety Rails (Non-Negotiable)

1. **System Nodes Cannot Change Behavior**  
   - CUT, STITCH, QC_FINAL, EDGE  
   - Lock UI and API  
   - Show message: `Editing is not allowed for system-defined nodes.`

2. **Graph cannot be saved without behavior_code**  
3. **Runtime cannot infer behavior anymore**  
4. **Migration must be idempotent**  
5. **Designer cannot create nodes with arbitrary behavior**  
6. **Behavior registry is the single source of truth**  
7. **Legacy behavior fields remain read-only (compat mode)**

---

# 📘 Summary

Task 15 is the **last prep task** before the DAG becomes a “true Super DAG.”

After completing Task 15:

- All nodes become behavior-aware  
- Designer workflow becomes standardized  
- Execution engine becomes deterministic  
- Routing & session logic becomes consistent across all behaviors  
- Task 16–20 (Parallel, Merge, SLA, Machine Behavior) can be implemented safely

---

# ✅ Next Task

After Task 15 is completed, continue with:

**Task 16 — Execution Mode Binding (Behavior + Mode = NodeType)**

Which introduces:

- HAT_SINGLE  
- BATCH  
- CLASSIC_SCAN  
- QC_SINGLE  

And makes every node formally typed.

CUT + BATCH
STITCH + HAT_SINGLE
EDGE + BATCH
QC_FINAL + QC_SINGLE

---

# End of Task 15.md