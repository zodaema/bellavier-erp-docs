# Graph Version Selection - Complete Flow Audit

## Overview
เอกสารนี้ trace flow ทั้งหมดตั้งแต่เปิดกราฟขึ้นมา จนถึงการเลือกเวอร์ชันต่างๆ (Draft, Published, Specific Version)

---

## 1. Initial Page Load Flow

### 1.1 Document Ready (graph_designer.js:376)
```
$(document).ready(function() {
    // 1. Initialize GraphVersionController
    versionController = new GraphVersionController()
    window.versionController = versionController
    
    // 2. Set callbacks
    versionController.setCallbacks({
        onIdentityChange: (newIdentity, previousIdentity) => { ... }
        onLoadRequest: (identityRequest) => {
            // User requested load via selector
            // Sets draft lock if ref === 'draft'
            loadGraph(identityRequest.graphId, versionParam, status)
        }
    })
    
    // 3. Bind version selector events
    $('#version-selector').on('change', ...)
    $('#version-selector').on('select2:select', ...)
    
    // 4. Initialize GraphSidebar
    initGraphSidebar()
})
```

### 1.2 GraphSidebar Initialization (graph_designer.js:539)
```
initGraphSidebar() {
    graphSidebar = new GraphSidebar({
        container: '#graph-sidebar',
        onGraphSelect: (graphId, source) => {
            // Handles graph selection from sidebar
            // Has draft lock checks
            versionController.selectGraph(graphId, source)
        }
    })
}
```

### 1.3 GraphSidebar.init() (graph_sidebar.js:113)
```
init() {
    this.loadStateFromUrl()      // Read graphId from URL
    this.loadStateFromStorage()  // Read saved state
    this.render()                 // Render UI
    this.bindEvents()             // Bind click handlers
    this.loadGraphs()             // Load graph list from API
}
```

### 1.4 GraphSidebar.loadGraphs() Success (graph_sidebar.js:260)
```
loadGraphs() {
    $.ajax({
        success: (response) => {
            this.graphs = response.graphs
            this.render()
            
            // Auto-select graph from URL/state
            if (this.selectedGraphId) {
                setTimeout(() => {
                    this.selectGraph(this.selectedGraphId, 'sidebar_autoselect')
                }, 100)
            }
        }
    })
}
```

### 1.5 Sidebar Auto-Select Flow (graph_designer.js:549-624)
```
onGraphSelect(graphId, source = 'sidebar_autoselect') {
    // P0 FIX: Sidebar autoselect must be ONE-SHOT only
    if (source === 'sidebar_autoselect') {
        // Check if already consumed or graph already loaded
        if (sidebarAutoSelectConsumed || currentGraphId !== null) {
            return // Block repeated autoselect
        }
        
        // Check draft lock/pending
        if (isDraftLockActive || isPendingDraft || isRecentUserDraftPick) {
            return // Block during draft lock
        }
        
        // Check if UI prefers draft on boot
        if (preferDraftOnBoot) {
            // Set draft lock
            pendingVersionSwitch = { graphId, requestedVersion: 'draft', ... }
            draftLockUntil = now + 3000
            loadGraph(graphId, 'draft', 'draft') // Bypass controller default
            return
        }
        
        // Consume one-shot autoselect
        sidebarAutoSelectConsumed = true
    }
    
    // Continue to versionController.selectGraph()
}
```

### 1.6 GraphVersionController.selectGraph() (GraphVersionController.js:243)
```
selectGraph(graphId, source) {
    // P0 FIX: Pre-identity race window guard
    // Check pending draft intent from window.__lastLoadIntent
    if (pendingDraft && isAutoSource) {
        return // Block auto-select during pending draft
    }
    
    // P0 FIX: Current identity guard
    if (currentIdentity && currentIdentity.graphId === graphId) {
        if (isAutoSource && currentIdentity.ref === 'draft') {
            return // Block auto-sources when viewing draft
        }
        if (source === 'sidebar_autoselect') {
            return // Block sidebar autoselect for any current identity
        }
    }
    
    // Default: Load published_current
    const identityRequest = {
        graphId: graphId,
        ref: 'published',
        versionId: null,
        versionLabel: null,
        draftId: null
    }
    
    this.onLoadRequest(identityRequest) // → graph_designer.js:390
}
```

