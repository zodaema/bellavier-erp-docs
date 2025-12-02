# Job Ticket Pages Restructuring - Final Specification

**Created:** November 15, 2025  
**Purpose:** Restructure 3 job ticket pages to have clear, canonical roles  
**Status:** 🚀 Implementation Ready

---

## 📋 Executive Summary

### **Goal:**
Make job creation and job ticket viewing for Linear + DAG mode canonical, non-overlapping, and spaghetti-free.

All 3 pages (`mo`, `hatthasilpa_jobs`, `hatthasilpa_job_ticket`) must be restructured to have clear, distinct roles aligned with the current DAG ERP system flow.

---

## 🚫 Non-Goals (Critical Constraints)

**These actions are STRICTLY FORBIDDEN and must NEVER be implemented:**

- ❌ **hatthasilpa_job_ticket will NOT create DAG jobs**
  - Job ticket viewer is read-only for DAG mode
  - All DAG job creation must go through `mo` or `hatthasilpa_jobs` pages only

- ❌ **Will NOT convert routing graph → job_task**
  - DAG mode uses `routing_node` and `flow_token`, NOT `job_task`
  - No conversion logic should exist between DAG and Linear task systems

- ❌ **Will NOT create graph_instance / tokens from job_ticket page**
  - Graph instance creation is only allowed in:
    - `mo.php` → `start_production` action
    - `hatthasilpa_jobs_api.php` → `create_and_start` action

- ❌ **Will NOT allow Import Routing for DAG jobs**
  - `task_import_routing` API must reject DAG mode jobs
  - UI must hide Import Routing button for DAG jobs

- ❌ **Will NOT mix DAG and Linear logic in same code path**
  - Clear separation: DAG uses `token_event`, Linear uses `wip_log`
  - No shared code that tries to handle both modes simultaneously

**Why These Constraints Exist:**
- Prevents architectural regression (spaghetti code)
- Maintains clear separation of concerns
- Ensures single source of truth for each production mode
- Prevents future developers from accidentally breaking the canonical architecture

---

## ⚠️ Linear Mode Compatibility Note

**Important:** Linear mode jobs will continue to use `job_task` + `wip_log` + PWA (legacy system) until a formal migration plan is established.

- ✅ Linear jobs remain fully functional
- ✅ Linear mode is NOT deprecated
- ✅ Both Linear and DAG modes coexist independently
- ⚠️ Do NOT assume Linear mode will be removed
- ⚠️ Do NOT break Linear functionality while implementing DAG features

**Current State:**
- Linear mode: Uses `job_task` table, WIP logs, PWA scanning (existing system)
- DAG mode: Uses `routing_node`, `flow_token`, `token_event` (new system)
- Both modes are production-ready and will coexist indefinitely

---

## 🎯 PART 1: Final Role Assignment for All 3 Pages

### **1. mo (Manufacturing Orders — OEM / Mass Production)**

**Role:** OEM / Mass-Production Job Creator

**Purpose:**
- Create OEM / Mass-Production jobs ONLY
- Support DAG mode
- Source of truth for OEM jobs running through PWA (OEM Scan Flow)

**Capabilities:**
- ✅ Create `job_ticket`
- ✅ Create `graph_instance`
- ✅ Spawn tokens
- ✅ Start production immediately (Start Production workflow)
- ✅ Action buttons: Start / Pause / Cancel (existing)
- ✅ Full production workflow management

**Current Status:**
- ✅ Already supports DAG mode
- ✅ Has `start_production` workflow
- ✅ Production-ready implementation

**Files:**
- `views/mo.php`
- `source/mo.php`
- `assets/javascripts/mo/mo.js`

---

### **2. hatthasilpa_jobs (Atelier / Hatthasilpa Job Creator — DAG Only)**

**Role:** Atelier / Hatthasilpa Job Creator (DAG Only)

**Purpose:**
- Create Atelier / Handcraft jobs ONLY
- DAG mode ONLY
- "1-click DAG job creator"
- More modern than MO, will be model for MO in future

**Capabilities:**
- ✅ Create `job_ticket`
- ✅ Create `graph_instance`
- ✅ Spawn tokens
- ✅ Auto-assign token(s)
- ❌ **Missing:** Action buttons like MO (Start/Pause/Cancel) → **MUST ADD**
- ❌ **Missing:** Production workflow management → **MUST ADD**

**Current Status:**
- ✅ Supports DAG mode
- ✅ Auto-spawns tokens
- ❌ Missing action buttons
- ❌ Missing production workflow

**Files:**
- `views/hatthasilpa_jobs.php`
- `source/hatthasilpa_jobs_api.php`
- `assets/javascripts/hatthasilpa/jobs.js`

**Required Changes:**
- Add action buttons (Start/Pause/Cancel/Complete)
- Add production workflow API endpoints
- Add action panel UI (like MO)

---

### **3. hatthasilpa_job_ticket (Job Ticket Viewer/Manager — NOT Job Creator)**

**Role:** Job Ticket Viewer/Manager (Read-Only for DAG)

**Purpose:**
- Central job ticket information viewer
- **NOT a job creator**
- Supports both Linear and DAG modes

**Capabilities:**

**For Linear Jobs:**
- ✅ Show task table (existing)
- ✅ Support WIP Log / Task Status UI
- ✅ Still used by PWA Linear (legacy)
- ⚠️ **Linear mode remains fully supported** - NOT deprecated, will coexist with DAG mode indefinitely

