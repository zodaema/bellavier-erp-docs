# 🎯 Production Control Center - Implementation Plan

**Created:** November 5, 2025  
**Purpose:** Unified control center for both OEM and Atelier production  
**Based on:** Project's actual structure (not assumptions)

---

## 📁 **Project Structure (Confirmed)**

```
index.php                    # Router (loads page/ + views/)
├─ page/                     # Page definitions ($page_detail)
│  └─ production_control.php # NEW: Our page definition
├─ views/                    # HTML templates
│  └─ production_control.php # NEW: Our UI
├─ source/                   # Backend APIs
│  ├─ atelier_jobs_api.php   # EXISTS: Atelier endpoints
│  ├─ mo.php                 # EXISTS: MO endpoints
│  └─ production_control_api.php # NEW: Aggregation (optional)
├─ assets/javascripts/       # Frontend JS
│  └─ production/
│     └─ control_center.js   # NEW: Main JS logic
└─ assets/stylesheets/       # CSS
   └─ production_control.css # NEW: Custom styles
```

---

## 🎯 **Design Overview: 3 Modes in One Page**

### Mode Structure:
```
┌────────────────────────────────────────────────────────────┐
│  HEADER: Global Search + Quick Filters + Mode Tabs        │
├────────────────────────────────────────────────────────────┤
│          │                                                 │
│  LEFT    │          MAIN CANVAS                            │
│  SIDEBAR │  ┌──────────────────────────────────────┐      │
│          │  │                                       │      │
│  Filters │  │  [PLAN] Calendar/Gantt                │  RIG│
│  Views   │  │  [RUN]  Queue/Kanban + Commands       │  HT │
│  Lanes   │  │  [INSPECT] Flow/People/Progress       │  DRA│
│          │  │                                       │  WER │
│          │  └──────────────────────────────────────┘      │
│          │                                                 │
├────────────────────────────────────────────────────────────┤
│  LIVE ACTIVITY PANEL: Recent logs (auto-refresh 15s)      │
└────────────────────────────────────────────────────────────┘
```

---

## 📋 **Implementation Phases**

### **Phase 1: Foundation (Week 1, Days 1-2)**
**Goal:** Basic structure + Run mode (most critical)

**Files to Create:**

1. **`page/production_control.php`**
```php
<?php
/**
 * Production Control Center Page Definition
 */

$page_detail['name'] = translate('production.control_center', 'Production Control Center');
$page_detail['subname'] = translate('manufacturing.title', 'Manufacturing');
$page_detail['permission_code'] = 'production.control_center'; // NEW permission

// CSS
$page_detail['css'][1] = domain::getDomain().'/assets/vendor/datatables/2.3.2/css/dataTables.bootstrap5.css';
$page_detail['css'][2] = 'views/template/sash/assets/libs/sweetalert2/sweetalert2.min.css';
$page_detail['css'][3] = domain::getDomain().'/assets/vendor/fullcalendar/fullcalendar.min.css'; // For Plan mode
$page_detail['css'][4] = domain::getDomain().'/assets/stylesheets/production_control.css?v='.time();

// JS Libraries (following project pattern: index [1-4] for libraries)
$page_detail['jquery'][1] = domain::getDomain().'/assets/vendor/datatables/2.3.2/js/dataTables.js';
$page_detail['jquery'][2] = domain::getDomain().'/assets/vendor/datatables/2.3.2/js/dataTables.bootstrap5.js';
$page_detail['jquery'][3] = domain::getDomain().'/assets/vendor/toastr/js/toastr.min.js';
$page_detail['jquery'][4] = 'views/template/sash/assets/libs/sweetalert2/sweetalert2.min.js';
$page_detail['jquery'][5] = domain::getDomain().'/assets/vendor/fullcalendar/fullcalendar.min.js';

// Custom JS (index [6] following project pattern)
$page_detail['jquery'][6] = domain::getDomain().'/assets/javascripts/production/control_center.js?v='.time();
?>
```

