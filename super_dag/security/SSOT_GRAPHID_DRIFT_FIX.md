# SSOT GraphId Drift Fix - Completion Report

**Date:** 2025-12-15  
**Issue:** Selector shows stale versions from previous graph / version change loads wrong graphId  
**Status:** ✅ **FIXED**

---

## 📋 Problem Summary

**Symptom 1:** When selecting a graph from sidebar, selector still shows versions from previous graph (not updating).

**Symptom 2:** When changing version in selector, sometimes loads a different graphId (not the one selected in sidebar).

**Root Cause:** 
- Versions list was not hard-bound to graphId (could be reused across graphs)
- graphId comparison had string/number mismatch issues
- `setIdentity()` without `reqSeq` could overwrite SSOT state
- Versions were not properly cleared/refreshed on graph switch

---

## 🔧 Solution: Hard-Bind Versions to GraphId + Enhanced Guards

**Principle:** Versions list must be hard-bound to a specific graphId. Selector is VIEW-ONLY and must always reflect the active graph's versions.

---

## ✅ Changes Made

### 1) Hard-Bind Versions List to GraphId

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`

**Added State:**
```javascript
// SSOT FIX: Hard-bind versions list to graphId (prevents cross-graph reuse)
/** @type {number|null} graphId that the current availableVersions belong to */
this.versionsGraphId = null;
```

**Modified `setAvailableVersions()`:**
- Changed signature: `setAvailableVersions(graphId, versions)` (now requires graphId)
- Added validation: If `graphId !== this.currentGraphId` → **discard** versions (prevent cross-graph reuse)
- Sets `this.versionsGraphId = graphId` only when graphId matches
- Added comprehensive logging

**Modified `canonicalToIdentityRequest()`:**
- Added validation: If `this.versionsGraphId !== graphId` → return null (versions are stale)
- Prevents resolving canonical values using versions from a different graph

**Result:** Selector will never resolve canonical using versions from a different graph.

---

### 2) GraphId Normalization (String/Number Mismatch Fix)

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`

**Changes:**
- All graphId comparisons normalize to `String()` before comparison
- All `data('graph-id')` assignments use `String(graphId)`
- Prevents false mismatches due to type differences (string "1952" vs number 1952)

**Locations:**
- `handleSelectorChange()`: Normalizes `ssotGraphId` and `domGraphId` to strings before comparison
- `setAvailableVersions()`: Normalizes both graphIds to strings before comparison
- `selectGraph()`: Sets selector `data('graph-id')` as string
- `setIdentity()`: Sets selector `data('graph-id')` as string
- `renderSelector()`: Sets selector `data('graph-id')` as string

**Result:** No false mismatches from type differences.

---

### 3) Prevent setIdentity Without reqSeq from Overwriting SSOT

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`

**Added Guards in `setIdentity()`:**

**Guard 4: Missing reqSeq While Pending Request Exists**
```javascript
if (this.pendingRequest && (!meta || typeof meta.reqSeq !== 'number')) {
    console.warn('[GraphVersionController] Discarding identity - missing reqSeq while pendingRequest exists', ...);
    return; // Discard - missing reqSeq while pending request exists
}
```

**Guard 5: GraphId Mismatch (Prevents Old Graph from Overwriting New)**
```javascript
if (this.currentGraphId != null && identity.graphId != null) {
    if (String(identity.graphId) !== String(this.currentGraphId) && source !== 'init') {
        console.warn('[GraphVersionController] Discarding identity - graphId mismatch', ...);
        return; // Discard - old graph cannot overwrite new graph
    }
}
```

**Result:** Prevents stale responses without `reqSeq` from overwriting SSOT state, and prevents old graph from overwriting new graph selection.

---

### 4) Sidebar Graph Select Must Force Refresh Versions

**File:** `assets/javascripts/dag/graph_designer.js`

**Modified `onGraphSelect` Callback:**
- Removed attempts to call non-existent methods (`refreshVersions`, `loadVersionsForGraph`, `loadVersions`)
- Standardized flow:
  1. `versionController.selectGraph(graphId, source)` - Sets `currentGraphId` immediately, calls `clearVersionsForGraphSwitch()`
  2. `loadVersionsForSelector(graphId, null, null)` - Loads versions for new graph
  3. When API response arrives → `versionController.setAvailableVersions(graphId, versions)` - Hard-binds versions to graphId
  4. `selectGraph()` already triggers `requestLoad()` for published_current

**Added `clearVersionsForGraphSwitch()` Method:**
- Clears `availableVersions = []`
- Clears `versionsGraphId = null`
- Hides selector (selector must be empty/disabled until versions load for new graph)

**Modified `loadVersionsForSelector()`:**
- Now passes `graphId` to `versionController.setAvailableVersions(graphId, versions)`

**Result:** When selecting a new graph, versions are always cleared and reloaded for that specific graph. Selector shows empty/disabled until correct versions load.

---

### 5) Enhanced Logging

**Added Logs:**

**selectGraph():**
```javascript
console.log('[GraphVersionController] selectGraph', {
    graphId: String(graphId),
    source: source,
    action: 'set currentGraphId and cleared versions for new graph'
});
```

**setAvailableVersions():**
```javascript
console.log('[GraphVersionController] setAvailableVersions', {
    graphId: normalizedGraphId,
    currentGraphId: normalizedCurrentGraphId,
    accepted: true/false,
    count: versions.length
});

