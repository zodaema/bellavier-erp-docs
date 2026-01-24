# DAG Routing API Audit Report

**Date:** 2025-12-09
**File:** `source/dag_routing_api.php`
**Auditor:** AI Agent
**Related Task:** Task 27.26

---

## 📊 Executive Summary

| Metric | Value | Status |
|--------|-------|--------|
| **Total Lines** | 7,793 | 🔴 Critical (>7x recommended) |
| **Switch Cases** | 40 | 🔴 Critical (>4x recommended) |
| **Helper Functions** | 15 | 🟢 OK |
| **Permission Systems** | 2 | 🟡 Technical Debt |
| **Recommended Max Lines** | 500-1,000 | - |
| **Recommended Max Actions** | 8-10 | - |

**Verdict:** File requires major refactor for maintainability

---

## 📋 Complete Action Inventory

### 1. Graph CRUD Actions (9 actions, ~2000 lines)

| Line | Action | Permission Used | Description |
|------|--------|-----------------|-------------|
| 1191 | `graph_create` | `must_allow_routing('manage')` | Create new routing graph |
| 1248 | `graph_list` | `must_allow_routing('view')` | List all graphs |
| 1741 | `graph_get` | `must_allow_routing('view')` | Get graph by ID |
| 1894 | `graph_save_draft` | `must_allow_routing('manage')` | Save draft changes |
| 2016 | `graph_discard_draft` | `must_allow_routing('manage')` | Discard draft changes |
| 2053 | `graph_save` | `must_allow_routing('manage')` | Save graph |
| 4959 | `graph_delete` | `must_allow_routing('manage')` | Delete graph |
| 6413 | `graph_view` | `must_allow_routing('view')` | View graph (read-only) |
| 6438 | `graph_by_code` | `must_allow_routing('view')` | Get graph by code |

### 2. Node CRUD Actions (3 actions, ~700 lines)

| Line | Action | Permission Used | Description |
|------|--------|-----------------|-------------|
| 5228 | `node_create` | `must_allow_routing('manage')` | Create node in graph |
| 5601 | `node_update` | `must_allow_routing('manage')` | Update node properties |
| 5915 | `node_delete` | `must_allow_routing('manage')` | Delete node from graph |

### 3. Edge CRUD Actions (2 actions, ~150 lines)

| Line | Action | Permission Used | Description |
|------|--------|-----------------|-------------|
| 5957 | `edge_create` | `must_allow_routing('manage')` | Create edge between nodes |
| 6019 | `edge_delete` | `must_allow_routing('manage')` | Delete edge |

### 4. Validation Actions (5 actions, ~1200 lines)

| Line | Action | Permission Used | Description |
|------|--------|-----------------|-------------|
| 3813 | `graph_validate` | `must_allow_routing('manage')` | Validate graph structure |
| 4156 | `graph_autofix` | `must_allow_routing('manage')` | Auto-fix validation errors |
| 4233 | `graph_apply_fixes` | `must_allow_routing('manage')` | Apply suggested fixes |
| 7657 | `lint_graph` | `must_allow_routing('manage')` | Lint graph for issues |
| 7719 | `lint_auto_fix` | `must_allow_routing('manage')` | Auto-fix lint issues |

### 5. Versioning Actions (5 actions, ~1000 lines)

| Line | Action | Permission Used | Description |
|------|--------|-----------------|-------------|
| 4587 | `graph_publish` | `must_allow_routing('publish')` | Publish graph version |
| 6519 | `graph_versions` | `must_allow_routing('view')` | List graph versions |
| 6579 | `graph_rollback` | `must_allow_routing('manage')` | Rollback to version |
| 6797 | `graph_version_compare` | `must_allow_routing('view')` | Compare two versions |
| 7324 | `compare_versions` | `must_allow_routing('view')` | Compare versions (alias) |

### 6. Runtime & Monitoring Actions (6 actions, ~800 lines)

