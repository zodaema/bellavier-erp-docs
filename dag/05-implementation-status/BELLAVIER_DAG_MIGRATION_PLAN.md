# 🔄 Bellavier ERP - DAG Migration Plan

**Status:** 📋 PLANNING PHASE  
**Created:** November 1, 2025  
**Purpose:** Safe migration from Linear to DAG system  
**Author:** AI Agent (based on BELLAVIER_PROTOCOL:ERP_OPS_CORE_V1.0)

---

## 🎯 **Migration Principles**

### **Core Principles:**

1. **Non-Destructive** ✅
   - Never delete existing tables
   - Never break existing functionality
   - Add new system alongside old

2. **Incremental** ✅
   - Phase 1: Both systems coexist
   - Phase 2: Gradual conversion
   - Phase 3: Full DAG (optional)

3. **Rollback-Safe** ✅
   - Can revert at any phase
   - No data loss
   - Old system continues working

4. **Backward Compatible** ✅
   - Existing jobs work unchanged
   - Existing APIs remain functional
   - Existing UI still usable

---

## 📊 **Current System Analysis**

### **Existing Tables:**

```
atelier_job_ticket
├── id_job_ticket (PK)
├── ticket_code
├── job_name
├── target_qty
├── process_mode (batch/piece)
├── status
└── work_center_id

atelier_job_task
├── id_job_task (PK)
├── id_job_ticket (FK)
├── step_name
├── sequence_no          ← Linear order!
├── status
├── assigned_to
├── predecessor_task_id  ← Simple dependency
└── estimated_hours

atelier_wip_log
├── id_wip_log (PK)
├── id_job_ticket (FK)
├── id_job_task (FK)
├── event_type
├── event_time
├── operator_user_id
├── operator_name
├── qty
├── serial_number
└── deleted_at (soft-delete)

atelier_task_operator_session
├── id_session (PK)
├── id_job_task (FK)
├── operator_user_id
├── status
├── total_qty
└── started_at
```

**Current Flow:**
```
Job Ticket → Task 1 → Task 2 → Task 3
             (seq=1)  (seq=2)  (seq=3)

- Sequential execution only
- No parallel (can't do Task 1 + Task 2 simultaneously)
- No assembly (can't join multiple tasks)
- predecessor_task_id only supports 1→1 dependency
```

---

## 🚀 **Migration Architecture**

### **Dual-Mode System:**

```
┌─────────────────────────────────────────┐
│        Job Ticket Creation              │
└─────────────────┬───────────────────────┘
                  │
         ┌────────▼─────────┐
         │ Choose Mode:      │
         │ [ ] Linear        │
         │ [x] DAG           │
         └────────┬──────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
    ┌───▼───┐            ┌───▼────┐
    │Linear │            │  DAG   │
    │System │            │ System │
    │(Old)  │            │ (New)  │
    └───────┘            └────────┘
    
Both systems coexist!
Old jobs use old system
New jobs can use DAG
```

**Implementation:**

```sql
-- Add mode selector to job_ticket
ALTER TABLE atelier_job_ticket
ADD COLUMN routing_mode ENUM('linear', 'dag') DEFAULT 'linear',
ADD COLUMN graph_instance_id INT NULL,
ADD INDEX idx_routing_mode (routing_mode);

-- Feature flag in config.php
define('ENABLE_DAG_ROUTING', false);  // Start with false
```

---

## 📋 **Phase 1: Foundation (Week 1-2)**

### **Goal:** Add DAG tables without breaking anything

### **Step 1.1: Create DAG Tables**

