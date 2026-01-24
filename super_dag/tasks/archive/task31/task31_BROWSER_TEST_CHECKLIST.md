# Task 31: CUT Timing - Browser Test Checklist

**Date:** 2026-01-13  
**Purpose:** Comprehensive browser testing checklist for CUT timing system  
**Status:** ✅ **READY FOR TESTING**

---

## 🎯 Test Objectives

Verify that all 6 critical SSOT architecture points are working correctly in browser:

1. ✅ NODE_YIELD canonical event whitelist
2. ✅ NODE_YIELD timeline semantics (informational only)
3. ✅ Idempotency/conflict protection (DB + transaction lock)
4. ✅ SSOT time policy (UI never creates authoritative time)
5. ✅ Used area failure modes (3 scenarios)
6. ✅ Documentation numbering

---

## 📋 Pre-Test Setup

### 1. Database Migration

```bash
# Run migration to create cut_session table
php database/tools/run_migrations.php
```

**Verify:**
- [ ] `cut_session` table exists
- [ ] `uk_active_session_key` unique index exists
- [ ] Foreign keys to `flow_token`, `routing_node`, `leather_sheet` exist

### 2. Test Data

**Required:**
- [ ] At least one CUT node in routing graph
- [ ] At least one token at CUT node
- [ ] Product with BOM components configured
- [ ] Material with leather category (for used_area testing)
- [ ] Product component material with `qty_required > 0` and `uom_code = 'sqft'`

---

## 🧪 Test Cases

### Test 1: Start CUT Session (Happy Path)

**Steps:**
1. Open Work Queue page
2. Click on token with CUT node
3. Click "CUT" button
4. Select Component (e.g., BODY)
5. Select Role (e.g., MAIN_MATERIAL)
6. Select Material (e.g., LEATHER-001)
7. Click "Start Cutting"

**Expected Results:**
- [ ] Modal locks (cannot close with X, ESC, or backdrop click)
- [ ] Timer starts from server time (not client time)
- [ ] Phase 2 shows selected component, role, material
- [ ] Session created in `cut_session` table with `status = 'RUNNING'`
- [ ] `started_at` is server time (not client time)
- [ ] Console shows: `[CUT] Session started: session_id=X`

**Verify in Database:**
```sql
SELECT * FROM cut_session WHERE status = 'RUNNING' ORDER BY id_session DESC LIMIT 1;
```
- [ ] `started_at` is recent (within last minute)
- [ ] `component_code`, `role_code`, `material_sku` match selection
- [ ] `operator_id` matches current user
- [ ] `duration_seconds = 0` (not ended yet)

---

### Test 2: Session Idempotency (Same Identity)

**Steps:**
1. Start CUT session (Test 1)
2. Refresh page (F5)
3. Reopen CUT modal
4. Select same Component, Role, Material
5. Click "Start Cutting" again

**Expected Results:**
- [ ] No error (idempotent start)
- [ ] Returns existing session (same `session_id`)
- [ ] Timer continues from original `started_at`
- [ ] Console shows: `[CUT] Idempotent start: session_id=X`

**Verify in Database:**
```sql
SELECT COUNT(*) FROM cut_session WHERE token_id = ? AND node_id = ? AND operator_id = ? AND status = 'RUNNING';
```
- [ ] Count = 1 (only one RUNNING session)

---

### Test 3: Session Conflict (Different Identity)

**Steps:**
1. Start CUT session for Component A, Role A, Material A
2. Try to start another session for Component B, Role B, Material B (same token/node/operator)

**Expected Results:**
- [ ] Error: `CUT_409_SESSION_ALREADY_RUNNING`
- [ ] Error message shows existing session details
- [ ] UI shows conflict dialog with existing session info
- [ ] Option to "Cancel" (abort) existing session or "Use Existing"

**Verify in Database:**
- [ ] Still only 1 RUNNING session (Component A)
- [ ] No duplicate session created

---

### Test 4: Transaction Lock (Race Condition Protection)

**Steps:**
1. Open two browser tabs/windows
2. Both tabs: Same token, same node, same operator
3. Tab 1: Start CUT session (Component A)
4. Tab 2: Immediately try to start CUT session (Component B)

**Expected Results:**
- [ ] Tab 1: Session starts successfully
- [ ] Tab 2: Either:
  - Waits for Tab 1 transaction to complete, then returns conflict error
  - Or: Returns conflict error immediately
- [ ] No duplicate sessions in database
- [ ] Database constraint `uk_active_session_key` prevents duplicates

**Verify in Database:**
```sql
SELECT COUNT(*) FROM cut_session WHERE token_id = ? AND node_id = ? AND operator_id = ? AND status = 'RUNNING';
```
- [ ] Count = 1 (only one RUNNING session)

---

### Test 5: End Session with Used Area (Happy Path - Leather)

**Prerequisites:**
- Material is leather (category contains "leather" or UoM is "sqft")
- Product component material has `qty_required > 0` and `uom_code = 'sqft'`

