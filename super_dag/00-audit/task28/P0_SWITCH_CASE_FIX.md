# Task 28.x - P0 Critical Fix: Switch Case Fall-through Bug
**Date:** 2025-12-13  
**Status:** ✅ **FIXED**  
**Priority:** P0 (Critical)

---

## Executive Summary

Fixed critical bug where `graph_save_draft` alias was falling through to `graph_discard_draft` instead of `graph_save`, causing draft saves to discard drafts instead of saving them.

---

## 🚨 Critical Bug Identified

### Problem
**Location:** `dag_graph_api.php` switch statement

**Issue:**
- `graph_save_draft` case was placed **before** `graph_discard_draft` case
- It had no `break;` statement (intended fall-through)
- PHP switch fall-through goes to the **next** case, which was `graph_discard_draft`
- Result: Calling `graph_save_draft` would **discard the draft** instead of saving it!

**Original Code:**
```php
case 'graph_save_draft':
    $_POST['save_type'] = 'draft';
    // Fall through to graph_save case (no break) ❌ WRONG - falls through to discard!

case 'graph_discard_draft':
    // ... discard logic ...

case 'graph_save':
    // ... save logic ...
```

### Impact
- **Data Loss Risk:** Draft saves would discard drafts instead of saving them
- **User Confusion:** "Save Draft" button would delete the draft
- **Production Risk:** Critical bug that could cause data loss in production

---

## ✅ Fix Applied

### Solution
**Moved `graph_save_draft` case to be immediately before `graph_save` case:**

```php
case 'graph_discard_draft':
    // ... discard logic ...
    break;

case 'graph_save_draft':  // ✅ NOW PLACED BEFORE graph_save
    // P0 FIX: Alias for backward compatibility - forwards to graph_save with save_type=draft
    // CRITICAL: Must be placed BEFORE graph_save case to fall-through correctly
    // Previously this was after graph_discard_draft, causing it to discard drafts instead of saving!
    $_POST['save_type'] = 'draft';
    // Fall through to graph_save case (no break) ✅ NOW FALLS THROUGH CORRECTLY

case 'graph_save':
    // ... save logic ...
```

### Changes Made
1. **Moved case statement:** `graph_save_draft` is now immediately before `graph_save`
2. **Updated comment:** Added clear warning about placement requirement
3. **Verified fall-through:** Fall-through now goes to correct case (`graph_save`)

---

## 📝 Additional Fixes (P1)

### P1.1: Normalization Error Handling
**Added try-catch around normalization for better error messages:**

```php
try {
    $normalizer = new \BGERP\Dag\Graph\Service\GraphPayloadNormalizer();
    $normalized = $normalizer->normalize($nodes, $edges);
    $nodes = $normalized['nodes'];
    $edges = $normalized['edges'];
} catch (\Throwable $e) {
    error_log("[graph_save] Normalization failed for graph {$graphId}: " . $e->getMessage());
    json_error(translate('dag_routing.error.invalid_payload_shape', 'Invalid payload format'), 400, [
        'app_code' => 'DAG_ROUTING_400_INVALID_PAYLOAD_SHAPE',
        'errors' => ['Payload normalization failed: ' . $e->getMessage()]
    ]);
}
```

### P1.2: Autosave Normalization (if payload present)
**Added normalization for autosave when nodes/edges are sent:**

```php
// P1 FIX: Autosave may also send nodes/edges (not just positions)
// If autosave sends nodes/edges, normalize them for consistency
if ($isAutosave && !empty($nodes)) {
    try {
        $normalizer = new \BGERP\Dag\Graph\Service\GraphPayloadNormalizer();
        $normalized = $normalizer->normalize($nodes, $edges);
        $nodes = $normalized['nodes'];
        $edges = $normalized['edges'];
    } catch (\Throwable $e) {
        // For autosave, log but don't block (autosave is best-effort)
        error_log("[graph_save] Autosave normalization warning for graph {$graphId}: " . $e->getMessage());
        Metrics::increment('dag_routing.autosave.normalization_warning', [
            'graph_id' => (string)$graphId
        ]);
    }
}
```

### P1.3: Updated Comments
**Updated comments to match actual logic:**
- Clarified that autosave routes to draft when active draft exists
- Removed conflicting comments about "autosave remains autosave"

---

## Testing Checklist

After fix:
- [x] Syntax check passed
- [x] Linter check passed
- [ ] Test: `graph_save_draft` → saves to draft table (not discard)
- [ ] Test: `graph_discard_draft` → discards draft correctly
- [ ] Test: Normalization error → returns 400 with clear message
- [ ] Test: Autosave with nodes/edges → normalizes correctly

---

## Related Documents

- `AUDIT_FOLLOW_UP_RISKS.md` - Original audit findings
- `NORMALIZATION_REFACTOR_COMPLETE.md` - Normalization refactor
- `AUDIT_FOLLOW_UP_FIXES_COMPLETE.md` - Autosave routing fix

