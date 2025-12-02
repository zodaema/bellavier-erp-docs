# 🏭🎨 Dual Production Model - Implementation Plan
**Date:** November 4, 2025 23:30 ICT  
**Priority:** 🚨 CRITICAL (Priority 1.5)  
**Status:** PLANNED - Ready for implementation  
**Timeline:** 10 hours total

---

## 🎯 Executive Summary

### **Critical Discovery:**
System was designed with single workflow, but Bellavier business requires TWO distinct production models:

1. **🎨 Atelier (Luxury):** Flexible, artisan-focused, small batch
2. **🏭 OEM (Mass):** Strict, efficiency-focused, large volume

### **Current Gap:**
- ❌ No `production_type` field
- ❌ Same workflow for both types
- ❌ MO optional for everyone (should be required for OEM only)
- ❌ Cannot enforce business rules per type

### **Solution:**
Implement dual-flow architecture with type-specific validation and UX.

---

## 📚 Business Requirements (From BELLAVIER_OPERATION_SYSTEM_DESIGN.md)

### **1. 🎨 Atelier Line (Luxury - Handcrafted)**

**Characteristics:**
```
Volume: 10-50 pieces per job
Process: Handcrafted by artisans
Traceability: High - per piece, per artisan
Schedule: FLEXIBLE (quality > deadline)
MO: OPTIONAL (can create jobs directly)
Priority: Craft quality + timing history
Example: Charlotte Aimée limited edition handbag
```

**Customer Value:**
- Scan serial → See artisan name
- See time spent per step
- Timeline: "Artisan John, 08:00-08:25 (25 min)"

**Workflow Requirements:**
- ✅ Quick start (1 step)
- ✅ No strict MO needed
- ✅ Flexible due dates
- ✅ Can adjust mid-production
- ✅ Focus on quality over speed

---

### **2. 🏭 OEM Line (Mass Production)**

**Characteristics:**
```
Volume: 100-1000+ pieces per order
Process: Standardized, assembly line
Traceability: Batch level (not per piece)
Schedule: STRICT (customer commitments)
MO: REQUIRED (customer orders)
Priority: Cost control + yield + on-time delivery
Example: Rebello car key case wholesale
```

**Customer Value:**
- Scan serial → See batch info
- General tracking (date, batch number)
- Per-piece timing not required

**Workflow Requirements:**
- ✅ Structured planning (MO required)
- ✅ Strict schedule validation
- ✅ Cannot start before scheduled date
- ✅ Locked after start (no mid-changes)
- ✅ Must complete by due date

---

## 🏗️ Architecture Design

### **Database Schema:**

```sql
-- Migration: 2025_11_dual_production_model.php

-- Job Ticket Enhancement
ALTER TABLE hatthasilpa_job_ticket 
  ADD COLUMN production_type ENUM('hatthasilpa','oem') NOT NULL DEFAULT 'hatthasilpa'
  COMMENT 'Business line: hatthasilpa (luxury) or oem (mass production)'
  AFTER routing_mode;

-- MO Enhancement
ALTER TABLE mo 
  ADD COLUMN production_type ENUM('hatthasilpa','oem') NOT NULL DEFAULT 'oem'
  COMMENT 'Business line identifier'
  AFTER status;

ALTER TABLE mo
  ADD COLUMN id_routing_graph INT(11) DEFAULT NULL 
  COMMENT 'FK to routing_graph - selected production process',
  ADD COLUMN graph_instance_id INT(11) DEFAULT NULL 
  COMMENT 'FK to job_graph_instance - active execution instance';

-- Migrate existing data
UPDATE hatthasilpa_job_ticket 
SET production_type = CASE 
  WHEN id_mo IS NULL THEN 'hatthasilpa'
  ELSE 'oem'
END;
```

---

### **Flow Architecture:**

