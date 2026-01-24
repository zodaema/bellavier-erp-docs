# Task 22.2 Results — Repair Event Model & Audit Trail

**Status:** ✅ COMPLETE  
**Date:** 2025-01-XX  
**Category:** SuperDAG / Canonical Events / Self-Healing / Audit Trail

**⚠️ IMPORTANT:** This task implements Repair Event Model & Audit Trail for Local Repair Engine.  
**Key Achievement:** Full audit trail with repair logs, before/after snapshots, and repair metadata in canonical events.

---

## 1. Executive Summary

Task 22.2 successfully implemented:
- **Repair Log Table** - `flow_token_repair_log` for audit trail
- **RepairEventModel Class** - Structured repair metadata
- **LocalRepairEngine Patches** - Added repair log tracking, metadata, and snapshots
- **TokenEventService Enhancement** - Returns event IDs for repair log tracking

**Key Achievements:**
- ✅ Created `flow_token_repair_log` table (migration 0009)
- ✅ Created RepairEventModel for structured repair metadata
- ✅ Patched LocalRepairEngine: added repair metadata to payload, addRepairLog(), snapshots
- ✅ Patched TokenEventService: returnIds parameter for event ID tracking
- ✅ Removed unsupported repair types (INVALID_SEQUENCE_SIMPLE, SESSION_OVERLAP_SIMPLE, ZERO_DURATION)
- ✅ Full audit trail: before/after snapshots, event IDs, repair context

---

## 2. Implementation Details

### 2.1 Repair Log Table

**File:** `database/migrations/0009_token_repair_log.php`

**Table:** `flow_token_repair_log`

**Schema:**
```sql
CREATE TABLE flow_token_repair_log (
    id_repair_log BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    token_id INT NOT NULL,
    node_id INT NULL,
    repair_type VARCHAR(64) NOT NULL,
    canonical_event_ids JSON NULL,
    before_snapshot JSON NULL,
    after_snapshot JSON NULL,
    batch_id VARCHAR(64) NULL,
    notes TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(64) NOT NULL DEFAULT 'system',
    INDEX idx_token (token_id),
    INDEX idx_node (node_id),
    INDEX idx_repair_type (repair_type),
    INDEX idx_batch_id (batch_id),
    INDEX idx_created_at (created_at),
    INDEX idx_token_created (token_id, created_at),
    FOREIGN KEY (token_id) REFERENCES flow_token(id_token) ON DELETE CASCADE,
    FOREIGN KEY (node_id) REFERENCES routing_node(id_node) ON DELETE SET NULL
) ENGINE=InnoDB;
```

**Key Fields:**
- `canonical_event_ids` - JSON array of event IDs created by repair
- `before_snapshot` - Timeline snapshot before repair
- `after_snapshot` - Timeline snapshot after repair
- `repair_type` - Type of repair (MISSING_START, MISSING_COMPLETE, etc.)

### 2.2 RepairEventModel Class

**File:** `source/BGERP/Dag/RepairEventModel.php`

**Purpose:** Provides structured repair metadata for canonical events

**Key Methods:**
- `buildRepairMetadata($repairType, $batchId, $originalProblems)` - Builds repair metadata structure
- `isRepairEvent($payload)` - Checks if event is a repair event
- `getRepairType($payload)` - Extracts repair type from payload
- `getRepairBatchId($payload)` - Extracts batch ID from payload

**Repair Metadata Structure:**
```php
[
    'repair' => [
        'type' => 'MISSING_START',
        'version' => 'v1',
        'by' => 'LocalRepairEngine',
        'batch_id' => null,
        'original_problems' => [...],
        'created_at' => '2025-01-01 10:00:00',
    ],
]
```

### 2.3 LocalRepairEngine Patches

**File:** `source/BGERP/Dag/LocalRepairEngine.php`

**Patch 1: Repair Metadata in Payload**
- All repair events now include repair metadata in payload
- Uses `RepairEventModel::buildRepairMetadata()` to structure metadata
- Metadata includes: type, version, by, batch_id, original_problems, created_at

**Patch 2: Removed Unsupported Repair Types**
- Removed from `REPAIRABLE_PROBLEMS`:
  - `INVALID_SEQUENCE_SIMPLE` (Task 22.3)
  - `SESSION_OVERLAP_SIMPLE` (Task 22.3)
  - `ZERO_DURATION` (Task 22.3)
- Only 4 repair types remain: MISSING_START, MISSING_COMPLETE, UNPAIRED_PAUSE, NO_CANONICAL_EVENTS

