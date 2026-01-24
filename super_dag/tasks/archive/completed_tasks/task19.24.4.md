

# Task 19.24.4 — API Slimming (Phase 2: Deep Cleanup)

## Objective
Reduce size and complexity of `dag_routing_api.php` by removing:
- Legacy PARAM parsing blocks
- Unreachable code paths
- Inline utility functions duplicated in Helper classes
- Dead branches from deprecated features

This is a **non-functional change** only — behavior MUST NOT change.

---

## Scope of Removal (Phase 2)

### 1. Remove Legacy PARAM Parsing Blocks
The following chunks can be safely removed (already replaced by `loadGraphState()` + `$requestBody` parsing):

- `$graphId = $_POST['graphId'] ?? ...`
- `$action = $_REQUEST['action'] ?? ...`
- Legacy edge updates via `$_POST['edges']`
- Legacy node updates via `$_POST['nodes']`

**Target:** approx. 180–250 lines.

---

### 2. Remove Old Graph Serialization Chunks
The following sections are unused after Task 19.x:

- Manual JSON encoding for nodes/edges
- “Graph JSON v1” fallback (deprecated in 18.3)
- Direct `$db->fetchAll("SELECT ...")` serialization

**Target:** approx. 120–160 lines.

---

### 3. Remove Deprecated Inline Utility Functions
These functions duplicate logic in Helper classes and can be removed:

- `sanitizeGraphInput()`
- `normalizeNodesForSave()`
- `normalizeEdgesForSave()`
- `rewriteTempIds()`
- `expandQCPolicy()`

Moved to:
- `GraphHelper`
- `SemanticIntentEngine`
- `ApplyFixEngine`

**Target:** approx. 200–300 lines.

---

### 4. Remove Unreachable Branches
Example patterns that should be removed:

- `if ($action === 'graph_load_v1') { ... }`
- `switch($action)` branches that have no callers
- Fallback `graph_load_runtime` code (superseded by new handler)
- Any `if (false) { ... }` debug guard blocks

**Expected:** 300–400 lines.

---

## Expected Result

By end of 19.24.4:
- `dag_routing_api.php` should drop from ~4,200 lines → ~3,200 lines
- Core action handlers remain clean:
  - `graph_load`
  - `graph_validate`
  - `graph_autofix`
  - `graph_apply_fixes`
  - `graph_save`
  - `graph_save_draft`
  - `graph_publish`
- All validation + autofix + intent logic fully handled by engines
- No duplicate logic between API and engine layer

---

## Tests Required After Cleanup
Run:

```
php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php
php tests/super_dag/AutoFixPipelineTest.php
```

All must pass (15/15).

No regression allowed.

---

## Next Task
**Task 19.24.5 — JavaScript Slimming (Phase 1: Remove Redundant Frontend Helpers)**  
Focuses on slimming:
- `graph_designer.js`
- `ConditionalEdgeEditor.js`
- `GraphSaver.js`

Priority: remove dead code, duplicate helper logic, unreachable branches.