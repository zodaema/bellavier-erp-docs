# Hatthasilpa Reality Event Canonical Spec

**Status:** CANONICAL (Must not conflict with Hatthasilpa Canonical Production Spec v1.0)  
**Date:** 2026-01-21  
**Version:** 1.0  
**Category:** SuperDAG / Canonical / Hatthasilpa

This document defines the canonical **Reality Event Model** for Hatthasilpa.

If any statement in this document conflicts with:

- `docs/super_dag/01-canonical/HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` (v1.0)
- `docs/super_dag/01-canonical/HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_NODE_POOL_STATE_MAPPING_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_ALLOCATION_POLICY_CANONICAL.md`

then this document is invalid by definition.

---

# 1. Scope & Purpose

## 1.1 Why event modeling is required

Event modeling is required because:

- Pool is SSOT of physical reality pre-binding.
- Pool changes must be attributable to **recorded physical actions**, not token lifecycle.
- Visibility is a read-only projection and must not be confused with reality.

Therefore the system must have a canonical way to record “what happened in the workshop” that is:

- deterministic
- auditable
- replay-safe
- non-commanding

## 1.2 Separation between reality events and projection

- **Reality Events** record observed physical actions and are the only authoritative source for pool mutations.
- **Projections** (e.g., Work Queue cards, readiness counts) are computed from reality and are never authoritative.

A projection must never be used as evidence that a reality event occurred.

---

# 2. What a Reality Event IS

## 2.1 Canonical definition

A **Reality Event** is:

- A canonical record that a physically meaningful action occurred.
- A record that can be audited and replayed to reconstruct pool reality.

A Reality Event exists to let the system say:

- “These parts exist in this pool state now”
- “These parts were consumed into ownership at a binding moment”

## 2.2 Relationship to physical actions

A Reality Event must correspond to a physical action that is meaningful in the atelier, such as:

- producing anonymous parts into a pool state
- moving anonymous parts between pool states
- allocating parts into a specific token at binding
- scrapping or adjusting quantities with explicit reason

## 2.3 Who may emit events (role-based, not UI-based)

Event emission authority must be defined by **roles**.

Canonical requirement:

- Only authorized roles may emit events that mutate pool quantities or create ownership.

The specific role taxonomy is **INSUFFICIENT EVIDENCE**.

This document therefore asserts only:

- A role-based authorization must exist.
- Authorization must not be inferred from UI page access.

---

# 3. What a Reality Event IS NOT

A Reality Event is not:

- A command.
- A schedule.
- A workflow transition.
- Token-flow advancement.

A Reality Event must not imply:

- “You must do this next.”
- “The artisan is not allowed to do other work.”
- “The graph step has been completed for a token.”

Reality Events describe reality; they do not prescribe it.

---

# 4. Canonical Event Categories

This section defines canonical categories (taxonomy) for Hatthasilpa events.

## 4.1 Pool-transform events (pre-binding)

**Pool-transform events** are non-binding events that:

- change anonymous pool quantities and/or their pool states
- never create ownership

These events operate only under `pool_mode=transform`.

## 4.2 Pool-allocation events (binding)

**Pool-allocation events** are binding events that:

- deduct quantities from pool
- create ownership by linking quantities to a token

These events operate only under `pool_mode=allocate`.

## 4.3 Quality/state events

Quality/state events are events that record quality outcomes that affect whether parts are usable.

How pre-binding QC affects pool state taxonomy is **INSUFFICIENT EVIDENCE**.

Canonical constraint:

- Any quality event must not bind to token pre-binding.
- Any quality event that affects usability must either:
  - mutate pool quantities/states deterministically, or
  - be explicitly labeled as not pool-affecting.

If the system cannot determine the pool effect deterministically, it must be labeled **INSUFFICIENT EVIDENCE**.

## 4.4 Scrap / adjustment events

- **Scrap events** permanently reduce usable pool quantities.
- **Adjustment events** correct pool quantities with explicit human justification.

