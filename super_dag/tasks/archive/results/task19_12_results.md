# Task 19.12 Results – ApplyFixEngine (AutoFix v3 Execution Layer)

**Status:** ✅ **COMPLETED**  
**Date:** December 19, 2025  
**Task:** [task19.12.md](task19.12.md)

---

## Summary

Task 19.12 successfully created `ApplyFixEngine.php` that can apply AutoFix operations to graph state in memory with atomic transaction support. The system can apply fixes selected by users, validate the graph after applying, and return the updated graph state to the UI for seamless integration.

---

## Changes Made

### 1. ApplyFixEngine.php (New File)

**Location:** `source/BGERP/Dag/ApplyFixEngine.php`

#### 1.1 Core Architecture
- **Class:** `ApplyFixEngine`
- **Purpose:** Apply AutoFix operations to graph state in memory
- **Key Features:**
  - Atomic transaction (all or nothing)
  - Safe: Validates operations before applying
  - Reversible: Can rollback on error
  - Deterministic: Same operations → same result

#### 1.2 Main Method: `apply()`
```php
public function apply(array $nodes, array $edges, array $operations, array $options = []): array
```

**Features:**
- Clones state before applying (for rollback)
- Validates each operation before applying
- Applies operations sequentially
- Rolls back on any exception
- Returns updated nodes/edges with applied count

**Return Structure:**
```php
[
    'nodes' => array,           // Updated nodes
    'edges' => array,           // Updated edges
    'applied_count' => int,     // Number of operations applied
    'errors' => array           // Non-fatal errors (if strict=false)
]
```

#### 1.3 Node Operations Supported

| Operation | Description | Safety Checks |
|-----------|-------------|---------------|
| `update_node_property` | Update any node property | Node must exist |
| `mark_as_sink` / `set_node_sink_flag` | Mark node as sink | Node must exist |
| `create_end_node` | Create new END node | Node code must not exist |
| `remove_node` | Remove node | Cannot remove START/END nodes |
| `set_node_metadata` | Set node metadata | Node must exist |
| `set_node_start_flag` / `set_node_end_flag` | Set START/END flag | Node must exist |
| `set_node_split_flag` / `set_node_merge_flag` | Set split/merge flag | Node must exist |
| `set_node_label` | Set node label (legacy) | Node must exist |
| `set_node_type` | Set node type (legacy) | Cannot change system node types |
| `set_node_position` | Set node position (legacy) | Node must exist |

#### 1.4 Edge Operations Supported

| Operation | Description | Safety Checks |
|-----------|-------------|---------------|
| `set_edge_as_else` / `set_edge_default_route` | Mark edge as default/else | Edge must exist |
| `create_edge` | Create new edge | Source/target nodes must exist, no duplicate edges |
| `remove_edge` | Remove edge | Edge must exist |
| `update_edge_condition` | Update edge condition | Edge must exist, condition required |
| `set_edge_condition_statuses` | Set QC condition statuses (legacy) | Edge must exist |

#### 1.5 Atomic Transaction Implementation

```php
// Clone state for rollback
$backupNodes = $this->deepClone($nodes);
$backupEdges = $this->deepClone($edges);

try {
    foreach ($operations as $op) {
        // Validate operation
        $validation = $this->validateOperation($op, $nodes, $edges, $nodeMap, $edgeMap);
        if (!$validation['valid']) {
            throw new \InvalidArgumentException('Operation validation failed');
        }
        
        // Apply operation
        $result = $this->applySingleOperation($op, $nodes, $edges, $nodeMap, $edgeMap);
        if (!$result['success']) {
            throw new \RuntimeException('Operation failed');
        }
        
        // Update state
        $nodes = $result['nodes'];
        $edges = $result['edges'];
    }
    
    // Final validation
    if ($validate) {
        $finalValidation = $this->validateGraphState($nodes, $edges);
        if (!$finalValidation['valid']) {
            throw new \RuntimeException('Final validation failed');
        }
    }
    
} catch (\Exception $e) {
    // Rollback on any exception
    $nodes = $backupNodes;
    $edges = $backupEdges;
    throw $e;
}
```

#### 1.6 Operation Validation

Each operation is validated before applying:
- **Node operations:** Check if node exists (by ID or code)
- **Edge operations:** Check if edge exists (by ID or code)
- **Create operations:** Check for duplicates
- **Remove operations:** Check for system nodes (START/END)
- **Graph state validation:** Check for orphan edges after applying

#### 1.7 Helper Methods

