# Chapter 13 — Refactor & Contribution Guide

**Last Updated:** November 19, 2025  
**Purpose:** Define how developers modify the codebase safely  
**Audience:** All developers, contributors, AI agents

---

## Overview

This chapter provides guidelines for refactoring code, contributing changes, and modifying the Bellavier Group ERP codebase. It defines stable-core rules, refactor zones, AI-assisted development workflow, and contribution processes.

**Key Topics:**
- Stable-core rules
- Refactor zones (Safe vs Dangerous)
- AI-assisted development workflow
- Adding a new module
- Adding new tests
- Review workflow
- Commit style
- Breaking change policy

**Principles:**
- Stability over cleverness
- Backward compatibility first
- Test-driven changes
- Documentation required

---

## Key Concepts

### 1. Stable-Core Rules

**Protected Areas (Do Not Touch Without Explicit Approval):**

1. **Bootstrap Core**
   - `TenantApiBootstrap` - Entry contract for 40+ APIs
   - `CoreApiBootstrap` - Entry contract for 12 APIs
   - Any bootstrap classes

2. **Security & Permission Core**
   - `PermissionHelper` - Permission logic (Task 19)
   - `permission.php` thin wrapper
   - `RateLimiter` and rate limit logic
   - `platform_serial_salt_api.php` and salt/crypto logic

3. **Migration Core**
   - `BootstrapMigrations` - Migration behavior (Task 19)
   - `bootstrap_migrations.php` thin wrapper
   - Migration execution logic

4. **System-Wide Tests**
   - `tests/Integration/SystemWide/*` - Behavior contracts
   - Don't modify existing assertions without Task approval

**Rules:**
- ❌ Don't change return values
- ❌ Don't remove required steps
- ❌ Don't break backward compatibility
- ✅ Add new features (if Task requests)
- ✅ Improve error messages
- ✅ Add logging (non-sensitive)

### 2. Refactor Zones

**Safe Zones (Can Refactor):**
- ✅ Business logic in Service classes
- ✅ API endpoint implementations (not bootstrap)
- ✅ Frontend JavaScript
- ✅ Test code
- ✅ Documentation

**Dangerous Zones (Require Approval):**
- ⚠️ Bootstrap layers
- ⚠️ Permission/migration helpers
- ⚠️ Security-critical code
- ⚠️ System-wide tests
- ⚠️ Database schema (migrations)

**Refactor Rules:**
- ✅ Small, focused changes
- ✅ Maintain backward compatibility
- ✅ Update tests
- ✅ Update documentation
- ❌ Large rewrites without approval
- ❌ Breaking changes without migration path

### 3. AI-Assisted Development Workflow

**Step 1: Read Documentation**
- Read Task doc (if exists)
- Read Developer Policy
- Read relevant chapters
- Read existing code patterns

**Step 2: Plan Changes**
- Identify scope
- Identify safe vs dangerous zones
- Plan backward compatibility
- Plan test updates

**Step 3: Implement Changes**
- Follow coding standards
- Maintain backward compatibility
- Write/update tests
- Update documentation

**Step 4: Verify Changes**
- Run tests
- Check syntax
- Verify no regressions
- Update documentation

**Step 5: Document Changes**
- Update Task doc
- Update CHANGELOG
- Update relevant chapters
- Document breaking changes (if any)

---

## Core Components

### Adding a New Module

#### Step 1: Plan Module Structure

**Components:**
- API endpoint (`source/{module}_api.php`)
- Service classes (`source/BGERP/Service/{Module}Service.php`)
- Database tables (migrations)
- Frontend (if needed)
- Tests

#### Step 2: Create Database Schema

**Migration File:**
```php
// database/tenant_migrations/YYYY_MM_module_tables.php
return function (mysqli $db): void {
    migration_create_table_if_missing($db, 'module_table', '...');
};
```

**Run Migration:**
```php
use BGERP\Migration\BootstrapMigrations;
BootstrapMigrations::run_tenant_migrations_for('default');
```

#### Step 3: Create Service Classes

