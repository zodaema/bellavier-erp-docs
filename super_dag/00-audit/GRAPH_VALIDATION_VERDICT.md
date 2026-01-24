# Graph Validation Verdict: Decision Tree & Evidence
**Date**: 2025-12-12  
**Purpose**: "ศาลตัดสิน" ว่า errors เกิดจาก (A) user/graph state ผิดจริง หรือ (B) ระบบ map/normalize/validate ผิด

## Evidence Collection Points

### Point A: Raw Payload จาก FE (ก่อน normalize)
**Log Tag**: `[AUDIT-A]`

**Check**:
- ✅ `nodes_count`, `edges_count`
- ✅ Sample nodes[0..2]: `{id, node_code}`
- ✅ Sample edges[0..2]: `{id, source, target, from_node_code, to_node_code, from_node_id, to_node_id}`
- ✅ **Critical**: Verify all `edge.source` and `edge.target` exist in `nodes.id`

**Expected**:
- Edges ต้องมีอย่างน้อย `source`/`target` จาก Cytoscape
- ถ้า edge.source ไม่มีใน nodes → **User/State Issue** (dangling edge)

---

### Point B: หลังทำ mapping cyIdToNodeCode
**Log Tag**: `[AUDIT-B]`

**Check**:
- ✅ `cyIdToNodeCode` mapping count
- ✅ Sample mappings (first 5)
- ✅ **Critical**: Missing IDs (edge source/target ที่ resolve ไม่ได้)

**Expected**:
- ทุก `edge.source` ต้อง resolve ได้เป็น `node_code`
- ทุก `edge.target` ต้อง resolve ได้เป็น `node_code`
- ถ้ามี missing IDs → **System Mapping Bug**

---

### Point C: หลัง normalize edge
**Log Tag**: `[AUDIT-C]`

**Check**:
- ❌ Log เฉพาะ edge ที่ `from_node_code` หรือ `to_node_code` เป็น `null`
- ✅ Log success สำหรับ edges ที่ map สำเร็จ (first 2 only)

**Expected**:
- `from_node_code`/`to_node_code` ไม่ควร `null` ถ้า UI ส่ง nodes ถูกต้อง
- ถ้า `null` → **System Normalization Bug**

---

### Point D: ก่อนเรียก GraphValidationEngine->validate()
**Log Tag**: `[AUDIT-D]`

**Check**:
- ✅ All `node_code` list (เพื่อ verify START1/END1 existence)
- ✅ All edges: `(from_node_code -> to_node_code)` list
- ✅ Count edges with missing codes
- ✅ `NodeMap` structure (for ReachabilityAnalyzer)
- ✅ `EdgeMap` structure (for ReachabilityAnalyzer)

**Expected**:
- START1/END1 จะอยู่หรือไม่อยู่ ต้องเห็นชัดใน node_codes list
- ถ้าใน list มี START1/END1 แต่ไม่อยู่ใน UI → **User/State Issue** (hidden state)
- ถ้า edges list ว่าง → **System Mapping Bug**

---

## Decision Tree

### Case 1: Raw payload ถูก แต่ normalize ทำพัง = **SYSTEM_MAPPING_BUG**

**เงื่อนไข**:
- ✅ Raw edges มี `source`/`target` ถูกต้อง (ชี้ไป node ids ที่มีอยู่ใน raw nodes)
- ❌ แต่ normalized edge กลับได้ `from_node_code=null` หรือ `to_node_code=null`

**Evidence**:
```
[AUDIT-A] ✅ All edge sources/targets exist in nodes
[AUDIT-B] ❌ Missing IDs: ["n_new_xxx", ...]  OR
[AUDIT-C] ❌ Edge mapping FAILED: from_node_code=NULL
```

**สรุป**: **SYSTEM_MAPPING_BUG**

**แก้ที่**:
- `cyIdToNodeCode` สร้างผิด
- หรือ normalize edge ไม่ได้เขียน field `from_node_code`/`to_node_code`
- หรือ field ถูก overwrite ทีหลัง

