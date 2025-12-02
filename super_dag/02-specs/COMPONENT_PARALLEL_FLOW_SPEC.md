# Component Parallel Flow Spec

**Status:** Production-Ready Specification  
**Concept Date:** 2025-12-02  
**Version:** 2.1 (Production-Grade, 3-5 year lifespan)  
**Category:** SuperDAG / Component Token / Parallel Work

**⚠️ CRITICAL VISION:** Component Token = **CORE MECHANIC** ของ Hatthasilpa Workflow  
**ไม่ใช่ optional enhancement แต่เป็น mandatory architecture**

**⚠️ MECHANISM:** Component Token uses **Native Parallel Split** (`is_parallel_split` flag), **NOT Subgraph `fork` mode**

**See Also:** 
- Concept: `docs/dag/02-concepts/COMPONENT_PARALLEL_FLOW.md`
- Audit: `docs/dag/00-audit/20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md`
- Subgraph Comparison: `docs/dag/00-audit/20251202_SUBGRAPH_VS_COMPONENT_AUDIT_REPORT.md`

---

## 0. Terminology (Token Types)

**⚠️ CRITICAL:** ใช้คำศัพท์ให้ตรงกันตลอดทั้ง spec

### Token Types (จาก `flow_token.token_type` enum)

| Type | `token_type` Value | Description | Example |
|------|-------------------|-------------|---------|
| **Final Token** | `'piece'` | กระเป๋า 1 ใบ (final product) | กระเป๋า TOTE ใบหนึ่งที่มี serial F001 |
| **Component Token** | `'component'` | ชิ้นส่วนย่อยของ Final Token | BODY / FLAP / STRAP ของกระเป๋า F001 |
| **Batch Token** | `'batch'` | กลุ่มชิ้นงานที่ process พร้อมกัน | Cutting batch 10 ชิ้น |

**Note:** 
- ไม่มี `token_type = 'final'` (ใช้ `'piece'` สำหรับ final product)
- Final Token = `token_type = 'piece'` + `parent_token_id IS NULL`
- Component Token = `token_type = 'component'` + `parent_token_id IS NOT NULL`

### Relationship Mechanism

**⚠️ ARCHITECTURE LAW:**
```
Component Token ↔ Final Token relationship = parent_token_id / parallel_group_id
NOT serial number pattern matching
```

**Database Fields (flow_token):**
- `parent_token_id` INT - FK to parent Final Token (ถ้าเป็น component)
- `parallel_group_id` INT - Parallel group ของ components จาก split node เดียวกัน
- `parallel_branch_key` VARCHAR(50) - Branch identifier ('A', 'B', 'C' หรือ '1', '2', '3')

**Serial Numbers = Labels Only:**
- `serial_number` VARCHAR(100) - Human-readable label (ไม่ใช่ relationship key)
- Component Serial (ถ้ามี) = แค่ label เท่านั้น
- **ห้ามใช้ serial pattern matching** (เช่น F001-BODY, F001-FLAP)
- Real relationship = `parent_token_id` + `parallel_group_id` (ใน token graph)

---

## 1. Core Principle: Component Tokens = First-Class Tokens

### 1.1 Component Token = Core Mechanic

**Component Token = First-Class Token** (ไม่ใช่ sub-token หรือ optional feature)

**Architecture Principle:**
- Component Token มี work session ของตัวเอง
- Component Token มี time tracking ของตัวเอง
- Component Token มี behavior execution ของตัวเอง
- Component Token = **Core Mechanic** ของ Hatthasilpa workflow

**Why Component Tokens Are Mandatory:**

1. **Parallel Craftsmanship Model:**
   - Bag มีหลายชิ้นส่วน (BODY, FLAP, STRAP, LINING, etc.)
   - แต่ละชิ้นส่วนทำโดยช่างคนละคน **พร้อมกัน (parallel)**
   - แต่ละช่างจับเวลาแยกกัน
   - Assembly = รวมชิ้นส่วนที่เสร็จแล้ว

2. **Component-Level Time Tracking:**
   - แต่ละช่างจับเวลาแยกกัน
   - Component token = work session แยกกัน
   - Time tracking per component = จำเป็นสำหรับ craftsmanship analytics

3. **ETA Model:**
   - ETA ของทั้งใบ = `max(component_times) + assembly_time`
   - Bottleneck = component ที่ใช้เวลานานที่สุด
   - ต้อง track component time แยกกันเพื่อคำนวณ ETA

4. **Assembly Merge:**
   - Assembly node = join component tokens
   - Final serial เกิดตอน **Job Creation** (ไม่ใช่ Assembly)
   - Assembly = รอให้ทุก component เสร็จก่อน re-activate final token

5. **Craftsmanship Traceability:**
   - Storytelling ของกระเป๋า = เวลาของแต่ละช่างในแต่ละชิ้น
   - ต้องรู้ว่าใครทำชิ้นไหน ใช้เวลาเท่าไหร่
   - Component token = signature ของแต่ละช่าง

6. **Multi-Craftsman Signature:**
   - แต่ละ component = signature ของช่างคนนั้น
   - QC ของแต่ละ component = คนละ node, คนละ behavior
   - ต้อง track component-level QC แยกกัน

7. **Bottleneck Analytics:**
   - ชิ้นไหนเสร็จช้า = bottleneck ของใบ
   - ต้องวิเคราะห์ component time เพื่อหา bottleneck
   - Component token = data source สำหรับ analytics

### 1.2 Job Tray (ถาดงาน) - Physical Container

**Status:** 🚧 **TARGET** (ยังไม่ implement)

**⚠️ CRITICAL:** Job Tray = Physical container in factory

**Relationship:**
- 1 Final Token = 1 Job Tray
- All components of a Final Token → Must be in the same tray
- Tray has QR/Tag with `final_serial` / `id_final_token`

**Database (Target):**
```sql
job_tray: -- ⚠️ ยังไม่มี table นี้
  - id_tray (PK)
  - id_final_token (FK to flow_token.id_token)
  - tray_code (VARCHAR) -- Physical tray identifier printed on tray
  - tray_label (VARCHAR) -- Optional human-readable label
  - created_at (DATETIME)
```

**Why derive `final_serial` from join instead of storing?**
- ลด redundancy: `final_serial` มาจาก `flow_token.serial_number` อยู่แล้ว
- Prevent inconsistency: ถ้าเก็บซ้ำอาจไม่ sync
- **Preferred:** JOIN กับ flow_token แทน

**Physical Reality:**
- Workers pick up "Tray F001" → Work with all components of F001
- No mixing: Components of F001 must stay in Tray F001
- Digital relationship (`parent_token_id`) = Physical relationship (tray)

**Role of Job Tray:**
- **Mapping physical ↔ final token** (ไม่ใช่ owner ของ serial เอง)
- Tray ไม่มี logic serial generation
- Tray = container only

**❌ Anti-pattern:**
- ❌ **DO NOT allow components of one piece to mix with another piece's tray**
- ❌ **DO NOT store serial generation logic in job_tray table**

---

## 2. Current Database Schema (100% Based on Actual Code)

### 2.1 flow_token (Token Table)

**Source:** `database/tenant_migrations/0001_init_tenant_schema_v2.php` line 694

