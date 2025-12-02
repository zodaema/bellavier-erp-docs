# Chapter 6 — API Development Guide

**Last Updated:** November 19, 2025  
**Purpose:** Teach developers how to build safe, standardized APIs  
**Audience:** Developers creating new API endpoints, AI agents modifying APIs

---

## Overview

This chapter provides a complete guide for developing API endpoints in the Bellavier Group ERP system. It covers standard structure, bootstrap usage, JSON format, security rules, and step-by-step instructions for adding new endpoints.

**Key Topics:**
- Standard API file structure
- Bootstrap usage (TenantApiBootstrap, CoreApiBootstrap)
- JSON output format (TenantApiOutput)
- Security rules (CSRF, rate limiting)
- Adding new endpoints (step-by-step)

**Standards:**
- ✅ All APIs use bootstrap layers
- ✅ All APIs return standardized JSON format
- ✅ All APIs have rate limiting
- ✅ All APIs have CSRF protection (state-changing operations)

---

## Key Concepts

### 1. Standard API Structure

**Every API file must follow this structure:**

```php
<?php
// 1. Autoloader
require_once __DIR__ . '/../vendor/autoload.php';

// 2. Bootstrap
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();
// OR
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init($mode);

// 3. Rate Limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'api_name', 'action', 120, 60);

// 4. Action Routing
$action = $_REQUEST['action'] ?? '';

try {
    switch ($action) {
        case 'action_name':
            // Permission check
            // Business logic
            // Output
            break;
        default:
            json_error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

### 2. When to Use Which Bootstrap

**TenantApiBootstrap:**
- ✅ Tenant-scoped operations
- ✅ Organization-specific data
- ✅ Requires tenant database
- ✅ Examples: `products.php`, `materials.php`, `dag_token_api.php`

**CoreApiBootstrap:**
- ✅ Platform-level operations
- ✅ Cross-tenant operations
- ✅ Requires core database
- ✅ Examples: `platform_dashboard_api.php`, `admin_org.php`

### 3. JSON Output Format

**Success Format:**
```json
{
  "ok": true,
  "data": {...},
  "meta": {
    "ai_trace": "...",
    "correlation_id": "..."
  }
}
```

**Error Format:**
```json
{
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Error message"
  }
}
```

**Output Methods:**
- `TenantApiOutput::success($data, $meta, $code)` - For tenant APIs
- `TenantApiOutput::error($message, $code, $extra)` - For tenant APIs
- `json_success($payload)` - Legacy/Platform APIs
- `json_error($message, $code, $extra)` - Legacy/Platform APIs

---

## Core Components

### TenantApiOutput

**Location:** `source/BGERP/Http/TenantApiOutput.php`  
**Namespace:** `BGERP\Http`  
**Status:** ✅ Created in Task 20

**Purpose:**
Ensures all tenant APIs return standardized JSON format.

**Key Methods:**

#### 1. Success Response

```php
TenantApiOutput::success($data, $meta = null, $code = 200): void
```

**Usage:**
```php
use BGERP\Http\TenantApiOutput;

TenantApiOutput::success(['products' => $products], null, 200);
```

**Output:**
```json
{
  "ok": true,
  "data": {"products": [...]},
  "meta": null
}
```

#### 2. Error Response

```php
TenantApiOutput::error($message, $code = null, $extra = null): void
```

**Usage:**
```php
use BGERP\Http\TenantApiOutput;

TenantApiOutput::error('Product not found', 404, ['product_id' => 123]);
```

**Output:**
```json
{
  "ok": false,
  "error": {
    "code": "404",
    "message": "Product not found",
    "product_id": 123
  }
}
```

#### 3. Start Output Buffer

```php
TenantApiOutput::startOutputBuffer(): void
```

**Usage:**
```php
use BGERP\Http\TenantApiOutput;

