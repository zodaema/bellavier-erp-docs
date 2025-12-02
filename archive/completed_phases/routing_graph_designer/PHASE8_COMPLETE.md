# Phase 8: Classic Integration - Complete

**Date:** November 15, 2025  
**Status:** ✅ **Complete**  
**Version:** 2.9.0

---

## 📋 **Overview**

Phase 8 integrates Classic (batch-first) production workflows into the unified production system. The system now supports both Hatthasilpa (piece-first, flexible) and Classic (batch-first, strict MO) production types within a single unified schema.

**Note:** "OEM" was renamed to "Classic" throughout the codebase for clarity and consistency.

---

## ✅ **Completed Tasks**

### **T0: Canonical Naming Migration** ✅
- **Purpose:** Migrate from legacy `hatthasilpa_*` table names to canonical names (`job_ticket`, `job_task`, etc.)
- **Status:** Complete
- **Changes:**
  - Created canonical VIEWs for existing deployments
  - Migrated all code (157 matches across 26 files) to use canonical names
  - Renamed physical tables to `*_real` for existing deployments
  - Removed compatibility VIEWs after code migration
  - Integrated canonical naming into base schema (`0001_init_tenant_schema_v2.php`)

### **T10: Database Schema - OEM Integration** ✅
- **Purpose:** Add OEM-specific columns to support batch processing
- **Status:** Complete
- **Schema Changes:**
  - `job_ticket.graph_version` (VARCHAR(20)) - Graph version tracking
  - `job_task.station_code` (VARCHAR(50)) - Station code for batch processing
  - `job_task.est_minutes` (INT) - Estimated minutes for step
  - `job_task.skip_reason`, `skipped_by`, `skipped_at` - Step skipping support
  - `wip_log.station_code` (VARCHAR(50)) - Station code in WIP logs
- **Indexes Added:**
  - `idx_graph_version` on `job_ticket`
  - `idx_station_code` on `job_task`
  - `idx_skip_info` on `job_task`
  - `idx_wip_station` on `wip_log`

### **T11: Classic API Endpoints** ✅
- **Status:** Complete
- **File:** `source/classic_api.php` (861 lines)
- **Endpoints:**
  - `ticket_create_from_graph` - Create Classic job ticket from routing graph
  - `ticket_scan` - Scan in/out events for station tracking
  - `ticket_list` - List Classic tickets with filtering
  - `ticket_get` - Get ticket details with current task info
  - `ticket_status` - Get ticket status with warnings
  - `ticket_report` - Reporting and metrics
- **Features:**
  - Topological sort for graph nodes
  - Sequence validation
  - Station WIP limit enforcement
  - Uses canonical tables (`job_ticket`, `job_task`, `wip_log`)
  - Integrated with `JobTicketStatusService` for status cascade

### **T12: Station WIP Rules** ✅
- **Status:** Complete
- **Implementation:** Integrated in `classic_api.php`
- **Rules:**
  - Sequence validation (previous step must be completed)
  - Station WIP limit checking (from `routing_node.wip_limit`)
  - Duplicate scan prevention
  - WIP warnings in `ticket_status` endpoint
- **Validation:**
  - Scan In: Checks previous step completion, WIP limit, duplicate prevention
  - Scan Out: Requires scan in first, updates task status

### **T13: UI Integration** ✅
- **Status:** Complete
- **Files Modified:**
  - `source/hatthasilpa_job_ticket.php` - Added `production_type` filter support
  - `views/hatthasilpa_job_ticket.php` - Added production type dropdown filter
  - `assets/javascripts/hatthasilpa/job_ticket.js` - Added filter handling
- **Features:**
  - Production type filter dropdown (All Types, Hatthasilpa, Classic, Hybrid)
  - Filter persists across table reloads
  - Classic tickets visible in main job ticket list

### **T14: PWA Integration** ✅
- **Status:** Complete
- **Files Modified:**
  - `source/pwa_scan_api.php` - Added Classic detection and current task info
  - `views/pwa_scan.php` - Added Classic batch scanning UI
  - `assets/javascripts/pwa_scan/pwa_scan.js` - Added Classic scan handlers
