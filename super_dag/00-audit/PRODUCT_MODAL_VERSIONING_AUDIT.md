# Product Modal & Graph Versioning Audit

**Date:** 2025-12-12  
**Purpose:** Audit Product Modal and Product Binding integration with Graph Versioning system  
**Status:** 📋 **AUDIT COMPLETE**

---

## Executive Summary

**Current State:**
- Product Modal uses `product_graph_binding.js` to display graph preview
- Product Binding uses `ProductGraphBindingHelper` to resolve graph versions
- **Issue:** No enforcement that Product Viewer only shows Published versions
- **Risk:** Product viewer may display Draft versions, violating production safety

**Required Changes:**
- Enforce Published-only resolution in `ProductGraphBindingHelper`
- Add validation in Product Modal preview
- Update API endpoints to reject Draft versions in product context

---

## Current Implementation

### 1. Product Modal Structure

**File:** `views/products.php`
- Modal ID: `#product-graph-binding-modal`
- Tabs: Binding, Statistics, History, Component Mapping, Components, Classic Dashboard
- Graph preview shown in Binding tab

**File:** `assets/javascripts/products/product_graph_binding.js`
- Main module: `ProductGraphBinding`
- Graph preview function: `showGraphPreviewWithViewer(graphId, graphName, version)`
- Uses `GraphViewer` component for rendering

### 2. Graph Preview Flow

**Current Flow:**
```
User clicks "Preview Graph" 
  → showGraphPreviewWithViewer(graphId, graphName, version)
  → API call: dag_routing_api.php?action=get_graph&id_graph=${graphId}&version=${version}
  → GraphViewer.create() renders graph
```

**Issues:**
1. ❌ No validation that `version` is Published (not Draft)
2. ❌ API `get_graph` may return Draft version if version parameter is Draft
3. ❌ No error handling for Draft version requests

### 3. ProductGraphBindingHelper

**File:** `source/BGERP/Helper/ProductGraphBindingHelper.php`

#### 3.1 `getGraphVersion()` Method

**Current Implementation:**
```php
public static function getGraphVersion(\mysqli $db, int $graphId, ?string $pinVersion = null): ?string {
    if ($pinVersion !== null && $pinVersion !== '') {
        $version = db_fetch_one($db, "
            SELECT version 
            FROM routing_graph_version 
            WHERE id_graph = ? AND version = ? AND published_at IS NOT NULL
        ", [$graphId, $pinVersion]);
        
        return $version ? $version['version'] : null;
    }
    
    // Get latest stable version
    $latest = db_fetch_one($db, "
        SELECT version 
        FROM routing_graph_version 
        WHERE id_graph = ? 
            AND is_stable = 1 
            AND published_at IS NOT NULL
        ORDER BY published_at DESC 
        LIMIT 1
    ", [$graphId]);
    
    return $latest ? $latest['version'] : null;
}
```

**Issues:**
1. ❌ Checks `published_at IS NOT NULL` but doesn't check `status = 'published'`
2. ❌ Doesn't validate that version is not Draft
3. ❌ Uses `is_stable` flag (may not align with new versioning model)

**Required Fix:**
- Add `status = 'published'` check
- Reject Draft versions explicitly
- Consider `allow_new_jobs = 1` for active versions

#### 3.2 `validateBinding()` Method

**Current Implementation:**
```php
public static function validateBinding(\mysqli $db, int $productId, int $graphId, ?string $version = null): array {
    // ...
    if ($graph['status'] !== 'published') {
        $errors[] = 'Graph must be published before binding';
    }
    
    // Check version if provided
    if ($version !== null && $graph) {
        $versionCheck = db_fetch_one($db, "
            SELECT id_version, is_stable, published_at 
            FROM routing_graph_version 
            WHERE id_graph = ? AND version = ? AND published_at IS NOT NULL
        ", [$graphId, $version]);
        
        if (!$versionCheck) {
            $errors[] = "Version '{$version}' not found or not published";
        }
    }
    // ...
}
```

**Issues:**
1. ⚠️ Checks graph status but not version status
2. ❌ Doesn't check `status = 'published'` for version
3. ❌ Doesn't reject Draft versions explicitly

**Required Fix:**
- Add version status check: `status = 'published'` or `status = 'retired'`
- Reject Draft versions explicitly

### 4. API Endpoints

#### 4.1 `dag_routing_api.php?action=get_graph`

**Current Behavior:**
- Accepts `id_graph` and optional `version` parameter
- Returns graph data (nodes, edges) for preview

**Issues:**
1. ❌ No validation that version is Published
2. ❌ May return Draft version if requested
3. ❌ No context-aware enforcement (product vs. designer)

