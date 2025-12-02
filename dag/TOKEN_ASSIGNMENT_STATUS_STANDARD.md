# Token Assignment Status Standard

**Date:** 2025-11-13  
**Status:** ✅ OFFICIAL STANDARD  
**Phase:** B (Runtime Routing Engine Hardening)

---

## Overview

This document defines the **official meaning** of each `token_assignment.status` value and the **state transitions** allowed in the Bellavier Hatthasilpa system.

### Purpose
- Ensure consistent status handling across all code
- Define clear state machine for assignment lifecycle
- Prevent invalid state transitions
- Guide debugging and monitoring

---

## Status Enum Definition

```sql
status ENUM(
    'assigned',
    'accepted',
    'started',
    'paused',
    'completed',
    'cancelled',
    'rejected'
) NOT NULL DEFAULT 'assigned'
```

---

## Status Meanings

### 1. `assigned`
**Meaning:** Assignment created by Manager, waiting for Operator action

**Characteristics:**
- Initial state when Manager assigns token to Operator
- Operator has NOT yet seen or accepted the assignment
- Assignment appears in Operator's queue/inbox
- No work session exists yet

**Typical Duration:** Minutes to hours (depends on notification response time)

**Next States:**
- `accepted` → Operator accepts the assignment
- `rejected` → Operator rejects the assignment
- `cancelled` → Manager cancels the assignment

**Database State:**
- `assigned_at`: Set
- `assigned_to_user_id`: Set
- `assigned_by_user_id`: Set
- `id_work_session`: NULL
- `accepted_at`: NULL
- `started_at`: NULL

---

### 2. `accepted`
**Meaning:** Operator acknowledged the assignment but has NOT started work yet

**Characteristics:**
- Operator clicked "Accept" but hasn't pressed "Start"
- Assignment removed from inbox, moved to "My Assignments"
- No active work session yet
- Operator committed to doing the work

**Typical Duration:** Minutes to hours (scheduling/preparation time)

**Next States:**
- `started` → Operator presses "Start Work"
- `cancelled` → Manager cancels (rare after acceptance)

**Database State:**
- `accepted_at`: Set
- `status_changed_at`: Set
- `id_work_session`: NULL (not started yet)
- `started_at`: NULL

**Note:** This state is OPTIONAL. Some workflows may go directly from `assigned` → `started`.

---

### 3. `started`
**Meaning:** Operator is actively working on the token (work session ACTIVE)

**Characteristics:**
- Operator pressed "Start Work"
- `token_work_session` created with `status='active'`
- Timer running, operator logged in at station
- Token cannot be reassigned while in this state (without explicit handoff)

**Typical Duration:** Minutes to hours (actual work time)

**Next States:**
- `paused` → Operator pauses work (break, interruption)
- `completed` → Operator finishes work successfully
- `cancelled` → Manager force-cancels (rare, requires reason)

**Database State:**
- `started_at`: Set
- `id_work_session`: Set (FK to token_work_session)
- `status_changed_at`: Set

**Critical Rule:**
- `getActiveWorkSessions()` MUST count `status = 'started'` for concurrency limits
- Only ONE operator can have `status='started'` per token at a time

---

### 4. `paused`
**Meaning:** Work session temporarily paused by Operator

**Characteristics:**
- Operator clicked "Pause" (break, lunch, interruption)
- Work session exists but timer stopped
- Operator can resume later
- Token still "owned" by this operator

**Typical Duration:** Minutes to hours (break duration)

**Next States:**
- `started` → Operator resumes work (most common)
- `cancelled` → Manager cancels while paused
- `completed` → Operator completes without resuming (rare edge case)

**Database State:**
- `paused_at`: Set
- `id_work_session`: Set (session still exists)
- Work session has `status='paused'`

**Note:** Multiple pause/resume cycles are allowed. Track with `token_work_session.pause_count`.

---

### 5. `completed`
**Meaning:** Operator finished work successfully

**Characteristics:**
- Operator clicked "Complete" or "Submit"
- Work session closed with `status='completed'`
- Token ready to move to next node (if routing rules allow)
- Actual work time recorded

**Terminal State:** YES (cannot transition to other states)

