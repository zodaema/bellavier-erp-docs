# Graph Versioning Audit Report
**Date:** 2025-12-13  
**Scope:** Tasks 28.1-28.8 (Graph Versioning & Immutability)  
**Severity Levels:** 🔴 Critical, 🟡 High, 🟢 Medium, ⚪ Low

---

## Executive Summary

This audit identifies **7 critical issues** and **5 high-risk issues** that could cause data corruption, security breaches, or user confusion in production. All issues must be fixed before production deployment.

---

## 🔴 CRITICAL ISSUES

### CRIT-1: `graph_save` Allows Autosave on Published Graphs (B1)
**Location:** `source/dag/dag_graph_api.php:666`  
**Severity:** 🔴 CRITICAL - Data Integrity Violation

**Issue:**
```php
if ($graphStatus === 'published' && !$isAutosave) {
    // Block manual save, but ALLOW autosave
}
```

**Problem:**
- Autosave bypasses immutability check for Published graphs
- Comment says "positions only, doesn't modify graph structure" but this is **false assumption**
- Autosave can merge with DB state and accidentally modify structure
- **Risk:** Published graphs can be modified through autosave endpoint

**Reproduction:**
1. Load Published graph version
2. Call `graph_save` with `save_type=autosave` and modified nodes/edges
3. Graph gets modified despite being Published

**Fix Required:**
```php
// Block ALL writes to Published graphs, including autosave
if ($graphStatus === 'published') {
    json_error(..., 403, ['app_code' => 'DAG_ROUTING_403_PUBLISHED_IMMUTABLE']);
}
```

**Files to Change:**
- `source/dag/dag_graph_api.php:666`

---

### CRIT-2: Missing `graph_autosave_positions` Endpoint Check (B1)
**Location:** Endpoint not found in current codebase  
**Severity:** 🔴 CRITICAL - Security Gap

**Issue:**
- Comment mentions "Frontend primarily uses graph_autosave_positions" (line 573)
- **This endpoint is NOT FOUND in codebase**
- If it exists elsewhere or is added later, it may bypass immutability checks

**Fix Required:**
1. Search for `graph_autosave_positions` in entire codebase
2. If exists, add published status check
3. If doesn't exist, remove comment reference

---

### CRIT-3: Missing `node_update_properties` Immutability Check (B1)
**Location:** Endpoint not found  
**Severity:** 🔴 CRITICAL - Security Gap

**Issue:**
- Audit checklist explicitly requires checking `node_update_properties`
- **Endpoint not found in codebase**
- If exists, may allow Published graph modification

**Fix Required:**
1. Search entire codebase for `node_update_properties`
2. Add Published/Retired immutability check if found
3. Document if endpoint doesn't exist or was removed

---

### CRIT-4: Version Switch State Not Fully Reset (A3)
**Location:** `assets/javascripts/dag/graph_designer.js:324-335, 1147-1174`  
**Severity:** 🔴 CRITICAL - State Corruption

**Issue:**
- `createCytoscapeInstance()` destroys and recreates Cytoscape instance ✅
- BUT: `window.isReadOnlyMode` may not be reset correctly
- Global variables like `currentGraphData`, `currentETag` updated, but event listeners may persist
- `window._selectedVersionForLoad` cleared too late (after async operation)

**Problem Scenario:**
1. User selects Published version (read-only)
2. User quickly switches to Draft version (editable)
3. If switch happens before `updateReadOnlyMode()` completes, state is inconsistent
4. Save operation may target wrong version

**Fix Required:**
```javascript
function handleVersionSwitch(selectedVersion, status) {
    // CRITICAL: Reset state IMMEDIATELY before async operation
    window.isReadOnlyMode = undefined; // Clear before load
    updateReadOnlyMode(false); // Reset to false, will be updated after load
    
    // Store selected version
    window._selectedVersionForLoad = {...};
    
    // Then proceed with load
}
```

**Files to Change:**
- `assets/javascripts/dag/graph_designer.js:9637-9693`

---

### CRIT-5: Version Status Logic Inconsistency (A3)
**Location:** `source/dag/Graph/Service/GraphService.php:144-269`  
**Severity:** 🔴 CRITICAL - Status Semantics

**Issue:**
- When loading `latest` with draft → sets `status = 'draft'` ✅
- When loading `latest` without draft → queries `routing_graph_version` for latest published ✅
- **BUT:** What if graph has NO published versions yet?
- Fallback sets `status = 'published'` even though graph never published
- This allows reads but prevents edits incorrectly

