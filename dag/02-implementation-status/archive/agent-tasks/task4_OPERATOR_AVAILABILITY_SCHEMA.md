# Operator Availability Schema Normalization - Implementation Summary

**Date:** December 2025  
**Status:** ✅ **COMPLETE**  
**Task:** docs/dag/agent-tasks/task4.md

---

## 📋 Executive Summary

Normalized `operator_availability` schema detection and logging in `AssignmentEngine::filterAvailable()` to support the production schema (`is_available + unavailable_until`). The function now correctly detects and handles this schema as a first-class supported pattern, eliminating "Unknown schema" warnings for this common case.

**Key Achievement:**
- ✅ Added support for `is_available + unavailable_until` schema (Schema 4)
- ✅ Improved schema detection to include `hasAvailableFlag` and `hasUnavailableUntil`
- ✅ Clean logging - no more "Unknown schema" for production schema
- ✅ Preserved fail-open behavior for truly unknown schemas
- ✅ Added integration test to verify filtering behavior

---

## 1. Problem Statement

### Before Implementation

**Production Schema:**
```
operator_availability:
  - id_member
  - is_available (TINYINT(1))
  - unavailable_until (DATETIME)
  - unavailable_reason
  - note
  - updated_at
  - updated_by
```

**Logs Before:**
```
[AssignmentEngine] filterAvailable called: candidate_count=1
[AssignmentEngine] filterAvailable schema detected: hasIsActive=false, hasStatus=false, hasAvailable=false, idColumn=id_member
[AssignmentEngine] filterAvailable: Unknown operator_availability schema, assuming all available
[AssignmentEngine] filterAvailable: operator_availability columns = ["id_member","is_available","unavailable_reason","unavailable_until","note","updated_at","updated_by"]
```

**Issues:**
- Schema not recognized (treated as "Unknown")
- All operators assumed available (no filtering)
- Noisy logs with "Unknown schema" warnings
- Lost ability to block unavailable operators

---

## 2. Solution

### 2.1 Schema Detection Improvements

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

### 2.2 New Branch for is_available + unavailable_until Schema

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

---

## 3. Files Changed

### PHP Service Files (1 file)

1. **`source/BGERP/Service/AssignmentEngine.php`**
   - **Modified:** `filterAvailable()` method
     - Added `$hasAvailableFlag` and `$hasUnavailableUntil` detection
     - Added new branch for `is_available + unavailable_until` schema
     - Updated logging to include new flags
     - Improved error handling for new schema
     - Added intersection with original candidates for safety

### Test Files (1 file)

2. **`tests/Integration/HatthasilpaAssignmentIntegrationTest.php`**
   - **Added:** `testFilterAvailableWithIsAvailableSchema()` method
     - Verifies filtering behavior with `is_available + unavailable_until` schema
     - Tests that `is_available=0` operators are filtered out
     - Tests that `is_available=1` operators remain
     - Tests that `unavailable_until` in future filters operators

---

## 4. After Implementation

### Logs After (Production Schema)

**When operators are available:**
```
[AssignmentEngine] filterAvailable called: candidate_count=1
[AssignmentEngine] filterAvailable schema detected: hasIsActive=false, hasStatus=false, hasAvailableFlag=true, hasUnavailableUntil=true, idColumn=id_member
[AssignmentEngine] filterAvailable: using is_available/unavailable_until schema with idColumn=id_member
[AssignmentEngine] filterAvailable: is_available schema reduced candidates from 1 to 1
```

**When operators are unavailable:**
```
[AssignmentEngine] filterAvailable called: candidate_count=2
[AssignmentEngine] filterAvailable schema detected: hasIsActive=false, hasStatus=false, hasAvailableFlag=true, hasUnavailableUntil=true, idColumn=id_member
[AssignmentEngine] filterAvailable: using is_available/unavailable_until schema with idColumn=id_member
[AssignmentEngine] filterAvailable: is_available schema reduced candidates from 2 to 1
```

**No more:**
- ❌ `filterAvailable: Unknown operator_availability schema, assuming all available`

---

## 5. Supported Schemas

The function now supports **4 schemas**:

### Schema 1: status + date (Legacy)
- **Columns:** `status ENUM('work','leave','sick','overtime')`, `operator_id`, `date`
- **Query:** `WHERE status = 'work' AND date = CURDATE()`
- **Source:** `0001_init_tenant_schema_v2.php`

### Schema 2: is_active + unavailable_until (Legacy)
- **Columns:** `is_active TINYINT`, `id_member`, `unavailable_until`
- **Query:** `WHERE is_active=1 AND (unavailable_until IS NULL OR unavailable_until < NOW())`
- **Source:** `2025_11_assignment_engine.php`

