# PWA Improvements Analysis - Roadmap Alignment

**Created:** November 15, 2025  
**Purpose:** Identify PWA improvements needed to align with DAG Implementation Roadmap  
**Status:** 📋 Analysis Complete

---

## 📊 Executive Summary

**Current State:**
- ✅ PWA Scan Station (Phase 2A) - Complete
- ⚠️ Work Queue (Phase 2B) - Partial (2B.1-2B.4 Complete, 2B.5-2B.6 Pending)
- ⏳ Component Model (Phase 4.0) - Not Started

**Critical Gaps:**
1. **Node-Type Aware UX** (Phase 2B.5) - NOT IMPLEMENTED ⚠️ CRITICAL
2. **Mobile Optimization** (Phase 2B.6) - Partial (List view exists but needs enhancement)
3. **Component Display** (Phase 4.0) - NOT IMPLEMENTED
4. **QC Pass/Fail Actions** (Phase 2B.5) - NOT IMPLEMENTED

---

## 🔍 Detailed Analysis

### 1. **Node-Type Aware Work Queue UX (Phase 2B.5) - CRITICAL**

#### **Current State:**

**API (`dag_token_api.php::handleGetWorkQueue()`):**
- ✅ Returns `node_type` in response (line 1711)
- ❌ Does NOT filter by node_type (shows START/END/SPLIT/JOIN/system nodes)
- ❌ Does NOT exclude non-operable nodes

**Frontend (`work_queue.js`):**
- ✅ Has `getNodeIcon()` function (line 523) that recognizes node types
- ❌ Does NOT filter columns by node_type
- ❌ Shows all nodes regardless of type
- ❌ Does NOT hide START/END/SPLIT/JOIN/system nodes
- ❌ Does NOT show QC-specific actions (Pass/Fail)

**PWA Scan (`pwa_scan.js`):**
- ✅ Has `getNodeTypeIcon()` function (line 2109)
- ❌ Does NOT check `node_type` before showing actions
- ❌ Shows Start/Pause/Complete for ALL node types
- ❌ Does NOT show Pass/Fail for QC nodes

#### **Required Changes:**

**1.1 API Filtering (`dag_token_api.php`):**
```php
// In handleGetWorkQueue() - Add filtering
$sql = "
    SELECT ft.*, rn.node_type, rn.node_name
    FROM flow_token ft
    INNER JOIN routing_node rn ON rn.id_node = ft.current_node_id
    WHERE ft.status IN ('ready', 'active', 'paused')
        AND rn.node_type IN ('operation', 'qc')  -- ✅ Only show operable nodes
        AND rn.node_type != 'system'  -- ✅ Hide system nodes
    ...
";
```

**1.2 Frontend Column Filtering (`work_queue.js`):**
```javascript
// In renderWorkQueue() - Filter nodes before rendering
function renderWorkQueue(nodes) {
    // Filter out non-operable nodes
    const operableNodes = nodes.filter(node => {
        const nodeType = node.node_type || 'operation';
        return ['operation', 'qc'].includes(nodeType);
    });
    
    // Render only operable nodes
    if (viewMode === 'list' || isMobile()) {
        renderListView(operableNodes, $container);
    } else {
        renderKanbanView(operableNodes, $container);
    }
}
```

**1.3 QC Node Actions (`work_queue.js`):**
```javascript
// In renderKanbanTokenCard() - Add QC-specific actions
function renderKanbanTokenCard(token, groupType) {
    const nodeType = token.node_type || 'operation';
    
    // QC nodes: Show Pass/Fail instead of Start/Pause/Complete
    if (nodeType === 'qc' && token.status === 'ready') {
        actionButtons = `
            <button class="btn btn-sm btn-success btn-qc-pass" 
                    data-token-id="${token.id_token}">
                <i class="ri-check-line"></i> ${t('work_queue.action.pass', 'Pass')}
            </button>
            <button class="btn btn-sm btn-danger btn-qc-fail" 
                    data-token-id="${token.id_token}">
                <i class="ri-close-line"></i> ${t('work_queue.action.fail', 'Fail')}
            </button>
        `;
    } else if (nodeType === 'operation') {
        // Normal operation actions
        // ... existing code ...
    }
    // START/END/SPLIT/JOIN nodes should not appear (filtered by API)
}
```

