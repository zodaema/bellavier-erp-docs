# 🔍 Routing Graph Designer - System Exploration Report

**วันที่สำรวจ:** 9 พฤศจิกายน 2025  
**สถานะ:** ✅ สำรวจเสร็จสมบูรณ์  
**เป้าหมาย:** เข้าใจระบบที่เกี่ยวข้องก่อนเริ่ม Phase 1

---

## 📋 สรุปภาพรวม

### ระบบที่สำรวจ:
1. ✅ **Work Center System** - จุดทำงาน/สถานีผลิต
2. ✅ **Team System** - ทีมงานและสมาชิก
3. ✅ **Assignment System** - การมอบหมายงาน
4. ✅ **DAG Routing API** - API สำหรับจัดการ routing graph
5. ✅ **Database Schema** - โครงสร้างตาราง routing_node และ routing_edge

---

## 🏭 1. Work Center System

### API Endpoint:
- **File:** `source/work_centers.php`
- **Base URL:** `/source/work_centers.php`

### Available Actions:
```php
case 'list':
    // GET /source/work_centers.php?action=list
    // Parameters:
    //   - search: string (optional)
    //   - status: 'all'|'active'|'inactive' (optional)
    //   - limit: int (default: 50, max: 500)
    //   - cursor: int (for pagination)
    // Response: {ok: true, data: [{id_work_center, code, name, description, is_active}]}

case 'detail':
    // GET /source/work_centers.php?action=detail&id_work_center={id}
    // Response: {ok: true, data: {id_work_center, code, name, description, is_active}}
    // Headers: ETag (for concurrency control)

case 'save':
    // POST /source/work_centers.php?action=save
    // Body: {id_work_center?, code, name, description, is_active?}
    // Response: {ok: true, id_work_center: int}

case 'update':
    // POST /source/work_centers.php?action=update
    // Body: {id_work_center, code?, name?, description?, is_active?}
    // Headers: If-Match (ETag for concurrency)
    // Response: {ok: true, id_work_center: int}

case 'delete':
    // POST /source/work_centers.php?action=delete
    // Body: {id_work_center}
    // Response: {ok: true, message: string}
```

### Database Schema:
```sql
CREATE TABLE work_center (
    id_work_center INT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    is_active TINYINT(1) DEFAULT 1,
    headcount INT NULL COMMENT 'Number of operators',
    work_hours_per_day DECIMAL(5,2) NULL COMMENT 'Hours per day',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_code (code)
);
```

### Key Points:
- ✅ มี `is_active` column สำหรับ soft-delete
- ✅ รองรับ pagination แบบ cursor-based
- ✅ มี ETag support สำหรับ concurrency control
- ✅ Permission: `work_centers.view`, `work_centers.manage`

### Usage in Graph Designer:
```javascript
// Load work centers for dropdown
$.get('source/work_centers.php', {
    action: 'list',
    status: 'active',
    limit: 100
}, function(resp) {
    if (resp.ok) {
        // Populate dropdown
        resp.data.forEach(wc => {
            $('#work_center_select').append(
                `<option value="${wc.id_work_center}">${wc.code} - ${wc.name}</option>`
            );
        });
    }
});
```

---

## 👥 2. Team System

### API Endpoint:
- **File:** `source/team_api.php`
- **Base URL:** `/source/team_api.php`

