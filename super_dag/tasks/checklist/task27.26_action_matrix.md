# Task 27.26: Action Matrix Checklist

**Purpose:** Track all 40 actions through refactor to ensure nothing breaks  
**Created:** 2025-12-09  
**Status:** 📋 Pre-Refactor

---

## 📋 Action Testing Matrix

| # | Action | Target API | Type | Key Screen/Feature | Tested Before | Tested After Phase 2a | Tested After Phase 2b | Notes |
|---|--------|------------|------|-------------------|---------------|----------------------|----------------------|-------|
| **GRAPH CRUD** |
| 1 | `graph_create` | `dag_graph_api.php` | WRITE | Create Graph Dialog | ⬜ | N/A | ⬜ | |
| 2 | `graph_list` | `dag_graph_api.php` | READ | Graph List Page | ⬜ | ⬜ | ⬜ | Phase 2a |
| 3 | `graph_get` | `dag_graph_api.php` | READ | Graph Designer Load | ⬜ | ⬜ | ⬜ | Phase 2a |
| 4 | `graph_save` | `dag_graph_api.php` | WRITE | Save Graph Button | ⬜ | N/A | ⬜ | |
| 5 | `graph_save_draft` | `dag_graph_api.php` | WRITE | Auto-save Draft | ⬜ | N/A | ⬜ | |
| 6 | `graph_discard_draft` | `dag_graph_api.php` | WRITE | Discard Draft Button | ⬜ | N/A | ⬜ | |
| 7 | `graph_delete` | `dag_graph_api.php` | WRITE | Delete Graph Dialog | ⬜ | N/A | ⬜ | |
| 8 | `graph_view` | `dag_graph_api.php` | READ | View Graph (read-only) | ⬜ | ⬜ | ⬜ | Phase 2a |
| 9 | `graph_by_code` | `dag_graph_api.php` | READ | Get Graph by Code | ⬜ | ⬜ | ⬜ | Phase 2a |
| **NODE CRUD** |
| 10 | `node_create` | `dag_node_api.php` | WRITE | Add Node Toolbar | ⬜ | N/A | ⬜ | |
| 11 | `node_update` | `dag_node_api.php` | WRITE | Node Properties Panel | ⬜ | N/A | ⬜ | |
| 12 | `node_delete` | `dag_node_api.php` | WRITE | Delete Node Button | ⬜ | N/A | ⬜ | |
| **EDGE CRUD** |
| 13 | `edge_create` | `dag_edge_api.php` | WRITE | Connect Nodes | ⬜ | N/A | ⬜ | |
| 14 | `edge_delete` | `dag_edge_api.php` | WRITE | Delete Edge | ⬜ | N/A | ⬜ | |
| **VALIDATION** |
| 15 | `graph_validate` | `dag_validation_api.php` | WRITE | Validate Button | ⬜ | N/A | ⬜ | |
| 16 | `graph_autofix` | `dag_validation_api.php` | WRITE | Auto-fix Button | ⬜ | N/A | ⬜ | |
| 17 | `graph_apply_fixes` | `dag_validation_api.php` | WRITE | Apply Fixes Button | ⬜ | N/A | ⬜ | |
| 18 | `lint_graph` | `dag_validation_api.php` | WRITE | Lint Graph | ⬜ | N/A | ⬜ | |
| 19 | `lint_auto_fix` | `dag_validation_api.php` | WRITE | Lint Auto-fix | ⬜ | N/A | ⬜ | |
| **VERSIONING** |
| 20 | `graph_publish` | `dag_version_api.php` | WRITE | Publish Button | ⬜ | N/A | ⬜ | |
| 21 | `graph_versions` | `dag_version_api.php` | READ | Version History Panel | ⬜ | ⬜ | ⬜ | Phase 2a |
| 22 | `graph_rollback` | `dag_version_api.php` | WRITE | Rollback Button | ⬜ | N/A | ⬜ | |
| 23 | `graph_version_compare` | `dag_version_api.php` | READ | Compare Versions | ⬜ | ⬜ | ⬜ | Phase 2a |
| 24 | `compare_versions` | `dag_version_api.php` | READ | Compare Versions (alias) | ⬜ | ⬜ | ⬜ | Phase 2a |
| **RUNTIME & MONITORING** |
| 25 | `graph_runtime` | `dag_runtime_api.php` | READ | Runtime Dashboard | ⬜ | ⬜ | ⬜ | Phase 2a |
| 26 | `graph_monitoring` | `dag_runtime_api.php` | READ | Monitoring Dashboard | ⬜ | ⬜ | ⬜ | Phase 2a |
| 27 | `get_graph_status` | `dag_runtime_api.php` | READ | Work Queue Dashboard | ⬜ | ⬜ | ⬜ | Phase 2a ⚠️ Cross-module perm |
| 28 | `get_graph_structure` | `dag_runtime_api.php` | READ | Graph Structure View | ⬜ | ⬜ | ⬜ | Phase 2a |
| 29 | `get_bottlenecks` | `dag_runtime_api.php` | READ | Bottleneck Analysis | ⬜ | ⬜ | ⬜ | Phase 2a ⚠️ Cross-module perm |
| 30 | `token_eta` | `dag_runtime_api.php` | READ | Token ETA Calculation | ⬜ | ⬜ | ⬜ | Phase 2a |
| **UTILITIES** |
| 31 | `graph_favorite_toggle` | `dag_utils_api.php` | WRITE | Favorite Star Icon | ⬜ | N/A | ⬜ | |
| 32 | `graph_autosave_positions` | `dag_utils_api.php` | WRITE | Auto-save Node Positions | ⬜ | N/A | ⬜ | |
| 33 | `graph_simulate` | `dag_utils_api.php` | WRITE | Simulate Graph | ⬜ | N/A | ⬜ | |
| 34 | `graph_viewer` | `dag_utils_api.php` | READ | Embedded Viewer | ⬜ | ⬜ | ⬜ | Phase 2a |
| 35 | `graph_flag_get` | `dag_utils_api.php` | READ | Get Graph Flags | ⬜ | ⬜ | ⬜ | Phase 2a |
| 36 | `graph_flag_set` | `dag_utils_api.php` | WRITE | Set Graph Flags | ⬜ | N/A | ⬜ | |
| 37 | `routing_schema_check` | `dag_utils_api.php` | READ | Schema Compatibility Check | ⬜ | ⬜ | ⬜ | Phase 2a |
| 38 | `get_subgraph_usage` | `dag_utils_api.php` | READ | Subgraph Usage Stats | ⬜ | ⬜ | ⬜ | Phase 2a |
| 39 | `get_rework_targets` | `dag_utils_api.php` | READ | Rework Target Nodes | ⬜ | ⬜ | ⬜ | Phase 2a |
| 40 | `validate_rework_target` | `dag_utils_api.php` | READ | Validate Rework Target | ⬜ | ⬜ | ⬜ | Phase 2a |

