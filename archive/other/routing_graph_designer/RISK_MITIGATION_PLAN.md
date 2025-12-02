# Routing Graph Designer - Risk Mitigation Plan

**Created:** November 10, 2025  
**Updated:** November 10, 2025 (v2.0 - Enhanced)  
**Status:** Planning Phase → Ready for Phase 1 Implementation  
**Priority:** High (Enterprise Production Readiness)

**Changes in v2.0:**
- ✅ Moved R5 (Unique Constraints) and R9 (Soft Validation) to P0/Phase 1
- ✅ Added Owner/Gate/Rollback columns to Risk Matrix
- ✅ Added Feature Flags (Kill-switches) for all P0 items
- ✅ Enhanced Schema Validation (includes publish check + health endpoint)
- ✅ Added Minimal Test Matrix (10 test cases)
- ✅ Mapped Success Criteria to Metrics
- ✅ Added Communication Playbook

---

## Executive Summary

This document outlines identified risks and mitigation strategies for the Routing Graph Designer system. Risks are prioritized by severity and impact, with implementation phases designed to address critical issues first.

---

## Risk Assessment Matrix

| Risk ID | Risk Description | Severity | Impact | Priority | Phase | Owner | Gate | Rollback Plan |
|---------|-----------------|----------|--------|----------|-------|-------|------|---------------|
| R1 | ETag header format incorrect | High | Medium | **P0** | Phase 1 | Backend Team | Unit + Integration | ✅ Completed |
| R2 | Schema drift vulnerability | High | High | **P0** | Phase 1 | Backend Team | Integration + Health Check | Feature flag: `schema_validation_enabled` |
| R3 | Accidental edge deletion | Critical | High | **P0** | Phase 1 | Full Stack | E2E + Manual | Feature flag: `protect_purge_edges` |
| R5 | Missing unique constraints | Medium | Medium | **P0** | Phase 1 | Backend Team | Unit + Integration | Migration rollback |
| R9 | No validation on save | Medium | Medium | **P0** | Phase 1 | Backend Team | Unit + Integration | Feature flag: `draft_soft_validate_on_save` |
| R12 | Missing If-Match enforcement | High | High | **P0** | Phase 1 | Backend Team | Integration + E2E | Feature flag: `enforce_if_match` |
| R4 | Inconsistent concurrency control | High | High | **P1** | Phase 2 | Backend Team | Integration | N/A (already in transaction) | ✅ Completed |
| R8 | Incomplete audit trail | Medium | Medium | **P1** | Phase 2 | Backend Team | Unit | Feature flag: `audit_logging_enabled` | ✅ Completed |
| R13 | Edge delete/insert integrity | Medium | Medium | **P1** | Phase 2 | Backend Team | Integration | Transaction rollback | ✅ Completed |
| R6 | JSON column type inconsistency | Medium | Low | **P2** | Phase 3 | Backend Team | Integration | Migration rollback | ✅ Completed |
| R7 | Permission code inconsistency | Medium | Medium | **P2** | Phase 3 | Backend Team | Unit | Permission mapping fallback | ✅ Completed |
| R10 | N+1 query performance | Low | Low | **P3** | Phase 4 | Backend Team | Performance Test | Query optimization rollback | ✅ Completed |
| R11 | Rate limit granularity | Low | Low | **P3** | Phase 4 | Backend Team | Load Test | Rate limit config rollback | ✅ Completed |
| R14 | Monitoring gaps | Low | Low | **P3** | Phase 4 | DevOps Team | Dashboard Review | Monitoring config rollback | ✅ Completed |
| R15 | Auto-save indicator stuck | Medium | Medium | **P0** | Phase 1 | Frontend Team | Browser Test | ✅ Completed |

**Priority Levels:**
- **P0**: Critical - Must fix immediately (Phase 1)
- **P1**: High - Fix in next phase (Phase 2)
- **P2**: Medium - Fix when time permits (Phase 3)
- **P3**: Low - Nice to have (Phase 4)

---

## Phase 1: Critical Fixes (Week 1-2)

**Goal:** Fix critical concurrency, data integrity, and safety issues

**Feature Flags (Kill-switches):**
- `enforce_if_match` - Enable If-Match header enforcement (default: true)
- `protect_purge_edges` - Require confirm_purge flag for edge deletion (default: true)
- `draft_soft_validate_on_save` - Enable soft validation on save (default: true)
- `schema_validation_enabled` - Enable schema preflight checks (default: true)

**Feature Flag Implementation:**
```php
// In config.php or feature flag service
function getFeatureFlag(string $key, bool $default = false): bool {
    // Check routing_graph_feature_flag table or config
    // For system-level flags, use config.php
    return defined("FEATURE_{$key}") ? constant("FEATURE_{$key}") : $default;
}
```

### R1: ETag Header Format Correction ✅ COMPLETED

**Status:** ✅ Implemented

**Current Issue:**
```php
header('ETag: "W/' . $etag . '"');  // Wrong: quotes around W/
```

**Correct Format:**
```php
header('ETag: W/"' . $etag . '"');  // Correct: W/"hash"
```

**Files to Update:**
- `source/dag_routing_api.php` (all `graph_get`, `graph_save`, `graph_publish`)

**Implementation:**
```php
// Helper function
function setETagHeader(string $etag): void {
    header('ETag: W/"' . $etag . '"');
}

// Usage
setETagHeader($newEtag);
```

**Testing:**
- Verify ETag header format in browser DevTools
- Test with multiple browsers (Chrome, Firefox, Safari)
- Verify cache behavior with `If-None-Match`

---

### R3: Prevent Accidental Edge Deletion

**Current Issue:**
Empty edge list in save payload causes all edges to be deleted.

**Solution:**
Require explicit confirmation flag for purge operations.

**Implementation:**
```php
// In graph_save case
$edges = $_POST['edges'] ?? [];
$confirmPurge = ($_POST['confirm_purge'] ?? '0') === '1';

// If edges list is empty AND no confirm_purge flag
if (empty($edges) && !$confirmPurge) {
    json_error('empty_edge_list_requires_confirmation', 400, [
        'app_code' => 'DAG_ROUTING_400_PURGE_REQUIRED',
        'message' => 'Empty edge list requires confirm_purge=1 flag'
    ]);
}

// Only delete all edges if confirm_purge is set
if (empty($edges) && $confirmPurge) {
    // Log purge action for audit
    error_log("Graph {$graphId}: Purging all edges (confirmed)");
    // Proceed with deletion
}
```

