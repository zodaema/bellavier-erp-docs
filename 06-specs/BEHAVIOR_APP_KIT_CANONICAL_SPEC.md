# Behavior App Kit v1 — Canonical Spec (Core OS vs Node Behavior Applications)
**Date:** 2026-01-16  
**Status:** CANONICAL  

This document defines the neutral, system-wide “Behavior Application” contract.

**Goal:** Make it fast to build new Node Behaviors without repeatedly re-learning how to integrate with the platform (Work Queue / Work Modal / Monitoring), while keeping the platform (Core) stable.

---

## 0) Architecture boundary (non-negotiable)

### 0.5 Canonical path tripwire (autoload safety)
Canonical path for `BGERP\\Dag\\*` is `source/dag/`. Do not create parallel definitions under `source/BGERP/` unless PSR-4 mapping is explicitly migrated.

### 0.1 Core = OS (bloodstream)
Core owns platform-wide semantics:
- DAG routing and token lifecycle
- Canonical UI contracts consumed by multiple pages
- Platform policy: permission/assignment/concurrency/monitoring

### 0.2 Node Behavior = Application
A Node Behavior is an application running inside the core modal/queue UX.
- It may have its own SSOT ledger/state
- It must not redefine global routing/session/permission semantics

### 0.3 SSOT is scoped
- **Platform SSOT** remains platform-owned.
- **Behavior SSOT** may exist only for that behavior’s internal ledger/state.

### 0.4 Projection is not authority
Projections (`session_status`, `time_summary`, derived flags) are for display/monitoring.
- Authorization and safety decisions must be enforced server-side.

---

## 1) Change classification (risk tiers)

- **Tier 0 — Behavior-local:** changes confined to a single behavior’s UI + endpoints + ledger.
- **Tier 1 — Adapter/Projection:** maps behavior state into canonical core contracts (safe when additive + backwards-compatible).
- **Tier 2 — Core contract:** changes to canonical fields consumed by multiple pages. Requires explicit decision + migration plan.
- **Tier 3 — Core kernel:** routing/session/permission semantics. Highest risk.

Default stance: **prefer Tier 0–1**.

---

## 2) Canonical contracts (OS-facing)

These contracts exist so core pages don’t need behavior-specific logic.

### 2.1 `session_status` (canonical activity signal)
**Required canonical field for any “work-like” behavior:**
- `active | paused | none`

### 2.2 `time_summary` (optional projection)
**Optional but recommended for behaviors that track time:**
- `{ presence_seconds, effort_seconds, first_started_at, last_activity_at, is_running? }`

Rules:
- `time_summary` must be derived from behavior SSOT (ledger), not from client timing.
- `time_summary` must not be used as an authorization gate.

### 2.3 Canonical error contract
All behavior endpoints should return:
- `ok: boolean`
- `error: string` (human readable)
- `app_code: string` (stable, machine readable)

---

## 3) Two behavior classes (supported by Kit v1)

### 3.1 Class A — Session-based (CUT-style)
- Has a session lifecycle: `start/pause/resume/end` (or `start/end` only)
- May have degraded mode (offline/network fail)
- May support sub-actions (yield/release)

### 3.2 Class B — Form/Action-based (STITCH/QC-style)
- No continuous session required
- Primary actions are discrete submissions (e.g., `qc_pass/qc_fail`, `complete`, `save_form`)

Kit rule:
- A behavior can implement either class, or both (but must still project canonical contracts).

---

## 4) Standardized context shape (UI → Behavior)

When the OS mounts a behavior UI, it must provide a stable context.

### 4.1 `BehaviorContext` (required keys)
- `source_page` (e.g., `work_queue`, `manager_assignment`, `debug`)
- `behavior_code` (uppercase string)
- `token_id` (int)
- `node_id` (int)

### 4.2 Optional keys (strongly recommended)
- `work_center_code` (string|null)
- `job_ticket_id` (int|null)
- `mo_id` (int|null)
- `extra` (object) — safe display-only metadata (serial_number, ticket_code)

Rules:
- Context must not contain secrets.
- Behavior must not assume context fields are authoritative; server must validate.

---

## 5) Behavior UI lifecycle hooks (JS-side)

Kit v1 standardizes behavior init and lifecycle.

### 5.1 Required hooks
- `mount(containerEl, context)`
- `unmount()`

### 5.2 Optional hooks
- `onVisibilityChange(isVisible)`
- `onTokenUpdated(tokenPayload)` (fresh server snapshot)

### 5.3 Session-based optional hooks (Class A)
- `onSessionStateChanged(session_status, details)`
- `requestLock({ reason })` / `requestUnlock()`

Rule:
- Lock/unlock requests are **requests**. The OS (host) decides whether to enforce, using server-confirmed state.

