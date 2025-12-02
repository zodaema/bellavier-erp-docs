# Job Ticket Pages Status Analysis

**Created:** November 15, 2025  
**Last Updated:** November 15, 2025  
**Purpose:** สำรวจสถานะของหน้า Job Ticket ทั้ง 3 หน้า และความสามารถในการสร้าง DAG Jobs  
**Status:** ✅ **IMPLEMENTATION COMPLETE** (November 14, 2025)

---

## 📋 Executive Summary

### **Key Findings (Updated - November 15, 2025):**

1. **`hatthasilpa_job_ticket` (หน้า Job Tickets):**
   - ✅ **รองรับ DAG mode แล้ว** - Phase 1 Complete
   - ✅ **DAG mode detection** - API และ UI ตรวจจับ `routing_mode='dag'` ได้ถูกต้อง
   - ✅ **Conditional UI** - ซ่อน Tasks table และ Import Routing สำหรับ DAG jobs
   - ✅ **DAG Info Panel** - แสดงข้อมูล DAG (Graph Name, Token Count) และ links
   - ✅ **Linear mode ยังทำงาน** - รองรับทั้ง Linear และ DAG mode
   - ⚠️ **ไม่สร้าง DAG jobs** - หน้าที่เป็น viewer เท่านั้น (ตาม design)

2. **`hatthasilpa_jobs` (หน้าสร้างงานหัตถศิลป์):**
   - ✅ **รองรับ DAG mode แล้ว** - Phase 2 Complete
   - ✅ **Auto-spawn tokens** - สร้าง tokens อัตโนมัติหลังสร้าง job
   - ✅ **Action Buttons** - Start/Pause/Cancel/Complete (Phase 2 เสร็จ)
   - ✅ **1-click workflow** - สร้าง job ticket + graph instance + tokens ในขั้นตอนเดียว
   - ✅ **Production-ready** - พร้อมใช้งานจริง

3. **`mo` (หน้า Manufacturing Orders):**
   - ✅ **รองรับ DAG mode แล้ว** - Phase 3 Complete
   - ✅ **Unified Services** - ใช้ `JobCreationService` และ `GraphInstanceService`
   - ✅ **Start Production workflow** - สร้าง graph instance + spawn tokens อัตโนมัติ
   - ✅ **OEM Production** - สำหรับงาน Mass Production / High Volume
   - ✅ **Production-ready** - Implementation สมบูรณ์

---

## 🔍 1. hatthasilpa_job_ticket (หน้า Job Tickets)

### **1.1 สถานะปัจจุบัน (Updated - November 15, 2025)**

**Files:**
- View: `views/hatthasilpa_job_ticket.php`
- API: `source/hatthasilpa_job_ticket.php`
- JavaScript: `assets/javascripts/hatthasilpa/job_ticket.js`

**Features ที่มี:**
- ✅ CRUD Job Tickets
- ✅ CRUD Tasks (`job_task`) - สำหรับ Linear mode
- ✅ Import Routing from Linear routing (`routing_step`)
- ✅ WIP Log management - สำหรับ Linear mode
- ✅ Task assignment
- ✅ Task status management
- ✅ **DAG mode detection** - Phase 1 Complete
- ✅ **Conditional UI** - ซ่อน/แสดง sections ตาม routing_mode
- ✅ **DAG Info Panel** - แสดงข้อมูล DAG และ links
- ✅ **URL parameter support** - Auto-load ticket detail จาก `?id=xxx`

**Role (ตาม JOB_TICKET_PAGES_RESTRUCTURING.md):**
- 📋 **Job Ticket Viewer/Manager** - ไม่ใช่ Job Creator
- ✅ สำหรับ Linear Jobs: แสดง task table, WIP Log, PWA Linear support
- ✅ สำหรับ DAG Jobs: แสดง DAG info panel, links to Token Management และ Work Queue
- ❌ **ไม่สร้าง DAG jobs** - ใช้ `mo` หรือ `hatthasilpa_jobs` แทน

---

### **1.2 Import Routing Feature (Updated - November 15, 2025)**

**API Endpoint:** `task_import_routing`

**Current Implementation:**
```php
// source/hatthasilpa_job_ticket.php
case 'task_import_routing':
    // Phase 4: Check routing_mode first
    if ($detected_mode === 'dag' || $graph_instance_id !== null) {
        json_error('Cannot import routing for DAG mode jobs', 400);
        return;
    }
    // 1. Get product ID from ticket
    // 2. Find Linear routing (routing_step table)
    // 3. Create job_task from routing_step
    // ✅ Only works for Linear mode (by design)
```

