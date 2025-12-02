# Task 21.1 Results — Node Behavior Engine (Core Spec & Minimal Skeleton)

**Status:** ✅ COMPLETE (Corrected - Aligned with Node_Behavier.md + Core Principles)  
**Date:** 2025-01-XX  
**Category:** SuperDAG / Node Behavior Engine

**⚠️ IMPORTANT:** This task was corrected to align with `Node_Behavier.md` canonical spec and Core Principles (13-15).  
**Key Changes:**
- Uses Node Mode from Work Center (BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE) instead of creating new Behavior Codes
- Implements Canonical Events Integration (Core Principles 14-15)
- Implements Close System principle (Core Principles 13)
- Aligns with Graph Neutrality (A1) and BOM Separation (A5)

---

## 1. Executive Summary

Task 21.1 successfully established the **conceptual foundation** and **minimal skeleton** for the Node Behavior Engine, **aligned with Node_Behavier.md canonical spec**. This task focused on specification and structure without implementing business logic, preparing the system for future behavior implementation in Tasks 21.2+.

**Key Achievements:**
- ✅ Created Behavior Model documentation (`node_behavior_model.md`) - aligned with Node_Behavier.md
- ✅ Created `NodeBehaviorEngine` PHP skeleton class - reads node_mode from Work Center
- ✅ Established context/effects structure - uses node_mode + line_type
- ✅ No database side effects (as required)
- ✅ No wiring to runtime systems (as required)

**Critical Correction:**
- ❌ Removed incorrect Behavior Catalog V1 (was creating new Behavior Codes: CUT, SEW, EDGE, QC, PACK)
- ✅ Now uses Node Mode from Work Center (BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE) as per Node_Behavier.md

---

## 2. Implementation Details

### 2.1 Behavior Model Documentation

**File:** `docs/super_dag/node_behavior_model.md`

**Purpose:** Conceptual foundation for Node Behavior Engine (aligned with Node_Behavier.md)

**Key Sections:**
1. **Core Concepts:**
   - Node Mode (from Work Center) vs Node Type distinction
   - Alignment with Node_Behavier.md Axioms (A2, A3, A4)
   
2. **Node Mode Catalog:**
   - BATCH_QUANTITY (Cutting / Prep)
   - HAT_SINGLE (Hatthasilpa – Single Piece Work)
   - CLASSIC_SCAN (Classic Line – PWA Scan)
   - QC_SINGLE (Quality Control per Piece)

3. **Execution Context Structure:**
   - Input Context (includes work_center.node_mode, job.line_type)
   - Output Effects structure
   - Abstraction principles

4. **Behavior Execution Flow:**
   - Token completion flow
   - Node Mode resolution from Work Center
   - Execution mode resolution (node_mode + line_type)

**Size:** ~400 lines

**Alignment:**
- ✅ Follows Node_Behavier.md AXIOM A2 (Work Center determines Node Mode)
- ✅ Follows Node_Behavier.md AXIOM A3 (Runtime uses node_mode + line_type)
- ✅ Follows Node_Behavier.md AXIOM A4 (Designer does not choose node_mode)

---

### 2.2 NodeBehaviorEngine PHP Skeleton

**File:** `source/BGERP/Dag/NodeBehaviorEngine.php`

**Purpose:** Core engine class for behavior execution (skeleton only in Task 21.1)

**Namespace:** `BGERP\Dag`

**Key Methods:**

1. **`resolveNodeMode(array $node): ?string`**
   - **Purpose:** Resolve node_mode from Work Center (NOT from Node)
   - **Implementation:**
     - Reads `id_work_center` from `routing_node`
     - Queries `work_center.node_mode`
     - Returns: `BATCH_QUANTITY`, `HAT_SINGLE`, `CLASSIC_SCAN`, `QC_SINGLE` or null
   - **Alignment:** 
     - Follows Node_Behavier.md AXIOM A2
     - Follows node_behavior_model.md Section 3.1.1 (Node Mode ไม่ encode line_type)

2. **`buildExecutionContext(array $token, array $node, ?array $jobTicket = null): array`**
   - **Purpose:** Build normalized execution context
   - **Key Fields:**
     - `work_center.node_mode` - From Work Center (not from Node)
     - `execution.node_mode` - Resolved node_mode
     - `execution.line_type` - From job context (classic or hatthasilpa)
   - **Alignment:** 
     - Follows Node_Behavier.md AXIOM A3
     - Follows node_behavior_model.md Section 9 (A1 - Graph Neutrality, A5 - BOM Separation)
     - BOM information NOT included in context (A5)

