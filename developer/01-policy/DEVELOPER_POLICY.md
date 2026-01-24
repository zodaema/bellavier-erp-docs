# Bellavier Group ERP – Developer Policy

**Last Updated:** November 19, 2025  
**Version:** 3.0.0 (Post-Bootstrap Migration)  
**Maintained by:** Bellavier ERP Team  
**Philosophy:** Reliability First, Backward Compatibility, No Hidden Magic, Security by Default

---

## Core Principles

### 1. Reliability First
- **Data Integrity > Speed**: Never sacrifice data consistency for performance
- **Explicit > Implicit**: Clear error messages, no silent failures
- **Test Coverage Matters**: Aim for 80%+ coverage, write tests before features
- **Production Mindset**: This system handles multi-million dollar operations

### 2. Backward Compatibility
- **No Breaking Changes**: Existing APIs must continue working
- **Thin Wrappers**: Legacy functions preserved as wrappers (Task 19)
- **Gradual Migration**: Support both old and new patterns during transitions
- **Version Awareness**: Document breaking changes clearly

### 3. No Hidden Magic
- **Clear Bootstrap**: All APIs use `TenantApiBootstrap::init()` or `CoreApiBootstrap::init()`
- **Explicit Dependencies**: Use PSR-4 autoloading, no hidden requires
- **Documented Behavior**: All helpers and services have clear documentation
- **Predictable Responses**: JSON format standardized (`{ok: true/false}`)

### 4. Security by Default
- **Prepared Statements**: 100% coverage, no exceptions
- **Input Validation**: All inputs validated before processing
- **Rate Limiting**: All APIs protected (Task 18)
- **CSRF Protection**: State-changing operations protected
- **Secure Logging**: No sensitive data in logs (Task 18)

---

## Forbidden Changes

### ❌ Business Logic Changes
**DO NOT** modify business logic without explicit Task/specification:
- Permission logic (`BGERP\Security\PermissionHelper`)
- Role mapping and access control
- Organization/tenant resolution
- Migration behavior (`BGERP\Migration\BootstrapMigrations`)
- Bootstrap behavior (`TenantApiBootstrap`, `CoreApiBootstrap`)

**Exception**: Only if explicitly requested in a Task document.

### ❌ Auth/Permission Logic Changes
**DO NOT** modify authentication or permission logic without explicit approval:
- `BGERP\Security\PermissionHelper` methods (Task 19)
- `is_platform_administrator()`, `platform_has_permission()`, etc.
- Session handling in bootstrap layers
- Tenant resolution logic

**Exception**: Security fixes documented in Task 18 are acceptable.

### ❌ JSON Response Format Changes
**DO NOT** change JSON error/success format without Task approval:
- Standard format: `{ok: true, data: {...}}` or `{ok: false, error: {...}}`
- All APIs must use `json_success()` / `json_error()` or `TenantApiOutput` (Task 20)
- Error structure: `{ok: false, error: {code: "...", message: "..."}}`

**Exception**: Only if Task explicitly requests format change.

### ❌ Rate Limiter / CSRF / Serial Salt Behavior
**DO NOT** modify security-critical behavior without explicit Task:
- Rate limiter configuration (Task 18)
- CSRF token validation (Task 18)
- Serial salt generation/rotation (Task 15, Task 18)
- File permissions for salt files (Task 18)

**Exception**: Security hardening documented in Task 18 is acceptable.

### ❌ Bootstrap Signature Changes
**DO NOT** change bootstrap method signatures:
- `TenantApiBootstrap::init()` - Returns `[$org, $db]` where `$db` is `BGERP\Helper\DatabaseHelper`
- `CoreApiBootstrap::init([...])` - Returns `[$member, $coreDb, $tenantDb, $org, $cid]`
- These are used by 52+ APIs and all integration tests

**Exception**: Only if Task explicitly requests signature change.

---

## Safety Rails (For Every Change)

### When Touching Bootstrap Code

