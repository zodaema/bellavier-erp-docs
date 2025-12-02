# Token Status & Node Type Validation Rules

**Created:** November 15, 2025  
**Purpose:** Definitive validation rules for token actions and status transitions  
**Status:** 📋 **CRITICAL** - Required for Phase 2B.5 implementation  
**Audience:** AI Agents, Developers, QA

---

## ⚠️ IMPORTANT

**These validation rules MUST be enforced at both API and Frontend levels.**

Violations indicate bugs or security issues.

---

## 🔒 Core Validation Rules

### **Rule 1: Node Type → Action Validation**

**Principle:** Each node type only allows specific actions.

**Validation Table:**

| node_type | Allowed Actions | Forbidden Actions |
|-----------|----------------|-------------------|
| `start` | `[]` (none) | ALL actions |
| `operation` | `start`, `pause`, `resume`, `complete` | `pass`, `fail`, `qc_pass`, `qc_fail` |
| `qc` | `pass`, `fail` | `start`, `pause`, `resume`, `complete` |
| `split` | `[]` (none) | ALL actions |
| `join` | `[]` (none) | ALL actions |
| `end` | `[]` (none) | ALL actions |
| `decision` | `submit_form` (if form required) | `start`, `pause`, `complete` |
| `system` | `[]` (none) | ALL actions |
| `wait` | `notify_complete` (if notification required) | `start`, `pause`, `complete` |

**Implementation:**
```php
// In dag_token_api.php - Before executing any action
function validateActionForNodeType($nodeType, $action) {
    $allowedActions = [
        'start' => [],
        'operation' => ['start', 'pause', 'resume', 'complete'],
        'qc' => ['pass', 'fail'],
        'split' => [],
        'join' => [],
        'end' => [],
        'decision' => ['submit_form'], // Only if form_schema_json exists
        'system' => [],
        'wait' => ['notify_complete'] // Only if notification required
    ];
    
    if (!isset($allowedActions[$nodeType])) {
        throw new Exception("Unknown node type: {$nodeType}");
    }
    
    if (!in_array($action, $allowedActions[$nodeType])) {
        throw new Exception("Action '{$action}' not allowed for node type '{$nodeType}'");
    }
    
    return true;
}
```

---

### **Rule 2: Token Status → Action Validation**

**Principle:** Actions can only be executed in specific token statuses.

**Validation Table:**

| Token Status | Allowed Actions | Notes |
|-------------|----------------|-------|
| `ready` | `start` (operation), `pass`/`fail` (qc) | Token ready to start work |
| `active` | `pause`, `complete` (operation), `pass`/`fail` (qc) | Work in progress |
| `paused` | `resume`, `complete` (operation) | Work paused |
| `waiting` | `[]` (none) | Waiting for join condition or capacity |
| `completed` | `[]` (none) | Work completed |
| `scrapped` | `[]` (none) | Token scrapped (defective) |

**Implementation:**
```php
// In dag_token_api.php - Before executing action
function validateActionForStatus($status, $action, $nodeType) {
    $statusActionMap = [
        'ready' => [
            'operation' => ['start'],
            'qc' => ['pass', 'fail']
        ],
        'active' => [
            'operation' => ['pause', 'complete'],
            'qc' => ['pass', 'fail']
        ],
        'paused' => [
            'operation' => ['resume', 'complete']
        ],
        'waiting' => [],
        'completed' => [],
        'scrapped' => []
    ];
    
    if (!isset($statusActionMap[$status])) {
        throw new Exception("Unknown status: {$status}");
    }
    
    $allowedForStatus = $statusActionMap[$status][$nodeType] ?? [];
    
    if (!in_array($action, $allowedForStatus)) {
        throw new Exception("Action '{$action}' not allowed for status '{$status}' on node type '{$nodeType}'");
    }
    
    return true;
}
```

---

### **Rule 3: Node Type → Status Transition Validation**

**Principle:** Status transitions must follow valid paths for each node type.

**Validation Table:**

| node_type | Valid Status Transitions |
|-----------|-------------------------|
| `operation` | `ready` → `active` → `completed` → `routed`<br>`active` → `paused` → `active` |
| `qc` | `ready` → `qc_pass` → `routed`<br>`ready` → `qc_fail` → `routed` |
| `join` | `ready` → `waiting` → `active` → `routed` |
| `split` | `ready` → `routed` (spawns children) |
| `end` | `ready` → `completed` |

