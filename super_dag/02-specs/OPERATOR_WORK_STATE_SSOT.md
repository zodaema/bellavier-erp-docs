# Operator Work State SSOT — OperatorWorkStateService (Central Resolver + Projection Contract)

## FREEZE (Reference-Only)

**Status:** Frozen (Reference Law Candidate)

- This document is a **formal reference specification**.
- **Do not implement** this SSOT as a production dependency until **Pool + CUT-GROUP** are stable.
- Pages/services MAY cite this spec as a **mandatory reference** during reviews.
- Any implementation proposal must include:
  - Tier classification (0–3) and blast-radius assessment
  - Migration plan alignment (see “Migration Plan (Future)”)
  - Rollback strategy

---

## Purpose

Define a centralized, platform-level resolver that provides a **single, canonical “what an operator is doing right now”** view for:

- People Tab (Manager Assignment → People)
- Manager dashboards / monitoring pages
- Future reporting surfaces that need *current* operator state

This spec defines a **contract + authority model + resolution algorithm**. It is intentionally **design-only** and does not prescribe UI flows or implementation details.

---

## Definitions

### Operator
A human worker identified by `operator_id` (maps to member/user identity in the system).

### Work State (Operator)
The system’s canonical interpretation of an operator’s **current activity state** and **current work focus** at a point in time.

### SSOT vs Projection
- **SSOT (authoritative source):** A domain-owned record that defines truth about a session/activity.
  - CUT: `cut_session` for batch micro-sessions
  - Non-CUT: `token_work_session` for single-flow continuous work
- **Projection:** A derived view assembled from multiple authoritative sources. The resolver output is a projection, but it must be treated as the **single contract** consumed by UIs.

### Session Types
- **CUT Batch Micro-Session:** A session scoped to a component+role+material unit of execution; **Save/Cancel ends the session**. Authority: `cut_session`.
- **Single-flow Session:** A continuous per-token session where paused persists until resumed/completed. Authority: `token_work_session`.

### Status Vocabulary (Operator-level)
- `available`: operator is eligible for work now and not currently active/paused on any work.
- `active`: operator has at least one currently-running authoritative session selected as `current_work`.
- `paused`: operator has no running session, but has at least one paused authoritative session selected as `current_work`.
- `unavailable`: operator is not eligible for work now due to availability constraints, regardless of sessions, *unless the system flags an inconsistency*.

**Note:** This spec does not redefine token/node READY semantics. This is operator state only.

---

## Output Contract (JSON-like)

```jsonc
{
  "operator_id": 123,

  "operator_status": "available | active | paused | unavailable",

  "current_work": {
    "work_type": "session | assignment_only | none",

    "behavior_code": "CUT | STITCH | EDGE | ...",
    "execution_mode": "BATCH | HAT_SINGLE | ...",          // if derivable; may be null
    "node_id": 456,
    "node_code": "CUT_01",
    "node_name": "Cutting",

    "token_id": 789,                                      // null if none
    "job_id": null,                                       // optional, if available
    "job_code": "JOB-2026-0001",                           // optional

    "session": {
      "session_type": "cut_session | token_work_session",
      "session_id": 111,
      "session_status": "RUNNING | PAUSED | active | paused",
      "started_at": "2026-01-19T12:00:00Z",
      "paused_at": null,
      "resumed_at": null,
      "ended_at": null,

      "identity": {
        "cut": {
          "component_code": "CMP001",
          "role_code": "MAIN",
          "material_sku": "LEATHER-ABC"
        }
      }
    },

    "assignment": {
      "assignment_id": 222,
      "assignment_status": "assigned | accepted | started | paused | direct | cut_session | none"
    }
  },

  "timer_summary": {
    "presence_seconds": 0,              // optional, if platform-level presence exists; else null
    "effort_seconds": 360,              // read-only computed from authoritative session timing fields
    "paused_total_seconds": 0,
    "first_started_at": "2026-01-19T12:00:00Z",
    "last_activity_at": "2026-01-19T12:06:00Z",
    "is_running": true
  },

  "workload_summary": {
    "active_count": 1,
    "paused_count": 0,
    "assigned_count": 3,

    "active_items": [
      { "token_id": 789, "behavior_code": "CUT", "node_id": 456, "session_type": "cut_session", "session_id": 111 }
    ],
    "paused_items": [],
    "assigned_items": [
      { "token_id": 790, "assignment_id": 223, "behavior_code": "STITCH", "node_id": 460 }
    ]
  },

  "availability": {
    "availability_status": "available | unavailable",
    "reason_code": "manual_unavailable | shift_off | role_mismatch | unknown | none",
    "source": "availability_service | schedule | manual_override",
    "effective_at": "2026-01-19T12:00:00Z"
  },

  "meta": {
    "server_time": "2026-01-19T12:07:00Z",

    "resolved_via": [
      {
        "source": "cut_session",
        "rows_considered": 1,
        "notes": "CUT ignores token_work_session by invariant"
      },
      {
        "source": "token_work_session",
        "rows_considered": 0
      },
      {
        "source": "token_assignment",
        "rows_considered": 3
      }
    ],

    "warnings": [
      {
        "code": "INCONSISTENT_UNAVAILABLE_WITH_ACTIVE_SESSION",
        "message": "Operator marked unavailable but has RUNNING session; availability may be stale."
      }
    ]
  }
}
```

