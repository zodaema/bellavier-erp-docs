# Phase 7.X Audit Report – Graph Draft Layer

**Date:** 2025-11-15

## 1. Scope
- `routing_graph_draft` schema & migration `2025_12_graph_draft_layer.php`
- API actions: `graph_save_draft`, `graph_discard_draft`, `graph_publish`, `graph_get`
- Client modules: `graph_designer.js`, `GraphLoader`, `GraphSaver`, `EventManager`, `GraphAPI`
- Validation behavior (draft vs strict publish)
- ETag / concurrency integration with draft workflow

## 2. Findings & Fixes
| ID | Area | Severity | Finding | Fix/Resolution |
|----|------|----------|---------|----------------|
| F-01 | Frontend – Save Flow | High | Manual `saveGraph()` still posted to live `graph_save` even when draft mode active, risking overwrite. | Added draft-mode guard to reroute manual saves to `saveDraft()` and skip auto-save while draft active. |
| F-02 | Frontend – Draft Save Payload | High | `saveDraft()` serialized raw Cytoscape data, missing normalized fields (position, JSON payloads), causing schema mismatch vs API expectations. | Reimplemented `saveDraft()` to reuse GraphSaver collectors and `SafeJSON`; now guarantees parity with `graph_save`. |
| F-03 | Frontend – State Handling | High | Draft save button did not manage `isManualSaving`, status indicators, or promise rejection, leading to stuck UI and unhandled errors. | Updated `saveDraft()` to manage state/indicators and return a Promise; EventManager now swallows rejection for button handler. |
| F-04 | Frontend – Draft Mode Flag | Medium | UI showed badge but core logic didn’t know draft state; save/auto-save unaware. | Introduced `isDraftModeActive` flag, toggled in `showDraftMode()/hideDraftMode()` and `handleGraphLoaded`. |
| F-05 | Frontend – API Access | Low | Multiple ad-hoc `graphAPI` instantiations; some code paths assumed global existed. | Created single `graphAPI` instance near state declarations and reused across draft actions. |

## 3. Outstanding Risks / TODO
1. **Backend constraint verification** – FK & unique index tests for `routing_graph_draft` still pending (tracked in roadmap checklist).
2. **Automated tests** – Need unit/integration coverage for draft save/discard/publish flows (API + UI).
3. **UX regression** – Full Graph Designer regression (autosave, undo/redo, quick-fix) required post-change.
4. **ETag/If-Match tests** – Ensure publish with stale draft + If-Match conflict surfaces correct error in UI.

## 4. Recommended Next Steps
- Write PHPUnit tests covering draft endpoints (happy path + validation warnings + publish strict failure).
- Expand JS test plan / manual checklist focusing on draft lifecycle (save → discard → publish) and concurrency scenarios.
- Run database constraint stress test (multiple drafts, concurrent users) to confirm unique index behavior.
- Update user documentation / training snippet to describe Save Draft vs Save behavior.

## 5. Graph Draft Data Model Audit (Nov 16, 2025)
- ✅ Verified migration `2025_12_graph_draft_layer.php` defines required columns (id_graph_draft, id_graph FK, draft_payload_json, status enum, timestamps, updated_by).
- ⚙️ Added patch migration `2025_12_graph_draft_layer_patch.php` to make `updated_by` nullable per spec; applied to DEFAULT/maison_atelier/test.
- ✅ Unique key `uq_graph_active (id_graph, status)` enforces single active draft; API additionally soft-discarded previous drafts before insert.
- ✅ Searched codebase – only `graph_save_draft`, `graph_discard_draft`, `graph_publish`, `graph_get` touch `routing_graph_draft`. Manual saves in draft mode now route through `saveDraft()` ensuring no direct writes to `routing_graph`.
- ✅ Confirmed draft saves never call `graph_save` (auto-save disabled + manual rerouted). Publish loads draft payload and only updates live graph after strict validation, then discards draft.
- 🚧 Remaining tests: database FK/unique stress tests & automated coverage for draft APIs/UI (tracked in Next Steps).

## 6. Draft API Contract Audit (Nov 16, 2025)
- ✅ `graph_save_draft` only talks to `routing_graph_draft` (insert/update + soft-discard old drafts). Validation runs in `'draft'` mode and warnings are returned in `validation_warnings`; endpoint never blocks on normal DAG issues.
- ✅ `graph_discard_draft` simply marks active drafts as `status='discarded'` with timestamp update. No touch of `routing_graph`/`routing_graph_version`; multiple calls safe (returns `had_draft`).
- ✅ `graph_publish` loads draft payload when present, normalizes nodes, runs `validateGraphStructure(...,'strict')`, returns `DAG_ROUTING_400_SUBGRAPH_VERSION` or `DAG_ROUTING_400_VALIDATION` with HTTP 400 on failure, otherwise snapshots to `routing_graph_version`, updates `routing_graph`, and discards draft.
- ✅ Legacy `graph_save` path still exists for non-draft graphs, but Graph Designer now routes manual/auto save through draft APIs whenever a draft is active, preventing accidental overwrites.
- 📌 Remaining work: add automated tests to assert HTTP/app_code responses and legacy-save toggle behavior (tracked in roadmap TODO).

## 7. Test Coverage Update (Nov 16, 2025)
- ✅ Added `tests/Integration/GraphDraftLayerTest.php` (maison_atelier tenant) covering draft save/update, discard, publish (valid/invalid), legacy publish without draft, and `graph_get` draft payload loading.
- ✅ Verified `tests/Integration/SubgraphGovernanceTest.php` remains 11/11 green after draft layer integration (no governance regressions).

## 8. Backend Completion Summary (Phase 7.X)
- ✅ Graph draft layer APIs validated via `GraphDraftLayerTest` (5 cases)
- ✅ Subgraph governance scenarios validated via `SubgraphGovernanceTest` (11 cases)
- ✅ Migrations applied to DEFAULT, maison_atelier, and test tenants
- ✅ Test cleanup strategy covers `job_graph_instance` + `graph_subgraph_binding` for temporary graphs
- ⏸ Draft-related UI/UX items (indicator, dialogs, autosave feedback) moved to Phase 7.Y – Graph Designer Draft UX Polish