**For DAG Jobs:**
- ❌ **MUST NOT** show task table
- ❌ **MUST NOT** show Import Routing button
- ❌ **MUST NOT** create graph instance / tokens
- ✅ Show "DAG Mode" badge
- ✅ Show number of tokens
- ✅ Show button → "Open in Token Management (filtered by job_ticket_id)"
- ✅ Show button → "Open in Work Queue (filtered by job_ticket_id)"

**Current Status:**
- ✅ Works for Linear mode
- ❌ Still tries to create DAG jobs (WRONG)
- ❌ Shows task table for DAG jobs (WRONG)
- ❌ Has Import Routing for DAG (WRONG)

**Files:**
- `views/hatthasilpa_job_ticket.php`
- `source/hatthasilpa_job_ticket.php`
- `assets/javascripts/hatthasilpa/job_ticket.js`

**Required Changes:**
- Remove DAG job creation logic
- Add routing_mode detection
- Conditional UI based on routing_mode
- Add links to Token Management and Work Queue

---

## 🎯 PART 2: Required Fixes for All 3 Pages

### **Fix 1: Add routing_mode Detection to hatthasilpa_job_ticket**

**What to Do:**
- Load `job_ticket.routing_mode` from database
- If `graph_instance_id != NULL` → `routing_mode = 'dag'`
- UI logic:
  - If DAG → hide tasks + WIP Log + Import Routing
  - If Linear → unchanged

**Implementation:**
```php
// In source/hatthasilpa_job_ticket.php
case 'get':
    $ticket = $db->fetchOne("
        SELECT 
            jt.*,
            CASE 
                WHEN jt.graph_instance_id IS NOT NULL THEN 'dag'
                ELSE 'linear'
            END as routing_mode
        FROM job_ticket jt
        WHERE jt.id_job_ticket = ?
    ", [$id]);
    
    // Return routing_mode in response
```

```javascript
// In assets/javascripts/hatthasilpa/job_ticket.js
function loadTicketDetail(ticketId) {
    $.get(EP, { action: 'get', id_job_ticket: ticketId })
        .done(function(resp) {
            const ticket = resp.data;
            const isDAG = ticket.routing_mode === 'dag';
            
            if (isDAG) {
                // Hide tasks table, WIP logs, Import Routing
                $('#tbl-job-tasks').closest('.section-divider').hide();
                $('#btn-import-routing').hide();
                // Show DAG info panel
                showDAGInfoPanel(ticket);
            } else {
                // Show tasks table (Linear mode)
                initOrReloadTasksTable(ticketId);
            }
        });
}
```

---

### **Fix 2: Add Action Buttons to hatthasilpa_jobs**

**What to Add:**

**Buttons:**
- Start Production
- Pause Job
- Cancel Job
- Complete Job

**API Endpoints (use same pattern as MO):**
```php
// In source/hatthasilpa_jobs_api.php
case 'start_production':
    // Similar to mo.php start_production
    // Create graph_instance if not exists
    // Spawn tokens if not spawned
    // Update job status to 'in_progress'

case 'pause_job':
    // Pause job ticket
    // Update status to 'paused'

case 'cancel_job':
    // Cancel job ticket
    // Update status to 'cancelled'

case 'complete_job':
    // Complete job ticket
    // Update status to 'completed'
```

**UI:**
- Add action panel (same style as MO)
- Show after job created
- Enable/disable based on job status

**Implementation:**
```html
<!-- In views/hatthasilpa_jobs.php -->
<div class="card mt-3" id="job-action-panel" style="display: none;">
    <div class="card-header">
        <h6>Job Actions</h6>
    </div>
    <div class="card-body">
        <button class="btn btn-success" id="btn-start-production">
            <i class="fe fe-play"></i> Start Production
        </button>
        <button class="btn btn-warning" id="btn-pause-job">
            <i class="fe fe-pause"></i> Pause Job
        </button>
        <button class="btn btn-danger" id="btn-cancel-job">
            <i class="fe fe-x"></i> Cancel Job
        </button>
        <button class="btn btn-primary" id="btn-complete-job">
            <i class="fe fe-check"></i> Complete Job
        </button>
    </div>
</div>
```

---

### **Fix 3: Standardize DAG Job Creation (MO + hatthasilpa_jobs)**

**Current State:**
- MO: `start_production` → creates graph_instance + tokens
- hatthasilpa_jobs: `create_and_start` → creates graph_instance + tokens
- Both use different code paths (spaghetti)

**Required:**
- Both must call the same service class:
  - `GraphInstanceService` (or create if not exists)
  - `TokenLifecycleService` (already exists)

**Recommended Implementation:**
```php
// Recommended: Create a shared service (e.g., source/BGERP/Service/GraphInstanceService.php)
// If similar functionality exists, reuse it instead
class GraphInstanceService {
    public function createInstance(int $graphId, ?int $moId, ?int $jobTicketId, string $productionType): int {
        // Unified graph instance creation
    }
    
    public function createNodeInstances(int $instanceId, int $graphId): void {
        // Unified node instance creation
    }
}

// Update mo.php
use BGERP\Service\GraphInstanceService;
$graphService = new GraphInstanceService($tenantDb);
$instanceId = $graphService->createInstance($graphId, $moId, null, 'classic');

// Update hatthasilpa_jobs_api.php
use BGERP\Service\GraphInstanceService;
$graphService = new GraphInstanceService($tenantDb);
$instanceId = $graphService->createInstance($graphId, null, $jobTicketId, 'hatthasilpa');
```

