# DAG Task Index (Unified)

**Bellavier Group ERP – DAG Documentation System**

This is the unified task index for all DAG-related documentation and tasks.  
All new designs must reference `super_dag/*` exclusively.

---

## Core

- [DAG_Blueprint.md](DAG_Blueprint.md) - Canonical foundational model of the Bellavier DAG Engine
- [DAG_IMPLEMENTATION_GUIDE.md](DAG_IMPLEMENTATION_GUIDE.md) - Implementation recipes for building the DAG Engine
- [DAG_EXAMPLES.md](DAG_EXAMPLES.md) - Example DAG graphs and production flows

---

## Active Tasks

### Task 1 Series (Super DAG Bootstrap)

- [task1.md](tasks/task1.md) - Bootstrap Work Center Behavior (Super DAG Foundation)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates `work_center_behavior` and `work_center_behavior_map` tables
  - Seeds preset behaviors (CUT, EDGE, STITCH, QC_FINAL, HARDWARE_ASSEMBLY, QC_REPAIR)
  - Implements `WorkCenterBehaviorRepository` PHP class
  - Integrates behavior metadata into `work_centers.php` API

- [task2.md](tasks/task2.md) - Work Center Behavior Mapping UI + API
  - Status: ✅ **COMPLETED** (December 2025)
  - Adds 3 API actions: `get_behavior_list`, `bind_behavior`, `unbind_behavior`
  - Creates `work_centers_behavior.js` for UI behavior management
  - Adds Behavior column to Work Centers DataTable
  - Implements behavior selection modal with bind/unbind functionality
  - Results: [task2_results.md](tasks/task2_results.md)

- [task3.md](tasks/task3.md) - Behavior Awareness Integration (Read-Only Phase)
  - Status: ✅ **COMPLETED** (December 2025)
  - Enriches 6 APIs with behavior metadata: `dag_token_api.php`, `dag_routing_api.php`, `pwa_scan_api.php`, `mo.php`, `hatthasilpa_job_ticket.php`
  - Adds behavior badges to 4 UIs: Work Queue, Job Ticket, MO Detail, PWA Scan
  - Read-only phase: No execution logic added, only metadata display
  - 100% backward compatible (behavior field is optional)
  - Results: [task3_results.md](tasks/task3_results.md)

- [task4.md](tasks/task4.md) - Behavior-Aware UX Layer (Pre-Execution Phase)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates `behavior_ui_templates.js` registry with 6 behavior templates (CUT, STITCH, EDGE, HARDWARE_ASSEMBLY, QC_SINGLE, QC_FINAL)
  - Integrates behavior UI panels into PWA Scan (token view), Work Queue (collapsible panels), Job Ticket (routing steps)
  - Pre-execution phase: UI templates only, no execution logic or state changes
  - 100% backward compatible with fail-safe error handling
  - Results: [task4_results.md](tasks/task4_results.md)

- [task5.md](tasks/task5.md) - Behavior Execution Spine (Stub Endpoint + Handler Wiring)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates `dag_behavior_exec.php` stub API endpoint for behavior execution requests
  - Creates `behavior_execution.js` execution spine with `BGBehaviorExec` global object
  - Registers behavior handlers for all 6 behaviors (STITCH, CUT, EDGE, HARDWARE_ASSEMBLY, QC_SINGLE, QC_FINAL)
  - Integrates handler initialization into PWA Scan, Work Queue, and Job Ticket
  - Stub phase: Logs requests and returns `{ok: true}` without modifying Token/Time/DAG Engine
  - 100% backward compatible, all buttons send standardized payloads
  - Results: [task5_results.md](tasks/task5_results.md)

- [task6.md](tasks/task6.md) - Token Engine Integration (Phase 1: Logging + Minimal Token Touch)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates `dag_behavior_log` table for behavior execution logging
  - Creates `BehaviorExecutionService` PHP class for centralized behavior execution
  - Integrates service into `dag_behavior_exec.php` (replaces stub)
  - Implements minimal token status updates for STITCH (start/resume → ensure 'active')
  - All behaviors log to `dag_behavior_log` table
  - CUT, EDGE, QC: Log-only (no token status changes)
  - 100% backward compatible, graceful degradation if table missing
  - Results: [task6_results.md](tasks/task6_results.md)

- [task7.md](tasks/task7.md) - Time Engine Integration (STITCH Behavior Only)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates `BGERP\Dag\TokenWorkSessionService` wrapper around existing `BGERP\Service\TokenWorkSessionService`
  - Integrates Time Engine into `BehaviorExecutionService::handleStitch()`
  - STITCH actions: `stitch_start` → creates session, `stitch_pause` → pauses session, `stitch_resume` → resumes session
  - All STITCH actions create/update sessions in `token_work_session` table
  - Dual logging: `token_work_session` (Time Engine) + `dag_behavior_log` (Audit Trail)
  - CUT, EDGE, QC: Still log-only (no Time Engine integration)
  - 100% backward compatible, comprehensive error handling
  - Results: [task7_results.md](tasks/task7_results.md)

- [task8.md](tasks/task8.md) - DAG Execution Logic (Phase 1: Refactor & Consolidate)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates `BGERP\Dag\DagExecutionService` central service for token movement
  - Consolidates DAG movement logic from `dag_token_api.php` into service layer
  - Methods: `moveToNextNode()`, `moveToNodeId()`, `reopenPreviousNode()` (stub)
  - Refactors `handleTokenMove()` and `handleCompleteToken()` to use service
  - Preserves 100% backward compatibility (same input → same output)
  - Complex routing logic (split/join/QC) still in `DAGRoutingService` (preserved)
  - Phase 1: Refactor only, no new features, no behavior changes
  - Results: [task8_results.md](tasks/task8_results.md)

- [task9.md](tasks/task9.md) - Behavior–DAG Integration (Phase 2)
  - Status: ✅ **COMPLETED** (December 2025)
  - Integrates `BehaviorExecutionService` with `DagExecutionService`
  - STITCH `stitch_complete` action routes token to next node automatically
  - QC `qc_pass` action routes token to next node (pass path)
  - QC `qc_fail` / `qc_rework` actions route token to rework node
  - API response includes optional `routing` field (non-breaking)
  - Frontend dispatches `BG:TokenRouted` event when token routed
  - Work Queue and PWA Scan auto-refresh UI when token routed
  - 100% backward compatible (routing field is optional)
  - Phase 2: Behavior-DAG integration, automatic routing after behavior completion
  - Results: [task9_results.md](tasks/task9_results.md)

- [task10.md](tasks/task10.md) - Behavior & Routing Validation Guards (Phase 2.5)
  - Status: ✅ **COMPLETED** (December 2025)
  - Adds comprehensive validation guards to `BehaviorExecutionService`
  - Prevents session conflicts (duplicate start, resume without pause)
  - Validates token status before behavior actions (prevents closed token operations)
  - Validates worker ownership before pause/complete
  - Adds routing validation to `DagExecutionService` (token state, next node)
  - Standardizes error codes and HTTP status codes
  - Distinguishes between end node completion and graph errors
  - 100% backward compatible (error responses enhanced, success unchanged)
  - Phase 2.5: Validation guards, error handling, safety rails
  - Results: [task10_results.md](tasks/task10_results.md)

- [task11.md](tasks/task11.md) - Enhanced Session Management (Phase 3)
  - Status: ✅ **COMPLETED** (December 2025)
  - Forces session lifecycle consistency for STITCH behavior
  - Requires active session before `stitch_complete` (error if missing)
  - Closes session before token routing (prevents routing with active session)
  - Adds session summary to response (total_work_seconds, total_pause_seconds, started_at, ended_at)
  - Blocks routing in `DagExecutionService` if session still active
  - Adds error codes: `BEHAVIOR_NO_ACTIVE_SESSION_FOR_COMPLETE`, `DAG_SESSION_STILL_ACTIVE`
  - 100% backward compatible (session_summary is optional field)
  - Phase 3: Enhanced session management, lifecycle enforcement
  - Results: [task11_results.md](tasks/task11_results.md)

