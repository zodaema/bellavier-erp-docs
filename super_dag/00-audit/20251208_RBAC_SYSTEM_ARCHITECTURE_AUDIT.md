# RBAC System Architecture Audit

> **Generated:** 2025-12-08  
> **Auditor:** AI Agent  
> **Scope:** Platform & Tenant RBAC infrastructure

---

## 📊 Executive Summary

ระบบ RBAC ของ Bellavier ERP มีโครงสร้างที่ **สมบูรณ์และแข็งแรง** แยกเป็น 2 ระดับชัดเจน:

| Level | Database | Purpose |
|-------|----------|---------|
| **Platform** | Core DB (`bgerp`) | Super Admin, Platform Console |
| **Tenant** | Tenant DB (`bgerp_t_*`) | Organization roles & permissions |

### ✅ Strengths

- โครงสร้างแยก Platform/Tenant ชัดเจน
- Owner role bypass ALL permissions
- Platform Super Admin bypass ทุก tenant
- Session caching สำหรับ performance
- Helper classes ครบถ้วน (PSR-4)
- UI พร้อมใช้ทั้ง 2 ระดับ

### ⚠️ Gaps (สำหรับ Task 27.23)

- ไม่มี **Token-level permission** (ใคร start/QC token ได้)
- ไม่มี **Assignment-aware permission** (strict assignment)
- ไม่มี **Node-level config** (QC node ให้ใครทำได้)

---

## 1️⃣ Platform Level (Core Database)

### Database Tables

```sql
-- Core DB: bgerp

platform_user
├── id_platform_user (PK)
├── id_member (FK → account)
├── status
└── is_super

platform_role
├── id_platform_role (PK)
├── code (unique)
├── name
└── description

platform_user_role
├── id_platform_user (FK)
└── id_platform_role (FK)

platform_permission
├── id_platform_permission (PK)
├── code (unique)
└── description

platform_role_permission
├── id_platform_role (FK)
├── id_platform_permission (FK)
└── allow (bool)
```

### Platform Roles (Known)

| Code | Description |
|------|-------------|
| `platform_super_admin` | Full platform access |
| `platform_owner` | Tenant owner access |

### Platform Permissions (Prefix: `platform.*`)

```
platform.accounts.manage    - Manage platform users
platform.tenants.manage     - Manage tenants
platform.migrations.run     - Run migrations (super admin only)
platform.roles.manage       - Manage platform roles
```

### UI & API

| Component | Path |
|-----------|------|
| Page | `page/platform_roles.php` |
| View | `views/platform_roles.php` |
| JS | `assets/javascripts/platform/roles.js` |
| API | `source/admin_rbac.php` (actions: `get_platform_roles`, `platform_user_*`) |

---

## 2️⃣ Tenant Level (Tenant Database)

### Database Tables

```sql
-- Tenant DB: bgerp_t_{org_code}

tenant_role
├── id_tenant_role (PK)
├── code (unique)
├── name
├── description
├── is_system (bool)
└── created_at, updated_at

tenant_user_role
├── id_member (FK → account)
├── id_tenant_role (FK)
├── assigned_at
└── assigned_by

permission
├── id_permission (PK)
├── code (unique)
└── description

tenant_role_permission
├── id_tenant_role (FK)
├── id_permission (FK)
├── allow (bool)
└── created_at
```

### Tenant Roles (Default 10 roles)

| ID | Code | Description |
|----|------|-------------|
| 1 | `owner` | **Bypasses ALL permissions** |
| 2 | `admin` | Tenant administrator |
| 3 | `viewer` | Read-only access |
| 4 | `production_manager` | Production supervisor |
| 5 | `production_operator` | Shop floor worker |
| 6 | `artisan_operator` | Craftsman |
| 7 | `quality_manager` | QC manager |
| 8 | `qc_lead` | QC lead/inspector |
| 9 | `inventory_manager` | Stock manager |
| 10 | `planner` | Production planner |

### UI & API

| Component | Path |
|-----------|------|
| Page | `page/admin_roles.php` |
| View | `views/admin_roles.php` |
| JS | `assets/javascripts/admin/roles.js` |
| API | `source/admin_rbac.php` (actions: `groups`, `perms`, `save_perms`, `tenant_role_*`) |

