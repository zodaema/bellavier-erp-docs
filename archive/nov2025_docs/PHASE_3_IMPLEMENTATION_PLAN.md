# Phase 3: Dual-Mode Authentication Implementation Plan

**Start Date:** November 3, 2025  
**Status:** 🔄 In Progress  
**Goal:** Enable authentication for both Platform Owners (Core DB) and Tenant Users (Tenant DB)

---

## 📋 Overview

**Current State:**
- All logins query `bgerp.account` table (Core DB)
- `source/model/member_class.php` (`memberDetail` class) handles authentication
- Session: `$_SESSION['member']` with `id_member` from Core DB

**Target State:**
- **Platform Owners:** Login via Core DB `bgerp.account` (no change)
- **Tenant Users:** Login via Tenant DB `tenant_user` (new flow)
- Session differentiation: `$_SESSION['platform_user']` vs `$_SESSION['tenant_user']`
- Dual-mode login flow: Try Tenant DB first, fallback to Core DB

---

## 🎯 Objectives

1. ✅ Create `TenantMemberLogin` class for tenant user authentication
2. ✅ Refactor `memberLogin` class to become platform-specific
3. ✅ Modify `source/member_login.php` to implement dual-mode logic
4. ✅ Update session handling for `$_SESSION['platform_user']` and `$_SESSION['tenant_user']`
5. ✅ Test login for both Platform Admins and Tenant Users
6. ✅ Ensure backward compatibility with existing code

---

## 🏗️ Architecture Design

### **Login Flow (Dual-Mode):**

```
User submits login (username + password)
    ↓
1. Resolve organization context
   - Check subdomain (e.g., maison-atelier.bellavier.local)
   - Check `$_SESSION['platform_context']['org']`
   - Check `platform_user.id_org` if platform user is logged in
    ↓
2. If organization context exists:
   → Try TenantMemberLogin->authenticate() (Tenant DB)
   → If successful: Set $_SESSION['tenant_user'] ✅
   → If fails: Continue to step 3
    ↓
3. If no org context OR tenant login failed:
   → Try PlatformMemberLogin->authenticate() (Core DB)
   → If successful: Set $_SESSION['platform_user'] ✅
   → If fails: Return "Invalid credentials" ❌
    ↓
4. Redirect to appropriate dashboard
   - Platform Admin → platform_dashboard
   - Tenant User → dashboard (tenant-specific)
```

### **Session Structure:**

**For Platform Users:**
```php
$_SESSION['platform_user'] = [
    'id_member' => 1,
    'username' => 'admin@bellavier.com',
    'name' => 'Platform Administrator',
    'email' => 'admin@bellavier.com',
    'is_platform_admin' => true,
    'login_at' => '2025-11-03 14:00:00'
];
```

**For Tenant Users:**
```php
$_SESSION['tenant_user'] = [
    'id_tenant_user' => 5,
    'username' => 'operator1',
    'name' => 'John Operator',
    'email' => 'operator1@atelier.com',
    'id_tenant_role' => 3,
    'role_code' => 'production.operator',
    'org_code' => 'maison_atelier',
    'login_at' => '2025-11-03 14:00:00'
];
```

**Backward Compatibility:**
```php
// For existing code that expects $_SESSION['member']
$_SESSION['member'] = $_SESSION['tenant_user'] ?? $_SESSION['platform_user'] ?? null;
```

---

## 📂 Files to Create/Modify

### **1. Create: `source/model/tenant_member_class.php`** (NEW)

