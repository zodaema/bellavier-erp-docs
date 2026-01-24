# Product Workspace Phase 3: Production Tab Plan

**Document Version:** 1.0  
**Date:** 2026-01-05  
**Status:** Planning  
**Author:** Opus 4.5 (Senior Product/UX Engineer + Staff Software Engineer)

---

## Executive Summary

Phase 3 implements the **Production Tab** within the Product Workspace, completing the "single-modal principle" by eliminating modal ping-pong for Graph Binding and Production Constraints management. This phase ensures users can configure production flow (routing graph binding, default mode, constraints) without leaving the workspace context.

**Key Achievement**: Users will no longer experience "Edit Graph → Close Modal → Remember to Publish" workflow. All production configuration happens inline, with server-truth draft detection and atomic publish/discard operations.

---

## 1. Goals

### Primary Goals
1. **Eliminate Modal Ping-Pong**: Graph binding and constraints editing must happen within the Workspace, not via separate Bootstrap modals
2. **Server Truth for Production Draft**: Production changes must use `get_usage_state` as source-of-truth (same pattern as Structure)
3. **Clear Mental Model**: Users understand: "Product Identity → Active Revision → Draft Changes (Structure/Production) → Publish"
4. **Conflict Handling**: Implement UX for 409 row_version conflicts using Task 29.4's concurrency model
5. **Accurate Draft Scope**: UI must not mislead users about which tab has pending changes

### Secondary Goals
- Reuse existing graph binding logic without duplication
- Prepare for Phase 4 (Revisions tab) by establishing publish workflow patterns
- Maintain Apple-grade UX: no dead ends, clear next actions, predictable behavior

---

## 2. Non-Goals

- **NOT** implementing full graph editor (use existing graph management UI)
- **NOT** implementing publish logic (Phase 4)
- **NOT** migrating all legacy modals (transitional strategy allowed)
- **NOT** adding new backend draft detection logic (reuse `get_usage_state`)

---

## 3. UX Design

### 3.1 Mental Model

```
Product Workspace (Single Modal)
├── General Tab: Product Identity (name, SKU, category, UoM)
├── Structure Tab: BOM & Constraints (Layer 2/3)
├── Production Tab: Routing & Flow Configuration ← PHASE 3
│   ├── Graph Binding Status (read-only summary)
│   ├── Graph Selection (inline picker or link to graph manager)
│   ├── Default Mode (batch/piece)
│   ├── Constraints (inline editor or embedded panel)
│   └── Draft Detection (server truth)
└── Revisions Tab: Governance & History (Phase 4)
```

### 3.2 Production Tab Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Production Tab                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─ Current Graph Binding ─────────────────────────────────┐│
│ │ Graph: [GRAPH-001] "Bag Assembly v2"                    ││
│ │ Version: v3.0 (pinned) │ Last Updated: 2025-12-15       ││
│ │ Default Mode: Batch                                      ││
│ │ Status: ✓ Active │ 3 jobs using this revision          ││
│ │                                                          ││
│ │ [Change Graph] [Edit Constraints]                       ││
│ └──────────────────────────────────────────────────────────┘│
│                                                             │
│ ┌─ Production Constraints ─────────────────────────────────┐│
│ │ (Inline editor or embedded panel - NO SEPARATE MODAL)   ││
│ │ • Min batch size: 10 pieces                             ││
│ │ • Max concurrent jobs: 5                                ││
│ │ • Lead time: 3 days                                     ││
│ └──────────────────────────────────────────────────────────┘│
│                                                             │
│ ┌─ Draft Changes Detected ─────────────────────────────────┐│
│ │ ⚠ You have unsaved production changes                   ││
│ │ • Graph binding changed from GRAPH-001 to GRAPH-002     ││
│ │ • Default mode changed from Batch to Piece              ││
│ │                                                          ││
│ │ These changes will affect new jobs created after        ││
│ │ publishing. Existing jobs (3) will continue using       ││
│ │ the current revision.                                   ││
│ └──────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘

Footer: [Discard Changes] [Publish Revision]
```

### 3.3 Interaction Patterns

#### Pattern A: Change Graph (Recommended)
1. User clicks **[Change Graph]** button
2. **Inline Graph Picker** appears within Production tab (replaces summary section)
3. User selects graph from dropdown or search
4. User confirms selection
5. Summary section updates with new graph
6. Draft detection triggers → Status Bar shows "Draft Changes Detected (Production)"
7. Footer shows **[Discard Changes]** and **[Publish Revision]**

#### Pattern B: Edit Constraints (Transitional)
1. User clicks **[Edit Constraints]** button
2. **Embedded Constraints Panel** expands within Production tab (accordion or drawer)
3. User edits constraints inline (no modal)
4. User clicks **[Save Constraints]** (local save, not publish)
5. Draft detection triggers
6. Footer shows **[Discard Changes]** and **[Publish Revision]**

#### Pattern C: Conflict Handling (409 Row Version Mismatch)
1. User clicks **[Publish Revision]**
2. Backend returns `409 Conflict` (row_version mismatch)
3. Workspace shows **Conflict Dialog**:
   ```
   ┌─ Concurrent Modification Detected ─────────────────────┐
   │ Another user has modified this product since you       │
   │ started editing.                                       │
   │                                                        │
   │ Your changes:                                          │
   │ • Graph: GRAPH-001 → GRAPH-002                        │
   │ • Mode: Batch → Piece                                 │
   │                                                        │
   │ Their changes:                                         │
   │ • Graph: GRAPH-001 → GRAPH-003                        │
   │ • Mode: Batch (unchanged)                             │
   │                                                        │
   │ [Reload Latest] [Compare] [Cancel]                    │
   └────────────────────────────────────────────────────────┘
   ```
4. User chooses:
   - **Reload Latest**: Discard local changes, reload from server
   - **Compare**: Show side-by-side diff (Phase 4)
   - **Cancel**: Keep editing, resolve manually

---

## 4. Data Contract

### 4.1 API Endpoints (Existing)

**Get Usage State** (Already exists)
```
GET /source/product_api.php?action=get_usage_state&id_product=123

Response:
{
  "ok": true,
  "data": {
    "active_revision": { ... },
    "has_draft_changes": true,
    "change_count": 2,
    "draft_scope": "production" // NEW: Backend should split scope
  }
}
```

**Get Graph Binding** (Already exists)
```
GET /source/products.php?action=detail&id_product=123

Response:
{
  "ok": true,
  "product": { ... },
  "graph_binding": {
    "id_graph": 5,
    "graph_code": "GRAPH-001",
    "graph_name": "Bag Assembly v2",
    "graph_version_pin": "3.0",
    "default_mode": "batch",
    "is_active": true
  }
}
```

**Update Graph Binding** (May need new endpoint)
```
POST /source/product_api.php

{
  "action": "update_graph_binding",
  "id_product": 123,
  "id_graph": 6,
  "graph_version_pin": "4.0",
  "default_mode": "piece",
  "row_version": 5 // For concurrency control
}

Response (Success):
{
  "ok": true,
  "message": "Graph binding updated (draft)",
  "row_version": 6
}

Response (Conflict):
{
  "ok": false,
  "error": "Concurrent modification detected",
  "app_code": "PRD_409_CONFLICT",
  "current_row_version": 7,
  "current_data": { ... }
}
```

**Discard Draft Changes** (Already exists from Phase 2)
```
POST /source/product_api.php

{
  "action": "discard_draft_changes",
  "id_product": 123,
  "scope": "production"
}
```

### 4.2 Frontend State

```javascript
state.serverDraft.production = true; // From get_usage_state
state.lastDraftScope = 'production'; // Tracked on change

