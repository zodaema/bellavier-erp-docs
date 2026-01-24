# Developer Quick Start

**Last Updated:** November 19, 2025  
**For:** New developers joining the Bellavier Group ERP project  
**Time:** 30-45 minutes for complete setup

---

## Prerequisites

### Required Software
- **PHP**: 8.2+ (tested with PHP 8.2)
- **Composer**: Latest version (for PSR-4 autoloading)
- **MySQL**: 8.0+ (for database)
- **MAMP** (or equivalent): For local development server
  - Apache/Nginx
  - PHP-FPM or mod_php

### Required Knowledge
- PHP (object-oriented, namespaces, PSR-4)
- MySQL (prepared statements, transactions)
- Basic understanding of multi-tenant architecture
- Git basics

---

## Local Setup

### Step 1: Clone Repository

```bash
cd /Applications/MAMP/htdocs/
git clone <repository-url> bellavier-group-erp
cd bellavier-group-erp
```

### Step 2: Install Dependencies

```bash
composer install
```

This installs:
- PHPUnit (for testing)
- PSR-4 autoloader configuration
- Other dependencies defined in `composer.json`

### Step 3: Configure Database

**Create `config.php`** (if not exists, copy from `config.local.php.example`):

```php
<?php
// Database configuration
define('DB_HOST', 'localhost');
define('DB_PORT', 8889); // MAMP default
define('DB_USER', 'root');
define('DB_PASS', 'root'); // MAMP default
define('DB_CORE', 'bgerp'); // Core database
```

**Database Structure:**
- **Core DB**: `bgerp` (users, organizations, permissions)
- **Tenant DBs**: `bgerp_t_{org_code}` (e.g., `bgerp_t_default`, `bgerp_t_maison_atelier`)

**Note**: Database names follow pattern `bgerp_t_{org_code}` for tenant databases.

### Step 4: Verify Setup

```bash
# Check PHP version
php -v  # Should be 8.2+

# Check Composer
composer --version

# Check autoloader
composer dump-autoload
```

---

## Running Migrations

### Using BootstrapMigrations Helper (Task 19)

**PSR-4 Helper:**
```php
use BGERP\Migration\BootstrapMigrations;

// Run core migrations
BootstrapMigrations::run_core_migrations();

// Run tenant migrations for specific org
BootstrapMigrations::run_tenant_migrations_for('default');

// Run tenant migrations for all orgs
BootstrapMigrations::run_tenant_migrations_for_all();
```

**Legacy Wrapper (Still Works):**
```php
require_once __DIR__ . '/bootstrap_migrations.php';

// Same functions available
run_core_migrations();
run_tenant_migrations_for('default');
```

### Command Line Usage

**Via CLI script:**
```bash
php source/bootstrap_migrations.php --tenant=default
php source/bootstrap_migrations.php --tenant=maison_atelier
php source/bootstrap_migrations.php --all-tenants
```

**Via provisioning script:**
```bash
php utils/provision.php --tenant=default
```

### Migration Files

**Location:** `database/tenant_migrations/`

**Naming:** `YYYY_MM_description.php` (e.g., `2025_11_tenant_user_accounts.php`)

**Format:** PHP functions that return migration logic (NOT SQL files)

**Reference:** See `docs/bootstrap/Task/task19.md` for migration patterns.

---

## Running Tests

### Test Structure

```
tests/
├── Integration/
│   ├── SystemWide/        # System-wide integration tests (Task 17)
│   │   ├── BootstrapTenantInitTest.php
│   │   ├── BootstrapCoreInitTest.php
│   │   ├── RateLimiterSystemWideTest.php
│   │   ├── JsonErrorFormatSystemWideTest.php
│   │   ├── JsonSuccessFormatSystemWideTest.php
│   │   ├── AuthGlobalCasesSystemWideTest.php
│   │   ├── EndpointSmokeSystemWideTest.php
│   │   ├── EndpointPermissionMatrixSystemWideTest.php
│   │   └── SecurityAuditSystemWideTest.php
│   ├── Bootstrap/         # Bootstrap tests (Task 16)
│   └── Api/               # API integration tests
└── Unit/                  # Unit tests (no database)
```

### Running Tests

**All tests:**
```bash
vendor/bin/phpunit
```

**System-wide tests (most important):**
```bash
vendor/bin/phpunit tests/Integration/SystemWide/
```

