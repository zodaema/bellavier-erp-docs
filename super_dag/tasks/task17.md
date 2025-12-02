

# Task 17 — Parallel Node Execution & Merge Semantics

**Status:** NEW  
**Category:** Super DAG – Execution Layer (Phase 6)  
**Depends on:**  
- Task 1–14 (Behavior & Execution Engine, Session Engine, Routing Integration)  
- Task 15 (Node Behavior Binding & Graph Standardization)  
- Task 16 (Execution Mode Binding & NodeType Model)

---

# 🎯 Objective

Introduce **first-class support for parallel branches and merge nodes** in Super DAG, using the existing NodeType/Behavior/Mode model and Token Engine 2.0.

After this task:
- A node can **split** execution into multiple parallel branches (parallel children)
- A merge node can **wait for all required branches** to complete before continuing
- Token Engine understands **parallel tokens** and **merge points**
- Logs & events clearly describe split/merge behavior
- No change of behavior semantics in existing nodes (CUT, STITCH, EDGE, QC, etc.) — this is an additive structural capability

This is the task that turns the DAG from a **linear chain** into a **true directed acyclic graph** with branches and joins.

---

# 🧩 Core Concepts

## 1. Parallel Split Node

A **Parallel Split Node** is a DAG node that:
- Has 2+ outgoing edges
- Marks all children as **parallel branches** of the same logical flow
- Causes the Token Engine to create multiple active tokens (one per branch)

Key rules:
- Behavior of a split node is usually neutral (e.g. `ROUTER` / `CONTROL`) or follows a simple behavior like `DISPATCH`  
  (Implementation must derive from existing schema / types; **do not invent new behavior unless already defined**.)
- Split node itself may or may not have a work center; often it is logical only.

## 2. Merge Node

A **Merge Node** is a DAG node that:
- Has 2+ incoming edges
- Waits until **all required incoming branches** have been completed
- Only then allows execution to continue beyond this node

Key rules:
- Merge semantics are **blocking**: downstream node(s) cannot start until merge condition is satisfied.
- Merge node is a logical control node. It may or may not have a behavior/work center depending on design.

## 3. Token Group / Parallel Group

Parallel branches belong to a **Parallel Group**:
- Identified by a `parallel_group_id` (new field) or equivalent
- All tokens created by a split belong to the same group
- Merge node references the same group to know which branches to wait for

> **Important:** Implementation must discover existing token / group fields in the schema before introducing new ones. If suitable fields already exist, reuse them.

---

# 📦 Deliverables

## 1. Schema Updates (Token & DAG)

Create a tenant migration:

`database/tenant_migrations/2025_12_17_parallel_merge_support.php`

### 1.1 Token Schema

Add fields to the token table (or related tables) that represent parallel groups.

**Example (must adapt to actual schema by repo discovery):**

- `parallel_group_id` (INT or BIGINT, nullable)  
- `parallel_branch_key` (VARCHAR, nullable) — e.g. `A`, `B`, `C`, or an index

Rules:
- When a split occurs, the parent token creates N new tokens with the same `parallel_group_id` and unique `parallel_branch_key`.
- Existing tokens not involved in parallel execution keep these fields NULL.

### 1.2 DAG Schema (Split/Merge Metadata)

Extend DAG node metadata (either in `dag_nodes` table or a related config table) with:

- `is_parallel_split` (TINYINT(1), default 0)
- `is_merge_node` (TINYINT(1), default 0)
- `merge_mode` (VARCHAR(50), nullable, e.g. `ALL`, `ANY`) — **for now Task 17 uses only `ALL`**

> **Schema/Discovery Requirement:**
> - Use repository scanning to find the actual DAG node table and adjust column names accordingly.  
> - Do not create new tables if an existing node-metadata structure is already used for control flags.

---

## 2. DAG Designer (UI) – Parallel / Merge Configuration

Update Super DAG Editor UI to allow marking nodes as:

- **Parallel Split Node**
- **Merge Node**

