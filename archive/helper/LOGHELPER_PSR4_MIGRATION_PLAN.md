# LogHelper PSR-4 Migration Plan

**Created:** November 14, 2025  
**Status:** 📋 Planning Phase  
**Priority:** Medium (Backward Compatibility Required)

---

## 📋 Overview

**Goal:** Migrate `LogHelper` from legacy `source/helper/LogHelper.php` to PSR-4 compliant `source/BGERP/Helper/LogHelper.php` while maintaining **100% backward compatibility** for existing code.

**Current State:**
- Location: `source/helper/LogHelper.php`
- Namespace: None (legacy class)
- Usage: 6+ files using `require_once` + `new LogHelper($db)`

**Target State:**
- Location: `source/BGERP/Helper/LogHelper.php`
- Namespace: `BGERP\Helper`
- Usage: PSR-4 autoload + `use BGERP\Helper\LogHelper;`

---

## 🎯 Migration Strategy

### **Phase 1: Create PSR-4 Version (Non-Breaking)**

**Step 1.1: Create New PSR-4 File**
- Create `source/BGERP/Helper/LogHelper.php`
- Add namespace `BGERP\Helper`
- Copy entire class code from `source/helper/LogHelper.php`
- **No changes to class implementation** (only namespace)

**Step 1.2: Update composer.json (if needed)**
- Verify `"BGERP\\": "source/BGERP/"` exists in `autoload.psr-4`
- Run `composer dump-autoload`

**Step 1.3: Test PSR-4 Autoload**
- Create test file using `use BGERP\Helper\LogHelper;`
- Verify autoload works correctly

---

### **Phase 2: Backward Compatibility Shim (Critical)**

**Step 2.1: Create Shim File**
- Keep `source/helper/LogHelper.php` as **shim/alias**
- Shim will `require_once` the PSR-4 version
- Shim will create class alias: `class LogHelper extends BGERP\Helper\LogHelper {}`

**Step 2.2: Verify Existing Code Still Works**
- Test all 6+ files that use `require_once 'helper/LogHelper.php'`
- Verify no breaking changes

**Files to Test:**
- `source/system_log.php`
- `source/dashboard.php`
- `source/member_login.php`
- `source/model/member_class.php`
- `source/notifications.php`
- (Any other files using LogHelper)

---

### **Phase 3: Gradual Migration (Optional)**

**Step 3.1: Update New Code**
- All new code should use PSR-4: `use BGERP\Helper\LogHelper;`
- Phase 7.5 code should use PSR-4 version

**Step 3.2: Update Existing Code (Gradual)**
- Update files one by one to use PSR-4
- Remove `require_once` statements
- Add `use BGERP\Helper\LogHelper;`

**Step 3.3: Deprecation Notice (Future)**
- Add `@deprecated` comment to shim file
- Plan removal after 6-12 months

---

## 📝 Implementation Details

### **New PSR-4 File Structure**

```php
<?php
/**
 * LogHelper - System Logging Utility
 * 
 * Purpose: Centralized logging to system_logs table
 * Features:
 * - Multiple log levels (INFO, SUCCESS, WARNING, ERROR, CRITICAL, DEBUG)
 * - Automatic IP address detection (Cloudflare, X-Forwarded-For, etc.)
 * - Sensitive data masking (password, api_key, token)
 * - Request context capture (method, URI, user_id)
 * 
 * @package Bellavier Group ERP
 * @namespace BGERP\Helper
 * @version 2.0
 * @since 2025-11-14
 * 
 * CRITICAL INVARIANTS:
 * - Requires mysqli connection (core_db() or tenant_db())
 * - Requires system_logs table to exist
 * - Falls back to error_log() if table missing
 */
namespace BGERP\Helper;

class LogHelper {
    // ... existing implementation ...
}
```

### **Backward Compatibility Shim**

```php
<?php
/**
 * LogHelper Shim - Backward Compatibility Layer
 * 
 * ⚠️ DEPRECATED: Use PSR-4 version instead
 * 
 * This file exists for backward compatibility only.
 * New code should use: use BGERP\Helper\LogHelper;
 * 
 * @deprecated Use BGERP\Helper\LogHelper instead
 * @see BGERP\Helper\LogHelper
 */
require_once __DIR__ . '/../BGERP/Helper/LogHelper.php';

// Create alias for backward compatibility
if (!class_exists('LogHelper', false)) {
    class LogHelper extends \BGERP\Helper\LogHelper {
        // Empty - all methods inherited from parent
    }
}
```

---

## ✅ Testing Checklist

### **Pre-Migration Tests**
- [ ] Verify all existing files using LogHelper work correctly
- [ ] Test log insertion to `system_logs` table
- [ ] Test all log levels (info, success, warning, error, critical, debug)
- [ ] Test IP address detection
- [ ] Test sensitive data masking

### **Post-Migration Tests**
- [ ] PSR-4 autoload works: `use BGERP\Helper\LogHelper;`
- [ ] Legacy require_once still works: `require_once 'helper/LogHelper.php'`
- [ ] Both methods create same class instance
- [ ] All existing files continue to work without changes
- [ ] No duplicate class definition errors

### **Integration Tests**
- [ ] Test in Phase 7.5 scrap/replacement APIs
- [ ] Test in system_log.php API
- [ ] Test in member_class.php
- [ ] Test in dashboard.php

---

## 🚨 Risk Assessment

### **Low Risk**
- ✅ Class implementation unchanged (only namespace added)
- ✅ Shim provides 100% backward compatibility
- ✅ No breaking changes to existing code

