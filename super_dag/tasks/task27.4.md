# Task 27.4 — Implement Behavior × Token Type Validation Matrix

**Phase:** 1 - Core Token Lifecycle + Behavior Wiring  
**Priority:** 🔴 BLOCKER  
**Estimated Effort:** 3-4 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 1 - Token Lifecycle Integration  
**Dependencies:** Task 27.3 (BehaviorExecutionService refactored) ✅ **COMPLETE**  
**Blocks:** Task 27.5 (ComponentFlowService)

---

## ⚠️ **Context from Task 27.3 (COMPLETED)**

**BehaviorExecutionService Structure:**
- ✅ Already refactored with lifecycle integration
- ✅ Has `execute()` method as main entry point
- ✅ Routes to 5 main handlers: handleStitch, handleCut, handleEdge, handleQc, handleSinglePiece
- ✅ Has `fetchToken()` helper method

**Integration Point:**
- File: `source/BGERP/Dag/BehaviorExecutionService.php`
- Method: `execute()` (main entry point, ~line 98-187)
- Validation should go: **AFTER** behavior code validation, **BEFORE** handler routing

**Current execute() Flow:**
```
1. Validate required params (token_id, behavior_code, etc.)
2. Validate behavior_code matches node.behavior_code
3. [NEW] → Validate token_type compatibility ⭐ INSERT HERE
4. Route to behavior handler (switch statement)
```

---

## 🎯 Goal

Implement validation matrix เพื่อกัน human error / graph ผิด / work center map ผิด

**Key Principle:**
- ✅ Validate behavior-token type compatibility BEFORE execution
- ❌ NO allowing invalid combinations (e.g., CUT with piece token)

---

## 📋 Requirements

### 1. Implement Validation Matrix

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

**Add private method:**

```php
/**
 * Validate behavior-token type compatibility
 * 
 * Based on: BEHAVIOR_EXECUTION_SPEC.md Section 3
 * 
 * @param string $behaviorCode Behavior code (STITCH, CUT, etc.)
 * @param string $tokenType Token type (piece, component, batch)
 * @return bool True if compatible
 */
private function validateBehaviorTokenType(string $behaviorCode, string $tokenType): bool
{
    // Matrix from BEHAVIOR_EXECUTION_SPEC.md Section 3
    $matrix = [
        'CUT' => ['batch' => true, 'piece' => false, 'component' => false],
        'STITCH' => ['batch' => false, 'piece' => true, 'component' => true],
        'EDGE' => ['batch' => false, 'piece' => true, 'component' => true],
        'GLUE' => ['batch' => false, 'piece' => true, 'component' => true],
        'SKIVE' => ['batch' => false, 'piece' => true, 'component' => true],
        'EMBOSS' => ['batch' => false, 'piece' => true, 'component' => true],
        'HARDWARE_ASSEMBLY' => ['batch' => false, 'piece' => true, 'component' => false],
        'ASSEMBLY' => ['batch' => false, 'piece' => true, 'component' => false],
        'PACK' => ['batch' => false, 'piece' => true, 'component' => false],
        'QC_SINGLE' => ['batch' => false, 'piece' => true, 'component' => true],
        'QC_INITIAL' => ['batch' => false, 'piece' => true, 'component' => true],
        'QC_REPAIR' => ['batch' => false, 'piece' => true, 'component' => true],
        'QC_FINAL' => ['batch' => false, 'piece' => true, 'component' => false],
    ];
    
    return $matrix[$behaviorCode][$tokenType] ?? false;
}
```

### 2. Add Validation in execute() Method

**Location:** `BehaviorExecutionService::execute()` (main entry point)

**Current execute() structure (~line 98-187):**
```php
public function execute(...) {
    try {
        // 1. Validate token_id
        $tokenId = isset($context['token_id']) ? (int)$context['token_id'] : null;
        if (!$tokenId) { return error; }
        
        // 2. Fetch token
        $token = $this->fetchToken($tokenId);
        if (!$token) { return error; }
        
        // 3. Validate behavior_code vs node.behavior_code (existing)
        // ... validation code ...
        
        // ⭐ INSERT NEW VALIDATION HERE (between step 3 and 4)
        
        // 4. Route to behavior handler (switch statement)
        switch ($behaviorCode) { ... }
    }
}
```