**Current Schema:**
```sql
flow_token (
  id_token INT PRIMARY KEY AUTO_INCREMENT,
  id_instance INT NOT NULL COMMENT 'Parent graph instance',
  graph_version VARCHAR(20) NULL,
  
  -- Token Type & Identity
  token_type ENUM('batch','piece','component') NOT NULL DEFAULT 'piece'
    COMMENT 'batch=entire lot, piece=single item, component=sub-assembly part',
  serial_number VARCHAR(100) NULL 
    COMMENT 'Serial/lot identifier (e.g., TOTE-2025-A7F3C9)',
  
  -- Relationship Fields
  parent_token_id INT NULL COMMENT 'Parent token if split from another',
  child_tokens JSON NULL COMMENT 'Array of child token IDs if split occurred',
  
  -- Parallel Execution Fields (Task 17)
  parallel_group_id INT NULL COMMENT 'Parallel group ID for tokens spawned from same split node',
  parallel_branch_key VARCHAR(50) NULL COMMENT 'Branch identifier within parallel group (e.g., A, B, C)',
  
  -- Current State
  current_node_id INT NULL COMMENT 'Current node position (NULL if completed/scrapped)',
  status ENUM('ready','active','waiting','paused','completed','scrapped') NOT NULL DEFAULT 'ready',
  qty DECIMAL(10,2) DEFAULT 1.00,
  metadata JSON NULL,
  
  -- Timestamps
  spawned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME NULL,
  scrapped_at DATETIME NULL,
  
  -- Indexes
  KEY idx_instance (id_instance),
  KEY idx_serial (serial_number),
  KEY idx_status (status),
  KEY idx_current_node (current_node_id),
  KEY idx_parent (parent_token_id),
  KEY idx_parallel_group (parallel_group_id, status),
  KEY idx_parallel_group_node (parallel_group_id, current_node_id, status),
  
  FOREIGN KEY (id_instance) REFERENCES job_graph_instance (id_instance) ON DELETE CASCADE,
  FOREIGN KEY (parent_token_id) REFERENCES flow_token (id_token) ON DELETE SET NULL,
  FOREIGN KEY (current_node_id) REFERENCES routing_node (id_node) ON DELETE SET NULL
)
```

**⚠️ Missing Fields (Target):**
- ❌ `component_code` VARCHAR(50) - Component identifier (BODY, FLAP, STRAP)
- ❌ `id_component` INT - FK to product_component (Task 5)

**Current Workaround:**
- ใช้ `metadata` JSON field เก็บ `component_code` ชั่วคราว
- Example: `metadata: {"component_code": "BODY", "component_name": "Bag Body"}`

### 2.2 routing_node (Node Table)

**Source:** `database/tenant_migrations/0001_init_tenant_schema_v2.php` line 3024-3028

**Current Schema (Parallel/Merge Support):**
```sql
routing_node (
  id_node INT PRIMARY KEY AUTO_INCREMENT,
  id_graph INT NOT NULL,
  node_code VARCHAR(100) NOT NULL,
  node_name VARCHAR(255) NULL,
  node_type ENUM('normal','start','end','decision','subgraph') NOT NULL,
  
  -- Behavior Fields
  behavior_code VARCHAR(100) NULL,
  execution_mode ENUM('single','piece','batch') NULL,
  ui_template VARCHAR(100) NULL,
  
  -- Parallel/Merge Flags (Task 17)
  is_parallel_split TINYINT(1) NOT NULL DEFAULT 0 
    COMMENT 'Flag: This node starts parallel branches (2+ outgoing edges required)',
  is_merge_node TINYINT(1) NOT NULL DEFAULT 0 
    COMMENT 'Flag: This node merges parallel branches (2+ incoming edges required)',
  merge_mode VARCHAR(50) NULL 
    COMMENT 'Merge semantics: ALL (wait for all branches), ANY (wait for any branch), N_OF_M',
  
  -- Indexes
  KEY idx_parallel_split (is_parallel_split),
  KEY idx_merge_node (is_merge_node)
)
```

**⚠️ Missing Fields (Target for Component Flow):**
- ❌ `produces_component` VARCHAR(50) - Component code this node produces/works with
- ❌ `consumes_components` JSON - Array of component codes required for this node

**Current Limitation:**
- ไม่มี node-to-component mapping
- ยังไม่ implement logic สร้าง component token จาก parallel split
- ยังไม่ implement merge validation (check if all components complete)

---

## 3. Behavior Execution for Component Tokens

### 3.1 Current Behavior Handlers

**Source:** `source/BGERP/Dag/BehaviorExecutionService.php` line 137-168

**Current Implementation:**
```php
switch ($behaviorCode) {
    case 'STITCH':
        return $this->handleStitch($sourcePage, $action, $context, $formData);
    
    case 'CUT':
        return $this->handleCut($sourcePage, $action, $context, $formData);
    
    case 'EDGE':
        return $this->handleEdge($sourcePage, $action, $context, $formData);
    
    case 'QC_SINGLE':
    case 'QC_FINAL':
    case 'QC_REPAIR':
    case 'QC_INITIAL':
        return $this->handleQc($sourcePage, $action, $context, $formData);
    
    // Task 27.1: Single-piece behaviors
    case 'HARDWARE_ASSEMBLY':
    case 'SKIVE':
    case 'GLUE':
    case 'ASSEMBLY':
    case 'PACK':
    case 'EMBOSS':
        return $this->handleSinglePiece($behaviorCode, $sourcePage, $action, $context, $formData);
    
    default:
        return ['ok' => false, 'error' => 'unsupported_behavior'];
}
```

**Handler Methods:**
- `handleStitch()` - STITCH behavior only (legacy, stable)
- `handleSinglePiece($behaviorCode, ...)` - Generic handler for single-piece behaviors
- `handleCut()` - CUT (batch) behavior
- `handleEdge()` - EDGE behavior
- `handleQc()` - QC behaviors (all types)

### 3.2 Behavior Support Matrix (Bellavier Hatthasilpa Factory Model)

**Status:** 🏭 **CURRENT** (Based on actual factory workflow as of 2025-12-02)

| Behavior | Piece Token Support | Component Token Support | Notes |
|----------|--------------------|-----------------------|-------|
| **STITCH** | ✅ Yes | ✅ **TARGET** | ช่างเย็บ component แยกกัน (BODY, FLAP, STRAP) |
| **HARDWARE_ASSEMBLY** | ✅ Yes | ✅ **TARGET** | ประกอบฮาร์ดแวร์ต่อ component |
| **SKIVE** | ✅ Yes | ✅ **TARGET** | ลดความหนาหนัง component |
| **GLUE** | ✅ Yes | ✅ **TARGET** | ทาน้ำยาติด component |
| **EDGE** | ✅ Yes | 🎯 **Component-Specific** | ทา edge ของ component (ไม่ใช้กับ final) |
| **EMBOSS** | ✅ Yes | ✅ **TARGET** | ปั๊มหนัง component |
| **QC_SINGLE** | ✅ Yes | ✅ **TARGET** | QC ต่อ component แยกกัน |
| **QC_INITIAL** | ✅ Yes | ✅ **TARGET** | QC เบื้องต้น component |
| **QC_REPAIR** | ✅ Yes | ✅ **TARGET** | QC หลัง repair component |
| **QC_FINAL** | ✅ Yes | ❌ Final only | QC final product หลัง assembly |
| **CUT** | 🎯 **Batch only** | ❌ Not Applicable | Cutting เป็น batch (ไม่ใช้ piece/component) |
| **ASSEMBLY** | ✅ **Final only** | ❌ Not Applicable | รวม components → final |
| **PACK** | ✅ **Final only** | ❌ Not Applicable | แพ็คสินค้าสำเร็จ (final only) |

**Legend:**
- ✅ Yes = Supported in current implementation
- ✅ **TARGET** = Architecturally supported, waiting for component flow implementation
- 🎯 **Specific** = Special use case (e.g., EDGE for components only, CUT for batch only)
- ❌ Not Applicable = Does not apply to this token type

