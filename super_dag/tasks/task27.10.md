# Task 27.10 — Wrong Tray Validation Hook (Basic)

**Phase:** 4 - Failure Recovery  
**Priority:** 🟡 HIGH  
**Estimated Effort:** 3-4 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 4 - Failure Mode Recovery  
**Dependencies:** Task 27.9 (FailureRecoveryService exists)  
**Blocks:** Task 27.11 (UI data contract)

---

## 🎯 Goal

Implement wrong tray detection เพื่อกันเคสหยิบ token ผิดถาด

**Key Principle:**
- ✅ Validate tray assignment BEFORE allowing work
- ❌ ยังไม่ implement tray table (use simple logic)
- ✅ Fail gracefully (ถ้าตรวจไม่ได้ → allow work)

**⚠️ PHASE 4 SCOPE:** Basic validation only (ยังไม่มี tray table จริง)

---

## 📋 Requirements

### 1. Implement validateTray() in FailureRecoveryService

**File:** `source/BGERP/Dag/FailureRecoveryService.php`

**Update stub method from Task 27.9:**

```php
/**
 * Validate token is in correct tray
 * 
 * Phase 4: Basic validation (no tray table yet)
 * Uses component token → parent token logic
 * 
 * @param int $tokenId
 * @param string $scannedTrayCode
 * @return array ['valid' => bool, 'message' => string, 'correct_tray' => string]
 */
public function validateTray(int $tokenId, string $scannedTrayCode): array
{
    // 1. Fetch token
    $token = $this->fetchToken($tokenId);
    if (!$token) {
        // Token not found → fail-open (allow work, log warning)
        error_log("[FailureRecovery] validateTray: token not found, allowing work");
        return ['valid' => true, 'message' => 'Token not found (fail-open)'];
    }
    
    // 2. Get expected tray code
    $expectedTray = $this->getExpectedTrayCode($token);
    
    if (!$expectedTray) {
        // Cannot determine expected tray → fail-open
        error_log("[FailureRecovery] validateTray: cannot determine expected tray, allowing work");
        return ['valid' => true, 'message' => 'Tray validation unavailable (fail-open)'];
    }
    
    // 3. Compare
    if ($scannedTrayCode !== $expectedTray) {
        error_log(sprintf(
            "[FailureRecovery] Wrong tray: token=%d, expected=%s, scanned=%s",
            $tokenId, $expectedTray, $scannedTrayCode
        ));
        
        return [
            'valid' => false,
            'message' => "Token ของถาด {$expectedTray} ห้ามใช้กับถาด {$scannedTrayCode}",
            'correct_tray' => $expectedTray,
            'scanned_tray' => $scannedTrayCode
        ];
    }
    
    // 4. Valid
    return [
        'valid' => true,
        'message' => 'Tray correct',
        'correct_tray' => $expectedTray
    ];
}

/**
 * Get expected tray code for token
 * 
 * Phase 4: Simple logic (no tray table)
 * - Component token → use parent's serial as tray code
 * - Piece token → use own serial as tray code
 * 
 * @param array $token
 * @return string|null Expected tray code
 */
private function getExpectedTrayCode(array $token): ?string
{
    if ($token['token_type'] === 'component') {
        // Component → tray = parent serial
        if ($token['parent_token_id']) {
            $parent = $this->fetchToken($token['parent_token_id']);
            return "T-" . ($parent['serial_number'] ?? '');
        }
    } elseif ($token['token_type'] === 'piece') {
        // Piece → tray = own serial
        return "T-" . ($token['serial_number'] ?? '');
    }
    
    return null;
}
```

### 2. Add Tray Validation in Behavior Start Actions

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

**Add tray check in start handlers (optional - if tray scanning exists):**

```php
function handleStitchStart($tokenId, $nodeId, $scannedTrayCode = null) {
    // 1. Tray validation (if tray scanned)
    if ($scannedTrayCode) {
        $trayValidation = $this->recoveryService->validateTray($tokenId, $scannedTrayCode);
        
        if (!$trayValidation['valid']) {
            return [
                'ok' => false,
                'error' => 'WRONG_TRAY',
                'app_code' => 'BEHAVIOR_409_WRONG_TRAY',
                'message' => $trayValidation['message'],
                'correct_tray' => $trayValidation['correct_tray']
            ];
        }
    }
    
    // 2. Continue normal flow
    $this->lifecycleService->startWork($tokenId);
    $sessionResult = $this->sessionService->startToken($tokenId, $this->workerId, ...);
    // ...
}
```

---

## 🚧 Guardrails (MUST FOLLOW)

