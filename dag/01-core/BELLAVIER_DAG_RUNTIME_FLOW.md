# 🔄 Bellavier ERP - DAG Runtime Flow

**Status:** 📋 PLANNING PHASE  
**Created:** November 1, 2025  
**Purpose:** Token & Node lifecycle documentation  
**Author:** AI Agent (based on BELLAVIER_PROTOCOL:ERP_OPS_CORE_V1.0)

---

## 🎯 **Overview**

This document explains how **tokens** (work units) flow through the **graph** (production workflow) and how **nodes** (work stations) change states during execution.

**Core Concept:**
```
Token = Piece of work (can be 1 piece or 1 lot)
Node = Work station or decision point
Edge = Path between nodes
Event = State change recorded in token_event table
```

---

## 🏗️ **System Architecture**

### **Three-Layer Model:**

```
┌─────────────────────────────────────────────┐
│  Layer 1: Graph Template (Routing Design)  │
│  - routing_graph, routing_node, routing_edge│
│  - Static, designed by planner             │
└─────────────────────────────────────────────┘
                    │
                    │ instantiate
                    ▼
┌─────────────────────────────────────────────┐
│  Layer 2: Graph Instance (Job Execution)   │
│  - job_graph_instance, node_instance       │
│  - Created per job ticket                  │
└─────────────────────────────────────────────┘
                    │
                    │ spawn
                    ▼
┌─────────────────────────────────────────────┐
│  Layer 3: Token Flow (Work Unit Tracking)  │
│  - flow_token, token_event                 │
│  - Moves through graph, records events     │
└─────────────────────────────────────────────┘
```

---

## 🎫 **Token Lifecycle**

### **Phase 1: Spawn**

**Trigger:** Job Ticket created

**Process:**
```
1. Job Ticket created
2. System creates job_graph_instance (from routing template)
3. Determine spawn strategy based on process_mode:
   
   IF process_mode = 'batch':
     Create 1 token (qty = target_qty)
   
   ELSE IF process_mode = 'piece':
     Create target_qty tokens (qty = 1 each, unique serial)

4. Place all tokens at START node
5. Create token_event(type='spawn') for each token
6. Create token_event(type='enter', node=START) for each token
```

**Example:**
```
Job: TOTE-001 (10 pieces, piece mode)

Creates:
- 10 tokens: TOTE-001-01, TOTE-001-02, ..., TOTE-001-10
- Each token.qty = 1
- Each token.current_node = CUT (start node)
- 20 events: 10x spawn + 10x enter
```

---

### **Phase 2: Enter Node**

**Trigger:** Token arrives at a node

**Process:**
```
1. Token arrives at node
2. Check node type:
   
   IF node.type = 'operation':
     SET token.status = 'active'
     SET node_instance.status = 'active' (if first token)
     Ready for operator to start work
   
   ELSE IF node.type = 'join':
     SET token.status = 'waiting'
     Check if all inputs arrived:
       IF all_inputs_satisfied():
         SET node_instance.status = 'active'
         SET all_waiting_tokens.status = 'active'
       ELSE:
         SET node_instance.status = 'waiting'
   
   ELSE IF node.type = 'decision':
     Evaluate condition immediately
     Route to appropriate next node

3. Create token_event(type='enter', node=current_node)
```

**Join Node Example:**
```
Node: ASSEMBLY (join)
Incoming edges: [SEW_BODY, SEW_STRAP]

Token 1 (BODY-001) arrives:
  - Creates token_event(type='enter')
  - token.status = 'waiting'
  - node_instance.status = 'waiting' (not all inputs)

Token 2 (STRAP-001) arrives:
  - Creates token_event(type='enter')
  - Check: BODY + STRAP = all inputs satisfied!
  - token.status = 'active' (both tokens)
  - node_instance.status = 'active'
  - Creates token_event(type='join') for both
```

---

### **Phase 3: Work Execution (UPDATED: Work Queue Approach)**

**Trigger:** Operator views work queue and selects token

**Process Flow:**