- [task12.md](tasks/task12.md) - Advanced Session & Time Safeguards (STITCH v2)
  - Status: ✅ **COMPLETED** (December 2025)
  - Implements stale session detection (auto-detect sessions exceeding 8-hour threshold)
  - Enforces single-active-session-per-worker rule (prevents multiple active sessions)
  - Adds minimal self-recovery flow (auto-close stale session on same token)
  - Blocks start/resume when conflicting sessions exist
  - Blocks resume on stale sessions (with supervisor contact suggestion)
  - Adds error codes: `BEHAVIOR_STITCH_CONFLICTING_SESSION`, `BEHAVIOR_STITCH_SESSION_STALE`
  - Enhanced UI feedback with user-friendly Thai error messages
  - 100% backward compatible (conflict and suggested_action are optional fields)
  - Phase 3: Advanced safeguards, conflict detection, stale detection
  - Results: [task12_results.md](tasks/task12_results.md)

- [task13.md](tasks/task13.md) - Supervisor Override & Session Recovery UI (STITCH v1)
  - Status: ✅ **COMPLETED** (December 2025)
  - Supervisor UI for viewing and managing active/stale sessions
  - DataTable with filtering (worker, status, behavior)
  - Force close sessions with required reason
  - Mark sessions as reviewed with optional note
  - Full audit logging to dag_behavior_log
  - Permission checks (platform admin or tenant admin only)
  - Uses SSDTQueryBuilder for secure server-side DataTable
  - 100% backward compatible (new endpoint, no breaking changes)
  - Phase 1: Supervisor UI for STITCH sessions
  - Results: [task13_results.md](tasks/task13_results.md)

- [task13.1.md](tasks/task13.1.md) - DAG Supervisor Sessions Permission Setup
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates permission code `DAG_SUPERVISOR_SESSIONS` in core and tenant DBs
  - Assigns permission to admin roles (PLATFORM_ADMIN, TENANT_ADMIN)
  - Adds hybrid permission guard in endpoint (role-based + permission code)
  - Idempotent migrations (safe to run multiple times)
  - Integration tests for permission enforcement
  - 100% backward compatible (fallback to role-based check if permission missing)
  - Results: [task13.1_results.md](tasks/task13.1_results.md)

- [task13.2.md](tasks/task13.2.md) - RBAC Full Safety Sweep & DB Permission Fix
  - Status: ✅ **COMPLETED** (December 2025)
  - Fixed all database access issues (DatabaseHelper::prepare() errors)
  - Standardized database source (Core DB vs Tenant DB)
  - Added platform permission filtering (platform.*, serial.*, migration.*)
  - Protected Owner role from modification/deletion
  - Created RbacHelper class for reusable RBAC logic
  - Optional cleanup migration for platform permissions
  - 100% backward compatible (no breaking changes)
  - Results: [task13.2_results.md](tasks/task13.2_results.md)

- [task14.md](tasks/task14.md) - Super DAG Behavior Execution (CUT / EDGE / QC) — Minimal Viable Production Line
  - Status: ✅ **COMPLETED** (December 2025)
  - **CUT Behavior Implementation:**
    - `handleCutStart()` - Start batch cutting session
    - `handleCutComplete()` - Complete cutting session and route to STITCH
    - Batch mode: No per-piece tracking (single session per batch)
    - Uses TokenWorkSessionService (same as STITCH)
    - Automatically routes tokens to STITCH node after complete
    - Actions: `cut_start`, `cut_complete`
  - **EDGE Behavior Implementation:**
    - `handleEdgeStart()` - Start edge coating session
    - `handleEdgeComplete()` - Complete edge coating session and route to next node
    - MVP mode: Single round per token (no multi-round)
    - Simple start/complete flow (no drying timer)
    - Uses TokenWorkSessionService
    - Automatically routes tokens to next node after complete
    - Actions: `edge_start`, `edge_complete`
  - **QC Behavior:**
    - Already implemented in Task 9 (no changes needed)
    - `qc_pass` → Route token to next node (pass path)
    - `qc_fail` → Route to rework node (if rework edge exists)
  - **JavaScript UI Handlers:**
    - CUT handlers: `#btn-cut-start`, `#btn-cut-complete`
    - EDGE handlers: `#btn-edge-start`, `#btn-edge-complete`
    - Auto-refreshes work queue after actions
  - **Files Modified:**
    - `source/BGERP/Dag/BehaviorExecutionService.php` - Full CUT/EDGE implementation
    - `assets/javascripts/dag/behavior_execution.js` - UI handlers
  - **Production Line Flow (MVP):**
    - Full production line now functional: CUT → STITCH → EDGE → QC → PACK
    - All behaviors use same session engine pattern
  - All behaviors integrate with DAG routing (DagExecutionService)
    - Full validation, error handling, and logging
  - Results: [task14_results.md](tasks/task14_results.md)

- [task15.md](tasks/task15.md) - DAG Node Behavior Binding & Graph Standardization (Phase 4)
  - Status: ✅ **COMPLETED** (December 2025)
  - Establishes first true DAG graph standardization layer
  - Ensures every DAG node has canonical `behavior_code` derived from Work Center Behavior mapping
  - Removes all "implicit behavior inference" from runtime
  - Builds foundation for Task 16–20 (Parallel / Merge / Machine / SLA)
  - **Schema Updates:**
    - Added `behavior_code` VARCHAR(50) NULL and `behavior_version` INT to `routing_node` table
    - Migration backfills behavior_code for existing nodes using work_center_behavior_map
  - **API Updates:**
    - `node_create`: Requires behavior_code for operation nodes, auto-resolves from work center
    - `node_update`: Validates behavior_code, prevents system node changes
    - `loadGraphWithVersion()`: Includes behavior_code in graph responses
  - **Service Updates:**
    - `BehaviorExecutionService`: Validates behavior_code match before execution
    - `DagExecutionService`: Includes behavior_code in node metadata
  - **Safety Rails:**
    - System nodes cannot change behavior_code
    - Operation nodes require behavior_code
    - Behavior_code must exist in work_center_behavior registry
  - Results: [task15_results.md](tasks/task15_results.md)

- [task16.md](tasks/task16.md) - Execution Mode Binding (Behavior + Mode = NodeType)
  - Status: ✅ **COMPLETED** (December 2025)
  - Establishes true NodeType Model: NodeType = Behavior + ExecutionMode
  - Enables deterministic routing, time modeling, QC flows, parallel paths, machine-driven flows, and analytics & throughput SLA
  - Builds foundation for Task 17 (Parallel Node Execution)
  - **Schema Updates:**
    - Added `execution_mode` VARCHAR(50) NULL and `derived_node_type` VARCHAR(100) NULL to `routing_node` table
    - Migration backfills execution_mode for existing nodes using canonical mapping
  - **NodeTypeRegistry Class:**
    - Provides validation and derivation logic for node types
    - Canonical mapping: Behavior → ExecutionMode (CUT→BATCH, STITCH→HAT_SINGLE, QC_FINAL→QC_SINGLE, etc.)
    - Valid execution modes: BATCH, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE
  - **API Updates:**
    - `node_create`: Requires execution_mode for operation nodes, auto-resolves from canonical mapping
    - `node_update`: Validates execution_mode, prevents system node changes
    - `loadGraphWithVersion()`: Includes execution_mode and derived_node_type in graph responses
  - **Service Updates:**
    - `BehaviorExecutionService`: Validates execution_mode match before execution
    - `DagExecutionService`: Includes execution_mode in node metadata
  - **Safety Rails:**
    - System nodes cannot change execution_mode
    - Operation nodes require execution_mode
    - Behavior + mode combination must be allowed
    - Execution mode must be valid (BATCH, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE)
  - Results: [task16_results.md](tasks/task16_results.md)

### Reserved Refactor Slot – Behavior “App Layer”

These are **reserved, not-yet-implemented** tasks for the day we want to refactor each behavior into a more app‑like, modular layer.  
**DO NOT** start these without an explicit green‑light / design review; they are placeholders only.

