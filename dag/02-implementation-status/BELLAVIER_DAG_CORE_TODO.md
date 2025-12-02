# 🎯 Bellavier ERP - DAG Core TODO List

**Status:** 📋 PLANNING PHASE  
**Created:** November 1, 2025  
**Purpose:** Architecture planning for Full DAG transition  
**Author:** AI Agent (based on BELLAVIER_PROTOCOL:ERP_OPS_CORE_V1.0)

---

## 🧭 **Vision Statement**

Transform Bellavier ERP production system from **Linear Task Flow** to **Full DAG (Directed Acyclic Graph)** to support:

- ✅ Parallel subprocess execution
- ✅ Component assembly (join nodes)
- ✅ Flexible rework routing
- ✅ Per-piece token tracking
- ✅ Graph-based bottleneck analysis

**Core Principle:** Non-destructive, backward-compatible, incremental adoption

---

## 📊 **Architecture Overview**

### **Conceptual Model:**

```
Linear (Current):
Job Ticket → [Task 1] → [Task 2] → [Task 3] → Done

DAG (Target):
Job Ticket → [Graph Instance]
                │
                ├─ [Node: CUT] ──┬─→ [Node: SEW_BODY] ──┐
                │                 │                      │
                │                 └─→ [Node: SEW_STRAP] ─┤
                │                                         │
                └─────────────────────────────────────────┴─→ [Node: ASSEMBLY]
                                                              │
                                                              └─→ [Node: QC] → [Node: FINISH]
```

### **Core Entities:**

| Entity | Purpose | Key Properties |
|--------|---------|----------------|
| **routing_graph** | Production workflow template | graph_id, name, version, is_published |
| **routing_node** | Work station / operation | node_id, graph_id, type, name, position |
| **routing_edge** | Directed connection between nodes | edge_id, from_node, to_node, condition |
| **job_graph_instance** | Active graph for a Job Ticket | instance_id, job_ticket_id, graph_id |
| **node_instance** | Node execution state for job | instance_node_id, status, blocked_by |
| **flow_token** | Work unit (piece/lot) | token_id, serial, current_node, status |
| **token_event** | Token lifecycle events | event_id, token_id, event_type, timestamp |

---

## 🗂️ **Phase 1: Core Foundation (Week 1-2)**

### **A1. Database Schema Design**

**Objective:** Define DAG data structures without breaking existing tables

**Tasks:**
- [ ] Design `routing_graph` table structure
  - Fields: graph_id (PK), name, description, version, created_by, is_published, created_at
  - Indexes: (is_published, created_at)
  
- [ ] Design `routing_node` table structure
  - Fields: node_id (PK), graph_id (FK), node_type (ENUM: operation/split/join/decision), name, work_center_id, position_x, position_y
  - Node types:
    - `operation`: Regular work (CUT, SEW, etc.)
    - `split`: Parallel spawn (CUT → BODY + STRAP)
    - `join`: Wait for all inputs (ASSEMBLY)
    - `decision`: QC pass/fail routing
  - Indexes: (graph_id, node_type)
  
- [ ] Design `routing_edge` table structure
  - Fields: edge_id (PK), graph_id (FK), from_node_id, to_node_id, edge_type (ENUM: normal/rework/conditional), condition_rule (JSON)
  - Edge types:
    - `normal`: Standard flow
    - `rework`: QC fail → previous node
    - `conditional`: Based on rules (e.g., qty > 10 → bulk line)
  - Indexes: (from_node_id), (to_node_id)
  - Constraint: DAG validation (no cycles!)
  
- [ ] Design `job_graph_instance` table structure
  - Fields: instance_id (PK), job_ticket_id (FK), graph_id (FK), status (ENUM: active/completed/cancelled), started_at, completed_at
  - Indexes: (job_ticket_id), (status)
  
- [ ] Design `node_instance` table structure
  - Fields: instance_node_id (PK), instance_id (FK), node_id (FK), status (ENUM: ready/active/waiting/blocked/completed), blocking_reason (JSON), started_at, completed_at
  - Node statuses:
    - `ready`: Can start (all inputs satisfied)
    - `active`: Work in progress
    - `waiting`: Join node waiting for inputs
    - `blocked`: Dependency not met
    - `completed`: Done
  - Indexes: (instance_id, status)
  