```
┌─────────────────────────────────────────────────────────────┐
│                    BELLAVIER GROUP ERP                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🎨 Atelier Line            🏭 OEM Line                     │
│  (Luxury)                   (Mass Production)               │
│                                                             │
├──────────────────────────┬──────────────────────────────────┤
│                          │                                  │
│  Hatthasilpa Jobs            │  Manufacturing Orders            │
│  (Direct, Flexible)      │  (MO Required, Strict)           │
│                          │                                  │
│  CREATE JOB:             │  CREATE MO:                      │
│  • Job name ✅           │  • Customer ⚠️ Required         │
│  • Qty (10-50) ✅        │  • Product ⚠️ Required          │
│  • Graph ✅              │  • Qty (100+) ⚠️ Required       │
│  • Due: flexible ⚠️      │  • Due: strict ⚠️ Required      │
│  • MO: optional ⚠️       │  • Graph ⚠️ Required            │
│                          │  • Schedule ⚠️ Required         │
│  [Create & Start]        │  [Create MO]                     │
│  ↓ (immediate)           │  ↓                               │
│  Spawn tokens            │  [Schedule] (validate)           │
│  ↓                       │  ↓                               │
│  Auto-assign             │  [Start Production] (on date)    │
│                          │  ↓                               │
│                          │  Spawn tokens + auto-assign      │
│                          │                                  │
└──────────┬───────────────┴─────────────┬────────────────────┘
           │                             │
           └──────────────┬──────────────┘
                          │
                          ▼
           ┌──────────────────────────────┐
           │    DAG Graph Execution        │
           │    (Unified Engine)           │
           └──────────────┬───────────────┘
                          │
                          ▼
           ┌──────────────────────────────┐
           │      Work Queue              │
           │  🎨 Atelier / 🏭 OEM         │
           │  (Shows type badge + MO)     │
           └──────────────────────────────┘
```

---

## 📋 Implementation Phases

### **Phase 1: Database Schema (1 hour)**

**Files:**
- `database/tenant_migrations/2025_11_dual_production_model.php` (NEW)

**Tasks:**
1. ✅ Create migration file
2. ✅ Add `production_type` to `hatthasilpa_job_ticket`
3. ✅ Add `production_type`, `id_routing_graph`, `graph_instance_id` to `mo`
4. ✅ Migrate existing data (NULL id_mo → atelier, else → oem)
5. ✅ Test migration on dev database
6. ✅ Verify data integrity

**Acceptance Criteria:**
- [ ] Migration runs without errors
- [ ] All tables have new columns
- [ ] Existing data migrated correctly
- [ ] Foreign keys valid

---

### **Phase 2: Hatthasilpa Jobs Page (3 hours)**

**Files:**
- `page/atelier_jobs.php` (NEW)
- `views/atelier_jobs.php` (NEW)
- `assets/javascripts/hatthasilpa/jobs.js` (NEW)
- `source/atelier_jobs_api.php` (NEW)

**UI Design:**
```html
<h1>🎨 Atelier Production</h1>
<p class="subtitle">Luxury handcrafted line - Flexible workflow for limited editions</p>

<div class="alert alert-info">
  <strong>Atelier Line:</strong> Create jobs directly for luxury products. 
  No strict MO required. Focus on quality and artisan craftsmanship.
</div>

<form id="formAtelierJob">
  <div class="row">
    <div class="col-md-6">
      <label>Job Name *</label>
      <input name="job_name" placeholder="Charlotte Aimée Batch 3" required>
    </div>
    <div class="col-md-3">
      <label>Quantity (pieces) *</label>
      <input name="qty" type="number" min="1" max="100" placeholder="20" required>
      <small class="text-muted">Typical: 10-50 pieces</small>
    </div>
    <div class="col-md-3">
      <label>Due Date</label>
      <input name="due_date" type="date">
      <small class="text-muted">Flexible (optional)</small>
    </div>
  </div>
  
  <div class="row">
    <div class="col-md-6">
      <label>Routing Graph *</label>
      <select name="id_routing_graph" required>
        <option value="">-- Select Production Process --</option>
        <!-- Populated from published graphs -->
      </select>
    </div>
    <div class="col-md-6">
      <label>Link to MO (Optional)</label>
      <select name="id_mo">
        <option value="">-- No MO (Direct Job) --</option>
        <!-- Populated from MO list -->
      </select>
      <small class="text-muted">Optional for special customer orders</small>
    </div>
  </div>
  
  <button type="submit" class="btn btn-success">
    <i class="ri-play-fill"></i> Create & Start Production
  </button>
</form>
```

