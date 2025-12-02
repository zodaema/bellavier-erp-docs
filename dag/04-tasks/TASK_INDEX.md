
# DAG Tasks Index (Task-based view)

**Docs Version:** DAG Spec v1.0 (Dec 2025)

**Current Active Task:** DAG-12

**Last Updated:** December 2025  
**Purpose:** Central index of all DAG tasks for easy navigation

---


<!-- TASK_INDEX_BEGIN -->

## 📋 Task Index Table

| Task ID | Title                                           | Short Description                                              | Scope                  | Status       | Doc File                                           |
|---------|-------------------------------------------------|---------------------------------------------------------------|------------------------|-------------|----------------------------------------------------|
| DAG-1   | DAG Docs Rebaseline (this task)                 | Rebaseline DAG documentation structure                        | docs/dag only          | ✅ COMPLETED | [03-tasks/TASK_DAG_1_DOCS_REBASELINE.md](TASK_DAG_1_DOCS_REBASELINE.md) |
| DAG-2   | Manager Assignment Propagation                  | Propagate manager assignments to tokens on spawn              | Assignment / Tokens    | ✅ COMPLETED | [03-tasks/TASK_DAG_2_MANAGER_ASSIGNMENT.md](TASK_DAG_2_MANAGER_ASSIGNMENT.md) |
| DAG-3   | Wait Node Logic & Background Evaluation         | Implement wait node with time/batch/approval logic            | Routing / Wait Nodes   | ✅ COMPLETED | [03-tasks/TASK_DAG_3_WAIT_NODE_LOGIC.md](TASK_DAG_3_WAIT_NODE_LOGIC.md) |
| DAG-4   | Debug Log & Work Queue Filter Enhancements      | Enhance debug logging and fix work queue filter issues        | Debug / Work Queue     | ✅ COMPLETED | [03-tasks/TASK_DAG_4_DEBUG_AND_FILTERS.md](TASK_DAG_4_DEBUG_AND_FILTERS.md) |
| DAG-12  | Operator Availability Schema Normalization      | Normalize operator availability schema detection              | Assignment / Operator  | ✅ COMPLETED | [03-tasks/TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md](TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md) |
| DAG-5   | Serial Number Hardening Layer (Stage 1)         | Detect serial number anomalies without blocking operations    | Serial / Health        | ✅ COMPLETED | [03-tasks/TASK_DAG_5_SERIAL_HARDENING.md](TASK_DAG_5_SERIAL_HARDENING.md) |
| DAG-6   | Operator Availability Fail-Open Logic           | Add fail-open logic for operator availability assignments     | Assignment / Operator  | ✅ COMPLETED | [03-tasks/TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md](TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md) |
| DAG-7   | Node Plan Auto-Assignment Integration           | Auto-assign token when node plan has exactly one candidate    | Assignment / Node Plan | ✅ COMPLETED | [03-tasks/TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md](TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md) |
| DAG-8   | Serial Enforcement Stage 2 Gate                 | Enforce serial health blockers with feature flag              | Serial / Enforcement   | ✅ COMPLETED | [03-tasks/TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md](TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md) |
| DAG-9   | Tenant Resolution & Integration Test Hardening  | Improve tenant resolution and harden integration tests        | Serial / Testing       | ✅ COMPLETED | [03-tasks/TASK_DAG_9_TENANT_RESOLUTION.md](TASK_DAG_9_TENANT_RESOLUTION.md) |
| DAG-10  | Operator Availability Console & Enforcement     | UI, API, and enforcement for operator availability            | Assignment / Operator  | ✅ COMPLETED | [03-tasks/TASK_DAG_10_OPERATOR_AVAILABILITY.md](TASK_DAG_10_OPERATOR_AVAILABILITY.md) |
| DAG-11  | Work Queue Start & Details Patch                | Fix work queue start logic, details, and UI smoothing         | Work Queue / UI        | ✅ COMPLETED | [03-tasks/TASK_DAG_11_WORK_QUEUE_START_DETAILS.md](TASK_DAG_11_WORK_QUEUE_START_DETAILS.md) |

