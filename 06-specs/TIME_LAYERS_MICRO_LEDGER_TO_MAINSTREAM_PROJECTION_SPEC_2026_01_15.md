# Time Layers Spec: Micro Ledger (SSOT) → Mainstream Projection
**Date:** 2026-01-15  
**Status:** Draft (for alignment)  
**Applies to:** CUT behavior (and future multi-batch behaviors), Work Queue monitoring, Manager/People monitoring, reporting/BI

---

## 1) Problem Statement
Legacy time tracking in Work Queue assumed:
- One token flows in a mostly single linear path.
- One “work session timeline” per token+node can represent reality.

CUT reality is different:
- Operator performs **multiple micro sessions** (start/pause/resume/end) over time.
- Operator can **batch work flexibly** (user-defined grouping), switch components, and perform **partial release**.
- Multiple micro events are not a simple “sub-task” of a single job timeline.

**Goal:** Define a time model where:
- “Micro time” is the authoritative record of actual effort.
- “Mainstream time” remains available for Work Queue/Manager/WIP but is derived, consistent, and not a second competing SSOT.

---

## 2) Definitions

### 2.1 Mainstream Time (Token–Node Work Time)
**Meaning:** Time used by the routing/work queue world to answer “token is being worked at node”.

**Responsibilities:**
- WIP / throughput / SLA / bottleneck at node-level
- “Who is working on what token now” monitoring
- Token-centric, node-centric

**Hard constraint:** Must remain readable & stable even when micro work is complex.

### 2.2 Micro Time (Operational Micro Sessions)
**Meaning:** Actual effort ledger: each record represents an operator’s concrete work slice (e.g., cutting component A in batch X). Many records per token+node are expected.

**Responsibilities:**
- Trace actual effort (labor) and context (component/batch/qty/release)
- Support partial release and multi-component work
- Operation-centric (not token-linear)

**Non-goal:** Micro time is not required to be 1:1 mapped to legacy token session UX.

### 2.3 Production Intent Time (Normative Reference Layer)
**Meaning:** Reference time representing what the system *intends/expects* a token to take at a node (benchmark), used for learning, training, and abnormality detection.

**Responsibilities:**
- Benchmark / target comparisons (normative)
- Skill curve (training vs master)
- Early warning signals for process drift (not punishment)

**Important:** This layer is **not SSOT**, and it is **not derived** from micro sessions. It is a separate reference layer. Do not overload micro or mainstream time to serve this purpose.

---

## 3) SSOT Architecture

### 3.1 Authoritative Layer (SSOT)
- **Micro time ledger** is SSOT.
  - For CUT today: `cut_session` (and optionally future `cut_subsession` / `cut_event`).
  - Timing fields must be server-time based.

### 3.2 Derived / Projection Layer (Not SSOT)
- **Mainstream time** is a projection derived from micro ledger.
- Used by Work Queue / Manager monitoring.
- If projection is missing/stale, it can be rebuilt from ledger.

> Micro = ledger (บัญชีแยกประเภท)  
> Mainstream = dashboard (สรุปเพื่อ monitoring)

### 3.3 Event Semantics (Ledger Philosophy)
Even if stored in a “session table” today, the micro ledger should be treated conceptually as an **event stream with duration**.

- Micro ledger semantics:
  - Events like `CUT_START`, `CUT_PAUSE`, `CUT_RESUME`, `CUT_END`, `CUT_ABORT`, and optional `CUT_RELEASE_PARTIAL`.
  - The ledger is the authoritative history and must remain audit-friendly.
- Session storage semantics:
  - `cut_session` can be viewed as an aggregation/convenience representation of the underlying event stream.
  - Session storage is allowed as an optimization, but the system philosophy remains event-first.

---

## 4) Canonical Outputs Required by Mainstream
Mainstream must expose at least **two** time metrics per (token_id, node_id):

