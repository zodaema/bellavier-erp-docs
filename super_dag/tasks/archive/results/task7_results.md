# Task 7 Results — Time Engine Integration (STITCH Behavior Only)

**Status:** ✅ **COMPLETED**  
**Date:** December 2025  
**Task:** [task7.md](task7.md)

---

## Summary

Task 7 successfully integrated Time Engine into behavior execution for STITCH behavior. The system now creates, pauses, and resumes work sessions when operators interact with STITCH behavior panels, while maintaining full audit trail through `dag_behavior_log`.

---

## Deliverables

### 1. Token Work Session Service (DAG Namespace)

**File:** `source/BGERP/Dag/TokenWorkSessionService.php`

**Class:** `BGERP\Dag\TokenWorkSessionService`

**Purpose:** Wrapper service around `BGERP\Service\TokenWorkSessionService` providing simplified interface for behavior execution.

**Methods:**

1. **`startSession(int $tokenId, ?int $nodeId, ?int $workerId): array`**
   - Wraps `CoreTokenWorkSessionService::startToken()`
   - Validates token_id and worker_id
   - Returns: `['ok' => bool, 'effect' => string, 'session_id' => int|null, 'error' => string|null]`
   - Error mapping: `token_already_in_progress`, `token_locked_by_another_operator`

2. **`pauseSession(int $tokenId, ?int $nodeId, ?int $workerId): array`**
   - Wraps `CoreTokenWorkSessionService::pauseToken()`
   - Validates token_id
   - Returns: `['ok' => bool, 'effect' => string, 'session_id' => int|null, 'error' => string|null]`
   - Error mapping: `no_active_session_for_token`

3. **`resumeSession(int $tokenId, ?int $nodeId, ?int $workerId): array`**
   - Wraps `CoreTokenWorkSessionService::resumeToken()`
   - Validates token_id
   - Returns: `['ok' => bool, 'effect' => string, 'session_id' => int|null, 'error' => string|null]`
   - Error mapping: `no_paused_session_for_token`

**Implementation Details:**
- Uses existing `BGERP\Service\TokenWorkSessionService` (no duplication)
- Provides simplified interface for behavior execution
- Maps exceptions to user-friendly error codes
- Gets operator name from core database (fallback to "User {id}")

---

### 2. Behavior Execution Service Integration

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

**Changes:**
- Added `$workerId` parameter to constructor
- Added lazy-initialized `DagTokenWorkSessionService` instance
- Updated `handleStitch()` to call Time Engine service

**STITCH Handler Flow:**

```php
// Task 7: Validate worker ID
if (!$this->workerId || $this->workerId <= 0) {
    return ['ok' => false, 'error' => 'missing_worker_id'];
}

// Call Time Engine service based on action
if ($action === 'stitch_start') {
    $sessionResult = $sessionService->startSession($tokenId, $nodeId, $this->workerId);
} elseif ($action === 'stitch_pause') {
    $sessionResult = $sessionService->pauseSession($tokenId, $nodeId, $this->workerId);
} elseif ($action === 'stitch_resume') {
    $sessionResult = $sessionService->resumeSession($tokenId, $nodeId, $this->workerId);
}

// If session service returned error, propagate it
if (!$sessionResult || !($sessionResult['ok'] ?? false)) {
    return ['ok' => false, 'error' => $sessionResult['error'] ?? 'session_operation_failed'];
}

// Log behavior action (still required for audit trail)
$logId = $this->logBehaviorAction(...);

// Return success with session info
return [
    'ok' => true,
    'effect' => $sessionResult['effect'],
    'session_id' => $sessionResult['session_id'],
    'log_id' => $logId
];
```

**Important:** Behavior logging (`dag_behavior_log`) is still performed after session operations for complete audit trail.

---

### 3. API Integration

**File:** `source/dag_behavior_exec.php`

**Changes:**
- Pass `$userId` to `BehaviorExecutionService` constructor
- Include `session_id` in success response

**Code:**
```php
$executionService = new BehaviorExecutionService($tenantDb, $org, $userId);
$result = $executionService->execute($behaviorCode, $sourcePage, $action, $context, $formData);

// Response includes session_id
TenantApiOutput::success([
    'received' => true,
    'effect' => $result['effect'] ?? 'none',
    'log_id' => $result['log_id'] ?? null,
    'session_id' => $result['session_id'] ?? null
]);
```

---

## Behavior → Action → Session Effect Mapping

### STITCH

| Action | Time Engine Call | Session Effect | Response Effect |
|--------|------------------|----------------|-----------------|
| `stitch_start` | `startSession()` | Creates new active session | `session_started` |
| `stitch_pause` | `pauseSession()` | Updates session to paused | `session_paused` |
| `stitch_resume` | `resumeSession()` | Updates session to active | `session_resumed` |

### CUT, EDGE, QC_SINGLE, QC_FINAL

| Action | Time Engine Call | Session Effect | Response Effect |
|--------|------------------|----------------|-----------------|
| All actions | None (log-only) | No session changes | `logged_only` |

---

