# Task 27.20 - Work Modal Implementation

**Date:** 2025-12-08  
**Status:** 🟡 PLANNING - มีแผนชัดเจน รอ implement  
**Last Updated:** 2025-12-08 03:30 ICT  
**Architecture Audit:** ✅ COMPLETE - See `20251207_TIME_ENGINE_ARCHITECTURE_AUDIT_V2.md`

---

## 🏛️ TIME ARCHITECTURE RULES (BINDING)

> **⚠️ CRITICAL:** ต้องอ่าน `docs/super_dag/00-audit/20251207_TIME_ENGINE_ARCHITECTURE_AUDIT_V2.md` ก่อนทำงาน

### Single Source of Truth Principle

```
┌─────────────────────────────────────────────────────────────┐
│              SINGLE SOURCE OF TRUTH                         │
│  WorkSessionTimeEngine.php (Backend - ONLY calculator)      │
│                         ↓                                   │
│              Timer DTO (JSON Response)                      │
│                         ↓                                   │
│  BGTimeEngine.js (Frontend - ONLY ticker)                   │
└─────────────────────────────────────────────────────────────┘
```

### Core Rules (BINDING - Violation = Immediate Reject)

| Rule | Description |
|------|-------------|
| **R1** | Backend is the ONLY time calculator - ห้ามคำนวณเวลาใน JavaScript |
| **R2** | One Timer DTO format - ห้ามสร้าง DTO format ใหม่ |
| **R3** | One API for time data - ห้ามสร้าง API คำนวณเวลาใหม่ |
| **R4** | BGTimeEngine is the ONLY ticker - ห้ามสร้าง setInterval timer ใหม่ |
| **R5** | Modal = Same render as Card - Modal ต้อง render เหมือน Token Card 100% |

### 🚫 Forbidden Actions

| Action | Why Forbidden |
|--------|---------------|
| สร้าง API คำนวณเวลาใหม่ (เช่น work_modal_api.php) | ละเมิด Single Source of Truth |
| คำนวณเวลาใน JavaScript (`new Date() - startedAt`) | Backend is ONLY calculator |
| สร้าง setInterval timer ใหม่ | BGTimeEngine is ONLY ticker |
| แก้ไข WorkSessionTimeEngine.php | 100% stable - NEVER TOUCH |
| แก้ไข BGTimeEngine.js core logic | 100% stable - NEVER TOUCH |
| สร้าง Modal rendering แยกจาก Card | Must use same render logic |

---

## 🔥 ROOT CAUSE (Architect Level Analysis)

### What Agent Did Wrong

1. **สร้าง `work_modal_api.php` แยก** → ละเมิด Single Source of Truth (R3)
2. **คำนวณเวลาเองใน JS** → ละเมิด Rule R1
3. **ไม่ใช้ `BGTimeEngine.updateTimerFromPayload()`** ใน Resume handler

### The ONLY Bug Left

**Location:** `work_queue.js` lines 2122-2127 (Resume handler)

```javascript
// ❌ CURRENT (WRONG):
if (resp.token && resp.token.timer) {
    const $timerEl = $('#workModalTimer');
    $timerEl.attr('data-status', 'active');
    $timerEl.attr('data-work-seconds-sync', resp.token.timer.work_seconds || 0);
    ...
}

// ✅ CORRECT (Copy from Pause handler):
const $timerEl = $('#workModalTimer');
if (resp.timer && typeof BGTimeEngine !== 'undefined') {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
}
```

**Why this is the bug:**
- Uses `resp.token.timer` → undefined (API returns `resp.timer`)
- Manual `attr()` assignments don't re-register element with BGTimeEngine
- Timer loses sync with drift-correction loop

---

## 📋 สถานะปัจจุบัน (หลัง Revert)

### ✅ สิ่งที่ทำงานได้ดี:
- **UI หลัก (Token Cards)** - timer เดินถูกต้อง
- **กดปุ่ม "ทำต่อ"** - resume ได้ปกติ สถานะเปลี่ยนถูกต้อง
- **กดปุ่ม "หยุด"** - pause ได้ปกติ
- **กดปุ่ม "เริ่ม"** - start ได้ปกติ

### ❌ สิ่งที่ยังไม่มี:
- **Modal ไม่เปิด** - ปุ่ม resume/start แค่เรียก API refresh UI ไม่ได้เปิด Modal
- **Modal Timer แสดง 00:00:00** - ไม่ได้ใช้ BGTimeEngine

