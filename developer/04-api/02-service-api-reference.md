# 🔧 Service Layer API Reference

**Purpose:** Quick reference for all services & APIs  
**Last Updated:** January 2025  
**Location:** `source/BGERP/Service/` + `source/BGERP/*/`  
**Namespace:** `BGERP\Service`, `BGERP\Dag`, `BGERP\MO`, `BGERP\Component`, `BGERP\Product`

---

## 🎯 **Service Overview**

**Total Services:** 48 services + 26 DAG engines + 6 MO services + 4 Component services + 1 Product service = 85 services/engines

**Core Services (10 services):**

| Service | Purpose | When to Use |
|---------|---------|-------------|
| OperatorSessionService | Manage operator work sessions | After ANY WIP log change |
| JobTicketStatusService | Update job/task status | After WIP log change |
| ValidationService | Validate inputs | Before saving data |
| ErrorHandler | Handle exceptions | Wrap risky operations |
| DatabaseTransaction | Manage transactions | Multi-step operations |
| SecureSerialGenerator | Generate secure serials | Job ticket creation (piece mode) |
| PermissionEngine ⭐ (NEW Dec 9) | Token-level permissions | Work Queue action checks |
| DAGValidationService ⭐ | Validate DAG graphs | Graph creation/editing |
| DAGRoutingService ⭐ | Route tokens through DAG | Token movements |
| TokenLifecycleService ⭐ | Manage token lifecycle | Spawn/move/complete tokens |

---

## 👤 **OperatorSessionService**

**File:** `source/service/OperatorSessionService.php`  
**Namespace:** `BGERP\Service\OperatorSessionService`

### **Constructor:**

```php
$service = new \BGERP\Service\OperatorSessionService($tenantDb);
```

**Parameters:**
- `$tenantDb` (mysqli) - Tenant database connection

---

### **handleWIPEvent()** - Handle WIP Log Event

```php
$service->handleWIPEvent($taskId, $operatorId, $eventType, $qty, $operatorName);
```

**When to call:** After WIP log **INSERT**

**Parameters:**
- `$taskId` (int) - Job task ID
- `$operatorId` (int) - Operator user ID
- `$eventType` (string) - Event type (start, complete, hold, resume)
- `$qty` (float) - Quantity (for complete events)
- `$operatorName` (string) - Operator display name

**Returns:** void

**Example:**
```php
// After inserting WIP log
$sessionService = new \BGERP\Service\OperatorSessionService($tenantDb);
$sessionService->handleWIPEvent(
    $taskId,
    $operatorUserId,
    'complete',
    25.5,
    'คุณแดง'
);
```

---

### **rebuildSessionsFromLogs()** - Rebuild Sessions from Logs

```php
$service->rebuildSessionsFromLogs($taskId);
```

**When to call:** After WIP log **DELETE** or **UPDATE**

**Parameters:**
- `$taskId` (int) - Job task ID

**Returns:** void

**What it does:**
1. Deletes all sessions for task
2. Reads all non-deleted WIP logs
3. Reconstructs sessions from scratch
4. Ensures data integrity

**Example:**
```php
// After deleting WIP log
$sessionService = new \BGERP\Service\OperatorSessionService($tenantDb);
$sessionService->rebuildSessionsFromLogs($taskId);
```

---

### **rebuildSessionsForTicket()** - Rebuild All Sessions for Ticket

```php
$service->rebuildSessionsForTicket($ticketId);
```

**When to call:** Manual recalculation trigger

**Parameters:**
- `$ticketId` (int) - Job ticket ID

**Returns:** void

**Use case:** Batch rebuild for entire ticket

---

### **hasActiveSessions()** - Check Active Sessions

```php
$hasActive = $service->hasActiveSessions($taskId);
```

**Parameters:**
- `$taskId` (int) - Job task ID

**Returns:** bool

**Use case:** Check if anyone is currently working

---

### **getTotalCompletedQty()** - Get Completed Quantity

```php
$qty = $service->getTotalCompletedQty($taskId);
```

**Parameters:**
- `$taskId` (int) - Job task ID

**Returns:** float

**Use case:** Calculate progress

---

## 📊 **JobTicketStatusService**

**File:** `source/service/JobTicketStatusService.php`  
**Namespace:** `BGERP\Service\JobTicketStatusService`

### **Constructor:**

```php
$service = new \BGERP\Service\JobTicketStatusService($tenantDb, $member);
```

**Parameters:**
- `$tenantDb` (mysqli) - Tenant database connection
- `$member` (array) - Current user from `thisLogin()`

---

### **updateAfterLog()** - Update Status After WIP Log

```php
$service->updateAfterLog($ticketId, $taskId, $eventType, $qty);
```

**When to call:** After WIP log change (insert/update/delete)

**Parameters:**
- `$ticketId` (int) - Job ticket ID
- `$taskId` (int) - Job task ID  
- `$eventType` (string) - Event type (start, complete, hold, etc.)
- `$qty` (float|null) - Quantity (for complete events)

**Returns:** void

**What it does:**
1. Updates task status based on event
2. Updates ticket status (aggregates from tasks)
3. Optionally updates MO status

**Example:**
```php
$statusService = new \BGERP\Service\JobTicketStatusService($tenantDb, $member);
$statusService->updateAfterLog($ticketId, $taskId, 'complete', 25);
```

---

