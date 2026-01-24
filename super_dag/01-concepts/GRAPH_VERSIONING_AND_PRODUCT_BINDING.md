# Graph Versioning and Product Binding Philosophy

**Status:** 🎯 **CORE CONCEPT** - Fundamental architectural principle  
**Date:** 2025-12-12  
**Category:** Architecture / Data Integrity / ERP Safety

---

## 🧠 Scope: GRAPH ONLY (Primary Focus)

**This document focuses on GRAPH LIFECYCLE only.**

**Out of Scope (for this chapter):**
- ❌ Inventory
- ❌ CUT / Component / Assignment
- ❌ Product / Job / Runtime (mentioned only for context)

**🎯 Primary Goal:**
Make "Graph Design → Save → Publish → View" correct, clear, and unambiguous.

**Why Graph First?**
If the graph lifecycle is not clean, the entire system will break.

---

## Executive Summary

**The Golden Rule:** When a graph is Published, subsequent edits must **NOT** affect products that are already bound to it.

This is not a feature request—it is a **non-negotiable requirement** for any production ERP system. Violating this rule leads to:
- Production line chaos
- QC failures
- WIP breakdown
- Worker confusion
- Traceability corruption
- Audit trail invalidation

---

## 1. The Problem Statement (GRAPH ONLY)

### 1.1 Current Graph Lifecycle Problems

**The graph system currently has problems at conceptual, UX, and API levels:**

**1. User doesn't know:**
- Whether they're editing Draft or Published
- What version they're viewing

**2. Save behavior is ambiguous:**
- Sometimes acts like "Save Draft"
- Sometimes acts like "Save over Published"
- No clear distinction

**3. No version history:**
- Cannot view old versions
- Cannot compare versions

**4. API confusion:**
- Save / Validate / Autosave / Node Update are mixed together
- Context is unclear

**5. Graph has no clear lifecycle:**
- No clear Draft → Published → Retired flow
- UI doesn't communicate state to users

**Result:** Graph lifecycle is broken, causing confusion and potential production issues.

### 1.2 What "Save" Should Mean (Clear Definition)

| Action | Result |
|--------|--------|
| **Save (while Draft)** | Save to Draft |
| **Save (while Published)** | ❌ **FORBIDDEN** → Must Create Draft first |
| **Publish** | Create new Published Version |
| **Edit after Publish** | Must create new Draft always |

**Key Rule:** `Save ≠ Publish` (must be clearly separated in UI and API)

**If UI still makes users think these are the same thing = FAIL**

---

## 2. The Correct Model (Iron Law) — GRAPH ONLY

### 2.1 Terminology (Critical - Prevents Confusion)

**Graph-Level Status:**
- **Active** = Graph is in use (shown in list)
- **Archived** = Graph is soft-deleted (hidden from list, but data preserved)

**Version-Level Status:**
- **Draft** = Editable workspace (not published)
- **Published** = Immutable snapshot (can be used for new jobs)
- **Retired** = Published snapshot that remains viewable but disallowed for new jobs (`allow_new_jobs=0`)

**Key Distinction:**
- **Archived (Graph)** = Soft-deleted graph (entire graph hidden)
- **Retired (Version)** = Old published version (still viewable, but not for new jobs)

**Why This Matters:**
Using "Archived" for both Graph and Version causes confusion. They serve different purposes:
- Graph Archived = Entire graph is deleted/hidden
- Version Retired = Specific version is deprecated but still viewable

### 2.2 Graph Status Hierarchy (Three States Only)

Graphs must have **exactly three states** (no others):

| Status | Meaning | Editable? |
|--------|---------|-----------|
| **Draft** | Workspace | ✅ Yes |
| **Published** | Contract (Immutable) | ❌ No |
| **Retired** | Deprecated (View-only) | ❌ No |

**Note:** "Retired" is for **Version-level** status. Graph-level uses "Active" / "Archived" (soft-deleted).

**Key Principle:** `Published Graph = Production Contract = Immutable`

**This rule MUST NOT be violated.**

### 2.2 Product Binding Model

**❌ FORBIDDEN Pattern:**
```sql
product → graph_id  -- WRONG: Binds to mutable graph
```

**✅ CORRECT Pattern:**
```sql
product → graph_id + graph_version  -- CORRECT: Binds to immutable version
```

**Or even better:**
```sql
product → graph_publish_id  -- CORRECT: Binds to immutable snapshot
```

**Rationale:**
- Product binding is a **production contract**
- It is **NOT** an editor preview
- It must remain stable throughout the product lifecycle

### 2.3 Product Version Selection Policy

**✅ ALLOWED: Product can select Published versions**

**But with strict requirements:**

| Requirement | Description |
|-------------|-------------|
| **Published Only** | ✅ Only Published versions (Draft = ❌ FORBIDDEN) |
| **Explicit Action** | ✅ Must be deliberate user action (not default) |
| **Default Behavior** | ✅ Default = Latest Published (auto) |
| **Confirmation Required** | ✅ Must show confirmation dialog |
| **Audit Trail** | ✅ Must log who, when, why |
| **Guard Checks** | ✅ Check for active jobs before allowing change |

**Why This Matters (Real-World Scenarios):**

In real factories, these situations occur:
- **Product A** was produced with Flow v1 (passed QC, stable)
- **Design team** creates Flow v2 (adds nodes, changes sequence)
- **But existing customer orders / lots** must still use v1
- **Or some SKUs** haven't been approved for v2 yet

👉 If Products cannot select versions:
= System forces everything to use latest version, which is **wrong in reality**

**Correct Model:**
```
Graph
 ├─ v1 (Published)
 ├─ v2 (Published)
 └─ v3 (Draft)

Product
 └─ uses Graph v2   ← explicit binding (not "latest")
```

**Key Principle:** Products should bind to **intentionally selected Graph Version**, not "latest Graph".

---

## 3. Graph Designer Must Answer 3 Questions (GRAPH ONLY)

**If the UI cannot answer these questions immediately = UX FAIL**

**The 3 Questions:**

1. **What version am I viewing?**
   - v3 (Draft), v2 (Published), v1 (Retired)
   - Must be visible at all times

2. **Can I edit this version?**
   - Draft = ✅ Yes
   - Published/Retired = ❌ No

3. **Will my actions affect production?**
   - Draft = ❌ No (no production impact)
   - Published = N/A (cannot edit)

**If UI cannot answer these → UX FAILS**

---

## 4. Behavior Specification

### 4.1 Scenario A: Publish → Edit → Save

