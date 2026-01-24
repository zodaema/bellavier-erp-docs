# Task 26.7 Results — Product Dual Delete Mode (Hard Delete + Archive)

**Date:** 2025-12-01  
**Status:** ✅ **COMPLETED**  
**Objective:** เพิ่มระบบ "Dual Delete Mode" สำหรับ Product เพื่อให้การจัดการข้อมูลเป็นไปตามมาตรฐาน ERP ระดับ Enterprise โดยป้องกันข้อมูลสำคัญหาย และยังคงรองรับกรณีสร้างผิด/ทดสอบที่ต้องลบจริงได้

---

## Executive Summary

Task 26.7 สำเร็จในการสร้างระบบ Dual Delete Mode สำหรับ Product โดยรองรับ 2 โหมด:
1. **Hard Delete (ลบจริง)** — ทำได้เฉพาะ Product ที่ *ไม่เคยถูกใช้งานเลย* (dependency = 0)
2. **Archive/Deactivate (Soft Delete)** — ใช้เมื่อ Product เคยถูกใช้งานแล้วแม้เพียงครั้งเดียว (is_active = 0)

**Key Achievements:**
- ✅ สร้าง `handleDeleteHard` endpoint พร้อม dependency validation
- ✅ สร้าง `handleDeactivate` และ `handleActivate` endpoints
- ✅ ปรับปรุง UI ให้ใช้ toggle switch สำหรับ activate/deactivate
- ✅ เพิ่ม dropdown button สำหรับ actions อื่นๆ (Edit, Assets, Graph Binding, Duplicate, Hard Delete)
- ✅ Hard Delete ต้องผ่าน `ProductDependencyScanner::canHardDelete()` เท่านั้น
- ✅ UI แสดง confirmation แบบ 2-step สำหรับ Hard Delete
- ✅ ใช้ `is_active = 0` สำหรับ Archive (ไม่ใช้ `is_archived` column)

---

## Implementation Details

### 1. Backend — Hard Delete Endpoint

**File:** `source/product_api.php`

**Function:** `handleDeleteHard()`

**Features:**
- ✅ ตรวจสอบ permissions (products.manage)
- ✅ ใช้ `ProductDependencyScanner::canHardDelete()` เพื่อตรวจสอบ dependencies
- ✅ Hard Delete ทำได้เฉพาะเมื่อ `is_unused = true` (dependency = 0)
- ✅ ถ้าพบ dependencies → return error พร้อม dependency report
- ✅ ถ้าไม่มี dependencies → DELETE จาก database จริงๆ

**Code Pattern:**
```php
function handleDeleteHard(\mysqli $db, array $member): void {
    // 1. Permission check
    must_allow_code($member, 'products.manage');
    
    // 2. Request validation
    $validation = RequestValidator::make($_POST, [
        'id_product' => 'required|integer|min:1'
    ]);
    
    // 3. Check dependencies
    $scanner = new \BGERP\Product\ProductDependencyScanner($db);
    if (!$scanner->canHardDelete($productId)) {
        // Get dependency report for error message
        $report = $scanner->getDependencies($productId);
        json_error(translate('products.error.cannot_hard_delete', ...), 400, [
            'app_code' => 'PROD_400_HAS_DEPENDENCIES',
            'dependencies' => $report
        ]);
        return;
    }
    
    // 4. Hard delete (only if no dependencies)
    $dbHelper->execute("DELETE FROM product WHERE id_product = ?", [$productId], 'i');
    
    // 5. Success response
    json_success(['message' => translate('products.toast.hard_deleted', 'Product permanently deleted')]);
}
```

---

### 2. Backend — Deactivate/Activate Endpoints

**File:** `source/product_api.php`

**Functions:** `handleDeactivate()`, `handleActivate()`

**Features:**
- ✅ `handleDeactivate`: Sets `is_active = 0` (Soft Delete/Archive)
- ✅ `handleActivate`: Sets `is_active = 1` (Restore)
- ✅ ตรวจสอบ state ก่อน update (prevent duplicate operations)
- ✅ Audit logging (ถ้ามี audit_log table)

