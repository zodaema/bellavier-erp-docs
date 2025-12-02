# 🔗 Bellavier ERP - DAG Integration Notes

**Status:** 📋 PLANNING PHASE  
**Created:** November 1, 2025  
**Purpose:** Integration approach with existing UI and systems  
**Author:** AI Agent (based on BELLAVIER_PROTOCOL:ERP_OPS_CORE_V1.0)

---

## 🎯 **Integration Philosophy**

**Core Principle:** Add DAG capabilities WITHOUT breaking existing workflows

### **Three-Layer Integration:**

```
┌──────────────────────────────────────────────┐
│  Layer 1: UI/UX (User-facing)               │
│  - Minimal changes to existing interfaces   │
│  - Detect mode automatically                │
│  - Show appropriate controls                │
└──────────────────────────────────────────────┘
                     │
┌──────────────────────────────────────────────┐
│  Layer 2: API (Business Logic)              │
│  - Dual-mode routing                        │
│  - Detect routing_mode                      │
│  - Call appropriate handler                 │
└──────────────────────────────────────────────┘
                     │
┌──────────────────────────────────────────────┐
│  Layer 3: Data (Storage)                    │
│  - Both systems coexist                     │
│  - Separate tables                          │
│  - No conflicts                             │
└──────────────────────────────────────────────┘
```

---

## 📱 **Operator UI (PWA Scan Station)**

### **Current Flow (Unchanged for Linear):**

```
1. Scan QR code
2. Show task list
3. Tap task → Start/Complete buttons
4. Submit → Create WIP log
```

### **New Flow (for DAG):**

```
1. Scan QR code
2. Backend detects routing_mode = 'dag'
3. Show token-based view:
   - "3 pieces ready at SEW_BODY"
   - "Next: Will route to EDGE"
4. Tap Start/Complete
5. Submit → Create token event + auto-route
```

---

### **Implementation: Auto-Detection**

**JavaScript (pwa_scan.js):**

```javascript
// No changes needed in scan/lookup logic
async function lookupEntity(code) {
    const response = await fetch('source/pwa_scan_api.php?action=lookup_entity', {
        method: 'POST',
        body: JSON.stringify({ code })
    });
    
    const data = await response.json();
    
    if (data.ok) {
        // Backend returns routing_mode
        pwaState.entity = data.entity;
        pwaState.routingMode = data.entity.routing_mode;  // 'linear' or 'dag'
        
        displayEntity(data.entity);
    }
}

function displayEntity(entity) {
    // Route to appropriate renderer
    if (entity.routing_mode === 'linear') {
        renderLinearView(entity);  // Existing code (unchanged)
    } else if (entity.routing_mode === 'dag') {
        renderDagView(entity);      // New code
    }
}
```

---

### **Linear View (Existing - No Changes):**

```javascript
function renderLinearView(entity) {
    // Current implementation remains unchanged
    // Shows:
    // - Job Ticket info
    // - Task list (CUT → SEW → EDGE)
    // - Progress bar
    // - Start/Complete buttons per task
}
```

---

### **DAG View (New):**

