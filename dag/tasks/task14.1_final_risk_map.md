# Task 14.1 — Final Risk Map (Pre-Task 14.2)

**Date:** December 2025  
**Phase:** 14.1 — Deep System Scan  
**Status:** ✅ COMPLETED

---

## Summary

This document provides a comprehensive risk map before starting Task 14.2 (Migration Rewrite). It consolidates all findings from the deep system scan and identifies critical risks and workload.

---

## Executive Summary

**Total Legacy Tables Found:** 6 tables  
**Total Code References:** 26 files, 36+ references  
**Risk Level:** ⚠️ **HIGH** — Multiple critical systems depend on legacy tables

**Recommendation:** **DO NOT proceed with Task 14.2 until code migration is complete.**

---

## Legacy Tables Status

### V1 Tables That Can Be Safely Deprecated

| Table | Code Usage | Risk | Status |
|-------|------------|------|--------|
| `uom` | 0 references | ✅ LOW | **SAFE TO DEPRECATE** |

### V1 Tables That Must Be Migrated First

| Table | Code Usage | Risk | Status |
|-------|------------|------|--------|
| `stock_item` | 5 files, 11 references | 🔴 CRITICAL | **MUST MIGRATE FIRST** |
| `bom_line` | 5 files, 8 references | 🔴 CRITICAL | **MUST MIGRATE FIRST** |
| `routing` (V1) | 3 files, 7 references | 🔴 HIGH | **MUST MIGRATE FIRST** |
| `stock_item_asset` | Unknown | 🟡 MEDIUM | **VERIFY USAGE** |
| `stock_item_lot` | Unknown | 🟡 MEDIUM | **VERIFY USAGE** |

---

## Critical Risk Areas

### 1. Stock Pipeline (CRITICAL RISK)

**Legacy Table:** `stock_item`  
**Files Affected:** 5 files, 11 references

**Critical Files:**
- `source/leather_grn.php` — 4 references (GRN Leather)
- `source/BGERP/Helper/MaterialResolver.php` — 1 reference (Core helper)
- `source/bom.php` — 3 references (BOM API)
- `source/trace_api.php` — 2 references (Trace API)
- `source/leather_cut_bom_api.php` — 1 reference (CUT BOM)

**Impact:**
- 🔴 **CRITICAL** — Core material pipeline depends on `stock_item`
- 🔴 **CRITICAL** — GRN Leather will fail if `stock_item` is removed
- 🔴 **CRITICAL** — Material resolution will fail if `stock_item` is removed

**Action Required:**
- **MUST migrate all 5 files** from `stock_item` → `material` before deprecating
- **Priority:** HIGHEST

---

### 2. BOM Pipeline (CRITICAL RISK)

**Legacy Table:** `bom_line`  
**Files Affected:** 5 files, 8 references

**Critical Files:**
- `source/leather_cut_bom_api.php` — 4 references (CUT BOM)
- `source/BGERP/Helper/MaterialResolver.php` — 1 reference (Core helper)
- `source/bom.php` — 1 reference (BOM API)
- `source/BGERP/Component/ComponentAllocationService.php` — 1 reference
- `source/component.php` — 1 reference

**Impact:**
- 🔴 **CRITICAL** — CUT BOM will fail if `bom_line` is removed
- 🔴 **CRITICAL** — Material resolution will fail if `bom_line` is removed
- 🔴 **HIGH** — BOM functionality will fail if `bom_line` is removed

**Action Required:**
- **MUST migrate all 5 files** from `bom_line` → `bom` + `bom_item` before deprecating
- **Priority:** HIGH

---

### 3. Routing System (HIGH RISK)

**Legacy Table:** `routing` (V1)  
**Files Affected:** 3 files, 7 references

**Critical Files:**
- `source/hatthasilpa_job_ticket.php` — 2 references (Job ticket creation)
- `source/routing.php` — 3 references (Legacy routing API)
- `source/pwa_scan_api.php` — 2 references (PWA scan)

**Impact:**
- 🔴 **HIGH** — Job ticket creation will fail if `routing` (V1) is removed
- 🔴 **HIGH** — Legacy routing UI will fail if `routing` (V1) is removed
- 🟡 **MEDIUM** — PWA scan may fail if `routing` (V1) is removed

**Action Required:**
- **MUST migrate all 3 files** from `routing` (V1) → `routing_graph` (V2) before deprecating
- **Priority:** HIGH

---

## V2 Tables That Must Be Protected

### Routing V2 (DAG Routing)

**Status:** ✅ **MUST PROTECT** — Per `routing_classification.md`

**Tables:**
- `routing_graph`, `routing_graph_version`, `routing_graph_var`
- `routing_graph_favorite`, `routing_graph_feature_flag`
- `routing_node`, `routing_edge`, `routing_set`, `routing_step`
- `routing_audit_log`

**Usage:** 45 files, 485 references  
**Risk if Removed:** 🔴 **CRITICAL** — DAG system will fail

---

### Stock V2

**Status:** ✅ **MUST PROTECT**

