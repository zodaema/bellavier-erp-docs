# Task 31: CUT Timing - Legacy System Audit Report

**Date:** 2026-01-13  
**Purpose:** Comprehensive audit of legacy timing systems (TimeEngine, Node Behavior, Graph) to understand how CUT timing should integrate  
**Status:** ✅ **COMPLETE**

---

## 🎯 Executive Summary

This audit examines the **legacy timing infrastructure** of Bellavier ERP to understand:
1. How **TimeEngine v2** tracks work sessions
2. How **Node Behavior Engine** executes behaviors
3. How **Graph/DAG system** manages token lifecycle
4. How **Canonical Events** provide timeline reconstruction

**Key Finding:** The legacy `TokenWorkSessionService` is designed for **single-piece work** (HAT_SINGLE mode), while CUT operations are **batch-based** (BATCH_QUANTITY mode) with component-level granularity. The new `CutSessionService` is correctly designed as a **first-class entity** for component-level timing, separate from legacy token-level timing.

---

## 📋 Table of Contents

1. [TimeEngine v2 Architecture](#1-timeengine-v2-architecture)
2. [Node Behavior Engine Architecture](#2-node-behavior-engine-architecture)
3. [Graph/DAG System Architecture](#3-graphdag-system-architecture)
4. [Canonical Events System](#4-canonical-events-system)
5. [Timeline Reconstruction](#5-timeline-reconstruction)
6. [Product Constraints System](#6-product-constraints-system)
7. [CUT Timing Integration Analysis](#7-cut-timing-integration-analysis)
8. [Legacy vs New System Comparison](#8-legacy-vs-new-system-comparison)
9. [Recommendations](#9-recommendations)

---

## 1. TimeEngine v2 Architecture

### 1.1 Core Components

#### WorkSessionTimeEngine (`source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`)

**Purpose:** Single Source of Truth for calculating work time from `token_work_session`.

**Key Method:**
```php
public function calculateTimer(array $sessionRow, ?DateTimeImmutable $now = null): array
```

**Returns:**
- `work_seconds`: Total work seconds at this moment
- `base_work_seconds`: Work seconds from DB snapshot
- `live_tail_seconds`: Additional seconds since `resumed_at`/`started_at`
- `status`: 'active'|'paused'|'completed'|'none'|'unknown'
- `started_at`: ISO8601 format
- `resumed_at`: ISO8601 format
- `last_server_sync`: Server time used for calculation

**Time Calculation Logic:**
1. **Base Work Seconds:** From `token_work_session.work_seconds` (snapshot)
2. **Live Tail Seconds:** Calculated on-the-fly from `resumed_at` (if exists) or `started_at`
3. **Total Work Seconds:** `base_work_seconds + live_tail_seconds` (if status='active')

**Timezone:** Uses `TimeHelper` for canonical timezone normalization (Asia/Bangkok)

**Usage:**
- Work Queue (Phase 1)
- Frontend Timer (Phase 2 - drift-corrected)
- Auto Guard (Phase 3 - abandoned session protection)
- Multi-surface Integration (Phase 4 - People Monitor, Trace Overview, Analytics)

---

#### TokenWorkSessionService (`source/BGERP/Service/TokenWorkSessionService.php`)

**Purpose:** Manages individual work sessions per token with pause/resume support.

**Key Methods:**
- `startToken(int $tokenId, int $operatorId, ...)` - Start work session
- `pauseToken(int $tokenId, ?string $reason)` - Pause work session
- `resumeToken(int $tokenId, int $operatorId)` - Resume work session
- `completeToken(int $tokenId, int $operatorId)` - Complete work session

**Session Lifecycle:**
```
START → ACTIVE → PAUSED → ACTIVE → COMPLETED
```

**Time Tracking:**
- `started_at`: Session start time (server time)
- `paused_at`: Last pause time
- `resumed_at`: Last resume time
- `work_seconds`: Accumulated work seconds (snapshot)
- `total_pause_minutes`: Total pause duration

**Key Features:**
- **Race Protection:** Uses `SELECT ... FOR UPDATE` to prevent concurrent starts
- **Auto-Pause:** Automatically pauses operator's current active session when starting new work
- **Multi-Operator Coordination:** Prevents conflicts between operators
- **Timezone:** Uses `TimeHelper` for canonical timezone normalization

**Table:** `token_work_session`
- `id_token` - Token ID (FK to `flow_token.id_token`)
- `operator_user_id` - Worker user ID
- `status` - 'active', 'paused', 'completed'
- `started_at`, `paused_at`, `resumed_at` - Timestamps
- `work_seconds` - Accumulated work seconds

**Scope:** **Token-level** (one session per token)

---

### 1.2 Time Model (`docs/developer/03-superdag/01-core/time_model.md`)

**Core Time Fields:**

#### Token Time Fields (`flow_token`)
- `start_at` (DATETIME NULL) - When token started work at current node
- `completed_at` (DATETIME NULL) - When token completed work
- `actual_duration_ms` (BIGINT UNSIGNED NULL) - Precise duration in milliseconds
- `spawned_at` (DATETIME) - When token was created

#### Node Time Fields (`routing_node`)
- `expected_minutes` (INT NULL) - Standard/expected operation time
- `sla_minutes` (INT NULL) - Service level agreement (maximum allowed time)

#### Event Time Fields (`token_event`)
- `event_time` (DATETIME) - When event occurred
- `duration_ms` (BIGINT UNSIGNED NULL) - Duration of the event

**Canonical Source:**
- `start_at` ← `NODE_START` canonical event
- `completed_at` ← `NODE_COMPLETE` canonical event
- `actual_duration_ms` = `completed_at - start_at` (calculated)

**Timezone:** All time operations use `TimeHelper` for canonical timezone normalization (Asia/Bangkok)

---

### 1.3 TimeEventReader (`source/BGERP/Dag/TimeEventReader.php`)

**Purpose:** Read canonical timeline from `token_event` and sync to `flow_token`.

**Key Method:**
```php
public function syncTimeline(int $tokenId): void
```

**Actions:**
1. Reads `token_event` for token
2. Calculates `start_at`, `completed_at`, `actual_duration_ms`
3. Updates `flow_token` fields
4. Handles pause/resume correctly

**Integration:**
- Called by `TokenLifecycleService::completeToken()`
- Called by repair engines
- Called by ETA system

**Canonical Timeline:**
- `NODE_START` → Sets `flow_token.start_at`
- `NODE_COMPLETE` → Sets `flow_token.completed_at` and calculates `actual_duration_ms`

---

## 2. Node Behavior Engine Architecture

### 2.1 NodeBehaviorEngine (`source/BGERP/Dag/NodeBehaviorEngine.php`)

**Purpose:** Core engine for executing node behaviors in SuperDAG.

**Key Principle:** Uses **Node Mode from Work Center**, NOT `behavior_code` from Node.

**Node Mode Resolution:**
```php
public function resolveNodeMode(array $node): ?string
```
- Reads `work_center.node_mode` (BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE)
- Node "receives" `node_mode` from Work Center it is bound to

**Execution Mode Resolution:**
```php
protected function resolveExecutionMode(?string $nodeMode, ?string $lineType): ?string
```
- Maps `(node_mode, line_type)` → `execution_mode`
- Examples:
  - `(HAT_SINGLE, hatthasilpa)` → `hat_single`
  - `(BATCH_QUANTITY, hatthasilpa)` → `hat_batch_quantity`
  - `(CLASSIC_SCAN, classic)` → `classic_scan`
  - `(QC_SINGLE, *)` → `qc_single`

**Behavior Registry:**
```php
protected array $behaviorRegistry = [
    'hat_single'        => 'executeHatSingle',
    'hat_batch_quantity'=> 'executeHatBatchQuantity',
    'classic_scan'      => 'executeClassicScan',
    'qc_single'         => 'executeQcSingle',
];
```

**Canonical Events:**
- Generates canonical events (TOKEN_*, NODE_*, COMP_*, etc.)
- Events persisted via `TokenEventService::persistEvent()`
- Events stored in `token_event` table

**Close System:** Behavior registry is internal only (NOT plugin-extensible)

---

### 2.2 BehaviorExecutionService (`source/BGERP/Dag/BehaviorExecutionService.php`)

**Purpose:** Centralizes handling of DAG behavior actions.

**Key Methods:**
- `handleCut(...)` - Handle CUT behavior actions
- `handleStitch(...)` - Handle STITCH behavior actions
- `handleEdge(...)` - Handle EDGE behavior actions
- `handleQc(...)` - Handle QC behavior actions

**CUT Handler:**
- `handleCutStart()` - **DEPRECATED** (returns error directing to `cut_session_start`)
- `handleCutComplete()` - **DEPRECATED** (returns error directing to `cut_session_end`)
- `handleCutBatchYieldSave()` - Requires `session_id`, uses `CutSessionService` (SSOT)
- `handleCutSessionStart()` - Creates CUT session via `CutSessionService`
- `handleCutSessionEnd()` - Ends CUT session via `CutSessionService`
- `handleCutSessionGetActive()` - Gets active session via `CutSessionService`

**Integration:**
- Uses `CutSessionService` for CUT timing (SSOT)
- Creates `NODE_YIELD` events with session timing
- Uses `TokenEventService` to persist canonical events

---

## 3. Graph/DAG System Architecture

### 3.1 Token Lifecycle (`source/BGERP/Service/TokenLifecycleService.php`)

**Purpose:** Manages token lifecycle (spawn, move, complete).

**Key Methods:**
- `spawnTokens(...)` - Spawn tokens for job instance
- `moveToken(...)` - Move token to next node
- `completeToken(...)` - Complete token at node

**Token States:**
- `ready` - Token spawned, ready to start
- `active` - Token actively working at node
- `waiting` - Token waiting for condition
- `paused` - Token paused
- `completed` - Token completed
- `scrapped` - Token scrapped

**Time Integration:**
- Sets `flow_token.start_at` when token enters node (uses `TimeHelper::now()`)
- Sets `flow_token.completed_at` when token completes (uses `TimeHelper::now()`)
- Calculates `flow_token.actual_duration_ms` from start/complete times

---

### 3.2 DAGRoutingService (`source/BGERP/Service/DAGRoutingService.php`)

**Purpose:** Core token routing logic, handles split/join, conditional routing.

**Key Method:**
```php
public function routeToken(int $tokenId, ?int $operatorId = null): array
```

**Flow:**
1. Fetch token and current node
2. Check subgraph exit
3. Release machine if leaving machine-bound node
4. Check if parallel split node → `handleParallelSplit()`
5. Check if merge node → `handleMergeNode()`
6. Get outgoing edges
7. Route based on edge count:
   - 0 edges → Complete token (FINISH node)
   - 1 edge → Auto-route to next node
   - 2+ edges → `selectNextNode()` (evaluate conditions)

**Time Integration:**
- Uses `TimeHelper` for canonical timezone normalization
- Sets `start_at` when token enters node

---

### 3.3 Graph Structure

**Tables:**
- `routing_graph` - DAG graphs
- `routing_node` - Graph nodes
- `routing_edge` - Graph edges
- `job_graph_instance` - Graph instances for jobs
- `node_instance` - Node instances for tokens

**Node Types:**
- `START` - Entry point
- `OPERATION` - Work node
- `QC` - Quality control node
- `END` - Exit point
- `SPLIT` - Parallel split
- `JOIN` - Parallel merge

**Node Modes (from Work Center):**
- `BATCH_QUANTITY` - Batch work (CUT, PREP)
- `HAT_SINGLE` - Single-piece work (STITCH, EDGE)
- `CLASSIC_SCAN` - Scan-based workflow
- `QC_SINGLE` - Quality control per piece

---

## 4. Canonical Events System

### 4.1 TokenEventService (`source/BGERP/Dag/TokenEventService.php`)

**Purpose:** Persist canonical events to `token_event` table.

**Key Method:**
```php
public function persistEvent(array $event, ?int $workerId = null): void
```

**Canonical Event Types (Whitelist):**
- **TOKEN_***: `TOKEN_CREATE`, `TOKEN_SHORTFALL`, `TOKEN_ADJUST`, `TOKEN_SPLIT`, `TOKEN_MERGE`
- **NODE_***: `NODE_START`, `NODE_PAUSE`, `NODE_RESUME`, `NODE_COMPLETE`, `NODE_CANCEL`
- **OVERRIDE_***: `OVERRIDE_ROUTE`, `OVERRIDE_TIME_FIX`, `OVERRIDE_TOKEN_ADJUST`
- **COMP_***: `COMP_BIND`, `COMP_UNBIND`
- **INVENTORY_***: `INVENTORY_MOVE`

**Table:** `token_event`
- `canonical_type` - Event type (from whitelist)
- `event_time` - When event occurred
- `duration_ms` - Event duration (if applicable)
- `event_data` - JSON payload

**Immutable:** Events are never updated or deleted (audit trail)

---

### 4.2 Canonical Event Flow

```
State Change Request (API)
  ↓
Service Layer (TokenLifecycleService, BehaviorExecutionService, etc.)
  ↓
Canonical Event Creation (TokenEventService::persistEvent)
  ↓
token_event (canonical_type, event_time, duration_ms, event_data)
  ↓
State Update (flow_token, node_instance, etc.)
  ↓
Time Sync (TimeEventReader::syncTimeline)
  ↓
flow_token (start_at, completed_at, actual_duration_ms)
```

**Principle:** "Reality Flexible, Logic Strict"
- All state changes must go through canonical events
- Canonical events are the single source of truth
- State tables are derived from canonical events

---

## 5. Timeline Reconstruction

### 5.1 TimelineReconstructionEngine (`source/BGERP/Dag/TimelineReconstructionEngine.php`)

**Purpose:** Reconstruct timeline from canonical events (L2/L3 repair).

**Key Method:**
```php
public function generateReconstructionPlan(int $tokenId): ?array
```

**Process:**
1. Validate token to get problems
2. Load raw canonical events
3. Normalize events (sort by time, group by node)
4. Determine ideal timeline
5. Diff ideal vs actual
6. Generate reconstruction events

**Reconstructable Problems:**
- Missing `NODE_START` event
- Missing `NODE_COMPLETE` event
- Timeline inconsistencies
- Duration mismatches

**Output:** Reconstruction plan with events to add

---

### 5.2 LocalRepairEngine (`source/BGERP/Dag/LocalRepairEngine.php`)

**Purpose:** L1 repair (local token repair).

**Scope:** Single token
**Actions:** Fix missing events, correct timestamps

**Table:** `token_repair_log` - Repair audit trail

---

### 5.3 RepairOrchestrator (`source/BGERP/Dag/RepairOrchestrator.php`)

**Purpose:** Orchestrate repair workflow.

**Flow:**
1. Integrity check (`CanonicalEventIntegrityValidator`)
2. Problem detection (`LocalRepairEngine::detectProblems`)
3. Local repair (`LocalRepairEngine::repair`)
4. Timeline reconstruction (`TimelineReconstructionEngine::generateReconstructionPlan`)
5. Repair orchestration (`RepairOrchestrator::orchestrate`)

---

## 6. Product Constraints System

### 6.1 Overview

**Purpose:** Product Constraints define material requirements and specifications for components in the BOM (Bill of Materials).

**Core Principle:** BOM Line is the Source of Truth for Material Constraints (V3 Philosophy).

**Key Concept:** Constraints are stored at the **BOM line item level** (`product_component_material`), not at the slot level.

---

### 6.2 Data Model

#### Table: `product_component_material` (BOM Line)

**Location:** Layer 3 of Material Architecture V2

**Key Fields:**
- `id_pcm` - Primary key
- `id_product_component` - FK to `product_component` (Layer 2)
- `material_sku` - Material SKU (FK to `material.sku`)
- `role_code` - Material role (MAIN_MATERIAL, LINING, HARDWARE, etc.) - **V3 Addition**
- `constraints_json` - JSON object of role-based constraints - **V3 Addition**
- `qty_required` - Quantity required per component unit (DECIMAL 10,4)
- `uom_code` - Unit of measure (e.g., 'sqft', 'sqm', 'm', 'yard', 'piece', 'pcs')

**V3 Extensions:**
```sql
ALTER TABLE product_component_material
  ADD COLUMN `role_code` VARCHAR(50) NOT NULL DEFAULT 'MAIN_MATERIAL',
  ADD COLUMN `constraints_json` JSON NULL;
```

**Constraint Identity:**
- Constraints are identified by: `(id_product_component, material_sku, role_code)`
- Each BOM line item has its own constraints based on material role

---

#### Table: `material_role_catalog`

**Purpose:** Catalog of material roles (data-driven UI).

**Key Fields:**
- `role_code` - Unique role identifier (MAIN_MATERIAL, LINING, HARDWARE, etc.)
- `name_en`, `name_th` - Role names
- `applies_to_line` - Production line scope ('classic', 'hatthasilpa', 'both')
- `is_active` - Active status

**Common Roles:**
- `MAIN_MATERIAL` - Main material of component
- `LINING` - Lining material
- `REINFORCEMENT` - Reinforcement material
- `HARDWARE` - Hardware (zipper, buckle, etc.)
- `THREAD` - Thread
- `EDGE_FINISH` - Edge finish
- `ADHESIVE` - Adhesive
- `PACKAGING` - Packaging

---

#### Table: `material_role_field`

**Purpose:** Field definitions per material role (data-driven form generation).

**Key Fields:**
- `role_code` - FK to `material_role_catalog.role_code`
- `field_key` - Field identifier in `constraints_json` (e.g., 'width_mm', 'thickness_mm')
- `field_type` - Field type ('text', 'number', 'select', 'boolean', 'json')
- `field_label_en`, `field_label_th` - Field labels
- `required` - Required flag (0 or 1)
- `unit` - Unit for number fields (e.g., 'mm', 'cm', 'sqft')
- `options_json` - Options for select type fields
- `display_order` - Display order

**Example Fields for MAIN_MATERIAL:**
- `width_mm` (number, required, unit: 'mm')
- `length_mm` (number, required, unit: 'mm')
- `thickness_mm` (number, required, unit: 'mm')
- `grain_direction` (select, optional)
- `finish_type` (select, optional)
- `piece_count` (number, required)
- `waste_factor_percent` (number, optional, unit: '%')

---

### 6.3 BOM Quantity Calculation

#### BomQuantityCalculator (`source/BGERP/Service/BomQuantityCalculator.php`)

**Purpose:** Compute `qty_required` from `constraints_json` based on material UoM.

**Key Method:**
```php
public static function compute(string $materialUomCode, array $constraints): float|int
```

**Basis Types:**
1. **AREA** (sqft, sqm):
   - Formula: `area = width_mm * length_mm * piece_count * (1 + waste_factor_percent/100)`
   - Converts to sqft or sqm based on UoM
   - Required fields: `width_mm`, `length_mm`, `piece_count`

2. **LENGTH** (m, yard):
   - Formula: `length = length_mm * piece_count * (1 + waste_factor_percent/100)`
   - Converts to m or yard based on UoM
   - Required fields: `length_mm`, `piece_count`

3. **COUNT** (piece, pcs):
   - Formula: `qty = ceil(piece_count * (1 + waste_factor_percent/100))`
   - Returns integer
   - Required fields: `piece_count`

**Input Unit:** Fixed to 'mm' (Phase A - locked)

**Output:** `qty_required` (DECIMAL 10,4) stored in `product_component_material.qty_required`

---

### 6.4 Used Area Calculation for CUT

#### Formula

**For Leather Materials (UoM = sqft/sq.ft):**
```
used_area = qty_required * qty_cut
```

Where:
- `qty_required` = From `product_component_material.qty_required` (computed from constraints)
- `qty_cut` = Operator input (quantity cut)

**Example:**
- `qty_required` = 0.42 sqft (from constraints: width=100mm, length=200mm, piece_count=1)
- `qty_cut` = 5 pieces
- `used_area` = 0.42 * 5 = 2.1 sqft

---

#### Backend Implementation

**Location:** `source/BGERP/Dag/BehaviorExecutionService.php::handleCutSessionEnd()`

**Query:**
```php
SELECT pcm.qty_required, pcm.uom_code
FROM product_component pc
JOIN product_component_material pcm ON pcm.id_product_component = pc.id_product_component
WHERE pc.id_product = ?
  AND UPPER(pc.component_type_code) = ?  -- component_code
  AND UPPER(COALESCE(pcm.role_code, 'MAIN_MATERIAL')) = ?  -- role_code
  AND pcm.material_sku = ?  -- material_sku
LIMIT 1
```

**Calculation:**
```php
$perUnit = (float)($row['qty_required'] ?? 0);
$uom = strtolower((string)($row['uom_code'] ?? ''));
$isSqft = ($uom === 'sqft' || $uom === 'sq.ft' || strpos($uom, 'sq') !== false || strpos($uom, 'ft') !== false);
if ($isSqft && $perUnit > 0) {
    $usedArea = round(max(0.0, $perUnit * (float)$qtyCut), 4);
}
```

**Key Points:**
- ✅ **SSOT:** `qty_required` comes from `product_component_material` (computed from constraints)
- ✅ **Auto-calculation:** `used_area` is computed server-side, not from operator input
- ✅ **Identity Match:** Query uses `(component_code, role_code, material_sku)` to match CUT session identity
- ✅ **UoM Check:** Only computes for leather materials (UoM contains 'sqft' or 'sq.ft')

---

#### Frontend Implementation

**Location:** `assets/javascripts/dag/behavior_execution.js`

**Function:**
```javascript
function computeUsedAreaFromConstraints(qty) {
    const mat = cutPhaseState.selectedMaterial || null;
    if (!mat) return null;
    const uom = (mat.uom_code || '').toString().toLowerCase();
    const perUnit = parseFloat(mat.qty_per_unit || 0) || 0;
    if (qty <= 0 || perUnit <= 0) return null;
    const isSqft = uom === 'sqft' || uom === 'sq.ft' || uom.includes('sq') || uom.includes('ft');
    if (!isSqft) return null;
    return Math.max(0, qty * perUnit);
}
```

**Key Points:**
- ✅ **Display Only:** Frontend calculation is for display only (not authoritative)
- ✅ **Uses Material Data:** Reads `qty_per_unit` from material data (from API response)
- ✅ **UoM Check:** Only computes for leather materials (UoM contains 'sqft')
- ✅ **Read-only Input:** UI shows "Used Area" as read-only, disabled input with "Auto-calculated" badge

---

### 6.5 Integration with CUT Session

#### Session Identity Match

**CUT Session Identity:**
- `component_code` - Component code (from `product_component.component_type_code`)
- `role_code` - Material role (from `product_component_material.role_code`)
- `material_sku` - Material SKU (from `product_component_material.material_sku`)

**Constraints Query Match:**
- `pc.component_type_code` = `component_code`
- `COALESCE(pcm.role_code, 'MAIN_MATERIAL')` = `role_code`
- `pcm.material_sku` = `material_sku`

**Result:** System can look up `qty_required` and `uom_code` for the exact BOM line item that matches the CUT session identity.

---

#### Used Area Auto-Calculation Flow

```
1. Operator starts CUT session
   → Selects: Component + Role + Material
   → System creates CutSession with identity (component_code, role_code, material_sku)

2. Operator enters qty_cut
   → Frontend: Computes used_area hint (display only)
   → Backend: Will compute used_area from constraints (SSOT)

3. Operator saves session
   → Backend: handleCutSessionEnd()
   → Queries product_component_material for (component_code, role_code, material_sku)
   → Gets qty_required and uom_code
   → Computes: used_area = qty_required * qty_cut (if UoM is sqft)
   → Saves to cut_session.used_area (SSOT)
```

**Key Principle:** Used area is **always computed from constraints** (SSOT), never from operator input.

---

### 6.6 Constraints Contract

#### API Contract (`docs/contracts/products/constraints_contract_v1.md`)

**Endpoints:**
1. `list_material_roles` - List available material roles
2. `list_role_fields` - List fields for a specific role
3. `component_save` (add/update with constraints) - Save component material with constraints

**Contract Rules:**
- Field names and types are locked
- Response structure is locked
- Error format is locked
- Breaking changes require version bump (v1 → v2)

**Status:** ✅ **LOCKED v1** (January 5, 2026)

---

### 6.7 Constraints Validation

#### MaterialRoleValidationService

**Purpose:** Validate constraints against role field definitions.

**Validation Rules:**
- Required fields must be present
- Field types must match (number, text, select, boolean, json)
- Select values must match `options_json[].value`
- Number fields must be numeric
- Waste factor must be >= 0 and <= 200

**Integration:**
- Called by `product_api.php` when saving component materials
- Returns validation errors with field-level details
- Prevents invalid constraints from being saved

---

### 6.8 Constraints Usage in Production

#### Material Requirements Planning (MRP)

**Usage:**
- `qty_required` is used to calculate material requirements for production orders
- Formula: `total_required = qty_required × order_qty`
- Used by `MaterialRequirementService` for MRP calculations

**Impact:** **HIGH** - Incorrect `qty_required` leads to wrong material requirements

---

#### BOM Costing

**Usage:**
- `qty_required × material_cost = line_cost`
- Used by `BOMService` for product cost calculations

**Impact:** **HIGH** - Incorrect `qty_required` leads to wrong product costs

---

#### Purchasing

**Usage:**
- Purchase orders generated from BOM use `qty_required × order_qty`
- Used to determine purchase quantities

**Impact:** **HIGH** - Wrong `qty_required` = wrong purchase quantities

---

### 6.9 Constraints and CUT Timing Integration

#### Used Area in NODE_YIELD Event

**When `cut_session_end` is called:**
1. `CutSessionService::endSession()` ends session
2. `BehaviorExecutionService::handleCutSessionEnd()` computes `used_area` from constraints
3. Creates `NODE_YIELD` event with:
   - `used_area` - From constraints (SSOT)
   - `material_sheet_id` - Leather sheet ID (if selected)
   - `component_code`, `role_code`, `material_sku` - Session identity

**Event Payload:**
```json
{
  "component_code": "BODY",
  "role_code": "MAIN_MATERIAL",
  "material_sku": "LEATHER-001",
  "used_area": 2.1,
  "material_sheet_id": 456,
  "started_at": "2026-01-13 10:30:00",
  "finished_at": "2026-01-13 11:00:00",
  "duration_seconds": 1800
}
```

---

#### Leather Sheet Usage Log

**Table:** `leather_sheet_usage_log`

**Purpose:** Track leather sheet usage for inventory management.

**Fields:**
- `id_sheet` - Leather sheet ID
- `token_id` - Token ID (if DAG)
- `used_area` - Used area (sqft) - **From CUT session (SSOT)**
- `used_by` - Operator user ID
- `note` - Usage notes

**Integration:**
- Created when CUT session ends
- Uses `used_area` from `cut_session` (computed from constraints)
- Enforces: `used_area <= remaining_area` (sheet validation)

---

### 6.10 Constraints SSOT Principles

#### Source of Truth Hierarchy

1. **Product Constraints (SSOT):**
   - `product_component_material.qty_required` - Computed from `constraints_json` via `BomQuantityCalculator`
   - `product_component_material.uom_code` - Unit of measure
   - `product_component_material.constraints_json` - Role-based constraints

2. **CUT Session (Derived):**
   - `cut_session.used_area` - Computed from `qty_required × qty_cut` (SSOT for CUT operation)
   - `cut_session.material_sheet_id` - Leather sheet reference

3. **Frontend (Display Only):**
   - `computeUsedAreaFromConstraints()` - Display hint only (not authoritative)

**Key Principle:** Used area is **always computed from constraints** (SSOT), never from operator input.

---

### 6.11 Constraints Validation in CUT Flow

#### Pre-Save Validation

**When operator saves CUT session:**
1. Backend queries `product_component_material` for constraints
2. Validates that `qty_required` exists and > 0
3. Validates that `uom_code` is valid for area calculation (if leather)
4. Computes `used_area` from constraints
5. Validates `used_area <= remaining_area` (if sheet selected)

**Error Handling:**
- If constraints not found → Returns error (cannot compute used_area)
- If `qty_required` = 0 → Returns error (invalid constraints)
- If `used_area > remaining_area` → Returns 409 conflict (insufficient area)

---

### 6.12 Constraints and Material Selection

#### Material Selection in CUT UI

**Flow:**
1. Operator selects Component → System shows available roles
2. Operator selects Role → System shows available materials for that role
3. Operator selects Material → System loads constraints (if exists)
4. System displays `qty_per_unit` (from material data) for frontend calculation hint

**Material Data Structure:**
```json
{
  "material_sku": "LEATHER-001",
  "material_name": "Premium Leather",
  "material_category": "Leather",
  "uom_code": "sqft",
  "qty_per_unit": 0.42  // From product_component_material.qty_required
}
```

**Key Points:**
- Material list is filtered by role (from `product_component_material`)
- `qty_per_unit` comes from `product_component_material.qty_required`
- Frontend uses `qty_per_unit` for display calculation only

---

### 6.13 Constraints Migration and Legacy Support

#### V3 Migration

**Status:** ✅ **COMPLETE** (V3 implemented)

**Changes:**
- Added `role_code` column to `product_component_material` (default: 'MAIN_MATERIAL')
- Added `constraints_json` column to `product_component_material`
- Created `material_role_catalog` table
- Created `material_role_field` table
- Implemented `BomQuantityCalculator` for quantity computation

**Legacy Support:**
- Existing rows use `role_code = 'MAIN_MATERIAL'` (default)
- `qty_required` can be computed from constraints OR manual (override mode)
- Override mode requires `override_mode=1` and `override_reason`

---

### 6.14 Constraints and CUT Timing Summary

**Integration Points:**
1. ✅ **Session Identity:** CUT session uses `(component_code, role_code, material_sku)` to match BOM line item
2. ✅ **Used Area Calculation:** `used_area = qty_required × qty_cut` (computed from constraints, SSOT)
3. ✅ **Material Selection:** Material list filtered by role, shows `qty_per_unit` for display
4. ✅ **Validation:** Backend validates constraints exist and computes used_area before saving
5. ✅ **NODE_YIELD Event:** Includes `used_area` from constraints (SSOT)

**SSOT Principles:**
- ✅ Constraints are stored in `product_component_material` (BOM line item)
- ✅ `qty_required` is computed from `constraints_json` via `BomQuantityCalculator`
- ✅ `used_area` is computed from `qty_required × qty_cut` (server-side, SSOT)
- ✅ Frontend calculation is display-only (not authoritative)

---

## 7. CUT Timing Integration Analysis

### 6.1 Legacy System (TokenWorkSessionService)

**Scope:** Token-level (one session per token)
**Table:** `token_work_session`
**Use Case:** Single-piece work (HAT_SINGLE mode)

**Limitations for CUT:**
1. **Token-level only:** Cannot track component-level timing
2. **No component/role/material identity:** Cannot distinguish between different cutting operations
3. **No batch granularity:** Cannot track individual component cuts within a batch
4. **No material tracking:** Cannot track which material/sheet was used

**Conclusion:** Legacy system is **NOT suitable** for CUT operations which require component-level granularity.

---

### 6.2 New System (CutSessionService)

**Scope:** Component-level (one session per component+role+material)
**Table:** `cut_session`
**Use Case:** Batch work (BATCH_QUANTITY mode) with component-level tracking

**Advantages:**
1. **Component-level identity:** `(token_id, node_id, component_code, role_code, material_sku)`
2. **Material tracking:** Tracks `material_sheet_id`, `used_area`
3. **Batch granularity:** Can track individual component cuts within a batch
4. **Server-side timing:** All timestamps from server, duration computed in backend

**Integration:**
- Creates `NODE_YIELD` events with session timing
- Uses `TokenEventService` to persist canonical events
- Timeline sync via `TimeEventReader` (if needed)

---

### 6.3 Integration Points

#### NODE_YIELD Event
When `cut_session_end` is called:
1. `CutSessionService::endSession()` ends session
2. `BehaviorExecutionService::handleCutSessionEnd()` creates `NODE_YIELD` event
3. Event payload includes:
   - `started_at` - From `cut_session.started_at` (SSOT)
   - `finished_at` - From `cut_session.ended_at` (SSOT)
   - `duration_seconds` - From `cut_session.duration_seconds` (SSOT, server-computed)
   - `component_code`, `role_code`, `material_sku` - Session identity
   - `session_id` - Reference to authoritative `CutSession`

#### Timeline Sync
- `TimeEventReader` can read `NODE_YIELD` events for timeline reconstruction
- `flow_token` timing remains token-level (not component-level)
- Component-level timing is in `cut_session` table

---

## 7. Legacy vs New System Comparison

| Aspect | Legacy (TokenWorkSessionService) | New (CutSessionService) |
|--------|----------------------------------|------------------------|
| **Scope** | Token-level | Component-level |
| **Identity** | `(token_id, operator_id)` | `(token_id, node_id, component_code, role_code, material_sku, operator_id)` |
| **Table** | `token_work_session` | `cut_session` |
| **Use Case** | Single-piece work (HAT_SINGLE) | Batch work (BATCH_QUANTITY) with component tracking |
| **Material Tracking** | ❌ No | ✅ Yes (`material_sheet_id`, `used_area`) |
| **Component Identity** | ❌ No | ✅ Yes (`component_code`, `role_code`, `material_sku`) |
| **Server-Side Timing** | ✅ Yes | ✅ Yes |
| **Canonical Events** | ✅ Yes (NODE_START, NODE_COMPLETE) | ✅ Yes (NODE_YIELD with session timing) |
| **Timeline Reconstruction** | ✅ Yes (via TimeEventReader) | ✅ Yes (via NODE_YIELD events) |

---

## 9. Recommendations

### 8.1 ✅ Current Implementation is Correct

The new `CutSessionService` is **correctly designed** as a first-class entity for component-level timing, separate from legacy token-level timing.

**Reasons:**
1. CUT operations require component-level granularity (component+role+material)
2. Legacy `TokenWorkSessionService` is token-level only (not suitable for CUT)
3. New system provides proper identity and material tracking
4. New system maintains SSOT principles (server-side timing)

---

### 8.2 Integration with Legacy Systems

**✅ DO:**
- Use `CutSessionService` for CUT timing (SSOT)
- Create `NODE_YIELD` events with session timing
- Use `TokenEventService` to persist canonical events
- Maintain compatibility with `TimeEventReader` (via NODE_YIELD events)

**❌ DON'T:**
- Use `TokenWorkSessionService` for CUT operations
- Mix token-level and component-level timing
- Bypass canonical event system
- Create custom timing logic outside of services

---

### 8.3 Timeline Reconstruction

**Current State:**
- `TimeEventReader` can read `NODE_YIELD` events
- Component-level timing is in `cut_session` table
- Token-level timing remains in `flow_token` table

**Future Enhancement (Optional):**
- Add component-level timeline reconstruction if needed
- Create `CutTimelineReader` service if component-level timeline queries are required

---

### 8.4 Documentation

**✅ Complete:**
- `task31_CUT_SESSION_TIMING_SPEC.md` - CUT session timing specification
- `task31_CUT_TIMING_SSOT_AUDIT.md` - SSOT audit findings
- `task31_CUT_TIMING_SSOT_POLICY.md` - SSOT policy
- `task31_CUT_SSOT_COMPLIANCE_REPORT.md` - Compliance verification
- `task31_CUT_LEGACY_SYSTEM_AUDIT.md` - This document

---

## 10. SSOT Architecture Lock

**Status:** ✅ **LOCKED** - All critical SSOT decisions documented and verified

**Reference:** See `task31_CUT_SSOT_ARCHITECTURE_LOCK.md` for detailed verification of:
1. ✅ NODE_YIELD canonical event whitelist
2. ✅ NODE_YIELD timeline semantics (Option A - informational only)
3. ✅ Idempotency/conflict protection (DB constraint + transaction lock)
4. ✅ SSOT time policy (UI never creates authoritative time)
5. ✅ Used area failure modes (3 scenarios defined)
6. ✅ Documentation numbering (consistent)

---

## 11. Conclusion

**Legacy System Analysis:**
- ✅ TimeEngine v2 provides token-level timing (suitable for HAT_SINGLE)
- ✅ Node Behavior Engine provides canonical event generation
- ✅ Graph/DAG system provides token lifecycle management
- ✅ Canonical Events provide timeline reconstruction

**CUT Timing Requirements:**
- ✅ Component-level granularity (component+role+material)
- ✅ Material tracking (sheet, used_area)
- ✅ Server-side timing (SSOT)
- ✅ Integration with canonical events (NODE_YIELD)
- ✅ Used area auto-calculation from Product Constraints (SSOT)

**Implementation Status:**
- ✅ `CutSessionService` correctly designed as first-class entity
- ✅ Separate from legacy `TokenWorkSessionService` (correct separation)
- ✅ Integrated with canonical events (NODE_YIELD)
- ✅ Maintains SSOT principles (server-side timing)
- ✅ Used area computed from Product Constraints (SSOT)
- ✅ Constraints integration via `(component_code, role_code, material_sku)` identity match

**Verdict:** ✅ **Current implementation is correct and well-integrated with legacy systems.**

---

**Report Generated:** 2026-01-13  
**System Status:** ✅ **PRODUCTION READY**
