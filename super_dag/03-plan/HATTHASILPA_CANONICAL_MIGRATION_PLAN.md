# Hatthasilpa Canonical Migration / Refactor Plan

**Status:** PLAN (derived strictly from `docs/super_dag/02-audit/HATTHASILPA_CANONICAL_VIOLATION_MAP.md`)  
**Date:** 2026-01-21  

This plan is a concrete, testable sequence to remove **BLOCKER** canonical violations and to constrain **TOLERATED** legacy behavior to the **Implementation Boundary doctrine** (projection-only, non-authoritative).

---

# 1. Objective

## 1.1 “Done” definition (measurable canonical compliance)

Canonical compliance is considered **DONE** when all items below are true:

- **All BLOCKER violations are eliminated**:
  - `V-QUEUE-02`, `V-CUT-01`, `V-REL-01`, `V-REL-02`, `V-ROUTE-01`, `V-ROUTE-02`, `V-POOL-01`, `V-OWN-01`.
- **Pool SSOT exists and is authoritative pre-binding**:
  - A pool quantity/state ledger exists and is updated only via canonical reality events (addresses `V-POOL-01`).
- **CUT batch reality updates Pool SSOT (not token events)**:
  - CUT yield updates pool quantities/states and persists pool-transform reality events (addresses `V-CUT-01`).
- **Release is pool-to-pool quantity movement, never token spawning**:
  - CUT release does not spawn downstream tokens and does not use token events as the release accounting source of truth (addresses `V-REL-01`, `V-REL-02`).
- **Downstream readiness is not produced by token routing for pre-binding nodes**:
  - Token routing and token status changes are not used as the “runnable” mechanism for pre-binding batch work (addresses `V-ROUTE-01`, `V-ROUTE-02`).
- **Work Queue never blocks artisans (queue is suggestion only)**:
  - No queue-derived “permission flags” and no shortage-based blocking prevents starting batch work (addresses `V-QUEUE-02`).
- **Ownership is created only via Binding-Node allocation (no soft binding)**:
  - Any token↔serial ownership-like link is created only by Binding Node allocation, and soft binding paths are disabled (addresses `V-OWN-01`).

## 1.2 Canonical invariant identifiers for tests

For acceptance tests (Section 6), invariants are referenced as:

- **I1:** Batch nodes never bind.
- **I2:** Only binding nodes allocate.
- **I3:** Release moves quantities between pools, never tokens.
- **I4:** Overcut goes into pool, not waste.
- **I5:** Token identity begins at assembly, not cutting.
- **I6:** Graph validates meaning, not command execution.
- **I7:** Work Queue suggests; artisans decide.

---

# 2. Current State Snapshot

## 2.1 BLOCKER violations (must be removed)

- `V-QUEUE-02` — Work Queue/Start action blocked by permission flags + shortage gates.
- `V-CUT-01` — CUT yield recorded as token events (`NODE_YIELD`) instead of pool transform events.
- `V-REL-01` — CUT release spawns downstream tokens.
- `V-REL-02` — Release accounting uses token events (`NODE_YIELD`/`NODE_RELEASE`) instead of pool quantities.
- `V-ROUTE-01` — Token routing moves tokens through nodes and sets status as readiness signal.
- `V-ROUTE-02` — Parallel split/merge spawns component tokens and re-activates parent token.
- `V-POOL-01` — Pool subsystem and `POOL_*` event taxonomy absent.
- `V-OWN-01` — Component serials can be bound to tokens (soft binding).

## 2.2 TOLERATED violations (allowed only as non-authoritative projection)

- `V-QUEUE-01` — Work Queue constructed from `flow_token` status + `current_node_id`.
- `V-QUEUE-03` — Work Queue UI describes itself as “flow_token + token_work_session”.
- `V-TOKEN-01` — Token lifecycle transitions used as operational state and emit node events.
- `V-OWN-02` — Material reservation/allocation “soft locks” (explicitly labeled **INSUFFICIENT EVIDENCE** in the violation map).

---

# 3. Strategy: Minimal-Disruption Canonicalization

## 3.1 Principle: demote token-flow safely; promote pool/event authority

- **Pool + Reality Events become the authoritative layer for pre-binding reality**.
- **Visibility becomes a deterministic projection**, derived from:
  - pool snapshot
  - demand (tokens as intent)
  - graph topology (Graph Designer remains neutral; topology is not execution logic)
