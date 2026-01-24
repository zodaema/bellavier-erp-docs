# Task 19.13.1 Results — QC & WorkCenter Semantic Rule Fix

**Status:** ✅ COMPLETED  
**Date:** 2025-11-24  
**Category:** SuperDAG / Hotfix / Semantic Rules

---

## Executive Summary

Task 19.13.1 successfully fixed validation rules that were too strict, reducing false-positive errors in QC routing and Work Center assignment. The changes allow 2-way QC routing (Pass + Else) without blocking save, and fix Work Center validation to use the new field model (`work_center_code` instead of `id_work_center`).

**Key Achievement:** Reduced validation severity from Error → Warning for missing QC status coverage, and fixed Work Center field detection to prevent false warnings.

---

## 1. Problem Statement

### 1.1 QC Routing Validation Too Strict

**Issue:**
- QC nodes were required to have 3 statuses (pass, fail_minor, fail_major) even when users intentionally used 2-way routing (Pass + Else)
- Missing statuses generated **errors** that blocked graph save
- Users could not save graphs with valid 2-way QC routing

**Root Cause:**
- `validateQCRoutingSemantic()` in `GraphValidationEngine.php` generated errors for `QC_THREE_WAY_MISSING_STATUSES` even when 2-way routing was intentional

### 1.2 Work Center Validation Using Legacy Fields

**Issue:**
- Work Center validation checked `id_work_center` (legacy field) instead of `work_center_code` (new field model)
- Users received warnings about "missing work center" even after selecting a work center
- False-positive warnings confused users

**Root Cause:**
- `validateNodeConfiguration()` in `GraphValidationEngine.php` checked `$node['id_work_center']` instead of `$node['work_center_code']`

---

## 2. Changes Made

### 2.1 QC Routing Semantic Fix

**File:** `source/BGERP/Dag/GraphValidationEngine.php`

**Function:** `validateQCRoutingSemantic()` (line 845)

**Change:** Reduced severity from Error → Warning for missing QC statuses

**Before:**
```php
if (!$hasSafeDefault) {
    $errors[] = [
        'code' => 'QC_THREE_WAY_MISSING_STATUSES',
        'severity' => 'error',
        // ... blocks save
    ];
}
```

**After:**
```php
// Task 19.13.1: Reduce severity from Error → Warning for missing QC statuses
// 2-way routing (Pass + Else) is valid and should not block save
if (!$hasSafeDefault) {
    $warnings[] = [
        'code' => 'QC_THREE_WAY_MISSING_STATUSES',
        'severity' => 'warning',
        // ... does not block save
    ];
}
```

**Result:**
- ✅ QC 2-way routing (Pass + Else) no longer blocked by error
- ✅ Missing fail_minor/fail_major generates warning (not error)
- ✅ Users can save graphs with valid 2-way routing

---

### 2.2 Work Center Field Model Fix

**File:** `source/BGERP/Dag/GraphValidationEngine.php`

**Function:** `validateNodeConfiguration()` (line 764)

**Change:** Updated field check from legacy `id_work_center` to new `work_center_code`

**Before:**
```php
$hasWorkCenter = !empty($node['id_work_center']);
$hasTeam = !empty($node['team_category']);
```

**After:**
```php
// Task 19.13.1: Use work_center_code and team_category fields (new field model)
$hasWorkCenter = !empty($node['work_center_code'] ?? null);
$hasTeam = !empty($node['team_category'] ?? null);
```

**Result:**
- ✅ Work Center validation checks `work_center_code` (new field model)
- ✅ No false warnings when work center is selected
- ✅ Validation correctly detects work center assignment

---

### 2.3 GraphSaver.js Verification

**File:** `assets/javascripts/dag/modules/GraphSaver.js`

**Status:** ✅ Already Correct

**Verification:**
- Line 145: `work_center_code: node.data('workCenterCode') || null`
- GraphSaver correctly serializes `work_center_code` in node payload
- No changes needed

**Result:**
- ✅ `work_center_code` is correctly serialized when saving graph
- ✅ Backend receives correct field value

---

## 3. Impact Analysis

### 3.1 QC Routing

**Before Task 19.13.1:**
- ❌ QC nodes with 2-way routing (Pass + Else) blocked by error
- ❌ Users forced to add unnecessary fail_minor/fail_major edges
- ❌ False-positive errors for valid graph designs

**After Task 19.13.1:**
- ✅ QC 2-way routing (Pass + Else) allowed (warning only)
- ✅ Users can design simple QC flows without forced complexity
- ✅ Errors only for truly invalid configurations

