# 🔐 Platform/Tenant Admin Separation - Implementation Guide

**Status:** ✅ Implemented (Option 3: Enhance Current System)  
**Date:** October 27, 2025

---

## 📊 Overview

This implementation enhances the existing permission system to clearly distinguish between:

- **🌐 Platform Administrators** - Manage the entire platform (all tenants)
- **🏢 Tenant Administrators** - Manage their organization only

---

## ✅ What Was Implemented

### **1. Helper Functions** (source/permission.php)

#### **`is_platform_administrator($member)`**
```php
/**
 * Check if user is platform administrator (super admin)
 * 
 * Checks platform_user + platform_user_role + platform_role tables
 * Returns true if user has platform_super_admin role
 */
function is_platform_administrator($member = null);
```

**Usage:**
```php
if (is_platform_administrator($logged_in_member_data)) {
    // Show platform console, allow access to all tenants
}
```

---

#### **`is_tenant_administrator($member, $org_code)`**
```php
/**
 * Check if user is tenant administrator (owner/admin)
 * 
 * Checks account_org + account_group tables
 * Returns true if user has 'owner' or 'admin' role in the specified tenant
 */
function is_tenant_administrator($member = null, $org_code = null);
```

**Usage:**
```php
if (is_tenant_administrator($logged_in_member_data, 'maison_atelier')) {
    // Allow tenant management for this org
}
```

---

#### **`can_access_tenant($member, $org_code)`**
```php
/**
 * Check if user can access a specific tenant
 * 
 * Platform admins → can access ALL tenants
 * Regular users → only their assigned tenants (via account_org)
 */
function can_access_tenant($member = null, $org_code = null);
```

**Usage:**
```php
if (can_access_tenant($logged_in_member_data, 'maison_atelier')) {
    // Load tenant data
} else {
    // Forbidden
}
```

---

#### **`get_admin_context($member)`**
```php
/**
 * Get user's admin context
 * 
 * Returns array with:
 * - type: 'platform' | 'tenant' | 'none'
 * - can_access_all: bool
 * - org: current org data
 * - is_tenant_admin: bool (if platform admin)
 */
function get_admin_context($member = null);
```

**Usage:**
```php
$ctx = get_admin_context($logged_in_member_data);

if ($ctx['type'] === 'platform') {
    // Show all tenants, platform console
} elseif ($ctx['type'] === 'tenant') {
    // Show current tenant only
} else {
    // No admin access
}
```

---

### **2. Updated `must_allow_admin()` Function**

**Before:**
```php
// Only checked specific permission codes
if (permission_allow_code($member, 'org.user.manage') || ...) {
    $allowed = true;
}
```

**After:**
```php
// Check platform/tenant admin first, then fallback to permissions
$isPlatformAdmin = is_platform_administrator($member);
$isTenantAdmin = is_tenant_administrator($member);

if ($isPlatformAdmin || $isTenantAdmin) {
    $allowed = true;
} else {
    // Fallback to specific permissions
}
```

**Benefits:**
- ✅ Platform admins bypass permission checks (they can do everything)
- ✅ Tenant admins get admin access within their org
- ✅ Backward compatible (still checks specific permissions)

---

### **3. Visual Hints in Sidebar**

#### **Administration Category:**

**Before:**
```
Administration
```

**After:**
```
Administration 🌐🏢  (if both platform & tenant admin)
Administration 🌐   (if platform admin only)
Administration 🏢   (if tenant admin only)
Administration      (if regular user)
```

**Implementation:**
```php
'label' => 'Administration',
'hint_function' => function() use ($logged_in_member_data) {
    $isPlatform = is_platform_administrator($logged_in_member_data);
    $isTenant = is_tenant_administrator($logged_in_member_data);
    if ($isPlatform && $isTenant) return ' 🌐🏢';
    if ($isPlatform) return ' 🌐';
    if ($isTenant) return ' 🏢';
    return '';
}
```

---

## 🎯 How It Works

### **User "admin" (Current Setup):**

```
Platform Level (Core DB):
  ✅ platform_user: id_member = 2 (admin)
  ✅ platform_role: platform_super_admin
  
Tenant Level (maison_atelier):
  ✅ account_org: id_member = 2, id_group = 2 (admin)
  
Result:
  🌐 is_platform_administrator() → TRUE
  🏢 is_tenant_administrator() → TRUE
  → Shows "Administration 🌐🏢" in sidebar
  → Can manage ALL tenants + current tenant
```

