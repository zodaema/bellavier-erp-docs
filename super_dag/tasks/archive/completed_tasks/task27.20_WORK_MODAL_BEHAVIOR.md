# Task 27.20: Work Modal & Behavior Implementation

**Date:** 2025-12-08  
**Status:** ✅ COMPLETE (All Phases)  
**Last Updated:** 2025-12-08 20:00 ICT  
**Architecture Audit:** ✅ See `00-audit/20251207_TIME_ENGINE_ARCHITECTURE_AUDIT_V2.md`  
**Codebase Audit:** ✅ Dec 8, 2025 - Enterprise Audit Score: 92/100  
**Guidelines Compliance:** ✅ Verified against SYSTEM_WIRING_GUIDE + 01-api-development.md  
**Results:** See `archive/results/task27.20_results.md`

---

## ⚠️ MANDATORY GUARDRAILS

> **ต้องอ่านและปฏิบัติตามก่อนเริ่มงาน:**

### 📘 Required Reading

| Document | Path | Purpose |
|----------|------|---------|
| **Developer Policy** | `docs/developer/01-policy/DEVELOPER_POLICY.md` | กฎหลักการพัฒนา |
| **API Development Guide** | `docs/developer/08-guides/01-api-development.md` | โครงสร้าง API มาตรฐาน |
| **System Wiring Guide** | `docs/developer/SYSTEM_WIRING_GUIDE.md` | การเชื่อมต่อระบบ |

### 🔒 Critical Rules

1. **API Structure:**
   - ✅ ใช้ `TenantApiBootstrap::init()` สำหรับ Tenant APIs
   - ✅ ใช้ `json_success()` / `json_error()` สำหรับ JSON response
   - ✅ ใส่ Rate Limiting: `RateLimiter::check($member, 120, 60, 'api_name')`

2. **Security:**
   - ✅ 100% Prepared Statements (NO string concatenation in SQL)
   - ✅ Input Validation ก่อนประมวลผล

3. **DAG System Rules:**
   - ✅ Token state changes ต้องผ่าน `TokenLifecycleService`
   - ✅ ห้าม direct SQL UPDATE บน `flow_token.status`
   - ✅ Behavior data เก็บใน `token_event.payload` (JSON)

4. **PWA/Frontend Rules:**
   - ✅ Touch targets ≥ 44px (Mobile-friendly)
   - ✅ ใช้ SweetAlert2 สำหรับ dialogs (ไม่ใช้ `alert()`, `confirm()`)

5. **i18n:**
   - ✅ Default language = **English**
   - ✅ ใช้ `t('key', 'Default')` สำหรับ JavaScript
   - ❌ ห้าม hardcode ภาษาไทยในโค้ด

### ✅ Guidelines Compliance Verification (Dec 8, 2025)

| Guideline | Section | Status |
|-----------|---------|--------|
| **SYSTEM_WIRING_GUIDE.md** | | |
| ↳ Use Hatthasilpa DAG System | Section 5 | ✅ |
| ↳ TokenLifecycleService for state changes | Section 7 | ✅ |
| ↳ token_work_session for work sessions | Section 5 | ✅ |
| ↳ No direct SQL UPDATE on DAG tables | Section 16 | ✅ |
| ↳ Work Queue = Hatthasilpa only | Section 10, 11 | ✅ |
| **01-api-development.md** | | |
| ↳ TenantApiBootstrap::init() | Step-by-Step | ✅ |
| ↳ json_success() / json_error() | Common Patterns | ✅ |
| ↳ Rate Limiting | Enterprise Features | ✅ |
| ↳ 100% Prepared Statements | Security Standards | ✅ |
| ↳ Input Validation | Best Practices | ✅ |
| ↳ i18n with t() function | i18n Requirements | ✅ |

> **Note:** Task 27.20 เป็นหลักๆ คือ Frontend JavaScript fix ไม่ใช่ Backend API creation  
> ดังนั้น Idempotency, ETag/If-Match ไม่จำเป็นต้องใช้ใน Task นี้

---

## 📋 Quick Overview

