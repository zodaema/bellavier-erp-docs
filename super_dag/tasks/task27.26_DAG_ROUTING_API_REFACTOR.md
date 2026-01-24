# Task 27.26: DAG Routing API & JS Refactor

**Created:** 2025-12-09  
**Last Updated:** 2025-12-10 (Phase 3 + Golden Tests Complete)  
**Status:** ✅ **Phase 3 COMPLETE** - GraphSaveEngine migrated with Golden Tests  
**Priority:** P2 (Medium)  
**Estimated Time:** 2.5 days active work + 1-3 months monitoring (PHP only, JS deferred to Q2 2026)

---

## 📊 Problem Statement

`dag_routing_api.php` has grown too large and violates single-responsibility principle:

| Metric | Current | Target |
|--------|---------|--------|
| Lines | 7,793 | < 1,000 per file |
| Actions | 40 | < 10 per file |
| Domains | 7 mixed | 1 per file |

### Issues

1. **Giant File Syndrome:** 7,793 lines is unmanageable
2. **Mixed Concerns:** Graph CRUD, Node CRUD, Validation, Versioning all in one file
3. **Legacy Permissions:** Dual permission system (dag.* + hatthasilpa.*)
4. **Hard to Test:** Large switch statement is hard to unit test
5. **Hard to Maintain:** Finding code is like finding needle in haystack

---

## 🎯 Goals

1. Split into 7 focused API files
2. Deprecate legacy `hatthasilpa.routing.*` permissions
3. Extract shared helpers to service classes
4. Add `@permission` docblocks to all new files
5. Use `ACTION_PERMISSIONS` pattern in new files

---

## 📁 Proposed File Structure

```
source/
├── dag_routing_api.php          # DEPRECATED - Redirect only
├── dag/
│   ├── dag_graph_api.php        # Graph CRUD (create, list, get, save, delete)
│   ├── dag_node_api.php         # Node CRUD (create, update, delete)
│   ├── dag_edge_api.php         # Edge CRUD (create, delete)
│   ├── dag_validation_api.php   # Validation (validate, autofix, lint)
│   ├── dag_version_api.php      # Versioning (publish, rollback, compare)
│   ├── dag_runtime_api.php      # Runtime (monitoring, status, bottlenecks)
│   └── dag_utils_api.php        # Utilities (favorites, flags, simulate)
└── BGERP/Service/
    └── DAGRoutingPermissionService.php  # Centralized permission logic
```

---

## 📋 Action Mapping

> ⚠️ **REQUIRED:** See [Action Matrix Checklist](checklist/task27.26_action_matrix.md) for complete tracking table.  
> **This section provides quick reference. The Action Matrix is MANDATORY for execution.**

### Action Matrix Summary (40 Actions)