**Flow:**
1. User clicks "Import from Routing" button
2. **Phase 4:** System checks `routing_mode` - ถ้าเป็น DAG จะ reject
3. System looks up `routing` table (Linear routing)
4. Gets `routing_step` records
5. Creates `job_task` records from steps
6. ✅ **Works correctly:** Only for Linear mode (by design)

**UI Location:**
- Button: `#btn-import-routing` in `views/hatthasilpa_job_ticket.php:283`
- Modal: `#routingModal` (shows routing steps for selection)
- ✅ **Hidden for DAG jobs** - Phase 1 Complete

**Design Decision:**
- ✅ Only imports from `routing_step` (Linear routing) - **By design**
- ✅ Rejects DAG mode jobs - **By design** (ตาม Non-Goals)
- ✅ DAG jobs ต้องสร้างผ่าน `mo` หรือ `hatthasilpa_jobs` เท่านั้น

---

### **1.3 DAG Mode Support (Updated - November 15, 2025)**

**Status:** ✅ **IMPLEMENTED** (Phase 1 Complete)

**What's Implemented:**

1. **DAG Mode Detection:**
   - ✅ API detects `routing_mode` from `graph_instance_id`
   - ✅ Returns `routing_mode`, `graph_instance_id_actual`, `graph_name`, `token_count`
   - ✅ Conditional loading: Tasks/Logs สำหรับ Linear เท่านั้น

2. **UI Indicators:**
   - ✅ DAG Info Panel - แสดง Graph Name, Token Count
   - ✅ Links to Token Management และ Work Queue
   - ✅ Tasks table ซ่อนสำหรับ DAG jobs
   - ✅ Import Routing button ซ่อนสำหรับ DAG jobs
   - ✅ Add Task button ซ่อนสำหรับ DAG jobs

3. **Design Decision (ตาม Non-Goals):**
   - ❌ **ไม่สร้าง Graph Instance** - ตาม design (ใช้ `mo` หรือ `hatthasilpa_jobs`)
   - ❌ **ไม่ spawn Tokens** - ตาม design (หน้าที่เป็น viewer เท่านั้น)
   - ✅ **Clear separation** - DAG creation ต้องผ่าน `mo` หรือ `hatthasilpa_jobs`

**Files Modified:**
- `source/hatthasilpa_job_ticket.php` - Added routing_mode detection
- `assets/javascripts/hatthasilpa/job_ticket.js` - Added conditional UI logic

---

### **1.4 Impact on PWA Testing (Updated - November 15, 2025)**

**Status:** ✅ **RESOLVED**

**Solution:**
- ✅ ใช้ `hatthasilpa_jobs` สำหรับสร้าง DAG jobs (Atelier)
- ✅ ใช้ `mo` สำหรับสร้าง DAG jobs (OEM/Mass Production)
- ✅ `hatthasilpa_job_ticket` เป็น viewer เท่านั้น (ตาม design)

**Workflow for PWA Testing:**
```
Option A (Atelier):
1. ไปที่ hatthasilpa_jobs
2. Create & Start Production
3. Tokens spawned automatically
4. Ready for Work Queue testing

Option B (OEM):
1. ไปที่ mo
2. Create MO → Plan → Start Production
3. Tokens spawned automatically
4. Ready for PWA testing
```

**Viewing DAG Jobs:**
- ✅ ใช้ `hatthasilpa_job_ticket` เพื่อดู DAG job details
- ✅ DAG Info Panel แสดงข้อมูลครบถ้วน
- ✅ Links to Token Management และ Work Queue ทำงานถูกต้อง

---

## 🔍 2. hatthasilpa_jobs (หน้าสร้างงานหัตถศิลป์)

### **2.1 สถานะปัจจุบัน**

**Files:**
- View: `views/hatthasilpa_jobs.php`
- API: `source/hatthasilpa_jobs_api.php`
- JavaScript: `assets/javascripts/hatthasilpa/jobs.js`
- Page: `page/hatthasilpa_jobs.php`

**Purpose:**
- 1-click workflow สำหรับสร้างงานหัตถศิลป์
- Volume: 10-50 pieces (max 100)
- MO: Optional
- Schedule: Flexible

**Features ที่มี:**
- ✅ List Hatthasilpa Jobs (DataTable)
- ✅ Create Job Ticket from Product + Template
- ✅ **Auto-create Graph Instance** (`job_graph_instance`)
- ✅ **Auto-spawn Tokens** (via `TokenLifecycleService`)
- ✅ **Auto-assign Tokens** (optional)
- ✅ Product selection
- ✅ Template (Graph) selection

---

### **2.2 Create Job Workflow**

