# User Architecture - Final Decision (Option A)

**Date:** November 3, 2025  
**Decision:** Tenant Owners in Core DB, Tenant Users in Tenant DB  
**Status:** ✅ Implemented & Fixed

---

## 🎯 Final Architecture (Option A)

### **Core DB (bgerp.account):**
```
Purpose: Platform-level users who can manage/view multiple tenants

Contains:
✅ Platform Super Admins (admin)
✅ Tenant Owners (test, test2, ...)
✅ Platform Developers
✅ Executives with cross-tenant access

Does NOT contain:
❌ Tenant Operators
❌ Tenant Supervisors  
❌ Tenant-specific employees
```

### **Tenant DB (tenant_user):**
```
Purpose: Tenant-specific employees (locked to one organization)

Contains:
✅ Production Operators (test_operator01, ...)
✅ Production Supervisors
✅ QC Inspectors
✅ Inventory Staff
✅ Any employee working FOR that tenant

Does NOT contain:
❌ Platform Admins
❌ Tenant Owners (they're in Core DB)
```

---

## 👥 User Type Classification

### **Type 1: Platform Super Admin**
```
Database: Core DB (account)
Example: admin
Characteristics:
- Bypass ALL permissions (even tenant permissions)
- Can access ALL tenants
- Manage platform-level features (migrations, health check)
- NOT specific to any tenant

Login: Standard login (no org context needed)
Session: $_SESSION['member'] with is_platform_admin flag
```

### **Type 2: Tenant Owner**
```
Database: Core DB (account)
Examples: test, test2
Characteristics:
- Can own/manage multiple tenants
- Switch between their tenants
- See cross-tenant reports
- Has 'owner' role in account_group

Login: Standard login → choose tenant via admin_organizations
Session: $_SESSION['member'] + platform_context
```

### **Type 3: Tenant User (Operators, etc.)**
```
Database: Tenant DB (tenant_user)
Examples: test_operator01
Characteristics:
- Locked to ONE tenant only
- Cannot switch tenants
- Work FOR that organization
- Roles: operator, supervisor, qc, inventory

Login: Login with org context (?org=maison_atelier)
Session: $_SESSION['tenant_user']
```

---

## 🔄 Login Flow by User Type

### **Platform Admin (admin):**
```
1. Login at: http://localhost:8888/bellavier-group-erp
2. No org context needed
3. Authenticate via Core DB (account table)
4. Session: $_SESSION['member']
5. Redirect: platform_dashboard
6. Can switch tenant via UI
```

### **Tenant Owner (test, test2):**
```
1. Login at: http://localhost:8888/bellavier-group-erp
2. No org context initially
3. Authenticate via Core DB (account table)
4. Session: $_SESSION['member']
5. See list of their tenants (from account_org)
6. Choose tenant → dashboard
7. Can switch via organization selector
```

### **Tenant User (test_operator01):**
```
1. Login at: http://localhost:8888/bellavier-group-erp?org=maison_atelier
2. Org context from URL or subdomain
3. Authenticate via Tenant DB (tenant_user table)
4. Session: $_SESSION['tenant_user']
5. Redirect: dashboard (tenant-specific)
6. CANNOT switch to other tenants
```

---

## 📊 Current State (After Fix)

### **Core DB (bgerp.account):**
| id_member | username | name | status | role | classification |
|-----------|----------|------|--------|------|----------------|
| 1 | admin | Administrator | ✅ 1 | Platform Admin | 🔷 Platform Admin |
| 2 | test | test | ✅ 1 | owner | 👑 Tenant Owner |
| 3 | test2 | test2 | ✅ 1 | owner | 👑 Tenant Owner |
| 4 | test_operator01 | Test Operator 01 | ❌ 0 | operator | ❌ Deactivated (moved to Tenant DB) |

**Total Active:** 3 users (1 Platform Admin + 2 Owners) ✅

### **Tenant DB (maison_atelier.tenant_user):**
| id_tenant_user | username | name | email | role |
|----------------|----------|------|-------|------|
| 2 | test_operator01 | Test Operator 01 | operator01@test.com | production.operator |

**Total:** 1 user (Operator) ✅

### **Tenant DB (default.tenant_user):**
| id_tenant_user | username | name | email | role |
|----------------|----------|------|-------|------|
| (empty) | - | - | - | - |

**Total:** 0 users ✅ (no employees yet)

---

## ✅ Verification Checklist

- [x] No duplicate users (same username in both DBs)
- [x] Platform Admins in Core DB ONLY
- [x] Tenant Owners in Core DB ONLY
- [x] Tenant Operators in Tenant DB ONLY
- [x] test_operator01 deactivated in Core DB
- [x] test_operator01 active in Tenant DB
- [x] test and test2 remain in Core DB (owners)
- [x] All active Core DB users are Platform Admins or Owners

---

## 🔐 Permission Model

### **Platform Admin (admin):**
```
Function: is_platform_administrator() → TRUE
Permission Check: BYPASS ALL (can do anything)
Access: ALL tenants
```

### **Tenant Owner (test, test2):**
```
Function: is_tenant_administrator() → TRUE (for their tenants)
Permission Check: Uses account_org + tenant_role_permission
Access: Their tenant(s) ONLY
Can: Manage users, view reports, configure settings
```

### **Tenant User (test_operator01):**
```
Function: tenant_permission_allow_code() → Check tenant_role_permission
Permission Check: Direct lookup via id_tenant_user → id_tenant_role
Access: Their tenant ONLY
Can: Perform job-specific tasks based on assigned role
```

---

## 📝 Important Notes

### **Why Owners in Core DB?**
1. ✅ Can own multiple tenants (scalability)
2. ✅ Can switch between their tenants
3. ✅ Platform Admin can manage owners via admin_organizations
4. ✅ Cross-tenant reports easier to implement

### **Why Operators in Tenant DB?**
1. ✅ Locked to one tenant (security)
2. ✅ Managed by Tenant Admin (not Platform Admin)
3. ✅ Fast authentication (no Core DB hit)
4. ✅ True data isolation

### **Backward Compatibility:**
```
Existing code checks:
- $_SESSION['member'] → Still works! (alias)
- id_member → Works for Platform users & Owners
- id_tenant_user → Works for Tenant users

Both paths work! Migration is safe.
```

---

## 🚀 Next Steps

### **For Testing:**
1. Test login as "admin" → Should access all tenants ✅
2. Test login as "test" → Should see maison_atelier ✅
3. Test login as "test_operator01" with ?org=maison_atelier → Should work ✅
4. Verify permissions for each user type

### **For Future:**
1. Add more tenant users via tenant_users UI
2. Deactivate remaining operators from Core DB (if any)
3. Consider: Automatically detect user type during migration

---

**Architecture:** ✅ **CORRECT & SCALABLE**  
**Data State:** ✅ **CLEAN (no duplicates)**  
**Ready:** ✅ **YES (for testing)**

