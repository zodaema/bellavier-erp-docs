# CUT Integration Audit (Work Queue / Default Behavior vs CUT Behavior)
**Date:** 2026-01-15  
**Scope:** Work Queue (PWA Scan) + Modal + Backend APIs + Session/Timer + Manager Monitoring  
**Goal:** Verify whether the “core system” (legacy Default behavior flow) still functions according to its intended lifecycle, and map how CUT behavior currently attaches to the core, including risks/side-effects.

---

## 1) Executive Summary

### 1.1 Core (Legacy) is still conceptually intact, but now effectively **hybrid**
The system currently runs two parallel execution tracks:

- **Legacy / Default track (token_work_session SSOT)**
  - APIs: `source/dag_token_api.php` actions like `start_token`, `pause_token`, `resume_token`, `complete_token`
  - Data SSOT: `token_work_session` (status `active/paused/...`) + `flow_token.status`
  - Timer engine: `BGTimeEngine` driven from legacy session fields

- **CUT track (cut_session SSOT)**
  - APIs: `source/dag_behavior_exec.php` with `BehaviorExecutionService` actions `cut_session_start/pause/resume/end/get_active`
  - Data SSOT: `cut_session` table (status `RUNNING/PAUSED/ENDED/ABORTED`)
  - Timer engine: CUT UI internal timer (SSOT display), *should not* depend on `token_work_session`

**Key point:** Core flow is not destroyed, but it is no longer “single-timer/single-session” by default. It requires careful bridging/mapping to prevent UI/monitoring from reading the wrong SSOT.

### 1.2 CUT is integrated mainly at **presentation + reporting + guard** layers
CUT is not replacing the token engine; it is “plugged in” by:

- Joining `cut_session` into Work Queue/Modal payloads
- Adding behavior metadata `behavior.code` to decide which UI controller to initialize
- Adding active-session guard to prevent an operator starting parallel work while CUT is `RUNNING`
- Extending Manager monitoring payload to reflect CUT active/paused

### 1.3 Highest-risk areas (where “issues still occur” is likely)
- **Dual modal lock layers:**
  - `WorkModalController` blocks close on “active” state
  - CUT handler (`behavior_execution.js`) also locks modal with bootstrap + keydown/backdrop handlers
  - If token/session data is stale or mapped inconsistently, one layer may not lock.

- **Dual timer layers:**
  - Legacy timer (`#workModalTimer` + `BGTimeEngine`) can run alongside CUT timer unless explicitly disabled for CUT.

- **State mapping mismatches:**
  - Legacy expects `active/paused`.
  - CUT uses `RUNNING/PAUSED`.
  - UI code paths check different fields (`token.status`, `session.status`, `timer.status`).

- **Multiple backend entrypoints:**
  - `source/dag_token_api.php` (Work Queue) vs `source/worker_token_api.php` (Worker API) vs `source/dag_behavior_exec.php` (Behavior spine)
  - If the frontend is calling a different endpoint than the one patched, fixes appear “not working”.

---

## 2) Core (Legacy / Default) — Intended Lifecycle vs Current Implementation

### 2.1 Intended design (legacy concept)
- A token at an operation node is started by an operator.
- A single authoritative work session exists per operator at a time.
- Status transitions:
  - `flow_token.status`: `ready → active → paused → ...`
  - `token_work_session.status`: `active/paused/completed`
- Timer is derived from server timestamps and rendered by `BGTimeEngine`.
- Manager monitoring reads aggregated token + session status and shows who is active/paused.

### 2.2 Current primary code paths (Work Queue)
- **Frontend:**
  - `assets/javascripts/pwa_scan/work_queue.js`
  - `assets/javascripts/pwa_scan/WorkModalController.js`
  - `assets/javascripts/pwa_scan/token_card/*` (card rendering)

- **Backend:**
  - `source/dag_token_api.php`:
    - `get_work_queue`
    - `get_token_detail`
    - `start_token`, `pause_token`, `resume_token`, `complete_token`
    - `manager_all_tokens`

### 2.3 Notes on “core correctness”
Core is still consistent with its original idea *if*:
- every UI action uses the correct API (`dag_token_api.php` for legacy)
- and the “one active session per operator” rule is enforced

However, in the repo there is also `source/worker_token_api.php` which implements `start_token/pause_token/resume_token` too.

