

## Task 24.1 – Job Ticket UI & Flow Cleanup (Job Ticket v2 – UX Pass 1)

### 1. Context

We have just renamed the module from `hatthasilpa_job_ticket` to `job_ticket` and confirmed that:

- Job Ticket is a **general production workflow tool** (conceptually supports Classic & Hatthasilpa).
- Hatthasilpa-specific UI (if any) will live elsewhere (e.g., `hatthasilpa_jobs`), not in the Job Ticket core.
- Permission code remains `hatthasilpa.job.ticket` for now (backward compatibility).

Current situation:

- Backend API: `source/job_ticket.php` (previously `hatthasilpa_job_ticket.php`).
- View: `views/job_ticket.php`.
- Page wrapper: `page/job_ticket.php`.
- JS controller: `assets/javascripts/hatthasilpa/job_ticket.js`.
- Job Ticket supports:
  - Linear mode (job_task + wip_log).
  - DAG mode (graph_instance_id, flow_token, etc.), where Tasks/Logs sections are hidden and DAG panel is shown.

We are **not** changing business rules in this task.  
We are doing a **UX/flow cleanup** and small consistency fixes to make Job Ticket usable and understandable for real users (internal staff) before we move on to deeper execution/token integration in later tasks.

---

### 2. Goals

1. **Clarify Job Ticket UI & Flow**
   - Make it obvious (from UI alone) what a Job Ticket is, what status it is in, and what the next valid actions are.
   - Reduce confusion around:
     - Ticket status vs Task status vs WIP logs.
     - Linear vs DAG mode.
     - MO linkage (if any).

2. **Fix Button/Action Availability**
   - Ensure Start / Pause / Resume / Complete buttons on **Tasks** appear only when valid.
   - Ensure ticket-level actions (if any) are consistent with ticket status.

3. **Improve Offcanvas Layout & Readability**
   - Make Offcanvas detail view more structured:
     - Header: Ticket identity, status, production type, routing mode.
     - Section for MO/Product summary.
     - Section for Tasks (Linear) or DAG info (DAG).
     - Section for WIP Logs.

4. **Update Wording to Be Less Confusing**
   - Remove or soften references that make Job Ticket look “Hatthasilpa-only”.
   - Keep the concept usable by production team without requiring deep system knowledge.

5. **Keep Everything Backward Compatible**
   - No breaking changes to API signatures.
   - No DB schema changes.
   - No permission changes.
   - No change in how sessions / WIP logs / status are computed.

---

### 3. Non-goals (IMPORTANT)

Do **NOT**:

- Change how canonical events, tokens, or DAG internals work.
- Implement new token behaviors or Node Behavior logic.
- Change how MO creates or links to Job Tickets (that will be in later tasks if needed).
- Change DB schema.
- Change permission code `hatthasilpa.job.ticket`.
- Move the JS file out of `assets/javascripts/hatthasilpa/`.

This is **UI/UX + minor wiring** only, not a deep behavior refactor.

---

### 4. Files in Scope

At minimum, you must review and potentially modify:

1. **View / Page**
   - `views/job_ticket.php`
   - `page/job_ticket.php`

2. **JS Controller**
   - `assets/javascripts/hatthasilpa/job_ticket.js`

3. **API (Read-Only for Context, Minimal Changes Only)**
   - `source/job_ticket.php`

4. **Shared Layout / Menu (Read-Only for Context)**
   - `views/template/sidebar-left.template.php`

If you need to add a small helper CSS rule, you may also touch:

- `assets/stylesheets/custom.css` (or the closest existing custom CSS file),
  but keep additions minimal and localized to Job Ticket.

---

### 5. Detailed Requirements

#### 5.1 Ticket List (Main Table)

1. **Columns**
   - Ensure the main Job Ticket table shows at least:
     - Ticket code
     - Job name
     - Product (short name / SKU)
     - MO code (if linked)
     - Production type (hatthasilpa / classic / hybrid) → shown as a small badge.
     - Routing mode (Linear / DAG / Unknown).
     - Status
     - Target qty / Completed qty (or a simple progress indicator).
     - Assigned operator (if applicable).
   - You may reuse existing columns if they already provide this info; do not add heavy joins in PHP.

2. **Status Badges**
   - Normalize visual status representation:
     - pending
     - in_progress
     - paused
     - completed
     - cancelled
   - Use existing badge styles if available; only add minimal styling if needed.

3. **Row Actions**
   - Keep core actions:
     - View / Detail
     - Edit
     - Delete
     - QR
   - Ensure that:
     - “Edit” is not shown when ticket is completed/cancelled (or is disabled with tooltip).
     - Delete is either:
       - Restricted to certain statuses (e.g., only pending tickets), or
       - Still shown but with a very clear confirmation message that it is destructive.

4. **Production Type Filter**
   - Keep or improve the production type filter (`hatthasilpa|classic|hybrid`).
   - Make sure the label of the filter is understandable (e.g., “Production Line” or “Line Type” instead of technical label).

#### 5.2 Offcanvas Detail – Structure and Layout

Reorganize the offcanvas detail into clear sections:

