# Behavior App Kit v1 — Implementation Playbook (Checklist)
**Date:** 2026-01-16  

This is a 1-page checklist to add a new Node Behavior as an “Application” that plugs into the OS safely.

---

## 0) Pre-flight (required)
- Classify change tier (0–3)
- Confirm behavior class:
  - Class A (session-based)
  - Class B (form/action-based)
- Confirm SSOT scope:
  - Behavior ledger is SSOT for behavior only
  - Platform SSOT remains unchanged

---

## 1) Define the behavior identity
- Choose `behavior_code` (UPPERCASE, stable)
- Decide if behavior is:
  - Session-based (start/pause/resume/end)
  - Action-based (submit/complete)

---

## 2) Backend (Behavior execution spine)

### 2.1 Add/confirm behavior actions
- Implement actions in `BehaviorExecutionService`
- Validate inputs server-side
- Return `{ ok, error, app_code }`

### 2.2 Idempotency
- Any mutation must accept `idempotency_key`
- On retry, return existing result (no duplicate side effects)

### 2.3 Concurrency guard
- If behavior can be “active work”, enforce server-side policy:
  - operator cannot run conflicting active work in parallel

Checklist (enter-active-work policy):
- Identify all enter-active-work actions (start/resume equivalents)
  - Work Queue: `dag_token_api.php` start/resume (including helper/takeover)
  - Worker App: `worker_token_api.php` start/resume
  - Behavior spine: `dag_behavior_exec.php` session start/resume
- Use an authority-side guard (server) on every enter-active-work entrypoint
- Ensure the guard is deterministic under concurrency (operator-level serialization)
- If the server cannot evaluate the guard, fail-closed for enter-active-work
- Return conflict using HTTP 409 with stable `app_code` and optional `conflict` payload

---

## 3) Behavior SSOT ledger (Class A)

If session-based:
- Use a behavior-owned ledger/table (`*_session`)
- Server time only for authoritative timestamps
- Explicit state machine (`RUNNING/PAUSED/ENDED/...`)

---

## 4) Projection (Tier 1)

Add a projection that maps behavior state into canonical contracts:
- `session_status: active|paused|none`
- optional `time_summary`

Rules:
- Projection is display-only (not authority)
- Core pages should not depend on behavior tables directly

---

## 5) Frontend (Behavior UI)

### 5.1 Implement behavior UI module
- Implement `mount(containerEl, context)`
- Implement `unmount()`
- Keep all UI state inside the behavior module (no global leaks)

### 5.2 Use standard context shape
- `source_page`, `behavior_code`, `token_id`, `node_id` required

### 5.3 Error UX
- Surface `app_code`-mapped errors with actionable messages

---

## 6) OS integration (thin)

- Mount behavior via the OS host (Work Modal)
- OS handles:
  - modal lifecycle
  - close lock (server-confirmed active work)
  - refresh token snapshots

Behavior can request lock/unlock, but OS decides.

---

## 7) Testing

### Class A (session-based)
- Start → pause → resume → end
- Network retry idempotency
- Degraded mode behavior
- Concurrency (2 tabs / 2 requests)

Guard tests (required):
- Legacy active blocks CUT start/resume
- CUT RUNNING blocks legacy start/resume
- Guard failure mode (simulate missing table / query failure) fails-closed for enter-active-work

### Class B (action-based)
- Submit action
- Validation failures and error mapping

---

## 8) Documentation
- Update:
  - `docs/06-specs/BEHAVIOR_APP_KIT_CANONICAL_SPEC.md` (only if contract changes)
  - behavior-specific spec doc (optional)

---

## 9) Final sanity checks
- No Tier 2–3 changes without explicit approval
- Canonical fields remain stable
- Projection is not used as authority