- **Legacy token-flow is constrained**:
  - allowed only as projection and transitional compatibility (Implementation Boundary doctrine)
  - forbidden for pre-binding execution semantics (addresses `V-ROUTE-01`, `V-ROUTE-02`)

## 3.2 Compatibility doctrine (Implementation Boundary)

During the transition:

- Existing token-flow endpoints may continue only if:
  - they are explicitly treated as **non-authoritative projections**, and
  - they are prevented from mutating pool reality or creating ownership outside allocation.

This plan therefore uses:

- **Feature-flagged cutover** for major authority changes (pool-first enablement).
- **Dual-read / dual-write where necessary** (temporary), with explicit acceptance checks.

---

# 4. Workstreams (Separated)

## A) Pool SSOT + Reality Event Subsystem (create missing foundations)

**Primary violations addressed:** `V-POOL-01` (enabler for `V-CUT-01`, `V-REL-02`, `V-REL-01`).

Deliverables (concrete and testable):

- A pool quantity/state storage model exists.
- A pool event taxonomy exists (`POOL_TRANSFORM`, `POOL_MOVE`, `POOL_ALLOCATE`, `POOL_SCRAP`, `POOL_ADJUST`).
- Writes to pool quantities happen only through pool event persistence.
- Read API exists for pool snapshot (for the Visibility Engine and CUT detail).

## B) Visibility Engine projection (queue derived from pool/demand/topology)

**Primary violations addressed:** `V-QUEUE-01` (eventual), `V-QUEUE-03` (eventual), and required to ensure `V-QUEUE-02` remediation does not regress into new gating.

Deliverables:

- Work Queue computation is derived from pool + demand + topology.
- Work Queue is suggestion-only and cannot be used as an authorization gate.
- Existing UI may consume the new projection without assuming token movement as proof.

## C) Binding Allocation subsystem (ownership only via allocate)

**Primary violations addressed:** `V-OWN-01`.

Deliverables:

- Allocation is the only operation that creates ownership.
- Binding Nodes perform allocation atomically.
- Any token↔serial linkage comes from allocation ledger entries.

## D) Legacy token-flow containment (what remains temporarily, what must stop)

**Primary violations addressed:** `V-TOKEN-01`, `V-ROUTE-01`, `V-ROUTE-02`.

Deliverables:

- Token lifecycle remains in allowed scope only (projection and/or post-binding identity work).
- Token routing is prevented from acting as the pre-binding execution engine.

## E) Deletion/disable plan for forbidden paths (spawning, soft binding, queue gates)

**Primary violations addressed:** `V-QUEUE-02`, `V-REL-01`, `V-ROUTE-02`, `V-OWN-01`.

Deliverables:

- Remove/disable queue-derived start blocks.
- Remove/disable CUT release token spawning.
- Remove/disable parallel split/merge token spawning semantics (Hatthasilpa context).
- Remove/disable component serial soft-binding.

---

# 5. Sequenced Execution Plan (PHASES)

## Phase 0 — Governance + Cutover Controls

- **Goal**
  - Establish a safe, testable rollout mechanism for authority transitions (pool-first vs token-projection).
- **Violations addressed**
  - Enables remediation for all BLOCKER items by preventing partial deployment risk.
- **Scope of code areas**
  - Configuration/feature flag layer used by:
    - `source/dag_token_api.php`
    - `source/BGERP/Dag/BehaviorExecutionService.php`
    - `assets/javascripts/pwa_scan/work_queue.js`
    - `source/BGERP/Service/DAGRoutingService.php`
- **Data changes/migrations**
  - None.
- **Backward compatibility approach**
  - Default flags preserve current behavior until Phase 1–4 are complete.
- **Acceptance tests / checks**
  - A switch exists to run the system in:
    - “legacy projection mode” (current)
    - “canonical pool-first mode” (new)

## Phase 1 — Introduce Pool SSOT + Pool Event Taxonomy

- **Goal**
  - Implement the missing Pool SSOT foundation so subsequent phases can stop using token events as pre-binding reality.
- **Violations addressed**
  - `V-POOL-01`.
- **Scope of code areas**
  - New pool data storage and pool event persistence services (exact placement is an implementation choice; plan requires existence and usage).
  - Existing services that must be able to read pool snapshot:
    - `source/BGERP/Dag/BehaviorExecutionService.php`
    - `source/dag_token_api.php`
- **Data changes/migrations**
  - **Required.** Create pool storage + pool event ledger tables.
