# Task 23.4 Results — MO ETA Engine (Advanced ETA Model v1)

**Status:** ✅ COMPLETE  
**Date:** 2025-01-XX  
**Category:** SuperDAG / MO Engine / Productionization Layer

**⚠️ IMPORTANT:** This task implements an advanced ETA (Estimated Time of Arrival) engine for MOs that calculates stage-level and node-level ETAs with delay propagation and queue modeling. It integrates with Load Simulation (Task 23.3) and uses canonical timeline (Phase 22) for accurate duration estimation.

---

## 1. Executive Summary

Task 23.4 successfully implemented:
- **MOLoadEtaService Class** - Core service for ETA calculation
- **MO ETA API** - New endpoint for ETA requests
- **CLI Tool** - Command-line tool for ETA calculation
- **Stage Timeline Model** - Stage-level ETA propagation
- **Node Timeline Model** - Node-level ETA calculation
- **Queue Model** - Work center waiting time estimation
- **Best/Normal/Worst ETA** - Three-case ETA summary
- **Patches from 23.3** - p90_ms propagation, capacity fix, constructor cleanup

**Key Achievements:**
- ✅ Created `MOLoadEtaService.php` (~450 lines)
- ✅ Created `mo_eta_api.php` with eta endpoint
- ✅ Created `tools/mo_eta.php` CLI tool
- ✅ Implemented stage timeline propagation
- ✅ Implemented node timeline calculation
- ✅ Implemented queue-based delay modeling
- ✅ Implemented best/normal/worst ETA calculation
- ✅ Patched `MOLoadSimulationService` (p90_ms, capacity fix, constructor cleanup)

---

## 2. Implementation Details

### 2.1 MOLoadEtaService Class

**File:** `source/BGERP/MO/MOLoadEtaService.php`

**Purpose:** Core service for MO ETA calculation

**Key Methods:**

1. **`computeETA(int $moId): array`**
   - Main entry point
   - Orchestrates all ETA calculation steps
   - Returns complete ETA result with stage/node timelines

2. **`buildNodeDurationTable(array $mo, array $nodeProjection): array`**
   - Combines canonical duration + fallback + sample size
   - Duration selector priority:
     1. canonical `avg_ms`
     2. canonical `p50_ms` (optional flag - use avg for now)
     3. fallback: `estimated_minutes × 60,000`
     4. default: 30 minutes
   - Stores p50_ms, p90_ms, sample_size, uses_canonical

3. **`buildQueueModel(array $nodeDurationTable, array $stationLoad): array`**
   - Maps work_center → waiting_ms
   - Formula: `waiting_ms = (station_workload_ms / capacity_per_day_ms) × queue_factor × 86400000`
   - Uses corrected `capacity_per_day_ms` formula

4. **`buildStageTimeline(array $mo, array $nodeDurationTable, array $queueModel): array`**
   - Groups nodes by stage (using sequence_no / 10)
   - Propagates each stage:
     - `stage_start_at = max(previous_stage_complete_at, now + waiting_time)`
     - `stage_execution_ms = sum(node_workload_ms for nodes in stage)`
     - `stage_complete_at = stage_start_at + stage_execution_ms`

5. **`buildNodeTimeline(array $mo, array $nodeDurationTable, array $stageTimeline): array`**
   - Computes each node's timeline
   - `node_start_at = stage_start_at + cumulative_node_offset`
   - `node_complete_at = node_start_at + duration_per_token × qty`

6. **`buildSummary(array $stageTimeline, array $nodeTimeline, array $nodeDurationTable, int $qty): array`**
   - Computes MO ETA (best/normal/worst):
     - `eta_best = last_stage.start_at + sum(p50_ms × qty)`
     - `eta_normal = last_stage.complete_at`
     - `eta_worst = eta_normal + (p90_ms × qty × overall_delay_factor)`

