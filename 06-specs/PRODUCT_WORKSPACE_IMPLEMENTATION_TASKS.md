# Product Workspace: Implementation Task Breakdown
## Phase-by-Phase Development Guide

**Version:** 1.0  
**Date:** 2026-01-05  
**Status:** IN_PROGRESS  
**Contract:** UX_CONTRACT_LOCKED ✅

---

## ⚠️ Implementation Constraints (LOCKED)

These rules are **non-negotiable** throughout all phases:

- ❌ **No new modals** — All UI within workspace
- ❌ **No hidden revision state** — Status bar always visible
- ❌ **No bypass of acceptance criteria** — Each phase must pass before next
- ✅ **Incremental migration** — Old modals remain functional until Phase 5
- ✅ **Tab-based navigation** — No modal ping-pong

---

## Phase 1: Foundation (Workspace Shell)

**Goal:** Functional workspace with tab navigation + sticky status bar

### 1.1 Frontend Components

| Component | File | Description |
|-----------|------|-------------|
| `ProductWorkspace` | `assets/javascripts/products/product_workspace.js` | Main workspace controller |
| `WorkspaceStatusBar` | `assets/javascripts/products/workspace_status_bar.js` | Sticky revision status |
| `WorkspaceTabs` | `assets/javascripts/products/workspace_tabs.js` | Tab navigation logic |
| `WorkspaceGeneral` | `assets/javascripts/products/workspace_general.js` | General tab content |

### 1.2 Template Files

| Template | File | Description |
|----------|------|-------------|
| Workspace Modal | `source/components/product_workspace/workspace.php` | Main modal structure |
| Status Bar | `source/components/product_workspace/status_bar.php` | Status bar HTML |
| Tab Container | `source/components/product_workspace/tabs.php` | Tab navigation HTML |
| General Tab | `source/components/product_workspace/tab_general.php` | General form fields |

### 1.3 API Touchpoints

| Endpoint | Action | Purpose |
|----------|--------|---------|
| `product_api.php` | `get_product` | Load product data |
| `product_api.php` | `update_product` | Save general fields |
| `product_api.php` | `get_revision` | Get active revision for status bar |
| `product_api.php` | `get_usage_state` | Check product state (DRAFT/ACTIVE/etc) |

### 1.4 State Management

```javascript
// Workspace State Object
const workspaceState = {
    productId: null,
    product: null,           // Product master data
    activeRevision: null,    // Current published revision
    draftRevision: null,     // Uncommitted draft (if exists)
    activeTab: 'general',    // Current tab
    isDirty: false,          // Has unsaved changes
    isLoading: false,
    rowVersion: null         // For optimistic locking
};
```

### 1.5 Tasks Checklist

- [x] **1.1.1** Create workspace modal HTML structure ✅
- [x] **1.1.2** Create tab navigation component ✅
- [x] **1.1.3** Create sticky status bar component ✅
- [x] **1.1.4** Implement status bar states (clean/diverged/no-revision) ✅
- [x] **1.1.5** Create General tab with product form fields ✅
- [x] **1.1.6** Wire up save functionality for General tab ✅
- [x] **1.1.7** Add workspace open trigger from product list ✅
- [x] **1.1.8** Implement close with unsaved changes confirmation ✅

### 1.6 Acceptance Criteria Mapping

| Criterion | Implementation |
|-----------|----------------|
| Workspace opens ≤ 500ms | Lazy load tabs, preload product data |
| Tab navigation works | Click handler + content swap |
| General tab displays fields | Reuse existing form structure |
| Save works | POST to update_product |
| Status bar always visible | Fixed position in modal header |
| Shows correct revision state | API call on load |
| Close confirmation | beforeunload + modal close handler |

---

## Phase 2: Structure Tab (Components + Constraints)

**Goal:** Inline editing of BOM with divergence detection

### 2.1 Frontend Components

| Component | File | Description |
|-----------|------|-------------|
| `WorkspaceStructure` | `assets/javascripts/products/workspace_structure.js` | Structure tab logic |
| `ComponentEditor` | `assets/javascripts/products/component_editor.js` | Inline component table |
| `ConstraintEditor` | `assets/javascripts/products/constraint_editor.js` | Constraint JSON editor |
| `DivergenceDetector` | `assets/javascripts/products/divergence_detector.js` | Change detection |

### 2.2 API Touchpoints

