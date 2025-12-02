

# Tenant API Bootstrap Specification

This document defines the standard bootstrap procedure for all **tenant-scoped API endpoints** in the Bellavier Group ERP system. It ensures consistency, reduces duplicated setup logic, and centralizes the initialization steps required for per-organization (tenant) execution.

---

# 1. Purpose
Tenant API Bootstrap provides a unified mechanism to:

- Resolve the current organization (tenant)
- Initialize tenant-specific database connection
- Provide common helpers (json_error, request validation, etc.)
- Apply global API behaviors (timezone, headers)
- Enforce security and context consistency

Every Hatthasilpa / DAG / Operator API that operates inside an organization **must** load this bootstrap.

---

# 2. File Location
```
source/bootstrap/tenant_api_bootstrap.php
```

This file will be included by all tenant-scoped APIs:
```
require_once __DIR__ . '/../bootstrap/tenant_api_bootstrap.php';
```

---

# 3. Responsibilities of tenant_api_bootstrap.php
The bootstrap performs the following steps:

## 3.1 Load Global Configuration
- Require global `config.php` (env, Composer autoload, constants)
- Rely on PSR-4 autoloaded helpers/services (no per-file require in APIs)

## 3.2 Resolve Current Tenant
```
$org = resolve_current_org();
if (!$org) {
    json_error('no_org', 403, ['app_code' => 'TENANT_403_NO_ORG']);
    exit;
}
```

## 3.3 Initialize Tenant Database
```
$tenantDb = tenant_db($org['code']);
$db = new DatabaseHelper($tenantDb);
```
This provides `$db` as a ready-to-use database handler for the tenant.

## 3.4 Standardize Response Headers
- Set `Content-Type: application/json; charset=utf-8`
- Optional: Disable caching if required

## 3.5 Set Timezone
- Use server-wide timezone defined in `config.php`
- Ensure consistency for `NOW()` across APIs

## 3.6 Error Handling Wrappers (Optional)
Bootstrap may provide wrappers for:
- Exception → json_error
- Database connection errors
- Unauthorized access to tenant data

---

# 4. Example tenant_api_bootstrap.php Implementation

```php
<?php

declare(strict_types=1);

use BGERP\Helper\DatabaseHelper;
use BGERP\Helper\JsonResponse;
use BGERP\Helper\OrgResolver;
use BGERP\Helper\TenantConnection;

// Global config: env, constants, Composer autoload
require_once __DIR__ . '/../../config.php';

header('Content-Type: application/json; charset=utf-8');

// Resolve current organization (tenant)
$org = OrgResolver::resolveCurrentOrg();
if (!$org) {
    JsonResponse::error('no_org', 403, ['app_code' => 'TENANT_403_NO_ORG']);
    exit;
}

// Initialize tenant database connection via helper
$tenantMysqli = TenantConnection::forOrgCode($org->getCode());
$db = new DatabaseHelper($tenantMysqli);

// Standardize timezone (per org, with global fallback)
\date_default_timezone_set($org->getTimezone() ?? DEFAULT_TIMEZONE);

// From this point on, all queries should go through $db (DatabaseHelper),
// not raw mysqli calls.
// Optional: Wrap downstream API logic in try/catch and convert to JsonResponse::error()
```

---

# 5. Usage Pattern (Mandatory for Tenant APIs)
Any new API under these modules must require the bootstrap:
- Hatthasilpa
- DAG Token / Routing
- Operator Management
- Work Queue APIs
- Anything requiring `$org` and `$db`

Example:
```
<?php
require_once __DIR__ . '/../bootstrap/tenant_api_bootstrap.php';

// Now safe to use $org and $db
```

---

# 6. Rules & Guardrails

1. Do **not** duplicate tenant resolution logic inside API files.
2. Do **not** create tenant DB connections manually.
3. All tenant APIs **must** load this bootstrap.
4. config.php must remain free from per-request logic.
5. index.php must remain free from tenant-specific logic.
6. Bootstrap must be lightweight — no heavy business logic.
7. All new classes, helpers, and services used by tenant APIs **must follow Bellavier Group coding standards**, including PSR-4 autoloading and proper namespacing.
8. New global functions are discouraged. Shared logic should be implemented in namespaced classes or helpers that are autoloaded via Composer.
9. Tenant APIs MUST NOT use raw mysqli_* functions directly; all DB access must go through DatabaseHelper or equivalent repository/service classes.

---

# 7. Future Extensions
The bootstrap can later add:
- Rate limiting per tenant
- Logging context injection
- Authentication enforcement
- Automatic transaction wrapper
- Multi-tenant analytics tagging

These should be added only when needed, keeping the bootstrap minimal.

---

# 8. Status
🟩 **Implementation Progress:**

- ✅ **Task 1:** Discovery & Mapping (Completed 2025-11-18)
- ✅ **Task 2:** PSR-4 Helper Classes & TenantApiBootstrap::init() (Completed 2025-11-18)
- ✅ **Task 3:** API Migration (Batch A - Low-risk APIs) (Completed 2025-11-18)
- ✅ **Task 4:** Legacy Query Refactor (Batch A/B) (Completed 2025-11-18)
- ✅ **Task 5:** Batch B Tenant API Migration (Completed 2025-11-18)
- ✅ **Task 6:** Batch C Tenant API Migration - dag_token_api.php (Completed 2025-11-18)
- ✅ **Task 6.1:** Batch D Tenant API Migration (Completed 2025-11-18)