### Guardrail 1: Fail-Open Philosophy
- ✅ ถ้าตรวจไม่ได้ → allow work + log warning (ไม่ block)
- ✅ ถ้า tray table ยังไม่มี → allow work
- ❌ NO blocking work unnecessarily
- ✅ Log warnings for investigation

### Guardrail 2: Simple Logic Only
- ✅ Component → tray = "T-{parent_serial}"
- ✅ Piece → tray = "T-{own_serial}"
- ❌ NO complex tray allocation algorithm
- ❌ NO creating tray table (future)

### Guardrail 3: Optional Integration
- ✅ Tray validation = optional parameter in start actions
- ✅ If no tray scanned → skip validation
- ❌ NO requiring tray scan for all behaviors
- ✅ Behaviors that benefit: STITCH, GLUE, EDGE (component work)

### Guardrail 4: Error Response Format
- ✅ Use standard error format
- ✅ Include `correct_tray` in response (helpful for worker)
- ❌ NO throwing exceptions (return error array)
- ✅ app_code = `BEHAVIOR_409_WRONG_TRAY`

### Guardrail 5: Scope Limitation
- ✅ Modify: FailureRecoveryService, BehaviorExecutionService (tray param only)
- ❌ NO creating tray tables
- ❌ NO UI changes (frontend handles error display)
- ❌ NO database schema changes

---

## 🧪 Testing Requirements

### Unit Tests

**File:** `tests/Unit/FailureRecoveryServiceTest.php` (update from Task 27.9)

**Add Test Cases:**
1. `testValidateTrayForComponentToken()` - Component expects parent tray
2. `testValidateTrayForPieceToken()` - Piece expects own tray
3. `testValidateTrayCorrectMatch()` - Should pass
4. `testValidateTrayWrongMatch()` - Should fail
5. `testValidateTrayFailOpen()` - No parent → fail-open

**Run Command:**
```bash
vendor/bin/phpunit tests/Unit/FailureRecoveryServiceTest.php --testdox
```

**Expected:** All tests pass (11/11 - 6 from Task 27.9 + 5 new)

### Manual Testing

**Test Scenario 1: Correct Tray**
1. Component token (parent serial = F001)
2. Scan tray "T-F001"
3. Should allow work ✅

**Test Scenario 2: Wrong Tray**
1. Component token (parent serial = F001)
2. Scan tray "T-F002"
3. Should block + show error message ❌

**Test Scenario 3: No Tray Scan**
1. Start work without scanning tray
2. Should work normally (validation skipped) ✅

**Test Scenario 4: Fail-Open**
1. Token with no parent (orphaned)
2. Scan any tray
3. Should allow work + log warning ✅

---

## 📦 Deliverables

### 1. Modified Files

- ✅ `source/BGERP/Dag/FailureRecoveryService.php`
  - Update `validateTray()` (~50 lines)
  - Add `getExpectedTrayCode()` (~25 lines)
  - Total: ~75 lines added/modified

- ✅ `source/BGERP/Dag/BehaviorExecutionService.php` (optional)
  - Add tray validation in start handlers (~15 lines per handler)
  - Total: ~30-60 lines (2-4 handlers)

### 2. Test Files

- ✅ `tests/Unit/FailureRecoveryServiceTest.php` (update)
  - Add 5 test cases
  - ~60-80 lines added

### 3. Results Document

- ✅ `docs/super_dag/tasks/results/task27.10_results.md`

---

## ✅ Definition of Done

- [ ] validateTray() implemented (basic logic)
- [ ] getExpectedTrayCode() works for component and piece tokens
- [ ] Fail-open behavior works (no blocking if cannot validate)
- [ ] Optional tray validation in behavior start actions
- [ ] Unit tests pass (11/11)
- [ ] Manual testing pass (4 scenarios)
- [ ] Wrong tray blocked correctly
- [ ] Correct tray allowed
- [ ] Results document created

---

## ❌ Out of Scope (DO NOT DO)

- ❌ NO creating job_tray table (future - Component Flow full implementation)
- ❌ NO complex tray allocation logic
- ❌ NO supervisor override mechanisms (future)
- ❌ NO UI changes
- ❌ NO database schema changes
- ❌ NO implementing cascadeCancelFinal
- ❌ NO implementing all 7 failure scenarios (just QC fail + wrong tray)

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Section 7.2 (Wrong tray)
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Section 13.3 (Wrong tray scenario)

**Code:**
- `source/BGERP/Dag/FailureRecoveryService.php` - File to modify (from Task 27.9)
- `source/BGERP/Dag/BehaviorExecutionService.php` - Integration point

---

**END OF TASK**