// At file start (after <?php)
TenantApiOutput::startOutputBuffer();
```

**Purpose:**
- Prevents whitespace/BOM before headers
- Catches accidental output
- Ensures clean JSON output

### Security Rules

#### 1. Rate Limiting

**All APIs must have rate limiting:**

```php
use BGERP\Helper\RateLimiter;

RateLimiter::check(
    $member['id_member'],  // User ID
    'api_name',            // Endpoint name
    'action_name',         // Action name
    120,                   // Limit (requests)
    60                     // Window (seconds)
);
```

**Configuration:**
- **Strict**: 10 req/60s (security-critical)
- **Standard**: 120 req/60s (normal operations)
- **Very Low**: 5 req/60s (migration operations)

#### 2. CSRF Protection

**State-changing operations must have CSRF protection:**

```php
// For POST/PUT/DELETE operations
if (!validateCsrfToken($_POST['csrf_token'] ?? '')) {
    json_error('invalid_csrf', 403);
}
```

**When to Apply:**
- ✅ POST operations (create, update)
- ✅ PUT operations (update)
- ✅ DELETE operations (delete)
- ❌ GET operations (read-only, no CSRF needed)

#### 3. Permission Checks

**All APIs must check permissions:**

```php
use BGERP\Security\PermissionHelper;

// Platform permission
if (!PermissionHelper::platform_has_permission($member, 'platform.health')) {
    json_error('forbidden', 403);
}

// Tenant permission
if (!PermissionHelper::hasOrgPermission($member, 'products.list')) {
    json_error('forbidden', 403);
}
```

---

## Adding New API Endpoints (Step-by-Step)

### Step 1: Choose Bootstrap

**Tenant API:**
```php
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();
```

**Platform API:**
```php
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init(['requirePlatformAdmin' => true]);
```

### Step 2: Add Rate Limiting

```php
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'api_name', 'action', 120, 60);
```

### Step 3: Add Permission Check

```php
use BGERP\Security\PermissionHelper;
if (!PermissionHelper::hasOrgPermission($member, 'module.resource.action')) {
    json_error('forbidden', 403);
}
```

### Step 4: Implement Action Logic

```php
$action = $_REQUEST['action'] ?? '';

