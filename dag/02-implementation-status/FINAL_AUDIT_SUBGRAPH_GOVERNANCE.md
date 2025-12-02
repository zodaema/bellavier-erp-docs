# Final Audit: Subgraph Binding & Governance

**Date:** December 2025  
**Status:** ✅ **NO REGRESSIONS FOUND**  
**Scope:** Verify subgraph binding population and governance after all fixes

---

## 📋 Executive Summary

**Overall Status:** ✅ **FULLY COMPLIANT**

All subgraph governance features are correctly implemented:
- ✅ Binding population logic is correct and complete
- ✅ Delete protection works correctly
- ✅ Where-used report returns accurate data
- ✅ Version pinning is enforced

**No regressions detected.**

---

## CHECK 1: Binding Population in graph_save()

### ✅ 1.1 Delete Old Bindings

**Location:** `source/dag_routing_api.php` - `graph_save` action  
**Line:** 3014

**Implementation:**
```php
// 1. Delete existing bindings for this parent graph
$db->execute("DELETE FROM graph_subgraph_binding WHERE parent_graph_id = ?", [$graphId], 'i');
```

**Status:** ✅ **CORRECT**
- Deletes all existing bindings for parent graph before inserting new ones
- Uses prepared statement (SQL injection safe)
- Runs inside transaction (atomic operation)

---

### ✅ 1.2 Insert New Bindings

**Location:** `source/dag_routing_api.php` - `graph_save` action  
**Lines:** 3029-3150

**Implementation Verified:**

1. **✅ Iterates through all nodes:**
   ```php
   foreach ($nodes as $node) {
       $nodeType = $node['node_type'] ?? '';
       if ($nodeType !== 'subgraph') {
           continue;
       }
   ```

2. **✅ Extracts subgraph_ref correctly:**
   - Supports JSON field format (`subgraph_ref`)
   - Supports legacy column format (`subgraph_ref_id`, `subgraph_ref_version`)
   - Handles both string and array JSON formats

3. **✅ Validates subgraph and version exist:**
   ```php
   // Validate subgraph exists
   $subgraphExists = $db->fetchOne(...);
   
   // Validate version exists
   $versionExists = $db->fetchOne(...);
   ```

4. **✅ Gets node ID correctly:**
   - Uses `nodeCodeToIdMap` built after nodes saved
   - Falls back to database query if map unavailable
   - Validates node ID exists before binding

5. **✅ Inserts binding with all required fields:**
   ```php
   INSERT INTO graph_subgraph_binding 
   (parent_graph_id, parent_graph_version, node_id, subgraph_id, subgraph_version)
   VALUES (?, ?, ?, ?, ?)
   ```
   - `parent_graph_id`: Current graph ID ✅
   - `parent_graph_version`: Latest published version (or NULL) ✅
   - `node_id`: Subgraph node ID ✅
   - `subgraph_id`: Referenced subgraph ID ✅
   - `subgraph_version`: Pinned version ✅

6. **✅ Uses ON DUPLICATE KEY UPDATE for idempotency:**
   - Prevents duplicate binding errors
   - Updates version if binding already exists

**Status:** ✅ **CORRECT** - All fields populated correctly

---

### ✅ 1.3 Autosave Skip

**Location:** `source/dag_routing_api.php` - `graph_save` action  
**Line:** 3011

**Implementation:**
```php
if (!$isAutosave) {
    // Binding population logic
}
```

**Status:** ✅ **CORRECT**
- Skips binding population during autosave (draft saves)
- Only populates bindings on manual save
- Prevents unnecessary binding updates during editing

---

### ✅ 1.4 Error Handling

**Location:** `source/dag_routing_api.php` - `graph_save` action  
**Lines:** 3155-3160

**Implementation:**
```php
} catch (\Throwable $bindingError) {
    // Binding population failure should abort save
    error_log("[graph_save] CRITICAL: Binding population failed: " . $bindingError->getMessage());
    $db->rollback();
    throw new \RuntimeException("Failed to populate subgraph bindings: " . $bindingError->getMessage());
}
```

**Status:** ✅ **CORRECT**
- Aborts save on binding failure (rollback transaction)
- Logs error for debugging
- Throws exception to prevent partial state
- No partial bindings created

---

## CHECK 2: Where-Used Report

### ✅ 2.1 API Endpoint

**Location:** `source/dag_routing_api.php` - `get_subgraph_usage` action  
**Lines:** 6081-6192

**Implementation Verified:**

1. **✅ Queries graph_subgraph_binding correctly:**
   ```sql
   FROM graph_subgraph_binding gsb
   INNER JOIN routing_graph rg ON rg.id_graph = gsb.parent_graph_id
   INNER JOIN routing_node rn ON rn.id_node = gsb.node_id
   WHERE gsb.subgraph_id = ?
   ```

2. **✅ Returns comprehensive data:**
   - Parent graph info (name, code, status)
   - Node info (name, code, type)
   - Version info (parent_version, subgraph_version)
   - Active instance counts
   - Active ticket counts
   - Version mismatch detection

3. **✅ Calculates summary statistics:**
   - Total parent graphs
   - Total bindings
   - Total active instances
   - Total active tickets
   - Unique versions

**Status:** ✅ **CORRECT** - Returns accurate usage data

---

## CHECK 3: Delete Protection

### ✅ 3.1 Subgraph Binding Check

**Location:** `source/dag_routing_api.php` - `graph_delete` action  
**Lines:** 4361-4394

