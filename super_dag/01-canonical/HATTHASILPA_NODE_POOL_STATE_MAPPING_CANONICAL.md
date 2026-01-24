# Hatthasilpa Node ↔ Pool State Mapping Canonical Spec

**Status:** CANONICAL (Must not conflict with Hatthasilpa Canonical Production Spec v1.0)  
**Date:** 2026-01-21  
**Version:** 1.0  
**Category:** SuperDAG / Canonical / Hatthasilpa

This document defines the deterministic mapping between **Node semantics** and **Pool state taxonomy** for Hatthasilpa.

If any statement in this document conflicts with:

- `docs/super_dag/01-canonical/HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` (v1.0)
- `docs/super_dag/01-canonical/HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md`

then this document is invalid by definition.

---

# 1. Scope & Purpose

## 1.1 Purpose

Pool state taxonomy is required because:

- Pool is SSOT of physical reality before binding.
- Visibility Engine must project Work Queue deterministically from Pool + Demand + Graph topology.
- Deterministic visibility requires deterministic interpretation of pool `state`.

Without an explicit state taxonomy and node↔state contract, engineers would be forced to guess what “ready” means, which is forbidden.

## 1.2 Scope

This specification defines:

- The canonical meaning of Pool `state`.
- The canonical rules for state validity and state transitions.
- A deterministic contract mapping Node types to:
  - required input pool states
  - produced output pool states
  - `pool_mode` obligations
- Deterministic handling of parallel and optional processing without token-flow assumptions.
- How missing or ambiguous state evidence must be labeled **INSUFFICIENT EVIDENCE**.

## 1.3 Non-goals

This specification does NOT define:

- Implementation details (schemas, APIs, code, UI screens).
- Permission logic.
- Any “execution engine” or command semantics.
- A full, exhaustive list of every possible state for every component in the business.

If a state or mapping cannot be defined deterministically by canonical law and physical reality, it must remain **INSUFFICIENT EVIDENCE**.

## 1.4 Relationship to Visibility Engine and Graph topology

- Graph topology is neutral: it declares nodes/edges only and must not command execution.
- Node↔Pool State mapping is **semantic meaning**, not execution ordering.
- Visibility Engine is read-only and uses this mapping to compute deterministic projections.

---

# 2. Canonical Definition of Pool State

## 2.1 What a `state` IS

A Pool `state` is:

- A **physically meaningful condition** of an anonymous component quantity.
- A statement about what pile/basket/rack the component belongs to, based on observed processing.
- A deterministic label that allows the system to answer:
  - “Can these parts be used as inputs to a node?”
  - “Have these parts passed a specific batch process?”

`state` is part of the Pool SSOT key:

- `(product_model_id, bom_version_id, component_code, state)`

Therefore `state` must be stable, auditable, and deterministic.

## 2.2 What a `state` IS NOT

A Pool `state` is not:

- A token lifecycle stage.
- A UI label or user convenience tag.
- A permission flag.
- An instruction to artisans.
- A hidden proxy for execution order.

## 2.3 State validity rules

A `state` value is valid only if all are true:

- **S1 — Physical meaning:** it corresponds to a physically meaningful segregation of parts.
- **S2 — Deterministic interpretation:** two independent observers must interpret the state the same way.
- **S3 — Node-defined:** it is used as an input/output by at least one node contract.

If a proposed `state` lacks any of S1–S3, it is invalid.

## 2.4 State transition rules

- **T1 — Transitions occur only via recorded physical reality events** that mutate Pool quantities.
- **T2 — Batch nodes transition quantities using `pool_mode=transform` only.**
- **T3 — Binding nodes transition quantities using `pool_mode=allocate` only (ownership creation).**
- **T4 — A state transition must never be inferred from token movement.**

---

# 3. Node → Pool State Contract

This section defines canonical node types and their required/produced pool states.

## 3.1 Canonical state naming doctrine (normative)

This document defines the following state naming doctrine for Hatthasilpa pool states:

- States must be **process-and-condition specific**.
- States must be **readable and stable**.

The canonical form is:

- `<process_code>_ready`

Where `<process_code>` is the node’s canonical process identity (e.g., `cut`, `skive`, `edge`).

This doctrine is required so that the Visibility Engine can interpret state meaning deterministically.

If a process requires additional physical segregation (e.g., hold/rework), such states are allowed only if their physical meaning is explicit and stable.

