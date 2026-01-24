# Risk Assessment: Task 27.26 DAG Routing API & JS Refactor

**Date:** 2025-12-09
**Task:** Task 27.26 - DAG Routing API & JS Refactor
**Status:** ⚠️ **HIGH RISK** - Requires careful planning
**Risk Level:** 🔴 **CRITICAL** (Core Production System)

---

## 📊 Executive Summary

| Category | Risk Count | Critical | High | Medium | Low |
|----------|------------|----------|------|--------|-----|
| **Quick Wins** | 6 | 0 | 1 | 2 | 3 |
| **PHP Refactor** | 8 | 2 | 3 | 2 | 1 |
| **JS Refactor** | 7 | 1 | 2 | 3 | 1 |
| **Legacy Removal** | 5 | 1 | 2 | 1 | 1 |
| **Permission System** | 4 | 1 | 1 | 1 | 1 |
| **Frontend Impact** | 3 | 1 | 1 | 1 | 0 |
| **Data Integrity** | 3 | 1 | 1 | 1 | 0 |
| **Total** | **36** | **7** | **11** | **11** | **7** |

---

## 🔴 CRITICAL RISKS (P1 - Must Address)

### 1. Breaking Frontend API Calls

| Risk ID | RISK-001 |
|---------|----------|
| **Description** | Frontend calls `dag_routing_api.php?action=xxx` - if we split files, URLs break |
| **Impact** | 🔴 **CRITICAL** - Entire DAG Designer stops working |
| **Probability** | High (100% if not handled) |
| **Severity** | Production outage |
| **Affected Systems** | DAG Designer, Graph Viewer, Product Graph Binding |

**Mitigation:**
- ✅ Keep `dag_routing_api.php` as thin router (backward compatibility)
- ✅ Router forwards to new files internally
- ✅ No frontend URL changes required
- ⚠️ **MUST TEST:** All 40 actions work through router

**Verification:**
- [ ] Test all actions via original URL
- [ ] Test all actions via new URLs (if exposed)
- [ ] Monitor error_log for 404s

---

### 2. Permission System Regression

| Risk ID | RISK-002 |
|---------|----------|
| **Description** | Legacy `hatthasilpa.routing.*` permissions still in use - removing fallback breaks access |
| **Impact** | 🔴 **CRITICAL** - Users lose access to DAG features |
| **Probability** | Medium (if removed too early) |
| **Severity** | Access denied for existing users |
| **Affected Users** | All users with legacy permissions |

**Current State:**
- Legacy permissions: 10 occurrences
- Fallback logic: `must_allow_routing()` function
- Database: Unknown how many users have legacy codes

**Mitigation:**
- ⚠️ **DO NOT REMOVE** fallback until migration complete
- ✅ Add logging to track legacy permission usage
- ✅ Create migration script to rename permissions in DB
- ✅ Monitor error_log for permission denials

**Timeline:**
- Q1 2026: Monitor usage
- Q2 2026: Migrate permissions in DB
- Q3 2026: Remove fallback (after 0 usage for 30 days)

---

### 3. Validation Logic Regression

| Risk ID | RISK-003 |
|---------|----------|
| **Description** | `GraphValidationEngine` used in 4 places - refactoring might break validation |
| **Impact** | 🔴 **CRITICAL** - Invalid graphs saved, production errors |
| **Probability** | Medium (if refactor incorrect) |
| **Severity** | Data corruption, invalid graphs in production |
| **Affected Operations** | Graph save, draft save, validation action |

**Current State:**
- Validation engine instantiated 4 times (duplicate)
- Used in: `graph_save`, `save_draft`, `validate`, another location
- Single source of truth: `GraphValidationEngine` class

**Mitigation:**
- ✅ Extract to helper function (same behavior, just DRY)
- ✅ Write integration tests for validation
- ✅ Test with invalid graphs (should reject)
- ✅ Test with valid graphs (should accept)

**Verification:**
- [ ] All validation rules work identically
- [ ] Error messages unchanged
- [ ] Invalid graphs still rejected

---

### 4. Legacy Timer Variables Removal

| Risk ID | RISK-004 |
|---------|----------|
| **Description** | `autoSaveTimer` and `pendingReloadTimer` still referenced 11 times - removing breaks timers |
| **Impact** | 🔴 **CRITICAL** - AutoSave and reload timers stop working |
| **Probability** | High (if removed without refactor) |
| **Severity** | Data loss (unsaved changes), broken reload logic |
| **Affected Features** | AutoSave, Graph reload, Timer management |