- **Features:**
  - Classic ticket detection in lookup
  - Classic batch scanning UI (scan in/out buttons)
  - Current task info display (step name, sequence, station)
  - Warnings display (sequence, WIP limit)
  - Direct integration with `classic_api.php` for scan operations

### **T15: Classic Reports** ✅
- **Status:** Complete
- **Implementation:** Integrated in `classic_api.php`
- **Features:**
  - `ticket_report` endpoint for reporting and metrics
  - Ticket statistics and station-level metrics
  - Progress tracking

### **T16: Testing & DoD** ✅
- **Status:** Complete
- **File:** `tests/Integration/ClassicIntegrationTest.php` (462 lines)
- **Test Cases:**
  - `testCreateTicketFromGraph` - Ticket creation from routing graph
  - `testScanInOutSequence` - Scan in/out workflow
  - `testSequenceEnforcement` - Sequence validation
  - `testDuplicateScanPrevention` - Duplicate scan detection
  - `testStationWipLimits` - WIP limit checking
  - `testMetricsTracking` - Metrics verification
- **Coverage:** 6 test cases covering critical Classic workflows

### **T17: Metrics & Alerts** ✅
- **Status:** Complete
- **Implementation:** Integrated in `classic_api.php`
- **Metrics Tracked:**
  - `classic_ticket_create_duration_ms` - Ticket creation duration
  - `classic_ticket_create_total` - Total tickets created
  - `classic_scan_in_duration_ms` - Scan in operation duration
  - `classic_scan_in_total` - Total scan in operations
  - `classic_scan_out_duration_ms` - Scan out operation duration
  - `classic_scan_out_total` - Total scan out operations
  - `classic_ticket_scan_duration_ms` - Overall scan operation duration
  - `classic_step_cycle_time_minutes` - Step cycle time (scan in to scan out)
  - `classic_step_p95` - P95 cycle time per station
  - `classic_sequence_violation` - Sequence validation violations
  - `classic_duplicate_scan_attempt` - Duplicate scan attempts
  - `classic_wip_limit_reached` - WIP limit violations
  - `classic_scan_out_without_in` - Scan out without scan in
- **Labels:** tenant, station_code, sequence_no, event, wip_count, wip_limit

### **T18: Rollout & Feature Flags** ✅
- **Status:** Complete
- **Implementation:** Integrated in `classic_api.php` and `FeatureFlagService.php`
- **Feature Flags:**
  - `FF_CLASSIC_MODE` - Enable Classic batch production mode (default: 'on')
  - `FF_CLASSIC_SHADOW_RUN` - Classic shadow run mode (default: 'off')
- **Integration:**
  - Feature flag check in `ticket_create_from_graph` endpoint
  - Returns 403 error if Classic mode disabled (unless shadow run enabled)
  - Feature flags managed via `FeatureFlagService`

---

## 🗄️ **Database Structure**

### **Canonical Table Names**
- `job_ticket` - Main work order (all production types)
- `job_task` - Work steps (all production types)
- `wip_log` - Event logs (all production types)
- `task_operator_session` - Operator sessions (all production types)
- `job_ticket_status_history` - Status history (all production types)

### **Production Type Column**
- `production_type` ENUM('hatthasilpa','classic','hybrid') - Distinguishes production line
- Used for filtering and logic separation (not table names)
- **Migration:** `2025_11_oem_to_classic_rename.php` updated all enum values from 'oem' to 'classic'

### **Classic-Specific Columns**
- `graph_version` - Tracks graph version used for job ticket
- `station_code` - Station identifier for batch processing
- `est_minutes` - Estimated completion time
- Skip fields - Support for skipping steps in OEM workflows

---

## 📁 **Files Modified**

