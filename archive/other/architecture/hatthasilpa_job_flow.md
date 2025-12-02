# Hatthasilpa Job Flow Overview

**Generated:** 2025-12-09  
**Purpose:** High-level flow diagram and sequence documentation for Hatthasilpa job lifecycle

---

## Overview

Hatthasilpa jobs are DAG-based production jobs for Atelier (luxury, flexible) production. The system uses a binding-first workflow where jobs are created from product-graph bindings, and tokens flow through DAG nodes representing production steps.

---

## High-Level Flow

### Job Creation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Job Creation (Planned)                                       │
├─────────────────────────────────────────────────────────────────┤
│ API: hatthasilpa_jobs_api.php?action=create                     │
│                                                                  │
│ Steps:                                                           │
│  1. Validate with ProductionRulesService                        │
│  2. Create job_ticket (status='planned')                        │
│  3. Create job_graph_instance                                   │
│  4. Create node_instances                                       │
│  5. Pre-generate serials                                        │
│  6. DO NOT spawn tokens                                         │
│                                                                  │
│ Service: JobCreationService::createFromBindingWithoutTokens()   │
│ Tables: job_ticket, job_graph_instance, node_instance           │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Assignment Planning (Optional)                               │
├─────────────────────────────────────────────────────────────────┤
│ UI: Plans tab                                                   │
│ API: assignment_plan_api.php                                    │
│                                                                  │
│ Steps:                                                           │
│  1. Create assignment_plan_job                                  │
│  2. Create assignment_plan_node                                 │
│  3. Preview assignments                                         │
│                                                                  │
│ Tables: assignment_plan_job, assignment_plan_node               │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. Job Start (Spawn Tokens)                                     │
├─────────────────────────────────────────────────────────────────┤
│ API: hatthasilpa_jobs_api.php?action=start_job                  │
│                                                                  │
│ Steps:                                                           │
│  1. Validate job.status = 'planned' or 'cancelled'             │
│  2. Update job_ticket.status = 'in_progress'                    │
│  3. Call dag_token_api.php?action=token_spawn                   │
│  4. Auto-route tokens from START → first operation node         │
│  5. Auto-assign tokens using plans (if exists)                  │
│                                                                  │
│ Internal Call: internalDagTokenPost('token_spawn', ...)         │
│ Service: TokenLifecycleService::spawnTokens()                   │
│ Tables: flow_token, token_event, token_assignment               │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. Token Execution (Work Queue)                                 │
├─────────────────────────────────────────────────────────────────┤
│ UI: Work Queue page                                             │
│ API: dag_token_api.php (start_token, pause_token, etc.)        │
│                                                                  │
│ Steps:                                                           │
│  1. Operator views work queue                                   │
│  2. Operator starts token (status='active')                     │
│  3. Operator completes work at node                             │
│  4. Token moves to next node (via edge routing)                 │
│  5. Repeat until END node                                       │
│                                                                  │
│ Services:                                                        │
│  - TokenExecutionService::runWithLock()                         │
│  - TokenWorkSessionService::startToken(), completeToken()       │
│  - DAGRoutingService::advanceToken()                            │
│ Tables: flow_token, token_work_session, token_event             │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. Job Completion                                               │
├─────────────────────────────────────────────────────────────────┤
│ API: hatthasilpa_jobs_api.php?action=complete_job               │
│                                                                  │
│ Steps:                                                           │
│  1. All tokens reached END node                                 │
│  2. Update job_ticket.status = 'completed'                      │
│  3. Cancel all remaining tokens                                 │
│                                                                  │
│ Tables: job_ticket, flow_token                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Sequence Diagrams

### Job Creation Sequence

```
User → hatthasilpa_jobs_api.php
  │
  ├─→ ProductionRulesService::validate()
  │   └─→ Validates: qty, binding_id, id_mo
  │
  ├─→ JobCreationService::createFromBindingWithoutTokens()
  │   ├─→ GraphInstanceService::createInstance()
  │   │   └─→ INSERT job_graph_instance
  │   │
  │   ├─→ GraphInstanceService::createNodeInstances()
  │   │   └─→ INSERT node_instance (for each routing_node)
  │   │
  │   ├─→ UnifiedSerialService::generateSerials()
  │   │   ├─→ INSERT job_ticket_serial (tenant DB)
  │   │   └─→ INSERT serial_registry (core DB)
  │   │
  │   └─→ Returns: {job_ticket_id, graph_instance_id, tokens_spawned: 0}
  │
  └─→ Response: {ok: true, data: {job_ticket_id, ticket_code, tokens_spawned: 0}}
```

