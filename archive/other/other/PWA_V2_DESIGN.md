# 📱 PWA Scan Station v2 - Unified Design

**Concept:** รวม Mobile WIP + PWA Scan Station → ระบบเดียวที่ใช้งานได้ทั้ง Quick & Detail

---

## Design Philosophy

> **"Simple by default, Powerful when needed"**

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  เริ่มต้นด้วย Quick Mode (2 clicks) 🏃                     │
│  แต่สามารถสลับเป็น Detail Mode (full form) ได้ทันที 📝     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## UI Mockup

### Landing Screen (Quick Mode - Default)

```
╔═══════════════════════════════════════════════════════════════╗
║  📱 Scan Station                            [⚡Quick] [Detail]║
║  หน้างานดิจิทัล - รวดเร็ว แม่นยำ                            ║
║  [🟢 Online]  [Queue: 0]                                     ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────┐    ║
║  │  [📷 สแกน QR/Barcode]                  (60px tall)  │    ║
║  └─────────────────────────────────────────────────────┘    ║
║                                                               ║
║                        หรือ                                  ║
║                                                               ║
║  ┌──────────────────────────────────┐ [✓ ตกลง]             ║
║  │ พิมพ์หมายเลข Ticket/MO/Lot     │                        ║
║  └──────────────────────────────────┘                        ║
║                                                               ║
║  ─────────────────────────────────────────────────────      ║
║                                                               ║
║  🎫 JOB-MO2025100012                               [✕]      ║
║  Job Ticket • เย็บมือ                                       ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────┐    ║
║  │  [🟢 เริ่มงาน              ]    (Start)            │    ║
║  │  [🔵 บันทึกความคืบหน้า      ]    (Progress)        │    ║
║  │  [🟡 ตรวจ QC               ]    (QC Check)         │    ║
║  │  [🔴 รายงานข้อบกพร่อง       ]    (Report Defect)   │    ║
║  │  [✅ เสร็จสมบูรณ์           ]    (Complete)        │    ║
║  └─────────────────────────────────────────────────────┘    ║
║                                                               ║
║  📋 กิจกรรมล่าสุด                                           ║
║  ┌─────────────────────────────────────────────────────┐    ║
║  │  JOB-001 • progress • 11:23                        │    ║
║  │  JOB-002 • complete • 11:15                        │    ║
║  └─────────────────────────────────────────────────────┘    ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### Detail Mode (Toggle to Full Form)

```
╔═══════════════════════════════════════════════════════════════╗
║  📱 Scan Station                            [Quick] [📝Detail]║
║  หน้างานดิจิทัล - รวดเร็ว แม่นยำ                            ║
║  [🟢 Online]  [Queue: 0]                                     ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────┐    ║
║  │  [📷 สแกน QR/Barcode]                              │    ║
║  └─────────────────────────────────────────────────────┘    ║
║                                                               ║
║  🎫 JOB-MO2025100012                               [✕]      ║
║  Job Ticket • เย็บมือ • Target: 10 pcs                      ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────┐    ║
║  │  📋 รายละเอียดการบันทึก                             │    ║
║  │                                                      │    ║
║  │  Task (ขั้นตอน):                                    │    ║
║  │  [CUT - ตัดหนัง           ▼]                       │    ║
║  │                                                      │    ║
║  │  Event Type:                                        │    ║
║  │  [🟢 Start] [📊 Progress] [⏸️ Hold]               │    ║
║  │  [▶️ Resume] [✅ Complete] [❌ Fail]              │    ║
║  │                                                      │    ║
║  │  Quantity (จำนวน):                                  │    ║
║  │  [___5___] pieces                                   │    ║
║  │                                                      │    ║
║  │  ─── QC Fail Details (if event = fail) ───         │    ║
║  │                                                      │    ║
║  │  Severity:                                          │    ║
║  │  [○ Low  ● Medium  ○ High]                         │    ║
║  │                                                      │    ║
║  │  Defect Code:                                       │    ║
║  │  [SCRATCH_____]                                     │    ║
║  │                                                      │    ║
║  │  Root Cause:                                        │    ║
║  │  ┌───────────────────────────────┐                 │    ║
║  │  │ หนังมีรอยขีดข่วน...          │                 │    ║
║  │  └───────────────────────────────┘                 │    ║
║  │                                                      │    ║
║  │  Photos:                                            │    ║
║  │  [📸 ถ่ายรูป] [📁 เลือกไฟล์]                       │    ║
║  │  [🖼️ IMG_001.jpg] [✕]                              │    ║
║  │                                                      │    ║
║  │  Notes:                                             │    ║
║  │  ┌───────────────────────────────┐                 │    ║
║  │  │ หมายเหตุเพิ่มเติม...          │                 │    ║
║  │  └───────────────────────────────┘                 │    ║
║  │                                                      │    ║
║  │  [💾 บันทึก]           [🔄 Reset]                  │    ║
║  └─────────────────────────────────────────────────────┘    ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## Feature Matrix (PWA v2)

