# Hatthasilpa Pool–Token Integration Canonical Spec

**Status:** CANONICAL (Derived from Hatthasilpa Canonical Production Spec v1.0)  
**Date:** 2026-01-21  
**Version:** 1.0  
**Category:** SuperDAG / Canonical / Hatthasilpa

This document defines the canonical integration layer that allows:

- Legacy token-oriented planning and downstream per-token work
- Canonical pool-first physical reality (pre-binding)

to coexist **without violating Hatthasilpa Canonical Production Spec v1.0**.

If any statement in this document conflicts with Hatthasilpa Canonical Production Spec v1.0, this document is invalid by definition.

---

# 1. Scope & Non-goals

## 1.1 Scope

This specification defines:

- The canonical ontology and invariants required for **Pool-first reality** and **Token-as-intent** to coexist.
- A conceptual **Visibility Engine** that projects Work Queue cards deterministically from Pool + Demand + Graph topology.
- Canonical node contracts for:
  - Batch Nodes (`pool_mode=transform`)
  - Binding Nodes (`pool_mode=allocate`)
- A conceptual, phase-based migration strategy from legacy token-flow visibility to pool-derived visibility.

## 1.2 Non-goals

This specification explicitly does NOT define:

- Implementation details (schemas, APIs, UI layouts, algorithms in code).
- Refactors of any existing subsystem.
- Timer/session mechanics beyond the requirement that they remain **behavior-scoped** and do not become pool SSOT.
- Graph “execution logic” (Graph Designer is topology only).
- Any permission system or enforcement system derived from Work Queue.

## 1.3 Relationship to Hatthasilpa Canonical Production Spec v1.0

- Hatthasilpa Canonical Production Spec v1.0 is Level 0 law (“physics”).
- This document is a **compatibility and integration canonical layer** that:
  - Restates required canonical invariants.
  - Adds integration-specific invariants to prevent token-flow assumptions from reappearing.
  - Defines how legacy token-centric systems may exist **only as projections and planning artifacts** prior to binding.

---

# 2. Core Ontology Definitions

This section defines what each concept IS and IS NOT, plus explicit forbidden behaviors.

## 2.1 Pool

### 2.1.1 Pool IS

**Pool = SSOT of physical reality before binding.**

Pool represents anonymous, swappable component quantities that exist in the physical world prior to identity formation.

- **Pool Scope Key (canonical):** `(product_model_id, bom_version_id, component_code, state)`
- Pool stores **quantity only** (no serial ownership, no token ownership).
- Pool accepts **overcut/extra usable parts** as valid stock.
- Pool quantities must never go negative.

### 2.1.2 Pool IS NOT

Pool is not:

- A token reservation system.
- A per-token WIP tracker.
- A permission gate (“pool empty” must not be treated as “work forbidden”).
- A workflow engine.

### 2.1.3 Pool invariants

- **Non-negativity:** `quantity_on_hand >= 0` must always hold.
- **Reality-sourced:** pool changes only occur from recorded reality events.
- **BOM scoping:** pools are scoped to `bom_version_id` by default; cross-version consumption is disallowed unless an explicit deterministic compatibility mapping exists.

### 2.1.4 Forbidden behaviors (Pool)

- **Forbidden:** any “soft binding” or reservation that prevents other jobs from consuming pool without an allocation.
- **Forbidden:** creating token/component ownership from any pool event other than `pool_mode=allocate` at a Binding Node.
- **Forbidden:** allowing pool quantity to go negative by implicit borrowing.

## 2.2 Token

### 2.2.1 Token IS

**Token = Cognitive Orchestrator** (not a physical item, not a ticket).

A token represents:

- Production intent (planned units, job context).
- Logical completeness targets.
- Serial identity as a planning identity, not ownership, prior to binding.
- A reconciliation target that interprets reality **after the fact** using pool and events.

**Token authority boundary (canonical):** token becomes identity-forming only at Binding Nodes (assembly/merge or equivalent).

### 2.2.2 Token IS NOT

Token is not:

- A physical bag before binding.
- A representation of pre-binding ownership.
- A command to artisans.
- The SSOT of early-stage production reality.

### 2.2.3 Forbidden behaviors (Token)

- **Forbidden:** using token lifecycle state to imply physical completion of batch work.
- **Forbidden:** requiring token/serial selection in any Batch Node.
- **Forbidden:** decrementing pool quantities “because tokens advanced.” Pool is changed only by reality events and allocation.
- **Forbidden:** spawning downstream tokens as a release mechanism from batch work.

## 2.3 Work Queue

### 2.3.1 Work Queue IS

Work Queue (Hatthasilpa) is:

- A **suggestion + aggregation tool**.
- A projection layer that summarizes:
  - Demand (intent)
  - Physical availability (pool)
  - Node opportunities implied by topology