### 1.7 onLoadRequest Callback (graph_designer.js:390)
```
onLoadRequest(identityRequest) {
    let versionParam = versionController.buildVersionParam(identityRequest)
    let status = identityRequest.ref === 'draft' ? 'draft' : 'published'
    
    if (identityRequest.ref === 'draft') {
        versionParam = 'draft'
        status = 'draft'
        
        // P0 FIX: Set draft lock
        pendingVersionSwitch = { graphId, requestedVersion: 'draft', untilTs: now + 5000 }
        draftLockUntil = now + 3000
    }
    
    loadGraph(identityRequest.graphId, versionParam, status)
}
```

---

## 2. Version Selector Change Flow

### 2.1 Native Change Event (graph_designer.js:430)
```
$('#version-selector').on('change', function(e) {
    // Check sync guard
    if (isVersionSelectorSyncing || now < versionSelectorSquelchUntil) {
        return // Ignore programmatic changes
    }
    
    const canonicalValue = $(this).val()
    
    if (canonicalValue === 'draft') {
        // P0 FIX: Set draft lock
        pendingVersionSwitch = { graphId, requestedVersion: 'draft', ... }
        draftLockUntil = now + 3000
        lastUserSelectAt = now
        lastUserCanonical = 'draft'
        
        loadGraph(currentGraphId, 'draft', 'draft') // Bypass controller
        return
    }
    
    // Use controller for other versions
    if (versionController) {
        versionController.handleSelectorChange(canonicalValue)
    }
})
```

### 2.2 Select2 Select Event (graph_designer.js:482)
```
$('#version-selector').on('select2:select', function(e) {
    const canonicalValue = $(this).val()
    
    if (canonicalValue === 'draft') {
        // P0 FIX: Set draft lock (same as change event)
        pendingVersionSwitch = { graphId, requestedVersion: 'draft', ... }
        draftLockUntil = now + 3000
        lastUserSelectAt = now
        lastUserCanonical = 'draft'
        
        loadGraph(currentGraphId, 'draft', 'draft') // Bypass controller
        return
    }
    
    versionController.handleSelectorChange(canonicalValue)
})
```

### 2.3 GraphVersionController.handleSelectorChange() (GraphVersionController.js:205)
```
handleSelectorChange(canonicalValue) {
    // Get graphId from currentIdentity or selector data attribute
    const graphId = this.currentIdentity?.graphId || $('#version-selector').data('graph-id')
    
    // Convert canonical to identity request
    const identityRequest = this.canonicalToIdentityRequest(canonicalValue, graphId)
    
    // Request load
    if (this.onLoadRequest) {
        this.onLoadRequest(identityRequest) // → graph_designer.js:390
    }
}
```

---

## 3. loadGraph() Function Flow

### 3.1 Entry Point (graph_designer.js:1250)
```
function loadGraph(graphId, versionToLoad, statusToLoad) {
    // P0 FIX: Prevent concurrent loads
    if (isLoadingGraph) {
        return // Skip if already loading
    }
    
    // P0 FIX: Set load intent BEFORE making request
    setLastLoadIntent(graphId, versionParam)
    
    // Use GraphLoader or direct AJAX
    if (graphLoader) {
        graphLoader.loadGraph(graphId, { version: versionParam })
    } else {
        // Direct AJAX fallback
    }
}
```

### 3.2 GraphLoader.loadGraph() (GraphLoader.js:57)
```
async loadGraph(graphId, options) {
    const { version } = options
    
    // Increment sequence
    const seq = ++this.state.loadSeq
    
    // Call GraphAPI
    if (this.api) {
        const apiResponse = await this.api.getGraph(graphId, { version })
        // Check stale response
        if (response._seq && response._seq < this.state.loadSeq) {
            return { ignored: true } // Stale response
        }
    }
    
    // Call onLoadSuccess callback
    this.onLoadSuccess(result)
}
```

### 3.3 GraphAPI.getGraph() (GraphAPI.js:99)
```
async getGraph(graphId, options) {
    // P0 FIX: Use global request sequence
    const requestSeq = ++GraphAPI.__globalRequestSeq
    
    const params = {
        action: 'graph_get',
        id: graphId,
        version: options.version // 'draft', 'published', or version string
    }
    
    return this._request('GET', params, headers, endpoint, {
        requestSeq: requestSeq,
        requestedVersion: options.version,
        graphId: graphId
    })
}
```