| Feature | Quick Mode | Detail Mode |
|---------|------------|-------------|
| **Scan Input** | ✅ Camera + Manual | ✅ Same |
| **Entity Detection** | ✅ Auto | ✅ Auto + Show details |
| **Action Buttons** | ✅ 5 big buttons | ⚠️ Hidden (use form) |
| **Task Selection** | ❌ Not shown | ✅ Dropdown (required) |
| **Event Type** | ✅ Implicit (via button) | ✅ 6 buttons (start/progress/hold/resume/complete/fail) |
| **Quantity** | ❌ Auto (0) | ✅ Number input |
| **QC Fail Form** | ❌ Basic | ✅ Full (severity/code/cause/photos) |
| **Notes** | ❌ Auto-generated | ✅ Textarea |
| **Photos** | ❌ No | ✅ Camera + Gallery |
| **Offline** | ✅ Queue | ✅ Queue |
| **Vibration** | ✅ Yes | ✅ Yes |
| **Recent Activities** | ✅ Show | ✅ Show |
| **Submit** | ✅ Auto | ✅ Manual (button) |

---

## User Flow Comparison

### Quick Mode Flow (2-3 clicks)
```
┌─────────┐    ┌──────────┐    ┌─────────┐    ┌──────┐
│  Scan   │ →  │  Action  │ →  │  Done!  │ →  │ Next │
│  Code   │    │  Button  │    │ (Auto)  │    │ Job  │
└─────────┘    └──────────┘    └─────────┘    └──────┘
   15s            5s              Auto           Loop

Total Time: ~20 seconds per action
```

### Detail Mode Flow (4-5 clicks)
```
┌─────────┐  ┌──────┐  ┌────────┐  ┌─────┐  ┌────────┐  ┌──────┐
│  Scan   │→ │ Task │→ │ Event  │→ │ Qty │→ │ Submit │→ │ Done │
│  Code   │  │Select│  │ Select │  │Input│  │ Button │  │      │
└─────────┘  └──────┘  └────────┘  └─────┘  └────────┘  └──────┘
   15s         10s        10s        10s       5s         Auto

Total Time: ~50 seconds per action (with QC fail: +60s for photos)
```

**Result:** Quick mode = **2.5× faster** than Detail mode!

---

## Technical Architecture

### Component Structure

```javascript
// PWA v2 Architecture

PWAScanStation
  ├─ ScanInput (Camera + Manual)
  │   ├─ CameraScanner (jsQR)
  │   └─ ManualInput (keyboard)
  │
  ├─ ModeToggle (Quick ⇄ Detail)
  │
  ├─ QuickMode
  │   ├─ EntityCard (show scanned code)
  │   └─ ActionButtons (5 buttons)
  │       ├─ StartButton
  │       ├─ ProgressButton
  │       ├─ QCCheckButton
  │       ├─ DefectButton
  │       └─ CompleteButton
  │
  ├─ DetailMode
  │   ├─ EntityCard (detailed info)
  │   ├─ TaskSelect (dropdown from routing)
  │   ├─ EventTypeButtons (6 buttons)
  │   ├─ QuantityInput
  │   ├─ QCFailForm (conditional)
  │   │   ├─ SeveritySelect
  │   │   ├─ DefectCodeInput
  │   │   ├─ RootCauseTextarea
  │   │   └─ PhotoUpload (camera + gallery)
  │   ├─ NotesTextarea
  │   └─ SubmitButton
  │
  ├─ OfflineQueue
  │   ├─ LocalStorage
  │   └─ SyncManager
  │
  ├─ RecentActivities
  │   └─ ActivityList
  │
  └─ ServiceWorker
      ├─ CacheStrategy
      └─ BackgroundSync
```

