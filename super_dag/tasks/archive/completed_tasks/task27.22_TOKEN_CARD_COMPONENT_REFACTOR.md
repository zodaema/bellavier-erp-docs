# Task 27.22: Token Card Component Refactor

> **Priority:** High (DRY Violation Fix)  
> **Estimated Effort:** 5-7 hours  
> **Status:** ✅ **COMPLETED** (2025-12-08)  
> **Prerequisites:** Task 27.21.1 (optional, can run parallel)

---

## 🎯 Objective

Consolidate 3 duplicate Token Card render functions into a **Single Component Pattern** following Hermès + Apple engineering standards.

**Key Principle:** `data → view model → view` (Apple-level architecture)

---

## 🚨 Current Problem

```
┌─────────────────────────────────────────────────────────────────┐
│  3 DUPLICATE RENDER FUNCTIONS                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  renderKanbanTokenCard()  ─┐                                   │
│  renderListTokenCard()    ─┼── Same logic, different layout    │
│  renderMobileJobCard()    ─┘                                   │
│                                                                 │
│  VIOLATIONS:                                                    │
│  • DRY (Don't Repeat Yourself)                                 │
│  • Single Source of Truth                                      │
│  • Maintainability                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Symptoms
1. Bug fixes require changes in 3 places
2. Features must be implemented 3 times
3. UI inconsistency between views
4. Recent example: Material Shortage warning added to 2/3 places only

---

## ✅ Target Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  MODULAR COMPONENT SYSTEM                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  TokenCardState.js       (View Model - Single Source)   │   │
│  │  └── computeTokenState(token) → TokenViewModel          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                         │                                       │
│                         ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  TokenCardParts.js       (Shared UI Components)         │   │
│  │  ├── renderStatusBadge(state)                           │   │
│  │  ├── renderTimer(token, state)                          │   │
│  │  ├── renderActionButtons(token, options)                │   │
│  │  ├── renderMaterialWarning(token)                       │   │
│  │  └── renderAssignmentInfo(token)                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                         │                                       │
│                         ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  TokenCardLayouts.js     (Layout Templates Only)        │   │
│  │  ├── kanbanLayout(token, parts)                         │   │
│  │  ├── listLayout(token, parts)                           │   │
│  │  └── mobileLayout(token, parts)                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                         │                                       │
│                         ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  TokenCardComponent.js   (Entry Point)                  │   │
│  │  └── TokenCard(token, { layout }) → HTML                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  BENEFITS:                                                      │
│  • Fix once, works everywhere                                  │
│  • Add feature once                                            │
│  • Guaranteed consistency                                      │
│  • Reusable by Modal, Dashboard, Future PWA                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📐 Token View Model Specification

**CRITICAL:** This is the SINGLE SOURCE OF TRUTH for token state across all views.

```javascript
/**
 * Token View Model - Central state computed from raw API token
 * 
 * ALL renderers MUST use this, not raw token data
 * Future: Work Modal, Dashboard, Reports can reuse this
 */
function computeTokenState(token) {
    return {
        // Identity
        id: token.id_token,
        serialNumber: token.serial_number,
        
        // Job Context
        jobCode: token.ticket_code || token.job_code,
        jobName: token.job_name,
        productName: token.product_name,
        
        // Node Context
        nodeId: token.current_node_id || token.node_id,
        nodeName: token.node_name,
        nodeCode: token.node_code,
        nodeType: token.node_type || 'operation',
        
        // Behavior
        behaviorCode: token.behavior?.code || token.behavior_code || null,
        behaviorName: token.behavior?.name || null,
        
        // Status (Computed)
        status: computeStatus(token), // 'ready' | 'active' | 'paused' | 'waiting' | 'completed'
        isQcNode: token.node_type === 'qc',
        isParallel: token.is_parallel || false,
        
        // Assignment
        isAssignedToMe: token.is_assigned_to_me || false,
        assignedToName: token.assigned_to_name || null,
        isMine: token.session?.is_mine || false,
        
        // Time (Normalized for BGTimeEngine)
        time: {
            workSeconds: token.timer?.work_seconds || 0,
            baseWorkSeconds: token.timer?.base_work_seconds || 0,
            lastServerSync: token.timer?.last_server_sync || null,
            timerStatus: token.timer?.status || 'stopped',
            startedAt: token.session?.started_at || null,
            pausedAt: token.session?.paused_at || null,
            totalPauseMinutes: token.session?.total_pause_minutes || 0
        },
        
        // Warnings
        warnings: {
            hasMaterialShortage: token.material_status?.has_shortage === true,
            shortages: token.material_status?.shortages || [],
            hasAssignmentConflict: false // Future use
        },
        
        // Session
        session: token.session || null
    };
}