```
┌────────────────────────────────────────┐
│ Operator Opens Task (e.g., SEW_BODY)  │
└───────────────┬────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│ System shows Work Queue:               │
│ - 3 pieces ready (TOTE-001, 002, 003) │
│ - 1 in progress (TOTE-004, by me)     │
│ - 2 paused (TOTE-005, 006, by me)     │
│ - 4 completed (TOTE-007-010)          │
└───────────────┬────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│ Operator selects "TOTE-001"           │
│ Taps "Start Work"                     │
│ Backend creates:                      │
│ - token_work_session (started_at)     │
│ - token_event(type='start')           │
│ - token.status = 'active'             │
└───────────────┬────────────────────────┘
                │
                │ (operator works)
                │
                ▼
┌────────────────────────────────────────┐
│ Operator needs break                  │
│ Taps "Pause"                          │
│ Backend updates:                      │
│ - session.status = 'paused'           │
│ - session.paused_at = NOW()           │
│ - token.status = 'paused'             │
└───────────────┬────────────────────────┘
                │
                │ (operator switches to TOTE-004)
                │
                ▼
┌────────────────────────────────────────┐
│ Later: Operator returns                │
│ Taps "Resume" on TOTE-001             │
│ Backend updates:                      │
│ - session.status = 'active'           │
│ - session.resumed_at = NOW()          │
│ - token.status = 'active'             │
└───────────────┬────────────────────────┘
                │
                │ (operator completes work)
                │
                ▼
┌────────────────────────────────────────┐
│ Operator taps "Complete"              │
│ Backend:                              │
│ - session.status = 'completed'        │
│ - session.completed_at = NOW()        │
│ - Calculate work_time (exclude pause) │
│ - token_event(type='complete')        │
│ - Triggers routing to next node       │
└───────────────┬────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│ System routes token to next node      │
│ Token: TOTE-001 → SEW_STRAP           │
│ (See Phase 4: Routing)                │
└────────────────────────────────────────┘
```

**Event Semantics:**

| Event | Description | Created By | Side Effects |
|-------|-------------|-----------|--------------|
| `start` | Operator begins work on token | Operator UI | Node status → active |
| `pause` | Work temporarily stopped | Operator UI | Record pause reason |
| `resume` | Work restarted after pause | Operator UI | Calculate pause duration |
| `complete` | Work finished | Operator UI | Trigger routing |

**Pause/Resume Example:**
```
Timeline:
10:00 - token_event(type='start', token=TOTE-001)
10:30 - token_event(type='pause', reason='lunch_break')
11:00 - token_event(type='resume')
12:00 - token_event(type='complete')

Total work time: 1.5 hours (10:00-10:30 + 11:00-12:00)
Pause time: 0.5 hours
```

---

### **Phase 4: Routing**

**Trigger:** Token work completed

**Routing Algorithm:**

```
ON token_event(type='complete', token_id, current_node):
  
  # Step 1: Get outgoing edges
  edges = get_outgoing_edges(current_node)
  
  # Step 2: Route based on edge count
  
  IF edges.count = 0:
    # Finish node - no more work
    SET token.status = 'completed'
    CREATE token_event(type='complete', metadata={'final': true})
    RETURN
  
  ELSE IF edges.count = 1:
    # Single path - auto route
    next_node = edges[0].to_node
    route_token(token, next_node)
  
  ELSE IF edges.count > 1:
    # Multiple paths - evaluate conditions
    next_node = select_next_node(edges, token)
    route_token(token, next_node)

FUNCTION route_token(token, next_node):
  # Move token
  SET token.current_node = next_node
  CREATE token_event(type='move', to_node=next_node)
  
  # Enter next node
  CREATE token_event(type='enter', node=next_node)
  
  # Check node type
  IF next_node.type = 'split':
    execute_split(token, next_node)
  ELSE IF next_node.type = 'join':
    check_join_condition(token, next_node)
```

**Conditional Routing Example:**
```
Node: QC_CHECK (decision node)
Outgoing edges:
  1. qc_pass → FINISH
  2. qc_fail → REWORK (edge back to SEW)

Operator marks QC result:
  IF qc_result = 'pass':
    CREATE token_event(type='qc_pass')
    route_token(token, FINISH)
  ELSE:
    CREATE token_event(type='qc_fail')
    route_token(token, SEW)  # Rework edge
```

