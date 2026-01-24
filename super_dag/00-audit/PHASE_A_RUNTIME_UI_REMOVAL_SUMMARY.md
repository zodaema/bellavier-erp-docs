# Phase A: Runtime UI Removal Summary

**Date:** 2025-12-12  
**Phase:** A - UI Cleanup (Backend Preserved)  
**Status:** ✅ **COMPLETED**

---

## Executive Summary

**Goal:** Remove "Runtime ON/OFF" UI elements completely while preserving backend logic for Phase B migration.

**Result:** ✅ All Runtime UI elements removed. Backend logic preserved (commented out, not deleted).

---

## Files Modified

### 1. `views/routing_graph_designer.php`
**Change:** Removed Runtime toggle button from toolbar
- **Line 165-169:** Removed `<button id="btn-toggle-runtime">` element
- **Added:** Comment explaining removal (Phase A) and future replacement (Phase B)

**Before:**
```php
<button type="button" class="btn btn-sm btn-secondary" id="btn-toggle-runtime" 
        data-bs-toggle="tooltip" data-bs-placement="bottom" 
        title="<?php echo translate('routing.toggle_runtime', 'Toggle Runtime'); ?>">
  <i class="ri-toggle-line"></i>
</button>
```

**After:**
```php
<!-- Phase A: Runtime toggle button removed - will be replaced with version-level "Allow New Jobs" in Phase B -->
```

---

### 2. `assets/javascripts/dag/graph_designer.js`

#### Change 1: Removed Runtime badge from title
- **Line 9422-9438:** Simplified `updateFeatureFlagUI()` function
- **Removed:** Runtime ON/OFF badge display logic
- **Preserved:** Badge cleanup (`.badge-runtime` removal) for safety

**Before:**
```javascript
function updateFeatureFlagUI() {
    const flags = featureFlagsCache[currentGraphId] || {};
    const runtimeFlag = flags['RUNTIME_ENABLED'];
    const runtimeEnabled = runtimeFlag && runtimeFlag.flag_value === 'on';
    
    const titleEl = $('#graph-title');
    titleEl.find('.badge-runtime').remove();
    
    if (runtimeEnabled) {
        titleEl.append(' <span class="badge bg-success badge-runtime">Runtime: ON</span>');
    } else {
        titleEl.append(' <span class="badge bg-secondary badge-runtime">Runtime: OFF</span>');
    }
}
```

**After:**
```javascript
function updateFeatureFlagUI() {
    if (!currentGraphId) return;
    
    // Phase A: Runtime badge removed - will be replaced with version-level "Allow New Jobs" in Phase B
    // Removed Runtime ON/OFF badge display
    const titleEl = $('#graph-title');
    titleEl.find('.badge-runtime').remove();
}
```

#### Change 2: Removed tooltip initialization
- **Line 9372:** Removed `#btn-toggle-runtime` from tooltip initialization selector

**Before:**
```javascript
$('#btn-save-graph, #btn-validate-graph, #btn-publish-graph, #btn-toggle-runtime, #btn-delete-graph').each(function() {
```

**After:**
```javascript
// Phase A: Removed #btn-toggle-runtime from tooltip initialization
$('#btn-save-graph, #btn-validate-graph, #btn-publish-graph, #btn-delete-graph').each(function() {
```

---

### 3. `assets/javascripts/dag/modules/EventManager.js`

#### Change 1: Disabled event binding
- **Line 150-152:** Commented out click event binding for `#btn-toggle-runtime`
- **Added:** Comment explaining Phase A removal

**Before:**
```javascript
$(document).on('click', '#btn-toggle-runtime', () => {
    this.handleToggleRuntime();
});
```

**After:**
```javascript
// Phase A: Runtime toggle event binding removed - will be replaced with version-level toggle in Phase B
// $(document).on('click', '#btn-toggle-runtime', () => {
//     this.handleToggleRuntime();
// });
```

#### Change 2: Disabled handler function
- **Line 260-300:** Modified `handleToggleRuntime()` to early return
- **Preserved:** Original code in comments for Phase B migration
- **Added:** Console warning for debugging

**Before:**
```javascript
handleToggleRuntime() {
    const currentGraphId = this.deps.getCurrentGraphId();
    // ... full implementation
}
```

**After:**
```javascript
/**
 * Handle toggle runtime feature flag
 * 
 * Phase A: Disabled - Runtime toggle removed from UI
 * Will be replaced with version-level "Allow New Jobs" toggle in Phase B
 */
handleToggleRuntime() {
    // Phase A: Early return - Runtime toggle disabled
    // Backend logic preserved for Phase B migration
    console.warn('[EventManager] handleToggleRuntime() called but disabled in Phase A');
    return;
    
    /* DISABLED CODE - Preserved for Phase B migration
    ... original implementation ...
    */
}
```

#### Change 3: Removed from cleanup
- **Line 71, 73:** Removed `#btn-toggle-runtime` from event cleanup

**Before:**
```javascript
'#btn-toggle-runtime').off('click');
$(document).off('click', '#btn-toggle-runtime');
```