**Fix Location**:
- File: `source/dag_routing_api.php`
- Function: Edge normalization loop (lines ~1703-1814)
- Patch: Ensure `$cyIdToNodeCode` includes all node IDs, fix string/int type comparison

---

### Case 2: Raw payload ส่ง edge source/target ที่ไม่มี node = **USER_STATE_ISSUE**

**เงื่อนไข**:
- ❌ ใน raw nodes ไม่มี `node.id` ที่ตรงกับ `edge.source` หรือ `edge.target`
- หรือ UI มี edge ค้างที่ชี้ไป node ที่ถูกลบไปแล้ว

**Evidence**:
```
[AUDIT-A] ❌ WARNING: Edges reference missing nodes - missing_sources=["n_unknown"], missing_targets=["n_unknown"]
```

**สรุป**: **USER_STATE_ISSUE** (or FE state bug)

**แก้ที่**:
- FE ต้อง prune dangling edges ตอนลบ node
- หรือ validate ต้อง run "cleanup step" ก่อน

**Fix Location**:
- File: `assets/javascripts/dag/graph_designer.js`
- Function: Edge extraction before validation
- Patch: Filter out edges where source/target nodes don't exist

---

### Case 3: START1/END1 unreachable เพราะ edgeMap ว่าง = **SYSTEM_VALIDATION_BUG**

**เงื่อนไข**:
- ✅ Raw graph มี START->END จริง (หรือ edges ที่เชื่อม START ไป START1/END1)
- ❌ แต่ normalized edges list ว่าง หรือ `edgeMap` ว่าง
- ❌ BFS ไม่เดินเพราะ `buildEdgeMap` ไม่เห็น edges

**Evidence**:
```
[AUDIT-D] All node_codes: ["START", "END", "START1", "END1"]
[AUDIT-D] All edges: []  OR  ["START -> END"]  (ไม่มี START -> START1)
[AUDIT-D] EdgeMap structure: total_from_nodes=0
[AUDIT-C] ❌ Edge mapping FAILED: from_node_code=NULL
```

**สรุป**: **SYSTEM_VALIDATION_BUG** (edge fields ไม่เข้า format ที่ engine คาด)

**แก้ที่**:
- Map `source`/`target` → `from_node_code`/`to_node_code` ก่อน `buildEdgeMap`
- หรือ update `TempIdHelper` ให้รองรับ `source`/`target` ตรง ๆ

**Fix Location**:
- File: `source/dag_routing_api.php`
- Function: Edge normalization (ensure `from_node_code`/`to_node_code` are set)
- File: `source/BGERP/Dag/GraphHelper.php`
- Function: `buildEdgeMap()` - handle `source`/`target` if `from_node_code` missing

---

### Case 4: START1/END1 unreachable เพราะมี node ลอยจริง = **USER_GRAPH_INVALID**

**เงื่อนไข**:
- ✅ Normalized nodes list มี START1/END1 จริง
- ✅ Normalized edges ไม่มีเส้นเชื่อมจาก START ไปหา START1/END1 (หรือไม่มี edge ที่เชื่อมถึง)
- ✅ EdgeMap มี edges แต่ BFS จาก START ไม่ถึง START1/END1

**Evidence**:
```
[AUDIT-D] All node_codes: ["START", "END", "START1", "END1"]
[AUDIT-D] All edges: ["START -> END"]  (ไม่มี START -> START1/END1)
[AUDIT-D] EdgeMap structure: total_from_nodes=1, sample_from_node_ids=["START"]
[AUDIT-C] ✅ All edges mapped successfully
```

**สรุป**: **USER_GRAPH_INVALID** (มี orphan nodes จริง)

**แนวทาง**:
- UI toggle "Show unreachable nodes"
- หรือ AutoFix remove/connect unreachable nodes
- User ต้องเชื่อม START1/END1 เข้ากับ main flow

---

## Minimal Repro Tests

### Repro A: Simple START->END (ควรผ่าน)

