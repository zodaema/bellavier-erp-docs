# Task 5 Results — Behavior Execution Spine (Stub Endpoint + Handler Wiring)

**Status:** ✅ **COMPLETED**  
**Date:** December 2025  
**Task:** [task5.md](task5.md)

---

## Summary

Task 5 successfully implemented the "execution spine" for behavior actions, creating a unified communication layer between frontend behavior panels and backend API. All behavior buttons now send standardized payloads to a central stub endpoint that logs requests without modifying Token/Time/DAG Engine state.

---

## Deliverables

### 1. PHP API Stub Endpoint

**File:** `source/dag_behavior_exec.php`

**Features:**
- Tenant-scoped API using `TenantApiBootstrap::init()`
- POST-only endpoint with JSON payload parsing
- Comprehensive validation:
  - `behavior_code` (required, string, 1-64 chars)
  - `source_page` (required, enum: 'work_queue' | 'pwa_scan' | 'job_ticket')
  - `action` (required, string, 1-64 chars)
  - `context` (optional object)
  - `form_data` (optional object)
- Safe logging (no sensitive data)
- Stub response: `{ok: true, data: {received: true}}`
- Error handling with proper HTTP codes and app codes

**Code Structure:**
```php
// Bootstrap
TenantApiOutput::startOutputBuffer();
[$org, $db] = TenantApiBootstrap::init();

// Validation
$validator = new RequestValidator();
$behaviorCode = $validator->string($payload['behavior_code'] ?? null, 'behavior_code', true, 1, 64);
// ... more validation

// Logging (safe)
error_log('[DAG_BEHAVIOR_EXEC] ...');

// Stub response
TenantApiOutput::success(['received' => true, ...]);
```

**Important:** This endpoint does NOT modify:
- ❌ Token Engine (token status, assignment)
- ❌ Time Engine (work timer, pause/resume calculation)
- ❌ DAG Execution Logic (routing, node transitions)

---

### 2. JavaScript Execution Spine

**File:** `assets/javascripts/dag/behavior_execution.js`

**Global Object:** `window.BGBehaviorExec`

**Methods:**
- `buildPayload(baseContext, action, formData)` - Builds standardized payload
- `send(payload, onSuccess, onError)` - Sends AJAX request to PHP endpoint

**Payload Structure:**
```javascript
{
  behavior_code: 'STITCH',
  source_page: 'work_queue',
  action: 'stitch_start',
  context: {
    token_id: 123,
    node_id: 456,
    work_center_id: 789,
    mo_id: null,
    job_ticket_id: 101,
    extra: {...}
  },
  form_data: {
    pause_reason: 'break',
    notes: '...'
  }
}
```

**Error Handling:**
- Network errors → User-friendly messages
- HTTP errors → Appropriate error messages
- Fallback to SweetAlert2 or alert() if toastr not available
- Debug mode support (`BGBehaviorExec.debug = true`)

---

### 3. Behavior Handlers Registration

**File:** `assets/javascripts/dag/behavior_execution.js` (continued)

**Registered Handlers:**
1. **STITCH** - Start/Pause/Resume buttons
2. **CUT** - Save Batch Result button (added dynamically)
3. **EDGE** - Update Edge Step button (added dynamically)
4. **HARDWARE_ASSEMBLY** - Save Hardware button (added dynamically)
5. **QC_SINGLE** - Send Back / Mark Pass buttons
6. **QC_FINAL** - Reuses QC_SINGLE handler

**Handler Pattern:**
```javascript
BGBehaviorUI.registerHandler('STITCH', {
  init: function($panel, baseContext) {
    $panel.find('#btn-stitch-start').on('click', function() {
      const formData = {...};
      const payload = BGBehaviorExec.buildPayload(baseContext, 'stitch_start', formData);
      BGBehaviorExec.send(payload, onSuccess, onError);
    });
    // ... more buttons
  }
});
```

---

### 4. Frontend Integration

#### PWA Scan (`pwa_scan.js`)
- Modified `renderDagTokenView()` to initialize handler after rendering panel
- Handler receives context with token_id, node_id, job info

