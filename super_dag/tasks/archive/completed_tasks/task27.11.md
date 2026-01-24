# Task 27.11 — Create get_context API for Work Queue UI

**Phase:** 5 - UI Data Contract  
**Priority:** 🟢 MEDIUM  
**Estimated Effort:** 4-6 hours  
**Status:** ✅ Complete (2025-12-04)

**Parent Task:** Phase 5 - Behavior UI Backend API  
**Dependencies:** Task 27.2-27.10 (Phase 1-4 complete)  
**Blocks:** None (final task in sequence)

---

## ⚠️ CRITICAL: Scope & Location

**File Location:**
- ✅ **Correct:** `source/dag_token_api.php` (add new action)
- ❌ **Wrong:** `dag_behavior_exec.php` (that's for behavior execution only)

**Service Namespace:**
- ✅ **Correct:** `BGERP\Service\ComponentFlowService`
- ❌ **Wrong:** `BGERP\Dag\ComponentFlowService` (ไม่มี!)

**Scope:**
- ✅ Read-only data provider
- ❌ NO state changes
- ❌ NO lifecycle calls

---

## 📋 Context from Phase 1-4 (COMPLETE)

**What we have now:**
- ✅ **TokenLifecycleService** - Node completion, split/merge (27.2, 27.8)
- ✅ **BehaviorExecutionService** - Execute behaviors (27.3, 27.6)
- ✅ **ParallelMachineCoordinator** - Handle split/merge (27.7)
- ✅ **FailureRecoveryService** - QC fail recovery + tray validation (27.9, 27.10)
- ✅ **ComponentFlowService** - Stub for sibling status (27.5)

**What this task adds:**
- ✅ **get_context API** - Single endpoint to fetch token + node + parent + tray + siblings

---

## 🎯 Goal

สร้าง API endpoint `get_context` ให้ frontend ดึงข้อมูล context สำหรับ render behavior UI

**Key Principle:**
- ✅ Backend = Data provider (structured JSON)
- ❌ Backend ไม่กำหนด layout/UI (ให้ frontend จัดการ)
- ✅ Single endpoint สำหรับทุก token type

**Quick Summary (TL;DR):**
1. Add `case 'get_context':` to `dag_token_api.php`
2. Return token + node + parent + tray + siblings data
3. Use existing services (ComponentFlowService for siblings)
4. Handle missing data gracefully (null, empty arrays)
5. ~80-100 lines of code

---

## 📋 Requirements

### 1. Add API Endpoint: get_context

**File:** `source/dag_token_api.php` (add to existing switch)

**Endpoint:**
```
POST source/dag_token_api.php
{
  "action": "get_context",
  "token_id": 123
}
```

**Implementation:**

```php
case 'get_context':
    handleGetContext($tenantDb);
    break;

// ... (add function at bottom of file) ...

/**
 * Get token context for Work Queue UI
 * Task 27.11: Returns token + node + parent + tray + siblings
 * 
 * @param mysqli $tenantDb Database connection
 * @return void (calls json_success/json_error)
 */
function handleGetContext($tenantDb): void
{
    // 1. Validate input
    $tokenId = (int)($_REQUEST['token_id'] ?? 0);
    if ($tokenId <= 0) {
        json_error('token_id required', 400, ['app_code' => 'DAG_400_MISSING_TOKEN_ID']);
    }
    
    // 2. Fetch token
    $token = db_fetch_one($tenantDb, "SELECT * FROM flow_token WHERE id_token = ?", [$tokenId]);
    if (!$token) {
        json_error('Token not found', 404, ['app_code' => 'DAG_404_TOKEN_NOT_FOUND']);
    }
    
    // 3. Build context (all optional fields start null)
    $context = [
        'token' => $token,
        'node' => null,
        'parent' => null,
        'tray' => null,
        'siblings' => []  // Empty array for UI (not null)
    ];
    
    // 4. Get current node (with work_center for behavior lookup)
    if (!empty($token['current_node_id'])) {
        $context['node'] = db_fetch_one($tenantDb, "
            SELECT 
                n.*,
                wc.code AS work_center_code,
                wc.behavior_code  -- Behavior comes from work_center, not node
            FROM routing_node n
            LEFT JOIN work_center wc ON wc.code = n.work_center_code
            WHERE n.id_node = ?
        ", [(int)$token['current_node_id']]);
    }
    
    // 5. Component-specific data
    if ($token['token_type'] === 'component') {
        // Get parent token
        if (!empty($token['parent_token_id'])) {
            $context['parent'] = db_fetch_one($tenantDb, "
                SELECT id_token, serial_number, token_type, status
                FROM flow_token WHERE id_token = ?
            ", [(int)$token['parent_token_id']]);
        }
        
        // Get sibling components (use ComponentFlowService if available)
        if (!empty($token['parallel_group_id'])) {
            // Direct query (ComponentFlowService.getSiblingStatus is stub)
            $context['siblings'] = fetchSiblingComponents($tenantDb, (int)$token['parallel_group_id']);
        }
        
        // Get tray info (simple: T-{parent_serial})
        if ($context['parent'] && !empty($context['parent']['serial_number'])) {
            $context['tray'] = [
                'tray_code' => 'T-' . $context['parent']['serial_number'],
                'final_serial' => $context['parent']['serial_number']
            ];
        }
    }
    
    // 6. Final token at merge → get components
    if ($token['token_type'] === 'piece' && $token['status'] === 'waiting') {
        // Get child component tokens
        $context['siblings'] = fetchChildComponents($tenantDb, $tokenId);
        
        // Tray info for piece
        if (!empty($token['serial_number'])) {
            $context['tray'] = [
                'tray_code' => 'T-' . $token['serial_number'],
                'final_serial' => $token['serial_number']
            ];
        }
    }
    
    // 7. Log and return
    error_log(sprintf(
        '[dag_token_api][get_context] token_id=%d, type=%s, status=%s',
        $tokenId,
        $token['token_type'] ?? 'unknown',
        $token['status'] ?? 'unknown'
    ));
    
    json_success(['context' => $context]);
}

/**
 * Fetch sibling components by parallel_group_id
 */
function fetchSiblingComponents($tenantDb, int $parallelGroupId): array
{
    $sql = "
        SELECT 
            id_token,
            status,
            parallel_branch_key,
            JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.component_code')) AS component_code,
            JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.worker_name')) AS worker_name
        FROM flow_token
        WHERE parallel_group_id = ?
          AND token_type = 'component'
        ORDER BY parallel_branch_key ASC
        LIMIT 20
    ";
    
    return db_fetch_all($tenantDb, $sql, [$parallelGroupId]) ?: [];
}

/**
 * Fetch child component tokens for a parent piece token
 */
function fetchChildComponents($tenantDb, int $parentTokenId): array
{
    $sql = "
        SELECT 
            id_token,
            status,
            parallel_branch_key,
            JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.component_code')) AS component_code,
            JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.worker_name')) AS worker_name
        FROM flow_token
        WHERE parent_token_id = ?
          AND token_type = 'component'
        ORDER BY parallel_branch_key ASC
        LIMIT 20
    ";
    
    return db_fetch_all($tenantDb, $sql, [$parentTokenId]) ?: [];
}
```

### 2. Response Structure

**For Component Token:**
```json
{
  "ok": true,
  "context": {
    "token": {
      "id_token": 123,
      "token_type": "component",
      "serial_number": "C-BODY-001",
      "status": "active",
      "metadata": "{\"component_code\": \"BODY\"}"
    },
    "node": {
      "id_node": 456,
      "node_name": "Stitch Body",
      "work_center_code": "WC-STITCH-01",
      "behavior_code": "STITCH"
    },
    "parent": {
      "id_token": 100,
      "serial_number": "F001",
      "token_type": "piece",
      "status": "waiting"
    },
    "tray": {
      "tray_code": "T-F001",
      "final_serial": "F001"
    },
    "siblings": [
      {"id_token": 123, "component_code": "BODY", "status": "active", "worker_name": "Alice", "parallel_branch_key": "BODY"},
      {"id_token": 124, "component_code": "FLAP", "status": "completed", "worker_name": "Bob", "parallel_branch_key": "FLAP"},
      {"id_token": 125, "component_code": "STRAP", "status": "ready", "worker_name": null, "parallel_branch_key": "STRAP"}
    ]
  }
}
```

**For Final Token (at merge):**
```json
{
  "ok": true,
  "context": {
    "token": {
      "id_token": 100,
      "token_type": "piece",
      "serial_number": "F001",
      "status": "waiting"
    },
    "node": {
      "id_node": 789,
      "node_name": "Assembly",
      "work_center_code": "WC-ASSEMBLY-01",
      "behavior_code": "ASSEMBLY",
      "is_merge_node": 1
    },
    "parent": null,
    "siblings": [
      {"id_token": 123, "component_code": "BODY", "status": "completed", "worker_name": "Alice", "parallel_branch_key": "BODY"},
      {"id_token": 124, "component_code": "FLAP", "status": "completed", "worker_name": "Bob", "parallel_branch_key": "FLAP"},
      {"id_token": 125, "component_code": "STRAP", "status": "completed", "worker_name": "Carol", "parallel_branch_key": "STRAP"}
    ],
    "tray": {
      "tray_code": "T-F001",
      "final_serial": "F001"
    }
  }
}
```

**For Simple Piece Token (no components):**
```json
{
  "ok": true,
  "context": {
    "token": {
      "id_token": 50,
      "token_type": "piece",
      "serial_number": "P001",
      "status": "active"
    },
    "node": {
      "id_node": 10,
      "node_name": "Cut",
      "work_center_code": "WC-CUT-01",
      "behavior_code": "CUT"
    },
    "parent": null,
    "tray": {
      "tray_code": "T-P001",
      "final_serial": "P001"
    },
    "siblings": []
  }
}
```

---

## 🚧 Guardrails (MUST FOLLOW)

### Guardrail 1: Data Only (No Presentation)
- ✅ Return structured JSON data
- ❌ NO HTML markup
- ❌ NO CSS classes
- ❌ NO UI wording (frontend handles i18n)
- ✅ Return raw data, let frontend render

### Guardrail 2: Fail Gracefully (NEVER Throw)
- ✅ If parent not found → return null for parent
- ✅ If siblings cannot be fetched → return empty array `[]`
- ✅ If tray cannot be determined → return null
- ❌ NO breaking API if optional data missing
- ❌ **NO throwing exceptions** (use json_error only)

### Guardrail 3: Simple Tray Logic
- ✅ Tray code = "T-{serial_number}"
- ❌ NO creating tray table
- ❌ NO complex tray assignment
- ✅ Derive from serial number only

### Guardrail 4: Performance
- ✅ Use prepared statements via db_fetch_one/db_fetch_all
- ✅ Fetch only necessary columns (not SELECT *)
- ❌ NO N+1 queries (fetch siblings in one query)
- ✅ Limit sibling query: `LIMIT 20` (prevent huge result sets)

### Guardrail 5: Scope Limitation
- ✅ **Modify:** `source/dag_token_api.php` only (add case + function)
- ❌ NO `dag_behavior_exec.php` changes
- ❌ NO UI file changes
- ❌ NO JavaScript changes
- ❌ NO database schema changes
- ❌ NO touching behavior handlers (BehaviorExecutionService)
- ❌ NO touching lifecycle (TokenLifecycleService)

### Guardrail 6: Read-Only (No State Changes)
- ✅ **Pure read operation** - fetch data only
- ❌ NO token status changes
- ❌ NO metadata updates
- ❌ NO lifecycle transitions
- ❌ NO session creation/modification

### Guardrail 7: Logging
- ✅ Log request: token_id, type, status
- ✅ Log errors with app_code
- ❌ NO logging sensitive data (passwords, keys)
- ❌ NO excessive logging (debug only if BGERP_DEBUG)

### Guardrail 8: Error Codes (Consistent)
- ✅ `DAG_400_MISSING_TOKEN_ID` - token_id not provided
- ✅ `DAG_404_TOKEN_NOT_FOUND` - token doesn't exist
- ✅ `DAG_401_UNAUTHORIZED` - auth failed (handled by existing code)
- ✅ `DAG_500_INTERNAL` - unexpected errors

---

## 🧪 Testing Requirements

### Manual Testing (Browser-based)

**Test Scenario 1: Component Token Context**
1. Create component token (with parent, parallel_group_id)
2. Call API via browser/curl: `action=get_context&token_id=123`
3. Check response has:
   - ✅ token (id, type, status)
   - ✅ node (id, name, work_center_code, behavior_code)
   - ✅ parent (id, serial, type, status)
   - ✅ tray (tray_code, final_serial)
   - ✅ siblings (array with component_code, status, worker_name)

**Test Scenario 2: Simple Piece Token Context**
1. Create piece token (no parent, no components)
2. Call API: `action=get_context&token_id=50`
3. Check response has:
   - ✅ token
   - ✅ node
   - ✅ parent = null
   - ✅ tray (derived from own serial)
   - ✅ siblings = [] (empty array)

**Test Scenario 3: Final Token at Merge (status=waiting)**
1. Create piece token with status='waiting' at merge node
2. Ensure it has child components
3. Call API: `action=get_context&token_id=100`
4. Check response has:
   - ✅ token
   - ✅ node (is_merge_node=1)
   - ✅ siblings = array of child components
   - ✅ tray

**Test Scenario 4: Missing Optional Data (Graceful)**
1. Token with no current_node_id (orphaned)
2. Call API
3. Should return:
   - ✅ token (always present)
   - ✅ node = null
   - ✅ parent = null
   - ✅ tray = null
   - ✅ siblings = []

**Test Scenario 5: Invalid Token ID**
1. Call API with non-existent token_id
2. Should return: `{ok: false, error: 'Token not found', app_code: 'DAG_404_TOKEN_NOT_FOUND'}`

### API Testing (curl)

```bash
# Test with curl (replace PHPSESSID with valid session)
curl -X POST "http://localhost:8888/bellavier-group-erp/source/dag_token_api.php" \
  -H "Cookie: PHPSESSID=your_session_id" \
  -d "action=get_context&token_id=123"

# Expected success:
# {"ok":true,"context":{"token":{...},"node":{...},"parent":{...},"tray":{...},"siblings":[...]}}

# Test invalid token
curl -X POST "http://localhost:8888/bellavier-group-erp/source/dag_token_api.php" \
  -H "Cookie: PHPSESSID=your_session_id" \
  -d "action=get_context&token_id=999999"

# Expected error:
# {"ok":false,"error":"Token not found","app_code":"DAG_404_TOKEN_NOT_FOUND"}
```

**Expected:** Valid JSON response with correct context data

---

## 📦 Deliverables

### 1. Modified Files

- ✅ `source/dag_token_api.php`
  - Add `case 'get_context':` to switch (~1 line)
  - Add `handleGetContext()` function (~40 lines)
  - Add `fetchSiblingComponents()` helper (~15 lines)
  - Add `fetchChildComponents()` helper (~15 lines)
  - **Total: ~70-90 lines**

### 2. Test Evidence

- ✅ Manual test checklist completed (5 scenarios)
- ✅ API responses verified (curl or browser)
- ✅ JSON structure matches spec
- ✅ No errors in PHP log
- ✅ Optional data handled gracefully

### 3. Results Document

- ✅ `docs/super_dag/tasks/results/task27.11_results.md`

---

## ✅ Definition of Done

- [x] get_context action added to dag_token_api.php
- [x] handleGetContext() function implemented
- [x] Returns correct data for component tokens (parent, siblings, tray)
- [x] Returns correct data for simple piece tokens (no parent/siblings)
- [x] Returns correct data for final token at merge (children as siblings)
- [x] Siblings data populated with component_code, status, worker_name
- [x] Tray data populated (simple T-{serial} format)
- [x] Missing data handled gracefully (null/empty array)
- [ ] Manual testing pass (5 scenarios) — requires runtime testing
- [x] JSON response structure matches spec
- [x] No PHP errors (syntax check passed)
- [x] Results document created (`results/task27.11_results.md`)

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO `dag_behavior_exec.php` changes (wrong file!)
- ❌ NO UI/JavaScript changes (frontend will consume API later)
- ❌ NO creating tray table
- ❌ NO implementing frontend rendering
- ❌ NO updating Work Queue UI files
- ❌ NO database schema changes
- ❌ NO touching behavior handlers (BehaviorExecutionService)
- ❌ NO touching lifecycle (TokenLifecycleService)
- ❌ NO implementing full component model (Phase 6)
- ❌ NO creating new spec .md files (only results .md)

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 8 (UI data contract)

**Code (Existing):**
- `source/dag_token_api.php` - File to modify (add case + function)
- `source/BGERP/Service/ComponentFlowService.php` - For sibling status (stub OK for now)
- `source/BGERP/Dag/FailureRecoveryService.php` - Tray validation reference

**Dependencies (Phase 1-4 complete):**
- Task 27.2: TokenLifecycleService extended
- Task 27.5: ComponentFlowService created
- Task 27.7: ParallelMachineCoordinator
- Task 27.9: FailureRecoveryService
- Task 27.10: Tray validation

---

## 📝 Implementation Notes

### 1. behavior_code Location
- ❗ `behavior_code` comes from **work_center**, not routing_node
- Need to JOIN: `routing_node n LEFT JOIN work_center wc ON wc.code = n.work_center_code`

### 2. JSON Extract Syntax (MySQL 5.7+)
- Use `JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.key'))` not `->>` operator
- Safer for older MySQL versions

### 3. Sibling Query Pattern
- Component token → query by `parallel_group_id`
- Piece token at merge → query by `parent_token_id`
- Both return same structure: id_token, status, component_code, worker_name

### 4. Graceful Fallbacks
- node not found → null
- parent not found → null
- siblings query fails → empty array []
- tray cannot be determined → null

---

## 📝 Results Template

```markdown
# Task 27.11 Results — get_context API Created

**Completed:** YYYY-MM-DD  
**Duration:** X hours  
**Status:** ✅ Complete

## Files Modified
- `source/dag_token_api.php` (+~80 lines)
  - Added case 'get_context'
  - Added handleGetContext()
  - Added fetchSiblingComponents()
  - Added fetchChildComponents()

## API Testing

### Test 1: Component Token
```bash
curl -X POST "http://localhost:8888/bellavier-group-erp/source/dag_token_api.php" \
  -H "Cookie: PHPSESSID=xxx" \
  -d "action=get_context&token_id=123"
```
Response: {...}

### Test 2: Simple Piece Token
Response: {...}

### Test 3: Token at Merge
Response: {...}

## Manual Testing Checklist
- [ ] Component token context correct
- [ ] Simple piece token context correct
- [ ] Final token at merge context correct
- [ ] Missing optional data handled (null/[])
- [ ] Invalid token returns 404

## Issues Encountered
- (List any issues and fixes)

## Phase 5 Status
- [x] Task 27.11: get_context API ✅
- [ ] Task 27.12: Component Metadata Aggregation

## Next Steps
- Frontend integration (Work Queue UI update)
- Component UI templates (if needed)
```

---

**END OF TASK**