---

## 3️⃣ Helper Classes

### PermissionHelper (`source/BGERP/Security/PermissionHelper.php`)

**Main class for permission checking (PSR-4)**

| Method | Description | Returns |
|--------|-------------|---------|
| `permissionAllowCode($member, $code)` | Check tenant permission | `bool` |
| `tenantPermissionAllowCode($member, $code)` | Tenant-specific check | `bool\|null` |
| `platformHasPermission($code)` | Check platform permission | `bool` |
| `platformHasAny($codes)` | Check any platform permission | `bool` |
| `isPlatformAdministrator($member)` | Is platform super admin? | `bool` |
| `isTenantAdministrator($member, $org)` | Is tenant admin? | `bool` |
| `canAccessTenant($member, $org)` | Can access tenant? | `bool` |
| `getUserPermissionCodes($member)` | Get all user permissions | `array` |
| `mustAllowCode($member, $code)` | Check & exit 403 if denied | `void` |
| `mustAllowModule($member, $module, $perm)` | Module-based check | `void` |
| `getAdminContext($member)` | Get admin type (platform/tenant) | `array` |
| `getPlatformContext($force)` | Get platform roles/permissions | `array` |

### RbacHelper (`source/BGERP/Rbac/RbacHelper.php`)

**Utility functions**

| Method | Description |
|--------|-------------|
| `isPlatformPermission($code)` | Check if code starts with `platform.*`, `serial.*`, `migration.*` |
| `isOwnerRole($code)` | Check if role code is 'owner' |
| `isOwnerRoleById($roleId, $db)` | Check if role ID is owner |

### permission.php (`source/permission.php`)

**Backward compatibility wrapper**

Wraps all legacy function calls to `PermissionHelper`:

```php
permission_allow_code()      → PermissionHelper::permissionAllowCode()
must_allow_code()            → PermissionHelper::mustAllowCode()
platform_has_permission()    → PermissionHelper::platformHasPermission()
is_platform_administrator()  → PermissionHelper::isPlatformAdministrator()
// ... etc
```

---

## 4️⃣ Admin RBAC API (`source/admin_rbac.php`)

### Actions

| Action | Method | Permission | Description |
|--------|--------|------------|-------------|
| `list` | GET | admin | List platform OR tenant users |
| `users` | GET | admin | List all users |
| `groups` | GET | admin | List tenant roles |
| `user_create` | POST | admin | Create tenant user |
| `user_get` | GET | admin | Get tenant user details |
| `user_update` | POST | admin | Update tenant user |
| `perms` | GET | admin | Get permissions for role |
| `save_perms` | POST | admin | Save role permissions |
| `get_platform_roles` | GET | platform | List platform roles |
| `platform_user_create` | POST | platform | Create platform user |
| `platform_user_get` | GET | platform | Get platform user |
| `platform_user_update` | POST | platform | Update platform user |
| `tenant_role_create` | POST | admin | Create tenant role |
| `tenant_role_update` | POST | admin | Update tenant role |
| `tenant_role_delete` | POST | admin | Delete tenant role |

### Permission Check

```php
function must_allow_admin($member) {
    // Allow if:
    // 1. Platform Super Admin
    // 2. Tenant Owner/Admin
    // 3. Has specific admin permissions:
    //    - org.user.manage
    //    - org.role.assign
    //    - org.settings.manage
    //    - admin.user.manage
    //    - admin.role.manage
    //    - admin.settings.manage
}
```

---

## 5️⃣ Permission Check Flow

```
┌─────────────────────────────────────────────────────────────┐
│                  permission_allow_code()                     │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│           PermissionHelper::permissionAllowCode()            │
│                                                              │
│   1. Check isPlatformAdministrator() → return true           │
│   2. Check account_org.id_group = 1 (owner) → return true    │
│   3. Get tenant_role from tenant_user_role                   │
│   4. If id_tenant_role = 1 (owner) → return true             │
│   5. Lookup permission.id_permission                         │
│   6. Check tenant_role_permission.allow                      │
│   7. Return allow value                                      │
└─────────────────────────────────────────────────────────────┘
```

