
# Task 19.1 – Unified UX for Conditional Routing (Bellavier SuperDAG)

**Objective:**  
Transform the Conditional Edge UI into a clean, deterministic, Apple-grade UX that eliminates confusion, prevents routing mistakes, and fully aligns with the unified condition engine introduced in Task 19.0.  
This task focuses exclusively on **UX / front-end logic / graph editing experience**, without touching backend routing semantics.

---

# 1. Scope

This task updates the following areas:

- Graph Designer UI (Condition Editor Panel)
- Edge Editing Modal
- Toolbar & Inspector Layout
- “Advanced JSON” toggles
- Default/Explicit Routing Indicators
- QC-specific presets
- Removal of UI ambiguity between Decision Node vs Conditional Edge

This task does **not** modify:
- DAGRoutingService
- Token Lifecycle
- Parallel/Machine behavior
- Backend condition evaluator logic

---

# 2. Deliverables

Task 19.1 produces:

1. **New Condition Editor UI**  
   - Dropdown-driven  
   - No free text for any logic-determining field  
   - QC-aware preset conditions  
   - Required/optional indicators  
   - Explicit default route selection

2. **New Conditional Edge Serializer**  
   - Converts structured UI fields → condition model  
   - Hides JSON from normal users  
   - Auto-generates JSON behind the scenes

3. **Updated Files**
   - `graph_designer.js`
   - `conditional_edge_editor.js` (new)
   - `GraphSaver.js`
   - `routing_graph_designer_toolbar_v2.php` (if necessary)
   - `task19_1_results.md`

---

# 3. UX Requirements (MUST)

## 3.1 Remove Decision Node from UI  
- Decision Node type is fully hidden from UI  
- No button, no entry in toolbar  
- Existing decision nodes:  
  - Shown but 100% read-only  
  - Display tag: **[Legacy Decision Node]**

---

## 3.2 Conditional Edge Primary UX  
### All routing logic is placed on edges.
UI must present condition logic like this:

```
If [Field] [Operator] [Value] → Follow this edge
```

**Fields (dropdown only):**
- QC Result → Status
- QC Result → Defect Type
- Job → Priority
- Token → Quantity
- Token → Metadata.*
- Node → Metadata.*

Internally, these fields MUST map to the following condition properties:

- "QC Result → Status"      → `qc_result.status`
- "QC Result → Defect Type" → `qc_result.defect_type`
- "Job → Priority"          → `job.priority`
- "Token → Quantity"        → `token.qty`
- "Token → Metadata.X"      → `token.metadata.X`
- "Node → Metadata.X"       → `node.metadata.X`

The UI and serializer MUST NOT invent new property names. They must reuse the unified condition model from Task 19.0.

**NO free-text fields for Field names**

---

## 3.3 Operator Rules (auto-selected based on field type)

### For status (enum):
- is
- is not
- in set
- not in set

### For numbers:
- ==
- !=
- >
- >=
- <
- <=

### For lists:
- contains
- does not contain

UI chooses valid operator set automatically.

---

## 3.4 Value Field (dropdown or numeric)  
**NEVER free-text except optional comments.**

Examples:

Field = QC Status → dropdown:
- pass
- fail_minor
- fail_major

Field = Job Priority → dropdown:
- low
- normal
- high
- urgent

Field = Token Qty → numeric input

---

# 4. QC-Aware Presets (MUST)

When editing an edge that originates from a QC Node:

UI automatically shows recommended presets:

```
QC Status is [Pass] → Finish Node
QC Status in [Fail – Minor, Fail – Major] → Rework Node
```

User may:
- Customize condition  
- Add additional condition groups  
- But cannot remove QC Status entirely

---

# 5. Default Route Clarification (MANDATORY)

To prevent fallback ambiguity:

- UI must require user to explicitly mark ONE route as “Default (Else)”  
  *only if* conditions do not fully cover all possible values.

- If condition coverage is complete (e.g., all QC statuses covered), default edge is disabled.

Default edge tag appears visually:

```
[Default Route]
```

And stored explicitly:

```
edge_condition.is_default = true
```

GraphSaver MUST compile a "Default Route" into an explicit always-true condition, for example:

```json
{
  "type": "expression",
  "expression": "true"
}
```

The backend MUST NOT implement any special fallback logic based on `is_default`. It is purely a UI helper flag that becomes a normal explicit condition when serialized.

Backend must NOT infer default through ordering.

---

# 6. Advanced Mode (JSON Hidden)

### Default mode = simple UI only  
- Field  
- Operator  
- Value  
- AND/OR groups

### Advanced toggle reveals raw JSON:
- Read-only unless user has `platform_role = dev`
- Use collapsible JSON viewer
- Editable only when the current user has a developer/admin role as defined by the existing permission system (e.g. `platform_role` or equivalent). For normal users the JSON view MUST remain read-only.

This prevents accidental corruption of logic.

---

# 7. Validation (Frontend)

Before saving graph:

1. No empty conditions allowed  
2. No overlapping ranges  
3. For QC: full coverage of statuses  

Full status coverage is REQUIRED only for QC nodes. For non-QC nodes, partial coverage is allowed, but any uncovered cases MUST NOT be silently routed by the backend; they must remain unroutable unless explicitly handled.
4. If incomplete → default route must be explicitly chosen  
5. Warning for multiple edges from same node without conditions  
6. Block Decision Node creation  
7. Require at least one condition group per edge (except default)

---

# 8. File-Level Implementation Details

## `graph_designer.js`
- Remove Decision node from toolbar
- Add openConditionEditor() for conditional edges
- Display condition badges inline on edges
- Detect QC Node and auto-generate presets

## `conditional_edge_editor.js` (new)
- Contains UI logic for:
  - field/operator/value editors
  - condition grouping  
  - default route toggle
  - field-type → operator mapping

## `GraphSaver.js`
- Convert structured UI → JSON condition
- Validate missing coverage
- Serialize `is_default`

## `routing_graph_designer_toolbar_v2.php`
- Hide Decision Node button

---

# 9. Acceptance Criteria

✔ All routing logic must now be set on edges only  
✔ No free-text condition fields  
✔ QC routing is clearer and safer  
✔ Decision Node removed from creation flow  
✔ Advanced Mode hides JSON from normal users  
✔ Conditions are deterministic and machine-readable  
✔ Graph cannot be saved if QC routing incomplete  
✔ UI is as simple as iOS Shortcuts

---

# End of Task 19.1 Specification
# 8. File-Level Implementation Details

## 8.5 Implementation Guardrails

- Do NOT modify `DAGRoutingService`, `ConditionEvaluator`, `TokenLifecycleService`, or machine/parallel/merge logic in this task.
- This task may only:
  - adjust frontend JavaScript and PHP view templates listed in Section 8,
  - call existing backend APIs (e.g. `dag_routing_api.php`),
  - and serialize conditions according to Task 19.0.
- If a backend change seems necessary, document it under `task19_1_results.md` as a follow-up item; do NOT implement it in Task 19.1.