```javascript
function renderDagView(entity) {
    const html = `
        <div class="card mb-3">
            <div class="card-header bg-primary text-white">
                <h5>${entity.job_name}</h5>
                <small>Ticket: ${entity.ticket_code}</small>
            </div>
            <div class="card-body">
                <!-- Current Node -->
                <div class="alert alert-info">
                    <i class="ri-map-pin-line"></i>
                    <strong>Current Station: ${entity.current_node_name}</strong>
                </div>
                
                <!-- Tokens Ready -->
                <div class="mb-3">
                    <label class="form-label">Tokens Ready:</label>
                    <div class="d-flex align-items-center">
                        <span class="badge bg-success fs-3 me-2">${entity.tokens_ready}</span>
                        <span class="text-muted">pieces waiting at this station</span>
                    </div>
                </div>
                
                <!-- Next Routing (Preview) -->
                ${entity.next_node ? `
                    <div class="alert alert-secondary">
                        <i class="ri-arrow-right-line"></i>
                        After complete: Auto-route to <strong>${entity.next_node}</strong>
                    </div>
                ` : ''}
                
                <!-- Join Waiting (if applicable) -->
                ${entity.join_waiting ? `
                    <div class="alert alert-warning">
                        <i class="ri-timer-line"></i>
                        Assembly waiting: ${entity.join_progress}
                        <div class="progress mt-2">
                            <div class="progress-bar" style="width: ${entity.join_percent}%">
                                ${entity.join_percent}%
                            </div>
                        </div>
                    </div>
                ` : ''}
            </div>
        </div>
        
        <!-- Action Buttons (Same as Linear!) -->
        <div class="card">
            <div class="card-body">
                <button id="btn-start-work" class="btn btn-primary btn-lg w-100 mb-2">
                    <i class="ri-play-circle-line"></i> Start Work
                </button>
                <button id="btn-complete-work" class="btn btn-success btn-lg w-100">
                    <i class="ri-checkbox-circle-line"></i> Complete Work
                </button>
            </div>
        </div>
    `;
    
    $('#entity-view').html(html);
    
    // Attach event listeners (same as linear)
    $('#btn-start-work').click(() => submitEvent('start'));
    $('#btn-complete-work').click(() => submitEvent('complete'));
}

async function submitEvent(eventType) {
    const payload = {
        action: 'log/save',
        routing_mode: pwaState.routingMode,  // 'dag'
        ticket_code: pwaState.entity.ticket_code,
        event_type: eventType,
        operator_id: currentUser.id,
        operator_name: currentUser.name,
        event_time: new Date().toISOString(),
        idempotency_key: uuidv4(),  // Critical for DAG!
        serial_number: pwaState.entity.current_serial || null
    };
    
    const response = await fetch('source/pwa_scan_api.php', {
        method: 'POST',
        body: JSON.stringify(payload)
    });
    
    const data = await response.json();
    
    if (data.ok) {
        notifySuccess('Work logged successfully');
        
        // Show routing notification
        if (data.routed_to) {
            notifyInfo(`Token routed to: ${data.routed_to}`);
        }
        
        // Refresh entity
        lookupEntity(pwaState.entity.ticket_code);
    }
}
```

---

## 🔌 **API Integration**

### **Backend Routing (pwa_scan_api.php):**

```php
<?php
// source/pwa_scan_api.php

case 'lookup_entity':
    $code = trim($input['code'] ?? '');
    
    // Fetch job ticket
    $ticket = fetch_ticket($tenantDb, $code);
    
    if (!$ticket) {
        json_error('Ticket not found', 404);
    }
    
    // Detect routing mode
    if ($ticket['routing_mode'] === 'linear') {
        $entity = build_linear_entity($tenantDb, $ticket);
    } else {
        $entity = build_dag_entity($tenantDb, $ticket);
    }
    
    json_success(['entity' => $entity]);
    break;

function build_linear_entity($db, $ticket) {
    // Existing logic (unchanged)
    // Returns: tasks, progress, status, etc.
    
    return [
        'routing_mode' => 'linear',
        'ticket_code' => $ticket['ticket_code'],
        'job_name' => $ticket['job_name'],
        'tasks' => fetch_tasks($db, $ticket['id_job_ticket']),
        // ... existing fields
    ];
}

function build_dag_entity($db, $ticket) {
    // New logic
    $instance = fetch_graph_instance($db, $ticket['graph_instance_id']);
    $tokens = fetch_active_tokens($db, $instance['instance_id']);
    
    // Current node (where tokens are waiting)
    $currentNode = detect_current_node($db, $tokens);
    
    // Next node (where tokens will go after complete)
    $nextNode = get_next_node($db, $currentNode['node_id']);
    
    // Join status (if at join node)
    $joinStatus = null;
    if ($currentNode['node_type'] === 'join') {
        $joinStatus = calculate_join_progress($db, $currentNode);
    }
    
    return [
        'routing_mode' => 'dag',
        'ticket_code' => $ticket['ticket_code'],
        'job_name' => $ticket['job_name'],
        'current_node_name' => $currentNode['name'],
        'current_node_type' => $currentNode['node_type'],
        'tokens_ready' => count($tokens),
        'next_node' => $nextNode['name'] ?? null,
        'join_waiting' => $currentNode['node_type'] === 'join',
        'join_progress' => $joinStatus['progress'] ?? null,
        'join_percent' => $joinStatus['percent'] ?? null,
        // ... additional fields
    ];
}

function fetch_active_tokens($db, $instanceId) {
    $stmt = $db->prepare("
        SELECT 
            ft.token_id,
            ft.serial_number,
            ft.status,
            rn.name as current_node_name
        FROM flow_token ft
        JOIN routing_node rn ON rn.node_id = ft.current_node_id
        WHERE ft.instance_id = ?
        AND ft.status IN ('active', 'waiting')
        ORDER BY ft.token_id
    ");
    $stmt->bind_param('i', $instanceId);
    $stmt->execute();
    return $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
}

function detect_current_node($db, $tokens) {
    // Assumption: All active tokens at same node
    if (empty($tokens)) return null;
    
    $firstToken = $tokens[0];
    
    $stmt = $db->prepare("
        SELECT 
            rn.node_id,
            rn.name,
            rn.node_type
        FROM routing_node rn
        JOIN flow_token ft ON ft.current_node_id = rn.node_id
        WHERE ft.token_id = ?
    ");
    $stmt->bind_param('i', $firstToken['token_id']);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc();
}

function get_next_node($db, $currentNodeId) {
    $stmt = $db->prepare("
        SELECT 
            rn.node_id,
            rn.name
        FROM routing_node rn
        JOIN routing_edge re ON re.to_node_id = rn.node_id
        WHERE re.from_node_id = ?
        AND re.edge_type = 'normal'
        LIMIT 1
    ");
    $stmt->bind_param('i', $currentNodeId);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc();
}
```