3. **`executeBehavior(array $context): array`**
   - **Purpose:** Stub method for behavior execution (no business logic in Task 21.1)
   - **Returns:** Structured result with `node_mode`, `line_type`, and `canonical_events` placeholder
   - **Canonical Events:** 
     - Output structure includes `canonical_events` array (placeholder in Task 21.1)
     - Allowed events: TOKEN_*, NODE_*, OVERRIDE_*, COMP_*, INVENTORY movements
     - Follows Core Principles 14-15 and node_behavior_model.md Section 4.0
   - **Guard:** Must not be invoked from production flows before Task 21.2

**Size:** ~180 lines

**Key Design Decisions:**
- ✅ Reads `node_mode` from `work_center` table (not from `routing_node`)
- ✅ Uses existing Node Modes (BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE)
- ✅ Does NOT create new Behavior Codes
- ✅ Node Mode does NOT encode line_type (Section 3.1.1)
- ✅ Output includes `canonical_events` array (placeholder in Task 21.1)
- ✅ Aligned with Node_Behavier.md canonical spec
- ✅ Aligned with Core Principles 13-15 (Close System, Canonical Events)

---

## 3. Files Created/Modified

### 3.1 Created Files

1. **`docs/super_dag/node_behavior_model.md`**
   - Behavior Model documentation (aligned with Node_Behavier.md)
   - ~400 lines

2. **`source/BGERP/Dag/NodeBehaviorEngine.php`**
   - PHP skeleton class for Node Behavior Engine
   - ~180 lines

### 3.2 Removed Files

1. **`docs/super_dag/node_behavior_catalog_v1.md`** (DELETED)
   - **Reason:** Was creating new Behavior Codes (CUT, SEW, EDGE, QC, PACK) that conflict with Node_Behavier.md
   - **Replacement:** Use Node Mode Catalog from Node_Behavier.md instead

---

## 4. Alignment with Node_Behavier.md

### 4.1 AXIOM A2 Compliance

**Requirement:** Work Center determines Node Mode, Node receives from Work Center

**Implementation:**
- ✅ `NodeBehaviorEngine::resolveNodeMode()` reads from `work_center.node_mode`
- ✅ Node does NOT store `node_mode` directly
- ✅ Context includes `work_center.node_mode` (not `node.behavior_code`)

### 4.2 AXIOM A3 Compliance

**Requirement:** Runtime uses (node_mode, line_type) to determine execution mode

**Implementation:**
- ✅ Context includes `execution.node_mode` (from Work Center)
- ✅ Context includes `execution.line_type` (from job context)
- ✅ Execution semantics will be determined by (node_mode, line_type) in Task 21.2+

### 4.3 AXIOM A4 Compliance

**Requirement:** Designer does not choose node_mode, only binds Node to Work Center

**Implementation:**
- ✅ `NodeBehaviorEngine` does NOT read `node_mode` from `routing_node`
- ✅ Engine resolves `node_mode` from Work Center at runtime
- ✅ Designer remains neutral (no node_mode selection in Designer)

---

## 5. Node Mode Usage

### 5.1 Node Modes Used (from Node_Behavier.md)

- **BATCH_QUANTITY:** Batch operations (CUTTING, SKIVING, PREP)
- **HAT_SINGLE:** Hatthasilpa single-piece work (Hand Stitching)
- **CLASSIC_SCAN:** Classic/OEM scan-driven stations
- **QC_SINGLE:** Quality control per piece

### 5.2 Execution Mode Resolution (Future - Task 21.2+)

Runtime will resolve execution mode using:
```php
execution_mode = resolveExecutionMode(
    workCenter.node_mode,  // BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE
    job.line_type          // classic or hatthasilpa
)
```

**Examples:**
- `(BATCH_QUANTITY, hatthasilpa)` → HAT_BATCH_QUANTITY + Time Engine
- `(HAT_SINGLE, hatthasilpa)` → HAT_SINGLE
- `(HAT_SINGLE, classic)` → CLASSIC_SINGLE
- `(CLASSIC_SCAN, classic)` → CLASSIC_SCAN (PWA)

