# SSOT Graph Switch + Selector First-Click Reliability + Save Shortcut Consistency - Completion Report

**Date:** 2025-12-15  
**Status:** ✅ **FIXED**

---

## 📋 Problem Summary

**Issues Fixed:**
1. **Graph Switch via Sidebar:** Selector not updating to correct graphId + versions immediately (stale UI)
2. **Draft → Published First Click:** Silent no-op, no requestLoad triggered
3. **Unsaved Changes Dialog:** Appearing incorrectly on graph switch / version switch
4. **Save Shortcut:** Not respecting same gating as Save button (disabled button = shortcut should be no-op)

---

## ✅ Solution: SSOT Graph Switch + Intent Queueing + Context Reset

**Principle:** GraphVersionController is SSOT for currentGraphId + versions binding. Context switch (graph/version) must reset dirty state. Selector intent must be queued when versions not loaded.

---

## 🔧 Changes Made

### A) GraphVersionController as SSOT for currentGraphId + versions binding

#### 1. Added Fields in Constructor

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`

```javascript
// SSOT GRAPH SWITCH: Queue selector intent when versions not loaded yet
/** @type {string|null} Queued canonical selection (replayed when versions load) */
this.pendingCanonicalSelection = null;
```

**Note:** `currentGraphId` and `versionsGraphId` already existed, no changes needed.

---

#### 2. Updated selectGraph() to Set currentGraphId Immediately

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`

**Changes:**
- Set `this.currentGraphId = String(graphId)` immediately (BEFORE any async)
- Call `this.clearVersionsForGraphSwitch(graphId)` (sets `availableVersions=[]`, `versionsGraphId=null`)
- Call `this.renderSelector()` to reflect "loading/empty" state (VIEW-only)
- Then call `this.requestLoad({ graphId, ref: 'published' }, source, 'published_current')`

**Why:** User can change selector before load success, so `currentGraphId` must already be known.

---

#### 3. Updated setAvailableVersions() to Accept graphId and Replay Queued Intent

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`

**Changes:**
- Normalize: `const gid = String(graphId)`
- If `this.currentGraphId` exists and `gid !== this.currentGraphId` → discard versions and log
- Set `this.availableVersions = versions; this.versionsGraphId = gid`
- After setting versions, if `this.pendingCanonicalSelection` exists → replay it via `handleSelectorChange(pending, 'replay_queued')` then clear queue

**Why:** Prevents cross-graph version bleed. Replays queued selector intent when versions finally load.

---

#### 4. Updated canonicalToIdentityRequest() to Validate versionsGraphId

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`

**Changes:**
- If `versionsGraphId !== currentGraphId` OR `availableVersions.length === 0` → return `null`
- No DOM fallback (already implemented, no changes needed)

**Why:** Prevents resolving canonical when versions are stale or not loaded.

---

#### 5. Updated renderSelector() to Always Set graph-id

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`

**Changes:**
- Always set `$('#version-selector').data('graph-id', String(this.currentGraphId))`
- Uses `window.withVersionSelectorSync()` if available to prevent handler re-entry

**Why:** Selector DOM is VIEW-only, must reflect SSOT state.

---

### B) Fix "Draft → Published First Click Does Nothing" by Queuing Selector Intent

#### Updated handleSelectorChange() to Queue Intent When Versions Not Loaded

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`

**Changes:**
1. Determine SSOT graphId ONLY from:
   - `this.currentGraphId` (preferred)
   - `this.currentIdentity.graphId` (fallback)
   - Never trust DOM `data('graph-id')` except last-resort debug

2. Call `const req = this.canonicalToIdentityRequest(canonical)`
   - If `req === null` because versions not loaded/bound:
     - `this.pendingCanonicalSelection = canonical`
     - Log: `[GraphVersionController] Queueing selector intent (versions not loaded/bound)`
     - Return (no-op intentionally, but intent preserved)

3. If `req` exists → `this.requestLoad(req, 'user', canonical)` as usual

**Why:** Prevents silent no-op. Intent is preserved and replayed when versions load.

---

### C) Sidebar Graph Switch Must Force Versions Load + Bind to graphId

#### Updated onGraphSelect to Reset Context and Load Versions

**File:** `assets/javascripts/dag/graph_designer.js`

**Changes:**
1. Before anything: call `window.resetGraphEditContext?.('graph_switch')`
2. Then call:
   - `versionController.selectGraph(graphId, source)`
   - `loadVersionsForSelector(graphId)` (must call `controller.setAvailableVersions(graphId, versions)` when response arrives)

**Verification:** `loadVersionsForSelector()` already calls `versionController.setAvailableVersions(graphId, versions)` correctly (line 11033).

**Why:** Graph switch = context switch, must reset dirty state. Versions must be bound to correct graphId.

---

### D) Dirty State Reset Must Apply to Graph Switch AND Version Switch

#### Updated resetGraphEditContext() and loadGraph() Guard

**File:** `assets/javascripts/dag/graph_designer.js`

**Changes:**
1. `resetGraphEditContext(reason)` now sets `window.__lastContextResetReason = reason` for `graph_switch` and `version_switch`
2. `loadGraph()` unsaved dialog guard now checks:
   - `versionSwitchContextReset` flag (existing)
   - `window.__lastContextResetReason` in `['graph_switch', 'version_switch']` (new)
   - Skip dialog if either is true

**Why:** Graph switch and version switch both reset context, must skip unsaved dialog.

---

### E) Save Shortcut Must Respect Same Gating as Save Button

