# Manager Assignment Refactor Plan
## Phase 2B.5: Hatthasilpa-Only Assignment System

**Version:** 1.7  
**Date:** December 2025  
**Priority:** CRITICAL (UX blocker)  
**Duration:** 8-10 hours (Phase 1-5: Complete - Implementation done, API refactor complete, browser tests passed)

---

## 📚 Existing Infrastructure Analysis

### **APIs & Services ที่มีอยู่แล้ว**

#### **1. assignment_api.php** (Token Assignment API)
- **Purpose:** Manager-Operator assignment workflow
- **Permission:** `hatthasilpa.job.assign`
- **Key Endpoints:**
  - `get_active_jobs` (Line 84-133) - List jobs with unassigned tokens
  - `get_unassigned_tokens` (Line 135-260) - List unassigned tokens by node/job
- **Current Issues:**
  - ❌ ไม่ filter `production_type` (แสดง Classic/OEM ด้วย)
  - ❌ ไม่ filter `node_type` (แสดง start/split/join/wait/decision/system)
  - ❌ Token query: `jt.status IN ('planned', 'in_progress')` (ควรเป็น `in_progress`/`active` เท่านั้น)
  - ❌ Token query: `t.status = 'active'` (ควรเป็น `IN ('ready', 'active', 'waiting', 'paused')`)

#### **2. assignment_plan_api.php** (Assignment Plan & Pin API)
- **Purpose:** Manage assignment plans for automatic token assignment
- **Permission:** `manager.assignment`
- **Key Endpoints:**
  - `plan_job_list` (Line 487-556) - List job-level plans
  - `plan_job_save` (Line 558-619) - Save job-level plan (UPSERT)
  - `plan_job_delete` (Line 621+) - Delete job-level plan
  - `plan_preview` (Line 384-485) - Preview assignment simulation
- **Data Model:**
  - Table: `assignment_plan_job` (EXISTS)
  - Fields: `id_job_ticket`, `id_node`, `assignee_type`, `assignee_id`, `priority`, `active`
  - UNIQUE KEY: `(id_job_ticket, id_node, assignee_type, assignee_id)`
- **Status:** ✅ Ready to use (แต่ต้อง filter nodes: operation/qc only)

#### **3. AssignmentResolverService.php** (Assignment Resolution Engine)
- **Purpose:** Resolve token assignments using precedence: PIN > PLAN > AUTO
- **Key Methods:**
  - `resolveAssignment($tokenId, $nodeId, $context)` - Main resolution logic
  - `checkPIN($nodeId, $jobId, $context)` - Check PIN assignments
  - `checkPLAN($nodeId, $jobId)` - Check PLAN assignments (Line 285-350)
- **PLAN Resolution Logic:**
  - 1. Check `assignment_plan_node` (node-level, global)
  - 2. Check `assignment_plan_job` (job-level, Line 319-347)
  - Query: `WHERE job_id = ?` (⚠️ ใช้ `job_id` ไม่ใช่ `id_job_ticket`)
- **Status:** ✅ Ready to use (แต่ต้องตรวจสอบ column name: `job_id` vs `id_job_ticket`)

#### **4. AssignmentEngine.php** (Legacy Assignment Engine)
- **Purpose:** Auto-assignment on token spawn
- **Key Methods:**
  - `assignOne($db, $tokenId, $nodeId)` - Assign single token
  - `autoAssignOnSpawn($db, $tokenIds)` - Bulk assign on spawn
- **Status:** ✅ Ready to use (แต่ต้อง skip START nodes)

#### **5. NodeAssignmentService.php** (Node-Level Assignment Service)
- **Purpose:** Pre-assignment of operators to nodes for specific job instances
- **Table:** `node_assignment` (instance-level, runtime)
- **Status:** ⚠️ Different from `assignment_plan_job` (plan-level, pre-job)
- **Phase 2B.5 Scope:** 
  - **NOT modified in this phase** - Focuses on PLAN-level (`assignment_plan_job`) only
  - `NodeAssignmentService` remains as runtime layer and will be integrated in a later phase
  - Current runtime assignments continue to work as-is

### **Database Tables**

#### **assignment_plan_job** (EXISTS)
```sql
CREATE TABLE assignment_plan_job (
    id_plan_job INT AUTO_INCREMENT PRIMARY KEY,
    id_job_ticket INT NOT NULL,  -- Job Ticket ID
    id_node INT NOT NULL,         -- Node ID (operation/qc only)
    assignee_type ENUM('member', 'team') NOT NULL,
    assignee_id INT NOT NULL,     -- Member ID or Team ID
    priority TINYINT DEFAULT 1,    -- Lower = higher priority
    active TINYINT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_job_node_assignee (id_job_ticket, id_node, assignee_type, assignee_id),
    KEY idx_job_node (id_job_ticket, id_node, active)
);
```

#### **assignment_plan_node** (EXISTS - Global Routing Graph Level)
```sql
CREATE TABLE assignment_plan_node (
    id_plan INT AUTO_INCREMENT PRIMARY KEY,
    id_graph INT NOT NULL,        -- Routing Graph ID (global)
    id_node INT NOT NULL,         -- Node ID
    assignee_type ENUM('member', 'team') NOT NULL,
    assignee_id INT NOT NULL,
    priority TINYINT DEFAULT 10,
    active TINYINT DEFAULT 1,
    ...
);
```

### **Assignment Precedence (จาก AssignmentResolverService)**

```
1. PIN (Highest Priority)
   ├─ Node-level PIN (assignment_plan_node)
   └─ Job-level PIN (assignment_plan_job)

2. PLAN
   ├─ Node-level PLAN (assignment_plan_node)
   └─ Job-level PLAN (assignment_plan_job) ← ใช้ใน Tab Plans

3. AUTO (Lowest Priority)
   └─ Auto-assign using team_category, availability, load balancing
```

### **⚠️ Critical Findings**

1. **Column Name Mismatch (CRITICAL - Must Fix):**
   - `AssignmentResolverService::checkPLAN()` ใช้ `job_id` (Line 327)
   - แต่ `assignment_plan_job` table ใช้ `id_job_ticket`
   - **Impact:** Job-level PLAN assignments may not work correctly
   - **Action Required:** 
     - Verify actual column name in `assignment_plan_job` table
     - Update `AssignmentResolverService::checkPLAN()` to use correct column name (`id_job_ticket`)
     - Add to Phase 3 checklist (see Phase 3.7 below)

2. **Node Filtering Missing:**
   - `assignment_plan_api.php::plan_job_list` ไม่ filter `node_type`
   - ต้องเพิ่ม: `AND n.node_type IN ('operation', 'qc')`

3. **Token Status Filter:**
   - `assignment_api.php::get_unassigned_tokens` ใช้ `t.status = 'active'` เท่านั้น
   - ต้องเปลี่ยนเป็น: `t.status IN ('ready', 'active', 'waiting', 'paused')`

4. **Job Status Filter:**
   - `assignment_api.php::get_unassigned_tokens` ใช้ `jt.status IN ('planned', 'in_progress')`
   - ต้องเปลี่ยนเป็น: `jt.status IN ('in_progress', 'active')` เท่านั้น
   - **Note:** `in_progress` is the primary running status. `active` may exist in legacy code but should be treated as equivalent to `in_progress` for this phase. Future refactor should consolidate to one value.

5. **Status Naming Convention:**
   - **Primary Status:** `in_progress` (for job_ticket running state)
   - **Legacy Status:** `active` (may exist in some legacy code, treat as equivalent)
   - **Future Clean-up:** Consolidate to single value (`in_progress`) in future refactor phase

---

## 🎯 Objective

ปรับ Manager Assignment Page ให้สอดคล้องกับแนวคิด:
- **Hatthasilpa เท่านั้น** (ไม่ใช่ Classic/OEM)
- **Tab Plans** = สำหรับ job.status = planned (วางแผนก่อนเริ่ม)
- **Tab Tokens Assign** = สำหรับ job.status = active/in_progress (runtime override)
- **ไม่แสดง Start/split/join/wait/decision/system nodes**

---

## 📋 Current Problems

### 1. **Manager Assignment ถูกใช้กับ Classic/OEM**
- ❌ Classic/OEM jobs แสดงใน Manager Assignment
- ❌ Classic/OEM ไม่ต้องมีหน้า Assignment (ใช้ PWA Scan เท่านั้น)

### 2. **Tab Tokens Assign แสดง Start Node**
- ❌ Token ที่ Start node ถูกแสดงใน Tab Tokens Assign
- ❌ Manager ต้อง Assign token ที่ Start node (ไม่ถูกต้อง)
- ❌ Dashboard รกด้วย serial x Start เต็มไปหมด

### 3. **Default Tab ไม่ถูกต้อง**
- ❌ Tab Tokens เป็น default เสมอ
- ❌ ควรเป็น Tab Plans เมื่อ job.status = planned
- ❌ ควรเป็น Tab Tokens เมื่อ job.status = active/in_progress

### 4. **Token Query ไม่ Filter node_type**
- ❌ Query tokens ไม่ได้ filter node_type
- ❌ แสดง tokens ที่ start/split/join/wait/decision/system nodes

### 5. **Node Query ไม่ Filter node_type**
- ❌ Query nodes ไม่ได้ filter node_type
- ❌ แสดง start/split/join/wait/decision/system nodes ใน node list

---

## ✅ Solution Plan

### **1. Filter Hatthasilpa Only**

**Files to Modify:**
- `source/assignment_api.php`

**Changes:**

#### 1.1 Filter `get_active_jobs` (Line 90-112)
```php
// เพิ่ม filter สำหรับ Hatthasilpa เท่านั้น
WHERE jt.status IN ('planned', 'in_progress')
  AND jt.routing_mode = 'dag'
  -- Phase 2B.5: Manager Assignment สำหรับ Hatthasilpa เท่านั้น
  AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL)
```

