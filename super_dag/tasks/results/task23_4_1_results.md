# Task 23.4.1 Results — ETA Integration Patch & Simulation Refinement

**Status:** ✅ COMPLETE  
**Date:** 2025-01-XX  
**Category:** SuperDAG / MO Engine / Productionization Layer

**⚠️ IMPORTANT:** This task implements patches and refinements to `MOLoadSimulationService` and `MOLoadEtaService` to make them production-ready for Phase 23. It removes unnecessary dependencies, fixes capacity calculations, enhances queue modeling, and adds validation/error handling.

---

## 1. Executive Summary

Task 23.4.1 successfully implemented:
- **Removed MOCreateAssistService Dependency** - Cleaned up simulation layer
- **Fixed capacity_per_hour_ms Calculation** - Uses work_hours_per_day instead of 24
- **Enhanced Queue Model** - Sequential queue model with station availability
- **Node-Level ETA Fields** - Added wait_ms, execution_ms, delay_factor
- **Stage-Level ETA Envelope** - Added risk_factor
- **Validation & Error Handling** - Added comprehensive validation
- **Enhanced API Response** - New formatted stages structure

**Key Achievements:**
- ✅ Removed unused `MOCreateAssistService` dependency
- ✅ Fixed `capacity_per_hour_ms` calculation (work_hours_per_day instead of 24)
- ✅ Enhanced queue model with station availability tracking
- ✅ Added sequential node timeline calculation
- ✅ Added node-level ETA fields (wait_ms, execution_ms, delay_factor)
- ✅ Added stage-level risk factor calculation
- ✅ Added validation for routing graph, quantity, unserviceable stations
- ✅ Enhanced API response structure

---

## 2. Implementation Details

### 2.1 MOLoadSimulationService Patches

**File:** `source/BGERP/MO/MOLoadSimulationService.php`

**Patch 1: Remove MOCreateAssistService Dependency**

**Removed:**
- `use BGERP\MO\MOCreateAssistService;`
- `private $assistService;`
- `$this->assistService = new MOCreateAssistService($db);` from constructor

**Rationale:**
- Simulation layer should be independent from assist layer
- Prevents future coupling issues if AssistService changes
- Reduces unnecessary dependencies

**Patch 2: Fix capacity_per_hour_ms Calculation**

**Before:**
```php
$capacityPerHourMs = $capacityPerDayMs ? (int)($capacityPerDayMs / 24) : null;
```

**After:**
```php
if ($workHoursPerDay > 0) {
    $capacityPerHourMs = (int)($capacityPerDayMs / $workHoursPerDay);
}
```

**Rationale:**
- Factory works 8 hours, not 24 hours
- Using 24-hour average overestimates capacity
- ETA calculations depend on accurate capacity_per_hour_ms

**Changes:**
- Added `$workHoursPerDay` variable
- Calculate `capacity_per_hour_ms` from `work_hours_per_day`
- Store `work_hours_per_day` in station load output

### 2.2 MOLoadEtaService Enhancements

**File:** `source/BGERP/MO/MOLoadEtaService.php`

**Enhancement 1: Enhanced Queue Model**

**Added Fields:**
- `capacity_per_hour_ms` - Capacity per hour (corrected)
- `station_available_at_ms` - When station becomes available

**Queue Model Logic:**
```php
// Use capacity_per_hour_ms for queue model
if ($capacityPerHourMs && $capacityPerHourMs > 0) {
    $waitingMs = (workload / capacity_per_hour) × queue_factor × 3600000;
    $stationAvailableAtMs = now + waitingMs;
}
```

**Enhancement 2: Sequential Queue Model for Node Timeline**

**Logic:**
```php
// node_start_at = max(prev_node_complete_at, station_available_at, stage_start_at)
$nodeStartAtMs = max($prevNodeCompleteAtMs, $stationAvailableAtMs, $stageStartAtMs);

// Update station availability after node completes
$stationAvailableAt[$workCenterId] = $nodeCompleteAtMs;
```

