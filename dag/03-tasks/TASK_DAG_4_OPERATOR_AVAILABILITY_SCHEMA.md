# DAG Task 4: Operator Availability Schema Normalization

**Task ID:** DAG-4  
**Status:** ✅ **COMPLETED** (December 2025)  
**Scope:** Assignment / Operator Availability  
**Type:** Implementation Task

---

## 1. Context

### Problem

Production environment uses `operator_availability` table with schema:
- `id_member`
- `is_available` (TINYINT(1))
- `unavailable_until` (DATETIME)
- `unavailable_reason`
- `note`
- `updated_at`
- `updated_by`

But `AssignmentEngine::filterAvailable()` didn't recognize this schema and treated it as "Unknown schema", causing:
- All operators assumed available (no filtering)
- Noisy logs: "Unknown operator_availability schema, assuming all available"
- Lost ability to block unavailable operators

### Impact

- Operators marked as unavailable in `operator_availability` table were still assigned work
- System couldn't respect operator availability settings
- Logs were noisy with "Unknown schema" warnings

---

## 2. Objective

Normalize `operator_availability` schema detection in `AssignmentEngine::filterAvailable()` to:
- Recognize `is_available + unavailable_until` schema as first-class supported pattern (Schema 4)
- Filter operators correctly based on `is_available` and `unavailable_until` values
- Eliminate "Unknown schema" warnings for production schema
- Preserve fail-open behavior for truly unknown schemas

---

## 3. Scope

### Files Changed

**PHP Service Files:**
- `source/BGERP/Service/AssignmentEngine.php`
  - Modified: `filterAvailable()` method
  - Added: `$hasAvailableFlag` and `$hasUnavailableUntil` detection
  - Added: New branch for `is_available + unavailable_until` schema
  - Updated: Logging to include new flags

**Test Files:**
- `tests/Integration/HatthasilpaAssignmentIntegrationTest.php`
  - Added: `testFilterAvailableWithIsAvailableSchema()` method

### Database Tables Used

- `operator_availability` - Operator availability status (existing, no schema changes)

---

## 4. Implementation Summary

### Schema Detection Improvements

**Added Detection Flags:**
- `$hasAvailableFlag` - Detects both `available` and `is_available` columns
- `$hasUnavailableUntil` - Detects `unavailable_until` column

**Updated Logging:**
```php
error_log(sprintf(
    '[AssignmentEngine] filterAvailable schema detected: hasIsActive=%s, hasStatus=%s, hasAvailableFlag=%s, hasUnavailableUntil=%s, idColumn=%s',
    $hasIsActive ? 'true' : 'false',
    $hasStatus ? 'true' : 'false',
    $hasAvailableFlag ? 'true' : 'false',
    $hasUnavailableUntil ? 'true' : 'false',
    $idColumn
));
```

### New Branch for is_available + unavailable_until Schema

**New Branch Logic:**
```php
elseif ($hasAvailableFlag && $hasUnavailableUntil) {
    // ✅ NEW: Schema 4: is_available + unavailable_until (production schema)
    error_log('[AssignmentEngine] filterAvailable: using is_available/unavailable_until schema with idColumn=' . $idColumn);
    
    // Determine which column name to use (is_available or available)
    $availColName = 'is_available'; // Prefer is_available
    
    $sql = "
        SELECT {$idColumn} AS member_id
        FROM operator_availability
        WHERE {$idColumn} IN ($in)
          AND ({$availColName} = 1 OR {$availColName} IS NULL)
          AND (unavailable_until IS NULL OR unavailable_until <= UTC_TIMESTAMP())
    ";
    
    // Execute query and filter candidates
    // Intersect with original candidateIds to preserve order & safety
}
```

**Filtering Rules:**
- Operator is **available** if:
  - `is_available = 1` OR `is_available IS NULL` (fail-open when not set)
  - AND `unavailable_until IS NULL` OR `unavailable_until <= UTC_TIMESTAMP()`
- Operator is **not available** (filtered out) if:
  - `is_available = 0`
  - OR `unavailable_until > UTC_TIMESTAMP()` (future date)

### Supported Schemas

The function now supports **4 schemas**:

1. **Schema 1: status + date** (Legacy)
   - Columns: `status ENUM('work','leave','sick','overtime')`, `operator_id`, `date`
   - Query: `WHERE status = 'work' AND date = CURDATE()`

2. **Schema 2: is_active + unavailable_until** (Legacy)
   - Columns: `is_active TINYINT`, `id_member`, `unavailable_until`
   - Query: `WHERE is_active=1 AND (unavailable_until IS NULL OR unavailable_until < NOW())`

3. **Schema 3: available** (Legacy)
   - Columns: `available TINYINT(1)`, `id_member`, `date`
   - Query: `WHERE available = 1`

4. **Schema 4: is_available + unavailable_until** ✅ NEW (Production)
   - Columns: `is_available TINYINT(1)`, `id_member`, `unavailable_until`
   - Query: `WHERE (is_available = 1 OR is_available IS NULL) AND (unavailable_until IS NULL OR unavailable_until <= UTC_TIMESTAMP())`

### Key Methods

**AssignmentEngine::filterAvailable()** (Enhanced)
- Location: `source/BGERP/Service/AssignmentEngine.php`
- Changes: Added Schema 4 detection and filtering branch
- Behavior: Recognizes production schema, filters correctly, logs clearly

---

## 5. Guardrails

### Must Not Regress

- ✅ **Fail-open behavior** - Truly unknown schemas still fail-open (assume all available)
- ✅ **Other schema branches** - Schema 1, 2, 3 unchanged
- ✅ **Intersection safety** - Results intersected with original candidates for safety
- ✅ **No schema changes** - Database schema unchanged (only PHP logic)

### Test Coverage

**Integration Test:**
- `testFilterAvailableWithIsAvailableSchema()` - Verifies filtering behavior with `is_available + unavailable_until` schema
- Tests that `is_available=0` operators are filtered out
- Tests that `is_available=1` operators remain
- Tests that `unavailable_until` in future filters operators

**Test File:** `tests/Integration/HatthasilpaAssignmentIntegrationTest.php`

---

## 6. Status

**Status:** ✅ **COMPLETED** (December 2025)

**Implementation:**
- ✅ Schema detection improved (hasAvailableFlag, hasUnavailableUntil)
- ✅ New branch added for `is_available + unavailable_until` schema
- ✅ Logging updated to show new flags
- ✅ No more "Unknown schema" for production schema
- ✅ Fail-open behavior preserved for truly unknown schemas
- ✅ Integration test added
- ✅ All existing tests still pass

**Related Tasks:**
- ✅ Task 6: Operator Availability Fail-Open Logic (December 2025) - Added fail-open for empty table
- ✅ Task 10: Operator Availability Console & Enforcement Flag (December 2025) - Added UI and enforcement

**Documentation:**
- ✅ Implementation summary: `docs/dag/agent-tasks/task4_OPERATOR_AVAILABILITY_SCHEMA.md`

---

## 7. Related Documentation

- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Assignment section
- [task4_OPERATOR_AVAILABILITY_SCHEMA.md](../agent-tasks/task4_OPERATOR_AVAILABILITY_SCHEMA.md) - Detailed implementation summary

---

**Task Completed:** December 2025  
**Implemented By:** AI Agent (Composer)  
**Task Reference:** docs/dag/agent-tasks/task4.md

