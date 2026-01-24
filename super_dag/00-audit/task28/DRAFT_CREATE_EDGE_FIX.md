# Task 28.x - Draft Create Edge Loss Fix
**Date:** 2025-12-13  
**Status:** ✅ **COMPLETED**  
**Priority:** P0 (Edge Loss When Creating Draft from Published)

---

## Executive Summary

Fixed critical bug where edges were lost when creating draft from published graph. The issue was caused by sending old published node/edge IDs, which backend tried to link to published nodes instead of newly created draft nodes.

---

## 🚨 Problem

### Root Cause

When creating draft from published graph:
1. **Backend creates new nodes** in draft table with new `id_node` values (e.g., published node ID=10 → draft node ID=20)
2. **Frontend sends old IDs** in edge data (`from_node_id: 10`, `to_node_id: 10`)
3. **Backend tries to link** edges to old published nodes (ID=10) instead of new draft nodes (ID=20)
4. **Result:** Edges are lost or linked incorrectly

### Technical Details

**Before Fix:**
```javascript
// Nodes: Sending published node IDs
id_node: nodeId,  // e.g., 10 (published node ID)

// Edges: Sending published node IDs
from_node_id: sourceNode.data('dbId'),  // e.g., 10 (published node ID)
to_node_id: targetNode.data('dbId'),    // e.g., 15 (published node ID)
```

**Problem Flow:**
1. User clicks "Create Draft" from published graph
2. Frontend sends nodes with `id_node: 10` (published ID)
3. Backend creates new draft node with `id_node: 20` (new ID)
4. Frontend sends edges with `from_node_id: 10` (old published ID)
5. Backend tries to find node with `id_node: 10` in draft table → **NOT FOUND**
6. Edge is lost or fails to link

---

## ✅ Solution

### Fix Applied

**Strategy:** Send `null` for all IDs to force backend to:
1. Create new nodes in draft table
2. Resolve edges using `node_code` instead of `id_node`

### Code Changes

#### 1. Node Data (Line ~1050)

**Before:**
```javascript
id_node: nodeId,  // Published node ID
temp_id: tempId || null,
```

**After:**
```javascript
// P0 FIX: Send null to force backend to create new node in draft table
id_node: null,

// P0 FIX: Generate new temp_id for draft clone
temp_id: nodeCode ? 'draft_clone_' + nodeCode : null,
```

**Result:** Backend creates new nodes with new IDs, all nodes have `node_code` for edge resolution.

#### 2. Edge Data (Line ~1108)

**Before:**
```javascript
id_edge: edge.data('dbId'),
from_node_id: sourceNode.data('dbId') || null,
to_node_id: targetNode.data('dbId') || null,
```

**After:**
```javascript
// P0 FIX: Send null to force backend to create new edge in draft table
id_edge: null,

// P0 FIX: Send null IDs to force backend to use node_code for edge resolution
from_node_id: null,
to_node_id: null,

// P0 FIX: These are the critical fields - backend uses these to resolve node IDs
from_node_code: sourceNode.data('nodeCode') || null,
to_node_code: targetNode.data('nodeCode') || null,
```

**Result:** Backend resolves edges using `from_node_code`/`to_node_code`, which match the newly created draft nodes.

---

## 🔄 Backend Processing Flow (After Fix)

1. **Frontend sends:**
   ```json
   {
     "nodes": [
       {"id_node": null, "node_code": "NODE_A", ...},
       {"id_node": null, "node_code": "NODE_B", ...}
     ],
     "edges": [
       {"id_edge": null, "from_node_id": null, "to_node_id": null, 
        "from_node_code": "NODE_A", "to_node_code": "NODE_B", ...}
     ]
   }
   ```

2. **Backend processes:**
   - Creates new nodes in draft table (new `id_node` values: 20, 21)
   - Normalizes edges using `GraphPayloadNormalizer`
   - Resolves `from_node_code: "NODE_A"` → finds draft node with `node_code: "NODE_A"` → gets `id_node: 20`
   - Resolves `to_node_code: "NODE_B"` → finds draft node with `node_code: "NODE_B"` → gets `id_node: 21`
   - Creates edge with `from_node_id: 20, to_node_id: 21` ✅

3. **Result:** All edges correctly linked to new draft nodes

---

## 📋 Testing Checklist

### Must Pass ✅

1. ✅ Create draft from published graph → All edges preserved
2. ✅ Draft nodes have new IDs (different from published)
3. ✅ Edges link to correct draft nodes (not published nodes)
4. ✅ Graph structure identical to published version
5. ✅ Can edit draft without affecting published version

---

## Related Documents

- `FRONTEND_INTEGRATION_FIX.md` - Frontend format fixes
- `GRAPHAPI_ENDPOINT_ROUTING_FIX.md` - API routing fixes

