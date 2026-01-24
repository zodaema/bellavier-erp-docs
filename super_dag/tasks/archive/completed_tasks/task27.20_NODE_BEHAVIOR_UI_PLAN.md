# Task 27.20: Node Behavior UI Enhancement Plan

> **Created:** December 6, 2025  
> **Updated:** December 8, 2025 (RESTART - work_modal_api.php deleted)  
> **Status:** 🔴 **RESTART** - ต้องเริ่มใหม่ตั้งแต่ต้น  
> **Priority:** HIGH (Timer bug identified)  
> **Estimated Duration:** 30 min (Bug fix) + 2-4 hours (Enhancements)  
> **Prerequisites:** ✅ All complete (27.21, 27.14)  
> **Phase:** 3 (Execution Layer - Behaviors)  
> **Architecture Audit:** See `docs/super_dag/00-audit/20251207_TIME_ENGINE_ARCHITECTURE_AUDIT_V2.md`

---

## 🏛️ TIME ARCHITECTURE RULES (BINDING)

> **⚠️ CRITICAL:** อ่านก่อนทำงานใดๆ เกี่ยวกับ Timer

### Single Source of Truth Principle

| Rule | Description | Violation = Reject |
|------|-------------|-------------------|
| **R1** | Backend is the ONLY time calculator | ห้ามคำนวณเวลาใน JavaScript |
| **R2** | One Timer DTO format | ห้ามสร้าง DTO format ใหม่ |
| **R3** | One API for time data | ห้ามสร้าง API คำนวณเวลาใหม่ |
| **R4** | BGTimeEngine is the ONLY ticker | ห้ามสร้าง setInterval timer ใหม่ |
| **R5** | Modal = Same render as Card | Modal ต้อง render เหมือน Token Card |

### Forbidden Actions

- ❌ สร้าง API คำนวณเวลาใหม่ (เช่น work_modal_api.php)
- ❌ คำนวณเวลาใน JavaScript (`new Date() - startedAt`)
- ❌ สร้าง setInterval timer ใหม่
- ❌ แก้ไข WorkSessionTimeEngine.php / BGTimeEngine.js

### Required Pattern for Timer Updates

```javascript
// ✅ ALWAYS use this pattern after pause/resume API calls:
const $timerEl = $('#workModalTimer');
if (resp.timer && typeof BGTimeEngine !== 'undefined') {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
}
```

---

## ⚠️ MANDATORY GUARDRAILS

> **ต้องอ่านและปฏิบัติตามเอกสารต่อไปนี้ก่อนเริ่มงาน:**

### 📘 Required Reading

| Document | Path | Purpose |
|----------|------|---------|
| **Developer Policy** | `docs/developer/01-policy/DEVELOPER_POLICY.md` | กฎหลักการพัฒนา, Forbidden Changes |
| **API Development Guide** | `docs/developer/08-guides/01-api-development.md` | โครงสร้าง API มาตรฐาน |
| **System Wiring Guide** | `docs/developer/SYSTEM_WIRING_GUIDE.md` | การเชื่อมต่อระบบ, DO NOT TOUCH Zones |

### 🔒 Critical Rules (MUST FOLLOW)

1. **API Structure:**
   - ✅ ใช้ `TenantApiBootstrap::init()` สำหรับ Tenant APIs
   - ✅ ใช้ `json_success()` / `json_error()` สำหรับ JSON response
   - ✅ ใส่ Rate Limiting: `RateLimiter::check($member, 120, 60, 'behavior_api')`
   - ✅ ใส่ Idempotency สำหรับ state-changing operations

2. **Security:**
   - ✅ 100% Prepared Statements (NO string concatenation in SQL)
   - ✅ Input Validation ก่อนประมวลผล
   - ✅ ห้าม log sensitive data

3. **JSON Format (Standard):**
   ```php
   // Success
   json_success(['data' => $result]);
   // Returns: {"ok": true, "data": {...}}
   
   // Error  
   json_error('Error message', 400, ['app_code' => 'BHV_400_XXX']);
   // Returns: {"ok": false, "error": "...", "app_code": "..."}
   ```

4. **Forbidden Changes:**
   - ❌ ห้ามแก้ไข Bootstrap signature
   - ❌ ห้ามแก้ไข Permission logic ใน `BGERP\Security\PermissionHelper`
   - ❌ ห้ามแก้ไข JSON format โดยไม่มี Task approval

