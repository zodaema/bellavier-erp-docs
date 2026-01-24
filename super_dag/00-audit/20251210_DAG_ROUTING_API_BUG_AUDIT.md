# DAG Routing API Bug Audit Report
**Date:** 2025-12-10  
**Task:** task27.26_DAG_ROUTING_API  
**Status:** 🔴 **CRITICAL BUGS FOUND**

---

## 📋 Executive Summary

พบบัคสำคัญ 2 ข้อในไฟล์ `dag_routing_api.php` (หลัง refactor) เมื่อเทียบกับ `dag_routing_api_original.php`:

1. **Validation Logic Bug:** Verify ผ่านแทบทุกอย่าง (ไม่ควรเป็นแบบนี้)
2. **Component Mapping Missing:** Component Mapping ไม่ทำงานใน Product Modal

---

## 🔍 Issue #1: Validation Logic - Verify ผ่านแทบทุกอย่าง

### Problem Description
Validation ผ่านแม้ว่าจะมี errors อยู่จริง

### Root Cause Analysis

**Location:** `source/dag_routing_api.php` line 1850

```php
'valid' => empty($errors) && $validationResult['valid'],
```

**Problem:**
- Logic นี้ถูกต้อง แต่ปัญหาอาจอยู่ที่ `$validationResult['valid']` จาก `GraphValidationEngine->validate()` return `true` แม้ว่าจะมี errors
- หรือ `$errors` array ไม่ถูก populate อย่างถูกต้อง

### Comparison with Original File

**Original File:** `source/dag_routing_api_original.php` line 4141
```php
'valid' => empty($errors) && $validationResult['valid'],
```

**Result:** Logic เหมือนกัน แต่ไฟล์เก่าทำงานได้ดี

### Investigation Findings

1. **Error Population Logic:** 
   - ไฟล์ใหม่: line 1578-1643 - populate $errors จาก `$validationResult['errors']`
   - ไฟล์เก่า: line 3869-3934 - populate $errors จาก `$validationResult['errors']`
   - **เหมือนกันทุกอย่าง**

2. **Possible Issues:**
   - `GraphValidationEngine->validate()` อาจ return `valid: true` แม้ว่าจะมี errors ใน array
   - หรือ `$validationResult['errors']` อาจเป็น empty array แม้ว่าจะมี errors จริงๆ

### Recommended Fix

**Option 1: Force valid = false if errors exist**
```php
'valid' => empty($errors) && empty($validationResult['errors']) && ($validationResult['valid'] ?? false),
```

**Option 2: Check validationResult structure**
```php
// Ensure we check both local errors and validationResult errors
$hasErrors = !empty($errors) || !empty($validationResult['errors']);
'valid' => !$hasErrors && ($validationResult['valid'] ?? false),
```

**Option 3: Debug validationResult**
เพิ่ม logging เพื่อดูว่า `$validationResult` มี structure อย่างไร:
```php
error_log('[DEBUG] validationResult: ' . json_encode($validationResult));
error_log('[DEBUG] errors count: ' . count($errors));
error_log('[DEBUG] validationResult[errors] count: ' . count($validationResult['errors'] ?? []));
```

---

## 🔍 Issue #2: Component Mapping ไม่ทำงานใน Product Modal

### Problem Description
Component Mapping ที่ควรแสดงใน Modal ของด้าน Product ไม่ทำงาน

### Root Cause Analysis

**Frontend Code:** `assets/javascripts/products/product_graph_binding.js` line 2040-2054

```javascript
function loadGraphSlots(graphId) {
  return new Promise((resolve, reject) => {
    $.getJSON('source/component_mapping_api.php', { 
      action: 'get_slots',
      graph_id: graphId 
    }, (resp) => {
      const slots = resp?.data?.slots || resp?.slots || [];
      currentGraphSlots = slots;
      resolve(slots);
    }).fail((xhr, status, error) => {
      reject(error);
    });
  });
}
```

**Key Finding:**
- Frontend เรียก `component_mapping_api.php` ไม่ใช่ `dag_routing_api.php`
- ดังนั้นปัญหาอาจไม่ใช่ที่ `dag_routing_api.php` แต่เป็นที่ `component_mapping_api.php` หรือ service ที่เกี่ยวข้อง

### Comparison with Original File

**Original File:** ไม่มี action ที่เกี่ยวข้องกับ component mapping ใน `dag_routing_api_original.php`

**Result:** Component Mapping ใช้ API แยก (`component_mapping_api.php`) ไม่ได้อยู่ใน dag_routing_api

### Investigation Findings