---

## 6. Context Structure

### 6.1 Input Context

```php
[
    'token' => [...],
    'node' => [
        'id_node' => int,
        'id_work_center' => int,  // FK to work_center
        // NO node_mode here - comes from Work Center
    ],
    'work_center' => [
        'id_work_center' => int,
        'node_mode' => string,  // BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE
    ],
    'execution' => [
        'node_mode' => string,  // From Work Center
        'line_type' => string,  // From job context (classic or hatthasilpa)
    ],
    'job_ticket' => [...],
    'time' => [...],
    'meta' => [...],
]
```

### 6.2 Output Effects (Canonical Events)

```php
[
    'ok' => bool,
    'node_mode' => string,  // BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE
    'line_type' => string,  // classic or hatthasilpa
    'canonical_events' => [
        // Placeholder in Task 21.1, will contain canonical events in Task 21.2+
        // Allowed: TOKEN_*, NODE_*, OVERRIDE_*, COMP_*, INVENTORY movements
    ],
    'effects' => [
        // Legacy structure for compatibility (will be deprecated in Task 21.2+)
        'wip' => null,
        'inventory' => null,
        'qc' => null,
        'routing' => null,
    ],
    'meta' => [
        'version' => '21.1',
        'executed' => false,  // Stub - no business logic yet
    ],
]
```

**Note:** Behavior ห้ามส่งผลลัพธ์ที่อยู่นอกเหนือรายการ canonical events ที่กำหนดไว้ (Core Principles 14-15)

---

## 7. Design Decisions

### 7.1 Why Use Node Mode from Work Center?

**Decision:** Read `node_mode` from `work_center` table, not from `routing_node`

**Rationale:**
- Aligns with Node_Behavier.md AXIOM A2
- Work Center is the source of truth for node_mode
- Node "receives" node_mode from Work Center (not stores it)
- Designer remains neutral (does not choose node_mode)

### 7.2 Why Not Create New Behavior Codes?

**Decision:** Use existing Node Modes (BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE) instead of creating new Behavior Codes (CUT, SEW, EDGE, QC, PACK)

**Rationale:**
- Node_Behavier.md already defines Node Modes
- Creating new Behavior Codes would conflict with existing architecture
- Node Modes are Framework-level enums (not user-defined)
- Avoids refactoring existing system

### 7.3 Why Include line_type in Context?

**Decision:** Include `line_type` (classic or hatthasilpa) in execution context

**Rationale:**
- Aligns with Node_Behavier.md AXIOM A3
- Runtime execution depends on (node_mode, line_type) pair
- Different execution modes for same node_mode based on line_type
- Enables "One Graph, Two Lines" architecture

### 7.4 TimeHelper Integration

**Decision:** Use `TimeHelper` for all timestamps in context

**Rationale:**
- Consistent with Task 20.2 timezone normalization
- Canonical timezone (Asia/Bangkok) for all operations
- Future-proof for multi-region deployments

### 7.5 Canonical Events Integration

**Decision:** Behavior Execution MUST output only canonical event structures

**Rationale:**
- Aligns with Core Principles 14-15 (Canonical Event Framework)
- Allowed events: TOKEN_*, NODE_*, OVERRIDE_*, COMP_*, INVENTORY movements
- Prevents custom keys in effects that break system consistency
- Manual overrides must be translated to canonical events before entering Behavior Engine

**Implementation:**
- `executeBehavior()` returns `canonical_events` array (placeholder in Task 21.1)
- Legacy `effects` structure maintained for compatibility, will be deprecated in Task 21.2+

### 7.6 Close System (No Plugin Architecture)

**Decision:** Behavior Registry is internal only (NOT plugin-extensible)

**Rationale:**
- Aligns with Core Principles 13 (Close Logic, Flexible Operations)
- Node Mode controlled by Bellavier Framework only
- Prevents external behavior types that could break system integrity
- Behavior registry used only for mapping `node_mode → internal behavior class`

### 7.7 Graph Neutrality & BOM Separation

**Decision:** 
- Graph Designer does NOT determine line_type (A1)
- Behavior Engine does NOT handle BOM logic (A5)

**Rationale:**
- Aligns with Node_Behavier.md AXIOM A1 (Graph Neutrality)
- Aligns with Node_Behavier.md AXIOM A5 (BOM Separation)
- Graph must be reusable between Classic/Hatthasilpa
- Component Binding (COMP_BIND/UNBIND) is canonical event only, separate from BOM logic