**User Actions:**
1. Publish graph (creates v1)
2. Edit graph (creates Draft v2)
3. Save draft

**Expected Behavior:**

| Context | What User Sees | Data Source |
|---------|----------------|-------------|
| Product Modal Viewer | **v1 (unchanged)** | Published snapshot |
| Graph Editor | v2 (Draft) | Draft state |
| Version History | v1 (Published), v2 (Draft) | Version table |

**Critical Rule:** Product viewer **MUST** show published version, **NEVER** draft.

### 3.2 Scenario B: Draft v2 → Publish

**User Actions:**
1. Edit draft v2
2. Click "Publish"

**Expected Behavior:**
- System creates **new immutable snapshot** (v2)
- System shows **explicit confirmation dialog:**
  ```
  "You are about to publish a new version (v2).
  
  ⚠️ Important:
  - New products will use v2
  - Existing products will continue using v1
  - Existing products will NOT change automatically"
  ```

**Optional (Advanced):**
- Explicit "Rebind Products" action (requires deliberate user action)
- Version comparison UI before rebinding

---

## 5. Required UX Components (GRAPH DESIGNER ONLY)

### 4.1 Core UX Principle: Answer 3 Questions in 2 Seconds

Graph Designer **MUST** answer these questions immediately:

1. **What version am I viewing?** (v3 Draft, v2 Published, etc.)
2. **Can I edit this version?** (Draft = Yes, Published = No)
3. **Will my edits affect production?** (Draft = No, Published = N/A)

If the UI cannot answer these questions → **UX FAILS**

### 4.2 Version Bar (Critical Missing Component)

**Location:** Below graph name, in header area above Canvas (centered)

**Wireframe - Draft Mode:**
```
┌──────────────────────────────────────────────────────────────┐
│ Graph: Leather Bag – Main Flow                                │
│ Version: v3 (Draft)     Published: v2                         │
│                                                              │
│ [ View Published ]   [ Compare ]   [ Publish Draft ]        │
└──────────────────────────────────────────────────────────────┘
```

**Wireframe - Published Mode:**
```
┌──────────────────────────────────────────────────────────────┐
│ Graph: Leather Bag – Main Flow                                │
│ Version: v2 (Published) 🔒 Read-only                          │
│                                                              │
│ [ Create New Draft ]                                         │
└──────────────────────────────────────────────────────────────┘
```

**Key Principles:**
- **Draft = Editable** (buttons: View Published, Compare, Publish)
- **Published = Read-only** (button: Create New Draft only)
- **Buttons change based on state** (not the same buttons)

**Purpose:**
- Clear visual indication of current state
- Easy access to published version
- Prevent accidental edits to published graphs
- Immediate answer to "What version am I viewing?"

### 4.3 Version Selector (Dropdown)

**Location:** Below Version Bar, as dropdown

**Display:**
```
Version ▼  v3 (Draft) 🟡
          v2 (Published) 🟢
          v1 (Retired) ⚪
```

**Behavior:**
- **Select Draft** → Graph becomes editable, canvas reloads with draft state
- **Select Published/Retired** → Graph becomes read-only, canvas reloads with published/retired state
- **Badge indicators:**
  - 🟡 Draft (editable)
  - 🟢 Published (immutable, can create jobs)
  - ⚪ Retired (view-only, cannot create new jobs)

**Critical Rule:** **Editing is FORBIDDEN when not in Draft mode**

**Navigation Rules:**
- **Switching versions** → Canvas **MUST** reload (cannot keep state)
- **Draft → Published** → Switch to read-only mode, disable all editing controls
- **Published → Draft** → Switch to editable mode, enable editing controls
- **Unsaved changes warning** → If switching away from draft with unsaved changes, show confirmation

**Version List Population:**
- Show all Draft versions (if multiple drafts exist)
- Show all Published versions (sorted by version_number DESC)
- Show all Retired versions (sorted by version_number DESC)
- **Hide Draft versions** in Product Modal context (only show Published)

### 4.4 Publish Dialog (Mandatory)

**Trigger:** User clicks "Publish Draft" button

**Dialog Content:**
```
┌──────────────────────────────────────────────────────────────┐
│ Publish new version (v3)?                                    │
│                                                              │
│ ⚠️ Important:                                                │
│ • New products will use v3                                   │
│ • Existing products will continue using v2                    │
│ • Ongoing production will NOT be affected                    │
│                                                              │
│ [ Publish v3 ]   [ Cancel ]                                   │
└──────────────────────────────────────────────────────────────┘
```

**Post-Publish Behavior:**
1. Draft v3 → Becomes Published v3 (immutable snapshot created)
2. System automatically creates new Draft (v4) for next edits
3. Products bound to v2 remain unchanged
4. Previous published versions remain "published" (not auto-archived)

**Retired Status Rules:**
- **Retired is manual action** (not automatic)
- When v3 is published, v2 remains "published" (not "retired")
- Admin must explicitly retire old versions if needed
- Retired versions are read-only and cannot be used for new jobs (`allow_new_jobs=0`)
- Retired versions remain viewable for audit/history purposes

### 4.5 Save Behavior (Clarified)

| Action | What Happens |
|--------|--------------|
| **Save Draft** | Saves to draft only (no production impact) |
| **Save after Published** | ❌ **FORBIDDEN** - Cannot save over published |
| **Edit Published** | ❌ **FORBIDDEN** - Must click "Create Draft" first |
| **Publish** | Creates new immutable snapshot |

**Key Rule:** `Save ≠ Publish` (must be clearly separated in UI and API)

### 4.6 Graph List Sidebar (Left Panel)

**What to Display:**
- Graph name
- Status badges:
  - `[Published v2]` - Latest published version
  - `[Draft v3]` - Active draft (if exists)

**Example:**
```
Leather Bag – Main Flow
[Published v2] [Draft v3]

Tote Production Flow
[Published v1]
```

**Design Principles:**
- **Show only Active graphs** (not Archived/soft-deleted)
- **Do NOT show all versions** in sidebar (too cluttered)
- **Version history** accessible via Version Selector (top)
- **Badge indicates state**, not full version list
- **Archived graphs** (soft-deleted) go to separate "Archived (Deleted)" page

### 4.7 Context-Aware Viewers

**Product Modal Viewer:**
- **Source:** Published snapshot **ONLY**
- **Behavior:** Read-only, immutable
- **Display:** `Workflow Version: v2 (Published)`
- **Purpose:** Show production contract
- **Critical:** **MUST NOT show Draft** under any circumstances