---

## State Management

```javascript
const appState = {
  // Mode
  mode: 'quick', // 'quick' | 'detail'
  
  // Current scan
  scannedData: {
    code: 'JOB-MO2025100012',
    type: 'job_ticket', // 'job_ticket' | 'mo' | 'lot'
    id: 123,
    details: {
      ticket_code: 'JOB-MO2025100012',
      job_name: 'Leather Bag Assembly',
      target_qty: 10,
      process_mode: 'piece', // 'piece' | 'batch'
      status: 'in-progress',
      routing_tasks: [
        { id: 1, name: 'CUT', status: 'completed' },
        { id: 2, name: 'SEW', status: 'in-progress' },
        { id: 3, name: 'FINISH', status: 'pending' }
      ]
    }
  },
  
  // Form data (Detail mode)
  formData: {
    id_task: null,
    event_type: null,
    qty: 0,
    notes: '',
    qc_fail: {
      severity: 'medium',
      defect_code: '',
      root_cause: '',
      photos: []
    }
  },
  
  // Offline queue
  queue: [],
  
  // Network
  isOnline: true,
  
  // Activities
  recentActivities: []
};
```

---

## Feature Mapping

### Quick Mode → Action Button Mapping

| Button | Event Type | Auto Fields |
|--------|------------|-------------|
| 🟢 เริ่มงาน | `start` | qty: 0, notes: "Started via PWA" |
| 🔵 บันทึกความคืบหน้า | `progress` | qty: 0, notes: "Progress via PWA" |
| 🟡 ตรวจ QC | `qc_check` | qty: 0, notes: "QC check via PWA" |
| 🔴 รายงานข้อบกพร่อง | `fail` | **→ Switch to Detail mode (QC form)** |
| ✅ เสร็จสมบูรณ์ | `complete` | qty: target_qty, notes: "Completed via PWA" |

**Special Case:** เมื่อกด "รายงานข้อบกพร่อง" → **Auto-switch to Detail mode** เพื่อกรอก QC fail details

---

### Detail Mode → Full Form

```javascript
// Detail mode collects all fields
{
  id_job_ticket: 123,
  id_task: 2,              // Selected from dropdown
  event_type: 'progress',  // Selected from buttons
  qty: 5,                  // User input
  notes: 'Half complete',  // User input
  
  // If event_type = 'fail'
  qc_fail: {
    severity: 'high',
    defect_code: 'SCRATCH',
    root_cause: 'Tool malfunction',
    photos: ['base64...', 'base64...']
  }
}
```

---

## UI Components (Detailed)

### 1. Mode Toggle (Top Right)

```html
<!-- Quick Mode (active) -->
<div class="btn-group mode-toggle">
  <button class="btn btn-sm btn-primary active">
    <i class="ri-flashlight-line"></i> Quick
  </button>
  <button class="btn btn-sm btn-outline-secondary">
    <i class="ri-file-list-line"></i> Detail
  </button>
</div>

<!-- Detail Mode (active) -->
<div class="btn-group mode-toggle">
  <button class="btn btn-sm btn-outline-secondary">
    <i class="ri-flashlight-line"></i> Quick
  </button>
  <button class="btn btn-sm btn-primary active">
    <i class="ri-file-list-line"></i> Detail
  </button>
</div>
```

**Behavior:**
- Click ปุ่ม → Switch mode ทันที
- ถ้ามีข้อมูลในฟอร์ม → Confirm ก่อน switch
- State persist ใน localStorage

---

### 2. Scan Input (Same for Both Modes)

