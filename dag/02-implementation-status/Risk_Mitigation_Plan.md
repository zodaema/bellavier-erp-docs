Hatthasilpa ERP — Risk Mitigation Plan (v1.0)

Bellavier Group — Internal Engineering Document
Scope: dag_token_api, hatthasilpa_jobs_api, Graph Instance, Token Lifecycle, Work Queue, Serial Registry

⸻

1. Overview

The Hatthasilpa production system has achieved functional parity across token spawning, routing, work-queue visibility, assignment, and cancellation.
However, due to the high complexity of dag_token_api and job-graph behaviors, several systemic risks remain that could cause inconsistent state across:
	•	job_graph_instance
	•	flow_token
	•	token_assignment
	•	token_work_session
	•	serial_registry (tenant + core)
	•	UI work queue hydration

This document outlines all known risks, proposes a target state, and defines actionable steps for mitigation with clear priorities.

⸻

2. Identified Risks

2.1 Token Idempotency Risks

Symptoms:
	•	Tokens re-spawn after cancellation.
	•	Old tokens reappear when job is restarted.
	•	Token sets from previous attempts accumulate.

Root causes:
	•	Mixed logic: spawn guards vs. instance reuse.
	•	Non-deterministic handling of “scrapped” tokens.
	•	Token existence checks are not fully atomic.

Impact:
Orphan tokens, duplicate work, operator confusion, incorrect timelines.

⸻

2.2 Graph Instance Reuse Risk

Current behavior:
	•	Cancel job → spawn scrapped tokens → restart job → instance reused.

Issues:
	•	Node instances from previous attempts remain.
	•	Token lineage/history polluted.
	•	Assignments and sessions could accumulate inside the same instance.
	•	Analytics and traceability lose accuracy.

Impact:
Non-clean production cycles and misleading audit data.

⸻

2.3 Serial Registry Dual-Write Integrity

Current behavior:
	•	Tenant DB updated first.
	•	Core DB updated asynchronously via outbox.
	•	TEMP serial mode used when FF_SERIAL_STD_HAT is disabled.

Risks:
	•	Temporary serial collisions.
	•	Serial chain not fully atomic.
	•	Lineage mismatch between tenant and core DB.

Impact:
Incorrect serial tracking of finished goods.

⸻

2.4 Session & Assignment Race Conditions

Risks:
	•	Two operators may start the same token simultaneously.
	•	UI debounce missing.
	•	Assignment creation and session start are not locked together.

Impact:
Double sessions, incorrect operator time, corrupted token states.

⸻

2.5 Work Queue Multi-Table Dependency

Work queue hydration involves 10+ tables.
Any out-of-sync write produces misleading operator task views.

Impact:
Wrong task displayed → wasted labor time or incorrect routing.

⸻

2.6 Cancel Job Not Fully Clean

Issues:
	•	Scrapping tokens does not fully isolate previous token history.
	•	Graph instance remains active.
	•	Restarting job reuses old instance.

Impact:
Tokens appear valid but their lineage is wrong.

⸻

2.7 Missing E2E Tests for Real Factory Flows

Current tests cover:
	•	Assignment
	•	Token spawn
	•	Work queue
	•	Graph integrity
But missing:

create job
→ spawn
→ scrap
→ cancel
→ restore to planned
→ restart
→ spawn new tokens
→ work queue hydration
→ operator start/pause/complete

Impact:
Failures can reappear silently.

⸻

3. Target Architecture (Safer State)

3.1 Cancel Job = Hard Reset
	•	Scrap every token
	•	Close every session
	•	Mark instance as archived (not reused)
	•	Delete/expire all assignments
	•	Next start_job → generate NEW instance
(never reuse an old one unless explicitly intended)

⸻

3.2 Token Spawn Idempotency

Define strict spawn rules:

if (existing_tokens_ready > 0)
    skip spawn
else if (existing_tokens_scrapped > 0)
    spawn new set (with new instance)
else
    spawn new set


⸻

