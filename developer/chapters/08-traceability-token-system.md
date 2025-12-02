# Chapter 8 — Traceability / Token System

**Last Updated:** November 19, 2025  
**Purpose:** Explain the token-based traceability system and DAG routing  
**Audience:** Developers working on traceability, token operations, and DAG routing

---

## Overview

The traceability system in Bellavier Group ERP uses a token-based approach to track every piece through production. Tokens flow through a Directed Acyclic Graph (DAG) routing system, providing complete audit trails and traceability.

**Key Components:**
- Token lifecycle (spawn → assign → work → route → complete)
- DAG routing design (graph, nodes, edges)
- QC/Rework integration
- MO (Manufacturing Order) linking
- API touchpoints (`trace_api.php`, `dag_token_api.php`)

**Design Principles:**
- ✅ Complete traceability (every piece tracked)
- ✅ DAG-based routing (flexible workflows)
- ✅ Audit trail (all events logged)
- ✅ Security (token ownership validation)

---

## Key Concepts

### 1. Token Lifecycle

**Complete Lifecycle:**
```
Token Spawn
    ├── Create token in flow_token table
    ├── Assign to initial node
    └── Set status: 'pending'
    ↓
Node Assignment
    ├── Assign operator to node
    ├── Create node_instance
    └── Update token status: 'assigned'
    ↓
Enter Node (Start Work)
    ├── Create token_event: 'enter'
    ├── Update node_instance: started_at
    └── Update token status: 'in_progress'
    ↓
Work (Start/Pause/Resume/Complete)
    ├── Create token_event: 'start', 'pause', 'resume', 'complete'
    ├── Update operator session
    └── Track work time
    ↓
Route to Next Node
    ├── Determine next node (DAG routing)
    ├── Create token_event: 'route'
    ├── Update token: current_node_id
    └── Update status: 'pending' (if more nodes) or 'completed' (if end node)
    ↓
Token Completed
    ├── Update token status: 'completed'
    ├── Set completed_at timestamp
    └── Finalize audit trail
```

### 2. DAG Routing Design

**Components:**
- `routing_graph` - Graph definitions
- `routing_node` - Node definitions (work stations)
- `routing_edge` - Edge definitions (routing paths)
- `flow_token` - Tokens flowing through graph
- `token_event` - Token events (audit trail)
- `node_instance` - Node instances (work sessions)

**Routing Logic:**
- Determine next node based on current node and conditions
- Support split/join/conditional routing
- Handle parallel paths
- Support rework loops

**Security:**
- Token ownership validation
- Node access control
- Operator assignment checks
- Complete audit trail

### 3. QC/Rework Integration

**QC Checkpoints:**
- QC nodes in DAG
- Pass/Fail routing
- Rework loops

**Rework Flow:**
```
Work → QC Node → [Pass] → Next Node
              → [Fail] → Rework Node → Work → QC Node
```

**MO Linking:**
- Tokens linked to Manufacturing Orders (MO)
- MO status updates based on token completion
- Batch tracking

---

## Core Components

### Token Tables

**flow_token:**
- Token definitions
- Current node, status, assignment
- Linked to MO, job ticket

**token_event:**
- All token events (audit trail)
- Event types: spawn, enter, start, pause, resume, complete, route
- Timestamps, operator, node

**node_instance:**
- Work sessions at nodes
- Operator assignments
- Start/pause/resume/complete times
- Work duration tracking

### DAG Tables

**routing_graph:**
- Graph definitions
- Graph metadata

**routing_node:**
- Node definitions (work stations)
- Node type, requirements
- Node configuration

**routing_edge:**
- Edge definitions (routing paths)
- Source node, target node
- Conditions, routing rules

### API Touchpoints

**dag_token_api.php:**
- Token operations (spawn, assign, start, pause, resume, complete, route)
- Node operations
- Token status queries

**trace_api.php:**
- Trace queries
- Token history
- Audit trail queries

---

## Token Security Model

### Token Ownership

**Validation:**
- Token ownership checked before operations
- Operator assignment validated
- Node access control enforced

**Security Checks:**
```php
// Check token ownership
if ($token['assigned_to'] != $member['id_member']) {
    json_error('unauthorized', 403);
}

// Check node access
if (!hasNodeAccess($member, $nodeId)) {
    json_error('forbidden', 403);
}
```

### Audit Trail

**Complete Logging:**
- All token events logged
- Operator, timestamp, node
- Event type, details
- Immutable audit trail

**Compliance:**
- Full traceability for compliance
- Historical data preserved
- Audit reports available

---

## How to Extend WIP Logic Safely

### Step 1: Understand Current Flow

**Read Existing Code:**
- `source/dag_token_api.php` - Token operations
- `source/trace_api.php` - Trace queries
- `source/dag_routing_api.php` - Routing logic

### Step 2: Identify Extension Point

**Possible Extension Points:**
- New event types
- New routing conditions
- New node types
- New token statuses

### Step 3: Maintain Backward Compatibility

**Rules:**
- ✅ Don't break existing token flows
- ✅ Don't change event types without migration
- ✅ Don't remove audit trail fields
- ✅ Don't change token status values

### Step 4: Add New Functionality

**Example: Adding New Event Type:**
```php
// 1. Add event type constant
define('TOKEN_EVENT_CUSTOM', 'custom');

// 2. Add event handling
case 'custom':
    // Validate
    // Create token_event
    // Update token status
    // Log audit trail
    break;
```

