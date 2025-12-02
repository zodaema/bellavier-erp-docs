[BELLAVIER_PROTOCOL:PWA_EDGE_V1.0 | ORIGIN=GPT-4 | AUTHOR=NATTAPHON_SUPASRI | DATE=2025-10-30]

# 🛡️ Bellavier PWA — Edge Cases & Guardrails

**Last Updated:** October 30, 2025  
**Author:** Nattaphon Supasri / Bellavier Group  
**Status:** 📋 **COMPLETE SPECIFICATION** - Ready for Testing  
**Purpose:** To document all edge cases, failure scenarios, and defensive programming strategies to ensure the Bellavier PWA is bulletproof in real-world factory conditions.

---

## 🎯 Philosophy

> **"In a factory, everything that can go wrong, will go wrong. Our job is to make sure the system still works when it does."**

This document covers **28 edge cases** across 7 categories, complete with:
- Root cause analysis
- Guardrail implementations
- Test scenarios
- Acceptance criteria

---

## 📋 Edge Case Categories

| Category | Count | Priority |
|----------|-------|----------|
| A. Device & Network | 6 | 🔴 CRITICAL |
| B. Version & Service Worker | 2 | 🔴 CRITICAL |
| C. Data Integrity | 7 | 🔴 CRITICAL |
| D. Security & Access | 3 | 🟠 HIGH |
| E. Factory Environment | 4 | 🟠 HIGH |
| F. Business Process | 4 | 🟡 MEDIUM |
| G. Analytics & Reporting | 2 | 🟢 LOW |

---

## 🔴 Category A: Device & Network Issues

### **A1. QR Scan Fails (Bright Light / Blurry / Damaged)**

**Scenario:** Operator tries to scan QR but camera can't focus or QR is damaged

**Root Cause:**
- Bright factory lighting
- Camera quality poor (budget phones)
- QR sticker damaged/dirty
- Wrong distance (too close/far)

**Guardrail:**
```javascript
// 1. Fallback to manual input
function enableQRFallback() {
    const $scanBtn = $('#manual-entry-btn');
    $scanBtn.click(() => {
        Swal.fire({
            title: 'สแกนไม่ติด?',
            html: `
                <input id="manual-code" 
                       class="swal2-input" 
                       placeholder="กรอกรหัส เช่น JT251030001"
                       autocomplete="off">
                <div class="text-muted mt-2">
                    <strong>เคล็ดลับ:</strong><br>
                    • เปิดไฟแฟลช<br>
                    • ถือห่าง 15-30 ซม.<br>
                    • ทำความสะอาด QR
                </div>
            `,
            showCancelButton: true,
            confirmButtonText: 'ยืนยัน',
            cancelButtonText: 'ยกเลิก',
            preConfirm: () => {
                const code = $('#manual-code').val().trim();
                if (!code) {
                    Swal.showValidationMessage('กรุณากรอกรหัส');
                    return false;
                }
                return code;
            }
        }).then(result => {
            if (result.isConfirmed) {
                lookupEntity(result.value);
            }
        });
    });
}

// 2. Flash control
function toggleFlash() {
    // Use MediaTrackConstraints
    const track = stream.getVideoTracks()[0];
    const capabilities = track.getCapabilities();
    
    if (capabilities.torch) {
        track.applyConstraints({
            advanced: [{torch: !flashOn}]
        });
        flashOn = !flashOn;
    }
}

// 3. Multi-format support
function initQRScanner() {
    const scanner = new Html5Qrcode("qr-reader");
    scanner.start(
        { facingMode: "environment" },
        {
            fps: 10,
            qrbox: { width: 250, height: 250 },
            // Support multiple formats
            formatsToSupport: [
                Html5QrcodeSupportedFormats.QR_CODE,
                Html5QrcodeSupportedFormats.CODE_128,
                Html5QrcodeSupportedFormats.EAN_13
            ]
        },
        onScanSuccess,
        onScanFailure
    );
}
```

**Test Scenarios:**
- [ ] Scan QR in bright sunlight (> 50k lux)
- [ ] Scan QR with damaged corner (30% missing)
- [ ] Scan QR with dirt/grease covering
- [ ] Scan QR from 5cm, 60cm distance
- [ ] Scan with flash on/off
- [ ] Manual entry after 3 failed scan attempts

**Acceptance Criteria:**
- Manual fallback appears after 3 failed scans or on user request
- Flash toggle works on 90% of devices
- Multi-format support (QR, Code 128, EAN-13)
- 95% scan success rate under normal conditions

---

### **A2. Camera/Microphone Permission Denied**

**Scenario:** User denies camera permission, app can't scan

**Root Cause:**
- First-time user denies by mistake
- Privacy concerns
- Browser restrictions

**Guardrail:**
```javascript
async function requestCameraPermission() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({ video: true });
        stream.getTracks().forEach(track => track.stop());
        return true;
    } catch (err) {
        if (err.name === 'NotAllowedError') {
            Swal.fire({
                icon: 'warning',
                title: 'ต้องการสิทธิ์กล้อง',
                html: `
                    <p>กรุณาอนุญาตการใช้กล้องเพื่อสแกน QR</p>
                    <div class="alert alert-info text-left mt-3">
                        <strong>วิธีเปิดสิทธิ์:</strong><br>
                        1. คลิกไอคอนกล้อง/ล็อกในแถบที่อยู่<br>
                        2. เลือก "อนุญาต" สำหรับกล้อง<br>
                        3. รีเฟรชหน้านี้
                    </div>
                `,
                confirmButtonText: 'ใช้โหมดกรอกมือแทน',
                showCancelButton: true,
                cancelButtonText: 'ลองอีกครั้ง'
            }).then(result => {
                if (result.isConfirmed) {
                    showManualEntry();
                } else {
                    location.reload();
                }
            });
        }
        return false;
    }
}
```

**Test Scenarios:**
- [ ] Deny camera permission → fallback works
- [ ] Grant permission after initial denial → scan works
- [ ] Block permission at OS level → fallback works

**Acceptance Criteria:**
- Clear instructions in Thai
- Manual entry fallback available
- No app crash on permission denial

---

### **A3. Network Offline During Initial Scan (Critical Gap)**

**Scenario:** Factory network down → operator scans ticket code → lookup fails → **production stops**

**Root Cause:**
- Internet outage (ISP failure)
- WiFi access point failure
- Server maintenance
- Peak hour congestion

**Business Impact:** 🚨 **CRITICAL - Blocks entire production line**

**Current State:**
- ✅ Submit actions offline → queue works perfectly
- ❌ **Initial ticket lookup requires network** → if offline, can't load ticket data → can't start work