3.3 Serial Registry Integrity
	•	Enable FF_SERIAL_STD_HAT by default for all Hatthasilpa tenants.
	•	TEMP serial mode allowed only for test tenants.
	•	Tenant + core DB must write atomically within the same logical transaction.

⸻

3.4 Work Queue Sanitization
	•	Only return tokens that satisfy:
	•	status = ‘ready’
	•	instance.status = ‘active’
	•	not scrapped
	•	not completed

⸻

3.5 Locking & Concurrency Policies
	•	Session start must lock token row (FOR UPDATE).
	•	Assignment + session start must be atomic inside a transaction.
	•	UI must debounce all start actions.

⸻

4. Action Plan (Prioritized)

Phase 1 — Critical Fixes (Next 48 hours)

(A) Cancel Job = New Instance Always
	•	Modify cancel logic to archive old instance.
	•	Next start_job must call spawnTokens() with NEW instance ID.
	•	Do not reuse old instance under any condition.

(B) Token Spawn Idempotent Guard
	•	Add strict guard in TokenLifecycleService:
	•	Existing ready tokens → skip
	•	Only scrapped tokens → regenerate new instance
	•	Mixed states → hard fail + instruct cancel-as-hard-reset

(C) Fix Work Queue to Hide Scrapped Tokens
	•	Scrapped tokens must never appear again.

⸻

Phase 2 — Stability Improvements (Next 7 days)

(D) Enable FF_SERIAL_STD_HAT for all Hatthasilpa tenants
	•	Replace TEMP serial mode with deterministic SKU-based standard serial.

(E) Session & Assignment Locking
	•	Add DB-level FOR UPDATE when starting sessions.
	•	Add composite key to prevent duplicate sessions.

(F) DAG Token API Refactor (Small Step)
	•	Move spawn logic to TokenLifecycleService so dag_token_api only orchestrates.

⸻

Phase 3 — Reliability & Guardrails (Next 14–30 days)

(G) Complete E2E Test Suite

Add dedicated test cases covering:

1. Cancel + Restart Flow

spawn → scrap → cancel → restart → new instance → new tokens

2. Concurrency Start Session Race
3. Double assignment race
4. Mixed ready & scrapped states
5. Serial consistency across tenant/core
(H) Add Developer Guardrails

Add headers in all critical files:

/**
 * WARNING:
 * This file is part of the Hatthasilpa Token Lifecycle Core.
 * DO NOT modify without understanding:
 *   - token idempotency
 *   - graph instance state machine
 *   - serial registry integrity
 *   - cross-DB transaction behaviors
 *
 * All changes require:
 *   1. Updating E2E test suite
 *   2. Reviewing with architecture owner
 *   3. Running full regression
 */


⸻

5. Monitoring Plan

Build dashboards to detect:
	•	orphan tokens
	•	inconsistent token counts per instance
	•	instances with more than one spawn cycle
	•	serial mismatch between tenant & core
	•	sessions without assignments
	•	assignments without tokens

⸻

6. Summary

This document establishes:
	•	A complete list of systemic risks
	•	A pragmatic mitigation plan
	•	A stable architecture direction for Hatthasilpa
	•	Guardrails to prevent regression
	•	A roadmap toward production-grade reliability

⸻

7. Applied Fixes (Owner‑led Hotfix, Nov 2025)

The following mitigations were applied directly in production by the owner (outside the automation pipeline) and are now the baseline for all future work:

1) Hard‑reset scrapping does not reuse old `job_graph_instance`.  
2) Restarting a job spawns a clean token set on the existing active instance (no resurrection of scrapped tokens; no duplicate token sets).  
3) Work‑queue hydration shows only valid/ready tokens; scrapped tokens are never resurrected.  
4) `dag_token_api` emits a single, sanitized JSON payload (no multi‑chunk responses).  
5) Token spawn idempotency guards prevent duplicate sets on repeated/restart flows.  
6) For Hatthasilpa piece mode, `FF_SERIAL_STD_HAT` must be enabled for deterministic serial generation; TEMP mode is for test tenants only.  
7) Initial concurrency guards applied to reduce assignment/session race windows; DB‑level locking to be codified in Phase 2(E).