---

### **Phase 5: Split (Parallel Spawn)**

**Trigger:** Token completes split node

**Process:**
```
ON token reaches split node:
  
  # Example: CUT splits to BODY + STRAP
  
  outgoing_edges = get_outgoing_edges(split_node)
  # edges = [to_SEW_BODY, to_SEW_STRAP]
  
  parent_token = current_token
  
  FOR each edge IN outgoing_edges:
    # Create child token
    child_token = create_token(
      serial = parent.serial + "-" + edge.component_name,
      qty = calculate_split_qty(parent, edge),
      parent_token_id = parent.token_id,
      current_node = edge.to_node
    )
    
    CREATE token_event(
      type = 'split',
      token_id = child_token.id,
      metadata = {
        'parent_token': parent.serial,
        'component': edge.component_name
      }
    )
    
    CREATE token_event(
      type = 'enter',
      token_id = child_token.id,
      node = edge.to_node
    )
  
  # Parent token consumed
  SET parent_token.status = 'completed'
```

**Example:**
```
Token: TOTE-001 (1 bag)
Node: CUT (split node)
Edges: [SEW_BODY, SEW_STRAP]

Result:
  Parent (TOTE-001) → completed
  Child 1: TOTE-001-BODY → SEW_BODY
  Child 2: TOTE-001-STRAP → SEW_STRAP

Events created:
  - token_event(type='split', token=TOTE-001-BODY, parent=TOTE-001)
  - token_event(type='split', token=TOTE-001-STRAP, parent=TOTE-001)
  - token_event(type='enter', token=TOTE-001-BODY, node=SEW_BODY)
  - token_event(type='enter', token=TOTE-001-STRAP, node=SEW_STRAP)
```

---

### **Phase 6: Join (Assembly)**

**Trigger:** Token enters join node

**Process:**
```
ON token_event(type='enter', node) WHERE node.type = 'join':
  
  incoming_edges = get_incoming_edges(node)
  # Example: [from_SEW_BODY, from_SEW_STRAP]
  
  tokens_at_node = get_tokens(
    current_node = node,
    status IN ('active', 'waiting')
  )
  
  IF tokens_at_node.count < incoming_edges.count:
    # Not all inputs arrived yet
    SET token.status = 'waiting'
    SET node_instance.status = 'waiting'
    
    # Show waiting status
    UPDATE node_instance SET metadata = {
      'waiting_for': list_missing_inputs(),
      'arrived': tokens_at_node.count,
      'required': incoming_edges.count
    }
  
  ELSE:
    # All inputs arrived!
    
    # Activate all waiting tokens
    FOR each token IN tokens_at_node:
      SET token.status = 'active'
      CREATE token_event(
        type = 'join',
        metadata = {
          'siblings': list_sibling_tokens(),
          'join_time': NOW()
        }
      )
    
    SET node_instance.status = 'active'
    
    # Ready for operator to assemble
```

**Assembly Example:**
```
Node: ASSEMBLY (join)
Required inputs: BODY + STRAP

Timeline:
10:00 - BODY-001 enters ASSEMBLY
        token.status = 'waiting'
        node.status = 'waiting'
        node.metadata = {'waiting_for': ['STRAP'], 'arrived': 1, 'required': 2}

10:30 - STRAP-001 enters ASSEMBLY
        All inputs satisfied!
        BODY-001.status = 'active'
        STRAP-001.status = 'active'
        node.status = 'active'
        
11:00 - Operator assembles
        Creates new token: TOTE-001-FINAL
        TOTE-001-FINAL.parent_tokens = [BODY-001, STRAP-001]
        
        token_event(type='complete', token=TOTE-001-FINAL)
        Routes to next node
```

**Join Strategy:**
- **All-at-once:** All tokens must arrive before any can proceed
- **Pair-wise:** Tokens pair up as they arrive (for bulk assembly)
- **Counted:** Fixed number required (e.g., 2 straps + 1 body)

---

### **Phase 7: QC & Rework**

**Trigger:** QC inspection result

**QC Pass Flow:**
```
Token at QC node:
  Operator inspects → Pass
  
  CREATE token_event(type='qc_pass')
  route_token(token, next_normal_node)
```