**Private Helper Methods:**
- `getCanonicalDurationStatsForNode()` - Gets canonical stats per node
- `checkCanonicalUsage()` - Checks if canonical timeline was used
- `fetchMO()` - Fetches MO data
- `fetchNodeSequenceNo()` - Fetches node sequence_no

### 2.2 MO ETA API

**File:** `source/mo_eta_api.php`

**Endpoint:**

**`GET /mo_eta_api.php?action=eta&id_mo=123`**
- Calculates ETA for MO
- Returns complete ETA result with stage/node timelines
- Permission: `mo.view`
- Cache: 5 minutes

**API Features:**
- Standard enterprise API structure (rate limiting, correlation ID, AI trace)
- GET-only enforcement
- Global error handling
- Accurate X-AI-Trace timing

### 2.3 CLI Tool

**File:** `tools/mo_eta.php`

**Usage:**
```bash
php tools/mo_eta.php --mo=123
```

**Features:**
- Command-line interface for ETA calculation
- Pretty-printed JSON output
- Error handling with clear messages

### 2.4 Patches to MOLoadSimulationService

**Task 23.4 Patches:**

1. **p90_ms Propagation Fix**
   - Added `p50_ms` and `p90_ms` to `nodeDurations` array
   - Used in bottleneck detection and ETA calculation

2. **Capacity Fix**
   - Renamed `capacity_per_hour_ms` → `capacity_per_day_ms`
   - Corrected formula: `capacity_per_day_ms = headcount × work_hours_per_day × 3600000`
   - Added backward compatibility: `capacity_per_hour_ms = capacity_per_day_ms / 24`

3. **Constructor Cleanup**
   - Removed unused `$assistService` property
   - Simplified constructor

4. **Sequence No Addition**
   - Added `sequence_no` to `simulateRoutingExpansion()` output
   - Used for stage grouping in ETA calculation

---

## 3. ETA Computation Model

### 3.1 Duration Selector (per node)

**Priority:**
1. canonical `avg_ms` (from TimeEventReader)
2. canonical `p50_ms` (optional flag - use avg for now)
3. fallback: `estimated_minutes × 60,000`
4. default: 30 minutes

**Stored:**
- `duration_per_token_ms`
- `p50_ms`
- `p90_ms`
- `sample_size`
- `uses_canonical`

### 3.2 Queue Model (Work Center)

**Formula:**
```
waiting_ms = (station_workload_ms / capacity_per_day_ms) × queue_factor × 86400000
```

**Where:**
- `station_workload_ms` = workload of nodes using same work center
- `capacity_per_day_ms` = headcount × work_hours_per_day × 3600000
- `queue_factor` = 0.8 (config)

**Output:**
```json
{
  "work_center_id": 5,
  "waiting_ms": 3600000,
  "capacity_per_day_ms": 28800000,
  "current_load_ms": 1400000
}
```

### 3.3 Stage ETA Propagation

**Formula:**
```
for stage in stages:
    stage_start_at = max(previous_stage_complete_at, now + waiting_time)
    stage_execution_ms = sum(node_workload_ms for nodes in stage)
    stage_complete_at = stage_start_at + stage_execution_ms
```

**Output:**
```json
{
  "stage": 0,
  "start_at": "2025-01-22 08:00:00",
  "complete_at": "2025-01-22 10:30:00",
  "execution_ms": 9000000,
  "waiting_ms": 3600000
}
```

### 3.4 Node ETA Model

**Formula:**
```
node_start_at = stage_start_at + cumulative_node_offset
node_complete_at = node_start_at + duration_per_token × qty
```

**Output:**
```json
{
  "node_id": 12,
  "stage": 0,
  "start_at": "2025-01-22 08:00:00",
  "complete_at": "2025-01-22 08:28:00",
  "duration_per_token_ms": 28000,
  "total_workload_ms": 1400000,
  "waiting_ms": 0
}
```

### 3.5 MO ETA Summary

