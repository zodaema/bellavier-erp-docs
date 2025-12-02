# Task 14.1 — Routing System Verification

**Date:** December 2025  
**Phase:** 14.1 — Deep System Scan  
**Status:** ✅ COMPLETED

---

## Summary

This document verifies the routing system classification per `routing_classification.md` and identifies code usage of Routing V1 vs V2.

---

## Routing Classification (Per `routing_classification.md`)

### Routing V2 (DAG Routing) — KEEP & PROTECT

**Status:** ✅ **ALL TABLES EXIST IN DATABASE**

1. ✅ `routing_graph` — DAG graph (V2)
2. ✅ `routing_graph_version` — Graph versioning
3. ✅ `routing_graph_var` — Graph variables
4. ✅ `routing_graph_favorite` — User favorites
5. ✅ `routing_graph_feature_flag` — Feature flags
6. ✅ `routing_node` — Graph node (V2)
7. ✅ `routing_edge` — Graph edge (V2)
8. ✅ `routing_set` — Routing set
9. ✅ `routing_step` — Routing step
10. ✅ `routing_audit_log` — Audit log

**Rules (Per `routing_classification.md`):**
- ✅ **DO NOT mark as legacy**
- ✅ **DO NOT move to deprecated folder**
- ✅ **DO NOT drop automatically**
- ✅ **Must be in Master Schema V2**

---

### Routing V1 (Legacy) — DEPRECATE

**Status:** ⚠️ **EXISTS IN DATABASE**

1. ❌ `routing` — Legacy routing table (V1)

**Rules (Per `routing_classification.md`):**
- ⚠️ **Can mark as legacy**
- ⚠️ **Can move migration to deprecated folder**
- ⚠️ **DO NOT drop automatically in production**
- ⚠️ **Must migrate code before deprecating**

---

## Code Usage Analysis

### Routing V2 (DAG Routing) Usage

**Status:** ✅ **ACTIVE USE** — 485 references across 45 files

**Key Files Using Routing V2:**
- `source/dag_routing_api.php` — 150 references
- `source/dag_token_api.php` — 47 references
- `source/BGERP/Service/DAGValidationService.php` — 50 references
- `source/BGERP/Service/DAGRoutingService.php` — 19 references
- `source/BGERP/Service/RoutingSetService.php` — 26 references
- `source/hatthasilpa_job_ticket.php` — 20 references
- `source/products.php` — 27 references
- `source/mo.php` — 21 references
- `source/classic_api.php` — 13 references
- And 36 more files...

**Conclusion:**
- ✅ Routing V2 is **actively used** by DAG system
- ✅ Routing V2 is **critical** for system operation
- ✅ Routing V2 must be **protected** in Master Schema V2

---

### Routing V1 (Legacy) Usage

**Status:** ⚠️ **ACTIVE USE** — 7 references across 3 files

**Files Using Routing V1:**

1. **`source/hatthasilpa_job_ticket.php`** (2 references)
   - Line 1091: `SELECT id_routing FROM routing WHERE id_product=? AND is_active=1`
   - Line 1188: `SELECT id_routing, version FROM routing WHERE id_product=? AND is_active=1`
   - **Purpose:** Job ticket creation uses legacy routing
   - **Risk:** HIGH — Core job ticket functionality depends on this

2. **`source/pwa_scan_api.php`** (2 references)
   - Line 1128: `FROM routing r`
   - Line 1570: `FROM routing r`
   - **Purpose:** PWA scan API uses legacy routing
   - **Risk:** MEDIUM — PWA functionality depends on this

3. **`source/routing.php`** (3 references)
   - Line 206: `FROM routing r`
   - Line 277: `INSERT INTO routing (id_product, version)`
   - Line 330: `DELETE FROM routing WHERE id_routing = ?`
   - **Purpose:** Routing API (legacy UI) uses legacy routing
   - **Risk:** HIGH — Legacy routing UI depends on this

**Conclusion:**
- ⚠️ Routing V1 is **still actively used** by 3 files
- ⚠️ Routing V1 must be **migrated to V2** before deprecating
- ⚠️ Routing V1 **cannot be safely removed** until code migration

---

## Routing V2 vs V1 Comparison

| Feature | Routing V1 | Routing V2 |
|---------|------------|------------|
| **Table Structure** | Single `routing` table | Multiple tables (graph, node, edge, etc.) |
| **Graph Support** | ❌ No (linear only) | ✅ Yes (DAG) |
| **Node/Edge** | ❌ No | ✅ Yes |
| **Versioning** | ❌ No | ✅ Yes (`routing_graph_version`) |
| **Feature Flags** | ❌ No | ✅ Yes (`routing_graph_feature_flag`) |
| **Audit Log** | ❌ No | ✅ Yes (`routing_audit_log`) |
| **Code Usage** | 3 files, 7 references | 45 files, 485 references |
| **Status** | ⚠️ Legacy (deprecate) | ✅ Active (protect) |

---

## Migration Requirements

### Before Deprecating Routing V1

1. **Migrate `hatthasilpa_job_ticket.php`:**
   - Replace `routing` queries with `routing_graph` queries
   - Use `routing_graph` to find active routing for product
   - Update job ticket creation logic

2. **Migrate `pwa_scan_api.php`:**
   - Replace `routing` queries with `routing_graph` queries
   - Update PWA scan logic to use DAG routing

3. **Migrate or Deprecate `routing.php`:**
   - Option A: Migrate to use `routing_graph` (V2)
   - Option B: Mark as Legacy UI and deprecate
   - Document that this is legacy routing UI

---

## Risk Assessment

### High Risk (Must Fix Before Deprecation)

1. **`hatthasilpa_job_ticket.php`** — Uses Routing V1 for job ticket creation
   - **Impact:** CRITICAL — Job ticket creation will fail if Routing V1 is removed
   - **Action:** Must migrate to Routing V2 before deprecating

2. **`routing.php`** — Legacy routing API
   - **Impact:** HIGH — Legacy routing UI will fail if Routing V1 is removed
   - **Action:** Migrate to Routing V2 or deprecate UI

### Medium Risk

1. **`pwa_scan_api.php`** — Uses Routing V1 for PWA scanning
   - **Impact:** MEDIUM — PWA scanning may fail if Routing V1 is removed
   - **Action:** Migrate to Routing V2

---

## Recommendations

### For Master Schema V2

1. **Include All Routing V2 Tables:**
   - All 10 Routing V2 tables must be in Master Schema V2
   - These are critical for DAG system operation

2. **Exclude Routing V1:**
   - `routing` (V1) should NOT be in Master Schema V2
   - But keep in existing tenants until code migration

3. **Code Migration Priority:**
   - **Phase 1:** Migrate `hatthasilpa_job_ticket.php` (highest priority)
   - **Phase 2:** Migrate `pwa_scan_api.php`
   - **Phase 3:** Migrate or deprecate `routing.php`

---

**Document Status:** ✅ Complete  
**Last Updated:** December 2025