**API Endpoints:**
```php
// source/atelier_jobs_api.php

case 'create_and_start':
    // 1. Validate input (flexible rules)
    if (!$jobName || !$qty || !$graphId) {
        json_error('Missing required fields', 400);
    }
    
    if ($qty > 100) {
        json_error('Hatthasilpa jobs limited to 100 pieces. Use OEM MO for larger orders.', 400);
    }
    
    // 2. Create job ticket
    $ticketId = createJobTicket([
        'job_name' => $jobName,
        'target_qty' => $qty,
        'production_type' => 'hatthasilpa',
        'routing_mode' => 'dag',
        'id_routing_graph' => $graphId,
        'id_mo' => $moId,  // Can be NULL
        'due_date' => $dueDate,  // Optional
    ]);
    
    // 3. Auto: Create graph instance
    $instanceId = createGraphInstance($ticketId, $graphId);
    
    // 4. Auto: Spawn tokens
    $tokenIds = spawnTokens($instanceId, $qty);
    
    // 5. Auto: Assign to operators (optional - can be manual)
    if ($autoAssign) {
        autoAssignTokens($tokenIds);
    }
    
    // 6. Update status
    updateJobStatus($ticketId, 'in_progress');
    
    json_success([
        'ticket_id' => $ticketId,
        'instance_id' => $instanceId,
        'tokens_spawned' => count($tokenIds)
    ]);
```

**Acceptance Criteria:**
- [ ] Page loads without errors
- [ ] Form validation working (flexible rules)
- [ ] 1-click create & start working
- [ ] Tokens spawned automatically
- [ ] Auto-assign (or manual) working
- [ ] Appears in Work Queue immediately

---

### **Phase 3: OEM MO Enhancement (2 hours)**

**Files:**
- `source/mo.php` (MODIFY - add endpoints)
- `views/mo.php` (MODIFY - add fields)
- `assets/javascripts/mo.js` (MODIFY - add logic)

**UI Enhancements:**

**MO Form - Add Fields:**
```html
<!-- Add to existing MO form -->

<div class="row">
  <div class="col-md-6">
    <label>Production Type *</label>
    <select name="production_type" required>
      <option value="oem">🏭 OEM (Mass Production)</option>
      <option value="hatthasilpa">🎨 Atelier (Luxury - Rare)</option>
    </select>
  </div>
  <div class="col-md-6">
    <label>Routing Graph *</label>
    <select name="id_routing_graph" required>
      <option value="">-- Select Production Process --</option>
      <!-- Populated from published graphs -->
    </select>
    <small class="text-muted">Required for production planning</small>
  </div>
</div>

<div class="row">
  <div class="col-md-6">
    <label>Scheduled Start *</label>
    <input name="scheduled_start" type="date" required>
  </div>
  <div class="col-md-6">
    <label>Scheduled End *</label>
    <input name="scheduled_end" type="date" required>
  </div>
</div>
```

