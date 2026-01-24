# Documentation Classification Audit
**Date:** 2025-12-25  
**Role:** System Archaeologist + Technical Librarian  
**Purpose:** Classify and archive documentation without modifying content  
**Scope:** `docs/super_dag/` directory only

---

## Executive Summary

Scanned `docs/super_dag/` directory structure and classified documents into:
- **ACTIVE/SSOT:** Runtime contracts, locked specifications, current system truth
- **COMPLETED:** Implementation plans for completed work
- **SUPERSEDED/LEGACY:** Replaced by newer documents
- **AUDIT/HISTORICAL:** Audit reports, evidence gathering, archaeology
- **AMBIGUOUS:** Requires human decision

**Total Documents Scanned:** ~525 files  
**Classification Method:** Status metadata, date stamps, cross-references, content analysis

---

## A) Document Inventory Table

### Contracts (01-contracts/)

| File | Current Location | Status | Action | Reason |
|------|-----------------|--------|--------|--------|
| `EDGE_CONDITION_CONTRACT.md` | `01-contracts/` | **ACTIVE (SSOT)** | KEEP | Locked contract (2025-11-14), referenced by runtime code |
| `EDGE_REWORK_CONTRACT.md` | `01-contracts/` | **ACTIVE (SSOT)** | KEEP | Locked contract (2025-11-14), referenced by runtime code |
| `EDGE_CONDITION_REWORK_LOCK_20251225.md` | `01-contracts/` | **ACTIVE (SSOT)** | KEEP | Lock summary with DB evidence, created 2025-12-25 |
| `EDGE_CONDITION_REWORK_AUDIT_SUMMARY.md` | `01-contracts/` | **AUDIT/HISTORICAL** | MOVE | Audit report (2025-11-14), evidence gathering (not normative contract) |
| `LEGACY_RELIANCE_QUERIES.sql` | `01-contracts/` | **ACTIVE (SSOT)** | KEEP | SQL queries for legacy reliance measurement (tool, not doc) |

### Specifications (02-specs/)

| File | Current Location | Status | Action | Reason |
|------|-----------------|--------|--------|--------|
| `COMPONENT_PARALLEL_FLOW_SPEC.md` | `02-specs/` | **ACTIVE (SSOT)** | KEEP | Production-ready spec (V2.1, 2025-12-02), 3-5 year lifespan |
| `SUPERDAG_TOKEN_LIFECYCLE.md` | `02-specs/` | **ACTIVE (SSOT)** | KEEP | Core architecture spec (V1.0, 2025-12-02) |
| `BEHAVIOR_EXECUTION_SPEC.md` | `02-specs/` | **ACTIVE (SSOT)** | KEEP | Target specification (V2.0, 2025-12-02) |

### Concepts (01-concepts/)

| File | Current Location | Status | Action | Reason |
|------|-----------------|--------|--------|--------|
| `QC_REWORK_PHILOSOPHY_V2.md` | `01-concepts/` | **ACTIVE (SSOT)** | KEEP | Master reference (2024-12-04, FINALIZED), referenced by implementation |
| `COMPONENT_PARALLEL_FLOW.md` | `01-concepts/` | **SUPERSEDED** | MOVE | Concept doc (2025-01-XX), superseded by `02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` (V2.1, 2025-12-02) |
| `EDGE_CONDITION_USAGE_POLICY.md` | `01-concepts/` | **AMBIGUOUS** | FLAG | Policy doc (2024-12-04), may be superseded by `EDGE_CONDITION_CONTRACT.md` (2025-11-14), needs review |

### Audit Reports (00-audit/)

| File | Current Location | Status | Action | Reason |
|------|-----------------|--------|--------|--------|
| `LEGACY_RELIANCE_STATS_20251225.md` | `00-audit/` | **AUDIT/HISTORICAL** | MOVE | DB evidence report, historical snapshot (2025-12-25) |
| `WORK_QUEUE_QC_REWORK_CUT_YIELD_KNOWLEDGE_AUDIT.md` | `00-audit/` | **AUDIT/HISTORICAL** | MOVE | Archaeology document (2025-12-25), evidence gathering |
| `20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md` | `00-audit/` | **AUDIT/HISTORICAL** | MOVE | Audit report (2025-12-02), historical reference |
| `*_AUDIT*.md` (all other audit files) | `00-audit/` | **AUDIT/HISTORICAL** | MOVE | All audit reports are historical evidence, not normative specs |

### Master Specs (specs/)