---

## 🎯 เป้าหมาย Task 27.20

**เปลี่ยนพฤติกรรมปุ่ม:**
- กด "เริ่ม" / "ทำต่อ" → **เปิด Modal** (แทนที่จะแค่ refresh UI)
- Modal แสดง Behavior UI Template (CUT, STITCH, QC, etc.)
- Timer ใน Modal ใช้ `BGTimeEngine` (drift-corrected)

---

## 🔍 Root Cause Analysis

### ทำไม Modal ไม่เปิด?

**ไม่ใช่เพราะ API พัง** - API ทำงานได้ดี!

**เหตุผลจริง:**
```javascript
// work_queue.js บรรทัด 2004-2006
$(document).on('click', '.btn-resume-token', function() {
    const tokenId = $(this).data('token-id');
    resumeToken(tokenId);  // ← แค่เรียก API resume แล้ว refresh UI
});

// function resumeToken() บรรทัด 2324-2338
function resumeToken(tokenId) {
    $.post(API_URL, { action: 'resume_token', token_id: tokenId }, function(resp) {
        if (resp.ok) {
            loadWorkQueue({ showLoading: false });  // ← แค่ refresh ไม่ได้เปิด Modal!
        }
    });
}
```

**ต้องแก้เป็น:**
```javascript
$(document).on('click', '.btn-resume-token', function() {
    const tokenId = $(this).data('token-id');
    const nodeId = $(this).data('node-id');
    
    // 1. Resume API first
    $.post(API_URL, { action: 'resume_token', token_id: tokenId }, function(resp) {
        if (resp.ok) {
            // 2. Then open Modal
            openWorkModal(tokenId, nodeId, resp.token);
        }
    });
});
```

---

## 📝 IMPLEMENTATION PLAN (Enterprise Grade)

> **⚠️ CRITICAL:** Agent ต้องทำตามแผนนี้เท่านั้น ห้ามเพิ่มหรือลดขั้นตอน

### 🎯 Overview

| Item | Detail |
|------|--------|
| **Total Steps** | 4 Steps |
| **Estimated Time** | 30-45 minutes |
| **Files to Modify** | 2 files |
| **Files to Create** | 0 files |
| **Lines to Change** | ~30 lines |

---

### STEP 1: เพิ่ม `get_token_details` action ใน `dag_token_api.php`

**File:** `source/dag_token_api.php`

**1.1 เพิ่ม case ใน switch statement (หลัง line ~358)**

```php
case 'get_token_details':
    handleGetTokenDetails($db, $userId);
    break;
```

**1.2 สร้าง function `handleGetTokenDetails` (หลัง `handleGetWorkQueue`)**