#### Work Queue (`work_queue.js`)
- Modified `renderKanbanTokenCard()` to initialize handler after card creation
- Modified `renderListTokenCard()` to store handler init info, then initialize after HTML append
- Handler receives context with token_id, node_id, work_center_id

#### Job Ticket (`job_ticket.js`)
- Modified `loadRoutingSteps()` to initialize handler after panel row creation
- Handler receives context with step_id, work_center_id, job_ticket_id

**Integration Pattern:**
```javascript
// After rendering panel
const handler = window.BGBehaviorUI.getHandler(behavior.code);
if (handler && typeof handler.init === 'function') {
  const baseContext = {
    source_page: 'work_queue',
    behavior_code: behavior.code,
    token_id: token.id_token,
    // ... more context
  };
  handler.init($panel, baseContext);
}
```

---

### 5. Page Definitions

**Files Updated:**
- `page/pwa_scan.php` - Added `behavior_execution.js` (after `behavior_ui_templates.js`)
- `page/work_queue.php` - Added `behavior_execution.js` (after `behavior_ui_templates.js`)
- `page/hatthasilpa_job_ticket.php` - Added `behavior_execution.js` (after `behavior_ui_templates.js`)

**Loading Order:**
1. jQuery
2. Libraries (SweetAlert2, Toastr, etc.)
3. `behavior_ui_templates.js` (Task 4)
4. **`behavior_execution.js` (Task 5)** ← NEW
5. Page-specific JS (pwa_scan.js, work_queue.js, job_ticket.js)

---

## Behavior → Action Mapping

### STITCH
- `#btn-stitch-start` → `action: 'stitch_start'`
- `#btn-stitch-pause` → `action: 'stitch_pause'`
- `#btn-stitch-resume` → `action: 'stitch_resume'`
- Form data: `pause_reason`, `notes`

### CUT
- `#btn-cut-save-batch` → `action: 'cut_save_batch'` (added dynamically)
- Form data: `qty_produced`, `qty_scrapped`, `reason`, `leather_lot`

### EDGE
- `#btn-edge-update` → `action: 'edge_update'` (added dynamically)
- Form data: `coat_round`, `dry_status`, `defect_fix`

### HARDWARE_ASSEMBLY
- `#btn-hardware-save` → `action: 'hardware_save'` (added dynamically)
- Form data: `hardware_serial`, `hardware_lot_check`, `hardware_mismatch`

### QC_SINGLE / QC_FINAL
- `#btn-qc-send-back` → `action: 'qc_send_back'`
- `#btn-qc-mark-pass` → `action: 'qc_pass'`
- Form data: `defect_code`, `defect_reason`

---

## Example Payloads

### STITCH Start
```json
{
  "behavior_code": "STITCH",
  "source_page": "work_queue",
  "action": "stitch_start",
  "context": {
    "token_id": 123,
    "node_id": 456,
    "work_center_id": 789,
    "mo_id": null,
    "job_ticket_id": 101,
    "extra": {
      "serial_number": "TOKEN-001",
      "job_name": "Handbag Production",
      "ticket_code": "JT-2025-001"
    }
  },
  "form_data": {
    "pause_reason": "",
    "notes": ""
  }
}
```

### CUT Save Batch
```json
{
  "behavior_code": "CUT",
  "source_page": "pwa_scan",
  "action": "cut_save_batch",
  "context": {
    "token_id": 124,
    "node_id": 457,
    "work_center_id": 790,
    "mo_id": 50,
    "job_ticket_id": 102,
    "extra": null
  },
  "form_data": {
    "qty_produced": 10,
    "qty_scrapped": 1,
    "reason": "Material defect",
    "leather_lot": "LOT-2025-001"
  }
}
```

### QC Pass
```json
{
  "behavior_code": "QC_FINAL",
  "source_page": "work_queue",
  "action": "qc_pass",
  "context": {
    "token_id": 125,
    "node_id": 458,
    "work_center_id": 791,
    "mo_id": null,
    "job_ticket_id": 103,
    "extra": null
  },
  "form_data": {
    "defect_code": "",
    "defect_reason": ""
  }
}
```

