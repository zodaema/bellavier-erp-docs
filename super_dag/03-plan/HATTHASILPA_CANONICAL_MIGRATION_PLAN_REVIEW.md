# Review: Hatthasilpa Canonical Migration / Refactor Plan

**Review scope (authoritative inputs):**

- `docs/super_dag/03-plan/HATTHASILPA_CANONICAL_MIGRATION_PLAN.md`
- `docs/super_dag/01-canonical/HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md`

**Hard constraint of this review:** critique only (no code changes, no canonical doc edits).

---

# 1) Token-flow as execution trigger (Checklist Item 1)

## 1.1 Findings

- **No explicit plan step requires token movement/routing/spawning as the execution trigger** for pre-binding work.
- The plan repeatedly states the opposite (pool-first authority), e.g.:
  - Plan §3.1: “Pool + Reality Events become the authoritative layer for pre-binding reality” (plan lines 71–78).
  - Plan Phase 4 goal: “Ensure pre-binding progress and readiness are not driven by token routing…” (plan lines 239–241).

## 1.2 Canonical-safety risks (not an immediate plan BLOCKER, but needs tightening)

While the plan does not *intend* token-flow execution, two paragraphs are **ambiguous enough** that an implementer could accidentally keep token events/routing authoritative unless additional explicit constraints are added to the plan:

- **Risk A — Dual-write language could be misapplied**
  - Plan Phase 2 “Backward compatibility approach”:
    - “Temporary dual-write may exist (token event retained for reporting) **but pool is authoritative**.” (plan lines 205–207)
  - Risk: Without an explicit rule that all pre-binding read surfaces must switch to pool-derived truth, dual-write could become de-facto dual-authority.

- **Risk B — “NODE_RELEASE may remain” requires a strict non-authority guarantee**
  - Plan Phase 3 “Backward compatibility approach”:
    - “`NODE_RELEASE` may remain as a projection record temporarily, but must not drive downstream execution.” (plan line 231)
  - Risk: This must be coupled to explicit acceptance tests asserting no runtime behavior uses `NODE_RELEASE`/`NODE_YIELD` as authoritative signals.

**Result:**

- **No Checklist Item 1 BLOCKER found** (no paragraph that explicitly relies on token flow as execution trigger).
- **Action required at plan-level:** add explicit “non-authoritative read boundary” acceptance tests (see Section 4).

---

# 2) Phase prerequisite ordering (Checklist Item 2)

## 2.1 Ordering check

The requested prerequisite ordering is:

- Pool SSOT **before** CUT yield **before** Release **before** Queue.

The plan’s phases are:

- Phase 1 — Pool SSOT + pool events (plan lines 173–193)
- Phase 2 — CUT Yield → pool transform + pool quantity updates (plan lines 194–213)
- Phase 3 — Release → pool-to-pool movement; remove token spawning (plan lines 214–236)
- Phase 5 — Visibility Engine cutover / queue derived from pool+demand+topology; remove queue gating (plan lines 258–281)

**Result:**

- **Pass:** Pool → Yield → Release → Queue is ordered correctly.

## 2.2 Canonical-safety sequencing concern (schedule risk, not ordering failure)

- The plan postpones removal of `V-QUEUE-02` (queue-as-permission) until Phase 5 (plan lines 263–280).
- Under Implementation Boundary Canonical §2.2 and §6.2, Work Queue must never be permission and must never trigger/authorize work.

This does **not** violate the ordering constraint, but it is a **high-impact prolonged non-canonical period** unless Phase 5 is prioritized early.

---

# 3) Phase 1 missing foundation tasks (Checklist Item 3)

Plan Phase 1 includes high-level deliverables (pool storage, pool event taxonomy, pool snapshot read API) (plan lines 101–106) and schema creation (plan lines 184–185). This is directionally correct, but it is missing several **foundation dependencies** required to make Phase 2–3 implementable and canonically safe.

## 3.1 Missing foundations that should be explicitly listed in Phase 1

- **F1 — Pool key definition (binding to existing domain identifiers)**
  - The plan does not explicitly specify how pool keys are constructed from existing system identifiers (e.g., how `product_revision_id` / job context maps into the pool key’s `product_model_id` and `bom_version_id`).
  - Without this, Phase 2 (CUT yield) cannot deterministically update a pool record.
  - This must be either:
    - a Phase 1 deliverable (explicit mapping contract), or
    - a Decision Checkpoint (see Section 5).

- **F2 — Minimal pool snapshot read contract (API/service boundary)**
  - Phase 1 says “Read API exists for pool snapshot” (plan line 106), but does not enumerate the minimal query capabilities required by Phase 3 and Phase 5.
  - At plan level, this should specify at minimum:
    - read pool quantity by `(product, bom/version, component_code, state)`
    - read pool quantities for a given “demand group” used by the Work Queue projection

- **F3 — Idempotency + ordering rules for pool events**
  - Implementation Boundary Canonical §5.1 requires mutations originate only from reality events.
  - The plan does not explicitly require idempotency semantics for pool event writes, which is a prerequisite to prevent duplicate yields/releases from inflating pool.
  - (This is plan-level; it is not implementation advice on how, only that the plan must require it.)