### 3.4 onLoadSuccess Callback (graph_designer.js:2280)
```
onLoadSuccess(data) {
    // Check stale response
    if (data.ignored) {
        return // Ignore stale response
    }
    
    const requestedVersion = data.requestedVersion
    
    // Normalize graph data
    const normalizedGraph = data.graph || {}
    const graphStatus = normalizedGraph.status || 'published'
    
    // P0 FIX: Set identity using requestedVersion (not graphStatus)
    if (versionController) {
        const isDraftRequest = (requestedVersion === 'draft')
        const identity = {
            graphId: graphId,
            ref: isDraftRequest ? 'draft' : 'published', // requestedVersion is source of truth
            versionId: isDraftRequest ? null : (normalizedGraph.id_version || null),
            draftId: isDraftRequest ? (draftId || null) : null,
            versionLabel: isDraftRequest ? null : (graphVersion || null)
        }
        versionController.setIdentity(identity)
        
        // Clear draft lock after successful draft load
        if (isDraftRequest && pendingVersionSwitch) {
            pendingVersionSwitch = null
            draftLockUntil = 0
        }
    }
    
    // Call handleGraphLoaded
    handleGraphLoaded(graphData, etag, graphId, draftInfo, requestedVersion)
}
```

---

## 4. handleGraphLoaded() Function Flow

### 4.1 Entry Point (graph_designer.js:1961)
```
function handleGraphLoaded(graphData, etag, graphId, draftInfo, requestedVersion) {
    // P0 FIX: Hard stale-response guard (FIRST LINE)
    try {
        if (isStaleLoad(graphId, requestedVersion)) {
            debugLogger.warn('[handleGraphLoaded] HARD REJECT: Stale response ignored')
            isLoadingGraph = false // Reset loading state
            return // HARD REJECT
        }
    } catch (e) {
        debugLogger.warn('[handleGraphLoaded] Stale guard error:', e)
    }
    
    // Continue processing...
    currentGraphId = graphId
    
    // Normalize graph data
    // Create Cytoscape instance
    // Update UI
    // etc.
}
```

---

## 5. Key Guards and Mechanisms

### 5.1 Stale Response Guard
- **Location**: `handleGraphLoaded()` first line
- **Purpose**: Prevent older responses from overwriting newer requests
- **Mechanism**: Compare `graphId` and `requestedVersion` with `lastLoadIntent`
- **Action**: Hard reject + reset `isLoadingGraph = false`

### 5.2 Draft Lock Mechanism
- **Variables**: `pendingVersionSwitch`, `draftLockUntil`
- **Set When**: User selects draft (selector change, onLoadRequest)
- **Clear When**: Draft load succeeds in `onLoadSuccess`
- **Purpose**: Prevent auto-select from overriding draft selection

### 5.3 Sidebar Auto-Select Guard
- **Variable**: `sidebarAutoSelectConsumed`
- **Purpose**: Allow auto-select only once (initial boot)
- **Block When**: Already consumed OR graph already loaded OR draft lock active

### 5.4 Pre-Identity Race Window Guard
- **Location**: `GraphVersionController.selectGraph()`
- **Purpose**: Block auto-select during pending draft intent
- **Mechanism**: Check `window.__lastLoadIntent` for pending draft

### 5.5 Current Identity Guard
- **Location**: `GraphVersionController.selectGraph()`
- **Purpose**: Block auto-sources when viewing draft
- **Mechanism**: Check `currentIdentity.ref === 'draft'`

### 5.6 Version Selector Sync Guard
- **Variables**: `isVersionSelectorSyncing`, `versionSelectorSquelchUntil`
- **Purpose**: Prevent programmatic selector updates from triggering change events
- **Mechanism**: Wrap programmatic updates in `withVersionSelectorSync()`

---

## 6. Flow Summary by Action

### 6.1 User Clicks Graph in Sidebar
```
Sidebar Click
  → graphSidebar.selectGraph(graphId, 'user')
  → onGraphSelect(graphId, 'user')
  → versionController.selectGraph(graphId, 'user')
  → onLoadRequest({ graphId, ref: 'published' })
  → loadGraph(graphId, 'published', 'published')
  → GraphLoader → GraphAPI → Backend
  → onLoadSuccess → handleGraphLoaded
```

### 6.2 User Selects Draft from Version Selector
```
Selector Change (draft)
  → $('#version-selector').on('change')
  → Set draft lock (pendingVersionSwitch, draftLockUntil)
  → loadGraph(currentGraphId, 'draft', 'draft')
  → GraphLoader → GraphAPI → Backend
  → onLoadSuccess → Set identity (ref: 'draft')
  → handleGraphLoaded → Clear draft lock
```

### 6.3 User Selects Published Version
```
Selector Change (published:2.0)
  → $('#version-selector').on('change')
  → versionController.handleSelectorChange('published:2.0')
  → onLoadRequest({ graphId, ref: 'published', versionLabel: '2.0' })
  → loadGraph(graphId, '2.0', 'published')
  → GraphLoader → GraphAPI → Backend
  → onLoadSuccess → Set identity (ref: 'published')
  → handleGraphLoaded
```