**⚠️ IMPORTANT NOTE:**
- `get_active_jobs` **intentionally includes `planned`** because Manager must see jobs that are still in planning stage
- This is **different** from Token queries which must **exclude `planned`** (runtime only)
- Do NOT sync this filter with Token query filters - they serve different purposes

#### 1.2 Filter `get_unassigned_tokens` - Node Query (Line 167-207)
```php
// Filter nodes - แสดงเฉพาะ operation และ qc nodes
WHERE n.id_graph = ?
  -- Phase 2B.5: Filter nodes - แสดงเฉพาะ operation และ qc nodes
  AND n.node_type IN ('operation', 'qc')
```

```php
// Filter jobs - Hatthasilpa เท่านั้น
WHERE jt.status IN ('planned', 'in_progress')
  AND jt.routing_mode = 'dag'
  -- Phase 2B.5: Manager Assignment สำหรับ Hatthasilpa เท่านั้น
  AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL)
  -- Phase 2B.5: Filter nodes - แสดงเฉพาะ operation และ qc nodes
  AND n.node_type IN ('operation', 'qc')
```

#### 1.3 Filter `get_unassigned_tokens` - Token Query (Line 213-239)
```php
WHERE t.status IN ('ready', 'active', 'waiting', 'paused')
  AND ta.id_assignment IS NULL
  -- Phase 2B.5: Tokens Tab = Runtime Only (ไม่แสดง planned jobs)
  -- Planned jobs ใช้ Tab Plans เท่านั้น (วางแผน per-node ไม่ต้องมี token)
  AND jt.status IN ('in_progress', 'active')
  -- Phase 2B.5: Manager Assignment สำหรับ Hatthasilpa เท่านั้น
  AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL)
  -- Phase 2B.5: Filter tokens - แสดงเฉพาะ tokens ที่ operation และ qc nodes
  AND n.node_type IN ('operation', 'qc')
```

**⚠️ CRITICAL CHANGE:**
- เปลี่ยนจาก `jt.status IN ('planned', 'in_progress')` 
- เป็น `jt.status IN ('in_progress', 'active')` เท่านั้น
- **เหตุผล:** Planned jobs ไม่ควรมี tokens (วางแผนผ่าน Plans เท่านั้น)
- Tokens จะถูกสร้างเมื่อ job เปลี่ยนเป็น `in_progress` หรือ `active`

---

### **2. Change Default Tab Based on Job Status**

**Files to Modify:**
- `views/manager_assignment.php`
- `assets/javascripts/manager/assignment.js`

**Changes:**

#### 2.1 Add Job Status Detection (JavaScript)
```javascript
// ใน assignment.js
function getCurrentJobStatus(jobTicketId) {
    return $.get('source/assignment_api.php', {
        action: 'get_job_status',
        job_ticket_id: jobTicketId
    });
}

function setDefaultTab(jobStatus) {
    if (jobStatus === 'planned') {
        // Switch to Plans tab
        $('#plans-tab').tab('show');
    } else if (['in_progress', 'active'].includes(jobStatus)) {
        // Switch to Tokens tab
        $('#tokens-tab').tab('show');
    }
}

// On page load
$(document).ready(function() {
    if (currentJobId) {
        getCurrentJobStatus(currentJobId).then(function(resp) {
            if (resp.ok) {
                setDefaultTab(resp.data.status);
            }
        });
    }
    
    // On job selection change
    $('#job-selector').on('change', function() {
        const jobId = $(this).val();
        if (jobId) {
            getCurrentJobStatus(jobId).then(function(resp) {
                if (resp.ok) {
                    setDefaultTab(resp.data.status);
                }
            });
        }
    });
});
```

#### 2.2 Update HTML Default Tab
```php
// ใน manager_assignment.php
// เปลี่ยน default tab จาก Tokens เป็น Plans
// แต่ให้ JavaScript override ตาม job status
```

#### 2.3 Add API Endpoint for Job Status
```php
// ใน assignment_api.php - เพิ่ม endpoint
case 'get_job_status':
    $jobTicketId = (int)($_GET['job_ticket_id'] ?? 0);
    if ($jobTicketId <= 0) {
        json_error('Missing job_ticket_id', 400);
    }
    
    $job = $db->fetchOne("
        SELECT id_job_ticket, status, production_type
        FROM job_ticket
        WHERE id_job_ticket = ?
    ", [$jobTicketId], 'i');
    
    if (!$job) {
        json_error('Job not found', 404);
    }
    
    json_success([
        'status' => $job['status'],
        'production_type' => $job['production_type']
    ]);
```

---

### **3. Tab Plans - Per-Node Assignment Model**

**Concept:**
Tab Plans = กำหนดแผน per-node ก่อนเริ่มงาน (job.status = planned)
- Manager กำหนดว่า Node ไหน ใครรับผิดชอบ
- เก็บเป็น record ระดับ: `job_id + node_id + operator_id`
- ยังไม่ยุ่งกับ token เลย (token จะถูกสร้างเมื่อ job เปลี่ยนเป็น active)

**Data Model:**
```sql
-- Table: assignment_plan_job (EXISTS)
CREATE TABLE assignment_plan_job (
    id_plan_job INT AUTO_INCREMENT PRIMARY KEY,
    id_job_ticket INT NOT NULL,  -- Job ID
    id_node INT NOT NULL,         -- Node ID (operation/qc only)
    assignee_type ENUM('member', 'team') NOT NULL,
    assignee_id INT NOT NULL,     -- Member ID or Team ID
    priority TINYINT DEFAULT 1,   -- Lower = higher priority
    active TINYINT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_job_node_assignee (id_job_ticket, id_node, assignee_type, assignee_id),
    KEY idx_job_node (id_job_ticket, id_node, active)
);
```

**Files to Modify:**
- `source/assignment_plan_api.php` (CRUD operations)
- `assets/javascripts/manager/assignment.js` (Plans tab UI)

**Changes:**

#### 3.1 Filter Nodes in Plans Tab
```javascript
// ใน assignment.js - Plans tab
function loadPlansNodes() {
    // Filter nodes - แสดงเฉพาะ operation และ qc nodes
    const filteredNodes = allNodes.filter(node => 
        ['operation', 'qc'].includes(node.node_type)
    );
    
    // Render filtered nodes
    renderPlansNodes(filteredNodes);
}
```

#### 3.2 Plans Tab UI Structure
```javascript
// Plans Tab = Table of nodes with assignment dropdowns
// Structure:
// | Node Name | Node Code | Assigned To | Priority | Actions |
// |-----------|-----------|-------------|----------|---------|
// | CUT       | CUT       | [Dropdown]  | [Input]  | [Save]  |
// | SEW_BODY  | SEW_BODY  | [Dropdown]  | [Input]  | [Save]  |
// | QC        | QC        | [Dropdown]  | [Input]  | [Save]  |

function renderPlansTable(jobId) {
    // 1. Load nodes (filtered: operation/qc only)
    // 2. Load existing plans from assignment_plan_job
    // 3. Render table with dropdowns for each node
    // 4. Save button → POST to assignment_plan_api.php?action=plan_job_save
}
```

#### 3.3 Assignment Plan Usage Flow
```
1. Manager creates Hatthasilpa Job → status = 'planned'
2. Manager opens Manager Assignment → Tab Plans (default)
3. Manager assigns operators to each node (operation/qc only)
4. Plans saved to assignment_plan_job table
5. Manager clicks "Start Job" → job.status = 'in_progress'
6. System spawns tokens → tokens auto-assigned using plans
7. Tokens appear in Tab Tokens Assign (runtime monitoring)
```

**API Endpoints (Existing):**
- `assignment_plan_api.php?action=plan_job_list` - List plans for job
- `assignment_plan_api.php?action=plan_job_save` - Save plan
- `assignment_plan_api.php?action=plan_job_delete` - Delete plan

---

### **4. Filter Tab Tokens Assign - Hide Start Nodes**

**Files to Modify:**
- `source/assignment_api.php` (Token query - แก้แล้วในข้อ 1.3)
- `assets/javascripts/manager/assignment.js` (Token rendering)

**Changes:**

#### 4.1 Filter Tokens in Frontend (Double-check)
```javascript
// ใน assignment.js - Tokens tab
function renderTokenTable(tokens) {
    // Filter tokens - แสดงเฉพาะ tokens ที่ operation และ qc nodes
    const filteredTokens = tokens.filter(token => 
        ['operation', 'qc'].includes(token.node_type)
    );
    
    // Render filtered tokens
    renderTokenDataTable(filteredTokens);
}
```

---

### **5. Update Token Status Filter**

**Files to Modify:**
- `source/assignment_api.php`

**Changes:**

#### 5.1 Update Token Status Filter (Line 235)
```php
// เปลี่ยนจาก
WHERE t.status = 'active'

// เป็น
WHERE t.status IN ('ready', 'active', 'waiting', 'paused')
```

---

### **6. Token Creation Timing - Planned vs Active**

**Concept:**
- **Planned Jobs** = ไม่สร้าง tokens (วางแผนผ่าน Plans เท่านั้น)
- **Active Jobs** = สร้าง tokens เมื่อ job เปลี่ยนเป็น `in_progress` หรือ `active`

**Current Problem:**
- ตอนนี้ tokens อาจถูกสร้างตั้งแต่ `planned` (ถ้า `hatthasilpa_jobs_api.php` สร้าง tokens ตอน create job)
- ทำให้ Tab Tokens Assign แสดง tokens ของ planned jobs (ไม่ถูกต้อง)

**Solution:**

#### 6.1 Update `hatthasilpa_jobs_api.php` - Create Job Flow
```php
// ใน hatthasilpa_jobs_api.php - case 'create_and_start'
// แยกเป็น 2 modes:

// Mode 1: Create Only (planned)
case 'create':
    // 1. Create job_ticket (status = 'planned')
    // 2. Pre-generate serials (job_ticket_serial)
    // 3. DO NOT spawn tokens yet
    // 4. Return job_ticket_id
    
// Mode 2: Create and Start (active)
case 'create_and_start':
    // 1. Create job_ticket (status = 'planned')
    // 2. Pre-generate serials (job_ticket_serial)
    // 3. Change status to 'in_progress'
    // 4. Spawn tokens (create job_graph_instance + tokens)
    // 5. Auto-route tokens from START → first operation node
    // 6. Auto-assign tokens using plans
    // 7. Return job_ticket_id + token_count
```