**Guardrail:**
```javascript
// 1. Pre-cache active tickets (shift start)
async function preCacheActiveTickets() {
    try {
        const response = await fetch(`${PWA_API}?action=get_active_tickets`, {
            credentials: 'include'
        });
        
        const result = await response.json();
        
        if (result.ok && result.data) {
            // Cache to IndexedDB
            const db = await openTicketCacheDB();
            const tx = db.transaction('tickets', 'readwrite');
            const store = tx.objectStore('tickets');
            
            // Clear old cache
            await store.clear();
            
            // Store fresh tickets
            for (const ticket of result.data) {
                await store.put({
                    code: ticket.ticket_code,
                    data: ticket,
                    cached_at: Date.now(),
                    expires_at: Date.now() + (8 * 60 * 60 * 1000) // 8 hours
                });
            }
            
            console.log(`[Cache] ${result.data.length} tickets cached`);
            notifySuccess(`โหลดข้อมูล ${result.data.length} tickets สำเร็จ`);
        }
    } catch (error) {
        console.error('[Cache] Pre-cache failed:', error);
        notifyWarning('ไม่สามารถโหลดข้อมูลล่วงหน้า กรุณาเชื่อมต่อเน็ตก่อนสแกน');
    }
}

// 2. Offline-first lookup
async function lookupEntity(code) {
    // Try online first (fresh data)
    if (navigator.onLine) {
        try {
            const response = await fetch(`${PWA_API}?action=lookup&code=${code}`, {
                credentials: 'include',
                cache: 'no-store'
            });
            
            const result = await response.json();
            
            if (result.ok) {
                // Cache for offline use
                await cacheTicket(code, result.data);
                return result;
            }
        } catch (error) {
            console.warn('[Lookup] Online failed, trying cache...', error);
        }
    }
    
    // Fallback to cache (offline or online failed)
    const cachedData = await getCachedTicket(code);
    
    if (cachedData) {
        console.log('[Lookup] Using cached data');
        notifyInfo('🔄 ใช้ข้อมูลแคช (ออฟไลน์)', '', 2000);
        return { ok: true, data: cachedData, fromCache: true };
    }
    
    // No cache available
    return { 
        ok: false, 
        error: 'ไม่พบข้อมูล กรุณาเชื่อมต่อเน็ตหรือกด "โหลดข้อมูล" ก่อนใช้งาน'
    };
}

// 3. Manual download button
function initManualDownload() {
    $('#btn-download-tickets').click(async () => {
        Swal.fire({
            title: 'โหลดข้อมูล Tickets?',
            text: 'จะโหลดรายการ tickets ที่ active ทั้งหมด เพื่อใช้งานออฟไลน์',
            icon: 'question',
            showCancelButton: true,
            confirmButtonText: 'โหลดเลย',
            cancelButtonText: 'ยกเลิก'
        }).then(async (result) => {
            if (result.isConfirmed) {
                Swal.fire({
                    title: 'กำลังโหลด...',
                    allowOutsideClick: false,
                    didOpen: () => Swal.showLoading()
                });
                
                await preCacheActiveTickets();
                Swal.close();
            }
        });
    });
}
```

**Test Scenarios:**
- [ ] Download tickets → disconnect network → scan cached ticket → works ✅
- [ ] Offline scan (no cache) → show helpful error message
- [ ] Cache expires (8 hours) → prompt to refresh
- [ ] Online scan → auto-updates cache
- [ ] Network restored → auto-sync queue

**Acceptance Criteria:**
- "Download Tickets" button visible in header
- Cache stores 8 hours (shift duration)
- Offline lookup works for cached tickets (95%+ success)
- Clear error message if ticket not cached
- Auto-refresh cache every 4 hours (background)

**Priority:** 🔴 **CRITICAL** (Production blocker)  
**ETA:** 4 hours (Week 1 of Pilot)  
**Status:** ✅ **IMPLEMENTED** (Oct 31, 2025)

**Implementation Details:**
- Download button with progress bar
- IndexedDB cache (100 active tickets)
- Offline fallback in lookupEntity()
- Auto-refresh every 1 hour
- Cached count display with timestamp
- Warning message when using cached data

---

### **A4. Offline for Extended Period (Network Loss)**

**Scenario:** Operator works offline for 1+ hour, multiple logs queued

**Root Cause:**
- WiFi dead zone in factory
- Internet outage
- Router issues

**Guardrail:**
```javascript
// 1. Offline detection
window.addEventListener('online', () => {
    updateOnlineStatus(true);
    triggerAutoSync();
});

window.addEventListener('offline', () => {
    updateOnlineStatus(false);
});

function updateOnlineStatus(isOnline) {
    const $indicator = $('#network-status');
    if (isOnline) {
        $indicator.removeClass('offline').addClass('online').text('🟢 ออนไลน์');
    } else {
        $indicator.removeClass('online').addClass('offline').text('🔴 ออฟไลน์ (จะบันทึกเมื่อกลับมา)');
    }
}

// 2. IndexedDB queue
async function queueOfflineAction(action) {
    const queue = await window.offlineQueue.getAll();
    
    // Prevent queue overflow (max 100 items)
    if (queue.length >= 100) {
        notifyWarning('คิวเต็ม กรุณาเชื่อมต่อเน็ตเพื่อส่งข้อมูล');
        return false;
    }
    
    await window.offlineQueue.add(action);
    updateQueueCount(queue.length + 1);
    return true;
}

// 3. Manual sync button
$('#manual-sync-btn').click(async () => {
    if (!navigator.onLine) {
        notifyError('ไม่มีสัญญาณเน็ต กรุณาลองใหม่ภายหลัง');
        return;
    }
    
    const count = await window.offlineQueue.count();
    if (count === 0) {
        notifyInfo('ไม่มีข้อมูลรอส่ง');
        return;
    }
    
    Swal.fire({
        title: `ส่งข้อมูล ${count} รายการ?`,
        text: 'อาจใช้เวลาสักครู่',
        showCancelButton: true,
        confirmButtonText: 'ส่งเลย',
        cancelButtonText: 'ยกเลิก'
    }).then(async (result) => {
        if (result.isConfirmed) {
            const success = await window.offlineQueue.sync();
            if (success) {
                notifySuccess('ส่งข้อมูลสำเร็จ!');
            } else {
                notifyError('ส่งข้อมูลล้มเหลว บางรายการ');
            }
        }
    });
});
```

**Test Scenarios:**
- [ ] Go offline → log 10 actions → go online → all synced
- [ ] Offline for 60 min → 50 actions → sync success
- [ ] Queue reaches 100 items → warning shown
- [ ] Manual sync button works correctly

**Acceptance Criteria:**
- 100% data safety (no data loss)
- Clear offline indicator
- Manual sync available
- Queue limit prevents memory issues

---

### **A4. Background Sync Blocked (Battery Saver / iOS)**

**Scenario:** Background Sync API disabled by OS

**Root Cause:**
- Battery saver mode
- iOS restrictions
- Browser policy

**Guardrail:**
```javascript
// 1. Check Background Sync support
async function checkBackgroundSyncSupport() {
    if ('serviceWorker' in navigator && 'sync' in registration) {
        return true;
    }
    
    // Fallback: manual sync only
    console.warn('Background Sync not supported - using manual sync only');
    $('#manual-sync-btn').removeClass('d-none'); // Show manual sync button
    return false;
}

// 2. Retry policy with exponential backoff
async function syncWithRetry(maxRetries = 3) {
    let attempt = 0;
    let delay = 1000; // Start with 1s
    
    while (attempt < maxRetries) {
        try {
            const result = await window.offlineQueue.sync();
            if (result.success) {
                return true;
            }
        } catch (err) {
            console.error(`Sync attempt ${attempt + 1} failed:`, err);
        }
        
        attempt++;
        if (attempt < maxRetries) {
            await new Promise(resolve => setTimeout(resolve, delay));
            delay *= 2; // Exponential backoff
        }
    }
    
    return false;
}

// 3. User notification
function notifyManualSyncRequired() {
    if (Notification.permission === 'granted') {
        new Notification('ข้อมูลรอส่ง', {
            body: 'กรุณาเปิดแอปเพื่อส่งข้อมูล',
            icon: '/assets/icons/icon-192x192.png',
            badge: '/assets/icons/badge-72x72.png',
            tag: 'sync-required',
            requireInteraction: true
        });
    }
}
```

**Test Scenarios:**
- [ ] Enable Battery Saver → manual sync still works
- [ ] iOS device → manual sync only mode
- [ ] Sync fails 3 times → notification shown

**Acceptance Criteria:**
- Manual sync always available as fallback
- Retry policy with backoff
- User notification when sync required

---

### **A5. Storage Quota Exceeded (Private Mode / Low Storage)**