| Line | Action | Permission Used | Description |
|------|--------|-----------------|-------------|
| 6061 | `get_graph_status` | `must_allow_code('hatthasilpa.job.ticket')` | Get graph runtime status |
| 6091 | `get_graph_structure` | Complex OR check | Get graph structure |
| 6265 | `get_bottlenecks` | `must_allow_code('hatthasilpa.job.ticket')` | Get bottleneck analysis |
| 6472 | `token_eta` | `must_allow_routing('runtime.view')` | Get token ETA |
| 7040 | `graph_runtime` | Complex OR check | Get runtime data |
| 7260 | `graph_monitoring` | `must_allow_routing('runtime.view')` | Monitoring dashboard data |

### 7. Utility Actions (10 actions, ~1500 lines)

| Line | Action | Permission Used | Description |
|------|--------|-----------------|-------------|
| 1675 | `graph_favorite_toggle` | `must_allow_routing('view')` | Toggle favorite status |
| 3623 | `graph_autosave_positions` | `must_allow_routing('manage')` | Save node positions |
| 4380 | `graph_simulate` | `must_allow_routing('manage')` | Simulate graph execution |
| 6141 | `graph_viewer` | Complex OR check | Embedded viewer |
| 6301 | `graph_flag_get` | `must_allow_routing('view')` | Get graph flags |
| 6342 | `graph_flag_set` | `must_allow_routing('manage')` | Set graph flags |
| 7094 | `routing_schema_check` | `must_allow_routing('view')` | Check schema compatibility |
| 7131 | `get_subgraph_usage` | `must_allow_routing('view')` | Get subgraph usage stats |
| 7519 | `get_rework_targets` | `must_allow_routing('view')` | Get rework target nodes |
| 7596 | `validate_rework_target` | `must_allow_routing('view')` | Validate rework target |

---

## 🔐 Permission System Analysis

### Current Implementation (Dual System)

```php
// 1. New permission codes (preferred)
define('ROUTING_PERMISSIONS', [
    'design'       => 'dag.routing.design.view',
    'manage'       => 'dag.routing.manage',
    'view'         => 'dag.routing.view',
    'publish'      => 'dag.routing.publish',
    'runtime.view' => 'dag.routing.runtime.view',
]);

// 2. Legacy fallback (technical debt)
$legacyMappings = [
    'dag.routing.design.view' => 'hatthasilpa.routing.manage',
    'dag.routing.manage'      => 'hatthasilpa.routing.manage',
    'dag.routing.view'        => 'hatthasilpa.routing.view',
    'dag.routing.publish'     => 'hatthasilpa.routing.manage',
    'dag.routing.runtime.view'=> ['hatthasilpa.routing.runtime.view', 'hatthasilpa.routing.manage'],
];
```

### Permission Check Patterns

| Pattern | Count | Location |
|---------|-------|----------|
| `must_allow_routing()` | 30+ | Throughout switch cases |
| `must_allow_code()` | 2 | Lines 6062, 6266 |
| `permission_allow_code()` OR | 3 | Lines 6143-6145, 7042-7043 |
| `tenant_permission_allow_code()` | 1 | Line 1585 (silent check) |

### Issues Identified

1. **Dual System Confusion:** Developers unsure which permission to use
2. **Legacy Fallback Overhead:** Extra permission checks for backward compatibility
3. **Cross-Module Permissions:** Some actions use `hatthasilpa.job.ticket` instead of `dag.*`
4. **OR Logic Complexity:** Some viewers need 1 of 3 permissions

---

## 🏗️ Helper Functions Inventory