**MO List - Add Column & Button:**
```html
<table id="tbl-mo">
  <thead>
    <tr>
      <th>MO Code</th>
      <th>Product</th>
      <th>Qty</th>
      <th>Type</th>
      <th>Graph</th>
      <th>Schedule</th>
      <th>Status</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>MO-2025-001</td>
      <td>TOTE Bag</td>
      <td>500</td>
      <td><span class="badge bg-info">🏭 OEM</span></td>
      <td>TOTE Production V1</td>
      <td>Nov 10 - Nov 25</td>
      <td>Scheduled</td>
      <td>
        <button class="btn btn-success btn-start-production"
                data-mo-id="1"
                ${!is_scheduled || !graph ? 'disabled' : ''}>
          <i class="ri-play-fill"></i> Start Production
        </button>
      </td>
    </tr>
  </tbody>
</table>
```

**API Enhancements:**
```php
// source/mo.php

case 'start_production':
    must_allow_code($member, 'mo.manage');
    
    $moId = (int)($_POST['id_mo'] ?? 0);
    if ($moId <= 0) {
        json_error('Invalid MO ID', 400);
    }
    
    // Get MO with validation
    $mo = db_fetch_one($tenantDb, "
        SELECT * FROM mo WHERE id_mo = ?
    ", [$moId]);
    
    if (!$mo) {
        json_error('MO not found', 404);
    }
    
    // Validate for OEM type
    if ($mo['production_type'] === 'oem') {
        if (!$mo['is_scheduled']) {
            json_error('OEM MO must be scheduled before starting production', 400);
        }
        if (!$mo['id_routing_graph']) {
            json_error('Routing graph required for OEM production', 400);
        }
        if ($mo['scheduled_start_date'] > date('Y-m-d')) {
            json_error('Cannot start before scheduled start date: ' . $mo['scheduled_start_date'], 400);
        }
    }
    
    // Create graph instance
    $stmt = $tenantDb->prepare("
        INSERT INTO job_graph_instance 
        (id_graph, id_mo, status, started_at)
        VALUES (?, ?, 'active', NOW())
    ");
    $stmt->bind_param('ii', $mo['id_routing_graph'], $moId);
    $stmt->execute();
    $instanceId = $stmt->insert_id;
    
    // Create node instances
    createNodeInstancesFromGraph($tenantDb, $instanceId, $mo['id_routing_graph']);
    
    // Spawn tokens
    $tokenService = new \BGERP\Service\TokenLifecycleService($tenantDb);
    $tokenIds = $tokenService->spawnTokens(
        $instanceId,
        $mo['qty'],
        'piece',  // or from MO.process_mode
        []  // Generate serials
    );
    
    // Auto-assign tokens (optional)
    if ($autoAssign) {
        autoAssignTokensByLoadBalancing($tenantDb, $tokenIds);
    }
    
    // Update MO
    $stmt = $tenantDb->prepare("
        UPDATE mo 
        SET graph_instance_id = ?, 
            status = 'in_progress',
            started_at = NOW()
        WHERE id_mo = ?
    ");
    $stmt->bind_param('ii', $instanceId, $moId);
    $stmt->execute();
    
    json_success([
        'instance_id' => $instanceId,
        'tokens_spawned' => count($tokenIds),
        'message' => 'Production started successfully'
    ]);
    return;

case 'get_published_graphs':
    $graphs = db_fetch_all($tenantDb, "
        SELECT id_graph, graph_name, description, 
               (SELECT COUNT(*) FROM routing_node WHERE id_graph = rg.id_graph) AS node_count
        FROM routing_graph rg
        WHERE status = 'published'
        ORDER BY graph_name
    ");
    
    json_success(['graphs' => $graphs]);
    return;
```

**Acceptance Criteria:**
- [ ] Graph dropdown populated
- [ ] Schedule validation working
- [ ] "Start Production" button logic correct
- [ ] Tokens spawned from MO
- [ ] MO status updated correctly
- [ ] Graph instance linked to MO

---

### **Phase 4: Business Rules Engine (2 hours)**

**Files:**
- `source/service/ProductionValidationService.php` (NEW)