**Scenario:** IndexedDB quota exceeded, can't queue more actions

**Root Cause:**
- Private/Incognito mode (limited quota)
- Device storage full
- Too many queued items

**Guardrail:**
```javascript
// 1. Check available storage
async function checkStorageQuota() {
    if (navigator.storage && navigator.storage.estimate) {
        const estimate = await navigator.storage.estimate();
        const percentUsed = (estimate.usage / estimate.quota) * 100;
        
        if (percentUsed > 90) {
            notifyWarning('พื้นที่เก็บข้อมูลใกล้เต็ม กรุณาส่งข้อมูลหรือเคลียร์คิว');
            return false;
        }
    }
    return true;
}

// 2. Compact payload (reduce size)
function compactPayload(action) {
    return {
        a: action.action,          // Short keys
        t: action.taskId,
        q: action.qty,
        e: action.event,
        ts: Date.now(),
        k: action.idempotency_key
        // Remove redundant fields
    };
}

// 3. Auto-cleanup old items
async function cleanupOldQueue() {
    const queue = await window.offlineQueue.getAll();
    const now = Date.now();
    const maxAge = 7 * 24 * 60 * 60 * 1000; // 7 days
    
    const toRemove = queue.filter(item => (now - item.timestamp) > maxAge);
    
    if (toRemove.length > 0) {
        for (const item of toRemove) {
            await window.offlineQueue.remove(item.id);
        }
        console.log(`Cleaned up ${toRemove.length} old queue items`);
    }
}
```

**Test Scenarios:**
- [ ] Private mode → limited quota warning
- [ ] Storage > 90% → warning + cleanup
- [ ] Queue items older than 7 days → auto-removed

**Acceptance Criteria:**
- Warning at 90% storage
- Compact payload format
- Auto-cleanup of stale items

---

## 🔴 Category B: Version & Service Worker Issues

### **B1. App Update During Active Use (Schema Incompatible)**

**Scenario:** User has app v1 open, server deploys v2 with breaking changes

**Root Cause:**
- Continuous deployment
- Schema migration
- API endpoint changes

**Guardrail:**
```javascript
// 1. App version negotiation
const APP_VERSION = '1.2.0';

function addVersionToRequest(data) {
    return {
        ...data,
        app_version: APP_VERSION,
        client_time: new Date().toISOString()
    };
}

// 2. Server-side version check
// Backend (PHP):
/*
$clientVersion = $_POST['app_version'] ?? '0.0.0';
$serverVersion = '1.2.0';

if (version_compare($clientVersion, $serverVersion, '<')) {
    // Client outdated
    json_error('app_outdated', 426); // 426 Upgrade Required
    exit;
}
*/

// 3. Handle outdated app
$(document).ajaxError(function(event, jqXHR, settings, thrownError) {
    if (jqXHR.status === 426) {
        const response = jqXHR.responseJSON;
        
        Swal.fire({
            icon: 'warning',
            title: 'มีเวอร์ชันใหม่',
            text: response.error || 'กรุณารีเฟรชหน้าเพื่ออัปเดต',
            confirmButtonText: 'รีเฟรชเลย',
            allowOutsideClick: false
        }).then(() => {
            window.location.reload(true);
        });
    }
});
```

**Test Scenarios:**
- [ ] Client v1 + Server v2 → upgrade prompt
- [ ] Reload works correctly
- [ ] No data loss during upgrade

**Acceptance Criteria:**
- Version mismatch detected
- Clear upgrade message
- Reload preserves current context (if possible)

---

### **B2. Service Worker Stuck on Old Version**

**Scenario:** Service Worker cached old version, user doesn't see updates

**Root Cause:**
- Browser caching aggressive
- skipWaiting() not called
- User doesn't reload

**Guardrail:**
```javascript
// 1. Service Worker update detection
if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/service-worker.js').then(registration => {
        // Check for updates every 1 hour
        setInterval(() => {
            registration.update();
        }, 60 * 60 * 1000);
        
        // Listen for updates
        registration.addEventListener('updatefound', () => {
            const newWorker = registration.installing;
            
            newWorker.addEventListener('statechange', () => {
                if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                    // New version available
                    showUpdateBanner();
                }
            });
        });
    });
}

// 2. Update banner
function showUpdateBanner() {
    const $banner = $('<div>')
        .addClass('update-banner')
        .html(`
            <div class="update-banner-content">
                <i class="fas fa-info-circle"></i>
                <span>มีเวอร์ชันใหม่ กรุณารีเฟรชเพื่ออัปเดต</span>
                <button id="update-now-btn" class="btn btn-sm btn-light">รีเฟรชเลย</button>
            </div>
        `);
    
    $('body').prepend($banner);
    
    $('#update-now-btn').click(() => {
        window.location.reload(true);
    });
}

// 3. Service Worker (skipWaiting)
// In service-worker.js:
self.addEventListener('install', (event) => {
    self.skipWaiting(); // Activate immediately
});

self.addEventListener('activate', (event) => {
    event.waitUntil(clients.claim()); // Take control immediately
});
```

**Test Scenarios:**
- [ ] Deploy new SW → update banner appears
- [ ] Click "รีเฟรชเลย" → new version loads
- [ ] Auto-check every 1 hour

**Acceptance Criteria:**
- Update detection works
- skipWaiting() + claim() implemented
- User sees update banner

---

## 🔴 Category C: Data Integrity Issues

### **C1. Double Tap / Network Retry (Duplicate Logs)**

**Scenario:** Operator double-taps button or network retries request

**Root Cause:**
- Impatient user (no feedback)
- Network timeout + retry
- Button not locked

**Guardrail:**
```javascript
// 1. Idempotency key per form
function getOrCreateIdempotencyKey($form) {
    let key = $form.data('idem-key');
    if (!key) {
        key = uuidv4();
        $form.data('idem-key', key);
    }
    return key;
}

// 2. Button locking
function withButtonLock($button, asyncFn) {
    return async function(...args) {
        if ($button.hasClass('is-loading')) {
            return; // Already processing
        }
        
        $button.addClass('is-loading').prop('disabled', true);
        
        try {
            await asyncFn.apply(this, args);
        } finally {
            $button.removeClass('is-loading').prop('disabled', false);
        }
    };
}

// 3. Backend idempotency check
// PHP:
/*
$idempotencyKey = $_POST['idempotency_key'] ?? null;
if (!$idempotencyKey) {
    json_error('idempotency_key required', 400);
}

// Check if already processed
$stmt = $db->prepare("SELECT 1 FROM atelier_wip_log WHERE id_job_task=? AND idempotency_key=?");
$stmt->bind_param('is', $taskId, $idempotencyKey);
$stmt->execute();
$exists = $stmt->get_result()->num_rows > 0;

if ($exists) {
    // Safe duplicate - return success without inserting
    json_success(['duplicate' => true, 'message' => 'Already processed']);
    exit;
}
*/

// Usage
$('#complete-btn').click(withButtonLock($('#complete-btn'), async function() {
    const key = getOrCreateIdempotencyKey($('#log-form'));
    const payload = {
        action: 'complete',
        qty: 1,
        idempotency_key: key
    };
    
    const response = await $.post('source/pwa_scan_api.php', payload);
    
    if (response.ok) {
        // Clear key for next action
        $('#log-form').removeData('idem-key');
        showSuccessAnimation();
    }
}));
```

**Test Scenarios:**
- [ ] Rapid click 10 times → only 1 log created
- [ ] Network timeout + retry → no duplicate
- [ ] Same form submit twice → duplicate caught

**Acceptance Criteria:**
- < 0.1% duplicate rate
- Button locked during processing
- Backend idempotency check

---

### **C2. Device Time Wrong (Timezone Shift)**