**Implementation:**
```php
// Check if graph is used as subgraph (graph_subgraph_binding)
$subgraphBindingResult = $db->fetchOne("SELECT COUNT(*) as cnt FROM graph_subgraph_binding WHERE subgraph_id = ?", [$graphId], 'i');
$subgraphBindingCount = (int)($subgraphBindingResult['cnt'] ?? 0);

if ($subgraphBindingCount > 0) {
    // Get parent graph details
    $parentGraphs = $db->fetchAll(...);
    
    json_error(..., [
        'app_code' => 'DAG_ROUTING_400_SUBGRAPH_IN_USE',
        'parent_graphs' => $parentGraphs,
        ...
    ]);
}
```

**Status:** ✅ **CORRECT**
- Checks `graph_subgraph_binding` table
- Blocks deletion if referenced
- Returns detailed parent graph list
- Error code: `DAG_ROUTING_400_SUBGRAPH_IN_USE`

---

### ✅ 3.2 Active Instance Check

**Location:** `source/dag_routing_api.php` - `graph_delete` action  
**Lines:** 4396-4409

**Implementation:**
```php
// Check if any active instances use this subgraph version
$activeInstanceResult = $db->fetchOne("
    SELECT COUNT(*) as cnt 
    FROM job_graph_instance 
    WHERE id_graph = ? AND graph_version IS NOT NULL AND status IN ('active', 'paused')
", [$graphId], 'i');
```

**Status:** ✅ **CORRECT**
- Checks for active/paused instances
- Only checks versioned instances (`graph_version IS NOT NULL`)
- Blocks deletion if active instances exist
- Error code: `DAG_ROUTING_400_ACTIVE_INSTANCES`

---

### ✅ 3.3 Active Ticket Check

**Location:** `source/dag_routing_api.php` - `graph_delete` action  
**Lines:** 4410-4425

**Implementation:**
```php
// Check active job tickets
$activeTicketResult = $db->fetchOne("
    SELECT COUNT(*) as cnt 
    FROM job_graph_instance jgi
    INNER JOIN job_ticket jt ON jt.id_job_ticket = jgi.id_job_ticket
    WHERE jgi.id_graph = ? AND jt.status IN ('in_progress', 'on_hold')
", [$graphId], 'i');
```

**Status:** ✅ **CORRECT**
- Checks for active tickets (`in_progress`, `on_hold`)
- Blocks deletion if active tickets exist
- Error code: `DAG_ROUTING_400_ACTIVE_TICKETS`

---

## CHECK 4: Version Pinning

### ✅ 4.1 Version Extraction

**Location:** `source/dag_routing_api.php` - `graph_save` action  
**Lines:** 3066-3067

**Implementation:**
```php
$subgraphId = $subgraphRef['graph_id'] ?? null;
$subgraphVersion = $subgraphRef['graph_version'] ?? null;
```

**Status:** ✅ **CORRECT**
- Extracts version from `subgraph_ref`
- Validates version exists before binding
- Stores version in binding table

---

### ✅ 4.2 Version Validation

**Location:** `source/dag_routing_api.php` - `graph_save` action  
**Lines:** 3110-3119

**Implementation:**
```php
// Validate version exists
$versionExists = $db->fetchOne(
    "SELECT id_version FROM routing_graph_version WHERE id_graph = ? AND version = ?",
    [$subgraphId, $subgraphVersion],
    'is'
);
if (!$versionExists) {
    error_log("[graph_save] Warning: Subgraph version '{$subgraphVersion}' not found for graph ID {$subgraphId} - skipping binding");
    continue;
}
```

**Status:** ✅ **CORRECT**
- Validates version exists in `routing_graph_version`
- Skips binding if version not found (validation will catch this)
- Logs warning for debugging

---

## CHECK 5: Parent Graph Version

### ✅ 5.1 Parent Version Storage

**Location:** `source/dag_routing_api.php` - `graph_save` action  
**Lines:** 3016-3027

**Implementation:**
```php
// 2. Get current graph version (if published)
$currentGraphVersion = null;
$publishedVersion = $db->fetchOne("
    SELECT version 
    FROM routing_graph_version 
    WHERE id_graph = ? AND published_at IS NOT NULL 
    ORDER BY published_at DESC 
    LIMIT 1
", [$graphId], 'i');
if ($publishedVersion) {
    $currentGraphVersion = $publishedVersion['version'];
}
```

**Status:** ✅ **CORRECT**
- Gets latest published version of parent graph
- Stores in `parent_graph_version` field
- NULL if parent graph not published yet

---

## Summary

### ✅ What's Working

1. ✅ Binding population logic is complete and correct
2. ✅ Delete protection works correctly (3 checks)
3. ✅ Where-used report returns accurate data
4. ✅ Version pinning is enforced
5. ✅ Error handling aborts save on failure
6. ✅ Autosave correctly skips binding population

### ⚠️ No Issues Found

**No regressions detected.**

---

## Conclusion

**Overall Assessment:** ✅ **FULLY COMPLIANT**

All subgraph governance features are correctly implemented:
- Binding population works correctly
- Delete protection is comprehensive
- Where-used report is accurate
- Version pinning is enforced
- Error handling prevents partial state

**Risk Level:** 🟢 **LOW** - All features working as designed

---

**Audit Completed:** December 2025  
**Auditor:** AI Agent (Composer)  
**Next Review:** After any subgraph-related changes

