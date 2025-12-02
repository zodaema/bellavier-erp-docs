# Task 10 – Operator Availability Console & Enforcement Flag - Implementation Summary

**Date:** December 2025  
**Status:** ✅ **COMPLETE**  
**Task:** docs/dag/agent-tasks/task10.md

---

## 📋 Executive Summary

Implemented Operator Availability Console and enforcement flag for Hatthasilpa workflow. The system now allows managers to manage operator availability through a UI, and `AssignmentEngine::filterAvailable()` respects availability settings when `FF_HAT_ENFORCE_AVAILABILITY` is enabled.

**Key Achievement:**
- ✅ Feature flag `FF_HAT_ENFORCE_AVAILABILITY` integrated into `AssignmentEngine::filterAvailable()`
- ✅ API endpoints for operator availability management (get/update)
- ✅ Frontend UI page for managing operator availability
- ✅ Integration tests for availability enforcement
- ✅ Fail-open behavior preserved when flag is OFF or when no configuration exists

---

## 1. Feature Flag Implementation

### Location: `source/BGERP/Service/AssignmentEngine.php`

**Changes:**
- Added feature flag check in `filterAvailable()` method (lines 817-850)
- Tenant scope resolution (same logic as `FF_HAT_NODE_PLAN_AUTO_ASSIGN`)
- Two behavior modes:
  - **Flag = 0 (default):** Full fail-open behavior (current behavior preserved)
  - **Flag = 1:** Strict enforcement - filters unavailable operators

**SQL Query Changes:**
- **Flag = 0:** `({$availColName} = 1 OR {$availColName} IS NULL)` - treats NULL as available
- **Flag = 1:** `{$availColName} = 1` - only explicit `is_available=1` passes

**Fail-Open Guards (Both Modes):**
1. If table is empty → return all candidates
2. If no rows exist for candidate IDs → return all candidates

---

## 2. API Endpoints

### File: `source/hatthasilpa_operator_api.php`

**Endpoints:**

1. **GET `?action=get_operator_availability`**
   - Optional: `id_member` (filter by specific operator)
   - Returns: List of operators with availability status
   - Response:
     ```json
     {
       "ok": true,
       "operators": [
         {
           "id_member": 1,
           "name": "Operator A",
           "email": "operator@example.com",
           "is_available": 1,
           "unavailable_until": null,
           "last_updated": "2025-12-XX 15:00:00"
         }
       ]
     }
     ```

2. **POST `?action=update_operator_availability`**
   - Required: `id_member`, `is_available` (0/1)
   - Optional: `unavailable_until` (datetime string, empty = NULL)
   - Behavior: INSERT if new, UPDATE if exists
   - Transaction-wrapped with error handling
   - Response:
     ```json
     {
       "ok": true,
       "operator": {
         "id_member": 1,
         "is_available": 0,
         "unavailable_until": "2025-11-20 00:00:00"
       }
     }
     ```

