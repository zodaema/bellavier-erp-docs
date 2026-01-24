# Task 21.2 Results — Node Behavior Execution (Canonical Events Only)

**Status:** ✅ COMPLETE  
**Date:** 2025-01-XX  
**Category:** SuperDAG / Node Behavior Engine

**⚠️ IMPORTANT:** This task implements execution mode resolution and canonical event generation.  
**Key Achievement:** NodeBehaviorEngine now "thinks" and generates canonical events, but still behind feature flag and does NOT write to database.

---

## 1. Executive Summary

Task 21.2 successfully implemented the "minimal brain" for `NodeBehaviorEngine::executeBehavior()`, enabling it to:
- Resolve execution mode from `(node_mode, line_type)` pair
- Generate canonical events based on execution mode
- Return structured canonical events array (no DB writes)
- Maintain backward compatibility with legacy effects structure

**Key Achievements:**
- ✅ Implemented `resolveExecutionMode()` - maps (node_mode, line_type) → execution_mode
- ✅ Implemented `buildCanonicalEvent()` - creates canonical event structures
- ✅ Implemented execution mode handlers: `executeHatSingle()`, `executeHatBatchQuantity()`, `executeClassicScan()`, `executeQcSingle()`
- ✅ Implemented `mapCanonicalEventsToLegacyEffects()` - compatibility layer
- ✅ Wired into `TokenLifecycleService::completeToken()` with feature flag protection
- ✅ Verified `line_type` resolution from `job_ticket.production_type`
- ✅ No database side effects (as required)

---

## 2. Implementation Details

### 2.1 Execution Mode Resolution

**File:** `source/BGERP/Dag/NodeBehaviorEngine.php`

**Method:** `resolveExecutionMode(?string $nodeMode, ?string $lineType): ?string`

**Purpose:** Maps (node_mode, line_type) → execution_mode

**Mapping Rules:**
- `HAT_SINGLE` + `hatthasilpa` → `hat_single`
- `BATCH_QUANTITY` + `hatthasilpa` → `hat_batch_quantity`
- `CLASSIC_SCAN` + `classic` → `classic_scan`
- `QC_SINGLE` + any line → `qc_single`

**Implementation:**
```php
protected function resolveExecutionMode(?string $nodeMode, ?string $lineType): ?string
{
    if (!$nodeMode) {
        return null;
    }
    
    switch ($nodeMode) {
        case 'HAT_SINGLE':
            if ($lineType === 'hatthasilpa') {
                return 'hat_single';
            }
            return null; // Classic not supported for HAT_SINGLE in Task 21.2
            
        case 'BATCH_QUANTITY':
            if ($lineType === 'hatthasilpa') {
                return 'hat_batch_quantity';
            }
            return null; // Classic not focused in Task 21.2
            
        case 'CLASSIC_SCAN':
            if ($lineType === 'classic') {
                return 'classic_scan';
            }
            return null;
            
        case 'QC_SINGLE':
            return 'qc_single'; // Works with both lines
            
        default:
            return null;
    }
}
```

**Note:** Task 21.2 does not throw exceptions for unsupported combinations - returns null and logs warning.

### 2.2 Canonical Event Builder

**Method:** `buildCanonicalEvent(string $type, array $context, array $payload = []): array`

**Purpose:** Creates canonical event structure (does NOT insert to DB)

**Structure:**
```php
[
    'event_type'    => string, // e.g., 'NODE_START', 'NODE_COMPLETE', 'COMP_BIND'
    'token_id'      => int|null,
    'node_id'       => int|null,
    'job_ticket_id' => int|null,
    'payload'       => array,
    'event_time'    => string, // MySQL DATETIME format
]
```

**Implementation:**
```php
protected function buildCanonicalEvent(string $type, array $context, array $payload = []): array
{
    $token = $context['token'] ?? [];
    $node = $context['node'] ?? [];
    $job = $context['job_ticket'] ?? [];
    $now = $context['time']['now'] ?? TimeHelper::now();
    
    return [
        'event_type'    => $type,
        'token_id'      => $token['id_token'] ?? null,
        'node_id'       => $node['id_node'] ?? null,
        'job_ticket_id' => $job['id_job_ticket'] ?? null,
        'payload'       => $payload,
        'event_time'    => TimeHelper::toMysql($now),
    ];
}
```