```sql
-- These are NEW tables, existing system unchanged

CREATE TABLE routing_graph (
    graph_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    version VARCHAR(20),
    is_published BOOLEAN DEFAULT false,
    created_by INT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_published (is_published, created_at)
) ENGINE=InnoDB;

CREATE TABLE routing_node (
    node_id INT PRIMARY KEY AUTO_INCREMENT,
    graph_id INT NOT NULL,
    node_type ENUM('operation', 'split', 'join', 'decision') NOT NULL,
    name VARCHAR(100) NOT NULL,
    work_center_id INT NULL,
    position_x INT DEFAULT 0,
    position_y INT DEFAULT 0,
    config JSON NULL COMMENT 'Node-specific configuration',
    INDEX idx_graph (graph_id),
    FOREIGN KEY (graph_id) REFERENCES routing_graph(graph_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE routing_edge (
    edge_id INT PRIMARY KEY AUTO_INCREMENT,
    graph_id INT NOT NULL,
    from_node_id INT NOT NULL,
    to_node_id INT NOT NULL,
    edge_type ENUM('normal', 'rework', 'conditional') DEFAULT 'normal',
    condition_rule JSON NULL,
    INDEX idx_from (from_node_id),
    INDEX idx_to (to_node_id),
    FOREIGN KEY (graph_id) REFERENCES routing_graph(graph_id) ON DELETE CASCADE,
    FOREIGN KEY (from_node_id) REFERENCES routing_node(node_id) ON DELETE CASCADE,
    FOREIGN KEY (to_node_id) REFERENCES routing_node(node_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE job_graph_instance (
    instance_id INT PRIMARY KEY AUTO_INCREMENT,
    job_ticket_id INT NOT NULL,
    graph_id INT NOT NULL,
    status ENUM('active', 'completed', 'cancelled') DEFAULT 'active',
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    INDEX idx_job_ticket (job_ticket_id),
    INDEX idx_status (status),
    FOREIGN KEY (job_ticket_id) REFERENCES atelier_job_ticket(id_job_ticket) ON DELETE CASCADE,
    FOREIGN KEY (graph_id) REFERENCES routing_graph(graph_id)
) ENGINE=InnoDB;

CREATE TABLE node_instance (
    instance_node_id INT PRIMARY KEY AUTO_INCREMENT,
    instance_id INT NOT NULL,
    node_id INT NOT NULL,
    status ENUM('ready', 'active', 'waiting', 'blocked', 'completed') DEFAULT 'ready',
    blocking_reason JSON NULL,
    started_at DATETIME NULL,
    completed_at DATETIME NULL,
    INDEX idx_instance (instance_id, status),
    FOREIGN KEY (instance_id) REFERENCES job_graph_instance(instance_id) ON DELETE CASCADE,
    FOREIGN KEY (node_id) REFERENCES routing_node(node_id)
) ENGINE=InnoDB;

CREATE TABLE flow_token (
    token_id INT PRIMARY KEY AUTO_INCREMENT,
    instance_id INT NOT NULL,
    serial_number VARCHAR(100) NULL,
    current_node_id INT NULL,
    status ENUM('active', 'waiting', 'completed', 'scrapped') DEFAULT 'active',
    parent_token_id INT NULL COMMENT 'For assembly genealogy',
    qty DECIMAL(10,2) DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_instance_status (instance_id, status),
    INDEX idx_serial (serial_number),
    INDEX idx_current_node (current_node_id),
    INDEX idx_parent (parent_token_id),
    FOREIGN KEY (instance_id) REFERENCES job_graph_instance(instance_id) ON DELETE CASCADE,
    FOREIGN KEY (current_node_id) REFERENCES routing_node(node_id),
    FOREIGN KEY (parent_token_id) REFERENCES flow_token(token_id)
) ENGINE=InnoDB;

CREATE TABLE token_event (
    event_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    token_id INT NOT NULL,
    event_type ENUM('spawn', 'enter', 'start', 'pause', 'resume', 'complete', 
                    'move', 'split', 'join', 'qc_pass', 'qc_fail', 'rework', 'scrap') NOT NULL,
    node_instance_id INT NULL,
    operator_id INT NULL,
    event_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    idempotency_key CHAR(36) NOT NULL COMMENT 'UUID for idempotency',
    metadata JSON NULL,
    INDEX idx_token_time (token_id, event_time),
    UNIQUE INDEX idx_idempotency (idempotency_key),
    INDEX idx_event_type (event_type, event_time),
    FOREIGN KEY (token_id) REFERENCES flow_token(token_id) ON DELETE CASCADE,
    FOREIGN KEY (node_instance_id) REFERENCES node_instance(instance_node_id)
) ENGINE=InnoDB;
```