### Step 5: Update Tests

**Add Tests:**
- Unit tests for new logic
- Integration tests for token flow
- System-wide tests for API endpoints

---

## Examples

### Example 1: Token Spawn

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

// Permission check
use BGERP\Security\PermissionHelper;
if (!PermissionHelper::hasOrgPermission($member, 'dag.token.spawn')) {
    json_error('forbidden', 403);
}

// Spawn token
$tokenData = [
    'graph_id' => $_POST['graph_id'],
    'initial_node_id' => $_POST['initial_node_id'],
    'mo_id' => $_POST['mo_id'] ?? null,
    'spawned_by' => $member['id_member']
];

// Create token
$stmt = $tenantDb->prepare("INSERT INTO flow_token (graph_id, current_node_id, status, mo_id, spawned_by) VALUES (?, ?, 'pending', ?, ?)");
$stmt->bind_param('iiii', $tokenData['graph_id'], $tokenData['initial_node_id'], $tokenData['mo_id'], $tokenData['spawned_by']);
$stmt->execute();
$tokenId = $tenantDb->insert_id;

// Create spawn event
$stmt = $tenantDb->prepare("INSERT INTO token_event (token_id, event_type, node_id, operator_id, event_time) VALUES (?, 'spawn', ?, ?, NOW())");
$stmt->bind_param('iii', $tokenId, $tokenData['initial_node_id'], $member['id_member']);
$stmt->execute();

json_success(['token_id' => $tokenId]);
```

### Example 2: Token Routing

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

$tokenId = (int)($_POST['token_id'] ?? 0);
$nextNodeId = (int)($_POST['next_node_id'] ?? 0);

// Get token
$stmt = $tenantDb->prepare("SELECT * FROM flow_token WHERE id=? AND status='in_progress'");
$stmt->bind_param('i', $tokenId);
$stmt->execute();
$token = $stmt->get_result()->fetch_assoc();

if (!$token) {
    json_error('token_not_found', 404);
}

// Check ownership
if ($token['assigned_to'] != $member['id_member']) {
    json_error('unauthorized', 403);
}

// Determine next node (DAG routing logic)
$nextNode = determineNextNode($tenantDb, $token['current_node_id'], $token);

// Update token
$tenantDb->begin_transaction();
try {
    $stmt = $tenantDb->prepare("UPDATE flow_token SET current_node_id=?, status='pending' WHERE id=?");
    $stmt->bind_param('ii', $nextNode['id'], $tokenId);
    $stmt->execute();
    
    // Create route event
    $stmt = $tenantDb->prepare("INSERT INTO token_event (token_id, event_type, node_id, operator_id, event_time) VALUES (?, 'route', ?, ?, NOW())");
    $stmt->bind_param('iii', $tokenId, $nextNode['id'], $member['id_member']);
    $stmt->execute();
    
    $tenantDb->commit();
    json_success(['token_id' => $tokenId, 'next_node_id' => $nextNode['id']]);
} catch (\Throwable $e) {
    $tenantDb->rollback();
    error_log("Error: " . $e->getMessage());
    json_error('internal_error', 500);
}
```

### Example 3: Trace Query

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

[$org, $tenantDb, $member] = \BGERP\Bootstrap\TenantApiBootstrap::init();

$tokenId = (int)($_GET['token_id'] ?? 0);

// Get token history
$stmt = $tenantDb->prepare("
    SELECT 
        te.*,
        n.name as node_name,
        u.name as operator_name
    FROM token_event te
    LEFT JOIN routing_node n ON n.id = te.node_id
    LEFT JOIN account u ON u.id_member = te.operator_id
    WHERE te.token_id = ?
    ORDER BY te.event_time ASC
");
$stmt->bind_param('i', $tokenId);
$stmt->execute();
$events = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

json_success(['events' => $events]);
```

---

## Reference Documents

### Token System Documentation

- **dag_token_api.php**: `source/dag_token_api.php` - Token operations API
- **trace_api.php**: `source/trace_api.php` - Trace queries API
- **dag_routing_api.php**: `source/dag_routing_api.php` - Routing logic API

### DAG Documentation

- **DAG Planning**: `docs/DAG_PLANNING_SUMMARY.md` - DAG system overview
- **DAG Core TODO**: `docs/BELLAVIER_DAG_CORE_TODO.md` - Architecture & checklist
- **DAG Runtime Flow**: `docs/BELLAVIER_DAG_RUNTIME_FLOW.md` - Token/Node lifecycle

### Related Chapters

- **Chapter 6**: API Development Guide
- **Chapter 9**: PWA Scan System
- **Chapter 11**: Security Handbook

---

## Future Expansion

### Planned Enhancements

1. **Advanced Routing**
   - Conditional routing
   - Dynamic routing rules
   - Machine learning-based routing

2. **Token Analytics**
   - Performance metrics
   - Bottleneck detection
   - Optimization suggestions

3. **Real-Time Tracking**
   - WebSocket updates
   - Live token status
   - Real-time notifications

4. **Token Cloning**
   - Batch token creation
   - Template-based spawning
   - Bulk operations

---

**Previous Chapter:** [Chapter 7 — Global Helpers](../chapters/07-global-helpers.md)  
**Next Chapter:** [Chapter 9 — PWA Scan System](../chapters/09-pwa-scan-system.md)