**Frontend Update:**
```javascript
// In saveGraph function
if (edges.length === 0 && cy.edges().length > 0) {
    // Show confirmation dialog
    Swal.fire({
        title: 'Clear All Edges?',
        text: 'This will remove all connections. Continue?',
        icon: 'warning',
        showCancelButton: true
    }).then((result) => {
        if (result.isConfirmed) {
            // Add confirm_purge flag
            payload.confirm_purge = 1;
            // Continue save
        }
    });
}
```

---

### R12: Enforce If-Match Header ✅ COMPLETED

**Status:** ✅ Implemented

**Current Issue:**
API accepts saves without `If-Match` header, risking lost updates.

**Solution:**
Return `428 Precondition Required` if `If-Match` is missing.

**Feature Flag:** `enforce_if_match` (default: true)

**Implementation:**
```php
// In graph_save case
$ifMatch = $_SERVER['HTTP_IF_MATCH'] ?? null;
$enforceIfMatch = getFeatureFlag('enforce_if_match', true);

// Enforce If-Match for manual saves only (autosave handled separately)
if ($enforceIfMatch && !$isAutosave) {
    if (!$ifMatch || trim($ifMatch) === '') {
        json_error('precondition_required', 428, [
            'app_code' => 'DAG_ROUTING_428_IF_MATCH_REQUIRED',
            'message' => 'If-Match header is required for graph save operations',
            'hint' => 'Reload graph to get current ETag, then retry save'
        ]);
    }
}
```

**Exception:**
- Auto-save operations skip `If-Match` enforcement (handled separately)
- Can be disabled via feature flag for emergency rollback

**Implementation Status:** ✅ **COMPLETED**
- ✅ If-Match enforcement for manual saves
- ✅ Feature flag support (`enforce_if_match`)
- ✅ Autosave exception (no enforcement)
- ✅ Returns 428 Precondition Required when missing

**Testing:**
- ✅ Test manual save without `If-Match` → returns 428
- ✅ Test auto-save → works (no `If-Match` required)
- ✅ Test with feature flag disabled → allows save without If-Match

**Files Modified:**
- `source/dag_routing_api.php` (lines 1310-1323)

---

### R2: Schema Drift Prevention ✅ COMPLETED

**Status:** ✅ Implemented

**Current Issue:**
Schema changes can break queries without detection.

**Solution:**
Add preflight schema validation and health check endpoint.

**Implementation:**

1. **Schema Version Table:**
```sql
CREATE TABLE IF NOT EXISTS routing_schema_version (
    id INT PRIMARY KEY AUTO_INCREMENT,
    version VARCHAR(20) NOT NULL,
    checksum VARCHAR(64) NOT NULL COMMENT 'MD5 of expected schema',
    applied_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_version (version)
) ENGINE=InnoDB;
```

2. **Preflight Check Function:**
```php
function validateRoutingSchema(mysqli $db): array {
    $errors = [];
    $warnings = [];
    
    // Check critical columns
    $requiredColumns = [
        'routing_graph' => ['id_graph', 'row_version', 'etag', 'version', 'status'],
        'routing_node' => ['id_node', 'id_graph', 'node_code', 'node_type', 'team_category', 'production_mode'],
        'routing_edge' => ['id_edge', 'id_graph', 'from_node_id', 'to_node_id', 'edge_type']
    ];
    
    foreach ($requiredColumns as $table => $columns) {
        // Check if table exists
        $tableExists = $db->query("SHOW TABLES LIKE '{$table}'")->num_rows > 0;
        if (!$tableExists) {
            $errors[] = "Missing table: {$table}";
            continue;
        }
        
        $result = $db->query("SHOW COLUMNS FROM `{$table}`");
        $existingColumns = [];
        while ($row = $result->fetch_assoc()) {
            $existingColumns[] = $row['Field'];
        }
        
        foreach ($columns as $col) {
            if (!in_array($col, $existingColumns)) {
                $errors[] = "Missing column: {$table}.{$col}";
            }
        }
    }
    
    // Check indexes
    $requiredIndexes = [
        'routing_graph' => ['idx_code', 'idx_status'],
        'routing_node' => ['uniq_graph_node_code', 'idx_graph'],
        'routing_edge' => ['idx_graph', 'idx_from', 'idx_to']
    ];
    
    foreach ($requiredIndexes as $table => $indexes) {
        $result = $db->query("SHOW INDEXES FROM `{$table}`");
        $existingIndexes = [];
        while ($row = $result->fetch_assoc()) {
            $existingIndexes[] = $row['Key_name'];
        }
        
        foreach ($indexes as $idx) {
            if (!in_array($idx, $existingIndexes)) {
                $warnings[] = "Missing index: {$table}.{$idx}";
            }
        }
    }
    
    return [
        'valid' => empty($errors),
        'errors' => $errors,
        'warnings' => $warnings
    ];
}
```

3. **Health Check Endpoint:**
```php
// In platform_health_api.php or new endpoint
case 'routing_schema_check':
    $validation = validateRoutingSchema($tenantDb);
    json_success([
        'schema_valid' => $validation['valid'],
        'errors' => $validation['errors']
    ]);
```

---

### R5: Add Unique Constraints ✅ COMPLETED

**Priority:** P0 (moved from P1)  
**Reason:** Prevents node_code duplication which can cause reference ambiguity and break subsequent saves.

**Status:** ✅ **COMPLETED**

**Database-Level Constraint:**
- ✅ Unique constraint already exists in schema: `UNIQUE KEY uniq_graph_node_code (id_graph, node_code)`
- ✅ Defined in `0001_init_tenant_schema_v2.php` migration (line 897)
- ✅ Prevents duplicate node_code per graph at database level