**Code Pattern:**
```php
function handleDeactivate(\mysqli $db, array $member): void {
    // 1. Permission check
    must_allow_code($member, 'products.manage');
    
    // 2. Request validation
    $validation = RequestValidator::make($_POST, [
        'id_product' => 'required|integer|min:1'
    ]);
    
    // 3. Check if already inactive
    if ((int)($product['is_active'] ?? 1) === 0) {
        json_error(translate('products.error.already_inactive', ...), 400);
        return;
    }
    
    // 4. Deactivate (is_active = 0)
    $dbHelper->execute(
        "UPDATE product SET is_active = 0 WHERE id_product = ?",
        [$productId],
        'i'
    );
    
    // 5. Success response
    json_success(['message' => translate('products.toast.deactivated', ...)]);
}
```

---

### 3. Frontend — Toggle Switch for Activate/Deactivate

**File:** `assets/javascripts/products/products.js`

**Features:**
- ✅ Toggle switch อยู่ด้านหน้าสุดของ actions column (ไม่มี label)
- ✅ เมื่อ toggle เปลี่ยน → แสดง confirmation dialog
- ✅ เรียก API `activate` หรือ `deactivate` ตาม state
- ✅ Update UI หลัง success (reload DataTable)

**Code Pattern:**
```javascript
// Toggle switch handler
$(document).on('change', '.product-active-toggle', function () {
    const $toggle = $(this);
    const idProduct = $toggle.data('id');
    const productName = $toggle.data('name') || '';
    const isChecked = $toggle.is(':checked');
    const action = isChecked ? 'activate' : 'deactivate';
    
    // Show confirmation
    Swal.fire({
        title: t(`products.${action}.confirm_title`, `${actionText} Product?`),
        html: `<div class="alert ${isChecked ? 'alert-info' : 'alert-warning'}">
            ${t(`products.${action}.message`, ...)}
        </div>`,
        icon: isChecked ? 'question' : 'warning',
        showCancelButton: true,
        confirmButtonText: t(`products.${action}.confirm`, `Yes, ${actionText}`),
        cancelButtonText: t('common.cancel', 'Cancel')
    }).then((result) => {
        if (result.isConfirmed) {
            // Call API
            $.post(EP, {
                action: action,
                id_product: idProduct
            }, function(resp) {
                if (resp.ok) {
                    toastr.success(t(`products.toast.${action === 'activate' ? 'activated' : 'deactivated'}`, ...));
                    table.ajax.reload();
                } else {
                    toastr.error(resp.error || 'Operation failed');
                    // Revert toggle
                    $toggle.prop('checked', !isChecked);
                }
            }, 'json');
        } else {
            // Revert toggle if cancelled
            $toggle.prop('checked', !isChecked);
        }
    });
});
```

---

### 4. Frontend — Hard Delete with 2-Step Confirmation

**File:** `assets/javascripts/products/products.js`

**Features:**
- ✅ Hard Delete button อยู่ใน dropdown menu
- ✅ 2-step confirmation:
  1. Step 1: Warning message + dependency check
  2. Step 2: Final confirmation with "DELETE" keyword
- ✅ เรียก API `where_used` เพื่อตรวจสอบ dependencies ก่อน
- ✅ ถ้ามี dependencies → แสดง dependency report และ block deletion
- ✅ ถ้าไม่มี dependencies → แสดง final confirmation