### Available Actions:
```php
case 'list':
    // GET /source/team_api.php?action=list
    // Parameters:
    //   - mode: 'oem'|'hatthasilpa'|'hybrid' (optional)
    //   - category: 'cutting'|'sewing'|'qc'|'finishing'|'general' (optional)
    //   - status: 'active'|'inactive' (optional)
    //   - q: string (search query, optional)
    // Response: {ok: true, data: [{id_team, code, name, team_category, production_mode, active}]}

case 'get':
    // GET /source/team_api.php?action=get&id={team_id}
    // Response: {ok: true, data: {id_team, code, name, team_category, production_mode, ...}}
    // Headers: ETag

case 'get_detail':
    // GET /source/team_api.php?action=get_detail&id={team_id}
    // Response: {ok: true, team: {...}, members: [...], workload: {...}}

case 'save':
    // POST /source/team_api.php?action=save
    // Body: {
    //   id_team?: int,
    //   code: string,
    //   name: string,
    //   description?: string,
    //   team_category?: 'cutting'|'sewing'|'qc'|'finishing'|'general',
    //   production_mode?: 'oem'|'hatthasilpa'|'hybrid',
    //   lead_id?: int,
    //   active?: 0|1
    // }
    // Response: {ok: true, id: int, message: string}
```

### Database Schema:
```sql
CREATE TABLE team (
    id_team INT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    id_org INT NOT NULL COMMENT 'Tenant isolation',
    team_category ENUM('cutting','sewing','qc','finishing','general') DEFAULT 'general',
    production_mode ENUM('oem','hatthasilpa','hybrid') DEFAULT 'hybrid',
    active TINYINT(1) DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by INT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_code_org (code, id_org),
    INDEX idx_org_active (id_org, active),
    INDEX idx_category (team_category, active),
    INDEX idx_production_mode (production_mode, active)
);
```

### Key Points:
- ✅ **team_category**: Functional classification (cutting, sewing, qc, finishing, general)
- ✅ **production_mode**: `oem` | `hatthasilpa` | `hybrid` (CRITICAL for dual production)
- ✅ Multi-tenant isolation via `id_org`
- ✅ Permission: `manager.team`, `manager.team.members`

### Usage in Graph Designer:
```javascript
// Load teams for team_category dropdown
$.get('source/team_api.php', {
    action: 'list',
    status: 'active',
    mode: 'hatthasilpa' // or 'hybrid'
}, function(resp) {
    if (resp.ok) {
        // Group by team_category
        const categories = {};
        resp.data.forEach(team => {
            if (!categories[team.team_category]) {
                categories[team.team_category] = [];
            }
            categories[team.team_category].push(team);
        });
        
        // Populate dropdown
        Object.keys(categories).forEach(cat => {
            $('#team_category_select').append(
                `<option value="${cat}">${cat.charAt(0).toUpperCase() + cat.slice(1)}</option>`
            );
        });
    }
});
```

---

## 📋 3. Assignment System

### API Endpoints:
- **Assignment API:** `source/assignment_api.php`
- **Assignment Plan API:** `source/assignment_plan_api.php`

### Key Concepts:

#### Node Pre-Assignment:
- Manager assigns operators to **nodes** (not individual tokens)
- System auto-assigns tokens when they enter assigned nodes
- **Table:** `node_assignment`
  ```sql
  CREATE TABLE node_assignment (
      id_node_assignment INT PRIMARY KEY AUTO_INCREMENT,
      id_instance INT NOT NULL COMMENT 'FK to job_graph_instance',
      id_node INT NOT NULL COMMENT 'FK to routing_node',
      assigned_to_user_id INT NOT NULL COMMENT 'Operator user ID',
      assigned_to_name VARCHAR(100),
      assigned_by_user_id INT NOT NULL COMMENT 'Manager user ID',
      assigned_at DATETIME DEFAULT NOW(),
      UNIQUE KEY (id_instance, id_node)
  );
  ```

#### Assignment Engine:
- **File:** `source/BGERP/Service/AssignmentEngine.php`
- **Precedence:** PIN > PLAN (Job/Node) > AUTO (skill + availability + load)
- **Auto-assignment:** Uses `TeamExpansionService` for load balancing

#### Team Expansion:
- **Service:** `BGERP\Service\TeamExpansionService`
- Expands team assignment to individual operators
- Load balancing: Pick operator with lowest current workload
- Respects availability (leave, absence)