**1.4 PWA Scan Token Actions (`pwa_scan.js`):**
```javascript
// In renderDagTokenView() - Check node_type before showing actions
function renderDagTokenView(token, headerHtml) {
    const nodeType = token.node_type || 'operation';
    const currentNode = token.current_node || {};
    
    // QC nodes: Show Pass/Fail buttons
    if (nodeType === 'qc' && token.status === 'ready') {
        actionButtons = `
            <button class="btn btn-success btn-lg w-100 mb-2" id="btn-qc-pass">
                <i class="ri-check-line"></i> ${t('pwa.action.pass', 'Pass')}
            </button>
            <button class="btn btn-danger btn-lg w-100" id="btn-qc-fail">
                <i class="ri-close-line"></i> ${t('pwa.action.fail', 'Fail')}
            </button>
        `;
    } else if (nodeType === 'operation') {
        // Normal operation actions (Start/Pause/Complete)
        // ... existing code ...
    } else {
        // START/END/SPLIT/JOIN nodes: No actions
        actionButtons = `
            <div class="alert alert-info">
                <i class="ri-information-line"></i> 
                ${t('pwa.info.system_node', 'System node - no operator actions')}
            </div>
        `;
    }
}
```

---

### 2. **Mobile-Optimized Work Queue UX (Phase 2B.6) - PARTIAL**

#### **Current State:**

**Frontend (`work_queue.js`):**
- ✅ Has List view implementation (line 244)
- ✅ Has mobile detection (`isMobile()` function)
- ✅ Has responsive breakpoint logic
- ⚠️ List view exists but needs enhancement:
  - Missing node filter/tabs
  - Missing "My Tasks" default filter
  - Missing toggle between List/Kanban views

#### **Required Changes:**

**2.1 Node Filter/Tabs:**
```javascript
// Add node filter dropdown/tabs in List view
function renderListView(nodes, $container) {
    // Add filter header
    let html = `
        <div class="work-queue-filters mb-3">
            <div class="btn-group w-100" role="group">
                <button class="btn btn-sm btn-outline-primary active" data-filter="all">
                    ${t('work_queue.filter.all', 'All Nodes')}
                </button>
                <button class="btn btn-sm btn-outline-primary" data-filter="my_tasks">
                    ${t('work_queue.filter.my_tasks', 'My Tasks')}
                </button>
                ${nodes.map(node => `
                    <button class="btn btn-sm btn-outline-secondary" data-filter-node="${node.node_id}">
                        ${node.node_name}
                    </button>
                `).join('')}
            </div>
        </div>
    `;
    
    // ... rest of list view ...
}
```

**2.2 View Mode Toggle:**
```javascript
// Add toggle button for List/Kanban views
function addViewModeToggle() {
    const $toggle = $(`
        <div class="view-mode-toggle mb-3">
            <div class="btn-group" role="group">
                <button class="btn btn-sm ${viewMode === 'list' ? 'btn-primary' : 'btn-outline-primary'}" 
                        data-view="list">
                    <i class="ri-list-check"></i> List
                </button>
                <button class="btn btn-sm ${viewMode === 'kanban' ? 'btn-primary' : 'btn-outline-primary'}" 
                        data-view="kanban">
                    <i class="ri-layout-column-line"></i> Kanban
                </button>
            </div>
        </div>
    `);
    
    $toggle.on('click', '[data-view]', function() {
        viewMode = $(this).data('view');
        loadWorkQueue();
    });
    
    $('#work-queue-container').before($toggle);
}
```

---

### 3. **Component Model Display (Phase 4.0) - NOT IMPLEMENTED**

#### **Current State:**

**API (`dag_token_api.php`):**
- ❌ Does NOT return `component_code` in Work Queue response
- ❌ Does NOT return `root_serial` in Work Queue response
- ❌ Does NOT return `id_component` in Work Queue response

**Frontend (`work_queue.js`):**
- ❌ Does NOT display component information
- ❌ Does NOT show component badge
- ❌ Does NOT filter by component_code
- ❌ Does NOT filter by root_serial

**PWA Scan (`pwa_scan.js`):**
- ❌ Does NOT display component information
- ❌ Does NOT show root serial

#### **Required Changes:**

**3.1 API Response (`dag_token_api.php`):**
```php
// In handleGetWorkQueue() - Add component fields
$tokenData = [
    'id_token' => $token['id_token'],
    'serial_number' => $token['serial_number'],
    'component_code' => $token['component_code'],  // ✅ NEW
    'id_component' => $token['id_component'],      // ✅ NEW
    'root_serial' => $token['root_serial'],        // ✅ NEW
    'root_token_id' => $token['root_token_id'],   // ✅ NEW
    'status' => $token['status'],
    // ... rest of fields ...
];
```

**3.2 Frontend Display (`work_queue.js`):**
```javascript
// In renderKanbanTokenCard() - Add component badge
function renderKanbanTokenCard(token, groupType) {
    let componentBadge = '';
    if (token.component_code) {
        componentBadge = `
            <span class="badge bg-info mb-1">
                <i class="ri-puzzle-line"></i> ${token.component_code}
            </span>
        `;
    }
    
    let rootSerialInfo = '';
    if (token.root_serial && token.root_serial !== token.serial_number) {
        rootSerialInfo = `
            <small class="text-muted d-block">
                <i class="ri-link"></i> Root: ${token.root_serial}
            </small>
        `;
    }
    
    // Add to card HTML
    html += `
        <div class="token-header">
            <h6>${token.serial_number}</h6>
            ${componentBadge}
            ${rootSerialInfo}
        </div>
    `;
}
```

