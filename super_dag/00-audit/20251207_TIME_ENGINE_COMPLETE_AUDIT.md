# Time Engine v2 Complete Audit Report

**Date:** December 7, 2025  
**Author:** AI Assistant  
**Status:** AUDIT COMPLETE - INTEGRATION BUG (NOT TIMEENGINE BUG)

---

## ⚠️ IMPORTANT CLARIFICATION

**TimeEngine v2 ถูกต้อง 100%** - ระบบเสร็จสมบูรณ์และทำงานถูกต้องตั้งแต่ก่อนหน้านี้

**ปัญหาเกิดจาก AI เขียน Modal handler ผิดพลาด:**
- ไม่ได้ copy pattern จาก Pause handler ที่มีอยู่แล้ว
- ใช้ `resp.token.timer` แทน `resp.timer` โดยไม่ดู API response structure
- ไม่ได้ใช้ `BGTimeEngine.updateTimerFromPayload()` ที่มีอยู่แล้ว

นี่คือความผิดของ AI ที่ทะลึ่งแก้โดยไม่เข้าใจระบบเดิม

---

## 1. System Overview

Time Engine v2 เป็นระบบจับเวลาทำงานของ Operator ที่แบ่งออกเป็น 2 ส่วน:

### 1.1 Backend (Single Source of Truth)

| File | Role |
|------|------|
| `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php` | คำนวณ Timer DTO จาก session data |
| `source/BGERP/Service/TokenWorkSessionService.php` | จัดการ session (start/pause/resume/complete) |
| `source/dag_token_api.php` | API endpoint สำหรับ work queue |

### 1.2 Frontend (Drift-Corrected Display)

| File | Role |
|------|------|
| `assets/javascripts/pwa_scan/work_queue_timer.js` | BGTimeEngine - tick & display |
| `assets/javascripts/pwa_scan/work_queue.js` | Work Queue UI + Modal handlers |
| `assets/javascripts/manager/assignment.js` | Manager Assignment (People tab) |

---

## 2. Timer DTO Contract

Timer DTO เป็น data structure ที่ Backend ส่งให้ Frontend:

```php
// Backend (WorkSessionTimeEngine::calculateTimer)
[
    'work_seconds' => int,        // Total work seconds at this moment
    'base_work_seconds' => int,   // Snapshot จาก DB
    'live_tail_seconds' => int,   // เวลาที่เพิ่มขึ้นหลัง resume/start
    'status' => string,           // 'active'|'paused'|'completed'|'none'
    'started_at' => string|null,  // ISO8601
    'resumed_at' => string|null,  // ISO8601
    'last_server_sync' => string, // ISO8601 (ใช้เป็น anchor สำหรับ drift)
]
```

```javascript
// Frontend (BGTimeEngine)
// Required data attributes:
// data-token-id: Unique ID (ป้องกัน duplicate)
// data-status: 'active'|'paused'|'completed'
// data-work-seconds-sync: ค่า work_seconds จาก server
// data-last-server-sync: ISO8601 (anchor time)
```

---

## 3. Time Calculation Flow

### 3.1 When Active

```
Backend:
┌─────────────────────────────────────────────────────────────┐
│ work_seconds = base_work_seconds + (NOW - anchor_time)      │
│ anchor_time = resumed_at ?? started_at                      │
│ base_work_seconds = session.work_seconds (from DB)          │
└─────────────────────────────────────────────────────────────┘

Frontend:
┌─────────────────────────────────────────────────────────────┐
│ displaySeconds = syncSeconds + (NOW - lastServerSync)       │
│ syncSeconds = data-work-seconds-sync                        │
│ lastServerSync = data-last-server-sync                      │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 When Paused/Completed

```
Backend & Frontend:
┌─────────────────────────────────────────────────────────────┐
│ work_seconds = base_work_seconds (static, no drift)         │
│ live_tail_seconds = 0                                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Data Flow Diagram

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│   Operator     │────▶│  dag_token_api │────▶│  TokenWork     │
│   Click        │     │  (API)         │     │  SessionService│
└────────────────┘     └───────┬────────┘     └───────┬────────┘
                               │                      │
                               │                      ▼
                               │              ┌────────────────┐
                               │              │ token_work_    │
                               │              │ session (DB)   │
                               │              └───────┬────────┘
                               │                      │
                               ▼                      ▼
                       ┌────────────────┐     ┌────────────────┐
                       │ WorkSession    │◀────│ Session Row    │
                       │ TimeEngine     │     │ (status, work_ │
                       │                │     │ seconds, etc)  │
                       └───────┬────────┘     └────────────────┘
                               │
                               ▼
                       ┌────────────────┐
                       │ Timer DTO      │
                       │ (JSON response)│
                       └───────┬────────┘
                               │
       ┌───────────────────────┼───────────────────────┐
       ▼                       ▼                       ▼