---

### **Event Submission (log/save):**

```php
case 'log/save':
    $routingMode = $input['routing_mode'] ?? 'linear';
    
    if ($routingMode === 'linear') {
        // Use existing WIP log handler
        $result = handle_wip_log_save($tenantDb, $input);
    } else {
        // Use new token event handler
        $result = handle_token_event_save($tenantDb, $input);
    }
    
    json_success($result);
    break;

function handle_token_event_save($db, $input) {
    // Find tokens at current node
    $ticket = fetch_ticket($db, $input['ticket_code']);
    $tokens = fetch_active_tokens($db, $ticket['graph_instance_id']);
    
    if (empty($tokens)) {
        throw new Exception('No active tokens found');
    }
    
    // Create event for each token
    $events = [];
    foreach ($tokens as $token) {
        $eventId = create_token_event($db, [
            'token_id' => $token['token_id'],
            'event_type' => $input['event_type'],
            'operator_id' => $input['operator_id'],
            'event_time' => $input['event_time'],
            'idempotency_key' => $input['idempotency_key'] . '_' . $token['token_id']
        ]);
        
        $events[] = $eventId;
    }
    
    // If complete event → trigger routing
    if ($input['event_type'] === 'complete') {
        $routed = route_tokens($db, $tokens);
        return [
            'events_created' => count($events),
            'routed_to' => $routed['node_name']
        ];
    }
    
    return ['events_created' => count($events)];
}

function create_token_event($db, $data) {
    $stmt = $db->prepare("
        INSERT INTO token_event 
        (token_id, event_type, operator_id, event_time, idempotency_key)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE event_id = event_id
    ");
    
    $stmt->bind_param('isiss',
        $data['token_id'],
        $data['event_type'],
        $data['operator_id'],
        $data['event_time'],
        $data['idempotency_key']
    );
    
    $stmt->execute();
    return $stmt->insert_id;
}

function route_tokens($db, $tokens) {
    // Get next node
    $firstToken = $tokens[0];
    $currentNodeId = $db->query("SELECT current_node_id FROM flow_token WHERE token_id = {$firstToken['token_id']}")->fetch_assoc()['current_node_id'];
    
    $nextNode = get_next_node($db, $currentNodeId);
    
    if (!$nextNode) {
        // Finish node
        foreach ($tokens as $token) {
            $db->query("UPDATE flow_token SET status = 'completed' WHERE token_id = {$token['token_id']}");
        }
        return ['node_name' => 'FINISH'];
    }
    
    // Move tokens to next node
    foreach ($tokens as $token) {
        $db->query("UPDATE flow_token SET current_node_id = {$nextNode['node_id']} WHERE token_id = {$token['token_id']}");
        
        // Create move event
        create_token_event($db, [
            'token_id' => $token['token_id'],
            'event_type' => 'move',
            'operator_id' => null,
            'event_time' => date('Y-m-d H:i:s'),
            'idempotency_key' => uniqid('move_', true)
        ]);
        
        // Create enter event
        create_token_event($db, [
            'token_id' => $token['token_id'],
            'event_type' => 'enter',
            'operator_id' => null,
            'event_time' => date('Y-m-d H:i:s'),
            'idempotency_key' => uniqid('enter_', true)
        ]);
    }
    
    return ['node_name' => $nextNode['name']];
}
```

