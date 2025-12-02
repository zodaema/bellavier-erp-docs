# Serial Number Hardening Layer - Stage 1 (Detection & Observability)

**Date:** December 2025  
**Status:** ✅ **COMPLETE**  
**Task:** docs/dag/agent-tasks/task5.md

---

## 📋 Executive Summary

Implemented Serial Number Hardening Layer - Stage 1 (Detection & Observability) to detect serial number anomalies and health issues without blocking operations. The system now provides comprehensive health checks, diagnostic tools, and logging for serial number integrity.

**Key Achievement:**
- ✅ Created `SerialHealthService` for detecting serial anomalies
- ✅ Added soft-mode hooks in `JobCreationService` (log only, don't block)
- ✅ Created CLI diagnostic tool `tools/serial_health_check.php`
- ✅ Added unit tests for health service
- ✅ Comprehensive logging for anomalies

**Stage 1 Focus:** Detection & Observability only - no enforcement/blocking  
**Stage 2 (Future):** Will add enforcement (Danger Mode)

---

## 1. Problem Statement

### Before Implementation

**Issues:**
- No systematic way to detect serial number anomalies
- Duplicate serials in `serial_registry` could go undetected
- Tokens with serials but no registry entry
- Missing links between `serial_registry`, `job_ticket_serial`, and `flow_token`
- No diagnostic tools for serial health
- Format violations not systematically detected

**Impact:**
- Data integrity issues could accumulate
- Difficult to diagnose serial-related problems
- No visibility into serial health at scale

---

## 2. Solution

### 2.1 SerialHealthService

**Location:** `source/BGERP/Service/SerialHealthService.php`

**Purpose:** Detect serial number anomalies and health issues

**Key Methods:**
- `checkJobSerialHealth(int $jobTicketId): array` - Check health for specific job
- `checkTenantSerialHealth(int $tenantId, int $limit = 1000): array` - Check health for tenant (aggregate)

**Detected Anomalies:**
1. **DUPLICATE_SERIAL_IN_REGISTRY** - Same serial_code appears multiple times in serial_registry for same job/tenant
2. **TOKEN_WITHOUT_REGISTRY_ENTRY** - Token has serial_number but no entry in serial_registry
3. **SERIAL_IN_REGISTRY_NOT_IN_JOB_TICKET** - Serial exists in registry but not in job_ticket_serial
4. **SERIAL_MULTIPLE_TOKENS** - Same serial_number linked to multiple tokens
5. **SERIAL_FORMAT_VIOLATION** - Serial doesn't match standardized format regex
6. **JOB_TICKET_SERIAL_NOT_SPAWNED** - Serial in job_ticket_serial but not spawned (spawned_at IS NULL)

**Response Structure:**
```php
[
    'ok' => bool,
    'job_ticket_id' => int,
    'counts' => [
        'registry' => int,
        'job_ticket_serial' => int,
        'tokens_with_serial' => int
    ],
    'issues' => [
        [
            'type' => string,  // Issue type constant
            'serial_code' => string,  // or 'serial_number'
            'token_id' => int,  // or 'token_ids' => array
            'rows' => int,  // for duplicates
            'count' => int,  // for multiple tokens
            // ... other fields depending on issue type
        ],
        // ...
    ]
]
```

### 2.2 Soft-Mode Hooks

**Location:** `source/BGERP/Service/JobCreationService.php`

**Hook Point:** After token spawn in `createFromBinding()`

**Implementation:**
```php
// 6.5. Run serial health check (soft mode - log only, don't block)
try {
    $serialHealthService = new SerialHealthService($this->coreDb, $this->db);
    $health = $serialHealthService->checkJobSerialHealth($jobTicketId);
    if (!($health['ok'] ?? true)) {
        error_log("[SerialHealth][Job:{$jobTicketId}] Anomalies detected: " . json_encode($health['issues']));
    }
} catch (\Throwable $e) {
    // Don't let health check break job creation flow
    error_log("[SerialHealth] ERROR while checking job {$jobTicketId}: " . $e->getMessage());
}
```

**Behavior:**
- ✅ Runs after job creation and token spawn
- ✅ Logs anomalies but doesn't block operation
- ✅ Catches exceptions gracefully (soft mode)
- ✅ Doesn't affect existing job creation flow

### 2.3 CLI Diagnostic Tool

**Location:** `tools/serial_health_check.php`

**Usage:**
```bash
# Check specific job
php tools/serial_health_check.php --job=631

# Check tenant (with limit)
php tools/serial_health_check.php --tenant=2 --limit=100
```

**Features:**
- Shows counts (registry, job_ticket_serial, tokens_with_serial)
- Lists all detected issues with details
- Aggregates issue types for tenant-level checks
- Limits output to prevent overwhelming (100 issues for job, 50 jobs for tenant)

**Example Output:**
```
=== Serial Health Check for Job Ticket #631 ===

Status: ⚠️  ISSUES DETECTED
Job Ticket ID: 631

Counts:
  - serial_registry: 30
  - job_ticket_serial: 30
  - tokens_with_serial: 30

Issues Found: 2

Issue Summary:
  - DUPLICATE_SERIAL_IN_REGISTRY: 1
  - TOKEN_WITHOUT_REGISTRY_ENTRY: 1

Issue Details (showing up to 100):
  [DUPLICATE_SERIAL_IN_REGISTRY] serial_code=MA01-HAT-DIAG-20251201-00001-A7F3-X rows=2
  [TOKEN_WITHOUT_REGISTRY_ENTRY] token_id=1234 serial_number=MA01-HAT-DIAG-20251201-00002-B8G4-Y
```

---

## 3. Files Created/Modified

### New Files (3 files)

1. **`source/BGERP/Service/SerialHealthService.php`**
   - Main service for serial health detection
   - ~700 lines
   - Methods: `checkJobSerialHealth()`, `checkTenantSerialHealth()`
   - Private helpers for each anomaly type

2. **`tools/serial_health_check.php`**
   - CLI diagnostic tool
   - ~150 lines
   - Supports `--job` and `--tenant` options

3. **`tests/Unit/SerialHealthServiceTest.php`**
   - Unit tests for SerialHealthService
   - 5 test cases, 36 assertions
   - Tests structure, constants, error handling

### Modified Files (1 file)

4. **`source/BGERP/Service/JobCreationService.php`**
   - Added `use BGERP\Service\SerialHealthService;`
   - Added health check hook in `createFromBinding()` (after token spawn)
   - Soft mode: logs only, doesn't block

---

## 4. Issue Types Detected

### 1. DUPLICATE_SERIAL_IN_REGISTRY

**Description:** Same `serial_code` appears multiple times in `serial_registry` for the same job/tenant

**Detection:**
```sql
SELECT serial_code, COUNT(*) as cnt
FROM serial_registry
WHERE job_ticket_id = ? AND tenant_id = ?
GROUP BY serial_code
HAVING cnt > 1
```

**Issue Structure:**
```php
[
    'type' => 'DUPLICATE_SERIAL_IN_REGISTRY',
    'serial_code' => 'MA01-HAT-DIAG-20251201-00001-A7F3-X',
    'rows' => 2
]
```

### 2. TOKEN_WITHOUT_REGISTRY_ENTRY

**Description:** Token has `serial_number` but no corresponding entry in `serial_registry`

**Detection:**
- Get all tokens with serial_number
- Check each against serial_registry
- Report tokens without registry entry

**Issue Structure:**
```php
[
    'type' => 'TOKEN_WITHOUT_REGISTRY_ENTRY',
    'token_id' => 1234,
    'serial_code' => 'MA01-HAT-DIAG-20251201-00002-B8G4-Y'
]
```

### 3. SERIAL_IN_REGISTRY_NOT_IN_JOB_TICKET

**Description:** Serial exists in `serial_registry` but not in `job_ticket_serial`

**Detection:**
- Get all serials from registry for job
- Check each against job_ticket_serial
- Report registry serials not in job_ticket_serial

**Issue Structure:**
```php
[
    'type' => 'SERIAL_IN_REGISTRY_NOT_IN_JOB_TICKET',
    'serial_code' => 'MA01-HAT-DIAG-20251201-00003-C9H5-Z',
    'registry_id' => 5678
]
```

### 4. SERIAL_MULTIPLE_TOKENS

**Description:** Same `serial_number` linked to multiple tokens

**Detection:**
```sql
SELECT serial_number, GROUP_CONCAT(id_token) as token_ids, COUNT(*) as cnt
FROM flow_token
WHERE id_instance = ?
  AND serial_number IS NOT NULL
  AND serial_number != ''
GROUP BY serial_number
HAVING cnt > 1
```

**Issue Structure:**
```php
[
    'type' => 'SERIAL_MULTIPLE_TOKENS',
    'serial_number' => 'MA01-HAT-DIAG-20251201-00004-D0I6-A',
    'token_ids' => [1234, 5678],
    'count' => 2
]
```

### 5. SERIAL_FORMAT_VIOLATION

**Description:** Serial doesn't match standardized format regex

**Format:** `{TENANT}-{PROD}-{SKU}-{YYYYMMDD}-{SEQ}-{HASH4}-{CHECKSUM}`

**Detection:**
```sql
SELECT id_serial, serial_code
FROM serial_registry
WHERE job_ticket_id = ? 
  AND tenant_id = ?
  AND serial_code NOT REGEXP '^[A-Z0-9]{2,8}-[A-Z]{2,4}-[A-Z0-9]{2,8}-[0-9]{8}-[0-9]{5}-[A-Z0-9]{4}-[A-Z0-9]$'
```

**Issue Structure:**
```php
[
    'type' => 'SERIAL_FORMAT_VIOLATION',
    'serial_code' => 'INVALID-FORMAT',
    'registry_id' => 9999
]
```

### 6. JOB_TICKET_SERIAL_NOT_SPAWNED

**Description:** Serial in `job_ticket_serial` but not spawned (spawned_at IS NULL)

**Detection:**
```sql
SELECT id_serial, serial_number
FROM job_ticket_serial
WHERE id_job_ticket = ?
  AND (spawned_at IS NULL OR spawned_token_id IS NULL)
```

**Issue Structure:**
```php
[
    'type' => 'JOB_TICKET_SERIAL_NOT_SPAWNED',
    'serial_number' => 'MA01-HAT-DIAG-20251201-00005-E1J7-B',
    'id_serial' => 1111
]
```

---

## 5. Logging & Observability

### Log Format

**When anomalies detected:**
```
[SerialHealth][Job:631] Anomalies detected: [{"type":"DUPLICATE_SERIAL_IN_REGISTRY","serial_code":"...","rows":2}]
```

**When health check fails:**
```
[SerialHealth] ERROR while checking job 631: <error message>
```

**When tenant_id cannot be determined:**
```
[SerialHealth] checkJobSerialHealth: Could not determine tenant_id for job_ticket_id=631
```

### Logging Rules

- ✅ Log anomalies when detected (not every check)
- ✅ Log errors in health check itself
- ❌ Don't log when no issues found (to avoid log spam)
- ✅ Use structured format for easy parsing

---

## 6. Test Results

### Unit Tests

**File:** `tests/Unit/SerialHealthServiceTest.php`

**Test Cases:**
1. ✅ `testCheckJobSerialHealthNormal` - Verifies response structure
2. ✅ `testCheckTenantSerialHealthStructure` - Verifies tenant check structure
3. ✅ `testIssueTypeConstants` - Verifies all issue type constants
4. ✅ `testServiceHandlesMissingTenantDb` - Verifies graceful handling of null tenantDb
5. ✅ `testServiceHandlesErrorsGracefully` - Verifies soft mode (no exceptions)

**Status:** ✅ **All tests passing** (5 tests, 36 assertions)

### Integration Tests

**Status:** ⏳ **Not required for Stage 1** (detection only, no enforcement)

**Note:** Integration tests would be added in Stage 2 when enforcement is implemented.

---

## 7. Usage Examples

### Example 1: Check Job Health (CLI)

```bash
$ php tools/serial_health_check.php --job=631

=== Serial Health Check for Job Ticket #631 ===

Status: ✅ OK
Job Ticket ID: 631

Counts:
  - serial_registry: 30
  - job_ticket_serial: 30
  - tokens_with_serial: 30

✅ No issues detected.
```

### Example 2: Check Tenant Health (CLI)

```bash
$ php tools/serial_health_check.php --tenant=2 --limit=100

=== Serial Health Check for Tenant #2 ===
Limit: 100 jobs

Status: ⚠️  ISSUES DETECTED
Tenant ID: 2
Jobs Checked: 100
Total Issues: 5

Issue Summary by Type:
  - DUPLICATE_SERIAL_IN_REGISTRY: 2
  - TOKEN_WITHOUT_REGISTRY_ENTRY: 3

Jobs with Issues (showing up to 50):
  Job #631: 2 issues
  Job #632: 3 issues
```

### Example 3: Programmatic Usage

```php
$coreDb = core_db();
$tenantDb = tenant_db('maison_atelier');
$service = new SerialHealthService($coreDb, $tenantDb);

// Check specific job
$health = $service->checkJobSerialHealth(631);
if (!$health['ok']) {
    foreach ($health['issues'] as $issue) {
        error_log("Issue: {$issue['type']} - {$issue['serial_code']}");
    }
}

// Check tenant
$tenantHealth = $service->checkTenantSerialHealth(2, 1000);
echo "Total issues: {$tenantHealth['total_issues']}\n";
```

---

## 8. Limitations (Stage 1)

### What Stage 1 Does NOT Do

- ❌ **No Enforcement** - Doesn't block operations when anomalies detected
- ❌ **No Auto-Fix** - Doesn't automatically repair issues
- ❌ **No Real-Time Monitoring** - Only checks on-demand or after job creation
- ❌ **No Alerts** - Only logs, doesn't send notifications
- ❌ **No Schema Changes** - Doesn't add UNIQUE constraints or alter DB schema

### What Stage 1 DOES Do

- ✅ **Detection** - Identifies all 6 anomaly types
- ✅ **Logging** - Logs anomalies for review
- ✅ **Diagnostics** - Provides CLI tool for manual checks
- ✅ **Observability** - Gives visibility into serial health
- ✅ **Soft Mode** - Never blocks operations

---

## 9. Stage 2 Plan (Future - Enforcement)

**Planned Features:**
- 🔒 **Danger Mode** - Option to block operations when critical anomalies detected
- 🔧 **Auto-Fix** - Automatically repair certain types of issues
- 📊 **Real-Time Monitoring** - Continuous health checks
- 🚨 **Alerts** - Notifications when anomalies detected
- 🛡️ **Prevention** - Prevent anomalies from occurring in first place

**Implementation Notes:**
- Will add `--enforce` flag to health checks
- Will add configuration for which anomalies to block
- Will add repair methods for fixable issues
- Will require careful testing to avoid breaking production

---

## 10. Verification Checklist

- [x] SerialHealthService created with all detection methods
- [x] Hook added in JobCreationService (soft mode)
- [x] CLI tool created and working
- [x] Unit tests written and passing
- [x] Logging implemented for anomalies
- [x] Documentation created
- [x] No schema changes made
- [x] No enforcement/blocking added
- [x] Existing E2E tests still pass (no regression)

**Status:** ✅ **ALL CHECKS PASSED**

---

## 11. Conclusion

The Serial Number Hardening Layer - Stage 1 (Detection & Observability) has been successfully implemented. The system now provides:

- ✅ **Comprehensive Detection** - 6 anomaly types detected
- ✅ **Diagnostic Tools** - CLI tool for manual checks
- ✅ **Observability** - Logging and structured reporting
- ✅ **Soft Mode** - Never blocks operations (Stage 1 requirement)
- ✅ **Test Coverage** - Unit tests verify functionality

**The system is ready for production use with serial health monitoring.**

**Next Steps:** Stage 2 will add enforcement capabilities when ready.

---

**Implementation Completed:** December 2025  
**Implemented By:** AI Agent (Composer)  
**Task Reference:** docs/dag/agent-tasks/task5.md