### Contract Rules

- All computed fields (`operator_status`, `current_work`, `timer_summary`, `workload_summary`) are **read-only projections**.
- `meta.resolved_via` and `meta.warnings` are required for observability and to prevent silent authority drift.

### Session Status Vocabulary Note

The resolver consumes **two distinct session vocabularies**:

- `cut_session`:
  - `RUNNING`, `PAUSED`
- `token_work_session`:
  - `active`, `paused`

Implementations **MUST NOT normalize or merge** these vocabularies.
They are preserved verbatim in `current_work.session.session_status`
and disambiguated by `session_type`.

---

## Authority Rules (Data Sources + Ownership)

### A) Availability (Authoritative for eligibility, not for activity)

**Source:** Availability subsystem (manual status, schedule, etc.)

**Authority:** Determines whether the operator is eligible for new work now.

**Non-authority:** Must not be used to infer what work is being done; it may only constrain `operator_status` to `unavailable` with warnings if conflicting.

### B) CUT Sessions — `cut_session` (Authoritative for CUT activity)

For `behavior_code = CUT`, `cut_session` is the only authority for:

- Whether operator is active/paused on CUT work
- CUT identity fields (component/role/material)
- Timing summary for CUT

**Hard rule:** For CUT, **ignore `token_work_session` completely** (even if it exists).

### C) Single-flow Sessions — `token_work_session` (Authoritative for non-CUT activity)

For behaviors other than CUT:

- Active/paused work state per operator/token
- Timing summary for that session

### D) Assignments — `token_assignment` (Authoritative for assignment intent, not runtime activity)

**Authority:** What work is assigned/accepted/started (human/process intent).

**Non-authority:** Must not be used to claim active work unless an authoritative session exists; must not be used to derive timer values.

### E) Work Queue (Non-authoritative)

Work Queue is explicitly a **projection** and must never be used as an authority input for operator work state.

---

## Resolution Algorithm

### Inputs (per operator)
Resolver collects candidate facts:

- `availability_status` (available/unavailable + reason)
- `cut_sessions` where `operator_id = X` and status in {RUNNING, PAUSED}
- `flow_sessions` (`token_work_session`) where `operator_user_id = X` and status in {active, paused}
- `assignments` where assigned_to_user_id = X and status in {assigned, accepted, started, paused}

### Step 1 — Partition authoritative session candidates

1. **CUT candidates:** from `cut_session` only, where status ∈ {RUNNING, PAUSED}.
2. **Non-CUT candidates:** from `token_work_session` where status ∈ {active, paused}, and associated node/behavior_code is **not CUT**.

### Step 2 — Remove disallowed mixes (behavior rule)

- CUT work must never be derived from `token_work_session`.
- If the system cannot determine behavior_code for a `token_work_session`, treat it as **eligible only for non-CUT**, and emit warning `UNKNOWN_BEHAVIOR_FOR_WORK_SESSION`.