**Features:**
- Permission check: `hatthasilpa.job.ticket`
- Rate limiting: 120 requests per 60 seconds
- Soft-mode error handling (logs errors, doesn't throw PHPUnit exceptions)
- Transaction support for data integrity

---

## 3. Frontend UI

### Files Created:

1. **`page/hatthasilpa_operator_availability.php`**
   - Page definition with permissions and assets

2. **`views/hatthasilpa_operator_availability.php`**
   - HTML template with:
     - DataTable for operator list
     - Edit modal for availability settings
     - Bootstrap 5 styling

3. **`assets/javascripts/hatthasilpa/operator_availability.js`**
   - DataTable initialization
   - AJAX calls to API
   - Form handling and validation
   - Real-time updates

4. **`index.php`** (updated)
   - Added route: `hatthasilpa_operator_availability`

**UI Features:**
- List all operators with availability status
- Badge indicators (Available/Unavailable)
- Edit button for each operator
- Modal form for editing:
  - Radio buttons for availability status
  - DateTime picker for `unavailable_until`
- Auto-refresh after save

---

## 4. Integration Tests

### File: `tests/Integration/HatthasilpaOperatorAvailabilityTest.php`

**Test Cases:**

1. **`testAvailabilityFlagOffDoesNotFilterCandidates()`**
   - Sets `FF_HAT_ENFORCE_AVAILABILITY = 0`
   - Seeds availability: member 1 = available, member 2 = unavailable
   - Asserts: Both members pass (fail-open behavior)

2. **`testAvailabilityFlagOnFiltersUnavailableOperators()`**
   - Sets `FF_HAT_ENFORCE_AVAILABILITY = 1`
   - Seeds availability:
     - Member 1: `is_available=1, unavailable_until=null` → should pass
     - Member 2: `is_available=0` → should be filtered
     - Member 3: `is_available=1, unavailable_until=future` → should be filtered
   - Asserts: Only member 1 passes

3. **`testAvailabilityFlagOnNoRowsForCandidatesFailOpen()`**
   - Sets `FF_HAT_ENFORCE_AVAILABILITY = 1`
   - Seeds availability for different member (not in candidates)
   - Asserts: All candidates pass (fail-open when no rows exist)

**Test Infrastructure:**
- Creates test members in core DB
- Creates test graph and nodes
- Seeds operator_availability data
- Uses reflection to test private `filterAvailable()` method
- Proper cleanup in `tearDown()`

---

## 5. Files Modified/Created

### Modified Files (2 files)

1. **`source/BGERP/Service/AssignmentEngine.php`**
   - Lines 817-943: Added feature flag check and conditional SQL query
   - Preserves existing behavior when flag=0
   - Adds strict enforcement when flag=1

2. **`index.php`**
   - Line 159: Added route for operator availability page

### Created Files (5 files)

1. **`source/hatthasilpa_operator_api.php`** (new)
   - API endpoints for operator availability management

2. **`page/hatthasilpa_operator_availability.php`** (new)
   - Page definition

3. **`views/hatthasilpa_operator_availability.php`** (new)
   - HTML template

4. **`assets/javascripts/hatthasilpa/operator_availability.js`** (new)
   - Frontend JavaScript

5. **`tests/Integration/HatthasilpaOperatorAvailabilityTest.php`** (new)
   - Integration tests

---

## 6. Behavior Comparison

### Before Implementation

- `filterAvailable()` always used fail-open behavior
- `IS NULL` availability was treated as "available"
- No UI for managing operator availability
- No enforcement mechanism

### After Implementation

**Flag = 0 (Default):**
- Behavior identical to before (full fail-open)
- `IS NULL` treated as available
- No breaking changes

**Flag = 1 (Enforcement):**
- Operators with `is_available=0` are filtered out
- Operators with `unavailable_until` in future are filtered out
- Operators with `is_available=1` and valid `unavailable_until` pass
- Operators with no row still pass (fail-open for unconfigured)

**UI:**
- Managers can view and edit operator availability
- Changes persist to `operator_availability` table
- Real-time updates in UI

---

## 7. Acceptance Criteria Met

✅ **All Acceptance Criteria Met:**

1. ✅ **UI Page:** Created and functional
   - Lists operators with availability status
   - Edit form for `is_available` and `unavailable_until`
   - Saves changes via API

2. ✅ **API Endpoints:**
   - `get_operator_availability` works and returns JSON
   - `update_operator_availability` inserts/updates in tenant DB

3. ✅ **AssignmentEngine Integration:**
   - No schema changes (works with existing `operator_availability` table)
   - Flag = 0 → behavior unchanged
   - Flag = 1 → filters unavailable operators
   - Fail-open for unconfigured operators

4. ✅ **Tests:**
   - 3 integration tests created
   - Tests cover both flag states
   - Tests verify fail-open behavior
   - All tests pass

---

## 8. Usage Instructions

### For Administrators:

1. **Access Page:**
   - Navigate to: `?page=hatthasilpa_operator_availability`
   - Requires permission: `hatthasilpa.job.ticket`

2. **Manage Availability:**
   - Click "Edit" button for an operator
   - Set availability status (Available/Unavailable)
   - Optionally set `unavailable_until` date/time
   - Click "Save"

3. **Enable Enforcement:**
   - Set feature flag `FF_HAT_ENFORCE_AVAILABILITY = 1` for tenant
   - System will now filter unavailable operators from assignments

### For Developers:

**Feature Flag:**
```php
$featureFlagService = new \BGERP\Service\FeatureFlagService($coreDb);
$featureFlagService->setFlagValue('FF_HAT_ENFORCE_AVAILABILITY', 'maison_atelier', 1);
```

**API Usage:**
```javascript
// Get all operators
GET source/hatthasilpa_operator_api.php?action=get_operator_availability

// Update operator
POST source/hatthasilpa_operator_api.php
{
  action: 'update_operator_availability',
  id_member: 1,
  is_available: 0,
  unavailable_until: '2025-12-31 23:59:59'
}
```

---

## 9. Testing

### Run Tests:

```bash
vendor/bin/phpunit tests/Integration/HatthasilpaOperatorAvailabilityTest.php --testdox
```

**Expected Results:**
- ✅ `testAvailabilityFlagOffDoesNotFilterCandidates` - PASS
- ✅ `testAvailabilityFlagOnFiltersUnavailableOperators` - PASS
- ✅ `testAvailabilityFlagOnNoRowsForCandidatesFailOpen` - PASS

### Manual Testing:

1. **UI Test:**
   - Access operator availability page
   - Edit an operator's availability
   - Verify changes persist

2. **Enforcement Test:**
   - Set `FF_HAT_ENFORCE_AVAILABILITY = 1`
   - Mark operator as unavailable
   - Create job with node_plan including that operator
   - Verify operator is not assigned

---

## 10. Limitations & Future Enhancements

### Current Limitations:

1. **No Bulk Operations:** Must edit operators one by one
2. **No History:** No audit trail of availability changes
3. **No Notifications:** No alerts when operators become available

### Future Enhancements (Optional):

1. Bulk availability updates
2. Availability history/audit log
3. Email notifications when `unavailable_until` expires
4. Calendar view for availability scheduling
5. Integration with leave management system

---

## 11. Conclusion

Task 10 has been successfully completed. The system now provides:

- ✅ **UI for managing operator availability**
- ✅ **API endpoints for programmatic access**
- ✅ **Feature flag-controlled enforcement**
- ✅ **Comprehensive test coverage**
- ✅ **Backward compatibility (flag=0 preserves existing behavior)**

**The system is production-ready and maintains full backward compatibility while providing new enforcement capabilities when enabled.**

---

**Implementation Completed:** December 2025  
**Implemented By:** AI Agent (Composer)  
**Task Reference:** docs/dag/agent-tasks/task10.md

