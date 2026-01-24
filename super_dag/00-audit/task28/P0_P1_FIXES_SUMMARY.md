# Task 28.x - P0/P1 Fixes Summary
**Date:** 2025-12-13  
**Status:** ✅ **ALL FIXES APPLIED**  
**Priority:** P0 (Critical) + P1 (High)

---

## Executive Summary

Applied all critical fixes identified in external AI audit:
1. **P0: Switch case fall-through bug** - Fixed
2. **P1: Normalization error handling** - Added
3. **P1: Autosave normalization** - Added
4. **P1: Comments updated** - Updated

---

## ✅ P0 Fix: Switch Case Fall-through Bug

### Problem
`graph_save_draft` case was placed before `graph_discard_draft`, causing it to fall-through to the wrong case (discard instead of save).

### Solution
**Moved `graph_save_draft` case to be immediately before `graph_save`:**

```php
case 'graph_discard_draft':
    // ... discard logic ...
    break;

case 'graph_save_draft':  // ✅ NOW BEFORE graph_save
    $_POST['save_type'] = 'draft';
    // Fall through to graph_save (no break)

case 'graph_save':
    // ... save logic ...
```

**Status:** ✅ **FIXED** - Lines 545-553

---

## ✅ P1 Fix: Normalization Error Handling

### Problem
If `GraphPayloadNormalizer::normalize()` throws an exception, the error message would be unclear.

### Solution
**Added try-catch around normalization:**

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

**Status:** ✅ **ADDED** - Lines 816-827

---

## ✅ P1 Fix: Autosave Normalization

### Problem
If autosave sends nodes/edges (not just positions), they are not normalized, potentially causing shape mismatches.

### Solution
**Added normalization for autosave when nodes/edges are present:**

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

**Status:** ✅ **ADDED** - Lines 830-844

---

## ✅ P1 Fix: Comments Updated

### Changes
- Updated routing logic comments to reflect actual behavior
- Clarified that autosave routes to draft when active draft exists
- Added warning comments about case placement requirement

**Status:** ✅ **UPDATED**

---

## Testing Checklist

- [x] Syntax check passed
- [x] Linter check passed
- [x] Case order verified: `graph_discard_draft` → `graph_save_draft` → `graph_save`
- [ ] Test: `graph_save_draft` → saves to draft table (not discard)
- [ ] Test: `graph_discard_draft` → discards draft correctly
- [ ] Test: Normalization error → returns 400 with clear message
- [ ] Test: Autosave with nodes/edges → normalizes correctly

---

## Related Documents

- `P0_SWITCH_CASE_FIX.md` - Detailed P0 fix documentation
- `AUDIT_FOLLOW_UP_RISKS.md` - Original audit findings
- `NORMALIZATION_REFACTOR_COMPLETE.md` - Normalization refactor