**Note:** Task 21.2 does not insert to DB. Task 21.3 will persist canonical events to `token_event` table.

### 2.3 Execution Mode Handlers

**Methods:**
- `executeHatSingle(array $context): array`
- `executeHatBatchQuantity(array $context): array`
- `executeClassicScan(array $context): array`
- `executeQcSingle(array $context): array`

**Implementation Strategy:**
- Task 21.2: Minimal implementation - focus on "complete node" case
- Each handler generates `NODE_COMPLETE` canonical event with appropriate payload
- Future tasks (21.3+) will add more sophisticated logic (NODE_START, NODE_PAUSE, NODE_RESUME, etc.)

**Example (executeHatSingle):**
```php
protected function executeHatSingle(array $context): array
{
    $events = [];
    
    // Task 21.2: Focus case "complete node" - minimal implementation
    $events[] = $this->buildCanonicalEvent('NODE_COMPLETE', $context, [
        'reason' => 'normal',
    ]);
    
    // Placeholder: Future tasks may add NODE_START, NODE_PAUSE, NODE_RESUME
    return $events;
}
```

### 2.4 Legacy Effects Compatibility Layer

**Method:** `mapCanonicalEventsToLegacyEffects(array $canonicalEvents, array $context): array`

**Purpose:** Provides backward compatibility while transitioning to canonical events

**Implementation:**
- Maps canonical events to legacy `effects` structure
- Preserves existing API contracts
- Task 21.3-21.4 will migrate consumers to use `canonical_events` directly

**Note:** This is a temporary compatibility layer. Future tasks will deprecate `effects` in favor of `canonical_events`.

### 2.5 Updated executeBehavior() Method

**Changes:**
- Resolves execution mode using `resolveExecutionMode()`
- Dispatches to appropriate execution mode handler
- Maps canonical events to legacy effects
- Returns structured result with `canonical_events` and `execution_mode`

**Return Structure:**
```php
[
    'ok'               => bool,
    'node_mode'        => string,
    'line_type'        => string,
    'execution_mode'   => string|null,
    'canonical_events' => array,
    'effects'          => array, // Legacy compatibility
    'meta'             => [
        'version'   => '21.2',
        'executed'  => true,
        'timestamp' => string,
    ],
]
```

### 2.6 Line Type Resolution

**File:** `source/BGERP/Dag/NodeBehaviorEngine.php`

**Method:** `buildExecutionContext()` - updated to resolve `line_type` from `job_ticket.production_type`

**Mapping:**
- `production_type = 'hatthasilpa'` → `line_type = 'hatthasilpa'`
- `production_type = 'oem'` or `'classic'` → `line_type = 'classic'`
- `production_type = 'hybrid'` → `line_type = 'hatthasilpa'` (default, may need context-specific resolution in future)

**Implementation:**
```php
// Get line_type from job_ticket.production_type (Task 21.2: verified)
$productionType = $jobTicket['production_type'] ?? null;
$lineType = null;
if ($productionType) {
    $pt = strtolower(trim($productionType));
    if ($pt === 'hatthasilpa') {
        $lineType = 'hatthasilpa';
    } elseif (in_array($pt, ['oem', 'classic'])) {
        $lineType = 'classic';
    } elseif ($pt === 'hybrid') {
        $lineType = 'hatthasilpa'; // Default for Task 21.2
    }
}
```

**Helper Method:** `fetchJobTicketFromInstance(int $instanceId): ?array`
- Fetches job_ticket data from `job_graph_instance` if not provided in context
- Used when `buildExecutionContext()` is called without `$jobTicket` parameter

### 2.7 Integration with TokenLifecycleService

**File:** `source/BGERP/Service/TokenLifecycleService.php`

**Method:** `completeToken()` - updated to call NodeBehaviorEngine