5. **DAG System Rules:**
   - ✅ ใช้ Canonical Event System (`token_event`) สำหรับทุก state change
   - ✅ Token state changes ต้องผ่าน `TokenLifecycleService`
   - ✅ ห้าม direct SQL UPDATE บน `flow_token.status`
   - ✅ Behavior data เก็บใน `token_event.payload` (JSON)

6. **PWA/Frontend Rules:**
   - ✅ Touch targets ≥ 44px (Mobile-friendly)
   - ✅ ใช้ existing notification helpers (`notifySuccess`, `notifyError`)
   - ✅ ใช้ SweetAlert2 สำหรับ dialogs (ไม่ใช้ `alert()`, `confirm()`)

7. **i18n (Internationalization):**
   - ✅ Default language ในโค้ด = **English**
   - ✅ ใช้ `translate('key', 'Default English Text')` สำหรับ PHP
   - ✅ ใช้ `t('key', 'Default English Text')` สำหรับ JavaScript
   - ✅ เพิ่ม translation keys ใน `lang/th.php` และ `lang/en.php`
   - ❌ ห้าม hardcode ภาษาไทยในโค้ดโดยตรง!

   **ตัวอย่าง:**
   ```javascript
   // JS - ถูก ✅
   $('#stitch-start-time').text(t('behavior.start_time', 'Start Time') + ': ' + time);
   
   // JS - ผิด ❌
   $('#stitch-start-time').text('เวลาเริ่มงาน: ' + time);
   ```

---

## 📌 Executive Summary

เป็นการ **พัฒนาระบบ UI แบบ Dynamic** สำหรับ PWA Work Queue ที่จะแสดงผล UI แตกต่างกันตาม `behavior_code` ของ Node แต่ละตัว เพื่อให้ Operator สามารถบันทึกข้อมูลที่เฉพาะเจาะจงกับงานแต่ละประเภท

**ตัวอย่าง:**
- Node `CUT` → แสดง Form บันทึก qty_produced, qty_scrapped, leather_sheets ที่ใช้
- Node `STITCH` → แสดง Time Control Panel (Start/Pause/Resume/Complete)
- Node `HARDWARE_ASSEMBLY` → แสดง Input สำหรับ Serial Number ของ Hardware
- Node `QC_*` → แสดง Defect Picker และ Pass/Fail Buttons

---

## 🔍 Current State Analysis (AUDITED Dec 7, 2025)

### ✅ สิ่งที่มีพร้อมแล้ว (COMPLETE!)

| Component | Status | Location |
|-----------|--------|----------|
| **API Endpoint** | ✅ **DONE** | `source/dag_behavior_exec.php` |
| **Execution Service** | ✅ **DONE** | `source/BGERP/Dag/BehaviorExecutionService.php` (~2800 lines) |
| **Time Session Service** | ✅ **DONE** | `source/BGERP/Dag/TokenWorkSessionService.php` |
| **Node Behavior Engine** | ✅ **DONE** | `source/BGERP/Dag/NodeBehaviorEngine.php` |
| **Template Registry** | ✅ **DONE** | `assets/javascripts/dag/behavior_ui_templates.js` (14 templates) |
| **Handler Objects** | ✅ **DONE** | `assets/javascripts/dag/behavior_execution.js` (ALL 11 handlers) |
| **PWA Scan Integration** | ✅ **DONE** | `assets/javascripts/pwa_scan/pwa_scan.js` |
| **Behavior Badge Display** | ✅ **DONE** | Work Queue Kanban columns |
| **Defect Catalog** | ✅ **DONE** | Task 27.14 |
| **Material Integration** | ✅ **DONE** | Task 27.21 |

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

### ⚠️ API Pattern Note

```php
// dag_behavior_exec.php uses TenantApiOutput (NOT json_success):
TenantApiOutput::error('message', 400, ['app_code' => '...']);
TenantApiOutput::success(['data' => $result]);
```

### ❌ สิ่งที่ยังต้องปรับปรุง (Enhancement)