---

### **Fix 4: Make MO + hatthasilpa_jobs Output Identical Job Tickets**

**Requirement:**
Job tickets created by MO or hatthasilpa_jobs must have identical structure:
- `routing_mode = 'dag'`
- `graph_instance_id = X`
- `job_ticket_id` shared across pages
- Token spawning consistent

**Recommended Implementation:**
```php
// Recommended: Create a unified service (e.g., source/BGERP/Service/JobCreationService.php)
// Alternative: Integrate this logic into existing services if preferred
class JobCreationService {
    public function createDAGJob(array $params): array {
        // 1. Create job_ticket
        // 2. Create graph_instance (via GraphInstanceService)
        // 3. Spawn tokens (via TokenLifecycleService)
        // 4. Return job_ticket_id, graph_instance_id, token_count
    }
}

// Update mo.php
use BGERP\Service\JobCreationService;
$jobService = new JobCreationService($tenantDb);
$result = $jobService->createDAGJob([
    'id_mo' => $moId,
    'id_graph' => $graphId,
    'production_type' => 'classic',
    'target_qty' => $qty
]);

// Update hatthasilpa_jobs_api.php
use BGERP\Service\JobCreationService;
$jobService = new JobCreationService($tenantDb);
$result = $jobService->createDAGJob([
    'id_job_ticket' => $jobTicketId,
    'id_graph' => $graphId,
    'production_type' => 'hatthasilpa',
    'target_qty' => $qty
]);
```

---

### **Fix 5: hatthasilpa_job_ticket Should Become Pure Viewer**

**Remove from hatthasilpa_job_ticket:**
- ❌ Any attempt to create tasks for DAG jobs
- ❌ Any import DAG-to-task converter
- ❌ Any ability to spawn tokens
- ❌ Any ability to create graph instances
- ❌ "Import Routing" button for DAG jobs

**Replace with:**
- ✅ DAG info panel
- ✅ Link to Token Management
- ✅ Link to Work Queue
- ✅ Token count display
- ✅ Graph instance info display

**Implementation:**
```html
<!-- In views/hatthasilpa_job_ticket.php -->
<?php if ($ticket['routing_mode'] === 'dag'): ?>
<div class="alert alert-info">
    <h6>DAG Mode Job</h6>
    <p>This job uses graph-based routing.</p>
    <div class="d-flex gap-2">
        <a href="?p=token_management&job_ticket_id=<?= $ticket['id_job_ticket'] ?>" 
           class="btn btn-primary">
            <i class="fe fe-list"></i> View Tokens
        </a>
        <a href="?p=work_queue&job_ticket_id=<?= $ticket['id_job_ticket'] ?>" 
           class="btn btn-success">
            <i class="fe fe-grid"></i> Open in Work Queue
        </a>
    </div>
</div>
<?php else: ?>
<!-- Show tasks table for Linear mode -->
<?php endif; ?>
```

---

## 🎯 PART 3: What to Delete / Deprecate

### **To Clean Spaghetti, These Must Be Removed or Disabled:**

1. **`task_import_routing` API endpoint:**
   - Must NOT operate when `routing_mode = 'dag'`
   - Return error if DAG mode detected

2. **UI Button: "Import Routing from Graph":**
   - Must NOT appear for DAG jobs
   - Hide when `routing_mode = 'dag'`

3. **Backend Code:**
   - Any code that tries `routing_node` → `job_task` conversion → DEPRECATE
   - Any DAG job creation logic in `hatthasilpa_job_ticket.php` → REMOVE

4. **References:**
   - Any references to "Create DAG Job here" in job_ticket → REMOVE
   - Any DAG-specific creation UI in job_ticket → REMOVE

**Implementation:**
```php
// In source/hatthasilpa_job_ticket.php
case 'task_import_routing':
    // Check routing_mode
    $ticket = $db->fetchOne("SELECT routing_mode, graph_instance_id FROM job_ticket WHERE id_job_ticket = ?", [$idTicket]);
    
    if ($ticket['routing_mode'] === 'dag' || $ticket['graph_instance_id']) {
        json_error('Cannot import routing for DAG mode jobs. Use Graph Designer instead.', 400);
        return;
    }
    
    // Continue with Linear routing import...
```

```javascript
// In assets/javascripts/hatthasilpa/job_ticket.js
function loadTicketDetail(ticketId) {
    // ... existing code ...
    
    if (ticket.routing_mode === 'dag') {
        // Hide Import Routing button
        $('#btn-import-routing').hide();
        // Hide tasks section
        $('#tbl-job-tasks').closest('.section-divider').hide();
    }
}
```

---

## 🎯 PART 4: After Fixing These Pages, System Can Support Phase 2

**Implementing these changes makes these things finally work:**

- ✅ PWA (OEM) DAG flow
- ✅ Work Queue (Atelier) DAG flow
- ✅ Token Management per job
- ✅ Unified `token_event` system
- ✅ Job Creation → Token Spawn → Routing → Start/Stop Flow
- ✅ Full Phase 2A / 2B / 2C integration

---

## 🎯 PART 5: Files to Modify

### **MO:**
- `views/mo.php` - Verify UI completeness
- `source/mo.php` - Verify DAG support
- `assets/javascripts/mo/mo.js` - Verify action buttons work

