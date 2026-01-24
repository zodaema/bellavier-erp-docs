# Job A: Backend Optimistic Locking - COMPLETED

**Date:** 2026-01-07  
**Duration:** ~30 minutes  
**Status:** ✅ COMPLETED

---

## 📋 Summary

Successfully implemented optimistic locking for `product_graph_binding` table to prevent concurrent update conflicts.

---

## 🔧 Changes Made

### 1. Migration (2026_01_product_graph_binding_row_version.php)

**File:** `database/tenant_migrations/2026_01_product_graph_binding_row_version.php`

**Changes:**
- Added `row_version INT NOT NULL DEFAULT 1` column to `product_graph_binding`
- Includes verification check
- Uses `migration_add_column_if_missing()` for idempotency

**SQL:**
```sql
ALTER TABLE product_graph_binding 
ADD COLUMN row_version INT NOT NULL DEFAULT 1 COMMENT 'Optimistic locking version';
```

---

### 2. Backend Handler (product_api.php)

**File:** `source/product_api.php`

**Function:** `handleBindRouting()`

**Changes:**

#### A. Added `row_version` to validation
```php
$validation = RequestValidator::make($_POST, [
    'id_product' => 'required|integer|min:1',
    'id_graph' => 'required|integer|min:1',
    'graph_version_pin' => 'nullable|string|max:10',
    'row_version' => 'nullable|integer|min:1' // NEW
]);
```

#### B. Extract `row_version` from request
```php
$rowVersion = isset($data['row_version']) ? (int)$data['row_version'] : null;
```

#### C. Fetch current `row_version` when checking existing binding
```php
$stmt = $db->prepare("
    SELECT id_binding, row_version 
    FROM product_graph_binding 
    WHERE id_product = ? AND id_graph = ? AND default_mode = 'hatthasilpa'
    LIMIT 1
");
```

#### D. Optimistic locking check before UPDATE
```php
if ($existing) {
    // If row_version provided, verify it matches current version
    if ($rowVersion !== null && $existing['row_version'] != $rowVersion) {
        json_error(
            translate('products.error.binding_conflict', 'Binding was modified by another user...'),
            409,
            ['app_code' => 'BINDING_409_CONFLICT', 'current_version' => $existing['row_version']]
        );
    }
    
    // Update with version bump
    $stmt = $db->prepare("
        UPDATE product_graph_binding 
        SET graph_version_pin = ?, is_active = 1, updated_by = ?, updated_at = NOW(), row_version = row_version + 1
        WHERE id_binding = ? AND row_version = ?
    ");
    
    // ... bind params and execute ...
    
    // Double-check: If affected_rows = 0, version mismatch occurred
    if ($affectedRows === 0) {
        json_error(
            translate('products.error.binding_conflict', '...'),
            409,
            ['app_code' => 'BINDING_409_CONFLICT']
        );
    }
}
```

#### E. Set `row_version = 1` for new bindings
```php
$stmt = $db->prepare("
    INSERT INTO product_graph_binding 
    (id_product, id_graph, graph_version_pin, default_mode, is_active, created_by, updated_by, row_version)
    VALUES (?, ?, ?, 'hatthasilpa', 1, ?, ?, 1)
");
```

#### F. Return complete binding object with `row_version`
```php
// Fetch complete binding data
$stmt = $db->prepare("
    SELECT 
        id_binding,
        id_product,
        id_graph,
        graph_version_pin,
        default_mode,
        is_active,
        row_version,
        created_at,
        updated_at
    FROM product_graph_binding
    WHERE id_binding = ?
");

json_success([
    'message' => translate('api.product.success.routing_bound', 'Routing graph bound successfully'),
    'binding' => $binding // Complete object with row_version
]);
```

---

### 3. Translations

**File:** `lang/th.php`

```php
'products.error.binding_conflict' => 'การผูก Graph ถูกแก้ไขโดยผู้ใช้อื่น กรุณาโหลดใหม่และลองอีกครั้ง',
```

---

## 🧪 Testing Scenarios

### Scenario 1: Normal Update (No Conflict)

**Request:**
```json
{
  "action": "bind_routing",
  "id_product": 123,
  "id_graph": 456,
  "graph_version_pin": "1.0",
  "row_version": 5
}
```