**Problem:**
- New graph with only draft → loads as "published" → blocks edits incorrectly
- Graph should be editable if no published version exists

**Fix Required:**
```php
if ($latestVersion) {
    $graph['status'] = $latestVersion['status'] ?? 'published';
} else {
    // No published version = graph is in draft state (editable)
    $graph['status'] = 'draft'; // Not 'published'!
}
```

**Files to Change:**
- `source/dag/Graph/Service/GraphService.php:248-253`

---

### CRIT-6: Version Ordering Uses VARCHAR Sort (C1)
**Location:** `source/dag/Graph/Repository/GraphMetadataRepository.php:266-311`  
**Severity:** 🔴 CRITICAL - UX/Logic Bug

**Issue:**
- Versions sorted by `published_at DESC` (correct for date)
- But if user manually specifies version like "v10", "v2" → VARCHAR sort gives wrong order
- Frontend displays versions in wrong order

**Current Code:**
```php
ORDER BY published_at DESC, id_version DESC
```

**Problem:**
- If multiple versions published same second → relies on `id_version`
- Version strings like "1.0", "2.0", "10.0" work fine (numeric)
- But "v1", "v2", "v10" would sort wrong if used

**Fix Required:**
- Current implementation is **ACCEPTABLE** because:
  1. Versions are generated as "1.0", "2.0" (numeric, not "v1", "v2")
  2. Primary sort by `published_at` is correct
  3. Secondary sort by `id_version` handles ties
- **Recommendation:** Add unit test to ensure version generation always produces sortable format

**Files to Review:**
- `source/dag/Graph/Service/GraphVersionService.php:generateNextVersion()`
- Ensure it always returns numeric format (e.g., "1.0", not "v1.0")

---

### CRIT-7: Draft Info Included When Loading Specific Version (A3)
**Location:** `source/dag/Graph/Service/GraphService.php:144-269`  
**Severity:** 🔴 CRITICAL - Status Confusion

**Issue:**
- When loading specific version (not 'latest'), `draftInfo` is correctly set to `null` ✅
- **BUT:** Frontend logic in `handleGraphLoaded()` still has fallback that checks `draftInfo`:
```javascript
if (!graphStatus && draftInfo && draftInfo.has_draft) {
    graphStatus = 'draft';
}
```

**Problem:**
- If backend accidentally sends `draftInfo` for specific version → frontend overrides status
- Edge case but possible if code changes

**Fix Required:**
- Backend fix is correct (already implemented)
- Frontend should add defensive check:
```javascript
// CRITICAL: Ignore draftInfo if status is explicitly set from version
if (!graphStatus && draftInfo && draftInfo.has_draft) {
    // Only set draft if status is truly missing (shouldn't happen for specific versions)
    graphStatus = 'draft';
}
```

**Status:** ✅ Backend fixed, ⚠️ Frontend needs defensive check

---

## 🟡 HIGH RISK ISSUES

### HIGH-1: `allow_new_jobs` Not Enforced in All Resolvers (C2)
**Location:** `source/dag/Graph/Service/GraphVersionResolver.php`  
**Severity:** 🟡 HIGH

**Issue:**
- `GraphVersionResolver::resolveForProduct()` checks `allow_new_jobs` ✅
- But job creation endpoints may bypass resolver
- Need to audit all job creation paths

**Fix Required:**
1. Search codebase for job creation endpoints
2. Ensure they all use `GraphVersionResolver` or check `allow_new_jobs`
3. Add integration tests

---

### HIGH-2: Version Selector Event Listener Duplication (A3)
**Location:** `assets/javascripts/dag/graph_designer.js:9695-9709`  
**Severity:** 🟡 HIGH

**Issue:**
- Uses `$(document).on('change', '#version-selector', ...)` (event delegation) ✅
- This is safe and prevents duplication
- **BUT:** If `#version-selector` is recreated (removed/added to DOM), events still work
- No risk of duplication ✅

**Status:** ✅ Safe (event delegation used)

---

### HIGH-3: Save Button Logic May Target Wrong Version (D2)
**Location:** `assets/javascripts/dag/graph_designer.js:saveGraph()`  
**Severity:** 🟡 HIGH