┌────────────┐         ┌────────────┐         ┌────────────┐
│ Card Timer │         │ Modal Timer│         │ People Tab │
│ (main UI)  │         │ (popup)    │         │ (manager)  │
└────────────┘         └────────────┘         └────────────┘
       │                       │                       │
       └───────────────────────┼───────────────────────┘
                               ▼
                       ┌────────────────┐
                       │ BGTimeEngine   │
                       │ (tick every 1s)│
                       └────────────────┘
```

---

## 5. ⚠️ AI INTEGRATION ERRORS (NOT TIMEENGINE BUGS)

### 5.1 AI-ERR-1: Modal Resume Handler Uses Wrong Response Path (AI wrote wrong code)

**Location:** `work_queue.js` lines 2122-2127

```javascript
// ❌ BUG: Uses resp.token.timer but API returns resp.timer
if (resp.token && resp.token.timer) {
    const $timerEl = $('#workModalTimer');
    $timerEl.attr('data-status', 'active');
    $timerEl.attr('data-work-seconds-sync', resp.token.timer.work_seconds || 0);
    $timerEl.attr('data-last-server-sync', resp.token.timer.last_server_sync || new Date().toISOString());
}
```

**Expected:** ควรใช้ `resp.timer` ตรงๆ เหมือน Pause handler

**Actual:** `resp.token` เป็น `undefined` ดังนั้น timer ไม่ได้ update

**Impact:** Timer ยังคงค่าเก่า หลัง Resume ใน Modal

### 5.2 AI-ERR-2: Modal Resume Handler ไม่ Register BGTimeEngine (AI didn't copy existing pattern)

**Location:** `work_queue.js` lines 2122-2127

```javascript
// ❌ BUG: ไม่มี BGTimeEngine.registerTimerElement() หลัง resume
// ❌ BUG: ไม่มี BGTimeEngine.updateTimerFromPayload() เหมือน Pause handler
if (resp.token && resp.token.timer) {
    // ... update attributes only
}
// ไม่มี: BGTimeEngine.registerTimerElement($timerEl[0]);
```

**Expected:** ควรเรียก `BGTimeEngine.updateTimerFromPayload()` เหมือน Pause handler

**Actual:** Timer element ไม่ถูก register เข้า tick loop

**Impact:** Timer ไม่เดินหลัง Resume ใน Modal

### 5.3 AI-ERR-3: Card Resume Handler Uses Same Wrong Pattern

**Location:** `work_queue.js` line ~2016

```javascript
// Resume API then open Modal
$.post(API_URL, {
    action: 'resume_token',
    token_id: tokenId
}, function(resp) {
    if (resp.ok) {
        // ...
        openWorkModal(tokenId, nodeId, resp.token || null);  // ❌ resp.token เป็น undefined!
    }
});
```

**Expected:** API ส่ง `resp.token` ที่มี full token data

**Actual:** API ส่งแค่ `resp.session` และ `resp.timer`

**Impact:** `openWorkModal` ได้รับ `null` และต้อง fetch ใหม่จาก `get_work_queue`

### 5.4 NOTE: API Response Structure (NOT a bug - AI should have read this)

**Location:** `dag_token_api.php` - handlePauseToken & handleResumeToken

```php
// ทั้ง pause และ resume ส่ง:
json_success([
    'session' => $sessionResult,
    'timer' => $timeEngine->calculateTimer(...),  // ✅ ถูกต้อง
    'message' => 'Work paused/resumed successfully'
]);

// แต่ไม่ได้ส่ง 'token' object ที่มี full data
```

**Expected:** ส่ง `token` object เหมือน `get_work_queue`

**Actual:** ส่งแค่ `session` และ `timer`

**Impact:** Frontend ต้อง re-fetch token data จาก `get_work_queue`

---

## 6. ✅ Working Components

### 6.1 Card Timer (Main UI) - ทำงานถูกต้อง

- `get_work_queue` ส่ง Timer DTO ครบ
- `renderTokenCard()` สร้าง DOM ถูกต้อง
- BGTimeEngine tick ทุกวินาที

### 6.2 Modal Open Timer - ทำงานถูกต้อง

- `openWorkModal()` fetch จาก `get_work_queue`
- `populateWorkModal()` ใช้ Timer DTO
- BGTimeEngine register ด้วย unique token-id (`'modal-' + tokenId`)

### 6.3 Modal Pause - ทำงานถูกต้อง

- ใช้ `BGTimeEngine.updateTimerFromPayload()` ถูกต้อง
- Timer freeze และแสดงค่าถูกต้อง

---

## 7. Database Schema

### token_work_session

| Column | Type | Description |
|--------|------|-------------|
| id_session | INT PK | Session ID |
| id_token | INT FK | Token being worked |
| operator_user_id | INT FK | Operator |
| operator_name | VARCHAR | Display name |
| status | ENUM | 'active', 'paused', 'completed' |
| started_at | DATETIME | First start time |
| resumed_at | DATETIME | Last resume time (anchor!) |
| paused_at | DATETIME | Last pause time |
| work_seconds | INT | Accumulated work (snapshot) |
| total_pause_minutes | INT | Total pause time |
| pause_count | INT | Number of pauses |

### Critical Fields for Time Calculation

1. **work_seconds** - บันทึกเมื่อ Pause (snapshot)
2. **resumed_at** - ใช้เป็น anchor สำหรับ live_tail
3. **started_at** - ใช้เมื่อ resumed_at เป็น NULL

---

## 8. Fix Recommendations

### Fix 1: Modal Resume Handler (Priority: P0)

```javascript
// แก้จาก:
if (resp.token && resp.token.timer) {
    $timerEl.attr('data-status', 'active');
    // ...
}