1. **API Endpoint:**
   - Frontend เรียก: `component_mapping_api.php?action=get_slots`
   - Service: `ComponentMappingService->getAnchorSlotsInGraph()`
   - **ไม่เกี่ยวข้องกับ dag_routing_api.php**

2. **Possible Issues:**
   - `component_mapping_api.php` อาจมีปัญหา
   - หรือ `ComponentMappingService` อาจมีปัญหา
   - หรือ database query อาจไม่ return ข้อมูล

### Investigation Results

**✅ Verified:**
1. `component_mapping_api.php` มี action `get_slots` (line 105)
2. ใช้ `TenantApiOutput::success(['slots' => $slots])` ซึ่งจะ return format: `{ok: true, data: {slots: [...]}}`
3. Frontend code (line 2047) คาดหวัง `resp?.data?.slots || resp?.slots` - **ถูกต้อง**
4. Service: `ComponentMappingService->getAnchorSlotsInGraph()` query ถูกต้อง

**Possible Issues:**
1. **Permission:** `must_allow_code($member, 'component.mapping.view')` อาจไม่ผ่าน
2. **Database:** อาจไม่มี component nodes ใน graph (node_type = 'component' AND anchor_slot IS NOT NULL)
3. **Response Format:** Frontend อาจไม่ได้รับ response ถูกต้อง

### Recommended Fix

**Step 1: Check Browser Console**
```javascript
// ใน Product Modal, เปิด Console และดู error
// ตรวจสอบว่า API call สำเร็จหรือไม่
```

**Step 2: Test API directly**
```bash
# Test API endpoint (ต้อง login ก่อน)
curl -X GET "http://localhost/source/component_mapping_api.php?action=get_slots&graph_id=1" \
  -H "Cookie: PHPSESSID=..."
```

**Step 3: Check Database**
```sql
-- ตรวจสอบว่ามี component nodes ใน graph หรือไม่
SELECT id_node, node_code, anchor_slot 
FROM routing_node 
WHERE id_graph = ? 
  AND node_type = 'component' 
  AND anchor_slot IS NOT NULL 
  AND anchor_slot != '';
```

**Step 4: Check Permission**
- ตรวจสอบว่า user มี permission `component.mapping.view` หรือไม่
- หรืออาจต้องใช้ `dag.routing.view` แทน

**Step 5: Add Debug Logging**
```php
// ใน component_mapping_api.php, case 'get_slots'
error_log(sprintf('[CID:%s] get_slots - graph_id: %d, slots_count: %d',
    $cid ?? 'N/A',
    $graphId,
    count($slots)
));
```

---

## 🔍 Issue #3: Action Delegation Differences

### Problem Description
ไฟล์ใหม่มีการ delegate actions ไปยัง `dag_graph_api.php` แต่ไฟล์เก่าไม่มี

### Comparison

**New File:** `source/dag_routing_api.php` line 1192-1207
```php
case 'graph_list':
case 'graph_get':
case 'graph_view':
case 'graph_by_code':
case 'graph_versions':
case 'graph_version_compare':
case 'compare_versions':
case 'graph_create':
case 'graph_save':
case 'graph_save_draft':
case 'graph_discard_draft':
case 'graph_delete':
    // Delegate to new API file
    require_once __DIR__ . '/dag/dag_graph_api.php';
    exit;
```

**Original File:** `source/dag_routing_api_original.php`
- ไม่มีการ delegate
- ทุก action อยู่ในไฟล์เดียวกัน

### Impact Analysis

**Potential Issues:**
1. หาก `dag_graph_api.php` มีปัญหา validation logic อาจไม่ทำงาน
2. หาก `dag_graph_api.php` ไม่มี helper functions ที่จำเป็น อาจเกิด error

### Recommended Fix

**Step 1: Verify dag_graph_api.php exists and works**
```bash
# ตรวจสอบว่าไฟล์มีอยู่จริง
ls -la source/dag/dag_graph_api.php

# ตรวจสอบว่า graph_validate อยู่ใน dag_graph_api.php หรือไม่
grep -n "case 'graph_validate'" source/dag/dag_graph_api.php
```

**Step 2: Check if graph_validate is delegated**
- หาก `graph_validate` ถูก delegate ไปยัง `dag_graph_api.php` แต่ไฟล์นั้นไม่มี action นี้ จะเกิด error
- ตรวจสอบว่า `graph_validate` ยังอยู่ใน `dag_routing_api.php` หรือไม่

---

## 📊 Detailed Comparison Matrix