**Response:**
```json
{
  "ok": true,
  "message": "Routing graph bound successfully",
  "binding": {
    "id_binding": 789,
    "id_product": 123,
    "id_graph": 456,
    "graph_version_pin": "1.0",
    "default_mode": "hatthasilpa",
    "is_active": 1,
    "row_version": 6,
    "created_at": "2026-01-07 10:00:00",
    "updated_at": "2026-01-07 10:05:00"
  }
}
```

---

### Scenario 2: Concurrent Update (Conflict)

**Timeline:**
```
T0: User A loads binding (row_version = 5)
T1: User B loads binding (row_version = 5)
T2: User A saves (row_version = 5) → Success, new version = 6
T3: User B saves (row_version = 5) → CONFLICT!
```

**User B's Request:**
```json
{
  "action": "bind_routing",
  "id_product": 123,
  "id_graph": 789,
  "row_version": 5
}
```

**User B's Response:**
```json
{
  "ok": false,
  "error": "การผูก Graph ถูกแก้ไขโดยผู้ใช้อื่น กรุณาโหลดใหม่และลองอีกครั้ง",
  "app_code": "BINDING_409_CONFLICT",
  "current_version": 6
}
```

**HTTP Status:** 409 Conflict

---

### Scenario 3: Create New Binding

**Request:**
```json
{
  "action": "bind_routing",
  "id_product": 123,
  "id_graph": 456,
  "graph_version_pin": "1.0"
}
```

**Response:**
```json
{
  "ok": true,
  "message": "Routing graph bound successfully",
  "binding": {
    "id_binding": 999,
    "id_product": 123,
    "id_graph": 456,
    "graph_version_pin": "1.0",
    "default_mode": "hatthasilpa",
    "is_active": 1,
    "row_version": 1,
    "created_at": "2026-01-07 10:10:00",
    "updated_at": "2026-01-07 10:10:00"
  }
}
```

---

## ✅ Acceptance Criteria

- [x] Migration adds `row_version` column to `product_graph_binding`
- [x] Backend checks `row_version` on UPDATE
- [x] Backend returns 409 + `BINDING_409_CONFLICT` on conflict
- [x] Backend returns new `row_version` in success response
- [x] Backend uses `WHERE id_binding = ? AND row_version = ?` for UPDATE
- [x] Backend checks `affected_rows` for double-verification
- [x] New bindings start with `row_version = 1`
- [x] Translations added for error messages

---

## 📊 Impact Analysis

### Security
- ✅ **Data Integrity:** Prevents silent data loss from concurrent updates
- ✅ **Audit Trail:** `row_version` provides change tracking
- ✅ **User Feedback:** Clear error message when conflict occurs

### Performance
- ✅ **Minimal Overhead:** Single integer column + WHERE clause check
- ✅ **No Locking:** Optimistic approach = no database locks
- ✅ **Fast Validation:** Integer comparison is O(1)

### Compatibility
- ✅ **Backward Compatible:** `row_version` is nullable in validation
- ✅ **Legacy Support:** Old clients without `row_version` still work
- ✅ **Migration Safe:** Uses `migration_add_column_if_missing()`

---

## 🚀 Next Steps

### Job B: API Unification
- Make `products.php?action=update_graph_binding` a wrapper
- Update Workspace JS to send `row_version`
- Update Workspace state after save

### Job E: Readiness Gate (NEW)
- Create `get_revision_readiness` endpoint
- Enforce readiness check in `publish_revision`
- Map "ติ๊กถูกในแท็บ" to deterministic rules

---

## 📝 Files Changed

| File | Lines Changed | Type |
|------|---------------|------|
| `database/tenant_migrations/2026_01_product_graph_binding_row_version.php` | +30 | NEW |
| `source/product_api.php` | +80 | MODIFIED |
| `lang/th.php` | +1 | MODIFIED |

**Total:** 111 lines changed, 1 new file

---

**Job A Status:** ✅ **COMPLETED**  
**Ready for Job B:** ✅ **YES**  
**Estimated Time for Job B:** 1.5 hours

---

*Report Generated: 2026-01-07*  
*Author: AI Agent*  
*Next: Job B - API Unification*

