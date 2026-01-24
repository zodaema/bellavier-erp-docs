# Task 28.6 Results: Create GraphVersionResolver Service

**Task:** Create GraphVersionResolver Service  
**Status:** ✅ **COMPLETE**  
**Date:** December 12, 2025  
**Duration:** ~6-8 hours  
**Phase:** Phase 2 - Versioning Core (Task 28.6)  
**Category:** Graph Lifecycle / Business Logic / Service Layer

---

## 🎯 Objectives Achieved

### Primary Goals
- [x] Create `GraphVersionResolver` service
- [x] Implement `resolveGraphForProduct($productId)`
- [x] Implement `resolveGraphForJob($jobId)`
- [x] Enforce resolution rules (Section 5.1 of concept doc)
- [x] Draft versions rejected in production context
- [x] Clear error messages

### Critical Features
- [x] Product resolution uses published snapshot only
- [x] Job resolution uses snapshot from job creation
- [x] Draft rejection with explicit error messages
- [x] Backward compatible (handles NULL status field)
- [x] Returns all new schema fields

---

## 📋 Files Created

### 1. GraphVersionResolver.php

**File:** `source/dag/Graph/Service/GraphVersionResolver.php`  
**Lines:** ~350 lines  
**Namespace:** `BGERP\Dag\Graph\Service`

#### 1.1 Class Structure

```php
class GraphVersionResolver
{
    private DatabaseHelper $dbHelper;
    
    public function __construct(DatabaseHelper $dbHelper)
    
    // Main resolution methods
    public function resolveGraphForProduct(int $productId, ?string $pinVersion = null): array
    public function resolveGraphForJob(int $jobId): array
    
    // Helper methods
    public function resolveGraphVersionById(int $idVersion): array
    public function getParsedSnapshot(array $versionData): array
}
```

---

### 2. Method Implementations

#### 2.1 `resolveGraphForProduct()` - Product Resolution

**Purpose:** Resolve graph version for product context (Section 5.1.1)

**Rules Enforced:**
- ✅ Returns published snapshot ONLY (never draft)
- ✅ Supports pinned version or latest published
- ✅ Rejects draft versions explicitly
- ✅ Clear error messages

**Implementation:**
```php
public function resolveGraphForProduct(int $productId, ?string $pinVersion = null): array
{
    // 1. Get active binding for product
    $binding = ProductGraphBindingHelper::getActiveBinding($tenantDb, $productId);
    
    // 2. Resolve version (pinned or latest published)
    if ($pinVersion !== null && $pinVersion !== '') {
        // Resolve to pinned published version
        // Reject draft versions explicitly
    } else {
        // Auto-resolve to latest published version
    }
    
    // 3. Return full version data with new schema fields
    return [
        'id_version' => int,
        'version' => string,
        'graph_id' => int,
        'payload_json' => string,
        'status' => string,
        'published_at' => string,
        'published_by' => int|null,
        'allow_new_jobs' => bool,
        'config_json' => string|null
    ];
}
```

**Key Features:**
- Uses `ProductGraphBindingHelper::getActiveBinding()` for binding lookup
- Supports `graph_version_pin` from binding or parameter
- Validates status field (rejects 'draft', allows 'published'/'retired')
- Backward compatible (handles NULL status field)

**Error Handling:**
- `RuntimeException` if product not found
- `RuntimeException` if binding not found
- `RuntimeException` if draft version attempted
- `RuntimeException` if version not found

---

#### 2.2 `resolveGraphForJob()` - Job Resolution

**Purpose:** Resolve graph version for job execution (Section 5.1.3)

**Rules Enforced:**
- ✅ Uses snapshot from job creation (immutable)
- ✅ Loads from job_ticket.graph_version
- ✅ Fallback to job_graph_instance
- ✅ Ensures job uses same workflow throughout lifecycle

**Implementation:**
```php
public function resolveGraphForJob(int $jobId): array
{
    // 1. Try to get graph_version from job_ticket
    $job = $tenantDb->prepare("
        SELECT graph_version, id_routing_graph 
        FROM job_ticket 
        WHERE id_job_ticket = ?
    ");
    
    // 2. Fallback to job_graph_instance if not found
    if (!$graphVersion || !$graphId) {
        // Try job_graph_instance
    }
    
    // 3. Load version snapshot
    $versionRecord = $tenantDb->prepare("
        SELECT * FROM routing_graph_version 
        WHERE id_graph = ? AND version = ?
    ");
    
    // 4. Return full version data
    return [...];
}
```

**Key Features:**
- Primary source: `job_ticket.graph_version`
- Fallback: `job_graph_instance.graph_version`
- Validates snapshot exists (throws if deleted)
- Returns immutable snapshot data

**Error Handling:**
- `RuntimeException` if job not found
- `RuntimeException` if version snapshot not found
- `RuntimeException` if snapshot was deleted

---

#### 2.3 `resolveGraphVersionById()` - Direct Lookup

**Purpose:** Helper method for direct version lookup by ID

**Use Cases:**
- When version ID is already known
- For internal service calls
- For testing/debugging

**Implementation:**
```php
public function resolveGraphVersionById(int $idVersion): array
{
    // Direct lookup by id_version
    // Returns full version data
}
```

---

#### 2.4 `getParsedSnapshot()` - Payload Parser

**Purpose:** Parse payload_json to structured data

**Use Cases:**
- Extract graph, nodes, edges from snapshot
- For graph loading/display
- For comparison operations

**Implementation:**
```php
public function getParsedSnapshot(array $versionData): array
{
    $payload = json_decode($versionData['payload_json'], true);
    
    return [
        'graph' => $payload['graph'],
        'nodes' => $payload['nodes'] ?? [],
        'edges' => $payload['edges'] ?? [],
        'snapshot_at' => $payload['snapshot_at'] ?? null
    ];
}
```