**Database State:**
- `completed_at`: Set
- `actual_minutes`: Calculated from work_session
- `status_changed_at`: Set
- Work session has `status='completed'`

**Effects:**
- Token may route to next node (depends on node rules)
- Assignment metrics updated
- Operator freed for next assignment

---

### 6. `cancelled`
**Meaning:** Assignment cancelled by Manager or System

**Characteristics:**
- Manager manually cancelled (e.g., order cancelled, wrong assignment)
- System auto-cancelled (e.g., token routing changed, node skipped)
- Operator no longer responsible for this work
- Work session (if exists) terminated

**Terminal State:** YES (cannot transition to other states)

**Database State:**
- `cancelled_at`: Set
- `cancelled_reason`: MUST be set (text explanation)
- `status_changed_at`: Set

**Common Reasons:**
- "Order cancelled by customer"
- "Token routed to different node"
- "Reassigned to different operator"
- "Production plan changed"

---

### 7. `rejected`
**Meaning:** Operator declined the assignment

**Characteristics:**
- Operator clicked "Reject" before starting work
- Assignment returned to Manager for reassignment
- No work session created
- Operator provides rejection reason (optional but recommended)

**Terminal State:** YES for this assignment (new assignment may be created)

**Database State:**
- `cancelled_at`: Set (reused for rejection time)
- `cancelled_reason`: Contains rejection reason
- `status_changed_at`: Set
- `id_work_session`: NULL (never started)

**Common Reasons:**
- "Too busy - cannot accept"
- "Wrong skill set"
- "Equipment not available"
- "Shift ending soon"

---

## State Transition Diagram

```
                    ┌──────────────┐
                    │   assigned   │ (Initial)
                    └──────┬───────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         v                 v                 v
    ┌─────────┐      ┌──────────┐      ┌──────────┐
    │rejected │      │ accepted │      │cancelled │ (Terminal)
    └─────────┘      └────┬─────┘      └──────────┘
    (Terminal)            │
                          v
                    ┌──────────┐
                    │ started  │ <────┐
                    └────┬─────┘      │
                         │            │
              ┌──────────┼────────┐   │
              │          │        │   │
              v          v        │   │
         ┌────────┐  ┌──────────┐│   │
         │ paused │  │completed ││   │
         └────┬───┘  └──────────┘│   │
              │      (Terminal)  │   │
              │                  │   │
              └──────────────────┴───┘
                                 │
                                 v
                            ┌──────────┐
                            │cancelled │
                            └──────────┘
                            (Terminal)
```

---

## Status Transition Rules

### Valid Transitions

| From | To | Condition | Action Required |
|------|----|-----------|--------------------|
| `assigned` | `accepted` | Operator accepts | Update `accepted_at` |
| `assigned` | `rejected` | Operator rejects | Update `cancelled_at`, `cancelled_reason` |
| `assigned` | `cancelled` | Manager cancels | Update `cancelled_at`, `cancelled_reason` |
| `assigned` | `started` | Direct start (skip accept) | Update `started_at`, create work_session |
| `accepted` | `started` | Operator starts work | Update `started_at`, create work_session |
| `accepted` | `cancelled` | Manager cancels | Update `cancelled_at`, `cancelled_reason` |
| `started` | `paused` | Operator pauses | Update `paused_at`, pause work_session |
| `started` | `completed` | Operator completes | Update `completed_at`, close work_session |
| `started` | `cancelled` | Manager force-cancels | Update `cancelled_at`, terminate work_session |
| `paused` | `started` | Operator resumes | Clear `paused_at`, resume work_session |
| `paused` | `completed` | Complete without resume | Update `completed_at`, close work_session |
| `paused` | `cancelled` | Manager cancels | Update `cancelled_at`, terminate work_session |

### Invalid Transitions (MUST BLOCK)

- `completed` → ANY (terminal state)
- `cancelled` → ANY (terminal state)
- `rejected` → ANY (terminal state)
- `assigned` → `completed` (must start first)
- `accepted` → `completed` (must start first)
- `rejected` → `started` (cannot start rejected assignment)

---

## Concurrency Rules