Both must be auditable and must not create ownership.

---

# 5. Event → Pool Interaction Rules

## 5.1 Which events mutate pool

Only the following event categories may mutate pool quantities:

- Pool-transform events (`pool_mode=transform`)
- Pool-allocation events (`pool_mode=allocate`)
- Scrap events
- Adjustment events

Any other event category must be non-mutating.

## 5.2 Non-negativity rules

Pool mutation must preserve the invariant:

- pool quantities must never go negative.

If a proposed event would cause negativity, it must be rejected.

## 5.3 Atomicity requirements

Pool mutations must be atomic at the semantic unit they claim.

Canonical requirement:

- If an event claims to move or transform `X` units, it must either apply fully or not at all.
- Allocation events must follow the atomicity doctrine defined in allocation canonical (per unit/per token).

---

# 6. Event → Token Interaction Rules

## 6.1 Which events may reference token

Only binding-phase events may reference a token as an ownership target.

Canonical rule:

- Pool-allocation events may reference `token_id` because allocation creates ownership.

## 6.2 Which events must NOT reference token

Pre-binding events must not reference token for ownership.

Canonical rule:

- Pool-transform events must not bind to token.
- Scrap/adjustment events must not create token ownership.

## 6.3 Binding vs pre-binding constraints

- Before binding: tokens are intent only; events must not create ownership.
- At binding: allocation events create ownership.
- After binding: token-bound events may exist (outside scope of pool SSOT) but must not retroactively create pre-binding ownership.

---

# 7. Ordering, Idempotency & Audit

## 7.1 Determinism requirements

Reality events must support deterministic reconstruction:

- Given the same initial pool state and the same ordered event stream, the resulting pool state must be identical.

This requires that:

- event meanings are unambiguous
- pool keys and state transitions are deterministic

## 7.2 Replay safety

The event model must support replay without producing different results.

A canonical idempotency doctrine is required:

- replaying the same event must not double-apply its pool effect.

The exact idempotency key specification is **INSUFFICIENT EVIDENCE**.

## 7.3 Audit expectations

Every event must be auditable.

Canonical minimum audit attributes are:

- actor identity (who recorded the event)
- event time (when it occurred / was recorded)
- reason code (why it happened)
- pool key(s) affected (what reality changed)

If an event cannot be attributed or justified, it is invalid.

---

# 8. Forbidden Event Patterns

The following patterns are canonically invalid:

- Events that imply permission or command.
- Events that create ownership without allocation.
- Events that derive from Work Queue visibility or queue presence.
- Events that treat token lifecycle as reality.
- Events that “move tokens” through nodes.
- Events that rely on “artisan must follow graph order” assumptions.

---

# 9. Error & Insufficient Evidence Handling

## 9.1 When events must be rejected

Events must be rejected if any of the following are true:

- They would cause pool negativity.
- They attempt to create ownership without allocation.
- They attempt to bind or require token selection in a batch context.
- They require a node↔state mapping that is undefined.
- Their pool effect cannot be computed deterministically.

## 9.2 How uncertainty is labeled

When the system cannot determine:

- the correct pool key,
- the correct state transition,
- the correct pool effect,

the correct label is:

- **INSUFFICIENT EVIDENCE**

Under **INSUFFICIENT EVIDENCE**, the system must not silently invent an event meaning.

---

# 10. Open Questions / Insufficient Evidence

The following items remain unresolved by current canonical evidence:

- Role taxonomy and authorization mapping for who may emit which event categories.
- Idempotency key definition for replay-safe event application.
- Pre-binding QC taxonomy and its deterministic pool impact.
- Whether events distinguish “occurred_at” vs “recorded_at” as separate canonical times.
- Whether pool candidates/partitions exist and how events address them (single aggregated pool vs partitioned pools).

Until resolved, systems must not guess; they must use deterministic rules only or label outcomes **INSUFFICIENT EVIDENCE** where needed.
