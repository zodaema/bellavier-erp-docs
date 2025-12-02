

# Task 19 – QC Routing Safety & Unified Condition Engine (Bellavier SuperDAG)

**Objective:**  
Transform the QC routing and condition system into a fully deterministic, unified, luxury‑grade workflow engine that reflects Bellavier Group’s architectural values: precision, traceability, predictability, and Apple‑class UX.  
This task establishes the foundation for all routing correctness and prevents ambiguous behavior in production.

---

# 1. Scope
This task updates **backend, frontend, database rules, UI behaviors, and validation layers**, focusing on:

- QC → Routing integration  
- Deterministic condition evaluation  
- Removal of Decision Node (deprecated)  
- Unified condition engine  
- No fallback routing rules  
- Mandatory condition coverage  
- Metadata standardization  
- Event logging  
- UX simplification (no free-text affecting logic)

All changes MUST be backward‑safe.  
Legacy graphs can still be loaded, but cannot create new Decision nodes.

---

# 2. Deliverables
Task 19 produces:

1. `ConditionEvaluator.php` – unified condition engine  
2. `QCMetadataNormalizer.php` – standardizes qc_result format  
3. Updated:
   - `DAGRoutingService.php`
   - `BehaviorExecutionService.php`
   - `dag_routing_api.php`
   - `GraphSaver.js`
   - `graph_designer.js`
4. New graph validation rules
5. QC UI update (no free text, dropdown‑only)
6. Migration to mark decision node deprecated
7. Documentation:
   - `task19_results.md`

---

# 3. Rules (MUST Implement)

## 3.1 QC Result Standardization
When QC completes:

### Write standardized metadata:
```
token.metadata.qc_result = {
  status: "pass" | "fail_minor" | "fail_major",
  defect_type: string|null,
  severity: string|null,
  notes: string,
  operator_id: int,
  timestamp: ISO8601
}
```

### Write event log:
```
event_type = "QC_COMPLETED"
payload_json = qc_result + form attachments
```

No free text for status or defect fields allowed.  
UI must use dropdowns only.

---

## 3.2 Remove Decision Node (Deprecated)
- Disable creation in UI (hide button)
- Block in API (`node_type = decision`)
- Keep loading legacy nodes → read‑only
- Auto‑migration:
  - For each decision rule:
    - convert into equivalent conditional edges

---

## 3.3 Unified Condition Engine
Create `ConditionEvaluator.php`:

- Supports:
  - token_property
  - job_property
  - node_property
  - qc_result.*
  - numeric comparison
  - boolean
  - IN / NOT IN
  - expression (safe evaluable)
- Pure function: `(condition, context) → boolean`
- Used in:
  - conditional edges
  - QC routing
  - future rule systems

All existing condition logic must be updated to call this evaluator.

---

## 3.4 QC Routing Safety Rules
### NO FALLBACK
If no condition matches:
```
RoutingError: No route matches QC result (status = X)
```
Token is set to:
```
state = "error_unroutable"
```

### Mandatory Coverage
Before saving graph:

If QC has possible statuses:
```
[pass, fail_minor, fail_major]
```

Then outgoing edges must cover ALL the statuses.

If missing:
```
GraphValidationError: Missing routing for QC status = fail_major
```

### Overlap Prevention
If two edge conditions overlap in range:
```
GraphValidationError: Conflicting conditional edges (overlap)
```

---

## 3.5 Conditional Edge UX Rewrite
UI changes:

- Condition field = dropdown only (no text input)
- Operators = limited by type
- Values = dropdown or numeric field (never free text)
- “Advanced JSON” is hidden behind toggle
- When selecting “QC Status”, preset values appear automatically

Example UI:
```
When QC Status is [Pass]
When QC Status is [Fail – Minor]
When QC Status is [Fail – Major]
```

---

## 3.6 Graph Validation Layer
Implement new validator:

- qc condition coverage required
- no fallback allowed
- no edge with empty condition
- no overlapping condition range
- no Decision nodes
- merge node must have ≥ 2 incoming edges
- parallel split must have ≥ 2 outgoing edges

Must run during:
- graph save
- graph publish
- graph versioning

---

## 3.7 Routing Engine Refactor
Modify `selectNextNode()`:

1. Fetch all outgoing edges
2. Evaluate each via `ConditionEvaluator`
3. If multiple match → error (ambiguous)
4. If none match → error (unroutable)
5. Follow matched edge exactly

Remove:
- “first edge fallback”
- QC special-case string matching
- default-routing behavior

---

# 4. Files to Modify

## Backend
- `source/BGERP/DAG/ConditionEvaluator.php` (new)
- `source/BGERP/DAG/QCMetadataNormalizer.php` (new)
- `source/BGERP/Service/DAGRoutingService.php`
- `source/BGERP/Service/BehaviorExecutionService.php`
- `source/dag_routing_api.php`

