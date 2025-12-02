# Core Platform Bootstrap – Discovery

**Generated:** 2025-11-18  
**Last Updated:** 2025-11-18  
**Task:** Task 13 – Core Platform Bootstrap Discovery  
**Purpose:** รวบรวมข้อมูล Core / Platform files ทั้งหมดที่เกี่ยวข้องกับ admin / login / RBAC / migrations / platform metrics เพื่อวางแผน Migration Roadmap สำหรับ CoreApiBootstrap

**Implementation Status:**
- ✅ **Task 8:** Core / Platform API Audit & Protection (Completed 2025-11-18)
- ✅ **Task 9:** Core / Platform Bootstrap Design (Completed 2025-11-18)
- ✅ **Task 10:** CoreApiBootstrap Implementation (Completed 2025-11-18)
- ✅ **Task 11:** Core / Platform API Migration (Completed 2025-11-18)
- ✅ **Task 12:** Platform API Batch A Standardization (Completed 2025-11-18)
- 🔄 **Task 13:** Core Platform Bootstrap Discovery (In Progress)

---

## 1. Overview

เอกสารนี้รวบรวมข้อมูลเกี่ยวกับ **Core / Platform files** ที่เป็นส่วนล่างสุดของ Bellavier ERP system:

- **Admin / Organization Management** (admin_org.php, admin_rbac.php)
- **Authentication / Login** (member_login.php)
- **RBAC / Permission** (permission.php, platform_roles_api.php)
- **Platform APIs** (platform_*_api.php)
- **Migrations** (bootstrap_migrations.php, run_tenant_migrations.php)

เป้าหมายคือ:
1. **ทำ inventory ไฟล์ Core / Platform ทั้งหมด** พร้อมจัดหมวดและระดับความเสี่ยง
2. **วิเคราะห์ bootstrap pattern ปัจจุบัน** (ใช้ CoreApiBootstrap หรือยัง, legacy pattern อะไรบ้าง)
3. **ออกแบบ Migration Roadmap** สำหรับ Task 14+ เพื่อ migrate ให้ใช้ CoreApiBootstrap ครบทั้งหมด

**สำคัญ:** Task 13 = Discovery + Documentation เท่านั้น, ไม่แก้ไขโค้ดใด ๆ

---

## 2. File Inventory (High-level)

### Summary Statistics

| Category | Total Files | Migrated to CoreApiBootstrap | Legacy Pattern | Helper/Library |
|----------|-------------|------------------------------|----------------|----------------|
| **Admin / Org** | 3 | 2 | 1 | 0 |
| **Auth / Login** | 1 | 1 | 0 | 0 |
| **RBAC / Permission** | 2 | 0 | 1 | 1 |
| **Platform APIs** | 7 | 4 | 3 | 0 |
| **Migrations** | 2 | 1 | 1 | 0 |
| **TOTAL** | **15** | **8** | **6** | **1** |

### Detailed File Inventory Table

| # | File | Type | Risk Level | Bootstrap Status | Entry Type | Notes |
|---|------|------|------------|------------------|------------|-------|
| **ADMIN / ORG** |
| 1 | `admin_org.php` | ADMIN_UI | CRITICAL | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 11) |
| 2 | `admin_rbac.php` | ADMIN_UI | CRITICAL | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 11) |
| 3 | `admin_feature_flags_api.php` | PLATFORM_API | HIGH | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 14) |
| **AUTH / LOGIN** |
| 4 | `member_login.php` | AUTH | CRITICAL | ✅ CoreApiBootstrap | HTTP (Plain Text) | Migrated (Task 11), Public endpoint |
| **RBAC / PERMISSION** |
| 5 | `permission.php` | UTILITY | MEDIUM | ❌ Helper Library | Function Library | Not API endpoint, defines permission functions |
| 6 | `platform_roles_api.php` | PLATFORM_API | HIGH | ❌ Legacy | HTTP JSON API | Uses `require_once config.php` + `core_db()` |
| **PLATFORM APIs** |
| 7 | `platform_dashboard_api.php` | PLATFORM_API | HIGH | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 11), Standardized (Task 12) |
| 8 | `platform_health_api.php` | PLATFORM_API | HIGH | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 11), Standardized (Task 12) |
| 9 | `platform_migration_api.php` | PLATFORM_API | HIGH | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 11), Standardized (Task 12) |
| 10 | `platform_serial_metrics_api.php` | PLATFORM_API | MEDIUM | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 11), Standardized (Task 12) |
| 11 | `platform_roles_api.php` | PLATFORM_API | HIGH | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 14) |
| 12 | `platform_serial_salt_api.php` | PLATFORM_API | CRITICAL | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 15), Security-hardened |
| 13 | `platform_tenant_owners_api.php` | PLATFORM_API | HIGH | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 14) |
| **MIGRATIONS** |
| 14 | `bootstrap_migrations.php` | UTILITY | CRITICAL | ❌ CLI Tool | CLI / Include | Not API endpoint, CLI tool for migrations |
| 15 | `run_tenant_migrations.php` | PLATFORM_API | CRITICAL | ✅ CoreApiBootstrap | HTTP JSON API | Migrated (Task 11) |

**Legend:**
- **Type:** `ADMIN_UI`, `AUTH`, `RBAC`, `PLATFORM_API`, `MIGRATION`, `UTILITY`
- **Risk Level:** `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`
- **Bootstrap Status:** ✅ Migrated to CoreApiBootstrap, ❌ Legacy pattern
- **Entry Type:** `HTTP JSON API`, `HTTP (Plain Text)`, `CLI`, `Function Library`

