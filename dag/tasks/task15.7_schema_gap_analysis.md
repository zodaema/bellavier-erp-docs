# Schema Gap Analysis — bgerp_t_maison_atelier vs 0001_init_tenant_schema_v2.php

**Date:** 2025-12-22  
**Comparison:** `bgerp_t_maison_atelier` (template DB) vs `0001_init_tenant_schema_v2.php`

---

## EXECUTIVE SUMMARY

**Critical Finding:** `0001_init_tenant_schema_v2.php` is **missing 41 tables** that exist in the canonical template database `bgerp_t_maison_atelier`.

- **Template DB:** 123 tables
- **init_tenant_schema_v2.php:** 82 tables
- **Missing:** 41 tables (33% of template)
- **Extra in init:** 0 tables (all tables in init exist in template)

---

## MISSING TABLES BREAKDOWN

### ⚠️ CRITICAL — Component Serial System (9 tables)

**Impact:** Component binding & serial tracking system is completely missing

1. `component_type` — Component type definitions (EDGE_PIECE, BODY_PANEL, STRAP)
2. `component_master` — Component master items (design-level components)
3. `component_serial_batch` — Batch records for serial generation
4. `component_serial_pool` — Daily running number pool for serial generation
5. `component_serial` — Individual component serial numbers with status
6. `component_serial_binding` — Component-to-token bindings (Phase 3.1)
7. `component_bom_map` — Component-to-BOM mapping
8. `component_serial_allocation` — Serial allocation tracking
9. `component_serial_usage_log` — Serial usage audit log

**Dependencies:**
- References: `flow_token`, `routing_node`, `work_center`
- Referenced by: Traceability system, BOM system

**Recommendation:** ⚠️ **MUST ADD** — Core feature for Hatthasilpa production line

---

### ⚠️ HIGH PRIORITY — Work Center Behavior System (3 tables)

**Impact:** Work center behavior mapping is missing (CUT, STITCH, EDGE, QC)

1. `work_center_behavior` — Behavior definitions (CUT, STITCH, EDGE, QC, etc.)
2. `work_center_behavior_map` — Work center ↔ Behavior mappings
3. `dag_behavior_log` — Behavior execution audit log

**Dependencies:**
- References: `work_center`, `routing_node`
- Referenced by: Token engine, behavior execution API

**Recommendation:** ⚠️ **MUST ADD** — Required for Task 14 (Behavior Engine)

---

### 🔹 HIGH PRIORITY — Traceability System (5 tables)

**Impact:** Product traceability features are missing

1. `trace_access_log` — Trace access audit log
2. `trace_export_job` — Trace export job tracking
3. `trace_note` — Trace notes & annotations
4. `trace_reconcile_log` — Trace reconciliation log
5. `trace_share_link` — Shareable trace links

**Dependencies:**
- References: `flow_token`, `component_serial`
- Referenced by: Traceability API, export features

**Recommendation:** ⚠️ **MUST ADD** — Core feature for traceability compliance

---

### 🔹 MEDIUM PRIORITY — Feature Flag System (1 table)

**Impact:** Feature flag management is missing

1. `feature_flag` — System-wide feature flags (key/value pairs)

**Note:** `tenant_feature_flags` exists in init, but `feature_flag` (system-level) is missing

**Dependencies:**
- Referenced by: Feature flag API, routing graph feature flags

**Recommendation:** ⚠️ **SHOULD ADD** — Required for feature rollout control

---

### 🔹 MEDIUM PRIORITY — Graph Binding System (3 tables)

**Impact:** Product-graph binding and subgraph system is missing

1. `product_graph_binding` — Product ↔ Routing graph bindings
2. `product_graph_binding_audit` — Binding change audit log
3. `graph_subgraph_binding` — Graph-to-subgraph bindings (nested graphs)

**Dependencies:**
- References: `product`, `routing_graph`
- Referenced by: Product management, graph designer

**Recommendation:** 🔹 **SHOULD ADD** — Required for multi-product graph management

---

### 🔹 MEDIUM PRIORITY — People Cache System (5 tables)

**Impact:** People service cache tables are missing

1. `people_availability_cache` — Availability cache from People Service
2. `people_operator_cache` — Operator cache from People Service
3. `people_team_cache` — Team cache from People Service
4. `people_masking_policy` — Data masking policy
5. `people_sync_error_log` — People sync error log

**Dependencies:**
- References: External People Service
- Referenced by: Assignment engine, team availability

**Recommendation:** 🔸 **OPTIONAL** — Can be added later if People Service integration is needed

---

### 🔸 LOW PRIORITY — Routing & Graph Drafts (2 tables)

**Impact:** Draft routing system is missing

1. `routing_graph_draft` — Draft versions of routing graphs
2. `routing_v1_usage_log` — V1 routing usage tracking (fallback monitoring)

**Recommendation:** 🔸 **OPTIONAL** — Add if draft/versioning feature is needed