- [ ] Design `flow_token` table structure
  - Fields: token_id (PK), instance_id (FK), serial_number, current_node_id, status (ENUM: active/completed/scrapped), parent_token_id (for assembly), qty (DECIMAL), created_at, updated_at
  - Token statuses:
    - `active`: Moving through graph
    - `completed`: Reached finish node
    - `scrapped`: QC rejected, removed from flow
  - Indexes: (instance_id, status), (serial_number), (current_node_id)
  
- [ ] Design `token_event` table structure
  - Fields: event_id (PK), token_id (FK), event_type (ENUM), node_instance_id, operator_id, event_time, idempotency_key (UUID), metadata (JSON)
  - Event types:
    - `spawn`: Token created
    - `enter`: Token enters node
    - `start`: Work started
    - `pause`: Work paused
    - `resume`: Work resumed
    - `complete`: Work completed
    - `move`: Token moved to next node
    - `join`: Token joined with others
    - `split`: Token spawned children
    - `qc_pass`: QC approved
    - `qc_fail`: QC rejected
    - `rework`: Sent back to previous node
    - `scrap`: Token removed from flow
  - Indexes: (token_id, event_time), (idempotency_key - UNIQUE), (event_type)

**Constraints & Validations:**
- [ ] DAG validation algorithm (detect cycles before publishing graph)
- [ ] Join node input validation (must have 2+ incoming edges)
- [ ] Split node output validation (must have 2+ outgoing edges)
- [ ] Idempotency key enforcement (prevent duplicate events)

---

### **A2. Conceptual Mapping from Existing System**

**Objective:** Map current tables to DAG model without data loss

**Mapping Strategy:**

```
Current System → DAG System

atelier_job_ticket → job_graph_instance
  - Creates graph instance from routing template
  - Backward compat: Linear graph (1→2→3)

atelier_job_task → routing_node + node_instance
  - Task definition → Node template
  - Task execution → Node instance

atelier_wip_log → token_event
  - Each log entry → Token event
  - Operator actions → Event creation

atelier_task_operator_session → (derived from token_events)
  - Calculate from token events in node
  - Aggregate by operator_id + node_instance

atelier_job_ticket.process_mode → token spawn strategy
  - batch: 1 token per batch
  - piece: 1 token per piece (with serial)
```

**Key Decisions:**
- [ ] Default graph generation: Linear (Task 1 → Task 2 → Task 3)
- [ ] Feature flag: `enable_dag_routing` (controls new behavior)
- [ ] Hybrid mode: Support both linear tasks AND graph nodes simultaneously
- [ ] Migration path: job_ticket.graph_instance_id (nullable initially)

---

### **A3. State Machine Design**

**Objective:** Define clear state transitions for nodes and tokens

**Node Instance State Machine:**

```
     ┌──────────┐
     │  READY   │ ← All inputs satisfied, can start
     └────┬─────┘
          │ (operator starts)
     ┌────▼─────┐
     │  ACTIVE  │ ← Work in progress
     └────┬─────┘
          │ (all tokens complete)
     ┌────▼─────┐
     │ COMPLETED│ ← Node done
     └──────────┘
     
     ┌──────────┐
     │ WAITING  │ ← Join node, waiting for all inputs
     └──────────┘
     
     ┌──────────┐
     │ BLOCKED  │ ← Dependency not met (upstream failure)
     └──────────┘
```

**Token State Machine:**

```
┌───────┐
│ SPAWN │ ← Token created (from job ticket or split node)
└───┬───┘
    │
┌───▼────┐
│ ACTIVE │ ← Moving through graph
└───┬────┘
    │
    ├─→ [COMPLETE] ← Reached finish node
    ├─→ [SCRAPPED] ← QC failed, removed
    └─→ [WAITING]  ← Join node, waiting for siblings
```

**Event Semantics:**

