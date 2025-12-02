# DAG Task 5: Serial Number Hardening Layer (Stage 1)

**Task ID:** DAG-5  
**Status:** ✅ **COMPLETED** (December 2025)  
**Scope:** Serial / Health Detection  
**Type:** Implementation Task

---

## 1. Context

### Problem

No systematic way to detect serial number anomalies in production:
- Duplicate serials in `serial_registry` could go undetected
- Tokens with serials but no registry entry
- Missing links between `serial_registry`, `job_ticket_serial`, and `flow_token`
- No diagnostic tools for serial health
- Format violations not systematically detected

### Impact

- Data integrity issues could accumulate
- Difficult to diagnose serial-related problems
- No visibility into serial health at scale
- Production could proceed with corrupted serial data

---

## 2. Objective

Implement Serial Number Hardening Layer - Stage 1 (Detection & Observability) that:
- Detects serial number anomalies without blocking operations
- Provides comprehensive health checks and diagnostic tools
- Logs anomalies for review
- Supports CLI tool for manual checks
- **Stage 1 Focus:** Detection & Observability only - no enforcement/blocking  
**Stage 2 (Future):** Will add enforcement (Danger Mode) - See [TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md](TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md)

---

## 3. Scope

### Files Created

**New Service:**
- `source/BGERP/Service/SerialHealthService.php` - Main service for serial health detection (~700 lines)
  - Methods: `checkJobSerialHealth()`, `checkTenantSerialHealth()`
  - Private helpers for each anomaly type

**CLI Tool:**
- `tools/serial_health_check.php` - CLI diagnostic tool (~150 lines)
  - Supports `--job` and `--tenant` options

**Test Files:**
- `tests/Unit/SerialHealthServiceTest.php` - Unit tests (5 test cases, 36 assertions)

### Files Modified

- `source/BGERP/Service/JobCreationService.php`
  - Added: Soft-mode hook in `createFromBinding()` (after token spawn)
  - Behavior: Logs anomalies but doesn't block operation

### Database Tables Used

- `serial_registry` - Serial master data
- `job_ticket_serial` - Job-level serial tracking
- `flow_token` - Token-level serial tracking

---

## 4. Implementation Summary

### SerialHealthService

**Purpose:** Detect serial number anomalies and health issues

**Key Methods:**
- `checkJobSerialHealth(int $jobTicketId): array` - Check health for specific job
- `checkTenantSerialHealth(int $tenantId, int $limit = 1000): array` - Check health for tenant (aggregate)

**Detected Anomalies (6 types):**

1. **DUPLICATE_SERIAL_IN_REGISTRY** - Same `serial_code` appears multiple times in `serial_registry` for same job/tenant
2. **TOKEN_WITHOUT_REGISTRY_ENTRY** - Token has `serial_number` but no entry in `serial_registry`
3. **SERIAL_IN_REGISTRY_NOT_IN_JOB_TICKET** - Serial exists in registry but not in `job_ticket_serial`
4. **SERIAL_MULTIPLE_TOKENS** - Same `serial_number` linked to multiple tokens
5. **SERIAL_FORMAT_VIOLATION** - Serial doesn't match standardized format regex
6. **JOB_TICKET_SERIAL_NOT_SPAWNED** - Serial in `job_ticket_serial` but not spawned (spawned_at IS NULL)

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
            'serial_code' => string,
            'token_id' => int,
            // ... other fields depending on issue type
        ],
        // ...
    ]
]
```

### Soft-Mode Hooks

**Location:** `source/BGERP/Service/JobCreationService.php`  
**Hook Point:** After token spawn in `createFromBinding()`

**Behavior:**
- ✅ Runs after job creation and token spawn
- ✅ Logs anomalies but doesn't block operation
- ✅ Catches exceptions gracefully (soft mode)
- ✅ Doesn't affect existing job creation flow

### CLI Diagnostic Tool

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

---

## 5. Guardrails

### Must Not Regress

- ✅ **Soft mode only** - Never blocks operations (Stage 1 requirement)
- ✅ **No schema changes** - Doesn't add UNIQUE constraints or alter DB schema
- ✅ **Fail-open behavior** - Exceptions don't break job creation flow
- ✅ **Existing serial logic** - Doesn't change serial generation or validation

### Limitations (Stage 1)

**What Stage 1 Does NOT Do:**
- ❌ **No Enforcement** - Doesn't block operations when anomalies detected
- ❌ **No Auto-Fix** - Doesn't automatically repair issues
- ❌ **No Real-Time Monitoring** - Only checks on-demand or after job creation
- ❌ **No Alerts** - Only logs, doesn't send notifications

**What Stage 1 DOES Do:**
- ✅ **Detection** - Identifies all 6 anomaly types
- ✅ **Logging** - Logs anomalies for review
- ✅ **Diagnostics** - Provides CLI tool for manual checks
- ✅ **Observability** - Gives visibility into serial health

---

## 6. Status

**Status:** ✅ **COMPLETED** (December 2025)

**Implementation:**
- ✅ SerialHealthService created with all detection methods
- ✅ Hook added in JobCreationService (soft mode)
- ✅ CLI tool created and working
- ✅ Unit tests written and passing (5 tests, 36 assertions)
- ✅ Logging implemented for anomalies
- ✅ Documentation created

**Related Tasks:**
- ✅ Task 8: Serial Enforcement Stage 2 Gate (December 2025) - Added enforcement layer
  - See [TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md](TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md)
- ✅ Task 9: Tenant Resolution & Integration Test Hardening (December 2025) - Improved tenant resolution
  - See [TASK_DAG_9_TENANT_RESOLUTION.md](TASK_DAG_9_TENANT_RESOLUTION.md)

**Documentation:**
- ✅ Implementation summary: `docs/dag/agent-tasks/task5_SERIAL_HARDENING.md`

---

## 7. Related Documentation

- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Serial tracking section
- [TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md](TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md) - Stage 2 enforcement
- [task5_SERIAL_HARDENING.md](../agent-tasks/task5_SERIAL_HARDENING.md) - Detailed implementation summary

---

**Task Completed:** December 2025  
**Status:** Stage 1 Complete (Detection & Observability)  
**Next Steps:** Stage 2 adds enforcement capabilities - See Task DAG-8

