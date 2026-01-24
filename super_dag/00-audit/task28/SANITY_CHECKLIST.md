# Task 28.x - Sanity Checklist (Definition of Done)
**Date:** 2025-12-13  
**Status:** ⚠️ **PENDING TESTING**  
**Purpose:** Gate for Task 28.x Completion - All items must pass before closing

---

## Overview

This checklist verifies that all fixes for Graph Versioning & Immutability are working correctly. All 17 test cases must pass without workarounds.

---

## ✅ Immutability Tests

### Test 1: Published Graph → Save Fails
**Action:**
1. Open a Published graph (status = 'published')
2. Make a change (e.g., move a node, change node property)
3. Click "Save" button

**Expected:**
- ❌ Save fails with 403 error
- ✅ Modal appears: "Cannot save to Published graph. Create a Draft version to make changes."
- ✅ Graph remains unchanged

**Status:** ⏳ Pending

---

### Test 2: Published Graph → Autosave Blocked
**Action:**
1. Open a Published graph
2. Make a change (move node)
3. Wait for autosave to trigger (or trigger manually)

**Expected:**
- ❌ Autosave fails with 403 error
- ✅ Graph remains unchanged
- ✅ No draft created automatically

**Status:** ⏳ Pending

---

### Test 3: Published Graph → Node Update Blocked
**Action:**
1. Open a Published graph
2. Open node properties panel
3. Change a property (e.g., node name)
4. Save property changes

**Expected:**
- ❌ Property update fails with 403 error
- ✅ Modal: "Cannot save to Published graph. Create a Draft version to make changes."

**Status:** ⏳ Pending

---

### Test 4: Retired Graph → Same as Published
**Action:**
1. Open a Retired graph (status = 'retired')
2. Make a change
3. Try to save

**Expected:**
- ❌ Save fails with 403 error (same as Published)
- ✅ Treated as immutable

**Status:** ⏳ Pending

---

## ✅ Draft Workflow Tests

### Test 5: Draft-Only Graph → Fully Editable
**Action:**
1. Create new graph (no published versions exist)
2. Make changes
3. Save

**Expected:**
- ✅ Save succeeds
- ✅ Status = 'draft'
- ✅ All operations work normally

**Status:** ⏳ Pending

---

### Test 6: Create Draft from Published → Editable
**Action:**
1. Open Published graph
2. Click "Create Draft" button
3. Make changes
4. Save

**Expected:**
- ✅ Draft created successfully
- ✅ Draft is fully editable
- ✅ Published version remains unchanged

**Status:** ⏳ Pending

---

### Test 7: Discard Draft → Returns to Published
**Action:**
1. Have an active draft for a Published graph
2. Click "Discard Draft" button
3. Confirm discard

**Expected:**
- ✅ Draft is deleted
- ✅ Graph view returns to latest Published version
- ✅ Published version unchanged

**Status:** ⏳ Pending

---

## ✅ Version Switching Tests

### Test 8: Switch Versions → No State Corruption
**Action:**
1. Open graph with multiple versions
2. Switch between versions 10+ times rapidly
3. Check UI state after each switch

**Expected:**
- ✅ No duplicate event listeners
- ✅ Read-only state updates correctly
- ✅ Version selector shows correct version
- ✅ Status badge updates correctly
- ✅ Graph loads correctly each time

**Status:** ⏳ Pending

---

### Test 9: Switch Published → Draft → Published
**Action:**
1. Open Published version
2. Switch to Draft (if exists)
3. Switch back to Published

**Expected:**
- ✅ Label/icon updates correctly
- ✅ Read-only state toggles correctly
- ✅ Save button enabled/disabled correctly

**Status:** ⏳ Pending

---

## ✅ Validation Tests

