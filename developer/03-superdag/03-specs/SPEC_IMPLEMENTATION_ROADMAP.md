# Implementation Roadmap

**Bellavier Group ERP – DAG System**

This document is the top-level execution plan that coordinates all domain specs into a phased implementation roadmap.

---

## Overview

This roadmap organizes implementation tasks across 7 domain specs into 4 phases. Each phase builds on previous phases, ensuring stable foundations before adding complexity.

**Domain Specs:**
1. [SPEC_WORK_CENTER_BEHAVIOR.md](SPEC_WORK_CENTER_BEHAVIOR.md) - Work Center Behavior
2. [SPEC_TOKEN_ENGINE.md](SPEC_TOKEN_ENGINE.md) - Token Engine
3. [SPEC_TIME_ENGINE.md](SPEC_TIME_ENGINE.md) - Time Engine
4. [SPEC_COMPONENT_SERIAL_BINDING.md](SPEC_COMPONENT_SERIAL_BINDING.md) - Component Serial Binding
5. [SPEC_QC_SYSTEM.md](SPEC_QC_SYSTEM.md) - QC System
6. [SPEC_PWA_CLASSIC_FLOW.md](SPEC_PWA_CLASSIC_FLOW.md) - PWA Classic Flow
7. [SPEC_LEATHER_STOCK_REALITY.md](SPEC_LEATHER_STOCK_REALITY.md) - Leather Stock Reality

**Principles:**
- Foundations first (Work Center Behavior, Token Engine, Time Engine)
- Hatthasilpa flow before Classic/PWA integration
- Leather Reality Layer last (depends on CUT node behavior)

---

## Phase 1 – Foundations

**Goal:** Establish core infrastructure for Work Center Behavior, Token Engine, and Time Engine.

**Prerequisites:** None

**Tasks:**

1. **WC-01:** Create `work_center_behavior` table and seed presets
   - Migration: `database/tenant_migrations/YYYY_MM_work_center_behavior.php`
   - Seed: CUT, EDGE, STITCH, QC_FINAL, HARDWARE_ASSEMBLY, QC_REPAIR
   - **Dependency:** None

2. **WC-02:** Create `work_center_behavior_map` table
   - Migration: `database/tenant_migrations/YYYY_MM_work_center_behavior_map.php`
   - Foreign keys to `work_center` and `work_center_behavior`
   - **Dependency:** WC-01

3. **T-01:** Document current DB structure for tokens
   - Review existing `flow_token` schema
   - Document current status enum values
   - Document current token_type enum values
   - **Dependency:** None

4. **T-02:** Design extensions for batch/single split
   - Add `batch_session_id`, `planned_qty`, `actual_qty`, `scrap_qty` fields
   - Design split logic: batch token → N single tokens
   - Preserve batch metadata in child tokens
   - **Dependency:** T-01

5. **TE-01:** Stabilize core time storage (already done – refer to existing tasks)
   - `WorkSessionTimeEngine::calculateTimer()` is single source of truth
   - `TokenWorkSessionService` handles start/pause/resume
   - Reference: `docs/time-engine/tasks/task1_TIME_ENGINE_V2_CORE_ENGINE_COMPLETE.md`
   - **Dependency:** None (already completed)

6. **TE-02:** Implement over-limit detection based on behavior
   - Service: `TimeEngineOverLimitService::checkOverLimit(int $tokenId, int $expectedDuration)`
   - Compares current work_seconds with threshold (1.5x expected)
   - Sets `over_limit_flag` in session
   - **Dependency:** TE-01, WC-01 (needs `default_expected_duration`)

**Phase 1 Deliverables:**
- Work Center Behavior tables and presets
- Token Engine extensions designed
- Time Engine over-limit detection
- Foundation for Phase 2

---

## Phase 2 – Hatthasilpa Flow

**Goal:** Complete Hatthasilpa single-piece flow with Work Queue integration, basic QC, and minimal component binding.

**Prerequisites:** Phase 1 complete

**Tasks:**

1. **WC-03:** Implement mapping UI in `/work_centers` to attach behavior
   - Screen: Work Center management page
   - Action: Select behavior from dropdown
   - Store mapping in `work_center_behavior_map`
   - **Dependency:** WC-01, WC-02

2. **WC-04:** Integrate behavior into work_queue rendering
   - Load behavior for each node's work center
   - Use `ui_template_code` to select UI template
   - Use `requires_quantity_input` to show/hide quantity field
   - Use `execution_mode` to determine batch vs single dialog
   - **Dependency:** WC-03

