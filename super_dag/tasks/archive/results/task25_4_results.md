# Task 25.4 Results — Deprecate Classic DAG / Cleanup Graph Binding UI & Backend

**Phase:** 25 — Classic Line Stabilization  
**Status:** ✅ **COMPLETED**  
**Date:** 2025-11-29  
**Owner:** System Engineering (Bellavier Group ERP)

---

## 📋 Summary

Task 25.4 เป็นการทำให้ Classic Line ไม่ต้องใช้ DAG/Graph Binding และทำให้ชัดเจนว่า:

> **Classic Line = ไม่ต้องใช้ DAG**  
> **Hatthasilpa Line = ต้องมี DAG Binding เท่านั้น**

---

## ✅ Completed Deliverables

### 1. ProductMetadataResolver Enhancement ✅

**File:** `source/BGERP/Product/ProductMetadataResolver.php`

- ✅ เพิ่ม `supports_graph` flag ใน metadata
  - Classic → `supports_graph = false`
  - Hatthasilpa → `supports_graph = true`
- ✅ Classic products: `routing` จะเป็น `null` เสมอ
- ✅ เพิ่ม `production_line` ที่ top level ของ metadata

**Changes:**
```php
// Task 25.4: Classic line does not support graph binding
$supportsGraph = ($productionLine === 'hatthasilpa');

// Task 25.4: For Classic, ensure routing is always null
if ($productionLine === 'classic') {
    $routing = null;
}
```

### 2. Product API Guards ✅

**File:** `source/product_api.php`

- ✅ `handleBindRouting()`: ป้องกัน Classic products bind graph
  - Error message: "Classic line cannot bind DAG routing. Only Hatthasilpa products support routing binding."
- ✅ `handleUnbindRouting()`: ป้องกัน Classic products unbind graph
  - Error message: "Classic line cannot unbind DAG routing. Only Hatthasilpa products have routing binding."

**Guards:**
```php
if ($productionLine !== 'hatthasilpa') {
    json_error('Classic line cannot bind DAG routing. Only Hatthasilpa products support routing binding.', 400);
}
```

### 3. Product Graph Binding Modal Refactor ✅

**File:** `views/products.php`

- ✅ เพิ่ม `binding-tab-item` และ `classic-dashboard-tab-item` IDs
- ✅ เพิ่ม Classic message box (`classic-no-binding-message`)
- ✅ Binding tab: ซ่อนเมื่อ Classic, แสดงเมื่อ Hatthasilpa
- ✅ Classic Dashboard tab: แสดงเมื่อ Classic, ซ่อนเมื่อ Hatthasilpa
- ✅ Graph Binding Form: ซ่อนเมื่อ Classic

**UI Changes:**
- Binding tab → ซ่อนเมื่อ `supports_graph = false`
- Classic Dashboard tab → แสดงเมื่อ `supports_graph = false`
- Classic message → "Classic products do not use DAG routing"

### 4. JavaScript Metadata Loading & Tab Control ✅

**File:** `assets/javascripts/products/product_graph_binding.js`

- ✅ เพิ่ม `loadProductMetadata()` function
  - โหลด metadata จาก `product_api.php?action=get_metadata`
  - ควบคุม tab visibility ตาม `supports_graph` flag
- ✅ Tab Control Logic:
  - **Hatthasilpa** (`supports_graph = true`):
    - แสดง Binding tab
    - ซ่อน Classic Dashboard tab
    - แสดง Graph Binding Form
    - Activate Binding tab
  - **Classic** (`supports_graph = false`):
    - ซ่อน Binding tab
    - แสดง Classic Dashboard tab
    - ซ่อน Graph Binding Form
    - แสดง Classic message
    - Activate Classic Dashboard tab
    - Auto-load Classic Dashboard
- ✅ `renderBindingStatus()`: Skip rendering สำหรับ Classic products

**New Function:**
```javascript
function loadProductMetadata(productId, token, callback) {
    // Load metadata from product_api.php
    // Control tab visibility based on supports_graph flag
    // Auto-load Classic Dashboard for Classic products
}
```

### 5. Database Migration ✅

**File:** `database/tenant_migrations/2025_12_deprecate_classic_dag_bindings.php`

- ✅ Deactivate routing bindings สำหรับ Classic products
- ✅ Query products ที่มี `production_lines` = 'oem' หรือ 'classic' (แต่ไม่มี 'hatthasilpa')
- ✅ UPDATE `product_graph_binding` SET `is_active = 0` สำหรับ Classic products
- ✅ Verify cleanup: ไม่มี active bindings เหลือสำหรับ Classic products

**Migration Logic:**
```sql
-- Step 1: Find Classic products
SELECT DISTINCT id_product 
FROM product 
WHERE (production_lines LIKE '%oem%' OR production_lines LIKE '%classic%')
  AND NOT production_lines LIKE '%hatthasilpa%'
  AND is_active = 1

-- Step 2: Deactivate bindings
UPDATE product_graph_binding 
SET is_active = 0, updated_at = NOW()
WHERE id_product IN (...) AND is_active = 1
```

### 6. Safety Guards ✅