1. **Header Section**
   - Ticket code + job name (prominent).
   - Status badge.
   - Production type badge.
   - Routing mode badge (Linear vs DAG).
   - Optional: small text for `process_mode` (piece / batch).

2. **MO / Product Summary**
   - Show:
     - MO code (with link to MO page).
     - Product name / SKU.
     - Target qty, Completed qty, Remaining qty.
     - Due date (if available).

3. **Routing Info**
   - Show a simple line:
     - “Routing Mode: Linear / DAG”
     - “Graph: {graph_instance_id_actual or graph name}” if available.
   - If DAG:
     - Show a small panel (already present in code) and **hide Tasks & Logs section**.
   - If Linear:
     - Show Tasks & Logs tabs/panels.

4. **Tasks Section (Linear Mode Only)**
   - Make sure table headers are clear:
     - Sequence, Step, Work Center, Process Mode, Status, Operator, Progress, Actions.
   - **Buttons per row:**
     - Start / Resume: only if status allows it.
     - Pause: only if status = in_progress.
     - Complete: only if status is not yet completed/cancelled.
     - Edit Task: always allowed except when ticket is completed/cancelled (can be disabled in that case).
   - All status changes go through existing API endpoints (`task_update_status`) – do **not** invent new ones.

5. **WIP Logs Section (Linear Mode Only)**
   - Keep the current table, but:
     - Make the add-log button more obvious (label, icon, or placement).
     - Show key columns: time, operator, qty, event_type, linked task.
   - For edit/delete log buttons:
     - Respect existing logic – only adjust icons / labels if needed.

#### 5.3 Buttons and Action Logic (Tasks Level)

Using only the existing status and process_mode fields:

- Allowed transitions:
  - `pending` → `in_progress` (Start)
  - `in_progress` → `paused` (Pause)
  - `paused` → `in_progress` (Resume)
  - `in_progress` → `completed` (Complete)
  - `paused` → `completed` (Complete) — if business logic already allows it

You must:

1. Make sure the JS only shows **valid** action buttons based on current `task.status`.
2. Ensure that clicking those buttons:
   - Calls `task_update_status` with the correct new status.
   - Refreshes the task list and ticket header afterwards.

Do **not** change the backend status machine; only align the UI with it.

#### 5.4 Wording and Labels

1. Replace UI labels that say “Hatthasilpa Job Ticket” with simply “Job Ticket”, unless the context is explicitly Hatthasilpa-only.
2. If there are tooltips or help texts that mention only Hatthasilpa, reword them to be more generic (e.g., “Job Ticket for craft line” instead of “Hatthasilpa only”).
3. Do not change permission code or internal identifiers (`hatthasilpa.job.ticket` etc.) in this task; only surface-facing text.

---

### 6. Implementation Steps

1. **Review Phase**
   - Read:
     - `source/job_ticket.php`
     - `views/job_ticket.php`
     - `page/job_ticket.php`
     - `assets/javascripts/hatthasilpa/job_ticket.js`
   - Build a mental map of:
     - Current status transitions.
     - Which actions are bound to which buttons.
     - How DAG vs Linear modes are distinguished.

2. **Design UI Adjustments**
   - Plan the new layout for offcanvas detail (header + sections).
   - Decide where badges, labels, and buttons go.
   - Keep HTML structure changes minimal but meaningful.

3. **Implement View Changes**
   - Adjust `views/job_ticket.php` and/or `page/job_ticket.php`:
     - Offcanvas markup.
     - Header information.
     - Sections for MO/Product, Routing, Tasks, Logs.
     - Label updates.

4. **Implement JS Logic Changes**
   - In `job_ticket.js`:
     - Add helper functions to determine which buttons should be visible per task status.
     - Update DataTables row renderers for tasks and logs.
     - Ensure refresh after status changes works consistently.

5. **Light Styling (Optional)**
   - If necessary, add minimal CSS rules to improve spacing or alignment.
   - Use existing design language; do not introduce a new visual style.

6. **Test**
   - Create several Job Tickets in different statuses.
   - Test in both Linear and DAG modes:
     - Linear: see tasks + logs.
     - DAG: ensure tasks/logs are hidden and DAG info shows instead.
   - Verify:
     - Buttons appear/disappear correctly by status.
     - No JS errors in console.
     - APIs respond with 200 and expected payload.
     - Old bookmarks / routes still work.

---

### 7. Deliverables

1. Updated files:
   - `views/job_ticket.php`
   - `page/job_ticket.php`
   - `assets/javascripts/hatthasilpa/job_ticket.js`
   - (Optional) `assets/stylesheets/custom.css` or equivalent.

2. New result doc:
   - `docs/super_dag/tasks/results/task24_1_results.md`
   - Include:
     - Summary of UI changes.
     - List of files modified.
     - Before/After screenshots (if possible, or at least textual description).
     - Known limitations & next-step recommendations for Task 24.2+.

---

### 8. Constraints

- No DB migrations in this task.
- No new API endpoints; use existing `action=` patterns.
- No behavior changes in how Job Ticket status is computed on the backend.
- Must remain fully compatible with existing data and routes.

Follow this spec strictly and keep the implementation clean, readable, and consistent with the existing codebase style.