```html
<div class="scan-input-section">
  <!-- Camera Scanner -->
  <button class="btn btn-lg btn-primary w-100 mb-3" id="btn-camera">
    <i class="ri-qr-scan-2-line fs-24"></i>
    <span class="ms-2 fs-18">สแกน QR/Barcode</span>
  </button>
  
  <!-- Manual Input -->
  <div class="input-group input-group-lg">
    <input type="text" 
           class="form-control" 
           id="manual-input" 
           placeholder="พิมพ์หมายเลข Ticket/MO/Lot"
           autofocus>
    <button class="btn btn-secondary">
      <i class="ri-check-line"></i> ตกลง
    </button>
  </div>
</div>
```

---

### 3. Entity Card (After Scan)

```html
<!-- Quick Mode Card -->
<div class="entity-card">
  <div class="d-flex justify-content-between">
    <div>
      <h5>JOB-MO2025100012</h5>
      <small class="text-muted">Job Ticket • เย็บมือ</small>
    </div>
    <button class="btn btn-sm btn-light" id="btn-clear">
      <i class="ri-close-line"></i>
    </button>
  </div>
</div>

<!-- Detail Mode Card (Enhanced) -->
<div class="entity-card">
  <div class="d-flex justify-content-between align-items-start">
    <div>
      <h5>JOB-MO2025100012</h5>
      <small class="text-muted">Job Ticket • เย็บมือ</small>
      <div class="mt-2">
        <span class="badge bg-info">Target: 10 pcs</span>
        <span class="badge bg-warning">In Progress</span>
      </div>
    </div>
    <button class="btn btn-sm btn-light">
      <i class="ri-close-line"></i>
    </button>
  </div>
  
  <!-- Progress bar (Detail mode only) -->
  <div class="mt-3">
    <div class="d-flex justify-content-between mb-1">
      <small>Progress</small>
      <small>7/10 (70%)</small>
    </div>
    <div class="progress" style="height: 8px;">
      <div class="progress-bar bg-success" style="width: 70%"></div>
    </div>
  </div>
  
  <!-- Task list (Detail mode only) -->
  <div class="mt-3">
    <small class="text-muted">Tasks:</small>
    <div class="d-flex gap-2 mt-2">
      <span class="badge bg-success">✓ CUT</span>
      <span class="badge bg-primary">SEW</span>
      <span class="badge bg-secondary">FINISH</span>
    </div>
  </div>
</div>
```

---

### 4. Action Area

**Quick Mode: 5 Big Buttons**
```html
<div class="action-buttons-quick">
  <button class="btn btn-success btn-lg w-100 mb-2" data-action="start">
    <i class="ri-play-circle-line"></i> เริ่มงาน
  </button>
  <button class="btn btn-primary btn-lg w-100 mb-2" data-action="progress">
    <i class="ri-checkbox-circle-line"></i> บันทึกความคืบหน้า
  </button>
  <button class="btn btn-warning btn-lg w-100 mb-2" data-action="qc_check">
    <i class="ri-shield-check-line"></i> ตรวจ QC
  </button>
  <button class="btn btn-danger btn-lg w-100 mb-2" data-action="report_defect">
    <i class="ri-error-warning-line"></i> รายงานข้อบกพร่อง
  </button>
  <button class="btn btn-info btn-lg w-100" data-action="complete">
    <i class="ri-check-double-line"></i> เสร็จสมบูรณ์
  </button>
</div>
```

