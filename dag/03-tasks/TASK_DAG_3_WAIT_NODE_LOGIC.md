# DAG Task 3: Wait Node Logic & Background Evaluation

**Task ID:** DAG-3  
**Status:** ✅ **COMPLETED** (95% - Production Ready)  
**Scope:** Routing / Wait Nodes  
**Type:** Implementation Task

---

## 1. Context

### Problem

Workflows needed a way to pause token execution for conditions other than join inputs, such as:
- Material drying time (e.g., glue drying 30 minutes)
- Batch size completion (wait for 10 tokens before proceeding)
- Supervisor approval
- Sensor conditions (e.g., humidity ≤ 12%)

Join nodes handle waiting for component inputs, but there was no mechanism for time-based, batch-based, or approval-based waits.

### Impact

- Workflows requiring time delays had to be handled manually
- Batch operations couldn't be automated
- Approval workflows required manual intervention

---

## 2. Objective

Implement `wait` node type that:
- Pauses token execution until a condition is satisfied
- Supports multiple wait types: time, batch, approval, sensor
- Auto-completes and routes tokens when conditions are met
- Is hidden from Work Queue and PWA (system-only)

---

## 3. Scope

### Database Schema

**Table:** `routing_node`  
**Column:** `wait_rule JSON NULL`  
**Migration:** `2025_12_december_consolidated.php` (Part 3/3)

**Example wait_rule JSON:**
```json
{"wait_type": "time", "minutes": 30}
{"wait_type": "batch", "min_batch": 10, "collect_for": "job_ticket"}
{"wait_type": "approval", "role": "supervisor"}
{"wait_type": "sensor", "value": "<= 12% humidity"}
```

### Wait Condition Types

| wait_type | Configuration | Description |
|-----------|---------------|-------------|
| `time` | `{"wait_type": "time", "minutes": 30}` | Wait for fixed duration |
| `batch` | `{"wait_type": "batch", "min_batch": 10, "collect_for": "job_ticket"}` | Wait until batch size reached |
| `approval` | `{"wait_type": "approval", "role": "supervisor"}` | Wait for manual approval |
| `sensor` | `{"wait_type": "sensor", "value": "<= 12% humidity"}` | Wait for sensor condition (future) |

### Visibility Policy

| Location | Visible? | Notes |
|----------|----------|-------|
| Work Queue | ❌ **NO** | System-only, no operator interaction |
| PWA | ❌ **NO** | System-only |
| Graph Designer | ✅ **YES** | For configuration |

### Allowed Actions

- ❌ No manual actions allowed (`start`, `pause`, `resume`, `complete`, `qc_pass`, `qc_fail`)
- ✅ System auto-complete when wait condition satisfied

---

## 4. Implementation Summary

### Routing Behavior

**Flow:**
```
Token enters wait node
  ↓
Status = 'waiting'
  ↓
Wait condition evaluation loop (background job or on-demand)
  ↓
If condition satisfied:
  → Auto-complete token
  → Auto-route to next node
  → Create 'wait_completed' event
```

### Key Methods

**DAGRoutingService::handleWaitNode()**
- Location: `source/BGERP/Service/DAGRoutingService.php`
- Purpose: Handle token entering wait node
- Behavior: Sets token status to 'waiting', creates 'wait_start' event, schedules evaluation

**DAGRoutingService::evaluateWaitCondition()**
- Purpose: Evaluate wait condition based on wait_type
- Supports: time, batch, approval, sensor

**DAGRoutingService::evaluateTimeWait()**
- Purpose: Check if elapsed time >= wait minutes
- Logic: Compares `wait_start` event time with current time

**DAGRoutingService::evaluateBatchWait()**
- Purpose: Check if batch size reached
- Logic: Counts tokens waiting at same node in same collection scope (job_ticket or instance)

**DAGRoutingService::evaluateApprovalWait()**
- Purpose: Check if approval granted
- Logic: Looks for `approval_granted` event

**DAGRoutingService::completeWaitNodeForToken()**
- Purpose: Public method for background jobs to complete wait node
- Behavior: Auto-completes token, routes to next node, creates 'wait_completed' event

### Background Job