**⚠️ IMPORTANT NOTE:**

This matrix represents **Bellavier Hatthasilpa factory workflow as of 2025-12-02.**  
It is NOT an architectural law that prevents future extensions.

**If future routing requires:**
- CUT per component (e.g., cut specific component shapes separately)
- PACK component sets (e.g., pack components before assembly)

**Then:**
1. Update this matrix in SPEC
2. Implement handler logic in BehaviorExecutionService
3. Update factory workflow documentation

**Do NOT assume:** "CUT cannot work with components forever" — it's a current factory constraint, not an architecture constraint.

### 3.3 Behavior Execution Context

**All behaviors accept these context fields:**
```php
$context = [
    'token_id' => 123,              // Component token or Final token
    'node_id' => 456,                // Current node
    'work_center_id' => 789,         // Work center
    'operator_id' => 101,            // Worker ID
    'execution_mode' => 'piece',     // single/piece/batch
    
    // Optional for component tokens (TARGET):
    'component_code' => 'BODY',      // BODY, FLAP, STRAP, etc.
    'parent_token_id' => 100,        // Final token ID (if component)
    'parallel_group_id' => 5         // Parallel group
];
```

**Current Behavior Logic:**
- Behaviors ไม่ได้แยก logic ตาม `token_type` (ใช้ logic เดียวกันทั้ง piece และ component)
- Time tracking ทำผ่าน `TokenWorkSessionService` (รองรับทุก token_type)
- Routing ทำผ่าน `DagExecutionService` (รองรับทุก token_type)

**Target Enhancement:**
- เพิ่ม validation: `behaviorSupportsTokenType($behaviorCode, $tokenType)`
- เพิ่ม component-specific rules (e.g., EDGE ใช้ได้กับ component เท่านั้น)

---

## 4. Parallel Split Mechanism (Native Parallel Split)

### 4.1 Current Implementation

**Source:** `database/tenant_migrations/0001_init_tenant_schema_v2.php`

**Parallel Split Flag:**
```sql
routing_node.is_parallel_split = 1
```

**When token reaches a parallel split node:**
1. ระบบ spawn multiple tokens (ตามจำนวน outgoing edges)
2. แต่ละ token ได้รับ:
   - `parallel_group_id` เดียวกัน
   - `parallel_branch_key` แตกต่างกัน ('A', 'B', 'C' หรือ '1', '2', '3')
3. Parent token → `status = 'waiting'` (รอ merge)

**⚠️ CURRENT GAP:**
- ✅ Database schema ready (parallel_group_id, parallel_branch_key)
- ✅ Node flags ready (is_parallel_split, is_merge_node)
- ❌ **Token spawn logic NOT IMPLEMENTED** (ไม่มี splitToken() / createComponentToken())
- ❌ **Node-to-component mapping NOT IMPLEMENTED** (ไม่มี produces_component field)

### 4.2 Target Node-to-Component Mapping

**⚠️ TARGET:** (ยังไม่ implement)

**Required Schema:**
```sql
routing_node:
  - produces_component VARCHAR(50) NULL -- Component code this node produces/works with
  - consumes_components JSON NULL -- Array of component codes required for merge node
```

**Parallel Split Node Example:**
```sql
-- Split node
id_node: 10
node_code: 'PARALLEL_SPLIT_01'
is_parallel_split: 1
produces_component: NULL -- Split node ไม่ produce

-- Target nodes (outgoing edges)
id_node: 11, node_code: 'STITCH_BODY', produces_component: 'BODY'
id_node: 12, node_code: 'STITCH_FLAP', produces_component: 'FLAP'
id_node: 13, node_code: 'STITCH_STRAP', produces_component: 'STRAP'
```

**Target Logic:**
```php
// When final token reaches parallel split node:
function handleParallelSplit($finalTokenId, $splitNodeId) {
    // Get outgoing edges
    $edges = getOutgoingEdges($splitNodeId);
    
    $parallelGroupId = generateParallelGroupId();
    
    foreach ($edges as $i => $edge) {
        $targetNode = getNode($edge['to_node_id']);
        $componentCode = $targetNode['produces_component']; // BODY, FLAP, STRAP
        
        // Create component token
        createComponentToken([
            'token_type' => 'component',
            'parent_token_id' => $finalTokenId,
            'parallel_group_id' => $parallelGroupId,
            'parallel_branch_key' => ($i + 1), // 1, 2, 3
            'metadata' => ['component_code' => $componentCode], // Temporary workaround
            'current_node_id' => $edge['to_node_id']
        ]);
    }
    
    // Update final token
    updateToken($finalTokenId, ['status' => 'waiting']);
}
```

### 4.3 Critical Rules for Parallel Split

**1. Component Token MUST have `parent_token_id`**
```sql
-- All component tokens MUST reference parent final token
WHERE token_type = 'component' AND parent_token_id IS NOT NULL
```

**2. Final Token status after split**
```sql
-- Final token becomes 'waiting' until merge
UPDATE flow_token SET status = 'waiting' WHERE id_token = <final_token_id>
```

**3. Final Token still linked to Job Tray (TARGET)**
- ถึงแม้ final token จะ split → ยังผูกกับ job_tray อยู่
- Component tokens ทุกตัว = ชิ้นส่วนใน tray เดียวกัน

---

## 5. Merge Node Semantics

**⚠️ IMPORTANT:** Merge semantics นิยามหลักอยู่ใน SuperDAG Core Spec  
Spec นี้ระบุเฉพาะ **Component Token interaction with merge engine**

**For detailed merge engine semantics (join buffer, AT_LEAST, TIMEOUT_FAIL policies):**  
→ See SuperDAG Core Merge Spec (ยังไม่มีไฟล์นี้ - TODO)

### 5.1 Component Token Merge Contract

**When all component tokens reach merge node:**

1. **Re-activate Final Token** (ไม่สร้าง token ใหม่)
   ```sql
   UPDATE flow_token 
   SET status = 'active', current_node_id = <merge_node_id>
   WHERE id_token = <final_token_id>
   ```

2. **Mark Component Tokens as 'merged'** (keep for traceability)
   ```sql
   UPDATE flow_token 
   SET status = 'completed', 
       metadata = JSON_SET(metadata, '$.merged_at', NOW(), '$.merged_into_token_id', <final_token_id>)
   WHERE id_token IN (<component_token_ids>)
   ```

3. **Aggregate Component Data into Final Token**
   ```json
   // Final token metadata after merge
   {
     "component_times": {
       "BODY": {"duration_ms": 7200000, "worker_id": 101, "worker_name": "Alice"},
       "FLAP": {"duration_ms": 5400000, "worker_id": 102, "worker_name": "Bob"},
       "STRAP": {"duration_ms": 3600000, "worker_id": 103, "worker_name": "Carol"}
     },
     "max_component_time": 7200000,
     "total_component_time": 16200000,
     "merged_component_tokens": [201, 202, 203],
     "component_qc_status": {
       "BODY": "pass",
       "FLAP": "pass",
       "STRAP": "pass"
     }
   }
   ```

**⚠️ CRITICAL:**
- Final Serial เกิดตอน **Job Creation** (ไม่ใช่ Assembly/Merge)
- Assembly ไม่ generate serial ใหม่
- Assembly = re-activate final token ที่มี serial อยู่แล้ว

### 5.2 Merge Policy for Component Flow

**Default Policy:** `ALL` (wait for all component tokens)

**Merge Node Configuration:**
```sql
routing_node:
  - is_merge_node: 1
  - merge_mode: 'ALL' -- Wait for all components
  - consumes_components: '["BODY","FLAP","STRAP"]' -- Required components
```