```php
<?php
/**
 * Tenant Member Authentication Class
 * Handles login for users in tenant_user table
 */

class TenantMemberDetail
{
    private $db; // Tenant DB connection
    private $orgCode;
    
    public function __construct($orgCode)
    {
        $this->orgCode = $orgCode;
        $this->db = tenant_db($orgCode);
    }
    
    /**
     * Authenticate tenant user
     * @param string $username
     * @param string $password
     * @return array|false User data or false
     */
    public function authenticate($username, $password)
    {
        $stmt = $this->db->prepare("
            SELECT 
                tu.id_tenant_user,
                tu.username,
                tu.email,
                tu.name,
                tu.id_tenant_role,
                tu.status,
                tu.last_login_at,
                tr.code as role_code,
                tr.name as role_name
            FROM tenant_user tu
            JOIN tenant_role tr ON tr.id_tenant_role = tu.id_tenant_role
            WHERE tu.username = ?
              AND tu.status = 1
              AND tu.deleted_at IS NULL
            LIMIT 1
        ");
        
        if (!$stmt) {
            error_log("Tenant auth prepare failed: " . $this->db->error);
            return false;
        }
        
        $stmt->bind_param('s', $username);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows === 0) {
            $stmt->close();
            return false; // User not found
        }
        
        $user = $result->fetch_assoc();
        $stmt->close();
        
        // Verify password
        require_once __DIR__ . '/../secure/PasswordHash.php';
        if (!validate_password($password, $user['password'])) {
            return false; // Wrong password
        }
        
        // Update last login
        $this->updateLastLogin($user['id_tenant_user']);
        
        // Return user data (without password)
        unset($user['password']);
        $user['org_code'] = $this->orgCode;
        
        return $user;
    }
    
    /**
     * Update last login timestamp
     */
    private function updateLastLogin($idTenantUser)
    {
        $stmt = $this->db->prepare("
            UPDATE tenant_user 
            SET last_login_at = NOW() 
            WHERE id_tenant_user = ?
        ");
        if ($stmt) {
            $stmt->bind_param('i', $idTenantUser);
            $stmt->execute();
            $stmt->close();
        }
    }
    
    /**
     * Get current logged-in tenant user from session
     * @return array|null
     */
    public function thisLogin()
    {
        return $_SESSION['tenant_user'] ?? null;
    }
    
    /**
     * Check if tenant user has permission
     * @param string $permissionCode
     * @return bool
     */
    public function hasPermission($permissionCode)
    {
        $user = $this->thisLogin();
        if (!$user) {
            return false;
        }
        
        // Use existing tenant_permission_allow_code function
        return tenant_permission_allow_code($this->db, $user['id_tenant_role'], $permissionCode);
    }
    
    /**
     * Logout tenant user
     */
    public function logout()
    {
        unset($_SESSION['tenant_user']);
        unset($_SESSION['member']); // Clear backward compat session
    }
}
```

### **2. Modify: `source/member_login.php`** (CORE LOGIC)

```php
<?php
/**
 * Dual-Mode Login Handler
 * Supports both Platform (Core DB) and Tenant (Tenant DB) authentication
 */

session_start();
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/model/member_class.php'; // Platform login
require_once __DIR__ . '/model/tenant_member_class.php'; // Tenant login (NEW)
require_once __DIR__ . '/global_function.php';

// Get login credentials
$username = $_POST['username'] ?? '';
$password = $_POST['password'] ?? '';

if (empty($username) || empty($password)) {
    // Redirect back with error
    header('Location: /?p=login&error=missing_fields');
    exit;
}

// Step 1: Resolve organization context
$orgCode = null;

// Try to get org from subdomain
if (isset($_SERVER['HTTP_HOST'])) {
    $host = $_SERVER['HTTP_HOST'];
    if (preg_match('/^([a-z0-9_]+)\.bellavier/', $host, $matches)) {
        $orgCode = $matches[1];
    }
}

// Try to get org from session (if platform user previously selected)
if (!$orgCode && isset($_SESSION['platform_context']['org']['code'])) {
    $orgCode = $_SESSION['platform_context']['org']['code'];
}

// Step 2: Try Tenant Login (if org context exists)
if ($orgCode) {
    $tenantLogin = new TenantMemberDetail($orgCode);
    $tenantUser = $tenantLogin->authenticate($username, $password);
    
    if ($tenantUser) {
        // SUCCESS: Tenant user authenticated
        $_SESSION['tenant_user'] = $tenantUser;
        $_SESSION['member'] = $tenantUser; // Backward compatibility
        
        error_log("Tenant user logged in: {$username} (org: {$orgCode})");
        
        // Redirect to tenant dashboard
        header('Location: /?p=dashboard');
        exit;
    }
    
    // Tenant login failed, continue to platform login attempt
    error_log("Tenant login failed for: {$username} (org: {$orgCode}), trying platform login");
}

// Step 3: Try Platform Login (Core DB)
$platformLogin = new memberDetail();
$platformUser = $platformLogin->thisLogin(); // Try existing session first

if (!$platformUser) {
    // No existing session, try to authenticate
    // Note: memberDetail class needs refactoring to support authenticate() method
    // For now, use existing login() method
    
    $coreDb = core_db();
    $stmt = $coreDb->prepare("
        SELECT 
            id_member,
            username,
            email,
            password,
            name,
            id_group
        FROM account
        WHERE username = ?
          AND status = 1
        LIMIT 1
    ");
    
    if (!$stmt) {
        error_log("Platform auth prepare failed: " . $coreDb->error);
        header('Location: /?p=login&error=system_error');
        exit;
    }
    
    $stmt->bind_param('s', $username);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        $stmt->close();
        // User not found in either tenant or platform DB
        header('Location: /?p=login&error=invalid_credentials');
        exit;
    }
    
    $user = $result->fetch_assoc();
    $stmt->close();
    
    // Verify password
    require_once __DIR__ . '/secure/PasswordHash.php';
    if (!validate_password($password, $user['password'])) {
        // Wrong password
        header('Location: /?p=login&error=invalid_credentials');
        exit;
    }
    
    // SUCCESS: Platform user authenticated
    unset($user['password']); // Remove password from session
    
    $_SESSION['platform_user'] = $user;
    $_SESSION['member'] = $user; // Backward compatibility
    $_SESSION['platform_user']['is_platform_admin'] = true;
    
    // Update last login
    $stmt = $coreDb->prepare("UPDATE account SET last_login_at = NOW() WHERE id_member = ?");
    if ($stmt) {
        $stmt->bind_param('i', $user['id_member']);
        $stmt->execute();
        $stmt->close();
    }
    
    error_log("Platform user logged in: {$username}");
    
    // Redirect to platform dashboard
    header('Location: /?p=platform_dashboard');
    exit;
}

// If we reach here, something went wrong
error_log("Login failed for: {$username} (unexpected state)");
header('Location: /?p=login&error=system_error');
exit;
```