**Detail Mode: Full Form**
```html
<form id="wip-detail-form" class="wip-form-detail">
  <!-- Task Selection -->
  <div class="mb-3">
    <label class="form-label">Task (ขั้นตอน) *</label>
    <select id="detail-task" class="form-select" required>
      <option value="1">CUT - ตัดหนัง</option>
      <option value="2" selected>SEW - เย็บ</option>
      <option value="3">FINISH - ตกแต่ง</option>
    </select>
  </div>
  
  <!-- Event Type (Button Group) -->
  <div class="mb-3">
    <label class="form-label">Event Type *</label>
    <div class="btn-group-vertical w-100" role="group">
      <input type="radio" class="btn-check" name="event" id="evt-start" value="start">
      <label class="btn btn-outline-success" for="evt-start">
        <i class="ri-play-line"></i> Start
      </label>
      
      <input type="radio" class="btn-check" name="event" id="evt-progress" value="progress" checked>
      <label class="btn btn-outline-primary" for="evt-progress">
        <i class="ri-progress-line"></i> Progress
      </label>
      
      <input type="radio" class="btn-check" name="event" id="evt-hold" value="hold">
      <label class="btn btn-outline-warning" for="evt-hold">
        <i class="ri-pause-line"></i> Hold
      </label>
      
      <input type="radio" class="btn-check" name="event" id="evt-resume" value="resume">
      <label class="btn btn-outline-info" for="evt-resume">
        <i class="ri-play-circle-line"></i> Resume
      </label>
      
      <input type="radio" class="btn-check" name="event" id="evt-complete" value="complete">
      <label class="btn btn-outline-success" for="evt-complete">
        <i class="ri-check-double-line"></i> Complete
      </label>
      
      <input type="radio" class="btn-check" name="event" id="evt-fail" value="fail">
      <label class="btn btn-outline-danger" for="evt-fail">
        <i class="ri-close-circle-line"></i> QC Fail
      </label>
    </div>
  </div>
  
  <!-- Quantity -->
  <div class="mb-3">
    <label class="form-label">Quantity (จำนวน)</label>
    <div class="input-group">
      <input type="number" id="detail-qty" class="form-control" 
             min="0" value="5">
      <span class="input-group-text">pieces</span>
    </div>
    <small class="text-muted">Target: 10 pieces (50% complete)</small>
  </div>
  
  <!-- QC Fail Section (Conditional - shown if event = 'fail') -->
  <div id="qc-fail-section" class="d-none">
    <div class="alert alert-danger">
      <i class="ri-alert-line"></i> QC Fail Information
    </div>
    
    <!-- Severity -->
    <div class="mb-3">
      <label class="form-label">Severity *</label>
      <div class="btn-group w-100" role="group">
        <input type="radio" class="btn-check" name="severity" id="sev-low" value="low">
        <label class="btn btn-outline-success" for="sev-low">Low</label>
        
        <input type="radio" class="btn-check" name="severity" id="sev-med" value="medium" checked>
        <label class="btn btn-outline-warning" for="sev-med">Medium</label>
        
        <input type="radio" class="btn-check" name="severity" id="sev-high" value="high">
        <label class="btn btn-outline-danger" for="sev-high">High</label>
      </div>
    </div>
    
    <!-- Defect Code -->
    <div class="mb-3">
      <label class="form-label">Defect Code</label>
      <input type="text" class="form-control" placeholder="e.g., SCRATCH, DENT">
    </div>
    
    <!-- Root Cause -->
    <div class="mb-3">
      <label class="form-label">Root Cause *</label>
      <textarea class="form-control" rows="3" 
                placeholder="อธิบายสาเหตุของข้อบกพร่อง..."></textarea>
    </div>
    
    <!-- Photos -->
    <div class="mb-3">
      <label class="form-label">Photos</label>
      <div class="d-grid gap-2">
        <button type="button" class="btn btn-outline-primary" id="btn-take-photo">
          <i class="ri-camera-line"></i> ถ่ายรูป
        </button>
        <input type="file" id="photo-upload" class="d-none" 
               accept="image/*" capture="environment" multiple>
      </div>
      <div id="photo-previews" class="mt-2 d-flex gap-2 flex-wrap">
        <!-- Photos appear here -->
      </div>
    </div>
  </div>
  
  <!-- Notes (Always shown in Detail mode) -->
  <div class="mb-3">
    <label class="form-label">Notes</label>
    <textarea id="detail-notes" class="form-control" rows="2"
              placeholder="หมายเหตุเพิ่มเติม..."></textarea>
  </div>
  
  <!-- Submit -->
  <div class="d-grid gap-2">
    <button type="submit" class="btn btn-success btn-lg">
      <i class="ri-save-line"></i> บันทึก
    </button>
    <button type="button" class="btn btn-outline-secondary" id="btn-reset">
      <i class="ri-refresh-line"></i> Reset
    </button>
  </div>
</form>
```

---

## Smart Defaults

### Process Mode Detection