| Component | Status | Description |
|-----------|--------|-------------|
| QC Defect Picker | ⏳ Enhancement | Load defects from `defect_catalog_api.php` in QC panel |
| Work Queue Modal | ⏳ Enhancement | Better modal/drawer integration |
| i18n Compliance | ⚠️ Check | Some hardcoded Thai text may need migration to `t()` |

---

## 🎯 Objectives (Updated after Audit)

> **Note:** Most objectives are already COMPLETE. This task is now focused on **enhancements**.

| Objective | Status | Notes |
|-----------|--------|-------|
| Handler Implementation | ✅ DONE | All 11 handlers in `behavior_execution.js` |
| API Integration | ✅ DONE | `dag_behavior_exec.php` + `BehaviorExecutionService` |
| Data Validation | ✅ DONE | Server-side in BehaviorExecutionService |
| Time Tracking | ✅ DONE | `TokenWorkSessionService` |
| Material Linking | ✅ DONE | Task 27.21 - consumption on node complete |
| **QC Defect Picker** | ⏳ **ENHANCE** | Load from `defect_catalog_api.php` |
| **i18n Cleanup** | ⏳ **ENHANCE** | Migrate hardcoded Thai to `t()` |
| **Work Queue Modal UX** | ⏳ **ENHANCE** | Better mobile experience |

---

## 📂 Technical Architecture

### 1. Handler Interface

```javascript
// Handler Object Structure
const BehaviorHandler = {
    /**
     * Initialize handler when panel is rendered
     * @param {jQuery} $panel - Panel container
     * @param {Object} context - Token/Node context
     */
    init: function($panel, context) {
        // Setup event listeners
        // Load initial data
        // Initialize state
    },
    
    /**
     * Validate form data before submit
     * @returns {Object} { valid: boolean, errors: string[] }
     */
    validate: function() {
        // Check required fields
        // Validate ranges
        // Return validation result
    },
    
    /**
     * Submit data to API
     * @param {Object} data - Form data
     * @param {Object} context - Token/Node context
     * @returns {Promise} API response
     */
    submit: async function(data, context) {
        // Call API
        // Handle response
        // Return result
    },
    
    /**
     * Cleanup when panel is removed
     */
    destroy: function() {
        // Remove event listeners
        // Clear timers
    }
};
```

### 2. Behavior-Specific Data Tables

เราจะใช้ตาราง `token_event.payload` (JSON) เพื่อเก็บข้อมูล behavior-specific แทนที่จะสร้างตารางใหม่

```json
// Example: CUT event payload
{
    "behavior_code": "CUT",
    "qty_produced": 10,
    "qty_scrapped": 2,
    "scrap_reason": "Material defect",
    "leather_sheets": ["SHEET-001", "SHEET-002"],
    "bom_results": [
        {"component": "BODY", "expected": 5, "actual": 5},
        {"component": "FLAP", "expected": 5, "actual": 4}
    ]
}

// Example: STITCH event payload
{
    "behavior_code": "STITCH",
    "start_time": "2025-12-06T10:00:00",
    "end_time": "2025-12-06T10:45:00",
    "pause_duration_seconds": 300,
    "pause_reason": "break",
    "notes": "Optional notes"
}

// Example: HARDWARE_ASSEMBLY event payload
{
    "behavior_code": "HARDWARE_ASSEMBLY",
    "hardware_serial": "HW-2025-12345",
    "lot_verified": true,
    "mismatch_reported": false
}

// Example: QC_* event payload
{
    "behavior_code": "QC_SINGLE",
    "result": "fail",
    "defect_code": "SCRATCH",
    "defect_id": 15,
    "defect_reason": "Surface scratch on body",
    "rework_target_node": 5
}
```

---

## 🗂️ Implementation Plan (Revised - Enhancement Only)

> **Status:** Core implementation COMPLETE. This plan covers enhancements only.

### ✅ Already Complete (No action needed)

| Part | Files | Status |
|------|-------|--------|
| Handler Implementation | `behavior_execution.js` | ✅ All 11 handlers done |
| API Endpoint | `dag_behavior_exec.php` | ✅ Complete |
| Execution Service | `BehaviorExecutionService.php` | ✅ ~2800 lines |
| Time Tracking | `TokenWorkSessionService.php` | ✅ Complete |
| Templates | `behavior_ui_templates.js` | ✅ 14 templates |

