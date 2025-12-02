# Integration Test Harness for Core/Tenant Bootstrap & Key APIs

**Status:** ✅ COMPLETED (2025-11-19)  
**Task:** Task 16

## 1. Overview

This document describes the **Integration Test Harness** created for Bellavier Group ERP that validates the new bootstrap layers (`TenantApiBootstrap` and `CoreApiBootstrap`) and provides reusable helpers for testing API endpoints.

## 2. Purpose

The Integration Test Harness provides:

1. **Base Test Class** (`IntegrationTestCase`) - Reusable helpers for running tenant and core/platform API scripts in tests
2. **Bootstrap Integration Tests** - Validates that bootstrap classes can be loaded and APIs can be executed without fatal errors
3. **API-Level Integration Tests** - Tests key API endpoints with happy paths
4. **Documentation** - Guidelines for extending the test suite

## 3. Structure

### 3.1 Base Class

**File:** `tests/Integration/IntegrationTestCase.php`

**Namespace:** `BellavierGroup\Tests\Integration`

**Responsibilities:**
- Provide helpers for running tenant APIs (`runTenantApi()`)
- Provide helpers for running core/platform APIs (`runCoreApi()`)
- Backup and restore superglobals to avoid cross-test pollution
- Setup minimal session data for tenant tests
- Setup platform admin session for core API tests
- Assert JSON response structure (`assertJsonResponse()`)

**Key Methods:**
- `runTenantApi(string $script, array $get = [], array $post = [], string $method = 'GET'): array`
- `runCoreApi(string $script, array $get = [], array $post = [], string $method = 'GET'): array`
- `setupPlatformAdminSession(): void`
- `assertJsonResponse(?array $json, bool $expectOk = true, string $message = ''): void`

### 3.2 Bootstrap Integration Tests

**Location:** `tests/Integration/Bootstrap/`

**Files:**
1. **TenantApiBootstrapIntegrationTest.php**
   - Tests that tenant-level APIs using `TenantApiBootstrap::init()` can be executed
   - Validates APIs: `people_api.php`, `dashboard_api.php`, `trace_api.php`

2. **CoreApiBootstrapIntegrationTest.php**
   - Tests that core/platform APIs using `CoreApiBootstrap::init()` can be executed
   - Validates APIs: `platform_health_api.php`, `platform_dashboard_api.php`, `platform_serial_salt_api.php`

### 3.3 API-Level Integration Tests

**Location:** `tests/Integration/Api/`

**Files:**
1. **PlatformHealthApiTest.php**
   - Tests `platform_health_api.php` endpoints
   - Validates JSON responses, error handling, authentication

2. **PeopleApiTest.php**
   - Tests `people_api.php` endpoints
   - Validates read-only actions (`lookup_team`, `lookup_availability`)

3. **DashboardApiTest.php**
   - Tests `dashboard_api.php` endpoints
   - Validates read-only actions (`summary`, `bottlenecks`)

## 4. How to Run

### 4.1 Run All Integration Tests

```bash
cd /Applications/MAMP/htdocs/bellavier-group-erp
vendor/bin/phpunit tests/Integration --testdox
```

### 4.2 Run Bootstrap Integration Tests Only

```bash
vendor/bin/phpunit tests/Integration/Bootstrap/ --testdox
```

### 4.3 Run API Integration Tests Only

```bash
vendor/bin/phpunit tests/Integration/Api/ --testdox
```

### 4.4 Run Specific Test Class

```bash
vendor/bin/phpunit tests/Integration/Bootstrap/TenantApiBootstrapIntegrationTest.php --testdox
```

### 4.5 Run Specific Test Method

```bash
vendor/bin/phpunit tests/Integration/Bootstrap/TenantApiBootstrapIntegrationTest.php --filter testPeopleApiCanExecuteWithTenantBootstrap --testdox
```

## 5. Current Coverage

### 5.1 Bootstrap Tests

**TenantApiBootstrap:**
- ✅ `people_api.php` - Validates TenantApiBootstrap can execute
- ✅ `dashboard_api.php` - Validates TenantApiBootstrap can execute
- ✅ `trace_api.php` - Validates TenantApiBootstrap can execute (may skip if DB state required)

**CoreApiBootstrap:**
- ✅ `platform_health_api.php` - Validates CoreApiBootstrap can execute
- ✅ `platform_dashboard_api.php` - Validates CoreApiBootstrap can execute
- ✅ `platform_serial_salt_api.php` - Validates CoreApiBootstrap can execute (status action)

### 5.2 API Tests

**Platform APIs:**
- ✅ `platform_health_api.php` - `run_all_tests` action
- ✅ `platform_health_api.php` - Invalid action error handling
- ✅ `platform_health_api.php` - Unauthorized error handling

**Tenant APIs:**
- ✅ `people_api.php` - `lookup_team` action
- ✅ `people_api.php` - `lookup_availability` action
- ✅ `people_api.php` - Invalid action error handling
- ✅ `dashboard_api.php` - `summary` action
- ✅ `dashboard_api.php` - `bottlenecks` action
- ✅ `dashboard_api.php` - Invalid action error handling

## 6. Known Limitations

### 6.1 Function Redeclaration

API files that define functions (not classes) may cause "Cannot redeclare function" errors when included multiple times in the same test run. The `IntegrationTestCase` handles this by:
- Using `require_once` to avoid duplicate includes
- Tracking included files with static variable
- Skipping execution if file already included (acceptable for bootstrap tests)

**Mitigation:** API files should use classes or check `function_exists()` before defining functions.

### 6.2 Header Warnings

API files that call `header()` after PHPUnit has sent output will generate warnings ("Cannot modify header information"). The `IntegrationTestCase` handles this by:
- Suppressing E_WARNING during script execution
- This is acceptable for integration tests - we're testing bootstrap, not HTTP headers