```javascript
// Auto-populate based on job ticket process_mode
if (ticket.process_mode === 'piece') {
  // Piece mode: Qty required for most events
  showQuantityInput();
  setQuantityRequired(true);
  
} else if (ticket.process_mode === 'batch') {
  // Batch mode: Qty optional
  showQuantityInput();
  setQuantityRequired(false);
  hintText = 'Batch mode: Enter qty if tracking per batch';
}
```

### Task Auto-Selection

```javascript
// Quick mode: Auto-select first in-progress task
const inProgressTask = ticket.routing_tasks.find(t => t.status === 'in-progress');
if (inProgressTask) {
  formData.id_task = inProgressTask.id;
}

// Detail mode: Show all tasks, pre-select in-progress
populateTaskDropdown(ticket.routing_tasks, inProgressTask?.id);
```

### Event Type Hints

```javascript
// Suggest next logical action based on status
const suggestions = {
  'planned': ['start'],
  'in-progress': ['progress', 'hold', 'complete', 'fail'],
  'on-hold': ['resume'],
  'qc': ['complete', 'fail']
};

// Highlight suggested buttons
highlightSuggestedActions(ticket.status);
```

---

## Progressive Enhancement

### Mobile-First, Desktop-Enhanced

**Mobile (< 768px):**
```css
/* Stack everything vertically */
.scan-station {
  max-width: 600px;
  margin: 0 auto;
}

.action-buttons button {
  height: 60px;
  font-size: 18px;
}

.entity-card {
  position: sticky;
  top: 0;
  z-index: 10;
}
```

**Tablet (768px - 1024px):**
```css
/* Wider action buttons */
.action-buttons {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
```

**Desktop (> 1024px):**
```css
/* Two-column layout */
.scan-station-wrapper {
  display: grid;
  grid-template-columns: 400px 1fr;
  gap: 20px;
}

.scan-input-section {
  /* Left column */
}

.form-section {
  /* Right column */
}
```

---

## API Changes (Backward Compatible)

### Current PWA API
```php
// source/pwa_scan_api.php
// Supports Quick mode only

POST /source/pwa_scan_api.php
{
  "code": "JOB-MO2025100012",
  "action": "progress",
  "timestamp": "2025-10-28T11:00:00"
}
```

### PWA v2 API (Enhanced)
```php
// source/pwa_scan_api.php (v2)
// Supports both Quick & Detail modes

POST /source/pwa_scan_api.php
{
  "mode": "quick", // or "detail"
  "code": "JOB-MO2025100012",
  
  // Quick mode fields
  "action": "progress",
  
  // Detail mode fields (optional)
  "id_task": 2,
  "event_type": "progress",
  "qty": 5,
  "notes": "Half complete",
  
  // QC fail fields (if event_type = 'fail')
  "qc_fail": {
    "severity": "high",
    "defect_code": "SCRATCH",
    "root_cause": "Tool malfunction",
    "photos": ["base64...", "base64..."]
  },
  
  "timestamp": "2025-10-28T11:00:00"
}
```

**Backend Logic:**
```php
$mode = $input['mode'] ?? 'quick';

if ($mode === 'quick') {
  // Use existing quick logic
  $idTask = auto_detect_task($entityId);
  $qty = 0;
  $notes = "Auto via PWA";
  
} else { // detail
  // Use full form data
  $idTask = $input['id_task'];
  $eventType = $input['event_type'];
  $qty = $input['qty'] ?? 0;
  $notes = $input['notes'] ?? '';
  
  // Handle QC fail
  if ($eventType === 'fail' && isset($input['qc_fail'])) {
    create_qc_fail_event($input['qc_fail']);
    upload_qc_photos($input['qc_fail']['photos']);
  }
}

// Common: Insert WIP log
insert_wip_log($tenantDb, $entityId, $idTask, $eventType, $qty, $notes);
```

---

## User Preferences

### Remember User's Choice

```javascript
// Save preferred mode
localStorage.setItem('pwa_preferred_mode', 'quick'); // or 'detail'

// On load
const preferredMode = localStorage.getItem('pwa_preferred_mode') || 'quick';
setState({ mode: preferredMode });
```