**API Endpoint:** `create_and_start` (in `hatthasilpa_jobs_api.php`)

**Flow:**
```php
// source/hatthasilpa_jobs_api.php
case 'create_and_start':
    1. Create job_ticket (production_type='hatthasilpa')
    2. Create job_graph_instance (from routing_graph)
    3. Update job_ticket.graph_instance_id
    4. Create node_instances (from routing_node)
    5. Spawn tokens (via TokenLifecycleService)
    6. Auto-assign tokens (optional)
    7. Return success
```

**UI Flow:**
1. User clicks "New Hatthasilpa Job"
2. Selects Product
3. Selects Template (Graph)
4. Enters Job Name, Quantity, Due Date
5. Clicks "Create & Start Production"
6. System creates everything automatically

**Auto-Actions (as per UI):**
- ✅ Spawn tokens with serial numbers
- ✅ Create graph instance from template
- ✅ Queue for assignment (optional auto-assign)
- ✅ Ready for Work Queue!

---

### **2.3 DAG Mode Support**

**Status:** ✅ **FULLY SUPPORTED**

**Evidence:**
- Creates `job_graph_instance` automatically
- Links `routing_graph` → `job_graph_instance`
- Creates `node_instance` records
- Spawns `flow_token` records
- Sets `routing_mode='dag'` (implicitly via graph_instance_id)

**Code Location:**
- `source/hatthasilpa_jobs_api.php:200-500` (create_and_start handler)

---

### **2.4 Status (Updated - November 15, 2025)**

**Status:** ✅ **PRODUCTION READY** (Phase 2 Complete)

**1. Graph Instance Creation:**
```php
// Uses JobCreationService::createDAGJob()
// ✅ Unified service (Phase 3 Complete)
// ✅ Uses GraphInstanceService internally
```

**2. Token Spawning:**
```php
// Uses TokenLifecycleService::spawnTokens()
// ✅ Works correctly
// ✅ Integrated with JobCreationService
```

**3. Action Buttons:**
- ✅ Start Production - API endpoint implemented
- ✅ Pause Job - API endpoint implemented
- ✅ Cancel Job - API endpoint implemented
- ✅ Complete Job - API endpoint implemented
- ✅ JavaScript handlers implemented
- ✅ UI panel shows/hides based on status

**4. Serial Number Generation:**
- ✅ Uses UnifiedSerialService (if enabled)
- ✅ Falls back to simple serial generation
- ✅ Format: `{prefix}-{sequence}`

**5. Error Handling:**
- ✅ Transaction rollback on errors
- ✅ Proper error messages
- ✅ Status validation before actions

**6. UI Completeness:**
- ✅ All UI elements work correctly
- ✅ Error messages display correctly
- ✅ Success messages display correctly
- ✅ Action panel shows/hides correctly

---

## 📊 Comparison Table (Updated - November 15, 2025)

| Feature | hatthasilpa_job_ticket | hatthasilpa_jobs | mo |
|---------|----------------------|------------------|-----|
| **Role** | Viewer/Manager | Job Creator (Atelier) | Job Creator (OEM) |
| **Create Job Ticket** | ✅ | ✅ | ✅ |
| **Linear Mode Support** | ✅ | ❌ (DAG only) | ❌ (DAG only) |
| **DAG Mode Support** | ✅ (Viewer) | ✅ (Creator) | ✅ (Creator) |
| **DAG Mode Detection** | ✅ | ✅ | ✅ |
| **DAG Info Panel** | ✅ | ❌ (N/A) | ❌ (N/A) |
| **Import Linear Routing** | ✅ | ❌ | ❌ |
| **Create Graph Instance** | ❌ (By design) | ✅ | ✅ |
| **Spawn Tokens** | ❌ (By design) | ✅ | ✅ |
| **Action Buttons** | ❌ (N/A) | ✅ | ✅ |
| **Task Management** | ✅ (Linear only) | ❌ | ❌ |
| **WIP Log Management** | ✅ (Linear only) | ❌ | ❌ |
| **Unified Services** | ❌ (N/A) | ✅ | ✅ |
| **UI Completeness** | ✅ | ✅ | ✅ |
| **Production Ready** | ✅ | ✅ | ✅ |

---

## 🎯 Recommendations (Updated - November 15, 2025)

### **Status: ✅ IMPLEMENTATION COMPLETE**

**All Priority 1-3 tasks completed:**

### **✅ Priority 1: DAG Mode Support in hatthasilpa_job_ticket** - **COMPLETE**

**What Was Implemented:**