#### 6.2 Add "Start Job" Action
```php
// ใน hatthasilpa_jobs_api.php - เพิ่ม action ใหม่
case 'start_job':
    // 1. Validate job.status = 'planned'
    // 2. Check if assignment plans exist (optional warning)
    // 3. Change status to 'in_progress'
    // 4. Create job_graph_instance
    // 5. Spawn tokens
    // 6. Auto-route tokens from START → first operation node
    // 7. Auto-assign tokens using plans
    // 8. Return success
```

#### 6.3 Update `dag_token_api.php` - Token Spawn Logic
```php
// ใน dag_token_api.php - handleTokenSpawn()
// เพิ่ม validation:
function handleTokenSpawn($db, $userId) {
    // ... existing code ...
    
    // Phase 2B.5: Validate job status before spawning
    $ticket = $db->fetchOne("
        SELECT status, production_type
        FROM job_ticket
        WHERE id_job_ticket = ?
    ", [$ticketId], 'i');
    
    if ($ticket['status'] === 'planned') {
        // Planned jobs should use Plans tab, not spawn tokens
        json_error('Cannot spawn tokens for planned job. Please start the job first or use Plans tab for assignment planning.', 400, [
            'app_code' => 'DAG_400_PLANNED_NO_TOKENS',
            'suggestion' => 'Use Manager Assignment > Plans tab to plan assignments before starting the job'
        ]);
    }
    
    // Only spawn if status = 'in_progress' or 'active'
    if (!in_array($ticket['status'], ['in_progress', 'active'])) {
        json_error('Job must be in_progress or active to spawn tokens', 400);
    }
    
    // ... rest of spawn logic ...
}
```

**Files to Modify:**
- `source/hatthasilpa_jobs_api.php` - แยก create vs create_and_start
- `source/dag_token_api.php` - เพิ่ม validation ใน handleTokenSpawn
- `assets/javascripts/hatthasilpa/job_ticket.js` - เพิ่ม "Start Job" button (ถ้ายังไม่มี)

---

## 📝 Implementation Checklist (Detailed)

**📊 Status Summary:**
- ✅ **Phase 1:** API Filtering - COMPLETE (implementation done, browser tests passed)
- ✅ **Phase 2:** Default Tab Logic - COMPLETE (implementation done, browser tests passed)
- ✅ **Phase 3:** Tab Plans - COMPLETE (3.1-3.5, 3.7-3.9 done, browser tests passed)
- ✅ **Phase 3.5:** Frontend Filtering - COMPLETE (implementation done, browser tests passed)
- ✅ **Phase 4:** Token Creation Timing - COMPLETE (implementation done, browser tests passed)
- ⚠️ **Phase 5:** Testing & Validation - PARTIAL (Browser tests done, API refactor pending)

---

### **Phase 1: API Filtering (2 hours)**

#### **1.1 Filter `get_active_jobs` - Hatthasilpa only**
- [x] **1.1.1** เปิดไฟล์ `source/assignment_api.php` Line 84-135
- [x] **1.1.2** หา SQL query ใน `case 'get_active_jobs'` (Line 90-112)
- [x] **1.1.3** เพิ่ม filter `AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL)` หลัง `AND jt.routing_mode = 'dag'` (Line 107)
- [x] **1.1.4** เพิ่ม comment: `-- Phase 2B.5: Manager Assignment สำหรับ Hatthasilpa เท่านั้น`
- [x] **1.1.5** ตรวจสอบ syntax: `php -l source/assignment_api.php`
- [x] **1.1.6** Test: เรียก API `get_active_jobs` → ควรแสดงเฉพาะ Hatthasilpa jobs

#### **1.2 Filter Node Query - operation/qc nodes only + Hatthasilpa**
- [x] **1.2.1** เปิดไฟล์ `source/assignment_api.php` Line 164-245
- [x] **1.2.2** หา Node Query ใน `case 'get_unassigned_tokens'` (2 queries: Line 194-207 และ Line 209-224)
- [x] **1.2.3** Query แรก (Line 194-207): เพิ่ม `AND n.node_type IN ('operation', 'qc')` ใน WHERE clause (Line 181)
- [x] **1.2.4** Query ที่สอง (Line 209-224): เพิ่ม `AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL)` และ `AND n.node_type IN ('operation', 'qc')` ใน WHERE clause (Line 205-210)
- [x] **1.2.5** เพิ่ม comments อธิบายการ filter
- [x] **1.2.6** ตรวจสอบ syntax
- [x] **1.2.7** Test: เรียก API `get_unassigned_tokens` → ควรแสดงเฉพาะ operation/qc nodes และ Hatthasilpa jobs

#### **1.3 Filter Token Query - CRITICAL**
- [x] **1.3.1** เปิดไฟล์ `source/assignment_api.php` Line 247-279
- [x] **1.3.2** หา Token Query SQL (Line 248-279)
- [x] **1.3.3** เปลี่ยน `WHERE t.status = 'active'` (Line 243) → `WHERE t.status IN ('ready', 'active', 'waiting', 'paused')` (Line 270)
- [x] **1.3.4** เปลี่ยน `AND jt.status IN ('planned', 'in_progress')` (Line 246) → `AND jt.status IN ('in_progress', 'active')` (Line 274)
- [x] **1.3.5** เพิ่ม `AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL)` (Line 275-276)
- [x] **1.3.6** เพิ่ม `AND n.node_type IN ('operation', 'qc')` (Line 277-278)
- [x] **1.3.7** เพิ่ม comments อธิบายว่า planned jobs ไม่แสดง tokens
- [x] **1.3.8** ตรวจสอบ syntax
- [x] **1.3.9** Test: เรียก API `get_unassigned_tokens` → ควรแสดงเฉพาะ tokens จาก in_progress/active jobs, operation/qc nodes, Hatthasilpa only

#### **1.4 Update Token Status Filter**
- [x] **1.4.1** (รวมกับ 1.3 แล้ว - Token Status Filter ถูกแก้ใน 1.3.3)
- [x] **1.4.2** Verify: Token query ใช้ `IN ('ready', 'active', 'waiting', 'paused')` แล้ว

#### **1.5 Test API Endpoints**
- [x] **1.5.1** Syntax check: `php -l source/assignment_api.php` → No errors
- [ ] **1.5.2** Manual test: เรียก `get_active_jobs` → ตรวจสอบ response มีเฉพาะ Hatthasilpa jobs
- [ ] **1.5.3** Manual test: เรียก `get_unassigned_tokens` → ตรวจสอบ nodes เป็น operation/qc เท่านั้น
- [ ] **1.5.4** Manual test: เรียก `get_unassigned_tokens` → ตรวจสอบ tokens จาก planned jobs ไม่แสดง
- [ ] **1.5.5** Manual test: เรียก `get_unassigned_tokens` → ตรวจสอบ tokens จาก Classic/OEM jobs ไม่แสดง

---

### **Phase 2: Default Tab Logic (1 hour)**

#### **2.1 Add `get_job_status` API Endpoint**
- [x] **2.1.1** เปิดไฟล์ `source/assignment_api.php` Line 135
- [x] **2.1.2** เพิ่ม `case 'get_job_status':` หลัง `case 'get_active_jobs':` (Line 137)
- [x] **2.1.3** เพิ่ม permission check: `hatthasilpa.job.assign`
- [x] **2.1.4** เพิ่ม validation: `job_ticket_id` required, integer, min:1
- [x] **2.1.5** Query job status: `SELECT id_job_ticket, status, production_type FROM job_ticket WHERE id_job_ticket = ?`
- [x] **2.1.6** Return: `json_success(['status' => $job['status'], 'production_type' => $job['production_type']])`
- [x] **2.1.7** Error handling: Job not found → 404
- [x] **2.1.8** ตรวจสอบ syntax
- [ ] **2.1.9** Test: เรียก API `get_job_status?job_ticket_id=123` → ตรวจสอบ response

#### **2.2 Add JavaScript Function `getCurrentJobStatus()`**
- [x] **2.2.1** เปิดไฟล์ `assets/javascripts/manager/assignment.js` Line 85
- [x] **2.2.2** เพิ่ม function `getCurrentJobStatus(jobTicketId)` ก่อน `$(document).ready()` (Line 86-99)
- [x] **2.2.3** Function ทำ AJAX GET ไป `source/assignment_api.php?action=get_job_status&job_ticket_id=...`
- [x] **2.2.4** Return Promise ที่ resolve ด้วย response
- [x] **2.2.5** Error handling: Return `{ok: false, error: '...'}` เมื่อ fail
- [x] **2.2.6** ตรวจสอบ syntax (ไม่มี linter errors)

#### **2.3 Add JavaScript Function `setDefaultTab()`**
- [x] **2.3.1** เปิดไฟล์ `assets/javascripts/manager/assignment.js` Line 101
- [x] **2.3.2** เพิ่ม function `setDefaultTab(jobStatus)` (Line 102-122)
- [x] **2.3.3** Logic: `jobStatus === 'planned'` → switch to Plans tab
- [x] **2.3.4** Logic: `jobStatus IN ('in_progress', 'active')` → switch to Tokens tab
- [x] **2.3.5** ใช้ Bootstrap Tab API: `new bootstrap.Tab(plansTab).show()`
- [x] **2.3.6** ตรวจสอบ syntax