**Required Fix:**
- Add `context` parameter: `product` vs `designer`
- If `context=product`, enforce Published-only
- If `context=designer`, allow Draft versions

#### 4.2 `dag_routing_api.php?action=graph_viewer`

**Current Behavior:**
- Similar to `get_graph` but optimized for viewer
- Used by Product Modal preview

**Issues:**
1. ❌ Same issues as `get_graph`
2. ❌ No Published-only enforcement

**Required Fix:**
- Same as `get_graph` (add context parameter)

### 5. Product Binding UI

**File:** `assets/javascripts/products/product_graph_binding.js`

#### 5.1 Version Pinning (Currently Disabled)

**Current State:**
- Version pinning UI removed (Task 25.3)
- Always uses "latest stable" automatically
- Comment: "Version pinning removed - always use latest stable automatically"

**Note:** This aligns with concept doc (default = latest published), but needs enforcement.

#### 5.2 Graph Preview

**Function:** `showGraphPreviewWithViewer(graphId, graphName, version)`

**Current Implementation:**
```javascript
const endpoint = version 
  ? `source/dag_routing_api.php?action=get_graph&id_graph=${graphId}&version=${version}`
  : `source/dag_routing_api.php?action=get_graph&id_graph=${graphId}`;

$.getJSON(endpoint, function(resp) {
  if (resp && resp.ok && resp.nodes) {
    // Render with GraphViewer
  }
});
```

**Issues:**
1. ❌ No validation that version is Published
2. ❌ No error handling for Draft version rejection
3. ❌ No context parameter to indicate product viewer

**Required Fix:**
- Add `context=product` parameter to API call
- Handle error response if Draft version is requested
- Show clear error message to user

---

## Required Changes

### Priority 1: Backend Enforcement (Critical)

#### Change 1.1: Update `ProductGraphBindingHelper::getGraphVersion()`

**File:** `source/BGERP/Helper/ProductGraphBindingHelper.php`

**Required Changes:**
```php
public static function getGraphVersion(\mysqli $db, int $graphId, ?string $pinVersion = null): ?string {
    // Normalize empty string to null
    if ($pinVersion !== null && $pinVersion !== '') {
        $version = db_fetch_one($db, "
            SELECT version 
            FROM routing_graph_version 
            WHERE id_graph = ? 
                AND version = ? 
                AND status = 'published'  -- ✅ ADD: Enforce Published only
                AND published_at IS NOT NULL
        ", [$graphId, $pinVersion]);
        
        if (!$version) {
            // ✅ ADD: Log warning if Draft version requested
            error_log("ProductGraphBindingHelper: Attempted to get Draft version {$pinVersion} for graph {$graphId}");
            return null;
        }
        
        return $version['version'];
    }
    
    // Get latest published version (not just stable)
    $latest = db_fetch_one($db, "
        SELECT version 
        FROM routing_graph_version 
        WHERE id_graph = ? 
            AND status = 'published'  -- ✅ ADD: Enforce Published only
            AND published_at IS NOT NULL
        ORDER BY published_at DESC 
        LIMIT 1
    ", [$graphId]);
    
    return $latest ? $latest['version'] : null;
}
```

#### Change 1.2: Update `ProductGraphBindingHelper::validateBinding()`

**Required Changes:**
```php
// In version check section:
if ($version !== null && $graph) {
    $versionCheck = db_fetch_one($db, "
        SELECT id_version, status, published_at 
        FROM routing_graph_version 
        WHERE id_graph = ? 
            AND version = ? 
            AND status IN ('published', 'retired')  -- ✅ ADD: Allow Published or Retired
            AND published_at IS NOT NULL
    ", [$graphId, $version]);
    
    if (!$versionCheck) {
        $errors[] = "Version '{$version}' not found or not published/retired";
    } elseif ($versionCheck['status'] === 'draft') {
        $errors[] = "Draft versions cannot be bound to products";  -- ✅ ADD: Explicit rejection
    }
}
```

### Priority 2: API Endpoint Updates

#### Change 2.1: Add Context Parameter to `get_graph` Action

**File:** `source/dag_routing_api.php`

**Required Changes:**
- Add `context` parameter: `product` | `designer` | `runtime`
- If `context=product`, enforce Published-only:
  ```php
  if ($context === 'product' && $version) {
      // Validate version is Published
      $versionCheck = db_fetch_one($db, "
          SELECT status 
          FROM routing_graph_version 
          WHERE id_graph = ? AND version = ?
      ", [$graphId, $version]);
      
      if (!$versionCheck || $versionCheck['status'] !== 'published') {
          json_error('Draft versions cannot be viewed in product context', 403, [
              'app_code' => 'DAG_ROUTING_403_DRAFT_IN_PRODUCT'
          ]);
      }
  }
  ```