**Features:**
- Tracks station availability per work center
- Sequential node processing within stage
- Accounts for previous node completion
- Updates station availability after each node

**Enhancement 3: Node-Level ETA Fields**

**Added Fields:**
- `waiting_ms` - Time node waits before starting
- `execution_ms` - Actual execution time (duration_per_token × qty)
- `delay_factor` - Risk factor based on p90 variance

**Calculation:**
```php
$waitingMs = max(0, $nodeStartAtMs - $stageStartAtMs);
$executionMs = $durationPerToken * $qty;
$delayFactor = ($p90Ms - $avgMs) / $avgMs;
```

**Enhancement 4: Stage-Level ETA Envelope**

**Added Fields:**
- `risk_factor` - Maximum p90 variance in stage

**Calculation:**
```php
foreach ($nodes as $node) {
    $variance = ($p90Ms - $avgMs) / $avgMs;
    $maxVariance = max($maxVariance, $variance);
}
$stageRiskFactor = $maxVariance;
```

**Enhancement 5: Validation & Error Handling**

**Validations Added:**
- MO must exist
- MO must be classic/oem production type
- MO must have routing graph assigned
- MO quantity must be > 0
- Station headcount = 0 → marked as unserviceable (warning)

**Error Messages:**
- Clear, descriptive error messages
- Graceful handling of missing data
- No silent failures

**Enhancement 6: Enhanced API Response**

**New Structure:**
```json
{
  "mo_id": 1234,
  "qty": 50,
  "eta": {
    "best": "...",
    "normal": "...",
    "worst": "..."
  },
  "eta_best": "...",  // Backward compatibility
  "eta_normal": "...",
  "eta_worst": "...",
  "stages": [
    {
      "stage_id": 1,
      "stage_start_at": "...",
      "stage_complete_at": "...",
      "stage_risk_factor": 0.3,
      "nodes": [
        {
          "node_id": 100,
          "station_id": 8,
          "node_start_at": "...",
          "node_complete_at": "...",
          "wait_ms": 1800000,
          "execution_ms": 2400000,
          "delay_factor": 0.3
        }
      ]
    }
  ],
  "stage_timeline": [...],  // Backward compatibility
  "node_timeline": [...],   // Backward compatibility
  "canonical_usage": true,
  "bottlenecks": [...]
}
```

---

## 3. Patches Applied

### 3.1 Patch 1: Remove AssistService Dependency

**File:** `source/BGERP/MO/MOLoadSimulationService.php`

**Changes:**
- Removed `use BGERP\MO\MOCreateAssistService;`
- Removed `private $assistService;`
- Removed `$this->assistService = new MOCreateAssistService($db);`

**Impact:**
- Reduced coupling
- Cleaner code
- No functional changes (service was unused)

### 3.2 Patch 2: Fix capacity_per_hour_ms

**File:** `source/BGERP/MO/MOLoadSimulationService.php`

**Changes:**
- Changed from `capacity_per_day_ms / 24` to `capacity_per_day_ms / work_hours_per_day`
- Added `$workHoursPerDay` variable
- Store `work_hours_per_day` in output

**Impact:**
- Accurate capacity calculation
- Correct ETA calculations
- Better queue model accuracy

### 3.3 Patch 3: Enhanced Queue Model

**File:** `source/BGERP/MO/MOLoadEtaService.php`

**Changes:**
- Use `capacity_per_hour_ms` for queue calculation
- Add `station_available_at_ms` tracking
- Calculate waiting time per hour instead of per day

**Impact:**
- More accurate waiting time estimates
- Better station availability tracking
- Improved ETA accuracy

### 3.4 Patch 4: Sequential Node Timeline

**File:** `source/BGERP/MO/MOLoadEtaService.php`

**Changes:**
- Sort nodes by sequence_no
- Track station availability per work center
- Calculate node_start_at = max(prev_node_complete, station_available, stage_start)
- Update station availability after each node

