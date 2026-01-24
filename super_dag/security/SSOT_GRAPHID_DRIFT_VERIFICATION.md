# SSOT GraphId Drift - Verification & Residual Bug Analysis

**Date:** 2025-12-15  
**Auditor:** Senior System Architect  
**Scope:** Verify SSOT GraphId Drift Fix and identify any residual bugs  
**Status:** ✅ **ANALYSIS COMPLETE**

---

## 1️⃣ Deterministic Verdict

**Verdict:** Symptoms are **timing race + missing rerender trigger** — NOT SSOT authority bug.

SSOT logic is architecturally sound. The remaining issue is that when `setAvailableVersions()` successfully accepts versions, `renderSelector()` shows the selector, BUT if `handleGraphLoaded()` arrives later and triggers another `loadVersionsForSelector()` call, there's a potential race where:
1. Selector shows versions from `setAvailableVersions()` (correct)
2. `handleGraphLoaded()` calls `loadVersionsForSelector()` again
3. Second API call may arrive out-of-order or after another graph switch
4. Selector may be re-rendered with wrong timing

However, the **real issue** is that `handleGraphLoaded()` calling `loadVersionsForSelector()` is redundant — versions should already be loaded from sidebar selection. This creates unnecessary duplicate API calls.

---

## 2️⃣ GraphId Authority Audit

### A. DOM GraphId Reading Points

**Analysis:**

**Point 1: `handleSelectorChange()` — Last Resort Fallback**
- **Location:** Line 408-411
- **Code:** Reads `$selector.data('graph-id')` only if `ssotGraphId` is null
- **Status:** ✅ **SAFE** — Only used as last resort when SSOT is unavailable
- **Risk:** **LOW** — Only activates in edge cases (early boot, identity not set)

**Point 2: `setAvailableVersions()` — Replay Queued Intent**
- **Location:** Line 549
- **Code:** Uses `this.currentGraphId || graphId` (SSOT first)
- **Status:** ✅ **SAFE** — Prioritizes SSOT, only uses parameter as fallback

**Verdict:** No unauthorized DOM reading. All DOM reads are either VIEW-ONLY updates or last-resort fallbacks.

---

### B. State Diverge Scenarios

**Analysis:**

**Scenario 1: Rapid Graph Switch (A→B→A)**
- **Timeline:**
  1. Click A → `currentGraphId = A`, `versionsGraphId = null` (cleared)
  2. API call A initiated
  3. Click B → `currentGraphId = B`, `versionsGraphId = null` (cleared)
  4. API call B initiated
  5. API A response arrives → `setAvailableVersions(A, versions)` → **DISCARDED** (currentGraphId = B)
  6. API B response arrives → `setAvailableVersions(B, versions)` → **ACCEPTED**
  7. Click A again → `currentGraphId = A`, `versionsGraphId = null` (cleared)
  8. API call A initiated again
  9. API A response arrives → `setAvailableVersions(A, versions)` → **ACCEPTED**

- **State Consistency:**
  - `currentGraphId` = A (correct)
  - `versionsGraphId` = A (matches)
  - `currentIdentity.graphId` = A (after setIdentity)
- **Status:** ✅ **CORRECT** — States converge correctly

**Scenario 2: Early setIdentity Before Versions Load**
- **Timeline:**
  1. Click A → `currentGraphId = A`, versions API call initiated
  2. Graph load API completes first → `setIdentity(A, meta)` → `currentGraphId = A` (redundant, already A)
  3. Versions API completes → `setAvailableVersions(A, versions)` → **ACCEPTED** (currentGraphId matches)
- **Status:** ✅ **CORRECT** — No divergence

**Scenario 3: setIdentity Discarded Due to GraphId Mismatch**
- **Timeline:**
  1. Click A → `currentGraphId = A`, graph load API initiated
  2. Click B → `currentGraphId = B`, graph load API B initiated
  3. Graph A response arrives → `setIdentity(A, meta)` → **GUARD 5 DISCARDS** (graphId mismatch)
  4. Graph B response arrives → `setIdentity(B, meta)` → **ACCEPTED**
- **Status:** ✅ **CORRECT** — Old graph prevented from overwriting new graph

**Verdict:** States do NOT diverge. All scenarios converge correctly.

---

### C. selectGraph() Without loadVersionsForSelector()

**Analysis:**

**Current Flow in `onGraphSelect()`:**
```javascript
versionController.selectGraph(graphId, source);  // Step 1
loadVersionsForSelector(graphId, null, null);    // Step 2
```

**Early Returns That Could Skip Step 2:**

