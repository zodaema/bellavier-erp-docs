# Task 14.1.4 — Routing V2 Execution Matrix

## Summary
This document describes how different routing scenarios are handled in Routing V2 using `DagExecutionService`.

---

## Routing Scenarios

### 1. Normal Node (operation)
**Scenario:** Token moves from one operation node to the next operation node along the normal path.

**Implementation:**
```php
$dagExecutionService = new DagExecutionService($tenantDb, $org, $userId);
$result = $dagExecutionService->moveToNextNode($tokenId);
```

**Behavior:**
- Finds next node via `DAGRoutingService->routeToken()`
- Validates token state (active/ready, no active session, component completeness)
- Updates `flow_token.current_node_id`
- Logs to `token_history`
- Returns `{ok: true, to_node_id: <next_node_id>}`

**Error Cases:**
- `DAG_SESSION_STILL_ACTIVE` - Token has active work session
- `COMPONENT_INCOMPLETE` - Required components not bound
- `DAG_NO_NEXT_NODE` - No valid edge to next node
- `DAG_TOKEN_CLOSED` - Token already completed/cancelled/scrapped

---

### 2. Split Node
**Scenario:** Token reaches a split node, creating multiple child tokens (one per outgoing edge).

**Implementation:**
- Handled by `DAGRoutingService->routeToken()` internally
- `DagExecutionService->moveToNextNode()` calls routing service which handles split logic
- Multiple tokens spawned, each following one edge

**Behavior:**
- Parent token may be consumed or remain active (depends on graph design)
- Child tokens inherit parent's serial/context
- Each child token routes independently

**Note:** Split logic is complex and handled by `DAGRoutingService` internally. `DagExecutionService` provides the gateway but delegates split handling to routing service.

---

### 3. Join Node
**Scenario:** Multiple tokens converge at a join node, waiting for all predecessors to arrive.

**Implementation:**
- Handled by `DAGRoutingService->routeToken()` internally
- Join node waits for all incoming tokens
- When all tokens arrive, they merge or one proceeds

**Behavior:**
- Tokens wait at join node until all predecessors complete
- Join condition validated (all tokens present, all completed)
- After join condition met, token(s) proceed to next node

**Note:** Join logic is complex and handled by `DAGRoutingService` internally. `DagExecutionService` provides the gateway but delegates join handling to routing service.

---

### 4. QC Decision Node
**Scenario:** Token reaches QC node, operator performs QC check (pass/fail), token routes based on result.

**Current Implementation:**
```php
// QC nodes still use DAGRoutingService->handleQCResult() for complex QC logic
if ($tokenInfo['node_type'] === 'qc') {
    $routingResult = $routingService->handleQCResult(
        $tokenId,
        $tokenInfo['current_node_id'],
        $qcPass,
        $qcReason,
        $operatorId
    );
}
```

**Behavior:**
- **Pass:** Routes to normal next node (via normal edge)
- **Fail:** Routes to rework node (via rework edge)
- QC result logged to `dag_behavior_log` and `token_history`

**Future Migration:**
- QC routing may be migrated to `DagExecutionService` in future task
- Current implementation acceptable as QC logic is complex (pass/fail decision, rework path selection)

---

### 5. Rework Node
**Scenario:** Token reaches rework node (from QC fail), routes back to previous operation or designated rework start node.

**Implementation:**
- Handled by `DAGRoutingService->routeToken()` internally
- Rework edges defined in graph (`routing_edge.edge_type = 'rework'`)
- Routing service selects rework edge when token is at rework node

**Behavior:**
- Token routes along rework edge
- May loop back to previous operation or designated rework start
- Rework count tracked (if implemented)

**Note:** Rework logic is handled by `DAGRoutingService` internally. `DagExecutionService` provides the gateway but delegates rework handling to routing service.

---

### 6. End Node
**Scenario:** Token reaches end node, marking completion of the job.

**Implementation:**
```php
if ($node['node_type'] === 'end') {
    $tokenService->completeToken($tokenId, $userId, [
        'completed_by' => $userId,
        'qc_pass' => $qcPass
    ]);
}
```

**Behavior:**
- Token status set to `completed`
- `completed_at` timestamp recorded
- Token removed from active work queue
- Final QC result recorded (if applicable)

**Response:**
- `DagExecutionService->moveToNextNode()` returns `{ok: true, completed: true}` when token reaches end node

---

## Execution Flow

### Standard Flow (Normal Node)
```
1. Operator completes work → handleCompleteToken()
2. Session closed → TokenWorkSessionService->completeToken()
3. Route to next → DagExecutionService->moveToNextNode()
4. Validation checks:
   - Token state (active/ready)
   - No active session
   - Component completeness
5. Find next node → DAGRoutingService->routeToken()
6. Update token → TokenLifecycleService->moveToken()
7. Log event → token_history
8. Return success
```