**3.3 Component Filtering:**
```javascript
// Add component filter in Work Queue
function addComponentFilter() {
    // Get unique component codes from tokens
    const componentCodes = [...new Set(tokens.map(t => t.component_code).filter(Boolean))];
    
    if (componentCodes.length > 0) {
        const $filter = $(`
            <select class="form-select form-select-sm" id="filter-component">
                <option value="">All Components</option>
                ${componentCodes.map(code => `
                    <option value="${code}">${code}</option>
                `).join('')}
            </select>
        `);
        
        $filter.on('change', function() {
            const selectedComponent = $(this).val();
            filterByComponent(selectedComponent);
        });
        
        $('#work-queue-filters').append($filter);
    }
}
```

**3.4 PWA Scan Component Display (`pwa_scan.js`):**
```javascript
// In renderDagTokenView() - Add component information
function renderDagTokenView(token, headerHtml) {
    let componentInfo = '';
    if (token.component_code) {
        componentInfo = `
            <div class="alert alert-info mb-3">
                <strong><i class="ri-puzzle-line"></i> Component:</strong> ${token.component_code}
                ${token.root_serial ? `<br><small>Root Serial: ${token.root_serial}</small>` : ''}
            </div>
        `;
    }
    
    html += componentInfo;
    // ... rest of view ...
}
```

---

### 4. **QC Pass/Fail API Endpoints**

#### **Current State:**

**API (`dag_token_api.php`):**
- ✅ Has `handleCompleteToken()` with QC support (line 2124)
- ⚠️ QC handling is embedded in complete endpoint
- ❌ No dedicated `qc_pass` and `qc_fail` endpoints

#### **Required Changes:**

**4.1 Add QC Endpoints:**
```php
// In dag_token_api.php - Add QC-specific endpoints
case 'qc_pass':
    handleQCPass($db, $userId);
    break;
    
case 'qc_fail':
    handleQCFail($db, $userId);
    break;

function handleQCPass($db, $operatorId) {
    $tokenId = (int)($_POST['token_id'] ?? 0);
    if ($tokenId <= 0) {
        json_error('Missing token_id', 400);
    }
    
    // Verify token is at QC node
    $token = db_fetch_one($db, "
        SELECT t.*, rn.node_type
        FROM flow_token t
        JOIN routing_node rn ON rn.id_node = t.current_node_id
        WHERE t.id_token = ?
    ", [$tokenId], 'i');
    
    if (!$token || $token['node_type'] !== 'qc') {
        json_error('Token is not at QC node', 400);
    }
    
    // Complete with QC pass
    handleCompleteToken($db, $operatorId, $tokenId, true, null);
}

function handleQCFail($db, $operatorId) {
    $tokenId = (int)($_POST['token_id'] ?? 0);
    $reason = $_POST['reason'] ?? '';
    
    if ($tokenId <= 0) {
        json_error('Missing token_id', 400);
    }
    
    // Verify token is at QC node
    $token = db_fetch_one($db, "
        SELECT t.*, rn.node_type
        FROM flow_token t
        JOIN routing_node rn ON rn.id_node = t.current_node_id
        WHERE t.id_token = ?
    ", [$tokenId], 'i');
    
    if (!$token || $token['node_type'] !== 'qc') {
        json_error('Token is not at QC node', 400);
    }
    
    // Complete with QC fail
    handleCompleteToken($db, $operatorId, $tokenId, false, $reason);
}
```

**4.2 Frontend QC Actions (`work_queue.js`):**
```javascript
// Add QC action handlers
$(document).on('click', '.btn-qc-pass', function() {
    const tokenId = $(this).data('token-id');
    
    Swal.fire({
        title: t('work_queue.qc.confirm_pass', 'Confirm QC Pass'),
        text: t('work_queue.qc.pass_message', 'Mark this item as passed?'),
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: t('common.confirm', 'Confirm'),
        cancelButtonText: t('common.cancel', 'Cancel')
    }).then((result) => {
        if (result.isConfirmed) {
            handleQCPass(tokenId);
        }
    });
});

function handleQCPass(tokenId) {
    $.post(API_URL, {
        action: 'qc_pass',
        token_id: tokenId
    }, function(resp) {
        if (resp.ok) {
            notifySuccess(t('work_queue.qc.passed', 'QC Passed'));
            loadWorkQueue();
        } else {
            notifyError(resp.error || t('work_queue.error.qc_failed', 'QC action failed'));
        }
    }, 'json');
}
```

---

## 📋 Implementation Checklist

