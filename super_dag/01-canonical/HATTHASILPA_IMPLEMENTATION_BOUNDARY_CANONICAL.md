# Hatthasilpa Implementation Boundary Canonical Spec

**Status:** CANONICAL (Must not conflict with Hatthasilpa Canonical Production Spec v1.0)  
**Date:** 2026-01-21  
**Version:** 1.0  
**Category:** SuperDAG / Canonical / Hatthasilpa

This document defines the canonical boundary between:

- **POOL-FIRST CANONICAL LAW** (ontology and system physics)
- **EXISTING IMPLEMENTATION** (legacy token-flow-driven code paths)

If any statement in this document conflicts with:

- `docs/super_dag/01-canonical/HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` (v1.0)
- `docs/super_dag/01-canonical/HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_NODE_POOL_STATE_MAPPING_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_ALLOCATION_POLICY_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_REALITY_EVENT_CANONICAL.md`

then this document is invalid by definition.

---

# 1. Purpose of This Document

## 1.1 Why boundary definition is required

Boundary definition is required because:

- Canonical Hatthasilpa law defines the ontology of physical reality.
- Existing systems may contain legacy token-flow authority paths.
- Without an explicit boundary, developers may unintentionally reintroduce non-canonical assumptions.

This document exists to prevent silent canonical regression.

## 1.2 Risk of silent canonical regression

Silent regression occurs when:

- Token state is treated as proof of pre-binding completion.
- Work Queue visibility is treated as permission.
- Release spawns tokens or implies downstream execution.
- Token lifecycle is used as a proxy for pool state.

All of the above are canonically invalid.

---

# 2. Canonical Authority Layers

This section defines canonical layers of authority. Higher layers must never overwrite lower layers.

## 2.1 Reality (Events + Pool)

**Authority:** Highest for pre-binding reality.

- Reality is recorded by **Reality Events**.
- Pool is SSOT of physical reality pre-binding.

Canonical rule:

- If a projection or token claim conflicts with Pool, Pool prevails.

## 2.2 Projection (Visibility / Queue)

**Authority:** None (read-only).

- Work Queue and Visibility are projections.
- Projections must never mutate reality.

Canonical rule:

- Projection absence must never be treated as permission denial.

## 2.3 Intent (Token)

**Authority:** Planning-only pre-binding.

- Tokens represent intent and logical completeness.
- Tokens do not represent ownership pre-binding.

Canonical rule:

- Token is not SSOT for pre-binding reality.

## 2.4 Ownership (Allocation)

**Authority:** Ownership begins only at allocation.

- Allocation is Binding-Node-only.
- Allocation creates ownership by deducting from pool and linking to token.

Canonical rule:

- No ownership exists without allocation.

---

# 3. What Existing Token-Based Logic MAY Continue To Do

Existing token-based logic may continue only within the Intent/Projection boundary.

## 3.1 Acceptable token responsibilities

Token-based logic may:

- Represent demand as intent (planned units).
- Provide grouping keys for batch aggregation.
- Provide identity for post-binding WIP (after allocation).
- Support reporting and reconciliation views that are explicitly labeled as projections.

## 3.2 Token as intent / planning / grouping only

Canonical requirement:

- Any token-derived pre-binding value is a **projection**, not authority.
- Tokens must not be required for batch work execution.

---

# 4. What Existing Token-Based Logic MUST STOP Doing

This section defines forbidden token responsibilities.

## 4.1 Forbidden token responsibilities (non-negotiable)

Existing token-based logic must stop doing any of the following:

- Using token lifecycle as proof that batch work happened.
- “Moving tokens” to represent physical progression through batch nodes.
- Spawning downstream tokens as a consequence of release.
- Performing soft binding/reservation of pool quantities.
- Deducting pool quantities implicitly based on token status.
- Requiring token/serial selection in any batch node context.

## 4.2 Token behaviors that violate pool-first doctrine

Any behavior is invalid if it:

- causes pool mutation from token state,
- causes allocation without binding-node preconditions,
- causes queue visibility to become permission.

---

# 5. Event Authority Boundary

## 5.1 Mutations that must originate ONLY from reality events

The following mutations must originate only from canonical Reality Events:

- Any pool quantity change.
- Any pool state change.
- Any scrap or adjustment affecting usable quantities.
- Any allocation (ownership creation).

No other subsystem may directly author these mutations.

## 5.2 Projections must never write back

Canonical rule:

- Visibility/Queue projections must never write events.
- Any “projection feedback loop” that auto-creates events is forbidden.

---

# 6. Visibility Boundary

## 6.1 What Work Queue is allowed to read

Work Queue may read:

- Pool snapshot.
- Demand snapshot (tokens as intent).
- Graph topology.
- Node↔Pool State mapping.

## 6.2 What it must never infer or trigger

Work Queue must never:

- Trigger execution.
- Trigger allocation.
- Trigger session creation.
- Infer physical completion from token state.
- Infer ownership without allocation.

---

# 7. Transitional Coexistence Doctrine

This section defines how legacy code may coexist temporarily without changing canonical law.

## 7.1 Temporary coexistence allowance (normative)

Legacy token-flow code paths may exist only if both are true:

- They are treated as **non-authoritative projections** for pre-binding reality.
- They are prevented from mutating pool reality or creating ownership outside allocation.

## 7.2 Required mental model for developers

During transition, developers must assume:

- Pool + Reality Events describe “what is real.”
- Visibility describes “what the system can suggest.”
- Tokens describe “what we intend” until allocation.

Any design that uses tokens to drive pre-binding execution is invalid.

---

# 8. Forbidden Refactor Patterns

The following refactor patterns are canonically invalid:

- “Just adapt token flow” (preserving token-driven authority).
- “Soft allocation” (reservation without allocation).
- “Queue-driven execution” (visibility triggers work).
- “Graph-enforced ordering” (assuming artisans obey topology).
- “Token-driven release” (release spawns downstream tokens).

---

# 9. Error Handling & INS UFFICIENT EVIDENCE

## 9.1 When implementation must refuse to act

Implementation must fail closed (refuse to act) if:

- An action would create ownership without allocation.
- An action would mutate pool without a reality event.
- A binding action cannot prove allocatability without going negative.
- Node↔state mapping is undefined.
- Allocation selection cannot be computed deterministically.

## 9.2 How ambiguity is handled without inventing logic

When required canonical evidence is missing, the correct label is:

- **INSUFFICIENT EVIDENCE**

Under ambiguity:

- The system must not invent state transitions.
- The system must not infer reality from token lifecycle.
- The system must not proceed with allocation.

---

# 10. Completion Criteria

## 10.1 How to know the system is canonically compliant

The system is canonically compliant when all are true:

- Pre-binding pool reality is mutated only by reality events.
- Batch nodes do not bind and do not require token selection.
- Binding nodes are the only place allocation occurs.
- Work Queue is projection-only and never permission.
- Release moves quantities between pools and never spawns tokens.
- Token lifecycle is not used as proof of batch completion.

## 10.2 Conditions allowing future refactors safely

Future refactors are canonically safe only when they:

- preserve Pool SSOT pre-binding,
- preserve allocation-only ownership creation,
- preserve projection read-only boundaries,
- do not reintroduce token-flow execution control.

If a boundary cannot be made explicit for a proposed change, the correct label is:

- **INSUFFICIENT EVIDENCE**