### Step 3 — Choose `current_work` session (if any)

Priority order:

1. **RUNNING wins over PAUSED**
   - CUT: `RUNNING`
   - Non-CUT: `active`

2. If multiple RUNNING/active sessions exist:
   - **Tie-breaker A (timestamp):** most recent `resumed_at` else `started_at`
   - **Tie-breaker B (behavior priority):** deterministic platform policy list (must be explicit and versioned).
     - **Mandatory fallback (policy-free determinism):**
       If **no behavior-priority policy is configured**, the resolver **MUST** apply the
       following deterministic ordering, in this exact order:
       1. `behavior_code` ASC (lexical)
       2. then `node_id` ASC
       3. then `token_id` ASC
       This fallback is **non-optional** and exists to prevent:
       - “first row wins” behavior
       - database iteration-order dependence
       - non-deterministic People Tab results across refreshes
       Implementations **MUST NOT** rely on database/default ordering at any stage.
   - **Tie-breaker C (token id):** lowest `token_id` to guarantee determinism (only used if still tied)

3. If no RUNNING/active sessions exist but paused sessions exist:
   - choose the paused session with most recent `paused_at`, else most recent `started_at`

### Step 4 — Derive `operator_status`

Given resolved `current_work` and availability:

1. If availability says unavailable:
   - `operator_status = unavailable`
   - If RUNNING/active session exists, emit warning `INCONSISTENT_UNAVAILABLE_WITH_ACTIVE_SESSION`
   - Do not discard the session; expose it as `current_work` because it is authoritative activity

2. Else availability is available:
   - RUNNING/active → `operator_status = active`
   - paused → `operator_status = paused`
   - none → `operator_status = available`

### Step 5 — Populate workload summary

- `active_items` = all authoritative sessions currently RUNNING/active (after behavior filters)
- `paused_items` = all authoritative sessions currently PAUSED/paused (after behavior filters)
- `assigned_items` = assignments not completed/canceled

### Behavior-specific rules (mandatory)

#### CUT

- `current_work.session.session_type = "cut_session"` only
- Ignore `token_work_session` entirely
- Micro-session semantics: if no RUNNING/PAUSED `cut_session`, CUT must not contribute to current state (history cannot force present)

#### Single-flow (non-CUT)

- Paused persists until resumed/completed per `token_work_session` authority
- Session history must not be used; only active/paused statuses

---

## Invariants (Non-negotiable)

1. **No history forcing current state**
   - Ended/aborted/completed sessions must never be used to claim `paused` or `active`.

2. **No mixed authorities for the same behavior**
   - CUT activity must never be inferred from `token_work_session`.
   - Non-CUT activity must never be inferred from `cut_session`.

3. **Projection is not permission**
   - Resolver output must never be used as an authorization gate.

4. **Queue is never authority**
   - Work Queue must not be used as an input.

5. **Deterministic resolution**
   - Same inputs at same `server_time` must produce identical output.

6. **Reset semantics must be respected**
   - CUT: if there is no RUNNING/PAUSED `cut_session`, CUT must reset to “none” immediately (no ghost paused).
   - Single-flow: paused persists only if there is a current paused authoritative session.

---

## Failure Modes to Guard Against

### 1) Ghost paused states

**Symptom:** operator shows paused due to stale legacy session record.

**Guard:** CUT ignores `token_work_session`; allowlist active statuses only.

### 2) History forcing current state

**Symptom:** ended/aborted sessions displayed as active/paused.

**Guard:** explicit status allowlists:

- CUT: RUNNING/PAUSED only
- Non-CUT: active/paused only

### 3) Queue acting as permission / UI-driven authority

**Symptom:** UI state or queue projection blocks/permits actions.

**Guard:** resolver has no side effects and is not consulted for authorization.

### 4) Multiple simultaneous sessions (data integrity issue)

**Symptom:** operator has multiple RUNNING/active sessions.

**Guard:** deterministic tie-breakers; emit warning `MULTIPLE_ACTIVE_SESSIONS_DETECTED`.

### 5) Unknown behavior linkage

