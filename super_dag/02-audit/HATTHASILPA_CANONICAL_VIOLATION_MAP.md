# Hatthasilpa Canonical Violation Map (Current Codebase)

**Status:** AUDIT (Evidence-based; non-solutioning)  
**Date:** 2026-01-21  
**Scope:** Current repository state under `/Applications/MAMP/htdocs/bellavier-group-erp`  

This document maps **observed code behavior** to **canonical violations** against the following locked canonical documents:

- `docs/super_dag/01-canonical/HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md`
- `docs/super_dag/01-canonical/HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_NODE_POOL_STATE_MAPPING_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_ALLOCATION_POLICY_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_REALITY_EVENT_CANONICAL.md`
- `docs/super_dag/01-canonical/HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md`

**Important constraints of this audit:**

- This is a **violation map only**.
- **No refactor proposals**.
- **No migration steps**.
- **No intent interpretation**.
- Where evidence is insufficient, this document explicitly labels **INSUFFICIENT EVIDENCE**.

---

## Audit Method (Evidence Sources)

Evidence was gathered from:

- Direct code inspection of:
  - `source/dag_token_api.php`
  - `assets/javascripts/pwa_scan/work_queue.js`
  - `source/BGERP/Service/TokenLifecycleService.php`
  - `source/BGERP/Service/DAGRoutingService.php`
  - `source/BGERP/Dag/BehaviorExecutionService.php`
  - `source/BGERP/Component/ComponentBindingService.php`
  - `source/BGERP/Service/MaterialReservationService.php`
  - `source/BGERP/Service/MaterialAllocationService.php`
- Repository search for canonical pool event constructs (e.g., `POOL_TRANSFORM`, `POOL_ALLOCATE`) which returned **no matches** in `source/**`.

---

## Classification Vocabulary

- **Token Authority Leak**: Token lifecycle / token movement treated as pre-binding reality authority.
- **Pool Authority Violation**: Pool SSOT absent or bypassed for pre-binding reality.
- **Projection → Mutation**: Projection layer (queue/visibility) causes or enforces mutations.
- **Soft Binding**: Ownership-like linking without canonical allocation at Binding Nodes.
- **Queue-as-Command**: Queue/visibility/derived flags treated as permission or gating.
- **Other**: Must be explicitly defined in the entry.

---

# Violations

## 1) Work Queue construction & filtering

### ❌ V-QUEUE-01 — Work Queue is constructed from `flow_token` status + `current_node_id` (token-flow visibility)

- **Canonical rule violated**
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §E.4 (Queue reconciliation derived from pool quantities + BOM)
  - `HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md` §4.1–§4.3 (Visibility Engine inputs/outputs; pool+demand+topology) and §4.6 (must not be execution trigger)
  - `HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md` §2.4.3 (Forbidden conflation: token moved/queue shown treated as transition)
- **Code location(s)**
  - `source/dag_token_api.php`
    - `handleGetWorkQueue(...)`
    - **Lines:** 2481–2624
    - Evidence excerpt:
      - `FROM flow_token t` (line 2577)
      - `WHERE (t.status = 'ready' OR (t.status IN ('active','paused') ...) OR (cs.id_session IS NOT NULL))` (lines 2614–2618)
- **Why this violates Canonical law**
  - Canonical Hatthasilpa requires queue visibility/progress to be derived from **Pool SSOT** (pre-binding reality) and BOM reconciliation, not from token lifecycle fields.
- **Severity:** TOLERATED
  - **Tolerated basis:** `HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md` §7.1 allows legacy token-flow code paths to coexist temporarily **only as non-authoritative projections**.
- **Classification:** Token Authority Leak

### ❌ V-QUEUE-02 — Work Queue/Start action is blocked by derived “can_start” and shortage gates (queue-as-permission)

- **Canonical rule violated**
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §E.1 (Queue is suggestion only; never permission)
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §G.4 (Explicit non-goal: treating queue as permission gate)
  - `HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md` §2.3.3 (Forbidden: readiness authorizes actions)
  - `HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md` §6.2 (Work Queue must never trigger/authorize)
