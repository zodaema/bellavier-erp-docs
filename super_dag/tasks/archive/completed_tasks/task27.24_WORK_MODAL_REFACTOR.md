# Task 27.24: Work Modal Refactor

> **Status:** ✅ COMPLETED  
> **Priority:** 🟡 HIGH (After 27.23)  
> **Created:** 2025-12-08  
> **Completed:** 2025-12-08  
> **Depends On:** Task 27.23 (Permission Engine)  
> **Actual Effort:** ~1 hour

---

## 🎯 Executive Summary

### ปัญหาที่พบ

Work Modal มีปัญหาหลายจุดที่ไม่เกี่ยวกับ Permission โดยตรง:

1. **Modal Logic กระจัดกระจาย** - เปิด/ปิด modal อยู่หลายที่
2. **Session Mismatch** - Modal เปิดก่อน API ยืนยัน = เวลาเพี้ยน
3. **Auto-open Logic** - ไม่ consistent ระหว่าง active/paused
4. **Button State** - ไม่ sync กับ token state จริง

### ทำไมต้องแยก Task?

- **Permission Engine (27.23)** = ตัดสินใจว่า "ทำได้หรือไม่"
- **Modal Refactor (27.24)** = จัดการ "UX flow เมื่อทำได้แล้ว"

ไม่ควรยัดรวมกัน เพราะจะทำให้ scope ใหญ่เกินไป

---

## ❌ ปัญหาปัจจุบัน

### 1. Modal Open Process ไม่ Unified

```javascript
// ตอนนี้มีหลายที่ที่เปิด modal:

// 1. จาก Card click
$('.token-card').on('click', function() {
    openWorkModal(tokenData);
});

// 2. จาก Start button
$('#btnStart').on('click', function() {
    startToken().then(() => openWorkModal(tokenData));
});

// 3. จาก Auto-open on refresh
if (token.status === 'active' && token.session.is_mine) {
    openWorkModal(tokenData);
}

// ❌ ปัญหา: Logic ซ้ำซ้อน และไม่ consistent
```

### 2. Session Mismatch

```javascript
// ปัจจุบัน:
function handleStart() {
    openWorkModal(tokenData);        // ❌ เปิด modal ทันที
    startTokenAPI().then(() => {     // API ยืนยันทีหลัง
        updateTimer();               // ❌ เวลาอาจเพี้ยน
    });
}

// ควรเป็น:
function handleStart() {
    startTokenAPI().then((response) => {
        openWorkModal(response.token);  // ✅ เปิดหลัง API ยืนยัน
        initTimer(response.session);    // ✅ ใช้ session จาก API
    });
}
```

### 3. Timer ไม่ Sync

```javascript
// ปัจจุบัน TokenCardState.js สร้าง timer data เอง:
timer: {
    elapsed: token.session?.elapsed_seconds || 0,
    startedAt: token.session?.started_at
}

// แต่ modal อาจใช้ค่าต่างกัน:
BGTimeEngine.start(token.id, serverTime);

// ❌ ผลลัพธ์: เวลาบน card กับใน modal ต่างกัน
```

---

## 🎯 Proposed Solution

### 1. Unified Modal Controller