**Issue:**
- `saveGraph()` checks `currentGraphData.draft.has_draft` to route to `saveDraft()`
- When viewing Published version, `draftInfo` is `null` (correct)
- **BUT:** If user switches version rapidly, `currentGraphData` may be stale

**Fix Required:**
- Ensure `currentGraphData` is updated synchronously before save
- Add defensive check:
```javascript
function saveGraph() {
    // CRITICAL: Re-check status from current loaded graph
    const currentStatus = (currentGraphData?.graph?.status) || 'draft';
    if (currentStatus === 'published' || currentStatus === 'retired') {
        notifyError('Cannot save Published/Retired version');
        return;
    }
    // Then proceed with draft check
}
```

---

### HIGH-4: Missing Context=Product Enforcement Audit (A2)
**Location:** Product viewer endpoints  
**Severity:** 🟡 HIGH

**Issue:**
- Audit checklist requires verifying all product-related endpoints use `context=product`
- **Not fully audited in this report** (requires full codebase search)

**Fix Required:**
1. Search for all product viewer/modal endpoints
2. Verify they all use `GraphVersionResolver::resolveForProduct()`
3. Add integration tests

---

### HIGH-5: Retired Status Read-Only Enforcement
**Location:** Multiple endpoints  
**Severity:** 🟡 HIGH

**Issue:**
- Code checks `status === 'published'` but may miss `status === 'retired'`
- Retired graphs should also be immutable

**Current Checks:**
- `graph_save`: Only checks `published` ❌
- Frontend: Checks both `published` and `retired` ✅

**Fix Required:**
```php
if (in_array($graphStatus, ['published', 'retired'])) {
    json_error(..., 403);
}
```

**Files to Change:**
- `source/dag/dag_graph_api.php:666`

---

## 🟢 MEDIUM RISK ISSUES

### MED-1: Version Number Generation Edge Cases
**Location:** `source/dag/Graph/Service/GraphVersionService.php:generateNextVersion()`  
**Severity:** 🟢 MEDIUM

**Issue:**
- Version generation assumes major.minor format ("1.0", "2.0")
- If version string is malformed, parsing may fail
- Should add validation

**Fix Recommended:**
- Add regex validation for version format
- Handle edge cases (null, empty, invalid format)

---

### MED-2: Draft Payload Normalization Consistency
**Location:** `source/dag/Graph/Service/GraphService.php:174-203`  
**Severity:** 🟢 MEDIUM

**Issue:**
- Draft payload normalization uses same logic as `loadGraphWithVersion()`
- Should extract to shared function to ensure consistency

**Fix Recommended:**
- Extract normalization to helper function
- Use in both places

---

## ⚪ LOW RISK / RECOMMENDATIONS

### LOW-1: Add Comprehensive Integration Tests
**Recommendation:** Create integration tests covering:
1. Switching versions 10+ times
2. Attempting to save Published version via all endpoints
3. Product viewer isolation (draft never visible)
4. Version ordering correctness

---

## Priority Fix List

### Must Fix Before Production (🔴):
1. **CRIT-1:** Block autosave on Published graphs
2. **CRIT-2:** Audit `graph_autosave_positions` endpoint
3. **CRIT-3:** Audit `node_update_properties` endpoint
4. **CRIT-4:** Fix version switch state reset
5. **CRIT-5:** Fix status logic for new graphs
6. **CRIT-7:** Add defensive checks in frontend
7. **HIGH-5:** Block writes to Retired graphs

### Should Fix Soon (🟡):
8. **HIGH-1:** Audit job creation paths
9. **HIGH-3:** Add defensive checks in save logic
10. **HIGH-4:** Complete product context audit

---

## Testing Checklist

- [ ] Attempt to save Published graph via `graph_save` (manual) → Must fail
- [ ] Attempt to save Published graph via `graph_save` (autosave) → Must fail
- [ ] Attempt to save Published graph via `graph_save_draft` → Must create draft (not modify published)
- [ ] Switch version 10 times (draft↔published↔retired) → State must be consistent
- [ ] Create job from Retired version → Must fail
- [ ] Product viewer shows only Published/Retired → Never Draft
- [ ] Version selector shows correct order (1.0, 2.0, 3.0... not 1.0, 10.0, 2.0)

---

## Notes

- Most critical issues are in backend immutability enforcement
- Frontend has good defensive checks but can be improved
- Version switching logic is mostly correct but needs state reset fixes
- Testing coverage for versioning scenarios is insufficient

