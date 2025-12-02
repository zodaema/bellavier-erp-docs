# Task 27.11 — Create get_context API for Work Queue UI

**Phase:** 5 - UI Data Contract  
**Priority:** 🟢 MEDIUM  
**Estimated Effort:** 4-6 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 5 - Behavior UI Backend API  
**Dependencies:** Task 27.10 (Tray validation exists)  
**Blocks:** None (final task in sequence)

---

## 🎯 Goal

สร้าง API endpoint `get_context` ให้ frontend ดึงข้อมูล context สำหรับ render behavior UI

**Key Principle:**
- ✅ Backend = Data provider (structured JSON)
- ❌ Backend ไม่กำหนด layout/UI (ให้ frontend จัดการ)
- ✅ Single endpoint สำหรับทุก token type

---

## 📋 Requirements

### 1. Add API Endpoint: get_context

**File:** `source/dag_behavior_exec.php` (or create if not exists)

**Endpoint:**
```
POST source/dag_behavior_exec.php
{
  "action": "get_context",
  "token_id": 123
}
```

**Implementation:**

```php
case 'get_context':
    // 1. Validate input
    $tokenId = (int)($_REQUEST['token_id'] ?? 0);
    if ($tokenId <= 0) {
        json_error('token_id required', 400);
    }
    
    // 2. Fetch token
    $token = db_fetch_one($tenantDb, "SELECT * FROM flow_token WHERE id_token = ?", [$tokenId]);
    if (!$token) {
        json_error('Token not found', 404);
    }
    
    // 3. Build context
    $context = [
        'token' => $token,
        'node' => null,
        'parent' => null,
        'tray' => null,
        'siblings' => null
    ];
    
    // 4. Get current node
    if ($token['current_node_id']) {
        $context['node'] = db_fetch_one($tenantDb, "
            SELECT * FROM routing_node WHERE id_node = ?
        ", [$token['current_node_id']]);
    }
    
    // 5. Component-specific data
    if ($token['token_type'] === 'component') {
        // Get parent
        if ($token['parent_token_id']) {
            $context['parent'] = db_fetch_one($tenantDb, "
                SELECT * FROM flow_token WHERE id_token = ?
            ", [$token['parent_token_id']]);
        }
        
        // Get sibling components (parallel group)
        if ($token['parallel_group_id']) {
            require_once __DIR__ . '/BGERP/Dag/ComponentFlowService.php';
            $componentService = new \BGERP\Dag\ComponentFlowService($tenantDb);
            $context['siblings'] = $componentService->getSiblingStatus($token['parallel_group_id']);
        }
        
        // Get tray info (simple: T-{parent_serial})
        if ($context['parent']) {
            $context['tray'] = [
                'tray_code' => 'T-' . $context['parent']['serial_number'],
                'final_serial' => $context['parent']['serial_number']
            ];
        }
    }
    
    // 6. Final token at merge → get components
    if ($token['token_type'] === 'piece' && $token['status'] === 'waiting') {
        // Get component tokens
        $context['siblings'] = db_fetch_all($tenantDb, "
            SELECT 
                id_token,
                status,
                metadata->>'$.component_code' AS component_code,
                metadata->>'$.worker_name' AS worker_name
            FROM flow_token
            WHERE parent_token_id = ?
              AND token_type = 'component'
            ORDER BY parallel_branch_key ASC
        ", [$tokenId]);
        
        // Tray info
        $context['tray'] = [
            'tray_code' => 'T-' . $token['serial_number'],
            'final_serial' => $token['serial_number']
        ];
    }
    
    // 7. Return context
    json_success(['context' => $context]);
    return;
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
      "metadata": {"component_code": "BODY"}
    },
    "node": {
      "id_node": 456,
      "node_name": "Stitch Body",
      "behavior_code": "STITCH"
    },
    "parent": {
      "id_token": 100,
      "serial_number": "F001",
      "token_type": "piece"
    },
    "tray": {
      "tray_code": "T-F001",
      "final_serial": "F001"
    },
    "siblings": [
      {"component_code": "BODY", "status": "active", "worker_name": "Alice"},
      {"component_code": "FLAP", "status": "completed", "worker_name": "Bob"},
      {"component_code": "STRAP", "status": "ready", "worker_name": null}
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
      "behavior_code": "ASSEMBLY",
      "is_merge_node": 1
    },
    "siblings": [
      {"component_code": "BODY", "status": "completed", "worker_name": "Alice"},
      {"component_code": "FLAP", "status": "completed", "worker_name": "Bob"},
      {"component_code": "STRAP", "status": "completed", "worker_name": "Carol"}
    ],
    "tray": {
      "tray_code": "T-F001",
      "final_serial": "F001"
    }
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

### Guardrail 2: Fail Gracefully
- ✅ If parent not found → return token only (no parent data)
- ✅ If siblings cannot be fetched → return empty array
- ✅ If tray cannot be determined → return null
- ❌ NO breaking API if optional data missing

### Guardrail 3: Simple Tray Logic
- ✅ Tray code = "T-{serial_number}"
- ❌ NO creating tray table
- ❌ NO complex tray assignment
- ✅ Derive from serial number only

### Guardrail 4: Performance
- ✅ Use prepared statements
- ✅ Fetch only necessary data
- ❌ NO N+1 queries (fetch siblings in one query)
- ✅ Limit sibling query (e.g., max 20 components)

### Guardrail 5: Scope Limitation
- ✅ Create/modify: `dag_behavior_exec.php` (or similar API file)
- ❌ NO UI file changes
- ❌ NO JavaScript changes
- ❌ NO database schema changes
- ❌ NO touching behavior handlers

---

## 🧪 Testing Requirements

### Manual Testing

**Test Scenario 1: Component Token Context**
1. Create component token (with parent, parallel_group_id)
2. Call API: `get_context&token_id=123`
3. Check response has: token, node, parent, tray, siblings ✅

**Test Scenario 2: Piece Token Context**
1. Create piece token
2. Call API: `get_context&token_id=100`
3. Check response has: token, node (no parent, no siblings) ✅

**Test Scenario 3: Final Token at Merge**
1. Final token with status='waiting' at merge node
2. Call API: `get_context&token_id=100`
3. Check response has: token, node, siblings (components), tray ✅

**Test Scenario 4: Missing Optional Data**
1. Token with no parent (orphaned)
2. Call API
3. Should return token + node (parent=null, tray=null) ✅

### API Testing

```bash
# Test with curl
curl -X POST "http://localhost:8888/source/dag_behavior_exec.php" \
  -H "Cookie: PHPSESSID=..." \
  -d "action=get_context&token_id=123"