---

## 3. Detailed File Notes

### 3.1 Admin / Organization Management

#### source/admin_org.php

- **Role**: ADMIN_UI
- **Risk Level**: CRITICAL (manages organizations, tenant DB provisioning)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ✅ Uses `CoreApiBootstrap::init(['requireAuth' => true, 'requireTenant' => false])`
  - ✅ Uses `$coreDb->getCoreDb()` for direct mysqli queries
  - ✅ Has AI Trace metadata and standardized error handling
  - ✅ Has RateLimiter configured
- **DB Access**:
  - Uses Core DB exclusively (organization table)
  - Tenant DB operations (provision/drop) handled separately via `provision_tenant()`
  - Uses `$db = $coreDb->getCoreDb()` for direct mysqli operations
- **Auth / Permission**:
  - Custom `must_allow_admin()` function (not `requirePlatformAdmin`)
  - Checks: `platform_has_any()`, `permission_allow_code()` for multiple permissions
  - Platform Super Admin can manage all orgs, Tenant Admin can manage current org only
- **Special Coupling**:
  - Calls `provision_tenant()` function for tenant DB creation
  - Manages `account_org`, `account_invite` tables (Core DB)
  - Drops tenant databases on org deletion (DESTRUCTIVE!)
- **Bootstrap Strategy**: ✅ **COMPLETED** - Already migrated to CoreApiBootstrap (Task 11)
- **Notes**: Fixed `DatabaseHelper::query()` issue in Task 11 by using `$db->getCoreDb()`

#### source/admin_rbac.php

- **Role**: ADMIN_UI
- **Risk Level**: CRITICAL (manages users, roles, permissions)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ✅ Uses `CoreApiBootstrap::init(['requireAuth' => true, 'requireTenant' => false])`
  - ✅ Resolves org manually if needed: `$org = $bootstrapOrg ?? resolve_current_org()`
  - ✅ Uses `$db = $coreDb->getCoreDb()` when no org, or `new DatabaseHelper($tenantMysqli, $coreDb->getCoreDb())` when org exists
  - ✅ Has AI Trace metadata and standardized error handling
  - ✅ Has RateLimiter configured
- **DB Access**:
  - Platform users: Core DB only
  - Tenant users: Core DB (account) + Tenant DB (tenant_user_role)
  - Uses conditional DatabaseHelper setup based on org existence
- **Auth / Permission**:
  - Custom `must_allow_admin()` function
  - Checks: `platform_has_any()`, `permission_allow_code()`, `get_platform_context()`
  - Platform Super Admin can manage Platform users
  - Tenant Admin can manage Tenant users only
- **Special Coupling**:
  - Manages both Platform users (platform_user table) and Tenant users (account_org + tenant_user_role)
  - Cross-database operations (Core DB + Tenant DB)
  - Legacy RBAC support (account_group, account_org)
- **Bootstrap Strategy**: ✅ **COMPLETED** - Already migrated to CoreApiBootstrap (Task 11)
- **Notes**: Fixed `DatabaseHelper::query()` issue in Task 11

#### source/admin_feature_flags_api.php

- **Role**: PLATFORM_API
- **Risk Level**: HIGH (manages feature flags for organizations)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ❌ Legacy: `require_once __DIR__ . '/../config.php'`
  - ❌ Uses `$coreDb = core_db()` directly
  - ❌ Manual auth check: `$objMemberDetail->thisLogin()`
  - ❌ Manual JSON header: `header('Content-Type: application/json')`
  - ✅ Has RateLimiter
  - ✅ Uses DatabaseHelper (but created manually: `new DatabaseHelper(null, $coreDb)`)
- **DB Access**:
  - Uses Core DB for organization lookup
  - Uses Tenant DB for feature flags (tenant_feature_flag table)
  - Helper function `$resolveOrg` for org resolution by id or code
- **Auth / Permission**:
  - Manual permission check (same as admin_org.php style)
  - Checks: `platform_has_any()`, `permission_allow_code()` for multiple permissions
- **Special Coupling**:
  - Feature flags stored in tenant DB (tenant_feature_flag table)
  - Org resolution by id or code (flexible)
- **Bootstrap Strategy**: **CANDIDATE for CoreApiBootstrap**
  - Should use: `CoreApiBootstrap::init(['requireAuth' => true, 'requireTenant' => false])`
  - Manually resolve org if needed (similar to admin_rbac.php)
  - Use `$coreDb` from bootstrap instead of `core_db()`
- **Notes**: Similar to admin_org.php in terms of permission checks, good candidate for migration

---

### 3.2 Authentication / Login

#### source/member_login.php

- **Role**: AUTH
- **Risk Level**: CRITICAL (authentication engine, affects all users)
- **Entry Type**: HTTP (Plain Text) - Legacy format ('success', 'fill', etc.)
- **Bootstrap Pattern**:
  - ✅ Uses `CoreApiBootstrap::init(['requireAuth' => false, 'jsonResponse' => false])`
  - ✅ Public endpoint (no auth required)
  - ✅ Plain text response (legacy compatibility)
  - ✅ Uses `$coreMysqli = $coreDb->getCoreDb()` for prepared statements
  - ✅ Has AI Trace metadata (but no finally block for X-AI-Trace header)