**Code Pattern:**
```javascript
// Hard delete handler
$(document).on('click', '.btn-hard-delete', function () {
    const idProduct = $(this).data('id');
    const productName = $(this).data('name') || '';
    
    // Step 1: Check dependencies
    $.get(EP, {
        action: 'where_used',
        id_product: idProduct
    }, function(resp) {
        if (resp.ok && resp.data.dependencies.has_dependency) {
            // Show dependency report
            Swal.fire({
                title: t('products.delete_hard.blocked_title', 'Cannot Delete Product'),
                html: `<div class="alert alert-danger">
                    ${t('products.delete_hard.has_dependencies', 'This product has dependencies and cannot be deleted.')}
                    <ul>
                        <li>MO: ${resp.data.dependencies.mo_count}</li>
                        <li>Job Tickets: ${resp.data.dependencies.job_ticket_count}</li>
                        ...
                    </ul>
                </div>`,
                icon: 'error',
                confirmButtonText: t('common.close', 'Close')
            });
            return;
        }
        
        // Step 2: Final confirmation
        Swal.fire({
            title: t('products.delete_hard.confirm_title', 'Permanently Delete Product?'),
            html: `<div class="alert alert-danger">
                ${t('products.delete_hard.warning', 'This action cannot be undone. Type DELETE to confirm.')}
                <input type="text" class="form-control mt-2" id="swal-delete-confirm" placeholder="Type DELETE">
            </div>`,
            icon: 'warning',
            showCancelButton: true,
            confirmButtonText: t('products.delete_hard.confirm', 'Delete Permanently'),
            cancelButtonText: t('common.cancel', 'Cancel'),
            preConfirm: () => {
                const confirmValue = document.getElementById('swal-delete-confirm').value;
                if (confirmValue !== 'DELETE') {
                    Swal.showValidationMessage(t('products.delete_hard.must_type_delete', 'You must type DELETE to confirm'));
                    return false;
                }
                return true;
            }
        }).then((result) => {
            if (result.isConfirmed) {
                // Call hard delete API
                $.post(EP, {
                    action: 'delete_hard',
                    id_product: idProduct
                }, function(resp) {
                    if (resp.ok) {
                        toastr.success(t('products.toast.hard_deleted', 'Product permanently deleted'));
                        table.ajax.reload();
                    } else {
                        toastr.error(resp.error || 'Deletion failed');
                    }
                }, 'json');
            }
        });
    }, 'json');
});
```

---

### 5. UI Refactoring — Actions Column

**File:** `assets/javascripts/products/products.js`

**Changes:**
- ✅ Toggle switch อยู่ด้านหน้าสุด (ไม่มี label)
- ✅ Actions อื่นๆ อยู่ใน dropdown button:
  - Edit
  - Assets
  - Graph Binding
  - Duplicate
  - Hard Delete

**Before:**
```javascript
// Separate buttons for each action
<button class="btn btn-sm btn-primary">Edit</button>
<button class="btn btn-sm btn-warning">Deactivate</button>
<button class="btn btn-sm btn-danger">Delete</button>
```

**After:**
```javascript
// Toggle switch + Dropdown button
<div class="d-flex align-items-center gap-1">
    <input type="checkbox" class="form-check-input product-active-toggle" 
           data-id="${row.id_product}" data-name="${row.name}"
           ${row.is_active ? 'checked' : ''}>
    
    <div class="btn-group">
        <button class="btn btn-sm btn-outline-primary dropdown-toggle" 
                data-bs-toggle="dropdown">
            <i class="fe fe-more-vertical"></i>
        </button>
        <ul class="dropdown-menu">
            <li><a class="dropdown-item btn-edit" href="#">Edit</a></li>
            <li><a class="dropdown-item btn-assets" href="#">Assets</a></li>
            <li><a class="dropdown-item btn-graph-binding" href="#">Graph Binding</a></li>
            <li><hr class="dropdown-divider"></li>
            <li><a class="dropdown-item btn-duplicate" href="#">Duplicate</a></li>
            <li><a class="dropdown-item btn-hard-delete text-danger" href="#">Hard Delete</a></li>
        </ul>
    </div>
</div>
```

---

## ProductDependencyScanner Integration

**File:** `source/BGERP/Product/ProductDependencyScanner.php`

**Enhancements:**
- ✅ เพิ่ม method `canHardDelete(int $productId): bool`
- ✅ เพิ่ม method `getDependencies(int $productId): array`
- ✅ Return `is_unused` flag ใน scan report
- ✅ ตรวจสอบ dependencies จาก:
  - MO (`mo.id_product`)
  - Job Tickets (`job_ticket.id_product`)
  - Hatthasilpa Jobs (`hatthasilpa_job_ticket.id_product`)
  - Graph bindings (`product_graph_binding.id_product`)
  - Inventory transactions (indirect)

**Code Pattern:**
```php
public function canHardDelete(int $productId): bool {
    $report = $this->scan($productId);
    return $report['is_unused'] === true;
}

public function getDependencies(int $productId): array {
    return $this->scan($productId);
}
```

---

## API Endpoints

### 1. `POST /product_api.php?action=deactivate`
- **Purpose:** Deactivate product (Soft Delete)
- **Request:** `{ id_product: int }`
- **Response:** `{ ok: true, message: "..." }`
- **Validation:** Must be active before deactivation

