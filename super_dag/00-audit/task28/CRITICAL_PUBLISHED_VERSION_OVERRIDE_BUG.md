# Critical Bug: Published Version Override by Draft Payload
**Date:** 2025-12-13  
**Status:** 🚨 **CRITICAL P0 - ROOT CAUSE IDENTIFIED**  
**Priority:** P0 (Published Version Data Corrupted When Draft Exists)

---

## Executive Summary

**Issue:** When viewing a Published version while an active draft exists, the Published version's nodes (positions, config) are **overridden by draft payload**, causing Published version to show incorrect data.

**User-Reported Symptoms:**
1. ✅ View Published version → Config and positions are correct
2. ✅ Click "Create Draft" → Draft is created with correct data
3. ❌ **View Published version again → Positions shift, Config missing**
4. ✅ Draft contains correct original data
5. ✅ Discard Draft → Published version returns to normal

**Root Cause:** `GraphService::getGraph()` when called with `version='latest'` and active draft exists, **overrides nodes from main table with draft payload**, even when user wants to view Published version.

---

## 🔍 Root Cause Analysis

### Critical Bug Location

**File:** `source/dag/Graph/Service/GraphService.php`  
**Method:** `getGraph()` (line 100-279)  
**Problem Lines:** 152-232

### The Problem Flow

```php
public function getGraph(int $graphId, string $version = 'latest'): ?array
{
    // Step 1: Load graph via helper
    $graphData = \loadGraphWithVersion($this->dbHelper, $graphId, $version);
    $nodes = $graphData['nodes'] ?? []; // ← Loaded from routing_node table (correct)
    
    // Step 2: Check for active draft
    if ($version === 'latest') {
        $hasActiveDraft = $this->metadataRepo->hasActiveDraft($graphId);
        
        if ($hasActiveDraft) {
            // ❌ CRITICAL BUG: Override nodes with draft payload
            $nodes = $draftPayload['nodes']; // ← Overwrites published nodes!
            $edges = $draftPayload['edges']; // ← Overwrites published edges!
            
            $graph['status'] = 'draft'; // ← Changes status to 'draft'
        }
    }
    
    // Step 3: Return overridden nodes
    $graph['nodes'] = $nodes; // ← Contains draft nodes, not published nodes!
    return ['graph' => $graph, ...];
}
```

### Why This Happens

1. **When user views Published version:**
   - UI may send `version='latest'` (default) instead of `version='published'` or specific version
   - `loadGraphWithVersion('latest')` loads nodes from `routing_node` table (correct)
   - But then `GraphService::getGraph()` **checks for active draft** and overrides nodes

2. **The Override Logic:**
   ```php
   if ($version === 'latest' && $hasActiveDraft) {
       // Override nodes/edges with draft payload
       $nodes = $draftPayload['nodes']; // ← CRITICAL: Overwrites published nodes!
       $graph['status'] = 'draft'; // ← Changes status too!
   }
   ```

3. **Result:**
   - Published version shows draft nodes (different positions/config)
   - User sees incorrect data
   - Draft has correct data (original published state)

---

## 📊 Data Flow Diagram

### Scenario: View Published Version (With Active Draft)

```
1. User clicks "View Published Version"
   → UI sends: action='graph_get', id=123, version='latest' (or undefined)
   → API receives: version='latest'

2. GraphService::getGraph(123, 'latest')
   → loadGraphWithVersion('latest')
   → SELECT * FROM routing_node WHERE id_graph=123
   → nodes = [published nodes with correct positions/config] ✅

3. Check for active draft
   → hasActiveDraft = true (draft exists)
   → Load draft_payload_json
   → nodes = draftPayload['nodes'] ❌ OVERRIDES published nodes!

4. Return result
   → graph.nodes = draft nodes (incorrect)
   → graph.status = 'draft' (incorrect)
   → User sees draft data instead of published data
```

### Scenario: View Published Version (No Active Draft)

```
1. User views Published Version
   → version='latest', hasActiveDraft = false
   
2. GraphService::getGraph(123, 'latest')
   → loadGraphWithVersion('latest')
   → nodes from routing_node table ✅
   
3. No override (no draft)
   → Return published nodes correctly ✅
```

---

## 🎯 Why Draft Has Correct Data

**Draft creation (`createDraftFromPublishedInternal`):**
1. Reads nodes from Published version (correct state)
2. Saves to `routing_graph_draft.draft_payload_json`
3. Draft contains snapshot of Published state ✅

