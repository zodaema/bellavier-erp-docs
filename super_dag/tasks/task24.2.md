## Task 24.2 – Job Ticket Progress Engine v1 (DAG / Token-Based Progress)

### 1. Context

Phase 24 focuses on **Job Ticket / Execution Sync**. In Task 24.1 we:

- Cleaned up the Job Ticket UI and flow.
- Clarified the distinction between Linear vs DAG mode in the UI.
- Improved the offcanvas layout and basic status visibility.

At this point:

- Canonical event pipeline, TimeEventReader, and token lifecycle are already implemented (Phase 21–22).
- MO ETA / Simulation / Health stack is implemented (Phase 23) but focused on MO, not Job Ticket.
- Job Ticket can be in:
  - **Linear mode** (job_task + wip_log driven), or
  - **DAG mode** (graph_instance_id / flow_token driven).

What we **don't** have yet is a unified, reliable **"Progress Engine"** for Job Tickets that:

- Uses **tokens / canonical events** when available (DAG mode).
- Falls back to **task / log based progress** in Linear mode (v1 can be simpler here).
- Exposes progress in a clean API that the UI (and later MO / dashboards) can consume.

This task creates **Job Ticket Progress Engine v1**, focused on:

- Read-only progress computation.
- DAG-first, token-based progress for tickets that already use the DAG stack.
- Non-invasive integration with Job Ticket UI (no DB schema changes).

We will NOT attempt to model all exotic scenarios in v1; the design must be extendable in later tasks (24.3+).

---

### 2. Goals

1. **Expose a token-based progress API for Job Tickets (DAG mode first)**  
   Given a `job_ticket_id`, compute:
   - Overall progress percentage (0–100).
   - Completed vs target quantity.
   - Optional: Stage / Node breakdown if feasible from existing data.

2. **Provide a minimal fallback for Linear mode**  
   - Use job_task status / completion to derive a coarse-grained progress.%
   - v1 can be simple: e.g., ratio of completed tasks.

3. **Integrate progress into Job Ticket UI**  
   - Show a progress bar and basic numbers in the offcanvas detail.
   - Optionally show a small breakdown section for DAG tickets.

4. **Keep the engine read-only and side-effect free**  
   - No DB schema changes in this task.
   - No writes to MO / Job Ticket fields.

5. **Respect canonical separation rules**  
   - Do not mix Hatthasilpa and Classic canonical timelines.
   - If we use canonical events, filter by the appropriate production mode / context where applicable.

---

### 3. Non-goals (Important)

Do **NOT** in this task:

- Add new DB tables or alter existing schemas.
- Persist progress to `job_ticket` or `mo` tables (this will be a later optimization if needed).
- Change token lifecycle, canonical event generation, or LocalRepairEngine.
- Change how MO ETA / Simulation works.
- Add any new background jobs / cron.

This task is about **read-only computation + UI integration**, nothing else.

---

### 4. Design Overview

#### 4.1 Core Idea

Introduce a new service class:

- `source/BGERP/JobTicket/JobTicketProgressService.php`

Responsibilities:

- Provide a single, stable entry point to compute progress for a Job Ticket.
- Implement DAG-based logic when the ticket is linked to a DAG instance.
- Implement a simple Linear-fallback when the ticket is not DAG-enabled.
- Expose optional breakdowns (stage / node) when data is available.

The service must:

- Be **pure read-only** (no writes).
- Be safe to call many times (no side effects).
- Handle invalid/missing data gracefully (return 0% with reason messages).

#### 4.2 DAG Mode (Token-Based)

For tickets with `routing_mode = 'dag'` or `graph_instance_id_actual` set:

- Use existing DAG / token infrastructure to compute progress.
- Prefer using token / canonical event data rather than legacy logs.

Possible data sources:

- `job_graph_instance` (or equivalent) to locate the graph instance for this ticket.
- `flow_token` for tokens belonging to this job ticket.
  - Fields: `status`, `qty`, `node_id`, `start_at`, `completed_at`, etc.
- Canonical events in `token_event` (optional for later refinements).

Basic DAG progress formula (v1 suggestion):

- Define `target_qty` at Job Ticket level.
- Count or sum `qty` of all tokens that:
  - Belong to this job ticket.
  - Are in a final status (e.g., `completed` / `scrapped` where scrapped may or may not count depending on design; v1 can count only `completed`).
- Progress percentage:

  ```
  progress_pct = clamp( (completed_qty / target_qty) * 100, 0, 100 )
  ```

- If `target_qty` is 0 or missing → `progress_pct = 0`, and return a warning in metadata.

Stage / node breakdown (v1, optional and simple):

- Group tokens by `node_id` and compute per-node completion rate.
- If stage concept is available (via node metadata / routing), group nodes by stage and compute per-stage completion.


#### 4.3 Linear Mode (Task-Based Fallback)

For tickets without DAG instance (pure linear / legacy tickets):

- Use `job_task` table to derive approximate progress.
- Simple v1 approach:

  - Let `N_total` = number of active tasks (excluding cancelled if applicable).
  - Let `N_completed` = number of tasks with `status = 'completed'`.
  - If `N_total > 0`:

    ```
    progress_pct = (N_completed / N_total) * 100
    ```

  - Else, `progress_pct = 0`.

- Optionally weight by `task_weight` or `sequence_no` if the schema already provides a simple factor. If not, keep it equal-weight to avoid overcomplicating v1.

- You may also optionally incorporate WIP logs in the future; for v1, task-level completion is enough.

#### 4.4 API Exposure

Create a small API entry point:

