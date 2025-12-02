# Core DB Migration Audit Report
**Date:** November 6, 2025  
**Database:** `bgerp` (Core Database)

---

## 📊 Current Status

### **Migration Files (4 files):**
```
database/migrations/
├── 0001_core_bootstrap.php                        61 KB  ✅ EXECUTED (Oct 17)
├── 2025_11_platform_role_cleanup.php              11 KB  ✅ EXECUTED (Nov 3)
├── 2025_11_merge_tenant_user_to_account.php      4.5 KB  ⚠️  NOT EXECUTED (partial?)
└── 2025_11_move_tenant_user_to_core.php          7.3 KB  ⚠️  NOT EXECUTED
```

---

## 🔍 Analysis

### **1. 0001_core_bootstrap.php (✅ GOOD)**
**Size:** 61 KB  
**Status:** ✅ Executed Oct 17, 2025  
**Contents:**
- Core tables: `account`, `organization`, `account_org`
- Platform roles & permissions
- Admin seed data
- Permission grants

**Verdict:** ✅ **KEEP** - Base schema, essential

---

### **2. 2025_11_platform_role_cleanup.php (✅ GOOD)**
**Size:** 11 KB  
**Status:** ✅ Executed Nov 3, 2025  
**Purpose:** Clean up platform roles

**Verdict:** ✅ **KEEP** (or archive if consolidated)

---

### **3. 2025_11_merge_tenant_user_to_account.php (⚠️ ISSUE)**
**Size:** 4.5 KB  
**Status:** ⚠️ **NOT in schema_migrations table**  
**Purpose:** 
- Add `user_type`, `org_code`, `id_tenant_role` to `account`
- Merge tenant_user data into account
- Drop tenant_user table

**Current Database State:**
- ✅ `account.user_type` EXISTS (enum: platform_super_admin, platform_owner, tenant_user)
- ❌ `account.org_code` NOT FOUND
- ❌ `account.id_tenant_role` NOT FOUND
- ❌ `tenant_user` table NOT FOUND (neither in Core nor Tenant DB)

**Analysis:**
- Migration was partially applied (user_type column exists)
- But NOT marked as executed in schema_migrations
- org_code and id_tenant_role columns missing
- No tenant_user table exists anywhere

**Possible Scenarios:**
1. Migration ran manually but not marked
2. user_type column added by another process
3. Migration approach abandoned mid-way

**Verdict:** ⚠️ **REVIEW NEEDED** - Partially applied, unclear state

---

### **4. 2025_11_move_tenant_user_to_core.php (⚠️ ISSUE)**
**Size:** 7.3 KB  
**Status:** ⚠️ **NOT EXECUTED**  
**Purpose:**
- Create `tenant_user` table in Core DB
- Move tenant_user from tenant DBs to core
- Prevent username collisions across tenants

**Current Database State:**
- ❌ `bgerp.tenant_user` NOT FOUND
- ❌ `bgerp_t_maison_atelier.tenant_user` NOT FOUND
- ❌ `bgerp_t_default.tenant_user` NOT FOUND

**Analysis:**
- Migration never executed
- No tenant_user table exists anywhere
- System may use different approach (account_org?)

**Verdict:** ⚠️ **LIKELY OBSOLETE** - No tenant_user tables exist

---

## 🤔 Conflicting Approaches

**Two different tenant user management approaches:**

### **Approach A: Merge into account**
File: `2025_11_merge_tenant_user_to_account.php`
- Add user_type to account
- Single account table for all users
- Status: Partially applied (user_type exists)

### **Approach B: Separate tenant_user table**
File: `2025_11_move_tenant_user_to_core.php`
- Create tenant_user in Core DB
- Keep account separate
- Status: Not applied

**Current Reality:**
- Using **Approach A** (partially)
- account.user_type exists
- No tenant_user table anywhere
- System uses `account` + `account_org` for multi-tenant

---

## 📋 Recommendations

### **Option 1: Complete Merge Migration ✅ RECOMMENDED**
**Actions:**
1. Run `2025_11_merge_tenant_user_to_account.php` to completion
2. Add missing columns (org_code, id_tenant_role)
3. Mark as executed in schema_migrations
4. Archive `2025_11_move_tenant_user_to_core.php` (not used)

**Pros:** Consistent with current state, completes started work  
**Cons:** Need to verify no data loss

---

### **Option 2: Clean Slate (Remove Unused Migrations) ⚠️ RISKY**
**Actions:**
1. Keep base schema in 0001_core_bootstrap.php
2. Add user_type to bootstrap (it's already there in production)
3. Archive both tenant_user migrations (unused)
4. Document decision

**Pros:** Clean, simple  
**Cons:** Lose migration history, unclear why user_type was added

---

### **Option 3: Consolidate Core DB (Like Tenant DB) 🎯 BEST**
**Actions:**
1. Export current Core DB schema
2. Create `0001_core_bootstrap_v2.php` with complete schema
3. Include user_type column (already in production)
4. Archive old migrations
5. Mark consolidated migration as executed

**Pros:** 
- Single source of truth
- Consistent with Tenant DB approach
- Clean deployment for new installations

**Cons:** More work upfront

---

## 🎯 Questions for User

1. **เก็บ migrations ที่ไม่ได้ใช้ไว้หรือลบ?**
   - `2025_11_merge_tenant_user_to_account.php` (บางส่วนทำแล้ว)
   - `2025_11_move_tenant_user_to_core.php` (ไม่เคยใช้)

2. **ต้องการ consolidate Core DB เหมือน Tenant DB หรือไม่?**
   - ข้อดี: Single file, clean, easy deployment
   - ข้อเสีย: ต้องใช้เวลาทำ

3. **ถ้า consolidate จะรวม platform_role_cleanup เข้าไปด้วยหรือไม่?**
   - Option A: เก็บแยก (audit trail)
   - Option B: รวมเข้า v2 (cleaner)

---

## 📊 Comparison: Tenant vs Core DB

| Aspect | Tenant DB | Core DB |
|--------|-----------|---------|
| **Before** | 15 files | 4 files |
| **After** | 3 files (80% reduction) | ? |
| **Strategy** | Consolidated ✅ | Not yet |
| **Status** | Clean ✅ | Has unused files ⚠️ |

---

**Waiting for user decision...**