**Input**:
```json
{
  "nodes": [
    {"id": "n_start", "node_code": "START", "node_type": "start"},
    {"id": "n_end", "node_code": "END", "node_type": "end"}
  ],
  "edges": [
    {"id": "e1", "source": "n_start", "target": "n_end"}
  ]
}
```

**Expected Result**:
- `valid: true`
- `error_count: 0`
- `unreachable_nodes: []`

**If Fails** → **SYSTEM_VALIDATION_BUG** (ระบบ validate ผิดแน่นอน)

---

### Repro B: START->END with orphan START1/END1 (ควร fail)

**Input**:
```json
{
  "nodes": [
    {"id": "n_start", "node_code": "START", "node_type": "start"},
    {"id": "n_end", "node_code": "END", "node_type": "end"},
    {"id": "n_start1", "node_code": "START1", "node_type": "start"},
    {"id": "n_end1", "node_code": "END1", "node_type": "end"}
  ],
  "edges": [
    {"id": "e1", "source": "n_start", "target": "n_end"}
  ]
}
```

**Expected Result**:
- `valid: false`
- `error_count: 2` (หรือมากกว่า)
- `unreachable_nodes: ["START1", "END1"]` ✅ (ถูกต้อง)
- `EDGE_DANGLING_FROM: false` (ไม่มี error นี้)

**If Shows**:
- `EDGE_DANGLING_FROM` → **SYSTEM_MAPPING_BUG**
- START1/END1 **not** unreachable → **SYSTEM_VALIDATION_BUG**

---

## Verdict Output Format

หลังจากรัน validation และดู logs ให้สรุปแบบนี้:

```markdown
## Verdict: [USER_GRAPH_INVALID | SYSTEM_MAPPING_BUG | SYSTEM_VALIDATION_BUG]

### Evidence Summary

1. **Raw Payload (AUDIT-A)**:
   - nodes_count: X
   - edges_count: Y
   - Missing node references: [list or none]
   - Verdict: ✅ Valid / ❌ Has dangling references

2. **Mapping (AUDIT-B)**:
   - cyIdToNodeCode mappings: X
   - Missing IDs: [list or none]
   - Verdict: ✅ All mapped / ❌ Missing mappings

3. **Normalized Edges (AUDIT-C)**:
   - Edges with missing codes: X
   - Verdict: ✅ All mapped / ❌ Mapping failed

4. **Final Payload (AUDIT-D)**:
   - All node_codes: [list]
   - All edges: [list]
   - EdgeMap size: X
   - Verdict: ✅ Valid structure / ❌ Empty/invalid

### Decision
[เลือก Case 1-4 ตามเงื่อนไขที่ตรง]

### Fix Recommendation
[ระบุไฟล์ ฟังก์ชัน และ patch idea 1-2 บรรทัด]
```

---

## Next Steps

1. ✅ Run validation in Graph Designer
2. ✅ Collect logs with `[AUDIT-A]`, `[AUDIT-B]`, `[AUDIT-C]`, `[AUDIT-D]` tags
3. ✅ Follow decision tree with evidence
4. ✅ Run minimal repro tests (A & B)
5. ✅ Generate verdict report

---

## Quick Reference: What to Look For

| Error Type | If AUDIT-A shows... | If AUDIT-B shows... | If AUDIT-C shows... | Verdict |
|-----------|---------------------|---------------------|---------------------|---------|
| EDGE_DANGLING_FROM | Missing nodes | Missing mappings | Mapping failed | **SYSTEM_MAPPING_BUG** |
| EDGE_DANGLING_FROM | All nodes exist | All mapped | Mapping failed | **SYSTEM_NORMALIZATION_BUG** |
| EDGE_DANGLING_FROM | Missing nodes | - | - | **USER_STATE_ISSUE** |
| UNREACHABLE_NODE | - | Missing mappings | Mapping failed | **SYSTEM_MAPPING_BUG** |
| UNREACHABLE_NODE | - | All mapped | All mapped | Check AUDIT-D |
| UNREACHABLE_NODE | - | All mapped | All mapped, but no edges to node | **USER_GRAPH_INVALID** |

