# Task 11 – Work Queue Start & Details Patch - Implementation Summary

**Date:** December 2025  
**Status:** ✅ **COMPLETE**  
**Task:** docs/dag/agent-tasks/task11.md

---

## 📋 Executive Summary

Fixed two critical issues in the Work Queue UI:
1. **Start Token Logic:** Tokens with status `'ready'` can now be started (previously only `'active'` was allowed)
2. **Details Section:** Restored missing fields in "รายละเอียดเพิ่มเติม" (details section) including serial numbers, notes, due dates, and product names
3. **Token Visibility:** Fixed token disappearing after start by including `'active'` and `'paused'` tokens in work queue

**Key Achievement:**
- ✅ Token status `'ready'` can be started from Work Queue
- ✅ Work Queue shows tokens that are currently being worked on (active/paused)
- ✅ Details section displays complete information (notes, due_date, product_name, serial numbers)
- ✅ No UI layout or styling changes (only logic and data mapping)

---

## 1. Part A: Fix Start Token Logic

### Problem
When clicking "เริ่ม" (Start) button on a token with status `'ready'` in Work Queue, the system returned error:
```json
{
  "ok": false,
  "error": "Token not available (status: ready)",
  "app_code": "DAG_400_START_FAILED"
}
```

### Root Cause
`TokenWorkSessionService::checkTokenLock()` only allowed tokens with status `'active'` to be started, but Work Queue UI shows `'ready'` tokens as available to start.

### Solution

**File:** `source/BGERP/Service/TokenWorkSessionService.php`

**Changes:**
- Modified `checkTokenLock()` method (lines 480-485) to accept both `'ready'` and `'active'` statuses
- Added comment explaining Work Queue UI requirement

**Code:**
```php
// TASK11: Allow 'ready' status to start (Work Queue UI requirement)
// Token can be started if status is 'ready' (assigned and ready to work) or 'active' (resuming)
$allowedStatuses = ['ready', 'active'];
if (!in_array($token['status'], $allowedStatuses, true)) {
    throw new Exception('Token not available (status: ' . $token['status'] . ')');
}
```

### Result
- ✅ Tokens with status `'ready'` can now be started successfully
- ✅ Tokens with status `'active'` can still be resumed (existing behavior preserved)
- ✅ Invalid statuses (scrapped, completed, etc.) are still blocked with `DAG_400_START_FAILED`

---

## 2. Part B: Restore "รายละเอียดเพิ่มเติม" Content

### Problem
The "รายละเอียดเพิ่มเติม" (details section) in Work Queue cards was empty, even though it previously displayed:
- Serial numbers
- Job code / order number
- Notes
- Due dates

### Root Cause
The `get_work_queue` API response was missing required fields that the frontend expected:
- `notes` (from `job_ticket.notes`)
- `due_date` (from `job_ticket.due_date` or `mo.scheduled_end_date`)
- `product_name` (from `product.name`)
- `job_ticket_id` (for grouping tokens by job)

### Solution

**File:** `source/dag_token_api.php`

**Changes:**

1. **Added fields to SQL SELECT (lines 1763-1767):**
   ```sql
   gi.id_job_ticket,
   jt.notes as job_notes,
   jt.due_date as job_due_date,
   mo.scheduled_end_date as mo_due_date,
   p.name as product_name,
   ```

2. **Added fields to tokenData response (lines 2038-2041):**
   ```php
   'job_ticket_id' => $token['id_job_ticket'] ?? null,
   'product_name' => $token['product_name'] ?? null,
   'notes' => $token['job_notes'] ?? null,
   'due_date' => $dueDate, // Prefer job_due_date, fallback to mo_due_date
   ```

### Result
- ✅ Details section now displays:
  - Serial numbers (existing)
  - Due date (from job_ticket or MO)
  - Notes (from job_ticket)
  - Product name
  - Assigned to (existing)
- ✅ Works in both Desktop (Kanban/List) and Mobile views
- ✅ No UI layout changes (only data mapping)

---

## 3. Part C: Fix Token Visibility After Start

### Problem
After clicking "เริ่ม" (Start), the token disappeared from Work Queue because the API only returned tokens with status `'ready'`.

### Root Cause
`handleGetWorkQueue()` filtered only `t.status = 'ready'`, so tokens that changed to `'active'` or `'paused'` were excluded.

### Solution

**File:** `source/dag_token_api.php`

**Changes:**

1. **Updated WHERE clause (lines 1810-1821):**
   ```sql
   WHERE 
     -- TASK11: Include 'ready', 'active', and 'paused' tokens (operator's work queue)
     -- Show tokens that are ready to start OR currently being worked on by this operator
     (
       t.status = 'ready'  -- Ready tokens (available to start)
       OR (t.status IN ('active', 'paused') AND s.operator_user_id = ?)  -- Active/paused tokens that belong to this operator
     )
   ```

2. **Updated parameter binding (lines 1829-1831):**
   ```php
   // TASK11: operatorId already used in WHERE clause (s.operator_user_id = ?)
   $params = [$operatorId]; // First param for WHERE clause
   $types = 'i';
   ```

### Result
- ✅ Tokens that are started (status = 'active') remain visible in Work Queue
- ✅ Tokens that are paused (status = 'paused') remain visible in Work Queue
- ✅ Only shows tokens belonging to the current operator (not other operators' active work)
- ✅ Ready tokens still appear as before

---

## 4. Files Modified

### Backend:
1. **`source/BGERP/Service/TokenWorkSessionService.php`**
   - Lines 480-485: Allow `'ready'` status to start

2. **`source/dag_token_api.php`**
   - Lines 1763-1767: Added fields to SQL SELECT
   - Lines 1810-1821: Updated WHERE clause to include active/paused tokens
   - Lines 1829-1831: Updated parameter binding
   - Lines 2038-2041: Added fields to tokenData response

### No Frontend Changes:
- Frontend already expected these fields
- No JavaScript or HTML changes required

---

## 5. Testing

### Manual Verification:
1. ✅ Open Work Queue
2. ✅ Click "เริ่ม" on a token with status `'ready'` → Should succeed (no error)
3. ✅ Token should remain visible after start (status changes to `'active'`)
4. ✅ Click "รายละเอียดเพิ่มเติม" → Should show notes, due_date, product_name
5. ✅ Pause a token → Should remain visible with paused status
6. ✅ Resume a token → Should remain visible with active status

### Edge Cases:
- ✅ Tokens with invalid status (scrapped, completed) are still blocked
- ✅ Tokens assigned to other operators don't appear in "My Work"
- ✅ Empty details section when no data exists (graceful handling)

---

## 6. Acceptance Criteria Met

✅ **Start Token Logic:**
- Token with status `'ready'` and assigned to current member can be started
- No error "Token not available (status: ready)"
- Invalid statuses still blocked with `DAG_400_START_FAILED`

✅ **Work Queue Details:**
- "รายละเอียดเพิ่มเติม" displays complete information
- Uses fields that UI expects (notes, due_date, product_name)
- Works in Desktop and Mobile views

✅ **UI Stable:**
- No layout or styling changes
- Buttons, headers, cards remain in same position
- Only content restored (not restructured)

---

## 7. Related Tasks

- **Task 11.1:** Work Queue UI Smoothing (Loading State & Flicker Fix) - Follow-up task to improve UX

---

## 8. Notes

- All changes are backward compatible
- No database schema changes
- No breaking changes to API response format (only added fields)
- Soft mode preserved (failures don't block operations)

---

**Last Updated:** December 2025  
**Status:** ✅ Complete