---

## 📊 Summary

| Category | Total | Read-Only (Phase 2a) | Mutating (Phase 2b) |
|----------|-------|---------------------|---------------------|
| **Graph CRUD** | 9 | 4 | 5 |
| **Node CRUD** | 3 | 0 | 3 |
| **Edge CRUD** | 2 | 0 | 2 |
| **Validation** | 5 | 0 | 5 |
| **Versioning** | 5 | 2 | 3 |
| **Runtime** | 6 | 6 | 0 |
| **Utilities** | 10 | 6 | 4 |
| **TOTAL** | **40** | **18** | **22** |

---

## ✅ Testing Checklist

### Phase 2a (Read-Only Actions) - 18 actions

**Before Testing:**
- [ ] All 18 read-only actions extracted to new files
- [ ] `dag_routing_api.php` delegates to new files
- [ ] All `ACTION_PERMISSIONS` defined correctly
- [ ] Cross-module permissions preserved (`hatthasilpa.job.ticket`)

**Testing:**
- [ ] Graph List Page loads (`graph_list`)
- [ ] Graph Designer opens and loads graph (`graph_get`)
- [ ] Graph by code works (`graph_by_code`)
- [ ] Graph view (read-only) works (`graph_view`)
- [ ] Version history panel works (`graph_versions`)
- [ ] Version compare works (`graph_version_compare`, `compare_versions`)
- [ ] Runtime dashboard works (`graph_runtime`)
- [ ] Monitoring dashboard works (`graph_monitoring`)
- [ ] Work Queue dashboard works (`get_graph_status`) ⚠️
- [ ] Graph structure view works (`get_graph_structure`)
- [ ] Bottleneck analysis works (`get_bottlenecks`) ⚠️
- [ ] Token ETA works (`token_eta`)
- [ ] Embedded viewer works (`graph_viewer`)
- [ ] Graph flags read works (`graph_flag_get`)
- [ ] Schema check works (`routing_schema_check`)
- [ ] Subgraph usage works (`get_subgraph_usage`)
- [ ] Rework targets work (`get_rework_targets`, `validate_rework_target`)