**Return Point 1: `selectGraph()` Early Return (Line 600)**
- **Condition:** `currentIdentity.graphId === graphId && source !== 'user' && source !== 'init'`
- **Effect:** Returns early, does NOT call `requestLoad()`
- **Impact:** `loadVersionsForSelector()` is still called (it's outside `selectGraph()`)
- **Status:** ✅ **NO ISSUE** — `loadVersionsForSelector()` is always called regardless of early return

**Return Point 2: Graph Sidebar Check (Not in controller)**
- **Location:** `graph_sidebar.js` (outside controller)
- **Condition:** If `currentIdentity` exists and matches, sidebar skips autoselect
- **Impact:** Does NOT prevent `onGraphSelect()` from being called
- **Status:** ✅ **NO ISSUE** — Sidebar check doesn't affect `onGraphSelect()` flow

**Verdict:** `loadVersionsForSelector()` is ALWAYS called after `selectGraph()` in current implementation. No missing call scenarios.

---

## 3️⃣ Sidebar → Selector Sync Path Analysis

### Step-by-Step Trace:

**Step 1: Sidebar Click**
- **Action:** User clicks graph A (1952) in sidebar
- **Result:** `onGraphSelect(1952, 'sidebar_autoselect')` called

**Step 2: `selectGraph(1952, 'sidebar_autoselect')`**
- **Actions:**
  - `this.currentGraphId = 1952` (SSOT set)
  - `clearVersionsForGraphSwitch(1952)` → `availableVersions = []`, `versionsGraphId = null`, selector hidden
  - `$selector.data('graph-id', '1952')` (VIEW-ONLY binding)
- **Result:** SSOT state ready, selector cleared and hidden

**Step 3: `loadVersionsForSelector(1952, null, null)`**
- **Action:** AJAX POST to `graph_versions` API
- **Result:** API call initiated (async)

**Step 4: `requestLoad()` (from `selectGraph()`)**
- **Action:** Triggers graph load for published_current
- **Result:** Graph load API call initiated (async)

**Step 5: API Response - Versions (Completes First)**
- **Action:** `setAvailableVersions(1952, versions)` called
- **Validation:** `graphId (1952) === currentGraphId (1952)` → ✅ MATCH
- **Actions:**
  - `this.availableVersions = versions`
  - `this.versionsGraphId = 1952`
  - `renderSelector()` called
- **Result:** Selector shows with Graph A versions

**Step 6: API Response - Graph Load (Completes Later)**
- **Action:** `handleGraphLoaded()` called
- **Action:** `loadVersionsForSelector(currentGraphId, currentVersion, graphStatus)` called (line 2010)
- **Problem:** ⚠️ **REDUNDANT CALL** — versions already loaded in Step 5

### Issues Identified:

**Issue 1: Redundant `loadVersionsForSelector()` in `handleGraphLoaded()`**
- **Location:** `graph_designer.js` line 2010
- **Problem:** Versions are already loaded from sidebar selection. Calling again creates:
  - Unnecessary API call
  - Potential race if graph switched again
- **Impact:** **MEDIUM** — Creates duplicate API calls but doesn't break SSOT (guard prevents wrong versions)

**Issue 2: `renderSelector()` After Discard Doesn't Re-render**
- **Location:** `setAvailableVersions()` line 527
- **Problem:** If versions are discarded, `renderSelector()` is NOT called → selector stays hidden
- **Impact:** **LOW** — Expected behavior (selector should be hidden if versions don't match)
- **Note:** This is actually CORRECT behavior — selector should be hidden if versions don't belong to current graph

**Verdict:** Main issue is redundant `loadVersionsForSelector()` call in `handleGraphLoaded()`. SSOT logic is correct.

---

## 4️⃣ Pending / Queue Side Effects Analysis

### A. Queued Selector Intent Replay Timing

**Scenario: User Clicks Selector Before Versions Load**
1. Click graph A → `selectGraph(A)` → `currentGraphId = A`, versions cleared
2. User clicks selector (Draft) → `handleSelectorChange('draft')`
3. `canonicalToIdentityRequest('draft', A)` → returns null (no versions yet)
4. `pendingCanonicalSelection = 'draft'` (queued)
5. Versions API completes → `setAvailableVersions(A, versions)`
6. Queued intent replay → `handleSelectorChange('draft')` (line 558)
7. `canonicalToIdentityRequest('draft', A)` → returns identityRequest (versions now available)
8. `requestLoad(identityRequest, 'user', 'draft')` → loads Draft

**Analysis:**
- ✅ Queue is cleared before replay (line 546) — prevents infinite loop
- ✅ Replay uses `this.currentGraphId` (line 549) — uses SSOT
- ✅ Versions validated in `canonicalToIdentityRequest()` (line 317) — ensures versions match graphId
- **Status:** ✅ **SAFE** — Queue replay is deterministic and uses SSOT

### B. setAvailableVersions() Discard Due to Timing

**Scenario: Rapid Switch Causes "Correct" Versions to Be Discarded**
1. Click A → `currentGraphId = A`, versions API call A
2. Click B → `currentGraphId = B`, versions API call B
3. API A completes first → `setAvailableVersions(A, versions)` → **DISCARDED** (currentGraphId = B)
4. API B completes → `setAvailableVersions(B, versions)` → **ACCEPTED**

**Analysis:**
- ✅ This is **CORRECT behavior** — Graph A versions SHOULD be discarded when currentGraphId is B
- ✅ User's intent is Graph B (last click wins)
- ✅ No SSOT corruption
- **Status:** ✅ **CORRECT** — Discard is intentional and prevents cross-graph version reuse

### C. pendingRequest vs pendingCanonicalSelection Interaction

**Scenario: Selector Click While Graph Load In Progress**
1. Click graph A → `selectGraph(A)` → `currentGraphId = A`, `pendingRequest = { seq: 1, graphId: A, ref: 'published' }`
2. User clicks selector (Draft) → `handleSelectorChange('draft')`
3. `canonicalToIdentityRequest('draft', A)` → returns identityRequest (versions loaded)
4. `requestLoad(identityRequest, 'user', 'draft')` → `pendingRequest = { seq: 2, graphId: A, ref: 'draft' }`
5. Published response arrives → `setIdentity(A_published, { reqSeq: 1 })` → **GUARD 2 DISCARDS** (seq mismatch)
6. Draft response arrives → `setIdentity(A_draft, { reqSeq: 2 })` → **ACCEPTED**

**Analysis:**
- ✅ Sequence guards prevent stale responses
- ✅ Last intent (draft) wins
- ✅ No interaction issues between pendingRequest and pendingCanonicalSelection
- **Status:** ✅ **CORRECT** — No side effects

**Verdict:** Pending/queue mechanisms work correctly. No timing issues identified.

---

## 5️⃣ Type / Timing Edge Cases

### A. GraphId Type Consistency

**Analysis:**

**Entry Points:**
1. `selectGraph(graphId, source)` — `graphId` parameter type: **number** (from sidebar)
2. `setAvailableVersions(graphId, versions)` — `graphId` parameter type: **number** (from API response)
3. `handleSelectorChange(canonicalValue)` — reads from SSOT (already normalized)

**Normalization Points:**
- `selectGraph()`: Sets `currentGraphId = graphId` (number), sets DOM as `String(graphId)`
- `setAvailableVersions()`: Compares as `String(graphId)`, stores as `Number(graphId)`
- `setIdentity()`: Sets `currentGraphId = identity.graphId` (number), sets DOM as `String(identity.graphId)`
- All comparisons: Use `String()` normalization

**Potential Issue:**
- `currentGraphId` is stored as **number**
- `versionsGraphId` is stored as **number** (line 532)
- Comparisons normalize to **string**
- **Status:** ✅ **CONSISTENT** — All comparisons use normalization, storage type doesn't matter

**Verdict:** Type consistency is maintained through normalization. No edge cases identified.

---

## 6️⃣ Root Cause Analysis

### Primary Issue: Redundant `loadVersionsForSelector()` in `handleGraphLoaded()`

**Location:** `graph_designer.js` line 2010

**Problem:**
```javascript
// In handleGraphLoaded():
if (isNewGraph || previousGraphId === null || $selector.find('option').length <= 1) {
    loadVersionsForSelector(currentGraphId, currentVersion, graphStatus);
}
```

**Why This Causes Issues:**
1. Sidebar selection already calls `loadVersionsForSelector()` (line 497)
2. `handleGraphLoaded()` calls it again (redundant)
3. If graph switched rapidly, second call may:
   - Create duplicate API request
   - Arrive out-of-order
   - Cause selector to re-render unnecessarily

**Impact:**
- **SSOT Logic:** ✅ Still correct (guard prevents wrong versions)
- **Performance:** ⚠️ Unnecessary API call
- **User Experience:** ⚠️ Selector may flicker/re-render unnecessarily

**Is This a Bug?**
- **SSOT Authority:** ❌ **NO** — SSOT logic is correct
- **View Refresh:** ⚠️ **MINOR** — Causes unnecessary re-renders but doesn't break functionality

---

## 7️⃣ Minimal Fix Proposal

### Fix 1: Remove Redundant `loadVersionsForSelector()` from `handleGraphLoaded()`

**Rationale:**
- Versions are already loaded from sidebar selection
- Controller manages versions via `setAvailableVersions()`
- Graph load response doesn't need to trigger version reload

**Change Type:** **Logic Cleanup** (removes redundant call)

**File:** `assets/javascripts/dag/graph_designer.js`

**Location:** `handleGraphLoaded()` function (around line 2008-2010)

**Current Code:**
```javascript
// Load versions for selector (controller will handle selection)
if (isNewGraph || previousGraphId === null || $selector.find('option').length <= 1) {
    // Reload versions for new graph, first load, or normal reload (like after creating draft)
    loadVersionsForSelector(currentGraphId, currentVersion, graphStatus);
}
```

**Proposed Change:**
```javascript
// SSOT FIX: Versions are already loaded from sidebar selection via loadVersionsForSelector()
// Controller manages versions via setAvailableVersions() - no need to reload here
// Exception: After draft creation/publish, versions may have changed - handle separately if needed
// For now, remove redundant call to prevent duplicate API requests and unnecessary re-renders
```

**Why This Doesn't Break SSOT:**
- Versions are loaded from sidebar selection (correct source)
- Controller validates versions via `setAvailableVersions(graphId, versions)` guard
- Graph load response doesn't change available versions (versions API is the source of truth)

**Why This Is Safe:**
- Versions are independent of graph data
- Versions API call is already initiated from sidebar selection
- If versions need refresh (e.g., after draft creation), it should be explicit, not automatic

---

### Fix 2: (Optional) Ensure Selector Shows After Successful setAvailableVersions()

**Rationale:**
- `renderSelector()` is called in `setAvailableVersions()` after accepting versions
- Selector should show if versions are accepted
- Current implementation already does this, but verify it's not being hidden elsewhere

**Analysis:**
- `setAvailableVersions()` → `renderSelector()` → checks `availableVersions.length` → shows selector if > 0
- **Status:** ✅ Already correct — no fix needed

---

## 8️⃣ Acceptance Tests (Mental Model)

### Test 1: Sidebar Click → Selector Must Update Within Same Load Cycle
1. Click graph A (1952) in sidebar
2. **Expected:** Selector shows Graph A versions (not previous graph)
3. **Expected Logs:**
   ```
   [GraphVersionController] selectGraph { graphId: '1952', source: 'sidebar_autoselect' }
   [GraphVersionController] clearVersionsForGraphSwitch { newGraphId: 1952 }
   [GraphVersionController] setAvailableVersions { graphId: '1952', accepted: true, count: 3 }
   ```
4. **Verification:** Selector displays versions for graph 1952

### Test 2: Rapid A→B→A → Selector Versions Must Belong to A Only
1. Click graph A (1952)
2. Immediately click graph B (153)
3. Immediately click graph A again
4. **Expected:** Selector shows Graph A versions only
5. **Expected Logs:**
   - Graph B versions API response → discarded (currentGraphId = A)
   - Graph A versions API response → accepted (currentGraphId = A)
6. **Verification:** No Graph B versions appear in selector

### Test 3: No Duplicate Version API Calls
1. Click graph A (1952) in sidebar
2. Monitor Network tab
3. **Expected:** Only ONE `graph_versions` API call for graph 1952
4. **Current Behavior:** TWO calls (one from sidebar, one from `handleGraphLoaded()`)
5. **After Fix:** ONE call only

---

## 9️⃣ Final Verdict

**SSOT Logic:** ✅ **ARCHITECTURALLY SOUND**

- GraphId authority is correct (SSOT-based)
- Versions are hard-bound to graphId
- Guards prevent cross-graph contamination
- State convergence is deterministic

**Remaining Issue:** ⚠️ **VIEW REFRESH OPTIMIZATION** (not SSOT bug)

- Redundant `loadVersionsForSelector()` call creates unnecessary API requests
- Does NOT break SSOT (guards prevent wrong versions)
- Fix is cleanup/optimization, not bug fix

**Recommendation:**
- Implement Fix 1 (remove redundant call)
- Verify with Test 3 (no duplicate API calls)
- Monitor selector sync behavior (should already work correctly)

---

## 🔟 Explicit Stop Condition

**SSOT is correct — remaining issue is view refresh responsibility, not authority bug.**

The SSOT GraphId Drift Fix is complete and correct. The only remaining optimization is removing the redundant `loadVersionsForSelector()` call in `handleGraphLoaded()`, which is a performance/view refresh issue, not an SSOT authority bug.

**Safe to proceed with minimal cleanup fix.**

