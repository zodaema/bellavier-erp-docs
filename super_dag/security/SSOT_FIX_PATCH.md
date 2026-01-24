# 🛡️ SSOT Fix - Single Source of Truth Implementation

**Date:** 2025-12-15  
**Objective:** ลดระบบซ้อน + สร้าง Single Source of Truth จริง  
**Strategy:** ลบ guard ซ้อน + ยึด GraphVersionController.currentIdentity เป็น SSOT เท่านั้น

---

## 📋 Problem Statement

**Root Cause:** D) ไม่มี canonical version state

**Symptom:**
- User สลับ Published → Draft
- Draft load สำเร็จ
- Selector "เด้งกลับ" ไป Published (sidebar autoselect override)

**Root Issue:**
- Multiple authorities แย่งกันควบคุม state
- Sidebar autoselect ยัง override ได้แม้ guards ซ้อน
- ไม่มี Single Source of Truth ที่ชัดเจน

---

## 🎯 Solution Strategy

### Single Source of Truth (SSOT):
- **GraphVersionController.currentIdentity** = SSOT สำหรับ version state
- **Sidebar** = Reader-only (อ่านได้อย่างเดียว, ห้ามเขียน)
- **Selector DOM** = Passive view (reflect เท่านั้น, ไม่ decide)

### Rules:
1. ถ้า `currentIdentity` มีค่า → ห้าม autoselect ทับ
2. `selectGraph(source !== 'user')` → ห้าม override `currentIdentity` เมื่อ `graphId` เดียวกัน
3. Autoselect ได้เฉพาะเมื่อ `currentIdentity === null` (initial boot)

---

## 📝 PATCH #1 — Sidebar: Disable Autoselect When Identity Exists

**File:** `assets/javascripts/dag/graph_sidebar.js`  
**Location:** `loadGraphs()` success callback (บรรทัด 273-348)

### Before (75+ lines):
```javascript
// Complex guard checks with global flags
const globalGraphId = ...;
const globalRequestedVersion = ...;
const lastLoadIntent = ...;
const isGraphAlreadyLoaded = ...;
const hasDraftIntent = ...;

const shouldAutoSelect = (() => {
    if (window.versionController) {
        const currentIdentity = window.versionController.getIdentity();
        if (currentIdentity && currentIdentity.graphId === this.selectedGraphId) {
            if (currentIdentity.ref === 'draft') {
                return false; // Don't auto-select
            }
        }
    }
    return true;
})();

if (shouldAutoSelect) {
    setTimeout(() => {
        this.selectGraph(this.selectedGraphId, 'sidebar_autoselect');
    }, 100);
}
```

### After (20 lines):
```javascript
// P0 SSOT FIX: Check canonical state from GraphVersionController
const versionController = (typeof window !== 'undefined' && window.versionController) ? window.versionController : null;
if (versionController && typeof versionController.getIdentity === 'function') {
    const currentIdentity = versionController.getIdentity();
    if (currentIdentity && currentIdentity.graphId === this.selectedGraphId) {
        // SSOT exists for this graph - preserve it, don't override
        console.debug('[GraphSidebar] Skipping autoselect - identity exists (SSOT)', {...});
        return; // Exit early - skip all autoselect logic
    }
}

// Identity is null (initial boot) - safe to autoselect
setTimeout(() => {
    this.selectGraph(this.selectedGraphId, 'sidebar_autoselect');
}, 100);
```

### Logic ที่ถูกลบออก:
- ❌ **ลบ:** `globalGraphId`, `globalRequestedVersion`, `lastLoadIntent` checks (ไม่ใช่ SSOT)
- ❌ **ลบ:** `isGraphAlreadyLoaded`, `hasDraftIntent` checks (heuristic-based)
- ❌ **ลบ:** `shouldAutoSelect` closure function ที่ซับซ้อน (check draft ref, etc.)
- ❌ **ลบ:** `if/else shouldAutoSelect` conditional (ซ้อนกัน)

### Logic ที่เพิ่มเข้าไป:
- ✅ **เพิ่ม:** Check `window.versionController.getIdentity()` เท่านั้น
- ✅ **เพิ่ม:** ถ้า `currentIdentity !== null` และ `graphId` เดียวกัน → `return` (skip autoselect)
- ✅ **เพิ่ม:** `console.debug` log สำหรับ trace