---

## 🧪 Testing Plan

### **Test 1: Tenant User Login**
```
Username: operator1 (from tenant_user table)
Password: [set during user creation]
Expected:
- $_SESSION['tenant_user'] set ✅
- $_SESSION['member'] = $_SESSION['tenant_user'] ✅
- Redirect to /?p=dashboard ✅
- Log: "Tenant user logged in: operator1 (org: maison_atelier)"
```

### **Test 2: Platform Admin Login**
```
Username: admin (from bgerp.account table)
Password: [existing admin password]
Expected:
- $_SESSION['platform_user'] set ✅
- $_SESSION['member'] = $_SESSION['platform_user'] ✅
- Redirect to /?p=platform_dashboard ✅
- Log: "Platform user logged in: admin"
```

### **Test 3: Invalid Credentials**
```
Username: nonexistent
Password: wrong
Expected:
- Redirect to /?p=login&error=invalid_credentials ✅
- No session set ✅
```

### **Test 4: Tenant Login Fallback**
```
Username: admin (exists in Core DB, not in Tenant DB)
Org Context: maison_atelier
Expected:
- Try tenant login first → fails
- Fallback to platform login → succeeds ✅
- $_SESSION['platform_user'] set ✅
```

---

## 🔄 Rollback Plan

If Phase 3 causes issues:

1. **Immediate Revert:**
   ```bash
   # Restore member_login.php from backup
   cp backup/member_login.php source/member_login.php
   
   # Remove TenantMemberDetail class
   rm source/model/tenant_member_class.php
   ```

2. **Database State:**
   - No database changes in Phase 3
   - tenant_user tables remain intact
   - Can continue using Core DB login

3. **Session Handling:**
   - Revert to `$_SESSION['member']` only
   - Remove `$_SESSION['tenant_user']` and `$_SESSION['platform_user']`

---

## 📊 Progress Tracking

- [ ] Create `tenant_member_class.php`
- [ ] Modify `member_login.php` for dual-mode
- [ ] Update `permission.php` to check both session types
- [ ] Test tenant user login
- [ ] Test platform admin login
- [ ] Test invalid credentials
- [ ] Test fallback logic
- [ ] Verify backward compatibility
- [ ] Update documentation

---

**Next:** Proceed with implementation!

