# Task 23.6 Results — MO Update Integration & ETA Cache Consistency

**Status:** ✅ Completed  
**Date:** November 28, 2025  
**Category:** SuperDAG / MO Planning / ETA Intelligence

**⚠️ IMPORTANT:** This task implements MO update integration with ETA cache and health service, ensuring cache consistency when MO fields change.

---

## 1. Executive Summary

Task 23.6 successfully implemented:

- **MO Update Handler** - New `handleUpdate()` function in `mo.php`
- **ETA Cache Invalidation** - Automatic cache invalidation on ETA-sensitive field changes
- **ETA Cache Recompute** - Best-effort recompute after invalidation
- **Health Service Integration** - `onMoUpdated()` method for logging MO update events
- **Signature Enhancement** - Added `product_id` to ETA cache signature
- **Non-Blocking Design** - All ETA/Health operations wrapped in try/catch

**Key Achievements:**
- ✅ Created `handleUpdate()` function in `mo.php` (~200 lines)
- ✅ Enhanced `MOEtaCacheService::buildSignature()` to include `product_id`
- ✅ Added `MOEtaCacheService::invalidateForMo()` alias method
- ✅ Added `MOEtaHealthService::onMoUpdated()` method
- ✅ Implemented ETA-sensitive field diff detection
- ✅ Non-blocking error handling (ETA failures don't block MO updates)

---

## 2. Implementation Details

### 2.1 MO Update Handler (`source/mo.php`)

**New Function:** `handleUpdate($db, $member)`

**Features:**
- Validates MO update request
- Loads old MO state before update
- Detects ETA-sensitive field changes:
  - `id_product` (product change)
  - `qty` (quantity change)
  - `id_routing_graph` (routing change)
  - `due_date` (due date change)
  - `scheduled_start_date` (start date change)
  - `scheduled_end_date` (end date change)
- Updates MO fields in transaction
- Invalidates ETA cache if ETA-sensitive fields changed
- Triggers ETA recompute (best-effort, non-blocking)
- Notifies `MOEtaHealthService` of update
- Returns updated MO data with change summary

**ETA-Sensitive Field Detection:**
```php
// Detects changes in:
- id_product
- qty
- id_routing_graph
- due_date
- scheduled_start_date
- scheduled_end_date

// Non-ETA-sensitive fields (don't trigger cache invalidation):
- uom_code
- notes
- description
```

**Error Handling:**
- All ETA/Health operations wrapped in try/catch
- MO update succeeds even if ETA operations fail
- Errors logged but not thrown

### 2.2 ETA Cache Service Enhancement (`source/BGERP/MO/MOEtaCacheService.php`)

**Changes:**

1. **Enhanced `buildSignature()` Method:**
   - Added `product_id` to signature data
   - Signature now includes:
     - `mo_id`
     - `product_id` (NEW)
     - `qty`
     - `routing_id`
     - `routing_version`
     - `routing_hash`
     - `production_type`
     - `status`
     - `engine_version`

2. **Added `invalidateForMo()` Method:**
   - Alias for `invalidate()` method
   - Provides consistent API naming
   - Task 23.6 requirement

**Signature Logic:**
```php
$signatureData = [
    'mo_id' => (int)$mo['id_mo'],
    'product_id' => isset($mo['id_product']) ? (int)$mo['id_product'] : null, // NEW
    'qty' => (float)$mo['qty'],
    'routing_id' => isset($mo['id_routing_graph']) ? (int)$mo['id_routing_graph'] : null,
    'routing_version' => (int)($routingMeta['version'] ?? 0),
    'routing_hash' => (string)($routingMeta['graph_hash'] ?? ''),
    'production_type' => (string)($mo['production_type'] ?? ''),
    'status' => (string)($mo['status'] ?? ''),
    'engine_version' => $this->getEngineVersion(),
];
```

### 2.3 ETA Health Service Enhancement (`source/BGERP/MO/MOEtaHealthService.php`)

**New Method:** `onMoUpdated(int $moId, array $diff)`

**Purpose:**
- Log MO update events to health log
- Track ETA-sensitive field changes
- Enable future monitoring and analysis

**Implementation:**
```php
public function onMoUpdated(int $moId, array $diff): void
{
    $this->logAlert([
        'mo_id' => $moId,
        'severity' => self::SEVERITY_INFO,
        'problem_code' => 'MO_UPDATED',
        'details_json' => json_encode([
            'status' => 'updated',
            'changed_fields' => $diff,
            'message' => 'MO updated with ETA-sensitive field changes. ETA cache invalidated.',
            'timestamp' => date('Y-m-d H:i:s'),
        ]),
    ]);
}
```

**Diff Format:**
```php
$diff = [
    'qty' => [10.0, 20.0],  // [old_value, new_value]
    'id_routing_graph' => [1, 2],
    'due_date' => ['2025-12-01', '2025-12-15'],
];
```

---

## 3. Integration Flow

### 3.1 MO Update Flow

```
1. User calls mo.php?action=update
   ↓
2. handleUpdate() loads old MO state
   ↓
3. Validates update request
   ↓
4. Detects ETA-sensitive field changes
   ↓
5. Updates MO in transaction
   ↓
6. If ETA-sensitive fields changed:
   a. Invalidate ETA cache (MOEtaCacheService::invalidateForMo)
   b. Recompute ETA (MOEtaCacheService::getOrCompute) - best-effort
   c. Log update event (MOEtaHealthService::onMoUpdated)
   ↓
7. Return success response with change summary
```

### 3.2 Error Handling Flow

```
MO Update Request
   ↓
Transaction Begin
   ↓
Update MO (SUCCESS)
   ↓
Transaction Commit
   ↓
ETA Cache Operations (try/catch):
   ├─ Invalidate Cache → SUCCESS
   ├─ Recompute ETA → SUCCESS or FAIL (logged, not thrown)
   └─ Health Log → SUCCESS or FAIL (logged, not thrown)
   ↓
Return Success Response
```

**Key Point:** MO update always succeeds even if ETA operations fail.

---

## 4. Files Modified

### 4.1 `source/mo.php`
- **Added:** `case 'update':` in action switch
- **Added:** `handleUpdate($db, $member)` function (~200 lines)
- **Features:**
  - ETA-sensitive field detection
  - Diff computation
  - ETA cache invalidation
  - ETA recompute (best-effort)
  - Health service notification

### 4.2 `source/BGERP/MO/MOEtaCacheService.php`
- **Modified:** `buildSignature()` - Added `product_id` to signature
- **Added:** `invalidateForMo()` - Alias method for consistency
- **Lines Changed:** ~15 lines

### 4.3 `source/BGERP/MO/MOEtaHealthService.php`
- **Added:** `onMoUpdated(int $moId, array $diff)` method
- **Lines Added:** ~30 lines

---

## 5. Design Decisions

### 5.1 Non-Blocking ETA Operations

**Decision:** All ETA/Health operations are non-blocking.

**Rationale:**
- MO update is core business operation
- ETA cache is optimization layer
- ETA failures should not prevent MO updates
- Errors logged for monitoring

**Implementation:**
```php
// All ETA operations wrapped in try/catch
try {
    $etaCacheService->invalidateForMo($id);
    $etaResult = $etaCacheService->getOrCompute($id);
    $etaHealthService->onMoUpdated($id, $diff);
} catch (\Throwable $e) {
    // Log but don't throw
    error_log(sprintf("[MO Update] ETA operation failed: %s", $e->getMessage()));
}
```

### 5.2 ETA-Sensitive Field Detection

**Decision:** Only specific fields trigger cache invalidation.

**Rationale:**
- Not all MO fields affect ETA calculation
- Unnecessary cache invalidation wastes resources
- Clear separation between ETA-sensitive and non-sensitive fields

**ETA-Sensitive Fields:**
- `id_product` - Product change affects routing/duration
- `qty` - Quantity change affects total duration
- `id_routing_graph` - Routing change affects entire ETA
- `due_date` - Date change affects scheduling
- `scheduled_start_date` - Start date affects timeline
- `scheduled_end_date` - End date affects timeline

**Non-ETA-Sensitive Fields:**
- `uom_code` - Unit of measure doesn't affect duration
- `notes` - Notes don't affect ETA
- `description` - Description doesn't affect ETA

### 5.3 Signature Enhancement

**Decision:** Added `product_id` to cache signature.

**Rationale:**
- Product change can affect routing selection
- Product change can affect duration estimates
- Signature must reflect all ETA-affecting fields
- Backward compatible (null handling for old cache rows)

---

## 6. Testing Scenarios

### 6.1 Qty Change Only

**Test:**
1. Create MO with qty = 10
2. Confirm ETA cache created
3. Update MO: qty = 20
4. Verify cache invalidated and recomputed

**Expected:**
- ✅ Cache entry invalidated
- ✅ New cache entry created with updated ETA
- ✅ `onMoUpdated()` called with `['qty' => [10, 20]]`
- ✅ MO update succeeds

### 6.2 Routing Change

**Test:**
1. Create MO with routing A
2. Update MO to routing B
3. Verify signature change and cache recompute

**Expected:**
- ✅ Cache entry invalidated
- ✅ New cache entry created with routing B ETA
- ✅ Signature includes new routing_id
- ✅ `onMoUpdated()` called with routing diff

### 6.3 No ETA-Sensitive Changes

**Test:**
1. Create MO
2. Update MO: notes = "Updated notes"
3. Verify cache NOT invalidated

**Expected:**
- ✅ Cache entry remains valid
- ✅ No ETA recompute triggered
- ✅ `onMoUpdated()` NOT called
- ✅ MO update succeeds

### 6.4 Recompute Failure

**Test:**
1. Simulate ETA computation error
2. Update MO with ETA-sensitive change
3. Verify MO update still succeeds

**Expected:**
- ✅ Cache invalidated
- ✅ ETA recompute fails (logged)
- ✅ MO update succeeds
- ✅ Error logged but not thrown

---

## 7. Code Statistics

- **Files Modified:** 3
- **Lines Added:** ~250
- **Lines Modified:** ~15
- **New Functions:** 2
  - `handleUpdate()` in `mo.php`
  - `onMoUpdated()` in `MOEtaHealthService.php`
- **Enhanced Functions:** 2
  - `buildSignature()` in `MOEtaCacheService.php`
  - Added `invalidateForMo()` alias

---

## 8. Known Limitations

1. **No UI Integration:** Task 23.6 focuses on backend only. Frontend integration will be in future tasks.

2. **No Batch Update Support:** Current implementation handles single MO updates only. Batch updates would require additional logic.

3. **No Update History:** MO update history is not tracked separately (only in health log).

4. **No Rollback on ETA Failure:** If ETA recompute fails, MO update still succeeds. This is intentional (non-blocking design).

---

## 9. Future Enhancements

1. **Update History Table:** Track MO update history separately from health log.

2. **Batch Update Support:** Support updating multiple MOs at once.

3. **UI Integration:** Add update UI with ETA preview.

4. **Update Validation:** Validate update requests against business rules (e.g., cannot change qty if MO is in_progress).

5. **Update Notifications:** Notify stakeholders when ETA-sensitive fields change.

---

## 10. Conclusion

Task 23.6 successfully closes the gap between MO updates and ETA cache consistency:

- ✅ MO updates automatically invalidate ETA cache when needed
- ✅ ETA cache recomputes after invalidation (best-effort)
- ✅ Health service tracks MO update events
- ✅ Non-blocking design ensures MO updates never fail due to ETA issues
- ✅ Signature enhancement ensures cache accuracy
- ✅ Clear separation between ETA-sensitive and non-sensitive fields

**Result:** MO update lifecycle is now fully integrated with ETA/Simulation/Health stack, maintaining consistency without blocking core operations.