### Key Points:
- ✅ Assignment happens at **node level** (not token level)
- ✅ Teams can be assigned → auto-expanded to members
- ✅ Load balancing based on current workload
- ✅ Respects operator availability

---

## 🗄️ 4. Database Schema - Routing Tables

### routing_node Table:
```sql
CREATE TABLE routing_node (
    id_node INT PRIMARY KEY AUTO_INCREMENT,
    id_graph INT NOT NULL COMMENT 'Parent graph',
    node_code VARCHAR(50) NOT NULL COMMENT 'Node code within graph',
    node_name VARCHAR(200) NOT NULL COMMENT 'Display name',
    node_type ENUM('start', 'operation', 'split', 'join', 'decision', 'end') NOT NULL,
    id_work_center INT NULL COMMENT 'Work center if operation type',
    estimated_minutes INT NULL COMMENT 'Standard operation time',
    node_config JSON NULL COMMENT 'Node-specific configuration',
    position_x INT NULL COMMENT 'UI canvas X position',
    position_y INT NULL COMMENT 'UI canvas Y position',
    sequence_no INT DEFAULT 0 COMMENT 'Display order',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE CASCADE,
    FOREIGN KEY (id_work_center) REFERENCES work_center(id_work_center) ON DELETE SET NULL,
    
    UNIQUE KEY uniq_graph_node_code (id_graph, node_code),
    INDEX idx_graph (id_graph),
    INDEX idx_type (node_type),
    INDEX idx_work_center (id_work_center)
);
```

### routing_edge Table:
```sql
CREATE TABLE routing_edge (
    id_edge INT PRIMARY KEY AUTO_INCREMENT,
    id_graph INT NOT NULL,
    from_node_id INT NOT NULL,
    to_node_id INT NOT NULL,
    edge_type ENUM('normal', 'rework', 'conditional') NOT NULL DEFAULT 'normal',
    edge_label VARCHAR(100) NULL COMMENT 'Label displayed on edge',
    edge_condition JSON NULL COMMENT 'Condition for conditional edges',
    condition_field VARCHAR(50) NULL COMMENT 'Legacy: field to evaluate',
    condition_value VARCHAR(100) NULL COMMENT 'Legacy: expected value',
    priority INT DEFAULT 0 COMMENT 'Priority for decision nodes',
    sequence_no INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE CASCADE,
    FOREIGN KEY (from_node_id) REFERENCES routing_node(id_node) ON DELETE CASCADE,
    FOREIGN KEY (to_node_id) REFERENCES routing_node(id_node) ON DELETE CASCADE,
    
    INDEX idx_from_node (from_node_id),
    INDEX idx_to_node (to_node_id),
    INDEX idx_graph (id_graph)
);
```

### Columns ที่มีอยู่แล้ว:
#### routing_node:
- ✅ `id_work_center` - FK to work_center
- ✅ `estimated_minutes` - เวลาที่ใช้ (นาที)
- ✅ `node_config` - JSON config
- ✅ `node_params` - JSON parameters (join_requirement อยู่ในนี้ ไม่ใช่ column แยก)
- ✅ `team_category` - ENUM('cutting','sewing','qc','finishing','general') - เพิ่มใน Phase 1
- ✅ `production_mode` - ENUM('oem','hatthasilpa','hybrid') - เพิ่มใน Phase 1
- ✅ `wip_limit` - INT - เพิ่มใน Phase 1
- ✅ `assignment_policy` - ENUM('auto','team_hint','team_lock') - เพิ่มใน Phase 1
- ✅ `preferred_team_id`, `allowed_team_ids`, `forbidden_team_ids` - เพิ่มใน Phase 1

**⚠️ CRITICAL:** 
- `team_category` และ `production_mode` เป็นคนละ field:
  - `team_category` = Functional classification (cutting/sewing/qc/finishing/general)
  - `production_mode` = Production type (oem/hatthasilpa/hybrid)
