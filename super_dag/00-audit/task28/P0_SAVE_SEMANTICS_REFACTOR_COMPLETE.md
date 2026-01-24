# Task 28.x - P0 Save Semantics Refactor Complete
**Date:** 2025-12-13  
**Status:** ✅ **COMPLETED**  
**Priority:** P0 (Critical)

---

## Executive Summary

Refactored DAG Graph save/draft/autosave routing to be deterministic and prevent critical bugs:
1. Created centralized `GraphSaveModeResolver` (single source of truth)
2. Prevented autosave from overwriting draft with empty payload
3. Removed If-Match requirement for draft saves
4. Eliminated duplicate routing logic

---

## 🎯 Objectives Achieved

### ✅ 1. Separated Routing Decision from Validation/Decode

**Problem:** Routing decisions were scattered throughout the code, causing state drift.

**Solution:** Created `GraphSaveModeResolver` that resolves save mode **EARLY** (before decode/validation):
- Single point of decision-making
- No duplicate routing logic
- Deterministic behavior

**Save Modes:**
- `draft`: Manual draft save (full payload)
- `autosave_draft`: Autosave when active draft exists (position-only merge)
- `autosave_main`: Autosave when no active draft (position updates to main tables)
- `publish`: Publish draft (blocked via graph_save endpoint)

### ✅ 2. Prevented Autosave from Overwriting Draft with Empty Payload

**Problem:** Autosave could send `nodes=[]`, `edges=[]` which would overwrite draft as empty graph.

**Solution:**
- Added `updateDraftPositions()` method in `GraphDraftService`
- Merges position updates with existing draft structure
- Skips autosave if no position updates provided
- Never overwrites draft with empty payload

**Code:**
```php
case 'autosave_draft':
    if ($nodesJson === null || $nodesJson === '') {
        // No position updates - skip (don't overwrite draft)
        json_success(['message' => 'Autosave skipped - no position updates']);
        break;
    }
    // Extract position updates and merge with existing draft
    $result = $draftService->updateDraftPositions($graphId, $positionUpdates, $userId);
```

### ✅ 3. Draft Save No Longer Requires If-Match

**Problem:** Draft saves were incorrectly requiring If-Match header (428 error).

**Solution:** `GraphSaveModeResolver` sets `requires_if_match: false` for draft modes:
- Draft saves: `requires_if_match = false`
- Autosave: `requires_if_match = false`
- Publish: `requires_if_match = true` (when implemented)

**Code:**
```php
// Resolver sets requires_if_match based on mode
if ($enforceIfMatch && $requiresIfMatch) {
    // Only enforce If-Match for publish (not draft/autosave)
}
```

### ✅ 4. Removed Duplicate Routing Logic

**Problem:** Routing logic appeared in multiple places:
- Line 702: `if ($hasActiveDraft && ($isDraft || $isAutosave || $isNodeUpdate))`
- Line 851: `if ($hasActiveDraft && ($isAutosave || $isNodeUpdate))`
- Line 720: `if ($enforceIfMatch && !$isAutosave)`

**Solution:** 
- **Single resolver call** at the beginning (line ~595)
- **Single switch case** using resolved mode (line ~700)
- **No duplicate routing logic** anywhere

---

## 📦 Files Changed

### New Files

1. **`source/dag/Graph/Service/GraphSaveModeResolver.php`**
   - Centralized resolver for save mode decisions
   - Returns: `mode`, `requires_if_match`, `allow_empty_payload`, `service_class`, `service_method`

### Modified Files

1. **`source/dag/dag_graph_api.php`**
   - Replaced all routing logic with resolver call
   - Removed duplicate routing checks
   - Updated If-Match enforcement to use resolved mode
   - Updated validation rules to use resolved mode

2. **`source/dag/Graph/Service/GraphDraftService.php`**
   - Added `updateDraftPositions()` method for position-only updates
   - Merges positions with existing draft structure
   - Never overwrites draft with empty payload

---

## 🧪 Test Cases

### Must Pass ✅

1. ✅ Autosave with active draft → No 428 error
2. ✅ Autosave position-only → Draft structure preserved
3. ✅ Manual save → Draft save passes (even with validation errors)
4. ✅ Autosave with no nodes/edges → Skips (doesn't overwrite draft)
5. ✅ Draft save → No If-Match required

### Must Fail ✅

1. ✅ Publish via graph_save → Blocked (501)
2. ✅ Save published graph without draft → Blocked (403)
3. ✅ Autosave empty payload → Skips (doesn't overwrite)

---

## 🔍 Code Quality

- **No duplicate routing logic** ✅
- **Deterministic behavior** ✅
- **Clear separation of concerns** ✅
- **Single source of truth** ✅
- **Comments explain save semantics** ✅

---

## 📝 Save Semantics (Documented in Code)

**Draft Save:**
- Full payload required (nodes + edges)
- Validation errors become warnings (non-blocking)
- No If-Match required
- Saves to `routing_graph_draft` table

**Autosave (with active draft):**
- Position updates only
- Merges with existing draft structure
- No If-Match required
- Skips if no position updates provided

**Autosave (no active draft):**
- Position updates only
- Updates main tables (`routing_node`)
- No If-Match required
- Best-effort (doesn't block on errors)

**Publish:**
- Blocked via graph_save endpoint (must use dedicated publish workflow)
- Requires If-Match (when implemented)
- Strict validation

---

## Related Documents

- `AUDIT_FOLLOW_UP_RISKS.md` - Original audit findings
- `NORMALIZATION_REFACTOR_COMPLETE.md` - Normalization refactor
- `CRITICAL_NORMALIZER_FIX.md` - Normalizer ID inference fix