**Verification:**
```sql
-- Check tables created
SHOW TABLES LIKE '%routing%';
SHOW TABLES LIKE '%token%';

-- Check indexes
SHOW INDEX FROM flow_token;
SHOW INDEX FROM token_event;
```

---

### **Step 1.2: Add Linking Columns**

```sql
-- Link job_ticket to graph_instance (nullable!)
ALTER TABLE atelier_job_ticket
ADD COLUMN routing_mode ENUM('linear', 'dag') DEFAULT 'linear' 
  COMMENT 'System mode: linear (old) or dag (new)',
ADD COLUMN graph_instance_id INT NULL 
  COMMENT 'Links to job_graph_instance if using DAG',
ADD INDEX idx_graph_instance (graph_instance_id);

-- Link task to node (for hybrid queries)
ALTER TABLE atelier_job_task
ADD COLUMN node_id INT NULL 
  COMMENT 'Maps to routing_node if generated from graph',
ADD INDEX idx_node (node_id);
```

**At this point:**
- ✅ All new tables exist
- ✅ Existing system unchanged (routing_mode defaults to 'linear')
- ✅ No impact on current operations

---

### **Step 1.3: Create Default Linear Graphs**

**Goal:** Create graph templates for existing task sequences

**Algorithm:**
```pseudo
FOR each unique task sequence:
  # Example: CUT → SEW → EDGE → FINISH
  
  graph = CREATE routing_graph(
    name = "Linear: " + sequence_name,
    description = "Auto-generated from existing tasks",
    version = "1.0",
    is_published = true
  )
  
  previous_node = NULL
  
  FOR each task in sequence:
    node = CREATE routing_node(
      graph_id = graph.id,
      node_type = 'operation',
      name = task.step_name,
      work_center_id = task.work_center_id,
      position_x = task.sequence_no * 200,  // Visual layout
      position_y = 100
    )
    
    IF previous_node IS NOT NULL:
      CREATE routing_edge(
        graph_id = graph.id,
        from_node_id = previous_node.id,
        to_node_id = node.id,
        edge_type = 'normal'
      )
    
    previous_node = node
```

**Example Output:**
```
Graph: "Linear: Standard Bag Production"
Nodes:
  1. CUT (seq=1)
  2. SEW (seq=2)
  3. EDGE (seq=3)
  4. FINISH (seq=4)

Edges:
  CUT → SEW
  SEW → EDGE
  EDGE → FINISH
```

---

## 📋 **Phase 2: Hybrid Operation (Week 3-4)**

### **Goal:** Support both systems simultaneously

### **Step 2.1: Dual-Track Job Creation**

**Job Ticket Creation Logic:**

```pseudo
ON create_job_ticket(data):
  ticket = CREATE atelier_job_ticket(
    ticket_code = generate_code(),
    job_name = data.job_name,
    target_qty = data.target_qty,
    routing_mode = data.use_dag ? 'dag' : 'linear'  // User choice
  )
  
  IF routing_mode = 'linear':
    # Old system (unchanged)
    FOR each task_template:
      CREATE atelier_job_task(
        id_job_ticket = ticket.id,
        step_name = task.name,
        sequence_no = task.sequence
      )
  
  ELSE IF routing_mode = 'dag':
    # New system
    graph = find_or_create_graph(data.product_type)
    
    instance = CREATE job_graph_instance(
      job_ticket_id = ticket.id,
      graph_id = graph.id
    )
    
    UPDATE ticket SET graph_instance_id = instance.id
    
    # Create node instances
    FOR each node IN graph.nodes:
      CREATE node_instance(
        instance_id = instance.id,
        node_id = node.id,
        status = 'ready'
      )
    
    # Spawn tokens
    spawn_tokens(instance, ticket.target_qty, ticket.process_mode)
```

---

### **Step 2.2: Dual-Track Operator UI**

**PWA Scan Station:**