**Risk:** If parts of the UI call `worker_token_api.php` while others call `dag_token_api.php`, enforcement and payload shapes differ.

---

## 3) CUT Behavior — How it “attaches” to the core

### 3.1 CUT UI is implemented as a behavior handler
- File: `assets/javascripts/dag/behavior_execution.js`
- Registration: `window.BGBehaviorUI.registerHandler('CUT', { init(...) { ... }})`

**Role:**
- Renders the CUT “mini-app” inside the Work Modal behavior panel.
- Maintains its own session state and triggers CUT endpoints.

### 3.2 CUT backend execution spine
- Endpoint: `source/dag_behavior_exec.php`
  - Accepts JSON payload `{behavior_code, source_page, action, ...}`
  - Dispatches to `BGERP\Dag\BehaviorExecutionService`

- Service: `source/BGERP/Dag/BehaviorExecutionService.php`
  - CUT actions:
    - `cut_session_start`
    - `cut_session_pause`
    - `cut_session_resume`
    - `cut_session_end`
    - `cut_session_abort`
    - `cut_session_get_active`

- SSOT policy docs:
  - `docs/super_dag/tasks/archive/task31/task31_CUT_TIMING_SSOT_POLICY.md`
  - `docs/super_dag/tasks/archive/task31/task31_CUT_SESSION_TIMING_SPEC.md`

### 3.3 CUT timing SSOT
- Table: `cut_session`
- Service: `source/BGERP/Dag/CutSessionService.php`

**Contract:**
- CUT timing must come from server time.
- Legacy `token_work_session` must not be authoritative for CUT.

### 3.4 Bridging CUT into the legacy Work Queue payload
To keep Work Queue/Modal functional without rewriting the entire UI, CUT is bridged in `source/dag_token_api.php`:

- `get_work_queue` and `get_token_detail` join `cut_session` and synthesize a legacy-shaped `token.session`:
  - If `cut_session.status == RUNNING` → `session.status = 'active'`
  - Else → `session.status = 'paused'`

- `timer` for CUT is synthesized in `get_token_detail`:
  - `timer.status` uses `running/paused` strings.

**Risk:** Bridging is “lossy” (e.g., RUNNING/PAUSED are collapsed into active/paused for some consumers). Some UI checks are case-sensitive and may not treat these as equivalent.

---

## 4) “Main bloodstream” impact analysis

### 4.1 Does CUT destroy core token lifecycle?
**No, not directly.**
CUT is designed to avoid using `TokenWorkSessionService` for timing and uses its own `cut_session`.

However, the system still uses `flow_token.status` and DAG routing for token progression; CUT is an embedded behavior, not a separate routing engine.

### 4.2 Where CUT can disturb core behavior
- **Operator concurrency:**
  - If CUT allows RUNNING while legacy start_token is allowed, you can get dual active sessions.
  - This is why active-session guard must check both `token_work_session` and `cut_session`.

- **Modal UX / locking:**
  - Two independent implementations exist (WorkModalController vs CUT handler).
  - If one layer thinks the session is not active (stale data), modal may close.

- **Timer UX:**
  - If legacy timer still binds to DOM for CUT tokens, the user sees timer re-starting or double ticking.

- **Monitoring and reporting:**
  - Manager monitoring historically reads `token_work_session`.
  - CUT requires mapping `cut_session` to `session_status/operator_user_id`.

### 4.3 Is core logic “broken” by CUT changes?
**Core logic is more “fragile” now, but not inherently broken.**
The fragility comes from:
- multiple possible sources of truth at the UI layer
- multiple endpoints capable of performing similar actions
- bridging/mapping that must be kept consistent everywhere

---

## 5) Current Integration Touchpoints (Evidence Table)

### 5.1 Frontend
- `assets/javascripts/pwa_scan/work_queue.js`
  - Defines `window.openWorkModal` (prefers `WorkModalController`)
  - Binds `.btn-start-token/.btn-pause-token/.btn-resume-token` legacy actions
  - Mobile cards `renderMobileJobCard()` produce legacy action buttons

- `assets/javascripts/pwa_scan/WorkModalController.js`
  - Fetches token fresh via `get_token_detail`
  - Controls legacy lifecycle via `start_token/pause_token/resume_token/complete_token`
  - Modal close lock based on “active state” heuristics
  - Timer sync via `BGTimeEngine.syncFromServer`