**Validation:**
```php
function validateMergeCompletion($finalTokenId, $mergeNodeId) {
    $node = getNode($mergeNodeId);
    $requiredComponents = json_decode($node['consumes_components'], true);
    
    $completedComponents = getCompletedComponentCodes($finalTokenId);
    
    $missing = array_diff($requiredComponents, $completedComponents);
    
    if (!empty($missing)) {
        return [
            'complete' => false,
            'missing' => $missing,
            'message' => 'ยังไม่ครบทุก component'
        ];
    }
    
    return ['complete' => true];
}
```

---

## 6. Work Queue Integration

### 6.1 Work Queue View by Role

**⚠️ CRITICAL:** แยก view ตาม worker role เพื่อป้องกันความสับสน

**Component Workers:**
- เห็น **component tokens** (BODY, FLAP, STRAP)
- ไม่จำเป็นต้องเห็น Final Token รายละเอียดมาก
- Filter: `token_type = 'component'` AND worker เข้าถึง node ได้

**Assembly Workers:**
- เห็นเฉพาะ **Final Token** (F001, F002) + status ว่า components complete หรือยัง
- ❌ ไม่เห็นรายการ component tokens แยกชิ้น
- Filter: `token_type = 'piece'` AND `current_node_id = assembly_node`

**Implementation (Target):**
```sql
-- Component Worker View
SELECT 
  ft.id_token,
  ft.serial_number,
  ft.metadata->>'$.component_code' AS component_code,
  ft.parent_token_id,
  parent.serial_number AS final_serial,
  rn.node_name,
  rn.behavior_code
FROM flow_token ft
JOIN flow_token parent ON parent.id_token = ft.parent_token_id
JOIN routing_node rn ON rn.id_node = ft.current_node_id
WHERE ft.token_type = 'component'
  AND ft.status IN ('ready', 'active')
  AND rn.work_center_id IN (SELECT work_center_id FROM worker_access WHERE id_member = ?)
ORDER BY ft.spawned_at ASC;

-- Assembly Worker View
SELECT 
  ft.id_token,
  ft.serial_number AS final_serial,
  ft.status,
  (SELECT COUNT(*) FROM flow_token WHERE parent_token_id = ft.id_token AND token_type = 'component' AND status = 'completed') AS completed_components,
  (SELECT COUNT(*) FROM flow_token WHERE parent_token_id = ft.id_token AND token_type = 'component') AS total_components,
  rn.node_name
FROM flow_token ft
JOIN routing_node rn ON rn.id_node = ft.current_node_id
WHERE ft.token_type = 'piece'
  AND ft.current_node_id IN (SELECT id_node FROM routing_node WHERE is_merge_node = 1)
  AND rn.work_center_id IN (SELECT work_center_id FROM worker_access WHERE id_member = ?)
ORDER BY ft.spawned_at ASC;
```

**UI Filtering:**
```javascript
// Work Queue UI
function loadWorkQueue(workerRole) {
    const params = {
        action: 'list_tokens',
        worker_id: currentWorkerId,
        role: workerRole // 'component_worker' or 'assembly_worker'
    };
    
    $.post('source/dag_work_queue_api.php', params, function(response) {
        if (response.ok) {
            renderWorkQueue(response.tokens, workerRole);
        }
    });
}

function renderWorkQueue(tokens, role) {
    if (role === 'component_worker') {
        // Show: Component Code, Final Serial, Node Name, Start Button
        tokens.forEach(token => {
            addRow(token.component_code, token.final_serial, token.node_name);
        });
    } else if (role === 'assembly_worker') {
        // Show: Final Serial, Components Status (3/3 complete), Assembly Button
        tokens.forEach(token => {
            const status = `${token.completed_components}/${token.total_components} complete`;
            addRow(token.final_serial, status, token.node_name);
        });
    }
}
```

**❌ Anti-pattern:**
- ❌ **DO NOT show component tokens to assembly worker** (confusing, they work on final token only)
- ❌ **DO NOT mix component view and final view in same list** (hard to distinguish)

---

## 7. Serial Number Strategy

### 7.1 Final Serial Generation

**⚠️ CRITICAL:** Final Serial เกิดตอน **Job Creation** (ไม่ใช่ Assembly)

**When:**
- Hatthasilpa Job created
- System generates N final tokens (ตามจำนวนใบที่ต้องผลิต)
- Each final token gets `serial_number` immediately

**Example:**
```php
// Job Creation
createHatthasilpaJob([
    'job_code' => 'JOB-2025-001',
    'product_id' => 123,
    'target_qty' => 5 // 5 bags
]);

// System creates 5 final tokens:
// F001, F002, F003, F004, F005 (serial generated at creation)
```

**Assembly Node:**
- ไม่ generate serial ใหม่
- ใช้ serial ที่มีอยู่แล้วจาก final token
- แค่ re-activate final token + aggregate component data

### 7.2 Component Serial (Label Only)

**⚠️ ARCHITECTURE LAW:**

```
Component Serial = Label Only (NOT Relationship Key)
Real relationship = parent_token_id + parallel_group_id
```

**If component serial exists:**
- เก็บใน `flow_token.serial_number` (เช่น "C-BODY-001")
- หรือ `metadata->>'$.component_serial'`
- **ใช้เป็น human-readable label เท่านั้น**

**❌ DO NOT:**
```php
// ❌ WRONG: Serial pattern matching
function findComponentBySerial($finalSerial, $componentCode) {
    $componentSerial = $finalSerial . '-' . $componentCode; // F001-BODY
    return db_query("SELECT * FROM flow_token WHERE serial_number = ?", [$componentSerial]);
}
```

**✅ CORRECT:**
```php
// ✅ RIGHT: Use token graph relationships
function findComponentByTokenGraph($finalTokenId, $componentCode) {
    return db_query("
        SELECT * 
        FROM flow_token 
        WHERE parent_token_id = ? 
          AND token_type = 'component'
          AND metadata->>'$.component_code' = ?
    ", [$finalTokenId, $componentCode]);
}
```

---

## 8. Implementation Gap Summary

### Status Legend:
- ✅ **CURRENT** = Implemented and working
- 🚧 **PARTIAL** = Infrastructure exists, logic missing
- 📋 **TARGET** = Planned but not implemented

### Database Schema

| Item | Status | Description |
|------|--------|-------------|
| `flow_token.token_type` enum | ✅ CURRENT | ('batch','piece','component') |
| `flow_token.parent_token_id` | ✅ CURRENT | FK to parent token |
| `flow_token.parallel_group_id` | ✅ CURRENT | Parallel group ID |
| `flow_token.parallel_branch_key` | ✅ CURRENT | Branch key (A, B, C) |
| `routing_node.is_parallel_split` | ✅ CURRENT | Parallel split flag |
| `routing_node.is_merge_node` | ✅ CURRENT | Merge node flag |
| `routing_node.merge_mode` | ✅ CURRENT | Merge policy (ALL, ANY) |
| `routing_node.produces_component` | 📋 TARGET | Component code mapping |
| `routing_node.consumes_components` | 📋 TARGET | Required components JSON |
| `flow_token.component_code` | 📋 TARGET | Component identifier field |
| `product_component` table | 📋 TARGET | Component master data (Task 5) |
| `job_tray` table | 📋 TARGET | Physical tray mapping |

### Token Lifecycle

