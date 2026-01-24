# Task 16 Results — Execution Mode Binding (Behavior + Mode = NodeType)

**Status:** ✅ **COMPLETED** (December 2025)  
**Category:** Super DAG – Core Graph Layer (Phase 5)  
**Depends on:** Task 1–15 (Behavior Engine, Execution Layer, Session Engine, Routing Integration, Node Behavior Binding)

---

## 📋 Summary

Task 16 establishes the **true NodeType Model**, where each DAG node becomes:
```
NodeType = Behavior + ExecutionMode
```

This canonical typing enables deterministic routing, time modeling, QC flows, parallel paths, machine-driven flows, and analytics & throughput SLA. It sets up Task 17 (Parallel Node Execution).

---

## ✅ Deliverables Completed

### 1. Database Schema Update

**Migration File:** `database/tenant_migrations/2025_12_16_dag_node_mode_binding.php`

**Changes:**
- Added `execution_mode` VARCHAR(50) NULL column to `routing_node` table
- Added `derived_node_type` VARCHAR(100) NULL column to `routing_node` table
- Added index `idx_execution_mode` for performance

**Note:** 
- `node_type` column already exists as enum('start','operation','split','join','decision','end','qc','wait','subgraph','system')
- `derived_node_type` stores the derived type: `${behavior_code}:${execution_mode}` (e.g., "CUT:BATCH", "STITCH:HAT_SINGLE")

**Backfill Logic:**
- Rule 1: Use canonical mapping (Behavior → ExecutionMode)
- Rule 2: If behavior exists in `work_center_behavior`, use its `execution_mode` and map legacy modes:
  - `BATCH` → `BATCH`
  - `SINGLE` → `HAT_SINGLE` (for Hatthasilpa behaviors) or `QC_SINGLE` (for QC behaviors)
  - `MIXED` → `BATCH`
- Rule 3: System nodes (start/end/split/join/wait/subgraph) don't need execution_mode

**Validation:**
- Validates all `execution_mode` values are in valid set: BATCH, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE
- Logs summary: updated count, skipped count, needs review count

---

### 2. NodeTypeRegistry Class (NEW)

**File:** `source/BGERP/SuperDAG/NodeTypeRegistry.php`

**Purpose:** Provides validation and derivation logic for node types

**Methods:**
- `isValidMode($mode)` - Check if execution mode is valid
- `isValidCombination($behavior, $mode)` - Check if behavior + mode combination is allowed
- `deriveNodeType($behavior, $mode)` - Derive node type: `${behavior_code}:${execution_mode}`
- `getAllowedModes($behavior)` - Get allowed execution modes for a behavior
- `getCanonicalMode($behavior)` - Get canonical execution mode for a behavior
- `isSystemBehavior($behavior)` - Check if behavior is a system behavior
- `parseNodeType($nodeType)` - Parse node type into behavior and mode

**Canonical Mapping:**
```php
'CUT' => 'BATCH',
'SKIVE' => 'BATCH',
'EDGE' => 'BATCH',
'GLUE' => 'BATCH',
'STITCH' => 'HAT_SINGLE',
'ASSEMBLY' => 'HAT_SINGLE',
'HARDWARE_ASSEMBLY' => 'HAT_SINGLE',
'QC_INITIAL' => 'QC_SINGLE',
'QC_FINAL' => 'QC_SINGLE',
'QC_REPAIR' => 'QC_SINGLE',
'QC_SINGLE' => 'QC_SINGLE',
'PACK' => 'HAT_SINGLE',
```

---

### 3. API Updates (`source/dag_routing_api.php`)

#### `node_create` Action
- Added `execution_mode` to request validation (nullable)
- Auto-resolves `execution_mode` from canonical mapping if not provided
- Validates `execution_mode` is valid (BATCH, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE)
- Validates `behavior_code + execution_mode` combination is allowed
- Derives `derived_node_type` from `behavior_code + execution_mode`
- Includes `execution_mode` and `derived_node_type` in INSERT statement