---

## 8. Known Limitations

### 8.1 No Business Logic

**Limitation:** `executeBehavior()` is a stub, returns placeholder effects only

**Reason:** Task 21.1 scope (specification-only)

**Future:** Task 21.2+ will implement real behavior logic based on node_mode

### 8.2 No Service Layer Integration

**Limitation:** No integration with TokenLifecycleService, InventoryService, etc.

**Reason:** Task 21.1 scope (skeleton only)

**Future:** Task 21.2+ will wire into service layer

### 8.3 line_type Field Verification Needed

**Limitation:** `line_type` field location in job_ticket may need verification

**Note:** According to Node_Behavier.md, line_type comes from job/MO/Hatthasilpa Job context. The exact field name/location may need adjustment based on actual schema.

**Future:** Verify and adjust in Task 21.2

---

## 9. Next Steps

### 9.1 Task 21.2 (Planned)

- Wire `NodeBehaviorEngine` into Token Completion Flow (read-only/dry-run)
- Verify `line_type` field location and resolution
- Test node_mode resolution from Work Center
- Implement execution mode resolution (node_mode + line_type)

### 9.2 Task 21.3 (Planned)

- Implement behavior logic for each node_mode:
  - BATCH_QUANTITY: Batch session creation, quantity handling
  - HAT_SINGLE: Single token work queue integration
  - CLASSIC_SCAN: PWA scan flow integration
  - QC_SINGLE: QC result capture
- Wire into service layer (TokenLifecycleService, InventoryService, etc.)

### 9.3 Task 21.4 (Planned)

- Internal Behavior Registry (NOT plugin-extensible)
  - Behavior registry ใช้เพื่อ mapping node_mode → internal behavior class เท่านั้น
  - Close System: ไม่อนุญาต plugin, extension, หรือ behavior type ใหม่จากภายนอก
  - Node Mode ถูกควบคุมโดย Bellavier Framework เท่านั้น
- Versioning and migration support

---

## 10. Acceptance Criteria

### 10.1 Specification

- ✅ Behavior Model documentation created and aligned with Node_Behavier.md
- ✅ NodeBehaviorEngine skeleton created
- ✅ Context/effects structure established
- ✅ No database side effects

### 10.2 Alignment

- ✅ Follows Node_Behavier.md AXIOM A2 (Work Center determines Node Mode)
- ✅ Follows Node_Behavier.md AXIOM A3 (Runtime uses node_mode + line_type)
- ✅ Follows Node_Behavier.md AXIOM A4 (Designer does not choose node_mode)
- ✅ Follows Node_Behavier.md AXIOM A1 (Graph Neutrality - Graph reusable between Classic/Hatthasilpa)
- ✅ Follows Node_Behavier.md AXIOM A5 (BOM Separation - Behavior Engine does NOT handle BOM)
- ✅ Uses existing Node Modes (no new Behavior Codes created)
- ✅ Node Mode does NOT encode line_type (Section 3.1.1)
- ✅ Follows Core Principles 13 (Close System - no plugin/extensible)
- ✅ Follows Core Principles 14-15 (Canonical Events - output only canonical event structures)

### 10.3 Code Quality

- ✅ PHP syntax valid
- ✅ No linter errors
- ✅ Proper documentation and comments
- ✅ Feature flag guard in place

---

## 11. Correction Summary

**Original Issue:**
- Created new Behavior Codes (CUT, SEW, EDGE, QC, PACK) that conflict with Node_Behavier.md
- Read `behavior_code` from `routing_node` instead of `node_mode` from `work_center`

**Correction Applied:**
- ✅ Removed incorrect Behavior Catalog V1
- ✅ Updated NodeBehaviorEngine to read `node_mode` from Work Center
- ✅ Updated documentation to align with Node_Behavier.md
- ✅ Uses existing Node Modes (BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE)

**Result:**
- ✅ Aligned with Node_Behavier.md canonical spec
- ✅ No conflicts with existing architecture
- ✅ Ready for Task 21.2+ implementation

---

**Document Status:** ✅ Complete (Task 21.1 - Corrected)  
**Last Updated:** 2025-01-XX  
**Alignment:** Aligned with Node_Behavier.md canonical spec
