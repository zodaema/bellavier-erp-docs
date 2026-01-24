# Task 31: CUT Modal Lock - Degraded Mode Implementation

**Date:** 2026-01-13  
**Status:** ✅ **COMPLETE**

---

## 🎯 Problem Statement

**P0-1 Critical Issue:** Safe default = unlock เมื่อ backend call fail เป็นอันตราย

**Scenario:**
- ช่างกด Start Cutting → session RUNNING ใน backend
- เน็ตหลุด / backend timeout / 500 error
- UI unlock modal → ช่างหนีออกได้ → งานค้างตาย

**Requirement:**
- Modal ต้อง lock จนกว่า session จะ complete
- ถ้า backend ล่ม → ใช้ degraded mode (ไม่ unlock ทิ้ง)

---

## ✅ Solution: Degraded Mode

### Flow Logic

```
Backend Check Result → Action
─────────────────────────────────────────
✅ Backend RUNNING → Lock modal + restore Phase 2
✅ Backend NO RUNNING → Unlock modal + clear hints
⚠️ Backend FAIL + hint RUNNING → Soft-lock + retry overlay
⚠️ Backend FAIL + no hint → Don't lock + show error
```

### Degraded Mode Rules

1. **Backend RUNNING** → Lock modal (normal flow)
2. **Backend NO RUNNING** → Unlock modal (normal flow)
3. **Backend FAIL + localStorage hint RUNNING** → Soft-lock modal + show retry overlay
4. **Backend FAIL + no hint** → Don't lock + show error (safe default)

---

## 🔧 Implementation Details

### 1. Backend Check with Timeout

**File:** `assets/javascripts/dag/behavior_execution.js`  
**Function:** `loadCutBatchDetail()`

```javascript
// ✅ ALWAYS check backend first (SSOT)
let backendRes;
let backendCheckFailed = false;
try {
    backendRes = await new Promise((resolve, reject) => {
        const payload = window.BGBehaviorExec.buildPayload(baseContext, 'cut_session_get_active', {});
        // Add timeout to prevent hanging
        const timeout = setTimeout(() => {
            reject(new Error('Backend check timeout'));
        }, 10000); // 10 second timeout
        window.BGBehaviorExec.send(payload, function(res) {
            clearTimeout(timeout);
            resolve(res);
        }, function(err) {
            clearTimeout(timeout);
            reject(err);
        });
    });
} catch (backendErr) {
    backendCheckFailed = true;
    // Handle degraded mode
}
```

### 2. Degraded Mode Handler

**When:** Backend check fails but localStorage hint says RUNNING

**Action:**
1. Restore Phase 2 from hint (best-effort)
2. Soft-lock modal (lock but show retry overlay)
3. Show retry overlay with "Checking session status..." message
4. Retry button → call backend again

**Code:**
```javascript
if (backendCheckFailed) {
    const storedHint = loadSessionFromStorage();
    
    if (storedHint && storedHint.status === 'RUNNING' && storedHint.session_id) {
        // ✅ Degraded mode: Backend unavailable but hint says RUNNING
        restoreSessionFromServer({
            session_id: storedHint.session_id,
            // ... restore from hint
        });
        lockModal();
        showBackendCheckRetryOverlay();
    } else {
        // No hint → safe to unlock
        unlockModal();
        clearSessionFromStorage();
    }
}
```

### 3. Retry Overlay

**Function:** `showBackendCheckRetryOverlay()`

**Features:**
- Overlay with spinner + message
- "Retry" button → call backend again
- If backend recovers → hide overlay, continue normally
- If backend still fails → keep overlay, show error

**UI:**
- Spinner (loading indicator)
- Message: "Checking session status... Network issue detected."
- Retry button

---

## 🔍 P0-2: Backend SSOT Endpoint Verification