**Current State:**
- `autoSaveTimer`: 8 references
- `pendingReloadTimer`: 3 references
- `TimerManager` exists but legacy vars still used

**Mitigation:**
- ❌ **DO NOT REMOVE** until refactored
- ✅ Replace all references with `TimerManager.isActive()`
- ✅ Replace all assignments with `TimerManager.set()`
- ✅ Test autoSave works after refactor

**Required Steps:**
1. Replace `if (autoSaveTimer)` → `if (TimerManager.isActive('autoSave'))`
2. Replace `clearTimeout(autoSaveTimer)` → `TimerManager.clear('autoSave')`
3. Remove variable declarations last

---

### 5. Deprecated Actions Still In Use

| Risk ID | RISK-005 |
|---------|----------|
| **Description** | `graph_view` and `graph_by_code` marked deprecated but might still be called |
| **Impact** | 🔴 **CRITICAL** - Features break if removed too early |
| **Probability** | Low (but catastrophic if happens) |
| **Severity** | Features stop working |
| **Affected Actions** | `graph_view`, `graph_by_code` |

**Current State:**
- `graph_view`: Returns 410, logs usage
- `graph_by_code`: Returns 410, logs usage
- Frontend: `dag_graph_view` is page (not API), safe

**Mitigation:**
- ⚠️ **CHECK ERROR LOG** for 7-30 days before removal
- ✅ Already logging all calls
- ✅ Return 410 (Gone) instead of 404 (Not Found)
- ✅ Provide alternatives in error message

**Verification:**
- [ ] Check error_log for `[dag_routing_api] DEPRECATED action` entries
- [ ] If 0 entries for 30 days → Safe to remove
- [ ] If entries found → Investigate source

---

### 6. Node/Edge Properties Editor Extraction

| Risk ID | RISK-006 |
|---------|----------|
| **Description** | Extracting 1,500+ lines of nested functions might break property editing |
| **Impact** | 🔴 **CRITICAL** - Cannot edit node/edge properties |
| **Probability** | Medium (complex nested logic) |
| **Severity** | Core feature broken |
| **Affected Features** | Node properties panel, Edge properties panel |

**Current State:**
- `showNodeProperties()`: ~1,500 lines with 30+ nested functions
- `showEdgeProperties()`: ~800 lines with nested functions
- Complex state management, form validation, UI updates

**Mitigation:**
- ✅ Extract incrementally (one function at a time)
- ✅ Test after each extraction
- ✅ Keep same function signatures
- ✅ Preserve all event handlers

**Verification:**
- [ ] All node types editable
- [ ] All edge types editable
- [ ] Form validation works
- [ ] Save operations work

---

### 7. Data Integrity During Refactor

| Risk ID | RISK-007 |
|---------|----------|
| **Description** | Large refactor might introduce bugs that corrupt graph data |
| **Impact** | 🔴 **CRITICAL** - Production graphs corrupted |
| **Probability** | Low (but catastrophic) |
| **Severity** | Data loss, production outage |
| **Affected Data** | All routing graphs, node data, edge data |

**Mitigation:**
- ✅ Use database transactions for all writes
- ✅ Write integration tests before refactor
- ✅ Test with production-like data
- ✅ Backup database before major changes
- ✅ Rollback plan ready

**Verification:**
- [ ] All CRUD operations tested
- [ ] Graph structure preserved
- [ ] Node/edge relationships intact
- [ ] Version history preserved

---

## 🟠 HIGH RISKS (P2 - Should Address)

### 8. Duplicate Error Handling Consolidation

| Risk ID | RISK-008 |
|---------|----------|
| **Description** | Extracting `rejectLegacyWorkCenterId()` might change error format |
| **Impact** | 🟠 **HIGH** - Frontend error handling breaks |
| **Probability** | Low (if done correctly) |
| **Severity** | Error messages not displayed correctly |
| **Affected Features** | Node creation, Node update error handling |

**Mitigation:**
- ✅ Keep exact same error format
- ✅ Test error messages match
- ✅ Test frontend error handling

---

### 9. Legacy Node Type UI Removal

| Risk ID | RISK-009 |
|---------|----------|
| **Description** | Removing ~500 lines of legacy node UI might break loading old graphs |
| **Impact** | 🟠 **HIGH** - Old graphs cannot be viewed/edited |
| **Probability** | Medium (if graphs still use legacy types) |
| **Severity** | Cannot access historical graphs |
| **Affected Data** | Graphs with `split`, `join`, `decision`, `wait` nodes |

**Mitigation:**
- ⚠️ **DO NOT REMOVE** until all graphs migrated
- ✅ Check database for graphs using legacy types
- ✅ Provide migration path for old graphs
- ✅ Keep read-only support for legacy types

