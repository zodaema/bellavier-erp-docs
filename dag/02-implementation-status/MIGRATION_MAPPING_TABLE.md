# Migration Mapping Table: Legacy Tasks → New Task-Based Structure

**Date:** December 2025  
**Purpose:** Track migration of files from `docs/dag/agent-tasks/` to new task-based structure

---

## 📋 Mapping Table

| Old File | New Task File | Status | Notes |
|----------|---------------|--------|-------|
| `task1.md` | `03-tasks/TASK_DAG_1_DOCS_REBASELINE.md` | ✅ Merged | Documentation reorganization task |
| `task1_IMPLEMENTATION_SUMMARY.md` | `03-tasks/TASK_DAG_1_DOCS_REBASELINE.md` (Section: Implementation) | ✅ Merged | Implementation summary merged into task file |
| `task2.md` | `03-tasks/TASK_DAG_2_MANAGER_ASSIGNMENT.md` | ✅ Merged | Manager assignment propagation |
| `task2_IMPLEMENTATION_SUMMARY.md` | `03-tasks/TASK_DAG_2_MANAGER_ASSIGNMENT.md` (Section: Implementation) | ✅ Merged | Implementation summary merged |
| `task3.md` | `03-tasks/TASK_DAG_4_DEBUG_AND_FILTERS.md` | ✅ Merged | Work Queue Filter Test Fix |
| `task3_IMPLEMENTATION_SUMMARY.md` | `03-tasks/TASK_DAG_4_DEBUG_AND_FILTERS.md` (Section: Implementation) | ✅ Merged | Implementation summary merged |
| `task4.md` | `03-tasks/TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md` | 🟡 To Create | Operator availability schema normalization |
| `task4_OPERATOR_AVAILABILITY_SCHEMA.md` | `03-tasks/TASK_DAG_4_OPERATOR_AVAILABILITY_SCHEMA.md` (Section: Implementation) | 🟡 To Create | Implementation summary to merge |
| `task5.md` | `03-tasks/TASK_DAG_5_SERIAL_HARDENING.md` | 🟡 To Create | Serial Number Hardening Layer (Stage 1) |
| `task5_SERIAL_HARDENING.md` | `03-tasks/TASK_DAG_5_SERIAL_HARDENING.md` (Section: Implementation) | 🟡 To Create | Implementation summary to merge |
| `task6.md` | `03-tasks/TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md` | 🟡 To Create | Operator Availability Fail-Open Logic |
| `task6_OPERATOR_AVAILABILITY_FAIL_OPEN.md` | `03-tasks/TASK_DAG_6_OPERATOR_AVAILABILITY_FAIL_OPEN.md` (Section: Implementation) | 🟡 To Create | Implementation summary to merge |
| `task7.md` | `03-tasks/TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md` | 🟡 To Create | Node Plan Auto-Assignment Integration |
| `task7_NODE_PLAN_AUTO_ASSIGNMENT.md` | `03-tasks/TASK_DAG_7_NODE_PLAN_AUTO_ASSIGN.md` (Section: Implementation) | 🟡 To Create | Implementation summary to merge |
| `task8.md` | `03-tasks/TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md` | 🟡 To Create | Serial Enforcement Stage 2 Gate |
| `task8_SERIAL_ENFORCEMENT_STAGE2.md` | `03-tasks/TASK_DAG_8_SERIAL_ENFORCEMENT_STAGE2.md` (Section: Implementation) | 🟡 To Create | Implementation summary to merge |
| `task9.md` | `03-tasks/TASK_DAG_9_TENANT_RESOLUTION.md` | 🟡 To Create | Tenant Resolution & Integration Test Hardening |
| `task9_TENANT_RESOLUTION_HARDENING.md` | `03-tasks/TASK_DAG_9_TENANT_RESOLUTION.md` (Section: Implementation) | 🟡 To Create | Implementation summary to merge |
| `task10.md` | `03-tasks/TASK_DAG_10_OPERATOR_AVAILABILITY.md` | 🟡 To Create | Operator Availability Console & Enforcement Flag |
| `task10_OPERATOR_AVAILABILITY_CONSOLE.md` | `03-tasks/TASK_DAG_10_OPERATOR_AVAILABILITY.md` (Section: Implementation) | 🟡 To Create | Implementation summary to merge |
| `task10.1.md` | `03-tasks/TASK_DAG_10_OPERATOR_AVAILABILITY.md` (Section: Subtask 10.1) | 🟡 To Create | Operator Availability Patch (People Monitor integration) |
| `task10.1_OPERATOR_AVAILABILITY_PATCH.md` | `03-tasks/TASK_DAG_10_OPERATOR_AVAILABILITY.md` (Section: Implementation) | 🟡 To Create | Implementation summary to merge |
| `task10.2.md` | `03-tasks/TASK_DAG_10_OPERATOR_AVAILABILITY.md` (Section: Subtask 10.2) | 🟡 To Create | Future subtask (if exists) |
| `task11.md` | `03-tasks/TASK_DAG_11_WORK_QUEUE_START_DETAILS.md` | 🟡 To Create | Work Queue Start & Details Patch |
| `task11_WORK_QUEUE_START_DETAILS_PATCH.md` | `03-tasks/TASK_DAG_11_WORK_QUEUE_START_DETAILS.md` (Section: Implementation) | 🟡 To Create | Implementation summary to merge |
| `task11.1.md` | `03-tasks/TASK_DAG_11_WORK_QUEUE_START_DETAILS.md` (Section: Subtask 11.1) | 🟡 To Create | Work Queue UI Smoothing |
| `task11.1_WORK_QUEUE_UI_SMOOTHING.md` | `03-tasks/TASK_DAG_11_WORK_QUEUE_START_DETAILS.md` (Section: Implementation) | 🟡 To Create | Implementation summary to merge |
| `INVESTIGATION_REPORT_NODE_PLAN_ASSIGNMENT.md` | `02-implementation-status/INVESTIGATION_SUMMARY.md` | 🟡 To Create | Investigation report (referenced in implementation-status) |

