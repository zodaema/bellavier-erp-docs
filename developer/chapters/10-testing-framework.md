# Chapter 10 — Testing Framework

**Last Updated:** November 19, 2025  
**Purpose:** Explain all test types added in Tasks 16-17 and how to write tests  
**Audience:** Developers writing tests, AI agents creating test code

---

## Overview

The Bellavier Group ERP testing framework provides comprehensive test coverage for bootstrap layers, system-wide integration, security, and API endpoints. The framework was established in Tasks 16-17 and expanded in subsequent tasks.

**Key Components:**
- `IntegrationTestCase` - Base class for integration tests (Task 16)
- SystemWide tests - System-wide integration tests (Task 17)
- Security audit tests - Security-focused tests (Task 18)
- Bootstrap tests - Bootstrap validation tests
- API tests - Endpoint-specific tests

**Test Coverage:**
- ✅ 30+ system-wide integration tests
- ✅ Bootstrap initialization tests
- ✅ Security audit tests
- ✅ Endpoint smoke tests
- ✅ Permission matrix tests

---

## Key Concepts

### 1. Test Structure

**Test Organization:**
```
tests/
├── Integration/
│   ├── SystemWide/        # System-wide tests (Task 17)
│   ├── Bootstrap/         # Bootstrap tests (Task 16)
│   └── Api/               # API integration tests
└── Unit/                  # Unit tests (no database)
```

**Test Base Classes:**
- `IntegrationTestCase` - Base for all integration tests
- `PHPUnit\Framework\TestCase` - Base for unit tests

### 2. IntegrationTestCase

**Location:** `tests/Integration/IntegrationTestCase.php`  
**Status:** ✅ Created in Task 16

**Purpose:**
Provides reusable helpers for calling APIs from tests in a safe, repeatable way.

**Key Methods:**

#### 1. Run Tenant API

```php
protected function runTenantApi(
    string $script, 
    array $get = [], 
    array $post = [], 
    array $session = []
): array
```

**Usage:**
```php
$result = $this->runTenantApi('products.php', ['action' => 'list']);
$response = $this->assertJsonResponse($result, 200);
```

#### 2. Run Core API

```php
protected function runCoreApi(
    string $script, 
    array $get = [], 
    array $post = [], 
    array $session = []
): array
```

**Usage:**
```php
$result = $this->runCoreApi('platform_health_api.php', ['action' => 'run_all_tests']);
$response = $this->assertJsonResponse($result, 200);
```

#### 3. Assert JSON Response

```php
protected function assertJsonResponse(
    array $result, 
    int $expectedStatusCode = 200
): array
```

**Usage:**
```php
$response = $this->assertJsonResponse($result, 200);
$this->assertTrue($response['ok']);
```

#### 4. Setup Platform Admin Session

```php
protected function setupPlatformAdminSession(): array
```

**Usage:**
```php
$session = $this->setupPlatformAdminSession();
$result = $this->runCoreApi('platform_dashboard_api.php', ['action' => 'summary'], [], $session);
```

### 3. Test Types

**Bootstrap Tests:**
- Validate bootstrap initialization
- Test tenant resolution
- Test platform admin checks

**SystemWide Tests:**
- Test system-wide behavior
- Test JSON format consistency
- Test authentication/authorization
- Test rate limiting
- Test endpoint smoke

**Security Tests:**
- Test security posture
- Test sensitive data handling
- Test CSRF protection
- Test rate limiting

**API Tests:**
- Test specific API endpoints
- Test request/response format
- Test error handling

---

## Core Components

### Bootstrap Tests

**Location:** `tests/Integration/Bootstrap/`

**Test Files:**
- `BootstrapTenantInitTest.php` - Tenant bootstrap tests
- `BootstrapCoreInitTest.php` - Core bootstrap tests

**Purpose:**
Validate that bootstrap layers initialize correctly and can be used consistently in tests.