1. **DAG Mode Detection:**
   - ✅ API detects `routing_mode` from `graph_instance_id`
   - ✅ Returns DAG-specific data (graph_name, token_count)

2. **Conditional UI:**
   - ✅ DAG Info Panel - แสดง Graph Name, Token Count, Links
   - ✅ Hide Tasks table สำหรับ DAG jobs
   - ✅ Hide Import Routing button สำหรับ DAG jobs
   - ✅ Hide Add Task button สำหรับ DAG jobs

3. **Design Decision:**
   - ✅ ไม่สร้าง DAG jobs ในหน้านี้ (ตาม Non-Goals)
   - ✅ ใช้ `hatthasilpa_jobs` หรือ `mo` สำหรับสร้าง DAG jobs
   - ✅ หน้าที่เป็น viewer เท่านั้น (ตาม design)

**Status:** ✅ Complete (Phase 1)

---

### **✅ Priority 2: hatthasilpa_jobs Action Buttons** - **COMPLETE**

**What Was Implemented:**

1. **Action Panel UI:**
   - ✅ Action panel HTML added
   - ✅ Shows Start/Pause/Cancel/Complete buttons
   - ✅ Status badge display
   - ✅ Conditional show/hide based on status

2. **API Endpoints:**
   - ✅ `start_production` - Start job
   - ✅ `pause_job` - Pause job
   - ✅ `cancel_job` - Cancel job
   - ✅ `complete_job` - Complete job

3. **JavaScript Handlers:**
   - ✅ Event handlers for all action buttons
   - ✅ Status validation
   - ✅ UI updates after actions
   - ✅ Table refresh after actions

**Status:** ✅ Complete (Phase 2)

---

### **✅ Priority 3: Unified Services (MO + hatthasilpa_jobs)** - **COMPLETE**

**What Was Implemented:**

1. **GraphInstanceService:**
   - ✅ Created `source/BGERP/Service/GraphInstanceService.php`
   - ✅ Unified graph instance creation
   - ✅ Node instance creation
   - ✅ Uses DatabaseHelper

2. **JobCreationService:**
   - ✅ Created `source/BGERP/Service/JobCreationService.php`
   - ✅ Unified DAG job creation
   - ✅ Creates job_ticket + graph_instance + tokens
   - ✅ Used by both MO and hatthasilpa_jobs

3. **Integration:**
   - ✅ MO uses `JobCreationService`
   - ✅ hatthasilpa_jobs uses `JobCreationService`
   - ✅ Identical job structure output
   - ✅ Consistent token spawning

**Status:** ✅ Complete (Phase 3)

### **✅ Priority 4: Cleanup** - **COMPLETE**

**What Was Implemented:**

1. **task_import_routing Protection:**
   - ✅ Rejects DAG mode jobs
   - ✅ Clear error message
   - ✅ Prevents accidental conversion

2. **Documentation:**
   - ✅ Updated JOB_TICKET_PAGES_RESTRUCTURING.md
   - ✅ Updated BROWSER_TEST_RESULTS.md
   - ✅ Clear role separation documented

**Status:** ✅ Complete (Phase 4)

---

## 📝 Implementation Checklist (Updated - November 15, 2025)

### **For hatthasilpa_job_ticket:** ✅ **COMPLETE**

- [x] Add DAG mode detection in API
- [x] Add conditional UI logic in JavaScript
- [x] Hide Tasks table for DAG jobs
- [x] Hide Import Routing button for DAG jobs
- [x] Add DAG info panel
- [x] Add links to Token Management and Work Queue
- [x] Update `task_import_routing` to reject DAG mode
- [x] Test with Linear jobs (should show tasks)
- [x] Test with DAG jobs (should show DAG panel)
- [x] Update documentation

**Status:** ✅ Phase 1 Complete (November 14, 2025)

### **For hatthasilpa_jobs:** ✅ **COMPLETE**

- [x] Add action panel UI
- [x] Add `start_production` API endpoint
- [x] Add `pause_job` API endpoint
- [x] Add `cancel_job` API endpoint
- [x] Add `complete_job` API endpoint
- [x] Add JavaScript handlers for action buttons
- [x] Verify graph instance creation works (via JobCreationService)
- [x] Verify token spawning works
- [x] Test error handling
- [x] Verify UI completeness
- [x] Test end-to-end workflow

**Status:** ✅ Phase 2 Complete (November 14, 2025)

### **For mo:** ✅ **COMPLETE**

- [x] Update to use JobCreationService
- [x] Verify start_production workflow works
- [x] Verify graph instance creation works (via unified service)
- [x] Verify token spawning works
- [x] Verify MO → Job Ticket inheritance
- [x] Test error handling and rollback
- [x] Verify product graph binding integration

