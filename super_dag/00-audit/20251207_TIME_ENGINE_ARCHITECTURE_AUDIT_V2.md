# Time Engine v2 - Architecture Audit (Architect Level)

**Date:** December 7, 2025  
**Level:** Production Architecture  
**Status:** DEFINITIVE - RULES BINDING FOR ALL AGENTS

---

## 🎯 Executive Summary

**TimeEngine v2 ถูกต้อง 100%** - ไม่มีปัญหาใดๆ กับ algorithm หรือ implementation

**ปัญหาที่เกิด:**
Agent สร้าง code ที่ละเมิด Single Source of Truth architecture โดย:
1. สร้าง API คำนวณเวลาแยก (`work_modal_api.php` - ถูกลบแล้ว)
2. เขียน Modal handler ที่ไม่ใช้ระบบเดียวกับ Card
3. คำนวณเวลาใน JavaScript แทนที่จะใช้ Timer DTO จาก Backend

---

## 1. 🏛️ TIME ARCHITECTURE PHILOSOPHY

### 1.1 Single Source of Truth Principle

```
┌─────────────────────────────────────────────────────────────┐
│              SINGLE SOURCE OF TRUTH                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         WorkSessionTimeEngine.php                    │   │
│  │         (Backend - The ONLY time calculator)         │   │
│  └──────────────────────┬──────────────────────────────┘   │
│                         │                                   │
│                         ▼                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Timer DTO (JSON)                        │   │
│  │  {work_seconds, status, last_server_sync, ...}       │   │
│  └──────────────────────┬──────────────────────────────┘   │
│                         │                                   │
│         ┌───────────────┼───────────────┐                   │
│         ▼               ▼               ▼                   │
│  ┌───────────┐   ┌───────────┐   ┌───────────┐             │
│  │   Card    │   │   Modal   │   │  People   │             │
│  │  Timer    │   │  Timer    │   │   Tab     │             │
│  └───────────┘   └───────────┘   └───────────┘             │
│         │               │               │                   │
│         └───────────────┼───────────────┘                   │
│                         ▼                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            BGTimeEngine.js                           │   │
│  │      (Frontend - ONLY displays & drifts)             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Core Rules (BINDING)

| Rule | Description | Violation = Immediate Reject |
|------|-------------|------------------------------|
| **R1** | Backend is the ONLY time calculator | ห้ามคำนวณเวลาใน JavaScript |
| **R2** | One Timer DTO format | ห้ามสร้าง DTO format ใหม่ |
| **R3** | One API for time data | ห้ามสร้าง API คำนวณเวลาใหม่ |
| **R4** | BGTimeEngine is the ONLY ticker | ห้ามสร้าง setInterval timer ใหม่ |
| **R5** | Modal = Same render as Card | Modal ต้อง render เหมือน Token Card 100% |

---

## 2. 🚫 FORBIDDEN PATTERNS (Anti-Patterns)

### 2.1 ❌ NEVER: Create new time calculation API

```php
// ❌ FORBIDDEN - ห้ามเด็ดขาด!
function handleGetTokenDetails() {
    // Calculate time here...
    $workSeconds = time() - strtotime($session['started_at']);
    // ...
}
```

**Why:** สร้าง Second Source of Truth → เวลาเพี้ยน

### 2.2 ❌ NEVER: Calculate time in JavaScript

```javascript
// ❌ FORBIDDEN - ห้ามเด็ดขาด!
const started = new Date(session.started_at);
const now = new Date();
const duration = (now - started) / 1000;
```

**Why:** 
- Timezone mismatch
- Clock drift
- ไม่รู้จัก pause time ที่ต้องหัก

### 2.3 ❌ NEVER: Create custom timer DOM structure

```javascript
// ❌ FORBIDDEN
$('#myCustomTimer').text(formatTime(seconds));
setInterval(() => { ... }, 1000);
```

**Why:** BGTimeEngine มีอยู่แล้ว - ใช้มัน!

### 2.4 ❌ NEVER: Create separate Modal rendering logic

```javascript
// ❌ FORBIDDEN
function populateWorkModal(token) {
    // Custom rendering for modal
    $('#modalTimer').text(...);
}
```

**Why:** Modal = อีกมุมมองของ Token Card → ต้องใช้ render function เดียวกัน

---

## 3. ✅ REQUIRED PATTERNS (Must Follow)

### 3.1 ✅ ALWAYS: Use Timer DTO from existing API

```javascript
// ✅ CORRECT
// get_work_queue returns tokens with timer DTO
$.post(API_URL, { action: 'get_work_queue' }, function(resp) {
    const token = resp.nodes.flatMap(n => n.tokens).find(t => t.id_token === tokenId);
    // token.timer is the Timer DTO - use it!
});
```

### 3.2 ✅ ALWAYS: Use BGTimeEngine for display

```javascript
// ✅ CORRECT
const $timerEl = $('#workModalTimer');
$timerEl.attr('data-token-id', 'modal-' + token.id_token);
$timerEl.attr('data-status', token.timer.status);
$timerEl.attr('data-work-seconds-sync', token.timer.work_seconds);
$timerEl.attr('data-last-server-sync', token.timer.last_server_sync);
BGTimeEngine.registerTimerElement($timerEl[0]);
```

### 3.3 ✅ ALWAYS: Use updateTimerFromPayload after API actions

```javascript
// ✅ CORRECT - Copy from existing Pause handler
if (resp.timer && typeof BGTimeEngine !== 'undefined') {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
}
```

### 3.4 ✅ ALWAYS: Modal uses same render function as Card

```javascript
// ✅ IDEAL ARCHITECTURE (Future refactor)
// Modal content should be: renderTokenCard(token, { mode: 'modal' })
// NOT: custom populateWorkModal() function
```

---

## 4. 📐 UNIFIED TIME API CONTRACT

### 4.1 Timer DTO Specification

```typescript
interface TimerDTO {
    // Calculated values (from WorkSessionTimeEngine)
    work_seconds: number;        // Total work seconds NOW
    base_work_seconds: number;   // Snapshot from DB
    live_tail_seconds: number;   // Seconds since anchor
    
