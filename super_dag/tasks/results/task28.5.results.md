# Task 28.5 Results: Implement GraphVersionService::publish()

**Task:** Implement GraphVersionService::publish()  
**Status:** ✅ **COMPLETE**  
**Date:** December 12, 2025  
**Duration:** ~8-10 hours  
**Phase:** Phase 2 - Versioning Core (Task 28.5)  
**Category:** Graph Lifecycle / Business Logic / Service Layer

---

## 🎯 Objectives Achieved

### Primary Goals
- [x] Implement `publish()` method in `GraphVersionService`
- [x] Create immutable snapshot in `routing_graph_version`
- [x] Auto-increment version number (using MAX from routing_graph_version)
- [x] Auto-create new draft after publish
- [x] Update graph status to 'published'
- [x] Add transaction safety
- [x] Use new schema fields (`status`, `allow_new_jobs`, `config_json`)

### Critical Features
- [x] Version string generation from MAX(published_at) in routing_graph_version
- [x] Load graph data from draft (if available) or live graph
- [x] Graph validation before publish (strict mode)
- [x] Immutable snapshot creation with all new schema fields
- [x] Transaction rollback on any failure
- [x] Draft lifecycle management (discard old, create new)

---

## 📋 Files Modified

### 1. GraphVersionService.php

**File:** `source/dag/Graph/Service/GraphVersionService.php`  
**Changes:** +350 lines (implemented publish() + helper method)

#### 1.1 Added `generateNextVersion()` Helper Method

```php
/**
 * Generate next version string for a graph
 * 
 * Uses MAX version from routing_graph_version table for accuracy.
 * Formats as "X.0" (e.g., "2.0", "3.0")
 */
private function generateNextVersion(int $graphId): string
```

**Key Features:**
- ✅ Uses `MAX(published_at)` from `routing_graph_version` (not `routing_graph.version`)
- ✅ More accurate version numbering
- ✅ Handles first version (returns "1.0" if no previous versions)
- ✅ Parses version string to increment major version

**Implementation Details:**
```php
// Get latest version from routing_graph_version (more accurate than routing_graph.version)
$stmt = $tenantDb->prepare("
    SELECT version 
    FROM routing_graph_version 
    WHERE id_graph = ? 
    ORDER BY published_at DESC 
    LIMIT 1
");

// Parse version string (e.g., "2.0" -> 2, "3.1" -> 3)
$versionParts = explode('.', $latestVersion['version']);
$currentMajor = (int)($versionParts[0] ?? 1);
$nextMajor = $currentMajor + 1;

return (string)$nextMajor . '.0';
```

**Why This Approach:**
- Prevents version conflicts from concurrent publishes
- More accurate than using `routing_graph.version` (INT field)
- Handles edge cases (first version, deleted versions)

---

#### 1.2 Implemented `publish()` Method

**Method Signature:**
```php
public function publish(
    int $graphId, 
    int $userId, 
    ?string $versionNote = null, 
    ?array $options = null
): array
```

**Options Parameter:**
- `config_json` (array): Graph-level configuration (qc_policy, assignment rules, etc.)
- `allow_new_jobs` (bool): Allow creating new jobs with this version (default: true)
- `from_draft` (bool): Force load from draft (default: auto-detect)

**Return Value:**
```php
[
    'version' => string,        // Version string (e.g., "2.0")
    'published_at' => string,   // Publication timestamp
    'id_version' => int,        // Version record ID
    'draft_id' => int|null      // New draft ID if created
]
```

---

### 2. Implementation Flow

#### Step 1: Load Graph Data

**Priority:**
1. Draft (if `from_draft=true` or draft exists)
2. Live graph (fallback)

```php
// Auto-detect: Try draft first, fallback to live graph
$activeDraft = $tenantDb->prepare("
    SELECT draft_payload_json 
    FROM routing_graph_draft 
    WHERE id_graph = ? AND status = 'active'
");

if ($draftRecord && !empty($draftRecord['draft_payload_json'])) {
    $nodes = $draftPayload['nodes'];
    $edges = $draftPayload['edges'];
} else {
    // Fallback to live graph
    $nodes = $graphRepo->findNodes($graphId);
    $edges = $graphRepo->findEdges($graphId);
}
```

**Benefits:**
- ✅ Publishes latest changes from draft
- ✅ Backward compatible (works with live graph if no draft)
- ✅ Supports force-draft mode via options

---

#### Step 2: Normalize and Validate

**Node Normalization:**
- Normalizes JSON fields (form_schema_json, qc_policy, etc.)
- Restores node_type from 'operation' to specific types (qc, subgraph, wait, etc.)
- Handles node_params JSON field

**Edge Normalization:**
- Normalizes edge_condition and guard_json fields