**Status:** ✅ Phase 3 Complete (November 14, 2025)

---

## 🔗 Related Files

### **hatthasilpa_job_ticket:**
- `views/hatthasilpa_job_ticket.php` - UI
- `source/hatthasilpa_job_ticket.php` - API (1865 lines)
- `assets/javascripts/hatthasilpa/job_ticket.js` - Frontend logic

### **hatthasilpa_jobs:**
- `views/hatthasilpa_jobs.php` - UI
- `source/hatthasilpa_jobs_api.php` - API
- `assets/javascripts/hatthasilpa/jobs.js` - Frontend logic
- `page/hatthasilpa_jobs.php` - Page definition

### **mo:**
- `views/mo.php` - UI
- `source/mo.php` - API (975+ lines)
- `assets/javascripts/mo/mo.js` - Frontend logic
- `page/mo.php` - Page definition

### **Related Services:**
- `source/BGERP/Service/TokenLifecycleService.php` - Token spawning
- `source/BGERP/Service/DAGRoutingService.php` - DAG routing
- `source/dag_token_api.php` - Token operations

---

## ✅ Conclusion (Updated - November 15, 2025)

### **Current State:**

1. **hatthasilpa_job_ticket:**
   - ✅ **DAG mode viewer** - Phase 1 Complete
   - ✅ Works for Linear mode (tasks, WIP logs)
   - ✅ Works for DAG mode (DAG info panel, links)
   - ✅ **Role:** Job Ticket Viewer/Manager (ไม่ใช่ Creator)
   - ✅ **Production-ready** - พร้อมใช้งานจริง

2. **hatthasilpa_jobs:**
   - ✅ **Can create DAG jobs** - Phase 2 Complete
   - ✅ **Action buttons** - Start/Pause/Cancel/Complete
   - ✅ **1-click workflow** - Create + Start Production
   - ✅ **Production-ready** - พร้อมใช้งานจริง
   - ✅ **Role:** Atelier Job Creator (DAG only)

3. **mo:**
   - ✅ **Can create DAG jobs** - Phase 3 Complete
   - ✅ **Unified services** - Uses JobCreationService
   - ✅ **Production-ready** - Complete implementation
   - ✅ **OEM Production** - For Mass Production use cases
   - ✅ **Role:** OEM Job Creator (DAG only)

### **Implementation Status:**

**Phase 1-5: ✅ 100% COMPLETE** (November 14, 2025)

- ✅ Phase 1: Detection & UI (hatthasilpa_job_ticket)
- ✅ Phase 2: Action Buttons (hatthasilpa_jobs)
- ✅ Phase 3: Standardization (MO + hatthasilpa_jobs)
- ✅ Phase 4: Cleanup (hatthasilpa_job_ticket)
- ✅ Phase 5: Testing (All tests passing)

**Test Results:**
- ✅ Automated tests: 17/17 passed
- ✅ Browser tests: All verified
- ✅ See `BROWSER_TEST_RESULTS.md` for details

### **Usage Guide:**

**For Atelier Jobs:**
1. ไปที่ `hatthasilpa_jobs`
2. Create & Start Production
3. Tokens spawned automatically
4. View in `hatthasilpa_job_ticket` (DAG info panel)

**For OEM Jobs:**
1. ไปที่ `mo`
2. Create MO → Plan → Start Production
3. Tokens spawned automatically
4. View in `hatthasilpa_job_ticket` (DAG info panel)

**For Viewing Jobs:**
- ใช้ `hatthasilpa_job_ticket` เพื่อดู details
- Linear jobs: แสดง tasks, WIP logs
- DAG jobs: แสดง DAG info panel, links

### **Architecture:**

**Canonical Roles (ตาม JOB_TICKET_PAGES_RESTRUCTURING.md):**
- `mo` = OEM Job Creator (DAG mode)
- `hatthasilpa_jobs` = Atelier Job Creator (DAG mode)
- `hatthasilpa_job_ticket` = Job Viewer/Manager (Linear + DAG)

**Unified Services:**
- `GraphInstanceService` - Graph instance creation
- `JobCreationService` - Complete DAG job creation
- Both MO and hatthasilpa_jobs use same services

**Status:** ✅ **PRODUCTION READY**

---

**Last Updated:** November 15, 2025  
**Status:** ✅ **IMPLEMENTATION COMPLETE** (November 14, 2025)  
**Completion:** Phase 1-5 Complete (100%)  
**Test Status:** ✅ All tests passing (17/17 automated, browser tests verified)  
**Next:** Ready for Phase 2 (DAG Implementation Roadmap)