**Steps:**
1. Start CUT session (Test 1)
2. Enter quantity (e.g., 5)
3. Select leather sheet (if required)
4. Click "Save & End Session"

**Expected Results:**
- [ ] Session ends successfully
- [ ] `used_area` is auto-calculated: `qty_required × qty_cut`
- [ ] "Used Area" input is read-only (shows calculated value)
- [ ] `cut_session.status = 'ENDED'`
- [ ] `cut_session.ended_at` is server time
- [ ] `cut_session.duration_seconds` is server-computed
- [ ] `NODE_YIELD` event created with `used_area` in payload
- [ ] Console shows: `[CUT] Session ended: session_id=X, used_area=Y`

**Verify in Database:**
```sql
SELECT * FROM cut_session WHERE id_session = ?;
```
- [ ] `status = 'ENDED'`
- [ ] `ended_at` is recent (within last minute)
- [ ] `duration_seconds > 0`
- [ ] `used_area = qty_required × qty_cut` (for leather)

```sql
SELECT * FROM token_event WHERE event_type = 'move' AND JSON_EXTRACT(event_data, '$.canonical_type') = 'NODE_YIELD' ORDER BY id_event DESC LIMIT 1;
```
- [ ] `canonical_type = 'NODE_YIELD'` in `event_data`
- [ ] `payload.used_area` matches calculated value
- [ ] `payload.component_code`, `payload.role_code`, `payload.material_sku` match session

---

### Test 6: End Session - Constraints Not Found (Error Case)

**Prerequisites:**
- Material is leather
- Product component material does NOT exist for selected (component, role, material)

**Steps:**
1. Start CUT session with Component/Role/Material that has no BOM line
2. Enter quantity
3. Click "Save & End Session"

**Expected Results:**
- [ ] Error: `CUT_400_CONSTRAINTS_NOT_FOUND`
- [ ] Error message: "Product constraints not found for this component/role/material combination. Cannot compute used_area for leather material."
- [ ] Session remains `RUNNING` (not ended)
- [ ] User must fix component/role/material selection or add BOM line

**Verify in Database:**
```sql
SELECT * FROM cut_session WHERE id_session = ?;
```
- [ ] `status = 'RUNNING'` (not ended)
- [ ] `ended_at IS NULL`
- [ ] No `NODE_YIELD` event created

---

### Test 7: End Session - Invalid Constraints (qty_required = 0)

**Prerequisites:**
- Material is leather
- Product component material exists but `qty_required = 0`

**Steps:**
1. Start CUT session
2. Enter quantity
3. Click "Save & End Session"

**Expected Results:**
- [ ] Error: `CUT_400_INVALID_CONSTRAINTS`
- [ ] Error message: "Invalid constraints: qty_required must be > 0 for leather materials"
- [ ] Session remains `RUNNING` (not ended)
- [ ] User must fix constraints in product BOM

**Verify in Database:**
- [ ] `status = 'RUNNING'` (not ended)
- [ ] No `NODE_YIELD` event created

---

### Test 8: End Session - Non-Leather Material (used_area = null)

**Prerequisites:**
- Material is NOT leather (UoM is not "sqft")
- Product component material exists

**Steps:**
1. Start CUT session with non-leather material
2. Enter quantity
3. Click "Save & End Session"

**Expected Results:**
- [ ] Session ends successfully
- [ ] `used_area = NULL` (acceptable for non-leather)
- [ ] No error about missing constraints
- [ ] `NODE_YIELD` event created with `used_area = null`

**Verify in Database:**
```sql
SELECT * FROM cut_session WHERE id_session = ?;
```
- [ ] `status = 'ENDED'`
- [ ] `used_area IS NULL`

---

### Test 9: Modal Lock & Recovery (Refresh Test)

**Steps:**
1. Start CUT session (Test 1)
2. Refresh page (F5)
3. Reopen CUT modal

**Expected Results:**
- [ ] Modal automatically restores to Phase 2
- [ ] Timer continues from original `started_at` (not reset)
- [ ] Selected component, role, material are restored
- [ ] Modal is locked (cannot close)
- [ ] Console shows: `[CUT] Restored active session: session_id=X`

**Verify:**
- [ ] Backend API `cut_session_get_active` is called on modal open
- [ ] Response contains `status = 'RUNNING'`
- [ ] UI state restored from backend (not localStorage)

---

### Test 10: Modal Lock - Degraded Mode (Backend Failure)

**Steps:**
1. Start CUT session
2. Simulate backend failure (stop server or block API)
3. Refresh page
4. Reopen CUT modal

**Expected Results:**
- [ ] If localStorage has RUNNING hint:
  - [ ] Modal enters "soft-locked" degraded mode
  - [ ] Overlay shows "กำลังตรวจสอบสถานะ/เน็ตมีปัญหา"
  - [ ] "Retry" button available
- [ ] If no localStorage hint:
  - [ ] Modal unlocks
  - [ ] Error message shown

