# Final Verdict: Graph Validation Errors
**Date**: 2025-12-12  
**Verdict**: **SYSTEM_MAPPING_BUG**

## Evidence Summary

### ✅ Point A: Raw Payload (AUDIT-A)
- **nodes_count**: 14
- **edges_count**: 19
- **Sample nodes**: มี `id` (Cytoscape ID) เช่น `"n4471"` แต่ `id_node: null`
- **Sample edges**: มี `source`/`target` (Cytoscape IDs) แต่ `from_node_code: null`, `to_node_code: null`
- **Verdict**: ✅ Raw payload valid - edges reference nodes that exist

### ✅ Point B: Mapping (AUDIT-B)
- **cyIdToNodeCode mappings**: 14 (ครบทุก node)
- **Missing IDs**: None
- **Verdict**: ✅ All edge source/target IDs have mappings

### ✅ Point C: Normalized Edges (AUDIT-C)
- **Edge[0] mapping**: ✅ OK - `source=n4471 -> from_node_code=START`
- **Edge[1] mapping**: ✅ OK - `source=n4472 -> to_node_code=CUT`
- **Verdict**: ✅ All edges mapped successfully

### ❌ Point D: Final Payload (AUDIT-D)
- **All node_codes**: ✅ มีครบ 14 nodes
- **All edges**: ✅ มี `from_node_code -> to_node_code` ครบ 19 edges
- **NodeMap structure**: ❌ `total_keys=0` (ว่างเปล่า!)
- **EdgeMap structure**: ❌ `total_from_nodes=0` (ว่างเปล่า!)

**Verdict**: ❌ **SYSTEM_MAPPING_BUG** - NodeMap ไม่ถูกสร้าง

---

## Root Cause

### Problem
`GraphHelper::buildNodeMap()` ไม่สร้าง mapping เพราะ:

1. Nodes จาก FE มี `id: "n4471"` (Cytoscape ID) แต่ไม่มี:
   - `id_node` (database ID) = `null`
   - `temp_id` (temp ID) = ไม่มี

2. `TempIdHelper::getValidationId($node, 'id_node', 'temp_id')`:
   - ตรวจสอบ `id_node` → `null` (ไม่ใช่ permanent ID)
   - ตรวจสอบ `temp_id` → ไม่มี (ไม่ใช่ temp-* format)
   - **Return `null`**

3. `buildNodeMap()`:
   ```php
   $id = TempIdHelper::getValidationId($node, 'id_node', 'temp_id');
   // $id = null
   if ($code !== null && $id !== null) {
       $map[$code] = $id;  // ❌ ไม่เข้าเงื่อนไข
   }
   if ($id !== null) {
       $map[$id] = $node;  // ❌ ไม่เข้าเงื่อนไข
   }
   ```
   - **Result**: `$map = []` (ว่างเปล่า)

4. `buildEdgeMap()`:
   - ใช้ `TempIdHelper::getValidationId($edge, 'from_node_id', 'from_node_code', $nodeMap)`
   - Edge มี `from_node_code: "START"` แต่ `nodeMap["START"]` ไม่มี (เพราะ NodeMap ว่าง)
   - **Return `null`** → EdgeMap ว่าง

5. `ReachabilityAnalyzer`:
   - BFS เริ่มจาก START แต่ `edgeMap[START]` = `[]` (ว่าง)
   - **Result**: ทุก node unreachable (รวมถึง START เอง!)

---

## Decision: Case 3 - SYSTEM_VALIDATION_BUG

**เงื่อนไข**:
- ✅ Raw graph มี edges จริง (19 edges)
- ✅ Normalized edges มี `from_node_code`/`to_node_code` ครบ
- ❌ แต่ `edgeMap` ว่างเปล่า
- ❌ BFS ไม่เดินเพราะ `buildEdgeMap` ไม่เห็น edges

**สรุป**: **SYSTEM_MAPPING_BUG** (NodeMap ไม่ถูกสร้าง → EdgeMap ว่าง → Validation fail)

---

## Fix Applied

### File: `source/BGERP/Dag/GraphHelper.php`
### Function: `buildNodeMap()` (lines 45-67)

**Patch**:
```php
// CRITICAL FIX: If no id_node/temp_id, use 'id' field (Cytoscape ID) as fallback
// This handles nodes from FE that only have Cytoscape IDs (e.g., "n4471")
if ($id === null) {
    $id = $node['id'] ?? null;
}
```

**Rationale**:
- Nodes จาก FE มี `id` (Cytoscape ID) แต่ไม่มี `id_node`/`temp_id`
- ต้องใช้ `id` เป็น fallback เพื่อสร้าง NodeMap
- NodeMap จะมี: `code => id`, `id => node` mappings

---

## Expected Result After Fix

### Before Fix:
```
[AUDIT-D] NodeMap structure: total_keys=0
[AUDIT-D] EdgeMap structure: total_from_nodes=0
→ Validation fails: EDGE_DANGLING_FROM, UNREACHABLE_NODE
```

### After Fix:
```
[AUDIT-D] NodeMap structure: total_keys=28 (14 code=>id + 14 id=>node)
[AUDIT-D] EdgeMap structure: total_from_nodes=10
→ Validation should pass (if graph structure is valid)
```

---

## Verification Steps

1. ✅ Refresh browser และกด Validate
2. ✅ ดู logs:
   - `[AUDIT-D] NodeMap structure: total_keys=X` (ควร > 0)
   - `[AUDIT-D] EdgeMap structure: total_from_nodes=X` (ควร > 0)
3. ✅ ตรวจสอบ validation errors:
   - `EDGE_DANGLING_FROM`: ควรหายไป
   - `UNREACHABLE_NODE`: ควรหายไป (ถ้ากราฟ structure ถูกต้อง)

---

## Conclusion

**Verdict**: **SYSTEM_MAPPING_BUG**

**Root Cause**: `buildNodeMap()` ไม่รองรับ nodes ที่มีแค่ Cytoscape ID (`id`) แต่ไม่มี `id_node`/`temp_id`

**Fix**: ใช้ `id` field เป็น fallback ใน `buildNodeMap()`

**Status**: ✅ Fixed - ต้องทดสอบอีกครั้งเพื่อยืนยัน