### **Hatthasilpa Jobs:**
- `views/hatthasilpa_jobs.php` - Add action panel UI
- `source/hatthasilpa_jobs_api.php` - Add action endpoints
- `assets/javascripts/hatthasilpa/jobs.js` - Add action button handlers

### **Job Ticket Viewer:**
- `views/hatthasilpa_job_ticket.php` - Add DAG info panel, hide tasks for DAG
- `source/hatthasilpa_job_ticket.php` - Add routing_mode detection, disable DAG creation
- `assets/javascripts/hatthasilpa/job_ticket.js` - Add conditional UI logic

### **New Services (to create):**
- `source/BGERP/Service/GraphInstanceService.php` - Unified graph instance creation
- `source/BGERP/Service/JobCreationService.php` - Unified job creation

---

## 🎯 PART 6: Final Canonical Architecture

### **Job Creation:**

**OEM Flow:**
```
MO → Create MO → Plan MO → Start Production → DAG Job → PWA OEM
```

**Atelier Flow:**
```
hatthasilpa_jobs → Create & Start → DAG Job → Work Queue
```

### **Job Viewing / Management (both OEM + Atelier):**

**Viewer:**
```
hatthasilpa_job_ticket → Read-only viewer for DAG (no tasks)
                        → Full viewer for Linear (with tasks)
```

**Token Management:**
```
token_management → Token-level actions (scrap, replacement)
                 → Filtered by job_ticket_id
```

**Execution:**
```
work_queue → Execution for Atelier (DAG tokens)
PWA → Execution for OEM (DAG tokens)
```

---

## 🎯 PART 7: Success Criteria

**Agent must ensure:**

- ✅ `hatthasilpa_job_ticket` no longer tries to generate DAG jobs
- ✅ `hatthasilpa_job_ticket` shows correct UI based on `routing_mode`
- ✅ `hatthasilpa_jobs` has full action buttons like MO
- ✅ MO + `hatthasilpa_jobs` generate identical DAG job structure
- ✅ Token spawning uses single unified service
- ✅ No spaghetti branch exists (no DAG logic inside job_ticket anymore)
- ✅ Pages behave in canonical roles as listed above

---

## 📝 Implementation Checklist

### **Phase 1: Detection & UI (hatthasilpa_job_ticket)** ✅ **COMPLETE**

- [x] Add `routing_mode` detection in API
- [x] Add conditional UI logic in JavaScript
- [x] Hide tasks table for DAG jobs
- [x] Hide Import Routing button for DAG jobs
- [x] Add DAG info panel
- [x] Add links to Token Management and Work Queue
- [x] Test with Linear jobs (should show tasks)
- [x] Test with DAG jobs (should show DAG panel)

**Status:** ✅ Complete (November 14, 2025)  
**Verification:** See `BROWSER_TEST_RESULTS.md` for test results

### **Phase 2: Action Buttons (hatthasilpa_jobs)** ✅ **COMPLETE**

- [x] Add action panel UI
- [x] Add `start_production` API endpoint
- [x] Add `pause_job` API endpoint
- [x] Add `cancel_job` API endpoint
- [x] Add `complete_job` API endpoint
- [x] Add JavaScript handlers for action buttons
- [x] Test action workflow end-to-end

**Status:** ✅ Complete (November 14, 2025)  
**Files Modified:**
- `source/hatthasilpa_jobs_api.php` - Added action endpoints
- `views/hatthasilpa_jobs.php` - Added action panel HTML
- `assets/javascripts/hatthasilpa/jobs.js` - Added action handlers

### **Phase 3: Standardization (MO + hatthasilpa_jobs)** ✅ **COMPLETE**

- [x] Create `GraphInstanceService`
- [x] Create `JobCreationService`
- [x] Update MO to use unified services
- [x] Update hatthasilpa_jobs to use unified services
- [x] Verify identical job structure output
- [x] Test token spawning consistency

**Status:** ✅ Complete (November 14, 2025)  
**Files Created:**
- `source/BGERP/Service/GraphInstanceService.php`
- `source/BGERP/Service/JobCreationService.php`
**Files Modified:**
- `source/mo.php` - Uses `JobCreationService`
- `source/hatthasilpa_jobs_api.php` - Uses `JobCreationService`

### **Phase 4: Cleanup (hatthasilpa_job_ticket)** ✅ **COMPLETE**

- [x] Disable `task_import_routing` for DAG mode
- [x] Remove DAG creation logic
- [x] Remove DAG-to-task conversion code
- [x] Update documentation
- [x] Test all edge cases

**Status:** ✅ Complete (November 14, 2025)  
**Files Modified:**
- `source/hatthasilpa_job_ticket.php` - Added DAG mode check in `task_import_routing`
- `assets/javascripts/hatthasilpa/job_ticket.js` - Conditional UI logic

### **Phase 5: Testing** ✅ **COMPLETE**

- [x] Test MO → Start Production → PWA flow
- [x] Test hatthasilpa_jobs → Create → Work Queue flow
- [x] Test hatthasilpa_job_ticket viewer for both modes
- [x] Test action buttons on hatthasilpa_jobs
- [x] Verify no spaghetti code remains

**Status:** ✅ Complete (November 14, 2025)  
**Test Results:** See `BROWSER_TEST_RESULTS.md` for detailed test results  
**Automated Tests:** `tests/manual/test_job_ticket_restructuring.php` - 17/17 tests passed

