# Task 19.24.6 — Undo/Redo State Map

**Date:** 2025-12-18  
**Purpose:** Document the current state of undo/redo system in SuperDAG Graph Designer

---

## 1. State Sources

### 1.1 Canvas (Cytoscape)

**Primary Source:** Cytoscape.js graph instance (`cy`)

**State Components:**
- **Nodes:** All node data including:
  - `id`, `dbId`, `nodeCode`, `label`, `nodeType`
  - `workCenterCode`, `estimatedMinutes`, `teamCategory`
  - `productionMode`, `wipLimit`, `concurrencyLimit`
  - `assignmentPolicy`, `preferredTeamId`, `allowedTeamIds`, `forbiddenTeamIds`
  - `isParallelSplit`, `isMergeNode`
  - `formSchemaJson`, `qcPolicy`, `ioContractJson`
  - `position` (x, y coordinates)
- **Edges:** All edge data including:
  - `id`, `dbId`, `source`, `target`
  - `edgeType`, `edgeCode`, `edgeName`
  - `edgeCondition` (conditional routing)
  - `isDefault`, `priority`

**State Capture Method:**
```javascript
const state = {
    nodes: cy.nodes().map(n => ({
        ...n.data(),
        position: n.position()
    })),
    edges: cy.edges().map(e => e.data())
};
```

### 1.2 Side Panel (Properties Panel)

**Source:** Properties form in `#properties-panel`

**State Components:**
- Node properties (work center, team, production mode, etc.)
- Edge properties (edge type, condition, priority, etc.)

**State Capture:** Changes are applied to Cytoscape nodes/edges, then `saveState()` is called

### 1.3 Conditional Edge Editor

**Source:** `ConditionalEdgeEditor` module

**State Components:**
- Condition groups (OR groups)
- Conditions within groups (AND conditions)
- Default route flag

**State Capture:** After saving condition, `performEdgeSave()` updates edge data and calls `saveState()`

---

## 2. History Entry Points

### 2.1 Node Operations

| Operation | Function | Location | Calls `saveState()` |
|-----------|----------|----------|---------------------|
| Add node | `addNode()` | Line 4313 | ✅ Line 4371 |
| Delete node | `deleteSelected()` | Line 4541 | ✅ Line 4581 |
| Update node properties | `updateNodeProperties()` | Line 6120 | ✅ Line 6126 |

### 2.2 Edge Operations

| Operation | Function | Location | Calls `saveState()` |
|-----------|----------|----------|---------------------|
| Add edge | Edge creation handler | Line 4440 | ✅ Line 4447 |
| Delete edge | `deleteSelected()` | Line 4541 | ✅ Line 4581 |
| Update edge properties | `performEdgeSave()` | Line 7071 | ✅ Line 7098 |
| Update edge condition | `performEdgeSave()` | Line 7071 | ✅ Line 7098 |

### 2.3 Graph Operations

| Operation | Function | Location | Calls `saveState()` |
|-----------|----------|----------|---------------------|
| Load graph | `loadGraph()` | Line 627 | ✅ Line 627 |
| Clear graph | `clearGraph()` | Line 831 | ✅ Line 831 |
| Apply fixes | `applyFixes()` | Line 7396 | ✅ Line 7524 |

### 2.4 Auto-Save Operations

| Operation | Function | Location | Calls `saveState()` |
|-----------|----------|----------|---------------------|
| Auto-save trigger | `scheduleAutoSave()` | Various | ✅ Via `saveState()` |

---

## 3. History Gaps (Actions That Don't Save State)

### 3.1 UI-Only Changes

**Not Saved:**
- Node position changes (drag & drop) - **Note:** Position is saved in state, but individual drags don't trigger `saveState()`
- Selection changes
- Zoom/pan operations
- Panel visibility toggles

**Reason:** These are UI-only changes that don't affect graph structure or properties

### 3.2 Validation/Autofix Operations

**Not Saved:**
- `validateGraph()` - Read-only operation
- `showAutoFixDialog()` - Only shows dialog, doesn't change graph
- `applyFixes()` - **Note:** This DOES save state after applying fixes (line 7524)

**Reason:** Validation is read-only. Autofix only saves state after user confirms and applies fixes.

---

## 4. State Object Structure

### 4.1 History Entry Format

```javascript
{
    nodes: [
        {
            id: "n_new_1234567890",
            dbId: 123,
            nodeCode: "OP001",
            label: "Operation 1",
            nodeType: "operation",
            workCenterCode: "WC001",
            estimatedMinutes: 30,
            teamCategory: "production",
            productionMode: "batch",
            wipLimit: 10,
            concurrencyLimit: 5,
            assignmentPolicy: "auto",
            preferredTeamId: null,
            allowedTeamIds: null,
            forbiddenTeamIds: null,
            isParallelSplit: false,
            isMergeNode: false,
            formSchemaJson: null,
            qcPolicy: null,
            ioContractJson: null,
            position: { x: 300, y: 150 }
        },
        // ... more nodes
    ],
    edges: [
        {
            id: "edge_123",
            dbId: 456,
            source: "n_new_1234567890",
            target: "n_new_1234567891",
            edgeType: "conditional",
            edgeCode: "EDGE001",
            edgeName: "Pass Route",
            edgeCondition: {
                type: "or",
                groups: [
                    {
                        conditions: [
                            {
                                type: "token_property",
                                property: "qc_result.status",
                                operator: "==",
                                value: "pass"
                            }
                        ]
                    }
                ]
            },
            isDefault: false,
            priority: 0
        },
        // ... more edges
    ]
}
```