---

### **User "test" (Owner):**

```
Platform Level:
  ❌ NOT in platform_user table
  
Tenant Level (maison_atelier):
  ✅ account_org: id_member = 1, id_group = 1 (owner)
  
Result:
  🌐 is_platform_administrator() → FALSE
  🏢 is_tenant_administrator() → TRUE
  → Shows "Administration 🏢" in sidebar
  → Can manage current tenant ONLY
```

---

### **Regular User (e.g., production_operator):**

```
Platform Level:
  ❌ NOT in platform_user table
  
Tenant Level:
  ✅ account_org: id_member = X, id_group = 6 (production_operator)
  
Result:
  🌐 is_platform_administrator() → FALSE
  🏢 is_tenant_administrator() → FALSE
  → Shows "Administration" (no emoji)
  → Limited access based on specific permissions
```

---

## 📋 Usage Examples

### **Example 1: Admin Pages**

```php
// admin_users.php, admin_roles.php, etc.

require_once 'source/permission.php';

$member = $objMemberDetail->thisLogin();

// Method 1: Simple check
must_allow_admin($member); // Auto-allows platform/tenant admins

// Method 2: Explicit check
if (!is_platform_administrator($member) && !is_tenant_administrator($member)) {
    http_response_code(403);
    echo json_encode(['ok' => false, 'error' => 'forbidden']);
    exit;
}

// Method 3: Context-aware
$ctx = get_admin_context($member);

if ($ctx['type'] === 'platform') {
    // Show all tenants
    $tenants = get_all_tenants();
} elseif ($ctx['type'] === 'tenant') {
    // Show current tenant only
    $tenants = [$ctx['org']];
} else {
    // Forbidden
}
```

---

### **Example 2: Tenant Switching**

```php
// source/admin_org.php?action=switch_org

if (!can_access_tenant($member, $target_org_code)) {
    http_response_code(403);
    echo json_encode(['ok' => false, 'error' => 'forbidden']);
    exit;
}

// Platform admins can switch to ANY tenant
// Regular users can only switch to their assigned tenants
```

---

### **Example 3: UI Conditional Display**

```php
// views/admin_users.php

<?php
$isPlatformAdmin = is_platform_administrator($logged_in_member_data);
$isTenantAdmin = is_tenant_administrator($logged_in_member_data);
?>

<?php if ($isPlatformAdmin): ?>
    <!-- Show platform-specific options -->
    <button>Manage All Tenants</button>
    <button>Run Migrations</button>
<?php endif; ?>

<?php if ($isTenantAdmin): ?>
    <!-- Show tenant-specific options -->
    <button>Manage Users</button>
    <button>Manage Roles</button>
<?php endif; ?>
```

---

## 🔄 Migration Path

### **No Database Changes Required!** ✅

This implementation uses **existing tables**:
- `platform_user`, `platform_user_role`, `platform_role` (already exist)
- `account_org`, `account_group` (already exist)

**Zero migration risk!**

---

## 🧪 Testing

### **Test Platform Admin:**

```bash
php -r "
require_once 'config.php';
require_once 'source/permission.php';

\$member = ['id_member' => 2]; // admin user

echo 'Platform Admin: ' . (is_platform_administrator(\$member) ? 'YES ✅' : 'NO ❌') . \"\\n\";
echo 'Tenant Admin: ' . (is_tenant_administrator(\$member) ? 'YES ✅' : 'NO ❌') . \"\\n\";

\$ctx = get_admin_context(\$member);
echo 'Context: ' . \$ctx['type'] . \"\\n\";
echo 'Can access all: ' . (\$ctx['can_access_all'] ? 'YES' : 'NO') . \"\\n\";
"
```

**Expected:**
```
Platform Admin: YES ✅
Tenant Admin: YES ✅
Context: platform
Can access all: YES
```

---

### **Test Tenant Admin (Owner):**

```bash
php -r "
require_once 'config.php';
require_once 'source/permission.php';

\$_SESSION['current_org_code'] = 'maison_atelier';
\$member = ['id_member' => 1]; // test user (owner)

echo 'Platform Admin: ' . (is_platform_administrator(\$member) ? 'YES ✅' : 'NO ❌') . \"\\n\";
echo 'Tenant Admin: ' . (is_tenant_administrator(\$member) ? 'YES ✅' : 'NO ❌') . \"\\n\";

\$ctx = get_admin_context(\$member);
echo 'Context: ' . \$ctx['type'] . \"\\n\";
echo 'Can access all: ' . (\$ctx['can_access_all'] ? 'YES' : 'NO') . \"\\n\";
"
```

