# Implementation Playbook: CUT Micro Ledger → Mainstream Projection (Time Summary)
**Date:** 2026-01-15  
**Scope:** Implementing the time-layer doctrine for CUT without breaking legacy Work Queue / Manager monitoring  
**Primary Spec:** `docs/06-specs/TIME_LAYERS_MICRO_LEDGER_TO_MAINSTREAM_PROJECTION_SPEC_2026_01_15.md`

---

## 0) Objectives
- Implement **micro ledger SSOT** for CUT (`cut_session`) as already enforced by policy.
- Provide a stable **mainstream projection** (`time_summary`) used by Work Queue and Manager.
- Ensure the system remains safe, deterministic, and auditable.

---

## 1) Doctrines / Non-negotiables (Operational)
- Micro ledger is authoritative; projection is rebuildable.
- Never derive “Production Intent Time” from averages automatically.
- Never use projection for authorization or punishment.
- Always preserve auditability (immutability-by-default + audit trail).

---

## 2) Current Reality (Baseline)
- CUT SSOT exists in `cut_session`.
- Legacy mainstream uses `token_work_session` and `BGTimeEngine`.
- Work Queue and Modal often expect legacy-shaped fields (`session.status`, `timer.status`).
- Manager monitoring may read a unified `session_status/operator_user_id` if present.

**Implementation goal:** introduce **explicit** `time_summary` payload fields for CUT and migrate UI to prefer them.

---

## 3) Rollout Strategy (Phased)

### Phase 0 — Freeze the contract (Docs-only)
**Outcome:** Everyone aligns on what will be built.
- Confirm the primary spec is frozen.
- Confirm naming of `time_summary` fields.

Exit criteria:
- Team agrees on `presence_seconds` vs `effort_seconds` semantics.

### Phase 1 — Add projection fields to API payload (no UI change yet)
**Outcome:** API can serve projection safely without changing UX.

Backend work:
- Extend `get_work_queue` and `get_token_detail` to include:
  - `time_summary: { presence_seconds, effort_seconds, first_started_at, last_activity_at }`

Rules:
- For non-CUT tokens: omit `time_summary` initially (or fill from legacy later).
- For CUT tokens: compute from `cut_session` only.

Exit criteria:
- API returns `time_summary` for CUT tokens with deterministic values.

### Phase 2 — Introduce projection computation mode
Choose one:

- **Mode A (recommended): On-read compute first**
  - Compute `time_summary` directly inside `get_work_queue/get_token_detail` query path.
  - Pros: minimal schema change, correctness-first.
  - Cons: more query cost.

- **Mode B: Incremental summary table**
  - Create `token_node_time_summary` derived table.
  - Update it on micro session transitions.
  - Pros: fast reads.
  - Cons: needs rebuild tooling and careful correctness.

Exit criteria:
- Chosen mode is implemented behind a feature flag.

### Phase 3 — UI consumes projection (CUT-only)
**Outcome:** Work Queue and Modal show stable time without relying on legacy timer/session.

Frontend work:
- For CUT tokens, display:
  - presence (primary)
  - effort (secondary)

Rules:
- CUT behavior UI remains SSOT for the running session state.
- Work Queue/Modal must not start legacy timers for CUT.

Exit criteria:
- CUT pause/resume does not cause legacy timer duplication.

### Phase 4 — Monitoring/Manager migration
**Outcome:** Manager monitoring reads consistent time fields.

Backend:
- Extend `manager_all_tokens` to include `time_summary` (CUT) and optionally legacy.

Frontend:
- Show “presence/effort” in manager view or drilldown.

Exit criteria:
- Monitoring accurately reflects CUT sessions and active operator.

### Phase 5 — Optional: unify for non-CUT behaviors
**Outcome:** The projection model becomes the standard interface.

Rules:
- For non-CUT, projection can be derived from `token_work_session`.
- Keep legacy as SSOT for non-CUT until a deliberate migration.

---

## 4) Feature Flags
Recommended flags:
- `time_summary_enabled` (global)
- `time_summary_cut_enabled` (CUT only)
- `time_summary_compute_mode = 'on_read' | 'summary_table'`

---

## 5) Data Contracts (API)

### 5.1 `time_summary` object
Canonical payload:
- `presence_seconds` (int)
- `effort_seconds` (int)
- `first_started_at` (datetime|null)
- `last_activity_at` (datetime|null)

Optional:
- `components_touched_count` (int)
- `micro_sessions_count` (int)
- `is_running` (bool)
- `active_operator_id` (int|null)

### 5.2 CUT mapping
- `effort_seconds` comes from sum of CUT micro durations.
- `presence_seconds` comes from window first-start to last-activity per policy.

---

## 6) Backend Implementation Notes

### 6.1 Query strategy (Mode A: on-read)
For each CUT token+node:
- Identify relevant `cut_session` rows (`token_id`, `node_id`).
- Compute:
  - first_started_at
  - last_activity_at (from event timestamps: started/paused/resumed/ended/aborted; do not use updated_at)
  - effort_seconds
  - presence_seconds

**Determinism rule:**
- All derived results must be uniquely reproducible from ledger rows.

### 6.2 Summary table strategy (Mode B)
If a summary table is introduced:
- Create rebuild job/command (idempotent) to re-derive from ledger.
- Update summary on:
  - `cut_session_start`
  - `cut_session_pause`
  - `cut_session_resume`
  - `cut_session_end`
  - `cut_session_abort`

---

## 7) UI Implementation Notes

### 7.1 Work Queue token cards
- For CUT tokens:
  - Hide legacy start/pause/resume card actions (already supported via feature flag).
  - Prefer display of projection fields.

### 7.2 Work Modal
- CUT behavior panel remains the authoritative controller.
- The modal should not show legacy timer UI for CUT.

---

## 8) Forbidden Changes (Protect the bloodstream)
- Do not reintroduce `TokenWorkSessionService` timing as SSOT for CUT.
- Do not accept client-provided timing for CUT.
- Do not make projection the gating condition for starting/stopping work.
- Do not silently “auto-benchmark” Production Intent Time from averages.

---

## 9) Verification Checklist

### Correctness
- `effort_seconds == sum(duration_seconds)` across ENDED sessions (plus running partial if defined).
- Projection rebuild produces same results.

### UX
- No double timers on CUT pause/resume.
- Manager monitoring shows correct active operator.

### Observability
- Correlation IDs in key endpoints.
- Log warnings on mixed-mode states (legacy + CUT concurrently).

---

## 10) Next Steps (Minimal-first)
Recommended minimal implementation path:
- Implement Phase 1 + Mode A on-read compute for CUT only.
- Add UI consumption only after API has stabilized.

---

## 11) Open Decisions
- Presence policy (paused included? idle-gap threshold?)
- Batch_key scope
- Partial release linkage record
- Multi-operator concurrency policy