**MUST:**
1. ✅ Update `docs/bootstrap/tenant_api_bootstrap.md` or `core_platform_bootstrap.design.md`
2. ✅ Update relevant Task doc (`docs/bootstrap/Task/taskXX.md`)
3. ✅ Run SystemWide tests: `vendor/bin/phpunit tests/Integration/SystemWide/`
4. ✅ Verify all 52+ APIs still work (smoke test)
5. ✅ Check integration tests pass (Tasks 16-17)

**DO NOT:**
- ❌ Change return values without updating all callers
- ❌ Remove required initialization steps
- ❌ Break backward compatibility

### When Touching Permission / Migration Code

**MUST:**
1. ✅ Run SystemWide tests: `vendor/bin/phpunit tests/Integration/SystemWide/`
2. ✅ Test permission matrix: `EndpointPermissionMatrixSystemWideTest`
3. ✅ Test auth cases: `AuthGlobalCasesSystemWideTest`
4. ✅ Verify thin wrappers still work (`permission.php`, `bootstrap_migrations.php`)
5. ✅ Check PSR-4 classes load correctly: `composer dump-autoload`

**DO NOT:**
- ❌ Remove thin wrapper functions (Task 19)
- ❌ Change function signatures in `PermissionHelper` or `BootstrapMigrations`
- ❌ Break existing permission checks

### When Adding New Endpoints

**MUST:**
1. ✅ Use correct bootstrap: `TenantApiBootstrap::init()` or `CoreApiBootstrap::init()`
2. ✅ Use standard JSON format: `{ok: true/false}` via `json_success()` / `json_error()` or `TenantApiOutput`
3. ✅ Add rate limiting: `RateLimiter::check()`
4. ✅ Add CSRF protection for state-changing operations
5. ✅ Add integration test in `tests/Integration/SystemWide/` or `tests/Integration/Api/`
6. ✅ Follow API structure standards (see `docs/API_STRUCTURE_AUDIT.md`)

**DO NOT:**
- ❌ Create endpoints without bootstrap
- ❌ Return non-standard JSON format
- ❌ Skip rate limiting
- ❌ Skip tests

### When Modifying Existing APIs

**MUST:**
1. ✅ Maintain backward compatibility (response format, parameters)
2. ✅ Update tests if behavior changes
3. ✅ Document changes in Task doc or CHANGELOG
4. ✅ Run SystemWide tests to verify no regressions

**DO NOT:**
- ❌ Change response format without Task approval
- ❌ Remove required parameters
- ❌ Break existing functionality

---

## Workflow Guidelines

### Standard Development Workflow

1. **Create/Update Task Document**
   - File: `docs/bootstrap/Task/taskXX.md`
   - Document: Objective, scope, constraints, acceptance criteria
   - Reference: Previous tasks (task16.md - task20.md)

2. **Read Related Documentation**
   - Bootstrap docs: `docs/bootstrap/tenant_api_bootstrap.md`, `core_platform_bootstrap.design.md`
   - Task docs: `docs/bootstrap/Task/task16.md` - `task20.md`
   - Security notes: `docs/security/task18_security_notes.md`

3. **Implement Changes**
   - Follow coding standards (see below)
   - Use existing helpers (`PermissionHelper`, `BootstrapMigrations`, `TenantApiOutput`)
   - Maintain backward compatibility
   - Add/update tests

4. **Add/Update Tests**
   - Integration tests: `tests/Integration/SystemWide/` or `tests/Integration/Api/`
   - Use `IntegrationTestCase` base class (Task 16)
   - Follow patterns from Task 17 tests
   - Run: `vendor/bin/phpunit tests/Integration/SystemWide/`

5. **Update Documentation**
   - Task doc: Update implementation status
   - Bootstrap docs: Update if bootstrap changed
   - Developer docs: Update if workflow changed
   - CHANGELOG: Document significant changes

### Code Review Checklist

Before marking any task complete:

- [ ] All tests passing (`vendor/bin/phpunit`)
- [ ] No PHP syntax errors (`php -l file.php`)
- [ ] Bootstrap usage correct (`TenantApiBootstrap::init()` or `CoreApiBootstrap::init()`)
- [ ] JSON format standardized (`{ok: true/false}`)
- [ ] Rate limiting added (if API endpoint)
- [ ] CSRF protection added (if state-changing)
- [ ] Integration tests added/updated
- [ ] Documentation updated (Task doc, bootstrap docs)
- [ ] Backward compatibility maintained
- [ ] No breaking changes (unless explicitly approved)