**Add validation after existing validations, before switch:**

```php
        // Existing validations above...
        
        // Task 27.4: Validate token_type compatibility
        if (!$this->validateBehaviorTokenType($behaviorCode, $token['token_type'])) {
            error_log(sprintf(
                '[BehaviorExecutionService][execute] Token type mismatch: behavior=%s, token_type=%s, token_id=%d',
                $behaviorCode,
                $token['token_type'],
                $tokenId
            ));
            
            return [
                'ok' => false,
                'error' => 'BEHAVIOR_TOKEN_TYPE_MISMATCH',
                'app_code' => 'BEHAVIOR_400_TOKEN_TYPE_MISMATCH',
                'message' => sprintf(
                    'Behavior %s does not support token_type=%s (allowed: %s)',
                    $behaviorCode,
                    $token['token_type'],
                    $this->getAllowedTokenTypes($behaviorCode)
                ),
                'behavior_code' => $behaviorCode,
                'token_type' => $token['token_type'],
                'allowed_types' => $this->getAllowedTokenTypes($behaviorCode)
            ];
        }
        
        // Continue to behavior handler (existing switch statement)
        switch ($behaviorCode) { ... }
```

**Helper method (optional, for better error messages):**
```php
private function getAllowedTokenTypes(string $behaviorCode): string
{
    $matrix = [
        'CUT' => 'batch',
        'STITCH' => 'piece, component',
        'EDGE' => 'piece, component',
        'GLUE' => 'piece, component',
        'SKIVE' => 'piece, component',
        'EMBOSS' => 'piece, component',
        'HARDWARE_ASSEMBLY' => 'piece',
        'ASSEMBLY' => 'piece',
        'PACK' => 'piece',
        'QC_SINGLE' => 'piece, component',
        'QC_INITIAL' => 'piece, component',
        'QC_REPAIR' => 'piece, component',
        'QC_FINAL' => 'piece'
    ];
    
    return $matrix[$behaviorCode] ?? 'unknown';
}
```

---

## 🚧 Guardrails (MUST FOLLOW)

### Guardrail 1: Matrix Accuracy
- ✅ Matrix MUST match `BEHAVIOR_EXECUTION_SPEC.md` Section 3 exactly
- ❌ NO adding behaviors not in spec
- ❌ NO changing compatibility rules without updating spec
- ✅ Copy-paste matrix from spec (ป้องกันพิมพ์ผิด)

### Guardrail 2: Validation Placement
- ✅ Validate in `execute()` method (main entry point)
- ✅ Validate BEFORE calling behavior handlers
- ✅ Validate AFTER fetching token
- ❌ NO validating in individual handlers (DRY principle)

### Guardrail 3: Error Response Format
- ✅ Use standard error format:
  ```php
  [
      'ok' => false,
      'error' => 'BEHAVIOR_TOKEN_TYPE_MISMATCH',
      'app_code' => 'BEHAVIOR_400_TOKEN_TYPE_MISMATCH',
      'message' => 'Human-readable message',
      'behavior_code' => $behaviorCode,
      'token_type' => $tokenType
  ]
  ```
- ❌ NO throwing exceptions (return error array)
- ✅ Log validation failures

### Guardrail 4: Backward Compatibility
- ✅ Existing valid flows ต้องทำงานได้เหมือนเดิม
- ❌ NO breaking existing behavior calls
- ✅ Only block invalid combinations (new validation)

### Guardrail 5: Scope Limitation
- ✅ Modify ONLY `BehaviorExecutionService.php`
- ❌ NO touching other services
- ❌ NO UI changes
- ❌ NO database changes
- ❌ NO creating new files (except test file)

---