---

### 🔸 LOW PRIORITY — Analytics & Materialized Views (5 tables)

**Impact:** Pre-computed analytics tables are missing

1. `mv_cycle_time_analytics` — Cycle time analytics (materialized view)
2. `mv_dashboard_trends` — Dashboard trends (materialized view)
3. `mv_node_bottlenecks` — Node bottleneck analysis (materialized view)
4. `mv_team_workload` — Team workload analysis (materialized view)
5. `mv_token_flow_summary` — Token flow summary (materialized view)

**Note:** These are likely materialized views for performance optimization

**Recommendation:** 🔸 **OPTIONAL** — Add if analytics performance is needed

---

### 🔸 LOW PRIORITY — Team History (1 table)

**Impact:** Team membership history is missing

1. `team_member_history` — Historical team membership records

**Note:** Current system has `team_member` but no history tracking

**Recommendation:** 🔸 **OPTIONAL** — Add if audit history is required

---

### 🔸 LOW PRIORITY — Legacy & Domain-Specific (6 tables)

**Impact:** Domain-specific or legacy tables

1. `account` — Account/GL system (may be legacy)
2. `cut_batch` — Leather cutting batch tracking
3. `leather_sheet` — Leather sheet inventory
4. `leather_sheet_usage_log` — Leather usage tracking
5. `leather_cut_bom_log` — Leather BOM audit log
6. `legacy_cleanup_tracking` — Legacy cleanup tracking (migration helper)

**Recommendation:** 🔸 **OPTIONAL** — Add only if specific to Hatthasilpa production

---

### ℹ️ VIEWS (NOT TABLES)

1. `hatthasilpa_supplier_score` — VIEW (points to `supplier_score` table, which exists in init)

**Recommendation:** ℹ️ **CREATE VIEW** — Add as view definition, not table

---

## RECOMMENDED ACTION PLAN

### Phase 1: CRITICAL (Must Add Now)

Add these tables to `0001_init_tenant_schema_v2.php`:

1. **Component Serial System (9 tables)**
   - `component_type`
   - `component_master`
   - `component_serial_batch`
   - `component_serial_pool`
   - `component_serial`
   - `component_serial_binding`
   - `component_bom_map`
   - `component_serial_allocation`
   - `component_serial_usage_log`

2. **Work Center Behavior System (3 tables)**
   - `work_center_behavior`
   - `work_center_behavior_map`
   - `dag_behavior_log`

3. **Traceability System (5 tables)**
   - `trace_access_log`
   - `trace_export_job`
   - `trace_note`
   - `trace_reconcile_log`
   - `trace_share_link`

4. **Feature Flag (1 table)**
   - `feature_flag`

**Total: 18 tables (CRITICAL)**

---

### Phase 2: HIGH PRIORITY (Should Add Soon)

1. **Graph Binding System (3 tables)**
   - `product_graph_binding`
   - `product_graph_binding_audit`
   - `graph_subgraph_binding`

2. **Team History (1 table)**
   - `team_member_history`

**Total: 4 tables**

---

### Phase 3: OPTIONAL (Add as Needed)

1. **People Cache System (5 tables)** — Add if People Service integration is implemented
2. **Routing Drafts (2 tables)** — Add if draft feature is needed
3. **Analytics MVs (5 tables)** — Add if performance optimization is needed
4. **Legacy & Domain (6 tables)** — Add only if specific to production requirements

**Total: 18 tables (OPTIONAL)**

---

## NEXT STEPS

### Option 1: Add All Critical Tables Now (Recommended)

1. Extract CREATE TABLE statements from `bgerp_t_maison_atelier` for 18 critical tables
2. Add them to `0001_init_tenant_schema_v2.php` in correct dependency order
3. Create a new migration `2025_12_add_missing_critical_tables.php` for existing tenants
4. Update `0002_seed_data.php` to seed `component_type` and `work_center_behavior`

### Option 2: Minimal Critical Only

Add only Component Serial (9) + Behavior (3) = 12 tables for immediate production needs

### Option 3: Full Alignment

Add all 41 tables to ensure 100% alignment with template DB

---

## IMPACT ASSESSMENT

### Without Critical Tables

- ❌ Component binding feature will fail (no tables to bind components)
- ❌ Behavior execution will fail (no behavior definitions)
- ❌ Traceability exports will fail (no trace tables)
- ❌ Feature flags won't work (no system flag table)

### With Critical Tables

- ✅ Component serial system operational
- ✅ Behavior engine operational (Task 14)
- ✅ Traceability system operational
- ✅ Feature flag management operational

---

## CONCLUSION

**Recommendation:** Proceed with **Phase 1 (18 critical tables)** immediately to ensure system alignment with template DB and avoid production issues.

The gap is significant (41 tables / 33% of template) and includes **core production features** that are already implemented in the template but missing from the init script.