    // Status
    status: 'active' | 'paused' | 'completed' | 'none';
    
    // Timestamps (ISO8601)
    started_at: string | null;
    resumed_at: string | null;
    last_server_sync: string;    // CRITICAL for drift calculation
}
```

### 4.2 API Response Contract

**ALL token-related API actions MUST include Timer DTO:**

| Action | Response |
|--------|----------|
| `get_work_queue` | `{ nodes: [{ tokens: [{ timer: TimerDTO }] }] }` |
| `start_token` | `{ session: {...}, timer: TimerDTO }` |
| `pause_token` | `{ session: {...}, timer: TimerDTO }` |
| `resume_token` | `{ session: {...}, timer: TimerDTO }` |
| `complete_token` | `{ session: {...}, timer: TimerDTO }` |

### 4.3 DOM Contract for BGTimeEngine

```html
<!-- Required attributes for BGTimeEngine -->
<span class="work-timer-active"
      data-token-id="unique-id"
      data-status="active|paused|completed"
      data-work-seconds-sync="3600"
      data-last-server-sync="2025-12-07T18:00:00+07:00">
    <!-- BGTimeEngine will update this text -->
</span>
```

---

## 5. 🔧 CURRENT BUGS & FIXES

### 5.1 Bug: Modal Resume Handler (lines 2105-2133)

**Problem:**
```javascript
// ❌ Uses resp.token.timer (undefined)
if (resp.token && resp.token.timer) { ... }