```php
/**
 * Get single token details for Work Modal
 * Reuses logic from get_work_queue but returns single token
 * Uses WorkSessionTimeEngine for timer calculation (SSOT)
 */
function handleGetTokenDetails($db, $userId) {
    global $member, $cid;
    
    $tokenId = (int)($_REQUEST['token_id'] ?? 0);
    if ($tokenId <= 0) {
        json_error('Missing or invalid token_id', 400, ['app_code' => 'DAG_400_MISSING_TOKEN']);
    }
    
    $tenantDb = $db->getTenantDb();
    
    // Query single token with same fields as get_work_queue
    $sql = "
        SELECT 
            t.id_token,
            t.serial_number,
            t.status,
            t.current_node_id,
            t.id_instance,
            n.node_name,
            n.node_code,
            n.node_type,
            n.id_work_center,
            s.id_session,
            s.operator_user_id,
            s.status as session_status,
            s.started_at,
            s.paused_at,
            s.resumed_at,
            s.work_seconds,
            s.notes as pause_reason,
            jt.ticket_code,
            jt.job_name,
            jt.id_mo,
            jt.id_job_ticket,
            p.name as product_name
        FROM flow_token t
        JOIN routing_node n ON n.id_node = t.current_node_id
        LEFT JOIN token_work_session s ON s.id_token = t.id_token 
            AND s.status IN ('active', 'paused')
        LEFT JOIN job_graph_instance gi ON gi.id_instance = t.id_instance
        LEFT JOIN job_ticket jt ON jt.id_job_ticket = gi.id_job_ticket
        LEFT JOIN product p ON p.id_product = jt.id_product
        WHERE t.id_token = ?
    ";
    
    $stmt = $tenantDb->prepare($sql);
    $stmt->bind_param('i', $tokenId);
    $stmt->execute();
    $token = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    
    if (!$token) {
        json_error('Token not found', 404, ['app_code' => 'DAG_404_TOKEN']);
    }
    
    // Calculate timer using WorkSessionTimeEngine (SSOT)
    $timeEngine = new WorkSessionTimeEngine($db);
    $now = new \DateTimeImmutable('now');
    
    if (!empty($token['id_session'])) {
        $sessionRow = [
            'status' => $token['session_status'],
            'work_seconds' => $token['work_seconds'],
            'started_at' => $token['started_at'],
            'resumed_at' => $token['resumed_at'],
        ];
        $timer = $timeEngine->calculateTimer($sessionRow, $now);
    } else {
        $timer = [
            'work_seconds' => 0,
            'status' => 'none',
            'last_server_sync' => $now->format(DATE_ATOM),
        ];
    }
    
    // Load behavior metadata
    $behavior = null;
    if (!empty($token['id_work_center'])) {
        try {
            $behaviorRepo = new WorkCenterBehaviorRepository($db);
            $behaviorData = $behaviorRepo->getByWorkCenterId((int)$token['id_work_center']);
            if ($behaviorData) {
                $behavior = [
                    'code' => $behaviorData['code'],
                    'name' => $behaviorData['name'],
                    'execution_mode' => $behaviorData['execution_mode'],
                ];
            }
        } catch (\Throwable $e) {
            error_log('[get_token_details] Behavior load failed: ' . $e->getMessage());
        }
    }
    
    // Build response (same structure as get_work_queue token)
    json_success([
        'token' => [
            'id_token' => $token['id_token'],
            'serial_number' => $token['serial_number'],
            'status' => $token['status'],
            'node_id' => $token['current_node_id'],
            'node_name' => $token['node_name'],
            'ticket_code' => $token['ticket_code'],
            'job_name' => $token['job_name'],
            'job_ticket_id' => $token['id_job_ticket'],
            'product_name' => $token['product_name'],
            'work_center_id' => $token['id_work_center'],
            'mo_id' => $token['id_mo'],
            'timer' => $timer,
            'session' => $token['id_session'] ? [
                'id_session' => $token['id_session'],
                'status' => $token['session_status'],
                'started_at' => $token['started_at'],
                'resumed_at' => $token['resumed_at'],
                'paused_at' => $token['paused_at'],
                'notes' => $token['pause_reason'],
            ] : null,
            'behavior' => $behavior,
            'behavior_code' => $behavior['code'] ?? 'DEFAULT',
        ]
    ]);
}
```

**Checklist Step 1:**
- [ ] เพิ่ม case 'get_token_details' ใน switch
- [ ] สร้าง function handleGetTokenDetails
- [ ] ใช้ WorkSessionTimeEngine (SSOT)
- [ ] Return Timer DTO format เดียวกับ get_work_queue

---

### STEP 2: แก้ Resume handler ใน Modal

**File:** `assets/javascripts/pwa_scan/work_queue.js`

**Location:** Lines 2122-2127

**เปลี่ยนจาก:**
```javascript
// Update timer
if (resp.token && resp.token.timer) {
    const $timerEl = $('#workModalTimer');
    $timerEl.attr('data-status', 'active');
    $timerEl.attr('data-work-seconds-sync', resp.token.timer.work_seconds || 0);
    $timerEl.attr('data-last-server-sync', resp.token.timer.last_server_sync || new Date().toISOString());
}
```

**เป็น:**
```javascript
// Update timer using BGTimeEngine (same pattern as Pause handler)
const $timerEl = $('#workModalTimer');
if (resp.timer && typeof BGTimeEngine !== 'undefined') {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
}
```

**Checklist Step 2:**
- [ ] แก้ lines 2122-2127
- [ ] ใช้ resp.timer (ไม่ใช่ resp.token.timer)
- [ ] ใช้ BGTimeEngine.updateTimerFromPayload()

---

### STEP 3: อัพเดท `openWorkModal` ใช้ `get_token_details` (Optional)

**File:** `assets/javascripts/pwa_scan/work_queue.js`

**Location:** Lines 2233-2256 (inside openWorkModal function)

**เปลี่ยนจาก:**
```javascript
// Fetch token details from get_work_queue API
$.post(API_URL, {
    action: 'get_work_queue'
}, function(resp) {
    if (resp.ok && resp.nodes) {
        const allTokens = resp.nodes.flatMap(node => node.tokens || []);
        const numericTokenId = parseInt(tokenId, 10);
        const token = allTokens.find(t => parseInt(t.id_token, 10) === numericTokenId);
        // ...
    }
});
```