| Feature | Status | Description |
|---------|--------|-------------|
| Spawn Final Token | ✅ CURRENT | Job creation spawns final tokens |
| Parallel Split Logic | 📋 TARGET | splitToken() / createComponentToken() |
| Component Token Creation | 📋 TARGET | Spawn components from split node |
| Component-to-Node Mapping | 📋 TARGET | Map component to target node |
| Merge Validation | 📋 TARGET | Check all components complete |
| Final Token Re-activation | 📋 TARGET | Re-activate at merge node |
| Component Data Aggregation | 📋 TARGET | Aggregate times/QC into final |

### Behavior Execution

| Feature | Status | Description |
|---------|--------|-------------|
| Behavior Handlers | ✅ CURRENT | handleStitch, handleCut, handleQc, etc. |
| Token Type Validation | 🚧 PARTIAL | No token_type-specific validation yet |
| Component Token Support | 🚧 PARTIAL | Time tracking works, routing works, but no component-specific rules |
| Behavior-Component Matrix | 📋 TARGET | behaviorSupportsTokenType() validation |

### Work Queue

| Feature | Status | Description |
|---------|--------|-------------|
| List All Tokens | ✅ CURRENT | Show all tokens in queue |
| Filter by Role | 📋 TARGET | Component worker vs Assembly worker view |
| Component Token Display | 📋 TARGET | Show component_code + final_serial |
| Assembly View | 📋 TARGET | Show components completion status |

### Time Tracking

| Feature | Status | Description |
|---------|--------|-------------|
| TokenWorkSessionService | ✅ CURRENT | Supports all token types |
| Component Time Tracking | ✅ CURRENT | Works with component tokens |
| Time Aggregation | 📋 TARGET | Aggregate component times to final |
| ETA Calculation | 📋 TARGET | max(component_times) + assembly |

---

## 9. Migration Path (From Current to Target)

**Priority 1 (BLOCKERS - Required for Component Flow):**

1. **Add `routing_node.produces_component` field**
   ```sql
   ALTER TABLE routing_node 
   ADD COLUMN produces_component VARCHAR(50) NULL 
   COMMENT 'Component code this node produces/works with';
   ```

2. **Add `routing_node.consumes_components` field**
   ```sql
   ALTER TABLE routing_node 
   ADD COLUMN consumes_components JSON NULL 
   COMMENT 'Array of component codes required for merge node';
   ```

3. **Implement `splitToken()` logic in TokenLifecycleService**
   - Spawn component tokens from parallel split node
   - Set parent_token_id, parallel_group_id, component_code

4. **Implement merge validation**
   - Check all required components complete
   - Re-activate final token

5. **Implement component data aggregation**
   - Aggregate component times, QC status, worker info
   - Store in final token metadata

**Priority 2 (Required for Production):**

6. **Work Queue Role-Based Filtering**
   - Component worker view
   - Assembly worker view

7. **Behavior-Component Matrix Validation**
   - `behaviorSupportsTokenType($behaviorCode, $tokenType)`
   - Return error if unsupported combination

8. **Component-to-Node Mapping UI**
   - Graph Designer: set produces_component for nodes
   - Validation: merge node has consumes_components

**Priority 3 (Long Term - Task 5):**

9. **Implement `product_component` table**
   - Component master data
   - BOM integration

10. **Add `flow_token.component_code` field**
    - Move from metadata JSON to dedicated field

11. **Implement `job_tray` table**
    - Physical tray mapping
    - QR code generation

---

## 10. Anti-Patterns (DO NOT DO)

**1. ❌ DO NOT Create Component Token Without `parent_token_id`**
```sql
-- WRONG
INSERT INTO flow_token (token_type, serial_number) 
VALUES ('component', 'C-BODY-001');

-- RIGHT
INSERT INTO flow_token (token_type, parent_token_id, metadata) 
VALUES ('component', 100, '{"component_code": "BODY"}');
```

**2. ❌ DO NOT Generate Final Serial at Assembly**
```php
// WRONG - Final serial should exist before assembly
function handleAssembly($componentTokens) {
    $finalSerial = generateFinalSerial(); // ❌
    createFinalToken(['serial_number' => $finalSerial]);
}

// RIGHT - Final serial already exists from job creation
function handleAssembly($componentTokens) {
    $finalTokenId = $componentTokens[0]['parent_token_id'];
    reActivateFinalToken($finalTokenId); // ✅
}
```

**3. ❌ DO NOT Mix Components Between Trays (Physical Reality)**
```php
// WRONG - Components of F001 mixed with F002
function pickComponents() {
    $components = [
        ['final_serial' => 'F001', 'component' => 'BODY'],
        ['final_serial' => 'F002', 'component' => 'BODY'] // ❌ Mixed in same tray
    ];
}

// RIGHT - Each final token has its own tray
function pickComponents($trayCode) {
    $finalSerial = getTrayOwner($trayCode); // F001
    $components = getComponentsInTray($finalSerial); // All F001 components only
}
```

**4. ❌ DO NOT Use Serial Pattern Matching for Relationships**
```php
// WRONG - Pattern matching is fragile
function findComponentsByPattern($finalSerial) {
    return db_query("
        SELECT * FROM flow_token 
        WHERE serial_number LIKE ?
    ", [$finalSerial . '-%']);
}

// RIGHT - Use token graph
function findComponentsByTokenGraph($finalTokenId) {
    return db_query("
        SELECT * FROM flow_token 
        WHERE parent_token_id = ? 
          AND token_type = 'component'
    ", [$finalTokenId]);
}
```

**5. ❌ DO NOT Show Component Tokens to Assembly Worker**
```javascript
// WRONG - Assembly worker sees components (confusing)
function loadWorkQueue(workerId) {
    return getAllTokens(); // ❌ Returns components + final tokens mixed
}

// RIGHT - Filter by role
function loadWorkQueue(workerId, role) {
    if (role === 'assembly_worker') {
        return getTokens("token_type = 'piece' AND current_node_id IN (SELECT id_node FROM routing_node WHERE is_merge_node = 1)");
    } else {
        return getTokens("token_type = 'component' AND current_node_id IN (...)");
    }
}
```

**6. ❌ DO NOT Use Subgraph `fork` Mode for Component Parallel Work**
```sql
-- WRONG - Using subgraph for component split
routing_node:
  node_type: 'subgraph'
  subgraph_mode: 'fork' -- ❌

-- RIGHT - Using native parallel split
routing_node:
  is_parallel_split: 1 -- ✅
  produces_component: NULL
```

---

## 11. Routing Node Truth Table

**Purpose:** กำหนด combination ที่ถูกต้องของ node flags เพื่อป้องกัน invalid graph configuration

### 11.1 Node Type + Flags Combinations

| node_type | is_parallel_split | is_merge_node | behavior_code | Valid? | Description |
|-----------|-------------------|---------------|---------------|--------|-------------|
| `normal` | 0 | 0 | STITCH | ✅ Yes | Normal behavior node |
| `normal` | 0 | 0 | NULL | ✅ Yes | Passthrough node (no behavior) |
| `normal` | 1 | 0 | NULL | ✅ Yes | Parallel split node (topology only) |
| `normal` | 0 | 1 | NULL | ✅ Yes | Merge node (topology only) |
| `normal` | 1 | 1 | NULL | ❌ No | Cannot be both split and merge |
| `normal` | 1 | 0 | STITCH | ❌ No | Split node cannot have behavior |
| `normal` | 0 | 1 | ASSEMBLY | ❌ No | Merge node cannot have behavior |
| `subgraph` | 0 | 0 | NULL | ✅ Yes | Subgraph reference node |
| `subgraph` | 1 | 0 | NULL | ❌ No | Subgraph cannot be parallel split |
| `subgraph` | 0 | 1 | NULL | ❌ No | Subgraph cannot be merge node |
| `start` | * | * | NULL | ✅ Yes | Start node (flags ignored) |
| `end` | * | * | NULL | ✅ Yes | End node (flags ignored) |
| `decision` | 0 | 0 | NULL | ✅ Yes | Decision node (conditional routing) |

