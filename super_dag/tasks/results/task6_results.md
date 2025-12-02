# Task 6 Results — Token Engine Integration (Phase 1: Logging + Minimal Token Touch)

**Status:** ✅ **COMPLETED**  
**Date:** December 2025  
**Task:** [task6.md](task6.md)

---

## Summary

Task 6 successfully integrated Token Engine into behavior execution, replacing the stub endpoint from Task 5 with actual execution logic. The system now logs all behavior actions to `dag_behavior_log` table and performs minimal token status updates for STITCH behavior (keeping token as 'active').

---

## Deliverables

### 1. Database Migration

**File:** `database/tenant_migrations/2025_12_dag_behavior_log.php`

**Table:** `dag_behavior_log`

**Schema:**
- `id_log` (PK, auto increment)
- `id_token` (nullable int, FK to flow_token)
- `id_node` (nullable int, FK to routing_node)
- `behavior_code` (varchar 64, NOT NULL)
- `action` (varchar 64, NOT NULL)
- `source_page` (varchar 64, NOT NULL)
- `context_json` (text, nullable)
- `form_data_json` (text, nullable)
- `created_at` (datetime, default CURRENT_TIMESTAMP)
- `created_by` (nullable int)

**Indexes:**
- `idx_token` (id_token)
- `idx_node` (id_node)
- `idx_behavior_action` (behavior_code, action)
- `idx_source_page` (source_page)
- `idx_created_at` (created_at)

**Foreign Keys:**
- `id_token` → `flow_token(id_token)` ON DELETE SET NULL
- `id_node` → `routing_node(id_node)` ON DELETE SET NULL

---

### 2. Behavior Execution Service

**File:** `source/BGERP/Dag/BehaviorExecutionService.php`

**Class:** `BGERP\Dag\BehaviorExecutionService`

**Constructor:**
```php
public function __construct(mysqli $db, array $org)
```

**Main Method:**
```php
public function execute(
    string $behaviorCode,
    string $sourcePage,
    string $action,
    array $context = [],
    array $formData = []
): array
```

**Behavior Handlers:**

1. **STITCH** (`handleStitch()`)
   - `stitch_start` → Ensures token status is 'active' (logs + minimal token touch)
   - `stitch_pause` → Logs only (pause handled by session, token stays 'active')
   - `stitch_resume` → Ensures token status is 'active' (logs + minimal token touch)
   - Returns: `['ok' => true, 'effect' => 'token_status_updated' | 'logged_only']`

2. **CUT** (`handleCut()`)
   - `cut_save_batch` → Logs only (no token status change)
   - Returns: `['ok' => true, 'effect' => 'logged_only']`

3. **EDGE** (`handleEdge()`)
   - `edge_update` → Logs only (no token status change)
   - Returns: `['ok' => true, 'effect' => 'logged_only']`

4. **QC_SINGLE / QC_FINAL** (`handleQc()`)
   - `qc_pass` → Logs only (no token status change)
   - `qc_send_back` → Logs only (no token status change)
   - Returns: `['ok' => true, 'effect' => 'logged_only']`

**Token Status Updates:**

- **STITCH start/resume:** Updates `flow_token.status = 'active'` (if token exists and is already 'active')
- **STITCH pause:** No token status change (pause is handled by `token_work_session`)
- **Other behaviors:** Log only, no token status changes

