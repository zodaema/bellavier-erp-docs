# 📊 Routing Graph Designer - สรุปการวิเคราะห์แบบละเอียด

**วันที่วิเคราะห์:** 9 พฤศจิกายน 2025  
**สถานะ:** ✅ ใช้งานได้ แต่ยังมีจุดที่ต้องปรับปรุง

---

## 📁 โครงสร้างไฟล์

### 1. Backend Files
- **`page/routing_graph_designer.php`** (24 บรรทัด)
  - Page definition
  - Load CSS/JS libraries (DataTables, Toastr, SweetAlert2, Cytoscape.js)
  - Permission: `atelier.routing.manage`

- **`views/routing_graph_designer.php`** (239 บรรทัด)
  - HTML structure: 3-column layout
  - Left: Graph list + Toolbox
  - Center: Canvas (Cytoscape.js)
  - Right: Properties panel + Validation results
  - Modal: New Graph form

- **`views/routing_graph_help.php`** (405 บรรทัด)
  - Help guide modal (ภาษาไทย)
  - อธิบาย node types, edge types, validation rules
  - ตัวอย่าง flow

### 2. Frontend Files
- **`assets/javascripts/dag/graph_designer.js`** (779 บรรทัด)
  - Main JavaScript logic
  - Cytoscape.js integration
  - CRUD operations
  - Event handlers

### 3. API Files
- **`source/dag_routing_api.php`** (880 บรรทัด)
  - Graph CRUD endpoints
  - Node CRUD endpoints
  - Edge CRUD endpoints
  - Validation & publish endpoints

### 4. Service Files
- **`source/BGERP/Service/DAGValidationService.php`** (768 บรรทัด)
  - Graph validation logic
  - Cycle detection
  - Node/edge type validation

- **`source/BGERP/Service/DAGRoutingService.php`** (591 บรรทัด)
  - Graph status analysis
  - Bottleneck detection
  - Token routing logic

---

## 🗄️ Database Schema

### ตารางหลัก (3 ตาราง)

#### 1. `routing_graph`
```sql
- id_graph (PK)
- code (UNIQUE) - เช่น "TOTE_PRODUCTION_V1"
- name - ชื่อ graph
- description - คำอธิบาย
- graph_type - sequential|parallel|conditional|assembly
- status - draft|published|archived
- created_by, created_at
- published_at, published_by
- is_published (computed)
```

#### 2. `routing_node`
```sql
- id_node (PK)
- id_graph (FK → routing_graph)
- node_code - รหัส node (เช่น "CUT", "SEW")
- node_name - ชื่อ node
- node_type - start|end|operation|split|join|decision
- id_work_center (FK → work_center, nullable)
- estimated_minutes - เวลาที่ใช้ (นาที)
- position_x, position_y - ตำแหน่งบน canvas
- sequence_no - ลำดับ (สำหรับ sorting)
- node_config (JSON) - config เพิ่มเติม
- node_params (JSON) - parameters (join_requirement อยู่ในนี้)
- team_category, production_mode, wip_limit - เพิ่มใน Phase 1
- assignment_policy, preferred_team_id, allowed_team_ids, forbidden_team_ids - เพิ่มใน Phase 1
- created_at
```

**⚠️ NOTE:** `join_requirement` ไม่ใช่ column แยก แต่เก็บใน `node_params` JSON field

#### 3. `routing_edge`
```sql
- id_edge (PK)
- id_graph (FK → routing_graph)
- from_node_id (FK → routing_node)
- to_node_id (FK → routing_node)
- edge_type - normal|conditional|rework
- edge_label - label บนเส้น
- edge_condition (JSON) - สำหรับ conditional edges
- condition_field, condition_value - legacy fields (deprecated)
- priority - ลำดับความสำคัญ
- created_at
```

**⚠️ NOTE:** `routing_edge` ไม่มี `deleted_at` column (ไม่มี soft-delete support)

---

## 🎨 Frontend Features (JavaScript)