### 4.2 State Restoration

**Method:** `GraphHistoryManager.restoreState(cy, state)`

**Process:**
1. Set `isRestoringState = true` (prevents saveState() during restoration)
2. Remove all current elements: `cy.elements().remove()`
3. Add nodes with all data properties preserved
4. Add edges with all data properties preserved
5. Update button states
6. Set `isRestoringState = false`

**Key Improvement (Task 19.24.6):**
- Previously: Only restored basic fields (id, label, nodeType, nodeCode, dbId)
- Now: Restores ALL node/edge data properties using spread operator (`{...nodeData}`)

---

## 5. Guard Logic (Task 19.24.6)

### 5.1 Async Operation Guard

**Flag:** `isAsyncOperationInProgress`

**Purpose:** Prevent undo/redo during async operations that modify graph state

**Operations Guarded:**
- `validateGraph()` - Disables undo/redo during validation
- `showAutoFixDialog()` - Disables undo/redo during autofix API call
- `applyFixes()` - Disables undo/redo during apply fixes API call

**Implementation:**
```javascript
// Set flag before async operation
isAsyncOperationInProgress = true;
updateUndoRedoButtons();

// Re-enable after operation completes (success or error)
isAsyncOperationInProgress = false;
updateUndoRedoButtons();
```

### 5.2 Undo/Redo Guard

**Location:** `undo()` and `redo()` functions

**Check:**
```javascript
if (isAsyncOperationInProgress) {
    notifyWarning('Undo/Redo is disabled while validation or auto-fix is in progress');
    return;
}
```

### 5.3 Button State Update

**Location:** `updateUndoRedoButtons()`

**Logic:**
```javascript
if (isAsyncOperationInProgress) {
    // Disable all undo/redo buttons
    $('#canvas-btn-undo, #btn-undo-v2').prop('disabled', true);
    $('#canvas-btn-redo, #btn-redo-v2').prop('disabled', true);
    return;
}
// Otherwise, use GraphHistoryManager to update buttons
```

---

## 6. History Stack Management

### 6.1 Stack Structure

**Storage:** `GraphHistoryManager.historyStack` (Array)

**Index:** `GraphHistoryManager.historyIndex` (current position)

**Max Size:** 50 entries (configurable via `maxHistory` option)

### 6.2 Stack Operations

**Save State:**
- Remove future states if in middle of history
- Push new state to stack
- Increment index
- Trim if exceeds max size

**Undo:**
- Decrement index
- Restore state at new index

**Redo:**
- Increment index
- Restore state at new index

**Clear:**
- Reset stack to empty
- Reset index to -1

---

## 7. Known Issues & Improvements

### 7.1 Fixed in Task 19.24.6

✅ **State Restoration:** Now preserves all node/edge properties (not just basic fields)  
✅ **Guard Logic:** Prevents undo/redo during async operations  
✅ **Button State:** Disables buttons during async operations  

### 7.2 Remaining Considerations

⚠️ **Node Position Changes:** Individual drag operations don't trigger `saveState()`  
   - **Impact:** Position changes are only saved when other properties change  
   - **Consideration:** May want to debounce position saves for better UX

⚠️ **Conditional Edge Editor:** State is saved after clicking "Save" in editor  
   - **Current:** Works correctly, but user must explicitly save  
   - **Consideration:** Could auto-save on condition change (with debounce)

---

## 8. Testing Scenarios

### 8.1 Basic Undo/Redo

1. **Add Node → Undo → Redo**
   - ✅ Node added → `saveState()` called
   - ✅ Undo removes node
   - ✅ Redo restores node

2. **Add Edge → Undo → Redo**
   - ✅ Edge added → `saveState()` called
   - ✅ Undo removes edge
   - ✅ Redo restores edge

3. **Update Node Properties → Undo → Redo**
   - ✅ Properties updated → `saveState()` called
   - ✅ Undo restores previous properties
   - ✅ Redo restores updated properties

4. **Update Edge Condition → Undo → Redo**
   - ✅ Condition updated → `saveState()` called
   - ✅ Undo restores previous condition
   - ✅ Redo restores updated condition

### 8.2 Autofix Integration

1. **Edit Graph → Validate → Autofix → Apply → Undo → Redo**
   - ✅ Graph edited → `saveState()` called
   - ✅ Validate (read-only, no state change)
   - ✅ Autofix (shows dialog, no state change)
   - ✅ Apply fixes → `saveState()` called (line 7524)
   - ✅ Undo restores graph before fixes
   - ✅ Redo restores graph after fixes

2. **Guard Logic Test:**
   - ✅ Undo/redo disabled during validate
   - ✅ Undo/redo disabled during autofix API call
   - ✅ Undo/redo disabled during apply fixes
   - ✅ Undo/redo re-enabled after operations complete

---

## 9. Summary

**State Sources:**
- Canvas (Cytoscape) - Primary source
- Side Panel - Updates canvas, then saves state
- Conditional Edge Editor - Updates edge, then saves state

**History Entry Points:**
- ✅ All node operations (add, delete, update)
- ✅ All edge operations (add, delete, update)
- ✅ Graph operations (load, clear, apply fixes)
- ✅ Auto-save triggers

**Guard Logic:**
- ✅ Prevents undo/redo during async operations
- ✅ Disables buttons during async operations
- ✅ Re-enables after operations complete

**State Preservation:**
- ✅ All node properties preserved
- ✅ All edge properties preserved
- ✅ Position information preserved

---

**Document Status:** ✅ Complete  
**Last Updated:** 2025-12-18