**Symptom:** session exists but behavior_code cannot be derived.

**Guard:** keep session but flag `UNKNOWN_BEHAVIOR_FOR_WORK_SESSION`; do not classify as CUT.

---

## Warning Code Catalog

Warnings are part of the resolver output contract (`meta.warnings[]`). They exist to prevent silent authority drift and to make data-integrity issues operationally visible.

### Required shape (all warnings)

- `code` (string, stable ID)
- `message` (string, human-readable)
- `details` (object, optional)
  - SHOULD include identifiers needed for triage (e.g., `session_type`, `session_id`, `token_id`, `node_id`, `behavior_code`).

### Warning Code Stability Rules (Non-negotiable)

- `code` values are a **stable API surface**.
- Warning codes **MUST NOT** be renamed or repurposed.
- If semantics need to change, a **new warning code** MUST be introduced
  (optionally with a `:v2` suffix), and the old code preserved.
- Consumers (dashboards, People Tab) may rely on warning codes for logic,
  visibility, or alerting without defensive fallbacks.

### Standard warning codes

1. `INCONSISTENT_UNAVAILABLE_WITH_ACTIVE_SESSION`
   - Meaning: availability claims unavailable while authoritative session is RUNNING/active.
   - Required details: `availability.source`, `availability.reason_code`, winning `session_type`, `session_id`, `token_id`.

2. `MULTIPLE_ACTIVE_SESSIONS_DETECTED`
   - Meaning: more than one authoritative RUNNING/active session exists for the operator.
   - Required details: array of conflicting sessions (at least `session_type`, `session_id`, `token_id`, `node_id`, `behavior_code`).

3. `UNKNOWN_BEHAVIOR_FOR_WORK_SESSION`
   - Meaning: a non-CUT `token_work_session` exists but resolver cannot reliably map it to a node/behavior.
   - Required details: `token_id`, `id_session` (if present), any node linkage fields that were missing.

4. `CUT_LEGACY_WORK_SESSION_PRESENT`
   - Meaning: a `token_work_session` record exists that appears to be associated with CUT.
   - Policy: CUT must ignore legacy sessions; this warning exists to surface cleanup needs.
   - Required details: `token_id`, `id_session`, any inferred node/behavior linkage.

5. `ASSIGNMENT_SESSION_MISMATCH`
   - Meaning: assignment indicates started/paused but no authoritative session exists (or session is on a different token/node).
   - Required details: `assignment_id`, `assignment_status`, `token_id`.

---

## Migration Plan (Future)

### Phase 1 — Internal Resolver Function

Introduce a centralized resolver function and reuse it across existing endpoints without changing outward response contracts.

### Phase 2 — Projection Service

Formalize `OperatorWorkStateService` as a dedicated projection layer returning the contract above; consumers switch to it.

### Phase 3 — Full SSOT Adoption

All operator-state consumers must use this contract as the only source; legacy per-page resolution logic is removed.

---

## Non-goals

- Not redefining canonical production definitions (Level 0)
- Not changing token lifecycle, pooling, binding, routing, or assignment semantics
- Not assuming UI flows or modal behavior
- Not assuming serial tracking in CUT
- Not introducing a new timer engine or replacing timing SSOT
- Not using projection output as permission/authorization
- Not solving historical reporting; this is “right now” state only

---

## Appendix A — Anti-Patterns (Do Not Write Again)

This appendix lists **forbidden patterns** that previously caused production bugs, especially around CUT micro-sessions.

### A1) Mixing authorities (CUT) — deriving CUT operator state from `token_work_session`

**Forbidden:** any logic that treats `token_work_session` as the source of truth for CUT.

```php
// ❌ WRONG: CUT must never be derived from token_work_session
if ($row['behavior_code'] === 'CUT' && in_array($row['session_status'], ['active','paused'], true)) {
    $operatorStatus = ($row['session_status'] === 'active') ? 'active' : 'paused';
}
```

**Why forbidden:** CUT is batch + micro-session. Legacy sessions can persist and create “ghost paused” states after Save/Cancel.

### A2) Using history to force current state

**Forbidden:** using last-known session (ended/aborted/completed) to infer current operator status.

