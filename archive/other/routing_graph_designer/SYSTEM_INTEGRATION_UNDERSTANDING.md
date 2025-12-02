# 🔗 Routing Graph Designer - System Integration Understanding

**วันที่สรุป:** 10 พฤศจิกายน 2025  
**สถานะ:** ✅ ความเข้าใจครบถ้วน - Ready for Full Development  
**Purpose:** บันทึกความเข้าใจระบบทั้งหมดเพื่อป้องกัน context token limit

---

## 📋 สารบัญ

1. [DAG Routing Graph Architecture](#dag-routing-graph-architecture)
2. [Token Lifecycle Flow](#token-lifecycle-flow)
3. [Work Queue System](#work-queue-system)
4. [Team Management System](#team-management-system)
5. [Assignment System](#assignment-system)
6. [Node Pre-Assignment](#node-pre-assignment)
7. [Integration Flow](#integration-flow)
8. [Key Database Tables](#key-database-tables)
9. [Key Services](#key-services)
10. [Critical Business Rules](#critical-business-rules)

---

## 🏗️ DAG Routing Graph Architecture

### Three-Layer Model

```
┌─────────────────────────────────────────────┐
│  Layer 1: Graph Template (Design Time)     │
│  - routing_graph (template)                │
│  - routing_node (work stations)            │
│  - routing_edge (connections)              │
│  - Static, designed by planner             │
│  - Status: draft → published               │
└─────────────────────────────────────────────┘
                    │
                    │ instantiate (when Job Ticket created)
                    ▼
┌─────────────────────────────────────────────┐
│  Layer 2: Graph Instance (Runtime)          │
│  - job_graph_instance (1 per Job Ticket)   │
│  - node_instance (execution state)         │
│  - Created per job ticket                  │
│  - Links to routing_graph template         │
└─────────────────────────────────────────────┘
                    │
                    │ spawn tokens
                    ▼
┌─────────────────────────────────────────────┐
│  Layer 3: Token Flow (Work Unit Tracking)  │
│  - flow_token (work units)                 │
│  - token_event (state changes)             │
│  - Moves through graph, records events     │
│  - Per-piece or per-batch tracking         │
└─────────────────────────────────────────────┘
```

### Key Concepts

- **Graph Template**: Reusable workflow design (like a bag pattern template)
- **Graph Instance**: Active execution for a specific job
- **Token**: Work unit (1 piece or 1 lot) flowing through graph
- **Node**: Work station or decision point
- **Edge**: Path between nodes (normal/conditional/rework)

---

## 🎫 Token Lifecycle Flow

### Complete Flow (8 Phases)

```
1. SPAWN
   └─ Job Ticket created → Create tokens (batch/piece mode)
   
2. ENTER
   └─ Token arrives at node → Check node type → Set status
   
3. WORK EXECUTION
   └─ Operator: Start → Pause → Resume → Complete
   
4. ROUTING
   └─ Token complete → Evaluate edges → Route to next node
   
5. SPLIT (Parallel)
   └─ Split node → Create child tokens → Parallel work
   
6. JOIN (Assembly)
   └─ Join node → Wait for all inputs → Activate → Assemble
   
7. QC & REWORK
   └─ QC check → Pass/Fail → Rework if needed
   
8. COMPLETION
   └─ Token reaches END → Job complete if all tokens done
```

### Token States

| State | Meaning | Actions Available |
|-------|---------|-------------------|
| **ready** | Not started, ready to begin | [Start] |
| **active** | Currently working | [Pause] [Complete] |
| **paused** | Work interrupted | [Resume] [Complete] |
| **waiting** | Waiting for components (join) | (none) |
| **blocked** | Cannot proceed (upstream fail) | (none) |
| **completed** | Finished, routed to next | (none) |

### Event Types

- `spawn` - Token created
- `enter` - Token enters node
- `start` - Operator begins work
- `pause` - Work paused
- `resume` - Work resumed
- `complete` - Work finished
- `move` - Token moves to next node
- `split` - Token splits into children
- `join` - Tokens join together
- `qc_pass` - QC passed
- `qc_fail` - QC failed
- `rework` - Sent back for rework
- `scrap` - Scrapped (max rework exceeded)

---

## 👷 Work Queue System

### Operator Journey (1 Day Example)

```
08:00 - Login PWA
       └─ See "My Tasks" (tokens assigned to me)

08:05 - Open SEW BODY Queue
       └─ See: Ready (3), In Progress (1), Paused (2), Completed (4)

08:10 - Start TOTE-001
       └─ Create token_work_session → Timer starts

08:25 - Pause TOTE-001 (break)
       └─ Record pause time → Switch to TOTE-005

08:30 - Start TOTE-005
       └─ Work on different piece

08:45 - Complete TOTE-005
       └─ Calculate work time → Token routes to next node

10:00 - Resume TOTE-001
       └─ Continue from pause → Work time accumulates

10:20 - Complete TOTE-001
       └─ Total work: 35 min (15+20, pause excluded)
       └─ Token routes to next node
```

### Work Queue Features

- **Token Filtering**: Operators see only assigned tokens
- **Multi-piece Flexibility**: Can pause and switch pieces
- **Accurate Time Tracking**: Excludes pause time
- **Offline Support**: Works offline → Auto-sync when online
- **Real-time Updates**: Queue refreshes every 30 seconds

### Work Session Tracking

```sql
-- Calculate actual work time (excludes pauses)
SELECT 
    TIMESTAMPDIFF(MINUTE, started_at, completed_at) as total_minutes,
    total_pause_minutes,
    (TIMESTAMPDIFF(MINUTE, started_at, completed_at) - total_pause_minutes) as work_minutes
FROM token_work_session
WHERE id_token = ?;
```

---

## 👥 Team Management System

### Team Structure

```
team (id_team, code, name, team_category, production_mode)
  └─ team_member (id_team, id_member, role, active)
      └─ operator_availability (id_member, date, available)
```

### Team Categories

- `cutting` - Cutting team
- `sewing` - Sewing team
- `qc` - Quality control team
- `finishing` - Finishing team
- `general` - General purpose team

### Production Modes (CRITICAL for Dual Production)

- `oem` - OEM production only (batch, high volume)
- `atelier` - Atelier production only (serial, craft, traceable)
- `hybrid` - BOTH (default, most flexible)

**Why Hybrid?**
- Same operators work on both OEM and Atelier jobs
- Limited resources require flexible staffing
- Operators may work OEM 3 days, Atelier 2 days

### Team Member Roles

- `lead` - Team leader (manage team, override assignments)
- `supervisor` - Senior member (approve assignments)
- `qc` - Quality control specialist
- `member` - Regular operator
- `trainee` - New member (limited assignments)

### Team Expansion

When team is assigned → System expands to individual operators:
1. Get all active team members
2. Filter by availability (leave, absence)
3. Calculate workload (active sessions + recent assignments)
4. Pick operator with lowest load
5. Assign token to selected operator

---

## 📋 Assignment System

### Three-Layer Precedence

```
PIN (Highest Priority)
  └─ Manager hard-assigns person/team
  └─ Wins everything (overrides all)

PLAN (Pre-assignment)
  └─ Job-level plan (specific to job ticket)
  └─ Node-level plan (reusable for graph)
  └─ Wins AUTO (but loses to PIN)

AUTO (Fallback)
  └─ Skill matching (operator_skill vs node_required_skill)
  └─ Load balancing (pick lowest workload)
  └─ Availability check (exclude inactive/leave)
```

### Assignment Resolution Flow

```
Token enters node
  │
  ├─ Check PIN assignment?
  │   └─ YES → Use PIN (done)
  │
  ├─ Check PLAN assignment?
  │   ├─ Job-level plan?
  │   │   └─ YES → Use PLAN (done)
  │   └─ Node-level plan?
  │       └─ YES → Use PLAN (done)
  │
  └─ AUTO assignment
      ├─ Find eligible operators (skill match)
      ├─ Filter by availability
      ├─ Calculate workload
      └─ Pick lowest load → Assign
```

### Assignment Tables

- `token_assignment` - Token-level assignments (PIN)
- `assignment_plan_job` - Job-level pre-assignment plans
- `assignment_plan_node` - Node-level pre-assignment plans
- `node_assignment` - Node pre-assignment (for auto-assignment)

---

## 🎯 Node Pre-Assignment

### Concept

**Manager assigns operators to NODES (not individual tokens)**  
**System auto-assigns tokens when they enter assigned nodes**

### Flow

```
1. Manager assigns nodes (one-time setup)
   └─ START → Operator A
   └─ CUT → Operator B
   └─ SEW → Operator C
   └─ QC → Operator D
   └─ END → Operator E

2. Spawn 100 tokens
   └─ All tokens start at START node
   └─ All auto-assigned to Operator A

3. Operator A completes token
   └─ Token routes to CUT node
   └─ System auto-assigns to Operator B (no manager intervention!)

4. Operator B completes token
   └─ Token routes to SEW node
   └─ System auto-assigns to Operator C

... and so on for all 100 tokens × 5 nodes = 500 auto-assignments!
```

### Database Schema

```sql
CREATE TABLE node_assignment (
    id_node_assignment INT AUTO_INCREMENT PRIMARY KEY,
    id_instance INT NOT NULL,              -- FK to job_graph_instance
    id_node INT NOT NULL,                  -- FK to routing_node
    assigned_to_user_id INT NOT NULL,      -- Operator user ID
    assigned_to_name VARCHAR(100),
    assigned_by_user_id INT NOT NULL,      -- Manager user ID
    assigned_at DATETIME DEFAULT NOW(),
    UNIQUE KEY (id_instance, id_node)      -- 1 operator per node
);
```

**Business Rule:** 1 node = 1 designated operator per job

### Integration Point

**DAGRoutingService** (line 90-91):
```php
// Move token to next node
$this->tokenService->moveToken($tokenId, $toNodeId, $operatorId);

// 🔥 AUTO-ASSIGN: Check if node has pre-assigned operator
$assigned = $this->assignmentService->autoAssignTokenToNode($tokenId, $toNodeId);
```

---

## 🔄 Integration Flow

### Complete System Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. DESIGN TIME: Routing Graph Designer                     │
│    - Planner designs graph template                        │
│    - Defines nodes, edges, conditions                      │
│    - Sets assignment policies (team_hint, team_lock, auto) │
│    - Publishes graph                                       │
└────────────────────┬──────────────────────────────────────┘
                      │ Publish
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. RUNTIME: Job Ticket Creation                            │
│    - Manager creates Job Ticket                            │
│    - System creates job_graph_instance from template        │
│    - Spawns tokens (batch/piece mode)                      │
│    - Tokens start at START node                            │
└────────────────────┬──────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. RUNTIME: Manager Assignment                             │
│    - Manager assigns operators/teams to nodes              │
│    - Or uses PIN assignment (hard-assign)                   │
│    - Or uses PLAN (job/node-level plans)                   │
└────────────────────┬──────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. RUNTIME: Token Flow & Auto-Assignment                   │
│    - Token routes to next node                             │
│    - System checks: PIN > PLAN > AUTO                      │
│    - Auto-assigns token to operator                        │
└────────────────────┬──────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. RUNTIME: Work Queue (Operator Interface)                │
│    - Operator sees tokens assigned to them                 │
│    - Selects token → Start → Pause → Resume → Complete     │
│    - Token routes to next node (auto)                      │
│    - Process repeats until END node                        │
└─────────────────────────────────────────────────────────────┘
```

### Key Integration Points

1. **Graph Designer → Job Ticket**
   - Published graph → Available for job creation
   - Graph template → Instantiated as job_graph_instance

2. **Job Ticket → Token Spawn**
   - Job Ticket created → Spawn tokens
   - Batch mode: 1 token (qty = target_qty)
   - Piece mode: N tokens (qty = 1 each, unique serial)

3. **Token Spawn → Assignment**
   - Tokens spawned → Auto-assign using PIN/PLAN/AUTO
   - Node pre-assignment → Auto-assign when token enters node

4. **Assignment → Work Queue**
   - Token assigned → Appears in operator's work queue
   - Operator filters: Only see assigned tokens

5. **Work Queue → Routing**
   - Operator completes token → Token routes to next node
   - Next node → Auto-assign using node pre-assignment

---

## 🗄️ Key Database Tables

### Graph Template Tables

- `routing_graph` - Graph templates (design time)
- `routing_node` - Work stations/nodes
- `routing_edge` - Connections between nodes

### Runtime Tables

- `job_graph_instance` - Active graph instances (1 per Job Ticket)
- `node_instance` - Node execution state
- `flow_token` - Work units (tokens)
- `token_event` - State change events

### Assignment Tables

- `node_assignment` - Node pre-assignment (1 operator per node per job)
- `token_assignment` - Token-level assignments (PIN)
- `assignment_plan_job` - Job-level pre-assignment plans
- `assignment_plan_node` - Node-level pre-assignment plans

### Team Tables

- `team` - Teams (cutting, sewing, qc, etc.)
- `team_member` - Team members
- `operator_availability` - Operator availability/leave

### Work Queue Tables

- `token_work_session` - Work sessions (start/pause/resume/complete)
- `token_event` - Events (start, pause, resume, complete, etc.)

---

## 🔧 Key Services

### DAG Services

- **DAGValidationService** - Graph validation (cycles, structure, rules)
- **DAGRoutingService** - Token routing (split, join, conditional)
- **TokenLifecycleService** - Token spawn, move, complete
- **DAGRoutingService** - Graph status analysis, bottleneck detection

### Assignment Services

- **NodeAssignmentService** - Node pre-assignment, auto-assignment
- **AssignmentEngine** - PIN > PLAN > AUTO resolution
- **TeamExpansionService** - Expand team assignment to operators

### Other Services

- **SerialManagementService** - Serial number generation
- **ProductionRulesService** - Atelier/OEM validation

---

## ⚠️ Critical Business Rules

### Graph Design Rules

1. **Exactly 1 START node** - Required
2. **At least 1 END node** - Required
3. **No cycles** - Except rework/event edges (not counted in DAG validation)
4. **All nodes connected** - No orphan nodes
5. **Split nodes** - ≥2 outgoing edges
6. **Join nodes** - ≥2 incoming edges
7. **Decision nodes** - Conditional edges only
8. **Operation nodes** - Work center required

### Assignment Rules

1. **PIN > PLAN > AUTO** - Precedence order
2. **1 node = 1 operator** - Per job (node_assignment)
3. **Team expansion** - Auto-expand to individual operators
4. **Load balancing** - Pick operator with lowest workload
5. **Availability check** - Exclude inactive/leave operators

### Token Rules

1. **Idempotency** - Every event has unique UUID
2. **Event ordering** - Must follow valid state transitions
3. **Join completeness** - All inputs must arrive before activate
4. **Rework limits** - Max retries before scrap
5. **Work time accuracy** - Excludes pause time

### Work Queue Rules

1. **Operator isolation** - See only assigned tokens
2. **Multi-piece flexibility** - Can pause and switch pieces
3. **Offline support** - Works offline → Auto-sync
4. **Real-time updates** - Queue refreshes every 30 seconds

---

## 🎯 Key Design Principles

### 1. Design Time vs Runtime Separation

- **Design Time**: Graph template (reusable, static)
- **Runtime**: Graph instance + tokens (dynamic, per job)

### 2. Policy-Based Assignment

- **Don't hard-lock teams at design time**
- Use **policies/hints/constraints** instead
- Graph remains reusable across seasons/lots/tenants

### 3. Assignment Resolution Precedence

```
PIN > PLAN > NODE_DEFAULT > AUTO
```

1. **PIN** (Manager hard-assigns) → Wins everything
2. **PLAN** (Pre-assignment plan) → Wins AUTO
3. **NODE_DEFAULT** (Policy from Designer) → Used as default/constraint
4. **AUTO** (work_center + team_category + load balance) → Fallback

### 4. Node-Level Assignment

- Manager assigns **nodes** (not tokens)
- System auto-assigns **tokens** when they enter nodes
- 1 assignment → Handles 100+ token flows automatically

### 5. Dual Production Support

- **OEM**: Batch mode (1 token = 50 pieces)
- **Atelier**: Piece mode (1 token = 1 piece, unique serial)
- **Hybrid teams**: Can serve both production types

---

## 📊 Data Flow Examples

### Example 1: Simple Sequential Flow

```
Job Ticket: TOTE-001 (10 pieces, piece mode)
Graph: TOTE_PRODUCTION_V1

1. Spawn: 10 tokens created (TOTE-001-01 to TOTE-001-10)
2. Assignment: All tokens assigned to START operator
3. Work: Operator completes START → Tokens route to CUT
4. Auto-assign: Tokens auto-assigned to CUT operator
5. Work: Operator completes CUT → Tokens route to SEW
6. Auto-assign: Tokens auto-assigned to SEW operator
7. ... continues until END
```

### Example 2: Split/Join Flow

```
Token: TOTE-001 (1 bag)
Node: CUT (split node)

1. Token completes CUT
2. Split: Creates 2 child tokens
   - TOTE-001-BODY → SEW_BODY node
   - TOTE-001-STRAP → SEW_STRAP node
3. Parallel work: Both tokens work simultaneously
4. Join: Both tokens arrive at ASSEMBLY node
5. Assembly: Operator assembles → Creates TOTE-001-FINAL
6. Continue: TOTE-001-FINAL routes to QC → END
```

### Example 3: QC & Rework Flow

```
Token: TOTE-001 at QC node

1. QC check: Inspector marks "Fail"
2. Rework: Token routes back to SEW node (rework edge)
3. Work: Operator fixes issue
4. Complete: Token routes back to QC
5. QC check: Inspector marks "Pass"
6. Continue: Token routes to END
```

---

## 🔍 Query Patterns

### Get Token Current Status

```sql
SELECT 
    ft.serial_number,
    ft.status,
    rn.name as current_node_name,
    ni.status as node_status
FROM flow_token ft
JOIN routing_node rn ON rn.id_node = ft.current_node_id
JOIN node_instance ni ON ni.node_id = rn.id_node
WHERE ft.id_token = ?;
```

### Get Work Queue (Operator View)

```sql
SELECT 
    t.*,
    rn.node_name,
    s.started_at,
    s.paused_at
FROM flow_token t
JOIN routing_node rn ON rn.id_node = t.current_node_id
LEFT JOIN token_assignment ta 
    ON ta.id_token = t.id_token 
    AND ta.assigned_to_user_id = ?
LEFT JOIN token_work_session s 
    ON s.id_token = t.id_token 
    AND s.operator_user_id = ?
WHERE (ta.id_assignment IS NOT NULL OR s.id_session IS NOT NULL)
  AND t.status IN ('active', 'paused', 'ready')
ORDER BY 
    CASE WHEN s.operator_user_id = ? THEN 0 ELSE 1 END,  -- My work first
    t.serial_number;
```

### Get Node Assignments (Manager View)

```sql
SELECT 
    rn.node_name,
    rn.node_code,
    COUNT(DISTINCT t.id_token) as token_count,
    na.assigned_to_name,
    na.assigned_at
FROM routing_node rn
LEFT JOIN node_assignment na 
    ON na.id_node = rn.id_node 
    AND na.id_instance = ?
LEFT JOIN flow_token t 
    ON t.current_node_id = rn.id_node 
    AND t.id_instance = ?
WHERE rn.id_graph = ?
GROUP BY rn.id_node;
```

---

## ✅ Summary

### System Architecture

- **3-Layer Model**: Template → Instance → Token
- **Design Time**: Graph Designer (static templates)
- **Runtime**: Job execution (dynamic instances + tokens)

### Key Flows

1. **Graph Design** → Publish → Job Ticket → Instance
2. **Token Spawn** → Assignment → Work Queue → Routing
3. **Work Execution** → Complete → Route → Next Node

### Critical Systems

1. **DAG Routing** - Graph-based workflow
2. **Work Queue** - Operator interface
3. **Team Management** - Team organization
4. **Assignment** - PIN > PLAN > AUTO
5. **Node Pre-Assignment** - Auto-assignment system

### Design Principles

- Policy-based assignment (not hard-locked)
- Node-level assignment (not token-level)
- Dual production support (OEM + Atelier)
- Offline-capable work queue
- Accurate time tracking (excludes pauses)

---

**Last Updated:** November 10, 2025  
**Status:** ✅ Complete Understanding - Ready for Full Development  
**Next:** Awaiting user's vision for Routing Graph Designer Full Development