**เป็น:**
```javascript
// Fetch single token details from get_token_details API (faster)
$.post(API_URL, {
    action: 'get_token_details',
    token_id: tokenId
}, function(resp) {
    if (resp.ok && resp.token) {
        showModalWithData(resp.token);
    } else {
        notifyError(resp.error || t('work_queue.error.token_not_found', 'Token not found'));
    }
}, 'json').fail(function(xhr, status, error) {
    notifyError(t('common.error.connection', 'Connection error'));
});
```

**Checklist Step 3:**
- [ ] เปลี่ยน action จาก get_work_queue เป็น get_token_details
- [ ] ส่ง token_id parameter
- [ ] ใช้ resp.token (single token, ไม่ต้อง flatMap)

---

### STEP 4: เพิ่ม fields ที่ขาดใน `get_work_queue` session object

**File:** `source/dag_token_api.php`

**Location:** Lines 2205-2215 (inside handleGetWorkQueue, session object)

**เปลี่ยนจาก:**
```php
'session' => $token['id_session'] ? [
    'id_session' => $token['id_session'],
    'status' => $token['session_status'],
    'is_mine' => $token['operator_user_id'] == $operatorId,
    'started_at' => $token['started_at'],
    'resumed_at' => $token['resumed_at'],
    'total_pause_minutes' => (int)$token['total_pause_minutes'],
    'help_type' => $token['help_type'],
    'replacement_reason' => $token['replacement_reason']
] : null,
```

**เป็น:**
```php
'session' => $token['id_session'] ? [
    'id_session' => $token['id_session'],
    'status' => $token['session_status'],
    'is_mine' => $token['operator_user_id'] == $operatorId,
    'started_at' => $token['started_at'],
    'resumed_at' => $token['resumed_at'],
    'paused_at' => $token['paused_at'],           // ← เพิ่ม
    'notes' => $token['notes'] ?? null,            // ← เพิ่ม (pause reason)
    'total_pause_minutes' => (int)$token['total_pause_minutes'],
    'help_type' => $token['help_type'],
    'replacement_reason' => $token['replacement_reason']
] : null,
```

**Checklist Step 4:**
- [ ] เพิ่ม paused_at ใน session object
- [ ] เพิ่ม notes ใน session object
- [ ] ตรวจสอบว่า SQL query มี s.paused_at และ s.notes แล้ว

---

### 🧪 TESTING PLAN

**After All Steps Complete:**

| Test | Expected Result | Pass? |
|------|-----------------|-------|
| กด "เริ่ม" | Modal opens, timer shows correct time | [ ] |
| Timer ticks | Timer increases every second | [ ] |
| กด "หยุดพัก" | Timer stops, value retained | [ ] |
| กด "ทำต่อ" | Timer continues from paused value | [ ] |
| Refresh page | Modal re-opens if session active/paused | [ ] |
| API get_token_details | Returns token with timer DTO | [ ] |

---

### 🚫 FORBIDDEN ACTIONS (Reminder)

| Action | Consequence |
|--------|-------------|
| สร้างไฟล์ API ใหม่ | Immediate Reject |
| คำนวณเวลาใน JS | Immediate Reject |
| แก้ WorkSessionTimeEngine.php | Immediate Reject |
| แก้ BGTimeEngine.js core | Immediate Reject |
| ใช้ setInterval ใหม่ | Immediate Reject |

---

## 2. Key Architectural Concepts

### 2.1 Time Engine Architecture

ระบบมี **TimeEngine v2** ที่เป็น Single Source of Truth สำหรับการคำนวณเวลา:

**Backend (PHP):** `WorkSessionTimeEngine.php`
```php
// Timer DTO Structure
[
    'work_seconds'      => int,   // เวลารวม ณ ตอนนี้
    'base_work_seconds' => int,   // work_seconds จาก DB snapshot
    'live_tail_seconds' => int,   // ส่วนเพิ่มตั้งแต่ resumed_at/started_at
    'status'            => string,// active|paused|completed|none|unknown
    'started_at'        => string,// ISO8601 format
    'resumed_at'        => string,// ISO8601 format
    'last_server_sync'  => string // ISO8601 format (สำหรับ drift correction)
]
```