### **Medium Risk**
- ⚠️ Need to verify composer autoload works correctly
- ⚠️ Need to test all 6+ files that use LogHelper

### **Mitigation**
- Keep shim file permanently (or until all code migrated)
- Test thoroughly before removing shim
- Document migration path clearly

---

## 📚 Usage Examples

### **Legacy Usage (Still Works)**
```php
require_once __DIR__ . '/helper/LogHelper.php';
$log = new LogHelper($db);
$log->error("Something went wrong", ['context' => 'data'], __FILE__, __LINE__, $user_id);
```

### **PSR-4 Usage (New Code)**
```php
require_once __DIR__ . '/../vendor/autoload.php';
use BGERP\Helper\LogHelper;

$log = new LogHelper($db);
$log->error("Something went wrong", ['context' => 'data'], __FILE__, __LINE__, $user_id);
```

### **Phase 7.5 Usage (Recommended)**
```php
// In dag_token_api.php or token_management_api.php
require_once __DIR__ . '/../vendor/autoload.php';
use BGERP\Helper\LogHelper;

// Get database connection
$db = resolve_current_org()->getDb();

// Create LogHelper instance
$log = new LogHelper($db);

// Log scrap action
$log->info("Token scrapped", [
    'token_id' => $tokenId,
    'reason' => $reason,
    'user_id' => $userId
], __FILE__, __LINE__, $userId);

// Log replacement creation
$log->success("Replacement token created", [
    'scrapped_token_id' => $scrappedTokenId,
    'replacement_token_id' => $replacementTokenId,
    'spawn_mode' => $spawnMode
], __FILE__, __LINE__, $userId);

// Log errors
$log->error("Failed to scrap token", [
    'token_id' => $tokenId,
    'error' => $errorMessage,
    'status' => $tokenStatus
], __FILE__, __LINE__, $userId);
```

---

## 🔄 Migration Timeline

### **Week 1: Preparation**
- [ ] Create PSR-4 version
- [ ] Create shim file
- [ ] Test backward compatibility
- [ ] Update documentation

### **Week 2: Rollout**
- [ ] Deploy PSR-4 version + shim
- [ ] Monitor for errors
- [ ] Update Phase 7.5 code to use PSR-4

### **Week 3+: Gradual Migration**
- [ ] Update new code to use PSR-4
- [ ] Gradually update existing files
- [ ] Plan deprecation timeline

---

## 📖 LogHelper API Reference

### **Constructor**
```php
public function __construct(mysqli $mysqli_connection)
```

### **Methods**

#### **log() - Generic Log Method**
```php
public function log(
    string $level,           // 'INFO', 'SUCCESS', 'WARNING', 'ERROR', 'CRITICAL', 'DEBUG'
    string $message,         // Log message
    array $context = [],    // Additional context data (will be JSON encoded)
    ?string $file = null,   // Source file (usually __FILE__)
    ?int $line = null,      // Source line (usually __LINE__)
    ?int $user_id = null    // User ID (usually $_SESSION['member']['id_member'])
): bool
```

#### **Convenience Methods**
```php
public function info(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
public function success(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
public function warning(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
public function error(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
public function critical(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
public function debug(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
```

### **Helper Methods**
```php
public function getClientIpAddress(): string
// Returns client IP address (handles Cloudflare, X-Forwarded-For, etc.)
```

---

## 🎯 Phase 7.5 Integration

### **Where to Use LogHelper in Phase 7.5**

1. **Scrap Token API** (`dag_token_api.php` → `handleTokenScrap`)
   ```php
   $log->info("Token scrapped", [
       'token_id' => $tokenId,
       'reason' => $reason,
       'comment' => $comment,
       'rework_count' => $token['rework_count'],
       'rework_limit' => $token['rework_limit']
   ], __FILE__, __LINE__, $userId);
   ```

2. **Create Replacement API** (`dag_token_api.php` → `handleCreateReplacement`)
   ```php
   $log->success("Replacement token created", [
       'scrapped_token_id' => $scrappedTokenId,
       'replacement_token_id' => $replacementTokenId,
       'spawn_mode' => $spawnMode,
       'comment' => $comment
   ], __FILE__, __LINE__, $userId);
   ```

3. **Error Logging** (All APIs)
   ```php
   $log->error("Failed to scrap token", [
       'token_id' => $tokenId,
       'error' => $errorMessage,
       'status' => $tokenStatus,
       'user_id' => $userId
   ], __FILE__, __LINE__, $userId);
   ```

4. **Permission Denied**
   ```php
   $log->warning("Permission denied for scrap token", [
       'token_id' => $tokenId,
       'user_id' => $userId,
       'required_permission' => 'hatthasilpa.job.manage'
   ], __FILE__, __LINE__, $userId);
   ```

---

## ✅ Success Criteria

- [ ] PSR-4 version created and working
- [ ] Backward compatibility shim working
- [ ] All existing code continues to work
- [ ] Phase 7.5 code uses PSR-4 version
- [ ] No breaking changes
- [ ] Documentation updated
- [ ] Tests passing

---

## 📝 Notes

- **Shim file should remain** until all code is migrated (6-12 months)
- **New code must use PSR-4** version
- **Existing code can continue** using legacy require_once
- **No rush to migrate** existing code (backward compatibility maintained)

---

**Last Updated:** November 14, 2025  
**Next Review:** After Phase 7.5 Backend Integration Complete