```javascript
// Detect routing mode
async function lookupEntity(code) {
    const response = await fetch('source/pwa_scan_api.php?action=lookup_entity', {
        method: 'POST',
        body: JSON.stringify({ code })
    });
    
    const data = await response.json();
    
    if (data.ok) {
        const entity = data.entity;
        
        if (entity.routing_mode === 'linear') {
            // Old UI (unchanged)
            renderLinearTaskView(entity);
        } else if (entity.routing_mode === 'dag') {
            // New UI (token-based)
            renderDagTokenView(entity);
        }
    }
}

function renderLinearTaskView(entity) {
    // Existing code (unchanged)
    // Shows: Task list, Start/Complete buttons
}

function renderDagTokenView(entity) {
    // New code
    // Shows: Available tokens at current node, Start/Complete with routing
    
    const html = `
        <div class="card">
            <div class="card-header">
                <h5>Current Node: ${entity.current_node_name}</h5>
            </div>
            <div class="card-body">
                <p>Tokens ready: <strong>${entity.token_count}</strong></p>
                <button class="btn btn-primary" onclick="startWork()">
                    Start Work
                </button>
            </div>
        </div>
    `;
    $('#entity-view').html(html);
}
```

---

### **Step 2.3: API Adaptation Layer**

**Backend Routing:**

```php
// source/pwa_scan_api.php

case 'log/save':
    $ticket = fetch_ticket($ticketCode);
    
    if ($ticket['routing_mode'] === 'linear') {
        // Use existing WIP log system
        $result = save_wip_log_linear($data);
    } else {
        // Use new token event system
        $result = save_token_event($data);
    }
    
    json_success($result);
    break;

function save_token_event($data) {
    global $tenantDb;
    
    // Find token
    $token = find_or_create_token($data['ticket_id'], $data['serial']);
    
    // Create idempotency key
    $idempotencyKey = $data['idempotency_key'] ?? generate_uuid();
    
    // Insert event
    $stmt = $tenantDb->prepare("
        INSERT INTO token_event 
        (token_id, event_type, operator_id, event_time, idempotency_key, metadata)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE event_id = event_id  -- Idempotent
    ");
    
    $stmt->bind_param('isisss', 
        $token['token_id'],
        $data['event_type'],
        $data['operator_id'],
        $data['event_time'],
        $idempotencyKey,
        json_encode($data['metadata'])
    );
    
    $stmt->execute();
    
    // Process routing logic
    if ($data['event_type'] === 'complete') {
        route_token($token['token_id']);
    }
    
    return ['token_id' => $token['token_id'], 'event_id' => $stmt->insert_id];
}
```

---

## 📋 **Phase 3: Data Conversion (Optional)**

### **Goal:** Convert historical data to DAG format

**Important:** This is optional! Old data can remain in linear format.

### **Step 3.1: Retrospective Graph Creation**

```pseudo
FOR each completed job_ticket WHERE routing_mode = 'linear':
  # Create graph instance retroactively
  
  tasks = get_tasks(job_ticket)
  graph = find_or_create_linear_graph(tasks)
  
  instance = CREATE job_graph_instance(
    job_ticket_id = job_ticket.id,
    graph_id = graph.id,
    status = 'completed',
    started_at = job_ticket.started_at,
    completed_at = job_ticket.completed_at
  )
  
  UPDATE job_ticket SET graph_instance_id = instance.id
  
  # Create node instances
  FOR each task IN tasks:
    node = find_node(graph, task.step_name)
    
    CREATE node_instance(
      instance_id = instance.id,
      node_id = node.id,
      status = 'completed',
      started_at = task.started_at,
      completed_at = task.completed_at
    )
    
    # Link task to node
    UPDATE task SET node_id = node.id
```

---

### **Step 3.2: WIP Log → Token Event Conversion**

```pseudo
FOR each wip_log WHERE job_ticket.routing_mode = 'linear':
  # Convert log entry to token event
  
  # Find or create token
  IF wip_log.serial_number IS NOT NULL:
    token = find_or_create_token(
      instance_id = job_ticket.graph_instance_id,
      serial = wip_log.serial_number
    )
  ELSE:
    # Batch mode - create single token per task
    token = find_or_create_batch_token(
      instance_id = job_ticket.graph_instance_id,
      task_id = wip_log.id_job_task
    )
  
  # Map event type
  event_type_map = {
    'start': 'start',
    'hold': 'pause',
    'resume': 'resume',
    'complete': 'complete',
    'qc_pass': 'qc_pass',
    'qc_fail': 'qc_fail'
  }
  
  mapped_event = event_type_map[wip_log.event_type]
  
  # Create token event
  CREATE token_event(
    token_id = token.token_id,
    event_type = mapped_event,
    operator_id = wip_log.operator_user_id,
    event_time = wip_log.event_time,
    idempotency_key = generate_uuid(),  // New UUID
    metadata = {
      'original_log_id': wip_log.id_wip_log,
      'converted_from': 'wip_log'
    }
  )
```

