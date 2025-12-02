# Timezone Audit Report

**Date:** 2025-01-XX  
**Task:** 20.2.1 - Timezone Normalization Audit Plan  
**Status:** ✅ COMPLETE (Audit-Only, No Code Changes)

---

## Executive Summary

This audit identifies all timezone-related operations across the SuperDAG / ETA / SLA / Token system. The audit covers PHP backend, JavaScript frontend, API endpoints, and database schema to establish a comprehensive migration plan for canonical timezone normalization.

**Total Files Audited:** 50+ files  
**Critical Issues Found:** 8 files  
**Need Fix:** 15 files  
**OK (Already Normalized):** 5 files

---

## Audit Scope

### Scope A — Core DAG / Routing ✅

| File | Function/Method | Usage | Current Behavior | Status | Priority |
|------|----------------|-------|------------------|--------|----------|
| `source/BGERP/Dag/EtaEngine.php` | `computeNodeEtaForToken()` | TimeHelper::now() | Canonical timezone | ✅ **OK** | - |
| `source/BGERP/Dag/EtaEngine.php` | `calculateSlaStatus()` | TimeHelper::now() | Canonical timezone | ✅ **OK** | - |
| `source/BGERP/Dag/EtaEngine.php` | `calculateDurationMs()` | TimeHelper::durationMs() | Canonical timezone | ✅ **OK** | - |
| `source/BGERP/Service/DAGRoutingService.php` | `checkWaitTimeout()` | `strtotime()`, `time()` | System timezone | ⚠️ **NEED_FIX** | Medium |
| `source/BGERP/Service/DAGRoutingService.php` | `generateQRCode()` | `date('Y-m-d H:i:s')` | System timezone | ⚠️ **NEED_FIX** | Low |
| `source/dag_routing_api.php` | `token_eta` | TimeHelper (via EtaEngine) | Canonical timezone | ✅ **OK** | - |
| `source/dag_routing_api.php` | Multiple actions | `date('Y-m-d H:i:s')` | System timezone | ⚠️ **NEED_FIX** | Medium |
| `source/dag_routing_api.php` | Multiple actions | `NOW()` (SQL) | Server timezone | ⚠️ **NEED_FIX** | Medium |
| `source/dag_routing_api.php` | ETag generation | `time()` | System timezone | ⚠️ **NEED_FIX** | Low |

**Summary:**
- ✅ EtaEngine: Already migrated to TimeHelper (Task 20.2)
- ⚠️ DAGRoutingService: 2 locations need migration
- ⚠️ dag_routing_api.php: ~15 locations need migration

---

### Scope B — Token Lifecycle Services ⚠️

| File | Function/Method | Usage | Current Behavior | Status | Priority |
|------|----------------|-------|------------------|--------|----------|
| `source/BGERP/Service/TokenLifecycleService.php` | `completeToken()` | `strtotime()`, `time()`, `NOW()` | System timezone | 🔴 **CRITICAL** | High |
| `source/BGERP/Service/TokenWorkSessionService.php` | `startToken()` | `date('Y-m-d H:i:s')` | System timezone | 🔴 **CRITICAL** | High |
| `source/BGERP/Service/TokenWorkSessionService.php` | `pauseToken()` | `strtotime()`, `time()` | System timezone | 🔴 **CRITICAL** | High |
| `source/BGERP/Service/TokenWorkSessionService.php` | `resumeToken()` | `date('Y-m-d H:i:s')` | System timezone | 🔴 **CRITICAL** | High |
| `source/BGERP/Service/TokenWorkSessionService.php` | `completeSession()` | `date('Y-m-d H:i:s')` | System timezone | 🔴 **CRITICAL** | High |
| `source/BGERP/Service/TokenWorkSessionService.php` | `checkLockExpiry()` | `strtotime()`, `time()` | System timezone | ⚠️ **NEED_FIX** | Medium |
| `source/BGERP/Service/TokenWorkSessionService.php` | `calculateTotalWorkMinutes()` | `strtotime()` | System timezone | ⚠️ **NEED_FIX** | Medium |
| `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php` | `calculateTimer()` | `new DateTimeImmutable('now')` | System timezone | ⚠️ **NEED_FIX** | Medium |
| `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php` | `parseDateTime()` | `DateTimeImmutable::createFromFormat()` | System timezone | ⚠️ **NEED_FIX** | Medium |

