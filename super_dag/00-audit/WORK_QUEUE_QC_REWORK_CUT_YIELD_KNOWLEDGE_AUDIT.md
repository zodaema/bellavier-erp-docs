# Work Queue / QC Rework / CUT Yield Knowledge Audit

**Date:** 2025-12-25  
**Role:** System Archaeologist (Document Discovery Only)  
**Purpose:** Rediscover existing documentation without proposing new designs

---

## Executive Summary

This audit scans the repository for existing documentation related to:
- **Work Queue** (execution queue, worker queue, station queue)
- **Component Flow** (parallel split, merge, component tokens)
- **QC Rework** (human-selected rework, component boundary, defect handling)
- **CUT / Batch Yield** (incremental output, partial yield, spawn tokens)

**Method:** Keyword-based search + manual file review  
**Scope:** `docs/` and `docs/super_dag/` directories  
**Output:** Document inventory + concept map + gap analysis

---

## Document Inventory

### [FILE] docs/super_dag/06-specs/COMPONENT_PARALLEL_FLOW_SPEC.md

- **Purpose:** Production-ready specification for Component Token parallel flow architecture. Defines Component Token as CORE MECHANIC (not optional).
- **Relevant Sections:**
  - **Token Types:** Defines `piece`, `component`, `batch` token types with database fields (`parent_token_id`, `parallel_group_id`, `parallel_branch_key`)
  - **Component Token = First-Class Token:** Component tokens have their own work sessions, time tracking, behavior execution
  - **Parallel Split Mechanism:** Uses native `is_parallel_split` flag (NOT subgraph fork mode)
  - **Assembly Merge:** Assembly node joins component tokens, final serial created at Job Creation (not Assembly)
- **Key Concepts Found:**
  - Component token relationship via `parent_token_id` + `parallel_group_id` (NOT serial pattern matching)
  - Component-level time tracking for craftsmanship analytics
  - ETA model: `max(component_times) + assembly_time`
  - Multi-craftsman signature per component
- **Status Signal:** Production-ready specification (Version 2.1, 3-5 year lifespan)
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/super_dag/06-specs/SUPERDAG_TOKEN_LIFECYCLE.md

- **Purpose:** Core architecture specification defining lifecycle of all token types in SuperDAG universe.
- **Relevant Sections:**
  - **Token Lifecycle States:** `ready`, `active`, `waiting`, `paused`, `completed`, `scrapped` with state transition diagram
  - **Component Spawn:** When parallel split node reached, spawns M component tokens with `parallel_group_id` and `parallel_branch_key`
  - **Component Merge (Assembly):** All component tokens reach merge node, parent token re-activated
  - **Batch Spawn (Future):** Cutting batch completes → spawn N piece tokens
  - **Replacement Spawn (Recovery):** Token scrapped → spawn replacement token
- **Key Concepts Found:**
  - Terminal states: `completed` and `scrapped` (cannot transition further)
  - Component tokens have `parent_token_id` linking to final token
  - Parallel group mechanism for tracking related components
- **Status Signal:** Core Architecture Specification (Version 1.0)
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/super_dag/01-concepts/QC_REWORK_PHILOSOPHY_V2.md

- **Purpose:** Philosophy and design for QC Rework V2 system with human-selected rework targets.
- **Relevant Sections:**
  - **Component Boundary Rule:** Rework MUST stay within same component branch (BODY work cannot go to STITCH_FLAP)
  - **Rework Target Selection Algorithm:** Finds component anchor, gets nodes downstream of anchor (same branch), filters valid targets
  - **Safety Net - Manual Override:** If algorithm finds no targets, shows manual override UI with dropdown (limited to same component branch)
  - **Same-Component Branch Constraint:** QC must select node in same branch only (prevents cross-branch routing)
- **Key Concepts Found:**
  - Human-selected rework target (`target_node_id` in form data)
  - Component anchor finding algorithm
  - Same-component branch validation (`validateReworkTargetSelection()`)
  - Manual override fallback with logging
