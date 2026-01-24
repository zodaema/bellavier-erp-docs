# Task 28.x - Create Draft Edge Fix - VERIFIED ✅
**Date:** 2025-12-13  
**Status:** ✅ **VERIFIED - WORKING**  
**Priority:** P0 (Edges Not Loading from Draft)

---

## Executive Summary

**Issue Resolved:** Edges were already saved correctly in draft payload, but frontend couldn't map them when loading draft because it only checked `from_node_id` (which is null for draft edges). After fixing the edge resolution logic to support `node_code` mapping, edges now display correctly after page refresh.

---

## 🎯 Root Cause (Confirmed)

### The Real Issue

**Not a Backend Problem:**
- Draft payload (`routing_graph_draft.draft_payload_json`) already contained edges correctly
- Edges had `from_node_code`/`to_node_code` (correct)
- Edges had `from_node_id: null`, `to_node_id: null` (correct for new draft)

**Frontend Mapping Problem:**
- `createCytoscapeInstance` only checked `edge.from_node_id` for edge resolution
- When `from_node_id` was null (draft edges), it couldn't map edges to nodes
- Result: All draft edges were skipped as "orphaned"

**Why It Worked After Fix:**
- Fixed code now checks `from_node_code`/`to_node_code` when `id_node` is null
- Builds `nodeCodeToCyId` map from Cytoscape node data
- Successfully maps edges using node codes

---

## ✅ Solution Applied

### Fix: Enhanced Edge Resolution Logic

**File:** `assets/javascripts/dag/graph_designer.js`

**Changes:**
1. **Node Code Map Building:**
   - Builds `nodeCodeToCyId` map from both `nodeCode` and `node_code`
   - Supports both camelCase and snake_case field names

2. **Edge Resolution Priority:**
   - Priority 1: `from_node_id`/`to_node_id` (published graphs)
   - Priority 2: `from_node_code`/`to_node_code` (draft graphs) ← **This was missing**
   - Priority 3: `source`/`target` (fallback)

3. **Debug Logging:**
   - Logs node code map size and sample entries
   - Logs edge mapping failures with detailed context
   - Helps troubleshoot if issues occur

---

## 📊 Verification Results

### Test Case: Existing Draft (After Fix)

1. ✅ **Created draft before fix** - Edges were saved correctly in draft payload
2. ✅ **Fixed edge resolution code** - Added `node_code` mapping support
3. ✅ **Refreshed page** - Edges now display correctly
4. ✅ **No need to recreate draft** - Existing draft payload was already correct

### Conclusion

**The draft payload was correct all along.** The issue was purely in the frontend edge resolution logic. Once fixed, existing drafts work immediately without needing to be recreated.

---

## 🧪 Testing Checklist

### Verified ✅

1. ✅ Existing drafts load edges correctly after fix
2. ✅ Edge resolution uses `node_code` when `id_node` is null
3. ✅ No orphaned edge warnings for valid edges
4. ✅ Debug logs show correct node code mapping
5. ✅ Both `nodeCode` and `node_code` field names supported

---

## 📝 Key Learnings

1. **Draft Payload Structure Was Correct:**
   - Backend correctly saved edges with `from_node_code`/`to_node_code`
   - Frontend just couldn't use them due to missing fallback logic

2. **Field Name Compatibility:**
   - Need to support both camelCase (`nodeCode`) and snake_case (`node_code`)
   - Backend uses snake_case, frontend uses camelCase

3. **Debug Logging Importance:**
   - Debug logs helped identify that edges were saved but not displayed
   - Will help troubleshoot similar issues in the future

---

## Related Documents

- `CREATE_DRAFT_EDGE_MAPPING_FIX.md` - Technical fix details
- `CREATE_DRAFT_CONFIG_FIELDS_FIX.md` - Config fields fix
- `CREATE_DRAFT_FROM_PUBLISHED_FIX.md` - 403 Forbidden fix