### 11.2 Validation Rules

**Rule 1: Exclusive Flags**
```sql
-- A node cannot be both split and merge
WHERE is_parallel_split = 1 AND is_merge_node = 1  -- INVALID
```

**Rule 2: Split/Merge Cannot Have Behavior**
```sql
-- Split/Merge nodes are topology nodes (no behavior execution)
WHERE (is_parallel_split = 1 OR is_merge_node = 1) AND behavior_code IS NOT NULL  -- INVALID
```

**Rule 3: Split Node Must Have 2+ Outgoing Edges**
```sql
-- Split node validation
SELECT rn.id_node, COUNT(re.id_edge) AS outgoing_count
FROM routing_node rn
LEFT JOIN routing_edge re ON re.from_node_id = rn.id_node
WHERE rn.is_parallel_split = 1
GROUP BY rn.id_node
HAVING outgoing_count < 2;  -- INVALID if < 2
```

**Rule 4: Merge Node Must Have 2+ Incoming Edges**
```sql
-- Merge node validation
SELECT rn.id_node, COUNT(re.id_edge) AS incoming_count
FROM routing_node rn
LEFT JOIN routing_edge re ON re.to_node_id = rn.id_node
WHERE rn.is_merge_node = 1
GROUP BY rn.id_node
HAVING incoming_count < 2;  -- INVALID if < 2
```

**Rule 5: Subgraph Node Type Cannot Have Split/Merge Flags**
```sql
-- Subgraph node validation
WHERE node_type = 'subgraph' AND (is_parallel_split = 1 OR is_merge_node = 1)  -- INVALID
```

### 11.3 Implementation (Graph Designer Validation)

```php
function validateNodeConfiguration($node) {
    $errors = [];
    
    // Rule 1: Exclusive flags
    if ($node['is_parallel_split'] && $node['is_merge_node']) {
        $errors[] = 'Node cannot be both parallel_split and merge_node';
    }
    
    // Rule 2: Split/Merge cannot have behavior
    if (($node['is_parallel_split'] || $node['is_merge_node']) && $node['behavior_code']) {
        $errors[] = 'Split/Merge node cannot have behavior_code';
    }
    
    // Rule 3: Split node edge count
    if ($node['is_parallel_split']) {
        $outgoingCount = countOutgoingEdges($node['id_node']);
        if ($outgoingCount < 2) {
            $errors[] = 'Parallel split node must have at least 2 outgoing edges';
        }
    }
    
    // Rule 4: Merge node edge count
    if ($node['is_merge_node']) {
        $incomingCount = countIncomingEdges($node['id_node']);
        if ($incomingCount < 2) {
            $errors[] = 'Merge node must have at least 2 incoming edges';
        }
    }
    
    // Rule 5: Subgraph type
    if ($node['node_type'] === 'subgraph' && ($node['is_parallel_split'] || $node['is_merge_node'])) {
        $errors[] = 'Subgraph node cannot have split/merge flags';
    }
    
    return [
        'valid' => empty($errors),
        'errors' => $errors
    ];
}
```

---

## 12. Component Split Graph Requirements (Contract for Graph Designer)

**Purpose:** กำหนด requirements ที่ Graph Designer ต้องทำให้ถูกต้องเพื่อให้ Component Parallel Flow ทำงานได้

### 12.1 Split Node Requirements

**Split Node MUST:**

1. ✅ **มี `is_parallel_split = 1`**
   ```sql
   routing_node.is_parallel_split = 1
   ```

2. ✅ **มีอย่างน้อย 2 outgoing edges**
   - ถ้ามี 1 edge → ไม่ใช่ parallel split (ใช้ normal node แทน)
   - แต่ละ edge = branch หนึ่ง

3. ✅ **ไม่มี `behavior_code`** (topology node เท่านั้น)
   ```sql
   routing_node.behavior_code IS NULL
   ```

4. ✅ **All target nodes มี `produces_component`** (TARGET - ยังไม่ implement)
   ```sql
   -- Target nodes (from outgoing edges)
   SELECT rn.*
   FROM routing_edge re
   JOIN routing_node rn ON rn.id_node = re.to_node_id
   WHERE re.from_node_id = <split_node_id>
     AND rn.produces_component IS NOT NULL;  -- ต้องมีทุก node
   ```

5. ✅ **Target nodes มี `produces_component` ไม่ซ้ำกัน**
   ```sql
   -- Check for duplicates
   SELECT produces_component, COUNT(*) AS cnt
   FROM routing_node rn
   JOIN routing_edge re ON re.to_node_id = rn.id_node
   WHERE re.from_node_id = <split_node_id>
   GROUP BY produces_component
   HAVING cnt > 1;  -- INVALID if any duplicates
   ```

**Example Valid Split:**
```
Split Node (id=10)
  ├─ Edge → STITCH_BODY (id=11, produces_component='BODY')
  ├─ Edge → STITCH_FLAP (id=12, produces_component='FLAP')
  └─ Edge → STITCH_STRAP (id=13, produces_component='STRAP')
```

**Example Invalid Split:**
```
❌ Split Node → only 1 outgoing edge (not parallel)
❌ Split Node → target node has no produces_component
❌ Split Node → two targets both produce 'BODY' (duplicate)
❌ Split Node → has behavior_code='CUT' (cannot execute behavior)
```

### 12.2 Target Node Requirements

**Target Nodes MUST:**

1. ✅ **มี `produces_component` field** (TARGET)
   ```sql
   routing_node.produces_component IN ('BODY', 'FLAP', 'STRAP', ...)
   ```

2. ✅ **เป็น node ประเภทที่เริ่มทำงาน component ได้ทันที**
   - ✅ Behavior node (STITCH, EDGE, etc.)
   - ✅ Normal passthrough node
   - ❌ Merge node (ห้ามใช้เป็น target ของ split)
   - ❌ Another split node (nested split ต้องทำผ่าน intermediate nodes)

3. ✅ **Behavior รองรับ component token** (ถ้ามี behavior)
   - ดู Section 3.2: Behavior Support Matrix
   - Example: STITCH ✅, EDGE ✅, ASSEMBLY ❌

**Example Valid Target:**
```sql
routing_node:
  id_node: 11
  node_code: 'STITCH_BODY'
  node_type: 'normal'
  behavior_code: 'STITCH'  -- Supports component token
  produces_component: 'BODY'
  is_parallel_split: 0
  is_merge_node: 0
```

**Example Invalid Target:**
```
❌ Target = merge node (ห้ามใช้)
❌ Target = split node (ต้องมี intermediate node ก่อน)
❌ Target behavior='PACK' (ไม่รองรับ component token ตาม factory model)
```

### 12.3 Merge Node Requirements

**Merge Node MUST:**

1. ✅ **มี `is_merge_node = 1`**
   ```sql
   routing_node.is_merge_node = 1
   ```

2. ✅ **มี `consumes_components` JSON array** (TARGET)
   ```sql
   routing_node.consumes_components = '["BODY","FLAP","STRAP"]'
   ```