### Handler Reference (Already Implemented)

| Category | Behaviors | Handler Location |
|----------|-----------|------------------|
| Time-Tracked | STITCH, SKIVE, GLUE, ASSEMBLY, PACK, EMBOSS | Lines 240, 1183-1431 |
| Batch | CUT | Line 309 |
| Multi-step | EDGE | Line 1037 |
| Serial | HARDWARE_ASSEMBLY | Line 1102 |
| QC | QC_SINGLE, QC_FINAL, QC_REPAIR, QC_INITIAL | Lines 1134-1177 |

---

### Part 2: API (✅ Already Complete)

#### Existing API: `dag_behavior_exec.php`

```php
// ✅ ALREADY EXISTS - DO NOT CREATE NEW FILE!
// Uses TenantApiBootstrap pattern (not json_success/json_error)

use BGERP\Bootstrap\TenantApiBootstrap;
use BGERP\Http\TenantApiOutput;
use BGERP\Dag\BehaviorExecutionService;

// Auth + Rate Limiting
TenantApiOutput::startOutputBuffer();
RateLimiter::check($member, 60, 60, 'dag_behavior_exec');
[$org, $db] = TenantApiBootstrap::init();

// Execute
$executionService = new BehaviorExecutionService($tenantDb, $org, $userId);
$result = $executionService->execute($behaviorCode, $sourcePage, $action, $context, $formData);

// Response
TenantApiOutput::success($result);
```

#### Frontend Integration: `behavior_execution.js`

```javascript
// ✅ ALREADY EXISTS - BGBehaviorExec global object
window.BGBehaviorExec.send(payload, onSuccess, onError);
```

#### 2.2 API Endpoint Details

| Endpoint | Method | Purpose | Request | Response |
|----------|--------|---------|---------|----------|
| `submit_behavior_data` | POST | บันทึกข้อมูล Behavior | `{ token_id, behavior_code, data }` | `{ ok, message }` |
| `get_behavior_context` | GET | โหลด Context สำหรับ Panel | `{ token_id }` | `{ token, node, product, bom }` |
| `get_defect_options` | GET | โหลด Defect dropdown | `{ category?, component? }` | `{ defects: [...] }` |
| `validate_hardware_serial` | GET | ตรวจสอบ Serial | `{ serial }` | `{ valid, info }` |
| `get_leather_sheets` | GET | โหลด Leather Sheets | `{ material_id }` | `{ sheets: [...] }` |

---

### Part 3: Data Validation (2-3 hours)

#### 3.1 Client-side Validation

```javascript
// Validation rules per behavior
const BEHAVIOR_VALIDATION = {
    CUT: {
        qty_produced: { required: true, type: 'number', min: 0 },
        qty_scrapped: { required: false, type: 'number', min: 0 }
    },
    STITCH: {
        // No specific fields, just time tracking
    },
    HARDWARE_ASSEMBLY: {
        hardware_serial: { required: true, pattern: /^HW-\d{4}-\d+$/ }
    },
    QC_SINGLE: {
        result: { required: true, enum: ['pass', 'fail'] },
        defect_code: { requiredIf: 'result === "fail"' }
    }
};
```

#### 3.2 Server-side Validation

```php
// source/BGERP/Service/BehaviorValidationService.php
class BehaviorValidationService {
    public function validate(string $behaviorCode, array $data): array;
    public function validateCUT(array $data): array;
    public function validateQC(array $data): array;
    public function validateHardwareSerial(string $serial): array;
}
```

---

### Part 4: QC Defect Integration (2-3 hours)

#### 4.1 Defect Picker Component

```javascript
// Features:
// 1. Load defects from defect_catalog
// 2. Group by category
// 3. Show severity badge
// 4. Filter by component (if applicable)
// 5. Auto-suggest rework node based on defect
```

#### 4.2 Rework Integration

เชื่อมกับ Task 27.15 (QC Rework V2):
- โหลด Rework candidates จาก `DAGRoutingService`
- Auto-suggest based on `defect.rework_recommendations`
- Supervisor approval workflow

---

### Part 5: Work Queue Integration (2-3 hours)

#### 5.1 Panel Rendering in Work Queue