2. **`views/production_control.php`**
```html
<!-- Header Bar -->
<div class="main-content app-content">
  <div class="container-fluid p-4">
    
    <!-- Header -->
    <div class="page-header mb-4">
      <div class="row align-items-center">
        <div class="col-md-4">
          <h1 class="page-title">
            <i class="ri-command-line me-2"></i>
            Production Control Center
          </h1>
        </div>
        <div class="col-md-5">
          <!-- Global Search -->
          <input type="text" id="globalSearch" class="form-control" 
                 placeholder="Search MO, Ticket, SKU, Serial...">
        </div>
        <div class="col-md-3 text-end">
          <!-- Quick Filters -->
          <div class="btn-group btn-group-sm" role="group">
            <button type="button" class="btn btn-outline-danger" data-filter="late">Late</button>
            <button type="button" class="btn btn-outline-warning" data-filter="today">Today</button>
            <button type="button" class="btn btn-outline-info" data-filter="in-progress">In Progress</button>
            <button type="button" class="btn btn-outline-success" data-filter="qc">QC</button>
          </div>
        </div>
      </div>
      
      <!-- Mode Tabs -->
      <ul class="nav nav-tabs mt-3" id="modeTabs" role="tablist">
        <li class="nav-item" role="presentation">
          <button class="nav-link" data-bs-toggle="tab" data-bs-target="#planMode" 
                  type="button" role="tab">
            <i class="ri-calendar-line me-1"></i> Plan
          </button>
        </li>
        <li class="nav-item" role="presentation">
          <button class="nav-link active" data-bs-toggle="tab" data-bs-target="#runMode" 
                  type="button" role="tab">
            <i class="ri-play-circle-line me-1"></i> Run
          </button>
        </li>
        <li class="nav-item" role="presentation">
          <button class="nav-link" data-bs-toggle="tab" data-bs-target="#inspectMode" 
                  type="button" role="tab">
            <i class="ri-search-eye-line me-1"></i> Inspect
          </button>
        </li>
      </ul>
    </div>
    
    <!-- Main Layout -->
    <div class="row">
      <!-- Left Sidebar (Filters) -->
      <div class="col-md-2">
        <div class="card">
          <div class="card-header">
            <h6 class="mb-0">Lanes</h6>
          </div>
          <div class="card-body p-0">
            <div class="list-group list-group-flush">
              <button class="list-group-item list-group-item-action" data-lane="mo-backlog">
                🏭 MO Backlog
              </button>
              <button class="list-group-item list-group-item-action" data-lane="mo-scheduled">
                🏭 MO Scheduled
              </button>
              <button class="list-group-item list-group-item-action" data-lane="mo-production">
                🏭 MO In Production
              </button>
              <button class="list-group-item list-group-item-action" data-lane="atelier-all">
                🎨 Atelier All
              </button>
              <button class="list-group-item list-group-item-action" data-lane="atelier-mine">
                🎨 Atelier Mine
              </button>
              <button class="list-group-item list-group-item-action" data-lane="hybrid">
                🔗 Linked (Hybrid)
              </button>
            </div>
          </div>
        </div>
        
        <!-- Saved Views -->
        <div class="card mt-3">
          <div class="card-header">
            <h6 class="mb-0">Saved Views</h6>
          </div>
          <div class="card-body">
            <small class="text-muted">Coming soon...</small>
          </div>
        </div>
      </div>
      
      <!-- Main Canvas -->
      <div class="col-md-7">
        <div class="tab-content" id="modeTabContent">
          
          <!-- PLAN MODE -->
          <div class="tab-pane fade" id="planMode" role="tabpanel">
            <div class="card">
              <div class="card-body">
                <div id="planCalendar"></div>
              </div>
            </div>
          </div>
          
          <!-- RUN MODE (Default) -->
          <div class="tab-pane fade show active" id="runMode" role="tabpanel">
            <!-- Command Bar -->
            <div class="card mb-3">
              <div class="card-body p-2">
                <div class="btn-group btn-group-sm" role="group">
                  <button type="button" class="btn btn-success" id="btnStart">
                    <i class="ri-play-line"></i> Start
                  </button>
                  <button type="button" class="btn btn-warning" id="btnPause">
                    <i class="ri-pause-line"></i> Pause
                  </button>
                  <button type="button" class="btn btn-danger" id="btnCancel">
                    <i class="ri-close-line"></i> Cancel
                  </button>
                  <button type="button" class="btn btn-info" id="btnAssign">
                    <i class="ri-user-add-line"></i> Assign
                  </button>
                  <button type="button" class="btn btn-secondary" id="btnRecalc">
                    <i class="ri-refresh-line"></i> Recalc
                  </button>
                </div>
                
                <div class="btn-group btn-group-sm ms-2" role="group">
                  <button type="button" class="btn btn-outline-primary" id="btnViewTable">
                    <i class="ri-table-line"></i> Table
                  </button>
                  <button type="button" class="btn btn-outline-primary" id="btnViewKanban">
                    <i class="ri-layout-grid-line"></i> Kanban
                  </button>
                </div>
              </div>
            </div>
            
            <!-- Work Queue Table -->
            <div class="card" id="queueTable">
              <div class="card-header">
                <h6 class="mb-0">Work Queue</h6>
              </div>
              <div class="card-body">
                <table id="workQueueDataTable" class="table table-hover" style="width:100%">
                  <thead>
                    <tr>
                      <th><input type="checkbox" id="selectAll"></th>
                      <th>Code</th>
                      <th>Type</th>
                      <th>Product</th>
                      <th>Qty</th>
                      <th>Due</th>
                      <th>Status</th>
                      <th>Progress</th>
                      <th>Assigned</th>
                    </tr>
                  </thead>
                  <tbody></tbody>
                </table>
              </div>
            </div>
            
            <!-- Kanban Board (hidden by default) -->
            <div class="card d-none" id="kanbanBoard">
              <div class="card-body">
                <div class="row">
                  <div class="col-md-3">
                    <h6>Planned</h6>
                    <div id="kanbanPlanned" class="kanban-column"></div>
                  </div>
                  <div class="col-md-3">
                    <h6>In Progress</h6>
                    <div id="kanbanInProgress" class="kanban-column"></div>
                  </div>
                  <div class="col-md-3">
                    <h6>QC</h6>
                    <div id="kanbanQC" class="kanban-column"></div>
                  </div>
                  <div class="col-md-3">
                    <h6>Done</h6>
                    <div id="kanbanDone" class="kanban-column"></div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <!-- INSPECT MODE -->
          <div class="tab-pane fade" id="inspectMode" role="tabpanel">
            <div class="card">
              <div class="card-body">
                <p class="text-muted">Select an item from the queue to inspect details.</p>
              </div>
            </div>
          </div>
          
        </div>
      </div>
      
      <!-- Right Drawer (Details) -->
      <div class="col-md-3">
        <div class="card">
          <div class="card-header">
            <h6 class="mb-0">Details</h6>
          </div>
          <div class="card-body" id="detailDrawer">
            <p class="text-muted">Click an item to view details</p>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Live Activity Panel -->
    <div class="row mt-3">
      <div class="col-12">
        <div class="card">
          <div class="card-header">
            <h6 class="mb-0">
              <i class="ri-pulse-line me-2"></i>
              Live Activity
              <span class="badge bg-success ms-2">Auto-refresh: 15s</span>
            </h6>
          </div>
          <div class="card-body">
            <div id="liveActivityTimeline"></div>
          </div>
        </div>
      </div>
    </div>
    
  </div>
</div>
```