**After:**
```javascript
// Phase A: Removed #btn-toggle-runtime from cleanup
```

---

### 4. `assets/javascripts/dag/graph_sidebar.js`

**Change:** Removed Runtime badge from graph list
- **Line 433-435:** Removed `runtimeBadge` variable and rendering
- **Line 464:** Removed `${runtimeBadge}` from template

**Before:**
```javascript
const runtimeBadge = graph.runtime_enabled 
    ? '<span class="badge bg-info">Runtime</span>' 
    : '';

// ... in template:
${statusBadge}
${versionBadge}
${runtimeBadge}
```

**After:**
```javascript
// Phase A: Runtime badge removed - will be replaced with version-level "Allow New Jobs" in Phase B

// ... in template:
${statusBadge}
${versionBadge}
```

---

## What Was Removed

### UI Elements Removed:
1. ✅ **Runtime Toggle Button** - Removed from toolbar (`#btn-toggle-runtime`)
2. ✅ **Runtime Badge (Title)** - Removed "Runtime: ON/OFF" from graph title
3. ✅ **Runtime Badge (Sidebar)** - Removed "Runtime" badge from graph list
4. ✅ **Tooltip** - Removed tooltip initialization for toggle button
5. ✅ **Event Handlers** - Disabled click event binding

### Backend Logic Preserved:
1. ✅ **`toggleFeatureFlag()` function** - Still exists in `graph_designer.js` (not called from UI)
2. ✅ **`handleToggleRuntime()` function** - Disabled but code preserved in comments
3. ✅ **API endpoint** - `graph_flag_set` action still exists (not called from UI)
4. ✅ **Feature flag storage** - `routing_graph_feature_flag` table unchanged

---

## What Was NOT Removed (Intentionally)

### Preserved for Phase B:
- `toggleFeatureFlag()` function (line 9440-9463 in `graph_designer.js`)
- Backend API endpoint `graph_flag_set` (not modified)
- Database table `routing_graph_feature_flag` (not modified)
- `isGraphRuntimeEnabled()` function in backend (not modified)

### Preserved for Context:
- ETA preview text mentioning "Runtime ETA" (line 5354) - This is informational text about token execution, not UI toggle

---

## Smoke Test Checklist

### ✅ Test 1: Graph Designer UI
- [x] Open Graph Designer
- [x] Verify: No "Runtime: ON/OFF" badge in graph title
- [x] Verify: No Runtime toggle button in toolbar
- [x] Verify: No JavaScript errors in console

### ✅ Test 2: Graph Sidebar
- [x] Open Graph List sidebar
- [x] Verify: No "Runtime" badge in graph list items
- [x] Verify: Status badges (Draft/Published) still display correctly

### ✅ Test 3: Event Handlers
- [x] Verify: No click handlers bound to `#btn-toggle-runtime`
- [x] Verify: No API calls to `graph_flag_set` when clicking toolbar buttons
- [x] Verify: Console shows warning if `handleToggleRuntime()` is called (defensive)

### ✅ Test 4: Backend Compatibility
- [x] Verify: Backend API endpoints still exist (not broken)
- [x] Verify: Feature flag storage unchanged
- [x] Verify: No database schema changes

---

## UI Before/After

### Before:
```
[Graph Title] [Runtime: ON]  ← Badge in title
[Save] [Validate] [Publish] [Runtime Toggle] [Delete]  ← Toggle button
Graph List:
  - Graph 1 [Published] [Runtime]  ← Badge in sidebar
```

### After:
```
[Graph Title]  ← Clean, no Runtime badge
[Save] [Validate] [Publish] [Delete]  ← No toggle button
Graph List:
  - Graph 1 [Published]  ← Clean, no Runtime badge
```

---

## Debug Mode (Not Implemented)

**Note:** Per requirements, debug mode was not implemented in Phase A. If needed for development, it can be added in Phase B with:
- `?debug=1` URL parameter check
- Owner permission check
- Conditional UI rendering

**Current State:** All Runtime UI completely removed (no debug mode).

---

## Next Steps (Phase B)

**Phase B will:**
1. Add `allow_new_jobs` field to `routing_graph_version` table
2. Migrate existing `RUNTIME_ENABLED` flags to version level
3. Add guard check in `JobCreationService::createDAGJob()`
4. Implement version-level "Allow New Jobs" toggle in Version Bar
5. Update UI labels and semantics

**Reference:** See `RUNTIME_ENABLED_AUDIT_AND_MIGRATION.md` for Phase B plan.

---

## Summary

**Files Modified:** 4 files
- `views/routing_graph_designer.php` (1 change)
- `assets/javascripts/dag/graph_designer.js` (2 changes)
- `assets/javascripts/dag/modules/EventManager.js` (3 changes)
- `assets/javascripts/dag/graph_sidebar.js` (1 change)

**UI Elements Removed:** 5 elements
- Runtime toggle button
- Runtime badge (title)
- Runtime badge (sidebar)
- Tooltip initialization
- Event handlers

**Backend Logic:** ✅ Preserved (commented, not deleted)

**Status:** ✅ **READY FOR PHASE B**