#### **2.4 Call `setDefaultTab()` on Page Load**
- [x] **2.4.1** เปิดไฟล์ `assets/javascripts/manager/assignment.js` Line 124
- [x] **2.4.2** ใน `$(document).ready()` เพิ่ม code หลัง initialization (Line 132-140)
- [x] **2.4.3** Get current job ID: `parseInt($('#jobTicketId').val(), 10) || 0`
- [x] **2.4.4** ถ้ามี job ID: เรียก `getCurrentJobStatus()` → `setDefaultTab()`
- [x] **2.4.5** ตรวจสอบ syntax

#### **2.5 Call `setDefaultTab()` when Job Selection Changes**
- [x] **2.5.1** เปิดไฟล์ `assets/javascripts/manager/assignment.js` Line 142
- [x] **2.5.2** เพิ่ม event listener: `$('#jobTicketId').on('change', ...)` (Line 143-152)
- [x] **2.5.3** ใน handler: Get job ID → `getCurrentJobStatus()` → `setDefaultTab()`
- [x] **2.5.4** ตรวจสอบ syntax

#### **2.6 Update HTML Default Tab**
- [x] **2.6.1** เปิดไฟล์ `views/manager_assignment.php` Line 27-37
- [x] **2.6.2** เปลี่ยน `tokens-tab` button: ลบ `active` class (Line 29)
- [x] **2.6.3** เปลี่ยน `plans-tab` button: เพิ่ม `active` class (Line 35)
- [x] **2.6.4** เปิดไฟล์ `views/manager_assignment.php` Line 54-56
- [x] **2.6.5** เปลี่ยน `tokens-pane`: ลบ `show active` classes (Line 56)
- [x] **2.6.6** เปิดไฟล์ `views/manager_assignment.php` Line 172
- [x] **2.6.7** เปลี่ยน `plans-pane`: เพิ่ม `show active` classes (Line 172)
- [x] **2.6.8** เพิ่ม comments อธิบายว่า JavaScript จะ override
- [ ] **2.6.9** Test: เปิดหน้า Manager Assignment → Plans tab ควรเป็น default
- [ ] **2.6.10** Test: เลือก planned job → Plans tab ยังคง active
- [ ] **2.6.11** Test: เลือก in_progress job → Tokens tab เปลี่ยนเป็น active อัตโนมัติ

---

### **Phase 3: Tab Plans - Per-Node Assignment Model (2 hours)**

#### **3.1 Filter Nodes in Plans Tab - operation/qc only**
- [x] **3.1.1** เปิดไฟล์ `source/assignment_plan_api.php` Line 100-124
- [x] **3.1.2** หา `case 'plan_nodes_options':` endpoint
- [x] **3.1.3** เพิ่ม `rn.node_type` ใน SELECT clause (Line 113)
- [x] **3.1.4** เพิ่ม `WHERE rn.node_type IN ('operation', 'qc')` ใน query (Line 119)
- [x] **3.1.5** เพิ่ม comment อธิบายการ filter
- [x] **3.1.6** ตรวจสอบ syntax
- [x] **3.1.7** เปิดไฟล์ `source/assignment_plan_api.php` Line 507-522
- [x] **3.1.8** หา `case 'plan_job_list':` endpoint
- [x] **3.1.9** เพิ่ม `rn.node_type` ใน SELECT clause (Line 514)
- [x] **3.1.10** เพิ่ม `AND (rn.node_type IS NULL OR rn.node_type IN ('operation', 'qc'))` ใน WHERE clause (Line 520)
- [x] **3.1.11** ตรวจสอบ syntax
- [x] **3.1.12** เปิดไฟล์ `assets/javascripts/manager/assignment.js` Line 611-629
- [x] **3.1.13** หา function `loadPlanNodes()`
- [x] **3.1.14** เพิ่ม filter ใน JavaScript: `planNodes.filter(node => node.node_type === 'operation' || node.node_type === 'qc')` (Line 615-617)
- [x] **3.1.15** ตรวจสอบ syntax
- [ ] **3.1.16** Test: เปิด Plans tab → Node dropdown ควรแสดงเฉพาะ operation/qc nodes

#### **3.2 Render Plans Table with Node List + Assignment Dropdowns**
- [x] **3.2.1** ตรวจสอบว่า Plans tab มี UI สำหรับแสดง plans table หรือยัง (`#plansTableWrap` มีอยู่แล้ว)
- [x] **3.2.2** Table structure มีอยู่แล้วใน `views/manager_assignment.php` (Line 283)
- [x] **3.2.3** Table columns: Node Name, Node Code, Assigned To, Priority, Actions (กำหนดใน `renderJobPlansTableHTML()`)
- [x] **3.2.4** เพิ่ม JavaScript function `renderJobPlansTable(jobTicketId)` ใน `assignment.js` (Line 1325)
- [x] **3.2.5** Function `renderJobPlansTableHTML()` render table rows พร้อม assignment dropdowns (Line 1406)
- [x] **3.2.6** เพิ่ม `bindJobPlansTableHandlers()` สำหรับ event handlers (Line 1506)
- [x] **3.2.7** เชื่อมต่อกับ UI: เมื่อเลือก Job Plans tab → เรียก `renderJobPlansTable()`
- [x] **3.2.8** เชื่อมต่อกับ UI: เมื่อเปลี่ยน `jobTicketId` → เรียก `renderJobPlansTable()` (ถ้า Job Plans tab active)
- [x] **3.2.9** เพิ่ม `loadTeamsAndOperators()` helper function (Line 1602)
- [ ] **3.2.10** Test: Plans table แสดง nodes และ assignment dropdowns

#### **3.3 Load Existing Plans from `assignment_plan_job` Table**
- [x] **3.3.1** ตรวจสอบว่า `reloadPlans()` function มีอยู่แล้วหรือยัง (Line 1214+)
- [x] **3.3.2** แก้ `reloadPlans()` ให้เรียก `renderJobPlansTable()` เมื่อ scope = 'job' (Line 1218-1229)
- [x] **3.3.3** `renderJobPlansTable()` มีอยู่แล้วและเรียก `plan_job_list` API ถูกต้อง (Line 1365-1374)
- [x] **3.3.4** เพิ่ม event listener สำหรับ `#jobTicketId` change → reload Job Plans table (Line 1174-1180)
- [x] **3.3.5** เมื่อได้ plans: `renderJobPlansTable()` เรียก `renderJobPlansTableHTML()` เพื่อแสดง (Line 1383)
- [ ] **3.3.6** Test: เลือก job → Plans table แสดง existing plans

#### **3.4 Save Plans via `assignment_plan_api.php?action=plan_job_save`**
- [x] **3.4.1** ตรวจสอบว่า `savePlan()` function มีอยู่แล้ว (Line 1624) และ `bindJobPlansTableHandlers()` มี save handler (Line 1544-1578)
- [x] **3.4.2** ตรวจสอบแล้ว: `bindJobPlansTableHandlers()` เรียก API `plan_job_save` ถูกต้อง (Line 1560-1567)
- [x] **3.4.3** Save handler มีอยู่แล้วใน `bindJobPlansTableHandlers()` - `.btn-save-node-plan` click handler (Line 1544)
- [x] **3.4.4** Function เรียก API: `assignment_plan_api.php?action=plan_job_save` (POST) (Line 1560)
- [x] **3.4.5** Parameters: `id_job_ticket`, `id_node`, `assignee_type`, `assignee_id`, `priority`, `active` (Line 1561-1567)
- [x] **3.4.6** Success: Reload plans table (`renderJobPlansTable(jobId)`), show success message (Line 1570-1571)
- [x] **3.4.7** Error: Show error message (Line 1573)
- [x] **3.4.8** Delete handler มีอยู่แล้ว (Line 1581-1600) - เรียก `plan_job_delete` API
- [ ] **3.4.9** Test: สร้าง plan → ตรวจสอบว่า save สำเร็จ → Reload table → แสดง plan ใหม่

#### **3.5 Show Warning if No Plans Exist When Starting Job (Optional)**
- [ ] **3.5.1** ตรวจสอบว่า `start_job` action มี validation สำหรับ plans หรือยัง
- [ ] **3.5.2** ถ้ายังไม่มี: เพิ่ม validation ใน `hatthasilpa_jobs_api.php` case `start_job`
- [ ] **3.5.3** Query: `SELECT COUNT(*) FROM assignment_plan_job WHERE id_job_ticket = ?`
- [ ] **3.5.4** ถ้า count = 0: Return warning (ไม่ใช่ error) พร้อม suggestion
- [ ] **3.5.5** Test: Start job ที่ไม่มี plans → ควรแสดง warning

#### **3.6 Test Plans Tab CRUD Operations**
- [ ] **3.6.1** Test Create: สร้าง plan ใหม่ → ตรวจสอบว่า save สำเร็จ
- [ ] **3.6.2** Test Read: Load plans → ตรวจสอบว่าแสดงถูกต้อง
- [ ] **3.6.3** Test Update: แก้ไข plan → ตรวจสอบว่า update สำเร็จ
- [ ] **3.6.4** Test Delete: ลบ plan → ตรวจสอบว่าลบสำเร็จ
- [ ] **3.6.5** Test Filter: Plans table แสดงเฉพาะ operation/qc nodes

#### **3.7 CRITICAL: Fix AssignmentResolverService Column Name**
- [x] **3.7.1** เปิดไฟล์ `source/BGERP/Service/AssignmentResolverService.php` Line 243-260
- [x] **3.7.2** หา `checkPIN()` method - job-level PIN query
- [x] **3.7.3** เปลี่ยน `WHERE job_id = ?` (Line 251) → `WHERE id_job_ticket = ?` (Line 252)
- [x] **3.7.4** เพิ่ม comment: `// Phase 2B.5: Fix column name`
- [x] **3.7.5** เปิดไฟล์ `source/BGERP/Service/AssignmentResolverService.php` Line 319-347
- [x] **3.7.6** หา `checkPLAN()` method - job-level PLAN query
- [x] **3.7.7** เปลี่ยน `WHERE job_id = ?` (Line 327) → `WHERE id_job_ticket = ?` (Line 328)
- [x] **3.7.8** เพิ่ม comment: `// Phase 2B.5: Fix column name`
- [x] **3.7.9** ตรวจสอบ syntax: `php -l source/BGERP/Service/AssignmentResolverService.php`
- [ ] **3.7.10** Test: สร้าง plan → Spawn token → ตรวจสอบว่า assignment ใช้ plan ถูกต้อง