**But when viewing Published:**
1. Loads nodes from main table (may be outdated)
2. Overrides with draft payload (which has correct original state)
3. **However:** Draft may have been edited, so draft != published anymore

**The real issue:** System is using draft as "source of truth" when user wants published version.

---

## 🔧 Solution Requirements

### Solution 1: **Don't Override When Viewing Published** (Recommended)

**Strategy:** Only override nodes when truly viewing "latest" (draft mode). If user explicitly wants published version, load from version snapshot or main table without draft override.

**Changes Required:**

#### Option A: Use Version Parameter Correctly

**Frontend Fix:**
- When viewing Published version, send `version='published'` or `version=<version_string>`
- Don't use `version='latest'` for Published views

**Backend Fix:**
- In `GraphService::getGraph()`, only override with draft when:
  - `version === 'latest'` AND
  - User is in draft editing mode (not just viewing)
  - OR: Add parameter `preferDraft=false` to prevent override

#### Option B: Load Published from Version Snapshot

**Backend Fix:**
```php
// In GraphService::getGraph()
if ($version === 'latest' && $hasActiveDraft) {
    // Only override if explicitly requested (draft editing mode)
    // If viewing published version, don't override
    if ($options['preferDraft'] ?? false) {
        $nodes = $draftPayload['nodes'];
        $graph['status'] = 'draft';
    } else {
        // Load from latest published version snapshot instead
        $versionData = loadLatestPublishedVersion($graphId);
        $nodes = $versionData['payload']['nodes'];
        $graph['status'] = 'published';
    }
}
```

#### Option C: Separate "Latest" from "Published"

**API Fix:**
- `version='latest'` → Always includes draft if exists (current behavior, but rename to `version='current'`)
- `version='published'` → Always loads from version snapshot (never draft override)
- `version=<version_string>` → Load specific version (never draft override)

---

## 💡 Recommended Fix

**Best Approach:** **Option C (Separate Latest from Published)**

1. **Change default behavior:**
   - `version='latest'` → Load draft if exists, else published
   - `version='published'` → Always load latest published version (no draft override)
   - `version=<version>` → Load specific version (no draft override)

2. **Update GraphService::getGraph():**
   ```php
   if ($version === 'latest') {
       // 'latest' means "current state" - includes draft if exists
       if ($hasActiveDraft) {
           $nodes = $draftPayload['nodes'];
           $graph['status'] = 'draft';
       } else {
           // No draft - load from main table or latest version
           // Keep current behavior (already correct)
       }
   } elseif ($version === 'published') {
       // 'published' means "latest published version" - NEVER override with draft
       // Load from version snapshot or main table
       // Skip draft check entirely
       $versionData = $this->loadLatestPublishedVersion($graphId);
       if ($versionData) {
           $nodes = $versionData['payload']['nodes'];
           $edges = $versionData['payload']['edges'];
       } else {
           // Fallback to main table
           $nodes = $graphRepo->findNodes($graphId);
           $edges = $graphRepo->findEdges($graphId);
       }
   }
   ```

3. **Update Frontend:**
   - When viewing Published version, send `version='published'` instead of `version='latest'`

---

## 📋 Verification Steps

After fix, verify:

1. **View Published (no draft):**
   - Should show correct positions/config
   - Status = 'published'

2. **Create Draft:**
   - Draft created with correct data

3. **View Published (with draft):**
   - Should show Published version data (not draft)
   - Positions/config should match before draft creation
   - Status = 'published'

4. **View Draft:**
   - Should show draft data (may differ from published)
   - Status = 'draft'

5. **Discard Draft:**
   - Published version unchanged

---

## Related Issues

- `NODE_POSITION_DRIFT_ANALYSIS.md` - Position drift between sources
- `CREATE_DRAFT_FROM_PUBLISHED_FIX.md` - Draft creation fixes

---

## Impact Assessment

**Severity:** P0 Critical

**Affected Users:**
- Users viewing Published versions while draft exists
- Users comparing Published vs Draft
- Production systems where drafts are common

**Data Integrity:**
- Published version data appears incorrect (but not actually corrupted in DB)
- Version snapshot is correct
- Main table may differ from version snapshot (separate issue)

**Business Impact:**
- High - Users lose trust in version system
- Users may make decisions based on incorrect data
- Production workflows affected