- **DB Access**:
  - Uses Core DB only (account table)
  - Uses Tenant DB for tenant user org lookup (optional)
  - Direct mysqli queries via `$coreMysqli->prepare()`
- **Auth / Permission**:
  - No permission check (public endpoint)
  - Rate limiting based on IP + identifier (pre-login)
  - Validates password using `validate_password()`
- **Special Coupling**:
  - Sets session data: `$_SESSION['member']`, `$_SESSION['login']`
  - Updates `last_login_at` timestamp
  - For tenant users: Gets org and role from tenant_user_role
  - For platform users: Gets platform context
- **Bootstrap Strategy**: ✅ **COMPLETED** - Already migrated to CoreApiBootstrap (Task 11)
- **Notes**: Fixed `$coreDb->error` and `$coreDb->prepare()` issues in Task 11

---

### 3.3 RBAC / Permission

#### source/permission.php

- **Role**: UTILITY (Function Library)
- **Risk Level**: MEDIUM (defines permission functions, not API endpoint)
- **Entry Type**: Function Library (included by other files)
- **Bootstrap Pattern**:
  - ❌ Not an API endpoint (function library)
  - Uses `core_db()` directly in functions
  - No bootstrap pattern (functions are called from other files)
- **DB Access**:
  - Uses Core DB for platform permissions (platform_user, platform_role, platform_permission)
  - Uses Tenant DB for tenant permissions (tenant_user_role, tenant_role_permission)
  - Functions like `permission_allow_code()`, `tenant_permission_allow_code()` query both DBs
- **Auth / Permission**:
  - Defines permission checking functions:
    - `platform_has_permission()`, `platform_has_any()`
    - `platform_is_super_admin()`
    - `permission_allow_code()`, `tenant_permission_allow_code()`
    - `get_platform_context()`, `get_user_permission_codes()`
- **Special Coupling**:
  - Used by ALL APIs that check permissions
  - Stores platform context in `$_SESSION['platform_context']`
  - Cross-database queries (Core DB + Tenant DB)
- **Bootstrap Strategy**: **NOT APPLICABLE** - Function library, not API endpoint
  - Functions should continue to use `core_db()` directly
  - No migration needed (helper functions, not bootstrap)
- **Notes**: This file is in Composer's `files` autoload, loaded automatically

#### source/platform_roles_api.php

- **Role**: PLATFORM_API
- **Risk Level**: HIGH (manages platform roles and permissions)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ❌ Legacy: `require_once __DIR__ . '/../config.php'`
  - ❌ Uses `$coreDb = core_db()` directly
  - ❌ Manual auth check: `$objMemberDetail->thisLogin()`
  - ❌ Manual JSON header: `header('Content-Type: application/json')`
  - ❌ Manual correlation ID: `$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8))`
  - ✅ Has RateLimiter
  - ✅ Uses DatabaseHelper (but created manually: `new DatabaseHelper(null, $coreDb)`)
- **DB Access**:
  - Uses Core DB exclusively (platform_role, platform_permission, platform_role_permission)
  - Never touches tenant DB
- **Auth / Permission**:
  - Checks: `is_platform_administrator($member)` (Platform Super Admin only)
  - Permission string: `platform.admin` (implicit)
- **Special Coupling**:
  - Manages platform roles and permissions (Core DB only)
  - System roles protection (cannot delete system roles)
  - Role deletion safety (cannot delete if assigned to users)
- **Bootstrap Strategy**: **CANDIDATE for CoreApiBootstrap**
  - Should use: `CoreApiBootstrap::init(['requireAuth' => true, 'requirePlatformAdmin' => true])`
  - Use `$coreDb` from bootstrap instead of `core_db()`
  - Remove manual correlation ID (handled by bootstrap)
- **Notes**: Very similar to admin_org.php in terms of structure, good candidate for migration

---

### 3.4 Platform APIs (Metrics / Dashboard / Health)

#### source/platform_dashboard_api.php

- **Role**: PLATFORM_API
- **Risk Level**: HIGH (platform statistics)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ✅ Uses `CoreApiBootstrap::init(['requireAuth' => true, 'requirePlatformAdmin' => true])`
  - ✅ Has AI Trace metadata and standardized error handling
  - ✅ Has RateLimiter configured
  - ✅ Uses `$db = $coreDb` (DatabaseHelper instance)
- **DB Access**:
  - Uses Core DB for platform statistics (organization, account)
  - Uses `$db->fetchOne()` and `$db->fetchAll()` (DatabaseHelper methods)
- **Auth / Permission**:
  - Platform Super Admin only (via `requirePlatformAdmin` option)
- **Bootstrap Strategy**: ✅ **COMPLETED** - Already migrated (Task 11) and standardized (Task 12)
- **Notes**: Standardized AI Trace + Error Handling in Task 12

#### source/platform_health_api.php

- **Role**: PLATFORM_API
- **Risk Level**: HIGH (system health diagnostics)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ✅ Uses `CoreApiBootstrap::init(['requireAuth' => true, 'requirePlatformAdmin' => true])`
  - ✅ Has AI Trace metadata and standardized error handling
  - ✅ Has RateLimiter configured (lower limit: 60 req/min)
  - ✅ Uses `$db = $coreDb` (DatabaseHelper instance)
- **DB Access**:
  - Uses Core DB for health checks
  - Uses Tenant DBs for tenant-specific checks (via helper functions)
  - Uses `$db->getCoreDb()` and `$db->fetchOne()` methods