---

## Refactor Rules

### Task 19 Refactor Rules (PSR-4 Helper Migration)

**CRITICAL**: The following rules apply to code refactored in Task 19:

**DO NOT:**
- ❌ Remove thin wrapper functions (`permission.php`, `bootstrap_migrations.php`)
- ❌ Change function signatures in `PermissionHelper` or `BootstrapMigrations`
- ❌ Modify control flow in permission/migration logic
- ❌ Change parameter names or types
- ❌ Refactor business logic (only namespace migration allowed)

**ALLOWED:**
- ✅ Update callers to use PSR-4 classes directly (gradual migration)
- ✅ Add new methods to PSR-4 classes (if needed)
- ✅ Improve documentation

**Rationale**: Task 19 was a namespace migration only. Business logic must remain unchanged.

### Bootstrap Refactor Rules (Tasks 1-15)

**CRITICAL**: Bootstrap layers are stable and used by 52+ APIs:

**DO NOT:**
- ❌ Change `TenantApiBootstrap::init()` return values
- ❌ Change `CoreApiBootstrap::init($mode)` return values
- ❌ Remove required initialization steps
- ❌ Break tenant resolution logic
- ❌ Break session handling

**ALLOWED:**
- ✅ Add optional features (feature flags)
- ✅ Improve error messages
- ✅ Add logging (non-sensitive)
- ✅ Performance optimizations (if verified safe)

**Rationale**: Bootstrap changes affect all APIs. Must maintain backward compatibility.

---

## Coding Standards (Summary)

## Frontend & i18n Standards (Mandatory)

### 1. i18n Requirements
- **All UI strings must use the existing translate() helper.**
- **Default/fallback text must always be English.**
- **Do not hard‑code Thai text directly in PHP or JS files.**
- **Do not use emojis, icons, or special characters in source code strings.**
- JS must use the global `t(key, fallback)` or equivalent wrapper already used in the codebase.

**Example (PHP):**
```php
label><?= translate('products.form.production_line', 'Production Line') ?></label>
```

**Example (JS):**
```javascript
text: t('job_ticket.lifecycle.start', 'Start Production')
```

### 2. Frontend Coding Standards
- **No `alert()`, `confirm()`, or browser-native dialogs** in production code.
- Use the system dialog framework (SweetAlert2 / Toast) or existing ERP dialog utilities.
- **All inline HTML event handlers are forbidden** (no `onclick="..."`).
- **All DOM event binding must be done via delegated listeners** inside the correct scoped container.
- **Every JS file must begin with a module header comment** describing purpose, dependencies, and author.
- **All JS error messages must be i18n-enabled**, English default.

### 3. HTML / View Standards
- No embedded scripts inside HTML files; use external JS files.
- All strings inside views must be wrapped with `translate()`.
- Fallback text must remain English for all UI.

### 4. Safety & Consistency
- **Never invent new helpers for i18n** unless a Task creates them explicitly.
- **All new UI components must be documented** in the related Task file.
- **All JS features must be defensive**: null checks, empty-state handling, and error fallback UI.

---

### PSR-4 Autoloading (Mandatory)

**Structure:**
```
source/BGERP/
├── Bootstrap/     # TenantApiBootstrap, CoreApiBootstrap
├── Security/      # PermissionHelper (Task 19)
├── Migration/     # BootstrapMigrations (Task 19)
├── Http/          # TenantApiOutput (Task 20)
└── Service/       # Business logic services
```

**Usage:**
```php
// At API top
require_once __DIR__ . '/../vendor/autoload.php';

// Use statements
use BGERP\Security\PermissionHelper;
use BGERP\Migration\BootstrapMigrations;
use BGERP\Http\TenantApiOutput;
```

### Bootstrap Usage (Mandatory)

**Tenant APIs:**
```php
require_once __DIR__ . '/../vendor/autoload.php';
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();
```

