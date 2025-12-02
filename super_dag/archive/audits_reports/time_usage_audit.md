# Time Usage Audit

**Date:** 2025-01-XX  
**Purpose:** Audit existing time handling in SuperDAG / ETA / SLA codebase  
**Task:** 20.2 - Timezone Normalization Layer (Pre-step)

---

## Summary

This audit identifies all time-related operations in the SuperDAG codebase to guide migration to `TimeHelper` in Task 20.2 and future Time Engine phases.

---

## PHP Backend

### 1. Global Timezone Configuration

| File | Function/Method | Current Timezone | Notes |
|------|----------------|-----------------|-------|
| `config.php` | `date_default_timezone_set('Asia/Bangkok')` | Asia/Bangkok | ✅ Already set correctly |
| `source/BGERP/Bootstrap/TenantApiBootstrap.php` | `date_default_timezone_set($timezone)` | Dynamic (from tenant) | ⚠️ Per-tenant timezone (future enhancement) |
| `source/BGERP/Service/UnifiedSerialService.php` | `date_default_timezone_set('UTC')` | UTC | ⚠️ Temporary UTC override (needs review) |

**Recommendation:**
- Keep `config.php` as canonical timezone source
- Migrate `TenantApiBootstrap` to use `TimeHelper` (future phase)
- Review `UnifiedSerialService` UTC usage (may be intentional for serial generation)

---

### 2. DateTime / DateTimeImmutable Usage

| File | Function/Method | Usage | Current Timezone | Notes |
|------|----------------|-------|------------------|-------|
| `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php` | `new DateTimeImmutable('now')` | Line 55 | System default | ✅ Candidate for TimeHelper::now() |
| `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php` | `new DateTimeImmutable($mysqlDateTime)` | Line 169 | System default | ✅ Candidate for TimeHelper::parse() |
| `source/service/ScheduleService.php` | `new DateTime($start_date)` | Line 327 | System default | ⚠️ Legacy service (out of scope for Task 20.2) |
| `source/service/CapacityCalculator.php` | `new DateTime(...)` | Multiple | System default | ⚠️ Legacy service (out of scope for Task 20.2) |

**Recommendation:**
- **Task 20.2:** Migrate `WorkSessionTimeEngine` to `TimeHelper`
- **Future:** Migrate legacy services in later phases

---

### 3. Bare time() / date() / strtotime() Usage

#### SuperDAG Core Modules (Task 20.2 Priority)

| File | Function/Method | Usage | Current Behavior | Notes |
|------|----------------|-------|------------------|-------|
| `source/BGERP/Dag/EtaEngine.php` | `computeNodeEtaForToken()` | `strtotime($startAt)` | Line 119 | System timezone | ✅ **HIGH PRIORITY** - Migrate to TimeHelper |
| `source/BGERP/Dag/EtaEngine.php` | `computeNodeEtaForToken()` | `time()` | Line 128 | System timezone | ✅ **HIGH PRIORITY** - Migrate to TimeHelper::now() |
| `source/BGERP/Dag/EtaEngine.php` | `computeNodeEtaForToken()` | `date('c', ...)` | Line 125 | System timezone | ✅ **HIGH PRIORITY** - Migrate to TimeHelper |
| `source/BGERP/Dag/EtaEngine.php` | `calculateSlaStatus()` | `time()` | Line 208 | System timezone | ✅ **HIGH PRIORITY** - Migrate to TimeHelper::now() |
| `source/BGERP/Dag/EtaEngine.php` | `calculateSlaStatus()` | `strtotime($startAt)` | Line 211 | System timezone | ✅ **HIGH PRIORITY** - Migrate to TimeHelper |
| `source/BGERP/Dag/EtaEngine.php` | `calculateDurationMs()` | `strtotime(...)` | Lines 243-244 | System timezone | ✅ **HIGH PRIORITY** - Migrate to TimeHelper |
| `source/BGERP/Dag/ApplyFixEngine.php` | `time()` | Lines 290, 499, 504 | System timezone | ⚠️ Used for temp_id generation (low priority) |

**Recommendation:**
- **Task 20.2:** Migrate all `EtaEngine` time operations to `TimeHelper`
- `ApplyFixEngine` temp_id generation can wait (not timezone-sensitive)

#### DAG Routing Service