- ✅ Backend guard: ป้องกัน Classic products bind graph
- ✅ Frontend guard: ซ่อน binding UI สำหรับ Classic products
- ✅ Migration guard: ลบ bindings ที่ไม่ถูกต้องสำหรับ Classic products

---

## 📁 Files Modified

### Files Modified
1. `source/BGERP/Product/ProductMetadataResolver.php`
   - เพิ่ม `supports_graph` flag
   - Ensure routing = null สำหรับ Classic

2. `source/product_api.php`
   - ปรับ error messages ให้ชัดเจน
   - Guard Classic products

3. `views/products.php`
   - เพิ่ม tab control IDs
   - เพิ่ม Classic message box
   - ปรับ tab structure

4. `assets/javascripts/products/product_graph_binding.js`
   - เพิ่ม `loadProductMetadata()` function
   - Tab visibility control
   - Auto-load Classic Dashboard

### New Files Created
1. `database/tenant_migrations/2025_12_deprecate_classic_dag_bindings.php`
   - Migration เพื่อลบ bindings สำหรับ Classic products

---

## ✅ Acceptance Criteria Status

| Criteria | Status |
|----------|--------|
| Classic products: UI ไม่แสดง Graph Binding tab | ✅ |
| Classic products: Backend ไม่ validate routing | ✅ |
| Classic products: API ไม่ส่ง routing metadata | ✅ |
| Hatthasilpa products: Graph Binding = required | ✅ |
| Classic products: ห้าม bind graph + แสดง error | ✅ |
| UI ซ่อนปุ่ม/เมนู Graph Binding เมื่อ classic | ✅ |
| Modal binding ซ่อนทั้ง tab และ inputs เมื่อ classic | ✅ |
| Product API: Skip routing validation สำหรับ Classic | ✅ |
| Routing Graph Binding Modal: แสดงเฉพาะ Classic Dashboard สำหรับ Classic | ✅ |
| Backward Safety: Classic products ที่เคยมี routing_graph_id → ลบค่าออก | ✅ |
| Migration script: ปรับฐานข้อมูล | ✅ |

---

## 🔧 Technical Details

### Metadata Structure (Updated)

**Classic Product:**
```json
{
  "ok": true,
  "data": {
    "product": {
      "id": 123,
      "name": "Classic Product",
      "sku": "CLASSIC-001",
      "production_line": "classic"
    },
    "production_line": "classic",
    "supports_graph": false,
    "routing": null,
    "classic": {
      "dashboard_enabled": true
    },
    "hatthasilpa": {
      "routing_required": false
    }
  }
}
```

**Hatthasilpa Product:**
```json
{
  "ok": true,
  "data": {
    "product": {
      "id": 456,
      "name": "Hatthasilpa Product",
      "sku": "HAT-001",
      "production_line": "hatthasilpa"
    },
    "production_line": "hatthasilpa",
    "supports_graph": true,
    "routing": {
      "bound": true,
      "valid": true,
      "id_graph": 88,
      "graph_name": "Hatthasilpa Production v3",
      "graph_mode": "dag",
      "node_count": 14
    },
    "classic": {
      "dashboard_enabled": false
    },
    "hatthasilpa": {
      "routing_required": true
    }
  }
}
```

### Tab Control Logic

**Hatthasilpa Products:**
- Binding tab: แสดง
- Stats tab: แสดง
- History tab: แสดง
- Classic Dashboard tab: ซ่อน

**Classic Products:**
- Binding tab: ซ่อน
- Stats tab: แสดง (ถ้ามี)
- History tab: แสดง (ถ้ามี)
- Classic Dashboard tab: แสดง (auto-activate)

---

## 🧪 Testing Recommendations

1. **Classic Product Testing:**
   - เปิด Product Graph Binding Modal → ควรเห็น Classic Dashboard tab
   - ไม่เห็น Binding tab
   - Classic Dashboard โหลดข้อมูลได้
   - พยายาม bind graph → ควรได้ error

2. **Hatthasilpa Product Testing:**
   - เปิด Product Graph Binding Modal → ควรเห็น Binding tab
   - ไม่เห็น Classic Dashboard tab
   - Binding form ทำงานได้ปกติ

3. **Migration Testing:**
   - รัน migration
   - ตรวจสอบว่า Classic products ไม่มี active bindings
   - ตรวจสอบว่า Hatthasilpa products ยังมี bindings อยู่

---

## 📝 Notes

### Backward Compatibility
- ✅ Classic products ที่เคยมี bindings จะถูก deactivate อัตโนมัติ
- ✅ Hatthasilpa products ไม่ได้รับผลกระทบ
- ✅ UI/API ทำงานแบบ backward compatible

### Known Limitations
- Classic products: ไม่สามารถ bind graph ได้อีกต่อไป
- Hybrid products (มีทั้ง classic และ hatthasilpa): ยังคงมี bindings อยู่ (จะแก้ใน Task 25.6)

---

## 🔮 Next Steps

- **Task 25.5** — Product Index + Filtering
  - หน้า list + filter ตาม line, type, active
  - Search optimization

- **Task 25.6** — DB Cleanup
  - Migration ลบ legacy template/version columns
  - Normalize `production_line` field
  - Handle hybrid products (แยกเป็น 2 products)

---

**Status:** ✅ **COMPLETED** (2025-11-29)