---

---

## 🎯 PART 8: Detailed Implementation Specifications (Reference Blueprint)

> **📌 Note:** This section provides *reference implementation examples* and recommended structure.  
> The exact class/file structure can be adjusted, but the **final behavior must match** the specifications in Parts 1-7.  
> Use this as a blueprint guide, not a rigid requirement.

---

### **8.1 GraphInstanceService Specification**

**Purpose:** Unified service for creating graph instances and node instances

**Recommended File:** `source/BGERP/Service/GraphInstanceService.php`  
> *Note: If a similar service already exists, reuse it. If not, create following this structure.*

**Methods:**

```php
class GraphInstanceService {
    /**
     * Create graph instance for a job
     * 
     * @param int $graphId Routing graph ID
     * @param int|null $moId MO ID (for OEM jobs)
     * @param int|null $jobTicketId Job ticket ID (for Atelier jobs)
     * @param string $productionType 'classic' or 'hatthasilpa'
     * @return int Graph instance ID
     */
    public function createInstance(int $graphId, ?int $moId, ?int $jobTicketId, string $productionType): int;
    
    /**
     * Create node instances for a graph instance
     * 
     * @param int $instanceId Graph instance ID
     * @param int $graphId Routing graph ID
     * @return array Created node instance IDs
     */
    public function createNodeInstances(int $instanceId, int $graphId): array;
    
    /**
     * Get start node for a graph
     * 
     * @param int $graphId Routing graph ID
     * @return array|null Start node data
     */
    public function getStartNode(int $graphId): ?array;
}
```

**Implementation Details:**

1. **createInstance():**
   - Insert into `job_graph_instance`
   - Set `status = 'active'`
   - Link to MO or Job Ticket
   - Return instance ID

2. **createNodeInstances():**
   - Query `routing_node` for graph
   - Insert into `node_instance` for each node
   - Set `status = 'ready'`
   - Return array of node instance IDs

3. **getStartNode():**
   - Query `routing_node` WHERE `node_type = 'start'`
   - Return node data or null

---

### **8.2 JobCreationService Specification**

**Purpose:** Unified service for creating DAG jobs (MO or Atelier)

**Recommended File:** `source/BGERP/Service/JobCreationService.php`  
> *Note: This service can be created as a new class, or the logic can be integrated into existing services. The important part is that MO and hatthasilpa_jobs use the same underlying logic.*

**Methods:**

```php
class JobCreationService {
    /**
     * Create complete DAG job (job_ticket + graph_instance + tokens)
     * 
     * @param array $params {
     *   'id_mo' => int|null,
     *   'id_job_ticket' => int|null,
     *   'id_graph' => int,
     *   'production_type' => 'classic'|'hatthasilpa',
     *   'target_qty' => int,
     *   'process_mode' => 'batch'|'piece',
     *   'serials' => array (optional, for piece mode)
     * }
     * @return array {
     *   'job_ticket_id' => int,
     *   'graph_instance_id' => int,
     *   'token_count' => int,
     *   'token_ids' => array
     * }
     */
    public function createDAGJob(array $params): array;
}
```

**Implementation Flow:**

1. **If job_ticket doesn't exist:**
   - Create `job_ticket` (if needed)
   - Set `routing_mode = 'dag'`

2. **Create graph instance:**
   - Call `GraphInstanceService::createInstance()`
   - Create node instances
   - Update `job_ticket.graph_instance_id`

3. **Spawn tokens:**
   - Call `TokenLifecycleService::spawnTokens()`
   - Use provided serials or generate new ones
   - Return token count and IDs

**Error Handling:**
- Use `DatabaseTransaction` for atomicity
- Rollback on any error
- Return detailed error messages

---

### **8.3 hatthasilpa_job_ticket API Changes**

> **📌 Note:** The SQL queries below use standard column names. Verify actual column names in your database schema before implementing.

**8.3.1 Update `get` endpoint (Reference Implementation):**

```php
case 'get':
    // ... existing code ...
    
    // PART 6: Add routing_mode detection
    $ticket = $db->fetchOne("
        SELECT 
            jt.*,
            CASE 
                WHEN jt.graph_instance_id IS NOT NULL THEN 'dag'
                WHEN jt.routing_mode IS NOT NULL THEN jt.routing_mode
                ELSE 'linear'
            END as routing_mode,
            gi.id_instance as graph_instance_id_actual,
            rg.name as graph_name,
            rg.code as graph_code
        FROM job_ticket jt
        LEFT JOIN job_graph_instance gi ON gi.id_job_ticket = jt.id_job_ticket
        LEFT JOIN routing_graph rg ON rg.id_graph = gi.id_graph
        WHERE jt.id_job_ticket = ?
    ", [$id]);
    
    // Only load tasks/logs for Linear mode
    $isDAG = ($ticket['routing_mode'] === 'dag' || $ticket['graph_instance_id_actual'] !== null);
    
    if ($isDAG) {
        $ticket['tasks'] = [];
        $ticket['logs'] = [];
        
        // Get token count
        $tokenCount = $db->fetchOne("
            SELECT COUNT(*) as count 
            FROM flow_token t
            JOIN job_graph_instance gi ON gi.id_instance = t.id_instance
            WHERE gi.id_job_ticket = ?
        ", [$id]);
        $ticket['token_count'] = (int)($tokenCount['count'] ?? 0);
    } else {
        // Linear mode: Load tasks and logs
        $ticket['tasks'] = $db->fetchAll("SELECT * FROM job_task WHERE id_job_ticket=? ORDER BY sequence_no ASC", [$id]);
        $ticket['logs'] = $db->fetchAll("SELECT l.*, t.step_name AS task_name FROM wip_log l LEFT JOIN job_task t ON t.id_job_task = l.id_job_task WHERE l.id_job_ticket=? AND l.deleted_at IS NULL ORDER BY l.event_time DESC", [$id]);
        $ticket['token_count'] = 0;
    }
    
    json_success(['data' => $ticket]);
```