**Scenario:** Operator's device time is incorrect or wrong timezone

**Root Cause:**
- Manual time setting
- Timezone misconfigured
- Travel/relocation

**Guardrail:**
```javascript
// 1. Always use server time for WIP logs
// Backend (PHP):
/*
// Ignore client timestamp, use server time
$eventTime = date('Y-m-d H:i:s'); // Always UTC

// But check if client time is way off (warning)
$clientTime = $_POST['client_time'] ?? null;
if ($clientTime) {
    $serverTimestamp = time();
    $clientTimestamp = strtotime($clientTime);
    $diff = abs($serverTimestamp - $clientTimestamp);
    
    if ($diff > 300) { // 5 minutes
        error_log("WARNING: Client time off by {$diff}s - device_id: {$deviceId}");
    }
}
*/

// 2. Frontend warning
function checkTimeSyncIssue() {
    const clientTime = Date.now();
    
    $.post('source/pwa_scan_api.php', {
        action: 'check_time_sync',
        client_time: new Date().toISOString()
    }, function(resp) {
        if (resp.time_diff_seconds > 300) {
            notifyWarning('เวลาอุปกรณ์ไม่ตรง อาจส่งผลต่อสถิติ');
        }
    });
}

// 3. Display in local timezone (UI only)
function formatDateTime(utcTimestamp) {
    return new Date(utcTimestamp).toLocaleString('th-TH', {
        timeZone: 'Asia/Bangkok',
        dateStyle: 'medium',
        timeStyle: 'short'
    });
}
```

**Test Scenarios:**
- [ ] Set device time +1 day → warning shown, but data correct
- [ ] Set device timezone wrong → UI shows correct local time

**Acceptance Criteria:**
- Server time used for all logs (UTC)
- Warning if device time off > 5 min
- UI converts to local timezone for display

---

### **C3. Undo Used Incorrectly (Wrong Log / Timing)**

**Scenario:** Operator undos wrong action or tries to undo too old

**Root Cause:**
- Misunderstanding what undo does
- Trying to undo old actions
- Undo after other actions

**Guardrail:**
```javascript
// 1. Undo stack (max 3 recent)
const undoStack = [];
const MAX_UNDO = 3;

function addToUndoStack(action) {
    undoStack.push({
        action: action.type,
        payload: action.data,
        timestamp: Date.now(),
        idempotency_key: action.key,
        displayText: `${action.type} ${action.qty || ''} ชิ้น`
    });
    
    if (undoStack.length > MAX_UNDO) {
        undoStack.shift();
    }
    
    updateUndoButton();
}

// 2. Undo confirmation with preview
function performUndo() {
    if (undoStack.length === 0) return;
    
    const lastAction = undoStack[undoStack.length - 1];
    const timeSince = Math.floor((Date.now() - lastAction.timestamp) / 1000);
    
    Swal.fire({
        title: 'ยกเลิกการกระทำล่าสุด?',
        html: `
            <div class="undo-preview">
                <p><strong>กระทำ:</strong> ${lastAction.displayText}</p>
                <p><strong>เมื่อ:</strong> ${timeSince} วินาทีที่แล้ว</p>
            </div>
            <div class="alert alert-warning mt-3">
                ⚠️ การยกเลิกจะส่งผลต่อ:<br>
                • ยอดผลงานลดลง<br>
                • สถานะ session อาจเปลี่ยน
            </div>
        `,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'ยกเลิกเลย',
        confirmButtonColor: '#ef4444',
        cancelButtonText: 'ไม่ยกเลิก'
    }).then(result => {
        if (result.isConfirmed) {
            executeUndo(lastAction);
        }
    });
}

// 3. Backend soft-delete by idempotency_key
// PHP:
/*
case 'undo_log':
    $idempotencyKey = $_POST['idempotency_key'] ?? null;
    if (!$idempotencyKey) {
        json_error('idempotency_key required', 400);
    }
    
    // Soft delete by key
    $stmt = $db->prepare("
        UPDATE atelier_wip_log 
        SET deleted_at=NOW(), deleted_by=?, deleted_reason='undo'
        WHERE idempotency_key=? AND deleted_at IS NULL
    ");
    $stmt->bind_param('is', $userId, $idempotencyKey);
    $stmt->execute();
    
    if ($stmt->affected_rows > 0) {
        // Rebuild sessions
        $sessionService->rebuildSessionsFromLogs($taskId);
        json_success(['undone' => true]);
    } else {
        json_error('Log not found or already deleted', 404);
    }
    break;
*/
```

**Test Scenarios:**
- [ ] Undo last 3 actions sequentially → progress correct
- [ ] Undo after 10 min → still works
- [ ] Try undo 4th action → not in stack

**Acceptance Criteria:**
- Max 3 actions in undo stack
- Clear preview of what will be undone
- Soft-delete with audit trail

---

### **C4. Piece Mode with qty > 1 or Missing Serial**

**Scenario:** Atelier task (piece mode) submitted with qty > 1 or no serial

**Root Cause:**
- User error
- Validation skipped
- Copy-paste from batch task

**Guardrail:**
```javascript
// 1. Frontend validation
function validatePieceModeInput(task, qty, serial) {
    if (task.process_mode === 'piece') {
        if (qty !== 1) {
            notifyError('งานแบบ Piece ต้องทำทีละ 1 ชิ้นเท่านั้น');
            return false;
        }
        
        if (!serial || serial.trim() === '') {
            notifyError('งานแบบ Piece ต้องระบุ Serial Number');
            return false;
        }
    }
    
    return true;
}

// 2. UI enforcement
function adjustUIForProcessMode(mode) {
    const $qtyInput = $('#log-qty');
    const $serialWrapper = $('#serial-wrapper');
    
    if (mode === 'piece') {
        // Force qty = 1
        $qtyInput.val(1).prop('readonly', true).attr({
            min: 1,
            max: 1,
            step: 1
        });
        
        // Show serial input (required)
        $serialWrapper.removeClass('d-none');
        $('#log-serial').prop('required', true);
        
        // Add helper text
        $('#qty-hint').text('Atelier mode: ทำทีละ 1 ชิ้น ต้องระบุ Serial');
    } else {
        // Batch mode
        $qtyInput.prop('readonly', false).attr({
            min: 0,
            step: 1
        }).removeAttr('max');
        
        $serialWrapper.addClass('d-none');
        $('#log-serial').prop('required', false);
        
        $('#qty-hint').text('กรอกจำนวนชิ้นงานที่ทำในครั้งนี้');
    }
}

// 3. Backend validation
// PHP:
/*
if ($task['process_mode'] === 'piece') {
    if ($qty !== 1) {
        json_error('Piece mode requires qty=1', 400);
    }
    
    if (empty($data['serial_number'])) {
        json_error('Piece mode requires serial_number', 400);
    }
}
*/
```

**Test Scenarios:**
- [ ] Piece task + qty=2 → blocked with error
- [ ] Piece task + no serial → blocked
- [ ] Batch task + qty=10 → allowed
- [ ] UI adapts based on task mode

**Acceptance Criteria:**
- 100% validation coverage
- Clear error messages in Thai
- UI prevents incorrect input

---

### **C5. Routing Changed Mid-Production**

**Scenario:** Task routing updated while operators are actively working

**Root Cause:**
- Engineering change order (ECO)
- Process improvement
- Error correction