**Code:**
```php
<?php
namespace BGERP\Service;

class ProductionValidationService
{
    /**
     * Validate job/MO creation based on production type
     */
    public static function validateProduction(array $data, string $productionType): array
    {
        $errors = [];
        
        if ($productionType === 'oem') {
            // OEM: Strict validation
            if (empty($data['id_mo']) && empty($data['creating_mo'])) {
                $errors[] = 'OEM production requires Manufacturing Order';
            }
            
            if (empty($data['id_routing_graph'])) {
                $errors[] = 'Routing graph required for OEM production';
            }
            
            if (empty($data['scheduled_start_date']) || empty($data['scheduled_end_date'])) {
                $errors[] = 'Production schedule required for OEM (customer commitment)';
            }
            
            if (!empty($data['qty']) && $data['qty'] < 100) {
                $errors[] = 'OEM production typically 100+ pieces. Consider Atelier line for smaller batches.';
            }
            
            if (!empty($data['due_date'])) {
                $dueDate = strtotime($data['due_date']);
                if ($dueDate < strtotime('+7 days')) {
                    $errors[] = 'OEM orders require minimum 7 days lead time';
                }
            }
            
        } else if ($productionType === 'hatthasilpa') {
            // Hatthasilpa: Flexible validation
            if (empty($data['id_routing_graph'])) {
                $errors[] = 'Routing graph required (defines production steps)';
            }
            
            if (!empty($data['qty']) && $data['qty'] > 100) {
                $errors[] = 'Atelier line limited to 100 pieces. Use OEM MO for larger orders.';
            }
            
            // MO and schedule optional
            // Due date optional (flexible delivery)
        }
        
        return [
            'valid' => empty($errors),
            'errors' => $errors
        ];
    }
    
    /**
     * Check if MO can start production
     */
    public static function canStartProduction(array $mo): array
    {
        $errors = [];
        
        if ($mo['status'] !== 'planned' && $mo['status'] !== 'scheduled') {
            $errors[] = 'MO must be in planned or scheduled status';
        }
        
        if ($mo['production_type'] === 'oem') {
            if (!$mo['is_scheduled']) {
                $errors[] = 'OEM production must be scheduled first';
            }
            
            if (!$mo['id_routing_graph']) {
                $errors[] = 'Routing graph not selected';
            }
            
            if ($mo['scheduled_start_date'] > date('Y-m-d')) {
                $errors[] = 'Cannot start before scheduled date: ' . $mo['scheduled_start_date'];
            }
        }
        
        return [
            'can_start' => empty($errors),
            'errors' => $errors
        ];
    }
    
    /**
     * Get workflow steps by production type
     */
    public static function getWorkflowSteps(string $productionType): array
    {
        if ($productionType === 'hatthasilpa') {
            return [
                ['step' => 1, 'name' => 'Create Job', 'required' => true],
                ['step' => 2, 'name' => 'Select Graph', 'required' => true],
                ['step' => 3, 'name' => 'Start Production', 'required' => true],
            ];
        } else {
            return [
                ['step' => 1, 'name' => 'Create MO', 'required' => true],
                ['step' => 2, 'name' => 'Select Graph', 'required' => true],
                ['step' => 3, 'name' => 'Schedule', 'required' => true],
                ['step' => 4, 'name' => 'Start Production', 'required' => true],
            ];
        }
    }
}
```

**Acceptance Criteria:**
- [ ] Validation service working
- [ ] Hatthasilpa: Flexible validation
- [ ] OEM: Strict validation
- [ ] Clear error messages
- [ ] Unit tests passing

---

### **Phase 5: Work Queue Enhancement (1 hour)**

**Files:**
- `source/dag_token_api.php` (MODIFY - handleGetWorkQueue)
- `source/assignment_api.php` (MODIFY - handleGetUnassignedTokens)
- `assets/javascripts/work_queue.js` (MODIFY - display logic)
- `assets/javascripts/manager/assignment.js` (MODIFY - display logic)