// ❌ Doesn't use BGTimeEngine.updateTimerFromPayload()
// ❌ Doesn't register element after status change to active
```

**Fix:**
```javascript
// ✅ Copy from Pause handler (lines 2082-2090)
const $timerEl = $('#workModalTimer');
if (resp.timer && typeof BGTimeEngine !== 'undefined') {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
}
```

### 5.2 Architectural Issue: Modal has separate rendering

**Problem:**
- `populateWorkModal()` is separate from Card rendering
- Timer setup duplicates logic from `renderTokenCard()`

**Future Refactor:**
```javascript
// Create unified render function
function renderTokenView(token, options = { mode: 'card' }) {
    // Same logic for both Card and Modal
    // Only layout differs based on mode
}
```

---

## 6. 🛡️ AGENT PREVENTION RULES

### 6.1 Pre-Commit Checklist for Time-Related Changes

Before ANY change touching timer/time:

- [ ] Does it use WorkSessionTimeEngine.php for calculation? (Must be YES)
- [ ] Does it use BGTimeEngine.js for display? (Must be YES)
- [ ] Does it create new time calculation logic? (Must be NO)
- [ ] Does it create new API for time data? (Must be NO)
- [ ] Does Modal use same render as Card? (Must be YES)

### 6.2 Code Review Gates

| Gate | Check | Fail Action |
|------|-------|-------------|
| G1 | No `new Date()` arithmetic in timer code | Reject |
| G2 | No `setInterval` for timers (except BGTimeEngine) | Reject |
| G3 | All timer DOM uses BGTimeEngine registration | Reject |
| G4 | All API responses include Timer DTO | Reject |
| G5 | Modal rendering reuses Card logic | Reject |

### 6.3 Architecture Decision Records (ADRs)

**ADR-TIME-001: Single Time Calculator**
- Decision: WorkSessionTimeEngine.php is the ONLY time calculator
- Status: ACTIVE
- Consequence: Any new time calculation code is auto-rejected

**ADR-TIME-002: Timer DTO Standard**
- Decision: All time data uses Timer DTO format
- Status: ACTIVE
- Consequence: Any custom time format is auto-rejected

**ADR-TIME-003: BGTimeEngine Monopoly**
- Decision: BGTimeEngine.js is the ONLY frontend timer
- Status: ACTIVE
- Consequence: Any new setInterval timer is auto-rejected

**ADR-TIME-004: Modal = Card Rendering**
- Decision: Modal must use same rendering logic as Card
- Status: ACTIVE
- Consequence: Separate Modal rendering logic is rejected

---

## 7. 📊 SYSTEM HEALTH MATRIX

| Component | Status | Notes |
|-----------|--------|-------|
| WorkSessionTimeEngine.php | ✅ 100% | Single source of truth |
| TokenWorkSessionService.php | ✅ 100% | pause/resume logic correct |
| BGTimeEngine.js | ✅ 100% | Drift-corrected ticker |
| Card Timer (Kanban) | ✅ 100% | Uses Timer DTO correctly |
| Modal Timer | ⚠️ 80% | Resume handler bug |
| People Tab Timer | ✅ 100% | Uses BGTimeEngine |
| API: get_work_queue | ✅ 100% | Returns Timer DTO |
| API: pause_token | ✅ 100% | Returns Timer DTO |
| API: resume_token | ✅ 100% | Returns Timer DTO |

---

## 8. 🎯 IMMEDIATE ACTIONS

### 8.1 Fix Resume Handler (5 minutes)

Location: `assets/javascripts/pwa_scan/work_queue.js` lines 2122-2127

```javascript
// REPLACE:
if (resp.token && resp.token.timer) {
    const $timerEl = $('#workModalTimer');
    $timerEl.attr('data-status', 'active');
    $timerEl.attr('data-work-seconds-sync', resp.token.timer.work_seconds || 0);
    $timerEl.attr('data-last-server-sync', resp.token.timer.last_server_sync || new Date().toISOString());
}

// WITH:
const $timerEl = $('#workModalTimer');
if (resp.timer && typeof BGTimeEngine !== 'undefined') {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
}
```

### 8.2 Future: Unify Modal & Card Rendering

Priority: P2 (After current bug is fixed)

Create unified `renderTokenView(token, mode)` function that:
- Renders Card when `mode === 'card'`
- Renders Modal content when `mode === 'modal'`
- Uses SAME timer setup logic
- Uses SAME BGTimeEngine registration

---

## 9. ✅ CONCLUSION

**TimeEngine v2 = Production Ready & Stable**

The architecture is sound. The bug exists because Agent violated architecture rules:

1. ❌ Created separate time handling in Modal
2. ❌ Didn't copy existing working pattern (Pause handler)
3. ❌ Didn't understand Single Source of Truth principle

**Prevention:**
- This document is now the binding contract
- All Agents MUST follow rules in Section 6
- Any violation = immediate reject

---

## Appendix: File References

| File | Purpose | Lines |
|------|---------|-------|
| `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php` | Backend calculator | 1-169 |
| `source/BGERP/Service/TokenWorkSessionService.php` | Session management | 1-971 |
| `source/dag_token_api.php` | API endpoints | handlePauseToken: 2434, handleResumeToken: 2525 |
| `assets/javascripts/pwa_scan/work_queue_timer.js` | BGTimeEngine | 1-309 |
| `assets/javascripts/pwa_scan/work_queue.js` | Work Queue UI | Modal handlers: 2049-2133 |