- `taskB1` – Behavior App Layer Skeleton  
  - Extract behavior dispatch table from `BehaviorExecutionService` into a dedicated registry  
  - Define stable per‑behavior interface (e.g., `execute($context, $payload): BehaviorResult`)  
  - Keep 100% backward compatibility: same endpoint, same payload, same responses

- `taskB2` – STITCH Behavior Isolation  
  - Move all STITCH‑specific logic into its own “app” module (PHP + JS), behind the common interface  
  - Keep `BehaviorExecutionService` as thin delegator only  
  - Add focused tests around STITCH flow (start/pause/resume/complete + routing)

- `taskB3` – QC Behavior Isolation (QC_SINGLE / QC_FINAL)  
  - Extract QC branch logic into dedicated QC behavior module  
  - Preserve current routing behavior (pass / fail / rework)  
  - Add tests for QC edge cases without touching STITCH

- `taskB4` – CUT / EDGE / HARDWARE Behavior Modules (Log‑First)  
  - Prepare modules for CUT, EDGE, HARDWARE_ASSEMBLY as log‑first apps  
  - Only after real usage patterns are clear, gradually add stateful behavior  
  - Ensure each behavior module can be deployed / rolled back independently

> Note: These tasks are **conceptual slots**. When the time comes, create proper `tasks/taskBx.md` files with detailed specs and safety rails before coding.

- [task17.md](tasks/task17.md) - Parallel Node Execution & Merge Semantics
  - Status: ✅ **COMPLETED** (December 2025)
  - Introduces first-class support for parallel branches and merge nodes
  - Enables true parallel execution with proper token synchronization
  - Transforms DAG from linear chain into true directed acyclic graph with branches and joins
  - **Schema Updates:**
    - Added `parallel_group_id` and `parallel_branch_key` to `flow_token` table
    - Added `is_parallel_split`, `is_merge_node`, and `merge_mode` to `routing_node` table
  - **Execution Logic:**
    - Parallel split: Spawns multiple tokens with same `parallel_group_id` and unique `parallel_branch_key`
    - Merge node: Waits for all branches to arrive before proceeding (ALL mode)
  - **UI Updates:**
    - Properties panel includes parallel/merge configuration
    - Visual badges (`||` for split, `⋂` for merge) displayed on nodes
    - Validation prevents invalid configurations
  - **Safety:**
    - Linear graphs continue to work unchanged
    - No auto-parallelization (only explicit split/merge nodes)
    - Comprehensive error handling and validation
  - Results: [task17_results.md](tasks/task17_results.md)

- [task18.md](tasks/task18.md) - Conditional Edge Routing & Unified Condition Model
  - Status: ✅ **COMPLETED** (December 2025)
  - Establishes unified condition model for conditional edge routing
  - Enables complex routing decisions based on token properties, job properties, and QC results
  - Builds foundation for Task 19 (Conditional Edge UX)
  - **Schema Updates:**
    - Uses existing `edge_condition` JSON field in `routing_edge` table
    - Unified condition model: `{ type: "token_property"|"job_property"|"node_property"|"expression", property: "...", operator: "...", value: ... }`
  - **Backend Updates:**
    - `ConditionEvaluator` class for evaluating conditions at runtime
    - Supports operators: `==`, `!=`, `>`, `>=`, `<`, `<=`, `IN`, `NOT_IN`, `CONTAINS`
    - Expression type for default routes: `{ type: "expression", expression: "true" }`
  - **API Updates:**
    - `graph_validate`: Validates condition syntax and QC coverage
    - `graph_save`: Validates conditions before save
  - **Safety:**
    - All conditions validated before save
    - QC nodes require full coverage (pass, fail_minor, fail_major)
    - Backward compatible with legacy condition formats
  - Results: [task18_results.md](tasks/task18_results.md) (if exists)

- [task19.1.md](tasks/task19.1.md) - Unified UX for Conditional Routing
  - Status: ✅ **COMPLETED** (December 2025)
  - Transforms conditional edge UI into clean, dropdown-only UX (Apple-grade)
  - Eliminates confusion and prevents routing mistakes
  - **New Component:**
    - `ConditionalEdgeEditor` class for unified condition editing
    - Dropdown-only fields (no free text for logic-determining fields)
    - QC-aware presets for edges from QC nodes
    - Default route (Else) support
    - Advanced JSON view (hidden by default)
  - **UI Features:**
    - Field dropdown: QC Result → Status, Job → Priority, Token → Quantity, etc.
    - Operator auto-selection based on field type (enum/number/string)
    - Value input type switching (select/number/text)
    - Real-time validation feedback
  - **Integration:**
    - Integrated into `graph_designer.js` edge properties panel
    - `GraphSaver` serializes to unified condition model
    - Frontend validation before save (QC coverage, condition completeness)
  - **Backward Compatibility:**
    - Legacy condition formats automatically converted
    - Existing graphs continue to work
    - Old conditions loaded and displayed correctly
  - Results: [task19_1_results.md](tasks/task19_1_results.md)

- [task19.2.md](tasks/task19.2.md) - Multi-Condition Rules & AND/OR Grouping
  - Status: ✅ **COMPLETED** (December 2025)
  - Extends conditional edge editor to support multiple condition blocks with grouping
  - Enables complex routing rules with AND/OR logic
  - **New Features:**
    - Multi-group UI: Multiple groups (OR logic) with multiple conditions per group (AND logic)
    - Legacy compatibility: Automatic conversion from legacy formats
    - QC templates: Two preset templates for common QC routing scenarios
    - Comprehensive validation: Hard errors (block save) and soft warnings (allow with confirmation)
    - QC coverage validation: Ensures all QC statuses covered across outgoing edges
  - **UI Components:**
    - Add Group / Remove Group buttons
    - Add Condition / Remove Condition buttons per group
    - OR separator between groups
    - Group labels: "All of these must match (AND)"
  - **Validation:**
    - Hard errors: No groups, empty groups, missing fields/operators/values, QC coverage gaps
    - Soft warnings: Conflicting conditions (e.g., `qty >= 2 AND qty < 1`)
  - **Templates:**
    - Template A: Basic QC Split (Pass vs Fail)
    - Template B: Severity + Quantity (Fail Minor + Qty >= 1, or Fail Major)
  - **Backward Compatibility:**
    - Legacy edges automatically converted on load
    - Single condition format still supported
    - No breaking changes to existing graphs
  - Results: [task19_2_results.md](tasks/task19_2_results.md)

- [task19.7.md](tasks/task19.7.md) - GraphValidator Hardening & Unified Validation Framework
  - Status: ✅ **COMPLETED** (December 2025)
  - Fixes all known issues in SuperDAG validation flow
  - Consolidates scattered validation code into unified engine
  - Introduces deterministic, predictable validation for both frontend and backend
  - **New Component:**
    - `GraphValidationEngine` class for unified validation
    - Structured error/warning messages with codes, severity, category, suggestions
    - 11 validation modules covering all graph rules
  - **Integration:**
    - Frontend (`graph_designer.js`) calls via API
    - Backend (`dag_routing_api.php`) uses for save/publish validation
    - Replaces all scattered validation logic
  - **Validation Modules:**
    - Node Existence, Start/End, Edge Integrity, Parallel Structure, Merge Structure
    - QC Routing, Conditional Routing, Behavior-WorkCenter Compatibility
    - Machine Binding, Node Configuration, Semantic Layer (Task 19.10)
  - Results: [task19_7_results.md](tasks/task19_7_results.md)