### **Database Migrations**
- `database/tenant_migrations/0001_init_tenant_schema_v2.php` - **Consolidated base schema** (87 tables) with canonical names and Classic columns
  - ✅ All Phase 8 migrations consolidated into this single file
  - ✅ Canonical table names used directly (no `_real` suffix for new deployments)
  - ✅ Classic columns integrated: `graph_version`, `station_code`, `est_minutes`, skip fields
  - ✅ All legacy tables included: `mo_status_history`, `team_member_history`, `node_required_skill`, `operator_skill`, `qc_fail_attachment`, `qc_rework_log`, `qc_rework_task`
  - ✅ Performance indexes: `idx_wip_log_task_deleted`, `idx_wip_log_ticket_deleted`, `idx_station_code`, etc.
- `database/tenant_migrations/2025_11_oem_to_classic_rename.php` - **Production type enum migration**
  - ✅ Updated `production_type` enum from 'oem' to 'classic' in all tables
  - ✅ Tables updated: `job_ticket`, `routing_graph`, `routing_node`, `pattern`, `product`, `job_graph_instance`, `mo`, `team`

**Note:** All Phase 8 migration files have been consolidated and removed:
- ~~`2025_11_canonical_table_views.php`~~ → Consolidated into `0001_init_tenant_schema_v2.php`
- ~~`2025_11_oem_integration_unified.php`~~ → Consolidated into `0001_init_tenant_schema_v2.php`
- ~~`2025_11_rename_tables_to_canonical.php`~~ → Consolidated into `0001_init_tenant_schema_v2.php`
- ~~`2025_11_remove_compatibility_views.php`~~ → Consolidated into `0001_init_tenant_schema_v2.php`
- ~~`2025_11_phase8_complete_schema.php`~~ → Consolidated into `0001_init_tenant_schema_v2.php`

### **Code Migration (26 files, 157 matches)**
- `source/hatthasilpa_job_ticket.php` - 60 matches → canonical names
- `source/pwa_scan_api.php` - 27 matches → canonical names
- `source/hatthasilpa_jobs_api.php` - 10 matches → canonical names
- Service layer files (10 files) → canonical names
- Supporting API files (10 files) → canonical names

### **Classic Integration Files**
- `source/classic_api.php` - **NEW** Classic batch job ticket API (984 lines)
  - T11: 6 API endpoints (ticket_create_from_graph, ticket_scan, ticket_list, ticket_get, ticket_status, ticket_report)
  - T12: Station WIP rules (sequence validation, WIP limits, duplicate prevention)
  - T17: Metrics tracking (12 metrics)
  - T18: Feature flags support (FF_CLASSIC_MODE, FF_CLASSIC_SHADOW_RUN)
- `source/mo.php` - Updated to use 'classic' production type
- `source/team_api.php` - Updated validation for Classic
- `source/products.php` - Updated production line validation
- `source/BGERP/Service/SerialManagementService.php` - Updated for Classic
- `source/BGERP/Service/UnifiedSerialService.php` - Updated with backward compatibility
- `source/BGERP/Service/TeamExpansionService.php` - Updated for Classic
- `source/BGERP/Service/TeamService.php` - Updated validation
- `source/BGERP/Service/TeamWorkloadService.php` - Updated validation
- `source/BGERP/Service/ProductionRulesService.php` - Updated rules
- `source/BGERP/Service/FeatureFlagService.php` - Added Classic feature flags (FF_CLASSIC_MODE, FF_CLASSIC_SHADOW_RUN)
- `source/BGERP/Service/RoutingSetService.php` - Updated production types
- `source/BGERP/Service/NodeParameterService.php` - Updated valid types
- `source/BGERP/Helper/SerialSaltHelper.php` - Updated for Classic
- `source/platform_serial_salt_api.php` - Updated for Classic
- `source/storage/secrets/serial_salts.php` - Updated 'oem' → 'classic'
- `assets/javascripts/mo/mo.js` - Updated for Classic
- `views/mo.php` - Updated UI for Classic
- `tests/Integration/ClassicIntegrationTest.php` - **NEW** Integration tests (462 lines, 6 test cases)

