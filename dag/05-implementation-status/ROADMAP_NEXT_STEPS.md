# Roadmap Next Steps (Dec 2025)

> **Reference:** See master plan in `docs/dag/02-implementation-status/DAG_IMPLEMENTATION_ROADMAP.md` (≈9,000 lines).  
> This file summarizes the immediate sub-roadmap so we can work safely without scrolling through the full document.

---

## 0.x — Checkpoint Policy (Before Every Phase)

Before implementing any phase:
- Create Cursor checkpoint named `BEFORE_PHASE_<NAME>`.
- After patching + tests pass, create checkpoint `AFTER_PHASE_<NAME>`.
- If any required test suite fails → revert to `BEFORE_PHASE_<NAME>` immediately.

## 0.y — Required Test Suites Before Starting Any Phase

Run and ensure all of the following pass before kicking off a new phase:
1. `tests/Integration/SubgraphGovernanceTest.php`
2. `tests/Integration/GraphDraftLayerTest.php` (once introduced)
3. Validation core suites:
   - `tests/Integration/DAGValidationServiceTest.php`
   - `tests/Integration/RoutingGraphAPITest.php`

**Rules:**
- If any suite fails, do **not** start the next phase.
- Fix the failure immediately or revert to `BEFORE_PHASE_<NAME>`.

---

## Safety Rules for AI (Composer1 / GPT-5.1 Codex)

1. **Restricted files** – Do NOT modify these unless a human-reviewed patch plan exists first:
   - `source/dag_routing_api.php`
   - `source/dag_routing_service.php`
   - `source/dag_token_api.php`
   - `source/hatsathilpa_assignment_api.php`
   - `tests/Integration/SubgraphGovernanceTest.php`

2. **No refactors** – Never refactor entire files or large functions.

3. **No global find/replace** – Avoid broad replacements or regex patches; edit only targeted lines.

4. **Patch workflow** – Every change must follow:
   - Step A: Analyze only
   - Step B: Create patch plan (with explicit line ranges)
   - Step C: Apply diff touching only the planned lines

5. **Tests are the authority** – Do not change tests just to make them pass.

---

## Step 1 — Phase 7.X Backend Core ✅ **COMPLETE** | UI/UX Polish → Phase 7.Y

**Status Update (December 2025):**
- ✅ **Backend Core:** COMPLETE
  - Migration `routing_graph_draft` table created and deployed
  - API endpoints: `graph_save_draft`, `graph_discard_draft`, `graph_publish` (modified)
  - `graph_get` returns draft info when available
  - Integration tests: `GraphDraftLayerTest.php` (5 tests passing)
  - Regression tests: `SubgraphGovernanceTest.php` (11/11 green, no regression)
  - Cleanup strategy: FK-safe deletion order verified
- ⏸ **UI/UX Polish:** Deferred to Phase 7.Y
  - Draft state indicator (badge + banner) - pending
  - Publish dialog with validation summary - pending
  - Autosave UX (saving/saved/failed states) - pending
  - Disable legacy `graph_save` when draft exists - pending
  - Undo history (stretch goal) - pending

### 1.5 Phase Lock Condition (Backend Core)
Phase 7.X backend core is considered **complete** when:
- ✅ `GraphDraftLayerTest` passes 100% (5/5 tests)
- ✅ `SubgraphGovernanceTest` remains 11/11 green (no regression)
- ✅ Migrations applied to all tenants (DEFAULT, maison_atelier, test)
- ✅ Cleanup strategy prevents FK constraint errors
- ✅ Roadmap Phase 7.X backend checklist fully ticked

**Current Status:** ✅ **All conditions met** (December 2025)

### 1.1 Integration Tests ✅ **COMPLETE**
✅ `tests/Integration/GraphDraftLayerTest.php` created and passing:
- ✅ `testSaveDraftCreatesOrUpdatesDraftRecord()`
- ✅ `testDiscardDraftMarksStatusDiscardedAndDoesNotTouchLiveGraph()`
- ✅ `testPublishWithValidDraftCreatesNewGraphVersionAndUpdatesRoutingGraph()`
- ✅ `testPublishWithInvalidGraphFailsAndKeepsDraftIntact()`
- ✅ `testPublishWithoutDraftBehavesLikeLegacyGraphSave()`

**Verification:**
- ✅ `SubgraphGovernanceTest.php` remains 11/11 green (no regression)
- ✅ No modifications to core validation logic
- ✅ FK-safe cleanup strategy implemented

### 1.2 Mandatory Audits ⏸ **PENDING**
Audits defined in master roadmap (to be completed):
1. NodeType Policy & UI Audit  
2. Flow Status & Transition Audit  
3. Hatthasilpa Assignment Integration Audit  

**Note:** Audits can proceed independently of UI/UX polish (Phase 7.Y).