### Bypass Rules

| Condition | Result |
|-----------|--------|
| `platform_super_admin` role | **Bypass ALL** |
| `account_org.id_group = 1` (owner in core DB) | **Bypass ALL** |
| `id_tenant_role = 1` (owner in tenant DB) | **Bypass ALL** |

---

## 6️⃣ Related Files

### Core Files

| Path | Purpose |
|------|---------|
| `source/BGERP/Security/PermissionHelper.php` | Main permission class |
| `source/BGERP/Rbac/RbacHelper.php` | RBAC utilities |
| `source/permission.php` | Backward compatibility |
| `source/admin_rbac.php` | Admin API |

### UI Files

| Path | Purpose |
|------|---------|
| `page/admin_roles.php` | Tenant roles page |
| `page/platform_roles.php` | Platform roles page |
| `views/admin_roles.php` | Tenant roles view |
| `views/platform_roles.php` | Platform roles view |
| `assets/javascripts/admin/roles.js` | Tenant roles JS |
| `assets/javascripts/platform/roles.js` | Platform roles JS |

### Seed & Migration

| Path | Purpose |
|------|---------|
| `database/seed_default_permissions.php` | Default permission definitions |
| `database/tenant_migrations/0002_seed_data.php` | Seed roles & permissions |

---

## 7️⃣ Integration with Task 27.23

### สิ่งที่มีอยู่แล้ว (ใช้ได้เลย)

| Feature | Location |
|---------|----------|
| Role-based permission check | `PermissionHelper::permissionAllowCode()` |
| Owner bypass | Built-in |
| Platform admin bypass | Built-in |
| Permission CRUD | `admin_rbac.php` |
| UI management | `page/admin_roles.php` |

### สิ่งที่ต้องเพิ่มใหม่ (Task 27.23)

| Feature | Purpose |
|---------|---------|
| **Token-level permission** | ใคร start/pause/QC token ได้ |
| **Assignment method check** | strict, auto, pin, help |
| **Node config check** | QC node ให้ใครทำได้ |
| **Token type rules** | replacement, rework, split |

### Recommended Approach

```php
// PermissionEngine ใช้ PermissionHelper เป็น base
class PermissionEngine {
    private PermissionHelper $permHelper;
    
    public function can($action, $context): bool {
        // Layer 1: Role permission (ใช้ระบบเดิม)
        $roleCheck = PermissionHelper::permissionAllowCode(
            $this->member, 
            $this->mapActionToPermission($action)
        );
        
        // Owner bypass ทุก layer
        if ($this->isOwner()) return true;
        
        // Layer 2: Assignment check (NEW)
        if (!$this->checkAssignment($action, $context)) {
            return false;
        }
        
        // Layer 3: Node config check (NEW)
        if (!$this->checkNodeConfig($action, $context)) {
            return false;
        }
        
        // Layer 4: Token type rules (NEW)
        if (!$this->checkTokenType($action, $context)) {
            return false;
        }
        
        return $roleCheck;
    }
}
```

---

## 8️⃣ Recommendations

### ✅ DO

1. **ใช้ PermissionHelper เป็น base** - ไม่ต้องเขียน role check ใหม่
2. **Respect owner bypass** - Owner ผ่านทุก layer
3. **เพิ่ม layer ใหม่แบบ additive** - ไม่แทนที่ระบบเดิม
4. **Cache ที่ request level** - เหมือน `$_SESSION['platform_context']`

### ❌ DON'T

1. ❌ สร้างระบบ permission ใหม่ทั้งหมด
2. ❌ Bypass PermissionHelper
3. ❌ แก้ไข owner bypass logic
4. ❌ Query permission ซ้ำหลายครั้งต่อ request

---

## 🔗 Related Documents

- [Permission System Audit](./20251208_PERMISSION_SYSTEM_AUDIT.md)
- [Roles & Permissions Database Audit](./20251208_ROLES_PERMISSIONS_DATABASE_AUDIT.md)
- [Task 27.23: Permission Engine Refactor](../tasks/task27.23_PERMISSION_ENGINE_REFACTOR.md)