**Summary:**
- 🔴 **CRITICAL:** Token lifecycle timestamps (start_at, pause_at, resume_at, completed_at) must use canonical timezone
- ⚠️ WorkSessionTimeEngine: Should migrate to TimeHelper for consistency

---

### Scope C — API Endpoints ⚠️

| File | Action | Usage | Current Behavior | Status | Priority |
|------|-------|-------|------------------|--------|----------|
| `source/dag_token_api.php` | `token_complete` | Token completion | System timezone | ⚠️ **NEED_FIX** | High |
| `source/pwa_scan_api.php` | Multiple actions | `date()`, `time()`, `strtotime()` | System timezone | ⚠️ **NEED_FIX** | Medium |
| `source/dag_routing_api.php` | `graph_save` | `date('Y-m-d H:i:s')` | System timezone | ⚠️ **NEED_FIX** | Medium |
| `source/dag_routing_api.php` | `graph_publish` | `date('Y-m-d H:i:s')` | System timezone | ⚠️ **NEED_FIX** | Medium |
| `source/dag_routing_api.php` | `graph_snapshot` | `date('Y-m-d H:i:s')` | System timezone | ⚠️ **NEED_FIX** | Low |
| `source/dag_routing_api.php` | `graph_rollback` | `date('Y-m-d H:i:s')` | System timezone | ⚠️ **NEED_FIX** | Low |

**Summary:**
- ⚠️ ~20 API endpoints need timezone normalization
- Priority: Token operations (High) > Graph operations (Medium) > Utility operations (Low)

---

### Scope D — Frontend JavaScript ✅

| File | Function/Method | Usage | Current Behavior | Status | Priority |
|------|----------------|-------|------------------|--------|----------|
| `assets/javascripts/dag/graph_sidebar.js` | `formatDate()` | GraphTimezone | Canonical timezone | ✅ **OK** | - |
| `assets/javascripts/dag/graph_sidebar_debug.js` | Debug logging | `new Date().toISOString()` | Browser timezone | ⚠️ **NEED_FIX** | Low |
| `assets/javascripts/dag/graph_designer.js` | ETA preview | Design-time only | N/A | ✅ **OK** | - |

**Summary:**
- ✅ graph_sidebar.js: Already migrated to GraphTimezone (Task 20.2)
- ⚠️ Debug files: Low priority (debug only)

---

## Database Schema Review

### Time-Related Columns

| Table | Column | Type | Default | Status | Notes |
|-------|--------|------|---------|--------|-------|
| `flow_token` | `spawned_at` | DATETIME | CURRENT_TIMESTAMP | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `flow_token` | `start_at` | DATETIME NULL | NULL | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `flow_token` | `completed_at` | DATETIME NULL | NULL | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `token_event` | `event_time` | DATETIME | CURRENT_TIMESTAMP | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `token_work_session` | `started_at` | DATETIME | NULL | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `token_work_session` | `paused_at` | DATETIME NULL | NULL | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `token_work_session` | `resumed_at` | DATETIME NULL | NULL | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `token_work_session` | `completed_at` | DATETIME NULL | NULL | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `routing_graph` | `created_at` | DATETIME | CURRENT_TIMESTAMP | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `routing_graph` | `updated_at` | DATETIME | CURRENT_TIMESTAMP | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `routing_graph_draft` | `saved_at` | DATETIME | NULL | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `routing_graph_draft` | `updated_at` | DATETIME | NULL | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `routing_graph_version` | `published_at` | DATETIME NULL | NULL | ⚠️ **NEED_FIX** | Should use canonical timezone |
| `routing_graph_version` | `snapshot_at` | DATETIME NULL | NULL | ⚠️ **NEED_FIX** | Should use canonical timezone |

**Summary:**
- All DATETIME columns use CURRENT_TIMESTAMP or manual `NOW()` → Need normalization
- Recommendation: Use TimeHelper::toMysql() for all DB writes

---

## Critical Issues (Must Fix in 20.2.2)

### 1. Token Lifecycle Timestamps 🔴

