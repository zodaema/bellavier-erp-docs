# Global Helpers Overview

**Last Updated:** November 19, 2025  
**Purpose:** Reference map for important helper classes and functions used throughout the Bellavier Group ERP system  
**Status:** Post-Task 19 (PSR-4 Migration Complete)

---

## Overview

This document provides a quick reference for the most important helper classes and functions in the Bellavier Group ERP codebase. After Task 19, most helpers have been migrated to PSR-4 classes under the `BGERP\` namespace.

**Key Changes (Task 19):**
- `permission.php` → `BGERP\Security\PermissionHelper` (with thin wrapper)
- `bootstrap_migrations.php` → `BGERP\Migration\BootstrapMigrations` (with thin wrapper)
- All helpers use PSR-4 autoloading (via Composer)

---

## Security & Permission

### `BGERP\Security\PermissionHelper`

**Location:** `source/BGERP/Security/PermissionHelper.php`  
**Namespace:** `BGERP\Security`  
**Status:** ✅ Migrated to PSR-4 (Task 19)

**Purpose:** Centralized permission checking and platform context management.

**Key Methods:**

```php
use BGERP\Security\PermissionHelper;

// Platform admin check
PermissionHelper::isPlatformAdministrator($member): bool

// Platform permission check
PermissionHelper::platform_has_permission($member, string $permission): bool

// Org permission check
PermissionHelper::hasOrgPermission($member, string $permission): bool

// Get platform context
PermissionHelper::getPlatformContext($member): ?array

// Permission allow code (legacy wrapper)
PermissionHelper::permission_allow_code($member, string $code): bool
```

**Usage Example:**
```php
require_once __DIR__ . '/../vendor/autoload.php';
use BGERP\Security\PermissionHelper;

