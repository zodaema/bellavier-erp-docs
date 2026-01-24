# AI Quick Start for Bellavier Group ERP

**Last Updated:** November 19, 2025  
**For:** AI agents (Cursor, ChatGPT, Claude, etc.) working on this codebase  
**Time:** 5-10 minutes to essential knowledge  
**Purpose:** Rules of engagement for AI-assisted development

---

## Scope

This document provides essential guidelines for AI agents working on the Bellavier Group ERP codebase. It defines:
- **What AI can do** (allowed changes)
- **What AI must NOT do** (forbidden changes)
- **How to safely make changes** (workflow)
- **Examples** (good vs. bad)

**Target Audience:**
- Cursor AI
- ChatGPT (with codebase context)
- Claude (with codebase access)
- Any AI agent with code editing capabilities

---

## Golden Rules for AI

### 1. Read Documentation First

**MUST read before making ANY changes:**
1. **Task Documentation**: `docs/bootstrap/Task/taskXX.md` (if working on specific task)
2. **Developer Policy**: `docs/developer/01-policy/DEVELOPER_POLICY.md`
3. **Bootstrap Docs**: `docs/bootstrap/tenant_api_bootstrap.md`, `core_platform_bootstrap.design.md`
4. **Related Task Docs**: `docs/bootstrap/Task/task16.md` - `task20.md`
5. **SuperDAG Core Knowledge** (if working on SuperDAG): `docs/developer/03-superdag/README.md` ⭐

**Time Investment:** 20-30 minutes reading → Prevents hours of debugging

### 2. Never Touch Business Logic Without Explicit Instruction

**FORBIDDEN:**
- ❌ Changing permission logic (`BGERP\Security\PermissionHelper`)
- ❌ Changing migration behavior (`BGERP\Migration\BootstrapMigrations`)
- ❌ Changing bootstrap behavior (`TenantApiBootstrap`, `CoreApiBootstrap`)
- ❌ Changing JSON response format (unless Task explicitly requests)
- ❌ Changing rate limiter configuration (unless Task explicitly requests)
- ❌ Changing CSRF validation logic (unless Task explicitly requests)

**ALLOWED:**
- ✅ Adding new features (if Task requests)
- ✅ Fixing bugs (if clearly identified)
- ✅ Refactoring code structure (if Task requests)
- ✅ Adding tests (always encouraged)

### 3. Maintain Backward Compatibility

**CRITICAL:**
- ✅ Preserve thin wrapper functions (`permission.php`, `bootstrap_migrations.php`)
- ✅ Don't change function signatures in helpers (Task 19)
- ✅ Don't break existing API responses
- ✅ Support both old and new patterns during transitions

**Exception:** Only if Task explicitly requests breaking changes.

### 4. Update Documentation

**MUST update:**
- ✅ Task documentation (`docs/bootstrap/Task/taskXX.md`)
- ✅ Bootstrap docs (if bootstrap changed)
- ✅ Developer docs (if workflow changed)
- ✅ CHANGELOG (if significant change)
- ✅ Implementation checklist (if new standard helpers/patterns were added): `docs/developer/02-quick-start/IMPLEMENTATION_EVERY_TIME_CHECKLIST.md`

**DO NOT:**
- ❌ Leave documentation outdated
- ❌ Skip documentation updates

### 5. Write Tests

**MUST:**
- ✅ Add integration tests for new features
- ✅ Update existing tests if behavior changes
- ✅ Run tests before completing: `vendor/bin/phpunit tests/Integration/SystemWide/`

**DO NOT:**
- ❌ Skip tests
- ❌ Break existing tests without fixing

---

## When Editing Bootstrap / Security-Sensitive Code

### Bootstrap Code (`TenantApiBootstrap`, `CoreApiBootstrap`)

**CRITICAL RULES:**
1. ✅ **Preserve Return Values**: Don't change what `init()` returns
   - `TenantApiBootstrap::init()` → `[$org, $tenantDb, $member]`
   - `CoreApiBootstrap::init($mode)` → `[$member, $coreDb]`

2. ✅ **Preserve Behavior**: Don't change initialization logic
   - Tenant resolution must work the same way
   - Session handling must work the same way
   - Database connection must work the same way

3. ✅ **Update Documentation**: If you change bootstrap, update:
   - `docs/bootstrap/tenant_api_bootstrap.md` or `core_platform_bootstrap.design.md`
   - Relevant Task doc