// Production tab state
productionState = {
  currentBinding: null,
  originalBinding: null,
  isLoaded: false,
  isEditing: false,
  editMode: null, // 'graph' | 'constraints' | null
};
```

---

## 5. Implementation Tasks

### Task 3.1: Production Tab UI Shell
**Effort**: 2 hours  
**Dependencies**: None

- [ ] Create `tab_production.php` template
- [ ] Add "Current Graph Binding" summary section (read-only)
- [ ] Add **[Change Graph]** and **[Edit Constraints]** buttons
- [ ] Add empty state for "No graph binding"
- [ ] Wire up tab activation in `product_workspace.js`

### Task 3.2: Load Production Data
**Effort**: 3 hours  
**Dependencies**: Task 3.1

- [ ] Add `loadProductionTab()` function
- [ ] Fetch graph binding from `products.php?action=detail`
- [ ] Populate summary section with binding data
- [ ] Handle "no binding" state
- [ ] Add loading spinner

### Task 3.3: Inline Graph Picker
**Effort**: 4 hours  
**Dependencies**: Task 3.2

- [ ] Create inline graph selection UI (dropdown or search)
- [ ] Fetch available graphs from backend
- [ ] Show graph preview (nodes, version)
- [ ] Implement "Confirm Selection" flow
- [ ] Update summary section after selection
- [ ] Trigger draft detection (set `state.lastDraftScope = 'production'`)

### Task 3.4: Embedded Constraints Editor
**Effort**: 5 hours  
**Dependencies**: Task 3.2

**Option A (Recommended)**: Inline accordion/drawer
- [ ] Create expandable constraints panel within Production tab
- [ ] Reuse existing constraint field rendering logic
- [ ] Add **[Save Constraints]** button (local save, not publish)
- [ ] Trigger draft detection after save

**Option B (Transitional)**: Render legacy modal content in iframe-like container
- [ ] Embed existing constraints modal HTML in a `<div>` within Production tab
- [ ] Disable Bootstrap modal backdrop
- [ ] Intercept modal close events to stay within workspace
- [ ] Migrate to Option A in Phase 3.5

### Task 3.5: Draft Detection for Production
**Effort**: 2 hours  
**Dependencies**: Task 3.3, 3.4

- [ ] Track `state.lastDraftScope = 'production'` on graph/constraint changes
- [ ] Update `updateRevisionStatus()` to handle `draft_scope` from backend
- [ ] Show draft scope label in Status Bar: "Draft Changes Detected (Production)"
- [ ] Update footer buttons to show Publish/Discard only in Production tab when draft exists

### Task 3.6: Discard Changes for Production
**Effort**: 1 hour  
**Dependencies**: Task 3.5

- [ ] Extend `handleDiscardChanges()` to handle `scope: 'production'`
- [ ] Call `discard_draft_changes` API (already exists from Phase 2)
- [ ] Reload Production tab after discard
- [ ] Refresh status bar

### Task 3.7: Conflict Handling (409)
**Effort**: 4 hours  
**Dependencies**: Task 3.3, 3.4

- [ ] Detect `409 Conflict` response from `update_graph_binding` API
- [ ] Show **Conflict Dialog** with:
  - Your changes vs Their changes
  - **[Reload Latest]** button → discard local, reload from server
  - **[Compare]** button → show diff (Phase 4)
  - **[Cancel]** button → keep editing
- [ ] Implement **Reload Latest** flow
- [ ] Log conflict events for debugging

### Task 3.8: Backend: Split Draft Scope
**Effort**: 3 hours  
**Dependencies**: None (can run in parallel)

- [ ] Modify `ProductUsageStateService::getUsageState()` to return `draft_scope`
- [ ] Detect if draft is from:
  - `product_component` changes → `'structure'`
  - `product_graph_binding` changes → `'production'`
  - Both → `'both'`
- [ ] Update API response to include `draft_scope` field

### Task 3.9: Phase 2 Patches (From User Feedback)
**Effort**: 2 hours  
**Dependencies**: None

- [x] Replace `state.isDirty` with computed `isWorkspaceDirty()`
- [x] Add draft scope hint to Status Bar
- [x] Remove duplicate publish buttons (canonical pattern: footer only)

---

## 6. Risk & Mitigation

### Risk 1: Legacy Constraints Modal is Complex
**Impact**: High  
**Probability**: High  
**Mitigation**:
- Start with **Pattern B (Transitional)**: Embed modal content in iframe-like container
- Plan migration to inline editor in Phase 3.5
- Document technical debt for future cleanup

### Risk 2: Backend Cannot Split Draft Scope Yet
**Impact**: Medium  
**Probability**: Medium  
**Mitigation**:
- Use `state.lastDraftScope` as client-side hint
- Show scope label based on last tab that triggered change
- Document limitation in UI: "Draft changes detected (last edited: Production)"
- Plan backend split for Phase 3.8

### Risk 3: Conflict UX is Unfamiliar to Users
**Impact**: Low  
**Probability**: Low  
**Mitigation**:
- Show clear explanation: "Another user modified this product"
- Provide safe default: **[Reload Latest]** is primary action
- Log conflicts for monitoring
- Add help text: "This prevents accidental overwrites"

### Risk 4: Graph Picker Performance (Many Graphs)
**Impact**: Low  
**Probability**: Low  
**Mitigation**:
- Use Select2 with search/pagination
- Cache graph list in client
- Add loading indicator
- Limit initial load to 50 graphs

---

## 7. Acceptance Criteria

### 7.1 Functional Criteria

**Production Tab Display**
- [ ] Production tab shows current graph binding (graph code, version, mode)
- [ ] Production tab shows "No graph binding" state if not configured
- [ ] Production tab shows constraints summary (read-only)
- [ ] Production tab loads within 500ms

**Graph Binding Change**
- [ ] User can change graph without opening separate modal
- [ ] User can select graph from dropdown/search
- [ ] User sees graph preview before confirming
- [ ] Draft detection triggers after graph change
- [ ] Status Bar shows "Draft Changes Detected (Production)"
- [ ] Footer shows **[Publish Revision]** and **[Discard Changes]**

**Constraints Editing**
- [ ] User can edit constraints without opening separate modal
- [ ] User can save constraints (local save, not publish)
- [ ] Draft detection triggers after constraint save
- [ ] Status Bar updates to show draft scope

**Discard Changes**
- [ ] User can discard production changes via footer button
- [ ] Discard restores graph binding from active revision snapshot
- [ ] Discard restores constraints from active revision snapshot
- [ ] Production tab reloads after discard
- [ ] Status Bar updates to "Clean" state

**Conflict Handling**
- [ ] 409 Conflict shows clear dialog with user's changes vs server's changes
- [ ] **[Reload Latest]** discards local changes and reloads from server
- [ ] **[Cancel]** keeps local changes and allows manual resolution
- [ ] Conflict events are logged for debugging

**Draft Scope Accuracy**
- [ ] Status Bar shows correct scope: "Structure", "Production", or "Both"
- [ ] Footer buttons appear only in relevant tabs
- [ ] User is not misled about which tab has pending changes

### 7.2 UX Criteria

**No Modal Ping-Pong**
- [ ] User never sees nested Bootstrap modals
- [ ] User never loses context when editing graph/constraints
- [ ] User can navigate between tabs without losing draft state

**Clear Mental Model**
- [ ] First-time user understands "Draft → Publish" flow within 2 minutes
- [ ] User knows which tab has pending changes at all times
- [ ] User understands impact of publish: "New jobs will use new config, existing jobs unchanged"

**Error Prevention**
- [ ] User cannot accidentally close workspace with unsaved changes (confirmation dialog)
- [ ] User cannot accidentally overwrite concurrent changes (409 conflict handling)
- [ ] User sees clear warning before discarding changes

**Performance**
- [ ] Production tab loads within 500ms
- [ ] Graph picker search responds within 200ms
- [ ] Draft detection updates within 100ms (local) + 30s (server polling)

---

## 8. Test Plan

### 8.1 Manual Testing Checklist

**Happy Path**
- [ ] Open workspace → Navigate to Production tab → See current binding
- [ ] Click **[Change Graph]** → Select new graph → Confirm → See draft detected
- [ ] Click **[Edit Constraints]** → Modify constraint → Save → See draft detected
- [ ] Click **[Discard Changes]** → Confirm → See changes reverted
- [ ] Navigate between tabs → Draft state persists
- [ ] Close workspace with draft → See confirmation dialog

**Edge Cases**
- [ ] Product with no graph binding → See empty state
- [ ] Product with 0 constraints → See empty constraints section
- [ ] Concurrent modification → See 409 conflict dialog
- [ ] Network error during graph change → See error message
- [ ] Slow graph picker load → See loading spinner

**Conflict Scenarios**
- [ ] User A changes graph, User B changes graph → 409 conflict
- [ ] User A changes graph, User B changes constraints → No conflict (different fields)
- [ ] User A publishes, User B tries to publish → 409 conflict

### 8.2 Automated Testing Hooks

**Frontend Unit Tests**
```javascript
describe('ProductionTab', () => {
  it('should load graph binding on tab activation', async () => { ... });
  it('should detect draft after graph change', () => { ... });
  it('should show conflict dialog on 409 response', () => { ... });
  it('should discard changes and reload', async () => { ... });
});
```

**Backend Integration Tests**
```php
class ProductionTabApiTest extends TestCase {
  public function testUpdateGraphBindingCreatesDraft() { ... }
  public function testDiscardProductionChangesRestoresSnapshot() { ... }
  public function testConcurrentModificationReturns409() { ... }
}
```

---

## 9. Rollout Strategy

### Phase 3.1: Foundation (Week 1)
- Implement Tasks 3.1, 3.2, 3.9
- Deploy to staging
- Internal testing

### Phase 3.2: Core Features (Week 2)
- Implement Tasks 3.3, 3.4, 3.5, 3.6
- Deploy to staging
- User acceptance testing (UAT)

### Phase 3.3: Polish & Conflict Handling (Week 3)
- Implement Tasks 3.7, 3.8
- Deploy to staging
- Load testing

### Phase 3.4: Production Rollout (Week 4)
- Deploy to production
- Monitor for conflicts and errors
- Collect user feedback

### Rollback Plan
- If critical bugs found: Disable Production tab (show "Coming Soon" message)
- If performance issues: Revert to legacy modal workflow
- If data corruption: Restore from backup, investigate snapshot restore logic

---

## 10. Success Metrics

### Quantitative Metrics
- **Modal Ping-Pong Reduction**: 0 nested modals (down from 2-3 in legacy flow)
- **Task Completion Time**: < 2 minutes to change graph and publish (down from 5+ minutes)
- **Error Rate**: < 1% of graph binding changes fail
- **Conflict Rate**: < 5% of publish attempts encounter 409 conflicts
- **Performance**: Production tab loads in < 500ms (P95)

### Qualitative Metrics
- **User Satisfaction**: "I no longer forget to publish" (user interviews)
- **Clarity**: "I always know if I have pending changes" (user interviews)
- **Confidence**: "I'm not afraid of overwriting someone else's work" (user interviews)

---

## 11. Future Enhancements (Post-Phase 3)

### Phase 3.5: Inline Constraints Editor
- Migrate from embedded modal to native inline editor
- Add real-time validation
- Add constraint templates

### Phase 4: Revisions Tab
- Full publish workflow with review screen
- Revision history and comparison
- Rollback to previous revisions

### Phase 5: Advanced Conflict Resolution
- Three-way merge UI
- Automatic conflict resolution for non-overlapping changes
- Conflict notification system

---

## Appendix A: Phase 2 Patches (Completed)

### Patch 1: Computed `isWorkspaceDirty()`
**Problem**: `state.isDirty` was mutable and unreliable  
**Solution**: Replaced with computed function derived from `localDirty` and `serverDraft`

```javascript
function isWorkspaceDirty() {
  return state.localDirty.general || 
         state.serverDraft.structure || 
         state.serverDraft.production;
}
```

### Patch 2: Draft Scope Hint
**Problem**: Backend cannot split draft scope yet, causing misleading UI  
**Solution**: Added `state.lastDraftScope` tracking and scope label in Status Bar

```javascript
state.lastDraftScope = 'production'; // Set on change
const scopeLabel = getDraftScopeLabel(); // 'Structure' | 'Production' | 'Both'
$('#statusChangeCount').text(`${changeCount} pending changes (${scopeLabel})`);
```

### Patch 3: Canonical Publish Button
**Problem**: Duplicate publish buttons (tab-level + footer) caused confusion  
**Solution**: Removed tab-level publish, kept footer as single source of truth

```javascript
// Footer only
$('#btnPublishRevision').on('click', handleQuickPublish);

// Tab buttons removed
// If tab needs CTA, scroll/focus to footer instead
```

---

## Appendix B: Technical Debt

### Debt 1: Embedded Constraints Modal (Transitional)
**Description**: Phase 3.4 may use iframe-like embedding of legacy modal  
**Impact**: Medium (code complexity, maintenance burden)  
**Payoff Plan**: Migrate to inline editor in Phase 3.5  
**Estimated Effort**: 8 hours

### Debt 2: Client-Side Draft Scope Hint
**Description**: Backend cannot split scope yet, using client-side tracking  
**Impact**: Low (minor UX limitation)  
**Payoff Plan**: Implement Task 3.8 (backend split)  
**Estimated Effort**: 3 hours

### Debt 3: No Three-Way Merge for Conflicts
**Description**: 409 conflicts require manual resolution  
**Impact**: Low (rare occurrence)  
**Payoff Plan**: Phase 5 (advanced conflict resolution)  
**Estimated Effort**: 16 hours

---

**End of Document**