### 4.8 Product Version Selection UI

**Location:** Product Modal / Product Detail Page

**Default Behavior (90% of users):**
```
Workflow:
Leather Bag – Main Flow
Version: v3 (Latest Published)
```

**Advanced Mode (Explicit Only - Owner/Planner/Admin):**

**UI Example:**
```
Workflow Configuration
────────────────────────
Graph: Leather Bag – Main Flow

Workflow Version:
(•) Latest Published (v3)
( ) Pin specific version

If pinned:
[ v2 ▼ ]  (Published)
```

**Key UX Rules:**
- **Never use "Change version"** → Always use **"Pin version"**
- **Default = Latest Published** (auto, no user action)
- **Pin = Explicit action** (requires confirmation)
- **Draft versions = Hidden** (not shown in dropdown)

**Confirmation Dialog (Mandatory):**

When user selects "Pin version":
```
┌──────────────────────────────────────────────────────────────┐
│ Pin workflow to version v2?                                    │
│                                                              │
│ ⚠️ Important:                                                   │
│ • This product will ALWAYS use v2                              │
│ • Future workflow updates will NOT affect this product         │
│ • Existing production jobs are NOT changed                     │
│                                                              │
│ [ Confirm Pin ]   [ Cancel ]                                  │
└──────────────────────────────────────────────────────────────┘
```

**Version Change Policy:**

| Status | Can Change? | Notes |
|--------|-------------|-------|
| **No jobs created** | ✅ **Yes** | Safe to change |
| **Has Draft jobs** | ⚠️ **Warning** | Show warning, allow with confirmation |
| **Has In-Progress jobs** | ❌ **FORBIDDEN** | Block change, show error |
| **All jobs completed** | ✅ **Yes** | Safe to change (with audit log) |

### 4.9 Version Comparison (Compare Feature)

**Purpose:** Compare differences between versions

**What to Compare:**
- **Nodes:** Added, removed, modified (properties, positions)
- **Edges:** Added, removed, modified (conditions, routing)
- **Config:** Changed graph-level config (qc_policy, assignment rules)

**Display Format:**
```
Comparing v2 (Published) vs v3 (Draft)

Changes:
+ Added: OPERATION4 (operation)
- Removed: OPERATION3 (operation)
~ Modified: OPERATION1 (work_center_code: CUTTING_01 → CUTTING_02)
+ Added Edge: OPERATION2 → OPERATION4
```

**Behavior:**
- Read-only comparison (no editing during compare)
- Side-by-side view or unified diff view
- Highlight changes in canvas (if supported)

**Audit Trail Requirements:**
- Log who changed the version
- Log when it was changed
- Log reason/note (optional but recommended)
- Log previous version (for rollback)

**Graph Editor:**
- **Source:** Draft (if exists) or latest published
- **Behavior:** Editable (only in Draft mode)
- **Purpose:** Design and modify workflows
- **Context:** Design workspace

**Version History Viewer:**
- **Source:** All versions (published + retired)
- **Behavior:** Read-only, comparison mode
- **Purpose:** Audit trail and version comparison

---

## 5. Source of Truth and Resolution Rules

### 5.1 Resolution Rules (Iron Law - Must Be Enforced)

**These rules MUST be enforced at runtime. Violation = system failure.**

#### 5.1.1 Product Viewer Resolution

**Rule:** Product Viewer **MUST** resolve to published snapshot **ONLY**

```php
// CORRECT: Product viewer resolution
function getProductGraphPreview($productId) {
    $binding = getActiveBinding($productId);
    $versionPin = $binding['graph_version_pin'] ?? null;
    
    if ($versionPin === null) {
        // Auto-resolve to latest published
        $graph = getLatestPublishedVersion($binding['id_graph']);
    } else {
        // Resolve to pinned published version
        $graph = getPublishedVersion($binding['id_graph'], $versionPin);
    }
    
    // CRITICAL: Never return draft
    if ($graph['status'] === 'draft') {
        throw new \RuntimeException('Product viewer cannot show draft');
    }
    
    return $graph;  // Immutable published snapshot
}
```

**Enforcement:** Backend validation must reject draft versions in product context.

#### 5.1.2 Graph Designer Resolution

**Rule:** Graph Designer resolves based on draft availability

```php
// CORRECT: Graph designer resolution
function getGraphForDesigner($graphId) {
    $hasActiveDraft = hasActiveDraft($graphId);
    
    if ($hasActiveDraft) {
        // Open draft (editable)
        return getDraft($graphId);
    } else {
        // Open latest published (read-only)
        $published = getLatestPublishedVersion($graphId);
        $published['readonly'] = true;  // Mark as read-only
        return $published;
    }
}
```

**Behavior:**
- **Has Draft** → Open draft (editable)
- **No Draft** → Open latest published (read-only) until user clicks "Create New Draft"

#### 5.1.3 Runtime / Token Execution Resolution

**Rule:** Runtime execution **MUST** use snapshot from job creation

```php
// CORRECT: Runtime resolution
function getGraphForExecution($jobId) {
    $job = getJob($jobId);
    
    // CRITICAL: Use snapshot from job creation
    $graphVersionId = $job['graph_version_id'] ?? $job['graph_publish_id'];
    
    if (!$graphVersionId) {
        throw new \RuntimeException('Job must have graph version snapshot');
    }
    
    // Load immutable snapshot
    return getGraphVersionSnapshot($graphVersionId);
}
```

**Enforcement:**
- Job creation **MUST** snapshot `graph_publish_id` (or `graph_version_id`)
- Runtime execution **MUST** use this snapshot, **NEVER** resolve to latest
- This ensures job execution uses the same workflow throughout its lifecycle

**Why This Matters:**
If runtime doesn't use snapshot → Job started with v1, but mid-execution resolves to v2 → Production chaos

---

## 6. Implementation Requirements

### 5.1 Published Graph Immutability

**Requirement:** Published graphs **MUST** be read-only.

**Implementation Options:**

**Option A: Clone on Publish (Recommended)**
```php
// When publishing:
1. Create immutable snapshot in routing_graph_version
2. Mark original graph as "published" (read-only flag)
3. Create new draft copy for future edits
```

**Option B: Version Table**
```sql
CREATE TABLE routing_graph_version (
    id_version INT PRIMARY KEY,
    id_graph INT NOT NULL,
    version_number INT NOT NULL,
    snapshot_json LONGTEXT NOT NULL,  -- Immutable snapshot
    published_at DATETIME NOT NULL,
    published_by INT NOT NULL,
    UNIQUE KEY (id_graph, version_number)
);
```

