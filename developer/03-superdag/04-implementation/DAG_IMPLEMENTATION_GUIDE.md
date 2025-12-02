# DAG Implementation Guide

**Bellavier Group ERP – Atelier & Classic Production Engine**

This guide provides implementation recipes for building the DAG Engine based on the [DAG_Blueprint.md](DAG_Blueprint.md).  
All content is derived directly from the blueprint, reorganized as an implementation reference.

---

## Table of Contents

1. [Node Behavior Mapping](#1-node-behavior-mapping)
2. [Token Engine 2.0 Integration](#2-token-engine-20-integration)
3. [Work Center Behavior Engine](#3-work-center-behavior-engine)
4. [Materialization Rules During MO](#4-materialization-rules-during-mo)
5. [Component Binding Overview](#5-component-binding-overview)
6. [Error Reality Model](#6-error-reality-model)
7. [Node Behavior + Mode Interaction Examples](#7-node-behavior--mode-interaction-examples)

---

## 1. Node Behavior Mapping

### 1.1 Node Model

A Node has two dimensions:

#### Node Behavior
"What this node *does*"  
CUT, SKIVE, EDGE-PAINT, STITCH, ASSEMBLE, QC, PACK

Determines required actions:
- CUT → qty
- EDGE PAINT → rounds
- ASSEMBLY → component binding
- QC → pass/fail codes

#### Node Execution Mode
"How the worker executes it"
- BATCH
- HAT_SINGLE
- CLASSIC_SCAN
- QC_SINGLE

**Behavior + Mode = Complete Node Definition**

### 1.2 Implementation Requirements

- DAG Designer must allow:
  - Behavior selection
  - Execution mode selection
  - Work Center assignment
  - Component requirements
  - QC handling
  - Batch flags
  - Node-level metadata rules

- Designer does NOT determine handcraft vs batch.  
  This is determined by MO or job ticket.

---

## 2. Token Engine 2.0 Integration

### 2.1 Core Token Model

Token must support all real production cases:

#### Core Attributes
- token_id
- job_ticket_id
- node_id
- worker(s)
- start_time / end_time
- status (active, paused, completed, rework)

#### Batch & Split
- batch_session_id
- split into N tokens
- propagate metadata

#### Time Engine Integration
- auto resume
- error detection
- drift correction

#### Component Integration
- component bindings
- replacement tracking
- mismatch error detection

#### Rework Logic
- fail → rework node creation
- rework loop counter
- scrap scenario

### 2.2 Worker Skill Model

Workers differ in specialization. Token routing must reflect real skill constraints.

#### Skill Attributes
- **skill_type**: cutting, stitching, edge-paint, assembly, QC
- **skill_level**: 1–5 (or free-form)
- **certifications**: e.g., "edge paint level 3"
- **can_handle_batch**: boolean
- **can_handle_hat_single**: boolean

#### System Requirements
- Token dispatch must consider skill requirements of nodes
- Designer may tag nodes with required skill_type + skill_level
- System prevents assignment of unqualified workers
- Enables future auto-routing / ML prediction

---

## 3. Work Center Behavior Engine

Work Center is not just a "name."  
Each center has *structured behavior*:

### 3.1 Behavior Attributes
- requires_qty: boolean
- supports_batch: boolean
- supports_single: boolean
- supports_scan: boolean
- supports_time_engine: boolean
- supports_component_binding: boolean
- supports_qc: boolean
- output_type: token | component-set | batch
- paint_rounds: number (optional)
- max_workers: number

### 3.2 Examples
- CUT: `{requires_qty: true, supports_batch: true}`
- EDGE PAINT: `{paint_rounds: 3}`
- ASSEMBLY: `{supports_component_binding: true}`
- QC: `{supports_qc: true}`

### 3.3 Work Center Capacity Model

Real factories operate under capacity constraints. Each Work Center must define:

#### Capacity Attributes
- **max_tokens**: maximum number of active tokens a worker or work center can handle
- **max_batch_size**: limit for batch-oriented nodes
- **concurrent_workers**: how many workers can operate at this station simultaneously
- **queue_limit**: optional limit for excessive workload
- **machine_capacity**: if machines are used, defines cycle time and throughput

#### Purpose
This capacity model is used during MO creation and job dispatching to:
- prevent overload
- estimate timeline
- assign workers correctly
- ensure realistic rending of factory throughput

---

## 4. Materialization Rules During MO

When a user creates MO (Classic) or Hatthasilpa Job:  
System must derive:

- token model
- batch session needs
- execution modes
- component worklist
- serial generation plan
- QC routing
- timeline estimate

All derived from:
- DAG Graph
- Work Center Behavior
- BOM
- Production mode (HAT vs CLASSIC)

---

## 5. Component Binding Overview

### 5.1 Components Are Not Equal

Component types:
- With Serial (hardware, straps, metal sets)
- Without Serial (lining, internal panels)
- Disposable
- Reusable metal parts

System Requirements:
- Component Type System
- Component Serial Binding
- Component Replacement Tracking

### 5.2 Components Do NOT bind at Cutting

Reasons:
- Cutting is batch
- Items get mixed
- QC happens before assembly
- Serial must match final assembly sequence

System Requirements:
- Binding occurs at Assembly node or QC pre-check
- Late binding support

### 5.3 Component Stock Movement Model

Component lifecycle must track stock changes precisely.

#### Flow
1. **component_stock_in** — initial receiving
2. **component_stock_out (picking)** — issued before assembly
3. **component_consumption** — consumed when bound to token
4. **component_scrap** — defect, broken hardware, or mismatched component

#### Notes
- Binding does NOT equal stock out (picking event is separate)
- Scrap events must decrease stock and log cause
- Enables full traceability & cost accuracy

---

## 6. Error Reality Model

The ERP must anticipate >50 real-world errors.

### 6.1 Error Categories

#### Batch Errors
- incomplete qty
- mismatch between expected vs actual

#### Worker Errors
- forgot start
- forgot pause
- start multiple tokens
- wrong worker

#### QC Errors
- failed inspection
- defect classification
- mis-binded components

#### Component Errors
- serial mismatch
- missing component
- wrong batch

#### Scan Errors
- reverse scan
- missing scan
- invalid node sequence

### 6.2 System Requirements
- Auto-detection
- Auto-recovery
- Token correction tools
- Error logs

---

## 7. Node Behavior + Mode Interaction Examples

### 7.1 Example: CUT Node

**Behavior:** CUT  
**Mode:** BATCH

**Result:**
- Requires qty input
- Creates batch session
- Splits into N tokens after completion
- Tracks yield vs target

### 7.2 Example: EDGE PAINT Node

**Behavior:** EDGE-PAINT  
**Mode:** HAT_SINGLE

**Result:**
- Requires paint_rounds (from Work Center)
- Time Engine tracks continuous work
- Supports pause/resume
- Worker attribution

### 7.3 Example: ASSEMBLY Node

**Behavior:** ASSEMBLE  
**Mode:** HAT_SINGLE

**Result:**
- Requires component binding
- Validates component serials
- Tracks component consumption
- Supports component replacement

### 7.4 Example: QC Node

**Behavior:** QC  
**Mode:** QC_SINGLE

**Result:**
- Requires pass/fail decision
- Triggers rework on fail
- Logs defect classification
- Validates component bindings

### 7.5 Example: PACK Node

**Behavior:** PACK  
**Mode:** CLASSIC_SCAN

**Result:**
- Scan-based completion
- No time tracking
- Safe-scan validation
- Reverse scan handling

---

## 8. Major Design Principles

1. **Workers make mistakes — system must self-heal.**
2. **Batch is first-class citizen.**
3. **Components bind late, not early.**
4. **Nodes have behavior + mode (two axes).**
5. **Token Engine is the universal ledger of work.**
6. **DAG Designer must remain neutral and reusable.**
7. **Hatthasilpa ≠ Classic — same graph, different execution model.**

---

## 9. Parallel Node Support

Some production tasks can occur simultaneously:
- drying after edge-paint
- pre-assembly prep
- machine-aided steps that run concurrently

### Requirements
- DAG must allow parallel branches
- Token system must track independent timelines
- Final merge node must validate completion of all parallel tasks

---

## 10. Machine Step Support

In preparation for machinery integration:
- log machine usage
- machine calibration cycles
- cycle time modeling
- safety interlocks for scan-based stations

---

## 11. Future Extensions

- Multi-worker attribution scoring
- Skill-based routing
- Machine learning for workload prediction
- Cost calculation per node
- Forensic Traceability for brand certification

---

## 12. Node Behavior Registry

Each Node Behavior must be registered so developers and AI agents can add, update, or validate behaviors consistently.

### 12.1 Purpose
- Standardize all behaviors (CUT, SKIVE, STITCH, EDGE-PAINT, ASSEMBLE, QC, PACK).
- Prevent mismatched spelling or unregistered behaviors.
- Provide metadata for each behavior.

### 12.2 Registry Structure (PHP)
All behaviors are defined in a single registry file:

`source/BGERP/DAG/Registry/NodeBehaviorRegistry.php`

The registry returns an associative array:

```php
return [
    'CUT' => [
        'requires_qty' => true,
        'description' => 'Cutting raw materials into required shapes',
        'default_mode' => 'BATCH'
    ],
    'EDGE-PAINT' => [
        'requires_rounds' => true,
        'default_rounds' => 3,
        'default_mode' => 'HAT_SINGLE'
    ],
    'ASSEMBLE' => [
        'requires_component_binding' => true,
        'default_mode' => 'HAT_SINGLE'
    ],
    // ...
];
```

### 12.3 Rules
- All behaviors must be declared in the registry.
- DAG Designer pulls directly from this registry.
- Adding a new behavior requires:
  1. Update registry
  2. Update Work Center behavior mapping
  3. Write Behavior Tests

---

## 13. Execution Mode Registry

Execution Modes define *how* operators execute tasks.

### 13.1 Purpose
- Prevent uncontrolled creation of new modes.
- Ensure all token time rules follow a consistent model.

### 13.2 Registry File
`source/BGERP/DAG/Registry/NodeModeRegistry.php`

```php
return [
    'BATCH' => [
        'supports_time_engine' => false,
        'splittable' => true
    ],
    'HAT_SINGLE' => [
        'supports_time_engine' => true,
        'splittable' => false
    ],
    'CLASSIC_SCAN' => [
        'supports_time_engine' => false,
        'scan_required' => true
    ],
    'QC_SINGLE' => [
        'supports_time_engine' => false,
        'qc_required' => true
    ],
];
```

### 13.3 Rules
- Modes must be neutral and not tied to any brand.
- Designer must always reference this registry.

---

## 14. Scan Logic – Classic Execution Mode

Classic mode relies entirely on scan-based execution.

### 14.1 When Worker Scans
The following pipeline executes:

1. Validate job_ticket and node order
2. Detect reverse scan
3. Detect missing/duplicate scans
4. Complete token immediately (no time tracking)
5. Log scan event for forensic traceability

### 14.2 Scan Error Handling
- Missing previous node → reject
- Scan wrong node → reject
- Scan too early → reject
- Double scan → warning → auto-fix
- Scan out of sequence → block until corrected

### 14.3 Use Cases
- Packing stations
- Machine-driven steps
- Heat press / mold machines
- Any step with predictable cycle time

---

## 15. Parallel Merge Rules

Parallel nodes must converge at a merge node.

### 15.1 Merge Logic
A merge node may only complete if:
- ALL parent parallel branches are completed
- NONE are in rework state
- ALL components from parallel paths are bound properly

### 15.2 Failure Cases
- One branch fails QC → merge is blocked
- One branch stuck in rework → merge waits
- Missing or mismatched component → merge refuses to finalize

### 15.3 Token Model Rules
- Each parallel branch yields its own sub-token
- Merge node consolidates:
  - time data
  - worker attribution
  - component bindings
- Final token inherits merged metadata

---

## 16. BOM-to-Node Linking

Nodes need to know which components are relevant.

### 16.1 Mapping Strategies
Two-level mapping:

1. **Product BOM**  
   - Lists required components (qty / type)
2. **Node Requirement Mapping**  
   - Lists which node consumes which component

### 16.2 Examples

| Component | BOM Qty | Consumption Node | Notes |
|----------|---------|------------------|-------|
| Long Strap (serial) | 1 | ASSEMBLE | Must bind serial |
| Edge Paint | 3 rounds | EDGE-PAINT | Auto-consume |
| Lining Panel | 1 set | CUT | Produces child tokens |
| Logo Hardware | 1 | ASSEMBLE | Binding required |

### 16.3 Rules
- Binding does NOT occur until assembly
- Cutting does NOT bind (batch)
- Every component must appear in BOM AND Node Requirement Mapping

---

## 17. Rework Rules by Node Behavior

Rework behavior depends on the node.

### 17.1 Table

| Behavior | Rework Type | Go-To Node | Notes |
|----------|-------------|------------|-------|
| CUT | Manual recut | Manual node | Typically rare |
| EDGE-PAINT | Re-round | same node | Uses remaining rounds |
| STITCH | Re-stitch | rework node | New token or same token |
| ASSEMBLE | Unbind + rebind | rework node | Component mismatch rules |
| QC | Re-inspect | dedicated QC rework node | Must log fail code |
| PACK | Reject & repeat | same node | Simple loop |

### 17.2 Rework Limit
Token tracks:
- rework_count
- rework_history

Hard limit:
- default 3 (configurable)

---

## 18. Token Lifecycle Diagram

Minimal lifecycle:

```
CREATED
   ↓
ACTIVE → PAUSED → RESUMED
   ↓
COMPLETED → (FAIL → REWORK) → ACTIVE
   ↓
FINISHED
```

Rules:
- Only QC can generate rework
- Rework always moves to a dedicated node
- Token history must be immutable

---

## 19. Dispatch + Skill Routing

Worker assignment must follow rules:

### 19.1 Required Matching
- skill_type must match node behavior
- skill_level must meet minimum threshold
- supports_batch/single must match node mode

### 19.2 Auto-Routing (future)
- System can suggest workers based on:
  - past performance
  - throughput
  - skill similarity
  - fatigue model (later)

### 19.3 Workload Balancing
Work Center capacity integrates with:
- queue size
- worker count
- node duration estimate
---

**Source:** [DAG_Blueprint.md](DAG_Blueprint.md)  
**Last Updated:** December 2025