- **Backward compatibility approach**
  - Do not change existing token_event behavior yet.
  - Pool tables start empty or are seeded as an explicit one-time migration step.
- **Acceptance tests / checks**
  - Verify pool tables exist.
  - Verify `POOL_*` events can be recorded and queried.
  - Verify pool non-negativity invariant at write time.
  - **F1 — PoolKey mapping contract to existing domain identifiers is defined and testable.**
    - Pool writes and reads must be expressible in terms of existing domain identifiers without guesswork.
    - If the mapping cannot be made deterministic, the correct label is **INSUFFICIENT EVIDENCE** (Decision Checkpoint required).
  - **F2 — Minimal pool snapshot read contract exists (required by later phases).**
    - Must support reading pool quantity by `(product, bom/version, component_code, state)`.
    - Must support reading pool quantities for a demand-group projection used by Work Queue (pool-derived projection later).
  - **F3 — Pool event idempotency and ordering requirement is explicit.**
    - Replay of the same event must not double-apply pool effects.
    - Event ordering used for reconstruction must be explicit and auditable.
  - **F4 — Enforcement boundary is explicit and verified.**
    - Pool mutation is allowed only via the pool-event subsystem.
    - No other subsystem may directly mutate pool quantities/states.

## Phase 2 — Canonicalize CUT Yield: pool-transform events + pool quantity updates

- **Goal**
  - Make CUT yield update Pool SSOT (transform) instead of recording yield only as token events.
- **Violations addressed**
  - `V-CUT-01`.
- **Scope of code areas**
  - `source/BGERP/Dag/BehaviorExecutionService.php`
    - `handleCutBatchYieldSave(...)` (currently writes `NODE_YIELD`).
- **Data changes/migrations**
  - None beyond Phase 1 schema.
- **Backward compatibility approach**
  - Temporary dual-write may exist (token event retained for reporting) **but pool is authoritative**.
  - Any retained token events are **NON-AUTHORITATIVE / PROJECTION-ONLY** and **MUST NOT be read by any pre-binding logic**.
  - Any dual-write must have a deterministic reconciliation check.
- **Acceptance tests / checks**
  - A CUT yield action results in:
    - a pool-transform event
    - an updated pool quantity/state
  - Token event `NODE_YIELD` is no longer the authoritative source for physical quantity.
  - Any persisted `NODE_YIELD` (if retained) is **PROJECTION-ONLY** and **MUST NOT be read as authority** by any pre-binding subsystem.

## Phase 3 — Canonicalize Release: pool-to-pool movement; remove downstream token spawning

- **Goal**
  - Replace release-as-token-spawning with release-as-quantity movement between pool states.
- **Violations addressed**
  - `V-REL-01`, `V-REL-02`.
- **Scope of code areas**
  - `source/BGERP/Dag/BehaviorExecutionService.php`
    - `handleCutBatchRelease(...)` (currently spawns tokens and writes `NODE_RELEASE`).
  - `source/BGERP/Service/TokenLifecycleService.php`
    - `spawnComponentTokensForCutRelease(...)` (forbidden by canonical release doctrine).
  - `source/dag_token_api.php`
    - `handleGetCutBatchDetail(...)` (currently aggregates `NODE_YIELD`/`NODE_RELEASE`).
- **Data changes/migrations**
  - None beyond Phase 1 schema.
- **Backward compatibility approach**
  - Existing UI endpoints continue to exist but must read pool quantities instead of token events.
  - `NODE_RELEASE` may remain as a projection record temporarily, but it is **NON-AUTHORITATIVE / PROJECTION-ONLY** and **MUST NOT be read by any pre-binding logic**.
  - `NODE_RELEASE` must not drive downstream execution.
- **Acceptance tests / checks**
  - Release results in pool state movement events and pool snapshot changes.
  - No downstream tokens are spawned by release.
  - CUT batch detail calculations match pool-derived totals.
  - Pre-binding quantity/accounting must not read `NODE_YIELD`/`NODE_RELEASE` from token_event as authority.

## Phase 4 — Remove token-routing authority for pre-binding execution (contain routing/split/merge)

- **Goal**
  - Ensure pre-binding progress and readiness are not driven by token routing, token status, or split/merge token mechanics.
- **Violations addressed**
  - `V-ROUTE-01`, `V-ROUTE-02`.
