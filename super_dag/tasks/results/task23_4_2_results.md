# Task 23.4.2 Results — ETA Audit Tool (Audit + Debugging + Cross-Check Layer)

**Status:** ✅ COMPLETE  
**Date:** 2025-01-XX  
**Category:** SuperDAG / MO Engine / Productionization Layer

**⚠️ IMPORTANT:** This task implements an ETA Audit Tool for cross-checking ETA calculations, detecting inconsistencies, and identifying outliers. It's a dev-only tool for debugging and validation.

---

## 1. Executive Summary

Task 23.4.2 successfully implemented:
- **MOEtaAuditService Class** - Core service for ETA auditing
- **ETA Audit Dev Tool** - Standalone HTML/JSON tool for auditing
- **Cross-Check Layer** - Validates Simulation vs ETA vs Canonical
- **Outlier Detection** - Identifies nodes with unusual delay patterns
- **Consistency Validation** - Checks node, stage, station, and queue consistency
- **Alert Level System** - Computes overall alert level (OK/WARNING/ERROR)

**Key Achievements:**
- ✅ Created `MOEtaAuditService.php` (~650 lines)
- ✅ Created `tools/eta_audit.php` standalone dev tool
- ✅ Implemented Simulation vs ETA comparison
- ✅ Implemented ETA vs Canonical comparison
- ✅ Implemented outlier node detection
- ✅ Implemented stage consistency validation
- ✅ Implemented ETA envelope validation
- ✅ Implemented alert level computation
- ✅ Created HTML UI with Bootstrap
- ✅ Added JSON export functionality

---

## 2. Implementation Details

### 2.1 MOEtaAuditService Class

**File:** `source/BGERP/MO/MOEtaAuditService.php`

**Purpose:** Core service for ETA auditing and cross-checking

**Key Methods:**

1. **`runAudit(int $moId): array`**
   - Main orchestrator
   - Runs all audit checks
   - Returns complete audit result

2. **`compareSimulationAndEta(array $simulation, array $eta): array`**
   - Checks consistency between simulation and ETA layers
   - Validates node count, duration, workload, station load, queue
   - Returns warnings and errors

3. **`compareEtaAndCanonical(array $eta, array $mo): array`**
   - Compares ETA with canonical timeline
   - Checks execution_ms vs canonical avg/p50/p90
   - Validates sample size and data sufficiency

4. **`detectOutlierNodes(array $eta, array $mo): array`**
   - Finds nodes with unusual delay patterns
   - Flags: HIGH_DELAY, HIGH_QUEUE, VARIANCE_SPIKE, INSUFFICIENT_DATA, HIGH_WORKLOAD

5. **`summarizeStageConsistency(array $eta): array`**
   - Validates stage timeline consistency
   - Checks stage_start_at < previous_complete_at
   - Validates stage overflow and risk factor

6. **`validateEtaEnvelope(array $eta): array`**
   - Validates ETA summary: best <= normal <= worst
   - Returns validation errors if envelope is invalid

7. **`computeAlertLevel(...): string`**
   - Computes overall alert level: OK | WARNING | ERROR
   - Based on error and warning counts

8. **`exportJson(array $auditResult): string`**
   - Exports audit results as JSON
   - Pretty-printed with Unicode support

**Constants:**
- `QUEUE_TOLERANCE = 0.15` (15% tolerance for queue mismatch)
- `HIGH_DELAY_THRESHOLD = 1.5` (delay_factor > 1.5)
- `HIGH_QUEUE_THRESHOLD = 0.10` (waiting_ms > 10% of execution_ms)
- `VARIANCE_SPIKE_THRESHOLD = 1.8` (p90/p50 > 1.8)
- `MIN_SAMPLE_SIZE = 3` (minimum canonical sample size)

### 2.2 ETA Audit Dev Tool

**File:** `tools/eta_audit.php`

**Purpose:** Standalone dev tool for auditing ETA calculations

**Features:**
- HTML UI with Bootstrap 5
- Form to enter MO ID
- Summary cards with alert level
- Consistency checks display
- Outlier nodes table
- Node consistency table
- Canonical stats table
- Stage timeline table
- JSON export functionality

**Usage:**
- Browser: `/tools/eta_audit.php?mo_id=123`
- JSON: `/tools/eta_audit.php?mo_id=123&json=1`

