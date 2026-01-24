# Task 10 Results — Behavior & Routing Validation Guards (Phase 2.5)

**Status:** ✅ **COMPLETED**  
**Date:** December 2025  
**Task:** [task10.md](task10.md)

---

## Summary

Task 10 successfully added comprehensive validation guards to `BehaviorExecutionService` and `DagExecutionService`, preventing invalid operations and providing clear error messages. The system now validates token states, session conflicts, worker ownership, and DAG routing constraints before executing behavior actions or routing tokens.

---

## Deliverables

### 1. Behavior-level Validation (STITCH)

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

**Changes:**

1. **Token Context Validation**
   - Validates `token_id` is present and token exists
   - Validates `worker_id` is present
   - Returns standardized error codes:
     - `BEHAVIOR_INVALID_CONTEXT` (400) - Missing required context
     - `BEHAVIOR_TOKEN_CLOSED` (409) - Token is already closed

2. **Session Conflict Prevention**
   - **`stitch_start`**: Prevents starting if active session already exists for same token + worker
     - Error: `BEHAVIOR_SESSION_ALREADY_ACTIVE` (409)
   - **`stitch_resume`**: Requires paused session to exist
     - Error: `BEHAVIOR_NO_PAUSED_SESSION` (400)
   - **`stitch_pause`**: Requires active session to exist
     - Error: `BEHAVIOR_NO_ACTIVE_SESSION` (400)

3. **Token Status Guards**
   - Prevents any STITCH action on tokens with status:
     - `completed`
     - `cancelled`
     - `scrapped`
   - Error: `BEHAVIOR_TOKEN_CLOSED` (409)

4. **Worker Ownership Check**
   - Validates worker owns the session before pause/complete
   - Error: `BEHAVIOR_WORKER_MISMATCH` (403)
   - Checks `operator_user_id` in `token_work_session` table

**Helper Methods Added:**
- `fetchToken(int $tokenId): ?array` - Fetch token from database
- `getActiveSessionForToken(int $tokenId, int $workerId): ?array` - Get active session
- `getPausedSessionForToken(int $tokenId, int $workerId): ?array` - Get paused session

---

### 2. Behavior-level Validation (QC)

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

**Changes:**

1. **QC Action Validation**
   - Validates action is in allowed set: `qc_pass`, `qc_fail`, `qc_rework`, `qc_send_back`
   - Error: `BEHAVIOR_QC_UNKNOWN_ACTION` (400)

2. **Token Status Guards**
   - Prevents QC actions on closed tokens (same as STITCH)
   - Error: `BEHAVIOR_TOKEN_CLOSED` (409)

3. **Context Validation**
   - Validates `token_id` and `worker_id` (same as STITCH)
   - Error: `BEHAVIOR_INVALID_CONTEXT` (400)

**Note:** Duplicate QC pass prevention is logged as TODO (requires QC result tracking table - future task)

---

### 3. Routing-level Validation (DagExecutionService)

**File:** `source/BGERP/Dag/DagExecutionService.php`

**Changes:**

1. **Token State Validation**
   - Validates token exists before routing
     - Error: `DAG_TOKEN_NOT_FOUND` (404)
   - Prevents routing closed tokens:
     - Status: `completed`, `cancelled`, `scrapped`
     - Error: `DAG_TOKEN_CLOSED` (409)
   - Validates token is in routable state:
     - Status must be `active` or `ready`
     - Error: `DAG_TOKEN_NOT_ACTIVE` (409)

2. **DAG Next Node Validation**
   - Distinguishes between:
     - **End node reached** → Returns `completed: true` (success)
     - **No next node + not end node** → Error: `DAG_NO_NEXT_NODE` (500)
   - Checks `node_type === 'end'` or `is_end_node === true`
   - Prevents silent routing failures

3. **Error Contract Enhancement**
   - All errors now include:
     - `error` - Error code (e.g., `DAG_NO_NEXT_NODE`)
     - `app_code` - Application error code (e.g., `DAG_500_NO_NEXT_NODE`)
     - `message` - Human-readable message
   - Preserves backward compatibility (same response structure)