### 1. Cytoscape.js Integration
- **Library:** Cytoscape.js 3.28.1 (CDN)
- **Canvas:** 600px height, responsive
- **Node Colors:**
  - Start: Green (#28a745)
  - Operation: Blue (#17a2b8)
  - Split: Yellow (#ffc107)
  - Join: Orange (#fd7e14)
  - Decision: Gray (#6c757d)
  - End: Red (#dc3545)

### 2. Graph List (DataTable)
- **Location:** Left panel
- **Columns:** Name, Status (Published/Draft)
- **Features:**
  - Click row → Load graph
  - Auto-reload after create/delete
  - Search functionality

### 3. Toolbox
- **Node Types:** 6 buttons
  - Start, Operation, Split, Join, Decision, End
- **Edge Creation:** Toggle mode button
- **Workflow:** Click node type → Add to canvas → Click to edit properties

### 4. Canvas Operations
- **Add Node:** Click toolbox button → Node appears
- **Add Edge:** Toggle edge mode → Click source → Click target
- **Edit:** Click node/edge → Properties panel shows
- **Delete:** Select element → Press Delete key
- **Drag:** Drag nodes to reposition (auto-saves position)

### 5. Properties Panel
- **Node Properties:**
  - Node Code (required)
  - Node Name (required)
  - Node Type (read-only)
  - Work Center (missing - ต้องเพิ่ม!)
  - Estimated Minutes (missing - ต้องเพิ่ม!)
  - Join Requirement (missing - ต้องเพิ่ม!)

- **Edge Properties:**
  - Edge Type (normal/rework/conditional)
  - Condition Field (missing - ต้องเพิ่ม!)
  - Condition Value (missing - ต้องเพิ่ม!)

### 6. Graph Actions
- **Save:** Save nodes/edges to database
- **Validate:** Check graph validity
- **Publish:** Mark as published (requires validation)
- **Delete:** Delete graph (if not in use)

---

## 🔌 API Endpoints

### Graph Management

#### `graph_create` (POST)
- **Purpose:** สร้าง graph ใหม่
- **Input:** name, description, graph_type
- **Output:** id_graph, code
- **Features:**
  - Auto-generate code (NAME_V1)
  - Idempotency support
  - Status: draft

#### `graph_list` (GET)
- **Purpose:** List all graphs
- **Output:** Array of graphs with node_count, edge_count
- **Filter:** Optional status filter

#### `graph_get` (GET)
- **Purpose:** Get single graph with nodes & edges
- **Input:** id (graph ID)
- **Output:** Graph object with nodes[], edges[]
- **Features:** ETag for concurrency control

#### `graph_save` (POST)
- **Purpose:** Save graph structure (nodes + edges)
- **Input:** id_graph, nodes (JSON), edges (JSON)
- **Features:**
  - Transaction-based
  - Update existing, insert new
  - Delete removed edges
  - ETag/If-Match concurrency control

#### `graph_validate` (GET/POST)
- **Purpose:** Validate graph structure
- **Input:** id or id_graph
- **Output:** {valid: bool, errors: []}
- **Validation Rules:**
  1. Exactly 1 START node
  2. At least 1 END node
  3. No cycles (except rework edges)
  4. All nodes connected (no orphans)
  5. Split nodes: ≥2 outgoing edges
  6. Join nodes: ≥2 incoming edges
  7. Decision nodes: conditional edges only
  8. Operation nodes: work_center_id required

#### `graph_publish` (POST)
- **Purpose:** Publish graph (make available for production)
- **Input:** id_graph
- **Pre-requisite:** Must pass validation
- **Features:** Sets status='published', published_at, published_by

#### `graph_delete` (POST)
- **Purpose:** Delete graph
- **Input:** id_graph
- **Business Rule:** Cannot delete if used by job_graph_instance
- **Features:** Cascade deletes nodes & edges

### Node Management

#### `node_create` (POST)
- **Purpose:** Create single node
- **Input:** id_graph, node_code, node_name, node_type, id_work_center, estimated_minutes, position_x, position_y, node_config
- **Output:** id_node
- **Status:** ⚠️ Not used by frontend (uses graph_save instead)

#### `node_update` (POST)
- **Purpose:** Update node properties
- **Input:** id_node, node_name, position_x, position_y
- **Status:** ⚠️ Limited fields (missing work_center, estimated_minutes)
- **Status:** ⚠️ Not used by frontend

#### `node_delete` (POST)
- **Purpose:** Delete single node
- **Input:** id_node
- **Status:** ⚠️ Not used by frontend (uses graph_save instead)

### Edge Management

#### `edge_create` (POST)
- **Purpose:** Create single edge
- **Input:** id_graph, from_node_id, to_node_id, edge_type, edge_label, edge_condition, priority
- **Status:** ⚠️ Not used by frontend (uses graph_save instead)

#### `edge_delete` (POST)
- **Purpose:** Delete single edge
- **Input:** id_edge
- **Status:** ⚠️ Not used by frontend (uses graph_save instead)

### Graph Analysis

#### `get_graph_status` (GET)
- **Purpose:** Get runtime status of graph instance
- **Input:** instance_id
- **Output:** instance, nodes[], edges[], token_stats[], bottlenecks[]
- **Permission:** `hatthasilpa.job.ticket`

#### `get_graph_structure` (GET)
- **Purpose:** Get graph structure (nodes + edges)
- **Input:** id_graph
- **Output:** graph, nodes[], edges[]

#### `get_bottlenecks` (GET)
- **Purpose:** Find bottleneck nodes (most waiting tokens)
- **Input:** instance_id, limit
- **Output:** bottlenecks[]
- **Permission:** `hatthasilpa.job.ticket`

---

## ✅ Features ที่มีอยู่แล้ว

### 1. Basic CRUD ✅
- ✅ Create graph (modal form)
- ✅ List graphs (DataTable)
- ✅ Load graph (click row)
- ✅ Save graph (nodes + edges)
- ✅ Delete graph (with confirmation)

### 2. Visual Editor ✅
- ✅ Cytoscape.js canvas
- ✅ Add nodes (6 types)
- ✅ Add edges (edge mode)
- ✅ Drag nodes
- ✅ Delete elements (Delete key)
- ✅ Node/edge selection
- ✅ Visual feedback (colors, selection)

### 3. Validation ✅
- ✅ Graph validation (8 rules)
- ✅ Validation results display
- ✅ Publish requires validation
- ✅ Error messages (Thai)

### 4. Properties Panel ✅
- ✅ Node properties form
- ✅ Edge properties form
- ✅ Save properties
- ✅ Clear on deselect

### 5. Help System ✅
- ✅ Help guide modal (Thai)
- ✅ Node types explanation
- ✅ Edge types explanation
- ✅ Validation rules
- ✅ Examples

---

## ⚠️ Features ที่ยังขาดหรือต้องปรับปรุง

### 1. Properties Panel - ขาดข้อมูลสำคัญ

#### Node Properties (ปัจจุบัน):
- ✅ Node Code
- ✅ Node Name
- ✅ Node Type (read-only)
- ❌ **Work Center** - ขาด! (สำคัญมากสำหรับ operation nodes)
- ❌ **Estimated Minutes** - ขาด!
- ❌ **Join Requirement** (JSON) - ขาด! (สำหรับ join nodes)
- ❌ **Node Config** (JSON) - ขาด!
- ❌ **Sequence No** - ขาด! (สำหรับ sorting)

#### Edge Properties (ปัจจุบัน):
- ✅ Edge Type (normal/rework/conditional)
- ❌ **Condition Field** - ขาด! (สำหรับ conditional edges)
- ❌ **Condition Value** - ขาด! (สำหรับ conditional edges)
- ❌ **Edge Label** - ขาด!
- ❌ **Priority** - ขาด!

### 2. Graph Management - ขาด Features

- ❌ **Graph Update** - ไม่มี endpoint แยก (ใช้ graph_save แทน)
- ❌ **Graph Duplicate** - ไม่มี (ควรมีเพื่อสร้าง version ใหม่)
- ❌ **Graph Archive** - ไม่มี (มี status='archived' แต่ไม่มี UI)
- ❌ **Graph Versioning** - ไม่มี (code auto-generate เป็น _V1 เท่านั้น)
- ❌ **Graph Import/Export** - ไม่มี (JSON export/import)

### 3. Node Management - ขาด Features

- ❌ **Node Duplicate** - ไม่มี
- ❌ **Node Copy/Paste** - ไม่มี
- ❌ **Bulk Node Operations** - ไม่มี
- ❌ **Node Templates** - ไม่มี (pre-configured nodes)

### 4. Edge Management - ขาด Features

- ❌ **Edge Labels on Canvas** - ไม่แสดง label บนเส้น
- ❌ **Conditional Edge Editor** - ไม่มี UI สำหรับแก้ไข condition
- ❌ **Edge Priority Visualization** - ไม่แสดง priority
- ❌ **Edge Validation** - ไม่มี real-time validation

### 5. Canvas Features - ขาด Features

- ❌ **Zoom Controls** - ไม่มี UI buttons (ใช้ mouse wheel)
- ❌ **Pan Controls** - ไม่มี UI buttons
- ❌ **Fit to Screen** - มีใน code แต่ไม่มี button
- ❌ **Grid/Guides** - ไม่มี
- ❌ **Snap to Grid** - ไม่มี
- ❌ **Undo/Redo** - ไม่มี
- ❌ **Multi-select** - ไม่มี (ลากเลือกหลาย nodes)
- ❌ **Copy/Paste** - ไม่มี

### 6. Validation - ขาด Features

- ❌ **Real-time Validation** - ไม่มี (validate แค่ตอนกดปุ่ม)
- ❌ **Visual Error Indicators** - ไม่แสดง error บน canvas
- ❌ **Validation Suggestions** - ไม่มี (แค่บอก error)
- ❌ **Auto-fix Suggestions** - ไม่มี

### 7. Work Center Integration - ขาด Features

- ❌ **Work Center Dropdown** - ไม่มีใน properties panel
- ❌ **Work Center Validation** - ไม่เช็คว่า work center ถูกต้อง
- ❌ **Work Center Preview** - ไม่แสดง work center name

### 8. User Experience - ขาด Features

- ❌ **Unsaved Changes Warning** - มีแต่ basic (beforeunload)
- ❌ **Auto-save** - ไม่มี (ต้องกด Save เอง)
- ❌ **Keyboard Shortcuts** - มีแค่ Delete
- ❌ **Context Menu** - ไม่มี (right-click menu)
- ❌ **Tooltips** - ไม่มี (hover hints)
- ❌ **Loading States** - ไม่มี (skeleton/loading indicators)

### 9. Data Integrity - ขาด Features

- ❌ **ETag Handling** - มีใน API แต่ frontend ไม่ส่ง
- ❌ **Concurrency Control** - ไม่มี (อาจเกิด conflict)
- ❌ **Change History** - ไม่มี (audit log)
- ❌ **Graph Locking** - ไม่มี (ป้องกันแก้พร้อมกัน)

### 10. Performance - ขาด Features

- ❌ **Lazy Loading** - โหลด graph ทั้งหมดทันที
- ❌ **Virtualization** - ไม่มี (สำหรับ graph ใหญ่)
- ❌ **Debouncing** - ไม่มี (save อาจเรียกบ่อย)

---

## 🔍 Code Quality Issues

### 1. JavaScript Issues

#### Properties Panel:
```javascript
// ปัจจุบัน: แสดงแค่ node_code, node_name, node_type
// ขาด: work_center_id, estimated_minutes, join_requirement, node_config
```

#### Edge Properties:
```javascript
// ปัจจุบัน: แสดงแค่ edge_type
// ขาด: condition_field, condition_value, edge_label, priority
```

#### Save Function:
```javascript
// ปัจจุบัน: ไม่ส่ง work_center_id, estimated_minutes
// ต้องแก้: เพิ่ม fields เหล่านี้ใน saveGraph()
```

### 2. API Issues

#### graph_save:
- ✅ รับ nodes[], edges[] (JSON)
- ✅ Update/Insert nodes
- ✅ Update/Insert edges
- ❌ **ไม่ update work_center_id** (มีใน schema แต่ไม่ใช้)
- ❌ **ไม่ update estimated_minutes** (มีใน schema แต่ไม่ใช้)
- ❌ **ไม่ update join_requirement** (มีใน schema แต่ไม่ใช้)

#### node_update:
- ⚠️ มี endpoint แต่ frontend ไม่ใช้
- ⚠️ Limited fields (แค่ node_name, position)

### 3. Database Schema Issues

#### routing_node:
- ✅ มี work_center_id แต่ไม่ใช้ใน properties panel
- ✅ มี estimated_minutes แต่ไม่ใช้
- ✅ มี join_requirement แต่ไม่ใช้
- ✅ มี node_config แต่ไม่ใช้
- ✅ มี node_params แต่ไม่ใช้

#### routing_edge:
- ✅ มี condition_field, condition_value แต่ไม่ใช้
- ✅ มี edge_label แต่ไม่ใช้
- ✅ มี priority แต่ไม่ใช้
- ✅ มี edge_condition (JSON) แต่ไม่ใช้

---

## 📊 สรุปสถานะ

### ✅ ทำงานได้แล้ว (Core Features)
1. ✅ Create/List/Load/Delete graphs
2. ✅ Visual editor (Cytoscape.js)
3. ✅ Add nodes (6 types)
4. ✅ Add edges
5. ✅ Drag & drop nodes
6. ✅ Basic properties editing
7. ✅ Graph validation
8. ✅ Publish workflow
9. ✅ Help guide

### ⚠️ ต้องปรับปรุง (Missing Features)
1. ⚠️ Properties panel - ขาด fields สำคัญ
2. ⚠️ Work center integration - ไม่มี dropdown
3. ⚠️ Edge properties - ขาด condition fields
4. ⚠️ Graph versioning - ไม่มี
5. ⚠️ Canvas UX - ขาด zoom/pan controls
6. ⚠️ Undo/Redo - ไม่มี
7. ⚠️ Real-time validation - ไม่มี
8. ⚠️ Auto-save - ไม่มี

### 🐛 Bugs ที่พบ
1. 🐛 Properties panel ไม่แสดง work_center_id
2. 🐛 Properties panel ไม่แสดง estimated_minutes
3. 🐛 Edge properties ไม่แสดง condition fields
4. 🐛 Save ไม่ส่ง work_center_id, estimated_minutes
5. 🐛 ไม่มี ETag handling ใน frontend

---

## 🎯 แนะนำการปรับปรุง (Priority)

### Priority 1: Critical (ต้องทำทันที)
1. ✅ เพิ่ม Work Center dropdown ใน node properties
2. ✅ เพิ่ม Estimated Minutes field ใน node properties
3. ✅ แก้ไข saveGraph() ให้ส่ง work_center_id, estimated_minutes
4. ✅ เพิ่ม Condition Field/Value ใน edge properties
5. ✅ แก้ไข graph_save API ให้รับ/บันทึก fields เหล่านี้

### Priority 2: Important (ควรทำเร็วๆ)
1. ✅ เพิ่ม Join Requirement editor (สำหรับ join nodes)
2. ✅ เพิ่ม Node Config editor (JSON editor)
3. ✅ เพิ่ม Edge Label field
4. ✅ เพิ่ม Edge Priority field
5. ✅ เพิ่ม Zoom/Pan controls
6. ✅ เพิ่ม Undo/Redo

### Priority 3: Nice to Have (ทำเมื่อมีเวลา)
1. ✅ Graph duplicate/clone
2. ✅ Graph versioning
3. ✅ Real-time validation
4. ✅ Auto-save
5. ✅ Multi-select
6. ✅ Copy/Paste

---

## 📝 สรุป

**Routing Graph Designer มีโครงสร้างพื้นฐานที่แข็งแรง** แต่ยังขาด features สำคัญหลายอย่าง โดยเฉพาะ:

1. **Properties Panel** - ขาด fields สำคัญ (work_center, estimated_minutes, conditions)
2. **API Integration** - มี endpoints แต่ frontend ไม่ใช้ครบ
3. **User Experience** - ขาด UX features (undo/redo, auto-save, zoom controls)

**แนะนำให้เริ่มปรับปรุงจาก Priority 1 ก่อน** เพื่อให้ระบบใช้งานได้สมบูรณ์ขึ้น

