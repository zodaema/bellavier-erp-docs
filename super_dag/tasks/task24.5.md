# Task 24.5 — Job Ticket State Machine Validation & Error Handling

## Objective
Strengthen the Job Ticket lifecycle by enforcing strict state transitions, preventing invalid operations, adding explicit error codes, and guaranteeing that Start / Pause / Resume / Complete behave consistently and predictably.

This ensures that Job Tickets in Classic Line operate without ambiguous states and eliminates operator-side confusion.

---

## Scope

### A. Backend (PHP)
**Target file:** `source/job_ticket.php`

Implement a strict state machine:

### 1. Allowed Transitions
| Current Status | Allowed Actions | Description |
|----------------|----------------|-------------|
| `draft` | plan | Plan job & lock routing/mode |
| `planned` | start | Start work at assigned station |
| `in_progress` | pause, complete | Pause or finish work |
| `paused` | resume, cancel | Resume or cancel |
| `completed` | — | Locked |
| `cancelled` | restore | Restore to `paused` |

---

### 2. Forbidden Transitions → Must throw error_code
- double Start → `ERR_ALREADY_STARTED`
- start while paused → `ERR_MUST_RESUME`
- pause when not in progress → `ERR_NOT_IN_PROGRESS`
- resume when not paused → `ERR_NOT_PAUSED`
- complete when still paused → `ERR_CANNOT_COMPLETE_FROM_PAUSED`
- restore when not cancelled → `ERR_CANNOT_RESTORE`

---

### 3. Error Response Standardization
Add unified error model:

```
{
  "ok": false,
  "error_code": "ERR_NOT_IN_PROGRESS",
  "error_message": "Cannot pause because the job is not currently in progress.",
  "ticket_id": 1234,
  "status": "planned"
}
```

---

### B. Frontend (JS)
**Target file:**  
`assets/javascripts/hatthasilpa/job_ticket.js`

### 1. Disable buttons based on state machine:
- Start shown only when status = `planned`
- Pause shown only when status = `in_progress`
- Resume shown only when status = `paused`
- Complete shown only when status in (`in_progress`)
- Cancel shown when status in (`paused`, `planned`)
- Restore shown only when status = `cancelled`

### 2. Show frontend error messages using `error_code` mapping

---

## C. UI / View
**Target file:**  
`views/job_ticket.php`

### 1. Replace hardcoded button visibility logic  
Use state machine rules (same as JS).

### 2. Add warning banner when transitions blocked
Example:

```
<div class="alert alert-warning d-none" id="jt-warning"></div>
```

JS will inject message when backend errors occur.

---

## D. Acceptance Criteria

### 1. Prevent all invalid transitions  
Impossible to produce invalid Ticket states.

### 2. Consistent UI rendering  
Users only see valid buttons per state.

### 3. Explicit error codes  
No more silent failures or ambiguous 0/1 responses.

### 4. Full backward compatibility  
Existing Job Tickets still work with new logic.

---

## E. Files to Patch in This Task

1. `source/job_ticket.php`  
   - Add state machine validator  
   - Add unified error response  
   - Add error_code mapping  
   - Enforce transition rules

2. `assets/javascripts/hatthasilpa/job_ticket.js`  
   - Button logic update  
   - Error message handler

3. `views/job_ticket.php`  
   - Update button display logic  
   - Add warning placeholder

---

## F. Next Task After 24.5
Task **24.6 — Job Ticket Assigned Operator**
- Add operator assignment logic
- Add backend & UI selector
- Only assigned operator can Start/Pause/Resume/Complete

---

_End of Task 24.5 Specification_