try {
    switch ($action) {
        case 'list':
            // Business logic
            break;
        case 'create':
            // CSRF check
            if (!validateCsrfToken($_POST['csrf_token'] ?? '')) {
                json_error('invalid_csrf', 403);
            }
            // Business logic
            break;
        default:
            json_error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

### Step 5: Output Response

**Tenant API:**
```php
use BGERP\Http\TenantApiOutput;
TenantApiOutput::success($data, $meta, 200);
```

**Platform API:**
```php
json_success(['data' => $data]);
```

### Step 6: Add Integration Test

```php
namespace BellavierGroup\Tests\Integration\Api;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

class MyApiTest extends IntegrationTestCase
{
    public function testMyEndpoint(): void
    {
        $result = $this->runTenantApi('my_api.php', ['action' => 'test']);
        $response = $this->assertJsonResponse($result, 200);
        $this->assertTrue($response['ok']);
    }
}
```

### Step 7: Update Documentation

- Update API reference documentation
- Update endpoint list
- Document required permissions
- Document request/response format

---

## Examples

### Example 1: Tenant API (Complete)

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Bootstrap
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Start output buffer
use BGERP\Http\TenantApiOutput;
TenantApiOutput::startOutputBuffer();

// Rate limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'products', 'list', 120, 60);

// Permission check
use BGERP\Security\PermissionHelper;
if (!PermissionHelper::hasOrgPermission($member, 'products.list')) {
    TenantApiOutput::error('forbidden', 403);
    return;
}

// Action routing
$action = $_REQUEST['action'] ?? '';

try {
    switch ($action) {
        case 'list':
            $stmt = $tenantDb->prepare("SELECT * FROM products WHERE org_id=? AND deleted_at IS NULL");
            $stmt->bind_param('i', $org['id_org']);
            $stmt->execute();
            $products = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            
            TenantApiOutput::success(['data' => $products], null, 200);
            break;
            
        case 'create':
            // CSRF check
            if (!validateCsrfToken($_POST['csrf_token'] ?? '')) {
                TenantApiOutput::error('invalid_csrf', 403);
                return;
            }
            
            // Permission check
            if (!PermissionHelper::hasOrgPermission($member, 'products.create')) {
                TenantApiOutput::error('forbidden', 403);
                return;
            }
            
            // Validation
            $name = $_POST['name'] ?? '';
            if (empty($name)) {
                TenantApiOutput::error('name_required', 400);
                return;
            }
            
            // Insert
            $stmt = $tenantDb->prepare("INSERT INTO products (org_id, name, created_by) VALUES (?, ?, ?)");
            $stmt->bind_param('isi', $org['id_org'], $name, $member['id_member']);
            $stmt->execute();
            $productId = $tenantDb->insert_id;
            
            TenantApiOutput::success(['id' => $productId], null, 201);
            break;
            
        default:
            TenantApiOutput::error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error in products.php: " . $e->getMessage());
    TenantApiOutput::error('internal_error', 500);
}
```

### Example 2: Platform API (Complete)

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Bootstrap (platform admin mode)
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init([
    'requirePlatformAdmin' => true
]);

// Rate limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'platform_dashboard', 'summary', 120, 60);

// Action routing
$action = $_REQUEST['action'] ?? '';

try {
    switch ($action) {
        case 'summary':
            $stmt = $coreDb->prepare("SELECT COUNT(*) as total_orgs FROM organization WHERE status=1");
            $stmt->execute();
            $result = $stmt->get_result()->fetch_assoc();
            
            json_success(['data' => ['total_orgs' => $result['total_orgs']]]);
            break;
            
        default:
            json_error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error in platform_dashboard_api.php: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

---

## Examples of Good vs Bad API Design

### ✅ Good: Standardized Structure

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'api', 'action', 120, 60);

use BGERP\Security\PermissionHelper;
if (!PermissionHelper::hasOrgPermission($member, 'module.action')) {
    json_error('forbidden', 403);
}

$action = $_REQUEST['action'] ?? '';
try {
    switch ($action) {
        case 'action':
            // Logic
            json_success(['data' => $result]);
            break;
        default:
            json_error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

### ❌ Bad: Missing Components

```php
<?php
// ❌ Wrong: No bootstrap
// ❌ Wrong: No rate limiting
// ❌ Wrong: No permission check
// ❌ Wrong: No error handling

$action = $_GET['action'];
if ($action == 'list') {
    $result = mysqli_query($db, "SELECT * FROM table");
    echo json_encode($result);
}
```

---

## Reference Documents

### API Documentation

- **API Reference**: `docs/API_REFERENCE.md` - Complete API documentation
- **API Structure Audit**: `docs/API_STRUCTURE_AUDIT.md` - Enterprise standards
- **Task 20**: `docs/bootstrap/Task/task20.md` - JSON output enforcement

### Code Examples

- **TenantApiOutput**: `source/BGERP/Http/TenantApiOutput.php`
- **Example APIs**: `source/products.php`, `source/materials.php`
- **Test Examples**: `tests/Integration/SystemWide/EndpointSmokeSystemWideTest.php`

---

## Future Expansion

### Planned Enhancements

1. **GraphQL API Layer**
   - Alternative to REST APIs
   - Type-safe queries
   - Unified interface

2. **API Versioning**
   - Versioned endpoints
   - Backward compatibility
   - Deprecation strategy

3. **API Documentation (OpenAPI)**
   - Auto-generated docs
   - Interactive testing
   - Client SDK generation

4. **API Gateway**
   - Centralized routing
   - Request transformation
   - Response caching

---

**Previous Chapter:** [Chapter 5 — Database Architecture](../chapters/05-database-architecture.md)  
**Next Chapter:** [Chapter 7 — Global Helpers](../chapters/07-global-helpers.md)