# Job A: Backend Optimistic Locking - COMPLETED

**Date:** 2026-01-07  
**Duration:** ~30 minutes  
**Status:** ✅ COMPLETED

---

## 📋 Summary

Successfully implemented optimistic locking for `product_graph_binding` table to prevent concurrent update conflicts.

---

## 🔧 Changes Made

### 1. Migration (2026_01_product_graph_binding_row_version.php)

**File:** `database/tenant_migrations/2026_01_product_graph_binding_row_version.php`

**Changes:**
- Added `row_version INT NOT NULL DEFAULT 1` column to `product_graph_binding`
- Includes verification check
- Uses `migration_add_column_if_missing()` for idempotency

**SQL:**
```sql
ALTER TABLE product_graph_binding 
ADD COLUMN row_version INT NOT NULL DEFAULT 1 COMMENT 'Optimistic locking version';
```

---

### 2. Backend Handler (product_api.php)

**File:** `source/product_api.php`

**Function:** `handleBindRouting()`

**Changes:**

#### A. Added `row_version` to validation
```php
$validation = RequestValidator::make($_POST, [
    'id_product' => 'required|integer|min:1',
    'id_graph' => 'required|integer|min:1',
    'graph_version_pin' => 'nullable|string|max:10',
    'row_version' => 'nullable|integer|min:1' // NEW
]);
```

#### B. Extract `row_version` from request
```php
$rowVersion = isset($data['row_version']) ? (int)$data['row_version'] : null;
```

#### C. Fetch current `row_version` when checking existing binding
```php
$stmt = $db->prepare("
    SELECT id_binding, row_version 
    FROM product_graph_binding 
    WHERE id_product = ? AND id_graph = ? AND default_mode = 'hatthasilpa'
    LIMIT 1
");
```

#### D. Optimistic locking check before UPDATE
```php
if ($existing) {
    // If row_version provided, verify it matches current version
    if ($rowVersion !== null && $existing['row_version'] != $rowVersion) {
        json_error(
            translate('products.error.binding_conflict', 'Binding was modified by another user...'),
            409,
            ['app_code' => 'BINDING_409_CONFLICT', 'current_version' => $existing['row_version']]
        );
    }
    
    // Update with version bump
    $stmt = $db->prepare("
        UPDATE product_graph_binding 
        SET graph_version_pin = ?, is_active = 1, updated_by = ?, updated_at = NOW(), row_version = row_version + 1
        WHERE id_binding = ? AND row_version = ?
    ");
    
    // ... bind params and execute ...
    
    // Double-check: If affected_rows = 0, version mismatch occurred
    if ($affectedRows === 0) {
        json_error(
            translate('products.error.binding_conflict', '...'),
            409,
            ['app_code' => 'BINDING_409_CONFLICT']
        );
    }
}
```

#### E. Set `row_version = 1` for new bindings
```php
$stmt = $db->prepare("
    INSERT INTO product_graph_binding 
    (id_product, id_graph, graph_version_pin, default_mode, is_active, created_by, updated_by, row_version)
    VALUES (?, ?, ?, 'hatthasilpa', 1, ?, ?, 1)
");
```

#### F. Return complete binding object with `row_version`
```php
// Fetch complete binding data
$stmt = $db->prepare("
    SELECT 
        id_binding,
        id_product,
        id_graph,
        graph_version_pin,
        default_mode,
        is_active,
        row_version,
        created_at,
        updated_at
    FROM product_graph_binding
    WHERE id_binding = ?
");

json_success([
    'message' => translate('api.product.success.routing_bound', 'Routing graph bound successfully'),
    'binding' => $binding // Complete object with row_version
]);
```

---

### 3. Translations

**File:** `lang/th.php`

```php
'products.error.binding_conflict' => 'การผูก Graph ถูกแก้ไขโดยผู้ใช้อื่น กรุณาโหลดใหม่และลองอีกครั้ง',
```

---

## 🧪 Testing Scenarios

### Scenario 1: Normal Update (No Conflict)

**Request:**
```json
{
  "action": "bind_routing",
  "id_product": 123,
  "id_graph": 456,
  "graph_version_pin": "1.0",
  "row_version": 5
}
```