### 6.1 Canonical Data Model (Finalized)

**Decision:** Use **Option B (Version Table)** as canonical model

#### 6.1.1 Graph Version Table (Immutable Snapshots)

```sql
CREATE TABLE routing_graph_version (
    id_version INT PRIMARY KEY AUTO_INCREMENT,
    id_graph INT NOT NULL COMMENT 'FK to routing_graph',
    version_number INT NOT NULL COMMENT 'Sequential version (1, 2, 3...)',
    snapshot_json LONGTEXT NOT NULL COMMENT 'Immutable JSON snapshot of nodes/edges',
    config_json LONGTEXT NULL COMMENT 'Graph-level config (qc_policy, assignment rules, etc.)',
    allow_new_jobs TINYINT(1) DEFAULT 1 COMMENT 'Allow creating new jobs with this version (0=disabled, 1=enabled)',
    published_at DATETIME NOT NULL,
    published_by INT NOT NULL,
    version_note VARCHAR(255) NULL COMMENT 'Optional note about this version',
    status ENUM('published', 'retired') NOT NULL DEFAULT 'published' COMMENT 'published=active, retired=deprecated but viewable',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE CASCADE,
    FOREIGN KEY (published_by) REFERENCES account(id_member) ON DELETE RESTRICT,
    
    UNIQUE KEY uq_graph_version (id_graph, version_number),
    INDEX idx_graph_status (id_graph, status),
    INDEX idx_published_at (published_at),
    INDEX idx_allow_new_jobs (allow_new_jobs)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Immutable snapshots of published graph versions';
```

**`allow_new_jobs` Field:**
- **Purpose:** Control whether new jobs can be created using this version
- **Default:** `1` (enabled) for new published versions
- **Retired versions:** Should default to `0` (disabled)
- **Behavior:**
  - `allow_new_jobs = 1` → Can create new jobs with this version
  - `allow_new_jobs = 0` → Cannot create new jobs (existing jobs continue running)
- **Migration:** Replaces legacy `RUNTIME_ENABLED` feature flag (see `RUNTIME_ENABLED_AUDIT_AND_MIGRATION.md`)

**Snapshot Content (`snapshot_json`):**
```json
{
    "nodes": [
        {
            "id_node": 123,
            "node_code": "OPERATION1",
            "node_type": "operation",
            "work_center_code": "CUTTING_01",
            "team_category": "cutting",
            "estimated_minutes": 30,
            "position": { "x": 100, "y": 200 },
            "node_config": { /* ... */ },
            "qc_policy": { /* ... */ }
        }
    ],
    "edges": [
        {
            "id_edge": 456,
            "from_node_code": "START1",
            "to_node_code": "OPERATION1",
            "edge_type": "normal"
        }
    ],
    "metadata": {
        "graph_id": 789,
        "graph_code": "BAG_PROD_FLOW",
        "snapshot_at": "2025-12-12 10:00:00"
    }
}
```

**Config Content (`config_json`):**
```json
{
    "graph_level_config": {
        "default_assignment_policy": "auto",
        "default_wip_limit": 10
    },
    "execution_config": {
        "parallel_split_policy": "ALL",
        "merge_policy": "ALL"
    }
}
```

#### 6.1.2 Product Binding Schema (Updated)

```sql
CREATE TABLE product_graph_binding (
    id_binding INT PRIMARY KEY AUTO_INCREMENT,
    id_product INT NOT NULL,
    id_graph INT NOT NULL,
    graph_version_id INT NULL COMMENT 'FK to routing_graph_version (NULL = latest published)',
    pinned_by INT NULL,
    pinned_at DATETIME NULL,
    note TEXT NULL,
    is_active TINYINT(1) DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (id_product) REFERENCES product(id_product) ON DELETE CASCADE,
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE RESTRICT,
    FOREIGN KEY (graph_version_id) REFERENCES routing_graph_version(id_version) ON DELETE RESTRICT,
    FOREIGN KEY (pinned_by) REFERENCES account(id_member) ON DELETE SET NULL,
    
    INDEX idx_product (id_product),
    INDEX idx_graph (id_graph),
    INDEX idx_version (graph_version_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Product binding to graph versions (immutable snapshots)';
```

**Behavior Rules:**
- `graph_version_id = NULL` → Auto-resolve to latest published version
- `graph_version_id = 123` → Lock to specific version (explicit pin)
- **Draft versions = NOT ALLOWED** (FK constraint + validation)

#### 6.1.3 Job Snapshot Schema

```sql
CREATE TABLE job_ticket (
    id_job_ticket INT PRIMARY KEY AUTO_INCREMENT,
    -- ... other fields ...
    graph_version_id INT NOT NULL COMMENT 'FK to routing_graph_version (snapshot at job creation)',
    -- ... other fields ...
    
    FOREIGN KEY (graph_version_id) REFERENCES routing_graph_version(id_version) ON DELETE RESTRICT
) ENGINE=InnoDB;
```

**Critical Rule:** Job **MUST** snapshot `graph_version_id` at creation time. This ensures job execution uses the same workflow throughout its lifecycle.

### 6.2 Product Binding Schema (Legacy Compatibility)

**Note:** If `graph_version_pin VARCHAR(10)` exists for backward compatibility:
- Map `graph_version_pin = 'v2'` → Resolve to `routing_graph_version` where `version_number = 2`
- Map `graph_version_pin = NULL` → Resolve to latest published version
- **Migration path:** Gradually migrate to `graph_version_id` FK

### 6.3 Editor Persistence Contract

**Problem:** Current system confuses different types of saves, leading to errors like "Cannot resolve node IDs for edge..."

**Solution:** Define clear contracts for each save operation.

#### 6.3.0 Save Operations Overview (Clear Contracts)

**🔒 MANDATORY: Each operation has a clear, non-overlapping contract.**

| Operation | Endpoint | Scope | Source of Truth | Validation | Version Impact |
|-----------|----------|-------|-----------------|------------|----------------|
| **Node Properties Update** | `node_update_properties` | Single node config | UI payload + DB merge (node config only) | Node-level only | No version change |
| **Autosave** | `graph_autosave` | Positions/viewport | UI payload + DB merge (positions only) | Minimal (syntax) | No version change |
| **Full Graph Save** | `graph_save_draft` | Entire graph (nodes + edges) | **UI payload ONLY** (no DB merge) | Full graph validation | Draft version only |
| **Validate Design** | `graph_validate_design` | Entire graph (nodes + edges) | **UI payload ONLY** (no DB merge) | Full graph validation | No save, validation only |
| **Publish** | `graph_publish` | Entire graph → snapshot | Current draft state (from DB) | Full graph validation | Creates Published version |