```javascript
// assets/javascripts/pwa_scan/WorkModalController.js

class WorkModalController {
    constructor() {
        this.modal = $('#workModal');
        this.currentToken = null;
        this.currentSession = null;
    }
    
    /**
     * Open modal AFTER API confirms action
     */
    async openForToken(tokenId) {
        // 1. Always fetch fresh data
        const response = await fetch(`/source/dag_token_api.php?action=get_token_detail&id=${tokenId}`);
        const data = await response.json();
        
        if (!data.ok) {
            notifyError(data.message);
            return;
        }
        
        this.currentToken = data.token;
        this.currentSession = data.session;
        
        // 2. Populate modal with server data
        this.populateModal();
        
        // 3. Initialize timer from server session
        if (this.currentSession?.started_at) {
            BGTimeEngine.syncFromServer(tokenId, this.currentSession);
        }
        
        // 4. Show modal
        this.modal.modal('show');
    }
    
    /**
     * Start token then open modal
     */
    async startAndOpen(tokenId) {
        const response = await fetch(`/source/dag_token_api.php?action=start_token&id=${tokenId}`, {
            method: 'POST'
        });
        const data = await response.json();
        
        if (!data.ok) {
            notifyError(data.message);
            return;
        }
        
        // Open modal with fresh session
        this.currentToken = data.token;
        this.currentSession = data.session;
        this.populateModal();
        
        // Timer starts from server-confirmed time
        BGTimeEngine.start(tokenId, data.session.started_at);
        
        this.modal.modal('show');
    }
    
    populateModal() {
        const token = this.currentToken;
        const permissions = token.permissions || {};
        
        // Set title
        $('#modalTokenTitle').text(`${token.serial_number} - ${token.node_name}`);
        
        // Show/hide buttons based on permissions from server
        $('#btnPause').toggle(permissions.can_pause);
        $('#btnResume').toggle(permissions.can_resume);
        $('#btnComplete').toggle(permissions.can_complete);
        $('#btnQcPass').toggle(permissions.can_qc_pass);
        $('#btnQcFail').toggle(permissions.can_qc_fail);
    }
    
    /**
     * Close modal safely
     */
    close() {
        // Pause timer if running
        if (this.currentSession?.status === 'active') {
            BGTimeEngine.pause(this.currentToken.id);
        }
        
        this.currentToken = null;
        this.currentSession = null;
        this.modal.modal('hide');
    }
}

// Singleton instance
window.workModalController = new WorkModalController();
```

### 2. Simplified Event Handlers

```javascript
// work_queue.js - Simplified

// Card click → Open modal (view only or with actions)
$(document).on('click', '.token-card', function(e) {
    if ($(e.target).closest('.btn').length) return; // Ignore button clicks
    
    const tokenId = $(this).data('token-id');
    workModalController.openForToken(tokenId);
});

// Start button → Start then open
$(document).on('click', '.btn-start', function(e) {
    e.stopPropagation();
    const tokenId = $(this).closest('.token-card').data('token-id');
    workModalController.startAndOpen(tokenId);
});

// Auto-open for active token on page load
$(document).ready(function() {
    const activeToken = window.INITIAL_DATA?.activeToken;
    if (activeToken?.status === 'active') {
        workModalController.openForToken(activeToken.id);
    }
});
```

### 3. Timer Sync with Server

```javascript
// BGTimeEngine enhancements

BGTimeEngine.syncFromServer = function(tokenId, session) {
    const serverTime = new Date(session.started_at).getTime();
    const now = Date.now();
    const elapsed = session.elapsed_seconds * 1000;
    
    // Calculate drift
    const expectedElapsed = now - serverTime;
    const drift = Math.abs(expectedElapsed - elapsed);
    
    if (drift > 1000) {
        console.warn(`Timer drift detected: ${drift}ms`);
    }
    
    // Use server-provided elapsed as source of truth
    this.timers[tokenId] = {
        startedAt: serverTime,
        elapsed: elapsed,
        pausedAt: session.paused_at ? new Date(session.paused_at).getTime() : null
    };
};
```

---

## 📁 Files to Create/Modify

### New Files:
| File | Purpose |
|------|---------|
| `assets/javascripts/pwa_scan/WorkModalController.js` | Unified modal controller |

### Files to Modify:
| File | Changes |
|------|---------|
| `assets/javascripts/pwa_scan/work_queue.js` | Simplify, delegate to WorkModalController |
| `assets/javascripts/dag/BGTimeEngine.js` | Add syncFromServer() |
| `page/work_queue.php` | Add WorkModalController.js script |

---

## ✅ Acceptance Criteria

- [ ] Single WorkModalController handles all modal operations
- [ ] Modal never opens before API confirms action
- [ ] Timer always synced from server session
- [ ] Auto-open only for active tokens (not paused)
- [ ] Button visibility uses permissions from API
- [ ] No duplicate event handlers
- [ ] Card click vs button click properly separated

---

## 🔗 Related Tasks

- Task 27.23: Permission Engine (must complete first)
- Task 27.20: Work Modal Behavior (superseded by this)
- Task 27.22: Token Card Component (modal integration)

---

## 🎯 Expected Outcome

**Before:**
- Modal เปิดก่อน API ยืนยัน
- Timer เพี้ยน
- Auto-open สำหรับ paused tokens
- Logic กระจัดกระจาย

**After:**
- Modal เปิดหลัง API ยืนยันเสมอ
- Timer sync จาก server
- Auto-open เฉพาะ active tokens
- Logic รวมที่ WorkModalController