| Action | Category | Old File | New File | Type | Test Case | Status |
|--------|----------|----------|----------|------|-----------|--------|
| `graph_list` | Graph | `dag_routing_api.php` | `dag_graph_api.php` | READ | Load graph list page | ⬜ |
| `graph_get` | Graph | `dag_routing_api.php` | `dag_graph_api.php` | READ | Load graph in designer | ⬜ |
| `graph_by_code` | Graph | `dag_routing_api.php` | `dag_graph_api.php` | READ | Get graph by code | ⬜ |
| `graph_view` | Graph | `dag_routing_api.php` | `dag_graph_api.php` | READ | View graph (read-only) | ⬜ |
| `graph_create` | Graph | `dag_routing_api.php` | `dag_graph_api.php` | WRITE | Create new graph | ⬜ |
| `graph_save` | Graph | `dag_routing_api.php` | `dag_graph_api.php` | WRITE | Save graph | ⬜ |
| `graph_save_draft` | Graph | `dag_routing_api.php` | `dag_graph_api.php` | WRITE | Save draft | ⬜ |
| `graph_discard_draft` | Graph | `dag_routing_api.php` | `dag_graph_api.php` | WRITE | Discard draft | ⬜ |
| `graph_delete` | Graph | `dag_routing_api.php` | `dag_graph_api.php` | WRITE | Delete graph | ⬜ |
| `node_create` | Node | `dag_routing_api.php` | `dag_node_api.php` | WRITE | Add node to graph | ⬜ |
| `node_update` | Node | `dag_routing_api.php` | `dag_node_api.php` | WRITE | Update node properties | ⬜ |
| `node_delete` | Node | `dag_routing_api.php` | `dag_node_api.php` | WRITE | Delete node | ⬜ |
| `edge_create` | Edge | `dag_routing_api.php` | `dag_edge_api.php` | WRITE | Create edge | ⬜ |
| `edge_delete` | Edge | `dag_routing_api.php` | `dag_edge_api.php` | WRITE | Delete edge | ⬜ |
| `graph_validate` | Validation | `dag_routing_api.php` | `dag_validation_api.php` | WRITE | Validate graph | ⬜ |
| `graph_autofix` | Validation | `dag_routing_api.php` | `dag_validation_api.php` | WRITE | Auto-fix errors | ⬜ |
| `graph_apply_fixes` | Validation | `dag_routing_api.php` | `dag_validation_api.php` | WRITE | Apply fixes | ⬜ |
| `lint_graph` | Validation | `dag_routing_api.php` | `dag_validation_api.php` | WRITE | Lint graph | ⬜ |
| `lint_auto_fix` | Validation | `dag_routing_api.php` | `dag_validation_api.php` | WRITE | Lint auto-fix | ⬜ |
| `graph_publish` | Version | `dag_routing_api.php` | `dag_version_api.php` | WRITE | Publish graph | ⬜ |
| `graph_versions` | Version | `dag_routing_api.php` | `dag_version_api.php` | READ | List versions | ⬜ |
| `graph_rollback` | Version | `dag_routing_api.php` | `dag_version_api.php` | WRITE | Rollback version | ⬜ |
| `graph_version_compare` | Version | `dag_routing_api.php` | `dag_version_api.php` | READ | Compare versions | ⬜ |
| `compare_versions` | Version | `dag_routing_api.php` | `dag_version_api.php` | READ | Compare (alias) | ⬜ |
| `graph_runtime` | Runtime | `dag_routing_api.php` | `dag_runtime_api.php` | READ | Runtime dashboard | ⬜ |
| `graph_monitoring` | Runtime | `dag_routing_api.php` | `dag_runtime_api.php` | READ | Monitoring dashboard | ⬜ |
| `get_graph_status` | Runtime | `dag_routing_api.php` | `dag_runtime_api.php` | READ | Work Queue status ⚠️ | ⬜ |
| `get_graph_structure` | Runtime | `dag_routing_api.php` | `dag_runtime_api.php` | READ | Graph structure | ⬜ |
| `get_bottlenecks` | Runtime | `dag_routing_api.php` | `dag_runtime_api.php` | READ | Bottleneck analysis ⚠️ | ⬜ |
| `token_eta` | Runtime | `dag_routing_api.php` | `dag_runtime_api.php` | READ | Token ETA | ⬜ |
| `graph_favorite_toggle` | Utils | `dag_routing_api.php` | `dag_utils_api.php` | WRITE | Toggle favorite | ⬜ |
| `graph_autosave_positions` | Utils | `dag_routing_api.php` | `dag_utils_api.php` | WRITE | Auto-save positions | ⬜ |
| `graph_simulate` | Utils | `dag_routing_api.php` | `dag_utils_api.php` | WRITE | Simulate graph | ⬜ |
| `graph_viewer` | Utils | `dag_routing_api.php` | `dag_utils_api.php` | READ | Embedded viewer | ⬜ |
| `graph_flag_get` | Utils | `dag_routing_api.php` | `dag_utils_api.php` | READ | Get flags | ⬜ |
| `graph_flag_set` | Utils | `dag_routing_api.php` | `dag_utils_api.php` | WRITE | Set flags | ⬜ |
| `routing_schema_check` | Utils | `dag_routing_api.php` | `dag_utils_api.php` | READ | Schema check | ⬜ |
| `get_subgraph_usage` | Utils | `dag_routing_api.php` | `dag_utils_api.php` | READ | Subgraph usage | ⬜ |
| `get_rework_targets` | Utils | `dag_routing_api.php` | `dag_utils_api.php` | READ | Rework targets | ⬜ |
| `validate_rework_target` | Utils | `dag_routing_api.php` | `dag_utils_api.php` | READ | Validate rework | ⬜ |

**Legend:**
- ⚠️ = Cross-module permission (`hatthasilpa.job.ticket`) - DO NOT CHANGE
- ⬜ = Not started / ✅ = Complete / ❌ = Failed