**8.3.2 Disable `task_import_routing` for DAG (Reference Implementation):**

```php
case 'task_import_routing':
    // PART 3: Check routing_mode first
    $ticket = $db->fetchOne("
        SELECT 
            routing_mode,
            graph_instance_id,
            CASE 
                WHEN graph_instance_id IS NOT NULL THEN 'dag'
                WHEN routing_mode IS NOT NULL THEN routing_mode
                ELSE 'linear'
            END as detected_mode
        FROM job_ticket 
        WHERE id_job_ticket = ?
    ", [$idTicket]);
    
    $isDAG = ($ticket['detected_mode'] === 'dag' || $ticket['graph_instance_id'] !== null);
    
    if ($isDAG) {
        json_error('Cannot import routing for DAG mode jobs. DAG jobs use graph-based routing. Use Graph Designer to modify the routing graph.', 400, [
            'app_code' => 'HTJT_400_DAG_MODE_NOT_SUPPORTED',
            'routing_mode' => $ticket['detected_mode']
        ]);
        return;
    }
    
    // Continue with Linear routing import (existing code)...
```

---

### **8.4 hatthasilpa_jobs API Changes**

**8.4.1 Add action endpoints (Reference Implementation):**

```php
// In source/hatthasilpa_jobs_api.php

case 'start_production':
    must_allow_code($member, 'hatthasilpa.job.ticket');
    
    $validation = RequestValidator::make($_POST, [
        'id_job_ticket' => 'required|integer|min:1'
    ]);
    if (!$validation['valid']) {
        json_error('validation_failed', 400, ['errors' => $validation['errors']]);
    }
    
    $jobTicketId = (int)$validation['data']['id_job_ticket'];
    
    // Get job ticket
    $ticket = $db->fetchOne("
        SELECT 
            jt.*,
            gi.id_instance as graph_instance_id
        FROM job_ticket jt
        LEFT JOIN job_graph_instance gi ON gi.id_job_ticket = jt.id_job_ticket
        WHERE jt.id_job_ticket = ?
    ", [$jobTicketId]);
    
    if (!$ticket) {
        json_error('Job ticket not found', 404);
    }
    
    if ($ticket['status'] !== 'planned' && $ticket['status'] !== 'in_progress') {
        json_error('Job must be in planned or in_progress status', 400);
    }
    
    // If graph instance doesn't exist, create it
    if (!$ticket['graph_instance_id']) {
        // Use JobCreationService to create graph instance
        // This should have been created during create_and_start
        json_error('Graph instance not found. Please recreate the job.', 400);
    }
    
    // Update job status to in_progress
    $db->execute("
        UPDATE job_ticket 
        SET status = 'in_progress', started_at = NOW()
        WHERE id_job_ticket = ?
    ", [$jobTicketId], 'i');
    
    json_success(['message' => 'Production started']);

case 'pause_job':
    must_allow_code($member, 'hatthasilpa.job.ticket');
    
    $validation = RequestValidator::make($_POST, [
        'id_job_ticket' => 'required|integer|min:1'
    ]);
    if (!$validation['valid']) {
        json_error('validation_failed', 400);
    }
    
    $jobTicketId = (int)$validation['data']['id_job_ticket'];
    
    // Update status to paused
    $db->execute("
        UPDATE job_ticket 
        SET status = 'paused', paused_at = NOW()
        WHERE id_job_ticket = ? AND status = 'in_progress'
    ", [$jobTicketId], 'i');
    
    json_success(['message' => 'Job paused']);

case 'cancel_job':
    must_allow_code($member, 'hatthasilpa.job.ticket');
    
    $validation = RequestValidator::make($_POST, [
        'id_job_ticket' => 'required|integer|min:1'
    ]);
    if (!$validation['valid']) {
        json_error('validation_failed', 400);
    }
    
    $jobTicketId = (int)$validation['data']['id_job_ticket'];
    
    // Only allow cancel if not completed
    $ticket = $db->fetchOne("SELECT status FROM job_ticket WHERE id_job_ticket = ?", [$jobTicketId]);
    if ($ticket['status'] === 'completed') {
        json_error('Cannot cancel completed job', 400);
    }
    
    // Update status to cancelled
    $db->execute("
        UPDATE job_ticket 
        SET status = 'cancelled', cancelled_at = NOW()
        WHERE id_job_ticket = ?
    ", [$jobTicketId], 'i');
    
    json_success(['message' => 'Job cancelled']);

case 'complete_job':
    must_allow_code($member, 'hatthasilpa.job.ticket');
    
    $validation = RequestValidator::make($_POST, [
        'id_job_ticket' => 'required|integer|min:1'
    ]);
    if (!$validation['valid']) {
        json_error('validation_failed', 400);
    }
    
    $jobTicketId = (int)$validation['data']['id_job_ticket'];
    
    // Update status to completed
    $db->execute("
        UPDATE job_ticket 
        SET status = 'completed', completed_at = NOW()
        WHERE id_job_ticket = ? AND status IN ('in_progress', 'paused')
    ", [$jobTicketId], 'i');
    
    json_success(['message' => 'Job completed']);
```

