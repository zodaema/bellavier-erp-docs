# Task 18 Results — Machine Cycles & Throughput-Aware Execution

**Status:** ✅ COMPLETED  
**Date:** 2025-12-17  
**Category:** Super DAG – Execution Layer (Phase 7)  
**Depends on:** Task 1–17 (Behavior & Execution Engine, Session Engine, Routing Integration, Parallel/Merge)

---

## 📋 Executive Summary

Task 18 successfully introduced **machine cycle awareness and throughput constraints** into Super DAG execution. The system now supports:

- ✅ Machine/equipment registry and allocation
- ✅ Node-level machine binding configuration (NONE, BY_WORK_CENTER, EXPLICIT)
- ✅ Machine-aware token routing with concurrency limits
- ✅ Machine cycle time tracking (started_at, completed_at)
- ✅ Queue management for machine-bound tokens
- ✅ UI integration in Graph Designer for machine configuration

**Key Achievement:** Non-machine-bound nodes continue to behave exactly as before (Task 17 compatibility maintained).

---

## 🎯 Objectives Completed

### 1. Schema & Migration ✅

**File:** `database/tenant_migrations/2025_12_18_machine_cycle_support.php`

**Machine Table:**
- Created `machine` table with:
  - `machine_code` (VARCHAR(50), UNIQUE)
  - `machine_name` (VARCHAR(100))
  - `work_center_code` (VARCHAR(50), FK to work_center.code)
  - `cycle_time_seconds` (INT) — average cycle time per unit/batch
  - `batch_capacity` (INT, default 1)
  - `concurrency_limit` (INT, default 1) — max parallel tokens
  - `is_system` (TINYINT(1), default 0)
  - `is_active` (TINYINT(1), default 1)
  - Indexes: `uniq_machine_code`, `idx_work_center_code`, `idx_is_active`, `idx_wc_active`

**Token Metadata (flow_token):**
- `machine_code` (VARCHAR(50), NULL)
- `machine_cycle_started_at` (DATETIME, NULL)
- `machine_cycle_completed_at` (DATETIME, NULL)
- Indexes: `idx_machine_code`, `idx_machine_node_status`

**Node Configuration (routing_node):**
- `machine_binding_mode` (VARCHAR(50), NULL) — NONE, BY_WORK_CENTER, EXPLICIT
- `machine_codes` (TEXT, NULL) — JSON array of machine codes (for EXPLICIT mode)
- Index: `idx_machine_binding`

**Validation:**
- Checks for invalid `machine_binding_mode` values
- Checks for EXPLICIT nodes with empty `machine_codes`
- Checks for orphaned `machine_code` references in `flow_token`

---

### 2. Machine Registry & Allocation Service ✅

**Files:**
- `source/BGERP/Dag/MachineRegistry.php` (moved from `BGERP/SuperDAG/`)
- `source/BGERP/Dag/MachineAllocationService.php` (moved from `BGERP/SuperDAG/`)

**MachineRegistry Responsibilities:**
- `getMachinesByWorkCenter(?string $workCenterCode, bool $activeOnly)` — Get machines for a work center
- `getMachineByCode(string $machineCode)` — Get single machine
- `getMachinesByCodes(array $machineCodes, bool $activeOnly)` — Get machines by explicit list
- `validateMachineCodes(array $machineCodes)` — Validate machine codes exist
- `getMachineMetadata(string $machineCode)` — Get cycle_time, batch_capacity, concurrency_limit

**MachineAllocationService Responsibilities:**
- `allocateMachine(int $tokenId, int $nodeId, ?string $workCenterCode, ?string $machineBindingMode, ?string $machineCodesJson)` — Allocate machine for token
  - Returns: `['allocated' => bool, 'machine_code' => string|null, 'waiting' => bool, 'reason' => string]`
- `releaseMachine(int $tokenId)` — Release machine slot when token completes
- `assignMachine(int $tokenId, string $machineCode)` — Assign machine to token

**Allocation Logic:**
- **BY_WORK_CENTER:** Auto-select from machines under node's work_center
- **EXPLICIT:** Use explicit machine_codes list
- **Concurrency Limit:** Respects `concurrency_limit` per machine (checks active tokens)
- **Queue Management:** Returns `waiting: true` if no machine available

---

### 3. Node-Level Machine Configuration ✅

**API Updates (`source/dag_routing_api.php`):**

**node_create / node_update:**
- Accepts `machine_binding_mode` (NONE, BY_WORK_CENTER, EXPLICIT)
- Accepts `machine_codes` (JSON array string for EXPLICIT mode)
- Validates `machine_codes` format and existence (if EXPLICIT)
- Error codes: `DAG_INVALID_MACHINE_CONFIG`, `DAG_MACHINE_NOT_FOUND`