- **Code location(s)**
  - `source/dag_token_api.php`
    - `computeTokenPermissions(...)` (permission flags for queue)
    - **Lines:** 2417–2467
    - Evidence excerpt:
      - `can_start => $status === 'ready' ... && !$hasShortage ...` (lines 2445–2451)
  - `source/dag_token_api.php`
    - `handleStartToken(...)`
    - **Lines:** 3915–3986
    - Evidence excerpt:
      - `checkMaterialShortageForToken(...)` then `json_error('Cannot start work: Material shortage detected...', 409, ...)` (lines 3975–3986)
- **Why this violates Canonical law**
  - Canonical Hatthasilpa requires Work Queue to be suggestion-only and explicitly tolerant of working ahead/out of order.
  - The observed behavior introduces a **hard block** on starting work derived from system checks, which functions as a permission gate.
- **Severity:** BLOCKER
- **Classification:** Queue-as-Command

### ❌ V-QUEUE-03 — Work Queue UI explicitly describes itself as “flow_token + token_work_session” operator queue

- **Canonical rule violated**
  - `HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md` §4.2 (Visibility Engine inputs include Pool snapshot; not token lifecycle as authority)
  - `HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md` §2.1–§2.3 (Reality > Projection > Intent; token is not SSOT)
- **Code location(s)**
  - `assets/javascripts/pwa_scan/work_queue.js`
    - File header comment
    - **Lines:** 1–14
    - Evidence excerpt:
      - “Purpose: Display and manage operator's work queue (flow_token + token_work_session)” (line 4)
- **Why this violates Canonical law**
  - Canonical Hatthasilpa requires pool-first pre-binding reality and visibility derived from pool evidence; this description indicates the queue is fundamentally built on token/session state.
- **Severity:** TOLERATED
  - **Tolerated basis:** `HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md` §7.1 (temporary coexistence as projection only).
- **Classification:** Token Authority Leak

---

## 2) Token lifecycle usage (status, transitions)

### ❌ V-TOKEN-01 — Token status transitions are used as operational state (`ready/active/paused`) and emit node events

- **Canonical rule violated**
  - `HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md` §2.2.3 (Forbidden: token lifecycle implies physical completion pre-binding)
  - `HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md` §4.1 (Forbidden: token lifecycle as proof of batch work)
- **Code location(s)**
  - `source/BGERP/Service/TokenLifecycleService.php`
    - `startWork(...)` **Lines:** 1677–1740
    - `pauseWork(...)` **Lines:** 1751–1814
    - `resumeWork(...)` **Lines:** 1825–1888
- **Why this violates Canonical law**
  - Canonical Hatthasilpa defines token as intent pre-binding; token lifecycle state must not become authoritative evidence of physical completion.
- **Severity:** TOLERATED
  - **Tolerated basis:** `HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md` §7.1 allows legacy token lifecycle to exist temporarily only as projection.
- **Classification:** Token Authority Leak

---

## 3) CUT / Batch behavior execution

### ❌ V-CUT-01 — CUT yield/reality is recorded as token events (`NODE_YIELD`) instead of Pool transform events

- **Canonical rule violated**
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §A.3 (Pool SSOT pre-binding) and §C.6 (Pool Event Taxonomy: `POOL_TRANSFORM`, etc.)
  - `HATTHASILPA_REALITY_EVENT_CANONICAL.md` §5.1 (Pool mutations must originate from canonical reality events) and §8 (Forbidden: events derived from projection)
- **Code location(s)**
  - `source/BGERP/Dag/BehaviorExecutionService.php`
    - `handleCutBatchYieldSave(...)`
    - **Lines:** 1087–1126
    - Evidence excerpt:
      - Persists `event_type = 'NODE_YIELD'` (lines 1109–1116)
- **Why this violates Canonical law**
  - Canonical requires pre-binding physical reality to update Pool SSOT via pool-transform events.
  - The observed system records CUT output via token-scoped events and does not mutate pool.
- **Severity:** BLOCKER
- **Classification:** Pool Authority Violation

---

## 4) Release logic

### ❌ V-REL-01 — CUT release spawns downstream tokens (token-based release / downstream spawning)

- **Canonical rule violated**
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §A.8(3) (Release moves quantities between pools, never tokens)
  - `HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md` §2.2.3 (Forbidden: spawning downstream tokens as release mechanism)
  - `HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md` §4.1 (Forbidden: spawning downstream tokens as consequence of release)