**Full Matrix:** See [Action Matrix Checklist](checklist/task27.26_action_matrix.md) for detailed testing checklist.

---

### Detailed Action Mapping by File

### 1. `dag_graph_api.php` (~2000 lines)
```php
/**
 * @permission dag.routing.manage
 */
const ACTION_PERMISSIONS = [
    'graph_create'        => 'dag.routing.manage',
    'graph_list'          => 'dag.routing.view',
    'graph_get'           => 'dag.routing.view',
    'graph_save'          => 'dag.routing.manage',
    'graph_save_draft'    => 'dag.routing.manage',
    'graph_discard_draft' => 'dag.routing.manage',
    'graph_delete'        => 'dag.routing.manage',
    'graph_view'          => 'dag.routing.view',
    'graph_by_code'       => 'dag.routing.view',
];
```

### 2. `dag_node_api.php` (~700 lines)
```php
/**
 * @permission dag.routing.manage
 */
const ACTION_PERMISSIONS = [
    'node_create' => 'dag.routing.manage',
    'node_update' => 'dag.routing.manage',
    'node_delete' => 'dag.routing.manage',
];
```

### 3. `dag_edge_api.php` (~150 lines)
```php
/**
 * @permission dag.routing.manage
 */
const ACTION_PERMISSIONS = [
    'edge_create' => 'dag.routing.manage',
    'edge_delete' => 'dag.routing.manage',
];
```

### 4. `dag_validation_api.php` (~1200 lines)
```php
/**
 * @permission dag.routing.manage
 */
const ACTION_PERMISSIONS = [
    'graph_validate'    => 'dag.routing.manage',
    'graph_autofix'     => 'dag.routing.manage',
    'graph_apply_fixes' => 'dag.routing.manage',
    'lint_graph'        => 'dag.routing.manage',
    'lint_auto_fix'     => 'dag.routing.manage',
];
```

### 5. `dag_version_api.php` (~1000 lines)
```php
/**
 * @permission dag.routing.manage, dag.routing.publish
 */
const ACTION_PERMISSIONS = [
    'graph_publish'         => 'dag.routing.publish',
    'graph_versions'        => 'dag.routing.view',
    'graph_rollback'        => 'dag.routing.manage',
    'graph_version_compare' => 'dag.routing.view',
    'compare_versions'      => 'dag.routing.view',
];
```

### 6. `dag_runtime_api.php` (~800 lines)
```php
/**
 * @permission dag.routing.runtime.view
 * 
 * ⚠️ CROSS-MODULE PERMISSION NOTE:
 * - get_graph_status and get_bottlenecks use 'hatthasilpa.job.ticket' (NOT dag.routing.*)
 * - This is intentional - these actions are used by Work Queue dashboard
 * - Users with hatthasilpa.job.ticket but NOT dag.routing.* must still access dashboard
 * - DO NOT change to dag.routing.runtime.view during refactor
 * - Keep existing permission check exactly as-is
 */
const ACTION_PERMISSIONS = [
    'graph_runtime'       => 'dag.routing.runtime.view',
    'graph_monitoring'    => 'dag.routing.runtime.view',
    'get_graph_status'    => 'hatthasilpa.job.ticket',  // ⚠️ Cross-module - DO NOT CHANGE
    'get_graph_structure' => 'dag.routing.view',
    'get_bottlenecks'     => 'hatthasilpa.job.ticket',  // ⚠️ Cross-module - DO NOT CHANGE
    'token_eta'           => 'dag.routing.runtime.view',
];
```

### 7. `dag_utils_api.php` (~1500 lines)
```php
/**
 * @permission dag.routing.view, dag.routing.manage
 */
const ACTION_PERMISSIONS = [
    'graph_favorite_toggle'    => 'dag.routing.view',
    'graph_autosave_positions' => 'dag.routing.manage',
    'graph_simulate'           => 'dag.routing.manage',
    'graph_flag_get'           => 'dag.routing.view',
    'graph_flag_set'           => 'dag.routing.manage',
    'graph_viewer'             => 'dag.routing.view',
    'routing_schema_check'     => 'dag.routing.view',
    'get_subgraph_usage'       => 'dag.routing.view',
    'get_rework_targets'       => 'dag.routing.view',
    'validate_rework_target'   => 'dag.routing.view',
];
```

---

## 🔄 Migration Strategy