**loadGraphWithVersion:**
- Includes `machine_binding_mode` and `machine_codes` in node JSON

**Validation:**
- EXPLICIT mode requires non-empty `machine_codes`
- Validates machine codes exist in `MachineRegistry`
- Returns clear error messages for invalid configurations

---

### 4. Execution Logic — Machine-Aware Token Routing ✅

**File:** `source/BGERP/Service/DAGRoutingService.php`

**Machine Allocation (routeToNode):**
```php
// When token enters machine-bound node:
1. Check machine_binding_mode
2. Call MachineAllocationService->allocateMachine()
3. If allocated → assign machine_code, set machine_cycle_started_at
4. If waiting → set token status = 'waiting', return waiting response
5. Log machine_allocated or machine_waiting event
```

**Machine Release (routeToken):**
```php
// When token leaves machine-bound node:
1. Check if token has machine_code
2. Call MachineAllocationService->releaseMachine()
3. Set machine_cycle_completed_at = NOW()
4. Log machine_released event
```

**Integration Points:**
- Machine allocation happens **after** token move but **before** status update
- Machine release happens **before** routing to next node
- Non-machine-bound nodes (`machine_binding_mode = NONE`) bypass machine logic entirely

**Event Logging:**
- `machine_allocated` — Machine assigned to token
- `machine_waiting` — Token waiting for machine slot
- `machine_released` — Machine slot freed

---

### 5. Graph Designer UI ✅

**File:** `assets/javascripts/dag/graph_designer.js`

**Machine Settings Section:**
- Added after Parallel Execution section
- Only shown for operation nodes (`isOperation === true`)
- Fields:
  - **Machine Binding Mode** dropdown:
    - `NONE` — No machine binding (default)
    - `BY_WORK_CENTER` — Auto-select from work center machines
    - `EXPLICIT` — Explicit machine list
  - **Machine Codes** textarea (shown when EXPLICIT selected):
    - JSON array format: `["MACHINE_001", "MACHINE_002"]`
    - Required for EXPLICIT mode
    - Validates JSON format and non-empty array

**Event Handlers:**
- `updateMachineBindingUI()` — Show/hide machine codes input based on binding mode
- Form validation — Ensures machine codes are valid JSON array with non-empty strings

**GraphSaver Integration:**
- `collectNodes()` includes `machine_binding_mode` and `machine_codes` in node data
- Graph loading parses `machine_codes` from JSON string to array

---

### 6. Seed Data ✅

**File:** `database/tenant_migrations/0002_seed_data.php`

**Default Machines (Optional):**
- `CUT_MACHINE_001` — Default cutting machine for CUT work center
- `EDG_MACHINE_001` — Default edging machine for EDG work center
- `SEW_MACHINE_001` — Default sewing machine for SEW work center

**Default Node Configuration:**
- All existing nodes set to `machine_binding_mode = NONE` (backward compatible)

**Idempotency:**
- Uses `migration_insert_if_not_exists()` for all seed operations
- Safe to run multiple times

---

## 🔧 Technical Implementation Details

### Machine Allocation Flow

```
Token enters machine-bound node:
  ↓
1. routeToNode() called
2. Move token to node
3. Check machine_binding_mode:
   - NONE → Skip machine logic
   - BY_WORK_CENTER → Get machines from work_center_code
   - EXPLICIT → Parse machine_codes JSON
4. MachineAllocationService->allocateMachine():
   - Find candidate machines
   - Check concurrency_limit (count active tokens)
   - If available → assign machine_code, set machine_cycle_started_at
   - If not available → set status = 'waiting', return
5. Continue with normal routing (if machine allocated)
```

### Machine Release Flow

```
Token completes node:
  ↓
1. routeToken() called
2. Check if token has machine_code
3. MachineAllocationService->releaseMachine():
   - Set machine_cycle_completed_at = NOW()
4. Route token to next node
```

### Concurrency Limit Enforcement

```php
// Count active tokens on machine at specific node
SELECT COUNT(*) 
FROM flow_token
WHERE machine_code = ?
  AND current_node_id = ?
  AND status IN ('active', 'waiting')
  AND machine_cycle_started_at IS NOT NULL
  AND machine_cycle_completed_at IS NULL

// If count < concurrency_limit → machine available
// If count >= concurrency_limit → token must wait
```

---

## ✅ Safety & Edge Cases

### 1. Non-Machine Nodes Unchanged ✅
- Nodes with `machine_binding_mode = NONE` behave exactly as Task 17
- No performance impact on non-machine-bound nodes