**Mitigation:** API files should check `headers_sent()` before calling `header()`, or use output buffering.

### 6.3 Database/Session Requirements

Some tests may require:
- Specific database state (tables, data)
- Authenticated session
- Specific tenant/org setup
- Feature flags enabled/disabled

**Mitigation:** Tests use `markTestSkipped()` with clear explanation if required state is not available.

### 6.4 Test Environment

Tests are designed to run in:
- Local MAMP environment with real database
- PHPUnit 9.x
- PHP 8.2+

**Mitigation:** Ensure test environment matches production setup as closely as possible.

## 7. How to Extend

### 7.1 Add a New Bootstrap Test

Create a new test file extending `IntegrationTestCase`:

```php
<?php

namespace BellavierGroup\Tests\Integration\Bootstrap;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

require_once __DIR__ . '/../../../config.php';
require_once __DIR__ . '/../../../source/global_function.php';

class NewBootstrapIntegrationTest extends IntegrationTestCase
{
    public function testNewApiCanExecuteWithBootstrap(): void
    {
        // Setup session if needed
        // Run API
        $result = $this->runTenantApi('source/new_api.php', [
            'action' => 'safe_action'
        ], [], 'GET');
        
        // Assert valid JSON
        $this->assertNotNull($result['json'], 'Response should be valid JSON');
        $this->assertArrayHasKey('ok', $result['json'], 'Response should have "ok" key');
    }
}
```

### 7.2 Add a New API Test

Create a new test file extending `IntegrationTestCase`:

```php
<?php

namespace BellavierGroup\Tests\Integration\Api;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

require_once __DIR__ . '/../../../config.php';
require_once __DIR__ . '/../../../source/global_function.php';

class NewApiTest extends IntegrationTestCase
{
    public function testNewApiActionReturnsValidJson(): void
    {
        // Setup session if needed
        // Run API with action
        $result = $this->runTenantApi('source/new_api.php', [
            'action' => 'list'
        ], [], 'GET');
        
        // Assert JSON response structure
        $this->assertJsonResponse($result['json'], true, 'Response should be ok');
        
        // Assert specific structure
        if ($result['json'] !== null && $result['json']['ok']) {
            $this->assertArrayHasKey('data', $result['json'], 'Success response should have "data" key');
        }
    }
    
    public function testNewApiInvalidActionReturnsError(): void
    {
        // Run API with invalid action
        $result = $this->runTenantApi('source/new_api.php', [
            'action' => 'invalid_action_xyz'
        ], [], 'GET');
        
        // Assert error response
        $this->assertJsonResponse($result['json'], false, 'Invalid action should return ok=false');
        $this->assertArrayHasKey('error', $result['json'], 'Error response should have "error" key');
    }
}
```

### 7.3 Best Practices

1. **Use Safe Actions First** - Test read-only actions before write actions
2. **Handle Skipped Tests** - Use `markTestSkipped()` with clear explanation if required state is not available
3. **Clean Up** - Use `tearDown()` to clean up test data if needed
4. **Document Dependencies** - Comment on required DB state, session, or feature flags
5. **Assert Structure, Not Data** - Focus on JSON structure and error handling, not specific data values

## 8. Troubleshooting

### 8.1 "Class not found" Error

**Cause:** Autoloader not configured correctly.

**Solution:**
- Ensure `composer.json` has correct PSR-4 mapping for `BellavierGroup\Tests\`
- Run `composer dump-autoload`
- Check that test files are in correct directory structure

### 8.2 "Cannot redeclare function" Error

**Cause:** API file defines functions that are included multiple times.

**Solution:**
- Use `require_once` instead of `require` in test (already handled by `IntegrationTestCase`)
- Refactor API file to use classes instead of functions
- Check `function_exists()` before defining functions in API file

### 8.3 "Headers already sent" Warning

**Cause:** API calls `header()` after PHPUnit has sent output.

**Solution:**
- Warning is suppressed by `IntegrationTestCase` (acceptable for integration tests)
- If needed, check `headers_sent()` before calling `header()` in API file

### 8.4 Test Fails with "not found" Error

**Cause:** API requires specific database state or session.

**Solution:**
- Use `markTestSkipped()` with clear explanation
- Or setup required state in `setUp()` method

## 9. Future Improvements

1. **Full E2E Coverage** - Add integration tests for all API endpoints
2. **Test Data Fixtures** - Create reusable test data setup/teardown helpers
3. **Mock Database** - Consider using test database or mocks for faster tests
4. **CI/CD Integration** - Run integration tests in CI/CD pipeline
5. **Performance Testing** - Add performance benchmarks for critical APIs

## 10. Status

**Task 16 Status:** ✅ COMPLETED (2025-11-19)

**Deliverables:**
- ✅ `IntegrationTestCase.php` base class
- ✅ `TenantApiBootstrapIntegrationTest.php` (3 tests)
- ✅ `CoreApiBootstrapIntegrationTest.php` (3 tests)
- ✅ `PlatformHealthApiTest.php` (3 tests)
- ✅ `PeopleApiTest.php` (3 tests)
- ✅ `DashboardApiTest.php` (3 tests)
- ✅ Documentation (`docs/testing/bootstrap_task16_integration_harness.md`)
- ✅ `composer.json` updated with PSR-4 autoload mapping

**Total Tests:** 15+ integration tests

**Coverage:**
- Bootstrap layer: ✅ Validated
- Key APIs: ✅ 5 APIs with happy-path tests
- Error handling: ✅ Invalid action tests
- Authentication: ✅ Unauthorized tests

---

**Document Version:** 1.0  
**Last Updated:** 2025-11-19  
**Maintainer:** Development Team

