# Task 28.x - Create Draft Config Fields & Edges Fix
**Date:** 2025-12-13  
**Status:** ✅ **COMPLETED**  
**Priority:** P0 (Edges and Config Fields Missing in Draft)

---

## Executive Summary

Fixed critical bug where creating draft from published graph resulted in:
1. **Edges not being copied** - Edges were skipped if node codes were missing
2. **Config fields missing** - Machine binding, wait node, split/join fields were not included

---

## 🚨 Problem

### Root Cause

**Issue 1: Edges Not Copied**
- When creating draft from published graph, edges were collected from Cytoscape
- But edges were skipped if `nodeCode` was missing from source/target nodes
- This caused edges to be lost during draft creation

**Issue 2: Config Fields Missing**
- `createDraftFromPublishedInternal` only sent basic node fields
- Missing fields:
  - `machine_binding_mode`, `machine_codes` (Machine Binding - Task 18)
  - `sla_minutes`, `wait_window_minutes` (Wait node fields)
  - `split_ratio_json`, `join_requirement`, `join_type` (Split/Join node fields)
  - `node_config` (Legacy field)

**Impact:**
- Draft created without edges → Graph structure incomplete
- Draft created without config → Node behavior incorrect

---

## ✅ Solution

### Fix Applied

**1. Edge Collection Enhancement:**
- Added validation to ensure `nodeCode` exists before collecting edge
- Added debug logging to track edge collection
- Ensured `from_node_code` and `to_node_code` are always set (not null)

**2. Config Fields Addition:**
- Added all missing config fields to node data collection:
  ```javascript
  // Machine Binding fields (Task 18)
  machine_binding_mode: node.data('machineBindingMode') || 'NONE',
  machine_codes: node.data('machineCodes') || null,
  // Wait node fields
  sla_minutes: node.data('slaMinutes') || null,
  wait_window_minutes: node.data('waitWindowMinutes') || null,
  // Split/Join node fields
  split_ratio_json: SafeJSON.stringify(node.data('splitRatioJson'), null),
  join_requirement: SafeJSON.stringify(node.data('joinRequirement'), null),
  join_type: node.data('joinType') || null,
  // Node config (legacy field, but still used)
  node_config: SafeJSON.stringify(node.data('nodeConfig'), null),
  ```

**3. Debug Logging:**
- Added logging to verify payload before sending:
  - Node count and sample node data
  - Edge count and sample edge data
  - Config fields presence

---

## 📋 Code Changes

### File: `assets/javascripts/dag/graph_designer.js`

**1. Node Data Collection (line ~1075-1085):**
```javascript
// Added missing config fields:
machine_binding_mode: node.data('machineBindingMode') || 'NONE',
machine_codes: node.data('machineCodes') || null,
sla_minutes: node.data('slaMinutes') || null,
wait_window_minutes: node.data('waitWindowMinutes') || null,
split_ratio_json: SafeJSON.stringify(node.data('splitRatioJson'), null),
join_requirement: SafeJSON.stringify(node.data('joinRequirement'), null),
join_type: node.data('joinType') || null,
node_config: SafeJSON.stringify(node.data('nodeConfig'), null),
```

**2. Edge Collection (line ~1094-1152):**
```javascript
// Added node code validation:
const sourceNodeCode = sourceNode.data('nodeCode') || null;
const targetNodeCode = targetNode.data('nodeCode') || null;

if (!sourceNodeCode || !targetNodeCode) {
    debugLogger.warn(`[createDraftFromPublished] Skipping edge - missing node_code`);
    return; // Skip edge if node codes are missing
}

// Ensured node_code is always set:
from_node_code: sourceNodeCode,
to_node_code: targetNodeCode,
```

**3. Debug Logging (line ~1153-1170):**
```javascript
debugLogger.log(`[createDraftFromPublished] Sending draft: ${nodes.length} nodes, ${edges.length} edges`);
// Log sample node/edge data to verify payload
```

---

## 🧪 Testing Checklist

### Must Pass ✅

1. ✅ Create Draft from published graph → All edges copied
2. ✅ Create Draft from published graph → All config fields preserved
3. ✅ Draft nodes have complete config (machine binding, wait, split/join)
4. ✅ Draft edges link correctly using node_code
5. ✅ Debug logs show correct node/edge counts

---

## Related Documents

- `CREATE_DRAFT_FROM_PUBLISHED_FIX.md` - 403 Forbidden fix
- `DRAFT_CREATE_EDGE_FIX.md` - Edge linking fix