> Do not re‑introduce prior behaviors (old instance reuse, duplicate spawns, scrapped token resurrection, multi‑JSON responses) unless explicitly approved and reflected in this plan.

### Baseline / Guardrails (Must Not Regress)
- Never reuse an archived/scrapped instance for new production cycles unless explicitly specified and documented.
- Enforce idempotent spawn logic:  
  - If `ready` tokens exist → skip spawning (idempotent no‑op).  
  - If only `scrapped` tokens exist → spawn a fresh set (new instance).  
  - If mixed states detected → hard fail with operator guidance to perform hard reset.
- Sanitize all API responses to a single JSON object per response path (no concatenated JSON chunks).
- Work‑queue queries must exclude scrapped/completed tokens and non‑active instances.

### Documentation & Roadmap Alignment
- See “Operational Update — Hatthasilpa Token Lifecycle Stabilization (Nov 2025)” in `DAG_IMPLEMENTATION_ROADMAP.md`.
- Phase 1/2 action items in §4 remain relevant; they now focus on **codifying** these hotfixes and expanding automated tests/monitoring.

### Test & Monitoring Follow‑ups
- Extend E2E coverage:  
  - Cancel → Restart → New instance → Spawn → Work‑queue ready‑only  
  - Concurrency (double start / session races)  
  - Serial registry consistency across tenant/core with `FF_SERIAL_STD_HAT` enforced  
- Assert `dag_token_api` single‑payload invariant in integration tests.  
- Add monitors for: duplicate spawns, mixed ready+scrapped states, reappearance of scrapped tokens, multi‑spawn per instance.

⸻

8. Additional Risks Identified (Post-Incident Review)

7.1 API Response Fragmentation
- Multiple JSON payloads were returned from dag_token_api.php in a single HTTP response.
- Caused orchestrator to misinterpret spawning results.
- Mitigation: enforce strict single-JSON output; sanitize buffers; wrap all dag_token_api responses in a standardized envelope.

7.2 Cross-Module State Drift
- job_graph_instance, flow_token and work_queue hydration were not guaranteed to stay consistent under partial failures.
- Mitigation: introduce a unified TransactionBoundary layer for spawn/scrap/cancel flows.

7.3 Incomplete State Machine Documentation
- cancel_job and start_job lacked a formally defined state diagram.
- Developers risk reintroducing regressions when modifying lifecycle logic.
- Mitigation: add explicit state machine spec (planned → in_progress → completed/cancelled → archived).

7.4 Hidden Feature Flag Dependencies
- FF_SERIAL_STD_HAT was required for correct token spawning but not documented.
- Mitigation: add explicit prerequisites list for all DAG operations.

7.5 Developer Guardrail Enforcement
- Manual patches revealed that developers can unintentionally break idempotency.
- Mitigation: add a mandatory “Regression Checklist” for PRs touching token lifecycle code.

⸻

9. Regression Checklist (Mandatory for All Future Changes)

Before merging any changes affecting dag_token_api, job lifecycle, or token lifecycle, verify:

[ ] No instance reuse occurs after cancel_job  
[ ] spawnTokens() executes idempotently  
[ ] Scrapped tokens cannot rehydrate into work_queue  
[ ] Serial registry writes are deterministic and FF_SERIAL_STD_HAT enabled  
[ ] Work queue returns only (ready + active-instance) tokens  
[ ] No multi-JSON responses in dag_token_api  
[ ] E2E tests (cancel → restart → spawn → work queue) pass  
[ ] Concurrency-safe session start via DB FOR UPDATE  
[ ] Assignment and session creation are atomic  

⸻

10. Baseline Resolution Mapping (What’s now “Resolved in Baseline”)