**UI Sections:**
1. **Header Summary** - MO info, alert level, ETA summary
2. **Consistency Checks** - Errors and warnings
3. **Outlier Nodes** - Nodes with unusual patterns
4. **Node Consistency** - Simulation vs ETA comparison
5. **Canonical Stats** - Canonical duration statistics
6. **Stage Timeline** - Stage-level timeline data
7. **Export JSON** - Button to export full audit result

---

## 3. Cross-Check Logic

### 3.1 Simulation vs ETA

**Checks:**
- Node count mismatch
- Duration per token mismatch (>5% tolerance)
- Total workload mismatch (>5% tolerance)
- Station workload mismatch (>5% tolerance)
- Queue waiting time mismatch (>15% tolerance)

**Output:**
- `node_consistency` - Per-node consistency results
- `station_consistency` - Per-station consistency results
- `queue_consistency` - Per-queue consistency results
- `warnings` - Array of warnings
- `errors` - Array of errors

### 3.2 ETA vs Canonical

**Checks:**
- Execution_ms < canonical avg × 0.7 (unusual)
- P90 > execution_ms × 2 (high variance)
- Sample size < 3 (underfitting)
- No canonical data available (fallback usage)

**Output:**
- `checks` - Per-node canonical comparison
- `warnings` - Array of warnings
- `errors` - Array of errors

### 3.3 Outlier Detection

**Flags:**
- `HIGH_DELAY` - delay_factor > 1.5
- `HIGH_QUEUE` - waiting_ms > 10% of execution_ms
- `VARIANCE_SPIKE` - p90/p50 > 1.8
- `INSUFFICIENT_DATA` - sample_size < 3 or no canonical data
- `HIGH_WORKLOAD` - total_workload_ms > expected × 1.5

**Output:**
- Array of outlier nodes with flags and metrics

### 3.4 Stage Consistency

**Checks:**
- Stage start_at < previous complete_at (ERROR)
- Stage duration > 24 hours (WARNING)
- Risk factor > 1.0 (WARNING)

**Output:**
- `warnings` - Array of warnings
- `errors` - Array of errors
- `stage_count` - Number of stages

### 3.5 ETA Envelope Validation

**Checks:**
- best <= normal (ERROR if violated)
- normal <= worst (ERROR if violated)

**Output:**
- `valid` - Boolean validation result
- `errors` - Array of errors
- `eta_best`, `eta_normal`, `eta_worst` - ETA values

---

## 4. Alert Level System

**Logic:**
- `ERROR` - If any errors found
- `WARNING` - If warning count > 5
- `OK` - Otherwise

**Error Sources:**
- Simulation vs ETA errors
- ETA vs Canonical errors
- Stage consistency errors
- ETA envelope errors

**Warning Sources:**
- Simulation vs ETA warnings
- ETA vs Canonical warnings
- Stage consistency warnings
- Outlier nodes

---

## 5. Files Created

### 5.1 Core Implementation

1. **`source/BGERP/MO/MOEtaAuditService.php`** (NEW)
   - ~650 lines
   - 8 main methods
   - Cross-check logic
   - Outlier detection
   - Alert level computation

2. **`tools/eta_audit.php`** (NEW)
   - Standalone dev tool
   - HTML UI with Bootstrap
   - JSON export
   - Error handling

### 5.2 Code Statistics

- **Lines Added:** ~900 lines
- **Methods:** 8 main methods + 3 helper methods
- **Constants:** 5 thresholds

---

## 6. Design Decisions

### 6.1 Standalone Dev Tool

**Decision:** Create standalone tool in `tools/` folder instead of integrated page.

**Rationale:**
- Dev tools should be separate from production UI
- Easier to access and debug
- No need for page definition or permission system
- Can be accessed directly via URL

### 6.2 Cross-Check Three Sources

**Decision:** Compare Simulation, ETA, and Canonical separately.

**Rationale:**
- Each layer has different data structures
- Easier to identify which layer has issues
- More granular error reporting
- Better debugging capability

### 6.3 Outlier Detection Flags

**Decision:** Use flag-based system for outlier classification.

**Rationale:**
- Multiple flags per node possible
- Clear categorization of issues
- Easy to filter and analyze
- Extensible for future flags

