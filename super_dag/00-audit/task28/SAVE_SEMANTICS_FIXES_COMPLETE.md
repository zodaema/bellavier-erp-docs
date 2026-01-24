# Task 28.x - Save Semantics Fixes (Complete)
**Date:** 2025-12-13  
**Status:** ✅ **FIXES COMPLETE**  
**Priority:** P0 (Critical)

---

## Executive Summary

Fixed **3 critical issues** identified in audit:
1. ✅ `graph_save_draft` now truly an alias (forwards to `graph_save`)
2. ✅ **P0 Bug Fixed**: Autosave no longer forced to draft (prevents draft data loss)
3. ✅ Publish routing blocked (no fall-through, clear error message)

---

## Fixes Applied

### ✅ Fix 1: graph_save_draft is Now a True Alias

**Problem:**
- `graph_save_draft` had separate implementation, not truly an alias
- Called `GraphDraftService::saveDraft()` directly
- Documentation said "alias" but code didn't match

**Solution:**
- Removed entire duplicate implementation
- Set `$_POST['save_type'] = 'draft'` and fall through to `graph_save`
- Maintains backward compatibility while unifying semantics

**Files Modified:**
- `source/dag/dag_graph_api.php` (lines 507-509)

**Impact:**
- ✅ True alias - all draft saves go through unified `graph_save` handler
- ✅ No code duplication
- ✅ Documentation matches code

---

### ✅ Fix 2: P0 Bug - Autosave No Longer Forced to Draft

**Problem:**
```php
// OLD CODE (BUGGY):
if ($isDraft || $hasActiveDraft) {
    $saveType = 'draft';
    $isDraft = true;
}
```
- Autosave could be forced to draft if `hasActiveDraft = true`
- Autosave sends empty/partial nodes/edges
- Would overwrite draft with empty graph → **draft data loss**

**Solution:**
```php
// NEW CODE (FIXED):
if (!$isAutosave && !$isNodeUpdate && ($isDraft || $hasActiveDraft)) {
    // Force route to draft ONLY for manual structural saves
    $saveType = 'draft';
    $isDraft = true;
    $isAutosave = false; // Ensure flags are cleared
    $isNodeUpdate = false;
}
```

**Files Modified:**
- `source/dag/dag_graph_api.php` (lines 771-781)

**Impact:**
- ✅ Autosave remains autosave (position-only updates via GraphSaveEngine)
- ✅ Node update remains node_update (not forced to draft)
- ✅ Only manual structural saves are forced to draft when active draft exists
- ✅ Prevents draft data loss from autosave

---

### ✅ Fix 3: Publish Routing - Blocked (No Fall-Through)

**Problem:**
- Publish routing had TODO and fell through to GraphSaveEngine
- Unclear behavior - didn't actually publish
- Risk: Users think they're publishing but it's just saving

**Solution:**
- Block publish via `graph_save` endpoint
- Return 501 with clear error message
- Must use dedicated publish workflow/endpoint

**Files Modified:**
- `source/dag/dag_graph_api.php` (lines 1037-1046)

**Impact:**
- ✅ Clear error message when trying to publish via save
- ✅ No fall-through confusion
- ✅ Forces use of proper publish workflow

---

## Routing Logic (Final)

| Condition | Route | Service | Table |
|-----------|-------|---------|-------|
| `save_type=draft` | Draft save | `GraphDraftService::saveDraft()` | `routing_graph_draft` |
| `save_type=autosave` | Autosave | `GraphSaveEngine` (autosave mode) | Main tables (position only) |
| `save_type=publish` | **BLOCKED** | Returns 501 error | N/A |
| `save_type=node_update` | **NOT IMPLEMENTED** | Returns 501 error | N/A |
| `hasActiveDraft` + manual save | Force draft | `GraphDraftService::saveDraft()` | `routing_graph_draft` |
| `hasActiveDraft` + autosave | Autosave | `GraphSaveEngine` (autosave mode) | Main tables (position only) |

---

## Additional P1 Fix (Observability)

### ✅ P1: Autosave Payload Error Logging

**Problem:**
- Autosave silently swallows JSON decode errors
- No warning/metrics when payload is invalid
- Makes debugging difficult in production

**Solution:**
- Added error logging when autosave payload decode fails
- Added metrics tracking: `dag_routing.autosave.payload_invalid`
- Logs include graph_id, field (nodes/edges), and error type

**Files Modified:**
- `source/dag/dag_graph_api.php` (lines 731-768)

**Impact:**
- ✅ Better observability for autosave issues
- ✅ Metrics available for monitoring
- ✅ Easier debugging in production

---

## Remaining P1/P2 Items (Not Critical)

### P1: Normalization Logic Duplication
- **Status:** Known issue, in TODO list
- **Impact:** Maintenance burden (not correctness issue)
- **Recommendation:** Extract to `GraphPayloadNormalizer` service (future work)

### P2: save_type Default Behavior
- **Status:** Working as designed (legacy fallback)
- **Impact:** UX clarity (FE should always send save_type)
- **Recommendation:** Frontend discipline (backend logic is safe)

### P2: node_update Not Implemented
- **Status:** Returns 501 (safe, no side effects)
- **Impact:** Feature incomplete (not a bug)
- **Recommendation:** Implement when needed

---

## Testing Checklist

- [x] Syntax check passed
- [x] Linter check passed
- [x] P1: Autosave payload error logging added
- [ ] Test: `graph_save_draft` forwards to `graph_save` correctly
- [ ] Test: Autosave with active draft does NOT overwrite draft
- [ ] Test: Manual save with active draft saves to draft table
- [ ] Test: Publish via `graph_save` returns 501 error
- [ ] Test: Published graph without draft cannot be saved (403)
- [ ] Test: Published graph with draft saves to draft (not main tables)
- [ ] Test: Autosave with invalid payload logs warning and tracks metric

---

## Related Documents

- `SAVE_SEMANTICS_REFACTOR.md` - Original refactor plan
- `P0_P1_FIXES_ENTERPRISE.md` - Previous fixes
- `PRODUCTION_READINESS_CHECKLIST.md` - Production readiness verification

