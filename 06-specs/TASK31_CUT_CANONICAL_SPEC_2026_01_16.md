# Task 31 — Canonical Spec: CUT as a Node Behavior Application (SSOT + UX + Integration)
**Date:** 2026-01-16  
**Status:** CANONICAL (Single Source of Truth for Task31 decisions)  

This document consolidates Task31 into one authoritative spec to prevent drift.

---

## 0) Scope & Non‑Goals (Architecture Guardrails)

### 0.1 What this spec covers
- CUT behavior timing and session lifecycle (SSOT)
- CUT batch yield + partial release semantics
- Modal lock & degraded mode behavior
- Canonical event semantics (`NODE_YIELD`, `NODE_RELEASE`) and how they relate to timeline reconstruction
- Adapter/projection rules to display CUT state in Work Queue / Work Modal / Manager Monitoring

### 0.2 Non‑goals (explicitly out of scope)
- Replacing core DAG routing / token lifecycle with CUT behavior
- Replacing platform-wide session/timing semantics for all nodes
- Making behavior-only tables the platform SSOT

---

## 1) Mental Model

- **Core = OS (bloodstream):** DAG routing + token lifecycle + canonical UI contracts
- **Node Behavior = Application:** runs inside the modal/queue panel, integrates via adapter/projection layers

Change tiers:
- Tier 0: behavior-local
- Tier 1: adapter/projection
- Tier 2+: core contract/kernel (requires explicit approval)

---

## 2) Canonical Contracts (Platform-level)

### 2.1 `session_status` (canonical activity signal)
- Values: `active | paused | none`

### 2.2 `time_summary` (optional projection for display/reporting)
If/when present:
- `{ presence_seconds, effort_seconds, first_started_at, last_activity_at, is_running? }`

### 2.3 Concurrency policy (platform-level)
- An operator must not run conflicting active work in parallel.

---

## 3) SSOT Boundaries (What owns truth)

### 3.1 CUT timing SSOT
- **SSOT:** `cut_session` (via `CutSessionService`)
- **NOT SSOT:** `token_work_session`

Policy:
- UI-provided timing is non-trusted.
- Backend timestamps must be server time.

### 3.2 Audit/event SSOT for yield/release
- Canonical audit log is persisted via `TokenEventService` using canonical types.

---

## 4) Status Mapping (CUT → Canonical)

CUT internal states:
- `RUNNING | PAUSED | ENDED | ABORTED`

Canonical projection mapping:
- `RUNNING` → `session_status = 'active'`
- `PAUSED` → `session_status = 'paused'`
- no active CUT session → `session_status = 'none'`

Notes:
- `ENDED/ABORTED` are ledger history; they should not project as “active”.

---

## 5) Data Model: `cut_session` (SSOT ledger)

Key properties:
- Identity: `(token_id, node_id, operator_id, component_code, role_code, material_sku[, material_sheet_id])`
- Server time fields: `started_at, ended_at, paused_at, resumed_at`
- Server-computed: `duration_seconds`, `paused_total_seconds`

Concurrency guard:
- One active session per `(token_id, node_id, operator_id)` is enforced at DB level via `active_session_key` + UNIQUE.

---

## 6) API: Behavior Execution (CUT app spine)

Endpoint:
- `source/dag_behavior_exec.php` via `BehaviorExecutionService`

### 6.1 Session lifecycle actions
- `cut_session_start`
- `cut_session_pause`
- `cut_session_resume`
- `cut_session_end`
- `cut_session_abort`
- `cut_session_get_active`

Rules:
- Every mutation supports/uses `idempotency_key`.
- If a client sends timing fields (`started_at`, `finished_at`, `duration_seconds`) they are ignored/rejected as authoritative.

### 6.2 Batch yield + partial release actions
- `cut_batch_yield_save`
- `cut_batch_release`

Both actions:
- Must be idempotent.
- Must persist canonical events using allowed canonical types.
- Must be concurrency-safe (transaction + deterministic selection).

---

## 7) Canonical Events: `NODE_YIELD` / `NODE_RELEASE`

### 7.1 Whitelist and persistence
- `NODE_YIELD` and `NODE_RELEASE` must be in canonical whitelist.
- Persisted through `TokenEventService` (never ad-hoc logging).

### 7.2 Timeline semantics (Option A)
- `NODE_YIELD` is **informational** and must not drive token timeline fields.
- Timeline reconstruction processes only:
  - `NODE_START`, `NODE_PAUSE`, `NODE_RESUME`, `NODE_COMPLETE`

Forbidden:
- Using `NODE_YIELD.duration_seconds` to update `flow_token.actual_duration_ms`.

---

## 8) UX Spec (CUT is an Application)

### 8.1 Option A: Task selection (mandatory)
Phase 1:
- Select `Component` → `Role` → `Material`

Phase 2:
- Cutting session screen shows the selected identity prominently.

Phase 3:
- Post-save returns to Phase 1 and updates progress.

### 8.2 Modal lock rules
- While CUT session is RUNNING: modal is locked (cannot close)
- When PAUSED: modal may be closable

### 8.3 Degraded mode
- Backend is SSOT.
- If backend check fails AND local hint indicates RUNNING:
  - soft-lock + retry overlay (do not unlock by default)

---

## 9) Integration with Core UI (Adapter/Projection)

### 9.1 Work Queue / Work Modal
- `get_work_queue` / `get_token_detail` should project CUT state into canonical contracts:
  - `session.status` and `timer.status` for UI compatibility
  - `permissions` based on projected session state

### 9.2 Manager monitoring
- `manager_all_tokens` must project CUT session into `session_status` so manager UI stays correct.

Rule:
- Core pages should not be forced to query behavior-only tables directly.

---

## 10) Roadmap: Make CUT Node a “great app” (Tier 0–1)

### 10.1 Product UX
- Eliminate ambiguity: identity is always explicit (Component+Role+Material)
- Clear progress & next action (Yield vs Release)
- Strong error messages mapped by `app_code` (actionable)

### 10.2 Reliability & resilience
- Idempotency everywhere (start/pause/resume/end/yield/release)
- Degraded mode tested (network drop + refresh)
- Deterministic selection rules for release (stable ordering)

### 10.3 Observability
- Correlation IDs everywhere
- Log app_code + token_id + node_id + operator_id on failures

### 10.4 Projection for platform consistency
- Continue projecting to `session_status` and (next) `time_summary` for CUT
- Keep projection non-authoritative: server guards remain gates

### 10.5 Tests
- Integration tests for:
  - session lifecycle
  - yield idempotency
  - release concurrency
  - degraded mode behavior

---

## 11) References (source documents)

These documents remain as references/implementation notes, but this file is canonical:
- `docs/super_dag/tasks/archive/task31/task31_CUT_TIMING_SSOT_POLICY.md`
- `docs/super_dag/tasks/archive/task31/task31_CUT_SSOT_ARCHITECTURE_LOCK.md`
- `docs/super_dag/tasks/archive/task31/task31_CUT_SESSION_TIMING_SPEC.md`
- `docs/super_dag/tasks/archive/task31/task31_CUT_SESSION_ERROR_HANDLING.md`
- `docs/super_dag/tasks/archive/task31/task31_CUT_UX_REDESIGN_OPTION_A.md`
- `docs/super_dag/tasks/archive/task31/task31_CUT_OPTION_A_IMPLEMENTATION_SUMMARY.md`
- `docs/super_dag/tasks/archive/task31/task31_CUT_MODAL_LOCK_DEGRADED_MODE.md`
- `docs/super_dag/tasks/archive/task31/task31_CUTTING_BATCH_PARTIAL_RELEASE.md`
