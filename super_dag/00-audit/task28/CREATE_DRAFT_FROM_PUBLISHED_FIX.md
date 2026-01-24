# Task 28.x - Create Draft From Published Fix
**Date:** 2025-12-13  
**Status:** ✅ **COMPLETED**  
**Priority:** P0 (403 Forbidden When Creating Draft)

---

## Executive Summary

Fixed critical bug where "Create Draft" button returned 403 Forbidden. The `GraphSaveModeResolver` was blocking creation of new drafts from published graphs, even when full payload was provided.

---

## 🚨 Problem

### Root Cause

**Error:**
```
403 Forbidden: "Cannot create draft on Published/Retired graph without active draft. 
Use 'Create Draft' button to create an editable draft version."
```

**Issue:**
- User clicks "Create Draft" button from published graph
- Frontend sends `action: 'graph_save_draft'` with full payload (nodes + edges)
- Backend routes to `graph_save` with `save_type: 'draft'`
- `GraphSaveModeResolver` checks: `!$hasActiveDraft && graphStatus=published`
- **Blocks the request** even though this IS the "Create Draft" workflow

**Logic Flaw:**
The resolver was designed to prevent accidental draft creation via normal save, but it also blocked the intentional "Create Draft" button workflow.

---

## ✅ Solution

### Fix Applied

**Strategy:** Allow creating new draft from published graph if full payload is provided.

**Logic:**
- If `!$hasActiveDraft && graphStatus=published && full payload` → **Allow** (Create Draft workflow)
- If `!$hasActiveDraft && graphStatus=published && no/partial payload` → **Block** (Invalid request)

**Code:**
```php
case 'draft':
    // P0 FIX: Allow creating new draft from published graph if full payload is provided
    // This enables "Create Draft" button workflow which sends full graph payload
    $isCreatingNewDraft = !$hasActiveDraft && 
                          in_array($graphStatus, ['published', 'retired']) &&
                          $payloadHasNodes && 
                          $payloadHasEdges;
    
    if (!$hasActiveDraft && in_array($graphStatus, ['published', 'retired']) && !$isCreatingNewDraft) {
        // Block only if no payload (invalid request) or partial payload
        throw new \RuntimeException(
            "Cannot create draft on Published/Retired graph without active draft. " .
            "Use 'Create Draft' button to create an editable draft version with full graph payload."
        );
    }
    
    // Draft save: Always go to draft table (full payload required)
    return [...];
```

---

## 📋 Workflow (After Fix)

### Create Draft From Published

1. **User clicks "Create Draft" button**
2. **Frontend sends:**
   ```json
   {
     "action": "graph_save_draft",
     "id_graph": 1957,
     "nodes": "[{...}, {...}]",  // Full payload
     "edges": "[{...}, {...}]"   // Full payload
   }
   ```

3. **Backend processes:**
   - Routes to `graph_save` with `save_type: 'draft'`
   - `GraphSaveModeResolver` checks:
     - `!$hasActiveDraft` ✅ (no active draft)
     - `graphStatus=published` ✅
     - `$payloadHasNodes && $payloadHasEdges` ✅ (full payload)
     - **Result:** `$isCreatingNewDraft = true` → **ALLOW**

4. **Backend creates:**
   - New draft in `routing_graph_draft` table
   - New nodes with new IDs (cloned from published)
   - New edges linked via `node_code`

5. **Result:** Draft created successfully ✅

---

## ⚠️ Node Positions Issue (Separate Investigation)

**Observation:** Node positions on published graph appear shifted (similar to draft that was overwritten).

**Possible Causes:**
1. **Autosave to published graph** (should be blocked, but verify)
2. **Draft positions merged into published** during publish workflow
3. **Legacy data** from previous drafts

**Current Protection:**
- `autosave_main` is blocked on published graphs (line 93-98 in resolver)
- `autosave_draft` only updates draft table (not published)

**Recommendation:**
- Investigate if positions are being updated during publish workflow
- Check if `GraphVersionService::publish()` preserves positions correctly
- Verify no legacy autosave logic is still active

---

## 🧪 Testing Checklist

### Must Pass ✅

1. ✅ Create Draft from published graph → Success (no 403)
2. ✅ Draft contains all nodes and edges from published
3. ✅ Draft nodes have new IDs (different from published)
4. ✅ Edges link correctly using node_code
5. ✅ Can edit draft without affecting published

---

## Related Documents

- `DRAFT_CREATE_EDGE_FIX.md` - Edge loss fix
- `P0_RESOLVER_LOGIC_FIXES.md` - Resolver fixes

