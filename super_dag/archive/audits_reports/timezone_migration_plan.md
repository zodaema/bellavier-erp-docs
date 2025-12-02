# Timezone Migration Plan

**Date:** 2025-01-XX  
**Task:** 20.2.1 - Timezone Normalization Audit Plan  
**Based On:** timezone_audit_report.md

---

## Overview

This migration plan defines the required fixes for Task 20.2.2 and beyond to achieve full timezone normalization across the SuperDAG / ETA / SLA / Token system.

---

## Migration Phases

### Phase 1: Task 20.2.2 — Critical Token Lifecycle (HIGH PRIORITY)

**Objective:** Migrate all token lifecycle timestamps to canonical timezone

**Target Files:**
1. `source/BGERP/Service/TokenLifecycleService.php`
2. `source/BGERP/Service/TokenWorkSessionService.php`
3. `source/dag_token_api.php`

**Changes Required:**

#### 1.1 TokenLifecycleService.php

**File:** `source/BGERP/Service/TokenLifecycleService.php`

**Location:** `completeToken()` method (lines 383-410)

**Current Code:**
```php
$startTimestamp = strtotime($token['start_at']);
$completedTimestamp = time();
$actualDurationMs = ($completedTimestamp - $startTimestamp) * 1000;
// ...
completed_at = NOW()
```

**Target Code:**
```php
use BGERP\Helper\TimeHelper;

$startDt = TimeHelper::parse($token['start_at']);
$completedDt = TimeHelper::now();
$actualDurationMs = TimeHelper::durationMs($startDt, $completedDt);
// ...
completed_at = ?
```

**SQL Changes:**
- Replace `NOW()` with `?` placeholder
- Bind `TimeHelper::toMysql(TimeHelper::now())`

**Estimated Effort:** 2 hours

---

#### 1.2 TokenWorkSessionService.php

**File:** `source/BGERP/Service/TokenWorkSessionService.php`

**Locations:**
- `startToken()` - Line 157: `date('Y-m-d H:i:s')`
- `pauseToken()` - Lines 194-195: `strtotime()`, `time()`
- `resumeToken()` - Line 248: `date('Y-m-d H:i:s')`
- `completeSession()` - Line 388: `date('Y-m-d H:i:s')`
- `checkLockExpiry()` - Line 555: `strtotime()`, `time()`
- `calculateTotalWorkMinutes()` - Line 838: `strtotime()`

**Changes:**
1. Add `use BGERP\Helper\TimeHelper;`
2. Replace all `date('Y-m-d H:i:s')` → `TimeHelper::toMysql(TimeHelper::now())`
3. Replace all `strtotime($time)` → `TimeHelper::parse($time)`
4. Replace all `time()` → `TimeHelper::timestamp(TimeHelper::now())`
5. Replace all `strtotime(date('Y-m-d H:i:s'))` → `TimeHelper::timestamp(TimeHelper::now())`

**Estimated Effort:** 4 hours

---

#### 1.3 dag_token_api.php

**File:** `source/dag_token_api.php`

**Location:** `token_complete` action

**Changes:**
- Ensure token completion uses TimeHelper (via TokenLifecycleService)
- Normalize response timestamps using TimeHelper::toIso8601()

**Estimated Effort:** 1 hour

---

### Phase 2: Task 20.2.3 — DAG Routing & Graph Operations (MEDIUM PRIORITY)

**Objective:** Migrate DAG routing and graph operation timestamps

**Target Files:**
1. `source/BGERP/Service/DAGRoutingService.php`
2. `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`
3. `source/dag_routing_api.php` (graph operations)

**Changes Required:**

#### 2.1 DAGRoutingService.php

**File:** `source/BGERP/Service/DAGRoutingService.php`

**Locations:**
- `checkWaitTimeout()` - Lines 1751-1752: `strtotime()`, `time()`
- `generateQRCode()` - Line 2496: `date('Y-m-d H:i:s')`

**Changes:**
1. Add `use BGERP\Helper\TimeHelper;`
2. Replace `strtotime($result['event_time'])` → `TimeHelper::parse($result['event_time'])`
3. Replace `time()` → `TimeHelper::timestamp(TimeHelper::now())`
4. Replace `date('Y-m-d H:i:s')` → `TimeHelper::toMysql(TimeHelper::now())`

**Estimated Effort:** 2 hours

---

#### 2.2 WorkSessionTimeEngine.php

**File:** `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`

**Locations:**
- `calculateTimer()` - Line 55: `new DateTimeImmutable('now')`
- `parseDateTime()` - Lines 160-169: `DateTimeImmutable::createFromFormat()`

**Changes:**
1. Add `use BGERP\Helper\TimeHelper;`
2. Replace `new DateTimeImmutable('now')` → `TimeHelper::now()`
3. Replace `parseDateTime()` → Use `TimeHelper::parse()` instead

**Estimated Effort:** 2 hours

---

#### 2.3 dag_routing_api.php (Graph Operations)

**File:** `source/dag_routing_api.php`

**Locations:**
- `graph_save` - Line 2035: `date('Y-m-d H:i:s')`
- `graph_publish` - Lines 4965-4967: `date('Y-m-d H:i:s')`, `NOW()`
- `graph_snapshot` - Line 4934: `date('Y-m-d H:i:s')`
- `graph_rollback` - Line 6874: `date('Y-m-d H:i:s')`
- Multiple actions: `NOW()` in SQL

**Changes:**
1. Add `use BGERP\Helper\TimeHelper;` at top
2. Replace all `date('Y-m-d H:i:s')` → `TimeHelper::toMysql(TimeHelper::now())`
3. Replace all SQL `NOW()` with `?` placeholder + `TimeHelper::toMysql(TimeHelper::now())`
4. Normalize all response timestamps using `TimeHelper::toIso8601()`

