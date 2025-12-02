# Task 19.4 – Condition Engine Standardization for Non-QC Routing (Bellavier SuperDAG)

**Objective:**  
Extend and standardize the unified condition engine (introduced in Task 19.0–19.2) so that **all node types** (not only QC nodes) use the same routing semantics, field model, and UX. Remove remaining ad-hoc routing decisions that rely on manual if/else or string comparisons and bring them under the single `ConditionEvaluator` model.

This task prepares SuperDAG for time-/SLA-aware routing and future optimization (Task 20+), by making sure **every conditional decision in the graph is expressed through a single, predictable engine.**

---

## 1. Scope

Task 19.4 focuses on **non-QC routing** and **field standardization**:

- Ensure **all conditional routing** (QC and non-QC) uses `ConditionEvaluator` with the unified condition model.
- Standardize **field registry** for non-QC conditions (job, token, node, order, etc.).
- Update UI to expose **non-QC fields** in ConditionalEdgeEditor (with the same dropdown-only UX).
- Document and migrate any remaining **custom per-node routing logic** that bypasses the engine.

This task does **NOT**:

- Change machine/parallel/merge semantics.
- Implement ETA/SLA or time-based routing (that is Task 20+).
- Add new DB columns or new node types.

---

## 2. Deliverables

1. **Field Registry for Conditional Routing**  
   - File: `docs/super_dag/condition_field_registry.md`
   - Defines the allowed fields for conditions across all node types:
     - Token fields
     - Job/order fields
     - Node fields
     - QC result fields
   - Maps human-readable labels in UI → internal property paths in JSON.

2. **Condition Engine Standardization**  
   - `ConditionEvaluator.php` (UPDATED, if needed)
   - Documentation in `docs/super_dag/condition_engine_overview.md` (NEW or UPDATED)
   - All conditional routing must use **only** the unified model:
     - `type: token_property`
     - `type: job_property`
     - `type: node_property`
     - `type: qc_result_property`
     - `type: expression` (safe)

3. **Non-QC Conditional Edge UX**  
   - `ConditionalEdgeEditor.js` (UPDATED)
   - Expose non-QC fields in dropdowns according to the field registry:
     - Job priority
     - Order type
     - Product family
     - Token quantity
     - Node behavior code (if allowed)
     - Node tags / metadata keys

4. **Routing Logic Migration (Non-QC)**  
   - `DAGRoutingService.php` (UPDATED, minimal)
   - Any non-QC node that currently routes via hand-written if/else logic must be:
     - expressed as a conditional edge using the unified model, OR
     - documented as a legacy exception in the results document.

5. **Results Document**  
   - File: `docs/super_dag/tasks/task19_4_results.md`
   - Includes:
     - Summary of field registry
     - List of places where routing now uses ConditionEvaluator
     - List of legacy exceptions (if any)
     - New test scenarios added to the test catalog

---

## 3. Field Registry Specification

Create `docs/super_dag/condition_field_registry.md` with at least the following structure:

### 3.1 Token Fields

- **Label:** Token Quantity  
  **Key (internal):** `token.qty`  
  **Type:** number

- **Label:** Token Metadata: X  
  **Key Pattern:** `token.metadata.X`  
  **Type:** dynamic (string/number/boolean)

### 3.2 QC Fields (for completeness)

- **Label:** QC Status  
  **Key:** `qc_result.status`  
  **Type:** enum (`pass`, `fail_minor`, `fail_major`)

- **Label:** QC Defect Type  
  **Key:** `qc_result.defect_type`  
  **Type:** string/enum

### 3.3 Job / Order Fields

- **Label:** Job Priority  
  **Key:** `job.priority`  
  **Type:** enum (`low`, `normal`, `high`, `urgent`)

- **Label:** Job Type  
  **Key:** `job.type`  
  **Type:** enum/string

- **Label:** Order Channel  
  **Key:** `job.order_channel`  
  **Type:** enum/string (e.g. `online`, `retail`, `oem`)

