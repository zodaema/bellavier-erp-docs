# LogHelper Usage Guide

**Purpose:** Guide for using LogHelper in Phase 7.5 and future development

---

## 🎯 Quick Start

### **PSR-4 Usage (Recommended for New Code)**

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';
use BGERP\Helper\LogHelper;

// Get database connection
$db = resolve_current_org()->getDb(); // or core_db() for platform-level

// Create LogHelper instance
$log = new LogHelper($db);

// Log an event
$log->info("Token scrapped", [
    'token_id' => 12345,
    'reason' => 'material_defect'
], __FILE__, __LINE__, $userId);
```

### **Legacy Usage (Still Works)**

```php
<?php
require_once __DIR__ . '/helper/LogHelper.php';

$log = new LogHelper($db);
$log->info("Token scrapped", ['token_id' => 12345], __FILE__, __LINE__, $userId);
```

---

## 📋 Log Levels

### **INFO** - General Information
```php
$log->info("Token status changed", [
    'token_id' => $tokenId,
    'old_status' => 'active',
    'new_status' => 'waiting'
], __FILE__, __LINE__, $userId);
```

### **SUCCESS** - Successful Operations
```php
$log->success("Replacement token created", [
    'scrapped_token_id' => $scrappedTokenId,
    'replacement_token_id' => $replacementTokenId
], __FILE__, __LINE__, $userId);
```

### **WARNING** - Recoverable Issues
```php
$log->warning("Permission denied", [
    'user_id' => $userId,
    'required_permission' => 'hatthasilpa.job.manage',
    'action' => 'scrap_token'
], __FILE__, __LINE__, $userId);
```

### **ERROR** - Errors That Need Attention
```php
$log->error("Failed to scrap token", [
    'token_id' => $tokenId,
    'error' => $errorMessage,
    'status' => $tokenStatus
], __FILE__, __LINE__, $userId);
```

### **CRITICAL** - Critical System Failures
```php
$log->critical("Database connection failed", [
    'db_error' => $db->error,
    'connection_string' => '***masked***'
], __FILE__, __LINE__, $userId);
```

### **DEBUG** - Debugging Information
```php
$log->debug("Token validation check", [
    'token_id' => $tokenId,
    'validation_result' => $isValid,
    'checks_performed' => ['status', 'permission', 'idempotency']
], __FILE__, __LINE__, $userId);
```

---

## 🎯 Phase 7.5 Usage Examples

### **Scrap Token**

```php
// In dag_token_api.php → handleTokenScrap()
try {
    // ... scrap logic ...
    
    $log->info("Token scrapped successfully", [
        'token_id' => $tokenId,
        'reason' => $reason,
        'comment' => $comment,
        'rework_count' => $token['rework_count'] ?? null,
        'rework_limit' => $token['rework_limit'] ?? null,
        'scrapped_at' => date('Y-m-d H:i:s')
    ], __FILE__, __LINE__, $userId);
    
} catch (Exception $e) {
    $log->error("Failed to scrap token", [
        'token_id' => $tokenId,
        'error' => $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ], __FILE__, __LINE__, $userId);
    throw $e;
}
```

### **Create Replacement**

```php
// In dag_token_api.php → handleCreateReplacement()
try {
    // ... create replacement logic ...
    
    $log->success("Replacement token created", [
        'scrapped_token_id' => $scrappedTokenId,
        'replacement_token_id' => $replacementTokenId,
        'spawn_mode' => $spawnMode,
        'comment' => $comment,
        'serial_number' => $replacementToken['serial_number']
    ], __FILE__, __LINE__, $userId);
    
} catch (Exception $e) {
    $log->error("Failed to create replacement token", [
        'scrapped_token_id' => $scrappedTokenId,
        'spawn_mode' => $spawnMode,
        'error' => $e->getMessage()
    ], __FILE__, __LINE__, $userId);
    throw $e;
}
```

### **Permission Denied**

```php
// In any API endpoint
if (!permission_allow_code($member, 'hatthasilpa.job.manage')) {
    $log->warning("Permission denied for scrap token", [
        'user_id' => $userId,
        'required_permission' => 'hatthasilpa.job.manage',
        'action' => 'scrap',
        'token_id' => $tokenId
    ], __FILE__, __LINE__, $userId);
    
    json_error('Permission Denied', 403);
}
```

### **Validation Error**

```php
// In validation checks
if ($token['status'] !== 'scrapped') {
    $log->warning("Invalid token status for replacement", [
        'token_id' => $tokenId,
        'current_status' => $token['status'],
        'required_status' => 'scrapped',
        'action' => 'create_replacement'
    ], __FILE__, __LINE__, $userId);
    
    json_error('Token is not scrapped', 400);
}
```

---

## 🔒 Security Features

### **Automatic Sensitive Data Masking**

LogHelper automatically masks sensitive fields in context:

```php
$log->info("User login", [
    'username' => 'john',
    'password' => 'secret123',  // Will be masked as '********'
    'api_key' => 'abc123',      // Will be masked as '********'
    'token' => 'xyz789'         // Will be masked as '********'
], __FILE__, __LINE__, $userId);
```

**Masked Fields:**
- `password`
- `new_password`
- `api_key`
- `token`

---

## 📊 Context Data Best Practices

### **Good Context Examples**

```php
// Include relevant IDs
$log->info("Token moved", [
    'token_id' => $tokenId,
    'from_node_id' => $fromNodeId,
    'to_node_id' => $toNodeId,
    'job_ticket_id' => $jobTicketId
], __FILE__, __LINE__, $userId);