**Platform APIs:**
```php
require_once __DIR__ . '/../vendor/autoload.php';
[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init('platform_admin');
```

### JSON Response Format (Mandatory)

**Success:**
```php
TenantApiOutput::success($data, $meta, 200);
// Or
json_success(['data' => $data, 'meta' => $meta]);
```

**Error:**
```php
TenantApiOutput::error($message, $code, $extra);
// Or
json_error($message, 400, ['app_code' => 'ERROR_CODE']);
```

### Testing (Mandatory)

**Integration Tests:**
```php
namespace BellavierGroup\Tests\Integration\SystemWide;

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

---

## Security Requirements

### Rate Limiting (Task 18)
- ✅ All APIs must use `RateLimiter::check()`
- ✅ Strict limits: 10 req/60s for security-critical operations
- ✅ Standard limits: 120 req/60s for normal operations

### CSRF Protection (Task 18)
- ✅ State-changing operations must validate CSRF tokens
- ✅ Use `validateCsrfToken()` helper
- ✅ Read-only operations (GET-style) don't need CSRF

### Secure Logging (Task 18)
- ✅ No sensitive data in logs (passwords, tokens, salts)
- ✅ Use `LogHelper` for structured logging
- ✅ Filter sensitive keys: `password`, `api_key`, `token`, `salt`

### File Permissions (Task 18)
- ✅ Serial salt files: `chmod(0600)`
- ✅ Protected with `.htaccess` (Deny all)
- ✅ Not in webroot

---

## Testing Requirements

### System-Wide Tests (Tasks 16-17)

**MUST run before completing any task:**
```bash
vendor/bin/phpunit tests/Integration/SystemWide/
```

**Test Suites:**
- `BootstrapTenantInitTest` - Tenant bootstrap validation
- `BootstrapCoreInitTest` - Core bootstrap validation
- `RateLimiterSystemWideTest` - Rate limiting behavior
- `JsonErrorFormatSystemWideTest` - Error format consistency
- `JsonSuccessFormatSystemWideTest` - Success format consistency
- `AuthGlobalCasesSystemWideTest` - Authentication cases
- `EndpointSmokeSystemWideTest` - API smoke tests
- `EndpointPermissionMatrixSystemWideTest` - Permission matrix
- `SecurityAuditSystemWideTest` - Security audit (Task 18)

### Test Coverage Goals
- **Overall**: 80%+ coverage
- **Critical APIs**: 90%+ coverage
- **Bootstrap**: 100% coverage (all paths tested)

---

## Documentation Requirements

### Task Documentation
- **File**: `docs/bootstrap/Task/taskXX.md`
- **Sections**: Objective, Scope, Constraints, Implementation Status, Test Results, Acceptance Criteria
- **Update**: After implementation, update status and results

### Bootstrap Documentation
- **Files**: `docs/bootstrap/tenant_api_bootstrap.md`, `core_platform_bootstrap.design.md`
- **Update**: When bootstrap behavior changes

### Developer Documentation
- **Files**: `docs/developer/` (this directory)
- **Update**: When workflow or standards change

---

## Related Documentation

### Essential Reading
- `docs/developer/README.md` - Entry point
- `docs/developer/02-quick-start/QUICK_START.md` - Setup guide
- `docs/developer/02-quick-start/GLOBAL_HELPERS.md` - Helper reference
- `docs/bootstrap/tenant_api_bootstrap.md` - Tenant bootstrap spec
- `docs/bootstrap/core_platform_bootstrap.design.md` - Core bootstrap design

### Task Documentation
- `docs/bootstrap/Task/task16.md` - Integration test harness
- `docs/bootstrap/Task/task17.md` - System-wide tests
- `docs/bootstrap/Task/task18.md` - Security review
- `docs/bootstrap/Task/task19.md` - PSR-4 helper migration
- `docs/bootstrap/Task/task20.md` - JSON output enforcement

### Security Documentation
- `docs/security/task18_security_notes.md` - Security audit findings

---

**Remember**: This system handles real businesses, real money, and real livelihoods. Code with care, test thoroughly, and maintain backward compatibility.