## Frontend
- `assets/javascripts/dag/graph_designer.js`
- `assets/javascripts/dag/modules/GraphSaver.js`
- `assets/javascripts/dag/ui/conditional_editor.js` (new or patched)

## DB
- migration to mark decision node deprecated
- no schema change to routing tables required

## Docs
- `docs/super_dag/tasks/task19_results.md`

---

# 5. Acceptance Criteria

✔ QC results always produce deterministic route  
✔ All routing decisions logged  
✔ No fallback behavior  
✔ QC status is always structured  
✔ Decision node removed from UI  
✔ Condition evaluator is unified  
✔ Graph validator prevents invalid setups  
✔ Conditional editor has no free-text fields  
✔ Existing graphs still load (read‑only decision nodes)

---

# 6. Notes for AI Agent

- DO NOT invent new fields  
- DO NOT modify machine allocation logic  
- DO NOT modify parallel/merge logic  
- DO NOT remove legacy decision nodes (read-only allowed)  
- ALWAYS route using ConditionEvaluator  
- ALWAYS validate graph before saving  
- If unsure how to convert a rule → ask or mirror existing condition patterns  
- Maintain backward compatibility

---

## 7. Anti-Magic / Strict Guardrails (DO NOT be creative)

To avoid over-creative refactors or unintended design changes, this task must respect the following hard limits:

1. **Do NOT change QC status enum**
   - Allowed values are exactly:
     - `pass`
     - `fail_minor`
     - `fail_major`
   - Do NOT rename, split, merge, or add new QC statuses in this task.
   - If you think a new status is needed, document it in `task19_results.md` under a “Future Ideas” section only.

2. **Do NOT change database schema (except decision deprecation marker)**
   - No new columns in `routing_node`, `routing_edge`, `flow_token`, or QC-related tables.
   - No column type changes.
   - The only DB-related change allowed is:
     - A migration that marks Decision Nodes as deprecated (e.g. via flags/metadata), without dropping tables or columns.

3. **Do NOT refactor outside the listed methods/files**
   - Only modify the files listed in Section 4.
   - Inside those files, prefer **minimal, localized changes**:
     - Do NOT rename existing public methods.
     - Do NOT move large blocks of code to new classes “for cleanliness”.
     - Do NOT change method signatures used by other parts of the system.
   - If you need a new helper method, keep it small and focused.

4. **Do NOT alter machine, parallel, or merge semantics**
   - Do NOT change:
     - machine allocation logic
     - parallel split/merge behavior
     - merge policies (`ALL`, `ANY`, `AT_LEAST`, `TIMEOUT_FAIL`)
   - You may ONLY reroute how QC nodes decide the **next node**, not how machines or parallel branches are scheduled.

5. **Decision Node migration MUST be conservative**
   - If an existing Decision node has a simple “if/else” rule that maps clearly to edge conditions:
     - You may auto-convert it to conditional edges.
   - If the Decision rule is complex or ambiguous:
     - Do NOT guess.
     - Leave the node as legacy, read-only.
     - Add a note in `task19_results.md` under “Unmigrated Decision Nodes” explaining why it was not auto-converted.

6. **Existing graphs must keep working**
   - Existing published graphs must:
     - Still load in the UI.
     - Still be executable with their current behavior, except where QC routing is explicitly made safer and more deterministic.
   - If strict validation would block an existing graph:
     - Implement validation as a **warning only** for existing versions.
     - Enforce blocking validation only for:
       - new graphs
       - new versions saved after Task 19.

7. **No new behavior types or node types**
   - Do NOT introduce new `behavior_code`, `node_type`, or new execution modes in this task.
   - Reuse existing behaviors and types only.

8. **JSON formats must stay backward-compatible**
   - `edge_condition`, `qc_policy`, `form_schema_json`, and `qc_result` formats:
     - MUST remain readable for existing data.
     - You may extend them in a backward-compatible way (add non-required fields), but do NOT remove or rename existing keys.
   - If you add fields, clearly document them in `task19_results.md`.

9. **Keep diffs small and reviewable**
   - Prefer adding small, focused functions (e.g. `ConditionEvaluator::evaluate`) over rewriting large methods.
   - Avoid “big-bang” rewrites of core services.
   - The goal of Task 19 is **safety and determinism**, not general code cleanup.

10. **If unsure, document instead of guessing**
    - If you are not 100% sure how to convert a rule, how to map a legacy condition, or how QC currently behaves:
      - Do NOT invent new logic.
      - Leave the legacy behavior as-is.
      - Document the uncertainty and the location (file + method + line) in `task19_results.md` for human review.

# End of Task 19 Specification