### Token Spawn Sequence

```
hatthasilpa_jobs_api.php → dag_token_api.php?action=token_spawn
  │
  ├─→ TokenLifecycleService::spawnTokens()
  │   ├─→ GraphInstanceService::getStartNode()
  │   │   └─→ SELECT routing_node WHERE node_type='start'
  │   │
  │   ├─→ FOR each target_qty:
  │   │   ├─→ INSERT flow_token
  │   │   │   ├─→ status='ready'
  │   │   │   ├─→ current_node_id=START node
  │   │   │   └─→ serial_code (from pre-generated serials)
  │   │   │
  │   │   ├─→ INSERT token_event
  │   │   │   └─→ event_type='spawn'
  │   │   │
  │   │   └─→ DAGRoutingService::advanceFromStart()
  │   │       └─→ Move token from START → first operation node
  │   │
  │   └─→ HatthasilpaAssignmentService::assignAuto()
  │       └─→ INSERT token_assignment (if plans exist)
  │
  └─→ Response: {ok: true, data: {tokens_spawned: N, token_ids: [...]}}
```

### Token Execution Sequence

```
Operator → Work Queue UI
  │
  ├─→ dag_token_api.php?action=get_work_queue
  │   └─→ Returns: List of ready tokens assigned to operator
  │
  ├─→ dag_token_api.php?action=start_token
  │   ├─→ TokenExecutionService::runWithLock()
  │   │   ├─→ SELECT flow_token FOR UPDATE
  │   │   ├─→ Validate: status='ready', assigned to operator
  │   │   │
  │   │   ├─→ TokenWorkSessionService::startToken()
  │   │   │   ├─→ INSERT token_work_session
  │   │   │   │   └─→ status='active', started_at=NOW()
  │   │   │   │
  │   │   │   └─→ UPDATE flow_token
  │   │   │       └─→ status='active'
  │   │   │
  │   │   └─→ INSERT token_event
  │   │       └─→ event_type='start'
  │   │
  │   └─→ Response: {ok: true, data: {token_id, status: 'active'}}
  │
  ├─→ [Operator works on task...]
  │
  ├─→ dag_token_api.php?action=complete_token
  │   ├─→ TokenExecutionService::runWithLock()
  │   │   ├─→ TokenWorkSessionService::completeToken()
  │   │   │   ├─→ UPDATE token_work_session
  │   │   │   │   └─→ status='completed', completed_at=NOW()
  │   │   │   │
  │   │   │   └─→ UPDATE flow_token
  │   │   │       └─→ status='completed'
  │   │   │
  │   │   ├─→ DAGRoutingService::advanceToken()
  │   │   │   ├─→ Find next node via routing_edge
  │   │   │   ├─→ IF next node exists:
  │   │   │   │   └─→ UPDATE flow_token
  │   │   │   │       ├─→ current_node_id=next_node_id
  │   │   │   │       └─→ status='ready'
  │   │   │   │
  │   │   │   └─→ ELSE (END node):
  │   │   │       └─→ UPDATE flow_token
  │   │   │           └─→ status='finished'
  │   │   │
  │   │   ├─→ INSERT token_event
  │   │   │   └─→ event_type='complete'
  │   │   │
  │   │   └─→ HatthasilpaAssignmentService::assignAuto()
  │   │       └─→ Auto-assign token at next node (if needed)
  │   │
  │   └─→ Response: {ok: true, data: {token_id, next_node_id, completed}}
  │
  └─→ [Repeat until END node]
```

---

## Key Services

### JobCreationService
- **Purpose:** Unified service for creating DAG jobs
- **Methods:**
  - `createFromBinding()`: Create job with tokens spawned
  - `createFromBindingWithoutTokens()`: Create job without tokens (planned)
- **Dependencies:**
  - `GraphInstanceService`: Creates graph and node instances
  - `TokenLifecycleService`: Spawns tokens
  - `UnifiedSerialService`: Generates serial numbers

### TokenLifecycleService
- **Purpose:** Manage token creation, movement, and completion
- **Methods:**
  - `spawnTokens()`: Spawn tokens for job instance
  - `moveToken()`: Move token to next node
  - `completeToken()`: Complete token work at node