**Frontend (JS):** `BGTimeEngine` namespace ใน `work_queue_timer.js`
```javascript
// DOM Contract (required data attributes):
// - data-token-id: Unique identifier
// - data-status: 'active'|'paused'|'completed'|'none'|'unknown'
// - data-work-seconds-sync: number (work_seconds from server)
// - data-last-server-sync: ISO8601 string (server time)

// Usage:
BGTimeEngine.registerTimerElement(spanEl);
BGTimeEngine.updateTimerFromPayload(spanEl, timerDto);
```

### 2.2 Node Behavior Model

**Key Concepts (from BEHAVIOR_EXECUTION_SPEC.md):**

1. **Behavior Code** = Execution Pattern + UI Template + Time Tracking Model
   - ตัวอย่าง: `STITCH`, `CUT`, `EDGE`, `QC_SINGLE`

2. **Work Center** = Physical Station ที่โรงงานนิยาม
   - User สร้างได้ไม่จำกัด
   - เลือก Behavior จากชุดกลาง

3. **Separation of Concerns:**
   - Behavior ไม่รู้เรื่อง UI (ส่งแค่ data)
   - Frontend handles rendering
   - Time tracking ผ่าน TimeEngine

### 2.3 Behavior-Token Type Compatibility Matrix

| Behavior | batch | piece | component |
|----------|:-----:|:-----:|:---------:|
| CUT | ✅ | ❌ | ❌ |
| STITCH | ❌ | ✅ | ✅ |
| EDGE | ❌ | ✅ | ✅ |
| GLUE | ❌ | ✅ | ✅ |
| QC_SINGLE | ❌ | ✅ | ✅ |
| ASSEMBLY | ❌ | ✅ | ❌ |
| PACK | ❌ | ✅ | ❌ |

---

## 3. Components Status

### 2.1 Behavior UI Templates (`behavior_ui_templates.js`)

| Behavior Code | Template | Handler | Status |
|---------------|----------|---------|--------|
| CUT | Batch Production Form + BOM + Leather Sheet | ✅ | ⚠️ API path bug |
| STITCH | Time Control Panel | ✅ | ✅ Working |
| EDGE | Edge Paint Steps | ✅ | ✅ Working |
| HARDWARE_ASSEMBLY | Hardware Assembly Form | ✅ | ✅ Working |
| QC_SINGLE | QC Console | ✅ | 🔵 Needs defect catalog |
| QC_FINAL | Reuses QC_SINGLE | ✅ | 🔵 Needs defect catalog |
| QC_REPAIR | Reuses QC_SINGLE | ✅ | 🔵 Needs defect catalog |
| QC_INITIAL | Reuses QC_SINGLE | ✅ | 🔵 Needs defect catalog |
| SKIVE | Time Control | ✅ | ✅ Working |
| GLUE | Time Control | ✅ | ✅ Working |
| ASSEMBLY | Time Control | ✅ | ✅ Working |
| PACK | Time Control | ✅ | ✅ Working |
| EMBOSS | Time Control | ✅ | ✅ Working |
| DEFAULT | Fallback message | ✅ | ✅ Working |

**Total: 14 templates registered**

### 2.2 Work Modal Features (`work_queue.js`)

| Feature | Status | Notes |
|---------|--------|-------|
| Modal Open/Close | ❌ TODO | Static backdrop, can't close without action |
| Live Timer (BGTimeEngine) | ❌ TODO | Updates every second |
| Token Info Display | ❌ TODO | Serial, Job Name, Status |
| Pause Button | ❌ TODO | With reason selector (Swal) |
| Resume Button | ❌ TODO | Updates status and timer |
| Complete Button | ❌ TODO | With confirmation |
| Close Button | ❌ TODO | Only visible when paused |
| Auto-resume on page load | ❌ TODO | `checkAndResumeActiveSession()` |
| Behavior Form Loading | ❌ TODO | Loads from `BGBehaviorUI.getTemplate()` |
| Behavior Handler Init | ❌ TODO | Calls `handler.init($container, baseContext)` |

### 2.3 API Endpoints

| Endpoint | Purpose | Status |
|----------|---------|--------|
| `work_modal_api.php` | DELETED | ❌ ห้ามสร้างใหม่! |
| `dag_token_api.php` | Token actions (start/pause/resume/complete) | ✅ Working |
| `dag_behavior_exec.php` | Behavior execution | ✅ Working |
| `leather_sheet_api.php` | Leather sheet usage for CUT | ⚠️ Path issue |
| `leather_cut_bom_api.php` | BOM for CUT | ⚠️ Path issue |
| `defect_catalog_api.php` | Defect codes for QC | 🔵 Not integrated |

