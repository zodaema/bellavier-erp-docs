# Task 19.13 Results — SuperDAG Legacy Cleanup & Deprecation Guardrails

**Status:** ✅ COMPLETED  
**Date:** 2025-11-24  
**Category:** SuperDAG / Housekeeping / Safety

---

## Executive Summary

Task 19.13 successfully cleaned up legacy features in SuperDAG, blocking creation/update of deprecated node types (`split`, `join`, `wait`, `decision`) while maintaining backward compatibility for existing graphs. All legacy features are now marked as read-only, with clear deprecation warnings and documentation.

**Key Achievement:** Single source of truth established for node types, edge semantics, parallel/merge semantics, and validation pipeline.

---

## 1. Legacy Features Deprecated

### 1.1 Node Types Blocked

The following legacy node types are now **blocked from creation/update**:

- ✅ `split` — Use `is_parallel_split` flag on operation nodes instead
- ✅ `join` — Use `is_merge_node` flag on operation nodes instead
- ✅ `wait` — Deprecated (read-only support)
- ✅ `decision` — Use conditional edges instead

### 1.2 Deprecation Levels

Each legacy feature follows a 3-level deprecation strategy:

1. **Blocked in UI** — Toolbar buttons commented out, `addNode()` guards prevent creation
2. **Soft-Deprecated in API** — `node_create` and `node_update` reject legacy types with clear error messages
3. **Runtime Tolerant** — Execution engine (`DAGRoutingService`) still handles legacy nodes for backward compatibility

---

## 2. Frontend Changes (graph_designer.js)

### 2.1 Toolbar Cleanup

**File:** `views/routing_graph_designer_toolbar_v2.php`

- ✅ Split node button: Commented out (line 47-51)
- ✅ Join node button: Commented out (line 53-57)
- ✅ Decision node button: Commented out (line 60-64)
- ✅ Wait node button: Commented out (line 72-76)

**Result:** Users cannot create legacy node types from toolbar.

### 2.2 Node Creation Guards

**File:** `assets/javascripts/dag/graph_designer.js`

**Location:** `addNode()` function (line 4190)

```javascript
// Task 19.13: Block legacy node types (deprecated)
const nodeTypeLower = nodeType.toLowerCase();
const legacyNodeTypes = ['decision', 'split', 'join', 'wait'];
if (legacyNodeTypes.includes(nodeTypeLower)) {
    const legacyTypeName = nodeTypeLower.charAt(0).toUpperCase() + nodeTypeLower.slice(1);
    notifyError(
        t('routing.legacy_node_type.deprecated', '{type} node type is deprecated and cannot be created. Use modern alternatives instead.', { type: legacyTypeName }),
        t('routing.validation_error', 'Validation Error')
    );
    return;
}
```

**Result:** All UI paths to create legacy nodes are blocked.

### 2.3 Properties Panel Updates

**File:** `assets/javascripts/dag/graph_designer.js`

**Changes:**

1. **Split Node UI** (line 4955-4974):
   - Added deprecation warning banner
   - All fields marked as read-only
   - Save blocked (returns early with warning)

2. **Join Node UI** (line 4976-4996):
   - Added deprecation warning banner
   - All fields marked as read-only
   - Save blocked (returns early with warning)

3. **Decision Node UI** (line 5009-5014):
   - Added deprecation warning banner
   - Form schema marked as read-only
   - Save blocked (returns early with warning)

4. **Wait Node UI** (line 5116-5134):
   - Added deprecation warning banner
   - All fields marked as read-only
   - Save blocked (returns early with warning)

**Result:** Legacy nodes can be viewed but not edited.

---

## 3. Backend Changes (dag_routing_api.php)

### 3.1 Node Creation Validation

**Action:** `node_create` (line 5881-5894)

```php
// Task 19.13: Reject legacy node types (split, join, wait, decision)
$nodeType = $_POST['node_type'] ?? 'operation';
$legacyNodeTypes = ['split', 'join', 'wait', 'decision'];
if (in_array($nodeType, $legacyNodeTypes, true)) {
    json_error(translate('dag_routing.error.legacy_node_type', ...), 400, [
        'app_code' => 'DAG_ROUTING_400_LEGACY_NODE_TYPE',
        'error' => [
            'code' => 'DAG_ROUTING_400_LEGACY_NODE_TYPE',
            'message' => ...,
            'legacy_types' => $legacyNodeTypes,
            'hint' => 'Use is_parallel_split=1 for parallel branches, or is_merge_node=1 for merge nodes. Use conditional edges instead of decision nodes.'
        ]
    ]);
}
```