**API Changes:**
```php
// In dag_token_api.php -> handleGetWorkQueue()

SELECT 
    t.id_token,
    t.serial_number,
    t.status,
    jt.ticket_code,
    jt.job_name,
    jt.production_type,  -- ⭐ ADD
    jt.id_mo,
    mo.mo_code,          -- ⭐ ADD
    mo.id_product AS mo_product,
    n.node_name,
    n.node_code,
    n.node_type
FROM flow_token t
JOIN job_graph_instance jgi ON t.id_instance = jgi.id_instance
LEFT JOIN hatthasilpa_job_ticket jt ON jgi.id_job_ticket = jt.id_job_ticket
LEFT JOIN mo ON jt.id_mo = mo.id_mo   -- ⭐ ADD JOIN
JOIN routing_node n ON t.current_node_id = n.id_node
WHERE t.status IN ('ready', 'active', 'paused')
```

**UI Changes:**
```javascript
// In work_queue.js - renderTokenCard()

function renderTokenCard(token) {
    const productionBadge = token.production_type === 'oem' 
        ? '<span class="badge bg-info-transparent"><i class="ri-building-line"></i> OEM</span>'
        : '<span class="badge bg-warning-transparent"><i class="ri-palette-line"></i> Atelier</span>';
    
    const sourceInfo = token.production_type === 'oem'
        ? `<i class="bi bi-box"></i> MO: ${token.mo_code || 'N/A'}`
        : `<i class="bi bi-briefcase"></i> Job: ${token.job_name}`;
    
    return `
        <div class="token-card">
            <div class="d-flex justify-content-between">
                <div>
                    ${productionBadge}
                    <code>${token.serial_number}</code>
                </div>
                <div class="text-end">
                    <span class="badge bg-primary">${token.node_name}</span>
                </div>
            </div>
            <div class="text-muted small mt-2">
                ${sourceInfo}
            </div>
            <div class="actions mt-2">
                ${renderActionButtons(token)}
            </div>
        </div>
    `;
}
```

**Acceptance Criteria:**
- [ ] Work Queue shows production_type badge
- [ ] OEM tokens show MO code
- [ ] Atelier tokens show job name
- [ ] Different colors per type
- [ ] All data displays correctly

---

### **Phase 6: Testing & Documentation (1-2 hours)**

**Test Scenarios:**

**Atelier Test:**
```
1. Create Atelier job (no MO)
   - Job name: "Test Luxury Bag"
   - Qty: 15
   - Graph: Any published
   - Due: (leave empty)
   ✅ Should succeed

2. Click "Create & Start"
   ✅ Should spawn 15 tokens immediately
   ✅ Should appear in Work Queue
   ✅ Should show "🎨 Atelier" badge
   ✅ Should show job name (not MO)

3. Operator workflow
   ✅ Should see token in queue
   ✅ Should be able to start work
```

**OEM Test:**
```
1. Create OEM MO without graph
   ❌ Should fail: "Routing graph required"

2. Create OEM MO without schedule
   ❌ Should fail: "Schedule required for OEM"

3. Create OEM MO (complete)
   - Customer: "ABC Trading"
   - Qty: 500
   - Graph: "TOTE Production V1"
   - Schedule: Nov 10-25
   ✅ Should succeed → Status: 'planned'

4. Try to start before scheduled date
   ❌ Should fail: "Cannot start before Nov 10"

5. On scheduled date, click "Start Production"
   ✅ Should spawn 500 tokens
   ✅ Should auto-assign
   ✅ Should appear in Work Queue
   ✅ Should show "🏭 OEM" badge
   ✅ Should show MO code

6. Try to change schedule after start
   ❌ Should fail: "Cannot modify schedule after production started"
```

**Documentation Updates:**
- [ ] Update `docs/USER_MANUAL.md` with dual flow
- [ ] Update `docs/MANAGER_QUICK_GUIDE_TH.md`
- [ ] Create `docs/ATELIER_vs_OEM_GUIDE.md`
- [ ] Update `ROADMAP_V3.md` (done)
- [ ] Update `CHANGELOG.md` (done)