---

## 📝 Notes

### Task Numbering

**Original Task Numbers:**
- Task 1: Manager Assignment (now DAG-2)
- Task 2: Debug Log Enhancement (now part of DAG-4)
- Task 3: Work Queue Filter Test Fix (now part of DAG-4)
- Task 4: Operator Availability Schema (now DAG-4)
- Task 5: Serial Hardening (now DAG-5)
- Task 6: Operator Availability Fail-Open (now DAG-6)
- Task 7: Node Plan Auto-Assign (now DAG-7)
- Task 8: Serial Enforcement Stage 2 (now DAG-8)
- Task 9: Tenant Resolution (now DAG-9)
- Task 10: Operator Availability Console (now DAG-10)
- Task 11: Work Queue Start & Details (now DAG-11)

**New DAG Task Numbers:**
- DAG-1: Docs Rebaseline (new task for this migration)
- DAG-2: Manager Assignment (was Task 1)
- DAG-3: Wait Node Logic (from roadmap Phase 1.5)
- DAG-4: Debug & Filters (was Tasks 2, 3, 11, 11.1)
- DAG-5: Serial Hardening (was Task 5) - **Note:** Changed from Component Model
- DAG-6: Operator Availability Fail-Open (was Task 6)
- DAG-7: Node Plan Auto-Assign (was Task 7)
- DAG-8: Serial Enforcement Stage 2 (was Task 8)
- DAG-9: Tenant Resolution (was Task 9)
- DAG-10: Operator Availability (was Task 10, 10.1, 10.2)
- DAG-11: Work Queue Start & Details (was Task 11, 11.1)

### Conflicts & Consolidations

**Consolidated Tasks:**
- **DAG-4:** Combines Tasks 2, 3, 11, 11.1 (all related to Debug Log & Work Queue)
- **DAG-10:** Combines Tasks 10, 10.1, 10.2 (all related to Operator Availability)
- **DAG-11:** Combines Tasks 11, 11.1 (Work Queue fixes)

**Renumbered:**
- Original Task 1 → DAG-2 (Manager Assignment)
- Original Task 5 → DAG-5 (Serial Hardening) - **Note:** DAG-5 was originally Component Model, now changed to Serial Hardening

---

## 🔄 Migration Status

- ✅ **Completed:** DAG-1, DAG-2, DAG-3, DAG-4 (partial)
- 🟡 **In Progress:** DAG-4 (Operator Availability), DAG-5 through DAG-11
- ⏳ **Pending:** Investigation reports consolidation

---

**Last Updated:** December 2025

