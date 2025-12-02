# Task 23.2 Results — MO Assist Hardening & Canonical-Aware Validation

**Status:** ✅ COMPLETE  
**Date:** 2025-01-XX  
**Category:** SuperDAG / MO Engine / Productionization Layer

**⚠️ IMPORTANT:** This task hardens the MO Creation Extension Layer (Task 23.1) by adding canonical timeline support, enhanced graph validation, node behavior compatibility checks, and improved error handling.

---

## 1. Executive Summary

Task 23.2 successfully hardened:
- **MOCreateAssistService** - Enhanced with canonical timeline support, cycle detection, reachability checks, and node behavior compatibility validation
- **MO Assist API** - Added global error handling, GET-only enforcement, and accurate X-AI-Trace timing
- **Canonical Timeline Integration** - Uses `TimeEventReader` for accurate time estimation
- **Graph Validation** - Uses `ReachabilityAnalyzer` for cycle detection and reachability analysis

**Key Achievements:**
- ✅ Enhanced `estimateTime()` to use canonical timeline (TimeEventReader)
- ✅ Made `getHistoricDuration()` product-aware + routing-aware
- ✅ Enhanced `validateGraphStructure()` with cycle detection + reachability
- ✅ Added `checkNodeBehaviorCompatibility()` for classic line validation
- ✅ Enhanced `getNodeStats()` with work center breakdown
- ✅ Added global try/catch in `mo_assist_api.php`
- ✅ Enforced GET-only method
- ✅ Fixed X-AI-Trace timing to measure actual handler execution

---

## 2. Implementation Details

### 2.1 MOCreateAssistService Enhancements

#### 2.1.1 Canonical Timeline Support (estimateTime)

**Before (Task 23.1):**
- Used `flow_token.actual_duration_ms` directly
- Not product-aware (cross-product data mixed)

**After (Task 23.2):**
- New method: `getCanonicalDurationStatsForProductRouting()`
  - Uses `TimeEventReader::getTimelineForToken()` for each token
  - Filters by product + routing (JOIN with MO)
  - Calculates avg, p50, p90 statistics
- `estimateTime()` now:
  1. Tries canonical timeline first
  2. Falls back to `flow_token.actual_duration_ms` if no canonical data
  3. Returns `uses_canonical` flag

**Code Changes:**
```php
// New method
private function getCanonicalDurationStatsForProductRouting(int $productId, int $routingId): ?array
{
    // Query tokens with product + routing filter
    // Use TimeEventReader for each token
    // Calculate statistics (avg, p50, p90)
}

// Updated estimateTime()
public function estimateTime(int $productId, int $routingId, int $qty): array
{
    // Try canonical first
    $canonicalStats = $this->getCanonicalDurationStatsForProductRouting($productId, $routingId);
    if ($canonicalStats) {
        // Use canonical avg
    } else {
        // Fallback to flow_token
    }
}
```

#### 2.1.2 Product-Aware Historic Duration

**Before (Task 23.1):**
- `getHistoricDuration()` only filtered by routing
- Cross-product data could be mixed

**After (Task 23.2):**
- Renamed to `getHistoricDurationForProductRouting()`
- JOINs with MO table to filter by product
- Used as fallback when canonical timeline unavailable

**Code Changes:**
```php
private function getHistoricDurationForProductRouting(int $productId, int $routingId): ?array
{
    // JOIN with mo table to filter by product
    // SELECT ... FROM flow_token ft
    // JOIN job_graph_instance jgi ON jgi.id_instance = ft.id_instance
    // LEFT JOIN mo m ON m.graph_instance_id = jgi.id_instance
    // WHERE jgi.id_graph = ? AND (m.id_product = ? OR m.id_product IS NULL)
}
```

#### 2.1.3 Enhanced Graph Structure Validation

**Before (Task 23.1):**
- Only checked root/leaf nodes
- No cycle detection
- No reachability analysis

**After (Task 23.2):**
- Uses `ReachabilityAnalyzer` for comprehensive analysis
- Detects cycles → `GRAPH_CYCLE_DETECTED` error
- Detects unreachable nodes → `UNREACHABLE_NODE` warning
- Maintains root/leaf node checks