- **Scope of code areas**
  - `source/BGERP/Service/DAGRoutingService.php`
    - `routeToken(...)`, `routeToNode(...)`
    - `handleParallelSplit(...)`, `handleMergeNode(...)`
  - `source/BGERP/Service/TokenLifecycleService.php`
    - `moveToken(...)`
- **Data changes/migrations**
  - None.
- **Backward compatibility approach**
  - Routing may remain for post-binding work, but must not be the pre-binding execution engine.
  - Any Hatthasilpa pre-binding “ready” determination must become pool-derived.
- **Acceptance tests / checks**
  - Pre-binding batch work does not require tokens to be moved node-by-node to become runnable.
  - Parallel split/merge does not create runnable state via spawning and reactivating tokens.

## Phase 5 — Visibility Engine cutover: Work Queue derived from pool+demand+topology; remove queue-as-permission

- **Goal**
  - Replace queue construction from token state with a pool-first projection.
  - Remove all queue-derived gating behavior.
- **Violations addressed**
  - **Must remove:** `V-QUEUE-02`.
  - **Must demote and eventually eliminate:** `V-QUEUE-01`, `V-QUEUE-03`.
- **Scope of code areas**
  - `source/dag_token_api.php`
    - `computeTokenPermissions(...)` (queue permissions)
    - `handleGetWorkQueue(...)`
    - `handleStartToken(...)` shortage-block behavior
  - `assets/javascripts/pwa_scan/work_queue.js`
    - Replace dependence on token/session as the primary queue truth where applicable.
- **Data changes/migrations**
  - None.
- **Backward compatibility approach**
  - Maintain the existing endpoint contract shape where possible; change the source of the numbers.
  - Any permissions in UI become display-only hints, not gates.
- **Acceptance tests / checks**
  - Work Queue does not block starting work (no shortage gate as a permission gate).
  - Queue numbers are derived from pool availability and demand.

## Phase 6 — Binding Allocation canonicalization; disable soft binding

- **Goal**
  - Remove soft binding (token↔serial binding outside allocation) and require allocation at Binding Nodes.
- **Violations addressed**
  - `V-OWN-01`.
- **Scope of code areas**
  - `source/BGERP/Component/ComponentBindingService.php`
    - `bindSerialToToken(...)` (soft binding).
  - Binding-node execution paths (exact binding-node endpoints are **INSUFFICIENT EVIDENCE** in the violation map; see Decision Checkpoints).
- **Data changes/migrations**
  - **Required.** Create an allocation ledger that represents canonical ownership creation.
- **Backward compatibility approach**
  - If existing consumers expect binding records, keep them only as derived views from allocation ledger (projection) until fully retired.
- **Acceptance tests / checks**
  - Ownership creation occurs only when allocation is performed.
  - No standalone serial binding creates ownership.

---

# 6. Acceptance Tests (Canonical Compliance)

## 6.1 Test matrix

Each test maps to at least one:

- canonical invariant `I1..I7`, and/or
- violation ID from the authoritative violation map.

### T1 — CUT batch: yield updates pool (not token events)

- **Maps to**
  - Invariants: `I1`, `I4`
  - Violations: `V-CUT-01`, `V-POOL-01`
- **Test steps**
  - Perform a CUT yield action (the same operation that currently triggers `handleCutBatchYieldSave(...)`).
- **Expected**
  - Pool quantities/states change.
  - A `POOL_TRANSFORM` (or equivalent transform taxonomy) event exists.
  - `NODE_YIELD` is not required as authoritative evidence for pool quantity.

### T2 — Release moves quantities between pools (no downstream token spawning)

- **Maps to**
  - Invariants: `I3`
  - Violations: `V-REL-01`, `V-REL-02`
- **Test steps**
  - Perform a CUT release action (the same operation that currently triggers `handleCutBatchRelease(...)`).
- **Expected**
  - Pool state movement occurs.
  - No new downstream tokens are created as a consequence.
  - CUT detail derived totals reflect pool-derived values.

### T3 — Work Queue never blocks artisans (no shortage gate)

- **Maps to**
  - Invariants: `I7`
  - Violations: `V-QUEUE-02`
- **Test steps**
  - With a scenario that previously triggered shortage block in `handleStartToken(...)`, attempt to start work.
- **Expected**
  - Work Queue does not function as a permission gate.
  - Any shortage information is displayed as informational only (no “cannot start” enforcement via queue).

### T4 — Downstream triggering is not token-routing-driven for pre-binding work

- **Maps to**
  - Invariants: `I6`
  - Violations: `V-ROUTE-01`
