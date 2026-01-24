# Code Analysis: Verification Checklist
**Date**: 2025-12-12  
**Purpose**: ตรวจสอบจากโค้ดจริงว่า normalization ทำงานถูกต้องหรือไม่

## สิ่งที่โค้ดปัจจุบันทำ

### 1. Node Normalization (dag_routing_api.php lines 1594-1622)

✅ **ทำถูกต้อง**:
- เก็บ `id` (Cytoscape ID) และ `node_code`
- สร้าง `$cyIdToNodeCode` mapping: `cyId => node_code`

### 2. Edge Normalization (dag_routing_api.php lines 1804-1918)

✅ **ทำถูกต้อง**:
- Map `source`/`target` (Cytoscape IDs) → `from_node_code`/`to_node_code`
- สร้าง normalized edge ที่มี `from_node_code` และ `to_node_code`

**Potential Issue**:
- ถ้า mapping fail → `from_node_code`/`to_node_code` = `null`
- Logged in `[AUDIT-C]` if fails

### 3. GraphHelper::buildNodeMap() (GraphHelper.php lines 45-67)

✅ **ทำถูกต้อง**:
- สร้าง `node_code => id` mapping (line 54)
- สร้าง `id => node` mapping (line 59)
- สร้าง `temp_id => node` mapping (line 63)

**Critical**: `nodeMap` มี **code => id** mapping สำหรับ `TempIdHelper` ใช้

### 4. GraphHelper::buildEdgeMap() (GraphHelper.php lines 83-136)

✅ **Logic ถูกต้อง**:
- ใช้ `TempIdHelper::getValidationId($edge, 'from_node_id', 'from_node_code', $nodeMap)`
- ถ้า edge มี `from_node_code` → TempIdHelper จะ resolve `nodeMap[$code]` → id

**Potential Issue**:
- ถ้า edge ไม่มี `from_node_code` → `TempIdHelper` return `null` → edgeMap ว่าง
- ถ้า `nodeMap` ไม่มี `code => id` mapping → `TempIdHelper` return `null` → edgeMap ว่าง

### 5. TempIdHelper::getValidationId() (TempIdHelper.php lines 96-129)

✅ **Logic ถูกต้อง**:
- ถ้ามี `from_node_code` และ `nodeMap` → resolve `nodeMap[$code]` → id (lines 111-125)

**Critical**: ต้องมี `from_node_code` ใน edge และ `nodeMap[$code]` ต้องมีค่า

---

## Verification Checklist

### ✅ Check 1: Normalized Edges มี from_node_code/to_node_code หรือไม่?

**ดูจาก**: `[AUDIT-C]` logs

**Expected**:
```
[AUDIT-C] ✅ Edge[0] mapping OK: source=n_xxx -> from_node_code=START, target=n_yyy -> to_node_code=END
```

**If Fails**:
```
[AUDIT-C] ❌ Edge[0] mapping FAILED: from_node_code=NULL
```
→ **SYSTEM_MAPPING_BUG**: Mapping logic ไม่ทำงาน

---

### ✅ Check 2: nodeMap มี code => id mapping หรือไม่?

**ดูจาก**: `[AUDIT-D]` logs

**Expected**:
```
[AUDIT-D] NodeMap structure: total_keys=X, has_code_to_id=yes
```

**If Missing**:
- `has_code_to_id=no` → **SYSTEM_MAPPING_BUG**: buildNodeMap ไม่สร้าง code => id mapping

---

### ✅ Check 3: EdgeMap มี edges หรือไม่?

**ดูจาก**: `[AUDIT-D]` logs

**Expected**:
```
[AUDIT-D] EdgeMap structure: total_from_nodes=1, sample_from_node_ids=["START"]
```

**If Empty**:
```
[AUDIT-D] EdgeMap structure: total_from_nodes=0
```
→ **SYSTEM_VALIDATION_BUG**: buildEdgeMap ไม่สร้าง edgeMap เพราะ edges ไม่มี `from_node_code` หรือ `nodeMap` ไม่มี code => id

---

### ✅ Check 4: Normalized Edges List มี edges หรือไม่?

**ดูจาก**: `[AUDIT-D]` logs

**Expected**:
```
[AUDIT-D] All edges: ["START -> END"]
```

**If Missing Codes**:
```
[AUDIT-D] All edges: ["(from=n_xxx, to=n_yyy) [MISSING CODES]"]
```
→ **SYSTEM_MAPPING_BUG**: Normalization ไม่ map `source`/`target` → `from_node_code`/`to_node_code`

---

## Root Cause Scenarios

### Scenario A: Mapping Logic ไม่ทำงาน

**Symptoms**:
- `[AUDIT-C]` ❌ Edge mapping FAILED: from_node_code=NULL
- `[AUDIT-D]` All edges: ["(from=n_xxx, to=n_yyy) [MISSING CODES]"]

**Root Cause**: 
- `$cyIdToNodeCode` mapping ไม่มี key ที่ตรงกับ `edge.source`
- หรือ type mismatch (string vs int)

**Fix**: 
- File: `source/dag_routing_api.php`
- Function: Edge normalization loop (lines 1815-1860)
- Patch: Fix string/int comparison, ensure all node IDs are in mapping

---

### Scenario B: nodeMap ไม่มี code => id mapping

**Symptoms**:
- `[AUDIT-D]` NodeMap structure: has_code_to_id=no
- `[AUDIT-C]` ✅ Edge mapping OK (from_node_code exists)
- `[AUDIT-D]` EdgeMap structure: total_from_nodes=0

**Root Cause**:
- `GraphHelper::buildNodeMap()` ไม่สร้าง `code => id` mapping
- หรือ nodes ไม่มี `node_code` หรือ `id`

**Fix**:
- File: `source/BGERP/Dag/GraphHelper.php`
- Function: `buildNodeMap()` (lines 45-67)
- Patch: Ensure `$code !== null && $id !== null` before creating mapping

---

### Scenario C: Edges มี from_node_code แต่ TempIdHelper ไม่ resolve

**Symptoms**:
- `[AUDIT-C]` ✅ Edge mapping OK
- `[AUDIT-D]` All edges: ["START -> END"]
- `[AUDIT-D]` EdgeMap structure: total_from_nodes=0

**Root Cause**:
- `TempIdHelper::getValidationId()` ไม่ resolve `from_node_code` → id
- หรือ `nodeMap` structure ไม่ถูกต้อง

**Fix**:
- File: `source/BGERP/Helper/TempIdHelper.php`
- Function: `getValidationId()` (lines 96-129)
- Patch: Debug why `nodeMap[$code]` resolution fails

---

## Next Steps

1. ✅ **Run validation** และดู logs
2. ✅ **Check [AUDIT-C]**: Edge mapping สำเร็จหรือไม่?
3. ✅ **Check [AUDIT-D]**: nodeMap และ EdgeMap structure
4. ✅ **Identify scenario** (A, B, หรือ C)
5. ✅ **Apply fix** ตาม scenario

---

## Quick Test

Run validation และดู logs ตามลำดับ:

1. `[AUDIT-A]` → Raw payload valid?
2. `[AUDIT-B]` → cyIdToNodeCode mapping complete?
3. `[AUDIT-C]` → Edge normalization successful?
4. `[AUDIT-D]` → Final payload and maps ready?

**If any step fails** → Identify root cause from scenarios above.