**Guardrail:**
```javascript
// 1. Versioned routing
// Backend schema:
/*
ALTER TABLE atelier_job_task ADD COLUMN routing_version INT NOT NULL DEFAULT 1;
ALTER TABLE atelier_wip_log ADD COLUMN task_routing_version INT NULL;
*/

// 2. Migration strategy when routing changes
// PHP:
/*
function migrateActiveSessions($ticketId, $oldTaskId, $newTaskId) {
    $db = tenant_db();
    
    // Option A: Auto-pause old task
    $db->query("
        UPDATE atelier_task_operator_session
        SET status='paused', paused_at=NOW()
        WHERE id_job_task={$oldTaskId} AND status='active'
    ");
    
    // Option B: Alert supervisor to manually resolve
    createSupervisorAlert([
        'type' => 'routing_change',
        'ticket_id' => $ticketId,
        'old_task' => $oldTaskId,
        'new_task' => $newTaskId,
        'message' => 'Task routing changed - please review active sessions'
    ]);
}
*/

// 3. Frontend notification
function handleRoutingChange(notification) {
    Swal.fire({
        icon: 'info',
        title: 'งานมีการเปลี่ยนแปลง',
        html: `
            <p>ขั้นตอนงานถูกปรับปรุง</p>
            <p>กรุณาตรวจสอบงานใหม่ก่อนทำต่อ</p>
        `,
        confirmButtonText: 'รับทราบ'
    }).then(() => {
        refreshTaskList();
    });
}
```

**Test Scenarios:**
- [ ] Change routing while session active → auto-pause + alert
- [ ] Operator sees updated task list
- [ ] Progress not lost

**Acceptance Criteria:**
- Active sessions auto-paused
- Supervisor notified
- No data corruption

---

### **C6. Ticket Cancelled During Production**

**Scenario:** Job ticket cancelled while operators are working on it

**Root Cause:**
- Customer cancellation
- Material unavailable
- Planning error

**Guardrail:**
```javascript
// 1. Auto-pause all sessions
// PHP:
/*
function cancelTicket($ticketId, $reason) {
    $db = tenant_db();
    
    // 1. Update ticket status
    $db->query("
        UPDATE atelier_job_ticket 
        SET status='cancelled', cancelled_at=NOW(), cancel_reason='{$reason}'
        WHERE id_job_ticket={$ticketId}
    ");
    
    // 2. Auto-pause all active sessions
    $db->query("
        UPDATE atelier_task_operator_session s
        JOIN atelier_job_task t ON t.id_job_task=s.id_job_task
        SET s.status='paused', s.paused_at=NOW(), s.pause_reason='ticket_cancelled'
        WHERE t.id_job_ticket={$ticketId} AND s.status='active'
    ");
    
    // 3. Alert all affected operators
    notifyOperatorsOfCancellation($ticketId);
    
    // 4. Alert supervisor to resolve
    createSupervisorAlert([
        'type' => 'ticket_cancelled',
        'ticket_id' => $ticketId,
        'message' => "Ticket {$ticketId} cancelled - please reassign operators"
    ]);
}
*/

// 2. Frontend notification
function handleTicketCancellation(ticketId) {
    Swal.fire({
        icon: 'warning',
        title: 'งานถูกยกเลิก',
        html: `
            <p>Ticket ${ticketId} ถูกยกเลิกแล้ว</p>
            <p>กรุณาติดต่อหัวหน้างานเพื่อรับงานใหม่</p>
        `,
        confirmButtonText: 'รับทราบ',
        allowOutsideClick: false
    }).then(() => {
        // Redirect to home
        window.location.href = 'index.php?p=pwa_scan';
    });
}

// 3. Block new logs on cancelled ticket
// PHP:
/*
$ticket = getTicket($ticketId);
if ($ticket['status'] === 'cancelled') {
    json_error('Ticket is cancelled - cannot add new logs', 400);
}
*/
```

**Test Scenarios:**
- [ ] Cancel ticket with 3 active sessions → all paused
- [ ] Operators notified immediately
- [ ] Cannot submit new logs to cancelled ticket

**Acceptance Criteria:**
- All sessions auto-paused
- Clear notification to operators
- Supervisor alert for reassignment

---

### **C7. Abandoned Session Still Working (Long Break)**

**Scenario:** Session marked as abandoned but operator is still working

**Root Cause:**
- 14-day threshold too short
- Holiday/sick leave
- Custom order delays

**Guardrail:**
```javascript
// 1. Warning before auto-abandon
// PHP Cron (runs daily):
/*
function warnBeforeAbandon() {
    $db = tenant_db();
    
    // Find sessions paused for 7+ days (warning phase)
    $stmt = $db->query("
        SELECT s.id_session, s.id_job_task, s.operator_user_id, s.updated_at
        FROM atelier_task_operator_session s
        JOIN atelier_job_task t ON t.id_job_task=s.id_job_task
        WHERE s.status='paused'
          AND s.updated_at < NOW() - INTERVAL 7 DAY
          AND s.updated_at >= NOW() - INTERVAL 8 DAY
          AND t.status NOT IN ('done','cancelled')
    ");
    
    while ($row = $stmt->fetch_assoc()) {
        // Notify supervisor
        notifySupervisor([
            'type' => 'session_warning',
            'session_id' => $row['id_session'],
            'message' => "Session paused for 7 days - will auto-abandon in 7 days"
        ]);
    }
}

function markAbandoned() {
    $db = tenant_db();
    
    // Mark as abandoned after 14 days
    $stmt = $db->query("
        UPDATE atelier_task_operator_session s
        JOIN atelier_job_task t ON t.id_job_task=s.id_job_task
        SET s.status='abandoned', 
            s.active_marker=0,
            s.abandoned_at=NOW(), 
            s.abandoned_reason='auto_cleanup_14d'
        WHERE s.status='paused'
          AND s.updated_at < NOW() - INTERVAL 14 DAY
          AND t.status NOT IN ('done','cancelled')
    ");
    
    if ($stmt->affected_rows > 0) {
        notifySupervisor([
            'type' => 'sessions_abandoned',
            'count' => $stmt->affected_rows,
            'message' => "{$stmt->affected_rows} sessions marked as abandoned"
        ]);
    }
}
*/

// 2. Supervisor can reactivate
// PHP:
/*
case 'reactivate_session':
    $sessionId = (int)($_POST['session_id'] ?? 0);
    
    $stmt = $db->prepare("
        UPDATE atelier_task_operator_session
        SET status='active', 
            active_marker=1,
            abandoned_at=NULL,
            abandoned_reason=NULL,
            updated_at=NOW()
        WHERE id_session=? AND status='abandoned'
    ");
    $stmt->bind_param('i', $sessionId);
    $stmt->execute();
    
    if ($stmt->affected_rows > 0) {
        json_success(['message' => 'Session reactivated']);
    } else {
        json_error('Session not found or not abandoned', 404);
    }
    break;
*/
```

**Test Scenarios:**
- [ ] Pause for 7 days → supervisor warning
- [ ] Pause for 14 days → auto-abandoned
- [ ] Supervisor reactivates → works correctly

**Acceptance Criteria:**
- 7-day warning to supervisor
- 14-day threshold configurable
- Reactivation possible

---

## 🟠 Category D: Security & Access Control

### **D1. QR Code Shared / Screenshot (Unauthorized Access)**

**Scenario:** QR code photographed and shared, unauthorized person scans

**Root Cause:**
- QR sticker not secured
- Screenshot shared in LINE
- Intentional leak

