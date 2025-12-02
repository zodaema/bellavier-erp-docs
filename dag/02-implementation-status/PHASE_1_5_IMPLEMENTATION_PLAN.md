# Phase 1.5 Wait Node Logic - Implementation Plan

**Date:** December 2025  
**Status:** 🟡 **PARTIALLY IMPLEMENTED** - Core logic done, missing background job and approval API  
**Priority:** 🟡 **IMPORTANT** - Required for time-based and approval workflows

---

## 📊 Current Implementation Status

### ✅ **Completed Components:**

1. **Database Schema** ✅
   - `wait_rule` JSON column added to `routing_node` table
   - Migration: `2025_12_december_consolidated.php` (Part 3/3)

2. **Core Routing Logic** ✅
   - `handleWaitNode()` - Implemented in `DAGRoutingService.php`
   - `evaluateWaitCondition()` - Implemented
   - `evaluateTimeWait()` - Implemented
   - `evaluateBatchWait()` - Implemented
   - `evaluateApprovalWait()` - Implemented
   - `completeWaitNode()` - Implemented
   - Integration in `routeToNode()` - Done

3. **Validation** ✅
   - `validateWaitNodes()` - Implemented in `DAGValidationService.php`
   - Integrated in `validateGraph()` method
   - Validates wait_rule, wait_type, and edge constraints

4. **Work Queue Filtering** ✅
   - Wait nodes filtered from Work Queue (line 1573 in `dag_token_api.php`)
   - Filter: `n.node_type IN ('operation', 'qc')`

---

## ⏳ **Missing Components:**

### **1. Background Job for Wait Condition Evaluation** ⏳

**Purpose:** Periodically evaluate wait conditions for tokens at wait nodes

**Requirements:**
- Run every 1-5 minutes (configurable)
- Evaluate all tokens with `status = 'waiting'` at wait nodes
- Auto-complete and route tokens when conditions met
- Handle time-based waits (check elapsed time)
- Handle batch waits (check batch size)
- Handle approval waits (check approval_granted event)

**Implementation Plan:**

**File:** `tools/cron/evaluate_wait_conditions.php`

```php
<?php
/**
 * Background Job: Evaluate Wait Conditions
 * 
 * Purpose: Periodically evaluate wait conditions for tokens at wait nodes
 * Frequency: Every 1-5 minutes (configurable)
 * 
 * @package Bellavier Group ERP
 * @version 1.0
 * @date December 2025
 */

require_once __DIR__ . '/../../config.php';
require_once __DIR__ . '/../../source/BGERP/Service/DAGRoutingService.php';

use BGERP\Service\DAGRoutingService;

function evaluateAllWaitConditions(): void
{
    $coreDb = core_db();
    
    // Get all active tenants
    $stmt = $coreDb->prepare("SELECT code FROM organization WHERE status=1");
    $stmt->execute();
    $res = $stmt->get_result();
    
    $processed = 0;
    $completed = 0;
    $errors = 0;
    
    while ($row = $res->fetch_assoc()) {
        $orgCode = $row['code'];
        $tenantDb = tenant_db($orgCode);
        
        try {
            // Get all tokens waiting at wait nodes
            $waitTokens = $tenantDb->query("
                SELECT 
                    ft.id_token,
                    ft.current_node_id,
                    rn.wait_rule
                FROM flow_token ft
                JOIN routing_node rn ON rn.id_node = ft.current_node_id
                WHERE ft.status = 'waiting'
                AND rn.node_type = 'wait'
            ")->fetch_all(MYSQLI_ASSOC);
            
            $routingService = new DAGRoutingService($tenantDb);
            
            foreach ($waitTokens as $tokenData) {
                $processed++;
                
                try {
                    $waitRule = \BGERP\Helper\JsonNormalizer::normalizeJsonField($tokenData, 'wait_rule', null);
                    
                    if (empty($waitRule)) {
                        error_log("Wait token {$tokenData['id_token']} missing wait_rule");
                        continue;
                    }
                    
                    // Evaluate condition
                    $conditionMet = $routingService->evaluateWaitCondition(
                        $tokenData['id_token'],
                        $tokenData['current_node_id'],
                        $waitRule
                    );
                    
                    if ($conditionMet) {
                        // Get node data
                        $nodeStmt = $tenantDb->prepare("
                            SELECT * FROM routing_node WHERE id_node = ?
                        ");
                        $nodeStmt->bind_param('i', $tokenData['current_node_id']);
                        $nodeStmt->execute();
                        $node = $nodeStmt->get_result()->fetch_assoc();
                        $nodeStmt->close();
                        
                        // Complete wait node
                        $routingService->completeWaitNode(
                            $tokenData['id_token'],
                            $tokenData['current_node_id'],
                            $waitRule['wait_type'],
                            null // System-initiated
                        );
                        
                        $completed++;
                    }
                } catch (\Exception $e) {
                    error_log("Error evaluating wait condition for token {$tokenData['id_token']}: " . $e->getMessage());
                    $errors++;
                }
            }
        } catch (\Exception $e) {
            error_log("Error processing tenant {$orgCode}: " . $e->getMessage());
            $errors++;
        }
    }
    
    $stmt->close();
    
    echo "Processed: {$processed}, Completed: {$completed}, Errors: {$errors}\n";
}

// Run if called from CLI
if (php_sapi_name() === 'cli') {
    evaluateAllWaitConditions();
}
```

