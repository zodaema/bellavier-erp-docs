# Task Index - Behavior Layer Evolution (Complete)

**Date:** 2025-12-02  
**Purpose:** Complete task index for Behavior Layer evolution  
**Scope:** Phase 1-5 (Token Lifecycle → Component → Parallel → Recovery → UI)

---

## 📋 Complete Task List

### Phase 1: Core Token Lifecycle + Behavior Wiring (2-3 days)

**Goal:** Behavior อยู่บน TokenLifecycle (ไม่แตะ status ตรงๆ)

| Task | Title | Effort | Status | Dependencies |
|------|-------|--------|--------|--------------|
| **27.2** | Extend TokenLifecycleService | 6-8h | ✅ **COMPLETE** | None |
| **27.3** | Refactor BehaviorExecutionService to Call Lifecycle | 8-10h | ✅ **COMPLETE** | 27.2 |
| **27.4** | Implement Behavior × Token Type Validation Matrix | 3-4h | ✅ **COMPLETE** | 27.3 |

**Total Phase 1:** 17-22 hours  
**Completed:** 🎉 **17-22h / 17-22h (100%)** ✅

**Deliverables:**
- ✅ TokenLifecycleService (single source of truth for token status)
- ✅ Behavior calls lifecycle APIs (no direct status updates)
- ✅ Validation matrix (13 behaviors × 3 token types)

---

### Phase 2: Component Flow Integration - Basic (1-1.5 days)

**Goal:** Behavior aware ของ component token (ยังไม่ทำ parallel จริง)

| Task | Title | Effort | Status | Dependencies |
|------|-------|--------|--------|--------------|
| **27.5** | Create ComponentFlowService (Stub) | 4-5h | 📋 Pending | 27.4 |
| **27.6** | Add Component Hooks in Behavior | 4-6h | 📋 Pending | 27.5 |

**Total Phase 2:** 8-11 hours

**Deliverables:**
- ✅ ComponentFlowService (stub methods)
- ✅ Component hooks in behavior (onComponentCompleted, isReadyForAssembly)
- ✅ Behavior aware of token_type = component

---

### Phase 3: Parallel / Split-Merge Integration (1.5-2 days)

**Goal:** ให้ parallel flow ทำงานจริงผ่าน Lifecycle + Coordinator

| Task | Title | Effort | Status | Dependencies |
|------|-------|--------|--------|--------------|
| **27.7** | Design ParallelMachineCoordinator API for Split/Merge | 6-8h | 📋 Pending | 27.6 |
| **27.8** | Implement completeNode() for All Node Types | 6-8h | 📋 Pending | 27.7 |

**Total Phase 3:** 12-16 hours

**Deliverables:**
- ✅ ParallelMachineCoordinator (handleSplit, handleMerge)
- ✅ TokenLifecycleService supports all node types (normal, split, merge, end)
- 🎉 **Component Parallel Flow works end-to-end!**

---

### Phase 4: Failure Mode Recovery (1-1.5 days)

**Goal:** ใส่สมองเวลา "พัง" (QC fail, wrong tray)

| Task | Title | Effort | Status | Dependencies |
|------|-------|--------|--------|--------------|
| **27.9** | Create FailureRecoveryService + QC Fail Flow | 5-7h | 📋 Pending | 27.8 |
| **27.10** | Wrong Tray Validation Hook (Basic) | 3-4h | 📋 Pending | 27.9 |

**Total Phase 4:** 8-11 hours

**Deliverables:**
- ✅ FailureRecoveryService (QC fail, replacement spawn)
- ✅ Wrong tray detection (basic validation)
- ✅ Fail-open behavior (ไม่ block unnecessarily)

---

### Phase 5: UI Data Contract (0.5-1 day)

**Goal:** เปิด API ให้ frontend เอา context ไป render

| Task | Title | Effort | Status | Dependencies |
|------|-------|--------|--------|--------------|
| **27.11** | Create get_context API for Work Queue UI | 4-6h | 📋 Pending | 27.10 |

**Total Phase 5:** 4-6 hours

**Deliverables:**
- ✅ get_context API endpoint
- ✅ Response structure for component/piece/final tokens
- ✅ Backend-Frontend separation (data vs presentation)

---

## 📊 Grand Total

**Total Tasks:** 10 tasks  
**Total Effort:** 49-66 hours (~6-8 working days)

**Completed:** 3/10 tasks ✅ (27.2, 27.3, 27.4)  
**In Progress:** 0/10 tasks  
**Pending:** 7/10 tasks

**🎉 Phase 1: COMPLETE!** (3/3 tasks done)

---

## 📝 Future Work / Backlog (Not in Current Plan)

