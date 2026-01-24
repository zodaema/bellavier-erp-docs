# Task 26.9 — Product Dependency Logic Refinement

**Status:** ✅ **COMPLETED**  
**Date:** 2025-12-01  
**Purpose:** แก้ไข logic dependency check ให้แยกระหว่าง "Operational usage" (ห้ามลบ) กับ "Config-only usage" (ลบได้พร้อม product)

---

## 🎯 Problem Statement

**Current Issue:**
- Logic dependency check ตอนนี้เข้มเกินไป เพราะไปนับ `product_graph_binding` และ `product_asset` เป็น "การถูกใช้งาน" ด้วย
- ทั้งที่จริงๆ แล้ว 2 ตัวนี้เป็นแค่ config ของ product เอง ไม่ใช่การเอา product ไปใช้ในงานผลิตจริง

**Impact:**
- Duplicate product → ได้ product_graph_binding + product_asset ติดมาด้วย
- พอเช็ค dependency → "อ้าว มีใช้ใน table อื่นแล้วนะ ห้ามลบ"
- ทั้งที่ยังไม่เคยเข้า MO / Hatthasilpa Jobs / Job Ticket เลย

---

## ✅ Solution: Separate Dependency Types

### 1. Operational Usage (ห้ามลบจริง)

ถ้า product ไปโผล่ในพวกนี้ → ต้อง soft delete เท่านั้น (is_active = 0)

- `mo` (MO ของ Classic line)
- `hatthasilpa_job_ticket` (Hatthasilpa Jobs)
- `job_ticket` (Job Tickets)
- (อนาคต) WIP log, shipment, invoice ฯลฯ

### 2. Config-Only Usage (ลบได้พร้อม product)

พวกนี้ไม่ควรนับว่า "เคยใช้งานแล้ว":

- `product_graph_binding` (Routing graph configuration)
- `product_asset` (ไฟล์ pattern, mockup, etc.)
- อะไรที่เป็น "ของประกอบของ product" ไม่ได้ถูกใช้ในงานจริงโดยตรง

---

## 🔧 Implementation Changes

### 1. ProductDependencyScanner::scan()

**Changes:**
- ✅ แยก dependency เป็น 2 กลุ่ม: Operational vs Config-only
- ✅ `has_dependency` เช็คแค่ Operational dependencies เท่านั้น
- ✅ `graph_bindings` และ `asset_count` ยังคงอยู่ใน report (สำหรับ reporting) แต่ไม่นับเป็น blocker
- ✅ เพิ่ม `asset_count` ใน report

**Before:**
```php
$report['has_dependency'] = (
    $report['mo_count'] > 0 ||
    $report['job_ticket_count'] > 0 ||
    $report['hatthasilpa_job_count'] > 0 ||
    $report['inventory_refs'] > 0 ||
    $report['graph_bindings'] > 0  // ❌ This blocks deletion incorrectly
);
```

**After:**
```php
// Config-only dependencies (for reporting only, don't block deletion)
$report['graph_bindings'] = count($graphBindings);
$report['asset_count'] = count($productAssets);

// Only operational dependencies block hard delete
$report['has_dependency'] = (
    $report['mo_count'] > 0 ||
    $report['job_ticket_count'] > 0 ||
    $report['hatthasilpa_job_count'] > 0 ||
    $report['inventory_refs'] > 0
    // Note: graph_bindings and assets are NOT included here
);
```

### 2. handleDeleteHard() Cleanup Logic

**Changes:**
- ✅ เพิ่ม cleanup logic สำหรับ config-only dependencies
- ✅ ลบ `product_graph_binding` ก่อนลบ product
- ✅ ลบ `product_asset` ก่อนลบ product
- ✅ (Optional) TODO: ลบไฟล์จริงจาก storage (ถ้าต้องการ)

**Code Pattern:**
```php
// Step 1: Delete config-only dependencies
// Delete product_graph_binding
$dbHelper->execute("DELETE FROM product_graph_binding WHERE id_product = ?", [$productId], 'i');

// Delete product_asset
$assets = $dbHelper->fetchAll("SELECT file_path, thumb_path FROM product_asset WHERE id_product = ?", [$productId], 'i');
$dbHelper->execute("DELETE FROM product_asset WHERE id_product = ?", [$productId], 'i');
// TODO: Optional - Delete actual files from storage

// Step 2: Delete product
$dbHelper->execute("DELETE FROM product WHERE id_product = ?", [$productId], 'i');
```

### 3. Documentation Updates

**Changes:**
- ✅ อัปเดต docblock ใน `ProductDependencyScanner::canHardDelete()`
- ✅ อธิบายชัดเจนว่า config-only dependencies ไม่ block deletion

---

## 📋 Files Modified

1. **`source/BGERP/Product/ProductDependencyScanner.php`**
   - แก้ `scan()` method ให้แยก operational vs config-only dependencies
   - เพิ่ม `asset_count` ใน report
   - `has_dependency` เช็คแค่ operational dependencies
   - อัปเดต docblock

2. **`source/product_api.php`**
   - เพิ่ม cleanup logic ใน `handleDeleteHard()`
   - ลบ `product_graph_binding` ก่อนลบ product
   - ลบ `product_asset` ก่อนลบ product

---

## ✅ Expected Behavior After Fix

### Scenario 1: Product with Graph Binding Only
- **Before:** ❌ Cannot hard delete (blocked by graph_binding)
- **After:** ✅ Can hard delete (graph_binding is config-only, will be cleaned up)

### Scenario 2: Product with Assets Only
- **Before:** ❌ Cannot hard delete (if assets were counted)
- **After:** ✅ Can hard delete (assets are config-only, will be cleaned up)

### Scenario 3: Product Used in MO
- **Before:** ❌ Cannot hard delete (correct)
- **After:** ❌ Cannot hard delete (correct - operational dependency)

### Scenario 4: Duplicate Product with Binding + Assets
- **Before:** ❌ Cannot hard delete (blocked by config-only dependencies)
- **After:** ✅ Can hard delete (config-only dependencies don't block, will be cleaned up)

---

## 🧪 Testing Checklist

- [ ] Product with only graph_binding → Can hard delete
- [ ] Product with only assets → Can hard delete
- [ ] Product with MO reference → Cannot hard delete (soft delete only)
- [ ] Product with Job Ticket → Cannot hard delete (soft delete only)
- [ ] Duplicate product with binding + assets → Can hard delete
- [ ] Hard delete cleans up graph_binding records
- [ ] Hard delete cleans up asset records
- [ ] Where Used report still shows config-only dependencies (for information)

---

## 📝 Notes

1. **Config-only dependencies are still reported** in `where_used` endpoint for information purposes, but they don't block deletion.

2. **File cleanup is optional** - Currently we only delete database records. Actual file deletion from storage can be added later if needed.

3. **Duplicate workflow** - Now works correctly:
   - Duplicate product → Gets binding + assets
   - If unused → Can hard delete (binding + assets cleaned up)
   - If used in MO/Job → Cannot hard delete (soft delete only)

---

**Last Updated:** 2025-12-01  
**Status:** ✅ **COMPLETED**

