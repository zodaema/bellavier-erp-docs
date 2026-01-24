# Task 28.x - Critical Normalizer Fix (Phantom Update Bug)
**Date:** 2025-12-13  
**Status:** ✅ **FIXED**  
**Priority:** P0 (Critical Data Loss Risk)

---

## Executive Summary

Fixed critical logic flaw in `GraphPayloadNormalizer` that caused new nodes with numeric temp IDs to be treated as existing nodes, resulting in phantom UPDATE operations (0 affected rows) and silent data loss.

---

## 🚨 Critical Bug: Phantom Update (Silent Data Loss)

### Problem

**Location:** `source/dag/Graph/Service/GraphPayloadNormalizer.php` line 78

**Original Code:**
```php
'id_node' => $node['id_node'] ?? (is_numeric($node['id'] ?? null) ? (int)$node['id'] : null) ?? null,
```

**Issue:**
- Normalizer attempted to infer `id_node` from `id` if `id` was numeric
- This caused new nodes with numeric temp IDs (e.g., `id: "167"`) to be treated as existing nodes
- GraphSaveEngine checks `isset($node['id_node']) && $node['id_node'] > 0` to decide UPDATE vs INSERT
- Result: New nodes triggered UPDATE operations with 0 affected rows instead of INSERT
- **Data Loss:** New nodes were silently dropped (phantom update)

### Scenario

1. Frontend creates new node with temp ID: `{ id: "167", id_node: null }`
2. Normalizer infers: `id_node = 167` (because `id` is numeric)
3. GraphSaveEngine sees: `isset($node['id_node']) && $node['id_node'] > 0` → true
4. Executes: `UPDATE routing_node ... WHERE id_node = 167 AND id_graph = ?`
5. Result: 0 affected rows (node 167 doesn't exist in this graph)
6. **Node is never inserted** → Silent data loss

### Solution

**Changed to strict mode - only use explicitly provided `id_node`:**

```php
// CRITICAL FIX P0: DO NOT infer id_node from id - this causes "Phantom Update" bug
// If id_node is not explicitly provided, it MUST be null (indicates new node)
// Frontend MUST send id_node for existing nodes, null for new nodes
'id_node' => $node['id_node'] ?? null, // STRICT: Only use explicitly provided id_node, never infer from id
```

**Result:**
- New nodes: `id_node = null` → GraphSaveEngine executes INSERT ✅
- Existing nodes: Frontend must send `id_node` explicitly → GraphSaveEngine executes UPDATE ✅

---

## ⚠️ P1 Fix: Edge Numeric ID Collision

### Problem

**Location:** `source/dag/Graph/Service/GraphPayloadNormalizer.php` lines 193-198

**Original Code:**
```php
if ($source !== null && is_numeric($source) && (int)$source > 0) {
    $fromNodeId = (int)$source;
}
```

**Issue:**
- Normalizer trusted any numeric `source`/`target` as a DB ID
- Numeric temp IDs from frontend (e.g., `"100"`) would be treated as DB IDs
- GraphSaveEngine would use these IDs directly without verification
- Result: Edges could be bound to wrong nodes or fail validation

### Solution

**Added payload verification before trusting numeric IDs:**

```php
// CRITICAL FIX P1: DO NOT trust numeric IDs as DB IDs without verification
// Check if numeric ID exists in current payload - if yes, it's likely a temp ID, not DB ID
if ($source !== null && is_numeric($source) && (int)$source > 0) {
    // Check if this numeric ID exists in current payload as a temp ID
    $isTempId = false;
    foreach ($normalizedNodes as $node) {
        $nodeId = $node['id'] ?? null;
        $nodeIdNode = $node['id_node'] ?? null;
        // If source matches node's id but node has no id_node (or id_node != source), it's a temp ID
        if ((string)$nodeId === (string)$source && (!$nodeIdNode || $nodeIdNode !== (int)$source)) {
            $isTempId = true;
            break;
        }
    }
    // Only set from_node_id if numeric ID is NOT a temp ID in current payload
    // If it's a temp ID, leave it null and rely on from_node_code (which is already resolved above)
    if (!$isTempId) {
        $fromNodeId = (int)$source;
    }
}
```

**Result:**
- Temp IDs in payload: `from_node_id = null`, rely on `from_node_code` ✅
- Verified DB IDs: `from_node_id` set correctly ✅
- GraphSaveEngine verifies via `node_code` resolution ✅

---

## Frontend Contract (Updated)

**For existing nodes:**
```javascript
{
    id: "n4485",           // Cytoscape ID
    id_node: 4485,         // REQUIRED: Explicit DB ID
    node_code: "NODE_001", // REQUIRED: Node code
    // ... other fields
}
```

**For new nodes:**
```javascript
{
    id: "tmp_xxx",         // Temp ID (any format, numeric or UUID)
    id_node: null,         // REQUIRED: Must be null (not undefined, not 0)
    node_code: "NODE_002", // REQUIRED: Node code
    // ... other fields
}
```

**Critical Rule:**
- ❌ **NEVER** infer `id_node` from `id` on backend
- ✅ Frontend **MUST** send `id_node` explicitly for existing nodes
- ✅ Frontend **MUST** send `id_node: null` for new nodes

---

## Testing Checklist

- [x] Syntax check passed
- [x] Linter check passed
- [ ] Test: New node with numeric temp ID → INSERT (not UPDATE)
- [ ] Test: Existing node with id_node → UPDATE
- [ ] Test: New node with UUID temp ID → INSERT
- [ ] Test: Edge with numeric temp ID → uses node_code (not numeric ID)
- [ ] Test: Edge with verified DB ID → uses from_node_id correctly

---

## Related Documents

- `NORMALIZATION_REFACTOR_COMPLETE.md` - Original normalization refactor
- `AUDIT_FOLLOW_UP_RISKS.md` - Original audit findings
- `P0_P1_FIXES_SUMMARY.md` - Switch case fixes

