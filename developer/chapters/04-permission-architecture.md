# Chapter 4 — Permission Architecture

**Last Updated:** November 19, 2025  
**Purpose:** Explain how permission and RBAC (Role-Based Access Control) works in the system  
**Audience:** Developers working on API endpoints, AI agents modifying permission logic

---

## Overview

The permission system in Bellavier Group ERP provides fine-grained access control for both platform-level and tenant-level operations. It ensures that users can only access resources and perform actions they are authorized for.

**Key Components:**
- `PermissionHelper` - PSR-4 permission checking class (Task 19)
- Permission model (platform vs tenant permissions)
- Role mapping (platform roles, tenant roles)
- Permission inheritance and hierarchy

**Migration Status:**
- ✅ Migrated to PSR-4 (`BGERP\Security\PermissionHelper`) in Task 19
- ✅ Thin wrapper preserved (`permission.php`) for backward compatibility
- ✅ Used in 62+ API files

---

## Key Concepts

### 1. Permission Model

**Two-Level Permission System:**

1. **Platform Permissions**
   - System-wide permissions
   - Managed in core database (`bgerp.permission`)
   - Examples: `platform.admin`, `platform.health`, `platform.roles`

2. **Tenant Permissions**
   - Organization-specific permissions
   - Managed per tenant
   - Examples: `products.list`, `materials.create`, `wip.update`

**Permission Structure:**
```
Permission Code Format: {module}.{resource}.{action}
Examples:
- platform.admin (platform admin access)
- products.list (list products)
- materials.create (create materials)
- wip.update (update WIP)
```

### 2. Role Mapping

**Platform Roles:**
- **Platform Super Admin**: Full system access
- **Platform Admin**: Limited platform access
- **Platform User**: Basic platform access

**Tenant Roles:**
- **Tenant Admin**: Full tenant access
- **Tenant Manager**: Management access
- **Tenant Operator**: Basic operator access

**Role-Permission Mapping:**
- Roles are mapped to permissions
- Users inherit permissions through roles
- Direct permission assignment also supported

### 3. Permission Checking Flow

```
User Request
    ↓
Bootstrap (Authentication)
    ↓
Permission Check
    ├── Platform Permission Check
    │   ├── Check user's platform role
    │   ├── Check direct platform permissions
    │   └── Return: allowed/denied
    │
    └── Tenant Permission Check
        ├── Check user's tenant role
        ├── Check direct tenant permissions
        └── Return: allowed/denied
    ↓
API Logic (if allowed)
```

---

## Core Components

### PermissionHelper

**Location:** `source/BGERP/Security/PermissionHelper.php`  
**Namespace:** `BGERP\Security`  
**Status:** ✅ Migrated to PSR-4 (Task 19)

**Purpose:**
Centralized permission checking and platform context management.

**Key Methods:**

#### 1. Platform Administrator Check

```php
PermissionHelper::isPlatformAdministrator(array $member): bool
```

**Purpose:** Check if user is platform super administrator.

**Usage:**
```php
use BGERP\Security\PermissionHelper;

if (!PermissionHelper::isPlatformAdministrator($member)) {
    json_error('unauthorized', 403);
}
```

**Returns:**
- `true`: User is platform super administrator
- `false`: User is not platform super administrator

#### 2. Platform Permission Check

```php
PermissionHelper::platform_has_permission(array $member, string $permission): bool
```

**Purpose:** Check if user has specific platform permission.

**Usage:**
```php
use BGERP\Security\PermissionHelper;

if (!PermissionHelper::platform_has_permission($member, 'platform.health')) {
    json_error('forbidden', 403);
}
```

**Returns:**
- `true`: User has permission
- `false`: User does not have permission

#### 3. Organization Permission Check

```php
PermissionHelper::hasOrgPermission(array $member, string $permission): bool
```

**Purpose:** Check if user has specific organization/tenant permission.

**Usage:**
```php
use BGERP\Security\PermissionHelper;

if (!PermissionHelper::hasOrgPermission($member, 'products.list')) {
    json_error('forbidden', 403);
}
```

**Returns:**
- `true`: User has permission
- `false`: User does not have permission

#### 4. Get Platform Context

```php
PermissionHelper::getPlatformContext(array $member): ?array
```

**Purpose:** Get platform context for user (platform roles, permissions).

**Usage:**
```php
use BGERP\Security\PermissionHelper;

$context = PermissionHelper::getPlatformContext($member);
if ($context && $context['is_platform_admin']) {
    // User is platform admin
}
```

**Returns:**
- `array`: Platform context (roles, permissions, is_platform_admin)
- `null`: No platform context

#### 5. Permission Allow Code (Legacy)

```php
PermissionHelper::permission_allow_code(array $member, string $code): bool
```

**Purpose:** Legacy permission check (backward compatibility).