---

### 4. Error Codes & JSON Output Standardization

**File:** `source/dag_behavior_exec.php`

**Changes:**

1. **Standardized Error Response Format**
   ```json
   {
     "ok": false,
     "error": "BEHAVIOR_TOKEN_CLOSED",
     "app_code": "BEHAVIOR_409_TOKEN_CLOSED",
     "message": "Token is already closed (status: completed)",
     "behavior_code": "STITCH",
     "action": "stitch_complete",
     "token_status": "completed"
   }
   ```

2. **HTTP Status Code Mapping**
   - `400` - Bad Request (validation errors, invalid context)
   - `403` - Forbidden (worker mismatch)
   - `409` - Conflict (token closed, session already active)
   - `404` - Not Found (token not found)
   - `500` - Internal Server Error (graph errors, routing failures)

3. **Error Code Categories**
   - `BEHAVIOR_*` - Behavior execution errors
   - `DAG_*` - DAG routing errors

4. **Backward Compatibility**
   - Success responses unchanged (all existing fields preserved)
   - Error responses enhanced (new fields are additive)
   - Existing clients can ignore new error fields

---

## Error Codes Reference

### Behavior Errors

| Error Code | HTTP | App Code | Description |
|------------|------|----------|-------------|
| `BEHAVIOR_INVALID_CONTEXT` | 400 | `BEHAVIOR_400_INVALID_CONTEXT` | Missing token_id or worker_id |
| `BEHAVIOR_TOKEN_CLOSED` | 409 | `BEHAVIOR_409_TOKEN_CLOSED` | Token is completed/cancelled/scrapped |
| `BEHAVIOR_SESSION_ALREADY_ACTIVE` | 409 | `BEHAVIOR_409_SESSION_ALREADY_ACTIVE` | Active session already exists |
| `BEHAVIOR_NO_PAUSED_SESSION` | 400 | `BEHAVIOR_400_NO_PAUSED_SESSION` | No paused session to resume |
| `BEHAVIOR_NO_ACTIVE_SESSION` | 400 | `BEHAVIOR_400_NO_ACTIVE_SESSION` | No active session to pause |
| `BEHAVIOR_WORKER_MISMATCH` | 403 | `BEHAVIOR_403_WORKER_MISMATCH` | Session belongs to different worker |
| `BEHAVIOR_QC_UNKNOWN_ACTION` | 400 | `BEHAVIOR_400_QC_UNKNOWN_ACTION` | Unknown QC action |

### DAG Routing Errors

| Error Code | HTTP | App Code | Description |
|------------|------|----------|-------------|
| `DAG_TOKEN_NOT_FOUND` | 404 | `DAG_404_TOKEN_NOT_FOUND` | Token does not exist |
| `DAG_TOKEN_CLOSED` | 409 | `DAG_409_TOKEN_CLOSED` | Token is completed/cancelled/scrapped |
| `DAG_TOKEN_NOT_ACTIVE` | 409 | `DAG_409_TOKEN_NOT_ACTIVE` | Token not in active/ready state |
| `DAG_NO_NEXT_NODE` | 500 | `DAG_500_NO_NEXT_NODE` | No next node found and not end node |

---

## Files Modified

### Modified Files (3)

1. **`source/BGERP/Dag/BehaviorExecutionService.php`**
   - Added validation guards in `handleStitch()`
   - Added validation guards in `handleQc()`
   - Added helper methods: `fetchToken()`, `getActiveSessionForToken()`, `getPausedSessionForToken()`
   - Enhanced error contract for routing failures

2. **`source/BGERP/Dag/DagExecutionService.php`**
   - Enhanced `moveToNextNode()` with validation guards
   - Added token state validation
   - Added DAG next node validation
   - Enhanced error codes and messages

3. **`source/dag_behavior_exec.php`**
   - Standardized error response format
   - Added HTTP status code mapping
   - Enhanced error details in response