**Result:** API rejects legacy node creation with clear error code and hint.

### 3.2 Node Update Validation

**Action:** `node_update` (line 6226-6243)

**Changes:**

1. Check existing node type (if updating existing node)
2. Check new node type (if changing node type)
3. Both paths reject legacy types with clear error messages

**Result:** Legacy nodes cannot be updated or converted to legacy types.

### 3.3 Legacy Validation Logic

**File:** `source/dag_routing_api.php`

**Changes:**

1. **Split Node Validation** (line 1254-1283):
   - Changed from `$errors[]` to `$warnings[]`
   - Added `@deprecated` comment
   - Marked as "LEGACY SUPPORT ONLY"

2. **Join Node Validation** (line 1285-1320):
   - Changed from `$errors[]` to `$warnings[]`
   - Added `@deprecated` comment
   - Marked as "LEGACY SUPPORT ONLY"

3. **Decision Node Validation** (line 1020-1044):
   - Added `@deprecated` comment
   - Marked as "LEGACY SUPPORT ONLY"

**Result:** Legacy validation still runs but generates warnings instead of errors, allowing old graphs to load.

---

## 4. Service Layer Changes (DAGRoutingService.php)

### 4.1 Runtime Handler Deprecation

**File:** `source/BGERP/Service/DAGRoutingService.php`

**Changes:**

1. **`handleSplitNode()`** (line 1223-1233):
   - Added `@deprecated` PHPDoc comment
   - Marked as "backward compatibility only"

2. **`handleJoinNode()`** (line 1406-1415):
   - Added `@deprecated` PHPDoc comment
   - Marked as "backward compatibility only"

3. **`handleWaitNode()`** (line 1618-1621):
   - Added `@deprecated` PHPDoc comment
   - Marked as "backward compatibility only"

4. **`handleDecisionNode()`** (line 1896-1905):
   - Added `@deprecated` PHPDoc comment
   - Marked as "backward compatibility only"

5. **Route Token Logic** (line 301-314):
   - Added `@deprecated` comments for each legacy handler call
   - Added inline comments explaining modern alternatives

**Result:** Runtime handlers still work for legacy graphs but are clearly marked as deprecated.

---

## 5. Backward Compatibility

### 5.1 Read-Only Support

All legacy features maintain **read-only support**:

- ✅ Legacy graphs can be loaded from database
- ✅ Legacy nodes are displayed in UI (with deprecation warnings)
- ✅ Legacy nodes are validated (warnings, not errors)
- ✅ Legacy nodes execute correctly in runtime (via deprecated handlers)

### 5.2 Migration Path

**Modern Alternatives:**

| Legacy Type | Modern Alternative |
|------------|---------------------|
| `split` node | `is_parallel_split=1` flag on operation node |
| `join` node | `is_merge_node=1` flag on operation node |
| `wait` node | (No direct replacement — consider removing) |
| `decision` node | Conditional edges with `ConditionEvaluator` |

---

## 6. Validation Changes

### 6.1 Error → Warning Conversion

Legacy validation errors are now **warnings** instead of errors:

- Split node validation: `$errors[]` → `$warnings[]`
- Join node validation: `$errors[]` → `$warnings[]`

**Rationale:** Old graphs should still load and validate (with warnings), but new graphs cannot create legacy types.

### 6.2 GraphValidationEngine v3

**Status:** ✅ Compatible

`GraphValidationEngine` v3 (Task 19.11) works correctly with legacy graphs:

- Detects legacy nodes
- Generates semantic warnings (not errors)
- AutoFix engine does not suggest fixes for legacy nodes (they are read-only)

---

## 7. Testing & Validation

### 7.1 Manual Smoke Tests

**Test Cases:**

1. ✅ **New Graph (No Legacy Types)**
   - Create new graph → Cannot create split/join/wait/decision nodes
   - Toolbar buttons are hidden
   - API rejects legacy node creation

2. ✅ **Old Graph (With Legacy Types)**
   - Load old graph with split/join/wait/decision nodes
   - Nodes display correctly (with deprecation warnings)
   - Properties panel shows read-only fields
   - Cannot update legacy nodes (blocked in UI and API)
   - Validation generates warnings (not errors)

3. ✅ **Conditional Edge (Legacy Format)**
   - Legacy conditional edges load correctly
   - Displayed in new Conditional Edge Editor (read-only)
   - No errors during load

### 7.2 API Validation

**Test Results:**