**🔒 Critical Rules:**
1. **graph_save_draft / graph_validate_design:** NEVER merge DB, use payload only
2. **node_update_properties / graph_autosave:** CAN merge DB (limited scope)
3. **Each operation has ONE clear purpose** - do not mix contexts

**Why This Matters:**
Mixing contexts (e.g., calling graph_save from node_update) = API context mismatch = validation errors, node ID resolution failures

#### 6.3.1 Save Operations (Defined)

| Operation | Endpoint | Scope | Validation | Use Case |
|-----------|----------|-------|------------|----------|
| **Full Graph Save** | `graph_save_draft` | Entire graph (nodes + edges) | Full graph validation (design/publish context) | User clicks "Save" button |
| **Autosave** | `graph_autosave` | Positions + lightweight merge | Minimal validation | Drag node, auto-save positions |
| **Node Properties Update** | `node_update_properties` | Single node properties | Node-level validation only | Edit node properties in panel |

#### 6.3.2 Full Graph Save (`graph_save_draft`)

**Purpose:** Save complete graph state (nodes + edges)

**Behavior:**
```php
// CORRECT: Full graph save
function graph_save_draft($graphId, $nodes, $edges, $context = 'design') {
    // Check if graph is published
    $graph = getGraph($graphId);
    
    if ($graph['status'] === 'published') {
        // Published graph → Save to draft table
        saveToDraft($graphId, $nodes, $edges);
    } else {
        // Draft graph → Save to main graph
        saveToGraph($graphId, $nodes, $edges);
    }
    
    // Full graph validation
    $validation = validateGraph($nodes, $edges, $context);
    if (!$validation['valid']) {
        return ['ok' => false, 'errors' => $validation['errors']];
    }
    
    // Save
    persistGraph($graphId, $nodes, $edges);
}
```

**Validation:** Full graph validation (structure, reachability, semantic rules)

#### 6.3.3 Autosave (`graph_autosave`)

**Purpose:** Save positions and lightweight changes (safe, non-destructive)

**Behavior:**
```php
// CORRECT: Autosave (safe)
function graph_autosave($graphId, $positions, $lightweightChanges = []) {
    // Only save positions and safe changes
    // Do NOT validate full graph (too expensive)
    // Do NOT save if graph is published (must create draft first)
    
    $graph = getGraph($graphId);
    if ($graph['status'] === 'published') {
        return ['ok' => false, 'error' => 'Cannot autosave published graph'];
    }
    
    // Merge positions into existing draft
    mergePositions($graphId, $positions);
    
    // Optional: Merge lightweight changes (e.g., node labels)
    if (!empty($lightweightChanges)) {
        mergeLightweightChanges($graphId, $lightweightChanges);
    }
}
```

**What Autosave Can Do:**
- ✅ Save node positions (x, y coordinates)
- ✅ Save lightweight changes (node labels, edge labels)
- ✅ Merge with existing draft (non-destructive)

**What Autosave Cannot Do:**
- ❌ Full graph validation
- ❌ Save to published graph
- ❌ Save structural changes (add/remove nodes/edges)

#### 6.3.4 Node Properties Update (`node_update_properties`)

**Purpose:** Update single node properties without full graph save

**🔒 Source of Truth Rule:**
- **Properties come from UI payload**
- **CAN merge with DB** (node config only, not graph structure)
- **DO NOT** load/validate entire graph

**Behavior:**
```php
// CORRECT: Node properties update
function node_update_properties($nodeId, $properties, $context = 'design') {
    // ✅ Get current node from DB (for merge)
    $node = getNode($nodeId);
    $graph = getGraph($node['id_graph']);
    
    // Check if graph is published
    if ($graph['status'] === 'published') {
        return ['ok' => false, 'error' => 'Cannot update published graph'];
    }
    
    // ✅ Merge properties (node config merge is allowed)
    $updatedNode = array_merge($node, $properties);
    
    // Node-level validation only (NOT full graph validation)
    $validation = validateNodeProperties($updatedNode, $context);
    if (!$validation['valid']) {
        return ['ok' => false, 'errors' => $validation['errors']];
    }
    
    // Update node only (no graph-level validation)
    updateNode($nodeId, $updatedNode);
    
    // Save to draft (if not already draft)
    if ($graph['status'] !== 'draft') {
        ensureDraftExists($graph['id_graph']);
    }
}
```

**Validation:** Node-level validation only (e.g., `work_center_code` required on publish)

**🔒 Critical Rules:**
1. **MUST NOT** trigger full graph validation
2. **MUST NOT** trigger edge resolution
3. **MUST NOT** call `graph_save` or `graph_validate_design`
4. **ONLY** validates node properties, not graph structure

#### 6.3.5 Save Behavior After Publish

**Current (Incorrect):**
```
Publish → Edit → Save = Updates published graph ❌
```

**Required (Correct):**
```
Publish → Edit → Save = Saves to draft only ✅
```

**🔒 UX Outcome (MANDATORY - Must Be Clear to User):**

**When user clicks "Save" while viewing Published graph:**

**Step 1: Show Confirmation Modal**
```
┌──────────────────────────────────────────────────────────────┐
│ Create new Draft from v2 (Published)?                        │
│                                                              │
│ This will create a new Draft version (v3) based on the      │
│ current Published version (v2).                             │
│                                                              │
│ ⚠️ Important:                                                │
│ • Published version v2 will remain unchanged                 │
│ • New Draft v3 will be created for editing                   │
│ • Product bindings will continue using v2                    │
│                                                              │
│ [ Create Draft ]   [ Cancel ]                                │
└──────────────────────────────────────────────────────────────┘
```

**Step 2: After User Confirms**
- Create new Draft (v3) based on current Published state
- Switch UI to Draft mode immediately
- Show badge: "v3 (Draft) 🟡"
- Enable all editing controls
- Show success message: "Draft v3 created from Published v2"

**Step 3: User Experience**
- User can now edit Draft v3
- Published v2 remains untouched
- Product bindings unaffected

**Implementation:**
- Check graph status before save
- If `status = 'published'` → Show confirmation modal → Create draft → Switch to draft
- If `status = 'draft'` → Save to graph directly (no modal)

**🔒 Critical Rule:** User MUST explicitly confirm before Draft creation from Published

