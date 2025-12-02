# Task 16 – Integration Test Harness for Core/Tenant Bootstrap & Key APIs

**Status:** ✅ COMPLETED (2025-11-19)  
**Owner:** AI Agent (Cursor)  
**Date:** 2025-11-19  

## 1. Objective

Create a **proper PHPUnit Integration Test Harness** for Bellavier Group ERP that:

1. Validates that the new bootstrap layers  
   - `BGERP\Bootstrap\TenantApiBootstrap`  
   - `BGERP\Bootstrap\CoreApiBootstrap`  
   are wired correctly and can be used consistently in tests.

2. Provides **reusable helpers** for calling key API scripts (tenant + platform) from tests in a safe, repeatable way.

3. Adds a **small but meaningful set of integration tests** for **key APIs** (read-only / safe endpoints first), without changing business logic.

> Goal: After Task 16, we should be able to run  
> `vendor/bin/phpunit tests/Integration`  
> and get deterministic feedback that the new bootstrap + core APIs are alive and wired correctly.

---

## 2. Constraints & Guardrails

- ❌ **DO NOT change business logic** in any API file.
- ❌ **DO NOT change response formats** (`json_success/json_error` payload shape).
- ❌ **DO NOT touch authentication, permission, or tenant-resolution logic**.
- ✅ You may **add new test classes, helpers, and fixtures only**.
- ✅ You may add **very small, test-only helpers** *inside tests* (e.g. utility methods), but **not** inside production code.
- ✅ All new test code must:
  - Use **PSR-4 namespaces** under `BellavierGroup\Tests\Integration\...`
  - Be compatible with **PHPUnit 9.x** (current project setup).

Assume the environment used by the owner:
- Tests are run locally via MAMP with a **real DB**.
- Existing tests already pass:
  - `tests/Unit/SerialHealthServiceTest.php`
  - `tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php`
- Do not break existing tests.

---

## 3. Scope

### 3.1 In Scope

1. **Integration Test Base Class**
   - Create a reusable base test class for integration tests:
     - `tests/Integration/IntegrationTestCase.php`
     - Namespace: `BellavierGroup\Tests\Integration`
   - Responsibilities:
     - Provide helpers for:
       - Running tenant APIs (include PHP script, simulate `$_GET/$_POST/$_SERVER`, capture output).
       - Running core/platform APIs similarly.
       - Optionally: helper to decode JSON responses.

2. **Smoke Integration Tests for Bootstrap Functions**
   - Verify that:
     - Including a tenant-level API that uses `TenantApiBootstrap::init()` does **not fatal** and can produce a JSON response under test.
     - Including a core/platform API that uses `CoreApiBootstrap::init()` behaves similarly.
   - Do **not** deeply assert business logic yet – focus on:
     - HTTP-like behavior (e.g. content-type is JSON if easy to check).
     - Response being valid JSON.
     - Contains `ok` or `error` keys as expected.

3. **Integration Tests for a Small Set of Key APIs**
   Focus on **safe / mostly read-only** or low-risk endpoints first:

   **Tenant APIs (Hatthasilpa / ERP):**
   - `source/dashboard_api.php` (if suitable)
   - `source/trace_api.php` – e.g. safe `status` or count-like actions if available
   - `source/hatthasilpa_jobs_api.php` – safe listing action
   - `source/people_api.php` – safe listing action (e.g. list people/operators)

   **Platform APIs (Core):**
   - `source/platform_health_api.php` – ideal “ping” endpoint
   - `source/platform_dashboard_api.php` – read-only dashboard summary (if safe)

   For each selected endpoint:
   - Create **at least one happy-path test** that:
     - Sets up minimal request context (`$_GET/$_POST`, `$_SERVER['REQUEST_METHOD']`, etc.).
     - Calls the API via include/require inside output buffering.
     - Asserts:
       - Response is valid JSON.
       - `ok === true` for success endpoints, or appropriate error structure for expected error.
       - No PHP warnings/notices/fatal errors (if feasible to detect via output).

4. **Documentation**
   - Add a small doc file:
     - `docs/testing/task16_integration_harness.md`
   - Describe:
     - The structure of integration tests.
     - How to run them.
     - Which APIs are currently covered.
     - How future tests should extend `IntegrationTestCase`.

### 3.2 Out of Scope (for Task 16)

- Full end-to-end coverage of all APIs (that will be future tasks).
- Heavy data setup / seeding tools.
- Changing production code to be “more testable” – unless absolutely required and explicitly agreed in a future task.
- UI / JavaScript testing.

---

## 4. Implementation Plan

### Step 0 – Discovery

1. Inspect existing tests:
   - `tests/Unit/SerialHealthServiceTest.php`
   - `tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php`
   - `tests/bootstrap/ApiBootstrapSmokeTest.php` (CLI smoke script)

2. Understand:
   - How PHPUnit is currently configured (`phpunit.xml` / `phpunit.xml.dist`).
   - Current namespaces and autoload configuration (via `composer.json`).

> Output of this step: short notes (in comments at the top of `IntegrationTestCase.php` or in the doc file) summarizing how tests are structured today.

---

### Step 1 – Create `IntegrationTestCase` Base Class

**File:**  
`tests/Integration/IntegrationTestCase.php`  
**Namespace:**  
`BellavierGroup\Tests\Integration`