It is explicitly tolerant of artisans working ahead or out of order.

### 2.3.2 Work Queue IS NOT

Work Queue is not:

- A command list.
- A permission system.
- A strict execution order.
- Evidence that work did or did not happen.

### 2.3.3 Forbidden behaviors (Work Queue)

- **Forbidden:** treating a queue card’s absence as forbidding work.
- **Forbidden:** using Work Queue readiness to authorize actions (authorization must not be derived from a projection).

## 2.4 Node Visibility vs Node Transition

### 2.4.1 Node Visibility (definition)

**Node Visibility** is a deterministic, read-only projection: whether a node/card should appear in Work Queue given:

- Current pool quantities and states
- Current demand (planned tokens/units)
- Graph topology and node classification

Node Visibility must not imply that any physical transformation has occurred.

### 2.4.2 Node Transition (definition)

**Node Transition** is a change in physical reality that is recorded as events:

- For Batch Nodes: `pool_mode=transform` events that move quantities between pool states.
- For Binding Nodes: `pool_mode=allocate` events that create ownership.

Node Transition is never caused by token movement.

### 2.4.3 Forbidden conflations

- **Forbidden:** “token moved to next node” being treated as a node transition.
- **Forbidden:** “queue shows next node” being treated as proof of completion.

---

# 3. Canonical Invariants (Extended)

This section restates canonical invariants and adds integration invariants required for safe coexistence.

## 3.1 Canonical invariants (must always hold)

- **Batch nodes never bind.**
  - Violating this breaks physical reality because early work is anonymous and swappable.
- **Only Binding Nodes allocate.**
  - Violating this creates ownership before the physical process supports it.
- **Release moves quantities between pools, never tokens.**
  - Violating this reintroduces token-flow as a hidden command layer.
- **Overcut goes into pool, not waste.**
  - Violating this contradicts observed reality: usable extra parts exist and are used.
- **Token identity begins at assembly, not cutting.**
  - Violating this forces per-token tracking too early.
- **Graph validates meaning, not command execution.**
  - Violating this turns topology into a workflow engine.
- **Work Queue suggests; artisans decide.**
  - Violating this contradicts reality: artisans work ahead to maintain flow.

## 3.2 Integration invariants (required for Pool–Token coexistence)

- **I-PT1 — Pool is authoritative pre-binding; token state is non-authoritative pre-binding.**
  - Violation causes the system to “believe” an idealized flow instead of observing reality.
- **I-PT2 — Pre-binding completion can only be inferred from pool states, not token lifecycle.**
  - Violation reintroduces hidden flow assumptions.
- **I-PT3 — Any projection derived from tokens must be allowed to be wrong without blocking work.**
  - Violation turns planning artifacts into commands.
- **I-PT4 — Allocation is the first moment ownership exists; before allocation, no token may be treated as owning components.**
  - Violation creates soft binding.
- **I-PT5 — Queue projection must be deterministic and read-only.**
  - Violation makes visibility computation an execution trigger.

---

# 4. Visibility Engine (Conceptual System)

This section defines a conceptual subsystem that computes Work Queue visibility without triggering execution.

## 4.1 Purpose

The Visibility Engine exists to:

- Produce a deterministic Work Queue projection from Pool + Demand + Graph topology.
- Provide read-only reconciliation outputs (need/done/remaining, readiness counts).
- Make node visibility independent of token movement.

## 4.2 Inputs

The Visibility Engine consumes only read-only inputs:

- **Graph topology**: nodes, edges, and node classification (Batch vs Binding).
- **BOM requirements**: component quantities per unit and required states per node output.
- **Pool snapshot**: quantities per `(product_model_id, bom_version_id, component_code, state)`.
- **Demand snapshot**: planned unit demand grouped by product model and BOM (tokens may exist as intent).
- **Assignment snapshot (optional)**: used for grouping cards, never as permission.

## 4.3 Outputs

The Visibility Engine outputs projections only:

- **Queue cards**:
  - Batch cards: group-level
  - Binding cards: token-level
- **Deterministic quantities** (projection-only):
  - `required_units`, `completed_units`, `remaining_units`
  - Binding readiness counts (“how many tokens can allocate now”)
- **Explainability fields** (conceptual):
  - Which pool keys drove readiness
  - Which missing pool keys prevented readiness

## 4.4 Deterministic rules

### 4.4.1 Batch card aggregation

Batch cards must aggregate demand at the group level (never 1 card per token for CUT-class batch work).

- `required_units = Σ planned_qty` for the group.
- `completed_units` is derived by pool availability for the node’s output state(s):
  - For each required component pool key at that output state:
    - `units_available(component) = floor(pool_qty(component, state) / bom_qty_per_unit)`
  - `completed_units = min(units_available(component) for all required components)`
- `remaining_units = max(required_units - completed_units, 0)`