3. **`assets/javascripts/production/control_center.js`**
```javascript
;(function($) {
    'use strict';
    
    // === CONFIGURATION ===
    const API = {
        MO: 'source/mo.php',
        ATELIER: 'source/atelier_jobs_api.php',
        TICKET: 'source/atelier_job_ticket.php'
    };
    
    const REFRESH_INTERVAL = 15000; // 15 seconds
    
    // === STATE ===
    let currentMode = 'run';
    let currentLane = 'mo-backlog';
    let selectedItems = [];
    let autoRefreshTimer = null;
    
    // === INITIALIZATION ===
    $(document).ready(function() {
        initializeDataTable();
        setupEventHandlers();
        startAutoRefresh();
        
        // Load initial data
        loadWorkQueue();
    });
    
    // === DATA TABLE ===
    function initializeDataTable() {
        window.workQueueTable = $('#workQueueDataTable').DataTable({
            ajax: {
                url: API.MO, // Dynamic based on lane
                type: 'POST',
                data: function(d) {
                    d.action = 'list';
                    d.lane = currentLane;
                    return d;
                }
            },
            columns: [
                { 
                    data: null,
                    orderable: false,
                    render: function(data, type, row) {
                        return `<input type="checkbox" class="item-checkbox" data-id="${row.id}" data-type="${row.type}">`;
                    }
                },
                { data: 'code' },
                { 
                    data: 'type',
                    render: function(data) {
                        return data === 'mo' ? 
                            '<span class="badge bg-primary">🏭 MO</span>' :
                            '<span class="badge bg-info">🎨 Atelier</span>';
                    }
                },
                { data: 'product_name' },
                { data: 'qty' },
                { data: 'due_date' },
                { 
                    data: 'status',
                    render: function(data) {
                        const badges = {
                            'planned': 'secondary',
                            'scheduled': 'info',
                            'in_progress': 'warning',
                            'qc': 'primary',
                            'done': 'success'
                        };
                        return `<span class="badge bg-${badges[data] || 'secondary'}">${data}</span>`;
                    }
                },
                { 
                    data: 'progress_pct',
                    render: function(data) {
                        return `<div class="progress">
                            <div class="progress-bar" style="width: ${data}%">${data}%</div>
                        </div>`;
                    }
                },
                { data: 'assigned_to_name' }
            ],
            serverSide: true,
            processing: true
        });
        
        // Row click handler
        $('#workQueueDataTable tbody').on('click', 'tr', function() {
            const row = workQueueTable.row(this).data();
            showDetailDrawer(row);
        });
    }
    
    // === EVENT HANDLERS ===
    function setupEventHandlers() {
        // Mode tabs
        $('[data-bs-toggle="tab"]').on('shown.bs.tab', function(e) {
            currentMode = $(e.target).data('bs-target').replace('#', '').replace('Mode', '');
            console.log('Mode changed:', currentMode);
        });
        
        // Lane filters
        $('[data-lane]').on('click', function() {
            currentLane = $(this).data('lane');
            $('[data-lane]').removeClass('active');
            $(this).addClass('active');
            reloadWorkQueue();
        });
        
        // Command buttons
        $('#btnStart').on('click', handleStart);
        $('#btnPause').on('click', handlePause);
        $('#btnCancel').on('click', handleCancel);
        $('#btnAssign').on('click', handleAssign);
        $('#btnRecalc').on('click', handleRecalc);
        
        // View toggles
        $('#btnViewTable').on('click', showTableView);
        $('#btnViewKanban').on('click', showKanbanView);
        
        // Select all checkbox
        $('#selectAll').on('change', function() {
            $('.item-checkbox').prop('checked', $(this).prop('checked'));
            updateSelectedItems();
        });
        
        // Individual checkboxes
        $(document).on('change', '.item-checkbox', updateSelectedItems);
    }
    
    // === DATA LOADING ===
    function loadWorkQueue() {
        workQueueTable.ajax.reload();
        loadLiveActivity();
    }
    
    function reloadWorkQueue() {
        // Change API endpoint based on lane
        const apiUrl = currentLane.startsWith('mo-') ? API.MO : API.ATELIER;
        workQueueTable.ajax.url(apiUrl).load();
    }
    
    function loadLiveActivity() {
        $.get(API.TICKET, {
            action: 'log_list',
            limit: 50,
            order: 'DESC'
        }, function(resp) {
            if (resp.ok && resp.data) {
                renderLiveActivity(resp.data);
            }
        }, 'json');
    }
    
    function renderLiveActivity(logs) {
        const $timeline = $('#liveActivityTimeline');
        $timeline.empty();
        
        logs.forEach(log => {
            $timeline.append(`
                <div class="activity-item">
                    <span class="badge bg-${getEventBadge(log.event_type)}">${log.event_type}</span>
                    <strong>${log.operator_name}</strong> 
                    on <code>${log.ticket_code}</code>
                    <small class="text-muted">${log.event_time}</small>
                </div>
            `);
        });
    }
    
    function getEventBadge(eventType) {
        const badges = {
            'start': 'success',
            'pause': 'warning',
            'resume': 'info',
            'complete': 'primary',
            'qc_pass': 'success',
            'qc_fail': 'danger'
        };
        return badges[eventType] || 'secondary';
    }
    
    // === DETAIL DRAWER ===
    function showDetailDrawer(item) {
        const $drawer = $('#detailDrawer');
        
        // Fetch full details
        const api = item.type === 'mo' ? API.MO : API.TICKET;
        const idField = item.type === 'mo' ? 'id_mo' : 'id_job_ticket';
        
        $.get(api, {
            action: 'get',
            [idField]: item.id
        }, function(resp) {
            if (resp.ok && resp.data) {
                renderDetailDrawer(resp.data, item.type);
            }
        }, 'json');
    }
    
    function renderDetailDrawer(data, type) {
        const $drawer = $('#detailDrawer');
        
        if (type === 'mo') {
            $drawer.html(`
                <h6>${data.mo_code}</h6>
                <dl class="row">
                    <dt class="col-6">Product:</dt>
                    <dd class="col-6">${data.product_name}</dd>
                    
                    <dt class="col-6">Qty:</dt>
                    <dd class="col-6">${data.qty}</dd>
                    
                    <dt class="col-6">Due:</dt>
                    <dd class="col-6">${data.due_date}</dd>
                    
                    <dt class="col-6">Status:</dt>
                    <dd class="col-6">${data.status}</dd>
                </dl>
                
                <div class="d-grid gap-2">
                    <button class="btn btn-sm btn-success" onclick="handleMOStart(${data.id_mo})">
                        Start Production
                    </button>
                    <button class="btn btn-sm btn-warning" onclick="handleMOSchedule(${data.id_mo})">
                        Schedule
                    </button>
                </div>
            `);
        } else {
            $drawer.html(`
                <h6>${data.ticket_code}</h6>
                <dl class="row">
                    <dt class="col-6">Job:</dt>
                    <dd class="col-6">${data.job_name}</dd>
                    
                    <dt class="col-6">Target:</dt>
                    <dd class="col-6">${data.target_qty}</dd>
                    
                    <dt class="col-6">Progress:</dt>
                    <dd class="col-6">${data.progress_pct}%</dd>
                    
                    <dt class="col-6">Status:</dt>
                    <dd class="col-6">${data.status}</dd>
                </dl>
                
                <div class="d-grid gap-2">
                    <button class="btn btn-sm btn-info" onclick="showTaskList(${data.id_job_ticket})">
                        View Tasks
                    </button>
                    <button class="btn btn-sm btn-secondary" onclick="handleRecalcSingle(${data.id_job_ticket})">
                        Recalc Sessions
                    </button>
                </div>
            `);
        }
    }
    
    // === COMMAND HANDLERS ===
    function handleStart() {
        if (selectedItems.length === 0) {
            toastr.warning('Please select items');
            return;
        }
        
        Swal.fire({
            title: 'Start Production?',
            text: `Start ${selectedItems.length} item(s)?`,
            icon: 'question',
            showCancelButton: true
        }).then((result) => {
            if (result.isConfirmed) {
                // Bulk start logic
                selectedItems.forEach(item => {
                    const api = item.type === 'mo' ? API.MO : API.TICKET;
                    $.post(api, {
                        action: 'start',
                        id: item.id
                    }, function(resp) {
                        if (resp.ok) {
                            toastr.success(`Started ${item.code}`);
                        }
                    }, 'json');
                });
                
                setTimeout(reloadWorkQueue, 1000);
            }
        });
    }
    
    function handlePause() {
        // Similar to handleStart
    }
    
    function handleCancel() {
        // Similar to handleStart
    }
    
    function handleAssign() {
        if (selectedItems.length === 0) {
            toastr.warning('Please select items');
            return;
        }
        
        // Load users for assignment
        $.get(API.TICKET, {
            action: 'users_for_assignment'
        }, function(resp) {
            if (resp.ok && resp.data) {
                showAssignModal(resp.data);
            }
        }, 'json');
    }
    
    function showAssignModal(users) {
        const options = users.map(u => 
            `<option value="${u.id_member}">${u.name}</option>`
        ).join('');
        
        Swal.fire({
            title: 'Assign to Operator',
            html: `
                <select id="swalOperator" class="form-control">
                    <option value="">-- Select Operator --</option>
                    ${options}
                </select>
            `,
            showCancelButton: true,
            preConfirm: () => {
                const operatorId = $('#swalOperator').val();
                if (!operatorId) {
                    Swal.showValidationMessage('Please select an operator');
                    return false;
                }
                return operatorId;
            }
        }).then((result) => {
            if (result.isConfirmed) {
                bulkAssign(result.value);
            }
        });
    }
    
    function bulkAssign(operatorId) {
        selectedItems.forEach(item => {
            if (item.type === 'atelier') {
                $.post(API.TICKET, {
                    action: 'task_assign',
                    id_job_task: item.id,
                    assigned_to: operatorId
                }, function(resp) {
                    if (resp.ok) {
                        toastr.success(`Assigned ${item.code}`);
                    }
                }, 'json');
            }
        });
        
        setTimeout(reloadWorkQueue, 1000);
    }
    
    function handleRecalc() {
        if (selectedItems.length === 0) {
            toastr.warning('Please select items');
            return;
        }
        
        selectedItems.forEach(item => {
            if (item.type === 'atelier') {
                $.post(API.TICKET, {
                    action: 'recalc_sessions',
                    id_job_ticket: item.id
                }, function(resp) {
                    if (resp.ok) {
                        toastr.success(`Recalculated ${item.code}`);
                    }
                }, 'json');
            }
        });
        
        setTimeout(reloadWorkQueue, 1000);
    }
    
    // === VIEW TOGGLES ===
    function showTableView() {
        $('#queueTable').removeClass('d-none');
        $('#kanbanBoard').addClass('d-none');
    }
    
    function showKanbanView() {
        $('#queueTable').addClass('d-none');
        $('#kanbanBoard').removeClass('d-none');
        loadKanbanData();
    }
    
    function loadKanbanData() {
        // TODO: Implement kanban board loading
    }
    
    // === AUTO REFRESH ===
    function startAutoRefresh() {
        autoRefreshTimer = setInterval(function() {
            if (currentMode === 'run') {
                loadLiveActivity();
            }
        }, REFRESH_INTERVAL);
    }
    
    // === HELPERS ===
    function updateSelectedItems() {
        selectedItems = [];
        $('.item-checkbox:checked').each(function() {
            selectedItems.push({
                id: $(this).data('id'),
                type: $(this).data('type'),
                code: $(this).closest('tr').find('td:nth-child(2)').text()
            });
        });
        console.log('Selected items:', selectedItems);
    }
    
    // === EXPOSE FUNCTIONS FOR INLINE HANDLERS ===
    window.handleMOStart = function(moId) {
        $.post(API.MO, {
            action: 'start',
            id_mo: moId
        }, function(resp) {
            if (resp.ok) {
                toastr.success('MO started');
                reloadWorkQueue();
            } else {
                toastr.error(resp.error || 'Failed to start MO');
            }
        }, 'json');
    };
    
    window.handleMOSchedule = function(moId) {
        // TODO: Show schedule modal
    };
    
    window.showTaskList = function(ticketId) {
        // TODO: Show task list in drawer
    };
    
    window.handleRecalcSingle = function(ticketId) {
        $.post(API.TICKET, {
            action: 'recalc_sessions',
            id_job_ticket: ticketId
        }, function(resp) {
            if (resp.ok) {
                toastr.success('Sessions recalculated');
                reloadWorkQueue();
            }
        }, 'json');
    };
    
})(jQuery);
```

