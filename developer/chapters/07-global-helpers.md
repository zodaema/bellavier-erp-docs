# Chapter 7 — Global Helpers

**Last Updated:** November 19, 2025  
**Purpose:** Describe all global subsystem helpers used throughout the system  
**Audience:** Developers using helper functions, AI agents modifying helper code

---

## Overview

This chapter documents all global helper classes and functions in the Bellavier Group ERP system. These helpers provide centralized functionality for common operations like permissions, migrations, database operations, logging, and rate limiting.

**Key Helpers:**
- `PermissionHelper` - Permission checking (Task 19)
- `BootstrapMigrations` - Migration execution (Task 19)
- `TenantApiOutput` - JSON output standardization (Task 20)
- `DatabaseHelper` - Database operations
- `LogHelper` - Logging system
- `RateLimiter` - Rate limiting

**Migration Status:**
- ✅ `PermissionHelper` - Migrated to PSR-4 (Task 19)
- ✅ `BootstrapMigrations` - Migrated to PSR-4 (Task 19)
- ✅ `TenantApiOutput` - Created in PSR-4 (Task 20)
- ⚠️ Other helpers may be legacy or PSR-4 (check codebase)

---

## Key Concepts

### 1. Helper Organization

**PSR-4 Helpers:**
- Located in `source/BGERP/` namespace
- Autoloaded via Composer
- Use `use` statements (no require_once)

**Legacy Helpers:**
- Located in `source/` or `source/helper/`
- Require manual `require_once`
- May have thin wrappers for backward compatibility

### 2. Helper Usage Pattern

**PSR-4 Helper:**
```php
require_once __DIR__ . '/../vendor/autoload.php';
use BGERP\Security\PermissionHelper;
use BGERP\Migration\BootstrapMigrations;
use BGERP\Http\TenantApiOutput;

PermissionHelper::isPlatformAdministrator($member);
BootstrapMigrations::run_tenant_migrations_for('default');
TenantApiOutput::success($data);
```

**Legacy Helper:**
```php
require_once __DIR__ . '/helper/LogHelper.php';
LogHelper::log('operation', $data);
```

### 3. Helper Categories

**Security Helpers:**
- Permission checking
- Authentication
- Authorization

**Database Helpers:**
- Migration execution
- Database operations
- Query building

**HTTP Helpers:**
- JSON output
- Response formatting
- Header management

**Utility Helpers:**
- Logging
- Rate limiting
- Error handling

---

## Core Components

### PermissionHelper

**Location:** `source/BGERP/Security/PermissionHelper.php`  
**Namespace:** `BGERP\Security`  
**Status:** ✅ Migrated to PSR-4 (Task 19)

**Purpose:** Centralized permission checking and platform context management.

**Key Methods:**
- `isPlatformAdministrator($member)` - Check platform admin
- `platform_has_permission($member, $permission)` - Check platform permission
- `hasOrgPermission($member, $permission)` - Check tenant permission
- `getPlatformContext($member)` - Get platform context
- `permission_allow_code($member, $code)` - Legacy permission check

**Reference:** See [Chapter 4 — Permission Architecture](../chapters/04-permission-architecture.md) for complete details.

### BootstrapMigrations

**Location:** `source/BGERP/Migration/BootstrapMigrations.php`  
**Namespace:** `BGERP\Migration`  
**Status:** ✅ Migrated to PSR-4 (Task 19)

**Purpose:** Execute database migrations for core and tenant databases.

**Key Methods:**
- `run_core_migrations()` - Run core database migrations
- `run_tenant_migrations_for($orgCode)` - Run tenant migrations for specific org
- `run_tenant_migrations_for_all()` - Run tenant migrations for all orgs
- `ensure_admin_seeded($coreDb)` - Ensure platform admin exists

**Reference:** See [Chapter 5 — Database Architecture](../chapters/05-database-architecture.md) for complete details.

### TenantApiOutput

**Location:** `source/BGERP/Http/TenantApiOutput.php`  
**Namespace:** `BGERP\Http`  
**Status:** ✅ Created in Task 20

**Purpose:** Ensures all tenant APIs return standardized JSON format.

**Key Methods:**
- `success($data, $meta, $code)` - Success response
- `error($message, $code, $extra)` - Error response
- `startOutputBuffer()` - Start output buffer (prevents whitespace/BOM)
- `safeExecute($callback)` - Safe execution wrapper

**Reference:** See [Chapter 6 — API Development Guide](../chapters/06-api-development-guide.md) for complete details.

### DatabaseHelper