---

## 📊 Implementation Checklist

### **Phase 1: Database ✅**
- [ ] Create migration `2025_11_dual_production_model.php`
- [ ] Add `production_type` to `hatthasilpa_job_ticket`
- [ ] Add `production_type`, `id_routing_graph`, `graph_instance_id` to `mo`
- [ ] Migrate existing data
- [ ] Test migration
- [ ] Apply to all tenant databases

### **Phase 2: Hatthasilpa Jobs Page ✅**
- [ ] Create `page/atelier_jobs.php`
- [ ] Create `views/atelier_jobs.php`
- [ ] Create `assets/javascripts/hatthasilpa/jobs.js`
- [ ] Create `source/atelier_jobs_api.php`
- [ ] Implement 1-click create & start
- [ ] Add to sidebar menu
- [ ] Test E2E workflow

### **Phase 3: OEM MO Enhancement ✅**
- [ ] Modify `source/mo.php` (add start_production, get_published_graphs)
- [ ] Modify `views/mo.php` (add graph dropdown, schedule fields)
- [ ] Modify `assets/javascripts/mo.js` (add validation, button logic)
- [ ] Implement strict validation
- [ ] Test start production flow

### **Phase 4: Business Rules ✅**
- [ ] Create `source/service/ProductionValidationService.php`
- [ ] Implement type-specific validation
- [ ] Write unit tests
- [ ] Test both flows

### **Phase 5: Work Queue Enhancement ✅**
- [ ] Modify `source/dag_token_api.php` (add MO join)
- [ ] Modify `source/assignment_api.php` (add MO join)
- [ ] Modify `assets/javascripts/work_queue.js` (add production_type display)
- [ ] Modify `assets/javascripts/manager/assignment.js` (add MO info)
- [ ] Test display

### **Phase 6: Testing & Documentation ✅**
- [ ] Test Atelier flow (no MO)
- [ ] Test OEM flow (with MO)
- [ ] Test validation rules
- [ ] Update documentation
- [ ] Create training materials

---

## 🎯 Success Criteria

### **Functional:**
- ✅ Hatthasilpa jobs can be created without MO
- ✅ OEM production requires MO
- ✅ Graph selection working for both types
- ✅ Schedule validation enforced for OEM
- ✅ Auto-spawn working
- ✅ Work Queue shows production_type

### **User Experience:**
- ✅ Hatthasilpa: 1 click to start
- ✅ OEM: Clear 3-step process
- ✅ No confusion between types
- ✅ Appropriate validation messages

### **Data Integrity:**
- ✅ All production_type values set
- ✅ OEM jobs have MO
- ✅ Graph instances linked correctly
- ✅ Tokens traceable to source

### **Performance:**
- ✅ Auto-spawn < 2 seconds for 1000 tokens
- ✅ Work Queue queries < 100ms
- ✅ No breaking changes

---

## 📅 Timeline

| Phase | Duration | Dependencies | Deliverable |
|-------|----------|--------------|-------------|
| 1. Database | 1 hour | None | Migration applied |
| 2. Atelier Page | 3 hours | Phase 1 | New page working |
| 3. OEM MO | 2 hours | Phase 1 | Enhanced MO page |
| 4. Business Rules | 2 hours | Phase 1 | Validation service |
| 5. Work Queue | 1 hour | Phase 2,3 | Enhanced display |
| 6. Testing | 1-2 hours | All | All tests passing |

**Total:** 10 hours (1-2 days)

---

## 🚨 Risks & Mitigations

### **Risk 1: Breaking existing workflows**
- **Mitigation:** Backward compatible migration (default values set)
- **Testing:** Verify existing linear jobs still work

### **Risk 2: User confusion during transition**
- **Mitigation:** Clear documentation, training materials
- **Communication:** Explain dual model to users