**Guardrail:**
```javascript
// 1. Signed token in QR
// PHP (generate QR):
/*
function generateSignedQRPayload($ticketId, $expiryHours = 24) {
    $secret = getenv('QR_SECRET_KEY'); // From env
    $payload = [
        'ticket_id' => $ticketId,
        'expires_at' => time() + ($expiryHours * 3600),
        'issued_at' => time()
    ];
    
    $payloadJson = json_encode($payload);
    $signature = hash_hmac('sha256', $payloadJson, $secret);
    
    $qrData = base64_encode($payloadJson) . '.' . $signature;
    return $qrData;
}

function verifySignedQRPayload($qrData) {
    list($payloadB64, $signature) = explode('.', $qrData);
    
    $payloadJson = base64_decode($payloadB64);
    $payload = json_decode($payloadJson, true);
    
    // Verify signature
    $secret = getenv('QR_SECRET_KEY');
    $expectedSignature = hash_hmac('sha256', $payloadJson, $secret);
    
    if (!hash_equals($expectedSignature, $signature)) {
        return ['valid' => false, 'error' => 'Invalid signature'];
    }
    
    // Check expiry
    if ($payload['expires_at'] < time()) {
        return ['valid' => false, 'error' => 'QR expired'];
    }
    
    return ['valid' => true, 'payload' => $payload];
}
*/

// 2. Role-based access
// PHP:
/*
$verification = verifySignedQRPayload($qrData);
if (!$verification['valid']) {
    json_error($verification['error'], 403);
}

$ticketId = $verification['payload']['ticket_id'];

// Check permission
if (!hasPermission($user, 'atelier.job.wip')) {
    // Show limited view only
    $ticket = getTicketSummary($ticketId); // No sensitive data
    json_success(['ticket' => $ticket, 'readonly' => true]);
} else {
    // Full access
    $ticket = getTicketFull($ticketId);
    json_success(['ticket' => $ticket, 'readonly' => false]);
}
*/
```

**Test Scenarios:**
- [ ] Scan expired QR → rejected
- [ ] Scan with insufficient permission → limited view
- [ ] Scan with tampered signature → rejected

**Acceptance Criteria:**
- QR expires after 24 hours (configurable)
- HMAC signature verified
- Role-based access enforced

---

### **D2. Device Lost / Stolen**

**Scenario:** Device with app installed is lost or stolen

**Root Cause:**
- Theft
- Misplaced
- Operator departure

**Guardrail:**
```javascript
// 1. Remote token revocation
// PHP Admin API:
/*
case 'revoke_device_token':
    $deviceId = $_POST['device_id'] ?? null;
    $userId = $_POST['user_id'] ?? null;
    
    // Revoke all tokens for this device/user
    $stmt = $db->prepare("
        UPDATE user_tokens 
        SET revoked_at=NOW(), revoke_reason='device_lost'
        WHERE device_id=? OR user_id=?
    ");
    $stmt->bind_param('si', $deviceId, $userId);
    $stmt->execute();
    
    json_success(['revoked' => $stmt->affected_rows]);
    break;
*/

// 2. Device binding (optional)
// Generate device fingerprint
function getDeviceFingerprint() {
    const data = {
        userAgent: navigator.userAgent,
        language: navigator.language,
        platform: navigator.platform,
        screenResolution: `${screen.width}x${screen.height}`,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
    };
    
    // Simple hash
    const fingerprint = btoa(JSON.stringify(data));
    localStorage.setItem('device_id', fingerprint);
    return fingerprint;
}

// 3. PIN lock (kiosk mode)
function enableKioskMode() {
    const pin = prompt('ตั้งรหัส PIN 4 หลัก:');
    if (pin && /^\d{4}$/.test(pin)) {
        localStorage.setItem('kiosk_pin', hashPIN(pin));
        localStorage.setItem('kiosk_enabled', 'true');
    }
}

function unlockKiosk() {
    if (localStorage.getItem('kiosk_enabled') !== 'true') {
        return true;
    }
    
    const pin = prompt('ใส่รหัส PIN:');
    const hashedPin = hashPIN(pin);
    
    if (hashedPin === localStorage.getItem('kiosk_pin')) {
        return true;
    } else {
        alert('PIN ไม่ถูกต้อง');
        return false;
    }
}
```

**Test Scenarios:**
- [ ] Report device lost → token revoked, cannot login
- [ ] Kiosk mode enabled → requires PIN
- [ ] Different device → requires reauth

**Acceptance Criteria:**
- Remote revocation works
- Device binding (optional)
- PIN lock available (kiosk mode)

---

### **D3. Operator Spoofing (Fake Name / Synthetic)**

**Scenario:** Someone submits WIP log with fake operator name

**Root Cause:**
- Synthetic operator allowed
- No validation
- Malicious intent

**Guardrail:**
```javascript
// 1. Disable synthetic in production
// PHP:
/*
if (empty($operatorUserId) || $operatorUserId <= 0) {
    json_error('Valid operator_user_id is required', 400);
}

// Verify operator exists
$stmt = $db->prepare("SELECT id_member FROM bgerp.account WHERE id_member=?");
$stmt->bind_param('i', $operatorUserId);
$stmt->execute();
$exists = $stmt->get_result()->num_rows > 0;

if (!$exists) {
    json_error('Operator not found', 404);
}

// Verify operator has permission
if (!hasPermission($operatorUserId, 'atelier.job.wip')) {
    json_error('Operator does not have WIP permission', 403);
}
*/

// 2. Frontend: No manual operator selection
// Only logged-in user can submit logs
const currentUserId = parseInt($('#current-user-id').val());

function submitWIPLog(data) {
    data.operator_user_id = currentUserId; // Force current user
    data.operator_name = $('#current-user-name').text();
    
    // Cannot be changed by user
    // ...
}
```

**Test Scenarios:**
- [ ] Submit with operator_user_id=0 → rejected
- [ ] Submit with non-existent operator → rejected
- [ ] Submit with operator without permission → rejected

**Acceptance Criteria:**
- 100% validation
- No synthetic operators in production
- Audit trail preserved

---

## 🟠 Category E: Factory Environment Issues

### **E1. Dirty Hands / Gloves (Cannot Touch Screen)**

**Scenario:** Operator has dirty hands or wearing gloves, can't use touchscreen

**Root Cause:**
- Grease/oil on hands
- Leather dust
- Safety gloves

**Guardrail:**
```css
/* 1. Large touch targets */
.action-button {
  min-width: 80px;
  min-height: 80px;
  padding: var(--space-4);
}

/* 2. High spacing between buttons */
.quick-action-panel {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--space-6); /* 24px minimum */
}

/* 3. Glove-friendly mode (increased sensitivity) */
@media (pointer: coarse) {
  /* Touch device detected */
  .action-button {
    min-width: 100px;
    min-height: 100px;
  }
}
```

**Alternative Input Methods:**
```javascript
// Voice commands (optional)
if ('webkitSpeechRecognition' in window) {
    const recognition = new webkitSpeechRecognition();
    recognition.lang = 'th-TH';
    recognition.continuous = false;
    
    $('#voice-command-btn').click(() => {
        recognition.start();
    });
    
    recognition.onresult = (event) => {
        const command = event.results[0][0].transcript.toLowerCase();
        
        if (command.includes('เริ่ม')) {
            triggerStart();
        } else if (command.includes('พัก')) {
            triggerPause();
        } else if (command.includes('เสร็จ')) {
            triggerComplete();
        }
    };
}

// NFC tap (future enhancement)
if ('NDEFReader' in window) {
    const reader = new NDEFReader();
    reader.scan().then(() => {
        reader.addEventListener("reading", ({ message }) => {
            const record = message.records[0];
            const action = new TextDecoder().decode(record.data);
            triggerAction(action);
        });
    });
}
```

**Test Scenarios:**
- [ ] Use with rubber gloves → buttons tappable
- [ ] Use with leather dust on hands → works
- [ ] Voice commands work (Thai)

**Acceptance Criteria:**
- 80x80px minimum button size
- 24px spacing between buttons
- Voice commands (optional, Thai support)

---

### **E2. Loud Factory Noise (Cannot Hear Audio Feedback)**

**Scenario:** Factory too loud (80-90 dB), operator can't hear success sound

