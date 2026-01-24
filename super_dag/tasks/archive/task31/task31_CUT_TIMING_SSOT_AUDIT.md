# Task 31: CUT Timing SSOT Audit & Refactor

**Date:** 2026-01-11  
**Status:** 🔴 **CRITICAL REFACTOR REQUIRED**

---

## 🎯 Problem Statement

CUT behavior currently has **TWO timing systems** running in parallel:

1. **Legacy TokenWorkSessionService** (batch-level, averaged)
   - Used by `cut_start` / `cut_complete` actions
   - Creates `token_work_session` records
   - Duration is averaged across batch

2. **CutSessionService** (component-level, SSOT)
   - Used by `cut_session_start` / `cut_session_end` actions
   - Creates `cut_session` records
   - Duration is per component + role + material

**This is INVALID.** CutSessionService must be the **SINGLE SOURCE OF TRUTH (SSOT)** for CUT timing.

---

## 📋 Audit Results

### A) Legacy Timing Usage in CUT

#### 1. `handleCutStart()` (Line 1766)
- **File:** `source/BGERP/Dag/BehaviorExecutionService.php`
- **Issue:** Uses `getSessionService()` → `DagTokenWorkSessionService` (legacy)
- **Action:** `cut_start` → Creates legacy `token_work_session`
- **Status:** ❌ **MUST DEPRECATE**

#### 2. `handleCutComplete()` (Line 1832)
- **File:** `source/BGERP/Dag/BehaviorExecutionService.php`
- **Issue:** Uses `TokenWorkSessionService::completeToken()` (line 1853-1854)
- **Action:** `cut_complete` → Completes legacy session
- **Status:** ❌ **MUST DEPRECATE**

#### 3. `handleCutBatchYieldSave()` (Line 841)
- **File:** `source/BGERP/Dag/BehaviorExecutionService.php`
- **Issue:** Accepts `started_at`, `finished_at`, `duration_seconds` from UI (line 870-872)
- **Problem:** UI-provided timing is NON-TRUSTED; should come from CutSession
- **Status:** ⚠️ **MUST REFACTOR** - Require `session_id`, derive timing from CutSession

---

### B) Correct Implementation (CutSessionService)

#### ✅ `handleCutSessionEnd()` (Line 4097)
- **File:** `source/BGERP/Dag/BehaviorExecutionService.php`
- **Status:** ✅ **CORRECT**
- **Behavior:** 
  - Ends CutSession via `CutSessionService::endSession()`
  - Creates NODE_YIELD event with timing from `cut_session` table (SSOT)
  - Timing fields: `started_at`, `ended_at`, `duration_seconds` from session record

---

## 🔧 Refactoring Plan

### Phase 1: Deprecate Legacy Actions

**Actions:**
- `cut_start` → Return error directing to `cut_session_start`
- `cut_complete` → Return error directing to `cut_session_end`

**Rationale:** Legacy actions create `token_work_session` which is NOT SSOT for CUT.

---

### Phase 2: Refactor `cut_batch_yield_save`

**Current Behavior:**
- Accepts UI-provided `started_at`, `finished_at`, `duration_seconds`
- Creates NODE_YIELD event with non-trusted timing

**Required Behavior:**
- **REQUIRE** `session_id` parameter
- Load CutSession by `session_id`
- **REJECT** UI-provided timing (ignore `started_at`, `finished_at`, `duration_seconds` from formData)
- Derive timing from CutSession record (SSOT)
- Create NODE_YIELD event with authoritative timing

**Backward Compatibility:**
- If `session_id` not provided → Return error with clear message
- If CutSession not found → Return 404
- If CutSession status != ENDED → Return error (session must be ended first)

---

### Phase 3: Frontend Contract Update

**Current:**
- Frontend calls `cut_session_end` (✅ correct)
- `cut_session_end` creates NODE_YIELD event (✅ correct)

**No changes needed** - Frontend already uses correct path.

**Note:** `buildCutPayload()` function exists but appears unused. Verify and remove if dead code.

---

## 📝 Documentation Requirements

### 1. CutSessionService Class Header
Add warning:
```php
/**
 * ⚠️ CRITICAL: This is the SINGLE SOURCE OF TRUTH (SSOT) for CUT timing.
 * 
 * DO NOT use TokenWorkSessionService for CUT operations.
 * DO NOT accept UI-provided timing values.
 * DO NOT create NODE_YIELD events without referencing an active CutSession.
 * 
 * Legacy TokenWorkSessionService is for other behaviors (STITCH, QC, etc.)
 * and is NOT authoritative for CUT timing.
 */
```

### 2. BehaviorExecutionService::handleCut()
Add warning:
```php
/**
 * ⚠️ CUT Timing Policy:
 * 
 * - cut_start / cut_complete: DEPRECATED (use cut_session_start / cut_session_end)
 * - cut_batch_yield_save: MUST reference CutSession (require session_id)
 * - All timing MUST come from CutSessionService, NOT UI or legacy TokenWorkSessionService
 */
```

### 3. Developer Guide
Create: `docs/super_dag/tasks/archive/task31/task31_CUT_TIMING_SSOT_POLICY.md`

---

## ✅ Success Criteria

After refactoring:
- [ ] `cut_start` / `cut_complete` return deprecation error
- [ ] `cut_batch_yield_save` requires `session_id` and rejects UI timing
- [ ] All NODE_YIELD events for CUT have timing from CutSession (SSOT)
- [ ] No `token_work_session` records created for CUT operations
- [ ] Documentation clearly states CutSession is SSOT
- [ ] Warnings added to prevent future misuse

---

## 🚫 Non-Goals

- Do NOT redesign CUT UX
- Do NOT introduce per-piece time tracking
- Do NOT normalize data across other behaviors
- Do NOT "average" time
- Do NOT silently keep two time sources
