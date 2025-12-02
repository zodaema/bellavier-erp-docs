# SuperDAG Token Lifecycle Model

**Status:** Core Architecture Specification  
**Date:** 2025-12-02  
**Version:** 1.0  
**Category:** SuperDAG / Token Engine / Core Lifecycle

**Purpose:** นิยาม lifecycle ของ token ทุกประเภทใน SuperDAG universe  
**Scope:** ใช้เป็นมาตรฐานกลางสำหรับ Component Flow, Batch Flow, Subgraph Flow, และ future extensions

---

## 0. Token Universe Overview

**SuperDAG Token = Work unit ที่เดินผ่าน routing graph**

**Token Types (Current):**
- `'batch'` - กลุ่มชิ้นงานที่ process พร้อมกัน (e.g., cutting batch)
- `'piece'` - ชิ้นงานเดี่ยว / final product (e.g., กระเป๋า 1 ใบ)
- `'component'` - ชิ้นส่วนย่อยของ piece (e.g., BODY, FLAP, STRAP)

**Token Types (Future):**
- `'tray'` - ถาดงาน (physical container tracking)
- `'work_order'` - ใบสั่งงานระดับ production order
- `'sub_component'` - ชิ้นส่วนย่อยลึกกว่า 1 ชั้น (e.g., Pocket → Body → Bag)

---

## 1. Token Lifecycle States

### 1.1 State Enum

**Database:** `flow_token.status` ENUM

```sql
status ENUM(
    'ready',      -- พร้อมเริ่มงาน (ยังไม่ start)
    'active',     -- กำลังทำงาน (work session active)
    'waiting',    -- รอ merge / รอ dependencies
    'paused',     -- หยุดชั่วคราว (worker pause)
    'completed',  -- เสร็จสิ้น (reached end node or merged)
    'scrapped'    -- ยกเลิก / ทิ้ง
) NOT NULL DEFAULT 'ready'
```

### 1.2 State Transition Diagram

```
                    ┌─────────────┐
                    │   CREATE    │
                    │  (spawned)  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
           ┌────────│    ready    │◄────────┐
           │        └──────┬──────┘         │
           │               │                │
           │      ┌────────▼────────┐       │
           │      │     active      │───────┘
           │      └────┬───────┬────┘   (resume)
           │           │       │
           │      (pause)   (complete node)
           │           │       │
           │      ┌────▼───┐   │
           │      │ paused │   │
           │      └────┬───┘   │
           │           │       │
           │      (resume)     │
           │           │       │
           │      ┌────▼───────▼────┐
           │      │    waiting      │ (ถ้าเป็น split node)
           │      └─────────┬───────┘
           │                │
           │           (merge complete)
           │                │
           │      ┌─────────▼─────────┐
           └─────►│    completed      │
    (scrap)       └───────────────────┘
                           │
                    ┌──────▼──────┐
                    │   archived  │ (future)
                    └─────────────┘
```

### 1.3 State Descriptions

| State | Description | When | Can Transition To |
|-------|-------------|------|-------------------|
| **ready** | Token พร้อมเริ่มงาน, ยังไม่มี worker claim | Token spawn, worker release | active |
| **active** | Worker กำลังทำงาน (work session active) | Worker start | paused, waiting, completed, scrapped |
| **waiting** | รอ dependencies (เช่น รอ component tokens complete) | Split node, เข้า merge node | active, scrapped |
| **paused** | Worker หยุดชั่วคราว (พักเบรก, เข้า WC) | Worker pause | active, scrapped |
| **completed** | เสร็จสิ้น (ถึง end node หรือ merged) | Reach end node, merge complete | - (terminal state) |
| **scrapped** | ยกเลิก / ทิ้ง (QC fail, damaged, cancelled) | QC fail, manual cancel | - (terminal state) |

**⚠️ Terminal States:**
- `completed` และ `scrapped` = terminal states (ไม่สามารถเปลี่ยนสถานะต่อได้)
- ถ้าต้องการ "reopen" → spawn token ใหม่ (ไม่ revert state)

---

## 2. Token Relationships

### 2.1 Relationship Types

**1. Parent-Child (Hierarchical)**
```
Final Token (piece)
  ├─ Component Token (component) - BODY
  ├─ Component Token (component) - FLAP
  └─ Component Token (component) - STRAP
```