**Integration Point:**
```php
// Task 21.2: Execute Node Behavior Engine (behind feature flag, read-only)
$coreDb = \core_db();
$ffs = new \BGERP\Service\FeatureFlagService($coreDb);
$tenantScope = $this->tenantCode ?? ($_SESSION['current_org_code'] ?? 'GLOBAL');
if ($ffs->getFlag('NODE_BEHAVIOR_EXPERIMENTAL', false, $tenantScope)) {
    try {
        $node = $this->fetchNode($token['current_node_id']);
        if ($node) {
            $behaviorEngine = new NodeBehaviorEngine($this->db);
            $context = $behaviorEngine->buildExecutionContext($token, $node);
            $behaviorResult = $behaviorEngine->executeBehavior($context);
            
            // Task 21.2: Log canonical events for inspection (no DB write yet)
            if (!empty($behaviorResult['canonical_events'])) {
                error_log(sprintf(
                    '[CID:%s][NodeBehaviorEngine] Token %d completed at node %d: %d canonical events generated',
                    $GLOBALS['cid'] ?? 'UNKNOWN',
                    $tokenId,
                    $token['current_node_id'],
                    count($behaviorResult['canonical_events'])
                ));
                // Task 21.3: Will persist canonical_events to token_event table
            }
        }
    } catch (\Exception $e) {
        // Task 21.2: Log but don't fail token completion if behavior engine errors
        error_log(sprintf(
            '[CID:%s][NodeBehaviorEngine] Error during behavior execution for token %d: %s',
            $GLOBALS['cid'] ?? 'UNKNOWN',
            $tokenId,
            $e->getMessage()
        ));
    }
}
```

**Safety:**
- Feature flag protection: `NODE_BEHAVIOR_EXPERIMENTAL` must be enabled
- Error handling: Logs errors but does not fail token completion
- Read-only: No database writes from behavior engine
- Non-blocking: Token completion proceeds even if behavior engine fails

---

## 3. Files Modified

### 3.1 Modified Files

1. **`source/BGERP/Dag/NodeBehaviorEngine.php`**
   - Updated class docblock (version 21.2)
   - Updated `buildExecutionContext()` - resolves `line_type` from `production_type`
   - Completely rewrote `executeBehavior()` - implements execution mode resolution and canonical event generation
   - Added `resolveExecutionMode()` method
   - Added `buildCanonicalEvent()` method
   - Added `executeHatSingle()` method
   - Added `executeHatBatchQuantity()` method
   - Added `executeClassicScan()` method
   - Added `executeQcSingle()` method
   - Added `mapCanonicalEventsToLegacyEffects()` method
   - Added `fetchJobTicketFromInstance()` helper method

2. **`source/BGERP/Service/TokenLifecycleService.php`**
   - Added `use BGERP\Dag\NodeBehaviorEngine;`
   - Updated `completeToken()` - calls NodeBehaviorEngine behind feature flag

### 3.2 No New Files Created

- All changes were made to existing files

---

## 4. Design Decisions

### 4.1 Execution Mode Resolution

**Decision:** Map (node_mode, line_type) → execution_mode

**Rationale:**
- Aligns with Node_Behavier.md AXIOM A3
- Enables "One Graph, Two Lines" architecture
- Separates behavior type (node_mode) from execution context (line_type)

### 4.2 Canonical Events Only

**Decision:** Output only canonical event structures, no custom keys

**Rationale:**
- Aligns with Core Principles 14-15 (Canonical Event Framework)
- Ensures system-wide consistency
- Prevents custom event types that break system integrity

### 4.3 Minimal Implementation

**Decision:** Focus on "complete node" case for Task 21.2

**Rationale:**
- Task 21.2 is behind feature flag - safe to be minimal
- Future tasks (21.3+) will add more sophisticated logic
- Allows incremental development and testing

### 4.4 Legacy Effects Compatibility

**Decision:** Maintain `effects` structure alongside `canonical_events`

**Rationale:**
- Prevents breaking existing consumers
- Allows gradual migration to canonical events
- Task 21.3-21.4 will migrate consumers to use `canonical_events` directly

