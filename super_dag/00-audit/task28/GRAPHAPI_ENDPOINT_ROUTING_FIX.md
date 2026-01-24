# Task 28.x - GraphAPI Endpoint Routing Fix
**Date:** 2025-12-13  
**Status:** ✅ **COMPLETED**  
**Priority:** P0 (Integration Breakers - URL Routing)

---

## Executive Summary

Fixed critical integration issues where `GraphAPI.js` was routing all requests to a single endpoint, causing graph operations to fail. Separated endpoints by responsibility and fixed autosave parameter format.

---

## 🚨 Critical Issues Fixed

### ✅ Fix 1: Separated Endpoint Routing

**Problem:**
- `GraphAPI.js` used single `baseURL` for all operations
- All requests (save, load, validate, publish) went to same endpoint
- Graph operations should use `dag_graph_api.php`, validation/publish should use `dag_routing_api.php`

**Solution:**
- Added `endpoints` object with `MANAGEMENT` and `LOGIC` separation
- Updated `_request()` method to accept `customURL` parameter
- Routed each method to appropriate endpoint

**Code:**
```javascript
constructor(config = {}) {
    // P0 FIX: Separate endpoints by responsibility for proper routing
    this.endpoints = {
        MANAGEMENT: config.baseURL || 'source/dag_graph_api.php',  // Graph CRUD
        LOGIC: 'source/dag_routing_api.php'                        // Validation, publish
    };
    this.baseURL = this.endpoints.MANAGEMENT; // Legacy compatibility
}

_request(method, data, headers = {}, customURL = null) {
    const url = customURL || this.baseURL;
    // ... use url instead of this.baseURL
}
```

**Endpoint Mapping:**
- `getGraph()` → `MANAGEMENT`
- `saveGraph()` → `MANAGEMENT`
- `autosavePositions()` → `MANAGEMENT`
- `saveDraft()` → `MANAGEMENT`
- `discardDraft()` → `MANAGEMENT`
- `deleteGraph()` → `MANAGEMENT`
- `listGraphs()` → `MANAGEMENT`
- `validateGraph()` → `LOGIC`
- `publishGraph()` → `LOGIC`

---

### ✅ Fix 2: Autosave Parameter Format

**Problem:**
- `autosavePositions()` used `action: 'graph_autosave_positions'` and `nodes_positions` key
- Backend expects `action: 'graph_save'` with `save_type: 'autosave'` and `nodes` key

**Solution:**
- Changed action to `graph_save`
- Added `save_type: 'autosave'` parameter
- Changed `nodes_positions` → `nodes` (consistent with other save operations)

**Before:**
```javascript
return this._request('POST', {
    action: 'graph_autosave_positions',
    id_graph: graphId,
    nodes_positions: nodesPositionsStr
}, headers);
```

**After:**
```javascript
return this._request('POST', {
    action: 'graph_save',
    save_type: 'autosave',
    id_graph: graphId,
    nodes: nodesStr  // Backend reads from 'nodes' key
}, headers, this.endpoints.MANAGEMENT);
```

---

### ✅ Fix 3: GraphLoader Fallback URL

**Problem:**
- Fallback AJAX in `GraphLoader.js` used hardcoded `dag_routing_api.php`
- Should use `dag_graph_api.php` for graph load operations

**Solution:**
- Updated fallback URL to `dag_graph_api.php`

**Before:**
```javascript
jQuery.ajax({
    url: 'source/dag_routing_api.php',
    // ...
});
```

**After:**
```javascript
// P0 FIX: Updated endpoint to dag_graph_api.php for graph load operations
jQuery.ajax({
    url: 'source/dag_graph_api.php',
    // ...
});
```

---

## 📋 Endpoint Architecture (Final)

### Management API (`dag_graph_api.php`)
**Purpose:** Graph CRUD operations (Create, Read, Update, Delete)

**Actions:**
- `graph_get` - Load graph data
- `graph_list` - List graphs with filters
- `graph_create` - Create new graph
- `graph_save` - Save graph (with `save_type`: draft|autosave|publish)
- `graph_save_draft` - Alias for `graph_save` with `save_type=draft`
- `graph_discard_draft` - Discard active draft
- `graph_delete` - Delete/archive graph

### Logic API (`dag_routing_api.php`)
**Purpose:** Validation and publishing workflows

**Actions:**
- `graph_validate` - Validate graph structure
- `graph_publish` - Publish graph version
- Other routing-specific operations

---

## 🧪 Testing Checklist

### Must Pass ✅

1. ✅ `getGraph()` → Calls `dag_graph_api.php?action=graph_get`
2. ✅ `saveGraph()` → Calls `dag_graph_api.php?action=graph_save`
3. ✅ `autosavePositions()` → Calls `dag_graph_api.php?action=graph_save&save_type=autosave&nodes=...`
4. ✅ `validateGraph()` → Calls `dag_routing_api.php?action=graph_validate`
5. ✅ `publishGraph()` → Calls `dag_routing_api.php?action=graph_publish`
6. ✅ GraphLoader fallback → Uses `dag_graph_api.php`

---

## Related Documents

- `FRONTEND_INTEGRATION_FIX.md` - Frontend format fixes
- `FILE_LOCATION_FIX.md` - File location fix

