# Task 20 Results — ETA / Time Engine (Phase 1: Read-Only ETA & SLA Warnings)

**Status:** ✅ COMPLETE  
**Date:** 2025-01-XX  
**Category:** SuperDAG / ETA Engine / Phase 1

---

## 1. Executive Summary

Task 20 successfully implemented the ETA / Time Engine Phase 1, providing read-only ETA calculation and SLA status warnings for tokens in the SuperDAG system. The implementation follows strict safety guards: no routing decision changes, no validation layer modifications, no DB schema changes, and no ParallelMachineCoordinator behavior changes.

**Key Achievements:**
- ✅ Created EtaEngine service (pure compute, no DB writes)
- ✅ Integrated with DAGRoutingService (read-only methods)
- ✅ Added `token_eta` API action
- ✅ Added ETA/SLA preview in Graph Designer properties panel
- ✅ All tests passing (45/45)
- ✅ No regressions

---

## 2. Implementation Details

### 2.1 EtaEngine Service (NEW)

**File:** `source/BGERP/Dag/EtaEngine.php`

**Purpose:** Pure compute service for ETA calculation and SLA status evaluation

**Key Methods:**
- `computeNodeEtaForToken(array $token, ?array $node = null, ?array $graph = null): array`
  - Calculates ETA for a token at its current node
  - Returns: `planned_finish_at`, `remaining_ms`, `sla_status`, `node_code`, `sla_minutes`, `is_completed`
  - Handles both active tokens (not completed) and completed tokens (performance analysis)

**SLA Status Constants:**
- `ON_TRACK` – Token is within SLA (elapsed < 80% of SLA)
- `AT_RISK` – Token is approaching SLA (elapsed ≥ 80% of SLA)
- `BREACHING` – Token has exceeded SLA (elapsed > SLA)

**Features:**
- Pure compute service (no DB writes)
- Read-only queries only
- Supports both `sla_minutes` and `expected_minutes`
- Calculates actual duration from `start_at` and `completed_at` if `actual_duration_ms` is missing
- Handles NULL values gracefully (no SLA = no status)

**Size:** ~350 lines

---

### 2.2 DAGRoutingService Integration

**File:** `source/BGERP/Service/DAGRoutingService.php`

**Changes:**
- Added `use BGERP\Dag\EtaEngine;` import
- Added `private $etaEngine;` property
- Initialized EtaEngine in constructor
- Added `getTokenEta(int $tokenId): array` method (read-only)

**Method Details:**
```php
public function getTokenEta(int $tokenId): array
```
- Fetches token and current node
- Calls `EtaEngine::computeNodeEtaForToken()`
- Returns ETA result or error message

**Safety:** No changes to routing decision logic (`routeToken`, `handleParallelSplit`, `handleMergeNode`)

---

### 2.3 API Action: `token_eta`

**File:** `source/dag_routing_api.php`

**Location:** Added before `graph_versions` case

**Action:** `token_eta`

**Input Parameters:**
- `id_token` (integer, min: 1) OR
- `token_id` (integer, min: 1)

**Output Format:**
```json
{
  "ok": true,
  "eta": {
    "planned_finish_at": "2025-12-31T10:30:00+07:00",
    "remaining_ms": 1234567,
    "sla_status": "AT_RISK",
    "node_code": "QC1",
    "sla_minutes": 45,
    "expected_minutes": 30,
    "is_completed": false
  }
}
```

**Features:**
- Rate limiting: 120 requests per 60 seconds
- Cache header: 10 seconds (short cache for real-time ETA)
- Error handling: Returns 404 if token/node not found
- Uses DAGRoutingService (which uses EtaEngine internally)

**Example Usage:**
```
GET source/dag_routing_api.php?action=token_eta&id_token=123
```

---

### 2.4 Graph Designer UI Integration

**File:** `assets/javascripts/dag/graph_designer.js`

**Changes:**
- Added `renderEtaPreview(data)` function
- Added ETA/SLA Preview section in node properties panel
- Positioned after SLA Minutes field

**UI Features:**
- **Design-Time Preview:**
  - Shows SLA minutes (if configured)
  - Shows expected minutes (if configured)
  - Displays in human-readable format (minutes or hours)
  - Shows message if no SLA/expected time configured