3. **WC-05:** Add over-limit hint using `default_expected_duration`
   - In work_queue, compare actual time vs `default_expected_duration`
   - Show warning if exceeded threshold (e.g., 150% of expected)
   - **Dependency:** WC-04, TE-02

4. **T-03:** Add API contracts for token state transitions
   - `token_start` → READY → ACTIVE
   - `token_pause` → ACTIVE → PAUSED
   - `token_resume` → PAUSED → ACTIVE
   - `token_complete` → ACTIVE → COMPLETED → Next node
   - **Dependency:** T-02

5. **T-04:** Implement batch split logic
   - Service: `TokenSplitService::splitBatchToken(int $batchTokenId, int $actualQty)`
   - Creates N single tokens from batch token
   - Links via `parent_token_id` and `child_tokens` JSON
   - **Dependency:** T-03

6. **TE-03:** Add conflict checker (1 worker → 1 active token)
   - Service: `TimeEngineConflictService::checkActiveSession(int $operatorUserId)`
   - Prevents starting second job if active session exists
   - **Dependency:** TE-02

7. **Q-01:** Define QC data model and defect catalog
   - Create `defect_catalog` table
   - Seed common defect codes (CUT02, EP01, SEW05, ASSEMBLE01, QC01)
   - Create `token_qc_result` table
   - Migration: `database/tenant_migrations/YYYY_MM_qc_system.php`
   - **Dependency:** None

8. **Q-02:** Attach QC behavior to specific nodes
   - Extend `routing_node` table:
     - Add `qc_policy` JSON field (if not exists)
   - Link QC nodes to `work_center_behavior` (QC_FINAL, QC_REPAIR)
   - **Dependency:** Q-01, WC-01

9. **C-01:** Finalize DB model for component serial links
   - Review existing `job_component_serial` table (Task 13)
   - Document current structure
   - **Dependency:** None (already exists)

10. **C-02:** Define APIs for bind/unbind/list
    - `hatthasilpa_component_api.php` (existing - Task 13):
      - `bind_component_serial` - Create binding
      - `get_component_serials` - List bindings
      - `get_component_panel` - UI panel data
    - **Dependency:** C-01 (already exists)

**Phase 2 Deliverables:**
- Work Queue integrated with Work Center Behavior
- Token Engine batch split functional
- Time Engine conflict checking
- Basic QC system (defect catalog, QC results)
- Component binding APIs (read/write)

---

## Phase 3 – Classic/PWA Integration

**Goal:** Normalize PWA scan flow, align Token + QC with Classic line, and complete QC integration.

**Prerequisites:** Phase 2 complete

**Tasks:**

1. **PWA-01:** Document current PWA DB/API
   - Review existing `wip_log` table structure
   - Document `classic_api.php` scan endpoints
   - Document `pwa_scan_api.php` (if separate)
   - **Dependency:** None

2. **PWA-02:** Standardize scan event types
   - Define scan event enum: 'scan_in', 'scan_out', 'scan_error'
   - Map to existing `wip_log.event_type` values
   - Add `scan_error_type` field to `wip_log`
   - **Dependency:** PWA-01

3. **PWA-03:** Implement error recovery patterns
   - Service: `PWAScanErrorService::detectError(string $tokenSerial, string $stationCode, int $sequenceNo)`
   - Error types: REVERSE_SCAN, MISSING_SCAN, DUPLICATE_SCAN
   - Recovery: Manual override with audit log
   - **Dependency:** PWA-02

4. **PWA-04:** Integrate with trace reports
   - Extend `trace_api.php` to show scan events
   - Display scan timeline (scan_in → work → scan_out)
   - Show scan errors and recovery actions
   - **Dependency:** PWA-03

5. **PWA-05:** Add safe-scan validation
   - Service: `PWAScanValidationService::validateScan(int $tokenId, string $stationCode, int $sequenceNo)`
   - Checks: Token at correct node, previous step completed, no duplicate scans
   - **Dependency:** PWA-03

6. **PWA-06:** Token Engine integration
   - Map scan events to token state transitions:
     - scan_in → Token enters node (status='active')
     - scan_out → Token completes node (status='completed')
   - Use same token model as Hatthasilpa (different entry point)
   - **Dependency:** PWA-05, T-03

7. **Q-03:** Integrate QC with token engine and trace API
   - Extend `dag_token_api.php`:
     - `token_qc_pass` action → Creates QC result, routes token forward
     - `token_qc_fail` action → Creates QC result, routes token to rework
   - Extend `trace_api.php`:
     - Show QC results in token timeline
     - Display defect codes and rework history
   - **Dependency:** Q-02, T-03