| Endpoint | Action | Purpose |
|----------|--------|---------|
| `product_api.php` | `get_components` | Load component list |
| `product_api.php` | `save_component` | Save individual component |
| `product_api.php` | `delete_component` | Remove component |
| `product_api.php` | `get_constraints` | Load constraints JSON |
| `product_api.php` | `save_constraints` | Save constraints |
| `product_api.php` | `check_divergence` | Compare current vs active revision |

### 2.3 State Management Addition

```javascript
// Add to workspaceState
structureState: {
    components: [],
    constraints: {},
    originalSnapshot: null,  // From active revision
    hasDivergence: false,
    divergenceDetails: []
};
```

### 2.4 Tasks Checklist

- [x] **2.1.1** Create Structure tab layout ✅
- [x] **2.1.2** Migrate component table to Structure tab ✅
- [x] **2.1.3** Implement inline component editing ✅
- [x] **2.1.4** Migrate constraint editor (no separate modal) ✅
- [x] **2.1.5** Implement divergence detection logic ✅
- [x] **2.1.6** Create divergence warning banner ✅
- [x] **2.1.7** Implement "Discard Changes" action ✅
- [x] **2.1.8** Wire divergence state to status bar ✅

### 2.5 Acceptance Criteria Mapping

| Criterion | Implementation |
|-----------|----------------|
| Components table in Structure tab | Move existing table |
| Components editable inline | Edit mode per row |
| Constraints editor embedded | Inline JSON editor |
| Divergence warning ≤ 1s | Compare on change event |
| Discard removes all changes | Reset to originalSnapshot |
| Draft persists across tabs | Store in workspaceState |

---

## Phase 3: Production Tab (Graph Binding)

**Goal:** Explicit graph version selection with comparison

### 3.1 Frontend Components

| Component | File | Description |
|-----------|------|-------------|
| `WorkspaceProduction` | `assets/javascripts/products/workspace_production.js` | Production tab logic |
| `GraphVersionSelector` | `assets/javascripts/products/graph_version_selector.js` | Version dropdown |
| `GraphCompare` | `assets/javascripts/products/graph_compare.js` | Current vs selected |

### 3.2 API Touchpoints

| Endpoint | Action | Purpose |
|----------|--------|---------|
| `graph_api.php` | `list_versions` | Get available graph versions |
| `product_api.php` | `get_graph_binding` | Current binding |
| `product_api.php` | `preview_graph_change` | Impact preview |

### 3.3 Tasks Checklist

- [x] **3.1.1** Create Production tab layout ✅
- [x] **3.1.2** Implement graph version selector ✅
- [x] **3.1.3** Show current binding from active revision ✅
- [x] **3.1.4** Implement current vs selected comparison ✅
- [x] **3.1.5** Wire graph change to divergence detection ✅
- [x] **3.1.6** Add graph change impact message ✅
- [x] **3.1.7** Integrate Assets Management (Images) ✅
- [x] **3.1.8** Add Graph Visualization auto-fit ✅
- [x] **3.1.9** Integrate Product Readiness System (Task 30.5) ✅

### 3.4 Acceptance Criteria Mapping

| Criterion | Implementation |
|-----------|----------------|
| Graph selector shows all versions | API fetch on tab open |
| Current vs selected visible | Side-by-side display |
| Graph change triggers warning | Divergence detector integration |
| Graph appears in snapshot | Include in revision creation |

---

## Phase 4: Revisions Tab (Governance)

**Goal:** Full revision lifecycle management

### 4.1 Frontend Components

| Component | File | Description |
|-----------|------|-------------|
| `WorkspaceRevisions` | `assets/javascripts/products/workspace_revisions.js` | Revisions tab logic |
| `RevisionTimeline` | `assets/javascripts/products/revision_timeline.js` | Revision list display |
| `RevisionActions` | `assets/javascripts/products/revision_actions.js` | Lifecycle buttons |
| `SnapshotViewer` | `assets/javascripts/products/snapshot_viewer.js` | View snapshot JSON |

### 4.2 API Touchpoints

| Endpoint | Action | Purpose |
|----------|--------|---------|
| `product_api.php` | `list_revisions` | All revisions for product |
| `product_api.php` | `get_revision` | Revision details + snapshot |
| `product_api.php` | `create_revision` | Create draft |
| `product_api.php` | `publish_revision` | Publish draft |
| `product_api.php` | `retire_revision` | Retire published |
| `product_api.php` | `delete_revision` | Delete draft |