- **Test steps**
  - Advance pre-binding production reality (via pool events) without moving tokens node-by-node.
- **Expected**
  - Visibility/readiness for next opportunities changes as a function of pool state, not token routing.

### T5 — Parallel split/merge does not create runnable state via token spawning/reactivation

- **Maps to**
  - Invariants: `I6`
  - Violations: `V-ROUTE-02`
- **Test steps**
  - Trigger the parallel split/merge scenario that currently uses `handleParallelSplit(...)` and `handleMergeNode(...)`.
- **Expected**
  - No “runnable” state is achieved by spawning component tokens and reactivating the parent token.
  - Pre-binding execution readiness is pool-derived.

### T6 — Binding node requires token selection + allocation; allocation creates ownership

- **Maps to**
  - Invariants: `I2`, `I5`
  - Violations: `V-OWN-01`
- **Test steps**
  - Start binding/assembly work.
- **Expected**
  - Token selection is required at binding time.
  - Allocation from pool occurs atomically.
  - Ownership ledger records token↔component linkage.

### T7 — Overcut reuse across jobs via pool

- **Maps to**
  - Invariants: `I4`
  - Violations: `V-POOL-01`, `V-CUT-01`
- **Test steps**
  - Produce extra usable components in one CUT batch.
  - Later, allocate/use those components in a different job.
- **Expected**
  - Pool increases from overcut.
  - Later consumption uses pool availability.
  - No per-token ownership exists prior to binding allocation.

### T8 — CUT detail must be pool-derived (token events ignored for quantity truth)

- **Maps to**
  - Violations: `V-REL-02`, `V-CUT-01`
  - Implementation Boundary: §2.1 / §2.2
- **Test steps**
  - Load CUT batch detail totals (the same user-facing totals that were historically computed from `token_event`).
- **Expected**
  - Totals are computed from pool snapshot + pool events.
  - `token_event` records (e.g., `NODE_YIELD`, `NODE_RELEASE`) are not used as authoritative quantity truth.

### T9 — Work Queue projection never triggers session creation

- **Maps to**
  - Implementation Boundary: §6.2
- **Test steps**
  - Load/render the Work Queue projection.
- **Expected**
  - No session rows/events are created as a consequence of projection.
  - Queue remains read-only.

### T10 — No pre-binding readiness from token movement

- **Maps to**
  - Violations: `V-ROUTE-01`
  - Implementation Boundary: §4.1
- **Test steps**
  - Change token position/status (e.g., `flow_token.current_node_id` / `flow_token.status`) without any pool events.
- **Expected**
  - Pool availability does not change.
  - No new pool-derived work opportunities appear solely due to token movement (except demand grouping explicitly labeled projection).

### T11 — Release endpoint cannot spawn downstream tokens (negative test)

- **Maps to**
  - Violations: `V-REL-01`
- **Test steps**
  - Execute the release action.
- **Expected**
  - No token creation occurs as a side effect of release.

### T12 — Soft binding endpoint is non-authoritative / disabled under canonical mode

- **Maps to**
  - Violations: `V-OWN-01`
  - Implementation Boundary: §4.1
- **Test steps**
  - Attempt to create token↔serial binding via any pre-allocation binding mechanism.
- **Expected**
  - Binding cannot create ownership.
  - Ownership can only arise via allocation.

### T13 — Allocation concurrency / non-negativity invariant

- **Maps to**
  - Violations: `V-POOL-01`, `V-OWN-01`
  - Implementation Boundary: §5.1
- **Test steps**
  - Perform concurrent allocation attempts against the same pool quantities.
- **Expected**
  - Pool never goes negative.
  - Outcome is consistent with a serializable history: exactly one succeeds or both fail safely without partial allocation.

---

# 7. Risk Register (Top 10)

1. **Pool schema correctness risk**
   - Mitigation: Phase 1 acceptance checks + non-negativity enforced at write time.
2. **Dual-write divergence risk (token events vs pool events)**
   - Mitigation: explicit reconciliation checks and time-boxed dual-write.
3. **Performance risk (Work Queue derived from pool + demand)**
   - Mitigation: projection caching strategy and load tests as part of Phase 5 acceptance.
4. **Partial cutover risk (mixed authority in production)**
   - Mitigation: Phase 0 feature flags with explicit “all-or-nothing per tenant” rollout.
5. **Operator workflow disruption risk**
   - Mitigation: preserve endpoint shapes during Phase 5; only change sources of truth.