---

## 6. Minimum Safe Fix (Incremental Approach)

If full versioning system is not yet implemented, implement these **minimum safety measures**:

### 6.1 Freeze Published Graphs

**Action:** Make published graphs read-only in editor

**Implementation:**
```php
// In graph_designer.js
if (graphStatus === 'published') {
    disableEditing();
    showMessage('This graph is published. Create a new draft to make changes.');
}
```

### 6.2 Product Viewer Isolation

**Action:** Product viewer **MUST** read from published snapshot only

**Implementation:**
```php
// In product_graph_binding.js or API
function getProductGraphPreview($productId) {
    $binding = getActiveBinding($productId);
    $version = $binding['graph_version_pin'] ?? 'latest';
    
    // CRITICAL: Always resolve to published version
    $graph = getPublishedGraphVersion($binding['id_graph'], $version);
    return $graph;  // Immutable snapshot
}
```

### 6.3 Draft Save Separation

**Action:** Save after publish creates draft, not updates published

**Implementation:**
```php
// In graph save logic
if ($graphStatus === 'published') {
    // Save to draft table, not main graph
    saveToDraft($graphId, $nodes, $edges);
} else {
    // Save to main graph (draft mode)
    saveToGraph($graphId, $nodes, $edges);
}
```

### 6.4 Version Display

**Action:** Show version information in UI

**Implementation:**
- Add version bar to graph designer
- Show "Published: v2" vs "Draft: v3"
- Prevent confusion about which version is being edited

---

## 7. Anti-Patterns (What NOT to Do)

### 7.1 ❌ Mutable Published Graphs

**Anti-Pattern:**
```php
// WRONG: Allowing edits to published graphs
if ($graphStatus === 'published') {
    updateGraph($graphId, $nodes, $edges);  // ❌ DANGEROUS
}
```

**Why It's Dangerous:**
- Products bound to graph will see changes
- Production contracts are violated
- Traceability is broken

### 7.2 ❌ Product Binding to Graph ID Only

**Anti-Pattern:**
```sql
-- WRONG: Binding without version
product_graph_binding (
    id_product,
    id_graph  -- ❌ No version pinning
)
```

**Why It's Dangerous:**
- Product always sees "latest" graph state
- Published edits affect production
- No immutability guarantee

### 7.3 ❌ Draft Viewer in Production Context

**Anti-Pattern:**
```php
// WRONG: Showing draft in product modal
$graph = getGraph($graphId);  // Gets latest (may be draft)
showInProductModal($graph);  // ❌ Shows draft to production
```

**Why It's Dangerous:**
- Production sees unfinished work
- Confusion about actual production workflow
- Risk of using incorrect workflow

### 7.4 ❌ Product Version Selection Anti-Patterns

**❌ FORBIDDEN Behaviors:**

1. **Product selects Draft version**
   ```php
   // WRONG: Allowing draft selection
   if ($version === 'draft') {
       allowSelection();  // ❌ FORBIDDEN
   }
   ```

2. **Auto-switch on new publish**
   ```php
   // WRONG: Auto-updating product binding
   if (newVersionPublished) {
       updateAllProductBindings();  // ❌ FORBIDDEN
   }
   ```

3. **Silent version change**
   ```php
   // WRONG: Changing without confirmation
   changeProductVersion($productId, $newVersion);  // ❌ No confirmation
   ```

4. **Change during active jobs**
   ```php
   // WRONG: Allowing change with active jobs
   if (hasActiveJobs($productId)) {
       allowVersionChange();  // ❌ FORBIDDEN
   }
   ```

5. **No audit trail**
   ```php
   // WRONG: Changing without logging
   updateBinding($productId, $newVersion);  // ❌ No audit log
   ```

**Why These Are Dangerous:**
- Production contracts are violated
- Traceability is broken
- No accountability for changes
- Risk of using wrong workflow in production

---

## 8. Migration Path

### 8.1 Phase 1: Safety Measures (Immediate)

**Priority:** 🔴 **CRITICAL**

1. ✅ Make published graphs read-only in editor
2. ✅ Ensure product viewer reads from published version only
3. ✅ Add version display in UI
4. ✅ Separate draft save from published graph

**Timeline:** 1-2 days

### 8.2 Phase 2: Version System (Short-term)

**Priority:** 🟡 **HIGH**

1. Implement `routing_graph_version` table
2. Create immutable snapshots on publish
3. Update product binding to use version pins
4. Add version comparison UI

**Timeline:** 1-2 weeks

### 8.3 Phase 3: Full Versioning (Long-term)

**Priority:** 🟢 **MEDIUM**

1. Version history viewer
2. Diff/compare functionality
3. Rollback capabilities
4. Version-based rebinding UI

**Timeline:** 1-2 months

---

## 9. Testing Requirements

### 9.1 Critical Test Cases

**Test 1: Published Graph Immutability**
```
1. Publish graph v1
2. Attempt to edit graph
3. Verify: Edit is blocked or saved to draft
4. Verify: Product viewer still shows v1
```

**Test 2: Product Binding Stability**
```
1. Bind product to graph v1
2. Edit graph (create draft v2)
3. Save draft
4. Verify: Product viewer shows v1 (unchanged)
```

**Test 3: New Version Publishing**
```
1. Publish graph v1
2. Create draft v2
3. Publish v2
4. Verify: New products can use v2
5. Verify: Existing products still use v1
```

---

## 10. References

### 10.1 Related Documents

- `docs/super_dag/01-concepts/PRODUCT_COMPONENT_ARCHITECTURE.md`
- `docs/dag/05-implementation-status/DAG_IMPLEMENTATION_ROADMAP.md`
- `docs/developer/05-database/01-schema-reference.md`

### 10.2 Code Locations

- Product Binding: `source/BGERP/Helper/ProductGraphBindingHelper.php`
- Graph Service: `source/dag/Graph/Service/GraphService.php`
- Graph Repository: `source/dag/Graph/Repository/GraphRepository.php`
- Product API: `source/product_api.php`

---

## 11. Conclusion

**The Bottom Line:**

> **Published graphs are production contracts. They must be immutable.**
>
> **Product bindings are commitments. They must reference immutable versions.**
>
> **Any system that allows published graph edits to affect production is fundamentally broken.**

This is not negotiable. This is ERP 101.

---

## 12. Product Version Selection Summary

**The Bottom Line:**

✅ **Product CAN select Published versions**  
❌ **Product CANNOT select Draft versions**  
✅ **Default = Latest Published (auto)**  
✅ **Pin = Explicit action (with confirmation + audit)**