### Per-User Settings (Future)
```php
// Save in database
UPDATE account 
SET preferences = JSON_SET(preferences, '$.pwa_mode', 'detail')
WHERE id_member = ?
```

---

## Migration Strategy

### Phase 1: Build PWA v2 (Week 1-2)
```
✓ Add mode toggle
✓ Implement Detail mode UI
✓ Enhance API to support both modes
✓ Add task selection
✓ Add QC fail form
✓ Add photo upload
✓ Testing (unit + integration)
```

### Phase 2: Pilot (Week 3)
```
✓ Deploy PWA v2 alongside Mobile WIP
✓ Train 5-10 users
✓ Collect feedback
✓ Monitor usage patterns:
  • Quick mode: 80% usage?
  • Detail mode: 20% usage?
  • Which features most used?
```

### Phase 3: Transition (Week 4)
```
✓ Redirect /atelier_wip_mobile → PWA v2
✓ Add banner: "New PWA available! Click here"
✓ Train all users
✓ Monitor error rates
```

### Phase 4: Deprecate (Week 5-6)
```
✓ Announce Mobile WIP deprecation
✓ Set deprecation date (2 weeks notice)
✓ Remove from menu
✓ Archive code (keep in /legacy/)
```

---

## Performance Targets (PWA v2)

| Action | Quick Mode | Detail Mode | Target |
|--------|------------|-------------|--------|
| Scan-to-Action | 2s | N/A | < 3s |
| Full Form Submit | N/A | 30s | < 60s |
| Offline Queue | Instant | Instant | < 1s |
| Photo Upload | N/A | 5s/photo | < 10s |
| Sync Time | 2s | 5s | < 10s |

---

## Data Model (Unified)

### atelier_wip_log (Enhanced)
```sql
-- Existing columns (Mobile WIP)
id_wip_log INT PRIMARY KEY AUTO_INCREMENT,
id_job_ticket INT,
id_job_task INT NULL,        -- NULL OK for Quick mode
event_type VARCHAR(50),      -- start/progress/hold/resume/complete/fail
event_time TIMESTAMP,
qty DECIMAL(10,2) DEFAULT 0, -- 0 for Quick mode
notes TEXT,                  -- Auto-generated or user input
actor_id INT,
operator_name VARCHAR(255),
barcode_payload TEXT,

-- New columns for PWA v2
source VARCHAR(20) DEFAULT 'web',  -- 'pwa_quick' | 'pwa_detail' | 'web'
device_info JSON,                  -- {type: 'mobile', os: 'iOS', ...}
is_offline_synced BOOLEAN DEFAULT 0,
synced_at TIMESTAMP NULL
```

### qc_fail_event (Same)
```sql
-- No changes needed
-- PWA v2 Detail mode uses same structure as Mobile WIP
```

---

## Example: Unified Workflow

### Scenario 1: Quick Action (ช่างเร่งรีบ)
```
1. [15s] Scan JOB-MO2025100012
2. [5s]  กดปุ่ม "บันทึกความคืบหน้า"
3. [Auto] ระบบบันทึก:
   • id_task: Auto-detect (SEW)
   • event_type: 'progress'
   • qty: 0
   • notes: "Progress via PWA quick mode"
   • source: 'pwa_quick'
   
Total: 20 seconds ✅
```

### Scenario 2: Detailed Entry (QC Inspector)
```
1. [15s]  Scan JOB-MO2025100012
2. [5s]   Switch to Detail mode
3. [10s]  เลือก Task: SEW
4. [10s]  เลือก Event: QC Fail
5. [20s]  กรอก QC form:
   • Severity: High
   • Defect Code: SCRATCH
   • Root Cause: "หนังมีรอยขีดข่วนจากเครื่องมือ"
6. [30s]  ถ่ายรูป 2 รูป
7. [10s]  Review + Submit
8. [Auto] ระบบบันทึก:
   • id_task: 2 (SEW)
   • event_type: 'fail'
   • qty: 1 (defect qty)
   • notes: User input
   • source: 'pwa_detail'
   • QC fail event created
   • Photos uploaded
   
Total: 100 seconds (1m 40s) ✅
```

---

## Key Improvements Over Separate Systems