**Verify:**
- [ ] Modal does NOT unlock if localStorage suggests RUNNING session
- [ ] Retry button calls `cut_session_get_active` again

---

### Test 11: Time SSOT (Server Time Only)

**Steps:**
1. Start CUT session
2. Note timer display
3. Change system clock (if possible) or wait 30 seconds
4. Check timer again

**Expected Results:**
- [ ] Timer calculates from server `started_at` + server `now()` (not client `Date.now()`)
- [ ] Timer continues correctly even if client clock changes
- [ ] Backend `duration_seconds` is computed from server time only

**Verify in Database:**
```sql
SELECT started_at, ended_at, duration_seconds, TIMESTAMPDIFF(SECOND, started_at, ended_at) as calculated_duration
FROM cut_session WHERE id_session = ?;
```
- [ ] `duration_seconds` matches `TIMESTAMPDIFF(SECOND, started_at, ended_at)`
- [ ] `started_at` and `ended_at` are server time (not client time)

---

### Test 12: NODE_YIELD Event Creation

**Steps:**
1. Complete CUT session (Test 5)
2. Check `token_event` table

**Expected Results:**
- [ ] `NODE_YIELD` event created in `token_event`
- [ ] `event_type = 'move'` (mapped from canonical type)
- [ ] `event_data.canonical_type = 'NODE_YIELD'`
- [ ] `event_data.payload` contains:
  - `component_code`, `role_code`, `material_sku`
  - `used_area` (for leather)
  - `duration_seconds` (from session)
  - `started_at`, `finished_at` (from session)

**Verify in Database:**
```sql
SELECT 
    id_event,
    event_type,
    JSON_EXTRACT(event_data, '$.canonical_type') as canonical_type,
    JSON_EXTRACT(event_data, '$.payload.component_code') as component_code,
    JSON_EXTRACT(event_data, '$.payload.used_area') as used_area,
    JSON_EXTRACT(event_data, '$.payload.duration_seconds') as duration_seconds
FROM token_event
WHERE JSON_EXTRACT(event_data, '$.canonical_type') = 'NODE_YIELD'
ORDER BY id_event DESC
LIMIT 1;
```
- [ ] Event exists
- [ ] `canonical_type = 'NODE_YIELD'`
- [ ] Payload contains correct data

---

### Test 13: TimeEventReader Ignores NODE_YIELD

**Steps:**
1. Complete CUT session (creates NODE_YIELD event)
2. Check token timeline

**Expected Results:**
- [ ] `TimeEventReader::getTimelineForToken()` does NOT use NODE_YIELD for token timeline
- [ ] Token `start_at` / `completed_at` come from NODE_START / NODE_COMPLETE only
- [ ] NODE_YIELD is informational only (for analytics)

**Verify:**
- [ ] Token timeline does not include NODE_YIELD events
- [ ] Only NODE_START, NODE_PAUSE, NODE_RESUME, NODE_COMPLETE are used for timeline

---

### Test 14: Cancel/Abort Session

**Steps:**
1. Start CUT session
2. Click "Cancel" button

**Expected Results:**
- [ ] Session status changes to `ABORTED`
- [ ] Modal unlocks
- [ ] No `NODE_YIELD` event created
- [ ] Session not included in roll-up calculations

**Verify in Database:**
```sql
SELECT * FROM cut_session WHERE id_session = ?;
```
- [ ] `status = 'ABORTED'`
- [ ] `ended_at IS NULL` or set to abort time
- [ ] No `NODE_YIELD` event created

---

## ✅ Test Completion Checklist

### Critical Path Tests
- [ ] Test 1: Start CUT Session (Happy Path)
- [ ] Test 2: Session Idempotency
- [ ] Test 3: Session Conflict
- [ ] Test 4: Transaction Lock
- [ ] Test 5: End Session with Used Area

### Error Handling Tests
- [ ] Test 6: Constraints Not Found
- [ ] Test 7: Invalid Constraints (qty_required = 0)
- [ ] Test 8: Non-Leather Material

### UX/Recovery Tests
- [ ] Test 9: Modal Lock & Recovery
- [ ] Test 10: Degraded Mode

### SSOT Verification Tests
- [ ] Test 11: Time SSOT
- [ ] Test 12: NODE_YIELD Event Creation
- [ ] Test 13: TimeEventReader Ignores NODE_YIELD
- [ ] Test 14: Cancel/Abort Session

---

## 🐛 Known Issues / Notes

**None currently** - All issues resolved.

---

## 📊 Test Results Summary

**Test Date:** _______________  
**Tester:** _______________  
**Environment:** _______________  

**Results:**
- Total Tests: 14
- Passed: ___
- Failed: ___
- Blocked: ___

**Critical Issues Found:**
1. ________________________________
2. ________________________________

**Non-Critical Issues Found:**
1. ________________________________
2. ________________________________

---

**Report Generated:** 2026-01-13  
**Status:** ✅ **READY FOR TESTING**