```js
// ❌ WRONG: history forcing present
const lastSession = sessions.sort((a,b) => b.updated_at - a.updated_at)[0];
if (lastSession) operator_status = 'paused';
```

**Why forbidden:** only current RUNNING/PAUSED (or active/paused) sessions are eligible inputs.

### A3) Treating Work Queue projection as permission or SSOT

**Forbidden:** blocking actions or marking operator state based solely on queue fields.

```js
// ❌ WRONG: queue acting as permission
if (queueToken.session_status === 'paused') {
  disableStartButton();
}
```

**Why forbidden:** Work Queue is a projection. Authorization must come from server-side session services.

### A4) Collapsing multiple session systems into one “status” without source labeling

**Forbidden:** emitting a single `session_status` without recording where it came from (`cut_session` vs `token_work_session`).

```jsonc
// ❌ WRONG: ambiguous status, cannot audit
{ "session_status": "paused" }
```

**Correct principle:** always include `meta.resolved_via` and session_type.

### A5) “Fallback to anything” resolution

**Forbidden:** if CUT session is missing, falling back to non-CUT session sources to fill the gap.

```php
// ❌ WRONG: cross-source fallback that breaks invariants
$session = $cutSession ?: $tokenWorkSession ?: $assignment;
```

**Why forbidden:** cross-source fallback reintroduces mixed authority.

### A6) Non-deterministic tie-breaking

**Forbidden:** choosing “first row returned” without ordering and tie-break policy.

```php
// ❌ WRONG: DB iteration order is not a policy
$current = $rows[0];
```

**Why forbidden:** inconsistent People Tab results across refreshes and indexes.

### A7) UI-driven authority (client decides session truth)

**Forbidden:** client-side state deciding whether a session exists or is active.

```js
// ❌ WRONG: client asserts authoritative session existence
if (localStorage.getItem('cut_session_running')) operator_status = 'active';
```

**Why forbidden:** only authoritative server sources may define session state.

---

## Appendix B — Resolution Scenarios (Normative Examples)

These scenarios are **normative**.

Any future implementation of `OperatorWorkStateService` that produces a
different result for the same inputs **violates this specification**.

This appendix is a **candidate source for future contract / conformance tests**,
but no test implementation is required at this stage.

### B1) CUT micro-session ends → operator must not remain paused

**Inputs:**

- `cut_session`: no rows with status RUNNING/PAUSED
- `token_work_session`: one row for the same token/operator with status `paused` (legacy)
- availability: `available`

**Expected:**

- `operator_status = available`
- `current_work.work_type = none`
- `meta.warnings` includes `CUT_LEGACY_WORK_SESSION_PRESENT`

### B2) CUT paused session exists → operator paused

**Inputs:**

- `cut_session`: one row with status `PAUSED`
- availability: `available`

**Expected:**

- `operator_status = paused`
- `current_work.session.session_type = cut_session`
- `current_work.session.session_status = PAUSED`

### B3) Availability unavailable but session running → unavailable with warning

**Inputs:**

- availability: `unavailable` (manual override)
- authoritative session: one RUNNING/active session exists

**Expected:**

- `operator_status = unavailable`
- `current_work` MUST still point to the running session
- `meta.warnings` includes `INCONSISTENT_UNAVAILABLE_WITH_ACTIVE_SESSION`

### B4) Multiple RUNNING sessions → deterministic selection + warning

**Inputs:**

- two RUNNING/active authoritative sessions exist
  - session A: resumed_at newer
  - session B: resumed_at older

**Expected:**

- winner = session A (timestamp tie-breaker)
- `meta.warnings` includes `MULTIPLE_ACTIVE_SESSIONS_DETECTED`

### B5) No behavior priority policy configured → deterministic lexical fallback

**Inputs:**

- two RUNNING/active sessions exist with identical timestamps
- no behavior-priority policy available
- session 1: `behavior_code = EDGE`, `node_id = 10`, `token_id = 200`
- session 2: `behavior_code = STITCH`, `node_id = 9`, `token_id = 100`

**Expected:**

- winner = session 1 (because `EDGE` < `STITCH` lexical)