**Tables:**
- `material`, `material_lot`, `material_asset`
- `stock_ledger` — **CRITICAL** (actively used by 6+ files)

**Usage:** Multiple files  
**Risk if Removed:** 🔴 **CRITICAL** — Stock system will fail

---

### BOM V2

**Status:** ✅ **MUST PROTECT**

**Tables:**
- `bom`, `bom_item`

**Usage:** BOM Service, BOM API  
**Risk if Removed:** 🔴 **CRITICAL** — BOM system will fail

---

## Workload Estimate for Task 14.2

### Code Migration Required

**Total Files to Migrate:** 13 files

1. **Stock Pipeline Migration (5 files):**
   - `source/leather_grn.php` — HIGH priority
   - `source/BGERP/Helper/MaterialResolver.php` — HIGHEST priority
   - `source/bom.php` — HIGH priority
   - `source/trace_api.php` — MEDIUM priority
   - `source/leather_cut_bom_api.php` — MEDIUM priority

2. **BOM Pipeline Migration (5 files):**
   - `source/leather_cut_bom_api.php` — HIGH priority
   - `source/BGERP/Helper/MaterialResolver.php` — HIGHEST priority
   - `source/bom.php` — HIGH priority
   - `source/BGERP/Component/ComponentAllocationService.php` — MEDIUM priority
   - `source/component.php` — MEDIUM priority

3. **Routing Migration (3 files):**
   - `source/hatthasilpa_job_ticket.php` — HIGH priority
   - `source/routing.php` — HIGH priority (or deprecate UI)
   - `source/pwa_scan_api.php` — MEDIUM priority

**Estimated Effort:** 2-3 days for code migration

---

## Migration Strategy

### Phase 1: Code Migration (Before Task 14.2)

1. **Migrate Stock Pipeline:**
   - Start with `MaterialResolver.php` (core helper)
   - Then `leather_grn.php` (critical GRN flow)
   - Then `bom.php`, `trace_api.php`, `leather_cut_bom_api.php`

2. **Migrate BOM Pipeline:**
   - Start with `MaterialResolver.php` (core helper)
   - Then `leather_cut_bom_api.php` (critical CUT flow)
   - Then `bom.php`, `ComponentAllocationService.php`, `component.php`

3. **Migrate Routing:**
   - Start with `hatthasilpa_job_ticket.php` (critical job creation)
   - Then `routing.php` (legacy UI - migrate or deprecate)
   - Then `pwa_scan_api.php`

### Phase 2: Master Schema V2 (Task 14.2)

1. **Create Master Schema V2:**
   - Include all V2 tables
   - Exclude all V1 legacy tables
   - Test on new tenant

2. **Update Bootstrap Scripts:**
   - Skip deprecated migrations
   - Use Master Schema V2 for new tenants

### Phase 3: Deprecation (After Task 14.2)

1. **Mark Legacy Migrations:**
   - Move to `*_deprecated/` folder
   - Update documentation

2. **Clean Up Legacy Tables:**
   - Manual cleanup in existing tenants (if needed)
   - Document cleanup procedures

---

## Risk Mitigation

### Before Starting Task 14.2

1. ✅ **Complete Code Migration:**
   - All 13 files must be migrated from V1 → V2
   - Test thoroughly after migration

2. ✅ **Verify V2 Tables:**
   - Ensure all V2 tables exist and work correctly
   - Test critical flows (GRN, CUT, BOM, Job Ticket)

3. ✅ **Backup Existing Tenants:**
   - Backup before any schema changes
   - Test on dev tenant first

### During Task 14.2

1. ⚠️ **Create Master Schema V2:**
   - Include only V2 tables
   - Exclude all V1 legacy tables
   - Test on new tenant

2. ⚠️ **Update Bootstrap:**
   - Ensure new tenants use Master Schema V2 only
   - Existing tenants keep current schema

### After Task 14.2

1. ⚠️ **Monitor System:**
   - Watch for any issues with V2 tables
   - Verify all critical flows work

2. ⚠️ **Document Changes:**
   - Update migration documentation
   - Document deprecation status

---

## Acceptance Criteria for Task 14.2

Before starting Task 14.2, ensure:

1. ✅ **Code Migration Complete:**
   - All 13 files migrated from V1 → V2
   - All tests passing

2. ✅ **V2 Tables Verified:**
   - All V2 tables exist and work
   - Critical flows tested

3. ✅ **Legacy Tables Safe to Deprecate:**
   - No code references to legacy tables
   - Legacy tables can be excluded from Master Schema V2

---

## Conclusion

**Current Status:** ⚠️ **NOT READY FOR TASK 14.2**

**Blockers:**
1. 🔴 Code migration not complete (13 files need migration)
2. 🔴 Legacy tables still actively used
3. 🔴 Risk of breaking critical systems if Task 14.2 proceeds

**Recommendation:**
- **DO NOT proceed with Task 14.2** until code migration is complete
- **Complete Phase 1 (Code Migration)** first
- **Then proceed with Task 14.2 (Master Schema V2)**

---

**Document Status:** ✅ Complete  
**Last Updated:** December 2025