### Documentation (2)

- `docs/super_dag/tasks/task10_results.md` (this file)
- `docs/super_dag/task_index.md` (updated)

---

## Implementation Details

### Validation Flow

**STITCH Start:**
```
1. Validate token_id exists
2. Validate worker_id exists
3. Fetch token from database
4. Check token status (must not be closed)
5. Check for existing active session (prevent conflict)
6. If all valid → proceed with start
```

**STITCH Resume:**
```
1. Validate token_id and worker_id
2. Fetch token (check not closed)
3. Check for paused session (must exist)
4. If all valid → proceed with resume
```

**STITCH Complete:**
```
1. Validate token_id and worker_id
2. Fetch token (check not closed)
3. Check worker owns active session (if exists)
4. Complete session
5. Route token (with routing validation)
6. Return result with routing info
```

**QC Pass:**
```
1. Validate token_id and worker_id
2. Fetch token (check not closed)
3. Validate action is allowed
4. Route token (with routing validation)
5. Return result with routing info
```

### Error Contract Between Services

**BehaviorExecutionService → DagExecutionService:**
- If routing fails:
  - Behavior action still succeeds (session completed)
  - Routing info includes `moved: false` and error details
  - Effect: `stitch_completed_but_not_routed` or `qc_pass_but_not_routed`

**Example Response (Routing Failed):**
```json
{
  "ok": true,
  "effect": "stitch_completed_but_not_routed",
  "session_id": 123,
  "log_id": 456,
  "routing": {
    "moved": false,
    "error": "DAG_NO_NEXT_NODE",
    "app_code": "DAG_500_NO_NEXT_NODE",
    "message": "No next node found and current node is not an end node"
  }
}
```

---

## Safety Rails Verification

✅ **No Database Schema Changes**
- No new tables created
- No new columns added
- No migrations required
- Uses existing `token_work_session` table for validation

✅ **No API Response Structure Breaking Changes**
- Success responses unchanged
- Error responses enhanced (additive fields only)
- Backward compatible

✅ **No Behavior Changes (Except Validation)**
- Existing valid operations work identically
- Invalid operations now return clear errors
- No silent failures

✅ **No Component Binding Logic Changes**
- Component binding logic untouched
- Component serial binding preserved

✅ **No QC State Logic Changes**
- QC result handling preserved
- QC routing logic unchanged

✅ **No Time Engine Changes**
- Time tracking logic untouched
- Work session logic preserved

✅ **Error Handling**
- All exceptions caught and logged
- Proper error codes returned
- User-friendly error messages
- HTTP status codes mapped correctly

✅ **Backward Compatible**
- Existing endpoints work identically
- No breaking changes
- Graceful degradation if validation fails

---

## Testing Status

### PHP Syntax Check
```bash
$ php -l source/BGERP/Dag/BehaviorExecutionService.php
No syntax errors detected in source/BGERP/Dag/BehaviorExecutionService.php

$ php -l source/BGERP/Dag/DagExecutionService.php
No syntax errors detected in source/BGERP/Dag/DagExecutionService.php

$ php -l source/dag_behavior_exec.php
No syntax errors detected in source/dag_behavior_exec.php
```

✅ **All PHP files pass syntax check**

### Manual Testing Checklist

**Behavior Guards:**
- [x] `stitch_start` on token with active session → `BEHAVIOR_SESSION_ALREADY_ACTIVE` ✅
- [x] `stitch_resume` without paused session → `BEHAVIOR_NO_PAUSED_SESSION` ✅
- [x] `stitch_pause` without active session → `BEHAVIOR_NO_ACTIVE_SESSION` ✅
- [x] `stitch_complete` on closed token → `BEHAVIOR_TOKEN_CLOSED` ✅
- [x] `stitch_pause` by different worker → `BEHAVIOR_WORKER_MISMATCH` ✅
- [x] `qc_pass` on closed token → `BEHAVIOR_TOKEN_CLOSED` ✅
- [x] Unknown QC action → `BEHAVIOR_QC_UNKNOWN_ACTION` ✅

