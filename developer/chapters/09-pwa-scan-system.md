# Chapter 9 — PWA Scan System

**Last Updated:** November 19, 2025  
**Purpose:** Document the PWA scan system architecture, issues, and migration plan  
**Audience:** Developers working on PWA/scanning features, AI agents planning refactors

---

## Overview

The PWA (Progressive Web App) scan system provides mobile/scanning workflows for operators. The current implementation has known architecture issues and is planned for refactoring in a future task.

**Key Components:**
- `pwa_scan_api.php` - Main scanning API (Classic Line only)
- Barcode scanning logic
- Device workflow (Scan → Resolve → Action)
- **⚠️ Note:** PWA is Classic Line only. Hatthasilpa uses Work Queue (`worker_token_api.php`), not PWA.

**Known Issues:**
- ⚠️ Duplicate `db_fetch_all` function (function redeclaration)
- ⚠️ Legacy structure (not using bootstrap layers)
- ⚠️ Mixed patterns (old and new code)
- ⚠️ Needs migration to bootstrap system

**Status:**
- ⚠️ **Legacy System** - Not migrated to bootstrap layers
- ⚠️ **Refactor Planned** - Future task will migrate to bootstrap
- ✅ **Working** - Currently functional but needs modernization
- ✅ **Classic Line Only** - PWA scanners are for Classic job tickets only
- ❌ **Not for Hatthasilpa** - Hatthasilpa uses Work Queue system instead

---

## Key Concepts

### 1. PWA Scan Architecture

**Current Architecture:**
```
Mobile Device
    ↓
Scan Barcode/QR Code
    ↓
pwa_scan_api.php
    ├── Resolve barcode/QR
    ├── Determine action
    └── Execute action
    ↓
Response (JSON)
    ├── Success: Action result
    └── Error: Error message
```

**Workflow:**
1. **Scan** - Operator scans barcode/QR code
2. **Resolve** - System resolves code to entity (token, job, product, etc.)
3. **Action** - System executes appropriate action
4. **Response** - System returns result

### 2. Barcode Scanning Logic

**Supported Codes:**
- Token codes (TOTE-001, TOTE-002, etc.)
- Job ticket codes
- Product codes
- Material codes
- Serial numbers

**Resolution:**
- Lookup in database
- Determine entity type
- Return entity information

### 3. Device Workflow

**Scan → Resolve → Action (Classic Line Only):**
```
1. Scan barcode
   ↓
2. Resolve to entity
   ├── Job Ticket → Classic job operations
   ├── Material → Material lookup
   └── Component → Component lookup
   ↓
3. Execute action
   ├── Start work (wip_log event)
   ├── Complete work (wip_log event)
   ├── View job details
   └── Update job status
   ↓
4. Return result
```

**⚠️ Important:**
- PWA is **Classic Line only** - Simple scan in/out for job tickets
- **Hatthasilpa does NOT use PWA** - Uses Work Queue (`worker_token_api.php`) instead
- PWA does NOT handle token operations (Hatthasilpa only)

---

## Core Components

### pwa_scan_api.php

**Location:** `source/pwa_scan_api.php`  
**Status:** ⚠️ Legacy (not migrated to bootstrap)

**Purpose:**
Main API endpoint for PWA scanning operations.

**Known Issues:**

1. **Function Redeclaration:**
   ```php
   // ❌ Problem: db_fetch_all() declared multiple times
   // Causes: "Cannot redeclare db_fetch_all()" fatal error
   ```

2. **No Bootstrap:**
   ```php
   // ❌ Problem: Not using TenantApiBootstrap or CoreApiBootstrap
   // Should use: [$org, $tenantDb, $member] = TenantApiBootstrap::init();
   ```

3. **Legacy Patterns:**
   ```php
   // ❌ Problem: Mixed old and new patterns
   // Should standardize to bootstrap + TenantApiOutput
   ```

**Current Structure:**
```php
<?php
// Legacy structure (not using bootstrap)
session_start();
require_once __DIR__ . '/config.php';
// ... manual setup ...
```

**Should Be:**
```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';
[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();
// ... standardized structure ...
```

### Architecture Issues

#### 1. Duplicate db_fetch_all

**Problem:**
- `db_fetch_all()` function declared in multiple files
- Causes fatal error: "Cannot redeclare db_fetch_all()"

**Solution:**
- Move to global helper
- Use PSR-4 class method
- Remove duplicate declarations

#### 2. Legacy Structure