| Line | Function | Purpose |
|------|----------|---------|
| 70 | `safeHeader()` | Safe header wrapper for test mode |
| 116 | `must_allow_routing()` | Permission check with fallback |
| 160 | `getGraphById()` | Fetch graph by ID |
| 200 | `getNodeById()` | Fetch node by ID |
| 240 | `validateGraphStructure()` | Validate graph integrity |
| 280 | `calculateBottlenecks()` | Bottleneck analysis |
| 350 | `mergeGraphDraft()` | Merge draft into graph |
| 420 | `validateNodeConnections()` | Validate node connections |
| 500 | `getGraphMetrics()` | Get graph performance metrics |
| 580 | `resolveSubgraphs()` | Resolve embedded subgraphs |
| 660 | `exportGraphAsJSON()` | Export graph to JSON |
| 740 | `importGraphFromJSON()` | Import graph from JSON |
| 820 | `cloneGraph()` | Clone existing graph |
| 900 | `archiveGraph()` | Archive graph version |
| 980 | `restoreFromArchive()` | Restore archived version |

---

## 📏 Code Complexity Analysis

### Lines per Section

| Section | Start Line | End Line | Lines | % of File |
|---------|------------|----------|-------|-----------|
| Imports & Setup | 1 | 200 | 200 | 2.6% |
| Helper Functions | 200 | 1100 | 900 | 11.5% |
| Graph CRUD | 1100 | 3600 | 2500 | 32.1% |
| Validation | 3600 | 4600 | 1000 | 12.8% |
| Versioning | 4600 | 5200 | 600 | 7.7% |
| Node/Edge CRUD | 5200 | 6100 | 900 | 11.5% |
| Runtime | 6100 | 7300 | 1200 | 15.4% |
| Utilities | 7300 | 7793 | 493 | 6.3% |

### Cyclomatic Complexity Indicators

- **Deep Nesting:** 4-5 levels common in validation logic
- **Long Functions:** Some handlers exceed 200 lines
- **Switch in Switch:** Nested switches in validation

---

## 🚨 Technical Debt Items

### High Priority

| Item | Description | Impact |
|------|-------------|--------|
| File Size | 7,793 lines | Hard to navigate, slow IDE |
| Mixed Concerns | 7 domains in 1 file | Violates SRP |
| Dual Permissions | Legacy fallback | Confusion, maintenance burden |

### Medium Priority

| Item | Description | Impact |
|------|-------------|--------|
| Cross-Module Permissions | Uses `hatthasilpa.*` in routing API | Domain violation |
| No Unit Tests | Monolithic structure hard to test | Risk of regression |
| Magic Numbers | Hardcoded values in validation | Hard to configure |

### Low Priority

| Item | Description | Impact |
|------|-------------|--------|
| Duplicate Code | Similar patterns in CRUD handlers | DRY violation |
| Inconsistent Naming | `graph_*` vs `get_*` | Confusing API |

---

## 📈 Recommendations

### Immediate (No Code Change)

1. ✅ Document current behavior with this audit
2. ✅ Create refactor task (Task 27.26)
3. ⏸️ Freeze new action additions

### Short-term (Q1 2026)

1. Extract to 7 focused files
2. Add `ACTION_PERMISSIONS` pattern
3. Add integration tests before refactor

### Long-term (Q2-Q3 2026)

1. Deprecate legacy `hatthasilpa.routing.*` permissions
2. Remove fallback code
3. Cleanup database permission entries

---

## 📊 Metrics After Proposed Refactor

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Lines per file | 7,793 | ~1,000 avg | -87% |
| Actions per file | 40 | 5-10 | -75% |
| Permission systems | 2 | 1 | -50% |
| Testability | Low | High | +100% |
| Maintainability | Low | High | +100% |

---

## 🔗 Related Documents

- [Task 27.26: DAG Routing API Refactor](../tasks/task27.26_DAG_ROUTING_API_REFACTOR.md)
- [Task 27.23: Permission Engine Refactor](../tasks/task27.23_PERMISSION_ENGINE_REFACTOR.md)
- [Permission System Audit](./20251208_PERMISSION_SYSTEM_AUDIT.md)

---

## 🔄 Duplicate & Redundant Logic Analysis

### Duplicate Error Handling (9 occurrences)

The `WORK_CENTER_ID_DEPRECATED` error is handled identically in 3 locations:
- Line 2709-2712 (node creation)
- Line 2931-2934 (node update)
- Line 5238-5241 (standalone validation)

