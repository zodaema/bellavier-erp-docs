# DAG Refactor Comparison Audit
**Date:** 2025-12-10  
**Task:** task27.26_DAG_ROUTING_API  
**Status:** 🔴 **CRITICAL ISSUES FOUND**

---

## 📋 Executive Summary

เปรียบเทียบไฟล์ทั้งหมดใน `source/dag/` กับ `dag_routing_api_original.php` พบปัญหาสำคัญ:

1. **`loadGraphWithVersion()` ใน `_helpers.php` ขาด `anchor_slot` ใน SELECT query**
2. **`loadGraphWithVersion()` ไม่ได้ check draft state** (แต่ original file ก็ไม่ได้ check เหมือนกัน - check แยกใน `graph_get` action)

---

## 🔍 Issue #1: Missing `anchor_slot` in `loadGraphWithVersion()` SELECT Query

### Problem Description
`loadGraphWithVersion()` ใน `source/dag/_helpers.php` ไม่ได้ include `anchor_slot` column ใน SELECT query

### Comparison

**Original File:** `source/dag_routing_api_original.php` line 470-522
```sql
SELECT 
    id_node,
    id_graph,
    node_code,
    node_name,
    node_type,
    ...
    qc_policy
FROM routing_node
WHERE id_graph = ?
```

**❌ Missing:** `anchor_slot` column ไม่ได้อยู่ใน SELECT list

**New File:** `source/dag/_helpers.php` line 259-310
```sql
SELECT 
    id_node,
    id_graph,
    node_code,
    node_name,
    node_type,
    ...
    qc_policy
FROM routing_node
WHERE id_graph = ?
```

**❌ Missing:** `anchor_slot` column ไม่ได้อยู่ใน SELECT list เหมือนกัน

### Impact
- เมื่อ query nodes จาก `routing_node` table, `anchor_slot` จะไม่ถูก return
- Component nodes จะไม่มี `anchor_slot` ใน response
- `getAnchorSlotsInGraph()` จะไม่พบ component nodes ที่มี `anchor_slot`

### Recommended Fix
เพิ่ม `anchor_slot` ใน SELECT query ของ `loadGraphWithVersion()`:

```sql
SELECT 
    id_node,
    id_graph,
    node_code,
    node_name,
    node_type,
    ...
    qc_policy,
    anchor_slot  -- ✅ ADD THIS
FROM routing_node
WHERE id_graph = ?
```

---

## 🔍 Issue #2: Draft State Handling

### Problem Description
`loadGraphWithVersion()` ไม่ได้ check draft state แต่ original file ก็ไม่ได้ check เหมือนกัน - check แยกใน `graph_get` action

### Comparison

**Original File:** `source/dag_routing_api_original.php`
- `loadGraphWithVersion()` (line 339-600): ไม่ check draft - query จาก `routing_node` โดยตรง
- `graph_get` action (line 1802-1891): **มี check draft แยก** - override nodes/edges จาก draft ถ้ามี

**New File:** `source/dag/_helpers.php`
- `loadGraphWithVersion()` (line 159-385): ไม่ check draft - query จาก `routing_node` โดยตรง
- `GraphService->getGraph()` (line 100-236): **มี check draft** (line 144-224) - override nodes/edges จาก draft ถ้ามี

### Analysis
- Pattern ถูกต้อง: `loadGraphWithVersion()` ไม่ check draft (low-level helper)
- แต่ `GraphService->getGraph()` มี check draft (high-level service)
- **ปัญหาคือ:** ถ้าใช้ `loadGraphWithVersion()` โดยตรง (ไม่ผ่าน GraphService) จะไม่ได้ draft nodes

### Impact
- ถ้า graph ยังอยู่ใน draft state, nodes จะอยู่ใน `draft_payload_json`
- `loadGraphWithVersion()` จะ query จาก `routing_node` ซึ่งอาจไม่มี draft nodes
- `getAnchorSlotsInGraph()` ที่ query จาก `routing_node` โดยตรงจะไม่พบ draft nodes

---

## 📊 Detailed Comparison Matrix

| Feature | Original File | New File (`source/dag/`) | Status |
|---------|--------------|-------------------------|--------|
| `loadGraphWithVersion()` - anchor_slot in SELECT | ❌ Missing | ❌ Missing | ⚠️ Same issue |
| `loadGraphWithVersion()` - draft check | ❌ No | ❌ No | ✅ Same (by design) |
| `graph_get` - draft check | ✅ Yes (line 1802-1891) | ✅ Yes (GraphService line 144-224) | ✅ Same |
| `graph_save` - anchor_slot handling | ✅ Yes (line 2736, 2758, 2958, 3007) | ✅ Yes (GraphSaveEngine line 686, 706, 749) | ✅ Same |
| `graph_save_draft` - anchor_slot in payload | ✅ Yes (saved in draft_payload_json) | ✅ Yes (saved in draft_payload_json) | ✅ Same |

---

## 🛠️ Recommended Fixes

### Priority 1: Add `anchor_slot` to `loadGraphWithVersion()` SELECT

**File:** `source/dag/_helpers.php` line 259-310

**Change:**
```php
$nodes = $db->fetchAll("
    SELECT 
        id_node,
        id_graph,
        node_code,
        node_name,
        node_type,
        ...
        qc_policy,
        anchor_slot  -- ✅ ADD THIS
    FROM routing_node
    WHERE id_graph = ?
    ORDER BY sequence_no ASC, id_node ASC
", [$graphId], 'i');
```

**Reason:**
- Component nodes ต้องมี `anchor_slot` ใน response
- `getAnchorSlotsInGraph()` ต้องอ่าน `anchor_slot` จาก nodes
- ถ้าไม่มี `anchor_slot` ใน SELECT, nodes จะไม่มี field นี้

---

## 🧪 Testing Checklist

- [ ] Test `loadGraphWithVersion()` return `anchor_slot` สำหรับ component nodes
- [ ] Test `getAnchorSlotsInGraph()` return slots จาก published graph
- [ ] Test `getAnchorSlotsInGraph()` return slots จาก draft graph (ผ่าน GraphService)
- [ ] Test Component Mapping ใน Product Modal ทำงานได้ปกติ
- [ ] Test `graph_save` save `anchor_slot` ลง database
- [ ] Test `graph_save_draft` save `anchor_slot` ใน draft payload

---

## 📝 Notes

1. **Draft State:**
   - `loadGraphWithVersion()` ไม่ check draft (by design - low-level helper)
   - `GraphService->getGraph()` มี check draft (high-level service)
   - ควรใช้ `GraphService->getGraph()` แทน `loadGraphWithVersion()` โดยตรง

2. **Anchor Slot:**
   - ต้องเพิ่ม `anchor_slot` ใน SELECT query ของ `loadGraphWithVersion()`
   - Original file ก็ไม่ได้ include `anchor_slot` - นี่อาจเป็น bug ที่มีอยู่แล้ว

---

## 🔗 Related Files

- `source/dag/_helpers.php` - `loadGraphWithVersion()` function
- `source/dag/Graph/Service/GraphService.php` - `getGraph()` method
- `source/dag/Graph/Service/GraphSaveEngine.php` - `saveGraph()` method
- `source/dag_routing_api_original.php` - Original implementation