---

## 📊 **Supervisor Dashboard**

### **Current Dashboard (Linear):**

```
Jobs List:
  - JOB-001: CUT (10/10) → SEW (5/10) → EDGE (0/10)
  - JOB-002: CUT (8/10) → SEW (0/10)
  
Progress bars, percentages
```

### **New Dashboard (DAG):**

```javascript
// Add graph visualization option

function renderJobTicketRow(job) {
    if (job.routing_mode === 'linear') {
        return renderLinearRow(job);  // Existing
    } else {
        return renderDagRow(job);      // New
    }
}

function renderDagRow(job) {
    return `
        <tr>
            <td>${job.ticket_code}</td>
            <td>${job.job_name}</td>
            <td>
                <button class="btn btn-sm btn-primary" onclick="showGraphView(${job.id})">
                    <i class="ri-node-tree"></i> View Graph
                </button>
            </td>
            <td>${job.tokens_active} / ${job.tokens_total}</td>
            <td>
                <span class="badge bg-info">${job.current_nodes_count} active nodes</span>
            </td>
        </tr>
    `;
}

function showGraphView(jobId) {
    // Modal with graph visualization
    
    $('#graph-modal').modal('show');
    
    // Fetch graph data
    fetch(`source/atelier_job_ticket.php?action=get_graph_status&id=${jobId}`)
        .then(r => r.json())
        .then(data => {
            renderCytoscapeGraph(data.graph);
        });
}

function renderCytoscapeGraph(graphData) {
    // Using Cytoscape.js
    
    const cy = cytoscape({
        container: document.getElementById('graph-canvas'),
        
        elements: [
            // Nodes
            ...graphData.nodes.map(node => ({
                data: {
                    id: node.node_id,
                    label: node.name,
                    tokens: node.token_count,
                    status: node.status
                },
                classes: node.status  // CSS class for color
            })),
            
            // Edges
            ...graphData.edges.map(edge => ({
                data: {
                    source: edge.from_node,
                    target: edge.to_node
                }
            }))
        ],
        
        style: [
            {
                selector: 'node',
                style: {
                    'label': 'data(label)',
                    'text-valign': 'center',
                    'width': 80,
                    'height': 80
                }
            },
            {
                selector: 'node.active',
                style: { 'background-color': '#28a745' }  // Green
            },
            {
                selector: 'node.waiting',
                style: { 'background-color': '#ffc107' }  // Yellow
            },
            {
                selector: 'node.completed',
                style: { 'background-color': '#6c757d' }  // Gray
            },
            {
                selector: 'edge',
                style: {
                    'width': 3,
                    'target-arrow-shape': 'triangle',
                    'curve-style': 'bezier'
                }
            }
        ],
        
        layout: {
            name: 'dagre',  // Auto-layout for DAG
            rankDir: 'LR'    // Left-to-right
        }
    });
}
```

---

## 🎨 **Graph Designer (Planner UI)**

### **New Page: routing_graph_designer.php**

```javascript
// Drag-and-drop graph builder

const graphDesigner = {
    nodes: [],
    edges: [],
    selectedNode: null,
    
    addNode(type) {
        const node = {
            id: `node_${Date.now()}`,
            type: type,  // 'operation', 'split', 'join', 'decision'
            name: prompt('Node name:'),
            x: 100,
            y: 100
        };
        
        this.nodes.push(node);
        this.render();
    },
    
    connectNodes(from, to) {
        const edge = {
            id: `edge_${Date.now()}`,
            from: from,
            to: to,
            type: 'normal'
        };
        
        this.edges.push(edge);
        this.render();
    },
    
    validate() {
        // Check for cycles
        if (this.hasCycle()) {
            alert('Error: Graph contains cycle!');
            return false;
        }
        
        // Check start/end nodes
        const startNodes = this.nodes.filter(n => !this.hasIncoming(n));
        if (startNodes.length !== 1) {
            alert('Error: Must have exactly 1 start node');
            return false;
        }
        
        // Check join nodes
        const joinNodes = this.nodes.filter(n => n.type === 'join');
        for (let node of joinNodes) {
            const incoming = this.getIncomingEdges(node);
            if (incoming.length < 2) {
                alert(`Error: Join node "${node.name}" must have 2+ inputs`);
                return false;
            }
        }
        
        return true;
    },
    
    save() {
        if (!this.validate()) return;
        
        const graphData = {
            name: $('#graph-name').val(),
            description: $('#graph-description').val(),
            nodes: this.nodes,
            edges: this.edges
        };
        
        $.post('source/routing_api.php', {
            action: 'save_graph',
            data: JSON.stringify(graphData)
        }, (resp) => {
            if (resp.ok) {
                alert('Graph saved successfully!');
            }
        });
    }
};
```