- `assets/javascripts/dag/behavior_execution.js`
  - CUT handler manages CUT session lifecycle via `BGBehaviorExec.send()`
  - Implements modal lock/unlock and storage-based degraded mode

### 5.2 Backend
- `source/dag_token_api.php`
  - Legacy work queue + session engine
  - CUT bridging joins and mapping in `get_work_queue/get_token_detail`
  - Active-session guard in `startTokenInternal()` checks:
    - `token_work_session.status='active'`
    - `cut_session.status='RUNNING'`
  - Manager monitoring `manager_all_tokens` includes cut_session join

- `source/dag_behavior_exec.php`
  - Behavior spine endpoint (JSON) for CUT and other behaviors

- `source/worker_token_api.php`
  - A parallel API implementing start/pause/resume semantics too
  - **Risk surface** if UI hits this instead of `dag_token_api.php`

---

## 6) Root-cause hypotheses for “issues still present”
This audit suggests the most likely reasons issues “remain” even after patches:

1. **The running UI path is not the one patched**
   - e.g., calling `worker_token_api.php` or another page with its own modal logic.

2. **State mapping mismatch (active vs RUNNING vs running)**
   - UI checks inconsistent fields and/or is case sensitive.

3. **Modal lifecycle is served by multiple controllers**
   - Legacy `openWorkModal/populateWorkModal` still exists.
   - CUT handler uses its own lock while WorkModalController also tries.

4. **Timer is still bound twice**
   - `BGTimeEngine` continues to tick for CUT tokens.

5. **Monitoring reads the wrong field set**
   - Some manager views may still read `s.operator_user_id` rather than the unified `operator_user_id` mapping.

---

## 7) Recommendations (Non-invasive)

### 7.1 Enforce a single “open modal” entrypoint
- All opens must go through `WorkModalController.openForToken()` to guarantee fresh token+session snapshot.

### 7.2 Explicit SSOT switching in UI
- For behavior code `CUT/CUTTING`:
  - disable legacy start/pause/resume buttons everywhere
  - disable legacy timer binding/sync
  - treat CUT session state as authoritative

### 7.3 Single operator active-session policy
- Backend guard must be enforced at the *actual* endpoint the UI calls.
- Verify no other endpoint bypasses the rule.

### 7.4 Monitoring contract
- Define a canonical `session_status` + `operator_user_id` contract used by all dashboards.
- Ensure CUT maps into that contract consistently.

---

## 8) Conclusion
The core legacy system remains conceptually valid, but the system is currently in a hybrid state where:
- Legacy and CUT each have their own SSOT for timing.
- Bridging exists to keep the old UI working.

This hybrid state is workable, but it is sensitive to:
- stale data
- inconsistent status mapping
- multiple endpoints
- dual modal/timer controllers

If “all problems still occur”, the highest probability is that the runtime path is different from the patched path, or a parallel endpoint/controller is still in use.

---

## 9) Updates implemented after initial audit (UI Lock + Timer Concurrency)

### 9.1 Objective
- Eliminate “multi-active timer” behavior (opening/starting other tokens while one is active).
- Ensure Work Modal cannot be closed while an operator session is active (including after `resume_token`).

### 9.2 Changes made (Frontend)

- **WorkModalController API request fixes**
  - File: `assets/javascripts/pwa_scan/WorkModalController.js`
  - Fixed POST payload keys to match backend contract:
    - `start_token`: now sends `token_id` + `operator_name` (and `help_type=own`)
    - `pause_token/resume_token`: now sends `token_id`
    - `complete_token`: now sends `token_id` + `operator_name`
  - Added/confirmed `__ACTIVE_TOKEN_LOCK__` is set after modal open/start/pause/resume/close.

- **Global active-session lock (SSOT-derived + immediate)**
  - File: `assets/javascripts/pwa_scan/work_queue.js`
  - Introduced `window.__ACTIVE_TOKEN_LOCK__`:
    - Derived from Work Queue payload (`token.session.is_mine === true` + `token.session.status === 'active'`).
    - Enforced in `window.openWorkModal`, card click handler, and `.btn-start-token`.
    - Updated immediately on legacy modal `start_token`/`resume_token` success; cleared on `pause_token`/`complete_token` success.

- **CUT-running lock**
  - File: `assets/javascripts/pwa_scan/work_queue.js`
  - Maintains `window.__CUT_ACTIVE_LOCK__` derived from Work Queue payload for CUT nodes.
  - Blocks opening/starting non-active tokens when a CUT session is RUNNING.