---

### **8.5 UI Changes Specification (Reference Implementation)**

**8.5.1 hatthasilpa_job_ticket.php (View):**

**Add DAG Info Panel:**

```html
<!-- After Tasks Section, before Logs Section -->
<?php if (isset($ticket) && ($ticket['routing_mode'] === 'dag' || $ticket['graph_instance_id'])): ?>
<!-- DAG Mode Info Panel -->
<div class="section-divider"></div>
<div class="pt-3">
    <div class="alert alert-info">
        <div class="d-flex justify-content-between align-items-start">
            <div>
                <h6 class="alert-heading">
                    <i class="fe fe-share-2 me-2"></i>
                    DAG Mode Job
                </h6>
                <p class="mb-2">This job uses graph-based routing.</p>
                <div class="row g-2">
                    <div class="col-md-6">
                        <small class="text-muted d-block">Graph:</small>
                        <strong><?= htmlspecialchars($ticket['graph_name'] ?? 'N/A') ?></strong>
                    </div>
                    <div class="col-md-6">
                        <small class="text-muted d-block">Tokens:</small>
                        <strong><?= $ticket['token_count'] ?? 0 ?> tokens</strong>
                    </div>
                </div>
            </div>
            <span class="badge bg-primary">DAG</span>
        </div>
        <div class="mt-3 d-flex gap-2">
            <a href="?p=token_management&job_ticket_id=<?= $ticket['id_job_ticket'] ?>" 
               class="btn btn-primary btn-sm">
                <i class="fe fe-list me-1"></i> View Tokens
            </a>
            <a href="?p=work_queue&job_ticket_id=<?= $ticket['id_job_ticket'] ?>" 
               class="btn btn-success btn-sm">
                <i class="fe fe-grid me-1"></i> Open in Work Queue
            </a>
        </div>
    </div>
</div>
<?php endif; ?>
```

**Conditionally Hide Tasks Section:**

```javascript
// In assets/javascripts/hatthasilpa/job_ticket.js
function loadTicketDetail(ticketId, showOffcanvas = true) {
    // ... existing code ...
    
    $.get(EP, { action: 'get', id_job_ticket: ticketId })
        .done(function(resp) {
            if (!resp.ok || !resp.data) {
                notifyError('Failed to load ticket details');
                return;
            }
            
            const ticket = resp.data;
            const isDAG = ticket.routing_mode === 'dag' || ticket.graph_instance_id_actual;
            
            // Populate form fields
            populateTicketForm(ticket);
            
            if (isDAG) {
                // DAG Mode: Hide tasks and WIP logs
                $('#tbl-job-tasks').closest('.section-divider').next().hide();
                $('#btn-import-routing').closest('.d-flex').hide();
                $('#btn-add-task').closest('.d-flex').hide();
                
                // Show DAG info panel (if exists)
                $('#dag-info-panel').show();
                
                // Don't initialize tasks table
            } else {
                // Linear Mode: Show tasks and WIP logs
                $('#tbl-job-tasks').closest('.section-divider').next().show();
                $('#btn-import-routing').closest('.d-flex').show();
                $('#btn-add-task').closest('.d-flex').show();
                
                // Hide DAG info panel
                $('#dag-info-panel').hide();
                
                // Initialize tasks table
                initOrReloadTasksTable(ticketId);
            }
            
            // Show offcanvas
            if (showOffcanvas) {
                const offcanvas = new bootstrap.Offcanvas(document.getElementById('jobDetailOffcanvas'));
                offcanvas.show();
            }
        });
}
```

**8.5.2 hatthasilpa_jobs.php (View - Reference Implementation):**

**Add Action Panel:**

```html
<!-- After job creation success, show action panel -->
<div class="card mt-3" id="job-action-panel" style="display: none;">
    <div class="card-header d-flex justify-content-between align-items-center">
        <h6 class="mb-0">Job Actions</h6>
        <span class="badge bg-primary" id="job-status-badge">Planned</span>
    </div>
    <div class="card-body">
        <div class="d-flex gap-2 flex-wrap">
            <button class="btn btn-success" id="btn-start-production" data-job-id="">
                <i class="fe fe-play me-1"></i> Start Production
            </button>
            <button class="btn btn-warning" id="btn-pause-job" data-job-id="" style="display: none;">
                <i class="fe fe-pause me-1"></i> Pause Job
            </button>
            <button class="btn btn-danger" id="btn-cancel-job" data-job-id="">
                <i class="fe fe-x me-1"></i> Cancel Job
            </button>
            <button class="btn btn-primary" id="btn-complete-job" data-job-id="" style="display: none;">
                <i class="fe fe-check me-1"></i> Complete Job
            </button>
        </div>
    </div>
</div>
```

**8.5.3 hatthasilpa_jobs.js (Reference Implementation):**

**Add Action Button Handlers:**

