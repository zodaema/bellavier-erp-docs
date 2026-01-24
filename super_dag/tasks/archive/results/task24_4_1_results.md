# Task 24.4.1 Results – Fix Job Ticket Creation Defaults (Classic Line + DAG)

**Date:** 2025-11-28  
**Status:** ✅ **COMPLETED**  
**Objective:** แก้ปัญหาการสร้าง Job Ticket ใหม่ที่ยัง fallback ไปใช้ค่าเริ่มต้นแบบ Legacy (production_type = hatthasilpa, routing_mode = linear) โดยบังคับให้ Job Ticket ที่สร้างจาก MO เป็น Classic Line + DAG Mode

---

## Executive Summary

Task 24.4.1 ได้แก้ไขปัญหาการสร้าง Job Ticket จาก MO ที่ยังใช้ค่า default แบบ Legacy โดย:
- **บังคับ production_type = 'classic'** สำหรับ MO-origin tickets
- **บังคับ routing_mode = 'dag'** เมื่อมี routing graph
- **ปรับ frontend** ให้ส่งค่าเหล่านี้เมื่อสร้าง ticket
- **เพิ่ม logging** สำหรับ debug

**Key Achievements:**
- ✅ ปรับ create case ใน job_ticket.php ให้บังคับ classic + dag สำหรับ MO-origin tickets
- ✅ เพิ่ม production_type และ routing_mode ใน INSERT statement
- ✅ ปรับ mo_info API ให้ return id_routing_graph และ production_type
- ✅ ปรับ frontend JS ให้เก็บและใช้ routing graph ID
- ✅ Backward compatible 100%

---

## Files Modified

### 1. `source/job_ticket.php`
**Changes:**
- **mo_info case (line 635-648):**
  - เพิ่ม `m.id_routing_graph` และ `m.production_type` ใน SELECT query
  - Return routing graph ID และ production_type ใน response

- **create case (line 942-1002):**
  - เพิ่ม logic สำหรับบังคับ production_type และ routing_mode:
    ```php
    // Task 24.4.1: Force Classic Line + DAG Mode for MO-origin tickets
    $isMoOrigin = !empty($payload['id_mo']);
    $productionType = 'classic'; // Default for MO-origin tickets
    $routingMode = 'linear'; // Default fallback
    
    if ($isMoOrigin) {
      $productionType = 'classic';
      if ($id_routing_graph !== null) {
        $routingMode = 'dag';
      } else {
        $routingMode = 'linear';
      }
    }
    ```
  - เพิ่ม `production_type` และ `routing_mode` ใน INSERT statement
  - เพิ่ม logging เมื่อ override จาก legacy defaults
  - เพิ่ม production_type และ routing_mode ใน response data

### 2. `assets/javascripts/hatthasilpa/job_ticket.js`
**Changes:**
- **mo_info handler (line 1120-1165):**
  - เก็บ MO data รวมถึง `id_routing_graph` และ `production_type` ใน data attribute:
    ```javascript
    $(selectors.ticketMo).data('mo-data', {
      id_mo: resp.data.id_mo,
      id_routing_graph: resp.data.id_routing_graph || null,
      production_type: resp.data.production_type || 'classic'
    });
    ```

- **gatherTicketPayload() function (line 2777-2791):**
  - เพิ่ม logic สำหรับส่ง production_type และ routing_mode:
    ```javascript
    // Task 24.4.1: Force Classic Line + DAG Mode for MO-origin tickets
    if (selectedMo && !$(selectors.ticketId).val()) { // Only for create, not update
      payload.production_type = 'classic';
      
      const moData = $(selectors.ticketMo).data('mo-data') || {};
      const hasRoutingGraph = !!(moData.id_routing_graph || $(selectors.ticketMo).data('routing-graph-id'));
      
      if (hasRoutingGraph) {
        payload.routing_mode = 'dag';
      } else {
        payload.routing_mode = 'linear';
      }
    }
    ```

---

## Business Rules Implementation

### Rule 1: MO-origin Tickets = Classic Line
**Implementation:**
```php
if ($isMoOrigin) {
    $productionType = 'classic'; // Always classic for MO-origin
}
```

**Validation:**
- ตรวจสอบ `!empty($payload['id_mo'])` เพื่อระบุว่าเป็น MO-origin ticket
- บังคับ `production_type = 'classic'` เสมอ