### 1.3 Documentation Updates ✅ **COMPLETE**
- ✅ `PHASE_7_X_AUDIT_REPORT.md` updated with "Backend Completion Summary"
- ✅ `DAG_IMPLEMENTATION_ROADMAP.md` Phase 7.X status updated
- ✅ Validation behavior documented (draft mode = warnings, publish mode = strict errors)
- ✅ UI/UX items moved to Phase 7.Y section

### 1.4 Phase 7.Y — Graph Designer Draft UX Polish (NEW)

**Objective:** Polish Graph Designer UI/UX for draft workflow

**Checklist:**
- [ ] Draft state indicator on Graph Designer (badge + banner)
- [ ] Publish dialog with validation summary (errors/warnings) and confirmation step
- [ ] Autosave UX: show saving/saved/failed states and handle reload
- [ ] Disable legacy direct `graph_save` when draft exists (UI guard)
- [ ] Basic undo history for draft editing (stretch goal)
- [ ] Regression checklist for Graph Designer (manual + automated when available)

**Priority:** 🟡 **MEDIUM** (can proceed after Phase 2B.6 or 5.3)

---

## Step 2 — Phase 2B.6 Mobile-Optimized Work Queue UX

Reasons to prioritize next:
- Independent from core DAG validation.
- Directly improves operator experience.
- Mostly frontend (PHP/JS/CSS) reusing existing APIs.

Targets:
- Mobile view of work queue focused on the logged-in operator.
- Tap-friendly cards/buttons (≥44px).
- Reuse `dag_token_api.php` / `work_queue_api.php` only.
- Responsive design: desktop unchanged, mobile uses stacked card layout.

### Optional but Recommended Tests
Create `tests/UI/MobileWorkQueueTest.php` with scenarios:
- Viewport `< 500px` renders card layout.
- Start/Pause/Complete actions visible and clickable.
- Authenticated operator sees only own tokens.

### Execution Prompt (Phase 2B.6 – Mobile Work Queue UX)
```
Prompt to AI Agent:
- Do NOT modify dag_token_api.php or work_queue_api.php.
- Focus ONLY on hatthasilpa_work_queue.php and related JS/CSS.
- No new backend endpoints unless explicitly approved.
- Desktop layout must remain unchanged; adjust mobile layout only.
- Work on layout/responsiveness (CSS/JS/PHP) without altering APIs.
```

Execution outline (after Phase 7.X passes tests/audits):
```
- Read 2B.6 spec in DAG_IMPLEMENTATION_ROADMAP.md
- Update hatthasilpa_work_queue.php and its JS:
  * detect viewport ≤ mobile breakpoint → card view with large actions
  * quick access to Start/Pause/Complete
- Verify:
  * desktop layout intact
  * mobile layout operable with one thumb
```

---

## Step 3 — Phase 5.3 Dry Run / Simulation (post 7.X backend core)

Approach:
- Add simulation endpoint (e.g., `graph_simulate`) that:
  - Accepts current graph/draft payload.
  - Performs validation + lightweight path simulation.
  - **Must not** write to DB (`routing_graph` / `routing_graph_version` untouched).
- Graph Designer adds "Dry Run" button:
  - Calls simulate endpoint.
  - Displays summary: paths, split/join, unreachable nodes, warnings.
  - No mutation of live/draft state.

Prerequisite: Phase 7.X backend core complete ✅ (tests passing, audits can proceed independently).

### Dry Run Tests
Create `tests/Integration/GraphSimulationTest.php`:
- Simulate valid graph → returns simulation report JSON.
- Simulate graph with missing join → validation details returned, no DB writes.
- Simulate draft payload → accepted; report generated.

### High-Risk Note
Simulation endpoint must **not** modify:
- Validation rules
- Subgraph version logic
- Reachable/unreachable logic
- Join/split logic
- QC/rework logic
- Binding recalculation

Simulation must call existing validators only. **Never** insert simulation logic into `dag_routing_api.php` directly.

### Execution Prompt (Phase 5.3 – Graph Simulation)
```
Prompt to AI Agent:
- DO NOT touch dag_routing_api.php validation block.
- Implement new endpoint only (e.g., graph_simulate.php).
- Reuse DAGValidationService + normalization helpers.
- No database writes; simulation must be stateless.
- Return simulation_report JSON only.
```

---

## Step 4 — Phase 3 Dashboard & Phase 4 Genealogy (Future)

- Follow Codex plan when ready.
- Prepare data contracts in advance:
  - Dashboard ↔ `token_event`, `job_graph_instance`, `flow_token`.
  - Genealogy ↔ serial mapping (parent-child, component metadata).
- Detailed design deferred until Phase 7.X backend core ✅ and 2B.6 are complete.

---

## Quick Reference to Master File
- Primary roadmap: `docs/dag/02-implementation-status/DAG_IMPLEMENTATION_ROADMAP.md`
- Audit report: `docs/dag/02-implementation-status/PHASE_7_X_AUDIT_REPORT.md`

Use this sub-roadmap to avoid mistakes in the 9k-line master document. Update both files when major milestones change.  