---

## Legacy → DAG Task Mapping

| Legacy Task | DAG Task |
|-------------|----------|
| Task 2      | DAG-4    |
| Task 3      | DAG-4    |
| Task 10     | DAG-10   |
| Task 10.1   | DAG-10   |
| Task 10.2   | DAG-10   |
| Task 11     | DAG-11   |
| Task 11.1   | DAG-11   |

---

| Task ID | Title                                           | Scope                  | Status       | Doc File                                           |
|---------|-------------------------------------------------|------------------------|-------------|----------------------------------------------------|
| DAG-1   | DAG Docs Rebaseline (this task)                 | docs/dag only          | ✅ COMPLETED | [03-tasks/TASK_DAG_1_DOCS_REBASELINE.md](TASK_DAG_1_DOCS_REBASELINE.md) |
| DAG-2   | Manager Assignment Propagation                 | Assignment / Tokens    | ✅ COMPLETED | [03-tasks/TASK_DAG_2_MANAGER_ASSIGNMENT.md](TASK_DAG_2_MANAGER_ASSIGNMENT.md) |
| DAG-3   | Wait Node Logic & Background Evaluation        | Routing / Wait Nodes   | ✅ COMPLETED | [03-tasks/TASK_DAG_3_WAIT_NODE_LOGIC.md](TASK_DAG_3_WAIT_NODE_LOGIC.md) |
| DAG-4   | Debug Log & Work Queue Filter Enhancements     | Debug / Work Queue     | ✅ COMPLETED | [03-tasks/TASK_DAG_4_DEBUG_AND_FILTERS.md](TASK_DAG_4_DEBUG_AND_FILTERS.md) |
| DAG-4   | Operator Availability Schema Normalization    | Assignment / Operator  | ✅ COMPLETED | [03-tasks/TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md](TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md) |
| DAG-5   | Serial Number Hardening Layer (Stage 1)         | Serial / Health        | ✅ COMPLETED | [03-tasks/TASK_DAG_5_SERIAL_HARDENING.md](TASK_DAG_5_SERIAL_HARDENING.md) |
| DAG-6   | Operator Availability Fail-Open Logic          | Assignment / Operator  | ✅ COMPLETED | [03-tasks/TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md](TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md) |
| DAG-7   | Node Plan Auto-Assignment Integration          | Assignment / Node Plan | ✅ COMPLETED | [03-tasks/TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md](TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md) |
| DAG-8   | Serial Enforcement Stage 2 Gate               | Serial / Enforcement   | ✅ COMPLETED | [03-tasks/TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md](TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md) |
| DAG-9   | Tenant Resolution & Integration Test Hardening | Serial / Testing       | ✅ COMPLETED | [03-tasks/TASK_DAG_9_TENANT_RESOLUTION.md](TASK_DAG_9_TENANT_RESOLUTION.md) |
| DAG-10  | Operator Availability Console & Enforcement    | Assignment / Operator  | ✅ COMPLETED | [03-tasks/TASK_DAG_10_OPERATOR_AVAILABILITY.md](TASK_DAG_10_OPERATOR_AVAILABILITY.md) |
| DAG-11  | Work Queue Start & Details Patch               | Work Queue / UI        | ✅ COMPLETED | [03-tasks/TASK_DAG_11_WORK_QUEUE_START_DETAILS.md](TASK_DAG_11_WORK_QUEUE_START_DETAILS.md) |

---

## 📊 Status Legend

- ✅ **COMPLETED** - Implementation complete, code live, tests passing
- 🟡 **PLANNED** - Design/spec ready, implementation pending
- 🚧 **IN PROGRESS** - Implementation in progress
- ⏳ **PENDING** - Blocked or waiting for dependencies

---

## 🔍 Quick Navigation

### By Status