Resolved in Baseline (owner‑applied, LIVE):
- Token Idempotency / Duplicate spawns → Guarded (skip if ready; respawn clean after scrapped).
- Instance reuse after cancel → Archived/isolated; no resurrection of scrapped tokens.
- Work Queue pollution → Filters exclude scrapped/completed and non‑active instances.
- Multi‑source JSON responses → Single sanitized payload guaranteed by `dag_token_api`.

Pending Codification (to be implemented + tested):
- Manager Assignment on spawn → propagate `manager_assignment` → `token_assignment` (B.1).
- Serial policy as spec:
  - Hatthasilpa tenants: `FF_SERIAL_STD_HAT` enabled by default; TEMP serial only for test tenants.
  - Tests for FF enabled/disabled flows (B.2).
If you want, I can now:

✔ Generate the patches for Phase 1 (A+B+C)

✔ Rewrite cancel_job + start_job into a safe, deterministic state machine

✔ Implement new instance generation logic

✔ Add the developer guardrails to all core files

✔ Add E2E test suite skeletons

⸻

11. Roadmap Re‑Entry Index (How This Plan Reconnects Back to the Main DAG Roadmap)

This section maps each mitigation area in this Risk Mitigation Plan to its corresponding phase
in the official `DAG_IMPLEMENTATION_ROADMAP.md`, ensuring that all hotfixes and new
stabilization rules re-enter the roadmap in a structured, traceable, and reviewable manner.

11.1 Mapping to Phase 2B (Work Queue, Token Lifecycle, Assignment)

- **Phase 2B.1 — Work Queue UX / Hydration**
  ↳ Connects to:
    - §3.4 Work Queue Sanitization
    - §2.5 Work Queue Multi‑Table Dependency
    - §4(C) Hide scrapped tokens + return only ready tokens
    - §7.2 Cross‑Module State Drift

- **Phase 2B.2 — Assignment Integration**
  ↳ Connects to:
    - §2.4 Session & Assignment Race Conditions
    - §3.5 Locking & Concurrency Policies
    - §4(E) Session & Assignment Locking
    - §10 Pending: Manager Assignment on spawn

- **Phase 2B.3 — Mobile Work Queue**
  ↳ Requires:
    - Stable hydration (2B.1)
    - Deterministic assignment/session behavior (2B.2)
    - §4(D) Serial registry consistency for piece mode

11.2 Mapping to Phase 7.X (Graph Designer + Versioning)

- **Phase 7.X — Graph Instance & Routing Integrity**
  ↳ Connects to:
    - §2.2 Graph Instance Reuse Risk
    - §3.1 Cancel Job = Hard Reset
    - §4(A) Always create new instance after cancel
    - §8.3 Incomplete State Machine Documentation

11.3 Mapping to Serial Governance (Cross‑Tenant)

- **FF_SERIAL_STD_HAT Enablement**
  ↳ Connects to:
    - §2.3 Serial Registry Dual‑Write Integrity
    - §3.3 Serial Registry Integrity
    - §4(D) Enable FF for Hatthasilpa tenants
    - §10 Pending codification: deterministic serial policy

11.4 Mapping to E2E Quality Gates

- **E2E Test Suite Expansion**
  ↳ Connects to:
    - §2.7 Missing E2E Tests for Real Factory Flows
    - §4(G) Complete E2E Test Suite
    - §7.1 API Response Fragmentation
    - §9 Regression Checklist

11.5 Summary of Required Actions Before Re‑Entry

To fully re‑enter the official roadmap, the following must be confirmed:

[ ] Hard reset cancel logic fully codified  
[ ] New-instance spawn guaranteed after cancel  
[ ] Deterministic, idempotent spawn behavior  
[ ] FF_SERIAL_STD_HAT enabled + tested  
[ ] Work queue returns correct token set  
[ ] Updated assignment/session concurrency rules  
[ ] All E2E tests defined in §4(G) implemented  
[ ] dag_token_api single‑JSON invariant enforced  
[ ] Developer guardrails applied across critical files  

Only after these are complete should the system transition from “hotfix stabilization mode” back into the formal DAG Implementation Roadmap.

⸻