- **F4 — Enforcement boundary: only one subsystem is allowed to mutate pool**
  - Implementation Boundary Canonical §5.1 and §5.2 require pool mutations to originate only from reality events and forbid projection write-back.
  - The plan should explicitly list a Phase 1 deliverable: “All pool writes go through the pool event persistence boundary; no other subsystem directly updates pool quantities.”
  - This is implied (plan line 105) but should be called out as a hard acceptance condition.

**Result:**

- **Checklist Item 3:** Partially complete; Phase 1 should explicitly list F1–F4.

---

# 4) Acceptance tests sufficiency (Checklist Item 4)

The plan includes a useful test matrix (T1–T7) mapped to invariants and/or violation IDs (plan lines 311–390). However, it is missing tests that specifically prevent regression to token authority in the exact ways prohibited by Implementation Boundary Canonical §4.1, §5.1, and §6.2.

## 4.1 Gaps

- The current tests do not explicitly assert that:
  - token events (`NODE_YIELD`, `NODE_RELEASE`) are **non-authoritative** for pre-binding quantities after cutover
  - Work Queue does not create sessions / does not trigger execution (Implementation Boundary §6.2)
  - token routing (`moveToken`, `routeToken`) cannot be used to create pre-binding readiness

## 4.2 Additional plan-level tests to add (no implementation guidance)

Add the following acceptance tests to the plan:

- **T8 — CUT detail must be pool-derived (token events ignored for quantity truth)**
  - **Maps to:** `V-REL-02`, `V-CUT-01`, Implementation Boundary §2.1/§2.2.
  - **Expected:** any CUT batch detail totals are computed from pool snapshot + pool events, not from token_event aggregation.

- **T9 — Work Queue projection never triggers session creation**
  - **Maps to:** Implementation Boundary §6.2 (“Work Queue must never trigger session creation”).
  - **Expected:** loading/rendering the queue produces no session rows/events.

- **T10 — No pre-binding readiness from token movement**
  - **Maps to:** `V-ROUTE-01`, Implementation Boundary §4.1.
  - **Expected:** changing `flow_token.current_node_id` / token status alone does not increase pool availability and does not cause new work opportunities to appear (except as demand grouping, which must be explicitly labeled projection).

- **T11 — Release endpoint cannot spawn downstream tokens (negative test)**
  - **Maps to:** `V-REL-01`.
  - **Expected:** assert no token creation occurs as a side effect of release.

- **T12 — Soft binding endpoint is non-authoritative / disabled under canonical mode**
  - **Maps to:** `V-OWN-01`.
  - **Expected:** binding cannot create ownership; ownership can only arise via allocation.

- **T13 — Allocation concurrency / non-negativity invariant**
  - **Maps to:** pool non-negativity requirement implied by plan Phase 1 acceptance and risk #6; supports `V-POOL-01` and `V-OWN-01` remediation.
  - **Expected:** concurrent allocation attempts cannot drive pool negative; exactly one succeeds or both fail safely.

**Result:**

- **Checklist Item 4:** Tests are a strong start but insufficient to prevent regression to token authority without T8–T13.

---

# 5) Decision Checkpoints completeness (Checklist Item 5)

The plan includes decision checkpoints DC-01 through DC-05 (plan lines 423–452). These correctly cover:

- `V-OWN-02` scope ambiguity
- pool locality/scope
- pool state taxonomy completeness
- binding node identification
- initial pool bootstrap

## 5.1 Missing Decision Checkpoints that should be added

- **DC-06 — Node↔Pool State mapping completeness for the current Hatthasilpa graph**
  - **Why required:** Implementation Boundary Canonical §6.1 explicitly lists Node↔Pool State mapping as an allowed read input for Work Queue.
  - The plan requires topology inputs but does not explicitly require a complete node↔state mapping inventory as a decision checkpoint.
  - Without it, Phase 2–3 (yield/release state transitions) and Phase 5 (visibility projection) cannot be implemented deterministically.

- **DC-07 — Batch vs Binding node classification for current nodes (execution boundary)**
  - **Why required:** Phase 4 and Phase 6 depend on knowing which nodes are pre-binding batch nodes vs binding nodes; the plan flags binding-node identification (DC-04) but does not explicitly include the full classification set for all relevant nodes.

- **DC-08 — Component code taxonomy mapping used by pool events**
  - **Why required:** Pool events require deterministic `component_code` usage; the plan assumes it but does not list it as an explicit decision checkpoint.

**Result:**

- **Checklist Item 5:** Partially satisfied; add DC-06–DC-08.

---

# Summary of Review Outcomes

- **(1) Token-flow execution trigger reliance:**
  - **No explicit plan BLOCKER found**, but dual-write and “NODE_RELEASE may remain” require additional hard acceptance tests to prevent accidental token-authority regression.
- **(2) Phase ordering:**
  - **Correct** for Pool → Yield → Release → Queue.
- **(3) Phase 1 foundations:**
  - Missing explicit plan requirements for pool key mapping, minimal read contract, idempotency/ordering, and enforcement boundary.
- **(4) Acceptance tests:**
  - Good baseline; needs additional tests T8–T13 specifically targeting Implementation Boundary prohibitions.
- **(5) Decision checkpoints:**
  - DC-01..DC-05 exist; must add DC-06..DC-08 for node↔pool mapping completeness and taxonomy decisions.