- **Auth / Permission**:
  - Platform Super Admin only (via `requirePlatformAdmin` option)
- **Bootstrap Strategy**: ✅ **COMPLETED** - Already migrated (Task 11) and standardized (Task 12)
- **Notes**: Standardized AI Trace + Error Handling in Task 12

#### source/platform_migration_api.php

- **Role**: PLATFORM_API
- **Risk Level**: HIGH (migration management)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ✅ Uses `CoreApiBootstrap::init(['requireAuth' => true, 'requirePlatformAdmin' => true])`
  - ✅ Has AI Trace metadata and standardized error handling
  - ✅ Has RateLimiter configured (lower limit: 60 req/min)
  - ✅ Uses `$db = $coreDb` (DatabaseHelper instance)
- **DB Access**:
  - Uses Core DB for tenant listing
  - Uses Tenant DBs for migration execution (via `run_tenant_migrations_for()`)
- **Auth / Permission**:
  - Platform Super Admin only (via `requirePlatformAdmin` option)
- **Bootstrap Strategy**: ✅ **COMPLETED** - Already migrated (Task 11) and standardized (Task 12)
- **Notes**: Standardized AI Trace + Error Handling in Task 12

#### source/platform_serial_metrics_api.php

- **Role**: PLATFORM_API
- **Risk Level**: MEDIUM (serial number metrics)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ✅ Uses `CoreApiBootstrap::init(['requireAuth' => true, 'requireTenant' => true])`
  - ✅ Has AI Trace metadata and standardized error handling (added in Task 12)
  - ✅ Uses `$tenantDb` and `$coreDb` from bootstrap (DatabaseHelper instances)
- **DB Access**:
  - Uses Core DB for serial registry (serial_registry table)
  - Uses Tenant DB for job ticket serials (job_ticket_serial, serial_link_outbox, serial_quarantine)
- **Auth / Permission**:
  - Checks: `must_allow('platform.view.metrics')` (custom permission check)
  - Requires tenant context
- **Bootstrap Strategy**: ✅ **COMPLETED** - Already migrated (Task 11) and standardized (Task 12)
- **Notes**: Added AI Trace + Error Handling in Task 12

#### source/platform_serial_salt_api.php

- **Role**: PLATFORM_API
- **Risk Level**: CRITICAL (security-sensitive, manages serial number salts)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ❌ Legacy: `require_once __DIR__ . '/../config.php'`
  - ❌ Uses `session_start()` manually
  - ❌ Manual auth check: `$objMemberDetail->thisLogin()`
  - ❌ Manual JSON header: `header('Content-Type: application/json')`
  - ❌ Manual correlation ID: `$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8))`
  - ✅ Has RateLimiter (very strict: 10 req/min)
  - ❌ No DatabaseHelper (uses file system for secrets)
- **DB Access**:
  - No database access (uses file system: `storage/secrets/serial_salts.php`)
  - File-based secret storage (not in database)
- **Auth / Permission**:
  - Checks: `is_platform_administrator($member)` (Platform Super Admin only, Owner/SysAdmin role)
  - Security-sensitive operations (salt generation/rotation)
- **Special Coupling**:
  - Manages serial number salts (file-based, not DB)
  - Show-once display (never log salt values)
  - CSRF protection
  - Atomic file writes
- **Bootstrap Strategy**: **CANDIDATE for CoreApiBootstrap (High Priority)**
  - Should use: `CoreApiBootstrap::init(['requireAuth' => true, 'requirePlatformAdmin' => true])`
  - Remove manual session/auth/header setup
  - Keep file-based secret storage (no DB migration needed)
  - **CAUTION**: Security-sensitive, requires thorough testing
- **Notes**: **CRITICAL** - Security-sensitive file, must be handled carefully

#### source/platform_tenant_owners_api.php

- **Role**: PLATFORM_API
- **Risk Level**: HIGH (manages tenant owners)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ❌ Legacy: `require_once __DIR__ . '/../config.php'`
  - ❌ Uses `$coreDb = core_db()` directly
  - ❌ Manual auth check: `$objMemberDetail->thisLogin()`
  - ❌ Manual JSON header: `header('Content-Type: application/json')`
  - ❌ Manual correlation ID: `$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8))`
  - ✅ Has RateLimiter
  - ✅ Uses DatabaseHelper (but created manually: `new DatabaseHelper(null, $coreDb)`)
- **DB Access**:
  - Uses Core DB exclusively (account, account_org, account_group)
  - Never touches tenant DB
- **Auth / Permission**:
  - Checks: `is_platform_administrator($member)` (Platform Super Admin only)
- **Special Coupling**:
  - Manages tenant owners (platform_owner user type)
  - Tenant assignment via account_org table
  - Soft delete (status = 0, never hard delete)
- **Bootstrap Strategy**: **CANDIDATE for CoreApiBootstrap**
  - Should use: `CoreApiBootstrap::init(['requireAuth' => true, 'requirePlatformAdmin' => true])`
  - Use `$coreDb` from bootstrap instead of `core_db()`
  - Remove manual correlation ID (handled by bootstrap)
- **Notes**: Very similar to platform_roles_api.php in terms of structure

---

### 3.5 Migrations

#### source/bootstrap_migrations.php