### **Risk 3: Data migration issues**
- **Mitigation:** Dry run on dev database first
- **Rollback:** Can revert migration if needed

---

## 💡 Key Design Decisions

### **Decision 1: Separate Pages vs Unified**
**Chosen:** Separate Pages ⭐
- `Manufacturing Orders` (OEM)
- `Hatthasilpa Jobs` (Luxury)

**Rationale:**
- Clearer UX
- Different workflows
- No confusion

---

### **Decision 2: Auto-assign vs Manual**
**Chosen:** Hybrid ⭐
- Auto-assign by default (load balancing)
- Manual override available (Manager Assignment page)

**Rationale:**
- Reduces manager workload
- Still allows manual control
- Best of both worlds

---

### **Decision 3: Job Ticket Role**
**Chosen:** Keep for Linear, Optional for DAG ⭐

**For DAG:**
- Hatthasilpa: Job Ticket = optional wrapper (if MO exists)
- OEM: No Job Ticket (MO → Graph Instance directly)

**For Linear:**
- Job Ticket still used (backward compatibility)

**Rationale:**
- Clean DAG architecture
- Backward compatible
- Clear separation

---

## 📚 Related Documents

**Planning:**
- `DUAL_PRODUCTION_MODEL_DESIGN.md` - This document
- `PRODUCTION_FLOW_ANALYSIS.md` - Flow comparison
- `ROADMAP_V3.md` - Priority tracking

**Original Vision:**
- `docs/BELLAVIER_OPERATION_SYSTEM_DESIGN.md` - Business context
- `docs/archive/2025-q4/OPERATOR_SESSION_FLOW_ANALYSIS.md` - Atelier vs OEM requirements

**Current System:**
- `docs/DAG_MASTER_GUIDE.md` - DAG architecture
- `docs/WORK_QUEUE_OPERATOR_JOURNEY.md` - Operator UX

---

## 🎊 Expected Outcome

### **Before (Current):**
```
❌ One workflow for both types
❌ Manager: 4-5 steps
❌ Confusing schedule (MO vs Job Ticket)
❌ Cannot enforce OEM rules
❌ Atelier too complex
```

### **After (Fixed):**
```
✅ Two distinct workflows
✅ Hatthasilpa: 1 step (Create & Start)
✅ OEM: 3 steps (Create → Schedule → Start)
✅ Clear business rules per type
✅ Simplified UX
✅ Production-ready for BOTH lines
```

---

## 🚀 Deployment Strategy

### **Phase A: Development (10 hours)**
- Implement all 6 phases
- Test thoroughly
- Document changes

### **Phase B: Staging (2 hours)**
- Deploy to staging
- Manager training (1 hour)
- Operator walkthrough (1 hour)

### **Phase C: Production (1 hour)**
- Apply migration
- Deploy code
- Monitor first jobs

**Total:** 13 hours end-to-end

---

## 📈 Success Metrics

### **Manager Experience:**
- Atelier creation time: < 2 minutes
- OEM creation time: < 5 minutes
- Workflow clarity: 9/10+
- Error rate: < 5%

### **Operator Experience:**
- Token context clarity: 10/10
- Can identify MO/Job: 100%
- Work start time: < 30 seconds

### **System Quality:**
- Production_type coverage: 100%
- Validation accuracy: 100%
- No breaking changes: ✅

---

## 🎯 Conclusion

**This is a CRITICAL missing piece!**

The system built excellent DAG infrastructure, but **forgot the original dual business model**.

**Must implement before production deployment** to align with Bellavier's reality:
- 🎨 Atelier (luxury, flexible)
- 🏭 OEM (mass, strict)

**Timeline:** 10 hours  
**Value:** 🔥 CRITICAL  
**Risk:** Low  
**Priority:** 1.5 (before Priority 2)

---

**Ready for implementation upon approval! 🚀**

