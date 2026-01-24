# Task 24.2 Results – Job Ticket Progress Engine v1 (DAG / Token-Based Progress)

**Date:** 2025-11-28  
**Status:** ✅ **COMPLETED**  
**Objective:** Create a unified, reliable Progress Engine for Job Tickets that uses tokens/canonical events for DAG mode and task completion for Linear mode

---

## Executive Summary

Task 24.2 successfully implemented Job Ticket Progress Engine v1, providing:
- Token-based progress computation for DAG mode tickets
- Task-based progress computation for Linear mode tickets
- Clean API endpoint for progress data
- UI integration in Job Ticket offcanvas detail view

**Key Achievements:**
- ✅ Created `JobTicketProgressService` class with DAG and Linear computation
- ✅ Created `job_ticket_progress_api.php` endpoint
- ✅ Integrated progress display into Job Ticket UI
- ✅ Read-only, side-effect free implementation
- ✅ Graceful error handling for missing/invalid data
- ✅ All syntax checks passed

---

## Files Created

### 1. `source/BGERP/JobTicket/JobTicketProgressService.php` (535 lines)
**Purpose:** Core service for computing Job Ticket progress

**Key Methods:**
- `computeProgress(int $jobTicketId): array` - Main entry point
- `computeDagProgress(int $jobTicketId, array $ticket): array` - DAG mode computation
- `computeLinearProgress(int $jobTicketId, array $ticket): array` - Linear mode computation
- `detectMode(array $ticket): string` - Detect routing mode (DAG vs Linear)
- `getTokenStats(int $graphInstanceId): array` - Get token statistics
- `getNodeBreakdown(int $graphInstanceId): array` - Get node-level breakdown (optional)
- `getTaskStats(int $jobTicketId): array` - Get task statistics for Linear mode
- `getLinearCompletedQty(int $jobTicketId): int` - Get completed qty from operator sessions

**Design Principles:**
- Read-only: Only SELECT queries, no writes
- Side-effect free: Safe to call many times
- Graceful degradation: Returns 0% with reason messages for invalid/missing data
- DAG-first: Uses token/canonical data when available
- Linear fallback: Uses task completion for legacy tickets

### 2. `source/job_ticket_progress_api.php` (95 lines)
**Purpose:** API endpoint for progress computation

**Actions:**
- `action=progress&job_ticket_id=123` - Returns progress data

**Response Format:**
```json
{
  "ok": true,
  "job_ticket_id": 123,
  "mode": "dag" | "linear" | "unknown",
  "progress_pct": 42.5,
  "completed_qty": 17,
  "target_qty": 40,
  "breakdown": {
    "nodes": [...],
    "stages": []
  },
  "meta": {
    "has_dag": true,
    "notes": []
  }
}
```

---

## Files Modified

### 1. `views/job_ticket.php`
**Changes:**
- Added Progress Section in offcanvas detail view (before Routing Info Section)
- Progress section includes:
  - Progress bar with percentage
  - Completed/Target/Remaining quantities (if available)
  - Mode label (DAG-based / Task-based)
  - Token or task information based on mode

### 2. `assets/javascripts/hatthasilpa/job_ticket.js`
**Changes:**
- Added `loadTicketProgress(jobTicketId)` function to call progress API
- Added `renderTicketProgress(data)` function to render progress data
- Added `renderTicketProgressError(resp)` function for error handling
- Integrated progress loading into `loadTicketDetail()` function

---

## Implementation Details

### DAG Mode Progress Computation

**Formula:**
```
progress_pct = clamp((completed_qty / target_qty) * 100, 0, 100)
```

**Data Sources:**
- `job_graph_instance` - Links job ticket to graph instance
- `flow_token` - Token data with status and qty
- Only counts tokens with `status = 'completed'` (v1: ignores 'scrapped')

**Token Statistics:**
- `total_tokens`: Total tokens for the graph instance
- `completed_count`: Number of completed tokens
- `completed_qty`: Sum of qty from completed tokens (defaults to 1 if qty is NULL)

**Node Breakdown (Optional):**
- Groups tokens by `current_node_id`
- Shows per-node completion rate
- Includes node name, code, total tokens, completed tokens, and progress percentage

### Linear Mode Progress Computation

**Formula (Task-based):**
```
progress_pct = (completed_tasks / total_tasks) * 100
```

**Alternative (Quantity-based, if available):**
```
progress_pct = clamp((completed_qty / target_qty) * 100, 0, 100)
```

**Data Sources:**
- `job_task` - Task data with status
- `task_operator_session` - Operator sessions for completed quantity
- Only counts tasks with `status != 'cancelled'`
- Completed tasks: `status IN ('completed', 'done')`

**Task Statistics:**
- `total_tasks`: Number of active tasks (excluding cancelled)
- `completed_tasks`: Number of completed tasks
- `tasks`: Array of task details with status

---

## API Integration

### Endpoint
```
GET/POST source/job_ticket_progress_api.php?action=progress&job_ticket_id=123
```

### Authentication
- Requires `hatthasilpa.job.ticket` permission
- Rate limited: 120 requests per 60 seconds

### Error Handling
- **404**: Ticket not found
- **400**: Missing or invalid job_ticket_id
- **500**: Internal server error

### Response Examples

**DAG Mode:**
```json
{
  "ok": true,
  "job_ticket_id": 123,
  "mode": "dag",
  "progress_pct": 65.5,
  "completed_qty": 26,
  "target_qty": 40,
  "total_tokens": 40,
  "completed_tokens": 26,
  "breakdown": {
    "nodes": [
      {
        "node_id": 1,
        "node_name": "Cut",
        "node_code": "CUT-001",
        "total_tokens": 10,
        "completed_tokens": 8,
        "completed_qty": 8,
        "progress_pct": 80.0
      }
    ],
    "stages": []
  },
  "meta": {
    "has_dag": true,
    "graph_instance_id": 456,
    "notes": []
  }
}
```