- **Role**: UTILITY (CLI Tool)
- **Risk Level**: CRITICAL (runs migrations, affects all databases)
- **Entry Type**: CLI / Include (can be run directly or included)
- **Bootstrap Pattern**:
  - ❌ Not an API endpoint (CLI tool / helper file)
  - Uses `require_once __DIR__ . '/../config.php'` manually
  - Detects CLI mode: `$isCli = (php_sapi_name() === 'cli')`
  - No bootstrap pattern (utility functions)
- **DB Access**:
  - Uses Core DB for core migrations (schema_migrations table)
  - Uses Tenant DBs for tenant migrations (tenant_schema_migrations table)
  - Functions: `run_core_migrations()`, `run_tenant_migrations_for()`, `run_tenant_migrations_for_all()`
- **Auth / Permission**:
  - No auth check (CLI tool)
  - Can be run from command line or included by other files
- **Special Coupling**:
  - Core migration system (runs PHP migrations from `database/migrations/`)
  - Tenant migration system (runs PHP migrations from `database/tenant_migrations/`)
  - Called by `run_tenant_migrations.php` and deployment scripts
- **Bootstrap Strategy**: **NOT APPLICABLE** - CLI tool, not API endpoint
  - Functions should continue to use `core_db()` and `tenant_db()` directly
  - No migration needed (utility functions, not bootstrap)
  - **Note**: May need `CoreCliBootstrap` in the future if we standardize CLI tools
- **Notes**: Helper file, not API endpoint. Used by `run_tenant_migrations.php`.

#### source/run_tenant_migrations.php

- **Role**: PLATFORM_API (but acts as migration runner)
- **Risk Level**: CRITICAL (runs migrations, affects tenant databases)
- **Entry Type**: HTTP JSON API
- **Bootstrap Pattern**:
  - ✅ Uses `CoreApiBootstrap::init(['requireAuth' => true, 'requireTenant' => false])`
  - ✅ Resolves org manually if needed: `$org = resolve_current_org()`
  - ✅ Has AI Trace metadata and standardized error handling
  - ✅ Has RateLimiter configured (very strict: 5 req/min)
- **DB Access**:
  - Uses Core DB for tenant listing
  - Uses Tenant DB for migration execution (via `run_tenant_migrations_for()`)
  - Calls `bootstrap_migrations.php` functions
- **Auth / Permission**:
  - Custom permission check: `permission_allow_code()` OR `platform_has_permission()`
  - Tenant Admin: `system.manage` OR `admin.manage`
  - Platform Admin: `platform.migrations.run` OR `platform.tenants.manage`
- **Special Coupling**:
  - Includes `bootstrap_migrations.php` for migration functions
  - Runs tenant migrations via `run_tenant_migrations_for($orgCode)`
  - Migration tracking in `tenant_schema_migrations` table
- **Bootstrap Strategy**: ✅ **COMPLETED** - Already migrated to CoreApiBootstrap (Task 11)
- **Notes**: Uses custom permission checks (not `requirePlatformAdmin`)

---

## 4. Bootstrap Patterns

### 4.1 Current Patterns Found

#### Pattern 1: CoreApiBootstrap (Modern) ✅

**Used in:** 8 files (admin_org.php, admin_rbac.php, member_login.php, platform_dashboard_api.php, platform_health_api.php, platform_migration_api.php, platform_serial_metrics_api.php, run_tenant_migrations.php)

**Structure:**
```php
require_once __DIR__ . '/../vendor/autoload.php';
use BGERP\Bootstrap\CoreApiBootstrap;
[$member, $coreDb, $tenantDb, $org, $cid] = CoreApiBootstrap::init([
    'requireAuth' => true,
    'requirePlatformAdmin' => true, // or false
    'requireTenant' => true, // or false
    'jsonResponse' => true, // or false
]);
```

**Benefits:**
- Standardized auth, session, headers, correlation ID
- Centralized error handling
- Consistent JSON response format
- AI Trace support
- Rate limiting support

#### Pattern 2: Legacy Bootstrap ❌

**Used in:** 6 files (admin_feature_flags_api.php, platform_roles_api.php, platform_serial_salt_api.php, platform_tenant_owners_api.php, bootstrap_migrations.php, permission.php)

**Structure:**
```php
session_start();
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/global_function.php';
require_once __DIR__ . '/model/member_class.php';
require_once __DIR__ . '/permission.php';

header('Content-Type: application/json');
$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
header('X-Correlation-Id: ' . $cid);

$objMemberDetail = new memberDetail();
$member = $objMemberDetail->thisLogin();
if (!$member) { json_error('unauthorized', 401); }

$coreDb = core_db();
$db = new DatabaseHelper(null, $coreDb);
```

**Problems:**
- Manual session/auth/header setup (inconsistent)
- Manual correlation ID (duplicate code)
- Manual DatabaseHelper creation (inconsistent)
- No standardized error handling
- No AI Trace support
- No rate limiting (unless added manually)

### 4.2 Issues from Inconsistent Patterns

1. **Duplicate Code:**
   - Manual auth check in every legacy file
   - Manual correlation ID generation
   - Manual DatabaseHelper creation
   - Manual JSON header setup

2. **Inconsistent Error Handling:**
   - Some files use `try-catch-finally` with AI Trace
   - Some files use basic `try-catch` only
   - Some files have no error handling

3. **Inconsistent Permission Checks:**
   - Some use `requirePlatformAdmin` option
   - Some use custom `is_platform_administrator()` check
   - Some use `must_allow_admin()` custom function