**Root Cause:**
- Sewing machines
- Cutting equipment
- Multiple operators

**Guardrail:**
```javascript
// 1. Haptic feedback (primary)
function provideFeedback(type, includeSound = true) {
    // Vibration always
    if (navigator.vibrate) {
        const patterns = {
            success: [100, 50, 100],
            error: [200, 100, 200, 100, 200],
            warning: [100, 50, 100, 50, 100]
        };
        navigator.vibrate(patterns[type] || [100]);
    }
    
    // Sound (optional, user can disable)
    if (includeSound && getSoundEnabled()) {
        playSound(type);
    }
    
    // Visual overlay (critical)
    showVisualFeedback(type);
}

// 2. Visual feedback (large, full-screen)
function showVisualFeedback(type) {
    const colors = {
        success: 'rgba(34, 197, 94, 0.95)',
        error: 'rgba(239, 68, 68, 0.95)',
        warning: 'rgba(245, 158, 11, 0.95)'
    };
    
    const icons = {
        success: 'fa-check-circle',
        error: 'fa-times-circle',
        warning: 'fa-exclamation-triangle'
    };
    
    const $overlay = $('<div>')
        .css({
            position: 'fixed',
            top: 0, left: 0, right: 0, bottom: 0,
            background: colors[type],
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 9999,
            animation: 'fadeInOut 1.5s'
        });
    
    const $icon = $('<i>')
        .addClass(`fas ${icons[type]}`)
        .css({
            fontSize: '120px',
            color: 'white',
            animation: 'scaleIn 0.5s'
        });
    
    $overlay.append($icon);
    $('body').append($overlay);
    
    setTimeout(() => {
        $overlay.fadeOut(300, () => $overlay.remove());
    }, 1500);
}

// 3. LED flash (if device supports)
async function flashScreen() {
    if ('torch' in navigator.mediaDevices.getSupportedConstraints()) {
        const stream = await navigator.mediaDevices.getUserMedia({ video: true });
        const track = stream.getVideoTracks()[0];
        
        await track.applyConstraints({ advanced: [{torch: true}] });
        setTimeout(async () => {
            await track.applyConstraints({ advanced: [{torch: false}] });
            track.stop();
        }, 300);
    }
}
```

**Test Scenarios:**
- [ ] Simulate 90 dB noise → visual feedback clear
- [ ] Disable sound → haptic + visual still work
- [ ] LED flash works (if supported)

**Acceptance Criteria:**
- Visual feedback always shown
- Haptic feedback as primary
- Sound optional (user can disable)

---

### **E3. Bright Sunlight (Screen Not Readable)**

**Scenario:** Factory has large windows, screen washed out in sunlight

**Root Cause:**
- Direct sunlight
- No shade
- Low screen brightness

**Guardrail:**
```css
/* 1. High contrast colors */
:root {
  --text-primary: #1e293b;  /* Very dark */
  --bg-card: #ffffff;        /* Pure white */
  --contrast-ratio: 7:1;     /* WCAG AAA */
}

.action-button {
  /* High contrast text */
  color: white;
  text-shadow: 0 2px 4px rgba(0,0,0,0.3);
  
  /* Bold borders */
  border: 3px solid rgba(0,0,0,0.2);
  box-shadow: 0 4px 12px rgba(0,0,0,0.25);
}

/* 2. Larger text */
.action-button-label {
  font-size: 18px; /* Larger than normal */
  font-weight: 700; /* Bold */
}

/* 3. No subtle grays */
.text-secondary {
  color: #475569; /* Darker gray */
}
```

```javascript
// 4. Brightness tip
function suggestBrightnessIncrease() {
    if (window.screen.brightness && window.screen.brightness < 0.8) {
        notifyInfo('แนะนำเพิ่มความสว่างหน้าจอเพื่อมองเห็นชัดเจนขึ้น');
    }
}
```

**Test Scenarios:**
- [ ] View in direct sunlight (50k lux) → readable
- [ ] Contrast ratio > 7:1 for all text
- [ ] No subtle colors used

**Acceptance Criteria:**
- WCAG AAA contrast ratio (7:1)
- Bold text (600+ weight)
- High contrast button borders

---

### **E4. Accidental Scroll / Tap (Button Too Close)**

**Scenario:** Operator accidentally taps wrong button or scrolls page

**Root Cause:**
- Buttons too close
- No spacing
- Scroll sensitivity high

**Guardrail:**
```css
/* 1. Safe spacing (minimum 12-16px) */
.quick-action-panel {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 24px; /* Large gap */
  padding: 20px;
}

/* 2. Prevent accidental scroll */
.pwa-container {
  overscroll-behavior: contain;
  touch-action: pan-y; /* Only vertical scroll */
}

.action-button {
  touch-action: manipulation; /* Prevent double-tap zoom */
}

/* 3. Gesture lock (prevent swipe) */
.no-swipe {
  touch-action: none; /* Disable all touch gestures */
}
```

```javascript
// 4. Confirmation for critical actions
function requireConfirmation($button, action) {
    if ($button.data('require-confirm')) {
        Swal.fire({
            title: 'ยืนยัน?',
            icon: 'question',
            showCancelButton: true,
            confirmButtonText: 'ใช่',
            cancelButtonText: 'ยกเลิก'
        }).then(result => {
            if (result.isConfirmed) {
                action();
            }
        });
    } else {
        action();
    }
}
```

**Test Scenarios:**
- [ ] Rapid taps on adjacent buttons → correct one triggered
- [ ] Swipe gesture → doesn't accidentally navigate
- [ ] User testing: < 2 errors per 10 actions

**Acceptance Criteria:**
- 24px minimum spacing
- Touch-action optimized
- Confirmation for destructive actions

---

## 🟡 Category F: Business Process Issues

### **F1. Over-Production (Exceeds Target)**

**Scenario:** Operator continues working past target quantity

**Root Cause:**
- Not checking progress
- Intentional buffer
- Miscommunication

**Guardrail:**
- **Already implemented** in Quantity Management Strategy
- Server-side validation with 5% tolerance
- Supervisor override for exceptions

**Test Scenarios:**
- [ ] Submit qty > target+5% → blocked
- [ ] Supervisor override → allowed with reason
- [ ] Progress bar shows warning at 95%

**Acceptance Criteria:**
- 100% server-side validation
- 5% tolerance (configurable)
- Supervisor override logged

---

### **F2. Serial Number Traceability Gap**

**Scenario:** Missing serial numbers prevent complete traceability during recall

**Root Cause:**
- Serial not enforced in piece mode
- Operator skips field
- Validation missing

**Guardrail:**
- **Covered in C4 (Piece Mode Validation)**
- Serial required for all piece mode tasks
- Backend validation enforced

**Test Scenarios:**
- [ ] Search by serial → full history shown
- [ ] Piece mode without serial → blocked
- [ ] Export serial history CSV → complete

**Acceptance Criteria:**
- 100% serial coverage for piece mode
- Searchable by serial number
- Export functionality for compliance

---

### **F3. Shift Change / Operator Swap**

**Scenario:** Operator changes mid-task

**Root Cause:**
- Shift change
- Break coverage
- Skill rebalancing