**Formula:**
```
eta_best     = stage[last_stage].start_at + sum(p50_ms × qty)
eta_normal   = stage[last_stage].complete_at
eta_worst    = eta_normal + (p90_ms × qty × overall_delay_factor)
```

**Output:**
```json
{
  "best": "2025-01-22T14:30:00+07:00",
  "normal": "2025-01-22T18:10:00+07:00",
  "worst": "2025-01-23T09:25:00+07:00"
}
```

---

## 4. Files Created/Modified

### 4.1 Core Implementation

1. **`source/BGERP/MO/MOLoadEtaService.php`** (NEW)
   - Main service class (~450 lines)
   - Implements all ETA calculation logic
   - Uses canonical timeline (Phase 22)
   - Integrates with Load Simulation (Task 23.3)

2. **`source/mo_eta_api.php`** (NEW)
   - API endpoint for ETA calculation
   - GET-only, standard enterprise structure

3. **`tools/mo_eta.php`** (NEW)
   - CLI tool for ETA calculation
   - Pretty-printed JSON output

4. **`source/BGERP/MO/MOLoadSimulationService.php`** (MODIFIED)
   - Added `p50_ms` and `p90_ms` to nodeDurations
   - Fixed capacity calculation (capacity_per_day_ms)
   - Removed unused `$assistService`
   - Added `sequence_no` to routing expansion

### 4.2 Code Statistics

- **Lines Added:** ~550 lines
- **Classes Added:** 1 (`MOLoadEtaService`)
- **Endpoints Added:** 1 (`eta`)
- **CLI Tools Added:** 1
- **Methods Added:** 7 public/private methods
- **Patches Applied:** 4 (p90_ms, capacity, constructor, sequence_no)

---

## 5. Design Decisions

### 5.1 Canonical-First Duration Selection

**Decision:** Try canonical timeline first, fallback to estimated_minutes or default.

**Rationale:**
- Canonical timeline is most accurate (Phase 22 self-healing)
- Per-node calculation provides granular duration stats
- Fallback ensures ETA works even without historic data

### 5.2 Stage Grouping by Sequence No

**Decision:** Group nodes by `sequence_no / 10` to determine stages.

**Rationale:**
- Simple, deterministic grouping
- Uses existing sequence_no field
- Can be adjusted if stage field is added later

### 5.3 Queue Model Formula

**Decision:** Use simplified queue model: `(workload / capacity) × queue_factor × ms_per_day`.

**Rationale:**
- Bellavier ERP doesn't have real queue system during simulation
- Simplified model provides reasonable waiting time estimates
- Queue factor (0.8) can be adjusted based on real data

### 5.4 Stage Propagation Logic

**Decision:** Stage start = max(previous_stage_complete_at, now + waiting_time).

**Rationale:**
- Accounts for sequential dependencies
- Includes queue waiting time
- Prevents negative time gaps

### 5.5 Best/Normal/Worst ETA Calculation

**Decision:** Use p50 for best, normal for normal, p90 for worst with delay factor.

**Rationale:**
- Best case uses optimistic estimate (p50)
- Normal case uses average estimate
- Worst case accounts for variance (p90) and delay propagation

### 5.6 Integration with Load Simulation

**Decision:** Reuse `MOLoadSimulationService` for node projection and station load.

**Rationale:**
- Code reuse
- Consistent duration calculation
- Shared validation logic

---

## 6. Integration Points

### 6.1 MOLoadSimulationService Integration

**Usage:**
- `MOLoadSimulationService::runSimulation()` for node projection and station load
- Reuses canonical duration calculation
- Shares work center capacity data

**Benefits:**
- Code reuse
- Consistent calculations
- Single source of truth for load data

### 6.2 TimeEventReader Integration

**Usage:**
- `TimeEventReader::getTimelineForToken($tokenId, $nodeId)` for per-node duration
- Filters canonical `NODE_*` events
- Calculates duration from sessions

**Benefits:**
- Uses self-healed timeline (Phase 22)
- Per-node granularity
- Supports pause/resume scenarios