- `findNode()` - Find node by ID or code
- `findEdge()` - Find edge by ID or code
- `buildNodeMap()` - Build node lookup map
- `buildEdgeMap()` - Build edge lookup map
- `deepClone()` - Deep clone array for rollback
- `validateOperation()` - Validate operation before applying
- `validateGraphState()` - Validate graph state after applying

### 2. dag_routing_api.php

#### 2.1 New Action: `graph_apply_fixes`

**Endpoint:** `?action=graph_apply_fixes`

**Request Parameters:**
- `id` or `id_graph` (required): Graph ID
- `fix_ids` (required): Array of fix IDs to apply

**Flow:**
1. Load graph data
2. Run validation to get current state
3. Get fixes from AutoFixEngine
4. Filter fixes by selected IDs
5. Check apply_mode (reject disabled fixes)
6. Apply fixes using ApplyFixEngine
7. Revalidate after applying
8. Return updated graph + validation

**Response Structure:**
```json
{
  "ok": true,
  "graph": {
    "nodes": [...],
    "edges": [...]
  },
  "validation": {
    "valid": true,
    "error_count": 0,
    "warning_count": 0,
    "errors": [],
    "warnings": [],
    "errors_detail": [],
    "warnings_detail": [],
    "intents": []
  },
  "applied_count": 3,
  "apply_errors": []
}
```

**Error Response:**
```json
{
  "ok": false,
  "error": "Apply Fix failed: ...",
  "app_code": "DAG_ROUTING_500_APPLY_FIX_FAILED",
  "rollback": true
}
```

**Location:** Lines 4907-5030

#### 2.2 Safety Checks

- **Disabled Fixes:** Rejects fixes with `apply_mode = 'disabled'`
- **Invalid Fix IDs:** Validates that selected fixes exist
- **Atomic Transaction:** All operations applied or none (rollback on error)
- **Final Validation:** Validates graph state after applying

### 3. graph_designer.js

#### 3.1 Updated `applyFixes()` Function

**Changes:**
- **Before:** Applied fixes directly in frontend (non-atomic)
- **After:** Calls API to apply fixes (atomic transaction)

**New Flow:**
1. Extract fix IDs from selected fixes
2. Check for disabled fixes (reject if any)
3. Show loading indicator
4. Call `graph_apply_fixes` API
5. Replace graph state with updated state from API
6. Show validation results
7. Re-run validation to update UI

**Location:** Lines 7286-7430

#### 3.2 Graph State Replacement

After API returns updated graph:
1. Clear current graph (`cy.elements().remove()`)
2. Add updated nodes with all metadata
3. Add updated edges with conditions
4. Update graph state manager
5. Save state

#### 3.3 User Feedback

- **Loading:** Shows spinner while applying
- **Success:** Shows success message with applied count
- **Warnings:** Shows warnings if any
- **Errors:** Shows errors if validation fails
- **Rollback:** Shows rollback message if operation fails

---

## Operations Implementation Details

### Node Operations

#### `create_end_node`
- Creates new END node with specified code/name/position
- Checks for duplicate node codes
- Sets `is_end` flag in node_params

#### `remove_node`
- Removes node and all connected edges
- Safety: Cannot remove START/END nodes
- Only allowed for unreachable.unintentional nodes (risk ≤ 60)

#### `mark_as_sink`
- Sets `is_sink` flag in node_params
- Optionally sets `sink_type` (e.g., 'rework', 'scrap')

#### `set_node_metadata`
- Merges metadata into node_params
- Preserves existing metadata

### Edge Operations

#### `create_edge`
- Creates new edge between source and target nodes
- Checks for duplicate edges (same from/to)
- Supports all edge types (normal, conditional, rework)
- Includes edge condition if provided

#### `remove_edge`
- Removes edge from graph
- No safety checks (edges can be removed freely)

#### `update_edge_condition`
- Updates edge condition JSON
- Validates condition is provided

#### `set_edge_as_else`
- Sets `is_default` flag on edge
- Used for default/else routes

---

## Safety & Constraints

### 1. Atomic Transaction
- All operations applied or none
- Rollback on any exception
- Deep clone for backup

### 2. Operation Validation
- Validates operations before applying
- Checks for node/edge existence
- Checks for duplicates
- Validates graph state after applying

### 3. System Node Protection
- Cannot remove START/END nodes
- Cannot change system node types
- Cannot create duplicate system nodes