---

## 📝 PATCH #2 — Controller: Ignore Non-User Override on Same Graph

**File:** `assets/javascripts/dag/modules/GraphVersionController.js`  
**Location:** `selectGraph(graphId, source)` (บรรทัด 248-377)

### Before (130+ lines):
```javascript
selectGraph(graphId, source = 'unknown') {
    // Stack trace logging
    console.warn('[GraphVersionController] selectGraph called', {...});
    
    // Pre-identity guard for sidebar_autoselect
    if (source === 'sidebar_autoselect') {
        const globalGraphId = ...;
        const globalRequestedVersion = ...;
        const lastLoadIntent = ...;
        const pendingVersionSwitch = ...;
        const draftLockUntil = ...;
        const lastUserCanonical = ...;
        const lastUserSelectAt = ...;
        
        const isGraphAlreadyLoaded = ...;
        const hasDraftIntent = ...;
        const isPendingDraft = ...;
        const isDraftLockActive = ...;
        const isRecentUserDraftPick = ...;
        
        if (isGraphAlreadyLoaded || hasDraftIntent || isPendingDraft || isDraftLockActive || isRecentUserDraftPick) {
            console.warn('[GraphVersionController] Blocked sidebar_autoselect...');
            return;
        }
    }
    
    // Pre-identity race window guard
    const pending = ...;
    const pendingDraft = ...;
    if (pendingDraft && isAutoSource) {
        console.warn('[GraphVersionController] Blocked auto selectGraph during pending draft intent...');
        return;
    }
    
    // If already have currentIdentity for this graph
    if (this.currentIdentity && this.currentIdentity.graphId === graphId) {
        const isAutoSource = source !== 'user' && source !== 'init';
        if (isAutoSource && this.currentIdentity.ref === 'draft') {
            console.warn('[GraphVersionController] Ignoring auto selectGraph override (draft lock)...');
            return;
        }
        if (source === 'sidebar_autoselect') {
            console.warn('[GraphVersionController] Ignoring sidebar auto-select...');
            return;
        }
    }
    
    // Default: load published
    const identityRequest = { graphId, ref: 'published', ... };
    if (this.onLoadRequest) {
        this.onLoadRequest(identityRequest);
    }
}
```

### After (20 lines):
```javascript
selectGraph(graphId, source = 'unknown') {
    if (!graphId) return;

    // P0 SSOT FIX: Minimal early-return - preserve currentIdentity when non-user source
    // Single Source of Truth: this.currentIdentity
    // Rule: If identity exists for same graph, only 'user' or 'init' can override
    if (this.currentIdentity && this.currentIdentity.graphId === graphId && source !== 'user' && source !== 'init') {
        // Non-user source trying to override existing identity - ignore it
        console.debug('[GraphVersionController] Ignoring non-user selectGraph - preserving identity (SSOT)', {
            graphId,
            source,
            identity: {
                ref: this.currentIdentity.ref,
                versionLabel: this.currentIdentity.versionLabel,
                draftId: this.currentIdentity.draftId
            },
            reason: 'GraphVersionController.currentIdentity is SSOT - only user/init can override'
        });
        return; // Early return - preserve current identity
    }

    // Phase 2.8: Always load published_current when selecting NEW graph (deterministic)
    const identityRequest = {
        graphId: graphId,
        ref: 'published',
        versionId: null,
        versionLabel: null,
        draftId: null
    };

    if (this.onLoadRequest) {
        this.onLoadRequest(identityRequest);
    }
}
```

### Logic ที่ถูกลบออก:
- ❌ **ลบ:** Stack trace logging (debug only - ไม่จำเป็น)
- ❌ **ลบ:** `sidebar_autoselect` specific guard block (70+ บรรทัด)
- ❌ **ลบ:** Pre-identity race window guard (pending draft intent checks)
- ❌ **ลบ:** Global flags checks (`window.__dagCurrentGraphId`, `window.__lastLoadIntent`, etc.)
- ❌ **ลบ:** Draft lock checks (`pendingVersionSwitch`, `draftLockUntil`)
- ❌ **ลบ:** Recent user draft pick checks (time-based heuristic)
- ❌ **ลบ:** Conditional `if (source === 'sidebar_autoselect')` block
- ❌ **ลบ:** Conditional `if (this.currentIdentity.ref === 'draft')` block

