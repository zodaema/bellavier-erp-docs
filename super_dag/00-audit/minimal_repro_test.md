# Minimal Repro Tests for Validation Audit

## Test A: Simple START->END (Should Pass)

**Purpose**: Verify basic validation works correctly.

**Expected**: `valid: true`, `error_count: 0`

**Test Data**:
```json
{
  "action": "graph_validate",
  "graph_id": 153,
  "nodes": "[{\"id\":\"n_test_start\",\"node_code\":\"START\",\"node_type\":\"start\"},{\"id\":\"n_test_end\",\"node_code\":\"END\",\"node_type\":\"end\"}]",
  "edges": "[{\"id\":\"e_test_1\",\"source\":\"n_test_start\",\"target\":\"n_test_end\"}]"
}
```

**How to Test**:
1. Open browser console in Graph Designer
2. Run:
```javascript
// Temporarily replace graph with minimal test
const testNodes = [
  {id: 'n_test_start', node_code: 'START', node_type: 'start'},
  {id: 'n_test_end', node_code: 'END', node_type: 'end'}
];
const testEdges = [
  {id: 'e_test_1', source: 'n_test_start', target: 'n_test_end'}
];

// Use existing validation function
if (typeof graphValidator !== 'undefined' && graphValidator.validateGraph) {
  graphValidator.validateGraph(currentGraphId, 'source/dag_routing_api.php', {
    nodes: testNodes,
    edges: testEdges
  }).then(result => {
    console.log('Test A Result:', result);
    if (result.validation && result.validation.valid) {
      console.log('✅ Test A PASSED');
    } else {
      console.error('❌ Test A FAILED - Expected valid=true');
      console.error('Errors:', result.validation?.errors);
    }
  });
}
```

**Success Criteria**:
- ✅ No `EDGE_DANGLING_FROM` errors
- ✅ No `UNREACHABLE_NODE` errors
- ✅ `valid: true`

**If Fails**:
- → **SYSTEM_VALIDATION_BUG** (ระบบ validate ผิดแน่นอน)
- Check logs for `[AUDIT-*]` tags to identify failure point

---

## Test B: START->END with Orphan Nodes (Should Fail Correctly)

**Purpose**: Verify validation correctly identifies unreachable nodes.

**Expected**: `valid: false`, `unreachable_nodes: ["START1", "END1"]`, NO `EDGE_DANGLING_FROM`

**Test Data**:
```json
{
  "action": "graph_validate",
  "graph_id": 153,
  "nodes": "[{\"id\":\"n_start\",\"node_code\":\"START\",\"node_type\":\"start\"},{\"id\":\"n_end\",\"node_code\":\"END\",\"node_type\":\"end\"},{\"id\":\"n_start1\",\"node_code\":\"START1\",\"node_type\":\"start\"},{\"id\":\"n_end1\",\"node_code\":\"END1\",\"node_type\":\"end\"}]",
  "edges": "[{\"id\":\"e1\",\"source\":\"n_start\",\"target\":\"n_end\"}]"
}
```

**How to Test**:
```javascript
const testNodes = [
  {id: 'n_start', node_code: 'START', node_type: 'start'},
  {id: 'n_end', node_code: 'END', node_type: 'end'},
  {id: 'n_start1', node_code: 'START1', node_type: 'start'},
  {id: 'n_end1', node_code: 'END1', node_type: 'end'}
];
const testEdges = [
  {id: 'e1', source: 'n_start', target: 'n_end'}
];

if (typeof graphValidator !== 'undefined' && graphValidator.validateGraph) {
  graphValidator.validateGraph(currentGraphId, 'source/dag_routing_api.php', {
    nodes: testNodes,
    edges: testEdges
  }).then(result => {
    console.log('Test B Result:', result);
    
    const validation = result.validation || {};
    const hasDanglingError = (validation.errors || []).some(e => 
      typeof e === 'string' ? e.includes('invalid source node') : 
      (e.code === 'EDGE_DANGLING_FROM' || e.message?.includes('invalid source'))
    );
    
    const unreachableStart1 = (validation.errors || []).some(e => 
      typeof e === 'string' ? e.includes('START1') && e.includes('unreachable') :
      (e.message?.includes('START1') && e.code === 'UNREACHABLE_NODE')
    );
    
    const unreachableEnd1 = (validation.errors || []).some(e => 
      typeof e === 'string' ? e.includes('END1') && e.includes('unreachable') :
      (e.message?.includes('END1') && e.code === 'UNREACHABLE_NODE')
    );
    
    if (hasDanglingError) {
      console.error('❌ Test B FAILED - Got EDGE_DANGLING_FROM (should not happen)');
      console.error('→ SYSTEM_MAPPING_BUG: Edge mapping failed');
    } else if (!unreachableStart1 || !unreachableEnd1) {
      console.error('❌ Test B FAILED - Missing UNREACHABLE_NODE for START1/END1');
      console.error('→ SYSTEM_VALIDATION_BUG: Reachability check failed');
    } else {
      console.log('✅ Test B PASSED - Correctly identified unreachable nodes');
    }
  });
}
```