### 4.1 `presence_seconds` (Node Presence Time)
**Question answered:** “Token ค้าง/อยู่ใน node นี้นานเท่าไรในมุม WIP?”

**Definition:**
- Time span of *token’s active presence window* at node.
- Derived from micro session activity boundaries.

**Default derivation (baseline):**
- `first_started_at` = earliest micro session start for that token+node.
- `last_ended_at` = latest micro session end (or now if running).
- `presence_seconds` = `last_ended_at - first_started_at` minus excluded periods by policy.

**Policy hooks (configurable):**
- Exclude “idle gaps” longer than `presence_idle_gap_threshold_seconds` (optional).
- Include/exclude paused windows depending on business interpretation.

### 4.2 `effort_seconds` (Labor Effort Time)
**Question answered:** “ลงแรงจริงไปกี่วินาที/นาที?”

**Definition:**
- Sum of actual working durations only.

**Default derivation:**
- `effort_seconds = SUM(duration_seconds)` of micro sessions (RUNNING time only).

**Key invariant:** `effort_seconds` does not need to equal `presence_seconds` (and usually won’t).

---

## 5) Context Binding: How Micro Sessions Attach to Mainstream
Aggregation requires a stable context key. Micro records MUST minimally include:
- `token_id`
- `node_id`
- `operator_id`

To preserve meaning in flexible-batch reality, micro records SHOULD include:
- `batch_key` (user-defined grouping key)
- `component_code` (or `component_id`)
- `role_code` (material role)
- `material_sku`
- `qty` / `units` (optional but recommended)
- `release_event_id` (optional, when partial release exists)

### 5.1 Batch Key Contract
`batch_key` is a **grouping label** chosen by the user/UI to represent “this working batch”.

Requirements:
- Not required to be unique globally.
- Must be stable for the duration of the batch.
- Should be stored on the micro record.

Examples:
- `BATCH-2026-01-15-01`
- `order123:body-main:sheet-7`
- `user:john:morning-run`

---

## 6) Data Model (Proposed)

### 6.1 Existing SSOT (CUT)
Use current `cut_session` as micro SSOT.

Minimum fields used by this spec:
- identity/context: `token_id, node_id, operator_id, component_code, role_code, material_sku, batch_key (NEW), qty_cut`
- timing: `started_at, ended_at, paused_total_seconds, duration_seconds`
- status: `RUNNING, PAUSED, ENDED, ABORTED`

### 6.2 New Projection Table: `token_node_time_summary` (Derived)
A canonical summary record per `(token_id, node_id)`.

Suggested schema (conceptual):
- Keys:
  - `token_id` (PK part)
  - `node_id` (PK part)
- Presence projection:
  - `first_started_at`
  - `last_activity_at`
  - `presence_seconds`
- Effort projection:
  - `effort_seconds`
  - `micro_sessions_count`
- Semantics/analytics:
  - `operators_count`
  - `components_touched_count`
  - `released_units_total` (optional)
- Observability:
  - `projection_version`
  - `computed_at`
  - `source = 'cut_session' | 'legacy_work_session' | 'mixed'`

**Important:** This summary is rebuildable from ledger; no business-critical decision should depend on it as SSOT.

---

## 7) Derivation Rules (Algorithm)

### 7.1 Derive per (token_id, node_id)
Input set:
- All micro sessions where `token_id = X AND node_id = Y`.

Compute:
- `first_started_at = MIN(started_at)`
- `last_activity_at = MAX(COALESCE(ended_at, resumed_at, paused_at, started_at))`

Presence window:
- Let `window_end = MAX(ended_at)` if any ended sessions exist.
- If there is a RUNNING session, `window_end = NOW()`.
- Baseline `presence_seconds = window_end - first_started_at`.

Effort:
- `effort_seconds = SUM(duration_seconds)` for ENDED sessions + running partial duration for RUNNING session if needed.