- [task19.8.md](tasks/task19.8.md) - Graph AutoFix Engine (Safe Quick-Fix for DAG & QC)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates safe, deterministic AutoFix layer for common graph problems
  - Provides fix suggestions without modifying database
  - Frontend applies fixes via UI confirmation
  - **New Component:**
    - `GraphAutoFixEngine` class for suggesting fixes
    - Analyzes validation errors/warnings from GraphValidationEngine
    - Suggests fixes without modifying database
  - **Fix Patterns (v1 - Metadata Only):**
    - QC Pass → Next, Else → Rework
    - Mark explicit SINK nodes
    - Default ELSE route clarification (non-QC)
    - START/END node metadata normalization
  - **API:**
    - `graph_autofix` action (read-only, no DB writes)
  - **UI Integration:**
    - "Try Auto-Fix" button in validation dialog
    - Fix selection dialog with checkboxes
    - Apply selected fixes to graph
  - Results: [task19_8_results.md](tasks/task19_8_results.md)

- [task19.9.md](tasks/task19.9.md) - AutoFix Engine v2 (Structural Repairs)
  - Status: ✅ **COMPLETED** (December 2025)
  - Expands AutoFix from metadata-only fixes to structural graph repairs
  - Creates edges and nodes to complete graph structures
  - **New Fix Patterns (v2 - Structural):**
    - Auto-create missing QC edges for full coverage (Pass / Minor / Major)
    - Auto-create valid ELSE edges for non-QC conditional nodes
    - Auto-create END node if missing
    - Auto-connect dangling edges (safe patterns only)
    - Auto-create required rework edges for QC nodes
    - Auto-mark merge/split nodes when graph structure implies them
  - **Safety:**
    - Never alters intended behavior
    - Only "completes" or "repairs" structures that are strongly implied
    - All fixes are suggestions (user must confirm)
  - **API:**
    - `graph_autofix` supports `mode=structural` (v1 + v2 fixes)
  - **UI:**
    - Shows "Structural Changes" badge for fixes that create nodes/edges
    - Warning banner for structural fixes
    - Preview of newly created elements
  - Results: [task19_9_results.md](tasks/task19_9_results.md)

- [task19.10.md](tasks/task19.10.md) - AutoFix v3 (Semantic Repair Engine)
  - Status: ✅ **COMPLETED** (December 2025)
  - Introduces semantic-level inference, risk scoring, and safe graph repair
  - Respects user intent instead of blind structural repair
  - **New Component:**
    - `SemanticIntentEngine` class for analyzing graph patterns and inferring intent
    - Detects QC routing patterns (2-way vs 3-way vs pass-only)
    - Identifies parallel vs multi-exit patterns
    - Determines intentional vs unintentional unreachable nodes
    - Provides semantic tags for AutoFix to generate contextual fixes
  - **Risk Scoring:**
    - Each fix receives Risk Score (0-100)
    - 0-20 Low: Auto-apply safe
    - 21-50 Medium: Needs user confirmation
    - 51-80 High: Shown but highlighted, disabled by default
    - 81-100 Critical: Never auto-applied
  - **Semantic Fix Patterns:**
    - QC 2-way fix (Risk: 10)
    - QC 3-way fix (Risk: 40)
    - Parallel split fix (Risk: 30)
    - END consolidation (Risk: 60)
    - Unreachable connection (Risk: 65)
  - **Integration:**
    - Unified validator + AutoFix pipeline: validate → infer intent → generate fixes → rank → apply
    - GraphValidationEngine Module 11: Semantic Validation Layer
  - **UI:**
    - Risk score badge (0-100) with color coding
    - High/Critical risk fixes disabled by default
    - Warning banner for risky fixes
  - Results: [task19_10_results.md](tasks/task19_10_results.md)

- [task19.10.1.md](tasks/task19.10.1.md) - Implement SemanticIntentEngine.php (v1.0)
  - Status: ✅ **COMPLETED** (December 2025)
  - Enhances `SemanticIntentEngine.php` to match specifications
  - Implements all 13 intent types with complete evidence fields
  - **Intent Types Implemented:**
    - QC Routing (3): `qc.pass_only`, `qc.two_way`, `qc.three_way`
    - Parallel/Multi-exit (4): `operation.linear_only`, `operation.multi_exit`, `parallel.true_split`, `parallel.semantic_split`
    - Endpoint (4): `endpoint.missing`, `endpoint.true_end`, `endpoint.multi_end`, `endpoint.unintentional_multi`
    - Reachability (2): `unreachable.intentional_subflow`, `unreachable.unintentional`
  - **Features:**
    - Every intent includes `scope`, `confidence`, `risk_base`, `evidence`, `notes` fields
    - Evidence fields match `semantic_intent_rules.md` exactly
    - Risk base values match `autofix_risk_scoring.md` exactly
    - Pattern descriptions for debugging/UI
    - No database queries (pure analysis)
    - No graph modification (read-only)
  - Results: [task19_10_1_results.md](tasks/task19_10_1_results.md)

- [task19.10.2.md](tasks/task19.10.2.md) - Integrate SemanticIntentEngine → AutoFixEngine v3
  - Status: ✅ **COMPLETED** (December 2025)
  - Integrates SemanticIntentEngine with AutoFixEngine v3 for intent-aware fixes
  - Dynamic risk scoring based on intent evidence
  - Suggest-only vs Auto-Apply based on risk bands
  - Results: (See Task 19.10 results)

- [task19.11.md](tasks/task19.11.md) - Validator v3 (Semantic Validation Engine)
  - Status: ✅ **COMPLETED** (December 2025)
  - Upgrades validation from rule-based (v2) to semantic-aware (v3)
  - Detects "structurally correct but semantically wrong" patterns
  - Reduces false positives, provides contextual error levels
  - Results: (See Task 19.10 results)

- [task19.12.md](tasks/task19.12.md) - ApplyFixEngine (AutoFix v3 Execution Layer)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates ApplyFixEngine for atomic, safe, reversible fix application
  - Supports manual selection and batch "Fix All Safe Issues"
  - Validates graph after apply, prevents edge cases
  - Results: (See Task 19.10 results)

- [task19.3.md](tasks/task19.3.md) - SuperDAG QC & Routing Regression Map (Safety Test Pack)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates regression map and test pack for QC + Conditional Routing
  - Documentation and test cases only (no logic changes)
  - Results: (Documentation pending)

- [task19.4.md](tasks/task19.4.md) - Condition Engine Standardization for Non-QC Routing
  - Status: ✅ **COMPLETED** (December 2025)
  - Extends unified condition engine to all node types (not only QC)
  - Standardizes field registry for non-QC conditions
  - Updates UI to expose non-QC fields in ConditionalEdgeEditor
  - Results: (Documentation pending)

- [task19.5.md](tasks/task19.5.md) - Time Modeling & SLA Pre-Layer (SuperDAG Time Foundation)
  - Status: ✅ **COMPLETED** (December 2025)
  - Establishes time data foundation for Task 20 (ETA/SLA)
  - Standardizes Node Expected Time, SLA, Actual Duration representation
  - Ensures flow_token and token_event consistently record time-related values
  - Results: (Documentation pending)

- [task19.6.md](tasks/task19.6.md) - Conditional Edge Editor UX Rewrite (Bellavier Premium Edition)
  - Status: ✅ **COMPLETED** (December 2025)
  - Redesigns Conditional Edge Editor into clean, intuitive, Apple-grade UI
  - Auto-context behavior, unified operator selection, dynamic form layout
  - Template-based presets, advanced JSON toggle
  - Results: (Documentation pending)

- [task15.1.md](tasks/task15.1.md) - Add PRESS Work Center & PRESS Behaviors
  - Status: ✅ **COMPLETED** (December 2025)
  - Adds PRESS work center and PRESS behaviors as system defaults
  - Supports Hot Stamp, Foil Press, Emboss, Logo Press
  - Migration + seed for work_center and behavior mapping
  - Results: (Documentation pending)

- [task17.2.md](tasks/task17.2.md) - Parallel Split Validation & Legacy Control Node UI Cleanup
  - Status: ✅ **COMPLETED** (December 2025)
  - Adds validation for ambiguous graph patterns (multiple outgoing edges without parallel/conditional flag)
  - Hides/deprecates legacy node types (split, join, wait) from UI
  - Prevents creation of legacy control nodes incompatible with SuperDAG model
  - Results: (Documentation pending)