// Or if discarded:
console.warn('[GraphVersionController] Discarding versions for wrong graphId', {
    versionsGraphId, currentGraphId, reason: '...'
});
```

**handleSelectorChange():**
```javascript
console.log('[GraphVersionController] handleSelectorChange', {
    canonicalValue,
    ssotGraphId: String(ssotGraphId),
    domGraphId: String(domGraphId),
    versionsGraphId: String(this.versionsGraphId),
    currentGraphId: String(this.currentGraphId)
});
```

**setIdentity() Guards:**
- All discard scenarios now have detailed warnings with context

**Result:** Comprehensive logging for debugging graphId drift issues.

---

## ✅ Acceptance Tests

### Test 1: Click Sidebar Graph A → Selector Must Show Versions of A
1. Click graph A (1952) in sidebar
2. **Expected:** Selector shows versions for graph 1952 (not previous graph)
3. **Expected Log:**
   ```
   [GraphVersionController] selectGraph { graphId: '1952', source: 'sidebar_autoselect' }
   [GraphVersionController] clearVersionsForGraphSwitch { newGraphId: 1952, previousVersionsGraphId: 153 }
   [GraphVersionController] setAvailableVersions { graphId: '1952', accepted: true, count: 3 }
   ```

### Test 2: Click A → Immediately Change Version → Must Request graphId = A
1. Click graph A (1952) in sidebar
2. Immediately change version selector to Draft
3. **Expected:** Request sends `graphId=1952` (never another graphId)
4. **Expected Log:**
   ```
   [GraphVersionController] handleSelectorChange { canonicalValue: 'draft', ssotGraphId: '1952', versionsGraphId: '1952', currentGraphId: '1952' }
   ```

### Test 3: Rapid Switch A→B→A + Toggle Published↔Draft
1. Click graph A (1952)
2. Click graph B (153)
3. Quickly click graph A again
4. Toggle Published ↔ Draft multiple times
5. **Expected:** 
   - Last selection (A) wins
   - Selector never shows versions from graph B
   - All requests use graphId=1952

### Test 4: Response Without reqSeq While PendingRequest Exists
1. Start loading graph A (pendingRequest exists)
2. Receive response without reqSeq metadata
3. **Expected:** Response is discarded, SSOT state not corrupted
4. **Expected Log:**
   ```
   [GraphVersionController] Discarding identity - missing reqSeq while pendingRequest exists
   ```

---

## 📊 Code Metrics

### Files Modified
1. `assets/javascripts/dag/modules/GraphVersionController.js` - ~120 lines added/modified
2. `assets/javascripts/dag/graph_designer.js` - ~15 lines modified

### Lines Added
- GraphVersionController: ~100 lines (guards, logging, normalization)
- graph_designer.js: ~5 lines (standardized flow)

### Complexity
- **Before:** Versions could be reused across graphs, graphId comparisons could fail due to types, stale responses could overwrite SSOT
- **After:** Versions hard-bound to graphId, normalized comparisons, comprehensive guards, deterministic flow

---

## ✅ Final Status

- [x] **1)** Hard-bind versions list to graphId
- [x] **2)** Normalize graphId comparisons (string/number)
- [x] **3)** Prevent setIdentity without reqSeq from overwriting SSOT
- [x] **4)** Sidebar graph select forces refresh versions
- [x] **5)** Enhanced logging for all operations
- [x] **6)** No linter errors

---

## 🔍 Key Improvements

### Versions Hard-Binding
- `versionsGraphId` tracks which graph the versions belong to
- `setAvailableVersions()` rejects versions for wrong graph
- `canonicalToIdentityRequest()` validates versions match graphId

### GraphId Normalization
- All comparisons use `String()` normalization
- Prevents false mismatches (string "1952" vs number 1952)

### Enhanced Guards
- Guard 4: Prevents responses without reqSeq from overwriting SSOT when pendingRequest exists
- Guard 5: Prevents old graph from overwriting new graph selection

### Standardized Flow
- Graph select → clearVersions → loadVersions → setAvailableVersions → renderSelector
- Selector is empty/disabled until correct versions load

---

**Fix Complete:** GraphId drift and selector stale version issues are now resolved. Versions are hard-bound to graphId, graphId comparisons are normalized, and comprehensive guards prevent SSOT corruption.

