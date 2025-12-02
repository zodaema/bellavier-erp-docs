# DAG Task 9: Tenant Resolution & Integration Test Hardening

**Task ID:** DAG-9  
**Status:** ✅ **COMPLETED** (December 2025)  
**Scope:** Serial / Testing  
**Type:** Implementation Task

---

## 1. Context

### Problem

1. **Noisy Logs:** "Could not determine tenant_id for job_ticket_id=..." appeared even when tenantDb was already provided
2. **Test Skipping:** `testEnforcementFlagZeroDoesNotBlock()` had to be skipped because health check couldn't detect anomalies without tenant_id
3. **Unclear Behavior:** System behavior was unclear when tenant_id couldn't be resolved

### Root Cause

- SerialHealthService always tried to resolve tenant_id from `job_ticket.id_org`
- When tenantDb was already provided, it should use direct-tenant mode (extract org_code from database name)
- Integration tests couldn't create reliable BLOCKER anomalies

### Impact

- Serial Enforcement Stage 2 tests couldn't run reliably
- Logs were noisy even in normal operation
- System behavior unclear in different contexts (prod, CLI, PHPUnit)

---

## 2. Objective

Improve SerialHealthService tenant resolution strategy and harden integration tests:
- Works reliably in all contexts (production, CLI, PHPUnit) without noisy tenant_id resolution logs
- Deterministic integration tests (both flag=0 and flag=1 pass)
- Tenant-local checks work even when tenant_id cannot be resolved
- No regression in Task 8 enforcement logic

---

## 3. Scope

### Files Changed

**PHP Service Files:**
- `source/BGERP/Service/SerialHealthService.php`
  - Added: `resolveTenantIdForJob()` - Improved tenant resolution
  - Added: `getDatabaseName()` - Get DB name from connection
  - Added: `extractOrgCodeFromDbName()` - Extract org_code from DB name
  - Added: `getTenantIdFromOrgCode()` - Look up tenant_id from org_code
  - Added: `checkJobSerialHealthTenantLocalOnly()` - Tenant-local only checks
  - Modified: `checkJobSerialHealth()` - Uses improved tenant resolution

**Test Files:**
- `tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php`
  - Added: `seedDuplicateSerialAnomaly()` - Deterministic BLOCKER anomaly creation
  - Modified: Test setup to update `graph_instance_id`
  - Removed: Skipping from `testEnforcementFlagZeroDoesNotBlock()`

---

## 4. Implementation Summary

### Improved Tenant Resolution Strategy

**Strategy 1: Direct-Tenant Mode (when tenantDb is provided)**
- Extract org_code from database name (e.g., `bgerp_t_maison_atelier` → `maison_atelier`)
- Look up tenant_id from `organization` table in core DB
- Fallback to `job_ticket.id_org` if column exists

**Strategy 2: Tenant-Aware Mode (when tenantDb is null)**
- Try to get tenant_id from `job_ticket.id_org`
- (Not used in current implementation - kept for future)

### Tenant-Local Only Mode

**New Method:** `checkJobSerialHealthTenantLocalOnly()`

**Behavior:**
- When tenant_id cannot be resolved, fall back to tenant-local checks only
- Checks `job_ticket_serial` and `flow_token` tables (tenant-local)
- Detects `ISSUE_SERIAL_MULTIPLE_TOKENS` (doesn't require tenant_id)
- Detects `ISSUE_JOB_TICKET_SERIAL_NOT_SPAWNED` (tenant-local)
- Skips `serial_registry` checks (requires tenant_id)

### Improved Logging

**Before:**
```
[SerialHealth] checkJobSerialHealth: Could not determine tenant_id for job_ticket_id=123
```

**After:**
- No log in normal path (when tenant_id is resolved successfully)
- Soft log in development mode only: `[SerialHealth] checkJobSerialHealth: Using direct-tenant mode (tenant_id not resolved)`
- Clear indication that this is fail-open by design, not an error

### Deterministic Integration Tests

**New Helper:** `seedDuplicateSerialAnomaly()`
- Creates 2 tokens with the same `serial_number` (BLOCKER: `ISSUE_SERIAL_MULTIPLE_TOKENS`)
- Works at tenant-local level (doesn't require tenant_id)
- Deterministic and reliable

**Fixed Test Setup:**
- Update `job_ticket.graph_instance_id` after creating `job_graph_instance`
- Ensures `getInstanceIdFromJobTicket()` works correctly
- Proper cleanup order (tokens → instance → job_ticket → graph)

**Removed Skipping:**
- `testEnforcementFlagZeroDoesNotBlock()` now passes
- `testEnforcementFlagOneBlocksOnBlocker()` still passes
- Both tests verify BLOCKER detection correctly

---

## 5. Guardrails

### Must Not Regress

- ✅ **Task 8 enforcement logic unchanged** - Enforcement behavior unchanged
- ✅ **Public method signatures unchanged** - No breaking changes
- ✅ **No database schema changes** - Database schema unchanged
- ✅ **Fail-open behavior preserved** - Tenant-local checks work even when tenant_id cannot be resolved

### Test Coverage

**Unit Tests:**
- All existing tests still pass (8 tests, 54 assertions)

**Integration Tests:**
- `testEnforcementFlagZeroDoesNotBlock()` - ✅ Passes (no skipping)
- `testEnforcementFlagOneBlocksOnBlocker()` - ✅ Passes

**Test File:** `tests/Integration/HatthasilpaE2E_SerialEnforcementStage2Test.php`

---

## 6. Status

**Status:** ✅ **COMPLETED** (December 2025)

**Implementation:**
- ✅ Improved tenant resolution (direct-tenant mode)
- ✅ Tenant-local fallback when tenant_id cannot be resolved
- ✅ Reduced noisy logs ("Could not determine tenant_id...")
- ✅ Deterministic integration test anomaly seeding
- ✅ Both integration tests pass (no skipping)
- ✅ All unit tests still pass
- ✅ No database schema changes
- ✅ Task 8 enforcement logic unchanged

**Related Tasks:**
- ✅ Task 5: Serial Number Hardening Layer (Stage 1) (December 2025) - Detection layer
  - See [TASK_DAG_5_SERIAL_HARDENING.md](TASK_DAG_5_SERIAL_HARDENING.md)
- ✅ Task 8: Serial Enforcement Stage 2 Gate (December 2025) - Enforcement layer
  - See [TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md](TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md)

**Documentation:**
- ✅ Implementation summary: `docs/dag/agent-tasks/task9_TENANT_RESOLUTION_HARDENING.md`

---

## 7. Related Documentation

- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Serial tracking section
- [TASK_DAG_5_SERIAL_HARDENING.md](TASK_DAG_5_SERIAL_HARDENING.md) - Stage 1 detection
- [TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md](TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md) - Stage 2 enforcement
- [task9_TENANT_RESOLUTION_HARDENING.md](../agent-tasks/task9_TENANT_RESOLUTION_HARDENING.md) - Detailed implementation summary

---

**Task Completed:** December 2025  
**Implemented By:** AI Agent (Composer)  
**Task Reference:** docs/dag/agent-tasks/task9.md