If additional states cannot be defined deterministically, they must remain **INSUFFICIENT EVIDENCE**.

## 3.2 Generic Batch Node (pool_mode=transform)

### Required input pool states

- **Mandatory:** Exactly one upstream input state set must be declared by the node’s semantic contract.
- If the upstream input state set is not declared deterministically, node visibility and transition meaning are **INSUFFICIENT EVIDENCE**.

### Produced output pool states

- **Mandatory:** exactly one primary output state must be declared.

### pool_mode

- **Required:** `transform`

### Input state consumption rules

- **Mandatory inputs:** quantities in the declared input states are the only quantities eligible to be transformed by this node.
- **Partially consumable:** allowed; batch work may transform any subset quantity.

### Forbidden behaviors

- Binding to a token.
- Requiring serial selection.
- Creating ownership.
- Mutating pool state by token lifecycle.

## 3.3 Generic Binding Node (pool_mode=allocate)

### Required input pool states

- **Mandatory:** for each required BOM component, a required input state (or explicit acceptable set) must be defined.
- If the required input state(s) cannot be determined, readiness is **INSUFFICIENT EVIDENCE**.

### Produced output pool states

- Binding nodes do not “produce anonymous output states” as their primary semantic action.
- Their canonical output is **ownership creation** (allocation ledger linking components to token).

### pool_mode

- **Required:** `allocate`

### Input state consumption rules

- **Mandatory:** allocation must deduct quantities from pool.
- **Non-negativity required:** allocation must never cause negative pools.

### Forbidden behaviors

- Soft binding or reservation.
- Allocation without token selection.
- Treating queue visibility as permission.

## 3.4 CUT (Batch)

### Required input pool states

- **INSUFFICIENT EVIDENCE**.

Reason: Hatthasilpa canonical v1.0 defines Pool as component pool SSOT, but does not define whether and how raw material inventory is represented as a Pool state/key.

### Produced output pool states

- **Mandatory output state:** `cut_ready`

Meaning:

- Anonymous components have been cut and are physically available as cut parts.

### pool_mode

- **Required:** `transform`

### Input mandatory/optional/partial

- **Input state definition:** **INSUFFICIENT EVIDENCE**.
- **Output partial production:** permitted (batch may produce any quantity).

### Forbidden behaviors

- Per-token cutting as the canonical unit of execution.
- Token ownership creation.
- Token selection requirements.

## 3.5 SKIVE (Batch)

### Required input pool states

- **Mandatory input state:** `cut_ready`

### Produced output pool states

- **Mandatory output state:** `skived_ready`

### pool_mode

- **Required:** `transform`

### Input mandatory/optional/partial

- **Partially consumable:** allowed.
- If only some component codes require skive, this must be expressed via BOM component requirements (component_code-level), not per-token selection.

### Forbidden behaviors

- Binding or allocation.
- Token selection.

## 3.6 EDGE (Batch)

### Required input pool states

- **Mandatory input state:** one of the following must be chosen explicitly per component/node contract:
  - `cut_ready`, or
  - `skived_ready`

If the input state choice is not declared deterministically, the mapping is **INSUFFICIENT EVIDENCE**.

### Produced output pool states

- **Mandatory output state:** `edged_ready`

### pool_mode

- **Required:** `transform`

### Input mandatory/optional/partial

- **Partially consumable:** allowed.

### Forbidden behaviors

- Implicitly assuming EDGE always happens after SKIVE.
- Token selection.
- Binding.

## 3.7 QC (pre-binding, Batch)

### Required input pool states

- **INSUFFICIENT EVIDENCE**.

Reason: Hatthasilpa canonical v1.0 establishes QC as an early-stage reality, but does not define a canonical pre-binding QC state taxonomy (pass/hold/scrap) or whether QC is represented as a pool state transition versus a separate quality ledger.

### Produced output pool states

- **INSUFFICIENT EVIDENCE**.

### pool_mode

- **Required:** `transform` (because QC is explicitly pre-binding in this node class).

### Forbidden behaviors

- Token binding.
- Token-based proof of batch completion.

## 3.8 ASSEMBLY (Binding)

### Required input pool states

- **Mandatory:** For each required BOM component, an explicit required input state (or acceptable set) must exist.

This document does not impose a single universal assembly input state.

Reason:

- Different components may require different last-batch states (e.g., some are `cut_ready`, others may be `edged_ready`).
- Imposing a single state would force hidden assumptions and break determinism.