**Timeline:**
- Q1 2026: Audit database for legacy node usage
- Q2 2026: Migrate or mark as read-only
- Q3 2026: Remove UI code (if 0 legacy graphs)

---

### 10. Permission Fallback Removal

| Risk ID | RISK-010 |
|---------|----------|
| **Description** | Removing `hatthasilpa.routing.*` fallback breaks users with legacy permissions |
| **Impact** | 🟠 **HIGH** - Users lose access |
| **Probability** | High (if removed before migration) |
| **Severity** | Access denied |
| **Affected Users** | Unknown count |

**Mitigation:**
- ⚠️ **DO NOT REMOVE** until DB migration complete
- ✅ Audit database for legacy permission assignments
- ✅ Create migration script
- ✅ Test with users having legacy permissions

---

### 11. Form Serializer Introduction

| Risk ID | RISK-011 |
|---------|----------|
| **Description** | Creating form serializer might miss edge cases in 149 `.val()` calls |
| **Impact** | 🟠 **HIGH** - Form data not saved correctly |
| **Probability** | Medium (complex forms) |
| **Severity** | Data loss, incorrect saves |
| **Affected Features** | All form submissions |

**Mitigation:**
- ✅ Test all form types
- ✅ Handle edge cases (nested fields, arrays, etc.)
- ✅ Preserve existing behavior exactly

---

### 12. Notification Pattern Standardization

| Risk ID | RISK-012 |
|---------|----------|
| **Description** | Standardizing 112 notification calls might change user experience |
| **Impact** | 🟠 **HIGH** - Users see different messages |
| **Probability** | Low (if done correctly) |
| **Severity** | UX inconsistency |
| **Affected Features** | All user notifications |

**Mitigation:**
- ✅ Keep same message text
- ✅ Keep same notification type (success/error/warning)
- ✅ Test all notification scenarios

---

### 13. File Split Breaking Imports

| Risk ID | RISK-013 |
|---------|----------|
| **Description** | Splitting files might break shared includes/requires |
| **Impact** | 🟠 **HIGH** - PHP errors, missing functions |
| **Probability** | Medium (if not careful) |
| **Severity** | Fatal errors, features broken |
| **Affected Systems** | All new API files |

**Mitigation:**
- ✅ Create shared bootstrap file
- ✅ Test all includes work
- ✅ Document dependencies

---

### 14. Action Count Mismatch

| Risk ID | RISK-014 |
|---------|----------|
| **Description** | Missing actions during split (40 actions must be preserved) |
| **Impact** | 🟠 **HIGH** - Features missing |
| **Probability** | Low (if careful) |
| **Severity** | Features not accessible |
| **Affected Features** | Any missing action |

**Mitigation:**
- ✅ Create action inventory before split
- ✅ Verify count matches (40 before = 40 after)
- ✅ Test all actions work

---

### 15. Legacy Field Rejection Removal

| Risk ID | RISK-015 |
|---------|----------|
| **Description** | Removing `id_work_center` rejection allows bad data |
| **Impact** | 🟠 **HIGH** - Invalid data accepted |
| **Probability** | Low (but data integrity risk) |
| **Severity** | Data corruption |
| **Affected Data** | Node work center assignments |