### For Users:
```
✅ Single app to learn
✅ Consistent interface
✅ Choose complexity level (quick vs detail)
✅ Offline works in both modes
✅ Install once, use everywhere
```

### For Developers:
```
✅ Single codebase
✅ Shared components
✅ Easier testing
✅ Easier maintenance
✅ Single deployment
```

### For Business:
```
✅ Lower training cost
✅ Consistent data quality
✅ Better user adoption
✅ Flexible for different roles:
   • Operators → Quick mode
   • QC/Supervisors → Detail mode
```

---

## Estimated Effort

### Development (3-4 days)
```
Day 1:
  ✓ Add mode toggle UI
  ✓ Implement Detail mode layout
  ✓ Task selection dropdown
  ✓ Event type button group
  
Day 2:
  ✓ Quantity input
  ✓ QC fail form (conditional)
  ✓ Notes textarea
  ✓ Form validation
  
Day 3:
  ✓ Photo upload (camera + gallery)
  ✓ Enhance API backend
  ✓ State management
  ✓ LocalStorage integration
  
Day 4:
  ✓ Testing (unit + integration)
  ✓ Bug fixes
  ✓ Performance optimization
  ✓ Documentation
```

### Testing (1 day)
```
✓ Quick mode: All 5 actions
✓ Detail mode: All event types
✓ QC fail flow: End-to-end
✓ Photo upload: Multiple photos
✓ Offline queue: Both modes
✓ Mode switching: State persistence
```

### Total: **4-5 days** to production-ready

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| User confusion (2 modes) | Medium | Low | Clear labels, tooltips, training |
| Data inconsistency | Low | Medium | Validate both modes equally |
| Performance degradation | Low | Low | Lazy load Detail mode components |
| Photo upload failures | Medium | Medium | Fallback to file input, retry logic |
| Offline conflicts | Low | Medium | Timestamp + queue + idempotent API |

**Overall Risk: 🟡 LOW-MEDIUM (Acceptable)**

---

## Success Metrics

### Adoption Rate
```
Target (Month 1): 50% of users try PWA v2
Target (Month 3): 80% prefer PWA v2 over Mobile WIP
```

### Mode Usage
```
Expected:
  Quick mode: 70-80% of actions
  Detail mode: 20-30% of actions
  
Measure:
  • Log source='pwa_quick' vs 'pwa_detail'
  • Weekly report
```

### Performance
```
Quick mode:   < 25s per action (avg 20s)
Detail mode:  < 90s per action (avg 60s)
Error rate:   < 1%
Sync success: > 99%
```

---

## Conclusion

### รูปแบบที่รวมกันแล้ว:

```
┌─────────────────────────────────────────────────────────┐
│  PWA Scan Station v2 - Unified Edition                 │
│                                                         │
│  [⚡ Quick Mode]  ← Default (80% usage)                │
│    • 2-3 clicks                                        │
│    • Auto-fill smart defaults                          │
│    • ไม่ต้องกรอกฟอร์ม                                 │
│                                                         │
│  [📝 Detail Mode]  ← Toggle when needed (20% usage)   │
│    • Full form                                         │
│    • Task selection                                    │
│    • QC documentation                                  │
│    • Photo evidence                                    │
│                                                         │
│  [💾 Offline Support]  ← Works in both modes          │
│    • Queue + Auto-sync                                 │
│    • Service Worker                                    │
│    • LocalStorage                                      │
│                                                         │
│  [📱 PWA Features]  ← One-time install                │
│    • Add to Home Screen                                │
│    • Camera integration                                │
│    • Push notifications (future)                       │
└─────────────────────────────────────────────────────────┘
```

**ตอบคำถาม:** จะออกมาเป็น **Progressive Web App แบบ Dual-mode** ที่ผู้ใช้สามารถ:
1. ใช้แบบเร็ว (Quick) สำหรับงานทั่วไป (80% use cases)
2. สลับเป็นแบบละเอียด (Detail) เมื่อต้องการ (20% use cases)

**Best of both worlds! 🎯**

---

**ต้องการให้ implement PWA v2 เลยไหมครับ?** (ใช้เวลา 4-5 วัน)
