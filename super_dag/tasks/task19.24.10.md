

# Task 19.24.10 – Deep Slimming of GraphHistoryManager.js & Safe History Engine Pre‑Check

> **Context:**  
> SuperDAG validation layer, QC routing, semantic intents, and AutoFix pipeline are now stable (Tasks 19.0–19.21).  
> Undo/Redo logic is functionally correct after Tasks 19.24.7–19.24.9, but `GraphHistoryManager.js` still carries historical weight and hidden complexity.  
> This task focuses on making the history engine *lean, predictable, and future‑proof* before Phase 20 (ETA/Time Engine).

---

## 🎯 GOAL

Make `GraphHistoryManager.js` as small, predictable, and “pure” as possible:

- Only responsible for **snapshot stack management** (history, index, baseline).
- No hidden caches, no Cytoscape binding, no duplicate serialization logic.
- Snapshot structure is **uniform and minimal** (nodes + edges + meta).
- Undo/Redo become as close to pure functions as practical.
- All existing tests must still pass (ValidateGraphTest, AutoFixPipelineTest, SemanticSnapshotTest).

---

## 📂 Files in Scope

1. `assets/javascripts/dag/modules/GraphHistoryManager.js` (**main target**)
2. `assets/javascripts/dag/graph_designer.js` (only where it touches history manager)
3. `docs/super_dag/tasks/task19.24.10_results.md` (to summarize changes after implementation)

---

## 1) Hidden State Audit & Slimming

### ✅ Objective

Ensure `GraphHistoryManager` maintains *only* the following state:

- `history` – array of snapshots
- `index` – current pointer in history
- `baselineIndex` – index used by `isModified()`

> **No other persistent instance fields should remain.**

### 🧩 Steps

1. Scan `GraphHistoryManager.js` for any extra fields, such as (examples, not exhaustive):
   - `lastAppliedState`
   - `pendingSnapshot`
   - `skipNextApply`
   - `cyCache`
   - any other “helper cache” or internal flags that live across calls

2. For each extra field:
   - If it is **not used** → remove it completely.
   - If it is used only for convenience, but not strictly necessary for correctness → remove it and adjust logic accordingly.
   - If it is truly required for correctness → document why in a short comment (but the target is to have *no* extra state if possible).

3. After refactor, `constructor` (or initial state) of `GraphHistoryManager` should only define:

   ```js
   this.history = [];
   this.index = -1;
   this.baselineIndex = -1;
   ```

---

## 2) Slim Snapshot Structure

### ✅ Objective

Normalize snapshot objects to a minimal, uniform structure suitable for Phase 20.

### 🎯 Target Snapshot Shape

A snapshot should look like this:

```js
{
  nodes: [...],
  edges: [...],
  meta: {
    // optional, but reserved for future (ETA/Time, selection, etc.)
  }
}
```

### 🧩 Steps

1. Search in `GraphHistoryManager.js` and `graph_designer.js` for snapshot shapes and usages like:
   - `snapshot.layout`
   - `snapshot.ui`
   - `snapshot.timestamp`
   - `snapshot.debug_hash`
   - `snapshot.digest`
   - any other non‑essential fields

2. Determine if those fields are:
   - **Still used** somewhere in the codebase (search repo‑wide).
   - Or are leftovers from legacy implementations.

3. For fields that:
   - Are not used anywhere else → remove them from both creation and handling.
   - Are used only for debugging/logging → remove them as part of lean‑up (we now have proper tests + snapshots).

4. Make sure that:
   - Wherever a snapshot is constructed (typically in `graph_designer.js` before calling history.push), it only populates `nodes`, `edges`, and optionally `meta`.
   - `GraphHistoryManager` does **not** silently mutate snapshot shapes (no adding random extra fields).

---

## 3) Simplify `push()` to the Minimal Form

### ✅ Objective

Make `push()` extremely simple and fast, with no unnecessary work.

### 🎯 Target Pattern