## 🧪 Testing Requirements

### Unit Tests

**File:** `tests/Unit/BehaviorTokenTypeValidationTest.php` (new)

**Test Cases (Minimum 13 behaviors × 3 token types = 39 tests):**

```php
// CUT tests
testCutWithBatchToken() // ✅ Should pass
testCutWithPieceToken() // ❌ Should fail
testCutWithComponentToken() // ❌ Should fail

// STITCH tests
testStitchWithBatchToken() // ❌ Should fail
testStitchWithPieceToken() // ✅ Should pass
testStitchWithComponentToken() // ✅ Should pass

// ASSEMBLY tests
testAssemblyWithBatchToken() // ❌ Should fail
testAssemblyWithPieceToken() // ✅ Should pass
testAssemblyWithComponentToken() // ❌ Should fail

// ... (cover all 13 behaviors)
```

**Run Command:**
```bash
vendor/bin/phpunit tests/Unit/BehaviorTokenTypeValidationTest.php --testdox
```

**Expected:** All tests pass (minimum 26 tests - test valid + invalid for key behaviors)

### Manual Testing

**Test Case 1: Valid Combination**
- Create piece token
- Execute STITCH behavior
- Should work normally ✅

**Test Case 2: Invalid Combination**
- Create piece token
- Try execute CUT behavior
- Should return `BEHAVIOR_TOKEN_TYPE_MISMATCH` error ❌

**Test Case 3: Component Token**
- Create component token (metadata with component_code)
- Execute STITCH behavior
- Should work ✅

---

## 📦 Deliverables

### 1. Modified Files

- ✅ `source/BGERP/Dag/BehaviorExecutionService.php`
  - Add `validateBehaviorTokenType()` method (~30 lines)
  - Add validation in `execute()` method (~15 lines)
  - Total: ~45 lines added

### 2. Test Files

- ✅ `tests/Unit/BehaviorTokenTypeValidationTest.php` (new)
  - Minimum 26 test cases (13 behaviors × 2 cases each)
  - ~200-300 lines

### 3. Results Document

- ✅ `docs/super_dag/tasks/results/task27.4_results.md`

---

## ✅ Definition of Done

- [ ] `validateBehaviorTokenType()` method implemented
- [ ] Matrix matches spec exactly (13 behaviors)
- [ ] Validation added to `execute()` method
- [ ] Unit tests pass (26+ tests)
- [ ] Manual testing pass (3 scenarios)
- [ ] Error response format correct
- [ ] No regressions (existing flows work)
- [ ] Results document created

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO implementing component flow logic (Phase 2)
- ❌ NO implementing split/merge (Phase 3)
- ❌ NO creating new behaviors
- ❌ NO database changes
- ❌ NO UI changes
- ❌ NO touching work_center table
- ❌ NO creating work_center_behavior table (legacy spec - not implementing)
- ❌ NO modifying other services

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 3 (Matrix)
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Section 3.2 (Behavior support matrix)

**Existing Code:**
- `source/BGERP/Dag/BehaviorExecutionService.php` - File to modify

---

## 📝 Results Template

```markdown
# Task 27.4 Results — Behavior-Token Type Validation Matrix

**Completed:** YYYY-MM-DD  
**Duration:** X hours  
**Status:** ✅ Complete

## Files Modified
- `source/BGERP/Dag/BehaviorExecutionService.php` (+45 lines)

## Files Created
- `tests/Unit/BehaviorTokenTypeValidationTest.php` (XXX lines, XX tests)

## Test Results
```
vendor/bin/phpunit tests/Unit/BehaviorTokenTypeValidationTest.php --testdox
✅ XX/XX tests passed
```

## Manual Testing
- ✅ Valid combination (STITCH + piece) works
- ✅ Invalid combination (CUT + piece) blocked correctly
- ✅ Error response format correct

## Issues Encountered
- (List any issues)

## Next Steps
- Proceed to Task 27.5 (Create ComponentFlowService)
```

---

**END OF TASK**