**Current State:**
- 40 APIs migrated to use `TenantApiBootstrap::init()`
  - Batch A: 6 APIs (100%)
  - Batch B: 14 APIs (100%)
  - Batch C: 1 API (dag_token_api.php - CRITICAL)
  - Batch D: 19 APIs (100%)
- All legacy query patterns removed from migrated APIs
- Smoke test validates bootstrap usage and legacy pattern detection (40 files)
- Critical file `dag_token_api.php` successfully migrated with all guardrails preserved
- All remaining tenant-scoped APIs migrated (Batch D complete)
- Ready for final cleanup and standardization (Task 7)

---

# 9. Non-Tenant Core / Platform Layer

**Core / Platform Files (Excluded from TenantApiBootstrap scope):**

There are ~10 Core / Platform files that are part of the Bellavier / Hatthasilpa ERP core platform but are **NOT** tenant-scoped APIs. These files handle platform-level operations such as:
- Admin / Org / RBAC / Permission management
- Member / Login / Session management
- Platform-level Dashboard / Health / Metrics
- Tenant migration / bootstrap / installer

**Status:**
- ✅ All Core/Platform files marked with "CORE / PLATFORM FILE (NON-TENANT API)" header
- ✅ Protected from accidental TenantApiBootstrap migration
- ⏳ A dedicated Core/Platform bootstrap will be designed in a future task (Task 9+)

**Files:**
- `source/admin_org.php` - Admin Organizations Management
- `source/admin_rbac.php` - Admin RBAC Management
- `source/bootstrap_migrations.php` - Migration Bootstrap
- `source/member_login.php` - Member Login API
- `source/permission.php` - Permission Helper
- `source/platform_dashboard_api.php` - Platform Dashboard
- `source/platform_health_api.php` - Platform Health Check
- `source/platform_migration_api.php` - Platform Migration API
- `source/platform_serial_metrics_api.php` - Platform Serial Metrics
- `source/run_tenant_migrations.php` - Tenant Migrations Runner

**Important:**
- These files **MUST NOT** be migrated to TenantApiBootstrap in this phase
- They will have a separate CoreBootstrap / PlatformBootstrap design in future tasks
- See `docs/bootstrap/tenant_api_bootstrap.discovery.md` for detailed classification

**CoreApiBootstrap:**
- Design specification: `docs/bootstrap/core_platform_bootstrap.design.md` (Task 9 ✅)
- Implementation: `source/BGERP/Bootstrap/CoreApiBootstrap.php` (Task 10 ✅)
- Migration: 12 Core/Platform API files migrated (Task 11 ✅, Task 12 ✅, Task 14 ✅, Task 15 ✅)
  - Task 11: 8 files (admin_org.php, admin_rbac.php, member_login.php, run_tenant_migrations.php, platform_*_api.php)
  - Task 12: Standardized AI Trace + Error Handling for 4 Platform APIs
  - Task 14: 3 files (admin_feature_flags_api.php, platform_roles_api.php, platform_tenant_owners_api.php)
  - Task 15: 1 file (platform_serial_salt_api.php - CRITICAL, security-sensitive)
- Separate bootstrap for Core/Platform layer APIs
- Supports multiple modes: auth required, public, platform admin, CLI mode
- Unit tests: `tests/bootstrap/CoreApiBootstrapTest.php` (9 tests, all passing)
- **Status:** ✅ 100% Complete - All Core/Platform API endpoints migrated

---

# 10. Bellavier Group Coding Standards (Summary)

Tenant API Bootstrap and all APIs that depend on it must comply with Bellavier Group's core engineering standards:

## 9.1 Namespacing & Autoloading (PSR-4)
- All new PHP classes MUST use proper namespaces under the project root (e.g. `BGERP\\Service\\...`, `BGERP\\Helper\\...`).
- Classes MUST be autoloadable via Composer's PSR-4 configuration.
- File paths MUST match namespaces to avoid manual `require` misuse.

## 9.2 File-level Conventions
- Use `declare(strict_types=1);` for new PHP files where feasible.
- Avoid closing `?>` tag in pure PHP files to prevent accidental output.
- Keep bootstrap files free of business logic — only environment setup, not domain-specific processing.

## 9.3 Error Codes & JSON Responses
- Use `json_error()` / `json_success()` helpers consistently for API responses.
- Every error response SHOULD include a stable `app_code` field for debugging and client-side handling.
- Do not echo/print raw PHP errors; rely on structured JSON error handling.

## 9.4 Security & Context
- Never bypass `resolve_current_org()` in tenant APIs.
- Never reuse `$db` across tenants; each request MUST use the tenant-specific `$db` from the bootstrap.
- Avoid reading raw `$_GET`/`$_POST` directly; use centralized request/validation helpers where available.

## 9.5 Extensibility
- When adding new behavior to the bootstrap, prefer opt-in feature flags or configuration-driven toggles.
- Do not introduce heavy dependencies or long-running logic in the bootstrap path.

These standards ensure that all tenant APIs are consistent, maintainable, and ready to scale with Bellavier Group's long-term roadmap.