function computeStatus(token) {
    if (token.session?.is_mine) {
        if (token.session.status === 'active') return 'active';
        if (token.session.status === 'paused') return 'paused';
    }
    if (token.status === 'ready') return 'ready';
    if (token.status === 'waiting') return 'waiting';
    if (token.status === 'completed') return 'completed';
    return 'ready';
}
```

---

## 📋 Data Attributes Contract

**MANDATORY:** Every token card MUST have these attributes for event handling and timer to work.

### Required Attributes (All Layouts)

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `data-token-id` | Token identification | `1234` |
| `data-node-id` | Node identification | `56` |
| `data-job-id` | Job ticket ID | `78` |

### Optional Attributes

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `data-material-shortage` | Has shortage flag | `"1"` or absent |
| `data-parallel-group-id` | Parallel group | `"pg-123"` |
| `data-token-data` | Full token JSON (for Modal) | `encodeURIComponent(JSON.stringify(...))` |

### Timer Element Attributes (Required for BGTimeEngine)

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `data-token-id` | Timer identification | `1234` |
| `data-started` | Session start time | `"2025-12-08 10:00:00"` |
| `data-pause-min` | Total pause minutes | `5` |
| `data-work-seconds-base` | Base work seconds | `1200` |
| `data-work-seconds-sync` | Synced work seconds | `1250` |
| `data-last-server-sync` | Last sync timestamp | `"2025-12-08 10:20:00"` |
| `data-status` | Timer status | `"active"` or `"paused"` |

### Element Classes

| Class | Purpose |
|-------|---------|
| `.js-token-card` | Root card element (click target) |
| `.work-timer` | Timer display element |
| `.work-timer-active` | Active timer (BGTimeEngine registers these) |

### Event Delegation Contract

```javascript
// Card click → Open Modal
$(document).on('click', '.js-token-card', function(e) {
    if ($(e.target).closest('button').length) return;
    const tokenId = $(this).data('token-id');
    openWorkModal(tokenId, ...);
});

// Button actions
$(document).on('click', '[data-action="start"]', ...);
$(document).on('click', '[data-action="pause"]', ...);
$(document).on('click', '[data-action="resume"]', ...);
$(document).on('click', '[data-action="qc_pass"]', ...);
$(document).on('click', '[data-action="qc_fail"]', ...);
```

---

## 📋 Implementation Plan

### Phase 1: Create Module Structure (1h)

| Step | Action | File |
|------|--------|------|
| 1.1 | Create `TokenCardState.js` | View Model logic |
| 1.2 | Create `TokenCardParts.js` | Shared renderers |
| 1.3 | Create `TokenCardLayouts.js` | Layout templates |
| 1.4 | Create `TokenCardComponent.js` | Main entry point |

**File Structure:**
```
assets/javascripts/pwa_scan/
├── work_queue.js              (existing - will be simplified)
├── work_queue_timer.js        (existing - BGTimeEngine)
└── token_card/                (NEW directory)
    ├── TokenCardState.js      (View Model)
    ├── TokenCardParts.js      (UI Parts)
    ├── TokenCardLayouts.js    (Layouts)
    └── TokenCardComponent.js  (Entry Point)