**Code Changes:**
```php
private function validateGraphStructure(int $routingId): array
{
    // ... root/leaf checks ...
    
    // Task 23.2: Cycle detection + reachability
    $nodes = /* fetch nodes */;
    $edges = /* fetch edges */;
    $analysis = $this->reachabilityAnalyzer->analyze($nodes, $edges);
    
    if (!empty($analysis['cycles'])) {
        $errors[] = [
            'code' => 'GRAPH_CYCLE_DETECTED',
            'severity' => 'error',
            'details' => $analysis['cycles'],
        ];
    }
    
    if (!empty($analysis['unreachable_nodes'])) {
        $warnings[] = [
            'code' => 'UNREACHABLE_NODE',
            'severity' => 'warning',
            'message' => "Found {$unreachableCount} unreachable node(s)",
        ];
    }
}
```

#### 2.1.4 Node Behavior Compatibility Check

**New Feature (Task 23.2):**
- Validates that nodes use work centers with classic-compatible `node_mode`
- Checks `work_center.node_mode` for each operation node
- Warns if `HAT_SINGLE` mode is used (hatthasilpa-only)
- Classic-compatible modes: `CLASSIC_SCAN`, `QC_SINGLE`, `BATCH_QUANTITY`

**Code Changes:**
```php
private function checkNodeBehaviorCompatibility(int $routingId, string $productionType): array
{
    // Get nodes with work center node_mode
    // Check compatibility based on production type
    // Return warnings for incompatible nodes
}
```

#### 2.1.5 Enhanced Node Stats

**Before (Task 23.1):**
- Only grouped by `node_type`

**After (Task 23.2):**
- Added `by_work_center` breakdown (optional, if schema supports)
- Returns work center code, name, and node count per work center

**Code Changes:**
```php
public function getNodeStats(int $routingId): array
{
    // ... existing by_type grouping ...
    
    // Task 23.2: Try to get work_center breakdown
    try {
        // JOIN with work_center table
        // Group by work_center
    } catch (\Exception $e) {
        // Schema may not support - ignore
    }
}
```

### 2.2 MO Assist API Hardening

#### 2.2.1 GET-Only Enforcement

**Before (Task 23.1):**
- Used `$_REQUEST['action']` (accepts GET/POST)

**After (Task 23.2):**
- Checks `$_SERVER['REQUEST_METHOD']` before processing
- Returns 405 if not GET
- Uses `$_GET['action']` instead of `$_REQUEST['action']`

**Code Changes:**
```php
// Task 23.2: Enforce GET-only
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_error('Method Not Allowed', 405, [
        'app_code' => 'MO_ASSIST_405_METHOD_NOT_ALLOWED',
        'allowed' => 'GET',
    ]);
}

// Use $_GET instead of $_REQUEST
$action = $_GET['action'] ?? '';
```

#### 2.2.2 Global Error Handling

**Before (Task 23.1):**
- No global try/catch
- Exceptions could expose stack traces

**After (Task 23.2):**
- Wraps entire switch statement in try/catch
- Logs errors with context (CID, user, action)
- Returns standardized 500 error
- Does not expose stack traces to client

**Code Changes:**
```php
try {
    switch ($action) {
        // ... handlers ...
    }
} catch (\Throwable $e) {
    // Log with context
    error_log(sprintf(
        "[CID:%s][%s][User:%d][Action:%s] %s",
        $cid, basename(__FILE__), $member['id_member'], $action, $e->getMessage()
    ));
    
    json_error('Internal server error', 500, [
        'app_code' => 'MO_ASSIST_500_INTERNAL_ERROR',
        'hint' => 'Contact system administrator.',
    ]);
}
```

#### 2.2.3 Accurate X-AI-Trace Timing

**Before (Task 23.1):**
- X-AI-Trace set before handler execution
- Only measured bootstrap time

**After (Task 23.2):**
- Moved X-AI-Trace to `finally` block
- Measures actual handler execution time
- Always sent even if exception occurs