```js
push(snapshot) {
  // Basic sanity guard (see section 6)
  if (!snapshot || !snapshot.nodes || !snapshot.edges) {
    throw new Error('[GraphHistoryManager] Invalid snapshot');
  }

  // Cut off any redo branch
  if (this.index < this.history.length - 1) {
    this.history = this.history.slice(0, this.index + 1);
  }

  this.history.push(snapshot);
  this.index++;
}
```

### 🧩 Steps

1. Inspect current `push()` implementation and remove:
   - Redundant deep clones if not strictly necessary.
   - Multiple JSON stringify/parse cycles beyond what is needed.
   - Extra normalization steps that can/should be done at snapshot creation (in `graph_designer.js`) instead.

2. If deep cloning is **truly required** to avoid mutation, centralize it into a single place, e.g.:

   ```js
   const safeSnapshot = deepClone(snapshot);
   ```

   but avoid double clones or multiple passes.

3. Ensure `push()` itself **does not**:
   - Touch Cytoscape.
   - Touch DOM.
   - Perform heavy calculation unrelated to history.

---

## 4) Ensure Undo / Redo are Pure w.r.t. State

### ✅ Objective

Undo/Redo should only manipulate the stack and indices; they should *not* have hidden side‑effects.

> Note: Applying the snapshot back to the graph (`cy`) is done in `graph_designer.js`, NOT inside the manager.

### 🧩 Steps

1. Inspect `undo()` and `redo()` in `GraphHistoryManager.js`:
   - They should only adjust `index` and return a snapshot.
   - No DOM, no Cytoscape, no logging spam, no external references.

2. Ensure a pattern similar to:

   ```js
   undo() {
     if (this.index <= 0) return null;
     this.index--;
     return this.history[this.index] || null;
   }

   redo() {
     if (this.index >= this.history.length - 1) return null;
     this.index++;
     return this.history[this.index] || null;
   }
   ```

3. Verify in `graph_designer.js`:
   - The code that applies the snapshot to Cytoscape is **only in one place**, e.g.:

     ```js
     const snapshot = historyManager.undo();
     if (snapshot) {
       applySnapshotToCy(cy, snapshot);
     }
     ```

   - There should not be any leftover legacy wrappers like `restoreState()` that duplicate logic (Task 19.24.9 already removed some; verify nothing regenerated them).

---

## 5) Remove Legacy History Compression Logic

### ✅ Objective

Remove old “smart” history compression logic from the manager. Phase 20 will introduce any needed smarter logic in a dedicated engine instead.

### 🧩 Steps

1. Search in `GraphHistoryManager.js` for concepts like:
   - combine / merge snapshots
   - `isSimilarSnapshot`
   - `shouldSkipSnapshot`
   - debounce/timers specifically for history
   - any complex heuristics “to reduce history noise”

2. If any such logic is found:
   - Remove it from the manager.
   - If this logic is genuinely useful for UX, move it (later) into a separate utility or a new “HistoryPolicy” layer (NOT part of this task; leave TODO if necessary).

> After Task 19.24.10, `GraphHistoryManager` must behave as a **dumb but reliable stack**, not as a heuristic engine.

---

## 6) Add Safety Guard for Invalid Snapshots

### ✅ Objective

Prevent corrupted history by guarding against invalid snapshots.

### 🧩 Steps

1. Add a small helper inside `GraphHistoryManager`:

   ```js
   _assertValidSnapshot(snapshot) {
     if (!snapshot || typeof snapshot !== 'object') {
       throw new Error('[GraphHistoryManager] Snapshot must be an object');
     }
     if (!Array.isArray(snapshot.nodes) || !Array.isArray(snapshot.edges)) {
       throw new Error('[GraphHistoryManager] Snapshot must contain nodes[] and edges[]');
     }
   }
   ```

2. Call this helper from:
   - `push(snapshot)`
   - Any other function that stores/replaces snapshots (if any)

3. Do **not** add this to read‑only operations (`undo()/redo()`), since they work on snapshots already in the stack.

---