### Logic ที่เพิ่มเข้าไป:
- ✅ **เพิ่ม:** Minimal early-return (3 บรรทัด):
  ```javascript
  if (this.currentIdentity && this.currentIdentity.graphId === graphId && source !== 'user' && source !== 'init') {
      console.debug('[GraphVersionController] Ignoring non-user selectGraph - preserving identity (SSOT)', {...});
      return; // Early return - preserve current identity
  }
  ```

---

## 📝 PATCH #3 — Designer: Remove Wrapper Guards

**File:** `assets/javascripts/dag/graph_designer.js`  
**Location:** `initGraphSidebar()` → wrapper `versionController.selectGraph` (บรรทัด 384-446)

### Before (62 lines):
```javascript
// P0 FINAL FIX: Wrap controller.selectGraph with pre-identity guards
if (versionController && typeof versionController.selectGraph === 'function' && !versionController.__wrappedSelectGraph) {
    const __origSelectGraph = versionController.selectGraph.bind(versionController);
    
    versionController.selectGraph = function(graphId, source = 'user') {
        const now = Date.now();
        const selectorVal = ($('#version-selector').val() || '').toString();
        const urlWantsDraft = ...;
        const intentWantsDraft = ...;
        const pendingDraft = ...;
        const lockActive = ...;
        const recentUserDraftPick = ...;
        
        // Block sidebar autoselect whenever draft is intended/locked
        if (source === 'sidebar_autoselect') {
            if (selectorVal === 'draft' || urlWantsDraft || intentWantsDraft || pendingDraft || lockActive || recentUserDraftPick) {
                console.warn('[GraphVersionController WRAP] Blocked selectGraph(sidebar_autoselect)...');
                return;
            }
            if (currentGraphId !== null) {
                console.warn('[GraphVersionController WRAP] Blocked selectGraph(sidebar_autoselect)...');
                return;
            }
        }
        
        // Block other non-user sources during draft lock/pending
        if (source !== 'user' && source !== 'init') {
            if (pendingDraft || lockActive || recentUserDraftPick || selectorVal === 'draft' || intentWantsDraft) {
                console.warn('[GraphVersionController WRAP] Blocked selectGraph(auto-source)...');
                return;
            }
        }
        
        return __origSelectGraph(graphId, source);
    };
    
    versionController.__wrappedSelectGraph = true;
    debugLogger.log('[GraphDesigner] versionController.selectGraph wrapped with pre-identity guards');
}
```

### After (2 lines):
```javascript
// P0 SSOT FIX: Removed wrapper guards - GraphVersionController.selectGraph() now handles SSOT internally
// Controller is now the single authority - no need for wrapper guards
// Sidebar autoselect prevention is handled in sidebar code (checks identity before calling)
```

### Logic ที่ถูกลบออก:
- ❌ **ลบ:** Wrapper function ทั้งหมด (60+ บรรทัด)
- ❌ **ลบ:** `__wrappedSelectGraph` flag check
- ❌ **ลบ:** `__origSelectGraph` binding
- ❌ **ลบ:** Selector DOM reading (`$('#version-selector').val()`)
- ❌ **ลบ:** URL draft check (`window.location.search`)
- ❌ **ลบ:** Intent draft check (`window.__lastLoadIntent`)
- ❌ **ลบ:** Draft lock checks (`pendingVersionSwitch`, `draftLockUntil`)
- ❌ **ลบ:** Recent user draft pick checks
- ❌ **ลบ:** `currentGraphId` check

---

## 📊 Summary: Lines Removed vs Added

### Removed (~250 lines):
- `graph_sidebar.js`: ~75 lines (guards ซ้อน)
- `GraphVersionController.js`: ~130 lines (guards ซ้อน)
- `graph_designer.js`: ~62 lines (wrapper)

### Added (~20 lines):
- `graph_sidebar.js`: ~20 lines (SSOT check)
- `GraphVersionController.js`: ~7 lines (minimal guard)
- `graph_designer.js`: ~2 lines (comment)