- ✅ `node_create` with `node_type=split` → Rejected (400 error)
- ✅ `node_create` with `node_type=join` → Rejected (400 error)
- ✅ `node_create` with `node_type=wait` → Rejected (400 error)
- ✅ `node_create` with `node_type=decision` → Rejected (400 error)
- ✅ `node_update` on existing split node → Rejected (400 error)
- ✅ `graph_validate` on graph with legacy nodes → Warnings (not errors)

---

## 8. Documentation Updates

### 8.1 Code Comments

**Added `@deprecated` Comments:**

- ✅ `DAGRoutingService::handleSplitNode()`
- ✅ `DAGRoutingService::handleJoinNode()`
- ✅ `DAGRoutingService::handleWaitNode()`
- ✅ `DAGRoutingService::handleDecisionNode()`
- ✅ Legacy validation logic in `dag_routing_api.php`
- ✅ Legacy UI sections in `graph_designer.js`

### 8.2 Inline Documentation

**Added Inline Comments:**

- ✅ "LEGACY SUPPORT ONLY" markers
- ✅ "Task 19.13" references
- ✅ Modern alternative hints in error messages

---

## 9. Files Modified

### 9.1 Frontend

- ✅ `assets/javascripts/dag/graph_designer.js` — Guards, UI updates, read-only fields
- ✅ `views/routing_graph_designer_toolbar_v2.php` — Toolbar buttons commented

### 9.2 Backend

- ✅ `source/dag_routing_api.php` — Validation, error handling, deprecation comments
- ✅ `source/BGERP/Service/DAGRoutingService.php` — Handler deprecation comments

---

## 10. Acceptance Criteria

- [x] Toolbar และ keyboard shortcuts ไม่มีปุ่ม/ทางลัดสำหรับ split/join/wait/decision node อีกต่อไป
- [x] GraphDesigner JS ไม่สามารถสร้าง node_type legacy ได้ผ่านทุก UI path
- [x] dag_routing_api ปฏิเสธการสร้าง/แก้ไข node_type legacy ด้วย error code ที่ชัดเจน
- [x] GraphValidationEngine v3 ทำงานได้ทั้งกับกราฟใหม่และกราฟเก่า (legacy-friendly)
- [x] No new code พึ่งพา legacy flags/types อีกต่อไป (split/join/wait/decision)
- [x] AutoFix + ApplyFixEngine ทำงานได้ปกติหลัง cleanup
- [x] เอกสาร task19_13_results.md สรุปรายการ legacy ที่ถูกปิดอย่างครบถ้วน

---

## 11. Known Limitations

### 11.1 Database Schema

**Not Changed:**

- Legacy columns (`split_policy`, `join_type`, `join_quorum`, `wait_window_minutes`) remain in database
- No migration to remove legacy columns (out of scope for Task 19.13)

**Rationale:** Removing columns would break existing graphs. Migration can be done in future task if needed.

### 11.2 Legacy Graph Execution

**Status:** ✅ Fully Supported

Legacy graphs execute correctly:

- Split nodes spawn tokens correctly
- Join nodes merge tokens correctly
- Wait nodes delay tokens correctly
- Decision nodes route tokens correctly

**Rationale:** Backward compatibility is critical for production systems.

---

## 12. Next Steps

### 12.1 Phase 20 Preparation

Task 19.13 prepares SuperDAG for Phase 20 (Time / ETA / Simulation):

- ✅ Clean codebase (no legacy feature confusion)
- ✅ Single source of truth established
- ✅ Clear deprecation path documented

### 12.2 Future Tasks

**Potential Follow-ups:**

1. **Database Migration** (if needed):
   - Remove legacy columns after all graphs migrated
   - Archive legacy graphs to separate table

2. **Legacy Graph Migration Tool**:
   - Auto-convert split nodes → `is_parallel_split` flags
   - Auto-convert join nodes → `is_merge_node` flags
   - Auto-convert decision nodes → conditional edges

---

## 13. Summary

Task 19.13 successfully cleaned up legacy features in SuperDAG while maintaining full backward compatibility. All legacy node types (`split`, `join`, `wait`, `decision`) are now:

- ✅ Blocked from creation/update (UI + API)
- ✅ Marked as deprecated (code comments + documentation)
- ✅ Supported in runtime (for existing graphs)
- ✅ Validated with warnings (not errors)

**Result:** SuperDAG now has a single source of truth for node types, edge semantics, parallel/merge semantics, and validation pipeline, ready for Phase 20.

---

**Task Status:** ✅ COMPLETED  
**Date Completed:** 2025-11-24  
**Next Task:** Phase 20 (Time / ETA / Simulation)