**Mitigation:**
- ❌ **KEEP REJECTION CODE** (it's a guard, not debt)
- ✅ Extract to helper (DRY improvement)
- ✅ Keep rejection logic

---

## 🟡 MEDIUM RISKS (P3 - Monitor)

### 16. Code Quality Metrics Regression

| Risk ID | RISK-016 |
|---------|----------|
| **Description** | Refactor might increase complexity instead of reducing |
| **Impact** | 🟡 **MEDIUM** - Harder to maintain |
| **Probability** | Low |
| **Severity** | Technical debt increase |

**Mitigation:**
- ✅ Measure metrics before/after
- ✅ Target: Reduce lines, functions, complexity

---

### 17. Test Coverage Gaps

| Risk ID | RISK-017 |
|---------|----------|
| **Description** | New files might not have adequate test coverage |
| **Impact** | 🟡 **MEDIUM** - Bugs not caught |
| **Probability** | Medium |
| **Severity** | Production bugs |

**Mitigation:**
- ✅ Write tests before refactor
- ✅ Maintain 80%+ coverage
- ✅ Integration tests for all actions

---

### 18. Performance Degradation

| Risk ID | RISK-018 |
|---------|----------|
| **Description** | Additional abstraction layers might slow down |
| **Impact** | 🟡 **MEDIUM** - Slower response times |
| **Probability** | Low |
| **Severity** | User experience degradation |

**Mitigation:**
- ✅ Benchmark before/after
- ✅ Keep same performance or better
- ✅ Monitor production metrics

---

### 19. Documentation Gaps

| Risk ID | RISK-019 |
|---------|----------|
| **Description** | New file structure not documented |
| **Impact** | 🟡 **MEDIUM** - Harder for new developers |
| **Probability** | Medium |
| **Severity** | Onboarding difficulty |

**Mitigation:**
- ✅ Document new structure
- ✅ Update API reference
- ✅ Add inline comments

---

### 20. Module Dependency Issues (JS)

| Risk ID | RISK-020 |
|---------|----------|
| **Description** | Extracted JS modules might have circular dependencies |
| **Impact** | 🟡 **MEDIUM** - Runtime errors |
| **Probability** | Medium |
| **Severity** | Features broken |

**Mitigation:**
- ✅ Design dependency graph
- ✅ Avoid circular dependencies
- ✅ Test module loading

---

## 🟢 LOW RISKS (P4 - Acceptable)

### 21. Code Comments Cleanup

| Risk ID | RISK-021 |
|---------|----------|
| **Description** | Removing Task/Phase comments loses historical context |
| **Impact** | 🟢 **LOW** - Less context for future |
| **Probability** | N/A (intentional) |
| **Severity** | Minor inconvenience |

**Mitigation:**
- ✅ Keep important comments
- ✅ Document in commit messages
- ✅ Reference task numbers in git history

---

### 22. Naming Convention Changes

| Risk ID | RISK-022 |
|---------|----------|
| **Description** | New file names might confuse existing developers |
| **Impact** | 🟢 **LOW** - Temporary confusion |
| **Probability** | Low |
| **Severity** | Minor learning curve |

**Mitigation:**
- ✅ Clear naming conventions
- ✅ Update documentation
- ✅ Announce changes

---

## 📋 Risk Mitigation Checklist

### Before Starting Refactor

- [ ] **Backup database** (all tenant DBs)
- [ ] **Write integration tests** for all 40 actions
- [ ] **Audit legacy permission usage** in database
- [ ] **Check error_log** for deprecated action usage (7-30 days)
- [ ] **Document current behavior** (what works now)
- [ ] **Create rollback plan** (how to revert if needed)
- [ ] **Set up monitoring** (error_log, performance metrics)

### During Refactor

- [ ] **Test after each change** (don't batch too many)
- [ ] **Keep backward compatibility** (router pattern)
- [ ] **Preserve error messages** (exact format)
- [ ] **Maintain test coverage** (80%+)
- [ ] **Document changes** (what changed, why)

### After Refactor

- [ ] **Run full test suite** (all tests pass)
- [ ] **Manual testing** (all 40 actions work)
- [ ] **Performance benchmark** (same or better)
- [ ] **Monitor error_log** (no new errors)
- [ ] **User acceptance testing** (key users test)

---

## 🎯 Risk Priority Matrix

| Priority | Risk Count | Action |
|----------|------------|--------|
| **P1 (Critical)** | 7 | Must address before refactor |
| **P2 (High)** | 11 | Should address during refactor |
| **P3 (Medium)** | 11 | Monitor during/after refactor |
| **P4 (Low)** | 7 | Acceptable, document only |

---

## 📝 Risk Register Summary

**Total Risks:** 36
- **Critical (P1):** 7 risks - **BLOCK REFACTOR** until addressed
- **High (P2):** 11 risks - **MITIGATE** during refactor
- **Medium (P3):** 11 risks - **MONITOR** during/after
- **Low (P4):** 7 risks - **ACCEPT** with documentation

**Overall Risk Level:** 🔴 **HIGH** - Requires careful planning and execution

**Recommendation:** 
- ✅ Complete all P1 mitigations before starting
- ✅ Execute refactor in small, testable increments
- ✅ Have rollback plan ready at all times
- ✅ Monitor production closely during and after

---

## 🔗 Related Documents

- [Task 27.26: DAG Routing API Refactor](../tasks/task27.26_DAG_ROUTING_API_REFACTOR.md)
- [Quick Wins Safety Check](./20251209_QUICK_WINS_SAFETY_CHECK.md)
- [DAG Routing API Audit](./20251209_DAG_ROUTING_API_AUDIT.md)
- [DAG JS Files Audit](./20251209_DAG_JS_FILES_AUDIT.md)

---

**Last Updated:** 2025-12-09
**Next Review:** Before starting Task 27.26 implementation