```javascript
// After job creation success
function showJobActionPanel(jobTicketId, status) {
    $('#job-action-panel').show();
    $('#job-action-panel [data-job-id]').attr('data-job-id', jobTicketId);
    $('#job-status-badge').text(status);
    
    // Show/hide buttons based on status
    if (status === 'planned') {
        $('#btn-start-production').show();
        $('#btn-pause-job').hide();
        $('#btn-complete-job').hide();
    } else if (status === 'in_progress') {
        $('#btn-start-production').hide();
        $('#btn-pause-job').show();
        $('#btn-complete-job').show();
    } else if (status === 'paused') {
        $('#btn-start-production').show();
        $('#btn-pause-job').hide();
        $('#btn-complete-job').show();
    }
}

// Action button handlers
$('#btn-start-production').on('click', function() {
    const jobId = $(this).data('job-id');
    if (!jobId) return;
    
    $.post(API, {
        action: 'start_production',
        id_job_ticket: jobId
    }, function(resp) {
        if (resp.ok) {
            toastr.success('Production started');
            showJobActionPanel(jobId, 'in_progress');
            if (jobsTable) jobsTable.ajax.reload();
        } else {
            toastr.error(resp.error || 'Failed to start production');
        }
    }, 'json');
});

// Similar handlers for pause, cancel, complete...
```

---

### **8.6 MO Integration Points**

**Current MO Flow (to verify):**

1. Create MO → `mo.php` `create` action
2. Plan MO → `mo.php` `plan` action
3. Start Production → `mo.php` `start_production` action
   - Creates `job_graph_instance`
   - Spawns tokens
   - Updates MO status

**Required Changes:**
- Update `start_production` to use `JobCreationService` (if created)
- Or keep existing implementation if working correctly
- Verify token spawning consistency

---

### **8.7 Edge Cases & Error Handling**

**Edge Cases to Handle:**

1. **Job ticket has graph_instance_id but routing_mode = 'linear':**
   - Treat as DAG (graph_instance_id takes precedence)
   - Update routing_mode in database

2. **Job ticket has routing_mode = 'dag' but no graph_instance_id:**
   - Show error: "DAG mode job missing graph instance"
   - Offer to create graph instance (link to hatthasilpa_jobs or MO)

3. **Tokens already spawned:**
   - Don't spawn again
   - Return existing token count

4. **Graph instance exists but tokens not spawned:**
   - Allow spawning tokens separately
   - Use `TokenLifecycleService::spawnTokens()`

5. **Action button clicked on wrong status:**
   - Validate status before action
   - Return clear error message

---

### **8.8 Database Schema Considerations**

> **⚠️ Important:** Verify actual column names in your database schema before implementing.  
> The names below are based on standard conventions and may need adjustment.

**Fields to Verify:**

1. **job_ticket table:**
   - `routing_mode` enum('linear','dag') - Must be set correctly
   - `graph_instance_id` - Links to `job_graph_instance.id_instance` (verify actual column name)
   - `status` - Must support 'planned', 'in_progress', 'paused', 'completed', 'cancelled'

2. **job_graph_instance table:**
   - `id_instance` (or `id_graph_instance`) - Primary key
   - `id_job_ticket` - Links to job_ticket (for Atelier)
   - `id_mo` - Links to MO (for OEM)
   - `id_graph` - Links to routing_graph
   - Both `id_job_ticket` and `id_mo` can be NULL, but at least one must be set

3. **flow_token table:**
   - `id_token` - Primary key
   - `id_instance` - Links to `job_graph_instance.id_instance` (verify actual column name - may be `id_graph_instance`)
   - `id_mo` - Optional, for OEM tokens
   - `serial_number` - Required for piece mode
   - `current_node_id` - Current node in routing graph

**⚠️ Schema Verification Checklist:**
- [ ] Verify `job_ticket.graph_instance_id` column name (may be `id_graph_instance` or similar)
- [ ] Verify `job_graph_instance.id_instance` column name (may be `id_graph_instance`)
- [ ] Verify `flow_token.id_instance` column name (may be `id_graph_instance`)
- [ ] Verify `routing_mode` column exists and supports 'dag' value
- [ ] Verify all foreign key relationships are correct

---

### **8.9 Testing Requirements**

**Test Scenarios:**

1. **Linear Job (hatthasilpa_job_ticket):**
   - Create Linear job ticket
   - Import routing from Linear routing
   - Verify tasks table shows
   - Verify WIP logs work
   - Verify Import Routing button visible

2. **DAG Job from MO:**
   - Create MO → Plan → Start Production
   - Verify graph instance created
   - Verify tokens spawned
   - View in hatthasilpa_job_ticket
   - Verify DAG panel shows
   - Verify tasks table hidden
   - Verify links to Token Management and Work Queue work

3. **DAG Job from hatthasilpa_jobs:**
   - Create job via hatthasilpa_jobs
   - Verify graph instance created
   - Verify tokens spawned
   - Verify action buttons appear
   - Test Start/Pause/Cancel/Complete actions
   - View in hatthasilpa_job_ticket
   - Verify DAG panel shows

4. **Error Cases:**
   - Try Import Routing on DAG job → Should fail with clear error
   - Try action button on wrong status → Should fail
   - Try create DAG job without graph → Should fail

---

**Last Updated:** November 15, 2025  
**Status:** ✅ **IMPLEMENTATION COMPLETE** (November 14, 2025)  
**Priority:** 🔴 CRITICAL - Blocks Phase 2 implementation  
**Completion:** Phase 1-5 Complete (100%)  
**Test Status:** ✅ All tests passing (17/17 automated, browser tests verified)