```javascript
// work_queue.js
function renderTokenCard(token) {
    // ...existing code...
    
    // Add behavior panel trigger
    const behaviorBtn = `<button class="btn btn-sm btn-primary btn-behavior-panel" 
                          data-token-id="${token.id_token}"
                          data-behavior="${token.behavior_code}">
                          <i class="ri-tools-line"></i> เปิดแผง
                         </button>`;
}

// Handle behavior panel open
$(document).on('click', '.btn-behavior-panel', function() {
    const tokenId = $(this).data('token-id');
    const behaviorCode = $(this).data('behavior');
    openBehaviorModal(tokenId, behaviorCode);
});
```

#### 5.2 Modal/Drawer Pattern

- ใช้ Modal หรือ Slide-in Drawer สำหรับ Behavior Panel
- Mobile-friendly design (touch targets ≥ 44px)
- Fullscreen mode on mobile

---

## 📁 Files Reference

### ✅ Existing Files (Already Complete)

| File | Purpose | Status |
|------|---------|--------|
| `source/dag_behavior_exec.php` | API endpoint | ✅ DONE |
| `source/BGERP/Dag/BehaviorExecutionService.php` | Core service | ✅ DONE |
| `source/BGERP/Dag/TokenWorkSessionService.php` | Time tracking | ✅ DONE |
| `source/BGERP/Dag/NodeBehaviorEngine.php` | Behavior engine | ✅ DONE |
| `assets/javascripts/dag/behavior_ui_templates.js` | UI templates | ✅ DONE |
| `assets/javascripts/dag/behavior_execution.js` | Handlers + API | ✅ DONE |
| `assets/javascripts/pwa_scan/pwa_scan.js` | PWA integration | ✅ DONE |

### ⏳ Files to Enhance (Optional)

| File | Enhancement | Priority |
|------|-------------|----------|
| `behavior_execution.js` | i18n migration (Thai → `t()`) | MEDIUM |
| QC handlers | Load defects from `defect_catalog_api.php` | HIGH |
| Work Queue modal | Better mobile drawer | LOW |

---

## 🔄 Implementation Sequence (Revised)

```
✅ ALREADY COMPLETE:
├── Handler Implementation → behavior_execution.js
├── API Endpoints → dag_behavior_exec.php
├── Execution Service → BehaviorExecutionService.php
├── Time Tracking → TokenWorkSessionService.php
└── Templates → behavior_ui_templates.js

⏳ ENHANCEMENTS ONLY (2-4 hours):
├── Enhancement 1: QC Defect Picker (1-2 hours)
│   └── Call defect_catalog_api.php in QC handlers
├── Enhancement 2: i18n Cleanup (1 hour)
│   └── Migrate hardcoded Thai text to t()
└── Enhancement 3: Testing (1 hour)
    └── Manual flow verification
```

---

## 🧪 Testing Plan

### Unit Tests

```php
// tests/Unit/BehaviorValidationServiceTest.php
public function testValidateCUT(): void;
public function testValidateQC(): void;
public function testValidateHardwareSerial(): void;
```

### Integration Tests

```php
// tests/Integration/BehaviorApiTest.php
public function testSubmitBehaviorData(): void;
public function testGetDefectOptions(): void;
```

### Manual Testing

| Scenario | Expected Result |
|----------|-----------------|
| Open CUT panel, enter qty, submit | Data saved, token moves to next node |
| Open STITCH panel, start/pause/resume/complete | Time tracked correctly |
| Open QC panel, select defect, submit fail | Token routed to rework node |
| Open HARDWARE_ASSEMBLY, enter invalid serial | Validation error shown |

---

## 📊 Success Metrics

| Metric | Target |
|--------|--------|
| All 11 behaviors have working handlers | 100% |
| API response time | < 200ms |
| Validation coverage | 100% |
| Mobile-friendly | Touch targets ≥ 44px |
| Defect picker loads from catalog | ✅ |
| Time tracking accurate to 1 second | ✅ |

---

## ⚠️ Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Performance on large defect catalogs | Medium | Implement pagination/search |
| Timer drift on mobile | Medium | Use server time sync |
| Offline behavior data | High | Queue for sync when online |
| Hardware serial conflicts | Low | Real-time validation check |

---

## 📝 Notes