**Service Structure:**
```php
<?php
namespace BGERP\Service;

class ModuleService
{
    public function __construct(private \mysqli $db) {}
    
    public function doSomething($data): array
    {
        // Business logic
    }
}
```

#### Step 4: Create API Endpoint

**API Structure:**
```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'module', 'action', 120, 60);

use BGERP\Security\PermissionHelper;
if (!PermissionHelper::hasOrgPermission($member, 'module.action')) {
    json_error('forbidden', 403);
}

$action = $_REQUEST['action'] ?? '';
try {
    switch ($action) {
        case 'action':
            // Logic
            json_success(['data' => $result]);
            break;
        default:
            json_error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

#### Step 5: Add Tests

**Integration Test:**
```php
namespace BellavierGroup\Tests\Integration\Api;

use BellavierGroup\Tests\Integration\IntegrationTestCase;

class ModuleApiTest extends IntegrationTestCase
{
    public function testModuleAction(): void
    {
        $result = $this->runTenantApi('module_api.php', ['action' => 'action']);
        $response = $this->assertJsonResponse($result, 200);
        $this->assertTrue($response['ok']);
    }
}
```

#### Step 6: Update Documentation

- Update API reference
- Update schema reference
- Update service reference
- Update developer docs

### Adding New Tests

#### Step 1: Choose Test Type

**Integration Test:**
- Extends `IntegrationTestCase`
- Tests real API behavior
- Uses `runTenantApi()` or `runCoreApi()`

**Unit Test:**
- Extends `PHPUnit\Framework\TestCase`
- Tests logic only (no database)
- Fast execution

#### Step 2: Create Test File

**File Location:**
- Integration: `tests/Integration/SystemWide/` or `tests/Integration/Api/`
- Unit: `tests/Unit/`

**File Naming:**
- Format: `{ClassName}Test.php`
- Example: `ProductsApiTest.php`

#### Step 3: Write Test Class

**Structure:**
```php
<?php

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

#### Step 4: Run Tests

```bash
vendor/bin/phpunit tests/Integration/Api/MyApiTest.php
```

### Review Workflow

#### Step 1: Self-Review

**Checklist:**
- [ ] All tests passing
- [ ] No PHP syntax errors
- [ ] No JavaScript errors
- [ ] Documentation updated
- [ ] Backward compatibility maintained
- [ ] Security considerations addressed

#### Step 2: Code Review

**Review Points:**
- Code quality (readability, maintainability)
- Security (prepared statements, validation, escaping)
- Performance (queries, indexes, N+1)
- Tests (coverage, quality)
- Documentation (completeness, accuracy)

#### Step 3: Testing

**Test Types:**
- Unit tests
- Integration tests
- System-wide tests
- Manual testing

#### Step 4: Documentation

**Update:**
- Task doc (if applicable)
- API reference
- Schema reference
- Service reference
- Developer docs

### Commit Style

#### Commit Message Format

**Format:**
```
Type: Brief description

Detailed description (if needed)

- Change 1
- Change 2
```

**Types:**
- `Feature:` - New feature
- `Fix:` - Bug fix
- `Refactor:` - Code refactoring
- `Docs:` - Documentation only
- `Test:` - Test additions/changes
- `Perf:` - Performance improvement
- `Security:` - Security fix

**Examples:**
```
Feature: Add products API endpoint

- Add products.php API
- Add ProductsService
- Add integration tests
- Update API reference docs
```

```
Fix: Resolve N+1 query in trace_api.php

- Replace correlated subquery with LEFT JOIN
- Add index for performance
- Update tests
```

### Breaking Change Policy

#### When Breaking Changes Are Allowed

**Allowed:**
- ✅ Explicit Task approval
- ✅ Migration path provided
- ✅ Deprecation period
- ✅ Documentation updated

**Not Allowed:**
- ❌ Breaking changes without approval
- ❌ Breaking changes without migration
- ❌ Breaking changes without notice

#### Breaking Change Process

**Step 1: Document Breaking Change**
- What is breaking
- Why it's necessary
- Migration path
- Deprecation timeline

**Step 2: Provide Migration Path**
- Legacy support (thin wrappers)
- Gradual migration
- Clear upgrade path