**Cron Setup:**
```bash
# Add to crontab (run every 2 minutes)
*/2 * * * * /usr/bin/php /path/to/tools/cron/evaluate_wait_conditions.php >> /path/to/logs/wait_evaluation.log 2>&1
```

**Status:** ⏳ **NOT IMPLEMENTED**

---

### **2. Approval API Endpoint** ⏳

**Purpose:** Allow supervisors/managers to grant approval for tokens waiting at approval wait nodes

**Requirements:**
- API endpoint: `POST /api/dag/approval/grant`
- Parameters: `token_id`, `approver_id`, `reason` (optional)
- Create `approval_granted` event
- Auto-complete wait node if condition met
- Permission check: Must have supervisor/manager role

**Implementation Plan:**

**File:** `source/dag_approval_api.php` (new file)

```php
<?php
/**
 * DAG Approval API
 * 
 * Purpose: Handle approval requests for wait nodes
 * 
 * @package Bellavier Group ERP
 * @version 1.0
 * @date December 2025
 */

session_start();
require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/model/member_class.php';
require_once __DIR__ . '/permission.php';
require_once __DIR__ . '/BGERP/Service/DAGRoutingService.php';
require_once __DIR__ . '/BGERP/Service/TokenLifecycleService.php';
require_once __DIR__ . '/global_function.php';

use BGERP\Service\DAGRoutingService;
use BGERP\Service\TokenLifecycleService;

// ... (standard API setup code) ...

function handleGrantApproval(): void
{
    global $db;
    
    // Get current user
    $objMemberDetail = new memberDetail();
    $member = $objMemberDetail->thisLogin();
    
    if (!$member) {
        json_error('unauthorized', 401);
        return;
    }
    
    // Check permission (supervisor/manager/admin)
    $hasPermission = checkPermission($member['id_member'], [
        'hatthasilpa.job.manage',
        'admin.manage',
        'supervisor.manage'
    ]);
    
    if (!$hasPermission) {
        json_error('permission_denied', 403, [
            'message' => 'Only supervisors/managers can grant approvals'
        ]);
        return;
    }
    
    // Get request data
    $data = json_decode(file_get_contents('php://input'), true);
    $tokenId = (int)($data['token_id'] ?? 0);
    $reason = $data['reason'] ?? '';
    
    if (!$tokenId) {
        json_error('validation_failed', 400, [
            'message' => 'token_id is required'
        ]);
        return;
    }
    
    // Get tenant DB
    $org = resolve_current_org();
    if (!$org) {
        json_error('org_not_resolved', 400);
        return;
    }
    
    $tenantDb = tenant_db($org['code']);
    
    // Get token and verify it's at a wait node
    $tokenStmt = $tenantDb->prepare("
        SELECT ft.*, rn.node_type, rn.wait_rule
        FROM flow_token ft
        JOIN routing_node rn ON rn.id_node = ft.current_node_id
        WHERE ft.id_token = ?
    ");
    $tokenStmt->bind_param('i', $tokenId);
    $tokenStmt->execute();
    $token = $tokenStmt->get_result()->fetch_assoc();
    $tokenStmt->close();
    
    if (!$token) {
        json_error('token_not_found', 404);
        return;
    }
    
    if ($token['node_type'] !== 'wait') {
        json_error('invalid_node_type', 400, [
            'message' => 'Token is not at a wait node'
        ]);
        return;
    }
    
    $waitRule = \BGERP\Helper\JsonNormalizer::normalizeJsonField($token, 'wait_rule', null);
    
    if (empty($waitRule) || ($waitRule['wait_type'] ?? '') !== 'approval') {
        json_error('invalid_wait_type', 400, [
            'message' => 'Token is not waiting for approval'
        ]);
        return;
    }
    
    // Create approval_granted event
    $tokenService = new TokenLifecycleService($tenantDb);
    $tokenService->createEvent($tokenId, 'approval_granted', $token['current_node_id'], $member['id_member'], [
        'approver_id' => $member['id_member'],
        'approver_name' => $member['name'],
        'reason' => $reason,
        'wait_type' => 'approval',
        'role' => $waitRule['role'] ?? null
    ]);
    
    // Evaluate wait condition (should now be met)
    $routingService = new DAGRoutingService($tenantDb);
    $node = [
        'id_node' => $token['current_node_id'],
        'node_name' => '', // Will be fetched if needed
        'node_type' => 'wait',
        'wait_rule' => $waitRule
    ];
    
    $conditionMet = $routingService->evaluateWaitCondition($tokenId, $token['current_node_id'], $waitRule);
    
    if ($conditionMet) {
        // Auto-complete wait node
        $routingService->completeWaitNode(
            $tokenId,
            $token['current_node_id'],
            'approval',
            $member['id_member']
        );
        
        json_success([
            'message' => 'Approval granted and token routed',
            'token_id' => $tokenId,
            'routed' => true
        ]);
    } else {
        json_success([
            'message' => 'Approval granted but condition not yet met',
            'token_id' => $tokenId,
            'routed' => false
        ]);
    }
}

// Route requests
$action = $_GET['action'] ?? '';

switch ($action) {
    case 'grant':
        handleGrantApproval();
        break;
    
    default:
        json_error('invalid_action', 400);
        break;
}
```