Counts:
- `micro_sessions_count = COUNT(*)`
- `operators_count = COUNT(DISTINCT operator_id)`
- `components_touched_count = COUNT(DISTINCT component_code)`

Policy adjustment (optional):
- If `gap > threshold`, subtract gap from presence.

### 7.2 When to compute
Two acceptable modes:

- **Mode A: Event-driven incremental projection (recommended for UX):**
  - On each micro session state transition (start/pause/resume/end/abort), update summary.

- **Mode B: On-read compute (recommended for correctness-first / low complexity):**
  - Work Queue query computes projection on the fly.

Hybrid is allowed:
- precompute for active tokens + nightly rebuild for all.

---

## 8) API Contract Implications

### 8.1 Behavior APIs (SSOT)
CUT behavior continues to use:
- `cut_session_start/pause/resume/end/get_active`

Contract additions:
- `batch_key` SHOULD be accepted and stored.
- `qty` SHOULD be accepted (if meaningful).
- Server must remain authoritative for timing.

### 8.2 Work Queue / Monitoring APIs (Projection)
Work Queue/Manager endpoints SHOULD return:
- `time_summary` (derived):
  - `presence_seconds`
  - `effort_seconds`
  - `first_started_at`
  - `last_activity_at`

Optional:
- `effort_seconds_by_component` (for drilldown)
- `active_operator_id` (if there is RUNNING session)

---

## 9) Backward Compatibility
Legacy `token_work_session` remains valid for non-CUT behaviors.

Rules:
- If behavior is non-CUT:
  - `token_work_session` remains SSOT for effort and presence (legacy worldview).
- If behavior is CUT:
  - `cut_session` is SSOT.
  - Any legacy session UI elements are projections only.

When both exist (should be rare / transitional):
- Summary `source = 'mixed'` and the system should surface warnings in logs.

---

## 10) UI Semantics
Work Queue / Manager should show both metrics:
- **Presence (ค้างที่ node):** used for WIP perception
- **Effort (ลงแรงจริง):** used for labor/efficiency

Suggested display:
- Primary: presence
- Secondary: effort

---

## 11) Invariants and Guardrails
- Micro ledger records are append/update-controlled by server actions only.
- Projection must be rebuildable.
- Projection must not be used to authorize/deny actions.
- Status vocabulary must be standardized:
  - Micro: `RUNNING/PAUSED/ENDED/ABORTED`
  - Mainstream: `active/paused` (presentation only)

### 11.1 Governance & Ethics of Time (Non-negotiable)
- Micro ledger must be immutable-by-default; if corrections are required, they must be recorded with an audit trail (who/when/why).
- Projection rebuild must be deterministic from the ledger.
- Time metrics must be used for learning, optimization, and traceability; they must not be used as punitive judgment of operators.
- Projection is a dashboard layer; it must not be treated as “truth” when ledger data is available.

---

## 12) Open Questions (Need decision)

### 12.1 Explicit Non-goals
- Do not attempt to normalize human behavior into a single linear work model.
- Do not optimize speed at the expense of craftsmanship.
- Do not enforce linear flow where the real work is non-linear (batching, partial release, multi-component).
- Do not use projection metrics as a basis for authorization, blame, or punishment.

### 12.2 Open Questions (Need decision)
- **Presence policy:** Do we count paused time as presence? Do we subtract long idle gaps?
- **Batch key semantics:** Is batch_key operator-scoped? token-scoped? global?
- **Partial release linkage:** Do we create a `release_event_id` first-class record?
- **Multi-operator collaboration:** How to represent concurrent micro sessions on same token+node (allowed or forbidden)?

---

## 13) Acceptance Criteria
- For a CUT token with multiple micro sessions:
  - `effort_seconds = sum of micro durations` (matches SSOT)
  - `presence_seconds` reflects the token’s time window on node (per chosen policy)
- Work Queue/Manager can show stable monitoring without relying on legacy session as SSOT.
- Rebuild from ledger produces same projection deterministically.