- `join_requirement` ไม่ใช่ column แยก แต่เก็บใน `node_params` JSON field

#### routing_edge:
- ✅ `edge_label` - Label บนเส้น
- ✅ `edge_condition` - JSON condition
- ✅ `condition_field`, `condition_value` - Legacy fields (deprecated)
- ✅ `priority` - ลำดับความสำคัญ
- ❌ `deleted_at` - **ไม่มี** (routing_edge ไม่มี soft-delete)

---

## 🔌 5. DAG Routing API

### API Endpoint:
- **File:** `source/dag_routing_api.php`
- **Base URL:** `/source/dag_routing_api.php`

### Current Actions:
```php
case 'graph_list':
    // GET /source/dag_routing_api.php?action=graph_list
    // Response: {ok: true, data: [{id_graph, name, status, ...}]}

case 'graph_get':
    // GET /source/dag_routing_api.php?action=graph_get&id_graph={id}
    // Response: {ok: true, data: {graph, nodes: [...], edges: [...]}}

case 'graph_save':
    // POST /source/dag_routing_api.php?action=graph_save
    // Body: {
    //   id_graph?: int,
    //   name: string,
    //   description?: string,
    //   nodes: [{id_node?, node_code, node_name, node_type, id_work_center?, estimated_minutes?, ...}],
    //   edges: [{id_edge?, from_node_id, to_node_id, edge_type, edge_label?, ...}]
    // }
    // Response: {ok: true, id_graph: int}

case 'graph_publish':
    // POST /source/dag_routing_api.php?action=graph_publish
    // Body: {id_graph}
    // Response: {ok: true, message: string}

case 'graph_validate':
    // POST /source/dag_routing_api.php?action=graph_validate
    // Body: {id_graph} or {nodes: [...], edges: [...]}
    // Response: {ok: true, valid: bool, errors: [...]}

case 'graph_delete':
    // POST /source/dag_routing_api.php?action=graph_delete
    // Body: {id_graph}
    // Response: {ok: true, message: string}
```

### Current graph_save Implementation:
```php
// ใน graph_save case
// Nodes array structure:
[
    {
        id_node?: int,
        node_code: string,
        node_name: string,
        node_type: 'start'|'operation'|'split'|'join'|'decision'|'end',
        id_work_center?: int,
        estimated_minutes?: int,
        node_config?: string (JSON string),
        position_x?: int,
        position_y?: int,
        sequence_no?: int
    }
]

// Edges array structure:
[
    {
        id_edge?: int,
        from_node_id: int,
        to_node_id: int,
        edge_type: 'normal'|'rework'|'conditional',
        edge_label?: string,
        edge_condition?: string (JSON string),
        priority?: int,
        sequence_no?: int
    }
]
```

### Missing Fields (ต้องเพิ่ม):
#### Nodes:
- ❌ `team_category` - ENUM('hatthasilpa','oem','hybrid') หรือ VARCHAR
- ❌ `wip_limit` - INT NULL

#### Edges:
- ✅ `edge_label` - มีอยู่แล้ว
- ✅ `edge_condition` - มีอยู่แล้ว
- ✅ `priority` - มีอยู่แล้ว

---

## 📝 6. Frontend - Graph Designer

### Current File:
- **File:** `assets/javascripts/dag/graph_designer.js`

### Current Structure:
```javascript
// Cytoscape.js initialization
let cy = cytoscape({
    container: document.getElementById('cy'),
    // ... config
});

// Node properties panel
function showNodeProperties(node) {
    // Currently shows:
    // - node_code
    // - node_name
    // - node_type
    // - position_x, position_y
    // Missing:
    // - id_work_center (dropdown)
    // - estimated_minutes (number input)
    // - team_category (dropdown)
    // - wip_limit (number input)
    // - node_config (JSON editor)
}

// Edge properties panel
function showEdgeProperties(edge) {
    // Currently shows:
    // - edge_type
    // - from_node_id, to_node_id
    // Missing:
    // - edge_label (text input)
    // - edge_condition (field + operator + value editor)
    // - priority (number input)
}

// Save function
function saveGraph() {
    // Currently sends:
    // - nodes: [{node_code, node_name, node_type, position_x, position_y}]
    // - edges: [{from_node_id, to_node_id, edge_type}]
    // Missing:
    // - nodes: [{id_work_center, estimated_minutes, team_category, wip_limit, node_config}]
    // - edges: [{edge_label, edge_condition, priority}]
}
```