4. ✅ **Run Tests**: Always run SystemWide tests after bootstrap changes
   ```bash
   vendor/bin/phpunit tests/Integration/SystemWide/
   ```

**FORBIDDEN:**
- ❌ Changing return value structure
- ❌ Removing required initialization steps
- ❌ Breaking backward compatibility
- ❌ Changing method signatures

### Security-Sensitive Code (`PermissionHelper`, `BootstrapMigrations`)

**CRITICAL RULES (Task 19):**
1. ✅ **Preserve Function Signatures**: Don't change method names, parameters, or return types
   - `PermissionHelper::isPlatformAdministrator($member): bool`
   - `BootstrapMigrations::run_tenant_migrations_for($orgCode): void`

2. ✅ **Preserve Thin Wrappers**: Don't remove `permission.php` or `bootstrap_migrations.php`
   - These are thin wrappers for backward compatibility
   - Legacy code still uses them

3. ✅ **Preserve Business Logic**: Don't change permission or migration logic
   - Task 19 was namespace migration only
   - Business logic must remain unchanged

4. ✅ **Run Tests**: Always run SystemWide tests after helper changes
   ```bash
   vendor/bin/phpunit tests/Integration/SystemWide/
   ```

**FORBIDDEN:**
- ❌ Changing method signatures
- ❌ Removing thin wrapper functions
- ❌ Modifying permission/migration logic
- ❌ Refactoring control flow

### Security Code (Rate Limiter, CSRF, Serial Salt)

**CRITICAL RULES (Task 18):**
1. ✅ **Preserve Security Behavior**: Don't change rate limiter, CSRF, or salt logic
   - Rate limiter configuration is documented in Task 18
   - CSRF validation must work the same way
   - Serial salt generation must work the same way

2. ✅ **Update Security Docs**: If you change security code, update:
   - `docs/security/task18_security_notes.md`
   - Relevant Task doc

3. ✅ **Run Security Tests**: Always run security tests after changes
   ```bash
   vendor/bin/phpunit tests/Integration/SystemWide/SecurityAuditSystemWideTest.php
   ```

**FORBIDDEN:**
- ❌ Changing rate limiter configuration (unless Task requests)
- ❌ Removing CSRF protection
- ❌ Changing serial salt generation logic
- ❌ Logging sensitive data

---

## i18n & Frontend Code Standards (Mandatory)

### 1. Internationalization (i18n)

**REQUIRED FOR ALL NEW/UPDATED FRONTEND CODE**

- All user‑visible strings MUST use `translate()` in PHP or `t()` in JavaScript.
- The **default** (fallback) language MUST be **English**.
- Do **NOT** hard‑code Thai strings in source code.
- Do **NOT** use emoji, decorative icons, or special Unicode symbols inside messages or comments.
- Follow this pattern:

#### PHP Example
```php
<?= translate('products.form.production_line_label', 'Production Line') ?>
```

#### JavaScript Example
```javascript
t('job_ticket.detail.progress_label', 'Progress')
```

**DO NOT:**
```php
echo "ไลน์ผลิต";
```

### 2. Frontend Safety Standards

#### DOM Access
- Always **scope selectors** to a container (`$modal.find(...)`) — do NOT use global selectors.

#### No Inline Event Handlers
- Forbidden: `onclick="..."`, `onchange="..."`
- Required: `.on('click', ...)` in JS files

#### Forbidden Browser APIs
- `alert()`, `confirm()`, `prompt()` → **Forbidden**
- Must use `Swal.fire()` (SweetAlert2) or toast helpers

#### Comments
- Comments MUST be professional, technical, and in English.
- No emotional language, no informal tone.
- Example:

```javascript
// Validate that the product metadata response includes routing details
```

### 3. Frontend Architecture Requirements

- All modals must reset state using a dedicated `resetXYZModal()` function.
- All pages must have one entry JS file only (per page).
- All backend-facing JS calls MUST use:
  - `BG.api.request()` helper (from `assets/javascripts/global_script.js`)
  - Standard response format `{ ok: true/false }`
- All new UI features must support i18n out of the box.

---

## Step-by-Step Workflow for AI Agents

### Step 1: Identify Task

**If working on specific task:**
1. Read `docs/bootstrap/Task/taskXX.md`
2. Understand objective, scope, constraints
3. Review acceptance criteria