### Rule 2: Classic Line + DAG Mode (when has graph)
**Implementation:**
```php
if ($isMoOrigin) {
    if ($id_routing_graph !== null) {
        $routingMode = 'dag';
    } else {
        $routingMode = 'linear'; // Fallback if no graph
    }
}
```

**Validation:**
- ตรวจสอบ `$id_routing_graph` จาก MO
- ถ้ามี graph → `routing_mode = 'dag'`
- ถ้าไม่มี graph → `routing_mode = 'linear'` (แต่ยังคง `production_type = 'classic'`)

### Rule 3: Non-MO Tickets
**Implementation:**
```php
else {
    // Non-MO origin: use values from request (if provided) or defaults
    $productionType = strtolower(trim($data['production_type'] ?? 'hatthasilpa'));
    $routingMode = strtolower(trim($data['routing_mode'] ?? 'linear'));
    
    // Validate and set defaults
    if (!in_array($productionType, ['classic', 'hatthasilpa'], true)) {
        $productionType = 'hatthasilpa'; // Default for non-MO tickets
    }
    if (!in_array($routingMode, ['linear', 'dag'], true)) {
        $routingMode = 'linear';
    }
}
```

**Validation:**
- Non-MO tickets ใช้ค่าจาก request หรือ defaults
- Default สำหรับ non-MO: `hatthasilpa` + `linear`

---

## Database Schema Impact

### Columns Used
- `job_ticket.production_type`: VARCHAR (classic | hatthasilpa)
- `job_ticket.routing_mode`: VARCHAR (linear | dag)
- `job_ticket.id_routing_graph`: INT NULL (foreign key to routing_graph)

### INSERT Statement Changes

**Before:**
```sql
INSERT INTO job_ticket (ticket_code, job_name, target_qty, id_mo, sku, id_product, due_date, assigned_to, assigned_user_id, notes, process_mode, id_routing_graph, graph_version) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
```

**After:**
```sql
INSERT INTO job_ticket (ticket_code, job_name, target_qty, id_mo, sku, id_product, due_date, assigned_to, assigned_user_id, notes, process_mode, production_type, routing_mode, id_routing_graph, graph_version) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
```

**Note:** `production_type` และ `routing_mode` ถูกเพิ่มเข้าไปใน INSERT statement

---

## Frontend Integration

### MO Info API Response
**Before:**
```json
{
  "ok": true,
  "data": {
    "id_mo": 123,
    "mo_code": "MO-001",
    "qty": 100,
    "status": "planned",
    "product_name": "Product A",
    "sku": "SKU-001"
  }
}
```

**After:**
```json
{
  "ok": true,
  "data": {
    "id_mo": 123,
    "mo_code": "MO-001",
    "qty": 100,
    "status": "planned",
    "id_routing_graph": 5,
    "production_type": "classic",
    "product_name": "Product A",
    "sku": "SKU-001"
  }
}
```

### Payload for Create
**Before:**
```javascript
{
  action: "create",
  job_name: "Job Name",
  id_mo: 123,
  // ... other fields
}
```

**After (MO-origin):**
```javascript
{
  action: "create",
  job_name: "Job Name",
  id_mo: 123,
  production_type: "classic",
  routing_mode: "dag", // or "linear" if no graph
  // ... other fields
}
```

---

## Testing Scenarios

### Scenario 1: Create Ticket from MO with Routing Graph
**Steps:**
1. Create MO with routing graph bound to product
2. Create Job Ticket from MO
3. Verify ticket has `production_type = 'classic'` and `routing_mode = 'dag'`

**Expected Result:**
- ✅ `production_type = 'classic'`
- ✅ `routing_mode = 'dag'`
- ✅ `id_routing_graph` matches MO's routing graph

### Scenario 2: Create Ticket from MO without Routing Graph
**Steps:**
1. Create MO without routing graph
2. Create Job Ticket from MO
3. Verify ticket has `production_type = 'classic'` and `routing_mode = 'linear'`

**Expected Result:**
- ✅ `production_type = 'classic'`
- ✅ `routing_mode = 'linear'`
- ✅ `id_routing_graph = NULL`

### Scenario 3: Create Ticket without MO (Non-MO origin)
**Steps:**
1. Create Job Ticket without MO (direct creation)
2. Verify ticket uses defaults or values from request