| File | Function/Method | Usage | Current Behavior | Notes |
|------|----------------|-------|------------------|-------|
| `source/BGERP/Service/DAGRoutingService.php` | `strtotime($result['event_time'])` | Line 1751 | System timezone | ⚠️ Wait time calculation (future phase) |
| `source/BGERP/Service/DAGRoutingService.php` | `time()` | Line 1752 | System timezone | ⚠️ Wait time calculation (future phase) |
| `source/BGERP/Service/DAGRoutingService.php` | `date('Y-m-d H:i:s')` | Line 2496 | System timezone | ⚠️ QR generation timestamp (future phase) |

**Recommendation:**
- **Task 20.2:** Not critical (not ETA/SLA related)
- **Future:** Migrate in later Time Engine phases

#### Token Lifecycle Service

| File | Function/Method | Usage | Current Behavior | Notes |
|------|----------------|-------|------------------|-------|
| `source/BGERP/Service/TokenLifecycleService.php` | `strtotime($token['start_at'])` | Line 387 | System timezone | ⚠️ Token completion calculation (future phase) |
| `source/BGERP/Service/TokenLifecycleService.php` | `time()` | Line 388 | System timezone | ⚠️ Token completion calculation (future phase) |
| `source/BGERP/Service/TokenWorkSessionService.php` | `date('Y-m-d H:i:s')` | Lines 157, 248 | System timezone | ⚠️ Session timestamps (future phase) |
| `source/BGERP/Service/TokenWorkSessionService.php` | `strtotime(...)` | Lines 194-195, 271 | System timezone | ⚠️ Session calculations (future phase) |

**Recommendation:**
- **Task 20.2:** Not critical (not ETA/SLA related)
- **Future:** Migrate in later Time Engine phases

---

## JavaScript Frontend

### 1. Direct Date() Usage

| File | Function/Method | Usage | Current Behavior | Notes |
|------|----------------|-------|------------------|-------|
| `assets/javascripts/dag/graph_sidebar.js` | `new Date()` | Line 574 | Browser timezone | ✅ **HIGH PRIORITY** - Migrate to GraphTimezone |
| `assets/javascripts/dag/graph_sidebar_debug.js` | `new Date().toISOString()` | Line 265 | Browser timezone | ⚠️ Debug only (low priority) |

**Recommendation:**
- **Task 20.2:** Migrate `graph_sidebar.js` to `GraphTimezone`
- Debug file can wait

### 2. Date.parse() / toISOString() Usage

**Status:** No direct `Date.parse()` or `toISOString()` found in DAG modules (good!)

---

## Migration Priority

### Task 20.2 (Immediate)

**Must Migrate:**
1. ✅ `EtaEngine.php` - All time operations (6 locations)
2. ✅ `graph_sidebar.js` - `new Date()` usage (1 location)

**Should Migrate (if time permits):**
3. ⚠️ `WorkSessionTimeEngine.php` - DateTimeImmutable usage (2 locations)

**Can Wait:**
4. ⚠️ `DAGRoutingService.php` - Wait time calculations (future phase)
5. ⚠️ `TokenLifecycleService.php` - Token timestamps (future phase)
6. ⚠️ `ApplyFixEngine.php` - Temp ID generation (not timezone-sensitive)

---

## Files to Create

1. ✅ `source/BGERP/Helper/TimeHelper.php` (NEW)
2. ✅ `assets/javascripts/dag/modules/GraphTimezone.js` (NEW)

---

## Files to Modify

### Task 20.2 Scope:
1. ✅ `source/BGERP/Dag/EtaEngine.php` - Replace all time operations
2. ✅ `assets/javascripts/dag/graph_sidebar.js` - Replace `new Date()`
3. ✅ `config.php` - Add `BGERP_TIMEZONE` constant

### Future Phases:
4. ⚠️ `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`
5. ⚠️ `source/BGERP/Service/DAGRoutingService.php`
6. ⚠️ `source/BGERP/Service/TokenLifecycleService.php`

---

## Notes

- **Canonical Timezone:** `Asia/Bangkok` (already set in `config.php`)
- **Current State:** Most code uses system default timezone (implicit)
- **Goal:** All SuperDAG/ETA/SLA operations use canonical timezone explicitly
- **Future:** Per-tenant timezone support (Task 20.x / 21.x)

---

**End of Audit**