Responsibilities:

- Extend `\PHPUnit\Framework\TestCase`.
- Provide generic helpers, for example:

```php
namespace BellavierGroup\Tests\Integration;

use PHPUnit\Framework\TestCase;

abstract class IntegrationTestCase extends TestCase
{
    /**
     * Run a tenant API PHP script and return [statusCode, headers, decodedJson].
     *
     * @param string $script Relative path from project root, e.g. 'source/dashboard_api.php'
     * @param array  $get
     * @param array  $post
     * @param string $method  'GET' or 'POST'
     * @return array{output: string, json: ?array}
     */
    protected function runTenantApi(string $script, array $get = [], array $post = [], string $method = 'GET'): array
    {
        // TODO: implement in a safe way:
        // - Backup & restore superglobals ($_GET, $_POST, $_REQUEST, $_SERVER)
        // - Start output buffering
        // - Include the script
        // - Capture output and decode JSON (if applicable)
    }

    /**
     * Similar helper for core/platform APIs, if needed.
     */
    protected function runCoreApi(string $script, array $get = [], array $post = [], string $method = 'GET'): array
    {
        // Implementation can delegate to runTenantApi if there is no difference in setup
    }
}

Requirements:
	•	Backup and restore superglobals to avoid cross-test pollution.
	•	Assume project root is current working directory when running phpunit; adjust paths if necessary.
	•	Do not assume specific tenant/org in this step; just make helpers generic.

⸻

Step 2 – Basic Bootstrap Integration Tests

Create tests to validate that including APIs that use the new bootstraps does not fatal.

File Example:
	1.	tests/Integration/Bootstrap/TenantApiBootstrapIntegrationTest.php
	2.	tests/Integration/Bootstrap/CoreApiBootstrapIntegrationTest.php

Possible approach:
	•	For Tenant:
	•	Pick a “safe” API like source/dashboard_api.php or source/people_api.php.
	•	Use runTenantApi() with minimal $_GET/$_POST.
	•	Assert:
	•	No fatal error (test will fail automatically if include throws).
	•	Output is valid JSON.
	•	For Core:
	•	Use source/platform_health_api.php.
	•	Use runCoreApi() with GET.
	•	Assert:
	•	Output is valid JSON.
	•	Contains a key like status or similar (depending on existing behavior).

If a test cannot run without a specific DB state or session, handle it gracefully:
	•	Either use test config/fixtures that already exist.
	•	Or markTestSkipped() with a clear message, rather than forcing a hard failure.

⸻

Step 3 – API-Level Integration Tests for Key Endpoints

Create a small set of tests that exercise real API behavior with happy paths.

Suggested files:
	1.	tests/Integration/Api/PlatformHealthApiTest.php
	•	Calls source/platform_health_api.php
	•	Asserts:
	•	Valid JSON.
	•	Contains expected high-level keys (e.g. ok, health, etc. – inspect actual response and match it).
	2.	tests/Integration/Api/PeopleApiTest.php
	•	Calls source/people_api.php with a safe listing action (e.g. action = list or similar).
	•	Asserts:
	•	Valid JSON.
	•	ok === true.
	•	data is an array (even if empty is fine).
	3.	tests/Integration/Api/DashboardApiTest.php
	•	Calls source/dashboard_api.php (if available and safe).
	•	Asserts basic structure like above.

Important:
	•	For any endpoint that requires authentication/tenant/org, reuse the same assumptions that other tests (like HatthasilpaE2E_SerialEnforcementStage2Test) already rely on:
	•	If they expect a particular session/tenant, replicate that minimal setup in the test.
	•	If that is not possible, markTestSkipped() with explanation rather than hacking production code.

⸻

Step 4 – Documentation

Create/Update:

File:
docs/testing/bootstrap_task16_integration_harness.md

Content should include:
	1.	Purpose of IntegrationTestCase.
	2.	Folder structure of integration tests (tests/Integration/...).
	3.	How to run:

cd /Applications/MAMP/htdocs/bellavier-group-erp
vendor/bin/phpunit tests/Integration --testdox


	4.	Current Coverage:
	•	Which APIs have integration tests.
	•	Known limitations (e.g. tests require local DB / certain tenant data).
	5.	How to extend:
	•	Example of adding a new test file that extends IntegrationTestCase and calls an API script.

⸻

5. Definition of Done (DoD)

Task 16 is COMPLETE when:
	1.	✅ tests/Integration/IntegrationTestCase.php exists and:
	•	Provides helpers to run API scripts and capture JSON output.
	•	Properly backs up/restores superglobals.
	2.	✅ At least 2 bootstrap tests exist:
	•	One for tenant API via TenantApiBootstrap.
	•	One for core API via CoreApiBootstrap.
	3.	✅ At least 3 API integration tests exist (can be small):
	•	PlatformHealthApiTest (core)
	•	PeopleApiTest (tenant)
	•	DashboardApiTest or equivalent (tenant)
	4.	✅ All new tests pass with:

vendor/bin/phpunit tests/Integration --testdox

and do not break existing unit/integration tests.

	5.	✅ docs/testing/task16_integration_harness.md is created/updated with:
	•	Overview
	•	How to run
	•	Current coverage
	•	Guidelines for future tests.
	6.	✅ No changes to business logic or API responses in production code (only test files added).

⸻