**Key Principles:**
- **Default behavior** = Latest Published (90% of users)
- **Advanced behavior** = Pin version (explicit, requires permission)
- **Draft = FORBIDDEN** (never shown, never selectable)
- **Confirmation required** (mandatory dialog)
- **Audit trail required** (who, when, why)
- **Guard checks required** (block if active jobs exist)

**What "Pin Version" Means:**
- Product will **ALWAYS** use the pinned version
- Future workflow updates will **NOT** affect this product
- This is a **deliberate choice**, not automatic

**What "Latest Published" Means:**
- Product uses the most recent published version
- When new version is published, product automatically uses it
- This is the **default behavior** for most products

---

## 7. Rebind Policy (Critical for Production Safety)

### 7.1 Rebind Definition

**Rebind = Explicit action to change product's graph version binding**

**Key Principle:** Rebind is **ALWAYS** a separate action from Publish. Publishing a new version does **NOT** automatically rebind existing products.

### 7.2 Rebind Scope Options

**Rebind must specify scope:**

| Scope | Description | Use Case |
|-------|-------------|----------|
| **Single Product** | Rebind only this product | Product-specific workflow change |
| **Multiple Products** | Rebind selected products | Batch update for related SKUs |
| **All Products (Graph)** | Rebind all products using this graph | Graph-wide migration (rare) |

### 7.3 Rebind Guard Rules

**Guard checks (MUST be enforced):**

| Condition | Action | Reason |
|-----------|--------|--------|
| **No jobs created** | ✅ **Allow** | Safe to rebind |
| **Has Draft jobs** | ⚠️ **Warning + Confirmation** | Jobs not started yet, but user should be aware |
| **Has In-Progress jobs** | ❌ **BLOCK** | Cannot change workflow mid-execution |
| **Has Completed jobs** | ✅ **Allow (with option)** | Can rebind, but may affect future jobs only |

**Implementation:**
```php
// CORRECT: Rebind guard checks
function canRebindProduct($productId, $newVersionId) {
    $activeJobs = countActiveJobs($productId);
    $inProgressJobs = countInProgressJobs($productId);
    
    if ($inProgressJobs > 0) {
        return [
            'allowed' => false,
            'reason' => "Cannot rebind: {$inProgressJobs} job(s) in progress"
        ];
    }
    
    if ($activeJobs > 0) {
        return [
            'allowed' => true,
            'warning' => "{$activeJobs} draft job(s) exist. Rebind will affect future jobs only."
        ];
    }
    
    return ['allowed' => true];
}
```

### 7.4 Rebind Effective Date Policy

**Option A: Immediate (Default)**
- Rebind takes effect immediately
- Future jobs use new version
- Existing jobs continue with old version

**Option B: Effective From Date (Advanced)**
- Rebind takes effect from specified date
- Jobs created before date use old version
- Jobs created after date use new version

**Recommendation:** Start with Option A (immediate), add Option B later if needed.

### 7.5 Rebind Confirmation Dialog

**Dialog Content:**
```
┌──────────────────────────────────────────────────────────────┐
│ Rebind product to workflow version v3?                        │
│                                                              │
│ Product: Leather Bag – Main                                   │
│ Current: v2 (Published)                                        │
│ New: v3 (Published)                                            │
│                                                              │
│ ⚠️ Important:                                                  │
│ • Future jobs will use v3                                      │
│ • Existing jobs will continue using v2                         │
│ • {activeJobs} draft job(s) will be affected                   │
│                                                              │
│ [ Confirm Rebind ]   [ Cancel ]                               │
└──────────────────────────────────────────────────────────────┘
```

### 7.6 Rebind Audit Trail

**Required Log Fields:**
- `rebound_by` (user ID)
- `rebound_at` (timestamp)
- `previous_version_id` (for rollback)
- `new_version_id` (target version)
- `reason` (optional note)
- `scope` (single/multiple/all)

---

## 8. Permissions and Audit Events

### 8.1 Permission Codes (RBAC)

**Required Permission Codes:**

| Action | Permission Code | Required Role |
|--------|----------------|--------------|
| **Publish Graph** | `dag_routing.publish` | Planner, Admin |
| **Create Draft** | `dag_routing.edit` | Designer, Planner, Admin |
| **Pin Product Version** | `products.bind_version` | Planner, Admin |
| **Rebind Products** | `products.rebind` | Admin only |
| **View Version History** | `dag_routing.view_history` | All authenticated |
| **Compare Versions** | `dag_routing.compare` | Designer, Planner, Admin |
| **Archive Version** | `dag_routing.archive` | Admin only |

**Implementation:**
```php
// CORRECT: Permission checks
function publishGraph($graphId, $userId) {
    must_allow_routing($userId, 'publish');  // Check permission
    // ... publish logic
}

function pinProductVersion($productId, $versionId, $userId) {
    must_allow_product($userId, 'bind_version');  // Check permission
    // ... pin logic
}
```

### 8.2 Audit Events (Required Logging)

**Audit Event Types:**

| Event | Event Code | Log Fields |
|-------|-----------|------------|
| **Graph Published** | `GRAPH_PUBLISHED` | graph_id, version_number, published_by, published_at |
| **Draft Created** | `DRAFT_CREATED` | graph_id, draft_id, created_by, created_at |
| **Product Version Pinned** | `PRODUCT_VERSION_PINNED` | product_id, graph_id, version_id, pinned_by, pinned_at, reason |
| **Product Version Unpinned** | `PRODUCT_VERSION_UNPINNED` | product_id, graph_id, previous_version_id, unpinned_by, unpinned_at |
| **Product Rebound** | `PRODUCT_REBOUND` | product_id, graph_id, previous_version_id, new_version_id, rebound_by, rebound_at, scope, reason |
| **Job Created with Version** | `JOB_CREATED_WITH_VERSION` | job_id, product_id, graph_id, version_id, created_by, created_at |
| **Version Retired** | `VERSION_RETIRED` | graph_id, version_id, retired_by, retired_at, reason |

**Audit Log Schema:**
```sql
CREATE TABLE routing_audit_log (
    id_log INT PRIMARY KEY AUTO_INCREMENT,
    event_type VARCHAR(50) NOT NULL,
    graph_id INT NULL,
    product_id INT NULL,
    version_id INT NULL,
    job_id INT NULL,
    user_id INT NOT NULL,
    event_data JSON NULL COMMENT 'Additional event-specific data',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_event_type (event_type),
    INDEX idx_graph (graph_id),
    INDEX idx_product (product_id),
    INDEX idx_user (user_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB;
```

