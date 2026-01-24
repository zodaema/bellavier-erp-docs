

# Task 18 — Machine Cycles & Throughput-Aware Execution

**Status:** NEW  
**Category:** Super DAG – Execution Layer (Phase 7)  
**Depends on:**  
- Task 1–14 (Behavior & Execution Engine, Session Engine, Routing Integration)  
- Task 15 (Node Behavior Binding & Graph Standardization)  
- Task 16 (Execution Mode Binding & NodeType Model)  
- Task 17 (Parallel Node Execution & Merge Semantics)

---

# 🎯 Objective

Introduce **machine cycle awareness and throughput constraints** into Super DAG execution,
so that:

- Nodes can be bound to specific machine groups / machines
- Each machine has **cycle time**, **capacity**, and **concurrency limits**
- Token routing respects machine availability
- Parallel branches become **physically realistic** (not just logically parallel)
- Time & SLA modeling (Task 19) can use actual machine cycle data as a foundation

This task is **structural & scheduling-focused** — it must not change the business meaning
of existing behaviors (CUT, EDGE, STITCH, QC, etc.).

---

# 🧩 Core Concepts

## 1. Machine vs Work Center

- **Work Center** = logical station / team location (CUT line, EDGE line, STITCH table)
- **Machine** = physical asset at/under a work center (e.g. cutting press #1, sewing machine #3)

A Work Center can have:
- 0 machines (fully manual operations)
- 1 machine
- multiple machines of the same type

This task introduces **machine-level throughput** on top of existing Work Center logic.

## 2. Machine Cycle & Capacity

For each machine we care about:
- `cycle_time` — how long it takes to process ONE unit or ONE batch
- `batch_capacity` — maximum units/batch per cycle (for BATCH modes)
- `concurrency_limit` — how many tokens can be processed in parallel (usually 1 per machine)

These values will drive:
- estimated time for Task 19 (SLA modeling)
- runtime queueing logic (who gets to use the machine next)

## 3. Scheduling Model (Simplified)

Task 18 does **not** implement a full-blown scheduling optimizer. It adds:

- a notion of **"machine slot"**: a token can be either waiting for machine or using machine
- basic **queueing** at machine-level (FIFO or existing policy)
- integration of machine cycle time into token execution metadata

---

# 📦 Deliverables

## 1. Schema & Migration (Machine & Token Metadata)

Create tenant migration:

`database/tenant_migrations/2025_12_18_machine_cycle_support.php`

### 1.1 Machine / Equipment Schema

> **Schema/Discovery Requirement:**  
> Before writing any SQL, implementation must scan the repository & template tenant DB
> to discover existing tables related to machines/equipment, e.g.:
> - `machine`, `equipment`, `work_center_machine`, `wc_equipment`, etc.  
> If a suitable machine-related table already exists, **reuse it** and extend it minimally.  
> Only if no machine concept exists at all may a new table be introduced.

New or extended fields (adapt to actual table name):

- `machine_code` (string, unique per tenant)
- `work_center_code` or FK to work_center
- `cycle_time_seconds` (INT) — average cycle time per unit or batch
- `batch_capacity` (INT, default 1)
- `concurrency_limit` (INT, default 1)
- `is_system` (TINYINT(1), default 0)
- `is_active` (TINYINT(1), default 1)

### 1.2 Token / Session Schema

Extend token-related table(s) (e.g. `flow_token`, `token`, or equivalent) with machine metadata.

**Example (must adapt to actual schema using discovery):**

- `machine_code` (nullable string)
- `machine_cycle_started_at` (nullable datetime)
- `machine_cycle_completed_at` (nullable datetime)

Rules:
- Non-machine-based nodes keep these fields NULL.
- Machine data must be additive and not break existing flows.

---

## 2. Machine Registry & Allocation Service

Create a dedicated service class for machine-related logic, or extend an existing one.

**New class (if none exists yet):**

`source/BGERP/SuperDAG/MachineRegistry.php`

Responsibilities:
- Discover available machines for a given work_center + node_type
- Provide cycle_time, batch_capacity, concurrency_limit
- Provide basic allocation decision: which machine to assign

**New/extended class for allocation:**

`source/BGERP/SuperDAG/MachineAllocationService.php`

Responsibilities:
- Allocate a machine for a given token (at a given node)
- Enforce `concurrency_limit` (no more than N active tokens per machine)
- Return selected machine_code or NULL if no machine is required

> **Important:**  
> If an existing service already partially handles machine assignment, extend it instead of creating duplicates.

---

## 3. Node-Level Machine Configuration

Augment DAG node configuration (in `routing_node` or equivalent) to allow machine binding.

### 3.1 Node Fields

Add fields (to `routing_node` or node-metadata table):

- `machine_binding_mode` (VARCHAR(50), nullable):  
  - `NONE` (default)  
  - `BY_WORK_CENTER` (select automatically from machines under the node's work_center)  
  - `EXPLICIT` (explicit machine_code list)
- `machine_codes` (TEXT, nullable): comma-separated or JSON list of allowed machines (for EXPLICIT mode)

> Use discovery to confirm if similar configuration fields already exist; reuse them when possible.

### 3.2 Graph Designer UI

In `graph_designer.js` node properties panel:

- Add section: **Machine Settings**
- Fields:
  - `Binding mode` (select: None / Use work center machines / Explicit machine list)
  - If `Explicit` → show multi-select list of machine codes

Validation:
- If `EXPLICIT` → list cannot be empty
- If node behavior/mode type is not compatible with machines (e.g. purely manual QC), UI should warn or disallow machine binding.

All config must be saved via `dag_routing_api.php` and stored in `routing_node`.

---

## 4. dag_routing_api.php — Machine Metadata Handling

Update `source/dag_routing_api.php`:

- `node_create` / `node_update`:
  - Accept and persist `machine_binding_mode`, `machine_codes`
  - Validate that referenced machine codes exist (if EXPLICIT)
- `loadGraphWithVersion`:
  - Include machine-related fields in node JSON for the editor

Error handling:
- Return explicit error codes/messages such as:
  - `DAG_INVALID_MACHINE_CONFIG` — invalid binding mode or missing machine list
  - `DAG_MACHINE_NOT_FOUND` — explicit code not found in registry

All errors must be logged using the existing logging helper.

---

## 5. Execution Logic — Machine-Aware Token Start

Extend `DagExecutionService` (or relevant execution service) to be machine-aware at **node start** time.

### 5.1 When a Token Enters a Machine-Bound Node

When a token is routed to a node that has `machine_binding_mode` ≠ `NONE`:

1. Use `MachineAllocationService` to determine:
   - Which machine will process this token (if any available)
   - Whether the token must **wait in queue** for a machine slot

2. If a machine is immediately available:
   - Assign `machine_code` to the token
   - Set `machine_cycle_started_at` = now  
   - (Optionally) derive an expected completion time using `cycle_time_seconds`

3. If no machine is available:
   - Keep token in a **waiting state** appropriate for your existing lifecycle (e.g. `QUEUED`, `PENDING_MACHINE`)  
   - **Do not invent new status codes**; reuse existing lifecycle enums and adapt them as needed.

4. Machine release:
   - When the node is completed for a token:  
     - Set `machine_cycle_completed_at` = now  
     - Free a slot on the assigned machine (decrement active count)

> **Important:**  
> Non-machine-bound nodes must continue to behave exactly as before.

---

## 6. Time Engine & Metrics Integration (Lightweight)

Task 18 must **not** introduce a heavy SLA/metrics layer yet, but it should:

- Log machine cycle durations:  
  `machine_cycle_completed_at - machine_cycle_started_at`
- Make this data available for Task 19 to build upon

If a time engine or duration logging already exists, extend it to:
- compute and expose per-machine cycle statistics
- remain backward compatible for nodes without machines

---

## 7. Seed & Defaults (0002_seed_data.php)

Update `database/tenant_migrations/0002_seed_data.php` to:

- Seed minimal **system machine records** for template tenants if your architecture requires them:  
  e.g., one default machine per key work center (CUT, EDGE, STITCH)  
- Seed default `machine_binding_mode = NONE` for all existing nodes

> **Rule:**  
> - Do not assume every tenant has machines.  
> - Seed must be conservative and safe; having no machines bound must remain valid.

All seed operations must use `migration_insert_if_not_exists(...)` and be idempotent.

---

## 8. Safety & Edge Cases (Non-Negotiable)

1. **Non-machine nodes must remain unchanged**  
   - Nodes with `machine_binding_mode = NONE` must behave exactly as in Task 17.

2. **No Forced Machines**  
   - System must not automatically bind machines to all nodes.  
   - Machine binding is opt-in via DAG configuration.

3. **Graceful Degradation**  
   - If machine-related config is invalid or missing, execution must fall back to existing node execution behavior (or fail fast with clear errors for obviously invalid config).

4. **Parallel + Machine**  
   - Parallel branches may each bind to different machines.  
   - Merge semantics from Task 17 must continue to work without modification.

5. **Rework**  
   - If rework sends a token back to a machine-bound node, machine allocation must be executed again, respecting concurrency limits.

6. **Idempotency**  
   - Migration and seed scripts must be safe to run on all tenants multiple times.

---

## 9. Implementation Notes (for AI Agents)

- **Always discover actual schema first.**  
  - Do not assume table/column names from this document; scan the repository and template DB.
- **Do not change existing behavior or execution_mode semantics.**  
  - This task is about adding machine context and throughput constraints only.
- **Do not add new execution modes.**  
  - Only use the four modes defined in Task 16.
- **Reuse existing lifecycle enums and logging patterns.**  
  - If the system already has `QUEUED`, `IN_PROGRESS`, etc., integrate machine logic into those states.
- **Keep the system operational even if no machines are configured.**

---

# ✅ Summary

Task 18 adds **machine cycle awareness** and **throughput constraints** to Super DAG execution
without changing existing behavior semantics.

After Task 18:
- Nodes can be associated with real machines and cycle times
- Token routing will respect machine capacity and concurrency
- Parallel branches will reflect realistic physical execution limits
- Machine cycle data will be available for Task 19 (SLA / time modeling)

This prepares the system for:
- Task 19 — SLA / Time Modeling across Work Centers and Machines  
- Task 20 — Advanced Dispatching & Skill-based Routing that accounts for machine availability.