### 4. Apply Mode Enforcement
- Rejects fixes with `apply_mode = 'disabled'`
- Allows `apply_mode = 'auto'`, `'suggest'`, `'suggest_only'`
- Validates in API before applying

### 5. Graph State Validation
- Validates graph state after applying
- Checks for orphan edges
- Ensures all edge references are valid

---

## Testing

### Manual Testing
1. ✅ Apply single fix (metadata) → Success
2. ✅ Apply multiple fixes (batch) → Success
3. ✅ Apply structural fix (create_edge) → Success
4. ✅ Apply structural fix (create_node) → Success
5. ✅ Apply fix with disabled apply_mode → Rejected
6. ✅ Apply fix with invalid node reference → Rollback
7. ✅ Apply fix with duplicate edge → Rollback
8. ✅ Apply fix that creates orphan edge → Rollback
9. ✅ Apply fixes and revalidate → Validation updated
10. ✅ UI replaces graph state correctly → Graph updated
11. ✅ Rollback on error → State restored
12. ✅ Final validation failure → Rollback

### Edge Cases
- ✅ Empty fix_ids array → Error
- ✅ Invalid fix IDs → Error
- ✅ Missing graph ID → Error
- ✅ Network error → Error handling
- ✅ API timeout → Error handling

---

## Files Modified

1. **source/BGERP/Dag/ApplyFixEngine.php** (NEW)
   - Complete implementation of ApplyFixEngine class
   - All node and edge operations
   - Atomic transaction support
   - Operation validation

2. **source/dag_routing_api.php**
   - Added `graph_apply_fixes` action
   - Integrated ApplyFixEngine
   - Added safety checks (apply_mode, validation)

3. **assets/javascripts/dag/graph_designer.js**
   - Updated `applyFixes()` to call API
   - Added graph state replacement logic
   - Added user feedback (loading, success, errors)

---

## Acceptance Criteria

- [x] ApplyFixEngine.php สร้างตามสเปก
- [x] Apply ทั้ง graph ได้แบบ atomic
- [x] รองรับ operations ทั้งหมดครบ
- [x] API graph_apply_fixes ใช้งานได้จริง
- [x] UI สามารถ apply fix ได้ครบ workflow
- [x] Validate หลัง apply แล้ว error น้อยลงหรือหายไป
- [x] ไม่มี regression กับกราฟเก่า

---

## Known Limitations

1. **Frontend applyFixOperation():** The old `applyFixOperation()` function is still present in the codebase but is no longer used. It can be removed in a future cleanup task.

2. **Graph State Replacement:** Currently replaces entire graph state. Could be optimized to only update changed nodes/edges in future.

3. **Diff Preview:** Task mentions optional diff preview - not implemented yet (future enhancement).

4. **Batch Apply:** Currently applies all selected fixes in one transaction. Could add option to apply fixes individually with confirmation.

5. **Undo/Redo:** Graph state changes are not tracked in undo/redo system. Could be enhanced to support undo/redo for applied fixes.

---

## Benefits

1. **Atomic Transactions:** All fixes applied or none - no partial state
2. **Safety:** Validates operations before applying, prevents invalid states
3. **Reversibility:** Rollback on error ensures graph state is never corrupted
4. **Deterministic:** Same operations → same result every time
5. **Backend Validation:** Uses backend validation engine for consistency
6. **User Experience:** Clear feedback on success/failure, loading indicators

---

## Integration with AutoFix v3

ApplyFixEngine works seamlessly with AutoFixEngine v3:

1. **AutoFixEngine v3** suggests fixes with operations
2. **User selects** fixes in UI
3. **UI sends** fix IDs to API
4. **API loads** fixes from AutoFixEngine
5. **ApplyFixEngine** applies operations atomically
6. **GraphValidationEngine** revalidates graph
7. **UI updates** with new graph state

This creates a complete pipeline:
- **Detection** (GraphValidationEngine) →
- **Suggestion** (AutoFixEngine) →
- **Execution** (ApplyFixEngine) →
- **Verification** (GraphValidationEngine)

---

## Next Steps

Task 19.12 successfully created the ApplyFixEngine execution layer for AutoFix v3. The system now:

1. ✅ Can apply fixes atomically
2. ✅ Validates operations before applying
3. ✅ Rolls back on errors
4. ✅ Integrates with API and UI
5. ✅ Provides clear user feedback

**Future Enhancements:**
- Diff preview before applying
- Undo/redo support for applied fixes
- Incremental graph updates (only changed nodes/edges)
- Batch apply with individual confirmations

---

**Last Updated:** December 19, 2025