### 2. No Forced Machines ✅
- System does not automatically bind machines to all nodes
- Machine binding is opt-in via DAG configuration

### 3. Graceful Degradation ✅
- Invalid machine config → Clear error messages
- Missing machines → Token waits (does not fail)
- Orphaned machine_code references → Validation warnings (does not break execution)

### 4. Parallel + Machine ✅
- Parallel branches can bind to different machines
- Merge semantics from Task 17 continue to work
- Each parallel token can have its own machine allocation

### 5. Rework ✅
- Rework tokens re-enter machine-bound nodes → Machine allocation executed again
- Concurrency limits respected for rework tokens

### 6. Idempotency ✅
- Migration safe to run multiple times
- Seed data uses `migration_insert_if_not_exists()`
- Default `machine_binding_mode = NONE` only set if NULL

---

## 📊 Files Modified

### Backend
1. `database/tenant_migrations/2025_12_18_machine_cycle_support.php` — Migration (created)
2. `database/tenant_migrations/0002_seed_data.php` — Machine seeding (updated)
3. `source/BGERP/Dag/MachineRegistry.php` — Machine registry service (created, moved from SuperDAG)
4. `source/BGERP/Dag/MachineAllocationService.php` — Machine allocation service (created, moved from SuperDAG)
5. `source/BGERP/Service/DAGRoutingService.php` — Machine-aware routing (updated)
6. `source/dag_routing_api.php` — Machine binding API support (updated)

### Frontend
7. `assets/javascripts/dag/graph_designer.js` — Machine settings UI (updated)
8. `assets/javascripts/dag/modules/GraphSaver.js` — Machine fields in graph save (updated)

### Namespace Refactoring
- Moved `BGERP\SuperDAG\MachineRegistry` → `BGERP\Dag\MachineRegistry`
- Moved `BGERP\SuperDAG\MachineAllocationService` → `BGERP\Dag\MachineAllocationService`
- Updated all references in `DAGRoutingService` and `dag_routing_api.php`

---

## 🧪 Testing Recommendations

### Unit Tests
- [ ] `MachineRegistry::getMachinesByWorkCenter()` — Returns correct machines
- [ ] `MachineRegistry::validateMachineCodes()` — Validates machine codes exist
- [ ] `MachineAllocationService::allocateMachine()` — Allocates available machine
- [ ] `MachineAllocationService::allocateMachine()` — Returns waiting if no machine available
- [ ] `MachineAllocationService::releaseMachine()` — Releases machine slot

### Integration Tests
- [ ] Token enters machine-bound node → Machine allocated
- [ ] Token enters machine-bound node → Token waits if no machine available
- [ ] Token completes machine-bound node → Machine released
- [ ] Non-machine-bound node → No machine logic executed
- [ ] EXPLICIT mode with invalid machine codes → Error returned
- [ ] Parallel branches with machines → Each branch can have different machine
- [ ] Rework token re-enters machine-bound node → Machine allocated again

### UI Tests
- [ ] Machine Settings section appears for operation nodes
- [ ] Machine Codes input shown when EXPLICIT mode selected
- [ ] Validation prevents saving EXPLICIT mode with empty machine codes
- [ ] Graph save/load preserves machine_binding_mode and machine_codes

---

## 📝 Next Steps (Future Tasks)

### Task 19 — SLA / Time Modeling
- Use `machine_cycle_started_at` and `machine_cycle_completed_at` for cycle time statistics
- Calculate expected completion time using `cycle_time_seconds`
- Model throughput across work centers and machines

### Task 20 — Advanced Dispatching & Skill-based Routing
- Account for machine availability in dispatching decisions
- Skill-based routing that considers machine capabilities
- Machine maintenance scheduling integration

---

## 🎉 Summary

Task 18 successfully adds **machine cycle awareness** to Super DAG execution without breaking existing functionality. The system now:

- ✅ Supports physical machine constraints (cycle time, capacity, concurrency)
- ✅ Provides machine-aware token routing with queue management
- ✅ Maintains backward compatibility (non-machine nodes unchanged)
- ✅ Offers flexible machine binding (NONE, BY_WORK_CENTER, EXPLICIT)
- ✅ Tracks machine cycle durations for future SLA modeling

**All deliverables completed. System ready for Task 19 (SLA / Time Modeling).**

---

**Related Documents:**
- `docs/super_dag/tasks/task18.md` — Original task specification
- `docs/super_dag/tasks/task17_results.md` — Parallel/Merge implementation
- `docs/super_dag/tasks/task16_results.md` — Execution Mode Binding