**Database:**
- `parent_token_id` INT - FK to parent token
- Direction: Child → Parent (component token points to piece token)

**2. Parallel Group (Sibling)**
```
Parallel Split Node
  ├─ Component Token 1 (parallel_group_id=5, branch_key='1')
  ├─ Component Token 2 (parallel_group_id=5, branch_key='2')
  └─ Component Token 3 (parallel_group_id=5, branch_key='3')
```

**Database:**
- `parallel_group_id` INT - Group identifier
- `parallel_branch_key` VARCHAR(50) - Branch identifier within group

**3. Replacement (Recovery)**
```
Original Token (scrapped) ──replacement_token_id──> New Token (active)
```

**Database:**
- `replacement_token_id` INT - FK to replacement token
- `parent_scrapped_token_id` INT - FK to scrapped token (reverse reference)

**4. Batch Spawn (Future)**
```
Batch Token (batch)
  ├─ Piece Token 1
  ├─ Piece Token 2
  └─ Piece Token N
```

**Database:**
- `child_tokens` JSON - Array of spawned token IDs

### 2.2 Relationship Rules

**Rule 1: Single Parent**
- Token สามารถมี `parent_token_id` ได้แค่ 1 token (no multiple parents)

**Rule 2: Component Must Have Parent**
- ถ้า `token_type = 'component'` → `parent_token_id` IS NOT NULL (mandatory)

**Rule 3: Parallel Group Membership**
- ถ้าอยู่ใน parallel group → `parallel_group_id` IS NOT NULL
- Siblings in same group มี `parallel_group_id` เดียวกัน

**Rule 4: Acyclic Relationship**
- Token graph ต้องเป็น DAG (Directed Acyclic Graph)
- ห้าม circular reference: Token A → Token B → Token A

---

## 3. Token Spawn Patterns

### 3.1 Job Creation Spawn (Final Tokens)

**When:** สร้าง Hatthasilpa Job

**Input:** 
- Job Code
- Product ID
- Target Qty (e.g., 5 bags)

**Output:**
- Spawn N final tokens (piece)
- Each token gets `serial_number` immediately
- Status: `ready`
- `parent_token_id`: NULL

**Example:**
```php
createHatthasilpaJob([
    'job_code' => 'JOB-2025-001',
    'product_id' => 123,
    'target_qty' => 5
]);

// Spawns:
// Token 1: serial='F001', token_type='piece', status='ready'
// Token 2: serial='F002', token_type='piece', status='ready'
// Token 3: serial='F003', token_type='piece', status='ready'
// Token 4: serial='F004', token_type='piece', status='ready'
// Token 5: serial='F005', token_type='piece', status='ready'
```

### 3.2 Parallel Split Spawn (Component Tokens)

**When:** Token reaches `is_parallel_split = 1` node

**Input:**
- Parent token (piece)
- Split node
- Outgoing edges (each with target node)

**Output:**
- Spawn M component tokens (ตามจำนวน outgoing edges)
- Each token:
  - `token_type = 'component'`
  - `parent_token_id = parent_token.id_token`
  - `parallel_group_id = <new_group_id>`
  - `parallel_branch_key = '1', '2', '3', ...`
  - `metadata->>'$.component_code' = <target_node.produces_component>`
  - `status = 'ready'`
  - `current_node_id = <target_node.id_node>`
- Parent token: `status = 'waiting'`

**Example:**
```php
// Token F001 reaches PARALLEL_SPLIT node with 3 outgoing edges:
// Edge 1 → STITCH_BODY (produces_component='BODY')
// Edge 2 → STITCH_FLAP (produces_component='FLAP')
// Edge 3 → STITCH_STRAP (produces_component='STRAP')

handleParallelSplit($tokenF001);

// Spawns:
// Token 201: token_type='component', parent=F001, parallel_group=5, branch='1', component='BODY'
// Token 202: token_type='component', parent=F001, parallel_group=5, branch='2', component='FLAP'
// Token 203: token_type='component', parent=F001, parallel_group=5, branch='3', component='STRAP'

// Parent token:
// Token F001: status='waiting'
```

### 3.3 Batch Spawn (Future)

**When:** Cutting batch completes

**Input:**
- Batch token
- Cut quantity