```

**Expected:** Valid JSON response with context data

---

## 📦 Deliverables

### 1. Modified/Created Files

- ✅ `source/dag_behavior_exec.php` (create or modify)
  - Add `get_context` case (~80-100 lines)
  - Authentication, tenant DB setup (~20 lines if new file)
  - Total: ~100-120 lines

### 2. Test Evidence

- ✅ Manual test checklist completed (4 scenarios)
- ✅ API responses verified (curl or Postman)
- ✅ JSON structure matches spec
- ✅ No errors in PHP log

### 3. Results Document

- ✅ `docs/super_dag/tasks/results/task27.11_results.md`

---

## ✅ Definition of Done

- [ ] get_context API endpoint exists
- [ ] Returns correct data for component tokens
- [ ] Returns correct data for piece tokens
- [ ] Returns correct data for final token at merge
- [ ] Siblings data populated correctly
- [ ] Tray data populated (simple T-{serial} format)
- [ ] Manual testing pass (4 scenarios)
- [ ] JSON response structure matches spec
- [ ] No PHP errors
- [ ] Results document created

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO UI/JavaScript changes (frontend will consume API later)
- ❌ NO creating tray table
- ❌ NO implementing frontend rendering
- ❌ NO updating Work Queue UI files
- ❌ NO database schema changes
- ❌ NO touching behavior handlers
- ❌ NO implementing full component model
- ❌ NO creating new .md documentation

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 8 (UI data contract)

**Code:**
- `source/dag_behavior_exec.php` - File to create/modify
- `source/BGERP/Dag/ComponentFlowService.php` - For sibling status

---

## 📝 Results Template

```markdown
# Task 27.11 Results — get_context API Created

**Completed:** YYYY-MM-DD  
**Duration:** X hours  
**Status:** ✅ Complete

## Files Created/Modified
- `source/dag_behavior_exec.php` (+XXX lines or new file)

## API Testing
```bash
curl test results...
```

## Response Examples
```json
{
  "ok": true,
  "context": {...}
}
```

## Manual Testing
- ✅ Component token context correct
- ✅ Piece token context correct
- ✅ Final token at merge context correct
- ✅ Optional data handled gracefully

## Issues Encountered
- (List any issues)

## Next Steps
- Frontend integration (separate task/sprint)
- Component UI templates (separate task)
```

---

**END OF TASK**