**✅ Completed Tasks:**
- [DAG-1: DAG Docs Rebaseline](TASK_DAG_1_DOCS_REBASELINE.md) - Documentation reorganization
- [DAG-2: Manager Assignment Propagation](TASK_DAG_2_MANAGER_ASSIGNMENT.md) - Manager plans propagate on spawn
- [DAG-3: Wait Node Logic & Background Evaluation](TASK_DAG_3_WAIT_NODE_LOGIC.md) - Wait nodes with time/batch/approval
- [DAG-4: Debug Log & Work Queue Filter Enhancements](TASK_DAG_4_DEBUG_AND_FILTERS.md) - Debug logging + Work Queue fixes
- [DAG-12: Operator Availability Schema Normalization](TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md) - Schema detection for operator availability
- [DAG-5: Serial Number Hardening Layer (Stage 1)](TASK_DAG_5_SERIAL_HARDENING.md) - Serial health detection
- [DAG-6: Operator Availability Fail-Open Logic](TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md) - Fail-open for empty table
- [DAG-7: Node Plan Auto-Assignment Integration](TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md) - Auto-assign from node plans
- [DAG-8: Serial Enforcement Stage 2 Gate](TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md) - Serial enforcement with feature flag
- [DAG-9: Tenant Resolution & Integration Test Hardening](TASK_DAG_9_TENANT_RESOLUTION.md) - Improved tenant resolution
- [DAG-10: Operator Availability Console & Enforcement](TASK_DAG_10_OPERATOR_AVAILABILITY.md) - UI and enforcement flag
- [DAG-11: Work Queue Start & Details Patch](TASK_DAG_11_WORK_QUEUE_START_DETAILS.md) - Start logic + details + UI smoothing

### By Scope

**Assignment / Tokens:**
- [DAG-2: Manager Assignment Propagation](TASK_DAG_2_MANAGER_ASSIGNMENT.md)
- [DAG-12: Operator Availability Schema Normalization](TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md)
- [DAG-6: Operator Availability Fail-Open Logic](TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md)
- [DAG-7: Node Plan Auto-Assignment Integration](TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md)
- [DAG-10: Operator Availability Console & Enforcement](TASK_DAG_10_OPERATOR_AVAILABILITY.md)

**Routing / Wait Nodes:**
- [DAG-3: Wait Node Logic & Background Evaluation](TASK_DAG_3_WAIT_NODE_LOGIC.md)

**Debug / Work Queue:**
- [DAG-4: Debug Log & Work Queue Filter Enhancements](TASK_DAG_4_DEBUG_AND_FILTERS.md)
- [DAG-11: Work Queue Start & Details Patch](TASK_DAG_11_WORK_QUEUE_START_DETAILS.md)

**Serial / Health:**
- [DAG-5: Serial Number Hardening Layer (Stage 1)](TASK_DAG_5_SERIAL_HARDENING.md)
- [DAG-8: Serial Enforcement Stage 2 Gate](TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md)
- [DAG-9: Tenant Resolution & Integration Test Hardening](TASK_DAG_9_TENANT_RESOLUTION.md)

**Documentation:**
- [DAG-1: DAG Docs Rebaseline](TASK_DAG_1_DOCS_REBASELINE.md)

---

<!-- TASK_INDEX_END -->

## 📚 Related Documentation

- [DAG_OVERVIEW.md](../00-overview/DAG_OVERVIEW.md) - System overview
- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Complete roadmap
- [IMPLEMENTATION_STATUS_SUMMARY.md](../02-implementation-status/IMPLEMENTATION_STATUS_SUMMARY.md) - Quick status summary

---

## 🔄 Task Status Details

### DAG-1: DAG Docs Rebaseline ✅

**Status:** ✅ COMPLETED (December 2025) (Spec Only)  
**Type:** Documentation Task  
**Scope:** Documentation reorganization only (no code changes)

**Summary:** Reorganized all documentation in `docs/dag/` into task-based structure with clear navigation.

**Key Deliverables:**
- New folder structure (00-overview, 01-roadmap, 03-tasks)
- DAG_OVERVIEW.md (entry point)
- Task files (DAG-1 through DAG-5)
- TASK_INDEX.md (this file)
- Roadmap refactored (condensed + links)