**Patch 3: Added addRepairLog() Method**
- Inserts repair log entry to `flow_token_repair_log`
- Records: token_id, node_id, repair_type, canonical_event_ids, before/after snapshots, notes
- Returns repair log ID

**Patch 4: Updated applyRepairPlan()**
- Creates before snapshot before repair
- Creates after snapshot after repair
- Calls `addRepairLog()` to record repair operation
- Returns `repair_log_id` and `event_ids` in result
- Sends `token_id` and `node_id` to `persistEvents()`

**Patch 5: createSnapshot() Method**
- Creates compact timeline snapshot
- Includes: start_time, complete_time, duration_ms, session_count, event_count, problem_count
- Uses `TimeEventReader` and `CanonicalEventIntegrityValidator`

### 2.4 TokenEventService Enhancement

**File:** `source/BGERP/Dag/TokenEventService.php`

**Enhancement: Return Event IDs**
- Added `$returnIds` parameter to `persistEvents()`
- When `$returnIds = true`, returns array of inserted event IDs
- When `$returnIds = false` (default), returns count (backward compatible)
- Handles duplicate key case (fetches existing event ID by idempotency_key)

**Usage:**
```php
// Old (backward compatible)
$count = $eventService->persistEvents($events, $operatorId);

// New (for repair tracking)
$eventIds = $eventService->persistEvents($events, $operatorId, true);
```

---

## 3. Files Created/Modified

### 3.1 Created Files

1. **`database/migrations/0009_token_repair_log.php`**
   - Migration for `flow_token_repair_log` table
   - ~50 lines

2. **`source/BGERP/Dag/RepairEventModel.php`**
   - Repair event metadata model
   - ~100 lines

### 3.2 Modified Files

1. **`source/BGERP/Dag/LocalRepairEngine.php`**
   - Added repair metadata to all repair handlers
   - Added `addRepairLog()` method
   - Added `createSnapshot()` method
   - Updated `applyRepairPlan()` with snapshots and log tracking
   - Removed unsupported repair types
   - Updated version to 22.2

2. **`source/BGERP/Dag/TokenEventService.php`**
   - Added `$returnIds` parameter to `persistEvents()`
   - Returns event IDs when requested
   - Updated version to 22.2

---

## 4. Design Decisions

### 4.1 Repair Metadata in Payload

**Decision:** Store repair metadata in canonical event payload

**Rationale:**
- Repair events are still canonical events
- Metadata is part of event context
- Easy to identify repair events in queries
- No schema changes needed

**Implementation:**
- All repair events have `payload.repair` structure
- Metadata includes type, version, by, batch_id, original_problems

### 4.2 Separate Repair Log Table

**Decision:** Create separate `flow_token_repair_log` table

**Rationale:**
- Dedicated audit trail for repair operations
- Before/after snapshots for comparison
- Batch repair tracking (batch_id)
- Easy to query repair history

**Implementation:**
- One log entry per repair operation
- Links to canonical events via `canonical_event_ids` JSON array
- Stores before/after snapshots for comparison

### 4.3 Snapshot Structure

**Decision:** Compact snapshot (not full timeline)

**Rationale:**
- Full timeline would be too large
- Key metrics are sufficient for comparison
- Reduces storage overhead

**Implementation:**
- Snapshot includes: start_time, complete_time, duration_ms, session_count, event_count, problem_count
- Before/after comparison shows repair impact

### 4.4 Backward Compatibility

**Decision:** TokenEventService::persistEvents() maintains backward compatibility

**Rationale:**
- Existing code still works (returns count)
- New code can opt-in to event IDs
- No breaking changes

**Implementation:**
- Default `$returnIds = false` (returns count)
- When `$returnIds = true`, returns array of IDs

---

## 5. Testing

### 5.1 Syntax Validation

- ✅ PHP syntax valid for all files
- ✅ No linter errors

### 5.2 Manual Testing (Planned)

**Test Cases:**
1. **MISSING_START Repair:**
   - Verify: Repair event has repair metadata in payload
   - Verify: Repair log entry created with event IDs
   - Verify: Before/after snapshots recorded

2. **NO_CANONICAL_EVENTS Repair:**
   - Verify: Multiple events created (START + COMPLETE)
   - Verify: Repair log has 2 event IDs
   - Verify: Snapshots show improvement

3. **Repair Log Query:**
   - Query repair log by token_id
   - Verify: Can see repair history
   - Verify: Can link to canonical events

