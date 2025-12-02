# Badge (Step) Sequence Number Fix

## Problem
In the Products page, under Node Details in the Product Graph Binding modal, the Badge (Step) was always displaying "Step 0" for all nodes instead of showing proper sequence numbers (1, 2, 3, ...).

## Root Cause
All `routing_node` records in the database had `sequence_no = 0`. This occurred because:
1. The `sequence_no` field was NOT included in the INSERT/UPDATE statements when creating or updating nodes in `dag_routing_api.php`
2. There was no logic to calculate and assign proper sequence numbers based on graph topology

## Solution Implemented

### 1. Fixed Existing Data
Created and executed `/tools/fix_routing_node_sequence_no.php` to:
- Calculate proper sequence numbers for all existing routing nodes
- Use topological sort (Kahn's algorithm) to determine node order
- Handle disconnected nodes gracefully
- Update 58 nodes across 19 graphs

Results:
```
Graph ID 7 (Belt - OEM):
  Seq: 1 | START    (start)
  Seq: 2 | CUT      (operation)
  Seq: 3 | SEW      (operation)
  Seq: 4 | QC       (decision)
  Seq: 5 | END      (end)
```

### 2. Added Automatic Recalculation
Modified `/source/dag_routing_api.php` to:
- Added `recalculateNodeSequence()` function that:
  - Performs topological sort on graph nodes
  - Assigns sequence numbers based on dependency order
  - Handles cycles and disconnected nodes
- Integrated into `graph_save` action to automatically recalculate sequence numbers after each save (non-autosave only)
- Added error handling to not fail saves if recalculation fails

### 3. Algorithm Details
**Topological Sort (Kahn's Algorithm)**:
1. Build adjacency list and in-degree map from edges
2. Start with nodes that have in-degree = 0 (typically START nodes)
3. Process nodes level by level (same distance from start)
4. Assign same sequence number to nodes at same level
5. Increment sequence for next level
6. Handle disconnected nodes by assigning sequential numbers

**Example Graph**:
```
START (Seq: 1)
  ↓
SPLIT (Seq: 2)
  ├→ OP1 (Seq: 3)
  └→ OP2 (Seq: 3)  [parallel nodes get same seq]
       ↓  ↓
      JOIN (Seq: 4)
        ↓
       END (Seq: 5)
```

## Files Changed
1. `/tools/fix_routing_node_sequence_no.php` - **NEW**: One-time fix script
2. `/source/dag_routing_api.php` - **MODIFIED**: 
   - Added `recalculateNodeSequence()` function
   - Integrated into `graph_save` action

## Testing
Verified the fix:
```bash
php tools/fix_routing_node_sequence_no.php
# Output: SUCCESS: Updated 58 nodes across 19 graphs.
```

Checked sample graph:
```sql
SELECT node_code, sequence_no, node_type 
FROM routing_node 
WHERE id_graph = 7 
ORDER BY sequence_no;

-- Results:
-- START:     Seq 1
-- CUT:       Seq 2
-- SEW:       Seq 3
-- QC:        Seq 4
-- END:       Seq 5
```

## Impact
✅ **Products Page**: Badge (Step) now shows correct sequence numbers (Step 1, Step 2, etc.)
✅ **Future Saves**: Sequence numbers automatically recalculated on each graph save
✅ **Existing Data**: All 58 nodes in 19 graphs now have proper sequence numbers
✅ **User Experience**: Node details are now properly ordered and numbered

## Future Considerations
1. **Performance**: For very large graphs (>100 nodes), consider caching sequence calculations
2. **UI Feedback**: Could add visual indicators for nodes at the same sequence level (parallel operations)
3. **Validation**: Could add validation to ensure sequence numbers are unique per level
4. **Graph Designer**: Update graph designer UI to show sequence numbers on nodes

## Maintenance
- The fix script can be re-run safely if needed (idempotent)
- Sequence recalculation is automatic on graph save
- No manual intervention required for new graphs

---

**Date**: 2025-11-13  
**Author**: Development Team  
**Status**: ✅ Completed and Tested
