# Task 31: CUT Timing SSOT Policy

**Date:** 2026-01-11  
**Status:** ✅ **ENFORCED**

---

## 🎯 Policy Statement

**CutSessionService is the SINGLE SOURCE OF TRUTH (SSOT) for CUT timing.**

Legacy TokenWorkSessionService is **NOT authoritative** for CUT operations and must not be used.

---

## ⚠️ Critical Rules

### 1. CUT Timing MUST Come from CutSession

- ✅ **Use:** `CutSessionService` → `cut_session` table
- ❌ **DO NOT use:** `TokenWorkSessionService` → `token_work_session` table

### 2. UI-Provided Timing is NON-TRUSTED

- ✅ **Accept:** `session_id` → Load CutSession → Use `started_at`, `ended_at`, `duration_seconds` from session
- ❌ **REJECT:** `started_at`, `finished_at`, `duration_seconds` from UI/formData

### 3. Required Actions for CUT

- ✅ **Start:** `cut_session_start` (creates CutSession)
- ✅ **End:** `cut_session_end` (ends CutSession, creates NODE_YIELD with SSOT timing)
- ❌ **DEPRECATED:** `cut_start`, `cut_complete` (return deprecation error)

### 4. NODE_YIELD Event Contract

When creating NODE_YIELD events for CUT:
- **MUST** reference a CutSession (`session_id` in payload)
- **MUST** use timing from CutSession (`started_at`, `ended_at`, `duration_seconds`)
- **MUST NOT** accept UI-provided timing

---

## 📋 Implementation Details

### CutSession Lifecycle

1. **Start:** `cut_session_start`
   - Creates `cut_session` record with `status = RUNNING`
   - `started_at` = server time (SSOT)
   - Identity: `component_code + role_code + material_sku`

2. **Pause/Resume:** `cut_session_pause` / `cut_session_resume`
   - Updates `paused_at`, `resumed_at`, `paused_total_seconds`
   - Server-computed (SSOT)

3. **End:** `cut_session_end`
   - Sets `status = ENDED`
   - `ended_at` = server time (SSOT)
   - Computes `duration_seconds = ended_at - started_at - paused_total_seconds` (SSOT)
   - Creates NODE_YIELD event with timing from session

### Legacy Actions (DEPRECATED)

- `cut_start` → Returns error directing to `cut_session_start`
- `cut_complete` → Returns error directing to `cut_session_end`
- `cut_batch_yield_save` → **REQUIRES** `session_id`, derives timing from CutSession

---

## 🚫 What NOT to Do

1. ❌ **DO NOT** call `TokenWorkSessionService::startSession()` for CUT
2. ❌ **DO NOT** call `TokenWorkSessionService::completeToken()` for CUT
3. ❌ **DO NOT** accept `started_at`/`finished_at`/`duration_seconds` from UI
4. ❌ **DO NOT** create NODE_YIELD events without `session_id`
5. ❌ **DO NOT** use `token_work_session` records for CUT timing reports

---

## ✅ What TO Do

1. ✅ **DO** use `CutSessionService::startSession()` for CUT
2. ✅ **DO** use `CutSessionService::endSession()` for CUT
3. ✅ **DO** require `session_id` in `cut_batch_yield_save`
4. ✅ **DO** load CutSession and use timing from session record
5. ✅ **DO** reference `cut_session` table for CUT timing reports

---

## 📊 Data Flow

```
User Action → cut_session_start
  ↓
CutSession created (status=RUNNING, started_at=server_time)
  ↓
User works (timer displays, but NOT authoritative)
  ↓
User saves → cut_session_end
  ↓
CutSession updated (status=ENDED, ended_at=server_time, duration_seconds=computed)
  ↓
NODE_YIELD event created (timing from CutSession, SSOT)
```

---

## 🔍 Verification

To verify SSOT is enforced:

1. Check `cut_session` table has records for all CUT operations
2. Check `NODE_YIELD` events have `session_id` in payload
3. Check `NODE_YIELD` events have timing from `cut_session` (not UI)
4. Verify no `token_work_session` records created for CUT (after migration)

---

## 📝 For Future Developers

If you need to:
- **Add timing to CUT:** Use CutSessionService, NOT TokenWorkSessionService
- **Query CUT timing:** Query `cut_session` table, NOT `token_work_session`
- **Create CUT events:** Reference CutSession, NOT legacy session

**Remember:** CutSession is SSOT. Legacy timing is invalid for CUT.