| Item | Detail |
|------|--------|
| **Remaining Work** | ✅ None - All Complete |
| **Phase 1** | ✅ **COMPLETE** - Timer + Modal + Resume Handler Fixed |
| **Phase 2** | ✅ **COMPLETE** - Duplicate buttons removed, API paths fixed, Bellavier UI |
| **Phase 3** | ✅ **COMPLETE** - QC Defect Picker + i18n Cleanup |
| **Files Modified** | `work_queue.js`, `dag_token_api.php`, `behavior_execution.js`, `behavior_ui_templates.js` |
| **Files to Create** | 0 files |

### ✅ PHASE 1-2 COMPLETED (Dec 8, 2025)

**All critical bugs fixed:**
- ✅ Resume handler timer bug fixed
- ✅ Behavior code resolution (id_work_center + node_code fallback)
- ✅ Fresh session data fetch in handleResumeToken
- ✅ Duplicate buttons removed from templates
- ✅ API paths fixed to absolute paths
- ✅ Null check in renderSheetUsageList
- ✅ Bellavier Enterprise UI for sheet selection

---

## 🏛️ TIME ARCHITECTURE RULES (BINDING)

> **⚠️ CRITICAL:** ต้องอ่านและปฏิบัติตามก่อนทำงาน

### Single Source of Truth Diagram

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

### Core Rules (BINDING)

| Rule | Description | Violation = Reject |
|------|-------------|-------------------|
| **R1** | Backend is the ONLY time calculator | ห้ามคำนวณเวลาใน JavaScript |
| **R2** | One Timer DTO format | ห้ามสร้าง DTO format ใหม่ |
| **R3** | One API for time data | ห้ามสร้าง API คำนวณเวลาใหม่ |
| **R4** | BGTimeEngine is the ONLY ticker | ห้ามสร้าง setInterval timer ใหม่ |
| **R5** | Modal = Same render as Card | Modal ต้อง render เหมือน Token Card |

> **📝 R3 Clarification:**
> - ✅ `get_token_details` action ใน `dag_token_api.php` = **OK** (reuse Time Engine + Timer DTO)
> - ❌ สร้างไฟล์ใหม่เช่น `work_modal_api.php` = **FORBIDDEN**

### 🚫 Forbidden Actions

| Action | Why Forbidden |
|--------|---------------|
| สร้าง API ใหม่ (เช่น work_modal_api.php) | ละเมิด SSOT |
| คำนวณเวลาใน JS (`new Date() - startedAt`) | Backend is ONLY calculator |
| สร้าง setInterval timer ใหม่ | BGTimeEngine is ONLY ticker |
| แก้ไข WorkSessionTimeEngine.php | 100% stable - NEVER TOUCH |
| แก้ไข BGTimeEngine.js core | 100% stable - NEVER TOUCH |

### Timer DTO Structure (Backend → Frontend)

```php
// WorkSessionTimeEngine.php returns:
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

### BGTimeEngine DOM Contract

```javascript
// Required data attributes for timer element:
// - data-token-id: Unique identifier
// - data-status: 'active'|'paused'|'completed'|'none'|'unknown'
// - data-work-seconds-sync: number (work_seconds from server)
// - data-last-server-sync: ISO8601 string (server time)