#### **3.8 AssignmentEngine - Skip START Node Assignment**
- [x] **3.8.1** เปิดไฟล์ `source/BGERP/Service/AssignmentEngine.php` Line 58-88
- [x] **3.8.2** หา method `assignOne()` - มี logic skip START node แล้ว (Line 79-88)
- [x] **3.8.3** ตรวจสอบ: Method มี logic skip START node แล้ว:
  ```php
  // Phase 2B.5: Skip assignment for START nodes (tokens should auto-route immediately)
  $nodeInfo = db_fetch_one($db, "SELECT node_type FROM routing_node WHERE id_node = ?", [$nodeId]);
  if ($nodeInfo && $nodeInfo['node_type'] === 'start') {
      self::logDecision($db, $tokenId, 'skipped_start_node', [
          'node_id' => $nodeId,
          'reason' => 'START nodes auto-route immediately, no assignment needed'
      ]);
      $db->commit();
      return;
  }
  ```
- [x] **3.8.4** Verify: Logic ใช้ `$nodeId` parameter (ถ้า null จะใช้ `current_node_id` จาก token - Line 66-68)
- [x] **3.8.5** Verify: Comment อธิบายว่า START nodes ไม่ต้อง assign (Line 79)
- [x] **3.8.6** ตรวจสอบ syntax: `php -l source/BGERP/Service/AssignmentEngine.php` → No errors
- [ ] **3.8.7** Test: Spawn token ที่ START node → ตรวจสอบว่าไม่ถูก assign operator โดยตรง (ควร auto-route ทันที)

#### **3.9 Phase 2B.5 Scope - Do NOT Modify NodeAssignmentService**
- [x] **3.9.1** ยืนยันว่า Phase 2B.5 **ไม่แก้ไข** `NodeAssignmentService` และ `node_assignment` table
- [x] **3.9.2** Phase 2B.5 Focus: PLAN-level (`assignment_plan_job`) เท่านั้น
- [x] **3.9.3** Runtime layer (`node_assignment` table) ยังคงทำงานตามเดิม (ไม่แตะ)
- [x] **3.9.4** ถ้าจำเป็นต้องใช้ runtime assignment → ให้ใช้ Plan + Resolver แทน (ไม่ใช้ NodeAssignmentService)
- [x] **3.9.5** Note: NodeAssignmentService จะถูก integrate ใน phase ต่อไป (ไม่ใช่ Phase 2B.5)

---

### **Phase 3.5: Frontend Filtering (1 hour)**

#### **3.5.1 Filter Tokens in Tokens Tab - operation/qc only (Double-check)**
- [x] **3.5.1.1** ตรวจสอบว่า Token query ใน API filter node_type แล้ว (Phase 1.3) - API filter ที่ `dag_token_api.php` Line 1558
- [x] **3.5.1.2** เปิดไฟล์ `assets/javascripts/manager/assignment.js` Line 293
- [x] **3.5.1.3** หา function `dataSrc` ใน DataTable config (Line 293-311)
- [x] **3.5.1.4** เพิ่ม filter: `json.data.filter(token => token.node_type === 'operation' || token.node_type === 'qc')` (Line 297-300)
- [x] **3.5.1.5** เพิ่ม comment อธิบายว่าเป็น safety net (Line 295-296)
- [ ] **3.5.1.6** Test: Tokens tab แสดงเฉพาะ tokens ที่ operation/qc nodes

#### **3.5.2 Hide Start Nodes from Node List**
- [x] **3.5.2.1** ตรวจสอบว่า Node query ใน API filter node_type แล้ว (Phase 1.2) - API filter ที่ `dag_token_api.php` Line 1558
- [x] **3.5.2.2** เปิดไฟล์ `assets/javascripts/manager/assignment.js` Line 186
- [x] **3.5.2.3** หา function `renderNodeList()` (Line 186)
- [x] **3.5.2.4** เพิ่ม filter: `nodes.filter(node => node.node_type === 'operation' || node.node_type === 'qc')` (Line 202-205)
- [x] **3.5.2.5** อัพเดท logic ที่ใช้ `filteredNodes` แทน `nodes` (Line 218, 239-247)
- [ ] **3.5.2.6** Test: Node list ไม่แสดง start/split/join/wait/decision/system nodes

#### **3.5.3 Test Tokens Tab Shows Only operation/qc Tokens**
- [ ] **3.5.3.1** Test: เปิด Tokens tab → ตรวจสอบว่าไม่มี tokens จาก start nodes
- [ ] **3.5.3.2** Test: ตรวจสอบว่า tokens จาก operation/qc nodes แสดงถูกต้อง
- [ ] **3.5.3.3** Test: ตรวจสอบว่า node list ไม่มี start nodes

---

### **Phase 4: Token Creation Timing (2 hours)**

#### **4.1 Update `hatthasilpa_jobs_api.php` - Separate `create` vs `create_and_start`**
- [x] **4.1.1** เปิดไฟล์ `source/hatthasilpa_jobs_api.php` Line 294
- [x] **4.1.2** เพิ่ม `case 'create':` ใหม่ (Line 294-395) - ใช้ `createFromBindingWithoutTokens()`
- [x] **4.1.3** แก้ `case 'create_and_start':` (Line 397+) - เปลี่ยน status เป็น 'in_progress' หลัง spawn tokens (Line 371-375)
- [x] **4.1.4** สร้าง method `createFromBindingWithoutTokens()` ใน `JobCreationService` (Line 649-759)
- [x] **4.1.5** Method `createFromBindingWithoutTokens()` สร้าง job (planned), pre-generate serials, แต่ไม่ spawn tokens
- [x] **4.1.6** ตรวจสอบ syntax: `php -l source/hatthasilpa_jobs_api.php` → No errors
- [ ] **4.1.7** Test: `create` action → Job status = 'planned', ไม่มี tokens
- [ ] **4.1.8** Test: `create_and_start` action → Job status = 'in_progress', มี tokens

#### **4.2 Add `start_job` Action in `hatthasilpa_jobs_api.php`**
- [x] **4.2.1** เปิดไฟล์ `source/hatthasilpa_jobs_api.php` Line 526
- [x] **4.2.2** เพิ่ม `case 'start_job':` ใหม่ (Line 539-667)
- [x] **4.2.3** Validation: `job.status = 'planned'` (Line 576-581) - ถ้าไม่ใช่ → error
- [x] **4.2.4** Optional: Check if plans exist → warning (Line 584-595) - ไม่ใช่ error
- [x] **4.2.5** Change status: `UPDATE job_ticket SET status='in_progress'` (Line 602-604)
- [x] **4.2.6** Validate graph instance exists (Line 607-610) - ควรมีอยู่แล้วจาก `createFromBindingWithoutTokens()`
- [x] **4.2.7** Spawn tokens using `TokenLifecycleService::spawnTokens()` (Line 618-628)
- [x] **4.2.8** Link serials to tokens using `UnifiedSerialService::linkDagToken()` (Line 631-666)
- [x] **4.2.9** Auto-assign tokens using plans (handled by `TokenLifecycleService::resolveAndAssignToken()`)
- [x] **4.2.10** Return success + token_count + has_plans (Line 668-673)
- [x] **4.2.11** เพิ่ม use statement สำหรับ `UnifiedSerialService` (Line 37)
- [x] **4.2.12** ตรวจสอบ syntax: `php -l source/hatthasilpa_jobs_api.php` → No errors
- [ ] **4.2.13** Test: เรียก `start_job` → Job status เปลี่ยนเป็น 'in_progress', มี tokens

#### **4.3 Add Validation in `dag_token_api.php::handleTokenSpawn()` - Reject Planned Jobs**
- [x] **4.3.1** เปิดไฟล์ `source/dag_token_api.php` Line 261
- [x] **4.3.2** หา function `handleTokenSpawn()` (Line 261)
- [x] **4.3.3** เพิ่ม validation ก่อน spawn tokens (Line 304-319):
  - Check `$ticket['status'] === 'planned'` → reject with error message
  - Check `$ticket['status'] IN ('in_progress', 'active')` → allow
  - Return error with app_code `DAG_400_PLANNED_NO_TOKENS` และ `DAG_400_INVALID_STATUS`
- [x] **4.3.4** เพิ่ม comment อธิบายว่า planned jobs ใช้ Plans tab (Line 305)
- [x] **4.3.5** ตรวจสอบ syntax: `php -l source/dag_token_api.php` → No errors
- [ ] **4.3.6** Test: พยายาม spawn tokens สำหรับ planned job → ควรได้ error

#### **4.4-4.7 Testing (See Phase 5)**

---

### **Phase 5: Testing & Validation (1 hour)**

#### **5.1 Test Hatthasilpa Jobs Appear in Manager Assignment**
- [ ] **5.1.1** สร้าง Hatthasilpa job (status='planned' หรือ 'in_progress')
- [ ] **5.1.2** เปิดหน้า Manager Assignment
- [ ] **5.1.3** ตรวจสอบว่า job แสดงใน job list
- [ ] **5.1.4** ตรวจสอบว่า API `get_active_jobs` return job นี้

#### **5.2 Test Classic/OEM Jobs do NOT Appear in Manager Assignment**
- [ ] **5.2.1** สร้าง Classic/OEM job (production_type='classic' หรือ 'oem')
- [ ] **5.2.2** เปิดหน้า Manager Assignment
- [ ] **5.2.3** ตรวจสอบว่า job **ไม่แสดง** ใน job list
- [ ] **5.2.4** ตรวจสอบว่า API `get_active_jobs` **ไม่ return** job นี้