**Code Changes:**
```php
try {
    // ... handlers ...
} catch (\Throwable $e) {
    // ... error handling ...
} finally {
    // Task 23.2: Update X-AI-Trace with actual execution time
    $aiTrace = [
        'cid' => $cid,
        'file' => 'mo_assist_api.php',
        'user' => $member['username'] ?? 'unknown',
        'action' => $action,
        'execution_ms' => round((microtime(true) - $__t0) * 1000, 2),
    ];
    header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));
}
```

---

## 3. Files Modified

### 3.1 Core Implementation

1. **`source/BGERP/MO/MOCreateAssistService.php`** (MODIFIED)
   - Added `ReachabilityAnalyzer` dependency
   - Enhanced `estimateTime()` with canonical timeline support
   - Renamed `getHistoricDuration()` → `getHistoricDurationForProductRouting()`
   - Added `getCanonicalDurationStatsForProductRouting()` method
   - Enhanced `validateGraphStructure()` with cycle detection + reachability
   - Added `checkNodeBehaviorCompatibility()` method
   - Enhanced `getNodeStats()` with work center breakdown

2. **`source/mo_assist_api.php`** (MODIFIED)
   - Added GET-only enforcement
   - Added global try/catch
   - Fixed X-AI-Trace timing (moved to finally block)
   - Changed `$_REQUEST` → `$_GET`

### 3.2 Code Statistics

- **Lines Modified:** ~200 lines
- **New Methods:** 3 (`getCanonicalDurationStatsForProductRouting`, `getHistoricDurationForProductRouting`, `checkNodeBehaviorCompatibility`)
- **Methods Enhanced:** 4 (`estimateTime`, `validateGraphStructure`, `getNodeStats`, `validateRouting`)

---

## 4. Design Decisions

### 4.1 Canonical Timeline First, Fallback Second

**Decision:** Try canonical timeline first, fallback to `flow_token.actual_duration_ms` if unavailable.

**Rationale:**
- Canonical timeline is more accurate (Phase 22 self-healing)
- Fallback ensures backward compatibility
- `uses_canonical` flag allows UI to show data source

### 4.2 Product-Aware Filtering

**Decision:** Filter historic duration by both product and routing.

**Rationale:**
- Different products may have different durations even with same routing
- Prevents cross-product data contamination
- More accurate estimates

### 4.3 ReachabilityAnalyzer Integration

**Decision:** Use existing `ReachabilityAnalyzer` instead of implementing custom cycle detection.

**Rationale:**
- Reuses proven, tested code
- Consistent with other graph validation
- Comprehensive analysis (cycles, unreachable nodes, dead ends)

### 4.4 Node Behavior Compatibility

**Decision:** Check `work_center.node_mode` for classic line compatibility.

**Rationale:**
- MO is classic-only (from task23.blueprint.md)
- `HAT_SINGLE` mode is incompatible with classic line
- Warning allows user to fix before creating MO

### 4.5 Optional Work Center Breakdown

**Decision:** Try to get work center breakdown, but don't fail if schema doesn't support it.

**Rationale:**
- Schema may vary across tenants
- Optional feature shouldn't break core functionality
- Try/catch ensures graceful degradation

### 4.6 GET-Only Enforcement

**Decision:** Enforce GET method at API level.

**Rationale:**
- Task 23.1 spec states "All GET requests"
- Prevents accidental POST usage
- Clear error message (405 Method Not Allowed)

### 4.7 Global Error Handling

**Decision:** Wrap entire switch in try/catch, log errors, return standardized response.

**Rationale:**
- Prevents unhandled exceptions from exposing stack traces
- Consistent error format
- Better debugging with context (CID, user, action)

### 4.8 X-AI-Trace in Finally Block

**Decision:** Move X-AI-Trace to finally block to measure actual execution time.

**Rationale:**
- Measures handler execution, not just bootstrap
- Always sent even if exception occurs
- More accurate performance monitoring

---

## 5. Integration Points

### 5.1 TimeEventReader Integration

**Usage:**
- `TimeEventReader::getTimelineForToken()` for canonical duration
- Filters canonical `NODE_*` events
- Calculates duration from sessions

**Benefits:**
- Uses self-healed timeline (Phase 22)
- More accurate than `flow_token.actual_duration_ms`
- Supports pause/resume scenarios