**Implementation:**
```php
// In DAGRoutingService - Before changing status
function validateStatusTransition($currentStatus, $newStatus, $nodeType) {
    $validTransitions = [
        'operation' => [
            'ready' => ['active'],
            'active' => ['paused', 'completed'],
            'paused' => ['active', 'completed'],
            'completed' => ['routed']
        ],
        'qc' => [
            'ready' => ['qc_pass', 'qc_fail'],
            'qc_pass' => ['routed'],
            'qc_fail' => ['routed']
        ],
        'join' => [
            'ready' => ['waiting'],
            'waiting' => ['active'],
            'active' => ['routed']
        ],
        'split' => [
            'ready' => ['routed']
        ],
        'end' => [
            'ready' => ['completed']
        ]
    ];
    
    if (!isset($validTransitions[$nodeType][$currentStatus])) {
        throw new Exception("Invalid current status '{$currentStatus}' for node type '{$nodeType}'");
    }
    
    if (!in_array($newStatus, $validTransitions[$nodeType][$currentStatus])) {
        throw new Exception("Invalid transition from '{$currentStatus}' to '{$newStatus}' for node type '{$nodeType}'");
    }
    
    return true;
}
```

---

### **Rule 4: Visibility Validation**

**Principle:** Non-operable nodes must not appear in Work Queue or PWA.

**Validation:**

| node_type | Visible in Work Queue? | Visible in PWA? |
|-----------|------------------------|-----------------|
| `start` | ❌ NO | ❌ NO |
| `operation` | ✅ YES | ✅ YES |
| `qc` | ✅ YES | ✅ YES |
| `split` | ❌ NO | ❌ NO |
| `join` | ⚠️ INFO ONLY | ❌ NO |
| `end` | ❌ NO | ❌ NO |
| `system` | ❌ NO | ❌ NO |

**Implementation:**
```php
// In handleGetWorkQueue() - Filter non-operable nodes
$sql = "
    SELECT ft.*, rn.node_type
    FROM flow_token ft
    INNER JOIN routing_node rn ON rn.id_node = ft.current_node_id
    WHERE ft.status IN ('ready', 'active', 'paused')
        AND rn.node_type IN ('operation', 'qc')  -- ✅ Only operable nodes
        AND rn.node_type != 'system'  -- ✅ Hide system nodes
    ...
";
```

```javascript
// In work_queue.js - Filter before rendering
function renderWorkQueue(nodes) {
    const operableNodes = nodes.filter(node => {
        const nodeType = node.node_type || 'operation';
        return ['operation', 'qc'].includes(nodeType);
    });
    
    // Render only operable nodes
    renderKanbanView(operableNodes, $container);
}
```

---

### **Rule 5: QC Node Action Validation**

**Principle:** QC nodes ONLY allow Pass/Fail actions, never Start/Pause/Complete.

**Validation:**
```php
// In handleStartToken() - Reject if QC node
if ($node['node_type'] === 'qc') {
    json_error('Cannot start work on QC node. Use Pass/Fail actions instead.', 400);
}

// In handleCompleteToken() - Reject if QC node (unless already passed/failed)
if ($node['node_type'] === 'qc' && !isset($_POST['qc_pass'])) {
    json_error('Cannot complete QC node. Use Pass/Fail actions instead.', 400);
}
```

```javascript
// In renderKanbanTokenCard() - Never show Start/Pause/Complete for QC
if (nodeType === 'qc') {
    // ✅ CORRECT: Show Pass/Fail only
    actionButtons = `
        <button class="btn-qc-pass">Pass</button>
        <button class="btn-qc-fail">Fail</button>
    `;
    
    // ❌ WRONG: Never show these
    // actionButtons = '<button class="btn-start">Start</button>'; // ❌
}
```

---

### **Rule 6: JOIN Node Token Validation**

**Principle:** Tokens at JOIN nodes cannot be operated on until join condition is met.

**Validation:**
```php
// In handleStartToken() - Reject if JOIN node
if ($node['node_type'] === 'join') {
    json_error('Cannot start work on JOIN node. Token will activate automatically when join condition is met.', 400);
}

// In handleCompleteToken() - Reject if JOIN node (unless join ready)
if ($node['node_type'] === 'join' && $token['status'] === 'waiting') {
    json_error('Cannot complete JOIN node. Token will activate automatically when all inputs arrive.', 400);
}
```

**Display Rules:**
- Show JOIN tokens in "Waiting" section (informational)
- Display join status (arrived_count / required_count)
- NO action buttons
- NO Start/Pause/Complete buttons

---

### **Rule 7: SPLIT Node Token Validation**

**Principle:** Tokens at SPLIT nodes cannot be operated on (system-controlled).