**Step 3: Update Documentation**
- Breaking change notice
- Migration guide
- Deprecation warnings

**Step 4: Communicate**
- Announce breaking change
- Provide timeline
- Offer support

---

## Developer Responsibilities

### When Refactoring

**MUST:**
- ✅ Maintain backward compatibility
- ✅ Update tests
- ✅ Update documentation
- ✅ Run all tests before committing
- ✅ Get approval for dangerous zones

**DO NOT:**
- ❌ Break existing functionality
- ❌ Remove features without deprecation
- ❌ Change public APIs without approval
- ❌ Skip tests

### When Contributing

**MUST:**
- ✅ Follow coding standards
- ✅ Write tests
- ✅ Update documentation
- ✅ Follow commit style
- ✅ Self-review before submitting

**DO NOT:**
- ❌ Submit untested code
- ❌ Skip documentation
- ❌ Break backward compatibility
- ❌ Modify protected areas without approval

---

## Common Pitfalls

### 1. Breaking Backward Compatibility

**Problem:**
```php
// ❌ Wrong: Breaking change without migration
// Old API: function getData($id)
// New API: function getData($id, $options)
```

**Solution:**
```php
// ✅ Correct: Maintain backward compatibility
function getData($id, $options = [])
{
    // Support both old and new usage
}
```

### 2. Modifying Protected Areas

**Problem:**
```php
// ❌ Wrong: Modifying bootstrap without approval
TenantApiBootstrap::init() {
    // Changed return value structure
    return [$org, $db]; // Was: [$org, $tenantDb, $member]
}
```

**Solution:**
```php
// ✅ Correct: Get approval first, then maintain compatibility
// Or add new method, keep old method
```

### 3. Skipping Tests

**Problem:**
```php
// ❌ Wrong: No tests for new feature
// Feature added but no tests
```

**Solution:**
```php
// ✅ Correct: Write tests first (TDD)
// Or write tests immediately after feature
```

---

## Examples

### Example 1: Safe Refactor

```php
// Before: Inline logic
function processData($data) {
    // 50 lines of logic
}

// After: Extract to service
function processData($data) {
    $service = new DataProcessingService($db);
    return $service->process($data);
}
```

**Safe Because:**
- ✅ Function signature unchanged
- ✅ Behavior unchanged
- ✅ Tests still pass
- ✅ Backward compatible

### Example 2: Dangerous Refactor

```php
// Before: Bootstrap returns [$org, $tenantDb, $member]
[$org, $tenantDb, $member] = TenantApiBootstrap::init();

// After: Changed to [$org, $db]
[$org, $db] = TenantApiBootstrap::init();
```

**Dangerous Because:**
- ❌ Breaks 40+ APIs
- ❌ No migration path
- ❌ No approval
- ❌ Breaking change

**Solution:**
- Get Task approval first
- Provide migration path
- Update all callers
- Maintain backward compatibility during transition

---

## Reference Documents

### Contribution Documentation

- **Developer Policy**: `docs/developer/01-policy/DEVELOPER_POLICY.md` - Complete rules
- **AI Quick Start**: `docs/developer/02-quick-start/AI_QUICK_START.md` - AI agent guide
- **Chapter 15**: `docs/developer/chapters/15-ai-developer-guidelines.md` - AI guidelines

### Related Chapters

- **Chapter 1**: System Overview & Philosophy
- **Chapter 3**: Bootstrap System
- **Chapter 4**: Permission Architecture
- **Chapter 10**: Testing Framework

---

## Future Expansion

### Planned Enhancements

1. **Automated Code Review**
   - CI/CD integration
   - Automated checks
   - Quality gates

2. **Contribution Guidelines**
   - Pull request template
   - Code review checklist
   - Contribution process

3. **Breaking Change Registry**
   - Track breaking changes
   - Migration guides
   - Deprecation timeline

---

**Previous Chapter:** [Chapter 12 — Performance Guide](../chapters/12-performance-guide.md)  
**Next Chapter:** [Chapter 14 — PWA/Frontend Integration](../chapters/14-pwa-frontend-integration.md)

