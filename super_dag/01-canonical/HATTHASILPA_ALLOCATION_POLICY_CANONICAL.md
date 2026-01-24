# Hatthasilpa Allocation Policy Canonical Spec

**Status:** CANONICAL (Must not conflict with Hatthasilpa Canonical Production Spec v1.0)  
**Date:** 2026-01-21  
**Version:** 1.0  
**Category:** SuperDAG / Canonical / Hatthasilpa

This document defines the deterministic allocation policy used by **Binding Nodes** in Hatthasilpa.

If any statement in this document conflicts with:

- `docs/super_dag/01-canonical/HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` (v1.0)
- `docs/super_dag/01-canonical/HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_NODE_POOL_STATE_MAPPING_CANONICAL.md`

then this document is invalid by definition.

---

# 1. Scope & Purpose

## 1.1 Purpose

Allocation policy must be explicit because:

- Allocation is the **only** operation that creates ownership.
- Binding Nodes are the **only** place allocation is allowed.
- Pool is SSOT of pre-binding physical reality; therefore allocation must deduct from pool without violating non-negativity.
- Allocation must be deterministic and audit-friendly; engineers must not guess selection behavior.

## 1.2 Scope

This specification defines:

- Canonical meaning of allocation (ownership creation semantics).
- Preconditions and constraints for valid allocation.
- Deterministic selection rules when allocating from Pool.
- Multi-component allocation rules (atomicity, partial allocation doctrine).
- Concurrency and conflict doctrine (canonical behavior under competition).
- Canonical forbidden patterns.
- Error and **INSUFFICIENT EVIDENCE** handling.

## 1.3 Non-goals

This specification does NOT define:

- Implementation details (schemas, APIs, code, UI behavior).
- Scheduling, execution ordering, or artisan workflow control.
- Any mechanism that causes allocation to happen automatically.

---

# 2. What Allocation IS

## 2.1 Canonical definition

**Allocation** is a Binding-Node-only operation (`pool_mode=allocate`) that:

- Deducts quantities from Pool in a non-negative manner.
- Creates ownership by linking allocated component quantities to a specific token.

Allocation is the canonical boundary where:

- Token identity becomes authoritative (identity-forming phase).
- Anonymous pool quantities become token-owned components.

## 2.2 Ownership creation semantics

- Ownership **does not exist** prior to allocation.
- Ownership **begins** at allocation and is expressed by an allocation record/event that is auditable and deterministic.
- Allocation must be attributable to an actor and a reason (audit requirement).

---

# 3. What Allocation IS NOT

Allocation is not:

- A reservation.
- A soft binding.
- An implied claim created by visibility/readiness.
- A UI-driven “pick which pool row you want” operation.
- A consequence of token lifecycle advancement.

Allocation must never be inferred from:

- Work Queue visibility.
- Token flow state.
- Any “node transition” concept not grounded in pool deduction + ownership creation.

---

# 4. Allocation Preconditions

## 4.1 Required pool state availability

Allocation may occur only when:

- The required **Node → Pool State** mapping is defined for the Binding Node.
- The required pool state(s) for each required component are defined deterministically.

If required state(s) are undefined or ambiguous, allocation must be blocked as **INSUFFICIENT EVIDENCE**.

## 4.2 Non-negativity constraint

- Allocation must never cause any pool quantity to go negative.
- If sufficient quantities do not exist, allocation must fail without mutating pool.

## 4.3 Atomicity requirement (per unit / per token)

Allocation for a single token unit must be **atomic**:

- Either all required components for the unit are allocated together, or none are.

A token must not be treated as “bound” if any required component for the unit was not allocated.

---

# 5. Deterministic Selection Rules

This section defines how allocation selects pool quantities deterministically.

## 5.1 Candidate set (normative)

For each required component, the candidate set consists only of pool quantities that match all of:

- `product_model_id`
- `bom_version_id`
- `component_code`
- required `state` (or an explicitly defined acceptable-state set)

No other pool quantities are eligible.

## 5.2 Single-record pool representation

If the system represents a given pool key as a single aggregated quantity record, selection is trivial:

- The allocation deducts from that single pool quantity.

No additional selection rule is required.

## 5.3 Multi-candidate pool representation

If the system represents a given pool key as multiple candidates (e.g., physically distinct partitions of the same pool key), allocation must choose deterministically.

### 5.3.1 Required determinism fields (conceptual)