- **Code location(s)**
  - `source/BGERP/Dag/BehaviorExecutionService.php`
    - `handleCutBatchRelease(...)`
    - **Lines:** 1140–1337
    - Evidence excerpt:
      - “Spawn component tokens at target node” (lines 1273–1282)
      - Persists `event_type = 'NODE_RELEASE'` with `selected_token_ids` (lines 1300–1316)
  - `source/BGERP/Service/TokenLifecycleService.php`
    - `spawnComponentTokensForCutRelease(...)`
    - **Lines:** 376–474
- **Why this violates Canonical law**
  - Canonical Hatthasilpa explicitly forbids release creating or moving tokens.
  - Observed implementation uses release to **create new downstream tokens**, which is token-flow execution authority.
- **Severity:** BLOCKER
- **Classification:** Token Authority Leak

### ❌ V-REL-02 — Release accounting uses token events (`NODE_YIELD`/`NODE_RELEASE`) instead of pool quantities

- **Canonical rule violated**
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §E.4 (reconciliation derived from pool quantities)
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §C.2 (Only physical reality events change pool; tokens do not decrement pools directly)
- **Code location(s)**
  - `source/dag_token_api.php`
    - `handleGetCutBatchDetail(...)`
    - **Lines:** 865–1157 (function start + aggregation loop)
    - Evidence excerpt:
      - “Aggregate canonical events from token_event ... NODE_YIELD/NODE_RELEASE” (lines 1113–1157)
- **Why this violates Canonical law**
  - Canonical Hatthasilpa requires pool state/quantity to be SSOT for pre-binding availability.
  - Observed implementation computes CUT “done/released/available” via token events (not pool).
- **Severity:** BLOCKER
- **Classification:** Pool Authority Violation

---

## 5) Downstream node triggering

### ❌ V-ROUTE-01 — Token routing moves tokens through nodes and sets status as readiness signal

- **Canonical rule violated**
  - `HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md` §2.4.3 (Forbidden: token moved treated as node transition)
  - `HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md` §4.1 (Forbidden: “moving tokens” to represent physical progression)
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §A.8(6) (Graph validates meaning, not command execution)
- **Code location(s)**
  - `source/BGERP/Service/TokenLifecycleService.php`
    - `moveToken(...)`
    - **Lines:** 341–374
  - `source/BGERP/Service/DAGRoutingService.php`
    - `routeToken(...)` **Lines:** 63–153
    - `routeToNode(...)` **Lines:** 165–354
    - Evidence excerpt:
      - Calls `tokenService->moveToken(...)` (lines 182–183, 205–206, 237–238)
      - Sets `flow_token.status = 'ready'` “for Work Queue” (lines 290–304)
- **Why this violates Canonical law**
  - Canonical Hatthasilpa requires downstream visibility to arise from Pool state, not from token movement/routing.
  - Observed implementation treats token movement and token status updates as the primary progression mechanism.
- **Severity:** BLOCKER
- **Classification:** Token Authority Leak

### ❌ V-ROUTE-02 — Parallel split/merge spawns component tokens and re-activates parent token as executable outcome

- **Canonical rule violated**
  - `HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md` §2.2.3 (Forbidden: spawning downstream tokens as release mechanism)
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §A.8(3) (Release moves quantities between pools, never tokens)
  - `HATTHASILPA_IMPLEMENTATION_BOUNDARY_CANONICAL.md` §8 (Forbidden refactor patterns: queue-driven/token-driven execution)
- **Code location(s)**
  - `source/BGERP/Service/DAGRoutingService.php`
    - `handleParallelSplit(...)` **Lines:** 3134–3186
      - Sets parent `flow_token.status = 'waiting'` (lines 3153–3157)
      - Uses coordinator “handleSplit” to spawn child tokens (lines 3145–3152)
    - `handleMergeNode(...)` **Lines:** 3198–3310
      - Sets parent `current_node_id` and `status = 'ready'` (lines 3278–3287)
- **Why this violates Canonical law**
  - Canonical Hatthasilpa forbids token spawning/movement as the carrier of pre-binding physical progression.
  - The observed design treats token spawning and parent re-activation as the mechanism by which work becomes “runnable.”
- **Severity:** BLOCKER
- **Classification:** Token Authority Leak

---

## 6) Pool mutation paths

### ❌ V-POOL-01 — Canonical Pool subsystem and pool event taxonomy are absent from codebase (no `POOL_*` event paths)