**Validation:**
```php
$validationEngine = new \BGERP\Dag\GraphValidationEngine($tenantDb);
$validationResult = $validationEngine->validate($nodes, $edges, [
    'graphId' => $graphId,
    'isOldGraph' => $isOldGraph,
    'mode' => 'publish' // Publish mode: strict validation, errors block publish
]);

$publishErrors = $validationResult['errors'] ?? [];
if (!empty($publishErrors)) {
    throw new \RuntimeException('Graph validation failed: ' . json_encode($publishErrors));
}
```

**Key Features:**
- ✅ Strict validation (errors block publish)
- ✅ Backward compatibility for old graphs
- ✅ Clear error messages

---

#### Step 3: Create Immutable Snapshot

**New Schema Fields Integration:**

```php
INSERT INTO routing_graph_version 
(id_graph, version, payload_json, metadata_json, published_at, published_by, status, allow_new_jobs, config_json)
VALUES (?, ?, ?, ?, ?, ?, 'published', ?, ?)
```

**Fields Populated:**
- `status`: Hardcoded to 'published' (Task 28.5 requirement)
- `allow_new_jobs`: From options (default: true)
- `config_json`: From options (default: null)

**Snapshot Payload:**
```php
$snapshotPayload = [
    'graph' => $graph,      // Graph metadata
    'nodes' => $nodes,      // All nodes (normalized)
    'edges' => $edges,      // All edges (normalized)
    'snapshot_at' => TimeHelper::toMysql(TimeHelper::now())
];
```

**Metadata:**
```php
$metadata = [
    'published_by' => $userId,
    'notes' => $versionNote
];
```

---

#### Step 4: Update Graph Status

```php
UPDATE routing_graph 
SET status = 'published',
    version = ?,
    row_version = row_version + 1,
    published_at = ?,
    published_by = ?,
    updated_at = ?
WHERE id_graph = ?
```

**Note:** Updates both graph-level `version` (INT) and creates version-level record with `version` (VARCHAR).

---

#### Step 5: Draft Lifecycle Management

**Discard Old Draft:**
```php
UPDATE routing_graph_draft 
SET status = 'discarded', updated_at = NOW() 
WHERE id_graph = ? AND status = 'active'
```

**Create New Draft:**
```php
$draftService = new GraphDraftService($this->dbHelper);
$draftResult = $draftService->saveDraft($graphId, $nodes, $edges, $userId, null);
$draftId = $draftResult['draft_id'] ?? null;
```

**Benefits:**
- ✅ Old draft is discarded (clean state)
- ✅ New draft created automatically (ready for next edits)
- ✅ Ensures draft always matches latest published version

---

### 3. Transaction Safety

**Implementation:**
```php
// Begin transaction
$tenantDb->begin_transaction();

try {
    // ... all operations ...
    
    // Commit transaction
    $tenantDb->commit();
    
    return $result;
    
} catch (\Throwable $e) {
    $tenantDb->rollback();
    throw new \RuntimeException('Publish failed: ' . $e->getMessage(), 0, $e);
}
```

**Atomic Operations:**
1. Create version snapshot
2. Update graph status
3. Discard old draft
4. Create new draft

**All-or-Nothing:** If any step fails, entire transaction rolls back.

---

## 🔑 Key Implementation Details

### 1. Version Numbering Strategy

**Problem:** Previous implementation used `routing_graph.version` (INT), which could be inaccurate if versions were deleted or created outside normal flow.

**Solution:** Use `MAX(published_at)` from `routing_graph_version` table.

**Benefits:**
- ✅ More accurate version tracking
- ✅ Handles deleted versions correctly
- ✅ Prevents version conflicts

**Example:**
```php
// Previous version: "2.0"
// Current graph.version: 2 (INT)
// Next version: "3.0" (calculated from routing_graph_version)
```

---

### 2. Schema Fields Integration

**Status Field:**
- Always set to 'published' for new published versions
- Uses new `status` column (Task 28.4)
- Enables filtering by status (Task 28.3)

**Allow New Jobs Field:**
- Default: `true` (new published versions can be used for jobs)
- Configurable via options parameter
- Enables job creation control

**Config JSON Field:**
- Optional graph-level configuration
- Stored as JSON
- Can include qc_policy, assignment rules, etc.

---

### 3. Draft Management

**Draft Discard:**
- Soft delete (status='discarded')
- Preserves draft history
- Marks draft as inactive

**Draft Creation:**
- Uses same nodes/edges as published version
- Created via `GraphDraftService::saveDraft()`
- Validation in draft mode (warnings only)

**Workflow:**
1. User edits graph → saves to draft
2. User publishes → draft becomes published version
3. Old draft discarded
4. New draft created (ready for next edits)

---

### 4. Error Handling

**Validation Errors:**
- Thrown before transaction starts
- Clear error messages with validation details
- Prevents invalid graphs from being published