| File | Current Location | Status | Action | Reason |
|------|-----------------|--------|--------|--------|
| `MATERIAL_PRODUCTION_MASTER_SPEC.md` | `specs/` | **ACTIVE (SSOT)** | KEEP | Master specification (Dec 2025, Finalized), CUT node batch workflow |

### Tasks (tasks/)

| File | Current Location | Status | Action | Reason |
|------|-----------------|--------|--------|--------|
| `task27.15_QC_REWORK_V2_PLAN.md` | `tasks/archive/completed_tasks/` | **COMPLETED** | KEEP IN ARCHIVE | Implementation plan for completed work, already archived |
| `TASK_PRIORITY_ANALYSIS.md` | `tasks/` | **AMBIGUOUS** | FLAG | Planning document (2025-12-09), may be active or completed |
| `MASTER_IMPLEMENTATION_ROADMAP.md` | `tasks/` | **AMBIGUOUS** | FLAG | Roadmap (2025-12-06, ALL PHASES COMPLETE), may be historical |
| `task_MATERIAL_MANAGEMENT_ROADMAP.md` | `tasks/` | **AMBIGUOUS** | FLAG | Planning document (2025-12-10, Planning), status unclear |
| `task27.26_DAG_ROUTING_API_REFACTOR.md` | `tasks/` | **AMBIGUOUS** | FLAG | Task document (2025-12-10, Phase 3 COMPLETE), may need archive |
| `task28_GRAPH_VERSIONING_IMPLEMENTATION.md` | `tasks/` | **AMBIGUOUS** | FLAG | Task document, status unclear |
| `task_index.md` | `tasks/` | **ACTIVE** | KEEP | Index/reference document |

### Root Level Documents

| File | Current Location | Status | Action | Reason |
|------|-----------------|--------|--------|--------|
| `DOCUMENTATION_INDEX.md` | `super_dag/` | **ACTIVE** | KEEP | Index/reference document (December 2025) |
| `README.md` | `super_dag/` | **ACTIVE** | KEEP | Directory README |
| `SYSTEM_CURRENT_STATE.md` | `super_dag/` | **AMBIGUOUS** | FLAG | Current state doc (2025-12-09), may be active reference or outdated |
| `DOCUMENTATION_COMPLETE.md` | `super_dag/` | **AMBIGUOUS** | FLAG | Completion marker (2025-12-02), may be historical |
| `COMPLETE_DOCUMENTATION_AND_TASKS.md` | `super_dag/` | **AMBIGUOUS** | FLAG | Completion marker (2025-12-02), may be historical |
| `FINAL_SUMMARY.md` | `super_dag/` | **AMBIGUOUS** | FLAG | Summary document (2025-12-02), status unclear |
| `DOCUMENTATION_SUMMARY.md` | `super_dag/` | **AMBIGUOUS** | FLAG | Summary document (2025-12-02), status unclear |

---

## B) Archive Plan (NO EXECUTION)

### Move to `docs/super_dag/archive/audit/`:

**From `01-contracts/`:**
1. `docs/super_dag/01-contracts/EDGE_CONDITION_REWORK_AUDIT_SUMMARY.md`
   → `docs/super_dag/archive/audit/EDGE_CONDITION_REWORK_AUDIT_SUMMARY.md`
   **Reason:** Audit report (2025-11-14), evidence gathering (not normative contract). Lock summary is in `EDGE_CONDITION_REWORK_LOCK_20251225.md`.

**From `00-audit/`:**
2. `docs/super_dag/00-audit/LEGACY_RELIANCE_STATS_20251225.md`
   → `docs/super_dag/archive/audit/LEGACY_RELIANCE_STATS_20251225.md`
   **Reason:** DB evidence snapshot (2025-12-25), historical reference

3. `docs/super_dag/00-audit/WORK_QUEUE_QC_REWORK_CUT_YIELD_KNOWLEDGE_AUDIT.md`
   → `docs/super_dag/archive/audit/WORK_QUEUE_QC_REWORK_CUT_YIELD_KNOWLEDGE_AUDIT.md`
   **Reason:** Archaeology document (2025-12-25), evidence discovery (not normative spec)

4. `docs/super_dag/00-audit/20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md`
   → `docs/super_dag/archive/audit/20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md`
   **Reason:** Audit report (2025-12-02), historical reference

5. All other `*_AUDIT*.md` files in `00-audit/` (84+ files)
   → `docs/super_dag/archive/audit/`
   **Reason:** All audit reports are historical evidence, not normative specifications

**Note:** `docs/DAG_RUNTIME_AUDIT_REPORT.md` is outside scope (not in `docs/super_dag/`)