**Expected:**
```
Platform Admin: NO ❌
Tenant Admin: YES ✅
Context: tenant
Can access all: NO
```

---

## 🎨 UI Enhancements

### **Sidebar Menu:**

**Platform Admin sees:**
```
🌐 Platform Console
   • Tenants
   • Accounts

🏢 Bellavier Group ERP
   • Dashboard
   ...

Administration 🌐🏢
   • System Logs
   • User & Access
```

**Tenant Admin sees:**
```
Bellavier Group ERP
   • Dashboard
   ...

Administration 🏢
   • System Logs
   • User & Access
```

**Regular User sees:**
```
Bellavier Group ERP
   • Dashboard
   ...

Administration
   (limited items based on permissions)
```

---

## 📊 Permission Matrix

| User Type | Platform Console | All Tenants | Current Tenant | Limited Access |
|-----------|------------------|-------------|----------------|----------------|
| **Platform Super Admin** | ✅ | ✅ | ✅ | - |
| **Tenant Owner** | ❌ | ❌ | ✅ | - |
| **Tenant Admin** | ❌ | ❌ | ✅ | - |
| **Production Manager** | ❌ | ❌ | ❌ | ✅ (production only) |
| **Viewer** | ❌ | ❌ | ❌ | ✅ (read-only) |

---

## 🚀 Benefits

### **1. Clarity** ✅
- Visual indicators (🌐 vs 🏢)
- Clear function names
- Self-documenting code

### **2. Security** ✅
- Explicit checks
- Platform admins clearly identified
- Tenant isolation enforced

### **3. Maintainability** ✅
- Reusable functions
- Centralized logic
- Easy to test

### **4. Flexibility** ✅
- User can be both platform & tenant admin
- Context-aware UI
- Backward compatible

---

## 🔮 Future Enhancements

### **Optional (if needed later):**

1. **Platform Console Page:**
   ```
   views/platform_console.php
   - List all tenants
   - Quick stats per tenant
   - Run migrations
   - Monitor health
   ```

2. **Audit Trail:**
   ```
   platform_admin_log table
   - Track platform admin actions
   - Cross-tenant operations
   - Compliance reporting
   ```

3. **Role Hierarchy:**
   ```
   platform_super_admin
     └─ platform_support (read-only platform access)
        └─ tenant_owner
           └─ tenant_admin
              └─ tenant_roles...
   ```

---

## 📝 Code Reference

### **Key Files Modified:**

1. **source/permission.php**
   - Added 4 helper functions (180 lines)
   - All documented with PHPDoc

2. **source/admin_rbac.php**
   - Updated `must_allow_admin()` (20 lines)
   - Uses new helper functions

3. **views/template/sidebar-left.template.php**
   - Added hint rendering (10 lines)
   - Shows 🌐/🏢 emojis

**Total changes:** ~210 lines of code

---

## ✅ Testing Checklist

### **Functional Tests:**

- [x] Platform admin can access all features
- [x] Tenant admin can manage current tenant
- [x] Regular users see limited menu
- [x] Visual hints display correctly
- [x] Permission checks work correctly

### **Edge Cases:**

- [x] User is both platform & tenant admin
- [x] User switches between tenants
- [x] User has no admin role
- [x] Invalid org code handling
- [x] Database connection failures (graceful degradation)

---

## 🎯 Deployment

### **Already Deployed:** ✅

**No additional deployment steps needed!**

- ✅ Code changes already in place
- ✅ Uses existing database tables
- ✅ Backward compatible
- ✅ Zero downtime

**Just refresh browser to see changes!**

---

## 📚 Related Documentation

- `PLATFORM_VS_TENANT_ADMIN_GUIDE.md` - Architectural overview
- `PERMISSION_SIMPLE_GUIDE.md` - Permission system basics
- `PERMISSION_MANAGEMENT_GUIDE.md` - Admin guide

---

## 🎊 Summary

✅ **Platform/Tenant Admin separation implemented successfully**  
✅ **Clear visual indicators (🌐 Platform, 🏢 Tenant)**  
✅ **4 reusable helper functions**  
✅ **Enhanced security & clarity**  
✅ **Zero migration required**  
✅ **Production ready**

**Implementation:** ✅ COMPLETE  
**Status:** 🟢 READY TO USE