---

## 📋 **API Endpoints Mapping**

### **Existing APIs (No changes needed):**

**Atelier (source/atelier_job_ticket.php):**
- `list` → Ticket queue
- `get` → Ticket detail
- `task_list` → Tasks for ticket
- `log_list` → Event logs
- `users_for_assignment` → Operator list
- `task_assign` → Assign task
- `task_update_status` → Update status
- `recalc_sessions` → Recalculate
- `generate_serials` → Generate serials
- `ticket_qr` → QR code
- `task_qr` → Task QR

**MO (source/mo.php):**
- `list` → MO queue
- `get` → MO detail
- `products` → Product list
- `create` → New MO

### **APIs to Add (source/mo.php):**

```php
case 'schedule':
    must_allow_code($member, 'mo.schedule');
    $id_mo = (int)($_POST['id_mo'] ?? 0);
    $start_date = trim($_POST['start_date'] ?? '');
    $end_date = trim($_POST['end_date'] ?? '');
    
    // Update schedule
    $stmt = $tenantDb->prepare("
        UPDATE mo 
        SET scheduled_start_date = ?,
            scheduled_end_date = ?,
            status = 'scheduled'
        WHERE id_mo = ?
    ");
    $stmt->bind_param('ssi', $start_date, $end_date, $id_mo);
    $stmt->execute();
    
    json_success(['message' => 'MO scheduled']);
    break;

case 'update_due':
    must_allow_code($member, 'mo.edit');
    $id_mo = (int)($_POST['id_mo'] ?? 0);
    $due_date = trim($_POST['due_date'] ?? '');
    
    $stmt = $tenantDb->prepare("UPDATE mo SET due_date = ? WHERE id_mo = ?");
    $stmt->bind_param('si', $due_date, $id_mo);
    $stmt->execute();
    
    json_success(['message' => 'Due date updated']);
    break;

case 'start':
    // Already exists but verify it works
    break;

case 'cancel':
    must_allow_code($member, 'mo.cancel');
    $id_mo = (int)($_POST['id_mo'] ?? 0);
    
    $stmt = $tenantDb->prepare("UPDATE mo SET status = 'cancelled' WHERE id_mo = ?");
    $stmt->bind_param('i', $id_mo);
    $stmt->execute();
    
    json_success(['message' => 'MO cancelled']);
    break;
```