### 6.4 Alert Level System

**Decision:** Simple three-level system (OK/WARNING/ERROR).

**Rationale:**
- Clear and actionable
- Easy to understand
- Color-coded in UI
- Can be extended later

### 6.5 JSON Export

**Decision:** Support JSON export for programmatic access.

**Rationale:**
- Useful for automated testing
- Can be consumed by other tools
- Machine learning training data
- API integration

---

## 7. Integration Points

### 7.1 MOLoadSimulationService Integration

**Usage:**
- `MOLoadSimulationService::runSimulation()` provides simulation data
- Used for node projection, station load, bottlenecks

**Benefits:**
- Access to simulation layer data
- Station load information
- Node projection details

### 7.2 MOLoadEtaService Integration

**Usage:**
- `MOLoadEtaService::computeETA()` provides ETA data
- Used for node timeline, stage timeline, ETA summary

**Benefits:**
- Access to ETA layer data
- Node and stage timeline
- ETA envelope (best/normal/worst)

### 7.3 TimeEventReader Integration

**Usage:**
- `TimeEventReader::getTimelineForToken()` provides canonical duration
- Used for canonical stats calculation

**Benefits:**
- Access to canonical timeline data
- Accurate duration statistics
- P50/P90 percentiles

---

## 8. Known Limitations

### 8.1 Queue Model Reconstruction

**Issue:** Queue model is not directly exposed from ETA service, so we reconstruct it from node timeline.

**Impact:** May not perfectly match internal queue model.

**Future Enhancement:** Expose queue model from ETA service or add getter method.

### 8.2 Simplified Outlier Detection

**Issue:** Outlier detection uses fixed thresholds, not statistical methods.

**Impact:** May miss subtle outliers or flag false positives.

**Future Enhancement:** Use statistical methods (z-score, IQR) for outlier detection.

### 8.3 Single MO Only

**Issue:** Tool only audits one MO at a time.

**Impact:** Cannot compare multiple MOs or batch audit.

**Future Enhancement:** Add batch audit functionality.

---

## 9. Testing

### 9.1 Manual Testing

**Test Cases:**
- MO with valid ETA → should show OK alert level
- MO with inconsistencies → should show WARNING/ERROR
- MO without canonical data → should show warnings
- MO with outlier nodes → should list outliers
- Invalid MO ID → should show error
- JSON export → should return valid JSON

**Test URL:**
```
/tools/eta_audit.php?mo_id=123
/tools/eta_audit.php?mo_id=123&json=1
```

### 9.2 Unit Tests (Future)

**TODO:** Create PHPUnit tests:
- Test compareSimulationAndEta()
- Test compareEtaAndCanonical()
- Test detectOutlierNodes()
- Test summarizeStageConsistency()
- Test validateEtaEnvelope()
- Test computeAlertLevel()

---

## 10. Acceptance Criteria

### 10.1 Completed ✅

- ✅ Created MOEtaAuditService class
- ✅ Implemented Simulation vs ETA comparison
- ✅ Implemented ETA vs Canonical comparison
- ✅ Implemented outlier node detection
- ✅ Implemented stage consistency validation
- ✅ Implemented ETA envelope validation
- ✅ Implemented alert level computation
- ✅ Created standalone dev tool
- ✅ Added HTML UI with Bootstrap
- ✅ Added JSON export functionality
- ✅ Error handling and validation

### 10.2 Pending

- ⏳ Unit tests
- ⏳ Batch audit functionality
- ⏳ Statistical outlier detection
- ⏳ Queue model getter from ETA service

---

## 11. Summary

Task 23.4.2 successfully implements an ETA Audit Tool for cross-checking ETA calculations, detecting inconsistencies, and identifying outliers. The tool provides a comprehensive dev interface for debugging and validation.

**Key Achievements:**
- ✅ Cross-check Simulation vs ETA vs Canonical
- ✅ Detect inconsistencies and outliers
- ✅ Validate stage and ETA envelope
- ✅ Compute alert levels
- ✅ Standalone dev tool with HTML/JSON
- ✅ Comprehensive error and warning reporting

**Next Steps:**
- Unit tests
- Batch audit functionality
- Statistical outlier detection
- Queue model getter from ETA service

---

**Task Status:** ✅ COMPLETE (Backend implementation done, testing pending)