These are projections only.

### 4.4.2 Binding readiness

A token is “binding-ready” (visible at Binding Node) if and only if:

- All required component pools can allocate one full unit per BOM **at that moment**.

This is computed from the same allocatability rule used for readiness counts.

## 4.5 Error tolerance

The Visibility Engine must be safe under incomplete or conflicting evidence:

- If any required input is missing or ambiguous, the engine must output an **unknown / insufficient evidence** readiness status rather than fabricating certainty.
- Under uncertainty, the engine must:
  - continue to function as a suggestion layer
  - avoid hiding reality behind false precision

When uncertainty exists, the correct label is: **INSUFFICIENT EVIDENCE**.

## 4.6 Why it MUST NOT trigger execution

The Visibility Engine is a projection layer only.

- It must not create sessions.
- It must not mutate tokens.
- It must not mutate pools.
- It must not allocate.

Any of the above would turn visibility into a hidden command channel, violating canonical law that ERP must observe reality and that artisans decide.

---

# 5. Node Contract Definitions

## 5.1 Batch Node Contract (pool_mode=transform)

Batch nodes exist where work is done in piles/baskets and output remains anonymous.

### 5.1.1 Allowed reads

- Pool snapshot (for current availability and reconciliation).
- BOM requirements and node output state definition.
- Demand snapshot (for required units aggregation).
- Graph topology (to determine upstream/downstream relationships).

### 5.1.2 Allowed writes

- Pool events with `pool_mode=transform` only:
  - `POOL_TRANSFORM`
  - `POOL_MOVE`
  - `POOL_SCRAP`
  - `POOL_ADJUST`

### 5.1.3 Forbidden actions

- Binding components to tokens.
- Requiring token/serial selection.
- Performing allocation.
- Spawning downstream tokens as a result of batch release.

### 5.1.4 Emitted events (canonical taxonomy)

All pool changes must emit events including: `pool_key`, `delta_qty`, `reason_code`, `actor_id`, `event_time`.

Batch nodes emit only `pool_mode=transform` events.

### 5.1.5 Effect on downstream visibility

- Batch node work affects downstream visibility only by changing pool quantities/states.
- No downstream visibility is created by token movement.

## 5.2 Binding Node Contract (pool_mode=allocate)

Binding nodes are identity-forming: the first step where work becomes a bag-in-progress and part swapping is no longer realistic.

### 5.2.1 Preconditions

- A specific token/serial must be selected **before work begins**.
- All required component pools must be allocatable for one unit per BOM at the moment of allocation.

### 5.2.2 Allocation rules

- Allocation is deterministic (policy must be defined and recorded).
- Allocation deducts from pool and must preserve non-negativity.
- Cross-BOM allocation is disallowed unless an explicit compatibility mapping exists and is recorded.

### 5.2.3 Ownership creation

- Ownership is created only by `POOL_ALLOCATE` (`pool_mode=allocate`).
- Allocation creates a ledger linking components to the token.
- Prior to allocation, token identity is planning-only.

### 5.2.4 Container requirements (canonical)

After binding:

- Every WIP must be assigned to a token-bound container.
- Containers must never mix tokens.
- Container assignment becomes mandatory for QC, rework, and time tracking.

### 5.2.5 Token involvement

- Token is required for identity and ownership only at binding and post-binding stages.
- Token must not be used to simulate pre-binding ownership.

---

# 6. Canonical Flow WITHOUT Token Movement

This section explains how the system functions without assuming token flow controls execution.

## 6.1 Why nodes appear without token flow

Nodes appear in Work Queue because visibility is computed from:

- **Demand (intent)**: there exists planned need for units at a node context.
- **Pool (reality)**: there exists or could exist physical quantity in relevant states.
- **Topology (meaning)**: the graph defines what kinds of work nodes exist and how pool states relate.

Visibility is therefore a reconciliation of “what we intend to make” against “what physically exists now,” not a token transition.

## 6.2 How downstream nodes become visible

Downstream nodes become visible when pool evidence satisfies the Visibility Engine rules for that node:

- Batch downstream nodes become relevant when their input/output pool states are involved in remaining demand.
- Binding nodes become visible at token-level only when allocatability exists for a full unit.

No token is required to move into a downstream node to make it visible.

## 6.3 Why release never spawns tokens

Release is a physical reality event that moves quantities between pool states.

Spawning tokens on release would:

- Treat tokens as physical items.
- Reintroduce hidden flow-based execution control.
- Violate canonical law that release moves quantities between pools, never tokens.

Therefore:

- Release is a pool movement/transform event only.
- Tokens remain planning/orchestration constructs and are reconciled against pool afterward.

## 6.4 How overcut crosses jobs safely via pool

Overcut is valid physical stock.