**Application-Level Validation:**
```php
// In graph_save validation (before transaction)
function validateNodeCodes(array $nodes, int $graphId, DatabaseHelper $db): array {
    $errors = [];
    
    // Check for duplicate node_code in payload
    $nodeCodes = array_column($nodes, 'node_code');
    $duplicates = array_diff_assoc($nodeCodes, array_unique($nodeCodes));
    if (!empty($duplicates)) {
        $errors[] = 'Duplicate node_code in payload: ' . implode(', ', array_unique($duplicates));
    }
    
    // Check for conflicts with existing nodes (for updates)
    if (!empty($nodes)) {
        $existingNodeIds = array_filter(array_column($nodes, 'id_node'));
        $params = [$graphId];
        $types = 'i';
        
        if (!empty($existingNodeIds)) {
            $placeholders = implode(',', array_fill(0, count($existingNodeIds), '?'));
            $params = array_merge($params, $existingNodeIds);
            $types .= str_repeat('i', count($existingNodeIds));
            $existingCodes = $db->fetchAll("
                SELECT node_code FROM routing_node 
                WHERE id_graph = ? AND id_node NOT IN ($placeholders)
            ", $params, $types);
        } else {
            $existingCodes = $db->fetchAll("
                SELECT node_code FROM routing_node 
                WHERE id_graph = ?
            ", $params, $types);
        }
        
        $existingCodeSet = array_column($existingCodes, 'node_code');
        foreach ($nodeCodes as $code) {
            if (in_array($code, $existingCodeSet)) {
                $errors[] = "node_code '{$code}' already exists in graph";
            }
        }
    }
    
    return $errors;
}
```

**Implementation Status:** ✅ **COMPLETED**
- ✅ Database constraint: `UNIQUE KEY uniq_graph_node_code (id_graph, node_code)`
- ✅ Application-level validation: `validateNodeCodes()` function
- ✅ Validation called before transaction in `graph_save`
- ✅ Returns 400 error with `DAG_ROUTING_400_DUPLICATE_NODE_CODE` app code

**Testing:**
- ✅ Try to create two nodes with same node_code → returns 400 error
- ✅ Try to update node to existing node_code → returns 400 error
- ✅ Database constraint prevents duplicates even if validation is bypassed

**Files Modified:**
- `source/dag_routing_api.php` (lines 494-540: `validateNodeCodes()` function, line 1377: validation call)
- Database schema: `0001_init_tenant_schema_v2.php` (line 897: unique constraint)

---

### R9: Soft Validation on Save (MOVED FROM PHASE 2)

**Priority:** P0 (moved from P1)  
**Reason:** Prevents invalid graphs from being saved, reducing risk of production errors.

**Feature Flag:** `draft_soft_validate_on_save` (default: true)

**Implementation:**
```php
// In graph_save case (before transaction)
function validateGraphStructure(array $nodes, array $edges): array {
    $errors = [];
    $warnings = [];
    
    $validationEnabled = getFeatureFlag('draft_soft_validate_on_save', true);
    if (!$validationEnabled) {
        return ['valid' => true, 'errors' => [], 'warnings' => []];
    }
    
    // Hard validation: START node count
    $startNodes = array_filter($nodes, fn($n) => $n['node_type'] === 'start');
    if (count($startNodes) !== 1) {
        $errors[] = 'Graph must have exactly one START node (found: ' . count($startNodes) . ')';
    }
    
    // Hard validation: END node count
    $endNodes = array_filter($nodes, fn($n) => $n['node_type'] === 'end');
    if (count($endNodes) < 1) {
        $errors[] = 'Graph must have at least one END node';
    }
    
    // Hard validation: No cycles (use DAGValidationService)
    try {
        $cycleCheck = $validationService->checkCycles($nodes, $edges);
        if (!$cycleCheck['valid']) {
            $errors[] = 'Graph contains cycles: ' . implode(', ', $cycleCheck['errors']);
        }
    } catch (\Exception $e) {
        $warnings[] = 'Cycle check failed: ' . $e->getMessage();
    }
    
    // Soft validation: All nodes reachable from START
    $startNode = reset($startNodes);
    if ($startNode) {
        $reachable = $validationService->checkReachability($startNode['id_node'], $nodes, $edges);
        if (!$reachable['all_reachable']) {
            $warnings[] = 'Some nodes are not reachable from START: ' . implode(', ', $reachable['unreachable']);
        }
    }
    
    return [
        'valid' => empty($errors),
        'errors' => $errors,
        'warnings' => $warnings
    ];
}

// Usage in graph_save
$structureValidation = validateGraphStructure($nodes, $edges);

if (!$structureValidation['valid']) {
    json_error('validation_failed', 400, [
        'app_code' => 'DAG_ROUTING_400_VALIDATION',
        'errors' => $structureValidation['errors'],
        'warnings' => $structureValidation['warnings']
    ]);
}

// If warnings exist, mark graph as "draft_invalid" but allow save
if (!empty($structureValidation['warnings'])) {
    $graphStatus = 'draft_invalid';
    // Log warnings
    error_log("Graph {$graphId} saved with warnings: " . implode(', ', $structureValidation['warnings']));
} else {
    $graphStatus = 'draft';
}
```

**Frontend Display:**
```javascript
// In saveGraph success handler
if (response.warnings && response.warnings.length > 0) {
    Swal.fire({
        title: t('routing.validation_warnings', 'Validation Warnings'),
        html: '<div class="alert alert-warning"><ul><li>' + 
              response.warnings.join('</li><li>') + 
              '</li></ul></div>',
        icon: 'warning',
        confirmButtonText: t('common.ok', 'OK')
    });
}

if (response.status === 'draft_invalid') {
    // Show badge or indicator
    $('#graph-title').append('<span class="badge bg-warning ms-2">Needs Validation</span>');
}
```

**Testing:**
- Save graph with 0 START nodes → should return 400
- Save graph with 2 START nodes → should return 400
- Save graph with 0 END nodes → should return 400
- Save graph with cycle → should return 400
- Save graph with unreachable nodes → should return 200 with warnings

---

## Phase 2: Data Integrity & Validation (Week 3-4)

### R5: Add Unique Constraints (MOVED TO PHASE 1)

**Status:** ✅ Moved to Phase 1

---

### R5: Add Unique Constraints (Legacy - Reference Only)

**Note:** This section moved to Phase 1. Keeping for reference.

