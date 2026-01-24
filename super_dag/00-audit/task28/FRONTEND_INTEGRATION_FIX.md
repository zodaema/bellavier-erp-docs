# Task 28.x - Frontend Integration Fix
**Date:** 2025-12-13  
**Status:** ✅ **COMPLETED**  
**Priority:** P0 (Integration Trap - Autosave Format Mismatch)

---

## Executive Summary

Fixed critical integration issue where frontend autosave format did not match backend expectations. Backend autosave does NOT call Normalizer for performance, so frontend must send data in exact snake_case format expected by backend.

---

## 🚨 The Integration Trap

### Problem

**Backend Behavior:**
- `draft` save: Calls `GraphPayloadNormalizer` → Accepts camelCase, converts to snake_case
- `autosave_draft` / `autosave_main`: **NO Normalizer** (performance optimization) → Reads fields directly

**Frontend Behavior (Before Fix):**
- Autosave sent `graph_autosave_positions` action to `dag_routing_api.php`
- Format was mostly correct but endpoint was wrong
- Missing `node_code` field (critical for new nodes)

**Result:**
- Autosave would fail silently if JS sent format that didn't match exactly
- New nodes without `id_node` would be skipped (no `node_code` to identify them)

---

## ✅ Fixes Applied

### 1. Changed API Endpoints

**Changed:**
- `dag_routing_api.php` → `dag_graph_api.php` for all graph operations (load, save)
- **Kept:** `dag_routing_api.php` for validate/publish operations (correct)

**Files Changed:**
- `graph_designer.js`:
  - GraphAPI baseURL (line 153)
  - Autosave endpoint (line 1902)
  - Manual save endpoint (line 2292)
  - Graph load endpoints (multiple locations)
  - `graph_save_draft` endpoint (line 1128)
  - Apply quick fix endpoint (line 4626)

---

### 2. Added `save_type` Parameter

**Manual Save:**
```javascript
const data = {
    action: 'graph_save',
    save_type: 'draft', // Explicit draft save
    id_graph: currentGraphId,
    nodes: ...,
    edges: ...
};
```

**Autosave:**
```javascript
const data = {
    action: 'graph_save',
    save_type: 'autosave', // Backend will route to autosave_draft or autosave_main
    id_graph: currentGraphId,
    nodes: ... // JSON string of position updates
};
```

**Result:** Backend `GraphSaveModeResolver` routes correctly based on `save_type` and graph state.

---

### 3. Fixed Autosave Format (CRITICAL)

**Before (Incorrect):**
```javascript
// Missing node_code, endpoint wrong
nodesPositions.push({
    id_node: dbId,
    position_x: Math.round(node.position('x')),
    position_y: Math.round(node.position('y')),
    node_name: node.data('label') || null
});
// Used: action: 'graph_autosave_positions', nodes_positions: ...
```

**After (Correct):**
```javascript
// P0 FIX: Backend autosave does NOT call Normalizer - must send exact format
const nodesPositions = [];
cy.nodes().forEach(node => {
    const dbId = node.data('dbId'); // id_node
    const nodeCode = node.data('nodeCode'); // node_code (CRITICAL for new nodes)
    const position = node.position();
    
    // Must have identifier (id_node OR node_code)
    if ((dbId && dbId > 0) || nodeCode) {
        nodesPositions.push({
            // CRITICAL: Backend reads these fields directly (snake_case)
            id_node: dbId && dbId > 0 ? dbId : null,
            node_code: nodeCode || null, // Required for new nodes
            position_x: Math.round(position.x), // Flattened (not position: {x, y})
            position_y: Math.round(position.y), // Flattened
            node_name: node.data('label') || null
        });
    }
});

// Use unified endpoint
const data = {
    action: 'graph_save',
    save_type: 'autosave',
    id_graph: currentGraphId,
    nodes: SafeJSON.stringify(nodesPositions, '[]') // JSON string (not nodes_positions)
};
```

**Key Changes:**
1. ✅ Added `node_code` field (critical for new nodes)
2. ✅ Changed `nodes_positions` → `nodes` (unified endpoint format)
3. ✅ Changed action `graph_autosave_positions` → `graph_save` with `save_type=autosave`
4. ✅ Position is flattened (`position_x`, `position_y`) not nested (`position: {x, y}`)
5. ✅ All field names are snake_case (backend expects directly)

---

## 📋 Backend Autosave Format Contract

**Backend Expects (for autosave_draft / autosave_main):**
```javascript
{
    action: 'graph_save',
    save_type: 'autosave',
    id_graph: <number>,
    nodes: <JSON string of array>, // Required for autosave
    edges: <not sent for autosave> // Optional, usually omitted
}
```

**Node Array Format (inside `nodes` JSON string):**
```javascript
[
    {
        id_node: <number> | null,      // DB ID (null for new nodes)
        node_code: <string> | null,    // String identifier (required if id_node is null)
        position_x: <number>,          // Flattened position (not nested)
        position_y: <number>,          // Flattened position (not nested)
        node_name: <string> | null     // Optional label update
    },
    ...
]
```

**Backend Processing (No Normalizer):**
```php
// Backend reads directly (no normalization)
$node['id_node']      // Used if present
$node['node_code']    // Used if id_node is null
$node['position_x']   // Must be exact field name
$node['position_y']   // Must be exact field name
$node['node_name']    // Optional
```

---

## 🧪 Testing Checklist

### Must Pass ✅

1. ✅ Autosave with existing nodes (have id_node) → Updates positions correctly
2. ✅ Autosave with new nodes (have node_code, no id_node) → Updates positions correctly
3. ✅ Manual save → Uses graph_save with save_type=draft
4. ✅ Graph load → Uses dag_graph_api.php?action=graph_get
5. ✅ Validate/Publish → Still uses dag_routing_api.php (correct)

### Integration Points

- ✅ Autosave sends `node_code` for new nodes
- ✅ Autosave uses flattened position (position_x, position_y)
- ✅ All field names are snake_case
- ✅ Endpoint changed to dag_graph_api.php
- ✅ save_type parameter added to all save operations

---

## Related Documents

- `P0_P1_FINAL_AUDIT_FIXES.md` - Backend fixes
- `P0_RESOLVER_LOGIC_FIXES.md` - Save mode resolver fixes