### 4.3 Tasks Checklist

- [x] **4.1.1** Create Revisions tab layout ✅
- [x] **4.1.2** Implement revision timeline/list ✅
- [x] **4.1.3** Show active revision badge ✅
- [x] **4.1.4** Implement lock reason display (expandable) ✅
- [x] **4.1.5** Wire Publish button with confirmation ✅
- [x] **4.1.6** Wire Retire button with confirmation ✅
- [x] **4.1.7** Wire Delete Draft button ✅
- [x] **4.1.8** Implement snapshot viewer modal ✅
- [x] **4.1.9** Handle 409 conflict gracefully ✅ (Optimistic locking with row_version)

### 4.4 Acceptance Criteria Mapping

| Criterion | Implementation |
|-----------|----------------|
| All revisions listed | Fetch on tab open |
| Active marked clearly | Green badge + "Active" label |
| Lock reason expandable | Accordion/collapsible |
| Publish creates revision | API + refresh status bar |
| Retire works | API + confirmation dialog |
| Delete draft works | API + guard checks |
| Snapshot viewable | Modal with JSON display |

---

## Phase 5: Polish & Deprecation

**Goal:** Complete UX, remove legacy modals

### 5.1 Tasks Checklist

- [x] **5.1.1** Finalize sticky status bar + global draft alert polish ✅ (i18n keys + fixed global alert visibility)
- [x] **5.1.2** Implement context-aware footer actions ✅ (disable Save when no changes; keep Publish gated by readiness)
- [x] **5.1.3** Add pre-publish validation summary ✅ (readiness checklist + draft scope shown in confirm)
- [x] **5.1.4** Test all Phase 1-4 criteria ✅ (phpunit regression run)
- [ ] **5.1.5** Conduct user testing (3 first-time users)
- [ ] **5.1.6** Fix issues from user testing
- [ ] **5.1.7** Remove legacy Edit Product modal
- [ ] **5.1.8** Remove legacy Constraints modal
- [ ] **5.1.9** Update all entry points to use workspace
- [ ] **5.1.10** Documentation update

### 5.2 Final Acceptance Criteria

| Criterion | Validation Method |
|-----------|-------------------|
| All Phase 1-4 criteria passing | Regression test |
| Power user 50% faster | Time comparison |
| First-time user 3-min publish | User test |
| Zero dead-end states | Exploratory testing |
| Old modals removed | Code audit |

---

## File Structure

```
assets/
├── javascripts/
│   └── products/
│       ├── product_workspace.js          # Main controller (Phase 1)
│       ├── workspace_status_bar.js       # Status bar (Phase 1)
│       ├── workspace_tabs.js             # Tab navigation (Phase 1)
│       ├── workspace_general.js          # General tab (Phase 1)
│       ├── workspace_structure.js        # Structure tab (Phase 2)
│       ├── workspace_production.js       # Production tab (Phase 3)
│       ├── workspace_revisions.js        # Revisions tab (Phase 4)
│       ├── component_editor.js           # Component table (Phase 2)
│       ├── constraint_editor.js          # Constraints (Phase 2)
│       ├── divergence_detector.js        # Change detection (Phase 2)
│       ├── graph_version_selector.js     # Graph picker (Phase 3)
│       ├── revision_timeline.js          # Revision list (Phase 4)
│       └── snapshot_viewer.js            # JSON viewer (Phase 4)
│
source/
├── components/
│   └── product_workspace/
│       ├── workspace.php                 # Main modal (Phase 1)
│       ├── status_bar.php                # Status bar HTML (Phase 1)
│       ├── tabs.php                      # Tab container (Phase 1)
│       ├── tab_general.php               # General form (Phase 1)
│       ├── tab_structure.php             # BOM/Constraints (Phase 2)
│       ├── tab_production.php            # Graph binding (Phase 3)
│       └── tab_revisions.php             # Governance (Phase 4)
```

---

## Current Progress

| Phase | Status | Completion |
|-------|--------|------------|
| Phase 1 | ✅ COMPLETE | 100% |
| Phase 2 | ✅ COMPLETE | 100% |
| Phase 3 | ✅ COMPLETE | 100% |
| Phase 4 | ✅ COMPLETE | 100% |
| Phase 5 | 🟡 IN_PROGRESS | 40% |

---

**Document End**

*Update this document as implementation progresses.*