- **Status Signal:** Concept document (V2 philosophy)
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/super_dag/04-contracts/EDGE_REWORK_CONTRACT.md

- **Purpose:** Runtime contract for edge rework routing (locked for determinism).
- **Relevant Sections:**
  - **V2 Path (handleQCFailV2 - Human Selection):** Direct `moveTokenToNode()` (NO edge traversal), validates same-component branch, checks max rework count
  - **Entry Point:** `BehaviorExecutionService::handleQc()` line 1600 checks `$targetNodeId !== null`
  - **Validation:** Same-component branch check via `validateReworkTargetSelection()`
  - **Audit Log:** Logs to `qc_rework_override_log`
- **Key Concepts Found:**
  - V2 human-selected rework bypasses edge traversal entirely
  - Component boundary enforcement in runtime
  - Max rework count check (`MAX_REWORK_COUNT_PER_TOKEN`)
- **Status Signal:** LOCKED (Runtime Determinism, Version 1.0, 2025-11-14)
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/super_dag/tasks/archive/completed_tasks/task27.15_QC_REWORK_V2_PLAN.md

- **Purpose:** Implementation plan for QC Rework V2 system.
- **Relevant Sections:**
  - **isValidReworkTarget():** Excludes node types (`start`, `end`, `split`, `join`, `merge`, `decision`, `router`, `component`, `qc`), enforces same component branch via `qcAnchorSlot`
  - **validateReworkTargetSelection():** Security check preventing arbitrary routing, MUST pass `qcAnchorSlot` to enforce same-branch rule
  - **handleQCFailV2():** Handles `rework_mode` (`same_piece` vs `recut`), validates target selection, routes token or spawns replacement
  - **CTO Audit Fix #2:** Must enforce same component branch rule (BODY work cannot go to STITCH_FLAP)
- **Key Concepts Found:**
  - Rework mode: `same_piece` (route same token) vs `recut` (scrap + spawn replacement)
  - Component anchor slot (`anchor_slot`) for branch identification
  - Cross-component rework prevention for traceability
- **Status Signal:** Implementation plan (completed task)
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/super_dag/specs/MATERIAL_PRODUCTION_MASTER_SPEC.md