1. **Mobile-first design** - Prioritize touch experience
2. **Offline support** - Queue data when offline (future enhancement)
3. **Reuse existing patterns** - Follow existing code style
4. **i18n compliance** - Default English in code, use `t()` / `translate()` for all text

---

## 🔗 Related Documents

- [MASTER_IMPLEMENTATION_ROADMAP.md](./MASTER_IMPLEMENTATION_ROADMAP.md)
- [task27.15_QC_REWORK_V2_PLAN.md](./task27.15_QC_REWORK_V2_PLAN.md) - QC Rework logic
- [task27.14_DEFECT_CATALOG_PLAN.md](./task27.14_DEFECT_CATALOG_PLAN.md) - Defect data source
- [task27.21_MATERIAL_INTEGRATION_PLAN.md](./task27.21_MATERIAL_INTEGRATION_PLAN.md) - Material consumption
- [01-api-development.md](../../developer/08-guides/01-api-development.md) - API standards
- [SYSTEM_WIRING_GUIDE.md](../../developer/SYSTEM_WIRING_GUIDE.md) - Integration rules

---

## ✅ Completion Criteria (Revised after Audit)

### ✅ Already Complete

- [x] All 11 behavior handlers implemented (`behavior_execution.js`)
- [x] API endpoint complete (`dag_behavior_exec.php`)
- [x] Server-side validation (`BehaviorExecutionService.php`)
- [x] Time tracking works (`TokenWorkSessionService.php`)
- [x] Material consumption on node complete (Task 27.21)

### ⚠️ Critical UX Issue (MUST FIX)

**ปัญหา:** เมื่อกด "เริ่ม" ระบบเรียก API แล้วก็ refresh หน้า → ไม่มี Modal ล็อคให้ทำงานจนเสร็จ

**ควรเป็น:**
```
กด "เริ่ม" → เปิด Work Modal (backdrop: static, ปิดไม่ได้)
           → Timer เริ่มนับแบบ realtime
           → Behavior Form ตาม node type
           → ต้องกด "หยุดพัก" หรือ "จบงาน" ถึงจะปิด Modal ได้
```

### 🔥 IDENTIFIED BUG: Resume Handler (Architect Audit V2)

**Location:** `assets/javascripts/pwa_scan/work_queue.js` lines 2122-2127

**Problem:** Resume handler uses wrong field and doesn't use BGTimeEngine

```javascript
// ❌ CURRENT (WRONG):
if (resp.token && resp.token.timer) { // resp.token.timer is UNDEFINED!
    const $timerEl = $('#workModalTimer');
    $timerEl.attr('data-status', 'active');
    ...
}

// ✅ FIX (Copy from Pause handler):
const $timerEl = $('#workModalTimer');
if (resp.timer && typeof BGTimeEngine !== 'undefined') {
    BGTimeEngine.updateTimerFromPayload($timerEl[0], resp.timer);
}
```

**Root Cause:** 
- API returns `resp.timer` not `resp.token.timer`
- Manual `attr()` doesn't re-register with BGTimeEngine
- Timer loses sync with drift-correction loop

### ⏳ Implementation Tasks

**🔴 P0 - Immediate (30 min)**
- [ ] **Fix Resume handler** - Use `resp.timer` + `BGTimeEngine.updateTimerFromPayload()`

**❌ NEEDS RE-IMPLEMENTATION**
- [ ] **Work Modal** - Bootstrap Modal ที่ปิดไม่ได้ (`backdrop: 'static'`)
- [ ] **Live Timer** - ใช้ BGTimeEngine (NOT setInterval!)
- [ ] **Behavior Form** - โหลด template ตาม behavior_code
- [ ] **Action Buttons** - หยุดพัก / ทำต่อ / จบงาน
- [ ] **Pause handler** - Uses BGTimeEngine.updateTimerFromPayload() correctly

**🟡 P1 - Short-term (2-3 hours)**
- [ ] ยุบปุ่มซ้ำใน Modal (Modal Footer vs Behavior Template)
- [ ] Fix API paths in `behavior_execution.js`
- [ ] Add null check in `renderSheetUsageList()`

**🔵 P2 - Future**
- [ ] QC defect picker - เชื่อม `defect_catalog_api.php`
- [ ] i18n cleanup
- [ ] Mobile-friendly UI
- [ ] Unit tests pass
- [ ] Documentation updated