**Example:**
```php
namespace BellavierGroup\Tests\Integration\Bootstrap;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

class BootstrapTenantInitTest extends IntegrationTestCase
{
    public function testTenantBootstrapReturnsOrgAndDbHelper(): void
    {
        $result = $this->runTenantApi('people_api.php', ['action' => 'list']);
        $response = $this->assertJsonResponse($result, 200);
        $this->assertTrue($response['ok']);
    }
}
```

### SystemWide Tests

**Location:** `tests/Integration/SystemWide/`

**Test Files:**
- `BootstrapTenantInitTest.php` - Tenant bootstrap validation
- `BootstrapCoreInitTest.php` - Core bootstrap validation
- `RateLimiterSystemWideTest.php` - Rate limiting behavior
- `JsonErrorFormatSystemWideTest.php` - Error format consistency
- `JsonSuccessFormatSystemWideTest.php` - Success format consistency
- `AuthGlobalCasesSystemWideTest.php` - Authentication cases
- `EndpointSmokeSystemWideTest.php` - API smoke tests
- `EndpointPermissionMatrixSystemWideTest.php` - Permission matrix
- `SecurityAuditSystemWideTest.php` - Security audit (Task 18)

**Purpose:**
Test system-wide behavior across all APIs to ensure consistency and correctness.

**Example:**
```php
namespace BellavierGroup\Tests\Integration\SystemWide;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

class JsonErrorFormatSystemWideTest extends IntegrationTestCase
{
    public function testTenantBasicApiErrorFormat(): void
    {
        $result = $this->runTenantApi('products.php', ['action' => 'invalid_action']);
        $response = $this->assertJsonResponse($result, 400);
        $this->assertFalse($response['ok']);
        $this->assertArrayHasKey('error', $response);
        $this->assertArrayHasKey('code', $response['error']);
        $this->assertArrayHasKey('message', $response['error']);
    }
}
```

### Security Audit Tests

**Location:** `tests/Integration/SystemWide/SecurityAuditSystemWideTest.php`  
**Status:** ✅ Created in Task 18

**Purpose:**
Test security posture, sensitive data handling, CSRF protection, and rate limiting.

**Test Methods:**
- `testSerialSaltApiDoesNotExposeSalts()` - Verifies salt values not in responses
- `testErrorResponsesDoNotExposeSensitiveData()` - Verifies error messages clean
- `testSerialSaltGenerateRequiresCsrf()` - Verifies CSRF protection
- `testSerialSaltApiHasRateLimiting()` - Verifies rate limiting
- `testErrorResponsesHaveCleanMessages()` - Verifies no stack traces

**Example:**
```php
public function testSerialSaltApiDoesNotExposeSalts(): void
{
    $session = $this->setupPlatformAdminSession();
    $result = $this->runCoreApi('platform_serial_salt_api.php', ['action' => 'status'], [], $session);
    $response = $this->assertJsonResponse($result, 200);
    
    // Verify no salt values in response
    $responseJson = json_encode($response);
    $this->assertStringNotContainsString('salt_value', $responseJson);
    $this->assertStringNotContainsString('secret', $responseJson);
}
```

---

## Writing New Tests

### Step 1: Choose Test Type

**Integration Test (with database):**
- Extends `IntegrationTestCase`
- Uses `runTenantApi()` or `runCoreApi()`
- Tests real API behavior

**Unit Test (no database):**
- Extends `PHPUnit\Framework\TestCase`
- Tests logic only
- Fast execution

### Step 2: Create Test File

**File Location:**
- Integration: `tests/Integration/SystemWide/` or `tests/Integration/Api/`
- Unit: `tests/Unit/`

**File Naming:**
- Format: `{ClassName}Test.php`
- Example: `ProductsApiTest.php`

### Step 3: Write Test Class

**Structure:**
```php
<?php

namespace BellavierGroup\Tests\Integration\Api;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

class ProductsApiTest extends IntegrationTestCase
{
    public function testListProducts(): void
    {
        $result = $this->runTenantApi('products.php', ['action' => 'list']);
        $response = $this->assertJsonResponse($result, 200);
        $this->assertTrue($response['ok']);
        $this->assertArrayHasKey('data', $response);
    }
}
```