---

## 🎯 7. Integration Points

### Work Center Integration:
```javascript
// Load work centers for dropdown
const workCenters = await fetch('source/work_centers.php?action=list&status=active')
    .then(r => r.json())
    .then(d => d.ok ? d.data : []);

// Populate dropdown
workCenters.forEach(wc => {
    $('#work_center_select').append(
        `<option value="${wc.id_work_center}">${wc.code} - ${wc.name}</option>`
    );
});
```

### Team Category Integration:
```javascript
// Team categories are fixed enum values
const teamCategories = [
    {value: 'hatthasilpa', label: 'Hatthasilpa'},
    {value: 'oem', label: 'OEM'},
    {value: 'hybrid', label: 'Hybrid'}
];

// Or load from team API to see which categories are in use
const teams = await fetch('source/team_api.php?action=list&status=active')
    .then(r => r.json())
    .then(d => d.ok ? d.data : []);

// Extract unique team_category values
const categories = [...new Set(teams.map(t => t.team_category))];
```

### Assignment Integration:
```javascript
// When node is selected, show assignment hints
function showAssignmentHints(nodeId) {
    // Call assignment_plan_api to get candidates
    fetch('source/assignment_plan_api.php?action=get_node_candidates&id_node=' + nodeId)
        .then(r => r.json())
        .then(d => {
            if (d.ok) {
                // Show teams/operators that can work this node
                displayAssignmentHints(d.data);
            }
        });
}
```

---

## ✅ 8. Summary & Next Steps

### What We Have:
1. ✅ **Work Center API** - Ready to use (`source/work_centers.php`)
2. ✅ **Team API** - Ready to use (`source/team_api.php`)
3. ✅ **Assignment System** - Ready for integration
4. ✅ **Database Schema** - Most columns exist
5. ✅ **DAG Routing API** - Basic CRUD ready

### What We Need to Add:

#### Database:
1. ❌ `routing_node.team_category` - ENUM('cutting','sewing','qc','finishing','general') NULL
2. ❌ `routing_node.production_mode` - ENUM('oem','hatthasilpa','hybrid') NULL
3. ❌ `routing_node.wip_limit` - INT NULL
4. ❌ `work_center_team_map` - Table สำหรับ mapping Work Center ↔ Team

#### API:
1. ❌ Update `graph_save` to accept new fields
2. ❌ Add ETag/If-Match support (partially exists)
3. ❌ Add `graph_duplicate` endpoint
4. ❌ Add `graph_archive` endpoint

#### Frontend:
1. ❌ Work Center dropdown in node properties
2. ❌ Estimated Minutes input
3. ❌ Team Category dropdown
4. ❌ WIP Limit input
5. ❌ Node Config JSON editor
6. ❌ Edge Label input
7. ❌ Edge Condition editor (field + operator + value)
8. ❌ Priority input
9. ❌ Update `saveGraph()` to send all new fields
10. ❌ ETag handling in `loadGraph()` and `saveGraph()`

---

## 🚀 Ready to Start Phase 1!

**Next Steps:**
1. ✅ Database migration: Add `team_category` and `wip_limit` to `routing_node`
2. ✅ Update API `graph_save` to accept new fields
3. ✅ Update Frontend to show new fields in inspector panels
4. ✅ Update `saveGraph()` to send all fields

**Estimated Time:** 2-3 days for Phase 1.1 (Node Properties Inspector)

