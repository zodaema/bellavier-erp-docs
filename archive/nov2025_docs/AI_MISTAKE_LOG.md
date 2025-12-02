# AI Mistake Log - Learn From These!

**Purpose:** Document AI mistakes to improve future development  
**Target Audience:** AI Agents, Developers, QA Team

---

## 🔴 Mistake #1: Wrong Migration Naming Format

**Date:** November 3, 2025  
**Severity:** 🔴 CRITICAL  
**Impact:** Wasted 30+ minutes, nearly broke migration system  
**Status:** ✅ Fixed

### What Went Wrong:
```
AI created migrations with wrong format:
❌ 0012_tenant_user_accounts.php
❌ 0013_migrate_users_to_tenant.php

Should have been:
✅ 2025_11_tenant_user_accounts.php
✅ 2025_11_migrate_users_to_tenant.php
```

### Why It Happened:
1. ❌ AI didn't list existing migrations before creating new ones
2. ❌ AI didn't check Migration Wizard UI expectations
3. ❌ AI saw `0009_work_queue_support.php` and assumed it was correct
4. ❌ AI didn't read .cursorrules requirement: "Explore existing code (10-20 min)"

### Consequences:
- Migration files created with wrong format
- Had to rename files (manual work)
- Had to drop and recreate tables (data loss risk!)
- Had to re-run migrations
- Migration Wizard didn't show files initially
- User had to catch the error (not AI!)

### Root Cause:
**AI didn't follow Step 4 of AI_IMPLEMENTATION_WORKFLOW.md:**
> "Explore existing code (10-20 min)"
> - Check similar implementations
> - Read existing files for patterns
> - Understand conventions

### How It Should Have Been Done:

**STEP 1: Research (5 minutes)**
```bash
# List existing migrations
ls -lh database/tenant_migrations/ | tail -10

# Result would show:
2025_10_bom_cost_system.php
2025_01_schedule_system.php
0009_work_queue_support.php (outlier!)

# Conclusion: Use YYYY_MM_ format (majority pattern)
```

**STEP 2: Check Migration Wizard UI**
```
Open: Platform Console → Migration Wizard
See: All files with YYYY_MM_ format
Conclusion: This is the expected format!
```

**STEP 3: Query Database**
```sql
SELECT migration FROM tenant_migrations ORDER BY executed_at DESC LIMIT 5;

Result:
- 2025_10_bom_cost_system
- 0008_dag_foundation
- 0007_progress_event_type
- ...

Conclusion: tenant_migrations table is actively used
```

**STEP 4: Create Correctly**
```php
// File: 2025_11_tenant_user_accounts.php
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    // ... migration code
};
```

### Fix Applied:
```bash
# Rename files
mv 0012_tenant_user_accounts.php 2025_11_tenant_user_accounts.php
mv 0013_migrate_users_to_tenant.php 2025_11_migrate_users_to_tenant.php

# Drop tables created with wrong migration
DROP TABLE tenant_user_invite, tenant_user_session, tenant_user_token, tenant_user;

# Re-run with correct format
migration_run_php_migration($db, '2025_11_tenant_user_accounts.php', 'tenant_migrations', 'migration');
```

### Prevention (MUST DO for all future tasks):
1. ✅ **ALWAYS** list existing files first: `ls database/tenant_migrations/`
2. ✅ **ALWAYS** check UI expectations: Open Migration Wizard
3. ✅ **ALWAYS** read similar implementations
4. ✅ **ALWAYS** follow checklist in IMPLEMENTATION_CHECKLIST.md
5. ✅ **NEVER** assume format without verification

### Documentation Updated:
- ✅ Created: `docs/MIGRATION_NAMING_STANDARD.md`
- ✅ Updated: Memory with migration naming rules
- ✅ Created: This mistake log

### Lesson Learned:
> **"Check existing patterns BEFORE creating new files"**
> **"Read documentation BEFORE writing code"**
> **"Verify assumptions BEFORE implementing"**

---

## 🎯 Future Mistake Template

Use this format to document future mistakes:

```
## 🔴 Mistake #N: [Title]

**Date:** YYYY-MM-DD
**Severity:** 🔴 CRITICAL / 🟡 MEDIUM / 🟢 LOW
**Impact:** [Description]
**Status:** ✅ Fixed / ⏳ Pending / ❌ Unresolved

### What Went Wrong:
[Description]

### Why It Happened:
[Root cause analysis]

### Consequences:
[Impact on system, time wasted, etc.]

### Root Cause:
[Which rule/process was not followed?]

### How It Should Have Been Done:
[Step-by-step correct approach]

### Fix Applied:
[What was done to fix it]

### Prevention:
[Checklist for future]

### Documentation Updated:
[List of updated docs]

### Lesson Learned:
[One-line takeaway]
```

---

**Total Mistakes Logged:** 1  
**Total Time Wasted:** ~30 minutes  
**Target:** 0 critical mistakes per month

---

**Remember: Every mistake is a learning opportunity!**  
**Document, Learn, Improve!**