- **Dependencies:**
  - `DAGRoutingService`: Routes tokens through graph
  - `HatthasilpaAssignmentService`: Assigns tokens to operators

### TokenExecutionService
- **Purpose:** Execute token work with locking and idempotency
- **Methods:**
  - `runWithLock()`: Execute token operation with row lock
- **Features:**
  - Row-level locking (`SELECT ... FOR UPDATE`)
  - Idempotency key support
  - Transaction management

### TokenWorkSessionService
- **Purpose:** Manage operator work sessions
- **Methods:**
  - `startToken()`: Start work session for token
  - `pauseToken()`: Pause work session
  - `resumeToken()`: Resume paused session
  - `completeToken()`: Complete work session
- **Tables:**
  - `token_work_session`: Tracks active work sessions

### DAGRoutingService
- **Purpose:** Route tokens through DAG graph
- **Methods:**
  - `advanceToken()`: Move token to next node
  - `advanceFromStart()`: Move token from START node
  - `handleQCResult()`: Route based on QC pass/fail
- **Features:**
  - Conditional edge routing (QC pass/fail)
  - Rework loop support
  - Parallel execution support (split/join nodes)

### HatthasilpaAssignmentService
- **Purpose:** Manage token assignments to operators
- **Methods:**
  - `assignAuto()`: Auto-assign tokens based on plans
  - `assignManual()`: Manual assignment by manager
- **Features:**
  - Soft mode (respects existing manager assignments)
  - Plan-based assignment (if plans exist)
  - Load balancing (lowest workload first)

---

## Database Tables

### Core Tables

#### job_ticket
- **Purpose:** Main job ticket record
- **Key Columns:**
  - `id_job_ticket`: Primary Key
  - `ticket_code`: Unique ticket code (e.g., ATELIER-20251209-0001)
  - `id_product`: FK to product
  - `id_routing_graph`: FK to routing_graph
  - `graph_instance_id`: FK to job_graph_instance
  - `production_type`: 'hatthasilpa' or 'classic'
  - `status`: 'planned', 'in_progress', 'paused', 'completed', 'cancelled'
  - `target_qty`: Target quantity
  - `due_date`: Due date
  - `started_at`, `completed_at`: Timestamps

#### flow_token
- **Purpose:** DAG token (represents one unit of work)
- **Key Columns:**
  - `id_token`: Primary Key
  - `id_instance`: FK to job_graph_instance
  - `serial_code`: Serial number (from pre-generated serials)
  - `current_node_id`: FK to routing_node (current position in graph)
  - `status`: 'ready', 'active', 'waiting', 'paused', 'completed', 'finished', 'cancelled'
  - `spawned_at`, `completed_at`: Timestamps
- **Critical Invariant:**
  - `current_node_id` references `routing_node.id_node` (NOT `node_instance.id_node_instance`)

#### job_graph_instance
- **Purpose:** Instance of routing graph for a job
- **Key Columns:**
  - `id_instance`: Primary Key
  - `id_job_ticket`: FK to job_ticket
  - `id_graph`: FK to routing_graph
  - `status`: 'active', 'archived'
  - `created_at`, `archived_at`: Timestamps

#### node_instance
- **Purpose:** Instance of routing node for a graph instance
- **Key Columns:**
  - `id_node_instance`: Primary Key
  - `id_instance`: FK to job_graph_instance
  - `id_node`: FK to routing_node
  - `status`: Node instance status
- **Note:** One node_instance per routing_node per graph_instance

#### token_work_session
- **Purpose:** Operator work session for a token
- **Key Columns:**
  - `id_session`: Primary Key
  - `id_token`: FK to flow_token
  - `operator_user_id`: FK to account (core DB)
  - `status`: 'active', 'paused', 'completed', 'cancelled'
  - `started_at`, `paused_at`, `completed_at`: Timestamps

#### token_assignment
- **Purpose:** Token assignment to operator or team
- **Key Columns:**
  - `id_assignment`: Primary Key
  - `id_token`: FK to flow_token (unique per token)
  - `assigned_to_type`: 'operator' or 'team'
  - `assigned_to_id`: Operator or team ID
  - `method`: 'PIN', 'PLAN', 'AUTO', 'MANUAL', 'REASSIGN', 'HELP'
  - `status`: 'pending', 'accepted', 'rejected'
  - `created_at`, `accepted_at`: Timestamps