| Event Type | Trigger | Token State Change | Node State Change |
|-----------|---------|-------------------|------------------|
| `spawn` | Job created OR split node | None → ACTIVE | - |
| `enter` | Token arrives at node | - | READY → ACTIVE (if first) |
| `start` | Operator begins work | - | - |
| `complete` | Operator finishes work | - | ACTIVE → COMPLETED (if last) |
| `move` | Token exits node | ACTIVE → ACTIVE | - |
| `join` | All inputs arrived | WAITING → ACTIVE | WAITING → ACTIVE |
| `qc_pass` | QC approved | - | - |
| `qc_fail` | QC rejected | ACTIVE → ACTIVE (rework) | - |
| `scrap` | Permanent removal | ACTIVE → SCRAPPED | - |

---

## 🗂️ **Phase 2: Graph Runtime Logic (Week 3-4)**

### **B1. Token Lifecycle Management**

**Objective:** Define how tokens move through the graph

**Core Algorithms:**

**1. Token Spawn:**
```pseudo
ON JobTicket.create(process_mode, target_qty):
  IF process_mode = 'batch':
    spawn 1 token (qty = target_qty)
  ELSE IF process_mode = 'piece':
    spawn target_qty tokens (qty = 1 each)
    
  FOR each token:
    SET token.current_node = graph.start_node
    CREATE token_event(type='spawn')
    CREATE token_event(type='enter', node=start_node)
```

**2. Token Routing:**
```pseudo
ON token_event(type='complete', token_id, node_id):
  edges = get_outgoing_edges(node_id)
  
  IF edges.count = 0:
    # Finish node
    SET token.status = 'completed'
    CREATE token_event(type='complete')
    
  ELSE IF edges.count = 1:
    # Auto route
    next_node = edges[0].to_node
    SET token.current_node = next_node
    CREATE token_event(type='move', to_node=next_node)
    CREATE token_event(type='enter', node=next_node)
    
  ELSE IF edges.count > 1:
    # Conditional routing
    next_node = evaluate_routing_rules(edges, token)
    SET token.current_node = next_node
    CREATE token_event(type='move', to_node=next_node)
    CREATE token_event(type='enter', node=next_node)
```

**3. Join Logic:**
```pseudo
ON token_event(type='enter', node_id) WHERE node.type = 'join':
  incoming_edges = get_incoming_edges(node_id)
  arrived_tokens = get_tokens_at_node(node_id)
  
  IF arrived_tokens.count < incoming_edges.count:
    # Still waiting
    SET node_instance.status = 'waiting'
    SET token.status = 'waiting'
  ELSE:
    # All inputs arrived!
    SET node_instance.status = 'active'
    FOR each token IN arrived_tokens:
      SET token.status = 'active'
      CREATE token_event(type='join')
```

**4. Split Logic:**
```pseudo
ON token_event(type='complete', node_id) WHERE node.type = 'split':
  outgoing_edges = get_outgoing_edges(node_id)
  
  FOR each edge IN outgoing_edges:
    new_token = clone_token(parent_token)
    SET new_token.parent_token_id = parent_token.token_id
    SET new_token.current_node = edge.to_node
    CREATE token_event(type='split', parent=parent_token)
    CREATE token_event(type='enter', node=edge.to_node)
  
  # Original token consumed
  SET parent_token.status = 'completed'
```

**5. Rework Logic:**
```pseudo
ON token_event(type='qc_fail', token_id, node_id):
  rework_edge = get_rework_edge(node_id)
  
  IF rework_edge EXISTS:
    rework_node = rework_edge.to_node
    SET token.current_node = rework_node
    CREATE token_event(type='rework', to_node=rework_node)
    CREATE token_event(type='enter', node=rework_node)
  ELSE:
    # No rework path → scrap
    SET token.status = 'scrapped'
    CREATE token_event(type='scrap')
```

---

### **B2. DAG Validation & Constraints**

**Objective:** Ensure graph integrity before execution

**Validation Rules:**

**1. Cycle Detection (Critical!):**
```pseudo
FUNCTION has_cycle(graph_id):
  nodes = get_all_nodes(graph_id)
  visited = {}
  recursion_stack = {}
  
  FOR each node IN nodes:
    IF NOT visited[node]:
      IF detect_cycle_dfs(node, visited, recursion_stack):
        RETURN true
  
  RETURN false

# Must validate before publishing graph!
```