- [task18.1.md](tasks/task18.1.md) - Machine × Parallel Combined Execution Logic
  - Status: ✅ **COMPLETED** (December 2025)
  - Adds combined rules between Parallel Execution and Machine-Based Execution
  - Handles parallel branches with different machines, queue management, merge semantics
  - Results: (Documentation pending)

- [task18.2.md](tasks/task18.2.md) - Node UX Logic Simplification & Progressive Disclosure (Patch v2)
  - Status: ✅ **COMPLETED** (December 2025)
  - Reduces UX complexity using Topology-Aware Logic and Progressive Disclosure
  - Auto-hides parallel/merge options based on edge topology
  - Auto-resets flags when edges change, makes Node Type read-only label
  - Results: (Documentation pending)

- [task18.3.md](tasks/task18.3.md) - Start/Finish Node Rules & QC Panel (Form Schema / Policy JSON) Simplification
  - Status: ✅ **COMPLETED** (December 2025)
  - Enforces 1 Start + 1 Finish node per graph standard
  - Hides JSON complexity from general users (UI as source of truth)
  - Advanced/Developer mode for JSON viewing
  - Results: (Documentation pending)

- [task18.4.md](tasks/task18.4.md) - SuperDAG MAP (Read-Only Logic Discovery)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates comprehensive SuperDAG logic map (read-only analysis)
  - Documents actual execution model, identifies gaps and legacy logic
  - Creates 4 documentation files for future refactoring
  - Results: (Documentation pending)

- [task23.6.md](tasks/task23.6.md) - MO Update Integration & ETA Cache Consistency
  - Status: ✅ **COMPLETED** (November 2025)
  - Integrates MO update actions with ETA cache invalidation
  - Ensures ETA/Simulation/Health stack reacts correctly to MO updates
  - Results: (See Task 23.6.1)

### Task 20 Series (ETA / Time Engine)

- [task20.md](tasks/task20.md) - ETA / Time Engine (Phase 1: Read-Only ETA & SLA Warnings)
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates read-only ETA/SLA engine for node-level and block-level time estimation
  - Exposes API/Service methods without DB writes (pure compute)
  - Adds UI indicators for ETA/SLA status in Graph Designer and Runtime view
  - Results: [task20_results.md](tasks/task20_results.md)

- [task20.2.md](tasks/task20.2.md) - Official Timezone Normalization Layer
  - Status: ✅ **COMPLETED** (November 2025)
  - Establishes single, canonical, system-wide timezone normalization layer
  - Replaces scattered timezone handling with unified TimeHelper mechanism
  - Ensures consistency, determinism, and future-proofing for multi-region deployments
  - Results: [task20_2_results.md](tasks/task20_2_results.md)

- [task20.2.1.md](tasks/task20.2.1.md) - Timezone Normalization: PHP Layer
  - Status: ✅ **COMPLETED** (November 2025)
  - Implements TimeHelper class for PHP timezone normalization
  - Results: [task20_2_1_results.md](tasks/task20_2_1_results.md)

- [task20.2.2.md](tasks/task20.2.2.md) - Timezone Normalization: Integration Pass
  - Status: ✅ **COMPLETED** (November 2025)
  - Integrates TimeHelper into TokenLifecycleService and related services
  - Results: [task20_2_2_results.md](tasks/task20_2_2_results.md)

- [task20.2.3.md](tasks/task20.2.3.md) - Timezone Normalization: Frontend Layer
  - Status: ✅ **COMPLETED** (November 2025)
  - Implements frontend timezone normalization for JavaScript
  - Results: [task20_2_3_results.md](tasks/task20_2_3_results.md)

- [task20.3.md](tasks/task20.3.md) - Worker App: Token Execution Engine
  - Status: ✅ **COMPLETED** (November 2025)
  - Token execution core with start/pause/resume/complete logic
  - Queue consumption layer with station assignment
  - Execution stability with auto-retry sync and conflict resolution
  - Results: [task20_3_results.md](tasks/task20_3_results.md)

- [task20.4.md](tasks/task20.4.md) - SLA Definition Panel UI
  - Status: ⏳ **PLANNED**
  - SLA per node configuration
  - SLA template groups
  - UI for editing SLA parameters

### Task 21 Series (Node Behavior Engine & Canonical Events)

- [task21.1.md](tasks/task21.1.md) - Node Behavior Engine (Core Spec & Minimal Skeleton)
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates behavior model spec and minimal skeleton
  - Establishes behavior_code concept and plug-in interface
  - Results: [task21_1_results.md](tasks/task21_1_results.md)

- [task21.2.md](tasks/task21.2.md) - Node Behavior Execution (Canonical Events Only)
  - Status: ✅ **COMPLETED** (November 2025)
  - Implements behavior execution with canonical events generation
  - Results: [task21_2_results.md](tasks/task21_2_results.md)

- [task21.3.md](tasks/task21.3.md) - Persist Canonical Events to token_event
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates TokenEventService for persisting canonical events
  - Results: [task21_3_results.md](tasks/task21_3_results.md)

- [task21.4.md](tasks/task21.4.md) - Internal Behavior Registry + Feature Flag Migration
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates internal behavior registry for node_mode/execution_mode mapping
  - Migrates NODE_BEHAVIOR_EXPERIMENTAL to official feature flag
  - Results: [task21_4_results.md](tasks/task21_4_results.md)

- [task21.5.md](tasks/task21.5.md) - TimeEventReader & Timeline Sync
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates TimeEventReader for reading canonical timeline
  - Syncs time data to flow_token (start_at, completed_at, actual_duration_ms)
  - Results: [task21_5_results.md](tasks/task21_5_results.md)

- [task21.6.md](tasks/task21.6.md) - Dev Timeline Debugger Tool
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates dev_token_timeline.php tool for debugging canonical timeline
  - Results: [task21_6_results.md](tasks/task21_6_results.md)

- [task21.7.md](tasks/task21.7.md) - Canonical Event Integrity Validator
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates CanonicalEventIntegrityValidator with 10+ validation rules
  - Results: [task21_7_results.md](tasks/task21_7_results.md)

- [task21.8.md](tasks/task21.8.md) - Bulk Integrity Validator + Session Overlap Rule
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates BulkIntegrityValidator for batch validation
  - Adds session overlap detection rule
  - Results: [task21_8_results.md](tasks/task21_8_results.md)

### Task 22 Series (Canonical Self-Healing & Timeline Engine)

- [task22.1.md](tasks/task22.1.md) - Local Repair Engine v1
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates LocalRepairEngine for token-level repair under controlled rules
  - Handles missing events, session pairs, timeline issues
  - Append-only, reversible, with audit trail
  - Results: [task22_1_results.md](tasks/task22_1_results.md)

- [task22.2.md](tasks/task22.2.md) - Repair Event Model & Audit Trail
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates token_repair_log table for repair audit trail
  - Results: [task22_2_results.md](tasks/task22_2_results.md)

- [task22.3.md](tasks/task22.3.md) - Timeline Reconstruction v1
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates TimelineReconstructionEngine for L2/L3 timeline problems
  - Reconstructs timeline from canonical events with append-only approach
  - Results: [task22_3_results.md](tasks/task22_3_results.md)

- [task22.3.1.md](tasks/task22.3.1.md) - Timeline Reconstruction: Sequence Repair
  - Status: ✅ **COMPLETED** (November 2025)
  - Implements sequence repair logic for invalid event sequences
  - Results: [task22_3_1_results.md](tasks/task22_3_1_results.md)

- [task22.3.2.md](tasks/task22.3.2.md) - Timeline Reconstruction: Session Overlap Repair
  - Status: ✅ **COMPLETED** (November 2025)
  - Implements session overlap detection and repair
  - Results: [task22_3_2_results.md](tasks/task22_3_2_results.md)

- [task22.3.3.md](tasks/task22.3.3.md) - Timeline Reconstruction: Zero Duration Repair
  - Status: ✅ **COMPLETED** (November 2025)
  - Implements zero/negative duration repair
  - Results: [task22_3_3_results.md](tasks/task22_3_3_results.md)

