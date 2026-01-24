# Task 28.x - Production Readiness Checklist
**Date:** 2025-12-13  
**Status:** ✅ **READY FOR TESTING**  
**Audit Level:** Comprehensive Code Review

---

## Executive Summary

After comprehensive audit by multiple AI reviewers, **all P0 (Critical) bugs have been fixed**. Code is **safe for production testing** with some P1/P2 improvements recommended for future iterations.

---

## ✅ P0 Fixes Verified (All Critical Bugs Fixed)

### ✅ P0-1: Autosave Overwrite Draft Bug
- **Status:** FIXED ✅
- **Fix:** Force route to draft ONLY for manual structural saves, NOT autosave/node_update
- **Verification:** Logic explicitly excludes `$isAutosave` and `$isNodeUpdate`

### ✅ P0-2: JSON Decode Error Check
- **Status:** FIXED ✅
- **Fix:** Check `json_last_error()` after EACH decode separately
- **Verification:** Separate error tracking for nodes and edges

### ✅ P0-3: Cytoscape ID Leak to Database
- **Status:** FIXED ✅
- **Fix:** Only numeric DB IDs in `from_node_id`/`to_node_id`, use `*_node_code` as primary
- **Verification:** Explicit type checking and null assignment for non-numeric IDs

### ✅ P0-4: Published Graph Immutability
- **Status:** FIXED ✅
- **Fix:** Force route to draft when active draft exists, block saves to published/retired without draft
- **Verification:** Clear routing logic with proper guards

---

## ✅ P1 Fixes Completed

### ✅ P1-1: Autosave Payload Error Observability
- **Status:** FIXED ✅
- **Fix:** Added error logging and metrics for invalid autosave payloads
- **Impact:** Better debugging and monitoring capabilities

---

## 🟠 P1 Items Remaining (Not Blocking)

### P1-2: Normalization Logic Duplication
- **Status:** Known issue, in TODO
- **Impact:** Maintenance burden (not correctness)
- **Risk:** Low (logic works correctly, just duplicated)
- **Recommendation:** Extract to `GraphPayloadNormalizer` service (future refactor)

---

## 🟡 P2 Items (Nice-to-Have)

### P2-1: save_type Default Behavior
- **Status:** Working as designed (legacy fallback)
- **Impact:** UX clarity (should be handled by frontend)
- **Risk:** Low (backend logic is safe)
- **Recommendation:** Frontend should always send explicit `save_type`

### P2-2: node_update Not Implemented
- **Status:** Returns 501 (safe, no side effects)
- **Impact:** Feature incomplete (not a bug)
- **Risk:** None (explicit error, no silent failures)
- **Recommendation:** Implement when feature is needed

---

## ✅ Architecture Verification

| Aspect | Status | Notes |
|--------|--------|-------|
| **Correctness** | ✅ PASS | All logic flows verified |
| **Data Safety** | ✅ PASS | No silent data corruption risks |
| **Immortality** | ✅ PASS | Published/Retired graphs properly protected |
| **Draft Semantics** | ✅ PASS | Draft saves non-blocking, proper routing |
| **Observability** | ✅ PASS | Error logging and metrics in place |
| **Maintainability** | 🟡 GOOD | Normalization duplication noted (P1-2) |
| **UX Semantics** | 🟡 GOOD | Relies on FE discipline (P2-1) |

---

## ✅ Code Quality Verification

- [x] No syntax errors
- [x] No linter errors
- [x] No TODO comments in critical paths
- [x] All P0 bugs fixed
- [x] Error handling comprehensive
- [x] Metrics tracking added
- [x] Logging appropriate

---

## 🚫 What NOT to Change (Agent Guidelines)

**CRITICAL:** These items are working correctly. Do NOT modify unless explicitly requested:

1. **❌ DO NOT change autosave force-route logic**
   - Current guard `!$isAutosave && !$isNodeUpdate` is CORRECT
   - Changing this will reintroduce P0 draft data loss bug

2. **❌ DO NOT remove force-route to draft when `hasActiveDraft`**
   - This ensures published graphs with active draft save to draft table
   - Removing this will cause writes to main tables

3. **❌ DO NOT change JSON decode error checking**
   - Separate error tracking for nodes/edges is CORRECT
   - Combining checks will reintroduce P0 JSON decode bug

4. **❌ DO NOT allow publish via `graph_save`**
   - Current 501 block is CORRECT
   - Publish must use dedicated workflow

5. **❌ DO NOT change edge normalization (Cytoscape ID handling)**
   - Current logic (numeric IDs only, use node_code) is CORRECT
   - Changing this will reintroduce P0 Cytoscape ID leak bug

---

## ✅ Testing Requirements

### Required Tests Before Production

1. **Draft Save Routing:**
   - [ ] `graph_save_draft` forwards to `graph_save` correctly
   - [ ] Draft save with active draft saves to draft table
   - [ ] Draft save returns validation_warnings (not blocking)

2. **Autosave Protection:**
   - [ ] Autosave with active draft does NOT overwrite draft
   - [ ] Autosave with invalid payload logs warning
   - [ ] Autosave metrics tracked correctly

3. **Published Graph Immutability:**
   - [ ] Published graph without draft returns 403
   - [ ] Published graph with draft saves to draft (not main tables)
   - [ ] Retired graph follows same rules

4. **Publish Workflow:**
   - [ ] `save_type=publish` via `graph_save` returns 501
   - [ ] Proper publish endpoint works correctly

5. **Error Handling:**
   - [ ] JSON decode errors handled separately for nodes/edges
   - [ ] Invalid save_type returns 400
   - [ ] Version conflicts handled correctly

---

## 📊 Metrics to Monitor

After deployment, monitor these metrics:

- `dag_routing.autosave.payload_invalid` - Should be near zero
- `dag_routing.save_duration_ms` - Performance baseline
- `dag_routing.save.conflict_409` - Version conflict rate
- Error log entries for autosave payload issues

---

## ✅ Verdict

**Status:** ✅ **SAFE FOR PRODUCTION TESTING**

- All P0 (Critical) bugs fixed
- Data safety verified
- Architecture sound
- Remaining items are P1/P2 (improvements, not blockers)

**Recommendation:** Proceed with testing phase. Normalization refactor (P1-2) can be done in future iteration.

---

## Related Documents

- `SAVE_SEMANTICS_FIXES_COMPLETE.md` - Detailed fix documentation
- `SAVE_SEMANTICS_REFACTOR.md` - Original refactor plan
- `P0_P1_FIXES_ENTERPRISE.md` - Previous fixes
- `AUDIT_EXECUTIVE_SUMMARY.md` - Original audit findings