**Status:** ⏳ **NOT IMPLEMENTED**

---

### **3. Testing** ⏳

**Unit Tests:**
- [ ] Time wait evaluation logic
- [ ] Batch wait counting logic
- [ ] Approval wait evaluation logic
- [ ] Wait rule validation

**Integration Tests:**
- [ ] Token enters wait node → status = waiting
- [ ] Time wait completes after duration
- [ ] Batch wait completes when batch full
- [ ] Approval wait completes when approval granted
- [ ] Wait completion routes token correctly

**Status:** ⏳ **NOT IMPLEMENTED**

---

## 🎯 Implementation Priority

### **Next Steps (In Order):**

1. **Background Job (HIGH PRIORITY)** 🔴
   - Required for time-based waits to work
   - Required for batch waits to work
   - Can be tested immediately after implementation

2. **Approval API (MEDIUM PRIORITY)** 🟡
   - Required for approval waits to work
   - Can be tested after background job

3. **Testing (MEDIUM PRIORITY)** 🟡
   - Verify all wait types work correctly
   - Edge case testing
   - Integration testing

---

## 📋 Acceptance Criteria Checklist

- [x] Wait nodes correctly set token status to `waiting` ✅
- [ ] Time-based waits complete after specified duration ⏳ (needs background job)
- [ ] Batch waits complete when batch size reached ⏳ (needs background job)
- [ ] Approval waits complete when approval granted ⏳ (needs approval API)
- [x] Wait nodes hidden from Work Queue and PWA ✅
- [x] Wait completion auto-routes token to next node ✅ (logic exists)
- [x] Wait events logged correctly (`wait_start`, `wait_completed`) ✅
- [x] Graph Designer validates wait_rule configuration ✅
- [ ] Background job evaluates wait conditions periodically ⏳

---

## 🚀 Recommended Implementation Order

1. **Implement Background Job** (1-2 hours)
   - Create `tools/cron/evaluate_wait_conditions.php`
   - Set up cron job
   - Test with time-based waits

2. **Implement Approval API** (1-2 hours)
   - Create `source/dag_approval_api.php`
   - Add permission checks
   - Test approval flow

3. **Testing** (2-3 hours)
   - Unit tests for wait evaluation
   - Integration tests for all wait types
   - Edge case testing

**Total Estimated Time:** 4-7 hours

---

**Last Updated:** December 2025  
**Next Review:** After background job implementation