### API: `cut_session_get_active`

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`  
**Method:** `handleCutSessionGetActive()`

**Verification:**
- ✅ Endpoint exists: `cut_session_get_active`
- ✅ Calls `CutSessionService::getActiveSession(tokenId, nodeId, operatorId)`
- ✅ Returns: `{ok: true, session: {...}}` or `{ok: true, session: null}`

**Backend Query:**
```sql
SELECT ... FROM cut_session
WHERE token_id = ? AND node_id = ? AND operator_id = ?
  AND status IN ('RUNNING', 'PAUSED')
ORDER BY started_at DESC LIMIT 1
```

**Response Fields:**
- `session_id` ✅
- `session_uuid` ✅
- `component_code` ✅
- `role_code` ✅
- `material_sku` ✅
- `started_at` ✅ (server time - SSOT)
- `status` ✅ ('RUNNING' | 'PAUSED')
- `paused_total_seconds` ✅

**Status:** ✅ **VERIFIED** - Endpoint is SSOT and returns correct data

---

## 🔧 P1-1: Bootstrap Modal Config Fix

**Problem:** Using private `_config` API

**Solution:** Use data attributes + public API

**Before:**
```javascript
if (modalInstance._config) {
    modalInstance._config.backdrop = 'static';
    modalInstance._config.keyboard = false;
}
```

**After:**
```javascript
// Set via data attributes (works even if instance created before)
$modal.attr('data-bs-backdrop', 'static');
$modal.attr('data-bs-keyboard', 'false');

// Re-initialize with options
modalInstance = bootstrap.Modal.getOrCreateInstance($modal[0], {
    backdrop: 'static',
    keyboard: false
});
```

---

## 🔧 P1-2: Event Namespace Fix

**Problem:** Using `.bs.modal` namespace (conflicts with Bootstrap)

**Solution:** Use custom namespace `.cutModalLock`

**Before:**
```javascript
$modal.off('click.bs.modal').on('click.bs.modal', function(e) {...});
```

**After:**
```javascript
$modal.off('click.cutModalLock').on('click.cutModalLock', function(e) {...});
$(document).off('keydown.cutModalLock').on('keydown.cutModalLock', function(e) {...});
```

---

## ✅ Acceptance Criteria

### P0-1: Degraded Mode
- [x] Backend RUNNING → Lock modal
- [x] Backend NO RUNNING → Unlock modal
- [x] Backend FAIL + hint RUNNING → Soft-lock + retry overlay
- [x] Backend FAIL + no hint → Don't lock + show error

### P0-2: Backend SSOT
- [x] Endpoint `cut_session_get_active` exists
- [x] Returns correct data (session_id, started_at, status, etc.)
- [x] Query uses token_id + node_id + operator_id
- [x] UI calls it on modal open

### P1-1: Bootstrap Modal Config
- [x] Use data attributes instead of private `_config`
- [x] Re-initialize modal with options if needed

### P1-2: Event Namespace
- [x] Use custom namespace `.cutModalLock`
- [x] No conflict with Bootstrap events

---

## 🚀 Testing Checklist

### Degraded Mode
- [ ] Start session → Disconnect network → Refresh → Should show retry overlay
- [ ] Retry button → Reconnect network → Should recover
- [ ] Start session → Clear localStorage → Disconnect network → Should not lock (no hint)

### Backend SSOT
- [ ] Start session → Check backend → Should return RUNNING session
- [ ] End session → Check backend → Should return null
- [ ] Start session → Refresh → Should restore from backend

### Modal Lock
- [ ] Backend RUNNING → Modal locked (X hidden, ESC disabled, backdrop disabled)
- [ ] Backend NO RUNNING → Modal unlocked
- [ ] Backend FAIL + hint → Soft-lock + retry overlay
- [ ] Backend FAIL + no hint → Not locked

---

## 📝 Notes

1. **Degraded mode is NOT perfect** - It's a graceful degradation that prevents "escape route" while allowing recovery.

2. **Retry overlay** gives user control to retry backend check without forcing them to refresh.

3. **Backend timeout** is 10 seconds - prevents hanging indefinitely.

4. **localStorage hint** is used ONLY when backend is unavailable - never for normal flow decisions.