3. ✅ **`consumes_components` ต้องตรงกับชุดของ `produces_component` จาก split**
   ```php
   // Validation
   $splitTargets = getProducesComponentsFromSplit($splitNodeId);  // ['BODY', 'FLAP', 'STRAP']
   $mergeConsumes = json_decode($mergeNode['consumes_components'], true);  // ['BODY', 'FLAP', 'STRAP']
   
   sort($splitTargets);
   sort($mergeConsumes);
   
   if ($splitTargets !== $mergeConsumes) {
       return ['valid' => false, 'error' => 'Merge consumes_components mismatch with split produces'];
   }
   ```

4. ✅ **มี incoming edges = จำนวน components**
   ```sql
   SELECT COUNT(*) AS incoming_count
   FROM routing_edge
   WHERE to_node_id = <merge_node_id>;
   
   -- incoming_count must = count(consumes_components)
   ```

5. ✅ **ไม่มี `behavior_code`** (topology node เท่านั้น)
   ```sql
   routing_node.behavior_code IS NULL
   ```

**Example Valid Merge:**
```
Merge Node (id=20)
  - is_merge_node: 1
  - merge_mode: 'ALL'
  - consumes_components: '["BODY","FLAP","STRAP"]'
  - Incoming edges: 3 (from BODY, FLAP, STRAP branches)
```

**Example Invalid Merge:**
```
❌ consumes_components=['BODY','FLAP'] but split produced ['BODY','FLAP','STRAP'] (mismatch)
❌ incoming edges=2 but consumes_components=['BODY','FLAP','STRAP'] (count mismatch)
❌ has behavior_code='ASSEMBLY' (cannot execute behavior)
```

### 12.4 Graph Designer UI Validation

**On Save Graph:**
```php
function validateComponentSplitGraph($graphId) {
    $errors = [];
    
    // Find all split nodes
    $splitNodes = db_query("
        SELECT * FROM routing_node 
        WHERE id_graph = ? AND is_parallel_split = 1
    ", [$graphId]);
    
    foreach ($splitNodes as $split) {
        // Check outgoing edges
        $targets = getTargetNodes($split['id_node']);
        
        if (count($targets) < 2) {
            $errors[] = "Split node {$split['node_code']} has < 2 outgoing edges";
        }
        
        // Check produces_component (TARGET validation)
        $components = array_column($targets, 'produces_component');
        $components = array_filter($components); // Remove nulls
        
        if (count($components) !== count($targets)) {
            $errors[] = "Split node {$split['node_code']} target nodes missing produces_component";
        }
        
        if (count($components) !== count(array_unique($components))) {
            $errors[] = "Split node {$split['node_code']} has duplicate produces_component";
        }
        
        // Find corresponding merge node
        $mergeNode = findMergeNodeForSplit($split['id_node']);
        
        if (!$mergeNode) {
            $errors[] = "Split node {$split['node_code']} has no corresponding merge node";
        } else {
            // Validate merge consumes_components
            $mergeConsumes = json_decode($mergeNode['consumes_components'], true);
            
            sort($components);
            sort($mergeConsumes);
            
            if ($components !== $mergeConsumes) {
                $errors[] = "Merge node {$mergeNode['node_code']} consumes_components mismatch";
            }
        }
    }
    
    return [
        'valid' => empty($errors),
        'errors' => $errors
    ];
}
```

---

## 13. Failure Modes & Recovery

**Purpose:** กำหนดวิธีจัดการ human error และ exceptional cases ใน Component Flow

### 13.1 Component Token Scrapped (QC Fail / Damage)

**Scenario:** Component token ทำเสีย (QC fail, damaged, lost)

**Current Behavior:**
- Component token → `status = 'scrapped'`
- Merge node → รอ component ที่เสียไม่ได้ → blocked

**Recovery (TARGET):**

**Option 1: Spawn Replacement Component Token**
```php
function spawnReplacementComponent($scrappedTokenId) {
    $scrapped = getToken($scrappedTokenId);
    $componentCode = $scrapped['metadata']->component_code;
    $parentTokenId = $scrapped['parent_token_id'];
    $parallelGroupId = $scrapped['parallel_group_id'];
    
    // Spawn new component token
    $newTokenId = createToken([
        'token_type' => 'component',
        'parent_token_id' => $parentTokenId,
        'parallel_group_id' => $parallelGroupId,
        'parallel_branch_key' => $scrapped['parallel_branch_key'],
        'metadata' => ['component_code' => $componentCode],
        'status' => 'ready',
        'current_node_id' => getReplacementStartNode($componentCode),  // ตามกำหนด
        'parent_scrapped_token_id' => $scrappedTokenId
    ]);
    
    // Link back to scrapped
    updateToken($scrappedTokenId, ['replacement_token_id' => $newTokenId]);
    
    return $newTokenId;
}
```

**Option 2: Supervisor Override (Cancel Final Token)**
```php
function cancelFinalTokenDueToComponentFailure($finalTokenId, $reason) {
    // Cancel final token
    updateToken($finalTokenId, [
        'status' => 'scrapped',
        'metadata' => JSON_SET(metadata, '$.cancellation_reason', $reason)
    ]);
    
    // Cancel all component tokens
    db_query("
        UPDATE flow_token 
        SET status = 'scrapped', 
            metadata = JSON_SET(metadata, '$.cancelled_by_parent', 1)
        WHERE parent_token_id = ?
    ", [$finalTokenId]);
}
```

### 13.2 Component Token Completed But Assembly Rejects

**Scenario:** Component token `status = 'completed'` แต่ assembly worker บอกว่าต้องแก้ใหม่

**Recovery (TARGET):**

**Option 1: Reopen Component Token**
```php
function reopenComponentToken($componentTokenId, $targetNodeId, $reason) {
    // Spawn new token (ไม่ revert status - immutable principle)
    $original = getToken($componentTokenId);
    
    $reworkTokenId = createToken([
        'token_type' => 'component',
        'parent_token_id' => $original['parent_token_id'],
        'parallel_group_id' => $original['parallel_group_id'],
        'parallel_branch_key' => $original['parallel_branch_key'],
        'metadata' => array_merge($original['metadata'], [
            'rework_from' => $componentTokenId,
            'rework_reason' => $reason
        ]),
        'status' => 'ready',
        'current_node_id' => $targetNodeId  // Node ที่ต้องแก้ใหม่
    ]);
    
    // Mark original as rework
    updateToken($componentTokenId, [
        'metadata' => JSON_SET(metadata, '$.reworked_by_token', $reworkTokenId)
    ]);
    
    return $reworkTokenId;
}
```

### 13.3 Component Token in Wrong Tray

**Scenario:** ช่างทำ component ของ F001 แต่ใส่ลงถาดของ F002 ผิด

**Detection (TARGET):**
```php
function validateComponentTrayAssignment($componentTokenId, $scanTrayCode) {
    $component = getToken($componentTokenId);
    $finalToken = getToken($component['parent_token_id']);
    $correctTray = getTrayByFinalToken($finalToken['id_token']);
    
    if ($correctTray['tray_code'] !== $scanTrayCode) {
        return [
            'valid' => false,
            'error' => 'WRONG_TRAY',
            'message' => "Component ของ {$finalToken['serial_number']} ต้องอยู่ในถาด {$correctTray['tray_code']}",
            'correct_tray' => $correctTray['tray_code'],
            'scanned_tray' => $scanTrayCode
        ];
    }
    
    return ['valid' => true];
}
```

**Recovery:**
- Block operation จนกว่าจะใส่ถาดถูก
- หรือ Supervisor override (log violation)

### 13.4 Partial Component Completion

**Scenario:** Split ไป 3 components แต่ช่างทำแค่ 2 component (ลืมทำ 1 ชิ้น)

**Behavior:**
- Merge node validation fails (missing component)
- Final token ยัง `status = 'waiting'` (ไม่ re-activate)