**Bootstrap tests:**
```bash
vendor/bin/phpunit tests/Integration/Bootstrap/
```

**API tests:**
```bash
vendor/bin/phpunit tests/Integration/Api/
```

**Unit tests:**
```bash
vendor/bin/phpunit tests/Unit/
```

**With readable output:**
```bash
vendor/bin/phpunit --testdox
```

### Expected Results

**System-wide tests:**
- 30+ tests covering bootstrap, rate limiting, JSON format, auth, endpoints, permissions, security
- Some tests may be skipped/incomplete (documented in test files)
- Most tests should pass (environment-dependent)

**Bootstrap tests:**
- 6+ tests validating bootstrap initialization
- All should pass

**API tests:**
- Various tests for specific API endpoints
- Coverage varies by API

**Note**: Some tests may fail due to:
- Missing test database setup
- Missing permission tables in test environment
- Pre-existing legacy code issues (not related to recent tasks)

---

## How to Safely Modify an API

### Step 1: Identify API Type

**Tenant API** (uses `TenantApiBootstrap`):
- Files: `source/products.php`, `source/materials.php`, `source/bom.php`, etc.
- Uses: `TenantApiBootstrap::init()`
- Returns: `[$org, $tenantDb, $member]`

**Platform API** (uses `CoreApiBootstrap`):
- Files: `source/platform_*.php`, `source/admin_*.php`
- Uses: `CoreApiBootstrap::init($mode)`
- Returns: `[$member, $coreDb]`

### Step 2: Understand Bootstrap Usage

**Tenant API Pattern:**
```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Now use $org, $tenantDb, $member
```

**Platform API Pattern:**
```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init('platform_admin');

// Now use $member, $coreDb
```

### Step 3: Use Helpers

**Permission Checks:**
```php
use BGERP\Security\PermissionHelper;

// Check platform admin
if (!PermissionHelper::isPlatformAdministrator($member)) {
    json_error('unauthorized', 403);
}

// Check org permission
if (!PermissionHelper::platform_has_permission($member, 'permission.code')) {
    json_error('forbidden', 403);
}
```

**Database Operations:**
```php
// Use prepared statements
$stmt = $tenantDb->prepare("SELECT * FROM table WHERE id=?");
$stmt->bind_param('i', $id);
$stmt->execute();
$result = $stmt->get_result()->fetch_assoc();
```

**JSON Output:**
```php
use BGERP\Http\TenantApiOutput;

// Success
TenantApiOutput::success($data, $meta, 200);

// Error
TenantApiOutput::error($message, $code, $extra);
```

### Step 4: Maintain JSON Format

**Standard Format:**
```json
{
  "ok": true,
  "data": {...},
  "meta": {...}
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

**Reference**: See `docs/bootstrap/Task/task20.md` for JSON output enforcement.

### Step 5: Add Rate Limiting

```php
use BGERP\Helper\RateLimiter;