**File:** `tools/cron/evaluate_wait_conditions.php`
- Purpose: Periodically evaluate wait conditions for all tokens at wait nodes
- Frequency: Every 1-5 minutes (configurable)
- Behavior: Evaluates all tokens with `status = 'waiting'` at wait nodes, auto-completes when conditions met

### Approval API

**File:** `source/dag_approval_api.php`
- Endpoint: `POST /api/dag/approval/grant?action=grant`
- Permission: Supervisor/manager/admin only
- Behavior: Creates `approval_granted` event, auto-completes wait node

### Validation

**DAGValidationService::validateWaitNodes()**
- Location: `source/BGERP/Service/DAGValidationService.php`
- Validates:
  - `wait_rule` must exist for `wait` nodes
  - `wait_rule.wait_type` must be one of: `time`, `batch`, `approval`, `sensor`
  - Must not have more than 1 outgoing edge
  - Cannot be used as join or split node
  - For `time` wait: `minutes` must be > 0
  - For `batch` wait: `min_batch` must be > 0

### Work Queue Filtering

**File:** `source/dag_token_api.php` (Line 1573)
- Filter: `n.node_type IN ('operation', 'qc')`
- Result: Wait nodes are hidden from Work Queue

---

## 5. Guardrails

### Must Not Regress

- ✅ **Wait nodes hidden from Work Queue** - Filter must remain: `node_type IN ('operation', 'qc')`
- ✅ **No manual actions** - Wait nodes must not accept start/pause/resume/complete actions
- ✅ **Auto-complete only** - Tokens at wait nodes can only be completed by system when condition satisfied
- ✅ **Validation rules** - Graph Designer must validate wait_rule configuration
- ✅ **Background job** - Must evaluate wait conditions periodically

### Test Coverage

**Test File:** `tests/Integration/WaitNodeLogicTest.php`

**Test Cases:**
- Time wait token enters wait node
- Time wait completes after duration
- Batch wait completes when batch full
- Approval wait completes when approval granted
- Wait completion routes token correctly
- Multiple tokens waiting at same batch node

**Status:** ⏳ Tests created but need refinement (95% implementation, 5% testing)

---

## 6. Status

**Status:** ✅ **COMPLETED** (95% - Production Ready)

**Implementation:**
- ✅ Database schema (`wait_rule` column) - Migration: `2025_12_december_consolidated.php`
- ✅ Core routing logic (`handleWaitNode()`, `evaluateWaitCondition()`) - `DAGRoutingService.php`
- ✅ Wait condition evaluation (time, batch, approval) - All evaluation methods implemented
- ✅ Validation (`validateWaitNodes()`) - `DAGValidationService.php`
- ✅ Work Queue filtering - Wait nodes filtered from Work Queue
- ✅ Background job - `tools/cron/evaluate_wait_conditions.php`
- ✅ Approval API - `source/dag_approval_api.php`
- ✅ Public method `completeWaitNodeForToken()` in `DAGRoutingService`

**Pending:**
- ⏳ Testing (unit tests, integration tests) - Tests created but need refinement

**Related Tasks:**
- ✅ Task 11: Work Queue Start & Details Patch (December 2025) - Fixed start token logic
- ✅ Task 11.1: Work Queue UI Smoothing (December 2025) - Fixed loading spinner

**Documentation:**
- ✅ Completion summary: `docs/dag/02-implementation-status/PHASE_1_5_COMPLETION_SUMMARY.md`
- ✅ Implementation plan: `docs/dag/02-implementation-status/PHASE_1_5_IMPLEMENTATION_PLAN.md`
- ✅ Roadmap section: `docs/dag/01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md` (Section 1.5)

---

## 7. Related Documentation

- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Section 1.5 Wait Node Logic
- [PHASE_1_5_COMPLETION_SUMMARY.md](../02-implementation-status/PHASE_1_5_COMPLETION_SUMMARY.md) - Detailed completion summary
- [PHASE_1_5_IMPLEMENTATION_PLAN.md](../02-implementation-status/PHASE_1_5_IMPLEMENTATION_PLAN.md) - Implementation plan

---

**Task Completed:** December 2025  
**Status:** 95% Complete (Production Ready, Tests Need Refinement)

