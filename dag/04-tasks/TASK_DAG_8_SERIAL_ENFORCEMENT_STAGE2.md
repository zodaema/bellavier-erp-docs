# DAG Task 8: Serial Enforcement Stage 2 Gate

**Task ID:** DAG-8  
**Status:** ✅ **COMPLETED** (December 2025)  
**Scope:** Serial / Enforcement  
**Type:** Implementation Task

---

## 1. Context

### Problem

Serial health detection (Stage 1) was working but only logging anomalies:
- No enforcement mechanism to block production when critical issues detected
- System would continue creating jobs/spawning tokens even with duplicate serials or format violations
- Production could proceed with corrupted serial data

### Impact

- Data integrity issues could accumulate in production
- No way to prevent corrupted serial data from entering system
- Stage 1 detection was "informational only" with no blocking capability

---

## 2. Objective

Implement Serial Enforcement Stage 2 Gate that:
- Maps issues to severity (BLOCKER vs WARNING)
- Evaluates gates with phase support (`pre_start`, `in_production`)
- Enforces blockers when feature flag enabled
- Controlled by feature flag `FF_SERIAL_ENFORCE_STAGE2` for safety
- Fail-open behavior (never blocks on exceptions)

---

## 3. Scope

### Files Changed

**PHP Service Files:**
- `source/BGERP/Service/SerialHealthService.php`
  - Added: `getIssueSeverity()` - Maps issue type to severity
  - Added: `evaluateGateForJob()` - Gate evaluation with phase support
  - Added: `mapIssueTypeToCode()` - Maps to canonical error codes
  - Added: `getIssueMessage()` - Human-readable messages

- `source/BGERP/Service/JobCreationService.php`
  - Added: Enforcement hook in `createFromBinding()` (pre_start phase)

- `source/dag_token_api.php`
  - Added: Enforcement hook in `handleTokenSpawn()` (in_production phase)

**Test Files:**
- `tests/Unit/SerialHealthServiceTest.php` - Extended with 3 new tests
- `tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php` - New integration tests (2 tests)

### Database Tables Used

- `serial_registry` - Serial master data
- `job_ticket_serial` - Job-level serial tracking
- `flow_token` - Token-level serial tracking

---

## 4. Implementation Summary

### Severity Mapping

**BLOCKER Issues (Critical - Block Production):**
- `ISSUE_SERIAL_MULTIPLE_TOKENS` → `SERIAL_DUPLICATE_TOKEN`
- `ISSUE_DUPLICATE_SERIAL_IN_REGISTRY` → `SERIAL_DUPLICATE_REGISTRY`
- `ISSUE_SERIAL_FORMAT_VIOLATION` → `SERIAL_FORMAT_INVALID`
- `ISSUE_TOKEN_WITHOUT_REGISTRY_ENTRY` → `SERIAL_NOT_IN_REGISTRY`

**WARNING Issues (Non-Critical - Log Only):**
- `ISSUE_SERIAL_IN_REGISTRY_NOT_IN_JOB_TICKET` → `SERIAL_UNUSED`
- `ISSUE_JOB_TICKET_SERIAL_NOT_SPAWNED` → `SERIAL_NOT_FULLY_SPAWNED`

### Gate Evaluation Method

**Location:** `source/BGERP/Service/SerialHealthService.php`  
**Method:** `public function evaluateGateForJob(int $jobTicketId, string $phase): array`

**Return Structure:**
```php
[
    'has_blocker' => bool,
    'has_warning' => bool,
    'issues' => [
        [
            'type' => string,        // Original issue type constant
            'severity' => string,     // 'BLOCKER' or 'WARNING'
            'code' => string,         // Canonical error code
            'message' => string,      // Human-readable message
            // ... other issue-specific fields
        ]
    ]
]
```

**Behavior:**
- Calls `checkJobSerialHealth()` to get issues
- Maps each issue to severity (BLOCKER/WARNING)
- Adds canonical error codes and messages
- Returns structured result for enforcement decision

### Enforcement Hooks