**2. Start/End Node Validation:**
```pseudo
FUNCTION validate_start_end(graph_id):
  start_nodes = nodes WHERE incoming_edges.count = 0
  end_nodes = nodes WHERE outgoing_edges.count = 0
  
  ASSERT start_nodes.count = 1  # Exactly one entry point
  ASSERT end_nodes.count >= 1   # At least one exit point
```

**3. Join Node Validation:**
```pseudo
FUNCTION validate_join_nodes(graph_id):
  join_nodes = nodes WHERE type = 'join'
  
  FOR each node IN join_nodes:
    incoming = get_incoming_edges(node)
    ASSERT incoming.count >= 2  # Must have 2+ inputs
```

**4. Split Node Validation:**
```pseudo
FUNCTION validate_split_nodes(graph_id):
  split_nodes = nodes WHERE type = 'split'
  
  FOR each node IN split_nodes:
    outgoing = get_outgoing_edges(node)
    ASSERT outgoing.count >= 2  # Must have 2+ outputs
```

---

### **B3. Auto-Routing Rules**

**Objective:** Define how system routes tokens automatically

**Rule Priority:**

1. **Explicit Operator Choice** (highest priority)
   - If operator manually selects next node → use that
   
2. **Conditional Edges**
   - If edge has condition_rule → evaluate rules
   - Example: `qty > 10 → bulk_line`, `qty <= 10 → manual_line`
   
3. **QC Edges**
   - If QC fail → follow rework edge
   - If QC pass → follow normal edge
   
4. **Single Path Auto-Route** (lowest priority)
   - If only 1 outgoing edge → auto-route
   
**Condition Rule Format (JSON):**
```json
{
  "type": "conditional",
  "condition": "token.qty > 10 AND token.priority = 'high'",
  "then_node": "bulk_processing",
  "else_node": "manual_processing"
}
```

---

## 🗂️ **Phase 3: Migration Strategy (Week 5-6)**

### **C1. Backward Compatibility Approach**

**Objective:** Support both linear tasks AND DAG graphs simultaneously

**Strategy: Dual-Mode System**

```
Mode 1: Linear (Existing Jobs)
- job_ticket.graph_instance_id = NULL
- Uses atelier_job_task as before
- No changes to existing workflows

Mode 2: DAG (New Jobs)
- job_ticket.graph_instance_id != NULL
- Uses job_graph_instance + flow_tokens
- New graph-based UI
```

**Implementation Checklist:**

- [ ] Add `job_ticket.graph_instance_id` (nullable)
- [ ] Add `job_ticket.routing_mode` ENUM('linear', 'dag') DEFAULT 'linear'
- [ ] Add feature flag `enable_dag_routing` in config
- [ ] Create default linear graph template (1→2→3)
- [ ] Map existing tasks → nodes in linear graph
- [ ] Operator UI: Detect routing_mode, show appropriate interface

**Migration Path:**

```
Phase 1: Parallel operation (both systems coexist)
  - New tickets can choose linear OR dag
  - Existing tickets continue using linear
  
Phase 2: Gradual conversion
  - Convert simple products to DAG first
  - Complex products: create DAG templates
  - Training: Teach users new concepts
  
Phase 3: Full DAG
  - All new tickets use DAG
  - Legacy tickets remain linear (read-only)
  - Eventually migrate all historical data
```

---

### **C2. Data Migration Plan**

**Objective:** Transform existing data to DAG format safely

**Non-Destructive Approach:**

**Step 1: Create Linear Graph Templates**
```pseudo
FOR each unique task sequence in existing job_tickets:
  CREATE routing_graph(name="Linear: " + sequence_name)
  
  FOR each task in sequence:
    CREATE routing_node(type='operation', name=task.step_name)
    CREATE routing_edge(from=prev_node, to=current_node)
  
  PUBLISH graph
```

**Step 2: Link Existing Jobs (Optional)**
```pseudo
FOR each job_ticket WHERE graph_instance_id IS NULL:
  graph = find_or_create_linear_graph(job_ticket.tasks)
  
  CREATE job_graph_instance(
    job_ticket_id = job_ticket.id,
    graph_id = graph.id
  )
  
  UPDATE job_ticket SET graph_instance_id = instance.id
```