**QC Fail Flow:**
```
Token at QC node:
  Operator inspects → Fail
  
  CREATE token_event(
    type = 'qc_fail',
    metadata = {
      'defect_type': 'stitch_loose',
      'severity': 'minor',
      'inspector': operator_id
    }
  )
  
  rework_edge = get_rework_edge(qc_node)
  
  IF rework_edge EXISTS:
    # Send back to previous node
    rework_node = rework_edge.to_node
    route_token(token, rework_node)
    
    CREATE token_event(
      type = 'rework',
      metadata = {
        'rework_count': count_previous_reworks(token),
        'reason': 'qc_fail'
      }
    )
  
  ELSE:
    # No rework path - must scrap
    SET token.status = 'scrapped'
    CREATE token_event(type='scrap')
```

**Rework Limit:**
```
IF token.rework_count >= MAX_REWORK_LIMIT:
  # Too many rework attempts
  SET token.status = 'scrapped'
  CREATE token_event(
    type = 'scrap',
    metadata = {
      'reason': 'max_rework_exceeded',
      'limit': MAX_REWORK_LIMIT
    }
  )
  
  # Alert supervisor
  send_notification(
    role = 'supervisor',
    message = "Token {serial} scrapped after {count} rework attempts"
  )
  
  # Handle replacement token (see Scrap & Replacement section below)
  handle_scrap_replacement(token, qc_node)
```

---

### **Phase 7.5: Scrap & Replacement Token**

**Key Concept:**
- **Rework Token** = ซ่อมชิ้นเดิม (ย้อนกลับไปบาง node)
- **Replacement Token** = ทำใหม่ (เริ่มจาก START หรือ CUT)

**Critical Rule:**
> **QC Fail → Rework (ซ่อม)**  
> **Scrap → Replacement (ทำใหม่)**

---

#### **Scrap Scenarios:**

**Scenario 1: Rework Limit Reached**
```
Token rework_count >= MAX_REWORK_LIMIT
→ Cannot rework anymore
→ Must scrap
```

**Scenario 2: Material Defect**
```
Operator marks: "Material Defect - Cannot Rework"
→ Immediate scrap (no rework limit check)
```

---

#### **Scrap Replacement Policy:**

Policy structure (extends rework policy):
```json
{
  "on_fail": "spawn_new_token",  // Rework policy (existing)
  "target_nodes": ["SEW", "EDG"],
  
  "on_scrap": {  // ✨ NEW: Scrap replacement policy
    "mode": "manual" | "auto_spawn_from_start" | "auto_spawn_from_cut" | "none",
    "require_approval": true | false,
    "notification": {
      "roles": ["supervisor"],
      "message_template": "Token {serial} scrapped. Action required."
    }
  }
}
```

**Policy Modes:**