**Implementation:**
```sql
-- Migration: 2025_11_routing_unique_constraints.php

-- Ensure unique node_code per graph
ALTER TABLE routing_node 
ADD CONSTRAINT uniq_graph_node_code_unique 
UNIQUE (id_graph, node_code);

-- Add check constraint for start nodes (via trigger or application-level)
-- Note: MySQL doesn't support CHECK constraints in older versions
-- Use application-level validation instead
```

**Application-Level Validation:**
```php
// In graph_save validation
function validateGraphStructure(array $nodes): array {
    $errors = [];
    
    // Check for duplicate node_code
    $nodeCodes = array_column($nodes, 'node_code');
    $duplicates = array_diff_assoc($nodeCodes, array_unique($nodeCodes));
    if (!empty($duplicates)) {
        $errors[] = 'Duplicate node_code: ' . implode(', ', array_unique($duplicates));
    }
    
    // Check for exactly one START node
    $startNodes = array_filter($nodes, fn($n) => $n['node_type'] === 'start');
    if (count($startNodes) !== 1) {
        $errors[] = 'Graph must have exactly one START node';
    }
    
    // Check for at least one END node
    $endNodes = array_filter($nodes, fn($n) => $n['node_type'] === 'end');
    if (count($endNodes) < 1) {
        $errors[] = 'Graph must have at least one END node';
    }
    
    return $errors;
}
```

---

### R9: Soft Validation on Save

**Implementation:**
```php
// In graph_save case (before transaction)
$validation = validateGraphStructure($nodes);
$warnings = [];

if (!empty($validation['errors'])) {
    // Hard errors - reject save
    json_error('validation_failed', 400, [
        'app_code' => 'DAG_ROUTING_400_VALIDATION',
        'errors' => $validation['errors']
    ]);
}

// Soft warnings - allow save but mark as invalid
$warnings = validateGraphWarnings($nodes, $edges);
if (!empty($warnings)) {
    // Mark graph as "dirty" or "needs_validation"
    $graphStatus = 'draft_invalid';
} else {
    $graphStatus = 'draft';
}

// Return warnings in response
json_success([
    'id' => $graphId,
    'warnings' => $warnings,
    'status' => $graphStatus
]);
```

**Frontend Display:**
```javascript
if (response.warnings && response.warnings.length > 0) {
    Swal.fire({
        title: 'Validation Warnings',
        html: '<ul><li>' + response.warnings.join('</li><li>') + '</li></ul>',
        icon: 'warning',
        confirmButtonText: 'OK'
    });
}
```

---

### R8: Audit Trail ✅ COMPLETED

**Status:** ✅ Implemented

**Implementation:**

1. **Create Audit Table:**
```sql
CREATE TABLE routing_audit_log (
    id_log BIGINT PRIMARY KEY AUTO_INCREMENT,
    id_graph INT NOT NULL,
    action ENUM('save','publish','delete','node_create','node_update','node_delete','edge_create','edge_delete') NOT NULL,
    actor_id INT NOT NULL COMMENT 'User ID',
    actor_name VARCHAR(200) NULL,
    correlation_id VARCHAR(32) NULL,
    before_hash VARCHAR(64) NULL COMMENT 'MD5 of before state',
    after_hash VARCHAR(64) NULL COMMENT 'MD5 of after state',
    changes_summary JSON NULL COMMENT 'Summary of changes',
    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_graph (id_graph),
    INDEX idx_action (action),
    INDEX idx_actor (actor_id),
    INDEX idx_created (created_at),
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE CASCADE
) ENGINE=InnoDB;
```

2. **Audit Helper Function:**
```php
function logRoutingAudit(
    mysqli $db,
    int $graphId,
    string $action,
    int $actorId,
    ?string $beforeHash = null,
    ?string $afterHash = null,
    ?array $changesSummary = null
): void {
    $stmt = $db->prepare("
        INSERT INTO routing_audit_log 
        (id_graph, action, actor_id, before_hash, after_hash, changes_summary, correlation_id, ip_address, user_agent)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    
    $correlationId = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
    $ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;
    $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? null;
    $changesJson = $changesSummary ? json_encode($changesSummary) : null;
    
    $stmt->bind_param(
        'isississs',
        $graphId,
        $action,
        $actorId,
        $beforeHash,
        $afterHash,
        $changesJson,
        $correlationId,
        $ipAddress,
        $userAgent
    );
    $stmt->execute();
    $stmt->close();
}
```

3. **Usage in graph_save:**
```php
// Before save
$beforeHash = md5(json_encode([
    'nodes' => $currentNodes,
    'edges' => $currentEdges
]));

// After save
$afterHash = md5(json_encode([
    'nodes' => $newNodes,
    'edges' => $newEdges
]));

logRoutingAudit(
    $tenantDb,
    $graphId,
    'save',
    $userId,
    $beforeHash,
    $afterHash,
    [
        'nodes_added' => count($newNodes) - count($currentNodes),
        'edges_added' => count($newEdges) - count($currentEdges)
    ]
);
```

**Implementation Status:** ✅ **COMPLETED**
- ✅ Migration created: `2025_11_routing_audit_log.php`
- ✅ Audit table: `routing_audit_log` with all required fields
- ✅ Helper function: `logRoutingAudit()` with feature flag support
- ✅ Audit logging in `graph_save` (manual saves with before/after state)
- ✅ Audit logging in `graph_autosave_positions` (lightweight autosave)
- ✅ Audit logging in `graph_publish` (with version info)
- ✅ Feature flag: `audit_logging_enabled` (default: true)
- ✅ Actor name caching from member table
- ✅ Correlation ID support for request tracing
- ✅ IP address and user agent tracking

**Testing:**
- ✅ Verify audit logs are created on save/publish
- ✅ Verify feature flag can disable audit logging
- ✅ Verify before/after hashes are different when changes occur
- ✅ Verify correlation IDs are unique per request

**Files Modified:**
- `database/tenant_migrations/2025_11_routing_audit_log.php` (new migration)
- `source/dag_routing_api.php`:
  - Lines 506-583: `logRoutingAudit()` helper function
  - Lines 1400-1412: Before state capture in `graph_save`
  - Lines 1737-1767: Audit logging in `graph_save` (manual)
  - Lines 1889-1898: Audit logging in `graph_autosave_positions`
  - Lines 2130-2155: Audit logging in `graph_publish`

---