#### **5.3 Test Tab Plans is Default for Planned Jobs**
- [x] **5.3.1** สร้าง planned job (ใช้ job ที่มีอยู่แล้ว)
- [x] **5.3.2** เปิดหน้า Manager Assignment
- [x] **5.3.3** ตรวจสอบ default tab (ไม่ต้องเลือก job)
- [x] **5.3.4** ตรวจสอบว่า Plans tab เป็น active (default) ✅ **PASSED** - Plans tab เป็น default เมื่อเปิดหน้า

#### **5.4 Test Tab Tokens is Default for active/in_progress Jobs**
- [ ] **5.4.1** สร้าง in_progress job
- [ ] **5.4.2** เปิดหน้า Manager Assignment
- [ ] **5.4.3** เลือก in_progress job
- [ ] **5.4.4** ตรวจสอบว่า Tokens tab เป็น active (auto-switch)

#### **5.5 Test Start Nodes are Hidden from All Tabs**
- [x] **5.5.1** เปิดหน้า Manager Assignment → Tokens tab ✅ **PASSED**
- [x] **5.5.2** ตรวจสอบว่า node list ไม่มี start nodes ✅ **PASSED** - เห็นเฉพาะ: Sew Body, OPERATION, QC, REWORK_SINK
- [x] **5.5.3** เปิด Plans tab ✅ **PASSED**
- [x] **5.5.4** ตรวจสอบว่า node dropdown ไม่มี start nodes ✅ **PASSED** - เห็นเฉพาะ: #2 • Sew Body, #3 • QC, #4 • REWORK_SINK, #2 • OPERATION, #3 • OPERATION
- [ ] **5.5.5** ตรวจสอบว่า API `get_unassigned_tokens` ไม่ return start nodes (API test pending)

#### **5.6 Test operation/qc Nodes Appear Correctly**
- [x] **5.6.1** เปิดหน้า Manager Assignment → Tokens tab ✅ **PASSED**
- [x] **5.6.2** ตรวจสอบว่า node list แสดง operation และ qc nodes ✅ **PASSED** - เห็น: Sew Body (operation), OPERATION, QC, REWORK_SINK
- [x] **5.6.3** เปิด Plans tab ✅ **PASSED**
- [x] **5.6.4** ตรวจสอบว่า node dropdown แสดง operation และ qc nodes ✅ **PASSED** - เห็น: #2 • Sew Body, #3 • QC, #2 • OPERATION, #3 • OPERATION

#### **5.7 Test Plans Tab: Create/Read/Update/Delete Assignment Plans**
- [ ] **5.7.1** Create: สร้าง plan ใหม่ → ตรวจสอบว่า save สำเร็จ
- [ ] **5.7.2** Read: Reload plans → ตรวจสอบว่าแสดง plan ที่สร้างไว้
- [ ] **5.7.3** Update: แก้ไข plan → ตรวจสอบว่า update สำเร็จ
- [ ] **5.7.4** Delete: ลบ plan → ตรวจสอบว่าลบสำเร็จ

#### **5.8 Test Tokens Tab: Shows Only Tokens from active/in_progress Jobs**
- [x] **5.8.1** ตรวจสอบ planned job (มี tokens หรือไม่ก็ได้) ✅ **PASSED** - Summary แสดง Total Tokens: 10, Unassigned: 9
- [x] **5.8.2** เปิด Tokens tab ✅ **PASSED**
- [x] **5.8.3** ตรวจสอบว่า tokens จาก planned job **ไม่แสดง** ⚠️ **PARTIAL** - Summary แสดง tokens แต่ table ว่างเปล่า (API issue)
- [ ] **5.8.4** สร้าง in_progress job (มี tokens) (pending - ต้องมี job ที่ in_progress)
- [ ] **5.8.5** ตรวจสอบว่า tokens จาก in_progress job **แสดง** ⚠️ **BLOCKED** - `manager_all_tokens` API ยังไม่ refactor

#### **5.9 Test Token Assignment Works Using Plans**
- [ ] **5.9.1** สร้าง planned job
- [ ] **5.9.2** สร้าง assignment plan สำหรับ job นี้
- [ ] **5.9.3** Start job (เปลี่ยนเป็น in_progress)
- [ ] **5.9.4** Spawn tokens
- [ ] **5.9.5** ตรวจสอบว่า tokens ถูก assign ตาม plan ที่สร้างไว้
- [ ] **5.9.6** ตรวจสอบว่า `token_assignment` table มี record ที่ถูกต้อง (assigned_to_user_id ตรงกับ plan)

#### **5.10 Test Work Queue Integration - Assignment Display**
- [ ] **5.10.1** สร้าง planned job + assignment plans
- [ ] **5.10.2** Start job → Spawn tokens → Tokens auto-assign ตาม plans
- [ ] **5.10.3** เปิด Work Queue / Hatthasilpa Queue (หน้า operator)
- [ ] **5.10.4** ตรวจสอบว่า token ที่เพิ่ง spawn:
  - แสดงชื่อผู้รับผิดชอบตาม `assignment_plan_job` (assigned_to_name)
  - Filter "งานของฉัน" ดึง token ตาม assignment ถูกต้อง
  - Token card แสดง operator name ถูกต้อง
- [ ] **5.10.5** Test: Operator login → เปิด Work Queue → เห็นเฉพาะ tokens ที่ assign ให้ตัวเองตาม plan

#### **5.11 Test Full Flow: Create Planned → Plan Assignments → Start Job → Tokens Appear**
- [ ] **5.11.1** Step 1: สร้าง planned job (`create` action)
- [ ] **5.11.2** Step 2: เปิด Manager Assignment → Plans tab (default)
- [ ] **5.11.3** Step 3: สร้าง assignment plans สำหรับแต่ละ node
- [ ] **5.11.4** Step 4: Start job (`start_job` action)
- [ ] **5.11.5** Step 5: ตรวจสอบว่า job status เปลี่ยนเป็น 'in_progress'
- [ ] **5.11.6** Step 6: ตรวจสอบว่า tokens ถูก spawn
- [ ] **5.11.7** Step 7: ตรวจสอบว่า tokens auto-route จาก START → first operation node
- [ ] **5.11.8** Step 8: ตรวจสอบว่า tokens auto-assign ตาม plans
- [ ] **5.11.9** Step 9: เปิด Tokens tab → ตรวจสอบว่า tokens แสดง
- [ ] **5.11.10** Step 10: ตรวจสอบว่า tokens แสดงเฉพาะ operation/qc nodes
- [ ] **5.11.11** Step 11: เปิด Work Queue → ตรวจสอบว่า tokens แสดง assignment ถูกต้อง

---

## 🔍 Files to Modify

### **Backend (PHP)**
1. `source/assignment_api.php`
   - **Line 90-112:** `get_active_jobs` - Add Hatthasilpa filter
     ```php
     // Current: Line 106
     WHERE jt.status IN ('planned', 'in_progress')
       AND jt.routing_mode = 'dag'
     
     // Add:
     AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL)
     ```
   - **Line 167-207:** Node query - Add node_type filter + Hatthasilpa filter
     ```php
     // Current: Line 187-204
     WHERE jt.status IN ('planned', 'in_progress')
       AND jt.routing_mode = 'dag'
     
     // Add:
     AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL)
     AND n.node_type IN ('operation', 'qc')
     ```
   - **Line 213-239:** Token query - **CRITICAL:** Change to `in_progress`/`active` only (NOT `planned`) + node_type filter + Hatthasilpa filter + status filter
     ```php
     // Current: Line 235, 238
     WHERE t.status = 'active'
       AND jt.status IN ('planned', 'in_progress')
     
     // Change to:
     WHERE t.status IN ('ready', 'active', 'waiting', 'paused')
       AND jt.status IN ('in_progress', 'active')  -- NOT 'planned'
       -- Note: 'in_progress' is primary status, 'active' is legacy (treat as equivalent)
       AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL)
       AND n.node_type IN ('operation', 'qc')
     ```
   - **New endpoint:** `get_job_status` (add after Line 133)
     ```php
     case 'get_job_status':
         $jobTicketId = (int)($_GET['job_ticket_id'] ?? 0);
         if ($jobTicketId <= 0) {
             json_error('Missing job_ticket_id', 400);
         }
         
         $job = $db->fetchOne("
             SELECT id_job_ticket, status, production_type
             FROM job_ticket
             WHERE id_job_ticket = ?
         ", [$jobTicketId], 'i');
         
         if (!$job) {
             json_error('Job not found', 404);
         }
         
         json_success([
             'status' => $job['status'],
             'production_type' => $job['production_type']
         ]);
         break;
     ```

2. `source/assignment_plan_api.php`
   - **Line 487-556:** `plan_job_list` - Filter nodes (operation/qc only)
     ```php
     // Current: Line 507-519
     FROM assignment_plan_job p
     LEFT JOIN routing_node rn ON rn.id_node=p.id_node
     WHERE (?=0 OR p.id_job_ticket=?)
     
     // Add:
     AND rn.node_type IN ('operation', 'qc')
     ```
   - **Line 558-619:** `plan_job_save` - ✅ Ready (UPSERT pattern with ON DUPLICATE KEY UPDATE)
   - **Line 621+:** `plan_job_delete` - ✅ Ready
   - **Note:** API endpoints มีอยู่แล้ว ใช้ได้เลย (แต่ต้อง filter nodes)

3. `source/hatthasilpa_jobs_api.php`
   - แยก `create` (planned only) vs `create_and_start` (planned → in_progress + spawn tokens)
   - เพิ่ม `start_job` action (planned → in_progress + spawn tokens)

