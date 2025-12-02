# Chapter 11 — Security Handbook

**Last Updated:** November 19, 2025  
**Purpose:** Centralize security policy and best practices  
**Audience:** All developers, security auditors, AI agents

---

## Overview

This chapter provides comprehensive security guidelines for the Bellavier Group ERP system. It covers security posture, sensitive data handling, directory permissions, cryptographic operations, CSRF/RateLimit rules, and logging practices.

**Key Topics:**
- Security posture summary (Task 18)
- Sensitive data rules
- Directory permission rules
- Salts + cryptographic rules
- CSRF/RateLimit rules
- Logging rules
- Common vulnerabilities & examples

**Security Status:**
- ✅ Security audit complete (Task 18)
- ✅ Rate limiting applied to all APIs
- ✅ CSRF protection for state-changing operations
- ✅ Secure logging (no sensitive data)
- ✅ File permissions hardened

---

## Key Concepts

### 1. Security Posture Summary

**Hardened Areas (Task 18):**
- ✅ Log sensitivity - No sensitive data logged
- ✅ CSRF protection - State-changing operations protected
- ✅ Rate limiting - All APIs protected
- ✅ File permissions - Serial salt files secured
- ✅ Error handling - Clean error messages
- ✅ Session management - Proper session handling

**Known Risks / Acceptable Risks:**
- ⚠️ Tenant APIs - Limited CSRF protection (some endpoints)
- ⚠️ Upload directories - Not audited (future task)
- ⚠️ Cookie security - Server configuration dependent
- ⚠️ Remember-me tokens - Not audited (if exists)

### 2. Security-First Architecture

**Principles:**
- Security by default
- Defense in depth
- Least privilege
- Fail securely
- Complete mediation

**Implementation:**
- All APIs protected with rate limiting
- State-changing operations protected with CSRF
- All inputs validated
- All outputs sanitized
- Secure logging (no sensitive data)

---

## Core Components

### Sensitive Data Rules

#### 1. What is Sensitive Data?

**Sensitive Data Includes:**
- Passwords (plain text or hashed)
- API keys
- Tokens (access tokens, refresh tokens, CSRF tokens)
- Salts (serial salts, password salts)
- Session IDs
- Personal data (if applicable)
- Credit card numbers (if applicable)

#### 2. Sensitive Data Handling Rules

**DO NOT:**
- ❌ Log sensitive data
- ❌ Include sensitive data in error messages
- ❌ Return sensitive data in API responses
- ❌ Store sensitive data in plain text
- ❌ Expose sensitive data in stack traces

**DO:**
- ✅ Filter sensitive keys before logging
- ✅ Use secure storage (encrypted, hashed)
- ✅ Mask sensitive values in logs
- ✅ Use secure transmission (HTTPS)
- ✅ Validate and sanitize inputs

#### 3. Logging Sensitive Data

**Filtered Keys (LogHelper):**
- `password`
- `new_password`
- `api_key`
- `token`
- `salt`

**Logging Pattern:**
```php
// ❌ Wrong: Logging sensitive data
error_log('Password: ' . $password);

// ✅ Correct: Filter sensitive data
LogHelper::log('operation', $data); // Automatically filters sensitive keys
```

### Directory Permission Rules

#### 1. Serial Salt File Permissions

**Location:** `storage/serial_salts/salts.php`

**Permissions:**
- ✅ `chmod(0600)` - Owner read/write only
- ✅ Protected with `.htaccess` (Deny all)
- ✅ Not in webroot

**Implementation:**
```php
// In platform_serial_salt_api.php
chmod($saltFile, 0600);
```

#### 2. Upload Directories

**Status:** ⚠️ Not audited in Task 18 (future task)

**Recommended:**
- ✅ `chmod(0755)` - Owner read/write/execute, others read/execute
- ✅ Protected with `.htaccess` (Deny execution)
- ✅ Validate file types before upload
- ✅ Sanitize filenames

#### 3. Log Directories

**Status:** ⚠️ Server configuration dependent