---

## 4. Known Issues

### 4.1 🔴 Critical: Duplicate Buttons in Modal

**Problem:** Modal มีปุ่ม 2 ชุดที่ซ้ำซ้อนกัน

**Location 1: Modal Footer** (`views/work_queue.php` lines 598-621)
```html
<div class="modal-footer">
    <button id="btnWorkPause">หยุดพัก</button>
    <button id="btnWorkResume">ทำต่อ</button>
    <button id="btnWorkComplete">จบงาน</button>
</div>
```

**Location 2: Behavior Template** (`behavior_ui_templates.js`)
```html
<!-- STITCH Template มีปุ่ม Start/Pause/Resume/Complete -->
<div class="btn-group w-100">
    <button id="btn-stitch-start">Start</button>
    <button id="btn-stitch-pause">Pause</button>
    <button id="btn-stitch-resume">Resume</button>
    <button id="btn-stitch-complete">Complete</button>
</div>
```

**Solution:** ยุบเหลือจุดเดียว
- ใช้ปุ่มใน Modal Footer เป็นหลัก (หยุดพัก/ทำต่อ/จบงาน)
- ลบปุ่มซ้ำออกจาก Behavior Templates
- หรือ ซ่อนปุ่มใน Template เมื่ออยู่ใน Modal

### 4.2 🔴 Critical: Timer Implementation Mismatch

**Problem:** Modal ใช้ `setInterval` เองใน `work_queue.js` แทนที่จะใช้ `BGTimeEngine` ที่มีอยู่แล้ว

**Current Implementation** (`work_queue.js` lines 2315-2336):
```javascript
// ❌ Manual setInterval - ไม่ใช้ BGTimeEngine
workModalTimerInterval = setInterval(function() {
    if (workModalIsPaused) return;
    const elapsed = Math.floor((now - workModalStartTime) / 1000) + workModalElapsedBeforePause;
    $('#workModalTimer').text(formatTime(elapsed));
}, 1000);
```

**Should Use** (`work_queue_timer.js`):
```javascript
// ✅ Use BGTimeEngine for drift-corrected timer
const $timerSpan = $('#workModalTimer');
$timerSpan.attr('data-token-id', tokenId);
$timerSpan.attr('data-status', 'active');
$timerSpan.attr('data-work-seconds-sync', timerDto.work_seconds);
$timerSpan.attr('data-last-server-sync', timerDto.last_server_sync);
BGTimeEngine.registerTimerElement($timerSpan[0]);
```

**Benefits:**
- Drift correction (client clock vs server clock)
- Auto-cleanup when element removed
- Consistent timer behavior across all pages

### 4.3 🔴 Critical: API Path Issues

**Problem:** `behavior_execution.js` uses relative paths that fail when accessed from `/work_queue` page.

```javascript
// Current (broken):
$.getJSON('source/leather_sheet_api.php', {...})

// Should be:
$.getJSON('/bellavier-group-erp/source/leather_sheet_api.php', {...})
```

**Console Error:**
```
Failed to load resource: 404 (Not Found)
http://localhost:8888/bellavier-group-erp/source/leather_sheet_api.php
```

**Affected APIs:**
- `leather_sheet_api.php` (7 occurrences)
- `leather_cut_bom_api.php` (3 occurrences)

### 4.4 🔴 Critical: Null Handling in renderSheetUsageList

**Problem:** `sheetUsages.forEach` throws TypeError when API returns non-array.

```javascript
// behavior_execution.js:345
TypeError: sheetUsages.forEach is not a function
```

**Fix Required:**
```javascript
// Add null check:
if (!Array.isArray(sheetUsages)) {
    sheetUsages = [];
}
```

### 4.5 🔴 Critical: Wrong Column Name in API Queries ✅ FIXED

**Problem:** `dag_token_api.php` and `work_modal_api.php` query non-existent column `work_seconds_total` instead of `work_seconds`.

**Fix Applied:**
```php
// Fixed: s.work_seconds_total → s.work_seconds
// Fixed: $session['work_seconds_total'] → $session['work_seconds']
```

### 4.6 🔴 Critical: People Monitor Missing Sessions Without Assignment ✅ FIXED