---

## 🔑 Key Implementation Details

### 1. Resolution Rules Enforcement

**Product Resolution (Section 5.1.1):**
- ✅ Published snapshot ONLY
- ✅ Draft rejection with clear error
- ✅ Pinned version support
- ✅ Latest published fallback

**Job Resolution (Section 5.1.3):**
- ✅ Snapshot from job creation
- ✅ Immutable throughout job lifecycle
- ✅ Fallback to job_graph_instance
- ✅ Error if snapshot missing

---

### 2. Draft Rejection Logic

**Explicit Rejection:**
```php
// Task 28.6: Reject Draft versions explicitly (CRITICAL - production safety)
if (isset($versionRecord['status']) && $versionRecord['status'] === 'draft') {
    throw new \RuntimeException("Draft versions cannot be used in product context. Version '{$versionPin}' is a draft.");
}
```

**Status Validation:**
```php
// Allow 'published' or 'retired' (or NULL if status field doesn't exist yet)
if (isset($versionRecord['status']) && !in_array($versionRecord['status'], ['published', 'retired'])) {
    throw new \RuntimeException("Version '{$versionPin}' has invalid status '{$versionRecord['status']}'. Only published or retired versions can be used in product context.");
}
```

**Benefits:**
- ✅ Prevents draft versions in production
- ✅ Clear error messages
- ✅ Backward compatible (handles NULL status)

---

### 3. Backward Compatibility

**Status Field Handling:**
```php
// Backward compatible: If status field doesn't exist, published_at IS NOT NULL is sufficient
WHERE published_at IS NOT NULL
    AND (status IS NULL OR status IN ('published', 'retired'))
    AND (status != 'draft' OR status IS NULL)
```

**Default Values:**
```php
'status' => $versionRecord['status'] ?? 'published',
'allow_new_jobs' => (bool)($versionRecord['allow_new_jobs'] ?? true),
```

**Benefits:**
- ✅ Works with existing databases
- ✅ Graceful degradation
- ✅ No breaking changes

---

### 4. Error Messages

**Clear and Actionable:**
- "No active graph binding found for product {id}"
- "Version '{version}' not found for graph {id}"
- "Draft versions cannot be used in product context"
- "Job {id} does not have graph version snapshot"
- "Graph version snapshot '{version}' not found"

**Benefits:**
- ✅ Easy debugging
- ✅ User-friendly messages
- ✅ Actionable errors

---

## ✅ Acceptance Criteria

All acceptance criteria from Task 28.6 specification:

- [x] Product resolution uses published snapshot only
- [x] Job resolution uses snapshot from job creation
- [x] Draft versions rejected in production context
- [x] Clear error messages
- [x] Enforces resolution rules (Section 5.1)

**Additional Achievements:**
- [x] Helper methods (resolveGraphVersionById, getParsedSnapshot)
- [x] Backward compatible (handles NULL status field)
- [x] Returns all new schema fields
- [x] Comprehensive error handling

---

## 🧪 Testing Notes

### Manual Testing Required

1. **Test Product Resolution:**
   ```php
   $resolver = new GraphVersionResolver($dbHelper);
   $version = $resolver->resolveGraphForProduct($productId);
   
   // Verify:
   // - Returns published version only
   // - Rejects draft versions
   // - Supports pinned version
   // - Falls back to latest published
   ```

2. **Test Job Resolution:**
   ```php
   $version = $resolver->resolveGraphForJob($jobId);
   
   // Verify:
   // - Uses snapshot from job creation
   // - Returns immutable snapshot
   // - Handles missing snapshot gracefully
   ```

3. **Test Draft Rejection:**
   - Try to resolve draft version for product
   - ✅ Should throw RuntimeException with clear message

4. **Test Error Handling:**
   - Product without binding
   - Job without version snapshot
   - Deleted version snapshot
   - ✅ Should throw clear error messages

---

## 📝 Notes

### Design Decisions

1. **Service-Based Approach:**
   - Decision: Create dedicated service instead of helper methods
   - Reason: Centralizes resolution logic, easier to test
   - Benefit: Reusable, maintainable

2. **Error Handling:**
   - Decision: Throw RuntimeException with clear messages
   - Reason: Fail fast, clear debugging
   - Benefit: Easy to catch and handle

3. **Backward Compatibility:**
   - Decision: Handle NULL status field gracefully
   - Reason: Works with existing databases
   - Benefit: No migration required

### Dependencies

- **ProductGraphBindingHelper:** For product binding lookup
- **DatabaseHelper:** Database connection management
- **routing_graph_version table:** Version snapshots
- **job_ticket table:** Job version snapshots

### Integration Points

- **ProductGraphBindingHelper:** Can use resolver instead of direct queries
- **JobCreationService:** Can use resolver for job version resolution
- **API Endpoints:** Can use resolver for product/job graph loading

### Next Steps

1. **Integration:** Update ProductGraphBindingHelper to use resolver (optional)
2. **Integration:** Update JobCreationService to use resolver (optional)
3. **Testing:** Comprehensive unit and integration tests
4. **Documentation:** Update API documentation

---

## 🔗 Related Tasks

- **Task 28.3:** Product Viewer Isolation - COMPLETE ✅ (enforces published-only)
- **Task 28.5:** Implement GraphVersionService::publish() - COMPLETE ✅ (creates versions)
- **Task 28.4:** Database Schema Updates - COMPLETE ✅ (provides schema fields)

---

**Status:** ✅ **COMPLETE**  
**Next Steps:** Proceed with Phase 3 (UX tasks) or integrate resolver into existing code.