### 6.3 TimeHelper Integration

**Usage:**
- `TimeHelper::now()` for current time
- `TimeHelper::parse()` for parsing datetime strings
- `TimeHelper::toMysql()` for MySQL datetime format
- `TimeHelper::toIso8601()` for ISO8601 format

**Benefits:**
- Canonical timezone handling (Asia/Bangkok)
- Consistent time operations
- Timezone-aware calculations

---

## 7. Known Limitations

### 7.1 Stage Grouping Simplification

**Issue:** Stage grouping uses `sequence_no / 10` which may not match actual stages.

**Impact:** May group unrelated nodes together or split related nodes.

**Future Enhancement:** Use actual stage field when available in routing_node.

### 7.2 Queue Model Simplification

**Issue:** Queue model is simplified and doesn't account for actual token queue positions.

**Impact:** Waiting time estimates may not be accurate for high-load scenarios.

**Future Enhancement:** Integrate with actual queue system when available.

### 7.3 Sequential Node Execution

**Issue:** Nodes in stage are assumed to execute sequentially.

**Impact:** May overestimate execution time if nodes can run in parallel.

**Future Enhancement:** Add parallel execution detection based on graph structure.

### 7.4 Delay Propagation

**Issue:** Delay propagation only considers stage-level delays, not node-level.

**Impact:** May miss node-level bottlenecks.

**Future Enhancement:** Add node-level delay propagation.

---

## 8. Testing

### 8.1 Manual Testing

**API Endpoint:**
```
GET /mo_eta_api.php?action=eta&id_mo=123
```

**CLI Tool:**
```bash
php tools/mo_eta.php --mo=123
```

**Test Cases:**
- MO with routing graph → should return ETA
- MO without routing graph → should return error
- MO with canonical timeline data → should use canonical
- MO without canonical data → should use fallback
- Stage propagation → should calculate sequential stages
- Queue model → should include waiting time
- Best/normal/worst ETA → should calculate all three cases

### 8.2 Unit Tests (Future)

**TODO:** Create PHPUnit tests:
- Test duration selector priority
- Test queue model calculation
- Test stage propagation logic
- Test node timeline calculation
- Test best/normal/worst ETA calculation

---

## 9. Acceptance Criteria

### 9.1 Completed ✅

- ✅ `MOLoadEtaService.php` created with all required methods
- ✅ `mo_eta_api.php` created with eta endpoint
- ✅ `tools/mo_eta.php` CLI tool created
- ✅ Stage timeline propagation implemented
- ✅ Node timeline calculation implemented
- ✅ Queue model implemented
- ✅ Best/normal/worst ETA calculation implemented
- ✅ Patches applied to `MOLoadSimulationService` (p90_ms, capacity, constructor, sequence_no)
- ✅ Non-intrusive design (no changes to `mo.php`)

### 9.2 Pending

- ⏳ Stage field support (when available)
- ⏳ Unit tests
- ⏳ Parallel execution detection
- ⏳ Node-level delay propagation

---

## 10. Summary

Task 23.4 successfully implements the MO ETA Engine (Advanced ETA Model v1). The new `MOLoadEtaService` provides stage-level and node-level ETA calculation with delay propagation and queue modeling using canonical timeline (Phase 22) and load simulation (Task 23.3) for accurate estimation.

**Key Achievements:**
- ✅ Complete ETA engine (~450 lines)
- ✅ Stage timeline propagation
- ✅ Node timeline calculation
- ✅ Queue-based delay modeling
- ✅ Best/normal/worst ETA summary
- ✅ API endpoint + CLI tool
- ✅ Patches applied to Load Simulation service
- ✅ Non-intrusive design

**Next Steps:**
- Stage field support (when available)
- Unit tests
- Parallel execution detection
- Node-level delay propagation

---

**Task Status:** ✅ COMPLETE (Backend implementation done, testing pending)

