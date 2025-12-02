# 🔐 Platform Super Admin: Full Tenant Access

**Last Updated:** October 27, 2025  
**Status:** ✅ Implemented & Tested

---

## 📋 Overview

Platform Super Administrators ตอนนี้มี **full access ทุก tenants** โดยไม่ต้องเพิ่มเข้า `account_org` table

---

## ✅ Features Implemented

### 1. **Organization Switcher**
```
Platform Admin เห็น: ALL active tenants
Regular User เห็น: เฉพาะ tenants ที่ assigned (account_org)
```

**Implementation:**
- `source/admin_org.php` → `my_orgs` API
- แก้ไข query ให้ platform admin ดึงจาก `organization` ทั้งหมด

### 2. **Organization Access Validation**
```php
can_access_tenant($member, $org_code):
  - Platform Admin: return true (ทุก tenant)
  - Regular User: check account_org
```

**Implementation:**
- `source/permission.php` → `can_access_tenant()`
- Return true ทันทีถ้าเป็น platform admin

### 3. **Permission System**
```php
tenant_permission_allow_code($member, $permission_code):
  - Platform Admin: return true (ทุก permission)
  - Regular User: check tenant_role_permission
```

**Implementation:**
- `source/permission.php` → `tenant_permission_allow_code()`
- เพิ่ม check `is_platform_administrator()` ก่อนทุกอย่าง

### 4. **Organization Resolution**
```php
resolve_current_org():
  - Platform Admin: เลือกได้จาก organization ทั้งหมด
  - Regular User: เลือกได้เฉพาะที่มี account_org
```

**Implementation:**
- `config.php` → `resolve_current_org()`
- แก้ไข fallback logic ให้ platform admin query จาก organization ทั้งหมด

### 5. **Switch Organization**
```php
switch_org:
  - Validate access ด้วย can_access_tenant()
  - Clear permission cache หลัง switch
  - Update session & cookie
```

**Implementation:**
- `source/admin_org.php` → `switch_org`
- เพิ่ม access validation และ cache clearing

---

## 🎯 Platform Admin Capabilities

### **What Platform Admins CAN Do:**

```
✅ View ALL tenants in organization switcher
✅ Switch to ANY tenant without account_org record
✅ Access ALL pages in ANY tenant
✅ Have ALL permissions in ALL tenants
✅ Manage platform-level features:
   • Tenants management
   • User accounts (cross-tenant)
   • Migration deployment (Migration Wizard)
   • System health monitoring (Health Check)
   • Platform dashboard overview
```

### **What Regular Users CANNOT Do:**

```
❌ See tenants they're not assigned to
❌ Switch to tenants without account_org record
❌ Access platform-level features
❌ Deploy migrations
❌ View system health check
```

---

## 🔧 Technical Implementation

### File Changes:

#### 1. `source/permission.php`
```php
function tenant_permission_allow_code($member_row, $permission_code) {
    // NEW: Platform admins bypass all checks
    if (is_platform_administrator($member_row)) {
        return true;
    }
    
    // Regular permission checking...
}
```

#### 2. `source/admin_org.php`
```php
case 'my_orgs':
    // NEW: Platform admins see all organizations
    if (is_platform_administrator($_SESSION['member'])) {
        $sql = "SELECT * FROM organization WHERE status = 1";
    } else {
        $sql = "SELECT * FROM account_org WHERE id_member = ?";
    }
```

#### 3. `config.php`
```php
function resolve_current_org(?string $preferredCode = null): ?array {
    // NEW: Platform admins can select any organization
    if ($isPlatformAdmin) {
        $sql = "SELECT * FROM organization WHERE status = 1 LIMIT 1";
    } else {
        $sql = "SELECT * FROM account_org WHERE id_member = ? LIMIT 1";
    }
}
```

#### 4. `source/admin_org.php` (switch_org)
```php
case 'switch_org':
    // NEW: Verify access with platform admin bypass
    $canAccess = can_access_tenant($_SESSION['member'], $code);
    
    if ($canAccess) {
        // Clear permission cache for clean state
        unset($_SESSION['_cached_permissions']);
    }
```

---

## 🧪 Testing

### Test Scenario 1: Platform Admin Login
```bash
Login: admin / password
Expected:
  ✅ See "Platform Console" menu
  ✅ See ALL tenants in org switcher
  ✅ Can switch to any tenant
  ✅ Has all permissions in all tenants
```

### Test Scenario 2: Switch Tenant
```bash
1. Login as platform admin
2. Click organization switcher
3. Select "maison_atelier"
4. Verify:
   ✅ URL redirects to index.php
   ✅ Organization name changes in header
   ✅ Can access all pages (Dashboard, MO, etc.)
   ✅ All menus visible
```