- **Purpose:** Master specification for material production including CUT node batch workflow.
- **Relevant Sections:**
  - **CUT Node Batch Workflow (V3 Final):** Graph = Process Logic (doesn't track component), CUT works per-component-quantity (not token-by-token), leather = one object per piece (Sheet/Scrap)
  - **Component Output (Post-CUT):** Doesn't split tokens into multiple paths, but splits "Component Output" for each downstream node via Component Mapping
  - **Token State for CUT Node:** Tokens change to `ready` but don't split to downstream nodes, components produced sent to downstream nodes via Component Mapping, tokens re-engage at Assembly
  - **Yield Calculation:** `usable quantity per component` tracked separately, system calculates `minimum(component.usable / component.required)` for final yield
- **Key Concepts Found:**
  - CUT node = batch work (not token-by-token)
  - Component-level yield tracking (usable/waste per component)
  - Component Output mapping to downstream nodes (not token splitting)
  - Token state management during CUT (tokens wait, components flow)
- **Status Signal:** Master specification
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/super_dag/00-audit/20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md

- **Purpose:** Audit report on Work Queue and Token Lifecycle integration.
- **Relevant Sections:**
  - **Work Queue Definition:** Operator-facing queue showing tokens assigned to worker, filtered by node/work center
  - **Token Lifecycle States:** `ready`, `active`, `waiting`, `paused`, `completed`, `scrapped` with transitions
  - **Work Session Tracking:** Time tracking per token with pause/resume support
  - **Queue Filtering:** Operators see only assigned tokens, filtered by node/work center
- **Key Concepts Found:**
  - Work Queue = operator-facing token list
  - Token assignment to workers
  - Work session time tracking
  - Queue filtering by node/work center
- **Status Signal:** Audit report (2025-12-02)
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/developer/SYSTEM_WIRING_GUIDE.md

- **Purpose:** System wiring guide showing how components connect.
- **Relevant Sections:**
  - **Work Queue:** `worker_token_api` - Hatthasilpa ONLY, shows tokens assigned to operator
  - **Work Center Behavior Mode Mapping:** `HAT_SINGLE`, `BATCH_QUANTITY`, `CLASSIC_SCAN`, `QC_SINGLE` modes
  - **Assignment Rules:** Use assignment system for Hatthasilpa DAG only, use Work Queue for Hatthasilpa token operations
- **Key Concepts Found:**
  - Work Queue API: `worker_token_api.php`
  - Work center behavior modes determine execution profiles
  - Assignment system for Hatthasilpa only
- **Status Signal:** System wiring guide
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/dag/05-implementation-status/NODE_TYPE_POLICY.md

- **Purpose:** Definitive specification for node type behavior, actions, and visibility.
- **Relevant Sections:**
  - **Node Type Policy Matrix:** `operation` and `qc` nodes visible in Work Queue, `split` and `join` nodes NOT visible (system-controlled)
  - **QC Node Actions:** `pass`, `fail` actions only, status transitions: `ready` → `qc_pass` / `qc_fail` → `routed`
- **Key Concepts Found:**
  - Work Queue visibility rules per node type
  - QC node specific actions (pass/fail)
  - System-controlled nodes (split/join) not visible in queue
- **Status Signal:** CRITICAL - Required for Phase 2B.5 implementation
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/archive/other/routing_graph_designer/SYSTEM_INTEGRATION_UNDERSTANDING.md

- **Purpose:** System integration understanding document (archive).
- **Relevant Sections:**
  - **Work Queue System:** Operator journey example, token filtering (operators see only assigned tokens), multi-piece flexibility (pause and switch pieces), accurate time tracking (excludes pause time)
  - **Work Session Tracking:** Calculate actual work time (excludes pauses), work session per token
- **Key Concepts Found:**
  - Operator workflow example (1 day)
  - Token filtering in work queue
  - Multi-piece work flexibility
  - Time tracking excluding pauses
- **Status Signal:** Archive document (older reference)
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/developer/03-superdag/04-implementation/DAG_EXAMPLES.md

- **Purpose:** Provides DAG implementation examples, including batch flow and yield tracking.
- **Relevant Sections:**
  - **Batch Flow (Cutting):** Batch session flow, yield tracking example (target 50, actual 48), batch → token split logic
  - **Batch Session Flow:** Worker starts batch, processes batch (single time duration), output actual_qty, system splits batch into individual tokens
- **Key Concepts Found:**
  - Batch session workflow
  - Yield tracking (target vs actual)
  - Batch token split into individual tokens
- **Status Signal:** Implementation examples
- **Open Questions Mentioned:** None explicitly stated

---

### [FILE] docs/developer/03-superdag/03-specs/SPEC_TOKEN_ENGINE.md

- **Purpose:** Token Engine specification.
- **Relevant Sections:**
  - **Batch Session Flow:** Batch token creation, batch completion with actual_qty, token split into single tokens
  - **Extensions Needed (Future):** `batch_session_id`, `planned_qty`, `actual_qty`, `scrap_qty`, `rework_count`, `rework_history`
- **Key Concepts Found:**
  - Batch token lifecycle
  - Future extensions for batch tracking
  - Rework history tracking (future)
- **Status Signal:** Specification document
- **Open Questions Mentioned:** None explicitly stated

---

## Cross-Document Synthesis

### 🔗 Concept Map (From Actual Documents Found)

#### 1. QC Rework

**Human-selected rework target:**
- Found in:
  - `docs/super_dag/01-concepts/QC_REWORK_PHILOSOPHY_V2.md` (section: Rework Target Selection Algorithm)
  - `docs/super_dag/04-contracts/EDGE_REWORK_CONTRACT.md` (section: V2 Path - Human Selection)
  - `docs/super_dag/tasks/archive/completed_tasks/task27.15_QC_REWORK_V2_PLAN.md` (section: handleQCFailV2())

**Component boundary (rework scope):**
- Found in:
  - `docs/super_dag/01-concepts/QC_REWORK_PHILOSOPHY_V2.md` (section: Component Boundary Rule)
  - `docs/super_dag/tasks/archive/completed_tasks/task27.15_QC_REWORK_V2_PLAN.md` (section: CTO Audit Fix #2 - Same Component Branch)
  - `docs/super_dag/04-contracts/EDGE_REWORK_CONTRACT.md` (section: V2 Path - validates same-component branch)

**Token history for QC:**
- Missing / unclear:
  - No explicit document found describing token history/audit trail for QC decisions
  - `SPEC_TOKEN_ENGINE.md` mentions `rework_history` as future extension, but not implemented

---

#### 2. CUT / Batch Yield

**Yield between work (not waiting for complete):**
- Found in:
  - `docs/super_dag/specs/MATERIAL_PRODUCTION_MASTER_SPEC.md` (section: Component Output Post-CUT - components flow to downstream nodes while tokens wait)
  - `docs/developer/03-superdag/04-implementation/DAG_EXAMPLES.md` (section: Batch Session Flow - output actual_qty during batch processing)

**Spawn tokens during work:**
- Found in:
  - `docs/super_dag/06-specs/SUPERDAG_TOKEN_LIFECYCLE.md` (section: Batch Spawn - Future: Cutting batch completes → spawn N piece tokens)
  - `docs/developer/03-superdag/03-specs/SPEC_TOKEN_ENGINE.md` (section: Batch Session Flow - token split into single tokens)

**Incremental/partial yield:**
- Found in:
  - `docs/super_dag/specs/MATERIAL_PRODUCTION_MASTER_SPEC.md` (section: Yield Calculation - usable quantity per component tracked separately)
  - `docs/developer/03-superdag/04-implementation/DAG_EXAMPLES.md` (section: Yield Tracking Example - target 50, actual 48)

**Missing / unclear:**
- No explicit document found describing incremental yield reporting (reporting yield before batch complete)
- Component-level yield tracking exists in MATERIAL_PRODUCTION_MASTER_SPEC, but incremental reporting not detailed
- **Note:** MATERIAL_PRODUCTION_MASTER_SPEC mentions "Component Output flows to downstream nodes while tokens wait" (line 872), suggesting yield can flow before batch complete, but explicit incremental reporting mechanism not documented

---

#### 3. Work Queue

**Queue per work center:**
- Found in:
  - `docs/developer/SYSTEM_WIRING_GUIDE.md` (section: Work Queue - `worker_token_api` for Hatthasilpa)
  - `docs/super_dag/00-audit/20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md` (section: Queue Filtering - filtered by node/work center)

**Token enqueue/dequeue:**
- Found in:
  - `docs/super_dag/00-audit/20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md` (section: Token Lifecycle States - `ready` → `active` → `completed`)
  - `docs/dag/05-implementation-status/NODE_TYPE_POLICY.md` (section: Node Type Policy Matrix - tokens visible in Work Queue for `operation` and `qc` nodes)

**Worker-driven pull:**
- Found in:
  - `docs/archive/other/routing_graph_designer/SYSTEM_INTEGRATION_UNDERSTANDING.md` (section: Work Queue System - operators see only assigned tokens, multi-piece flexibility)
  - `docs/super_dag/00-audit/20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md` (section: Work Queue Definition - operator-facing queue showing tokens assigned to worker)

**Missing / unclear:**
- No explicit document found describing push vs pull mechanism in detail
- Assignment system mentioned in SYSTEM_WIRING_GUIDE, but queue pull mechanism not detailed

---

## Explicit Gap Report

| Concept | Found in Docs? | File(s) | Notes |
|---------|----------------|---------|-------|
| QC human-selected rework | **YES** | `QC_REWORK_PHILOSOPHY_V2.md`, `EDGE_REWORK_CONTRACT.md`, `task27.15_QC_REWORK_V2_PLAN.md` | Well documented with algorithm and validation rules |
| Component rework boundary | **YES** | `QC_REWORK_PHILOSOPHY_V2.md`, `task27.15_QC_REWORK_V2_PLAN.md`, `EDGE_REWORK_CONTRACT.md` | Same-component branch rule enforced |
| CUT incremental yield | **PARTIAL** | `MATERIAL_PRODUCTION_MASTER_SPEC.md` (component-level tracking), `DAG_EXAMPLES.md` (batch yield) | Component yield tracking exists, but incremental reporting (before complete) not explicitly detailed |
| Work Queue definition | **YES** | `20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md`, `SYSTEM_WIRING_GUIDE.md`, `NODE_TYPE_POLICY.md` | Operator-facing queue with filtering documented |
| Token history for QC | **NO** | `SPEC_TOKEN_ENGINE.md` (mentions `rework_history` as future) | Not found in current documentation |
| Yield before complete | **PARTIAL** | `MATERIAL_PRODUCTION_MASTER_SPEC.md` (Component Output flows while tokens wait) | Concept exists but incremental yield reporting not detailed |
| Spawn tokens during work | **YES** | `SUPERDAG_TOKEN_LIFECYCLE.md` (Batch Spawn - Future), `SPEC_TOKEN_ENGINE.md` (token split) | Documented as future feature and in batch flow |
| Worker-driven pull mechanism | **PARTIAL** | `SYSTEM_INTEGRATION_UNDERSTANDING.md` (operators see assigned tokens), `SYSTEM_WIRING_GUIDE.md` (assignment system) | Concept mentioned but pull mechanism details not explicit |

---

## Final Summary

### 📚 Document List (By Priority)

**High Priority (Core Specifications):**
1. `docs/super_dag/06-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` - Component token architecture
2. `docs/super_dag/06-specs/SUPERDAG_TOKEN_LIFECYCLE.md` - Token lifecycle states and transitions
3. `docs/super_dag/01-concepts/QC_REWORK_PHILOSOPHY_V2.md` - QC rework V2 philosophy
4. `docs/super_dag/04-contracts/EDGE_REWORK_CONTRACT.md` - Runtime contract for rework
5. `docs/super_dag/specs/MATERIAL_PRODUCTION_MASTER_SPEC.md` - CUT node batch workflow

**Medium Priority (Implementation Plans & Audits):**
6. `docs/super_dag/tasks/archive/completed_tasks/task27.15_QC_REWORK_V2_PLAN.md` - QC rework V2 implementation plan
7. `docs/super_dag/00-audit/20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md` - Work queue audit
8. `docs/developer/SYSTEM_WIRING_GUIDE.md` - System wiring and work queue API

**Reference (Examples & Policies):**
9. `docs/dag/05-implementation-status/NODE_TYPE_POLICY.md` - Node visibility in work queue
10. `docs/developer/03-superdag/04-implementation/DAG_EXAMPLES.md` - Batch flow examples
11. `docs/developer/03-superdag/03-specs/SPEC_TOKEN_ENGINE.md` - Token engine spec (future extensions)

**Archive (Historical Reference):**
12. `docs/archive/other/routing_graph_designer/SYSTEM_INTEGRATION_UNDERSTANDING.md` - Older work queue reference

---

### 🧠 Concepts We Actually Thought About (With File References)

**QC Human-Selected Rework:**
- ✅ **Documented:** Algorithm for finding rework targets (`QC_REWORK_PHILOSOPHY_V2.md`)
- ✅ **Documented:** Same-component branch validation (`task27.15_QC_REWORK_V2_PLAN.md`)
- ✅ **Documented:** Runtime implementation (`EDGE_REWORK_CONTRACT.md` - V2 Path)
- ✅ **Documented:** Manual override fallback (`QC_REWORK_PHILOSOPHY_V2.md` - Safety Net)

**Component Boundary:**
- ✅ **Documented:** Component anchor finding (`QC_REWORK_PHILOSOPHY_V2.md`)
- ✅ **Documented:** Same-branch constraint (`task27.15_QC_REWORK_V2_PLAN.md` - CTO Audit Fix #2)
- ✅ **Documented:** Cross-component prevention (`EDGE_REWORK_CONTRACT.md`)

**CUT Batch Yield:**
- ✅ **Documented:** Component-level yield tracking (`MATERIAL_PRODUCTION_MASTER_SPEC.md`)
- ✅ **Documented:** Component Output mapping (`MATERIAL_PRODUCTION_MASTER_SPEC.md` - Post-CUT)
- ✅ **Documented:** Batch token split (`SUPERDAG_TOKEN_LIFECYCLE.md` - Batch Spawn)
- ⚠️ **Partial:** Incremental yield reporting (concept exists but not detailed)

**Work Queue:**
- ✅ **Documented:** Operator-facing queue (`20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md`)
- ✅ **Documented:** Token filtering by work center (`SYSTEM_WIRING_GUIDE.md`)
- ✅ **Documented:** Node visibility rules (`NODE_TYPE_POLICY.md`)
- ⚠️ **Partial:** Pull mechanism details (concept mentioned but not explicit)

---

### ❓ Concepts We Thought We Had But No Evidence Found

**Token History for QC Decisions:**
- ❌ **Not Found:** No document describes token history/audit trail for QC decisions
- ⚠️ **Future Mention:** `SPEC_TOKEN_ENGINE.md` mentions `rework_history` as future extension, but not implemented

**Incremental Yield Reporting (Before Batch Complete):**
- ❌ **Not Found:** No explicit document describes reporting yield incrementally during batch work
- ⚠️ **Concept Exists:** Component Output flows to downstream nodes while tokens wait (`MATERIAL_PRODUCTION_MASTER_SPEC.md`), but incremental reporting not detailed

**Worker-Driven Pull Mechanism Details:**
- ❌ **Not Found:** No explicit document describes push vs pull mechanism in detail
- ⚠️ **Concept Exists:** Operators see assigned tokens (`SYSTEM_INTEGRATION_UNDERSTANDING.md`), assignment system mentioned (`SYSTEM_WIRING_GUIDE.md`), but pull mechanism not detailed

**Yield Before Complete (Explicit Specification):**
- ❌ **Not Found:** No explicit document describes yield reporting before batch completion
- ⚠️ **Concept Exists:** Component Output flows while tokens wait (`MATERIAL_PRODUCTION_MASTER_SPEC.md`), but yield reporting timing not specified

---

## Document Age Classification

### Recent (2025-12-02 to 2025-12-25)
- `COMPONENT_PARALLEL_FLOW_SPEC.md` (2025-12-02, Version 2.1)
- `SUPERDAG_TOKEN_LIFECYCLE.md` (2025-12-02, Version 1.0)
- `EDGE_REWORK_CONTRACT.md` (2025-11-14, Version 1.0, locked)
- `MATERIAL_PRODUCTION_MASTER_SPEC.md` (latest CUT V3 workflow)
- `20251202_WORK_QUEUE_TOKEN_LIFECYCLE_INTEGRATION_AUDIT.md` (2025-12-02)

### Older (2025-11 to 2025-12-01)
- `QC_REWORK_PHILOSOPHY_V2.md` (concept document)
- `task27.15_QC_REWORK_V2_PLAN.md` (completed task, implementation plan)
- `SYSTEM_WIRING_GUIDE.md` (system wiring reference)

### Archive (Pre-2025-11)
- `docs/archive/other/routing_graph_designer/SYSTEM_INTEGRATION_UNDERSTANDING.md` (older reference)

---

**Status:** ✅ **COMPLETE**  
**Method:** Keyword search + manual file review  
**Role:** System Archaeologist (Document Discovery Only)  
**No Design Proposals:** This audit only reports what exists in documentation