## Example Execution Flow

### STITCH Start Request
```json
{
  "behavior_code": "STITCH",
  "source_page": "work_queue",
  "action": "stitch_start",
  "context": {
    "token_id": 123,
    "node_id": 456,
    "work_center_id": 789
  },
  "form_data": {
    "pause_reason": "",
    "notes": ""
  }
}
```

**Execution:**
1. Validate context (requires `token_id`, `worker_id` from session)
2. Call `TokenWorkSessionService::startSession(123, 456, userId)`
3. Core service creates session in `token_work_session` table
4. Log to `dag_behavior_log` table
5. Return: `{ok: true, effect: 'session_started', session_id: 1, log_id: 2}`

**Database Changes:**
- `token_work_session`: 1 new row (status='active', started_at=NOW())
- `dag_behavior_log`: 1 new row
- `flow_token`: Status remains 'active' (no change)

### STITCH Pause Request
```json
{
  "behavior_code": "STITCH",
  "source_page": "work_queue",
  "action": "stitch_pause",
  "context": {
    "token_id": 123,
    "node_id": 456
  },
  "form_data": {
    "pause_reason": "break",
    "notes": "พักเบรก"
  }
}
```

**Execution:**
1. Validate context (requires `token_id`)
2. Call `TokenWorkSessionService::pauseSession(123, 456, userId)`
3. Core service:
   - Finds active session for token
   - Calculates work_seconds (base + live tail)
   - Updates session: status='paused', paused_at=NOW(), work_seconds=calculated
4. Log to `dag_behavior_log` table
5. Return: `{ok: true, effect: 'session_paused', session_id: 1, log_id: 3}`

**Database Changes:**
- `token_work_session`: 1 row updated (status='paused', paused_at=NOW(), work_seconds=calculated)
- `dag_behavior_log`: 1 new row
- `flow_token`: Status remains 'active' (no change)

### STITCH Resume Request
```json
{
  "behavior_code": "STITCH",
  "source_page": "work_queue",
  "action": "stitch_resume",
  "context": {
    "token_id": 123,
    "node_id": 456
  },
  "form_data": {
    "pause_reason": "",
    "notes": ""
  }
}
```

**Execution:**
1. Validate context (requires `token_id`)
2. Call `TokenWorkSessionService::resumeSession(123, 456, userId)`
3. Core service:
   - Finds paused session for token
   - Calculates pause duration
   - Updates session: status='active', resumed_at=NOW(), total_pause_minutes+=pause_duration
4. Log to `dag_behavior_log` table
5. Return: `{ok: true, effect: 'session_resumed', session_id: 1, log_id: 4}`

**Database Changes:**
- `token_work_session`: 1 row updated (status='active', resumed_at=NOW(), total_pause_minutes+=pause_duration)
- `dag_behavior_log`: 1 new row
- `flow_token`: Status remains 'active' (no change)

---

## Error Handling

### Validation Errors

**Missing token_id:**
```json
{
  "ok": false,
  "error": "missing_token_id",
  "action": "stitch_start"
}
```

**Missing worker_id:**
```json
{
  "ok": false,
  "error": "missing_worker_id",
  "action": "stitch_start"
}
```

### Session Operation Errors

**No active session (pause):**
```json
{
  "ok": false,
  "error": "no_active_session_for_token",
  "effect": "no_active_session"
}
```

**No paused session (resume):**
```json
{
  "ok": false,
  "error": "no_paused_session_for_token",
  "effect": "no_paused_session"
}
```

**Token already in progress (start):**
```json
{
  "ok": false,
  "error": "token_already_in_progress",
  "effect": "session_exists"
}
```

**Token locked by another operator:**
```json
{
  "ok": false,
  "error": "token_locked_by_another_operator",
  "effect": "token_locked"
}
```

---

## Safety Rails Verification

✅ **No DAG Routing Logic Changes**
- No token movement between nodes
- No changes to `current_node_id`
- No routing graph modifications

✅ **No Component Binding Logic Changes**
- No component serial binding logic
- No changes to component-related tables

✅ **No Behavior UI Changes**
- `behavior_ui_templates.js` unchanged
- `behavior_execution.js` unchanged
- Frontend payload structure unchanged

✅ **No Token Status Enum Changes**
- `flow_token.status` remains ENUM('active','completed','scrapped')
- No new status values added

✅ **STITCH Only**
- CUT, EDGE, QC_SINGLE, QC_FINAL remain log-only (no Time Engine integration)
- Only STITCH behavior uses Time Engine

✅ **Error Handling**
- All exceptions caught and logged
- Proper HTTP status codes returned
- User-friendly error messages

✅ **Backward Compatible**
- Existing behavior panels still work
- Handlers are optional (no error if missing)
- Graceful degradation if session service fails

---

## Testing Status

### PHP Syntax Check
```bash
$ php -l source/BGERP/Dag/TokenWorkSessionService.php
No syntax errors detected in source/BGERP/Dag/TokenWorkSessionService.php

$ php -l source/BGERP/Dag/BehaviorExecutionService.php
No syntax errors detected in source/BGERP/Dag/BehaviorExecutionService.php

$ php -l source/dag_behavior_exec.php
No syntax errors detected in source/dag_behavior_exec.php
```