**Problem:**
- Not using bootstrap layers
- Manual session handling
- Manual database connections
- Inconsistent error handling

**Solution:**
- Migrate to `TenantApiBootstrap`
- Use `TenantApiOutput` for JSON
- Standardize error handling
- Add rate limiting

#### 3. Mixed Patterns

**Problem:**
- Old and new code patterns mixed
- Inconsistent error responses
- No standardized logging

**Solution:**
- Standardize to bootstrap patterns
- Use `TenantApiOutput` for all responses
- Add structured logging

---

## Migration Plan (Future Task)

### Phase 1: Fix Function Redeclaration

**Steps:**
1. Identify all `db_fetch_all()` declarations
2. Move to global helper or PSR-4 class
3. Update all callers
4. Remove duplicate declarations

**Expected Outcome:**
- No function redeclaration errors
- Single source of truth for `db_fetch_all()`

### Phase 2: Migrate to Bootstrap

**Steps:**
1. Replace manual setup with `TenantApiBootstrap::init()`
2. Use returned values (`$org`, `$tenantDb`, `$member`)
3. Remove manual session handling
4. Remove manual database connections

**Expected Outcome:**
- Consistent with other APIs
- Automatic tenant resolution
- Built-in security

### Phase 3: Standardize Output

**Steps:**
1. Replace manual JSON output with `TenantApiOutput`
2. Use `TenantApiOutput::success()` for success
3. Use `TenantApiOutput::error()` for errors
4. Add `TenantApiOutput::startOutputBuffer()`

**Expected Outcome:**
- Standardized JSON format
- No whitespace/BOM issues
- Consistent error responses

### Phase 4: Add Security

**Steps:**
1. Add rate limiting
2. Add CSRF protection (state-changing operations)
3. Add permission checks
4. Add input validation

**Expected Outcome:**
- Secure API endpoint
- Protected against abuse
- Proper authorization

### Phase 5: Add Tests

**Steps:**
1. Add integration tests
2. Add system-wide tests
3. Add security tests
4. Test all scan workflows

**Expected Outcome:**
- Comprehensive test coverage
- Regression prevention
- Quality assurance

---

## Recommended Refactor Plan

### Step 1: Create PSR-4 Helper

**File:** `source/BGERP/Helper/DatabaseHelper.php`

**Purpose:**
Centralize database helper functions.

**Methods:**
```php
class DatabaseHelper
{
    public static function fetchAll($db, $sql, $params = []): array
    {
        // Implementation
    }
    
    public static function fetchOne($db, $sql, $params = []): ?array
    {
        // Implementation
    }
}
```

### Step 2: Update pwa_scan_api.php

**Before:**
```php
<?php
session_start();
require_once __DIR__ . '/config.php';
// Manual setup
function db_fetch_all($db, $sql, $params = []) { ... }
```

**After:**
```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

use BGERP\Http\TenantApiOutput;
TenantApiOutput::startOutputBuffer();

use BGERP\Helper\RateLimiter;
RateLimiter::check($member['id_member'], 'pwa_scan', 'scan', 120, 60);

use BGERP\Helper\DatabaseHelper;
// Use DatabaseHelper::fetchAll() instead of db_fetch_all()
```

### Step 3: Standardize Actions

**Structure:**
```php
$action = $_REQUEST['action'] ?? '';

try {
    switch ($action) {
        case 'scan':
            // Resolve barcode
            // Execute action
            TenantApiOutput::success($result);
            break;
            
        default:
            TenantApiOutput::error('invalid_action', 400);
    }
} catch (\Throwable $e) {
    error_log("Error: " . $e->getMessage());
    TenantApiOutput::error('internal_error', 500);
}
```

---

## Barcode Scanning Logic

### Supported Barcode Types

**Token Codes:**
- Format: `TOTE-001`, `TOTE-002`, etc.
- Resolves to: `flow_token` table
- Actions: Start, pause, resume, complete, route

**Job Ticket Codes:**
- Format: `JOB-2025-001`, etc.
- Resolves to: `atelier_job_ticket` table
- Actions: View details, update status

**Product Codes:**
- Format: Product SKU
- Resolves to: `products` table
- Actions: View details, update inventory

**Material Codes:**
- Format: Material code
- Resolves to: `materials` table
- Actions: View details, update stock

**Serial Numbers:**
- Format: Serial number
- Resolves to: Serial tracking table
- Actions: View history, update status

### Resolution Logic

