# Chapter 3 — Bootstrap System

**Last Updated:** January 2025  
**Purpose:** Explain the foundational bootstrap layers that initialize all API endpoints  
**Audience:** Developers working on API endpoints, AI agents modifying API structure

---

## Overview

The bootstrap system provides centralized initialization for all API endpoints in the Bellavier Group ERP system. It ensures consistency, reduces code duplication, and enforces security and context setup across all APIs.

**Key Components:**
- `TenantApiBootstrap` - For tenant-scoped APIs (65+ APIs migrated)
- `CoreApiBootstrap` - For platform/core APIs (12 APIs migrated)
- Rate limiting integration (71 APIs)
- Request validation (62 APIs)
- Idempotency (38 APIs)
- AI-trace debug injection
- Error handler structure

**Migration Status:**
- ✅ **77+ APIs** migrated to bootstrap layers (85.9%)
- ⚠️ **8+ APIs** still need migration (14.1%)

**Benefits:**
- ✅ Consistent initialization across all APIs
- ✅ Automatic tenant resolution
- ✅ Built-in security (rate limiting, auth)
- ✅ Standardized error handling
- ✅ Reduced code duplication

---

## Key Concepts

### 1. Bootstrap Philosophy

**Lightweight & Focused:**
- Bootstrap performs **only initialization**, no business logic
- No queries, no side effects, no heavy operations
- Fast execution (< 10ms typical)

**Centralized Setup:**
- All APIs use the same initialization pattern
- Consistent behavior across the system
- Easy to maintain and update

**Security First:**
- Rate limiting applied automatically
- Authentication checked before API logic
- Error handling standardized

### 2. When to Use Which Bootstrap

**TenantApiBootstrap:**
- ✅ Tenant-scoped operations (products, materials, WIP, DAG, MO, etc.)
- ✅ Organization-specific data
- ✅ Requires tenant database (122 tables)
- ✅ 65+ APIs use this

**CoreApiBootstrap:**
- ✅ Platform-level operations (admin, health, roles, migration, etc.)
- ✅ Cross-tenant operations
- ✅ Requires core database (13 tables)
- ✅ 12 APIs use this

### 3. Bootstrap Initialization Flow

**TenantApiBootstrap Flow:**
```
1. Load config.php
2. Resolve organization (from session/context)
3. Initialize tenant database connection
4. Create DatabaseHelper instance
5. Set timezone
6. Return: [$org, $db] (where $db is DatabaseHelper instance)
```

**CoreApiBootstrap Flow:**
```
1. Load config.php
2. Handle CLI mode (if enabled)
3. Start session (if not CLI)
4. Set headers (Correlation ID, Content-Type)
5. Check maintenance mode
6. Initialize core database connection
7. Authenticate user (if required)
8. Check permissions (platform admin, custom)
9. Resolve tenant context (if required)
10. Initialize tenant database (if tenant required)
11. Return: [$member, $coreDb, $tenantDb, $org, $cid] (varies by mode)
```

---

## Core Components

### TenantApiBootstrap

**Location:** `source/BGERP/Bootstrap/TenantApiBootstrap.php`

**Purpose:**
Initialize tenant-scoped APIs with organization context, tenant database, and authenticated user.

**Initialization Steps:**

1. **Load Global Configuration**
   ```php
   require_once __DIR__ . '/../../../config.php';
   ```
   - Loads environment variables
   - Loads Composer autoloader
   - Sets up constants

2. **Resolve Organization**
   ```php
   $org = OrgResolver::resolveCurrentOrg();
   ```
   - Resolves from session/context
   - Returns organization data (id_org, code, name, etc.)
   - Exits with JSON error if no org found

3. **Initialize Tenant Database**
   ```php
   $tenantMysqli = TenantConnection::forOrgCode($orgCode);
   $db = new DatabaseHelper($tenantMysqli);
   ```
   - Connects to tenant database (`bgerp_t_{org_code}`)
   - Wraps connection in DatabaseHelper
   - Handles connection errors gracefully

4. **Set Timezone**
   ```php
   date_default_timezone_set($org['timezone'] ?? DEFAULT_TIMEZONE);
   ```
   - Sets timezone per organization
   - Ensures consistent timestamps

**Return Values:**
```php
[$org, $tenantDb, $member] = TenantApiBootstrap::init();
```

- `$org`: Organization array (id_org, code, name, status, timezone)
- `$tenantDb`: Tenant database connection (mysqli)
- `$member`: Current user/member array (id_member, username, name, etc.)

**Usage Example:**
```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Now safe to use $org, $tenantDb, $member
$stmt = $tenantDb->prepare("SELECT * FROM products WHERE org_id=?");
$stmt->bind_param('i', $org['id_org']);
$stmt->execute();
```

### CoreApiBootstrap

**Location:** `source/BGERP/Bootstrap/CoreApiBootstrap.php`

**Purpose:**
Initialize platform/core APIs with core database, authentication, and optional tenant context.

**Modes:**