**Response:**
```json
{
  "ok": true,
  "message": "Routing graph bound successfully",
  "binding": {
    "id_binding": 789,
    "id_product": 123,
    "id_graph": 456,
    "graph_version_pin": "1.0",
    "default_mode": "hatthasilpa",
    "is_active": 1,
    "row_version": 6,
    "created_at": "2026-01-07 10:00:00",
    "updated_at": "2026-01-07 10:05:00"
  }
}
```

---

### Scenario 2: Concurrent Update (Conflict)

**Timeline:**
```
T0: User A loads binding (row_version = 5)
T1: User B loads binding (row_version = 5)
T2: User A saves (row_version = 5) → Success, new version = 6
T3: User B saves (row_version = 5) → CONFLICT!
```

**User B's Request:**
```json
{
  "action": "bind_routing",
  "id_product": 123,
  "id_graph": 789,
  "row_version": 5
}
```

**User B's Response:**
```json
{
  "ok": false,
  "error": "การผูก Graph ถูกแก้ไขโดยผู้ใช้อื่น กรุณาโหลดใหม่และลองอีกครั้ง",
  "app_code": "BINDING_409_CONFLICT",
  "current_version": 6
}
```

**HTTP Status:** 409 Conflict

---

### Scenario 3: Create New Binding

**Request:**
```json
{
  "action": "bind_routing",
  "id_product": 123,
  "id_graph": 456,
  "graph_version_pin": "1.0"
}
```

**Response:**
```json
{
  "ok": true,
  "message": "Routing graph bound successfully",
  "binding": {
    "id_binding": 999,
    "id_product": 123,
    "id_graph": 456,
    "graph_version_pin": "1.0",
    "default_mode": "hatthasilpa",
    "is_active": 1,
    "row_version": 1,
    "created_at": "2026-01-07 10:10:00",
    "updated_at": "2026-01-07 10:10:00"
  }
}
```

---

## ✅ Acceptance Criteria

- [x] Migration adds `row_version` column to `product_graph_binding`
- [x] Backend checks `row_version` on UPDATE
- [x] Backend returns 409 + `BINDING_409_CONFLICT` on conflict
- [x] Backend returns new `row_version` in success response
- [x] Backend uses `WHERE id_binding = ? AND row_version = ?` for UPDATE
- [x] Backend checks `affected_rows` for double-verification
- [x] New bindings start with `row_version = 1`
- [x] Translations added for error messages

---

## 📊 Impact Analysis

### Security
- ✅ **Data Integrity:** Prevents silent data loss from concurrent updates
- ✅ **Audit Trail:** `row_version` provides change tracking
- ✅ **User Feedback:** Clear error message when conflict occurs

### Performance
- ✅ **Minimal Overhead:** Single integer column + WHERE clause check
- ✅ **No Locking:** Optimistic approach = no database locks
- ✅ **Fast Validation:** Integer comparison is O(1)

### Compatibility
- ✅ **Backward Compatible:** `row_version` is nullable in validation
- ✅ **Legacy Support:** Old clients without `row_version` still work
- ✅ **Migration Safe:** Uses `migration_add_column_if_missing()`

---

## 🚀 Next Steps

### Job B: API Unification
- Make `products.php?action=update_graph_binding` a wrapper
- Update Workspace JS to send `row_version`
- Update Workspace state after save

### Job E: Readiness Gate (NEW)
- Create `get_revision_readiness` endpoint
- Enforce readiness check in `publish_revision`
- Map "ติ๊กถูกในแท็บ" to deterministic rules

---

## 📝 Files Changed

| File | Lines Changed | Type |
|------|---------------|------|
| `database/tenant_migrations/2026_01_product_graph_binding_row_version.php` | +30 | NEW |
| `source/product_api.php` | +80 | MODIFIED |
| `lang/th.php` | +1 | MODIFIED |

**Total:** 111 lines changed, 1 new file

---

**Job A Status:** ✅ **COMPLETED**  
**Ready for Job B:** ✅ **YES**  
**Estimated Time for Job B:** 1.5 hours

---

*Report Generated: 2026-01-07*  
*Author: AI Agent*  
*Next: Job B - API Unification*