**Verification:**
```sql
-- Count conversion progress
SELECT 
    routing_mode,
    COUNT(*) as ticket_count,
    SUM(CASE WHEN graph_instance_id IS NOT NULL THEN 1 ELSE 0 END) as converted_count
FROM atelier_job_ticket
GROUP BY routing_mode;

-- Compare event counts
SELECT 
    'wip_log' as source,
    COUNT(*) as count
FROM atelier_wip_log
WHERE deleted_at IS NULL
UNION ALL
SELECT 
    'token_event' as source,
    COUNT(*) as count
FROM token_event;
```

---

## 🔄 **Rollback Strategy**

### **If Things Go Wrong:**

**Phase 1 Rollback:** (Tables created)
```sql
-- Simply don't use new system
UPDATE atelier_job_ticket SET routing_mode = 'linear';

-- Old system continues working
-- No data loss
```

**Phase 2 Rollback:** (Hybrid operation)
```sql
-- Stop creating new DAG jobs
UPDATE config SET enable_dag_routing = false;

-- Existing DAG jobs: Continue in read-only mode
-- New jobs: Use linear only
-- No data loss
```

**Phase 3 Rollback:** (After conversion)
```sql
-- Converted data remains accessible in both formats
-- Token events are additive, don't delete wip_log

-- Worst case: Drop new tables (but loses new data!)
-- DROP TABLE token_event, flow_token, node_instance, 
--     job_graph_instance, routing_edge, routing_node, routing_graph;

-- Old system fully functional
```

---

## ✅ **Migration Checklist**

### **Pre-Migration:**
- [ ] Backup all databases
- [ ] Test DAG tables in staging
- [ ] Train 1-2 pilot users
- [ ] Prepare rollback scripts

### **Phase 1: Foundation**
- [ ] Create DAG tables (Week 1)
- [ ] Add linking columns (Week 1)
- [ ] Generate linear graphs (Week 2)
- [ ] Verify old system unchanged (Week 2)

### **Phase 2: Hybrid**
- [ ] Implement dual-mode creation (Week 3)
- [ ] Update Operator UI (Week 3)
- [ ] Adapt APIs (Week 4)
- [ ] Test both modes simultaneously (Week 4)

### **Phase 3: Conversion (Optional)**
- [ ] Convert historical data (Week 5+)
- [ ] Verify data integrity (Week 6)
- [ ] Performance testing (Week 6)

### **Post-Migration:**
- [ ] Monitor both systems
- [ ] Collect user feedback
- [ ] Optimize queries
- [ ] Update documentation

---

## 📊 **Success Metrics**

**Technical:**
- ✅ Zero downtime during migration
- ✅ < 5% performance degradation
- ✅ 100% data integrity (no loss)
- ✅ Rollback tested and working

**Business:**
- ✅ Operators can use both systems
- ✅ No training required for linear mode
- ✅ Optional DAG training for advanced users
- ✅ Gradual adoption (no forced switch)

---

## 🎯 **Timeline Estimate**

| Phase | Duration | Risk | Rollback |
|-------|----------|------|----------|
| **Phase 1: Foundation** | 2 weeks | Low ✅ | Easy |
| **Phase 2: Hybrid** | 2 weeks | Medium ⚠️ | Easy |
| **Phase 3: Conversion** | 2-4 weeks | High 🔴 | Moderate |

**Recommended:** Stop at Phase 2 for 1-2 months, then evaluate if Phase 3 is needed.

---

**See Also:**
- `BELLAVIER_DAG_CORE_TODO.md` - Implementation checklist
- `BELLAVIER_DAG_RUNTIME_FLOW.md` - Token/Node lifecycle
- `BELLAVIER_DAG_INTEGRATION_NOTES.md` - UI integration

---

**Status:** Migration plan documented, ready for execution

