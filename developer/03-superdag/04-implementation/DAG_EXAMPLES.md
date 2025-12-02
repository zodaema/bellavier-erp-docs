# DAG Examples

## 0. Global Concepts (Recommended Before Reading Examples)

This section summarizes the core DAG concepts from the blueprint so that example graphs become easier to understand.

### 0.1 Token Types
- **Batch Token** — created from batch-mode nodes; represents multiple pieces.
- **Individual Token** — created after batch split; follows HAT_SINGLE or CLASSIC_SCAN flows.

### 0.2 Node Behaviors
- **BATCH** — 1 session → many outputs, yield tracking.
- **HAT_SINGLE** — time-engine based, single-piece.
- **CLASSIC_SCAN** — scan-driven, station-based.
- **QC_SINGLE** — inspection with pass/fail.

### 0.3 Branching Modes
- **Parallel Branch** — all branches must finish before merge.
- **Conditional Branch** — typically QC → rework or pass.

### 0.4 Component Binding Principles
- Binding never happens in batch steps.
- Default binding point is ASSEMBLE or QC pre-check.
- Supports: with serial, without serial, disposable, reusable.

### 0.5 Token Lifecycle Basics
1. Token spawned → enters first node  
2. Worker action (time-engine / scan / batch)  
3. Node completes → next node  
4. Optional rework loops  
5. QC → final pass  
6. PACK → END

---

## Table of Contents

