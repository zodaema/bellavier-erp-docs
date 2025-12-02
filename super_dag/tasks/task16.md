

# Task 16 — Execution Mode Binding (Behavior + Mode = NodeType)

**Status:** NEW  
**Category:** Super DAG – Core Graph Layer (Phase 5)  
**Depends on:**  
- Task 1–14 (Behavior Engine, Execution Layer, Session Engine, Routing Integration)  
- Task 15 (Node Behavior Binding & Graph Standardization)

---

# 🎯 Objective

This task establishes the true **NodeType Model**, where each DAG node becomes:

```
NodeType = Behavior + ExecutionMode
```

This canonical typing is required before implementing:

- Parallel Node Execution (Task 17)  
- Merge Semantics (Task 18)  
- Machine Cycles (Task 19)  
- SLA / Throughput Prediction (Task 20)

---

# 🧩 Execution Modes (Canonical)

Add these 4 execution modes as system-defined enumerations:

| Mode | Description |
|------|-------------|
| `BATCH` | Batch-based manufacturing (CUT, EDGE, SKIVE, GLUE) |
| `HAT_SINGLE` | Hatthasilpa single-piece operations (STITCH, ASSEMBLY) |
| `CLASSIC_SCAN` | OEM / scan-driven stations |
| `QC_SINGLE` | QC operations (initial/final/repair) |

Seed these modes into `0002_seed_data.php` using `migration_insert_if_not_exists`.

---

# 📦 Deliverables

## 1. Update DAG Node Schema  
Add:

| Column | Type | Notes |
|--------|------|-------|
| `execution_mode` | VARCHAR(50) NULL | Must reference system mode registry |
| `node_type` | VARCHAR(100) NULL | Derived: `${behavior_code}:${execution_mode}` |

Migration file:  
`2025_12_xx_16_dag_node_mode_binding.php`

### Migration Steps:
1. Add above fields  
2. For existing nodes:  
   - Determine mode via canonical mapping (below)  
   - Set `node_type` accordingly  
3. Log summary
4. For any node where behavior_code is NULL or mapping is ambiguous, leave `execution_mode` and `node_type` as NULL and log them clearly for manual review (do NOT invent modes).

---

## 2. Canonical Mapping (Behavior → ExecutionMode)

| Behavior | Mode |
|----------|------|
| CUT | BATCH |
| SKIVE | BATCH |
| EDGE | BATCH |
| GLUE | BATCH |
| STITCH | HAT_SINGLE |
| ASSEMBLY | HAT_SINGLE |
| HARDWARE_ASSEMBLY | HAT_SINGLE |
| QC_INITIAL | QC_SINGLE |
| QC_FINAL | QC_SINGLE |
| QC_REPAIR | QC_SINGLE |
| PACK | HAT_SINGLE |

Seed this mapping into `0002_seed_data.php`.

**Rule:**  
- These mappings are **system-level and immutable** for system behaviors.  
- System behaviors (CUT, SKIVE, EDGE, GLUE, STITCH, ASSEMBLY, HARDWARE_ASSEMBLY, QC_INITIAL, QC_FINAL, QC_REPAIR, PACK) must always use the canonical modes above.  
- Tenant-specific overrides are not allowed for system behaviors.

---

## 3. DAG Designer (UI)

### Add required dropdown:
```
Execution Mode (required)
```

Auto-fill based on Behavior selection.  
For system nodes → lock the mode and show:

`Execution mode is system-defined.`

This message must be implemented as an i18n string (e.g. `superdag.node.mode.locked`) and must replace any interactive control (hide dropdown completely for system nodes).

### Show NodeType badge:
Example:  
`[CUT:BATCH]`  
`[STITCH:HAT_SINGLE]`

---

## 4. Update dag_node_api.php

### Update:
- create_node  
- update_node  
- get_node  
- get_graph  

### Validation:
- mode must exist in registry  
- behavior + mode must be allowed pair  
- system nodes → mode cannot change  
- node_type must always be updated consistently

---

## 5. NodeTypeRegistry (NEW)

Create a new PHP registry class:

`BGERP/SuperDAG/NodeTypeRegistry.php`

Functions:

- `isValidMode($mode)`  
- `isValidCombination($behavior, $mode)`  
- `deriveNodeType($behavior, $mode)`  
- `getAllowedModes($behavior)`  

---

## 6. BehaviorExecutionService Update

Before executing any node:

```
if ($node->execution_mode !== expected_mode_for_behavior)  
    throw DAG_MODE_MISMATCH
```

Execution modes now participate in safety validation.

---

## 7. DagExecutionService Update

Add `execution_mode` and `node_type` into:

- internal node structure  
- routing decisions  
- token payload  
- event logs

---

## 8. Seed Update (0002_seed_data.php)

### Must seed:
1. Execution mode registry  
2. Behavior → Mode canonical mapping  
3. Generate default `node_type` definitions for system behaviors  
4. **Bind execution_mode to Work Center** where required for new tenants  
5. Ensure DAG Designer relies on this seed exclusively

**All seed updates must use `migration_insert_if_not_exists`.**

**Schema/Discovery Requirement:**  
- Table/column names in this document are examples only.  
- Before writing seed or migration code, the implementation must scan the existing repository to discover the actual tables and columns used for:  
  - execution mode registry  
  - behavior registry  
  - work center → behavior mapping  
  - any existing execution_mode fields  
- DO NOT introduce new tables or columns if suitable ones already exist in the current schema.

---

# 🔒 Safety Rules (Non-Negotiable)

1. System nodes must NOT allow execution mode editing  
2. Designer must select valid behavior + mode only  
3. Runtime can never infer execution mode  
4. All nodes must have `behavior_code`, `execution_mode`, `node_type`  
5. Legacy fields remain read-only  
6. NodeType must remain stable across tenants

---

# 📘 Summary

Task 16 transitions the DAG from a “behavior-aware graph” to a **fully typed execution graph**.

This enables deterministic:

- routing  
- time modeling  
- QC flows  
- parallel paths  
- machine-driven flows  
- analytics & throughput SLA  

and sets up Task 17 (Parallel Node Execution).

---

---

## 9. Implementation Notes (for AI Agents)

- Always **discover actual schema** from the repository first (tables, columns, existing enums) before implementing this task.  
- Never assume that examples in this file exactly match the current database; adapt to what actually exists.  
- Do not invent new execution modes beyond the four specified here without an explicit spec update.  
- Do not change behavior for existing runtime flows (HATTHASILPA, CLASSIC_SCAN, QC, etc.). This task is structural/typing only; behavior semantics must remain identical after migration.  
- All changes must be idempotent and safe to run across all tenants.

# Next Task

**Task 17 — Parallel Node Execution + Merge Semantics**