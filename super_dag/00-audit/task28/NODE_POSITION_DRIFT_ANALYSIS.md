# Node Position Drift Analysis
**Date:** 2025-12-13  
**Status:** 🔍 **ANALYSIS COMPLETE - ROOT CAUSE IDENTIFIED**  
**Priority:** P0 (Published Graph Node Positions Changing Unexpectedly)

---

## Executive Summary

**Issue:** Node positions on Published graphs change unexpectedly when:
- Creating/deleting/saving Drafts
- Publishing draft

**Root Cause Identified:** There are **multiple sources of truth** for node positions:
1. **Main tables** (`routing_node.position_x`, `routing_node.position_y`)
2. **Draft payload** (`routing_graph_draft.draft_payload_json` → `nodes[].position_x`)
3. **Version snapshot** (`routing_graph_version.payload_json` → `nodes[].position_x`)

The system **switches between these sources** based on draft existence, causing position drift.

---

## 🔍 Root Cause Analysis

### Problem 1: **Publish Workflow Doesn't Update Main Tables**

**Location:** `GraphVersionService::publish()` (line 146-405)

**Current Behavior:**
1. Load nodes/edges from draft (line 202-203)
2. Create version snapshot in `routing_graph_version.payload_json` (line 298-303)
3. Update `routing_graph` status to 'published' (line 364-381)
4. **❌ Does NOT update `routing_node` table**
5. **❌ Creates new draft from draft nodes** (line 405) - uses draft positions, not main table positions

**Impact:**
- After publish, main `routing_node` table still has old positions
- New draft has positions from old draft (may differ from main table)
- When loading 'latest' without draft → uses main table positions (old)
- When loading 'latest' with draft → uses draft positions (new/different)

**Code Reference:**
```php
// GraphVersionService::publish() line 405
$draftResult = $draftService->saveDraft($graphId, $nodes, $edges, $userId, null);
// $nodes here came from draft payload (line 202), not from main routing_node table
```

---

### Problem 2: **Loading Logic Switches Between Sources**

**Location:** `GraphService::getGraph()` (line 100-274)

**Current Behavior:**
```php
if ($version === 'latest') {
    $hasActiveDraft = $this->metadataRepo->hasActiveDraft($graphId);
    
    if ($hasActiveDraft) {
        // Load from draft payload
        $nodes = $draftPayload['nodes']; // Source: routing_graph_draft.draft_payload_json
    } else {
        // Load from main tables
        $nodes = loadGraphWithVersion(...); // Source: routing_node table
    }
}
```

**Impact:**
- **When draft exists**: Positions come from draft payload (may differ from main table)
- **When draft deleted**: Positions come from main table (may be outdated)
- **Result**: Positions "jump" when draft is created/deleted

---

### Problem 3: **loadGraphWithVersion() Doesn't Load Nodes for 'latest'**

**Location:** `source/dag/_helpers.php` → `loadGraphWithVersion()` (line 158-270)

**Current Behavior:**
```php
if ($version === 'latest') {
    // Get graph metadata only
    $graph = $db->fetchOne("SELECT * FROM routing_graph WHERE id_graph = ? AND status != 'deleted'", ...);
    // ❌ Does NOT load nodes/edges here
    // Nodes are loaded later in GraphService::getGraph() via graphRepo->findNodes()
}

// For specific versions:
else {
    // Load from version snapshot
    $nodes = $payload['nodes']; // Source: routing_graph_version.payload_json
}
```

**Impact:**
- For 'latest' without draft: Uses `graphRepo->findNodes()` → loads from `routing_node` table
- For 'latest' with draft: Uses draft payload
- **Two different sources = position drift**

---

### Problem 4: **Draft Save Uses Payload Positions (Not Main Table)**

**Location:** `GraphDraftService::saveDraft()` (line 50-163)

**Current Behavior:**
- Accepts nodes array from frontend
- Stores nodes in `draft_payload_json`
- **Does NOT read positions from main `routing_node` table**

**Impact:**
- If frontend sends different positions than main table → draft has different positions
- When loading draft → shows frontend positions, not main table positions

---

## 📊 Data Flow Diagram

### Scenario 1: Load Published Graph (No Draft)
```
1. GraphService::getGraph('latest')
   → No active draft
   → loadGraphWithVersion('latest')
   → graphRepo->findNodes($graphId)
   → SELECT * FROM routing_node WHERE id_graph = ?
   → Positions from main table ✅
```

### Scenario 2: Load Published Graph (With Draft)
```
1. GraphService::getGraph('latest')
   → Has active draft
   → Load draft_payload_json
   → $nodes = draftPayload['nodes']
   → Positions from draft payload ⚠️ (may differ from main table)
```

### Scenario 3: Publish Draft
```
1. GraphVersionService::publish()
   → Load nodes from draft payload (line 202)
   → Create version snapshot (line 298) - stores draft positions
   → Update routing_graph status (line 364)
   → ❌ Does NOT update routing_node table
   → Create new draft from draft nodes (line 405) - continues draft positions
   
Result:
- routing_node table: Old positions (unchanged)
- routing_graph_version.payload_json: Draft positions (new)
- routing_graph_draft.draft_payload_json: Draft positions (same as version)
```

### Scenario 4: Delete Draft
```
1. Draft deleted
2. Next load: GraphService::getGraph('latest')
   → No active draft
   → Load from routing_node table
   → Positions "jump" back to main table values (may be outdated)
```