### 2.1 Split Node Configuration

In node properties panel:

- Add toggle: `This node starts parallel branches`  
  → sets `is_parallel_split = 1`
- Validate that node has 2+ outgoing edges when marked as split

### 2.2 Merge Node Configuration

In node properties panel:

- Add toggle: `This node merges parallel branches`  
  → sets `is_merge_node = 1`
- Add dropdown: `Merge mode` (for now only `ALL` is allowed; `ANY` reserved for future)
- Validate that node has 2+ incoming edges when marked as merge

### 2.3 UI Safety

- Do not allow a node to be both `is_parallel_split` and `is_merge_node` at the same time.  
- Show a visual icon/badge for split and merge nodes (e.g. `||` for split, `⋂` for merge).
- If the graph topology changes such that split/merge constraints are violated (e.g. split node now has only 1 outgoing edge), show a validation error and block save.

---

## 3. `dag_routing_api.php` – Graph & Node API

Update `source/dag_routing_api.php`:

### 3.1 Node Create / Update

- Accept and persist:
  - `is_parallel_split` (bool)
  - `is_merge_node` (bool)
  - `merge_mode` (string, default `ALL`)
- Enforce validation:
  - `is_parallel_split = 1` → require 2+ outgoing edges
  - `is_merge_node = 1` → require 2+ incoming edges
  - Node cannot be both split and merge

### 3.2 Graph Load

- Include `is_parallel_split`, `is_merge_node`, and `merge_mode` in graph JSON
- Ensure Super DAG editor gets all flags necessary to render the graph correctly

### 3.3 Validation Errors

Return clear error codes/messages such as:

- `DAG_INVALID_SPLIT_NODE` — "Parallel split node must have at least 2 outgoing edges."
- `DAG_INVALID_MERGE_NODE` — "Merge node must have at least 2 incoming edges."
- `DAG_INVALID_NODE_FLAGS` — "Node cannot be both split and merge."

All errors must be logged via existing logging helper.

---

## 4. DagExecutionService — Parallel Execution Logic

Extend `source/BGERP/Dag/DagExecutionService.php` to support parallel splits and merge semantics.

### 4.1 Parallel Split Execution

When a token reaches a node with `is_parallel_split = 1`:

1. Identify all outgoing edges (child nodes)
2. For each child node, create a new token:
   - Inherit parent token context (MO, serial, component bindings context, etc.)
   - Set `parallel_group_id` = new unique group id (for this split)
   - Set `parallel_branch_key` = incremental index or label (e.g. `1`, `2`, `3`)
3. Mark parent token as **completed or transformed** according to existing token lifecycle rules (DO NOT invent new lifecycle; reuse the standard pattern already used for routing).  
4. Log event: `DAG_PARALLEL_SPLIT` with payload containing:
   - `parallel_group_id`
   - involved node ids
   - child token ids

### 4.2 Merge Execution

When a token **completes** at a node marked as `is_merge_node = 1`:

1. Determine the `parallel_group_id` of this token
2. Fetch all sibling tokens in the same `parallel_group_id` that are expected to arrive at this merge node (based on incoming edges)
3. If merge mode = `ALL`:
   - Check if **all required branches** are in a terminal/complete state at this merge node
   - If not all completed → keep merge node in **waiting state** (do not route forward)
   - If all completed → proceed to route a **single merged token** forward

4. Merged token behavior:
   - You may reuse one of the branch tokens as the "merged" token (e.g. the first one to complete) and mark others as closed/merged.  
   - Or create a new token that carries forward the common context.  
   - **Important:** Reuse the existing token lifecycle patterns; do not invent new state transitions.

5. Log event: `DAG_PARALLEL_MERGE` with payload:
   - `parallel_group_id`
   - merge node id
   - list of branch tokens and their completion status

> **Important:**
> - If the underlying schema already has fields for grouping tokens or sessions (e.g. `group_token_id`), reuse them instead of adding new columns.  
> - Implementation must ensure that non-parallel flows remain unchanged.