### R4: Consistent Concurrency Control ✅ COMPLETED

**Status:** ✅ Implemented

**Current Issue:**
Mixed use of ETag (from JSON) and row_version.

**Solution:**
Use `routing_graph.row_version` as single source of truth.

**Implementation Status:** ✅ **COMPLETED**
- ✅ All operations use `routing_graph.row_version` as single source of truth
- ✅ ETag is calculated from `row_version`: `md5($graphId . '|' . $rowVersion)`
- ✅ All design operations increment `routing_graph.row_version` atomically
- ✅ Optimistic locking uses `row_version` in WHERE clauses: `WHERE id_graph = ? AND row_version = ?`
- ✅ All database operations wrapped in transactions (`beginTransaction()` → `commit()` / `rollback()`)
- ✅ Transactions used in: `graph_save`, `graph_autosave_positions`, `graph_publish`

**Verification:**
- ✅ `graph_save`: Uses transaction, increments `row_version` atomically
- ✅ `graph_autosave_positions`: Uses transaction, increments `row_version` atomically
- ✅ `graph_publish`: Uses transaction, increments `row_version` atomically
- ✅ ETag always derived from `row_version` (not stored separately in JSON)
- ✅ Version conflicts detected via `row_version` mismatch (409 Conflict)

**Future Enhancement (Optional):**
If fine-grained locking is needed:
```sql
ALTER TABLE routing_node ADD COLUMN row_version INT NOT NULL DEFAULT 1;
ALTER TABLE routing_edge ADD COLUMN row_version INT NOT NULL DEFAULT 1;
```

---

### R13: Edge Delete/Insert Integrity

**Current Status:** ✅ Already handled in transaction

**Enhancement:**
Add explicit error handling for mid-transaction failures:
```php
try {
    $db->beginTransaction();
    
    // Delete edges not in new list
    // Insert/update edges
    
    $db->commit();
} catch (\Throwable $e) {
    $db->rollback();
    error_log("Edge update failed: " . $e->getMessage());
    json_error('edge_update_failed', 500, [
        'app_code' => 'DAG_ROUTING_500_EDGE_UPDATE'
    ]);
}
```

---

## Phase 3: Consistency & Standards (Week 5-6) ✅ COMPLETED

### R7: Permission Code Standardization ✅ COMPLETED

**Status:** ✅ **COMPLETED** (November 10, 2025)

**Current Issue:**
Mixed use of `hatthasilpa.routing.*` and `dag.routing.*`

**Solution Implemented:**
Created permission mapping with legacy fallback support.

**Implementation:**
```php
// In dag_routing_api.php
const ROUTING_PERMISSIONS = [
    'design' => 'dag.routing.design.view',
    'design.view' => 'dag.routing.design.view',
    'manage' => 'dag.routing.manage',
    'view' => 'dag.routing.view',
    'publish' => 'dag.routing.publish',
    'runtime.view' => 'dag.routing.runtime.view',
    // Legacy mappings (for backward compatibility)
    'hatthasilpa.manage' => 'hatthasilpa.routing.manage',
    'hatthasilpa.view' => 'hatthasilpa.routing.view',
    'hatthasilpa.runtime.view' => 'hatthasilpa.routing.runtime.view'
];

function must_allow_routing(array $member, string $permission, bool $allowLegacy = true): void {
    // Get full permission code from mapping
    $fullCode = ROUTING_PERMISSIONS[$permission] ?? $permission;
    
    // Check primary permission
    if (permission_allow_code($member, $fullCode)) {
        return; // Permission granted
    }
    
    // Fallback to legacy permissions if allowed
    if ($allowLegacy) {
        $legacyMappings = [
            'dag.routing.design.view' => 'hatthasilpa.routing.manage',
            'dag.routing.manage' => 'hatthasilpa.routing.manage',
            'dag.routing.view' => 'hatthasilpa.routing.view',
            'dag.routing.publish' => 'hatthasilpa.routing.manage',
            'dag.routing.runtime.view' => ['hatthasilpa.routing.runtime.view', 'hatthasilpa.routing.manage']
        ];
        
        $legacyCodes = $legacyMappings[$fullCode] ?? [];
        if (!is_array($legacyCodes)) {
            $legacyCodes = [$legacyCodes];
        }
        
        foreach ($legacyCodes as $legacyCode) {
            if (permission_allow_code($member, $legacyCode)) {
                return; // Legacy permission granted
            }
        }
    }
    
    // No permission granted - throw error
    json_error('insufficient_permissions', 403, [
        'app_code' => 'DAG_ROUTING_403_PERMISSION',
        'message' => "Permission required: {$fullCode}",
        'permission' => $fullCode
    ]);
}
```

**Generic Function Added:**
```php
// In permission.php - Reusable for other modules
function must_allow_module(array $member, string $module, string $permission, array $options = []): void {
    // Generic permission checker with legacy fallback support
    // Usage: must_allow_module($member, 'qc', 'view', ['legacy' => 'atelier.qc.view']);
}
```

**Migration Completed:**
- ✅ Updated all 21 API endpoints to use `must_allow_routing()`
- ✅ Legacy permissions (`hatthasilpa.routing.*`) automatically fallback
- ✅ Generic `must_allow_module()` function created for other modules
- ✅ No breaking changes - backward compatible

**Benefits:**
- Code readability: `'manage'` instead of `'hatthasilpa.routing.manage'`
- Legacy support: Automatic fallback to old permissions
- Maintainability: Change permission codes in one place
- Reusability: Generic function for other modules

---

### R6: JSON Column Type Consistency ✅ COMPLETED

**Status:** ✅ **COMPLETED** (November 10, 2025)

**Current Issue:**
Some tenants may have TEXT instead of JSON for JSON columns.

**Solution Implemented:**
Migration to ensure JSON type + application-level normalization function.

**Migration File:** `2025_11_json_column_consistency.php`

**Implementation:**
```php
// Migration: Ensure JSON columns
ALTER TABLE routing_node 
MODIFY COLUMN allowed_team_ids JSON NULL,
MODIFY COLUMN forbidden_team_ids JSON NULL,
MODIFY COLUMN node_config JSON NULL,
MODIFY COLUMN node_params JSON NULL;

ALTER TABLE routing_edge
MODIFY COLUMN edge_condition JSON NULL;
```