**HTML Structure:**
```html
<div class="mb-3" id="prop-eta-preview-group">
    <label class="form-label mb-2">ETA / SLA Preview</label>
    <div id="eta-preview-content" class="border rounded p-2 bg-light">
        <!-- Rendered by renderEtaPreview() -->
    </div>
</div>
```

**Function:**
```javascript
function renderEtaPreview(data) {
    // Reads slaMinutes and expectedMinutes from node data
    // Returns HTML string with formatted display
}
```

**Note:** Phase 1 only shows design-time preview. Runtime ETA integration (showing actual token ETA) is deferred to future tasks.

---

## 3. Safety Verification

### 3.1 No Routing Decision Changes

✅ **Verified:**
- No changes to `routeToken()` method
- No changes to `handleParallelSplit()` method
- No changes to `handleMergeNode()` method
- No changes to `selectNextNode()` method
- EtaEngine is read-only (no routing logic)

### 3.2 No Validation Layer Changes

✅ **Verified:**
- No changes to `GraphValidationEngine`
- No changes to `SemanticIntentEngine`
- No changes to `GraphAutoFixEngine`
- No changes to validation logic

### 3.3 No DB Schema Changes

✅ **Verified:**
- No new migrations created
- No new columns added
- Uses existing fields from Task 19.5:
  - `routing_node.sla_minutes`
  - `routing_node.expected_minutes`
  - `flow_token.start_at`
  - `flow_token.actual_duration_ms`
  - `flow_token.completed_at`

### 3.4 No ParallelMachineCoordinator Changes

✅ **Verified:**
- No changes to `ParallelMachineCoordinator` behavior
- EtaEngine only reads parallel data (does not modify execution logic)

---

## 4. Test Results

### 4.1 SuperDAG Regression Tests

**ValidateGraphTest:**
- ✅ 15/15 passed
- No validation logic regressions

**AutoFixPipelineTest:**
- ✅ 15/15 passed
- No auto-fix logic regressions

**SemanticSnapshotTest:**
- ✅ 15/15 passed
- No semantic intent regressions

**Total:** 45/45 passed (100% pass rate)

### 4.2 Linter Verification

✅ **No Linter Errors:**
- `source/BGERP/Dag/EtaEngine.php` - No errors
- `source/BGERP/Service/DAGRoutingService.php` - No errors
- `source/dag_routing_api.php` - No errors
- `assets/javascripts/dag/graph_designer.js` - No errors

### 4.3 Manual Testing

✅ **Graph Designer:**
- Node properties panel displays ETA preview correctly
- SLA minutes shown when configured
- Expected minutes shown when configured
- No JavaScript console errors
- UI renders correctly

✅ **API Testing:**
- `token_eta` action returns correct JSON structure
- Error handling works (404 for missing token/node)
- Rate limiting enforced
- Cache headers set correctly

---

## 5. Acceptance Criteria

### 5.1 EtaEngine Exists + Has Unit-like Methods

✅ **PASSED**
- File: `source/BGERP/Dag/EtaEngine.php` exists
- Method: `computeNodeEtaForToken()` implemented
- No DB writes (pure compute)
- Read-only queries only

### 5.2 API `token_eta` Works

✅ **PASSED**
- Action: `source/dag_routing_api.php?action=token_eta&id_token=...` works
- Returns JSON with required fields:
  - `planned_finish_at` ✅
  - `remaining_ms` ✅
  - `sla_status` ✅
  - `node_code` ✅
  - `sla_minutes` ✅

### 5.3 UI Graph Designer Shows SLA/ETA Design-Time Preview

✅ **PASSED**
- Properties panel shows SLA (from `sla_minutes`)
- Properties panel shows expected time (from `expected_minutes`)
- No JavaScript console errors
- UI renders correctly

### 5.4 (Optional) Runtime ETA View

⚠️ **DEFERRED**
- Runtime ETA integration not implemented in Phase 1
- Design-time preview only (as specified in task requirements)
- Future task: Add runtime token ETA display when token context is available

### 5.5 All Tests Pass

✅ **PASSED**
- SuperDAG tests (3 files): 45/45 passed
- No new test failures
- No regressions

### 5.6 No Regression on Validation & Routing

✅ **PASSED**
- No changes to validation files
- No changes to auto-fix files
- No changes to semantic engine files
- No changes to routing behavior

---

## 6. Files Created/Modified

### 6.1 Created Files

