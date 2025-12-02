# 🚀 Bellavier ERP - API Development Guide

**Version:** 1.6 (Enterprise+ Edition)  
**Date:** November 8, 2025, 23:30 ICT  
**Last Updated:** November 8, 2025, 23:50 ICT  
**Purpose:** คู่มือการพัฒนา API ตามมาตรฐาน Enterprise ของ Bellavier ERP  
**Reference:** `source/api_template.php` - Template มาตรฐานสำหรับ API ทั้งระบบ  
**Changes in v1.6:** Added Naming Convention, Security & Concurrency Guard, PSR-4 Verification, and Commit Policy sections

---

## 📑 Table of Contents

- [Quick Start](#quick-start)
- [Developer Lifecycle Example](#developer-lifecycle-example)
- [Folder & Naming Convention](#folder--naming-convention)
- [Complete Template Structure](#complete-template-structure)
- [Step-by-Step Implementation](#step-by-step-implementation)
- [Integration with PSR-4 Service Layer](#integration-with-psr-4-service-layer)
- [Enterprise Features Checklist](#enterprise-features-checklist)
- [Common Patterns](#common-patterns)
- [Best Practices](#best-practices)
- [Security Standards](#security-standards)
- [Error Code Policy](#error-code-policy)
- [Performance & Observability Tips](#performance--observability-tips)
- [Troubleshooting](#troubleshooting)
- [Version Policy](#version-policy)

---

## 🎯 Quick Start

**Before writing ANY API:**
1. ✅ Copy `source/api_template.php` as starting point
2. ✅ Replace `example` with your module name
3. ✅ Follow this guide step-by-step
4. ✅ Test syntax: `php -l source/your_api.php`
5. ✅ Test via browser

**Reference Template:** `source/api_template.php` (184 lines, Enterprise-ready)

---

## 🧠 Developer Lifecycle Example

**Complete workflow for creating a new API from scratch:**

### 1️⃣ Create New File

```bash
# Copy template
cp source/api_template.php source/product.php

# Or create manually using template as reference
```

### 2️⃣ Edit Placeholders

**Replace all occurrences:**
- `example` → `product`
- `Example` → `Product`
- `EX_` → `PROD_` (in app_code)

**Update permissions:**
```php
@permission product.view, product.manage
```

**Update SQL statements:**
```php
// Replace table_name with actual table
"SELECT * FROM product WHERE id = ?"
```

**Update validation rules:**
```php
$validation = RequestValidator::make($_POST, [
    'sku' => 'required|string|max:50',
    'name' => 'required|string|max:255',
    'price' => 'nullable|float|min:0'
]);
```

### 3️⃣ Test Locally

```bash
# Syntax check
php -l source/product.php

# Test via PHP built-in server (optional)
php -S localhost:8000 -t source/
```

### 4️⃣ Review & Verify

**Check Headers:**
- ✅ `X-Correlation-Id` present
- ✅ `X-AI-Trace` present with execution_ms
- ✅ `Content-Type` set correctly

**Test with Postman/curl:**
```bash
# Test create with Idempotency-Key
curl -X POST http://localhost:8888/source/product.php \
  -H "Idempotency-Key: test-key-123" \
  -H "Content-Type: application/json" \
  -d '{"sku":"TEST001","name":"Test Product"}'

# Test get with ETag
curl -I http://localhost:8888/source/product.php?action=get&id=1

# Test update with If-Match
curl -X POST http://localhost:8888/source/product.php \
  -H "If-Match: \"abc123\"" \
  -d '{"id":1,"name":"Updated Name"}'
```

**Verify Error Responses:**
- ✅ All errors have `app_code`
- ✅ HTTP status codes correct (400, 404, 409, 500)
- ✅ Error messages generic (no DB details exposed)

### 5️⃣ Submit for Review

- [ ] All checklist items completed
- [ ] Syntax check passed
- [ ] Tested via browser
- [ ] Error responses verified
- [ ] Headers verified

---

## 📦 Folder & Naming Convention

**Standard directory structure for Bellavier ERP:**

| Type | Location | Naming Pattern | Example |
|------|----------|---------------|---------|
| **API endpoints** | `source/` | `snake_case.php` | `product.php`, `routing.php`, `work_centers.php` |
| **Service classes** | `source/BGERP/Service/` | `PascalCase` + `Service` | `ProductService.php`, `BOMService.php` |
| **Models** | `source/BGERP/Model/` | `PascalCase` + `Model` | `WorkOrderModel.php` (future) |
| **Helpers** | `source/BGERP/Helper/` | `PascalCase` | `RateLimiter.php`, `DatabaseHelper.php` |
| **Exceptions** | `source/BGERP/Exception/` | `PascalCase` + `Exception` | `ValidationException.php` |
| **Config files** | `source/BGERP/Config/` | `PascalCase.php` | `OperatorRoleConfig.php` |
| **Documentation** | `docs/` | `UPPER_SNAKE_CASE.md` | `API_DEVELOPMENT_GUIDE.md` |
| **Page definitions** | `page/` | `snake_case.php` | `product.php`, `work_centers.php` |
| **Views (HTML)** | `views/` | `snake_case.php` | `product.php`, `work_centers.php` |
| **JavaScript** | `assets/javascripts/{module}/` | `snake_case.js` | `product.js`, `job_ticket.js` |

**Key Rules:**
- ✅ API files: `snake_case.php` in `source/`
- ✅ Service classes: `PascalCase` in `source/BGERP/Service/`
- ✅ Use PSR-4 autoloading for all classes
- ✅ Config classes: `PascalCase.php` in `source/BGERP/Config/` (PSR-4 compliant)
- ✅ Documentation: `UPPER_SNAKE_CASE.md` in `docs/`

---

## 📋 Complete Template Structure

### File Header (Docblock)

```php
<?php
/**
 * [Module Name] API
 * 
 * Purpose: [Brief description of what this API does]
 * Features:
 * - Feature 1
 * - Feature 2
 * - Feature 3
 * 
 * @package Bellavier Group ERP
 * @version 1.0
 * @lifecycle runtime
 * @tenant_scope true
 * @permission [module].view, [module].manage
 * @author Development Team
 * @since 2025-11-08
 * 
 * CRITICAL INVARIANTS:
 * - [Important business rule 1]
 * - [Important business rule 2]
 * 
 * Multi-tenant Notes:
 * - All queries scoped to current tenant DB
 * - [Any cross-DB considerations]
 */
```

### Required Includes

```php
session_start();
require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/global_function.php';
require_once __DIR__ . '/model/member_class.php';
require_once __DIR__ . '/permission.php';
```

### Enterprise Helper Imports

```php
use BGERP\Helper\DatabaseHelper;
use BGERP\Helper\RateLimiter;
use BGERP\Helper\RequestValidator;
use BGERP\Helper\Idempotency;
```

### Initialization Block

```php
// --- Initialize ----------------------------------------------------
$__t0 = microtime(true);  // Execution timer
$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
header('X-Correlation-Id: ' . $cid);
```

### Authentication Block

```php
// --- Auth ----------------------------------------------------------
$objMemberDetail = new memberDetail();
$member = $objMemberDetail->thisLogin();
if (!$member) {
    json_error('unauthorized', 401, ['app_code' => 'AUTH_401_UNAUTHORIZED']);
}
```

### Maintenance Mode Check

```php
// --- Maintenance ---------------------------------------------------
if (file_exists(__DIR__ . '/../storage/maintenance.flag')) {
    header('Retry-After: 60');
    json_error('service_unavailable', 503, ['app_code' => 'CORE_503_MAINT']);
}
```

### Rate Limiting

```php
// --- Rate Limiting -------------------------------------------------
RateLimiter::check($member, 120, 60, 'module_name');
// Parameters: $member, $maxRequests, $windowSeconds, $endpoint
```

### Core Setup

```php
// --- Core Setup ----------------------------------------------------
$tenantDb = tenant_db();
$db = new DatabaseHelper($tenantDb);
$action = $_REQUEST['action'] ?? '';
$aiTrace = [
    'module' => basename(__FILE__, '.php'),
    'action' => $action,
    'tenant' => $member['id_org'] ?? 0,
    'user_id' => $member['id_member'] ?? 0,
    'timestamp' => gmdate('c'),
    'request_id' => $cid
];
```

### Service Auto-Binding (Recommended)

**Service Class Auto-Binding** automatically binds API file names to Service classes using PSR-4 naming convention.

**Examples:**
- `source/example.php` → `BGERP\Service\ExampleService`
- `source/work_center.php` → `BGERP\Service\WorkCenterService`
- `source/qc_rework.php` → `BGERP\Service\QcReworkService`

```php
use BGERP\Service\ServiceFactory;

// --- Service Auto-Binding ------------------------------------------
// Automatically binds API file name to Service class
try {
    $service = ServiceFactory::fromApiFile(__FILE__, $tenantDb, (int)($member['id_org'] ?? 0));
} catch (\RuntimeException $e) {
    // Service not found - fallback to manual implementation or throw error
    error_log(sprintf('[CID:%s][%s] Service auto-binding failed: %s', $cid, basename(__FILE__), $e->getMessage()));
    json_error('service_unavailable', 503, ['app_code' => 'CORE_503_SERVICE_NOT_FOUND']);
}
```

**Benefits:**
- ✅ No manual service instantiation needed
- ✅ Consistent naming convention (snake_case → PascalCase)
- ✅ Type-safe service access
- ✅ Easy to test (mock service class)

**Note:** If service class doesn't exist, API will return 503. Create the service class first or handle gracefully.

**See Also:** [Integration with PSR-4 Service Layer](#integration-with-psr-4-service-layer) for complete service implementation guide.

### Action Router (Switch Statement)

```php
// ===================================================================
// ACTIONS
// ===================================================================
try {
    switch ($action) {
        // Actions here
    }
    
    // AI Trace (success)
    $aiTrace['execution_ms'] = (int)((microtime(true) - $__t0) * 1000);
    header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));
    
} catch (Throwable $e) {
    // Error handling
}
```

### Error Handling Block

```php
} catch (Throwable $e) {
    $aiTrace['error'] = $e->getMessage();
    $aiTrace['execution_ms'] = (int)((microtime(true) - $__t0) * 1000);
    header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));

    error_log(sprintf('[CID:%s][%s][User:%d][Action:%s] %s',
        $cid, basename(__FILE__), $member['id_member'] ?? 0, $action, $e->getMessage()
    ));

    json_error('internal_error', 500, ['app_code' => 'MODULE_500_INTERNAL']);
}
```

---

## 🔧 Step-by-Step Implementation

### 1. List Action (Read-Only)

```php
case 'list':
    must_allow_code($member, 'module.view');

    $rows = $db->fetchAll(
        "SELECT id, code, name, is_active FROM table_name ORDER BY id DESC"
    );
    header('Content-Type: application/json; charset=utf-8');
    json_success(['data' => $rows]);
    break;
```

**Key Points:**
- ✅ Use `DatabaseHelper::fetchAll()` for SELECT queries
- ✅ Set `Content-Type` header explicitly (not in global header)
- ✅ Use `must_allow_code()` for permission check
- ✅ Return via `json_success()`

### 2. Get Action (Single Record)

```php
case 'get':
    must_allow_code($member, 'module.view');
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        json_error('missing_id', 400, ['app_code' => 'MODULE_400_MISSING_ID']);
    }

    $row = $db->fetchOne("SELECT * FROM table_name WHERE id = ?", [$id], 'i');
    if (!$row) {
        json_error('not_found', 404, ['app_code' => 'MODULE_404_NOT_FOUND']);
    }

    // ETag for concurrency control
    $etag = md5(json_encode($row));
    header('ETag: "' . $etag . '"');
    header('Cache-Control: private, max-age=30');
    
    json_success(['data' => $row]);
    break;
```

**Key Points:**
- ✅ Validate ID input
- ✅ Return 404 if not found
- ✅ Generate ETag for concurrency control
- ✅ Add Cache-Control header

### 3. Create Action (POST)

```php
case 'create':
    must_allow_code($member, 'module.manage');

    // Idempotency check
    $key = $_SERVER['HTTP_IDEMPOTENCY_KEY'] ?? null;
    $cached = Idempotency::guard($key, 'create');
    if ($cached !== null) return;

    // Centralized validation
    $validation = RequestValidator::make($_POST, [
        'code' => 'required|string|max:50',
        'name' => 'required|string|max:255',
        'description' => 'nullable|string|max:500'
    ]);

    if (!$validation['valid']) {
        $firstError = $validation['errors'][0] ?? null;
        json_error($firstError['message'] ?? 'validation_failed', 400, [
            'app_code' => $firstError['app_code'] ?? 'MODULE_400_VALIDATION',
            'errors' => $validation['errors']
        ]);
    }

    $data = $validation['data'];
    
    // Database operation
    $stmt = $tenantDb->prepare("INSERT INTO table_name (code, name, description) VALUES (?, ?, ?)");
    if (!$stmt) {
        json_error('db_operation_failed', 500, ['app_code' => 'MODULE_500_PREPARE']);
    }
    $stmt->bind_param('sss', $data['code'], $data['name'], $data['description'] ?? '');
    
    if (!$stmt->execute()) {
        $errno = $stmt->errno ?? 0;
        $stmt->close();
        
        // Handle duplicate key (MySQL error 1062)
        if ($errno === 1062) {
            json_error('duplicate_entry', 409, ['app_code' => 'MODULE_409_DUP']);
        }
        
        json_error('db_operation_failed', 500, ['app_code' => 'MODULE_500_EXECUTE']);
    }

    $id = $stmt->insert_id;
    $stmt->close();

    // Store idempotency response
    if ($key) {
        Idempotency::store($key, ['id' => $id], 201);
    }
    
    // REST compliance: 201 Created with Location header
    header('Location: /source/module.php?action=get&id=' . $id);
    json_success(['id' => $id], 201);
    break;
```

**Key Points:**
- ✅ Idempotency guard before operation
- ✅ Use `RequestValidator::make()` for validation
- ✅ Use `$stmt->errno` (not `$tenantDb->error`) for error checking
- ✅ Handle duplicate key (1062) → 409 Conflict
- ✅ Return 201 Created with Location header
- ✅ Store idempotency response after success

### 4. Update Action (PUT/PATCH)

```php
case 'update':
    must_allow_code($member, 'module.manage');

    // Centralized validation
    $validation = RequestValidator::make($_POST, [
        'id' => 'required|integer|min:1',
        'name' => 'required|string|max:255',
        'description' => 'nullable|string|max:500'
    ]);
    
    if (!$validation['valid']) {
        $firstError = $validation['errors'][0] ?? null;
        json_error($firstError['message'] ?? 'validation_failed', 400, [
            'app_code' => $firstError['app_code'] ?? 'MODULE_400_VALIDATION',
            'errors' => $validation['errors']
        ]);
    }
    
    $data = $validation['data'];

    // ETag / If-Match check for concurrency control
    $current = $db->fetchOne("SELECT * FROM table_name WHERE id=?", [$data['id']], 'i');
    if (!$current) {
        json_error('not_found', 404, ['app_code' => 'MODULE_404_NOT_FOUND']);
    }
    
    $currentEtag = md5(json_encode($current));
    if (!empty($_SERVER['HTTP_IF_MATCH']) && $_SERVER['HTTP_IF_MATCH'] !== '"' . $currentEtag . '"') {
        json_error('version_conflict', 409, ['app_code' => 'MODULE_409_VER']);
    }

    // Database operation
    $stmt = $tenantDb->prepare("UPDATE table_name SET name=?, description=? WHERE id=?");
    if (!$stmt) {
        json_error('db_operation_failed', 500, ['app_code' => 'MODULE_500_PREPARE']);
    }
    $stmt->bind_param('ssi', $data['name'], $data['description'] ?? '', $data['id']);
    
    if (!$stmt->execute()) {
        $errno = $stmt->errno ?? 0;
        $stmt->close();
        json_error('db_operation_failed', 500, ['app_code' => 'MODULE_500_EXECUTE']);
    }
    $stmt->close();
    
    json_success();
    break;
```

**Key Points:**
- ✅ Validate input with `RequestValidator`
- ✅ Fetch current record for ETag comparison
- ✅ Check `If-Match` header for concurrency control
- ✅ Return 409 Conflict if version mismatch
- ✅ Use `$stmt->errno` for error checking

### 5. Delete Action (DELETE)

```php
case 'delete':
    must_allow_code($member, 'module.manage');

    // Centralized validation
    $validation = RequestValidator::make($_POST, ['id' => 'required|integer|min:1']);
    if (!$validation['valid']) {
        $firstError = $validation['errors'][0] ?? null;
        json_error($firstError['message'] ?? 'validation_failed', 400, [
            'app_code' => $firstError['app_code'] ?? 'MODULE_400_VALIDATION',
            'errors' => $validation['errors']
        ]);
    }

    $data = $validation['data'];
    
    // ETag / If-Match check (optional but recommended)
    $current = $db->fetchOne("SELECT * FROM table_name WHERE id=?", [$data['id']], 'i');
    if (!$current) {
        json_error('not_found', 404, ['app_code' => 'MODULE_404_NOT_FOUND']);
    }
    
    $currentEtag = md5(json_encode($current));
    if (!empty($_SERVER['HTTP_IF_MATCH']) && $_SERVER['HTTP_IF_MATCH'] !== '"' . $currentEtag . '"') {
        json_error('version_conflict', 409, ['app_code' => 'MODULE_409_VER']);
    }

    // Soft delete (recommended) or hard delete
    $stmt = $tenantDb->prepare("UPDATE table_name SET is_active=0 WHERE id=?");
    // OR: $stmt = $tenantDb->prepare("DELETE FROM table_name WHERE id=?");
    
    if (!$stmt) {
        json_error('db_operation_failed', 500, ['app_code' => 'MODULE_500_PREPARE']);
    }
    $stmt->bind_param('i', $data['id']);
    
    if (!$stmt->execute()) {
        $errno = $stmt->errno ?? 0;
        $stmt->close();
        json_error('db_operation_failed', 500, ['app_code' => 'MODULE_500_EXECUTE']);
    }
    $stmt->close();
    
    json_success();
    break;
```

**Key Points:**
- ✅ Validate input
- ✅ Check ETag/If-Match for concurrency control
- ✅ Prefer soft-delete (`is_active=0`) over hard delete
- ✅ Use `$stmt->errno` for error checking

### 6. Default Case (Unknown Action)

```php
default:
    json_error('unknown_action', 400, ['app_code' => 'MODULE_400_UNKNOWN']);
```

---

## ✅ Enterprise Features Checklist

### Mandatory Features (All APIs)

- [ ] **Comprehensive Docblock** - Purpose, Features, CRITICAL INVARIANTS
- [ ] **PSR-4 Autoloading** - `require_once __DIR__ . '/../vendor/autoload.php';`
- [ ] **Correlation ID** - `X-Correlation-Id` header
- [ ] **AI Trace** - `X-AI-Trace` header with execution_ms
- [ ] **Authentication** - `$objMemberDetail->thisLogin()`
- [ ] **Maintenance Mode** - Check `storage/maintenance.flag`
- [ ] **Rate Limiting** - `RateLimiter::check()`
- [ ] **Top-level Try-Catch** - Wrap switch statement
- [ ] **Standardized Error Handling** - Use `json_error()` with `app_code`
- [ ] **Execution Time Tracking** - Update AI-Trace with `execution_ms`

### Write Operations (Create/Update/Delete)

- [ ] **RequestValidator** - Use `RequestValidator::make()` for all inputs
- [ ] **Idempotency** - For create operations (guard + store)
- [ ] **ETag/If-Match** - For update/delete operations
- [ ] **Error Code Mapping** - Use `$stmt->errno` (not `$tenantDb->error`)
- [ ] **Duplicate Handling** - Map MySQL 1062 → 409 Conflict
- [ ] **201 Created** - Return 201 with Location header for create

### Read Operations (List/Get)

- [ ] **DatabaseHelper** - Use `DatabaseHelper::fetchAll()` / `fetchOne()`
- [ ] **ETag Header** - Generate ETag for get operations
- [ ] **Cache-Control** - Add `Cache-Control: private, max-age=30`
- [ ] **Content-Type** - Set `Content-Type: application/json` explicitly

### Export Operations (CSV/Excel/PDF)

- [ ] **Content-Type** - Set appropriate Content-Type (text/csv, application/pdf, etc.)
- [ ] **Content-Disposition** - Set filename in header
- [ ] **Exit After Output** - Use `exit;` after output (don't continue)

### Naming Convention Enforcement

- [ ] **File Name** - ต้องเป็น `snake_case` (`*_api.php`)
- [ ] **Class Name** - ต้องเป็น `PascalCase` และ prefix ด้วย `BGERP\Service\`
- [ ] **Standard Variables** - `$member`, `$db`, `$action` ต้องมีทุกไฟล์ (standard scope)
- [ ] **Error Codes** - ใช้ pattern: `MODULE_ERRCODE_DESCRIPTION` (เช่น `DAG_400_VALIDATION`, `TEAM_404_NOT_FOUND`)

### Security & Concurrency Guard

- [ ] **Auth Check** - ตรวจสอบ auth ทุกครั้งก่อนทำงาน (ผ่าน `$member`)
- [ ] **Idempotency-Key** - ใช้สำหรับ create ทุกจุด
- [ ] **ETag/If-Match** - ใช้สำหรับ update ทุกจุด
- [ ] **Audit Logging** - Log IP + user agent ลงใน audit_log (ถ้ามี audit system)

### PSR-4 Verification

- [ ] **Autoload Rebuild** - Run `composer dump-autoload -o` หลังเพิ่ม service class
- [ ] **Namespace Check** - ตรวจสอบการ import namespace (case-sensitive)
- [ ] **Class Loading Test** - Confirm service class โหลดผ่าน autoload ได้จริง (ทดสอบด้วย `class_exists()`)

### Refactor Commit Policy

- [ ] **One File Per Commit** - Commit แยก 1 ไฟล์ต่อ 1 commit
- [ ] **Commit Message** - Format: `refactor(api): migrate {filename} to enterprise`
- [ ] **Branch Strategy** - Push ไป branch: `feature/api-enterprise-refactor` (ถ้าใช้ Git workflow)

---

## 🧩 Integration with PSR-4 Service Layer

**Purpose:** แยก business logic ออกจาก API controller เพื่อให้ code สะอาด, testable, และ maintainable

### Architecture Pattern

```
API Controller (source/product.php)
    ↓ (auto-binds via ServiceFactory)
Service Layer (source/BGERP/Service/ProductService.php)
    ↓ (extends BaseService)
BaseService (source/BGERP/Service/BaseService.php)
    ↓ (uses)
Database Helper (source/BGERP/Helper/DatabaseHelper.php)
```

### Service Class Auto-Binding

**New in Version 1.5:** Use `ServiceFactory::fromApiFile()` to automatically bind API files to Service classes.

**Naming Convention:**
- API file: `source/example.php` → Service class: `BGERP\Service\ExampleService`
- API file: `source/work_center.php` → Service class: `BGERP\Service\WorkCenterService`
- API file: `source/qc_rework.php` → Service class: `BGERP\Service\QcReworkService`

**How It Works:**
1. Extract base filename (remove `.php` extension)
2. Convert snake_case/kebab-case to PascalCase
3. Append `Service` suffix
4. Resolve to `BGERP\Service\{Name}Service`
5. Instantiate and return service instance

**Example Usage:**
```php
use BGERP\Service\ServiceFactory;

// In API file (source/example.php)
$service = ServiceFactory::fromApiFile(__FILE__, $tenantDb, $tenantId);

// Use service methods
$rows = $service->list();
$item = $service->get($id);
$id = $service->create($code, $name, $desc);
```

### Service Class Structure

**Location:** `source/BGERP/Service/[ModuleName]Service.php`

**Base Service Class:**
All service classes should extend `BaseService` which provides:
- Database connection (`$this->db`)
- Tenant ID (`$this->tenantId`)
- Transaction helper (`$this->tx()`)

**Example:**
```php
<?php
namespace BGERP\Service;

class ProductService extends BaseService
{
    /**
     * Constructor (inherits from BaseService)
     * 
     * @param \mysqli $tenantDb Tenant database connection
     * @param int $tenantId Tenant ID (optional)
     */
    public function __construct(\mysqli $tenantDb, int $tenantId = 0)
    {
        parent::__construct($tenantDb, $tenantId);
    }

    /**
     * Create a new product
     * @param array $data Validated data
     * @return int New product ID
     * @throws \Exception On failure
     */
    public function create(array $data): int
    {
        $stmt = $this->db->prepare("INSERT INTO product (sku, name, price) VALUES (?, ?, ?)");
        if (!$stmt) {
            throw new \Exception('Failed to prepare statement');
        }
        $stmt->bind_param('ssd', $data['sku'], $data['name'], $data['price'] ?? 0);
        if (!$stmt->execute()) {
            $stmt->close();
            throw new \Exception('Failed to create product');
        }
        $id = $stmt->insert_id;
        $stmt->close();
        return $id;
    }

    /**
     * Get product by ID
     * @param int $id Product ID
     * @return array|null Product data or null if not found
     */
    public function getById(int $id): ?array
    {
        return $this->dbHelper->fetchOne(
            "SELECT * FROM product WHERE id_product = ?",
            [$id],
            'i'
        );
    }

    /**
     * List all products
     * @param array $filters Optional filters
     * @return array List of products
     */
    public function list(array $filters = []): array
    {
        $sql = "SELECT * FROM product WHERE is_active = 1";
        $params = [];
        $types = '';

        if (!empty($filters['search'])) {
            $sql .= " AND (sku LIKE ? OR name LIKE ?)";
            $search = '%' . $filters['search'] . '%';
            $params[] = $search;
            $params[] = $search;
            $types .= 'ss';
        }

        $sql .= " ORDER BY id_product DESC LIMIT 100";

        return $this->dbHelper->fetchAll($sql, $params, $types);
    }
}
```

### API Controller Integration

**In API file (`source/product.php`):**

```php
use BGERP\Service\ServiceFactory;

// Auto-bind service from API file name
// source/product.php → BGERP\Service\ProductService
try {
    $service = ServiceFactory::fromApiFile(__FILE__, $tenantDb, (int)($member['id_org'] ?? 0));
} catch (\RuntimeException $e) {
    error_log(sprintf('[CID:%s][%s] Service auto-binding failed: %s', $cid, basename(__FILE__), $e->getMessage()));
    json_error('service_unavailable', 503, ['app_code' => 'CORE_503_SERVICE_NOT_FOUND']);
}

// In create action
case 'create':
    must_allow_code($member, 'product.manage');
    
    // Idempotency check
    $key = $_SERVER['HTTP_IDEMPOTENCY_KEY'] ?? null;
    $cached = Idempotency::guard($key, 'create');
    if ($cached !== null) return;
    
    // Validation
    $validation = RequestValidator::make($_POST, [
        'sku' => 'required|string|max:50',
        'name' => 'required|string|max:255',
        'price' => 'nullable|float|min:0'
    ]);
    
    if (!$validation['valid']) {
        $firstError = $validation['errors'][0] ?? null;
        json_error($firstError['message'] ?? 'validation_failed', 400, [
            'app_code' => $firstError['app_code'] ?? 'PROD_400_VALIDATION',
            'errors' => $validation['errors']
        ]);
    }
    
    // Delegate to service
    try {
        $id = $service->create(
            $validation['data']['sku'],
            $validation['data']['name'],
            $validation['data']['price'] ?? 0.0
        );
        
        // Store idempotency response
        if ($key) {
            Idempotency::store($key, ['id_product' => $id], 201);
        }
        
        header('Location: /source/product.php?action=get&id=' . $id);
        json_success(['id_product' => $id], 201);
    } catch (\Exception $e) {
        error_log("ProductService::create failed: " . $e->getMessage());
        json_error('db_operation_failed', 500, ['app_code' => 'PROD_500_CREATE']);
    }
    break;
```

### Benefits

**✅ Separation of Concerns:**
- API controller handles: routing, auth, validation, response formatting
- Service layer handles: business logic, data access, complex operations

**✅ Testability:**
- Service classes can be unit tested independently
- Mock database connections easily

**✅ Reusability:**
- Service methods can be called from multiple APIs
- CLI scripts can use same services

**✅ Maintainability:**
- Business logic changes don't affect API structure
- Easier to refactor and optimize

### When to Create a Service Class

**✅ Create Service Class When:**
- Business logic is complex (> 50 lines)
- Logic is reused in multiple places
- Need unit testing
- Complex calculations or transformations
- Multiple database operations in sequence

**❌ Don't Need Service Class When:**
- Simple CRUD operations (< 20 lines)
- Single database query
- No business logic (just pass-through)

---

## 🎨 Common Patterns

### Pattern 1: SSDT (Server-Side DataTables)

```php
case 'list':
    must_allow_code($member, 'module.view');
    require_once __DIR__ . '/utils/ssdt.php';
    
    $baseSql = "SELECT t.id, t.code, t.name, t.is_active FROM table_name t";
    $columns = [
        ['db' => 't.id', 'dt' => 'id', 'name' => 't.id'],
        ['db' => 't.code', 'dt' => 'code', 'name' => 't.code'],
        ['db' => 't.name', 'dt' => 'name', 'name' => 't.name'],
        ['db' => 't.is_active', 'dt' => 'is_active', 'name' => 't.is_active']
    ];
    
    $builder = new SSDTQueryBuilder($tenantDb, $baseSql, $columns);
    $builder->applyFilters();
    $builder->execute();
    $result = $builder->result();
    
    // Set Content-Type for SSDT response
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($result);
    break;
```

### Pattern 2: Cross-Database User Lookup

```php
// Step 1: Fetch from tenant DB
$tasks = $db->fetchAll("SELECT * FROM tenant_table WHERE condition = ?", [$param], 'i');

// Step 2: Extract user IDs
$userIds = array_filter(array_column($tasks, 'assigned_to'));

// Step 3: Fetch users from core DB
if (!empty($userIds)) {
    $coreDb = core_db();
    $placeholders = implode(',', array_fill(0, count($userIds), '?'));
    $types = str_repeat('i', count($userIds));
    $stmt = $coreDb->prepare("SELECT id_member, name FROM bgerp.account WHERE id_member IN ($placeholders)");
    $stmt->bind_param($types, ...$userIds);
    $stmt->execute();
    $users = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $userMap = array_column($users, 'name', 'id_member');
}

// Step 4: Merge
foreach ($tasks as &$task) {
    $task['assigned_name'] = $userMap[$task['assigned_to']] ?? null;
}
```

### Pattern 3: CSV Export

```php
case 'export_csv':
    must_allow_code($member, 'module.view');
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        json_error('missing_id', 400, ['app_code' => 'MODULE_400_MISSING_ID']);
    }
    
    $rows = $db->fetchAll("SELECT * FROM table_name WHERE id = ?", [$id], 'i');
    
    // Generate CSV
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="export_' . date('Ymd') . '.csv"');
    $output = fopen('php://output', 'w');
    fprintf($output, chr(0xEF).chr(0xBB).chr(0xBF)); // UTF-8 BOM
    
    // Headers
    fputcsv($output, ['Column1', 'Column2', 'Column3']);
    
    // Data
    foreach ($rows as $row) {
        fputcsv($output, [$row['col1'], $row['col2'], $row['col3']]);
    }
    
    fclose($output);
    exit;
```

---

## 🎯 Best Practices

### 1. Content-Type Header

**❌ DON'T:**
```php
header('Content-Type: application/json; charset=utf-8'); // At top of file
```

**✅ DO:**
```php
// Remove global Content-Type header
// Set per-action:
json_success(['data' => $rows]); // json_success() sets Content-Type automatically
// OR for SSDT:
header('Content-Type: application/json; charset=utf-8');
echo json_encode($result);
// OR for exports:
header('Content-Type: text/csv; charset=utf-8');
```

### 2. Error Handling

**❌ DON'T:**
```php
if (!$stmt->execute()) {
    json_error($tenantDb->error ?? 'failed', 500); // Wrong!
}
```

**✅ DO:**
```php
if (!$stmt->execute()) {
    $errno = $stmt->errno ?? 0; // Use statement errno
    $stmt->close();
    
    if ($errno === 1062) {
        json_error('duplicate_entry', 409, ['app_code' => 'MODULE_409_DUP']);
    }
    
    json_error('db_operation_failed', 500, ['app_code' => 'MODULE_500_EXECUTE']);
}
```

### 3. Validation

**❌ DON'T:**
```php
$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    json_error('missing_id', 400); // Manual validation
}
```

**✅ DO:**
```php
$validation = RequestValidator::make($_POST, [
    'id' => 'required|integer|min:1'
]);

if (!$validation['valid']) {
    $firstError = $validation['errors'][0] ?? null;
    json_error($firstError['message'] ?? 'validation_failed', 400, [
        'app_code' => $firstError['app_code'] ?? 'MODULE_400_VALIDATION',
        'errors' => $validation['errors']
    ]);
}

$data = $validation['data'];
$id = (int)$data['id'];
```

### 4. Idempotency

**❌ DON'T:**
```php
// No idempotency check
$stmt = $tenantDb->prepare("INSERT INTO ...");
$stmt->execute();
```

**✅ DO:**
```php
// Idempotency check
$key = $_SERVER['HTTP_IDEMPOTENCY_KEY'] ?? null;
$cached = Idempotency::guard($key, 'create');
if ($cached !== null) return;

// ... perform operation ...

// Store idempotency response
if ($key) {
    Idempotency::store($key, ['id' => $id], 201);
}
```

### 5. ETag/If-Match

**❌ DON'T:**
```php
// No concurrency control
$stmt = $tenantDb->prepare("UPDATE ...");
$stmt->execute();
```

**✅ DO:**
```php
// Fetch current record
$current = $db->fetchOne("SELECT * FROM table WHERE id=?", [$id], 'i');
if (!$current) {
    json_error('not_found', 404, ['app_code' => 'MODULE_404_NOT_FOUND']);
}

// Check ETag
$currentEtag = md5(json_encode($current));
if (!empty($_SERVER['HTTP_IF_MATCH']) && $_SERVER['HTTP_IF_MATCH'] !== '"' . $currentEtag . '"') {
    json_error('version_conflict', 409, ['app_code' => 'MODULE_409_VER']);
}

// Perform update
$stmt = $tenantDb->prepare("UPDATE ...");
$stmt->execute();
```

---

## 🔐 Security Standards

**All API endpoints must comply with enterprise-grade security controls:**

### Authentication & Session Security

**✅ DO:**
```php
// Regenerate session ID after login
session_regenerate_id(true);

// Set secure session cookies (in config.php or session handler)
ini_set('session.cookie_httponly', '1');
ini_set('session.cookie_secure', '1'); // HTTPS only in production
ini_set('session.cookie_samesite', 'Lax');
```

**❌ DON'T:**
```php
// Never expose session ID in URLs or logs
error_log("Session ID: " . session_id()); // WRONG!
```

### Input Validation & Sanitization

**✅ DO:**
```php
// Always use RequestValidator for user inputs
$validation = RequestValidator::make($_POST, [
    'email' => 'required|string|max:100',
    'amount' => 'required|float|min:0'
]);

// Use prepared statements for ALL database queries
$stmt = $tenantDb->prepare("SELECT * FROM table WHERE id = ?");
$stmt->bind_param('i', $id);
```

**❌ DON'T:**
```php
// Never use raw SQL with user input
$query = "SELECT * FROM table WHERE id = " . $_GET['id']; // SQL INJECTION RISK!

// Never trust user input
$name = $_POST['name']; // WRONG! Always validate first
```

### Error Message Security

**✅ DO:**
```php
// Return generic error messages
json_error('invalid_credentials', 401, ['app_code' => 'AUTH_401_UNAUTHORIZED']);

// Log detailed errors server-side only
error_log("Login failed for user: " . $username . " - Reason: " . $detailedReason);
```

**❌ DON'T:**
```php
// Never expose database errors to client
json_error($stmt->error, 500); // WRONG! Exposes DB structure

// Never expose system details
json_error("MySQL Error: " . $db->error, 500); // WRONG!
```

### Permission Checks

**✅ DO:**
```php
// Check permission for EVERY privileged action
case 'create':
    must_allow_code($member, 'module.manage'); // Required!
    // ... rest of code
```

**❌ DON'T:**
```php
// Never skip permission checks
case 'delete':
    // Missing permission check - SECURITY RISK!
    $stmt = $tenantDb->prepare("DELETE FROM table WHERE id=?");
```

### Sensitive Data Handling

**✅ DO:**
```php
// Mask sensitive data in logs
$maskedEmail = preg_replace('/(.{2})(.*)(@.*)/', '$1***$3', $email);
error_log("User email: " . $maskedEmail);

// Never log passwords or tokens
// (Don't log password fields at all)
```

**❌ DON'T:**
```php
// Never log sensitive data
error_log("Password: " . $_POST['password']); // CRITICAL SECURITY RISK!
error_log("API Key: " . $apiKey); // WRONG!
```

### SQL Injection Prevention

**✅ DO:**
```php
// Always use prepared statements
$stmt = $tenantDb->prepare("SELECT * FROM table WHERE id = ? AND name = ?");
$stmt->bind_param('is', $id, $name);
$stmt->execute();
```

**❌ DON'T:**
```php
// Never concatenate user input into SQL
$sql = "SELECT * FROM table WHERE id = " . $_GET['id']; // SQL INJECTION!
$sql = "SELECT * FROM table WHERE name = '" . $_POST['name'] . "'"; // SQL INJECTION!
```

### XSS Prevention

**✅ DO:**
```php
// Escape output in HTML context
echo htmlspecialchars($userInput, ENT_QUOTES, 'UTF-8');

// JSON encoding automatically escapes
json_success(['data' => $userInput]); // Safe
```

**❌ DON'T:**
```php
// Never output user input directly
echo $userInput; // XSS RISK!
echo "<div>" . $_POST['comment'] . "</div>"; // XSS RISK!
```

### Security Checklist

**Before deploying any API:**

- [ ] All user inputs validated with `RequestValidator`
- [ ] All database queries use prepared statements
- [ ] Permission checks on all privileged actions
- [ ] Generic error messages (no DB details exposed)
- [ ] Sensitive data masked in logs
- [ ] Session cookies secure (HttpOnly, Secure, SameSite)
- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities
- [ ] Rate limiting enabled
- [ ] Authentication required for all endpoints

---

## 📘 Error Code Policy

**Standardized error codes for consistent error handling across all APIs:**

| Error Type | HTTP Code | Example app_code | Description | When to Use |
|-------------|-----------|------------------|-------------|-------------|
| **Validation error** | 400 | `MODULE_400_VALIDATION` | Input invalid or missing required fields | Request validation fails |
| **Missing ID** | 400 | `MODULE_400_MISSING_ID` | Required ID parameter missing | ID not provided or invalid |
| **Unknown action** | 400 | `MODULE_400_UNKNOWN` | Action not recognized | Invalid action parameter |
| **Unauthorized** | 401 | `AUTH_401_UNAUTHORIZED` | Session expired or invalid | User not logged in |
| **Forbidden** | 403 | `AUTH_403_FORBIDDEN` | No permission for action | User lacks required permission |
| **Not found** | 404 | `MODULE_404_NOT_FOUND` | Resource not found | Record doesn't exist |
| **Duplicate entry** | 409 | `MODULE_409_DUP` | Duplicate key violation | Unique constraint violation (MySQL 1062) |
| **Version conflict** | 409 | `MODULE_409_VER` | ETag mismatch | Concurrent modification detected |
| **Prepare failed** | 500 | `MODULE_500_PREPARE` | SQL prepare statement failed | Database connection/prepare error |
| **Execute failed** | 500 | `MODULE_500_EXECUTE` | SQL execute failed | Query execution error |
| **Internal error** | 500 | `MODULE_500_INTERNAL` | Unhandled exception | Catch-all for unexpected errors |
| **Maintenance** | 503 | `CORE_503_MAINT` | System under maintenance | Maintenance flag exists |

### app_code Naming Convention

**Format:** `{MODULE}_{HTTP_CODE}_{TYPE}`

**Examples:**
- `PROD_400_VALIDATION` - Product module, validation error
- `BOM_409_DUP` - BOM module, duplicate entry
- `AUTH_401_UNAUTHORIZED` - Authentication module, unauthorized
- `CORE_503_MAINT` - Core system, maintenance mode

### Error Response Format

```json
{
  "ok": false,
  "error": "validation_failed",
  "app_code": "MODULE_400_VALIDATION",
  "meta": {
    "errors": [
      {
        "field": "email",
        "message": "Email is required",
        "app_code": "MODULE_400_EMAIL_REQUIRED"
      }
    ]
  }
}
```

### Error Code Mapping Table

**Database Errors → HTTP Codes:**

| MySQL Error Code | Error Type | HTTP Code | app_code Pattern |
|------------------|------------|-----------|------------------|
| 1062 | Duplicate entry | 409 | `MODULE_409_DUP` |
| 1452 | Foreign key constraint | 400 | `MODULE_400_FK` |
| 1048 | Column cannot be null | 400 | `MODULE_400_NULL` |
| 1054 | Unknown column | 500 | `MODULE_500_COLUMN` |
| 2006 | MySQL server gone | 503 | `CORE_503_DB` |

**Implementation:**
```php
if (!$stmt->execute()) {
    $errno = $stmt->errno ?? 0;
    $stmt->close();
    
    switch ($errno) {
        case 1062:
            json_error('duplicate_entry', 409, ['app_code' => 'MODULE_409_DUP']);
        case 1452:
            json_error('foreign_key_violation', 400, ['app_code' => 'MODULE_400_FK']);
        default:
            json_error('db_operation_failed', 500, ['app_code' => 'MODULE_500_EXECUTE']);
    }
}
```

---

## 🔍 Performance & Observability Tips

**Best practices for API performance and monitoring:**

### Execution Time Tracking

**✅ DO:**
```php
// Start timer at beginning
$__t0 = microtime(true);

// ... perform operations ...

// Update AI-Trace with execution time
$aiTrace['execution_ms'] = (int)((microtime(true) - $__t0) * 1000);
header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));
```

**Log slow operations:**
```php
$executionMs = (int)((microtime(true) - $__t0) * 1000);
if ($executionMs > 200) {
    error_log(sprintf('[SLOW][%s][%s] Execution time: %dms', 
        basename(__FILE__), $action, $executionMs));
}
```

### Query Optimization

**✅ DO:**
```php
// Use LIMIT for all list endpoints
$rows = $db->fetchAll(
    "SELECT * FROM table WHERE condition = ? ORDER BY id DESC LIMIT 100",
    [$param],
    'i'
);

// Use indexes (check DatabaseHelper uses indexes)
// Add WHERE clauses to filter early
```

**❌ DON'T:**
```php
// Never fetch all rows without limit
$rows = $db->fetchAll("SELECT * FROM large_table"); // WRONG! Could be millions of rows
```

### Caching Strategy

**✅ DO:**
```php
// Add Cache-Control headers for read operations
header('Cache-Control: private, max-age=30'); // 30 seconds cache

// For static data (UoM, categories), use longer cache
header('Cache-Control: private, max-age=300'); // 5 minutes cache
```

**Consider caching:**
- Master data (UoM, categories, work centers)
- User permissions (per session)
- Aggregated statistics (refresh every 5 min)

### Rate Limiting Strategy

**✅ DO:**
```php
// Global rate limit (applied to all endpoints)
RateLimiter::check($member, 120, 60, 'global'); // 120 req/min

// Endpoint-specific rate limit (for heavy operations)
RateLimiter::check($member, 10, 60, 'export_csv'); // 10 req/min for exports
```

### Database Connection Management

**✅ DO:**
```php
// Reuse tenant database connection
$tenantDb = tenant_db(); // Gets existing connection or creates new

// Use DatabaseHelper for SELECT queries (handles connection pooling)
$db = new DatabaseHelper($tenantDb);
```

### Monitoring & Logging

**✅ DO:**
```php
// Log all errors with context
error_log(sprintf('[CID:%s][%s][User:%d][Action:%s] %s',
    $cid, basename(__FILE__), $member['id_member'] ?? 0, $action, $e->getMessage()
));

// Log performance metrics
if ($executionMs > 100) {
    error_log(sprintf('[PERF][%s][%s] Slow query: %dms', 
        basename(__FILE__), $action, $executionMs));
}
```

### Performance Checklist

**Before deploying:**

- [ ] Execution time tracked in AI-Trace
- [ ] LIMIT clause on all list queries
- [ ] Cache-Control headers for read operations
- [ ] Rate limiting configured appropriately
- [ ] Slow queries logged (> 200ms)
- [ ] Database indexes verified
- [ ] No N+1 query problems
- [ ] Connection pooling used

---

## 🔍 Troubleshooting

### Issue: "Class 'BGERP\Helper\XXX' not found"

**Solution:**
```php
// Ensure autoload is included
require_once __DIR__ . '/../vendor/autoload.php';

// Use correct namespace
use BGERP\Helper\DatabaseHelper;
use BGERP\Helper\RateLimiter;
use BGERP\Helper\RequestValidator;
use BGERP\Helper\Idempotency;
```

### Issue: Content-Type header conflicts

**Solution:**
- Remove global `header('Content-Type: application/json')` from top
- Let `json_success()` / `json_error()` set it automatically
- Set explicitly only for SSDT or export actions

### Issue: RateLimiter not blocking requests

**Solution:**
- Ensure `RateLimiter::check()` is called BEFORE switch statement
- Don't wrap in try-catch (RateLimiter exits internally)
- Check Redis connection if using Redis backend

### Issue: ETag/If-Match not working

**Solution:**
- Ensure ETag is generated from complete row data
- ETag format must be: `"hash"` (with double quotes)
- Check `HTTP_IF_MATCH` header (not `HTTP_IF_MATCH_HEADER`)

### Issue: Idempotency not preventing duplicates

**Solution:**
- Ensure `Idempotency::guard()` is called BEFORE database operation
- Store response AFTER successful operation
- Use same idempotency key format consistently

---

## 📚 Related Documentation

- **`source/api_template.php`** - Complete template reference (184 lines)
- **`../API_STRUCTURE_AUDIT.md`** - Complete API standards playbook
- **`../ENTERPRISE_HELPERS_STATUS.md`** - Enterprise helpers integration status
- **`../API_ENTERPRISE_AUDIT_NOV2025.md`** - Compliance audit report
- **`README.md`** - Development Guides Index (this folder)

---

## ✅ Quick Checklist

**Before submitting API for review:**

- [ ] Syntax check: `php -l source/your_api.php`
- [ ] All Enterprise features implemented (checklist above)
- [ ] Tested via browser
- [ ] No hardcoded Thai strings (use `translate()`)
- [ ] Error messages have `app_code`
- [ ] All write operations use `RequestValidator`
- [ ] All create operations have Idempotency
- [ ] All update/delete operations have ETag/If-Match
- [ ] Content-Type set per-action (not globally)
- [ ] Execution time tracked in AI-Trace

---

---

## 📅 Version Policy

**Document version history and planned improvements:**

### Version 1.0 (November 8, 2025)
- ✅ Initial Enterprise Template Edition
- ✅ Complete template structure documentation
- ✅ Step-by-step implementation guide
- ✅ Enterprise features checklist
- ✅ Common patterns (SSDT, Cross-DB, CSV Export)
- ✅ Best practices (DO/DON'T examples)
- ✅ Troubleshooting guide

### Version 1.5 (November 8, 2025) - Current
- ✅ Added Security Standards section
- ✅ Added PSR-4 Service Layer integration guide
- ✅ Added Folder & Naming Convention reference
- ✅ Added Error Code Policy with taxonomy table
- ✅ Added Developer Lifecycle Example (complete workflow)
- ✅ Added Performance & Observability Tips
- ✅ Added Version Policy section

### Planned for Version 2.0
- 🔄 Integration with OpenAPI/Swagger Generator
- 🔄 Automated API documentation generation
- 🔄 API testing templates (PHPUnit integration)
- 🔄 GraphQL endpoint support (if needed)
- 🔄 Webhook/Event system documentation
- 🔄 API versioning strategy implementation

### Version Compatibility

**Current Template:** `source/api_template.php` v1.0  
**Compatible with:** PHP 8.2+, MySQL 8.0+  
**Standards:** PSR-4, REST, HTTP/1.1

---

**Last Updated:** November 8, 2025, 23:30 ICT  
**Template Version:** 1.5 (Enterprise+ Edition)  
**Document Status:** ✅ Production Ready - Suitable for external audit