- Overcut increases pool quantities in the relevant pool key.
- Because pool is anonymous pre-binding, any compatible demand (same scope key, or explicit compatibility mapping) may later allocate from that pool at binding.
- No ownership is attributed to the job that produced the overcut.

## 6.5 How assembly readiness is determined

Assembly (Binding Node) readiness is determined by allocatability:

- A token is assembly-ready if all required component pools can allocate one full unit per BOM at that moment.

This readiness is a **projection** and must not be treated as permission.

---

# 7. Migration Strategy (Conceptual Only)

This section defines a phase-based migration strategy. It does not prescribe implementation.

## Phase 0: Legacy observation

- **What remains**:
  - Legacy token lifecycle and token-based visibility may still exist.
- **What is deprecated**:
  - None yet.
- **Invariants enforced**:
  - Declare the canonical truth: legacy visibility is not authoritative for pre-binding reality.
  - Begin labeling any token-derived pre-binding status as projection-only.

## Phase 1: Pool mirrors reality

- **What remains**:
  - Legacy token systems continue to operate.
  - Pool begins to receive reality events for batch work.
- **What is deprecated**:
  - Any assumption that token status is SSOT for batch completion.
- **Invariants enforced**:
  - Pool non-negativity.
  - Batch nodes emit transform-only pool events.

## Phase 2: Visibility Engine replaces token-flow visibility

- **What remains**:
  - Tokens still exist as intent.
- **What is deprecated**:
  - Work Queue visibility derived from token lifecycle for Hatthasilpa pre-binding stages.
- **Invariants enforced**:
  - Work Queue is computed from Pool + Demand + Graph topology.
  - Visibility Engine is read-only and deterministic.

## Phase 3: Pool-based release

- **What remains**:
  - Token planning and post-binding per-token workflows.
- **What is deprecated**:
  - Any release mechanism that spawns downstream tokens.
- **Invariants enforced**:
  - Release moves quantities between pools only.
  - Overcut is recorded into pools.

## Phase 4: Token reduced to post-binding only

- **What remains**:
  - Tokens exist for binding and post-binding stages.
  - Pre-binding stages are pool-first.
- **What is deprecated**:
  - Token-driven orchestration semantics in pre-binding.
- **Invariants enforced**:
  - Token authority begins at binding.
  - Pre-binding SSOT is pool.

---

# 8. Failure Modes & Self-Audit

This section lists failure modes and why they do not violate canonical law, plus undefined areas.

## 8.1 Failure modes

1) **Failure mode: Work Queue shows no card, artisans still work**
- **Why it does not violate canonical law**: queue is suggestion-only; artisans decide; system reconciles after the fact.

2) **Failure mode: Pool shows surplus (overcut) exceeding planned demand**
- **Why it does not violate canonical law**: overcut is valid stock and must enter pool; surplus reflects reality.

3) **Failure mode: Legacy token status contradicts pool (token says done, pool says not available)**
- **Why it does not violate canonical law**: pre-binding authority is pool; token status is projection-only.

4) **Failure mode: Parallel branches produce imbalanced states (EDGE ready, SKIVE not ready) delaying binding readiness**
- **Why it does not violate canonical law**: binding readiness is physical allocatability; no node commands another.

5) **Failure mode: Attempted early reservation (“soft binding”) to secure scarce parts**
- **Why it does not violate canonical law (when prevented)**: soft binding is forbidden; only allocation creates ownership.

## 8.2 What remains undefined (INSUFFICIENT EVIDENCE)

- **Pool state taxonomy**: the complete canonical list of pool `state` values per component.
- **Node-to-state mapping**: how every node in arbitrary graphs defines its output and required input pool states.
- **Allocation policy**: the mandatory deterministic allocation policy (FIFO or other) and how it varies by component.
- **Location scoping**: whether physical location/work center must be part of PoolKey.
- **Token cancellation/plan change**: how demand reductions should affect queue projections.

---

# 9. Versioning & Change Protocol

This document is canonical and must follow strict change control.

## 9.1 Versioning rules

- Any semantic change requires a **version bump**.
- Each version must record:
  - date
  - author
  - rationale tied to physical reality
  - migration note describing scope and impact

## 9.2 Justification doctrine

Changes are valid only if justified by:

- Observed Hatthasilpa physical production reality, or
- Correction of an inconsistency with Hatthasilpa Canonical Production Spec v1.0

System convenience is not a valid reason.

## 9.3 Canonical integrity preservation

- If conflict is discovered between this document and Hatthasilpa Canonical Production Spec v1.0:
  - Hatthasilpa Canonical Production Spec v1.0 prevails.
  - This document must be updated with a version bump to restore consistency.
- No silent edits.
- If evidence is insufficient to define a rule, it must remain explicitly labeled **INSUFFICIENT EVIDENCE** until physical reality or canonical law resolves it.