| Mode | Behavior | Use Case |
|------|----------|----------|
| **`manual`** | Alert supervisor → Supervisor creates replacement token manually | Default (safest) |
| **`auto_spawn_from_start`** | Auto spawn replacement token at START node | Remake entire piece |
| **`auto_spawn_from_cut`** | Auto spawn replacement token at CUT node | Recut material only |
| **`none`** | No replacement token created | Material loss (don't remake) |

---

#### **Scrap Replacement Flow:**

```
ON token scrapped:
  
  # 1. Mark token as scrapped
  SET token.status = 'scrapped'
  CREATE token_event(
    type = 'scrap',
    metadata = {
      'reason': 'max_rework_exceeded' | 'material_defect',
      'rework_count': token.rework_count,
      'limit': MAX_REWORK_LIMIT
    }
  )
  
  # 2. Get scrap policy from QC node
  scrap_policy = get_scrap_policy(qc_node)
  mode = scrap_policy['on_scrap']['mode']
  
  # 3. Handle replacement based on mode
  IF mode = 'auto_spawn_from_start':
    replacement_token = spawn_token(
      serial = generate_replacement_serial(token.serial),
      current_node = START_NODE,
      parent_scrapped_token_id = token.id,
      scrap_replacement_mode = 'auto_start'
    )
    CREATE token_event(
      type = 'spawn',
      token_id = replacement_token.id,
      metadata = {
        'reason': 'scrap_replacement',
        'parent_scrapped': token.serial,
        'mode': 'auto_start'
      }
    )
    send_notification(
      roles = scrap_policy['on_scrap']['notification']['roles'],
      message = "Token {token.serial} scrapped. Replacement token {replacement_token.serial} created at START."
    )
  
  ELSE IF mode = 'auto_spawn_from_cut':
    # Find CUT node in graph
    cut_node = find_node_by_type(graph, 'operation', team_category='cutting')
    IF cut_node:
      replacement_token = spawn_token(
        serial = generate_replacement_serial(token.serial),
        current_node = cut_node.id,
        parent_scrapped_token_id = token.id,
        scrap_replacement_mode = 'auto_cut'
      )
      CREATE token_event(
        type = 'spawn',
        token_id = replacement_token.id,
        metadata = {
          'reason': 'scrap_replacement',
          'parent_scrapped': token.serial,
          'mode': 'auto_cut'
        }
      )
      send_notification(...)
    ELSE:
      # Fallback to START if CUT not found
      spawn_replacement_at_start(...)
  
  ELSE IF mode = 'manual':
    # Just notify supervisor
    send_notification(
      roles = scrap_policy['on_scrap']['notification']['roles'],
      message = scrap_policy['on_scrap']['notification']['message_template']
        .replace('{serial}', token.serial)
        .replace('{count}', token.rework_count)
    )
    # Supervisor will create replacement token via UI
  
  ELSE IF mode = 'none':
    # No replacement - just log
    log_material_loss(token)
    send_notification(...)  # Informational only
```

---

#### **Key Differences: Rework vs Replacement**

| Aspect | Rework Token | Replacement Token |
|--------|--------------|-------------------|
| **Purpose** | ซ่อมชิ้นเดิม | ทำใหม่ |
| **Trigger** | QC fail (but rework_count < limit) | Scrap (rework_count >= limit OR material_defect) |
| **Policy** | `on_fail` | `on_scrap` |
| **Target Node** | Rework node (e.g., SEW, EDG) | START or CUT |
| **Serial Number** | Same serial (or serial-REWORK) | New serial (or serial-REPLACE) |
| **Parent Link** | `parent_token_id` (if split) | `parent_scrapped_token_id` |
| **Flow** | Token → Rework Sink → Spawn at rework node | Token → Scrap → Spawn at START/CUT |

---

#### **Example Flow:**

**Normal Rework (ซ่อม):**
```
1. Token TOTE-001-05 at QC → Fail (reason: QC_FAIL_STITCH)
2. Route to Rework Sink (via rework edge)
3. Rework Sink reads policy → Spawn rework token at SEW
4. Rework token TOTE-001-05-REWORK starts at SEW
5. After SEW → Back to QC
6. If pass → Continue to PACK
7. If fail again → Repeat (until rework_count < limit)
```

**Scrap & Replacement (ทำใหม่):**
```
1. Token TOTE-001-05 at QC → Fail (rework_count = 3, limit = 3)
2. Mark token as scrapped
3. Check on_scrap.mode = "auto_spawn_from_start"
4. Spawn replacement token TOTE-001-05-REPLACE at START
5. Replacement token starts fresh from START
6. Original token TOTE-001-05 remains as scrapped (for tracking)
```

---

#### **Database Schema:**

```sql
-- Add to flow_token table
ALTER TABLE flow_token
ADD COLUMN parent_scrapped_token_id INT NULL COMMENT 'Reference to scrapped token (if this is a replacement)',
ADD COLUMN scrap_replacement_mode VARCHAR(50) NULL COMMENT 'How this token was created: manual, auto_start, auto_cut',
ADD INDEX idx_parent_scrapped (parent_scrapped_token_id);
```

---

#### **Summary Logic (For AI Agents):**

**Remember these 3 rules:**

1. **QC fail but can still rework:**
   - Use `on_fail` → spawn rework token
   - Rework token = same piece, go back to some node
   - Graph remains DAG (no loops)

2. **QC fail and "cannot rework anymore":**
   - Mark scrap (status = scrapped)
   - Use `on_scrap.mode` to decide replacement token
   - Replacement token = new piece, start from START or CUT per policy

3. **Rework Limit = forced entry to scrap flow:**
   - rework_count >= MAX_REWORK_LIMIT → cannot rework anymore
   - Always use `on_scrap` flow

**Golden Rule:**
> **QC Fail → Rework (ซ่อม)**  
> **Scrap → Replacement (ทำใหม่)**

---

### **Phase 8: Completion**

**Trigger:** Token reaches finish node

**Process:**
```
ON token reaches finish_node:
  
  SET token.status = 'completed'
  SET token.completed_at = NOW()
  
  CREATE token_event(
    type = 'complete',
    metadata = {
      'final': true,
      'total_duration': calculate_duration(token),
      'node_count': count_nodes_visited(token),
      'rework_count': count_reworks(token)
    }
  )
  
  # Check if all tokens in job completed
  remaining_tokens = count_active_tokens(job_instance)
  
  IF remaining_tokens = 0:
    # Job fully completed!
    SET job_instance.status = 'completed'
    SET job_instance.completed_at = NOW()
    
    # Update job ticket
    UPDATE job_ticket SET status = 'completed'
    
    # Notify
    send_notification(
      role = 'planner',
      message = "Job {ticket_code} completed"
    )
```

---

## 🔧 **Node Instance State Machine**

### **State Transitions:**

```
     ┌──────────┐
     │  READY   │ ← Created, waiting for first token
     └────┬─────┘
          │ (first token enters)
     ┌────▼─────┐
     │  ACTIVE  │ ← Work in progress
     └────┬─────┘
          │ (all tokens complete)
     ┌────▼─────────┐
     │  COMPLETED   │ ← Node done for this job
     └──────────────┘
     
Special states:
     
     ┌──────────┐
     │ WAITING  │ ← Join node, not all inputs arrived
     └──────────┘
     
     ┌──────────┐
     │ BLOCKED  │ ← Upstream failure, cannot proceed
     └──────────┘
```

### **State Descriptions:**

| State | Meaning | Tokens at Node | Can Start Work? |
|-------|---------|----------------|-----------------|
| READY | Created, no tokens yet | 0 | No |
| WAITING | Join waiting for inputs | 1+ (waiting) | No |
| ACTIVE | Work in progress | 1+ (active) | Yes |
| BLOCKED | Upstream problem | 0 | No |
| COMPLETED | All tokens done | 0 (moved on) | No |

---

## 📊 **Event Processing Rules**

### **Idempotency:**

Every event must have a **unique UUID** (idempotency_key):

```
client_generates_uuid = uuid4()

CREATE token_event(
  token_id = 123,
  event_type = 'start',
  idempotency_key = client_generates_uuid,
  ...
)

# If submitted again with same UUID:
CONSTRAINT idx_idempotency UNIQUE (idempotency_key)
→ INSERT fails (duplicate key)
→ Return 200 OK (already processed)
```

**Why important:**
- Network retries don't create duplicate events
- Offline queue doesn't double-submit
- Audit trail remains clean

---

### **Event Ordering:**

Events must be processed in **chronological order** per token:

```
# Correct order:
1. spawn
2. enter (node A)
3. start
4. complete
5. move
6. enter (node B)

# Invalid order detected:
1. spawn
2. enter (node A)
3. complete  ← ERROR! Must 'start' before 'complete'
```

**Validation:**
```
ON token_event.create:
  last_event = get_last_event(token_id)
  
  IF NOT is_valid_transition(last_event.type, new_event.type):
    RAISE InvalidTransitionError
```

---

### **Event Metadata (JSON):**

Each event can store additional context:

```json
{
  "event_type": "qc_fail",
  "metadata": {
    "defect_type": "stitch_loose",
    "defect_location": "left_side",
    "severity": "minor",
    "inspector": "user_123",
    "photo_url": "s3://qc-photos/abc.jpg",
    "rework_instructions": "Re-stitch with reinforcement"
  }
}
```

**Common Metadata:**

| Event Type | Typical Metadata |
|-----------|------------------|
| `start` | `workstation_id`, `operator_notes` |
| `pause` | `pause_reason`, `pause_category` |
| `complete` | `actual_qty`, `quality_notes` |
| `qc_fail` | `defect_type`, `severity`, `photo_url` |
| `rework` | `rework_count`, `rework_reason` |
| `split` | `parent_token`, `component_name` |
| `join` | `siblings`, `assembly_notes` |

---

## 🔍 **Query Patterns**

### **1. Token Current Status:**

```sql
SELECT 
  ft.serial_number,
  ft.status,
  rn.name as current_node_name,
  ni.status as node_status,
  (SELECT event_type FROM token_event 
   WHERE token_id = ft.token_id 
   ORDER BY event_time DESC LIMIT 1) as last_event
FROM flow_token ft
JOIN routing_node rn ON rn.node_id = ft.current_node_id
JOIN node_instance ni ON ni.node_id = rn.node_id
WHERE ft.token_id = ?;
```

### **2. Bottleneck Detection:**

```sql
-- Nodes with most waiting tokens
SELECT 
  rn.name as node_name,
  COUNT(ft.token_id) as waiting_tokens,
  ni.status as node_status
FROM flow_token ft
JOIN routing_node rn ON rn.node_id = ft.current_node_id
JOIN node_instance ni ON ni.node_id = rn.node_id
WHERE ft.status IN ('active', 'waiting')
GROUP BY rn.node_id
ORDER BY waiting_tokens DESC
LIMIT 5;
```

### **3. Token Journey:**

```sql
-- Full path of a token
SELECT 
  te.event_type,
  te.event_time,
  rn.name as node_name,
  te.metadata
FROM token_event te
LEFT JOIN routing_node rn ON JSON_EXTRACT(te.metadata, '$.node_id') = rn.node_id
WHERE te.token_id = ?
ORDER BY te.event_time ASC;
```

### **4. Assembly Lineage:**

```sql
-- Find all components of final product
SELECT 
  child.serial_number as component,
  parent.serial_number as final_product,
  te.event_time as assembled_at
FROM flow_token child
JOIN flow_token parent ON parent.token_id IN (
  SELECT parent_token_id 
  FROM flow_token 
  WHERE token_id = child.token_id
)
JOIN token_event te ON te.token_id = child.token_id AND te.event_type = 'join'
WHERE parent.serial_number = ?;
```

---

## 🎯 **Performance Considerations**

### **Indexes Required:**

```sql
-- Token queries
CREATE INDEX idx_token_status ON flow_token(status, current_node_id);
CREATE INDEX idx_token_serial ON flow_token(serial_number);

-- Event queries
CREATE INDEX idx_event_token_time ON token_event(token_id, event_time);
CREATE INDEX idx_event_idempotency ON token_event(idempotency_key) UNIQUE;
CREATE INDEX idx_event_type ON token_event(event_type, event_time);

-- Node queries
CREATE INDEX idx_node_instance_status ON node_instance(instance_id, status);
```

### **Query Optimization:**

1. **Avoid N+1:** Fetch token + events in single query
2. **Cache node status:** Update denormalized counts
3. **Partition events:** Archive old events to separate table
4. **Materialized views:** Pre-compute bottleneck metrics

---

## 📋 **Summary**

**Token Lifecycle:**
```
SPAWN → ENTER → START → COMPLETE → ROUTE → ENTER (next) → ... → FINISH
```

**Key Events:**
- `spawn`, `enter`, `start`, `pause`, `resume`, `complete`, `move`
- `split`, `join`, `qc_pass`, `qc_fail`, `rework`, `scrap`

**Node States:**
- READY → ACTIVE → COMPLETED
- Special: WAITING (join), BLOCKED (upstream fail)

**Critical Rules:**
- ✅ Idempotency (UUID per event)
- ✅ Event ordering (validate transitions)
- ✅ Join completeness (all inputs before activate)
- ✅ Rework limits (max retries)

---

**See Also:**
- `BELLAVIER_DAG_CORE_TODO.md` - Implementation checklist
- `BELLAVIER_DAG_MIGRATION_PLAN.md` - Migration strategy
- `BELLAVIER_DAG_INTEGRATION_NOTES.md` - UI integration

---

**Status:** Runtime flow documented, ready for implementation

