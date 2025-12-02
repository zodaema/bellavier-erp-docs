# Chapter 15 — AI Developer Guidelines

**Last Updated:** November 19, 2025  
**Purpose:** Teach AI how to modify code safely in the Bellavier Group ERP system  
**Audience:** AI agents (Cursor, ChatGPT, Claude, etc.), developers using AI assistance

---

## Overview

This chapter provides comprehensive guidelines for AI agents working on the Bellavier Group ERP codebase. It defines golden rules, safety rails, dangerous zones, good vs bad patches, and specific handling instructions for bootstrap, security, and permission-sensitive code.

**Key Topics:**
- Golden Rules for AI
- Safety rails
- Dangerous zones
- Good vs Bad patches
- Handling bootstrap/security files
- Handling permission-sensitive code

**Philosophy:**
- Stability over cleverness
- Security over convenience
- Backward compatibility over refactor "beauty"
- AI is a co-pilot, not the owner

---

## Key Concepts

### 1. Primary Mission

**AI Agents must always prioritize:**

1. **Stability over cleverness**
   - Do not break working behavior
   - Do not introduce new side effects
   - Do not change business rules unless explicitly requested

2. **Security over convenience**
   - Never weaken authentication, authorization, or cryptographic operations
   - Any security change must include explanation and risk assessment

3. **Backward compatibility over refactor "beauty"**
   - Existing APIs must keep the same input/output contract
   - Prefer new functions/flags/options over breaking changes

### 2. Core Principles

**Stability First:**
- Do not break working behavior
- Do not introduce new side effects
- Do not change business rules unless explicitly requested

**Backward Compatibility:**
- Existing APIs must keep the same input/output contract
- If new behavior needed, prefer:
  - New functions
  - New flags/options
  - New versioned endpoints

**Minimal & Targeted Changes:**
- Edit the **smallest possible surface**
- Do not rewrite entire files when only a few lines needed
- Avoid "cleanup refactors" not requested in the task

**Security Above All:**
- Never weaken authentication, authorization, or cryptographic operations
- Any security change must include:
  - Short explanation
  - Clear risk/impact note
  - Test (if possible)

---

## Core Components

### Forbidden Zones (Do Not Touch Without Explicit Human Approval)

#### 1. Bootstrap Core

**Protected Files:**
- `TenantApiBootstrap` (and any file under `source/BGERP/Bootstrap/` related to tenant bootstrap)
- `CoreApiBootstrap`
- `CoreCliBootstrap` (if exists)
- Any future bootstrap classes

**Why Protected:**
- Define the **entry contract** for 52+ APIs
- Extremely sensitive to changes
- Used by all integration tests

**Rules:**
- ❌ Don't change return value structure
- ❌ Don't remove required initialization steps
- ❌ Don't break backward compatibility
- ✅ Add optional features (feature flags)
- ✅ Improve error messages
- ✅ Add logging (non-sensitive)

#### 2. Security & Permission Core

**Protected Files:**
- `BGERP\Security\PermissionHelper`
- Any `permission.php` thin wrapper
- `LogHelper` (except to add safe, non-sensitive logs)
- `RateLimiter` and related rate limit logic
- `platform_serial_salt_api.php` and related salt/crypto logic

**Why Protected:**
- Security-critical code
- Used by all APIs
- Task 19 forbids logic changes

**Rules:**
- ❌ Don't change permission logic
- ❌ Don't remove thin wrapper functions
- ❌ Don't modify security behavior
- ✅ Add new permission checks (if Task requests)
- ✅ Improve error messages
- ✅ Add logging (non-sensitive)

#### 3. Migration Core

**Protected Files:**
- `BGERP\Migration\BootstrapMigrations`
- `bootstrap_migrations.php` wrapper
- `run_tenant_migrations.php`

**Why Protected:**
- Migration behavior must remain stable across all tenants
- Used in production deployments
- Task 19 forbids logic changes