For deterministic selection across multiple candidates, each candidate must have:

- A stable identity (`candidate_id`) used only for deterministic tie-breaking.
- A deterministic precedence attribute representing “entered required state” ordering (`entered_state_at`).

If these cannot be provided deterministically, allocation must be blocked as **INSUFFICIENT EVIDENCE**.

### 5.3.2 Canonical ordering policy

When multiple candidates exist for the same pool key, the canonical selection order is:

1) **FIFO by `entered_state_at` ascending** (oldest-in-state allocated first).
2) **Tie-breaker:** `candidate_id` ascending.

This ordering is required so that allocation is:

- deterministic (no guessing)
- audit-friendly (the reason a candidate was chosen is explainable)

## 5.4 Audit requirement (normative)

Every allocation must record, as part of its auditable allocation evidence:

- The declared allocation policy name (e.g., “FIFO_ENTERED_STATE_AT”).
- The exact pool key(s) and quantities deducted.
- If multiple candidates exist: which candidate(s) were used and their ordering basis.

---

# 6. Multi-Component Allocation

## 6.1 Joint allocation doctrine

Allocation at a Binding Node must allocate all required BOM components for a unit **as one atomic decision**.

- The system must not allocate component A for a token unit if component B for the same unit cannot also be allocated.

## 6.2 Partial allocation rules

- **Forbidden:** partial allocation that results in a token being treated as bound without all required components allocated for the unit.
- **Allowed:** allocating fewer complete units than requested (e.g., only some tokens/units can be allocated) provided each allocated unit is complete and atomic.

## 6.3 Failure handling when one component is insufficient

If any required component is insufficient:

- Allocation must fail for that unit.
- No pool deduction may occur for that unit.
- The failure must be auditable and must not be masked by fallback logic.

---

# 7. Concurrency & Conflict Doctrine

This section defines canonical behavior when allocations compete.

## 7.1 Canonical conflict behavior (normative)

If two allocations compete for the same pool quantities:

- The system must produce an outcome consistent with a **serializable** history:
  - One allocation may succeed (deducting quantities), and
  - the other must either succeed using remaining quantities or fail without mutating pool.

Non-negativity must always hold.

## 7.2 Deterministic winner selection

Deterministic “who wins” under true concurrency is **INSUFFICIENT EVIDENCE**.

Reason:

- Canonical law requires determinism and auditability of selection given an authoritative commit order, but does not define a universal canonical ordering for simultaneous requests.

Therefore, canonical requirement is:

- The committed allocation order must be auditable after the fact.
- Losers must not succeed by forcing negative pool or partial allocation.

---

# 8. Forbidden Patterns

The following are canonically invalid:

- Artisan/operator choosing specific pool candidates/rows as part of allocation.
- Allocation implied by Work Queue readiness or visibility.
- Allocation triggered by token lifecycle state or token-flow “node transitions.”
- Soft binding / reservation.
- Any allocation that can create negative pools.
- Any allocation that binds a token without complete per-unit component allocation.

---

# 9. Error & Insufficient Evidence Handling

## 9.1 When allocation must be blocked

Allocation must be blocked (fail closed) if any of the following are true:

- Required node↔pool-state mapping is undefined.
- Required input state(s) for a component are ambiguous.
- Candidate ordering fields required for determinism (`entered_state_at`, `candidate_id`) are not available when multiple candidates exist.
- The system cannot determine non-negativity for the proposed allocation.

## 9.2 How uncertainty is labeled

When allocation cannot proceed due to missing canonical evidence or undefined deterministic rules, the correct label is:

- **INSUFFICIENT EVIDENCE**

Allocation must not proceed under ambiguity.

---

# 10. Open Questions / Insufficient Evidence

The following allocation-related items are not fully defined by existing canonical law and remain unresolved:

- Whether pool candidates must exist at all (single aggregated pool per key vs physically partitioned pools).
- Whether location/work-center must constrain allocation (location scoping doctrine).
- Whether any component families require non-FIFO allocation due to physical constraints (e.g., matching grain, shade, or batch consistency).
- How pre-binding QC/hold states (if any) constrain allocatable state sets.
- Whether deterministic allocation should incorporate additional canonical precedence beyond FIFO (e.g., expiry/aging), which is not defined by current canonical evidence.

Until resolved, these must not be guessed; systems must either use the deterministic rules defined above or block with **INSUFFICIENT EVIDENCE** where required.