**Problem:** `team_api.php > people_monitor_list` uses `INNER JOIN token_assignment` as starting point.
If operator starts work directly from Work Queue (without assignment), the session is invisible!

**Root Cause:**
```sql
-- Token 1770 has active session but NO assignment!
Session 47: token=1770, operator=1, status=paused, work_seconds=523
            → NO token_assignment record!
```

**Impact:**
- People Monitor shows "Available" instead of "Paused"
- Timer shows 00:00:00
- Manager cannot see operator's actual work status

**Fix Applied:** Changed query to use UNION:
1. Part 1: Tokens with assignments (existing query)
2. Part 2: Active/paused sessions WITHOUT assignments (new)

```sql
-- Added: Sessions without assignment (direct start from Work Queue)
SELECT ... FROM token_work_session s
LEFT JOIN token_assignment ta ON ...
WHERE ta.id_assignment IS NULL  -- Only sessions without assignment
```

### 4.6 🟡 Medium: Timer Reset Issue (Duplicate of 4.5)

**This is the user-visible symptom of Issue 4.5**

**Problem:** Timer shows `00:00:00` instead of continuing from elapsed time when resuming paused work.

**Root Cause:** Combined effect of:
1. Wrong column name `work_seconds_total` → returns 0
2. Modal doesn't use `BGTimeEngine` (uses manual `setInterval`)

**Solution:** 
1. Fix column name (Issue 4.5)
2. Use `BGTimeEngine.updateTimerFromPayload()` with Timer DTO from API

### 4.6 🟡 Medium: BOM Not Configured

**Symptom:** Modal shows "ไม่มี BOM สำหรับขั้นตอนนี้"

**Cause:** Product doesn't have BOM configured for CUT stage, or BOM API returns empty.

### 4.7 🔵 Low: QC Defect Picker

**Current State:** QC templates have hardcoded defect options:
```html
<option value="SCRATCH">Scratch</option>
<option value="COLOR_MISMATCH">Color Mismatch</option>
```

**Required:** Load from `defect_catalog_api.php` dynamically.

---

## 5. Files Modified in This Task

| File | Changes |
|------|---------|
| `source/work_modal_api.php` | ❌ DELETED - ห้ามสร้างใหม่ |
| `source/dag_token_api.php` | Fixed SQL: `p.name` instead of `p.product_name` |
| `assets/javascripts/pwa_scan/work_queue.js` | Added `data-node-id`, changed API to `work_modal_api.php` |

---

## 6. Action Items

### 🔴 STEP 1: Revert dag_token_api.php (CRITICAL)

**ต้องแก้ไข function `handleGetTokenDetails()`:**

```php
// ✅ CORRECT SQL:
$sql = "
    SELECT 
        t.id_token,
        t.serial_number,
        t.status,
        t.current_node_id,
        t.id_instance,  -- ไม่ใช่ job_ticket_id
        t.rework_count,
        n.node_name,
        n.node_code,
        n.behavior_code,
        n.execution_mode,
        jt.ticket_code,
        jt.job_name,
        jt.id_mo,
        p.name AS product_name  -- ไม่ใช่ p.product_name
    FROM flow_token t
    LEFT JOIN routing_node n ON n.id_node = t.current_node_id
    LEFT JOIN job_graph_instance gi ON gi.id_graph_instance = t.id_instance
    LEFT JOIN job_ticket jt ON jt.id_job_ticket = gi.id_job_ticket  -- ไม่ใช่ atelier_job_ticket
    LEFT JOIN product p ON p.id_product = jt.id_product
    WHERE t.id_token = ?
";

// ✅ CORRECT Session SQL:
$sessionSql = "
    SELECT 
        s.id_session,
        s.operator_user_id,  -- ไม่ใช่ operator_id
        s.operator_name,
        s.status,
        s.started_at,
        s.resumed_at,  -- ต้องมี!
        s.paused_at,
        s.completed_at,
        s.work_seconds,  -- ไม่ใช่ work_seconds_total
        s.notes AS pause_reason  -- ใช้ alias
    FROM token_work_session s
    WHERE s.id_token = ?  -- ไม่ใช่ s.token_id
      AND s.status IN ('active', 'paused')
    ORDER BY s.id_session DESC
    LIMIT 1
";

// ✅ CORRECT Timer calculation (with resumed_at):
$baseWorkSeconds = (int)($session['work_seconds'] ?? 0);
$liveTailSeconds = 0;

if ($session['status'] === 'active') {
    $resumeTime = $session['resumed_at'] ? strtotime($session['resumed_at']) : null;
    $startTime = $session['started_at'] ? strtotime($session['started_at']) : null;
    $referenceTime = $resumeTime ?: $startTime;
    
    if ($referenceTime) {
        $now = time();
        $liveTailSeconds = max(0, $now - $referenceTime);
    }
}

$totalWorkSeconds = $baseWorkSeconds + $liveTailSeconds;

$timer = [
    'work_seconds' => $totalWorkSeconds,
    'base_work_seconds' => $baseWorkSeconds,
    'live_tail_seconds' => $liveTailSeconds,
    'status' => $session['status'],
    'started_at' => $session['started_at'],
    'resumed_at' => $session['resumed_at'],
    'last_server_sync' => date('c'),
    'formatted' => gmdate('H:i:s', $totalWorkSeconds),
    'is_paused' => ($session['status'] === 'paused')
];
```