[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init('platform_admin');

if (!PermissionHelper::isPlatformAdministrator($member)) {
    json_error('unauthorized', 403);
}
```

**Legacy Wrapper:**
The original `permission.php` file still exists as a thin wrapper for backward compatibility:
```php
// Old way (still works)
require_once __DIR__ . '/permission.php';
if (is_platform_administrator($member)) { ... }

// New way (recommended)
use BGERP\Security\PermissionHelper;
if (PermissionHelper::isPlatformAdministrator($member)) { ... }
```

**Migration Notes (Task 19):**
- All 15 functions from `permission.php` migrated to static methods
- Thin wrapper preserves 100% backward compatibility
- Used in 62+ API files
- Future: Consider removing thin wrapper after all callers migrated

**Reference:** See `docs/bootstrap/Task/task19.md` for migration details.

---

## Migrations

### `BGERP\Migration\BootstrapMigrations`

**Location:** `source/BGERP/Migration/BootstrapMigrations.php`  
**Namespace:** `BGERP\Migration`  
**Status:** ✅ Migrated to PSR-4 (Task 19)

**Purpose:** Execute database migrations for core and tenant databases.

**Key Methods:**

```php
use BGERP\Migration\BootstrapMigrations;

// Run core database migrations
BootstrapMigrations::run_core_migrations(): void

// Run tenant migrations for specific org
BootstrapMigrations::run_tenant_migrations_for(string $orgCode): void

// Run tenant migrations for all orgs
BootstrapMigrations::run_tenant_migrations_for_all(): void

// Ensure admin user seeded
BootstrapMigrations::ensure_admin_seeded($coreDb): void
```

**Usage Example:**
```php
require_once __DIR__ . '/../vendor/autoload.php';
use BGERP\Migration\BootstrapMigrations;

// Run migrations for default tenant
BootstrapMigrations::run_tenant_migrations_for('default');

// Run migrations for all tenants
BootstrapMigrations::run_tenant_migrations_for_all();
```

**Legacy Wrapper:**
The original `bootstrap_migrations.php` file still exists as a thin wrapper:
```php
// Old way (still works)
require_once __DIR__ . '/bootstrap_migrations.php';
run_tenant_migrations_for('default');

// New way (recommended)
use BGERP\Migration\BootstrapMigrations;
BootstrapMigrations::run_tenant_migrations_for('default');
```

**Migration Notes (Task 19):**
- All 5 functions from `bootstrap_migrations.php` migrated to static methods
- Thin wrapper preserves 100% backward compatibility
- Used in: `run_tenant_migrations.php`, `utils/provision.php`
- Future: Consider removing thin wrapper after all callers migrated

**Reference:** See `docs/bootstrap/Task/task19.md` for migration details.

---

## Database

### `DatabaseHelper`

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

**Reference:** See `docs/developer/01-policy/DEVELOPER_POLICY.md` for database rules.

---

## Logging & Error Handling

### `LogHelper`

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

**Reference:** See `docs/security/task18_security_notes.md` for logging guidelines.

### `ErrorHandler`

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

## HTTP & JSON Output

### `BGERP\Http\TenantApiOutput`

**Location:** `source/BGERP/Http/TenantApiOutput.php`  
**Namespace:** `BGERP\Http`  
**Status:** ✅ Created in Task 20

**Purpose:** Ensures all tenant APIs return standardized JSON format.

**Key Methods:**

```php
use BGERP\Http\TenantApiOutput;

// Success response
TenantApiOutput::success($data, $meta = null, $code = 200): void

// Error response
TenantApiOutput::error($message, $code = null, $extra = null): void

// Safe execution wrapper
TenantApiOutput::safeExecute(callable $callback): mixed

// Start output buffer (prevents whitespace/BOM issues)
TenantApiOutput::startOutputBuffer(): void
```

**Usage Example:**
```php
require_once __DIR__ . '/../vendor/autoload.php';
use BGERP\Http\TenantApiOutput;

TenantApiOutput::startOutputBuffer();

// ... API logic ...

TenantApiOutput::success($data, $meta, 200);
```

**Reference:** See `docs/bootstrap/Task/task20.md` for JSON output enforcement.

---

## Bootstrap Layers (Overview)

### `BGERP\Bootstrap\TenantApiBootstrap`

**Location:** `source/BGERP/Bootstrap/TenantApiBootstrap.php`  
**Purpose:** Initialize tenant-scoped APIs (40+ APIs migrated)

**Usage:**
```php
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();
```

**Returns:**
- `$org`: Organization/tenant information
- `$tenantDb`: Tenant database connection (mysqli)
- `$member`: Current user/member information

**Reference:** See `docs/bootstrap/tenant_api_bootstrap.md` for complete specification.

### `BGERP\Bootstrap\CoreApiBootstrap`

**Location:** `source/BGERP/Bootstrap/CoreApiBootstrap.php`  
**Purpose:** Initialize platform/core APIs (12 APIs migrated)

**Usage:**
```php
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init('platform_admin');
```

**Modes:**
- `'platform_admin'`: Requires platform administrator
- `'auth_required'`: Requires authentication
- `'public'`: No authentication required
- `'cli'`: CLI mode (no session)

**Returns:**
- `$member`: Current user/member information (null if public/cli)
- `$coreDb`: Core database connection (mysqli)

**Reference:** See `docs/bootstrap/core_platform_bootstrap.design.md` for complete specification.

---

## Rate Limiting

### `BGERP\Helper\RateLimiter`

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

**Reference:** See `docs/security/task18_security_notes.md` for rate limiting guidelines.

---

## Helper Migration Status

### ✅ Migrated to PSR-4 (Task 19)

- ✅ `BGERP\Security\PermissionHelper` - Permission checks
- ✅ `BGERP\Migration\BootstrapMigrations` - Migration execution

### ⚠️ May Be Legacy or PSR-4 (Check Codebase)

- ⚠️ `DatabaseHelper` - Database operations
- ⚠️ `LogHelper` - Logging
- ⚠️ `ErrorHandler` - Error handling
- ⚠️ `RateLimiter` - Rate limiting

### ✅ Created in Recent Tasks

- ✅ `BGERP\Http\TenantApiOutput` - JSON output (Task 20)
- ✅ `BGERP\Bootstrap\TenantApiBootstrap` - Tenant bootstrap (Tasks 1-15)
- ✅ `BGERP\Bootstrap\CoreApiBootstrap` - Core bootstrap (Tasks 10-15)

---

## Quick Reference

### Permission Checks
```php
use BGERP\Security\PermissionHelper;

if (!PermissionHelper::isPlatformAdministrator($member)) { ... }
if (!PermissionHelper::platform_has_permission($member, 'code')) { ... }
```

### Migrations
```php
use BGERP\Migration\BootstrapMigrations;

BootstrapMigrations::run_tenant_migrations_for('default');
```

### JSON Output
```php
use BGERP\Http\TenantApiOutput;

TenantApiOutput::success($data, $meta, 200);
TenantApiOutput::error($message, $code, $extra);
```

### Bootstrap
```php
// Tenant API
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Platform API
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init('platform_admin');
```

---

## Related Documentation

### Helper Details
- **PermissionHelper**: `source/BGERP/Security/PermissionHelper.php`
- **BootstrapMigrations**: `source/BGERP/Migration/BootstrapMigrations.php`
- **TenantApiOutput**: `source/BGERP/Http/TenantApiOutput.php`

### Migration History
- **Task 19**: `docs/bootstrap/Task/task19.md` - PSR-4 helper migration
- **Task 20**: `docs/bootstrap/Task/task20.md` - JSON output enforcement

### Bootstrap Architecture
- **Tenant Bootstrap**: `docs/bootstrap/tenant_api_bootstrap.md`
- **Core Bootstrap**: `docs/bootstrap/core_platform_bootstrap.design.md`

### Security
- **Security Notes**: `docs/security/task18_security_notes.md`

---


---

## i18n Usage for Helpers (New – 2025 Standard)

All user‑facing strings returned from APIs **must support i18n**.  
However, *internal error keys, exception messages, and logs do NOT require translation*.

### Rules
- API responses MUST use:
  ```php
  TenantApiOutput::error(
      translate('errors.unauthorized', 'Unauthorized'),
      403
  );
  ```
- Log messages MUST be English only and do NOT use translate()
- Exception messages MUST be English only
- Internal helper messages MUST be English only

### Summary
| Layer               | i18n Required | Notes |
|--------------------|--------------|-------|
| API success/error  | ✅ Yes       | Use translate() with English fallback |
| UI (JS/HTML)       | ✅ Yes       | Use t() |
| Logs               | ❌ No        | English only, sanitized |
| Exceptions         | ❌ No        | Internal English messages only |
| Helper internal    | ❌ No        | Do not use translate() |

---

## Frontend Helper & JS Standards (New)

These standards apply to every JS module in the system.

### Mandatory
- All UI text must use:
  ```javascript
  t('products.form.save', 'Save')
  ```
- All API calls must use `fetchJson()`
- No `alert()` / `confirm()` / `prompt()`
- No inline handlers (`onclick=""` forbidden)
- Always wrap modules with:
  ```javascript
  // Module: XYZ
  // Author: Bellavier Group Engineering
  // Updated: YYYY-MM-DD
  ```

---

## PSR‑4 & Helper Architecture Standard (New)

### Rules
- Every new helper must be placed under:
  `source/BGERP/{Module}/`
- Helpers MUST NOT mix business logic with UI logic
- Helpers MUST be pure functions when possible
- Helpers MUST NOT access the database directly unless designed as a DB helper

### Example – Correct
```php
namespace BGERP\Helper;

class MathHelper {
    public static function clamp(int $value, int $min, int $max): int {
        return max($min, min($max, $value));
    }
}
```

### Example – Incorrect
```php
// ❌ business logic inside helper
public static function createProductAndGraph(...) { ... }
```

---

## Security Standards for Helpers (New)

- Helpers must never log sensitive fields:
  `password`, `token`, `api_key`, `secret`, `salt`
- Logs must be English‑only
- Use LogHelper to automatically sanitize arrays

---

## AI Agent Implementation Rules (New)

When generating helper‑related code:

1. Use English for all comments
2. Use i18n for all user‑visible API strings
3. Never hard‑code UI text
4. Follow PSR‑12 + Bellavier Coding Standard
5. Maintain strict file headers:
   ```
   /**
    * File: XYZ.php
    * Purpose:
    * Author: Bellavier Group Engineering
    * Updated: YYYY-MM-DD
    */
   ```

---

**Need more details?** → Check the source files or related documentation.
