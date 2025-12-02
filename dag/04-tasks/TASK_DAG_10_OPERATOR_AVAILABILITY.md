# DAG Task 10: Operator Availability Console & Enforcement Flag

**Task ID:** DAG-10  
**Status:** ✅ **COMPLETED** (December 2025)  
**Scope:** Assignment / Operator Availability / UI  
**Type:** Implementation Task (Multiple Sub-tasks)

---

## 1. Context

### Problem

Multiple issues related to operator availability management:
1. **Task 10:** No UI for managing operator availability - system couldn't respect operator availability settings
2. **Task 10.1:** Standalone Operator Availability page created but should integrate with existing People Monitor
3. **Task 10.2:** People Monitor needed workload, current work, and realtime timer features

### Impact

- Managers couldn't easily set operator availability
- System couldn't enforce availability (no feature flag)
- People Monitor didn't show accurate workload or current work status
- No realtime visibility into operator work progress

---

## 2. Objective

Implement complete Operator Availability system:
1. **Task 10:** Operator Availability Console & Enforcement Flag
   - Backend API for managing operator availability
   - Feature flag `FF_HAT_ENFORCE_AVAILABILITY` for enforcement
   - Integration with `AssignmentEngine::filterAvailable()`

2. **Task 10.1:** Patch - Integrate into People Monitor
   - Remove standalone page
   - Integrate availability API into People Monitor tab
   - Preserve existing UI layout

3. **Task 10.2:** People Monitor Enhancements (Planned)
   - Workload breakdown (active/paused/assigned)
   - Current work display
   - Realtime work timer

---

## 3. Scope

### Task 10: Operator Availability Console & Enforcement Flag

**Files Created:**
- `source/hatthasilpa_operator_api.php` - API for managing operator availability
  - `get_operator_availability` - List all operators with availability status
  - `update_operator_availability` - Update operator availability

**Files Modified:**
- `source/BGERP/Service/AssignmentEngine.php`
  - Modified: `filterAvailable()` - Added feature flag check for enforcement
  - Behavior: When `FF_HAT_ENFORCE_AVAILABILITY=1`, filters unavailable operators

**Feature Flag:**
- `FF_HAT_ENFORCE_AVAILABILITY`
  - `0` (default) - Fail-open behavior (detection only)
  - `1` - Enforce availability (filter unavailable operators)

### Task 10.1: Patch - People Monitor Integration

**Files Removed:**
- `page/hatthasilpa_operator_availability.php` - Standalone page (deleted)
- `views/hatthasilpa_operator_availability.php` - HTML template (deleted)
- `assets/javascripts/hatthasilpa/operator_availability.js` - JavaScript (deleted)

**Files Modified:**
- `assets/javascripts/manager/assignment.js`
  - Enhanced: `loadPeopleMonitor()` - Merges availability data
  - Enhanced: `renderPeopleTable()` - Displays availability status
  - Updated: Set Availability button handler - Uses new API
  - Updated: Save Availability handler - Calls `hatthasilpa_operator_api.php`

- `index.php` - Removed route for standalone page

**Integration:**
- People Monitor tab now loads availability data from `hatthasilpa_operator_api.php`
- Set Availability button opens modal with current values
- Save updates `operator_availability` table via new API
- Status column reflects availability from `operator_availability` table

### Task 10.2: People Monitor Enhancements (Planned)

**Planned Features:**
- Workload breakdown: `active_count`, `paused_count`, `assigned_ready_count`
- Current work display: Shows active/paused/ready work with state
- Realtime work timer: Shows elapsed time for active work

**Status:** 🟡 **PLANNED** (Not yet implemented)

---

## 4. Implementation Summary

### Task 10: Backend API & Enforcement

**API Endpoints:**

**GET `/?action=get_operator_availability`**
- Returns list of all operators with availability status
- Response:
```json
{
  "ok": true,
  "operators": [
    {
      "id_member": 1,
      "name": "Operator A",
      "is_available": 1,
      "unavailable_until": null,
      "last_updated": "2025-11-17 15:00:00"
    }
  ]
}
```

**POST `/?action=update_operator_availability`**
- Updates operator availability
- Input: `id_member`, `is_available`, `unavailable_until`
- Behavior: INSERT if not exists, UPDATE if exists

**Enforcement Logic:**
- When `FF_HAT_ENFORCE_AVAILABILITY=1`:
  - Filters operators with `is_available=0` or `unavailable_until > NOW()`
  - Respects availability settings from `operator_availability` table
- When `FF_HAT_ENFORCE_AVAILABILITY=0`:
  - Fail-open behavior (same as before)

### Task 10.1: People Monitor Integration

**Before:**
- Standalone Operator Availability page existed
- People Monitor showed status from `team_api.php` only
- No integration with `operator_availability` table

**After:**
- Standalone page removed
- People Monitor merges data from both `team_api.php` and `hatthasilpa_operator_api.php`
- Set Availability button works with new API
- Status reflects `operator_availability` table when available

**Fail-Open Behavior:**
- If `hatthasilpa_operator_api.php` fails → People Monitor continues with original data
- If no availability row exists → Operator treated as available (original behavior)
- If availability API returns empty → All operators treated as available

---

## 5. Guardrails

### Must Not Regress

- ✅ **UI preservation** - People Monitor layout unchanged (Task 10.1)
- ✅ **Fail-open behavior** - Availability API failures don't break People Monitor
- ✅ **Feature flag protection** - Enforcement only when flag enabled
- ✅ **No schema changes** - Database schema unchanged

### Test Coverage

**Integration Tests:**
- `tests/Integration/HatthasilpaOperatorAvailabilityTest.php`
- Tests skip gracefully if `operator_availability` table doesn't exist (acceptable)

**Status:** ✅ **Tests passing** (with graceful degradation)

---

## 6. Status

**Status:** ✅ **COMPLETED** (December 2025)

**Implementation:**
- ✅ Task 10: Operator Availability Console & Enforcement Flag - Complete
- ✅ Task 10.1: People Monitor Integration - Complete
- 🟡 Task 10.2: People Monitor Enhancements - Planned (not yet implemented)

**Related Tasks:**
- ✅ Task 4: Operator Availability Schema Normalization (December 2025) - Schema detection
  - See [TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md](TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md)
- ✅ Task 6: Operator Availability Fail-Open Logic (December 2025) - Fail-open for empty table
  - See [TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md](TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md)

**Documentation:**
- ✅ Task 10: `docs/dag/agent-tasks/task10.md`
- ✅ Task 10.1: `docs/dag/agent-tasks/task10.1_OPERATOR_AVAILABILITY_PATCH.md`
- 🟡 Task 10.2: `docs/dag/agent-tasks/task10.2.md` (Planned)

---

## 7. Related Documentation

- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Assignment section
- [TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md](TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md) - Schema normalization
- [TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md](TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md) - Fail-open logic
- [task10.md](../agent-tasks/task10.md) - Original task specification
- [task10.1_OPERATOR_AVAILABILITY_PATCH.md](../agent-tasks/task10.1_OPERATOR_AVAILABILITY_PATCH.md) - Patch implementation summary

---

**Task Completed:** December 2025 (Tasks 10, 10.1)  
**Status:** Task 10.2 Planned (not yet implemented)  
**Implemented By:** AI Agent (Composer)  
**Task Reference:** docs/dag/agent-tasks/task10.md, task10.1.md