- **Canonical rule violated**
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §A.3 (Pool SSOT pre-binding) and §C.6 (Required pool event taxonomy)
  - `HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md` §2.1.1–§2.1.4 (Pool IS SSOT; reservation/soft binding forbidden)
  - `HATTHASILPA_REALITY_EVENT_CANONICAL.md` §5.1 (Which events mutate pool)
- **Code location(s)**
  - **No code locations found.**
  - Evidence:
    - Repository search for `component_pool|POOL_TRANSFORM|POOL_ALLOCATE|pool_key|pool_state` in `source/**` returned **no matches**.
- **Why this violates Canonical law**
  - Canonical requires Pool to exist as SSOT for pre-binding physical reality, with explicit pool mutation events.
  - Observed implementation records pre-binding output via token events and token rows, with no pool SSOT event path.
- **Severity:** BLOCKER
- **Classification:** Pool Authority Violation

---

## 7) Ownership creation paths

### ❌ V-OWN-01 — Component serials can be bound to tokens (explicit “soft binding”)

- **Canonical rule violated**
  - `HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` §A.6 (Allocation is the only operation that creates ownership)
  - `HATTHASILPA_ALLOCATION_POLICY_CANONICAL.md` §3 (Allocation is not reservation/soft binding) and §8 (Forbidden patterns)
  - `HATTHASILPA_POOL_TOKEN_INTEGRATION_CANONICAL.md` §2.1.4 (Forbidden: soft binding) and §2.2.3 (Forbidden: early ownership)
- **Code location(s)**
  - `source/BGERP/Component/ComponentBindingService.php`
    - File header note declares “soft binding”
    - **Lines:** 1–21
    - `bindSerialToToken(...)`
    - **Lines:** 49–116
    - Evidence excerpt:
      - Inserts binding record and updates serial status to `used` (lines 77–99)
- **Why this violates Canonical law**
  - Canonical Hatthasilpa defines ownership creation strictly at Binding Nodes via allocation from pool.
  - This service creates a token↔serial ownership-like link independent of binding-node allocation.
- **Severity:** BLOCKER
- **Classification:** Soft Binding

### ❌ V-OWN-02 — Material reservation/allocation subsystem implements “soft locks” and “allocate to token on start”

- **Canonical rule violated**
  - **INSUFFICIENT EVIDENCE**: Hatthasilpa canonical law is explicit about **component pool** semantics; it does not define whether raw material lot reservation/allocation is governed by the same no-reservation doctrine.
  - However, the pattern matches the forbidden shape “reservation/soft lock” described in:
    - `HATTHASILPA_ALLOCATION_POLICY_CANONICAL.md` §3 (No reservation / soft binding) **if** interpreted as a pool-equivalent.
- **Code location(s)**
  - `source/BGERP/Service/MaterialReservationService.php`
    - Header: “Manage soft-locks on inventory when jobs are created”
    - **Lines:** 1–13
    - `createReservations(...)`
    - **Lines:** 54–110
  - `source/BGERP/Service/MaterialAllocationService.php`
    - Header: “Hard-link materials to specific tokens when work starts”
    - **Lines:** 1–12
    - `allocateToToken(...)`
    - **Lines:** 55–142
- **Why this violates Canonical law**
  - **INSUFFICIENT EVIDENCE**: canonical applicability to raw material lot reservation/allocation is not explicitly defined in the Hatthasilpa pool/ownership canon.
- **Severity:** TOLERATED
  - Basis: canonical applicability is **INSUFFICIENT EVIDENCE** (this entry is recorded for visibility; not proven as a Hatthasilpa pool violation).
- **Classification:** Other — “Reservation subsystem outside defined Pool SSOT scope (INSUFFICIENT EVIDENCE)”

---

# Summary Index (for owners)

- **BLOCKER violations**
  - V-QUEUE-02
  - V-CUT-01
  - V-REL-01
  - V-REL-02
  - V-ROUTE-01
  - V-ROUTE-02
  - V-POOL-01
  - V-OWN-01

- **TOLERATED violations (Implementation Boundary §7 / or INSUFFICIENT EVIDENCE)**
  - V-QUEUE-01 (Implementation Boundary §7.1)
  - V-QUEUE-03 (Implementation Boundary §7.1)
  - V-TOKEN-01 (Implementation Boundary §7.1)
  - V-OWN-02 (**INSUFFICIENT EVIDENCE** on canonical applicability)