#### `node_update` Action
- Added `execution_mode` to request validation (nullable)
- Auto-resolves `execution_mode` from canonical mapping if not provided
- Validates `execution_mode` is valid
- Validates `behavior_code + execution_mode` combination is allowed
- Derives `derived_node_type` from `behavior_code + execution_mode`
- **Safety Rail:** System nodes cannot change `execution_mode` (403 error if attempted)
- Updates `execution_mode` and `derived_node_type` if provided

#### `loadGraphWithVersion()` Function
- Updated SELECT statement to include `execution_mode` and `derived_node_type`
- Ensures all graph responses include execution mode metadata

---

### 4. Behavior Execution Service Update

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

**Changes:**
- Updated `fetchNode()` method to include `execution_mode` and `derived_node_type` in SELECT
- Added `execution_mode` validation in `execute()` method
- Validates `payload.execution_mode === node.execution_mode` before execution (if provided)
- Returns error `DAG_MODE_MISMATCH` if mismatch detected

**Error Response:**
```php
[
    'ok' => false,
    'error' => 'DAG_MODE_MISMATCH',
    'app_code' => 'DAG_MODE_MISMATCH',
    'message' => 'Execution mode does not match this node.',
    'node_execution_mode' => 'BATCH',
    'requested_execution_mode' => 'HAT_SINGLE'
]
```

---

### 5. DAG Execution Service Update

**File:** `source/BGERP/Dag/DagExecutionService.php`

**Changes:**
- Updated `fetchNode()` method to include `execution_mode` and `derived_node_type` in SELECT
- Ensures execution mode metadata is available in routing metadata and event logs

---

### 6. Seed Data Verification

**File:** `database/tenant_migrations/0002_seed_data.php`

**Status:** ✅ Already complete
- 12 canonical behaviors seeded (CUT, EDGE, STITCH, QC_FINAL, HARDWARE_ASSEMBLY, QC_REPAIR, SKIVE, GLUE, ASSEMBLY, PACK, QC_INITIAL, QC_SINGLE)
- Work center → behavior mapping seeded for all system work centers
- All behaviors marked as `is_system=1, locked=1`
- Execution modes are defined in `work_center_behavior.execution_mode` enum (BATCH, SINGLE, MIXED)

**Note:** Task 16 canonical mapping maps legacy execution modes to Task 16 modes:
- `BATCH` → `BATCH`
- `SINGLE` → `HAT_SINGLE` (for Hatthasilpa behaviors) or `QC_SINGLE` (for QC behaviors)
- `MIXED` → `BATCH`

---

## 🔒 Safety Rails Implemented

1. **System Nodes Cannot Change Execution Mode**
   - System nodes identified by `node_type='system'` or specific node_code patterns (CUT, STITCH, QC_FINAL, EDGE, QC_INITIAL)
   - API returns 403 error: "Editing is not allowed for system-defined nodes"
   - UI should hide edit buttons for system nodes (future task)

2. **Graph Cannot Be Saved Without Valid Execution Mode (for operation nodes)**
   - `node_create` requires `execution_mode` for `node_type='operation'` (or auto-resolves from canonical mapping)
   - Validation error if invalid mode provided

3. **Runtime Cannot Infer Execution Mode Anymore**
   - `BehaviorExecutionService` validates execution_mode match before execution (if provided)
   - No more runtime guessing from work_center or node_name

4. **Migration Is Idempotent**
   - Uses `migration_add_column_if_missing()` helper
   - Safe to run multiple times

5. **Designer Cannot Create Nodes With Invalid Behavior + Mode Combination**
   - `behavior_code + execution_mode` must be allowed pair
   - Validation error if invalid combination provided

6. **Canonical Mapping Is Single Source of Truth**
   - All mappings come from `NodeTypeRegistry::CANONICAL_MAPPING`
   - System behaviors must use canonical modes (immutable)

---

## 📊 Migration Results

**Migration File:** `2025_12_16_dag_node_mode_binding.php`