**Usage:**
```php
use BGERP\Security\PermissionHelper;

if (!PermissionHelper::permission_allow_code($member, 'products.list')) {
    json_error('forbidden', 403);
}
```

**Returns:**
- `true`: Permission allowed
- `false`: Permission denied

### Legacy Wrapper Functions

**Location:** `source/permission.php`  
**Status:** ✅ Thin wrapper (Task 19)

**Purpose:**
Backward compatibility for legacy code that uses function-style permission checks.

**Functions:**
- `is_platform_administrator($member)` → `PermissionHelper::isPlatformAdministrator()`
- `platform_has_permission($member, $permission)` → `PermissionHelper::platform_has_permission()`
- `has_org_permission($member, $permission)` → `PermissionHelper::hasOrgPermission()`
- `get_platform_context($member)` → `PermissionHelper::getPlatformContext()`
- `permission_allow_code($member, $code)` → `PermissionHelper::permission_allow_code()`

**Usage:**
```php
// Old way (still works)
require_once __DIR__ . '/permission.php';
if (is_platform_administrator($member)) { ... }

// New way (recommended)
use BGERP\Security\PermissionHelper;
if (PermissionHelper::isPlatformAdministrator($member)) { ... }
```

---

## APIs Requiring Permissions

### Platform APIs

**Require Platform Admin:**
- `platform_dashboard_api.php` - Platform dashboard
- `platform_health_api.php` - Health check
- `platform_roles_api.php` - Role management
- `platform_serial_salt_api.php` - Serial salt management
- `admin_org.php` - Organization management
- `admin_rbac.php` - RBAC management

**Require Platform Permission:**
- `platform_migration_api.php` - Migration operations (requires `platform.migration`)

### Tenant APIs

**Require Tenant Permissions:**
- `products.php` - Product management (requires `products.*`)
- `materials.php` - Material management (requires `materials.*`)
- `bom.php` - BOM management (requires `bom.*`)
- `dag_token_api.php` - Token operations (requires `dag.token.*`)
- `trace_api.php` - Trace operations (requires `trace.*`)
- `qc_rework.php` - QC/Rework operations (requires `qc.*`)

**Permission Pattern:**
```
{module}.{resource}.{action}
Examples:
- products.list
- products.create
- products.update
- products.delete
```

---

## How to Add New Permissions Safely

### Step 1: Define Permission Code

**Format:** `{module}.{resource}.{action}`

**Examples:**
- `reports.generate` - Generate reports
- `analytics.view` - View analytics
- `settings.update` - Update settings

### Step 2: Add Permission to Database

**Core Database (Platform Permissions):**
```sql
INSERT INTO permission (code, name, description, module) 
VALUES ('platform.reports', 'Platform Reports', 'Access platform reports', 'platform');
```

**Tenant Database (Tenant Permissions):**
```sql
INSERT INTO permission (code, name, description, module) 
VALUES ('reports.generate', 'Generate Reports', 'Generate tenant reports', 'reports');
```

### Step 3: Assign Permission to Roles

**Platform Role:**
```sql
INSERT INTO platform_role_permission (role_id, permission_id) 
VALUES (?, ?);
```

**Tenant Role:**
```sql
INSERT INTO tenant_role_permission (role_id, permission_id, org_id) 
VALUES (?, ?, ?);
```

### Step 4: Use Permission in API

```php
use BGERP\Security\PermissionHelper;

// Check permission before operation
if (!PermissionHelper::platform_has_permission($member, 'reports.generate')) {
    json_error('forbidden', 403);
}

// Proceed with operation
```

### Step 5: Update Documentation

- Update permission documentation
- Update API documentation
- Update role documentation

---

## Forbidden Practices

### ❌ DO NOT

1. **Skip Permission Checks**
   ```php
   // ❌ Wrong: No permission check
   // Proceed directly with operation
   ```

2. **Hardcode Permission Checks**
   ```php
   // ❌ Wrong: Hardcoded check
   if ($member['id_member'] == 1) { ... }
   ```

3. **Bypass Permission System**
   ```php
   // ❌ Wrong: Direct database access without check
   $stmt = $db->prepare("SELECT * FROM sensitive_table");
   ```

4. **Change Permission Logic Without Task Approval**
   ```php
   // ❌ Wrong: Modifying PermissionHelper logic
   // Task 19 forbids changing permission logic
   ```

5. **Remove Thin Wrapper Functions**
   ```php
   // ❌ Wrong: Removing permission.php wrapper
   // Task 19 requires thin wrappers for backward compatibility
   ```

### ✅ DO

1. **Always Check Permissions**
   ```php
   // ✅ Correct: Check permission first
   if (!PermissionHelper::platform_has_permission($member, 'reports.generate')) {
       json_error('forbidden', 403);
   }
   ```