### Phase 1: Prepare (0.5 day)
1. Create `source/dag/` directory
2. Create shared bootstrap/helper includes
3. Document current behavior with tests
4. **Create Action Matrix Checklist** (see below)

### Phase 2a: Extract Read-Only Actions (0.75 day) ⭐ **SAFETY FIRST**

**Goal:** Move read-only actions first to minimize risk of data corruption

**Actions to Extract:**
- `graph_list`, `graph_get`, `graph_by_code`, `graph_versions`, `graph_view`, `graph_viewer`
- `get_graph_structure`, `graph_runtime`, `graph_monitoring`, `get_bottlenecks` (read-only)
- `graph_flag_get`, `routing_schema_check`, `get_subgraph_usage`, `get_rework_targets`, `validate_rework_target`
- `graph_version_compare`, `compare_versions`

**Testing Requirements:**
- ✅ Graph Designer opens and loads graphs
- ✅ Validation view works
- ✅ Runtime monitor works
- ✅ All read-only screens functional
- ✅ No data mutation possible

**After Phase 2a:** Deploy and monitor for 3-7 days before proceeding

---

### Phase 2b: Extract Mutating Actions (0.75 day) ⚠️ **HIGH RISK**

**Goal:** Move write actions after read-only is stable

**Actions to Extract:**
- `graph_create`, `graph_save`, `graph_save_draft`, `graph_discard_draft`, `graph_delete`
- `node_create`, `node_update`, `node_delete`
- `edge_create`, `edge_delete`
- `graph_validate`, `graph_autofix`, `graph_apply_fixes`, `lint_graph`, `lint_auto_fix`
- `graph_publish`, `graph_rollback`
- `graph_favorite_toggle`, `graph_autosave_positions`, `graph_simulate`, `graph_flag_set`

**Testing Requirements:**
- ✅ All CRUD operations work
- ✅ Validation and autofix work
- ✅ Versioning (publish/rollback) works
- ✅ No data corruption
- ✅ Transaction safety verified

**After Phase 2b:** Deploy and monitor for 7-14 days before proceeding

---

### Phase 2: Router Strategy ⭐ **CRITICAL SAFETY**

**⚠️ IMPORTANT:** Keep `dag_routing_api.php` as delegating router for **≥1 release cycle** (or 1-3 months of real usage)

**Step 1:** Each group extracted to new file, `dag_routing_api.php` requires and delegates:
```php
// dag_routing_api.php (Phase 2)
require_once __DIR__ . '/dag/dag_graph_api.php';
require_once __DIR__ . '/dag/dag_node_api.php';
// ... etc

switch ($action) {
    case 'graph_list':
    case 'graph_get':
    case 'graph_save':
        // Delegate to dag_graph_api.php
        require_once __DIR__ . '/dag/dag_graph_api.php';
        exit; // Let new file handle it
}
```

**Step 2:** After all groups extracted, convert to thin router:
```php
// dag_routing_api.php (Phase 3)
// Thin router - forward to new files
$action = $_REQUEST['action'] ?? '';
$routing = [
    'graph_*' => 'dag/dag_graph_api.php',
    'node_*' => 'dag/dag_node_api.php',
    // ... etc
];
// Forward to appropriate file
```

**Step 3:** Keep router for **≥1 release** to catch:
- Frontend calls using old URLs
- External scripts calling old endpoints
- Browser bookmarks/cached requests

**Step 4:** After monitoring period (check error_log for 7-30 days), only then consider:
- Marking as deprecated
- Adding deprecation warnings
- Eventually removing (Q3 2026+)

**⚠️ DO NOT DELETE** `dag_routing_api.php` until error logs confirm zero legacy usage for 30+ days

---

## 🛑 Router Persistence Safety Rule (MANDATORY)

> ⚠️ **CRITICAL:** This rule is **NON-NEGOTIABLE** and must be followed strictly. Any violation is considered a **spec violation**.

### The Rule

The legacy file `dag_routing_api.php` **MUST NOT be deleted** during this task.

It must remain as a delegating router for:

1. **At least 1 full release cycle (30-60 days)**, AND
2. **Until error logs confirm zero usage of legacy endpoints for 30 consecutive days**

### Why This Rule Exists

- Frontend may have cached URLs or bookmarks
- External scripts may call old endpoints
- Browser extensions may use old API paths
- Mobile apps may have hardcoded URLs
- Third-party integrations may not be updated immediately