**Linear Mode:**
```json
{
  "ok": true,
  "job_ticket_id": 124,
  "mode": "linear",
  "progress_pct": 75.0,
  "completed_qty": 30,
  "target_qty": 40,
  "total_tasks": 4,
  "completed_tasks": 3,
  "breakdown": {
    "tasks": [
      {
        "task_id": 1,
        "step_name": "Cut",
        "sequence_no": 1,
        "status": "completed",
        "is_completed": true
      }
    ],
    "stages": [],
    "nodes": []
  },
  "meta": {
    "has_dag": false,
    "notes": []
  }
}
```

---

## UI Integration

### Progress Section Layout

**Location:** Offcanvas detail view, after MO/Product Summary, before Routing Info

**Components:**
1. **Progress Bar:**
   - Visual progress bar (0-100%)
   - Color coding:
     - Green (bg-success): 100%
     - Blue (bg-info): ≥75%
     - Yellow (bg-warning): ≥50%
     - Gray (bg-secondary): <50%

2. **Mode Badge:**
   - "DAG-based" for DAG mode
   - "Task-based" for Linear mode

3. **Quantity Information (if available):**
   - Completed quantity
   - Target quantity
   - Remaining quantity

4. **Token/Task Information:**
   - DAG mode: Completed tokens / Total tokens
   - Linear mode: Completed tasks / Total tasks

### Error State
- Shows warning alert if progress API fails
- Message: "Progress not available"
- Does not block UI functionality

---

## Testing Notes

### Manual Test Scenarios

1. **DAG Mode Ticket with Completed Tokens:**
   - Create DAG mode ticket
   - Spawn tokens and complete some
   - Expected: Progress shows completed_qty / target_qty percentage
   - Expected: Node breakdown shows per-node progress

2. **DAG Mode Ticket with No Tokens:**
   - Create DAG mode ticket
   - No tokens spawned yet
   - Expected: 0% progress with appropriate message

3. **Linear Mode Ticket with Mixed Task Statuses:**
   - Create Linear mode ticket
   - Add multiple tasks with different statuses
   - Expected: Progress shows completed_tasks / total_tasks percentage
   - Expected: If operator sessions exist, uses quantity-based progress

4. **Linear Mode Ticket with Operator Sessions:**
   - Create Linear mode ticket
   - Add tasks and create operator sessions
   - Expected: Progress uses completed_qty from sessions if available

5. **Invalid/Missing Ticket:**
   - Call API with non-existent ticket ID
   - Expected: 404 error with appropriate message

### Performance Notes

**Queries Per Call:**
- **DAG Mode:**
  - 1 query: Fetch ticket data
  - 1 query: Check graph instance
  - 1 query: Get token statistics
  - 1 query: Get node breakdown (optional)
  - **Total: 3-4 queries**

- **Linear Mode:**
  - 1 query: Fetch ticket data
  - 1 query: Get task statistics
  - 1 query: Get completed qty from sessions
  - **Total: 3 queries**

**Caching:**
- No internal caching in v1 (can be added in later tasks if needed)
- Service is safe to call multiple times (read-only)

---

## Limitations & Next Steps

### Known Limitations (v1)

1. **Scrapped Tokens:**
   - v1 only counts `completed` tokens, ignores `scrapped`
   - Future: May need to account for scrapped qty separately

2. **Stage Breakdown:**
   - Not implemented in v1 (returns empty array)
   - Future: Can be added by grouping nodes by stage metadata

3. **Weighted Task Progress:**
   - Linear mode uses equal-weight task completion
   - Future: Can add task_weight or sequence_no weighting

4. **Canonical Event Integration:**
   - v1 uses direct token status, not canonical events
   - Future: Can integrate with TimeEventReader for more accurate progress

5. **Progress Persistence:**
   - v1 is read-only, doesn't persist progress to DB
   - Future: Can add caching or periodic updates if needed

### Next Steps (Task 24.3+)

1. **Performance Optimization:**
   - Add internal caching for frequently accessed tickets
   - Consider materialized views for large datasets

2. **Enhanced Breakdown:**
   - Implement stage-level breakdown
   - Add time-based progress (ETA integration)

3. **Scrapped Token Handling:**
   - Decide on scrapped token counting policy
   - Add separate scrapped_qty field if needed

4. **Canonical Event Integration:**
   - Use TimeEventReader for more accurate progress
   - Integrate with canonical timeline

5. **Progress Persistence (Optional):**
   - Add progress_pct column to job_ticket table
   - Periodic background job to update progress

---

## Code Quality

- ✅ All syntax checks passed
- ✅ No linter errors
- ✅ Follows existing code patterns
- ✅ Read-only implementation (no side effects)
- ✅ Graceful error handling
- ✅ Consistent with project coding standards
- ✅ Well-documented with PHPDoc comments

---

## Summary

Task 24.2 successfully implemented Job Ticket Progress Engine v1, providing a unified, reliable way to compute progress for both DAG and Linear mode tickets. The implementation is read-only, side-effect free, and gracefully handles missing or invalid data. The UI integration provides clear visual feedback to users about ticket progress.

**Files Created:** 2  
**Files Modified:** 2  
**Lines Added:** ~700  
**Breaking Changes:** None  
**Backward Compatible:** Yes