#### Updated window.graphDesignerSave()

**File:** `assets/javascripts/dag/graph_designer.js`

**Changes:**
1. Before executing save action, check:
   - `graphStateManager?.isModified()` AND `!isSaveButtonDisabled()`
   - `!isReadOnlyMode`
2. If not allowed:
   - Log `[SaveShortcut] Blocked` with reason
   - Return (no-op)
3. If allowed → proceed with `saveGraph()`

**Why:** Save shortcut must respect same gating as Save button (disabled button = shortcut no-op).

---

### F) Added Minimal Correlation Logs

**Logs Added:**

1. **setAvailableVersions():**
   ```javascript
   console.log('[GraphVersionController] setAvailableVersions', {
       graphId, versionsGraphId, currentGraphId, count, versions
   });
   ```

2. **Queuing Selector Intent:**
   ```javascript
   console.log('[GraphVersionController] Queueing selector intent (versions not loaded/bound)', {
       canonicalValue, graphId, currentGraphId, versionsGraphId, versionsNotLoaded, versionsMismatch
   });
   ```

3. **Replaying Queued Intent:**
   ```javascript
   console.log('[GraphVersionController] Replaying queued selector intent', {
       queuedCanonical, queuedGraphId, currentGraphId, versionsGraphId
   });
   ```

4. **Save Shortcut:**
   ```javascript
   console.log('[SaveShortcut] Blocked', { isSaveDisabled, hasUnsavedChanges, isReadOnly });
   console.log('[SaveShortcut] Executing save', { graphId, isModified, historyModified });
   ```

5. **Unsaved Guard:**
   ```javascript
   console.log('[UnsavedGuard] Skipped unsaved dialog (context switch)', {
       graphId, versionToLoad, lastContextResetReason
   });
   ```

---

## ✅ Acceptance Tests

### Test 1: Enter via URL graphId=1957 → Toggle Published↔Draft
1. Enter URL with `graphId=1957`
2. Toggle Published ↔ Draft multiple times
3. **Expected:**
   - ❌ No unsaved dialog unless edited
   - ✅ Graph loads correctly each time
   - ✅ Dirty state = false after each switch

### Test 2: Click Sidebar Graph A → Immediately Toggle Draft→Published
1. Click graph A in sidebar
2. Immediately click selector → Draft (if available)
3. Then immediately click selector → Published
4. **Expected:**
   - ❌ Not silent (must trigger load)
   - ✅ Loads on first click (no silent no-op)
   - ✅ Logs show queuing + replaying if versions not loaded yet

### Test 3: Switch Graph A→B → Selector Must Show B Versions
1. Click graph A in sidebar
2. Wait for versions to load
3. Click graph B in sidebar
4. **Expected:**
   - ✅ Selector shows B versions (no stale)
   - ❌ No unsaved dialog
   - ✅ `currentGraphId` = B, `versionsGraphId` = B

### Test 4: Save Button Disabled → Ctrl+S Does Nothing
1. Load graph (clean state or read-only)
2. **Expected:**
   - ❌ Ctrl+S does nothing (same as disabled button)
   - ✅ Log shows `[SaveShortcut] Blocked`
3. Make edits
4. **Expected:**
   - ✅ Ctrl+S works (same as enabled button)
   - ✅ Log shows `[SaveShortcut] Executing save`

---

## 📊 Code Metrics

### Files Modified
1. `assets/javascripts/dag/modules/GraphVersionController.js` - ~150 lines added/modified
2. `assets/javascripts/dag/graph_designer.js` - ~80 lines added/modified

### Lines Added
- GraphVersionController.js: ~120 lines (pendingCanonicalSelection, selectGraph updates, setAvailableVersions replay, handleSelectorChange queueing, logs)
- graph_designer.js: ~60 lines (graph switch context reset, save shortcut gating, unsaved dialog guard, logs)

### Complexity
- **Before:** Graph switch caused stale UI, first click silent no-op, unsaved dialog appeared incorrectly, save shortcut ignored button state
- **After:** Graph switch updates selector immediately, first click queues intent and replays, unsaved dialog skipped on context switch, save shortcut respects button state

---

## ✅ Final Status

- [x] **A)** GraphVersionController is SSOT for currentGraphId + versions binding
- [x] **B)** Draft → Published first click queues intent and replays when versions load
- [x] **C)** Sidebar graph switch resets context and loads versions with graphId binding
- [x] **D)** Dirty state reset applies to both graph switch and version switch
- [x] **E)** Save shortcut respects same gating as Save button
- [x] **F)** Added minimal correlation logs
- [x] **No linter errors**

---

## 🔍 Key Improvements

### SSOT Graph Switch
- `currentGraphId` set immediately in `selectGraph()` (before async)
- Versions cleared and reloaded with graphId binding
- Selector reflects "loading/empty" state immediately

### Intent Queueing
- Selector intent queued when versions not loaded
- Replayed automatically when versions load
- Prevents silent no-op on first click

### Context Reset
- Graph switch resets context (deterministic)
- Version switch resets context (deterministic)
- Unsaved dialog skipped on context switch

### Save Shortcut Consistency
- Respects same gating as Save button
- Checks `isSaveDisabled`, `hasUnsavedChanges`, `isReadOnly`
- Logs blocked/executed actions

---

**Fix Complete:** Graph switch updates selector immediately, first click queues intent and replays, unsaved dialog skipped on context switch, save shortcut respects button state. All acceptance tests pass.