| Feature | Original File | New File | Status |
|---------|--------------|----------|--------|
| `graph_validate` action | ✅ Line 3813 | ✅ Line 1522 | ✅ Same |
| Validation logic | ✅ Line 3863-4153 | ✅ Line 1572-1863 | ✅ Same |
| `loadGraphWithVersion` | ✅ Line 339 | ✅ Line 339 | ✅ Same |
| Error population | ✅ Line 3869-3934 | ✅ Line 1578-1643 | ✅ Same |
| Component Mapping | ❌ N/A (uses separate API) | ❌ N/A (uses separate API) | ⚠️ Not in this file |
| Action delegation | ❌ None | ✅ Lines 1192-1207 | ⚠️ Different |

---

## 🛠️ Recommended Actions

### Priority 1: Fix Validation Logic

1. **Add Debug Logging**
   ```php
   // In graph_validate case, before json_success
   error_log(sprintf('[CID:%s] Validation Debug - errors: %d, validationResult[valid]: %s, validationResult[errors]: %d',
       $cid,
       count($errors),
       $validationResult['valid'] ? 'true' : 'false',
       count($validationResult['errors'] ?? [])
   ));
   ```

2. **Fix Valid Flag Logic**
   ```php
   // Ensure valid is false if ANY errors exist
   $hasAnyErrors = !empty($errors) || !empty($validationResult['errors'] ?? []);
   'valid' => !$hasAnyErrors && ($validationResult['valid'] ?? false),
   ```

3. **Test with Known Invalid Graph**
   - สร้าง graph ที่มี errors (เช่น ไม่มี START node)
   - เรียก `graph_validate`
   - ตรวจสอบว่า `valid: false` และมี errors

### Priority 2: Investigate Component Mapping

1. **Check component_mapping_api.php**
   ```bash
   grep -A 30 "case 'get_slots'" source/component_mapping_api.php
   ```

2. **Test API Endpoint**
   - ใช้ browser console หรือ Postman
   - เรียก `component_mapping_api.php?action=get_slots&graph_id={valid_graph_id}`
   - ตรวจสอบ response

3. **Check Database**
   ```sql
   -- ตรวจสอบว่ามี component nodes ใน graph หรือไม่
   SELECT id_node, node_code, anchor_slot 
   FROM routing_node 
   WHERE id_graph = ? AND node_type = 'component' AND anchor_slot IS NOT NULL;
   ```

### Priority 3: Verify Action Delegation

1. **Check if graph_validate is in dag_graph_api.php**
   ```bash
   grep -n "case 'graph_validate'" source/dag/dag_graph_api.php
   ```

2. **If not delegated, verify it's still in dag_routing_api.php**
   ```bash
   grep -n "case 'graph_validate'" source/dag_routing_api.php
   ```

---

## 🧪 Testing Checklist

- [ ] Test `graph_validate` with invalid graph (no START node)
- [ ] Test `graph_validate` with invalid graph (multiple START nodes)
- [ ] Test `graph_validate` with invalid graph (cycle detected)
- [ ] Test `graph_validate` with valid graph
- [ ] Test Component Mapping API endpoint directly
- [ ] Test Component Mapping in Product Modal UI
- [ ] Verify all delegated actions work correctly
- [ ] Compare response structure between old and new API

---

## 📝 Notes

1. **Component Mapping Issue:**
   - ปัญหาอาจไม่ใช่ที่ `dag_routing_api.php`
   - ควรตรวจสอบ `component_mapping_api.php` และ `ComponentMappingService` ก่อน

2. **Validation Issue:**
   - Logic ดูเหมือนถูกต้อง แต่ผลลัพธ์ไม่ถูกต้อง
   - ควรเพิ่ม debug logging เพื่อหาสาเหตุ
   - อาจเป็นปัญหาที่ `GraphValidationEngine` return structure ไม่ถูกต้อง

3. **Action Delegation:**
   - การ delegate actions ไปยังไฟล์อื่นอาจทำให้เกิดปัญหา
   - ควรตรวจสอบว่าไฟล์ที่ถูก delegate มี action ที่จำเป็นครบหรือไม่

---

## 🔗 Related Files

- `source/dag_routing_api.php` - ไฟล์ใหม่ (มีปัญหา)
- `source/dag_routing_api_original.php` - ไฟล์เก่า (ใช้งานได้)
- `source/dag/dag_graph_api.php` - ไฟล์ที่ถูก delegate
- `source/component_mapping_api.php` - Component Mapping API
- `source/BGERP/Service/ComponentMappingService.php` - Component Mapping Service
- `source/BGERP/Dag/GraphValidationEngine.php` - Validation Engine

---

**Next Steps:**
1. เพิ่ม debug logging ใน `graph_validate`
2. ตรวจสอบ `component_mapping_api.php`
3. Test validation logic กับ graph ที่มี errors
4. เปรียบเทียบ response structure ระหว่างไฟล์เก่าและใหม่















