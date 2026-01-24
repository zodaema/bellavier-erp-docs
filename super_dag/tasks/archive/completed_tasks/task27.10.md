# Task 27.10 — Wrong Tray Validation Hook (Basic)

**Phase:** 4 - Failure Recovery  
**Priority:** 🟡 HIGH  
**Estimated Effort:** 3-4 hours  
**Status:** 📋 Pending

**Parent Task:** Phase 4 - Failure Mode Recovery  
**Dependencies:** Task 27.9 (FailureRecoveryService exists) ✅ **COMPLETE**  
**Blocks:** Task 27.11 (UI data contract)

---

## ⚠️ **Context from Phase 1-4 (Tasks 27.2-27.9 COMPLETE)**

**Phase 4 So Far:**
- ✅ Task 27.9: FailureRecoveryService created (+280 lines)
- ✅ validateTray() stub exists (always returns valid)
- ✅ QC fail recovery implemented (scrap + spawn + link)
- ✅ Component scrap detection added (checkComponentScrapStatus)
- ✅ Merge idempotency implemented (retry-safe)
- ✅ 9/9 unit tests passed

**Current State of validateTray():**
```php
// Task 27.9 - Stub (always pass):
public function validateTray(int $tokenId, string $scannedTrayCode): array {
    return ['valid' => true, 'message' => 'Tray validation not implemented yet'];
}
```

**This Task (27.10):**
- Replace stub with real validation logic
- Simple tray logic: Component → "T-{parent_serial}", Piece → "T-{own_serial}"
- Fail-open philosophy (allow work if cannot validate)
- Optional integration in behavior start handlers

**Note:** This completes Phase 4 (Failure Recovery). Task 27.11+ moves to Phase 5 (UI + Analytics).

---

## 🚨 **CRITICAL: Simple Tray Logic (No Table Yet)**

**⚠️ Phase 4 Limitation:**
- ❌ NO tray table (job_tray, tray_assignment, etc.)
- ❌ NO complex tray allocation algorithm
- ✅ Simple rule-based validation only

**Tray Logic (Simple):**
```
Component Token → Expected Tray = "T-{parent_serial}"
Piece Token → Expected Tray = "T-{own_serial}"
Batch Token → No tray validation (skip)
```

**Fail-Open Philosophy:**
- Cannot determine tray → allow work (log warning)
- Token not found → allow work (log warning)
- No serial number → allow work (log warning)

**Future Enhancement (Phase 5+):**
- Create job_tray table
- Complex allocation (multi-component per tray, tray capacity, etc.)
- Tray lifecycle (created, filled, moved, completed)

---

## 🎯 Goal

Implement wrong tray detection เพื่อกันเคสหยิบ token ผิดถาด

**Key Principle:**
- ✅ Validate tray assignment BEFORE allowing work
- ✅ Simple logic (serial-based, no table)
- ✅ Fail gracefully (ถ้าตรวจไม่ได้ → allow work + log)
- ❌ NO complex allocation (Phase 4 scope limitation)

---

## 📝 Quick Summary (TL;DR)

**What This Task Does:**
1. Implements validateTray() in FailureRecoveryService (replaces stub from 27.9)
2. Simple tray logic: T-{parent_serial} for components, T-{own_serial} for pieces
3. Fail-open behavior (allow work if cannot validate)
4. Optional integration in behavior start handlers
5. 5 unit tests for validation scenarios

**What This Task Does NOT Do:**
- ❌ Create tray tables (job_tray, tray_assignment)
- ❌ Complex allocation algorithm
- ❌ UI changes (frontend handles error display)
- ❌ Schema changes

**Key Deliverable:**
- Working tray validation (~75 lines)
- 10 total tests (5 existing + 5 new)
- Completes Phase 4 (Failure Recovery)

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
    
    // 3. Compare (case-insensitive)
    if (strcasecmp($scannedTrayCode, $expectedTray) !== 0) {
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
            if (!$parent) {
                return null;  // Parent not found → fail-open
            }
            
            $serial = $parent['serial_number'] ?? null;
            if (empty($serial)) {
                return null;  // No serial → fail-open
            }
            
            return "T-" . $serial;
        }
    } elseif ($token['token_type'] === 'piece') {
        // Piece → tray = own serial
        $serial = $token['serial_number'] ?? null;
        if (empty($serial)) {
            return null;  // No serial → fail-open
        }
        
        return "T-" . $serial;
    }
    
    // Batch or unknown type → no tray validation
    return null;
}

/**
 * ⚠️ Note: Missing Serial Numbers
 * 
 * Some tokens may not have serial_number assigned if:
 * - Job created before serial issuance
 * - Token spawned in batch mode (serials generated later)
 * - System migration (legacy tokens)
 * 
 * Therefore: NULL serial → return null → validateTray() fails open
 */
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
- ❗ **Depth Limit:** Query max 1 parent level only (no parent of parent)
- ❗ **Example:** Component → fetch parent → stop (don't fetch parent's parent)

### Guardrail 3: Optional Integration (Selective Behaviors Only)
- ✅ Tray validation = optional parameter in start actions
- ✅ If no tray scanned → skip validation
- ❌ NO requiring tray scan for all behaviors

