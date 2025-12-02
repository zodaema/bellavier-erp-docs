# Task 19.24.8 — GraphHistoryManager Current Behavior Analysis

**Date:** 2025-12-18  
**Purpose:** Document current behavior of GraphHistoryManager before refactoring

---

## 1. Current Methods

### 1.1 Core Methods

| Method | Signature | Behavior |
|--------|-----------|----------|
| `saveState(cy)` | `saveState(cy: Cytoscape)` | Saves current graph state to history stack |
| `undo(cy)` | `undo(cy: Cytoscape) => boolean` | Undoes last action, restores state to cytoscape directly |
| `redo(cy)` | `redo(cy: Cytoscape) => boolean` | Redoes last undone action, restores state to cytoscape directly |
| `restoreState(cy, state)` | `restoreState(cy: Cytoscape, state: Object)` | Restores state to cytoscape (internal) |
| `clear()` | `clear() => void` | Clears history stack |
| `canUndo()` | `canUndo() => boolean` | Checks if undo is available |
| `canRedo()` | `canRedo() => boolean` | Checks if redo is available |
| `updateButtons()` | `updateButtons() => void` | Updates undo/redo button states |
| `getHistorySize()` | `getHistorySize() => number` | Returns stack size |
| `getHistoryIndex()` | `getHistoryIndex() => number` | Returns current index |
| `isRestoring()` | `isRestoring() => boolean` | Checks if currently restoring |

### 1.2 Missing Methods (Required for Task 19.24.8)

- ❌ `push(snapshot)` - Push snapshot to stack
- ❌ `markBaseline()` - Mark current state as baseline (saved state)
- ❌ `isModified()` - Check if current state differs from baseline

---

## 2. State Structure

### 2.1 Current State Format

```javascript
{
    nodes: [
        {
            ...nodeData,  // All node data properties
            position: { x: number, y: number }
        }
    ],
    edges: [
        {
            ...edgeData  // All edge data properties
        }
    ]
}
```

### 2.2 What's NOT Stored

- ❌ `cy.json()` full structure
- ❌ Selection state (selected node/edge IDs)
- ❌ Viewport state (pan, zoom)
- ❌ Graph ID
- ❌ Timestamp

---

## 3. Stack Structure

### 3.1 Internal Structure

```javascript
this.historyStack = [];        // Array of state objects
this.historyIndex = -1;        // Current position pointer
this.maxHistory = 50;          // Maximum stack size
this.isRestoringState = false; // Guard flag to prevent saveState during restore
```

### 3.2 Stack Behavior

- **Push:** Removes future states if in middle of history (`slice(0, index + 1)`)
- **Undo:** Decrements index, restores state directly to cytoscape
- **Redo:** Increments index, restores state directly to cytoscape
- **Limit:** Trims oldest entries when exceeds `maxHistory`

---

## 4. Issues Identified

### 4.1 Direct Cytoscape Manipulation

**Problem:** `undo()` and `redo()` call `restoreState()` which directly manipulates cytoscape. This can trigger event listeners that call `saveState()` again, creating unwanted history entries.

**Current Flow:**
```
undo() → restoreState() → cy.elements().remove() → cy.add() → [event listeners fire] → saveState() → [duplicate entry]
```

### 4.2 No Baseline Tracking

**Problem:** No way to track "saved state" vs "modified state". Cannot determine if graph is dirty relative to last save.

**Missing:**
- `baselineIndex` property
- `markBaseline()` method
- `isModified()` method

### 4.3 Incomplete State Snapshot

**Problem:** Current state only stores nodes/edges, not:
- Selection state
- Viewport state (pan/zoom)
- Graph ID

This means undo/redo doesn't restore:
- Which node/edge was selected
- Viewport position/zoom level

### 4.4 Tight Coupling

**Problem:** GraphHistoryManager directly manipulates cytoscape instance. Should be a generic snapshot stack that doesn't know about cytoscape.

**Current:** `undo(cy)`, `redo(cy)`, `restoreState(cy, state)`

**Should be:** `undo() => snapshot`, `redo() => snapshot`, `push(snapshot)`

---

## 5. Guard Flag Analysis

### 5.1 Current Guard

**Flag:** `isRestoringState`

**Usage:**
- Set to `true` in `restoreState()` before restoring
- Set to `false` in `finally` block after restoring
- Checked in `saveState()` to prevent saving during restore

**Limitation:** Only prevents `saveState()` within GraphHistoryManager. Doesn't prevent `saveState()` calls from graph_designer.js event listeners.

---

## 6. Summary

**Current Behavior:**
- ✅ Basic undo/redo functionality works
- ✅ Guard flag prevents saveState during restore (within manager)
- ❌ Direct cytoscape manipulation (tight coupling)
- ❌ No baseline tracking
- ❌ Incomplete state snapshot (missing selection, viewport)
- ❌ Event listeners can still trigger saveState during restore

**Required Changes (Task 19.24.8):**
1. Create canonical snapshot format (with selection, viewport, graphId)
2. Refactor to generic snapshot stack (no direct cytoscape manipulation)
3. Add baseline tracking
4. Add `restoringFromHistory` flag in graph_designer.js to prevent saveState during restore
5. Create `buildGraphSnapshot()` and `restoreGraphSnapshot()` helpers

---

**Analysis Date:** 2025-12-18  
**Status:** ✅ Complete