6. **Concurrency risk for allocation (double-allocate / negative pool)**
   - Mitigation: allocation must be atomic and enforce non-negativity at transaction level.
7. **Routing semantics regression risk**
   - Mitigation: Phase 4 isolates pre-binding from post-binding routing; run regression tests on post-binding flows.
8. **Parallel work semantics risk**
   - Mitigation: Phase 4 acceptance tests ensure parallel split/merge does not become an execution engine.
9. **Data migration/seed risk (initial pool snapshot)**
   - Mitigation: explicit seeding strategy + reconciliation report; if not possible, require Decision Checkpoint.
10. **Soft binding dependencies risk**
   - Mitigation: Phase 6 provides compatibility via derived views until dependent consumers are migrated.

---

# 8. Decision Checkpoints

These are required because the authoritative violation map explicitly includes **INSUFFICIENT EVIDENCE** and/or because the plan cannot safely proceed without a defined decision.

## DC-01 — Material reservation/allocation subsystem scope (V-OWN-02)

- **Source:** `V-OWN-02` is explicitly labeled **INSUFFICIENT EVIDENCE** in the violation map.
- **Decision needed:** Is raw material lot reservation/allocation governed by Hatthasilpa pool doctrine, or is it out-of-scope?
- **Plan impact:**
  - If in-scope: treat reservation as forbidden soft binding and plan containment/removal.
  - If out-of-scope: formally document as a separate inventory policy domain with clear boundary.

## DC-02 — Pool scope keys and locality (INSUFFICIENT EVIDENCE)

- **Reason:** Pool SSOT is required (Phase 1) but the violation map does not specify whether pool is per-warehouse, per-location, or global-per-tenant.
- **Decision needed:** Define the authoritative pool scoping dimensions (e.g., include/exclude warehouse/location).

## DC-03 — Pool state taxonomy completeness (INSUFFICIENT EVIDENCE)

- **Reason:** Phase 2–3 require moving quantities between pool states; the violation map does not enumerate all required states.
- **Decision needed:** Confirm the canonical set of pool states needed for Hatthasilpa nodes.

## DC-04 — Binding node identification in the current graph/runtime (INSUFFICIENT EVIDENCE)

- **Reason:** Phase 6 must implement binding-node allocation, but the violation map does not identify the exact binding node(s) and their runtime entrypoints.
- **Decision needed:** Identify which node codes/types constitute the first binding node (assembly/merge or equivalent) in current Hatthasilpa topology.

## DC-05 — Initial pool bootstrap method (INSUFFICIENT EVIDENCE)

- **Reason:** `V-POOL-01` indicates pool is absent; plan needs an initial baseline.
- **Decision needed:** Choose initial pool bootstrap strategy:
  - from physical inventory snapshot
  - from historical events
  - start-empty with explicit manual `POOL_ADJUST` events

## DC-06 — Complete Node ↔ Pool State mapping inventory

- **Why required:** Implementation Boundary §6.1 allows Work Queue to read Node Pool State mapping; deterministic pool transitions and projections require a complete inventory.
- **Later phases depending on it:** Phase 2 (yield state meaning), Phase 3 (release state movement), Phase 5 (visibility projection).
- **Why guessing is forbidden:** Any undefined/ambiguous mapping must be labeled **INSUFFICIENT EVIDENCE**; inventing state meaning violates canonical determinism.

## DC-07 — Batch vs Binding classification for all nodes (execution boundary)

- **Why required:** The plan must deterministically distinguish pre-binding batch behavior from binding behavior to enforce `pool_mode=transform` vs `pool_mode=allocate` boundaries.
- **Later phases depending on it:** Phase 4 (routing containment for pre-binding), Phase 6 (binding allocation canonicalization).
- **Why guessing is forbidden:** Misclassification would reintroduce early ownership or token-flow authority; ambiguity must be labeled **INSUFFICIENT EVIDENCE**.

## DC-08 — Component code taxonomy used by pool events

- **Why required:** Pool events and pool keys require deterministic `component_code` usage; inconsistent taxonomy breaks replay determinism and audit.
- **Later phases depending on it:** Phase 2 (yield produces component quantities), Phase 3 (release moves component quantities), Phase 5 (projection aggregates by component requirements).
- **Why guessing is forbidden:** If component codes cannot be defined deterministically, events become non-replayable; the correct label is **INSUFFICIENT EVIDENCE**.

---