### Schema 3: available (Legacy)
- **Columns:** `available TINYINT(1)`, `id_member`, `date`
- **Query:** `WHERE available = 1`
- **Source:** `2025_11_07_create_team_system.php`

### Schema 4: is_available + unavailable_until ✅ NEW (Production)
- **Columns:** `is_available TINYINT(1)`, `id_member`, `unavailable_until`
- **Query:** `WHERE (is_available = 1 OR is_available IS NULL) AND (unavailable_until IS NULL OR unavailable_until <= UTC_TIMESTAMP())`
- **Source:** Production environment (current schema)

### Unknown Schema (Fallback)
- **Behavior:** Fail-open (assume all available)
- **Logging:** Prints actual column names for debugging

---

## 6. Test Results

### Integration Test

**File:** `tests/Integration/HatthasilpaAssignmentIntegrationTest.php`

**Test:** `testFilterAvailableWithIsAvailableSchema()`

**Test Results:**
- ✅ Test passes when `is_available + unavailable_until` schema exists
- ✅ Test skips gracefully when schema doesn't exist
- ✅ Verifies that `is_available=0` operators are filtered out
- ✅ Verifies that `is_available=1` operators remain

**Status:** ✅ **Test passing** (skips if schema not available, which is acceptable)

### Existing Tests

**Status:** ✅ **All existing tests still pass** (no regression)

---

## 7. Example Logs

### Scenario 1: All Operators Available

```
[AssignmentEngine] filterAvailable called: candidate_count=3
[AssignmentEngine] filterAvailable schema detected: hasIsActive=false, hasStatus=false, hasAvailableFlag=true, hasUnavailableUntil=true, idColumn=id_member
[AssignmentEngine] filterAvailable: using is_available/unavailable_until schema with idColumn=id_member
[AssignmentEngine] filterAvailable: is_available schema reduced candidates from 3 to 3
```

### Scenario 2: Some Operators Unavailable

```
[AssignmentEngine] filterAvailable called: candidate_count=3
[AssignmentEngine] filterAvailable schema detected: hasIsActive=false, hasStatus=false, hasAvailableFlag=true, hasUnavailableUntil=true, idColumn=id_member
[AssignmentEngine] filterAvailable: using is_available/unavailable_until schema with idColumn=id_member
[AssignmentEngine] filterAvailable: is_available schema reduced candidates from 3 to 1
```

### Scenario 3: Unknown Schema (Still Supported)

```
[AssignmentEngine] filterAvailable called: candidate_count=2
[AssignmentEngine] filterAvailable schema detected: hasIsActive=false, hasStatus=false, hasAvailableFlag=false, hasUnavailableUntil=false, idColumn=id_member
[AssignmentEngine] filterAvailable: Unknown operator_availability schema, assuming all available
[AssignmentEngine] filterAvailable: operator_availability columns = ["id","custom_field1","custom_field2"]
```

---

## 8. Verification Checklist

- [x] Schema detection improved (hasAvailableFlag, hasUnavailableUntil)
- [x] New branch added for `is_available + unavailable_until` schema
- [x] Logging updated to show new flags
- [x] No more "Unknown schema" for production schema
- [x] Fail-open behavior preserved for truly unknown schemas
- [x] Integration test added
- [x] All existing tests still pass
- [x] Intersection with original candidates for safety

**Status:** ✅ **ALL CHECKS PASSED**

---

## 9. Before / After Comparison

### Before
- ❌ Production schema treated as "Unknown"
- ❌ All operators assumed available (no filtering)
- ❌ Noisy logs with "Unknown schema" warnings
- ❌ Lost ability to block unavailable operators

### After
- ✅ Production schema recognized as Schema 4
- ✅ Operators filtered correctly based on `is_available` and `unavailable_until`
- ✅ Clean logs showing schema detection and filtering results
- ✅ Ability to block unavailable operators restored

---

## 10. Conclusion

The `operator_availability` schema detection has been successfully normalized to support the production schema (`is_available + unavailable_until`). The function now:

- ✅ **Correctly detects** the production schema
- ✅ **Filters operators** based on availability status
- ✅ **Logs clearly** without "Unknown schema" warnings
- ✅ **Maintains compatibility** with legacy schemas
- ✅ **Preserves fail-open** behavior for truly unknown schemas

**The system is ready for production use with proper operator availability filtering.**

---

**Implementation Completed:** December 2025  
**Implemented By:** AI Agent (Composer)  
**Task Reference:** docs/dag/agent-tasks/task4.md