### 6.4 Sidebar Auto-Select (Initial Boot)
```
Sidebar loadGraphs() Success
  → setTimeout(() => selectGraph(graphId, 'sidebar_autoselect'), 100)
  → onGraphSelect(graphId, 'sidebar_autoselect')
  → Check: sidebarAutoSelectConsumed? → NO (first time)
  → Check: draft lock? → NO (initial boot)
  → Check: preferDraftOnBoot? → Check selector/URL/state
  → If draft preferred: loadGraph(graphId, 'draft', 'draft')
  → Else: versionController.selectGraph(graphId, 'sidebar_autoselect')
  → Load published_current
```

### 6.5 Sidebar Auto-Select (After Graph Loaded)
```
Sidebar loadGraphs() Success (refresh)
  → setTimeout(() => selectGraph(graphId, 'sidebar_autoselect'), 100)
  → onGraphSelect(graphId, 'sidebar_autoselect')
  → Check: sidebarAutoSelectConsumed? → YES
  → Check: currentGraphId !== null? → YES
  → RETURN (Blocked - already consumed and graph loaded)
```

---

## 7. Critical Code Paths

### 7.1 Draft Selection Paths
1. **Version Selector Change** → `loadGraph(..., 'draft', 'draft')` (bypass controller)
2. **Version Selector Select2** → `loadGraph(..., 'draft', 'draft')` (bypass controller)
3. **Controller onLoadRequest** → `loadGraph(..., 'draft', 'draft')` (via controller)

### 7.2 Published Selection Paths
1. **Sidebar Click** → `versionController.selectGraph()` → `onLoadRequest({ ref: 'published' })`
2. **Version Selector** → `versionController.handleSelectorChange()` → `onLoadRequest({ ref: 'published' })`
3. **Sidebar Auto-Select** → `versionController.selectGraph()` → `onLoadRequest({ ref: 'published' })`

### 7.3 Specific Version Selection Paths
1. **Version Selector** → `versionController.handleSelectorChange('published:2.0')` → `onLoadRequest({ ref: 'published', versionLabel: '2.0' })`

---

## 8. Potential Race Conditions and Guards

### 8.1 Race: Published Response After Draft Request
- **Guard**: Stale response guard in `handleGraphLoaded()` (first line)
- **Mechanism**: Compare `requestedVersion` with `lastLoadIntent.versionParam`
- **Action**: Hard reject + reset loading state

### 8.2 Race: Auto-Select During Draft Load
- **Guard**: Pre-identity race window guard in `selectGraph()`
- **Mechanism**: Check `window.__lastLoadIntent` for pending draft
- **Action**: Block auto-select if pending draft exists

### 8.3 Race: Auto-Select After Draft Loaded
- **Guard**: Current identity guard in `selectGraph()`
- **Mechanism**: Check `currentIdentity.ref === 'draft'`
- **Action**: Block auto-sources when viewing draft

### 8.4 Race: Sidebar Refresh Override
- **Guard**: Sidebar auto-select one-shot + draft lock
- **Mechanism**: `sidebarAutoSelectConsumed` + `draftLockUntil`
- **Action**: Block repeated autoselect + block during draft lock

---

## 9. Debugging Hints

### 9.1 Key Variables to Monitor
- `window.__lastLoadIntent` - Latest load intent
- `pendingVersionSwitch` - Pending draft switch
- `draftLockUntil` - Draft lock expiration
- `sidebarAutoSelectConsumed` - One-shot autoselect flag
- `versionController.currentIdentity` - Current graph identity

### 9.2 Key Log Points
- `[LoadIntent] Set load intent:` - When load intent is set
- `[GraphVersionController] selectGraph called` - When selectGraph is called
- `[handleGraphLoaded] HARD REJECT:` - When stale response is rejected
- `[GraphSidebar] Blocked non-user selectGraph` - When autoselect is blocked
- `[VersionSelector] Draft lock set` - When draft lock is set

---

## 10. Checklist for Testing

- [ ] Initial page load → Sidebar auto-selects graph → Loads published_current
- [ ] User clicks graph in sidebar → Loads published_current
- [ ] User selects draft from selector → Loads draft → Lock prevents override
- [ ] User selects published version → Loads published version
- [ ] Sidebar refresh → Does NOT override draft selection
- [ ] Stale published response → Rejected by stale guard
- [ ] Auto-select during draft load → Blocked by pre-identity guard
- [ ] Auto-select after draft loaded → Blocked by current identity guard

---

**Last Updated**: 2025-12-15
**Author**: AI Assistant
**Status**: Complete Audit