---

## 🎯 Root Cause Summary

**Primary Issue:** Published graphs have **3 sources of positions** that can diverge:
1. `routing_node.position_x/y` (main table) - **Not updated during publish**
2. `routing_graph_version.payload_json` (version snapshot) - **Updated during publish**
3. `routing_graph_draft.draft_payload_json` (draft) - **Used when draft exists**

**Secondary Issue:** Loading logic switches between sources based on draft existence:
- Draft exists → Use draft positions
- Draft deleted → Use main table positions
- **Result: Positions "jump" when draft state changes**

---

## 💡 Proposed Solutions (Analysis Only - Not Implemented)

### Solution 1: **Update Main Tables During Publish** (Recommended)

**Strategy:** When publishing, update `routing_node` table with positions from draft.

**Changes Required:**
```php
// GraphVersionService::publish()
// After creating version snapshot, before creating new draft:
$saveEngine = new GraphSaveEngine($this->dbHelper);
$saveEngine->save($nodes, $edges, [
    'graphId' => $graphId,
    'isAutosave' => false, // Full save to update positions
    'userId' => $userId
]);
```

**Pros:**
- Main table always reflects published state
- Positions consistent regardless of draft existence
- Simple fix

**Cons:**
- Requires calling GraphSaveEngine (more complex)

---

### Solution 2: **Load Positions from Version Snapshot When Published**

**Strategy:** When loading published graph without draft, load positions from latest version snapshot instead of main table.

**Changes Required:**
```php
// GraphService::getGraph('latest')
if (!$hasActiveDraft && $graphStatus === 'published') {
    // Load from latest version snapshot
    $versionData = loadLatestVersion($graphId);
    $nodes = $versionData['payload']['nodes'];
} else {
    // Load from draft or main table
}
```

**Pros:**
- Uses immutable version snapshot (correct source of truth for published)
- Positions consistent with what was published

**Cons:**
- Requires version lookup for every load
- More complex loading logic

---

### Solution 3: **Don't Create Draft After Publish** (Simplest)

**Strategy:** Remove the "create new draft after publish" step (line 405).

**Changes Required:**
```php
// GraphVersionService::publish()
// Remove this:
// $draftResult = $draftService->saveDraft($graphId, $nodes, $edges, $userId, null);
```

**Pros:**
- Eliminates draft position drift
- Published graphs always load from main table
- Simple change

**Cons:**
- Users need to manually create draft to edit (may not be desired UX)

---

### Solution 4: **Create Draft from Main Table (Not Draft Payload)**

**Strategy:** When creating draft after publish, load positions from main table instead of draft payload.

**Changes Required:**
```php
// GraphVersionService::publish()
// Before creating new draft:
$graphRepo = new GraphRepository($this->dbHelper);
$mainTableNodes = $graphRepo->findNodes($graphId); // Load from main table
$mainTableEdges = $graphRepo->findEdges($graphId);

// Use main table positions, but keep draft structure
foreach ($nodes as &$node) {
    $nodeCode = $node['node_code'];
    $mainNode = array_filter($mainTableNodes, fn($n) => $n['node_code'] === $nodeCode)[0] ?? null;
    if ($mainNode) {
        $node['position_x'] = $mainNode['position_x'];
        $node['position_y'] = $mainNode['position_y'];
    }
}

$draftResult = $draftService->saveDraft($graphId, $nodes, $edges, $userId, null);
```

**Pros:**
- Draft positions match main table
- Prevents position drift

**Cons:**
- More complex logic
- Assumes main table has correct positions (may not be true after publish)

---

## 📋 Recommended Approach

**Best Solution:** **Solution 1 (Update Main Tables During Publish)** + **Solution 2 (Load from Version When Published)**

**Rationale:**
1. **During Publish:** Update main `routing_node` table → ensures consistency
2. **When Loading Published:** Load from version snapshot → uses immutable published state
3. **When Loading Draft:** Load from draft payload → shows current draft state

**This ensures:**
- Main table reflects latest published state
- Version snapshot is immutable record
- Draft shows current editing state
- No position drift between sources

---

## 🔍 Verification Steps

To confirm this analysis, check:

1. **After Publish:**
   ```sql
   -- Check main table positions
   SELECT id_node, node_code, position_x, position_y FROM routing_node WHERE id_graph = ?;
   
   -- Check version snapshot positions
   SELECT JSON_EXTRACT(payload_json, '$.nodes[*].position_x') FROM routing_graph_version WHERE id_graph = ? ORDER BY published_at DESC LIMIT 1;
   
   -- Should match if Solution 1 implemented
   ```

2. **After Draft Save:**
   ```sql
   -- Check draft positions
   SELECT JSON_EXTRACT(draft_payload_json, '$.nodes[*].position_x') FROM routing_graph_draft WHERE id_graph = ? AND status = 'active';
   
   -- Check main table positions
   SELECT position_x, position_y FROM routing_node WHERE id_graph = ?;
   
   -- May differ (this is expected - draft is editable)
   ```

3. **After Draft Delete:**
   - Load graph → positions should match version snapshot (not main table if Solution 2 implemented)

---

## Related Documents

- `CREATE_DRAFT_FROM_PUBLISHED_FIX.md` - Draft creation fixes
- `P0_SAVE_SEMANTICS_REFACTOR_COMPLETE.md` - Save semantics refactor

