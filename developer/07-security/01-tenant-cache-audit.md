# Tenant Cache Security Audit

**Date:** 2025-11-XX  
**Status:** ✅ Audit Complete  
**Risk Level:** 🟡 Medium (2 issues found)

---

## 📋 Executive Summary

ตรวจสอบ cache ทั้งหมดที่อาจทำให้ข้อมูล tenant หนึ่งไปแสดงใน tenant อื่น พบ **2 จุดที่ต้องแก้ไข** และ **5 จุดที่ปลอดภัย**

---

## ✅ **ปลอดภัย (Safe)**

### 1. `tenant_db()` - Connection Cache
**File:** `config.php:232`

```php
static $tenantCache = [];
// ...
$code = $org['code'];
if (isset($tenantCache[$code])) {
    return $tenantCache[$code];
}
```

**✅ ปลอดภัย:** ใช้ `$code` (tenant code) เป็น key → แต่ละ tenant มี connection แยกกัน

---

### 2. `resolve_current_org()` - Organization Resolution
**File:** `config.php:255`

```php
// PHP 8.2 FIX: Remove static cache - it prevents tenant switching from working correctly
// Static variables persist across multiple calls in the same request, causing stale tenant data
```

**✅ ปลอดภัย:** ลบ static cache ออกแล้ว (แก้ไขเมื่อ Oct 28, 2025)

---

### 3. `app_translator()` - Translation Cache
**File:** `global_function.php:177`

```php
static $dictionaries = [];
$lang = app_language();
if (!isset($dictionaries[$lang])) {
    // ...
}
```

**✅ ปลอดภัย:** ใช้ `$lang` เป็น key → ไม่เกี่ยวกับ tenant (translation เป็น global)

---

### 4. `ensure_work_center_schema()` - Schema Check Cache
**File:** `work_centers.php:91`

```php
static $checked = [];
$hash = spl_object_hash($db);
if (isset($checked[$hash])) {
    return;
}
```

**✅ ปลอดภัย:** ใช้ `spl_object_hash($db)` เป็น key → แต่ละ connection object มี hash แยกกัน

---

### 5. `fetch_org_by_code()` / `fetch_org_by_domain()` - Organization Lookup
**File:** `config.php:379-410`

```php
function fetch_org_by_code(string $code): ?array {
    $db = core_db();
    // ... query from core_db() ...
}
```

**✅ ปลอดภัย:** ไม่มี cache, query จาก core_db() ทุกครั้ง

---

## ⚠️ **ต้องแก้ไข (Needs Fix)**

### 1. `columnExists()` - Column Existence Cache
**File:** `source/pwa_scan_api.php:1348`

```php
function columnExists($db, $table, $column) {
    static $cache = [];
    $cacheKey = "{$table}.{$column}";  // ❌ ไม่มี tenant code!
    
    if (isset($cache[$cacheKey])) {
        return $cache[$cacheKey];
    }
    // ...
}
```

**🐛 ปัญหา:**
- Cache key ไม่รวม tenant code
- ถ้า tenant A และ B มี table structure เหมือนกัน → อาจใช้ cache ผิด
- **ความเสี่ยง:** ต่ำ (column existence ไม่ใช่ข้อมูล sensitive)

**✅ วิธีแก้:**
```php
function columnExists($db, $table, $column) {
    static $cache = [];
    
    // เพิ่ม tenant code ใน cache key
    $org = resolve_current_org();
    $tenantCode = $org['code'] ?? 'unknown';
    $cacheKey = "{$tenantCode}.{$table}.{$column}";
    
    if (isset($cache[$cacheKey])) {
        return $cache[$cacheKey];
    }
    // ...
}
```

---

### 2. `Idempotency::guard()` - Idempotency Response Cache
**File:** `source/BGERP/Helper/Idempotency.php:28`

```php
public static function guard(?string $key, string $action = 'create'): ?array
{
    // ...
    $file = $storageDir . '/' . md5($key) . '.json';  // ❌ ไม่มี tenant code!
    
    if (file_exists($file)) {
        $cached = json_decode(file_get_contents($file), true);
        // Return cached response...
    }
}
```

**🐛 ปัญหา:**
- Filename ไม่รวม tenant code
- ถ้า tenant A และ B ใช้ idempotency key เดียวกัน → อาจได้ response ผิด
- **ความเสี่ยง:** สูง (อาจ return ข้อมูล tenant อื่น)

**✅ วิธีแก้:**
```php
public static function guard(?string $key, string $action = 'create'): ?array
{
    if (empty($key)) {
        return null;
    }
    
    // เพิ่ม tenant code ใน filename
    $org = resolve_current_org();
    $tenantCode = $org['code'] ?? 'unknown';
    $storageDir = __DIR__ . '/../../storage/idempotency/' . $tenantCode;
    if (!is_dir($storageDir)) {
        mkdir($storageDir, 0755, true);
    }
    
    $file = $storageDir . '/' . md5($key) . '.json';
    // ...
}
```

---

## 🔍 **การตรวจสอบเพิ่มเติม**

### Static Variables ที่ไม่เกี่ยวกับ Tenant
- `core_db()` - `static $core_conn` → ปลอดภัย (core DB ไม่ใช่ tenant-specific)
- `ensure_database_exists()` - `static $checked` → ปลอดภัย (database creation check)
- `Metrics::*` - Static methods → ปลอดภัย (metrics ไม่มี tenant context)

---

## 📊 **สรุป**

| Category | Count | Status |
|----------|-------|--------|
| ✅ Safe | 5 | No action needed |
| ⚠️ Needs Fix | 2 | Fix required |
| 🔍 Review | 0 | - |

---

## 🎯 **Action Items**

1. **Fix `columnExists()` cache key** (Low Priority)
   - เพิ่ม tenant code ใน cache key
   - Risk: Low (column existence ไม่ใช่ข้อมูล sensitive)

2. **Fix `Idempotency::guard()` storage path** (High Priority)
   - แยก storage directory ตาม tenant
   - Risk: High (อาจ return ข้อมูล tenant อื่น)

---

## 📝 **Notes**

- การแก้ไข `tenant_db()` ให้ส่ง `$org['code']` ชัดเจนช่วยลดความเสี่ยงได้มาก
- Static cache ใน PHP 8.2 มี behavior ที่ aggressive กว่า PHP 7.4 → ต้องระวัง
- ควรตรวจสอบ cache ทุกครั้งที่มีการเพิ่ม static variable ใหม่

---

**Last Updated:** 2025-11-XX  
**Next Review:** 2026-01-XX