1. **`source/BGERP/Dag/EtaEngine.php`** (NEW)
   - Pure compute service for ETA calculation
   - ~350 lines
   - Methods: `computeNodeEtaForToken()`, helper methods

### 6.2 Modified Files

1. **`source/BGERP/Service/DAGRoutingService.php`**
   - Added EtaEngine import
   - Added `$etaEngine` property
   - Added `getTokenEta()` method
   - **Lines Added:** ~30 lines

2. **`source/dag_routing_api.php`**
   - Added `token_eta` action case
   - **Lines Added:** ~50 lines

3. **`assets/javascripts/dag/graph_designer.js`**
   - Added `renderEtaPreview()` function
   - Added ETA preview section in properties panel
   - **Lines Added:** ~40 lines

---

## 7. Code Statistics

### 7.1 Lines of Code

- **EtaEngine.php:** ~350 lines (new)
- **DAGRoutingService.php:** +30 lines
- **dag_routing_api.php:** +50 lines
- **graph_designer.js:** +40 lines
- **Total Added:** ~470 lines

### 7.2 Complexity

- **EtaEngine:** Low complexity (pure compute, no side effects)
- **API Integration:** Low complexity (simple read-only endpoint)
- **UI Integration:** Low complexity (display-only, no logic)

---

## 8. Design Decisions

### 8.1 Pure Compute Service

**Decision:** EtaEngine is a pure compute service with no DB writes

**Rationale:**
- Follows Task 20 requirements (read-only)
- Safe to call from multiple contexts
- No side effects
- Easy to test

### 8.2 Design-Time Preview Only

**Decision:** Phase 1 only shows design-time preview (SLA/expected minutes from node data)

**Rationale:**
- Task 20 requirements specify design-time preview
- Runtime integration requires token context (more complex)
- Deferred to future tasks to reduce risk

### 8.3 AT_RISK Threshold (80%)

**Decision:** Hard-coded 80% threshold for AT_RISK status

**Rationale:**
- Task 20 requirements specify 80% threshold
- Commented for future adjustment
- Can be made configurable in future tasks

### 8.4 Integration via DAGRoutingService

**Decision:** API calls DAGRoutingService, which calls EtaEngine

**Rationale:**
- Keeps API layer clean
- Reuses existing service structure
- Easy to extend in future tasks

---

## 9. Future Enhancements (Out of Scope for Phase 1)

### 9.1 Runtime ETA Display

- Show actual token ETA in Graph Designer (when token context available)
- Display ETA in runtime views (job board, token list, QC screen)
- Real-time ETA updates

### 9.2 Parallel Block ETA

- Calculate ETA for parallel blocks (max of branch ETAs)
- Handle merge node ETA calculation

### 9.3 Path ETA

- Calculate ETA for entire graph path
- Predict completion time for full workflow

### 9.4 Configurable Thresholds

- Make AT_RISK threshold configurable (currently 80%)
- Add custom SLA warning levels

### 9.5 Historical Performance

- Use historical `actual_minutes` for better ETA prediction
- Machine-specific ETA adjustments

---

## 10. Summary

Task 20 Phase 1 Complete:
- ✅ EtaEngine service created (pure compute)
- ✅ DAGRoutingService integration (read-only)
- ✅ `token_eta` API action implemented
- ✅ Graph Designer UI shows ETA/SLA preview
- ✅ All tests passing (45/45)
- ✅ No regressions
- ✅ No routing/validation changes
- ✅ No DB schema changes

**Module Status:** ✅ Ready for Phase 2 (Runtime ETA Integration)

**Safety Status:** ✅ All safety guards followed

**Test Status:** ✅ 100% pass rate (45/45)

---

## 11. Note to Future Self

After Task 20 Phase 1:
- EtaEngine is the single source of truth for ETA calculation
- All ETA-related logic should go through EtaEngine
- Do not add ETA calculation logic directly in routing/validation services
- Runtime ETA integration should use EtaEngine (not duplicate logic)

**Next Steps (Task 20.x):**
- Runtime ETA display in Graph Designer
- Runtime ETA display in job board/token list
- Parallel block ETA calculation
- Path ETA calculation

---

**Task Status:** ✅ COMPLETE

**Final File Sizes:**
- EtaEngine.php: ~350 lines (new)
- DAGRoutingService.php: +30 lines
- dag_routing_api.php: +50 lines
- graph_designer.js: +40 lines

**Total Code Added:** ~470 lines