**Important Notes:**
- Token status in `flow_token` is ENUM('active','completed','scrapped')
- We only update status to 'active' (never to 'IN_PROGRESS' or 'PAUSED' as those don't exist in enum)
- Pause/resume is managed by `token_work_session` table, not `flow_token.status`

---

### 3. API Integration

**File:** `source/dag_behavior_exec.php`

**Changes:**
- Added `use BGERP\Dag\BehaviorExecutionService;`
- Replaced stub response with actual execution logic
- Calls `BehaviorExecutionService::execute()` with validated payload
- Handles execution errors with proper HTTP codes and app codes
- Returns execution result with `effect` field

**Flow:**
```php
// Validate payload
$validator = new RequestValidator();
$behaviorCode = $validator->string(...);
$sourcePage = $validator->string(...);
$action = $validator->string(...);

// Execute behavior
$executionService = new BehaviorExecutionService($tenantDb, $org);
$result = $executionService->execute($behaviorCode, $sourcePage, $action, $context, $formData);

// Handle result
if ($result['ok'] !== true) {
    TenantApiOutput::error(...);
} else {
    TenantApiOutput::success([
        'received' => true,
        'effect' => $result['effect'] ?? 'none',
        'log_id' => $result['log_id'] ?? null
    ]);
}
```

**Error Handling:**
- Validation errors → HTTP 400 with `DAG_BEHAVIOR_400_EXEC_FAILED`
- Execution errors → HTTP 400 with error details
- Unexpected exceptions → HTTP 500 with `DAG_BEHAVIOR_500_INTERNAL`
- All errors logged to error_log

---

## Behavior → Action → Effect Mapping

### STITCH
| Action | Token Status Update | Effect |
|--------|---------------------|--------|
| `stitch_start` | Ensures `status = 'active'` | `token_status_updated` or `logged_only` |
| `stitch_pause` | No change (handled by session) | `logged_only` |
| `stitch_resume` | Ensures `status = 'active'` | `token_status_updated` or `logged_only` |

### CUT
| Action | Token Status Update | Effect |
|--------|---------------------|--------|
| `cut_save_batch` | No change | `logged_only` |

### EDGE
| Action | Token Status Update | Effect |
|--------|---------------------|--------|
| `edge_update` | No change | `logged_only` |

### QC_SINGLE / QC_FINAL
| Action | Token Status Update | Effect |
|--------|---------------------|--------|
| `qc_pass` | No change | `logged_only` |
| `qc_send_back` | No change | `logged_only` |

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
1. Validate context (requires `token_id`)
2. Log to `dag_behavior_log` table
3. Update `flow_token.status = 'active'` (if token exists and is 'active')
4. Return: `{ok: true, effect: 'token_status_updated', log_id: 1}`

**Database Changes:**
- `dag_behavior_log`: 1 new row
- `flow_token`: Status updated to 'active' (if needed)

### CUT Save Batch Request
```json
{
  "behavior_code": "CUT",
  "source_page": "pwa_scan",
  "action": "cut_save_batch",
  "context": {
    "token_id": 124,
    "node_id": 457
  },
  "form_data": {
    "qty_produced": 10,
    "qty_scrapped": 1,
    "reason": "Material defect",
    "leather_lot": "LOT-2025-001"
  }
}
```

**Execution:**
1. Validate context (token_id optional for CUT)
2. Log to `dag_behavior_log` table
3. No token status change
4. Return: `{ok: true, effect: 'logged_only', log_id: 2}`

**Database Changes:**
- `dag_behavior_log`: 1 new row
- `flow_token`: No changes

---

## Safety Rails Verification

✅ **No Time Engine Changes**
- No modifications to `TokenWorkSessionService`
- No modifications to `WorkSessionTimeEngine`
- No modifications to time tracking logic

✅ **No DAG Routing Logic Changes**
- No token movement between nodes
- No changes to `current_node_id`
- No routing graph modifications

✅ **No Behavior UI Changes**
- `behavior_ui_templates.js` unchanged
- Frontend payload structure unchanged
- No breaking changes to existing UI

✅ **Error Handling**
- All exceptions caught and logged
- Proper HTTP status codes returned
- User-friendly error messages

✅ **Backward Compatible**
- Existing behavior panels still work
- Handlers are optional (no error if missing)
- Graceful degradation if `dag_behavior_log` table doesn't exist

---

## Testing Status

### PHP Syntax Check
```bash
$ php -l source/BGERP/Dag/BehaviorExecutionService.php
No syntax errors detected in source/BGERP/Dag/BehaviorExecutionService.php

$ php -l source/dag_behavior_exec.php
No syntax errors detected in source/dag_behavior_exec.php
```

✅ **All PHP files pass syntax check**

### Manual Testing Checklist

- [x] PHP syntax check: Both files pass ✅
- [x] Migration: `dag_behavior_log` table created successfully
- [x] STITCH start: Logs entry and updates token status (if needed)
- [x] STITCH pause: Logs entry only (no token status change)
- [x] STITCH resume: Logs entry and updates token status (if needed)
- [x] CUT save batch: Logs entry only
- [x] EDGE update: Logs entry only
- [x] QC pass: Logs entry only
- [x] QC send back: Logs entry only
- [x] Error handling: Missing token_id returns proper error
- [x] Error handling: Unsupported behavior returns proper error
- [x] Response format: Includes `effect` and `log_id` fields

### Database Verification

**Check log entries:**
```sql
SELECT * FROM dag_behavior_log 
ORDER BY created_at DESC 
LIMIT 10;
```

**Check token status updates:**
```sql
SELECT id_token, status, updated_at 
FROM flow_token 
WHERE id_token IN (123, 124, ...)
ORDER BY updated_at DESC;
```

---

## Files Modified

### New Files (2)
- `source/BGERP/Dag/BehaviorExecutionService.php` (350+ lines)
- `database/tenant_migrations/2025_12_dag_behavior_log.php` (60+ lines)

### Modified Files (1)
- `source/dag_behavior_exec.php` - Integrated `BehaviorExecutionService` (replaced stub)

### Documentation (2)
- `docs/super_dag/tasks/task6_results.md` (this file)
- `docs/super_dag/task_index.md` (updated)

---

## Implementation Details

### Token Status Logic

**Important:** `flow_token.status` is ENUM('active','completed','scrapped'), not 'IN_PROGRESS' or 'PAUSED'.

**STITCH Behavior:**
- `stitch_start` / `stitch_resume`: Ensures token is 'active' (doesn't change if already 'active')
- `stitch_pause`: No token status change (pause is handled by `token_work_session.status = 'paused'`)

**Why this approach:**
- Token status represents lifecycle (active/completed/scrapped)
- Session status represents work state (active/paused/completed)
- Pause/resume is a session-level concept, not token-level

### Logging Logic

**Table Check:**
- Service checks if `dag_behavior_log` table exists before inserting
- If table doesn't exist, logs to error_log instead (graceful degradation)
- No exceptions thrown if table is missing

**JSON Storage:**
- `context_json`: Full context object as JSON
- `form_data_json`: Full form data object as JSON
- Both nullable (can be NULL if empty)

### Error Handling

**Validation Errors:**
- Missing `token_id` for STITCH → `['ok' => false, 'error' => 'missing_token_id']`
- Unsupported behavior → `['ok' => false, 'error' => 'unsupported_behavior']`

**Execution Errors:**
- Caught by try-catch in `execute()`
- Logged to error_log
- Returned as `['ok' => false, 'error' => 'execution_failed']`

**API Errors:**
- HTTP 400 for validation/execution errors
- HTTP 500 for unexpected exceptions
- All errors include `app_code` for client handling

---

## Next Steps (Task 7+)

Task 6 is **Phase 1** of Token Engine integration. The next tasks will:

1. **Task 7:** Time Engine integration (work timer start/pause/resume)
2. **Task 8:** DAG Execution Logic (token movement between nodes)
3. **Task 9:** Behavior-specific execution logic (CUT batch processing, QC state transitions, etc.)
4. **Task 10:** Validation and business rules per behavior

---

## Notes

- Token status updates are minimal (only for STITCH start/resume)
- All other behaviors are log-only for now
- Service gracefully handles missing `dag_behavior_log` table
- Error handling is comprehensive with proper logging
- No breaking changes to existing systems
- Ready for Task 7: Time Engine Integration

---

**Task 6 Complete** ✅  
**Ready for Task 7: Time Engine Integration**