**Location:** `source/BGERP/Helper/DatabaseHelper.php` (if exists) or legacy helper  
**Status:** ⚠️ May be legacy or PSR-4 (check codebase)

**Purpose:** Database connection and query helpers.

**Best Practices:**
- ✅ Always use prepared statements
- ✅ Always validate inputs before queries
- ✅ Always handle errors (log, don't expose to users)
- ✅ Always use transactions for multi-step operations
- ✅ Always filter soft-deleted records (for WIP logs: `WHERE deleted_at IS NULL`)

**Usage Pattern:**
```php
// Prepared statement example
$stmt = $tenantDb->prepare("SELECT * FROM table WHERE id=?");
$stmt->bind_param('i', $id);
$stmt->execute();
$result = $stmt->get_result()->fetch_assoc();

// Transaction example
$tenantDb->begin_transaction();
try {
    // Multiple operations
    $tenantDb->commit();
} catch (\Throwable $e) {
    $tenantDb->rollback();
    throw $e;
}
```

### LogHelper

**Location:** `source/BGERP/Helper/LogHelper.php` (if exists) or legacy helper  
**Status:** ⚠️ May be legacy or PSR-4 (check codebase)

**Purpose:** Structured logging with sensitive data filtering.

**Key Features:**
- Filters sensitive keys: `password`, `api_key`, `token`, `salt`
- Structured format: `[CID:...][Filename][User:...][Action:...]`
- Masks sensitive values with `********`

**Usage Pattern:**
```php
// Structured logging
error_log("[CID:{$cid}][{$filename}][User:{$userId}][Action:{$action}] Message");

// Sensitive data filtering (automatic in LogHelper)
LogHelper::log('operation', $data); // Automatically filters sensitive keys
```

**Security Notes (Task 18):**
- ✅ No sensitive data logged (passwords, tokens, salts)
- ✅ Structured format for easy parsing
- ✅ Error messages clean (no stack traces in production)

### RateLimiter

**Location:** `source/BGERP/Helper/RateLimiter.php` (if exists) or legacy helper  
**Status:** ⚠️ Check codebase for exact location

**Purpose:** Prevent abuse and brute force attacks.

**Usage Pattern:**
```php
use BGERP\Helper\RateLimiter;

// Check rate limit
RateLimiter::check($userId, $endpoint, $action, $limit, $windowSeconds);

// Example: 120 requests per 60 seconds
RateLimiter::check($member['id_member'], 'products', 'list', 120, 60);
```

**Configuration (Task 18):**
- **Strict**: 10 req/60s (security-critical operations)
- **Standard**: 120 req/60s (normal operations)
- **Very Low**: 5 req/60s (migration operations)

**Reference:** See [Chapter 11 — Security Handbook](../chapters/11-security-handbook.md) for complete details.

### ErrorHandler

**Location:** `source/BGERP/Helper/ErrorHandler.php` (if exists) or legacy helper  
**Status:** ⚠️ May be legacy or PSR-4 (check codebase)

**Purpose:** Centralized error handling and JSON error responses.

**Usage Pattern:**
```php
try {
    // Operation
} catch (\Throwable $e) {
    ErrorHandler::handle($e, true); // Sends JSON response
}
```

---

## Example Use Cases

### Example 1: Permission Check in API

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Permission check
use BGERP\Security\PermissionHelper;
if (!PermissionHelper::hasOrgPermission($member, 'products.list')) {
    json_error('forbidden', 403);
}

// Proceed with operation
```

### Example 2: Running Migrations

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Run migrations for specific tenant
use BGERP\Migration\BootstrapMigrations;
BootstrapMigrations::run_tenant_migrations_for('default');

// Run migrations for all tenants
BootstrapMigrations::run_tenant_migrations_for_all();
```

### Example 3: JSON Output

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Start output buffer
use BGERP\Http\TenantApiOutput;
TenantApiOutput::startOutputBuffer();

// ... API logic ...

// Success response
TenantApiOutput::success($data, $meta, 200);

// Error response
TenantApiOutput::error('Error message', 400, ['field' => 'value']);
```

### Example 4: Rate Limiting

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Rate limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'products', 'list', 120, 60);

// Proceed with operation
```

### Example 5: Logging

```php
<?php
// Structured logging
$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
error_log("[CID:{$cid}][products.php][User:{$member['id_member']}][Action:list] Products listed");

// Using LogHelper (if available)
use BGERP\Helper\LogHelper;
LogHelper::log('products.list', [
    'user_id' => $member['id_member'],
    'org_id' => $org['id_org'],
    'count' => count($products)
    // Sensitive keys automatically filtered
]);
```

---

## Forbidden Changes for Helpers

### ❌ DO NOT

1. **Change Helper Method Signatures**
   ```php
   // ❌ Wrong: Changing signature
   PermissionHelper::isPlatformAdministrator($member, $extraParam);
   ```

2. **Remove Thin Wrapper Functions**
   ```php
   // ❌ Wrong: Removing permission.php wrapper
   // Task 19 requires thin wrappers for backward compatibility
   ```

3. **Modify Helper Logic Without Task Approval**
   ```php
   // ❌ Wrong: Changing permission logic
   // Task 19 forbids changing helper logic
   ```

4. **Add Business Logic to Helpers**
   ```php
   // ❌ Wrong: Adding business logic
   PermissionHelper::createProduct($data); // Should be in Service layer
   ```

5. **Log Sensitive Data**
   ```php
   // ❌ Wrong: Logging sensitive data
   LogHelper::log('operation', ['password' => $password]);
   ```

### ✅ DO

1. **Use Helper Methods Correctly**
   ```php
   // ✅ Correct: Use helper methods as designed
   PermissionHelper::isPlatformAdministrator($member);
   ```

2. **Follow Helper Patterns**
   ```php
   // ✅ Correct: Follow existing patterns
   use BGERP\Security\PermissionHelper;
   PermissionHelper::platform_has_permission($member, 'permission.code');
   ```

3. **Document Helper Usage**
   ```php
   // ✅ Correct: Document helper usage
   // Requires permission: products.list
   if (!PermissionHelper::hasOrgPermission($member, 'products.list')) {
       json_error('forbidden', 403);
   }
   ```

---

## Helper Migration Status

### ✅ Migrated to PSR-4 (Task 19)

- ✅ `BGERP\Security\PermissionHelper` - Permission checks
- ✅ `BGERP\Migration\BootstrapMigrations` - Migration execution

### ✅ Created in Recent Tasks

- ✅ `BGERP\Http\TenantApiOutput` - JSON output (Task 20)
- ✅ `BGERP\Bootstrap\TenantApiBootstrap` - Tenant bootstrap (Tasks 1-15)
- ✅ `BGERP\Bootstrap\CoreApiBootstrap` - Core bootstrap (Tasks 10-15)

### ⚠️ May Be Legacy or PSR-4 (Check Codebase)

- ⚠️ `DatabaseHelper` - Database operations
- ⚠️ `LogHelper` - Logging
- ⚠️ `ErrorHandler` - Error handling
- ⚠️ `RateLimiter` - Rate limiting

---

## Quick Reference

### Permission Checks
```php
use BGERP\Security\PermissionHelper;

if (!PermissionHelper::isPlatformAdministrator($member)) { ... }
if (!PermissionHelper::platform_has_permission($member, 'code')) { ... }
if (!PermissionHelper::hasOrgPermission($member, 'code')) { ... }
```

### Migrations
```php
use BGERP\Migration\BootstrapMigrations;

BootstrapMigrations::run_tenant_migrations_for('default');
BootstrapMigrations::run_tenant_migrations_for_all();
BootstrapMigrations::run_core_migrations();
```

### JSON Output
```php
use BGERP\Http\TenantApiOutput;

TenantApiOutput::startOutputBuffer();
TenantApiOutput::success($data, $meta, 200);
TenantApiOutput::error($message, $code, $extra);
```

### Bootstrap
```php
// Tenant API
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Platform API
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init(['requirePlatformAdmin' => true]);
```

---

## Reference Documents

### Helper Details

- **PermissionHelper**: `source/BGERP/Security/PermissionHelper.php`
- **BootstrapMigrations**: `source/BGERP/Migration/BootstrapMigrations.php`
- **TenantApiOutput**: `source/BGERP/Http/TenantApiOutput.php`

### Migration History

- **Task 19**: `docs/bootstrap/Task/task19.md` - PSR-4 helper migration
- **Task 20**: `docs/bootstrap/Task/task20.md` - JSON output enforcement

### Related Chapters

- **Chapter 4**: Permission Architecture
- **Chapter 5**: Database Architecture
- **Chapter 6**: API Development Guide
- **Chapter 11**: Security Handbook

---

**Previous Chapter:** [Chapter 6 — API Development Guide](../chapters/06-api-development-guide.md)  
**Next Chapter:** [Chapter 8 — Traceability / Token System](../chapters/08-traceability-token-system.md)