---

## 6) Backend behavior action contract (PHP-side)

### 6.1 Entry point
Behavior actions are executed via the behavior execution spine:
- `source/dag_behavior_exec.php` → `BehaviorExecutionService`

### 6.2 Safety requirements (standard)
- Request validation (use standard validator)
- Rate limiting (after auth)
- Idempotency for create/mutation operations
- Tenant isolation
- Standard `ok/error/app_code`

### 6.3 Session SSOT (Class A)
If a behavior is session-based, it must have a ledger/table/service that is SSOT for that behavior.
- Example (CUT): `cut_session` via `CutSessionService`

---

## 7) Projection/Adapter layer (Tier 1)

### 7.1 Purpose
Provide a single place that maps behavior SSOT into canonical contracts.

### 7.2 Rules
- Projection must be additive and backwards-compatible.
- Projection must not become an authorization gate.
- Core pages must not be forced to depend on behavior-specific tables.

### 7.3 Permission view vs canonical contract view (anti-drift)
- For **permission/lock computation**, treat “none” as **empty/null** (permission view).
- For **external canonical payloads** (UI/BI), it is acceptable to emit explicit `session_status: 'none'` (canonical contract view).

Rule:
- Do not feed the canonical contract view directly into permission logic (e.g., `computeTokenPermissions()`), because it may break legacy checks that rely on `empty(session_status)`.

---

## 8) Concurrency & guards (platform policy)

### 8.1 The platform needs a single active-work policy
Even if each behavior has its own ledger, the platform must protect operators from parallel active work.

### 8.2 Implementation rule
- UI guards are helpful but not sufficient.
- Server-side guard is required for any operation that starts active work.

### 8.3 Canonical definition: “enter active work” entrypoints
An endpoint is considered “enter active work” if it can transition an operator into a RUNNING/ACTIVE work state.

Minimum covered entrypoints (non-exhaustive; all future entrypoints must follow the same policy):
- `dag_token_api.php`
  - `start_token` (and any helper/takeover variants)
  - `resume_token`
- `worker_token_api.php`
  - `start_token`
  - `resume_token`
- `dag_behavior_exec.php` (behavior spine)
  - `cut_session_start` / `cut_session_resume` (Class A example)

### 8.4 Authority doctrine (non-negotiable)
- The active-work guard is **authority-side** (server), not a UI convenience.
- The guard must be enforced on **every** enter-active-work entrypoint.
- Projection fields (`session_status`, `time_summary`) are not sufficient for enforcement.

### 8.5 Determinism doctrine (race protection)
The guard must not be “best-effort”. It must be deterministic under concurrency.

Rule:
- Token-level locking (locking only `flow_token` for the target token) is **not sufficient**, because an operator can race across multiple tokens.
- The guard should use an operator-level serialization mechanism (e.g., a DB lock keyed by operator identity) so that:
  - check(legacy active, behavior active)
  - then start/resume
  occurs atomically for that operator.

### 8.6 Guard availability doctrine (fail-closed)
If the server cannot evaluate the guard (schema missing, query failure, lock failure), it must **fail-closed** for enter-active-work.

Reason:
- Guard unavailability is a kernel-safety condition; silent bypass creates the highest risk window for double-active sessions.

### 8.7 Standard error shape for conflict
For enter-active-work conflicts, return:
- HTTP `409`
- `app_code` identifying the conflict (stable)
- `conflict` payload (optional but recommended) describing the existing session/token

---

## 9) Degraded mode (for Class A behaviors)

### 9.1 Goal
Prevent unsafe escape routes when the backend is unavailable but the user likely has an active session.

### 9.2 Approved pattern
- Backend is SSOT.
- If backend check fails and a local hint indicates RUNNING:
  - soft-lock + retry UI
- If backend check fails and no hint exists:
  - fail open (do not lock), show error

Clarification:
- This section describes **UI degraded behavior** (display/UX).
- It does not override the authority doctrine in §8:
  - server-side enter-active-work guard must remain authoritative and fail-closed when guard cannot be evaluated.

---

## 10) Compliance checklist (pre-flight)

Before implementing or modifying a behavior:
- Identify tier (0–3)
- List canonical fields touched (`session_status`, `time_summary`, others)
- List consumers (queue/modal/monitoring/manager)
- Confirm SSOT table/service for the change
- Define rollback (feature flag / safe fallback)

---

## 11) CUT as exemplar (non-authoritative)

CUT is the reference implementation for Class A behaviors:
- session ledger (SSOT)
- degraded mode
- strict identity validation
- partial release (sub-actions)

But:
- CUT does not redefine platform routing/timeline semantics.
- CUT SSOT is scoped to CUT timing only.