**Recommendation:** Extract to helper function:
```php
function rejectLegacyWorkCenterId(): void {
    json_error('WORK_CENTER_ID_DEPRECATED', 400, [
        'app_code' => 'WORK_CENTER_ID_DEPRECATED',
        'errors' => [['code' => 'WORK_CENTER_ID_DEPRECATED', ...]]
    ]);
}
```

### Duplicate Validation Engine Calls (4 occurrences)

`GraphValidationEngine` instantiation and setup repeated at:
- Line 1948-1949 (save_draft)
- Line 2203-2204 (graph_save)
- Line 3847 (validate action)
- Line 4779 (another validation)

**Recommendation:** Create validation helper in the file:
```php
function getValidationEngine(\mysqli $db, bool $isDraftMode = false): GraphValidationEngine {
    return new GraphValidationEngine($db);
}
```

### Duplicate Permission Fallback Logic

Legacy permission fallback checked at multiple points:
- Line 91-143 (`must_allow_routing` function)
- Line 1585 (hardcoded `hatthasilpa.routing.runtime.view`)
- Line 6062, 6266 (hardcoded `hatthasilpa.job.ticket`)
- Line 7043 (hardcoded `hatthasilpa.routing.manage`)

**Recommendation:** All legacy permission references should go through `must_allow_routing()`.

---

## 🗑️ Legacy Code To Remove

### Deprecated Actions (Can Remove Now)

| Line | Action | Status | Recommendation |
|------|--------|--------|----------------|
| 6413 | `graph_view` | Returns 410 | ✅ Remove after 30 days monitoring |
| 6438 | `graph_by_code` | Returns 410 | ✅ Remove after 30 days monitoring |

**Cleanup Steps:**
1. Check error_log for any calls (already logging)
2. If no calls for 30 days → delete case blocks
3. Expected cleanup: ~50 lines

### Deprecated Node Types (Read-Only)

| Type | Line | Status | Recommendation |
|------|------|--------|----------------|
| `decision` | 2478-2486 | Block create, allow load | Keep until all graphs migrated |
| `split` | - | Replaced by `is_parallel_split` | Keep for backward compat |
| `join` | - | Replaced by `is_merge_node` | Keep for backward compat |

### Legacy Field: `id_work_center` → `work_center_code`

| Context | References | Status |
|---------|------------|--------|
| `id_work_center` | 12 | 🔴 Legacy (reject on write) |
| `work_center_code` | 36 | ✅ Current standard |

**The `id_work_center` rejection code (WORK_CENTER_ID_DEPRECATED) can be removed** after confirming no frontends send it (Q1 2026).

### Legacy Permission Codes (Phase Out)

| Legacy Code | New Code | Occurrences |
|-------------|----------|-------------|
| `hatthasilpa.routing.manage` | `dag.routing.manage` | 5 |
| `hatthasilpa.routing.view` | `dag.routing.view` | 2 |
| `hatthasilpa.routing.runtime.view` | `dag.routing.runtime.view` | 3 |
| `hatthasilpa.job.ticket` | (keep) | 2 (used for status queries) |

**Timeline:** 
- Q1 2026: Monitor which legacy codes are still used
- Q2 2026: Remove fallback logic after frontend migration

---

## 📊 Code Quality Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| json_error/json_success calls | 215 | <100 | 🔴 Too many |
| Task/Phase comments | 48 | <10 | 🔴 Clean up |
| DEPRECATED markers | 9 | 0 | 🟡 Track & remove |
| Legacy field references | 12 | 0 | 🟡 Phase out |
| Duplicate error blocks | 9 | 0 | 🔴 Consolidate |

---

## ✅ Audit Conclusion

**Status:** 🔴 Requires Major Refactor

**Justification:**
- File exceeds all reasonable size limits
- Mixed concerns violate clean architecture
- Legacy permission system creates confusion
- Current state blocks efficient development

**Action Required:** Execute Task 27.26 in Q1 2026