4. **Database Connection Management:**
   - Some use `$coreDb->getCoreDb()` for direct mysqli
   - Some use `$coreDb` (DatabaseHelper) for prepared statements
   - Some create DatabaseHelper manually

---

## 5. Migration Roadmap Proposal

### Phase 1: Low-Risk Platform APIs (Batch A) ✅ COMPLETED

**Status:** ✅ COMPLETED (Task 12)

**Files:**
- ✅ `platform_dashboard_api.php` - Standardized
- ✅ `platform_health_api.php` - Standardized
- ✅ `platform_migration_api.php` - Standardized
- ✅ `platform_serial_metrics_api.php` - Standardized (AI Trace added in Task 12)

**Bootstrap Options:**
```php
CoreApiBootstrap::init([
    'requireAuth' => true,
    'requirePlatformAdmin' => true, // or requireTenant => true for serial_metrics
    'jsonResponse' => true,
]);
```

**Migration Effort:** ⭐ (Easy - Already done)

---

### Phase 2: Medium-Risk Platform APIs (Batch B)

**Status:** 🔄 PENDING (Task 14+)

**Files:**
1. `admin_feature_flags_api.php`
2. `platform_roles_api.php`
3. `platform_tenant_owners_api.php`

**Bootstrap Options:**
```php
CoreApiBootstrap::init([
    'requireAuth' => true,
    'requirePlatformAdmin' => true, // For platform_roles and platform_tenant_owners
    // admin_feature_flags: requirePlatformAdmin => false, custom permission check
    'jsonResponse' => true,
]);
```

**Migration Strategy:**
- Replace `require_once config.php` with autoloader + CoreApiBootstrap
- Use `$coreDb` from bootstrap instead of `core_db()`
- Remove manual correlation ID (handled by bootstrap)
- Add AI Trace metadata and standardized error handling
- Keep custom permission checks if needed

**Migration Effort:** ⭐⭐ (Medium - Similar to admin_org.php)

**Guardrails:**
- ❌ Don't change permission checks
- ❌ Don't change business logic
- ❌ Don't change response format

---

### Phase 3: High-Risk Platform APIs (Batch C - Security-Sensitive)

**Status:** 🔄 PENDING (Task 15+)

**Files:**
1. `platform_serial_salt_api.php` ⚠️ **CRITICAL**

**Bootstrap Options:**
```php
CoreApiBootstrap::init([
    'requireAuth' => true,
    'requirePlatformAdmin' => true,
    'jsonResponse' => true,
]);
```

**Migration Strategy:**
- Replace legacy bootstrap with CoreApiBootstrap
- **CRITICAL:** Keep file-based secret storage (no DB migration)
- **CRITICAL:** Keep CSRF protection
- **CRITICAL:** Keep show-once display logic
- Add AI Trace metadata (but never log salt values)
- Add standardized error handling

**Migration Effort:** ⭐⭐⭐⭐⭐ (Very High - Security-sensitive)

**Guardrails:**
- ❌ **NEVER** log salt values to error_log or AI Trace
- ❌ Don't change file-based secret storage
- ❌ Don't change CSRF protection
- ❌ Don't change show-once display
- ✅ Test thoroughly before deployment
- ✅ Security audit required

---

### Phase 4: Helper Files / Libraries (No Migration Needed)

**Status:** ✅ N/A

**Files:**
1. `permission.php` - Function library (no migration needed)
2. `bootstrap_migrations.php` - CLI tool (no migration needed)

**Reason:**
- `permission.php` is a function library (included by other files)
- `bootstrap_migrations.php` is a CLI tool (not an API endpoint)
- Both should continue to use `core_db()` directly
- **Note:** May need `CoreCliBootstrap` in the future if we standardize CLI tools

---

## 6. Migration Priority Matrix

| Priority | Files | Risk Level | Migration Effort | Dependencies |
|----------|-------|------------|------------------|--------------|
| **P0 (Critical)** | `platform_serial_salt_api.php` | CRITICAL | ⭐⭐⭐⭐⭐ | Security audit |
| **P1 (High)** | `admin_feature_flags_api.php` | HIGH | ⭐⭐ | - |
| **P1 (High)** | `platform_roles_api.php` | HIGH | ⭐⭐ | - |
| **P1 (High)** | `platform_tenant_owners_api.php` | HIGH | ⭐⭐ | - |
| **P2 (N/A)** | `permission.php` | MEDIUM | N/A | Function library |
| **P2 (N/A)** | `bootstrap_migrations.php` | CRITICAL | N/A | CLI tool |

**P0 (Critical):** Security-sensitive, must be handled with extreme caution  
**P1 (High):** Should be migrated soon for consistency  
**P2 (N/A):** Not applicable (helper files, no migration needed)

---

## 7. Recommended Migration Order (Task 14+)

### Task 14: Platform API Batch B Migration (Medium-Risk)

**Scope:**
- `admin_feature_flags_api.php`
- `platform_roles_api.php`
- `platform_tenant_owners_api.php`

**Bootstrap Options:**
- `admin_feature_flags_api.php`: `CoreApiBootstrap::init(['requireAuth' => true, 'requirePlatformAdmin' => false, 'jsonResponse' => true])` + custom permission check
- `platform_roles_api.php`: `CoreApiBootstrap::init(['requireAuth' => true, 'requirePlatformAdmin' => true, 'jsonResponse' => true])`
- `platform_tenant_owners_api.php`: `CoreApiBootstrap::init(['requireAuth' => true, 'requirePlatformAdmin' => true, 'jsonResponse' => true])`