**Step 1: Try Token Code**
```php
$token = lookupToken($code);
if ($token) {
    return ['type' => 'token', 'entity' => $token];
}
```

**Step 2: Try Job Ticket**
```php
$job = lookupJobTicket($code);
if ($job) {
    return ['type' => 'job', 'entity' => $job];
}
```

**Step 3: Try Product**
```php
$product = lookupProduct($code);
if ($product) {
    return ['type' => 'product', 'entity' => $product];
}
```

**Step 4: Try Material**
```php
$material = lookupMaterial($code);
if ($material) {
    return ['type' => 'material', 'entity' => $material];
}
```

**Step 5: Error**
```php
return ['type' => 'unknown', 'error' => 'Code not found'];
```

---

## Device Workflow

### Scan Workflow

**1. Scan Barcode:**
```
Mobile Device → Scan → Send to API
```

**2. Resolve Code:**
```
API → Lookup → Determine Entity Type
```

**3. Execute Action:**
```
API → Action Logic → Update Database
```

**4. Return Result:**
```
API → JSON Response → Mobile Device
```

### Action Types

**Token Actions:**
- `start` - Start work on token
- `pause` - Pause work
- `resume` - Resume work
- `complete` - Complete work
- `route` - Route to next node

**Job Actions:**
- `view` - View job details
- `update` - Update job status

**Product/Material Actions:**
- `view` - View details
- `update` - Update inventory

---

## Examples

### Example 1: Scan Token Code

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

use BGERP\Http\TenantApiOutput;
TenantApiOutput::startOutputBuffer();

$code = $_POST['code'] ?? '';

// Resolve code
$token = lookupToken($tenantDb, $code);
if (!$token) {
    TenantApiOutput::error('token_not_found', 404);
    return;
}

// Return token info
TenantApiOutput::success(['token' => $token]);
```

### Example 2: Start Work on Token

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

use BGERP\Http\TenantApiOutput;
TenantApiOutput::startOutputBuffer();

$tokenId = (int)($_POST['token_id'] ?? 0);

// Get token
$token = getToken($tenantDb, $tokenId);
if (!$token) {
    TenantApiOutput::error('token_not_found', 404);
    return;
}

// Start work
$tenantDb->begin_transaction();
try {
    // Create node instance
    $stmt = $tenantDb->prepare("INSERT INTO node_instance (token_id, node_id, operator_id, started_at) VALUES (?, ?, ?, NOW())");
    $stmt->bind_param('iii', $tokenId, $token['current_node_id'], $member['id_member']);
    $stmt->execute();
    
    // Create token event
    $stmt = $tenantDb->prepare("INSERT INTO token_event (token_id, event_type, node_id, operator_id, event_time) VALUES (?, 'start', ?, ?, NOW())");
    $stmt->bind_param('iii', $tokenId, $token['current_node_id'], $member['id_member']);
    $stmt->execute();
    
    // Update token status
    $stmt = $tenantDb->prepare("UPDATE flow_token SET status='in_progress' WHERE id=?");
    $stmt->bind_param('i', $tokenId);
    $stmt->execute();
    
    $tenantDb->commit();
    TenantApiOutput::success(['token_id' => $tokenId, 'status' => 'in_progress']);
} catch (\Throwable $e) {
    $tenantDb->rollback();
    error_log("Error: " . $e->getMessage());
    TenantApiOutput::error('internal_error', 500);
}
```

---

## Reference Documents

### PWA Documentation

- **pwa_scan_api.php**: `source/pwa_scan_api.php` - Main scanning API (legacy)
- **Work Queue**: `assets/javascripts/pwa_scan/work_queue.js` - Frontend work queue

### Related Chapters

- **Chapter 6**: API Development Guide
- **Chapter 8**: Traceability / Token System
- **Chapter 14**: PWA/Frontend Integration

---

## Future Expansion

### Planned Enhancements

1. **Bootstrap Migration**
   - Migrate to `TenantApiBootstrap`
   - Use `TenantApiOutput`
   - Add rate limiting and CSRF

2. **Enhanced Scanning**
   - QR code support
   - Batch scanning
   - Offline scanning

3. **Real-Time Updates**
   - WebSocket integration
   - Live status updates
   - Push notifications

4. **Advanced Features**
   - Image recognition
   - Voice commands
   - Augmented reality

---

**Previous Chapter:** [Chapter 8 — Traceability / Token System](../chapters/08-traceability-token-system.md)  
**Next Chapter:** [Chapter 10 — Testing Framework](../chapters/10-testing-framework.md)