**Step 3: Convert WIP Logs to Token Events (Optional)**
```pseudo
FOR each wip_log:
  token = find_or_create_token(
    instance_id = wip_log.job_ticket.graph_instance_id,
    serial = wip_log.serial_number OR generate_batch_token()
  )
  
  CREATE token_event(
    token_id = token.id,
    event_type = map_event_type(wip_log.event_type),
    event_time = wip_log.event_time,
    operator_id = wip_log.operator_user_id
  )
```

**Rollback Plan:**
```pseudo
IF migration_fails OR performance_issues:
  # DAG system is additive, not destructive
  # Simply stop using it:
  
  1. SET enable_dag_routing = false
  2. UPDATE job_tickets SET routing_mode = 'linear'
  3. Existing linear system continues working
  4. No data loss!
```

---

### **C3. Testing Strategy**

**Test Levels:**

**1. Unit Tests:**
- [ ] DAG cycle detection algorithm
- [ ] Token routing logic
- [ ] Join condition evaluation
- [ ] State machine transitions

**2. Integration Tests:**
- [ ] Create graph → spawn tokens → route → complete
- [ ] Split node → parallel execution → join
- [ ] QC fail → rework edge → re-enter node
- [ ] Serial genealogy (parent-child tracking)

**3. Load Tests:**
- [ ] 1000 tokens in single graph
- [ ] 100 concurrent job instances
- [ ] Complex graph (10+ nodes, 3 join points)

**4. Compatibility Tests:**
- [ ] Linear job tickets still work
- [ ] Operator UI handles both modes
- [ ] Dashboard aggregates both systems

---

## 🗂️ **Phase 4: Integration & UX (Week 7-8)**

### **D1. Operator Interface**

**Objective:** Operator uses same Start/Complete buttons, backend adapts

**Current Flow:**
```
Operator:
1. Scans ticket QR
2. Sees task list
3. Taps "Start" on Task
4. Works
5. Taps "Complete"
```

**DAG Flow (Same UX!):**
```
Operator:
1. Scans ticket QR
2. Backend: Finds available tokens at current node
3. Shows: "3 pieces ready at SEW_BODY"
4. Taps "Start" → Backend creates token_event(type='start')
5. Works
6. Taps "Complete" → Backend:
   - Creates token_event(type='complete')
   - Routes token to next node automatically
   - Shows: "Moved to EDGE (next step)"
```

**Key Changes:**
- [ ] Backend: Map button clicks → token events
- [ ] Show token count instead of task progress %
- [ ] Auto-route notification ("Next: EDGE station")
- [ ] Join wait indicator ("Waiting for STRAP: 7/10 ready")

---

### **D2. Supervisor Dashboard**

**Objective:** Visualize entire graph, identify bottlenecks

**Current Dashboard:**
```
Linear view:
CUT (10/10) → SEW (5/10) → EDGE (0/10)
                   ↑
              Bottleneck!
```

**DAG Dashboard (Graph View!):**
```
       ┌─ SEW_BODY (8/10) ─┐
       │                   │
CUT ───┤                   ├─ ASSEMBLY (0/10) ← BLOCKED
(10/10)│                   │   (Waiting for STRAP)
       └─ SEW_STRAP (2/10) ┘
                 ↑
            BOTTLENECK!
```

**Features:**
- [ ] Live graph visualization (Cytoscape.js or D3.js)
- [ ] Node color by status:
  - Green: Completed
  - Blue: Active
  - Yellow: Waiting (join)
  - Red: Blocked
- [ ] Token count on each node
- [ ] Bottleneck highlighting (slowest node)
- [ ] Click node → see tokens + operators

---

### **D3. Graph Designer (For Planners)**

**Objective:** Create/edit routing graphs without coding