**Impact:**
- Realistic node sequencing
- Accurate station availability
- Better delay propagation

### 3.5 Patch 5: Node-Level ETA Fields

**File:** `source/BGERP/MO/MOLoadEtaService.php`

**Changes:**
- Added `waiting_ms` calculation
- Added `execution_ms` field
- Added `delay_factor` calculation (p90 variance)

**Impact:**
- Detailed node-level ETA information
- Risk factor per node
- Better visibility into delays

### 3.6 Patch 6: Stage-Level Risk Factor

**File:** `source/BGERP/MO/MOLoadEtaService.php`

**Changes:**
- Added `calculateStageRiskFactor()` method
- Calculate max p90 variance in stage
- Store `risk_factor` in stage timeline

**Impact:**
- Stage-level risk assessment
- Better bottleneck identification
- Improved ETA accuracy

### 3.7 Patch 7: Validation & Error Handling

**File:** `source/BGERP/MO/MOLoadEtaService.php`

**Changes:**
- Validate MO exists
- Validate production type
- Validate routing graph exists
- Validate quantity > 0
- Check for unserviceable stations (headcount = 0)

**Impact:**
- Graceful error handling
- Clear error messages
- Prevents invalid calculations

### 3.8 Patch 8: Enhanced API Response

**File:** `source/BGERP/MO/MOLoadEtaService.php`

**Changes:**
- Added `formatStagesForResponse()` method
- New `stages` array with nested nodes
- Backward compatibility (keep `stage_timeline`, `node_timeline`)
- Added `eta_best`, `eta_normal`, `eta_worst` for compatibility

**Impact:**
- Better API response structure
- Easier frontend consumption
- Backward compatible

---

## 4. Files Modified

### 4.1 Core Implementation

1. **`source/BGERP/MO/MOLoadSimulationService.php`** (MODIFIED)
   - Removed `MOCreateAssistService` dependency
   - Fixed `capacity_per_hour_ms` calculation
   - Added `work_hours_per_day` to output

2. **`source/BGERP/MO/MOLoadEtaService.php`** (MODIFIED)
   - Enhanced queue model
   - Sequential node timeline calculation
   - Added node-level ETA fields
   - Added stage-level risk factor
   - Added validation & error handling
   - Enhanced API response structure

### 4.2 Code Statistics

- **Lines Modified:** ~200 lines
- **Methods Added:** 2 (`calculateStageRiskFactor`, `formatStagesForResponse`)
- **Methods Modified:** 4 (`buildQueueModel`, `buildNodeTimeline`, `buildStageTimeline`, `computeETA`)
- **Patches Applied:** 8

---

## 5. Design Decisions

### 5.1 Remove AssistService Dependency

**Decision:** Remove unused `MOCreateAssistService` dependency from simulation layer.

**Rationale:**
- Simulation layer should be independent
- Prevents future coupling issues
- Cleaner code architecture

### 5.2 Fix capacity_per_hour_ms

**Decision:** Use `work_hours_per_day` instead of 24 for capacity calculation.

**Rationale:**
- Factory works 8 hours, not 24 hours
- Accurate capacity is critical for ETA
- Queue model depends on correct capacity

### 5.3 Sequential Queue Model

**Decision:** Implement sequential node processing with station availability tracking.

**Rationale:**
- Realistic node sequencing
- Accounts for station capacity constraints
- Better delay propagation

### 5.4 Node-Level ETA Fields

**Decision:** Add detailed node-level fields (wait_ms, execution_ms, delay_factor).

**Rationale:**
- Better visibility into node-level delays
- Risk factor per node
- Detailed ETA information

### 5.5 Stage-Level Risk Factor

**Decision:** Calculate stage risk factor based on max p90 variance.

**Rationale:**
- Stage-level risk assessment
- Better bottleneck identification
- Improved ETA accuracy

### 5.6 Enhanced API Response