**Guardrail:**
```javascript
// 1. Auto-pause current session on new start
// PHP:
/*
case 'start':
    $taskId = (int)($_POST['task_id'] ?? 0);
    $operatorId = $member['id_member'];
    
    // Check if operator has active session on different task
    $stmt = $db->prepare("
        SELECT id_session, id_job_task FROM atelier_task_operator_session
        WHERE operator_user_id=? AND status='active'
    ");
    $stmt->bind_param('i', $operatorId);
    $stmt->execute();
    $activeSession = $stmt->get_result()->fetch_assoc();
    
    if ($activeSession && $activeSession['id_job_task'] != $taskId) {
        // Auto-pause previous task
        $sessionService->handlePause($activeSession['id_job_task'], $operatorId, 'auto_switch');
        
        notifyInfo("งานก่อนหน้าถูกพักอัตโนมัติ");
    }
    
    // Start new task
    $sessionService->handleStart($taskId, $operatorId);
    json_success(['message' => 'Started']);
    break;
*/

// 2. Progress combines multiple operators
// Already implemented - sessions tracked per operator
// Progress = SUM(all operator sessions)
```

**Test Scenarios:**
- [ ] Operator A starts task → Operator B starts same task → both sessions tracked
- [ ] Operator changes task → previous auto-paused
- [ ] Progress calculation correct with 3 operators

**Acceptance Criteria:**
- Auto-pause on task switch
- Multi-operator sessions supported
- Progress combines correctly

---

### **F4. Priority Override (Urgent Order)**

**Scenario:** Urgent order needs to jump queue

**Root Cause:**
- Customer escalation
- Material expiry
- VIP order

**Guardrail:**
```javascript
// 1. Supervisor "pin to top"
// PHP:
/*
case 'pin_ticket':
    must_allow('atelier.job.ticket.manage'); // Supervisor only
    
    $ticketId = (int)($_POST['ticket_id'] ?? 0);
    $priority = (int)($_POST['priority'] ?? 1); // 1=normal, 2=high, 3=urgent
    
    $stmt = $db->prepare("
        UPDATE atelier_job_ticket
        SET priority=?, updated_at=NOW()
        WHERE id_job_ticket=?
    ");
    $stmt->bind_param('ii', $priority, $ticketId);
    $stmt->execute();
    
    json_success(['message' => 'Priority updated']);
    break;
*/

// 2. Visual indication
function renderTicketCard(ticket) {
    const priorityBadges = {
        1: '',
        2: '<span class="badge bg-warning">⚠️ ด่วน</span>',
        3: '<span class="badge bg-danger">🔥 เร่งด่วนมาก</span>'
    };
    
    const borderColors = {
        1: 'border-left: 4px solid #cbd5e1',
        2: 'border-left: 4px solid #f59e0b',
        3: 'border-left: 4px solid #ef4444'
    };
    
    return `
        <div class="ticket-card" style="${borderColors[ticket.priority]}">
            <h4>${ticket.ticket_code} ${priorityBadges[ticket.priority]}</h4>
            <p>${ticket.job_name}</p>
        </div>
    `;
}

// 3. Sort by priority
function sortTicketsByPriority(tickets) {
    return tickets.sort((a, b) => {
        // Priority first (3 > 2 > 1)
        if (a.priority !== b.priority) {
            return b.priority - a.priority;
        }
        // Then by due date
        return new Date(a.due_date) - new Date(b.due_date);
    });
}
```

**Test Scenarios:**
- [ ] Supervisor pins ticket → moves to top
- [ ] Operator sees urgent badge clearly
- [ ] Sort order correct (urgent → high → normal)

**Acceptance Criteria:**
- Supervisor can set priority
- Visual distinction clear
- Sort order enforced

---

## 🟢 Category G: Analytics & Reporting Issues

### **G1. Daily Report Incorrect (Session Crosses Midnight)**

**Scenario:** Report shows wrong date because session spans 2 days

**Root Cause:**
- Session started yesterday, completed today
- Report uses session.completed_at
- Wrong day attribution

**Guardrail:**
```sql
-- Use WIP log event_time (not session timestamps) for daily reports
-- PHP:
/*
function getDailyProductionReport($date) {
    $db = tenant_db();
    
    // Group by DATE(event_time) NOT by session completed_at
    $stmt = $db->prepare("
        SELECT 
            DATE(l.event_time) as report_date,
            l.operator_user_id,
            COUNT(*) as action_count,
            COALESCE(SUM(CASE WHEN l.event_type='complete' THEN l.qty ELSE 0 END), 0) as total_qty
        FROM atelier_wip_log l
        WHERE DATE(l.event_time) = ?
          AND l.deleted_at IS NULL
        GROUP BY DATE(l.event_time), l.operator_user_id
    ");
    $stmt->bind_param('s', $date);
    $stmt->execute();
    
    return $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
}
*/
```

**Test Scenarios:**
- [ ] Session: 23:00 Day 1 → 01:00 Day 2 → Report splits correctly
- [ ] Compare daily reports → sum matches total

**Acceptance Criteria:**
- Daily reports use event_time
- Sessions spanning days handled correctly

---

### **G2. Average Time Per Piece Wrong (First Piece Uses started_at)**

**Scenario:** Avg time calculation includes setup time in first piece

**Root Cause:**
- First piece: complete[0] - session.started_at (includes setup)
- Skews average upward

**Guardrail:**
```javascript
// PHP:
/*
function calculateAvgTimePerPiece($taskId) {
    $db = tenant_db();
    
    // Get all complete events ordered by time
    $stmt = $db->prepare("
        SELECT event_time, qty
        FROM atelier_wip_log
        WHERE id_job_task=? AND event_type='complete' AND deleted_at IS NULL
        ORDER BY event_time ASC
    ");
    $stmt->bind_param('i', $taskId);
    $stmt->execute();
    $logs = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    
    if (count($logs) < 2) {
        return null; // Not enough data
    }
    
    $durations = [];
    for ($i = 1; $i < count($logs); $i++) {
        $prevTime = strtotime($logs[$i-1]['event_time']);
        $currTime = strtotime($logs[$i]['event_time']);
        $duration = $currTime - $prevTime;
        
        // Filter outliers (> 95th percentile)
        if ($duration < 3600) { // Max 1 hour per piece
            $durations[] = $duration;
        }
    }
    
    if (empty($durations)) {
        return null;
    }
    
    // Use median (robust to outliers)
    sort($durations);
    $median = $durations[floor(count($durations) / 2)];
    
    return $median;
}
*/
```

**Test Scenarios:**
- [ ] First piece takes 30 min (setup) → not included in avg
- [ ] Outlier piece (phone call) → filtered out
- [ ] Median used instead of mean

**Acceptance Criteria:**
- First piece excluded from avg
- Outlier filtering (> P95 or > 1 hour)
- Median used (robust)

---

## ✅ Master Test Checklist

Before launching PWA to production:

### **Critical (Must Pass):**
- [ ] A1-A5: All device/network scenarios tested
- [ ] B1-B2: Version handling works
- [ ] C1-C7: Data integrity guaranteed (0 data loss)
- [ ] D1-D3: Security enforced (no unauthorized access)

### **High Priority:**
- [ ] E1-E4: Factory environment tested (gloves, noise, sunlight)
- [ ] F1-F4: Business process edge cases handled

### **Nice to Have:**
- [ ] G1-G2: Analytics accuracy verified

### **Acceptance Criteria:**
- **Functional:** 100% of critical scenarios pass
- **Usability:** < 2 errors per 10 actions (user testing)
- **Performance:** < 2s load time, < 100ms response
- **Reliability:** 99.9% uptime, 0% data loss
- **Security:** 0 unauthorized access incidents

---

## 🚀 Next Steps

1. **Prioritize:** Focus on Category A-C first (critical)
2. **Implement:** Add guardrails to codebase
3. **Test:** Run through each scenario
4. **Iterate:** Fix failures, retest
5. **Deploy:** Pilot with 5 operators
6. **Monitor:** Track metrics, gather feedback

---

**Last Updated:** October 30, 2025  
**Next Review:** After Pilot Deployment (Week 2)  
**Maintained by:** Development Team + QA

---

[END OF DOCUMENT]