**UI Concept:**
```
┌─────────────────────────────────────┐
│ Graph Designer: TOTE Bag v2         │
├─────────────────────────────────────┤
│                                     │
│  [Drag & Drop Canvas]               │
│                                     │
│   ┌──────┐                         │
│   │ CUT  │                         │
│   └───┬──┘                         │
│       │                             │
│       ├───→ [SEW_BODY]              │
│       │                             │
│       └───→ [SEW_STRAP]             │
│                                     │
│  Toolbox:                          │
│  [ Operation Node ]                │
│  [ Join Node ]                     │
│  [ Split Node ]                    │
│  [ QC Decision ]                   │
│                                     │
│  [Validate DAG] [Publish]          │
└─────────────────────────────────────┘
```

**Validation Before Publish:**
- [ ] Check for cycles
- [ ] Verify start/end nodes
- [ ] Validate join/split nodes
- [ ] Test with sample token

---

### **D4. Serial Genealogy (Traceability)**

**Objective:** Track parent-child relationships in assembly

**Assembly Example:**
```
Final Product: TOTE-001
├─ BODY: TOTE-001-BODY (parent_token_id = NULL)
├─ STRAP-1: TOTE-001-STRAP-1 (parent_token_id = NULL)
├─ STRAP-2: TOTE-001-STRAP-2 (parent_token_id = NULL)
└─ HARDWARE: TOTE-001-HW (parent_token_id = NULL)

Assembly Token: TOTE-001-FINAL
├─ parent_tokens = [BODY, STRAP-1, STRAP-2, HW]
└─ Created at: ASSEMBLY node (join)
```

**Query Traceability:**
```sql
-- Find all components of final product
SELECT 
  ft.serial_number as component_serial,
  rn.name as made_at_node,
  te.operator_name,
  te.event_time
FROM flow_token parent
JOIN flow_token child ON child.parent_token_id = parent.token_id
JOIN token_event te ON te.token_id = child.token_id
WHERE parent.serial_number = 'TOTE-001-FINAL'
ORDER BY te.event_time;

-- Find what final product uses this component
SELECT 
  parent.serial_number as final_product
FROM flow_token child
JOIN flow_token parent ON parent.token_id = child.parent_token_id
WHERE child.serial_number = 'TOTE-001-BODY';
```

---

## ✅ **Priority & Sequence**

### **Week 1-2: Core Foundation**
1. ✅ Database schema design (A1)
2. ✅ Conceptual mapping (A2)
3. ✅ State machine design (A3)

### **Week 3-4: Runtime Logic**
1. ✅ Token lifecycle (B1)
2. ✅ DAG validation (B2)
3. ✅ Auto-routing rules (B3)

### **Week 5-6: Migration**
1. ✅ Backward compatibility (C1)
2. ✅ Data migration plan (C2)
3. ✅ Testing strategy (C3)

### **Week 7-8: Integration & UX**
1. ✅ Operator interface (D1)
2. ✅ Supervisor dashboard (D2)
3. ✅ Graph designer (D3)
4. ✅ Serial genealogy (D4)

---

## 🎯 **Success Criteria**

**Must Have:**
- [ ] No cycle in any published graph
- [ ] Idempotent event processing (no duplicates)
- [ ] Backward compatible (linear jobs work)
- [ ] Safe rollback mechanism
- [ ] < 100ms token routing latency

**Should Have:**
- [ ] Visual graph designer
- [ ] Real-time dashboard
- [ ] Serial genealogy query
- [ ] Bottleneck detection

**Nice to Have:**
- [ ] Graph simulation (dry run)
- [ ] What-if analysis
- [ ] Predictive bottleneck warning

---

## 🚨 **Critical Constraints**

1. **DAG Validation:** No cycles allowed (detect before publish)
2. **Idempotency:** Every event needs UUID (prevent double submit)
3. **Join Completeness:** Join node waits for ALL inputs
4. **Serial Genealogy:** Parent-child linkage at assembly
5. **Non-Destructive:** Existing system continues working
6. **Rollback:** Can revert to linear if needed

---

## 📚 **Related Documents**

- `BELLAVIER_DAG_RUNTIME_FLOW.md` - Token/Node lifecycle details
- `BELLAVIER_DAG_MIGRATION_PLAN.md` - Step-by-step migration
- `BELLAVIER_DAG_INTEGRATION_NOTES.md` - UI integration approach

---

**Status:** Planning complete, ready for review  
**Next Step:** Review with team → Approve approach → Begin Phase 1 implementation