**Decision:** Add new `stages` structure while maintaining backward compatibility.

**Rationale:**
- Better API structure for frontend
- Easier consumption
- No breaking changes

---

## 6. Integration Points

### 6.1 MOLoadSimulationService Integration

**Usage:**
- `MOLoadSimulationService::runSimulation()` provides station load with corrected capacity
- `capacity_per_hour_ms` now uses `work_hours_per_day`
- Station load includes `work_hours_per_day` for ETA service

**Benefits:**
- Accurate capacity data
- Correct queue model calculations
- Better ETA accuracy

### 6.2 Queue Model Integration

**Usage:**
- Queue model provides `station_available_at_ms` for node timeline
- Node timeline uses station availability for sequential processing
- Station availability updates after each node completes

**Benefits:**
- Realistic node sequencing
- Accurate station availability
- Better delay propagation

---

## 7. Known Limitations

### 7.1 Simplified Node Sequencing

**Issue:** Nodes in stage are processed sequentially based on sequence_no, not actual graph dependencies.

**Impact:** May not reflect actual parallel execution if nodes can run in parallel.

**Future Enhancement:** Use routing_edge to determine actual dependencies.

### 7.2 Station Availability Simplification

**Issue:** Station availability is calculated per MO, not across all MOs.

**Impact:** May underestimate waiting time if multiple MOs use same station.

**Future Enhancement:** Consider all active MOs when calculating station availability.

### 7.3 Stage Grouping Simplification

**Issue:** Stage grouping uses `sequence_no / 10` which may not match actual stages.

**Impact:** May group unrelated nodes together or split related nodes.

**Future Enhancement:** Use actual stage field when available.

---

## 8. Testing

### 8.1 Manual Testing

**API Endpoint:**
```
GET /mo_eta_api.php?action=eta&id_mo=123
```

**Test Cases:**
- MO with routing graph → should return ETA with stages
- MO without routing graph → should return error
- MO with qty = 0 → should return error
- Station with headcount = 0 → should be marked (warning)
- Sequential node processing → should calculate correct node_start_at
- Station availability → should update after each node
- Risk factor → should calculate based on p90 variance

### 8.2 Unit Tests (Future)

**TODO:** Create PHPUnit tests:
- Test capacity_per_hour_ms calculation
- Test sequential queue model
- Test node timeline calculation
- Test stage risk factor calculation
- Test validation logic

---

## 9. Acceptance Criteria

### 9.1 Completed ✅

- ✅ Removed `MOCreateAssistService` dependency
- ✅ Fixed `capacity_per_hour_ms` calculation
- ✅ Enhanced queue model with station availability
- ✅ Added sequential node timeline calculation
- ✅ Added node-level ETA fields (wait_ms, execution_ms, delay_factor)
- ✅ Added stage-level risk factor
- ✅ Added validation & error handling
- ✅ Enhanced API response structure
- ✅ Maintained backward compatibility

### 9.2 Pending

- ⏳ Unit tests
- ⏳ Graph dependency-based sequencing
- ⏳ Multi-MO station availability
- ⏳ Stage field support

---

## 10. Summary

Task 23.4.1 successfully implements patches and refinements to make `MOLoadSimulationService` and `MOLoadEtaService` production-ready. The patches remove unnecessary dependencies, fix capacity calculations, enhance queue modeling, and add comprehensive validation and error handling.

**Key Achievements:**
- ✅ Removed unused dependency
- ✅ Fixed capacity calculation
- ✅ Enhanced queue model
- ✅ Sequential node timeline
- ✅ Node-level ETA fields
- ✅ Stage-level risk factor
- ✅ Validation & error handling
- ✅ Enhanced API response
- ✅ Backward compatibility maintained

**Next Steps:**
- Unit tests
- Graph dependency-based sequencing
- Multi-MO station availability
- Stage field support

---

**Task Status:** ✅ COMPLETE (Backend implementation done, testing pending)