- **Hard modal close prevention while active**
  - File: `assets/javascripts/pwa_scan/work_queue.js`
  - Added `#workModal` `hide.bs.modal` guard that prevents closing when `__ACTIVE_TOKEN_LOCK__.is_active === true`.
  - Updated legacy CUT modal close policy: for CUT standalone mode, close action is shown only when NOT active.

### 9.3 Changes made (Backend)

- **Active-session guard already enforced**
  - File: `source/dag_token_api.php`
  - `startTokenInternal()` rejects starting another token when operator has:
    - legacy `token_work_session.status='active'`
    - or CUT `cut_session.status='RUNNING'`
  - Response uses HTTP 409 with structured `app_code`.

---

## 10) Addendum (2026-01-16) — Manager Assignment Monitor + Modal Close on CUT Pause

### 10.1 Problem statement observed
- In Work Modal: CUT status appears to change (RUNNING → PAUSED) in the modal header.
- In Manager Assignment monitor (`manager_assignment`): the status badge still shows `paused` (or does not reflect the latest CUT state).
- After pressing Pause (CUT), the modal still cannot be closed.

### 10.2 Audit finding: Manager Assignment monitor data source
- File: `assets/javascripts/manager/assignment.js`
- The monitor loads tokens via:
  - `POST source/dag_token_api.php` with `action=manager_all_tokens`
- The status badge in the table is computed from `row.session_status`.

Implication:
- If the `manager_all_tokens` payload does not map CUT session state into `session_status`, the manager page will not reflect CUT correctly.
- This monitor does not read Work Modal UI state; it only reads backend payload.

### 10.3 Root cause: `manager_all_tokens` was still effectively legacy for session status
Before patching, `manager_all_tokens` primarily joined `token_work_session` for session status.

For CUT nodes, this is not SSOT. CUT SSOT lives in `cut_session`.

### 10.4 Patch applied: Make `manager_all_tokens` reflect CUT SSOT
- File: `source/dag_token_api.php`
- In `handleManagerAllTokens()`:
  - Join latest active `cut_session` per `(token_id, node_id)` using a derived table with `MAX(id_session)` for statuses `RUNNING/PAUSED`.
  - Map CUT status into the canonical UI contract:
    - `RUNNING` → `session_status = 'active'`
    - `PAUSED` → `session_status = 'paused'`
  - Compute `work_seconds_display` from `cut_session` when node is `CUT/CUTTING`.

Expected effect:
- Manager Assignment monitor should show correct `active/paused` for CUT tokens without relying on `token_work_session`.

### 10.5 Audit finding: Why modal could not be closed after CUT Pause
There are two lock layers:
- Work Queue modal controller lock:
  - File: `assets/javascripts/pwa_scan/WorkModalController.js`
  - Blocks `hide.bs.modal` (and `close()`) when it believes the session is active.
- CUT behavior handler lock:
  - File: `assets/javascripts/dag/behavior_execution.js`
  - Locks the modal while CUT is RUNNING and calls `unlockModal()` on pause.

Failure mode:
- After CUT pause, the CUT handler correctly clears `window.__CUT_ACTIVE_LOCK__.is_running`.
- But WorkModalController may still see stale `currentSession` / `timer` state and continues to block close.

### 10.6 Patch applied: Close policy for CUT uses `__CUT_ACTIVE_LOCK__`
- File: `assets/javascripts/pwa_scan/WorkModalController.js`
- For CUT/CUTTING only:
  - Determine “active/close-block” state via:
    - `window.__CUT_ACTIVE_LOCK__.is_running` AND `token_id` match
  - Do not infer active state from legacy session/timer fields for CUT.

Expected effect:
- While CUT is RUNNING: modal close remains blocked.
- After CUT pause: modal becomes closable.

### 10.7 Next actions (decision points)
- Confirm that all manager monitoring views standardize on the same contract:
  - `session_status` and (if needed) `active_operator_id` / `cut_operator_id`.
- If needed, introduce an explicit `time_summary` projection object for CUT (presence/effort) per the playbook so manager views do not depend on legacy `work_seconds_display` semantics.
- Implement backend guard hardening:
  - Ensure the “only one active work per operator” rule is enforced in every start entrypoint used by UI.