- [task22.3.4.md](tasks/task22.3.4.md) - Timeline Reconstruction: Event Time Disorder Repair
  - Status: ✅ **COMPLETED** (November 2025)
  - Implements event time disorder detection and repair
  - Results: [task22_3_4_results.md](tasks/task22_3_4_results.md)

- [task22.3.5.md](tasks/task22.3.5.md) - Timeline Reconstruction: Integration & Testing
  - Status: ✅ **COMPLETED** (November 2025)
  - Integrates all reconstruction modules
  - Comprehensive testing and validation
  - Results: [task22_3_5_results.md](tasks/task22_3_5_results.md)

- [task22.3.6.md](tasks/task22.3.6.md) - Repair Orchestrator Layer
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates RepairOrchestrator for coordinating repair operations
  - Results: [task22_3_6_results.md](tasks/task22_3_6_results.md)

### Task 23 Series (MO Planning & ETA Intelligence)

- [task23.1.md](tasks/task23.1.md) - MO Creation Extension Layer
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates MOCreateAssistService for smart MO creation assistance
  - Routing suggestion, validation, time estimation preview
  - Non-intrusive layer working before legacy mo.php create()
  - Results: [task23_1_results.md](tasks/task23_1_results.md)

- [task23.2.md](tasks/task23.2.md) - MO Create Assist Hardening & Canonical-Aware Validation
  - Status: ✅ **COMPLETED** (November 2025)
  - Enhances MOCreateAssistService with canonical timeline support
  - Product-aware historic duration, enhanced graph validation
  - Cycle detection, reachability analysis, node behavior compatibility checks
  - Hardens MO Assist API with GET-only enforcement, global error handling
  - Results: [task23_2_results.md](tasks/task23_2_results.md)

- [task23.3.md](tasks/task23.3.md) - Workload Planning & Load Simulation Engine (v1)
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates MOLoadSimulationService for workload planning and load simulation
  - Station load, worker load, bottleneck prediction, node-level execution projection
  - Routing-based WIP distribution
  - Uses canonical timeline first, then historic duration, then fallback
  - API endpoint `/mo/load-simulation` and CLI tool `cron/mo_load_sim.php`
  - Results: [task23_3_results.md](tasks/task23_3_results.md)

- [task23.4.md](tasks/task23.4.md) - MO ETA Engine (Advanced ETA Model v1)
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates MOLoadEtaService for computing MO ETA (best, normal, worst)
  - Stage-level ETA, node-level ETA, queue modeling, delay propagation
  - API endpoint `/mo/eta` and CLI tool `cron/mo_eta.php`
  - Results: [task23_4_results.md](tasks/task23_4_results.md)

- [task23.4.1.md](tasks/task23.4.1.md) - ETA Integration Patch & Simulation Refinement
  - Status: ✅ **COMPLETED** (November 2025)
  - Major patch to align MOLoadSimulationService and MOLoadEtaService with Advanced ETA Model B
  - Removes MOCreateAssistService dependency, fixes capacity calculations
  - Adds node-level ETA fields, sequential queue model, station availability rollover
  - Adds stage-level ETA envelope with risk factor
  - Results: [task23_4_1_results.md](tasks/task23_4_1_results.md)

- [task23.4.2.md](tasks/task23.4.2.md) - ETA Audit Tool (Audit + Debugging + Cross-Check Layer)
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates MOEtaAuditService for cross-validating ETA calculations
  - Standalone dev tool `tools/eta_audit.php` with HTML UI and JSON export
  - Identifies ETA errors and red flags
  - Results: [task23_4_2_results.md](tasks/task23_4_2_results.md)

- [task23.4.3.md](tasks/task23.4.3.md) - ETA Consistency Corrections + Canonical-Aware ETA Comparison
  - Status: ✅ **COMPLETED** (November 2025)
  - Fixes queue model normalization, canonical-aware ETA comparison
  - Corrects node workload comparison, adds canonical stats cache
  - Results: [task23_4_3_results.md](tasks/task23_4_3_results.md)

- [task23.4.4.md](tasks/task23.4.4.md) - ETA Result Caching Layer
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates MOEtaCacheService and mo_eta_cache table
  - Signature-based and TTL-based invalidation
  - Results: [task23_4_4_results.md](tasks/task23_4_4_results.md)

- [task23.4.5.md](tasks/task23.4.5.md) - ETA Cache Hardening & Engine Version Binding
  - Status: ✅ **COMPLETED** (November 2025)
  - Hardens MOEtaCacheService with routing_version, routing_hash, engine_version in signature
  - Adds defensive validation and error handling
  - Results: [task23_4_5_results.md](tasks/task23_4_5_results.md)

- [task23.4.6.md](tasks/task23.4.6.md) - ETA Self-Validation Routine + Monitoring Dashboard
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates MOEtaHealthService for ETA health validation
  - Creates mo_eta_health_log table, cron script, and monitoring dashboard
  - Results: [task23_4_6_results.md](tasks/task23_4_6_results.md)

- [task23.5.md](tasks/task23.5.md) - Integrate ETA Engine with MO Lifecycle
  - Status: ✅ **COMPLETED** (November 2025)
  - Wires MOEtaCacheService into MO creation and update lifecycle
  - Wires MOEtaHealthService into token completion lifecycle (best-effort, non-blocking)
  - Makes ETA lifecycle aware of MO status transitions
  - Creates dev tools index page (tools/index_dev.php)
  - Results: [task23_5_results.md](tasks/task23_5_results.md)

- [task23.6.md](tasks/task23.6.md) - MO Update Integration & ETA Cache Consistency
  - Status: ✅ **COMPLETED** (November 2025)
  - Integrates MO update actions with ETA cache invalidation
  - Ensures ETA/Simulation/Health stack reacts correctly to MO updates
  - Results: (See Task 23.6.1)

- [task23.6.1.md](tasks/task23.6.1.md) - MO Update Integration & ETA Cache Consistency
  - Status: ✅ **COMPLETED** (November 2025)
  - Integrates MO update actions with ETA cache invalidation
  - Ensures ETA/Simulation/Health stack reacts correctly to MO updates
  - Results: [task23_6_1_results.md](tasks/results/task23_6_1_results.md)

- [task23.6.2.md](tasks/task23.6.2.md) - MO UI Consolidation & Flow Cleanup
  - Status: ✅ **COMPLETED** (November 2025)
  - Transforms MO page into planning-only interface (removes execution controls)
  - Disables execution actions (start/stop/complete/resume) and redirects to Job Tickets UI
  - Consolidates restore functionality (reuse → restore)
  - Removes UOM field from UI (backend-driven auto-resolution)
  - Implements dynamic action buttons based on MO status
  - Results: [task23_6_2_results.md](tasks/results/task23_6_2_results.md)

- [task23.6.3.md](tasks/task23.6.3.md) - Finalize MO Page Integration & Close Phase 23
  - Status: ✅ **COMPLETED** (November 2025)
  - Finalizes MO page integration with complete UI polish
  - Adds "Open Job Ticket" button with proper state handling (active/disabled)
  - Adds Routing Info block in Create/Edit modals (read-only, informational)
  - Removes Production Template selection (replaced with Routing Info)
  - Verifies ETA/Simulation Lifecycle Hooks (Plan, Update, Cancel, Complete, Restore)
  - Maintains Job Ticket creation timing (no changes to start_production flow)
  - Cleans up legacy code (removes handleGetTemplatesForProduct)
  - Results: [task23_6_3_results.md](tasks/results/task23_6_3_results.md)

### Task 24 Series (Job Ticket UI & Flow Cleanup)

- [task24.1.md](tasks/task24.1.md) - Job Ticket UI & Flow Cleanup (Job Ticket v2 – UX Pass 1)
  - Status: ✅ **COMPLETED** (December 2025)
  - Clarifies Job Ticket UI & Flow (ticket status, task status, WIP logs distinction)
  - Fixes button/action availability (Start/Pause/Resume/Complete only when valid)
  - Improves offcanvas layout & readability
  - Updates wording to be less confusing (removes Hatthasilpa-only references)
  - Results: (Documentation pending)

