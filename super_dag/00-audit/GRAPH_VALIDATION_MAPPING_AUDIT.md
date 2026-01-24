# Graph Validation Mapping Audit
**Date**: 2025-12-12  
**Issue**: Validation errors showing incorrect results

## Problem Summary

Validation returns:
1. `EDGE_DANGLING_FROM`: Edge has invalid source node
2. `UNREACHABLE_NODE`: START1 and END1 are unreachable from START (incorrect!)

## Root Cause Analysis

### 1. EDGE_DANGLING_FROM Error

**Location**: `GraphValidationEngine::validateEdgeIntegrity()` (line 520-542)

**Logic**:
```php
$fromId = TempIdHelper::getValidationId($edge, 'from_node_id', 'from_node_code', $nodeMap);
if ($fromId === null) {
    // EDGE_DANGLING_FROM error
}
```

**Issue**: 
- `TempIdHelper::getValidationId()` looks for `from_node_id` or `from_node_code` in edge
- If both are missing or cannot be resolved via `nodeMap`, returns `null`
- **Expected**: `source` field should be mapped to `from_node_code` before validation

### 2. UNREACHABLE_NODE Error (START1 and END1)

**Location**: `ReachabilityAnalyzer::buildReachabilityMap()` (line 157-182)

**Logic**:
1. Uses `GraphHelper::buildEdgeMap()` to build adjacency list
2. `buildEdgeMap()` calls `TempIdHelper::getValidationId($edge, 'from_node_id', 'from_node_code', $nodeMap)` 
3. If edges don't have `from_node_code`, `edgeMap` is empty
4. BFS from START finds no outgoing edges → all nodes unreachable (including START itself!)

**Issue**:
- If `from_node_code` mapping fails, `edgeMap[$startNodeId]` is empty array
- BFS never traverses → all nodes marked unreachable
- **Expected**: `source`/`target` should be mapped to `from_node_code`/`to_node_code`

## Data Flow Analysis

### Current Flow:
1. **Frontend** sends: `{source: "n_new_xxx", target: "n_new_yyy"}` (Cytoscape IDs)
2. **dag_routing_api.php** (lines 1703-1814):
   - Maps `source` -> `from_node_code` using `$cyIdToNodeCode` mapping
   - Should set `from_node_code` in normalized edge
3. **GraphValidationEngine**:
   - Uses `TempIdHelper::getValidationId($edge, 'from_node_id', 'from_node_code', $nodeMap)`
   - If `from_node_code` is missing → validation fails

### Potential Issues:

1. **Mapping Failure**: 
   - `source` value doesn't match any key in `$cyIdToNodeCode`
   - Type mismatch (string vs int)
   - Missing `node_code` in source node

2. **Normalization Failure**:
   - `from_node_code` not set in normalized edge array
   - Field overwritten later in code

3. **NodeMap Issue**:
   - `nodeMap` doesn't have correct mappings
   - `GraphHelper::buildNodeMap()` doesn't include all node IDs

## Debug Checklist

When validation fails, check:

1. **Raw Data** (from logs):
   ```json
   {
     "nodes": [{"id": "n_new_xxx", "node_code": "START1", ...}],
     "edges": [{"source": "n_new_xxx", "target": "n_new_yyy", ...}]
   }
   ```

2. **Node Mapping** (should log):
   ```
   [graph_validate] Node mapping: {"n_new_xxx": "START1", ...}
   ```

3. **Edge Resolution** (should log):
   ```
   [graph_validate] Edge[0] resolution: source=n_new_xxx -> from_node_code=START1
   ```

4. **Normalized Edges** (should have `from_node_code`):
   ```json
   {
     "from_node_code": "START1",
     "to_node_code": "END1"
   }
   ```

5. **NodeMap Structure** (passed to validation):
   - Should have: `{"START1": id, id: node, ...}`
   - Check if `GraphHelper::buildNodeMap()` includes all nodes

## Verification Steps

1. ✅ Check if `from_node_code`/`to_node_code` are set in normalized edges
2. ✅ Verify `nodeMap` has correct code => id mappings
3. ✅ Confirm `TempIdHelper::getValidationId()` can resolve codes
4. ✅ Ensure `buildEdgeMap()` creates correct adjacency list

## Conclusion

**If mapping works correctly**:
- Errors are **real** (graph structure is invalid)
- Edges are not properly connected in UI

**If mapping fails**:
- Errors are **false positives** (validation bug)
- Need to fix `source` -> `from_node_code` mapping in `dag_routing_api.php`

## Next Steps

1. Add comprehensive debug logging to trace data flow
2. Verify normalized edge structure before validation
3. Test with known-good graph structure
4. Compare normalized data with validation engine expectations
