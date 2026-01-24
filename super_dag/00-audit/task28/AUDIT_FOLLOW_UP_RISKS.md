# Task 28.x - Audit Follow-up: Remaining Risks & Verifications
**Date:** 2025-12-13  
**Status:** ⚠️ **RISKS IDENTIFIED** - Fixes Required  
**Priority:** P1 (High)

---

## Executive Summary

Following the normalization refactor, an external AI audit identified **1 critical risk** (B) that requires immediate fix, and **2 acceptable risks** (A, C) with mitigation strategies.

---

## ⚠️ Critical Risk (P0): Autosave with Active Draft

### Problem
**Location:** `dag_graph_api.php` line 489, `GraphSaveEngine->save()` line 295-320

**Issue:**
- When `save_type='autosave'` and an active draft exists, the code does NOT force routing to `GraphDraftService`.
- Instead, it falls through to `GraphSaveEngine->save()` which updates the **main `routing_node` table** directly.
- This means autosave positions are saved to the published graph instead of the draft table.

**Scenario:**
1. Graph has Published version v1.0
2. User creates Draft
3. User drags nodes (autosave triggers)
4. Autosave goes to `GraphSaveEngine->save()` → Updates `routing_node` table (main table)
5. **Result:** Published graph positions are modified, violating immutability

### Current Code
```php
// dag_graph_api.php line 489
if (!$isAutosave && !$isNodeUpdate && ($isDraft || $hasActiveDraft)) {
    $saveType = 'draft'; // Force manual save to draft
}
// Note: Autosave is NOT forced to draft!
```

### Fix Required
**Force autosave to draft when active draft exists:**

```php
// dag_graph_api.php - Fix autosave routing
if (($isDraft || $hasActiveDraft) && ($isAutosave || $isNodeUpdate || !$isAutosave)) {
    // If active draft exists, ALL saves (including autosave) should go to draft
    $saveType = 'draft';
    $isDraft = true;
}
```

**Alternative:** Route autosave to `GraphDraftService` explicitly when `$hasActiveDraft` is true.

---

## 🔶 Acceptable Risk (P1): Numeric ID Collision

### Problem
**Location:** `GraphPayloadNormalizer.php` line 193-198

**Issue:**
- If frontend generates a numeric temp ID (e.g., `"1001"`) and a DB node with ID `1001` exists, the code assumes it's a DB ID.
- Current code checks if numeric ID exists in payload, but edge case remains if numeric temp ID is not in payload but matches a DB ID.

### Current Mitigation
`GraphPayloadNormalizer::resolveNodeCode()` checks:
1. Cytoscape ID mapping (from payload)
2. Node lookup (from payload)
3. **Nodes array scan** (from payload) ← This should catch most cases

### Fix Required
**Frontend Contract Enforcement:**
- Frontend MUST use prefix for temp IDs (e.g., `tmp_1001`, `n_1001`).
- Backend should add validation warning if numeric temp IDs are detected.

**Status:** ✅ **Acceptable Risk** - Current mitigation is sufficient. Frontend contract enforcement is the proper fix.

---

## 🔶 Acceptable Risk (P2): Error Handling Brittleness

### Problem
**Location:** `dag_graph_api.php` line 796, 830

**Issue:**
- Uses `strpos($message, '...')` to parse error messages.
- If error message format changes in Service layer, API will return wrong status codes.

### Current Status
**Acceptable Risk** - Low priority for now. Proper fix would require structured exceptions, which is a larger refactor.

---

## ✅ Verified: Frontend Autosave Implementation

### Check Result
**Location:** `assets/javascripts/dag/modules/GraphSaver.js` line 357-427

**Finding:**
- `saveAuto()` method does NOT send `save_type='autosave'` parameter.
- It sends `action='graph_save'` with nodes/edges payload.
- API detects autosave by checking if `save_type` is missing and `nodes`/`edges` are missing/empty.

**Fix Required:**
**Add `save_type='autosave'` to frontend autosave call:**

```javascript
// GraphSaver.js - saveAuto() method
const response = await this.api.call('graph_save', {
    id_graph: graphId,
    save_type: 'autosave', // ✅ ADD THIS
    nodes: nodesPositions.length > 0 ? JSON.stringify(nodesPositions) : '',
    edges: '', // Autosave doesn't modify edges
    'If-Match': ifMatch
});
```

---

## ✅ Verified: GraphSaveEngine Autosave Logic

### Check Result
**Location:** `GraphSaveEngine->save()` line 295-320

**Finding:**
- `GraphSaveEngine` does NOT check for active draft.
- Autosave updates `routing_node` table directly (line 309, 315).
- **This confirms the critical risk (B) is valid.**

**Fix Required:**
- Route autosave to `GraphDraftService` when active draft exists (see Fix Required section above).

---

## Action Items

### 🔴 P0 - Critical (Must Fix Before Production)

1. **Fix Autosave Routing** (`dag_graph_api.php` line 700-715) ✅ **FIXED**
   - Force autosave to draft when active draft exists
   - Route to `GraphDraftService` instead of `GraphSaveEngine`
   - Status: Applied - All saves (including autosave) now route to draft when active draft exists

2. **Add `save_type` to Frontend Autosave** (`GraphSaver.js`)
   - Send `save_type='autosave'` explicitly
   - Improves API contract clarity

### 🟡 P1 - High (Should Fix Soon)

3. **Frontend ID Generation Contract**
   - Enforce temp ID prefix (e.g., `tmp_`, `n_`)
   - Document in frontend coding standards

### 🟢 P2 - Low (Acceptable Risk)

4. **Error Handling Refactor** (Future)
   - Replace string parsing with structured exceptions
   - Low priority, acceptable for now

---

## Testing Checklist

After fixes:
- [ ] Test: Autosave with active draft → positions saved to draft table
- [ ] Test: Autosave without draft → positions saved to main table (for draft-only graphs)
- [ ] Test: Autosave on published graph (no draft) → returns 403
- [ ] Test: Frontend sends `save_type='autosave'` correctly
- [ ] Test: Numeric temp ID collision (edge case)

---

## Related Documents

- `NORMALIZATION_REFACTOR_COMPLETE.md` - Original refactor
- `CRITICAL_BUGS_FIXED.md` - Previous critical fixes
- `SAVE_SEMANTICS_REFACTOR.md` - Save semantics refactor

