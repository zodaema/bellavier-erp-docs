# Task Index - Behavior Layer Evolution (Phase 1-2)

**Date:** 2025-12-02  
**Purpose:** Index for Behavior Layer evolution tasks  
**Scope:** Phase 1-2 (Token Lifecycle + Component Hooks)

---

## 📋 Task List

### Phase 1: Core Token Lifecycle + Behavior Wiring

**Goal:** Behavior อยู่บน TokenLifecycle (ไม่แตะ status ตรง ๆ)

| Task | Title | Effort | Status | Dependencies |
|------|-------|--------|--------|--------------|
| **27.2** | Create TokenLifecycleService | 6-8h | 📋 Pending | None |
| **27.3** | Refactor BehaviorExecutionService to Call Lifecycle | 8-10h | 📋 Pending | 27.2 |
| **27.4** | Implement Behavior × Token Type Validation Matrix | 3-4h | 📋 Pending | 27.3 |

**Total Phase 1:** 17-22 hours (~2-3 days)

---

### Phase 2: Component Flow Integration (Basic)

**Goal:** Behavior aware ของ component token (ยังไม่ทำ parallel จริง)

| Task | Title | Effort | Status | Dependencies |
|------|-------|--------|--------|--------------|
| **27.5** | Create ComponentFlowService (Stub) | 4-5h | 📋 Pending | 27.4 |
| **27.6** | Add Component Hooks in Behavior | 4-6h | 📋 Pending | 27.5 |

**Total Phase 2:** 8-11 hours (~1-1.5 days)

---

## 🎯 Progress Summary

**Completed:** 0/6 tasks  
**In Progress:** 0/6 tasks  
**Pending:** 6/6 tasks  

**Total Effort:** 25-33 hours (3-4 days)

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Behavior integration blueprint
- `docs/super_dag/02-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - Token lifecycle model

**Audit:**
- `docs/super_dag/00-audit/20251202_BEHAVIOR_LAYER_AUDIT_REPORT.md` - Current gaps

---

## 🎯 Next Phases (Not Started)

### Phase 3: Parallel / Split-Merge Integration
- Task 27.7: Design ParallelMachineCoordinator API
- Task 27.8: Implement TokenLifecycleService::completeNode() for all node types

### Phase 4: Failure Recovery
- Task 27.9: Create FailureRecoveryService + QC Fail Flow
- Task 27.10: Wrong Tray Validation Hook

### Phase 5: UI Data Contract
- Task 27.11: Create get_context API for Work Queue

---

**Last Updated:** December 2, 2025