**Output:**
- Spawn N piece tokens
- Each token:
  - `token_type = 'piece'`
  - `parent_token_id = batch_token.id_token`
  - `status = 'ready'`
- Batch token: `child_tokens = [piece_token_ids]`, `status = 'completed'`

### 3.4 Replacement Spawn (Recovery)

**When:** Token scrapped → need replacement

**Input:**
- Scrapped token
- Replacement reason

**Output:**
- Spawn new token (same type, same parent if applicable)
- New token:
  - `parent_scrapped_token_id = scrapped_token.id_token`
  - `status = 'ready'`
  - `current_node_id = <replacement_start_node>`
- Scrapped token:
  - `replacement_token_id = new_token.id_token`
  - `status = 'scrapped'` (unchanged)

---

## 4. Token Merge Patterns

### 4.1 Component Merge (Assembly)

**When:** All component tokens reach merge node

**Input:**
- Component tokens (all siblings in same parallel_group)
- Merge node (`is_merge_node = 1`)

**Validation:**
1. Check all required components arrived:
   ```sql
   SELECT component_code FROM flow_token 
   WHERE parallel_group_id = ? AND status = 'completed'
   ```
2. Compare with `merge_node.consumes_components`

**Output:**
- Re-activate parent token:
  ```sql
  UPDATE flow_token 
  SET status = 'active', current_node_id = <merge_node.id_node>
  WHERE id_token = <parent_token_id>
  ```
- Mark component tokens as merged:
  ```sql
  UPDATE flow_token 
  SET metadata = JSON_SET(metadata, '$.merged_at', NOW(), '$.merged_into_token_id', <parent_token_id>)
  WHERE id_token IN (<component_token_ids>)
  ```
- Aggregate component data:
  ```json
  // Parent token metadata
  {
    "component_times": {...},
    "max_component_time": 7200000,
    "merged_component_tokens": [201, 202, 203]
  }
  ```

### 4.2 Batch Join (Future)

**When:** Multiple batch tokens join to form lot

**Similar pattern to component merge, but:**
- Multiple batch tokens → new batch token (higher level)
- Original batch tokens: `status = 'completed'`

---

## 5. Token Lifecycle Events (Canonical Events)

### 5.1 Event Types

**Token Creation:**
- `TOKEN_CREATE` - Token spawned

**Token Split:**
- `TOKEN_SPLIT` - Parent token splits into children

**Token Merge:**
- `TOKEN_MERGE` - Children merge back to parent

**Node Execution:**
- `NODE_START` - Worker starts work on token at node
- `NODE_PAUSE` - Worker pauses work
- `NODE_RESUME` - Worker resumes work
- `NODE_COMPLETE` - Work completed at node

**Token Adjustment:**
- `TOKEN_ADJUST` - Manual adjustment (qty, metadata)
- `TOKEN_SHORTFALL` - Token falls short of requirements

**Token Cancellation:**
- `NODE_CANCEL` - Token cancelled/scrapped

**Routing Override:**
- `OVERRIDE_ROUTE` - Manual routing override

### 5.2 Event Persistence

**All canonical events → `token_event` table**

```sql
token_event (
  id_event INT PRIMARY KEY AUTO_INCREMENT,
  id_token INT NOT NULL,
  id_node INT NULL,
  event_type ENUM('spawn','enter','start','pause','resume','complete','move','split','join','qc_pass','qc_fail','rework','scrap'),
  event_data JSON NULL,
  event_time DATETIME NOT NULL,
  operator_id INT NULL,
  
  FOREIGN KEY (id_token) REFERENCES flow_token (id_token)
)
```

**Event data contains:**
- `canonical_type` - Canonical event name (e.g., TOKEN_SPLIT)
- `payload` - Event-specific data

---

## 6. Multi-Level Component Support (Future)

### 6.1 Nested Components

**Example:** 3-Level hierarchy
```
Final Token (Bag)
  ├─ Component Token (BODY)
  │    ├─ Sub-Component Token (POCKET_FRONT)
  │    └─ Sub-Component Token (POCKET_BACK)
  ├─ Component Token (FLAP)
  └─ Component Token (STRAP)
```

**Database Support:**
- `parent_token_id` already supports arbitrary depth
- No change to schema needed

**Lifecycle Support:**
- Component token can spawn sub-component tokens (another parallel split)
- Sub-components merge back to component
- Component completes → continue to final merge