**After Phase 2a:**
- [ ] Deploy to staging
- [ ] Monitor error_log for 3-7 days
- [ ] Verify no frontend breakage
- [ ] Verify no permission issues

---

### Phase 2b (Mutating Actions) - 22 actions

**Before Testing:**
- [ ] Phase 2a stable for 3-7 days
- [ ] All 22 mutating actions extracted to new files
- [ ] Transaction safety verified
- [ ] Permission checks verified

**Testing:**
- [ ] Create graph works (`graph_create`)
- [ ] Save graph works (`graph_save`)
- [ ] Save draft works (`graph_save_draft`)
- [ ] Discard draft works (`graph_discard_draft`)
- [ ] Delete graph works (`graph_delete`)
- [ ] Create node works (`node_create`)
- [ ] Update node works (`node_update`)
- [ ] Delete node works (`node_delete`)
- [ ] Create edge works (`edge_create`)
- [ ] Delete edge works (`edge_delete`)
- [ ] Validate graph works (`graph_validate`)
- [ ] Auto-fix works (`graph_autofix`)
- [ ] Apply fixes works (`graph_apply_fixes`)
- [ ] Lint graph works (`lint_graph`)
- [ ] Lint auto-fix works (`lint_auto_fix`)
- [ ] Publish graph works (`graph_publish`)
- [ ] Rollback works (`graph_rollback`)
- [ ] Favorite toggle works (`graph_favorite_toggle`)
- [ ] Auto-save positions works (`graph_autosave_positions`)
- [ ] Simulate graph works (`graph_simulate`)
- [ ] Set graph flags works (`graph_flag_set`)

**After Phase 2b:**
- [ ] Deploy to staging
- [ ] Monitor error_log for 7-14 days
- [ ] Verify no data corruption
- [ ] Verify transaction safety
- [ ] Verify all CRUD operations work

---

## ⚠️ Critical Notes

1. **Cross-Module Permissions:**
   - `get_graph_status` and `get_bottlenecks` use `hatthasilpa.job.ticket`
   - **DO NOT CHANGE** during refactor
   - These are used by Work Queue dashboard

2. **Router Strategy:**
   - Keep `dag_routing_api.php` as delegating router for ≥1 release
   - Monitor error_log for 30+ days before considering removal

3. **Testing Order:**
   - Phase 2a (read-only) first → test → deploy → monitor
   - Phase 2b (mutating) second → test → deploy → monitor
   - Never do both phases simultaneously

---

**Last Updated:** 2025-12-09  
**Next Update:** After Phase 2a completion