### QC Flow
```
1. Operator completes QC → handleCompleteToken() with qc_pass
2. Session closed → TokenWorkSessionService->completeToken()
3. Check node type → if 'qc', use DAGRoutingService->handleQCResult()
4. Route based on QC result:
   - Pass → normal next node
   - Fail → rework node
5. Log QC result → dag_behavior_log
6. Return success
```

### Auto-Route from START
```
1. Token spawned → handleTokenSpawn()
2. Check if at START node
3. Auto-route → DagExecutionService->moveToNextNode()
4. Token moves to first operation node
5. Auto-assignment → AssignmentEngine->autoAssignOnSpawn()
```

---

## Error Handling

### Error Codes
- `DAG_TOKEN_NOT_FOUND` - Token ID doesn't exist
- `DAG_TOKEN_CLOSED` - Token already completed/cancelled/scrapped
- `DAG_TOKEN_NOT_ACTIVE` - Token not in active/ready state
- `DAG_SESSION_STILL_ACTIVE` - Token has active work session (must close first)
- `COMPONENT_INCOMPLETE` - Required components not bound
- `DAG_NO_NEXT_NODE` - No valid edge to next node
- `DAG_TOKEN_INVALID` - Token state invalid for routing

### Error Response Format
```json
{
  "ok": false,
  "error": "DAG_SESSION_STILL_ACTIVE",
  "app_code": "DAG_409_SESSION_STILL_ACTIVE",
  "message": "Token has active work session. Session must be closed before routing to next node.",
  "from_node_id": 123,
  "to_node_id": null
}
```

---

## Logging & Telemetry

### Logged Events
- **Token Movement:** `token_history` table
  - `event_type`: `routed`
  - `from_node_id`: Previous node
  - `to_node_id`: New node
  - `routing_source`: `behavior`, `qc`, `supervisor`, `system`
  - `graph_version`: `V2`

- **Behavior Actions:** `dag_behavior_log` table
  - `behavior_code`: Behavior that triggered routing
  - `action`: `complete`, `qc_pass`, `qc_fail`
  - `routing_result`: Result of routing operation

### Metadata Fields
- `routing_source`: Source of routing action
  - `behavior` - From behavior panel
  - `qc` - From QC action
  - `supervisor` - From supervisor override
  - `system` - Auto-routing (START node, background tasks)
- `old_node`: Node ID before move
- `new_node`: Node ID after move
- `graph_version`: Always `V2` for super_dag

---

## Backward Compatibility

### V1 Fallback (Removed in Task 14.1.4)
- **Before:** `DagExecutionService->moveToNextNode()` with fallback to `DAGRoutingService->routeToken()`
- **After:** `DagExecutionService->moveToNextNode()` exclusively, no fallback
- **Rationale:** V2 routing is now stable and handles all scenarios

### V1 Exceptions (Still Used)
- **QC Nodes:** `DAGRoutingService->handleQCResult()` - Complex QC decision logic
- **Metadata APIs:** `dag_routing_api.php` - Graph structure queries (not execution)

---

## Testing Scenarios

### Test Cases
1. **Normal Node Routing:** Token moves from operation node to next operation node
2. **QC Pass:** Token at QC node, operator passes, routes to normal next node
3. **QC Fail:** Token at QC node, operator fails, routes to rework node
4. **End Node:** Token reaches end node, completes successfully
5. **Component Incomplete:** Token routing blocked due to missing components
6. **Active Session:** Token routing blocked due to active work session
7. **Auto-Route START:** Token spawned at START node, auto-routes to first operation node

### Regression Tests
- All existing routing scenarios must continue to work
- No behavior changes observable from client
- Error messages must be clear and actionable
- Logging must capture all routing events

---

## Summary

**Routing V2 Execution Matrix:**
- ✅ Normal nodes: `DagExecutionService->moveToNextNode()`
- ✅ Split/Join nodes: Handled by `DAGRoutingService` internally (via `DagExecutionService`)
- ⚠️ QC nodes: `DAGRoutingService->handleQCResult()` (acceptable, complex logic)
- ✅ End nodes: `TokenLifecycleService->completeToken()`
- ✅ Auto-route START: `DagExecutionService->moveToNextNode()`

**Gateway Pattern:**
- All routing operations go through `DagExecutionService`
- `DagExecutionService` delegates complex logic to `DAGRoutingService` internally
- APIs never call `DAGRoutingService` directly (except QC nodes)