### 2. `POST /product_api.php?action=activate`
- **Purpose:** Activate product (Restore)
- **Request:** `{ id_product: int }`
- **Response:** `{ ok: true, message: "..." }`
- **Validation:** Must be inactive before activation

### 3. `POST /product_api.php?action=delete_hard`
- **Purpose:** Permanently delete product
- **Request:** `{ id_product: int }`
- **Response:** 
  - Success: `{ ok: true, message: "..." }`
  - Error: `{ ok: false, error: "...", dependencies: {...} }`
- **Validation:** Must pass `ProductDependencyScanner::canHardDelete()`

### 4. `GET /product_api.php?action=where_used`
- **Purpose:** Get dependency report
- **Request:** `{ id_product: int }`
- **Response:** `{ ok: true, data: { product: {...}, dependencies: {...} } }`

---

## UI/UX Changes

### Product List Table

**Before:**
- Separate buttons: Edit, Deactivate, Delete
- Status column showing Active/Inactive

**After:**
- Toggle switch (no label) for activate/deactivate
- Dropdown button for other actions
- Status badges (Draft, Inactive) in name column
- No separate Status column

### Modals

**Hard Delete Confirmation:**
- Step 1: Dependency check (if dependencies found → show report and block)
- Step 2: Final confirmation with "DELETE" keyword input

**Activate/Deactivate Confirmation:**
- Simple confirmation dialog
- Warning icon for deactivate, question icon for activate

---

## Testing Matrix

| Case | State | Dependency | Expected |
|------|-------|------------|----------|
| 1 | Active | 0 | Hard Delete allowed |
| 2 | Active | >0 | Hard Delete blocked → Archive only |
| 3 | Inactive | 0 | Hard Delete allowed |
| 4 | Inactive | >0 | Hard Delete blocked |
| 5 | Draft | 0 | Hard Delete allowed |
| 6 | Draft | >0 | Hard Delete blocked |

---

## Files Modified

1. **`source/product_api.php`**
   - Added `handleDeleteHard()` function
   - Added `handleDeactivate()` function
   - Added `handleActivate()` function
   - Updated action routing

2. **`assets/javascripts/products/products.js`**
   - Added toggle switch handler (`.product-active-toggle`)
   - Added hard delete handler (`.btn-hard-delete`)
   - Refactored `renderActions()` to use toggle + dropdown
   - Added 2-step confirmation for hard delete

3. **`views/products.php`**
   - Updated actions column structure (toggle + dropdown)
   - Removed separate Status column

4. **`source/BGERP/Product/ProductDependencyScanner.php`**
   - Added `canHardDelete()` method
   - Added `getDependencies()` method
   - Enhanced `scan()` to return `is_unused` flag

---

## Internationalization (i18n)

**New Keys Added:**
- `products.deactivate.*` - Deactivate confirmation messages
- `products.activate.*` - Activate confirmation messages
- `products.delete_hard.*` - Hard delete confirmation messages
- `products.toast.activated` - Toast message for activation
- `products.toast.deactivated` - Toast message for deactivation
- `products.toast.hard_deleted` - Toast message for hard delete
- `products.error.cannot_hard_delete` - Error message for blocked deletion
- `products.error.already_inactive` - Error message for duplicate deactivation
- `products.error.already_active` - Error message for duplicate activation

---

## Security & Permissions

- ✅ Hard Delete: `products.manage` permission required
- ✅ Deactivate/Activate: `products.manage` permission required
- ✅ Dependency validation: Always checked before hard delete
- ✅ Audit logging: Attempted for all state changes (if audit_log table exists)

---

## Benefits

1. **Data Safety:** Hard Delete ทำได้เฉพาะ unused products
2. **User Experience:** Toggle switch ใช้งานง่ายกว่า separate buttons
3. **Enterprise Compliance:** ตรงตามมาตรฐาน ERP สำหรับ product lifecycle management
4. **Audit Trail:** ทุกการเปลี่ยนแปลง state มี logging
5. **Flexibility:** รองรับทั้ง soft delete (archive) และ hard delete

---

## Next Steps

Product Dual Delete Mode is now complete. Ready for:
- Task 26.8 — Product Module Enterprise Standards Compliance ✅
- Task 26.9 — Product Module Additional Features
- Task 27 — Node Behavior Engine

---

**Last Updated:** 2025-12-01  
**Completed By:** AI Agent  
**Status:** ✅ **COMPLETED**