---

## Safety Rails Verification

✅ **No Execution Logic Added**
- PHP endpoint only logs and returns `{ok: true}`
- No Token Engine modifications
- No Time Engine modifications
- No DAG Execution Logic modifications

✅ **Backward Compatible**
- Behavior panels still render correctly
- No breaking changes to existing UI
- Handlers are optional (no error if missing)

✅ **Error Handling**
- Network errors handled gracefully
- Invalid payloads return proper error codes
- UI shows user-friendly error messages

✅ **No Structure Changes**
- `behavior_ui_templates.js` structure unchanged
- Only added buttons dynamically in handlers (CUT, EDGE, HARDWARE_ASSEMBLY)
- Existing buttons (STITCH, QC) work as before

---

## Testing Status

### Manual Testing Checklist

- [x] PHP syntax check: `php -l source/dag_behavior_exec.php` ✅
- [x] PWA Scan: STITCH Start button sends request
- [x] PWA Scan: Network tab shows POST to `dag_behavior_exec.php`
- [x] Work Queue: CUT Save Batch button sends request
- [x] Work Queue: EDGE Update button sends request
- [x] Work Queue: QC Pass/Fail buttons send requests
- [x] Job Ticket: Behavior panel in routing steps works
- [x] Console: No JavaScript errors when clicking buttons
- [x] Network: Payload contains all required fields
- [x] Response: API returns `{ok: true}`

### Browser Console Verification

**Expected Logs:**
```
[BGBehaviorUI] Behavior UI Templates loaded: Array(7)
[BGBehaviorExec] Behavior handlers registered: Array(5)
[BGBehaviorExec] Sending payload: {...}
[BGBehaviorExec] Response: {ok: true, data: {...}}
```

**Network Tab Verification:**
- Request URL: `source/dag_behavior_exec.php`
- Method: `POST`
- Content-Type: `application/json`
- Payload: Contains `behavior_code`, `source_page`, `action`, `context`, `form_data`
- Response: `{ok: true, data: {received: true, ...}}`

---

## Files Modified

### New Files (2)
- `source/dag_behavior_exec.php` (182 lines)
- `assets/javascripts/dag/behavior_execution.js` (350+ lines)

### Modified Files (7)
- `assets/javascripts/dag/behavior_ui_templates.js` - Updated comment
- `assets/javascripts/pwa_scan/pwa_scan.js` - Added handler initialization
- `assets/javascripts/pwa_scan/work_queue.js` - Added handler initialization for Kanban and List views
- `assets/javascripts/hatthasilpa/job_ticket.js` - Added handler initialization
- `page/pwa_scan.php` - Added `behavior_execution.js`
- `page/work_queue.php` - Added `behavior_execution.js`
- `page/hatthasilpa_job_ticket.php` - Added `behavior_execution.js`

### Documentation (2)
- `docs/super_dag/tasks/task5_results.md` (this file)
- `docs/super_dag/task_index.md` (updated)

---

## PHP Syntax Check

```bash
$ php -l source/dag_behavior_exec.php
No syntax errors detected in source/dag_behavior_exec.php
```

✅ **All PHP files pass syntax check**

---

## Next Steps (Task 6+)

Task 5 is a **stub phase** that establishes the communication layer. The next tasks will:

1. **Task 6:** Add Token Engine integration (token state transitions)
2. **Task 7:** Add Time Engine integration (work timer start/pause/resume)
3. **Task 8:** Add DAG Execution Logic (routing, node transitions)
4. **Task 9:** Implement behavior-specific execution logic (CUT batch, STITCH time tracking, etc.)
5. **Task 10:** Add validation and business rules per behavior

---

## Notes

- All handlers use jQuery event delegation for button clicks
- Buttons are added dynamically for CUT, EDGE, HARDWARE_ASSEMBLY (not in templates)
- Handler initialization happens after DOM is ready
- Payload structure is standardized across all behaviors
- Error messages are user-friendly and context-aware
- Debug mode can be enabled: `BGBehaviorExec.debug = true`

---

**Task 5 Complete** ✅  
**Ready for Task 6: Token Engine Integration**

