# DAG Task 6: Operator Availability Fail-Open Logic

**Task ID:** DAG-6  
**Status:** ✅ **COMPLETED** (December 2025)  
**Scope:** Assignment / Operator Availability  
**Type:** Implementation Task

---

## 1. Context

### Problem

When `operator_availability` table uses `is_available + unavailable_until` schema but:
- Table is completely empty (no rows), OR
- Table has data but no rows for any candidate

The query:
```sql
SELECT id_member
FROM operator_availability
WHERE id_member IN (...)
```

Returns 0 rows → intersect with candidates → results in 0 available operators → **incorrectly blocks all candidates**

### Impact

- System incorrectly blocked all operators when table was empty
- System incorrectly blocked operators when they weren't yet configured in availability table
- Business logic requires: "If table empty or no candidate rows → everyone is available" (fail-open)

---

## 2. Objective

Implement dual fail-open logic for `AssignmentEngine::filterAvailable()` in the `is_available + unavailable_until` schema branch:
- **Layer 1:** Empty table check (COUNT(*) = 0) → return all candidates
- **Layer 2:** No candidate rows check (LIMIT 1 query) → return all candidates
- Proper logging for both fail-open scenarios
- No impact on other schema branches or existing behavior

---

## 3. Scope

### Files Changed

**PHP Service Files:**
- `source/BGERP/Service/AssignmentEngine.php`
  - Modified: `filterAvailable()` method
  - Branch: `is_available + unavailable_until` schema only
  - Added: Fail-open layer 1 (empty table check)
  - Added: Fail-open layer 2 (no candidate rows check)
  - Added: Logging for both scenarios

### Database Tables Used

- `operator_availability` - Operator availability status (existing, no schema changes)

---

## 4. Implementation Summary

### Fail-Open Layer 1: Empty Table Check

**Location:** `source/BGERP/Service/AssignmentEngine.php` - `filterAvailable()` method  
**Branch:** `is_available + unavailable_until` schema only

**Implementation:**
```php
// Fail-open ชั้นที่ 1: ตรวจว่า table ว่างหรือไม่
$countStmt = $db->prepare("SELECT COUNT(*) as cnt FROM operator_availability");
if ($countStmt) {
    $countStmt->execute();
    $countResult = $countStmt->get_result();
    $countRow = $countResult->fetch_assoc();
    $countStmt->close();
    
    if ($countRow && (int)$countRow['cnt'] === 0) {
        // Table ว่าง → fail-open (ถือว่าทุกคนว่าง)
        error_log('[AssignmentEngine] filterAvailable: operator_availability empty, using fail-open (keep all candidates)');
        return $ids;
    }
}
```

**Behavior:**
- Checks if `operator_availability` table has any rows
- If COUNT(*) = 0 → returns all candidates immediately (fail-open)
- Logs the fail-open decision

### Fail-Open Layer 2: No Candidate Rows Check

**Location:** Same method, after layer 1 check

**Implementation:**
```php
// Fail-open ชั้นที่ 2: ตรวจว่ามี row สำหรับ candidate ใดเลยหรือไม่
$checkStmt = $db->prepare("
    SELECT {$idColumn}
    FROM operator_availability
    WHERE {$idColumn} IN ($in)
    LIMIT 1
");
if ($checkStmt) {
    $checkStmt->bind_param($types, ...$ids);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();
    $hasAnyRow = $checkResult->num_rows > 0;
    $checkStmt->close();
    
    if (!$hasAnyRow) {
        // ไม่มี row สำหรับ candidate ใดเลย → fail-open (ถือว่ายังไม่ config)
        error_log('[AssignmentEngine] filterAvailable: no availability rows for candidates, fail-open');
        return $ids;
    }
}
```

**Behavior:**
- Checks if there's at least one row for any candidate
- Uses `LIMIT 1` for efficiency (only need to know if any exists)
- If no rows found → returns all candidates (fail-open)
- Logs the fail-open decision

### Key Methods

**AssignmentEngine::filterAvailable()** (Enhanced)
- Location: `source/BGERP/Service/AssignmentEngine.php`
- Changes: Added dual fail-open logic for `is_available + unavailable_until` schema
- Behavior: Returns all candidates when table empty or no candidate rows

---

## 5. Guardrails

### Must Not Regress

- ✅ **Other schema branches unchanged** - Only `is_available + unavailable_until` branch modified
- ✅ **Normal filtering preserved** - When rows exist, filtering works as before
- ✅ **Method signature unchanged** - No new parameters
- ✅ **No database schema changes** - Only PHP logic changes

### Test Coverage

**Integration Test:**
- `testFilterAvailableWithIsAvailableSchema()` - Verifies filtering behavior
- Tests fail-open when table empty
- Tests fail-open when no candidate rows
- Tests normal filtering when rows exist

**Test File:** `tests/Integration/HatthasilpaAssignmentIntegrationTest.php`

---

## 6. Status

**Status:** ✅ **COMPLETED** (December 2025)

**Implementation:**
- ✅ Fail-open layer 1 implemented (empty table check)
- ✅ Fail-open layer 2 implemented (no candidate rows check)
- ✅ Logging added for both scenarios
- ✅ Only `is_available + unavailable_until` branch modified
- ✅ Other schema branches unchanged
- ✅ All existing tests still pass

**Related Tasks:**
- ✅ Task 4: Operator Availability Schema Normalization (December 2025) - Added Schema 4 support
  - See [TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md](TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md)
- ✅ Task 10: Operator Availability Console & Enforcement Flag (December 2025) - Added UI and enforcement
  - See [TASK_DAG_10_OPERATOR_AVAILABILITY.md](TASK_DAG_10_OPERATOR_AVAILABILITY.md)

**Documentation:**
- ✅ Implementation summary: `docs/dag/agent-tasks/task6_OPERATOR_AVAILABILITY_FAIL_OPEN.md`

---

## 7. Related Documentation

- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Assignment section
- [TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md](TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md) - Schema normalization
- [task6_OPERATOR_AVAILABILITY_FAIL_OPEN.md](../agent-tasks/task6_OPERATOR_AVAILABILITY_FAIL_OPEN.md) - Detailed implementation summary

---

**Task Completed:** December 2025  
**Implemented By:** AI Agent (Composer)  
**Task Reference:** docs/dag/agent-tasks/task6.md