### Enforcement

**During Phase 2:**
- ✅ Keep `dag_routing_api.php` as delegating router
- ✅ All actions forward to new files
- ✅ Log all legacy endpoint calls (for monitoring)

**After Phase 2b (Monitoring Period):**
- ✅ Check `error_log` daily for legacy endpoint calls
- ✅ Monitor for 30 consecutive days with **zero legacy calls**
- ✅ Only then consider deprecation warnings

**Before Deletion (Q3 2026+):**
- ✅ Must have 30+ days of zero legacy usage
- ✅ Must have explicit approval from project lead
- ✅ Must have rollback plan ready

### What NOT to Do

❌ **DO NOT** delete `dag_routing_api.php` during Phase 2  
❌ **DO NOT** remove router logic before monitoring period  
❌ **DO NOT** skip error log monitoring  
❌ **DO NOT** assume "no one uses it" without proof  

### What TO Do

✅ **DO** keep router for entire monitoring period  
✅ **DO** log all legacy endpoint calls  
✅ **DO** check error logs daily during monitoring  
✅ **DO** wait for 30 consecutive days of zero usage  
✅ **DO** get explicit approval before deletion  

### Violation Consequences

If `dag_routing_api.php` is deleted before the monitoring period completes:

- **Immediate rollback required**
- **Spec violation** - task considered incomplete
- **Risk of breaking production** - frontend/scripts may fail
- **Must restore router** and restart monitoring period

---

**This rule is MANDATORY and cannot be bypassed.**

---

### Phase 3: Deprecate Legacy Permissions (0.5 day)
1. Add deprecation logging for `hatthasilpa.routing.*`
2. Update database seed to use `dag.routing.*` only
3. Create migration to rename permissions

### Phase 4: Cleanup (0.5 day)
1. Remove legacy fallback code (only after Phase 2 router period)
2. Update frontend URLs if needed
3. **DO NOT DELETE** `dag_routing_api.php` until Phase 2 monitoring complete

---

## ⚠️ Risks & Mitigations

> 📋 **COMPREHENSIVE RISK ASSESSMENT** - See [Risk Assessment Report](../00-audit/20251209_RISK_ASSESSMENT_TASK27.26.md)

### Quick Summary

| Risk Level | Count | Status |
|------------|-------|--------|
| 🔴 **Critical (P1)** | 7 | **MUST ADDRESS** before refactor |
| 🟠 **High (P2)** | 11 | Mitigate during refactor |
| 🟡 **Medium (P3)** | 11 | Monitor during/after |
| 🟢 **Low (P4)** | 7 | Acceptable |

### Top 7 Critical Risks

1. **RISK-001:** Breaking Frontend API Calls → Keep router for backward compatibility
2. **RISK-002:** Permission System Regression → Don't remove fallback until migration
3. **RISK-003:** Validation Logic Regression → Extract helper, write tests
4. **RISK-004:** Legacy Timer Variables → Refactor first, don't remove
5. **RISK-005:** Deprecated Actions Still In Use → Check error_log 7-30 days
6. **RISK-006:** Node/Edge Properties Editor Extraction → Extract incrementally
7. **RISK-007:** Data Integrity During Refactor → Use transactions, backup DB

**Overall Risk Level:** 🔴 **HIGH** - Requires careful planning

**See full details:** [Risk Assessment Report](../00-audit/20251209_RISK_ASSESSMENT_TASK27.26.md)

---

## 📋 Acceptance Criteria

### Phase 2-3 Core Refactor:
- [x] Graph CRUD actions migrated to `GraphSaveEngine` ✅
- [x] `graph_save` delegated to service layer ✅
- [x] **Golden Tests for GraphSaveEngine complete** ✅ (6 scenarios, 38 assertions)
- [ ] All 40 actions work identically after refactor (pending full migration)
- [ ] **Action Matrix Checklist completed** (see [Action Matrix](checklist/task27.26_action_matrix.md))
- [x] Each new file < 1500 lines ✅ (`dag_graph_api.php` ≈ 910 lines)
- [x] All new files have `@permission` docblock ✅
- [x] All new files use `ACTION_PERMISSIONS` pattern ✅
- [ ] Legacy permissions deprecated with logging (Phase 3 - deferred)
- [x] No frontend changes required ✅
- [x] Golden Tests pass ✅ (6 tests, 38 assertions)
- [ ] Integration tests pass (API level - deferred)
- [ ] **Router kept for ≥1 release cycle** (monitoring period - pending)
- [x] **Phase 2a (read-only) tested and stable** ✅
- [x] **Phase 3 (mutating) core complete with Golden Tests** ✅
- [ ] **Cross-module permissions preserved** (`hatthasilpa.job.ticket` for `get_graph_status`, `get_bottlenecks` - pending full migration)

