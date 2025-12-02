# Task 19.24.14 — Extract Graph Action Layer  
(super_dag / Lean‑Up Phase, Part of 19.24.x Consolidation)

---

## 1. Overview

This task extracts *all graph‑mutation logic* out of `graph_designer.js` and moves it into a dedicated module:

**`assets/javascripts/dag/modules/GraphActionLayer.js`**

This reduces the size of `graph_designer.js` (currently ~8,752 lines), clarifies separation of concerns, and prepares the codebase for Phase 20 (ETA/Time Engine).

---

## 2. Objective

- Make `graph_designer.js` a **pure UI orchestrator**.
- Move **ALL graph-mutating operations** into `GraphActionLayer.js`.
- Ensure **zero behavior change**.
- Ensure **Undo/Redo**, **drag grouping**, **micro‑dedupe**, and **validation previews** continue to work.

---

## 3. Scope (What Must Be Extracted)

Extract *every* function that mutates the graph:

### 3.1 Node-level actions
- `addNode()`
- `duplicateNode()`
- `deleteNode()`
- `moveNodeFinalization()` (end of drag)
- `updateNodeData()` (label, op code, qc flags)

### 3.2 Edge-level actions
- `addEdgeThroughEdgeMode()`
- `deleteEdge()`
- `updateEdgeData()` (conditions, qc, default routes)

### 3.3 Selection logic
- `deleteSelected()`
- `duplicateSelected()`
- `applyTemplateToSelected()`

### 3.4 Graph‑wide actions
- `applyTemplate()`
- `renameGraph()`
- `relabelAllNodes()`

All of the above must be moved into `GraphActionLayer.js` as pure action functions.

---

## 4. Action Layer Design

### 4.1 Module interface
The module must export:

```js
export const GraphActionLayer = {
  addNode,
  deleteNode,
  duplicateNode,
  addEdge,
  deleteEdge,
  duplicateEdge,
  updateNodeData,
  updateEdgeData,
  applyTemplate,
  relabelGraph,
};
```

It must **NOT** import or reference:
- UI elements
- event handlers
- DOM nodes
- history manager
- validator UI
- dialogs

It must only operate on:
- `cy` (cytoscape instance)
- `{ nodes, edges }` style data

---

## 5. Required Changes in `graph_designer.js`

### 5.1 Replace local inline logic with calls to `GraphActionLayer`
Examples:

```js
// BEFORE
function addNode(...) {
   const n = cy.add(...);
   saveState();
}

// AFTER
GraphActionLayer.addNode(cy, payload);
history.push(buildGraphSnapshot());
```

### 5.2 Simplify event handlers
All handlers become:

```js
buttonAddNode.onclick = () => {
  history.beginGroup('addNode');
  GraphActionLayer.addNode(cy, {...});
  history.endGroup(buildGraphSnapshot());
};
```

No logic should remain in the UI layer.

---

## 6. Safety Guard (MUST APPLY)

Before closing the task:

- Ensure **NO** action logic remains in `graph_designer.js`.
- Ensure extracted functions are **pure and side‑effect free** (except mutating cy).
- Ensure GraphHistoryManager receives snapshots only from UI layer.
- Ensure no cyclic imports:  
  `GraphActionLayer.js` must **never** import:
  - `graph_designer.js`
  - `GraphHistoryManager.js`
  - `GraphIOLayer.js`

---

## 7. Acceptance Criteria

### AC‑1 — Module Structure
- `GraphActionLayer.js` exists and contains only action functions.
- No UI code inside the module.

### AC‑2 — graph_designer.js Slimmed
- Reduce at least **400–600 lines**.
- All duplicated action logic removed.
- No direct graph mutation logic left.

### AC‑3 — Behavior Preservation
- Undo/Redo still one-step-per-action.
- Edge creation still works.
- Node creation, deletion, duplication still works.
- QC and default-routing editors still functional.

### AC‑4 — Test Stability
- `ValidateGraphTest` passes 15/15
- `SemanticSnapshotTest` passes 15/15 (no auto-update needed)
- `AutoFixPipelineTest` passes 15/15

### AC‑5 — Code Cleanliness
- No leftover legacy comments.
- No TODO blocks referencing old action code.
- No zombie functions.

---

## 8. Developer Notes for AI Agent (Cursor / Codex)

You are allowed to:
- Move, extract, and inline logic.
- Delete duplicated blocks.
- Delete unreachable branches.
- Convert callback-style code into pure functions.

You are **not allowed** to:
- Change UI behavior.
- Change shortcut bindings.
- Change validation semantics.
- Modify snapshot format.

---

## 9. Task Completion Checklist

| Item | Status |
|------|--------|
| Extract Node Actions | ☐ |
| Extract Edge Actions | ☐ |
| Extract Selection Actions | ☐ |
| Extract Template Actions | ☐ |
| Remove Mutations in graph_designer.js | ☐ |
| Slim down by 400–600 lines | ☐ |
| Run full test suite | ☐ |
| Snapshot test stable | ☐ |

---

**This file is the authoritative spec.  
Follow exactly.**