RateLimiter::check($member['id_member'], 'api_name', 'action_name', 120, 60);
// Parameters: user_id, endpoint, action, limit, window_seconds
```

### Step 6: Add CSRF Protection (State-Changing Operations)

```php
// For POST/PUT/DELETE operations
if (!validateCsrfToken($_POST['csrf_token'] ?? '')) {
    json_error('invalid_csrf', 403);
}
```

### Step 7: Add Integration Test

**Create test file:**
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

**Run test:**
```bash
vendor/bin/phpunit tests/Integration/Api/MyApiTest.php
```

### Step 8: Verify Changes

**Checklist:**
- [ ] API uses correct bootstrap (`TenantApiBootstrap` or `CoreApiBootstrap`)
- [ ] JSON format standardized (`{ok: true/false}`)
- [ ] Rate limiting added
- [ ] CSRF protection added (if state-changing)
- [ ] Integration test added/updated
- [ ] All tests passing
- [ ] Documentation updated

---

## Reference Documentation

### Bootstrap Architecture
- **Tenant Bootstrap**: `docs/bootstrap/tenant_api_bootstrap.md`
- **Core Bootstrap**: `docs/bootstrap/core_platform_bootstrap.design.md`
- **Task Docs**: `docs/bootstrap/Task/task16.md` - `task20.md`

### Helper Reference
- **Global Helpers**: `docs/developer/02-quick-start/GLOBAL_HELPERS.md`
- **PermissionHelper**: `source/BGERP/Security/PermissionHelper.php`
- **BootstrapMigrations**: `source/BGERP/Migration/BootstrapMigrations.php`
- **TenantApiOutput**: `source/BGERP/Http/TenantApiOutput.php`

### Testing
- **Integration Test Harness**: `docs/testing/bootstrap_task16_integration_harness.md`
- **System-Wide Tests**: `docs/bootstrap/Task/task17.md`
- **Test Base Class**: `tests/Integration/IntegrationTestCase.php`

### Security
- **Security Notes**: `docs/security/task18_security_notes.md`
- **Security Tests**: `tests/Integration/SystemWide/SecurityAuditSystemWideTest.php`

---

## Common Issues & Solutions

### Issue: "Class not found" Error

**Solution:**
```bash
composer dump-autoload
```

**Check**: PSR-4 namespace matches directory structure.

### Issue: Tests Failing

**Solution:**
1. Check test database setup
2. Verify permission tables exist
3. Check test environment configuration
4. Review test output for specific errors

### Issue: Bootstrap Not Working

**Solution:**
1. Verify bootstrap file exists: `source/BGERP/Bootstrap/TenantApiBootstrap.php`
2. Check autoloader: `composer dump-autoload`
3. Verify usage: `[$org, $tenantDb, $member] = TenantApiBootstrap::init();`

### Issue: JSON Format Errors

**Solution:**
1. Use `TenantApiOutput::success()` or `json_success()`
2. Verify format: `{ok: true/false}`
3. Check `docs/bootstrap/Task/task20.md` for patterns

---

## Next Steps

1. **Read Developer Policy**: `docs/developer/01-policy/DEVELOPER_POLICY.md`
2. **Read Global Helpers**: `docs/developer/02-quick-start/GLOBAL_HELPERS.md`
3. **Explore Bootstrap Docs**: `docs/bootstrap/tenant_api_bootstrap.md`
4. **Review Task Docs**: `docs/bootstrap/Task/task16.md` - `task20.md`
5. **Start Development**: Pick a task and follow the workflow

---

**Ready to code?** → Read `docs/developer/01-policy/DEVELOPER_POLICY.md` for rules and standards.

## Additional Development Standards (2025 Update)

The following global standards apply to **all development tasks**, including PHP, JS, API endpoints, UI work, and AI‑generated code.

### 1. Internationalization (i18n)
- All UI-visible strings must use `translate(key, 'Fallback English')`.
- English must always be the fallback language.
- Do **not** translate:
  - error messages returned from backend exceptions,
  - log messages,
  - debug messages,
  - internal helper comments.
- Never hardcode Thai text in JS or PHP.

**Example:**
```php
<label><?php echo translate('products.form.production_line', 'Production Line'); ?></label>
```

### 2. JavaScript Standards
- Never use `alert()`, `confirm()`, `prompt()`.
- Use centralized UI helpers:
  - `BG.ui.toastSuccess()`, `BG.ui.toastError()`, `BG.ui.toastInfo()`, `BG.ui.confirmDialog()`
- All strings rendered in UI must use:
  ```js
  t('products.error.invalid_line', 'Invalid production line')
  ```
- Always use `BG.api.request()` wrapper (never raw jQuery AJAX).

### 3. PHP / API Standards
- All tenant APIs must bootstrap using:
  ```php
  [$org, $tenantDb, $member] = TenantApiBootstrap::init();
  ```
- All platform APIs must use:
  ```php
  [$member, $coreDb] = CoreApiBootstrap::init('platform_admin');
  ```
- JSON responses must use:
  ```php
  TenantApiOutput::success($data, $meta);
  TenantApiOutput::error('ERROR_CODE', 'Readable message', 400);
  ```

### 4. Security Standards
- Never log sensitive data (tokens, passwords, session IDs, personal information).
- All POST/PUT/DELETE actions must validate CSRF token.
- Rate limiting is required for all state‑changing endpoints.

### 5. Coding Style
- PHP must follow PSR‑4 autoloading and folder structure.
- Class names must be descriptive and namespaced.
- Comments must be written in clear professional English:
  - No emojis
  - No informal wording
  - No Thai in code comments

### 6. AI Agent Rules
Any code generated by Cursor / AI Agent must follow:
1. i18n rules (English fallback, no Thai in code)
2. No jQuery AJAX (use BG.api.request)
3. No UI blocking alerts
4. Proper bootstrap and JSON output format
5. Security + CSRF + Rate‑limit patterns
6. Clear comments explaining intent