If the required input states per component are not explicitly defined, binding readiness is **INSUFFICIENT EVIDENCE**.

### Produced output pool states

- None (primary effect is allocation/ownership creation).

### pool_mode

- **Required:** `allocate`

### Input mandatory/optional/partial

- **Mandatory:** allocation consumes pool quantities for each required component.
- **Partial binding across a single unit:** forbidden (a token cannot be “half allocated” and treated as bound).

### Forbidden behaviors

- Allocation without token/serial selection.
- Reservation/soft binding.
- Treating allocatability projection as permission to work.

---

# 4. Parallel & Optional Processing

## 4.1 Parallel nodes

Parallel processing is permitted because:

- Graph topology is neutral.
- Batch nodes are non-binding and only transform pool states.

Canonical rule:

- Parallel nodes must each declare:
  - their input state(s)
  - their output state

No parallel edge implies a required ordering.

## 4.2 Optional steps

Optional processing must be represented without ambiguity.

Canonical rule:

- Optionality must be expressed at the **BOM component requirement level** (component_code-level) or via an explicit acceptable-state set for a binding requirement.

Forbidden:

- Per-unit optionality that cannot be expressed deterministically.

If a product requires “some units get skive, some units do not” within the same BOM and without a deterministic selector, this is **INSUFFICIENT EVIDENCE**.

---

# 5. State Compatibility & Reuse

## 5.1 Compatibility across jobs

Pool states are reusable across jobs only when the PoolKey matches:

- `(product_model_id, bom_version_id, component_code, state)`

This is canonical because Pool is anonymous and SSOT pre-binding.

## 5.2 Forbidden compatibility

- Cross-`bom_version_id` reuse is forbidden unless an explicit deterministic compatibility mapping exists.
- Cross-`product_model_id` reuse is forbidden.
- Reuse across different `component_code` is forbidden.
- Reuse across different `state` is forbidden unless an explicit acceptable-state set is defined.

If compatibility is not explicitly defined deterministically, it is **INSUFFICIENT EVIDENCE**.

## 5.3 Overcut and reuse

Overcut is valid and must enter pool as additional quantity in the appropriate output state (e.g., `cut_ready`).

Overcut reuse is therefore safe and canonical because:

- It does not create ownership.
- It does not move tokens.
- It is consumed only by binding allocation.

---

# 6. Visibility Interaction

This section defines how pool state availability interacts with visibility computations.

## 6.1 Batch visibility

Batch node visibility depends on:

- Demand evidence (`required_units > 0`), and
- State evidence that the node is relevant (remaining demand exists and/or upstream quantities exist in declared input states).

If state evidence cannot be computed because:

- required input/output states are not defined, or
- pool keys are ambiguous,

then visibility must be labeled **INSUFFICIENT EVIDENCE**.

## 6.2 Binding readiness

Binding readiness is allocatability:

- For every required BOM component, pool quantity at the required state(s) must be sufficient for one unit without going negative.

If allocatability cannot be computed deterministically due to undefined required states, readiness must be labeled **INSUFFICIENT EVIDENCE**.

---

# 7. Forbidden Patterns

The following patterns are canonically invalid:

- **State mutation via token flow:** any logic where token lifecycle changes imply pool state transitions.
- **Implicit state assumptions:** e.g., assuming EDGE always follows SKIVE without explicit state contracts.
- **UI-defined states:** any state taxonomy defined by UI convenience rather than physical meaning.
- **Queue-defined states:** any state inferred from what appears in Work Queue.
- **Token-based proof of batch completion:** using token status as evidence that pool has been transformed.

---

# 8. Open Questions / Insufficient Evidence

The following are not fully defined by existing canonical law and must remain explicitly unresolved:

- **Raw material representation for CUT inputs:** whether and how raw materials are represented as pool states/keys.
- **Pre-binding QC taxonomy:** whether QC creates pool state partitions (pass/hold) or is represented elsewhere while still remaining non-binding.
- **Full state catalog per component family:** the exhaustive list of physical states across all atelier processes.
- **Location scoping doctrine:** whether pool must be location-scoped to reflect physically separated baskets across work centers.
- **Rework loops pre-binding:** whether rework creates additional states or is modeled as adjustments/transforms.

Until resolved, any engineer-facing system must label the relevant computations as **INSUFFICIENT EVIDENCE** and must not invent or infer missing state mappings.