**Application-Level Handling:**
```php
// In dag_routing_api.php
function normalizeJsonField($value) {
    if ($value === null || $value === '') {
        return null;
    }
    
    // If already an array/object, return as-is
    if (is_array($value) || is_object($value)) {
        return $value;
    }
    
    // If string, try to decode
    if (is_string($value)) {
        $decoded = json_decode($value, true);
        if (json_last_error() === JSON_ERROR_NONE) {
            return $decoded;
        }
        // If decode failed, return null (invalid JSON)
        return null;
    }
    
    // Unknown type, return as-is
    return $value;
}
```

**Integration Points:**
- ✅ `evaluateEdgeConditions()` - Uses `normalizeJsonField()` for `edge_condition`
- ✅ `buildGraphResponse()` - Uses `normalizeJsonField()` for `node_config`
- ✅ Handles both JSON type (MySQL 5.7.8+) and TEXT type (legacy)

**Migration Features:**
- ✅ Checks MySQL version (requires 5.7.8+ for JSON type)
- ✅ Idempotent (safe to run multiple times)
- ✅ Only converts columns that are not already JSON type
- ✅ Graceful handling if columns don't exist

**Benefits:**
- Database consistency: All JSON columns use proper JSON type
- Application compatibility: Works with both JSON and TEXT types
- No data loss: Migration preserves existing data
- Backward compatible: Handles legacy TEXT columns gracefully

---

## Phase 4: Performance & Monitoring (Week 7-8) ✅ COMPLETED

### R10: N+1 Query Optimization ✅ COMPLETED

**Status:** ✅ **COMPLETED** (November 10, 2025)

**Current Issue:**
`graph_list` queried per-graph for latest version (N+1 query problem).

**Solution Implemented:**
Use self-join with derived table to get latest version for all graphs in one query.

**Implementation:**
```php
// Optimized query (single query instead of N+1)
$versionStmt = $tenantDb->prepare("
    SELECT 
        v1.id_graph,
        v1.published_at as last_published_at,
        v1.version
    FROM routing_graph_version v1
    INNER JOIN (
        SELECT id_graph, MAX(published_at) as max_published_at
        FROM routing_graph_version
        WHERE id_graph IN ($placeholders)
        GROUP BY id_graph
    ) v2 ON v1.id_graph = v2.id_graph 
        AND v1.published_at = v2.max_published_at
    WHERE v1.id_graph IN ($placeholders)
    ORDER BY v1.published_at DESC
");
```

**Performance Improvement:**
- Before: N+1 queries (1 query + N queries for N graphs)
- After: 1 query for all graphs
- Example: 10 graphs = 11 queries → 1 query (91% reduction)

**Benefits:**
- Faster `graph_list` endpoint response time
- Reduced database load
- Better scalability for large numbers of graphs

---

### R11: Granular Rate Limiting ✅ COMPLETED

**Status:** ✅ **COMPLETED** (November 10, 2025)

**Current Issue:**
Global rate limit was too restrictive for auto-save and didn't differentiate between actions.

**Solution Implemented:**
Per-action and per-graph rate limits with new `checkGraphAction()` method.

**Implementation:**
```php
// In RateLimiter class
public static function checkGraphAction(
    array $member,
    string $action,
    ?int $graphId = null,
    int $maxRequests = 60,
    int $windowSeconds = 60
): void {
    $endpoint = "dag_routing_{$action}";
    if ($graphId !== null && $graphId > 0) {
        $endpoint .= ":{$graphId}";
    }
    
    self::check($member, $maxRequests, $windowSeconds, $endpoint);
}
```

**Rate Limits Applied:**
- **Autosave:** 600/min per graph (high limit for frequent position updates)
- **Manual Save:** 30/min per graph (lower limit to prevent abuse)
- **Publish:** 10/min per graph (lowest limit - expensive operation)

**Usage:**
```php
// graph_save endpoint
if ($isAutosave) {
    RateLimiter::checkGraphAction($member, 'auto_save', $graphId, 600, 60);
} else {
    RateLimiter::checkGraphAction($member, 'save', $graphId, 30, 60);
}

// graph_autosave_positions endpoint
RateLimiter::checkGraphAction($member, 'auto_save', $graphId, 600, 60);

// graph_publish endpoint
RateLimiter::checkGraphAction($member, 'publish', $graphId, 10, 60);
```