#### Change 2.2: Update `graph_viewer` Action

**Same changes as `get_graph`** (add context parameter and enforcement)

### Priority 3: Frontend Updates

#### Change 3.1: Update `showGraphPreviewWithViewer()`

**File:** `assets/javascripts/products/product_graph_binding.js`

**Required Changes:**
```javascript
function showGraphPreviewWithViewer(graphId, graphName, version) {
    // ... existing modal creation ...
    
    // ✅ ADD: Add context=product parameter
    const endpoint = version 
      ? `source/dag_routing_api.php?action=get_graph&id_graph=${graphId}&version=${version}&context=product`
      : `source/dag_routing_api.php?action=get_graph&id_graph=${graphId}&context=product`;
    
    $.getJSON(endpoint, function(resp) {
      if (resp && resp.ok && resp.nodes) {
        // ... existing rendering ...
      } else {
        // ✅ ADD: Better error handling for Draft version rejection
        const errorMsg = resp?.app_code === 'DAG_ROUTING_403_DRAFT_IN_PRODUCT'
          ? t('product_graph.draft_not_allowed', 'Draft versions cannot be viewed in product context. Please select a published version.')
          : (resp?.message || t('product_graph.no_data', 'No graph data available'));
        
        $('#graph-viewer-preview-container').html(`
          <div class="alert alert-warning m-3">
            <i class="fe fe-info me-2"></i>
            ${errorMsg}
          </div>`);
      }
    }).fail(function(xhr) {
      // ... existing error handling ...
    });
}
```

#### Change 3.2: Update Version Display

**Required Changes:**
- Show version status badge (Published/Retired) in Product Modal
- Hide Draft versions from version selector (if any)
- Display warning if attempting to preview Draft version

---

## Integration with Task 28

### Task 28.3: Product Viewer Isolation

**This audit directly supports Task 28.3.**

**Implementation Checklist:**
- [ ] Update `ProductGraphBindingHelper::getGraphVersion()` (Change 1.1)
- [ ] Update `ProductGraphBindingHelper::validateBinding()` (Change 1.2)
- [ ] Add context parameter to `get_graph` API (Change 2.1)
- [ ] Add context parameter to `graph_viewer` API (Change 2.2)
- [ ] Update `showGraphPreviewWithViewer()` (Change 3.1)
- [ ] Add version status display in Product Modal (Change 3.2)
- [ ] Test: Product viewer rejects Draft versions
- [ ] Test: Product viewer shows Published versions correctly
- [ ] Test: Error messages are clear

---

## Risk Assessment

### High Risk
- **Breaking Change:** If `getGraphVersion()` suddenly rejects existing bindings
- **Mitigation:** Check existing bindings first, migrate if needed

### Medium Risk
- **User Confusion:** If Draft version was previously viewable, users may be confused
- **Mitigation:** Clear error messages, gradual rollout

### Low Risk
- **UI Changes:** Adding context parameter is non-breaking
- **Backward Compatibility:** Default context can be 'designer' for existing calls

---

## Testing Requirements

### Test Cases

1. **Product Viewer with Published Version**
   - ✅ Should display graph correctly
   - ✅ Should show version badge (Published)

2. **Product Viewer with Draft Version (Should Fail)**
   - ❌ Should reject with clear error message
   - ❌ Should not display graph

3. **Product Viewer with Retired Version**
   - ✅ Should display graph (view-only)
   - ✅ Should show version badge (Retired)
   - ⚠️ Should show warning that version is retired

4. **Product Viewer without Version (Auto Latest)**
   - ✅ Should resolve to latest Published version
   - ✅ Should not resolve to Draft version

5. **Graph Designer with Draft Version**
   - ✅ Should display Draft version (context=designer)
   - ✅ Should allow editing

---

## Summary

**Current Issues:**
1. ❌ No Published-only enforcement in ProductGraphBindingHelper
2. ❌ API endpoints don't validate version status
3. ❌ Frontend doesn't handle Draft version rejection

**Required Actions:**
1. ✅ Update `ProductGraphBindingHelper` methods (Priority 1)
2. ✅ Add context parameter to API endpoints (Priority 2)
3. ✅ Update frontend preview function (Priority 3)

**Integration:**
- Directly supports **Task 28.3: Product Viewer Isolation**
- Must be completed as part of Phase 1 (Safety Net)

**Status:** ✅ **READY FOR IMPLEMENTATION**