### 4.5 Feature Flag Protection

**Decision:** Guard all behavior engine calls with `NODE_BEHAVIOR_EXPERIMENTAL` feature flag

**Rationale:**
- Prevents accidental production usage
- Allows controlled rollout
- Enables testing in dev/staging environments

### 4.6 Error Handling

**Decision:** Log errors but don't fail token completion

**Rationale:**
- Behavior engine is experimental - should not block core functionality
- Allows graceful degradation
- Future tasks may add more sophisticated error handling

---

## 5. Testing

### 5.1 Syntax Validation

- ✅ PHP syntax valid for all modified files
- ✅ No linter errors

### 5.2 Manual Testing (Planned)

**Test Cases:**
1. HAT_SINGLE + hatthasilpa → generates `hat_single` execution mode
2. BATCH_QUANTITY + hatthasilpa → generates `hat_batch_quantity` execution mode
3. CLASSIC_SCAN + classic → generates `classic_scan` execution mode
4. QC_SINGLE + any line → generates `qc_single` execution mode
5. Unsupported combinations → returns null execution mode, logs warning
6. Feature flag disabled → behavior engine not called
7. Feature flag enabled → canonical events generated and logged

**Note:** Unit tests will be added in Task 21.3+ when behavior engine is more stable.

---

## 6. Known Limitations

### 6.1 Minimal Implementation

**Limitation:** Only "complete node" case implemented

**Reason:** Task 21.2 scope (minimal brain)

**Future:** Task 21.3+ will add NODE_START, NODE_PAUSE, NODE_RESUME, etc.

### 6.2 No Database Persistence

**Limitation:** Canonical events are not persisted to database

**Reason:** Task 21.2 scope (read-only)

**Future:** Task 21.3 will persist canonical events to `token_event` table

### 6.3 Hybrid Production Type

**Limitation:** Hybrid production type defaults to 'hatthasilpa' line_type

**Reason:** Task 21.2 scope (minimal implementation)

**Future:** May need context-specific resolution for hybrid type

### 6.4 Classic Line Limited Support

**Limitation:** Classic line only supported for CLASSIC_SCAN and QC_SINGLE node modes

**Reason:** Task 21.2 focuses on Hatthasilpa line

**Future:** Task 21.3+ will add full Classic line support

---

## 7. Next Steps

### 7.1 Task 21.3 (Planned)

- Persist canonical events to `token_event` table
- Implement more sophisticated behavior logic for each execution mode
- Add NODE_START, NODE_PAUSE, NODE_RESUME events
- Migrate consumers from `effects` to `canonical_events`

### 7.2 Task 21.4 (Planned)

- Internal Behavior Registry (NOT plugin-extensible)
- Versioning and migration support
- Full Classic line support

---

## 8. Acceptance Criteria

### 8.1 Implementation

- ✅ `executeBehavior()` returns canonical events array
- ✅ No database writes from behavior engine
- ✅ Feature flag protection in place
- ✅ Execution mode resolution implemented
- ✅ Canonical event builder implemented
- ✅ All execution mode handlers implemented (minimal)

### 8.2 Integration

- ✅ Wired into `TokenLifecycleService::completeToken()`
- ✅ Feature flag check implemented
- ✅ Error handling implemented (non-blocking)
- ✅ Logging for canonical events inspection

### 8.3 Code Quality

- ✅ PHP syntax valid
- ✅ No linter errors
- ✅ Proper documentation and comments
- ✅ Follows Node_Behavier.md and Core Principles

---

## 9. Alignment

- ✅ Follows Node_Behavier.md AXIOM A3 (Runtime uses node_mode + line_type)
- ✅ Follows Core Principles 14-15 (Canonical Events)
- ✅ Follows node_behavior_model.md Section 4.0 (Canonical Events Integration)
- ✅ Maintains backward compatibility with legacy effects structure
- ✅ Feature flag protection prevents accidental production usage

---

**Document Status:** ✅ Complete (Task 21.2)  
**Last Updated:** 2025-01-XX  
**Alignment:** Aligned with Node_Behavier.md + Core Principles 14-15