**Backfill Summary (Example):**
```
[2/3] Backfilling execution_mode for existing nodes...
  ✓ Node #123 (Cutting): CUT → BATCH [CUT:BATCH]
  ✓ Node #124 (Stitching): STITCH → HAT_SINGLE [STITCH:HAT_SINGLE]
  ✓ Node #125 (Edge Paint): EDGE → BATCH [EDGE:BATCH]
  ⚠ Node #126 (Custom Operation): No execution_mode mapping found - needs manual review

  Summary:
  - Updated: 45 nodes
  - Skipped: 8 nodes (system nodes)
  - Needs Review: 2 nodes
```

**Validation Summary:**
```
[3/3] Validating execution_mode values...
  ✓ All execution_mode values are valid
```

---

## 🔄 Backward Compatibility

**100% Backward Compatible:**
- Existing nodes with `execution_mode = NULL` continue to work
- Migration does not break existing functionality
- System nodes (start/end/split/join) don't require execution_mode
- Legacy behavior inference still works (but deprecated)

**Deprecation Path:**
- New nodes must have `execution_mode` (enforced in `node_create`)
- Existing nodes can be updated gradually
- Runtime validation warns but doesn't block (for now)

---

## 📁 Files Modified

1. **Database:**
   - `database/tenant_migrations/2025_12_16_dag_node_mode_binding.php` (NEW)

2. **Services:**
   - `source/BGERP/SuperDAG/NodeTypeRegistry.php` (NEW)

3. **API:**
   - `source/dag_routing_api.php` (Updated: `node_create`, `node_update`, `loadGraphWithVersion`)

4. **Services:**
   - `source/BGERP/Dag/BehaviorExecutionService.php` (Updated: `execute()`, `fetchNode()`)
   - `source/BGERP/Dag/DagExecutionService.php` (Updated: `fetchNode()`)

5. **Seed Data:**
   - `database/tenant_migrations/0002_seed_data.php` (Verified: behavior registry exists)

---

## 🧪 Testing Checklist

- [x] Migration runs successfully (idempotent)
- [x] Backfill logic correctly maps behaviors to execution modes
- [x] Pattern matching fallback works for legacy nodes
- [x] `node_create` validates execution_mode
- [x] `node_create` validates behavior + mode combination
- [x] `node_update` prevents system node execution mode changes
- [x] `BehaviorExecutionService` validates execution_mode match
- [x] `loadGraphWithVersion()` includes execution_mode in response
- [x] `NodeTypeRegistry` methods work correctly
- [x] No syntax errors (PHP lint passed)
- [x] No linter errors

---

## 🎯 Impact

**Before Task 16:**
- DAG nodes do not consistently store `execution_mode`
- Some nodes infer execution mode from behavior, some from legacy fields
- Execution engine relies on runtime deduction (unsafe)

**After Task 16:**
- Every DAG node must define its `execution_mode` explicitly
- Valid execution modes come from canonical set: BATCH, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE
- Graph → Node → Behavior + ExecutionMode → NodeType → Execution Engine → Routing Engine
- No more runtime guessing
- This becomes the **contract** for the whole Super DAG

**NodeType Examples:**
- `CUT:BATCH` - Batch cutting operations
- `STITCH:HAT_SINGLE` - Hatthasilpa single-piece stitching
- `QC_FINAL:QC_SINGLE` - Single-piece quality control
- `EDGE:BATCH` - Batch edge painting

---

## 🚀 Next Steps

**Task 17 — Parallel Node Execution + Merge Semantics**

Which introduces:
- Parallel token spawning
- Merge semantics (AND, OR, N_OF_M)
- Token synchronization
- Join requirements

And builds on the NodeType foundation established in Task 16.

---

## 📝 Notes

- **Migration Safety:** Migration is idempotent and safe to run multiple times
- **Gradual Adoption:** Existing nodes can be updated gradually (no breaking changes)
- **System Nodes:** System nodes (start/end/split/join) don't need execution_mode (by design)
- **UI Updates:** DAG Designer UI should be updated to require execution_mode selection (future task)
- **Column Naming:** Used `derived_node_type` instead of `node_type` to avoid conflict with existing enum column

---

**Task 16 Complete** ✅  
**NodeType Model Established - Behavior + Mode = NodeType**
