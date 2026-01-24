# Product Workspace UX Refactor Plan
## Apple-Grade, Revision-First, Human-Centric Design

**Version:** 1.0  
**Date:** 2026-01-05  
**Author:** Lead Product Architect  
**Status:** APPROVED FOR IMPLEMENTATION

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Mental Model](#2-mental-model)
3. [Workspace Layout Specification](#3-workspace-layout-specification)
4. [UX Flow Examples](#4-ux-flow-examples)
5. [Migration Strategy](#5-migration-strategy)
6. [Guardrails & Safety Design](#6-guardrails--safety-design)
7. [Implementation Phases](#7-implementation-phases)
8. [Anti-Patterns (Explicitly Rejected)](#8-anti-patterns-explicitly-rejected)
9. [Quality Validation Checklist](#9-quality-validation-checklist)

---

## 1. Executive Summary

### 1.1 Why Current UX is Risky

The current Product UI suffers from **fragmented cognitive load**:

| Problem | Impact | Risk Level |
|---------|--------|------------|
| Product editing, Graph Binding, Constraints, and Revisions live in **separate modals** | Users lose context when switching between tasks | 🔴 High |
| Revision controls are **hidden inside Edit modal** | Users forget revisions exist; skip publishing | 🔴 High |
| No **visible divergence detection** | Users make changes but don't know they need a new revision | 🔴 Critical |
| System dependencies are **invisible** | Graph/Constraint → Revision dependency is unclear | 🟡 Medium |
| **Modal ping-pong** required for complete workflows | High friction, high error rate | 🔴 High |

**Root Cause:** The UI treats "Revision" as a field to manage, not as the governance backbone that the system actually uses.

### 1.2 What the New Workspace Solves

The **Product Workspace** consolidates all product configuration into a **single, tabbed interface** with:

| Improvement | Benefit |
|-------------|---------|
| **Unified context** | All product config in one place |
| **Sticky revision bar** | User always knows current governance state |
| **Automatic divergence detection** | System tells user when action is needed |
| **Guided actions** | No dead ends, no hidden critical steps |
| **Tab-based mental model** | Clear separation of concerns without losing context |

**Design Mantra:**

> "The user does not manage revisions. The system uses revisions.  
> The user configures products. The system enforces governance."

---

## 2. Mental Model

### 2.1 Conceptual Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRODUCT WORKSPACE                            │
│                    (Single Modal / Drawer / Page)                   │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              STICKY REVISION STATUS BAR                      │    │
│  │  ● Active: Rev 2.0 (Published 2025-11-12) 🔒                │    │
│  │  ⚠️ Draft changes detected — Publish required               │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌──────────┬──────────┬─────────────┬────────────┐                │
│  │ General  │ Structure │ Production  │ Revisions  │                │
│  │ (Identity)│(Spec/BOM)│(Graph/Flow) │(Governance)│                │
│  └──────────┴──────────┴─────────────┴────────────┘                │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                     TAB CONTENT AREA                         │    │
│  │              (Context-aware, editable/readonly)              │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                     ACTION FOOTER                            │    │
│  │         [Discard] [Save Draft] [Publish Revision]           │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Entity Relationships

```
PRODUCT (Identity)
    │
    ├── Immutable: SKU, Base UOM
    ├── Editable: Name, Description, Category, Active Status
    │
    └── REVISIONS (Governance Layer)
            │
            ├── Rev 1.0 [RETIRED] ← Referenced by 45 jobs
            ├── Rev 2.0 [PUBLISHED] ← Active, referenced by 12 jobs 🔒
            └── Rev 3.0 [DRAFT] ← Contains unpublished changes
                    │
                    ├── Snapshot: Components + Constraints + Graph Version
                    └── State: Diverged from Rev 2.0
```

### 2.3 Key Insight

| Concept | Definition |
|---------|------------|
| **Product** | Identity container — "What is this item?" |
| **Revision** | Frozen specification — "What does production use?" |
| **Workspace** | Lens over revisions — "How do I configure this?" |

The user interacts with the **Workspace**.  
The system persists to **Revisions**.  
Production consumes **Snapshots**.

---

## 3. Workspace Layout Specification

### 3.1 Tab Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  General  │  Structure  │  Production  │  Revisions            │
│  ────────    ─────────     ──────────     ──────────           │
│  Identity    BOM/Spec     Graph/Flow     Governance            │
│  Always      Breaking     Breaking       Timeline              │
│  Editable    Changes      Changes        + Actions             │
└─────────────────────────────────────────────────────────────────┘
```

---

### 3.2 Tab: General (Identity)

**Purpose:** Product master data that does NOT affect production spec.

| Field | Editable | Requires New Revision |
|-------|----------|----------------------|
| SKU | ❌ (Immutable) | N/A |
| Name | ✅ | ❌ No |
| Description | ✅ | ❌ No |
| Category | ✅ | ❌ No |
| Active / Inactive | ✅ | ❌ No |
| Default UOM | ❌ (Invariant) | N/A |
| Production Line | ⚠️ (Warning) | ⚠️ Advisory |

**UX Behavior:**
- Changes save immediately to `product` table
- No revision impact
- Green "Saved" confirmation inline

**Visual:**
```
┌─────────────────────────────────────────────────────────────┐
│ General                                                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  SKU              │ BV-TOTE-001          │ 🔒               │
│  Name             │ Classic Leather Tote │ ✎                │
│  Description      │ Premium handcrafted… │ ✎                │
│  Category         │ Bags ▼               │                   │
│  Status           │ ● Active  ○ Inactive │                   │
│  Production Line  │ ● Hatthasilpa ○ Classic │               │
│                                                              │
│  ────────────────────────────────────────                   │
│  ✓ Changes auto-saved. No revision required.                │
└─────────────────────────────────────────────────────────────┘
```

---

### 3.3 Tab: Structure (BOM / Spec)

**Purpose:** Components, Constraints, Material specifications — **Breaking changes require revision.**

| Section | Content | Editable |
|---------|---------|----------|
| Components | Material list with roles, quantities, constraints | ✅ Draft mode |
| Constraints | JSON-based validation rules per component | ✅ Draft mode |
| Validation | Real-time constraint schema validation | Read-only |

**UX Behavior:**
- Edits accumulate as **Draft Changes**
- Divergence from active revision is computed live
- **Banner appears** when divergence detected:

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠️ Draft Changes Detected                                   │
│                                                              │
│ You have modified 3 components and 2 constraint rules.      │
│ These changes will NOT affect production until published.   │
│                                                              │
│ [Preview Diff]  [Discard Changes]  [Create Revision →]     │
└─────────────────────────────────────────────────────────────┘
```

**Visual:**
```
┌─────────────────────────────────────────────────────────────┐
│ Structure                                                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Components (5)                              [+ Add]        │
│  ─────────────────────────────────────────────────          │
│  │ Role          │ Material       │ Qty  │ Constraints │    │
│  │ main_body     │ Italian Veg-Tan│ 1.2m²│ ✓ Valid     │    │
│  │ strap         │ Bridle Leather │ 0.4m²│ ✓ Valid     │    │
│  │ lining        │ Suede Pig      │ 0.8m²│ ⚠️ Modified │    │
│  │ hardware      │ Brass Buckle   │ 4 pcs│ ✓ Valid     │    │
│  │ thread        │ Global Thread  │ 50m  │ ✓ Valid     │    │
│                                                              │
│  Constraints Schema: v1.3 ✓                                 │
│                                                              │
│  ────────────────────────────────────────────────           │
│  ⚠️ 1 component modified. Revision required to apply.       │
└─────────────────────────────────────────────────────────────┘
```

---

### 3.4 Tab: Production (Graph / Flow)

**Purpose:** Production flow binding — **Explicit graph_version_id selection.**

| Field | Content | Editable |
|-------|---------|----------|
| Graph Selection | Dropdown of available published graph versions | ✅ |
| Current Binding | Which graph version active revision uses | Read-only |
| Preview | Visual DAG preview (future) | Read-only |

**UX Behavior:**
- Changing graph version = **Breaking change**
- Must create new revision to apply
- Clear comparison between current vs selected:

```
┌─────────────────────────────────────────────────────────────┐
│ Production                                                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Production Flow Binding                                     │
│  ─────────────────────────────────────────────              │
│                                                              │
│  Current (Rev 2.0):  H-v2.0 "Leather Bag Standard"         │
│  Selected:           H-v4.0 "Leather Bag Parallel + Assy"  │
│                                                              │
│  ┌───────────────────────────────────────────────────┐     │
│  │ ⚠️ Graph version change detected                   │     │
│  │                                                     │     │
│  │ Changing production flow requires a new revision.  │     │
│  │ Jobs using Rev 2.0 will continue with H-v2.0.     │     │
│  │ New jobs will use H-v4.0 after publishing.        │     │
│  │                                                     │     │
│  │ [Keep Current]  [Apply to New Revision →]         │     │
│  └───────────────────────────────────────────────────┘     │
│                                                              │
│  Graph Preview (Conceptual)                                 │
│  ─────────────────────────────────────────────              │
│  [Cutting] ──→ [Prep] ──→ [Assembly] ──→ [QC]              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

### 3.5 Tab: Revisions (Governance)

**Purpose:** Revision history, lifecycle actions, lock visibility — **The control center.**

| Section | Content |
|---------|---------|
| Timeline | Chronological list of all revisions |
| Active Badge | Clear visual for current production revision |
| Lock Reasons | Why a revision cannot be modified |
| Actions | Publish Draft, Retire, View Snapshot |

**UX Behavior:**
- This is the **governance dashboard**
- No editing of spec here — only lifecycle actions
- Clear explanation of immutability:

```
┌─────────────────────────────────────────────────────────────┐
│ Revisions                                                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Revision History                                            │
│  ─────────────────────────────────────────────              │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ★ Rev 3.0 [DRAFT]                                    │   │
│  │   Created: 2026-01-05 by Admin                       │   │
│  │   Changes: 3 components, 1 graph update              │   │
│  │                                                       │   │
│  │   [Preview] [Publish →] [Delete Draft]               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ● Rev 2.0 [PUBLISHED] 🔒 Active                      │   │
│  │   Published: 2025-11-12 by Admin                     │   │
│  │   Graph: H-v2.0                                      │   │
│  │   Referenced by: 12 active jobs, 34 tokens           │   │
│  │                                                       │   │
│  │   Lock Reason: IN_PRODUCTION (45 total references)   │   │
│  │   This revision cannot be modified.                  │   │
│  │                                                       │   │
│  │   [View Snapshot] [Retire →]                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ○ Rev 1.0 [RETIRED]                                  │   │
│  │   Published: 2025-08-01 / Retired: 2025-11-12       │   │
│  │   Referenced by: 128 completed jobs                  │   │
│  │                                                       │   │
│  │   [View Snapshot]                                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

### 3.6 Sticky Revision Status Bar

**Always visible at top of workspace.** Never hidden.

**States:**

| State | Visual | Action |
|-------|--------|--------|
| Clean | `● Rev 2.0 Active — No pending changes` | None required |
| Diverged | `⚠️ Draft changes — Publish required` | [Publish Now] |
| No Revision | `⚠️ No revision — Create one to start production` | [Create Revision] |
| Publishing | `⏳ Publishing revision...` | Disabled |

**Visual Examples:**

```
┌─────────────────────────────────────────────────────────────┐
│ ● Rev 2.0 Active                                    ✓ Clean │
│   Published 2025-11-12 • 12 active jobs                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ ⚠️ Draft Changes Detected                    [Publish Now →]│
│   Rev 2.0 Active • 3 pending changes                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ ⚠️ No Revision                         [Create Revision →] │
│   This product cannot be used in production yet             │
└─────────────────────────────────────────────────────────────┘
```

---

### 3.7 Action Footer

**Context-aware footer with primary actions.**

| Context | Primary Action | Secondary Actions |
|---------|----------------|-------------------|
| General tab, no changes | Save (disabled) | — |
| Structure tab, changes | Save Draft | Discard |
| Structure tab, diverged | Publish Revision | Save Draft, Discard |
| Revisions tab, draft exists | Publish Revision | Delete Draft |

**Visual:**
```
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  [Discard Changes]                    [Save Draft] [Publish]│
│                                        secondary    primary  │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. UX Flow Examples

### 4.1 Flow: Editing a Product Already in Production

**Scenario:** User wants to change a component for a product that has active jobs.

```
1. User opens Product Workspace for "Classic Leather Tote"

   ┌─────────────────────────────────────────────────────┐
   │ ● Rev 2.0 Active — No pending changes       ✓ Clean │
   └─────────────────────────────────────────────────────┘

2. User navigates to Structure tab

3. User modifies "lining" component quantity

4. System immediately detects divergence:

   ┌─────────────────────────────────────────────────────┐
   │ ⚠️ Draft Changes Detected              [Publish →] │
   │   Rev 2.0 Active • 1 pending change                 │
   └─────────────────────────────────────────────────────┘

5. User clicks [Publish →]

6. System shows confirmation:

   ┌─────────────────────────────────────────────────────┐
   │ Publish Revision 3.0?                               │
   │                                                      │
   │ This will:                                          │
   │ • Create Rev 3.0 with your changes                  │
   │ • Make Rev 3.0 the active revision                  │
   │ • New jobs will use Rev 3.0                         │
   │ • Existing jobs (12) will continue with Rev 2.0    │
   │                                                      │
   │ [Cancel]                    [Publish Revision 3.0] │
   └─────────────────────────────────────────────────────┘

7. User confirms

8. System publishes, status bar updates:

   ┌─────────────────────────────────────────────────────┐
   │ ● Rev 3.0 Active — Just published          ✓ Clean │
   └─────────────────────────────────────────────────────┘
```

**Key UX Points:**
- User never left the workspace
- System guided every step
- No modal ping-pong
- Clear impact explanation

---

### 4.2 Flow: Creating a New Revision (From Scratch)

**Scenario:** Product has no revision yet.

```
1. User opens Product Workspace

   ┌─────────────────────────────────────────────────────┐
   │ ⚠️ No Revision                   [Create Revision →]│
   │   This product cannot be used in production yet     │
   └─────────────────────────────────────────────────────┘

2. User configures Structure tab (components, constraints)

3. User configures Production tab (graph binding)

4. User clicks [Create Revision →] from status bar

5. System validates:
   ✓ At least 1 component
   ✓ Graph version selected
   ✓ Constraints schema valid

6. System creates Rev 1.0 as DRAFT

7. User clicks [Publish] in footer

8. System publishes Rev 1.0:

   ┌─────────────────────────────────────────────────────┐
   │ ● Rev 1.0 Active                            ✓ Clean │
   │   Published just now • Ready for production         │
   └─────────────────────────────────────────────────────┘
```

---

### 4.3 Flow: Publishing a Revision

**Scenario:** User has made changes and wants to publish.

```
1. User has draft changes (status bar shows warning)

2. User clicks [Publish Revision] in footer

3. System performs pre-flight checks:

   ┌─────────────────────────────────────────────────────┐
   │ Pre-Publish Validation                              │
   │                                                      │
   │ ✓ Components valid (5 items)                        │
   │ ✓ Constraints schema v1.3                           │
   │ ✓ Graph version H-v4.0 exists                       │
   │ ✓ Invariants preserved (SKU, UOM unchanged)         │
   │                                                      │
   │ Ready to publish Rev 3.0                            │
   │                                                      │
   │ [Cancel]                    [Confirm & Publish]    │
   └─────────────────────────────────────────────────────┘

4. User confirms

5. System:
   - Builds runtime snapshot
   - Sets Rev 3.0 as published
   - Retires Rev 2.0 (allow_new_jobs = 0)
   - Updates product.active_revision_id

6. Success feedback:

   ┌─────────────────────────────────────────────────────┐
   │ ✓ Rev 3.0 Published Successfully                   │
   │                                                      │
   │ New jobs will now use Rev 3.0                       │
   │ 12 existing jobs continue with Rev 2.0             │
   └─────────────────────────────────────────────────────┘
```

---

### 4.4 Flow: Viewing Lock Reason

**Scenario:** User wants to understand why a revision is locked.

```
1. User navigates to Revisions tab

2. User sees Rev 2.0 with 🔒 icon

3. User clicks on Rev 2.0 card

4. System expands lock details:

   ┌─────────────────────────────────────────────────────┐
   │ ● Rev 2.0 [PUBLISHED] 🔒 Active                     │
   │                                                      │
   │ ▼ Lock Details                                      │
   │   ─────────────────────────────────────────         │
   │   Status: IMMUTABLE                                 │
   │   Reason: Referenced by runtime entities            │
   │                                                      │
   │   References:                                       │
   │   • 12 active jobs (in_progress)                   │
   │   • 34 flow tokens (active)                        │
   │   • First referenced: 2025-11-12 14:30             │
   │                                                      │
   │   This revision cannot be:                          │
   │   ✗ Modified                                        │
   │   ✗ Deleted                                         │
   │   ✓ Retired (after new revision published)         │
   │                                                      │
   │   [View Snapshot JSON]                              │
   └─────────────────────────────────────────────────────┘
```

---

## 5. Migration Strategy

### 5.1 Current Modal → New Tab Mapping

| Current Location | New Location | Notes |
|------------------|--------------|-------|
| Edit Product Modal (general fields) | **General tab** | Direct mapping |
| Edit Product Modal → Version Control section | **Revisions tab** | Promoted to first-class tab |
| Constraints Modal | **Structure tab** | Embedded inline |
| Graph Binding Dropdown (in product list) | **Production tab** | Full workspace context |
| Components Modal | **Structure tab** | Embedded inline |

### 5.2 Reusable Components

| Component | Reuse Status | Notes |
|-----------|--------------|-------|
| Product form fields | ✅ Reuse | Move to General tab |
| Constraints editor | ✅ Reuse | Embed in Structure tab |
| Component table | ✅ Reuse | Embed in Structure tab |
| Graph selector dropdown | ✅ Reuse | Enhance with version display |
| Revision list renderer | ✅ Reuse | Promote to Revisions tab |
| Revision action buttons | ✅ Reuse | Add to footer + Revisions tab |

### 5.3 Deprecated Patterns

| Pattern | Status | Replacement |
|---------|--------|-------------|
| Separate Edit Modal | 🚫 Deprecated | Product Workspace |
| Nested Constraints Modal | 🚫 Deprecated | Inline in Structure tab |
| Separate Graph Binding UI | 🚫 Deprecated | Production tab |
| Hidden Version Control section | 🚫 Deprecated | Revisions tab (prominent) |

### 5.4 Incremental Implementation Path

```
Phase 1: Workspace Shell
├── Create tabbed container
├── Migrate General tab (existing form)
└── Keep other modals temporarily

Phase 2: Structure Tab
├── Inline Components table
├── Inline Constraints editor
└── Divergence detection logic

Phase 3: Production Tab
├── Graph version selector
├── Binding comparison UI
└── Preview placeholder

Phase 4: Revisions Tab
├── Migrate revision list
├── Lock reason display
└── Lifecycle actions

Phase 5: Status Bar & Footer
├── Sticky revision bar
├── Context-aware footer
└── Deprecate old modals
```

---

## 6. Guardrails & Safety Design

### 6.1 Preventing Illegal Operations

| Illegal Operation | How UX Prevents |
|-------------------|-----------------|
| Editing immutable revision | Field disabled + lock icon + explanation |
| Deleting referenced revision | Button disabled + tooltip "Referenced by X jobs" |
| Publishing without components | Validation gate + error message |
| Modifying SKU after creation | Field disabled + "Invariant" label |
| Retiring active revision without replacement | Confirmation dialog + warning |

### 6.2 Explaining Immutability

**Language patterns (use consistently):**

| Scenario | Message |
|----------|---------|
| Revision locked | "This revision is used by production and cannot be modified." |
| Why create new revision | "Changes require a new revision to preserve job history." |
| Active vs Draft | "Production uses the Active revision. Draft changes are not visible to production." |

### 6.3 Error Handling

**All errors must include:**
1. What went wrong
2. Why it happened
3. What to do next

**Example:**
```
┌─────────────────────────────────────────────────────────────┐
│ ❌ Cannot Publish Revision                                  │
│                                                              │
│ Reason: No graph version selected                           │
│                                                              │
│ Fix: Go to Production tab and select a graph version.       │
│                                                              │
│ [Go to Production Tab]                           [Dismiss] │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Implementation Phases

### Phase 1: Foundation (Week 1-2)

**Goal:** Workspace shell with tab navigation

**Tasks:**
- [ ] Create `ProductWorkspace` component/template
- [ ] Implement tab container with routing
- [ ] Migrate General tab content
- [ ] Keep legacy modals functional (parallel operation)

**Success Criteria:**
- User can open Product Workspace
- General tab shows product fields
- Saving works as before

---

### Phase 2: Structure Integration (Week 2-3)

**Goal:** Components and Constraints inline

**Tasks:**
- [ ] Migrate Components table to Structure tab
- [ ] Migrate Constraints editor to Structure tab
- [ ] Implement divergence detection
- [ ] Add warning banner UI

**Success Criteria:**
- Components editable in Structure tab
- Constraints editable inline
- Divergence warning appears when changes made

---

### Phase 3: Production Tab (Week 3-4)

**Goal:** Graph binding with version awareness

**Tasks:**
- [ ] Create Production tab layout
- [ ] Implement graph version selector
- [ ] Add current vs selected comparison
- [ ] Wire to revision creation flow

**Success Criteria:**
- Graph version selectable
- Change detection works
- Flow to create revision available

---

### Phase 4: Revisions Tab (Week 4-5)

**Goal:** Full governance visibility

**Tasks:**
- [ ] Migrate revision list to tab
- [ ] Add lock reason expandable details
- [ ] Implement lifecycle action buttons
- [ ] Add snapshot viewer (modal)

**Success Criteria:**
- All revisions visible with status
- Lock reasons explained
- Publish/Retire/Delete work from tab

---

### Phase 5: Polish & Deprecation (Week 5-6)

**Goal:** Complete transition, remove legacy

**Tasks:**
- [ ] Implement Sticky Status Bar
- [ ] Implement Context-Aware Footer
- [ ] Deprecate old modals
- [ ] User testing & refinement

**Success Criteria:**
- Status bar always visible
- Footer actions context-aware
- Legacy modals removed
- Zero user confusion in testing

---

## 8. Anti-Patterns (Explicitly Rejected)

### ❌ NEVER DO THESE:

| Anti-Pattern | Why It's Rejected |
|--------------|-------------------|
| **Multiple nested modals** | Creates cognitive overhead, loses context |
| **Hidden revision actions** | Critical governance should be prominent |
| **Requiring user memory** | "Save, close, reopen, find, click" = error-prone |
| **Blocking errors without guidance** | User stuck = user angry |
| **Mixing governance with form fields** | Revision is not a text input |
| **Silent state changes** | User must always know current state |
| **Modal ping-pong** | 3+ modals for one workflow = UX failure |
| **Admin override backdoors** | Governance is governance, no exceptions |

---

## 9. Quality Validation Checklist

### Before shipping, validate:

**First-Time User Test:**
- [ ] Can complete "create product → publish revision" without help
- [ ] Understands what a revision is from UI alone
- [ ] Cannot accidentally skip required steps

**Power User Test:**
- [ ] Faster workflow than current multi-modal system
- [ ] All actions reachable within 2 clicks
- [ ] Keyboard navigation works

**Edge Case Test:**
- [ ] Product with no revision → clear guidance
- [ ] Product in production → clear lock explanation
- [ ] Concurrent edit attempt → graceful conflict handling

**Apple UX Test:**
- [ ] Zero dead ends
- [ ] Zero hidden critical actions
- [ ] Zero unexplained states
- [ ] Every error has a next action

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **Product** | Identity container for a manufactured item |
| **Revision** | Frozen, immutable specification snapshot |
| **Draft** | Uncommitted changes not yet affecting production |
| **Published** | Active revision used by new jobs |
| **Retired** | No longer used for new jobs, but referenced by historical jobs |
| **Divergence** | Difference between current edits and active revision |
| **Snapshot** | Self-contained JSON of all spec data at publish time |
| **Governance** | Rules enforcing data integrity and traceability |

---

## Appendix B: File Structure Suggestion

```
assets/
├── javascripts/
│   └── products/
│       ├── product_workspace.js          # Main workspace controller
│       ├── product_workspace_general.js  # General tab logic
│       ├── product_workspace_structure.js # Structure tab logic
│       ├── product_workspace_production.js # Production tab logic
│       ├── product_workspace_revisions.js # Revisions tab logic
│       ├── product_workspace_status_bar.js # Sticky bar
│       └── product_workspace_footer.js   # Context-aware footer
│
source/
├── pages/
│   └── products.php                      # Updated to load workspace
├── components/
│   └── product_workspace/
│       ├── workspace.php                 # Main template
│       ├── tab_general.php               # General tab template
│       ├── tab_structure.php             # Structure tab template
│       ├── tab_production.php            # Production tab template
│       └── tab_revisions.php             # Revisions tab template
```

---

**Document End**

*This plan is ready for engineering handoff. Implementation should follow phases sequentially, with user testing between phases.*