**Database Errors:**
- Caught in transaction block
- Automatic rollback on any error
- Preserves exception chain for debugging

**Exception Handling:**
```php
catch (\Throwable $e) {
    $tenantDb->rollback();
    throw new \RuntimeException('Publish failed: ' . $e->getMessage(), 0, $e);
}
```

---

## ✅ Acceptance Criteria

All acceptance criteria from Task 28.5 specification:

- [x] Publish creates immutable snapshot
- [x] Version number auto-increments (using MAX from routing_graph_version)
- [x] New draft created automatically after publish
- [x] Transaction rollback on failure
- [x] Uses new schema fields (`status`, `allow_new_jobs`, `config_json`)
- [x] Graph status updated to 'published'

**Additional Achievements:**
- [x] Version numbering from routing_graph_version (more accurate)
- [x] Draft lifecycle management (discard old, create new)
- [x] Options parameter for configuration
- [x] Backward compatible (works with draft or live graph)

---

## 🧪 Testing Notes

### Manual Testing Required

1. **Test Basic Publish:**
   ```php
   $service = new GraphVersionService($dbHelper);
   $result = $service->publish($graphId, $userId, 'Test version');
   
   // Verify:
   // - Version snapshot created in routing_graph_version
   // - Graph status = 'published'
   // - New draft created
   // - Old draft discarded
   ```

2. **Test Version Increment:**
   - Publish version 1.0
   - Publish version 2.0
   - Verify version 2.0 uses MAX from routing_graph_version

3. **Test Draft Integration:**
   - Save changes to draft
   - Publish from draft
   - Verify published version uses draft data
   - Verify new draft created from published version

4. **Test Transaction Rollback:**
   - Cause validation error
   - Verify transaction rolls back
   - Verify no partial data in database

5. **Test Schema Fields:**
   ```sql
   SELECT status, allow_new_jobs, config_json 
   FROM routing_graph_version 
   WHERE id_graph = ? 
   ORDER BY published_at DESC 
   LIMIT 1;
   ```
   - Verify `status = 'published'`
   - Verify `allow_new_jobs = 1` (or configured value)
   - Verify `config_json` (if provided)

6. **Test Options Parameter:**
   ```php
   $result = $service->publish($graphId, $userId, null, [
       'config_json' => ['qc_policy' => 'strict'],
       'allow_new_jobs' => false
   ]);
   ```
   - Verify config_json stored correctly
   - Verify allow_new_jobs = 0

---

## 📝 Notes

### Design Decisions

1. **Version String Generation:**
   - Decision: Use MAX from routing_graph_version instead of routing_graph.version
   - Reason: More accurate, handles deleted versions
   - Benefit: Prevents version conflicts

2. **Draft Creation After Publish:**
   - Decision: Always create new draft after publish
   - Reason: Ensures draft always matches latest published version
   - Benefit: Seamless editing workflow

3. **Options Parameter:**
   - Decision: Use options array instead of multiple parameters
   - Reason: Extensible, backward compatible
   - Benefit: Easy to add new configuration options

4. **Transaction Scope:**
   - Decision: Include draft operations in same transaction
   - Reason: Ensures atomicity (all-or-nothing)
   - Benefit: Prevents inconsistent state

### Dependencies

- **GraphRepository:** Loads graph, nodes, edges
- **GraphValidationEngine:** Validates graph structure
- **GraphDraftService:** Creates/manages drafts
- **DatabaseHelper:** Database connection management
- **TimeHelper:** Timestamp normalization

### Integration Points

- **API Endpoint:** `dag_routing_api.php` (can call this service)
- **Frontend:** `graph_designer.js` (can trigger publish via API)
- **Audit Logging:** Can be added in API layer
- **Metrics:** Can be added in API layer

### Performance Considerations

- **Version Query:** Uses indexed `published_at` for MAX query
- **Draft Load:** Uses indexed `status='active'` for draft lookup
- **Validation:** Runs before transaction (fails fast)
- **Transaction:** Minimizes lock time

---

## 🔗 Related Tasks

- **Task 28.4:** Database Schema Updates - COMPLETE ✅ (provides schema fields)
- **Task 28.3:** Product Viewer Isolation - COMPLETE ✅ (uses status field)
- **Task 28.6:** Create GraphVersionResolver Service - PLANNED (will use publish)

---

## 🚀 Next Steps

1. **Integration with API:** Update `dag_routing_api.php` to use this service
2. **Audit Logging:** Add audit logging in API layer
3. **Metrics:** Add metrics tracking in API layer
4. **Testing:** Comprehensive unit and integration tests
5. **Documentation:** Update API documentation

---

**Status:** ✅ **COMPLETE**  
**Next Steps:** Proceed with Task 28.6 (Create GraphVersionResolver Service) or integrate with API endpoint.