// Include relevant state
$log->warning("Rework limit approaching", [
    'token_id' => $tokenId,
    'rework_count' => $reworkCount,
    'rework_limit' => $reworkLimit,
    'remaining' => $reworkLimit - $reworkCount
], __FILE__, __LINE__, $userId);

// Include error details
$log->error("Database query failed", [
    'query' => 'SELECT * FROM flow_token WHERE ...',
    'error' => $db->error,
    'error_code' => $db->errno
], __FILE__, __LINE__, $userId);
```

### **Bad Context Examples**

```php
// ❌ Too much data (performance impact)
$log->info("Token updated", [
    'entire_token_object' => $token,  // Too large!
    'entire_request' => $_POST        // Security risk!
], __FILE__, __LINE__, $userId);

// ❌ Sensitive data not masked
$log->info("User created", [
    'password' => $plainPassword,  // Should be masked!
    'credit_card' => $cardNumber    // Should not be logged!
], __FILE__, __LINE__, $userId);

// ✅ Good: Only relevant fields
$log->info("User created", [
    'user_id' => $userId,
    'username' => $username,
    'role' => $role
], __FILE__, __LINE__, $userId);
```

---

## 🔍 Automatic Context Capture

LogHelper automatically captures:

- **IP Address** - From Cloudflare, X-Forwarded-For, X-Real-IP, REMOTE_ADDR
- **Request Method** - GET, POST, PUT, DELETE, etc.
- **Request URI** - Up to 2000 characters
- **Source File** - From `__FILE__` parameter
- **Source Line** - From `__LINE__` parameter
- **User ID** - From `$user_id` parameter
- **Timestamp** - Automatically set to `NOW()`

---

## 📝 Method Signatures

### **Full Signature**

```php
public function log(
    string $level,           // 'INFO', 'SUCCESS', 'WARNING', 'ERROR', 'CRITICAL', 'DEBUG'
    string $message,         // Log message (required)
    array $context = [],    // Additional context data (optional)
    ?string $file = null,   // Source file (optional, use __FILE__)
    ?int $line = null,      // Source line (optional, use __LINE__)
    ?int $user_id = null    // User ID (optional)
): bool
```

### **Convenience Methods**

All convenience methods have the same signature (except `$level`):

```php
public function info(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
public function success(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
public function warning(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
public function error(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
public function critical(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
public function debug(string $message, array $context = [], ?string $file = null, ?int $line = null, ?int $user_id = null): bool
```

---

## ⚠️ Error Handling

### **Fallback Behavior**

If `system_logs` table doesn't exist:
- LogHelper falls back to `error_log()`
- Returns `false`
- No exception thrown (graceful degradation)

### **Database Connection Failure**

If database connection fails:
- Logs to `error_log()`
- Returns `false`
- No exception thrown

### **JSON Encoding Failure**

If context data cannot be JSON encoded:
- Truncates context to 500 characters
- Logs warning to `error_log()`
- Continues with truncated context

---

## 🎯 Phase 7.5 Integration Checklist

- [ ] Use PSR-4 version: `use BGERP\Helper\LogHelper;`
- [ ] Create LogHelper instance with correct DB connection
- [ ] Log all scrap actions (info level)
- [ ] Log all replacement creations (success level)
- [ ] Log all errors (error level)
- [ ] Log permission denials (warning level)
- [ ] Include relevant context (token_id, user_id, etc.)
- [ ] Use `__FILE__` and `__LINE__` for source location
- [ ] Pass `$userId` from session or parameter

---

## 📚 Related Documentation

- [LogHelper PSR-4 Migration Plan](./LOGHELPER_PSR4_MIGRATION_PLAN.md)
- [Phase 7.5 Pending Tasks](../dag/02-implementation-status/PHASE_7_5_PENDING_TASKS.md)
- [Error Handling & UX Guidelines](../dag/02-implementation-status/PHASE_7_5_PENDING_TASKS.md#-error-handling--ux-guidelines)

---

**Last Updated:** November 14, 2025