**⚠️ Validation:**
- Depth limit: 3 levels (Final → Component → Sub-Component) recommended
- Beyond 3 levels → performance and complexity concerns

### 6.2 Dynamic Component Creation

**Scenario:** Worker discovers need for additional component during work

**Current:** Components defined at graph design time

**Future Enhancement:**
- Allow "ad-hoc component spawn" during execution
- Worker creates component token manually
- Component follows normal lifecycle
- Merge node validates "at least required components" (not exact match)

---

## 7. Token Archival & Retention (Future)

### 7.1 Archival Policy

**When to archive:**
- Token completed > 90 days
- Token scrapped > 30 days

**Archival process:**
- Move to `flow_token_archive` table
- Keep `token_event` records (immutable audit trail)
- Update references: parent_token_id, replacement_token_id → NULL or archive reference

### 7.2 Retention Policy

**Live tokens (flow_token):**
- Keep all active, waiting, paused tokens indefinitely
- Keep completed tokens for 90 days
- Keep scrapped tokens for 30 days

**Archived tokens (flow_token_archive):**
- Keep for 3 years (compliance requirement)
- After 3 years → export to data warehouse, delete from operational DB

---

## 8. Integration with Component Parallel Flow

**Component Parallel Flow Spec** (`COMPONENT_PARALLEL_FLOW_SPEC.md`) เป็น **concrete implementation** ของ lifecycle model นี้

**Lifecycle model นี้ = abstract framework**  
**Component Flow spec = concrete rules สำหรับ Hatthasilpa workflow**

**What this document defines:**
- Token types และ state machine (generic)
- Relationship patterns (generic)
- Spawn/merge patterns (generic)

**What Component Flow spec defines:**
- Component token-specific rules (Hatthasilpa-specific)
- Behavior support matrix (factory model)
- Node-to-component mapping (implementation details)

**Example:**
- Lifecycle model: "Token can spawn children" (generic)
- Component Flow spec: "Final token spawns BODY/FLAP/STRAP at PARALLEL_SPLIT node" (specific)

---

## 9. Anti-Patterns

**1. ❌ DO NOT Revert Terminal States**
```php
// WRONG
UPDATE flow_token SET status = 'active' WHERE id_token = ? AND status = 'completed';

// RIGHT
// Spawn replacement token instead
$newTokenId = spawnReplacementToken($completedTokenId);
```

**2. ❌ DO NOT Create Component Without Parent**
```sql
-- WRONG
INSERT INTO flow_token (token_type) VALUES ('component');

-- RIGHT
INSERT INTO flow_token (token_type, parent_token_id) VALUES ('component', 123);
```

**3. ❌ DO NOT Use Serial for Relationship**
```php
// WRONG
SELECT * FROM flow_token WHERE serial_number LIKE 'F001-%';

// RIGHT
SELECT * FROM flow_token WHERE parent_token_id = 123;
```

**4. ❌ DO NOT Skip State Transition**
```php
// WRONG: ready → completed (skip active)
UPDATE flow_token SET status = 'completed' WHERE status = 'ready';

// RIGHT: ready → active → completed (follow state machine)
UPDATE flow_token SET status = 'active' WHERE status = 'ready';
// ... work happens ...
UPDATE flow_token SET status = 'completed' WHERE status = 'active';
```

---

## 10. References

**Related Specs:**
- `docs/dag/03-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Component Flow implementation
- `docs/dag/03-specs/ROUTING_NODE_TRUTH_TABLE.md` - Node types and flags (TODO)
- `docs/developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md` - Behavior execution

**Database Schema:**
- `database/tenant_migrations/0001_init_tenant_schema_v2.php` - flow_token table

**Concept Documents:**
- `docs/dag/02-concepts/COMPONENT_PARALLEL_FLOW.md` - Component concept flow

---

## 11. Version History

**v1.0 (2025-12-02):**
- Initial lifecycle model
- Token types: batch, piece, component
- State machine: ready → active → waiting → completed/scrapped
- Relationship patterns: parent-child, parallel group, replacement
- Spawn patterns: job creation, parallel split, replacement
- Merge patterns: component merge
- Future support: multi-level components, batch join, archival

---

**END OF LIFECYCLE MODEL**