// Usage:
BGTimeEngine.registerTimerElement(spanEl);
BGTimeEngine.updateTimerFromPayload(spanEl, timerDto);
```

### Behavior-Token Type Compatibility Matrix

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

## 🎯 เป้าหมายหลัก

**เปลี่ยนพฤติกรรมปุ่ม:**
- กด "เริ่ม" / "ทำต่อ" → **เปิด Modal** (แทนที่จะแค่ refresh UI)
- Modal แสดง Behavior UI Template (CUT, STITCH, QC, etc.)
- Timer ใน Modal ใช้ `BGTimeEngine` (drift-corrected)
- Modal ปิดได้เฉพาะเมื่อ หยุดพัก หรือ จบงาน

---

## 📊 Current State (Audited Dec 8, 2025)

### ✅ Work Modal Implementation (MOSTLY COMPLETE!)

| Component | Status | Location |
|-----------|--------|----------|
| **Modal HTML** | ✅ | `views/work_queue.php` lines 543-620 |
| **openWorkModal()** | ✅ | `work_queue.js` lines 2210-2258 |
| **populateWorkModal()** | ✅ | `work_queue.js` lines 2264+ (uses BGTimeEngine) |
| **Pause button handler** | ✅ | `work_queue.js` lines 2048-2102 (uses resp.timer correctly) |
| **Resume button handler** | ❌ **BUG** | `work_queue.js` lines 2104-2136 (uses resp.token.timer - WRONG!) |
| **Complete button handler** | ✅ | `work_queue.js` lines 2138+ |
| **Start → opens Modal** | ✅ | `work_queue.js` line 2016 |
| **Resume (main UI) → opens Modal** | ✅ | `work_queue.js` line 2431 |

### ✅ API Endpoints (ALL RETURN timer DTO)

| Endpoint | Status | Timer DTO |
|----------|--------|-----------|
| `handlePauseToken` | ✅ | ✅ Returns `resp.timer` |
| `handleResumeToken` | ✅ | ✅ Returns `resp.timer` |
| `handleStartToken` | ✅ | ✅ Returns `resp.token.timer` |
| `get_work_queue` | ✅ | ✅ Includes timer per token |

### ✅ Infrastructure (COMPLETE!)

| Component | Status | Location |
|-----------|--------|----------|
| **API Endpoint** | ✅ | `source/dag_behavior_exec.php` |
| **Execution Service** | ✅ | `source/BGERP/Dag/BehaviorExecutionService.php` (~2800 lines) |
| **Time Session Service** | ✅ | `source/BGERP/Dag/TokenWorkSessionService.php` |
| **Node Behavior Engine** | ✅ | `source/BGERP/Dag/NodeBehaviorEngine.php` |
| **Template Registry** | ✅ | `assets/javascripts/dag/behavior_ui_templates.js` (14 templates) |
| **Handler Objects** | ✅ | `assets/javascripts/dag/behavior_execution.js` (11 handlers) |
| **Defect Catalog** | ✅ | Task 27.14 |
| **Material Integration** | ✅ | Task 27.21 |

### Registered Handlers (ALL COMPLETE!)

| Handler | File Line | Actions Supported |
|---------|-----------|-------------------|
| STITCH | 240 | start, pause, resume, complete |
| CUT | 309 | save_batch |
| EDGE | 1037 | multi-step rounds |
| HARDWARE_ASSEMBLY | 1102 | serial binding |
| QC_SINGLE | 1134 | pass, fail, rework |
| QC_FINAL, QC_REPAIR, QC_INITIAL | 1173-1177 | aliases to QC_SINGLE |
| SKIVE | 1183 | single-piece |
| GLUE | 1245 | single-piece |
| ASSEMBLY | 1307 | single-piece |
| PACK | 1369 | single-piece |
| EMBOSS | 1431 | single-piece |

### ⚠️ API Response Pattern Reference

| API File | Response Pattern | Bootstrap |
|----------|-----------------|-----------|
| `dag_token_api.php` | `json_success()` / `json_error()` | `TenantApiBootstrap::init()` |
| `dag_behavior_exec.php` | `TenantApiOutput::success()` / `TenantApiOutput::error()` | `TenantApiBootstrap::init()` |
| `leather_sheet_api.php` | `json_success()` / `json_error()` | `TenantApiBootstrap::init()` |
| `leather_cut_bom_api.php` | `json_success()` / `json_error()` | `TenantApiBootstrap::init()` |
| `defect_catalog_api.php` | `json_success()` / `json_error()` | `TenantApiBootstrap::init()` |

> **Note:** ทั้งหมดใช้ `TenantApiBootstrap::init()` ตามมาตรฐาน และมี Rate Limiting

### 📋 สถานะ (Updated Dec 8, 2025 19:00 ICT)

| Issue | Status | Priority | Phase |
|-------|--------|----------|-------|
| Modal ไม่เปิดเมื่อกด Start/Resume | ✅ FIXED | - | Done |
| Modal Timer แสดง 00:00:00 | ✅ FIXED | - | Done |
| Resume handler ใช้ code ผิด | ✅ **FIXED** | - | Done |
| Resume shows 00:00:00 after pause | ✅ **FIXED** | - | Done |
| Behavior code not resolved | ✅ **FIXED** | - | Done |
| ปุ่มใน Modal ซ้ำ 2 ชุด | ✅ **FIXED** | - | Done |
| API path issue (CUT behavior) | ✅ **FIXED** | - | Done |
| Null handling in renderSheetUsageList | ✅ **FIXED** | - | Done |
| Sheet selection UI (prompt→SweetAlert2) | ✅ **FIXED** | - | Done |
| QC Defect Picker ไม่ได้เชื่อม API | ⏳ Pending | P2 | **Phase 3** |
| i18n cleanup | ⏳ Pending | P3 | Phase 3 |

> **🎉 Phase 1-2 COMPLETE! Phase 3 is optional enhancement.**

---

## 📦 Components Status

### Behavior UI Templates (`behavior_ui_templates.js`)

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

### Work Modal Features (`work_queue.js`) - **Audited Status**

| Feature | Status | Location / Notes |
|---------|--------|------------------|
| Modal HTML | ✅ DONE | `views/work_queue.php` lines 543-620 |
| `openWorkModal()` | ✅ DONE | `work_queue.js` lines 2210-2258 |
| `populateWorkModal()` | ✅ DONE | `work_queue.js` lines 2264+ (uses BGTimeEngine) |
| Live Timer (BGTimeEngine) | ✅ DONE | Uses `BGTimeEngine.registerTimerElement()` |
| Token Info Display | ✅ DONE | Serial, Job Name, Status |
| Pause Button | ✅ DONE | lines 2048-2102 (uses SweetAlert2) |
| Resume Button | ✅ **FIXED** | lines 2104-2136: Fixed - uses correct timer approach |
| Complete Button | ✅ DONE | lines 2138+ |
| Close Button | ✅ DONE | Only visible when paused |
| Start → opens Modal | ✅ DONE | line 2016 |
| Resume (main UI) → opens Modal | ✅ DONE | line 2431 |
| Behavior Form Loading | ✅ DONE | `BGBehaviorUI.getTemplate()` |
| Behavior Handler Init | ✅ DONE | `handler.init($container, baseContext)` |
| Behavior Code Resolution | ✅ DONE | `enrichTokenWithBehavior()` with fallback |
| Sheet Selection UI | ✅ DONE | Bellavier Enterprise SweetAlert2 modal |

> **🎉 Summary:** 15/15 features DONE. Phase 3 is optional enhancement.

### API Endpoints

| Endpoint | Purpose | Status |
|----------|---------|--------|
| `work_modal_api.php` | DELETED | ❌ ห้ามสร้างใหม่! |
| `dag_token_api.php` | Token actions (start/pause/resume/complete) | ✅ Working |
| `dag_behavior_exec.php` | Behavior execution | ✅ Working |
| `leather_sheet_api.php` | Leather sheet usage for CUT | ✅ **Fixed paths** |
| `leather_cut_bom_api.php` | BOM for CUT | ✅ **Fixed paths** |
| `defect_catalog_api.php` | Defect codes for QC | 🔵 Not integrated (Phase 3) |

---

## ⚠️ Known Issues (Detail)

### Issue 4.1: Duplicate Buttons in Modal ✅ FIXED

**Solution Applied:** Removed duplicate buttons from behavior templates (STITCH, SKIVE, GLUE, ASSEMBLY, PACK, EMBOSS). Now uses only Modal Footer buttons.

### Issue 4.2: Resume Handler Bug ✅ FIXED

**Solution Applied:** Fixed timer handling in resume - preserves existing work_seconds and re-registers with BGTimeEngine.

### Issue 4.3: API Path Issues ✅ FIXED

**Solution Applied:** Changed all relative paths to absolute paths in `behavior_execution.js`:
- `leather_sheet_api.php` (7 occurrences)
- `leather_cut_bom_api.php` (3 occurrences)

### Issue 4.4: Null Handling in renderSheetUsageList ✅ FIXED

**Solution Applied:** Added `Array.isArray()` check before forEach.

### Issue 4.5: Sheet Selection UI ✅ ENHANCED

**Solution Applied:** Replaced native `prompt()` with Bellavier Enterprise SweetAlert2 modal:
- Visual sheet cards with stock gauge
- GRN number display
- Color-coded stock status (available/low/critical)
- Quick-select buttons for area input
- Real-time validation

### Issue 4.6: QC Defect Picker ✅ FIXED

**Solution Applied:** Added dynamic loading from `defect_catalog_api.php` in QC_SINGLE handler:
- Supports grouped response by category
- Falls back to hardcoded options on API failure
- Added validation before "Send Back" action

### Issue 4.7: i18n Cleanup ✅ FIXED

**Solution Applied:** All Thai hardcoded text replaced with English defaults:
- Templates: CUT, STITCH, EDGE, HARDWARE_ASSEMBLY, SKIVE, GLUE, ASSEMBLY, PACK, EMBOSS, QC_SINGLE
- Total: ~30 Thai strings replaced

---

## 🏗️ Architecture Reference

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

# ✅ PRE-IMPLEMENTATION CHECKLIST

> **⚠️ Agent ต้อง verify ทุกข้อก่อนเริ่มแก้ไขโค้ด:**

| # | Check | Command / Method | Expected |
|---|-------|-----------------|----------|
| 1 | อ่าน Mandatory Guardrails ด้านบน | Manual | ✅ เข้าใจแล้ว |
| 2 | ตรวจสอบ bug location | `grep -n "resp.token && resp.token.timer" work_queue.js` | พบ around line 2122 |
| 3 | ตรวจสอบ Pause handler (ที่ถูกต้อง) | `grep -n "resp.timer && typeof BGTimeEngine" work_queue.js` | พบ around line 2083 |
| 4 | ไม่มี uncommitted changes | `git status` | clean working tree |

### Quick Verification Commands:

```bash
# 1. ตรวจสอบ bug line
grep -n "resp.token && resp.token.timer" assets/javascripts/pwa_scan/work_queue.js