### Step 4: Run Tests

**Command:**
```bash
vendor/bin/phpunit tests/Integration/Api/ProductsApiTest.php
```

**With readable output:**
```bash
vendor/bin/phpunit tests/Integration/Api/ProductsApiTest.php --testdox
```

### Step 5: Verify Results

**Expected:**
- All tests passing
- No errors or warnings
- Proper assertions

---

## How AI Should Write Tests

### Golden Rules

1. **Follow Existing Patterns**
   - Use `IntegrationTestCase` base class
   - Follow naming conventions
   - Use existing helper methods

2. **Test Both Success and Failure**
   - Happy path tests
   - Error scenario tests
   - Edge case tests

3. **Use Proper Assertions**
   - `assertTrue()` / `assertFalse()`
   - `assertEquals()` for exact matches
   - `assertArrayHasKey()` for array structure
   - `assertStringContainsString()` for string content

4. **Clean Up Test Data**
   - Use `setUp()` and `tearDown()` methods
   - Clean up test data after tests
   - Don't leave test data in database

5. **Document Test Purpose**
   - Clear test method names
   - Comments for complex tests
   - Document expected behavior

### Example: AI Writing a Test

```php
<?php

namespace BellavierGroup\Tests\Integration\Api;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

class MyApiTest extends IntegrationTestCase
{
    /**
     * Test successful API call
     */
    public function testMyApiSuccess(): void
    {
        // Arrange: Setup test data if needed
        
        // Act: Call API
        $result = $this->runTenantApi('my_api.php', ['action' => 'test']);
        
        // Assert: Verify response
        $response = $this->assertJsonResponse($result, 200);
        $this->assertTrue($response['ok']);
        $this->assertArrayHasKey('data', $response);
    }
    
    /**
     * Test error handling
     */
    public function testMyApiError(): void
    {
        // Act: Call API with invalid input
        $result = $this->runTenantApi('my_api.php', ['action' => 'invalid']);
        
        // Assert: Verify error response
        $response = $this->assertJsonResponse($result, 400);
        $this->assertFalse($response['ok']);
        $this->assertArrayHasKey('error', $response);
    }
}
```

---

## How to Run Selective Tests

### Run All Tests

```bash
vendor/bin/phpunit
```

### Run Specific Suite

```bash
# System-wide tests
vendor/bin/phpunit tests/Integration/SystemWide/

# Bootstrap tests
vendor/bin/phpunit tests/Integration/Bootstrap/

# API tests
vendor/bin/phpunit tests/Integration/Api/

# Unit tests
vendor/bin/phpunit tests/Unit/
```

### Run Specific Test File

```bash
vendor/bin/phpunit tests/Integration/SystemWide/JsonErrorFormatSystemWideTest.php
```

### Run Specific Test Method

```bash
vendor/bin/phpunit --filter testMyApiSuccess tests/Integration/Api/MyApiTest.php
```

### Run with Readable Output

```bash
vendor/bin/phpunit --testdox
```

### Run with Coverage

```bash
vendor/bin/phpunit --coverage-html coverage/
```

---

## Examples

### Example 1: Bootstrap Test

```php
<?php

namespace BellavierGroup\Tests\Integration\Bootstrap;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

class BootstrapTenantInitTest extends IntegrationTestCase
{
    public function testTenantBootstrapReturnsOrgAndDbHelper(): void
    {
        $result = $this->runTenantApi('people_api.php', ['action' => 'list']);
        $response = $this->assertJsonResponse($result, 200);
        $this->assertTrue($response['ok']);
    }
    
    public function testTenantBootstrapSessionContextIsInitialized(): void
    {
        $session = $this->setupPlatformAdminSession();
        $result = $this->runTenantApi('people_api.php', ['action' => 'list'], [], $session);
        $response = $this->assertJsonResponse($result, 200);
        $this->assertTrue($response['ok']);
    }
}
```

