# User Management Architecture - Single URL + Core DB

**Created:** November 3, 2025  
**Updated:** November 4, 2025  
**Status:** ✅ Implemented & Simplified  
**Architecture:** Single URL, tenant users in Core DB

---

## 🎯 Problem Solved

**Before (Problematic):**
```
admin_users.php (Single Page - WRONG!)
├─ Permission 1: platform.accounts.manage (Platform Admin)
├─ Permission 2: org.user.manage (Tenant Admin)
└─ Database: Core DB bgerp.account (both types mixed)
   ❌ Platform Owners + Tenant Users in same table
   ❌ Same UI for different purposes
   ❌ Confusing for both admin types
```

**After (Correct):**
```
Platform Admin → platform_accounts.php
├─ Permission: platform.accounts.manage ONLY
├─ Purpose: Manage Platform Owners (who manage tenants)
└─ Database: Core DB bgerp.account (Platform Owners only)

Tenant Admin → tenant_users.php
├─ Permission: org.user.manage ONLY
├─ Purpose: Manage Users within their organization
└─ Database: Core DB bgerp.account (will migrate to tenant_user later)
```

---

## 📂 Files Created/Modified

### **New Files (Tenant Users)**
1. `page/tenant_users.php` - Page definition
2. `views/tenant_users.php` - HTML template
3. `assets/javascripts/tenant/users.js` - Frontend logic
4. `source/tenant_users_api.php` - Backend API

### **Modified Files**
1. `page/admin_users.php` - Changed to Platform-only
2. `index.php` - Added routes (`tenant_users`, `platform_accounts`)
3. `views/template/sidebar-left.template.php` - Updated menu items

---

## 🔑 Permission Model

### **Platform Admin (Platform Console)**
```
Permission: platform.accounts.manage
Scope: Cross-tenant (manages Platform Owners)
Pages:
  - platform_accounts.php (admin_users.php renamed)
  - Can create/edit Platform Owners
  - Can assign platform roles
```

### **Tenant Admin (Organization)**
```
Permission: org.user.manage
Scope: Single tenant (manages users in their org)
Pages:
  - tenant_users.php (NEW)
  - Can create/edit Tenant Users
  - Can assign tenant roles
```

---

## 🗂️ Database Structure (Current State)

### **Core DB (`bgerp`)**
```sql
-- Still mixed (will be separated in Phase 2 of Refactor Plan)
account
├─ Platform Owners (should stay)
└─ Tenant Users (should move to tenant_user)

account_org
├─ Maps users to organizations
└─ Maps users to groups/roles

account_group  -- ⚠️ Will be removed Nov 4, 2025
├─ Global groups (Administrator, Supervisor, etc.)
└─ Used by both Platform and Tenant (legacy)

**⚠️ Schema Change (November 4, 2025):**
- `account_group` table will be removed
- `account_org.id_group` → `account_org.role_code` (VARCHAR)
- Owner bypass check will use `role_code = 'owner'` directly
```

### **Tenant DB (`bgerp_t_xxx`)**
```sql
tenant_role
├─ admin, supervisor, operator, qc_inspector, viewer
└─ Used for mapping in tenant_users.php

tenant_role_permission
├─ Maps tenant_role to permission codes
└─ Used for permission checks
```

---

## 🚀 API Endpoints

### **Tenant Users API (`tenant_users_api.php`)**
```
POST source/tenant_users_api.php

Actions:
- list: Get users in organization (DataTable)
- get: Get single user details
- create: Create new user
- update: Update user info
- update_status: Activate/deactivate user
- reset_password: Generate new password
- get_roles: Get available tenant roles
- list_invites: Get pending invitations (TODO)
- invite: Send email invitation (TODO)
- resend_invite: Resend invitation (TODO)
- cancel_invite: Cancel invitation (TODO)

Permission Required: org.user.manage
Scope: Current organization only (filtered by id_org)
```

### **Platform Accounts API (`admin_org.php` - existing)**
```
POST source/admin_org.php

Actions:
- users: List platform accounts
- user_save: Create/update platform account
- (Other actions for orgs, roles, etc.)

Permission Required: platform.accounts.manage OR platform.tenants.manage
Scope: Cross-tenant (all organizations)
```

---

## 🧭 Navigation (Sidebar)