**Recommended:**
- ✅ `chmod(0600)` or `0640` - Not world-readable
- ✅ Rotate logs regularly
- ✅ Monitor log file sizes
- ✅ Secure log file access

### Salts + Cryptographic Rules

#### 1. Serial Salt Generation

**Location:** `source/platform_serial_salt_api.php`

**Security Measures:**
- ✅ CSRF protection required
- ✅ Rate limiting (10 req/60s)
- ✅ Platform admin only
- ✅ Secure file storage (0600 permissions)
- ✅ No salt values in logs
- ✅ No salt values in responses

**Implementation:**
```php
// Generate salt
$salt = bin2hex(random_bytes(32));

// Store securely
file_put_contents($saltFile, $salt);
chmod($saltFile, 0600);
```

#### 2. Password Hashing

**Rules:**
- ✅ Use bcrypt (or stronger)
- ✅ Never store plain text passwords
- ✅ Never log passwords
- ✅ Use secure random salts

**Implementation:**
```php
// Hash password
$hashedPassword = password_hash($password, PASSWORD_BCRYPT);

// Verify password
if (password_verify($password, $hashedPassword)) {
    // Valid password
}
```

### CSRF/RateLimit Rules

#### 1. CSRF Protection

**When to Apply:**
- ✅ POST operations (create, update)
- ✅ PUT operations (update)
- ✅ DELETE operations (delete)
- ❌ GET operations (read-only, no CSRF needed)

**Implementation:**
```php
// Validate CSRF token
if (!validateCsrfToken($_POST['csrf_token'] ?? '')) {
    json_error('invalid_csrf', 403);
}
```

**Protected Endpoints:**
- ✅ `platform_serial_salt_api.php` - Generate, rotate actions
- ⚠️ Some tenant APIs - Limited coverage (future task)

#### 2. Rate Limiting

**Configuration:**
- **Strict**: 10 req/60s (security-critical operations)
- **Standard**: 120 req/60s (normal operations)
- **Very Low**: 5 req/60s (migration operations)

**Implementation:**
```php
use BGERP\Helper\RateLimiter;

RateLimiter::check(
    $member['id_member'],  // User ID
    'api_name',            // Endpoint name
    'action_name',         // Action name
    120,                   // Limit (requests)
    60                     // Window (seconds)
);
```

**Protected Endpoints:**
- ✅ All migrated APIs (40+ APIs)
- ✅ Platform APIs (12 APIs)
- ✅ Login API (custom implementation)

### Logging Rules

#### 1. Structured Logging Format

**Format:**
```
[CID:{correlation_id}][{filename}][User:{user_id}][Action:{action}] Message
```

**Example:**
```
[CID:abc123][products.php][User:42][Action:list] Products listed successfully
```

#### 2. Sensitive Data Filtering

**Automatic Filtering:**
- `LogHelper` automatically filters sensitive keys
- Masks sensitive values with `********`
- Never logs passwords, tokens, salts

**Manual Filtering:**
```php
// ❌ Wrong: Logging sensitive data
error_log('Password: ' . $password);

// ✅ Correct: Filter sensitive data
$safeData = array_filter($data, function($key) {
    return !in_array($key, ['password', 'api_key', 'token', 'salt']);
}, ARRAY_FILTER_USE_KEY);
error_log('Data: ' . json_encode($safeData));
```

#### 3. Error Logging

**Rules:**
- ✅ Log all errors (non-sensitive)
- ✅ Use structured format
- ✅ Include context (user, action, correlation ID)
- ❌ Never log stack traces in production
- ❌ Never log sensitive data

