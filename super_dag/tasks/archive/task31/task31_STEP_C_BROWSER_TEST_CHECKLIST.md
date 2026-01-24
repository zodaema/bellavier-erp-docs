# Step C: CUT_UI_CONTROLLER Browser Test Checklist

**Date:** 2026-01-13  
**Status:** Ready for Testing  
**Context:** Enterprise CUT UI in Work Queue Modal

---

## Pre-Test Setup

1. ✅ Hard refresh browser (Cmd+Shift+R / Ctrl+Shift+R) เพื่อโหลดโค้ดใหม่
2. ✅ เปิด Browser DevTools (Console + Network tab)
3. ✅ ตรวจสอบว่า `data-cut-ui-mode="ENTERPRISE"` ถูก set ใน panel

---

## Test 1: Controller Initialization ✅

**Objective:** ตรวจสอบว่า controller ถูกสร้างและ initialize ถูกต้อง

**Steps:**
1. เปิด Work Queue modal → เลือก token ที่มี behavior = CUT
2. ดู Console logs

**Expected Results:**
- ✅ ไม่มี JavaScript errors
- ✅ Console แสดง `[CUT_UI] dispatch BOOT` (ถ้า debug mode เปิด)
- ✅ Panel มี attribute `data-cut-ui-mode="ENTERPRISE"`
- ✅ Phase 1 แสดงนิ่ง (ไม่มี flash)

**Pass Criteria:**
- [ ] No errors
- [ ] Controller initialized
- [ ] Phase 1 displayed correctly

---

## Test 2: Component Selection → Start Session ✅

**Objective:** ตรวจสอบว่า selection flow และ start session ทำงานผ่าน controller

**Steps:**
1. Phase 1: เลือก Component
2. Phase 1: เลือก Role
3. Phase 1: เลือก Material
4. กด "Start Cutting" button

**Expected Results:**
- ✅ Console แสดง `[CUT_UI] dispatch SELECT_COMPONENT`
- ✅ Console แสดง `[CUT_UI] dispatch SELECT_ROLE`
- ✅ Console แสดง `[CUT_UI] dispatch SELECT_MATERIAL`
- ✅ Console แสดง `[CUT_UI] dispatch START_SESSION_REQUEST`
- ✅ Network: POST `cut_session_start` ส่งสำเร็จ
- ✅ Console แสดง `[CUT_UI] dispatch START_SESSION_SUCCESS`
- ✅ Console แสดง `[CUT_UI] transition SELECTING → RUNNING`
- ✅ Phase 2 แสดงขึ้นมา
- ✅ Timer เริ่มเดิน
- ✅ Modal ถูก lock (ไม่สามารถปิดได้)

**Pass Criteria:**
- [ ] All events dispatched correctly
- [ ] Phase transition works
- [ ] Timer starts
- [ ] Modal locked

---

## Test 3: Phase 2 → Save & End Session ✅

**Objective:** ตรวจสอบว่า end session ทำงานผ่าน controller และ transition ถูกต้อง

**Steps:**
1. Phase 2: ใส่ quantity > 0
2. Phase 2: เลือก leather sheet (ถ้า material เป็น leather)
3. กด "Save & End Session" button

**Expected Results:**
- ✅ Console แสดง `[CUT_UI] dispatch INPUT_QTY`
- ✅ Console แสดง `[CUT_UI] dispatch INPUT_SHEET` (ถ้าเลือก sheet)
- ✅ Console แสดง `[CUT_UI] dispatch END_SESSION_REQUEST`
- ✅ Network: POST `cut_session_end` ส่งสำเร็จ
- ✅ Console แสดง `[CUT_UI] dispatch END_SESSION_SUCCESS`
- ✅ Console แสดง `[CUT_UI] transition RUNNING → COMPLETED`
- ✅ Phase 3 แสดงขึ้นมา (success message + summary table)
- ✅ Modal ถูก unlock

**Pass Criteria:**
- [ ] All events dispatched correctly
- [ ] API call succeeds
- [ ] Phase 3 displayed
- [ ] Modal unlocked

---

## Test 4: End → Step1 Bug Fix (CRITICAL) ✅

**Objective:** ตรวจสอบว่า bug "End → Step1 แต่ไม่เปลี่ยนแปลง" ถูกแก้แล้ว

**Steps:**
1. ทำ Test 3 จนเสร็จ (End Session สำเร็จ)
2. รอ 2 วินาที (auto-return to Phase 1)
3. ดู Component list

**Expected Results:**
- ✅ Phase 3 แสดง 2 วินาที
- ✅ Console แสดง `[CUT_UI] dispatch RESET_TO_PHASE1`
- ✅ Console แสดง `[CUT_UI] transition COMPLETED → SELECTING`
- ✅ Network: GET request เพื่อ refetch batch requirements
- ✅ Phase 1 แสดงขึ้นมา
- ✅ Component list ถูก re-render
- ✅ Progress เปลี่ยนทันที:
  - Done qty เพิ่มขึ้น (ตาม qty ที่ cut)
  - Available qty เปลี่ยน (ถ้ามี)
  - Progress bar อัปเดต

**Pass Criteria:**
- [ ] Auto-return works
- [ ] Batch requirements refetched
- [ ] Component list re-rendered
- [ ] Progress updated correctly

---

## Test 5: Modal Recovery (Refresh) ✅

**Objective:** ตรวจสอบว่า controller restore session ได้ถูกต้อง