## 7) Deterministic Snapshot Hash (Optional but Recommended)

### ✅ Objective

Add an optional deterministic hash to snapshots so that Semantic/History tests can rely on stable identity if needed (without re‑hashing everything in every test).

> This is optional for runtime, but helpful for debug/logging and ensuring consistent behavior between executions.

### 🧩 Steps

1. Add a small pure utility function (inside the module, not exported) to compute a simple deterministic hash from a string (e.g. a tiny FNV‑1a or a simple non‑cryptographic hash):

   ```js
   function simpleHash(str) {
     let hash = 0;
     for (let i = 0; i < str.length; i++) {
       hash = (hash * 31 + str.charCodeAt(i)) | 0;
     }
     return hash >>> 0;
   }
   ```

2. In `push(snapshot)`:
   - After validation and (optional) clone, compute:

     ```js
     const hashPayload = JSON.stringify({
       nodes: snapshot.nodes,
       edges: snapshot.edges
     });
     snapshot.__hash = simpleHash(hashPayload);
     ```

   - This field is:
     - Not required by runtime logic.
     - Safe to ignore by other parts of the system.
     - Very useful for debugging and tests.

3. Ensure that this extra field does not break any existing serialization/validation logic (most code should ignore `__hash`).

---

## 8) Keep Public API Stable

### ✅ Objective

Do **not** change the public API surface that `graph_designer.js` relies on.

Public methods that must remain:

- `push(snapshot)`
- `undo()`
- `redo()`
- `markBaseline()`
- `isModified()`
- `clear()`
- `getLength()`
- `getCurrentIndex()`
- `getBaselineIndex()`

> Internal implementation can change, but these methods and their semantics must stay intact.

---

## 9) Tests & Verification

After refactor is done:

1. Run the SuperDAG test suites:

   ```bash
   php tests/super_dag/ValidateGraphTest.php
   php tests/super_dag/AutoFixPipelineTest.php
   php tests/super_dag/SemanticSnapshotTest.php
   ```

2. Manually sanity‑check in the UI:
   - Create a small graph.
   - Perform multiple operations: add node, move node, connect edges.
   - Undo step by step → verify visual graph returns exactly to previous states.
   - Redo step by step → verify visual graph replays correctly.
   - Confirm no console errors/warnings related to history.

3. If needed, add a brief note to `docs/super_dag/tasks/task19.24.10_results.md` summarizing:
   - Lines removed
   - State fields removed
   - Snapshot shape before/after (brief)
   - Confirmation that tests all pass

---

## ✅ Acceptance Criteria Checklist

- [ ] `GraphHistoryManager` มีแค่ `history`, `index`, `baselineIndex` เป็น state
- [ ] Snapshot shape ลดเหลือ `nodes`, `edges`, `meta` (optional) เท่านั้น
- [ ] `push()` ถูกปรับให้เป็น implementation ที่เรียบง่ายและเร็ว
- [ ] `undo()` / `redo()` เป็น pure stack operations (ไม่มี side effects)
- [ ] Legacy compression/heuristic logic ถูกลบออกจาก manager ทั้งหมด
- [ ] Safety guard `_assertValidSnapshot()` ถูกใช้ใน `push()`
- [ ] (ถ้าทำ) `snapshot.__hash` ถูก generate แบบ deterministic
- [ ] Public API ของ manager ไม่เปลี่ยน
- [ ] Tests ทั้งหมดผ่าน (ValidateGraph, AutoFixPipeline, SemanticSnapshot)
- [ ] มีไฟล์ `task19.24.10_results.md` สรุปผลลัพธ์ของ task นี้

---

> หลังจบ Task 19.24.10, `GraphHistoryManager.js` จะกลายเป็น “history engine แบบมินิมอล” ที่เชื่อถือได้ และพร้อมให้ Phase 20 (ETA/Time & Predictive Routing) ใช้งานต่อโดยไม่ต้องกลัวหนี้เทคนิคจาก logic เก่า ๆ ใน Undo/Redo อีกต่อไป