**Strategy:**
- Follow same pattern as Task 11/12
- Replace legacy bootstrap with CoreApiBootstrap
- Add AI Trace + Error Handling
- Keep business logic unchanged

**Guardrails:**
- ❌ Don't change permission checks
- ❌ Don't change business logic
- ❌ Don't change response format

**Estimated Effort:** 2-3 hours (similar to Task 12)

---

### Task 15: Platform Serial Salt API Migration (High-Risk, Security-Sensitive)

**Scope:**
- `platform_serial_salt_api.php` ⚠️ **CRITICAL**

**Bootstrap Options:**
```php
CoreApiBootstrap::init([
    'requireAuth' => true,
    'requirePlatformAdmin' => true,
    'jsonResponse' => true,
]);
```

**Strategy:**
- Replace legacy bootstrap with CoreApiBootstrap
- **CRITICAL:** Never log salt values (even in AI Trace)
- **CRITICAL:** Keep file-based secret storage
- **CRITICAL:** Keep CSRF protection
- **CRITICAL:** Keep show-once display
- Add standardized error handling (but never expose salt values)

**Guardrails:**
- ❌ **NEVER** log salt values (error_log, AI Trace, audit logs)
- ❌ Don't change file-based secret storage
- ❌ Don't change CSRF protection
- ❌ Don't change show-once display
- ✅ Security audit required
- ✅ Thorough testing required
- ✅ Code review required

**Estimated Effort:** 4-6 hours (security review + testing)

---

## 8. Bootstrap Pattern Comparison

### Before (Legacy Pattern)

```php
session_start();
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/global_function.php';
require_once __DIR__ . '/model/member_class.php';
require_once __DIR__ . '/permission.php';

header('Content-Type: application/json');
$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
header('X-Correlation-Id: ' . $cid);

$objMemberDetail = new memberDetail();
$member = $objMemberDetail->thisLogin();
if (!$member) { json_error('unauthorized', 401); }

if (!is_platform_administrator($member)) {
    json_error('forbidden', 403);
}

$coreDb = core_db();
$db = new DatabaseHelper(null, $coreDb);

// ... business logic ...
```

**Problems:**
- 15+ lines of boilerplate
- Manual session/auth/header setup
- Manual correlation ID
- Inconsistent error handling
- No AI Trace support

### After (CoreApiBootstrap Pattern)

```php
require_once __DIR__ . '/../vendor/autoload.php';
use BGERP\Bootstrap\CoreApiBootstrap;
use BGERP\Helper\DatabaseHelper;
use BGERP\Helper\RateLimiter;

[$member, $coreDb, $tenantDb, $org, $cid] = CoreApiBootstrap::init([
    'requireAuth' => true,
    'requirePlatformAdmin' => true,
    'jsonResponse' => true,
]);

$__t0 = microtime(true);
$userId = $member['id_member'];
RateLimiter::check($member, 120, 60, 'platform_api');

$db = $coreDb; // DatabaseHelper instance

$aiTrace = [
    'module' => basename(__FILE__, '.php'),
    'action' => $_REQUEST['action'] ?? '',
    'tenant' => 0,
    'user_id' => $userId,
    'timestamp' => gmdate('c'),
    'request_id' => $cid
];

try {
    // ... business logic ...
} catch (\Throwable $e) {
    // Standardized error logging
    error_log(sprintf("[CID:%s][%s][User:%d] %s", $cid, basename(__FILE__), $userId, $e->getMessage()));
    json_error('internal_error', 500, ['app_code' => 'API_500_INTERNAL']);
} finally {
    $aiTrace['execution_ms'] = (int)((microtime(true) - $__t0) * 1000);
    if (!headers_sent()) {
        header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));
    }
}
```

**Benefits:**
- 3 lines for bootstrap (vs 15+ lines)
- Standardized auth, session, headers
- Automatic correlation ID
- Standardized error handling
- AI Trace support
- Rate limiting support

---

## 9. Current Statistics

### Migration Status

| Status | Count | Percentage |
|--------|-------|------------|
| ✅ **Migrated to CoreApiBootstrap** | 12 | 80.0% |
| ❌ **Legacy Pattern** | 0 | 0% |
| 🔄 **N/A (Helper/Library)** | 2 | 13.3% |
| **TOTAL (API Endpoints)** | **12** | **100%** |
| **TOTAL (All Files)** | **15** | **100%** |

### Breakdown by Type

| Type | Total | Migrated | Legacy | N/A |
|------|-------|----------|--------|-----|
| **Admin / Org** | 3 | 3 | 0 | 0 |
| **Auth / Login** | 1 | 1 | 0 | 0 |
| **RBAC / Permission** | 2 | 0 | 0 | 2 |
| **Platform APIs** | 7 | 7 | 0 | 0 |
| **Migrations** | 2 | 1 | 0 | 1 |

### Migration Progress by Task

- ✅ **Task 11:** Migrated 8 Core/Platform API files to CoreApiBootstrap
- ✅ **Task 12:** Standardized AI Trace + Error Handling for 4 Platform APIs
- ✅ **Task 13:** Discovery + Documentation
- ✅ **Task 14:** Migrated 3 Platform APIs (admin_feature_flags_api.php, platform_roles_api.php, platform_tenant_owners_api.php)
- ✅ **Task 15:** Migrated 1 CRITICAL file (platform_serial_salt_api.php - Security-hardened)

