# Hatthasilpa Canonical Production Spec

**Status:** Canonical Source of Truth (Law of Physics)  
**Date:** 2026-01-18  
**Version:** 1.0  
**Category:** SuperDAG / Canonical / Hatthasilpa

**Scope:** Hatthasilpa only (atelier workflow)  
**Intent:** Lock production ontology so implementation follows physical reality, not idealized command flow.

---

## ⚠️ Non-negotiable Canonical Law
Any implementation, schema, UI, or logic that contradicts this document is invalid by definition, regardless of legacy behavior or system convenience.

## Core Reality (Non-negotiable)
- Artisans do **not** work per bag/serial in early stages.
- Cutting, edging, splitting, preparation happen in batches (piles/baskets).
- Artisans often work ahead of system suggestion to maintain flow.
- Tracking individual components before assembly is unrealistic and harmful.
- ERP must follow reality; it does not command it.

---

## Canonical Versioning & Change Protocol
- Canonical changes require an explicit **version bump**.
- Every change must include a **reason tied to physical reality** (not system convenience).
- If a canonical change impacts behavior/spec/implementation, add a **migration note** with scope and impact.
- No silent edits: record date, author, and rationale in the version history.

## A) Terminology & Canonical Definitions

### A.1 Token (Parent Token)
**Token = Cognitive Orchestrator** (not a physical item, not a ticket).
- Represents production intent and logical completeness.
- Owns serial identity but does **not** embody physical ownership before binding.
- Interprets reality from events + pools **after the fact**.
- Does **not** command artisans; it is not permission.

### A.2 Work Queue (Hatthasilpa Only)
Work Queue is a **suggestion + aggregation tool** (never a command list).
- Tokens with same product + BOM + node + artisan are grouped into one card.
- CUT queue must **never** show 1 card per token.
- CUT queue shows **group progress**, not serial identity.

### A.3 Pool (Component Pool)
**Pool = SSOT of physical reality before binding.**

**Pool Scope Key:** `(product_model_id, bom_version_id, component_code, state)`
- Stores quantity only (no serial ownership).
- Accepts overcut/extra usable parts as valid stock.
- Anonymous until binding.
- Must never go negative.

#### A.3.1 pool_mode Contract
`pool_mode` is the canonical contract for how pool quantities change:
- `transform`: batch state transitions (non-binding). Used by Batch Nodes to move/transform pool quantities across states or component outputs without creating ownership.
- `allocate`: binding ownership creation. Used only by Binding Nodes to deduct from pool and link components to a token.

**Rule:** Batch Nodes must use `pool_mode=transform`; Binding Nodes must use `pool_mode=allocate`.

### A.4 Batch Node (Non-binding Node)
Batch node if work can be done in piles/baskets and output remains anonymous.
- Records events → updates pool.
- May transform pool state.
- **Must NOT bind to token.**
- **Must NOT require serial selection.**

Examples: CUT, SKIVE/SPLIT, EDGE PAINT (batch), PREP/PRIMER, hardware prep (batch).

### A.5 Binding Node (Identity-forming Node)
Binding node if identity begins and component swapping is no longer realistic.
- Binding starts **only here**, never earlier.
- Token/Serial **must be selected before work begins**.
- Components **must be allocated from pool**.
- From this point on, work is per-token.

**Type B (Identity-forming) Binding Definition:**
Binding starts at the **first step where work becomes a bag-in-progress** (assembly/merge or equivalent). Nodes that are batch-order and still anonymous remain non-binding even if they touch parts (e.g., EDGE, SPLIT/SKIVE, HARDWARE PREP). These must continue to operate as `pool_mode=transform`.

### A.6 Allocation (Binding Mechanism)
Allocation is the only operation that creates ownership.
- Deducts quantities from pool.
- Creates ledger linking components → token.
- Happens only at Binding Nodes.
- Deterministic policy (FIFO or defined rule).

### A.7 Basket / Container
Physical baskets must mirror logic.
- **Before Binding:** anonymous/shared/pool-based.
- **After Binding:** token-bound, no mixing, required for QC/rework/timing.
- **Container contract:** after binding, every WIP must be assigned to a token-bound container; containers must never mix tokens; container assignment is mandatory for QC, rework, and time tracking.

### A.8 Canonical Invariants (Must Always Hold)
1) Batch nodes never bind.
2) Only binding nodes allocate.
3) Release moves quantities between pools, never tokens.
4) Overcut goes into pool, not waste.
5) Token identity begins at assembly, not cutting.
6) Graph validates meaning, not command execution.
7) Work Queue suggests; artisans decide.

---

## B) Node Classification Rules

### B.1 Batch Node Criteria (Non-binding)
Batch if **all** are true:
1) Work done in piles/baskets.
2) Output remains anonymous component.
3) Swapping parts between bags remains realistic.
4) Physical reality does not require serial association.

### B.2 Binding Node Criteria
Binding if **any** are true:
1) Bag identity begins (assembly/merge).
2) Components become inseparable into a specific bag.
3) Swapping parts is no longer realistic.
4) Serial must be selected for work to be meaningful.

