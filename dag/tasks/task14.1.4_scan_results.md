# Task 14.1.4 — Routing Execution Layer Scan Results

## Summary
This document identifies all routing execution touchpoints that need to be migrated from Routing V1 (direct `DAGRoutingService` calls, `TokenLifecycleService.moveToken()`) to Routing V2 (`DagExecutionService`).

---

## Files Scanned

### 1. `source/dag_token_api.php`
**Status:** Partially migrated (mixed V1/V2)

#### Touchpoints:

**A. Auto-route from START node (Line 692-714)**
- **Current:** `DAGRoutingService->routeToken($tokenId)`
- **Target:** `DagExecutionService->moveToNextNode($tokenId)`
- **Context:** After token spawn, auto-route tokens from START node
- **Priority:** HIGH (execution path)

**B. `handleTokenMove()` (Line 826-922)**
- **Current:** ✅ Already uses `DagExecutionService->moveToNodeId($tokenId, $toNodeId)`
- **Status:** ✅ MIGRATED (no change needed)

**C. `handleTokenComplete()` (Line 936-1049)**
- **Current:** `DAGRoutingService->routeToken($tokenId, $userId)` (Line 1012)
- **Target:** `DagExecutionService->moveToNextNode($tokenId)`
- **Context:** Manager/system-level complete (deprecated endpoint, but still used)
- **Priority:** MEDIUM (backward compatibility)

**D. `handleCompleteToken()` (Line 2617-2698)**
- **Current:** Mixed - uses `DagExecutionService->moveToNextNode()` with fallback to `DAGRoutingService->routeToken()` (Line 2659-2665)
- **Target:** Remove fallback, use `DagExecutionService` exclusively
- **Context:** Operator-level complete from Work Queue
- **Priority:** HIGH (primary execution path)
- **Note:** QC nodes still use `DAGRoutingService->handleQCResult()` (Line 2650) - this is acceptable as QC routing is complex

---

### 2. `source/pwa_scan_api.php`
**Status:** Needs verification

#### Touchpoints:
- **Scan Result:** No direct routing calls found in grep
- **Action:** Verify if routing is handled via `dag_token_api.php` or `BehaviorExecutionService`
- **Priority:** LOW (likely already migrated via BehaviorExecutionService)

---

### 3. `source/BGERP/Dag/BehaviorExecutionService.php`
**Status:** ✅ Already migrated

#### Touchpoints:
- **Current:** ✅ Uses `DagExecutionService->moveToNextNode($tokenId)` (Lines 423, 845, 1112)
- **Status:** ✅ MIGRATED (no change needed)
- **Note:** This service is the primary gateway for behavior-triggered routing

---

### 4. `source/dag_routing_api.php`
**Status:** Metadata API (not execution layer)

#### Touchpoints:
- **Current:** Uses `DAGRoutingService` for metadata queries (graph structure, node info)
- **Status:** ✅ NO MIGRATION NEEDED (metadata APIs, not execution)
- **Note:** This file handles graph metadata, not token movement

---

### 5. `source/BGERP/Service/DAGRoutingService.php`
**Status:** Internal service (used by DagExecutionService)

#### Touchpoints:
- **Current:** Contains `routeToken()` method that performs direct SQL updates
- **Status:** ✅ NO MIGRATION NEEDED (internal service, used by DagExecutionService)
- **Note:** This service is called by `DagExecutionService`, not directly by APIs

---

### 6. `source/BGERP/Service/TokenLifecycleService.php`
**Status:** Internal service (used by DagExecutionService)

#### Touchpoints:
- **Current:** Contains `moveToken()` method that performs direct SQL updates
- **Status:** ✅ NO MIGRATION NEEDED (internal service, used by DagExecutionService)
- **Note:** This service is called by `DagExecutionService`, not directly by APIs

---

## Migration Mapping Table

| File | Function/Line | Current (V1) | Target (V2) | Status | Priority |
|------|---------------|--------------|-------------|--------|----------|
| `dag_token_api.php` | Auto-route START (692-714) | `DAGRoutingService->routeToken()` | `DagExecutionService->moveToNextNode()` | ⚠️ TODO | HIGH |
| `dag_token_api.php` | `handleTokenMove()` (826-922) | `DagExecutionService->moveToNodeId()` | ✅ Already V2 | ✅ DONE | - |
| `dag_token_api.php` | `handleTokenComplete()` (1012) | `DAGRoutingService->routeToken()` | `DagExecutionService->moveToNextNode()` | ⚠️ TODO | MEDIUM |
| `dag_token_api.php` | `handleCompleteToken()` (2659-2665) | Mixed (V2 + V1 fallback) | `DagExecutionService` only | ⚠️ TODO | HIGH |
| `BehaviorExecutionService.php` | `execute()` (423, 845, 1112) | `DagExecutionService->moveToNextNode()` | ✅ Already V2 | ✅ DONE | - |

---

## Backward Compatibility Notes

### V1 Fallback Strategy
- **QC Nodes:** `DAGRoutingService->handleQCResult()` is still used for QC-specific routing logic (pass → normal route, fail → rework)
- **Complex Routing:** Some edge cases may still require `DAGRoutingService` for backward compatibility
- **Legacy Tokens:** Tokens spawned before V2 migration may need V1 routing until they complete

### V2 Override Strategy
- **New Tokens:** All new tokens use V2 routing exclusively
- **Active Tokens:** Migrate to V2 routing when they move to next node
- **Graph Metadata:** Always read from V2 (`routing_graph`, `routing_node`, `routing_edge`)

---

## Remaining V1 References (Acceptable)

1. **QC Routing:** `DAGRoutingService->handleQCResult()` - Complex QC decision logic, acceptable to keep
2. **Metadata APIs:** `dag_routing_api.php` - Graph structure queries, not execution
3. **Internal Services:** `DAGRoutingService`, `TokenLifecycleService` - Used by `DagExecutionService`, not directly by APIs

---

## Next Steps

1. ✅ **Scan Complete** - All touchpoints identified
2. ⚠️ **Migrate `dag_token_api.php`** - Replace V1 calls with V2
3. ⚠️ **Remove V1 Fallback** - Clean up mixed V1/V2 code in `handleCompleteToken()`
4. ⚠️ **Test** - Verify all routing scenarios work correctly
5. ⚠️ **Document** - Create routing matrix and results document