// เป็น:
const $timerEl = $('#workModalTimer');
if (resp.timer && typeof BGTimeEngine !== 'undefined') {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
} else {
    // Fallback
    $timerEl.attr('data-status', 'active');
}
```

### Fix 2: Consistent API Response (Priority: P1)

Option A: API ส่ง full token object ทุก action

```php
// In handlePauseToken, handleResumeToken:
$token = $this->fetchTokenDetails($tokenId);  // Full token data
$token['timer'] = $timeEngine->calculateTimer(...);
json_success(['token' => $token]);
```

Option B: Frontend ยอมรับ pattern ปัจจุบัน

```javascript
// Resume handler ใช้ resp.timer แทน resp.token.timer
if (resp.timer) {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
}
```

---

## 9. Test Scenarios

| # | Scenario | Expected | Status |
|---|----------|----------|--------|
| T1 | เปิด Modal หลัง Resume จาก Card | Timer แสดงค่าถูกต้องและเดิน | ✅ PASS |
| T2 | กด Pause ใน Modal | Timer หยุดและค้างค่าถูกต้อง | ✅ PASS |
| T3 | กด Resume ใน Modal | Timer ต่อจากค่าเดิมและเดิน | ❌ FAIL |
| T4 | กด Pause ใน Modal แล้ว Resume | Timer ต่อจากค่าเดิมและเดิน | ❌ FAIL |
| T5 | Multiple pause/resume cycles | Timer สะสมเวลาถูกต้อง | ❌ FAIL |

---

## 10. Appendix: Code References

### Backend

```
source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php:52   calculateTimer()
source/BGERP/Service/TokenWorkSessionService.php:178           pauseToken()
source/BGERP/Service/TokenWorkSessionService.php:266           resumeToken()
source/dag_token_api.php:2434                                   handlePauseToken()
source/dag_token_api.php:2525                                   handleResumeToken()
source/dag_token_api.php:1930                                   get_work_queue Timer attach
```

### Frontend

```
assets/javascripts/pwa_scan/work_queue_timer.js:52              registerTimerElement()
assets/javascripts/pwa_scan/work_queue_timer.js:251             updateTimerFromPayload()
assets/javascripts/pwa_scan/work_queue.js:2049                  #btnWorkPause handler
assets/javascripts/pwa_scan/work_queue.js:2105                  #btnWorkResume handler
assets/javascripts/pwa_scan/work_queue.js:2278                  populateWorkModal() timer setup
```

---

## 11. Summary

**TimeEngine v2 ไม่มีปัญหา** - ระบบถูกสร้างมาถูกต้องและทำงานได้ดี

**Root Cause (AI Integration Error):**
AI เขียน Modal Resume handler ผิดพลาด:
1. ใช้ `resp.token.timer` แต่ API ส่ง `resp.timer` (ไม่ได้ดู response structure)
2. ไม่ได้ใช้ `BGTimeEngine.updateTimerFromPayload()` ที่มีอยู่แล้ว
3. ไม่ได้ copy pattern จาก Pause handler ที่อยู่ห่างกันแค่ไม่กี่บรรทัด

**Correct Pattern (Already exists in Pause handler line 2082-2090):**
```javascript
const $timerEl = $('#workModalTimer');
if (resp.timer && typeof BGTimeEngine !== 'undefined') {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
}
```

**Lesson Learned:**
เมื่อ integrate กับระบบที่มีอยู่แล้ว ต้อง:
1. ศึกษาระบบเดิมให้เข้าใจก่อน
2. Copy pattern ที่ทำงานถูกต้องอยู่แล้ว
3. ไม่ทะลึ่งเขียนใหม่โดยไม่เข้าใจ

**Severity:** Low - แก้แค่ 2-3 บรรทัด (copy จาก Pause handler)