2. **Use PermissionHelper Methods**
   ```php
   // ✅ Correct: Use helper methods
   use BGERP\Security\PermissionHelper;
   PermissionHelper::isPlatformAdministrator($member);
   ```

3. **Follow Permission Code Format**
   ```php
   // ✅ Correct: Use standard format
   PermissionHelper::platform_has_permission($member, 'module.resource.action');
   ```

4. **Document New Permissions**
   ```php
   // ✅ Correct: Document permission usage
   // Requires permission: reports.generate
   ```

---

## Permission Testing Guide

### Unit Tests

**Test Permission Checks:**
```php
use BGERP\Security\PermissionHelper;

public function testPlatformAdminCheck(): void
{
    $adminMember = ['id_member' => 1, 'platform_role' => 'super_admin'];
    $this->assertTrue(PermissionHelper::isPlatformAdministrator($adminMember));
    
    $regularMember = ['id_member' => 2, 'platform_role' => 'user'];
    $this->assertFalse(PermissionHelper::isPlatformAdministrator($regularMember));
}
```

### Integration Tests

**Test Permission Enforcement:**
```php
// In API integration test
public function testApiRequiresPermission(): void
{
    // Test without permission
    $result = $this->runTenantApi('products.php', ['action' => 'list'], [], $nonAdminSession);
    $response = $this->assertJsonResponse($result, 403);
    $this->assertFalse($response['ok']);
    
    // Test with permission
    $result = $this->runTenantApi('products.php', ['action' => 'list'], [], $adminSession);
    $response = $this->assertJsonResponse($result, 200);
    $this->assertTrue($response['ok']);
}
```

### System-Wide Tests

**Permission Matrix Tests:**
- `tests/Integration/SystemWide/EndpointPermissionMatrixSystemWideTest.php`
- Tests permission enforcement across all endpoints
- Validates role-permission mappings

---

## Examples

### Example 1: Platform API with Permission Check

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$member, $coreDb] = \BGERP\Bootstrap\CoreApiBootstrap::init([
    'requirePlatformAdmin' => true
]);

// Additional permission check
use BGERP\Security\PermissionHelper;
if (!PermissionHelper::platform_has_permission($member, 'platform.reports')) {
    json_error('forbidden', 403);
}

// Proceed with operation
```

### Example 2: Tenant API with Permission Check

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Permission check
use BGERP\Security\PermissionHelper;
if (!PermissionHelper::hasOrgPermission($member, 'products.create')) {
    json_error('forbidden', 403);
}

// Proceed with operation
```

### Example 3: Multiple Permission Checks

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Check multiple permissions
use BGERP\Security\PermissionHelper;

$action = $_REQUEST['action'] ?? '';

switch ($action) {
    case 'list':
        if (!PermissionHelper::hasOrgPermission($member, 'products.list')) {
            json_error('forbidden', 403);
        }
        break;
        
    case 'create':
        if (!PermissionHelper::hasOrgPermission($member, 'products.create')) {
            json_error('forbidden', 403);
        }
        break;
        
    case 'delete':
        // Delete requires both list and delete permissions
        if (!PermissionHelper::hasOrgPermission($member, 'products.list') ||
            !PermissionHelper::hasOrgPermission($member, 'products.delete')) {
            json_error('forbidden', 403);
        }
        break;
}
```

---

## Reference Documents

### Permission Documentation

- **PermissionHelper**: `source/BGERP/Security/PermissionHelper.php` - Source code
- **Legacy Wrapper**: `source/permission.php` - Thin wrapper functions
- **Task 19**: `docs/bootstrap/Task/task19.md` - PSR-4 migration details

### Security Documentation

- **Security Notes**: `docs/security/task18_security_notes.md` - Security audit
- **Chapter 11**: `docs/developer/chapters/11-security-handbook.md` - Security handbook

### Test Examples

- **Permission Tests**: `tests/Integration/SystemWide/EndpointPermissionMatrixSystemWideTest.php`
- **Auth Tests**: `tests/Integration/SystemWide/AuthGlobalCasesSystemWideTest.php`

---

## Future Expansion

### Planned Enhancements

1. **Permission Inheritance**
   - Hierarchical permission structure
   - Permission groups
   - Wildcard permissions

2. **Dynamic Permissions**
   - Runtime permission assignment
   - Context-based permissions
   - Time-based permissions

3. **Permission Caching**
   - Cache permission checks
   - Reduce database queries
   - Performance optimization

4. **Permission Audit Trail**
   - Track permission changes
   - Audit permission usage
   - Compliance reporting

---

**Previous Chapter:** [Chapter 3 — Bootstrap System](../chapters/03-bootstrap-system.md)  
**Next Chapter:** [Chapter 5 — Database Architecture](../chapters/05-database-architecture.md)