### Phase 3.5 (Golden Tests):
- [x] Comprehensive test suite covering critical save scenarios ✅
- [x] Validation engine compatibility with `temp_id` ✅
- [x] Autosave validation working correctly ✅
- [x] Safety net established for future refactoring ✅

**Status:** ✅ **Core Architecture Complete** - Ready for production feature development

---

## 🔗 Related Documents

- [DAG Routing API Audit](../00-audit/20251209_DAG_ROUTING_API_AUDIT.md) - PHP audit
- [DAG JS Files Audit](../00-audit/20251209_DAG_JS_FILES_AUDIT.md) - JavaScript audit
- [Risk Assessment Report](../00-audit/20251209_RISK_ASSESSMENT_TASK27.26.md) - Comprehensive risk analysis
- **[Action Matrix Checklist](checklist/task27.26_action_matrix.md)** ⭐ **REQUIRED** - Track all 40 actions through refactor
- Task 27.23: Permission Engine Refactor (prerequisite) ✅
- Task 27.25: Permission UI Improvement ✅

---

## 📅 Timeline

| Phase | Duration | Target | Notes |
|-------|----------|--------|-------|
| Phase 1: Prepare | 0.5 day | Q1 2026 | Create Action Matrix |
| Phase 2a: Extract Read-Only | 0.75 day | Q1 2026 | 18 actions, test & monitor 3-7 days |
| Phase 2b: Extract Mutating | 0.75 day | Q1 2026 | 22 actions, test & monitor 7-14 days |
| Phase 2: Router Period | 1-3 months | Q1-Q2 2026 | Keep router, monitor error_log |
| Phase 3: Deprecate | 0.5 day | Q2 2026 | After router period stable |
| Phase 4: Cleanup | 0.5 day | Q3 2026 | Only after 30+ days zero legacy usage |

**Recommended Start:** After core DAG features stabilize (Q1 2026)

**Total Estimated Time:** 2.5 days active work + 1-3 months monitoring period

---

## 📁 Part 2: JavaScript Refactor ⏸️ **DEFERRED**

> ⚠️ **CRITICAL:** Do NOT start JS refactor until PHP API refactor is **fully stable in production** (after Phase 2b + 7-14 days monitoring)

**Reasoning:**
- Avoid "API changing + JS changing" simultaneously
- If both break, debugging becomes impossible
- Wait until PHP refactor is proven stable before touching JS

**Current State Assessment:**
- ✅ **14 modules already extracted** (4,862 lines) - Good modular structure
- 🔴 **graph_designer.js is large** (8,839 lines) but functional
- 🟢 **Other files are manageable** (< 2,000 lines each)
- 🟡 **Some duplicate code** but not critical

**Recommendation:** ⏸️ **Defer refactor for now**
- Current structure is functional and modular
- Better ROI to focus on PHP API refactor first
- Plan for Q2 2026 (after PHP refactor stable)

**See:** [DAG JS Files Audit](../00-audit/20251209_DAG_JS_FILES_AUDIT.md) for detailed analysis

**Timeline:** Q2 2026 (after PHP refactor stable)

---

### Problem

`graph_designer.js` has grown too large:

| Metric | Current | Target |
|--------|---------|--------|
| Lines | 8,839 | ~1,000 |
| Functions | 101 | ~15 |
| Nested functions | 30+ | 0 |

### Proposed JS Module Structure