### Active Work Sessions
```php
function getActiveWorkSessions(int $nodeId): int {
    // Count ONLY assignments with status='started'
    // NOT 'assigned' or 'accepted'
    return $db->query("
        SELECT COUNT(*) 
        FROM token_assignment 
        WHERE id_node = ? 
        AND status = 'started'
    ")->fetch_row()[0];
}
```

**Critical:**
- `assigned` and `accepted` do NOT count toward concurrency limits
- Only `started` (actively working) counts
- This prevents queue blocking while operators accept assignments

---

## Implementation Guidelines

### 1. Status Updates

Always use status-specific columns:
```php
// CORRECT
if ($newStatus === 'accepted') {
    $stmt = $db->prepare("
        UPDATE token_assignment 
        SET status = 'accepted',
            accepted_at = NOW(),
            status_changed_at = NOW()
        WHERE id_assignment = ?
    ");
}

// WRONG - missing timestamps
UPDATE token_assignment SET status = 'completed' WHERE id_assignment = ?
```

### 2. Transition Validation

Before updating status:
```php
function validateTransition(string $currentStatus, string $newStatus): bool {
    $validTransitions = [
        'assigned' => ['accepted', 'rejected', 'cancelled', 'started'],
        'accepted' => ['started', 'cancelled'],
        'started' => ['paused', 'completed', 'cancelled'],
        'paused' => ['started', 'completed', 'cancelled'],
        'completed' => [],  // Terminal
        'cancelled' => [],  // Terminal
        'rejected' => []    // Terminal
    ];
    
    return in_array($newStatus, $validTransitions[$currentStatus] ?? [], true);
}
```

### 3. Work Session Sync

Keep `token_assignment.status` and `token_work_session.status` in sync:
```php
// When starting work
UPDATE token_assignment SET status = 'started', ...
INSERT INTO token_work_session (status='active', ...)

// When pausing
UPDATE token_assignment SET status = 'paused', ...
UPDATE token_work_session SET status = 'paused', ...

// When completing
UPDATE token_assignment SET status = 'completed', ...
UPDATE token_work_session SET status = 'completed', ...
```

---

## Monitoring Queries

### Count assignments by status
```sql
SELECT status, COUNT(*) as cnt
FROM token_assignment
GROUP BY status
ORDER BY FIELD(status, 'assigned', 'accepted', 'started', 'paused', 'completed', 'cancelled', 'rejected');
```

### Find stuck assignments (assigned > 1 hour)
```sql
SELECT *
FROM token_assignment
WHERE status = 'assigned'
AND assigned_at < DATE_SUB(NOW(), INTERVAL 1 HOUR);
```

### Find long-running work (started > 4 hours)
```sql
SELECT ta.*, t.serial_number
FROM token_assignment ta
JOIN flow_token t ON t.id_token = ta.id_token
WHERE ta.status = 'started'
AND ta.started_at < DATE_SUB(NOW(), INTERVAL 4 HOUR);
```

---

## Notes for Developers

1. **Always check current status before updating**
   - Use WHERE clause with current status to prevent race conditions
   - Example: `WHERE id_assignment = ? AND status = 'assigned'`

2. **Set status_changed_at on every status change**
   - Helps with debugging and metrics
   - Use `NOW()` or `CURRENT_TIMESTAMP`

3. **Require cancellation reason**
   - `cancelled_reason` MUST NOT be NULL for `cancelled` status
   - Same for `rejected` status

4. **Log all status changes**
   - Consider adding to `assignment_log` table
   - Include: who changed, when, from what status, to what status, reason

5. **Handle orphaned sessions**
   - If assignment is cancelled, ensure work_session is terminated
   - Add cleanup job for dangling sessions

---

## Related Documents

- [DAG Routing Service](./BELLAVIER_DAG_RUNTIME_FLOW.md)
- [Token Work Session Lifecycle](../implementation/TOKEN_WORK_SESSION_LIFECYCLE.md)
- [Assignment API Documentation](../api/assignment_api.md)

---

**Approved by:** Engineering Team  
**Effective Date:** 2025-11-13  
**Version:** 1.0  
**Review Date:** 2025-12-13