**Rules:**
- ❌ Don't change migration behavior
- ❌ Don't remove thin wrapper functions
- ❌ Don't modify migration execution logic
- ✅ Add new migration helpers (if needed)
- ✅ Improve error messages

#### 4. Legacy PWA Scan System

**Protected Files:**
- `pwa_scan_api.php` and related legacy helpers

**Why Protected:**
- Known to be complex and fragile
- Has function redeclaration issues
- Planned for refactor in future task

**Rules:**
- ❌ Don't touch unless dedicated PWA Scan refactor task
- ✅ Document issues found
- ✅ Propose refactor plan (don't implement)

#### 5. System-Wide Tests

**Protected Files:**
- Files under `tests/Integration/SystemWide/*`

**Why Protected:**
- Define **system contracts**
- Used to validate system behavior

**Rules:**
- ✅ Add new tests if needed
- ❌ Don't modify existing assertions unless Task specifically requests
- ✅ Update tests if behavior changes (with Task approval)

### Allowed but Restricted Zones

#### 1. Tenant APIs

**Allowed:**
- ✅ Use `TenantApiOutput` to standardize JSON format
- ✅ Improve error handling and validation
- ✅ Add logging (via `LogHelper`) without exposing sensitive data

**Forbidden:**
- ❌ Changing the meaning of existing actions (`action=list` must still "list" in the same way)
- ❌ Changing DB queries in ways that filter out or include additional records unless clearly requested
- ❌ Renaming or removing existing actions without migration steps

#### 2. Platform APIs

**Allowed:**
- ✅ Migrate to `CoreApiBootstrap` when needed (if not already)
- ✅ Normalize JSON output and error formats
- ✅ Add additional safety checks (permissions, CSRF, rate limits)

**Forbidden:**
- ❌ Weakening permission checks
- ❌ Changing role/permission mappings without explicit approval
- ❌ Exposing internal IDs or sensitive configuration data

---

## Required Workflow for Any AI Task

### Step 1: Read Relevant Docs First

**MUST Read:**
- `docs/developer/README.md`
- `docs/developer/01-policy/DEVELOPER_POLICY.md`
- `docs/developer/02-quick-start/QUICK_START.md`
- `docs/developer/02-quick-start/GLOBAL_HELPERS.md`
- Task-specific doc under `docs/bootstrap/Task/` or `docs/performance/`, etc.

**Time Investment:** 20-30 minutes reading → Prevents hours of debugging

### Step 2: Identify the Scope Clearly

**Questions to Answer:**
- Which file(s) are allowed to change?
- Which behavior must remain the same?
- Which task number (e.g., Task 20, Task 21) is being executed?

### Step 3: Plan Before Editing

**Write Short Reasoning:**
- What will be changed and why
- Ensure the plan respects forbidden zones and safety rules
- Identify potential risks

### Step 4: Apply Minimal Patch

**Principles:**
- Change the smallest possible area
- Keep old behavior intact unless clearly instructed
- Maintain backward compatibility

### Step 5: Run Basic Checks

**Checks:**
- `php -l` on modified files (syntax check)
- `composer dump-autoload` if new classes were added
- Appropriate `phpunit` command for related tests

### Step 6: Document the Change

**Update Documentation:**
- Update corresponding `docs/bootstrap/Task/taskXX.md` or related doc
- Summarize:
  - Files changed
  - Behavior changes (if any)
  - Tests run

### Step 7: Leave TODO/NOTE When Unsure

**When to Leave TODO:**
- If environment prevents full testing (e.g., missing DB table)
- If behavior is unclear
- If change might have side effects

**Format:**
```php
// TODO(ai): Needs manual verification in real environment.
// Never "fake" a passing state.
```

---

## What AI Must Never Do

### ❌ Forbidden Actions

1. **Rewrite large files just for style**
   - Don't reformat entire files
   - Don't change code style unless Task requests

2. **Remove legacy code paths without confirming they are unused**
   - Check usage first
   - Provide migration path if removing

3. **Change configuration for production**
   - Don't change DB, domain, credentials
   - Don't modify production settings

4. **Log sensitive data**
   - Don't log passwords, tokens, salts, personal data
   - Use `LogHelper` which filters sensitive data

5. **Silence errors by blindly catching exceptions and ignoring them**
   - Always log errors
   - Never empty catch blocks
   - Always provide error context

---

## AI + Human Collaboration

### AI is a Co-Pilot, Not the Owner

**For decisions involving:**
- Security
- Permission changes
- Data model changes
- Public API contracts

**AI must:**
- ✅ **Propose** options
- ✅ **Wait for explicit human approval** before applying large or irreversible changes
- ✅ **Explain risks and benefits**
- ✅ **Provide migration path** if breaking change

### When to Ask for Approval

**Ask for Approval When:**
- Changing bootstrap signatures
- Modifying permission logic
- Changing migration behavior
- Breaking backward compatibility
- Large refactors (> 100 lines)
- Security-related changes

**Don't Ask for Approval When:**
- Adding new features (if Task requests)
- Fixing bugs (if clearly identified)
- Adding tests
- Updating documentation
- Small, safe changes

---

## Examples

### ✅ Good: Adding New Feature (Task Requests)

**Scenario:** Task 22 requests adding a new API endpoint.

**AI Actions:**
1. ✅ Read Task 22 doc
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

**Scenario:** Task 23 requests refactoring API structure.

**AI Actions:**
1. ✅ Read Task 23 doc
2. ✅ Understand refactoring scope
3. ✅ Maintain backward compatibility (if required)
4. ✅ Update tests
5. ✅ Update documentation

**Result:** ✅ Safe, follows Task requirements

---

## Handling Bootstrap/Security Files

### When Editing Bootstrap Code

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

### When Editing Security-Sensitive Code

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

### When Editing Security Code (Rate Limiter, CSRF, Serial Salt)

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

## Step-by-Step Workflow for AI Agents

### Complete Workflow

1. **Read Documentation (20-30 min)**
   - Task doc (if exists)
   - Developer Policy
   - Relevant chapters
   - Existing code patterns

2. **Identify Scope**
   - Which files allowed to change?
   - Which behavior must remain same?
   - Which task number?

3. **Plan Changes**
   - Write short reasoning
   - Ensure plan respects forbidden zones
   - Identify risks

4. **Implement Changes**
   - Minimal patch
   - Keep old behavior intact
   - Maintain backward compatibility

5. **Run Checks**
   - `php -l` (syntax)
   - `composer dump-autoload` (if new classes)
   - `phpunit` (tests)

6. **Document Changes**
   - Update Task doc
   - Summarize files changed
   - Document behavior changes
   - Document tests run

7. **Leave TODO if Unsure**
   - If environment prevents testing
   - If behavior unclear
   - Never "fake" passing state

8. **Recommend Human Verification**
   - Always recommend human review
   - Suggest manual testing
   - Highlight potential risks

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

## Reference Documents

### AI-Specific Documentation

- **AI Quick Start**: `docs/developer/02-quick-start/AI_QUICK_START.md` - 5-minute guide
- **Developer Policy**: `docs/developer/01-policy/DEVELOPER_POLICY.md` - Complete rules
- **Chapter.md**: `docs/developer/chapter.md` - AI Agent Operating Rules

### Task Documentation

- **Tasks 16-21**: `docs/bootstrap/Task/task16.md` - `task21.md` - Recent task history
- **Security Notes**: `docs/security/task18_security_notes.md` - Security audit

### Related Chapters

- **Chapter 1**: System Overview & Philosophy
- **Chapter 3**: Bootstrap System
- **Chapter 4**: Permission Architecture
- **Chapter 11**: Security Handbook
- **Chapter 13**: Refactor & Contribution Guide

---

**Previous Chapter:** [Chapter 14 — PWA/Frontend Integration](../chapters/14-pwa-frontend-integration.md)  
**Back to:** [Chapter 1 — System Overview](../chapters/01-system-overview.md)

---

**End of Developer Handbook Chapters**