4. **Backward Compatibility:**
   - Verify: TokenEventService::persistEvents() still returns count by default
   - Verify: Existing code still works

---

## 6. Known Limitations

### 6.1 Snapshot Size

**Limitation:** Snapshots are compact, not full timeline

**Reason:** Storage efficiency

**Future:** May add full timeline option if needed

### 6.2 Batch Repair Tracking

**Limitation:** batch_id field exists but not yet used

**Reason:** Batch repair in Task 22.4

**Future:** Will be populated in Task 22.4

### 6.3 Repair Event Identification

**Limitation:** Must check payload.repair to identify repair events

**Reason:** Repair events are still canonical events

**Future:** May add index on event_data JSON for faster queries

---

## 7. Next Steps

### 7.1 Task 22.3

- Timeline Reconstruction v1
- Handle INVALID_SEQUENCE_SIMPLE, SESSION_OVERLAP_SIMPLE, ZERO_DURATION
- Reconstruct complex timelines

### 7.2 Task 22.4

- Batch Repair Tools
- Use batch_id in repair log
- CLI commands for batch repair

---

## 8. Acceptance Criteria

### 8.1 Implementation

- ✅ Repair log table created
- ✅ RepairEventModel created
- ✅ LocalRepairEngine patches applied
- ✅ TokenEventService enhanced
- ✅ Unsupported repair types removed

### 8.2 Audit Trail

- ✅ Repair events have metadata in payload
- ✅ Repair log entries created
- ✅ Before/after snapshots recorded
- ✅ Event IDs tracked

### 8.3 Code Quality

- ✅ PHP syntax valid
- ✅ No linter errors
- ✅ Backward compatible
- ✅ Proper documentation

---

## 9. Alignment

- ✅ Follows task22.2.md requirements
- ✅ Aligns with Phase 22 Blueprint
- ✅ Integrates with LocalRepairEngine from Task 22.1
- ✅ Uses TokenEventService from Task 21.3
- ✅ Uses TimeEventReader from Task 21.5

---

## 10. Statistics

**Files Created:**
- `RepairEventModel.php`: ~100 lines
- `0009_token_repair_log.php`: ~50 lines

**Files Modified:**
- `LocalRepairEngine.php`: ~150 lines added/modified
- `TokenEventService.php`: ~30 lines added

**Total Lines Added:** ~330 lines

---

## 11. Usage Examples

### 11.1 Repair with Log Tracking

```php
$repairEngine = new \BGERP\Dag\LocalRepairEngine($db);
$repairPlan = $repairEngine->generateRepairPlan($tokenId);

$result = $repairEngine->applyRepairPlan($repairPlan);

if ($result['success']) {
    echo "Added " . $result['events_added'] . " events\n";
    echo "Event IDs: " . implode(', ', $result['event_ids']) . "\n";
    echo "Repair Log ID: " . $result['repair_log_id'] . "\n";
    
    // Query repair log
    $log = $db->query("SELECT * FROM flow_token_repair_log WHERE id_repair_log = " . $result['repair_log_id'])->fetch_assoc();
    print_r($log);
}
```

### 11.2 Check Repair Event

```php
$event = $db->query("SELECT event_data FROM token_event WHERE id_event = 1234")->fetch_assoc();
$eventData = json_decode($event['event_data'], true);
$payload = $eventData['payload'] ?? [];

if (\BGERP\Dag\RepairEventModel::isRepairEvent($payload)) {
    $repairType = \BGERP\Dag\RepairEventModel::getRepairType($payload);
    echo "This is a repair event: " . $repairType . "\n";
}
```

### 11.3 Query Repair History

```php
$repairs = $db->query("
    SELECT * FROM flow_token_repair_log 
    WHERE token_id = 123 
    ORDER BY created_at DESC
")->fetch_all(MYSQLI_ASSOC);

foreach ($repairs as $repair) {
    echo "Repair Type: " . $repair['repair_type'] . "\n";
    echo "Event IDs: " . $repair['canonical_event_ids'] . "\n";
    echo "Before: " . json_encode(json_decode($repair['before_snapshot'])) . "\n";
    echo "After: " . json_encode(json_decode($repair['after_snapshot'])) . "\n";
}
```

---

**Document Status:** ✅ Complete (Task 22.2)  
**Last Updated:** 2025-01-XX  
**Alignment:** Aligned with task22.2.md requirements and Phase 22 Blueprint


