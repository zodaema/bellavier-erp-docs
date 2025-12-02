# 📘 Bellavier ERP API Standard Playbook

**Version:** 3.0 (January 2025 Update)  
**Date:** January 2025  
**Last Updated:** January 2025  
**Purpose:** มาตรฐานกลางสำหรับ API ทั้งระบบ (Bellavier ERP Standard) - ใช้เป็นเอกสารแม่สำหรับกำหนดโครงสร้าง API  
**Audience:** Development Team, Code Reviewers, AI Agents, New Team Members  
**Status:** ✅ **Bootstrap Migration: 77+ APIs migrated (85.9%)**  
**Enterprise Helpers:** ✅ **RateLimiter (71 APIs), RequestValidator (62 APIs), Idempotency (38 APIs)**

---

## 📑 Table of Contents

- [⚙️ API Structure Standard](#️-api-structure-standard-bellavier-erp---psr-4-compliant)
- [📦 Standard Response Schema](#-standard-response-schema)
- [🚨 Error Classification Matrix](#-error-classification-matrix)
- [🧾 Standardized Logging Format](#-standardized-logging-format)
- [🔒 Security Checklist](#-security-checklist)
- [📊 Executive Summary](#-executive-summary)
- [🔴 Critical Issues](#-critical-issues-must-fix)
- [🟢 Good Practices](#-good-practices-keep-these)
- [📋 Detailed File-by-File Assessment](#-detailed-file-by-file-assessment)
- [📈 API Consistency Scorecard](#-api-consistency-scorecard-post-fix-tracker)
- [🎯 Recommended Standard Template](#-recommended-standard-template)
- [📊 Migration Priority](#-migration-priority)
- [🔄 API Versioning & Deprecation](#-api-versioning--deprecation)
- [📄 Pagination, Filtering & Sorting](#-pagination-filtering--sorting)
- [🔐 Idempotency & Concurrency Control](#-idempotency--concurrency-control)
- [🔗 Correlation & Metrics](#-correlation--metrics-observability)
- [🏷️ Error Code Taxonomy](#️-error-code-taxonomy-app-specific)
- [🕐 Time/Zone Policy](#-timezone-policy)
- [📋 Standard Headers](#-standard-headers)
- [🧪 Testing Playbook](#-testing-playbook)
- [🧰 Request Validation Layer](#-request-validation-layer-standardized)
- [🧠 External API Retry Policy](#-external-api-retry-policy)
- [📋 API Capability Manifest](#-api-capability-manifest)
- [🏷️ Bellavier-Specific Namespace Policy](#️-bellavier-specific-namespace-policy)
- [🧪 Unit Test Templates](#-unit-test-templates)
- [🗑️ API Retirement Procedure](#️-api-retirement-procedure)
- [📐 JSON Schema Registry](#-json-schema-registry)

---

## ⚙️ API Structure Standard (Bellavier ERP - PSR-4 Compliant)

**Purpose:** กำหนดเลเยอร์และโครงสร้างมาตรฐานสำหรับ API ทั้งระบบ

### Architecture Layers

| Layer | Responsibility | Standard Prefix | Location | Example |
|-------|----------------|-----------------|----------|---------|
| **Controller** | Action router / Permission check / Request handling | `*_api.php` | `source/` | `dag_token_api.php`, `team_api.php` |
| **Service** | Business logic layer | `BGERP\Service\` | `source/BGERP/Service/` | `BGERP\Service\TokenLifecycleService` |
| **Model** | Database entity / Repository | `BGERP\Model\` | `source/BGERP/Model/` | `BGERP\Model\FlowToken` (future) |
| **Helper** | Shared utilities | `global_function.php` | `source/` | `json_error()`, `tenant_db()`, `db_fetch_one()` |
| **Exception** | Custom error types | `BGERP\Exception\` | `source/BGERP/Exception/` | `BGERP\Exception\ValidationException` |
| **Config** | Configuration files | `*_config.php` | `source/config/` | `operator_roles.php` |

### Mandatory Requirements

**All API controllers (`*_api.php`) MUST:**

1. ✅ **Use `switch ($action)` routing** - ไม่ใช้ `if ($action === '...')`
2. ✅ **Wrap in top-level try-catch** - จับ unhandled exceptions ทั้งหมด
3. ✅ **Return JSON via `json_error()` / `json_success()` only** - ไม่ใช้ manual `http_response_code()` + `echo json_encode()`
4. ✅ **Log all exceptions** - ใช้ standardized logging format (API name + action + timestamp)
5. ✅ **Use PSR-4 classes for business logic** - ไม่มี inline SQL ใน controller
6. ✅ **Check authentication** - ใช้ `$objMemberDetail->thisLogin()` เป็นมาตรฐาน
7. ✅ **Check permissions** - ใช้ `must_allow_code()` หรือ `permission_allow_code()`
8. ✅ **Scope by tenant** - ทุก query ต้อง filter by `id_org` (ใช้ `tenant_db()`)

### File Structure Template

```
source/
├── [module]_api.php          ← Controller (Action router)
├── BGERP/
│   ├── Service/              ← Business logic
│   │   └── [Name]Service.php
│   ├── Exception/            ← Custom exceptions
│   │   └── [Name]Exception.php
│   └── Helper/               ← Utilities
│       └── DatabaseHelper.php
├── config/                   ← Configuration
│   └── [name]_config.php
└── global_function.php       ← Shared functions
```

---

## 📦 Standard Response Schema

**Purpose:** ทุก API ต้องตอบกลับในรูปแบบ JSON ที่สอดคล้องกัน เพื่อให้ frontend, mobile app, PWA และ AI agents ใช้ schema เดียวกันทั้งหมด

### ✅ Success Response

```json
{
  "ok": true,
  "data": {
    // Response payload
  },
  "meta": {
    "timestamp": "2025-11-07T23:40:00+07:00",
    "action": "assign_token",
    "version": "1.0"
  }
}
```

**Implementation:**
```php
json_success([
    'data' => $result,
    'meta' => [
        'timestamp' => date('c'),
        'action' => $action,
        'version' => '1.0'
    ]
]);
```

### ❌ Error Response

```json
{
  "ok": false,
  "error": "Invalid parameters",
  "code": 400,
  "meta": {
    "timestamp": "2025-11-07T23:40:00+07:00",
    "file": "assignment_api.php",
    "action": "assign_token"
  }
}
```

**Implementation:**
```php
json_error('Invalid parameters', 400, [
    'meta' => [
        'timestamp' => date('c'),
        'file' => basename(__FILE__),
        'action' => $action
    ]
]);
```

### Response Codes

| HTTP Code | Meaning | Usage |
|-----------|---------|-------|
| **200** | Success | `json_success()` default |
| **400** | Bad Request | Invalid input, validation failed |
| **401** | Unauthorized | Not authenticated |
| **403** | Forbidden | No permission |
| **404** | Not Found | Resource not found |
| **409** | Conflict | Concurrency conflict, duplicate |
| **422** | Unprocessable Entity | Business logic violation |
| **500** | Internal Server Error | Unhandled exception |

**Note:** `json_error()` และ `json_success()` ใน `global_function.php` จัดการ HTTP codes อัตโนมัติ

---

## 🔄 API Versioning & Deprecation

**Purpose:** กำหนดมาตรฐานการ versioning และ deprecation สำหรับ API ทั้งระบบ

### Versioning Strategy

**Current:** All APIs use implicit versioning (no version in path)

**Future Standard:**
- Path-based: `/api/v1/...`, `/api/v2/...`
- Header-based: `X-API-Version: 1.0`

### Deprecation Policy

**When deprecating an endpoint:**

1. **Add deprecation headers:**
   ```php
   header('Deprecation: true');
   header('Sunset: 2026-06-01T00:00:00+07:00'); // ISO8601 format
   header('Link: </api/v2/new-endpoint>; rel="successor-version"');
   ```

2. **Return deprecation warning in response:**
   ```json
   {
     "ok": true,
     "data": {...},
     "meta": {
       "deprecated": true,
       "sunset": "2026-06-01T00:00:00+07:00",
       "migrate_to": "/api/v2/new-endpoint"
     }
   }
   ```

3. **Document in CHANGELOG.md:**
   - Mark endpoint as deprecated
   - Specify migration path
   - Set removal date

### Deprecated Endpoint Error Response

```json
{
  "ok": false,
  "error": "deprecated",
  "code": 410,
  "meta": {
    "deprecated": true,
    "sunset": "2026-06-01T00:00:00+07:00",
    "migrate_to": "/api/v2/new-endpoint",
    "app_code": "CORE_410_01"
  }
}
```

**Implementation:**
```php
if ($isDeprecated) {
    header('Deprecation: true');
    header('Sunset: 2026-06-01T00:00:00+07:00');
    json_error('deprecated', 410, [
        'meta' => [
            'deprecated' => true,
            'sunset' => '2026-06-01T00:00:00+07:00',
            'migrate_to' => '/api/v2/new-endpoint',
            'app_code' => 'CORE_410_01'
        ]
    ]);
}
```

---

## 📄 Pagination, Filtering & Sorting

**Purpose:** กำหนดมาตรฐานการ pagination, filtering และ sorting ให้เป็นหนึ่งเดียวทั้งระบบ

### Cursor-Based Pagination (Recommended)

**Query Parameters:**
```
?limit=50&cursor=abc123&sort=created_at.desc&filter[status]=active&filter[type]=hatthasilpa
```

**Response:**
```json
{
  "ok": true,
  "data": [...],
  "meta": {
    "next_cursor": "def456",
    "has_more": true,
    "total": null
  }
}
```

**Implementation:**
```php
$limit = min((int)($_GET['limit'] ?? 50), 100); // Max 100
$cursor = $_GET['cursor'] ?? null;
$sort = $_GET['sort'] ?? 'created_at.desc'; // field.direction

// Parse sort
[$sortField, $sortDir] = explode('.', $sort);
$sortDir = strtoupper($sortDir) === 'DESC' ? 'DESC' : 'ASC';

// Build query
$sql = "SELECT * FROM table WHERE 1=1";
$params = [];
$types = '';

if ($cursor) {
    $sql .= " AND id > ?";
    $params[] = $cursor;
    $types .= 'i';
}

$sql .= " ORDER BY {$sortField} {$sortDir} LIMIT ?";
$params[] = $limit + 1; // Fetch one extra to check has_more
$types .= 'i';

// Execute query
$stmt = $tenantDb->prepare($sql);
if (!empty($params)) {
    $stmt->bind_param($types, ...$params);
}
$stmt->execute();
$results = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

// Check if has more
$hasMore = count($results) > $limit;
if ($hasMore) {
    array_pop($results); // Remove extra item
}

// Get next cursor (last item's ID)
$nextCursor = $hasMore ? end($results)['id'] : null;

json_success([
    'data' => $results,
    'meta' => [
        'next_cursor' => $nextCursor,
        'has_more' => $hasMore,
        'total' => null // Cursor-based doesn't provide total
    ]
]);
```

### Filtering

**Query Format:**
```
?filter[field]=value&filter[field2]=value2
```

**Implementation:**
```php
$filters = $_GET['filter'] ?? [];
$whereClauses = [];
$params = [];
$types = '';

foreach ($filters as $field => $value) {
    // Whitelist allowed filter fields
    $allowedFields = ['status', 'type', 'category'];
    if (!in_array($field, $allowedFields)) {
        continue;
    }
    
    $whereClauses[] = "{$field} = ?";
    $params[] = $value;
    $types .= 's';
}

if (!empty($whereClauses)) {
    $sql .= " AND " . implode(" AND ", $whereClauses);
}
```

### Sorting

**Query Format:**
```
?sort=field.direction
```

**Allowed Directions:** `asc`, `desc`

**Default:** `created_at.desc`

**Note:** Offset-based pagination (`?page=1&per_page=50`) is **deprecated** - use cursor-based instead.

---

## 🛡️ Enterprise API Helpers (RateLimiter, RequestValidator, Idempotency)

**Version:** 2.6+  
**Status:** ✅ Integrated in 6 APIs (work_centers, materials, dashboard, bom, qc_rework, system_log)

### RateLimiter

**Purpose:** ป้องกันการใช้งาน API เกินขีดจำกัด และรับประกันการใช้งานทรัพยากรอย่างเป็นธรรม

**Usage:**
```php
use BGERP\Helper\RateLimiter;

// After authentication, before switch($action)
RateLimiter::check($member, 120, 60, 'endpoint_name');
// Parameters: $member, $maxRequests, $windowSeconds, $endpoint
```

**Features:**
- File-based rate limiting (Redis optional)
- Per-user, per-endpoint tracking
- Automatic 429 response with Retry-After header
- X-RateLimit-* headers for client awareness

**Mandatory:** ✅ Required for all API endpoints

### RequestValidator

**Purpose:** Validation และ sanitization แบบรวมศูนย์สำหรับ user inputs

**Usage:**
```php
use BGERP\Helper\RequestValidator;

$validation = RequestValidator::make($_POST, [
    'id' => 'required|integer|min:1',
    'name' => 'required|string|max:255',
    'email' => 'nullable|string|max:100',
    'status' => 'nullable|in:active,inactive'
]);

if (!$validation['valid']) {
    $firstError = $validation['errors'][0] ?? null;
    json_error($firstError['message'] ?? 'validation_failed', 400, [
        'app_code' => $firstError['app_code'] ?? 'MODULE_400_VALIDATION',
        'errors' => $validation['errors']
    ]);
}

$data = $validation['data']; // Sanitized and validated
```

**Supported Rules:**
- `required`, `nullable`
- `string`, `integer`, `float`
- `max:value`, `min:value`
- `in:value1,value2`

**Mandatory:** ✅ Required for all user inputs (replace manual trim()/isset() checks)

### Idempotency

**Purpose:** ป้องกันการส่ง request ซ้ำ (double-submission) สำหรับ create operations

**Usage:**
```php
use BGERP\Helper\Idempotency;

// Before INSERT
$idempotencyKey = $_SERVER['HTTP_IDEMPOTENCY_KEY'] ?? null;
$cachedResponse = Idempotency::guard($idempotencyKey, 'create');
if ($cachedResponse !== null) {
    return; // Replay cached response
}

// After successful INSERT
if ($idempotencyKey) {
    Idempotency::store($idempotencyKey, ['id' => $newId], 201);
}

// Return 201 Created with Location header
header('Location: /source/api.php?action=detail&id=' . $newId);
json_success(['id' => $newId], 201);
```

**Features:**
- File-based caching (1 hour TTL)
- Automatic response replay for duplicate keys
- REST-compliant 201 Created status

**Mandatory:** ✅ Required for all create operations

### ETag / If-Match (Concurrency Control)

**Purpose:** ป้องกัน concurrent write conflicts สำหรับ update operations

**Usage:**
```php
// In detail/get action
$etag = md5(json_encode($data));
header('ETag: "' . $etag . '"');
header('Cache-Control: private, max-age=30');

// In update action
$currentEtag = md5(json_encode($current));
if (!empty($_SERVER['HTTP_IF_MATCH']) && $_SERVER['HTTP_IF_MATCH'] !== '"' . $currentEtag . '"') {
    json_error('version_conflict', 409, ['app_code' => 'MODULE_409_VER']);
}
```

**Mandatory:** ✅ Required for all update operations

### Maintenance Mode

**Purpose:** อนุญาตให้ระบบปิดการใช้งานชั่วคราวอย่างเป็นระบบ

**Usage:**
```php
// At start of API file, before authentication
if (file_exists(__DIR__ . '/../storage/maintenance.flag')) {
    header('Retry-After: 60');
    json_error('service_unavailable', 503, ['app_code' => 'CORE_503_MAINT']);
}
```

**Mandatory:** ✅ Required for all API endpoints

### Execution Time Tracking

**Purpose:** ติดตาม performance และช่วยในการ debug

**Usage:**
```php
// At start
$__t0 = microtime(true);

// Before response (in try block)
$aiTrace['execution_ms'] = (int)((microtime(true) - $__t0) * 1000);
header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));

// In catch block (even on error)
$aiTrace['execution_ms'] = (int)((microtime(true) - $__t0) * 1000);
$aiTrace['error'] = $e->getMessage();
header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));
```

**Mandatory:** ✅ Required for all API endpoints

---

## 🔐 Idempotency & Concurrency Control

**Purpose:** รับประกัน idempotency สำหรับ POST/PUT และป้องกัน concurrency conflicts

### Idempotency Key (POST/PUT ที่สร้างทรัพยากร)

**Header:** `Idempotency-Key: <UUID-v4>`

**Implementation:**
```php
$idk = $_SERVER['HTTP_IDEMPOTENCY_KEY'] ?? null;

if (!$idk) {
    json_error('Idempotency-Key required', 400, ['app_code' => 'CORE_400_01']);
}

// Validate UUID format
if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $idk)) {
    json_error('Invalid Idempotency-Key format (must be UUID v4)', 400, ['app_code' => 'CORE_400_02']);
}

// Check if key already exists
$stmt = $tenantDb->prepare("SELECT id, result_data FROM idempotency_keys WHERE key_val=? AND created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)");
$stmt->bind_param('s', $idk);
$stmt->execute();
$existing = $stmt->get_result()->fetch_assoc();
$stmt->close();

if ($existing) {
    // Return cached response
    header('X-Idempotency-Replayed: true');
    echo $existing['result_data'];
    exit;
}

// Store idempotency key (will be updated with result after operation)
$stmt = $tenantDb->prepare("INSERT INTO idempotency_keys(key_val, created_at) VALUES(?, NOW())");
$stmt->bind_param('s', $idk);
$stmt->execute();
$stmt->close();

// After successful operation, update with result:
// $resultJson = json_encode(['ok' => true, 'data' => $result]);
// $stmt = $tenantDb->prepare("UPDATE idempotency_keys SET result_data=? WHERE key_val=?");
// $stmt->bind_param('ss', $resultJson, $idk);
// $stmt->execute();
```

**Database Schema:**
```sql
CREATE TABLE idempotency_keys (
    id INT AUTO_INCREMENT PRIMARY KEY,
    key_val VARCHAR(36) UNIQUE NOT NULL,
    result_data TEXT,
    created_at DATETIME NOT NULL,
    INDEX idx_key_created (key_val, created_at)
) ENGINE=InnoDB;
```

### ETag / If-Match (Concurrency Control)

**For Read Operations:**
```php
// Calculate ETag from version hash or last modified
$etag = sprintf('"%s"', hash('sha256', $row['version_hash'] ?? $row['updated_at']));
header('ETag: ' . $etag);
```

**For Update Operations:**
```php
$ifMatch = $_SERVER['HTTP_IF_MATCH'] ?? '';
$currentEtag = sprintf('"%s"', hash('sha256', $row['version_hash'] ?? $row['updated_at']));

if ($ifMatch && $ifMatch !== $currentEtag) {
    json_error('Version conflict - resource has been modified', 409, [
        'app_code' => 'CORE_409_02',
        'meta' => [
            'current_version' => $currentEtag,
            'provided_version' => $ifMatch
        ]
    ]);
}
```

**Response Headers:**
- `ETag: "v7"` - Current version of resource
- `Last-Modified: Wed, 21 Oct 2015 07:28:00 GMT` - Last modification time

---

## 🧰 Request Validation Layer (Standardized)

**Purpose:** กำหนดมาตรฐานการ validate request inputs ให้ทุก API ใช้ validator เดียวกัน เพื่อลด code duplication และสร้าง error message + app_code อัตโนมัติ

### RequestValidator Helper

**Location:** `source/BGERP/Helper/RequestValidator.php`

**Usage:**
```php
use BGERP\Helper\RequestValidator;

// Validate request data
$validated = RequestValidator::make($_POST, [
    'id' => 'required|integer|min:1',
    'status' => 'required|string|in:active,inactive,pending',
    'name' => 'required|string|max:255',
    'email' => 'nullable|email|max:100',
    'quantity' => 'required|integer|min:1|max:1000',
    'assigned_to' => 'nullable|integer|exists:account,id_member',
]);

if (!$validated['valid']) {
    json_error('Validation failed', 400, [
        'app_code' => $validated['app_code'] ?? 'CORE_400_05',
        'validation_errors' => $validated['errors']
    ]);
}

// Use validated data
$id = $validated['data']['id'];
$status = $validated['data']['status'];
```

### Validation Rules

| Rule | Description | Example |
|------|-------------|---------|
| `required` | Field must be present and not empty | `'id' => 'required'` |
| `nullable` | Field is optional | `'notes' => 'nullable|string'` |
| `integer` | Must be an integer | `'id' => 'required|integer'` |
| `string` | Must be a string | `'name' => 'required|string'` |
| `email` | Must be valid email format | `'email' => 'required|email'` |
| `min:N` | Minimum value/length | `'id' => 'integer|min:1'` |
| `max:N` | Maximum value/length | `'name' => 'string|max:255'` |
| `in:val1,val2` | Must be one of the values | `'status' => 'in:active,inactive'` |
| `exists:table,column` | Must exist in database | `'user_id' => 'exists:account,id_member'` |
| `regex:pattern` | Must match regex pattern | `'code' => 'regex:/^[A-Z0-9]+$/'` |

### Auto-Generated App Codes

**Format:** `{MODULE}_400_{SEQUENCE}`

**Examples:**
- `CORE_400_05` - General validation failure
- `CORE_400_06` - Missing required field
- `CORE_400_07` - Invalid format
- `CORE_400_08` - Value out of range

### Implementation Example

```php
<?php
namespace BGERP\Helper;

class RequestValidator
{
    public static function make(array $data, array $rules): array
    {
        $errors = [];
        $validated = [];
        
        foreach ($rules as $field => $ruleString) {
            $rulesArray = explode('|', $ruleString);
            $value = $data[$field] ?? null;
            
            // Check required
            if (in_array('required', $rulesArray)) {
                if ($value === null || $value === '') {
                    $errors[$field][] = "Field '{$field}' is required";
                    continue;
                }
            }
            
            // Skip validation if nullable and empty
            if (in_array('nullable', $rulesArray) && ($value === null || $value === '')) {
                $validated[$field] = null;
                continue;
            }
            
            // Type validation
            if (in_array('integer', $rulesArray)) {
                if (!is_numeric($value) || (int)$value != $value) {
                    $errors[$field][] = "Field '{$field}' must be an integer";
                    continue;
                }
                $value = (int)$value;
            }
            
            if (in_array('string', $rulesArray)) {
                if (!is_string($value)) {
                    $errors[$field][] = "Field '{$field}' must be a string";
                    continue;
                }
            }
            
            // Min/Max validation
            foreach ($rulesArray as $rule) {
                if (preg_match('/^min:(\d+)$/', $rule, $matches)) {
                    $min = (int)$matches[1];
                    if (is_numeric($value) && $value < $min) {
                        $errors[$field][] = "Field '{$field}' must be at least {$min}";
                    }
                }
                
                if (preg_match('/^max:(\d+)$/', $rule, $matches)) {
                    $max = (int)$matches[1];
                    if (is_string($value) && strlen($value) > $max) {
                        $errors[$field][] = "Field '{$field}' must not exceed {$max} characters";
                    } elseif (is_numeric($value) && $value > $max) {
                        $errors[$field][] = "Field '{$field}' must not exceed {$max}";
                    }
                }
            }
            
            // In validation
            foreach ($rulesArray as $rule) {
                if (preg_match('/^in:(.+)$/', $rule, $matches)) {
                    $allowedValues = explode(',', $matches[1]);
                    if (!in_array($value, $allowedValues)) {
                        $errors[$field][] = "Field '{$field}' must be one of: " . implode(', ', $allowedValues);
                    }
                }
            }
            
            $validated[$field] = $value;
        }
        
        return [
            'valid' => empty($errors),
            'data' => $validated,
            'errors' => $errors,
            'app_code' => empty($errors) ? null : 'CORE_400_05'
        ];
    }
}
```

### Benefits

- ✅ **Reduces code duplication** - Single validation logic for all APIs
- ✅ **Auto-generates app_code** - Consistent error codes
- ✅ **AI Test Generator ready** - Works with Schemathesis, Dredd
- ✅ **Type-safe validated data** - No need for manual type casting
- ✅ **Clear error messages** - User-friendly validation feedback

---

## 🏷️ Bellavier-Specific Namespace Policy

**Purpose:** ป้องกัน future namespace collision และรองรับการแตก branch project อื่น (Charlotte Aimée ERP, Rebello ERP) โดยไม่ต้องแก้ import

### Namespace Alias Strategy

**Current:** `BGERP\` namespace only

**Recommended:** Add `Bellavier\ERP\` as alias for `BGERP\`

### Composer.json Configuration

**Add to `composer.json`:**
```json
{
  "autoload": {
    "psr-4": {
      "BGERP\\": "source/BGERP/",
      "Bellavier\\ERP\\": "source/BGERP/"
    }
  }
}
```

**Benefits:**
- ✅ **Prevents namespace collision** - Future projects can use different namespaces
- ✅ **Branch-friendly** - Charlotte Aimée ERP can use `CAERP\`, Rebello ERP can use `REB\`
- ✅ **Backward compatible** - Existing `BGERP\` imports still work
- ✅ **Future-proof** - Easy to migrate to full `Bellavier\ERP\` namespace

### Usage Examples

**Option 1: Use BGERP (Current)**
```php
use BGERP\Service\TokenLifecycleService;
use BGERP\Exception\ValidationException;
```

**Option 2: Use Bellavier\ERP (New, Recommended)**
```php
use Bellavier\ERP\Service\TokenLifecycleService;
use Bellavier\ERP\Exception\ValidationException;
```

**Both work identically** - Same classes, same functionality

### Migration Path

**Phase 1 (Current):** Use `BGERP\` namespace
**Phase 2 (Future):** Gradually migrate to `Bellavier\ERP\`
**Phase 3 (Long-term):** Deprecate `BGERP\` alias (with 1-year notice)

**Implementation:**
```bash
# After updating composer.json
composer dump-autoload
```

---

## 🚨 Error Classification Matrix

**Purpose:** แบ่งระดับความรุนแรงของ errors เพื่อให้ monitoring และ AI agents วิเคราะห์ log ได้อัตโนมัติ

| Level | Severity | Function | Example | Action Required | Log Format |
|-------|----------|----------|---------|----------------|------------|
| ⚠️ **Warning** | Low | Recoverable issue | Missing optional param, fallback used | Log + Continue | `[WARN]` |
| ❌ **Error** | Medium | API logic failure | Invalid input, no permission, validation failed | Return `json_error()` | `[ERROR]` |
| 💣 **Critical** | High | Unhandled exception / DB fail | PDOException, Token invariant broken, Data corruption | Log + Alert admin | `[CRITICAL]` |
| 🧩 **System** | Critical | Infrastructure issue | Redis down, Config missing, Autoload failed | Escalate to DevOps immediately | `[SYSTEM]` |

### Error Handling Pattern

```php
try {
    // Business logic
} catch (\BGERP\Exception\ValidationException $e) {
    // ⚠️ Warning / ❌ Error level
    error_log(sprintf("[ERROR][%s][%s] Validation failed: %s", ...));
    json_error($e->getMessage(), 400);
    
} catch (\BGERP\Exception\DatabaseException $e) {
    // 💣 Critical level
    error_log(sprintf("[CRITICAL][%s][%s] Database error: %s", ...));
    json_error('Database operation failed', 500);
    
} catch (\Throwable $e) {
    // 💣 Critical / 🧩 System level
    error_log(sprintf("[CRITICAL][%s][%s] Unhandled exception: %s", ...));
    json_error('Internal server error', 500);
}
```

---

## 🧾 Standardized Logging Format

**Purpose:** กำหนด log format เดียวกันทุกไฟล์ เพื่อให้ filter ได้ง่ายใน CloudWatch, Graylog, หรือระบบ internal log viewer

### Standard Log Format

```php
error_log(sprintf(
    "[%s][%s][User:%d][Action:%s] %s",
    date('Y-m-d H:i:s'),
    basename(__FILE__),
    $member['id_member'] ?? 0,
    $action ?? '-',
    $message
));
```

### Log Levels

```php
// ⚠️ Warning
error_log(sprintf("[WARN][%s][%s][User:%d][Action:%s] %s", ...));

// ❌ Error
error_log(sprintf("[ERROR][%s][%s][User:%d][Action:%s] %s", ...));

// 💣 Critical
error_log(sprintf("[CRITICAL][%s][%s][User:%d][Action:%s] %s", ...));

// 🧩 System
error_log(sprintf("[SYSTEM][%s][%s][User:%d][Action:%s] %s", ...));
```

### Enhanced Logging (Development Mode)

```php
$isDev = defined('APP_ENV') && APP_ENV === 'development';

if ($isDev) {
    error_log(sprintf(
        "[%s][%s][User:%d][Action:%s] %s\nStack trace:\n%s",
        date('Y-m-d H:i:s'),
        basename(__FILE__),
        $member['id_member'] ?? 0,
        $action ?? '-',
        $e->getMessage(),
        $e->getTraceAsString()
    ));
} else {
    error_log(sprintf(
        "[%s][%s][User:%d][Action:%s] %s",
        date('Y-m-d H:i:s'),
        basename(__FILE__),
        $member['id_member'] ?? 0,
        $action ?? '-',
        $e->getMessage()
    ));
}
```

### Log Parsing Examples

**Filter by API file:**
```bash
grep "\[.*\]\[dag_token_api.php\]" error_log
```

**Filter by user:**
```bash
grep "\[User:123\]" error_log
```

**Filter by action:**
```bash
grep "\[Action:assign_token\]" error_log
```

**Filter by severity:**
```bash
grep "\[CRITICAL\]" error_log
```

---

## 🔗 Correlation & Metrics (Observability)

**Purpose:** บังคับรับ/สร้าง X-Correlation-Id และกำหนด Metrics ชื่อมาตรฐานเพื่อให้ log เดียวกันในทุก service

### Correlation ID

**Header:** `X-Correlation-Id: <hex-string>`

**Implementation:**
```php
// Get or generate correlation ID
$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));

// Set in response header
header('X-Correlation-Id: ' . $cid);

// Use in all logs
error_log(sprintf(
    "[CID:%s][%s][User:%d][Action:%s] %s",
    $cid,
    basename(__FILE__),
    $member['id_member'] ?? 0,
    $action ?? '-',
    $message
));
```

**Benefits:**
- Trace request across multiple services
- Filter logs by correlation ID
- Debug distributed systems easily

### AI Trace Metadata

**Purpose:** เพิ่ม metadata สำหรับ AI Agents วิเคราะห์ log และ performance ได้แม่นยำขึ้น

**Header:** `X-AI-Trace: <JSON>`

**Implementation:**
```php
// Generate AI trace metadata
$aiTrace = [
    'module' => basename(__FILE__, '.php'),
    'action' => $action ?? '-',
    'tenant' => $member['id_org'] ?? 0,
    'user_id' => $member['id_member'] ?? 0,
    'timestamp' => gmdate('c'),
    'request_id' => $cid // Correlation ID
];

header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));

// Include in logs
error_log(sprintf(
    "[CID:%s][AI-Trace:%s][%s][User:%d][Action:%s] %s",
    $cid,
    json_encode($aiTrace),
    basename(__FILE__),
    $member['id_member'] ?? 0,
    $action ?? '-',
    $message
));
```

**Benefits:**
- ✅ **AI Agent Log Analysis** - AI สามารถเข้าใจ context ระหว่าง API, Tenant, และ Operator ได้ชัดเจน
- ✅ **Bellavier AI Diagnostic Dashboard** - เตรียมพร้อมสำหรับ Phase 3 AI Dashboard
- ✅ **Performance Correlation** - เชื่อมโยง performance metrics กับ tenant/user context
- ✅ **Automated Debugging** - AI สามารถวิเคราะห์ root cause ได้เร็วขึ้น

**Example Log Output:**
```
[CID:a1b2c3d4][AI-Trace:{"module":"dag_token_api","action":"token/spawn","tenant":1,"user_id":5}][dag_token_api][User:5][Action:token/spawn] Token spawned successfully
```

### Standard Metrics

**Naming Convention:** `api.{metric_name}{labels}`

**Required Metrics:**

1. **Request Count:**
   ```
   api.requests_total{api="dag_token_api",action="token/spawn",code="200"}
   ```

2. **Latency:**
   ```
   api.latency_ms{api="dag_token_api",action="token/spawn",code="200",success="true"}
   ```

3. **Errors:**
   ```
   api.errors_total{api="dag_token_api",action="token/spawn",severity="error"}
   ```

**Implementation Example:**
```php
$startTime = microtime(true);

// ... business logic ...

$duration = (microtime(true) - $startTime) * 1000; // milliseconds
$success = isset($result['ok']) && $result['ok'];

// Log metric (to be collected by monitoring system)
error_log(sprintf(
    "[METRIC] api.latency_ms{api=\"%s\",action=\"%s\",code=\"%d\",success=\"%s\"} %d",
    basename(__FILE__, '.php'),
    $action,
    http_response_code(),
    $success ? 'true' : 'false',
    (int)$duration
));
```

---

## 🏷️ Error Code Taxonomy (App-Specific)

**Purpose:** นอกเหนือจาก HTTP code ให้มี `app_code` คงที่เพื่อให้ frontend/mobile app แสดง error message ที่เหมาะสม

### App Code Format

```
{MODULE}_{HTTP_CODE}_{SEQUENCE}
```

**Module Prefixes:**
- `CORE_` - Core system errors
- `DAG_` - DAG/Token system errors
- `ASN_` - Assignment system errors
- `OPD_` - Operator Directory errors
- `PWA_` - PWA Scan Station errors
- `TEAM_` - Team management errors

**Example:**
```json
{
  "ok": false,
  "error": "operator_not_found",
  "code": 404,
  "app_code": "OPD_404_01",
  "meta": {
    "message": "Operator not found",
    "help_url": "/docs/errors/OPD_404_01"
  }
}
```

### App Code Mapping Table

| App Code | HTTP Code | Module | Description | Solution |
|----------|-----------|--------|-------------|----------|
| `CORE_400_01` | 400 | Core | Missing Idempotency-Key | Include `Idempotency-Key` header |
| `CORE_400_02` | 400 | Core | Invalid Idempotency-Key format | Use UUID v4 format |
| `CORE_409_01` | 409 | Core | Duplicate request (idempotency) | Request already processed |
| `CORE_409_02` | 409 | Core | Version conflict (ETag mismatch) | Refresh resource and retry |
| `DAG_400_01` | 400 | DAG | Invalid token state | Check token status |
| `DAG_404_01` | 404 | DAG | Token not found | Verify token ID |
| `OPD_404_01` | 404 | Operator | Operator not found | Check operator ID |
| `ASN_403_01` | 403 | Assignment | Permission denied | Check user permissions |

**Implementation:**
```php
json_error('operator_not_found', 404, [
    'app_code' => 'OPD_404_01',
    'meta' => [
        'message' => 'Operator not found',
        'help_url' => '/docs/errors/OPD_404_01'
    ]
]);
```

---

## 🔒 Security Checklist

**Purpose:** Checklist สำหรับ code reviewer ใช้เช็กก่อน merge โดยไม่ต้องเปิดหลายไฟล์

| Check | Description | Standard | Status |
|-------|-------------|----------|--------|
| ✅ **Authentication** | `$objMemberDetail->thisLogin()` called | Required | ✅ |
| ✅ **Tenant Isolation** | All queries scoped by `id_org` | Required | ✅ |
| ✅ **Input Validation** | Every POST/GET param validated | Required | ⚠️ |
| ✅ **SQL Injection** | All queries use prepared statements | Required | ✅ |
| ✅ **XSS Prevention** | Output escaped with `htmlspecialchars()` | Required | ⚠️ |
| ⚠️ **File Upload** | Must use `/uploads/temp/` and sanitize names | Required | ⚠️ |
| ⚠️ **External API** | Require approval + timeout handling | Required | ⚠️ |
| ⚠️ **CSRF Protection** | Not applicable (API-only, session-based) | N/A | ✅ |
| ⚠️ **Rate Limiting** | IP/Member-based, return 429 + Retry-After | Required | ⏳ |
| ⚠️ **Input Sanitization** | Use `ValidationService` for all inputs | Recommended | ⚠️ |
| ⚠️ **PII Redaction** | Never log: phone, email, tokens, file paths | Required | ⚠️ |
| ⚠️ **File Upload Policy** | Max size, allowed types, virus scan, temp storage | Required | ⚠️ |

### Security Best Practices

1. **Always validate input:**
   ```php
   $id = (int)($_POST['id'] ?? 0);
   if ($id <= 0) {
       json_error('Invalid ID', 400);
   }
   ```

2. **Always use prepared statements:**
   ```php
   $stmt = $tenantDb->prepare("SELECT * FROM table WHERE id=?");
   $stmt->bind_param('i', $id);
   ```

3. **Always scope by tenant:**
   ```php
   $tenantDb = tenant_db(); // Auto-scopes by current org
   // Or explicitly:
   $stmt = $tenantDb->prepare("SELECT * FROM table WHERE id_org=? AND id=?");
   ```

4. **Always check permissions:**
   ```php
   must_allow_code($member, 'permission.code');
   ```

### PII Redaction (Log Security)

**Never log sensitive data:**
- Phone numbers
- Email addresses
- API tokens / passwords
- File paths with user data
- Credit card numbers
- Personal identification numbers

**Redaction Pattern:**
```php
function redactPII($data) {
    // Redact phone numbers
    $data = preg_replace('/\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/', '***-***-****', $data);
    
    // Redact email addresses
    $data = preg_replace('/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/', '***@***.***', $data);
    
    // Redact tokens (32+ character hex strings)
    $data = preg_replace('/\b[0-9a-f]{32,}\b/i', '***TOKEN***', $data);
    
    return $data;
}

// Use before logging
error_log(sprintf("[%s] User data: %s", basename(__FILE__), redactPII(json_encode($userData))));
```

### File Upload Policy

**Requirements:**
1. **Max file size:** 10MB (configurable)
2. **Allowed types:** Whitelist only (`image/jpeg`, `image/png`, `application/pdf`, etc.)
3. **Storage:** Temporary storage in `/uploads/temp/` only
4. **Virus scan:** Scan before processing (future enhancement)
5. **Cron purge:** Delete files older than 7 days automatically

**Implementation:**
```php
$allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'application/pdf'];
$maxSize = 10 * 1024 * 1024; // 10MB

if (!in_array($_FILES['file']['type'], $allowedTypes)) {
    json_error('Invalid file type', 400, ['app_code' => 'CORE_400_03']);
}

if ($_FILES['file']['size'] > $maxSize) {
    json_error('File too large (max 10MB)', 400, ['app_code' => 'CORE_400_04']);
}

// Sanitize filename
$filename = preg_replace('/[^a-zA-Z0-9._-]/', '', basename($_FILES['file']['name']));
$tempPath = __DIR__ . '/../uploads/temp/' . uniqid() . '_' . $filename;

// Move to temp storage
if (!move_uploaded_file($_FILES['file']['tmp_name'], $tempPath)) {
    json_error('Failed to save file', 500, ['app_code' => 'CORE_500_01']);
}
```

### Rate Limiting

**Headers:**
- `X-RateLimit-Limit: 100` - Requests per window
- `X-RateLimit-Remaining: 95` - Remaining requests
- `X-RateLimit-Reset: 1636329600` - Reset timestamp
- `Retry-After: 60` - Seconds to wait (when 429)

**Implementation:**
```php
// Rate limit by IP + Member ID
$rateLimitKey = sprintf('rate_limit:%s:%d', $_SERVER['REMOTE_ADDR'], $member['id_member']);
$rateLimitCount = apcu_fetch($rateLimitKey) ?: 0;
$rateLimitMax = 100; // per hour
$rateLimitWindow = 3600; // seconds

if ($rateLimitCount >= $rateLimitMax) {
    header('Retry-After: ' . $rateLimitWindow);
    json_error('Rate limit exceeded', 429, ['app_code' => 'CORE_429_01']);
}

// Increment counter
apcu_store($rateLimitKey, $rateLimitCount + 1, $rateLimitWindow);

// Set headers
header('X-RateLimit-Limit: ' . $rateLimitMax);
header('X-RateLimit-Remaining: ' . ($rateLimitMax - $rateLimitCount - 1));
header('X-RateLimit-Reset: ' . (time() + $rateLimitWindow));
```

---

## 🧠 External API Retry Policy

**Purpose:** กำหนดมาตรฐานการ retry สำหรับ External API Integration (LINE OA, Meta API, Shippop, etc.) เพื่อลดการ fail แบบ random และรองรับ automated retry ที่ predictable

### Retry Strategy

**Pattern:** Exponential Backoff with Max Attempts

**Implementation:**
```php
function callExternalAPI(string $url, array $payload, int $maxAttempts = 3): array
{
    $cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
    
    for ($attempt = 1; $attempt <= $maxAttempts; $attempt++) {
        try {
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => json_encode($payload),
                CURLOPT_HTTPHEADER => [
                    'Content-Type: application/json',
                    'X-Correlation-Id: ' . $cid,
                    'X-Attempt: ' . $attempt
                ],
                CURLOPT_TIMEOUT => 10, // 10 seconds timeout
                CURLOPT_CONNECTTIMEOUT => 5 // 5 seconds connect timeout
            ]);
            
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            curl_close($ch);
            
            if ($curlError) {
                throw new \Exception("cURL error: {$curlError}");
            }
            
            $decoded = json_decode($response, true);
            
            // Success (2xx status codes)
            if ($httpCode >= 200 && $httpCode < 300) {
                error_log(sprintf(
                    "[CID:%s][RETRY][Attempt:%d/%d][SUCCESS] External API call succeeded",
                    $cid,
                    $attempt,
                    $maxAttempts
                ));
                
                return [
                    'ok' => true,
                    'data' => $decoded,
                    'http_code' => $httpCode,
                    'attempts' => $attempt
                ];
            }
            
            // Retryable errors (5xx, timeout, network errors)
            if ($httpCode >= 500 || $httpCode === 0) {
                if ($attempt < $maxAttempts) {
                    $delay = 200000 * $attempt; // Exponential backoff: 200ms, 400ms, 600ms
                    error_log(sprintf(
                        "[CID:%s][RETRY][Attempt:%d/%d][RETRYABLE] HTTP %d, retrying in %dms",
                        $cid,
                        $attempt,
                        $maxAttempts,
                        $httpCode,
                        $delay / 1000
                    ));
                    usleep($delay);
                    continue;
                }
            }
            
            // Non-retryable errors (4xx)
            error_log(sprintf(
                "[CID:%s][RETRY][Attempt:%d/%d][FAILED] HTTP %d - Non-retryable",
                $cid,
                $attempt,
                $maxAttempts,
                $httpCode
            ));
            
            return [
                'ok' => false,
                'error' => 'External API call failed',
                'http_code' => $httpCode,
                'data' => $decoded,
                'attempts' => $attempt,
                'app_code' => 'CORE_500_02'
            ];
            
        } catch (\Exception $e) {
            if ($attempt < $maxAttempts) {
                $delay = 200000 * $attempt;
                error_log(sprintf(
                    "[CID:%s][RETRY][Attempt:%d/%d][EXCEPTION] %s, retrying in %dms",
                    $cid,
                    $attempt,
                    $maxAttempts,
                    $e->getMessage(),
                    $delay / 1000
                ));
                usleep($delay);
                continue;
            }
            
            error_log(sprintf(
                "[CID:%s][RETRY][Attempt:%d/%d][FAILED] %s",
                $cid,
                $attempt,
                $maxAttempts,
                $e->getMessage()
            ));
            
            return [
                'ok' => false,
                'error' => $e->getMessage(),
                'attempts' => $attempt,
                'app_code' => 'CORE_500_03'
            ];
        }
    }
    
    // All attempts exhausted
    return [
        'ok' => false,
        'error' => 'External API call failed after ' . $maxAttempts . ' attempts',
        'attempts' => $maxAttempts,
        'app_code' => 'CORE_500_04'
    ];
}
```

### Retry Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `max_attempts` | 3 | Maximum retry attempts |
| `initial_delay_ms` | 200 | Initial delay in milliseconds |
| `backoff_multiplier` | 1 | Multiplier for exponential backoff (attempt * delay) |
| `timeout_seconds` | 10 | Request timeout |
| `connect_timeout_seconds` | 5 | Connection timeout |

### Retryable vs Non-Retryable Errors

**Retryable (will retry):**
- HTTP 500, 502, 503, 504 (Server errors)
- HTTP 0 (Network/Timeout errors)
- cURL connection errors
- DNS resolution failures

**Non-Retryable (fail immediately):**
- HTTP 400, 401, 403, 404 (Client errors)
- HTTP 422 (Validation errors)
- Invalid request format

### Usage Example

```php
// In API endpoint
$result = callExternalAPI('https://api.example.com/webhook', [
    'event' => 'token.created',
    'token_id' => $tokenId,
    'tenant_id' => $member['id_org']
]);

if (!$result['ok']) {
    json_error('External API call failed', 500, [
        'app_code' => $result['app_code'],
        'meta' => [
            'attempts' => $result['attempts'],
            'http_code' => $result['http_code'] ?? null
        ]
    ]);
}

// Use result
json_success(['external_response' => $result['data']]);
```

### Benefits

- ✅ **Reduces random failures** - Automatic retry for transient errors
- ✅ **Predictable retry behavior** - Exponential backoff prevents thundering herd
- ✅ **Comprehensive logging** - `[RETRY][Attempt:N]` tags for easy filtering
- ✅ **Configurable** - Adjustable attempts, delays, timeouts
- ✅ **Graceful degradation** - Non-retryable errors fail fast

---

## 🕐 Time/Zone Policy

**Purpose:** กำหนดนโยบายการจัดการเวลาและ timezone ให้สอดคล้องกันทั้งระบบ

### UTC Storage Policy

**Rule:** เก็บเวลาเป็น UTC เสมอใน database

**Implementation:**
```php
// Always use UTC for database
date_default_timezone_set('UTC');
$now = date('Y-m-d H:i:s'); // UTC

// Or explicitly:
$now = gmdate('Y-m-d H:i:s'); // UTC
```

### Response Time Format

**Include server time in responses:**
```json
{
  "ok": true,
  "data": {...},
  "meta": {
    "server_time": "2025-11-07T16:45:00Z",
    "timezone": "UTC"
  }
}
```

**Implementation:**
```php
json_success([
    'data' => $result,
    'meta' => [
        'server_time' => gmdate('c'), // ISO8601 UTC
        'timezone' => 'UTC'
    ]
]);
```

### Client-Side Conversion

**Frontend converts UTC → Asia/Bangkok:**
```javascript
const serverTime = new Date(response.meta.server_time);
const localTime = serverTime.toLocaleString('th-TH', {
    timeZone: 'Asia/Bangkok',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
});
```

**Benefits:**
- Prevents clock-skew issues
- Consistent timezone handling
- Easy debugging with server_time

---

## 📊 Executive Summary

| Metric | Current State | Target | Gap |
|--------|--------------|--------|-----|
| **Consistency Score** | 65% | 95% | ⚠️ **-30%** |
| **Error Handling** | 70% | 95% | ⚠️ **-25%** |
| **Documentation** | 40% | 90% | ⚠️ **-50%** |
| **Code Organization** | 75% | 95% | ⚠️ **-20%** |
| **Security Practices** | 85% | 95% | ⚠️ **-10%** |
| **Overall Enterprise Readiness** | **67%** | **95%** | ⚠️ **-28%** |

**Status:** ⚠️ **NEEDS IMPROVEMENT** - มีหลายจุดที่ต้องปรับปรุงเพื่อให้ถึงระดับ Enterprise

---

## 🔴 Critical Issues (Must Fix)

### 1. **Inconsistent Action Routing Pattern** 🔴 **HIGH PRIORITY**

**Problem:**
- บางไฟล์ใช้ `switch ($action)` (team_api.php, dag_routing_api.php, hatthasilpa_jobs_api.php)
- บางไฟล์ใช้ `if ($action === '...')` (assignment_api.php, token_management_api.php, pwa_scan_api.php)

**Impact:**
- Code readability ลดลง
- Maintenance ยากขึ้น
- ไม่มี default case handling

**Files Affected:**
- `assignment_api.php` - ใช้ `if` statements (15+ actions)
- `token_management_api.php` - ใช้ `if` statements (10+ actions)
- `pwa_scan_api.php` - ใช้ `if` statements (8+ actions)

**Recommendation:**
```php
// ✅ STANDARD PATTERN (ใช้ switch)
switch ($action) {
    case 'action_name':
        // Implementation
        break;
    default:
        json_error('Invalid action', 400);
}
```

---

### 2. **Inconsistent Error Response Format** 🔴 **HIGH PRIORITY**

**Problem:**
- บางไฟล์ใช้ `json_error()` (team_api.php, dag_routing_api.php)
- บางไฟล์ใช้ `http_response_code()` + `echo json_encode()` (assignment_api.php, pwa_scan_api.php)

**Impact:**
- Response format ไม่สม่ำเสมอ
- Frontend ต้อง handle หลายรูปแบบ
- Debugging ยากขึ้น

**Examples:**

❌ **BAD (Inconsistent):**
```php
// assignment_api.php
if (!$member) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'error' => 'unauthorized']);
    exit;
}

// pwa_scan_api.php
if (!$member) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'error' => 'unauthorized']);
    exit;
}
```

✅ **GOOD (Consistent):**
```php
// team_api.php
if (!$member) {
    json_error('unauthorized', 401);
}

// dag_routing_api.php
if (!$member) {
    json_error('unauthorized', 401);
}
```

**Recommendation:**
- ใช้ `json_error()` และ `json_success()` จาก `global_function.php` เป็นมาตรฐานเดียว
- ลบ manual `http_response_code()` + `echo json_encode()` ทั้งหมด

---

### 3. **Missing Top-Level Error Handling** 🟡 **MEDIUM PRIORITY**

**Problem:**
- บางไฟล์มี try-catch ครอบ switch ทั้งหมด (assignment_plan_api.php)
- บางไฟล์มี try-catch เฉพาะบาง action
- บางไฟล์ไม่มี try-catch เลย

**Impact:**
- Unhandled exceptions อาจ expose sensitive information
- Error logging ไม่ครบถ้วน
- Debugging ยากขึ้น

**Examples:**

✅ **GOOD (Has top-level try-catch):**
```php
// assignment_plan_api.php
try {
    switch ($action) {
        case 'action_name':
            // Implementation
            break;
    }
} catch (\Throwable $e) {
    error_log("Assignment Plan API error: " . $e->getMessage());
    json_error('Internal server error', 500);
}
```

❌ **BAD (No top-level try-catch):**
```php
// assignment_api.php
switch ($action) {
    case 'action_name':
        // Implementation - อาจ throw exception
        break;
}
// ไม่มี catch block!
```

**Recommendation:**
- เพิ่ม top-level try-catch ครอบ switch ทั้งหมดในทุก API file
- Log errors พร้อม context (action, user, timestamp)
- Return generic error message (ไม่ expose stack trace)

---

### 4. **Inconsistent Documentation** 🟡 **MEDIUM PRIORITY**

**Problem:**
- `dag_token_api.php` มี documentation ดีมาก (CRITICAL INVARIANTS, INTERNAL INVARIANTS)
- ไฟล์อื่นๆ มี documentation น้อยมากหรือไม่มีเลย

**Examples:**

✅ **EXCELLENT (dag_token_api.php):**
```php
/**
 * DAG Token Movement API
 * 
 * Purpose: Token lifecycle management (spawn, move, complete, scrap)
 * Created: November 2, 2025
 * Phase: DAG Phase 3 - Runtime Logic
 * 
 * ⚠️ CRITICAL INVARIANT:
 * flow_token.current_node_id references routing_node.id_node (NOT node_instance.id_node_instance)
 * 
 * INTERNAL INVARIANTS (Production Rules - DO NOT VIOLATE!)
 * 1. TOKEN LIFECYCLE: ...
 * 2. NODE REFERENCE RULE: ...
 * ...
 */
```

❌ **POOR (assignment_api.php):**
```php
/**
 * Token Assignment API
 * 
 * Purpose: Manager-Operator assignment workflow
 * - Manager assigns tokens to operators
 * - Operators view assigned work
 * - Track assignment lifecycle
 * 
 * @date November 4, 2025
 */
// ไม่มี CRITICAL INVARIANTS, ไม่มี INTERNAL RULES
```

**Recommendation:**
- เพิ่ม header documentation ในทุก API file:
  - Purpose & Endpoints
  - Critical Invariants (ถ้ามี)
  - Permission Requirements
  - Multi-tenant Notes
  - Version & Date

---

### 5. **Inconsistent Error Logging** 🟡 **MEDIUM PRIORITY**

**Problem:**
- บางไฟล์ log errors ดีมาก (pwa_scan_api.php, dag_token_api.php)
- บางไฟล์ log errors น้อยมากหรือไม่ log เลย

**Examples:**

✅ **GOOD (Detailed logging):**
```php
// pwa_scan_api.php
catch (Exception $e) {
    error_log('PWA v2 lookup error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['ok' => false, 'error' => $e->getMessage()]);
    exit;
}

// dag_token_api.php
catch (\Throwable $e) {
    error_log("DAG Token API Error ({$action}): " . $e->getMessage());
    json_error($e->getMessage(), 500);
}
```

❌ **BAD (No logging):**
```php
// บางไฟล์ไม่มี error_log() เลย
catch (\Exception $e) {
    json_error($e->getMessage(), 500);
    // ไม่มี error_log()!
}
```

**Recommendation:**
- Log errors พร้อม context:
  - API file name
  - Action name
  - User ID (ถ้า available)
  - Timestamp (auto)
  - Error message + stack trace (development mode only)

---

## 🟢 Good Practices (Keep These)

### 1. **PSR-4 Autoloading** ✅
- ทุกไฟล์ใช้ PSR-4 autoload แล้ว
- ใช้ `use` statements แทน manual `require_once`
- Clean และ maintainable

### 2. **Authentication Check** ✅
- ทุกไฟล์มี authentication check
- ใช้ `$objMemberDetail->thisLogin()` เป็นมาตรฐาน

### 3. **Permission Checks** ✅
- ใช้ `must_allow_code()` หรือ `permission_allow_code()` เป็นมาตรฐาน
- Permission checks ครบถ้วน

### 4. **Prepared Statements** ✅
- ใช้ prepared statements ทุกที่
- ป้องกัน SQL injection ได้ดี

### 5. **Multi-tenant Support** ✅
- ใช้ `tenant_db()` เป็นมาตรฐาน
- Filter by `id_org` ครบถ้วน

---

## 📋 Detailed File-by-File Assessment

### ✅ **EXCELLENT** (Ready for Enterprise)

| File | Score | Notes |
|------|-------|-------|
| `dag_token_api.php` | **95%** | ✅ Excellent documentation, ✅ Consistent error handling, ✅ Top-level try-catch, ✅ Detailed logging |
| `team_api.php` | **85%** | ✅ Uses switch, ✅ Uses json_error, ⚠️ Missing top-level try-catch, ⚠️ Documentation could be better |
| `dag_routing_api.php` | **85%** | ✅ Uses switch, ✅ Uses json_error, ⚠️ Missing top-level try-catch, ⚠️ Documentation could be better |

### ⚠️ **NEEDS IMPROVEMENT** (Not Enterprise Ready)

| File | Score | Issues |
|------|-------|--------|
| `assignment_api.php` | **60%** | ❌ Uses `if` instead of `switch`, ❌ Uses manual `http_response_code()`, ❌ No top-level try-catch, ⚠️ Documentation minimal |
| `token_management_api.php` | **60%** | ❌ Uses `if` instead of `switch`, ❌ Uses manual `http_response_code()`, ❌ No top-level try-catch, ⚠️ Documentation minimal |
| `pwa_scan_api.php` | **65%** | ❌ Uses `if` instead of `switch`, ❌ Uses manual `http_response_code()`, ✅ Has error logging, ⚠️ Documentation minimal |
| `assignment_plan_api.php` | **75%** | ✅ Uses switch, ✅ Uses json_error, ✅ Has top-level try-catch, ⚠️ Documentation could be better |
| `hatthasilpa_jobs_api.php` | **70%** | ✅ Uses switch, ⚠️ Uses manual `http_response_code()` in some places, ❌ No top-level try-catch, ⚠️ Documentation minimal |

---

## 🎯 Recommended Standard Template

```php
<?php
/**
 * [API Name] API
 * 
 * Purpose: [Brief description]
 * Endpoints: [List of endpoints]
 * 
 * ⚠️ CRITICAL INVARIANTS: [If applicable]
 * - [Rule 1]
 * - [Rule 2]
 * 
 * Permission: [Permission code(s)]
 * Multi-tenant: [Notes about tenant scoping]
 * 
 * @package Bellavier Group ERP
 * @version 1.2
 * @lifecycle runtime
 * @tenant_scope true
 * @permission dag.manage
 * @author Development Team
 * @since 2025-11-07
 * 
 * Lifecycle Tags:
 * - runtime: Called during normal operation (most APIs)
 * - admin: Called during admin/configuration (routing setup, etc.)
 * - async: Called asynchronously (background jobs, webhooks)
 * 
 * @lifecycle runtime
 * @lifecycle admin
 * @lifecycle async
 */

session_start();
require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/global_function.php';
require_once __DIR__ . '/model/member_class.php';
require_once __DIR__ . '/permission.php';

use BGERP\Service\SomeService;
use BGERP\Exception\SomeException;
use BGERP\Helper\RequestValidator;

header('Content-Type: application/json; charset=utf-8');

// Correlation ID & AI Trace
$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
header('X-Correlation-Id: ' . $cid);

// Authentication
$objMemberDetail = new memberDetail();
$member = $objMemberDetail->thisLogin();
if (!$member) {
    json_error('unauthorized', 401);
}

// Tenant DB
$tenantDb = tenant_db();

// Action routing
$action = $_REQUEST['action'] ?? '';

// AI Trace Metadata
$aiTrace = [
    'module' => basename(__FILE__, '.php'),
    'action' => $action,
    'tenant' => $member['id_org'] ?? 0,
    'user_id' => $member['id_member'] ?? 0,
    'timestamp' => gmdate('c'),
    'request_id' => $cid
];
header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));

// Top-level error handling
try {
    switch ($action) {
        
        case 'action_name':
            must_allow_code($member, 'permission.code');
            
            // Input validation using RequestValidator
            $validated = RequestValidator::make($_POST, [
                'id' => 'required|integer|min:1',
                'status' => 'required|string|in:active,inactive',
                'name' => 'nullable|string|max:255'
            ]);
            
            if (!$validated['valid']) {
                json_error('Validation failed', 400, [
                    'app_code' => $validated['app_code'] ?? 'CORE_400_05',
                    'validation_errors' => $validated['errors']
                ]);
            }
            
            // Use validated data
            $id = $validated['data']['id'];
            $status = $validated['data']['status'];
            
            // Business logic
            // ...
            
            json_success(['data' => $result]);
            break;
            
        default:
            json_error('Invalid action', 400);
    }
    
} catch (\Throwable $e) {
    // Standardized logging format
    $isDev = defined('APP_ENV') && APP_ENV === 'development';
    $logMessage = sprintf(
        "[%s][%s][User:%d][Action:%s] %s",
        date('Y-m-d H:i:s'),
        basename(__FILE__),
        $member['id_member'] ?? 0,
        $action ?? '-',
        $e->getMessage()
    );
    
    if ($isDev) {
        error_log($logMessage . "\nStack trace:\n" . $e->getTraceAsString());
    } else {
        error_log($logMessage);
    }
    
    json_error('Internal server error', 500);
}
```

---

## 📊 Migration Priority

### **Phase 1: Critical Consistency Fixes** ✅ **COMPLETE** (2025-11-08, 00:30 ICT)

**Status:** ✅ **COMPLETE**

**Completed Tasks:**
1. ✅ Convert `if ($action === '...')` → `switch ($action)` ใน:
   - `assignment_api.php` (9 actions)
   - `token_management_api.php` (11 actions)
   - `pwa_scan_api.php` (4 actions)

2. ✅ Replace manual `http_response_code()` + `echo json_encode()` → `json_error()` ใน:
   - `assignment_api.php` (2 locations)
   - `pwa_scan_api.php` (26 locations)
   - `hatthasilpa_jobs_api.php` (11 locations)

3. ✅ Add top-level try-catch ใน:
   - `assignment_api.php`
   - `token_management_api.php`
   - `hatthasilpa_jobs_api.php`
   - `team_api.php`
   - `dag_routing_api.php`

4. ✅ Add Correlation ID and AI Trace headers in all APIs

**Results:**
- ✅ 100% consistency in action routing
- ✅ 100% consistency in error responses
- ✅ 100% coverage of top-level error handling

---

### **Phase 2: Documentation Enhancement** ✅ **COMPLETE** (2025-11-08, 00:45 ICT)

**Status:** ✅ **COMPLETE**

**Completed Tasks:**
1. ✅ Add comprehensive header documentation ในทุก API file
2. ✅ Document critical invariants (ถ้ามี)
3. ✅ Document permission requirements
4. ✅ Document multi-tenant notes

**Files Updated:**
- `dag_routing_api.php` - Added full header documentation with CRITICAL INVARIANTS
- `team_api.php` - Added comprehensive documentation with permission requirements
- `assignment_plan_api.php` - Added documentation with CRITICAL INVARIANTS
- `dag_token_api.php` - Enhanced existing documentation

**Results:**
- ✅ 100% documentation coverage
- ✅ All critical invariants documented
- ✅ All permission requirements clearly stated

---

### **Phase 3: Error Logging Enhancement** ✅ **COMPLETE** (2025-11-08, 01:00 ICT)

**Status:** ✅ **COMPLETE**

**Completed Tasks:**
1. ✅ Standardize error logging format
2. ✅ Add context (API name, action, user ID)
3. ✅ Add stack trace (development mode only)

**Files Updated:**
- `assignment_plan_api.php` - Updated 3 nested catch blocks
- `dag_token_api.php` - Updated 4 function handlers + debug logs

**Results:**
- ✅ 100% standardized logging format
- ✅ All error logs include full context
- ✅ Stack traces only in development mode

---

### **Phase 4: Future Enhancements** (Optional)

**Note:** Phase 1-3 are complete. Future enhancements may include:
- Request Validation Layer (RequestValidator helper)
- API Capability Manifest updates
- Additional security hardening
- Performance optimizations

---

### **Phase 4-6: Remaining APIs Migration** ✅ **COMPLETE** (2025-11-08, 02:00 ICT)

**Status:** ✅ **COMPLETE**

**Scope:** Migrated 10 remaining API files to Enterprise standards

**Files Completed:**
- **Phase 4 (Production APIs - HIGH PRIORITY):**
  - ✅ `hatthasilpa_job_ticket.php` - Job ticket CRUD (100% compliance)
  - ✅ `mo.php` - Manufacturing Order operations (100% compliance)
  - ✅ `hatthasilpa_schedule.php` - Production scheduling (100% compliance)
- **Phase 5 (Platform Admin APIs - MEDIUM PRIORITY):**
  - ✅ `platform_tenant_owners_api.php` - Tenant owner management (100% compliance)
  - ✅ `platform_roles_api.php` - Platform role management (100% compliance)
  - ✅ `platform_dashboard_api.php` - Platform dashboard stats (100% compliance)
  - ✅ `platform_migration_api.php` - Migration management (100% compliance)
  - ✅ `platform_health_api.php` - Health check diagnostics (100% compliance)
- **Phase 6 (Tenant Management APIs - MEDIUM PRIORITY):**
  - ✅ `tenant_users_api.php` - Tenant user management (100% compliance)
  - ✅ `exceptions_api.php` - Production exceptions board (100% compliance)

**Results:** ✅ **ALL 18 APIs AT 100% COMPLIANCE**

---

## 📈 API Consistency Scorecard (Post-Fix Tracker)

**Purpose:** ติดตามความคืบหน้าของแต่ละ API file ว่าถึงเป้าหมายหรือยัง

### **Phase 1-3 Complete (8 APIs)** ✅

| API File | Routing | Error Format | Try-Catch | Doc | Log | Security | Score | Status |
|----------|---------|--------------|-----------|-----|-----|----------|-------|--------|
| `dag_token_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | ✅ **Excellent** |
| `team_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | ✅ **Excellent** |
| `dag_routing_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | ✅ **Excellent** |
| `assignment_plan_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | ✅ **Excellent** |
| `hatthasilpa_jobs_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | ✅ **Excellent** |
| `pwa_scan_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | ✅ **Excellent** |
| `assignment_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | ✅ **Excellent** |
| `token_management_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | ✅ **Excellent** |

### **Pending Migration (10 APIs)** ⚠️

| API File | Routing | Error Format | Try-Catch | Doc | Log | Score | Priority | Phase |
|----------|---------|--------------|-----------|-----|-----|-------|----------|-------|
| `hatthasilpa_job_ticket.php` | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | 🔴 High | Phase 4 ✅ |
| `mo.php` | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | 🔴 High | Phase 4 ✅ |
| `hatthasilpa_schedule.php` | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | 🔴 High | Phase 4 ✅ |
| `platform_tenant_owners_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | 🟡 Medium | Phase 5 ✅ |
| `platform_roles_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | 🟡 Medium | Phase 5 ✅ |
| `platform_dashboard_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | 🟡 Medium | Phase 5 ✅ |
| `platform_migration_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | 🟡 Medium | Phase 5 ✅ |
| `platform_health_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | 🟡 Medium | Phase 5 ✅ |
| `tenant_users_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | 🟡 Medium | Phase 6 ✅ |
| `exceptions_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | **100%** | 🟡 Medium | Phase 6 ✅ |

**Legend:**
- ✅ = Meets standard
- ⚠️ = Needs improvement
- ❌ = Missing

**Target:** All APIs ≥ 90% score  
**Current Status:** ✅ **18/18 APIs Complete (100%)** | ✅ **ALL APIs AT 100% COMPLIANCE**

---

## ✅ Success Criteria

**Enterprise Ready เมื่อ:**
- ✅ ทุกไฟล์ใช้ `switch ($action)` เป็นมาตรฐาน → **✅ 100% ACHIEVED** (18/18 APIs)
- ✅ ทุกไฟล์ใช้ `json_error()` / `json_success()` เป็นมาตรฐาน → **✅ 100% ACHIEVED** (18/18 APIs)
- ✅ ทุกไฟล์มี top-level try-catch → **✅ 100% ACHIEVED** (18/18 APIs)
- ✅ ทุกไฟล์มี comprehensive documentation → **✅ 100% ACHIEVED** (18/18 APIs)
- ✅ ทุกไฟล์มี consistent error logging (standardized format) → **✅ 100% ACHIEVED** (18/18 APIs)
- ✅ ทุกไฟล์ผ่าน Security Checklist → **✅ 100% ACHIEVED** (18/18 APIs)
- ✅ Consistency Score ≥ 95% → **✅ 100% ACHIEVED** (All APIs at 100%)
- ✅ Error Handling Score ≥ 95% → **✅ 100% ACHIEVED** (All APIs at 100%)
- ✅ Documentation Score ≥ 90% → **✅ 100% ACHIEVED** (All APIs at 100%)
- ✅ Security Score ≥ 95% → **✅ 100% ACHIEVED** (All APIs at 100%)

**Current Status:** ✅ **ALL CRITERIA MET** (November 8, 2025, 02:00 ICT)

**Compliance Test Results:**
- ✅ Overall Score: 198/198 (100%)
- ✅ All 18 APIs: 11/11 checks passed (100%)
- ✅ Syntax Check: All files valid
- ✅ Enterprise Standards: Fully compliant

---

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| **2.5** | 2025-11-08, 02:00 ICT | **Phase 4-6 Complete Edition** - Completed Phase 4 (Production APIs), Phase 5 (Platform Admin APIs), Phase 6 (Tenant Management APIs). All 18 APIs now at 100% compliance score. |
| **2.4** | 2025-11-08, 01:00 ICT | **Phase 1-3 Complete Edition** - Completed Phase 1 (Critical Consistency Fixes), Phase 2 (Documentation Enhancement), Phase 3 (Error Logging Enhancement). All 8 APIs now at 100% compliance score. |
| **2.3** | 2025-11-08, 00:05 ICT | **Fine-Tuned Excellence Edition** - Added Bellavier-Specific Namespace Policy, Unit Test Templates (RequestValidator & Retry Policy), Enhanced @lifecycle annotations, API Retirement Procedure, JSON Schema Registry |
| **2.2** | 2025-11-07, 23:58 ICT | **Operational Excellence Edition** - Added Request Validation Layer (Standardized), AI Trace Metadata, External API Retry Policy, API Capability Manifest, Lifecycle Tags in Header Doc Template |
| **2.1** | 2025-11-07, 23:55 ICT | **Enterprise Standard Edition** - Added API Versioning & Deprecation, Pagination/Filtering/Sorting, Idempotency & Concurrency Control, Correlation & Metrics, Error Code Taxonomy, Time/Zone Policy, Standard Headers, Testing Playbook, OpenAPI Specification, Enhanced Security (PII Redaction, File Upload Policy, Rate Limiting) |
| **2.0** | 2025-11-07, 23:45 ICT | **API Standard Edition** - Added API Structure Standard, Response Schema, Error Classification Matrix, Standardized Logging Format, Security Checklist, Consistency Scorecard |
| **1.0** | 2025-11-07, 23:30 ICT | Initial audit - Identified 5 critical issues, 3 phases of improvements |

---

## 🎯 Quick Reference for AI Agents

**When creating a new API file, follow this checklist:**

1. ✅ Use `switch ($action)` for routing
2. ✅ Wrap entire switch in top-level try-catch
3. ✅ Use `json_error()` / `json_success()` only
4. ✅ Use standardized logging format
5. ✅ Check authentication with `$objMemberDetail->thisLogin()`
6. ✅ Check permissions with `must_allow_code()`
7. ✅ Scope all queries by tenant (`tenant_db()`)
8. ✅ Use PSR-4 services for business logic
9. ✅ Add comprehensive header documentation
10. ✅ Follow Security Checklist

**Reference:** See [Recommended Standard Template](#-recommended-standard-template) for complete example.

---

## 📋 Standard Headers

**Purpose:** กำหนด standard headers ที่ทุก API ต้องใช้

| Header | Use When | Example | Required |
|--------|----------|--------|----------|
| `Content-Type` | Every response | `application/json; charset=utf-8` | ✅ Yes |
| `X-Correlation-Id` | Every request/response | `a1b2c3d4e5f6` | ✅ Yes |
| `Cache-Control` | Read-only listings | `private, max-age=30` | ⚠️ Optional |
| `Retry-After` | 429/503 errors | `60` (seconds) or `Wed, 21 Oct 2015 07:28:00 GMT` | ✅ Yes (when 429/503) |
| `Idempotency-Key` | POST/PUT create operations | `550e8400-e29b-41d4-a716-446655440000` (UUID v4) | ⚠️ Required for POST/PUT |
| `ETag` | Read operations (for concurrency) | `"v7"` | ⚠️ Recommended |
| `If-Match` | Update operations | `"v7"` | ⚠️ Recommended |
| `X-RateLimit-Limit` | Every response | `100` | ⚠️ Recommended |
| `X-RateLimit-Remaining` | Every response | `95` | ⚠️ Recommended |
| `X-RateLimit-Reset` | Every response | `1636329600` (timestamp) | ⚠️ Recommended |
| `Deprecation` | Deprecated endpoints | `true` | ✅ Yes (if deprecated) |
| `Sunset` | Deprecated endpoints | `2026-06-01T00:00:00+07:00` (ISO8601) | ✅ Yes (if deprecated) |
| `Link` | Deprecated endpoints | `</api/v2/new-endpoint>; rel="successor-version"` | ✅ Yes (if deprecated) |

### Header Implementation Example

```php
// Standard headers (always set)
header('Content-Type: application/json; charset=utf-8');

// Correlation ID
$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
header('X-Correlation-Id: ' . $cid);

// Cache control (for read-only endpoints)
if ($action === 'list' || $action === 'get') {
    header('Cache-Control: private, max-age=30');
}

// Rate limiting headers
header('X-RateLimit-Limit: ' . $rateLimitMax);
header('X-RateLimit-Remaining: ' . $remaining);
header('X-RateLimit-Reset: ' . $resetTime);

// ETag (for concurrency control)
if ($action === 'get') {
    $etag = sprintf('"%s"', hash('sha256', $row['version_hash'] ?? $row['updated_at']));
    header('ETag: ' . $etag);
}
```

---

## 🧪 Testing Playbook

**Purpose:** กำหนดมาตรฐานการทดสอบ API เพื่อให้มั่นใจว่า API ทำงานถูกต้องและปลอดภัย

| Test Type | Must Have | Tools | Purpose |
|-----------|-----------|-------|---------|
| **Contract** | ✅ Yes | Dredd / Schemathesis | Validate JSON shape, required fields |
| **Idempotency** | ✅ Yes | PHPUnit Integration | POST ซ้ำด้วย key เดิม → same response |
| **Concurrency** | ✅ Yes | k6 / artillery | ETag mismatch → 409 Conflict |
| **Rate-limit** | ✅ Yes | k6 / artillery | เกิน quota → 429 + Retry-After |
| **Security** | ✅ Yes | ZAP Baseline | SQLi/XSS basic probes |
| **Performance** | ⚠️ Optional | k6 / artillery | Response time < 200ms (p95) |

### Contract Testing Example

**OpenAPI Schema (YAML):**
```yaml
paths:
  /source/dag_token_api.php:
    post:
      parameters:
        - name: action
          in: query
          required: true
          schema:
            type: string
            enum: [token/spawn]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [ticket_id]
              properties:
                ticket_id:
                  type: integer
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: object
                required: [ok, data]
                properties:
                  ok:
                    type: boolean
                    enum: [true]
                  data:
                    type: object
```

**Dredd Test:**
```bash
dredd api.yaml http://localhost:8888 --language php
```

### Idempotency Test Example

```php
// tests/Integration/IdempotencyTest.php
public function testPostWithSameIdempotencyKeyReturnsSameResponse(): void
{
    $idempotencyKey = '550e8400-e29b-41d4-a716-446655440000';
    
    // First request
    $response1 = $this->callApi('POST', '/source/dag_token_api.php', [
        'action' => 'token/spawn',
        'ticket_id' => 123
    ], [
        'Idempotency-Key: ' . $idempotencyKey
    ]);
    
    // Second request (same key)
    $response2 = $this->callApi('POST', '/source/dag_token_api.php', [
        'action' => 'token/spawn',
        'ticket_id' => 123
    ], [
        'Idempotency-Key: ' . $idempotencyKey
    ]);
    
    // Should return same response
    $this->assertEquals($response1, $response2);
    $this->assertTrue(isset($response2['headers']['X-Idempotency-Replayed']));
}
```

### Concurrency Test Example (k6)

```javascript
import http from 'k6/http';
import { check } from 'k6';

export default function () {
    // Read operation
    let res = http.get('http://localhost:8888/source/dag_token_api.php?action=token/get&token_id=1');
    let etag = res.headers['ETag'];
    
    // Update with old ETag (should fail)
    res = http.put('http://localhost:8888/source/dag_token_api.php', JSON.stringify({
        action: 'token/update',
        token_id: 1,
        status: 'active'
    }), {
        headers: {
            'Content-Type': 'application/json',
            'If-Match': etag // Old ETag
        }
    });
    
    check(res, {
        'returns 409 Conflict': (r) => r.status === 409,
        'has app_code': (r) => JSON.parse(r.body).app_code === 'CORE_409_02'
    });
}
```

### Rate Limit Test Example

```javascript
import http from 'k6/http';
import { check } from 'k6';

export default function () {
    // Make 101 requests (limit is 100)
    for (let i = 0; i < 101; i++) {
        let res = http.get('http://localhost:8888/source/dag_token_api.php?action=token/list');
        
        if (i === 100) {
            check(res, {
                'returns 429 Too Many Requests': (r) => r.status === 429,
                'has Retry-After header': (r) => r.headers['Retry-After'] !== undefined
            });
        }
    }
}
```

### Security Test Example (ZAP Baseline)

```bash
# Run ZAP baseline scan
docker run -t owasp/zap2docker-stable zap-baseline.py \
    -t http://localhost:8888/bellavier-group-erp/source/dag_token_api.php \
    -J zap-report.json
```

**Expected:** No SQL injection or XSS vulnerabilities detected

---

## 🧪 Unit Test Templates

**Purpose:** ตัวอย่าง Unit Test สำหรับ RequestValidator และ Retry Policy เพื่อปิดวงจร "test-driven documentation"

### RequestValidator Unit Test

**File:** `tests/Unit/RequestValidatorTest.php`

```php
<?php
namespace BellavierGroup\Tests\Unit;

use PHPUnit\Framework\TestCase;
require_once __DIR__ . '/../../vendor/autoload.php';

use BGERP\Helper\RequestValidator;

class RequestValidatorTest extends TestCase
{
    public function testRequiredFieldValidation(): void
    {
        $data = ['name' => 'Test'];
        $rules = [
            'id' => 'required|integer',
            'name' => 'required|string'
        ];
        
        $result = RequestValidator::make($data, $rules);
        
        $this->assertFalse($result['valid']);
        $this->assertArrayHasKey('id', $result['errors']);
        $this->assertStringContainsString('required', $result['errors']['id'][0]);
    }
    
    public function testIntegerValidation(): void
    {
        $data = ['id' => '123'];
        $rules = ['id' => 'required|integer'];
        
        $result = RequestValidator::make($data, $rules);
        
        $this->assertTrue($result['valid']);
        $this->assertIsInt($result['data']['id']);
        $this->assertEquals(123, $result['data']['id']);
    }
    
    public function testMinMaxValidation(): void
    {
        $data = ['quantity' => 5];
        $rules = ['quantity' => 'required|integer|min:1|max:10'];
        
        $result = RequestValidator::make($data, $rules);
        
        $this->assertTrue($result['valid']);
        
        // Test min violation
        $data['quantity'] = 0;
        $result = RequestValidator::make($data, $rules);
        $this->assertFalse($result['valid']);
        
        // Test max violation
        $data['quantity'] = 11;
        $result = RequestValidator::make($data, $rules);
        $this->assertFalse($result['valid']);
    }
    
    public function testInValidation(): void
    {
        $data = ['status' => 'active'];
        $rules = ['status' => 'required|string|in:active,inactive,pending'];
        
        $result = RequestValidator::make($data, $rules);
        
        $this->assertTrue($result['valid']);
        
        // Test invalid value
        $data['status'] = 'invalid';
        $result = RequestValidator::make($data, $rules);
        $this->assertFalse($result['valid']);
        $this->assertStringContainsString('must be one of', $result['errors']['status'][0]);
    }
    
    public function testNullableField(): void
    {
        $data = ['name' => 'Test'];
        $rules = [
            'name' => 'required|string',
            'notes' => 'nullable|string|max:500'
        ];
        
        $result = RequestValidator::make($data, $rules);
        
        $this->assertTrue($result['valid']);
        $this->assertNull($result['data']['notes']);
    }
    
    public function testAppCodeGeneration(): void
    {
        $data = [];
        $rules = ['id' => 'required|integer'];
        
        $result = RequestValidator::make($data, $rules);
        
        $this->assertFalse($result['valid']);
        $this->assertEquals('CORE_400_05', $result['app_code']);
    }
}
```

### External API Retry Policy Unit Test

**File:** `tests/Unit/ExternalAPIRetryTest.php`

```php
<?php
namespace BellavierGroup\Tests\Unit;

use PHPUnit\Framework\TestCase;
require_once __DIR__ . '/../../vendor/autoload.php';

class ExternalAPIRetryTest extends TestCase
{
    private function mockCurlCall(int $httpCode, bool $shouldFail = false): array
    {
        // Mock implementation - in real test, use PHPUnit mocks
        if ($shouldFail) {
            throw new \Exception('cURL error: Connection timeout');
        }
        
        return [
            'ok' => $httpCode >= 200 && $httpCode < 300,
            'http_code' => $httpCode,
            'data' => ['status' => 'ok']
        ];
    }
    
    public function testRetryableErrorRetries(): void
    {
        $attempts = 0;
        $maxAttempts = 3;
        
        for ($attempt = 1; $attempt <= $maxAttempts; $attempt++) {
            $attempts++;
            $result = $this->mockCurlCall(500); // Retryable error
            
            if ($result['ok']) {
                break;
            }
            
            if ($attempt < $maxAttempts) {
                // Simulate exponential backoff
                usleep(200000 * $attempt);
                continue;
            }
        }
        
        $this->assertEquals($maxAttempts, $attempts);
        $this->assertFalse($result['ok']);
    }
    
    public function testNonRetryableErrorFailsImmediately(): void
    {
        $attempts = 0;
        $maxAttempts = 3;
        
        for ($attempt = 1; $attempt <= $maxAttempts; $attempt++) {
            $attempts++;
            $result = $this->mockCurlCall(400); // Non-retryable error
            
            // Non-retryable errors should break immediately
            if (!$result['ok'] && $result['http_code'] < 500) {
                break;
            }
        }
        
        $this->assertEquals(1, $attempts); // Should only attempt once
        $this->assertFalse($result['ok']);
    }
    
    public function testSuccessOnFirstAttempt(): void
    {
        $attempts = 0;
        $maxAttempts = 3;
        
        for ($attempt = 1; $attempt <= $maxAttempts; $attempt++) {
            $attempts++;
            $result = $this->mockCurlCall(200); // Success
            
            if ($result['ok']) {
                break;
            }
        }
        
        $this->assertEquals(1, $attempts);
        $this->assertTrue($result['ok']);
    }
    
    public function testExponentialBackoffDelay(): void
    {
        $delays = [];
        $maxAttempts = 3;
        
        for ($attempt = 1; $attempt <= $maxAttempts; $attempt++) {
            $start = microtime(true);
            usleep(200000 * $attempt); // Exponential backoff
            $end = microtime(true);
            $delays[] = ($end - $start) * 1000; // Convert to milliseconds
        }
        
        // Verify delays increase exponentially
        $this->assertGreaterThan($delays[0], $delays[1]);
        $this->assertGreaterThan($delays[1], $delays[2]);
    }
    
    public function testRetryLogging(): void
    {
        $cid = 'test-correlation-id';
        $attempt = 2;
        $maxAttempts = 3;
        $httpCode = 500;
        
        $logMessage = sprintf(
            "[CID:%s][RETRY][Attempt:%d/%d][RETRYABLE] HTTP %d, retrying",
            $cid,
            $attempt,
            $maxAttempts,
            $httpCode
        );
        
        $this->assertStringContainsString('[RETRY]', $logMessage);
        $this->assertStringContainsString('Attempt:2/3', $logMessage);
        $this->assertStringContainsString('HTTP 500', $logMessage);
    }
}
```

### Running Unit Tests

```bash
# Run RequestValidator tests
vendor/bin/phpunit tests/Unit/RequestValidatorTest.php

# Run Retry Policy tests
vendor/bin/phpunit tests/Unit/ExternalAPIRetryTest.php

# Run all unit tests
vendor/bin/phpunit tests/Unit/
```

### Benefits

- ✅ **Test-driven documentation** - Code examples are testable
- ✅ **CI/CD ready** - Tests can be automated
- ✅ **Regression prevention** - Catch breaking changes early
- ✅ **Learning resource** - New developers can learn from tests

---

## 📚 OpenAPI Specification (Contract First)

**Purpose:** ใช้ OpenAPI (YAML) เป็น source of truth สำหรับ API contracts

### Benefits

- ✅ Auto-generate API documentation
- ✅ Contract testing (Dredd/Schemathesis)
- ✅ Client SDK generation
- ✅ API versioning support

### Example Structure

**File:** `docs/openapi/api-v1.yaml`

```yaml
openapi: 3.0.3
info:
  title: Bellavier ERP API
  version: 1.0.0
  description: Multi-tenant Manufacturing & Atelier Management System

paths:
  /source/dag_token_api.php:
    post:
      summary: Spawn tokens for job
      parameters:
        - name: action
          in: query
          required: true
          schema:
            type: string
            enum: [token/spawn]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TokenSpawnRequest'
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TokenSpawnResponse'
        '400':
          description: Bad Request
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'

components:
  schemas:
    TokenSpawnRequest:
      type: object
      required: [ticket_id]
      properties:
        ticket_id:
          type: integer
          minimum: 1
    
    TokenSpawnResponse:
      type: object
      required: [ok, data]
      properties:
        ok:
          type: boolean
          enum: [true]
        data:
          type: object
          properties:
            tokens_created:
              type: integer
    
    ErrorResponse:
      type: object
      required: [ok, error, code]
      properties:
        ok:
          type: boolean
          enum: [false]
        error:
          type: string
        code:
          type: integer
        app_code:
          type: string
```

**Note:** OpenAPI specification is optional but highly recommended for Enterprise-grade APIs.

---

## 🗑️ API Retirement Procedure

**Purpose:** กำหนดมาตรฐานการเลิกใช้ API (Deprecation → Sunset → Removal) เพื่อใช้เป็นมาตรฐานระยะยาวสำหรับ Enterprise SLA

### Retirement Lifecycle

**Phase 1: Deprecation (Announcement)**
- Duration: 90 days minimum
- Actions:
  - Add `Deprecation: true` header
  - Add `Sunset: <ISO8601>` header (90+ days from deprecation)
  - Document in CHANGELOG.md
  - Notify stakeholders via email/announcement
  - Add deprecation warning in API response

**Phase 2: Sunset (Grace Period)**
- Duration: 90 days from deprecation
- Actions:
  - Continue serving requests (with warnings)
  - Monitor usage metrics
  - Send reminder notifications (30 days, 7 days before removal)
  - Provide migration guides and support

**Phase 3: Removal (Hard Cutoff)**
- Duration: Immediate after sunset period
- Actions:
  - Return `410 Gone` status code
  - Remove endpoint from API documentation
  - Archive code to `archive/` directory
  - Update `api_capabilities.json` manifest
  - Record removal in CHANGELOG.md

### Retirement Timeline Example

```
Day 0:   Deprecation announced
         - Headers: Deprecation: true, Sunset: 2026-02-01T00:00:00Z
         - CHANGELOG.md entry
         - Email notification sent

Day 30:  Reminder notification (60 days remaining)

Day 60:  Reminder notification (30 days remaining)

Day 83:  Final warning notification (7 days remaining)

Day 90:  Sunset period ends → Removal
         - Endpoint returns 410 Gone
         - Code archived
         - Manifest updated
```

### Implementation

**Deprecation Header:**
```php
// In deprecated endpoint
header('Deprecation: true');
header('Sunset: 2026-02-01T00:00:00Z');
header('Link: </api/v2/new-endpoint>; rel="successor-version"');

// In response meta
json_success([
    'data' => $result,
    'meta' => [
        'deprecated' => true,
        'sunset' => '2026-02-01T00:00:00Z',
        'migrate_to' => '/api/v2/new-endpoint',
        'days_remaining' => 45
    ]
]);
```

**Removal (410 Gone):**
```php
// After sunset period
if ($isRemoved) {
    json_error('deprecated', 410, [
        'app_code' => 'CORE_410_01',
        'meta' => [
            'removed' => true,
            'removed_at' => '2026-02-01T00:00:00Z',
            'migrate_to' => '/api/v2/new-endpoint',
            'changelog' => '/docs/CHANGELOG.md#2026-02-01'
        ]
    ]);
}
```

### CHANGELOG.md Entry Format

```markdown
## [2026-02-01] - API Retirement

### Removed
- **BREAKING:** `/source/old_api.php?action=old_endpoint` - Removed after 90-day deprecation period
  - Migration: Use `/api/v2/new-endpoint` instead
  - Deprecation announced: 2025-11-01
  - Sunset date: 2026-02-01

### Deprecated
- `/source/another_api.php?action=deprecated_action` - Will be removed on 2026-05-01
  - Migration: Use `/api/v2/new_action` instead
```

### Monitoring & Metrics

**Track during deprecation:**
- Request count per day
- Unique users/customers affected
- Error rate (if migration issues)
- Support tickets related to deprecation

**Decision Points:**
- If usage > 10% of total traffic → Extend sunset period
- If critical customers affected → Provide extended support
- If migration blockers found → Delay removal

### Benefits

- ✅ **Predictable lifecycle** - Clear timeline for stakeholders
- ✅ **Enterprise SLA compliance** - Standardized retirement process
- ✅ **Reduced breaking changes** - Graceful deprecation → removal
- ✅ **Better planning** - Teams can plan migrations in advance
- ✅ **Documentation** - Complete audit trail in CHANGELOG.md

---

## 📋 API Capability Manifest

**Purpose:** ให้ระบบอื่นหรือ AI Agent สามารถดึงข้อมูลความสามารถของ API ได้อัตโนมัติ เพื่อใช้ใน CI/CD Test, AI code generator, และ API sync

### Manifest File

**Location:** `docs/api_capabilities.json`

**Format:**
```json
{
  "version": "1.0",
  "generated_at": "2025-11-07T23:55:00Z",
  "apis": {
    "team_api": {
      "file": "source/team_api.php",
      "version": "1.1",
      "lifecycle": "runtime",
      "actions": [
        "team/list",
        "team/create",
        "team/update",
        "team/delete",
        "team/get",
        "member/add",
        "member/remove",
        "member/set_role",
        "people_monitor_list",
        "available_operators"
      ],
      "requires": ["auth", "tenant_scope"],
      "permissions": ["team.manage"],
      "idempotency_required": ["team/create", "member/add"],
      "supports_pagination": true,
      "supports_filtering": true,
      "rate_limit": 100
    },
    "dag_token_api": {
      "file": "source/dag_token_api.php",
      "version": "1.2",
      "lifecycle": "runtime",
      "actions": [
        "token/spawn",
        "token/move",
        "token/complete",
        "token/scrap",
        "token/status",
        "token/list"
      ],
      "requires": ["auth", "tenant_scope", "idempotency_key"],
      "permissions": ["dag.manage"],
      "idempotency_required": ["token/spawn", "token/move"],
      "supports_pagination": true,
      "supports_filtering": false,
      "rate_limit": 200
    },
    "assignment_api": {
      "file": "source/assignment_api.php",
      "version": "1.0",
      "lifecycle": "runtime",
      "actions": [
        "assign_token",
        "bulk_assign",
        "unassign_token"
      ],
      "requires": ["auth", "tenant_scope"],
      "permissions": ["assignment.manage"],
      "idempotency_required": ["assign_token", "bulk_assign"],
      "supports_pagination": false,
      "supports_filtering": false,
      "rate_limit": 150
    },
    "assignment_plan_api": {
      "file": "source/assignment_plan_api.php",
      "version": "1.0",
      "lifecycle": "runtime",
      "actions": [
        "plan/create",
        "plan/update",
        "plan/delete",
        "plan/list",
        "plan/get",
        "plan/preview",
        "plan_nodes_options",
        "list_candidates"
      ],
      "requires": ["auth", "tenant_scope"],
      "permissions": ["assignment.plan.manage"],
      "idempotency_required": ["plan/create"],
      "supports_pagination": true,
      "supports_filtering": true,
      "rate_limit": 100
    },
    "dag_routing_api": {
      "file": "source/dag_routing_api.php",
      "version": "1.0",
      "lifecycle": "admin",
      "actions": [
        "graph/create",
        "graph/update",
        "graph/delete",
        "graph/list",
        "node/create",
        "node/update",
        "node/delete",
        "edge/create",
        "edge/delete"
      ],
      "requires": ["auth", "tenant_scope"],
      "permissions": ["dag.routing.manage"],
      "idempotency_required": [],
      "supports_pagination": true,
      "supports_filtering": true,
      "rate_limit": 50
    },
    "pwa_scan_api": {
      "file": "source/pwa_scan_api.php",
      "version": "1.0",
      "lifecycle": "runtime",
      "actions": [
        "scan/quick",
        "scan/detail"
      ],
      "requires": ["auth", "tenant_scope"],
      "permissions": ["pwa.scan"],
      "idempotency_required": [],
      "supports_pagination": false,
      "supports_filtering": false,
      "rate_limit": 300
    }
  }
}
```

### Capability Endpoint (Optional)

**Endpoint:** `/source/capabilities_api.php?action=manifest`

**Response:**
```json
{
  "ok": true,
  "data": {
    "version": "1.0",
    "generated_at": "2025-11-07T23:55:00Z",
    "apis": {...}
  }
}
```

### Usage Scenarios

1. **CI/CD Test Generation:**
   ```bash
   # Generate tests from manifest
   php tools/generate-tests-from-manifest.php docs/api_capabilities.json
   ```

2. **AI Code Generator:**
   ```php
   // AI Agent reads manifest to understand API capabilities
   $manifest = json_decode(file_get_contents('docs/api_capabilities.json'), true);
   $api = $manifest['apis']['team_api'];
   // AI knows: requires auth, supports pagination, needs idempotency for create
   ```

3. **OpenAPI Schema Generation:**
   ```bash
   # Auto-generate OpenAPI schema from manifest
   php tools/generate-openapi-from-manifest.php docs/api_capabilities.json
   ```

4. **API Documentation:**
   ```bash
   # Generate API docs from manifest
   php tools/generate-docs-from-manifest.php docs/api_capabilities.json
   ```

### Benefits

- ✅ **CI/CD Test Automation** - Auto-generate tests from manifest
- ✅ **AI Code Generator** - AI understands API capabilities automatically
- ✅ **API Sync** - Future API gateway can sync capabilities
- ✅ **Auto-Documentation** - Generate docs from manifest
- ✅ **OpenAPI Generation** - Partial OpenAPI schema from manifest

---

## 📐 JSON Schema Registry

**Purpose:** เก็บ JSON Schema สำหรับแต่ละ module เพื่อใช้กับ OpenAPI auto-generation และ Contract Testing

### Schema Directory Structure

```
docs/
├── schemas/
│   ├── common/
│   │   ├── error_response.json
│   │   ├── success_response.json
│   │   └── pagination_meta.json
│   ├── dag/
│   │   ├── token_spawn_request.json
│   │   ├── token_spawn_response.json
│   │   ├── token_move_request.json
│   │   └── token_status_response.json
│   ├── team/
│   │   ├── team_create_request.json
│   │   ├── team_create_response.json
│   │   └── team_list_response.json
│   ├── assignment/
│   │   ├── assign_token_request.json
│   │   └── assign_token_response.json
│   └── pwa/
│       ├── scan_quick_request.json
│       └── scan_quick_response.json
```

### Schema File Format

**Example:** `docs/schemas/dag/token_spawn_request.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Token Spawn Request",
  "description": "Request schema for spawning DAG tokens",
  "type": "object",
  "required": ["ticket_id"],
  "properties": {
    "ticket_id": {
      "type": "integer",
      "minimum": 1,
      "description": "Job ticket ID"
    },
    "quantity": {
      "type": "integer",
      "minimum": 1,
      "maximum": 1000,
      "default": 1,
      "description": "Number of tokens to spawn"
    },
    "priority": {
      "type": "string",
      "enum": ["low", "normal", "high", "urgent"],
      "default": "normal",
      "description": "Token priority"
    }
  }
}
```

**Example:** `docs/schemas/common/error_response.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Error Response",
  "description": "Standard error response format",
  "type": "object",
  "required": ["ok", "error", "code"],
  "properties": {
    "ok": {
      "type": "boolean",
      "const": false
    },
    "error": {
      "type": "string",
      "description": "Error message"
    },
    "code": {
      "type": "integer",
      "description": "HTTP status code"
    },
    "app_code": {
      "type": "string",
      "pattern": "^[A-Z_]+_\\d{3}_\\d{2}$",
      "description": "Application-specific error code"
    },
    "meta": {
      "type": "object",
      "properties": {
        "timestamp": {
          "type": "string",
          "format": "date-time"
        },
        "file": {
          "type": "string"
        },
        "action": {
          "type": "string"
        }
      }
    }
  }
}
```

### Schema Usage

**1. OpenAPI Generation:**
```bash
# Generate OpenAPI spec from schemas
php tools/generate-openapi-from-schemas.php docs/schemas/ > docs/openapi/api-v1.yaml
```

**2. Contract Testing (Schemathesis):**
```bash
# Validate API responses against schemas
schemathesis run docs/openapi/api-v1.yaml \
  --base-url http://localhost:8888 \
  --checks all
```

**3. AI Agent Integration:**
```php
// AI Agent reads schema to understand request/response format
$schema = json_decode(file_get_contents('docs/schemas/dag/token_spawn_request.json'), true);
// AI knows: ticket_id is required integer, quantity is optional with default 1
```

**4. Frontend Type Generation:**
```bash
# Generate TypeScript types from schemas
json-schema-to-typescript docs/schemas/dag/token_spawn_request.json > frontend/types/token.ts
```

### Schema Maintenance

**When to update schemas:**
- ✅ New API endpoint created
- ✅ Request/response format changed
- ✅ New fields added/removed
- ✅ Validation rules updated

**Schema versioning:**
- Use `$id` field for versioning: `"$id": "https://api.bellavier.com/schemas/dag/token_spawn_request/v1.0"`
- Update version in `$id` when breaking changes occur
- Keep old versions in `schemas/archive/` directory

### Benefits

- ✅ **OpenAPI auto-generation** - Generate complete OpenAPI specs from schemas
- ✅ **Contract testing** - Validate API contracts automatically
- ✅ **AI Agent ready** - AI can understand API structure from schemas
- ✅ **Type safety** - Generate TypeScript/PHP types from schemas
- ✅ **Documentation** - Self-documenting API structure
- ✅ **Version control** - Track schema changes in Git

### Schema Registry Index

**File:** `docs/schemas/index.json`

```json
{
  "version": "1.0",
  "updated_at": "2025-11-07T23:58:00Z",
  "schemas": {
    "common": {
      "error_response": "common/error_response.json",
      "success_response": "common/success_response.json",
      "pagination_meta": "common/pagination_meta.json"
    },
    "dag": {
      "token_spawn_request": "dag/token_spawn_request.json",
      "token_spawn_response": "dag/token_spawn_response.json",
      "token_move_request": "dag/token_move_request.json"
    },
    "team": {
      "team_create_request": "team/team_create_request.json",
      "team_create_response": "team/team_create_response.json"
    }
  }
}
```

---

**Reference:** See [Recommended Standard Template](#-recommended-standard-template) for complete example.

---

**Remember:** Consistency is key to Enterprise-grade code. Small improvements compound into significant quality gains! 💎

