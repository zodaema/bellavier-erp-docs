# 🔧 DAG Routing System - Refactor Plan

**วันที่:** 2025-11-12  
**สถานะ:** 🟢 Phase 3 In Progress (3.1-3.3 Complete)  
**เป้าหมาย:** ปรับปรุงโครงสร้างโค้ด, ลดความซ้ำซ้อน, เพิ่มเสถียรภาพ และประสิทธิภาพ

---

## 📋 สารบัญ

1. [ภาพรวมการ Refactor](#ภาพรวมการ-refactor)
2. [Phase 1: Critical Fixes (เสถียรภาพ)](#phase-1-critical-fixes-เสถียรภาพ)
3. [Phase 2: Moderate Refactoring (โครงสร้าง)](#phase-2-moderate-refactoring-โครงสร้าง)
4. [Phase 3: Optional Improvements (ประสิทธิภาพ)](#phase-3-optional-improvements-ประสิทธิภาพ)
5. [API Refactoring Plan](#api-refactoring-plan)
6. [Quality Gates & SLOs](#quality-gates--slos)
7. [Observability & Telemetry](#observability--telemetry)
8. [Security & Privacy Hardening](#security--privacy-hardening)
9. [CI/CD & Testing Matrix](#cicd--testing-matrix)
10. [Performance Budget & Benchmarks](#performance-budget--benchmarks)
11. [Rollout Strategy & Feature Flags](#rollout-strategy--feature-flags)
12. [Risk Register & Backout Plan](#risk-register--backout-plan)
13. [System Integration Layer](#system-integration-layer)
14. [Data Retention & Archival Plan](#data-retention--archival-plan)
15. [Schema Dependency Map](#schema-dependency-map)
16. [Failover Plan](#failover-plan)
17. [AI Validation Hook Spec](#ai-validation-hook-spec)
18. [Timeline & Milestones](#timeline--milestones)

---

## 🎯 ภาพรวมการ Refactor

### ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | ขนาด | สถานะ | ความสำคัญ |
|------|------|-------|----------|
| `graph_designer.js` | ~4,655 บรรทัด | 🔴 Critical | Frontend Core |
| `dag_routing_api.php` | ~5,208 บรรทัด | 🔴 Critical | Backend Core |

### หลักการ Refactor

1. **ไม่ทำลาย Logic ที่ดีอยู่แล้ว** (ETag, auto-save, validation)
2. **ลดความซ้ำซ้อน** (DRY principle)
3. **เพิ่มความอ่านง่าย** (Maintainability)
4. **ปรับปรุงประสิทธิภาพ** (Performance)
5. **เพิ่มเสถียรภาพ** (Stability)

---

## 🔴 Phase 1: Critical Fixes (เสถียรภาพ)

**เป้าหมาย:** แก้ไขปัญหาที่อาจทำให้ระบบไม่เสถียร  
**ระยะเวลา:** 2-3 วัน  
**ลำดับความสำคัญ:** สูงสุด

### 1.1 Cytoscape Instance Exposure

**ปัญหา:**
```javascript
let cy = null;
window.cy = cy; // ❌ ไม่อัปเดตเมื่อสร้าง instance ใหม่
```

**แก้ไข:**
```javascript
// สร้าง helper function
function exposeCytoscapeInstance(instance) {
    window.cy = instance;
    if (window.APP_DEBUG) {
        console.log('Cytoscape instance exposed to window.cy');
    }
}

// เรียกใช้หลังจากสร้างเสร็จ
cy = cytoscape({...});
exposeCytoscapeInstance(cy);
```

**ไฟล์:** `graph_designer.js`  
**ตำแหน่ง:** ทุกที่ที่สร้าง Cytoscape instance

---

### 1.2 Auto-save Flag Logic

**ปัญหา:**
```javascript
if (silent && isAutoSaving && retryCount === 0) return;
if (!silent && isManualSaving && retryCount === 0) return;
// ❌ ซับซ้อน, เสี่ยงค้างในสถานะ
```

**แก้ไข:**
```javascript
// สร้าง state machine helper
function canSaveGraph(silent = false, retryCount = 0) {
    // Block if already saving
    if (isAutoSaving || isManualSaving || isLoadingGraph) {
        return false;
    }
    
    // Block retry if already attempted
    if (retryCount > 0 && (isAutoSaving || isManualSaving)) {
        return false;
    }
    
    return true;
}

// ใช้ใน saveGraph
function saveGraph(silent = false, retryCount = 0) {
    if (!canSaveGraph(silent, retryCount)) {
        console.log('Save blocked: operation in progress');
        return;
    }
    // ... rest of save logic
}
```

**ไฟล์:** `graph_designer.js`  
**ตำแหน่ง:** `saveGraph()` function

---

### 1.3 Timer Cleanup

**ปัญหา:**
```javascript
// ❌ กระจายหลายที่, เสี่ยง memory leak
autoSaveTimer
pendingReloadTimer
window.autoSaveFallbackTimer
```

**แก้ไข:**
```javascript
// สร้าง Timer Manager
const TimerManager = {
    timers: {},
    
    set(name, callback, delay) {
        this.clear(name);
        this.timers[name] = setTimeout(() => {
            callback();
            delete this.timers[name];
        }, delay);
    },
    
    clear(name) {
        if (this.timers[name]) {
            clearTimeout(this.timers[name]);
            delete this.timers[name];
        }
        // Also clear window.* timers for backward compatibility
        if (window[name]) {
            clearTimeout(window[name]);
            window[name] = null;
        }
    },
    
    clearAll() {
        Object.keys(this.timers).forEach(name => this.clear(name));
    }
};

// ใช้แทน
TimerManager.set('autoSave', () => autoSaveGraph(), 3000);
TimerManager.clear('autoSave');
```

**ไฟล์:** `graph_designer.js`  
**ตำแหน่ง:** ทุกที่ที่ใช้ `setTimeout` / `clearTimeout`

---

### 1.4 ETag Parsing Utility

**ปัญหา:**
```javascript
// ❌ ซ้ำซ้อนกว่า 6 จุด
parsedETag = etagHeader.trim().replace(/^"|"$/g, '').replace(/^W\//, '');
```

**แก้ไข:**
```javascript
// สร้าง ETag utility
const ETagUtils = {
    parse(header) {
        if (!header) return null;
        return header.trim()
            .replace(/^"|"$/g, '')  // Remove quotes
            .replace(/^W\//, '');    // Remove weak validator prefix
    },
    
    format(etag, weak = false) {
        if (!etag) return null;
        const prefix = weak ? 'W/' : '';
        return `${prefix}"${etag}"`;
    },
    
    match(current, incoming) {
        return this.parse(current) === this.parse(incoming);
    }
};

// ใช้แทน
const currentETag = ETagUtils.parse(jqXHR.getResponseHeader('ETag'));
```

**ไฟล์:** `graph_designer.js`  
**ตำแหน่ง:** ทุกที่ที่ parse ETag

---

## 🟠 Phase 2: Moderate Refactoring (โครงสร้าง)

**เป้าหมาย:** ปรับปรุงโครงสร้างโค้ดให้อ่านง่ายและบำรุงรักษาง่าย  
**ระยะเวลา:** 5-7 วัน  
**ลำดับความสำคัญ:** ปานกลาง

### 2.1 Notification System Consolidation

**ปัญหา:**
```javascript
// ❌ ซ้ำกัน 4 ตัว
notifySuccess()
notifyError()
notifyInfo()
notifyWarning()
```

**แก้ไข:**
```javascript
// สร้าง Notification Manager
const NotificationManager = {
    isShowing: false,
    queue: [],
    
    show(type, message, title) {
        // Prevent duplicate notifications
        if (this.isShowing && type === 'success') {
            return;
        }
        
        this.isShowing = true;
        clearToasts();
        
        const defaultTitle = t(`common.${type}`, type.charAt(0).toUpperCase() + type.slice(1));
        toastr[type](message, title || defaultTitle);
        
        // Reset flag after animation
        setTimeout(() => {
            this.isShowing = false;
            this.processQueue();
        }, 3000);
    },
    
    success(message, title) { this.show('success', message, title); },
    error(message, title) { this.show('error', message, title); },
    info(message, title) { this.show('info', message, title); },
    warning(message, title) { this.show('warning', message, title); },
    
    processQueue() {
        if (this.queue.length > 0 && !this.isShowing) {
            const { type, message, title } = this.queue.shift();
            this.show(type, message, title);
        }
    }
};

// ใช้แทน
NotificationManager.success('Graph saved successfully');
```

**ไฟล์:** `graph_designer.js`  
**ตำแหน่ง:** ทุกที่ที่เรียก `notify*()` functions

---

### 2.2 Keyboard Shortcut Handler

**ปัญหา:**
```javascript
// ❌ ยาวเกิน, ยาก maintain
$(document).on('keydown', function(e) {
    if (e.ctrlKey || e.metaKey) {
        if (e.key === 'z' && !e.shiftKey) { undo(); }
        else if (e.key === 'z' && e.shiftKey) { redo(); }
        // ... 50+ lines
    }
});
```

**แก้ไข:**
```javascript
// สร้าง Keyboard Shortcut Manager
const KeyboardShortcuts = {
    shortcuts: {
        'Ctrl+Z': { handler: () => undo(), preventDefault: true },
        'Ctrl+Shift+Z': { handler: () => redo(), preventDefault: true },
        'Ctrl+S': { handler: () => saveGraph(false), preventDefault: true },
        'Delete': { handler: () => deleteSelected(), preventDefault: true },
        'F': { handler: () => cy?.fit(cy.nodes(), 50), preventDefault: false },
        'C': { handler: () => cy?.center(), preventDefault: false },
        'Escape': { handler: () => clearSelection(), preventDefault: true }
    },
    
    init() {
        $(document).on('keydown', (e) => this.handle(e));
    },
    
    handle(e) {
        const key = this.getKeyString(e);
        const shortcut = this.shortcuts[key];
        
        if (shortcut) {
            if (shortcut.preventDefault) {
                e.preventDefault();
            }
            shortcut.handler();
        }
    },
    
    getKeyString(e) {
        const parts = [];
        if (e.ctrlKey || e.metaKey) parts.push('Ctrl');
        if (e.shiftKey) parts.push('Shift');
        if (e.altKey) parts.push('Alt');
        parts.push(e.key);
        return parts.join('+');
    },
    
    register(key, handler, options = {}) {
        this.shortcuts[key] = {
            handler,
            preventDefault: options.preventDefault !== false
        };
    }
};

// Initialize
KeyboardShortcuts.init();
```

**ไฟล์:** `graph_designer.js`  
**ตำแหน่ง:** แทนที่ keyboard handler ทั้งหมด

**สถานะการดำเนินการ (2025-11-12):** ✅ เสร็จสมบูรณ์
- สร้าง `KeyboardShortcuts.js` (UMD) สำหรับจัดการคีย์ลัดทั้งหมดของ Graph Designer
- สร้าง `EventManager.js` (UMD) เพื่อรวม UI event bindings และรองรับ fallback legacy
- อัปเดต `graph_designer.js` ให้เรียกใช้โมดูลใหม่พร้อม fallback กรณีโหลดไม่สำเร็จ
- ปรับ `page/routing_graph_designer.php` ให้โหลด Toaster/KeyboardShortcuts/EventManager ตามลำดับ
- เพิ่มชุดทดสอบใน `tools/test_phase2_1_modules.html` ครอบคลุม Phase 2.1 + 2.2 (51 assertions)
- **ถัดไป:** รวม Notification Manager (Phase 2.1) และแยกโมดูล UI อื่น ๆ (Phase 2.3)

---

### 2.3 State & History Manager

**ปัญหา:**
```javascript
// ❌ undo/redo และ isModified กระจายอยู่ใน graph_designer.js
let historyStack = [];
let historyIndex = -1;
let isModified = false;
// ยากต่อการ maintain และ test
```

**แก้ไข:**
```javascript
// สร้าง GraphHistoryManager และ GraphStateManager
const GraphHistoryManager = {
    saveState(cy) { /* ... */ },
    undo(cy) { /* ... */ },
    redo(cy) { /* ... */ },
    canUndo() { /* ... */ },
    canRedo() { /* ... */ },
    clear() { /* ... */ }
};

const GraphStateManager = {
    setModified() { /* ... */ },
    clearModified() { /* ... */ },
    isModified() { /* ... */ },
    onModified(callback) { /* ... */ },
    onCleared(callback) { /* ... */ }
};
```

**ไฟล์:** `assets/javascripts/dag/modules/GraphHistoryManager.js`, `GraphStateManager.js`  
**ตำแหน่ง:** แทนที่ undo/redo system และ isModified flag ใน `graph_designer.js`

**สถานะการดำเนินการ (2025-11-12):** ✅ เสร็จสมบูรณ์
- สร้าง `GraphHistoryManager.js` (UMD) สำหรับจัดการ undo/redo stack
  - Methods: `saveState()`, `undo()`, `redo()`, `canUndo()`, `canRedo()`, `clear()`, `updateButtons()`
  - รองรับ history limit (MAX_HISTORY = 50)
  - จัดการ `isRestoringState` flag เพื่อป้องกัน infinite loop
- สร้าง `GraphStateManager.js` (UMD) สำหรับจัดการ `isModified` flag
  - Methods: `setModified()`, `clearModified()`, `isModified()`, `onModified()`, `onCleared()`, `reset()`
  - รองรับ event callbacks สำหรับ state changes
- อัปเดต `graph_designer.js`:
  - ลบ `historyStack`, `historyIndex`, `isRestoringState`, `isModified` variables
  - แทนที่ด้วย `graphHistoryManager` และ `graphStateManager`
  - อัปเดตทุกที่ที่ใช้ `isModified` ให้ใช้ `graphStateManager.isModified()`
  - อัปเดต undo/redo functions ให้ใช้ `graphHistoryManager`
  - เพิ่ม fallback สำหรับกรณี modules ไม่โหลด
- อัปเดต `page/routing_graph_designer.php`:
  - เพิ่ม script tags สำหรับ `GraphHistoryManager.js` และ `GraphStateManager.js`
- เพิ่ม tests ใน `tools/test_phase2_1_modules.html`:
  - GraphHistoryManager: 10 tests (instantiation, saveState, undo, redo, clear, etc.)
  - GraphStateManager: 7 tests (instantiation, setModified, clearModified, callbacks, etc.)
- **ผลลัพธ์:** ลดขนาด `graph_designer.js` ~100 บรรทัด, แยก concerns ชัดเจน, ทดสอบได้ง่ายขึ้น

---

### 2.4 Module Separation - GraphLoader

**ปัญหา:**
```javascript
// ❌ loadGraph() function ยาวกว่า 130 บรรทัด
// รวม API call, ETag parsing, และ UI updates ไว้ด้วยกัน
// ยากต่อการ maintain และ test
```

**แก้ไข:**
```javascript
// สร้าง GraphLoader module
const GraphLoader = {
    loadGraph(graphId, options) { /* API call + ETag parsing */ },
    parseETag(etagHeader) { /* ETag parsing */ },
    generateETag(graphData) { /* ETag generation */ },
    isLoading() { /* Check loading state */ }
};

// แยก UI updates ออกมา
function handleGraphLoaded(graphData, etag, graphId) {
    // UI updates only
}

// loadGraph() ใช้ GraphLoader
function loadGraph(graphId) {
    if (graphLoader) {
        graphLoader.loadGraph(graphId); // Calls handleGraphLoaded() via callback
    } else {
        // Fallback to direct AJAX
    }
}
```

**ไฟล์:** `assets/javascripts/dag/modules/GraphLoader.js`  
**ตำแหน่ง:** แทนที่ API call และ ETag parsing ใน `loadGraph()` function

**สถานะการดำเนินการ (2025-11-12):** ✅ เสร็จสมบูรณ์
- สร้าง `GraphLoader.js` (UMD) สำหรับจัดการ graph loading จาก API
  - Methods: `loadGraph()`, `isLoading()`, `parseETag()`, `generateETag()`
  - รองรับ GraphAPI module และ fallback ไปยัง AJAX โดยตรง
  - จัดการ ETag parsing และ generation
  - มี callbacks: `onLoadStart`, `onLoadSuccess`, `onLoadError`
- อัปเดต `graph_designer.js`:
  - แยก `handleGraphLoaded()` function สำหรับ UI updates
  - `loadGraph()` ใช้ `GraphLoader` สำหรับ API call
  - มี fallback ไปยัง direct AJAX ถ้า module ไม่โหลด
  - ลดขนาด `loadGraph()` function ~50 บรรทัด
- อัปเดต `page/routing_graph_designer.php`:
  - เพิ่ม script tag สำหรับ `GraphLoader.js`
- เพิ่ม tests ใน `tools/test_phase2_1_modules.html`:
  - GraphLoader: 10 tests (instantiation, isLoading, parseETag, generateETag, callbacks)
  - รวมทั้งหมด: 70 tests ผ่าน
- **ผลลัพธ์:** แยก concerns ชัดเจน (API call vs UI updates), ทดสอบได้ง่ายขึ้น, รองรับ fallback

---

### 2.6 GraphSaver Integration

**ปัญหา:**
```javascript
// ❌ graph_designer.js มี save logic ยาวกว่า 1,000 บรรทัด
// saveGraph() function ซับซ้อน (manual save, auto-save, conflict handling)
```

**แก้ไข:**
- แปลง `GraphSaver.js` เป็น UMD format (รองรับ browser script tags)
- อัปเดต GraphSaver ให้ใช้ SafeJSON แทน JSON.stringify
- เพิ่ม script tag สำหรับ GraphSaver.js ใน `page/routing_graph_designer.php`

**ไฟล์ที่แก้ไข:**
- `assets/javascripts/dag/modules/GraphSaver.js` - แปลงเป็น UMD, ใช้ SafeJSON
- `page/routing_graph_designer.php` - เพิ่ม script tag สำหรับ GraphSaver.js

**สถานะการดำเนินการ (2025-11-12):** ✅ เสร็จสมบูรณ์
- แปลง GraphAPI.js เป็น UMD format (รองรับ browser script tags)
- GraphSaver.js แปลงเป็น UMD format แล้ว
- ใช้ SafeJSON แทน JSON.stringify แล้ว
- **Integrate GraphSaver เข้ากับ graph_designer.js:**
  - Initialize GraphSaver ใน graph_designer.js พร้อม dependencies (GraphAPI, ETagUtils, TimerManager, Toaster, Swal, SafeJSON)
  - Refactor `saveGraph()` function ให้ใช้ GraphSaver.canSave(), GraphSaver.saveAuto(), GraphSaver.saveManual()
  - เพิ่ม `handleVersionConflict()` helper function สำหรับจัดการ version conflict
  - มี fallback ไปยัง original implementation ถ้า GraphSaver ไม่โหลด
- อัปเดต `page/routing_graph_designer.php` เพิ่ม script tag สำหรับ GraphAPI.js และ GraphSaver.js
- **ผลลัพธ์:** ลดขนาด saveGraph() function จาก ~900 บรรทัด เหลือ ~150 บรรทัด (ส่วนที่เหลือเป็น fallback), แยก concerns ชัดเจน (state machine, data collection, API calls), ทดสอบได้ง่ายขึ้น

---

### 2.7 GraphValidator Module

**ปัญหา:**
```javascript
// ❌ graph_designer.js มี validation logic กระจัดกระจาย
// validateGraph(), parseValidationErrors(), buildValidationData(), updateValidationPanel()
```

**แก้ไข:**
- สร้าง `GraphValidator.js` module ใน `assets/javascripts/dag/modules/` (UMD format)
- รวม validation functions ทั้งหมด:
  - `parseErrors()` - Parse errors from API response
  - `buildValidationData()` - Build validation data object
  - `buildChecklistItems()` - Build checklist items
  - `buildChecklistHtml()` - Build checklist HTML
  - `buildErrorListHtml()` - Build error list HTML
  - `showValidationDialog()` - Show validation result dialog
  - `showErrorDialog()` - Show error dialog (standardized)
  - `validateGraph()` - Validate graph via API

**ไฟล์ที่สร้าง:**
- `assets/javascripts/dag/modules/GraphValidator.js` - Graph validation module

**ไฟล์ที่แก้ไข:**
- `page/routing_graph_designer.php` - เพิ่ม script tag สำหรับ GraphValidator.js

**สถานะการดำเนินการ (2025-11-12):** ✅ เสร็จสมบูรณ์
- GraphValidator.js สร้างแล้ว (UMD format)
- รวม validation functions ทั้งหมดแล้ว:
  - `parseErrors()` - Parse errors from API response
  - `buildValidationData()` - Build validation data object
  - `buildChecklistItems()` - Build checklist items
  - `buildChecklistHtml()` - Build checklist HTML
  - `buildErrorListHtml()` - Build error list HTML
  - `showValidationDialog()` - Show validation result dialog
  - `showErrorDialog()` - Show error dialog (standardized)
  - `validateGraph()` - Validate graph via API
- **Integrate GraphValidator เข้ากับ graph_designer.js:**
  - Initialize GraphValidator ใน graph_designer.js พร้อม dependencies (t, Swal, Toaster, SafeJSON, callbacks)
  - Refactor `validateGraph()` function ให้ใช้ GraphValidator.validateGraph()
  - มี fallback ไปยัง original implementation ถ้า GraphValidator ไม่โหลด
- อัปเดต `page/routing_graph_designer.php` เพิ่ม script tag สำหรับ GraphValidator.js
- **ผลลัพธ์:** ลดขนาด validateGraph() function จาก ~160 บรรทัด เหลือ ~20 บรรทัด (ส่วนที่เหลือเป็น fallback), แยก concerns ชัดเจน (API call, error parsing, UI display), ทดสอบได้ง่ายขึ้น

---

### 2.5 JSON Helper Utility (SafeJSON)

**ปัญหา:**
```javascript
// ❌ ซ้ำกันหลายสิบครั้ง
try {
    const parsed = JSON.parse(value);
} catch (e) {
    console.error('Parse error');
    return null;
}
```

**แก้ไข:**
- สร้าง `SafeJSON.js` module ใน `assets/javascripts/core/` (UMD format)
- Methods: `parse()`, `stringify()`, `parseArray()`, `parseObject()`, `isValid()`
- Error handling แบบปลอดภัย (ไม่ crash เมื่อ JSON invalid)
- Fallback values สำหรับทุก method

**การใช้งาน:**
```javascript
// แทนที่ JSON.parse() → SafeJSON.parse()
allowedTeamIds: SafeJSON.parseArray(node.allowed_team_ids, []),
joinRequirement: SafeJSON.parseObject(node.join_requirement, {}),

// แทนที่ JSON.stringify() → SafeJSON.stringify()
allowed_team_ids: SafeJSON.stringify(node.data('allowedTeamIds'), null),
nodes: SafeJSON.stringify(nodes, '[]'),
```

**ไฟล์ที่สร้าง:**
- `assets/javascripts/core/SafeJSON.js` - Safe JSON utility module

**ไฟล์ที่แก้ไข:**
- `graph_designer.js` - แทนที่ JSON.parse/stringify ทั้งหมด (30+ จุด)
- `page/routing_graph_designer.php` - เพิ่ม script tag สำหรับ SafeJSON.js

**สถานะ:** ✅ Complete
- สร้าง SafeJSON.js module แล้ว
- แทนที่ JSON.parse/stringify ใน graph_designer.js แล้ว (30+ จุด)
- มี fallback ถ้า module ไม่โหลด
- Error handling ดีขึ้น (ไม่ crash เมื่อ JSON invalid)

---

## 🟢 Phase 3: Optional Improvements (ประสิทธิภาพ)

**เป้าหมาย:** ปรับปรุงประสิทธิภาพและคุณภาพโค้ด  
**ระยะเวลา:** 3-5 วัน  
**ลำดับความสำคัญ:** ต่ำ

### 3.1 Auto-save Debounce

**ปัญหา:**
```javascript
// ❌ ใช้ TimerManager.set() ซ้ำๆ, control ยาก
TimerManager.set('autoSave', function() { saveGraph(true); }, 3000);
```

**แก้ไข:**
- สร้าง `Debounce.js` module ใน `assets/javascripts/core/` (UMD format)
- Functions: `debounce()`, `throttle()`
- Features: leading/trailing options, cancel(), flush(), pending()
- ใช้ debounce สำหรับ auto-save แทน TimerManager

**การใช้งาน:**
```javascript
// สร้าง debounced function
const debouncedAutoSave = debounce(function() {
    saveGraph(true);
}, AUTO_SAVE_DEBOUNCE, { leading: false, trailing: true });

// เรียกใช้
scheduleAutoSave() {
    debouncedAutoSave(); // Auto-debounced
}

// Cancel ถ้าจำเป็น
debouncedAutoSave.cancel();
```

**ไฟล์ที่สร้าง:**
- `assets/javascripts/core/Debounce.js` - Debounce/throttle utility module

**ไฟล์ที่แก้ไข:**
- `graph_designer.js` - ใช้ debouncedAutoSave แทน TimerManager.set()
- `page/routing_graph_designer.php` - เพิ่ม script tag สำหรับ Debounce.js

**สถานะ:** ✅ Complete
- Debounce.js สร้างแล้ว (UMD format)
- อัปเดต scheduleAutoSave() ให้ใช้ debounce แล้ว
- มี fallback ถ้า module ไม่โหลด

---

### 3.2 Debug Flag System (DebugLogger)

**ปัญหา:**
```javascript
// ❌ console.log เยอะมากใน production (29+ จุดใน graph_designer.js)
console.log('Graph loaded:', graphId);
console.log('Save successful');
```

**แก้ไข:**
- สร้าง `DebugLogger.js` module ใน `assets/javascripts/core/` (UMD format)
- Methods: `log()`, `error()`, `warn()`, `info()`, `group()`, `groupEnd()`, `time()`, `timeEnd()`, `table()`
- Errors always logged (ไม่ขึ้นกับ debug flag)
- Logs only shown if `window.APP_DEBUG === true`

**การใช้งาน:**
```javascript
// ใช้แทน console.log
debugLogger.log('Graph loaded:', graphId);
debugLogger.group('Save Operation');
debugLogger.log('ETag:', currentETag);
debugLogger.groupEnd();

// Errors always logged
debugLogger.error('Save failed:', error);
```

**ไฟล์ที่สร้าง:**
- `assets/javascripts/core/DebugLogger.js` - Debug logging utility module

**ไฟล์ที่แก้ไข:**
- `page/routing_graph_designer.php` - เพิ่ม script tag สำหรับ DebugLogger.js

**สถานะ:** ✅ Complete
- DebugLogger.js สร้างแล้ว (UMD format)
- แทนที่ console.log/warn/error ทั้งหมดใน graph_designer.js ด้วย debugLogger แล้ว (60+ จุด)
- debugLogger จะแสดง log เฉพาะเมื่อ `window.APP_DEBUG === true`
- console.error จะแสดงเสมอ (errors always logged)
- มี fallback object ถ้า module ไม่โหลด

**ไฟล์ที่แก้ไข:**
- `graph_designer.js` - แทนที่ console.log/warn/error ทั้งหมดด้วย debugLogger
- `page/routing_graph_designer.php` - เพิ่ม script tag สำหรับ DebugLogger.js

---

### 3.3 Duplicate Toast Prevention

**ปัญหา:**
```javascript
// ❌ saveGraph เรียกซ้ำ → toast ซ้ำ 2-3 ครั้ง
notifySuccess('Saved!');
```

**แก้ไข:**
- อัปเดต `Toaster.js` เพื่อเพิ่ม duplicate prevention
- Features:
  - 2 seconds cooldown สำหรับ duplicate messages
  - Errors always shown (ไม่มีการป้องกัน duplicate)
  - Options: `allowDuplicate` flag สำหรับกรณีพิเศษ
- Methods: `success()`, `info()`, `warning()`, `error()`, `clear()`

**การใช้งาน:**
```javascript
// ป้องกัน duplicate อัตโนมัติ
Toaster.success('Saved!'); // จะไม่แสดงซ้ำภายใน 2 วินาที

// Force show duplicate (ถ้าจำเป็น)
Toaster.success('Saved!', 'Success', { allowDuplicate: true });

// Errors always shown
Toaster.error('Error occurred'); // แสดงเสมอ
```

**ไฟล์ที่แก้ไข:**
- `assets/javascripts/core/Toaster.js` - เพิ่ม duplicate prevention logic

**สถานะ:** ✅ Complete
- Toaster.js อัปเดตแล้ว (มี duplicate prevention)
- 2 seconds cooldown สำหรับ duplicate messages
- Errors always shown (ไม่มีการป้องกัน duplicate)

---

### 3.4 Async Validation

**ปัญหา:**
```javascript
// ❌ Validation run sync → freeze UI ถ้า data ใหญ่
const result = validateGraph();
```

**แก้ไข:**
```javascript
// สร้าง Async Validator
const AsyncValidator = {
    async validate(graphData) {
        // Show loading indicator
        this.showLoading();
        
        try {
            // Run validation in background
            const result = await this.runValidation(graphData);
            return result;
        } finally {
            this.hideLoading();
        }
    },
    
    async runValidation(graphData) {
        // Use Web Worker if available
        if (window.Worker) {
            return this.validateInWorker(graphData);
        } else {
            // Fallback to async setTimeout
            return new Promise((resolve) => {
                setTimeout(() => {
                    resolve(this.validateSync(graphData));
                }, 0);
            });
        }
    },
    
    validateSync(graphData) {
        // Existing validation logic
        return validateGraph(graphData);
    }
};

// ใช้แทน
const result = await AsyncValidator.validate(graphData);
```

**ไฟล์:** `graph_validator.js` (ใหม่)  
**ตำแหน่ง:** Validation logic

---

## 🔧 API Refactoring Plan

### 4.1 Naming Consistency

**ปัญหา:**
- `hatthasilpa.routing.*` (legacy)
- `dag.routing.*` (ใหม่)
- `routing_graph`, `routing_node`, `routing_edge` (ใหม่)

**แก้ไข:**

1. **สร้าง Migration สำหรับ Production Type:**
```sql
-- Migration: 2025_11_routing_graph_production_type.php
ALTER TABLE routing_graph 
ADD COLUMN production_type ENUM('hatthasilpa','classic','hybrid') 
DEFAULT 'classic' 
COMMENT 'Production line type: hatthasilpa (handcrafted), classic (OEM), hybrid';

-- Update existing records based on category
UPDATE routing_graph 
SET production_type = CASE 
    WHEN category = 'hatthasilpa' THEN 'hatthasilpa'
    WHEN category = 'oem' THEN 'classic'
    ELSE 'hybrid'
END 
WHERE production_type IS NULL;
```

2. **อัปเดต API Filter:**
```php
// ใน dag_routing_api.php
case 'graph_list':
    // Support both category (legacy) and production_type (new)
    $category = $_GET['category'] ?? null;
    $productionType = $_GET['production_type'] ?? $category; // Fallback to category
    
    if ($productionType) {
        $where[] = "production_type = ?";
        $params[] = $productionType;
        $types .= 's';
    }
```

**ไฟล์:** 
- Migration: `database/tenant_migrations/2025_11_routing_graph_production_type.php`
- API: `source/dag_routing_api.php`

---

### 4.2 Graph Category Filter Enhancement

**ปัญหา:**
- Filter ใช้ `category` แต่ DB ใช้ `production_type`
- ไม่มี field จริงในฐานข้อมูล

**แก้ไข:**

1. **เพิ่ม Column (ดู 4.1)**
2. **อัปเดต API:**
```php
// Support both for backward compatibility
$filters = [
    'category' => $_GET['category'] ?? null,
    'production_type' => $_GET['production_type'] ?? null,
    'status' => $_GET['status'] ?? null,
    'search' => $_GET['search'] ?? null
];

// Build WHERE clause
$where = [];
$params = [];
$types = '';

if ($filters['production_type'] || $filters['category']) {
    $productionType = $filters['production_type'] ?? $filters['category'];
    $where[] = "production_type = ?";
    $params[] = $productionType;
    $types .= 's';
}
```

**ไฟล์:** `source/dag_routing_api.php`  
**ตำแหน่ง:** `graph_list` action

---

### 4.3 Job Integration API

**ปัญหา:**
- ไม่มี API ที่ map `product_id → routing_graph_id`
- ไม่สามารถ trace "ต้นทางของสินค้า" ได้โดยอัตโนมัติ

**แก้ไข:**

1. **สร้าง API Endpoint:**
```php
// ใน dag_routing_api.php
case 'graph_by_product':
    $productId = (int)($_GET['product_id'] ?? 0);
    if ($productId <= 0) {
        json_error('Invalid product_id', 400);
    }
    
    // Get active binding
    $binding = $db->fetchOne("
        SELECT 
            pgb.id_graph,
            rg.code AS graph_code,
            rg.name AS graph_name,
            rg.status AS graph_status,
            pgb.graph_version_pin,
            pgb.default_mode
        FROM product_graph_binding pgb
        INNER JOIN routing_graph rg ON rg.id_graph = pgb.id_graph
        WHERE pgb.id_product = ?
            AND pgb.is_active = 1
            AND (pgb.effective_from <= NOW() OR pgb.effective_from IS NULL)
            AND (pgb.effective_until IS NULL OR pgb.effective_until >= NOW())
        ORDER BY pgb.priority DESC, pgb.effective_from DESC
        LIMIT 1
    ", [$productId], 'i');
    
    if (!$binding) {
        json_error('No active graph binding found for product', 404);
    }
    
    json_success(['binding' => $binding]);
    break;
```

2. **สร้าง Helper Function:**
```php
// ใน helper/ProductGraphBindingHelper.php
public static function getGraphForProduct(\mysqli $db, int $productId, ?string $mode = null): ?array {
    // Existing logic (already implemented)
    return self::getActiveBinding($db, $productId, $mode);
}
```

**ไฟล์:** 
- API: `source/dag_routing_api.php`
- Helper: `source/BGERP/Helper/ProductGraphBindingHelper.php`

---

### 4.4 Performance Optimization

**ปัญหา:**
- `graph_list` ยิง SQL หลายรอบ (5-9 queries)
- ไม่มี caching layer

**แก้ไข:**

1. **เพิ่ม Caching Layer:**
```php
// ใน dag_routing_api.php
case 'graph_list':
    // Check cache first
    $cacheKey = 'graph_list_' . md5(json_encode($_GET) . $org['code']);
    $cached = apcu_fetch($cacheKey);
    
    if ($cached !== false) {
        json_success($cached);
        return;
    }
    
    // ... existing query logic ...
    
    // Cache result (5 minutes)
    apcu_store($cacheKey, $result, 300);
    json_success($result);
    break;
```

2. **Optimize Queries:**
```php
// Combine multiple queries where possible
$graphs = $db->fetchAll("
    SELECT 
        rg.*,
        COUNT(DISTINCT rn.id_node) AS node_count,
        COUNT(DISTINCT re.id_edge) AS edge_count,
        MAX(rg.updated_at) AS last_modified
    FROM routing_graph rg
    LEFT JOIN routing_node rn ON rn.id_graph = rg.id_graph AND rn.deleted_at IS NULL
    LEFT JOIN routing_edge re ON re.id_graph = rg.id_graph AND re.deleted_at IS NULL
    WHERE rg.id_org = ?
    GROUP BY rg.id_graph
    ORDER BY rg.updated_at DESC
", [$org['id_org']], 'i');
```

**ไฟล์:** `source/dag_routing_api.php`  
**ตำแหน่ง:** `graph_list` action

---

### 4.5 Audit Log Verification

**ปัญหา:**
- `logRoutingAudit()` อ้างอิง `bgerp.account`
- ต้องตรวจสอบว่า table มีจริงหรือไม่

**แก้ไข:**

1. **ตรวจสอบ Schema:**
```php
// ใน dag_routing_api.php
function logRoutingAudit($db, $action, $graphId, $details = []) {
    // Verify core DB connection
    $coreDb = core_db();
    if (!$coreDb) {
        error_log('Cannot connect to core DB for audit logging');
        return;
    }
    
    // Check if account table exists
    $tableCheck = $coreDb->query("SHOW TABLES LIKE 'account'");
    if (!$tableCheck || $tableCheck->num_rows === 0) {
        error_log('Core DB account table not found - skipping audit log');
        return;
    }
    
    // ... existing audit log logic ...
}
```

2. **เพิ่ม Fallback:**
```php
// If account table doesn't exist, log to tenant DB instead
$actorName = 'System';
try {
    $actorStmt = $coreDb->prepare("SELECT name FROM bgerp.account WHERE id_member = ? LIMIT 1");
    if ($actorStmt) {
        $actorStmt->bind_param('i', $member['id_member']);
        $actorStmt->execute();
        $actorResult = $actorStmt->get_result();
        if ($actorRow = $actorResult->fetch_assoc()) {
            $actorName = $actorRow['name'];
        }
    }
} catch (\Exception $e) {
    error_log('Audit log: Cannot fetch actor name: ' . $e->getMessage());
    // Continue with default 'System'
}
```

**ไฟล์:** `source/dag_routing_api.php`  
**ตำแหน่ง:** `logRoutingAudit()` function

---

## ✅ Quality Gates & SLOs

### Service Level Objectives (SLOs)

**เป้าหมายเชิงบริการ:**

- **Availability (API DAG):** 99.9% ต่อเดือน
- **P95 API Latency:**
  - `graph_list` ≤ 200ms
  - `graph_get` ≤ 300ms
  - `graph_save` ≤ 500ms (ไม่รวม validation async)
- **Error Rate:** 5xx > 0.5% ถือว่า breach (trigger alert)

### Quality Gates

**ต้องผ่านก่อน merge/deploy:**

- ✅ **Unit tests** ≥ 80% coverage ในโมดูลที่แก้
- ✅ **E2E happy path:** Load → Edit → Auto-save → Manual save → Reload → ETag 304 ผ่าน
- ✅ **Doctor script:** 0 error, warning ยอมรับได้
- ✅ **Lint/Type check** ผ่านทั้งหมด (ESLint + PHP CodeSniffer/PSR-12)
- ✅ **API contract test** ผ่าน (schema/field/headers) ทุก endpoint ที่แตะ

---

## 📈 Observability & Telemetry

### Metrics (ต่อ endpoint)

**API Metrics:**
- `api.dag.graph_list.latency_ms` (p50/p95/p99)
- `api.dag.graph_save.latency_ms` และ `conflict_ratio` (412/200)
- `api.dag.graph_get.cache_hit` vs `cache_miss`
- `api.dag.graph_delete.conflict_ratio` (foreign key errors)

**UI Metrics:**
- `ui.graph.autosave.count`
- `ui.graph.autosave.fail`
- `ui.graph.save.manual.count`
- `ui.graph.validation.async.duration_ms`

**Database Metrics:**
- `db.routing_graph.query.count` (per request)
- `db.routing_graph.query.duration_ms`

### Logs

**Standard Headers (ทุก response):**
- `X-Correlation-Id`: Unique request ID
- `X-Tenant-Id`: Current tenant code
- `X-App-Version`: Application version
- `X-Request-Id`: Internal request tracking

**Log Levels:**
- **WARN:** เมื่อพบ soft-validate warnings
- **ERROR:** เมื่อ hard-validate fail หรือ 5xx errors
- **INFO:** Graph operations (create/update/delete)
- **DEBUG:** ETag matching, cache hits/misses

**Log Format:**
```json
{
  "timestamp": "2025-11-12T10:30:00+07:00",
  "level": "INFO",
  "correlation_id": "abc123",
  "tenant_id": "maison_atelier",
  "user_id": 1,
  "action": "graph_save",
  "graph_id": 42,
  "duration_ms": 245,
  "etag_match": true,
  "cache_hit": false
}
```

### Tracing (ถ้ามี)

**Spans:**
- `graph_load`: Loading graph from database
- `graph_validate`: Validation process
- `graph_save`: Save operation
- `graph_publish`: Publish operation

**Attributes:**
- `tenant`: Tenant code
- `graph_id`: Graph ID
- `nodes`: Node count
- `edges`: Edge count
- `etag_old`: Previous ETag
- `etag_new`: New ETag
- `conflict`: Boolean (true if 412)

---

## 🔒 Security & Privacy Hardening

### Permission Matrix

**Permissions:**
- `dag.routing.view`: View graphs (read-only)
- `dag.routing.manage`: Create/update/delete graphs
- `dag.routing.publish`: Publish graphs (make available for production)
- `dag.routing.diff.view`: View graph version differences
- `dag.routing.audit.view`: View audit logs

**Legacy Compatibility:**
- `hatthasilpa.routing.*` → Maps to `dag.routing.*` (backward compatible)

### Multi-tenant Isolation

**ทุก Query ต้อง:**
- Filter by `id_org` หรือ `tenant_id`
- Include tenant context in cache keys: `t{tenant}_graph_{id}`
- Validate tenant membership before operations

**Cache Key Format:**
```php
$cacheKey = sprintf('t%s_graph_%s_%s', 
    $tenantCode, 
    $graphId, 
    md5(json_encode($filters))
);
```

### Idempotency

**ทุก Create/Update สำคัญ:**
- รองรับ `Idempotency-Key` header
- Store key → response mapping (TTL: 24 hours)
- Return cached response if key exists

**Implementation:**
```php
$idempotencyKey = $_SERVER['HTTP_IDEMPOTENCY_KEY'] ?? null;
if ($idempotencyKey) {
    $cached = apcu_fetch("idempotency_{$idempotencyKey}");
    if ($cached !== false) {
        http_response_code(200);
        header('X-Idempotency-Replayed: true');
        echo $cached;
        return;
    }
}
// ... perform operation ...
if ($idempotencyKey) {
    apcu_store("idempotency_{$idempotencyKey}", $response, 86400);
}
```

### ETag / If-Match

**Conflict Detection:**
- ใช้ `If-Match` header สำหรับ conditional updates
- Return `412 Precondition Failed` เมื่อ ETag ไม่ match
- Include `ETag` header ในทุก response

**Client Handling:**
```javascript
$.ajax({
    url: 'source/dag_routing_api.php',
    type: 'POST',
    headers: {
        'If-Match': currentETag
    },
    success: function(response, textStatus, jqXHR) {
        const newETag = jqXHR.getResponseHeader('ETag');
        // Update stored ETag
    },
    error: function(jqXHR) {
        if (jqXHR.status === 412) {
            // Handle conflict: show dialog, reload, merge
        }
    }
});
```

### Input Validation

**Search Constraints:**
- Search string length ≤ 100 characters
- Block wildcard patterns: `%`, `_` (escape if needed)
- Sanitize special characters

**Graph Data Limits:**
- Max nodes per graph: 1,000
- Max edges per graph: 2,000
- Max node name length: 100 characters
- Max notes length: 5,000 characters

### Data Privacy

**Audit Log:**
- เก็บเฉพาะ metadata ที่จำเป็น
- ไม่เก็บ payload ลับลูกค้า (sensitive data)
- Encrypt audit logs if containing PII
- Retention: 90 days (configurable)

**Fields to Exclude from Audit:**
- Node positions (internal UI state)
- Large JSON payloads
- User passwords/tokens

---

## 🧪 CI/CD & Testing Matrix

### Pipelines

**Pipeline Stages:**
1. **Lint:** ESLint (JS) + PHP CodeSniffer (PHP)
2. **Unit Tests:** PHPUnit + Jest (if applicable)
3. **Integration Tests:** API endpoint tests
4. **Build:** Asset compilation, minification
5. **Doctor Script:** Health checks, schema validation
6. **Smoke Tests:** Basic happy path verification

### Testing Matrix

**Browsers (Desktop):**
- Chrome (latest)
- Safari (latest)
- Edge (latest)
- Firefox (latest) - optional

**Mobile:**
- iOS Safari (latest)
- Android Chrome (latest)

**Locales:**
- `th-TH`: Thai locale (date/time/number format)
- `en-US`: English locale (date/time/number format)

**Tenants:**
- `maison_atelier`: Primary tenant
- `default`: Secondary tenant (if available)

**Test Scenarios:**
- Graph CRUD operations
- Auto-save functionality
- ETag conflict handling
- Permission checks
- Multi-tenant isolation
- Product-graph binding

### Contract Tests

**JSON Schema (OpenAPI - แบบย่อ):**

**graph_list Response:**
```json
{
  "ok": true,
  "data": {
    "graphs": [
      {
        "id_graph": "integer",
        "code": "string",
        "name": "string",
        "status": "enum:draft,published,archived",
        "production_type": "enum:hatthasilpa,classic,hybrid",
        "node_count": "integer",
        "edge_count": "integer",
        "updated_at": "datetime"
      }
    ],
    "total": "integer",
    "page": "integer",
    "per_page": "integer"
  },
  "meta": {
    "etag": "string",
    "cache_control": "string"
  }
}
```

**graph_get Response:**
```json
{
  "ok": true,
  "data": {
    "graph": {
      "id_graph": "integer",
      "code": "string",
      "name": "string",
      "status": "string",
      "nodes": ["array"],
      "edges": ["array"]
    }
  },
  "meta": {
    "etag": "string"
  }
}
```

**Standard Headers:**
- `ETag`: Graph version identifier
- `Vary`: `Accept, Accept-Language`
- `Cache-Control`: `private, max-age=60`
- `X-Correlation-Id`: Request tracking ID
- `X-Tenant-Id`: Current tenant
- `X-App-Version`: Application version

---

## 🚀 Performance Budget & Benchmarks

### Frontend Performance

**Bundle Size:**
- Initial load bundle (`graph_designer` + modules) ≤ 300KB gzipped
- Lazy load modules when possible
- Code splitting for large features

**Auto-save:**
- Debounce ค่าเริ่มต้น ≥ 2.5s (config ปรับได้)
- Max debounce: 10s (prevent excessive saves)

**Validation:**
- ใช้ Web Worker สำหรับ validation เมื่อ nodes > 400
- Sync validation สำหรับ graphs เล็ก (< 100 nodes)

**Rendering:**
- Cytoscape canvas render ≤ 16ms per frame (60 FPS)
- Node/edge limit: 1,000 nodes, 2,000 edges (warn if exceeded)

### Backend Performance

**Query Optimization:**
- Query count ต่อ `graph_list` ≤ 3 (aggregated query + cache)
- Query count ต่อ `graph_get` ≤ 2 (graph + nodes/edges)

**Caching:**
- Redis/APCu cache TTL เริ่มต้น: 60–300s
- Granular invalidation: Invalidate by graph_id, tenant_id
- Cache key format: `t{tenant}_graph_{id}_{version}`

**Database Indexes:**

**routing_graph:**
```sql
INDEX idx_tenant_production_status_updated (
    id_org, 
    production_type, 
    status, 
    updated_at DESC
)
```

**product_graph_binding:**
```sql
INDEX idx_product_mode_active (
    id_product, 
    default_mode, 
    is_active, 
    effective_from, 
    effective_until
)
```

**routing_node:**
```sql
INDEX idx_graph_deleted (
    id_graph, 
    deleted_at
)
```

**routing_edge:**
```sql
INDEX idx_graph_deleted (
    id_graph, 
    deleted_at
)
```

### Benchmark Checklist

**Test Dataset:**
- 1,000 graphs
- 50,000 nodes (average 50 per graph)
- 80,000 edges (average 80 per graph)
- Synthetic data (generated)

**Performance Targets:**
- `graph_list` (100 graphs): < 200ms (p95)
- `graph_get` (50 nodes, 80 edges): < 300ms (p95)
- `graph_save` (50 nodes, 80 edges): < 500ms (p95)
- `graph_validate` (400 nodes): < 2s (p95)

**Concurrency Tests:**
- 20 concurrent editors → conflict ratio < 5%
- 100 concurrent `graph_list` requests → p95 < 500ms
- Auto-save collision handling → no data loss

---

## 🌈 Rollout Strategy & Feature Flags

### Feature Flags

**Existing Flags:**
- `PRODUCT_GRAPH_BINDING_ENABLED`: Enable product-graph binding feature
- `PRODUCT_GRAPH_BINDING_AUTO_SELECT`: Auto-select graph for products
- `PRODUCT_GRAPH_BINDING_CACHE_ENABLED`: Enable caching for bindings

**New Flags:**
- `GRAPH_VALIDATION_ASYNC`: Enable async validation (Web Worker)
- `GRAPH_AUTOSAVE_ENABLED`: Enable auto-save functionality
- `GRAPH_ETAG_ENABLED`: Enable ETag conflict detection
- `GRAPH_CACHE_ENABLED`: Enable API response caching

**Flag Configuration:**
```php
// config.php
define('GRAPH_VALIDATION_ASYNC', getFeatureFlag('graph_validation_async', false));
define('GRAPH_AUTOSAVE_ENABLED', getFeatureFlag('graph_autosave_enabled', true));
define('GRAPH_ETAG_ENABLED', getFeatureFlag('graph_etag_enabled', true));
define('GRAPH_CACHE_ENABLED', getFeatureFlag('graph_cache_enabled', true));
```

### Gradual Rollout

**Phase 1: Internal (Bellavier Team)**
- Enable all flags for internal users
- Monitor metrics, errors, performance
- Duration: 1 week

**Phase 2: Pilot Tenant (Atelier A)**
- Enable flags for single tenant
- Collect feedback, fix issues
- Duration: 1 week

**Phase 3: All Tenants**
- Enable flags globally
- Monitor closely for first 48 hours
- Duration: Ongoing

### Kill Switch

**Emergency Disable:**
- ปิดได้ทันทีโดยไม่กระทบ schema/data
- Flags can be toggled via admin panel or config
- Fallback to legacy behavior if flag disabled

**Implementation:**
```php
if (!GRAPH_AUTOSAVE_ENABLED) {
    // Disable auto-save, manual save only
    return;
}
```

### Compatibility

**Legacy Permissions:**
- รองรับ `hatthasilpa.routing.*` จนกว่าจะ deprecate
- Migration path: `hatthasilpa.routing.*` → `dag.routing.*`
- Deprecation notice: Show warning for legacy permissions

**Backward Compatibility:**
- API endpoints support both old and new formats
- Database schema changes are additive (no breaking changes)
- Frontend supports both old and new UI patterns

---

## 🧯 Risk Register & Backout Plan

### ความเสี่ยงหลัก

**1. Save Conflict สูงช่วงแรก**

**ความเสี่ยง:**
- Users อาจพบ 412 Precondition Failed บ่อย
- UX อาจไม่ชัดเจนว่าต้องทำอย่างไร

**Mitigation:**
- UX ชัดเจน: แสดงสาเหตุ + ปุ่ม reload/merge
- Auto-retry logic สำหรับ transient conflicts
- User education: แนะนำให้ save บ่อยขึ้น

**2. Query ช้าเมื่อกราฟใหญ่**

**ความเสี่ยง:**
- Graph with 500+ nodes อาจช้า
- UI freeze during validation

**Mitigation:**
- เปิด Web Worker สำหรับ validation
- เพิ่ม database indexes
- Implement caching layer
- Pagination สำหรับ large graphs

**3. Cross-tenant Cache Leak**

**ความเสี่ยง:**
- Cache key ไม่มี tenant prefix → data leak
- Security vulnerability

**Mitigation:**
- ทุก cache key ต้องมี prefix: `t{tenant}_`
- Validate tenant context in cache operations
- Audit cache keys regularly

**4. Module Separation Breaking Changes**

**ความเสี่ยง:**
- แบ่ง modules อาจทำให้ dependencies พัง
- Import/export errors

**Mitigation:**
- Test thoroughly before merge
- Use feature flags to toggle gradually
- Keep backward compatibility layer

### Backout Plan

**Scenario 1: Critical Bug Found**

**Steps:**
1. ปิด flags ทันที: `GRAPH_AUTOSAVE_ENABLED = false`
2. ปิด `PRODUCT_GRAPH_BINDING_AUTO_SELECT` ก่อน `ENABLED`
3. แจ้งทีมและ users
4. Investigate root cause
5. Fix and re-enable gradually

**Scenario 2: Performance Degradation**

**Steps:**
1. Disable caching: `GRAPH_CACHE_ENABLED = false`
2. Disable async validation: `GRAPH_VALIDATION_ASYNC = false`
3. Monitor performance metrics
4. Optimize queries/indexes
5. Re-enable features one by one

**Scenario 3: Data Corruption**

**Steps:**
1. ปิด flags ทั้งหมดทันที
2. Rollback code (แต่ไม่ rollback schema)
3. Restore from backup if needed
4. Investigate root cause
5. Fix and test thoroughly before re-deploy

**Cache Cleanup:**
```php
// Clear cache for specific scope
function clearGraphCache($tenantCode, $graphId = null) {
    $pattern = $graphId 
        ? "t{$tenantCode}_graph_{$graphId}_*"
        : "t{$tenantCode}_graph_*";
    
    // APCu
    $iterator = new APCuIterator('/^' . preg_quote($pattern, '/') . '/');
    foreach ($iterator as $key => $value) {
        apcu_delete($key);
    }
    
    // Redis (if used)
    if (class_exists('Redis')) {
        $redis = new Redis();
        $keys = $redis->keys($pattern);
        foreach ($keys as $key) {
            $redis->del($key);
        }
    }
}
```

**Schema Compatibility:**
- Schema changes are **additive only** (no breaking changes)
- New columns have default values
- Old code works with new schema
- New code works with old schema (graceful degradation)

---

## 🔗 System Integration Layer

### Integration Points

**1. Job Ticket System**

**Connection:**
- `routing_graph` → `job_ticket` (via `job_graph_instance`)
- Graph published → Available for job ticket creation
- Graph version pinned → Used in job ticket metadata

**Data Flow:**
```
routing_graph (published)
    ↓
product_graph_binding (active)
    ↓
job_ticket (created with graph_id)
    ↓
job_graph_instance (runtime execution)
```

**API Endpoints:**
- `job_ticket_api.php?action=create` → Auto-selects graph from `product_graph_binding`
- `job_ticket_api.php?action=get_graph` → Returns graph instance for job

**Integration Code:**
```php
// ใน job_ticket_api.php
case 'create':
    $productId = (int)($_POST['product_id'] ?? 0);
    
    // Get active graph binding
    $binding = ProductGraphBindingHelper::getActiveBinding(
        $tenantDb, 
        $productId, 
        $productionType
    );
    
    if ($binding) {
        $jobTicket['id_graph'] = $binding['id_graph'];
        $jobTicket['graph_version'] = $binding['graph_version_pin'] ?? 'latest';
    }
    break;
```

**ไฟล์:** `source/job_ticket_api.php`, `source/BGERP/Helper/ProductGraphBindingHelper.php`

---

**2. Product System**

**Connection:**
- `product` → `product_graph_binding` → `routing_graph`
- Product creation → Can bind to graph
- Product update → May trigger graph rebinding

**Data Flow:**
```
product (created/updated)
    ↓
product_graph_binding (created/updated)
    ↓
routing_graph (referenced)
```

**API Endpoints:**
- `products.php?action=graph_binding_save` → Create/update binding
- `products.php?action=graph_binding_get` → Get active binding
- `products.php?action=graph_preview` → Preview graph for product

**Integration Code:**
```php
// ใน products.php
case 'graph_binding_save':
    $productId = (int)($_POST['id_product'] ?? 0);
    $graphId = (int)($_POST['id_graph'] ?? 0);
    
    // Validate product exists
    $product = $db->fetchOne("SELECT * FROM product WHERE id_product = ?", [$productId], 'i');
    if (!$product) {
        json_error('Product not found', 404);
    }
    
    // Validate graph exists
    $graph = $db->fetchOne("SELECT * FROM routing_graph WHERE id_graph = ?", [$graphId], 'i');
    if (!$graph) {
        json_error('Graph not found', 404);
    }
    
    // Save binding
    $bindingId = saveProductGraphBinding($db, $productId, $graphId, $_POST);
    json_success(['id_binding' => $bindingId]);
    break;
```

**ไฟล์:** `source/products.php`

---

**3. People DB (Core Database)**

**Connection:**
- `bgerp.account` → `routing_graph` (via `created_by`, `updated_by`)
- `bgerp.account` → `routing_audit_log` (via `actor_id`)

**Data Flow:**
```
bgerp.account (user login)
    ↓
routing_graph (created/updated by user)
    ↓
routing_audit_log (logged with user_id)
```

**Integration Points:**
- User authentication → Resolve `id_member` from session
- Audit logging → Fetch user name from `bgerp.account`
- Permission checks → Validate user permissions

**Integration Code:**
```php
// ใน dag_routing_api.php
function logRoutingAudit($db, $action, $graphId, $details = []) {
    $coreDb = core_db();
    $member = $_SESSION['member'] ?? null;
    
    if ($member && $coreDb) {
        // Fetch user name from core DB
        $userStmt = $coreDb->prepare("SELECT name FROM bgerp.account WHERE id_member = ?");
        $userStmt->bind_param('i', $member['id_member']);
        $userStmt->execute();
        $userResult = $userStmt->get_result();
        $userName = $userResult->fetch_assoc()['name'] ?? 'Unknown';
        
        // Log to audit table
        $auditStmt = $db->prepare("
            INSERT INTO routing_audit_log 
            (action, id_graph, actor_id, actor_name, details, created_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ");
        $detailsJson = json_encode($details);
        $auditStmt->bind_param('siiss', $action, $graphId, $member['id_member'], $userName, $detailsJson);
        $auditStmt->execute();
    }
}
```

**ไฟล์:** `source/dag_routing_api.php`

---

**4. Work Queue System**

**Connection:**
- `routing_graph` → `flow_token` (via DAG execution)
- Graph nodes → Work queue tasks
- Graph edges → Task dependencies

**Data Flow:**
```
routing_graph (published)
    ↓
job_ticket (created)
    ↓
flow_token (spawned for each node)
    ↓
work_queue (tasks for operators)
```

**Integration Points:**
- Graph publish → Creates token templates
- Job ticket start → Spawns tokens from graph
- Node completion → Triggers next node tokens

**ไฟล์:** `source/hatthasilpa_jobs_api.php`, `source/assignment_plan_api.php`

---

## 📦 Data Retention & Archival Plan

### Audit Log Retention

**Retention Policy:**
- **Active logs:** 90 days (configurable)
- **Archived logs:** 180 days (read-only, compressed)
- **Permanent archive:** Critical operations only (publish, delete)

**Implementation:**
```php
// Scheduled job: archive_audit_logs.php
function archiveAuditLogs($db) {
    $cutoffDate = date('Y-m-d H:i:s', strtotime('-90 days'));
    
    // Archive old logs
    $archived = $db->execute("
        INSERT INTO routing_audit_log_archive
        SELECT * FROM routing_audit_log
        WHERE created_at < ?
    ", [$cutoffDate], 's');
    
    // Delete archived logs
    $db->execute("
        DELETE FROM routing_audit_log
        WHERE created_at < ?
    ", [$cutoffDate], 's');
    
    return $archived;
}
```

**Archive Table Schema:**
```sql
CREATE TABLE routing_audit_log_archive (
    -- Same structure as routing_audit_log
    -- Plus: archived_at DATETIME DEFAULT CURRENT_TIMESTAMP
    -- Compressed: Use COMPRESS() for details JSON
) ENGINE=InnoDB;
```

---

### Graph Version Archival

**Retention Policy:**
- **Published graphs:** Keep all versions (unlimited)
- **Draft graphs:** Keep last 10 versions per graph
- **Deleted graphs:** Soft delete, archive after 180 days

**Implementation:**
```php
// Cleanup old draft versions
function cleanupOldDraftVersions($db, $graphId, $keepCount = 10) {
    $versions = $db->fetchAll("
        SELECT id_version 
        FROM routing_graph_version
        WHERE id_graph = ? 
            AND status = 'draft'
        ORDER BY created_at DESC
    ", [$graphId], 'i');
    
    if (count($versions) > $keepCount) {
        $toDelete = array_slice($versions, $keepCount);
        $ids = array_column($toDelete, 'id_version');
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        
        // Archive before delete
        $db->execute("
            INSERT INTO routing_graph_version_archive
            SELECT * FROM routing_graph_version
            WHERE id_version IN ($placeholders)
        ", $ids, str_repeat('i', count($ids)));
        
        // Delete archived versions
        $db->execute("
            DELETE FROM routing_graph_version
            WHERE id_version IN ($placeholders)
        ", $ids, str_repeat('i', count($ids)));
    }
}
```

---

### Cache Data Rotation

**Cache TTL Strategy:**
- **Graph list:** 60 seconds (frequently accessed)
- **Graph detail:** 300 seconds (less frequently changed)
- **Product bindings:** 180 seconds (moderate change rate)
- **Validation results:** 30 seconds (frequently invalidated)

**Cache Invalidation:**
```php
function invalidateGraphCache($tenantCode, $graphId = null) {
    $patterns = [
        "t{$tenantCode}_graph_list_*",
        "t{$tenantCode}_graph_{$graphId}_*",
        "t{$tenantCode}_product_binding_*"
    ];
    
    foreach ($patterns as $pattern) {
        // APCu
        $iterator = new APCuIterator('/^' . preg_quote($pattern, '/') . '/');
        foreach ($iterator as $key => $value) {
            apcu_delete($key);
        }
        
        // Redis
        if (class_exists('Redis')) {
            $redis = new Redis();
            $keys = $redis->keys($pattern);
            foreach ($keys as $key) {
                $redis->del($key);
            }
        }
    }
}
```

---

### Data Rotation Schedule

**Daily:**
- Archive audit logs older than 90 days
- Cleanup old draft versions (keep last 10)

**Weekly:**
- Compress archived logs
- Optimize database tables
- Update statistics

**Monthly:**
- Review retention policies
- Generate retention reports
- Archive deleted graphs (180 days)

---

## 🗺️ Schema Dependency Map

### Visual Dependency Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Core Database (bgerp)                     │
├─────────────────────────────────────────────────────────────┤
│  account (id_member, name, email)                           │
│    ↑                                                         │
│    │ (created_by, updated_by, actor_id)                      │
└────┼─────────────────────────────────────────────────────────┘
     │
     │
┌────┼─────────────────────────────────────────────────────────┐
│    │         Tenant Database (bgerp_t_{tenant})              │
├────┼─────────────────────────────────────────────────────────┤
│    │                                                          │
│    ├──► routing_graph (id_graph, code, name, status)         │
│    │         │                                                 │
│    │         ├──► routing_node (id_node, id_graph, ...)      │
│    │         │         │                                        │
│    │         │         └──► routing_edge (from_node_id, ...)  │
│    │         │                                                  │
│    │         └──► routing_graph_version (id_version, ...)     │
│    │                                                             │
│    ├──► product (id_product, sku, name)                      │
│    │         │                                                  │
│    │         └──► product_graph_binding (id_binding, ...)      │
│    │                   │                                         │
│    │                   └──► routing_graph (id_graph)           │
│    │                                                             │
│    ├──► job_ticket (id_job_ticket, id_graph, ...)             │
│    │         │                                                  │
│    │         └──► job_graph_instance (id_instance, ...)       │
│    │                                                             │
│    └──► routing_audit_log (id_audit, id_graph, actor_id, ...) │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Foreign Key Relationships

**routing_graph:**
- `id_org` → `bgerp.organization.id_org`
- `created_by` → `bgerp.account.id_member`
- `updated_by` → `bgerp.account.id_member`

**routing_node:**
- `id_graph` → `routing_graph.id_graph` (CASCADE DELETE)
- `id_work_center` → `work_center.id_work_center`
- `assigned_to` → `bgerp.account.id_member`

**routing_edge:**
- `id_graph` → `routing_graph.id_graph` (CASCADE DELETE)
- `from_node_id` → `routing_node.id_node` (CASCADE DELETE)
- `to_node_id` → `routing_node.id_node` (CASCADE DELETE)

**product_graph_binding:**
- `id_product` → `product.id_product` (CASCADE DELETE)
- `id_graph` → `routing_graph.id_graph` (RESTRICT DELETE)
- `created_by` → `bgerp.account.id_member`

**job_ticket:**
- `id_graph` → `routing_graph.id_graph` (nullable)
- `id_mo` → `mo.id_mo` (nullable)

**routing_audit_log:**
- `id_graph` → `routing_graph.id_graph` (nullable, for deleted graphs)
- `actor_id` → `bgerp.account.id_member`

### Dependency Rules

**Cascade Delete:**
- Delete `routing_graph` → Deletes all `routing_node` and `routing_edge`
- Delete `routing_node` → Deletes all `routing_edge` connected to it
- Delete `product` → Deletes all `product_graph_binding`

**Restrict Delete:**
- Cannot delete `routing_graph` if `product_graph_binding` exists
- Must remove bindings first

**Nullable Foreign Keys:**
- `job_ticket.id_graph` (nullable) → Job can exist without graph
- `routing_audit_log.id_graph` (nullable) → Audit log persists after graph deletion

---

## 🔄 Failover Plan

### Database Failover

**Primary Database Failure:**

**Scenario:** Tenant database (`bgerp_t_{tenant}`) unavailable

**Failover Steps:**
1. **Detect failure:** Health check endpoint returns 503
2. **Switch to read-only mode:** Disable writes, enable read-only cache
3. **Alert team:** Send notification to ops team
4. **Failover to replica:** If available, switch to read replica
5. **Restore from backup:** If replica unavailable, restore from latest backup

**Implementation:**
```php
// ใน config.php
define('DB_FAILOVER_ENABLED', true);
define('DB_READ_REPLICA_HOST', 'replica.example.com');
define('DB_READ_REPLICA_PORT', 3306);

// ใน DatabaseHelper
function getTenantDb($tenantCode, $readOnly = false) {
    try {
        $db = connectToPrimary($tenantCode);
        return $db;
    } catch (\Exception $e) {
        if ($readOnly && DB_FAILOVER_ENABLED) {
            error_log("Primary DB failed, switching to replica: " . $e->getMessage());
            return connectToReplica($tenantCode);
        }
        throw $e;
    }
}
```

**Recovery Steps:**
1. Fix primary database
2. Sync data from replica (if available)
3. Verify data integrity
4. Switch back to primary
5. Monitor for 24 hours

---

### Cache Failover

**Redis/APCu Failure:**

**Scenario:** Cache layer unavailable

**Failover Steps:**
1. **Detect failure:** Cache operations return false/null
2. **Disable caching:** Set `GRAPH_CACHE_ENABLED = false`
3. **Continue operation:** System works without cache (slower)
4. **Alert team:** Notify ops team
5. **Restore cache:** Fix Redis/APCu, re-enable caching

**Implementation:**
```php
function getCache($key) {
    try {
        // Try APCu first
        $value = apcu_fetch($key);
        if ($value !== false) {
            return $value;
        }
        
        // Try Redis
        if (class_exists('Redis')) {
            $redis = new Redis();
            $redis->connect('127.0.0.1', 6379);
            $value = $redis->get($key);
            if ($value !== false) {
                return json_decode($value, true);
            }
        }
        
        return null;
    } catch (\Exception $e) {
        error_log("Cache failure: " . $e->getMessage());
        // Continue without cache
        return null;
    }
}
```

---

### Application Failover

**Multi-Server Deployment:**

**Scenario:** One application server fails

**Failover Steps:**
1. **Load balancer:** Automatically routes traffic to healthy servers
2. **Health check:** `/health` endpoint returns 200 OK
3. **Session persistence:** Use shared session storage (Redis/DB)
4. **Graceful shutdown:** Allow in-flight requests to complete

**Health Check Endpoint:**
```php
// source/platform_health_api.php
case 'check':
    $health = [
        'status' => 'ok',
        'database' => checkDatabase(),
        'cache' => checkCache(),
        'disk' => checkDiskSpace(),
        'memory' => checkMemory()
    ];
    
    $allHealthy = array_reduce($health, function($carry, $item) {
        return $carry && ($item === 'ok' || $item === true);
    }, true);
    
    http_response_code($allHealthy ? 200 : 503);
    json_success(['health' => $health]);
    break;
```

---

### Data Recovery

**Backup Strategy:**
- **Full backup:** Daily at 2 AM
- **Incremental backup:** Every 6 hours
- **Retention:** 30 days full, 7 days incremental

**Recovery Procedure:**
1. Identify last known good state
2. Restore from backup
3. Apply incremental backups up to failure point
4. Verify data integrity
5. Resume operations

---

## 🤖 AI Validation Hook Spec

### Smart Validation Architecture

**Purpose:** ให้ AI ตรวจ DAG ก่อน publish (Hatthasilpa Smart Validation)

**Integration Points:**
- Pre-publish validation hook
- Post-save suggestion engine
- Real-time linting suggestions

---

### Pre-Publish Validation Hook

**Trigger:** Before `graph_publish` action

**Validation Flow:**
```
graph_publish request
    ↓
Standard validation (DAGValidationService)
    ↓
AI Validation Hook (if enabled)
    ↓
AI analyzes graph structure
    ↓
Returns suggestions/warnings
    ↓
User reviews → Approve/Reject
    ↓
Publish or return to draft
```

**API Specification:**
```php
// ใน dag_routing_api.php
case 'graph_publish':
    // Standard validation first
    $validation = validateRoutingSchema($db, $graphId);
    if (!$validation['valid']) {
        json_error('Standard validation failed', 400, ['errors' => $validation['errors']]);
    }
    
    // AI validation hook (if enabled)
    if (getFeatureFlag('ai_validation_enabled', false)) {
        $aiValidation = validateGraphWithAI($graphId, $graphData);
        
        if (!$aiValidation['approved']) {
            // Return warnings/suggestions, but allow override
            json_error('AI validation warnings', 400, [
                'errors' => [],
                'warnings' => $aiValidation['warnings'],
                'suggestions' => $aiValidation['suggestions'],
                'allow_override' => true,
                'ai_confidence' => $aiValidation['confidence']
            ]);
        }
    }
    
    // Proceed with publish
    publishGraph($db, $graphId);
    break;
```

**AI Validation Function:**
```php
function validateGraphWithAI($graphId, $graphData) {
    // Prepare graph structure for AI
    $payload = [
        'graph_id' => $graphId,
        'nodes' => $graphData['nodes'],
        'edges' => $graphData['edges'],
        'metadata' => [
            'production_type' => $graphData['production_type'],
            'node_count' => count($graphData['nodes']),
            'edge_count' => count($graphData['edges'])
        ]
    ];
    
    // Call AI service (internal or external)
    $aiEndpoint = getConfig('ai_validation_endpoint', 'http://localhost:8000/validate');
    $response = http_post_json($aiEndpoint, $payload);
    
    return [
        'approved' => $response['approved'] ?? false,
        'confidence' => $response['confidence'] ?? 0.0,
        'warnings' => $response['warnings'] ?? [],
        'suggestions' => $response['suggestions'] ?? []
    ];
}
```

---

### AI Validation Criteria

**1. Graph Structure Analysis:**
- Check for optimal node ordering
- Identify potential bottlenecks
- Suggest parallelization opportunities
- Detect redundant nodes

**2. Production Best Practices:**
- Verify work center assignments
- Check team capacity alignment
- Validate QC checkpoints placement
- Ensure proper rework loops

**3. Performance Optimization:**
- Identify long sequential paths
- Suggest split/join optimizations
- Recommend caching strategies
- Flag potential deadlocks

**4. Compliance & Safety:**
- Verify required QC steps
- Check safety protocol compliance
- Validate documentation requirements
- Ensure audit trail completeness

---

### Post-Save Suggestion Engine

**Trigger:** After `graph_save` action

**Functionality:**
- Analyze saved graph
- Generate improvement suggestions
- Store in `routing_lint_suggestions` table
- Display in UI as "AI Suggestions" panel

**Implementation:**
```php
// Background job: generate_ai_suggestions.php
function generateAISuggestions($graphId) {
    $graphData = loadGraphData($graphId);
    
    // Call AI service
    $suggestions = callAIService('suggest', $graphData);
    
    // Store suggestions
    foreach ($suggestions as $suggestion) {
        $db->execute("
            INSERT INTO routing_lint_suggestions
            (id_graph, suggestion_type, message, confidence, created_at)
            VALUES (?, ?, ?, ?, NOW())
        ", [
            $graphId,
            $suggestion['type'], // 'optimization', 'best_practice', 'warning'
            $suggestion['message'],
            $suggestion['confidence']
        ]);
    }
}
```

---

### Real-time Linting

**Trigger:** During graph editing (debounced)

**Functionality:**
- Analyze current graph state
- Show inline suggestions
- Highlight potential issues
- Auto-fix simple problems

**Frontend Integration:**
```javascript
// ใน graph_designer.js
function requestAILinting(graphData) {
    if (!getFeatureFlag('ai_linting_enabled')) {
        return;
    }
    
    $.post('source/dag_routing_api.php', {
        action: 'ai_lint',
        graph_data: graphData
    }, function(response) {
        if (response.ok && response.data.suggestions) {
            displayLintSuggestions(response.data.suggestions);
        }
    });
}

// Debounced: call every 5 seconds during editing
const aiLintDebounced = debounce(() => {
    const graphData = exportGraphData();
    requestAILinting(graphData);
}, 5000);
```

---

### AI Service Configuration

**Feature Flags:**
- `AI_VALIDATION_ENABLED`: Enable AI validation hook
- `AI_LINTING_ENABLED`: Enable real-time linting
- `AI_SUGGESTIONS_ENABLED`: Enable post-save suggestions

**Configuration:**
```php
// config.php
define('AI_VALIDATION_ENABLED', getFeatureFlag('ai_validation_enabled', false));
define('AI_VALIDATION_ENDPOINT', getConfig('ai_validation_endpoint', 'http://localhost:8000/validate'));
define('AI_VALIDATION_TIMEOUT', 5); // seconds
define('AI_VALIDATION_CONFIDENCE_THRESHOLD', 0.7); // 70% confidence required
```

**Error Handling:**
- AI service timeout → Fallback to standard validation only
- AI service error → Log error, continue with standard validation
- Low confidence → Show as warnings, allow override

---

## 📅 Timeline & Milestones

### Week 1: Critical Fixes
- [ ] Day 1-2: Cytoscape exposure, Auto-save flags
- [ ] Day 3: Timer cleanup, ETag utility
- [ ] Day 4-5: Testing & bug fixes

### Week 2: Moderate Refactoring
- [ ] Day 1-2: Notification system (pending)
- [x] Day 1-2: Keyboard shortcuts & Event Manager (Completed 2025-11-12)
- [x] Day 3: State & History Manager (Completed 2025-11-12)
  - ✅ Created GraphHistoryManager.js (UMD) - Manages undo/redo stack
  - ✅ Created GraphStateManager.js (UMD) - Manages isModified flag
  - ✅ Updated graph_designer.js to use new modules
  - ✅ Added tests in test_phase2_1_modules.html
- [x] Day 4: Module separation - GraphLoader (Completed 2025-11-12)
  - ✅ Created GraphLoader.js (UMD) - Handles graph loading from API
  - ✅ Updated graph_designer.js to use GraphLoader module
  - ✅ Extracted handleGraphLoaded() for UI updates
  - ✅ Added fallback to direct AJAX if module not loaded
- [x] Day 5: Module separation - SafeJSON (Completed 2025-11-12)
  - ✅ Created SafeJSON.js (UMD) - Safe JSON parsing/stringifying utility
  - ✅ Updated graph_designer.js to use SafeJSON (30+ replacements)
  - ✅ Added fallback to JSON.parse/stringify if module not loaded
- [x] Day 6: GraphSaver Integration (Completed 2025-11-12)
  - ✅ Converted GraphAPI.js to UMD format
  - ✅ Integrated GraphSaver into graph_designer.js
  - ✅ Refactored saveGraph() to use GraphSaver (reduced from ~900 to ~150 lines)
  - ✅ Added handleVersionConflict() helper function
  - ✅ Added fallback to original implementation
- [x] Day 7: GraphValidator Integration (Completed 2025-11-12)
  - ✅ Integrated GraphValidator into graph_designer.js
  - ✅ Refactored validateGraph() to use GraphValidator (reduced from ~160 to ~20 lines)
  - ✅ Added fallback to original implementation
  - ✅ Added tests (10 tests - total 70 tests passing)
- [ ] Day 5: JSON helper, Testing

### Week 3: API Refactoring
- [ ] Day 1: Naming consistency, Production type migration
- [ ] Day 2: Graph category filter enhancement
- [ ] Day 3: Job integration API
- [ ] Day 4: Performance optimization
- [ ] Day 5: Audit log verification

### Week 4: Optional Improvements
- [ ] Day 1-2: Auto-save debounce, Debug flag
- [ ] Day 3: Duplicate toast prevention
- [ ] Day 4-5: Async validation (if time permits)

---

## ✅ Testing Checklist

### Frontend (graph_designer.js)
- [ ] Cytoscape instance creation/destruction
- [ ] Auto-save functionality
- [ ] Manual save functionality
- [ ] ETag handling
- [ ] Keyboard shortcuts
- [ ] Notifications (no duplicates)
- [ ] Graph loading/saving
- [ ] Validation display

### Backend (dag_routing_api.php)
- [ ] Graph CRUD operations
- [ ] Product-graph binding
- [ ] Graph list filtering (category/production_type)
- [ ] Performance (query count, caching)
- [ ] Audit logging
- [ ] Error handling

---

## 📝 Notes

1. **Backward Compatibility:** ทุกการเปลี่ยนแปลงต้องรองรับ legacy code
2. **Testing:** ทุก phase ต้องมี test coverage
3. **Documentation:** อัปเดต documentation ตามการเปลี่ยนแปลง
4. **Migration:** ต้องมี migration script สำหรับ database changes

---

## 🎯 Success Criteria

- [ ] Code duplication reduced by 60%+
- [ ] File size reduced (graph_designer.js < 2,000 lines)
- [ ] No breaking changes to existing functionality
- [ ] Performance improved (query count reduced by 40%+)
- [ ] All tests passing
- [ ] Documentation updated

---

**Last Updated:** 2025-11-12  
**Status:** 🟡 Planning Complete - Ready for Implementation