---

## 5. BehaviorExecutionService — No Direct Change (But Aware)

`source/BGERP/Dag/BehaviorExecutionService.php` does **not** need new behavior types in Task 17. However:

- It must preserve behavior semantics when called in a parallel context.  
- If any behavior has implicit assumptions about "only one branch exists", they must be made parallel-safe **without changing their business meaning**.

Logging for behavior execution must continue to work for each parallel token independently.

---

## 6. Token Engine & Logging

Extend token handling utilities (wherever token state transitions are handled) to be parallel-aware.

### 6.1 Token Creation Helpers

- Add helper to create multiple child tokens in a group
- Ensure correct copying of:
  - MO reference
  - serial linkage
  - component binding context (but do not bind them here)

### 6.2 Logging

- Add structured logs for split/merge events
- Ensure all logs include:
  - `parallel_group_id`
  - original parent token id
  - list of child tokens

This is critical for traceability and debugging.

---

## 7. Seed & Configuration (0002_seed_data.php)

Even though Task 17 mainly deals with routing semantics rather than behavior:

- If there are any new **control behaviors** (like `ROUTER`, `MERGE_CONTROL`), they must be seeded in `0002_seed_data.php`.
- All such control behaviors must be `is_system = 1`, `locked = 1`, `is_active = 1`.

**Schema/Discovery Requirement:**
- Before adding any new behaviors, implementation must scan the repository and template tenant DB to confirm if similar behaviors already exist. Avoid duplicates.

All seed insertions must use `migration_insert_if_not_exists(...)` and be idempotent across tenants.

---

## 8. Safety & Edge Cases (Non-Negotiable)

1. **Linear Graphs Must Continue to Work**  
   - If `is_parallel_split = 0` and `is_merge_node = 0`, behavior must be **identical** to pre-Task 17 behavior.

2. **No Auto-Parallelization**  
   - System must never infer parallel execution by itself. Only a graph designed with explicit split/merge nodes may trigger parallel logic.

3. **Error Handling for Inconsistent Graphs**  
   - If at runtime a node is marked as merge but the expected branches cannot be found or are in invalid states, error codes such as `DAG_INVALID_PARALLEL_STATE` must be raised and logged.

4. **Rework Handling**  
   - If rework sends a token back into a parallel branch:
     - Merge semantics must still wait for all required branches to reach the merge node again.  
     - Implementation must be careful to avoid infinite loops; existing rework safeguards must remain in effect.

5. **Component Binding & QC**  
   - This task does **not** change component binding or QC rules.  
   - However, implementation must ensure that component- and QC-related behaviors can execute on parallel branches without conflicting token state.

6. **Idempotency**  
   - Migration and seed scripts must be safe to run multiple times on all tenants.

---

## 9. Implementation Notes (for AI Agents)

- **Discover schema first.** Tables/columns in this document are examples. Use repository scanning and template tenant DB to find the actual schema for tokens, DAG nodes, and routing metadata.
- Do **not** change existing behavior definitions or execution semantics. This task is structural and routing-focused.
- Do not introduce new execution modes. Only use the four modes defined in Task 16.
- Parallel split/merge must be implemented in a way that non-parallel flows continue to run exactly as before.
- All changes must be compatible with existing logging and monitoring patterns.

---

# ✅ Summary

Task 17 introduces **parallel branches and merge nodes** into Super DAG, while respecting the existing Behavior + Mode + NodeType model and Token Engine 2.0.

After Task 17:
- DAG graphs can express real-world flows where multiple operations proceed in parallel and then join back.  
- Token Engine can represent these branches as grouped tokens.  
- Routing is capable of waiting for all required branches to finish before moving forward.

This sets the foundation for:
- Task 18 — Machine Cycles & Throughput-aware Execution  
- Task 19 — SLA / Time Modeling across parallel paths  
- Task 20 — Advanced Dispatching & Skill-based Routing.