```
assets/javascripts/dag/
├── graph_designer.js            # SLIM - Orchestration only (~1000 lines)
├── modules/
│   ├── GraphInit.js             # Initialization (300 lines)
│   ├── GraphCRUD.js             # Load/Save/Delete (1500 lines)
│   ├── NodeOperations.js        # Node CRUD (400 lines)
│   ├── EdgeOperations.js        # Edge CRUD (600 lines)
│   ├── NodePropertiesEditor.js  # Node properties panel (1500 lines) ← NEW
│   ├── EdgePropertiesEditor.js  # Edge properties panel (800 lines) ← NEW
│   ├── ValidationUI.js          # Validation panel (800 lines) ← NEW
│   ├── PublishManager.js        # Publishing (200 lines) ← NEW
│   ├── DraftManager.js          # Draft operations (200 lines) ← NEW
│   ├── ToolbarManager.js        # Toolbar/UI (300 lines) ← NEW
│   ├── AutoSaveManager.js       # AutoSave (100 lines) ← NEW
│   └── FeatureFlagManager.js    # Feature flags (100 lines) ← NEW
│   # Existing modules remain unchanged
│   ├── GraphSaver.js
│   ├── GraphValidator.js
│   ├── GraphHistoryManager.js
│   └── ...
```

### JS Refactor Priority

1. **P1:** Extract NodePropertiesEditor (1,500 lines - largest block)
2. **P1:** Extract EdgePropertiesEditor (800 lines)
3. **P2:** Extract ValidationUI (800 lines)
4. **P2:** Extract GraphCRUD (1,500 lines)
5. **P3:** Remaining cleanup

### JS Timeline

| Phase | Duration | Target |
|-------|----------|--------|
| Extract Properties Editors | 1 day | Q1 2026 |
| Extract Validation/CRUD | 1 day | Q1 2026 |

---

## 🧹 Cleanup Items (Quick Wins)

> ⚠️ **SAFETY CHECK COMPLETED** - See [Safety Check Report](../00-audit/20251209_QUICK_WINS_SAFETY_CHECK.md)

### PHP (dag_routing_api.php)

| Item | Lines | Effort | Impact | Status |
|------|-------|--------|--------|--------|
| Extract `rejectLegacyWorkCenterId()` helper | 9→1 | 15 min | DRY | ✅ **SAFE** |
| Consolidate validation engine instantiation | 4→1 | 15 min | DRY | ✅ **SAFE** |
| Remove `graph_by_code` deprecated action | ~20 | 5 min | Clean | ⚠️ **Check log first** |
| Remove `graph_view` deprecated action | ~20 | 5 min | Clean | ⚠️ **Check log first** |
| Remove `id_work_center` rejection | 12 refs | 30 min | Clean | ❌ **KEEP** (guard) |
| Remove legacy permission fallback (Q2 2026) | ~50 | 1 hr | Clean | ⏸️ **Later** |

### JS (graph_designer.js)

| Item | Lines | Effort | Impact | Status |
|------|-------|--------|--------|--------|
| Standardize notification pattern | 112→50 | 30 min | Consistent | ✅ **SAFE** |
| Create form serializer | 149→30 | 1 hr | DRY | ✅ **SAFE** |
| Remove legacy timer variables | ~10 | 30 min | Clean | 🔴 **Refactor first** |
| Remove legacy node type UI (Q2 2026) | ~500 | 2 hr | Clean | ⏸️ **Later** |

### ⚠️ Safety Notes

- **Legacy timer vars**: Still referenced 11 times - requires refactor, not quick removal
- **Deprecated actions**: Check error_log for 7 days before removal
- **`id_work_center` rejection**: Keep as guard (working as intended)

---

## 📝 Notes

This refactor is **not urgent** but should be done before:
1. Adding more actions to dag_routing_api.php
2. Onboarding new developers
3. Major DAG feature additions

Current file works fine - this is a **maintainability improvement**, not a bug fix.

---

## ✅ Pre-Execution Checklist

Before starting this refactor, ensure:

- [ ] **Action Matrix Checklist created** - See [checklist/task27.26_action_matrix.md](checklist/task27.26_action_matrix.md)
- [ ] **Router Persistence Rule understood** - See [🛑 Router Persistence Safety Rule](#-router-persistence-safety-rule-mandatory) above
- [ ] **All 40 actions mapped** - See [Action Matrix Summary](#action-matrix-summary-40-actions) above
- [ ] **Phase 2a/2b split understood** - Read-only actions first, then mutating
- [ ] **Cross-module permissions noted** - `get_graph_status` and `get_bottlenecks` use `hatthasilpa.job.ticket`
- [ ] **Monitoring period planned** - 3-7 days for Phase 2a, 7-14 days for Phase 2b
- [ ] **Error log monitoring setup** - Ready to track legacy endpoint usage
- [ ] **Rollback plan ready** - In case of issues

**DO NOT START** until all checklist items are complete.