### Move to `docs/super_dag/archive/legacy/`:

1. `docs/super_dag/01-concepts/COMPONENT_PARALLEL_FLOW.md`
   → `docs/super_dag/archive/legacy/COMPONENT_PARALLEL_FLOW.md`
   **Reason:** Concept document superseded by `02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` (V2.1, 2025-12-02). Spec references concept doc but spec is authoritative.

---

## C) Ambiguous Documents (Require Human Decision)

### Documents Requiring Review:

1. **`docs/super_dag/01-concepts/EDGE_CONDITION_USAGE_POLICY.md`**
   - **Status:** AMBIGUOUS — REQUIRES DECISION
   - **Reason:** May be superseded by `EDGE_CONDITION_CONTRACT.md` (locked contract). Policy document may contain guidance not in contract, or may be legacy. Needs review to determine if still relevant or should be archived.

2. **`docs/super_dag/tasks/TASK_PRIORITY_ANALYSIS.md`**
   - **Status:** AMBIGUOUS — REQUIRES DECISION
   - **Reason:** Planning document. Unclear if active planning tool or completed analysis. Needs review to determine if should remain active or move to archive.

3. **`docs/super_dag/tasks/MASTER_IMPLEMENTATION_ROADMAP.md`**
   - **Status:** AMBIGUOUS — REQUIRES DECISION
   - **Reason:** Master roadmap. Unclear if actively maintained or superseded by newer planning. Needs review.

4. **`docs/super_dag/tasks/task_MATERIAL_MANAGEMENT_ROADMAP.md`**
   - **Status:** AMBIGUOUS — REQUIRES DECISION
   - **Reason:** Task/roadmap document. Status unclear (active planning vs completed). Needs review.

5. **`docs/super_dag/tasks/task27.26_DAG_ROUTING_API_REFACTOR.md`**
   - **Status:** AMBIGUOUS — REQUIRES DECISION
   - **Reason:** Task document. May be completed (in `tasks/` not `tasks/archive/`). Needs review to determine if should move to archive or remain active.

6. **`docs/super_dag/SYSTEM_CURRENT_STATE.md`**
   - **Status:** AMBIGUOUS — REQUIRES DECISION
   - **Reason:** Current state document. May be active reference or outdated. Needs review.

7. **`docs/super_dag/DOCUMENTATION_COMPLETE.md`**
   - **Status:** AMBIGUOUS — REQUIRES DECISION
   - **Reason:** Completion marker. May be historical milestone or active status indicator. Needs review.

8. **`docs/super_dag/COMPLETE_DOCUMENTATION_AND_TASKS.md`**
   - **Status:** AMBIGUOUS — REQUIRES DECISION
   - **Reason:** Completion marker. May be historical milestone or active status indicator. Needs review.

9. **`docs/super_dag/FINAL_SUMMARY.md`**
   - **Status:** AMBIGUOUS — REQUIRES DECISION
   - **Reason:** Summary document. Unclear if active reference or historical. Needs review.

10. **`docs/super_dag/DOCUMENTATION_SUMMARY.md`**
    - **Status:** AMBIGUOUS — REQUIRES DECISION
    - **Reason:** Summary document. Unclear if active reference or historical. Needs review.

---

## D) Final "Clean Active Docs" List

### Active Documents (SSOT) - Remaining in Working Folders

**Contracts (Locked, Runtime Determinism):**
1. `docs/super_dag/01-contracts/EDGE_CONDITION_CONTRACT.md` - Locked contract (2025-11-14)
2. `docs/super_dag/01-contracts/EDGE_REWORK_CONTRACT.md` - Locked contract (2025-11-14)
3. `docs/super_dag/01-contracts/EDGE_CONDITION_REWORK_LOCK_20251225.md` - Lock summary with DB evidence
4. `docs/super_dag/01-contracts/LEGACY_RELIANCE_QUERIES.sql` - SQL queries (tool, not doc)