- `source/job_ticket_progress_api.php`

Supported actions:

- `action=progress&job_ticket_id=123`
  - Returns:

    ```json
    {
      "ok": true,
      "job_ticket_id": 123,
      "mode": "dag" | "linear" | "unknown",
      "progress_pct": 42.5,
      "completed_qty": 17,
      "target_qty": 40,
      "breakdown": {
        "stages": [...],  // optional
        "nodes": [...]    // optional
      },
      "meta": {
        "has_dag": true,
        "notes": ["..."]
      }
    }
    ```

- `action=stage_breakdown&job_ticket_id=123` (optional, only if you decide to separate from main progress for performance)
- `action=node_breakdown&job_ticket_id=123` (optional)

The implementation can start with a **single `progress` action** and embed minimal breakdown data. Further actions can be added in later tasks.


#### 4.5 UI Integration (job_ticket.js + views/job_ticket.php)

In the Job Ticket offcanvas (detail view):

- When loading ticket details, call the new progress API for that ticket.
- Display:

  - A progress bar with percentage.
  - Completed vs target qty if available.
  - Optional: small text like "DAG-based" / "Task-based" to indicate mode.

UI rules:

- If API fails → show 0% or "N/A" and a subtle message like "Progress not available"; do not block the UI.
- Keep the UI light; do not add heavy charts.

---

### 5. Implementation Steps

#### 5.1 Create JobTicketProgressService

File: `source/BGERP/JobTicket/JobTicketProgressService.php`

Responsibilities:

- `computeProgress(int $jobTicketId): array`
  - Main entry point.
  - Detect whether ticket is DAG or Linear.
  - Delegate to `computeDagProgress()` or `computeLinearProgress()`.
  - Return a structured array:

    ```php
    [
      'ok'            => true/false,
      'mode'          => 'dag'|'linear'|'unknown',
      'progress_pct'  => float,
      'completed_qty' => int|null,
      'target_qty'    => int|null,
      'breakdown'     => [
        'stages' => [...], // optional
        'nodes'  => [...], // optional
      ],
      'meta'          => [ 'notes' => [...], 'warnings' => [...]],
    ]
    ```

- `computeDagProgress(int $jobTicketId): array`
  - Encapsulate all DAG/token-based logic.

- `computeLinearProgress(int $jobTicketId): array`
  - Encapsulate task-based fallback logic.

Constraints:

- Read-only: only SELECT queries, no UPDATE/INSERT/DELETE.
- Handle missing ticket / missing data gracefully (return `ok=false` and reason in meta).
- Add minimal internal logging where helpful (e.g., if required context is missing).


#### 5.2 Implement job_ticket_progress_api.php

File: `source/job_ticket_progress_api.php`

- Initialize tenant / environment (similar style to other `*_api.php` files).
- Verify authentication & permission (re-use pattern from `job_ticket.php`).
- Accept GET/POST with `action=progress` and `job_ticket_id` (int).
- Instantiate `JobTicketProgressService` and call `computeProgress()`.
- Return JSON with HTTP 200 on success, 4xx/5xx only on serious errors (e.g., auth).


#### 5.3 Wire into Job Ticket UI

Files:

- `assets/javascripts/hatthasilpa/job_ticket.js`
- `views/job_ticket.php`

Tasks:

1. Add a small progress section in the offcanvas detail:
   - Progress bar + %.
   - Completed / target qty text if present.
   - Mode label: DAG vs Linear.

2. In JS:
   - On `loadTicketDetail(id, showOffcanvas)`, after ticket data is loaded, call the progress API:

     ```js
     $.getJSON('source/job_ticket_progress_api.php', {
       action: 'progress',
       job_ticket_id: id
     })
     .done(renderTicketProgress)
     .fail(handleTicketProgressError);
     ```

   - Implement `renderTicketProgress(data)` to update the DOM.
   - Implement `handleTicketProgressError()` to show a fallback state.

3. Avoid excessive calls:
   - Only call when offcanvas is opened / ticket changed.
   - Optionally cache last response per ticket in JS if needed.


#### 5.4 Minor Backend Enrichment (Optional)

File: `source/job_ticket.php`

- If helpful, you may expose basic `completed_qty` in the existing `get` action for tickets that already have this information cheaply available.
- However, **do not duplicate logic** between `job_ticket.php` and `JobTicketProgressService`. The new service should be the single source of truth for progress logic.


---

### 6. Testing & Validation

Create result document:

- `docs/super_dag/tasks/results/task24_2_results.md`

Include at least:

1. **Summary of Implementation**
   - Files created/modified.
   - High-level description of DAG vs Linear progress logic.

2. **Manual Test Scenarios**
   - Ticket with DAG routing, some tokens completed → progress between 0–100%.
   - Ticket with DAG routing, no tokens → 0% with a note.
   - Ticket in linear mode with multiple tasks and mixed statuses.
   - Ticket with invalid/missing data.

3. **Performance Notes**
   - Rough estimate of queries performed per call.
   - Any simple caching used inside the service.

4. **Limitations / Next Steps**
   - e.g., "Stage breakdown is approximate", "Does not account for scrapped qty yet", etc.


---

### 7. Constraints Recap

- No DB schema changes.
- No behavior change in token lifecycle or canonical event generation.
- No MO-side writes or schema changes.
- No new cron/scheduled jobs.
- Must remain safe to call from UI without impacting performance significantly.

Follow the existing code style and patterns used in the BGERP codebase. Keep the implementation clean, modular, and well-documented so that later tasks (24.3+) can extend the Progress Engine without rewriting it from scratch.