**Estimated Effort:** 4 hours

---

### Phase 3: Task 20.2.4 — PWA & Utility Operations (LOW PRIORITY)

**Objective:** Migrate PWA scan API and utility operations

**Target Files:**
1. `source/pwa_scan_api.php`
2. `source/dag_routing_api.php` (utility operations)
3. `assets/javascripts/dag/graph_sidebar_debug.js`

**Estimated Effort:** 3 hours

---

## Migration Checklist

### Task 20.2.2 Checklist

- [ ] Migrate TokenLifecycleService::completeToken()
  - [ ] Replace `strtotime()` with `TimeHelper::parse()`
  - [ ] Replace `time()` with `TimeHelper::now()`
  - [ ] Replace `NOW()` with `TimeHelper::toMysql()`
  - [ ] Test token completion
- [ ] Migrate TokenWorkSessionService
  - [ ] startToken() - Replace `date()`
  - [ ] pauseToken() - Replace `strtotime()`, `time()`
  - [ ] resumeToken() - Replace `date()`
  - [ ] completeSession() - Replace `date()`
  - [ ] checkLockExpiry() - Replace `strtotime()`, `time()`
  - [ ] calculateTotalWorkMinutes() - Replace `strtotime()`
  - [ ] Test all session operations
- [ ] Migrate dag_token_api.php
  - [ ] Ensure token_complete uses TimeHelper
  - [ ] Normalize response timestamps
  - [ ] Test API endpoint
- [ ] Run all tests
  - [ ] ValidateGraphTest (15/15)
  - [ ] AutoFixPipelineTest (15/15)
  - [ ] SemanticSnapshotTest (15/15)
  - [ ] Manual testing: Token start/pause/resume/complete

---

### Task 20.2.3 Checklist

- [ ] Migrate DAGRoutingService
  - [ ] checkWaitTimeout() - Replace time operations
  - [ ] generateQRCode() - Replace `date()`
  - [ ] Test routing operations
- [ ] Migrate WorkSessionTimeEngine
  - [ ] calculateTimer() - Replace `DateTimeImmutable('now')`
  - [ ] parseDateTime() - Replace with `TimeHelper::parse()`
  - [ ] Test timer calculations
- [ ] Migrate dag_routing_api.php (graph operations)
  - [ ] graph_save - Replace `date()`, `NOW()`
  - [ ] graph_publish - Replace `date()`, `NOW()`
  - [ ] graph_snapshot - Replace `date()`
  - [ ] graph_rollback - Replace `date()`
  - [ ] Normalize all response timestamps
  - [ ] Test graph operations
- [ ] Run all tests

---

## Testing Strategy

### Unit Tests

1. **TimeHelper Tests:**
   - Test `now()` returns canonical timezone
   - Test `parse()` handles all formats
   - Test `toIso8601()` returns correct format
   - Test `toMysql()` returns correct format
   - Test `durationMs()` calculates correctly

2. **EtaEngine Tests:**
   - Test ETA calculation with canonical timezone
   - Test SLA status with canonical timezone
   - Test duration calculation with canonical timezone

### Integration Tests

1. **Token Lifecycle Tests:**
   - Test token start → timestamp in canonical timezone
   - Test token pause → timestamp in canonical timezone
   - Test token resume → timestamp in canonical timezone
   - Test token complete → timestamp in canonical timezone
   - Test actual_duration_ms calculation

2. **API Tests:**
   - Test `token_eta` returns canonical timezone timestamps
   - Test `token_complete` stores canonical timezone timestamps
   - Test graph operations store canonical timezone timestamps

### Regression Tests

1. Run all existing SuperDAG tests (45/45 must pass)
2. Manual testing: Token operations
3. Manual testing: Graph operations
4. Manual testing: ETA/SLA calculations

---

## Risk Assessment

### High Risk

1. **Token Lifecycle Timestamps:**
   - **Risk:** Breaking existing token operations
   - **Mitigation:** Thorough testing, gradual rollout
   - **Rollback:** Keep old code as fallback initially

2. **Database Timestamps:**
   - **Risk:** Inconsistent timestamps in database
   - **Mitigation:** Migration script to normalize existing data
   - **Rollback:** Revert to `NOW()` if issues occur

### Medium Risk

1. **API Response Timestamps:**
   - **Risk:** Frontend breaks if format changes
   - **Mitigation:** Maintain backward compatibility
   - **Rollback:** Revert to old format

2. **Graph Operations:**
   - **Risk:** Graph save/publish breaks
   - **Mitigation:** Test thoroughly before deployment
   - **Rollback:** Revert to old timestamp handling

### Low Risk

1. **Utility Operations:**
   - **Risk:** Minor functionality breaks
   - **Mitigation:** Low priority, can fix later
   - **Rollback:** Easy to revert

---

## Success Criteria

### Task 20.2.2

- ✅ All token lifecycle timestamps use TimeHelper
- ✅ All SQL `NOW()` replaced with TimeHelper
- ✅ All tests passing (45/45)
- ✅ No regressions in token operations
- ✅ Manual testing: Token start/pause/resume/complete works

### Task 20.2.3

- ✅ All DAG routing timestamps use TimeHelper
- ✅ All graph operation timestamps use TimeHelper
- ✅ All API responses normalized
- ✅ All tests passing (45/45)
- ✅ No regressions in routing/graph operations

---

## Notes

- **Backward Compatibility:** Maintain ISO8601 format in API responses
- **Database Migration:** Consider migration script for existing data (future task)
- **Tenant Timezone:** Per-tenant timezone support deferred to Task 20.3+
- **UTC Storage:** Future enhancement: Store all timestamps in UTC (Task 20.4+)

---

**End of Migration Plan**