**Validation:**
```php
// In handleStartToken() - Reject if SPLIT node
if ($node['node_type'] === 'split') {
    json_error('Cannot start work on SPLIT node. Split happens automatically.', 400);
}

// Tokens at SPLIT nodes should not appear in Work Queue at all
// (filtered out by API)
```

---

### **Rule 8: END Node Token Validation**

**Principle:** Tokens at END nodes automatically complete (no operator action).

**Validation:**
```php
// In handleCompleteToken() - Auto-complete if END node
if ($node['node_type'] === 'end') {
    // Token should already be completed automatically
    // This is a safety check
    if ($token['status'] !== 'completed') {
        // Auto-complete it
        $tokenService->completeToken($tokenId, $operatorId);
    }
    json_success(['message' => 'Token completed at END node']);
    return;
}
```

---

### **Rule 9: START Node Token Validation**

**Principle:** Tokens at START nodes automatically route (no operator action).

**Validation:**
```php
// Tokens should never be at START node in Work Queue
// (they auto-route immediately)

// Safety check: If token somehow stuck at START node
if ($node['node_type'] === 'start') {
    // Auto-route to next node
    $routingService->routeToken($tokenId);
    json_success(['message' => 'Token auto-routed from START node']);
    return;
}
```

---

### **Rule 10: Session Validation**

**Principle:** Work sessions can only exist for operable nodes.

**Validation:**
```php
// In TokenWorkSessionService::startToken() - Validate node type
function startToken($tokenId, $operatorId) {
    $token = getToken($tokenId);
    $node = getNode($token['current_node_id']);
    
    // Only operation nodes can have work sessions
    if ($node['node_type'] !== 'operation') {
        throw new Exception("Cannot start work session on node type '{$node['node_type']}'. Only 'operation' nodes support work sessions.");
    }
    
    // ... rest of start logic ...
}
```

---

## 🚨 Common Validation Errors

### **Error 1: Operator tries to Start QC node**
```
Error: "Cannot start work on QC node. Use Pass/Fail actions instead."
Status: 400 Bad Request
Fix: Show Pass/Fail buttons instead of Start button
```

### **Error 2: Operator tries to Complete JOIN node**
```
Error: "Cannot complete JOIN node. Token will activate automatically when all inputs arrive."
Status: 400 Bad Request
Fix: Hide JOIN nodes from Work Queue (or show as informational only)
```

### **Error 3: Operator tries to Pause QC node**
```
Error: "Action 'pause' not allowed for node type 'qc'"
Status: 400 Bad Request
Fix: Never show Pause button for QC nodes
```

### **Error 4: Token at SPLIT node appears in Work Queue**
```
Error: "Token should not appear in Work Queue at SPLIT node"
Status: Data inconsistency
Fix: Filter SPLIT nodes in handleGetWorkQueue()
```

### **Error 5: Token at END node has active session**
```
Error: "Cannot have active session at END node"
Status: Data inconsistency
Fix: Auto-complete token when it reaches END node
```

---

## 📋 Implementation Checklist

### **API Level (`dag_token_api.php`):**
- [ ] Add `validateActionForNodeType()` function
- [ ] Add `validateActionForStatus()` function
- [ ] Add `validateStatusTransition()` function
- [ ] Call validation before executing any action
- [ ] Return clear error messages for violations

### **Frontend Level (`work_queue.js`, `pwa_scan.js`):**
- [ ] Validate node_type before rendering actions
- [ ] Hide invalid actions based on node_type
- [ ] Show error messages if validation fails
- [ ] Prevent invalid actions from being sent to API

### **Service Level (`DAGRoutingService`, `TokenLifecycleService`):**
- [ ] Validate status transitions before changing status
- [ ] Validate node type before creating sessions
- [ ] Auto-route tokens at START/END nodes
- [ ] Auto-complete tokens at END nodes

---

## 🎯 Acceptance Criteria

- [ ] All actions validated at API level
- [ ] All actions validated at Frontend level
- [ ] Clear error messages for violations
- [ ] No invalid actions can be executed
- [ ] No invalid status transitions can occur
- [ ] Non-operable nodes filtered correctly
- [ ] QC nodes only show Pass/Fail actions
- [ ] Operation nodes only show Start/Pause/Complete actions
- [ ] JOIN/SPLIT/START/END nodes hidden from Work Queue

---

## 📝 Related Documents

- `NODE_TYPE_POLICY.md` - Node type policy matrix
- `DAG_IMPLEMENTATION_ROADMAP.md` - Phase 2B.5 specification
- `WORK_QUEUE_OPERATOR_JOURNEY.md` - Work Queue UX design

---

**Document Status:** ✅ **COMPLETE** - Ready for Implementation  
**Last Updated:** November 15, 2025