**Implementation:**
```php
try {
    // Operation
} catch (\Throwable $e) {
    error_log("[CID:{$cid}][{$filename}][User:{$userId}][Action:{$action}] Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

---

## Common Vulnerabilities & Examples

### 1. SQL Injection

**Vulnerable Code:**
```php
// ❌ Wrong: SQL injection vulnerability
$query = "SELECT * FROM users WHERE id = " . $_GET['id'];
$result = $db->query($query);
```

**Secure Code:**
```php
// ✅ Correct: Prepared statement
$stmt = $db->prepare("SELECT * FROM users WHERE id = ?");
$stmt->bind_param('i', $_GET['id']);
$stmt->execute();
$result = $stmt->get_result();
```

### 2. XSS (Cross-Site Scripting)

**Vulnerable Code:**
```php
// ❌ Wrong: XSS vulnerability
echo "<div>" . $_GET['name'] . "</div>";
```

**Secure Code:**
```php
// ✅ Correct: Output escaping
echo "<div>" . htmlspecialchars($_GET['name'], ENT_QUOTES, 'UTF-8') . "</div>";
```

### 3. CSRF (Cross-Site Request Forgery)

**Vulnerable Code:**
```php
// ❌ Wrong: No CSRF protection
if ($_POST['action'] == 'delete') {
    $db->query("DELETE FROM table WHERE id = " . $_POST['id']);
}
```

**Secure Code:**
```php
// ✅ Correct: CSRF protection
if (!validateCsrfToken($_POST['csrf_token'] ?? '')) {
    json_error('invalid_csrf', 403);
}
if ($_POST['action'] == 'delete') {
    $stmt = $db->prepare("DELETE FROM table WHERE id = ?");
    $stmt->bind_param('i', $_POST['id']);
    $stmt->execute();
}
```

### 4. Sensitive Data Exposure

**Vulnerable Code:**
```php
// ❌ Wrong: Exposing sensitive data
error_log('Salt: ' . $salt);
echo json_encode(['salt' => $salt]);
```

**Secure Code:**
```php
// ✅ Correct: No sensitive data exposure
error_log('Salt operation completed');
echo json_encode(['status' => 'success']); // No salt in response
```

### 5. Rate Limiting Bypass

**Vulnerable Code:**
```php
// ❌ Wrong: No rate limiting
// API vulnerable to abuse
```

**Secure Code:**
```php
// ✅ Correct: Rate limiting
use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'api', 'action', 120, 60);
```

---

## Security Checklist

### Before Deploying Any Code

- [ ] All queries use prepared statements
- [ ] All inputs validated
- [ ] All outputs escaped/sanitized
- [ ] Rate limiting applied
- [ ] CSRF protection applied (state-changing operations)
- [ ] Permission checks applied
- [ ] No sensitive data in logs
- [ ] No sensitive data in error messages
- [ ] No sensitive data in API responses
- [ ] File uploads validated (if applicable)
- [ ] Session security verified
- [ ] Error handling comprehensive

### Security Audit Checklist

- [ ] Log sensitivity audit passed
- [ ] CSRF coverage audit passed
- [ ] Rate limiter audit passed
- [ ] File permissions audit passed
- [ ] Error surface audit passed
- [ ] Session security audit passed

---

## Reference Documents

### Security Documentation

- **Security Notes**: `docs/security/task18_security_notes.md` - Complete security audit
- **Task 18**: `docs/bootstrap/Task/task18.md` - Security review & hardening

### Security Tests

- **SecurityAuditSystemWideTest**: `tests/Integration/SystemWide/SecurityAuditSystemWideTest.php`
- **AuthGlobalCasesSystemWideTest**: `tests/Integration/SystemWide/AuthGlobalCasesSystemWideTest.php`

### Related Chapters

- **Chapter 4**: Permission Architecture
- **Chapter 6**: API Development Guide
- **Chapter 10**: Testing Framework

---

## Future Expansion

### Planned Enhancements

1. **Enhanced CSRF Protection**
   - CSRF helper for tenant APIs
   - Token rotation
   - Double-submit cookie pattern

2. **Advanced Rate Limiting**
   - Per-IP rate limiting
   - Adaptive rate limiting
   - Rate limit headers

3. **Security Monitoring**
   - Intrusion detection
   - Anomaly detection
   - Security alerts

4. **Penetration Testing**
   - Regular security audits
   - Vulnerability scanning
   - Security assessments

---

**Previous Chapter:** [Chapter 10 — Testing Framework](../chapters/10-testing-framework.md)  
**Next Chapter:** [Chapter 12 — Performance Guide](../chapters/12-performance-guide.md)