**If working on general improvement:**
1. Read `docs/developer/01-policy/DEVELOPER_POLICY.md`
2. Understand forbidden changes
3. Check if change is allowed

### Step 2: Read Related Documentation

**MUST read:**
1. **Bootstrap Docs**: `docs/bootstrap/tenant_api_bootstrap.md`, `core_platform_bootstrap.design.md`
2. **Task Docs**: `docs/bootstrap/Task/task16.md` - `task20.md` (relevant tasks)
3. **Security Docs**: `docs/security/task18_security_notes.md` (if security-related)
4. **Developer Policy**: `docs/developer/01-policy/DEVELOPER_POLICY.md`

**Time:** 20-30 minutes (prevents hours of debugging)

### Step 3: Explore Existing Code

**MUST do:**
1. Search for similar implementations (`grep`, `codebase_search`)
2. Read existing code for patterns
3. Check existing tests for examples
4. Verify no duplicate functionality exists

**DO NOT:**
- ❌ Create new code without checking existing
- ❌ Duplicate existing functionality

### Step 4: Implement Changes

**Follow patterns:**
1. Use existing helpers (`PermissionHelper`, `BootstrapMigrations`, `TenantApiOutput`)
2. Use correct bootstrap (`TenantApiBootstrap` or `CoreApiBootstrap`)
3. Maintain JSON format (`{ok: true/false}`)
4. Add rate limiting (if API endpoint)
5. Add CSRF protection (if state-changing)

**DO NOT:**
- ❌ Change business logic without Task approval
- ❌ Break backward compatibility
- ❌ Skip tests

### Step 5: Add/Update Tests

**MUST:**
1. Add integration tests for new features
2. Update existing tests if behavior changes
3. Use `IntegrationTestCase` base class (Task 16)
4. Follow patterns from Task 17 tests

**Run tests:**
```bash
vendor/bin/phpunit tests/Integration/SystemWide/
```

### Step 6: Update Documentation

**MUST update:**
1. Task doc (`docs/bootstrap/Task/taskXX.md`) - Implementation status
2. Bootstrap docs (if bootstrap changed)
3. Developer docs (if workflow changed)
4. CHANGELOG (if significant change)

**DO NOT:**
- ❌ Skip documentation updates
- ❌ Leave outdated documentation

### Step 7: Verify Changes

**Checklist:**
- [ ] All tests passing
- [ ] No PHP syntax errors (`php -l file.php`)
- [ ] Bootstrap usage correct
- [ ] JSON format standardized
- [ ] Rate limiting added (if API)
- [ ] CSRF protection added (if state-changing)
- [ ] Documentation updated
- [ ] Backward compatibility maintained

### Step 8: Recommend Manual Verification

**ALWAYS recommend:**
- Human developer should run `php -l` on changed files
- Human developer should run `vendor/bin/phpunit` manually
- Human developer should test in browser (if frontend)
- Human developer should review changes

**Rationale:** AI can make mistakes. Human verification is essential.

---

## Examples

### ✅ Good: Adding New Feature (Task Requests)

**Scenario:** Task 21 requests adding a new API endpoint.

**AI Actions:**
1. ✅ Read Task 21 doc
2. ✅ Check existing APIs for patterns
3. ✅ Use `TenantApiBootstrap::init()`
4. ✅ Use `TenantApiOutput::success()` for JSON
5. ✅ Add rate limiting
6. ✅ Add CSRF protection (if state-changing)
7. ✅ Add integration test
8. ✅ Update Task doc

**Result:** ✅ Safe, follows patterns, documented

### ✅ Good: Fixing Bug (Clearly Identified)

**Scenario:** Bug report: API returns null instead of JSON.

**AI Actions:**
1. ✅ Read `docs/bootstrap/Task/task20.md` (JSON output enforcement)
2. ✅ Check existing code for JSON output patterns
3. ✅ Fix to use `TenantApiOutput::success()`
4. ✅ Add test to prevent regression
5. ✅ Update documentation

**Result:** ✅ Safe, fixes bug, prevents regression

### ❌ Bad: Changing Permission Logic (No Task Approval)

**Scenario:** AI thinks permission logic can be "improved."

**AI Actions:**
1. ❌ Changes `PermissionHelper::isPlatformAdministrator()` logic
2. ❌ Doesn't read Task 19 (forbids logic changes)
3. ❌ Breaks existing permission checks