### **Phase 2B.5: Node-Type Aware Work Queue UX (CRITICAL)**

- [ ] **API Filtering (`dag_token_api.php`):**
  - [ ] Filter out START/END/SPLIT/JOIN/system nodes in `handleGetWorkQueue()`
  - [ ] Only return tokens at 'operation' and 'qc' nodes
  - [ ] Add `node_type` to response (already exists, verify it's correct)

- [ ] **Frontend Column Filtering (`work_queue.js`):**
  - [ ] Filter nodes before rendering Kanban columns
  - [ ] Hide columns for START/END/SPLIT/JOIN/system nodes
  - [ ] Update `renderKanbanColumn()` to skip non-operable nodes

- [ ] **QC Node Actions (`work_queue.js`):**
  - [ ] Add Pass/Fail buttons for QC nodes
  - [ ] Hide Start/Pause/Complete for QC nodes
  - [ ] Add QC action handlers (`handleQCPass()`, `handleQCFail()`)

- [ ] **PWA Scan Token Actions (`pwa_scan.js`):**
  - [ ] Check `node_type` before showing actions
  - [ ] Show Pass/Fail for QC nodes
  - [ ] Hide actions for START/END/SPLIT/JOIN nodes
  - [ ] Show info message for system nodes

- [ ] **API QC Endpoints (`dag_token_api.php`):**
  - [ ] Add `qc_pass` endpoint
  - [ ] Add `qc_fail` endpoint
  - [ ] Verify token is at QC node before processing

### **Phase 2B.6: Mobile-Optimized Work Queue UX**

- [ ] **Node Filter/Tabs:**
  - [ ] Add node filter dropdown/tabs in List view
  - [ ] Add "My Tasks" filter (assigned to me)
  - [ ] Add "All Nodes" option

- [ ] **View Mode Toggle:**
  - [ ] Add List/Kanban toggle button
  - [ ] Persist user preference (localStorage)
  - [ ] Auto-detect mobile and default to List view

- [ ] **List View Enhancements:**
  - [ ] Group tokens by node (collapsible sections)
  - [ ] Show node name as header
  - [ ] Inline actions (no separate columns)

### **Phase 4.0: Component Model Display**

- [ ] **API Response (`dag_token_api.php`):**
  - [ ] Add `component_code` to Work Queue response
  - [ ] Add `id_component` to Work Queue response
  - [ ] Add `root_serial` to Work Queue response
  - [ ] Add `root_token_id` to Work Queue response

- [ ] **Frontend Display (`work_queue.js`):**
  - [ ] Add component badge to token cards
  - [ ] Show root serial information
  - [ ] Add component filter dropdown
  - [ ] Add root serial filter

- [ ] **PWA Scan Display (`pwa_scan.js`):**
  - [ ] Show component information in token view
  - [ ] Show root serial if different from token serial
  - [ ] Add component badge

---

## 🎯 Priority Order

1. **🔴 CRITICAL: Phase 2B.5** - Node-Type Aware UX
   - Blocks production use
   - Must be done before Work Queue can be used in production

2. **🟡 IMPORTANT: Phase 2B.6** - Mobile Optimization
   - Improves UX for mobile operators
   - Can be done after 2B.5

3. **🟡 IMPORTANT: Phase 4.0** - Component Display
   - Required for component traceability
   - Can be done in parallel with other features

---

## 📝 Files to Modify

### **Backend:**
- `source/dag_token_api.php` - Add filtering, QC endpoints, component fields
- `source/pwa_scan_api.php` - Add component fields (if needed)

### **Frontend:**
- `assets/javascripts/pwa_scan/work_queue.js` - Node filtering, QC actions, component display
- `assets/javascripts/pwa_scan/pwa_scan.js` - Node-type aware actions, component display
- `views/work_queue.php` - Add filter UI elements (if needed)

---

## ✅ Acceptance Criteria

### **Phase 2B.5:**
- [ ] START/END/SPLIT/JOIN nodes do NOT appear in Work Queue
- [ ] QC nodes show Pass/Fail buttons (not Start/Pause/Complete)
- [ ] Operation nodes show Start/Pause/Complete buttons
- [ ] PWA Scan shows appropriate actions based on node_type
- [ ] No invalid actions for system nodes

### **Phase 2B.6:**
- [ ] Mobile devices default to List view
- [ ] Desktop devices default to Kanban view
- [ ] User can toggle between views
- [ ] "My Tasks" filter works correctly
- [ ] Node filter/tabs work correctly
- [ ] No horizontal scrolling on mobile

### **Phase 4.0:**
- [ ] Component badges displayed on token cards
- [ ] Root serial shown when different from token serial
- [ ] Component filter works correctly
- [ ] Root serial filter works correctly
- [ ] PWA Scan shows component information

---

**Document Status:** Ready for Implementation  
**Last Updated:** November 15, 2025