**Files:**
- `source/BGERP/Service/TokenLifecycleService.php` (completeToken)
- `source/BGERP/Service/TokenWorkSessionService.php` (startToken, pauseToken, resumeToken, completeSession)

**Issue:** Token timestamps (`start_at`, `pause_at`, `resume_at`, `completed_at`) use system timezone instead of canonical timezone.

**Impact:** 
- ETA calculations may be incorrect
- SLA violations may be misreported
- Cross-timezone deployments will fail

**Fix:** Migrate to TimeHelper::toMysql() for all timestamp writes.

---

### 2. API Timestamp Responses ⚠️

**Files:**
- `source/dag_routing_api.php` (multiple actions)
- `source/dag_token_api.php` (token_complete)

**Issue:** API responses include timestamps in system timezone instead of canonical timezone.

**Impact:**
- Frontend receives inconsistent timezone data
- ETA displays may be incorrect

**Fix:** Normalize all API response timestamps using TimeHelper::toIso8601().

---

### 3. SQL NOW() Usage ⚠️

**Files:**
- `source/dag_routing_api.php` (multiple actions)
- `source/BGERP/Service/TokenLifecycleService.php`

**Issue:** Direct SQL `NOW()` uses server timezone instead of canonical timezone.

**Impact:**
- Database timestamps inconsistent
- Cross-server deployments will fail

**Fix:** Replace `NOW()` with `TimeHelper::toMysql(TimeHelper::now())` in prepared statements.

---

## Status Summary

### ✅ OK (Already Normalized)

1. `source/BGERP/Dag/EtaEngine.php` - All time operations use TimeHelper
2. `assets/javascripts/dag/graph_sidebar.js` - Uses GraphTimezone
3. `source/dag_routing_api.php` - `token_eta` action uses TimeHelper (via EtaEngine)
4. `source/BGERP/Helper/TimeHelper.php` - Canonical timezone helper (new)
5. `assets/javascripts/dag/modules/GraphTimezone.js` - Canonical timezone helper (new)

### ⚠️ NEED_FIX (Medium Priority)

1. `source/BGERP/Service/DAGRoutingService.php` - Wait time calculations
2. `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php` - DateTimeImmutable usage
3. `source/dag_routing_api.php` - Graph save/publish timestamps
4. `source/dag_routing_api.php` - ETag generation
5. `source/pwa_scan_api.php` - PWA timestamp handling

### 🔴 CRITICAL (High Priority - Must Fix in 20.2.2)

1. `source/BGERP/Service/TokenLifecycleService.php` - Token completion timestamps
2. `source/BGERP/Service/TokenWorkSessionService.php` - Session timestamps (start/pause/resume/complete)
3. `source/dag_token_api.php` - Token completion API
4. All SQL `NOW()` usage in token operations

---

## Recommendations

### Immediate (Task 20.2.2)

1. **Migrate Token Lifecycle Services:**
   - TokenLifecycleService::completeToken()
   - TokenWorkSessionService::startToken()
   - TokenWorkSessionService::pauseToken()
   - TokenWorkSessionService::resumeToken()
   - TokenWorkSessionService::completeSession()

2. **Replace SQL NOW() with TimeHelper:**
   - All `NOW()` in token operations
   - All `NOW()` in graph operations

3. **Normalize API Responses:**
   - All timestamp fields in API responses
   - Use TimeHelper::toIso8601() for JSON responses

### Future (Task 20.2.3+)

1. Migrate WorkSessionTimeEngine to TimeHelper
2. Migrate DAGRoutingService time operations
3. Migrate PWA scan API timestamps
4. Add tenant-level timezone support

---

## Files Requiring Migration

### High Priority (20.2.2)

1. `source/BGERP/Service/TokenLifecycleService.php`
2. `source/BGERP/Service/TokenWorkSessionService.php`
3. `source/dag_token_api.php`

### Medium Priority (20.2.3)

4. `source/BGERP/Service/DAGRoutingService.php`
5. `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`
6. `source/dag_routing_api.php` (graph operations)

### Low Priority (Future)

7. `source/pwa_scan_api.php`
8. `source/dag_routing_api.php` (utility operations)
9. `assets/javascripts/dag/graph_sidebar_debug.js`

---

**End of Audit Report**