**Behaviors to Integrate (Tray-Relevant):**
- ✅ STITCH (component assembly work)
- ✅ EDGE (edge treatment - tray-based)
- ✅ GLUE (gluing components - tray-based)
- ✅ HARDWARE_ASSEMBLY (component work)

**Behaviors to SKIP (No Tray Usage):**
- ❌ CUT (no tray - direct from batch)
- ❌ QC (inspection - no tray logic)
- ❌ PACK (final packaging - different system)
- ❌ EMBOSS (embossing - no tray)

**Integration Scope:** Add `$scannedTrayCode = null` parameter to 4 handlers only (not all 13)

### Guardrail 4: Serial Format & Comparison
- ✅ Tray code format: `"T-" . $serialNumber` (exact format)
- ✅ **Case-insensitive comparison:** `strcasecmp()` or `strtoupper()` both sides
- ❌ NO case-sensitive comparison (user might scan "t-f001" vs "T-F001")
- ✅ Missing serial → fail-open (allow work + log warning)

**Example:**
```php
// Generate expected tray:
$expectedTray = "T-" . ($parent['serial_number'] ?? '');

// Compare (case-insensitive):
if (strcasecmp($scannedTrayCode, $expectedTray) !== 0) {
    // Wrong tray
}
```

### Guardrail 5: Error Response Format
- ✅ Use standard error format
- ✅ Include `correct_tray` in response (helpful for worker)
- ❌ NO throwing exceptions (return error array)
- ✅ app_code = `BEHAVIOR_409_WRONG_TRAY`

### Guardrail 6: Pure Function (Read-Only)
- ❗ **CRITICAL:** validateTray() MUST be a pure function
- ✅ Read-only operation (queries only)
- ❌ **NO updating flow_token** (no status change, no metadata update)
- ❌ **NO calling TokenLifecycleService** (no state transitions)
- ❌ **NO side effects** (only return validation result)
- ✅ Logging allowed (error_log only)

**Why Critical:** Validation should not change system state. Only behavior handlers change state.

### Guardrail 7: Missing Serial Handling
- ✅ **Assumption:** Some tokens may not have serial_number yet
- ✅ **Reason:** Job creation might happen before serial issuance
- ✅ **Behavior:** If serial_number is NULL/empty → fail-open (allow work)
- ✅ **Logging:** Log warning for missing serials (helps debugging)
- ❌ **NO throwing errors** for missing serials

**Example:**
```php
if (empty($token['serial_number'])) {
    error_log("[FailureRecovery] Token {$tokenId} has no serial, allowing work (fail-open)");
    return ['valid' => true, 'message' => 'No serial - validation skipped'];
}
```

### Guardrail 8: Scope Limitation
- ✅ Modify: FailureRecoveryService.validateTray() only
- ✅ Optional: BehaviorExecutionService (4 handlers: STITCH, EDGE, GLUE, HARDWARE_ASSEMBLY)
- ❌ NO creating tray tables
- ❌ NO UI changes (frontend handles error display)
- ❌ NO database schema changes

### Guardrail 9: Validation Timing (Start Actions Only)
- ❗ **validateTray() MUST be called only during "start" actions**
- ✅ Call in: handleStitchStart, handleEdgeStart, handleGlueStart, etc.
- ❌ **NO calling during:**
  - pause/resume actions (already working)
  - complete actions (work already done)
  - routing logic (not behavior-specific)
- ✅ Reason: Tray validation prevents wrong work from starting (not pausing/completing)

### Guardrail 10: Structured Error Response (UI-Friendly)
- ✅ **Return structured JSON** for UI consumption
- ✅ Required fields:
  - `valid` (bool) - Pass/fail status
  - `message` (string) - Thai language message for display
  - `correct_tray` (string|null) - Expected tray code
  - `scanned_tray` (string) - What was scanned (on error only)
- ✅ Optional: `code` (string) - Error code for programmatic handling (e.g., "TRAY_MISMATCH")
- ❌ NO Thai-only error codes (use English codes, Thai messages)

**Example Response:**
```php
// Error:
['valid' => false, 'message' => 'ถาดไม่ตรงกับชิ้นงาน...', 'correct_tray' => 'T-F001', 'scanned_tray' => 'T-F003']

// Success:
['valid' => true, 'message' => 'Tray correct', 'correct_tray' => 'T-F001']
```

### Guardrail 11: Never Throws Exceptions
- ❗ **validateTray() MUST NEVER throw exceptions**
- ✅ All errors return error arrays: `['valid' => false, 'message' => ...]`
- ❌ NO `throw new Exception()` (would break behavior flow)
- ✅ Reason: Validation is optional feature, must not crash worker app

---

## 🧪 Testing Requirements

### Unit Tests

**File:** `tests/Unit/FailureRecoveryServiceTest.php` (update from Task 27.9)

**Current Tests (from Task 27.9):** 5 tests (QC fail recovery)

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

**Expected:** All tests pass (10/10 - 5 from Task 27.9 + 5 new)

**Note:** ParallelMachineCoordinatorErrorTest (4 tests) runs separately, total = 14 tests across both files

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

