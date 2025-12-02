# Tenant API Bootstrap Discovery Report

**Generated:** 2025-11-18  
**Last Updated:** 2025-11-19 (Updated after Task 17 completion)  
**Task:** Task 1 – Tenant API Bootstrap Discovery & Mapping  
**Purpose:** รวบรวมข้อมูล API + Helper ทั้งระบบที่ยังใช้ core setup แบบเก่าให้ครบ ก่อนวางแผนย้ายไปใช้ `TenantApiBootstrap` แบบ PSR-4

**Implementation Status:**
- ✅ **Task 1:** Discovery & Mapping (Completed 2025-11-18)
- ✅ **Task 2:** PSR-4 Helper Classes & TenantApiBootstrap::init() (Completed 2025-11-18)
- ✅ **Task 3:** API Migration (Batch A - Low-risk APIs) (Completed 2025-11-18)
- ✅ **Task 4:** Legacy Query Refactor (Batch A/B) (Completed 2025-11-18)
- ✅ **Task 5:** Batch B Tenant API Migration (Completed 2025-11-18)
- ✅ **Task 6:** Batch C Tenant API Migration - dag_token_api.php (Completed 2025-11-18)
- ✅ **Task 6.1:** Batch D Tenant API Migration (Completed 2025-11-18)
- ✅ **Task 16:** Integration Test Harness (Completed 2025-11-19)
- ✅ **Task 17:** System-Wide Integration Tests (Completed 2025-11-19)

---

## Executive Summary