# 2. ตรวจสอบ correct pattern (Pause handler)
grep -n "resp.timer && typeof BGTimeEngine" assets/javascripts/pwa_scan/work_queue.js

# 3. ดู context รอบๆ bug
sed -n '2118,2135p' assets/javascripts/pwa_scan/work_queue.js
```

---

# 🚀 PHASE 1: Foundation (Timer + Modal Open)

**Priority:** 🔴 P0 - CRITICAL  
**Time:** ~5 minutes (เหลือแค่ bug fix)  
**Goal:** Modal เปิดได้ และ Timer ทำงานถูกต้อง

---

## Phase 1 Status Summary

| Task | Status | Notes |
|------|--------|-------|
| Modal HTML | ✅ DONE | `views/work_queue.php` |
| `openWorkModal()` | ✅ DONE | Uses `get_work_queue` + flatMap |
| `populateWorkModal()` | ✅ DONE | Uses BGTimeEngine correctly |
| Pause handler | ✅ DONE | Uses `resp.timer` correctly |
| **Resume handler** | ❌ **BUG** | Uses `resp.token.timer` (wrong!) |
| Complete handler | ✅ DONE | Working |
| API returns timer | ✅ DONE | Both pause/resume return timer DTO |

---

## Phase 1 Tasks

### ✅ STEP 1.1: เพิ่ม `get_token_details` action - **OPTIONAL**

> **Note:** ไม่จำเป็น - ระบบใช้ `get_work_queue` + flatMap อยู่แล้วและทำงานได้

**File:** `source/dag_token_api.php`

**1.1.1 เพิ่ม case ใน switch statement (หลัง line ~358)**

```php
case 'get_token_details':
    handleGetTokenDetails($db, $userId);
    break;