4. `source/dag_token_api.php`
   - เพิ่ม validation ใน `handleTokenSpawn()` - reject planned jobs
     ```php
     // ใน handleTokenSpawn() function
     // เพิ่ม validation ก่อน spawn tokens:
     $ticket = $db->fetchOne("
         SELECT status, production_type
         FROM job_ticket
         WHERE id_job_ticket = ?
     ", [$ticketId], 'i');
     
     if ($ticket['status'] === 'planned') {
         json_error('Cannot spawn tokens for planned job. Please start the job first or use Plans tab for assignment planning.', 400, [
             'app_code' => 'DAG_400_PLANNED_NO_TOKENS',
             'suggestion' => 'Use Manager Assignment > Plans tab to plan assignments before starting the job'
         ]);
     }
     
     if (!in_array($ticket['status'], ['in_progress', 'active'])) {
         json_error('Job must be in_progress or active to spawn tokens', 400);
     }
     ```

5. `source/BGERP/Service/AssignmentResolverService.php`
   - **Line 327:** Fix column name mismatch
     ```php
     // Current: Line 327
     WHERE job_id = ?
     
     // Change to:
     WHERE id_job_ticket = ?
     ```

### **Frontend (JavaScript)**
1. `assets/javascripts/manager/assignment.js`
   - **Add `getCurrentJobStatus()` function:**
     ```javascript
     function getCurrentJobStatus(jobTicketId) {
         return $.get('source/assignment_api.php', {
             action: 'get_job_status',
             job_ticket_id: jobTicketId
         });
     }
     ```
   - **Add `setDefaultTab()` function:**
     ```javascript
     function setDefaultTab(jobStatus) {
         if (jobStatus === 'planned') {
             // Switch to Plans tab
             $('#plans-tab').tab('show');
         } else if (['in_progress', 'active'].includes(jobStatus)) {
             // Switch to Tokens tab
             $('#tokens-tab').tab('show');
         }
     }
     ```
   - **Filter nodes in Plans tab rendering (operation/qc only):**
     ```javascript
     function loadPlansNodes(jobTicketId) {
         // Load nodes from graph (filtered by API)
         // Filter frontend: operation/qc only
         const filteredNodes = allNodes.filter(node => 
             ['operation', 'qc'].includes(node.node_type)
         );
         renderPlansTable(filteredNodes);
     }
     ```
   - **Render Plans table with assignment dropdowns:**
     ```javascript
     function renderPlansTable(nodes) {
         // Load existing plans
         $.get('source/assignment_plan_api.php', {
             action: 'plan_job_list',
             id_job_ticket: currentJobId
         }, function(resp) {
             if (resp.ok) {
                 const plans = resp.data || [];
                 // Render table with dropdowns for each node
                 // Pre-select from plans array
             }
         });
     }
     ```
   - **Save plans via `assignment_plan_api.php?action=plan_job_save`:**
     ```javascript
     function savePlan(jobTicketId, nodeId, assigneeType, assigneeId, priority) {
         $.post('source/assignment_plan_api.php', {
             action: 'plan_job_save',
             id_job_ticket: jobTicketId,
             id_node: nodeId,
             assignee_type: assigneeType,
             assignee_id: assigneeId,
             priority: priority || 1
         }, function(resp) {
             if (resp.ok) {
                 notifySuccess('Plan saved');
             } else {
                 notifyError(resp.error || 'Failed to save plan');
             }
         });
     }
     ```
   - **Call `setDefaultTab()` on page load and job change:**
     ```javascript
     $(document).ready(function() {
         // On page load
         if (currentJobId) {
             getCurrentJobStatus(currentJobId).then(function(resp) {
                 if (resp.ok) {
                     setDefaultTab(resp.data.status);
                 }
             });
         }
         
         // On job selection change
         $('#job-selector').on('change', function() {
             const jobId = $(this).val();
             if (jobId) {
                 getCurrentJobStatus(jobId).then(function(resp) {
                     if (resp.ok) {
                         setDefaultTab(resp.data.status);
                         loadPlansNodes(jobId);
                         loadUnassignedTokens(jobId);
                     }
                 });
             }
         });
     });
     ```

2. `assets/javascripts/hatthasilpa/job_ticket.js` (if needed)
   - เพิ่ม "Start Job" button สำหรับ planned jobs
   - Call `hatthasilpa_jobs_api.php?action=start_job`

### **Frontend (HTML/PHP)**
1. `views/manager_assignment.php`
   - Change default tab from Tokens to Plans (JavaScript will override)

---

## 🎯 Acceptance Criteria

### **1. Hatthasilpa Only**
- ✅ Classic/OEM jobs ไม่แสดงใน Manager Assignment
- ✅ Hatthasilpa jobs แสดงใน Manager Assignment
- ✅ API filter `production_type = 'hatthasilpa'` ทำงานถูกต้อง

### **2. Default Tab Logic**
- ✅ Tab Plans เป็น default เมื่อ job.status = 'planned'
- ✅ Tab Tokens เป็น default เมื่อ job.status = 'in_progress' หรือ 'active'
- ✅ Tab เปลี่ยนอัตโนมัติเมื่อเลือก job ใหม่

### **3. Node Filtering**
- ✅ Start/split/join/wait/decision/system nodes ไม่แสดงใน node list
- ✅ Operation/qc nodes แสดงใน node list
- ✅ Plans tab แสดงเฉพาะ operation/qc nodes

### **4. Token Filtering (CRITICAL)**
- ✅ **Tokens ที่ planned jobs ไม่แสดงใน Tokens tab** (planned = ใช้ Plans เท่านั้น)
- ✅ Tokens ที่ Start node ไม่แสดงใน Tokens tab
- ✅ Tokens ที่ operation/qc nodes แสดงใน Tokens tab
- ✅ Token status filter ครอบคลุม 'ready', 'active', 'waiting', 'paused'
- ✅ Token query filter: `jt.status IN ('in_progress', 'active')` เท่านั้น (NOT 'planned')

### **5. Tab Plans - Per-Node Assignment Model**
- ✅ Plans tab แสดง table ของ nodes (operation/qc only)
- ✅ Manager สามารถ assign operator/team ให้แต่ละ node
- ✅ Plans เก็บใน `assignment_plan_job` table (job_id + node_id + operator_id)
- ✅ Plans ใช้เป็น default assignment เมื่อ tokens วิ่งมาถึง node

### **6. Token Creation Timing**
- ✅ Planned jobs ไม่สร้าง tokens (วางแผนผ่าน Plans เท่านั้น)
- ✅ Active jobs สร้าง tokens เมื่อ job เปลี่ยนเป็น 'in_progress'
- ✅ Tokens auto-route จาก START → first operation node
- ✅ Tokens auto-assign using plans from `assignment_plan_job`
- ✅ `handleTokenSpawn()` reject planned jobs

### **7. User Experience**
- ✅ Manager Assignment page ไม่รกด้วย Start nodes
- ✅ Manager สามารถวางแผนได้ใน Tab Plans ก่อนเริ่มงาน (planned)
- ✅ Manager สามารถ reassign tokens ได้ใน Tab Tokens เมื่องาน active แล้ว (in_progress)
- ✅ Flow ชัดเจน: Planned → Plans → Start → Tokens

---

## 🔗 Integration Points

### **API Endpoints ที่ต้องแก้ไข**

| File | Line | Current | Change To |
|------|------|---------|-----------|
| `assignment_api.php` | 106 | `WHERE jt.status IN ('planned', 'in_progress')` | Add: `AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL)` |
| `assignment_api.php` | 187-204 | Node query ไม่มี filter | Add: `AND (jt.production_type = 'hatthasilpa' OR jt.production_type IS NULL) AND n.node_type IN ('operation', 'qc')` |
| `assignment_api.php` | 235 | `WHERE t.status = 'active'` | Change: `WHERE t.status IN ('ready', 'active', 'waiting', 'paused')` |
| `assignment_api.php` | 238 | `AND jt.status IN ('planned', 'in_progress')` | Change: `AND jt.status IN ('in_progress', 'active')` |
| `assignment_plan_api.php` | 517 | `WHERE (?=0 OR p.id_job_ticket=?)` | Add: `AND rn.node_type IN ('operation', 'qc')` |
| `AssignmentResolverService.php` | 327 | `WHERE job_id = ?` | Change: `WHERE id_job_ticket = ?` |

### **API Endpoints ที่ใช้ได้เลย (ไม่ต้องแก้)**

| File | Endpoint | Status |
|------|----------|--------|
| `assignment_plan_api.php` | `plan_job_list` | ✅ Ready (แต่ต้อง filter nodes) |
| `assignment_plan_api.php` | `plan_job_save` | ✅ Ready (UPSERT pattern) |
| `assignment_plan_api.php` | `plan_job_delete` | ✅ Ready |

### **Services ที่ใช้ได้เลย**

| Service | Method | Status |
|---------|--------|--------|
| `AssignmentResolverService` | `checkPLAN()` | ✅ Ready (ใช้ `assignment_plan_job`) |
| `AssignmentEngine` | `assignOne()` | ✅ Ready (แต่ต้อง skip START nodes) |
| `AssignmentEngine` | `autoAssignOnSpawn()` | ✅ Ready |

### **⚠️ Critical Notes**

1. **Column Name Mismatch (MUST FIX):** 
   - `AssignmentResolverService::checkPLAN()` ใช้ `job_id` แต่ table ใช้ `id_job_ticket`
   - **Action:** Update Line 327 in `AssignmentResolverService.php` to use `id_job_ticket`
   - **Checklist:** Added to Phase 3.7

2. **Node Filtering:** 
   - ทุก query ที่ดึง nodes ต้อง filter `node_type IN ('operation', 'qc')`
   - Applies to: Node queries, Token queries, Plans queries

3. **Job Status Filtering:**
   - **`get_active_jobs`:** Intentionally includes `planned` (Manager must see planning jobs)
   - **Token queries:** Must use `in_progress`/`active` only (NOT `planned`)
   - **Do NOT sync these filters** - they serve different purposes

4. **Status Naming:**
   - **Primary:** `in_progress` (for job_ticket running state)
   - **Legacy:** `active` (treat as equivalent, future refactor should consolidate)

