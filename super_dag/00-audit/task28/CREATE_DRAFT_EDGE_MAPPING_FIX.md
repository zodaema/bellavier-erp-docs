# Task 28.x - Create Draft Edge Mapping Fix
**Date:** 2025-12-13  
**Status:** ✅ **COMPLETED**  
**Priority:** P0 (Edges Not Loading from Draft)

---

## Executive Summary

Fixed critical bug where edges were not loaded when creating draft from published graph. The issue was in `createCytoscapeInstance` edge resolution logic - it didn't properly handle `node_code` mapping when `from_node_id`/`to_node_id` were null (draft graphs).

---

## 🚨 Problem

### Root Cause

**Issue: Edges Not Loading from Draft**

When loading a draft graph:
1. Draft nodes have `id_node: null` (new nodes)
2. Draft edges have `from_node_id: null`, `to_node_id: null`
3. Edges rely on `from_node_code`/`to_node_code` for resolution
4. `createCytoscapeInstance` tried to resolve edges using `nodeCodeToCyId` map
5. **But**: The map was only built from `el.data.nodeCode` (camelCase), not `el.data.node_code` (snake_case)
6. **Result**: Edge resolution failed, edges were skipped as "orphaned"

**Additional Issues:**
- Map didn't support both `nodeCode` and `node_code` field names
- No debug logging to troubleshoot edge resolution failures
- Edge mapping logic didn't check both field name variants

---

## ✅ Solution

### Fix Applied

**1. Enhanced Node Code Mapping:**
- Map supports both `nodeCode` (camelCase) and `node_code` (snake_case)
- Ensures compatibility with both frontend and backend formats

**2. Improved Edge Resolution:**
- Support both `from_node_code`/`to_node_code` and `fromNodeCode`/`toNodeCode` field names
- Better error messages with debug logging
- Log available node codes when mapping fails

**3. Debug Logging:**
- Log node code map size and sample entries
- Log edge mapping failures with detailed context
- Log available node codes when resolution fails

---

## 📋 Code Changes

### File: `assets/javascripts/dag/graph_designer.js`

**1. Node Code Map Building (line ~465-476):**
```javascript
// P0 FIX: Support both node_code (backend format) and nodeCode (frontend format)
const nodeCodeToCyId = new Map();
elements.forEach(el => {
    if (el.group !== 'nodes') return;
    nodeIdSet.add(el.data.id);
    // Map both nodeCode (camelCase) and node_code (snake_case) for compatibility
    const nodeCode = el.data.nodeCode || el.data.node_code || null;
    if (nodeCode) {
        nodeCodeToCyId.set(nodeCode, el.data.id);
    }
});
```

**2. Edge Resolution (line ~477-510):**
```javascript
// P0 FIX: Support both from_node_code and fromNodeCode field names
const fromNodeCode = edge.from_node_code || edge.fromNodeCode || null;
const toNodeCode = edge.to_node_code || edge.toNodeCode || null;

if (edge.from_node_id && edge.to_node_id) {
    // Use numeric IDs (published graphs)
    sourceId = 'n' + edge.from_node_id;
    targetId = 'n' + edge.to_node_id;
} else if (fromNodeCode && toNodeCode) {
    // P0 FIX: Use node_code mapping (draft graphs)
    sourceId = nodeCodeToCyId.get(fromNodeCode) || null;
    targetId = nodeCodeToCyId.get(toNodeCode) || null;
    
    // Debug log if mapping fails
    if (!sourceId || !targetId) {
        debugLogger.warn(`[createCytoscapeInstance] Failed to map edge by node_code...`);
    }
}
```

**3. Debug Logging:**
```javascript
// Log node code map for troubleshooting
if (nodeCodeToCyId.size > 0) {
    debugLogger.log(`[createCytoscapeInstance] Built nodeCodeToCyId map with ${nodeCodeToCyId.size} entries...`);
}

// Enhanced orphaned edge warning
debugLogger.warn(`[createCytoscapeInstance] Skipping orphaned edge ${eid}: source=${sourceId}, target=${targetId}, from_code=${fromNodeCode || ''}, to_code=${toNodeCode || ''}, from_id=${edge.from_node_id || 'null'}, to_id=${edge.to_node_id || 'null'}`);
```

---

## 🧪 Testing Checklist

### Must Pass ✅

1. ✅ Create Draft from published graph → Edges load correctly
2. ✅ Load draft graph → All edges visible in Cytoscape
3. ✅ Edge resolution uses `node_code` when `id_node` is null
4. ✅ Debug logs show correct node code mapping
5. ✅ No orphaned edge warnings for valid edges

---

## Related Documents

- `CREATE_DRAFT_CONFIG_FIELDS_FIX.md` - Config fields fix
- `CREATE_DRAFT_FROM_PUBLISHED_FIX.md` - 403 Forbidden fix
- `DRAFT_CREATE_EDGE_FIX.md` - Edge linking fix