### 🔴 STEP 2: ทดสอบหลัง Revert

```bash
# ทดสอบ API โดยตรง
curl -X POST "http://localhost:8888/bellavier-group-erp/source/dag_token_api.php" \
  -d "action=get_token_details&token_id=1770" \
  -b "PHPSESSID=xxx"

# ต้องได้:
# {"ok":true,"token":{...,"timer":{"work_seconds":12345,...}}}
```

### 🟡 STEP 3: หลังทดสอบผ่านแล้ว

- [ ] ทดสอบกดปุ่ม "ทำต่อ" → Modal ต้องเปิด
- [ ] ทดสอบ timer แสดงค่าถูกต้อง (ไม่ใช่ 00:00:00)
- [ ] ทดสอบ auto-resume on page load

### P1 - Short-term (หลัง Modal ทำงานได้)

- [ ] Fix API paths in `behavior_execution.js`
- [ ] Add null check in `renderSheetUsageList()`
- [ ] ยุบปุ่มซ้ำใน Modal (Modal Footer vs Behavior Template)
- [ ] ใช้ BGTimeEngine แทน setInterval

### P2 - Future

- [ ] Integrate `defect_catalog_api.php` with QC templates
- [ ] i18n: Migrate hardcoded Thai text to `t()` function
- [ ] Unit tests for behavior handlers

---

## 7. Testing Checklist

### Work Modal Flow

- [ ] Page load → Active session detected → Modal auto-opens
- [ ] Click "เริ่ม" (Start) → Modal opens, timer starts
- [ ] Click "หยุดพัก" (Pause) → Timer stops, close button appears
- [ ] Click "ทำต่อ" (Resume) → Timer resumes, close button hides
- [ ] Click "จบงาน" (Complete) → Token moves to next node
- [ ] Click "ปิดหน้าต่าง" (Close) → Modal closes (only when paused)
- [ ] Refresh page → Modal re-opens if session was active/paused

### Behavior-Specific Tests

- [ ] CUT: Sheet selection works
- [ ] CUT: BOM table displays
- [ ] STITCH: Start/Pause/Resume/Complete
- [ ] QC: Defect selection and Send Back
- [ ] EDGE: Coat round and dry status

---

## 8. Architecture Notes

### Modal State Variables

```javascript
let workModalTimerInterval = null;
let workModalStartTime = null;
let workModalPausedTime = null;
let workModalTokenId = null;
let workModalNodeId = null;
let workModalBehaviorCode = null;
let workModalIsPaused = false;
let workModalElapsedBeforePause = 0;
```

### Behavior Context Object

```javascript
const baseContext = {
    source_page: 'work_queue',
    behavior_code: workModalBehaviorCode,
    token_id: workModalTokenId,
    node_id: workModalNodeId,
    work_center_id: tokenData.work_center_id || null,
    mo_id: tokenData.mo_id || null,
    job_ticket_id: tokenData.job_ticket_id || null,
    extra: {
        serial_number: tokenData.serial_number || null,
        job_name: tokenData.job_name || null,
        ticket_code: tokenData.ticket_code || null
    }
};
```

---

## 9. Related Documentation

- `docs/dag/04-tasks/task4.md` - Behavior UI Templates
- `docs/dag/04-tasks/task5.md` - Behavior Execution Spine
- `docs/super_dag/tasks/task27.20.md` - Work Modal Implementation Plan
- `docs/archive/other/user-guides/01-manuals/WORK_QUEUE_OPERATOR_JOURNEY.md`

---

*Last Updated: 2025-12-07 18:50 ICT*