### **Platform Console (platform-only class)**
```
Dashboard → platform_dashboard
Tenants → admin_organizations
Platform Accounts → platform_accounts (admin_users.php)
Migration Wizard → platform_migration_wizard
Health Check → platform_health_check
```

### **Administration (tenant-only - implicit)**
```
Users → tenant_users (NEW!)
Roles → admin_roles
Organizations → admin_organizations (tenant view)
```

---

## 🔒 Permission Checks

### **Platform Accounts Page**
```php
// page/admin_users.php (now platform-only)
$page_detail['permission_platform_codes'] = ['platform.accounts.manage'];
// Removed: permission_code (no longer dual-permission)
```

### **Tenant Users Page**
```php
// page/tenant_users.php
$page_detail['permission_code'] = 'org.user.manage';
// No permission_platform_codes (tenant-level only)
```

### **API Permission Checks**
```php
// source/tenant_users_api.php
if (!permission_allow_code($member, 'org.user.manage')) {
    json_error('forbidden - tenant admin permission required', 403);
}

// source/admin_org.php (platform accounts)
if (!platform_has_any(['platform.tenants.manage', 'platform.accounts.manage'])) {
    json_error('forbidden - platform admin only', 403);
}
```

---

## 🎨 UI Differences

### **Platform Accounts (`platform_accounts.php`)**
- **Focus:** Managing Platform Owners (who manage tenants)
- **Features:**
  - Create Platform Owner accounts
  - Assign platform roles (platform_super_admin, etc.)
  - Assign to multiple organizations
  - No tenant-specific fields

### **Tenant Users (`tenant_users.php`)**
- **Focus:** Managing users within organization
- **Features:**
  - Create organization users
  - Assign tenant roles (admin, supervisor, operator, etc.)
  - Single organization context (current org)
  - User invitations (email-based)
  - Last login tracking

---

## 📊 Role Mapping

### **Platform Roles (Core DB)**
```
platform_role (bgerp.platform_role)
├─ platform_super_admin (all permissions)
├─ platform_tenant_manager (manage tenants)
└─ platform_billing_admin (billing only)
```

### **Tenant Roles (Tenant DB)**
```
tenant_role (bgerp_t_xxx.tenant_role)
├─ admin (full org access)
├─ supervisor (manage tasks)
├─ operator (execute work)
├─ qc_inspector (quality control)
└─ viewer (read-only)
```

---

## 🧪 Testing Checklist

- [ ] Platform Admin can access `platform_accounts.php`
- [ ] Platform Admin can create Platform Owner
- [ ] Platform Admin CANNOT access `tenant_users.php` (permission denied)
- [ ] Tenant Admin can access `tenant_users.php`
- [ ] Tenant Admin can create Tenant User
- [ ] Tenant Admin can only see users in their org
- [ ] Tenant Admin CANNOT access `platform_accounts.php` (permission denied)
- [ ] Sidebar shows correct menu items for each role
- [ ] Old route `admin_users` still works (legacy support)

---

## 🔄 Migration Path (Future - Phase 2-8)

This separation is **Phase 0 prep** for the full refactor:

**Current State:**
- ✅ Separate UIs for Platform/Tenant admins
- ⚠️  Still using Core DB for both types (mixed)
- ⚠️  No `tenant_user` table yet

**Phase 1-2: Create `tenant_user` table**
- Migrate tenant users from Core DB → Tenant DB
- Keep Platform Owners in Core DB

**Phase 3-4: Dual-mode authentication**
- Support both Core and Tenant login
- Update `tenant_users_api.php` to use `tenant_user`

**Phase 5-6: Update foreign keys**
- Change all references from `account.id_member` → `tenant_user.id_tenant_user`
- Update 50+ files

**Phase 7-8: Cleanup**
- Remove tenant users from Core DB
- Deprecate old permission tables

---

## 📝 Key Takeaways

1. **Platform Admins** manage **Platform Owners** (who can access multiple tenants)
2. **Tenant Admins** manage **Tenant Users** (who work in one organization)
3. **Separate UIs** prevent confusion and mistakes
4. **Permission-based routing** ensures proper access control
5. **Database separation** (future) will provide true multi-tenant isolation

---

**This is a LIVING DOCUMENT. Update as refactoring progresses.**

