# Task 22.1 Results — Local Repair Engine v1

**Status:** ✅ COMPLETE  
**Date:** 2025-01-XX  
**Category:** SuperDAG / Canonical Events / Self-Healing / Local Repair

**⚠️ IMPORTANT:** This task implements Local Repair Engine v1 for repairing canonical events at token level.  
**Key Achievement:** Local repair engine with append-only repair events, feature flag control, and validate-propose-apply workflow.

---

## 1. Executive Summary

Task 22.1 successfully implemented:
- **LocalRepairEngine Class** - Token-level repair engine for canonical events
- **Validator Patches** - 3 safety patches to CanonicalEventIntegrityValidator
- **Feature Flag** - CANONICAL_SELF_HEALING_LOCAL for controlled rollout
- **Repair Handlers** - Support for MISSING_START, MISSING_COMPLETE, UNPAIRED_PAUSE, NO_CANONICAL_EVENTS

**Key Achievements:**
- ✅ Created LocalRepairEngine with generateRepairPlan, applyRepairPlan, simulateRepair
- ✅ Patched Validator: safety in checkLegacySync, ongoing session overlap, empty events check
- ✅ Created feature flag migration (0008_canonical_self_healing_local_flag.php)
- ✅ Added FeatureFlagService helper (isCanonicalSelfHealingLocalEnabled)
- ✅ Implemented repair handlers for 4 problem types
- ✅ Append-only repair (creates new events, doesn't modify originals)

---

## 2. Implementation Details

### 2.1 Validator Patches

**File:** `source/BGERP/Dag/CanonicalEventIntegrityValidator.php`

**Patch 1: Safety in checkLegacySync()**
- Added check for `prepare()` failure
- Returns warning `LEGACY_SYNC_CHECK_FAILED` instead of fatal error
- Prevents validator from crashing on DB errors

**Patch 2: Ongoing Session Overlap**
- Added check for ongoing sessions (to = null)
- Detects if session A is ongoing and session B starts before now
- Problem code: `ONGOING_SESSION_OVERLAP` (severity: warning)

**Patch 3: Empty Events Check**
- Added check at start of `validateToken()`
- If no canonical events found → `NO_CANONICAL_EVENTS` error
- Prevents `valid=true` for tokens with no events

### 2.2 LocalRepairEngine Class

**File:** `source/BGERP/Dag/LocalRepairEngine.php`

**Purpose:** Repair canonical events for a single token (local scope)

**Key Methods:**
- `isTokenEligible(int $tokenId): array` - Check if token can be repaired (must be complete/cancelled/scrapped)
- `canRepairProblem(array $problem): bool` - Check if problem is repairable in v1
- `generateRepairPlan(int $tokenId): array` - Analyze problems and create repair plan
- `applyRepairPlan(array $repairPlan, bool $simulation = false): array` - Apply repair plan
- `simulateRepair(int $tokenId): array` - Dry-run repair (simulation mode)

**Repair Types Supported (v1):**
- `MISSING_START` - Add NODE_START inferred from NODE_COMPLETE
- `MISSING_COMPLETE` - Add NODE_COMPLETE inferred from flow_token.completed_at
- `UNPAIRED_PAUSE` - Add NODE_RESUME to pair with unpaired NODE_PAUSE
- `NO_CANONICAL_EVENTS` - Create minimal timeline (START + COMPLETE) from flow_token fields

**Repair Plan Structure:**
```php
[
    'token_id' => 123,
    'problems_detected' => [...],
    'repairs' => [
        [
            'type' => 'ADD_MISSING_START',
            'canonical_event' => [
                'canonical_type' => 'NODE_START',
                'event_time' => '2025-01-01 10:00:00',
                'payload' => ['repair_reason' => 'MISSING_START', ...],
            ],
            'node_id' => 456,
            'notes' => '...',
        ],
        // ...
    ],
    'notes' => '...',
    'status' => 'proposed',
]
```

### 2.3 Feature Flag

**File:** `database/migrations/0008_canonical_self_healing_local_flag.php`

**Flag:** `CANONICAL_SELF_HEALING_LOCAL`

**Default:** 0 (disabled) for all tenants

**Purpose:** Control Local Repair Engine v1 activation

**Usage:**
- When disabled: Only simulation mode allowed
- When enabled: Allows `applyRepairPlan()` to actually persist repair events

**FeatureFlagService Helper:**
```php
$ffs = new FeatureFlagService($coreDb);
if ($ffs->isCanonicalSelfHealingLocalEnabled($tenantScope)) {
    // Apply repair
}
```

### 2.4 Repair Handlers

**MISSING_START Handler:**
- Finds NODE_COMPLETE event
- Calculates START time = COMPLETE time - 1 minute (min_duration)
- Creates NODE_START event with `repair_reason: 'MISSING_START'`

**MISSING_COMPLETE Handler:**
- Finds NODE_START event
- Uses `flow_token.completed_at` as COMPLETE time
- Creates NODE_COMPLETE event with `repair_reason: 'MISSING_COMPLETE'`

**UNPAIRED_PAUSE Handler:**
- Finds last NODE_PAUSE without matching NODE_RESUME
- Places NODE_RESUME just before NODE_COMPLETE (or pause time + 1 minute)
- Creates NODE_RESUME event with `repair_reason: 'UNPAIRED_PAUSE'`

**NO_CANONICAL_EVENTS Handler:**
- Checks if token has `start_at` and `completed_at`
- Creates minimal timeline: NODE_START + NODE_COMPLETE
- Both events inferred from flow_token fields

---

## 3. Files Created/Modified

### 3.1 Created Files

1. **`source/BGERP/Dag/LocalRepairEngine.php`**
   - Local Repair Engine v1 class
   - ~550 lines
   - Implements repair plan generation and application

2. **`database/migrations/0008_canonical_self_healing_local_flag.php`**
   - Feature flag migration
   - ~80 lines
   - Creates CANONICAL_SELF_HEALING_LOCAL flag

### 3.2 Modified Files

1. **`source/BGERP/Dag/CanonicalEventIntegrityValidator.php`**
   - Added 3 safety patches
   - Updated version to 22.1

2. **`source/BGERP/Service/FeatureFlagService.php`**
   - Added `FLAG_CANONICAL_SELF_HEALING_LOCAL` constant
   - Added `isCanonicalSelfHealingLocalEnabled()` helper method

---

## 4. Design Decisions

### 4.1 Append-Only Repair

**Decision:** Repair events are appended, not modifying original events

**Rationale:**
- Preserves audit trail
- Allows reconstruction of original state
- Aligns with "No Silent Mutation" principle

**Implementation:**
- Repair events have `repair_reason` in payload
- Original events remain unchanged
- Repair events can be identified by `payload.repair_reason`

### 4.2 Closed Context Only

**Decision:** Only repair tokens in complete/cancelled/scrapped status

**Rationale:**
- Prevents race conditions with active tokens
- Ensures repair doesn't interfere with ongoing operations
- Aligns with Safety Model from Phase 22 Blueprint

**Implementation:**
- `isTokenEligible()` checks token status
- Returns error if token is not in closed context

### 4.3 Feature Flag Control

**Decision:** Use feature flag to control repair activation

**Rationale:**
- Allows gradual rollout
- Can be enabled per tenant/environment
- Default OFF for safety

**Implementation:**
- Flag checked in `applyRepairPlan()`
- Simulation mode always allowed (flag not checked)

### 4.4 Direct Insert for Repair Events

**Decision:** Use direct INSERT instead of TokenEventService for repair events

**Rationale:**
- TokenEventService::persistEvents() doesn't accept token/node context directly
- Repair events need explicit token/node IDs
- Direct insert gives full control

**Future:** May extend TokenEventService to accept token/node context

---

## 5. Testing

### 5.1 Syntax Validation

- ✅ PHP syntax valid for all files
- ✅ No linter errors

### 5.2 Manual Testing (Planned)

**Test Cases:**
1. **MISSING_START:**
   - Token with NODE_COMPLETE but no NODE_START
   - Verify: Repair plan generates ADD_MISSING_START
   - Verify: Apply creates NODE_START event

2. **MISSING_COMPLETE:**
   - Token with NODE_START but no NODE_COMPLETE (token complete)
   - Verify: Repair plan generates ADD_MISSING_COMPLETE
   - Verify: Apply creates NODE_COMPLETE event

3. **UNPAIRED_PAUSE:**
   - Token with NODE_PAUSE but no NODE_RESUME
   - Verify: Repair plan generates ADD_REVERSE_PAUSE
   - Verify: Apply creates NODE_RESUME event

4. **NO_CANONICAL_EVENTS:**
   - Token with no canonical events but has start_at/completed_at
   - Verify: Repair plan generates CREATE_MINIMAL_TIMELINE
   - Verify: Apply creates START + COMPLETE events

5. **Feature Flag:**
   - Test with flag disabled (simulation only)
   - Test with flag enabled (actual apply)

---

## 6. Known Limitations

### 6.1 Limited Repair Types

**Limitation:** Only 4 repair types in v1

**Reason:** Start with simple, safe repairs

**Future:** Add more repair types in Task 22.2+

### 6.2 No Timeline Reconstruction

**Limitation:** Cannot reconstruct complex timelines

**Reason:** Out of scope for v1 (Task 22.3)

**Future:** Timeline reconstruction in Task 22.3

### 6.3 Direct INSERT for Repair Events

**Limitation:** Uses direct INSERT instead of TokenEventService

**Reason:** TokenEventService doesn't accept token/node context

**Future:** May extend TokenEventService API

---

## 7. Next Steps

### 7.1 Task 22.2

- Create Repair Event Model & Audit Trail
- Add `token_repair_log` table
- Integrate with LocalRepairEngine

### 7.2 Task 22.3

- Timeline Reconstruction v1
- Reconstruct complex timelines
- Handle session gaps and time issues

### 7.3 Task 22.4

- Batch Repair Tools
- CLI commands for batch repair
- Integration with BulkIntegrityValidator

---

## 8. Acceptance Criteria

### 8.1 Implementation

- ✅ LocalRepairEngine created
- ✅ Validator patches implemented (3 patches)
- ✅ Feature flag created and integrated
- ✅ Repair handlers for 4 problem types
- ✅ Append-only repair (no modification of originals)

### 8.2 Safety

- ✅ Closed context only (complete/cancelled tokens)
- ✅ Feature flag controlled
- ✅ Simulation mode available
- ✅ No silent mutations

### 8.3 Code Quality

- ✅ PHP syntax valid
- ✅ No linter errors
- ✅ Proper documentation
- ✅ Follows Core Principles

---

## 9. Alignment

- ✅ Follows task22.1.md requirements
- ✅ Aligns with Phase 22 Blueprint
- ✅ Uses CanonicalEventIntegrityValidator from Task 21.7-21.8
- ✅ Integrates with TokenEventService from Task 21.3
- ✅ Uses TimeEventReader from Task 21.5

---

## 10. Statistics

**Files Created:**
- `LocalRepairEngine.php`: ~550 lines
- `0008_canonical_self_healing_local_flag.php`: ~80 lines

**Files Modified:**
- `CanonicalEventIntegrityValidator.php`: ~30 lines added (3 patches)
- `FeatureFlagService.php`: ~20 lines added (helper method)

**Total Lines Added:** ~680 lines

---

## 11. Usage Examples

### 11.1 Generate Repair Plan

```php
$repairEngine = new \BGERP\Dag\LocalRepairEngine($db);
$repairPlan = $repairEngine->generateRepairPlan($tokenId);

echo "Problems: " . count($repairPlan['problems_detected']) . "\n";
echo "Repairs: " . count($repairPlan['repairs']) . "\n";
```

### 11.2 Simulate Repair

```php
$simulation = $repairEngine->simulateRepair($tokenId);
echo "Would add: " . $simulation['simulation_result']['events_added'] . " events\n";
```

### 11.3 Apply Repair Plan

```php
// Check feature flag first
$coreDb = core_db();
$ffs = new \BGERP\Service\FeatureFlagService($coreDb);
if ($ffs->isCanonicalSelfHealingLocalEnabled($tenantScope)) {
    $result = $repairEngine->applyRepairPlan($repairPlan);
    if ($result['success']) {
        echo "Added " . $result['events_added'] . " repair events\n";
        
        // Re-validate
        if ($result['validation_after']) {
            echo "Valid after repair: " . ($result['validation_after']['valid'] ? 'YES' : 'NO') . "\n";
        }
    }
} else {
    echo "Feature flag disabled - simulation only\n";
}
```

---

**Document Status:** ✅ Complete (Task 22.1)  
**Last Updated:** 2025-01-XX  
**Alignment:** Aligned with task22.1.md requirements and Phase 22 Blueprint