8. **Q-04:** Add QC dashboards (data needs only)
   - QC metrics query:
     - Pass rate by node
     - Defect frequency by code
     - Rework rate by node
     - Component completeness failure rate
   - **Dependency:** Q-03

9. **Q-05:** Implement multi-level QC routing logic
   - Service: `QCRoutingService::determineReworkNode(int $tokenId, string $defectCode, int $currentQcNodeId)`
   - Logic: Check defect severity, determine rework target
   - **Dependency:** Q-03

10. **C-03:** Integrate with QC_FINAL and PACKING nodes
    - QC_FINAL: Check component completeness before PASS
    - PACKING: Validate all components bound before shipping
    - Show component list in QC panel
    - **Dependency:** C-02, Q-03

**Phase 3 Deliverables:**
- PWA scan flow normalized and error recovery implemented
- Token Engine aligned with Classic line (scan-driven entry points)
- QC system fully integrated (multi-level routing, dashboards)
- Component binding integrated with QC_FINAL

---

## Phase 4 – Leather Reality Layer

**Goal:** Implement Leather Steward workflow, planner warnings, and offcut analytics.

**Prerequisites:** Phase 3 complete (or Phase 2 if Leather Reality is independent)

**Tasks:**

1. **L-01:** Add leather reality tables
   - Create `leather_bucket` table
   - Create `leather_reality_snapshot` table
   - Migration: `database/tenant_migrations/YYYY_MM_leather_reality.php`
   - **Dependency:** None

2. **L-02:** Build Leather Steward UI/flow for bucketing
   - Screen: `/materials/leather_bucket` or `/leather_steward`
   - UI: Bucket selection, sq_ft input, batch submission
   - API: `leather_steward_api.php?action=bucket_leather`
   - Reconciliation logic: T vs B_total calculation
   - **Dependency:** L-01

3. **L-03:** Add MO planner warnings based on ratios
   - Service: `LeatherRealityService::checkPanelAvailability(int $productId)`
   - Queries latest snapshot
   - Calculates panel_ratio
   - Returns warning if ratio < threshold (0.3)
   - **Dependency:** L-02

4. **L-04:** Add "offcut product line" analytics
   - Query: Products that can use offcuts
   - Display: Offcut ratio + suggested products
   - Integration: Planner dashboard
   - **Dependency:** L-02

5. **L-05:** Integrate with CUT node residual pattern
   - CUT node completion: Record residual pattern
   - Options: "1 large panel + small offcuts" or "small offcuts only"
   - Updates leather reality automatically
   - **Dependency:** L-02, WC-04 (CUT node behavior)

6. **L-06:** Add reconciliation reports
   - Report: Leather Reality Reconciliation
   - Shows: T vs B_total, unknown_ratio trend
   - Alerts: High unknown_ratio (needs better bucketing)
   - **Dependency:** L-02

**Phase 4 Deliverables:**
- Leather Steward workflow functional
- Planner warnings for panel-grade stock
- Offcut analytics and product suggestions
- CUT node residual pattern recording

---

## Task Dependencies Summary

**Critical Path:**
1. WC-01 → WC-02 → WC-03 → WC-04 → WC-05
2. T-01 → T-02 → T-03 → T-04
3. TE-01 → TE-02 → TE-03
4. Q-01 → Q-02 → Q-03 → Q-04, Q-05
5. PWA-01 → PWA-02 → PWA-03 → PWA-04, PWA-05, PWA-06
6. L-01 → L-02 → L-03, L-04, L-05, L-06

**Cross-Domain Dependencies:**
- WC-05 depends on TE-02 (over-limit detection needs behavior)
- T-04 depends on WC-04 (batch split needs behavior integration)
- C-03 depends on Q-03 (component completeness check needs QC)
- L-05 depends on WC-04 (residual pattern needs CUT node behavior)

---

## Implementation Notes

**Iteration Order:**
- Phase 1 can be done in parallel (WC-01, T-01, TE-01 are independent)
- Phase 2 requires Phase 1 complete
- Phase 3 can start after Phase 2 (some tasks independent)
- Phase 4 can start after Phase 2 (independent of Phase 3)

**Breaking Changes:**
- All changes are additive (no breaking changes to existing tables)
- New tables only (no schema modifications to existing tables)
- Feature flags recommended for gradual rollout

**Testing Strategy:**
- Unit tests for each service
- Integration tests for API endpoints
- Manual testing for UI workflows
- Performance tests for batch split and time calculations

---

**Source:** All SPEC_*.md files  
**Related:** [DAG_Blueprint.md](DAG_Blueprint.md), [REALITY_EVENT_IN_HOUSE.md](REALITY_EVENT_IN_HOUSE.md)  
**Last Updated:** December 2025