---

## 🎯 **Key Design Decisions**

### **1. Unified Tables (Not Separate)**
- ✅ Single `job_ticket` table for all production types
- ✅ Use `production_type` column for filtering
- ✅ Benefits: Unified traceability, analytics, shared infrastructure

### **2. Canonical Naming**
- ✅ Tables use canonical names (`job_ticket`, not `hatthasilpa_job_ticket`)
- ✅ No production-line prefix in table names
- ✅ Clear and consistent naming convention

### **3. New Deployments vs Existing**
- **New deployments:** Use canonical names directly in base schema (no VIEW layer)
- **Existing deployments:** Migrated via VIEWs → physical rename → cleanup

---

## 📊 **Migration Statistics**

- **Files migrated:** 26 files
- **Matches changed:** 157 matches
- **Tables renamed:** 5 tables
- **VIEWs created:** 5 canonical VIEWs (temporary, for existing deployments only)
- **VIEWs removed:** 5 compatibility VIEWs (after cleanup)
- **Syntax check:** ✅ All files pass PHP syntax check
- **Migration consolidation:** ✅ All Phase 8 migrations consolidated into `0001_init_tenant_schema_v2.php`
- **Total tables in schema:** 87 tables (includes all features + legacy tables)
- **Cleanup completed:** ✅ Removed redundant migration files and documentation

---

## ✅ **Verification**

### **Database Structure**
```sql
-- Check canonical tables
SHOW TABLES LIKE 'job_%';
-- Should show: job_ticket, job_task, wip_log, task_operator_session, job_ticket_status_history

-- Check OEM columns
SHOW COLUMNS FROM job_ticket LIKE 'graph_version';
SHOW COLUMNS FROM job_task LIKE 'station_code';
SHOW COLUMNS FROM wip_log LIKE 'station_code';
```

### **Code Status**
- ✅ All code uses canonical names (`job_ticket`, `job_task`, etc.)
- ✅ No `hatthasilpa_*` references in new code
- ✅ All foreign keys reference canonical names
- ✅ Migration tracking updated

---

## 📚 **Related Documentation**

- `docs/database/DB_NAMING_POLICY.md` - Database naming policy
- `docs/routing_graph_designer/PHASE7_10_TASK_BOARD.md` - Task board
- `docs/production/01-design/DUAL_PRODUCTION_MODEL_DESIGN.md` - Production model design

---

## 🚀 **Next Steps**

1. **Future Enhancements:**
   - Classic-specific reporting dashboard
   - Station performance metrics visualization
   - WIP limit optimization recommendations
   - Batch size optimization
   - Aging detection alerts
   - Throughput calculation enhancements
2. **Future:** Consider renaming `*_real` tables to canonical names (6-12 months)

---

## 📝 **Migration Notes**

### **OEM → Classic Rename**
- All references to "OEM" renamed to "Classic" throughout codebase
- Database enum values updated via migration `2025_11_oem_to_classic_rename.php`
- Serial salt backward compatibility maintained for existing serials
- No breaking changes for existing data

### **Serial Salts Migration**
- `serial_salts.php` updated: 'oem' → 'classic'
- `UnifiedSerialService.php` maintains backward compatibility
- Old serials with 'oem' production_type still verify correctly
- New serials use 'classic' production_type

---

**Last Updated:** November 15, 2025 (Updated: Phase 8 Classic Integration Complete - All Tasks Finished)  
**Status:** ✅ **Phase 8 100% Complete**  
**Schema Status:** ✅ **87 tables consolidated** - Ready for production deployment  
**Code Status:** ✅ **Complete** - All T11-T18 tasks finished  
**Testing Status:** ✅ **Complete** - 6 integration tests created  
**Metrics Status:** ✅ **Complete** - 12 metrics tracked  
**Feature Flags Status:** ✅ **Complete** - 2 flags implemented  
**Next Phase:** Phase 9 (People System Integration) or Phase 10 (Production Dashboard Integration)