**Success Criteria**:
- ✅ `EDGE_DANGLING_FROM`: **NO** (should not appear)
- ✅ `UNREACHABLE_NODE` for START1: **YES**
- ✅ `UNREACHABLE_NODE` for END1: **YES**
- ✅ `valid: false` (expected, since there are errors)

**If Shows EDGE_DANGLING_FROM**:
- → **SYSTEM_MAPPING_BUG** (edge mapping failed)
- Check `[AUDIT-B]` and `[AUDIT-C]` logs

**If Missing UNREACHABLE_NODE**:
- → **SYSTEM_VALIDATION_BUG** (reachability check failed)
- Check `[AUDIT-D]` logs for EdgeMap structure

---

## Test C: Edge with Missing Source Node (Should Show EDGE_DANGLING_FROM)

**Purpose**: Verify validation correctly identifies dangling edges.

**Expected**: `EDGE_DANGLING_FROM` error

**Test Data**:
```javascript
const testNodes = [
  {id: 'n_start', node_code: 'START', node_type: 'start'},
  {id: 'n_end', node_code: 'END', node_type: 'end'}
];
const testEdges = [
  {id: 'e1', source: 'n_start', target: 'n_end'},
  {id: 'e2', source: 'n_missing', target: 'n_end'}  // Missing source node
];
```

**Success Criteria**:
- ✅ `EDGE_DANGLING_FROM` for edge with missing source: **YES**
- ✅ Error message includes edge ID

**If Missing EDGE_DANGLING_FROM**:
- → **SYSTEM_VALIDATION_BUG** (edge integrity check failed)

---

## How to Run Tests

### Option 1: Browser Console (Recommended)

1. Open Graph Designer page
2. Open browser DevTools (F12)
3. Go to Console tab
4. Copy-paste test code above
5. Check console output and PHP error logs

### Option 2: Direct API Call

```bash
# Test A
curl -X POST "http://localhost/source/dag_routing_api.php" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "action=graph_validate&graph_id=153&nodes=[{\"id\":\"n_test_start\",\"node_code\":\"START\",\"node_type\":\"start\"},{\"id\":\"n_test_end\",\"node_code\":\"END\",\"node_type\":\"end\"}]&edges=[{\"id\":\"e_test_1\",\"source\":\"n_test_start\",\"target\":\"n_test_end\"}]"

# Test B
curl -X POST "http://localhost/source/dag_routing_api.php" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "action=graph_validate&graph_id=153&nodes=[{\"id\":\"n_start\",\"node_code\":\"START\",\"node_type\":\"start\"},{\"id\":\"n_end\",\"node_code\":\"END\",\"node_type\":\"end\"},{\"id\":\"n_start1\",\"node_code\":\"START1\",\"node_type\":\"start\"},{\"id\":\"n_end1\",\"node_code\":\"END1\",\"node_type\":\"end\"}]&edges=[{\"id\":\"e1\",\"source\":\"n_start\",\"target\":\"n_end\"}]"
```

---

## Expected Log Output

### Test A (Should Pass)

```
[AUDIT-A] Raw payload: nodes_count=2, edges_count=1
[AUDIT-A] Sample nodes[0..2]: [{"idx":0,"id":"n_test_start","node_code":"START",...},...]
[AUDIT-A] Sample edges[0..2]: [{"idx":0,"id":"e_test_1","source":"n_test_start","target":"n_test_end",...}]
[AUDIT-B] cyIdToNodeCode mapping: total=2
[AUDIT-B] ✅ All edge source/target IDs have mappings
[AUDIT-C] ✅ Edge[0] mapping OK: source=n_test_start -> from_node_code=START, target=n_test_end -> to_node_code=END
[AUDIT-D] All node_codes: ["START","END"]
[AUDIT-D] All edges: ["START -> END"]
[AUDIT-D] ✅ All edges have from_node_code and to_node_code
```

### Test B (Should Show Unreachable)

```
[AUDIT-A] Raw payload: nodes_count=4, edges_count=1
[AUDIT-A] Sample nodes[0..2]: [...]
[AUDIT-B] ✅ All edge source/target IDs have mappings
[AUDIT-C] ✅ Edge[0] mapping OK: source=n_start -> from_node_code=START, target=n_end -> to_node_code=END
[AUDIT-D] All node_codes: ["START","END","START1","END1"]
[AUDIT-D] All edges: ["START -> END"]  ← No edge to START1/END1
[AUDIT-D] EdgeMap structure: total_from_nodes=1, sample_from_node_ids=["START"]
```

**Result**: Should show `UNREACHABLE_NODE` for START1 and END1, but **NO** `EDGE_DANGLING_FROM`.

---

## Troubleshooting

### If Test A Fails
- Check `[AUDIT-B]` for missing mappings
- Check `[AUDIT-C]` for mapping failures
- → **SYSTEM_MAPPING_BUG**

### If Test B Shows EDGE_DANGLING_FROM
- Check `[AUDIT-C]` logs
- → **SYSTEM_MAPPING_BUG** (normalization failed)

### If Test B Doesn't Show UNREACHABLE_NODE
- Check `[AUDIT-D]` for EdgeMap structure
- → **SYSTEM_VALIDATION_BUG** (reachability analysis failed)

