# Task 28.x - Normalization Refactor Complete
**Date:** 2025-12-13  
**Status:** ✅ **COMPLETE**  
**Priority:** P1 (Maintenance)

---

## Executive Summary

Successfully extracted duplicated normalization logic from `dag_graph_api.php` and `dag_routing_api.php` into a shared `GraphPayloadNormalizer` service. This ensures validation and save operations use identical node/edge structure, preventing inconsistencies.

---

## Problem Identified

**Duplication:** Normalization logic was duplicated in two places:
1. `dag_graph_api.php` - `graph_save` action (lines 809-980)
2. `dag_routing_api.php` - `graph_validate` action (lines 1618-1775)

**Risk:**
- Fixes in one place may not be applied to the other
- Validation and save may use different normalization rules
- Inconsistent behavior leads to "validate passes but save fails" scenarios

---

## Solution

**Created:** `GraphPayloadNormalizer` service
- **Location:** `source/dag/Graph/Service/GraphPayloadNormalizer.php`
- **Namespace:** `BGERP\Dag\Graph\Service`
- **Methods:**
  - `normalize(array $nodes, array $edges): array` - Main normalization method
  - `normalizeNodes(array $nodes): array` - Private: Normalize nodes
  - `buildIdMappings(array $nodes): array` - Private: Build Cytoscape ID mappings
  - `normalizeEdges(array $edges, array $nodes, array $mappings): array` - Private: Normalize edges
  - `resolveNodeCode($id, array $nodes, array $mappings): ?string` - Private: Resolve node code

**Refactored:**
1. `dag_graph_api.php` - `graph_save` now uses `GraphPayloadNormalizer`
2. `dag_routing_api.php` - `graph_validate` now uses `GraphPayloadNormalizer`

---

## Features

### Node Normalization
- Converts camelCase to snake_case (`nodeType` → `node_type`)
- Preserves Cytoscape `id` field
- Auto-generates `node_code` from `node_name` if missing
- Falls back to `id` if `node_code` cannot be generated

### Edge Normalization
- Maps Cytoscape `source`/`target` to `from_node_code`/`to_node_code`
- **P0.2 Fix:** Only stores numeric DB IDs in `from_node_id`/`to_node_id`
- **P1 Fix:** Prevents numeric temp ID collision with DB IDs
- Uses `node_code` as primary identifier for resolution

### ID Collision Prevention
- Checks if numeric ID exists in current payload before assuming it's a DB ID
- Prevents edges from binding to wrong nodes when temp IDs collide with DB IDs
- Unresolved edges will fail validation (correct behavior)

---

## Code Reduction

**Before:**
- `dag_graph_api.php`: ~170 lines of normalization code
- `dag_routing_api.php`: ~160 lines of normalization code
- **Total:** ~330 lines duplicated

**After:**
- `GraphPayloadNormalizer.php`: ~280 lines (shared service)
- `dag_graph_api.php`: ~3 lines (service call)
- `dag_routing_api.php`: ~3 lines (service call)
- **Total:** ~286 lines (saved ~44 lines, eliminated duplication)

---

## Testing Checklist

- [x] Syntax check passed
- [x] Linter check passed
- [ ] Test: Node normalization (camelCase → snake_case)
- [ ] Test: Edge normalization (source/target → node_code)
- [ ] Test: ID collision prevention (numeric temp ID vs DB ID)
- [ ] Test: Validation and save use same normalization
- [ ] Test: Backward compatibility (existing payloads work)

---

## Related Documents

- `CRITICAL_BUGS_FIXED.md` - P0/P1 fixes that are now centralized
- `SAVE_SEMANTICS_REFACTOR.md` - Original refactor plan
- `PRODUCTION_READINESS_CHECKLIST.md` - Overall readiness status