- **Label:** Customer Tier  
  **Key:** `job.customer_tier`  
  **Type:** enum (`normal`, `vip`, etc.)

### 3.4 Node Fields

- **Label:** Node Behavior Code  
  **Key:** `node.behavior_code`  
  **Type:** enum (matches behavior registry)

- **Label:** Node Category  
  **Key:** `node.category`  
  **Type:** enum/string

- **Label:** Node Metadata: X  
  **Key Pattern:** `node.metadata.X`  
  **Type:** dynamic

> **Rule:** The UI and serializer MUST NOT invent new property names. They must use this registry as the single source of truth.

---

## 4. UI Updates (ConditionalEdgeEditor)

Extend `ConditionalEdgeEditor.js` to:

1. Use the field registry to populate dropdowns:
   - QC-specific fields when the edge originates from a QC node. 
   - Job/Token/Node fields for any node where such context is available.

2. Automatically select valid operators based on field type:
   - enum/string → `is`, `is not`, `in set`, `not in set`
   - number → `==`, `!=`, `>`, `>=`, `<`, `<=`
   - boolean → `is true`, `is false`

3. Prevent free-text field names:
   - Field dropdown values must be generated exclusively from the registry.

4. Serialize field selection into the correct internal property path using the mapping from the registry.

---

## 5. Routing Logic Migration (Non-QC Nodes)

Identify any places where routing decisions are currently implemented as manual logic and not via conditional edges, for example:

- branching based on `job.priority` inside `DAGRoutingService`
- special-case next-node selection based on token metadata or job type

For each such case, **prefer** the following approach:

1. Express the behavior as a graph condition using conditional edges.  
2. Use `ConditionEvaluator` in `DAGRoutingService` to evaluate those conditions.

If a behavior **must remain hard-coded** (e.g., safety controls that cannot be expressed through graph conditions yet), then:

- Leave the logic as-is.
- Document it explicitly in `task19_4_results.md` under a section like:
  - `Legacy / Hard-coded Routing Exceptions`

---

## 6. Testing & Integration with Existing Test Pack

Update `docs/super_dag/tests/qc_routing_test_cases.md` to:

- Add **at least 5 new test cases** focusing on **non-QC routing**, e.g.:
  - Priority-based routing
  - Customer tier routing
  - Product type routing
  - Node behavior-based routing

Reuse the structure and style from Task 19.2 / 19.3 test cases.

If the CLI test harness (`QCRoutingSmokeTest.php`) can be trivially extended to cover one or two non-QC cases **without changing its core design**, you may add a small number of additional smoke tests **only if it stays small and focused**.

---

## 7. Implementation Guardrails

To keep this task safe and focused:

- **Do NOT** modify:
  - `ParallelMachineCoordinator`
  - machine allocation logic
  - parallel/merge semantics
- **Do NOT** add new:
  - database columns
  - node types
  - behavior codes
- **Do NOT** introduce new routing concepts (weights, costs, multi-objective optimization).
- Backend changes are allowed **only** to:
  - move existing non-QC routing decisions onto `ConditionEvaluator`
  - remove ad-hoc string comparisons for routing
- If any existing behavior is unclear or cannot be safely migrated:
  - Leave it as-is
  - Document it in `task19_4_results.md` instead of guessing

---

## 8. Acceptance Criteria

✔ Field registry document exists and is used by the UI  
✔ ConditionalEdgeEditor uses the registry for all field dropdowns  
✔ All new and existing conditional routing (QC + non-QC) use the unified `ConditionEvaluator` model  
✔ No manual if/else routing logic remains, except explicitly documented legacy exceptions  
✔ At least 5 non-QC routing test cases are added to the test catalog  
✔ No machine/parallel/merge logic, DB schema, or new node types/behaviors are introduced in this task  
✔ Task results are summarized in `task19_4_results.md`

---

# End of Task 19.4 Specification