**Net Reduction:** ~230 lines of complexity removed

---

## ✅ Expected Behavior After Patch

### Case 1: User switches Published → Draft
1. User clicks Draft selector
2. `loadGraph(graphId, 'draft')` called
3. Draft load success → `handleGraphLoaded()` → `setIdentity({ ref: 'draft' })`
4. Sidebar reload (async) → `loadGraphs()` success
5. **✅ Check identity:** `versionController.getIdentity()` returns `{ ref: 'draft' }`
6. **✅ Skip autoselect:** `return` early - no `selectGraph()` call
7. **✅ Result:** Selector stays on Draft, no bounce back

### Case 2: Initial Boot (identity === null)
1. Page loads → `selectedGraphId` from URL
2. Sidebar `loadGraphs()` success
3. **✅ Check identity:** `versionController.getIdentity()` returns `null`
4. **✅ Allow autoselect:** Call `selectGraph(graphId, 'sidebar_autoselect')`
5. **✅ Controller:** Identity null → load published (initial boot)

### Case 3: User clicks different graph
1. User clicks graph B (currently viewing graph A)
2. Sidebar `selectGraph(graphB, 'user')` called
3. **✅ Controller:** Source is 'user' → allow override
4. **✅ Load:** Graph B published version

---

## 🔍 Expected Logs

### When autoselect is blocked:
```
[GraphSidebar] Skipping autoselect - identity exists (SSOT)
  graphId: 1952
  identity: { ref: 'draft', versionLabel: null, draftId: 123 }
  reason: 'GraphVersionController.currentIdentity is SSOT - sidebar is reader-only'
```

### When selectGraph override is blocked:
```
[GraphVersionController] Ignoring non-user selectGraph - preserving identity (SSOT)
  graphId: 1952
  source: 'sidebar_autoselect'
  identity: { ref: 'draft', versionLabel: null, draftId: 123 }
  reason: 'GraphVersionController.currentIdentity is SSOT - only user/init can override'
```

---

## ✅ Safety Confirmation

**หลัง fix นี้ มีโอกาสไหมที่:**
- ✅ Draft save → ไม่กระทบ (backend hard guarantee)
- ✅ Publish trigger → ไม่กระทบ (backend hard guarantee)
- ✅ Job runtime → ไม่กระทบ (backend read from pinned version)

**Frontend fix ไม่กระทบ backend security guarantees** ✅

---

## 📝 Files Changed

1. `assets/javascripts/dag/graph_sidebar.js` - Simplified autoselect logic
2. `assets/javascripts/dag/modules/GraphVersionController.js` - Minimal SSOT guard
3. `assets/javascripts/dag/graph_designer.js` - Removed wrapper guards

**Total:** 3 files, ~230 lines removed, ~20 lines added

---

## 🧪 Test Plan

### 1. Hard Reproduce:
- เข้า graph 1952 → สลับ Published → สลับ Draft
- **Expected:** Selector ไม่เด้งกลับ
- **Log:** ต้องเห็น `[GraphSidebar] Skipping autoselect - identity exists (SSOT)`

### 2. Reload Page:
- Draft-first boot ยังทำงาน (ถ้ามี URL wantsDraft)
- Sidebar autoselect ยังทำงานได้เมื่อ `identity === null` เท่านั้น

### 3. Regression:
- เลือก graph อื่นจาก sidebar (source='user' หรือ click) ต้องยังเปลี่ยนได้ปกติ
- Published → Published switch ต้องทำงานปกติ

### 4. Log Audit:
- Search ใน console ว่า `sidebar_autoselect` ไม่ควรเรียก `selectGraph()` เมื่อ identity exists

---

## ✨ Key Principles Applied

1. **Single Source of Truth:** `GraphVersionController.currentIdentity` = SSOT
2. **No Guard Nesting:** ลบ guards ซ้อน → minimal check
3. **No Time-Based Heuristics:** ไม่ใช้ timeout/lock window
4. **No Flags:** ไม่เพิ่ม state flag ใหม่
5. **Reader-Only Sidebar:** Sidebar เป็น view/list ไม่ใช่ controller

---

**Status:** ✅ Complete - Ready for Testing  
**Next Step:** Test Published → Draft switch to verify no bounce back