**🎉 Core Platform Bootstrap Migration: 100% Complete!**

---

## 10. Next Steps

### Immediate (Task 13)

1. ✅ Complete this discovery document
2. ✅ Verify all file patterns documented
3. ✅ Create migration roadmap

### Short-term (Task 14)

**Task 14: Platform API Batch B Migration**
- Migrate `admin_feature_flags_api.php`
- Migrate `platform_roles_api.php`
- Migrate `platform_tenant_owners_api.php`
- Estimated effort: 2-3 hours

### Medium-term (Task 15)

**Task 15: Platform Serial Salt API Migration**
- Migrate `platform_serial_salt_api.php` (CRITICAL, security-sensitive)
- Security audit required
- Thorough testing required
- Estimated effort: 4-6 hours (including security review)

### Long-term (Future Tasks)

- **Task 16+:** Core CLI Bootstrap design (if needed for `bootstrap_migrations.php`)
- **Task 17+:** Platform API full modernization (if additional improvements needed)
- **Task 18+:** Performance optimization review
- **Task 19+:** Integration tests for critical paths

---

## 11. Notes & Observations

### Common Patterns

1. **Permission Checks:**
   - Most files use `is_platform_administrator($member)` for Platform Super Admin check
   - Some use custom `must_allow_admin()` function (admin_org.php, admin_rbac.php)
   - Some use `must_allow('permission.code')` for custom permissions

2. **Database Access:**
   - Core DB: Used for platform-level data (organizations, accounts, platform_users)
   - Tenant DB: Used for tenant-specific data (feature flags, tenant_users)
   - Cross-DB: Some files need both (admin_rbac.php, platform_serial_metrics_api.php)

3. **Error Handling:**
   - Migrated files: Standardized try-catch-finally with AI Trace
   - Legacy files: Basic try-catch or no error handling

4. **Rate Limiting:**
   - Migrated files: Use `RateLimiter::check()` consistently
   - Legacy files: Some have rate limiting, some don't

### Potential Issues

1. **Inconsistent Permission Checks:**
   - Some use `requirePlatformAdmin` option
   - Some use custom `is_platform_administrator()` check
   - Should standardize on one approach

2. **DatabaseHelper Usage:**
   - Some files use `$coreDb->getCoreDb()` for direct mysqli (admin_org.php, admin_rbac.php)
   - Some files use `$coreDb` (DatabaseHelper) for prepared statements
   - Should document when to use which approach

3. **Cross-Database Queries:**
   - Some files need both Core DB and Tenant DB (admin_rbac.php, platform_serial_metrics_api.php)
   - Current pattern: Resolve org manually, create DatabaseHelper with both connections
   - Should standardize this pattern

### Recommendations

1. **Standardize Permission Checks:**
   - Use `requirePlatformAdmin` option in CoreApiBootstrap when possible
   - Only use custom checks when necessary (admin_org.php, admin_rbac.php)

2. **Document DatabaseHelper Usage:**
   - When to use `$coreDb->getCoreDb()` (direct mysqli for DDL/complex queries)
   - When to use `$coreDb` (DatabaseHelper for prepared statements)

3. **Create Migration Guide:**
   - Step-by-step guide for migrating legacy files to CoreApiBootstrap
   - Common pitfalls and solutions
   - Testing checklist

---

## 12. Status & Next Steps

**Task 13 Status:** ✅ COMPLETED (2025-11-18)

### Completion Summary

- ✅ Created discovery document structure
- ✅ Scanned all Core/Platform files (15 files total)
- ✅ Analyzed each file (detailed notes for all 15 files)
- ✅ Identified bootstrap patterns (2 patterns: CoreApiBootstrap vs Legacy)
- ✅ Created migration roadmap (Phase 1-4)
- ✅ Documented current statistics (8 migrated, 6 legacy, 1 N/A)
- ✅ Created priority matrix (P0-P2)
- ✅ Defined next steps (Task 14-15)

### Key Findings

1. **8 files already migrated** to CoreApiBootstrap (Task 11-12)
2. **6 files still use legacy pattern** (need migration in Task 14-15)
3. **1 file is helper library** (no migration needed: permission.php)
4. **1 file is CLI tool** (no migration needed: bootstrap_migrations.php)

### Migration Readiness

| Category | Readiness | Notes |
|----------|-----------|-------|
| **Batch B (Medium-Risk)** | ✅ Ready | Similar to admin_org.php, straightforward migration |
| **Batch C (Critical)** | ⚠️ Needs Review | Security-sensitive, requires security audit |
| **Helper Files** | ✅ N/A | No migration needed (function library / CLI tool) |

### Next Actions

1. ✅ **Task 14:** Migrate Batch B files (3 files, medium-risk) - COMPLETED
2. ✅ **Task 15:** Migrate Batch C file (1 file, critical, security-sensitive) - COMPLETED
3. 🔄 **Future:** Consider CoreCliBootstrap for CLI tools (optional)
4. 🔄 **Future:** Platform API full modernization (if additional improvements needed)
5. 🔄 **Future:** Performance optimization review
6. 🔄 **Future:** Integration tests for critical paths

---

**Document Status:** ✅ Complete  
**Last Updated:** 2025-11-18  
**Next Phase:** Task 14 – Platform API Batch B Migration