---

## C) Pool & Allocation Model

### C.1 Pool Data Structure (Conceptual)
```
PoolKey:
  product_model_id
  bom_version_id
  component_code
  state

PoolRecord:
  quantity_on_hand >= 0
  last_updated_at
```

### C.2 Pool Invariants
- Quantity never negative.
- Only physical reality events change quantity.
- Tokens do not decrement pools directly (only allocation at binding).

### C.3 Allocation Ledger (Conceptual)
```
AllocationEntry:
  token_id
  pool_key
  quantity_allocated
  allocation_policy
  allocation_timestamp
```

### C.4 pool_mode Determinism
- `transform` events may move quantities between pool states or component outputs, but **never** create ownership.
- `allocate` events deduct quantities from pools and **must** reference a token and allocation policy.
- Mixed usage is invalid: a single event cannot be both transform and allocate.

### C.5 BOM Version Carry-forward Policy
- Pools are **strictly scoped** to `bom_version_id` by default.
- Cross-version use is **disallowed** unless an explicit compatibility mapping exists.
- Compatibility mapping must be deterministic and auditable (e.g., `bom_version_compatibility` reference).
- Allocation across versions must record the compatibility reference in the allocation ledger/event.

### C.6 Pool Event Taxonomy (Minimal Required Types)
All pool changes must emit canonical events with audit reasons. Minimum event types:
- `POOL_TRANSFORM`: batch transformation/state transition (pool_mode=transform).
- `POOL_MOVE`: non-binding movement between pool states (e.g., cut_ready → skived_ready).
- `POOL_ALLOCATE`: binding allocation to token (pool_mode=allocate).
- `POOL_SCRAP`: permanent reduction due to scrap/damage.
- `POOL_ADJUST`: manual correction with explicit reason code.

**Event Invariants:**
- Pools never negative (reject or compensate before event persist).
- Every event must include: `pool_key`, `delta_qty`, `reason_code`, `actor_id`, `event_time`.
- `POOL_ALLOCATE` must include `token_id` and allocation policy.
- `POOL_ADJUST` must include human-readable justification.

---

## D) Token Lifecycle (Hatthasilpa)

### D.1 Pre-binding Phase
- Token exists as **intent** only.
- No component ownership; pool is SSOT.
- Serial numbers may be reserved at job creation **for planning**, but do **not** imply ownership.

### D.2 Binding Phase (Assembly)
- Token identity begins.
- Token/serial selection required before work starts.
- Allocation creates ownership and decrements pool.

### D.3 Post-binding Phase
- Work is per-token.
- QC/rework/time tracking is token-bound.

---

## E) Work Queue Behavior

### E.1 General Queue Contract
- Suggestion only, never permission.
- Artisans may work ahead; system reconciles after the fact.

### E.2 CUT Queue
- Must show group card (never 1 card per token).
- Grouping dimensions: product_model + BOM + node + assigned artisan.
- Shows group progress, not serial identity.

### E.3 Binding/Assembly Queue
- Must show token-level cards (one per token).
- Serial selection required for action.

### E.4 Queue Reconciliation Algorithm (Deterministic)
Queue progress and readiness are derived from pool quantities and BOM requirements:

1) **Group Card Required Qty**
- `required_units = Σ planned_qty` for tokens in the group (product_model + bom_version + node + artisan).

2) **Completed Units (by pool availability)**
- For each component required by BOM at the node’s output state:
  - `units_available(component) = floor(pool_qty(component, state) / bom_qty_per_unit)`
- `completed_units = min(units_available(component) for all required components)`

3) **In-Progress / Remaining**
- `remaining_units = max(required_units - completed_units, 0)`

4) **Assembly Readiness (Binding Nodes)**
- A token is **assembly-ready** if **all** required component pools can allocate one full unit per BOM.
- Group readiness count = number of tokens that can be fully allocated from pools at that moment.

**Rule:** Queue numbers are projections only; they never block or authorize work.

---

## F) Real-world Scenarios (Canonical Behavior)

### F.1 Artisan Cuts Extra Parts
- Pool increases accordingly.
- Overcut is valid stock.
- No token ownership created.

### F.2 Artisan Works Ahead of Queue
- Events update pools.
- Tokens become ready **after** reality occurs.
- Queue never blocks.

### F.3 Partial Batch Released Forward
- Pool quantity moves between states (e.g., cut_ready → skived_ready).
- No token binding occurs.

### F.4 Assembly Begins With Limited Pool
- Allocation occurs deterministically for selected token(s).
- Pool decremented accordingly.
- Unallocated tokens remain unbound.

---

## G) Explicit Non-goals (Must Never Attempt)
1) Early serial tracking before binding.
2) Forced strict node-by-node execution.
3) Treating CUT as per-token work.
4) Treating queue as permission gate.
5) Token ownership created by batch nodes.
6) Negative pools or implicit borrowing.
7) Serial selection required in batch nodes.
8) Token equals physical bag before binding.
