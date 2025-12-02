# SuperDAG Architecture Map

**Status:** Active Documentation  
**Date:** 2025-01-XX (Last Updated)  
**Purpose:** Complete architecture map of SuperDAG execution engine based on actual codebase

> **⚠️ IMPORTANT:** This document describes **what the code actually does**, not what it should do. All references are to actual files, classes, and methods in the codebase.

---

## Table of Contents

1. [Layer Overview](#layer-overview)
2. [API Layer](#api-layer)
3. [Service Layer](#service-layer)
4. [DAG Engine Layer](#dag-engine-layer)
5. [UI Integration Layer](#ui-integration-layer)
6. [Database / Persistence Layer](#database--persistence-layer)
7. [Interaction Map](#interaction-map)
8. [Node Type & Behavior Semantics](#node-type--behavior-semantics)

---

## Layer Overview

SuperDAG execution engine is organized into 6 main layers:

```
┌─────────────────────────────────────────────────────────┐
│ API Layer                                                │
│ - dag_routing_api.php                                   │
│ - dag_token_api.php                                     │
│ - job_ticket_dag.php                                    │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Service Layer                                             │
│ - DAGRoutingService (uses TimeHelper - Task 20.2.3)    │
│ - TokenLifecycleService (uses TimeHelper - Task 20.2.2) │
│ - TokenWorkSessionService (uses TimeHelper - Task 20.2.2)│
│ - AssignmentResolverService                              │
│ - WorkSessionTimeEngine (uses TimeHelper - Task 20.2.3) │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ DAG Engine Layer                                          │
│ - DagExecutionService                                    │
│ - BehaviorExecutionService                               │
│ - ParallelMachineCoordinator                             │
│ - MachineAllocationService                               │
│ - MachineRegistry                                        │
│ - NodeTypeRegistry                                       │
│ - EtaEngine (Task 20: ETA/SLA calculation)               │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Helper / Utility Layer                                    │
│ - TimeHelper (PHP - canonical timezone - Task 20.2)     │
│ - GraphTimezone (JS - canonical timezone - Task 20.2)    │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ UI Integration Layer                                      │
│ - graph_designer.js (UI orchestrator - Task 19.24.16)  │
│ - GraphHistoryManager.js (history engine)                │
│ - GraphIOLayer.js (snapshot marshalling)                 │
│ - GraphActionLayer.js (graph mutations)                  │
│ - GraphSaver.js                                          │
│ - ConditionalEdgeEditor.js (Task 19.1, 19.2)            │
│ - GraphValidator.js (validation UI bridge)               │
│ - GraphTimezone.js (timezone normalization - Task 20.2) │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Database / Persistence Layer                              │
│ - routing_graph                                          │
│ - routing_node (sla_minutes, estimated_minutes - Task 20)│
│ - routing_edge                                           │
│ - flow_token (start_at, actual_duration_ms - Task 19.5) │
│ - machine                                                │
│ - token_event (duration_ms - Task 19.5)                  │
│ - token_work_session (all timestamps use canonical TZ)   │
└─────────────────────────────────────────────────────────┘
```

---

## API Layer

### File: `source/dag_routing_api.php`

**Purpose:** REST API endpoints for graph management and node operations

**Key Actions:**
- `graph_list` - List all graphs
- `graph_create` - Create new graph
- `graph_update` - Update graph metadata
- `graph_delete` - Delete graph
- `node_create` - Create new node
- `node_update` - Update node properties
- `node_delete` - Delete node
- `edge_create` - Create edge between nodes
- `edge_update` - Update edge properties
- `edge_delete` - Delete edge
- `loadGraphWithVersion` - Load graph with all nodes and edges
- `validateGraphStructure` - Validate graph topology

**Key Validations (from code):**
- START node: Must have exactly 1 (validated in `validateGraphStructure`)
- FINISH/END node: Must have at least 1 (validated in `validateGraphStructure`)
- Parallel split nodes: Must have 2+ outgoing edges (validated in `validateGraphStructure`)
- Merge nodes: Must have 2+ incoming edges (validated in `validateGraphStructure`)
- Legacy node types (`split`, `join`, `wait`): Rejected in `node_create` and `node_update` (Task 17.2)

**Node Configuration Fields (from code):**
- `behavior_code` (VARCHAR) - Behavior code (CUT, STITCH, EDGE, QC_SINGLE, etc.)
- `behavior_version` (INT) - Behavior version
- `execution_mode` (VARCHAR) - Execution mode (BATCH, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE)
- `derived_node_type` (VARCHAR) - Derived as `${behavior_code}:${execution_mode}`
- `is_parallel_split` (TINYINT) - Flag: node starts parallel branches
- `is_merge_node` (TINYINT) - Flag: node merges parallel branches
- `merge_mode` (VARCHAR) - Merge semantics (deprecated, use `parallel_merge_policy`)
- `parallel_merge_policy` (ENUM) - Merge policy: ALL, ANY, AT_LEAST, TIMEOUT_FAIL
- `parallel_merge_timeout_seconds` (INT NULL) - Timeout for TIMEOUT_FAIL policy
- `parallel_merge_at_least_count` (INT NULL) - Minimum count for AT_LEAST policy
- `machine_binding_mode` (VARCHAR) - NONE, BY_WORK_CENTER, EXPLICIT
- `machine_codes` (TEXT) - Comma-separated or JSON list of machine codes
- `work_center_code` (VARCHAR) - Work center code (FK to work_center.code)
- `qc_policy` (JSON) - QC policy configuration
- `form_schema_json` (JSON) - Form schema for QC/Decision nodes

**Edge Configuration Fields (from code):**
- `edge_type` (ENUM) - normal, rework, conditional
- `edge_condition` (JSON) - Condition for conditional edges (Task 18, 19.1, 19.2)
  - Unified condition model: `{ type: "token_property"|"job_property"|"node_property"|"expression", property: "...", operator: "...", value: ... }`
  - Multi-group format: `{ type: "or", groups: [{ type: "and", conditions: [...] }] }`
  - Single group: `{ type: "and", conditions: [...] }`
  - Default route: `{ type: "expression", expression: "true" }`
- `condition_rule` (JSON) - Alternative condition format (used in decision nodes)
- `edge_label` (VARCHAR) - Display label
- `priority` (INT) - Evaluation order for decision nodes
- `is_default` (TINYINT) - Default edge flag

---

### File: `source/dag_token_api.php`

**Purpose:** Token lifecycle API endpoints  
**Task 20.2.2:** Uses `TimeHelper` via service layer for canonical timezone normalization

**Key Actions:**
- `spawn` - Spawn tokens for job instance
- `start` - Start token execution at node
- `complete` - Complete token at node (uses TimeHelper via TokenLifecycleService)
- `pause` - Pause token execution
- `resume` - Resume token execution
- `cancel` - Cancel token (qc_fail, redesign, permanent)

---

### File: `source/job_ticket_dag.php`

**Purpose:** Job ticket DAG execution API (Job Ticket V2)

**Key Actions:**
- `start` - Start job ticket execution
- `complete` - Complete node execution
- `pause` - Pause execution
- `resume` - Resume execution
- `fail` - Fail node execution

---

## Service Layer

### Class: `BGERP\Service\DAGRoutingService`

**File:** `source/BGERP/Service/DAGRoutingService.php`  
**Purpose:** Core token routing logic, handles split/join, conditional routing, machine allocation

**Key Methods:**

#### `routeToken(int $tokenId, ?int $operatorId = null): array`
- **Entry point** for token routing after work completion
- **Flow:**
  1. Fetch token and current node
  2. Check subgraph exit (Phase 1.7)
  3. Release machine if leaving machine-bound node (Task 18)
  4. Check if parallel split node → `handleParallelSplit()`
  5. Check if merge node → `handleMergeNode()`
  6. Get outgoing edges
  7. Route based on edge count:
     - 0 edges → Complete token (FINISH node)
     - 1 edge → Auto-route to next node
     - 2+ edges → `selectNextNode()` (evaluate conditions)

#### `routeToNode(int $tokenId, array $edge, ?int $operatorId = null): array`
- Routes token to specific node via edge
- **Checks:**
  - Concurrency limit (priority) → WIP limit
  - Machine allocation (Task 18)
  - Production mode transition (Phase 2C)
- **Actions:**
  - Move token to target node
  - Set status to 'ready' for operation/QC nodes
  - Resolve assignment
  - Auto-assign token to node

#### `selectNextNode(array $edges, array $token, ?int $operatorId = null): array`
- **Priority order:**
  1. Conditional edges (evaluate conditions)
  2. Normal edges
  3. First edge (fallback)
- **Condition evaluation:** Calls `evaluateCondition()`

#### `evaluateCondition(array $condition, array $token, ?array $job = null, ?array $node = null): bool`
- **Location:** `source/BGERP/Service/DAGRoutingService.php:820`
- **Supported condition types (from code):**
  - `qty_threshold` - Token quantity comparison
  - `token_property` - Token property comparison (qty, priority, serial_number, status, rework_count, metadata)
  - `job_property` - Job property comparison (target_qty, process_mode, work_center_id, production_type)
  - `node_property` - Node property comparison (current_load, node_type, node_code)
  - `expression` - Simple expression parser (e.g., "token.qty > 10 AND token.priority = 'high'")
- **Operators:** `>`, `>=`, `<`, `<=`, `==`, `!=`, `IN`, `NOT_IN`, `CONTAINS`, `STARTS_WITH`

#### `handleParallelSplit(int $tokenId, array $node, ?int $operatorId = null): array`
- **Location:** `source/BGERP/Service/DAGRoutingService.php:2821`
- **Flow:**
  1. Get outgoing edges (must be 2+)
  2. Generate `parallel_group_id` (uses parent token ID)
  3. Create split config for each branch
  4. Call `TokenLifecycleService::splitToken()` to create child tokens
  5. Notify `ParallelMachineCoordinator::onSplit()` (Task 18.1)
  6. Log parallel split event

#### `handleMergeNode(int $tokenId, array $node, ?int $operatorId = null): array`
- **Location:** `source/BGERP/Service/DAGRoutingService.php:2885`
- **Flow:**
  1. Get `parallel_group_id` from token
  2. Get merge policy from node (`parallel_merge_policy`, `parallel_merge_at_least_count`, `parallel_merge_timeout_seconds`)
  3. Call `ParallelMachineCoordinator::canMerge()` to check readiness
  4. If deadlock → Mark group as stuck
  5. If not ready → Set token to 'waiting', log merge_waiting event
  6. If ready → Move token through merge node, continue routing

#### `handleQCResult(int $tokenId, int $nodeId, bool $qcPass, ?string $reason = null, ?int $operatorId = null): array`
- **Location:** `source/BGERP/Service/DAGRoutingService.php:336`
- **Flow:**
  1. Load QC policy from node (`qc_policy` JSON field)
  2. If QC Pass → Find pass edge (edge_condition with qc='pass' or normal edge)
  3. If QC Fail → `handleQCFailWithPolicy()`
  4. Route token accordingly

---

### Class: `BGERP\Service\TokenLifecycleService`

**File:** `source/BGERP/Service/TokenLifecycleService.php`  
**Purpose:** Token creation, movement, and completion

**Key Methods:**

#### `spawnTokens(int $instanceId, int $targetQty, string $processMode, array $serials = []): array`
- **Location:** `source/BGERP/Service/TokenLifecycleService.php:41`
- **Idempotency:** Skips if instance has live tokens (ready/active/waiting/paused)
- **Process modes:**
  - `batch` → 1 token for entire batch
  - `piece` → 1 token per piece (uses serials from `job_ticket_serial`)
- **Flow:**
  1. Check idempotency (mixed state guard)
  2. Normalize process mode
  3. Get start node
  4. Create token(s) with status 'ready'
  5. Create spawn + enter events
  6. Auto-assign on spawn

#### `moveToken(int $tokenId, int $toNodeId, ?int $operatorId = null): bool`
- **Location:** `source/BGERP/Service/TokenLifecycleService.php:334`
- **Actions:**
  - Update `flow_token.current_node_id`
  - Create 'move' event
  - Create 'enter' event at new node

#### `completeToken(int $tokenId, ?int $operatorId = null): bool`
- **Location:** `source/BGERP/Service/TokenLifecycleService.php:376`
- **Actions:**
  - Set status to 'completed'
  - Set `completed_at` timestamp
  - Create 'complete' event
  - Check instance completion

#### `splitToken(int $parentTokenId, array $splitConfig, ?int $parallelGroupId = null): array`
- **Location:** `source/BGERP/Service/TokenLifecycleService.php:657`
- **Task 17:** Enhanced with parallel support
- **Flow:**
  1. Generate `parallel_group_id` if not provided (uses parent token ID)
  2. For each branch in split config:
     - Create child token with `parallel_group_id` and `parallel_branch_key`
     - Create 'split' event
     - Create 'enter' event
  3. Mark parent as 'completed'
- **Returns:** Array of child token IDs

#### `cancelToken(int $tokenId, string $cancellationType, string $reason, ?int $operatorId = null): array`
- **Location:** `source/BGERP/Service/TokenLifecycleService.php:430`
- **Cancellation types:**
  - `qc_fail` → Auto-spawn replacement token
  - `redesign` → Mark for redesign (requires manager review)
  - `permanent` → Just scrap, no replacement
- **Actions:**
  - Set status to 'scrapped'
  - Set `cancellation_type` and `cancellation_reason`
  - Clear `current_node_id`
  - Create 'cancel' event
  - Handle based on cancellation type
- **Task 23.5:** Added `onTokenCompleted()` hook for ETA health tracking (non-blocking)

---

### Class: `BGERP\Dag\TokenEventService`

**File:** `source/BGERP/Dag/TokenEventService.php`  
**Purpose:** Persist canonical events to token_event table (Task 21.3)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `persistEvent(string $eventType, array $context, array $payload = []): int`
- **Location:** `source/BGERP/Dag/TokenEventService.php`
- **Purpose:** Persist canonical event to `token_event` table
- **Event Types:** TOKEN_*, NODE_*, OVERRIDE_*, COMP_*, INVENTORY_*
- **Actions:**
  - Validates event type
  - Creates event record with canonical timezone (TimeHelper)
  - Returns event ID

#### `getEventsForToken(int $tokenId, ?array $options = []): array`
- **Location:** `source/BGERP/Dag/TokenEventService.php`
- **Purpose:** Retrieve canonical events for a token
- **Options:**
  - `event_types` - Filter by event types
  - `from_time` - Filter by start time
  - `to_time` - Filter by end time
- **Returns:** Array of event records

**Integration:**
- Used by `NodeBehaviorEngine` for persisting canonical events
- Used by `TimeEventReader` for reading timeline
- All canonical events must go through this service

---

### Class: `BGERP\Dag\TimeEventReader`

**File:** `source/BGERP/Dag/TimeEventReader.php`  
**Purpose:** Read canonical timeline from token_event table (Task 21.5)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `getTimelineForToken(int $tokenId, ?array $options = []): array`
- **Location:** `source/BGERP/Dag/TimeEventReader.php`
- **Purpose:** Build canonical timeline for a token
- **Returns:**
  - `events` - Array of events in chronological order
  - `sessions` - Array of work sessions
  - `start_at` - Token start time (ISO8601)
  - `completed_at` - Token completion time (ISO8601)
  - `actual_duration_ms` - Total duration in milliseconds

#### `getDurationStats(int $tokenId, ?string $nodeId = null): array`
- **Location:** `source/BGERP/Dag/TimeEventReader.php`
- **Purpose:** Calculate duration statistics for token/node
- **Returns:**
  - `avg_ms` - Average duration
  - `p50_ms` - 50th percentile
  - `p90_ms` - 90th percentile
  - `min_ms` - Minimum duration
  - `max_ms` - Maximum duration

**Integration:**
- Used by `MOCreateAssistService` for time estimation (Task 23.2)
- Used by `MOLoadEtaService` for ETA calculation (Task 23.4)
- Used by `LocalRepairEngine` and `TimelineReconstructionEngine` for timeline analysis
- All timeline reads must go through this service (never query `token_event` directly)

---

## DAG Engine Layer

### Class: `BGERP\Dag\NodeBehaviorEngine`

**File:** `source/BGERP/Dag/NodeBehaviorEngine.php`  
**Purpose:** Execute node behaviors based on Node Mode from Work Center (Task 21.1)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `resolveNodeMode(array $node): ?string`
- **Location:** `source/BGERP/Dag/NodeBehaviorEngine.php`
- **Purpose:** Resolve node_mode from Work Center (NOT from Node)
- **Implementation:**
  - Reads `id_work_center` from `routing_node`
  - Queries `work_center.node_mode`
  - Returns: `BATCH_QUANTITY`, `HAT_SINGLE`, `CLASSIC_SCAN`, `QC_SINGLE` or null
- **Alignment:** Follows Node_Behavier.md AXIOM A2 (Work Center determines Node Mode)

#### `buildExecutionContext(array $token, array $node, ?array $jobTicket = null): array`
- **Location:** `source/BGERP/Dag/NodeBehaviorEngine.php`
- **Purpose:** Build normalized execution context
- **Key Fields:**
  - `work_center.node_mode` - From Work Center (not from Node)
  - `execution.node_mode` - Resolved node_mode
  - `execution.line_type` - From job context (classic or hatthasilpa)
  - `time.now` - Current time in canonical timezone (TimeHelper)
- **Alignment:** Follows Node_Behavier.md AXIOM A3 (Runtime uses node_mode + line_type)

#### `executeBehavior(array $context): array`
- **Location:** `source/BGERP/Dag/NodeBehaviorEngine.php`
- **Purpose:** Execute behavior based on node_mode
- **Returns:**
  - `canonical_events` - Array of canonical events (TOKEN_*, NODE_*, etc.)
  - `effects` - Legacy structure for compatibility
  - `meta` - Execution metadata
- **Task 21.2+:** Generates canonical events for all behavior actions

**Integration:**
- Used by `TokenLifecycleService` for behavior execution (Task 21.2+)
- Generates canonical events via `TokenEventService`
- Aligned with Canonical Event Framework (Core Principles 14-15)

---

### Class: `BGERP\Dag\DagExecutionService`

**File:** `source/BGERP/Dag/DagExecutionService.php`  
**Purpose:** Centralized service for DAG token movement and execution logic

**Key Methods:**

#### `moveToNextNode(int $tokenId): array`
- **Location:** `source/BGERP/Dag/DagExecutionService.php:58`
- **Entry point** for token advancement (called from BehaviorExecutionService)
- **Validations:**
  - Token exists
  - Token not closed (completed/cancelled/scrapped)
  - Token in valid state (active/ready)
  - No active work session (Task 11)
  - Component completeness (Task 13.6)
- **Flow:**
  1. Validate token state
  2. Call `DAGRoutingService::routeToken()`
  3. Return routing result

#### `moveToNodeId(int $tokenId, int $targetNodeId): array`
- **Location:** `source/BGERP/Dag/DagExecutionService.php:220`
- **Purpose:** Manual/override routing to specific node
- **Validations:**
  - Token exists and is active/ready
  - Target node exists
  - Component completeness for target node

---

### Class: `BGERP\Dag\BehaviorExecutionService`

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`  
**Purpose:** Execute behavior actions (STITCH, CUT, EDGE, QC)

**Key Methods:**

#### `execute(string $behaviorCode, string $sourcePage, string $action, array $context = [], array $formData = []): array`
- **Location:** `source/BGERP/Dag/BehaviorExecutionService.php:94`
- **Validations (from code):**
  - Task 15: `behavior_code` must match `node.behavior_code`
  - Task 16: `execution_mode` must match `node.execution_mode`
- **Behavior handlers:**
  - `STITCH` → `handleStitch()`
  - `CUT` → `handleCut()`
  - `EDGE` → `handleEdge()`
  - `QC_SINGLE` / `QC_FINAL` → `handleQc()`

#### `handleStitch(...)`
- **Location:** `source/BGERP/Dag/BehaviorExecutionService.php:184`
- **Actions:**
  - `stitch_start` → Start work session
  - `stitch_pause` → Pause work session
  - `stitch_resume` → Resume work session
  - `stitch_complete` → Complete session + route to next node
- **Integration:**
  - Uses `TokenWorkSessionService` for session management
  - Uses `DagExecutionService::moveToNextNode()` for routing

#### `handleQc(...)`
- **Location:** `source/BGERP/Dag/BehaviorExecutionService.php:1236`
- **Actions:**
  - `qc_pass` → Route to next node (normal path)
  - `qc_fail` / `qc_rework` → Use `DAGRoutingService::handleQCResult()` for rework
  - `qc_send_back` → Log only (no auto-route)

---

### Class: `BGERP\Dag\ParallelMachineCoordinator`

**File:** `source/BGERP/Dag/ParallelMachineCoordinator.php`  
**Purpose:** Coordinate parallel and machine-based execution (Task 18.1)

**Key Methods:**

#### `onSplit(int $parentTokenId, int $splitNodeId, array $childTokenIds, int $parallelGroupId): array`
- **Location:** `source/BGERP/Dag/ParallelMachineCoordinator.php:47`
- **Flow:**
  1. For each child token:
     - Check if node needs machine allocation
     - If yes → Call `MachineAllocationService::allocateMachine()`
     - If allocated → Assign machine, log event, set branch state to 'IN_MACHINE'
     - If waiting → Set token to 'waiting', log event, set branch state to 'WAITING_MACHINE'
     - If no machine binding → Set branch state to 'READY'
  2. Return branch states

#### `canMerge(int $graphId, int $mergeNodeId, int $parallelGroupId, string $mergePolicy = 'ALL', ?int $atLeastCount = null, ?int $timeoutSeconds = null): array`
- **Location:** `source/BGERP/Dag/ParallelMachineCoordinator.php:148`
- **Merge policies (from code):**
  - `ALL` → All branches must be completed
  - `ANY` → Any branch completed is enough
  - `AT_LEAST` → At least N branches must be completed
  - `TIMEOUT_FAIL` → Wait for all, but fail if timeout exceeded
- **Flow:**
  1. Check for deadlock (`isBlockStuck()`)
  2. Check timeout (if TIMEOUT_FAIL policy)
  3. Count completed/waiting/active branches
  4. Evaluate merge policy
  5. Return `['can_merge' => bool, 'reason' => string, 'deadlock' => bool]`

#### `isBlockStuck(int $parallelGroupId): array`
- **Location:** `source/BGERP/Dag/ParallelMachineCoordinator.php:317`
- **Deadlock detection:**
  - Checks for branches waiting on inactive machines
  - Checks for branches waiting but node has no machine binding
- **Returns:** `['stuck' => bool, 'reason' => string|null]`

#### `getETA(int $parallelGroupId): array`
- **Location:** `source/BGERP/Dag/ParallelMachineCoordinator.php:373`
- **Purpose:** Estimate time for parallel block completion
- **Logic:**
  - If branches waiting → Cannot estimate (returns null)
  - If branches in machine → Estimate based on cycle time and elapsed time
  - Returns longest branch ETA

---

### Class: `BGERP\Dag\MachineAllocationService`

**File:** `source/BGERP/Dag/MachineAllocationService.php`  
**Purpose:** Allocate and release machines for tokens

**Key Methods:**

#### `allocateMachine(int $tokenId, int $nodeId, ?string $workCenterCode = null, ?string $machineBindingMode = null, ?string $machineCodesJson = null): array`
- **Location:** `source/BGERP/Dag/MachineAllocationService.php:40`
- **Binding modes:**
  - `NONE` → No machine binding (returns immediately)
  - `BY_WORK_CENTER` → Auto-select from work center machines
  - `EXPLICIT` → Use explicit machine list from `machine_codes`
- **Flow:**
  1. Get candidate machines based on binding mode
  2. Find available machine (respecting `concurrency_limit`)
  3. Return allocation result

#### `findAvailableMachine(array $candidateMachines, int $nodeId): ?array`
- **Location:** `source/BGERP/Dag/MachineAllocationService.php:154`
- **Logic:**
  - For each candidate machine:
    - Count active tokens at node using this machine
    - If count < `concurrency_limit` → Machine available
  - Returns first available machine

#### `assignMachine(int $tokenId, string $machineCode): bool`
- **Location:** `source/BGERP/Dag/MachineAllocationService.php:225`
- **Actions:**
  - Set `flow_token.machine_code`
  - Set `flow_token.machine_cycle_started_at = NOW()`
  - Clear `flow_token.machine_cycle_completed_at`

#### `releaseMachine(int $tokenId): bool`
- **Location:** `source/BGERP/Dag/MachineAllocationService.php:203`
- **Actions:**
  - Set `flow_token.machine_cycle_completed_at = NOW()`
  - (Note: `machine_code` is NOT cleared - kept for audit trail)

---

### Class: `BGERP\Dag\MachineRegistry`

**File:** `source/BGERP/Dag/MachineRegistry.php`  
**Purpose:** Discover and provide machine metadata

**Key Methods:**

#### `getMachinesByWorkCenter(?string $workCenterCode = null, bool $activeOnly = true): array`
- **Location:** `source/BGERP/Dag/MachineRegistry.php:35`
- Returns all machines for work center (or all machines if workCenterCode is null)

#### `getMachineByCode(string $machineCode): ?array`
- **Location:** `source/BGERP/Dag/MachineRegistry.php:96`
- Returns single machine record

#### `getMachinesByCodes(array $machineCodes, bool $activeOnly = true): array`
- **Location:** `source/BGERP/Dag/MachineRegistry.php:132`
- Returns machines by explicit code list

---

### Class: `BGERP\Dag\NodeTypeRegistry`

**File:** `source/BGERP/Dag/NodeTypeRegistry.php`  
**Purpose:** Validate and derive node types (Task 16)

**Key Methods:**

#### `isValidMode(string $mode): bool`
- **Location:** `source/BGERP/Dag/NodeTypeRegistry.php:69`
- **Valid modes:** BATCH, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE

#### `getCanonicalMode(string $behaviorCode): ?string`
- **Location:** `source/BGERP/Dag/NodeTypeRegistry.php:80`
- **Canonical mappings (from code):**
  - CUT → BATCH
  - EDGE → BATCH
  - STITCH → HAT_SINGLE
  - QC_FINAL → QC_SINGLE
  - QC_SINGLE → QC_SINGLE
  - HARDWARE_ASSEMBLY → BATCH
  - QC_REPAIR → QC_SINGLE
  - EMBOSS → HAT_SINGLE

#### `isValidCombination(string $behaviorCode, string $executionMode): bool`
- **Location:** `source/BGERP/Dag/NodeTypeRegistry.php:92`
- Checks if behavior + execution mode combination is allowed

#### `deriveNodeType(string $behaviorCode, string $executionMode): string`
- **Location:** `source/BGERP/Dag/NodeTypeRegistry.php:110`
- **Format:** `{behavior_code}:{execution_mode}` (e.g., "CUT:BATCH", "STITCH:HAT_SINGLE")

---

### Class: `BGERP\Dag\GraphValidationEngine`

**File:** `source/BGERP/Dag/GraphValidationEngine.php`  
**Purpose:** Unified validation engine for graph structure and semantics (Task 19.7, 19.10)  
**Status:** ✅ **COMPLETED** (December 2025)

**Key Methods:**

#### `validate(array $nodes, array $edges, array $options = []): array`
- **Location:** `source/BGERP/Dag/GraphValidationEngine.php:39`
- **Purpose:** Single source of truth for all graph validation rules
- **Validations (11 modules):**
  1. Node Existence - Graph must have nodes
  2. Start/End - Exactly 1 START, at least 1 END
  3. Edge Integrity - All edges reference valid nodes
  4. Parallel Structure - Split nodes have 2+ outgoing edges
  5. Merge Structure - Merge nodes have 2+ incoming edges
  6. QC Routing - QC nodes have proper routing coverage
  7. Conditional Routing - Conditional edges have valid conditions
  8. Behavior-WorkCenter Compatibility - Behavior matches work center
  9. Machine Binding - Machine-bound nodes have valid machines
  10. Node Configuration - Node parameters are valid
  11. Semantic Layer (Task 19.10) - Intent mismatch detection
- **Returns:**
  - `valid`: boolean
  - `errors`: Array of error objects with code, message, severity, category, suggestion
  - `warnings`: Array of warning objects
  - `summary`: Validation statistics

**Integration:**
- Frontend (`graph_designer.js`) calls via `graph_validate` API
- Backend (`dag_routing_api.php`) uses for save/publish validation
- Replaces all scattered validation logic

---

### Class: `BGERP\Dag\GraphAutoFixEngine`

**File:** `source/BGERP/Dag/GraphAutoFixEngine.php`  
**Purpose:** Safe, deterministic AutoFix layer for graph problems (Task 19.8, 19.9, 19.10)  
**Status:** ✅ **COMPLETED** (December 2025)

**Key Methods:**

#### `suggestFixes(array $nodes, array $edges, array $validationResult, array $options = []): array`
- **Location:** `source/BGERP/Dag/GraphAutoFixEngine.php:46`
- **Purpose:** Suggest fixes for validation errors/warnings
- **Modes:**
  - `metadata` (v1) - Metadata fixes only
  - `structural` (v2) - v1 + structural fixes (create edges/nodes)
  - `semantic` (v3) - v1 + v2 + semantic fixes with risk scoring
- **Returns:**
  - `fixes`: Array of FixDefinition objects
  - `patched_nodes`: Preview of patched nodes (for UI)
  - `patched_edges`: Preview of patched edges (for UI)

**Fix Patterns:**

**v1 (Metadata Only):**
- QC Pass → Next, Else → Rework
- Mark explicit SINK nodes
- Default ELSE route clarification (non-QC)
- START/END node metadata normalization

**v2 (Structural):**
- Auto-create missing QC edges for full coverage
- Auto-create valid ELSE edges for non-QC conditional nodes
- Auto-create END node if missing
- Auto-connect unreachable nodes
- Auto-create required rework edges for QC nodes
- Auto-mark merge/split nodes when graph structure implies

**v3 (Semantic - Task 19.10):**
- QC 2-way fix (Risk: 10)
- QC 3-way fix (Risk: 40)
- Parallel split fix (Risk: 30)
- END consolidation (Risk: 60)
- Unreachable connection (Risk: 65)

**Risk Scoring (Task 19.10):**
- Each fix receives Risk Score (0-100)
- 0-20 Low: Auto-apply safe
- 21-50 Medium: Needs user confirmation
- 51-80 High: Shown but disabled by default
- 81-100 Critical: Never auto-applied

**Integration:**
- Called via `graph_autofix` API action
- Frontend (`graph_designer.js`) shows fixes dialog with risk badges
- User selects fixes to apply
- Frontend applies fixes to graph before save

---

### Class: `BGERP\Dag\SemanticIntentEngine`

**File:** `source/BGERP/Dag/SemanticIntentEngine.php`  
**Purpose:** Analyze graph patterns to infer user intent (Task 19.10, 19.10.1)  
**Status:** ✅ **COMPLETED** (December 2025)

**Key Methods:**

#### `analyzeIntent(array $nodes, array $edges, array $options = []): array`
- **Location:** `source/BGERP/Dag/SemanticIntentEngine.php:42`
- **Purpose:** Infer semantic intent from graph patterns
- **Returns:**
  - `intents`: Array of IntentDefinition objects
  - `patterns`: Array of human-readable pattern descriptions

**Intent Types (13 types):**

**QC Routing (3):**
- `qc.pass_only` - Only PASS edge, no failure/rework
- `qc.two_way` - Pass + Rework (no minor/major split)
- `qc.three_way` - Pass + Minor + Major

**Parallel/Multi-exit (4):**
- `operation.linear_only` - Exactly 1 outgoing edge (reduces noise)
- `operation.multi_exit` - Multiple edges with rework/conditional (not parallel)
- `parallel.true_split` - 2+ normal edges to operation nodes
- `parallel.semantic_split` - 2+ normal edges to mixed node types

**Endpoint (4):**
- `endpoint.missing` - No END node
- `endpoint.true_end` - Single END node
- `endpoint.multi_end` - Multiple END nodes with parallel structure
- `endpoint.unintentional_multi` - Multiple END nodes without parallel structure

**Reachability (2):**
- `unreachable.intentional_subflow` - Unreachable node in connected subgraph
- `unreachable.unintentional` - Isolated unreachable node

**IntentDefinition Structure:**
- `type`: Intent type string
- `scope`: 'node' | 'edge' | 'graph'
- `node_id`, `node_code`, `edge_id`: Target identifiers
- `confidence`: 0.0-1.0
- `risk_base`: Base risk score (0-100)
- `evidence`: Structured evidence data
- `notes`: Human-readable description

**Integration:**
- Used by `GraphAutoFixEngine` to generate contextual fixes
- Used by `GraphValidationEngine` for semantic validation layer
- Pure analysis (no DB queries, no graph modification)

---

## Helper / Utility Layer

### Class: `BGERP\Helper\TimeHelper`

**File:** `source/BGERP/Helper/TimeHelper.php`  
**Purpose:** Canonical timezone normalization layer for PHP backend (Task 20.2)  
**Status:** ✅ **COMPLETED** (January 2025)

**Key Methods:**

#### `now(): DateTimeImmutable`
- Returns current time in canonical timezone (Asia/Bangkok)
- Uses `BGERP_TIMEZONE` constant from `config.php`

#### `parse($timeString, ?$format = null): ?DateTimeImmutable`
- Parse any time format → canonical timezone
- Supports ISO8601, MySQL DATETIME, Unix timestamp, relative strings
- Returns null if parsing fails

#### `toIso8601(DateTimeImmutable $dt): string`
- Format DateTimeImmutable as ISO8601 string

#### `toMysql(DateTimeImmutable $dt): string`
- Format DateTimeImmutable as MySQL DATETIME string

#### `durationMs(DateTimeImmutable $start, DateTimeImmutable $end): int`
- Calculate duration in milliseconds between two DateTimeImmutable objects

**Integration:**
- Used by `EtaEngine` for all time operations
- Used by `TokenLifecycleService` for token timestamps
- Used by `TokenWorkSessionService` for session timestamps
- Used by `DAGRoutingService` for wait time calculations
- Used by `WorkSessionTimeEngine` for timer calculations
- All SuperDAG time operations must use TimeHelper (no bare `strtotime()`, `time()`, `date()`)

---

### Class: `BGERP\Dag\CanonicalEventIntegrityValidator`

**File:** `source/BGERP/Dag/CanonicalEventIntegrityValidator.php`  
**Purpose:** Validate canonical event integrity (Task 21.7)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `validateToken(int $tokenId, ?array $options = []): array`
- **Location:** `source/BGERP/Dag/CanonicalEventIntegrityValidator.php`
- **Purpose:** Validate canonical events for a token
- **Validation Rules (10+):**
  - Missing start event
  - Missing complete event
  - Unpaired pause/resume
  - Invalid sequence
  - Session overlap
  - Zero/negative duration
  - Event time disorder
  - No canonical events
- **Returns:**
  - `valid` - Boolean
  - `problems` - Array of problem codes
  - `suggestions` - Array of repair suggestions

**Integration:**
- Used by `LocalRepairEngine` for detecting repairable problems
- Used by `TimelineReconstructionEngine` for L2/L3 problem detection
- Used by dev tools (`dev_token_timeline.php`, `dag_validate_cli.php`)

---

### Class: `BGERP\Dag\BulkIntegrityValidator`

**File:** `source/BGERP/Dag/BulkIntegrityValidator.php`  
**Purpose:** Batch validation for multiple tokens (Task 21.8)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `validateTokens(array $tokenIds, ?array $options = []): array`
- **Location:** `source/BGERP/Dag/BulkIntegrityValidator.php`
- **Purpose:** Validate multiple tokens in batch
- **Returns:**
  - `results` - Array of validation results per token
  - `summary` - Aggregated statistics
  - `session_overlaps` - Detected session overlaps

**Integration:**
- Used for bulk validation and reporting
- Detects session overlap across tokens

---

### Class: `BGERP\Dag\LocalRepairEngine`

**File:** `source/BGERP/Dag/LocalRepairEngine.php`  
**Purpose:** Repair canonical events for a single token (Task 22.1)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `proposeRepairs(int $tokenId, ?array $options = []): array`
- **Location:** `source/BGERP/Dag/LocalRepairEngine.php`
- **Purpose:** Propose repairs for detected problems
- **Repairable Problems:**
  - `MISSING_START` - Missing start event
  - `MISSING_COMPLETE` - Missing complete event
  - `UNPAIRED_PAUSE` - Unpaired pause/resume
  - `NO_CANONICAL_EVENTS` - No canonical events
  - `COMPLETION_ISSUE` - Completion/sequence issues
- **Returns:**
  - `repairs` - Array of repair proposals
  - `audit_trail` - Repair audit information

#### `applyRepair(int $tokenId, string $repairType, array $repairData): array`
- **Location:** `source/BGERP/Dag/LocalRepairEngine.php`
- **Purpose:** Apply repair to token
- **Actions:**
  - Creates repair events (append-only)
  - Logs to `token_repair_log` table
  - Updates token timeline
- **Returns:** Repair result with new events

**Integration:**
- Used by `RepairOrchestrator` for coordinating repairs
- Feature flag controlled: `CANONICAL_SELF_HEALING_LOCAL`
- Append-only approach (never modifies original events)

---

### Class: `BGERP\Dag\TimelineReconstructionEngine`

**File:** `source/BGERP/Dag/TimelineReconstructionEngine.php`  
**Purpose:** Reconstruct canonical timeline for L2/L3 problems (Task 22.3)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `generateReconstructionPlan(int $tokenId, ?array $options = []): array`
- **Location:** `source/BGERP/Dag/TimelineReconstructionEngine.php`
- **Purpose:** Generate reconstruction plan for token
- **Reconstructable Problems:**
  - `SESSION_OVERLAP_SIMPLE` - Session overlap detection and repair
  - `ZERO_DURATION` - Zero/negative duration repair
  - `INVALID_SEQUENCE_SIMPLE` - Sequence repair (implicit)
- **Returns:**
  - `plan` - Reconstruction plan
  - `new_events` - Proposed new events
  - `risk_score` - Risk assessment

#### `applyReconstruction(int $tokenId, array $plan): array`
- **Location:** `source/BGERP/Dag/TimelineReconstructionEngine.php`
- **Purpose:** Apply reconstruction to token
- **Actions:**
  - Creates new events (append-only)
  - Reconstructs timeline from existing events
  - Logs to `token_repair_log` table
- **Returns:** Reconstruction result

**Integration:**
- Used by `RepairOrchestrator` for L2/L3 repairs
- Integrates with `TimeEventReader` for timeline analysis
- Append-only approach (never modifies original events)

---

### Class: `BGERP\Dag\RepairOrchestrator`

**File:** `source/BGERP/Dag/RepairOrchestrator.php`  
**Purpose:** Coordinate repair operations (Task 22.3.6)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `orchestrateRepair(int $tokenId, ?array $options = []): array`
- **Location:** `source/BGERP/Dag/RepairOrchestrator.php`
- **Purpose:** Orchestrate repair for token
- **Flow:**
  1. Validate token using `CanonicalEventIntegrityValidator`
  2. Detect problems (L1, L2, L3)
  3. Propose repairs using `LocalRepairEngine` or `TimelineReconstructionEngine`
  4. Apply repairs
  5. Log to `token_repair_log`
- **Returns:** Repair orchestration result

**Integration:**
- Coordinates between `LocalRepairEngine` and `TimelineReconstructionEngine`
- Used by repair tools and APIs

---

### Class: `BGERP\Dag\EtaEngine`

**File:** `source/BGERP/Dag/EtaEngine.php`  
**Purpose:** Calculate ETA (Estimated Time of Arrival) and SLA status for tokens (Task 20)  
**Status:** ✅ **COMPLETED** (January 2025)

**Key Methods:**

#### `computeNodeEtaForToken(array $token, ?array $node = null, ?array $graph = null): array`
- Calculate ETA for token at current node
- Uses `TimeHelper` for all time operations
- Returns:
  - `planned_finish_at` - ISO8601 timestamp in canonical timezone
  - `remaining_ms` - Remaining time in milliseconds
  - `sla_status` - ON_TRACK, AT_RISK, or BREACHING
  - `node_code` - Current node code
  - `sla_minutes` - SLA minutes from node
  - `estimated_minutes` - Estimated minutes from node

#### `calculateSlaStatus(DateTimeImmutable $startDt, int $plannedMinutes, ?DateTimeImmutable $now = null): ?string`
- Calculate SLA status for active token
- Uses `TimeHelper::durationMs()` for elapsed time calculation
- Threshold: 80% of planned time = AT_RISK

**SLA Status Constants:**
- `ON_TRACK` - Within 80% of planned time
- `AT_RISK` - 80-100% of planned time elapsed
- `BREACHING` - Exceeded planned time

**Integration:**
- Called via `DAGRoutingService::getTokenEta()`
- Exposed via `dag_routing_api.php?action=token_eta`
- Used by Graph Designer for ETA preview in node properties panel

---

## MO Service Layer

### Class: `BGERP\MO\MOCreateAssistService`

**File:** `source/BGERP/MO/MOCreateAssistService.php`  
**Purpose:** Smart MO creation assistance (Task 23.1, 23.2)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `buildCreatePreview(array $moData): array`
- **Location:** `source/BGERP/MO/MOCreateAssistService.php`
- **Purpose:** Build MO creation preview with suggestions
- **Returns:**
  - `routing_suggestions` - Suggested routing graphs
  - `validation_warnings` - Graph validation warnings
  - `time_estimation` - Time estimation preview
  - `eta_preview` - ETA preview (Task 23.5)

#### `validateGraphStructure(int $routingId): array`
- **Location:** `source/BGERP/MO/MOCreateAssistService.php`
- **Purpose:** Validate graph structure for MO creation
- **Validations:**
  - Cycle detection (using `ReachabilityAnalyzer`)
  - Reachability analysis
  - Node behavior compatibility (classic line)
- **Returns:** Validation result with errors/warnings

**Integration:**
- Used by `mo_assist_api.php` for MO creation assistance
- Non-intrusive layer (works before legacy `mo.php` create())
- Uses `TimeEventReader` for canonical timeline (Task 23.2)

---

### Class: `BGERP\MO\MOLoadSimulationService`

**File:** `source/BGERP/MO/MOLoadSimulationService.php`  
**Purpose:** Workload planning and load simulation (Task 23.3)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `runSimulation(int $moId, ?array $options = []): array`
- **Location:** `source/BGERP/MO/MOLoadSimulationService.php`
- **Purpose:** Run load simulation for MO
- **Returns:**
  - `station_load` - Load per work center
  - `worker_load` - Load per worker
  - `bottleneck_prediction` - Predicted bottlenecks
  - `node_projection` - Node-level execution projection
- **Uses:** Canonical timeline first, then historic duration, then fallback

#### `runSimulationForPreview(array $mo): array`
- **Location:** `source/BGERP/MO/MOLoadSimulationService.php`
- **Purpose:** Run simulation for preview (no id_mo yet)
- **Task 23.5:** Added for MO creation preview

**Integration:**
- API endpoint: `/mo/load-simulation`
- CLI tool: `cron/mo_load_sim.php`
- Used by MO planning UI

---

### Class: `BGERP\MO\MOLoadEtaService`

**File:** `source/BGERP/MO/MOLoadEtaService.php`  
**Purpose:** MO ETA calculation engine (Task 23.4)  
**Status:** ✅ **COMPLETED** (November 2025)  
**⚠️ Usage Status:** Optional/Experimental - Engine available but not enforced in daily operations

**Key Methods:**

#### `computeETA(int $moId): array`
- **Location:** `source/BGERP/MO/MOLoadEtaService.php`
- **Purpose:** Compute ETA for MO
- **Returns:**
  - `best` - Best case ETA (ISO8601)
  - `normal` - Normal case ETA (ISO8601)
  - `worst` - Worst case ETA (ISO8601)
  - `stages` - Stage-level ETA with risk factors
  - `nodes` - Node-level ETA timeline

#### `computeETAForPreview(array $mo): array`
- **Location:** `source/BGERP/MO/MOLoadEtaService.php`
- **Purpose:** Compute ETA for preview (no id_mo yet)
- **Task 23.5:** Added for MO creation preview

**Integration:**
- API endpoint: `/mo/eta`
- CLI tool: `cron/mo_eta.php`
- Uses `TimeEventReader` for canonical timeline
- Integrated with MO lifecycle (Task 23.5)

**⚠️ Current Usage:**
- ETA calculation engine is fully implemented and operational
- ETA cache and health monitoring systems are active
- **Not used as constraint** in current factory planning operations
- Classic Line uses fixed schedules and manual planning
- ETA available for informational/debugging purposes only
- Future: May be integrated as planning tool when needed

---

### Class: `BGERP\MO\MOEtaCacheService`

**File:** `source/BGERP/MO/MOEtaCacheService.php`  
**Purpose:** ETA result caching with signature-based invalidation (Task 23.4.4)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `getCachedETA(int $moId): ?array`
- **Location:** `source/BGERP/MO/MOEtaCacheService.php`
- **Purpose:** Get cached ETA if valid
- **Signature includes:** routing_version, routing_hash, engine_version, qty, etc.
- **Returns:** Cached ETA or null if invalid

#### `cacheETA(int $moId, array $etaResult): bool`
- **Location:** `source/BGERP/MO/MOEtaCacheService.php`
- **Purpose:** Cache ETA result
- **Actions:**
  - Generates signature from MO data
  - Stores in `mo_eta_cache` table
  - TTL-based invalidation

**Integration:**
- Used by `MOLoadEtaService` for caching
- Auto-invalidated on MO update (Task 23.6.1)
- Integrated with MO lifecycle (Task 23.5)

---

### Class: `BGERP\MO\MOEtaHealthService`

**File:** `source/BGERP/MO/MOEtaHealthService.php`  
**Purpose:** ETA health validation and monitoring (Task 23.4.6)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `validateETAHealth(int $moId): array`
- **Location:** `source/BGERP/MO/MOEtaHealthService.php`
- **Purpose:** Validate ETA health for MO
- **Returns:**
  - `health_status` - OK, WARNING, ERROR
  - `metrics` - Aggregated metrics
  - `red_flags` - Detected issues

#### `onTokenCompleted(int $tokenId): void`
- **Location:** `source/BGERP/MO/MOEtaHealthService.php`
- **Purpose:** Hook for token completion (Task 23.5)
- **Actions:**
  - Updates health log
  - Non-blocking (best-effort)

**Integration:**
- Called by `TokenLifecycleService::completeToken()` (Task 23.5)
- Creates `mo_eta_health_log` entries
- Cron script: `eta_health_cron.php`
- Monitoring dashboard available

---

### Class: `BGERP\MO\MOEtaAuditService`

**File:** `source/BGERP/MO/MOEtaAuditService.php`  
**Purpose:** Cross-validate ETA calculations (Task 23.4.2)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `auditETA(int $moId): array`
- **Location:** `source/BGERP/MO/MOEtaAuditService.php`
- **Purpose:** Audit ETA calculations
- **Returns:**
  - `errors` - Detected errors
  - `red_flags` - Warning flags
  - `comparison` - ETA vs Simulation vs Canonical comparison

**Integration:**
- Dev tool: `tools/eta_audit.php` (HTML UI + JSON export)
- Used for debugging and validation

---

## Product Service Layer

### Class: `BGERP\Product\ClassicProductionStatsService`

**File:** `source/BGERP/Product/ClassicProductionStatsService.php`  
**Purpose:** Classic production statistics recording and aggregation (Task 25.1)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `recordProductionOutput(int $jobTicketId, array $data): bool`
- **Location:** `source/BGERP/Product/ClassicProductionStatsService.php`
- **Purpose:** Record production output for job ticket
- **Actions:**
  - Records to `production_output_daily` table
  - Aggregates daily statistics
  - Idempotent (prevents duplicate records)

#### `getDailyOutput(int $productId, string $dateFrom, string $dateTo): array`
- **Location:** `source/BGERP/Product/ClassicProductionStatsService.php`
- **Purpose:** Get daily output statistics
- **Returns:** Aggregated daily statistics

**Integration:**
- Hooks in `job_ticket.php` for lifecycle tracking (start, complete, cancel, restore)
- Used by `product_stats_api.php` for statistics endpoints

---

### Class: `BGERP\Product\ProductMetadataResolver`

**File:** `source/BGERP/Product/ProductMetadataResolver.php`  
**Purpose:** Product metadata resolution (Task 25.3)  
**Status:** ✅ **COMPLETED** (November 2025)

**Key Methods:**

#### `resolveMetadata(int $productId): array`
- **Location:** `source/BGERP/Product/ProductMetadataResolver.php`
- **Purpose:** Resolve product metadata
- **Returns:**
  - `production_line` - Single production line (classic or hatthasilpa)
  - `supports_graph` - Whether product supports graph binding
  - `routing_info` - Routing graph information
  - `classic_stats` - Classic production statistics

**Integration:**
- Used by `product_api.php` for metadata endpoints
- Task 25.7: Uses single production_line column (not multi-select)

---

## UI Integration Layer

### File: `assets/javascripts/dag/modules/GraphTimezone.js`

**Purpose:** Frontend timezone normalization layer (Task 20.2.3)  
**Status:** ✅ **COMPLETED** (January 2025)

**Key Functions:**
- `normalize(dt)` - Normalize date to canonical timezone
- `toLocal(dt)` - Convert to local timezone
- `fromLocal(dt)` - Convert from local timezone
- `isValid(dt)` - Validate date
- `now()` - Current time in canonical timezone
- `format(dt, format)` - Format date

**Integration:**
- Used by `graph_sidebar.js` for date operations
- Loaded in `page/routing_graph_designer.php`
- All frontend time operations should use GraphTimezone

---

### File: `assets/javascripts/dag/graph_designer.js`

**Purpose:** Graph Designer UI (Cytoscape.js-based)

**Key Functions:**
- `createCytoscapeInstance(graphData)` - Initialize graph visualization
- `addNode(nodeType)` - Add new node (with Start/Finish validation - Task 18.3)
- `deleteSelected()` - Delete selected node/edge
- `saveNodeProperties()` - Save node properties to graph
- `showNodeProperties(nodeId)` - Show node properties panel
- `updateParallelMergeUIForSelectedNode()` - Update UI based on topology (Task 18.2)
- `loadGraph(graphId)` - Load graph from API

**Task 18.2 Features:**
- Topology-aware parallel/merge UI (hides sections if topology doesn't support)
- Node Type as read-only badge
- Node Code as read-only (auto-generated)
- Machine Settings in accordion (hidden if work center has no machines)

**Task 18.3 Features:**
- Start/Finish node rules (1 Start, 1 Finish exactly)
- Toolbar disable when Start/Finish exists
- QC Panel simplification (hide JSON, UI as source of truth)

**Task 19.1 Features:**
- ConditionalEdgeEditor integration for conditional edges
- Dropdown-only condition editor (no free text)
- QC-aware presets for edges from QC nodes
- Default route (Else) support
- Advanced JSON view (hidden by default)

**Task 19.2 Features:**
- Multi-group condition editor (OR between groups, AND within groups)
- Add/Remove groups and conditions
- QC templates (Template A: Basic QC Split, Template B: Severity + Quantity)
- Comprehensive validation (hard errors + soft warnings)
- QC coverage validation across outgoing edges
- Legacy format auto-conversion

**Task 19.7 Features:**
- Unified validation via `graph_validate` API
- Real-time validation feedback in UI
- Structured error/warning messages
- "Try Auto-Fix" button when fixes available

**Task 19.8 Features:**
- AutoFix dialog with fix selection checkboxes
- Fix preview (shows what will change)
- Apply selected fixes to graph

**Task 19.9 Features:**
- Structural fixes preview (shows new edges/nodes)
- "Structural Changes" badge for fixes that create elements
- Warning banner for structural fixes

**Task 19.10 Features:**
- Risk score badges (0-100) with color coding
- High/Critical risk fixes disabled by default
- Warning banner for risky fixes
- Manual review requirement for high-risk fixes

---

### File: `assets/javascripts/dag/modules/GraphSaver.js`

**Purpose:** Graph save/validation logic

**Key Functions:**
- `saveManual()` - Manual save (with validation)
- `saveAuto()` - Auto-save (with validation)
- `collectNodeData()` - Collect node data for save
- `validateGraphStructure()` - Client-side graph validation
- `serializeEdgeCondition(edge, editorContainer)` - Serialize edge condition (Task 19.1, 19.2)
  - Supports single condition (Task 19.1) and multi-group (Task 19.2) formats
  - Uses ConditionalEdgeEditor.serializeConditionGroups() for multi-group

**Validations (from code):**
- START node count = 1
- END/FINISH node count >= 1
- Parallel split nodes: 2+ outgoing edges
- Merge nodes: 2+ incoming edges
- Legacy node types rejected
- QC coverage validation (Task 19.1, 19.2)

---

### File: `assets/javascripts/dag/modules/conditional_edge_editor.js` (Task 19.1, 19.2)

**Purpose:** Unified conditional edge editor with multi-group support

**Key Functions:**
- `getAvailableFields()` - Returns dropdown-only field list
- `getOperatorsForField(field)` - Auto-selects valid operators
- `getValueInputType(field)` - Returns input type (select/number/text)
- `getEnumValues(field)` - Returns enum values for dropdown
- `isFromQCNode(edge, cy)` - Detects QC node source
- `getQCPresets()` - Returns QC-aware preset conditions (Task 19.1)
- `getQCTemplates()` - Returns QC templates for multi-group setup (Task 19.2)
- `renderEditor(edge, cy, existingCondition, isDefault)` - Renders editor HTML
  - Task 19.1: Single condition UI
  - Task 19.2: Multi-group UI with groups and conditions
- `parseConditionToGroups(existingCondition)` - Legacy → Multi-group conversion (Task 19.2)
- `normalizeConditionForUI(condition)` - Normalize condition for display (Task 19.2)
- `serializeCondition(field, operator, value, isDefault)` - Serialize single condition (Task 19.1)
- `serializeConditionGroups(editorContainer, isDefault)` - Serialize multi-group (Task 19.2)
- `validateConditionGroups(editorContainer, isDefault, options)` - Comprehensive validation (Task 19.2)
- `detectConflictingConditions(conditions, groupIdx, warnings)` - Conflict detection (Task 19.2)
- `validateQCCoverage(editorContainer, cy, sourceNode)` - QC coverage check (Task 19.2)
- `applyQCTemplate(editorContainer, template)` - Apply QC template (Task 19.2)

**Condition Model (Task 18, 19.1, 19.2):**
- Single condition: `{ type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }`
- Multi-group: `{ type: "or", groups: [{ type: "and", conditions: [...] }] }`
- Default route: `{ type: "expression", expression: "true" }`

**Validation Rules (Task 19.2):**
- Hard errors: No groups, empty groups, missing fields/operators/values, QC coverage gaps
- Soft warnings: Conflicting conditions (e.g., `qty >= 2 AND qty < 1`)

---

## Database / Persistence Layer

### Table: `routing_graph`

**Schema (from `0001_init_tenant_schema_v2.php`):**
- `id_graph` (PK)
- `graph_code` (UNIQUE)
- `graph_name`
- `graph_version` (INT)
- `is_active` (TINYINT)
- `is_draft` (TINYINT)
- `description` (TEXT)
- `created_at`, `updated_at`

---

### Table: `routing_node`

**Schema (from `0001_init_tenant_schema_v2.php` + migrations):**

**Core Fields:**
- `id_node` (PK)
- `id_graph` (FK → routing_graph)
- `node_code` (UNIQUE within graph)
- `node_name`
- `node_type` (ENUM: start, operation, qc, decision, end, split, join, wait, subgraph)
- `work_center_code` (VARCHAR, FK to work_center.code)
- `estimated_minutes` (INT)

**Task 15 Fields:**
- `behavior_code` (VARCHAR) - Behavior code
- `behavior_version` (INT) - Behavior version

**Task 16 Fields:**
- `execution_mode` (VARCHAR) - Execution mode
- `derived_node_type` (VARCHAR) - Derived node type

**Task 17 Fields:**
- `is_parallel_split` (TINYINT) - Parallel split flag
- `is_merge_node` (TINYINT) - Merge node flag
- `merge_mode` (VARCHAR) - Merge semantics (deprecated)

**Task 18 Fields:**
- `machine_binding_mode` (VARCHAR) - Machine binding mode
- `machine_codes` (TEXT) - Machine codes list

**Task 18.1 Fields:**
- `parallel_merge_policy` (ENUM: ALL, ANY, AT_LEAST, TIMEOUT_FAIL)
- `parallel_merge_timeout_seconds` (INT NULL)
- `parallel_merge_at_least_count` (INT NULL)

**Configuration Fields:**
- `node_config` (JSON) - Node-specific configuration
- `qc_policy` (JSON) - QC policy configuration
- `form_schema_json` (JSON) - Form schema for QC/Decision nodes

---

### Table: `routing_edge`

**Schema (from `0001_init_tenant_schema_v2.php`):**
- `id_edge` (PK)
- `id_graph` (FK → routing_graph)
- `from_node_id` (FK → routing_node)
- `to_node_id` (FK → routing_node)
- `edge_type` (ENUM: normal, rework, conditional)
- `edge_condition` (JSON) - Condition for conditional edges
- `condition_rule` (JSON) - Alternative condition format (used in decision nodes)
- `edge_label` (VARCHAR) - Display label
- `priority` (INT) - Evaluation order
- `is_default` (TINYINT) - Default edge flag
- `guard_json` (JSON) - Runtime guard conditions

---

### Table: `flow_token`

**Schema (from `0001_init_tenant_schema_v2.php` + migrations):**

**Core Fields:**
- `id_token` (PK)
- `id_instance` (FK → job_graph_instance)
- `token_type` (ENUM: batch, piece, component)
- `serial_number` (VARCHAR)
- `parent_token_id` (FK → flow_token, NULL for root tokens)
- `current_node_id` (FK → routing_node, NULL if completed/scrapped)
- `status` (ENUM: ready, active, waiting, paused, completed, scrapped, cancelled, merged, consumed, stuck)
- `qty` (DECIMAL)

**Task 17 Fields:**
- `parallel_group_id` (INT NULL) - Parallel group ID
- `parallel_branch_key` (VARCHAR NULL) - Branch identifier

**Task 18 Fields:**
- `machine_code` (VARCHAR NULL) - Assigned machine code
- `machine_cycle_started_at` (DATETIME NULL)
- `machine_cycle_completed_at` (DATETIME NULL)

**Other Fields:**
- `metadata` (JSON) - Custom data
- `rework_count` (INT) - Rework count
- `rework_limit` (INT) - Rework limit
- `cancellation_type` (VARCHAR) - Cancellation type
- `cancellation_reason` (TEXT) - Cancellation reason
- `redesign_required` (TINYINT) - Redesign flag
- `spawned_at`, `completed_at`, `cancelled_at`

---

### Table: `machine`

**Schema (from `2025_12_18_machine_cycle_support.php`):**
- `id_machine` (PK)
- `machine_code` (UNIQUE)
- `machine_name`
- `work_center_code` (FK to work_center.code)
- `cycle_time_seconds` (INT NULL) - Average cycle time per unit/batch
- `batch_capacity` (INT) - Maximum units/batch per cycle
- `concurrency_limit` (INT) - How many tokens can be processed in parallel
- `is_system` (TINYINT) - System default flag
- `is_active` (TINYINT) - Machine is active
- `description` (TEXT)

---

### Table: `token_event`

**Schema (from code usage):**
- `id_event` (PK)
- `id_token` (FK → flow_token)
- `event_type` (VARCHAR) - Event type (spawn, enter, move, complete, cancel, split, merge, etc.)
  - **Task 21.2+:** Also supports canonical event types (TOKEN_*, NODE_*, OVERRIDE_*, COMP_*, INVENTORY_*)
- `id_node` (FK → routing_node, NULL for some events)
- `operator_user_id` (INT NULL)
- `event_time` (DATETIME) - Uses canonical timezone via TimeHelper (Task 20.2.2)
- `idempotency_key` (UNIQUE) - Idempotency key
- `event_data` (JSON) - Event metadata
- `duration_ms` (BIGINT UNSIGNED NULL) - Event duration in milliseconds (Task 19.5, Task 20: ETA calculation)
- **Task 21.5:** Used by `TimeEventReader` for canonical timeline
- **Task 22.1+:** Used by repair engines for timeline reconstruction

---

### Table: `token_repair_log`

**Schema (from Task 22.2):**
- `id_repair` (PK)
- `id_token` (FK → flow_token)
- `repair_type` (VARCHAR) - Repair type (MISSING_START, MISSING_COMPLETE, etc.)
- `repair_data` (JSON) - Repair details
- `created_by` (INT) - User who initiated repair
- `created_at` (DATETIME) - Repair timestamp
- `repaired_events` (JSON) - Array of repaired event IDs
- **Purpose:** Audit trail for all repair operations

---

### Table: `mo_eta_cache`

**Schema (from Task 23.4.4):**
- `id_cache` (PK)
- `id_mo` (FK → mo)
- `eta_signature` (VARCHAR) - Signature for cache invalidation
- `eta_result` (JSON) - Cached ETA result
- `cached_at` (DATETIME) - Cache timestamp
- `expires_at` (DATETIME) - TTL expiration
- **Purpose:** Cache ETA calculations with signature-based invalidation

---

### Table: `mo_eta_health_log`

**Schema (from Task 23.4.6):**
- `id_health` (PK)
- `id_mo` (FK → mo)
- `health_status` (VARCHAR) - OK, WARNING, ERROR
- `metrics` (JSON) - Aggregated metrics
- `red_flags` (JSON) - Detected issues
- `logged_at` (DATETIME) - Log timestamp
- **Purpose:** ETA health monitoring and validation

---

### Table: `production_output_daily`

**Schema (from Task 25.1):**
- `id_output` (PK)
- `id_product` (FK → product)
- `output_date` (DATE) - Output date
- `total_output` (INT) - Total output quantity
- `created_at`, `updated_at` (DATETIME)
- **Purpose:** Daily aggregated production statistics for Classic line

---

## Interaction Map

### Token Spawn Flow

```
API: dag_token_api.php::spawn()
  ↓
TokenLifecycleService::spawnTokens()
  ├─→ Check idempotency (mixed state guard)
  ├─→ Get start node
  ├─→ Create token(s) with status 'ready'
  ├─→ Create spawn + enter events
  └─→ AssignmentResolverService::resolveAssignment() (auto-assign)
```

### Token Execution Flow (STITCH example)

```
API: dag_token_api.php::start() / complete()
  ↓
BehaviorExecutionService::execute('STITCH', 'work_queue', 'stitch_start' / 'stitch_complete')
  ├─→ Validate behavior_code matches node.behavior_code (Task 15)
  ├─→ Validate execution_mode matches node.execution_mode (Task 16)
  ├─→ TokenWorkSessionService::startSession() / completeToken()
  │     └─→ Uses TimeHelper for timestamps (Task 20.2.2)
  └─→ (if complete) DagExecutionService::moveToNextNode()
        ↓
      DAGRoutingService::routeToken()
        ├─→ Check parallel split → handleParallelSplit()
        ├─→ Check merge → handleMergeNode()
        ├─→ Get outgoing edges
        ├─→ selectNextNode() (evaluate conditions)
        └─→ routeToNode()
              ├─→ Check concurrency/WIP limits
              ├─→ MachineAllocationService::allocateMachine() (if machine-bound)
              ├─→ Move token
              └─→ AssignmentResolverService::resolveAssignment()
  
Task 21.2+ (Canonical Events):
  ↓
NodeBehaviorEngine::executeBehavior()
  ├─→ Resolve node_mode from Work Center
  ├─→ Build execution context
  ├─→ Generate canonical events
  └─→ TokenEventService::persistEvent() → token_event table
  
Task 23.5 (MO Lifecycle):
  ↓
TokenLifecycleService::completeToken()
  └─→ MOEtaHealthService::onTokenCompleted() (non-blocking)
        └─→ Updates mo_eta_health_log
```

### Parallel Split Flow

```
DAGRoutingService::routeToken()
  ↓ (if is_parallel_split = true)
handleParallelSplit()
  ├─→ Get outgoing edges (must be 2+)
  ├─→ Generate parallel_group_id (parent token ID)
  ├─→ TokenLifecycleService::splitToken()
  │     └─→ Create child tokens with parallel_group_id + parallel_branch_key
  └─→ ParallelMachineCoordinator::onSplit()
        ├─→ For each child token:
        │     ├─→ Check machine binding
        │     ├─→ MachineAllocationService::allocateMachine()
        │     └─→ Set branch state (READY, IN_MACHINE, WAITING_MACHINE)
        └─→ Return branch states
```

### Merge Flow

```
DAGRoutingService::routeToken()
  ↓ (if is_merge_node = true)
handleMergeNode()
  ├─→ Get parallel_group_id from token
  ├─→ Get merge policy from node
  ├─→ ParallelMachineCoordinator::canMerge()
  │     ├─→ Check deadlock (isBlockStuck())
  │     ├─→ Check timeout (if TIMEOUT_FAIL)
  │     ├─→ Count completed branches
  │     └─→ Evaluate merge policy (ALL, ANY, AT_LEAST, TIMEOUT_FAIL)
  ├─→ If deadlock → Mark group as stuck
  ├─→ If not ready → Set token to 'waiting'
  └─→ If ready → Move token through merge, continue routing
```

### Conditional Routing Flow

```
DAGRoutingService::routeToken()
  ↓ (if 2+ outgoing edges)
selectNextNode()
  ├─→ Priority 1: Evaluate conditional edges
  │     └─→ evaluateCondition()
  │           ├─→ Load job/node data if needed
  │           ├─→ Evaluate condition type (qty_threshold, token_property, job_property, node_property, expression)
  │           └─→ Return true/false
  ├─→ Priority 2: Normal edge
  └─→ Priority 3: First edge (fallback)
```

### Machine Allocation Flow

```
DAGRoutingService::routeToNode()
  ↓ (if machine_binding_mode != NONE)
MachineAllocationService::allocateMachine()
  ├─→ Get candidate machines (BY_WORK_CENTER or EXPLICIT)
  ├─→ findAvailableMachine()
  │     ├─→ For each candidate:
  │     │     ├─→ Count active tokens at node using machine
  │     │     └─→ If count < concurrency_limit → Available
  │     └─→ Return first available machine
  ├─→ If allocated → assignMachine() (set machine_code, machine_cycle_started_at)
  └─→ If waiting → Set token status to 'waiting', log machine_waiting event
```

---

## Node Type & Behavior Semantics

### NodeType Derivation

**Formula:** `NodeType = Behavior + ExecutionMode`

**Implementation:** `NodeTypeRegistry::deriveNodeType()`

**Example:**
- `CUT:BATCH` → CUT behavior with BATCH execution mode
- `STITCH:HAT_SINGLE` → STITCH behavior with HAT_SINGLE execution mode

**Validation:**
- `NodeTypeRegistry::isValidCombination()` checks if behavior + mode is allowed
- `NodeTypeRegistry::getCanonicalMode()` returns default mode for behavior

---

### Behavior Execution Modes

**Valid Modes (from `NodeTypeRegistry::VALID_MODES`):**
- `BATCH` - Batch production (multiple units per operation)
- `HAT_SINGLE` - Hatthasilpa single-piece mode (per-piece tracking)
- `CLASSIC_SCAN` - Classic/OEM scan mode
- `QC_SINGLE` - QC single-piece mode

**Canonical Mappings (from `NodeTypeRegistry::CANONICAL_MAPPING`):**
- CUT → BATCH
- EDGE → BATCH
- STITCH → HAT_SINGLE
- QC_FINAL → QC_SINGLE
- QC_SINGLE → QC_SINGLE
- HARDWARE_ASSEMBLY → BATCH
- QC_REPAIR → QC_SINGLE
- EMBOSS → HAT_SINGLE

---

### Node Types (from `routing_node.node_type` ENUM)

**Core Types:**
- `start` - Entry point (must have exactly 1 per graph)
- `operation` - Work operation (CUT, STITCH, EDGE, etc.)
- `qc` - Quality control node
- `decision` - Conditional routing node
- `end` - Exit point (must have at least 1 per graph)

**Legacy Types (deprecated, rejected in API - Task 17.2):**
- `split` - Legacy parallel split (replaced by `is_parallel_split` flag)
- `join` - Legacy join (replaced by `is_merge_node` flag)
- `wait` - Legacy wait node

**Other Types:**
- `subgraph` - Subgraph reference node

---

### Behavior Codes

**Supported Behaviors (from `BehaviorExecutionService::execute()`):**
- `STITCH` - Stitching operations
- `CUT` - Cutting operations
- `EDGE` - Edging operations
- `QC_SINGLE` - Single-piece QC
- `QC_FINAL` - Final QC

**Behavior Registry:**
- Stored in `work_center_behavior` table
- Mapped to work centers via `work_center_behavior_map`
- System behaviors are locked (`is_system = 1`)

---

## Summary

This architecture map documents the **actual implementation** of SuperDAG execution engine as of Task 20.2.3. All references point to real files, classes, and methods in the codebase.

**Key Takeaways:**
1. **Entry Points:** `DAGRoutingService::routeToken()` is the main routing entry point
2. **Token Lifecycle:** `TokenLifecycleService` manages token creation, movement, and completion
3. **Behavior Execution:** `BehaviorExecutionService` executes behavior-specific actions
4. **Parallel Execution:** `ParallelMachineCoordinator` coordinates parallel and machine execution
5. **Conditional Routing:** `DAGRoutingService::evaluateCondition()` evaluates edge conditions
6. **Machine Allocation:** `MachineAllocationService` allocates machines based on binding mode
7. **NodeType Model:** `NodeTypeRegistry` validates and derives node types (Behavior + ExecutionMode)
8. **Graph Validation:** `GraphValidationEngine` provides unified validation (11 modules) (Task 19.7, 19.10)
9. **AutoFix Engine:** `GraphAutoFixEngine` suggests safe fixes for graph problems (v1: metadata, v2: structural, v3: semantic) (Task 19.8, 19.9, 19.10)
10. **Semantic Intent:** `SemanticIntentEngine` analyzes graph patterns to infer user intent (13 intent types) (Task 19.10, 19.10.1)

**Recent Updates (January 2025):**
- **Task 20:** Added EtaEngine for ETA/SLA calculation
- **Task 20.2:** Added TimeHelper (PHP) and GraphTimezone (JS) for canonical timezone normalization
- **Task 20.2.1:** Timezone audit completed
- **Task 20.2.2:** Token lifecycle services migrated to TimeHelper
- **Task 20.2.3:** DAG routing and graph operations migrated to TimeHelper
- **Task 21.1-21.8:** Added Node Behavior Engine, Canonical Events, Timeline Engine
  - NodeBehaviorEngine, TokenEventService, TimeEventReader
  - CanonicalEventIntegrityValidator, BulkIntegrityValidator
- **Task 22.1-22.3.6:** Added Self-Healing & Timeline Reconstruction
  - LocalRepairEngine, TimelineReconstructionEngine, RepairOrchestrator
  - token_repair_log table
- **Task 23.1-23.6.3:** Added MO Planning & ETA Intelligence
  - MOCreateAssistService, MOLoadSimulationService, MOLoadEtaService
  - MOEtaCacheService, MOEtaHealthService, MOEtaAuditService
  - mo_eta_cache, mo_eta_health_log tables
- **Task 25.1-25.7:** Added Product Statistics Layer
  - ClassicProductionStatsService, ProductMetadataResolver
  - production_output_daily table
- **Task 19.24.16:** Module structure normalization (6 modules)
- **Task 19.24.17:** Final consolidation (removed zombie code, normalized structure)

**Next Steps:**
- Use this map as foundation for future tasks
- Reference actual code locations when implementing new features
- Maintain this document as codebase evolves
- All time operations must use TimeHelper/GraphTimezone (no bare PHP/JS time functions)

**Last Updated:** January 2025 (Added TimeHelper, GraphTimezone, EtaEngine, Module Structure, Timezone Normalization)