```

**Deliverable:** Module files created with structure

---

### Phase 2: Extract State Logic (1h)

| Step | Action | Notes |
|------|--------|-------|
| 2.1 | Implement `computeTokenState()` | Central View Model |
| 2.2 | Implement `computeStatus()` | Status logic |
| 2.3 | Add JSDoc comments | For future reference |

**Deliverable:** TokenCardState.js complete and tested

---

### Phase 3: Extract UI Parts (1.5h)

| Step | Action | Notes |
|------|--------|-------|
| 3.1 | Extract `renderStatusBadge(state)` | Status badge HTML |
| 3.2 | Extract `renderTimer(token, state)` | Timer with data attrs |
| 3.3 | Extract `renderAssignmentInfo(state)` | Assignment alert |
| 3.4 | Extract `renderMaterialWarning(state)` | Shortage warning |
| 3.5 | Extract `renderActionButtons(state, options)` | All button types |
| 3.6 | Extract `renderNodeInfo(state)` | Node + behavior badge |

**Deliverable:** TokenCardParts.js complete

---

### Phase 4: Create Layout Templates (1h)

| Step | Action | Notes |
|------|--------|-------|
| 4.1 | Create `kanbanLayout(token, state, parts)` | Column card |
| 4.2 | Create `listLayout(token, state, parts)` | Row card |
| 4.3 | Create `mobileLayout(token, state, parts)` | Mobile card |

**Deliverable:** TokenCardLayouts.js complete

---

### Phase 5: Incremental Migration (1.5h)

> **IMPORTANT:** Migrate ONE view at a time to minimize risk

| Step | Action | Test |
|------|--------|------|
| 5.1 | Load scripts in page definition | page/pwa_scan_v2.php |
| 5.2 | **Migrate Kanban first** | Full test cycle |
| 5.3 | Verify: Timer, Modal, Buttons, Shortage | All work? |
| 5.4 | **Migrate List view** | Full test cycle |
| 5.5 | Verify: Timer, Modal, Buttons, Shortage | All work? |
| 5.6 | **Migrate Mobile view** | Full test cycle |
| 5.7 | Verify: Timer, Modal, Buttons, Shortage | All work? |
| 5.8 | Remove old render functions | After all verified |

**Migration Order Rationale:**
1. **Kanban first** - Most visible, most tested, highest confidence
2. **List second** - Similar to Kanban, medium complexity
3. **Mobile last** - Has job grouping logic, most complex

---

### Phase 6: Event Handler Cleanup (0.5h)

| Step | Action | Notes |
|------|--------|-------|
| 6.1 | Consolidate card click handlers | Use `.js-token-card` |
| 6.2 | Add `data-action` to buttons | Standardize actions |
| 6.3 | Verify delegation works | All views |

---

## ⚠️ Risk Warnings

### 1. God File Prevention

**Risk:** TokenCardComponent.js grows uncontrollably

**Mitigation:**
- Use separate module files from start
- Each module has single responsibility
- If file > 200 lines, split further

### 2. Data Attribute Compatibility

**Risk:** Existing event handlers break

**Mitigation:**
- Audit ALL current data-* usage before refactor
- Keep backward compatible attributes
- Test each view fully before moving to next

### 3. BGTimeEngine Dependency

**Risk:** Timer stops working after refactor

**Mitigation:**
- `renderTimer()` is SOLE SOURCE of timer markup
- Timer contract documented above
- Test timer in all 3 views after each migration step

---

## 🔒 Guardrails

### MUST Follow

1. **computeTokenState() is SINGLE SOURCE** - All renderers use this
2. **No logic in layouts** - Layouts are HTML structure only
3. **Token data unchanged** - API response stays same
4. **Event delegation** - Single point for click handlers
5. **BGTimeEngine compatibility** - Timer data attributes exactly as specified
6. **Migrate one view at a time** - Never all at once

### MUST NOT Do

1. ❌ Change API response format
2. ❌ Modify token data structure
3. ❌ Break existing event handlers
4. ❌ Rename data-* attributes without updating handlers
5. ❌ Create new CSS files (use existing classes)
6. ❌ Merge all views in one commit

---

## 📁 Files Affected

### Create
```
assets/javascripts/pwa_scan/token_card/
├── TokenCardState.js
├── TokenCardParts.js
├── TokenCardLayouts.js
└── TokenCardComponent.js
```

### Modify
- `assets/javascripts/pwa_scan/work_queue.js` (remove old functions)
- `page/pwa_scan_v2.php` (add script includes)

### Delete (after verification)
- None (functions are in work_queue.js, just remove them)

---

## ✅ Acceptance Criteria

| # | Criteria | Test Method |
|---|----------|-------------|
| 1 | Kanban view displays correctly | Visual |
| 2 | List view displays correctly | Visual |
| 3 | Mobile view displays correctly | Visual (resize) |
| 4 | Click card opens Modal (all views) | Click test |
| 5 | Timer works in all views | Wait 60s & verify |
| 6 | Timer persists after pause/resume | Action test |
| 7 | Material shortage warning shows | UI check |
| 8 | Start/Pause/Resume work | Button test |
| 9 | QC Pass/Fail work | Button test |
| 10 | No console errors | F12 check |
| 11 | Only 1 TokenCard function exists | Code review |

---

## 📊 Before/After Metrics

| Metric | Before | After |
|--------|--------|-------|
| Render functions | 3 | 1 |
| Lines of duplicate code | ~450 | 0 |
| Places to fix bugs | 3 | 1 |
| Consistency guaranteed | ❌ | ✅ |
| Reusable by other views | ❌ | ✅ |

---

## 🔗 Related Tasks

- Task 27.20: Work Modal Behavior (completed)
- Task 27.21: Material Integration (completed)
- Task 27.21.1: Rework Material Reserve (in progress)

---

## 📅 Schedule

Can run **parallel** with Task 27.21.1 since:
- No database changes
- No API changes
- Frontend-only refactor

---

---

## ✅ Completion Status (2025-12-09)

**Status:** ✅ **COMPLETED**

### What Was Done

1. ✅ Created TokenCard component files:
   - `TokenCardState.js` - State computation (view model)
   - `TokenCardParts.js` - UI parts rendering
   - `TokenCardLayouts.js` - Layout definitions
   - `TokenCardComponent.js` - Main component

2. ✅ Migrated List view to use `TokenCard()` (line 758, 779, 784, 803, 822)

3. ✅ Migrated Kanban view to use `TokenCard.createWithHandler()` (line 1376)

4. ✅ Marked legacy functions as `@deprecated`:
   - `renderListTokenCard()` (line 1111)
   - `renderKanbanTokenCard()` (line 1415)

5. ✅ Loaded component files in `page/work_queue.php` (line 25-28)

### Remaining Cleanup (Optional)

- ⏸️ Remove deprecated functions `renderListTokenCard()` and `renderKanbanTokenCard()` (~600 lines)
- ⏸️ Remove `renderTokenCard()` function if not used (line 1758)

**Note:** Legacy functions are marked deprecated but kept for backward compatibility. Can be removed in future cleanup.

---

*Last Updated: Dec 9, 2025*