### Example 2: SystemWide Test

```php
<?php

namespace BellavierGroup\Tests\Integration\SystemWide;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

class JsonErrorFormatSystemWideTest extends IntegrationTestCase
{
    public function testTenantBasicApiErrorFormat(): void
    {
        $result = $this->runTenantApi('products.php', ['action' => 'invalid_action']);
        $response = $this->assertJsonResponse($result, 400);
        
        $this->assertFalse($response['ok']);
        $this->assertArrayHasKey('error', $response);
        $this->assertArrayHasKey('code', $response['error']);
        $this->assertArrayHasKey('message', $response['error']);
        $this->assertIsString($response['error']['code']);
        $this->assertIsString($response['error']['message']);
    }
}
```

### Example 3: Security Test

```php
<?php

namespace BellavierGroup\Tests\Integration\SystemWide;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

class SecurityAuditSystemWideTest extends IntegrationTestCase
{
    public function testSerialSaltApiDoesNotExposeSalts(): void
    {
        $session = $this->setupPlatformAdminSession();
        $result = $this->runCoreApi('platform_serial_salt_api.php', ['action' => 'status'], [], $session);
        $response = $this->assertJsonResponse($result, 200);
        
        // Verify no salt values in response
        $responseJson = json_encode($response);
        $this->assertStringNotContainsString('salt_value', $responseJson);
        $this->assertStringNotContainsString('secret', $responseJson);
    }
}
```

### Example 4: API Test

```php
<?php

namespace BellavierGroup\Tests\Integration\Api;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

class ProductsApiTest extends IntegrationTestCase
{
    public function testListProducts(): void
    {
        $result = $this->runTenantApi('products.php', ['action' => 'list']);
        $response = $this->assertJsonResponse($result, 200);
        
        $this->assertTrue($response['ok']);
        $this->assertArrayHasKey('data', $response);
        $this->assertIsArray($response['data']);
    }
    
    public function testCreateProduct(): void
    {
        $postData = [
            'action' => 'create',
            'name' => 'Test Product',
            'csrf_token' => 'test_token' // In real test, use valid CSRF token
        ];
        
        $result = $this->runTenantApi('products.php', [], $postData);
        $response = $this->assertJsonResponse($result, 201);
        
        $this->assertTrue($response['ok']);
        $this->assertArrayHasKey('id', $response['data']);
    }
}
```

---

## Reference Documents

### Testing Documentation

- **Integration Test Harness**: `docs/testing/bootstrap_task16_integration_harness.md` - Complete guide
- **Task 16**: `docs/bootstrap/Task/task16.md` - Integration test harness
- **Task 17**: `docs/bootstrap/Task/task17.md` - System-wide tests
- **Task 18**: `docs/bootstrap/Task/task18.md` - Security audit tests

### Test Code

- **IntegrationTestCase**: `tests/Integration/IntegrationTestCase.php` - Base class
- **SystemWide Tests**: `tests/Integration/SystemWide/` - System-wide tests
- **Bootstrap Tests**: `tests/Integration/Bootstrap/` - Bootstrap tests
- **API Tests**: `tests/Integration/Api/` - API tests

---

## Future Expansion

### Planned Enhancements

1. **Test Coverage Reports**
   - Automated coverage reports
   - Coverage thresholds
   - Coverage tracking

2. **Performance Tests**
   - Load testing
   - Stress testing
   - Performance benchmarks

3. **E2E Tests**
   - End-to-end workflows
   - Browser automation
   - User journey tests

4. **Test Data Management**
   - Test fixtures
   - Data factories
   - Test database seeding

---

**Previous Chapter:** [Chapter 9 — PWA Scan System](../chapters/09-pwa-scan-system.md)  
**Next Chapter:** [Chapter 11 — Security Handbook](../chapters/11-security-handbook.md)

