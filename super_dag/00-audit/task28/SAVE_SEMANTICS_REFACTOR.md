# Task 28.x - Save Semantics Refactor
**Date:** 2025-12-13  
**Status:** 🔄 **IN PROGRESS**  
**Priority:** P0 (Critical)

---

## Executive Summary

Refactoring `graph_save` and `graph_save_draft` to unify semantics and fix critical issues:

1. **Unify save semantics** - Single `graph_save` endpoint with `save_type` parameter
2. **Draft save non-blocking** - Draft saves don't block on validation errors
3. **Separate node_update** - Node config saves don't trigger full graph validation
4. **Fix JSON decode** - Check errors separately for nodes/edges
5. **Shared normalizer** - Extract normalization to shared service

---

## Problems Identified

### 1. Publish Still "Saveable" (Semantic Confusion) ✅ FIXED

**Previous Behavior:**
- If graph is Published but has active draft → `graph_save` allows save
- But unclear: Does it save to draft table or published version?
- Risk: May touch `routing_graph`/`routing_node` directly instead of draft

**Fix:**
- Force route to draft service when `hasActiveDraft` AND manual structural save (not autosave/node_update)
- Explicit routing ensures saves go to `routing_graph_draft` table, not main tables
- Publish via `graph_save` is now blocked (must use dedicated publish workflow)

---

### 2. Two Endpoints, Confusing Semantics

**Current:**
- `graph_save` - Full save (strict validation)
- `graph_save_draft` - Draft save (warnings only)

**Problem:**
- Keyboard shortcuts may call wrong endpoint
- Frontend must know which to call
- Risk of calling `graph_save` when should call `graph_save_draft`

**Solution:**
- Unify to single `graph_save` with `save_type` parameter:
  - `save_type=draft` (Ctrl+S)
  - `save_type=publish` (Shift+Ctrl+S)
  - `save_type=autosave` (timer)
  - `save_type=node_update` (node config only)

---

### 3. JSON Decode Error Check (P0 Bug)

**Current:**
```php
$nodes = json_decode($nodesJson, true);
$edges = json_decode($edgesJson, true);
if (json_last_error() !== JSON_ERROR_NONE) { ... }
```

**Problem:**
- `json_last_error()` only reflects LAST decode
- If nodes fail but edges succeed → error not caught
- Causes downstream validation to fail mysteriously

**Fix:**
- Check error after EACH decode separately

---

### 4. Normalization Duplication

**Current:**
- `graph_save` has 200+ lines of normalization
- `graph_validate` may use different logic
- Risk: Validate passes but save fails (or vice versa)

**Fix:**
- Extract to `GraphPayloadNormalizer` service
- Both `graph_validate` and `graph_save` use same normalizer

---

### 5. Autosave Detection Incomplete

**Current:**
- Autosave = `save_type=autosave` OR no nodes/edges
- But "save node config" sends partial data → not detected as autosave
- Falls through to strict manual save → fails

**Fix:**
- Support `save_type=node_update`
- Validate only node fields, not full graph

---

### 6. Error Handling Parse Issues

**Current:**
```php
if (strpos($message, 'Graph validation failed') !== false) {
    $errorData = json_decode($message, true);
}
```

**Problem:**
- Exception message format: `"Graph validation failed: [{...},{...}]"`
- Not valid JSON → `json_decode` fails
- Falls back to string → FE gets wrong format

**Fix:**
- Use structured exceptions (`GraphValidationException`)
- Controller extracts errors directly, no string parsing

---

## Implementation Plan

### Task 1: Unify Save Semantics ✅

1. Modify `graph_save` to accept `save_type` parameter
2. Route based on `save_type`:
   - `draft` → `GraphDraftService::saveDraft()` (saves to routing_graph_draft table)
   - `publish` → **BLOCKED** (must use dedicated publish workflow/endpoint)
   - `autosave` → `GraphSaveEngine` (position updates only, NOT forced to draft)
   - `node_update` → **NOT YET IMPLEMENTED** (returns 501)
3. Make `graph_save_draft` an alias (forwards to `graph_save` with `save_type=draft` by setting POST parameter and falling through)

**CRITICAL FIX P0:** Force route to draft ONLY for manual structural saves, NOT for autosave/node_update. This prevents autosave from overwriting draft with empty nodes/edges.

---

### Task 2: Draft Save Non-Blocking ✅

1. Draft saves use `GraphDraftService::saveDraft()` (already non-blocking)
2. Validation errors become warnings
3. Return `validation_warnings` in response
4. Only publish requires strict validation

---

### Task 3: Separate node_update ✅

1. Add `save_type=node_update` support
2. Validate only node-specific fields
3. Don't trigger full graph validation
4. Prevents "resolve node IDs for edge" errors

---

### Task 4: Fix JSON Decode + Shared Normalizer ✅

1. Check `json_last_error()` after EACH decode
2. Extract normalization to `GraphPayloadNormalizer`
3. Use in both `graph_validate` and `graph_save`

---

## Files to Modify

- `source/dag/dag_graph_api.php` - Main refactor
- `source/dag/Graph/Service/GraphPayloadNormalizer.php` - NEW (extract normalization)
- `source/dag/Graph/Exception/GraphValidationException.php` - NEW (structured exceptions)

---

## Testing Checklist

- [ ] Draft save doesn't block on validation errors
- [ ] Publish requires strict validation
- [ ] Node config save doesn't trigger full graph validation
- [ ] JSON decode errors caught correctly
- [ ] Normalization consistent between validate and save
- [ ] Keyboard shortcuts work correctly
- [ ] Published graphs can't be saved (only draft)

---

## Related Documents

- `P0_P1_FIXES_ENTERPRISE.md` - Previous fixes
- `FRONTEND_P0_P1_FIXES.md` - Frontend fixes
- `AUDIT_EXECUTIVE_SUMMARY.md` - Original audit