### **updateAfterTicketSave()** - Update After Ticket Save

```php
$service->updateAfterTicketSave($ticketId);
```

**When to call:** After creating/updating job ticket

**Parameters:**
- `$ticketId` (int) - Job ticket ID

**Returns:** void

---

### **refreshMoStatus()** - Refresh MO Status

```php
$service->refreshMoStatus($moId, $sourceEvent);
```

**When to call:** When job ticket status changes

**Parameters:**
- `$moId` (int) - Manufacturing Order ID
- `sourceEvent` (string) - Event that triggered refresh

**Returns:** void

---

## ✅ **ValidationService**

**File:** `source/service/ValidationService.php`  
**Namespace:** `BGERP\Service\ValidationService`

**All methods are STATIC**

---

### **validateJobTicket()** - Validate Ticket Data

```php
$validation = \BGERP\Service\ValidationService::validateJobTicket($data, $isUpdate);
```

**Parameters:**
- `$data` (array) - Ticket data from $_POST
- `$isUpdate` (bool) - true if updating existing ticket

**Returns:**
```php
[
    'valid' => bool,
    'errors' => array  // Empty if valid
]
```

**Example:**
```php
$validation = \BGERP\Service\ValidationService::validateJobTicket($_POST, false);
if (!$validation['valid']) {
    json_error(implode(', ', $validation['errors']), 400);
}
```

---

### **validateJobTask()** - Validate Task Data

```php
$validation = \BGERP\Service\ValidationService::validateJobTask($data, $ticketTargetQty);
```

**Parameters:**
- `$data` (array) - Task data
- `$ticketTargetQty` (float) - Ticket target quantity (for validation)

**Returns:** Same as validateJobTicket

---

### **validateWIPLog()** - Validate WIP Log Data

```php
$validation = \BGERP\Service\ValidationService::validateWIPLog($data, $task, $ticket);
```

**Parameters:**
- `$data` (array) - WIP log data
- `$task` (array) - Task info
- `$ticket` (array) - Ticket info

**Returns:** Same as validateJobTicket

**Validates:**
- Event type valid
- Qty positive (for complete events)
- Not exceeding tolerance (5%)
- Piece mode: qty = 1, serial required
- Serial not duplicate (same task)

---

### **validateStatusTransition()** - Validate Status Change

```php
$validation = \BGERP\Service\ValidationService::validateStatusTransition($currentStatus, $newStatus);
```

**Parameters:**
- `$currentStatus` (string) - Current status
- `$newStatus` (string) - Desired status

**Returns:** Same as validateJobTicket