- [task24.2.md](tasks/task24.2.md) - Job Ticket Progress Engine v1 (DAG / Token-Based Progress)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates unified, reliable Progress Engine for Job Tickets
  - Uses tokens/canonical events when available (DAG mode)
  - Falls back to task/log based progress in Linear mode
  - Exposes progress in clean API for UI consumption
  - Results: (Documentation pending)

- [task24.3.md](tasks/task24.3.md) - Job Ticket Progress: Accuracy, Consistency & UI Fallback
  - Status: ✅ **COMPLETED** (December 2025)
  - Improves progress accuracy and consistency across DAG and Linear modes
  - Adds error model with clear error codes/messages
  - Implements UI fallback behavior when progress cannot be calculated
  - Results: (Documentation pending)

- [task24.4.md](tasks/task24.4.md) - Job Ticket Lifecycle v2 (Start / Pause / Resume / Complete / Cancel / Restore)
  - Status: ✅ **COMPLETED** (December 2025)
  - Upgrades Job Ticket lifecycle with complete state machine
  - Integrates with TokenLifecycleService safely
  - Adds audit logging for all transitions
  - Results: (Documentation pending)

- [task24.4.1.md](tasks/task24.4.1.md) - Job Ticket Lifecycle v2 (Additional refinements)
  - Status: ✅ **COMPLETED** (December 2025)
  - Additional refinements to Job Ticket lifecycle
  - Results: (Documentation pending)

- [task24.5.md](tasks/task24.5.md) - Job Ticket State Machine Validation & Error Handling
  - Status: ✅ **COMPLETED** (December 2025)
  - Enforces strict state transitions, prevents invalid operations
  - Adds explicit error codes for forbidden transitions
  - Guarantees consistent Start/Pause/Resume/Complete behavior
  - Results: (Documentation pending)

- [task24.6.md](tasks/task24.6.md) - Job Ticket Assigned Operator Support
  - Status: ✅ **COMPLETED** (December 2025)
  - Adds assigned_operator_id field support in Job Ticket API
  - Reads/writes assigned_operator_id in list/get/create/update actions
  - Results: (Documentation pending)

- [task24.6.1.md](tasks/task24.6.1.md) - Job Ticket Assigned Operator (Additional refinements)
  - Status: ✅ **COMPLETED** (December 2025)
  - Additional refinements to assigned operator support
  - Results: (Documentation pending)

- [task24.6.2.md](tasks/task24.6.2.md) - Job Ticket Assigned Operator (Additional refinements)
  - Status: ✅ **COMPLETED** (December 2025)
  - Additional refinements to assigned operator support
  - Results: (Documentation pending)

- [task24.6.3.md](tasks/task24.6.3.md) - Job Ticket Assigned Operator (Additional refinements)
  - Status: ✅ **COMPLETED** (December 2025)
  - Additional refinements to assigned operator support
  - Results: (Documentation pending)

- [task24.6.4.md](tasks/task24.6.4.md) - Job Ticket Assigned Operator (Additional refinements)
  - Status: ✅ **COMPLETED** (December 2025)
  - Additional refinements to assigned operator support
  - Results: (Documentation pending)

- [task24.6.5.md](tasks/task24.6.5.md) - Job Ticket Assigned Operator (Additional refinements)
  - Status: ✅ **COMPLETED** (December 2025)
  - Additional refinements to assigned operator support
  - Results: (Documentation pending)

- [task24.7.md](tasks/task24.7.md) - Hatthasilpa Jobs: Planned → Token Generation Fix, Job Lifecycle Refinement, and Cross-Sync With Job Ticket
  - Status: ✅ **COMPLETED** (December 2025)
  - Stabilizes Hatthasilpa Jobs lifecycle (Create = Planned, Start = Generate Tokens)
  - Fixes cancel/restore state transitions
  - Syncs to Job Ticket (offcanvas view only, no actions)
  - Results: (Documentation pending)

- [task24.8.md](tasks/task24.8.md) - Job Ticket Printable Work Card (A4)
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates A4 Work Card page for Job Ticket printing
  - Adds Print Work Card button in Job Ticket offcanvas
  - Clean, print-friendly layout with CSS print media
  - Results: (Documentation pending)

- [task24.9.md](tasks/task24.9.md) - Work Card Print Engine Refactor (job_ticket_print)
  - Status: ✅ **COMPLETED** (December 2025)
  - Refactors Work Card print page for cleaner code structure
  - Separates Data/Service/View layers clearly
  - Removes hack superglobals/require API within view
  - Results: (Documentation pending)

### Task 25 Series (Production Statistics Layer)

- [task25.1.md](tasks/task25.1.md) - Product Output Analytics (Classic Line)
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates `production_output_daily` table for daily aggregated production statistics
  - Implements `ClassicProductionStatsService` for recording and aggregating production stats
  - Adds hooks in `job_ticket.php` for lifecycle tracking (start, complete, cancel, restore)
  - Creates `product_stats_api.php` with endpoints: `daily-output`, `product-capacity`, `lead-time-history`
  - Classic Line only (production_type = 'oem' / 'classic')
  - Results: (Documentation pending)

- [task25.2.md](tasks/task25.2.md) - Product Classic Output Dashboard (Classic Production Overview)
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates Classic Production Overview tab in Product Graph Binding Modal
  - Implements `classic_dashboard` API endpoint with summary statistics
  - Implements `classic_dashboard_csv` API endpoint for data export
  - Creates interactive Chart.js dashboard with range filters (7/14/30/60/90 days)
  - Displays summary cards (Total Output, Avg per Day, Best Day, Worst Day)
  - Patches ClassicProductionStatsService for improved accuracy and idempotency
  - Results: [task25_2_results.md](tasks/results/task25_2_results.md)

- [task25.3.md](tasks/task25.3.md) - Product Module: Phase 1 (Rebuild Foundation)
  - Status: ✅ **COMPLETED** (November 2025)
  - Creates ProductMetadataResolver service for product metadata resolution
  - Creates product_api.php (central API endpoint for Product Page)
  - Refactors Product Graph Binding Modal (removes template version logic)
  - Removes hybrid mode, version pinning, legacy template/version UI
  - Renames labels: Atelier → Hatthasilpa, OEM → Classic
  - Establishes foundation: 1 Product = 1 Production Line (classic/hatthasilpa)
  - Results: [task25_3_results.md](tasks/results/task25_3_results.md)

- [task25.4.md](tasks/task25.4.md) - Deprecate Classic DAG / Cleanup Graph Binding UI & Backend
  - Status: ✅ **COMPLETED** (November 2025)
  - Removes DAG routing bindings from Classic line products
  - Adds supports_graph flag to metadata
  - Hides Graph Binding UI for Classic products, shows Classic Dashboard instead
  - Adds backend guards to prevent Classic products from binding graphs
  - Creates migration to deactivate existing Classic product bindings
  - Results: [task25_4_results.md](tasks/results/task25_4_results.md)

- [task25.5.md](tasks/task25.5.md) - Product Module Hardening & Full Refactor Integration
  - Status: ✅ **COMPLETED** (December 2025)
  - Deprecates legacy endpoints (bind_graph, update_version_pin) in source/products.php
  - Adds duplicate-as-draft functionality (API + UI)
  - Removes duplicate functions and fixes global variable usage
  - Creates migration for legacy product data cleanup (is_draft column, production_lines updates)
  - Updates UI wording (OEM → Classic, Atelier → Hatthasilpa)
  - Prepares foundation for modern error handling
  - Results: [task25_5_results.md](tasks/results/task25_5_results.md)