1. **platform_admin** (Default for most platform APIs)
   ```php
   [$member, $coreDb] = CoreApiBootstrap::init(['requirePlatformAdmin' => true]);
   ```
   - Requires platform administrator
   - Returns core database connection
   - No tenant context

2. **auth_required**
   ```php
   [$member, $coreDb] = CoreApiBootstrap::init(['requireAuth' => true]);
   ```
   - Requires authentication
   - No platform admin required
   - Returns core database connection

3. **public**
   ```php
   [$member, $coreDb] = CoreApiBootstrap::init(['requireAuth' => false]);
   ```
   - No authentication required
   - Returns core database connection
   - `$member` will be null

4. **cli**
   ```php
   [$member, $coreDb] = CoreApiBootstrap::init(['cliMode' => true]);
   ```
   - CLI mode (no session, no auth)
   - Returns core database connection
   - `$member` will be null

**Initialization Steps:**

1. **Load Configuration**
   - Loads config.php
   - Loads Composer autoloader
   - Loads global_function.php

2. **Handle CLI Mode**
   - Skips session if CLI mode
   - Skips authentication if CLI mode

3. **Start Session** (if not CLI)
   - Starts PHP session
   - Retrieves session data

4. **Set Headers**
   - Correlation ID (X-Correlation-Id)
   - Content-Type (application/json)
   - AI Trace (X-AI-Trace)

5. **Check Maintenance Mode**
   - Returns maintenance message if enabled

6. **Initialize Core Database**
   - Connects to core database (`bgerp`)
   - Wraps in DatabaseHelper

7. **Authenticate User** (if required)
   - Checks session for logged-in user
   - Returns JSON error if not authenticated

8. **Check Permissions** (if required)
   - Platform admin check
   - Custom permission checks
   - Returns JSON error if not authorized

9. **Resolve Tenant Context** (if required)
   - Resolves organization from session/context
   - Initializes tenant database if needed

**Return Values:**
```php
[$member, $coreDb, $tenantDb, $org, $cid] = CoreApiBootstrap::init($options);
```

- `$member`: Member array (null if CLI/public mode)
- `$coreDb`: Core database connection (DatabaseHelper)
- `$tenantDb`: Tenant database connection (null if not required)
- `$org`: Organization array (null if not required)
- `$cid`: Correlation ID string

**Usage Example:**
```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Platform admin mode
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init([
    'requirePlatformAdmin' => true
]);

// Now safe to use $member, $coreDb
$stmt = $coreDb->prepare("SELECT COUNT(*) as total FROM organization WHERE status=1");
$stmt->execute();
```

### Rate Limiting Integration

**Automatic Application:**
- Rate limiting is applied in bootstrap layer
- Per-user, per-endpoint limits
- Configurable limits per API

**Configuration:**
```php
// In API file (after bootstrap)
use BGERP\Helper\RateLimiter;

RateLimiter::check(
    $member['id_member'],  // User ID
    'api_name',            // Endpoint name
    'action_name',         // Action name
    120,                   // Limit (requests)
    60                     // Window (seconds)
);
```

**Limits:**
- **Strict**: 10 req/60s (security-critical)
- **Standard**: 120 req/60s (normal operations)
- **Very Low**: 5 req/60s (migration operations)

### AI-Trace Debug Injection

**Purpose:**
Track API requests for debugging and monitoring.

**Headers:**
- `X-Correlation-Id`: Unique request identifier
- `X-AI-Trace`: AI agent tracking information

**Format:**
```json
{
  "module": "products",
  "action": "list",
  "tenant": "default",
  "user_id": 123,
  "timestamp": "2025-11-19T10:00:00Z",
  "request_id": "abc123",
  "execution_ms": 45
}
```

**Usage:**
- Automatically injected by bootstrap
- No manual setup required
- Excludes sensitive data (passwords, tokens, salts)

### Error Handler Structure

**Standardized Error Format:**
```json
{
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Error message",
    "trace": null
  }
}
```

**Error Handling:**
- Bootstrap catches initialization errors
- Returns JSON error responses
- Logs errors (non-sensitive)
- No stack traces in production

---

## Developer Responsibilities

### When Using Bootstrap

**MUST:**
- ✅ Use correct bootstrap (`TenantApiBootstrap` or `CoreApiBootstrap`)
- ✅ Use returned values correctly
- ✅ Don't bypass bootstrap initialization
- ✅ Apply rate limiting after bootstrap
- ✅ Use DatabaseHelper for database operations

**DO NOT:**
- ❌ Create manual database connections
- ❌ Bypass tenant resolution
- ❌ Skip authentication checks
- ❌ Change bootstrap return values
- ❌ Modify bootstrap code without Task approval

### When Modifying Bootstrap

**CRITICAL RULES:**
- ❌ **DO NOT** change return value structure
- ❌ **DO NOT** remove required initialization steps
- ❌ **DO NOT** break backward compatibility
- ❌ **DO NOT** add business logic to bootstrap

**ALLOWED:**
- ✅ Add optional features (feature flags)
- ✅ Improve error messages
- ✅ Add logging (non-sensitive)
- ✅ Performance optimizations (if verified safe)