**Critical Rule:** All version-related actions **MUST** be logged for audit trail and traceability.

---

## 9. Implementation Task Pack

### 9.1 Phase 1 — Safety Net (Immediate - Stop Damage)

**Priority:** 🔴 **CRITICAL**  
**Timeline:** 3-5 days

**Tasks:**

1. **Product Viewer Isolation**
   - Enforce Product Modal reads from published snapshot only
   - Add validation to reject draft versions in product context
   - Update `ProductGraphBindingHelper::getGraphVersion()` to enforce published-only

2. **Published Read-Only**
   - Disable all editing controls when viewing published graph
   - Show "Create Draft" button only (hide Save, Edit controls)
   - Add visual indicator (🔒 Read-only badge)

3. **Save Routing**
   - Update save logic: If viewing published → Create draft first
   - Update save logic: Save always writes to draft (never overwrites published)
   - Add validation: Block save to published graph

### 9.2 Phase 2 — Versioning Core

**Priority:** 🟡 **HIGH**  
**Timeline:** 1-2 weeks

**Tasks:**

4. **Immutable Snapshot Table**
   - Create `routing_graph_version` table (migration)
   - Define snapshot JSON structure
   - Add indexes and foreign keys

5. **Publish Flow**
   - Implement publish action: Create immutable snapshot
   - Auto-increment version number
   - Auto-create new draft after publish
   - Update graph status to 'published'

6. **Resolver Service**
   - Create `GraphVersionResolver` service
   - Implement `resolveGraphForProduct($productId)`
   - Implement `resolveGraphForJob($jobId)`
   - Enforce resolution rules (Section 5.1)

### 9.3 Phase 3 — UX (Eliminate Confusion)

**Priority:** 🟡 **HIGH**  
**Timeline:** 1-2 weeks

**Tasks:**

7. **Version Bar + Version Selector**
   - Implement Version Bar UI (wireframe from Section 4.2)
   - Implement Version Selector dropdown (Section 4.3)
   - Add version badges (🟡 Draft, 🟢 Published, ⚪ Retired)

8. **History List**
   - Populate version dropdown with all versions
   - Implement version switching (reload canvas)
   - Add read-only mode when viewing published/retired

9. **Publish Dialog**
   - Implement publish confirmation dialog (Section 4.4)
   - Add warning messages
   - Handle post-publish behavior (auto-create draft)

### 9.4 Phase 4 — Product Pin Version

**Priority:** 🟢 **MEDIUM**  
**Timeline:** 1 week

**Tasks:**

10. **UI Pin/Unpin + Guards**
    - Add version pin UI in Product Modal (Section 4.8)
    - Implement guard checks (active jobs)
    - Add confirmation dialog
    - Implement audit logging

11. **Backend Enforcement**
    - Validate pinned version is published (not draft)
    - Update `product_graph_binding` to use `graph_version_id`
    - Add validation in binding API

### 9.5 Phase 5 — Editor Persistence Contract

**Priority:** 🟢 **MEDIUM**  
**Timeline:** 1 week

**Tasks:**

12. **Separate Endpoints**
    - Ensure `node_update_properties` endpoint exists (already implemented)
    - Ensure `graph_save_draft` endpoint exists
    - Ensure `graph_autosave` endpoint exists
    - Define clear contracts (Section 6.3)

13. **Autosave Definition**
    - Define what autosave can do (positions only)
    - Define what autosave cannot do (full graph validation)
    - Implement safe merge logic

### 9.6 Phase 6 — Runtime/Allow New Jobs Migration

**Priority:** 🟡 **HIGH** (Clarifies confusion)  
**Timeline:** 1-2 weeks

**Tasks:**

14. **Migrate Runtime Feature Flag**
    - Add `allow_new_jobs` field to `routing_graph_version` table
    - Migrate existing `RUNTIME_ENABLED` flags to version level
    - Add guard check in `JobCreationService::createDAGJob()`
    - Update UI labels ("Runtime" → "Allow New Jobs")
    - Move toggle to Version Bar (version-level, not graph-level)

15. **Deprecate Legacy Flag**
    - Add deprecation warning to `isGraphRuntimeEnabled()`
    - Keep backward compatibility during transition
    - Remove after migration complete

**Reference:** See `RUNTIME_ENABLED_AUDIT_AND_MIGRATION.md` for detailed migration plan.

---

## 13. Goal of This Chapter (GRAPH ONLY)

**Consider "Graph Lifecycle" complete when:**

✅ **Published Graph is immutable** (cannot be edited)  
✅ **Draft and Published are clearly separated**  
✅ **Save and Publish are clearly separated**  
✅ **Can view old versions**  
✅ **UI doesn't mislead users**  
✅ **APIs don't mix contexts**

**Still not concerned with:**
- ❌ Inventory
- ❌ Component
- ❌ Assignment
- ❌ Product (except binding context)
- ❌ Job (except binding context)
- ❌ Runtime (except binding context)

**If graph is not clean, the entire system will break.**

---

## 14. Key Takeaways for Implementation

**For AI Agents and Developers (GRAPH ONLY Focus):**

**Core Principles:**
1. **Graphs have multiple versions** - Always (v1, v2, v3...)
2. **Published = Immutable Contract** - Never editable
3. **Draft = Workspace** - Only editable state
4. **Graph must have clear lifecycle** - Draft → Published → Retired
5. **UI must communicate state clearly** - Before user clicks
6. **Save ≠ Publish** - Must be clearly separated

**The 3 Questions Graph Designer UI Must Answer:**
1. **What version am I viewing?** (v3 Draft, v2 Published, etc.)
2. **Can I edit this version?** (Draft = Yes, Published = No)
3. **Will my actions affect production?** (Draft = No, Published = N/A)

**If UI cannot answer these → UX FAILS**

**Focus: Graph Lifecycle + Version + Save/Publish UX**

**Do NOT touch:**
- Inventory
- Component
- Assignment

**If graph is not clean, everything else will break.**

**Product Version Selection Rules:**
1. Default = Latest Published (auto, no user action)
2. Pin = Explicit action (requires confirmation + audit)
3. Draft = FORBIDDEN (never shown, never selectable)
4. Active jobs = Block version change
5. All changes = Must be logged (audit trail)

---

**Document Status:** ✅ **READY FOR IMPLEMENTATION**  
**Next Steps:** Implement Phase 1 safety measures immediately