**Steps:**
1. Start session (Phase 2)
2. Refresh page (F5)
3. เปิด Work Queue modal อีกครั้ง

**Expected Results:**
- ✅ Console แสดง `[CUT_UI] syncFromBackend`
- ✅ Network: GET `cut_session_get_active`
- ✅ ถ้ามี active session:
  - Console แสดง `[CUT_UI] dispatch START_SESSION_SUCCESS`
  - Phase 2 restore ขึ้นมา
  - Timer เริ่มเดินต่อ
  - Modal ถูก lock
- ✅ ถ้าไม่มี active session:
  - Phase 1 แสดงขึ้นมา

**Pass Criteria:**
- [ ] Backend sync works
- [ ] Session restored correctly
- [ ] Phase correct after restore

---

## Test 6: Legacy Isolation (No Flash) ✅

**Objective:** ตรวจสอบว่า legacy blocks ไม่ flash

**Steps:**
1. เปิด Work Queue modal → CUT
2. ดู Network tab และ Console
3. ทำ transition ระหว่าง phases

**Expected Results:**
- ✅ ไม่มี legacy form fields (`qty_produced`, `qty_scrapped`) แสดง
- ✅ ไม่มี `.cut-bom-section` แสดง
- ✅ ไม่มี `.leather-sheets-section` (legacy) แสดง
- ✅ ไม่มี flash/flicker เมื่อ transition
- ✅ DOM ไม่มี legacy nodes (ถูก remove แล้ว)

**Pass Criteria:**
- [ ] No legacy blocks visible
- [ ] No flash/flicker
- [ ] Legacy nodes removed from DOM

---

## Test 7: Error Handling ✅

**Objective:** ตรวจสอบว่า error handling ทำงานถูกต้อง

**Steps:**
1. Start session
2. Disconnect network (หรือ block API calls)
3. กด "Save & End Session"

**Expected Results:**
- ✅ Console แสดง `[CUT_UI] dispatch END_SESSION_FAIL`
- ✅ Error message แสดง
- ✅ Phase ยังคงเป็น RUNNING (ไม่ reset)
- ✅ Modal ยัง lock อยู่
- ✅ User สามารถ retry ได้

**Pass Criteria:**
- [ ] Error handled gracefully
- [ ] State preserved
- [ ] User can retry

---

## Test 8: Double-Binding Prevention ✅

**Objective:** ตรวจสอบว่า event handlers ไม่ถูก bind ซ้ำ

**Steps:**
1. เปิด modal → CUT
2. ปิด modal
3. เปิด modal → CUT อีกครั้ง
4. ทำ action ต่างๆ (select, start, save)

**Expected Results:**
- ✅ Console ไม่มี duplicate event logs
- ✅ Actions ทำงานถูกต้อง (ไม่ซ้ำ)
- ✅ `_handlersBound` flag ทำงาน

**Pass Criteria:**
- [ ] No duplicate handlers
- [ ] Actions work correctly

---

## Test 9: Non-Enterprise Context (Legacy) ✅

**Objective:** ตรวจสอบว่า legacy flow ยังทำงาน (non-modal)

**Steps:**
1. เปิด page ที่ไม่ใช่ Work Queue modal (ถ้ามี)
2. ตรวจสอบ CUT behavior

**Expected Results:**
- ✅ Controller ไม่ถูกสร้าง (`cutUIController === null`)
- ✅ Legacy code path ทำงาน
- ✅ ไม่มี errors

**Pass Criteria:**
- [ ] Legacy flow works
- [ ] No errors

---

## Debug Commands (Console)

```javascript
// Check controller state
cutUIController?.state

// Check current phase
cutUIController?.state.phase

// Check session
cutUIController?.state.session

// Manually dispatch event
cutUIController?.dispatch('BATCH_LOADED', { batchData: [...] })

// Force render
cutUIController?.render()
```

---

## Known Issues / Notes

- Controller ทำงานเฉพาะใน Enterprise context (`isEnterpriseContext === true`)
- Legacy code path ยังคงทำงานใน non-Enterprise context
- State sync ระหว่าง controller และ `cutPhaseState` (backward compatibility)

---

## Test Results

**Tester:** _______________  
**Date:** _______________  
**Browser:** _______________  
**Version:** _______________

| Test | Status | Notes |
|------|--------|-------|
| Test 1: Controller Initialization | ⬜ Pass / ⬜ Fail | |
| Test 2: Component Selection → Start | ⬜ Pass / ⬜ Fail | |
| Test 3: Phase 2 → Save & End | ⬜ Pass / ⬜ Fail | |
| Test 4: End → Step1 Bug Fix | ⬜ Pass / ⬜ Fail | |
| Test 5: Modal Recovery | ⬜ Pass / ⬜ Fail | |
| Test 6: Legacy Isolation | ⬜ Pass / ⬜ Fail | |
| Test 7: Error Handling | ⬜ Pass / ⬜ Fail | |
| Test 8: Double-Binding Prevention | ⬜ Pass / ⬜ Fail | |
| Test 9: Non-Enterprise Context | ⬜ Pass / ⬜ Fail | |

---

## Overall Status

**Overall:** ⬜ **PASS** / ⬜ **FAIL**

**Critical Issues:**
- 

**Minor Issues:**
- 

**Recommendations:**
- 

---

**Next Steps:**
- [ ] Fix critical issues
- [ ] Re-test failed tests
- [ ] Update documentation
- [ ] Deploy to production