```

**1.1.2 สร้าง function `handleGetTokenDetails`**

```php
/**
 * Get single token details for Work Modal
 * Reuses WorkSessionTimeEngine for timer calculation (SSOT)
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
    // IMPORTANT: ใช้ $db (DatabaseHelper) ที่ได้จาก TenantApiBootstrap::init()
    // ห้ามเดา constructor เอง - ให้ดูจาก handlePauseToken/handleResumeToken ที่มีอยู่
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

**Checklist 1.1:**
- [ ] เพิ่ม case 'get_token_details' ใน switch
- [ ] สร้าง function handleGetTokenDetails
- [ ] ใช้ WorkSessionTimeEngine (SSOT)
- [ ] Return Timer DTO format เดียวกับ get_work_queue

---

### ❌ STEP 1.2: แก้ Resume handler ใน Modal - **BUG FIX REQUIRED**

> **🔥 นี่คือ BUG เดียวที่เหลือใน Phase 1**

**File:** `assets/javascripts/pwa_scan/work_queue.js`

**Location:** Lines 2122-2127 (inside `#btnWorkResume` click handler)

**Problem:** ใช้ `resp.token.timer` แต่ API ส่ง `resp.timer` โดยตรง

**เปลี่ยนจาก:**
```javascript
// ❌ BUG: resp.token doesn't exist in resume_token response!
if (resp.token && resp.token.timer) {
    const $timerEl = $('#workModalTimer');
    $timerEl.attr('data-status', 'active');
    $timerEl.attr('data-work-seconds-sync', resp.token.timer.work_seconds || 0);
    $timerEl.attr('data-last-server-sync', resp.token.timer.last_server_sync || new Date().toISOString());
}
```

**เป็น:**
```javascript
// ✅ FIX: Use resp.timer directly (same pattern as Pause handler line 2083)
const $timerEl = $('#workModalTimer');
if (resp.timer && typeof BGTimeEngine !== 'undefined') {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
}
```

**Why this fixes the bug:**
1. `resume_token` API returns `resp.timer` (not `resp.token.timer`)
2. `BGTimeEngine.updateTimerFromPayload()` properly registers the element for ticking
3. This is the same pattern used in Pause handler (line 2083-2084) which works correctly

**Checklist 1.2:**
- [ ] แก้ lines 2122-2127
- [ ] ใช้ resp.timer (ไม่ใช่ resp.token.timer)
- [ ] ใช้ BGTimeEngine.updateTimerFromPayload()

---

### ⚡ STEP 1.3: อัพเดท `openWorkModal` ใช้ `get_token_details` - **OPTIONAL**

> **Note:** ไม่จำเป็น - ระบบใช้ `get_work_queue` + flatMap อยู่แล้ว

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

**Checklist 1.3:**
- [ ] เปลี่ยน action จาก get_work_queue เป็น get_token_details
- [ ] ส่ง token_id parameter
- [ ] ใช้ resp.token (single token, ไม่ต้อง flatMap)

---

### ⚡ STEP 1.4: เพิ่ม fields ที่ขาดใน `get_work_queue` session - **OPTIONAL**

> **Note:** ไม่กระทบ core functionality, เพิ่มได้ภายหลัง

**File:** `source/dag_token_api.php`

**Location:** handleGetWorkQueue → session object (around line 2205)

**เพิ่ม fields:**
```php
'session' => $token['id_session'] ? [
    'id_session' => $token['id_session'],
    'status' => $token['session_status'],
    'is_mine' => $token['operator_user_id'] == $operatorId,
    'started_at' => $token['started_at'],
    'resumed_at' => $token['resumed_at'],
    'paused_at' => $token['paused_at'],           // ← เพิ่ม
    'notes' => $token['pause_reason'] ?? null,      // ← ใช้ alias จาก SQL: s.notes as pause_reason
    'total_pause_minutes' => (int)$token['total_pause_minutes'],
    'help_type' => $token['help_type'],
    'replacement_reason' => $token['replacement_reason']
] : null,
```

**Checklist 1.4:**
- [ ] เพิ่ม paused_at ใน session object
- [ ] เพิ่ม notes ใน session object
- [ ] ตรวจสอบว่า SQL query มี s.paused_at และ s.notes

---

## Phase 1 Testing

| Test | Expected Result | Current Status |
|------|-----------------|----------------|
| กด "เริ่ม" | Modal opens, timer shows correct time | ✅ Working |
| Timer ticks | Timer increases every second | ✅ Working |
| กด "หยุดพัก" | Timer stops, value retained | ✅ Working |
| กด "ทำต่อ" (Modal) | Timer continues from paused value | ❌ **BUG** (Step 1.2) |
| API resume_token | Returns timer DTO | ✅ Working |

**After Step 1.2 Fix:**

| Test | Expected Result | Pass? |
|------|-----------------|-------|
| กด "ทำต่อ" (Modal) | Timer continues from paused value | [ ] |

---

## 📋 Phase 1 Post-Implementation Verification

> **Agent ต้อง verify ทุกข้อหลังแก้ไขโค้ด:**

| # | Check | Method | Expected | Pass? |
|---|-------|--------|----------|-------|
| 1 | No syntax errors | `php -l` (if PHP) / Browser Console | No errors | [ ] |
| 2 | Bug line changed | `grep -n "resp.timer && typeof BGTimeEngine" work_queue.js` | พบ 2 matches (Pause + Resume) | [ ] |
| 3 | Old bug removed | `grep -n "resp.token && resp.token.timer" work_queue.js` | ไม่พบ | [ ] |
| 4 | Browser test: Start | กด Start → Modal opens, Timer ticks | Timer เดิน | [ ] |
| 5 | Browser test: Pause | กด หยุดพัก → Timer stops, shows paused time | Timer หยุด | [ ] |
| 6 | Browser test: Resume | กด ทำต่อ → Timer continues from paused value | Timer เดินต่อจากค่าเดิม | [ ] |
| 7 | No console errors | Browser F12 Console | No JavaScript errors | [ ] |

### Test Script (Browser Console):

```javascript
// หลังจากกด Start + Pause + Resume ให้ตรวจสอบ:
console.log('Modal Timer Status:', $('#workModalTimer').attr('data-status'));
console.log('Modal Timer Seconds:', $('#workModalTimer').attr('data-work-seconds-sync'));
```

---

# 🔧 PHASE 2: Modal Complete (Buttons + State)

**Priority:** 🟡 P1  
**Time:** 1-2 hours  
**Goal:** Modal ใช้งานได้สมบูรณ์

---

## Phase 2 Tasks

### STEP 2.1: ยุบปุ่มซ้ำใน Modal

**Problem:** Modal มีปุ่ม 2 ชุดที่ซ้ำซ้อน

**Location 1: Modal Footer** (`views/work_queue.php` lines 598-621)
```html
<button id="btnWorkPause">หยุดพัก</button>
<button id="btnWorkResume">ทำต่อ</button>
<button id="btnWorkComplete">จบงาน</button>
```

**Location 2: Behavior Template** (`behavior_ui_templates.js`)
```html
<button id="btn-stitch-start">Start</button>
<button id="btn-stitch-pause">Pause</button>
```

**Solution:**
- ใช้ปุ่มใน Modal Footer เป็นหลัก
- ลบปุ่มซ้ำออกจาก Behavior Templates (STITCH, etc.)
- หรือซ่อนปุ่มใน Template เมื่ออยู่ใน Modal

**Checklist 2.1:**
- [ ] ตรวจสอบว่าปุ่มไหนซ้ำ
- [ ] ลบหรือซ่อนปุ่มที่ซ้ำ
- [ ] ทดสอบว่าปุ่มทำงานถูกต้อง

---

### STEP 2.2: Fix API paths ใน `behavior_execution.js`

**Problem:** Relative paths ที่ fail เมื่อเรียกจาก `/work_queue`

**เปลี่ยนจาก:**
```javascript
$.getJSON('source/leather_sheet_api.php', {...})
```

**เป็น:**
```javascript
$.getJSON('/bellavier-group-erp/source/leather_sheet_api.php', {...})
// หรือใช้ base URL variable
```

**Affected Files:**
- `leather_sheet_api.php` (7 occurrences)
- `leather_cut_bom_api.php` (3 occurrences)

**Checklist 2.2:**
- [ ] แก้ path leather_sheet_api.php
- [ ] แก้ path leather_cut_bom_api.php
- [ ] ทดสอบ CUT behavior

---

### STEP 2.3: Add null check in `renderSheetUsageList`

**File:** `behavior_execution.js`

**เพิ่ม:**
```javascript
if (!Array.isArray(sheetUsages)) {
    sheetUsages = [];
}
sheetUsages.forEach(...)
```

**Checklist 2.3:**
- [ ] เพิ่ม null check
- [ ] ทดสอบ CUT behavior

---

## Phase 2 Testing

| Test | Expected Result | Pass? |
|------|-----------------|-------|
| ปุ่มใน Modal ไม่ซ้ำกัน | มีปุ่มเดียวต่อ action | [ ] |
| CUT behavior โหลด BOM | ไม่มี 404 error | [ ] |
| CUT behavior โหลด sheets | ไม่มี TypeError | [ ] |

---

# 🎨 PHASE 3: Behavior Enhancements

**Priority:** 🔵 P2  
**Time:** 2-3 hours  
**Goal:** ปรับปรุง UX และ Enhancements

---

## Phase 3 Tasks

### STEP 3.1: QC Defect Picker

**Goal:** Load defects from `defect_catalog_api.php`

**เปลี่ยนจาก hardcoded:**
```html
<option value="SCRATCH">Scratch</option>
<option value="COLOR_MISMATCH">Color Mismatch</option>
```

**เป็น dynamic load:**
```javascript
$.getJSON('/bellavier-group-erp/source/defect_catalog_api.php', {
    action: 'list'
}, function(resp) {
    if (resp.ok && resp.data) {
        resp.data.forEach(defect => {
            $select.append(`<option value="${defect.code}">${defect.name}</option>`);
        });
    }
});
```

**Checklist 3.1:**
- [ ] แก้ QC_SINGLE handler
- [ ] Load defects from API
- [ ] ทดสอบ QC behavior

---

### STEP 3.2: i18n Cleanup

**Goal:** Migrate hardcoded Thai text to `t()`

**Files to check:**
- `behavior_ui_templates.js`
- `behavior_execution.js`
- `work_queue.js`

**Pattern:**
```javascript
// ❌ ผิด
$('#status').text('กำลังทำงาน');

// ✅ ถูก
$('#status').text(t('behavior.status.working', 'Working'));
```

**Checklist 3.2:**
- [ ] ค้นหา hardcoded Thai text
- [ ] แปลงเป็น t() function
- [ ] เพิ่ม keys ใน lang/th.php และ lang/en.php

---

### STEP 3.3: Mobile-friendly UI

**Goal:** Touch targets ≥ 44px

**Checklist 3.3:**
- [ ] ตรวจสอบ button sizes
- [ ] ตรวจสอบ input sizes
- [ ] ทดสอบบน mobile device

---

## Phase 3 Testing

| Test | Expected Result | Pass? |
|------|-----------------|-------|
| QC defects load from API | Dropdown shows defects | [ ] |
| No hardcoded Thai | All text through t() | [ ] |
| Mobile touch targets | Buttons ≥ 44px | [ ] |

---

# 📁 Files Reference

## ✅ Files to Modify

| File | Phase | Changes |
|------|-------|---------|
| `source/dag_token_api.php` | 1 | +1 case, +1 function (~80 lines), +2 fields |
| `assets/javascripts/pwa_scan/work_queue.js` | 1, 2 | ~20 lines |
| `assets/javascripts/dag/behavior_execution.js` | 2, 3 | Fix paths, null check |
| `assets/javascripts/dag/behavior_ui_templates.js` | 2, 3 | Remove duplicate buttons, i18n |

## ❌ Files NOT to Create

| File | Reason |
|------|--------|
| `work_modal_api.php` | ละเมิด SSOT (R3) |
| New timer JS | ละเมิด SSOT (R4) |

## 🔒 Files NOT to Modify

| File | Reason |
|------|--------|
| `WorkSessionTimeEngine.php` | 100% stable |
| `work_queue_timer.js` (BGTimeEngine core) | 100% stable |

---

# 📚 Related Documents

| Document | Purpose |
|----------|---------|
| `00-audit/20251207_TIME_ENGINE_ARCHITECTURE_AUDIT_V2.md` | Architecture rules |
| `docs/developer/08-guides/01-api-development.md` | API standards |
| `docs/developer/SYSTEM_WIRING_GUIDE.md` | Integration rules |
| Task 27.14 | Defect Catalog |
| Task 27.21 | Material Integration |

---

# ✅ Completion Criteria

## Phase 1 Complete When:
- [ ] Modal เปิดเมื่อกด Start/Resume
- [ ] Timer แสดงค่าถูกต้อง (ไม่ใช่ 00:00:00)
- [ ] Timer เดินเมื่อ active
- [ ] Timer หยุดเมื่อ paused
- [ ] Resume ทำให้ timer เดินต่อได้

## Phase 2 Complete When:
- [ ] ปุ่มไม่ซ้ำซ้อน
- [ ] CUT behavior โหลดได้ไม่ error
- [ ] No 404 errors on API calls

## Phase 3 Complete When:
- [ ] QC defects load from API
- [ ] No hardcoded Thai text
- [ ] Mobile-friendly

---

*Last Updated: 2025-12-08 04:00 ICT*