---

### DAG-2: Manager Assignment Propagation ✅

**Status:** ✅ COMPLETED (December 2025) (Code Live)  
**Type:** Implementation Task  
**Scope:** Assignment / Tokens

**Summary:** Manager plans from `manager_assignment` table now propagate to `token_assignment` on token spawn.

**Key Features:**
- Precedence: PIN > MANAGER > PLAN > AUTO
- Idempotency: Existing assignments never overridden
- Soft mode: Failures don't block spawn
- Work Queue integration: Assignments visible

**Related Tasks:**
- Task 2: Debug Log Enhancement
- Task 3: Work Queue Filter Test Fix
- Task 11: Work Queue Start & Details Patch
- Task 11.1: Work Queue UI Smoothing

---

### DAG-3: Wait Node Logic & Background Evaluation ✅

**Status:** ✅ COMPLETED (95% - Production Ready) (Partial, Code Live)  
**Type:** Implementation Task  
**Scope:** Routing / Wait Nodes

**Summary:** Implemented `wait` node type with time-based, batch-based, and approval-based wait conditions.

**Key Features:**
- Wait types: time, batch, approval, sensor (future)
- Background job for periodic evaluation
- Approval API for manual approval
- Auto-complete and route when conditions met
- Hidden from Work Queue and PWA

**Status Note:** 95% complete - Tests created but need refinement

---

### DAG-4: Debug Log & Work Queue Filter Enhancements ✅

**Status:** ✅ COMPLETED (December 2025) (Code Live)  
**Type:** Implementation Task (Multiple Sub-tasks)  
**Scope:** Debug / Work Queue

**Summary:** Fixed multiple Work Queue and debug logging issues.

**Sub-tasks:**
- Task 2: Debug Log Enhancement - Comprehensive debug logging
- Task 3: Work Queue Filter Test Fix - Test JSON parsing fix
- Task 11: Work Queue Start & Details Patch - Start logic + details section
- Task 11.1: Work Queue UI Smoothing - Spinner + silent refresh + scroll preservation

---

### DAG-5: Serial Number Hardening Layer (Stage 1) ✅

**Status:** ✅ COMPLETED (December 2025) (Code Live)  
**Type:** Implementation Task  
**Scope:** Serial / Health

**Summary:** Implemented Serial Number Hardening Layer - Stage 1 (Detection & Observability) to detect serial number anomalies without blocking operations.