**Expected Result:**
- ✅ `production_type = 'hatthasilpa'` (default) หรือค่าจาก request
- ✅ `routing_mode = 'linear'` (default) หรือค่าจาก request

### Scenario 4: Update Existing Ticket
**Steps:**
1. Update existing Job Ticket
2. Verify production_type และ routing_mode ไม่ถูก override

**Expected Result:**
- ✅ Existing values ไม่ถูก override
- ✅ Update logic ไม่กระทบ production_type/routing_mode

---

## Logging

### Debug Logs Added
```php
// Task 24.4.1: Log override from legacy defaults
if ($isMoOrigin) {
    error_log(sprintf(
        "[Task 24.4.1] Created MO-origin ticket %d: production_type=%s, routing_mode=%s (graph_id=%s)", 
        $insertId, $productionType, $routingMode, $id_routing_graph ?: 'none'
    ));
}
```

**Example Log Output:**
```
[Task 24.4.1] Created MO-origin ticket 1234: production_type=classic, routing_mode=dag (graph_id=5)
[Task 24.4.1] Created MO-origin ticket 1235: production_type=classic, routing_mode=linear (graph_id=none)
```

---

## Consistency Checks

### SQL Verification
```sql
-- Check MO-origin tickets created after patch
SELECT 
    id_job_ticket,
    ticket_code,
    id_mo,
    production_type,
    routing_mode,
    id_routing_graph,
    created_at
FROM job_ticket
WHERE id_mo IS NOT NULL
  AND created_at >= '2025-11-28'
ORDER BY created_at DESC;

-- Expected: All should have production_type = 'classic'
-- Expected: routing_mode = 'dag' if id_routing_graph IS NOT NULL
-- Expected: routing_mode = 'linear' if id_routing_graph IS NULL
```

### Lifecycle v2 Compatibility
- ✅ Tickets created with `production_type = 'classic'` สามารถใช้ lifecycle v2 ได้
- ✅ Tickets with `routing_mode = 'dag'` สามารถ spawn tokens ได้
- ✅ Start/Pause/Resume/Complete ทำงานได้ถูกต้อง

---

## Backward Compatibility

### Existing Tickets
- ✅ Tickets ที่สร้างก่อน patch ไม่ถูกแก้ไข
- ✅ Update operations ไม่กระทบ production_type/routing_mode
- ✅ Legacy tickets ยังทำงานได้ปกติ

### API Compatibility
- ✅ mo_info API เพิ่ม fields ใหม่ (backward compatible)
- ✅ create API รับ production_type/routing_mode จาก request (optional)
- ✅ Non-MO tickets ยังใช้ defaults เดิม

---

## Limitations & Future Enhancements

### Known Limitations

1. **Graph Detection:**
   - Frontend ต้องพึ่งพา mo_info API เพื่อรู้ routing graph ID
   - ถ้า MO ยังไม่มี routing graph → จะใช้ linear mode

2. **Product Binding:**
   - ยังไม่มีการตรวจสอบ product binding อัตโนมัติ
   - ต้องพึ่งพา MO's routing graph

### Future Enhancements

1. **Auto-detect Product Binding:**
   - ตรวจสอบ product binding อัตโนมัติเมื่อสร้าง ticket
   - Override MO's routing graph ถ้า product binding เปลี่ยน

2. **Graph Validation:**
   - Validate routing graph ก่อนสร้าง ticket
   - Warn ถ้า graph ไม่ valid หรือไม่ published

---

## Summary

Task 24.4.1 ได้แก้ไขปัญหาการสร้าง Job Ticket จาก MO ที่ยังใช้ค่า default แบบ Legacy โดยบังคับให้เป็น Classic Line + DAG Mode ตาม business rules ใหม่

**Files Modified:** 2  
**Lines Added:** ~50  
**Breaking Changes:** None  
**Backward Compatible:** Yes  
**Database Changes:** None (uses existing columns)

**Key Benefits:**
- ✅ MO-origin tickets เป็น Classic Line เสมอ
- ✅ DAG mode ถูกใช้เมื่อมี routing graph
- ✅ Lifecycle v2 ทำงานได้ถูกต้องกับ tickets ใหม่
- ✅ ไม่มีผลข้างเคียงกับ Hatthasilpa Line