✅ **All PHP files pass syntax check**

### Manual Testing Checklist

- [x] PHP syntax check: All files pass ✅
- [x] STITCH start: Creates session in `token_work_session` ✅
- [x] STITCH start: Logs entry in `dag_behavior_log` ✅
- [x] STITCH start: Response includes `session_id` ✅
- [x] STITCH pause: Updates session status to 'paused' ✅
- [x] STITCH pause: Calculates and saves `work_seconds` ✅
- [x] STITCH pause: Logs entry in `dag_behavior_log` ✅
- [x] STITCH resume: Updates session status to 'active' ✅
- [x] STITCH resume: Updates `total_pause_minutes` ✅
- [x] STITCH resume: Logs entry in `dag_behavior_log` ✅
- [x] Error: Pause without active session returns proper error ✅
- [x] Error: Resume without paused session returns proper error ✅
- [x] Error: Start with missing token_id returns proper error ✅
- [x] CUT/EDGE/QC: Still log-only (no session changes) ✅
- [x] Response format: Includes `effect`, `log_id`, `session_id` ✅

### Database Verification

**Check session entries:**
```sql
SELECT * FROM token_work_session 
WHERE id_token = 123
ORDER BY created_at DESC;
```

**Check behavior log entries:**
```sql
SELECT * FROM dag_behavior_log 
WHERE behavior_code = 'STITCH' AND id_token = 123
ORDER BY created_at DESC;
```

**Verify work time calculation:**
```sql
SELECT 
    id_session,
    status,
    started_at,
    paused_at,
    resumed_at,
    work_seconds,
    total_pause_minutes,
    TIMESTAMPDIFF(SECOND, COALESCE(resumed_at, started_at), NOW()) AS live_seconds
FROM token_work_session
WHERE id_token = 123
ORDER BY created_at DESC
LIMIT 1;
```

---

## Files Modified

### New Files (1)
- `source/BGERP/Dag/TokenWorkSessionService.php` (200+ lines)

### Modified Files (2)
- `source/BGERP/Dag/BehaviorExecutionService.php` - Integrated Time Engine for STITCH
- `source/dag_behavior_exec.php` - Pass worker ID to service

### Documentation (2)
- `docs/super_dag/tasks/task7_results.md` (this file)
- `docs/super_dag/task_index.md` (updated)

---

## Implementation Details

### Service Architecture

**Wrapper Pattern:**
- `BGERP\Dag\TokenWorkSessionService` wraps `BGERP\Service\TokenWorkSessionService`
- Provides simplified interface for behavior execution
- Maps exceptions to user-friendly error codes
- No logic duplication (reuses existing service)

**Lazy Initialization:**
- `BehaviorExecutionService` creates `DagTokenWorkSessionService` only when needed
- Reduces overhead for non-STITCH behaviors

### Time Tracking

**Work Seconds Calculation:**
- Base work seconds: Accumulated from previous work periods
- Live tail: Seconds since last resume/start (calculated on pause)
- Total: `work_seconds = base_work_seconds + live_tail_seconds`

**Pause Duration:**
- Calculated on resume: `(NOW() - paused_at) / 60` (minutes)
- Added to `total_pause_minutes`
- Excluded from work duration

**Session Status Flow:**
```
start → active
pause → paused (work_seconds saved)
resume → active (total_pause_minutes updated)
complete → completed (future)
```

### Error Mapping

**Core Service Exceptions → User-Friendly Errors:**
- "Token already in progress" → `token_already_in_progress`
- "Token locked by" → `token_locked_by_another_operator`
- "No active session" → `no_active_session_for_token`
- "No paused session" → `no_paused_session_for_token`

### Audit Trail

**Dual Logging:**
1. `token_work_session` - Work session lifecycle (Time Engine)
2. `dag_behavior_log` - Behavior action log (Audit Trail)

**Why Both?**
- `token_work_session`: Tracks work time, pause duration, operator
- `dag_behavior_log`: Tracks behavior actions, form data, source page
- Both provide different perspectives for debugging and analytics

---

## Next Steps (Task 8+)

Task 7 is **STITCH-only** Time Engine integration. The next tasks will:

1. **Task 8:** DAG Execution Logic (token movement between nodes)
2. **Task 9:** Behavior-specific execution logic (CUT batch processing, QC state transitions, etc.)
3. **Task 10:** Validation and business rules per behavior
4. **Task 11+:** Time Engine integration for other behaviors (CUT, EDGE, QC)

---

## Notes

- Time Engine integration is STITCH-only for Task 7
- Other behaviors (CUT, EDGE, QC) remain log-only
- Session service gracefully handles missing tables
- Error handling is comprehensive with proper logging
- No breaking changes to existing systems
- Ready for Task 8: DAG Execution Logic

---

**Task 7 Complete** ✅  
**Ready for Task 8: DAG Execution Logic**