1. [Example DAG Graphs](#1-example-dag-graphs)
2. [Example Hatthasilpa Flow](#2-example-hatthasilpa-flow)
3. [Example Batch Flow (Cutting)](#3-example-batch-flow-cutting)
4. [Example Classic Scan Flow](#4-example-classic-scan-flow)
5. [Example Component Binding Flow](#5-example-component-binding-flow)

---

## 1. Example DAG Graphs

### 1.1 Basic Sequential Flow

```
START → CUT → SKIVE → EDGE-PAINT → STITCH → ASSEMBLE → QC → PACK → END
```

**Characteristics:**
- Linear sequence
- Each node processes tokens in order
- No parallel branches
- Suitable for simple products

**When to Use:** Small leather goods, wallets, straps.

### 1.2 Parallel Assembly Flow

```
                    ┌─ SEW_BODY ─┐
START → CUT → SKIVE ┤            ├→ ASSEMBLE → QC → PACK → END
                    └─ SEW_STRAP ┘
```

**Characteristics:**
- Parallel branches after SKIVE
- Both SEW_BODY and SEW_STRAP can run simultaneously
- ASSEMBLE node waits for both branches to complete
- Merge node validates completion

**When to Use:** Bags with independent subassemblies (body vs strap).

### 1.3 Rework Loop Flow

```
START → CUT → SKIVE → EDGE-PAINT → QC ──┐
                                         │
                                         ├→ REWORK → QC
                                         │
                                         └→ PASS → ASSEMBLE → END
```

**Characteristics:**
- QC node can trigger rework
- Rework loop counter prevents infinite loops
- Scrap scenario if rework fails multiple times

**When to Use:** Products with high QC rejection probability or complex paint rounds.

---

## 2. Example Hatthasilpa Flow

**Production Mode:** Single-Piece Handcraft (Hatthasilpa Flow)

### 2.1 Flow Description

Used in: Hand-stitching, painting, assembly

### 2.2 Characteristics

- One worker = one piece
- Time-based workflow
- Pause/Resume errors are common
- Multi-worker contribution may happen

### 2.3 System Requirements

- Continuous Time Engine
- Auto error correction
- Worker attribution
- Rework loops

### 2.4 Example Node Sequence

```
START → CUT (BATCH) → SKIVE (HAT_SINGLE) → EDGE-PAINT (HAT_SINGLE) → 
STITCH (HAT_SINGLE) → ASSEMBLE (HAT_SINGLE) → QC (QC_SINGLE) → PACK (HAT_SINGLE) → END
```

**Node Details:**
- **CUT:** BATCH mode (cuts multiple pieces at once)
- **SKIVE:** HAT_SINGLE mode (one worker, one piece, time-tracked)
- **EDGE-PAINT:** HAT_SINGLE mode (paint_rounds: 3, time-tracked)
- **STITCH:** HAT_SINGLE mode (hand-stitching, time-tracked)
- **ASSEMBLE:** HAT_SINGLE mode (component binding required)
- **QC:** QC_SINGLE mode (pass/fail decision)
- **PACK:** HAT_SINGLE mode (final packaging)

### 2.5 Token Lifecycle

1. Token spawned at START node
2. Worker starts work at SKIVE node (Time Engine begins)
3. Worker pauses (error correction handles pause/resume)
4. Worker resumes (Time Engine tracks continuous time)
5. Token moves to next node
6. Component binding at ASSEMBLE node
7. QC validation
8. Token completes at END node  
9. Node history logged for artisan attribution  
10. Time Engine merges sessions automatically (pause/resume corrected)

---

## 3. Example Batch Flow (Cutting)

**Production Mode:** Batch Flow

### 3.1 Flow Description

Used in: Cutting, Skiving, Certain Prep

### 3.2 Characteristics

- One worker processes many pieces at once
- Single time duration produces multiple outputs
- Yield may be lower/higher than target quantity
- Loss, waste, mismatch is normal
- Some components may need re-cutting

### 3.3 System Requirements

- Batch Session
- Volume input
- Yield tracking
- Batch → Token Split logic

### 3.4 Example Node Sequence

```
START → CUT (BATCH) → SKIVE (BATCH) → EDGE-PAINT (BATCH) → 
STITCH (HAT_SINGLE) → ASSEMBLE (HAT_SINGLE) → QC (QC_SINGLE) → PACK (HAT_SINGLE) → END
```

**Node Details:**
- **CUT:** BATCH mode (requires_qty: true, supports_batch: true)
- **SKIVE:** BATCH mode (processes multiple pieces)
- **EDGE-PAINT:** BATCH mode (paint_rounds: 3, batch processing)
- **STITCH:** HAT_SINGLE mode (switches to single-piece after batch steps)
- **ASSEMBLE:** HAT_SINGLE mode (component binding)
- **QC:** QC_SINGLE mode (individual inspection)
- **PACK:** HAT_SINGLE mode (individual packaging)

### 3.5 Batch Session Flow

1. Worker starts batch session at CUT node
2. Input: target_qty = 50 pieces
3. Worker processes batch (single time duration)
4. Output: actual_qty = 48 pieces (yield tracking)
5. Batch session completes
6. System splits batch into 48 individual tokens
7. Each token continues independently through remaining nodes

### 3.6 Yield Tracking Example

- **Target:** 50 pieces
- **Actual:** 48 pieces
- **Loss:** 2 pieces (logged as waste)
- **Yield %:** 96%
- **System Action:** Creates 48 tokens, logs 2 as scrap

### 3.7 Batch → HAT_SINGLE Transition Note
When switching from batch mode to HAT_SINGLE mode:
- System automatically splits batch token into individual tokens.
- Each token inherits batch metadata (cut lot, yield origin).
- Time Engine starts fresh at the first HAT_SINGLE node.

---

## 4. Example Classic Scan Flow

**Production Mode:** Classic Line (Scan-Based Flow)

### 4.1 Flow Description

Used in: OEM, Classic mass production

### 4.2 Characteristics

- Station → Station
- Driven by scan events
- No constant time tracking
- Needs safe-scan, reverse scan handling

### 4.3 System Requirements

- Scan Engine
- Missing scan recovery
- Invalid sequence protection

### 4.4 Example Node Sequence

```
START → CUT (BATCH) → SKIVE (CLASSIC_SCAN) → EDGE-PAINT (CLASSIC_SCAN) → 
STITCH (CLASSIC_SCAN) → ASSEMBLE (CLASSIC_SCAN) → QC (CLASSIC_SCAN) → PACK (CLASSIC_SCAN) → END
```

**Node Details:**
- **CUT:** BATCH mode (initial batch processing)
- **SKIVE:** CLASSIC_SCAN mode (scan-based completion)
- **EDGE-PAINT:** CLASSIC_SCAN mode (scan-based completion)
- **STITCH:** CLASSIC_SCAN mode (scan-based completion)
- **ASSEMBLE:** CLASSIC_SCAN mode (scan-based completion, component binding)
- **QC:** CLASSIC_SCAN mode (scan-based completion, pass/fail)
- **PACK:** CLASSIC_SCAN mode (scan-based completion)

### 4.5 Scan Flow Example

1. Token spawned at START node
2. CUT node completes (batch processing)
3. Token moves to SKIVE node (waiting for scan)
4. Worker scans serial at SKIVE station
5. System validates scan (safe-scan check)
6. Token moves to next node
7. Worker scans at EDGE-PAINT station
8. System validates sequence (prevents reverse scan)
9. Process continues through all scan-based nodes
10. Token completes at END node

### 4.6 Error Handling

- **Reverse Scan:** System detects token already passed this node, logs error
- **Missing Scan:** System can recover if worker forgot to scan (manual override)
- **Invalid Sequence:** System prevents token from skipping nodes

### 4.7 Scan Engine Safety
- Rejects repeated scans at the same station.
- Prevents skipping nodes.
- Provides manual override for missing scans with audit logs.

---

## 5. Example Component Binding Flow

**Production Mode:** Hatthasilpa Flow with Component Binding

### 5.1 Flow Description

Multi-part product assembly with component serial tracking

### 5.2 Component Types

- **With Serial:** hardware, straps, metal sets
- **Without Serial:** lining, internal panels
- **Disposable:** consumable materials
- **Reusable:** metal parts

### 5.3 Flow Sequence

```
START → CUT (BATCH) → SKIVE (HAT_SINGLE) → EDGE-PAINT (HAT_SINGLE) → 
STITCH_BODY (HAT_SINGLE) ──┐
                           ├→ ASSEMBLE (HAT_SINGLE) → QC (QC_SINGLE) → PACK (HAT_SINGLE) → END
STITCH_STRAP (HAT_SINGLE) ─┘
```

### 5.4 Component Binding Process

#### Step 1: Component Stock Movement

1. **component_stock_in** — initial receiving
   - Hardware: 100 pieces received
   - Straps: 50 pieces received
   - Lining: 200 meters received

2. **component_stock_out (picking)** — issued before assembly
   - Hardware: 1 piece picked for job_ticket_631
   - Strap: 1 piece picked for job_ticket_631
   - Lining: 2 meters picked for job_ticket_631

3. **component_consumption** — consumed when bound to token
   - Hardware serial "HW-2025-001" bound to token_1234
   - Strap serial "STR-2025-045" bound to token_1234
   - Lining consumed (no serial)

4. **component_scrap** — defect handling
   - Hardware "HW-2025-002" scrapped (defect)
   - Stock decreased, cause logged

#### Step 2: Binding at Assembly Node

**Node:** ASSEMBLE  
**Mode:** HAT_SINGLE  
**Behavior:** ASSEMBLE

**Process:**
1. Token arrives at ASSEMBLE node
2. Worker selects components from picked stock
3. System validates component serials
4. Components bound to token:
   - Hardware: "HW-2025-001"
   - Strap: "STR-2025-045"
   - Lining: consumed (no serial)
5. Binding recorded in component_consumption
6. Token proceeds to QC

#### Step 3: Component Validation at QC

**Node:** QC  
**Mode:** QC_SINGLE  
**Behavior:** QC

**Process:**
1. QC inspector checks component bindings
2. Validates serials match final product
3. If mismatch detected:
   - Component error logged
   - Rework triggered
   - Component replacement required

### 5.5 Late Binding Example

**Scenario:** Components do NOT bind at Cutting

**Reason:**
- Cutting is batch
- Items get mixed
- QC happens before assembly
- Serial must match final assembly sequence

**Binding Point:** Assembly node or QC pre-check

**Example:**
1. CUT node processes batch (50 pieces)
2. Components are NOT bound yet
3. Pieces move through SKIVE, EDGE-PAINT, STITCH
4. At ASSEMBLE node, worker selects components
5. Components bound to specific token
6. Serial matches final assembly sequence

#### Why Late Binding is Required
Component binding cannot occur at batch steps because:
- Pieces are mixed inside the batch.
- Serial-number identity only becomes meaningful at assembly.
- Ensures traceability without slowing down early-stage workers.

### 5.6 Component Replacement Example

**Scenario:** Component defect detected at QC

**Process:**
1. QC fails due to hardware defect
2. System logs component error
3. Worker replaces hardware:
   - Old: "HW-2025-001" (scrapped)
   - New: "HW-2025-003" (bound)
4. Replacement tracked in component_replacement
5. Token proceeds with new component

---

## 6. Production Reality Model Summary

### 6.1 Batch Flow
- One worker processes many pieces at once
- Single time duration produces multiple outputs
- Yield tracking required

### 6.2 Single-Piece Handcraft (Hatthasilpa Flow)
- One worker = one piece
- Time-based workflow
- Pause/Resume error handling

### 6.3 Classic Line (Scan-Based Flow)
- Station → Station
- Driven by scan events
- No constant time tracking

---

## 7. Recommended Reading Order for Developers
1. DAG_Blueprint.md (conceptual)
2. DAG_EXAMPLES.md (practical patterns)
3. DAG_IMPLEMENTATION_GUIDE.md (system implementation)
4. super_dag/models/ (for behavior definitions)
5. super_dag/api/ (for execution logic)

---

**Source:** [DAG_Blueprint.md](DAG_Blueprint.md)  
**Last Updated:** December 2025
