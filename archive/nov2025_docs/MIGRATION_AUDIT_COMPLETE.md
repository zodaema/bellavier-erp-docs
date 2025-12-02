# Migration Files - Complete Audit & Fix Plan

**Date:** November 3, 2025  
**Auditor:** AI Agent (after user correction)  
**Status:** 🟡 Mixed Formats Found - Action Required

---

## 📊 Audit Results

### **Files Found (11 migrations):**

| File | Format | Table | Status | Action |
|------|--------|-------|--------|--------|
| `0001_init_tenant_schema.php` | NNNN_ | tenant_migrations | ✅ Run | 🔒 Keep (Foundation) |
| `0002_seed_sample_data.php` | NNNN_ | tenant_migrations | ✅ Run | 🔒 Keep (Foundation) |
| `0003_performance_indexes.php` | NNNN_ | tenant_migrations | ✅ Run | 🔒 Keep (Foundation) |
| `0004_session_improvements.php` | NNNN_ | tenant_migrations | ✅ Run | 🔒 Keep (Already Run) |
| `0005_serial_tracking.php` | NNNN_ | tenant_migrations | ✅ Run | 🔒 Keep (Already Run) |
| `0006_serial_unique_trigger.php` | NNNN_ | tenant_migrations | ✅ Run | 🔒 Keep (Already Run) |
| `0007_progress_event_type.php` | NNNN_ | tenant_migrations | ✅ Run | 🔒 Keep (Already Run) |
| `0008_dag_foundation.php` | NNNN_ | tenant_migrations | ✅ Run | 🔒 Keep (Already Run) |
| `0009_work_queue_support.php` | NNNN_ | **tenant_schema_migrations** ❌ | ✅ Run | ⚠️ **FIX REQUIRED** |
| `2025_11_tenant_user_accounts.php` | YYYY_MM_ | tenant_migrations | ✅ Run | ✅ Correct |
| `2025_11_migrate_users_to_tenant.php` | YYYY_MM_ | tenant_migrations | ✅ Run | ✅ Correct |

---

## ⚠️ Issues Found

### **Issue #1: 0009_work_queue_support.php in Wrong Table**
```
File: 0009_work_queue_support.php
Current Table: tenant_schema_migrations ❌
Should Be: tenant_migrations ✅

Problem:
- Migration Wizard queries tenant_migrations ONLY
- 0009 is in different table → won't show migration status correctly
- May cause re-run attempts (dangerous!)
```

### **Issue #2: Mixed Naming Formats**
```
NNNN_ format: 9 files (0001-0009)
YYYY_MM_ format: 2 files (2025_11_*)

Problem:
- Inconsistent naming makes chronological sorting confusing
- New developers won't know which format to use
- Migration Wizard expects YYYY_MM_ for filtering
```

---

## 🎯 Fix Strategy (Safe Approach)

### **Option A: Conservative (Recommended)**
**Keep existing files as-is, standardize going forward**

**Rationale:**
- Files 0001-0008 already run successfully
- Renaming could break migration tracking
- Risk > Reward for old files

**Actions:**
1. 🔒 Keep 0001-0008 unchanged (already run, working)
2. ⚠️ Fix 0009 ONLY (wrong table issue)
3. ✅ Document: All NEW migrations MUST use YYYY_MM_ format
4. ✅ Update .cursorrules with explicit check

### **Option B: Full Standardization (Risky)**
**Rename all 0001-0009 to YYYY_MM_ format**

**Rationale:**
- Clean, consistent naming
- Better for long-term maintenance

**Risks:**
- 🔴 Migration tracking may break
- 🔴 May trigger re-runs (data duplication!)
- 🔴 Requires updating both migration tables
- 🔴 Requires testing on all tenants

---

## ✅ Recommended Action Plan

### **Phase A: Fix Critical Issue (0009) - DO THIS NOW**

**Problem:**
```
0009_work_queue_support.php is in tenant_schema_migrations
→ Migration Wizard doesn't track it
→ Could cause re-run attempts
```

**Solution:**
```sql
-- Move record to correct table
INSERT INTO tenant_migrations (migration, executed_at, execution_time)
SELECT version, applied_at, NULL FROM tenant_schema_migrations 
WHERE version = '0009_work_queue_support';

-- Keep in old table for compatibility (don't delete)
```

**Verification:**
- Check Migration Wizard shows 0009 as completed
- Verify no re-run attempted

---

### **Phase B: Document Standard (DO THIS NOW)**

**Files to Update:**
1. `.cursorrules` - Add migration naming check
2. `IMPLEMENTATION_CHECKLIST.md` - Add migration format item
3. `docs/MIGRATION_NAMING_STANDARD.md` - Already created ✅

---

### **Phase C: Create Deprecation Notice (DO THIS NOW)**

**File:** `database/tenant_migrations/README.md`

**Content:**
```markdown
# Migration Naming Convention

## ✅ CORRECT FORMAT (Use This!)
YYYY_MM_description.php

Examples:
- 2025_11_tenant_user_accounts.php
- 2025_12_invoice_system.php

## ❌ DEPRECATED FORMAT (Don't Use!)
NNNN_description.php

Examples:
- 0009_work_queue_support.php (legacy)
- 0012_xxx.php (WRONG!)

## Rules:
1. All NEW migrations MUST use YYYY_MM_ format
2. Existing 0001-0009 kept for compatibility
3. Check Migration Wizard UI before creating
```

---

## 🚀 Implementation Steps

Let me proceed with the fix...