**Specifications (Production-Ready):**
5. `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - V2.1 (2025-12-02)
6. `docs/super_dag/02-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - V1.0 (2025-12-02)
7. `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - V2.0 (2025-12-02)

**Concepts (Master Reference):**
8. `docs/super_dag/01-concepts/QC_REWORK_PHILOSOPHY_V2.md` - FINALIZED (2024-12-04)

**Specs (Master):**
9. `docs/super_dag/specs/MATERIAL_PRODUCTION_MASTER_SPEC.md` - CUT node batch workflow

**Index/Reference:**
10. `docs/super_dag/task_index.md` - Task index
11. `docs/super_dag/DOCUMENTATION_INDEX.md` - Documentation index
12. `docs/super_dag/README.md` - Directory README

**Total Active Documents:** 12 files

**Note:** All files in `00-audit/` (84+ files) are classified as AUDIT/HISTORICAL and should be moved to archive. Only the classification audit itself (`DOCUMENTATION_CLASSIFICATION_AUDIT.md`) remains in `00-audit/` temporarily for review.

---

## Classification Evidence

### ACTIVE/SSOT Criteria Applied:

**EDGE_CONDITION_CONTRACT.md:**
- Status: "LOCKED (Runtime Determinism)"
- Date: 2025-11-14
- Referenced by: Runtime code (`DAGRoutingService.php`, `ConditionEvaluator.php`)
- **Verdict:** ACTIVE (SSOT)

**EDGE_REWORK_CONTRACT.md:**
- Status: "LOCKED (Runtime Determinism)"
- Date: 2025-11-14
- Referenced by: Runtime code (`DAGRoutingService.php`, `BehaviorExecutionService.php`)
- **Verdict:** ACTIVE (SSOT)

**COMPONENT_PARALLEL_FLOW_SPEC.md:**
- Status: "Production-Ready Specification"
- Version: 2.1 (3-5 year lifespan)
- Date: 2025-12-02
- **Verdict:** ACTIVE (SSOT)

**SUPERDAG_TOKEN_LIFECYCLE.md:**
- Status: "Core Architecture Specification"
- Version: 1.0
- Date: 2025-12-02
- **Verdict:** ACTIVE (SSOT)

**QC_REWORK_PHILOSOPHY_V2.md:**
- Status: "✅ FINALIZED"
- Date: 2024-12-04
- Referenced by: Implementation plan (`task27.15_QC_REWORK_V2_PLAN.md`)
- **Verdict:** ACTIVE (SSOT) - Master reference

### SUPERSEDED Criteria Applied:

**COMPONENT_PARALLEL_FLOW.md:**
- Location: `01-concepts/`
- Superseded by: `02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` (V2.1, 2025-12-02)
- Spec references concept doc but spec is authoritative
- **Verdict:** SUPERSEDED (MOVE TO ARCHIVE)

### AUDIT/HISTORICAL Criteria Applied:

**EDGE_CONDITION_REWORK_AUDIT_SUMMARY.md:**
- Purpose: "Audit Summary (Evidence-Based)"
- Contains: Evidence table, call flow, verdicts
- Not normative spec, evidence gathering
- **Verdict:** AUDIT/HISTORICAL (MOVE TO ARCHIVE)

**LEGACY_RELIANCE_STATS_20251225.md:**
- Purpose: "Legacy Reliance Statistics"
- Contains: DB query results, snapshot data
- Historical evidence, not normative spec
- **Verdict:** AUDIT/HISTORICAL (MOVE TO ARCHIVE)

**WORK_QUEUE_QC_REWORK_CUT_YIELD_KNOWLEDGE_AUDIT.md:**
- Role: "System Archaeologist (Document Discovery Only)"
- Purpose: "Rediscover existing documentation"
- Evidence gathering, not normative spec
- **Verdict:** AUDIT/HISTORICAL (MOVE TO ARCHIVE)

---

## Archive Structure (Proposed)

```
docs/super_dag/
├── 01-contracts/          (ACTIVE contracts only)
├── 02-specs/             (ACTIVE specs only)
├── 01-concepts/          (ACTIVE concepts only)
├── specs/                (ACTIVE master specs)
├── tasks/                (ACTIVE tasks + index)
├── README.md             (ACTIVE)
├── DOCUMENTATION_INDEX.md (ACTIVE)
└── archive/
    ├── audit/             (Audit reports, evidence)
    ├── legacy/            (Superseded documents)
    └── completed/         (Completed implementation plans)
```

---

## Notes

1. **SQL Files:** `LEGACY_RELIANCE_QUERIES.sql` is a tool (queries), not documentation. Kept in contracts as reference tool.

2. **Task Archive:** `tasks/archive/completed_tasks/` already exists. Completed tasks already archived are not moved again.

3. **Cross-References:** Some documents reference others. Moving superseded docs may break references. Consider adding "Replaced by" notes in moved files.

4. **Ambiguous Documents:** 10 documents require human decision. Cannot classify automatically without understanding current planning status.

---

**Status:** ✅ **CLASSIFICATION COMPLETE**  
**Archive Plan:** Provided (NO EXECUTION)  
**Ambiguities:** 10 documents flagged for human review