### 5.2 ReachabilityAnalyzer Integration

**Usage:**
- `ReachabilityAnalyzer::analyze()` for graph structure validation
- Detects cycles, unreachable nodes, dead ends
- Returns structured analysis results

**Benefits:**
- Reuses proven validation logic
- Comprehensive graph analysis
- Consistent with other graph validation

### 5.3 Work Center Schema Integration

**Usage:**
- Reads `work_center.node_mode` for compatibility check
- JOINs `routing_node` with `work_center` table
- Validates classic line compatibility

**Benefits:**
- Ensures MO uses compatible node modes
- Prevents runtime errors
- Clear warnings for incompatible configurations

---

## 6. Known Limitations

### 6.1 Canonical Timeline Performance

**Issue:** `getCanonicalDurationStatsForProductRouting()` queries up to 100 tokens and calls `TimeEventReader` for each.

**Impact:** May be slow if many tokens need processing.

**Future Enhancement:** Add caching or batch processing.

### 6.2 Work Center Breakdown Optional

**Issue:** Work center breakdown may not work if schema doesn't support JOIN.

**Impact:** Feature gracefully degrades (returns empty array).

**Future Enhancement:** Check schema version or feature flag.

### 6.3 Node Behavior Compatibility

**Issue:** Only checks `HAT_SINGLE` as incompatible. Other modes may need validation.

**Impact:** May miss edge cases.

**Future Enhancement:** Expand compatibility matrix based on production requirements.

---

## 7. Testing

### 7.1 Manual Testing

**Endpoints to Test:**
1. `/mo_assist_api.php?action=estimate-time&id_product=1&id_routing=1&qty=100`
   - Should use canonical timeline if available
   - Should fallback to `flow_token` if no canonical data
   - Should return `uses_canonical` flag

2. `/mo_assist_api.php?action=validate&id_product=1&id_routing=1&production_type=classic`
   - Should detect cycles if graph has cycles
   - Should detect unreachable nodes
   - Should check node behavior compatibility

3. `/mo_assist_api.php?action=node-stats&id_routing=1`
   - Should return work center breakdown if available

4. POST request to any endpoint
   - Should return 405 Method Not Allowed

5. Exception scenario
   - Should return 500 with standardized error
   - Should not expose stack trace
   - Should log error with context

### 7.2 Unit Tests (Future)

**TODO:** Create PHPUnit tests:
- Test canonical timeline calculation
- Test cycle detection
- Test reachability analysis
- Test node behavior compatibility
- Test GET-only enforcement
- Test error handling

---

## 8. Acceptance Criteria

### 8.1 Completed ✅

- ✅ `estimateTime()` uses canonical timeline (TimeEventReader) when available
- ✅ `getHistoricDuration()` is product-aware + routing-aware
- ✅ `validateGraphStructure()` detects cycles and unreachable nodes
- ✅ Node behavior compatibility check for classic line
- ✅ `getNodeStats()` includes work center breakdown (optional)
- ✅ Global try/catch in `mo_assist_api.php`
- ✅ GET-only enforcement
- ✅ Accurate X-AI-Trace timing (finally block)

### 8.2 Pending

- ⏳ Unit tests for new methods
- ⏳ Integration tests for canonical timeline
- ⏳ Performance testing for canonical timeline calculation

---

## 9. Summary

Task 23.2 successfully hardened the MO Creation Extension Layer by:
- Integrating canonical timeline (Phase 22) for accurate time estimation
- Adding comprehensive graph validation (cycles, reachability)
- Validating node behavior compatibility for classic line
- Improving error handling and API robustness

**Key Achievements:**
- ✅ Canonical timeline support (TimeEventReader)
- ✅ Product-aware historic duration
- ✅ Cycle detection + reachability analysis
- ✅ Node behavior compatibility validation
- ✅ Enhanced error handling
- ✅ GET-only enforcement
- ✅ Accurate performance monitoring

**Next Steps:**
- Unit tests
- Performance optimization for canonical timeline
- Expand node behavior compatibility matrix

---

**Task Status:** ✅ COMPLETE (Backend implementation done, testing pending)