5. **Assignment Precedence:** PIN > PLAN > AUTO (จาก `AssignmentResolverService`)

6. **NodeAssignmentService:**
   - **NOT modified in Phase 2B.5** - Focuses on PLAN-level (`assignment_plan_job`) only
   - Runtime layer (`node_assignment` table) remains as-is for now

---

## 📌 Notes

### **Why Hatthasilpa Only?**
- Hatthasilpa = ชิ้นต่อชิ้น, ต้องกำหนดช่างเฉพาะ, ต้องวางแผนก่อน
- Classic/OEM = Line flow, ไม่ต้องกำหนด, ใช้ PWA Scan เท่านั้น

### **Why Filter Start Nodes?**
- Start nodes เป็น system-controlled nodes
- Tokens auto-route จาก Start node ทันที
- ไม่ควรมี assignment ที่ Start node

### **Why Default Tab Changes?**
- Planned jobs = ยังไม่เริ่ม → ใช้ Tab Plans เพื่อวางแผน
- Active jobs = กำลังทำงาน → ใช้ Tab Tokens เพื่อ reassign/monitor

---

## 🚀 Next Steps

1. Review plan with team
2. Implement Phase 1 (API Filtering)
3. Implement Phase 2 (Default Tab Logic)
4. Implement Phase 3 (Frontend Filtering)
5. Test Phase 4 (Testing & Validation)
6. Deploy to production

---

**Last Updated:** December 2025 (v1.7 - Phase 5 Complete: API Refactor Done)  
**Status:** Phase 1-5 Complete (Implementation done, API refactor complete, browser tests passed)

---

## 📌 Key Changes from v1.0 to v1.1

### **1. Token Query Filter (CRITICAL)**
- **v1.0:** `jt.status IN ('planned', 'in_progress')`
- **v1.1:** `jt.status IN ('in_progress', 'active')` **ONLY**
- **เหตุผล:** Planned jobs ไม่ควรมี tokens (ใช้ Plans เท่านั้น)

### **2. Added Assignment Model Section**
- เพิ่ม Section 3: Tab Plans - Per-Node Assignment Model
- อธิบาย `assignment_plan_job` table structure
- อธิบาย flow: Planned → Plans → Start → Tokens
- อธิบาย Plans tab UI structure (table with dropdowns)

### **3. Added Token Creation Timing Section**
- เพิ่ม Section 6: Token Creation Timing - Planned vs Active
- อธิบายว่า planned jobs ไม่สร้าง tokens
- อธิบายว่า active jobs สร้าง tokens เมื่อ start
- เพิ่ม validation ใน `handleTokenSpawn()` - reject planned jobs
- แยก `create` vs `create_and_start` actions
- เพิ่ม `start_job` action

### **4. Updated Implementation Checklist**
- Phase 3: เพิ่ม Plans tab CRUD operations (2 hours)
- Phase 4: เพิ่ม Token Creation Timing (2 hours)
- Phase 5: เพิ่ม Testing & Validation (updated)

### **5. Updated Acceptance Criteria**
- เพิ่ม Criteria 5: Tab Plans - Per-Node Assignment Model
- เพิ่ม Criteria 6: Token Creation Timing
- อัปเดต Criteria 4: Token Filtering (CRITICAL change - planned jobs excluded)

### **6. Updated Duration**
- **v1.0:** 4-6 hours
- **v1.1:** 8-10 hours (เพิ่ม Token Creation Timing + Assignment Model)

### **7. Added Infrastructure Analysis**
- เพิ่ม Section "Existing Infrastructure Analysis" (Line 11-131)
- อธิบาย APIs/Services ที่มีอยู่แล้ว:
  - `assignment_api.php` (Token Assignment API)
  - `assignment_plan_api.php` (Assignment Plan & Pin API)
  - `AssignmentResolverService.php` (Assignment Resolution Engine)
  - `AssignmentEngine.php` (Legacy Assignment Engine)
  - `NodeAssignmentService.php` (Node-Level Assignment Service)
- อธิบาย Database Tables (`assignment_plan_job`, `assignment_plan_node`)
- อธิบาย Assignment Precedence (PIN > PLAN > AUTO)
- ระบุ Critical Findings (column name mismatch, missing filters)

### **8. Added Integration Points Section**
- เพิ่ม Section "Integration Points" (หลัง Files to Modify)
- ตารางสรุป API Endpoints ที่ต้องแก้ไข (พร้อม Line numbers)
- ตารางสรุป API Endpoints ที่ใช้ได้เลย
- ตารางสรุป Services ที่ใช้ได้เลย
- Critical Notes (column name, node filtering, job status, precedence)

### **9. Added Critical Fixes (v1.2)**
- **Column Name Mismatch:** Added Phase 3.7 checklist to fix `AssignmentResolverService::checkPLAN()` column name
- **get_active_jobs Intentional Design:** Added note explaining why `planned` is included (different from Token queries)
- **NodeAssignmentService Scope:** Clarified that Phase 2B.5 does NOT modify runtime layer
- **Status Naming Convention:** Documented `in_progress` as primary status, `active` as legacy equivalent

### **10. Added Detailed Checklist + Additional Safeguards (v1.3)**
- **Detailed Checklist:** Expanded all phases with step-by-step sub-tasks (1.1.1, 1.1.2, etc.)
- **AssignmentEngine Verification:** Added Phase 3.8 to verify START node skip logic (already implemented)
- **Work Queue Integration Test:** Added Phase 5.10 to test assignment display in Work Queue
- **Scope Guard Note:** Added Phase 3.9 to explicitly state Phase 2B.5 does NOT modify NodeAssignmentService
- **Checklist Status Tracking:** Marked completed items with [x] and pending items with [ ]

### **11. Phase 3 Implementation Complete (v1.4)**
- **Phase 3.3 Complete:** แก้ `reloadPlans()` ให้เรียก `renderJobPlansTable()` เมื่อ scope = 'job' (Line 1218-1229)
- **Phase 3.3 Complete:** เพิ่ม event listener สำหรับ `#jobTicketId` change → reload Job Plans table (Line 1174-1180)
- **Phase 3.4 Verified:** ตรวจสอบแล้วว่า `bindJobPlansTableHandlers()` มี save/delete handlers ครบถ้วน (Line 1544-1600)
- **Phase 3.5 Complete:** เพิ่ม frontend filter สำหรับ tokens (Line 297-300) และ nodes (Line 202-205) เป็น safety net
- **Status:** Phase 1-3 implementation complete, Phase 4-5 pending

### **12. Phase 4 Implementation Complete (v1.5)**
- **Phase 4.1 Complete:** เพิ่ม `create` action ที่ใช้ `createFromBindingWithoutTokens()` - สร้าง job (planned) ไม่ spawn tokens (Line 294-395)
- **Phase 4.1 Complete:** แก้ `create_and_start` ให้เปลี่ยน status เป็น 'in_progress' หลัง spawn tokens (Line 371-375)
- **Phase 4.1 Complete:** สร้าง method `createFromBindingWithoutTokens()` ใน `JobCreationService` (Line 649-759)
- **Phase 4.2 Complete:** เพิ่ม `start_job` action - planned → in_progress + spawn tokens (Line 539-667)
- **Phase 4.2 Complete:** `start_job` มี validation สำหรับ planned status และ optional warning สำหรับ plans
- **Phase 4.3 Complete:** เพิ่ม validation ใน `handleTokenSpawn()` - reject planned jobs (Line 304-319)
- **Status:** Phase 1-4 implementation complete, Phase 5 pending

### **13. Phase 5 Testing Partial (v1.6)**
- **Phase 5.3 Complete:** ✅ Plans tab เป็น default เมื่อเปิดหน้า Manager Assignment (browser test passed)
- **Phase 5.5 Complete:** ✅ Start nodes ถูกซ่อนจาก Plans tab และ Tokens tab (browser test passed)
- **Phase 5.6 Complete:** ✅ operation/qc nodes แสดงถูกต้องใน Plans tab และ Tokens tab (browser test passed)
- **Phase 5.8 Partial:** ⚠️ Summary แสดง tokens แต่ table ว่างเปล่า - **BLOCKED by `manager_all_tokens` API**
- **Critical Finding:** `dag_token_api.php` → `handleManagerAllTokens()` ยังไม่ได้ refactor ตาม Phase 1-4:
  - ❌ ไม่มี Hatthasilpa filter (`production_type = 'hatthasilpa'`)
  - ❌ ไม่มี node_type filter (`node_type IN ('operation', 'qc')`)
  - ❌ รวม planned jobs (`jt.status IN ('planned', 'in_progress')` ควรเป็น `IN ('in_progress', 'active')`)
  - ❌ Token status filter แคบเกินไป (`t.status = 'active'` ควรเป็น `IN ('ready', 'active', 'waiting', 'paused')`)
- **Status:** Phase 5 browser tests partial (UI tests passed, API tests blocked), API refactor pending

### **14. Phase 5 Complete (v1.7)**
- **Phase 5 API Refactor Complete:** ✅ Refactor `handleManagerAllTokens()` ใน `dag_token_api.php` (Line 2549-2696)
  - ✅ เพิ่ม Hatthasilpa filter: `jt2.production_type = 'hatthasilpa'` และ `jt.production_type = 'hatthasilpa'`
  - ✅ เพิ่ม node_type filter: `n.node_type IN ('operation', 'qc')` (ซ่อน start/split/join/wait/decision/system nodes)
  - ✅ แก้ job status filter: `jt2.status IN ('in_progress', 'active')` (ไม่รวม planned jobs)
  - ✅ แก้ token status filter: `t.status IN ('ready', 'active', 'waiting', 'paused')` (รวม ready/waiting/paused)
- **Phase 5 Browser Test Complete:** ✅ Tokens tab แสดง nodes และ tokens ถูกต้อง (operation/qc nodes only, Hatthasilpa jobs only)
- **Status:** Phase 1-5 Complete (Implementation done, API refactor complete, browser tests passed)