**Validates:** State machine rules (e.g., can't go pending → completed)

---

### **sanitizeInt()** - Sanitize Integer

```php
$value = \BGERP\Service\ValidationService::sanitizeInt($input, $min, $max);
```

**Parameters:**
- `$input` (mixed) - Input value
- `$min` (int) - Minimum allowed (default 1)
- `$max` (int) - Maximum allowed (default 999999)

**Returns:** int (or throws if invalid)

---

### **sanitizeFloat()** - Sanitize Float

```php
$value = \BGERP\Service\ValidationService::sanitizeFloat($input, $min, $max, $decimals);
```

**Parameters:**
- `$input` (mixed) - Input value
- `$min` (float) - Minimum allowed
- `$max` (float) - Maximum allowed
- `$decimals` (int) - Decimal places

**Returns:** float

---

### **sanitizeString()** - Sanitize String

```php
$value = \BGERP\Service\ValidationService::sanitizeString($input, $maxLength);
```

**Parameters:**
- `$input` (mixed) - Input value
- `maxLength` (int) - Maximum length (default 255)

**Returns:** string (trimmed, escaped)

---

## 🛡️ **ErrorHandler**

**File:** `source/service/ErrorHandler.php`  
**Namespace:** `BGERP\Service\ErrorHandler`

### **handle()** - Handle Exception

```php
\BGERP\Service\ErrorHandler::handle($exception, $sendResponse);
```

**Parameters:**
- `$exception` (Throwable) - Exception to handle
- `$sendResponse` (bool) - Send JSON response? (default true)

**Returns:** void

**Example:**
```php
try {
    // Risky operation
} catch (\Throwable $e) {
    \BGERP\Service\ErrorHandler::handle($e, true);
}
```

---

### **wrap()** - Wrap Code with Error Handling

```php
$result = \BGERP\Service\ErrorHandler::wrap(function() {
    // Your code
    return $result;
});
```

**Parameters:**
- `$callback` (Closure) - Code to wrap

**Returns:** mixed (callback return value)

**Example:**
```php
$result = \BGERP\Service\ErrorHandler::wrap(function() use ($db, $data) {
    // Complex operation
    $id = save_ticket($db, $data);
    return $id;
});
```

---

## 💾 **DatabaseTransaction**

**File:** `source/service/DatabaseTransaction.php`  
**Namespace:** `BGERP\Service\DatabaseTransaction`

### **Constructor:**

```php
$transaction = new \BGERP\Service\DatabaseTransaction($db);
```

**Parameters:**
- `$db` (mysqli) - Database connection

---

### **execute()** - Execute in Transaction

```php
$result = $transaction->execute(function($db) {
    // Multi-step operations
    // All or nothing!
    return $result;
});
```

**Parameters:**
- `$callback` (Closure) - Operations to execute
- `$isolationLevel` (string) - Optional: SERIALIZABLE, REPEATABLE READ, etc.

**Returns:** mixed (callback return value)

**Example:**
```php
$transaction = new \BGERP\Service\DatabaseTransaction($tenantDb);

$ticketId = $transaction->execute(function($db) use ($data, $member) {
    // Step 1: Insert ticket
    $stmt = $db->prepare("INSERT INTO atelier_job_ticket ...");
    $stmt->execute();
    $ticketId = $stmt->insert_id;
    
    // Step 2: Insert tasks
    foreach ($tasks as $task) {
        $stmt = $db->prepare("INSERT INTO atelier_job_task ...");
        $stmt->execute();
    }
    
    // If any step fails → auto rollback!
    return $ticketId;
});
```

---

## 🔄 **Service Integration Pattern**

### **After WIP Log INSERT:**

```php
// 1. Insert WIP log
$stmt = $db->prepare("INSERT INTO atelier_wip_log ...");
$stmt->execute();

// 2. Update sessions
if ($taskId && $operatorUserId) {
    $sessionService = new \BGERP\Service\OperatorSessionService($tenantDb);
    $sessionService->handleWIPEvent($taskId, $operatorUserId, $eventType, $qty, $operatorName);
}

// 3. Update statuses
$statusService = new \BGERP\Service\JobTicketStatusService($tenantDb, $member);
$statusService->updateAfterLog($ticketId, $taskId, $eventType, $qty);
```

---

### **After WIP Log DELETE:**

```php
// 1. Soft-delete log
$stmt = $db->prepare("UPDATE atelier_wip_log SET deleted_at=NOW(), deleted_by=? WHERE id_wip_log=?");
$stmt->execute();

// 2. CRITICAL: Rebuild sessions
if ($taskId) {
    $sessionService = new \BGERP\Service\OperatorSessionService($tenantDb);
    $sessionService->rebuildSessionsFromLogs((int)$taskId);
}

// 3. Update statuses
$statusService = new \BGERP\Service\JobTicketStatusService($tenantDb, $member);
$statusService->updateAfterLog($ticketId, $taskId, 'delete', null);

// 4. Fallback (safety net)
update_task_status_from_logs($tenantDb, $taskId);
recalc_job_ticket_status($tenantDb, $ticketId);
```

---

### **After WIP Log UPDATE:**

```php
// Same as DELETE:
// 1. Update the log
// 2. rebuildSessionsFromLogs($taskId)
// 3. updateAfterLog()
// 4. Fallback status updates
```

---

## 🚨 **Critical Service Rules**

### **1. Service Order Matters!**

```
✅ CORRECT:
1. OperatorSessionService->handleWIPEvent() or rebuildSessionsFromLogs()
2. JobTicketStatusService->updateAfterLog()

❌ WRONG:
1. JobTicketStatusService->updateAfterLog()
2. OperatorSessionService->handleWIPEvent()
-- Wrong order = wrong progress calculation!
```

---

### **2. Always Load Services:**

```php
// At top of API file
require_once __DIR__ . '/service/OperatorSessionService.php';
require_once __DIR__ . '/service/JobTicketStatusService.php';
require_once __DIR__ . '/service/ValidationService.php';
require_once __DIR__ . '/service/ErrorHandler.php';
require_once __DIR__ . '/exception/JobTicketException.php';
```

---

### **3. Handle Service Exceptions:**

```php
try {
    $sessionService->handleWIPEvent(...);
    $statusService->updateAfterLog(...);
} catch (\Throwable $e) {
    error_log("Service error: " . $e->getMessage());
    json_error($e->getMessage(), 500);
}
```

**❌ NEVER silent catch:**
```php
try {
    $sessionService->handleWIPEvent(...);
} catch (\Throwable $e) {
    // ignore ← DATA CORRUPTION!
}
```

---

## 📋 **Service Usage Checklist**

### **Before Using Services:**
- [ ] Load with `require_once` at API file top
- [ ] Initialize with correct parameters ($db, $member)
- [ ] Verify table structure (if modifying data)

### **When Using Services:**
- [ ] Call in correct order (Session → Status)
- [ ] Pass all required parameters
- [ ] Wrap in try-catch
- [ ] Log errors (not silent)

### **After Using Services:**
- [ ] Verify data integrity (check database)
- [ ] Test status cascade (ticket, task, sessions)
- [ ] Check fallback functions called (if delete/update)

---

## 🎯 **Common Patterns**

### **Pattern 1: WIP Log Save (New)**

```php
case 'log_save':
    // 1. Validate
    $validation = \BGERP\Service\ValidationService::validateWIPLog($_POST, $task, $ticket);
    if (!$validation['valid']) {
        json_error(implode(', ', $validation['errors']), 400);
    }
    
    // 2. Use transaction
    $transaction = new \BGERP\Service\DatabaseTransaction($tenantDb);
    $logId = $transaction->execute(function($db) use ($data, $taskId, $operatorId) {
        // Insert WIP log
        $stmt = $db->prepare("INSERT INTO atelier_wip_log ...");
        $stmt->execute();
        $logId = $stmt->insert_id;
        
        // Update sessions
        $sessionService = new \BGERP\Service\OperatorSessionService($db);
        $sessionService->handleWIPEvent($taskId, $operatorId, $eventType, $qty, $operator);
        
        // Update statuses
        $statusService = new \BGERP\Service\JobTicketStatusService($db, $GLOBALS['member']);
        $statusService->updateAfterLog($ticketId, $taskId, $eventType, $qty);
        
        return $logId;
    });
    
    json_success(['id' => $logId]);
    break;
```

---

### **Pattern 2: WIP Log Delete**

```php
case 'log_delete':
    $idLog = (int)($_POST['id'] ?? 0);
    
    // Fetch log first
    $log = db_fetch_one($tenantDb, "
        SELECT id_job_ticket, id_job_task 
        FROM atelier_wip_log 
        WHERE id_wip_log = ?
    ", [$idLog]);
    
    if (!$log) {
        json_error('Log not found', 404);
    }
    
    // Soft-delete
    $stmt = $tenantDb->prepare("
        UPDATE atelier_wip_log 
        SET deleted_at = NOW(), deleted_by = ? 
        WHERE id_wip_log = ?
    ");
    $stmt->bind_param('ii', $member['id_member'], $idLog);
    $stmt->execute();
    
    // CRITICAL: Rebuild sessions
    $sessionService = new \BGERP\Service\OperatorSessionService($tenantDb);
    $sessionService->rebuildSessionsFromLogs((int)$log['id_job_task']);
    
    // Update statuses
    $statusService = new \BGERP\Service\JobTicketStatusService($tenantDb, $member);
    $statusService->updateAfterLog($log['id_job_ticket'], $log['id_job_task'], 'delete', null);
    
    // Fallback
    update_task_status_from_logs($tenantDb, $log['id_job_task']);
    recalc_job_ticket_status($tenantDb, $log['id_job_ticket']);
    
    json_success(['message' => 'Log deleted']);
    break;
```

---

### **Pattern 3: Manual Recalculation**

```php
case 'recalc_sessions':
    $ticketId = (int)($_POST['id_job_ticket'] ?? 0);
    
    $sessionService = new \BGERP\Service\OperatorSessionService($tenantDb);
    $sessionService->rebuildSessionsForTicket($ticketId);
    
    $statusService = new \BGERP\Service\JobTicketStatusService($tenantDb, $member);
    $statusService->updateAfterTicketSave($ticketId);
    
    json_success(['message' => 'Recalculated']);
    break;
```

---

## 🎯 **Quick Answers**

| Question | Answer |
|----------|--------|
| Which service to call first? | **OperatorSessionService** (always!) |
| When to rebuild sessions? | **After log delete/update** |
| When to use handleWIPEvent? | **After log insert** |
| How to validate input? | **ValidationService::validateWIPLog()** |
| How to handle errors? | **ErrorHandler::handle() or wrap()** |
| How to use transaction? | **DatabaseTransaction->execute()** |
| What if service fails? | **Log error, throw exception (don't ignore!)** |

---

## ⚠️ **Common Mistakes**

### **1. Wrong Service Order:**

```php
❌ WRONG:
$statusService->updateAfterLog(...);  // Status first
$sessionService->handleWIPEvent(...); // Session second
// Result: Wrong progress because sessions not updated yet!

✅ CORRECT:
$sessionService->handleWIPEvent(...);  // Session first
$statusService->updateAfterLog(...);   // Status second (uses sessions)
```

---

### **2. Forgetting Rebuild After Delete:**

```php
❌ WRONG:
UPDATE atelier_wip_log SET deleted_at = NOW() ...
// No rebuild → sessions still include deleted log!

✅ CORRECT:
UPDATE atelier_wip_log SET deleted_at = NOW() ...
$sessionService->rebuildSessionsFromLogs($taskId);
```

---

### **3. Silent Service Failure:**

```php
❌ WRONG:
try {
    $sessionService->handleWIPEvent(...);
} catch (\Throwable $e) {
    // Do nothing ← Silent failure!
}

✅ CORRECT:
try {
    $sessionService->handleWIPEvent(...);
} catch (\Throwable $e) {
    error_log("Session service error: " . $e->getMessage());
    json_error('Failed to update sessions: ' . $e->getMessage(), 500);
}
```

---

## 🔐 **SecureSerialGenerator**

**File:** `source/service/SecureSerialGenerator.php`  
**Namespace:** `BGERP\Service\SecureSerialGenerator`  
**Created:** November 1, 2025

**All methods are STATIC**

### **generate()**

Generate cryptographically secure serial number.

**Parameters:**
- `string $prefix` - SKU or component type (e.g., 'TOTE', 'BODY')
- `mysqli $db` - Database connection
- `int $maxRetries` - Max retry attempts (default: 10)

**Returns:** `string` - Generated serial (e.g., 'TOTE-2025-A7F3C9')

**Example:**
```php
$db = tenant_db();
$serial = \BGERP\Service\SecureSerialGenerator::generate('TOTE', $db);
// Returns: TOTE-2025-A7F3C9 (cryptographically random)
```

---

### **bulkGenerate()**

Generate multiple serials at once.

**Parameters:**
- `string $prefix` - SKU prefix
- `int $count` - How many to generate (max: 1000)
- `mysqli $db` - Database connection

**Returns:** `array` - Array of generated serials

**Example:**
```php
$serials = \BGERP\Service\SecureSerialGenerator::bulkGenerate('WALLET', 10, $db);
// Returns: ['WALLET-2025-A7F3C9', 'WALLET-2025-B2E1D5', ...]
```

---

### **validateFormat()**

Validate serial format (static validation, no DB query).

**Parameters:**
- `string $serial` - Serial to validate

**Returns:** `bool` - True if valid format

**Format:** `{PREFIX}-{YEAR}-{HASH-6}`

**Example:**
```php
$isValid = \BGERP\Service\SecureSerialGenerator::validateFormat('TOTE-2025-A7F3C9');
// Returns: true

$isValid = \BGERP\Service\SecureSerialGenerator::validateFormat('TOTE-001');
// Returns: false (no hash)
```

---

### **generateQRPayload()**

Generate QR code payload with verification hash.

**Parameters:**
- `string $serial` - Serial number
- `int $ticketId` - Job ticket ID
- `int $taskId` - Job task ID

**Returns:** `string` - JSON payload with HMAC hash

**Example:**
```php
$payload = \BGERP\Service\SecureSerialGenerator::generateQRPayload(
    'TOTE-2025-A7F3C9', 
    10, 
    6
);
// Returns: {"type":"work_piece","serial":"TOTE-2025-A7F3C9","hash":"..."}
```

---

### **verifyQRPayload()**

Verify QR payload authenticity (anti-tampering).

**Parameters:**
- `string $payload` - JSON payload from QR scan

**Returns:** `array` - ['valid' => bool, 'data' => array|null, 'reason' => string|null]

**Example:**
```php
$verification = \BGERP\Service\SecureSerialGenerator::verifyQRPayload($scannedPayload);

if ($verification['valid']) {
    $serial = $verification['data']['serial'];
    // Proceed with authentic data
} else {
    // Reject tampered/fake QR
    error_log("QR tampering detected: " . $verification['reason']);
}
```

---

## 🚀 **DAGValidationService** ⭐ **(NEW - Nov 2, 2025)**

**File:** `source/service/DAGValidationService.php`  
**Namespace:** `BGERP\Service\DAGValidationService`  
**Purpose:** Validate DAG graph structure and business rules

### **Constructor:**

```php
$service = new \BGERP\Service\DAGValidationService($tenantDb);
```

---

### **hasCycle()** - Detect Cycles in Graph

```php
$hasCycle = $service->hasCycle($graphId);
```

**Purpose:** Detect cycles in the graph (excluding rework edges)

**Parameters:**
- `int $graphId` - Graph ID to validate

**Returns:** `bool` - true if cycle detected, false otherwise

**Notes:**
- Rework edges are excluded from cycle detection (intentional loops)
- Uses Depth-First Search (DFS) algorithm

**Example:**
```php
if ($service->hasCycle(1)) {
    json_error('Graph contains cycle (not allowed except for rework edges)', 400);
}
```

---

### **validateGraph()** - Comprehensive Graph Validation

```php
$result = $service->validateGraph($graphId);
```

**Purpose:** Validate all aspects of the graph (structure, nodes, edges, joins)

**Parameters:**
- `int $graphId` - Graph ID to validate

**Returns:** `array` - ['valid' => bool, 'errors' => array]

**Validation Checks:**
- Exactly 1 start node and 1 end node
- All nodes have at least 1 connection
- No cycles (except rework edges)
- Join nodes have proper configuration
- All edges connect valid nodes

**Example:**
```php
$validation = $service->validateGraph(1);
if (!$validation['valid']) {
    json_error('Graph validation failed: ' . implode(', ', $validation['errors']), 400);
}
```

---

### **canPublishGraph()** - Check if Graph is Publishable

```php
$canPublish = $service->canPublishGraph($graphId);
```

**Purpose:** Determine if graph meets all requirements for publishing

**Parameters:**
- `int $graphId` - Graph ID to check

**Returns:** `array` - ['can_publish' => bool, 'reasons' => array]

**Requirements:**
- Graph must pass validateGraph()
- Must have at least 1 operation node
- All nodes must be properly configured

---

## 🔀 **DAGRoutingService** ⭐ **(NEW - Nov 2, 2025)**

**File:** `source/service/DAGRoutingService.php`  
**Namespace:** `BGERP\Service\DAGRoutingService`  
**Purpose:** Route tokens through the DAG graph

### **Constructor:**

```php
$service = new \BGERP\Service\DAGRoutingService($tenantDb);
```

---

### **routeToken()** - Route Token to Next Node

```php
$nextNodes = $service->routeToken($tokenId, $currentNodeId);
```

**Purpose:** Determine next nodes for token based on current node type

**Parameters:**
- `int $tokenId` - Token to route
- `int $currentNodeId` - Current node instance ID

**Returns:** `array` - List of next node IDs

**Routing Logic:**
- **Operation node:** Follow normal edges
- **Split node:** Follow all outgoing edges (parallel work)
- **Join node:** Wait until all tokens arrive
- **Decision node:** Evaluate condition and route accordingly

---

### **handleSplitNode()** - Handle Token Split

```php
$childTokens = $service->handleSplitNode($tokenId, $nodeId);
```

**Purpose:** Split 1 token into N tokens (parallel work)

**Parameters:**
- `int $tokenId` - Parent token to split
- `int $nodeId` - Split node instance ID

**Returns:** `array` - List of child token IDs

**Example:**
```php
// Token arrives at split node (CUT → SEW_BODY + SEW_STRAP)
$childTokens = $service->handleSplitNode(1, 5);
// Returns: [2, 3] (2 child tokens created)
```

---

### **handleJoinNode()** - Handle Token Join

```php
$result = $service->handleJoinNode($tokenId, $nodeId);
```

**Purpose:** Merge N tokens into 1 token (convergence)

**Parameters:**
- `int $tokenId` - Token arriving at join
- `int $nodeId` - Join node instance ID

**Returns:** `array` - ['joined' => bool, 'merged_token_id' => int|null]

**Logic:**
- Increment `tokens_waiting` counter
- If counter >= `min_tokens` requirement: merge tokens
- Merged token continues to next node

**Example:**
```php
// Token 2 arrives at join node (needs 2 tokens)
$result = $service->handleJoinNode(2, 6);
// If token 3 already waiting: {'joined': true, 'merged_token_id': 4}
// Else: {'joined': false} (waiting for more tokens)
```

---

### **getBottlenecks()** - Find Bottleneck Nodes

```php
$bottlenecks = $service->getBottlenecks($instanceId, $limit = 5);
```

**Purpose:** Identify nodes with highest token wait times (performance monitoring)

**Parameters:**
- `int $instanceId` - Graph instance ID
- `int $limit` - Max results (default: 5)

**Returns:** `array` - List of bottleneck nodes with metrics

**Example:**
```php
$bottlenecks = $service->getBottlenecks(1);
// Returns: [
//   {'node_name': 'QC', 'waiting_tokens': 15, 'avg_wait_minutes': 45},
//   {'node_name': 'SEW_BODY', 'waiting_tokens': 8, 'avg_wait_minutes': 30}
// ]
```

---

### **getGraphStatus()** - Get Graph Execution Status

```php
$status = $service->getGraphStatus($instanceId);
```

**Purpose:** Get real-time status of graph execution

**Parameters:**
- `int $instanceId` - Graph instance ID

**Returns:** `array` - Comprehensive status metrics

**Metrics:**
- Total tokens (spawned, in-transit, completed, scrapped)
- Node status breakdown (pending, active, completed, blocked)
- Completion percentage
- Estimated time remaining

---

## 🎫 **TokenLifecycleService** ⭐ **(NEW - Nov 2, 2025)**

**File:** `source/service/TokenLifecycleService.php`  
**Namespace:** `BGERP\Service\TokenLifecycleService`  
**Purpose:** Manage token lifecycle (create, move, complete, scrap)

### **Constructor:**

```php
$service = new \BGERP\Service\TokenLifecycleService($tenantDb);
```

---

### **spawnTokens()** - Create Initial Tokens

```php
$tokenIds = $service->spawnTokens($instanceId, $ticketId, $targetQty, $serials = []);
```

**Purpose:** Spawn initial tokens when job starts

**Parameters:**
- `int $instanceId` - Graph instance ID
- `int $ticketId` - Job ticket ID
- `float $targetQty` - Target quantity
- `array $serials` - Optional pre-generated serials

**Returns:** `array` - List of spawned token IDs

**Logic:**
- If serials provided: Create 1 token per serial (piece mode)
- Else: Create 1 batch token with qty = targetQty

**Example:**
```php
// Spawn 50 piece tokens with serials
$tokenIds = $service->spawnTokens(1, 123, 50, $serials);
// Returns: [1, 2, 3, ..., 50]
```

---

### **moveToken()** - Move Token to Next Node

```php
$service->moveToken($tokenId, $fromNodeId, $toNodeId, $operatorId, $operatorName);
```

**Purpose:** Move token from one node to another

**Parameters:**
- `int $tokenId` - Token to move
- `int $fromNodeId` - Current node instance ID
- `int $toNodeId` - Destination node instance ID
- `int $operatorId` - Operator performing move
- `string $operatorName` - Operator name

**Creates Events:**
- `exit_node` (from current node)
- `enter_node` (to next node)

---

### **completeToken()** - Mark Token as Completed

```php
$service->completeToken($tokenId, $operatorId, $operatorName);
```

**Purpose:** Mark token as finished (reached end node)

**Parameters:**
- `int $tokenId` - Token to complete
- `int $operatorId` - Operator
- `string $operatorName` - Operator name

**Creates Event:** `complete_token`

---

### **scrapToken()** - Mark Token as Scrapped

```php
$service->scrapToken($tokenId, $reason, $operatorId, $operatorName);
```

**Purpose:** Mark token as defective/scrapped

**Parameters:**
- `int $tokenId` - Token to scrap
- `string $reason` - Scrap reason
- `int $operatorId` - Operator
- `string $operatorName` - Operator name

**Creates Event:** `scrap`

---

## 🌐 **DAG Token API (HTTP Endpoints)** ⭐ **(NEW - Nov 2, 2025)**

**File:** `source/dag_token_api.php`  
**Purpose:** RESTful API for token movement operations  
**Authentication:** Required (session-based)

---

### **POST token_spawn** - Create Tokens for Job

**URL:** `source/dag_token_api.php?action=token_spawn`

**Request:**
```json
{
  "ticket_id": 123
}
```

**Response:**
```json
{
  "ok": true,
  "id_instance": 14,
  "token_count": 5,
  "token_ids": [17, 18, 19, 20, 21],
  "process_mode": "piece"
}
```

**Logic:**
1. Get job ticket
2. Create graph instance if not exists
3. Create node instances
4. Generate serials (piece mode) or batch token
5. Spawn tokens at START node
6. Log spawn + enter events

---

### **POST token_move** - Move Token to Node

**URL:** `source/dag_token_api.php?action=token_move`

**Request:**
```json
{
  "token_id": 17,
  "to_node_id": 2
}
```

**Response:**
```json
{
  "ok": true,
  "token_id": 17,
  "from_node": 1,
  "to_node": 2,
  "message": "Token moved successfully"
}
```

---

### **POST token_complete** - Complete Work at Node

**URL:** `source/dag_token_api.php?action=token_complete`

**Request:**
```json
{
  "token_id": 17,
  "node_id": 5,
  "qc_pass": true
}
```

**Response (Auto-Routed):**
```json
{
  "ok": true,
  "token_id": 17,
  "next_node_id": 6,
  "message": "Token routed to next node"
}
```

**Response (Completed):**
```json
{
  "ok": true,
  "token_id": 17,
  "status": "completed",
  "message": "Token completed successfully"
}
```

---

### **POST token_scrap / scrap** - Scrap Defective Token (Phase 7.5)

**URL:** `source/dag_token_api.php?action=scrap` (or `action=token_scrap`)

**Permission:** `atelier.token.scrap` (supervisor/manager only)

**Request:**
```json
{
  "token_id": 17,
  "reason": "material_defect" | "max_rework_exceeded" | "other",
  "comment": "สายหนังมีรอยตำหนิจากการฟอก"
}
```

**Response:**
```json
{
  "ok": true,
  "token_id": 17,
  "status": "scrapped",
  "message": "Token scrapped successfully"
}
```

**Error Cases:**
- `TOKEN_NOT_FOUND` (404) - Token ไม่มีในระบบ
- `TOKEN_CANNOT_BE_SCRAPPED_FROM_THIS_STATUS` (400) - Status ไม่ใช่ active/waiting/rework
- `FORBIDDEN` (403) - ไม่มีสิทธิ์ scrap token (ต้องเป็น supervisor/manager)

**Phase 7.5 Behavior:**
- Only tokens with status `active`, `waiting`, or `rework` can be scrapped
- Updates `scrapped_at` and `scrapped_by` fields
- Creates `scrap` event with metadata: `reason`, `comment`, `rework_count`, `limit`
- Idempotent: If already scrapped, returns success

---

### **POST create_replacement** - Create Replacement Token (Phase 7.5)

**URL:** `source/dag_token_api.php?action=create_replacement`

**Permission:** `atelier.token.create_replacement` (supervisor/manager only)

**Purpose:** Create a new token to replace a scrapped token (manual mode only)

**Request:**
```json
{
  "scrapped_token_id": 17,
  "spawn_mode": "from_start" | "from_cut",
  "comment": "QC ตัดสินว่าต้องตัดหนังใหม่"
}
```

**Response:**
```json
{
  "ok": true,
  "replacement_token_id": 25,
  "scrapped_token_id": 17,
  "spawn_node": "START",
  "message": "Replacement token created successfully"
}
```

**Error Cases:**
- `SCRAPPED_TOKEN_NOT_FOUND` (404) - Scrapped token ไม่มีในระบบ
- `TOKEN_IS_NOT_SCRAPPED` (400) - Token ยังไม่ถูก scrap
- `REPLACEMENT_ALREADY_EXISTS` (409) - มี replacement token อยู่แล้ว
- `START_NODE_NOT_FOUND` (404) - ไม่พบ START node ใน graph
- `FORBIDDEN` (403) - ไม่มีสิทธิ์สร้าง replacement (ต้องเป็น supervisor/manager)

**Phase 7.5 Behavior:**
- Only scrapped tokens can have replacements
- Replacement token **reuses original serial number** (1 serial = 1 product from customer view)
- Links replacement via `parent_scrapped_token_id` and `scrap_replacement_mode = 'manual'`
- Creates events on both tokens:
  - `replacement_created` on scrapped token (with replacement_token_id in metadata)
  - `replacement_of` on replacement token (with scrapped_token_id in metadata)
- Idempotent: If replacement already exists, returns error with existing replacement_token_id

---

### **GET token_status** - Get Token Details

**URL:** `source/dag_token_api.php?action=token_status&token_id=17`

**Response:**
```json
{
  "ok": true,
  "token": {
    "id_token": 17,
    "serial_number": "JT-001-2025-A7F3C9",
    "status": "active",
    "current_node_id": 2,
    "node_name": "Sew Body",
    "qty": 1
  },
  "events": [
    {"event_type": "spawn", "event_time": "2025-11-02 17:41:57"},
    {"event_type": "enter", "event_time": "2025-11-02 17:41:57"},
    {"event_type": "move", "event_time": "2025-11-02 17:42:15"}
  ]
}
```

---

### **GET token_list** - List Job Tokens

**URL:** `source/dag_token_api.php?action=token_list&ticket_id=123`

**Response:**
```json
{
  "ok": true,
  "id_instance": 14,
  "tokens": [
    {"id_token": 17, "serial_number": "...", "status": "active", "node_name": "Cutting"},
    {"id_token": 18, "serial_number": "...", "status": "completed", "node_name": "Finish"}
  ],
  "summary": {
    "active": 4,
    "completed": 1,
    "scrapped": 0,
    "total": 5
  }
}
```

---

### **GET node_tokens** - Get Tokens at Node

**URL:** `source/dag_token_api.php?action=node_tokens&node_instance_id=7`

**Response:**
```json
{
  "ok": true,
  "node_instance_id": 7,
  "token_count": 4,
  "tokens": [
    {"id_token": 17, "serial_number": "...", "qty": 1},
    {"id_token": 18, "serial_number": "...", "qty": 1}
  ]
}
```

---

## 🔐 **PermissionEngine** (NEW Dec 9)

**File:** `source/BGERP/Service/PermissionEngine.php`  
**Namespace:** `BGERP\Service\PermissionEngine`

### **Constructor:**

```php
$engine = new \BGERP\Service\PermissionEngine($tenantDb);
```

**Parameters:**
- `$tenantDb` (mysqli) - Tenant database connection

---

### **canActOnToken()** - Main Permission Check

```php
$result = $engine->canActOnToken($token, $member, $action, $nodeConfig);
```

**Purpose:** Token-level permission check with 4-layer model

**Parameters:**
- `$token` (array) - Token data (id_token, assigned_to, assignment_method, etc.)
- `$member` (array) - Current user data
- `$action` (string) - Action type (start, pause, complete, qc_pass, qc_fail, etc.)
- `$nodeConfig` (array) - Node configuration (allows_self_qc, requires_assignment, etc.)

**Returns:** array
```php
[
    'allowed' => bool,
    'reason' => string,  // If not allowed, reason code
    'layer' => string   // Which layer denied (role, assignment, node, token)
]
```

**4-Layer Permission Model:**
1. **Role Permission** - Base RBAC check (via PermissionHelper)
2. **Assignment Method** - strict, auto, pin, help
3. **Node Config** - QC self-pick, self-QC rules
4. **Token Type** - replacement, rework, split tokens

**Example:**
```php
$engine = new \BGERP\Service\PermissionEngine($tenantDb);
$result = $engine->canActOnToken($token, $member, 'start', $nodeConfig);

if (!$result['allowed']) {
    json_error($result['reason'], 403, ['app_code' => $result['layer']]);
}
```

---

### **canStartToken()** - Start Permission

```php
$allowed = $engine->canStartToken($token, $member, $nodeConfig);
```

**Returns:** bool

---

### **canPauseToken()** - Pause Permission

```php
$allowed = $engine->canPauseToken($token, $member, $nodeConfig);
```

**Returns:** bool

---

### **canCompleteToken()** - Complete Permission

```php
$allowed = $engine->canCompleteToken($token, $member, $nodeConfig);
```

**Returns:** bool

---

### **canQCToken()** - QC Permission

```php
$allowed = $engine->canQCToken($token, $member, $nodeConfig);
```

**Purpose:** QC permission with self-QC rules
- Unassigned tokens: Self-QC allowed
- Assigned tokens: Only assigned user can QC

**Returns:** bool

---

## 📦 **MaterialAllocationService** - Scrap Handling (NEW Dec 9)

**File:** `source/BGERP/Service/MaterialAllocationService.php`  
**Namespace:** `BGERP\Service\MaterialAllocationService`

### **handleScrapMaterials()** - Handle Materials for Scrapped Token

```php
$result = $service->handleScrapMaterials($tokenId, $userId);
```

**Purpose:** Handle material return/waste when token is scrapped

**Parameters:**
- `$tokenId` (int) - Token ID
- `$userId` (int) - User ID performing the scrap

**Returns:** array
```php
[
    'success' => bool,
    'returned_count' => int,  // Materials returned to stock
    'wasted_count' => int,     // Materials marked as waste
    'message' => string        // Error message if failed
]
```

**Business Rules:**
- If `consumed_qty = 0`: Return all reserved materials to stock
- If `consumed_qty > 0`: Mark consumed materials as waste, return unused to stock

**Event Types Logged:**
- `material_returned_scrap` - Materials returned to stock
- `material_wasted_scrap` - Materials marked as waste

**Example:**
```php
$materialService = new \BGERP\Service\MaterialAllocationService($tenantDb);
$result = $materialService->handleScrapMaterials($tokenId, $userId);

if ($result['success']) {
    error_log(sprintf(
        'Token %d: Materials handled - Returned: %d, Wasted: %d',
        $tokenId,
        $result['returned_count'],
        $result['wasted_count']
    ));
} else {
    error_log('Material handling failed: ' . $result['message']);
}
```

---

## 📚 **Service File Locations**

```
source/BGERP/Service/
├── OperatorSessionService.php (490 lines)
├── JobTicketStatusService.php (394 lines)
├── ValidationService.php (409 lines)
├── ErrorHandler.php (231 lines)
├── DatabaseTransaction.php (243 lines)
├── SecureSerialGenerator.php (272 lines)
├── PermissionEngine.php (457 lines) ⭐ NEW Dec 9
├── MaterialAllocationService.php (1304 lines) ⭐ (handleScrapMaterials added)
├── DAGValidationService.php (367 lines) ⭐
├── DAGRoutingService.php (586 lines) ⭐
└── TokenLifecycleService.php (542 lines) ⭐

Total: 11 core services, 5303+ lines of production-ready code
```

---

**See Also:**
- `docs/guide/MEMORY_GUIDE.md` - Service integration patterns
- `.cursorrules` - Service integration rules
- `tests/Unit/` - Service unit tests

---

**Status:** Service API documented, use before ANY service call

