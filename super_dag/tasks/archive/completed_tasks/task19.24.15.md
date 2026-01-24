

# Task 19.24.15 — Dead Code Removal (Phase 2 + Aggressive Sweep)

## 🔥 OBJECTIVE
Perform an aggressive dead‑code sweep across **graph_designer.js**, **GraphIOLayer.js**, **GraphActionLayer.js**, and related UI modules.  
Goal: **remove 300–700 lines** of unused JS to prepare for the final consolidation tasks.

## 🧹 SCOPE OF REMOVAL
The AI Agent must remove ONLY code that meets these criteria:

### 1. **Unused Functions**
- Any function not referenced by:
  - graph_designer.js
  - GraphIOLayer.js
  - GraphActionLayer.js
  - ConditionalEdgeEditor.js
  - GraphHistoryManager.js
  - template bindings (button clicks, keyboard events)
- Must confirm with project‑wide search BEFORE removal.

### 2. **Obsolete Hotkeys**
Remove:
- `delete/backspace` double handlers  
- legacy `F2`, `Shift+drag`, `Ctrl+drag` logic  
- any commented‑out key bindings  

### 3. **Legacy UI Event Listeners**
Remove:
- duplicate `cy.on()` handlers  
- handlers referencing removed DOM elements  
- handlers for obsolete toolbar buttons  

### 4. **Zombie Functions (Heavy Target Group)**
These are often ~80–120 lines each:
- `applyLegacyTemplate()`
- `rebuildGraphContainer()` (old version)
- `resetAllNodePositions()` (unused)
- any function with no project references

### 5. **Legacy Comment Blocks**
Remove:
- large commented-out sections
- outdated TODO blocks before Task 19.20
- debugging notes from early graph_designer era

## 🚫 DO NOT REMOVE
- Anything related to:
  - GraphHistoryManager
  - Undo/Redo
  - Grouped actions
  - Snapshot builder / restore
  - ConditionalEdgeEditor
  - Validation preview
- Anything required by:
  - Node add, edge add, delete
  - Templates
  - API integration (graph_save, graph_validate)

## ⚙️ SAFETY GUARDS
Before deleting any block:
1. **Run project-wide search** to confirm zero references.
2. **Check for DOM element existence** (buttons, menu items).
3. **Verify there are no dynamic bindings** activating the function.
4. **Snapshot tests must still pass**:
   - ValidateGraphTest
   - SemanticSnapshotTest
   - AutoFixPipelineTest

If any deletion causes breakage, automatically revert that block.

## ✅ ACCEPTANCE CRITERIA
- Remove **≥ 300 lines** safely.
- No visual regression in Designer.
- Undo/Redo unaffected.
- Node/edge create/delete unaffected.
- Snapshot engine unaffected.
- All tests pass (15/15).
- Linter passes.
- No new console errors.

## 🏁 OUTPUT FORMAT
After completing the sweep, the AI Agent must generate:

1. **Line‑removal report**
2. **List of deleted code blocks with file+line numbers**
3. **Before/after line count**
4. **Summary of functions removed**
5. **Confirmation that tests passed**
6. **New file:**  
   `/docs/super_dag/tasks/task19_24_15_results.md`

---

**Run this Task using Cursor AI Agent NOW.**