**Recovery (TARGET):**

**Option 1: Wait (Block Merge)**
```php
function validateMergeReadiness($finalTokenId, $mergeNodeId) {
    $node = getNode($mergeNodeId);
    $requiredComponents = json_decode($node['consumes_components'], true);
    
    $completedComponents = db_query("
        SELECT metadata->>'$.component_code' AS component_code
        FROM flow_token
        WHERE parent_token_id = ?
          AND token_type = 'component'
          AND status = 'completed'
    ", [$finalTokenId]);
    
    $completedCodes = array_column($completedComponents, 'component_code');
    $missing = array_diff($requiredComponents, $completedCodes);
    
    if (!empty($missing)) {
        return [
            'ready' => false,
            'missing' => $missing,
            'message' => 'ยังไม่ครบทุก component: ' . implode(', ', $missing)
        ];
    }
    
    return ['ready' => true];
}
```

**Option 2: Supervisor Override (Partial Merge)**
```php
function supervisorOverrideMerge($finalTokenId, $reason) {
    // Allow merge even if incomplete
    // Log violation
    db_query("INSERT INTO dag_supervisor_override (id_token, override_type, reason, operator_id) VALUES (?, 'partial_merge', ?, ?)", 
        [$finalTokenId, $reason, $supervisorId]);
    
    // Re-activate final token
    updateToken($finalTokenId, [
        'status' => 'active',
        'current_node_id' => $mergeNodeId,
        'metadata' => JSON_SET(metadata, '$.partial_merge', 1)
    ]);
}
```

### 13.5 Final Token Cancelled → Cascade to Components

**Scenario:** Final token cancelled (customer cancel order, design change)

**Behavior:**
- Final token → `status = 'scrapped'`
- All component tokens → must also be cancelled

**Implementation (TARGET):**
```php
function cascadeCancelFinalToken($finalTokenId, $reason) {
    // Cancel final token
    updateToken($finalTokenId, [
        'status' => 'scrapped',
        'metadata' => JSON_SET(metadata, '$.cancellation_reason', $reason)
    ]);
    
    // Cancel all component tokens
    db_query("
        UPDATE flow_token 
        SET status = 'scrapped',
            scrapped_at = NOW(),
            metadata = JSON_SET(metadata, '$.cancelled_by_parent', 1, '$.parent_cancellation_reason', ?)
        WHERE parent_token_id = ?
          AND status NOT IN ('completed', 'scrapped')
    ", [$reason, $finalTokenId]);
    
    // Emit canonical events
    $components = getComponentTokens($finalTokenId);
    foreach ($components as $comp) {
        emitEvent('NODE_CANCEL', [
            'token_id' => $comp['id_token'],
            'reason' => 'parent_cancelled'
        ]);
    }
}
```

### 13.6 Worker Completes Wrong Component

**Scenario:** Worker กด complete บน component token ผิดชิ้น (เช่น กดของ F002 แทนที่จะเป็น F001)

**Prevention (UI Validation):**
```javascript
// Work Queue UI
function confirmComplete(tokenId) {
    const token = getTokenInfo(tokenId);
    
    Swal.fire({
        title: 'ยืนยันการทำเสร็จ',
        html: `
            <p>Component: <strong>${token.component_code}</strong></p>
            <p>Final Serial: <strong>${token.final_serial}</strong></p>
            <p>ถาดงาน: <strong>${token.tray_code}</strong></p>
        `,
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'ยืนยัน',
        cancelButtonText: 'ยกเลิก'
    }).then((result) => {
        if (result.isConfirmed) {
            completeToken(tokenId);
        }
    });
}
```

**Recovery:**
- ถ้าเกิดผิดแล้ว → Supervisor reopen token (spawn replacement)
- Log error for training

### 13.7 Split Node Error (System Failure During Split)

**Scenario:** ระบบ crash ระหว่าง spawn component tokens (spawn ไป 2/3 แล้วตาย)

**Detection:**
```php
function detectOrphanedSplits() {
    // Find final tokens in 'waiting' status with incomplete component set
    $orphaned = db_query("
        SELECT 
            ft.id_token AS final_token_id,
            ft.serial_number,
            ft.parallel_group_id,
            COUNT(comp.id_token) AS component_count,
            ft.metadata->>'$.expected_components' AS expected_count
        FROM flow_token ft
        LEFT JOIN flow_token comp ON comp.parent_token_id = ft.id_token AND comp.token_type = 'component'
        WHERE ft.status = 'waiting'
          AND ft.token_type = 'piece'
        GROUP BY ft.id_token
        HAVING component_count < expected_count
    ");
    
    return $orphaned;
}
```

**Recovery:**
```php
function repairOrphanedSplit($finalTokenId) {
    // Get split node info
    $finalToken = getToken($finalTokenId);
    $expectedComponents = $finalToken['metadata']->expected_components;
    $existingComponents = getComponentTokens($finalTokenId);
    
    $existingCodes = array_column($existingComponents, 'component_code');
    $missing = array_diff($expectedComponents, $existingCodes);
    
    // Spawn missing components
    foreach ($missing as $componentCode) {
        $targetNode = getNodeByProducesComponent($componentCode);
        
        createToken([
            'token_type' => 'component',
            'parent_token_id' => $finalTokenId,
            'parallel_group_id' => $finalToken['parallel_group_id'],
            'metadata' => ['component_code' => $componentCode, 'recovered' => true],
            'status' => 'ready',
            'current_node_id' => $targetNode['id_node']
        ]);
    }
}
```

---

## 14. References

**Core Architecture:**
- `docs/dag/03-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - Token lifecycle model (NEW)

**Concept Documents:**
- `docs/dag/02-concepts/COMPONENT_PARALLEL_FLOW.md` - High-level concept flow

**Audit Reports:**
- `docs/dag/00-audit/20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md` - Current status audit
- `docs/dag/00-audit/20251202_SUBGRAPH_VS_COMPONENT_AUDIT_REPORT.md` - Subgraph vs Component comparison

**Implementation Checklists:**
- (TODO: Create implementation checklist for Component Flow - Priority 1-3 items)

**Related Specs:**
- SuperDAG Core Merge Spec (TODO) - Merge engine semantics
- `docs/developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md` - Behavior execution contracts

---

## 15. Version History

**v2.1 (2025-12-02):**
- ✅ Added Section 11: Routing Node Truth Table (node type + flags validation)
- ✅ Added Section 12: Component Split Graph Requirements (contract for Graph Designer)
- ✅ Added Section 13: Failure Modes & Recovery (7 scenarios)
- ✅ Added reference to SUPERDAG_TOKEN_LIFECYCLE.md (core lifecycle model)
- ✅ Production-ready spec (3-5 year lifespan)

**v2.0 (2025-12-02):**
- ✅ Complete rewrite based on actual codebase (100% verified)
- ✅ Added Section 0: Terminology (Token Types)
- ✅ Clarified Final Token vs Component Token vs Batch Token
- ✅ Added "Current vs Target" status for all features
- ✅ Behavior Matrix marked as "Bellavier Hatthasilpa Factory Model"
- ✅ Reduced Merge Semantics (reference SuperDAG Core Spec)
- ✅ Added Section 6.1: Work Queue View by Role
- ✅ Separated Spec from Task/Status (moved to Gap Summary)
- ✅ Consistent version (2.0 throughout)
- ✅ Updated all references to use correct paths
- ✅ Emphasized "Component Serial = Label Only" in Section 0 and Section 7

**v1.0 (2025-12-XX):**
- Initial specification

---

**END OF SPEC**