### Test Scenario 3: Regular User Login
```bash
Login: regular_user / password
Expected:
  ❌ No "Platform Console" menu
  ✅ See only assigned tenants in org switcher
  ❌ Cannot access platform features
```

---

## 📊 Database Structure

### Platform Level (Core DB):
```sql
-- Platform users and roles
platform_user
platform_role (code: platform_super_admin)
platform_user_role
```

### Tenant Level (Tenant DB):
```sql
-- Tenant-specific roles and permissions
tenant_role (owner, admin, etc.)
permission (93 permissions synced from core)
tenant_role_permission
```

### Account Assignment (Core DB):
```sql
-- User-to-Organization mapping
account_org (id_member, id_org, id_group)
-- Regular users NEED this
-- Platform admins DO NOT need this
```

---

## 🎯 Migration Tracking

### Unified Table: `tenant_migrations`

**Old System:**
```
provision_tenant() → tenant_schema_migrations
Migration Wizard   → tenant_migrations
❌ Inconsistent tracking
```

**New System:**
```
provision_tenant() → tenant_migrations
Migration Wizard   → tenant_migrations
✅ Unified tracking
```

**Migration Script:**
```sql
-- Auto-migrate old records
INSERT IGNORE INTO tenant_migrations (migration, executed_at)
SELECT version, applied_at 
FROM tenant_schema_migrations;
```

---

## 🚀 Platform Tools

### 1. **Platform Dashboard**
```
URL: ?p=platform_dashboard
Features:
  • Tenant overview (count, status, health)
  • User statistics
  • Migration status
  • Quick actions
  • Tenant table with details
```

### 2. **Migration Wizard**
```
URL: ?p=platform_migration_wizard
Features:
  • Select migration file
  • Select target tenants
  • Test migration (dry run)
  • Deploy to multiple tenants
  • View migration logs
  • Track deployment status
```

### 3. **Health Check**
```
URL: ?p=platform_health_check
Features:
  • Core system diagnostics (9 tests)
  • Database connections (per tenant)
  • Permission system validation
  • Migration status checking
  • Tenant isolation verification
  • File system checks
  • Real-time health score (30 tests total)
```

---

## 🔍 Troubleshooting

### Issue: "Platform admin ไม่มี permissions หลัง switch"

**Solution:**
```php
// Ensure platform admin check in tenant_permission_allow_code()
if (is_platform_administrator($member_row)) {
    return true;  // Bypass all checks
}
```

### Issue: "ไม่เห็น tenants ใน organization switcher"

**Solution:**
```php
// Ensure my_orgs API returns all orgs for platform admin
if (is_platform_administrator($_SESSION['member'])) {
    $sql = "SELECT * FROM organization WHERE status = 1";
}
```

### Issue: "Switch org แล้ว permissions ยังไม่อัพเดท"

**Solution:**
```php
// Clear permission cache in switch_org
unset($_SESSION['_cached_permissions']);
session_write_close();
```

---

## 📝 Best Practices

### 1. **Platform Admin Account Security**
- ใช้รหัสผ่านที่แข็งแกร่ง
- เปิด 2FA ถ้าเป็นไปได้
- จำกัดจำนวน platform admins
- Audit log การ switch tenant

### 2. **Tenant Admin Separation**
- แต่ละ tenant ควรมี admin ของตัวเอง
- Platform admin ไม่ควร assigned เข้า account_org
- ใช้ tenant admin สำหรับงานประจำวัน

### 3. **Migration Management**
- ใช้ Migration Wizard สำหรับ deployment
- Test migration ก่อน deploy จริงเสมอ
- Deploy ไปยังหลาย tenants พร้อมกัน
- เก็บ migration logs

---

## 🎉 Summary

```
┌────────────────────────────────────────────────────────┐
│  Platform Super Admin: Full Access Implementation     │
├────────────────────────────────────────────────────────┤
│  ✅ Access Control: Implemented                       │
│  ✅ Permission Bypass: Working                        │
│  ✅ Organization Switcher: Shows all tenants          │
│  ✅ Session Management: Proper cache clearing         │
│  ✅ Platform Tools: 3 tools available                 │
│  ✅ Testing: All scenarios passed                     │
└────────────────────────────────────────────────────────┘
```

**Platform admins ตอนนี้สามารถ:**
- Switch ไปยังทุก tenant โดยไม่ต้อง account_org
- มี permissions ทั้งหมดในทุก tenant
- เข้าถึง Platform Console features ครบถ้วน

**Status:** Production Ready ✅