**Routing Guards:**
- [x] Route closed token → `DAG_TOKEN_CLOSED` ✅
- [x] Route non-existent token → `DAG_TOKEN_NOT_FOUND` ✅
- [x] Route token with no next node (not end) → `DAG_NO_NEXT_NODE` ✅
- [x] Route token at end node → `completed: true` ✅

**Error Format:**
- [x] All errors have `ok: false` ✅
- [x] All errors have `error` code ✅
- [x] All errors have `app_code` ✅
- [x] All errors have `message` ✅
- [x] HTTP status codes mapped correctly ✅

**Backward Compatibility:**
- [x] Valid operations return same success format ✅
- [x] Existing clients can ignore new error fields ✅
- [x] UI works without changes ✅

---

## Examples

### Example 1: Session Already Active

**Request:**
```json
{
  "behavior_code": "STITCH",
  "action": "stitch_start",
  "context": {
    "token_id": 123,
    "node_id": 10
  }
}
```

**Response (409 Conflict):**
```json
{
  "ok": false,
  "error": "BEHAVIOR_SESSION_ALREADY_ACTIVE",
  "app_code": "BEHAVIOR_409_SESSION_ALREADY_ACTIVE",
  "message": "Session already active for this token and worker",
  "behavior_code": "STITCH",
  "action": "stitch_start",
  "session_id": 456
}
```

### Example 2: Token Closed

**Request:**
```json
{
  "behavior_code": "STITCH",
  "action": "stitch_complete",
  "context": {
    "token_id": 123,
    "node_id": 10
  }
}
```

**Response (409 Conflict):**
```json
{
  "ok": false,
  "error": "BEHAVIOR_TOKEN_CLOSED",
  "app_code": "BEHAVIOR_409_TOKEN_CLOSED",
  "message": "Token is already closed (status: completed)",
  "behavior_code": "STITCH",
  "action": "stitch_complete",
  "token_status": "completed"
}
```

### Example 3: No Next Node (Graph Error)

**Request:**
```json
{
  "behavior_code": "STITCH",
  "action": "stitch_complete",
  "context": {
    "token_id": 123,
    "node_id": 10
  }
}
```

**Response (Success with Routing Failure):**
```json
{
  "ok": true,
  "effect": "stitch_completed_but_not_routed",
  "session_id": 456,
  "log_id": 789,
  "routing": {
    "moved": false,
    "error": "DAG_NO_NEXT_NODE",
    "app_code": "DAG_500_NO_NEXT_NODE",
    "message": "No next node found and current node is not an end node"
  }
}
```

### Example 4: Worker Mismatch

**Request:**
```json
{
  "behavior_code": "STITCH",
  "action": "stitch_pause",
  "context": {
    "token_id": 123,
    "node_id": 10
  }
}
```

**Response (403 Forbidden):**
```json
{
  "ok": false,
  "error": "BEHAVIOR_WORKER_MISMATCH",
  "app_code": "BEHAVIOR_403_WORKER_MISMATCH",
  "message": "Session belongs to different worker",
  "behavior_code": "STITCH",
  "action": "stitch_pause",
  "session_owner": 999
}
```

---

## Next Steps (Task 11+)

Task 10 is **Phase 2.5** (validation guards). The next tasks will:

1. **Task 11:** Enhanced session management
   - Auto-close active sessions before routing
   - Validate session completion before movement
   - Enhanced conflict resolution

2. **Task 12+:** Advanced features
   - Component binding validation
   - QC result tracking (prevent duplicate pass)
   - Batch split/merge validation

---

## Notes

- Phase 2.5 = Validation guards (prevent invalid operations)
- All existing behavior preserved
- Error responses enhanced (additive)
- No breaking changes
- Clear error messages for debugging
- HTTP status codes properly mapped
- Worker ownership validation implemented

---

**Task 10 Complete** ✅  
**Ready for Task 11: Enhanced Session Management**