#### token_event
- **Purpose:** Event log for token lifecycle
- **Key Columns:**
  - `id_event`: Primary Key
  - `id_token`: FK to flow_token
  - `event_type`: 'spawn', 'start', 'pause', 'resume', 'complete', 'move', 'scrap'
  - `from_node_id`, `to_node_id`: Node transitions
  - `operator_user_id`: Operator who triggered event
  - `event_time`: Timestamp

---

## API Endpoints

### Job Management

#### POST hatthasilpa_jobs_api.php?action=create
- **Purpose:** Create planned job (no tokens)
- **Parameters:**
  - `job_name`: Job name
  - `id_product`: Product ID
  - `target_qty`: Target quantity
  - `binding_id`: Product-graph binding ID
  - `due_date`: Due date (optional)
  - `id_mo`: Manufacturing order ID (optional)
- **Response:**
  ```json
  {
    "ok": true,
    "data": {
      "job_ticket_id": 123,
      "ticket_code": "ATELIER-20251209-0001",
      "graph_instance_id": 456,
      "tokens_spawned": 0
    }
  }
  ```

#### POST hatthasilpa_jobs_api.php?action=create_and_start
- **Purpose:** Create and start job (1-click workflow)
- **Parameters:** Same as `create`
- **Response:**
  ```json
  {
    "ok": true,
    "data": {
      "job_ticket_id": 123,
      "ticket_code": "ATELIER-20251209-0001",
      "graph_instance_id": 456,
      "tokens_spawned": 10
    }
  }
  ```

#### POST hatthasilpa_jobs_api.php?action=start_job
- **Purpose:** Start planned job (spawn tokens)
- **Parameters:**
  - `id_job_ticket`: Job ticket ID
- **Response:**
  ```json
  {
    "ok": true,
    "data": {
      "job_ticket_id": 123,
      "job_status": "in_progress",
      "spawn": {
        "tokens_spawned": 10,
        "token_ids": [789, 790, ...]
      }
    }
  }
  ```

### Token Management

#### POST dag_token_api.php?action=token_spawn
- **Purpose:** Spawn tokens for job instance
- **Parameters:**
  - `ticket_id`: Job ticket ID
- **Response:**
  ```json
  {
    "ok": true,
    "data": {
      "tokens_spawned": 10,
      "token_ids": [789, 790, ...]
    }
  }
  ```

#### POST dag_token_api.php?action=get_work_queue
- **Purpose:** Get work queue for operator
- **Response:**
  ```json
  {
    "ok": true,
    "data": {
      "ready": [...],
      "active": [...],
      "paused": [...]
    }
  }
  ```

#### POST dag_token_api.php?action=start_token
- **Purpose:** Start token work (operator action)
- **Parameters:**
  - `token_id`: Token ID
- **Response:**
  ```json
  {
    "ok": true,
    "data": {
      "token_id": 789,
      "status": "active"
    }
  }
  ```

#### POST dag_token_api.php?action=complete_token
- **Purpose:** Complete token work at node
- **Parameters:**
  - `token_id`: Token ID
- **Response:**
  ```json
  {
    "ok": true,
    "data": {
      "token_id": 789,
      "next_node_id": 456,
      "completed": false
    }
  }
  ```

---

## Workflow Patterns

### 1-Click Workflow (create_and_start)
- **Use Case:** Quick job creation for immediate production
- **Flow:**
  1. Create job_ticket
  2. Create job_graph_instance
  3. Create node_instances
  4. Pre-generate serials
  5. Spawn tokens at START node
  6. Auto-route tokens from START → first operation node
  7. Auto-assign tokens (if plans exist)
  8. Status: `in_progress`

### Planned Workflow (create → start_job)
- **Use Case:** Planned jobs with assignment planning
- **Flow:**
  1. Create job_ticket (status: `planned`)
  2. Create job_graph_instance
  3. Create node_instances
  4. Pre-generate serials
  5. [Plan assignments via Plans tab]
  6. Start job (spawn tokens with plans)
  7. Status: `in_progress`

### Token Execution Pattern
1. **Operator Views Work Queue:**
   - `dag_token_api.php?action=get_work_queue`
   - Returns: List of ready tokens assigned to operator

2. **Operator Starts Token:**
   - `dag_token_api.php?action=start_token`
   - Creates `token_work_session` (status: `active`)
   - Updates `flow_token` (status: `active`)

3. **Operator Works on Task:**
   - [Physical work happens]