### Test 10: Validate Design → Uses UI State
**Action:**
1. Open Draft graph
2. Make changes in UI (don't save)
3. Click "Validate" button

**Expected:**
- ✅ Validation uses current UI state (not DB state)
- ✅ Validation results match what user sees

**Status:** ⏳ Pending

---

### Test 11: Validate with Context Parameter
**Action:**
1. Open graph
2. Run validation
3. Check network tab for API request

**Expected:**
- ✅ Request includes `context: 'design'` parameter
- ✅ Backend receives context correctly

**Status:** ⏳ Pending

---

### Test 12: AutoFix Shows Reason When No Fixes
**Action:**
1. Create graph with unfixable errors (e.g., missing START node)
2. Run validation
3. Check validation response

**Expected:**
- ✅ Response includes `fix_count: 0`
- ✅ Response includes `unfixable_reasons` array
- ✅ Reasons explain why no fixes available

**Status:** ⏳ Pending

---

## ✅ Product Viewer Isolation Tests

### Test 13: Product Viewer → Only Published/Retired
**Action:**
1. Open product modal/viewer
2. Check graph versions shown

**Expected:**
- ✅ Only Published and Retired versions visible
- ✅ Draft versions NOT visible
- ✅ Cannot select Draft for product binding

**Status:** ⏳ Pending

---

### Test 14: Product Binding → Uses Published Version
**Action:**
1. Bind product to graph
2. Check which version is used

**Expected:**
- ✅ Product uses Published version (not Draft)
- ✅ GraphVersionResolver selects correctly

**Status:** ⏳ Pending

---

## ✅ Edge Cases

### Test 15: New Graph → Starts as Draft
**Action:**
1. Create completely new graph (never published)
2. Check initial status

**Expected:**
- ✅ Status = 'draft'
- ✅ Graph is editable
- ✅ Can save normally

**Status:** ⏳ Pending

---

### Test 16: First Publish → Version 1.0
**Action:**
1. Create new graph
2. Publish for first time
3. Check version number

**Expected:**
- ✅ Version = "1.0" (not "2.0")
- ✅ Correct versioning logic

**Status:** ⏳ Pending

---

### Test 17: Version Selector → Shows Correct Versions
**Action:**
1. Open graph with Published versions and active Draft
2. Check version selector dropdown

**Expected:**
- ✅ Draft shows next version number (e.g., "v2.0" not "vdraft")
- ✅ Published versions show correctly
- ✅ Icons match status (lock for published, pencil for draft)

**Status:** ⏳ Pending

---

## Summary

| Category | Tests | Passed | Failed | Pending |
|----------|-------|--------|--------|---------|
| Immutability | 4 | 0 | 0 | 4 |
| Draft Workflow | 3 | 0 | 0 | 3 |
| Version Switching | 2 | 0 | 0 | 2 |
| Validation | 3 | 0 | 0 | 3 |
| Product Isolation | 2 | 0 | 0 | 2 |
| Edge Cases | 3 | 0 | 0 | 3 |
| **Total** | **17** | **0** | **0** | **17** |

---

## Test Execution Instructions

1. **Setup:**
   - Ensure all fixes are deployed
   - Have test graphs ready (Published, Draft, Retired states)
   - Have browser DevTools open (Network tab, Console)

2. **Execution:**
   - Run tests in order
   - Mark each test as ✅ Pass or ❌ Fail
   - Document any issues found

3. **Completion:**
   - All 17 tests must pass
   - No workarounds allowed
   - Update status table above

---

## Notes

- **Blocking:** If any Test 1-4 (Immutability) fails, Task 28.x **MUST NOT** be closed
- **Critical:** Tests 8-9 (Version Switching) must pass for production readiness
- **Documentation:** All failures must be documented with reproduction steps

---

## Related Documents

- `AUDIT_EXECUTIVE_SUMMARY.md` - Complete audit findings
- `AUDIT_REPORT_GRAPH_VERSIONING.md` - Detailed audit report
- `P0_P1_FIXES_COMPLETE.md` - Fix implementation summary