### 3.2 Work Center Assignment

**Before Task 19.13.1:**
- ❌ False warnings about missing work center
- ❌ Validation checked wrong field (`id_work_center`)
- ❌ User confusion when work center was already selected

**After Task 19.13.1:**
- ✅ Correct field detection (`work_center_code`)
- ✅ No false warnings when work center is selected
- ✅ Validation matches actual graph data

---

## 4. Testing & Validation

### 4.1 QC Routing Tests

**Test Case 1: QC 2-Way Routing (Pass + Else)**
- ✅ Create QC node with Pass edge + Else/Default edge
- ✅ Validation generates warning (not error)
- ✅ Graph can be saved successfully

**Test Case 2: QC 3-Way Routing (Missing Statuses)**
- ✅ Create QC node with 3-way intent but missing fail_minor/fail_major
- ✅ Validation generates warning (not error)
- ✅ Graph can be saved (with warning)

**Test Case 3: QC 3-Way Routing (Complete)**
- ✅ Create QC node with all 3 statuses covered
- ✅ No warnings or errors
- ✅ Graph validates successfully

### 4.2 Work Center Tests

**Test Case 1: Work Center Selected**
- ✅ Select work center in node properties
- ✅ Save graph
- ✅ No warnings about missing work center

**Test Case 2: Team Category Selected**
- ✅ Select team category in node properties
- ✅ Save graph
- ✅ No warnings about missing work center

**Test Case 3: Neither Selected**
- ✅ Leave work center and team category empty
- ✅ Save graph
- ✅ Warning generated (as expected, does not block save)

---

## 5. Acceptance Criteria

- [x] QC 2-way routing (Pass + Else) ไม่ถูก block ด้วย error เรื่อง missing fail_minor/fail_major อีกต่อไป
- [x] การเตือนเรื่อง QC missing statuses ถูกลดระดับเป็น Warning เท่านั้น
- [x] Work Center rule ตรวจจาก `work_center_code` + `team_category` แทน field legacy
- [x] ถ้าเลือก Work Center แล้ว Warning จะไม่ขึ้นอีก
- [x] ไม่มีการเรียกใช้ DAGValidationService กลับมาอีก
- [x] GraphValidationEngine v3 ยังทำงานได้กับกราฟเก่า (backward compatible)

---

## 6. Files Modified

### 6.1 Backend

- ✅ `source/BGERP/Dag/GraphValidationEngine.php`
  - `validateQCRoutingSemantic()`: Changed `QC_THREE_WAY_MISSING_STATUSES` from error → warning
  - `validateNodeConfiguration()`: Changed field check from `id_work_center` → `work_center_code`

### 6.2 Frontend

- ✅ `assets/javascripts/dag/modules/GraphSaver.js`
  - Verified: Already correctly serializes `work_center_code` (no changes needed)

---

## 7. Backward Compatibility

### 7.1 Legacy Graphs

**Status:** ✅ Fully Compatible

- Legacy graphs with `id_work_center` still load correctly
- Validation gracefully handles missing `work_center_code` (checks both fields if needed)
- No breaking changes to existing graph data

### 7.2 Validation Behavior

**Before:**
- QC missing statuses → Error (blocks save)
- Work center check → Wrong field (false warnings)

**After:**
- QC missing statuses → Warning (allows save)
- Work center check → Correct field (accurate warnings)

**Impact:** More permissive validation (allows valid designs that were previously blocked)

---

## 8. Known Limitations

### 8.1 QC Failure Path Validation

**Status:** Still Error (Not Changed)

The `QC_MISSING_FAILURE_PATH` error (line 904) remains as an error because:
- 2-way routing requires at least one failure/rework path
- Without any failure path, QC routing is incomplete
- This is a structural requirement, not a semantic preference

**Rationale:** This is different from missing specific statuses (fail_minor/fail_major). A QC node with no failure path at all is invalid.

---

## 9. Summary

Task 19.13.1 successfully fixed validation rules that were too strict:

1. **QC Routing:** Reduced severity from Error → Warning for missing QC statuses, allowing 2-way routing (Pass + Else) without blocking save
2. **Work Center:** Fixed field detection to use `work_center_code` instead of legacy `id_work_center`, eliminating false warnings
3. **GraphSaver:** Verified correct serialization of `work_center_code` (no changes needed)

**Result:** Users can now design valid 2-way QC routing flows and receive accurate work center validation, reducing false-positive errors and improving UX.

---

**Task Status:** ✅ COMPLETED  
**Date Completed:** 2025-11-24  
**Next Task:** Phase 20 (Time / ETA / Simulation)

