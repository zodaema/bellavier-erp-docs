# Migration Naming Standard

**Created:** November 3, 2025 (After Critical Mistake)  
**Purpose:** Document official naming convention to prevent future errors  
**Severity:** 🔴 CRITICAL - Wrong format = พังระบบ!

---

## ❌ **Mistake That Happened (Learn From This!)**

**What went wrong:**
- AI created `0012_tenant_user_accounts.php` (wrong format!)
- Should be: `2025_11_tenant_user_accounts.php`
- Wasted time: Create → Discover error → Rename → Drop tables → Re-run
- **Root cause:** Didn't check existing migrations first!

**Impact:**
- Migration ไม่ปรากฏใน Migration Wizard UI
- บันทึกใน wrong table (`tenant_schema_migrations` instead of `tenant_migrations`)
- User ต้องมา catch error เอง

---

## ✅ **Official Naming Convention**

### **Format: `YYYY_MM_description.php`**

**Components:**
- `YYYY`: 4-digit year (2025, 2026, etc.)
- `MM`: 2-digit month (01-12, leading zero required)
- `description`: snake_case description (lowercase, underscores)
- `.php`: Extension

**Examples:**
```
✅ CORRECT:
- 2025_11_tenant_user_accounts.php
- 2025_10_bom_cost_system.php
- 2025_01_schedule_system.php

❌ WRONG:
- 0012_tenant_user_accounts.php (old format, deprecated!)
- 2025_11_TenantUserAccounts.php (camelCase - wrong!)
- 2025-11-tenant-user-accounts.php (hyphens - wrong!)
- tenant_user_accounts_2025_11.php (order wrong!)
```

---

## 📋 **Migration Tables (2 Systems)**

### **Table 1: `tenant_migrations` (PRIMARY - Use This!)**
```sql
Columns:
- migration VARCHAR(191) PK
- executed_at DATETIME
- execution_time INT

Used by:
- Migration Wizard UI ✅
- migration_run_php_migration() ✅

Format Expected:
- YYYY_MM_description.php ✅
- (Any format, but YYYY_MM_ preferred for chronological sorting)
```

### **Table 2: `tenant_schema_migrations` (LEGACY)**
```sql
Columns:
- version VARCHAR(191) PK
- applied_at DATETIME

Used by:
- Old CLI scripts (deprecated)
- bootstrap_migrations.php (fallback)

Format Expected:
- NNNN_description.php (e.g., 0009_work_queue_support)
- ⚠️  AVOID using this format for new migrations!
```

---

## 🎯 **How to Check Before Creating Migration**

### **STEP 1: List existing migrations**
```bash
ls -la database/tenant_migrations/*.php | tail -10
```

**Look for:**
- Most recent files (newest at bottom)
- Naming pattern (YYYY_MM_ vs NNNN_)
- Follow the MAJORITY pattern

### **STEP 2: Check Migration Wizard**
```
Navigate to: Platform Console → Migration Wizard
Check: What files are listed?
Pattern: Should show YYYY_MM_xxx.php files
```

### **STEP 3: Query migration tables**
```sql
-- Check which table is actively used
SELECT * FROM tenant_migrations ORDER BY executed_at DESC LIMIT 5;
SELECT * FROM tenant_schema_migrations ORDER BY applied_at DESC LIMIT 5;

-- Compare: Which table has more recent entries?
```

---

## 🚨 **Red Flags (STOP if you see these!)**

1. 🔴 Creating migration with format `NNNN_` when others use `YYYY_MM_`
2. 🔴 Creating migration without checking existing files first
3. 🔴 Migration doesn't appear in Migration Wizard UI
4. 🔴 Using wrong migration table (tenant_schema_migrations vs tenant_migrations)

---

## ✅ **Checklist: Before Creating ANY Migration**

```
□ 1. List existing migrations in database/tenant_migrations/
□ 2. Identify naming pattern (YYYY_MM_ or NNNN_?)
□ 3. Check Migration Wizard UI (what format do they use?)
□ 4. Query tenant_migrations table (what's the latest?)
□ 5. Use migration_run_php_migration() function (not custom logic)
□ 6. Test that migration appears in Wizard UI
□ 7. Verify migration is saved in correct table

Score Required: 7/7 ✅
If ANY check fails: STOP and investigate!
```

---

## 📝 **Correct Migration Creation Process**

### **Step 1: Research (5 minutes)**
```bash
# Check existing migrations
ls -lh database/tenant_migrations/ | tail -10

# Check migration table
mysql -u root -proot [tenant_db] -e "SELECT migration FROM tenant_migrations ORDER BY executed_at DESC LIMIT 5"

# Open Migration Wizard UI
# Check what files are listed
```

### **Step 2: Determine Next Number**
```
Latest: 2025_11_migrate_users_to_tenant.php

Next (same month): 2025_11_xxx.php (add descriptive name)
Next (next month): 2025_12_xxx.php
```

### **Step 3: Create Migration**
```php
<?php
/**
 * Migration: 2025_11_feature_name
 * Description: What this migration does
 * Date: YYYY-MM-DD
 */

require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    // Migration logic here
    echo "Creating feature...\n";
    
    migration_create_table_if_missing($db, 'table_name', "(...)");
    
    echo "✅ Migration completed!\n";
};
```

### **Step 4: Test**
```bash
# Run migration
php -r "
require_once 'config.php';
require_once 'database/tools/migration_helpers.php';
\$db = tenant_db('default');
migration_run_php_migration(\$db, 'database/tenant_migrations/2025_11_xxx.php', 'tenant_migrations', 'migration');
"

# Verify in UI
# Open Migration Wizard → Check if file appears
```

---

## 📖 **Reference Examples**

### **Good Examples (Follow These):**
```php
// From existing migrations:
2025_10_bom_cost_system.php ✅
2025_01_schedule_system.php ✅
2025_11_tenant_user_accounts.php ✅ (after fix)

// Pattern:
YYYY_MM_feature_description.php
```

### **Bad Examples (DO NOT Use):**
```php
0009_work_queue_support.php ❌ (old CLI format)
0012_tenant_user_accounts.php ❌ (AI mistake - fixed!)
migration_0001.php ❌ (no date)
2025-11-feature.php ❌ (hyphens instead of underscores)
```

---

## 🎯 **For AI Agents (MANDATORY)**

**BEFORE creating ANY migration:**

1. ✅ Read this file: `docs/MIGRATION_NAMING_STANDARD.md`
2. ✅ List existing migrations: `ls database/tenant_migrations/`
3. ✅ Check Migration Wizard UI (what files are shown?)
4. ✅ Use format: `YYYY_MM_description.php`
5. ✅ Test that file appears in Wizard UI
6. ✅ Never assume - always verify!

**If in doubt:**
- Check `2025_10_bom_cost_system.php` (good example)
- Check migration_helpers.php (how it works)
- Check Migration Wizard code (what it expects)

---

**This mistake cost 30+ minutes of debugging time.**  
**Don't let it happen again!**