**Benefits:**
- Different limits for different actions (autosave vs manual save vs publish)
- Per-graph isolation (one graph's activity doesn't affect others)
- Better user experience (autosave doesn't get throttled by manual saves)
- Prevents abuse while allowing legitimate frequent operations

---

### R15: Auto-Save System Overhaul ✅ COMPLETED

**Risk Description:**
Auto-save system had multiple issues:
1. **Hard validation blocking autosave:** `validateGraphStructure()` always enforced strict rules (start=1, end required, no cycles) → autosave failed during graph design
2. **Edge purge protection blocking:** Empty edges array triggered purge confirmation → autosave failed with 400
3. **Rate limit conflicts:** Autosave shared same rate limit (120/min) with manual saves → frequent throttling
4. **Indicator stuck:** `isAutoSaving` flag could get stuck, preventing future autosaves
5. **Full save overhead:** Autosave sent entire graph (nodes + edges) even for position-only changes

**Impact:**
- Auto-save failed frequently during graph design
- Poor UX: Users saw "Auto-saving..." stuck
- Data loss risk: Changes not saved automatically
- Performance: Unnecessary full graph saves

**Mitigation (Implemented):**

1. **Lightweight Autosave Endpoint (`graph_autosave_positions`):**
   - New endpoint: Only updates `position_x`, `position_y`, `node_name`
   - No validation (safe for partial updates)
   - No edge operations (prevents purge conflicts)
   - Separate rate limit: 600/min (vs 120/min for manual saves)
   - Optimistic locking with ETag/If-Match

2. **Soft Validation Mode for `graph_save`:**
   - Detects `save_type=autosave` parameter
   - Skips schema validation
   - Converts structure validation errors → warnings (doesn't block save)
   - Skips edge purge protection
   - Partial update: Only positions/names (no insert/delete nodes/edges)

3. **Stale Flag Detection:**
   - `scheduleAutoSave()` detects and resets stale `isAutoSaving` flags
   - Prevents autosave from being permanently blocked

4. **Comprehensive Error Handling:**
   - AJAX timeout: 10s for auto-save
   - Fallback timeout: 15s maximum display time
   - State reset in all error paths
   - Proper cleanup of timers

**Implementation Status:** ✅ **COMPLETED**
- ✅ New endpoint: `graph_autosave_positions` (positions only)
- ✅ Soft validation mode in `graph_save` (`save_type=autosave`)
- ✅ Separate rate limit: 600/min for autosave
- ✅ Stale flag detection and auto-reset
- ✅ AJAX timeout: 10s for auto-save
- ✅ Fallback timeout: 15s maximum display time
- ✅ State reset in all error paths

**Testing:**
- ✅ Browser test: Autosave works during graph design (no validation blocking)
- ✅ Browser test: Autosave doesn't trigger edge purge protection
- ✅ Browser test: Indicator doesn't stick
- ✅ Browser test: Rate limit doesn't conflict

**Files Modified:**
- `source/dag_routing_api.php`:
  - New endpoint: `graph_autosave_positions` (lines 1652-1796)
  - Modified `graph_save`: Soft validation mode, skip edge purge for autosave
- `assets/javascripts/dag/graph_designer.js`:
  - Autosave uses `graph_autosave_positions` endpoint
  - Stale flag detection in `scheduleAutoSave()`
  - Comprehensive error handling and timeout protection

---

### R14: Enhanced Monitoring ✅ COMPLETED

**Status:** ✅ **COMPLETED** (November 10, 2025)

**Current Issue:**
No comprehensive monitoring for performance, errors, and conflicts.

**Solution Implemented:**
Enhanced Metrics class with aggregation methods and monitoring dashboard endpoint.

**Implementation:**

1. **Metrics Collection:**
```php
// In graph_save
Metrics::record('dag_routing.save.duration_ms', $saveDuration, [
    'action' => $isAutosave ? 'autosave' : 'save',
    'graph_id' => (string)$graphId
]);
Metrics::increment('dag_routing.save.success', [
    'action' => $isAutosave ? 'autosave' : 'save'
]);

// Track slow saves (> 1 second)
if ($saveDuration > 1000) {
    Metrics::increment('dag_routing.save.slow', [
        'action' => $isAutosave ? 'autosave' : 'save'
    ]);
}

// Track 409 conflicts
Metrics::increment('dag_routing.save.conflict_409', [
    'action' => $isAutosave ? 'autosave' : 'save',
    'graph_id' => (string)$graphId
]);

// Track errors
Metrics::increment('dag_routing.save.error', [
    'action' => $isAutosave ? 'autosave' : 'save',
    'error_type' => 'db_operation_failed'
]);
```

2. **Metrics Helper Methods Added:**
```php
// Get aggregated statistics (count, avg, min, max, p50, p95, p99)
Metrics::getAggregated('dag_routing.save.duration_ms', $windowMinutes);

// Get counter total
Metrics::getCount('dag_routing.save.success', $windowMinutes);
```

3. **Monitoring Dashboard Endpoint (`graph_monitoring`):**
```php
// GET /source/dag_routing_api.php?action=graph_monitoring&window=10
// Returns:
{
    "ok": true,
    "window_minutes": 10,
    "metrics": {
        "save": {
            "duration_ms": {
                "count": 50,
                "avg": 120.5,
                "p50": 100,
                "p95": 250,
                "p99": 500
            },
            "success_count": 48,
            "error_count": 2,
            "conflict_count": 3,
            "slow_count": 1,
            "error_rate_percent": 4.0,
            "conflict_rate_percent": 6.0
        },
        "autosave": {
            "duration_ms": {...},
            "success_count": 200,
            "conflict_count": 5,
            "success_rate_percent": 97.56
        }
    },
    "alerts": {
        "high_error_rate": false,
        "high_conflict_rate": false,
        "slow_performance": false,
        "low_autosave_success": false
    }
}
```

**Metrics Tracked:**
- `dag_routing.save.duration_ms` - Save operation duration (histogram)
- `dag_routing.save.success` - Successful saves (counter)
- `dag_routing.save.error` - Failed saves (counter)
- `dag_routing.save.conflict_409` - Version conflicts (counter)
- `dag_routing.save.slow` - Slow saves > 1s (counter)
- `dag_routing.autosave.duration_ms` - Autosave duration (histogram)
- `dag_routing.autosave.success` - Successful autosaves (counter)
- `dag_routing.autosave.conflict_409` - Autosave conflicts (counter)
- `dag_routing.autosave.error` - Autosave errors (counter)

**Alert Thresholds:**
- High error rate: > 5%
- High conflict rate: > 10%
- Slow performance: P95 > 500ms
- Low autosave success: < 90%

**Benefits:**
- Real-time performance monitoring
- Error rate tracking
- Conflict detection
- Autosave success rate monitoring
- Alert system for anomalies
- Historical data analysis (configurable time window)

---

## Implementation Timeline

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| **Phase 1** | Week 1-2 | ETag fix, purge protection, If-Match enforcement, schema validation |
| **Phase 2** | Week 3-4 | Unique constraints, soft validation, audit trail, concurrency consistency |
| **Phase 3** | Week 5-6 | Permission standardization, JSON type consistency | ✅ **COMPLETED** (Nov 10, 2025) |
| **Phase 4** | Week 7-8 | Query optimization, granular rate limiting, monitoring | ✅ **COMPLETED** (Nov 10, 2025) |

---

## Testing Strategy

### Phase 1 Testing
- [ ] ETag header format verification (multiple browsers)
- [ ] Purge confirmation flow
- [ ] If-Match enforcement (manual + auto-save)
- [ ] Schema validation health check
- [ ] Auto-save indicator timeout protection (UX-1, UX-2)

### Phase 2 Testing
- [ ] Unique constraint violations
- [ ] Validation warnings display
- [ ] Audit log entries
- [ ] Concurrency conflict scenarios

### Phase 3 Testing ✅ COMPLETED
- [x] Permission checks - All 21 endpoints updated, legacy fallback verified
- [x] JSON field handling (TEXT + JSON) - Migration created, normalization function tested

### Phase 4 Testing ✅ COMPLETED
- [x] Query performance benchmarks - N+1 query optimized (91% reduction)
- [x] Rate limit behavior - Granular rate limits implemented
- [x] Monitoring dashboard - `graph_monitoring` endpoint created

---

## Success Criteria & Metrics

| Criteria | Metric | Target | Dashboard Query | Alert Threshold |
|----------|--------|--------|-----------------|-----------------|
| Zero data loss incidents | `dag_routing.save.error_rate` | < 0.1% | `sum(rate(dag_routing_save_errors_total[5m])) / sum(rate(dag_routing_save_total[5m]))` | > 0.5% for 5 min |
| Low latency | `dag_routing.save.duration_ms.p95` | < 500ms | `histogram_quantile(0.95, dag_routing_save_duration_ms_bucket)` | > 1000ms |
| Zero accidental deletions | `dag_routing.purge.without_confirm` | = 0 | `count(dag_routing_400_purge_required) WHERE NOT followed_by_confirm_within_10m` | > 0 |
| Zero schema drift | `routing.schema_valid` | = true | `routing_schema_validation{valid="false"}` | false for > 1 min |
| Concurrency conflicts | `dag_routing.save.409_rate` | < 1% | `sum(rate(dag_routing_409_version_conflict[5m])) / sum(rate(dag_routing_save_total[5m]))` | > 5% for 5 min |
| 100% audit coverage | `routing.audit.coverage` | = 100% | `sum(routing_audit_log_total) / sum(routing_save_total + routing_publish_total)` | < 95% |

**Monitoring Dashboard:**
- Error rate by endpoint (save/publish/validate)
- P50/P95/P99 latency
- 409 conflict rate
- Auto-save success rate
- Schema validation status
- Purge operations (with/without confirm)

---

## Minimal Test Matrix

**Purpose:** Quick validation checklist for QA/Agents to verify Phase 1 fixes

### ETag Semantics (3 tests)

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| **ET-1: Save with new ETag** | 1. Load graph → get ETag<br>2. Make changes<br>3. Save with current ETag | 200 OK, new ETag in response header |
| **ET-2: Save with stale ETag** | 1. Load graph → get ETag<br>2. Load graph again in another tab → get new ETag<br>3. Save first tab with old ETag | 409 Conflict, error message "version_conflict" |
| **ET-3: Missing If-Match** | 1. Load graph<br>2. Make changes<br>3. Save WITHOUT If-Match header | 428 Precondition Required (if `enforce_if_match=true`) |

### Purge Protection (2 tests)

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| **PU-1: Empty edges without confirm** | 1. Load graph with edges<br>2. Remove all edges in UI<br>3. Save (edges=[]) | 400 Bad Request, error code `DAG_ROUTING_400_PURGE_REQUIRED` |
| **PU-2: Empty edges with confirm** | 1. Load graph with edges<br>2. Remove all edges in UI<br>3. Confirm purge dialog<br>4. Save (edges=[], confirm_purge=1) | 200 OK, edges deleted, audit log entry |

### Validation (4 tests)

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| **VA-1: No START node** | 1. Create graph<br>2. Add only END node<br>3. Save | 400 Bad Request, error "Graph must have exactly one START node" |
| **VA-2: Multiple START nodes** | 1. Create graph<br>2. Add 2 START nodes<br>3. Save | 400 Bad Request, error "Graph must have exactly one START node" |
| **VA-3: No END node** | 1. Create graph<br>2. Add only START node<br>3. Save | 400 Bad Request, error "Graph must have at least one END node" |
| **VA-4: Duplicate node_code** | 1. Create graph<br>2. Add node with code "NODE1"<br>3. Add another node with code "NODE1"<br>4. Save | 400 Bad Request OR DB error (UNIQUE constraint violation) |

### Concurrency (1 test)

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| **CO-1: Concurrent save** | 1. Open graph in Tab A<br>2. Open same graph in Tab B<br>3. Make changes in Tab A → Save<br>4. Make changes in Tab B → Save (without reload) | Tab A: 200 OK<br>Tab B: 409 Conflict, prompt to reload |

**Total:** 10 test cases

---

## Communication Playbook

### Phase 1 Deployment

**Pre-Deployment:**
1. **Notify UI/Agent Teams:**
   - Frontend must send `If-Match` header for manual saves
   - Frontend must handle `confirm_purge` flag for edge deletion
   - Frontend must display validation warnings

2. **Feature Flags Setup:**
   ```php
   // In config.php (for gradual rollout)
   define('FEATURE_enforce_if_match', true);
   define('FEATURE_protect_purge_edges', true);
   define('FEATURE_draft_soft_validate_on_save', true);
   define('FEATURE_schema_validation_enabled', true);
   ```

**During Deployment:**
1. Monitor error rates:
   - Watch for spike in 428 errors (If-Match missing)
   - Watch for spike in 400 errors (validation failures)
   - Watch for spike in 409 errors (concurrency conflicts)

2. User Communication:
   - If 409 errors spike: Show toast message "Graph was updated. Please reload and try again."
   - If 428 errors: Show message "Please refresh the page and try saving again."
   - If validation errors: Show specific validation messages

**Rollback Procedure:**
```php
// Emergency rollback (disable feature flags)
define('FEATURE_enforce_if_match', false);  // Allow saves without If-Match
define('FEATURE_protect_purge_edges', false);  // Allow edge deletion without confirm
define('FEATURE_draft_soft_validate_on_save', false);  // Skip validation
```

**Post-Deployment:**
1. Monitor for 24 hours:
   - Error rates should stabilize
   - No increase in support tickets
   - User feedback positive

2. Gradual enablement:
   - Start with `enforce_if_match=false` for 1 day
   - Enable after confirming frontend updates are deployed
   - Enable validation after confirming users understand warnings

---

## Notes

- All migrations must be idempotent
- Backward compatibility maintained where possible
- Gradual rollout recommended for production
- Monitor error rates closely during each phase
- Feature flags allow instant rollback if issues arise

---

**Last Updated:** November 10, 2025 (v2.5 - Phase 4 Complete)  
**Next Review:** After production deployment  
**Version:** 2.5 (Phase 4: R10, R11, R14 - All Completed, Monitoring Dashboard Added)