- [task25.6.md](tasks/task25.6.md) - Product API Enterprise Refactor (product_api.php)
  - Status: ✅ **COMPLETED** (December 2025)
  - Transforms product_api.php into Enterprise-grade API aligned with api_template.php
  - Implements bootstrap & skeleton (output buffer, correlation ID, AI trace, maintenance mode, rate limiting)
  - Refactors SQL queries (replaces SELECT * with explicit columns, uses DatabaseTransaction helper)
  - Adds i18n support (31 translate() calls for all user-facing messages)
  - Adds ETag/cache support for read-only endpoints (get_metadata, get_classic_dashboard)
  - Adds idempotency guard for duplicate action
  - Standardizes logging format ([CID:...][File][User][Action])
  - Removes forbidden patterns (no header('Location'), no raw exit;)
  - Maintains 100% backward compatibility (all actions and response formats unchanged)
  - Results: [task25_6_results.md](tasks/results/task25_6_results.md)

- [task25.7.md](tasks/task25.7.md) - Product Line Model Consolidation (Classic vs Hatthasilpa)
  - Status: ✅ **COMPLETED** (December 2025)
  - Consolidates Product module to use single production line per product model
  - Removes multi-select production lines, normalizes backend model
  - Migration normalizes existing data (hatthasilpa → hatthasilpa, else → classic)
  - ProductMetadataResolver uses single production_line column
  - product_api.php guards prevent Classic products from binding routing
  - UI uses radio buttons (single choice) instead of checkboxes (multi-select)
  - Tab visibility based on production_line (Hatthasilpa = Graph Binding, Classic = Classic Dashboard)
  - Results: [task25_7_results.md](tasks/results/task25_7_results.md)

### Task 26 Series (Product Module Consolidation)

- [task26.1.md](tasks/task26.1.md) - Product Core Cleanup & Consolidation
  - Status: ✅ **COMPLETED** (December 2025)
  - จัดระเบียบใหม่ (Consolidation) ของระบบสินค้า (Product Module) ให้พร้อมใช้งานจริง
  - เพิ่ม description field ใน product table และ UI
  - Enhanced validation rules (SKU uniqueness, required fields, production line change protection)
  - Consolidated assets management (Images + Patterns with tabs)
  - Removed legacy pattern versioning model completely
  - Enhanced product duplication (assets + patterns + routing bindings)
  - Expanded Product Metadata API (get_full, duplicate, update_core_fields, upload_asset)
  - UI refactor (modal reset, tabs organization, description field)
  - Fixed pattern.production_line enum from ('hatthasilpa','oem') to ('hatthasilpa','classic')
  - Results: [task26_1_results.md](tasks/results/task26_1_results.md)

- [task26.2.md](tasks/task26.2.md) - Product → MO Integration
  - Status: ✅ **COMPLETED** (December 2025)
  - Connects refactored Product Module to MO Module
  - Ensures MO creation uses product metadata, enforces Classic vs Hatthasilpa behavior
  - Hides draft products, displays product summary, supports routing suggestions
  - Results: [task26_2_results.md](tasks/results/task26_2_results.md)

- [task26.3.md](tasks/task26.3.md) - Publish Lifecycle + Metadata Panel Revamp
  - Status: ✅ **COMPLETED** (December 2025)
  - Implements Draft/Published status using existing is_draft column
  - is_draft = 1 means Draft, is_draft = 0 means Published
  - is_published is a computed field (not a new column)
  - Adds Publish/Unpublish endpoints and UI buttons
  - Results: (integrated into Task 26.4)

- [task26.4.md](tasks/task26.4.md) - Product List Cleanup & Draft/Publish UX Redesign
  - Status: ✅ **COMPLETED** (December 2025)
  - Removes Status column from product list (uses badge near SKU only)
  - Removes Unpublish/Mark as Draft actions (one-way publish flow)
  - Moves Publish button to Edit Modal
  - Published products cannot revert to Draft (use Duplicate to create new version)
  - Results: (integrated into Task 26.5)

- [task26.5.md](tasks/task26.5.md) - Product State Guarding & Cross-Module Enforcement
  - Status: ✅ **COMPLETED** (December 2025)
  - Creates validateProductState() helper function for centralized validation
  - Enforces is_draft=0 and is_active=1 in MO, Hatthasilpa Jobs, Job Ticket modules
  - Updates ProductMetadataResolver to include state object (is_draft, is_active, is_usable)
  - Adds Inactive badge to product list UI
  - UI filtering shows only Published & Active products in dropdowns
  - Results: [task26_5_results.md](tasks/results/task26_5_results.md)

- task26.6.md - Product Delete + Hard Dependency Validation (Planned)

- [task26.7.md](tasks/task26.7.md) - Product Dual Delete Mode (Hard Delete + Archive)
  - Status: ✅ **COMPLETED** (December 2025)
  - Implements dual delete mode: Hard Delete (for unused products) and Archive/Deactivate (for used products)
  - Creates handleDeleteHard endpoint with dependency validation using ProductDependencyScanner
  - Creates handleDeactivate and handleActivate endpoints
  - UI uses toggle switch for activate/deactivate, dropdown for other actions
  - Hard Delete requires zero operational dependencies (MO, Job Ticket, Hatthasilpa Jobs, Inventory)
  - Results: [task26_7_results.md](tasks/results/task26_7_results.md)

- [task26.8.md](tasks/task26.8.md) - Product Module Enterprise Standards Compliance
  - Status: ✅ **COMPLETED** (December 2025)
  - Adds finally blocks for AI-Trace in product APIs (product_api.php, product_stats_api.php)
  - Enhances AI Trace metadata for comprehensive observability
  - Ensures 100% compliance with SYSTEM_WIRING_GUIDE.md standards
  - Results: [task26_8_results.md](tasks/results/task26_8_results.md)

- [task26.9.md](tasks/task26.9.md) - Product Dependency Logic Refinement
  - Status: ✅ **COMPLETED** (December 2025)
  - Refines ProductDependencyScanner to differentiate between operational and config-only dependencies
  - Updates handleDeleteHard to perform cleanup for config-only dependencies
  - Operational usage (MO, Job Ticket, Hatthasilpa Jobs, Inventory) blocks hard delete
  - Config-only usage (graph bindings, assets) does not block hard delete but is cleaned up
  - Results: [task26_9_results.md](tasks/results/task26_9_results.md) (if exists)

- [task26.10.md](tasks/task26.10.md) - Simplify Product Documents Modal
  - Status: ✅ **COMPLETED** (December 2025)
  - Removes all Pattern UI elements from Product Assets Modal
  - Redesigns modal to be "Assets Only" (Images grid)
  - Stops duplicating pattern records when duplicating products
  - Adds pattern cleanup in hard delete
  - Adds Active Status column as first column with toggle switch
  - Replaces all confirm() with SweetAlert dialogs
  - Adds image fallback handler (no-image.png)
  - Results: [task26_10_results.md](tasks/results/task26_10_results.md)

### Future Tasks (Placeholders)

- task27.md - (Planned)
- [task28_GRAPH_VERSIONING_IMPLEMENTATION.md](tasks/task28_GRAPH_VERSIONING_IMPLEMENTATION.md) - Graph Versioning & Immutability Implementation (📋 PLANNED)
- task29.md - (Planned)
- task30.md - (Planned)
- task31.md - (Planned)
- task32.md - (Planned)
- task33.md - (Planned)
- task34.md - (Planned)
- task35.md - (Planned)
- task36.md - (Planned)
- task37.md - (Planned)
- task38.md - (Planned)
- task39.md - (Planned)
- task40.md - (Planned)

---

## Legacy Notice

⚠️ **Important:** The old `docs/dag/` folder is deprecated and frozen.

- All new designs must reference `docs/super_dag/*` exclusively
- Old `docs/dag/` folder is preserved for historical reference only
- Do not create new files in `docs/dag/`
- Update all new documentation to link to `docs/super_dag/*`


- [task19.24.5.md](tasks/task19.24.5.md) through [task19.24.17.md](tasks/task19.24.17.md) - SuperDAG Lean-Up Additional Passes
  - Status: ✅ **COMPLETED** (November 2025)
  - Additional Lean-Up passes for validation engine optimization (13 subtasks)
  - Results: See individual results files

**Last Updated:** December 1, 2025 (Added Task 26.10 and results)