**REQUIRED:**
- ✅ Update bootstrap documentation
- ✅ Update relevant Task doc
- ✅ Run SystemWide tests
- ✅ Verify all 52+ APIs still work

---

## Common Pitfalls

### 1. Wrong Bootstrap Usage

**Problem:**
```php
// ❌ Wrong: Using TenantApiBootstrap for platform operation
[$org, $tenantDb, $member] = TenantApiBootstrap::init();
// Then trying to access core database
```

**Solution:**
```php
// ✅ Correct: Use CoreApiBootstrap for platform operations
[$member, $coreDb] = CoreApiBootstrap::init(['requirePlatformAdmin' => true]);
```

### 2. Manual Database Connection

**Problem:**
```php
// ❌ Wrong: Manual connection bypasses bootstrap
$db = mysqli_connect('localhost', 'user', 'pass', 'bgerp_t_default');
```

**Solution:**
```php
// ✅ Correct: Use bootstrap
[$org, $tenantDb, $member] = TenantApiBootstrap::init();
// $tenantDb is already initialized
```

### 3. Ignoring Return Values

**Problem:**
```php
// ❌ Wrong: Not using returned values
TenantApiBootstrap::init();
// Then trying to use undefined $org, $tenantDb
```

**Solution:**
```php
// ✅ Correct: Capture return values
[$org, $tenantDb, $member] = TenantApiBootstrap::init();
// Now use $org, $tenantDb, $member
```

### 4. Missing Rate Limiting

**Problem:**
```php
// ❌ Wrong: No rate limiting
[$org, $tenantDb, $member] = TenantApiBootstrap::init();
// API vulnerable to abuse
```

**Solution:**
```php
// ✅ Correct: Add rate limiting
[$org, $tenantDb, $member] = TenantApiBootstrap::init();

use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'api_name', 'action', 120, 60);
```

---

## Examples

### Example 1: Tenant API with Bootstrap

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Bootstrap
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Rate limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'products', 'list', 120, 60);

// Permission check
use BGERP\Security\PermissionHelper;
if (!PermissionHelper::platform_has_permission($member, 'products.list')) {
    json_error('forbidden', 403);
}

// Action routing
$action = $_REQUEST['action'] ?? '';

try {
    switch ($action) {
        case 'list':
            $stmt = $tenantDb->prepare("SELECT * FROM products WHERE org_id=?");
            $stmt->bind_param('i', $org['id_org']);
            $stmt->execute();
            $products = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            
            use BGERP\Http\TenantApiOutput;
            TenantApiOutput::success(['data' => $products], null, 200);
            break;
            
        default:
            json_error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

### Example 2: Platform API with Bootstrap

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
    error_log("Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

### Example 3: Public API with Bootstrap

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Bootstrap (public mode)
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init([
    'requireAuth' => false
]);

// $member will be null (public endpoint)
// Rate limiting by IP instead
use BGERP\Helper\RateLimiter;
$ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
RateLimiter::check($ip, 'public_api', 'status', 60, 60);

// Action routing
$action = $_REQUEST['action'] ?? '';

try {
    switch ($action) {
        case 'status':
            json_success(['data' => ['status' => 'online']]);
            break;
            
        default:
            json_error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

---

## Reference Documents

### Bootstrap Documentation

- **Tenant Bootstrap**: `docs/bootstrap/tenant_api_bootstrap.md` - Complete specification
- **Core Bootstrap**: `docs/bootstrap/core_platform_bootstrap.design.md` - Design specification
- **Chapter 2**: `docs/developer/chapters/02-architecture-deep-dive.md` - Architecture overview

### Task Documentation

- **Tasks 1-15**: Bootstrap migration (TenantApiBootstrap, CoreApiBootstrap)
- **Task 16**: Integration test harness
- **Task 17**: System-wide integration tests

### Code Examples

- **Bootstrap Classes**: 
  - `source/BGERP/Bootstrap/TenantApiBootstrap.php`
  - `source/BGERP/Bootstrap/CoreApiBootstrap.php`
- **Test Examples**: 
  - `tests/Integration/SystemWide/BootstrapTenantInitTest.php`
  - `tests/Integration/SystemWide/BootstrapCoreInitTest.php`

---

## Future Expansion

### Planned Enhancements

1. **CLI Bootstrap** (`CoreCliBootstrap`)
   - Dedicated CLI mode bootstrap
   - No session, no authentication
   - Direct database access

2. **Async Job Bootstrap**
   - For background jobs
   - Queue-based processing
   - Retry mechanisms

3. **GraphQL Bootstrap**
   - For GraphQL API layer
   - Type-safe queries
   - Unified interface

4. **WebSocket Bootstrap**
   - For real-time features
   - Connection management
   - Message routing

---

**Previous Chapter:** [Chapter 2 — Architecture Deep Dive](../chapters/02-architecture-deep-dive.md)  
**Next Chapter:** [Chapter 4 — Permission Architecture](../chapters/04-permission-architecture.md)