**Result:** ❌ **FORBIDDEN** - Breaks backward compatibility, violates Task 19 rules

### ❌ Bad: Removing Thin Wrappers (No Task Approval)

**Scenario:** AI thinks thin wrappers are "unnecessary."

**AI Actions:**
1. ❌ Removes `permission.php` thin wrapper
2. ❌ Doesn't read Task 19 (requires thin wrappers)
3. ❌ Breaks legacy code that uses `is_platform_administrator()`

**Result:** ❌ **FORBIDDEN** - Breaks backward compatibility, violates Task 19 rules

### ❌ Bad: Changing JSON Format (No Task Approval)

**Scenario:** AI thinks JSON format can be "improved."

**AI Actions:**
1. ❌ Changes from `{ok: true}` to `{success: true}`
2. ❌ Doesn't read Task 20 (standardized format)
3. ❌ Breaks all frontend code expecting `{ok: true}`

**Result:** ❌ **FORBIDDEN** - Breaks backward compatibility, violates Task 20 rules

### ✅ Good: Refactoring Code Structure (Task Requests)

**Scenario:** Task 22 requests refactoring API structure.

**AI Actions:**
1. ✅ Read Task 22 doc
2. ✅ Understand refactoring scope
3. ✅ Maintain backward compatibility (if required)
4. ✅ Update tests
5. ✅ Update documentation

**Result:** ✅ Safe, follows Task requirements

---

## Red Flags (STOP Immediately)

If you see yourself doing any of these, **STOP** and ask for clarification:

1. ❌ **Changing business logic** without Task approval
2. ❌ **Removing thin wrappers** (`permission.php`, `bootstrap_migrations.php`)
3. ❌ **Changing bootstrap signatures** (`TenantApiBootstrap::init()`, `CoreApiBootstrap::init()`)
4. ❌ **Changing JSON format** from `{ok: true/false}`
5. ❌ **Removing rate limiting** or CSRF protection
6. ❌ **Logging sensitive data** (passwords, tokens, salts)
7. ❌ **Breaking backward compatibility** without Task approval
8. ❌ **Skipping tests** or documentation updates

---

## Green Flags (Good to Proceed)

✅ Read Task documentation  
✅ Read Developer Policy  
✅ Checked existing code for patterns  
✅ Using existing helpers correctly  
✅ Maintaining backward compatibility  
✅ Adding/updating tests  
✅ Updating documentation  
✅ Following bootstrap patterns  
✅ Following JSON format standards  

---

## Quick Reference

### Must-Read Documents
- `docs/developer/01-policy/DEVELOPER_POLICY.md` - Rules and standards
- `docs/bootstrap/Task/task16.md` - `task20.md` - Recent task history
- `docs/bootstrap/tenant_api_bootstrap.md` - Tenant bootstrap spec
- `docs/bootstrap/core_platform_bootstrap.design.md` - Core bootstrap design

### Must-Follow Patterns
- Bootstrap: `TenantApiBootstrap::init()` or `CoreApiBootstrap::init()`
- JSON: `{ok: true/false}` via `TenantApiOutput` or `json_success()`/`json_error()`
- Tests: `IntegrationTestCase` base class, SystemWide test patterns
- Helpers: `PermissionHelper`, `BootstrapMigrations`, `TenantApiOutput`

### Must-Update Documentation
- Task doc (implementation status)
- Bootstrap docs (if bootstrap changed)
- Developer docs (if workflow changed)
- CHANGELOG (if significant change)

---

## Summary

**AI agents working on this codebase MUST:**
1. ✅ Read documentation first (20-30 min)
2. ✅ Follow Task requirements exactly
3. ✅ Maintain backward compatibility
4. ✅ Use existing helpers and patterns
5. ✅ Add/update tests
6. ✅ Update documentation
7. ✅ Recommend human verification

**AI agents MUST NOT:**
1. ❌ Change business logic without Task approval
2. ❌ Remove thin wrappers
3. ❌ Change bootstrap signatures
4. ❌ Change JSON format
5. ❌ Skip tests or documentation

**Remember:** This system handles real businesses and real money. Code with care, test thoroughly, and maintain backward compatibility.

---

**Next Steps:** Read `docs/developer/01-policy/DEVELOPER_POLICY.md` for complete rules and standards.
