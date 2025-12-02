

# Task 24.7 — Hatthasilpa Jobs: Planned → Token Generation Fix, Job Lifecycle Refinement, and Cross‑Sync With Job Ticket

## Objective
Stabilize and finalize the Hatthasilpa Jobs lifecycle to match the true workflow:
1. **Create = Planned** (never auto‑InProgress)
2. **Start = Generate Tokens + Move to InProgress**
3. **Cancel/Restore = Correct state transitions**
4. **Sync to Job Ticket = Offcanvas open / view / detail only, no actions**
5. **No Job Owner requirement** for Hatthasilpa
6. Ensure Job Ticket page never shows Classic-only actions for Hatthasilpa jobs.

---

## Scope & Work Items

### 1. Backend — hatthasilpa_jobs_api.php
- Fix `action: create`:
  - Force status = `planned` regardless of incoming data.
  - Ensure NO token generation on create.
- Fix `action: start_production`:
  - Generate DAG tokens via GraphBindingHelper + Flow Token Engine.
  - Set status = `in_progress`.
  - Log event.
- Fix `action: restore_to_planned`:
  - Status must become `planned` (not paused).
- Fix `action: cancel_job`:
  - Status → `cancelled`.
  - Soft-clear tokens (do not delete).
- Ensure Hatthasilpa jobs NEVER check for `job_owner_id`.

### 2. Backend — job_ticket.php (Cross-Sync)
- Modify `get` action so:
  - If coming from Hatthasilpa: show ticket detail, but hide Classic lifecycle data.
- Add `open_from_hatthasilpa` mode:
  - Return limited detail.
  - Hide Classic-only fields (owner, routing_mode, progress, session logs).

### 3. JS — hatthasilpa/jobs.js
- In table list:
  - Add click handler for “View details” → redirect to `index.php?p=job_ticket&id=XXX&src=hatthasilpa`.
- In create modal:
  - Remove any field related to job_owner/operator.
- After create:
  - Refresh list.
  - Ensure status badge shows `Planned`.

### 4. JS — job_ticket.js
- If `src=hatthasilpa`:
  - Hide lifecycle buttons (start/pause/resume/cancel/restore).
  - Hide job_owner/select.
  - Hide assigned operator section.
  - Hide routing_mode and node progress.
  - Hide MO cross-reference.
  - Show a banner:  
    **“This Job Ticket was created from Hatthasilpa Jobs. Lifecycle actions must be performed in Hatthasilpa Jobs.”**

### 5. Views — job_ticket.php
- Add a `source-banner` placeholder.
- Conditionally hide Classic-only blocks based on a flag from JS.

---

## Acceptance Criteria
- Creating a Hatthasilpa job always results in:
  ```
  status: planned
  tokens: none
  job_owner_id: null
  ```
- Pressing Start in Hatthasilpa jobs page:
  ```
  status: in_progress
  tokens: generated
  ```
- Pressing Cancel:
  ```
  status: cancelled
  tokens: remain soft but inactive
  ```
- Pressing Restore:
  ```
  status: planned
  ```
- Opening a Hatthasilpa job in Job Ticket offcanvas:
  - Shows details.
  - Hides all Classic actions.
  - No JS errors.

---

## Files to Modify
- `source/hatthasilpa_jobs_api.php`
- `source/job_ticket.php`
- `assets/javascripts/hatthasilpa/jobs.js`
- `assets/javascripts/hatthasilpa/job_ticket.js`
- `views/job_ticket.php`

---

## Status

- ✅ **COMPLETED** (2025-11-29)
- See: [task24_7_results.md](results/task24_7_results.md)