**Worker API Lifecycle Integration** 🔮
- **What:** Integrate dag_token_api.php + worker_token_api.php with TokenLifecycleService
- **Why:** Currently Worker path (dag_token_api) doesn't emit canonical events (NODE_START, NODE_RESUME, etc.)
- **Impact:** Low - Both paths work, just Worker path missing analytics events
- **Priority:** 🟡 Medium (not blocking Phase 2-5)
- **Effort:** 4-6 hours
- **When:** After Phase 1-5 complete, or before production deployment
- **Related:** Task 27.2 (TokenLifecycleService), Task 27.3 (BehaviorExecutionService)
- **Status:** Documented, not scheduled
- **Date Noted:** December 2, 2025

**Current State:**
- ✅ Behavior path: dag_behavior_exec.php → BehaviorExecutionService → TokenLifecycleService ✅
- ⚠️ Worker path: dag_token_api.php → old routing logic (no lifecycle, no canonical events)

**Decision:** Focus on Task 27.4-27.11 first (main plan), defer Worker API integration to later

---

## 🎯 Critical Path

```
27.2 (TokenLifecycle) → 27.3 (Behavior Refactor) → 27.4 (Validation)
    ↓
27.5 (ComponentService) → 27.6 (Component Hooks)
    ↓
27.7 (Parallel API) → 27.8 (Split/Merge Integration) ← 🎉 MILESTONE
    ↓
27.9 (Failure Recovery) → 27.10 (Tray Validation)
    ↓
27.11 (UI API)
```

---

## 🎉 Milestones

**Milestone 1:** Phase 1 Complete (Task 27.2-27.4)
- ✅ Behavior no longer touches token status directly
- ✅ Token status transitions through TokenLifecycleService
- ✅ Validation matrix prevents invalid combinations

**Milestone 2:** Phase 2 Complete (Task 27.5-27.6)
- ✅ Behavior aware of component tokens
- ✅ Component metadata captured
- ✅ Assembly validates components ready

**Milestone 3:** Phase 3 Complete (Task 27.7-27.8) 🎉
- 🎉 **Component Parallel Flow works end-to-end!**
- ✅ Split node spawns components
- ✅ Merge node re-activates parent
- ✅ Component times aggregated

**Milestone 4:** Phase 4 Complete (Task 27.9-27.10)
- ✅ QC fail recovery works
- ✅ Wrong tray detection works
- ✅ Production-ready error handling

**Milestone 5:** Phase 5 Complete (Task 27.11)
- ✅ UI can fetch token context
- ✅ Ready for frontend integration

---

## 📚 References

**Specs:**
- `docs/super_dag/02-specs/BEHAVIOR_EXECUTION_SPEC.md` - Behavior blueprint
- `docs/super_dag/02-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - Token lifecycle
- `docs/super_dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Component rules

**Audit:**
- `docs/super_dag/00-audit/20251202_BEHAVIOR_LAYER_AUDIT_REPORT.md` - Current gaps

---

## 🔑 Critical Rules (Every Task)

**Architecture:**
1. ❌ Behavior ห้าม UPDATE flow_token.status ตรงๆ
2. ❌ Behavior ห้าม implement split/merge logic
3. ❌ Behavior ห้าม aggregate component data
4. ✅ Behavior = Orchestrator (call services only)

**Service Ownership:**
- TokenLifecycleService = Token status
- ComponentFlowService = Component metadata
- ParallelMachineCoordinator = Split/merge
- FailureRecoveryService = Recovery logic
- BehaviorExecutionService = Orchestration

**Testing:**
- ✅ Unit tests สำหรับ services
- ✅ Integration tests สำหรับ flows
- ✅ Manual testing ทุก task
- ✅ Results document ทุก task

---

## 📁 Task Files Location

```
docs/super_dag/tasks/
├── task27.2.md (Phase 1 - TokenLifecycleService)
├── task27.3.md (Phase 1 - Refactor Behavior)
├── task27.4.md (Phase 1 - Validation Matrix)
├── task27.5.md (Phase 2 - ComponentFlowService)
├── task27.6.md (Phase 2 - Component Hooks)
├── task27.7.md (Phase 3 - Parallel API)
├── task27.8.md (Phase 3 - Split/Merge Integration)
├── task27.9.md (Phase 4 - Failure Recovery)
├── task27.10.md (Phase 4 - Tray Validation)
├── task27.11.md (Phase 5 - UI API)
├── results/ (results documents)
└── TASK_INDEX_BEHAVIOR_LAYER_EVOLUTION.md (this file)
```

---

## 🎯 Success Criteria

**After completing all tasks:**

- ✅ Behavior Layer = SuperDAG Behavior Engine (not Legacy Simple Engine)
- ✅ Token Lifecycle integrated
- ✅ Component Flow integrated
- ✅ Parallel execution working
- ✅ Failure recovery working
- ✅ Production-ready
- ✅ 3-5 year lifespan (no major refactoring needed)

---

**Last Updated:** December 2, 2025  
**Status:** 📋 Ready for Execution