4. **Operator Completes Token:**
   - `dag_token_api.php?action=complete_token`
   - Completes `token_work_session` (status: `completed`)
   - Advances `flow_token` to next node
   - Auto-assigns token at next node (if needed)

5. **Repeat Until END Node:**
   - When token reaches END node: `flow_token.status='finished'`
   - Job completion checked: All tokens finished → `job_ticket.status='completed'`

---

## Critical Invariants

### Token/Node Invariant
- **Rule:** `flow_token.current_node_id` must reference `routing_node.id_node` (NOT `node_instance.id_node_instance`)
- **Reason:** Tokens navigate the graph topology (routing_node), not instance-specific data (node_instance)
- **Enforcement:** All token queries must JOIN `routing_node` on `current_node_id`

### Job/Token Boundary
- **Rule:** `hatthasilpa_jobs_api.php` manages job-level planning only; token operations via `dag_token_api.php`
- **Reason:** Separation of concerns (job planning vs token execution)
- **Enforcement:** `hatthasilpa_jobs_api.php` never directly touches `flow_token` (always via `dag_token_api.php`)

### Idempotency Requirement
- **Rule:** All state-changing operations require idempotency key
- **Reason:** Prevents duplicate operations (e.g., double-spawn tokens)
- **Enforcement:** `Idempotency::guard()` before state changes, `Idempotency::store()` after success

### Assignment Uniqueness
- **Rule:** One token can have only one active assignment
- **Reason:** Prevents conflicting assignments
- **Enforcement:** Unique index on `(id_token, status)` in `token_assignment`

### Session Uniqueness
- **Rule:** One token can have only one active work session
- **Reason:** Prevents concurrent work on same token
- **Enforcement:** Row-level locking (`SELECT ... FOR UPDATE`) in `TokenExecutionService::runWithLock()`

---

## Error Handling

### Job Creation Errors
- **Validation Error:** 400 Bad Request with `app_code: 'HATTHASILPA_JOBS_400_VALIDATION'`
- **Business Rules Error:** 400 Bad Request with `app_code: 'HATTHASILPA_JOBS_400_BUSINESS_RULES'`
- **Database Error:** 500 Internal Server Error with `app_code: 'HATTHASILPA_JOBS_500_CREATE_FAILED'`

### Token Spawn Errors
- **Missing Graph:** 404 Not Found with `app_code: 'DAG_404_GRAPH'`
- **Invalid Status:** 400 Bad Request with `app_code: 'DAG_400_INVALID_STATUS'`
- **Spawn Failure:** Soft fail (log warning, continue) - existing tokens may still work

### Token Execution Errors
- **Invalid Status:** 400 Bad Request with `app_code: 'DAG_400_INVALID_STATUS'`
- **Permission Denied:** 403 Forbidden with `app_code: 'DAG_403_FORBIDDEN'`
- **Lock Timeout:** 409 Conflict with `app_code: 'DAG_409_LOCK_TIMEOUT'`

---

## Summary

### Key Takeaways

1. **Binding-First Workflow:**
   - Jobs created from `product_graph_binding` (not templates)
   - Binding = Product + Graph + BOM (optional)

2. **Two-Phase Creation:**
   - Phase 1: Create planned job (no tokens)
   - Phase 2: Start job (spawn tokens)

3. **Token-Based Execution:**
   - Each token = one unit of work
   - Tokens flow through DAG graph (routing_node)
   - Operators work on tokens via Work Queue

4. **Service Layer Architecture:**
   - `JobCreationService`: Job creation
   - `TokenLifecycleService`: Token spawn/move/complete
   - `TokenExecutionService`: Token work execution
   - `DAGRoutingService`: Graph routing logic
   - `HatthasilpaAssignmentService`: Token assignments

5. **Critical Boundaries:**
   - Job API (`hatthasilpa_jobs_api.php`) ≠ Token API (`dag_token_api.php`)
   - Token navigation uses `routing_node` (not `node_instance`)
   - All state changes require idempotency keys

---

## Related Documentation

- **API Inventory:** `docs/erp_api_inventory.md`
- **Seed Inventory:** `docs/erp_seed_inventory.md`
- **Legacy Routing:** `docs/erp_legacy_routing.md`
- **DAG Master Guide:** `docs/dag/DAG_MASTER_GUIDE.md`
- **Assignment Plan:** `docs/dag/HATTHASILPA_ASSIGNMENT_PLAN.md`