- **Total PHP Files Analyzed:** 158 files in `source/`
- **Tenant-scoped APIs Found:** ~53 files using `resolve_current_org()`
- **APIs Using PSR-4 (`use BGERP\`):** 83 files
- **Helper Classes Existing:** 11 classes in `source/BGERP/Helper/`
- **Helper Classes Missing:** 3 classes needed for Bootstrap (OrgResolver, JsonResponse, TenantConnection)
- **Current Pattern:** Function-based (resolve_current_org, tenant_db, json_error/json_success)
- **Target Pattern:** PSR-4 class-based (TenantApiBootstrap::init())

---

## 1. API Inventory & Patterns

### 1.1 Tenant-Scoped APIs Summary Table

| # | File Path | Type | Org Resolve Pattern | DB Pattern | Header/JSON Pattern | PSR-4 Ready? | Lines | Migration Status | Notes |
|---|-----------|------|---------------------|-----------|---------------------|--------------|-------|------------------|-------|
| 1 | `source/dag_token_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | custom header + `json_error()` | ✅ Uses `use BGERP\` | ~3,314 | ✅ **Migrated** (Task 6) | **CRITICAL** - Successfully migrated with all guardrails preserved |
| 2 | `source/hatthasilpa_operator_api.php` | API | `$org = resolve_current_org()` | `$tenantDb = tenant_db($org['code']); $db = new DatabaseHelper($tenantDb)` | `header('Content-Type: application/json')` + `json_error()` | ✅ Uses `use BGERP\Helper\*` | ~289 | ✅ **Migrated** (Task 3) | Standard pattern |
| 3 | `source/team_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `header('X-Correlation-Id')` + `json_error()` | ✅ Uses `use BGERP\Service\*` | ~1,580 | ✅ **Migrated** (Task 5) | **FIXED** - Duplicate org resolution removed |
| 4 | `source/dag_routing_api.php` | API | `$org = resolve_current_org()` | `$tenantDb = tenant_db($org['code']); $db = new DatabaseHelper($tenantDb)` | `safeHeader()` + `json_error()` | ✅ Uses `use BGERP\` | ~6,996 | ✅ **Migrated + Refactored** (Task 3+4) | Standard pattern |
| 5 | `source/hatthasilpa_jobs_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~2,064 | ✅ **Migrated** (Task 5) | Standard pattern |
| 6 | `source/hatthasilpa_job_ticket.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~1,933 | ✅ **Migrated** (Task 5) | Standard pattern |
| 7 | `source/assignment_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~1,501 | ✅ **Migrated + Refactored** (Task 3+4) | Standard pattern |
| 8 | `source/assignment_plan_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~1,077 | ✅ **Migrated** (Task 3) | Standard pattern |
| 9 | `source/token_management_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~802 | ✅ **Migrated** (Task 5) | Standard pattern |
| 10 | `source/trace_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~2,930 | ✅ **Migrated** (Task 5) | Standard pattern |
| 11 | `source/dag_approval_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~247 | ✅ **Migrated** (Task 5) | Standard pattern |
| 12 | `source/pwa_scan_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~1,881 | ✅ **Migrated** (Task 5) | Standard pattern |
| 13 | `source/exceptions_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~298 | ✅ **Migrated** (Task 5) | Standard pattern |
| 14 | `source/dashboard_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~773 | ✅ **Migrated** (Task 5) | Standard pattern |
| 15 | `source/tenant_users_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~893 | ✅ **Migrated** (Task 5) | Standard pattern |
| 16 | `source/routing.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~642 | ✅ **Migrated** (Task 3) | Standard pattern |
| 17 | `source/mo.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~1,013 | ✅ **Migrated** (Task 5) | Standard pattern |
| 18 | `source/products.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~3,077 | ✅ **Migrated** (Task 5) | Standard pattern |
| 19 | `source/classic_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~1,021 | ✅ **Migrated** (Task 5) | Standard pattern |
| 20 | `source/people_api.php` | API | `TenantApiBootstrap::init()` | `$db->getTenantDb()` | `json_error/json_success` | ✅ | ~261 | ✅ **Migrated** (Task 5) | Standard pattern |

**Note:** ยังมี APIs อื่นๆ อีก ~33 ไฟล์ที่ใช้ pattern คล้ายกัน (ดูรายละเอียดใน section 1.2)

### 1.2 Common Patterns Found

#### Pattern A: Standard Tenant API Setup (Most Common)
```php
session_start();
require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/global_function.php';
require_once __DIR__ . '/model/member_class.php';
require_once __DIR__ . '/permission.php';

use BGERP\Helper\DatabaseHelper;
use BGERP\Helper\RateLimiter;

// Auth
$objMemberDetail = new memberDetail();
$member = $objMemberDetail->thisLogin();
if (!$member) {
    json_error('unauthorized', 401, ['app_code' => 'AUTH_401_UNAUTHORIZED']);
}

// Org Resolution
$org = resolve_current_org();
if (!$org) {
    json_error('no_org', 403, ['app_code' => 'XXX_403_NO_ORG']);
}

// DB Setup
$tenantDb = tenant_db($org['code']);
$db = new DatabaseHelper($tenantDb);
```

**Files using this pattern:** ~45+ files

#### Pattern B: With Rate Limiting & Maintenance Check
```php
// ... (same as Pattern A) ...

// Maintenance
if (file_exists(__DIR__ . '/../storage/maintenance.flag')) {
    header('Retry-After: 60');
    json_error('service_unavailable', 503, ['app_code' => 'CORE_503_MAINT']);
}

// Rate Limiting
RateLimiter::check($member, 120, 60, 'api_name');

// ... (org + DB setup) ...
```

**Files using this pattern:** ~30+ files

#### Pattern C: With Correlation ID
```php
$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
header('X-Correlation-Id: ' . $cid);
```

**Files using this pattern:** ~25+ files

---

## 2. Helper Classes Inventory

### 2.1 Existing Helper Classes (source/BGERP/Helper/)

| Class Name | File Path | Purpose | Used By Bootstrap? |
|------------|-----------|---------|-------------------|
| `DatabaseHelper` | `source/BGERP/Helper/DatabaseHelper.php` | Database operations with prepared statements | ✅ **YES** - Required |
| `RateLimiter` | `source/BGERP/Helper/RateLimiter.php` | Rate limiting per user/tenant | ❌ Optional |
| `RequestValidator` | `source/BGERP/Helper/RequestValidator.php` | Request validation | ❌ Optional |
| `Idempotency` | `source/BGERP/Helper/Idempotency.php` | Idempotency key handling | ❌ Optional |
| `JsonNormalizer` | `source/BGERP/Helper/JsonNormalizer.php` | JSON normalization | ❌ Optional |
| `CacheHelper` | `source/BGERP/Helper/CacheHelper.php` | Caching utilities | ❌ Optional |
| `Metrics` | `source/BGERP/Helper/Metrics.php` | Metrics collection | ❌ Optional |
| `ProductGraphBindingHelper` | `source/BGERP/Helper/ProductGraphBindingHelper.php` | Product-graph binding | ❌ No |
| `ProductionBindingHelper` | `source/BGERP/Helper/ProductionBindingHelper.php` | Production binding | ❌ No |
| `SerialSaltHelper` | `source/BGERP/Helper/SerialSaltHelper.php` | Serial salt management | ❌ No |
| `TempIdHelper` | `source/BGERP/Helper/TempIdHelper.php` | Temporary ID generation | ❌ No |

### 2.2 Missing Helper Classes (Required for Bootstrap)

| Class Name | Status | Purpose | Implementation Notes |
|------------|--------|---------|---------------------|
| `BGERP\Helper\OrgResolver` | ✅ **COMPLETED** (Task 2) | Wrap `resolve_current_org()` function | ✅ Implemented: `resolveCurrentOrg()` static method |
| `BGERP\Helper\JsonResponse` | ✅ **COMPLETED** (Task 2) | Wrap `json_error()` / `json_success()` functions | ✅ Implemented: `error()` / `success()` static methods |
| `BGERP\Helper\TenantConnection` | ✅ **COMPLETED** (Task 2) | Wrap `tenant_db()` function | ✅ Implemented: `forOrgCode()` static method |

**Implementation Details:**
- **File:** `source/BGERP/Helper/OrgResolver.php` (19 lines)
- **File:** `source/BGERP/Helper/JsonResponse.php` (48 lines)
- **File:** `source/BGERP/Helper/TenantConnection.php` (42 lines)
- **File:** `source/BGERP/Bootstrap/TenantApiBootstrap.php` (116 lines)

### 2.3 Function-Based Helpers (Current State)

| Function | Location | Usage Count | Migration Target |
|----------|----------|-------------|-----------------|
| `resolve_current_org()` | `config.php` | 53 files | `BGERP\Helper\OrgResolver::resolveCurrentOrg()` |
| `tenant_db()` | `config.php` | 52 files | `BGERP\Helper\TenantConnection::forOrgCode()` |
| `json_error()` | `global_function.php` | 59 files | `BGERP\Helper\JsonResponse::error()` |
| `json_success()` | `global_function.php` | 59 files | `BGERP\Helper\JsonResponse::success()` |
| `core_db()` | `config.php` | Multiple | Keep as-is (core DB, not tenant) |

---

## 3. PSR-4 Autoloading Analysis

### 3.1 Current PSR-4 Usage

**APIs using `use BGERP\` statements:** 83 files

**Common imports:**
- `use BGERP\Helper\DatabaseHelper;` - Most common
- `use BGERP\Helper\RateLimiter;` - Very common
- `use BGERP\Helper\RequestValidator;` - Common
- `use BGERP\Service\*` - Various services

### 3.2 Require Patterns

**APIs using `require_once` for helpers:** ~13 files (legacy pattern)

**Common require patterns:**
```php
require_once __DIR__ . '/../vendor/autoload.php';  // Composer autoload
require_once __DIR__ . '/../config.php';            // Config + functions
require_once __DIR__ . '/global_function.php';      // Global functions
require_once __DIR__ . '/model/member_class.php';    // Member class
require_once __DIR__ . '/permission.php';            // Permission functions
```

**Note:** `config.php` is already in `composer.json` autoload files, so `require_once` is redundant but harmless.

### 3.3 Composer Autoload Configuration

From `composer.json`:
```json
{
  "autoload": {
    "psr-4": {
      "BGERP\\": "source/BGERP/"
    },
    "files": [
      "config.php",
      "source/permission.php",
      "source/helper/LogHelper.php",
      "source/utils/provision.php"
    ]
  }
}
```

**Status:** ✅ PSR-4 configured correctly  
**Note:** `global_function.php` is NOT in autoload files (intentional - functions are loaded via require_once)

---

## 4. Variable Naming Patterns

### 4.1 Database Connection Variables

| Variable Name | Type | Usage Count | Notes |
|--------------|------|-------------|-------|
| `$db` | `DatabaseHelper` | ~45 files | ✅ **Standard** - Should be used by Bootstrap |
| `$tenantDb` | `mysqli` | ~50 files | ⚠️ **Legacy** - Should be internal to Bootstrap |
| `$coreDb` | `mysqli` | ~10 files | ✅ Keep (core DB, not tenant) |
| `$conn` | `mysqli` | ~5 files | ⚠️ **Legacy** - Should migrate to `$db` |
| `$mysqli` | `mysqli` | ~3 files | ⚠️ **Legacy** - Should migrate to `$db` |

### 4.2 Organization Variables

| Variable Name | Type | Usage Count | Notes |
|--------------|------|-------------|-------|
| `$org` | `array` | ~53 files | ✅ **Standard** - Should be provided by Bootstrap |
| `$currentOrg` | `array` | ~2 files | ⚠️ **Rare** - Should standardize to `$org` |

---

## 5. Header & Timezone Patterns

### 5.1 Content-Type Headers

**APIs setting `Content-Type: application/json`:** ~40+ files

**Patterns found:**
- `header('Content-Type: application/json; charset=utf-8');` - Most common
- `header('Content-Type: application/json');` - Some files
- `json_success()` / `json_error()` functions also set headers (in `global_function.php`)

**Risk:** Duplicate header setting (function + manual header)

### 5.2 Timezone

**APIs setting timezone:** 0 files (using global timezone from `config.php`)

**Current:** `date_default_timezone_set('Asia/Bangkok')` in `config.php`

**Bootstrap should:** Use same timezone (no change needed)

### 5.3 Other Headers

- `X-Correlation-Id` - ~25 files
- `Retry-After` (maintenance mode) - ~30 files
- `Cache-Control` - Set by `json_success()` / `json_error()` functions

---

## 6. Risk & Attention List

### 6.1 High-Risk Files

#### 1. `source/dag_token_api.php`
- **Lines:** ~3,314 lines
- **Risk Level:** 🔴 **CRITICAL**
- **Issues:**
  - Very large file with complex business logic
  - Multiple patterns mixed (org resolution, DB, headers, business logic)
  - Uses `resolve_current_org()`, `tenant_db()`, `DatabaseHelper`
  - Has extensive guardrails and invariants documented
  - **Recommendation:** Refactor carefully, test thoroughly

#### 2. `source/team_api.php`
- **Lines:** ~1,580 lines
- **Risk Level:** 🟡 **MEDIUM**
- **Issues:**
  - **Duplicate org resolution:** `resolve_current_org()` called twice (lines 65 and 80)
  - Uses `DatabaseHelper` correctly
  - **Recommendation:** Fix duplicate call during migration

#### 3. `source/hatthasilpa_operator_api.php`
- **Lines:** ~289 lines
- **Risk Level:** 🟢 **LOW**
- **Issues:**
  - Standard pattern, clean structure
  - **Recommendation:** Safe to migrate early (good candidate for Batch A)

### 6.2 Pattern Inconsistencies

1. **Duplicate Org Resolution**
   - `team_api.php` calls `resolve_current_org()` twice
   - Should be fixed during migration

2. **Header Setting Duplication**
   - Some APIs set `Content-Type` manually AND via `json_success()` / `json_error()`
   - Bootstrap should handle headers once

3. **Variable Naming**
   - Mix of `$db` (DatabaseHelper) and `$tenantDb` (mysqli)
   - Bootstrap should standardize to `$db` (DatabaseHelper)

### 6.3 Files Requiring Special Attention

- **Large files (>1000 lines):** May need refactoring before migration
- **Files with custom error handling:** May conflict with Bootstrap error handling
- **Files using both `$db` and `$tenantDb`:** Need careful migration

---

## 7. Migration Strategy Recommendations

### 7.1 Batch Grouping

#### **Batch A: Low-Risk, Standard Pattern** ✅ **COMPLETED (Task 3+4)**
- ✅ `hatthasilpa_operator_api.php` (~289 lines) - **Migrated (Task 3)**
- ✅ `api_template.php` (template file) - **Migrated (Task 3)**
- ✅ `dag_routing_api.php` (~6,996 lines) - **Migrated + Refactored (Task 3+4)**
- ✅ `routing.php` (~642 lines) - **Migrated (Task 3)**
- ✅ `assignment_api.php` (~1,501 lines) - **Migrated + Refactored (Task 3+4)**
- ✅ `assignment_plan_api.php` (~1,077 lines) - **Migrated (Task 3)**

**Status:**
- ✅ All Batch A APIs migrated to `TenantApiBootstrap::init()`
- ✅ Legacy query patterns removed (Task 4)
- ✅ Smoke test validates bootstrap usage
- ✅ Syntax check passed for all files

**Criteria:**
- ✅ Standard pattern (org + DB + headers)
- ✅ Uses `DatabaseHelper` correctly
- ✅ No complex business logic in setup
- ✅ < 500 lines (some exceptions: dag_routing_api.php, assignment_api.php)

#### **Batch B: Medium-Risk** ✅ **COMPLETED (Task 5)**
- ✅ `team_api.php` (fixed duplicate org resolution) - **Migrated (Task 5)**
- ✅ `dag_approval_api.php` - **Migrated (Task 5)**
- ✅ `token_management_api.php` - **Migrated (Task 5)**
- ✅ `trace_api.php` - **Migrated (Task 5)**
- ✅ `pwa_scan_api.php` - **Migrated (Task 5)**
- ✅ `exceptions_api.php` - **Migrated (Task 5)**
- ✅ `dashboard_api.php` - **Migrated (Task 5)**
- ✅ `tenant_users_api.php` - **Migrated (Task 5)**
- ✅ `mo.php` - **Migrated (Task 5)**
- ✅ `products.php` - **Migrated (Task 5)**
- ✅ `classic_api.php` - **Migrated (Task 5)**
- ✅ `people_api.php` - **Migrated (Task 5)**
- ✅ `hatthasilpa_jobs_api.php` - **Migrated (Task 5)**
- ✅ `hatthasilpa_job_ticket.php` - **Migrated (Task 5)**

**Status:**
- ✅ All Batch B APIs migrated to `TenantApiBootstrap::init()`
- ✅ Duplicate org resolution fixed in `team_api.php`
- ✅ All `resolve_current_org()` calls removed from business logic
- ✅ Legacy patterns removed (tenant_db, new DatabaseHelper, new mysqli)
- ✅ Syntax check passed for all files
- ✅ Smoke test validates bootstrap usage

#### **Batch C: High-Risk** ✅ **COMPLETED (Task 6)**
- ✅ `dag_token_api.php` (3,314 lines - **CRITICAL**) - **Migrated (Task 6)**
- Other large/complex files (> 2000 lines or complex business logic)

**Note:** `hatthasilpa_jobs_api.php` and `hatthasilpa_job_ticket.php` were migrated in Task 5 (Batch B) despite their size, as they follow standard patterns.

**Status:**
- ✅ `dag_token_api.php` migrated to `TenantApiBootstrap::init()`
- ✅ All legacy patterns removed (`resolve_current_org()`, `tenant_db()`, `new DatabaseHelper()`, `new mysqli()`)
- ✅ All guardrails and invariants preserved (no business logic changes)
- ✅ Syntax check passed
- ✅ Smoke test validates bootstrap usage

**Criteria:**
- 🔴 Very large files (> 3000 lines)
- 🔴 Complex business logic
- 🔴 Multiple patterns
- 🔴 Critical business functions

### 7.2 Migration Order

1. ✅ **Task 1:** Discovery & Mapping (Completed 2025-11-18)
2. ✅ **Task 2:** Create Helper Classes (OrgResolver, JsonResponse, TenantConnection) (Completed 2025-11-18)
3. ✅ **Task 3:** Implement `TenantApiBootstrap` class (PSR-4) + Migrate Batch A APIs (Completed 2025-11-18)
4. ✅ **Task 4:** Legacy Query Refactor (Batch A/B) (Completed 2025-11-18)
5. ✅ **Task 5:** Batch B Tenant API Migration (Completed 2025-11-18)
6. ✅ **Task 6:** Batch C Tenant API Migration - dag_token_api.php (Completed 2025-11-18)
7. ✅ **Task 6.1:** Batch D Tenant API Migration (Completed 2025-11-18)
8. ⏳ **Task 7:** Final cleanup legacy patterns (remove duplicate code, standardize) (Pending)

---

## 8. Helper Functions Location Reference

### 8.1 Current Function Locations

| Function | File | Line Range | Type |
|----------|------|------------|------|
| `resolve_current_org()` | `config.php` | ~265-381 | Global function |
| `tenant_db()` | `config.php` | ~242-260 | Global function |
| `core_db()` | `config.php` | ~205-216 | Global function |
| `json_error()` | `global_function.php` | ~266-295 | Global function |
| `json_success()` | `global_function.php` | ~226-264 | Global function |

### 8.2 Migration Path

**Current:**
```php
$org = resolve_current_org();
$tenantDb = tenant_db($org['code']);
$db = new DatabaseHelper($tenantDb);
json_error('message', 400, ['app_code' => 'XXX']);
```

**Target (via Bootstrap):**
```php
\BGERP\Bootstrap\TenantApiBootstrap::init();
// Now available: $org, $db (DatabaseHelper)
// Use: JsonResponse::error('message', 400, ['app_code' => 'XXX']);
```

---

## 9. Success Criteria Checklist

- [x] ✅ Complete inventory of tenant-scoped APIs
- [x] ✅ Identified all Helper classes (existing + missing)
- [x] ✅ Documented current patterns (org, DB, headers, JSON)
- [x] ✅ Analyzed PSR-4 readiness
- [x] ✅ Identified high-risk files
- [x] ✅ Proposed migration batches (A, B, C)
- [x] ✅ Documented variable naming patterns
- [x] ✅ No code changes made (pure discovery)

---

## 10. Next Steps

1. **Review this report** with team
2. **Approve migration strategy** (Batch A → B → C)
3. **Create Task 2:** Implement Helper Classes (OrgResolver, JsonResponse, TenantConnection)
4. **Create Task 3:** Implement TenantApiBootstrap class
5. **Create Task 4+:** Migrate APIs in batches

---

---

## 11. Implementation Progress Summary

### 11.1 Completed Tasks

#### ✅ Task 1: Discovery & Mapping (2025-11-18)
- Complete inventory of 158 PHP files
- Identified 53 tenant-scoped APIs
- Documented patterns and risks
- Proposed migration strategy

#### ✅ Task 2: PSR-4 Helper Classes (2025-11-18)
- Created `BGERP\Helper\OrgResolver` (19 lines)
- Created `BGERP\Helper\JsonResponse` (48 lines)
- Created `BGERP\Helper\TenantConnection` (42 lines)
- Created `BGERP\Bootstrap\TenantApiBootstrap` (116 lines)
- All classes use PSR-4 autoloading
- All classes wrap legacy functions (backward compatible)

#### ✅ Task 3: API Migration - Batch A (2025-11-18)
- Migrated 6 APIs to use `TenantApiBootstrap::init()`
- Files migrated:
  1. `source/api_template.php`
  2. `source/routing.php`
  3. `source/assignment_api.php`
  4. `source/assignment_plan_api.php`
  5. `source/dag_routing_api.php`
  6. `source/hatthasilpa_operator_api.php`
- All files pass syntax check
- Smoke test validates bootstrap usage

#### ✅ Task 4: Legacy Query Refactor - Batch A/B (2025-11-18)
- Refactored `source/assignment_api.php` (1,501 lines)
  - Converted 19 prepared statements
  - SELECT → `$db->fetchAll()` / `$db->fetchOne()`
  - INSERT/UPDATE/DELETE → `$db->execute()` or mysqli for complex queries
  - DDL queries → mysqli via `$db->getTenantDb()`
- Refactored `source/dag_routing_api.php` (6,996 lines)
  - Converted SELECT queries
  - DDL queries → mysqli via `$db->getTenantDb()`
- Updated smoke test to detect legacy patterns
- All legacy patterns removed from Batch A/B APIs

#### ✅ Task 5: Batch B Tenant API Migration (2025-11-18)
- Migrated 14 APIs to use `TenantApiBootstrap::init()`
- Files migrated:
  1. `source/token_management_api.php` (~802 lines)
  2. `source/trace_api.php` (~2,930 lines)
  3. `source/pwa_scan_api.php` (~1,881 lines)
  4. `source/dag_approval_api.php` (~247 lines)
  5. `source/exceptions_api.php` (~298 lines)
  6. `source/dashboard_api.php` (~773 lines)
  7. `source/tenant_users_api.php` (~893 lines)
  8. `source/mo.php` (~1,013 lines)
  9. `source/products.php` (~3,077 lines)
  10. `source/classic_api.php` (~1,021 lines)
  11. `source/people_api.php` (~261 lines)
  12. `source/hatthasilpa_jobs_api.php` (~2,064 lines)
  13. `source/hatthasilpa_job_ticket.php` (~1,933 lines)
  14. `source/team_api.php` (~1,580 lines) - **Fixed duplicate org resolution**
- All files pass syntax check
- Smoke test validates bootstrap usage
- Legacy patterns removed (`resolve_current_org()`, `tenant_db()`, `new DatabaseHelper()`, `new mysqli()`)
- Special handling: `team_api.php` duplicate org resolution fixed
- Helper functions that create `DatabaseHelper` from `mysqli` parameter are acceptable (service factory pattern)

#### ✅ Task 6: Batch C Tenant API Migration - dag_token_api.php (2025-11-18)
- Migrated critical file `dag_token_api.php` (~3,314 lines) to use `TenantApiBootstrap::init()`
- **CRITICAL FILE** - Core of Hatthasilpa DAG Token Engine
- Changes made:
  1. Added `use BGERP\Bootstrap\TenantApiBootstrap;`
  2. Replaced `resolve_current_org()` + `tenant_db()` with `TenantApiBootstrap::init()`
  3. Removed all `new DatabaseHelper()` instances (2 locations)
  4. Fixed `resolve_current_org()` call in business logic (1 location)
  5. Updated `handleGetWorkQueue()` to use `$db` from bootstrap
- All guardrails and invariants preserved:
  - TOKEN/NODE INVARIANTS maintained
  - TRANSACTION & DB SAFETY maintained
  - WORK SESSION & TOKEN LOCK maintained
  - ASSIGNMENT RULES maintained
  - NODE TYPE POLICY maintained
- No business logic changes - only core setup and DB access patterns
- Syntax check passed
- Smoke test validates bootstrap usage
- Legacy patterns completely removed

#### ✅ Task 6.1: Batch D Tenant API Migration (2025-11-18)
- Migrated 19 remaining tenant-scoped APIs to use `TenantApiBootstrap::init()`
- Files migrated:
  1. `source/qc_rework.php` - QC Rework API
  2. `source/purchase_rfq.php` - Purchase RFQ API
  3. `source/dashboard.php` - Dashboard API
  4. `source/sales_report.php` - Sales Report API
  5. `source/grn.php` - GRN (Goods Receipt Note) API
  6. `source/adjust.php` - Inventory Adjustment API
  7. `source/issue.php` - Issue/Return API
  8. `source/transfer.php` - Transfer API
  9. `source/dashboard_qc_metrics.php` - Dashboard QC Metrics API
  10. `source/work_centers.php` - Work Centers API
  11. `source/materials.php` - Materials API (fixed resolve_current_org() in upload_asset)
  12. `source/bom.php` - Bill of Materials API
  13. `source/locations.php` - Locations API
  14. `source/stock_on_hand.php` - Stock On Hand API
  15. `source/product_categories.php` - Product Categories API
  16. `source/uom.php` - Units of Measure API
  17. `source/stock_card.php` - Stock Card API
  18. `source/refs.php` - Reference Data API
  19. `source/warehouses.php` - Warehouses API
  20. `source/hatthasilpa_schedule.php` - Hatthasilpa Schedule API
- All files pass syntax check
- Smoke test validates bootstrap usage (40 files total)
- Legacy patterns removed (`resolve_current_org()`, `tenant_db()`, `new DatabaseHelper()`, `new mysqli()`)
- Special fix: `materials.php` line 470 - removed `resolve_current_org()` call in `upload_asset` action

### 11.2 Current Statistics

**APIs Migrated:** 40 / 53 (75.5%)
- Batch A: 6 / 6 (100%) ✅
- Batch B: 14 / 14 (100%) ✅
- Batch C: 1 / 1 (100%) ✅ (dag_token_api.php - CRITICAL)
- Batch D: 19 / 19 (100%) ✅
- Remaining: ~13 APIs (mostly smaller files or special cases)

**Legacy Patterns Removed:**
- ✅ `resolve_current_org()` - Removed from migrated APIs
- ✅ `tenant_db()` - Removed from migrated APIs
- ✅ `new DatabaseHelper()` - Removed from migrated APIs
- ✅ `new mysqli()` - Removed from migrated APIs
- ✅ `$mysqli->query()` - Only allowed via `$db->getTenantDb()`

**Helper Classes:**
- ✅ 3 / 3 required classes implemented (100%)
- ✅ 1 / 1 bootstrap class implemented (100%)

### 11.3 Core / Platform Layer (Non-Tenant, Out of Scope for Task 1–6.1)

**Core / Platform Files (Excluded from TenantApiBootstrap scope):**

These files are part of the Bellavier / Hatthasilpa ERP core platform and are **NOT** tenant-scoped APIs. They are excluded from TenantApiBootstrap migration in this phase.

1. `source/admin_org.php` - Admin Organizations Management (Platform-level)
2. `source/admin_rbac.php` - Admin RBAC Management (Platform + Tenant)
3. `source/bootstrap_migrations.php` - Migration Bootstrap (Core)
4. `source/member_login.php` - Member Login API (Core Authentication)
5. `source/permission.php` - Permission Helper (Core)
6. `source/platform_dashboard_api.php` - Platform Dashboard (Platform-level)
7. `source/platform_health_api.php` - Platform Health Check (Platform-level)
8. `source/platform_migration_api.php` - Platform Migration API (Platform-level)
9. `source/platform_serial_metrics_api.php` - Platform Serial Metrics (Platform-level)
10. `source/run_tenant_migrations.php` - Tenant Migrations Runner (Tenant-scoped but Migration tool)

**Status:**
- ✅ All files marked with "CORE / PLATFORM FILE (NON-TENANT API)" header
- ✅ Protected from accidental TenantApiBootstrap migration
- ⏳ A dedicated Core/Platform bootstrap will be designed in a future task (Task 9+)

**Reason:**
- These files are NOT tenant-scoped Hatthasilpa APIs
- They handle platform-level operations (admin, login, RBAC, migrations, platform metrics)
- They MUST NOT be migrated to TenantApiBootstrap in this phase
- They will have a separate CoreBootstrap / PlatformBootstrap design in future tasks

### 11.4 Core / Platform Bootstrap Design (Task 9)

**Status:** ✅ COMPLETED (2025-11-18)

**Design Document:** `docs/bootstrap/core_platform_bootstrap.design.md`

**Key Design Decisions:**
- **CoreApiBootstrap**: Separate bootstrap for Core/Platform layer (non-tenant APIs)
- **Multiple Modes**: Auth required, public, platform admin, CLI mode, tenant context optional
- **Preserve Existing Logic**: All auth/session/permission logic must work identically
- **Gradual Migration**: Risk-based migration phases (Group B → Group A → Group C)

**Migration Strategy:**
1. **Phase 1 (Low Risk):** Platform APIs (Group B) - `platform_dashboard_api.php`, `platform_health_api.php`, `platform_migration_api.php`
2. **Phase 2 (Medium Risk):** Platform Serial Metrics - `platform_serial_metrics_api.php`
3. **Phase 3 (High Risk):** Admin APIs (Group A) - `admin_org.php`, `admin_rbac.php`
4. **Phase 4 (Very High Risk):** Auth & Permission - `member_login.php`, `permission.php` (may keep as-is)
5. **Phase 5 (High Risk):** Migration Tools (Group C) - `bootstrap_migrations.php`, `run_tenant_migrations.php`

**Interface Design:**
```php
CoreApiBootstrap::init([
    'requireAuth'        => true,
    'requirePlatformAdmin'=> false,
    'requiredPermissions'=> [],
    'requireTenant'      => false,
    'jsonResponse'       => true,
    'cliMode'            => false,
]) → [$member, $coreDb, $tenantDb, $org, $cid]
```

**See:** `docs/bootstrap/core_platform_bootstrap.design.md` for complete specification

### 11.5 Core / Platform Bootstrap Implementation (Task 10)

**Status:** ✅ COMPLETED (2025-11-18)

**Implementation Details:**
- **CoreApiBootstrap.php:** ✅ Implemented
  - Location: `source/BGERP/Bootstrap/CoreApiBootstrap.php`
  - All modes implemented: auth required, public, platform admin, CLI mode, tenant context optional
  - All options supported: `requireAuth`, `requirePlatformAdmin`, `requiredPermissions`, `requireTenant`, `jsonResponse`, `cliMode`, `correlationId`

- **Unit Tests:** ✅ Added
  - Location: `tests/bootstrap/CoreApiBootstrapTest.php`
  - 9 tests, 26 assertions, all passing
  - Tests cover: class existence, method signatures, CLI mode, return structure

- **Behavior:** ✅ Matches Design
  - All 5 modes functional
  - JSON and plain text response support
  - Maintenance mode check
  - Correlation ID generation
  - Core DB and optional Tenant DB initialization

**See:** `docs/bootstrap/core_platform_bootstrap.design.md` Section 10 for complete implementation status

### 11.6 Core / Platform API Migration (Task 11)

**Status:** ✅ COMPLETED (2025-11-18)

**Files Migrated:** 8 / 10 Core/Platform API files

**Batch A (Simple - 2 files):**
- ✅ `platform_health_api.php` - Uses `requireAuth=true, requirePlatformAdmin=true, jsonResponse=true`
- ✅ `platform_dashboard_api.php` - Uses `requireAuth=true, requirePlatformAdmin=true, jsonResponse=true`

**Batch B (Admin - 2 files):**
- ✅ `admin_org.php` - Uses `requireAuth=true, jsonResponse=true` (custom permission checks preserved)
- ✅ `admin_rbac.php` - Uses `requireAuth=true, jsonResponse=true` (custom permission checks preserved)

**Batch C (Complex - 3 files):**
- ✅ `platform_migration_api.php` - Uses `requireAuth=true, requirePlatformAdmin=true, jsonResponse=true`
- ✅ `platform_serial_metrics_api.php` - Uses `requireAuth=true, requireTenant=true, jsonResponse=true`
- ✅ `run_tenant_migrations.php` - Uses `requireAuth=true, jsonResponse=true` (custom permission checks preserved)

**Special Case (1 file):**
- ✅ `member_login.php` - Uses `requireAuth=false, jsonResponse=false` (public endpoint, plain text response)

**Files Not Migrated (Helper Files):**
- `bootstrap_migrations.php` - Helper file (CLI tool, not API endpoint)
- `permission.php` - Helper file (function library, not API endpoint)

**Migration Results:**
- All migrated files use `CoreApiBootstrap::init()` with appropriate options
- Business logic preserved (no changes to auth, permission, response format)
- Custom permission checks preserved where needed
- Rate limiting and additional setup preserved
- All files pass syntax check ✅

### 11.7 Next Steps

1. **Task 7:** Final cleanup and standardization
   - Remove duplicate code
   - Standardize patterns across all migrated Tenant APIs
   - Update documentation
2. **Task 8:** Core / Platform API Audit & Protection (✅ COMPLETED)
   - Core/Platform files classified and protected
   - Header comments added
   - Documentation updated
3. **Task 9:** Core / Platform Bootstrap Design (✅ COMPLETED)
   - Design specification complete
   - Interface defined
   - Migration strategy defined
4. **Task 10:** Core / Platform Bootstrap Implementation (✅ COMPLETED)
   - CoreApiBootstrap class implemented
   - Unit tests added and passing
5. **Task 11:** Core / Platform API Migration (✅ COMPLETED)
   - 8 Core/Platform API files migrated to CoreApiBootstrap
   - All business logic preserved
   - Ready for production use
6. **Future Tasks:**
   - Task 12+: Platform API full modernization (if needed)
   - Add integration tests for critical paths
   - Performance optimization review

---

### ✅ Task 17: System-Wide Integration Tests (2025-11-19)

**Status:** ✅ COMPLETED

**Created Files:**
- `tests/Integration/SystemWide/BootstrapTenantInitTest.php` - 3 tests
- `tests/Integration/SystemWide/BootstrapCoreInitTest.php` - 3 tests
- `tests/Integration/SystemWide/RateLimiterSystemWideTest.php` - 3 tests (incomplete - requires heavy load)
- `tests/Integration/SystemWide/JsonErrorFormatSystemWideTest.php` - 4 tests
- `tests/Integration/SystemWide/JsonSuccessFormatSystemWideTest.php` - 5 tests
- `tests/Integration/SystemWide/AuthGlobalCasesSystemWideTest.php` - 5 tests
- `tests/Integration/SystemWide/EndpointSmokeSystemWideTest.php` - 14 tests (data-driven)
- `tests/Integration/SystemWide/EndpointPermissionMatrixSystemWideTest.php` - 6+ tests (data-driven)

**Total Tests:** 30+ integration tests

**Coverage:**
- Tenant APIs: ~17% (9/53 migrated APIs)
- Platform APIs: ~42% (5/12 migrated APIs)
- Overall: ~20% (14/65 migrated APIs)

**Test Categories:**
- Bootstrap initialization: ✅ 6 tests
- Rate limiting: ⚠️ 3 tests (incomplete)
- JSON format consistency: ✅ 9 tests
- Authentication: ✅ 5 tests
- Endpoint smoke: ✅ 14 tests
- Permission matrix: ✅ 6+ tests

**Known Limitations:**
- Rate limit full test requires 60+ rapid calls (marked incomplete)
- Cross-tenant test requires multi-tenant setup (marked skipped)
- Some APIs may use legacy error format (marked incomplete with TODO)

**Next Steps:**
- Task 18 (Security Review) can use these tests to verify security fixes
- Expand coverage to all 65+ migrated APIs
- Add dedicated performance and multi-tenant test suites

---

### ✅ Task 18: Security Review & Hardening Pass (2025-11-19)

**Status:** ✅ COMPLETED

**Security Audit Results:**
- ✅ Log Sensitivity: No sensitive data logged (platform_serial_salt_api.php, LogHelper.php)
- ✅ CSRF Protection: platform_serial_salt_api.php protected
- ✅ Rate Limiting: All APIs protected (40+ APIs + member_login.php custom implementation)
- ✅ File Permissions: Serial salt file 0600 + .htaccess protection
- ✅ Error Handling: Standardized, clean error messages, no stack traces
- ✅ Session Management: Bootstrap layers handle properly

**Tests Created:**
- `tests/Integration/SystemWide/SecurityAuditSystemWideTest.php` - 5 security audit tests

**Known Risks Documented:**
- Tenant APIs - Limited CSRF protection (low-medium risk, session auth provides protection)
- Upload directories - Not audited (low risk, out of scope)
- Cookie security - Server configuration dependent (documented)
- Remember-me tokens - Not audited (not found in scope)

**Documentation:**
- `docs/security/task18_security_notes.md` - Complete security review documentation

---

**Report Status:** ✅ Complete + ✅ Implementation In Progress  
**Last Updated:** 2025-11-19 (Updated after Task 18 completion)  
**Current Phase:** Task 18 Complete, Ready for Task 19 (Next Phase)