**Key Features:**
- SerialHealthService for detecting 6 anomaly types
- CLI diagnostic tool (`tools/serial_health_check.php`)
- Soft-mode hooks in JobCreationService (log only, don't block)
- Comprehensive unit tests (5 tests, 36 assertions)

**Related Tasks:**
- DAG-8: Serial Enforcement Stage 2 Gate (adds enforcement layer)
- DAG-9: Tenant Resolution & Integration Test Hardening (improves tenant resolution)

---

### DAG-6: Operator Availability Fail-Open Logic ✅

**Status:** ✅ COMPLETED (December 2025) (Code Live)  
**Type:** Implementation Task  
**Scope:** Assignment / Operator Availability

**Summary:** Implemented dual fail-open logic for `AssignmentEngine::filterAvailable()` in the `is_available + unavailable_until` schema branch.

**Key Features:**
- Fail-open layer 1: Empty table check
- Fail-open layer 2: No candidate rows check
- Proper logging for both scenarios
- No impact on other schema branches

---

### DAG-7: Node Plan Auto-Assignment Integration ✅

**Status:** ✅ COMPLETED (December 2025) (Code Live)  
**Type:** Implementation Task  
**Scope:** Assignment / Node Plan

**Summary:** Implemented Node Plan Auto-Assignment Integration for Hatthasilpa DAG system. When a `node_plan` has exactly 1 candidate after filtering, the system now automatically creates a `token_assignment` row.

**Key Features:**
- Auto-assigns when exactly 1 candidate exists
- Feature flag protection (`FF_HAT_NODE_PLAN_AUTO_ASSIGN`)
- Idempotency: Won't override existing assignments
- Priority order: manager_assignment > job_plan > node_plan > auto

---

### DAG-8: Serial Enforcement Stage 2 Gate ✅

**Status:** ✅ COMPLETED (December 2025) (Code Live)  
**Type:** Implementation Task  
**Scope:** Serial / Enforcement

**Summary:** Implemented Serial Enforcement Stage 2 Gate for Hatthasilpa DAG system. The system now enforces serial health blockers when feature flag `FF_SERIAL_ENFORCE_STAGE2` is enabled.

**Key Features:**
- Severity mapping (BLOCKER vs WARNING)
- Gate evaluation with phase support (`pre_start`, `in_production`)
- Enforcement hooks in JobCreationService and dag_token_api.php
- Feature flag protection (`FF_SERIAL_ENFORCE_STAGE2`)
- Fail-open behavior (never blocks on exceptions)

---

### DAG-9: Tenant Resolution & Integration Test Hardening ✅

**Status:** ✅ COMPLETED (December 2025) (Code Live)  
**Type:** Implementation Task  
**Scope:** Serial / Testing

**Summary:** Improved SerialHealthService tenant resolution strategy and hardened integration tests for Serial Enforcement Stage 2.

**Key Features:**
- Improved tenant resolution (direct-tenant mode vs tenant-aware mode)
- Reduced noisy logs ("Could not determine tenant_id...")
- Deterministic integration tests (both flag=0 and flag=1 pass)
- Tenant-local checks work even when tenant_id cannot be resolved

---

### DAG-10: Operator Availability Console & Enforcement ✅

**Status:** ✅ COMPLETED (December 2025) (Code Live)  
**Type:** Implementation Task (Multiple Sub-tasks)  
**Scope:** Assignment / Operator Availability / UI

**Summary:** Implemented complete Operator Availability system with UI, API, and enforcement flag.

**Sub-tasks:**
- Task 10: Operator Availability Console & Enforcement Flag - Backend API and feature flag
- Task 10.1: Patch - People Monitor Integration - Removed standalone page, integrated into People Monitor
- Task 10.2: People Monitor Enhancements - Planned (workload, current work, realtime timer)

---

### DAG-11: Work Queue Start & Details Patch ✅

**Status:** ✅ COMPLETED (December 2025) (Code Live)  
**Type:** Implementation Task (Multiple Sub-tasks)  
**Scope:** Work Queue / UI
### DAG-12: Operator Availability Schema Normalization ✅

**Status:** ✅ COMPLETED (December 2025) (Code Live)  
**Type:** Implementation Task  
**Scope:** Assignment / Operator  

**Summary:** Normalized and detected operator availability schema for assignment logic, improving consistency and reliability.

**Key Features:**
- Unified schema detection for operator availability
- Robust fallback and error handling
- No impact to legacy assignment logic

**Related Tasks:**
- DAG-2: Manager Assignment Propagation
- DAG-6: Operator Availability Fail-Open Logic
- DAG-10: Operator Availability Console & Enforcement


**Summary:** Fixed multiple Work Queue issues including start logic, details section, token visibility, and UI smoothing.

**Sub-tasks:**
- Task 11: Start & Details Patch - Fix start logic, restore details section, fix token visibility
- Task 11.1: UI Smoothing - Fix loading spinner, add silent refresh, preserve scroll position

---

## 📝 Adding New Tasks

When adding a new task:

1. Create task file: `TASK_DAG_N_TITLE.md` in `03-tasks/`
2. Add row to this index table
3. Update status in roadmap if applicable
4. Link from relevant phase section in roadmap

**Task ID Format:** `DAG-N` where N is sequential number

---


## AI Agent Guidelines for Editing This File

- Do not modify Task IDs retroactively.
- Preserve table structure.
- Update status fields only when instructed.
- Keep anchor comments intact.


**Last Updated:** December 2025  
**Maintained By:** AI Agent (Auto)