---

## 🎯 **Phase 2-4 (Future)**

### **Phase 2: Plan Mode (Week 1, Days 3-5)**
- Calendar view integration
- Gantt chart
- Capacity heatmap
- Bulk schedule

### **Phase 3: Inspect Mode (Week 2, Days 1-3)**
- Flow visualization
- Detailed task view
- People view (who's doing what)
- Enhanced logs

### **Phase 4: Advanced Features (Week 2, Days 4-5)**
- Saved views (localStorage)
- Keyboard shortcuts
- Export/print
- Real-time updates (optional WebSocket)

---

## 📋 **Implementation Checklist**

### **Day 1:**
- [x] Create file structure plan
- [ ] Create `page/production_control.php`
- [ ] Create `views/production_control.php`
- [ ] Create `assets/javascripts/production/control_center.js`
- [ ] Add menu item in sidebar
- [ ] Test basic page loading

### **Day 2:**
- [ ] Implement Run mode (Queue table)
- [ ] Connect to atelier_jobs_api.php
- [ ] Connect to mo.php
- [ ] Test lane switching
- [ ] Test detail drawer

### **Day 3-5:**
- [ ] Add MO schedule/cancel endpoints
- [ ] Implement command buttons
- [ ] Add bulk actions
- [ ] Test live activity
- [ ] Polish UI

---

## 🚀 **Quick Start Commands**

```bash
# 1. Create directories
mkdir -p assets/javascripts/production
mkdir -p assets/stylesheets

# 2. Create files (already have templates above)

# 3. Add permission to database
# Run in MySQL:
INSERT INTO permission (code, name, description) VALUES
('production.control_center', 'Production Control Center', 'Access to unified production control center');

# 4. Add menu item in views/template/sidebar-left.template.php
# (Find manufacturing section and add)

# 5. Test
# Navigate to: index.php?p=production_control
```

---

**Status:** Ready for implementation  
**Estimated Time:** 5 days (1 week)  
**Dependencies:** None (uses existing APIs)

