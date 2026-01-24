# Task 28.x - Test Execution Guide
**Date:** 2025-12-13  
**Purpose:** Guide for executing Sanity Tests

---

## Test Files Created

### Automated Tests (PHPUnit)
- **File:** `tests/Integration/Task28_ImmutabilitySanityTest.php`
- **Coverage:** Core immutability tests (Tests 1, 2, 4, 5, 11, 12)
- **Status:** ✅ Created, ready for execution

### Manual Tests (Browser)
- **File:** `SANITY_CHECKLIST.md`
- **Coverage:** All 17 test cases (including UI/UX tests)
- **Status:** ⏳ Requires browser testing

---

## Running Automated Tests

### Prerequisites
1. PHPUnit installed (via Composer)
2. Test database configured
3. Test tenant setup (`maison_atelier`)

### Command
```bash
# Run all Task 28 tests
vendor/bin/phpunit tests/Integration/Task28_ImmutabilitySanityTest.php --testdox

# Run specific test
vendor/bin/phpunit tests/Integration/Task28_ImmutabilitySanityTest.php::testPublishedGraphSaveFails --testdox
```

### Expected Results

**Test 1: Published Graph Save Fails**
- ✅ Should return `ok: false`
- ✅ Should have `app_code: 'DAG_ROUTING_403_PUBLISHED_IMMUTABLE'`
- ✅ Should contain error message about Published graph

**Test 2: Published Graph Autosave Blocked**
- ✅ Should return `ok: false`
- ✅ Should have `app_code: 'DAG_ROUTING_403_PUBLISHED_IMMUTABLE'`
- ✅ Should block even with `save_type: 'autosave'`

**Test 4: Retired Graph Same as Published**
- ✅ Should be treated as immutable
- ✅ Should have same error response

**Test 5: Draft-Only Graph Editable**
- ✅ Should succeed (or fail for validation, not immutability)
- ✅ Should NOT have `DAG_ROUTING_403_PUBLISHED_IMMUTABLE` error

**Test 11: Validate with Context Parameter**
- ✅ Should accept `context` parameter
- ✅ Should not error on context validation

**Test 12: AutoFix Shows Reason When No Fixes**
- ✅ Response should have `fix_count` field
- ✅ If `fix_count === 0`, should have `unfixable_reasons` array

---

## Manual Browser Testing

### Setup
1. Open browser to graph designer
2. Open DevTools (F12)
3. Go to Network tab (for API monitoring)
4. Go to Console tab (for errors)

### Test Execution Order

**Critical Tests (Must Pass):**
1. Test 1: Published Graph → Save Fails
2. Test 2: Published Graph → Autosave Blocked
3. Test 4: Retired Graph → Same as Published

**Workflow Tests:**
5. Test 5: Draft-Only Graph → Fully Editable
6. Test 6: Create Draft from Published → Editable
7. Test 7: Discard Draft → Returns to Published

**Version Switching Tests:**
8. Test 8: Switch Versions → No State Corruption
9. Test 9: Switch Published → Draft → Published

**Validation Tests:**
10. Test 10: Validate Design → Uses UI State
11. Test 11: Validate with Context Parameter
12. Test 12: AutoFix Shows Reason When No Fixes

**Product Isolation Tests:**
13. Test 13: Product Viewer → Only Published/Retired
14. Test 14: Product Binding → Uses Published Version

**Edge Cases:**
15. Test 15: New Graph → Starts as Draft
16. Test 16: First Publish → Version 1.0
17. Test 17: Version Selector → Shows Correct Versions

---

## Test Data Requirements

### Graph States Needed

1. **Published Graph**
   - Status: `published`
   - Has published version record
   - Can be used for Tests 1, 2, 3

2. **Retired Graph**
   - Status: `retired` (version-level)
   - Can be used for Test 4

3. **Draft-Only Graph**
   - Status: `draft`
   - No published versions
   - Can be used for Test 5

4. **Graph with Active Draft**
   - Has published version
   - Has active draft
   - Can be used for Tests 6, 7

5. **Graph with Multiple Versions**
   - Version 1.0 (published)
   - Version 2.0 (retired)
   - Active draft (v3.0)
   - Can be used for Tests 8, 9, 17

---

## Documenting Test Results

### In SANITY_CHECKLIST.md

For each test:
1. Mark status: ⏳ Pending / ✅ Pass / ❌ Fail
2. If fail:
   - Document error message
   - Document reproduction steps
   - Document expected vs actual behavior

### Example Entry

```markdown
### Test 1: Published Graph → Save Fails
**Status:** ✅ Pass

**Results:**
- ✅ Save fails with 403 error
- ✅ Modal appears: "Cannot save to Published graph..."
- ✅ Graph remains unchanged

**Notes:**
- Tested with graph ID 1234
- API returned correct app_code: DAG_ROUTING_403_PUBLISHED_IMMUTABLE
```

---

## Troubleshooting

### Test Failures

**Issue:** Tests fail with "Cannot resolve tenant organization"
- **Fix:** Ensure `$_SESSION['current_org_code']` is set correctly
- **Fix:** Check tenant database exists

**Issue:** Tests fail with "Graph not found"
- **Fix:** Check test graph creation in setUp()
- **Fix:** Verify database connection

**Issue:** API returns wrong error code
- **Fix:** Check graph status in database
- **Fix:** Verify immutability guard code path

### Manual Test Issues

**Issue:** UI not showing correct status
- **Fix:** Check browser console for errors
- **Fix:** Verify API response has correct status field
- **Fix:** Hard refresh (Ctrl+F5) to clear cache

**Issue:** Version selector not updating
- **Fix:** Check Network tab for API calls
- **Fix:** Verify `loadVersionsForSelector()` is called
- **Fix:** Check for JavaScript errors in Console

---

## Success Criteria

All tests pass when:
- ✅ Automated tests: 6/6 pass
- ✅ Manual tests: 17/17 pass
- ✅ No workarounds needed
- ✅ No regression from previous behavior

---

## Related Documents

- `SANITY_CHECKLIST.md` - Complete test cases (17 tests)
- `CODE_REVIEW_SUMMARY.md` - Code review results
- `NEXT_STEPS.md` - Testing execution plan