---

## 🔍 **Serial Traceability Integration**

### **Current Traceability (Linear):**

```sql
SELECT * FROM atelier_wip_log 
WHERE serial_number = 'TOTE-001'
AND deleted_at IS NULL
ORDER BY event_time;
```

### **New Traceability (DAG):**

```sql
-- Full token journey
SELECT 
    te.event_type,
    te.event_time,
    rn.name as node_name,
    te.metadata
FROM token_event te
JOIN flow_token ft ON ft.token_id = te.token_id
LEFT JOIN routing_node rn ON JSON_EXTRACT(te.metadata, '$.node_id') = rn.node_id
WHERE ft.serial_number = 'TOTE-001'
ORDER BY te.event_time;

-- Assembly genealogy
SELECT 
    parent.serial_number as final_product,
    child.serial_number as component,
    te.event_time as assembled_at
FROM flow_token child
JOIN flow_token parent ON parent.token_id = child.parent_token_id
JOIN token_event te ON te.token_id = child.token_id AND te.event_type = 'join'
WHERE parent.serial_number = 'TOTE-001-FINAL';
```

**UI Integration:**

```javascript
// Serial search page works for both!

async function searchSerial(serial) {
    const resp = await fetch(`source/serial_history.php?action=search&serial=${serial}`);
    const data = await resp.json();
    
    if (data.ok) {
        if (data.source === 'linear') {
            renderLinearHistory(data.history);
        } else {
            renderDagHistory(data.history, data.genealogy);
        }
    }
}

function renderDagHistory(history, genealogy) {
    let html = '<div class="timeline">';
    
    // Show token events
    history.forEach((event, i) => {
        html += `
            <div class="timeline-item">
                <div class="badge bg-primary">${i + 1}</div>
                <div class="timeline-content">
                    <strong>${event.event_type}</strong> at ${event.node_name}
                    <br>
                    <small>${event.operator_name || 'System'} | ${event.event_time}</small>
                </div>
            </div>
        `;
    });
    
    // Show assembly components
    if (genealogy && genealogy.length > 0) {
        html += `
            <div class="mt-3">
                <h6>Assembled from:</h6>
                <ul>
                    ${genealogy.map(c => `<li><a href="#" onclick="searchSerial('${c.component}')">${c.component}</a></li>`).join('')}
                </ul>
            </div>
        `;
    }
    
    html += '</div>';
    $('#history-view').html(html);
}
```

---

## ✅ **Backward Compatibility Checklist**

### **Must Maintain:**
- [ ] Existing job tickets work unchanged
- [ ] Existing WIP logs readable
- [ ] Existing task list displays correctly
- [ ] Existing reports work
- [ ] Existing operator workflow unchanged (for linear jobs)
- [ ] Existing APIs return expected format

### **Can Add (Non-Breaking):**
- [ ] New `routing_mode` field (defaults to 'linear')
- [ ] New `graph_instance_id` field (nullable)
- [ ] New DAG tables (separate, no conflicts)
- [ ] New API endpoints (no impact on old ones)
- [ ] New UI views (conditional rendering)

---

## 📚 **Integration Summary**

**UI Layer:**
- ✅ Auto-detect routing mode
- ✅ Render appropriate view
- ✅ Same button labels (Start/Complete)
- ✅ Enhanced feedback (routing notifications)

**API Layer:**
- ✅ Dual-mode routing (if/else)
- ✅ Backward compatible responses
- ✅ Additive events (token + wip_log coexist)

**Data Layer:**
- ✅ Separate tables (no conflicts)
- ✅ Linking columns (nullable)
- ✅ Both systems queryable

---

**See Also:**
- `BELLAVIER_DAG_CORE_TODO.md` - Implementation checklist
- `BELLAVIER_DAG_RUNTIME_FLOW.md` - Token/Node lifecycle
- `BELLAVIER_DAG_MIGRATION_PLAN.md` - Migration strategy

---

**Status:** Integration approach documented, ready for implementation