**Hook 1: Job Creation (pre_start phase)**
- Location: `source/BGERP/Service/JobCreationService.php` - `createFromBinding()`
- Behavior: Blocks job creation when flag=1 and blockers detected
- Response: Returns error response (ok=false, error='ERR_SERIAL_HEALTH_BLOCKED')

**Hook 2: Token Spawn (in_production phase)**
- Location: `source/dag_token_api.php` - `handleTokenSpawn()`
- Behavior: Blocks token spawn when flag=1 and blockers detected
- Response: Rollback transaction, return error (ok=false, error='ERR_SERIAL_HEALTH_BLOCKED')

### Feature Flag Integration

**Feature Flag:** `FF_SERIAL_ENFORCE_STAGE2`

**Values:**
- `0` (default) - Detection only (log issues, don't block)
- `1` - Enforce BLOCKER (block production when blockers detected)

**Fail-Open Rules:**
- If flag not found → `enforceEnabled = false` (don't block)
- If flag check throws exception → `enforceEnabled = false` (don't block)
- If `SerialHealthService` throws exception → don't block (fail-open)

---

## 5. Guardrails

### Must Not Regress

- ✅ **Stage 1 detection unchanged** - Detection logic remains the same
- ✅ **Fail-open behavior** - Never blocks on exceptions or flag check failures
- ✅ **WARNING issues never block** - Only BLOCKER issues can block production
- ✅ **No schema changes** - Database schema unchanged

### Test Coverage

**Unit Tests:**
- `testIssueSeverityMapping()` - Verifies severity mapping
- `testEvaluateGateForJobNoIssues()` - Verifies gate with no issues
- `testEvaluateGateForJobStructure()` - Verifies gate result structure

**Integration Tests:**
- `testEnforcementFlagZeroDoesNotBlock()` - Case A: flag=0, should not block
- `testEnforcementFlagOneBlocksOnBlocker()` - Case B: flag=1, should detect blocker

**Test Files:**
- `tests/Unit/SerialHealthServiceTest.php`
- `tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php`

---

## 6. Status

**Status:** ✅ **COMPLETED** (December 2025)

**Implementation:**
- ✅ Severity mapping implemented (BLOCKER vs WARNING)
- ✅ Gate evaluation method (`evaluateGateForJob()`) created
- ✅ Enforcement hook in JobCreationService (pre_start phase)
- ✅ Enforcement hook in dag_token_api.php (in_production phase)
- ✅ Feature flag integration (`FF_SERIAL_ENFORCE_STAGE2`)
- ✅ Fail-open behavior (never blocks on exception)
- ✅ Error response contract (ok=false, error='ERR_SERIAL_HEALTH_BLOCKED', issues=[])
- ✅ Unit tests for severity mapping and gate evaluation
- ✅ Integration tests for flag=0 and flag=1 scenarios
- ✅ No regression in existing tests

**Related Tasks:**
- ✅ Task 5: Serial Number Hardening Layer (Stage 1) (December 2025) - Detection layer
  - See [TASK_DAG_5_SERIAL_HARDENING.md](TASK_DAG_5_SERIAL_HARDENING.md)
- ✅ Task 9: Tenant Resolution & Integration Test Hardening (December 2025) - Improved tenant resolution
  - See [TASK_DAG_9_TENANT_RESOLUTION.md](TASK_DAG_9_TENANT_RESOLUTION.md)

**Documentation:**
- ✅ Implementation summary: `docs/dag/agent-tasks/task8_SERIAL_ENFORCEMENT_STAGE2.md`

---

## 7. Related Documentation

- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Serial tracking section
- [TASK_DAG_5_SERIAL_HARDENING.md](TASK_DAG_5_SERIAL_HARDENING.md) - Stage 1 detection
- [TASK_DAG_9_TENANT_RESOLUTION.md](TASK_DAG_9_TENANT_RESOLUTION.md) - Tenant resolution improvements
- [task8_SERIAL_ENFORCEMENT_STAGE2.md](../agent-tasks/task8_SERIAL_ENFORCEMENT_STAGE2.md) - Detailed implementation summary

---

**Task Completed:** December 2025  
**Status:** Stage 2 Complete (Enforcement Gate)  
**Dependencies:** Stage 1 (Task DAG-5) must be complete

